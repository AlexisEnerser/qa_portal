"""Servicio de ejecución de scripts Playwright en subprocess aislado."""

import asyncio
import json
import logging
import os
import tempfile
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy.orm import Session

from app.models.automated import (
    AutomatedRun, AutomatedRunResult, AutomatedRunStatus, AutomatedResultStatus,
    AutomatedTestCase,
)
from app.services.wasabi_service import upload_file

logger = logging.getLogger(__name__)

# Timeout por test individual (30s) y por suite completa (5min)
TEST_TIMEOUT_SECONDS = 30
SUITE_TIMEOUT_SECONDS = 300

# Semáforo para limitar concurrencia (máx 2 ejecuciones simultáneas)
_run_semaphore = asyncio.Semaphore(2)


def _build_runner_script(script_code: str, output_dir: str) -> str:
    """Construye el script completo que se ejecutará en subprocess."""
    return f'''
import asyncio
import json
import time
import os
import sys

async def run():
    from playwright.async_api import async_playwright

    output_dir = {repr(output_dir)}
    result = {{"status": "passed", "error": None, "screenshots": [], "log": ""}}
    start = time.time()

    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=True,
                executable_path="/usr/bin/chromium",
                args=["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu"]
            )
            context = await browser.new_context(
                viewport={{"width": 1280, "height": 720}},
                ignore_https_errors=True,
            )
            page = await context.new_page()

            # Redirigir screenshots al directorio de salida
            _original_screenshot = page.screenshot
            _step_counter = [0]

            async def _patched_screenshot(**kwargs):
                path = kwargs.get("path", f"step_{{_step_counter[0]:02d}}.png")
                _step_counter[0] += 1
                full_path = os.path.join(output_dir, os.path.basename(path))
                kwargs["path"] = full_path
                await _original_screenshot(**kwargs)
                result["screenshots"].append(full_path)

            page.screenshot = _patched_screenshot

            # Ejecutar el test del usuario
{_indent_code(script_code, 12)}

            await test_main(page)
            await browser.close()

    except AssertionError as e:
        result["status"] = "failed"
        result["error"] = str(e)
    except Exception as e:
        result["status"] = "error"
        result["error"] = f"{{type(e).__name__}}: {{e}}"

    result["duration_ms"] = int((time.time() - start) * 1000)

    with open(os.path.join(output_dir, "result.json"), "w") as f:
        json.dump(result, f)

asyncio.run(run())
'''


def _indent_code(code: str, spaces: int) -> str:
    """Indenta código para insertarlo dentro del runner."""
    indent = " " * spaces
    return "\n".join(indent + line for line in code.splitlines())


async def _run_single_test(
    test_case: AutomatedTestCase,
    run_id: uuid.UUID,
    db: Session,
) -> AutomatedRunResult:
    """Ejecuta un solo test case y devuelve el resultado."""
    result = AutomatedRunResult(
        run_id=run_id,
        automated_test_case_id=test_case.id,
        status=AutomatedResultStatus.skipped,
        executed_at=datetime.now(timezone.utc),
    )

    if not test_case.script_code or not test_case.is_active:
        result.error_message = "Test sin script o desactivado"
        db.add(result)
        db.commit()
        return result

    with tempfile.TemporaryDirectory(prefix="pw_test_") as tmpdir:
        runner_code = _build_runner_script(test_case.script_code, tmpdir)
        script_path = os.path.join(tmpdir, "run_test.py")

        with open(script_path, "w") as f:
            f.write(runner_code)

        try:
            proc = await asyncio.create_subprocess_exec(
                "python", script_path,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=tmpdir,
            )
            stdout, stderr = await asyncio.wait_for(
                proc.communicate(), timeout=TEST_TIMEOUT_SECONDS
            )

            result.console_log = (stdout.decode(errors="replace") + "\n" + stderr.decode(errors="replace")).strip()

            result_file = os.path.join(tmpdir, "result.json")
            if os.path.exists(result_file):
                with open(result_file) as f:
                    data = json.load(f)

                status_map = {
                    "passed": AutomatedResultStatus.passed,
                    "failed": AutomatedResultStatus.failed,
                    "error": AutomatedResultStatus.error,
                }
                result.status = status_map.get(data.get("status", "error"), AutomatedResultStatus.error)
                result.duration_ms = data.get("duration_ms")
                result.error_message = data.get("error")

                # Subir screenshots a Wasabi
                screenshot_ids = []
                for ss_path in data.get("screenshots", []):
                    if os.path.exists(ss_path):
                        try:
                            with open(ss_path, "rb") as img:
                                file_bytes = img.read()
                            file_id = await upload_file(
                                file_bytes=file_bytes,
                                filename=os.path.basename(ss_path),
                                filetype="image/png",
                                folder=f"qa-portal/automated/{run_id}/{test_case.id}",
                            )
                            screenshot_ids.append(file_id)
                        except Exception as e:
                            logger.warning(f"Error subiendo screenshot: {e}")
                result.screenshots = screenshot_ids
            else:
                result.status = AutomatedResultStatus.error
                result.error_message = f"No se generó result.json. stderr: {stderr.decode(errors='replace')[:500]}"

        except asyncio.TimeoutError:
            result.status = AutomatedResultStatus.error
            result.error_message = f"Timeout: el test excedió {TEST_TIMEOUT_SECONDS}s"
            result.duration_ms = TEST_TIMEOUT_SECONDS * 1000
        except Exception as e:
            result.status = AutomatedResultStatus.error
            result.error_message = f"{type(e).__name__}: {e}"

    db.add(result)
    db.commit()
    db.refresh(result)
    return result


async def execute_run(run_id: uuid.UUID, db_factory) -> None:
    """Ejecuta todos los tests de un run. Se llama como background task."""
    async with _run_semaphore:
        db: Session = db_factory()
        try:
            run = db.query(AutomatedRun).filter(AutomatedRun.id == run_id).first()
            if not run:
                return

            run.status = AutomatedRunStatus.running
            db.commit()

            test_cases = (
                db.query(AutomatedTestCase)
                .filter(
                    AutomatedTestCase.suite_id == run.suite_id,
                    AutomatedTestCase.is_active == True,
                )
                .order_by(AutomatedTestCase.order)
                .all()
            )

            for tc in test_cases:
                if run.status == AutomatedRunStatus.cancelled:
                    break
                await _run_single_test(tc, run.id, db)

            # Refrescar el run por si fue cancelado
            db.refresh(run)
            if run.status != AutomatedRunStatus.cancelled:
                has_errors = any(
                    r.status in (AutomatedResultStatus.error, AutomatedResultStatus.failed)
                    for r in run.results
                )
                run.status = AutomatedRunStatus.completed if not has_errors else AutomatedRunStatus.failed
            run.finished_at = datetime.now(timezone.utc)
            db.commit()

        except Exception as e:
            logger.error(f"Error ejecutando run {run_id}: {e}")
            try:
                run = db.query(AutomatedRun).filter(AutomatedRun.id == run_id).first()
                if run:
                    run.status = AutomatedRunStatus.failed
                    run.finished_at = datetime.now(timezone.utc)
                    db.commit()
            except Exception:
                pass
        finally:
            db.close()
