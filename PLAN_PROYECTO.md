# Plan de Desarrollo — Portal QA Unificado
> Última actualización: 2026-04-09 (rev 4)
> Estado general: EN DESARROLLO — Módulos 1-13 completos

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
| Pruebas automatizadas | Playwright (Python) en contenedor backend |
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

### `automated_suites`
```
id, project_id, name, description,
created_by, created_at, updated_at
```

### `automated_test_cases`
```
id, suite_id, name, description,
source_test_case_id (FK nullable → test_cases.id, referencia al caso manual original),
script_code (TEXT — código Playwright en Python),
target_url (VARCHAR — URL base de la app a probar),
order, is_active,
created_by, created_at, updated_at
```

### `automated_runs`
```
id, suite_id,
status (pending/running/completed/failed/cancelled),
environment, version,
started_at, finished_at, triggered_by
```

### `automated_run_results`
```
id, run_id, automated_test_case_id,
status (passed/failed/error/skipped),
duration_ms, error_message, console_log (TEXT),
screenshots (JSON array de wasabi_file_ids),
executed_at
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
| Reporte pruebas automatizadas | BD propia (Módulo 13) | Resultados de suites automatizadas + screenshots + formulario normativo |
| Reporte pruebas automatizadas (legacy) | QEngine API | Migrado de N8N — DEPRECADO, se mantiene temporalmente |
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

### MÓDULO 9 — Integración QEngine (Pruebas Automatizadas) — DEPRECADO

> **Nota:** Este módulo será reemplazado por el Módulo 13 (Pruebas Automatizadas Nativas).
> Se mantiene temporalmente para proyectos que aún tengan datos en QEngine.
> Una vez migrados todos los proyectos, se eliminará la dependencia con Zoho QEngine.

**Flujo original (migrado desde N8N + Selenium):**
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

### MÓDULO 13 — Pruebas Automatizadas Nativas (reemplaza QEngine)

**Objetivo:** Permitir que un QA sin experiencia en programación pueda crear, ejecutar y documentar pruebas automatizadas directamente desde el portal, usando IA para generar los scripts y los test cases manuales existentes como referencia.

**Tecnología de ejecución:** Playwright (Python) ejecutado en el contenedor backend existente (ya tiene Chromium + ChromeDriver instalados).

**Dependencia nueva:** `playwright` en `requirements.txt` + `playwright install chromium` en Dockerfile.

#### Flujo del usuario

1. QA entra al módulo de pruebas automatizadas de un proyecto
2. Crea una "Suite Automatizada" (nombre, descripción)
3. Crea test cases automatizados por uno de 3 caminos:
   - **Clonar desde test case manual:** selecciona un test case existente del proyecto, se copian los pasos como referencia contextual, y la IA genera el script Playwright a partir de esos pasos + la URL objetivo
   - **Describir en lenguaje natural:** escribe algo como "Verificar que el login rechaza contraseñas incorrectas en https://miapp.com/login" y la IA genera el script completo
   - **Editar manualmente:** para el QA que sí sabe código, puede escribir o ajustar el script directamente
4. El QA puede previsualizar el script generado y pedir ajustes a la IA via chat ("cambia el selector del botón", "agrega verificación del mensaje de error")
5. Ejecuta la suite desde el portal — ve progreso en tiempo real
6. Los resultados (pass/fail, screenshots automáticos por paso, logs, duración) se guardan en BD
7. Para re-testear: botón "Ejecutar de nuevo" lanza la misma suite y crea un nuevo run en el historial

#### Páginas Flutter

1. **Lista de suites automatizadas** (por proyecto) — similar a la lista de ejecuciones manuales, con indicador del último run (fecha, status general, % pasados)
2. **Detalle de suite** — lista de test cases automatizados con status del último run por cada uno, botón "Ejecutar suite", botón "Nuevo test"
3. **Crear/editar test automatizado:**
   - Botón "Clonar desde prueba manual" → selector de test case → preview de pasos clonados → botón "Generar script con IA"
   - Campo de texto "Describe qué quieres probar" → botón "Generar con IA"
   - Editor de código (solo lectura por defecto, editable si el QA quiere)
   - Campo "URL de la aplicación"
   - Mini-chat con IA para refinar: "Cambia el selector", "Agrega verificación de que aparezca un toast", "Haz que espere 3 segundos antes de verificar"
4. **Pantalla de ejecución** — progreso en tiempo real (polling o WebSocket), logs por test, screenshots conforme se generan
5. **Historial de runs** — lista de ejecuciones pasadas con resultados, comparable entre runs ("en v2.1 pasaban 15/20, en v2.2 pasan 18/20")
6. **Resultados de un run** — por cada test: status, duración, screenshots automáticos, log de errores, botón para registrar bug si falló

#### Backend — Endpoints nuevos

```
# CRUD Suites
GET    /automated/suites?project_id=...
POST   /automated/suites
GET    /automated/suites/{suite_id}
PUT    /automated/suites/{suite_id}
DELETE /automated/suites/{suite_id}

