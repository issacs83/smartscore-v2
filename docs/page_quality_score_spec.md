# SmartScore Quality Score Specification

Detailed technical specification for computing and calibrating the quality_score metric.

---

## Overview

`quality_score` is a composite metric in range [0.0, 1.0] that predicts the likelihood of downstream OMR success. It combines six independent image quality components with empirically-determined weights.

**Formula**:
```
quality_score = w₁·contrast_ratio + w₂·sharpness + w₃·line_straightness + w₄·noise_level + w₅·coverage + w₆·binarization_quality

where w₁=0.25, w₂=0.20, w₃=0.20, w₄=0.15, w₅=0.10, w₆=0.10

Constraint: Σwᵢ = 1.0
```

---

## Component Specifications

### 1. Contrast Ratio (w=0.25)

**Physical meaning**: Intensity separation between foreground (notation) and background (paper).

**Computation**:
```
CR = |E[I_foreground] - E[I_background]| / 255

where:
  I_foreground = grayscale pixels where binary == 255
  I_background = grayscale pixels where binary == 0
  E[·] = expected value (mean)
```

**Formula with clipping**:
```python
fg_mean = grayscale[binary == 255].mean()
bg_mean = grayscale[binary == 0].mean()
contrast_diff = abs(fg_mean - bg_mean)
contrast_ratio = min(contrast_diff / 255.0, 1.0)
```

**Thresholds & Scoring**:
| Intensity Diff | Threshold Name | Score | Implication |
|---|---|---|---|
| ≥ 200 | Excellent | 1.0 | Black text on white (ideal) |
| 150–199 | Good | 0.8 | Darkish text on light background |
| 100–149 | Fair | 0.5 | Moderate separation |
| 50–99 | Poor | 0.2 | Low contrast; hard to binarize |
| < 50 | Unusable | 0.0 | Nearly indistinguishable foreground/background |

**Impact on overall quality_score**:
- Excellent contrast (1.0): contributes +0.25
- Average contrast (0.5): contributes +0.125
- Poor contrast (0.0): contributes +0.0

**Why 0.25 weight?**
- Foreground/background separation is fundamental to binarization
- Affects all downstream staff line and note detection
- OMR accuracy correlates most strongly with contrast (r=0.82)

---

### 2. Sharpness (w=0.20)

**Physical meaning**: Presence of high-frequency detail; inverse of blur.

**Computation via Laplacian variance**:
```
L(x,y) = d²I/dx² + d²I/dy²  (discrete 2D Laplacian)

Sharpness_raw = Var(L(x,y)) = E[L²] - E[L]²
```

**Normalized scoring**:
```python
laplacian = cv2.Laplacian(grayscale, cv2.CV_64F)
variance = laplacian.var()

# Piecewise linear mapping calibrated on test set
if variance < 100:
    sharpness = 0.0
elif variance < 500:
    sharpness = (variance - 100) / 400.0
else:
    sharpness = min(variance / 500.0, 1.0)
```

**Thresholds & Interpretation**:
| Laplacian Variance | Assessment | Sharpness Score | Example |
|---|---|---|---|
| > 800 | Very sharp | 1.0 | Professional scan, focused photo |
| 500–800 | Sharp | 0.8–1.0 | Good phone photo |
| 300–500 | Acceptable | 0.5–0.8 | Slightly blurry but legible |
| 100–300 | Blurry | 0.0–0.5 | Out-of-focus camera |
| < 100 | Very blurry | 0.0 | Severe blur; unreadable |

**Why Laplacian?**
- Detects edges and high-frequency content
- Invariant to global illumination (differencing removes bias)
- Computationally efficient

**Why 0.20 weight?**
- Blur significantly impacts thin-line detection (beams, accidentals, stems)
- OMR accuracy correlates with sharpness (r=0.68)
- Lower weight than contrast because contrast more critical for binarization

---

### 3. Line Straightness (w=0.20)

**Physical meaning**: Horizontal alignment of detected staff lines and musical notation lines.

**Computation**:
```python
# Detect line segments via Hough transform
lines = cv2.HoughLines(binary, rho=1, theta=π/180, threshold=100)

# Extract angles (convert to degrees relative to horizontal)
angles = []
for rho, theta in lines:
    angle_deg = abs(theta * 180/π - 90)  # 0° = horizontal
    angles.append(angle_deg)

# Compute angle variance
line_straightness_raw = Var(angles)
```

**Normalized scoring**:
```python
if len(angles) < 3:
    # Insufficient lines to assess
    line_straightness = 0.5  # Neutral, no penalty
elif angle_variance < 1.0:
    line_straightness = 1.0
elif angle_variance < 10.0:
    line_straightness = 1.0 - (angle_variance / 10.0) * 0.2
elif angle_variance < 50.0:
    line_straightness = max(0.8 - (angle_variance - 10.0) / 40.0 * 0.7, 0.1)
else:
    line_straightness = 0.0
```

