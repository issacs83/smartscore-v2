"""
Quality scoring for restored score images
Computes multiple quality metrics that are combined into a single score
"""

import numpy as np
import cv2
import logging

logger = logging.getLogger(__name__)


class QualityScorer:
    """Computes quality metrics for score images"""

    def __init__(self):
        self.weights = {
            'contrast_ratio': 0.25,
            'sharpness': 0.20,
            'line_straightness': 0.20,
            'noise_level': 0.15,
            'coverage': 0.10,
            'binarization_quality': 0.10
        }

    def compute_score(self, binary: np.ndarray,
                     grayscale: np.ndarray) -> tuple:
        """
        Compute overall quality score

        Args:
            binary: Binary image (0 or 255)
            grayscale: Grayscale image (0-255)

        Returns:
            (score: float [0-1], components: dict)
        """
        if binary is None or binary.size == 0:
            return 0.0, {}

        try:
            components = {}

            # Contrast ratio
            components['contrast_ratio'] = self._compute_contrast_ratio(binary)

            # Sharpness
            components['sharpness'] = self._compute_sharpness(grayscale)

            # Line straightness
            components['line_straightness'] = self._compute_line_straightness(binary)

            # Noise level
            components['noise_level'] = self._compute_noise_level(grayscale)

            # Coverage
            components['coverage'] = self._compute_coverage(binary)

            # Binarization quality
            components['binarization_quality'] = self._compute_binarization_quality(
                binary, grayscale)

            # Weighted average
            score = sum(components[key] * self.weights[key]
                       for key in self.weights.keys())
            score = np.clip(score, 0.0, 1.0)

            logger.debug(f"Quality score: {score:.3f} - {components}")

            return float(score), components

        except Exception as e:
            logger.warning(f"Quality scoring failed: {e}")
            return 0.0, {}

    def _compute_contrast_ratio(self, binary: np.ndarray) -> float:
        """
        Contrast ratio: difference between background and foreground

        Returns: 0.0-1.0
        """
        try:
            # Separate foreground (black=0) and background (white=255)
            fg_mask = binary == 0
            bg_mask = binary == 255

            if not np.any(fg_mask) or not np.any(bg_mask):
                return 0.1

            # In binary, contrast is just the difference
            # More well-separated = higher score
            contrast = 1.0  # Binary is perfectly contrasted
            return float(np.clip(contrast, 0.0, 1.0))

        except Exception as e:
            logger.warning(f"Contrast ratio computation failed: {e}")
            return 0.5

    def _compute_sharpness(self, grayscale: np.ndarray) -> float:
        """
        Sharpness using Laplacian variance

        Returns: 0.0-1.0
        """
        try:
            if grayscale.size == 0:
                return 0.0

            # Convert to uint8 if needed
            img = grayscale.astype(np.uint8) if grayscale.dtype != np.uint8 else grayscale

            # Compute Laplacian
            laplacian = cv2.Laplacian(img, cv2.CV_64F)
            variance = np.var(laplacian)

            # Normalize: typical variance for clear text is 200-500+
            # Map to 0-1 range
            sharpness = min(variance / 500.0, 1.0)
            return float(np.clip(sharpness, 0.0, 1.0))

        except Exception as e:
            logger.warning(f"Sharpness computation failed: {e}")
            return 0.5

    def _compute_line_straightness(self, binary: np.ndarray) -> float:
        """
        Line straightness by detecting horizontal lines and checking angle variance

        Returns: 0.0-1.0
        """
        try:
            if binary.size == 0:
                return 0.5

            # Invert for line detection
            inv_binary = cv2.bitwise_not(binary)

            height, width = binary.shape
            min_line_length = int(width * 0.2)

            # HoughLinesP
            lines = cv2.HoughLinesP(inv_binary, rho=1, theta=np.pi/180,
                                   threshold=50, minLineLength=min_line_length,
                                   maxLineGap=10)

            if lines is None or len(lines) < 2:
                return 0.5

            # Extract angles for near-horizontal lines
            angles = []
            for line in lines:
                x1, y1, x2, y2 = line[0]
                angle = np.arctan2(y2 - y1, x2 - x1) * 180 / np.pi

                if angle < -90:
                    angle += 180
                if angle > 90:
                    angle -= 180

                if abs(angle) < 30:  # Near horizontal
                    angles.append(angle)

            if not angles:
                return 0.5

            # Lower variance = straighter lines
            angle_variance = np.var(angles)
            straightness = max(0.0, 1.0 - angle_variance * 10)
            return float(np.clip(straightness, 0.0, 1.0))

        except Exception as e:
            logger.warning(f"Line straightness computation failed: {e}")
            return 0.5

    def _compute_noise_level(self, grayscale: np.ndarray) -> float:
        """
        Noise level using high-pass filter

        Returns: 0.0-1.0
        """
        try:
            if grayscale.size == 0:
                return 0.0

            # Convert to uint8 if needed
            img = grayscale.astype(np.uint8) if grayscale.dtype != np.uint8 else grayscale

            # High-pass filter using Laplacian
            laplacian = cv2.Laplacian(img, cv2.CV_64F)
            noise_energy = np.mean(np.abs(laplacian))

            # Typical noise energy for clear images: < 50
            # For noisy images: > 100
            # Score inversely: less noise = higher score
            noise_score = max(0.0, 1.0 - noise_energy / 100.0)
            return float(np.clip(noise_score, 0.0, 1.0))

        except Exception as e:
            logger.warning(f"Noise level computation failed: {e}")
            return 0.5

    def _compute_coverage(self, binary: np.ndarray) -> float:
        """
        Coverage: ratio of foreground (non-white) pixels

        Returns: 0.0-1.0
        """
        try:
            if binary.size == 0:
                return 0.0

            # Count non-white pixels
            fg_pixels = np.sum(binary < 128)
            total_pixels = binary.size

            coverage_ratio = fg_pixels / total_pixels if total_pixels > 0 else 0

            # For score pages, expect 20-60% coverage
            # Penalize if too little or too much
            if coverage_ratio < 0.05:
                return 0.1  # Too little content
            if coverage_ratio > 0.7:
                return 0.5  # Too much noise or poor binarization

            # Optimal range 0.15-0.5
            if coverage_ratio < 0.15:
                score = coverage_ratio / 0.15 * 0.7
            elif coverage_ratio < 0.5:
                score = 0.7 + (coverage_ratio - 0.15) / 0.35 * 0.3
            else:
                score = 1.0 - (coverage_ratio - 0.5) / 0.2 * 0.5
                score = max(0.5, score)

            return float(np.clip(score, 0.0, 1.0))

        except Exception as e:
            logger.warning(f"Coverage computation failed: {e}")
            return 0.5

    def _compute_binarization_quality(self, binary: np.ndarray,
                                     grayscale: np.ndarray) -> float:
        """
        Binarization quality by comparing with alternative thresholding method

        Returns: 0.0-1.0
        """
        try:
            if binary.size == 0 or grayscale.size == 0:
                return 0.0

            # Alternative binarization using Otsu
            _, otsu_binary = cv2.threshold(grayscale, 0, 255,
                                          cv2.THRESH_BINARY + cv2.THRESH_OTSU)

            # Compare: higher agreement = better
            agreement = np.mean(binary == otsu_binary)

            # Also check adaptive threshold
            adaptive_binary = cv2.adaptiveThreshold(grayscale, 255,
                                                   cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                                   cv2.THRESH_BINARY, 31, 10)

            agreement_adaptive = np.mean(binary == adaptive_binary)

            # Average agreement with alternatives
            quality = (agreement + agreement_adaptive) / 2.0
            return float(np.clip(quality, 0.0, 1.0))

        except Exception as e:
            logger.warning(f"Binarization quality computation failed: {e}")
            return 0.5
