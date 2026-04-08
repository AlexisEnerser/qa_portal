from fastapi import APIRouter, Depends, HTTPException, Query, Body
from typing import List
from sqlalchemy.orm import Session
from app.services.sonar_service import sonar_service
from app.services.auth_service import get_current_user
from app.database import get_db
from app.models.user import User
from app.models.reports import SonarReport

router = APIRouter()

@router.get("/projects")
async def get_sonar_projects(current_user: User = Depends(get_current_user)):
    """
    Lista proyectos de SonarQube para selección en el portal.
    """
    return await sonar_service.get_projects()

@router.post("/scan")
async def trigger_scan(
    repo_url: str = Body(...),
    project_key: str = Body(...),
    branch: str = Body("main"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Clona el repositorio, ejecuta sonar-scanner vía Docker y espera el resultado.
    """
    try:
        await sonar_service.run_scan(repo_url, project_key, branch)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error en el análisis: {e}")
    return {"status": "ok", "project_key": project_key}

@router.get("/analysis/{project_key}")
async def get_sonar_analysis(
    project_key: str,
    severity: str = Query("CRITICAL", regex="^(INFO|MINOR|MAJOR|CRITICAL|BLOCKER)$"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtiene métricas de un proyecto, genera análisis con IA y guarda en BD.
    """
    issues = await sonar_service.get_issues(project_key, severity)
    vulnerabilities = await sonar_service.get_vulnerabilities(project_key)
    ai_analysis = await sonar_service.analyze_with_ai(project_key, issues)

    issues_count = issues.get("total", 0)
    vulnerabilities_count = vulnerabilities.get("total", 0)

    # Guardar en sonar_reports
    report = SonarReport(
        project_name=project_key,
        issues_count=issues_count,
        vulnerabilities_count=vulnerabilities_count,
        raw_json={"issues": issues.get("issues", [])[:50]},
        ai_analysis=ai_analysis,
        created_by=current_user.id,
    )
    db.add(report)
    db.commit()

    return {
        "project": project_key,
        "issues_count": issues_count,
        "vulnerabilities_count": vulnerabilities_count,
        "analysis": ai_analysis,
        "raw_issues": issues.get("issues", [])[:20],
    }
