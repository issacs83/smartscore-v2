# SmartScore Module C: Failure Modes and Recovery

## E-C01: IMAGE_TOO_SMALL

**Condition**
- `image.shape[0] < 200` OR `image.shape[1] < 200` pixels
- Check performed at pipeline entry

**Detection Method**
```python
if min(image.shape[:2]) < 200:
    failure_reason = "E-C01: IMAGE_TOO_SMALL"
    # Abort immediately
```

**Recovery Action**
- Return `RestorationResult` with:
  - `failure_reason = "E-C01: IMAGE_TOO_SMALL"`
  - `quality_score = 0.0`
  - `binary = None`
  - `rectified_gray = None`
  - `processing_time_ms = elapsed`
- Propagate to caller; do not attempt restoration

**Test Case Description**
- Input: 150×150 pixel image (clean scan)
- Expected: Immediate rejection, no processing
- Assertion: `result.failure_reason == "E-C01"` AND `result.processing_time_ms < 10`

**Impact on Downstream OMR**
- OMR receives `failure_reason`; user alerted that image is too small to restore
- No OMR processing attempted
- Recommendation: Prompt user to use higher resolution camera or provided higher-res scan

---

## E-C02: IMAGE_TOO_LARGE

**Condition**
- `image.shape[0] × image.shape[1] > 100,000,000` (100 megapixels)
- Check performed at pipeline entry

**Detection Method**
```python
if image.shape[0] * image.shape[1] > 100_000_000:
    failure_reason = "E-C02: IMAGE_TOO_LARGE"
    # Abort immediately
```

**Recovery Action**
- Return `RestorationResult` with:
  - `failure_reason = "E-C02: IMAGE_TOO_LARGE"`
  - `quality_score = 0.0`
  - `binary = None`
  - `rectified_gray = None`
  - `processing_time_ms = elapsed`
- Do not attempt restoration

**Test Case Description**
- Input: 15000×7000 pixel image (150 MP)
- Expected: Immediate rejection
- Assertion: `result.failure_reason == "E-C02"` AND `result.processing_time_ms < 10`

**Impact on Downstream OMR**
- OMR receives `failure_reason`; user alerted about memory/processing constraints
- Recommendation: Downsample image to < 100 MP or split into multiple regions

---

## E-C03: PAGE_NOT_FOUND

**Condition**
- `detect_page_bounds(image)` returns `None` after edge detection and contour analysis
- Occurs when no clear document boundary (4-sided polygon) detected

**Detection Method**
```python
bounds = detect_page_bounds(image)
if bounds is None:
    failure_reason = "E-C03: PAGE_NOT_FOUND"
    # Set page_bounds = None; continue pipeline
```

**Recovery Action**
- Set `page_bounds = None` in result
- Skip perspective correction step (step 2)
- Continue pipeline from step 3 (detect_skew) with original image
- Log warning: "No page boundary detected; skipping perspective correction"
- Processing continues; **not a hard failure**

**Test Case Description**
1. Input: Uniform white image (200×200)
   - Expected: bounds = None; processing continues
   - Assertion: `result.page_bounds is None` AND `result.failure_reason is None`
2. Input: Sheet music photo with visible edge clipping (partial page)
   - Expected: bounds = None or truncated bounds (E-C07 also possible)
   - Assertion: `result.page_bounds is None`
3. Input: Sheet music with very small or blended margins
   - Expected: bounds detection fails; processing continues
   - Assertion: Quality score should reflect lack of perspective correction

**Impact on Downstream OMR**
- OMR receives `page_bounds = None`; aware that no perspective transform applied
- OMR can attempt to detect staff lines from raw skew-corrected image
- Quality score may be lower; OMR may flag for manual review if score < 0.3

---

## E-C04: EXCESSIVE_BLUR

**Condition**
- Laplacian variance of grayscale image < 100 (threshold)
- Computed after grayscale conversion (step 5), before binarization

**Detection Method**
```python
laplacian = cv2.Laplacian(grayscale, cv2.CV_64F)
variance = laplacian.var()
if variance < 100:
    excessive_blur = True
```

**Recovery Action**
- **Non-blocking warning**: Log "E-C04: EXCESSIVE_BLUR detected"
- Continue pipeline to completion
- Set quality_score component `sharpness = 0.0` (this reduces overall quality_score)
- Return result with:
  - `failure_reason = None` (not a hard failure)
  - `quality_score` ≤ 0.4 (due to low sharpness weight = 0.20)
  - `binary` and `rectified_gray` populated (best-effort restoration)
  - `metadata["excessive_blur_detected"] = true`

