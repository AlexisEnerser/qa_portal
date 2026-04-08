from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from uuid import UUID
import base64
import httpx

from app.database import get_db
from app.models.execution import TestExecution, ExecutionResultStatus
from app.models.reports import ExecutionPdfVersion
from app.models.user import User
from app.services.auth_service import get_current_user
from app.services.wasabi_service import upload_file, get_download_url

router = APIRouter()

STATUS_LABELS = {
    "passed": "Satisfactorio",
    "failed": "Fallido",
    "blocked": "Bloqueado",
    "not_applicable": "No Aplica",
    "pending": "Pendiente",
}

STATUS_COLORS = {
    "passed": "#17B020",
    "failed": "#E53935",
    "blocked": "#FB8C00",
    "not_applicable": "#757575",
    "pending": "#9E9E9E",
}


@router.get("/executions/{execution_id}/pdf-data")
async def get_execution_pdf_data(
    execution_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    execution = db.query(TestExecution).filter(TestExecution.id == execution_id).first()
    if not execution:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sesión no encontrada")

    results = execution.results
    total = len(results)
    passed = sum(1 for r in results if r.status == ExecutionResultStatus.passed)
    failed = sum(1 for r in results if r.status == ExecutionResultStatus.failed)
    blocked = sum(1 for r in results if r.status == ExecutionResultStatus.blocked)
    not_applicable = sum(1 for r in results if r.status == ExecutionResultStatus.not_applicable)

    # Calculate total duration from all results
    total_duration = sum(r.duration_seconds or 0 for r in results)

    test_cases_data = []
    for result in results:
        tc = result.test_case
        module = tc.module

        steps = [
            {
                "order": s.order,
                "action": s.action,
                "test_data": s.test_data or "",
                "expected_result": s.expected_result,
            }
            for s in sorted(tc.steps, key=lambda s: s.order)
        ]

        # Download screenshots from Wasabi and convert to base64
        screenshots_b64 = []
        async with httpx.AsyncClient(timeout=30.0) as client:
            for screenshot in sorted(result.screenshots, key=lambda s: s.order):
                if screenshot.wasabi_file_id:
                    try:
                        url = await get_download_url(screenshot.wasabi_file_id)
                        resp = await client.get(url)
                        if resp.status_code == 200:
                            encoded = base64.b64encode(resp.content).decode("utf-8")
                            ext = screenshot.file_name.rsplit(".", 1)[-1].lower()
                            mime = f"image/{'jpeg' if ext in ('jpg', 'jpeg') else ext}"
                            screenshots_b64.append({
                                "file_name": screenshot.file_name,
                                "base64": encoded,
                                "mime_type": mime,
                            })
                    except Exception:
                        pass  # Skip failed downloads

        assignee_name = result.assignee.name if result.assignee else "Sin asignar"

        test_cases_data.append({
            "module_name": module.name,
            "title": tc.title,
            "preconditions": tc.preconditions or "",
            "postconditions": tc.postconditions or "",
            "steps": steps,
            "status": result.status.value,
            "status_label": STATUS_LABELS.get(result.status.value, result.status.value),
            "status_color": STATUS_COLORS.get(result.status.value, "#000000"),
            "notes": result.notes or "",
            "assignee": assignee_name,
            "screenshots": screenshots_b64,
            "duration_seconds": result.duration_seconds,
        })

    return {
        "execution": {
            "id": str(execution.id),
            "name": execution.name,
            "version": execution.version or "",
            "environment": execution.environment or "",
            "started_at": execution.started_at.isoformat(),
            "finished_at": execution.finished_at.isoformat() if execution.finished_at else None,
        },
        "project": {
            "id": str(execution.project.id),
            "name": execution.project.name,
        },
        "summary": {
            "total": total,
            "passed": passed,
            "failed": failed,
            "blocked": blocked,
            "not_applicable": not_applicable,
            "pending": total - passed - failed - blocked - not_applicable,
            "progress_pct": round((passed + failed + blocked + not_applicable) / total * 100, 1) if total > 0 else 0.0,
        },
        "total_duration_seconds": total_duration,
        "analyst": current_user.name,
        "test_cases": test_cases_data,
    }


# ─── PDF Upload (from Flutter) ───────────────────────────────────────────────

@router.post("/executions/{execution_id}/pdf-upload")
async def upload_execution_pdf(
    execution_id: UUID,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    execution = db.query(TestExecution).filter(TestExecution.id == execution_id).first()
    if not execution:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sesión no encontrada")

    pdf_bytes = await request.body()
    if not pdf_bytes:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No se recibió el archivo PDF")

    # Determine next version number
    last_version = (
        db.query(ExecutionPdfVersion)
        .filter(ExecutionPdfVersion.execution_id == execution_id)
        .order_by(ExecutionPdfVersion.version_number.desc())
        .first()
    )
    next_version = (last_version.version_number + 1) if last_version else 1

    # Upload to Wasabi
    folder = f"qa-portal/pdfs/executions/{execution_id}"
    filename = f"v{next_version}.pdf"
    wasabi_file_id = await upload_file(
        file_bytes=pdf_bytes,
        filename=filename,
        filetype="application/pdf",
        folder=folder,
    )

    pdf_version = ExecutionPdfVersion(
        execution_id=execution_id,
        version_number=next_version,
        wasabi_file_id=wasabi_file_id,
        file_size=len(pdf_bytes),
        generated_by=current_user.id,
    )
    db.add(pdf_version)
    db.commit()
    db.refresh(pdf_version)

    return {
        "id": str(pdf_version.id),
        "version_number": pdf_version.version_number,
        "wasabi_file_id": pdf_version.wasabi_file_id,
        "file_size": pdf_version.file_size,
        "generated_at": pdf_version.generated_at.isoformat(),
    }


# ─── List PDF versions ───────────────────────────────────────────────────────

@router.get("/executions/{execution_id}/pdf-versions")
def list_pdf_versions(
    execution_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    versions = (
        db.query(ExecutionPdfVersion)
        .filter(ExecutionPdfVersion.execution_id == execution_id)
        .order_by(ExecutionPdfVersion.version_number.desc())
        .all()
    )
    return [
        {
            "id": str(v.id),
            "version_number": v.version_number,
            "file_size": v.file_size,
            "generated_by": v.generator.name if v.generator else None,
            "generated_at": v.generated_at.isoformat(),
        }
        for v in versions
    ]


# ─── Download PDF version ────────────────────────────────────────────────────

@router.get("/executions/{execution_id}/pdf-versions/{version_id}/download")
async def download_pdf_version(
    execution_id: UUID,
    version_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    version = (
        db.query(ExecutionPdfVersion)
        .filter(
            ExecutionPdfVersion.id == version_id,
            ExecutionPdfVersion.execution_id == execution_id,
        )
        .first()
    )
    if not version:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Versión no encontrada")

    url = await get_download_url(version.wasabi_file_id)
    return {"url": url, "version_number": version.version_number}
