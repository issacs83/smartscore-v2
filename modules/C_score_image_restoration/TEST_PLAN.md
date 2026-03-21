# SmartScore Module C: Test Plan

## Unit Tests

### 1. detect_page_bounds()

**Test 1.1: Clean scan with visible margins**
- Input: Scanned sheet music with white margins (300 DPI scan)
- Expected: 4-point polygon with corners ≈ 10-50 pixels from image edge
- Assertion: `bounds is not None` AND `len(bounds) == 4`

**Test 1.2: No page boundary (white background)**
- Input: Uniform white image (200×200)
- Expected: `None`
- Assertion: `bounds is None`

**Test 1.3: Multiple documents in frame**
- Input: Photo with 2 sheets of music
- Expected: Largest contour selected (one page)
- Assertion: `bounds is not None` AND polygon area covers ~80% of one page

**Test 1.4: Partial page (edge clipping)**
- Input: Sheet music with top edge cut off by ~15 pixels
- Expected: Bounds detected at partial page, or `None` if detection fails
- Assertion: Either `bounds is not None` and E-C07 triggered in pipeline, or `bounds is None`

---

### 2. correct_perspective()

**Test 2.1: No perspective distortion (orthogonal camera)**
- Input: Image + square bounds (camera angle = 0°)
- Expected: Output ≈ input (minimal change)
- Assertion: SSIM(output, input) > 0.99

**Test 2.2: Perspective distortion (45° camera angle)**
- Input: Sheet music photo taken at 45° angle; bounds detected as trapezoid
- Expected: Output is rectified to rectangle; staff lines horizontal
- Assertion: Detected skew angle in output ≈ 0° (before deskew step)

**Test 2.3: Skip if bounds=None**
- Input: Image + `bounds=None`
- Expected: Output = input
- Assertion: `np.array_equal(output, input)`

**Test 2.4: Large perspective (extreme corner points)**
- Input: Bounds with corners extending to image edge
- Expected: Rectified output may lose corner content; no crash
- Assertion: `output.shape[0] > 0 AND output.shape[1] > 0`

---

### 3. detect_skew()

**Test 3.1: Horizontal page (no skew)**
- Input: Clean scan, staff lines horizontal
- Expected: Angle ≈ 0° (tolerance: ±0.5°)
- Assertion: `abs(angle) < 0.5`

**Test 3.2: Rotated 15° clockwise**
- Input: Image rotated 15° clockwise
- Expected: Detected angle ≈ 15° ± 1°
- Assertion: `14 < angle < 16`

**Test 3.3: Rotated -20° (counterclockwise)**
- Input: Image rotated 20° counterclockwise
- Expected: Detected angle ≈ -20° ± 1°
- Assertion: `-21 < angle < -19`

**Test 3.4: No clear lines (white noise)**
- Input: White noise image
- Expected: Angle = 0.0 (fallback, <5 lines detected)
- Assertion: `angle == 0.0`

**Test 3.5: Extreme rotation (40°)**
- Input: Image rotated 40°
- Expected: Angle ≈ 40° ± 2° (may exceed ±45° limit; clipped)
- Assertion: `-45 <= angle <= 45` AND `abs(angle - 40) < 2`

---

### 4. correct_skew()

**Test 4.1: No rotation**
- Input: Image with angle = 0.0°
- Expected: Output = input
- Assertion: `np.allclose(output, input, rtol=0.01)` (small interpolation variance acceptable)

**Test 4.2: Rotate +10°**
- Input: Image with angle = 10.0°
- Expected: Output rotated -10° (corrects the skew); staff lines horizontal
- Assertion: Detected skew in output ≈ 0°

**Test 4.3: Handle black borders**
- Input: Image rotated; output includes black padding from rotation
- Expected: Black borders removed via bounding box of non-zero pixels
- Assertion: Output has minimal black pixels (< 5% border)

**Test 4.4: Small angle (<0.5°)**
- Input: Image with angle = 0.2°
- Expected: Skipped (no rotation applied)
- Assertion: `output.shape == input.shape` AND `output ≈ input`

---

### 5. convert_grayscale()

**Test 5.1: RGB image**
- Input: uint8 array (H, W, 3)
- Expected: Output (H, W), values [0, 255]
- Assertion: `output.shape == (H, W)` AND `output.dtype == np.uint8`

**Test 5.2: RGBA image (discard alpha)**
- Input: uint8 array (H, W, 4)
- Expected: Output (H, W), alpha ignored
- Assertion: `output.shape == (H, W)` AND alpha not in computation

**Test 5.3: Already grayscale**
- Input: uint8 array (H, W)
- Expected: Output = input
- Assertion: `np.array_equal(output, input)`

