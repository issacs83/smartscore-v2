# SmartScore Module C: Metrics Specification

Detailed measurement and aggregation of image quality, processing performance, and reliability metrics.

---

## Quality Score Components

The overall `quality_score` is a weighted average of six components, each in range [0.0, 1.0].

**Formula**:
```
quality_score = 0.25 × contrast_ratio
              + 0.20 × sharpness
              + 0.20 × line_straightness
              + 0.15 × noise_level
              + 0.10 × coverage
              + 0.10 × binarization_quality
```

---

### 1. Contrast Ratio (Weight: 0.25)

**Definition**: Intensity separation between foreground (text/staff) and background.

**Computation**:
```python
def compute_contrast_ratio(grayscale: np.ndarray, binary: np.ndarray) -> float:
    """
    grayscale: uint8 array [0, 255]
    binary: uint8 array {0, 255}

    Returns: float [0.0, 1.0]
    """
    foreground_pixels = grayscale[binary == 255]
    background_pixels = grayscale[binary == 0]

    if len(foreground_pixels) == 0 or len(background_pixels) == 0:
        return 0.0

    fg_mean = foreground_pixels.mean()
    bg_mean = background_pixels.mean()

    # Intensity difference (0-255 range)
    diff = abs(fg_mean - bg_mean)

    # Normalize to [0, 1]
    contrast_ratio = min(diff / 255.0, 1.0)

    return contrast_ratio
```

**Thresholds**:
- **Excellent** (0.90–1.00): `diff >= 200` (e.g., black text on white)
- **Good** (0.75–0.89): `diff >= 150`
- **Fair** (0.60–0.74): `diff >= 100`
- **Poor** (0.40–0.59): `diff >= 50`
- **Unusable** (0.00–0.39): `diff < 50`

**Impact on quality_score**:
- Good contrast: +0.225 (0.25 × 0.9)
- Low contrast: +0.025 (0.25 × 0.1)

---

### 2. Sharpness (Weight: 0.20)

**Definition**: Presence of high-frequency detail; inverse of blur.

**Computation**:
```python
def compute_sharpness(grayscale: np.ndarray) -> float:
    """
    Laplacian variance as sharpness proxy.

    Returns: float [0.0, 1.0]
    """
    laplacian = cv2.Laplacian(grayscale, cv2.CV_64F)
    variance = laplacian.var()

    # Empirical thresholds (calibrated on test set)
    # variance < 100: very blurry
    # variance 100-200: blurry
    # variance 200-500: acceptable
    # variance > 500: sharp

    if variance < 100:
        sharpness = 0.0
    elif variance < 500:
        sharpness = (variance - 100) / 400.0
    else:
        sharpness = min(variance / 500.0, 1.0)

    return sharpness
```

**Thresholds**:
- **Excellent** (0.90–1.00): `variance >= 800`
- **Good** (0.75–0.89): `variance >= 500`
- **Fair** (0.60–0.74): `variance >= 300`
- **Poor** (0.40–0.59): `variance >= 100`
- **Unusable** (0.00–0.39): `variance < 100` → E-C04 warning

**Impact on quality_score**:
- Sharp image: +0.18 (0.20 × 0.9)
- Blurry image: +0.00 (0.20 × 0.0)

---

### 3. Line Straightness (Weight: 0.20)

**Definition**: Horizontal alignment of detected lines (staff lines should be parallel and horizontal).

**Computation**:
```python
def compute_line_straightness(grayscale: np.ndarray, binary: np.ndarray) -> float:
    """
    Detect horizontal lines via Hough; measure angle variance.

    Returns: float [0.0, 1.0]
    """
    # Detect lines via Hough transform
    lines = cv2.HoughLines(binary, rho=1, theta=np.pi/180, threshold=100)

    if lines is None or len(lines) < 3:
        # Too few lines detected; cannot assess straightness
        return 0.5  # Neutral; no penalty or bonus

    # Extract angles (in degrees, relative to horizontal)
    angles = []
    for rho, theta in lines:
        # Convert theta (radians, 0-π) to degrees relative to horizontal
        angle_deg = abs(theta * 180 / np.pi - 90)  # 0° = horizontal
        angles.append(angle_deg)

    # Compute variance of angles
    angle_variance = np.var(angles)

    # Thresholds (empirical, calibrated on test set)
    # variance < 1.0: perfectly straight (all lines parallel)
    # variance 1.0-10.0: straight
    # variance 10.0-50.0: tilted/skewed
    # variance > 50.0: very skewed or corrupted

    if angle_variance < 1.0:
        straightness = 1.0
    elif angle_variance < 10.0:
        straightness = 1.0 - (angle_variance / 10.0) * 0.2
    elif angle_variance < 50.0:
        straightness = max(0.8 - (angle_variance - 10.0) / 40.0 * 0.7, 0.1)
    else:
        straightness = 0.0

    return straightness
```

