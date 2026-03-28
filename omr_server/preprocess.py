"""
Image preprocessing for OMR — optimized for camera-captured piano scores.

Pipeline (research-backed order: geometry first, then pixel enhancement):
  1. EXIF orientation fix
  2. Document boundary detection + perspective correction
  3. Shadow removal (morphological divide-by-background)
  4. Grayscale conversion
  5. Auto-rotation (portrait→landscape if staff lines are vertical)
  6. Deskew (staff-line angle correction)
  7. Upscale (INTER_CUBIC, capped at 3000px)
  8. Illumination normalization (divide-by-background on grayscale)
  9. Score region crop
  10. Output grayscale — NO binarization (homr UNet expects grayscale)

Key insight: Do NOT binarize before feeding to DL-based OMR engines.
Their UNet segmentation models are trained on grayscale images.
"""

import cv2
import numpy as np


def preprocess_for_omr(image_path: str, output_path: str) -> str:
    """Apply full preprocessing pipeline and save result."""
    img = cv2.imread(image_path, cv2.IMREAD_COLOR)
    if img is None:
        return image_path

    log = []

    # 1. EXIF orientation
    img = fix_exif_orientation(img, image_path)

    # 2. Perspective correction (on color, before any pixel ops)
    img, corrected = correct_perspective(img)
    if corrected:
        log.append("perspective")

    # 3. Shadow removal (on color, morphological)
    img = remove_shadows(img)
    log.append("deshadow")

    # 4. Grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 5. Auto-rotation
    gray, rotated = auto_rotate(gray)
    if rotated:
        log.append("rotated")

    # 6. Deskew
    gray, angle = deskew(gray)
    if angle:
        log.append(f"deskew={angle:.1f}")

    # 7. Upscale
    gray, scale = upscale_if_needed(gray)
    if scale > 1:
        log.append(f"upscale={scale}x")

    # 8. Illumination normalization (divide-by-background)
    gray = normalize_illumination(gray)

    # 9. Crop to score region
    gray, cropped = crop_to_score(gray)
    if cropped:
        log.append("cropped")

    # NO binarization, NO sharpening — feed clean grayscale to OMR

    cv2.imwrite(output_path, gray)
    info = ", ".join(log) if log else "no changes"
    print(f"[Preprocess] Saved: {output_path} ({gray.shape}) [{info}]")
    return output_path


# ─── Geometric corrections ────────────────────────────────────────────


def fix_exif_orientation(img: np.ndarray, path: str) -> np.ndarray:
    """Fix image rotation based on EXIF orientation tag."""
    try:
        from PIL import Image, ExifTags
        pil = Image.open(path)
        exif = pil.getexif()
        if not exif:
            return img
        orient_key = None
        for k, v in ExifTags.TAGS.items():
            if v == "Orientation":
                orient_key = k
                break
        if orient_key is None or orient_key not in exif:
            return img
        orient = exif[orient_key]
        ops = {
            3: cv2.ROTATE_180,
            6: cv2.ROTATE_90_CLOCKWISE,
            8: cv2.ROTATE_90_COUNTERCLOCKWISE,
        }
        if orient in ops:
            img = cv2.rotate(img, ops[orient])
            print(f"[Preprocess] EXIF rotation (orientation={orient})")
    except Exception:
        pass
    return img


def correct_perspective(img: np.ndarray) -> tuple[np.ndarray, bool]:
    """Detect paper boundary and apply 4-point perspective transform."""
    h, w = img.shape[:2]
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(blurred, 50, 150)

    # Dilate to close edge gaps
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    edges = cv2.dilate(edges, kernel, iterations=2)

    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return img, False

    contours = sorted(contours, key=cv2.contourArea, reverse=True)[:5]

    doc_corners = None
    for c in contours:
        peri = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, 0.02 * peri, True)
        area_ratio = cv2.contourArea(c) / (h * w)
        if len(approx) == 4 and area_ratio > 0.3:
            doc_corners = approx.reshape(4, 2).astype(np.float32)
            break

    if doc_corners is None:
        return img, False

    # Order points: top-left, top-right, bottom-right, bottom-left
    ordered = _order_points(doc_corners)

    # Compute target size
    w1 = np.linalg.norm(ordered[1] - ordered[0])
    w2 = np.linalg.norm(ordered[2] - ordered[3])
    h1 = np.linalg.norm(ordered[3] - ordered[0])
    h2 = np.linalg.norm(ordered[2] - ordered[1])
    new_w = int(max(w1, w2))
    new_h = int(max(h1, h2))

    if new_w < 200 or new_h < 200:
        return img, False

    dst = np.array([
        [0, 0], [new_w - 1, 0],
        [new_w - 1, new_h - 1], [0, new_h - 1]
    ], dtype=np.float32)

    M = cv2.getPerspectiveTransform(ordered, dst)
    warped = cv2.warpPerspective(img, M, (new_w, new_h),
                                  borderMode=cv2.BORDER_CONSTANT,
                                  borderValue=(255, 255, 255))
    print(f"[Preprocess] Perspective corrected: ({w}x{h}) → ({new_w}x{new_h})")
    return warped, True


def _order_points(pts: np.ndarray) -> np.ndarray:
    """Order 4 points as: top-left, top-right, bottom-right, bottom-left."""
    rect = np.zeros((4, 2), dtype=np.float32)
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]  # top-left has smallest sum
    rect[2] = pts[np.argmax(s)]  # bottom-right has largest sum
    d = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(d)]  # top-right has smallest difference
    rect[3] = pts[np.argmax(d)]  # bottom-left has largest difference
    return rect


