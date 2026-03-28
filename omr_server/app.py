#!/usr/bin/env python3
"""
SmartScore OMR Server (FastAPI)

Usage:
  uvicorn app:app --host 0.0.0.0 --port 8080
  # or: python3 app.py

Endpoints:
  POST /omr          — single image OMR
  POST /omr/multi    — multi-page OMR
  POST /render       — MusicXML -> PNG via LilyPond
  GET  /health
  GET  /corpus/search?q=<query>
  GET  /corpus/export?id=<score_id>
  GET  /corpus/stats
  GET  /imslp/search?q=<query>
  GET  /imslp/page?title=<title>
  GET  /imslp/download?url=<url>
  GET  /imslp/download_binary?url=<url>
"""

import asyncio
import base64
import json
import os
import re
import sys
import tempfile
import traceback
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from typing import Optional

from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from fastapi.staticfiles import StaticFiles

from omr_engine import get_engine_name, is_available, run_omr
from renderer import render_to_midi, render_to_png

# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------

app = FastAPI(title="SmartScore OMR Server", version="2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: restrict in production
    allow_methods=["*"],
    allow_headers=["*"],
)

# Thread pool for CPU-bound OMR work
_omr_pool = ThreadPoolExecutor(max_workers=2, thread_name_prefix="omr")

# ---------------------------------------------------------------------------
# music21 (lazy)
# ---------------------------------------------------------------------------
_music21_available = False
try:
    import music21

    _music21_available = True
    print("[Corpus] music21 loaded successfully")
except ImportError as e:
    print(f"[Corpus] music21 not available: {e}")

# Pre-cached corpus index
_corpus_index: list | None = None


def _load_corpus_index():
    global _corpus_index
    if _corpus_index is not None:
        return
    index_path = os.path.join(os.path.dirname(__file__), "corpus_index.json")
    if os.path.exists(index_path):
        with open(index_path) as f:
            _corpus_index = json.load(f)
        print(f"[Corpus] Loaded pre-built index: {len(_corpus_index)} entries")
    else:
        _corpus_index = []
        print("[Corpus] No pre-built index found")


# Load index at startup
_load_corpus_index()

# ---------------------------------------------------------------------------
# Preprocessing
# ---------------------------------------------------------------------------
_preprocess_available = False
try:
    from preprocess import preprocess_for_omr

    _preprocess_available = True
except ImportError:
    pass

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB per image
MAX_RENDER_BODY = 5 * 1024 * 1024  # 5 MB for render request
MAX_DOWNLOAD_BYTES = 50 * 1024 * 1024  # 50 MB for IMSLP downloads
ALLOWED_IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".tiff", ".bmp", ".webp"}
OMR_PAGE_TIMEOUT = 120  # seconds per page

IMSLP_ALLOWED_HOSTS = {
    "imslp.org",
    "www.imslp.org",
    "imslp.simssa.ca",
    "petruccimusiclibrary.org",
}
IMSLP_ALLOWED_EXTS = {".xml", ".musicxml", ".mxl", ".pdf", ".mid", ".midi"}
IMSLP_UA = "SmartScore/2.0 (educational music app)"


# ═══════════════════════════════════════════════════════════════════════════
# Health
# ═══════════════════════════════════════════════════════════════════════════


@app.get("/health")
async def health():
    return {
        "status": "ready" if is_available() else "no_engine",
        "engine": get_engine_name(),
    }


# ═══════════════════════════════════════════════════════════════════════════
# OMR — single image
# ═══════════════════════════════════════════════════════════════════════════


def _process_single_image(image_data: bytes, filename: str) -> str:
    """Synchronous: save image, preprocess, run OMR. Returns MusicXML."""
    suffix = os.path.splitext(filename)[1] or ".png"
    if suffix.lower() not in ALLOWED_IMAGE_EXTS:
        suffix = ".png"

    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(image_data)
        tmp_path = tmp.name

    try:
        original_path = tmp_path
        # Preprocessing
        if _preprocess_available:
            try:
                pp_path = tmp_path.rsplit(".", 1)[0] + "_preprocessed.png"
                preprocess_for_omr(tmp_path, pp_path)
                if os.path.exists(pp_path):
                    tmp_path = pp_path
                    print("[OMR] Using preprocessed image")
            except Exception as e:
                print(f"[OMR] Preprocess skipped: {e}")

        # Run OMR
        musicxml = None
        try:
            musicxml = run_omr(tmp_path)
        except Exception as e1:
            if tmp_path != original_path:
                print(f"[OMR] Preprocessed failed ({e1}), trying original")
                musicxml = run_omr(original_path)
            else:
                raise

        if not musicxml:
            raise RuntimeError("OMR produced no output")

        print(f"[OMR] Success: {len(musicxml)} chars MusicXML")
        return musicxml
    finally:
        for p in {tmp_path, original_path} if 'original_path' in dir() else {tmp_path}:
            if os.path.exists(p):
                os.unlink(p)


