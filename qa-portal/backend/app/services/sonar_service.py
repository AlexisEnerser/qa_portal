import httpx
import asyncio
import shutil
import tempfile
import json
import logging

from app.config import get_settings
from app.services.ai_client import generate

logger = logging.getLogger(__name__)
settings = get_settings()


class SonarService:
    def __init__(self):
        self.base_url = settings.sonarqube_url
        self.token = settings.sonarqube_token
        # SonarQube uses token as username with empty password for basic auth
        self._auth = (self.token, "") if self.token else None

    def _client(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(auth=self._auth, timeout=30.0)

    async def get_projects(self):
        """Lista proyectos de SonarQube."""
        url = f"{self.base_url}/api/components/search"
        params = {"qualifiers": "TRK", "ps": 500}
        async with self._client() as client:
            try:
                response = await client.get(url, params=params)
                response.raise_for_status()
                data = response.json()
                components = data.get("components", [])
                return [{"key": c["key"], "name": c.get("name", c["key"])} for c in components]
            except Exception as e:
                logger.error(f"Error consultando proyectos de SonarQube: {e}")
                return []

    async def run_scan(self, repo_url: str, project_key: str, branch: str = "main"):
        """Clona un repositorio, ejecuta sonar-scanner vía Docker y espera el resultado."""
        tmp_dir = tempfile.mkdtemp(prefix="sonar_scan_")
        try:
            clone_cmd = ["git", "clone", "--depth", "1", "--branch", branch, repo_url, tmp_dir]
            proc = await asyncio.create_subprocess_exec(
                *clone_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            _, stderr = await asyncio.wait_for(proc.communicate(), timeout=120)
            if proc.returncode != 0:
                raise RuntimeError(f"Error clonando repo: {stderr.decode()}")

            scanner_cmd = [
                "docker", "run", "--rm",
                "--network=sonarqube-prod_default",
                "-v", f"{tmp_dir}:/usr/src",
                "-e", f"SONAR_HOST_URL={self.base_url}",
                "sonarsource/sonar-scanner-cli",
                f"-Dsonar.projectKey={project_key}",
                f"-Dsonar.sources=/usr/src",
                f"-Dsonar.projectBaseDir=/usr/src",
            ]
            if self.token:
                scanner_cmd.append(f"-Dsonar.token={self.token}")

            proc = await asyncio.create_subprocess_exec(
                *scanner_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=300)
            if proc.returncode != 0:
                logger.warning(f"Scanner stderr: {stderr.decode()}")

            await self._wait_for_analysis(project_key)
            return True
        except Exception as e:
            logger.error(f"Error en scan de SonarQube: {e}")
            raise
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)

    async def _wait_for_analysis(self, project_key: str, max_retries: int = 15):
        """Espera a que el análisis de SonarQube termine."""
        url = f"{self.base_url}/api/ce/component"
        params = {"component": project_key}
        async with self._client() as client:
            for _ in range(max_retries):
                try:
                    resp = await client.get(url, params=params)
                    if resp.status_code == 200:
                        current = resp.json().get("current", {})
                        status = current.get("status", "")
                        if status in ("SUCCESS", "FAILED", "CANCELED"):
                            return
                except Exception:
                    pass
                await asyncio.sleep(5)

    async def get_issues(self, project_key: str, severity: str = "CRITICAL"):
        """Obtiene issues de un proyecto específico."""
        url = f"{self.base_url}/api/issues/search"
        params = {
            "componentKeys": project_key,
            "resolved": "false",
            "severities": severity,
        }
        async with self._client() as client:
            try:
                response = await client.get(url, params=params)
                response.raise_for_status()
                return response.json()
            except Exception as e:
                logger.error(f"Error consultando issues de SonarQube: {e}")
                return {"total": 0, "issues": []}

    async def get_vulnerabilities(self, project_key: str):
        """Obtiene vulnerabilidades de un proyecto específico."""
        url = f"{self.base_url}/api/issues/search"
        params = {
            "componentKeys": project_key,
            "types": "VULNERABILITY",
            "resolved": "false",
        }
        async with self._client() as client:
            try:
                response = await client.get(url, params=params)
                response.raise_for_status()
                return response.json()
            except Exception as e:
                logger.error(f"Error consultando vulnerabilidades de SonarQube: {e}")
                return {"total": 0, "issues": []}

    async def analyze_with_ai(self, project_key: str, issues_data: dict):
        """Usa la IA para explicar los issues críticos."""
        issues = issues_data.get("issues", [])
        if not issues:
            return "No se encontraron issues críticos para analizar."

        simplified_issues = []
        for issue in issues[:15]:
            component = issue.get("component", "").split(":")[-1]
            simplified_issues.append({
                "archivo": component,
                "linea": issue.get("line"),
                "mensaje": issue.get("message"),
                "severidad": issue.get("severity"),
            })

        prompt = f"""
Analiza los siguientes issues de SonarQube encontrados en el proyecto '{project_key}'.
Explica de manera clara y técnica en español por qué son importantes y sugiere una corrección breve para cada uno.
Agrupa los problemas similares si es posible.

Issues:
{json.dumps(simplified_issues, indent=2)}
"""
        system_prompt = "Eres un experto en Quality Assurance y Seguridad de Software. Tu objetivo es ayudar a los desarrolladores a entender y corregir errores de código."

        try:
            analysis = await generate(prompt, system_prompt=system_prompt)
            return analysis
        except Exception as e:
            logger.error(f"Error en análisis IA de SonarQube: {e}")
            return "El servicio de IA no pudo completar el análisis en este momento."


sonar_service = SonarService()
