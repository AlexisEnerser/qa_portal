from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from datetime import datetime, timezone
from collections import defaultdict

from app.database import get_db
from app.models.project import Project, Module, TestCase
from app.models.execution import TestExecution, TestExecutionResult, ExecutionResultStatus, ExecutionModule
from app.models.user import User
from app.schemas.execution import (
    ExecutionCreate, ExecutionUpdate, ExecutionResponse, ExecutionSummary,
    ResultUpdate, ResultResponse, ResultWithTestCase,
    DashboardResponse, ModuleProgress, QAProgress,
)
from app.services.auth_service import get_current_user, require_admin

router = APIRouter()


def _sync_execution(execution: TestExecution, db: Session) -> None:
    """Sincroniza resultados de una ejecución abierta con los test cases actuales.

    - Agrega TestExecutionResult(pending) para test cases nuevos en los módulos seleccionados.
    - Elimina resultados cuyo test case ya no existe en la BD.
    No hace nada si la ejecución ya está terminada (finished_at != None).
    """
    if execution.finished_at is not None:
        return

    # Módulos seleccionados para esta ejecución
    selected_module_ids = [em.module_id for em in execution.selected_modules]
    if not selected_module_ids:
        return

    # Test cases activos actuales en esos módulos
    expected_tc_ids = set(
        tc_id for (tc_id,) in db.query(TestCase.id).filter(
            TestCase.module_id.in_(selected_module_ids),
            TestCase.status == "active",
        ).all()
    )

    # Resultados existentes en la ejecución
    existing_results = {r.test_case_id: r for r in execution.results}
    existing_tc_ids = set(existing_results.keys())

    changed = False

    # Agregar nuevos
    to_add = expected_tc_ids - existing_tc_ids
    for tc_id in to_add:
        db.add(TestExecutionResult(
            execution_id=execution.id,
            test_case_id=tc_id,
            status=ExecutionResultStatus.pending,
        ))
        changed = True

    # Eliminar huérfanos (test case ya no existe)
    to_remove = existing_tc_ids - expected_tc_ids
    for tc_id in to_remove:
        db.delete(existing_results[tc_id])
        changed = True

    if changed:
        db.commit()
        db.refresh(execution)


def _count_results(results):
    counts = defaultdict(int)
    for r in results:
        counts[r.status.value] += 1
    return counts


# ─── Sesiones de ejecución ────────────────────────────────────────────────────