@app.post("/omr")
async def omr_single(image: UploadFile = File(...)):
    data = await image.read()
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "Image too large (max 10 MB)")

    loop = asyncio.get_event_loop()
    try:
        musicxml = await loop.run_in_executor(
            _omr_pool, _process_single_image, data, image.filename or "score.png"
        )
        return {"musicxml": musicxml, "success": True}
    except Exception as e:
        traceback.print_exc()
        return JSONResponse({"error": str(e), "success": False}, status_code=500)


# ═══════════════════════════════════════════════════════════════════════════
# OMR — multi page
# ═══════════════════════════════════════════════════════════════════════════


def _merge_musicxml_pages(xml_list: list[str]) -> str:
    """Merge multiple MusicXML strings by concatenating measures."""
    if len(xml_list) == 1:
        return xml_list[0]

    def extract_measures(xml_text):
        return re.findall(r"<measure\b[^>]*>.*?</measure>", xml_text, re.DOTALL)

    def get_header(xml_text):
        match = re.search(r"<part\b", xml_text)
        return xml_text[: match.start()] if match else ""

    all_measures = []
    for page_xml in xml_list:
        all_measures.extend(extract_measures(page_xml))

    # Renumber measures
    renumbered = []
    for idx, m in enumerate(all_measures, 1):
        new_m = re.sub(
            r'(<measure\s[^>]*\bnumber=")[^"]*(")',
            lambda match, n=idx: f"{match.group(1)}{n}{match.group(2)}",
            m,
        )
        renumbered.append(new_m)

    header = get_header(xml_list[0])
    if not header.strip():
        header = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<score-partwise version="3.1">\n'
            "  <part-list>"
            '<score-part id="P1"><part-name>Piano</part-name></score-part>'
            "</part-list>\n"
        )

    measures_block = "\n    ".join(renumbered)
    merged = f'{header}<part id="P1">\n    {measures_block}\n  </part>\n</score-partwise>'
    if not merged.strip().startswith("<?xml"):
        merged = '<?xml version="1.0" encoding="UTF-8"?>\n' + merged
    return merged


@app.post("/omr/multi")
async def omr_multi(request: Request):
    form = await request.form()
    image_fields = sorted(
        [k for k in form.keys() if k.startswith("image_")],
        key=lambda k: int(k.split("_", 1)[1]) if k.split("_", 1)[1].isdigit() else 0,
    )
    if not image_fields:
        raise HTTPException(400, "No image fields found (expected image_0, image_1, ...)")

    print(f"[OMR/multi] Processing {len(image_fields)} page(s)")

    # Read all images
    images: list[tuple[bytes, str]] = []
    for field_name in image_fields:
        upload = form[field_name]
        data = await upload.read()
        if len(data) > MAX_UPLOAD_BYTES:
            raise HTTPException(413, f"{field_name} too large (max 10 MB)")
        images.append((data, upload.filename or f"{field_name}.png"))

    # Process each page in thread pool
    loop = asyncio.get_event_loop()
    xml_list: list[str] = []

    for i, (data, fname) in enumerate(images):
        print(f"[OMR/multi] Page {i + 1}/{len(images)}: {fname}")
        try:
            musicxml = await asyncio.wait_for(
                loop.run_in_executor(_omr_pool, _process_single_image, data, fname),
                timeout=OMR_PAGE_TIMEOUT,
            )
            xml_list.append(musicxml)
            print(f"[OMR/multi] Page {i + 1}: OK ({len(musicxml)} chars)")
        except asyncio.TimeoutError:
            print(f"[OMR/multi] Page {i + 1}: TIMEOUT after {OMR_PAGE_TIMEOUT}s, skipping")
        except Exception as e:
            print(f"[OMR/multi] Page {i + 1} failed: {e}")

    if not xml_list:
        return JSONResponse(
            {"error": "OMR produced no output for any page", "success": False},
            status_code=500,
        )

    merged_xml = _merge_musicxml_pages(xml_list)
    print(f"[OMR/multi] Merged {len(xml_list)} page(s): {len(merged_xml)} chars")

    return {"musicxml": merged_xml, "page_count": len(xml_list), "success": True}


