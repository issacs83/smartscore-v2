"""
Image preprocessing for OMR quality improvement.
- Watermark removal (morphological approach)
- Contrast enhancement (CLAHE)
- Adaptive binarization
- Deskewing
"""
import cv2
import numpy as np


def preprocess_for_omr(image_path: str, output_path: str) -> str:
    """Apply full preprocessing pipeline and save result."""
    img = cv2.imread(image_path)
    if img is None:
        return image_path  # Return original if can't read

    # 1. Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 2. Remove watermark
    gray = remove_watermark(gray)

    # 3. Enhance contrast
    gray = enhance_contrast(gray)

    # 4. Deskew
    gray = deskew(gray)

    # Save preprocessed
    cv2.imwrite(output_path, gray)
    print(f"[Preprocess] Saved: {output_path} ({gray.shape})")
    return output_path


def remove_watermark(gray: np.ndarray) -> np.ndarray:
    """Remove light watermarks from sheet music.
    
    Strategy: Watermarks are typically lighter than music notation.
    1. Detect light-colored regions (watermark candidates)
    2. Fill them with background color
    """
    # Gentle approach: only lighten mid-gray pixels (watermark range)
    # Preserve dark pixels (music notation) and white pixels (background)
    result = gray.copy()
    watermark_range = (gray > 160) & (gray < 215)
    result[watermark_range] = np.minimum(gray[watermark_range].astype(int) + 50, 255).astype(np.uint8)
    return result


def enhance_contrast(gray: np.ndarray) -> np.ndarray:
    """Enhance contrast using CLAHE."""
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    return clahe.apply(gray)


def deskew(gray: np.ndarray) -> np.ndarray:
    """Deskew image based on staff line angle detection."""
    # Detect horizontal lines (staff lines)
    edges = cv2.Canny(gray, 50, 150, apertureSize=3)
    lines = cv2.HoughLinesP(edges, 1, np.pi / 180, threshold=100,
                             minLineLength=gray.shape[1] // 4, maxLineGap=10)

    if lines is None or len(lines) < 5:
        return gray  # Not enough lines to deskew

    # Calculate average angle of near-horizontal lines
    angles = []
    for line in lines:
        x1, y1, x2, y2 = line[0]
        if abs(x2 - x1) > 50:  # Only long horizontal lines
            angle = np.arctan2(y2 - y1, x2 - x1) * 180 / np.pi
            if abs(angle) < 10:  # Near horizontal
                angles.append(angle)

    if not angles:
        return gray

    median_angle = np.median(angles)
    if abs(median_angle) < 0.1:
        return gray  # Already straight

    # Rotate
    h, w = gray.shape
    center = (w // 2, h // 2)
    M = cv2.getRotationMatrix2D(center, median_angle, 1.0)
    rotated = cv2.warpAffine(gray, M, (w, h), 
                              flags=cv2.INTER_LINEAR,
                              borderMode=cv2.BORDER_CONSTANT,
                              borderValue=255)
    
    print(f"[Preprocess] Deskewed by {median_angle:.2f} degrees")
    return rotated
