# Plan de Desarrollo — Portal QA Unificado
> Última actualización: 2026-03-30 (rev 2)
> Estado general: PLANEACIÓN — pendiente de recibir archivos existentes

---

## Contexto del Proyecto

Sistema unificado para actividades de QA que reemplaza y mejora el flujo actual fragmentado entre:
- Zoho QEngine (documentación de pruebas)
- N8N (orquestación de APIs)
- Python/Selenium (descarga de imágenes)
- Flutter (portal + generación de PDF)
- SonarQube Docker (análisis de código)
- GitHub API (hojas de posteo)

**Equipo:** 3 personas de QA
**Infraestructura:** Una PC local como servidor, accesible en red local

---

## Stack Tecnológico

| Capa | Tecnología |
|---|---|
| Backend | Python + FastAPI |
| Base de datos | PostgreSQL (Docker) |
| Frontend / PDF | Flutter Web |
| Capturas de pantalla | Screen Capture API (navegador) |
| Análisis de código | SonarQube (Docker, ya existente) |
| IA | API interna compatible con OpenAI (`https://openai.enerser.com.mx/api/v1`) |
| Almacenamiento de archivos | Wasabi S3-compatible (API interna `http://10.255.248.68:3002`) |
| Contenerización | Docker Compose |

**Modelo IA:** `openai/gpt-oss-20b` — NO soporta imágenes, solo texto.

---

## Estructura de Base de Datos

### `users`
```
id, name, email, password_hash, role (admin/qa), is_active,
avatar_path, avatar_file_id, created_at
```

### `projects`
```
id, name, description, status, created_by, created_at
```

### `modules`
```
id, project_id, name, description, order, created_at
```

### `test_cases`
```
id, module_id, title, preconditions, postconditions,
status (active/inactive), created_by, created_at
```

### `test_steps`
```
id, test_case_id, order, action, test_data, expected_result
```

### `execution_modules`
```
id, execution_id, module_id
```

### `test_executions`
```
id, project_id, name, version, environment,
started_at, finished_at, created_by
```

### `test_execution_results`
```
id, execution_id, test_case_id, assigned_to,
status (pending/passed/failed/blocked/not_applicable),
notes, duration_seconds, executed_at, executed_by
```

### `screenshots`
```
id, execution_result_id, file_path (nullable), file_name,
wasabi_file_id, order, taken_at, taken_by
```

### `bugs`
```
id, execution_result_id, title, description,
severity (critical/high/medium/low), status (open/in_progress/closed),
steps_to_reproduce, external_id (null hasta integración futura),
created_by, created_at
```

### `sonar_reports`
```
id, project_name, repo_url, branch,
analyzed_at, issues_count, raw_json, created_by
```

### `posting_sheets`
```
id, project_id, commit_id, repo, summary_json,
generated_at, created_by
```

### `execution_pdf_versions`
```
id, execution_id, version_number, wasabi_file_id,
file_size, generated_by, generated_at
```

---

## Módulos del Sistema

---

### MÓDULO 1 — Autenticación
- Login con JWT
- Sin registro público — usuarios creados por administrador
- Roles: `admin` (crea usuarios y proyectos) / `qa` (ejecuta pruebas y genera reportes)

---

### MÓDULO 2 — Gestión de Proyectos y Casos de Prueba

**Páginas:**
- Lista de proyectos
- Detalle del proyecto (módulos)
- Detalle del módulo (test cases)
- Formularios CRUD para proyecto / módulo / test case

**Lógica:**
- Jerarquía: Proyecto → Módulo → Test Case → Pasos
- Cada paso tiene: acción, test data, resultado esperado
- Los pasos se pueden reordenar
- Operaciones: crear, editar, eliminar, duplicar, mover entre módulos
- IA: botón "Generar con IA" — el QA describe la funcionalidad y la IA propone test cases con pasos completos

**Futuro (no se desarrolla ahora):**
- Exportar test cases a QEngine via API