# ═══════════════════════════════════════════════════════════════════════════
# Render (MusicXML -> PNG via LilyPond)
# ═══════════════════════════════════════════════════════════════════════════


def _render_sync(musicxml: str) -> dict:
    with tempfile.NamedTemporaryFile(suffix=".xml", delete=False) as tmp:
        tmp.write(musicxml.encode("utf-8"))
        tmp_path = tmp.name
    try:
        base_path = tmp_path.rsplit(".", 1)[0]
        png_b64 = render_to_png(musicxml, base_path)
        midi_b64 = render_to_midi(base_path)
        result = {"success": bool(png_b64)}
        if png_b64:
            result["png_base64"] = png_b64
        if midi_b64:
            result["midi_base64"] = midi_b64
        if not png_b64:
            result["error"] = "LilyPond rendering failed"
        return result
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


@app.post("/render")
async def render(request: Request):
    body = await request.body()
    if len(body) > MAX_RENDER_BODY:
        raise HTTPException(413, "Request body too large")
    data = json.loads(body)
    musicxml = data.get("musicxml", "")
    if not musicxml:
        raise HTTPException(400, "No musicxml provided")

    print(f"[Render] Rendering MusicXML ({len(musicxml)} chars) to PNG...")
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(_omr_pool, _render_sync, musicxml)
    return result


# ═══════════════════════════════════════════════════════════════════════════
# Corpus
# ═══════════════════════════════════════════════════════════════════════════


@app.get("/corpus/search")
async def corpus_search(q: str = ""):
    if not q.strip():
        raise HTTPException(400, "Missing query parameter 'q'")

    query = q.strip().lower()

    # Fast search from pre-cached index
    if _corpus_index:
        results = [
            e
            for e in _corpus_index
            if query in e.get("title", "").lower()
            or query in e.get("composer", "").lower()
            or query in e.get("id", "").lower()
        ][:30]
        return {"results": results, "query": q, "total": len(results)}

    if not _music21_available:
        raise HTTPException(503, "music21 not installed")

    search_results = music21.corpus.search(q)
    results = []
    for r in search_results[:30]:
        source_path = str(r.sourcePath) if r.sourcePath else ""
        score_id = source_path.replace("\\", "/")
        for prefix in ["/music21/corpus/", "music21/corpus/"]:
            if prefix in score_id:
                score_id = score_id.split(prefix, 1)[-1]
                break
        title = ""
        composer = ""
        try:
            if r.metadata:
                title = r.metadata.title or ""
                composer = r.metadata.composer or ""
        except Exception:
            pass
        if not title:
            title = score_id.split("/")[-1].replace(".xml", "").replace(".mxl", "")
        results.append({"id": score_id, "title": title, "composer": composer, "parts": 0})

    return {"results": results, "query": q, "total": len(search_results)}


@app.get("/corpus/export")
async def corpus_export(id: str = ""):
    if not id.strip():
        raise HTTPException(400, "Missing parameter 'id'")
    if not _music21_available:
        raise HTTPException(503, "music21 not installed")

    score_id = id.strip()
    if not re.match(r"^[\w\-./]+$", score_id):
        raise HTTPException(400, "Invalid score id")

    def _export_sync():
        print(f"[Corpus] Export: {score_id}")
        score = music21.corpus.parse(score_id)
        with tempfile.NamedTemporaryFile(suffix=".xml", delete=False) as tmp:
            tmp_path = tmp.name
        try:
            score.write("musicxml", fp=tmp_path)
            with open(tmp_path, "r", encoding="utf-8", errors="replace") as f:
                xml_content = f.read()
        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)

        title = ""
        part_count = 0
        try:
            if score.metadata:
                title = score.metadata.title or ""
            flat_parts = score.parts
            part_count = len(flat_parts) if flat_parts else 0
        except Exception:
            pass
        if not title:
            title = score_id.split("/")[-1].replace(".xml", "").replace(".mxl", "")

        # Render to PNG
        base_path = tmp_path.rsplit(".", 1)[0]
        png_b64 = render_to_png(xml_content, base_path)
        midi_b64 = render_to_midi(base_path)

        response = {"musicxml": xml_content, "title": title, "parts": part_count, "success": True}
        if png_b64:
            response["png_base64"] = png_b64
        if midi_b64:
            response["midi_base64"] = midi_b64
        return response

    loop = asyncio.get_event_loop()
    try:
        result = await loop.run_in_executor(_omr_pool, _export_sync)
        return result
    except Exception as e:
        traceback.print_exc()
        return JSONResponse({"error": str(e), "success": False}, status_code=500)


