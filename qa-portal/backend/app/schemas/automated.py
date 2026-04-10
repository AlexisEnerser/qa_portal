from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from uuid import UUID
from app.models.automated import AutomatedRunStatus, AutomatedResultStatus
from app.schemas.user import UserSummary


# ─── Suite ────────────────────────────────────────────────────────────────────

class SuiteCreate(BaseModel):
    project_id: UUID
    name: str
    description: Optional[str] = None


class SuiteUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None


class SuiteResponse(BaseModel):
    id: UUID
    project_id: UUID
    name: str
    description: Optional[str]
    created_by: UUID
    creator: UserSummary
    created_at: datetime
    updated_at: datetime
    model_config = {"from_attributes": True}


class SuiteSummary(BaseModel):
    id: UUID
    project_id: UUID
    name: str
    description: Optional[str]
    created_at: datetime
    test_count: int = 0
    last_run_status: Optional[str] = None
    last_run_at: Optional[datetime] = None
    last_run_passed: int = 0
    last_run_total: int = 0



# ─── Automated Test Case ─────────────────────────────────────────────────────

class AutoTestCreate(BaseModel):
    name: str
    description: Optional[str] = None
    source_test_case_id: Optional[UUID] = None
    script_code: Optional[str] = None
    target_url: Optional[str] = None
    order: Optional[int] = 0


class AutoTestUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    script_code: Optional[str] = None
    target_url: Optional[str] = None
    order: Optional[int] = None
    is_active: Optional[bool] = None


class AutoTestResponse(BaseModel):
    id: UUID
    suite_id: UUID
    name: str
    description: Optional[str]
    source_test_case_id: Optional[UUID]
    script_code: Optional[str]
    target_url: Optional[str]
    order: int
    is_active: bool
    created_by: UUID
    created_at: datetime
    updated_at: datetime
    model_config = {"from_attributes": True}


# ─── Clone from manual ───────────────────────────────────────────────────────

class CloneFromManualRequest(BaseModel):
    suite_id: UUID
    source_test_case_id: UUID
    target_url: str


# ─── IA Script Generation ────────────────────────────────────────────────────

class GenerateScriptRequest(BaseModel):
    description: str
    target_url: str
    source_steps: Optional[List[dict]] = None


class GenerateScriptResponse(BaseModel):
    script_code: str


class RefineScriptRequest(BaseModel):
    current_script: str
    instruction: str


class RefineScriptResponse(BaseModel):
    script_code: str



# ─── Run ──────────────────────────────────────────────────────────────────────

class RunCreate(BaseModel):
    environment: Optional[str] = None
    version: Optional[str] = None


class RunResponse(BaseModel):
    id: UUID
    suite_id: UUID
    status: AutomatedRunStatus
    environment: Optional[str]
    version: Optional[str]
    started_at: datetime
    finished_at: Optional[datetime]
    triggered_by: UUID
    model_config = {"from_attributes": True}


class RunSummary(BaseModel):
    id: UUID
    suite_id: UUID
    status: AutomatedRunStatus
    environment: Optional[str]
    version: Optional[str]
    started_at: datetime
    finished_at: Optional[datetime]
    total: int = 0
    passed: int = 0
    failed: int = 0
    error: int = 0
    skipped: int = 0


class RunStatusResponse(BaseModel):
    id: UUID
    status: AutomatedRunStatus
    total: int = 0
    completed: int = 0
    passed: int = 0
    failed: int = 0
    error: int = 0


# ─── Run Result ───────────────────────────────────────────────────────────────

class RunResultResponse(BaseModel):
    id: UUID
    run_id: UUID
    automated_test_case_id: UUID
    test_name: str = ""
    status: AutomatedResultStatus
    duration_ms: Optional[int]
    error_message: Optional[str]
    console_log: Optional[str]
    screenshots: Optional[list] = []
    executed_at: Optional[datetime]
    model_config = {"from_attributes": True}
