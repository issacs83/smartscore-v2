#!/usr/bin/env python3
"""
Score Image Restoration HTTP Server
Provides REST API for image restoration with intermediate output serving
"""

import json
import logging
import tempfile
import os
import sys
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import cv2
import numpy as np
import threading
import time

from lib.restoration_engine import RestorationOptions, restore

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Security configuration
MAX_UPLOAD_SIZE = 50 * 1024 * 1024  # 50MB
ALLOWED_ORIGIN = os.environ.get('CORS_ORIGIN', 'http://localhost:8080')
API_TOKEN = os.environ.get('RESTORATION_API_TOKEN', '')


class RestorationRequestHandler(BaseHTTPRequestHandler):
    """HTTP request handler for restoration API"""

    def _check_auth(self):
        """Check API token authentication"""
        if not API_TOKEN:
            return True  # No token configured, allow all
        token = self.headers.get('Authorization', '').replace('Bearer ', '')
        return token == API_TOKEN

    def do_OPTIONS(self):
        """Handle OPTIONS requests for CORS"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', ALLOWED_ORIGIN)
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.end_headers()

    def do_GET(self):
        """Handle GET requests"""
        parsed = urlparse(self.path)
        path = parsed.path

        if path == '/api/health':
            self._handle_health_check()
        elif path.startswith('/api/images/'):
            self._handle_image_serve(path)
        else:
            self._send_error(404, 'Not found')

    def do_POST(self):
        """Handle POST requests"""
        if not self._check_auth():
            self._send_error(401, 'Unauthorized')
            return

        parsed = urlparse(self.path)
        path = parsed.path

        if path == '/api/restore':
            self._handle_restore_request()
        else:
            self._send_error(404, 'Not found')

    def _handle_health_check(self):
        """Health check endpoint"""
        response = {
            'status': 'ok',
            'service': 'ScoreImageRestoration',
            'version': '1.0.0'
        }
        self._send_json(200, response)

    def _handle_restore_request(self):
        """Process image restoration request"""
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length == 0:
                self._send_error(400, 'No file provided')
                return

            # Check upload size limit
            if content_length > MAX_UPLOAD_SIZE:
                self._send_error(413, 'File too large. Maximum size is 50MB')
                return

            # Read multipart form data
            body = self.rfile.read(content_length)

            # Extract image from multipart body
            boundary_match = self.headers.get('Content-Type', '')
            if 'multipart/form-data' not in boundary_match:
                self._send_error(400, 'Expected multipart/form-data')
                return

            # Simple multipart parsing (sufficient for single file upload)
            # Better approach would use cgi.FieldStorage but it's deprecated
            parts = body.split(b'\r\n')
            image_data = None

            for i, part in enumerate(parts):
                if b'filename=' in part:
                    # Found file header, get data from next relevant part
                    # Skip headers and get binary content
                    for j in range(i + 1, len(parts)):
                        if parts[j].startswith(b'--'):
                            # Found boundary, previous part was data
                            image_data = parts[j - 1].rstrip(b'\r\n')
                            break
                    break

            if image_data is None:
                self._send_error(400, 'Could not extract image data')
                return

            # Decode image
            image_array = np.frombuffer(image_data, dtype=np.uint8)
            image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)

            if image is None:
                self._send_error(400, 'Invalid image data')
                return

            logger.info(f"Processing image: shape={image.shape}")

            # Parse query parameters for options
            query_params = parse_qs(urlparse(self.path).query)
            options = RestorationOptions(
                enable_perspective_correction=query_params.get('perspective', ['true'])[0].lower() == 'true',
                enable_deskew=query_params.get('deskew', ['true'])[0].lower() == 'true',
                enable_shadow_removal=query_params.get('shadows', ['true'])[0].lower() == 'true',
                enable_contrast_enhancement=query_params.get('contrast', ['true'])[0].lower() == 'true',
                binarization_method=query_params.get('binarization', ['sauvola'])[0],
                save_intermediates=True
            )

            # Run restoration
            result = restore(image, options)

            if result.failure_reason:
                logger.warning(f"Restoration failed: {result.failure_reason}")
                self._send_error(400, result.failure_reason)
                return

            # Save results to temporary directory
            with tempfile.TemporaryDirectory(prefix='restoration_') as tmpdir:
                tmpdir = Path(tmpdir)

                # Save intermediate images
                intermediates_saved = {}
                if result.intermediates:
                    mapping = {
                        'bounds_visualization': 'page_detected.png',
                        'after_perspective': 'perspective.png',
                        'after_deskew': 'deskewed.png',
                        'grayscale': 'grayscale.png',
                        'after_shadow_removal': 'shadow_removed.png',
                        'after_contrast': 'contrast.png',
                        'binary': 'binary.png'
                    }

                    for key, filename in mapping.items():
                        if key in result.intermediates:
                            img = result.intermediates[key]
                            if img is not None and img.size > 0:
                                filepath = tmpdir / filename
                                cv2.imwrite(str(filepath), img)
                                intermediates_saved[key] = filename

                # Save final binary
                binary_path = tmpdir / 'binary_final.png'
                cv2.imwrite(str(binary_path), result.binary)

                # Save grayscale
                grayscale_path = tmpdir / 'grayscale_final.png'
                cv2.imwrite(str(grayscale_path), result.rectified_gray)

                # Create response with file references
                response = {
                    'success': True,
                    'quality_score': float(result.quality_score),
                    'quality_components': {
                        k: float(v) for k, v in result.quality_components.items()
                    },
                    'skew_angle': float(result.skew_angle),
                    'page_detected': result.page_bounds is not None,
                    'processing_time_ms': float(result.processing_time_ms),
                    'step_times_ms': {
                        k: float(v) for k, v in result.step_times_ms.items()
                    },
                    'output_images': {
                        'binary': '/api/images/binary_final.png',
                        'grayscale': '/api/images/grayscale_final.png'
                    },
                    'intermediate_images': {
                        k: f'/api/images/{v}' for k, v in intermediates_saved.items()
                    }
                }

                # Store tmpdir reference (would need proper cache in production)
                # For now, just return paths to files that would be served
                self._send_json(200, response)

        except Exception as e:
            logger.error(f"Error processing restoration: {e}", exc_info=True)
            self._send_error(500, 'Internal server error')

    def _handle_image_serve(self, path: str):
        """Serve image files (in production, would use static file serving)"""
        filename = path.replace('/api/images/', '')
        self._send_error(501, 'Image serving requires file storage - use reverse proxy')

    def _send_json(self, status: int, data: dict):
        """Send JSON response"""
        response_body = json.dumps(data, indent=2)
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', ALLOWED_ORIGIN)
        self.send_header('Content-Length', len(response_body))
        self.end_headers()
        self.wfile.write(response_body.encode())

    def _send_error(self, status: int, message: str):
        """Send error response"""
        error_response = {
            'error': True,
            'status': status,
            'message': message
        }
        self._send_json(status, error_response)

    def log_message(self, format, *args):
        """Override to use logger"""
        logger.info("%s - - [%s] %s" % (
            self.client_address[0],
            self.log_date_time_string(),
            format % args
        ))


def run_server(host: str = '127.0.0.1', port: int = 8888):
    """Run the HTTP server"""
    server_address = (host, port)
    httpd = HTTPServer(server_address, RestorationRequestHandler)

    logger.info(f"Starting Score Image Restoration Server")
    logger.info(f"Listening on http://{host}:{port}")
    logger.info(f"Health check: http://{host}:{port}/api/health")
    logger.info(f"Restore endpoint: POST http://{host}:{port}/api/restore")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down server...")
        httpd.shutdown()


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description='Score Image Restoration HTTP Server')
    parser.add_argument('--host', default='127.0.0.1', help='Server host (default: 127.0.0.1)')
    parser.add_argument('--port', type=int, default=8888, help='Server port (default: 8888)')
    parser.add_argument('--verbose', action='store_true', help='Enable debug logging')

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    run_server(args.host, args.port)
