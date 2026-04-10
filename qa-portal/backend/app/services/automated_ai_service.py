"""Servicio IA para generación y refinamiento de scripts Playwright."""

import json
import logging
from app.services.ai_client import generate

logger = logging.getLogger(__name__)

SYSTEM_PROMPT_GENERATE = """Eres un experto en automatización de pruebas con Playwright en Python.
Tu tarea es generar scripts de prueba automatizados.

REGLAS ESTRICTAS:
1. Genera ÚNICAMENTE una función async llamada `test_main(page)` que recibe un objeto `page` de Playwright.
2. Cada paso debe incluir `await page.screenshot(path="step_XX_descripcion.png")` después de la acción.
3. Usa selectores robustos: texto visible con `get_by_text()`, roles con `get_by_role()`, o CSS como último recurso.
4. Incluye `assert` para validar resultados esperados.
5. Usa `await page.wait_for_load_state("networkidle")` después de navegaciones.
6. Agrega timeouts explícitos en esperas: `timeout=5000`.
7. Escribe comentarios en español explicando cada paso.
8. NO uses imports — solo el código de la función.
9. NO uses `async with async_playwright()` — la función recibe `page` ya creado.
10. Responde ÚNICAMENTE con el código Python, sin markdown, sin explicaciones, sin bloques ```.

EJEMPLO DE FORMATO:
async def test_main(page):
    # Paso 1: Navegar a la página
    await page.goto("https://ejemplo.com")
    await page.wait_for_load_state("networkidle")
    await page.screenshot(path="step_01_pagina_inicial.png")

    # Paso 2: Verificar título
    title = await page.title()
    assert "Ejemplo" in title, f"Título inesperado: {title}"
    await page.screenshot(path="step_02_titulo_verificado.png")"""

SYSTEM_PROMPT_REFINE = """Eres un experto en automatización de pruebas con Playwright en Python.
El usuario te dará un script existente y una instrucción para modificarlo.

REGLAS:
1. Devuelve el script COMPLETO modificado (no solo el fragmento cambiado).
2. Mantén la estructura: una función `async def test_main(page):`.
3. Mantén los screenshots en cada paso.
4. Mantén los comentarios en español.
5. Responde ÚNICAMENTE con el código Python, sin markdown, sin explicaciones, sin bloques ```.
"""


def _build_steps_context(source_steps: list[dict] | None) -> str:
    """Convierte pasos manuales a texto contextual para el prompt."""
    if not source_steps:
        return ""
    lines = ["Pasos del test case manual como referencia:"]
    for s in source_steps:
        order = s.get("order", "?")
        action = s.get("action", "")
        data = s.get("test_data", "")
        expected = s.get("expected_result", "")
        line = f"  {order}. Acción: {action}"
        if data:
            line += f" | Datos: {data}"
        line += f" | Resultado esperado: {expected}"
        lines.append(line)
    return "\n".join(lines)


def _clean_code(raw: str) -> str:
    """Limpia posible markdown que el modelo agregue."""
    clean = raw.strip()
    if clean.startswith("```"):
        clean = clean.split("```")[1]
        if clean.startswith("python"):
            clean = clean[6:]
    if clean.endswith("```"):
        clean = clean[:-3]
    return clean.strip()


async def generate_script(description: str, target_url: str, source_steps: list[dict] | None = None) -> str:
    """Genera un script Playwright a partir de descripción y/o pasos manuales."""
    steps_ctx = _build_steps_context(source_steps)

    prompt = f"""Genera un script de prueba automatizado con Playwright para:

Descripción: {description}
URL objetivo: {target_url}

{steps_ctx}

Genera la función `test_main(page)` completa."""

    max_retries = 2
    for attempt in range(max_retries + 1):
        try:
            raw = await generate(prompt, system_prompt=SYSTEM_PROMPT_GENERATE, max_tokens=3000)
            code = _clean_code(raw)
            if "async def test_main" not in code:
                if attempt < max_retries:
                    continue
                return f"# Error: La IA no generó una función válida\n# Respuesta:\n# {code[:500]}"
            return code
        except Exception as e:
            logger.error(f"Error generando script (intento {attempt + 1}): {e}")
            if attempt < max_retries:
                continue
            return f"# Error al generar script: {e}"


async def refine_script(current_script: str, instruction: str) -> str:
    """Refina un script existente según instrucciones del QA."""
    prompt = f"""Script actual:
```python
{current_script}
```

Instrucción del QA: {instruction}

Devuelve el script completo modificado."""

    max_retries = 2
    for attempt in range(max_retries + 1):
        try:
            raw = await generate(prompt, system_prompt=SYSTEM_PROMPT_REFINE, max_tokens=3000)
            code = _clean_code(raw)
            if "async def test_main" not in code:
                if attempt < max_retries:
                    continue
                return current_script  # Devolver original si falla
            return code
        except Exception as e:
            logger.error(f"Error refinando script (intento {attempt + 1}): {e}")
            if attempt < max_retries:
                continue
            return current_script


SYSTEM_PROMPT_ANALYZE = """Eres un experto en automatización de pruebas con Playwright en Python.
Un test automatizado falló y necesitas ayudar a un QA que NO sabe programar a entender qué pasó y cómo solucionarlo.

REGLAS:
1. Explica el error en español, de forma sencilla y directa.
2. NO uses jerga técnica innecesaria. Si mencionas un concepto técnico, explícalo brevemente.
3. Da una sugerencia CONCRETA de qué cambiar. Por ejemplo: "Cambia la línea X por Y" o "Dile a la IA: 'selecciona el primer enlace que diga Pricing'".
4. Si el error es de selector (elemento no encontrado, múltiples coincidencias, timeout), sugiere un selector alternativo más específico.
5. Si el error es de timing (timeout esperando carga), sugiere agregar esperas.
6. Formatea tu respuesta así:

**¿Qué pasó?**
[explicación sencilla]

**¿Cómo solucionarlo?**
[instrucción concreta que el QA puede copiar al chat de refinamiento]

7. Responde ÚNICAMENTE con el análisis, sin código, sin bloques ```.
"""


async def analyze_test_error(
    script_code: str,
    error_message: str,
    console_log: str = "",
    test_name: str = "",
) -> str:
    """Analiza un error de test y devuelve explicación + sugerencia para el QA."""
    prompt = f"""El test "{test_name}" falló con este error:

Error: {error_message}

Script que se ejecutó:
```python
{script_code}
```

{f"Log de consola:{chr(10)}{console_log[:1000]}" if console_log else ""}

Analiza el error y sugiere cómo solucionarlo de forma sencilla."""

    try:
        result = await generate(prompt, system_prompt=SYSTEM_PROMPT_ANALYZE, max_tokens=1000)
        return result.strip()
    except Exception as e:
        logger.error(f"Error analizando test: {e}")
        return f"No se pudo analizar el error: {e}"
