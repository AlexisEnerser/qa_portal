from fastapi import APIRouter, Depends, HTTPException
import logging

from app.models.user import User
from app.schemas.ai_chat import ChatRequest, ChatResponse, ContextType
from app.services.auth_service import get_current_user
from app.services.ai_client import generate

router = APIRouter()
logger = logging.getLogger(__name__)

# ── System prompts por contexto ───────────────────────────────────────────────

_BASE = (
    "Eres un asistente de QA experto integrado en un portal de pruebas de software. "
    "Responde siempre en español, de forma clara y concisa. "
    "Si no tienes suficiente información, pide aclaraciones."
)

_CONTEXT_PROMPTS: dict[ContextType, str] = {
    ContextType.test_case: (
        f"{_BASE}\n"
        "El usuario está revisando un caso de prueba. "
        "Ayúdalo a mejorar los pasos, precondiciones, datos de prueba y resultados esperados. "
        "Sugiere escenarios adicionales si es pertinente."
    ),
    ContextType.execution: (
        f"{_BASE}\n"
        "El usuario está ejecutando pruebas en una sesión activa. "
        "Oriéntalo sobre qué verificar en cada paso, cómo interpretar resultados "
        "y cuándo marcar un caso como fallido o bloqueado."
    ),
    ContextType.bug: (
        f"{_BASE}\n"
        "El usuario está trabajando con un reporte de bug. "
        "Ayúdalo a mejorar la descripción, pasos para reproducir, "
        "y a evaluar la severidad correcta."
    ),
    ContextType.sonar_report: (
        f"{_BASE}\n"
        "El usuario está revisando un análisis de SonarQube. "
        "Explica los issues de código en lenguaje claro, sugiere correcciones "
        "y prioriza por impacto."
    ),
    ContextType.posting_sheet: (
        f"{_BASE}\n"
        "El usuario está generando una hoja de posteo a partir de commits de GitHub. "
        "Ayúdalo con dudas sobre el proceso de despliegue y documentación."
    ),
    ContextType.qengine: (
        f"{_BASE}\n"
        "El usuario está trabajando con pruebas automatizadas de Zoho QEngine. "
        "Ayúdalo a interpretar resultados y generar reportes."
    ),
    ContextType.general: _BASE,
}


def _build_system_prompt(req: ChatRequest) -> str:
    prompt = _CONTEXT_PROMPTS.get(req.context_type, _BASE)

    if req.context_data:
        context_lines = []
        for key, value in req.context_data.items():
            if isinstance(value, list):
                value = ", ".join(str(v) for v in value[:10])
            context_lines.append(f"- {key}: {value}")
        if context_lines:
            prompt += "\n\nContexto actual:\n" + "\n".join(context_lines)

    return prompt


def _build_messages(req: ChatRequest) -> str:
    """Convierte historial + mensaje actual en un solo prompt para generate()."""
    parts = []
    for msg in req.history[-10:]:  # últimos 10 mensajes
        role_label = "Usuario" if msg.role == "user" else "Asistente"
        parts.append(f"{role_label}: {msg.content}")
    parts.append(f"Usuario: {req.message}")
    return "\n".join(parts)


@router.post("/chat", response_model=ChatResponse)
async def chat(
    req: ChatRequest,
    current_user: User = Depends(get_current_user),
):
    """Endpoint principal del asistente IA contextual."""
    try:
        system_prompt = _build_system_prompt(req)
        user_prompt = _build_messages(req)

        reply = await generate(
            prompt=user_prompt,
            system_prompt=system_prompt,
            max_tokens=1500,
        )

        return ChatResponse(
            reply=reply.strip(),
            context_type=req.context_type,
        )
    except Exception as e:
        logger.error(f"Error en chat IA: {e}")
        raise HTTPException(status_code=502, detail="No se pudo obtener respuesta de la IA")
