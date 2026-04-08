from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
import json

from app.database import get_db
from app.models.project import Module, TestCase, TestStep, TestCaseStatus
from app.models.user import User
from app.schemas.project import (
    TestCaseCreate, TestCaseUpdate, TestCaseResponse, TestCaseSummary,
    TestStepCreate, TestStepUpdate, TestStepResponse,
    AIGenerateRequest, AIGenerateResponse,
)
from app.services.auth_service import get_current_user
from app.services.ai_client import generate

router = APIRouter()


# ─── Test Cases ───────────────────────────────────────────────────────────────

@router.get("/modules/{module_id}/test-cases", response_model=List[TestCaseResponse])
def list_test_cases(
    module_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    module = db.query(Module).filter(Module.id == module_id).first()
    if not module:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Módulo no encontrado")
    return db.query(TestCase).filter(TestCase.module_id == module_id).order_by(TestCase.order, TestCase.created_at).all()


@router.post("/modules/{module_id}/test-cases", response_model=TestCaseResponse, status_code=status.HTTP_201_CREATED)
def create_test_case(
    module_id: UUID,
    body: TestCaseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    module = db.query(Module).filter(Module.id == module_id).first()
    if not module:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Módulo no encontrado")

    test_case = TestCase(
        module_id=module_id,
        title=body.title,
        preconditions=body.preconditions,
        postconditions=body.postconditions,
        status=TestCaseStatus.active,
        created_by=current_user.id,
    )
    db.add(test_case)
    db.flush()

    for step_data in body.steps:
        step = TestStep(
            test_case_id=test_case.id,
            order=step_data.order,
            action=step_data.action,
            test_data=step_data.test_data,
            expected_result=step_data.expected_result,
        )
        db.add(step)

    db.commit()
    db.refresh(test_case)
    return test_case


@router.get("/test-cases/{test_case_id}", response_model=TestCaseResponse)
def get_test_case(
    test_case_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tc = db.query(TestCase).filter(TestCase.id == test_case_id).first()
    if not tc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Test case no encontrado")
    return tc


@router.put("/test-cases/{test_case_id}", response_model=TestCaseResponse)
def update_test_case(
    test_case_id: UUID,
    body: TestCaseUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tc = db.query(TestCase).filter(TestCase.id == test_case_id).first()
    if not tc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Test case no encontrado")

    if body.title is not None:
        tc.title = body.title
    if body.preconditions is not None:
        tc.preconditions = body.preconditions
    if body.postconditions is not None:
        tc.postconditions = body.postconditions
    if body.status is not None:
        tc.status = body.status

    db.commit()
    db.refresh(tc)
    return tc


@router.delete("/test-cases/{test_case_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_test_case(
    test_case_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tc = db.query(TestCase).filter(TestCase.id == test_case_id).first()
    if not tc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Test case no encontrado")
    db.delete(tc)
    db.commit()


@router.post("/test-cases/{test_case_id}/duplicate", response_model=TestCaseResponse, status_code=status.HTTP_201_CREATED)
def duplicate_test_case(
    test_case_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    original = db.query(TestCase).filter(TestCase.id == test_case_id).first()
    if not original:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Test case no encontrado")

    copy = TestCase(
        module_id=original.module_id,
        title=f"{original.title} (copia)",
        preconditions=original.preconditions,
        postconditions=original.postconditions,
        status=TestCaseStatus.active,
        created_by=current_user.id,
    )
    db.add(copy)
    db.flush()

    for step in original.steps:
        db.add(TestStep(
            test_case_id=copy.id,
            order=step.order,
            action=step.action,
            test_data=step.test_data,
            expected_result=step.expected_result,
        ))

    db.commit()
    db.refresh(copy)
    return copy


@router.patch("/test-cases/{test_case_id}/move", response_model=TestCaseResponse)
def move_test_case(
    test_case_id: UUID,
    target_module_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tc = db.query(TestCase).filter(TestCase.id == test_case_id).first()
    if not tc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Test case no encontrado")

    target = db.query(Module).filter(Module.id == target_module_id).first()
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Módulo destino no encontrado")

    tc.module_id = target_module_id
    db.commit()
    db.refresh(tc)
    return tc


# ─── Reordenar test cases ────────────────────────────────────────────────────

@router.put("/modules/{module_id}/test-cases/reorder")
def reorder_test_cases(
    module_id: UUID,
    test_case_ids: List[UUID],
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    module = db.query(Module).filter(Module.id == module_id).first()
    if not module:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Módulo no encontrado")

    try:
        for new_order, tc_id in enumerate(test_case_ids):
            tc = db.query(TestCase).filter(
                TestCase.id == tc_id,
                TestCase.module_id == module_id,
            ).first()
            if tc:
                tc.order = new_order
        db.commit()
    except Exception:
        db.rollback()

    return {"status": "ok"}


# ─── Pasos ────────────────────────────────────────────────────────────────────

@router.put("/test-cases/{test_case_id}/steps", response_model=TestCaseResponse)
def replace_steps(
    test_case_id: UUID,
    steps: List[TestStepCreate],
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Reemplaza todos los pasos de un test case (usado al reordenar o editar en bloque)."""
    tc = db.query(TestCase).filter(TestCase.id == test_case_id).first()
    if not tc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Test case no encontrado")

    db.query(TestStep).filter(TestStep.test_case_id == test_case_id).delete()

    for step_data in steps:
        db.add(TestStep(
            test_case_id=test_case_id,
            order=step_data.order,
            action=step_data.action,
            test_data=step_data.test_data,
            expected_result=step_data.expected_result,
        ))

    db.commit()
    db.refresh(tc)
    return tc


# ─── Generación con IA ────────────────────────────────────────────────────────

@router.post("/modules/{module_id}/test-cases/generate", response_model=AIGenerateResponse)
async def generate_test_cases_with_ai(
    module_id: UUID,
    body: AIGenerateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    module = db.query(Module).filter(Module.id == module_id).first()
    if not module:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Módulo no encontrado")

    system_prompt = """Eres un experto en QA. Tu tarea es generar casos de prueba detallados en español.
Responde ÚNICAMENTE con un JSON válido, sin texto adicional, con esta estructura exacta:
{
  "test_cases": [
    {
      "title": "Nombre del caso de prueba",
      "preconditions": "Condiciones previas necesarias",
      "postconditions": "Estado esperado al finalizar",
      "steps": [
        {
          "order": 1,
          "action": "Acción que realiza el QA",
          "test_data": "Datos de prueba si aplica o null",
          "expected_result": "Resultado esperado de esta acción"
        }
      ]
    }
  ]
}"""

    prompt = f"""Genera casos de prueba para el módulo "{module.name}".
Descripción de la funcionalidad: {body.description}
Genera entre 3 y 5 casos de prueba cubriendo flujo feliz, validaciones y casos de error."""

    max_retries = 2
    last_error = None

    for attempt in range(max_retries + 1):
        try:
            raw = await generate(prompt, system_prompt=system_prompt, max_tokens=3000)

            # Limpiar posible markdown que el modelo agregue
            clean = raw.strip()
            if clean.startswith("```"):
                clean = clean.split("```")[1]
                if clean.startswith("json"):
                    clean = clean[4:]
            if clean.endswith("```"):
                clean = clean[:-3]

            data = json.loads(clean.strip())
            return AIGenerateResponse(**data)

        except json.JSONDecodeError as e:
            last_error = e
            if attempt < max_retries:
                continue
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="La IA devolvió una respuesta inválida después de varios intentos.",
            )
        except Exception as e:
            last_error = e
            if attempt < max_retries:
                continue
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Error al conectar con el servicio de IA: {str(e)}",
            )
