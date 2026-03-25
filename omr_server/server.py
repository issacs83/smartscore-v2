#!/usr/bin/env python3
"""
SmartScore OMR Server
Accepts music score images → returns MusicXML via homr engine.

Usage:
  python3 server.py [--port 5000] [--host 0.0.0.0]

API:
  POST /omr
    Body: multipart/form-data with 'image' file
    Returns: { "musicxml": "<xml>...", "success": true }
    Error:   { "error": "...", "success": false }

  GET /health
    Returns: { "status": "ready", "engine": "homr" }
"""

import argparse
import io
import os
import sys
import tempfile
import traceback
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import cgi

# Try to import homr
_homr_available = False
try:
    from homr.main import process_image, download_weights, ProcessingConfig
    from homr.music_xml_generator import XmlGeneratorArguments
    _homr_available = True
    print("[OMR] homr engine loaded successfully")
    # Download model weights if not present
    try:
        download_weights(use_gpu_inference=False)
        print("[OMR] Model weights ready")
    except Exception as e:
        print(f"[OMR] Weight download note: {e}")
except ImportError as e:
    print(f"[OMR] homr not available: {e}")
    print("[OMR] Install with: pip3 install homr")

# Fallback: try Audiveris CLI
_audiveris_available = False
if not _homr_available:
    import shutil
    if shutil.which("audiveris"):
        _audiveris_available = True
        print("[OMR] Audiveris CLI found")