---

### MÓDULO 3 — Ejecución de Pruebas

**Concepto:** Sesión de ejecución por proyecto y versión. Múltiples sesiones por proyecto. 3 QAs pueden trabajar simultáneamente.

**Selección de módulos:** Al crear una sesión, el usuario selecciona qué módulos del proyecto se incluirán en la evaluación. Solo los test cases de los módulos seleccionados se cargan como resultados pendientes. Si no se seleccionan módulos, se incluyen todos por defecto. La relación se guarda en la tabla `execution_modules`.

**Páginas:**
- Lista de sesiones por proyecto
- Crear sesión (nombre, versión, ambiente, selección de módulos con checkboxes)
- Vista de ejecución (pantalla principal de trabajo)
- Dashboard de la sesión (con botón regresar a lista de sesiones)

**Gestión de sesiones:**
- Solo el usuario admin puede eliminar sesiones de ejecución (con confirmación)

**Vista de ejecución:**

*Panel izquierdo:*
- Test cases agrupados por módulo
- Indicador visual de estado por colores
- Indicador de QA asignado
- Barra de progreso general

*Panel derecho (al seleccionar un test case):*
- Pre-condiciones, pasos (acción / test data / resultado esperado)
- Asignación de QA responsable
- Botones de estado: `Pasó / Falló / Bloqueado / No Aplica`
- Campo de notas
- Galería de capturas de pantalla
- Botón "Iniciar captura de pantalla"
- Si falló: botón "Registrar bug" (con asistencia de IA)

**Dashboard:**
- Conteo por estado
- Progreso por módulo
- Progreso por QA
- Listado de bugs de la sesión

---

### MÓDULO 4 — Captura de Pantalla

**Dos formas de agregar imágenes a un test case:**

#### Opción A — Captura en vivo (Screen Capture API)
1. QA selecciona test case activo
2. Click en "Iniciar captura"
3. Navegador solicita permiso (Screen Capture API)
4. QA selecciona la ventana/pestaña del portal a probar
5. Barra flotante con: nombre del test case, botón "Tomar captura", botón "Detener"
6. Cada captura queda ligada automáticamente al test case activo

#### Opción B — Subir imágenes existentes
- Botón "Subir imágenes" disponible en el panel del test case
- Soporta selección múltiple de archivos (jpg, png, webp)
- También soporta arrastrar y soltar (drag & drop)
- Las imágenes se suben al servidor y quedan ligadas al test case

**Gestión de la galería (aplica para ambas opciones):**
- Las imágenes se pueden reordenar (drag & drop dentro de la galería)
- Se pueden eliminar individualmente
- Se puede mezclar: capturas en vivo + imágenes subidas en la misma galería
- El orden de la galería es el orden en que aparecen en el PDF

**Almacenamiento:** Archivos almacenados en Wasabi (S3-compatible) via API interna. Backend actúa como proxy — el frontend no conoce la API de Wasabi. Referenciados por `wasabi_file_id` en BD.

**Requisito técnico:** Screen Capture API funciona en Chrome/Edge en localhost o HTTPS.

---

### MÓDULO 5 — Registro de Bugs

**No tiene integración externa — estructura lista para futuro (Jira, Azure DevOps, etc.)**

**Al crear un bug:**
- Se auto-poblan: pasos del test case, capturas asociadas
- IA redacta título, descripción y pasos en formato estructurado
- QA revisa y edita antes de guardar
- Las capturas de pantalla del test case se vinculan automáticamente al bug (disponibles para integración futura con Jira/Azure DevOps)

**Campos:** título, descripción, severidad, pasos para reproducir, evidencia, estado
**Campo `external_id`:** vacío hasta integración futura

**Vistas:**
- Lista de bugs por proyecto/sesión
- Filtros por severidad, estado, módulo, QA
- Detalle con capturas

---

### MÓDULO 6 — Generación de PDF de Evidencias

