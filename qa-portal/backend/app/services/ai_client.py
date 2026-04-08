from openai import AsyncOpenAI
from app.config import get_settings
import logging

logger = logging.getLogger(__name__)
settings = get_settings()

_client = AsyncOpenAI(
    base_url=settings.ai_base_url,
    api_key=settings.ai_api_key,
)


async def generate(prompt: str, system_prompt: str = "", max_tokens: int = 2048) -> str:
    """
    Cliente IA central. Todos los módulos del backend usan esta función.
    """
    messages = []
    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})
    messages.append({"role": "user", "content": prompt})

    response = await _client.chat.completions.create(
        model=settings.ai_model,
        messages=messages,
        max_tokens=max_tokens,
    )
    return response.choices[0].message.content


async def check_ai_connection() -> None:
    """
    Verifica conectividad con el API de IA al arrancar el servidor.
    """
    try:
        response = await generate("ping", system_prompt="Responde solo con la palabra 'pong'", max_tokens=10)
        logger.info(f"Conexión IA OK — respuesta: {response.strip()}")
    except Exception as e:
        logger.warning(f"No se pudo conectar con el API de IA: {e}")