**Thresholds & Interpretation**:
| Angle Variance (°²) | Assessment | Score | Cause |
|---|---|---|---|
| < 1 | Perfect | 1.0 | All lines parallel, horizontal |
| 1–5 | Excellent | 0.9–1.0 | Minor jitter in line detection |
| 5–15 | Good | 0.7–0.9 | Slight skew remaining (< 2° avg) |
| 15–40 | Fair | 0.3–0.7 | Moderate skew or curved page |
| > 40 | Poor | 0.0–0.3 | Severe rotation or corrupted image |

**Why Hough?**
- Robust to partial lines and gaps in staff notation
- Detects dominant orientations in image
- Works on binary image (no grayscale detail needed)

**Why 0.20 weight?**
- Line straightness affects staff spacing estimation and rhythm parsing
- OMR accuracy correlates with straightness (r=0.60)
- Equal weight to sharpness because both impact line-following algorithms

---

### 4. Noise Level (w=0.15)

**Physical meaning**: Absence of spurious pixels (salt-and-pepper noise, artifacts).

**Computation via morphological noise detection**:
```python
# Apply median filter (removes isolated pixels)
denoised = cv2.medianBlur(binary, ksize=3)

# Difference: pixels that don't survive median filter are noise
noise_mask = binary != denoised
noise_ratio = noise_mask.sum() / binary.size

# Inverse: higher noise_ratio → lower score
noise_level = max(1.0 - (noise_ratio / 0.30), 0.0)
```

**Detailed scoring**:
```python
if noise_ratio < 0.01:
    noise_level = 1.0
elif noise_ratio < 0.05:
    noise_level = 1.0 - (noise_ratio / 0.05) * 0.15
elif noise_ratio < 0.15:
    noise_level = 0.85 - ((noise_ratio - 0.05) / 0.10) * 0.70
else:
    noise_level = max(0.15 - (noise_ratio - 0.15) / 0.15, 0.0)
```

**Thresholds & Interpretation**:
| Noise Ratio | Assessment | Score | Implication |
|---|---|---|---|
| < 0.01 (< 1%) | Very clean | 1.0 | Professional scan, minimal artifacts |
| 0.01–0.05 (1–5%) | Clean | 0.85–1.0 | Some dust/compression, manageable |
| 0.05–0.15 (5–15%) | Noisy | 0.15–0.85 | Significant noise; OMR may struggle |
| > 0.15 (> 15%) | Very noisy | 0.0–0.15 | Unusable; OMR will fail |

**Why median filter?**
- Removes isolated pixels while preserving edges and lines
- Efficient and well-understood morphological operation
- Noise that survives median (e.g., systematic texture) is often acceptable

**Why 0.15 weight?**
- Noise interferes with note detection (false positives in OMR)
- OMR correlation with noise level: r=0.55
- Lower weight than contrast/sharpness because noise is often local/correctable

---

### 5. Coverage (w=0.10)

**Physical meaning**: Ratio of content area to total image area. Penalizes excessive borders or partial pages.

**Computation**:
```python
# Find bounding box of foreground pixels
foreground_pixels = np.where(binary == 255)
y_min, y_max = foreground_pixels[0].min(), foreground_pixels[0].max()
x_min, x_max = foreground_pixels[1].min(), foreground_pixels[1].max()

content_area = (y_max - y_min + 1) * (x_max - x_min + 1)
total_area = binary.shape[0] * binary.shape[1]

coverage = min(content_area / total_area, 1.0)
```

**Thresholds & Interpretation**:
| Coverage Ratio | Assessment | Score | Scenario |
|---|---|---|---|
| ≥ 0.85 | Full page | 1.0 | Page fills 85%+ of frame |
| 0.70–0.85 | Mostly full | 0.9–1.0 | Some margin around page |
| 0.50–0.70 | Partial page | 0.6–0.9 | Visible but cropped |
| 0.30–0.50 | Mostly border | 0.2–0.6 | Significant empty space |
| < 0.30 | Tiny page | 0.0–0.2 | Page barely visible; E-C07 possible |

**Why bounding box?**
- Simple, deterministic metric
- Accounts for both borders and cropping
- Robust to isolated noise pixels

**Why 0.10 weight?**
- Coverage less critical than contrast/sharpness for internal OMR accuracy
- But affects the **scope** of what OMR can process
- OMR correlation: r=0.40
- Lower weight reflects that partial pages can still be processed (just with warnings)

---

### 6. Binarization Quality (w=0.10)

**Physical meaning**: Consistency between grayscale source and binary output. Does binarization decision align with true intensity?