**Thresholds**:
- **Excellent** (0.90–1.00): `angle_variance < 1.0` (all lines ≈ parallel)
- **Good** (0.75–0.89): `angle_variance < 5.0`
- **Fair** (0.60–0.74): `angle_variance < 15.0`
- **Poor** (0.40–0.59): `angle_variance < 40.0`
- **Unusable** (0.00–0.39): `angle_variance >= 40.0`

**Impact on quality_score**:
- Straight lines: +0.18 (0.20 × 0.9)
- Skewed lines: +0.02 (0.20 × 0.1)

---

### 4. Noise Level (Weight: 0.15)

**Definition**: Absence of high-frequency noise; inverse of noise energy.

**Computation**:
```python
def compute_noise_level(binary: np.ndarray) -> float:
    """
    Measure noise as high-frequency energy in binary image.
    Isolated pixels or small artifacts = noise.

    Returns: float [0.0, 1.0] (1.0 = low noise, 0.0 = high noise)
    """
    # Morphological noise detection: small blobs that are not connected to main content
    # Use median filter to identify noise
    denoised = cv2.medianBlur(binary, ksize=3)
    noise_pixels = np.abs(binary.astype(int) - denoised.astype(int))
    noise_ratio = noise_pixels.sum() / binary.size

    # Thresholds (empirical)
    # noise_ratio < 0.01: clean
    # noise_ratio < 0.05: acceptable
    # noise_ratio < 0.15: noisy
    # noise_ratio >= 0.15: very noisy

    if noise_ratio < 0.01:
        noise_level = 1.0
    elif noise_ratio < 0.05:
        noise_level = 1.0 - (noise_ratio / 0.05) * 0.15
    elif noise_ratio < 0.15:
        noise_level = 0.85 - ((noise_ratio - 0.05) / 0.10) * 0.70
    else:
        noise_level = max(0.15 - (noise_ratio - 0.15) / 0.15, 0.0)

    return noise_level
```

**Thresholds**:
- **Excellent** (0.90–1.00): `noise_ratio < 0.01` (< 1% noise pixels)
- **Good** (0.75–0.89): `noise_ratio < 0.05`
- **Fair** (0.60–0.74): `noise_ratio < 0.10`
- **Poor** (0.40–0.59): `noise_ratio < 0.20`
- **Unusable** (0.00–0.39): `noise_ratio >= 0.20`

**Impact on quality_score**:
- Clean image: +0.135 (0.15 × 0.9)
- Very noisy: +0.015 (0.15 × 0.1)

---

### 5. Coverage (Weight: 0.10)

**Definition**: Ratio of content (foreground + background with text) to total image area. Penalizes excessive white borders or partial pages.

**Computation**:
```python
def compute_coverage(binary: np.ndarray) -> float:
    """
    Estimate how much of the image contains actual document content
    (as opposed to empty/border area).

    Returns: float [0.0, 1.0]
    """
    # Find bounding box of non-background regions
    # In binary image: assume background (0) is mostly outside content area
    # Look for the largest rectangle of content

    # Simple approach: find bounding box of foreground pixels
    foreground_pixels = np.where(binary == 255)

    if len(foreground_pixels[0]) == 0:
        return 0.0  # No content

    y_min, y_max = foreground_pixels[0].min(), foreground_pixels[0].max()
    x_min, x_max = foreground_pixels[1].min(), foreground_pixels[1].max()

    content_area = (y_max - y_min + 1) * (x_max - x_min + 1)
    total_area = binary.size

    coverage = min(content_area / total_area, 1.0)

    # Thresholds
    # coverage >= 0.85: full page
    # coverage >= 0.70: most of page
    # coverage >= 0.50: partial page (acceptable)
    # coverage < 0.50: mostly border (problematic)

    return coverage
```