**Test Case Description**
1. Input: Sheet music photo taken out-of-focus (heavy Gaussian blur)
   - Expected: Processing continues; quality_score < 0.4
   - Assertion: `result.quality_score < 0.4` AND `result.failure_reason is None`
2. Input: Motion-blurred image (camera shake)
   - Expected: Laplacian variance detected as low; quality reduced
   - Assertion: `result.metadata["excessive_blur_detected"] == true`
3. Input: Clean scan (Laplacian variance > 500)
   - Expected: No blur warning; quality_score unaffected
   - Assertion: `result.metadata.get("excessive_blur_detected") != true`

**Impact on Downstream OMR**
- OMR receives `quality_score < 0.4`; may decline OMR processing (if configured threshold = 0.3)
- User warned: "Image is blurry; OMR accuracy may be low"
- Optional: OMR may attempt lightweight processing for user preview, but flags result as low-confidence

---

## E-C05: EXCESSIVE_GLARE

**Condition**
- Pixels with intensity > 250 constitute > 30% of image area (saturated white)
- Computed on grayscale image after shadow removal (step 6)

**Detection Method**
```python
saturated_count = (grayscale > 250).sum()
saturation_ratio = saturated_count / grayscale.size
if saturation_ratio > 0.30:
    excessive_glare = True
```

**Recovery Action**
- **Non-blocking warning**: Log "E-C05: EXCESSIVE_GLARE detected"
- Continue pipeline to completion
- Set quality_score component `contrast_ratio = 0.0` (contrast heavily reduced)
- Optionally attempt aggressive shadow removal in step 6 (retry with larger kernel)
- Return result with:
  - `failure_reason = None` (not a hard failure)
  - `quality_score` ≤ 0.5 (due to lost contrast; weight = 0.25)
  - `binary` and `rectified_gray` populated
  - `metadata["excessive_glare_detected"] = true`

**Test Case Description**
1. Input: Photo of sheet music taken under bright window (large white glare patches)
   - Expected: Processing continues; quality_score < 0.5
   - Assertion: `result.quality_score < 0.5` AND `result.metadata["excessive_glare_detected"] == true`
2. Input: Photo with reflective surface glare (>40% saturated)
   - Expected: Glare detected; binary image may lose staff lines in glare regions
   - Assertion: `result.binarization_quality < 0.7` (component-level)
3. Input: Overexposed corners only (< 20% saturated)
   - Expected: No glare warning; processing normal
   - Assertion: `result.metadata.get("excessive_glare_detected") != true`

**Impact on Downstream OMR**
- OMR receives `quality_score < 0.5`; may decline processing
- Binary image may have missing foreground in glare regions; OMR cannot recover
- User recommendation: Retake photo under diffuse lighting, avoid direct reflections

---

## E-C06: LOW_CONTRAST

**Condition**
- Foreground-background intensity separation < 30 (measured as mean intensity difference of foreground vs. background clusters)
- Computed on grayscale image after shadow removal (step 6)

**Detection Method**
```python
# Simple: use Otsu threshold to estimate foreground/background split
_, binary_otsu = cv2.threshold(grayscale, 0, 255, cv2.THRESH_OTSU)
foreground = grayscale[binary_otsu == 255]
background = grayscale[binary_otsu == 0]
contrast = abs(foreground.mean() - background.mean())
if contrast < 30:
    low_contrast = True
```

**Recovery Action**
- **Non-blocking**: Log "E-C06: LOW_CONTRAST detected"
- Automatically **enable contrast enhancement** (step 7) if disabled
- Apply CLAHE with aggressive settings: clipLimit=3.0, tileGridSize=(6,6)
- Continue pipeline to completion
- Return result with:
  - `failure_reason = None` (automatic recovery)
  - `quality_score` may be reduced if contrast enhancement insufficient
  - `binary` and `rectified_gray` populated
  - `metadata["low_contrast_detected"] = true`
  - `metadata["contrast_enhancement_applied"] = true`

**Test Case Description**
1. Input: Sheet music photo taken in dim light (low contrast, mostly mid-gray)
   - Expected: Automatic contrast enhancement; processing continues
   - Assertion: `result.metadata["contrast_enhancement_applied"] == true`
2. Input: Faded photocopy (inherently low contrast)
   - Expected: Contrast enhanced; quality may still be moderate
   - Assertion: `result.quality_score < 0.7` (even with enhancement)
3. Input: High-contrast scan (contrast > 80)
   - Expected: No low-contrast warning; enhancement applied only if enabled
   - Assertion: `result.metadata.get("low_contrast_detected") != true`

**Impact on Downstream OMR**
- OMR receives enhanced binary; staff lines more visible
- If automatic enhancement insufficient, OMR may still struggle with staff recognition
- User recommendation: Use better lighting during capture