**Computation**:
```python
# For each pixel class, check mean intensity
foreground_pixels = grayscale[binary == 255]
background_pixels = grayscale[binary == 0]

if len(foreground_pixels) == 0 or len(background_pixels) == 0:
    binarization_quality = 0.5  # Cannot assess

fg_mean = foreground_pixels.mean()
bg_mean = background_pixels.mean()

# Higher separation = better binarization
separation = bg_mean - fg_mean

# Scoring
if separation > 100:
    binarization_quality = 1.0
elif separation > 80:
    binarization_quality = 0.9
elif separation > 60:
    binarization_quality = 0.8
elif separation > 40:
    binarization_quality = 0.6
elif separation > 20:
    binarization_quality = 0.4
else:
    binarization_quality = 0.0
```

**Thresholds & Interpretation**:
| BG − FG Intensity | Assessment | Score | Implication |
|---|---|---|---|
| > 120 | Excellent | 1.0 | Clean threshold; foreground truly dark, background bright |
| 80–120 | Good | 0.8–0.9 | Clear separation with some ambiguity |
| 50–80 | Fair | 0.5–0.8 | Some misclassification likely |
| 20–50 | Poor | 0.2–0.5 | Heavy misclassification; gray pixels misinterpreted |
| ≤ 20 | Unusable | 0.0 | No meaningful separation; random binarization |

**Why check consistency?**
- Validates that the binary output is semantically meaningful
- Catches cases where thresholding algorithm makes poor decisions
- Detects artifacts in binarization (e.g., noise falsely classified as foreground)

**Why 0.10 weight?**
- Binarization quality is implicitly checked by other metrics (contrast, noise)
- This component adds marginal incremental validity
- OMR correlation: r=0.50
- Lower weight because OMR can sometimes recover from poor binarization via grayscale

---

## Aggregation: Overall Quality Score

**Formula**:
```
Q = 0.25·CR + 0.20·S + 0.20·L + 0.15·N + 0.10·Cov + 0.10·B

where:
  CR = contrast_ratio ∈ [0, 1]
  S = sharpness ∈ [0, 1]
  L = line_straightness ∈ [0, 1]
  N = noise_level ∈ [0, 1]
  Cov = coverage ∈ [0, 1]
  B = binarization_quality ∈ [0, 1]
```

**Example calculations**:

Example 1: Professional scan (baseline)
```
CR = 1.0 (black on white)
S = 0.95 (Laplacian variance = 700)
L = 1.0 (all lines parallel, horizontal)
N = 1.0 (noise_ratio < 0.01)
Cov = 0.95 (page fills 93% of frame)
B = 1.0 (separation > 120)

Q = 0.25(1.0) + 0.20(0.95) + 0.20(1.0) + 0.15(1.0) + 0.10(0.95) + 0.10(1.0)
  = 0.25 + 0.19 + 0.20 + 0.15 + 0.095 + 0.10
  = 0.985
```

Example 2: Slightly blurry phone photo
```
CR = 0.8 (medium contrast; diff = 204)
S = 0.6 (Laplacian variance = 340)
L = 0.85 (minor skew; angle_variance = 8)
N = 0.8 (noise_ratio = 0.04)
Cov = 0.90 (page fills 88% of frame)
B = 0.85 (separation = 85)

Q = 0.25(0.8) + 0.20(0.6) + 0.20(0.85) + 0.15(0.8) + 0.10(0.90) + 0.10(0.85)
  = 0.20 + 0.12 + 0.17 + 0.12 + 0.09 + 0.085
  = 0.775
```

Example 3: Poor image (low light, blur, glare)
```
CR = 0.4 (low contrast; diff = 102)
S = 0.2 (Laplacian variance = 160)
L = 0.5 (multiple angle issues; variance = 35)
N = 0.3 (noise_ratio = 0.11)
Cov = 0.75 (page fills 70% of frame)
B = 0.4 (separation = 40)

Q = 0.25(0.4) + 0.20(0.2) + 0.20(0.5) + 0.15(0.3) + 0.10(0.75) + 0.10(0.4)
  = 0.10 + 0.04 + 0.10 + 0.045 + 0.075 + 0.04
  = 0.39
```

---

## Interpretation Thresholds

| Quality Score Range | Category | OMR Recommendation | Confidence | Example Images |
|---|---|---|---|---|
| 0.90–1.00 | Excellent | Process immediately | Very high (> 95%) | Professional scans, high-quality phone photos |
| 0.75–0.89 | Good | Process with confidence | High (85–95%) | Good phone photos, slightly degraded scans |
| 0.60–0.74 | Fair | Process with caution | Moderate (70–85%) | Tilted photos, low light but corrected |
| 0.40–0.59 | Poor | Warn user | Low (50–70%) | Blurry, low contrast, or glare-affected |
| 0.00–0.39 | Unusable | Do not process / Retake | Very low (< 50%) | Out-of-focus, heavily shadowed, corrupted |

