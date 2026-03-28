"""Score rendering: MusicXML -> PNG + MIDI.

Primary: Verovio Python (tolerant, fast, no external deps)
Fallback: LilyPond (musicxml2ly + lilypond CLI)
"""

import base64
import glob
import os
import subprocess


def render_to_png(musicxml: str, base_path: str) -> str | None:
    """Render MusicXML to PNG. Tries Verovio first, falls back to LilyPond."""
    # Try Verovio (faster, more tolerant)
    result = _render_verovio(musicxml)
    if result:
        return result
    # Fallback to LilyPond
    return _render_lilypond(musicxml, base_path)


def _render_verovio(musicxml: str) -> str | None:
    """Render MusicXML to PNG via Verovio Python bindings."""
    try:
        import verovio
        import cairosvg

        tk = verovio.toolkit()
        tk.setOptions({
            "pageHeight": 2970,
            "pageWidth": 2100,
            "scale": 40,
            "adjustPageHeight": True,
            "breaks": "auto",
        })

        if not tk.loadData(musicxml):
            print("[Render] Verovio: failed to load MusicXML")
            return None

        page_count = tk.getPageCount()
        if page_count < 1:
            return None

        # Render first page to SVG, convert to PNG
        svg = tk.renderToSVG(1)
        if not svg or len(svg) < 100:
            return None

        png_data = cairosvg.svg2png(bytestring=svg.encode("utf-8"), dpi=150)
        print(f"[Render] Verovio PNG: {len(png_data)} bytes ({page_count} pages)")
        return base64.b64encode(png_data).decode("ascii")

    except ImportError:
        return None
    except Exception as e:
        print(f"[Render] Verovio failed: {e}")
        return None


def _render_lilypond(musicxml: str, base_path: str) -> str | None:
    """Render MusicXML to PNG via musicxml2ly + LilyPond. Returns base64 string."""
    try:
        xml_path = base_path + "_render.xml"
        ly_path = base_path + "_render.ly"
        png_path = base_path + "_render.png"

        with open(xml_path, "w") as f:
            f.write(musicxml)

        # MusicXML -> LilyPond
        result = subprocess.run(
            ["musicxml2ly", xml_path, "-o", ly_path],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if not os.path.exists(ly_path):
            print(f"[Render] musicxml2ly failed: {result.stderr[:200]}")
            return None

        # Add \midi block for MIDI generation
        ly_content = open(ly_path).read()
        ly_content = ly_content.replace("\\layout {}", "\\layout {} \\midi {}")
        with open(ly_path, "w") as f:
            f.write(ly_content)

        # LilyPond -> PNG
        result = subprocess.run(
            ["lilypond", "--png", "-dresolution=150", ly_path],
            capture_output=True,
            text=True,
            timeout=90,
            cwd=os.path.dirname(ly_path) or "/tmp",
        )

        # Find output PNG (may be -page1.png for multi-page)
        png_candidates = [png_path] + sorted(
            glob.glob(base_path + "_render-page*.png")
        )
        png_data = None
        for candidate in png_candidates:
            if os.path.exists(candidate):
                with open(candidate, "rb") as f:
                    png_data = f.read()
                os.unlink(candidate)
                break

        # Clean up
        for leftover in glob.glob(base_path + "_render-page*.png"):
            os.unlink(leftover)
        for path in [xml_path]:
            if os.path.exists(path):
                os.unlink(path)

        if png_data:
            print(f"[Render] PNG: {len(png_data)} bytes")
            return base64.b64encode(png_data).decode("ascii")
        else:
            print(f"[Render] LilyPond failed: {result.stderr[:200]}")
            return None
    except Exception as e:
        print(f"[Render] Error: {e}")
        return None


def render_to_midi(base_path: str) -> str | None:
    """Get MIDI if LilyPond generated it. Returns base64 string."""
    midi_path = base_path + "_render.midi"
    ly_path = base_path + "_render.ly"
    try:
        if os.path.exists(midi_path):
            with open(midi_path, "rb") as f:
                midi_data = f.read()
            os.unlink(midi_path)
            # Clean up
            for path in [ly_path, base_path + "_render.pdf"]:
                if os.path.exists(path):
                    os.unlink(path)
            print(f"[Render] MIDI: {len(midi_data)} bytes")
            return base64.b64encode(midi_data).decode("ascii")
    except Exception as e:
        print(f"[Render] MIDI error: {e}")
    return None