def auto_rotate(gray: np.ndarray) -> tuple[np.ndarray, bool]:
    """Detect if score is rotated 90° (staff lines vertical → rotate)."""
    h, w = gray.shape
    edges = cv2.Canny(gray, 50, 150)
    lines = cv2.HoughLinesP(edges, 1, np.pi / 180, threshold=80,
                             minLineLength=min(h, w) // 5, maxLineGap=10)
    if lines is None or len(lines) < 5:
        return gray, False

    horiz, vert = 0, 0
    for line in lines:
        x1, y1, x2, y2 = line[0]
        dx, dy = abs(x2 - x1), abs(y2 - y1)
        if dx > dy * 3:
            horiz += 1
        elif dy > dx * 3:
            vert += 1

    if vert > horiz * 1.5 and vert > 10:
        gray = cv2.rotate(gray, cv2.ROTATE_90_COUNTERCLOCKWISE)
        print(f"[Preprocess] Auto-rotated 90° (horiz={horiz}, vert={vert})")
        return gray, True
    return gray, False


def deskew(gray: np.ndarray) -> tuple[np.ndarray, float | None]:
    """Deskew based on staff-line angle detection."""
    h, w = gray.shape
    edges = cv2.Canny(gray, 50, 150, apertureSize=3)
    lines = cv2.HoughLinesP(edges, 1, np.pi / 180, threshold=100,
                             minLineLength=w // 4, maxLineGap=10)
    if lines is None or len(lines) < 5:
        return gray, None

    angles = []
    for line in lines:
        x1, y1, x2, y2 = line[0]
        if abs(x2 - x1) > 50:
            angle = np.arctan2(y2 - y1, x2 - x1) * 180 / np.pi
            if abs(angle) < 10:
                angles.append(angle)

    if not angles:
        return gray, None

    median_angle = float(np.median(angles))
    if abs(median_angle) < 0.2 or abs(median_angle) > 5.0:
        return gray, None

    center = (w // 2, h // 2)
    M = cv2.getRotationMatrix2D(center, median_angle, 1.0)
    rotated = cv2.warpAffine(gray, M, (w, h),
                              flags=cv2.INTER_LINEAR,
                              borderMode=cv2.BORDER_CONSTANT,
                              borderValue=255)
    return rotated, median_angle


# ─── Pixel corrections ─────────────────────────────────────────────────


def remove_shadows(img_bgr: np.ndarray) -> np.ndarray:
    """Remove shadows using morphological background estimation.

    Works on color image. Estimates the background (bright) using
    dilation + median blur, then subtracts variation.
    """
    planes = cv2.split(img_bgr)
    result = []
    for plane in planes:
        dilated = cv2.dilate(plane, np.ones((7, 7), np.uint8))
        bg = cv2.medianBlur(dilated, 21)
        diff = 255 - cv2.absdiff(plane, bg)
        norm = cv2.normalize(diff, None, alpha=0, beta=255,
                             norm_type=cv2.NORM_MINMAX, dtype=cv2.CV_8UC1)
        result.append(norm)
    return cv2.merge(result)


def normalize_illumination(gray: np.ndarray) -> np.ndarray:
    """Normalize uneven illumination using divide-by-background.

    Replaces gamma + CLAHE + watermark removal in a single step.
    """
    # Estimate background with heavy Gaussian blur
    bg = cv2.GaussianBlur(gray, (0, 0), sigmaX=50)
    # Avoid division by zero
    bg = np.maximum(bg, 1).astype(np.float32)
    # Divide and rescale
    normalized = (gray.astype(np.float32) / bg) * 255.0
    normalized = np.clip(normalized, 0, 255).astype(np.uint8)
    return normalized


def upscale_if_needed(gray: np.ndarray, target_min_px: int = 1800) -> tuple[np.ndarray, int]:
    """Upscale low-resolution images for better OMR detection."""
    h, w = gray.shape
    short_side = min(h, w)
    if short_side >= target_min_px:
        return gray, 1

    scale = 2
    new_w, new_h = w * scale, h * scale
    if max(new_w, new_h) > 3000:
        scale_f = 3000.0 / max(w, h)
        new_w, new_h = int(w * scale_f), int(h * scale_f)
        scale = round(scale_f, 1)

    upscaled = cv2.resize(gray, (new_w, new_h), interpolation=cv2.INTER_CUBIC)
    print(f"[Preprocess] Upscaled {scale}x: ({w}x{h}) → ({new_w}x{new_h})")
    return upscaled, scale


def crop_to_score(gray: np.ndarray) -> tuple[np.ndarray, bool]:
    """Crop to score content region, removing margins."""
    h, w = gray.shape
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (20, 5))
    dilated = cv2.dilate(binary, kernel, iterations=2)

    contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return gray, False

    all_points = np.vstack(contours)
    x, y, rw, rh = cv2.boundingRect(all_points)
    content_ratio = (rw * rh) / (w * h)
    if content_ratio > 0.9 or content_ratio < 0.1:
        return gray, False

    pad_x = max(10, int(w * 0.03))
    pad_y = max(10, int(h * 0.03))
    x1 = max(0, x - pad_x)
    y1 = max(0, y - pad_y)
    x2 = min(w, x + rw + pad_x)
    y2 = min(h, y + rh + pad_y)

    cropped = gray[y1:y2, x1:x2]
    ch, cw = cropped.shape
    if ch < 200 or cw < 200:
        return gray, False

    print(f"[Preprocess] Cropped: ({w}x{h}) → ({cw}x{ch})")
    return cropped, True