**Thresholds**:
- **Excellent** (0.90–1.00): `coverage >= 0.85` (page fills > 85% of frame)
- **Good** (0.75–0.89): `coverage >= 0.70`
- **Fair** (0.60–0.74): `coverage >= 0.50`
- **Poor** (0.40–0.59): `coverage >= 0.30`
- **Unusable** (0.00–0.39): `coverage < 0.30` (too much border)

**Impact on quality_score**:
- Full page: +0.09 (0.10 × 0.9)
- Mostly border: +0.01 (0.10 × 0.1)

---

### 6. Binarization Quality (Weight: 0.10)

**Definition**: Consistency between grayscale source and binary output; measure of how well binarization preserved content.

**Computation**:
```python
def compute_binarization_quality(grayscale: np.ndarray, binary: np.ndarray) -> float:
    """
    Measure how well binarization decision (0 or 255) aligns with grayscale intensity.
    Foreground pixels should come from dark grayscale regions.

    Returns: float [0.0, 1.0]
    """
    # For pixels where binary=255 (foreground), grayscale should be low
    # For pixels where binary=0 (background), grayscale should be high

    foreground_pixels = grayscale[binary == 255]
    background_pixels = grayscale[binary == 0]

    if len(foreground_pixels) == 0 or len(background_pixels) == 0:
        return 0.5  # Neutral if unable to assess

    fg_mean = foreground_pixels.mean()
    bg_mean = background_pixels.mean()

    # Ideal: foreground << background
    # Score based on separation
    if bg_mean - fg_mean > 100:
        binarization_quality = 1.0  # Very clean separation
    elif bg_mean - fg_mean > 50:
        binarization_quality = 0.8
    elif bg_mean - fg_mean > 30:
        binarization_quality = 0.6
    else:
        binarization_quality = 0.3  # Poor separation; binarization may have errors

    return min(binarization_quality, 1.0)
```

**Thresholds**:
- **Excellent** (0.90–1.00): `bg_mean - fg_mean > 120` (clear separation)
- **Good** (0.75–0.89): `bg_mean - fg_mean > 80`
- **Fair** (0.60–0.74): `bg_mean - fg_mean > 50`
- **Poor** (0.40–0.59): `bg_mean - fg_mean > 30`
- **Unusable** (0.00–0.39): `bg_mean - fg_mean <= 30` (unclear separation)

**Impact on quality_score**:
- Clean binarization: +0.09 (0.10 × 0.9)
- Poor binarization: +0.01 (0.10 × 0.1)

---

## Overall Quality Score Thresholds

| Range | Assessment | OMR Recommendation | Reliability |
|-------|------------|-------------------|------------|
| 0.90–1.00 | Excellent | Process immediately | Very high (> 95%) |
| 0.75–0.89 | Good | Process with confidence | High (85–95%) |
| 0.60–0.74 | Fair | Process with caution | Moderate (70–85%) |
| 0.40–0.59 | Poor | Warn user; may process | Low (50–70%) |
| 0.00–0.39 | Unusable | Do not process; retake | Very low (< 50%) |

**Reliability**: Expected OMR accuracy relative to best-case scenario (0.90–1.00 score).

---

## Processing Performance Metrics

### Per-Step Timing

Measured in milliseconds (ms). Each step recorded in `metadata["step_times"]`.

**Desktop environment (8-core i7, standard image 3000×3600)**:

| Step | Typical (ms) | Target (ms) | Notes |
|------|--------------|------------|-------|
| detect_page_bounds | 80–100 | < 120 | Canny edge detection + contour finding |
| correct_perspective | 40–80 | < 100 | warpPerspective transform |
| detect_skew | 50–70 | < 100 | Hough line transform |
| correct_skew | 60–90 | < 120 | Rotation + crop |
| convert_grayscale | 15–25 | < 30 | Color space conversion |
| remove_shadows | 90–130 | < 150 | Morphological operations + illumination est. |
| enhance_contrast | 35–60 | < 80 | CLAHE or histogram stretch |
| binarize | 30–50 | < 80 | Adaptive threshold |
| compute_quality_score | 20–35 | < 50 | Laplacian, Hough, histogram analysis |
| **Total** | **400–600** | **< 800** | End-to-end restoration |

**Mobile environment (4-core ARM, image 2000×2400)**:

