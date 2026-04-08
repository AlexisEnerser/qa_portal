from sqlalchemy import Column, String, Text, Integer, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID, JSONB
from datetime import datetime, timezone
import uuid

from app.database import Base


class SonarReport(Base):
    __tablename__ = "sonar_reports"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_name = Column(String(150), nullable=False)
    repo_url = Column(String(512), nullable=True)
    branch = Column(String(100), nullable=True)
    analyzed_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    issues_count = Column(Integer, default=0)
    vulnerabilities_count = Column(Integer, default=0)
    raw_json = Column(JSONB, nullable=True)
    ai_analysis = Column(Text, nullable=True)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    creator = relationship("User", foreign_keys=[created_by])


class PostingSheet(Base):
    __tablename__ = "posting_sheets"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id"), nullable=True)
    commit_id = Column(String(100), nullable=False)
    repo = Column(String(255), nullable=False)
    org = Column(String(100), nullable=True)
    branch = Column(String(100), nullable=True)
    summary_json = Column(JSONB, nullable=True)
    generated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    project = relationship("Project", foreign_keys=[project_id])
    creator = relationship("User", foreign_keys=[created_by])


class Developer(Base):
    __tablename__ = "developers"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(150), nullable=False)
    github_username = Column(String(100), nullable=False, unique=True, index=True)
    email = Column(String(150), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class ExecutionPdfVersion(Base):
    __tablename__ = "execution_pdf_versions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    execution_id = Column(UUID(as_uuid=True), ForeignKey("test_executions.id", ondelete="CASCADE"), nullable=False)
    version_number = Column(Integer, nullable=False)
    wasabi_file_id = Column(String(255), nullable=False)
    file_size = Column(Integer, nullable=True)
    generated_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    generated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    execution = relationship("TestExecution", backref="pdf_versions")
    generator = relationship("User", foreign_keys=[generated_by])
