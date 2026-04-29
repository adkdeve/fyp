"""user profile notification settings

Revision ID: 92a1b3c4d5e6
Revises: 0b62a69b5da6
Create Date: 2026-04-29 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "92a1b3c4d5e6"
down_revision: Union[str, None] = "0b62a69b5da6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("company", sa.String(length=160), nullable=True))
    op.add_column("users", sa.Column("location", sa.String(length=250), nullable=True))
    op.add_column(
        "users",
        sa.Column(
            "notify_critical_alerts",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
    )
    op.add_column(
        "users",
        sa.Column(
            "notify_medium_alerts",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
    )
    op.alter_column("users", "notify_critical_alerts", server_default=None)
    op.alter_column("users", "notify_medium_alerts", server_default=None)


def downgrade() -> None:
    op.drop_column("users", "notify_medium_alerts")
    op.drop_column("users", "notify_critical_alerts")
    op.drop_column("users", "location")
    op.drop_column("users", "company")
