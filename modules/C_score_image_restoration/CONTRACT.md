# SmartScore Module C: Score Image Restoration — Contract

## Purpose
Restore photographed sheet music images to near-scan quality for downstream OMR processing. This module is **INDEPENDENT from OMR** — it only produces cleaned images.

## Input
- **`input_image`**: Raw image bytes (JPEG/PNG), from camera or file
  - Accepted: uint8 numpy array (H×W or H×W×3/H×W×4), file path string
  - Constraint: 200×200 ≤ dimensions ≤ 10000×10000; file size ≤ 100 MP

- **`options`**: `RestorationOptions` (optional, defaults applied if not provided)
  - `enable_perspective_correction: bool` (default: `true`)
    - Apply 4-point perspective transform using detected page boundaries
  - `enable_deskew: bool` (default: `true`)
    - Detect and correct document skew (rotation)
  - `enable_shadow_removal: bool` (default: `true`)
    - Apply shadow/vignette removal via adaptive illumination estimation
  - `enable_contrast_enhancement: bool` (default: `true`)
    - Stretch histogram or apply CLAHE post-binarization
  - `binarization_method: str` (default: `"sauvola"`)
    - Valid: `"sauvola"` | `"otsu"` | `"adaptive"`
    - `sauvola`: local threshold, preserves thin lines
    - `otsu`: global threshold, fast, less noise-robust
    - `adaptive`: block-based threshold, balance between local/global
  - `sauvola_k: float` (default: `0.2`, range: `[0.1, 0.5]`)
    - Control constant for Sauvola binarization; higher K = lower threshold sensitivity
  - `save_intermediates: bool` (default: `false`)
    - Write intermediate step outputs to `output_dir/intermediates/`

## Output
- **`RestorationResult`**: Dataclass or dict with fields:
  - `rectified_gray: np.ndarray`
    - Shape: (H, W), dtype: uint8, values: [0, 255]
    - Grayscale image after all correction steps, before binarization
  - `binary: np.ndarray`
    - Shape: (H, W), dtype: uint8, values: {0, 255}
    - Final binarized image (foreground=255, background=0)
  - `quality_score: float`
    - Range: [0.0, 1.0]
    - Composite metric; see METRICS.md for weights and thresholds
  - `page_bounds: Optional[PageBounds]`
    - 4-tuple of (x, y) corner points: `[(tl_x, tl_y), (tr_x, tr_y), (br_x, br_y), (bl_x, bl_y)]`
    - Coordinates in original image space; `None` if detection failed
  - `skew_angle: float`
    - Degrees, range: [-45, 45]
    - Positive = clockwise rotation; `0.0` if no skew detected
  - `failure_reason: Optional[str]`
    - Error code + description if processing failed (see FAILURE_MODES.md)
    - `None` on success
  - `intermediates: Optional[Dict[str, np.ndarray]]`
    - Dict keys: `"bounds_detected"`, `"perspective_corrected"`, `"deskewed"`, `"grayscale"`, `"shadows_removed"`, `"contrast_enhanced"`, `"binarized"`
    - Values: corresponding intermediate images
    - Only populated if `options.save_intermediates == true`
  - `processing_time_ms: float`
    - Total wall-clock time in milliseconds
  - `metadata: Dict[str, Any]`
    - `"original_shape": (H, W[, C])`
    - `"rectified_shape": (H', W')`
    - `"dpi_estimate": float` (estimated DPI if detected; default: 300)
    - `"step_times": Dict[str, float]` (milliseconds per step)

## Pipeline Steps (in order)

### 1. `detect_page_bounds(image) → PageBounds | None`
- **Input**: uint8 numpy array (H×W or H×W×3), color or grayscale
- **Output**: 4-point polygon (top-left, top-right, bottom-right, bottom-left) or `None`
- **Method**: Edge detection (Canny) → contour finding → largest quadrilateral
- **Tolerance**: Accept ≥4 corner points; reject if corners extend <10 pixels from image edge
- **Failure**: Return `None` if no clear document boundary found (error code E-C03)

### 2. `correct_perspective(image, bounds) → image`
- **Input**: uint8 array, PageBounds
- **Output**: uint8 array of rectified image
- **Method**: cv2.getPerspectiveTransform() → cv2.warpPerspective()
- **Output size**: Set to bounding box of bounds; pad if corners extend outside
- **Skip if**: `bounds == None` or `enable_perspective_correction == false`
- **Fallback**: Return input unchanged

### 3. `detect_skew(image) → angle_degrees`
- **Input**: uint8 array (H×W, grayscale or RGB)
- **Output**: float in range [-45, 45] degrees
- **Method**: Hough line transform → detect horizontal/vertical lines → compute dominant angle
- **Threshold**: Only accept lines with high confidence; if ≤5 lines detected, return `0.0`
- **Skip if**: `enable_deskew == false`
- **Fallback**: Return `0.0`

### 4. `correct_skew(image, angle) → image`
- **Input**: uint8 array, angle in degrees
- **Output**: uint8 array of rotated+cropped image
- **Method**: cv2.getRotationMatrix2D() → cv2.warpAffine() with white border
- **Crop**: Remove black padding after rotation
- **Skip if**: `angle < 0.5` degrees or `enable_deskew == false`

### 5. `convert_grayscale(image) → grayscale_image`
- **Input**: uint8 array (H×W or H×W×3/4)
- **Output**: uint8 array (H×W)
- **Method**: cv2.cvtColor(image, cv2.COLOR_BGR2GRAY) or average channels