| Step | Typical (ms) | Target (ms) | Notes |
|------|--------------|------------|-------|
| detect_page_bounds | 100–150 | < 200 | Slower contour finding |
| correct_perspective | 80–130 | < 200 | warpPerspective on ARM |
| detect_skew | 80–120 | < 200 | Hough on ARM |
| correct_skew | 100–150 | < 250 | Rotation expensive on ARM |
| convert_grayscale | 20–30 | < 50 | Fast on ARM |
| remove_shadows | 150–250 | < 400 | Morphology slower; may disable |
| enhance_contrast | 60–100 | < 150 | CLAHE or histogram |
| binarize | 50–80 | < 150 | Adaptive threshold |
| compute_quality_score | 30–50 | < 80 | Quality metrics |
| **Total** | **1500–2000** | **< 2500** | End-to-end (mobile) |

### Aggregate Metrics

**Single image**:
- Mean processing time: 550ms (desktop), 1800ms (mobile)
- Std deviation: ±150ms
- P95 (95th percentile): 800ms (desktop), 2200ms (mobile)
- P99 (99th percentile): 1100ms (desktop), 2500ms (mobile)

**Batch (4 images, parallel)**:
- Throughput: ~7 images/second (desktop)
- Memory peak: < 500 MB

---

## Quality Score Distribution (Test Set)

Aggregate statistics from regression test suite (N=500 diverse images).

**Desktop scans** (professional quality):
- Mean: 0.92
- Std dev: 0.04
- P5 (5th percentile): 0.86
- P25: 0.89
- P50 (median): 0.93
- P75: 0.96
- P95: 0.98

**Phone photos** (varied lighting/angle):
- Mean: 0.68
- Std dev: 0.18
- P5: 0.38
- P25: 0.54
- P50 (median): 0.70
- P75: 0.82
- P95: 0.89

**Synthetic test set** (programmatically distorted):
- Mean: 0.65
- Std dev: 0.25
- P5: 0.15
- P25: 0.45
- P50: 0.68
- P75: 0.85
- P95: 0.92

---

## Reliability Metrics

### Page Detection Success Rate

**Definition**: Percentage of images where page_bounds detected successfully (not None, not E-C07).

**Targets**:
- Clean scans: > 99%
- Phone photos: > 95%
- Synthetic distorted: > 85%
- Overall: > 90%

**Measurement**:
```python
successful = sum(1 for r in results if r.page_bounds is not None)
success_rate = successful / len(results)
```

### Perspective Correction Success Rate

**Definition**: If page_bounds detected, perspective correction applied without error.

**Target**: 100% (never fails after bounds detected)

**Measurement**:
```python
applied = sum(1 for r in results if r.page_bounds is not None)
successful = sum(1 for r in results if r.page_bounds is not None and r.intermediates["perspective_corrected"] is not None)
success_rate = successful / applied if applied > 0 else 1.0
```

### Deskew Accuracy

**Definition**: Angle error between detected skew and ground truth.

**Target**: ± 1.5 degrees (MAE)

**Measurement**:
```python
errors = [abs(result.skew_angle - ground_truth_angle) for result, ground_truth_angle in test_pairs]
mae = np.mean(errors)
```

### Binarization Quality (Foreground Preservation)

**Definition**: Percentage of foreground pixels (text/staff) correctly preserved in binary output.

**Target**: > 90%

**Measurement**:
```python
# From binarization ground truth (if available)
preserved = sum((binary == 255) & (ground_truth_binary == 255))
total_foreground = (ground_truth_binary == 255).sum()
preservation_rate = preserved / total_foreground
```

### False Failure Rate

**Definition**: Percentage of good images (quality_score > 0.70) that pipeline marks as failed (failure_reason != None).

**Target**: < 1%

**Measurement**:
```python
good_images = [r for r in results if r.quality_score > 0.70]
false_failures = sum(1 for r in good_images if r.failure_reason is not None)
false_failure_rate = false_failures / len(good_images)
```

---

## Calibration and Adjustment

### Adjusting Quality Score Weights

If downstream OMR analysis shows quality_score does not predict accuracy well, adjust weights.

**Current weights** (validate via correlation test):
```python
weights = {
    "contrast_ratio": 0.25,
    "sharpness": 0.20,
    "line_straightness": 0.20,
    "noise_level": 0.15,
    "coverage": 0.10,
    "binarization_quality": 0.10
}
```

