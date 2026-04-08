"""Wasabi file storage service — proxies uploads through the backend."""

import hashlib
import httpx

from app.config import get_settings

_settings = get_settings()
_BASE = _settings.wasabi_api_url.rstrip("/")
_HEADERS = {"x-api-key": _settings.wasabi_api_key}
_TIMEOUT = 60.0


async def upload_file(
    file_bytes: bytes,
    filename: str,
    filetype: str,
    folder: str,
    metadata: dict | None = None,
) -> str:
    """Upload a file to Wasabi and return the file_id.

    Steps:
      1. Compute SHA-256 hash of the file bytes.
      2. Request a presigned upload URL (or get back an existing file_id).
      3. PUT the file to the presigned URL.
      4. Confirm the upload.
    """
    file_hash = hashlib.sha256(file_bytes).hexdigest()

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        # Step 1 — generate presigned URL
        gen_body: dict = {
            "filename": filename,
            "filetype": filetype,
            "folder": folder,
            "hash": file_hash,
        }
        if metadata:
            gen_body["metadata"] = metadata

        gen_resp = await client.post(
            f"{_BASE}/files/generate/url",
            json=gen_body,
            headers=_HEADERS,
        )
        gen_resp.raise_for_status()
        gen_data = gen_resp.json()

        file_id: str = gen_data["file_id"]

        # If the file already exists, skip upload
        if gen_data.get("alreadyExists"):
            return file_id

        presigned_url: str = gen_data["url"]

        # Step 2 — PUT file to presigned URL
        put_resp = await client.put(
            presigned_url,
            content=file_bytes,
            headers={
                "Content-Type": filetype,
                "x-amz-meta-file-id": file_id,
            },
        )
        put_resp.raise_for_status()

        # Step 3 — confirm upload
        confirm_resp = await client.post(
            f"{_BASE}/files/confirm/upload",
            json={
                "file_id": file_id,
                "size": len(file_bytes),
                "hash": file_hash,
            },
            headers=_HEADERS,
        )
        confirm_resp.raise_for_status()

    return file_id


async def get_download_url(file_id: str) -> str:
    """Get a presigned download URL for a file stored in Wasabi."""
    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.get(
            f"{_BASE}/files/download/{file_id}",
            headers=_HEADERS,
        )
        resp.raise_for_status()
        return resp.json()["url"]
