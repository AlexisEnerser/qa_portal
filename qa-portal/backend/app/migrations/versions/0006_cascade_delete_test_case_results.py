"""Add CASCADE on delete to test_execution_results.test_case_id FK

Revision ID: 0006
Revises: 0005
Create Date: 2026-04-08
"""
from alembic import op

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint(
        "test_execution_results_test_case_id_fkey",
        "test_execution_results",
        type_="foreignkey",
    )
    op.create_foreign_key(
        "test_execution_results_test_case_id_fkey",
        "test_execution_results",
        "test_cases",
        ["test_case_id"],
        ["id"],
        ondelete="CASCADE",
    )


def downgrade() -> None:
    op.drop_constraint(
        "test_execution_results_test_case_id_fkey",
        "test_execution_results",
        type_="foreignkey",
    )
    op.create_foreign_key(
        "test_execution_results_test_case_id_fkey",
        "test_execution_results",
        "test_cases",
        ["test_case_id"],
        ["id"],
    )
