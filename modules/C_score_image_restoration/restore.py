#!/usr/bin/env python3
"""
Score Image Restoration CLI Entry Point
Processes a single score image through the full restoration pipeline
"""

import argparse
import json
import sys
import cv2
import numpy as np
import logging
from pathlib import Path
from datetime import datetime

from lib.restoration_engine import RestorationOptions, restore

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def save_intermediate_images(intermediates: dict, output_dir: Path) -> dict:
    """Save intermediate images to disk and return file paths"""
    saved_paths = {}

    if intermediates is None:
        return saved_paths

    # Map of intermediate key to friendly filename
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
        if key in intermediates:
            img = intermediates[key]
            if img is not None and img.size > 0:
                filepath = output_dir / filename
                success = cv2.imwrite(str(filepath), img)
                if success:
                    saved_paths[key] = str(filepath)
                    logger.info(f"Saved: {filename}")

    return saved_paths


def main():
    parser = argparse.ArgumentParser(
        description='Score Image Restoration Pipeline',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 restore.py input.jpg --output-dir ./output/
  python3 restore.py photo.png --output-dir /tmp/results/ --no-perspective
  python3 restore.py score.jpg --output-dir results/ --binarization otsu
        """
    )

    parser.add_argument(
        'input_image',
        help='Path to input score image'
    )

    parser.add_argument(
        '--output-dir',
        type=str,
        default='./restoration_output/',
        help='Output directory for results (default: ./restoration_output/)'
    )

    parser.add_argument(
        '--no-perspective',
        action='store_true',
        help='Disable perspective correction'
    )

    parser.add_argument(
        '--no-deskew',
        action='store_true',
        help='Disable skew correction'
    )

    parser.add_argument(
        '--no-shadows',
        action='store_true',
        help='Disable shadow removal'
    )

    parser.add_argument(
        '--no-contrast',
        action='store_true',
        help='Disable contrast enhancement'
    )

    parser.add_argument(
        '--binarization',
        type=str,
        choices=['sauvola', 'otsu', 'adaptive'],
        default='sauvola',
        help='Binarization method (default: sauvola)'
    )

    parser.add_argument(
        '--sauvola-k',
        type=float,
        default=0.2,
        help='Sauvola k parameter (default: 0.2)'
    )

    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable debug logging'
    )

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Validate input
    input_path = Path(args.input_image)
    if not input_path.exists():
        logger.error(f"Input file not found: {input_path}")
        return 1

    if not input_path.is_file():
        logger.error(f"Input path is not a file: {input_path}")
        return 1

    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    logger.info(f"Output directory: {output_dir}")

    # Load image
    logger.info(f"Loading image: {input_path}")
    image = cv2.imread(str(input_path))

    if image is None:
        logger.error(f"Failed to read image: {input_path}")
        return 1

    logger.info(f"Image shape: {image.shape}")

    # Setup options
    options = RestorationOptions(
        enable_perspective_correction=not args.no_perspective,
        enable_deskew=not args.no_deskew,
        enable_shadow_removal=not args.no_shadows,
        enable_contrast_enhancement=not args.no_contrast,
        binarization_method=args.binarization,
        sauvola_k=args.sauvola_k,
        save_intermediates=True,
        output_dir=str(output_dir)
    )

    logger.info("Running restoration pipeline...")
    logger.info(f"  - Perspective: {options.enable_perspective_correction}")
    logger.info(f"  - Deskew: {options.enable_deskew}")
    logger.info(f"  - Shadow removal: {options.enable_shadow_removal}")
    logger.info(f"  - Contrast enhancement: {options.enable_contrast_enhancement}")
    logger.info(f"  - Binarization: {options.binarization_method}")

    # Run restoration
    result = restore(image, options)

    # Check for failures
    if result.failure_reason:
        logger.error(f"Restoration failed: {result.failure_reason}")
        return 1

    logger.info(f"Restoration completed in {result.processing_time_ms:.2f}ms")

    # Save intermediate images
    intermediate_paths = save_intermediate_images(result.intermediates, output_dir)

    # Save binary output
    binary_path = output_dir / 'binary_final.png'
    cv2.imwrite(str(binary_path), result.binary)
    logger.info(f"Saved binary output: {binary_path}")

    # Save grayscale output
    grayscale_path = output_dir / 'grayscale_final.png'
    cv2.imwrite(str(grayscale_path), result.rectified_gray)
    logger.info(f"Saved grayscale output: {grayscale_path}")

    # Prepare quality score report
    quality_report = {
        'timestamp': datetime.now().isoformat(),
        'input_image': str(input_path.name),
        'input_shape': list(image.shape),
        'output_shape': list(result.binary.shape),
        'quality_score': float(result.quality_score),
        'quality_components': {
            k: float(v) for k, v in result.quality_components.items()
        },
        'skew_angle_degrees': float(result.skew_angle),
        'page_detected': result.page_bounds is not None,
        'processing_time_ms': float(result.processing_time_ms),
        'step_times_ms': {
            k: float(v) for k, v in result.step_times_ms.items()
        },
        'options': {
            'perspective_correction': options.enable_perspective_correction,
            'deskew': options.enable_deskew,
            'shadow_removal': options.enable_shadow_removal,
            'contrast_enhancement': options.enable_contrast_enhancement,
            'binarization_method': options.binarization_method,
            'sauvola_k': options.sauvola_k
        },
        'intermediate_images': intermediate_paths,
        'output_paths': {
            'binary': str(binary_path),
            'grayscale': str(grayscale_path)
        }
    }

    # Save quality score JSON
    quality_path = output_dir / 'quality_score.json'
    with open(quality_path, 'w') as f:
        json.dump(quality_report, f, indent=2)
    logger.info(f"Saved quality report: {quality_path}")

    # Print summary
    print("\n" + "="*70)
    print("RESTORATION SUMMARY")
    print("="*70)
    print(f"Input:             {input_path.name}")
    print(f"Input shape:       {image.shape[0]}x{image.shape[1]}")
    print(f"Output shape:      {result.binary.shape[0]}x{result.binary.shape[1]}")
    print(f"\nQuality Score:     {result.quality_score:.3f} / 1.000")
    print(f"\nQuality Components:")
    for component, value in sorted(result.quality_components.items()):
        print(f"  {component:20s}: {value:.3f}")
    print(f"\nSkew angle:        {result.skew_angle:.2f}°")
    print(f"Page detected:     {'Yes' if result.page_bounds else 'No'}")
    print(f"\nProcessing Time:   {result.processing_time_ms:.2f}ms")
    print(f"\nStep Times:")
    for step, duration in sorted(result.step_times_ms.items()):
        print(f"  {step:20s}: {duration:8.2f}ms")
    print(f"\nOutputs saved to:  {output_dir}")
    print(f"  - binary_final.png")
    print(f"  - grayscale_final.png")
    for key in sorted(intermediate_paths.keys()):
        print(f"  - {Path(intermediate_paths[key]).name}")
    print(f"  - quality_score.json")
    print("="*70)

    return 0


if __name__ == '__main__':
    sys.exit(main())
