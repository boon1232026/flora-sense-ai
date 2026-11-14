from __future__ import annotations

from statistics import fmean
from typing import Iterable, Sequence

from .types import ImageMetrics

Pixel = Sequence[int]


def _normalise_pixels(pixels: Iterable[Pixel]) -> list[tuple[int, int, int]]:
    output: list[tuple[int, int, int]] = []
    for pixel in pixels:
        if len(pixel) != 3:
            continue
        r, g, b = (max(0, min(255, int(v))) for v in pixel)
        output.append((r, g, b))
    return output


def analyze_rgb_pixels(pixels: Iterable[Pixel]) -> ImageMetrics:
    """Compute baseline leaf metrics without requiring OpenCV.

    ExG uses 2G - R - B on normalized channels. A production path can replace the
    RGB-list input with decoded image arrays while keeping the same metric output.
    """
    values = _normalise_pixels(pixels)
    if not values:
        return ImageMetrics()

    total = len(values)
    mean_r = fmean(p[0] for p in values) / 255.0
    mean_g = fmean(p[1] for p in values) / 255.0
    mean_b = fmean(p[2] for p in values) / 255.0
    green_pixels = sum(1 for r, g, b in values if g > r * 1.05 and g > b * 1.05)
    exg = (2.0 * mean_g) - mean_r - mean_b
    green_ratio = green_pixels / total
    mean_values = (mean_r * 255.0, mean_g * 255.0, mean_b * 255.0)
    brightness_ok = 20.0 <= fmean(mean_values) <= 245.0

    return ImageMetrics(
        exg=round(exg, 4),
        green_ratio=round(green_ratio, 4),
        mean_rgb=tuple(round(v, 2) for v in mean_values),
        quality_ok=brightness_ok and total >= 10,
    )


def analyze_image_bytes(image_bytes: bytes) -> ImageMetrics:
    """Decode a compressed image and compute baseline leaf metrics.

    OpenCV is optional for unit tests; the production AI service installs it from
    requirements.txt. Raises ValueError for malformed image bytes.
    """
    try:
        import cv2
        import numpy as np
    except ImportError as exc:
        raise RuntimeError("Install ai-engine/requirements.txt for image analysis") from exc
    data = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(data, cv2.IMREAD_COLOR)
    if image is None or image.size == 0:
        raise ValueError("invalid_image_bytes")
    rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    pixels = rgb.reshape(-1, 3)
    if len(pixels) > 300_000:
        step = max(1, len(pixels) // 300_000)
        pixels = pixels[::step]
    return analyze_rgb_pixels(pixels.tolist())
