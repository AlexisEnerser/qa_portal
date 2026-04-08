import httpx
from app.config import get_settings
from sqlalchemy.orm import Session
from app.models.reports import Developer
import logging

logger = logging.getLogger(__name__)
settings = get_settings()

class GithubService:
    def __init__(self):
        self.token = settings.github_token
        self.headers = {
            "Authorization": f"token {self.token}",
            "Accept": "application/vnd.github.v3+json"
        }
        self.base_url = "https://api.github.com"

    async def get_recent_commits(self, org: str, repo: str, branch: str = "main", per_page: int = 100):
        """
        Obtiene los últimos n commits de una rama específica.
        """
        url = f"{self.base_url}/repos/{org}/{repo}/commits"
        params = {"sha": branch, "per_page": per_page}
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(url, headers=self.headers, params=params)
                response.raise_for_status()
                return response.json()
            except Exception as e:
                logger.error(f"Error consultando commits de GitHub: {e}")
                return []

    async def get_commit_details(self, org: str, repo: str, sha: str):
        """
        Obtiene detalles completos de un commit, incluyendo archivos modificados.
        """
        url = f"{self.base_url}/repos/{org}/{repo}/commits/{sha}"
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(url, headers=self.headers)
                response.raise_for_status()
                return response.json()
            except Exception as e:
                logger.error(f"Error consultando detalle de commit: {e}")
                return {}

    async def get_developer_info(self, db: Session, github_username: str):
        """
        Busca información del desarrollador en la base de datos local.
        """
        return db.query(Developer).filter(Developer.github_username == github_username).first()

    def filter_ignored_files(self, files: list):
        """
        Filtra archivos de acuerdo a patrones comunes de ruido (binarios, vendor, etc.)
        """
        ignored_paths = ['bin/', 'obj/', 'node_modules/', 'dist/', '.dll']
        filtered = []
        for file in files:
            filename = file.get("filename", "")
            if not any(ignored in filename for ignored in ignored_paths):
                filtered.append({
                    "filename": filename,
                    "status": file.get("status"),
                    "additions": file.get("additions"),
                    "deletions": file.get("deletions"),
                    "changes": file.get("changes")
                })
        return filtered

    async def generate_posting_sheet_data(self, db: Session, org: str, repo: str, branch: str, target_sha: str):
        """
        Lógica completa de la 'Hoja de Posteo'.
        """
        all_commits = await self.get_recent_commits(org, repo, branch)
        
        # Encontrar índice del commit objetivo
        try:
            target_index = next(i for i, c in enumerate(all_commits) if c["sha"] == target_sha)
        except StopIteration:
            return {"error": f"Commit {target_sha} no encontrado en los últimos 100 de la rama {branch}"}

        # Commit actual
        actual_commit_raw = await self.get_commit_details(org, repo, target_sha)
        author_login = actual_commit_raw.get("author", {}).get("login", "desconocido")
        
        # Buscar en la DB local
        dev_info = await self.get_developer_info(db, author_login)
        dev_name = dev_info.name if dev_info else (actual_commit_raw.get("commit", {}).get("author", {}).get("name") or author_login)
        dev_email = dev_info.email if dev_info else (actual_commit_raw.get("commit", {}).get("author", {}).get("email") or "sin correo")

        # Archivos filtrados
        files = self.filter_ignored_files(actual_commit_raw.get("files", []))

        # Commit anterior (si existe) para referencia o rollback
        rollback_sha = None
        if target_index + 1 < len(all_commits):
            rollback_sha = all_commits[target_index + 1]["sha"]

        return {
            "org": org,
            "repo": repo,
            "branch": branch,
            "sha": target_sha,
            "rollback_sha": rollback_sha,
            "developer_name": dev_name,
            "developer_email": dev_email,
            "message": actual_commit_raw.get("commit", {}).get("message", "(sin mensaje)"),
            "date": actual_commit_raw.get("commit", {}).get("author", {}).get("date"),
            "html_url": actual_commit_raw.get("html_url"),
            "files": files
        }

github_service = GithubService()
