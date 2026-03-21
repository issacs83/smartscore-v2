"""
Score Image Restoration Engine - Core restoration pipeline
Handles perspective correction, deskewing, shadow removal, contrast enhancement, and binarization
"""

import numpy as np
import cv2
import time
from dataclasses import dataclass, field, asdict
from typing import Dict, Tuple, List, Optional
import logging

logger = logging.getLogger(__name__)


@dataclass
class PageBounds:
    """Represents the 4 corner points of a detected page"""
    corners: np.ndarray  # shape (4, 2), dtype float32

    def is_valid(self) -> bool:
        """Check if bounds are valid"""
        return (self.corners is not None and
                self.corners.shape == (4, 2) and
                np.all(np.isfinite(self.corners)))


@dataclass
class RestorationOptions:
    """Configuration for restoration pipeline"""
    enable_perspective_correction: bool = True
    enable_deskew: bool = True
    enable_shadow_removal: bool = True
    enable_contrast_enhancement: bool = True
    binarization_method: str = "sauvola"  # "sauvola" | "otsu" | "adaptive"
    sauvola_k: float = 0.2
    save_intermediates: bool = False
    output_dir: str = None


@dataclass
class RestorationResult:
    """Result of image restoration"""
    rectified_gray: np.ndarray  # uint8 grayscale
    binary: np.ndarray  # uint8 (0 or 255)
    quality_score: float  # 0.0-1.0
    quality_components: Dict[str, float]  # individual score components
    page_bounds: Optional[PageBounds]  # 4 corners
    skew_angle: float  # degrees
    failure_reason: Optional[str] = None
    intermediates: Optional[Dict[str, np.ndarray]] = None
    processing_time_ms: float = 0.0
    step_times_ms: Dict[str, float] = field(default_factory=dict)
    metadata: dict = field(default_factory=dict)


def detect_page_bounds(image: np.ndarray) -> Optional[PageBounds]:
    """
    Detect page boundaries using contour detection

    Args:
        image: Input image (BGR or grayscale)

    Returns:
        PageBounds with ordered corners (TL, TR, BR, BL) or None if not found
    """
    start_time = time.perf_counter()

    if image is None or image.size == 0:
        return None

    try:
        # Convert to grayscale
        if len(image.shape) == 3:
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        else:
            gray = image.copy()

        # Blur to reduce noise
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)

        # Canny edge detection
        edges = cv2.Canny(blurred, 50, 150)

        # Find contours
        contours, _ = cv2.findContours(edges, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)

        if not contours:
            return None

        # Filter contours by area
        image_area = image.shape[0] * image.shape[1]
        min_area = image_area * 0.1

        valid_contours = []
        for contour in contours:
            area = cv2.contourArea(contour)
            if area > min_area:
                # Approximate contour
                epsilon = 0.02 * cv2.arcLength(contour, True)
                approx = cv2.approxPolyDP(contour, epsilon, True)

                # Check if 4-sided
                if len(approx) == 4:
                    valid_contours.append(approx.reshape(4, 2).astype(np.float32))

        if not valid_contours:
            return None

        # Get largest contour by area
        largest = max(valid_contours, key=lambda c: cv2.contourArea(c.reshape(4, 1, 2)))

        # Order corners: top-left, top-right, bottom-right, bottom-left
        corners = _order_corners(largest)

        elapsed = (time.perf_counter() - start_time) * 1000
        logger.debug(f"detect_page_bounds: {elapsed:.2f}ms")

        return PageBounds(corners=corners)

    except Exception as e:
        logger.warning(f"Page bounds detection failed: {e}")
        return None


