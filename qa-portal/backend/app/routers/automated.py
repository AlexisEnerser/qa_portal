"""Router para pruebas automatizadas — CRUD, IA, ejecución, historial, PDF."""

from uuid import UUID
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func

from app.database import get_db, SessionLocal
from app.models.user import User
from app.models.project import Project, TestCase
from app.models.automated import (
    AutomatedSuite, AutomatedTestCase, AutomatedRun, AutomatedRunResult,
    AutomatedRunStatus, AutomatedResultStatus,
)
from app.schemas.automated import (
    SuiteCreate, SuiteUpdate, SuiteResponse, SuiteSummary,
    AutoTestCreate, AutoTestUpdate, AutoTestResponse,
    CloneFromManualRequest, GenerateScriptRequest, GenerateScriptResponse,
    RefineScriptRequest, RefineScriptResponse,
    RunCreate, RunResponse, RunSummary, RunStatusResponse, RunResultResponse,
)
from app.services.automated_ai_service import generate_script, refine_script
from app.services.playwright_runner import execute_run
from app.services.wasabi_service import get_download_url
from app.routers.auth import get_current_user

router = APIRouter()


# ─── CRUD Suites ──────────────────────────────────────────────────────────────

@router.get("/suites", response_model=list[SuiteSummary])
def list_suites(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    suites = (
        db.query(AutomatedSuite)
        .filter(AutomatedSuite.project_id == project_id)
        .order_by(AutomatedSuite.created_at.desc())
        .all()
    )
    result = []
    for s in suites:
        test_count = db.query(func.count(AutomatedTestCase.id)).filter(
            AutomatedTestCase.suite_id == s.id
        ).scalar() or 0

        last_run = (
            db.query(AutomatedRun)
            .filter(AutomatedRun.suite_id == s.id)
            .order_by(AutomatedRun.started_at.desc())
            .first()
        )
        last_run_passed = 0
        last_run_total = 0
        if last_run:
            last_run_total = db.query(func.count(AutomatedRunResult.id)).filter(
                AutomatedRunResult.run_id == last_run.id
            ).scalar() or 0
            last_run_passed = db.query(func.count(AutomatedRunResult.id)).filter(
                AutomatedRunResult.run_id == last_run.id,
                AutomatedRunResult.status == AutomatedResultStatus.passed,
            ).scalar() or 0

        result.append(SuiteSummary(
            id=s.id, project_id=s.project_id, name=s.name,
            description=s.description, created_at=s.created_at,
            test_count=test_count,
            last_run_status=last_run.status.value if last_run else None,
            last_run_at=last_run.started_at if last_run else None,
            last_run_passed=last_run_passed, last_run_total=last_run_total,
        ))
    return result


@router.post("/suites", response_model=SuiteResponse, status_code=201)
def create_suite(
    body: SuiteCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = db.query(Project).filter(Project.id == body.project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="Proyecto no encontrado")
    suite = AutomatedSuite(
        project_id=body.project_id, name=body.name,
        description=body.description, created_by=current_user.id,
    )
    db.add(suite)
    db.commit()
    db.refresh(suite)
    return suite


@router.get("/suites/{suite_id}", response_model=SuiteResponse)
def get_suite(
    suite_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    suite = db.query(AutomatedSuite).filter(AutomatedSuite.id == suite_id).first()
    if not suite:
        raise HTTPException(status_code=404, detail="Suite no encontrada")
    return suite


@router.put("/suites/{suite_id}", response_model=SuiteResponse)
def update_suite(
    suite_id: UUID, body: SuiteUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    suite = db.query(AutomatedSuite).filter(AutomatedSuite.id == suite_id).first()
    if not suite:
        raise HTTPException(status_code=404, detail="Suite no encontrada")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(suite, field, value)
    suite.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(suite)
    return suite


@router.delete("/suites/{suite_id}", status_code=204)
def delete_suite(
    suite_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    suite = db.query(AutomatedSuite).filter(AutomatedSuite.id == suite_id).first()
    if not suite:
        raise HTTPException(status_code=404, detail="Suite no encontrada")
    db.delete(suite)
    db.commit()


# ─── CRUD Test Cases ──────────────────────────────────────────────────────────

@router.get("/suites/{suite_id}/tests", response_model=list[AutoTestResponse])
def list_tests(
    suite_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return (
        db.query(AutomatedTestCase)
        .filter(AutomatedTestCase.suite_id == suite_id)
        .order_by(AutomatedTestCase.order)
        .all()
    )


@router.post("/suites/{suite_id}/tests", response_model=AutoTestResponse, status_code=201)
def create_test(
    suite_id: UUID, body: AutoTestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    suite = db.query(AutomatedSuite).filter(AutomatedSuite.id == suite_id).first()
    if not suite:
        raise HTTPException(status_code=404, detail="Suite no encontrada")
    tc = AutomatedTestCase(
        suite_id=suite_id, name=body.name, description=body.description,
        source_test_case_id=body.source_test_case_id,
        script_code=body.script_code, target_url=body.target_url,
        order=body.order or 0, created_by=current_user.id,
    )
    db.add(tc)
    db.commit()
    db.refresh(tc)
    return tc


@router.get("/tests/{test_id}", response_model=AutoTestResponse)
def get_test(
    test_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tc = db.query(AutomatedTestCase).filter(AutomatedTestCase.id == test_id).first()
    if not tc:
        raise HTTPException(status_code=404, detail="Test no encontrado")
    return tc


@router.put("/tests/{test_id}", response_model=AutoTestResponse)
def update_test(
    test_id: UUID, body: AutoTestUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tc = db.query(AutomatedTestCase).filter(AutomatedTestCase.id == test_id).first()
    if not tc:
        raise HTTPException(status_code=404, detail="Test no encontrado")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(tc, field, value)
    tc.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(tc)
    return tc


@router.delete("/tests/{test_id}", status_code=204)
def delete_test(
    test_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tc = db.query(AutomatedTestCase).filter(AutomatedTestCase.id == test_id).first()
    if not tc:
        raise HTTPException(status_code=404, detail="Test no encontrado")
    db.delete(tc)
    db.commit()


# ─── Clone from manual + IA ──────────────────────────────────────────────────

@router.post("/tests/clone-from-manual", response_model=AutoTestResponse, status_code=201)
async def clone_from_manual(
    body: CloneFromManualRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    suite = db.query(AutomatedSuite).filter(AutomatedSuite.id == body.suite_id).first()
    if not suite:
        raise HTTPException(status_code=404, detail="Suite no encontrada")

    source = (
        db.query(TestCase)
        .options(joinedload(TestCase.steps))
        .filter(TestCase.id == body.source_test_case_id)
        .first()
    )
    if not source:
        raise HTTPException(status_code=404, detail="Test case manual no encontrado")

    steps_data = [
        {"order": s.order, "action": s.action, "test_data": s.test_data, "expected_result": s.expected_result}
        for s in sorted(source.steps, key=lambda x: x.order)
    ]

    script_code = await generate_script(
        description=f"{source.title}. Precondiciones: {source.preconditions or 'Ninguna'}",
        target_url=body.target_url,
        source_steps=steps_data,
    )

    tc = AutomatedTestCase(
        suite_id=body.suite_id, name=source.title,
        description=f"Clonado desde test manual: {source.title}",
        source_test_case_id=source.id,
        script_code=script_code, target_url=body.target_url,
        created_by=current_user.id,
    )
    db.add(tc)
    db.commit()
    db.refresh(tc)
    return tc


@router.post("/generate-script", response_model=GenerateScriptResponse)
async def generate_script_endpoint(
    body: GenerateScriptRequest,
    current_user: User = Depends(get_current_user),
):
    code = await generate_script(body.description, body.target_url, body.source_steps)
    return GenerateScriptResponse(script_code=code)


@router.post("/refine-script", response_model=RefineScriptResponse)
async def refine_script_endpoint(
    body: RefineScriptRequest,
    current_user: User = Depends(get_current_user),
):
    code = await refine_script(body.current_script, body.instruction)
    return RefineScriptResponse(script_code=code)


# ─── Ejecución ────────────────────────────────────────────────────────────────

@router.post("/suites/{suite_id}/run", response_model=RunResponse, status_code=201)
def start_run(
    suite_id: UUID,
    body: RunCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    suite = db.query(AutomatedSuite).filter(AutomatedSuite.id == suite_id).first()
    if not suite:
        raise HTTPException(status_code=404, detail="Suite no encontrada")

    active_count = db.query(func.count(AutomatedRun.id)).filter(
        AutomatedRun.suite_id == suite_id,
        AutomatedRun.status == AutomatedRunStatus.running,
    ).scalar()
    if active_count and active_count > 0:
        raise HTTPException(status_code=409, detail="Ya hay una ejecución en curso para esta suite")

    run = AutomatedRun(
        suite_id=suite_id, environment=body.environment,
        version=body.version, triggered_by=current_user.id,
    )
    db.add(run)
    db.commit()
    db.refresh(run)

    background_tasks.add_task(execute_run, run.id, SessionLocal)
    return run


@router.get("/runs/{run_id}/status", response_model=RunStatusResponse)
def get_run_status(
    run_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    run = db.query(AutomatedRun).filter(AutomatedRun.id == run_id).first()
    if not run:
        raise HTTPException(status_code=404, detail="Run no encontrado")

    results = db.query(AutomatedRunResult).filter(AutomatedRunResult.run_id == run_id).all()
    total_tests = db.query(func.count(AutomatedTestCase.id)).filter(
        AutomatedTestCase.suite_id == run.suite_id,
        AutomatedTestCase.is_active == True,
    ).scalar() or 0

    return RunStatusResponse(
        id=run.id, status=run.status,
        total=total_tests, completed=len(results),
        passed=sum(1 for r in results if r.status == AutomatedResultStatus.passed),
        failed=sum(1 for r in results if r.status == AutomatedResultStatus.failed),
        error=sum(1 for r in results if r.status == AutomatedResultStatus.error),
    )


@router.get("/runs/{run_id}/results", response_model=list[RunResultResponse])
def get_run_results(
    run_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    run = db.query(AutomatedRun).filter(AutomatedRun.id == run_id).first()
    if not run:
        raise HTTPException(status_code=404, detail="Run no encontrado")

    results = (
        db.query(AutomatedRunResult)
        .options(joinedload(AutomatedRunResult.test_case))
        .filter(AutomatedRunResult.run_id == run_id)
        .all()
    )
    return [
        RunResultResponse(
            id=r.id, run_id=r.run_id,
            automated_test_case_id=r.automated_test_case_id,
            test_name=r.test_case.name if r.test_case else "",
            status=r.status, duration_ms=r.duration_ms,
            error_message=r.error_message, console_log=r.console_log,
            screenshots=r.screenshots or [], executed_at=r.executed_at,
        )
        for r in results
    ]


# ─── Historial ────────────────────────────────────────────────────────────────

@router.get("/suites/{suite_id}/runs", response_model=list[RunSummary])
def list_runs(
    suite_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    runs = (
        db.query(AutomatedRun)
        .filter(AutomatedRun.suite_id == suite_id)
        .order_by(AutomatedRun.started_at.desc())
        .all()
    )
    result = []
    for r in runs:
        results = db.query(AutomatedRunResult).filter(AutomatedRunResult.run_id == r.id).all()
        result.append(RunSummary(
            id=r.id, suite_id=r.suite_id, status=r.status,
            environment=r.environment, version=r.version,
            started_at=r.started_at, finished_at=r.finished_at,
            total=len(results),
            passed=sum(1 for x in results if x.status == AutomatedResultStatus.passed),
            failed=sum(1 for x in results if x.status == AutomatedResultStatus.failed),
            error=sum(1 for x in results if x.status == AutomatedResultStatus.error),
            skipped=sum(1 for x in results if x.status == AutomatedResultStatus.skipped),
        ))
    return result


# ─── PDF Data ─────────────────────────────────────────────────────────────────

@router.get("/runs/{run_id}/pdf-data")
async def get_run_pdf_data(
    run_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    run = (
        db.query(AutomatedRun)
        .options(joinedload(AutomatedRun.suite).joinedload(AutomatedSuite.project))
        .filter(AutomatedRun.id == run_id)
        .first()
    )
    if not run:
        raise HTTPException(status_code=404, detail="Run no encontrado")

    results = (
        db.query(AutomatedRunResult)
        .options(joinedload(AutomatedRunResult.test_case))
        .filter(AutomatedRunResult.run_id == run_id)
        .all()
    )

    test_results = []
    for r in results:
        screenshot_urls = []
        for file_id in (r.screenshots or []):
            try:
                url = await get_download_url(file_id)
                screenshot_urls.append(url)
            except Exception:
                screenshot_urls.append(None)

        test_results.append({
            "test_name": r.test_case.name if r.test_case else "Sin nombre",
            "status": r.status.value,
            "duration_ms": r.duration_ms,
            "error_message": r.error_message,
            "screenshot_urls": screenshot_urls,
        })

    total = len(results)
    passed = sum(1 for r in results if r.status == AutomatedResultStatus.passed)

    return {
        "project_name": run.suite.project.name if run.suite and run.suite.project else "",
        "suite_name": run.suite.name if run.suite else "",
        "version": run.version,
        "environment": run.environment,
        "started_at": run.started_at.isoformat() if run.started_at else None,
        "finished_at": run.finished_at.isoformat() if run.finished_at else None,
        "total": total,
        "passed": passed,
        "failed": sum(1 for r in results if r.status == AutomatedResultStatus.failed),
        "error": sum(1 for r in results if r.status == AutomatedResultStatus.error),
        "success_pct": round((passed / total * 100) if total > 0 else 0, 1),
        "results": test_results,
    }


# ─── Servir screenshot (redirect a Wasabi presigned URL) ─────────────────────

@router.get("/screenshots/{file_id}")
async def serve_automated_screenshot(file_id: str):
    try:
        url = await get_download_url(file_id)
        return RedirectResponse(url=url, status_code=302)
    except Exception:
        raise HTTPException(status_code=404, detail="Screenshot no encontrado")


# ─── Análisis IA de errores ──────────────────────────────────────────────────

@router.post("/analyze-error")
async def analyze_error(
    body: dict,
    current_user: User = Depends(get_current_user),
):
    from app.services.automated_ai_service import analyze_test_error

    script_code = body.get("script_code", "")
    error_message = body.get("error_message", "")
    console_log = body.get("console_log", "")
    test_name = body.get("test_name", "")

    analysis = await analyze_test_error(
        script_code=script_code,
        error_message=error_message,
        console_log=console_log,
        test_name=test_name,
    )
    return {"analysis": analysis}
