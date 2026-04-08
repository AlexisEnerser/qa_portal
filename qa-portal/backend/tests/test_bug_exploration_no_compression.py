"""
Bug Condition Exploration Test — Task 1, Test B (Python)
**Validates: Requirements 1.2, 1.3**

Bug B: totalPayloadSize > 50MB AND nginxProxyReadTimeout <= 120s AND noImageCompression → Docker timeout

This test creates test images >1400px wide and verifies that the current code
in pdf_data.py reads/encodes them WITHOUT any compression. The base64 output
size should be approximately original_size × 1.37 (base64 overhead), proving
that no compression or resizing is applied.

EXPECTED: This test FAILS on unfixed code (confirming the bug exists).
The assertion that images ARE compressed will fail because the current code
does NO compression at all.
"""

import base64
import os
import tempfile

import pytest
from hypothesis import given, settings, HealthCheck
from hypothesis import strategies as st
from PIL import Image


# ---------------------------------------------------------------------------
# Helper: create a test image of a given size and save to a temp file
# ---------------------------------------------------------------------------

def create_test_image(width: int, height: int, tmp_dir: str, name: str = "test.png") -> str:
    """Create a PNG image of the given dimensions and return its file path."""
    img = Image.new("RGB", (width, height), color=(100, 150, 200))
    path = os.path.join(tmp_dir, name)
    img.save(path, format="PNG")
    return path


# ---------------------------------------------------------------------------
# Extract the read-and-encode logic from pdf_data.py (the bug is here)
# This mirrors exactly what get_execution_pdf_data() does for each screenshot
# ---------------------------------------------------------------------------

def read_and_encode_screenshot(file_path: str) -> dict:
    """
    Use the actual compress_screenshot logic from the image_compression utility.
    This mirrors what get_execution_pdf_data() does for each screenshot.
    """
    from app.utils.image_compression import compress_screenshot

    file_name = os.path.basename(file_path)
    compressed_bytes, mime_type = compress_screenshot(file_path)
    encoded = base64.b64encode(compressed_bytes).decode("utf-8")
    return {
        "file_name": file_name,
        "base64": encoded,
        "mime_type": mime_type,
        "original_size": os.path.getsize(file_path),
        "encoded_size": len(encoded),
    }


# ---------------------------------------------------------------------------
# Property-based exploration test
# ---------------------------------------------------------------------------

class TestBugExplorationNoCompression:
    """
    Property 1 (Bug Condition): Images >1400px wide are sent without
    compression. The base64 size ≈ original_size × 1.37 (no reduction).

    On FIXED code, large images should be compressed/resized, so the
    base64 size should be SIGNIFICANTLY SMALLER than original × 1.37.
    """

    @given(
        width=st.integers(min_value=1500, max_value=3000),
        height=st.integers(min_value=800, max_value=2000),
    )
    @settings(
        max_examples=35,
        suppress_health_check=[HealthCheck.too_slow],
        deadline=None,
    )
    def test_large_images_should_be_compressed_but_are_not(self, width: int, height: int):
        """
        **Validates: Requirements 1.2, 1.3**

        For any image with width > 1400px, the encoding logic from pdf_data.py
        SHOULD compress/resize it before base64 encoding. On unfixed code,
        NO compression happens, so base64_size ≈ original_size × 1.37.

        This test asserts that compression IS applied (encoded size should be
        significantly less than raw base64 of the original). On unfixed code,
        this assertion FAILS — confirming the bug.
        """
        with tempfile.TemporaryDirectory() as tmp_dir:
            img_path = create_test_image(width, height, tmp_dir, f"large_{width}x{height}.png")

            result = read_and_encode_screenshot(img_path)

            # On FIXED code: large images are converted to JPEG and resized
            # On UNFIXED code: mime_type stays as image/png (no conversion)
            assert result["mime_type"] == "image/jpeg", (
                f"Bug confirmed: Image {width}x{height} was NOT converted to JPEG. "
                f"mime_type = {result['mime_type']} (expected image/jpeg after compression)."
            )

            # Verify the image was actually resized to max 1400px width
            decoded_bytes = base64.b64decode(result["base64"])
            from io import BytesIO
            decoded_img = Image.open(BytesIO(decoded_bytes))
            assert decoded_img.width <= 1400, (
                f"Bug confirmed: Image was NOT resized. "
                f"Original: {width}x{height}, "
                f"After encoding: {decoded_img.width}x{decoded_img.height}. "
                f"Expected max width 1400px after compression."
            )

    def test_specific_example_large_screenshot_no_compression(self):
        """
        Concrete example: a 2000×1200 PNG image should be compressed
        before base64 encoding. On unfixed code, it is NOT compressed.

        **Validates: Requirements 1.2, 1.3**
        """
        with tempfile.TemporaryDirectory() as tmp_dir:
            img_path = create_test_image(2000, 1200, tmp_dir, "big_screenshot.png")
            original_file_size = os.path.getsize(img_path)

            result = read_and_encode_screenshot(img_path)

            # Verify the mime_type is still image/png (not converted to jpeg)
            # On fixed code, it should be image/jpeg for large images
            assert result["mime_type"] == "image/jpeg", (
                f"Bug confirmed: Large image was NOT converted to JPEG. "
                f"mime_type = {result['mime_type']} (expected image/jpeg after compression). "
                f"Original size: {original_file_size} bytes, "
                f"Encoded size: {result['encoded_size']} chars"
            )

    def test_large_image_not_resized(self):
        """
        A 2500×1800 image should be resized to max 1400px width on fixed code.
        On unfixed code, the image dimensions are NOT checked or modified.

        **Validates: Requirements 1.3**
        """
        with tempfile.TemporaryDirectory() as tmp_dir:
            width, height = 2500, 1800
            img_path = create_test_image(width, height, tmp_dir, "huge.png")

            result = read_and_encode_screenshot(img_path)

            # Decode the base64 back and check if the image was resized
            decoded_bytes = base64.b64decode(result["base64"])
            from io import BytesIO
            decoded_img = Image.open(BytesIO(decoded_bytes))

            # On FIXED code: width should be <= 1400 (resized)
            # On UNFIXED code: width remains 2500 (no resizing)
            assert decoded_img.width <= 1400, (
                f"Bug confirmed: Image was NOT resized. "
                f"Original: {width}x{height}, "
                f"After encoding: {decoded_img.width}x{decoded_img.height}. "
                f"Expected max width 1400px after compression."
            )
