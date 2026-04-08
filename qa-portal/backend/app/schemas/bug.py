from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from uuid import UUID
from app.models.bug import BugSeverity, BugStatus
from app.schemas.user import UserSummary


class BugCreate(BaseModel):
    title: str
    description: Optional[str] = None
    steps_to_reproduce: Optional[str] = None
    severity: BugSeverity = BugSeverity.medium


class BugUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    steps_to_reproduce: Optional[str] = None
    severity: Optional[BugSeverity] = None
    status: Optional[BugStatus] = None
    external_id: Optional[str] = None


class ScreenshotInfo(BaseModel):
    id: UUID
    file_name: str
    order: int

    model_config = {"from_attributes": True}


class BugResponse(BaseModel):
    id: UUID
    execution_result_id: UUID
    title: str
    description: Optional[str]
    steps_to_reproduce: Optional[str]
    severity: BugSeverity
    status: BugStatus
    external_id: Optional[str]
    created_by: UUID
    created_at: datetime
    creator: UserSummary
    screenshots: List[ScreenshotInfo] = []

    model_config = {"from_attributes": True}


class BugSummary(BaseModel):
    id: UUID
    title: str
    severity: BugSeverity
    status: BugStatus
    created_at: datetime
    creator: UserSummary

    model_config = {"from_attributes": True}


class BugAIRequest(BaseModel):
    """Datos que se envían a la IA para que redacte el bug."""
    test_case_title: str
    preconditions: Optional[str] = None
    steps: List[dict]          # [{order, action, test_data, expected_result}]
    notes: Optional[str] = None   # observaciones del QA al ejecutar
