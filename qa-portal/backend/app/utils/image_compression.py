"""Image compression utilities for screenshot processing."""

import io
import os

from PIL import Image


def compress_screenshot(file_path: str) -> tuple[bytes, str]:
    """Compress large screenshots to JPEG; preserve small images unchanged.

    - Images with width > 1400px are resized (maintaining aspect ratio) and
      converted to JPEG quality 80.
    - Images with width <= 1400px are returned as-is (original bytes and mime_type).

    Returns:
        (compressed_bytes, mime_type)
    """
    img = Image.open(file_path)
    if img.width > 1400:
        img.thumbnail((1400, 1400))
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")
        buffer = io.BytesIO()
        img.save(buffer, format="JPEG", quality=80)
        return buffer.getvalue(), "image/jpeg"
    with open(file_path, "rb") as f:
        original_bytes = f.read()
    ext = os.path.splitext(file_path)[1].lstrip(".").lower()
    mime_type = f"image/{ext if ext != 'jpg' else 'jpeg'}"
    return original_bytes, mime_type
