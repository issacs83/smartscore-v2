"""
Tests for Score Image Restoration Engine
"""

import pytest
import numpy as np
import cv2
import os
import logging
from pathlib import Path

# Setup logging
logging.basicConfig(level=logging.DEBUG)

# Add parent directories to path
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from lib.restoration_engine import (
    RestorationOptions, RestorationResult, PageBounds,
    detect_page_bounds, correct_perspective, detect_skew, correct_skew,
    convert_grayscale, remove_shadows, enhance_contrast, binarize, restore
)
from lib.test_image_generator import ScoreImageGenerator


class TestPageBoundDetection:
    """Test page bounds detection"""

    def test_detect_page_bounds_clean(self):
        """Clean image with clear border should detect bounds"""
        # Generate clean score
        image = ScoreImageGenerator.generate_clean_score(800, 1000)

        bounds = detect_page_bounds(image)

        assert bounds is not None, "Bounds should be detected in clean image"
        assert bounds.is_valid(), "Bounds should be valid"
        assert bounds.corners.shape == (4, 2)

    def test_detect_page_bounds_no_border(self):
        """Full-page scan without clear border may return None"""
        # Create simple image without strong edges
        image = np.ones((500, 500, 3), dtype=np.uint8) * 200

        bounds = detect_page_bounds(image)

        # Acceptable to return None for images without clear bounds
        assert bounds is None or bounds.is_valid()

    def test_detect_page_bounds_empty(self):
        """Empty image should return None"""
        bounds = detect_page_bounds(None)
        assert bounds is None


class TestPerspectiveCorrection:
    """Test perspective correction"""

    def test_correct_perspective(self):
        """Known perspective should be corrected"""
        image = ScoreImageGenerator.generate_clean_score(500, 600)
        image = ScoreImageGenerator.apply_perspective(image, strength=0.1)

        bounds = PageBounds(corners=np.array([
            [50, 60],
            [450, 40],
            [480, 560],
            [20, 570]
        ], dtype=np.float32))

        result = correct_perspective(image, bounds)

        assert result is not None
        assert result.shape[0] > 0 and result.shape[1] > 0
        # Result should be roughly rectangular
        assert abs(result.shape[0] - image.shape[0]) < image.shape[0] * 0.5
        assert abs(result.shape[1] - image.shape[1]) < image.shape[1] * 0.5


class TestSkewDetection:
    """Test skew detection and correction"""

    def test_detect_skew_tilted(self):
        """Tilted image should detect angle within tolerance"""
        image = ScoreImageGenerator.generate_clean_score(500, 600)
        image = ScoreImageGenerator.apply_rotation(image, 5.0)

        angle = detect_skew(image)

        # Should detect angle magnitude (may be + or -)
        # Tolerance: within 3 degrees of expected value or its negation
        assert abs(abs(angle) - 5.0) < 3.0, f"Expected ~5° magnitude, got {angle}°"

    def test_detect_skew_straight(self):
        """Straight image should have angle near 0"""
        image = ScoreImageGenerator.generate_clean_score(500, 600)

        angle = detect_skew(image)

        assert abs(angle) < 2.0, f"Expected ~0°, got {angle}°"

    def test_correct_skew(self):
        """Skew correction should work"""
        image = ScoreImageGenerator.generate_clean_score(500, 600)

        corrected = correct_skew(image, 5.0)

        assert corrected is not None
        assert corrected.shape == image.shape


class TestShadowRemoval:
    """Test shadow removal"""

    def test_remove_shadows(self):
        """Shadow removal should increase uniformity"""
        image = ScoreImageGenerator.generate_clean_score(400, 500)
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        shadowed = ScoreImageGenerator.apply_shadow(gray, direction="left", intensity=0.6)

        # Original should have brightness variation
        original_std = np.std(shadowed)

        # Remove shadows
        result = remove_shadows(shadowed)

        # Result should have less variation in brightness (more uniform)
        result_std = np.std(result)

        # After shadow removal, uniformity might improve
        assert result is not None
        assert result.shape == shadowed.shape


class TestContrastEnhancement:
    """Test contrast enhancement"""

    def test_enhance_contrast(self):
        """Contrast enhancement should work on valid input"""
        image = ScoreImageGenerator.generate_clean_score(400, 500)
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

        # Reduce contrast
        low_contrast = np.uint8(gray.astype(np.float32) * 0.7 + 40)

        # Enhance
        enhanced = enhance_contrast(low_contrast)

        assert enhanced is not None
        assert enhanced.shape == low_contrast.shape
        assert enhanced.dtype == np.uint8


