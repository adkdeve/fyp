"""add user site assignment and low alert notifications

Revision ID: a4f7c2d9e8b1
Revises: 92a1b3c4d5e6
Create Date: 2026-05-01 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a4f7c2d9e8b1"
down_revision: Union[str, None] = "92a1b3c4d5e6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("site_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_users_site_id_sites",
        "users",
        "sites",
        ["site_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.add_column(
        "users",
        sa.Column(
            "notify_low_alerts",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
    )
    op.alter_column("users", "notify_low_alerts", server_default=None)


def downgrade() -> None:
    op.drop_column("users", "notify_low_alerts")
    op.drop_constraint("fk_users_site_id_sites", "users", type_="foreignkey")
    op.drop_column("users", "site_id")
