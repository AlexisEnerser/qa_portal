from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # Base de datos
    postgres_user: str
    postgres_password: str
    postgres_db: str
    postgres_host: str = "db"
    postgres_port: int = 5432

    # JWT
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 480
    jwt_refresh_token_expire_days: int = 7

    # IA
    ai_base_url: str
    ai_api_key: str
    ai_model: str = "openai/gpt-oss-20b"

    # SonarQube
    sonarqube_url: str = "http://10.255.230.98:9000"
    sonarqube_token: str = ""

    # GitHub
    github_token: str = ""

    # Wasabi File Storage
    wasabi_api_url: str = "http://10.255.248.68:3002"
    wasabi_api_key: str = ""

    # Servidor
    backend_port: int = 8000
    environment: str = "development"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    class Config:
        env_file = ".env"
        case_sensitive = False


@lru_cache
def get_settings() -> Settings:
    return Settings()
