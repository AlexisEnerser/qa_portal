from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from uuid import UUID
import json

from app.database import get_db
from app.models.bug import Bug, BugSeverity, BugStatus
from app.models.execution import TestExecutionResult
from app.models.user import User
from app.schemas.bug import BugCreate, BugUpdate, BugResponse, BugSummary, BugAIRequest
from app.services.auth_service import get_current_user
from app.services.ai_client import generate

router = APIRouter()


def _get_result_or_404(result_id: UUID, db: Session) -> TestExecutionResult:
    result = db.query(TestExecutionResult).filter(TestExecutionResult.id == result_id).first()
    if not result:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Resultado de ejecución no encontrado")
    return result


def _bug_with_screenshots(bug: Bug) -> dict:
    """Construye la respuesta del bug incluyendo screenshots del execution_result."""
    data = {
        "id": bug.id,
        "execution_result_id": bug.execution_result_id,
        "title": bug.title,
        "description": bug.description,
        "steps_to_reproduce": bug.steps_to_reproduce,
        "severity": bug.severity,
        "status": bug.status,
        "external_id": bug.external_id,
        "created_by": bug.created_by,
        "created_at": bug.created_at,
        "creator": bug.creator,
        "screenshots": sorted(bug.execution_result.screenshots, key=lambda s: s.order) if bug.execution_result else [],
    }
    return data


# ─── IA: redactar bug ─────────────────────────────────────────────────────────

@router.post("/results/{result_id}/bugs/draft")
async def draft_bug_with_ai(
    result_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Genera un borrador del bug usando IA a partir del test case fallido.
    No guarda en BD — devuelve la propuesta para que el QA la revise.
    """
    result = _get_result_or_404(result_id, db)
    tc = result.test_case

    steps_text = "\n".join(
        f"{s.order}. Acción: {s.action}"
        + (f" | Datos: {s.test_data}" if s.test_data else "")
        + f" | Resultado esperado: {s.expected_result}"
        for s in sorted(tc.steps, key=lambda s: s.order)
    )

    system_prompt = """Eres un experto en QA. Tu tarea es redactar un reporte de bug claro y estructurado en español.
Responde ÚNICAMENTE con un JSON válido, sin texto adicional, con esta estructura exacta:
{
  "title": "Título conciso del bug (máx 100 caracteres)",
  "description": "Descripción clara del problema detectado",
  "steps_to_reproduce": "Pasos numerados para reproducir el bug",
  "severity_suggestion": "critical | high | medium | low",
  "severity_reason": "Breve justificación de la severidad sugerida"
}"""

    notes_section = f"\nObservaciones del QA al ejecutar: {result.notes}" if result.notes else ""

    prompt = f"""Test case fallido: {tc.title}
Módulo: {tc.module.name}
Precondiciones: {tc.preconditions or 'N/A'}

Pasos ejecutados:
{steps_text}
{notes_section}

Redacta el reporte de bug basándote en esta información."""

    try:
        raw = await generate(prompt, system_prompt=system_prompt, max_tokens=1000)

        clean = raw.strip()
        if clean.startswith("```"):
            clean = clean.split("```")[1]
            if clean.startswith("json"):
                clean = clean[4:]
        if clean.endswith("```"):
            clean = clean[:-3]

        data = json.loads(clean.strip())
        return data

    except json.JSONDecodeError:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="La IA devolvió una respuesta inválida. Intenta de nuevo.",
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Error al conectar con el servicio de IA: {str(e)}",
        )


# ─── CRUD bugs ────────────────────────────────────────────────────────────────

@router.post("/results/{result_id}/bugs", response_model=BugResponse, status_code=status.HTTP_201_CREATED)
def create_bug(
    result_id: UUID,
    body: BugCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _get_result_or_404(result_id, db)

    bug = Bug(
        execution_result_id=result_id,
        title=body.title,
        description=body.description,
        steps_to_reproduce=body.steps_to_reproduce,
        severity=body.severity,
        status=BugStatus.open,
        created_by=current_user.id,
    )
    db.add(bug)
    db.commit()
    db.refresh(bug)
    return _bug_with_screenshots(bug)


@router.get("/results/{result_id}/bugs", response_model=List[BugSummary])
def list_bugs_by_result(
    result_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _get_result_or_404(result_id, db)
    return (
        db.query(Bug)
        .filter(Bug.execution_result_id == result_id)
        .order_by(Bug.created_at.desc())
        .all()
    )


@router.get("/executions/{execution_id}/bugs", response_model=List[BugResponse])
def list_bugs_by_execution(
    execution_id: UUID,
    severity: Optional[BugSeverity] = None,
    status_filter: Optional[BugStatus] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lista todos los bugs de una sesión de ejecución con filtros opcionales."""
    query = (
        db.query(Bug)
        .join(TestExecutionResult)
        .filter(TestExecutionResult.execution_id == execution_id)
    )
    if severity:
        query = query.filter(Bug.severity == severity)
    if status_filter:
        query = query.filter(Bug.status == status_filter)

    return [_bug_with_screenshots(b) for b in query.order_by(Bug.created_at.desc()).all()]


@router.get("/bugs/{bug_id}", response_model=BugResponse)
def get_bug(
    bug_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    bug = db.query(Bug).filter(Bug.id == bug_id).first()
    if not bug:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bug no encontrado")
    return _bug_with_screenshots(bug)


@router.put("/bugs/{bug_id}", response_model=BugResponse)
def update_bug(
    bug_id: UUID,
    body: BugUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    bug = db.query(Bug).filter(Bug.id == bug_id).first()
    if not bug:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bug no encontrado")

    if body.title is not None:
        bug.title = body.title
    if body.description is not None:
        bug.description = body.description
    if body.steps_to_reproduce is not None:
        bug.steps_to_reproduce = body.steps_to_reproduce
    if body.severity is not None:
        bug.severity = body.severity
    if body.status is not None:
        bug.status = body.status
    if body.external_id is not None:
        bug.external_id = body.external_id

    db.commit()
    db.refresh(bug)
    return _bug_with_screenshots(bug)


@router.delete("/bugs/{bug_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_bug(
    bug_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    bug = db.query(Bug).filter(Bug.id == bug_id).first()
    if not bug:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bug no encontrado")
    db.delete(bug)
    db.commit()
