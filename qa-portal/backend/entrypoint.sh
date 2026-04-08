#!/bin/sh

# Salir inmediatamente si un comando falla
set -e

echo "Esperando a que la base de datos estÃ© lista..."
until curl -s http://db:5432 || [ $? -eq 52 ]; do
  echo "Postgres estÃ¡ indisponible - durmiendo"
  sleep 1
done

echo "Base de datos arriba - ejecutando migraciones"
alembic upgrade head

echo "Ejecutando script de seed (usuarios iniciales)"
python seed.py

echo "Iniciando servidor FastAPI"
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
