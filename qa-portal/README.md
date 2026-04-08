# QA Portal — Arranque

## Requisitos
- Docker Desktop instalado y corriendo

## Primera vez

```bash
# 1. Levantar servicios
docker-compose up -d --build

# 2. Ejecutar migración de base de datos
docker exec -it qa_portal_backend alembic upgrade head

# 3. Crear usuarios iniciales
docker exec -it qa_portal_backend python seed.py
```

## Uso diario

```bash
# Levantar
docker-compose up -d

# Detener
docker-compose down
```

## URLs

| Servicio | URL |
|---|---|
| API Backend | http://localhost:8000 |
| Documentación API | http://localhost:8000/docs |
| Adminer (BD) | http://localhost:8080 |

## Usuarios iniciales

| Email | Contraseña | Rol |
|---|---|---|
| admin@enerser.com.mx | Admin1234 | Administrador |
| qa1@enerser.com.mx | Qa1234 | QA |
| qa2@enerser.com.mx | Qa1234 | QA |

**Cambiar contraseñas después del primer login.**
