from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from enum import Enum


class ContextType(str, Enum):
    test_case = "test_case"
    execution = "execution"
    bug = "bug"
    sonar_report = "sonar_report"
    posting_sheet = "posting_sheet"
    qengine = "qengine"
    general = "general"


class ChatMessage(BaseModel):
    role: str = Field(..., pattern="^(user|assistant)$")
    content: str


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000)
    context_type: ContextType = ContextType.general
    context_data: Optional[Dict[str, Any]] = None
    history: List[ChatMessage] = Field(default_factory=list, max_length=20)


class ChatResponse(BaseModel):
    reply: str
    context_type: ContextType