**Test 5.4: Preserve value range**
- Input: RGB with max = 255, min = 0
- Expected: Grayscale max ≈ 255, min ≈ 0
- Assertion: `output.min() < 10` AND `output.max() > 240`

---

### 6. remove_shadows()

**Test 6.1: Uniform lighting (no shadows)**
- Input: Grayscale image with uniform illumination
- Expected: Output ≈ input
- Assertion: SSIM(output, input) > 0.95

**Test 6.2: Vignette shadow (darker edges)**
- Input: Grayscale image with gradient (dark corners, bright center)
- Expected: Output more uniform; shadow reduced
- Assertion: std_dev(output) < std_dev(input)

**Test 6.3: Hard shadow (half-dark)**
- Input: Grayscale image with half dark, half bright (sharp boundary)
- Expected: Output attempts to lighten dark side; some halo effect acceptable
- Assertion: Output[dark_region].mean() > Input[dark_region].mean()

**Test 6.4: Skip if disabled**
- Input: Image with shadows, option `enable_shadow_removal=False`
- Expected: Output = input
- Assertion: `np.array_equal(output, input)`

---

### 7. enhance_contrast()

**Test 7.1: Already high contrast**
- Input: Binary-like image (mostly 0 or 255)
- Expected: Minimal change
- Assertion: Output ≈ input

**Test 7.2: Low contrast (mid-gray)**
- Input: Grayscale image with range [100, 150]
- Expected: Stretched to wider range (e.g., [30, 220])
- Assertion: `output.min() < 50` AND `output.max() > 200`

**Test 7.3: CLAHE method**
- Input: Grayscale with uneven lighting
- Expected: Local contrast enhanced; no extreme stretching
- Assertion: `output.dtype == np.uint8` AND no black/white clipping artifacts

**Test 7.4: Skip if disabled**
- Input: Low-contrast image, option `enable_contrast_enhancement=False`
- Expected: Output = input
- Assertion: `np.array_equal(output, input)`

---

### 8. binarize()

**Test 8.1: Sauvola method (default)**
- Input: Grayscale image (staff lines on white)
- Expected: Binary output with staff lines = 255, background = 0
- Assertion: `output.dtype == np.uint8` AND `set(output.unique()) == {0, 255}`

**Test 8.2: Otsu method**
- Input: Grayscale image with bimodal histogram
- Expected: Binary output, globally thresholded
- Assertion: `output.dtype == np.uint8` AND `set(output.unique()) == {0, 255}`

**Test 8.3: Adaptive method**
- Input: Grayscale image with varying illumination
- Expected: Binary output, locally thresholded
- Assertion: `output.dtype == np.uint8` AND foreground lines preserved

**Test 8.4: Sauvola with custom k**
- Input: Grayscale image, `sauvola_k=0.3`
- Expected: Output adapts threshold sensitivity; fewer noise artifacts than default k=0.2
- Assertion: Noise pixel count lower than k=0.1 case

**Test 8.5: Thin line preservation**
- Input: Grayscale with thin staff lines (2-3 pixels)
- Expected: Sauvola/Adaptive preserve lines; Otsu may lose thin lines
- Assertion: Sauvola foreground coverage > Otsu foreground coverage

---

### 9. compute_quality_score()

**Test 9.1: Clean scan (high score)**
- Input: Binary from clean scan, corresponding grayscale
- Expected: quality_score > 0.8
- Assertion: All components (contrast, sharpness, etc.) near 1.0

**Test 9.2: Blurry image (low sharpness)**
- Input: Binary/grayscale from blurred image
- Expected: quality_score < 0.4 (sharpness = 0.0)
- Assertion: Quality score primarily penalized by sharpness weight (0.20)

**Test 9.3: Low contrast (penalized)**
- Input: Binary/grayscale from low-contrast scan
- Expected: quality_score < 0.6 (contrast_ratio < 0.5)
- Assertion: Contrast weight (0.25) dominates penalty

**Test 9.4: Partial content (low coverage)**
- Input: Binary/grayscale with only 30% page content (white border)
- Expected: quality_score < 0.7 (coverage = 0.3)
- Assertion: Coverage weight (0.10) contributes penalty

**Test 9.5: Reference scores**
- Professional scan: 0.92-0.98
- Good phone photo: 0.75-0.85
- Tilted/slightly blurry: 0.60-0.75
- Poor lighting/low contrast: 0.40-0.60
- Blurry/glare: 0.20-0.40
- Assertion: Input test images should match reference ranges

---

## Integration Tests

### Test 10: Full Pipeline (Raw Image → Quality Score)

