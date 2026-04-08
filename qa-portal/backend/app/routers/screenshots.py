from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
import uuid
import os
from datetime import datetime, timezone

from app.database import get_db
from app.models.execution import TestExecutionResult, Screenshot
from app.models.user import User
from app.schemas.screenshot import ScreenshotResponse, ScreenshotReorder
from app.services.auth_service import get_current_user
from app.services.wasabi_service import upload_file, get_download_url

router = APIRouter()

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
MAX_FILE_SIZE_MB = 10
WASABI_FOLDER = "qa-portal/screenshots"


def _get_result_or_404(result_id: UUID, db: Session) -> TestExecutionResult:
    result = db.query(TestExecutionResult).filter(TestExecutionResult.id == result_id).first()
    if not result:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Resultado no encontrado")
    return result


# ─── Listar capturas ──────────────────────────────────────────────────────────

@router.get("/results/{result_id}/screenshots", response_model=List[ScreenshotResponse])
def list_screenshots(
    result_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _get_result_or_404(result_id, db)
    return (
        db.query(Screenshot)
        .filter(Screenshot.execution_result_id == result_id)
        .order_by(Screenshot.order)
        .all()
    )


# ─── Subir imágenes ───────────────────────────────────────────────────────────

@router.post(
    "/results/{result_id}/screenshots",
    response_model=List[ScreenshotResponse],
    status_code=status.HTTP_201_CREATED,
)
async def upload_screenshots(
    result_id: UUID,
    files: List[UploadFile] = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = _get_result_or_404(result_id, db)
    execution_id = str(result.execution_id)

    last = (
        db.query(Screenshot)
        .filter(Screenshot.execution_result_id == result_id)
        .order_by(Screenshot.order.desc())
        .first()
    )
    next_order = (last.order + 1) if last else 0

    saved = []
    for file in files:
        ext = os.path.splitext(file.filename or "")[1].lower()
        if ext not in ALLOWED_EXTENSIONS:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Formato no permitido: {ext}. Usa jpg, png o webp.",
            )

        content = await file.read()
        if len(content) > MAX_FILE_SIZE_MB * 1024 * 1024:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"El archivo {file.filename} supera {MAX_FILE_SIZE_MB}MB.",
            )

        file_id = uuid.uuid4()
        file_name = f"{file_id}{ext}"

        # Determine MIME type
        mime_map = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp"}
        mime_type = mime_map.get(ext, "application/octet-stream")

        # Upload to Wasabi
        folder = f"{WASABI_FOLDER}/{execution_id}"
        wasabi_file_id = await upload_file(
            file_bytes=content,
            filename=file_name,
            filetype=mime_type,
            folder=folder,
        )

        screenshot = Screenshot(
            execution_result_id=result_id,
            file_path=None,
            file_name=file_name,
            wasabi_file_id=wasabi_file_id,
            order=next_order,
            taken_at=datetime.now(timezone.utc),
            taken_by=current_user.id,
        )
        db.add(screenshot)
        next_order += 1
        saved.append(screenshot)

    db.commit()
    for s in saved:
        db.refresh(s)

    return saved


# ─── Reordenar ────────────────────────────────────────────────────────────────

@router.put("/results/{result_id}/screenshots/reorder", response_model=List[ScreenshotResponse])
def reorder_screenshots(
    result_id: UUID,
    body: ScreenshotReorder,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _get_result_or_404(result_id, db)

    for new_order, screenshot_id in enumerate(body.screenshot_ids):
        screenshot = db.query(Screenshot).filter(
            Screenshot.id == screenshot_id,
            Screenshot.execution_result_id == result_id,
        ).first()
        if not screenshot:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Captura {screenshot_id} no encontrada en este resultado",
            )
        screenshot.order = new_order

    db.commit()

    return (
        db.query(Screenshot)
        .filter(Screenshot.execution_result_id == result_id)
        .order_by(Screenshot.order)
        .all()
    )


# ─── Eliminar ────────────────────────────────────────────────────────────────

@router.delete("/screenshots/{screenshot_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_screenshot(
    screenshot_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    screenshot = db.query(Screenshot).filter(Screenshot.id == screenshot_id).first()
    if not screenshot:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Captura no encontrada")

    db.delete(screenshot)
    db.commit()


# ─── Servir imagen (redirect a Wasabi presigned URL) ─────────────────────────

@router.get("/screenshots/file/{file_name}")
async def serve_screenshot(file_name: str, db: Session = Depends(get_db)):
    screenshot = db.query(Screenshot).filter(Screenshot.file_name == file_name).first()
    if not screenshot:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Archivo no encontrado")

    if screenshot.wasabi_file_id:
        url = await get_download_url(screenshot.wasabi_file_id)
        return RedirectResponse(url=url, status_code=302)

    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Archivo no disponible")