### 6. `remove_shadows(grayscale) → grayscale`
- **Input**: uint8 array (H×W)
- **Output**: uint8 array (H×W)
- **Method**: Morphological opening → estimate background illumination (Gaussian blur of morph result) → divide pixel values by illumination (normalize)
- **Skip if**: `enable_shadow_removal == false`
- **Fallback**: Return input unchanged

### 7. `enhance_contrast(grayscale) → enhanced_grayscale`
- **Input**: uint8 array (H×W)
- **Output**: uint8 array (H×W)
- **Method**: If Otsu selected, CLAHE (Contrast Limited Adaptive Histogram Equalization) with clipLimit=2.0, tileGridSize=(8,8); else histogram stretch to [10, 240]
- **Skip if**: `enable_contrast_enhancement == false`
- **Fallback**: Return input unchanged

### 8. `binarize(grayscale, method, params) → binary_image`
- **Input**: uint8 array (H×W), method name, parameters dict (sauvola_k if Sauvola)
- **Output**: uint8 array (H×W), values {0, 255}
- **Method**:
  - **Sauvola**: cv2.adaptiveThreshold(..., cv2.ADAPTIVE_THRESH_GAUSSIAN_C, blockSize=51, C=sauvola_k)
  - **Otsu**: cv2.threshold(..., 0, 255, cv2.THRESH_OTSU)
  - **Adaptive**: cv2.adaptiveThreshold(..., cv2.ADAPTIVE_THRESH_MEAN_C, blockSize=11, C=10)
- **Constraint**: Output foreground = 255 (white), background = 0 (black)

### 9. `compute_quality_score(binary, grayscale) → float`
- **Input**: binary uint8 (H×W, values {0,255}), grayscale uint8 (H×W, values [0,255])
- **Output**: float in [0.0, 1.0]
- **Components**: See METRICS.md for detailed formulas
  - contrast_ratio (0.25 weight)
  - sharpness (0.20 weight)
  - line_straightness (0.20 weight)
  - noise_level (0.15 weight)
  - coverage (0.10 weight)
  - binarization_quality (0.10 weight)

---

## API

```python
def restore(
    image: np.ndarray,
    options: RestorationOptions = None
) -> RestorationResult
```
- **Input**: Numpy array (uint8, H×W or H×W×3/4)
- **Options**: Defaults applied if `None`
- **Output**: `RestorationResult`
- **Raises**: ValueError if image violates size constraints

```python
def restore_file(
    path: str,
    output_dir: str = None,
    options: RestorationOptions = None
) -> RestorationResult
```
- **Input**: Path to image file (JPEG/PNG)
- **Output path**: Writes `{output_dir}/rectified.png`, `{output_dir}/binary.png`, `{output_dir}/metadata.json`
  - If `output_dir=None`, only return result in memory
  - If `save_intermediates=true`, write to `{output_dir}/intermediates/`
- **Output**: `RestorationResult`

```python
def restore_batch(
    paths: List[str],
    output_dir: str,
    options: RestorationOptions = None
) -> List[RestorationResult]
```
- **Input**: List of file paths; output directory (required, one subdirectory per image)
- **Parallelization**: Process up to 4 images in parallel (CPU-bound; adjust for available cores)
- **Output**: List of `RestorationResult`, same order as input paths

---

## Error Codes

| Code | Error | Condition | Recovery |
|------|-------|-----------|----------|
| E-C01 | IMAGE_TOO_SMALL | image.shape[0] < 200 OR image.shape[1] < 200 | Reject; return failure_reason |
| E-C02 | IMAGE_TOO_LARGE | image.shape[0] × image.shape[1] > 100,000,000 | Reject; return failure_reason |
| E-C03 | PAGE_NOT_FOUND | detect_page_bounds() returns None | Set page_bounds=None; continue (skip perspective correction) |
| E-C04 | EXCESSIVE_BLUR | Laplacian variance < 100 (grayscale) | Warn user; return quality_score < 0.3; continue |
| E-C05 | EXCESSIVE_GLARE | Pixels > 250 count > 30% of image | Warn user; return quality_score < 0.3; continue |
| E-C06 | LOW_CONTRAST | foreground_mean - background_mean < 30 | Warn user; enhance_contrast enabled automatically; continue |
| E-C07 | PARTIAL_CUT | page_bounds corner extends > 20% outside image | Set page_bounds=None; warn user; skip perspective; continue |
| E-C08 | PROCESSING_TIMEOUT | wall-clock time > 30 seconds | Interrupt pipeline; return failure_reason; no partial result |

---

## Contract Guarantees

1. **Independence**: Module C produces valid images regardless of downstream OMR module. No circular dependencies.
2. **Determinism**: Same input + same options → same output (excluding timestamped metadata).
3. **Graceful degradation**: If one step fails, pipeline attempts to continue with fallback behavior (e.g., skip perspective correction if bounds not detected). Only E-C08 (timeout) causes hard abort.
4. **Resource bounds**: Memory: < 3× input image size (for working buffers). Wall time: < 30 seconds per image.
5. **Metadata passthrough**: `page_bounds`, `skew_angle`, `quality_score` passed to Module D for context.

---

## Integration Points

- **Upstream (camera/file input)**: Accepts JPEG/PNG bytes or numpy arrays
- **Downstream (Module D — OMR)**: Consumes `binary` and `rectified_gray` arrays; uses `quality_score` for filtering; interprets `failure_reason` for error handling
- **Configuration**: RestorationOptions struct; no global state

