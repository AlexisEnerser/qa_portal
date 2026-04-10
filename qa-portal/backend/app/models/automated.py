from sqlalchemy import Column, String, Text, Integer, Boolean, DateTime, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID, JSONB
from datetime import datetime, timezone
import uuid
import enum
from app.database import Base

class AutomatedRunStatus(str, enum.Enum):
    pending = "pending"
    running = "running"
    completed = "completed"
    failed = "failed"
    cancelled = "cancelled"

class AutomatedResultStatus(str, enum.Enum):
    passed = "passed"
    failed = "failed"
    error = "error"
    skipped = "skipped"

class AutomatedSuite(Base):
    __tablename__ = "automated_suites"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    project = relationship("Project", foreign_keys=[project_id])
    creator = relationship("User", foreign_keys=[created_by])
    test_cases = relationship("AutomatedTestCase", back_populates="suite", cascade="all, delete-orphan", order_by="AutomatedTestCase.order")
    runs = relationship("AutomatedRun", back_populates="suite", cascade="all, delete-orphan")

class AutomatedTestCase(Base):
    __tablename__ = "automated_test_cases"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    suite_id = Column(UUID(as_uuid=True), ForeignKey("automated_suites.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    source_test_case_id = Column(UUID(as_uuid=True), ForeignKey("test_cases.id", ondelete="SET NULL"), nullable=True)
    script_code = Column(Text, nullable=True)
    target_url = Column(String(512), nullable=True)
    order = Column(Integer, default=0, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    suite = relationship("AutomatedSuite", back_populates="test_cases")
    source_test_case = relationship("TestCase", foreign_keys=[source_test_case_id])
    creator = relationship("User", foreign_keys=[created_by])

class AutomatedRun(Base):
    __tablename__ = "automated_runs"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    suite_id = Column(UUID(as_uuid=True), ForeignKey("automated_suites.id", ondelete="CASCADE"), nullable=False)
    status = Column(SAEnum(AutomatedRunStatus), nullable=False, default=AutomatedRunStatus.pending)
    environment = Column(String(100), nullable=True)
    version = Column(String(50), nullable=True)
    started_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    finished_at = Column(DateTime(timezone=True), nullable=True)
    triggered_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    suite = relationship("AutomatedSuite", back_populates="runs")
    trigger_user = relationship("User", foreign_keys=[triggered_by])
    results = relationship("AutomatedRunResult", back_populates="run", cascade="all, delete-orphan")

class AutomatedRunResult(Base):
    __tablename__ = "automated_run_results"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    run_id = Column(UUID(as_uuid=True), ForeignKey("automated_runs.id", ondelete="CASCADE"), nullable=False)
    automated_test_case_id = Column(UUID(as_uuid=True), ForeignKey("automated_test_cases.id", ondelete="CASCADE"), nullable=False)
    status = Column(SAEnum(AutomatedResultStatus), nullable=False, default=AutomatedResultStatus.skipped)
    duration_ms = Column(Integer, nullable=True)
    error_message = Column(Text, nullable=True)
    console_log = Column(Text, nullable=True)
    screenshots = Column(JSONB, nullable=True, default=list)
    executed_at = Column(DateTime(timezone=True), nullable=True)
    run = relationship("AutomatedRun", back_populates="results")
    test_case = relationship("AutomatedTestCase", foreign_keys=[automated_test_case_id])
