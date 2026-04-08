"""Add route column to test_execution_results

Revision ID: 0007
Revises: 0006
Create Date: 2026-04-08
"""
from alembic import op
import sqlalchemy as sa

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("test_execution_results", sa.Column("route", sa.String(512), nullable=True))


def downgrade() -> None:
    op.drop_column("test_execution_results", "route")
