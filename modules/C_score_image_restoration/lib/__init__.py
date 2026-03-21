"""Score Image Restoration Library"""

from .restoration_engine import (
    RestorationOptions,
    RestorationResult,
    PageBounds,
    restore,
    detect_page_bounds,
    correct_perspective,
    detect_skew,
    correct_skew,
    convert_grayscale,
    remove_shadows,
    enhance_contrast,
    binarize
)

from .quality_scorer import QualityScorer

__all__ = [
    'RestorationOptions',
    'RestorationResult',
    'PageBounds',
    'restore',
    'detect_page_bounds',
    'correct_perspective',
    'detect_skew',
    'correct_skew',
    'convert_grayscale',
    'remove_shadows',
    'enhance_contrast',
    'binarize',
    'QualityScorer'
]