**Tipos de PDF:**

| Tipo | Fuente | Descripción |
|---|---|---|
| Reporte pruebas manuales | Sesión propia | Test cases + estados + capturas + formulario normativo |
| Reporte pruebas automatizadas | QEngine API | Migrado de N8N |
| Reporte SonarQube | SonarQube API + IA | Issues + análisis IA |
| Hoja de posteo | GitHub API | Resumen de commits |

**PDF de pruebas manuales — formato normativo completo:**
Al presionar "Exportar PDF" en el dashboard de una sesión, se muestra un formulario donde el usuario llena los datos que no se pueden auto-llenar:
- Logo (ENERSER / XIGA)
- Dirección IP
- Área
- HU Entregable
- Mejoras implementadas
- Firmas: Solicitante + Cargo, Desarrollador, Tech Lead + Cargo, Coordinador

Se auto-llenan del sistema: proyecto, sesión, versión, ambiente, fecha, analista QA, módulos evaluados, test cases con pasos/estados/capturas, conclusión con porcentaje.

Secciones del PDF: Información general, Control de versiones, Áreas participantes, Casos de prueba (con capturas), Conclusión, Mejoras aplicadas, Firmas.

**Todos los PDF se generan en Flutter** usando los diseños normativos existentes.
El backend entrega JSON estructurado, Flutter construye el PDF.

---

### MÓDULO 7 — Integración SonarQube

**Flujo automatizado (reemplaza proceso manual):**
1. QA ingresa: nombre del proyecto, URL del repo, rama
2. Backend clona el repo automáticamente
3. Lanza el scanner de SonarQube via Docker
4. Espera resultado y consulta la API de SonarQube
5. Extrae todos los issues
6. IA agrupa, traduce y explica cada issue con sugerencia de corrección
7. Devuelve JSON al portal Flutter
8. Flutter genera PDF con sección de análisis IA etiquetada

**Historial de análisis guardado en BD.**

---

### MÓDULO 8 — Integración GitHub (Hoja de Posteo)

**Flujo (migrado desde N8N):**
1. QA ingresa: repositorio y commit ID
2. Backend consulta GitHub API
3. Extrae resumen de cambios
4. Devuelve JSON al portal Flutter
5. Flutter genera PDF de hoja de posteo

---

### MÓDULO 9 — Integración QEngine (Pruebas Automatizadas)

**Flujo (migrado desde N8N + Selenium):**
1. QA selecciona proyecto de QEngine
2. Backend consulta API de QEngine y extrae datos
3. Selenium descarga imágenes y las convierte a base64
4. Devuelve JSON completo al portal Flutter
5. Flutter genera PDF de evidencia de pruebas automatizadas

---

### MÓDULO 10 — Asistente IA (Chat Contextual)

**Widget flotante disponible en todo el portal.**

Contexto dinámico según la pantalla activa:
- En un test case → conoce los pasos, sugiere mejoras
- En reporte SonarQube → responde preguntas sobre issues
- En ejecución → orienta sobre qué verificar en cada paso
- En cualquier pantalla → responde preguntas generales de QA

---

## Integraciones de IA — Resumen

| # | Dónde | Qué hace |
|---|---|---|
| 1 | Análisis de código | Complementa SonarQube con análisis lógico y de negocio |
| 2 | Crear test cases | Genera propuesta de casos y pasos desde descripción libre |
| 3 | Registro de bugs | Redacta el bug en formato estructurado |
| 4 | Reporte SonarQube | Explica issues en lenguaje claro con sugerencias de corrección |
| 5 | Asistente general | Chat con contexto de la pantalla activa |

**Cliente IA (único, reutilizable en todo el backend):**
```python
client = OpenAI(
    base_url="https://openai.enerser.com.mx/api/v1",
    api_key="_token"
)
# Modelo: openai/gpt-oss-20b
# NO soporta imágenes — solo texto
```

---

