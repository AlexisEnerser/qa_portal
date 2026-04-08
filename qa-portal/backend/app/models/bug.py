from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime, timezone
import uuid
import enum

from app.database import Base


class BugSeverity(str, enum.Enum):
    critical = "critical"
    high = "high"
    medium = "medium"
    low = "low"


class BugStatus(str, enum.Enum):
    open = "open"
    in_progress = "in_progress"
    closed = "closed"


class Bug(Base):
    __tablename__ = "bugs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    execution_result_id = Column(UUID(as_uuid=True), ForeignKey("test_execution_results.id", ondelete="CASCADE"), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    steps_to_reproduce = Column(Text, nullable=True)
    severity = Column(SAEnum(BugSeverity), nullable=False, default=BugSeverity.medium)
    status = Column(SAEnum(BugStatus), nullable=False, default=BugStatus.open)
    external_id = Column(String(100), nullable=True)  # reservado para Jira/Azure DevOps
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    execution_result = relationship("TestExecutionResult", back_populates="bugs")
    creator = relationship("User", foreign_keys=[created_by])
