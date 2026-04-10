from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.config import get_settings
from app.routers import auth, users, projects, test_cases, executions, screenshots, pdf_data, bugs, sonar, github, ai_chat, automated

settings = get_settings()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Verificar conectividad con IA al arrancar
    from app.services.ai_client import check_ai_connection
    await check_ai_connection()
    yield

app = FastAPI(
    title="QA Portal API",
    version="1.0.0",
    description="Backend unificado para actividades de QA",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth", tags=["Autenticación"])
app.include_router(users.router, prefix="/users", tags=["Usuarios"])
app.include_router(projects.router, prefix="/projects", tags=["Proyectos y Módulos"])
app.include_router(test_cases.router, prefix="/qa", tags=["Test Cases"])
app.include_router(executions.router, prefix="/qa", tags=["Ejecuciones"])
app.include_router(screenshots.router, prefix="/qa", tags=["Capturas de pantalla"])
app.include_router(pdf_data.router, prefix="/qa", tags=["PDF"])
app.include_router(bugs.router, prefix="/qa", tags=["Bugs"])
app.include_router(sonar.router, prefix="/sonar", tags=["SonarQube"])
app.include_router(github.router, prefix="/github", tags=["Github"])
app.include_router(ai_chat.router, prefix="/ai", tags=["Asistente IA"])
app.include_router(automated.router, prefix="/automated", tags=["Pruebas Automatizadas"])



@app.get("/health", tags=["Sistema"])
def health_check():
    return {"status": "ok", "environment": settings.environment}