**Test 10.1: Clean scan (baseline)**
- Input: 300 DPI scan (3000×3600), perfect lighting, straight
- Processing: All steps enabled
- Expected output:
  - `rectified_gray`: (3000, 3600), uint8
  - `binary`: (3000, 3600), uint8, {0, 255}
  - `quality_score`: 0.92-0.98
  - `page_bounds`: 4 corners ~20 pixels from edge
  - `skew_angle`: ±0.5°
  - `processing_time_ms`: 800-1200 (desktop)
- Assertion: All above met; no failure_reason

**Test 10.2: Tilted photo (5-15° rotation)**
- Input: Phone photo, sheet music tilted 8°
- Processing: All steps enabled
- Expected:
  - Staff lines horizontal in output (skew_angle ≈ 0)
  - Perspective corrected (trapezoid → rectangle)
  - quality_score: 0.65-0.80
  - processing_time_ms: 1500-2500
- Assertion: Output staff lines detectable as horizontal

**Test 10.3: Strong perspective distortion**
- Input: Phone photo taken at 30° camera angle (trapezoid page)
- Processing: All steps enabled
- Expected:
  - Page_bounds detected as trapezoid
  - Output rectified to rectangle
  - Skew corrected
  - quality_score: 0.60-0.75
  - processing_time_ms: 2000-3000
- Assertion: Output aspect ratio matches standard sheet music

**Test 10.4: Shadows on one side**
- Input: Photo with strong directional lighting (left side bright, right side dark)
- Processing: All steps enabled (shadow removal ON)
- Expected:
  - Shadows removed; lighting more uniform
  - quality_score: 0.70-0.85
  - Binarization quality good across image
- Assertion: Foreground coverage in dark region > 50% (shadows removed)

**Test 10.5: Low light / underexposed**
- Input: Photo taken indoors without flash (dim, ~50 lux)
- Processing: All steps enabled
- Expected:
  - Low-contrast warning (E-C06 → auto-enhance)
  - Contrast enhanced automatically
  - quality_score: 0.50-0.70 (even with enhancement)
  - processing_time_ms: 2000-3000 (extra contrast enhancement)
- Assertion: Staff lines visible in output (contrast enhanced)

**Test 10.6: Glare / overexposed spots**
- Input: Photo with bright reflection/flash glare (>30% saturated)
- Processing: All steps enabled
- Expected:
  - Excessive glare detected (E-C05)
  - quality_score: 0.30-0.50
  - Binary image may have missing foreground in glare regions
  - Processing continues (non-blocking)
- Assertion: `failure_reason is None` AND `metadata["excessive_glare_detected"] == true`

**Test 10.7: Partial page (cropped)**
- Input: Sheet music photo with bottom 10% cut off
- Processing: All steps enabled
- Expected:
  - Page bounds may be detected or not (E-C07 possible)
  - If detected, extends beyond image → bounds invalidated
  - quality_score: 0.40-0.60 (incomplete document)
  - processing_time_ms: 1500-2000
- Assertion: `page_bounds is None` AND quality_score < 0.7

**Test 10.8: Curved page (book spine)**
- Input: Photo of sheet music with curved binding (pages curved at spine)
- Processing: All steps enabled
- Expected:
  - Perspective detection may fail (E-C03) or detect bent bounds
  - If perspective applied, output may be suboptimal (cannot fully straighten curve)
  - quality_score: 0.40-0.65
  - line_straightness component low (curved lines detected)
- Assertion: quality_score < 0.75 (curved page cannot be fully corrected)

---

## Test Categories

### Category 1: Clean Images (Baseline)
- Professional scans (300+ DPI)
- Optimal lighting, straight page
- Expected: quality_score > 0.85
- Performance: < 500ms on desktop, < 2s on mobile

### Category 2: Slightly Tilted (5-15°)
- Phone photos with minor rotation
- Expected: quality_score 0.65-0.80
- Assertion: Skew correction detects and removes tilt

### Category 3: Strong Perspective (>30°)
- Camera angle distant from orthogonal
- Expected: quality_score 0.60-0.75
- Assertion: Perspective transform applied; output rectangular

### Category 4: Shadows
- Uneven lighting (vignette, directional shadows)
- Expected: quality_score 0.70-0.85 (shadow removal enabled)
- Assertion: Shadow removal reduces illumination variance

### Category 5: Low Light / Underexposed
- Dim capture (< 100 lux)
- Expected: quality_score 0.50-0.70
- Assertion: Contrast enhancement triggered; staff lines visible

### Category 6: Glare / Overexposed
- Bright reflection, flash glare
- Expected: quality_score 0.30-0.50
- Assertion: Glare detected (E-C05); processing continues

### Category 7: Partial Page (Cropped)
- Document boundary extends outside image
- Expected: quality_score 0.40-0.60
- Assertion: Bounds invalidated or partial_cut detected

### Category 8: Curved Page (Book)
- Curved binding, non-planar page
- Expected: quality_score 0.40-0.65
- Assertion: Cannot fully straighten; quality penalized

