"""Add automated testing tables: suites, test_cases, runs, run_results

Revision ID: 0008
Revises: 0007
Create Date: 2026-04-09
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSONB

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "automated_suites",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("project_id", UUID(as_uuid=True),
                  sa.ForeignKey("projects.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("created_by", UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "automated_test_cases",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("suite_id", UUID(as_uuid=True),
                  sa.ForeignKey("automated_suites.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("source_test_case_id", UUID(as_uuid=True),
                  sa.ForeignKey("test_cases.id", ondelete="SET NULL"), nullable=True),
        sa.Column("script_code", sa.Text, nullable=True),
        sa.Column("target_url", sa.String(512), nullable=True),
        sa.Column("order", sa.Integer, nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default="true"),
        sa.Column("created_by", UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=False),

        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "automated_runs",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("suite_id", UUID(as_uuid=True),
                  sa.ForeignKey("automated_suites.id", ondelete="CASCADE"), nullable=False),
        sa.Column("status",
                  sa.Enum("pending", "running", "completed", "failed", "cancelled",
                          name="automatedrunstatus"),
                  nullable=False, server_default="pending"),
        sa.Column("environment", sa.String(100), nullable=True),
        sa.Column("version", sa.String(50), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("triggered_by", UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=False),
    )

    op.create_table(
        "automated_run_results",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("run_id", UUID(as_uuid=True),
                  sa.ForeignKey("automated_runs.id", ondelete="CASCADE"), nullable=False),
        sa.Column("automated_test_case_id", UUID(as_uuid=True),
                  sa.ForeignKey("automated_test_cases.id", ondelete="CASCADE"), nullable=False),
        sa.Column("status",
                  sa.Enum("passed", "failed", "error", "skipped",
                          name="automatedresultstatus"),
                  nullable=False, server_default="skipped"),
        sa.Column("duration_ms", sa.Integer, nullable=True),
        sa.Column("error_message", sa.Text, nullable=True),
        sa.Column("console_log", sa.Text, nullable=True),
        sa.Column("screenshots", JSONB, nullable=True),
        sa.Column("executed_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("automated_run_results")
    op.drop_table("automated_runs")
    op.drop_table("automated_test_cases")
    op.drop_table("automated_suites")
    sa.Enum(name="automatedrunstatus").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="automatedresultstatus").drop(op.get_bind(), checkfirst=True)
