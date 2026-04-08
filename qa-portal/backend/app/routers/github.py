from fastapi import APIRouter, Depends, HTTPException, Query, Body
from app.services.github_service import github_service
from app.routers.auth import get_current_user
from app.database import get_db
from sqlalchemy.orm import Session
from app.models.user import User
from app.models.reports import PostingSheet

router = APIRouter()

@router.get("/commits")
async def get_github_commits(
    org: str, 
    repo: str, 
    branch: str = "main",
    current_user: User = Depends(get_current_user)
):
    """
    Lista los últimos 100 commits de un repositorio.
    """
    commits = await github_service.get_recent_commits(org, repo, branch)
    if not commits:
        raise HTTPException(status_code=404, detail="Repositorio o rama no encontrados")
    return commits

@router.post("/posting-sheet-data")
async def generate_posting_sheet_data(
    org: str = Body(...),
    repo: str = Body(...),
    branch: str = Body(...),
    commit_sha: str = Body(...),
    business: str = Body(""),
    product: str = Body(""),
    project_detail: str = Body(""),
    user_rollback: str = Body(""),
    user_rollback_mail: str = Body(""),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Genera la data estructurada para la Hoja de Posteo y realiza el mapeo de desarrollador.
    Incluye campos normativos: business, product, project_detail, user_rollback, user_rollback_mail.
    """
    data = await github_service.generate_posting_sheet_data(db, org, repo, branch, commit_sha)
    if "error" in data:
        raise HTTPException(status_code=400, detail=data["error"])

    # Agregar campos normativos del formulario
    data["business"] = business
    data["product"] = product
    data["project_detail"] = project_detail
    data["user_rollback"] = user_rollback
    data["user_rollback_mail"] = user_rollback_mail

    # Guardar en posting_sheets
    record = PostingSheet(
        commit_id=commit_sha,
        repo=repo,
        org=org,
        branch=branch,
        summary_json=data,
        created_by=current_user.id,
    )
    db.add(record)
    db.commit()

    return data