def _order_corners(corners: np.ndarray) -> np.ndarray:
    """Order corners to TL, TR, BR, BL"""
    # Compute centroid
    centroid = np.mean(corners, axis=0)

    # Sort by angle from centroid
    angles = np.arctan2(corners[:, 1] - centroid[1], corners[:, 0] - centroid[0])
    sorted_indices = np.argsort(angles)
    sorted_corners = corners[sorted_indices]

    # Find top-left (should be at top and left)
    top_indices = np.argsort(sorted_corners[:, 1])[:2]
    bottom_indices = np.argsort(sorted_corners[:, 1])[2:]

    top_points = sorted_corners[top_indices]
    bottom_points = sorted_corners[bottom_indices]

    tl = top_points[np.argmin(top_points[:, 0])]
    tr = top_points[np.argmax(top_points[:, 0])]
    br = bottom_points[np.argmax(bottom_points[:, 0])]
    bl = bottom_points[np.argmin(bottom_points[:, 0])]

    return np.array([tl, tr, br, bl], dtype=np.float32)


def correct_perspective(image: np.ndarray, bounds: PageBounds) -> np.ndarray:
    """
    Correct perspective distortion using homography

    Args:
        image: Input image
        bounds: Detected page bounds

    Returns:
        Perspective-corrected image
    """
    start_time = time.perf_counter()

    if not bounds.is_valid():
        return image.copy()

    try:
        corners = bounds.corners

        # Compute destination rectangle
        top_width = np.linalg.norm(corners[1] - corners[0])
        bottom_width = np.linalg.norm(corners[2] - corners[3])
        left_height = np.linalg.norm(corners[3] - corners[0])
        right_height = np.linalg.norm(corners[2] - corners[1])

        width = int(max(top_width, bottom_width))
        height = int(max(left_height, right_height))

        # Destination points
        dst_points = np.array([
            [0, 0],
            [width, 0],
            [width, height],
            [0, height]
        ], dtype=np.float32)

        # Compute perspective transform
        M = cv2.getPerspectiveTransform(corners, dst_points)

        # Apply warp
        result = cv2.warpPerspective(image, M, (width, height),
                                     borderMode=cv2.BORDER_REPLICATE)

        elapsed = (time.perf_counter() - start_time) * 1000
        logger.debug(f"correct_perspective: {elapsed:.2f}ms -> {width}x{height}")

        return result

    except Exception as e:
        logger.warning(f"Perspective correction failed: {e}")
        return image.copy()


def detect_skew(image: np.ndarray) -> float:
    """
    Detect page skew angle using Hough line detection

    Args:
        image: Input image (grayscale or BGR)

    Returns:
        Skew angle in degrees (-30 to +30)
    """
    start_time = time.perf_counter()

    if image is None or image.size == 0:
        return 0.0

    try:
        # Convert to grayscale
        if len(image.shape) == 3:
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        else:
            gray = image.copy()

        # Threshold
        _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

        # Invert for line detection
        binary = cv2.bitwise_not(binary)

        # HoughLinesP
        height, width = binary.shape
        min_line_length = int(width * 0.3)
        lines = cv2.HoughLinesP(binary, rho=1, theta=np.pi/180, threshold=100,
                               minLineLength=min_line_length, maxLineGap=20)

        if lines is None or len(lines) == 0:
            return 0.0

        # Extract angles
        angles = []
        for line in lines:
            x1, y1, x2, y2 = line[0]
            angle = np.arctan2(y2 - y1, x2 - x1) * 180 / np.pi

            # Normalize to -90 to 90
            if angle < -90:
                angle += 180
            if angle > 90:
                angle -= 180

            # Filter near-horizontal lines
            if abs(angle) < 30:
                angles.append(angle)

        if not angles:
            return 0.0

        # Return median angle
        skew_angle = np.median(angles)

        elapsed = (time.perf_counter() - start_time) * 1000
        logger.debug(f"detect_skew: {elapsed:.2f}ms -> {skew_angle:.2f}°")

        return float(skew_angle)

    except Exception as e:
        logger.warning(f"Skew detection failed: {e}")
        return 0.0


