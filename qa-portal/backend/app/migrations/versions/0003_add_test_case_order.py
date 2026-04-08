"""add order column to test_cases

Revision ID: 0003_add_test_case_order
Revises: ff1176bffd78
Create Date: 2026-03-31
"""
from alembic import op
import sqlalchemy as sa

revision = '0003_add_test_case_order'
down_revision = 'ff1176bffd78'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('test_cases', sa.Column('order', sa.Integer(), nullable=True, server_default='0'))


def downgrade() -> None:
    op.drop_column('test_cases', 'order')
