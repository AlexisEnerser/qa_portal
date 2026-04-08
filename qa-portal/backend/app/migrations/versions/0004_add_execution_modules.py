"""add execution_modules table

Revision ID: 0004
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "0004"
down_revision = "83f6e3d0c1ef"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "execution_modules",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("execution_id", UUID(as_uuid=True), sa.ForeignKey("test_executions.id", ondelete="CASCADE"), nullable=False),
        sa.Column("module_id", UUID(as_uuid=True), sa.ForeignKey("modules.id", ondelete="CASCADE"), nullable=False),
    )


def downgrade():
    op.drop_table("execution_modules")