class OMRHandler(BaseHTTPRequestHandler):
    """HTTP request handler for OMR API."""

    def do_GET(self):
        if self.path == "/health":
            engine = "homr" if _homr_available else ("audiveris" if _audiveris_available else "none")
            self._json_response({
                "status": "ready" if (_homr_available or _audiveris_available) else "no_engine",
                "engine": engine,
            })
        else:
            self._json_response({"error": "Not found"}, 404)

    def do_POST(self):
        if self.path != "/omr":
            self._json_response({"error": "Not found"}, 404)
            return

        try:
            # Parse multipart form data
            content_type = self.headers.get("Content-Type", "")
            if "multipart/form-data" not in content_type:
                self._json_response({"error": "Content-Type must be multipart/form-data", "success": False}, 400)
                return

            form = cgi.FieldStorage(
                fp=self.rfile,
                headers=self.headers,
                environ={
                    "REQUEST_METHOD": "POST",
                    "CONTENT_TYPE": content_type,
                },
            )

            if "image" not in form:
                self._json_response({"error": "Missing 'image' field", "success": False}, 400)
                return

            file_item = form["image"]
            if not file_item.file:
                self._json_response({"error": "Empty file", "success": False}, 400)
                return

            image_data = file_item.file.read()
            filename = file_item.filename or "score.png"

            print(f"[OMR] Processing image: {filename} ({len(image_data)} bytes)")

            # Save to temp file
            suffix = os.path.splitext(filename)[1] or ".png"
            with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
                tmp.write(image_data)
                tmp_path = tmp.name

            try:
                musicxml = self._run_omr(tmp_path)
                if musicxml:
                    print(f"[OMR] Success: {len(musicxml)} chars MusicXML")

                    # Also render to PNG via LilyPond
                    png_b64 = self._render_to_png(musicxml, tmp_path)

                    response = {"musicxml": musicxml, "success": True}
                    if png_b64:
                        response["png_base64"] = png_b64
                        response["has_rendered_image"] = True

                    # Also generate MIDI
                    midi_b64 = self._render_to_midi(tmp_path)
                    if midi_b64:
                        response["midi_base64"] = midi_b64

                    self._json_response(response)
                else:
                    self._json_response({"error": "OMR produced no output", "success": False}, 500)
            finally:
                os.unlink(tmp_path)

        except Exception as e:
            traceback.print_exc()
            self._json_response({"error": str(e), "success": False}, 500)

    def _run_omr(self, image_path):
        """Run OMR engine on the image file."""
        if _homr_available:
            return self._run_homr(image_path)
        elif _audiveris_available:
            return self._run_audiveris(image_path)
        else:
            raise RuntimeError("No OMR engine available. Install homr: pip3 install homr")

    def _run_homr(self, image_path):
        """Run homr OMR engine."""
        # process_image writes MusicXML to a file
        output_path = image_path.rsplit(".", 1)[0] + ".musicxml"
        try:
            config = ProcessingConfig(
                enable_debug=False,
                enable_cache=False,
                write_staff_positions=False,
                read_staff_positions=False,
                selected_staff=-1,
                use_gpu_inference=False,
            )
            xml_args = XmlGeneratorArguments()
            process_image(image_path, config, xml_args)
            # homr writes output next to input file with .musicxml extension
            if os.path.exists(output_path):
                with open(output_path) as f:
                    content = f.read()
                os.unlink(output_path)
                # Fix MusicXML for Verovio compatibility
                if not content.strip().startswith('<?xml'):
                    content = '<?xml version="1.0" encoding="UTF-8"?>\n' + content
                # Add version attribute if missing
                content = content.replace(
                    '<score-partwise>',
                    '<score-partwise version="3.1">'
                )
                # Remove empty defaults that cause issues
                content = content.replace('<defaults />', '')
                content = content.replace('<defaults/>', '')
                return content
            # Try other possible output paths
            for ext in [".musicxml", ".xml", "_output.musicxml"]:
                alt_path = image_path.rsplit(".", 1)[0] + ext
                if os.path.exists(alt_path):
                    with open(alt_path) as f:
                        result = f.read()
                    os.unlink(alt_path)
                    return result
        except Exception as e:
            print(f"[OMR] homr error: {e}")
            traceback.print_exc()
            raise
        return None

    def _run_audiveris(self, image_path):
        """Run Audiveris CLI."""
        import subprocess
        with tempfile.TemporaryDirectory() as outdir:
            cmd = [
                "audiveris", "-batch",
                "-export",
                "-output", outdir,
                image_path
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            if result.returncode != 0:
                raise RuntimeError(f"Audiveris failed: {result.stderr}")

            # Find output MusicXML
            for f in os.listdir(outdir):
                if f.endswith(".xml") or f.endswith(".musicxml"):
                    with open(os.path.join(outdir, f)) as fh:
                        return fh.read()
        return None

    def _render_to_png(self, musicxml, image_path):
        """Render MusicXML to PNG via LilyPond."""
        import base64
        import subprocess
        try:
            base_path = image_path.rsplit(".", 1)[0]
            xml_path = base_path + "_render.xml"
            ly_path = base_path + "_render.ly"
            png_path = base_path + "_render.png"

            with open(xml_path, "w") as f:
                f.write(musicxml)

            # MusicXML → LilyPond
            result = subprocess.run(
                ["musicxml2ly", xml_path, "-o", ly_path],
                capture_output=True, text=True, timeout=30
            )

            if not os.path.exists(ly_path):
                print(f"[Render] musicxml2ly failed: {result.stderr[:200]}")
                return None

            # Add \midi block for MIDI generation
            ly_content = open(ly_path).read()
            ly_content = ly_content.replace('\\layout {}', '\\layout {} \\midi {}')
            with open(ly_path, 'w') as f:
                f.write(ly_content)

            # LilyPond → PNG
            result = subprocess.run(
                ["lilypond", "--png", "-dresolution=150", ly_path],
                capture_output=True, text=True, timeout=60,
                cwd=os.path.dirname(ly_path) or "/tmp"
            )

            if os.path.exists(png_path):
                with open(png_path, "rb") as f:
                    png_data = f.read()
                os.unlink(png_path)
                os.unlink(xml_path)
                print(f"[Render] PNG: {len(png_data)} bytes")
                return base64.b64encode(png_data).decode("ascii")
            else:
                print(f"[Render] LilyPond failed: {result.stderr[:200]}")
                # Cleanup
                for p in [xml_path]:
                    if os.path.exists(p): os.unlink(p)
                return None
        except Exception as e:
            print(f"[Render] Error: {e}")
            return None

    def _render_to_midi(self, image_path):
        """Get MIDI if LilyPond generated it."""
        import base64
        base_path = image_path.rsplit(".", 1)[0]
        midi_path = base_path + "_render.midi"
        ly_path = base_path + "_render.ly"
        try:
            if os.path.exists(midi_path):
                with open(midi_path, "rb") as f:
                    midi_data = f.read()
                os.unlink(midi_path)
                if os.path.exists(ly_path): os.unlink(ly_path)
                # Clean up PDF if generated
                pdf_path = base_path + "_render.pdf"
                if os.path.exists(pdf_path): os.unlink(pdf_path)
                print(f"[Render] MIDI: {len(midi_data)} bytes")
                return base64.b64encode(midi_data).decode("ascii")
        except Exception as e:
            print(f"[Render] MIDI error: {e}")
        return None

    def _json_response(self, data, status=200):
        """Send JSON response with CORS headers."""
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def log_message(self, format, *args):
        print(f"[OMR] {args[0]}")


def main():
    parser = argparse.ArgumentParser(description="SmartScore OMR Server")
    parser.add_argument("--port", type=int, default=5000, help="Port (default: 5000)")
    parser.add_argument("--host", default="0.0.0.0", help="Host (default: 0.0.0.0)")
    args = parser.parse_args()

    server = HTTPServer((args.host, args.port), OMRHandler)
    print(f"[OMR] Server starting on {args.host}:{args.port}")

    if _homr_available:
        print("[OMR] Engine: homr (MIT)")
    elif _audiveris_available:
        print("[OMR] Engine: Audiveris (AGPL)")
    else:
        print("[OMR] WARNING: No engine available! Install homr: pip3 install homr")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[OMR] Server stopped")
        server.server_close()


if __name__ == "__main__":
    main()
