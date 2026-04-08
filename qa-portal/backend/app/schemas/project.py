from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from uuid import UUID
from app.models.project import TestCaseStatus
from app.schemas.user import UserSummary


# ─── Project ─────────────────────────────────────────────────────────────────

class ProjectCreate(BaseModel):
    name: str
    description: Optional[str] = None


class ProjectUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    is_active: Optional[bool] = None


class ProjectResponse(BaseModel):
    id: UUID
    name: str
    description: Optional[str]
    is_active: bool
    created_by: UUID
    created_at: datetime
    creator: UserSummary

    model_config = {"from_attributes": True}


class ProjectSummary(BaseModel):
    id: UUID
    name: str
    description: Optional[str] = None
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ─── Module ──────────────────────────────────────────────────────────────────

class ModuleCreate(BaseModel):
    name: str
    description: Optional[str] = None
    order: Optional[int] = 0


class ModuleUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    order: Optional[int] = None


class ModuleResponse(BaseModel):
    id: UUID
    project_id: UUID
    name: str
    description: Optional[str]
    order: int
    created_at: datetime

    model_config = {"from_attributes": True}


# ─── Test Step ───────────────────────────────────────────────────────────────

class TestStepCreate(BaseModel):
    order: int
    action: str
    test_data: Optional[str] = None
    expected_result: str


class TestStepUpdate(BaseModel):
    order: Optional[int] = None
    action: Optional[str] = None
    test_data: Optional[str] = None
    expected_result: Optional[str] = None


class TestStepResponse(BaseModel):
    id: UUID
    test_case_id: UUID
    order: int
    action: str
    test_data: Optional[str]
    expected_result: str

    model_config = {"from_attributes": True}


# ─── Test Case ───────────────────────────────────────────────────────────────

class TestCaseCreate(BaseModel):
    title: str
    preconditions: Optional[str] = None
    postconditions: Optional[str] = None
    steps: List[TestStepCreate] = []


class TestCaseUpdate(BaseModel):
    title: Optional[str] = None
    preconditions: Optional[str] = None
    postconditions: Optional[str] = None
    status: Optional[TestCaseStatus] = None


class TestCaseResponse(BaseModel):
    id: UUID
    module_id: UUID
    module_name: str = ""
    title: str
    preconditions: Optional[str]
    postconditions: Optional[str]
    status: TestCaseStatus
    created_by: UUID
    created_at: datetime
    steps: List[TestStepResponse] = []
    creator: UserSummary

    model_config = {"from_attributes": True}


class TestCaseSummary(BaseModel):
    id: UUID
    title: str
    status: TestCaseStatus
    created_at: datetime

    model_config = {"from_attributes": True}


# ─── IA ──────────────────────────────────────────────────────────────────────

class AIGenerateRequest(BaseModel):
    description: str


class AIGeneratedStep(BaseModel):
    order: int
    action: str
    test_data: Optional[str] = None
    expected_result: str


class AIGeneratedTestCase(BaseModel):
    title: str
    preconditions: Optional[str] = None
    postconditions: Optional[str] = None
    steps: List[AIGeneratedStep]


class AIGenerateResponse(BaseModel):
    test_cases: List[AIGeneratedTestCase]
