from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID

from app.database import get_db
from app.schemas.user import UserCreate, UserUpdate, UserPasswordUpdate, UserStatusUpdate, UserResponse, UserSummary
from app.services.auth_service import hash_password, require_admin, get_current_user
from app.models.user import User

router = APIRouter()


@router.get("/qa-team", response_model=List[UserSummary])
def list_qa_team(
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Lista usuarios activos (para dropdowns de asignación). Cualquier usuario autenticado."""
    return db.query(User).filter(User.is_active == True).order_by(User.name).all()


@router.get("/", response_model=List[UserResponse])
def list_users(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    return db.query(User).order_by(User.created_at).all()


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(
    body: UserCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    existing = db.query(User).filter(User.email == body.email).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="El email ya está registrado")

    user = User(
        name=body.name,
        email=body.email,
        password_hash=hash_password(body.password),
        role=body.role,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.put("/{user_id}", response_model=UserResponse)
def update_user(
    user_id: UUID,
    body: UserUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")

    if body.name is not None:
        user.name = body.name
    if body.email is not None:
        existing = db.query(User).filter(User.email == body.email, User.id != user_id).first()
        if existing:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="El email ya está en uso")
        user.email = body.email
    if body.role is not None:
        user.role = body.role

    db.commit()
    db.refresh(user)
    return user


@router.patch("/{user_id}/password", status_code=status.HTTP_204_NO_CONTENT)
def update_password(
    user_id: UUID,
    body: UserPasswordUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")
    user.password_hash = hash_password(body.password)
    db.commit()


@router.patch("/{user_id}/status", response_model=UserResponse)
def update_status(
    user_id: UUID,
    body: UserStatusUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")
    user.is_active = body.is_active
    db.commit()
    db.refresh(user)
    return user
