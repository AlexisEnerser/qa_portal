from sqlalchemy import Column, String, Text, Boolean, Integer, DateTime, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime, timezone
import uuid
import enum

from app.database import Base


class TestCaseStatus(str, enum.Enum):
    active = "active"
    inactive = "inactive"


class Project(Base):
    __tablename__ = "projects"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(150), nullable=False)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    creator = relationship("User", foreign_keys=[created_by])
    modules = relationship("Module", back_populates="project", cascade="all, delete-orphan", order_by="Module.order")
    executions = relationship("TestExecution", back_populates="project", cascade="all, delete-orphan")


class Module(Base):
    __tablename__ = "modules"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(150), nullable=False)
    description = Column(Text, nullable=True)
    order = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    project = relationship("Project", back_populates="modules")
    test_cases = relationship("TestCase", back_populates="module", cascade="all, delete-orphan")


class TestCase(Base):
    __tablename__ = "test_cases"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    module_id = Column(UUID(as_uuid=True), ForeignKey("modules.id", ondelete="CASCADE"), nullable=False)
    title = Column(String(255), nullable=False)
    preconditions = Column(Text, nullable=True)
    postconditions = Column(Text, nullable=True)
    status = Column(SAEnum(TestCaseStatus), nullable=False, default=TestCaseStatus.active)
    order = Column(Integer, default=0, nullable=True)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    module = relationship("Module", back_populates="test_cases")
    creator = relationship("User", foreign_keys=[created_by])
    steps = relationship("TestStep", back_populates="test_case", cascade="all, delete-orphan", order_by="TestStep.order")

    @property
    def module_name(self) -> str:
        return self.module.name if self.module else ""


class TestStep(Base):
    __tablename__ = "test_steps"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    test_case_id = Column(UUID(as_uuid=True), ForeignKey("test_cases.id", ondelete="CASCADE"), nullable=False)
    order = Column(Integer, nullable=False)
    action = Column(Text, nullable=False)
    test_data = Column(Text, nullable=True)
    expected_result = Column(Text, nullable=False)

    test_case = relationship("TestCase", back_populates="steps")