@app.get("/corpus/stats")
async def corpus_stats():
    if not _music21_available:
        raise HTTPException(503, "music21 not installed")

    _load_corpus_index()
    total = len(_corpus_index) if _corpus_index else 15026

    known_composers = {
        "bach": "bach", "beethoven": "beethoven", "mozart": "mozart",
        "haydn": "haydn", "schubert": "schubert", "handel": "handel",
    }
    composer_counts = {}
    for display_name, query in known_composers.items():
        try:
            results = music21.corpus.search(query)
            if len(results) > 0:
                composer_counts[display_name] = len(results)
        except Exception:
            pass

    return {"total": total, "composers": composer_counts, "available": True}


# ═══════════════════════════════════════════════════════════════════════════
# IMSLP proxy
# ═══════════════════════════════════════════════════════════════════════════


def _validate_imslp_url(url: str) -> str:
    """Validate URL is from IMSLP allowed hosts."""
    parsed = urllib.parse.urlparse(url)
    if parsed.netloc not in IMSLP_ALLOWED_HOSTS:
        raise HTTPException(403, "URL not allowed: must be from imslp.org")
    return url


@app.get("/imslp/search")
async def imslp_search(q: str = ""):
    if not q.strip():
        raise HTTPException(400, "Missing query parameter 'q'")

    params = urllib.parse.urlencode({
        "action": "query", "list": "search", "srsearch": q,
        "srnamespace": "0", "srlimit": "20", "format": "json",
    })
    api_url = f"https://imslp.org/api.php?{params}"

    def _fetch():
        req = urllib.request.Request(api_url, headers={"User-Agent": IMSLP_UA})
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode("utf-8"))

    loop = asyncio.get_event_loop()
    try:
        raw = await loop.run_in_executor(None, _fetch)
        hits = raw.get("query", {}).get("search", [])
        results = [
            {"title": h.get("title", ""), "snippet": h.get("snippet", ""), "timestamp": h.get("timestamp", "")}
            for h in hits
        ]
        return {"results": results, "query": q}
    except urllib.error.URLError as e:
        raise HTTPException(502, f"IMSLP unreachable: {e}")


@app.get("/imslp/page")
async def imslp_page(title: str = ""):
    if not title.strip():
        raise HTTPException(400, "Missing parameter 'title'")

    wiki_url = f"https://imslp.org/wiki/{urllib.parse.quote(title.strip().replace(' ', '_'))}"

    def _fetch():
        req = urllib.request.Request(wiki_url, headers={"User-Agent": IMSLP_UA})
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.read().decode("utf-8", errors="replace")

    loop = asyncio.get_event_loop()
    try:
        html = await loop.run_in_executor(None, _fetch)
    except urllib.error.URLError as e:
        raise HTTPException(502, f"IMSLP unreachable: {e}")

    files = []
    seen: set[str] = set()

    # PMLP file references
    pmlp_files = re.findall(
        r"(PMLP\d+[A-Za-z0-9_\-\.]*\.(?:pdf|xml|musicxml|mxl|mid|midi))",
        html, re.IGNORECASE,
    )
    for fname in pmlp_files:
        if fname not in seen:
            seen.add(fname)
            ext = fname.rsplit(".", 1)[-1].lower()
            ftype = "pdf" if ext == "pdf" else ("midi" if ext in ("mid", "midi") else "musicxml")
            files.append({"label": fname, "type": ftype, "url": ""})

    # Direct download links
    direct_links = re.findall(
        r'href="(https?://[^"]*(?:\.pdf|\.xml|\.musicxml|\.mxl|\.mid|\.midi)[^"]*)"',
        html, re.IGNORECASE,
    )
    for url in direct_links:
        label = url.split("/")[-1]
        if label not in seen:
            seen.add(label)
            ext = label.rsplit(".", 1)[-1].lower()
            ftype = "pdf" if ext == "pdf" else ("midi" if ext in ("mid", "midi") else "musicxml")
            files.append({"label": label, "type": ftype, "url": url})

    # Dedupe and limit
    unique_files = []
    unique_labels: set[str] = set()
    for f in files:
        short = f["label"][:60]
        if short not in unique_labels:
            unique_labels.add(short)
            unique_files.append(f)
            if len(unique_files) >= 30:
                break

    return {"title": title, "files": unique_files, "wiki_url": wiki_url}


