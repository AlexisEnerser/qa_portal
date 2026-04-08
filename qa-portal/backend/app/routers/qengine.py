from fastapi import APIRouter, Depends, HTTPException, Body, Query
from typing import List, Dict
from app.services.qengine_service import qengine_service
from app.routers.auth import get_current_user
from app.models.user import User

router = APIRouter()

@router.get("/projects")
async def get_qengine_projects(current_user: User = Depends(get_current_user)):
    """
    Lista proyectos de QEngine consultando la API real de Zoho.
    """
    token = await qengine_service.get_access_token()
    if not token:
        raise HTTPException(status_code=503, detail="No se pudo obtener token de Zoho QEngine")

    import httpx
    url = f"{qengine_service.base_url}/projects"
    headers = {"Authorization": f"Bearer {token}"}
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            data = response.json()
            # La API de Zoho devuelve los proyectos bajo distintas claves según versión
            projects = data.get("projects", data.get("data", []))
            return [{"id": str(p.get("id", "")), "name": p.get("name", "")} for p in projects]
        except Exception as e:
            import logging
            logging.getLogger(__name__).error(f"Error listando proyectos QEngine: {e}")
            raise HTTPException(status_code=502, detail=f"Error consultando QEngine: {e}")

@router.get("/suites/{project_id}")
async def get_test_suites(project_id: str, current_user: User = Depends(get_current_user)):
    """
    Lista las suites de prueba de un proyecto.
    """
    data = await qengine_service.get_test_suites(project_id)
    if not data:
        raise HTTPException(status_code=404, detail="No se encontraron suites para este proyecto")
    return data

@router.post("/report-data")
async def get_report_data(
    project_id: str = Body(...),
    test_run_id: str = Body(...),
    extract_images: bool = Body(True),
    # Campos normativos que vienen del formulario Flutter (no de la API de Zoho)
    environment: str = Body("QA"),
    ip_address: str = Body(""),
    analyst_type: str = Body(""),
    area: str = Body(""),
    module: str = Body(""),
    enhancements: str = Body(""),
    requestor: str = Body(""),
    requestor_position: str = Body(""),
    developer: str = Body(""),
    techlead: str = Body(""),
    techlead_position: str = Body(""),
    coordinator: str = Body(""),
    hu_entregable: str = Body(""),
    zohoprojects: str = Body(""),
    current_user: User = Depends(get_current_user)
):
    """
    Obtiene los resultados de ejecución y opcionalmente extrae capturas de pantalla vía Selenium.
    Incluye campos normativos del formulario para el PDF (ambiente, analista, área, etc.).
    """
    results = await qengine_service.get_test_results(project_id, test_run_id)

    if extract_images:
        image_items = []
        testcaseresults = results.get("testcaseresults", [])
        for res in testcaseresults:
            result_id = res.get("id")
            if result_id:
                items = await qengine_service.get_test_result_detail(project_id, str(result_id))
                image_items.extend(items)

        if image_items:
            images_base64 = await qengine_service.process_images(image_items)
            return {
                "results": results,
                "images": images_base64,
                "meta": {
                    "environment": environment, "ip_address": ip_address,
                    "analyst_type": analyst_type, "area": area,
                    "module": module, "enhancements": enhancements,
                    "requestor": requestor, "requestor_position": requestor_position,
                    "developer": developer, "techlead": techlead,
                    "techlead_position": techlead_position, "coordinator": coordinator,
                    "hu_entregable": hu_entregable, "zohoprojects": zohoprojects,
                }
            }

    return {
        "results": results,
        "images": [],
        "meta": {
            "environment": environment, "ip_address": ip_address,
            "analyst_type": analyst_type, "area": area,
            "module": module, "enhancements": enhancements,
            "requestor": requestor, "requestor_position": requestor_position,
            "developer": developer, "techlead": techlead,
            "techlead_position": techlead_position, "coordinator": coordinator,
            "hu_entregable": hu_entregable, "zohoprojects": zohoprojects,
        }
    }
