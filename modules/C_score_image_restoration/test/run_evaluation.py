"""
Evaluation harness for Score Image Restoration Engine
Generates test images, runs restoration pipeline, and produces evaluation report
"""

import json
import os
import sys
import time
import numpy as np
import cv2
from pathlib import Path
from collections import defaultdict

# Add parent to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from lib.restoration_engine import restore, RestorationOptions
from lib.test_image_generator import ScoreImageGenerator


def run_evaluation():
    """Main evaluation function"""
    print("=" * 70)
    print("SCORE IMAGE RESTORATION ENGINE - EVALUATION")
    print("=" * 70)

    # Setup directories
    test_dir = os.path.join(os.path.dirname(__file__), 'test_images')
    report_dir = os.path.join(os.path.dirname(__file__), 'reports')
    intermediates_dir = os.path.join(report_dir, 'intermediates')

    Path(test_dir).mkdir(parents=True, exist_ok=True)
    Path(report_dir).mkdir(parents=True, exist_ok=True)
    Path(intermediates_dir).mkdir(parents=True, exist_ok=True)

    # Generate test images
    print("\n[1/4] Generating test images...")
    metadata = ScoreImageGenerator.generate_test_set(test_dir, count=20)
    print(f"  Generated {len(metadata)} test images")

    # Run restoration pipeline
    print("\n[2/4] Running restoration pipeline...")
    results = []
    per_image_results = []

    test_images = sorted([f for f in os.listdir(test_dir) if f.endswith('.png')])

    for idx, filename in enumerate(test_images, 1):
        filepath = os.path.join(test_dir, filename)

        # Load image
        image = cv2.imread(filepath)
        if image is None:
            print(f"  [{idx}/{len(test_images)}] {filename} - FAILED TO LOAD")
            continue

        print(f"  [{idx}/{len(test_images)}] {filename}...", end=" ", flush=True)

        # Restore with intermediate saving
        options = RestorationOptions(
            enable_perspective_correction=True,
            enable_deskew=True,
            enable_shadow_removal=True,
            enable_contrast_enhancement=True,
            binarization_method="sauvola",
            save_intermediates=True
        )

        result = restore(image, options)
        results.append(result)

        # Store per-image results
        img_result = {
            'filename': filename,
            'distortions': metadata[filename].get('distortions', []),
            'quality_score': result.quality_score,
            'quality_components': result.quality_components,
            'processing_time_ms': result.processing_time_ms,
            'step_times_ms': result.step_times_ms,
            'failure_reason': result.failure_reason,
            'skew_angle': result.skew_angle,
            'page_bounds_detected': result.page_bounds is not None
        }
        per_image_results.append(img_result)

        print(f"score={result.quality_score:.3f} time={result.processing_time_ms:.1f}ms")

        # Save intermediates
        if result.intermediates:
            img_base = os.path.splitext(filename)[0]
            img_dir = os.path.join(intermediates_dir, img_base)
            Path(img_dir).mkdir(parents=True, exist_ok=True)

            for step_name, step_image in result.intermediates.items():
                if step_image is not None and step_image.size > 0:
                    output_file = os.path.join(img_dir, f"{step_name}.png")
                    try:
                        cv2.imwrite(output_file, step_image)
                    except Exception as e:
                        print(f"    Warning: Could not save {step_name}: {e}")

    print(f"\n  Successfully processed {len([r for r in results if not r.failure_reason])}/{len(test_images)} images")

    # Compute aggregate statistics
    print("\n[3/4] Computing statistics...")

    successful_results = [r for r in results if not r.failure_reason]
    failed_results = [r for r in results if r.failure_reason]

    if successful_results:
        processing_times = [r.processing_time_ms for r in successful_results]
        quality_scores = [r.quality_score for r in successful_results]

        stats = {
            'total_images': len(results),
            'successful': len(successful_results),
            'failed': len(failed_results),
            'success_rate': len(successful_results) / len(results),
            'processing_time_ms': {
                'mean': float(np.mean(processing_times)),
                'median': float(np.median(processing_times)),
                'p95': float(np.percentile(processing_times, 95)),
                'p99': float(np.percentile(processing_times, 99)),
                'min': float(np.min(processing_times)),
                'max': float(np.max(processing_times))
            },
            'quality_score': {
                'mean': float(np.mean(quality_scores)),
                'median': float(np.median(quality_scores)),
                'std': float(np.std(quality_scores)),
                'min': float(np.min(quality_scores)),
                'max': float(np.max(quality_scores)),
                'p25': float(np.percentile(quality_scores, 25)),
                'p75': float(np.percentile(quality_scores, 75))
            }
        }

        # Compute per-component average
        component_averages = defaultdict(list)
        for r in successful_results:
            for component, value in r.quality_components.items():
                component_averages[component].append(value)

        stats['quality_components_avg'] = {
            component: float(np.mean(values))
            for component, values in component_averages.items()
        }

        # Step timing analysis
        step_timings = defaultdict(list)
        for r in successful_results:
            for step, time_ms in r.step_times_ms.items():
                step_timings[step].append(time_ms)

        stats['step_timings_ms'] = {
            step: {
                'mean': float(np.mean(times)),
                'max': float(np.max(times))
            }
            for step, times in step_timings.items()
        }

    else:
        stats = {
            'total_images': len(results),
            'successful': 0,
            'failed': len(failed_results),
            'success_rate': 0.0
        }

    # Build report
    print("\n[4/4] Generating report...")

    report = {
        'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
        'test_count': len(test_images),
        'statistics': stats,
        'per_image_results': per_image_results,
        'test_configuration': {
            'image_size': '2000x2800',
            'binarization_method': 'sauvola',
            'enable_perspective_correction': True,
            'enable_deskew': True,
            'enable_shadow_removal': True,
            'enable_contrast_enhancement': True
        }
    }

    # Save JSON report
    report_file = os.path.join(report_dir, 'evaluation_report.json')
    with open(report_file, 'w') as f:
        json.dump(report, f, indent=2)

    print(f"  Report saved: {report_file}")

    # Print summary
    print("\n" + "=" * 70)
    print("EVALUATION SUMMARY")
    print("=" * 70)

    print(f"\nTest Images: {stats['total_images']}")
    print(f"Successful: {stats['successful']}")
    print(f"Failed: {stats['failed']}")
    print(f"Success Rate: {stats.get('success_rate', 0)*100:.1f}%")

    if 'processing_time_ms' in stats:
        print(f"\nProcessing Time:")
        print(f"  Mean: {stats['processing_time_ms']['mean']:.1f}ms")
        print(f"  Median: {stats['processing_time_ms']['median']:.1f}ms")
        print(f"  P95: {stats['processing_time_ms']['p95']:.1f}ms")

        print(f"\nQuality Score:")
        print(f"  Mean: {stats['quality_score']['mean']:.3f}")
        print(f"  Median: {stats['quality_score']['median']:.3f}")
        print(f"  Range: [{stats['quality_score']['min']:.3f}, {stats['quality_score']['max']:.3f}]")

        print(f"\nQuality Components (Avg):")
        for component, value in sorted(stats['quality_components_avg'].items()):
            print(f"  {component}: {value:.3f}")

        print(f"\nStep Timing Breakdown (ms):")
        for step, timings in sorted(stats['step_timings_ms'].items()):
            print(f"  {step}: {timings['mean']:.1f}ms (max {timings['max']:.1f}ms)")

    print("\nIntermediates saved to:", intermediates_dir)
    print("\n" + "=" * 70)

    return report


if __name__ == '__main__':
    report = run_evaluation()
    sys.exit(0 if report['statistics'].get('success_rate', 0) > 0.8 else 1)