@app.get("/imslp/download")
async def imslp_download(url: str = ""):
    if not url.strip():
        raise HTTPException(400, "Missing parameter 'url'")
    file_url = _validate_imslp_url(url.strip())
    lower = file_url.lower()
    if not any(lower.endswith(ext) for ext in IMSLP_ALLOWED_EXTS):
        raise HTTPException(400, "Only MusicXML, PDF, or MIDI files can be downloaded")

    def _fetch():
        req = urllib.request.Request(file_url, headers={"User-Agent": IMSLP_UA})
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read(MAX_DOWNLOAD_BYTES).decode("utf-8", errors="replace")

    loop = asyncio.get_event_loop()
    try:
        content = await loop.run_in_executor(None, _fetch)
        return Response(content=content, media_type="text/xml; charset=utf-8")
    except urllib.error.URLError as e:
        raise HTTPException(502, f"Download failed: {e}")


@app.get("/imslp/download_binary")
async def imslp_download_binary(url: str = ""):
    if not url.strip():
        raise HTTPException(400, "Missing parameter 'url'")
    file_url = _validate_imslp_url(url.strip())

    filename = file_url.split("/")[-1].split("?")[0] or "file"
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    ext_map = {
        "xml": "musicxml", "musicxml": "musicxml", "mxl": "musicxml",
        "pdf": "pdf", "mid": "midi", "midi": "midi",
    }
    file_type = ext_map.get(ext)
    if not file_type:
        raise HTTPException(400, "Only MusicXML, PDF, or MIDI files are allowed")

    def _fetch():
        req = urllib.request.Request(file_url, headers={"User-Agent": IMSLP_UA})
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read(MAX_DOWNLOAD_BYTES)

    loop = asyncio.get_event_loop()
    try:
        raw = await loop.run_in_executor(None, _fetch)
        return {"data_base64": base64.b64encode(raw).decode("ascii"), "filename": filename, "type": file_type}
    except urllib.error.URLError as e:
        raise HTTPException(502, f"Download failed: {e}")


# ═══════════════════════════════════════════════════════════════════════════
# Score Following — Timing Map + Reference Features
# ═══════════════════════════════════════════════════════════════════════════


@app.post("/score/timing-map")
async def score_timing_map(request: Request):
    body = await request.body()
    data = json.loads(body)
    musicxml = data.get("musicxml", "")
    tempo = data.get("tempo_bpm", 120.0)
    if not musicxml:
        raise HTTPException(400, "No musicxml provided")

    from timing_map import generate_timing_map
    result = generate_timing_map(musicxml, tempo)
    return result


@app.post("/score/reference-features")
async def score_reference_features(request: Request):
    body = await request.body()
    if len(body) > MAX_RENDER_BODY:
        raise HTTPException(413, "Request body too large")
    data = json.loads(body)
    musicxml = data.get("musicxml", "")
    tempo = data.get("tempo_bpm", 120.0)
    if not musicxml:
        raise HTTPException(400, "No musicxml provided")

    from reference_features import generate_reference_features

    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(
        _omr_pool, generate_reference_features, musicxml, tempo, True
    )
    return result


@app.get("/score/{score_hash}/chroma-cache")
async def score_chroma_cache(score_hash: str):
    cache_path = os.path.join(
        os.path.dirname(__file__), "chroma_cache", f"{score_hash}.json"
    )
    if not os.path.exists(cache_path):
        raise HTTPException(404, "Cache not found")
    with open(cache_path) as f:
        return json.loads(f.read())


# ═══════════════════════════════════════════════════════════════════════════
# Static files + startup
# ═══════════════════════════════════════════════════════════════════════════


def mount_static(web_dir: str):
    """Mount Flutter web build as static files (catch-all for SPA)."""
    if os.path.isdir(web_dir):
        app.mount("/", StaticFiles(directory=web_dir, html=True), name="static")
        print(f"[Static] Serving {web_dir}")


if __name__ == "__main__":
    import uvicorn

    # Auto-mount Flutter web build if available
    script_dir = os.path.dirname(os.path.abspath(__file__))
    web_dir = os.path.join(script_dir, "..", "build_unified", "build", "web")
    if os.path.isdir(web_dir):
        mount_static(web_dir)

    uvicorn.run(app, host="0.0.0.0", port=8080)