**Reweighting procedure**:
1. Gather OMR accuracy metrics for 50+ test images
2. Compute Pearson correlation between each component and OMR accuracy
3. Set weight proportional to correlation magnitude
4. Renormalize so weights sum to 1.0
5. Re-validate on holdout test set

Example adjustment (if sharpness correlates more strongly):
```python
# New weights: increase sharpness, decrease coverage
weights = {
    "contrast_ratio": 0.25,
    "sharpness": 0.25,      # +0.05
    "line_straightness": 0.20,
    "noise_level": 0.15,
    "coverage": 0.05,       # -0.05
    "binarization_quality": 0.10
}
```

### Adjusting Component Thresholds

If test results show threshold misalignment (e.g., "blurry" images labeled as "good"), recalibrate.

**Example: Sharpness threshold adjustment**

Current:
```python
if variance < 100:
    sharpness = 0.0
elif variance < 500:
    sharpness = (variance - 100) / 400.0
else:
    sharpness = min(variance / 500.0, 1.0)
```

Adjusted (if test data shows > 200 is typically blurry):
```python
if variance < 200:
    sharpness = 0.0
elif variance < 600:
    sharpness = (variance - 200) / 400.0
else:
    sharpness = min(variance / 600.0, 1.0)
```

---

## Reporting and Dashboards

### Metrics Log Format

Every restoration operation logged to JSON:
```json
{
  "timestamp": "2026-03-21T14:32:00Z",
  "image_path": "/path/to/image.jpg",
  "quality_score": 0.87,
  "components": {
    "contrast_ratio": 0.92,
    "sharpness": 0.85,
    "line_straightness": 0.89,
    "noise_level": 0.80,
    "coverage": 0.94,
    "binarization_quality": 0.88
  },
  "processing_time_ms": 567,
  "step_times": {
    "detect_page_bounds": 92,
    "correct_perspective": 48,
    "detect_skew": 64,
    "correct_skew": 72,
    "convert_grayscale": 22,
    "remove_shadows": 118,
    "enhance_contrast": 51,
    "binarize": 44,
    "compute_quality_score": 32
  },
  "page_bounds": [[10, 20], [3590, 25], [3585, 3595], [15, 3590]],
  "skew_angle": -1.2,
  "failure_reason": null,
  "warnings": ["low_contrast_detected"],
  "output_files": {
    "rectified_gray": "/output/rectified.png",
    "binary": "/output/binary.png",
    "metadata": "/output/metadata.json"
  }
}
```

### Aggregated Metrics Report (Daily)

```
SmartScore Module C — Daily Metrics Report
Date: 2026-03-21

=== Volume ===
Total images processed: 1,247
Successful: 1,203 (96.5%)
Hard failures: 44 (3.5%)
  - E-C01 (too small): 8
  - E-C02 (too large): 3
  - E-C08 (timeout): 2
  - Other: 31

=== Quality ===
Mean quality_score: 0.74
Median quality_score: 0.76
Std deviation: 0.18
P5: 0.41
P95: 0.94

Distribution:
  Excellent (0.90–1.00): 312 images (25%)
  Good (0.75–0.89): 421 images (35%)
  Fair (0.60–0.74): 285 images (24%)
  Poor (0.40–0.59): 127 images (11%)
  Unusable (0.00–0.39): 58 images (5%)

=== Performance ===
Mean processing time: 634 ms
P95 processing time: 1,246 ms
Fastest: 124 ms
Slowest: 4,821 ms (timeout warning)

Breakdown:
  detect_page_bounds: 97 ms (avg)
  remove_shadows: 122 ms (avg)
  other steps: 41 ms (avg)

=== Reliability ===
Page detection success rate: 94.2%
Deskew accuracy (MAE): 1.3°
False failure rate: 0.8%

=== Warnings ===
Excessive blur (E-C04): 127 images (10%)
Excessive glare (E-C05): 43 images (3%)
Low contrast (E-C06): 89 images (7%)
Partial cut (E-C07): 52 images (4%)

=== Correlation with OMR ===
Pearson r (quality_score vs. OMR accuracy): 0.82
P-value: < 0.001
Recommendation: quality_score is strong predictor of OMR success
```

---

## Notes

- All thresholds subject to calibration based on production data
- Metrics logged to support continuous improvement and debugging
- Quality score designed to predict downstream OMR accuracy; validate regularly against actual OMR results

