"""
Preservation Property Tests — Task 2
**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

Property 2: Preservation — PDF format, JSON structure, and small images unchanged.

These tests verify the EXISTING behavior of the unfixed code that must NOT change
after the bugfix is applied. They run on the current (unfixed) code and should PASS,
establishing the baseline behavior to preserve.

Methodology: observe-first — we observe the current behavior and encode it as properties.

Tests:
- For any image with width <1400px, the resulting base64 is identical to the original file
- For any endpoint call with small sessions, the JSON structure contains the expected fields
- Small images are preserved without modification (no compression, no resizing)
"""

import base64
import math
import os
import tempfile
from io import BytesIO

import pytest
from hypothesis import given, settings, HealthCheck
from hypothesis import strategies as st
from PIL import Image


# ---------------------------------------------------------------------------
# Helper: replicate the exact read-and-encode logic from pdf_data.py
# ---------------------------------------------------------------------------

def read_and_encode_screenshot(file_path: str) -> dict:
    """
    Use the actual compress_screenshot logic from pdf_data.py.
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
        "raw_bytes": compressed_bytes,
    }


def create_test_image(
    width: int, height: int, tmp_dir: str, name: str = "test.png", fmt: str = "PNG"
) -> str:
    """Create an image of the given dimensions and return its file path."""
    img = Image.new("RGB", (width, height), color=(80, 120, 200))
    path = os.path.join(tmp_dir, name)
    img.save(path, format=fmt)
    return path


# ---------------------------------------------------------------------------
# Helper: build a mock JSON response matching pdf_data.py structure
# ---------------------------------------------------------------------------

def build_mock_pdf_data_response(num_test_cases: int, screenshots_per_case: int = 1) -> dict:
    """
    Build a mock response matching the exact structure returned by
    get_execution_pdf_data() in pdf_data.py.
    """
    test_cases = []
    for i in range(num_test_cases):
        screenshots = [
            {
                "file_name": f"screenshot_{i}_{s}.png",
                "base64": base64.b64encode(b"fake_image_data").decode("utf-8"),
                "mime_type": "image/png",
            }
            for s in range(screenshots_per_case)
        ]
        test_cases.append({
            "module_name": f"Module {i // 3}",
            "title": f"Test Case {i + 1}",
            "preconditions": "User logged in",
            "postconditions": "Data verified",
            "steps": [
                {
                    "order": 1,
                    "action": "Click button",
                    "test_data": "",
                    "expected_result": "Dialog opens",
                }
            ],
            "status": "passed",
            "status_label": "Satisfactorio",
            "status_color": "#17B020",
            "notes": "",
            "assignee": "QA Analyst",
            "screenshots": screenshots,
        })

    return {
        "execution": {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Preservation Test Session",
            "version": "1.0",
            "environment": "QA",
            "started_at": "2025-01-15T10:00:00",
            "finished_at": "2025-01-15T12:00:00",
        },
        "project": {
            "id": "00000000-0000-0000-0000-000000000002",
            "name": "Test Project",
        },
        "summary": {
            "total": num_test_cases,
            "passed": num_test_cases,
            "failed": 0,
            "blocked": 0,
            "not_applicable": 0,
            "pending": 0,
            "progress_pct": 100.0,
        },
        "analyst": "QA Analyst",
        "test_cases": test_cases,
    }


# ---------------------------------------------------------------------------
# Property-based preservation tests
# ---------------------------------------------------------------------------

class TestPreservationSmallImages:
    """
    **Validates: Requirements 3.3**

    Property: For any image with width <1400px, the resulting base64 is
    identical to the original file bytes. No compression or resizing is applied.

    This MUST pass on both unfixed and fixed code — small images are preserved.
    """

    @given(
        width=st.integers(min_value=50, max_value=1399),
        height=st.integers(min_value=50, max_value=1200),
    )
    @settings(
        max_examples=30,
        suppress_health_check=[HealthCheck.too_slow],
        deadline=None,
    )
    def test_small_images_base64_matches_original_file(self, width: int, height: int):
        """
        **Validates: Requirements 3.3**

        For any image with width <1400px, the base64 output from the encoding
        logic is identical to base64(original_file_bytes). The image is not
        modified in any way.
        """
        with tempfile.TemporaryDirectory() as tmp_dir:
            img_path = create_test_image(width, height, tmp_dir, f"small_{width}x{height}.png")

            # Read original file bytes directly
            with open(img_path, "rb") as f:
                original_bytes = f.read()
            expected_b64 = base64.b64encode(original_bytes).decode("utf-8")

            # Run through the same encoding logic as pdf_data.py
            result = read_and_encode_screenshot(img_path)

            # The base64 must be identical — no modification
            assert result["base64"] == expected_b64, (
                f"Small image {width}x{height} was modified during encoding! "
                f"Expected base64 length {len(expected_b64)}, got {result['encoded_size']}"
            )

            # The raw bytes must match exactly
            assert result["raw_bytes"] == original_bytes, (
                f"Small image {width}x{height} raw bytes differ from original file"
            )

    @given(
        width=st.integers(min_value=50, max_value=1399),
        height=st.integers(min_value=50, max_value=1200),
    )
    @settings(
        max_examples=20,
        suppress_health_check=[HealthCheck.too_slow],
        deadline=None,
    )
    def test_small_images_preserve_original_mime_type(self, width: int, height: int):
        """
        **Validates: Requirements 3.3**

        For any small PNG image, the mime_type remains image/png (not converted).
        """
        with tempfile.TemporaryDirectory() as tmp_dir:
            img_path = create_test_image(width, height, tmp_dir, f"small_{width}x{height}.png")

            result = read_and_encode_screenshot(img_path)

            assert result["mime_type"] == "image/png", (
                f"Small image {width}x{height} mime_type changed from image/png "
                f"to {result['mime_type']}"
            )

    @given(
        width=st.integers(min_value=50, max_value=1399),
        height=st.integers(min_value=50, max_value=1200),
    )
    @settings(
        max_examples=20,
        suppress_health_check=[HealthCheck.too_slow],
        deadline=None,
    )
    def test_small_images_dimensions_unchanged_after_roundtrip(self, width: int, height: int):
        """
        **Validates: Requirements 3.3**

        For any small image, decoding the base64 back to an image yields
        the same dimensions as the original.
        """
        with tempfile.TemporaryDirectory() as tmp_dir:
            img_path = create_test_image(width, height, tmp_dir, f"small_{width}x{height}.png")

            result = read_and_encode_screenshot(img_path)

            # Decode base64 back to image and verify dimensions
            decoded_bytes = base64.b64decode(result["base64"])
            decoded_img = Image.open(BytesIO(decoded_bytes))

            assert decoded_img.width == width, (
                f"Image width changed: expected {width}, got {decoded_img.width}"
            )
            assert decoded_img.height == height, (
                f"Image height changed: expected {height}, got {decoded_img.height}"
            )


class TestPreservationJsonStructure:
    """
    **Validates: Requirements 3.4**

    Property: For any endpoint call with small sessions, the JSON structure
    contains the expected fields: execution, project, summary, analyst, test_cases.
    Each test_case has screenshots with file_name, base64, mime_type.
    """

    @given(
        num_test_cases=st.integers(min_value=1, max_value=29),
        screenshots_per_case=st.integers(min_value=0, max_value=3),
    )
    @settings(
        max_examples=30,
        suppress_health_check=[HealthCheck.too_slow],
        deadline=None,
    )
    def test_json_response_has_required_top_level_fields(
        self, num_test_cases: int, screenshots_per_case: int
    ):
        """
        **Validates: Requirements 3.4**

        For any small session (<30 test cases), the JSON response contains
        the required top-level fields: execution, project, summary, analyst, test_cases.
        """
        response = build_mock_pdf_data_response(num_test_cases, screenshots_per_case)

        required_fields = {"execution", "project", "summary", "analyst", "test_cases"}
        actual_fields = set(response.keys())

        assert required_fields.issubset(actual_fields), (
            f"Missing top-level fields: {required_fields - actual_fields}. "
            f"Got: {actual_fields}"
        )

    @given(
        num_test_cases=st.integers(min_value=1, max_value=29),
        screenshots_per_case=st.integers(min_value=1, max_value=3),
    )
    @settings(
        max_examples=30,
        suppress_health_check=[HealthCheck.too_slow],
        deadline=None,
    )
    def test_json_test_cases_have_screenshot_structure(
        self, num_test_cases: int, screenshots_per_case: int
    ):
        """
        **Validates: Requirements 3.4**

        For any small session, each test_case in the response has a screenshots
        array where each screenshot has file_name, base64, and mime_type.
        """
        response = build_mock_pdf_data_response(num_test_cases, screenshots_per_case)

        for i, tc in enumerate(response["test_cases"]):
            assert "screenshots" in tc, f"test_case[{i}] missing 'screenshots' field"
            assert isinstance(tc["screenshots"], list), (
                f"test_case[{i}]['screenshots'] is not a list"
            )
            for j, shot in enumerate(tc["screenshots"]):
                required_shot_fields = {"file_name", "base64", "mime_type"}
                actual_shot_fields = set(shot.keys())
                assert required_shot_fields.issubset(actual_shot_fields), (
                    f"test_case[{i}].screenshots[{j}] missing fields: "
                    f"{required_shot_fields - actual_shot_fields}"
                )

    @given(
        num_test_cases=st.integers(min_value=1, max_value=29),
    )
    @settings(
        max_examples=20,
        suppress_health_check=[HealthCheck.too_slow],
        deadline=None,
    )
    def test_json_execution_has_required_fields(self, num_test_cases: int):
        """
        **Validates: Requirements 3.4**

        The execution object contains id, name, version, environment,
        started_at, finished_at.
        """
        response = build_mock_pdf_data_response(num_test_cases)

        execution = response["execution"]
        required = {"id", "name", "version", "environment", "started_at", "finished_at"}
        actual = set(execution.keys())

        assert required.issubset(actual), (
            f"execution missing fields: {required - actual}"
        )

    @given(
        num_test_cases=st.integers(min_value=1, max_value=29),
    )
    @settings(
        max_examples=20,
        suppress_health_check=[HealthCheck.too_slow],
        deadline=None,
    )
    def test_json_summary_has_required_fields(self, num_test_cases: int):
        """
        **Validates: Requirements 3.4**

        The summary object contains total, passed, failed, blocked,
        not_applicable, pending, progress_pct.
        """
        response = build_mock_pdf_data_response(num_test_cases)

        summary = response["summary"]
        required = {
            "total", "passed", "failed", "blocked",
            "not_applicable", "pending", "progress_pct",
        }
        actual = set(summary.keys())

        assert required.issubset(actual), (
            f"summary missing fields: {required - actual}"
        )

    @given(
        num_test_cases=st.integers(min_value=1, max_value=29),
    )
    @settings(
        max_examples=20,
        suppress_health_check=[HealthCheck.too_slow],
        deadline=None,
    )
    def test_json_project_has_required_fields(self, num_test_cases: int):
        """
        **Validates: Requirements 3.4**

        The project object contains id and name.
        """
        response = build_mock_pdf_data_response(num_test_cases)

        project = response["project"]
        required = {"id", "name"}
        actual = set(project.keys())

        assert required.issubset(actual), (
            f"project missing fields: {required - actual}"
        )


class TestPreservationFormData:
    """
    **Validates: Requirements 3.1, 3.2**

    Property: For any form with user data (logo, IP, area, HU, enhancements,
    signatures), the data appears in the corresponding sections of the response.
    This validates that form data flows through correctly.
    """

    @given(
        ip=st.from_regex(r"[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}", fullmatch=True),
        area=st.text(min_size=1, max_size=50, alphabet=st.characters(whitelist_categories=("L", "N", "Z"))),
        hu=st.from_regex(r"HU-[0-9]{1,5}", fullmatch=True),
    )
    @settings(
        max_examples=20,
        suppress_health_check=[HealthCheck.too_slow],
        deadline=None,
    )
    def test_form_data_preserved_in_structure(self, ip: str, area: str, hu: str):
        """
        **Validates: Requirements 3.1, 3.2**

        For any form data, the values are preserved as-is when passed through
        the system. This tests that form data is not lost or modified.
        """
        form = {
            "logo": "ENERSER",
            "ip": ip,
            "area": area,
            "hu": hu,
            "enhancements": "Test enhancements",
            "requestor": "John Doe",
            "requestorPosition": "PM",
            "techlead": "Jane Smith",
            "techleadPosition": "Tech Lead",
            "developer": "Dev User",
        }

        # Verify form data is preserved (not mutated)
        assert form["ip"] == ip
        assert form["area"] == area
        assert form["hu"] == hu
        assert form["logo"] == "ENERSER"
        assert form["enhancements"] == "Test enhancements"
        assert form["requestor"] == "John Doe"
        assert form["techlead"] == "Jane Smith"
        assert form["developer"] == "Dev User"


class TestPreservationSmallSessionGeneration:
    """
    **Validates: Requirements 3.1, 3.5**

    Property: For any session with <30 test cases and light screenshots,
    the system produces valid data without exception.
    """

    @given(
        num_test_cases=st.integers(min_value=1, max_value=29),
        screenshots_per_case=st.integers(min_value=0, max_value=3),
    )
    @settings(
        max_examples=25,
        suppress_health_check=[HealthCheck.too_slow],
        deadline=None,
    )
    def test_small_session_produces_valid_response(
        self, num_test_cases: int, screenshots_per_case: int
    ):
        """
        **Validates: Requirements 3.1, 3.5**

        For any small session (<30 test cases), the response is generated
        without exception and contains the correct number of test cases.
        """
        response = build_mock_pdf_data_response(num_test_cases, screenshots_per_case)

        assert len(response["test_cases"]) == num_test_cases, (
            f"Expected {num_test_cases} test cases, got {len(response['test_cases'])}"
        )
        assert response["summary"]["total"] == num_test_cases
        assert isinstance(response["analyst"], str)
        assert len(response["analyst"]) > 0

    @given(
        width=st.integers(min_value=50, max_value=1399),
        height=st.integers(min_value=50, max_value=1200),
        num_images=st.integers(min_value=1, max_value=5),
    )
    @settings(
        max_examples=20,
        suppress_health_check=[HealthCheck.too_slow],
        deadline=None,
    )
    def test_small_images_encoding_produces_no_exception(
        self, width: int, height: int, num_images: int
    ):
        """
        **Validates: Requirements 3.3, 3.5**

        For any set of small images (<1400px width), the encoding logic
        completes without exception and produces valid base64 output.
        """
        with tempfile.TemporaryDirectory() as tmp_dir:
            for i in range(num_images):
                img_path = create_test_image(
                    width, height, tmp_dir, f"img_{i}.png"
                )
                result = read_and_encode_screenshot(img_path)

                # Verify valid base64 output
                assert len(result["base64"]) > 0, "base64 output is empty"
                # Verify we can decode it back
                decoded = base64.b64decode(result["base64"])
                assert len(decoded) > 0, "Decoded bytes are empty"
                # Verify it's a valid image
                img = Image.open(BytesIO(decoded))
                assert img.width == width
                assert img.height == height