@router.get("/projects/{project_id}/executions", response_model=List[ExecutionSummary])
def list_executions(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Proyecto no encontrado")

    executions = (
        db.query(TestExecution)
        .filter(TestExecution.project_id == project_id)
        .order_by(TestExecution.started_at.desc())
        .all()
    )

    result = []
    for ex in executions:
        counts = _count_results(ex.results)
        total = len(ex.results)
        result.append(ExecutionSummary(
            id=ex.id,
            name=ex.name,
            version=ex.version,
            environment=ex.environment,
            started_at=ex.started_at,
            finished_at=ex.finished_at,
            total=total,
            passed=counts["passed"],
            failed=counts["failed"],
            blocked=counts["blocked"],
            not_applicable=counts["not_applicable"],
            pending=counts["pending"],
        ))
    return result


@router.post("/projects/{project_id}/executions", response_model=ExecutionResponse, status_code=status.HTTP_201_CREATED)
def create_execution(
    project_id: UUID,
    body: ExecutionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Proyecto no encontrado")

    execution = TestExecution(
        project_id=project_id,
        name=body.name,
        version=body.version,
        environment=body.environment,
        created_by=current_user.id,
    )
    db.add(execution)
    db.flush()

    # Determinar módulos a incluir
    if body.module_ids:
        modules = db.query(Module).filter(
            Module.project_id == project_id,
            Module.id.in_(body.module_ids),
        ).all()
    else:
        modules = db.query(Module).filter(Module.project_id == project_id).all()

    # Registrar módulos seleccionados
    for module in modules:
        db.add(ExecutionModule(execution_id=execution.id, module_id=module.id))

    # Auto-poblar resultados solo con test cases de los módulos seleccionados
    for module in modules:
        test_cases = (
            db.query(TestCase)
            .filter(TestCase.module_id == module.id, TestCase.status == "active")
            .all()
        )
        for tc in test_cases:
            db.add(TestExecutionResult(
                execution_id=execution.id,
                test_case_id=tc.id,
                status=ExecutionResultStatus.pending,
            ))

    db.commit()
    db.refresh(execution)
    return execution


@router.get("/executions/{execution_id}", response_model=ExecutionResponse)
def get_execution(
    execution_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    execution = db.query(TestExecution).filter(TestExecution.id == execution_id).first()
    if not execution:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sesión no encontrada")
    return execution


@router.put("/executions/{execution_id}", response_model=ExecutionResponse)
def update_execution(
    execution_id: UUID,
    body: ExecutionUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    execution = db.query(TestExecution).filter(TestExecution.id == execution_id).first()
    if not execution:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sesión no encontrada")

    if body.name is not None:
        execution.name = body.name
    if body.version is not None:
        execution.version = body.version
    if body.environment is not None:
        execution.environment = body.environment

    db.commit()
    db.refresh(execution)
    return execution


@router.post("/executions/{execution_id}/finish", response_model=ExecutionResponse)
def finish_execution(
    execution_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    execution = db.query(TestExecution).filter(TestExecution.id == execution_id).first()
    if not execution:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sesión no encontrada")

    execution.finished_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(execution)
    return execution


@router.delete("/executions/{execution_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_execution(
    execution_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    execution = db.query(TestExecution).filter(TestExecution.id == execution_id).first()
    if not execution:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sesión no encontrada")
    db.delete(execution)
    db.commit()


# ─── Resultados por test case ─────────────────────────────────────────────────

@router.get("/executions/{execution_id}/results", response_model=List[ResultWithTestCase])
def list_results(
    execution_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    execution = db.query(TestExecution).filter(TestExecution.id == execution_id).first()
    if not execution:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sesión no encontrada")
    _sync_execution(execution, db)
    return execution.results


@router.put("/executions/{execution_id}/results/{result_id}", response_model=ResultResponse)
def update_result(
    execution_id: UUID,
    result_id: UUID,
    body: ResultUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = db.query(TestExecutionResult).filter(
        TestExecutionResult.id == result_id,
        TestExecutionResult.execution_id == execution_id,
    ).first()
    if not result:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Resultado no encontrado")

    if body.status is not None:
        result.status = body.status
        # Registrar quién y cuándo ejecutó si cambia de pending
        if body.status != ExecutionResultStatus.pending:
            result.executed_at = datetime.now(timezone.utc)
            result.executed_by = current_user.id

    if body.assigned_to is not None:
        assignee = db.query(User).filter(User.id == body.assigned_to, User.is_active == True).first()
        if not assignee:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")
        result.assigned_to = body.assigned_to

    if body.notes is not None:
        result.notes = body.notes

    if body.duration_seconds is not None:
        result.duration_seconds = body.duration_seconds

    db.commit()
    db.refresh(result)
    return result


# ─── Dashboard ────────────────────────────────────────────────────────────────

@router.get("/executions/{execution_id}/dashboard", response_model=DashboardResponse)
def get_dashboard(
    execution_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    execution = db.query(TestExecution).filter(TestExecution.id == execution_id).first()
    if not execution:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sesión no encontrada")

    _sync_execution(execution, db)

    results = execution.results
    total = len(results)
    counts = _count_results(results)

    completed = counts["passed"] + counts["failed"] + counts["blocked"] + counts["not_applicable"]
    progress_pct = round((completed / total * 100), 1) if total > 0 else 0.0

    # Progreso por módulo
    module_map = defaultdict(lambda: defaultdict(int))
    module_names = {}
    for r in results:
        mod = r.test_case.module
        module_map[mod.id][r.status.value] += 1
        module_names[mod.id] = mod.name

    by_module = [
        ModuleProgress(
            module_id=mid,
            module_name=module_names[mid],
            total=sum(module_map[mid].values()),
            passed=module_map[mid]["passed"],
            failed=module_map[mid]["failed"],
            blocked=module_map[mid]["blocked"],
            not_applicable=module_map[mid]["not_applicable"],
            pending=module_map[mid]["pending"],
        )
        for mid in module_map
    ]

    # Progreso por QA
    qa_map = defaultdict(lambda: defaultdict(int))
    qa_users = {}
    for r in results:
        if r.assigned_to:
            qa_map[r.assigned_to][r.status.value] += 1
            if r.assigned_to not in qa_users and r.assignee:
                qa_users[r.assigned_to] = r.assignee

    by_qa = [
        QAProgress(
            user=qa_users[uid],
            total=sum(qa_map[uid].values()),
            passed=qa_map[uid]["passed"],
            failed=qa_map[uid]["failed"],
            blocked=qa_map[uid]["blocked"],
            not_applicable=qa_map[uid]["not_applicable"],
            pending=qa_map[uid]["pending"],
        )
        for uid in qa_map
    ]

    return DashboardResponse(
        execution_id=execution.id,
        execution_name=execution.name,
        total=total,
        passed=counts["passed"],
        failed=counts["failed"],
        blocked=counts["blocked"],
        not_applicable=counts["not_applicable"],
        pending=counts["pending"],
        progress_pct=progress_pct,
        by_module=by_module,
        by_qa=by_qa,
    )
