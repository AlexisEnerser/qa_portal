from sqlalchemy import Column, String, Text, Integer, DateTime, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime, timezone
import uuid
import enum

from app.database import Base


class ExecutionResultStatus(str, enum.Enum):
    pending = "pending"
    passed = "passed"
    failed = "failed"
    blocked = "blocked"
    not_applicable = "not_applicable"


class ExecutionModule(Base):
    __tablename__ = "execution_modules"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    execution_id = Column(UUID(as_uuid=True), ForeignKey("test_executions.id", ondelete="CASCADE"), nullable=False)
    module_id = Column(UUID(as_uuid=True), ForeignKey("modules.id", ondelete="CASCADE"), nullable=False)

    execution = relationship("TestExecution", back_populates="selected_modules")
    module = relationship("Module")


class TestExecution(Base):
    __tablename__ = "test_executions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(200), nullable=False)
    version = Column(String(50), nullable=True)
    environment = Column(String(100), nullable=True)
    started_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    finished_at = Column(DateTime(timezone=True), nullable=True)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    project = relationship("Project", back_populates="executions")
    creator = relationship("User", foreign_keys=[created_by])
    results = relationship("TestExecutionResult", back_populates="execution", cascade="all, delete-orphan")
    selected_modules = relationship("ExecutionModule", back_populates="execution", cascade="all, delete-orphan")


class TestExecutionResult(Base):
    __tablename__ = "test_execution_results"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    execution_id = Column(UUID(as_uuid=True), ForeignKey("test_executions.id", ondelete="CASCADE"), nullable=False)
    test_case_id = Column(UUID(as_uuid=True), ForeignKey("test_cases.id"), nullable=False)
    assigned_to = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    status = Column(SAEnum(ExecutionResultStatus), nullable=False, default=ExecutionResultStatus.pending)
    notes = Column(Text, nullable=True)
    executed_at = Column(DateTime(timezone=True), nullable=True)
    executed_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    duration_seconds = Column(Integer, nullable=True)

    execution = relationship("TestExecution", back_populates="results")
    test_case = relationship("TestCase")
    assignee = relationship("User", foreign_keys=[assigned_to])
    executor = relationship("User", foreign_keys=[executed_by])
    screenshots = relationship("Screenshot", back_populates="execution_result", cascade="all, delete-orphan", order_by="Screenshot.order")
    bugs = relationship("Bug", back_populates="execution_result", cascade="all, delete-orphan")


class Screenshot(Base):
    __tablename__ = "screenshots"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    execution_result_id = Column(UUID(as_uuid=True), ForeignKey("test_execution_results.id", ondelete="CASCADE"), nullable=False)
    file_path = Column(String(512), nullable=True)
    file_name = Column(String(255), nullable=False)
    wasabi_file_id = Column(String(255), nullable=True)
    order = Column(Integer, nullable=False, default=0)
    taken_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    taken_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)

    execution_result = relationship("TestExecutionResult", back_populates="screenshots")
    taker = relationship("User", foreign_keys=[taken_by])
