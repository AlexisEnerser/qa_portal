"""Add wasabi storage fields, duration_seconds, pdf versions table, avatar_file_id

Revision ID: 0005
Revises: 0004
Create Date: 2026-04-06
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Screenshot: add wasabi_file_id, make file_path nullable
    op.add_column("screenshots", sa.Column("wasabi_file_id", sa.String(255), nullable=True))
    op.alter_column("screenshots", "file_path", existing_type=sa.String(512), nullable=True)

    # TestExecutionResult: add duration_seconds
    op.add_column("test_execution_results", sa.Column("duration_seconds", sa.Integer(), nullable=True))

    # User: add avatar_file_id
    op.add_column("users", sa.Column("avatar_file_id", sa.String(255), nullable=True))

    # ExecutionPdfVersion: new table
    op.create_table(
        "execution_pdf_versions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("execution_id", UUID(as_uuid=True), sa.ForeignKey("test_executions.id", ondelete="CASCADE"), nullable=False),
        sa.Column("version_number", sa.Integer(), nullable=False),
        sa.Column("wasabi_file_id", sa.String(255), nullable=False),
        sa.Column("file_size", sa.Integer(), nullable=True),
        sa.Column("generated_by", UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("generated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("execution_pdf_versions")
    op.drop_column("users", "avatar_file_id")
    op.drop_column("test_execution_results", "duration_seconds")
    op.drop_column("screenshots", "wasabi_file_id")
    op.alter_column("screenshots", "file_path", existing_type=sa.String(512), nullable=False)
