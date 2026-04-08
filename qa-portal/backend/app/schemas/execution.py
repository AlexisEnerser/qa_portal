from pydantic import BaseModel
from typing import Optional, List, Dict
from datetime import datetime
from uuid import UUID
from app.models.execution import ExecutionResultStatus
from app.schemas.user import UserSummary
from app.schemas.project import TestCaseResponse, TestStepResponse


# ─── Sesión de ejecución ─────────────────────────────────────────────────────

class ExecutionCreate(BaseModel):
    name: str
    version: Optional[str] = None
    environment: Optional[str] = None
    module_ids: Optional[List[UUID]] = None


class ExecutionUpdate(BaseModel):
    name: Optional[str] = None
    version: Optional[str] = None
    environment: Optional[str] = None


class ExecutionResponse(BaseModel):
    id: UUID
    project_id: UUID
    name: str
    version: Optional[str]
    environment: Optional[str]
    started_at: datetime
    finished_at: Optional[datetime]
    created_by: UUID
    creator: UserSummary

    model_config = {"from_attributes": True}


class ExecutionSummary(BaseModel):
    id: UUID
    name: str
    version: Optional[str]
    environment: Optional[str]
    started_at: datetime
    finished_at: Optional[datetime]
    total: int = 0
    passed: int = 0
    failed: int = 0
    blocked: int = 0
    not_applicable: int = 0
    pending: int = 0

    model_config = {"from_attributes": True}


# ─── Resultado por test case ──────────────────────────────────────────────────

class ResultUpdate(BaseModel):
    status: Optional[ExecutionResultStatus] = None
    assigned_to: Optional[UUID] = None
    notes: Optional[str] = None
    duration_seconds: Optional[int] = None


class ScreenshotResponse(BaseModel):
    id: UUID
    file_name: str
    order: int
    taken_at: datetime

    model_config = {"from_attributes": True}


class ResultResponse(BaseModel):
    id: UUID
    execution_id: UUID
    test_case_id: UUID
    assigned_to: Optional[UUID]
    assignee: Optional[UserSummary]
    status: ExecutionResultStatus
    notes: Optional[str]
    executed_at: Optional[datetime]
    executed_by: Optional[UUID]
    executor: Optional[UserSummary]
    duration_seconds: Optional[int] = None
    screenshots: List[ScreenshotResponse] = []

    model_config = {"from_attributes": True}


class ResultWithTestCase(BaseModel):
    id: UUID
    execution_id: UUID
    test_case_id: UUID
    assigned_to: Optional[UUID]
    assignee: Optional[UserSummary]
    status: ExecutionResultStatus
    notes: Optional[str]
    executed_at: Optional[datetime]
    executed_by: Optional[UUID]
    executor: Optional[UserSummary]
    duration_seconds: Optional[int] = None
    screenshots: List[ScreenshotResponse] = []
    test_case: TestCaseResponse

    model_config = {"from_attributes": True}


# ─── Dashboard ────────────────────────────────────────────────────────────────

class QAProgress(BaseModel):
    user: UserSummary
    total: int
    passed: int
    failed: int
    blocked: int
    not_applicable: int
    pending: int


class ModuleProgress(BaseModel):
    module_id: UUID
    module_name: str
    total: int
    passed: int
    failed: int
    blocked: int
    not_applicable: int
    pending: int


class DashboardResponse(BaseModel):
    execution_id: UUID
    execution_name: str
    total: int
    passed: int
    failed: int
    blocked: int
    not_applicable: int
    pending: int
    progress_pct: float
    by_module: List[ModuleProgress]
    by_qa: List[QAProgress]