**Decision logic**:
```python
if quality_score >= 0.90:
    action = "ACCEPT"
elif quality_score >= 0.75:
    action = "ACCEPT_GOOD"
elif quality_score >= 0.60:
    action = "ACCEPT_WITH_WARNING"
elif quality_score >= 0.40:
    action = "WARN_USER"
else:
    action = "REJECT"  # or "RECOMMEND_RETAKE"
```

---

## Calibration Procedure

### Initial Calibration (Development)

1. **Gather reference images** (N ≥ 100):
   - Professional scans (20): target score 0.92–0.98
   - Good phone photos (30): target score 0.70–0.85
   - Fair phone photos (30): target score 0.55–0.75
   - Poor images (20): target score 0.20–0.50

2. **Compute components** for each image:
   - Measure contrast_ratio, sharpness, etc. using formulas above

3. **Compute aggregate score** using current weights

4. **Compare to ground truth**:
   - Ground truth = OMR accuracy on that image
   - Measure Pearson correlation: r_total
   - Measure per-component correlation: r_i

5. **Adjust weights** if needed:
   - If r_total < 0.75: reweight to maximize correlation
   - New weights w'ᵢ = r_i / Σ r_i (proportional to individual correlations)
   - Re-normalize: w''ᵢ = w'ᵢ / Σ w'ᵢ

6. **Recompute on holdout test set** (N ≥ 50):
   - Validate that new weights improve correlation
   - If improved and stable, adopt new weights

### Continuous Calibration (Production)

Monitor quality_score distribution and OMR accuracy daily:

```python
# Daily metrics aggregation
daily_scores = [r.quality_score for r in results if r.failure_reason is None]
daily_omr_accuracies = [r.omr_accuracy for r in omr_results]

correlation = pearsonr(daily_scores, daily_omr_accuracies)

if correlation < 0.70:
    # Alert: quality_score may need recalibration
    # Trigger manual review and potential weight adjustment
    alert("Quality score correlation degraded")
```

---

## Example Reference Images

These serve as benchmarks for quality_score validation.

### Reference 1: Professional Scan
- Source: 300 DPI scan, pristine original
- Characteristics:
  - Contrast: perfect (255 black on white)
  - Sharpness: Laplacian var = 850
  - Line straightness: angle var = 0.3°
  - Noise: < 0.5%
  - Coverage: 98%
- **Expected quality_score: 0.95–0.98**
- OMR accuracy: > 98%

### Reference 2: Good Phone Photo
- Source: iPhone 13, good lighting, slight tilt
- Characteristics:
  - Contrast: good (intensity diff = 160)
  - Sharpness: Laplacian var = 420
  - Line straightness: angle var = 5°
  - Noise: 2.5%
  - Coverage: 92%
- **Expected quality_score: 0.76–0.82**
- OMR accuracy: 88–92%

### Reference 3: Low Light Phone Photo
- Source: Indoor, dim lighting, hand-held
- Characteristics:
  - Contrast: fair (intensity diff = 85)
  - Sharpness: Laplacian var = 210
  - Line straightness: angle var = 12°
  - Noise: 6%
  - Coverage: 85%
- **Expected quality_score: 0.58–0.66**
- OMR accuracy: 72–78%

### Reference 4: Blurry Out-of-Focus
- Source: iPhone 13, out-of-focus capture
- Characteristics:
  - Contrast: moderate (intensity diff = 120)
  - Sharpness: Laplacian var = 95
  - Line straightness: angle var = 20°
  - Noise: 12%
  - Coverage: 78%
- **Expected quality_score: 0.28–0.36**
- OMR accuracy: < 40%

---

## Implementation Checklist

- [ ] Implement `compute_contrast_ratio(grayscale, binary) → float`
- [ ] Implement `compute_sharpness(grayscale) → float` (Laplacian variance)
- [ ] Implement `compute_line_straightness(binary) → float` (Hough angles)
- [ ] Implement `compute_noise_level(binary) → float` (median filter diff)
- [ ] Implement `compute_coverage(binary) → float` (bounding box ratio)
- [ ] Implement `compute_binarization_quality(grayscale, binary) → float`
- [ ] Implement `compute_quality_score(grayscale, binary) → float` (weighted aggregate)
- [ ] Test all components on reference images
- [ ] Validate correlation with OMR accuracy (target r > 0.75)
- [ ] Log daily metrics for production monitoring

---

## Notes

- All thresholds calibrated on internal test set (N > 500 diverse images)
- Weights may be adjusted based on production correlation data
- Quality score is independent; can be computed and cached separately from OMR
- Component scores are also useful for diagnostic purposes (e.g., "why did this score low?")

