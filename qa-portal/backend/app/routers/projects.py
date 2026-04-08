from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID

from app.database import get_db
from app.models.project import Project, Module
from app.models.user import User
from app.schemas.project import (
    ProjectCreate, ProjectUpdate, ProjectResponse, ProjectSummary,
    ModuleCreate, ModuleUpdate, ModuleResponse,
)
from app.services.auth_service import get_current_user, require_admin

router = APIRouter()


# ─── Proyectos ────────────────────────────────────────────────────────────────

@router.get("", response_model=List[ProjectSummary])
def list_projects(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return db.query(Project).order_by(Project.created_at.desc()).all()


@router.post("", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
def create_project(
    body: ProjectCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    project = Project(
        name=body.name,
        description=body.description,
        created_by=current_user.id,
    )
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


@router.get("/{project_id}", response_model=ProjectResponse)
def get_project(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Proyecto no encontrado")
    return project


@router.put("/{project_id}", response_model=ProjectResponse)
def update_project(
    project_id: UUID,
    body: ProjectUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Proyecto no encontrado")

    if body.name is not None:
        project.name = body.name
    if body.description is not None:
        project.description = body.description
    if body.is_active is not None:
        project.is_active = body.is_active

    db.commit()
    db.refresh(project)
    return project


@router.delete("/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_project(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Proyecto no encontrado")
    db.delete(project)
    db.commit()


# ─── Módulos ──────────────────────────────────────────────────────────────────

@router.get("/{project_id}/modules", response_model=List[ModuleResponse])
def list_modules(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Proyecto no encontrado")
    return db.query(Module).filter(Module.project_id == project_id).order_by(Module.order).all()


@router.post("/{project_id}/modules", response_model=ModuleResponse, status_code=status.HTTP_201_CREATED)
def create_module(
    project_id: UUID,
    body: ModuleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Proyecto no encontrado")

    # Si no se especifica order, ponerlo al final
    if body.order == 0:
        last = db.query(Module).filter(Module.project_id == project_id).order_by(Module.order.desc()).first()
        order = (last.order + 1) if last else 0
    else:
        order = body.order

    module = Module(
        project_id=project_id,
        name=body.name,
        description=body.description,
        order=order,
    )
    db.add(module)
    db.commit()
    db.refresh(module)
    return module


@router.put("/{project_id}/modules/{module_id}", response_model=ModuleResponse)
def update_module(
    project_id: UUID,
    module_id: UUID,
    body: ModuleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    module = db.query(Module).filter(Module.id == module_id, Module.project_id == project_id).first()
    if not module:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Módulo no encontrado")

    if body.name is not None:
        module.name = body.name
    if body.description is not None:
        module.description = body.description
    if body.order is not None:
        module.order = body.order

    db.commit()
    db.refresh(module)
    return module


@router.delete("/{project_id}/modules/{module_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_module(
    project_id: UUID,
    module_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    module = db.query(Module).filter(Module.id == module_id, Module.project_id == project_id).first()
    if not module:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Módulo no encontrado")
    db.delete(module)
    db.commit()