# CRUD Test Cases Automatizados
GET    /automated/suites/{suite_id}/tests
POST   /automated/suites/{suite_id}/tests
GET    /automated/tests/{test_id}
PUT    /automated/tests/{test_id}
DELETE /automated/tests/{test_id}

# Clonación desde test case manual
POST   /automated/tests/clone-from-manual
       Body: { suite_id, source_test_case_id, target_url }
       → Copia pasos como referencia, IA genera script Playwright

# Generación de script con IA
POST   /automated/generate-script
       Body: { description, target_url, source_steps (opcional) }
       → Devuelve script Playwright generado

# Refinamiento de script con IA (chat)
POST   /automated/refine-script
       Body: { current_script, instruction }
       → Devuelve script ajustado según la instrucción del QA

# Ejecución
POST   /automated/suites/{suite_id}/run
       Body: { environment (opcional), version (opcional) }
       → Crea un run, lanza ejecución en background, devuelve run_id
GET    /automated/runs/{run_id}/status
       → Estado actual del run + progreso (polling)
GET    /automated/runs/{run_id}/results
       → Resultados completos con screenshots y logs

# Historial
GET    /automated/suites/{suite_id}/runs
       → Lista de runs pasados con resumen de resultados

# PDF
GET    /automated/runs/{run_id}/pdf-data
       → JSON estructurado para que Flutter genere el PDF normativo
```

#### Servicio IA — Generación de scripts

El prompt del sistema instruye a la IA para generar código Playwright en Python con estas reglas:
- Cada paso del test incluye `await page.screenshot(...)` automáticamente
- Usa selectores robustos (texto visible, roles ARIA, data-testid)
- Incluye `assert` para validar resultados esperados
- Maneja timeouts y esperas explícitas
- Código simple y legible, con comentarios en español

**Ejemplo de entrada (clonado desde manual):**
```
Test case: "Login con credenciales incorrectas"
URL: https://miapp.com/login
Pasos manuales:
1. Acción: Abrir la página de login | Resultado esperado: Se muestra el formulario
2. Acción: Ingresar email válido y contraseña incorrecta | Datos: email=test@test.com, pass=abc123 | Resultado esperado: Mensaje de error
3. Acción: Verificar mensaje de error | Resultado esperado: "Credenciales inválidas"
```

**Ejemplo de salida (script generado por IA):**
```python
# Test: Login con credenciales incorrectas
# URL: https://miapp.com/login
# Clonado desde test case manual: [ID]

async def test_login_credenciales_incorrectas(page):
    # Paso 1: Abrir la página de login
    await page.goto("https://miapp.com/login")
    await page.wait_for_load_state("networkidle")
    await page.screenshot(path="step_01_pagina_login.png")

    # Paso 2: Ingresar credenciales incorrectas
    await page.fill("[name='email']", "test@test.com")
    await page.fill("[name='password']", "abc123")
    await page.screenshot(path="step_02_datos_ingresados.png")

    # Paso 3: Enviar formulario y verificar error
    await page.click("button[type='submit']")
    await page.wait_for_selector(".error-message", timeout=5000)
    await page.screenshot(path="step_03_mensaje_error.png")

    error_text = await page.text_content(".error-message")
    assert "credenciales" in error_text.lower() or "inválid" in error_text.lower(), \
        f"Mensaje de error inesperado: {error_text}"