---

## E-C07: PARTIAL_CUT

**Condition**
- Detected page_bounds corner point extends > 20% outside original image boundary
- Specifically: any (x, y) coordinate of detected corner satisfies:
  - `x < -0.2 * width` OR `x > 1.2 * width` OR
  - `y < -0.2 * height` OR `y > 1.2 * height`

**Detection Method**
```python
if bounds is not None:
    for (x, y) in bounds:
        if x < -0.2 * width or x > 1.2 * width or \
           y < -0.2 * height or y > 1.2 * height:
            partial_cut = True
            break
```

**Recovery Action**
- **Non-blocking warning**: Log "E-C07: PARTIAL_CUT detected"
- Set `page_bounds = None` (invalidate detected bounds)
- Skip perspective correction (step 2)
- Continue pipeline from step 3 (detect_skew) with original image
- Return result with:
  - `failure_reason = None` (not a hard failure)
  - `page_bounds = None`
  - `quality_score` reduced (incomplete document)
  - `metadata["partial_cut_detected"] = true`

**Test Case Description**
1. Input: Sheet music photo with bottom edge cut off (page_bounds extends 30% below image)
   - Expected: bounds invalidated; processing continues without perspective correction
   - Assertion: `result.page_bounds is None` AND `result.metadata["partial_cut_detected"] == true`
2. Input: Photo with partial top margin (bounds corner extends 5% above image)
   - Expected: No partial_cut warning (threshold = 20%)
   - Assertion: `result.metadata.get("partial_cut_detected") != true`
3. Input: Photo with visible but cropped page (extends 25% outside)
   - Expected: Partial cut detected; bounds invalidated
   - Assertion: Quality score should be < 0.7 (document incomplete)

**Impact on Downstream OMR**
- OMR receives `page_bounds = None`; aware that page is incomplete
- OMR processes best-effort from skew-corrected but non-perspective-corrected image
- Result quality likely suboptimal; OMR may flag for manual review
- User recommendation: Retake photo ensuring full page is visible in frame

---

## E-C08: PROCESSING_TIMEOUT

**Condition**
- Wall-clock time exceeds 30 seconds from pipeline start
- Checked periodically (every 100ms) between steps

**Detection Method**
```python
start_time = time.time()
while not pipeline_complete:
    elapsed = (time.time() - start_time) * 1000  # milliseconds
    if elapsed > 30_000:
        timeout = True
        break
    # ... process step
```

**Recovery Action**
- **Hard failure**: Immediately interrupt pipeline
- Return `RestorationResult` with:
  - `failure_reason = "E-C08: PROCESSING_TIMEOUT"`
  - `quality_score = 0.0`
  - `binary = None`
  - `rectified_gray = None`
  - `processing_time_ms = elapsed` (actual wall time, > 30000)
- Release all working buffers
- Do not attempt to continue pipeline

**Test Case Description**
1. Input: 50 MP image on single-core mobile device
   - Expected: Timeout after ~25 seconds; hard failure
   - Assertion: `result.failure_reason == "E-C08"` AND `result.processing_time_ms > 30000`
2. Input: Pathological input (e.g., white noise image that exhausts contour detection)
   - Expected: Timeout; hard failure
   - Assertion: `result.quality_score == 0.0`
3. Input: Standard image on modern 8-core desktop
   - Expected: Processing completes < 1 second; no timeout
   - Assertion: `result.failure_reason is None` AND `result.processing_time_ms < 1000`

**Impact on Downstream OMR**
- OMR receives `failure_reason = "E-C08"`; no restoration attempted
- User alerted: "Image restoration timeout; try smaller image or reduce processing options"
- Recommendation: Downsampled image, disable expensive steps (perspective correction, shadow removal), or use faster hardware

---

## Summary Table

| Code | Error | Blocking? | Recovery | Quality Score | page_bounds |
|------|-------|-----------|----------|---------------|-------------|
| E-C01 | TOO_SMALL | Yes | Reject | 0.0 | None |
| E-C02 | TOO_LARGE | Yes | Reject | 0.0 | None |
| E-C03 | PAGE_NOT_FOUND | No | Skip perspective | Variable | None |
| E-C04 | EXCESSIVE_BLUR | No | Reduce sharpness | < 0.4 | As detected |
| E-C05 | EXCESSIVE_GLARE | No | Reduce contrast | < 0.5 | As detected |
| E-C06 | LOW_CONTRAST | No | Auto-enhance | Variable | As detected |
| E-C07 | PARTIAL_CUT | No | Skip perspective | < 0.7 | None |
| E-C08 | TIMEOUT | Yes | Abort pipeline | 0.0 | None |

