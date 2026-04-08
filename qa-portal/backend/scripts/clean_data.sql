-- Script de limpieza para empezar desde cero con Wasabi storage
-- Ejecutar dentro del contenedor: docker exec -i qa_portal_db psql -U qa_user -d qa_portal < scripts/clean_data.sql

-- Eliminar datos en orden de dependencias
TRUNCATE TABLE execution_pdf_versions CASCADE;
TRUNCATE TABLE screenshots CASCADE;
TRUNCATE TABLE bugs CASCADE;
TRUNCATE TABLE test_execution_results CASCADE;
TRUNCATE TABLE execution_modules CASCADE;
TRUNCATE TABLE test_executions CASCADE;

-- Limpiar avatares (poner a null los campos de avatar)
UPDATE users SET avatar_path = NULL, avatar_file_id = NULL;

SELECT 'Limpieza completada. Todos los datos de ejecuciones, screenshots y avatares han sido eliminados.' AS resultado;