```

#### Runner de ejecución

- Se ejecuta en el contenedor backend existente (ya tiene Chromium instalado)
- Cada test se ejecuta en un subprocess aislado con timeout configurable
- Screenshots se suben automáticamente a Wasabi y se referencian en `automated_run_results`
- Concurrencia limitada a 1-2 ejecuciones simultáneas (suficiente para 3 QAs)
- Si un test se cuelga, el subprocess se mata después del timeout y se marca como `error`

#### PDF de pruebas automatizadas

Se reutiliza y adapta el `QenginePdfService` existente en Flutter:
- Misma estructura normativa (logo, firmas, información general, conclusión)
- Fuente de datos: BD propia en vez de API de Zoho
- Incluye: nombre de la suite, versión, ambiente, fecha, resultados por test con screenshots, porcentaje de éxito, conclusión auto-generada

---

## Integraciones de IA — Resumen

| # | Dónde | Qué hace |
|---|---|---|
| 1 | Análisis de código | Complementa SonarQube con análisis lógico y de negocio |
| 2 | Crear test cases | Genera propuesta de casos y pasos desde descripción libre |
| 3 | Registro de bugs | Redacta el bug en formato estructurado |
| 4 | Reporte SonarQube | Explica issues en lenguaje claro con sugerencias de corrección |
| 5 | Asistente general | Chat con contexto de la pantalla activa |
| 6 | Generar scripts automatizados | Genera código Playwright desde descripción libre o pasos manuales clonados |
| 7 | Refinar scripts automatizados | Ajusta scripts existentes según instrucciones en lenguaje natural del QA |

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
| **11 — Exportar QEngine** | ~~Cuando haya APIs disponibles~~ CANCELADO — reemplazado por Módulo 13 | ❌ CANCELADO |
| **12 — Wasabi Storage** | Migración de imágenes (avatares + screenshots) a Wasabi S3, versionado de PDFs, timer por test case | ✅ COMPLETA |
| **13.1 — Auto: Modelos y BD** | Tablas `automated_suites`, `automated_test_cases`, `automated_runs`, `automated_run_results` + migraciones Alembic + CRUD endpoints | ✅ COMPLETA |
| **13.2 — Auto: IA genera scripts** | Servicio IA para generar scripts Playwright desde descripción libre o desde pasos manuales clonados | ✅ COMPLETA |
| **13.3 — Auto: Runner** | Servicio de ejecución de scripts Playwright en subprocess, captura de screenshots a Wasabi, manejo de timeouts | ✅ COMPLETA |
| **13.4 — Auto: UI Suites y Tests** | Pantallas Flutter: lista de suites, crear/editar test, clonar desde manual, editor de código, campo URL | ✅ COMPLETA |
| **13.5 — Auto: UI Ejecución** | Pantalla de ejecución en tiempo real (polling), progreso, logs, screenshots conforme se generan | ✅ COMPLETA |
| **13.6 — Auto: Historial y Resultados** | Historial de runs por suite, comparación entre runs, detalle de resultados con screenshots y logs | ✅ COMPLETA |
| **13.7 — Auto: PDF normativo** | Adaptar QenginePdfService para leer de BD propia, mismo formato normativo | ✅ COMPLETA |
| **13.8 — Auto: Chat IA refinamiento** | Mini-chat en pantalla de edición de test para refinar scripts con instrucciones en lenguaje natural | ✅ COMPLETA |

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
- Exportación a QEngine: ~~dejada para cuando compartan las APIs~~ CANCELADA — se reemplaza por pruebas automatizadas nativas
- Selección de módulos al crear sesión: tabla `execution_modules` registra los módulos elegidos; si no se envían `module_ids`, se incluyen todos (retrocompatible)
- Almacenamiento de archivos migrado a Wasabi (S3-compatible) — backend actúa como proxy, el frontend no conoce la API de Wasabi
- Imágenes (avatares y screenshots) se almacenan en Wasabi con presigned URLs para descarga
- PDFs de ejecución se versionan en Wasabi — cada generación crea una nueva versión numerada (v1, v2, v3...)
- Timer por test case: el cronómetro inicia al activar captura de pantalla y se acumula; la duración total aparece en el PDF
- **Pruebas automatizadas nativas reemplazan QEngine** — se elimina la dependencia con Zoho QEngine, Selenium para scraping de imágenes, y las credenciales de Zoho
- **Playwright como motor de automatización** — se ejecuta en el contenedor backend existente (ya tiene Chromium), no se necesita contenedor adicional
- **IA genera scripts Playwright** — el QA describe en español qué quiere probar, la IA genera el código; también puede clonar pasos de test cases manuales como contexto
- **Clonación de test cases manuales como referencia** — los pasos manuales se usan como input para la IA, no se ejecutan directamente; el script generado es independiente
- **Concurrencia limitada a 1-2 ejecuciones simultáneas** — suficiente para equipo de 3 QAs, evita sobrecarga del servidor
- **Módulo 9 (QEngine) se mantiene temporalmente** — para proyectos con datos históricos en Zoho, se eliminará cuando se complete la migración

---

## Notas y Pendientes

- Verificar si el portal Flutter actual se sirve como web o solo como app de escritorio
- Confirmar credenciales y token del API de IA interna al momento de desarrollar
- ~~Confirmar estructura exacta de respuesta de APIs de QEngine (al recibir archivos)~~ — ya no aplica, se reemplaza por módulo nativo
- Definir puerto de exposición del portal en red local
- Agregar `playwright` a `requirements.txt` y `playwright install chromium` al Dockerfile para Módulo 13
- Definir timeout por defecto para ejecución de scripts automatizados (sugerido: 30s por test, 5min por suite)
- Evaluar si se necesita WebSocket para progreso en tiempo real o si polling cada 2s es suficiente