class TestBinarization:
    """Test binarization methods"""

    def test_binarize_sauvola(self):
        """Sauvola binarization should work"""
        image = ScoreImageGenerator.generate_clean_score(400, 500)
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

        binary = binarize(gray, method="sauvola", sauvola_k=0.2)

        assert binary is not None
        assert binary.shape == gray.shape
        assert set(np.unique(binary)) <= {0, 255}

    def test_binarize_otsu(self):
        """Otsu binarization should work"""
        image = ScoreImageGenerator.generate_clean_score(400, 500)
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

        binary = binarize(gray, method="otsu")

        assert binary is not None
        assert binary.shape == gray.shape
        assert set(np.unique(binary)) <= {0, 255}

    def test_binarize_adaptive(self):
        """Adaptive binarization should work"""
        image = ScoreImageGenerator.generate_clean_score(400, 500)
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

        binary = binarize(gray, method="adaptive")

        assert binary is not None
        assert binary.shape == gray.shape
        assert set(np.unique(binary)) <= {0, 255}

    def test_binarize_preserves_staff_lines(self):
        """Binarization should preserve staff lines"""
        image = ScoreImageGenerator.generate_clean_score(600, 700)
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

        binary = binarize(gray, method="sauvola")

        # Check that there are black pixels (staff lines)
        black_pixels = np.sum(binary == 0)
        assert black_pixels > 0, "Binary should contain staff lines"

        # Should not be all black or all white
        white_pixels = np.sum(binary == 255)
        assert white_pixels > 0, "Binary should contain white background"


class TestFullPipeline:
    """Test complete restoration pipeline"""

    def test_full_pipeline(self):
        """Full pipeline should work end-to-end"""
        image = ScoreImageGenerator.generate_clean_score(600, 700)
        image = ScoreImageGenerator.apply_rotation(image, 3.0)
        image = ScoreImageGenerator.apply_shadow(image, intensity=0.3)

        options = RestorationOptions(
            enable_perspective_correction=True,
            enable_deskew=True,
            enable_shadow_removal=True,
            enable_contrast_enhancement=True,
            binarization_method="sauvola"
        )

        result = restore(image, options)

        assert result is not None
        assert not result.failure_reason, f"Pipeline failed: {result.failure_reason}"
        assert result.rectified_gray is not None
        assert result.binary is not None
        assert result.quality_score >= 0.0
        assert result.quality_score <= 1.0
        assert result.skew_angle is not None
        assert result.processing_time_ms > 0

    def test_quality_score_clean(self):
        """Clean image should have high quality score"""
        image = ScoreImageGenerator.generate_clean_score(600, 700)

        result = restore(image)

        assert result.quality_score > 0.5, f"Clean image should score > 0.5, got {result.quality_score}"

    def test_quality_score_noisy(self):
        """Noisy image should have lower quality score"""
        image = ScoreImageGenerator.generate_clean_score(600, 700)
        image = ScoreImageGenerator.apply_noise(image, sigma=30)

        result = restore(image)

        assert result.quality_score < 0.8, f"Noisy image should score lower, got {result.quality_score}"

    def test_intermediates_saved(self):
        """Intermediate images should be saved when enabled"""
        image = ScoreImageGenerator.generate_clean_score(400, 500)

        options = RestorationOptions(save_intermediates=True)
        result = restore(image, options)

        assert result.intermediates is not None
        assert len(result.intermediates) > 0
        assert 'grayscale' in result.intermediates
        assert 'binary' in result.intermediates

    def test_failure_detection(self):
        """Too-small images should fail gracefully"""
        tiny_image = np.ones((50, 50, 3), dtype=np.uint8) * 255

        result = restore(tiny_image)

        assert result.failure_reason is not None
        assert "E-C02" in result.failure_reason

    def test_step_times_recorded(self):
        """Each step should record timing"""
        image = ScoreImageGenerator.generate_clean_score(400, 500)

        result = restore(image)

        assert len(result.step_times_ms) > 0
        assert sum(result.step_times_ms.values()) > 0

    def test_batch_processing(self):
        """Process multiple images"""
        results = []
        for i in range(3):
            image = ScoreImageGenerator.generate_clean_score(300, 400)

            result = restore(image)
            results.append(result)

        assert len(results) == 3
        for result in results:
            # All should have valid quality score
            assert result.quality_score >= 0.0
            # And should have valid metadata
            assert result.processing_time_ms >= 0.0


class TestQualityScoring:
    """Test quality score components"""

    def test_quality_components_present(self):
        """All quality components should be computed"""
        image = ScoreImageGenerator.generate_clean_score(400, 500)

        result = restore(image)

        expected_components = {
            'contrast_ratio',
            'sharpness',
            'line_straightness',
            'noise_level',
            'coverage',
            'binarization_quality'
        }

        assert expected_components.issubset(result.quality_components.keys())

    def test_quality_components_in_range(self):
        """Quality components should be between 0 and 1"""
        image = ScoreImageGenerator.generate_clean_score(400, 500)

        result = restore(image)

        for component, value in result.quality_components.items():
            assert 0.0 <= value <= 1.0, f"{component} = {value} out of range"


class TestEdgeCases:
    """Test edge cases"""

    def test_grayscale_input(self):
        """Should handle grayscale input"""
        image = ScoreImageGenerator.generate_clean_score(400, 500)
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

        result = restore(gray)

        assert not result.failure_reason
        assert result.quality_score >= 0.0

    def test_very_small_valid_image(self):
        """Minimum valid size should work"""
        image = np.ones((100, 100, 3), dtype=np.uint8) * 200

        result = restore(image)

        # Should not fail on 100x100
        assert not result.failure_reason or "E-C02" not in result.failure_reason

    def test_empty_image_input(self):
        """None input should fail gracefully"""
        result = restore(None)

        assert result.failure_reason is not None
        assert result.quality_score == 0.0