---

## Synthetic Test Generation

**Purpose**: Generate diverse test cases programmatically from a single clean reference image.

**Method**:
1. Start with professional scan (baseline): `reference.png`
2. For each test category, apply transformations:
   - **Tilt**: `rotate(reference, angle)` for angle in [5, 10, 15, -5, -10, -15]
   - **Perspective**: `apply_perspective_matrix(reference, corners)` with various camera angles
   - **Blur**: `cv2.GaussianBlur(reference, (k, k), sigma)` for k in [5, 9, 15], sigma in [1, 2, 3]
   - **Shadow**: `reference * illumination_map` where illumination is vignette or gradient
   - **Underexpose**: `reference * brightness_factor` for factor in [0.5, 0.6, 0.7]
   - **Overexpose**: Replace random regions with white (>250 intensity)
   - **Crop**: Remove borders via `reference[y0:y1, x0:x1]`
   - **Curve**: Apply radial distortion (book page curl)
3. Generate 10-15 variants per category → ~120 synthetic test images
4. Run full pipeline on each; compare quality_score to expected range
5. Track failures and outliers

**Assertion Pattern**:
```python
for test_image, expected_range in synthetic_tests:
    result = restore(test_image)
    assert expected_range[0] <= result.quality_score <= expected_range[1], \
        f"Image {test_image} scored {result.quality_score}, expected {expected_range}"
```

---

## Quality Score Correlation Test

**Purpose**: Validate that higher quality_score correlates with better downstream OMR accuracy.

**Method**:
1. Generate 50 test images across all quality ranges (0.2 to 0.95)
2. Restore each via Module C → obtain quality_score
3. Feed binary and rectified_gray to Module D (OMR)
4. Measure OMR accuracy (e.g., note detection rate, staff recognition accuracy)
5. Compute Pearson correlation: quality_score vs. OMR accuracy
6. Expected correlation: r > 0.75 (strong positive)

**Test Cases**:
- High-quality images (score > 0.85): OMR accuracy > 90%
- Medium-quality images (score 0.60-0.75): OMR accuracy 75-90%
- Low-quality images (score < 0.40): OMR accuracy < 75% or OMR declines to process

**Assertion**:
```python
correlation = pearsonr(quality_scores, omr_accuracies)
assert correlation.pvalue < 0.05, "Quality score not significantly correlated with OMR accuracy"
assert correlation.statistic > 0.75, "Correlation too weak"
```

---

## Performance Targets

### Desktop Environment (8-core Intel i7, 16 GB RAM)
- **Single image (standard 3000×3600)**: < 500ms
  - Breakdown:
    - detect_page_bounds: < 100ms
    - correct_perspective: < 80ms
    - detect_skew: < 60ms
    - correct_skew: < 70ms
    - convert_grayscale: < 30ms
    - remove_shadows: < 100ms
    - enhance_contrast: < 50ms
    - binarize: < 40ms
    - compute_quality_score: < 50ms
  - Overhead (I/O, memory mgmt): < 50ms

- **Batch processing (4 images)**: < 2 seconds (parallelized, 4 workers)
- **Memory usage**: < 200 MB per image

### Mobile Environment (4-core ARM, 4 GB RAM)
- **Single image (2000×2400)**: < 2 seconds
  - Lower resolution processed; shadow removal may be simplified
  - Acceptable: 1.5-2.5s for balanced quality/speed
- **Memory usage**: < 100 MB (downsampled working buffers)

### Regression Test Format
```python
def test_performance_desktop():
    image = load_test_image("clean_scan_3000x3600.png")
    start = time.time()
    result = restore(image)
    elapsed_ms = (time.time() - start) * 1000
    assert elapsed_ms < 500, f"Desktop restore took {elapsed_ms}ms, expected < 500ms"
    assert result.processing_time_ms < 500
    for step, step_time in result.metadata["step_times"].items():
        assert step_time < 200, f"Step {step} took {step_time}ms"
```

---

## Regression Test Suite

**Location**: `tests/regression/test_module_c.py`

**Structure**:
```python
class TestModuleC:
    @pytest.mark.smoke
    def test_clean_scan_baseline(self):
        # Test 10.1

    @pytest.mark.quality
    def test_quality_score_ranges(self):
        # Tests across all categories

    @pytest.mark.performance
    def test_performance_desktop(self):
        # Desktop timing constraints

    @pytest.mark.integration
    def test_correlation_with_omr(self):
        # Quality score vs. OMR accuracy
```

**Run locally**: `pytest tests/regression/test_module_c.py -m smoke -v`
**Run full suite**: `pytest tests/regression/test_module_c.py -v`
**CI/CD**: Run on each commit; flag if any test fails

