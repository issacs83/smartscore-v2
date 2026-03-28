"""OMR engine wrapper — homr / Audiveris."""

import os
import shutil
import subprocess
import tempfile
import traceback

# Try to import homr
_homr_available = False
try:
    from homr.main import process_image, download_weights, ProcessingConfig
    from homr.music_xml_generator import XmlGeneratorArguments

    _homr_available = True
    print("[OMR] homr engine loaded successfully")
    try:
        download_weights(use_gpu_inference=False)
        print("[OMR] Model weights ready")
    except Exception as e:
        print(f"[OMR] Weight download note: {e}")
except ImportError as e:
    print(f"[OMR] homr not available: {e}")

# Fallback: Audiveris CLI
_audiveris_available = False
if not _homr_available:
    if shutil.which("audiveris"):
        _audiveris_available = True
        print("[OMR] Audiveris CLI found")


def get_engine_name() -> str:
    if _homr_available:
        return "homr"
    if _audiveris_available:
        return "audiveris"
    return "none"


def is_available() -> bool:
    return _homr_available or _audiveris_available


def run_omr(image_path: str) -> str | None:
    """Run OMR on an image file and return MusicXML string."""
    if _homr_available:
        return _run_homr(image_path)
    if _audiveris_available:
        return _run_audiveris(image_path)
    raise RuntimeError("No OMR engine available. Install homr: pip3 install homr")


def _detect_gpu() -> bool:
    """Check if CUDA GPU is available for homr inference (requires onnxruntime-gpu)."""
    try:
        import torch
        if not torch.cuda.is_available():
            return False
        # Also check if onnxruntime has GPU support
        import onnxruntime as ort
        providers = ort.get_available_providers()
        has_cuda = "CUDAExecutionProvider" in providers
        if has_cuda:
            print(f"[OMR] GPU detected: {torch.cuda.get_device_name(0)} (ONNX CUDA provider available)")
        else:
            print(f"[OMR] GPU detected: {torch.cuda.get_device_name(0)} but onnxruntime lacks CUDA provider — using CPU")
        return has_cuda
    except Exception:
        return False


_use_gpu = _detect_gpu()


def _run_homr(image_path: str) -> str | None:
    output_path = image_path.rsplit(".", 1)[0] + ".musicxml"
    try:
        config = ProcessingConfig(
            enable_debug=False,
            enable_cache=False,
            write_staff_positions=False,
            read_staff_positions=False,
            selected_staff=-1,
            use_gpu_inference=_use_gpu,
        )
        xml_args = XmlGeneratorArguments()
        process_image(image_path, config, xml_args)

        if os.path.exists(output_path):
            with open(output_path) as f:
                content = f.read()
            os.unlink(output_path)
            return _fix_musicxml(content)

        # Try alternative output paths
        for ext in [".musicxml", ".xml", "_output.musicxml"]:
            alt_path = image_path.rsplit(".", 1)[0] + ext
            if os.path.exists(alt_path):
                with open(alt_path) as f:
                    result = f.read()
                os.unlink(alt_path)
                return _fix_musicxml(result)
    except Exception as e:
        print(f"[OMR] homr error: {e}")
        traceback.print_exc()
        raise
    return None


def _run_audiveris(image_path: str) -> str | None:
    with tempfile.TemporaryDirectory() as outdir:
        cmd = ["audiveris", "-batch", "-export", "-output", outdir, image_path]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if result.returncode != 0:
            raise RuntimeError(f"Audiveris failed: {result.stderr}")
        for f in os.listdir(outdir):
            if f.endswith((".xml", ".musicxml")):
                with open(os.path.join(outdir, f)) as fh:
                    return fh.read()
    return None


def _fix_musicxml(content: str) -> str:
    """Fix MusicXML: header fixes + duration repair via music21."""
    # Basic header fixes
    if not content.strip().startswith("<?xml"):
        content = '<?xml version="1.0" encoding="UTF-8"?>\n' + content
    content = content.replace("<score-partwise>", '<score-partwise version="3.1">')
    content = content.replace("<defaults />", "")
    content = content.replace("<defaults/>", "")

    # Repair measure durations via music21
    try:
        from musicxml_repair import repair
        content = repair(content)
    except Exception as e:
        print(f"[OMR] MusicXML repair skipped: {e}")

    return content
