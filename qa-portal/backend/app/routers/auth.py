from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
import os, uuid

from app.database import get_db
from app.schemas.auth import LoginRequest, TokenResponse, RefreshRequest, AccessTokenResponse
from app.schemas.user import UserResponse
from app.services.auth_service import (
    authenticate_user,
    create_access_token,
    create_refresh_token,
    validate_refresh_token,
    revoke_refresh_token,
    get_current_user,
)
from app.services.wasabi_service import upload_file, get_download_url
from app.models.user import User

router = APIRouter()


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    user = authenticate_user(body.email, body.password, db)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas",
        )
    return TokenResponse(
        access_token=create_access_token(user),
        refresh_token=create_refresh_token(user, db),
    )


@router.post("/refresh", response_model=AccessTokenResponse)
def refresh(body: RefreshRequest, db: Session = Depends(get_db)):
    user = validate_refresh_token(body.refresh_token, db)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token inválido o expirado",
        )
    return AccessTokenResponse(access_token=create_access_token(user))


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(body: RefreshRequest, db: Session = Depends(get_db)):
    revoke_refresh_token(body.refresh_token, db)


@router.get("/me", response_model=UserResponse)
def me(current_user: User = Depends(get_current_user)):
    return current_user


# ─── Perfil ───────────────────────────────────────────────────────────────────


@router.put("/profile", response_model=UserResponse)
def update_profile(
    body: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from app.services.auth_service import hash_password, verify_password
    current_password = body.get("current_password", "")
    new_password = body.get("new_password", "")
    if not current_password or not new_password:
        raise HTTPException(status_code=422, detail="Se requiere contraseña actual y nueva")
    if not verify_password(current_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Contraseña actual incorrecta")
    if len(new_password) < 6:
        raise HTTPException(status_code=422, detail="La nueva contraseña debe tener al menos 6 caracteres")
    current_user.password_hash = hash_password(new_password)
    db.commit()
    db.refresh(current_user)
    return current_user


@router.post("/profile/avatar", response_model=UserResponse)
async def upload_avatar(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise HTTPException(status_code=422, detail="Formato no permitido")

    content = await file.read()
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Archivo supera 5MB")

    mime_map = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp"}
    mime_type = mime_map.get(ext, "application/octet-stream")

    file_name = f"{uuid.uuid4()}{ext}"
    folder = f"qa-portal/avatars/{current_user.id}"

    wasabi_file_id = await upload_file(
        file_bytes=content,
        filename=file_name,
        filetype=mime_type,
        folder=folder,
    )

    current_user.avatar_file_id = wasabi_file_id
    current_user.avatar_path = file_name  # Keep filename for URL construction
    db.commit()
    db.refresh(current_user)
    return current_user


@router.get("/profile/avatar/{file_name}")
async def serve_avatar(file_name: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.avatar_path == file_name).first()
    if not user or not user.avatar_file_id:
        raise HTTPException(status_code=404, detail="Avatar no encontrado")

    url = await get_download_url(user.avatar_file_id)
    return RedirectResponse(url=url, status_code=302)