def correct_skew(image: np.ndarray, angle: float) -> np.ndarray:
    """
    Correct skew by rotating image

    Args:
        image: Input image
        angle: Rotation angle in degrees

    Returns:
        Deskewed image
    """
    start_time = time.perf_counter()

    # Skip if angle is too small
    if abs(angle) < 0.5:
        return image.copy()

    try:
        height, width = image.shape[:2]
        center = (width // 2, height // 2)

        # Get rotation matrix
        M = cv2.getRotationMatrix2D(center, angle, 1.0)

        # Apply rotation
        result = cv2.warpAffine(image, M, (width, height),
                               borderMode=cv2.BORDER_REPLICATE,
                               flags=cv2.INTER_LINEAR)

        elapsed = (time.perf_counter() - start_time) * 1000
        logger.debug(f"correct_skew: {elapsed:.2f}ms -> {angle:.2f}°")

        return result

    except Exception as e:
        logger.warning(f"Skew correction failed: {e}")
        return image.copy()


def convert_grayscale(image: np.ndarray) -> np.ndarray:
    """
    Convert image to grayscale

    Args:
        image: Input image

    Returns:
        Grayscale image (uint8)
    """
    start_time = time.perf_counter()

    if image is None or image.size == 0:
        return np.array([], dtype=np.uint8)

    try:
        if len(image.shape) == 2:
            # Already grayscale
            result = image.astype(np.uint8)
        else:
            # Convert from BGR or RGB
            result = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

        elapsed = (time.perf_counter() - start_time) * 1000
        logger.debug(f"convert_grayscale: {elapsed:.2f}ms")

        return result

    except Exception as e:
        logger.warning(f"Grayscale conversion failed: {e}")
        return np.array([], dtype=np.uint8)


def remove_shadows(grayscale: np.ndarray) -> np.ndarray:
    """
    Remove shadows and uneven lighting using morphological operations

    Args:
        grayscale: Grayscale image

    Returns:
        Shadow-removed grayscale image
    """
    start_time = time.perf_counter()

    if grayscale is None or grayscale.size == 0:
        return grayscale.copy()

    try:
        # Estimate background using dilation
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
        dilated = cv2.dilate(grayscale, kernel, iterations=5)

        # Blur the dilated image for smooth background estimate
        background = cv2.GaussianBlur(dilated, (21, 21), 0)

        # Compute difference (shadow regions will be darker)
        # Invert the difference to brighten shadows
        shadow_mask = cv2.absdiff(grayscale, background)

        # Apply to original
        result = np.uint8(np.clip(grayscale.astype(np.float32) +
                                  shadow_mask.astype(np.float32) * 0.5, 0, 255))

        elapsed = (time.perf_counter() - start_time) * 1000
        logger.debug(f"remove_shadows: {elapsed:.2f}ms")

        return result

    except Exception as e:
        logger.warning(f"Shadow removal failed: {e}")
        return grayscale.copy()


def enhance_contrast(grayscale: np.ndarray) -> np.ndarray:
    """
    Enhance contrast using CLAHE (Contrast Limited Adaptive Histogram Equalization)

    Args:
        grayscale: Grayscale image

    Returns:
        Contrast-enhanced image
    """
    start_time = time.perf_counter()

    if grayscale is None or grayscale.size == 0:
        return grayscale.copy()

    try:
        # CLAHE
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        result = clahe.apply(grayscale.astype(np.uint8))

        elapsed = (time.perf_counter() - start_time) * 1000
        logger.debug(f"enhance_contrast: {elapsed:.2f}ms")

        return result

    except Exception as e:
        logger.warning(f"Contrast enhancement failed: {e}")
        return grayscale.copy()


def binarize(grayscale: np.ndarray, method: str = "sauvola",
             sauvola_k: float = 0.2) -> np.ndarray:
    """
    Binarize grayscale image using specified method

    Args:
        grayscale: Grayscale image
        method: "sauvola", "otsu", or "adaptive"
        sauvola_k: k parameter for Sauvola method

    Returns:
        Binary image (uint8, 0 or 255)
    """
    start_time = time.perf_counter()

    if grayscale is None or grayscale.size == 0:
        return np.array([], dtype=np.uint8)

    try:
        if method == "sauvola":
            result = _binarize_sauvola(grayscale, k=sauvola_k)
        elif method == "otsu":
            _, result = cv2.threshold(grayscale, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        elif method == "adaptive":
            result = cv2.adaptiveThreshold(grayscale, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                          cv2.THRESH_BINARY, 31, 10)
        else:
            logger.warning(f"Unknown binarization method: {method}, using Otsu")
            _, result = cv2.threshold(grayscale, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

        elapsed = (time.perf_counter() - start_time) * 1000
        logger.debug(f"binarize ({method}): {elapsed:.2f}ms")

        return result.astype(np.uint8)

    except Exception as e:
        logger.warning(f"Binarization ({method}) failed: {e}")
        return np.array([], dtype=np.uint8)


def _binarize_sauvola(image: np.ndarray, k: float = 0.2, window_size: int = 31,
                      R: float = 128.0) -> np.ndarray:
    """
    Sauvola binarization using integral images for efficiency

    Args:
        image: Grayscale image
        k: Parameter controlling threshold sensitivity
        window_size: Local window size
        R: Dynamic range

    Returns:
        Binary image
    """
    # Ensure uint8
    img = image.astype(np.uint8)

    # Compute integral images
    integral = cv2.integral(img)
    integral_sq = cv2.integral(img.astype(np.float32) ** 2)

    # Padding
    pad = window_size // 2
    output = np.zeros_like(img, dtype=np.uint8)

    height, width = img.shape
    window_area = window_size * window_size

    for y in range(height):
        for x in range(width):
            # Compute window bounds
            y0 = max(0, y - pad)
            y1 = min(height, y + pad + 1)
            x0 = max(0, x - pad)
            x1 = min(width, x + pad + 1)

            # Compute mean using integral image
            area = (y1 - y0) * (x1 - x0)
            sum_val = (integral[y1, x1] - integral[y0, x1] -
                      integral[y1, x0] + integral[y0, x0])
            mean_val = sum_val / area if area > 0 else 0

            # Compute variance using integral image of squares
            sum_sq = (integral_sq[y1, x1] - integral_sq[y0, x1] -
                     integral_sq[y1, x0] + integral_sq[y0, x0])
            variance = (sum_sq / area - mean_val ** 2) if area > 0 else 0
            variance = max(0, variance)  # Handle floating point errors

            # Sauvola threshold
            std_val = np.sqrt(variance)
            threshold = mean_val * (1.0 + k * (std_val / R - 1.0))

            # Apply threshold
            output[y, x] = 255 if img[y, x] > threshold else 0

    return output


def restore(image: np.ndarray, options: RestorationOptions = None) -> RestorationResult:
    """
    Full restoration pipeline

    Args:
        image: Input image (BGR or grayscale)
        options: Restoration options

    Returns:
        RestorationResult with restored image and metadata
    """
    total_start = time.perf_counter()
    step_times = {}

    if options is None:
        options = RestorationOptions()

    try:
        # Validate input
        if image is None or image.size == 0:
            return RestorationResult(
                rectified_gray=np.array([], dtype=np.uint8),
                binary=np.array([], dtype=np.uint8),
                quality_score=0.0,
                quality_components={},
                page_bounds=None,
                skew_angle=0.0,
                failure_reason="E-C01: Invalid input image",
                processing_time_ms=0.0,
                step_times_ms=step_times
            )

        # Validate dimensions
        if image.shape[0] < 100 or image.shape[1] < 100:
            return RestorationResult(
                rectified_gray=np.array([], dtype=np.uint8),
                binary=np.array([], dtype=np.uint8),
                quality_score=0.0,
                quality_components={},
                page_bounds=None,
                skew_angle=0.0,
                failure_reason="E-C02: Image too small (<100x100)",
                processing_time_ms=0.0,
                step_times_ms=step_times
            )

        intermediates = {} if options.save_intermediates else None
        working_image = image.copy()

        # Step 1: Detect page bounds
        step_start = time.perf_counter()
        page_bounds = detect_page_bounds(working_image)
        step_times['detect_page_bounds'] = (time.perf_counter() - step_start) * 1000
        if intermediates is not None and page_bounds:
            _draw_bounds(working_image, page_bounds, intermediates)

        # Step 2: Perspective correction
        if options.enable_perspective_correction and page_bounds:
            step_start = time.perf_counter()
            working_image = correct_perspective(working_image, page_bounds)
            step_times['correct_perspective'] = (time.perf_counter() - step_start) * 1000
            if intermediates is not None:
                intermediates['after_perspective'] = working_image.copy()

        # Step 3: Detect skew
        step_start = time.perf_counter()
        skew_angle = detect_skew(working_image)
        step_times['detect_skew'] = (time.perf_counter() - step_start) * 1000

        # Step 4: Correct skew
        if options.enable_deskew:
            step_start = time.perf_counter()
            working_image = correct_skew(working_image, skew_angle)
            step_times['correct_skew'] = (time.perf_counter() - step_start) * 1000
            if intermediates is not None:
                intermediates['after_deskew'] = working_image.copy()

        # Step 5: Convert to grayscale
        step_start = time.perf_counter()
        rectified_gray = convert_grayscale(working_image)
        step_times['convert_grayscale'] = (time.perf_counter() - step_start) * 1000
        if intermediates is not None:
            intermediates['grayscale'] = rectified_gray.copy()

        # Step 6: Remove shadows
        if options.enable_shadow_removal:
            step_start = time.perf_counter()
            rectified_gray = remove_shadows(rectified_gray)
            step_times['remove_shadows'] = (time.perf_counter() - step_start) * 1000
            if intermediates is not None:
                intermediates['after_shadow_removal'] = rectified_gray.copy()

        # Step 7: Enhance contrast
        if options.enable_contrast_enhancement:
            step_start = time.perf_counter()
            rectified_gray = enhance_contrast(rectified_gray)
            step_times['enhance_contrast'] = (time.perf_counter() - step_start) * 1000
            if intermediates is not None:
                intermediates['after_contrast'] = rectified_gray.copy()

        # Step 8: Binarize
        step_start = time.perf_counter()
        binary = binarize(rectified_gray, method=options.binarization_method,
                         sauvola_k=options.sauvola_k)
        step_times['binarize'] = (time.perf_counter() - step_start) * 1000
        if intermediates is not None:
            intermediates['binary'] = binary.copy()

        # Step 9: Compute quality score
        step_start = time.perf_counter()
        from .quality_scorer import QualityScorer
        scorer = QualityScorer()
        quality_score, quality_components = scorer.compute_score(binary, rectified_gray)
        step_times['compute_quality'] = (time.perf_counter() - step_start) * 1000

        total_time = (time.perf_counter() - total_start) * 1000

        return RestorationResult(
            rectified_gray=rectified_gray,
            binary=binary,
            quality_score=quality_score,
            quality_components=quality_components,
            page_bounds=page_bounds,
            skew_angle=skew_angle,
            failure_reason=None,
            intermediates=intermediates,
            processing_time_ms=total_time,
            step_times_ms=step_times,
            metadata={
                'image_shape': image.shape,
                'binarization_method': options.binarization_method,
            }
        )

    except Exception as e:
        logger.error(f"Restoration pipeline failed: {e}")
        return RestorationResult(
            rectified_gray=np.array([], dtype=np.uint8),
            binary=np.array([], dtype=np.uint8),
            quality_score=0.0,
            quality_components={},
            page_bounds=None,
            skew_angle=0.0,
            failure_reason=f"E-C99: {str(e)}",
            processing_time_ms=(time.perf_counter() - total_start) * 1000,
            step_times_ms=step_times
        )


def _draw_bounds(image: np.ndarray, bounds: PageBounds, intermediates: dict):
    """Helper to draw bounds on image for visualization"""
    try:
        img = image.copy()
        if len(img.shape) == 2:
            img = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)

        pts = bounds.corners.astype(np.int32)
        cv2.polylines(img, [pts], True, (0, 255, 0), 3)
        intermediates['bounds_visualization'] = img
    except:
        pass