## Infraestructura Docker Compose

```
services:
  backend      → FastAPI (Python)
  frontend     → Flutter Web (Nginx)
  db           → PostgreSQL
  sonarqube    → SonarQube (ya existente)
  sonar-db     → PostgreSQL separada para Sonar
```

Accesible desde cualquier equipo en la red local.

---

## Fases de Desarrollo

| Fase | Qué se construye | Estado |
|---|---|---|
| **1 — Base** | Docker Compose + PostgreSQL + FastAPI base + JWT + usuarios | ✅ COMPLETA |
| **2 — Proyectos y casos** | CRUD Proyectos / Módulos / Test Cases + IA generadora | ✅ COMPLETA |
| **3 — Ejecución** | Sesiones, asignación, estados, dashboard | ✅ COMPLETA |
| **4 — Capturas** | Backend: subir, reordenar, eliminar, servir imágenes. Flutter: estructura base, GetX, ApiClient, AuthController, LoginScreen | ✅ COMPLETA |
| **5 — PDF evidencia manual** | Backend: endpoint pdf-data. Flutter: ExecutionPdfService + ExecutionPdfController | ✅ COMPLETA |
| **6 — Bugs** | Registro con IA (borrador automático), CRUD completo, filtros por sesión | ✅ COMPLETA |
| **7 — Migración N8N** | SonarQube + GitHub + QEngine en backend Python | ✅ COMPLETA |
| **8 — PDFs existentes** | PDF Sonar + PDF posteo + PDF QEngine con diseño normativo | ✅ COMPLETA |
| **9 — UI Flutter** | Todas las pantallas del portal (proyectos, módulos, test cases, ejecución, bugs, reportes) | ✅ COMPLETA |
| **10 — IA avanzada** | Asistente contextual en el portal | ✅ COMPLETA |
| **11 — Exportar QEngine** | Cuando haya APIs disponibles | FUTURO |
| **12 — Wasabi Storage** | Migración de imágenes (avatares + screenshots) a Wasabi S3, versionado de PDFs, timer por test case | ✅ COMPLETA |

---

## Archivos Pendientes de Recibir

Para no partir de cero, se esperan los siguientes archivos del usuario:

- [ ] Archivos Python actuales (clientes de APIs: QEngine, SonarQube, GitHub)
- [ ] JSONs de flujos N8N (Zoho, SonarQube, GitHub)
- [ ] Código Flutter actual del portal
- [ ] PDFs de ejemplo o recursos del diseño normativo

---

## Decisiones Tomadas

- PDF se genera en Flutter (no en backend) — más fácil modificar en Dart
- N8N se reemplaza completamente por el backend Python
- Login se rehace desde cero en PostgreSQL
- IA no procesa imágenes (modelo no lo soporta)
- IA no resume commits en hoja de posteo (no se considera necesario)
- Bugs: sin integración externa por ahora, `external_id` reservado para futuro
- Exportación a QEngine: dejada para cuando compartan las APIs
- Selección de módulos al crear sesión: tabla `execution_modules` registra los módulos elegidos; si no se envían `module_ids`, se incluyen todos (retrocompatible)
- Almacenamiento de archivos migrado a Wasabi (S3-compatible) — backend actúa como proxy, el frontend no conoce la API de Wasabi
- Imágenes (avatares y screenshots) se almacenan en Wasabi con presigned URLs para descarga
- PDFs de ejecución se versionan en Wasabi — cada generación crea una nueva versión numerada (v1, v2, v3...)
- Timer por test case: el cronómetro inicia al activar captura de pantalla y se acumula; la duración total aparece en el PDF

---

## Notas y Pendientes

- Verificar si el portal Flutter actual se sirve como web o solo como app de escritorio
- Confirmar credenciales y token del API de IA interna al momento de desarrollar
- Confirmar estructura exacta de respuesta de APIs de QEngine (al recibir archivos)
- Definir puerto de exposición del portal en red local
