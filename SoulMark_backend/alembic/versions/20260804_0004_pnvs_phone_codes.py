"""Track the provider used for phone verification codes.

Revision ID: 20260804_0004
Revises: 20260804_0003
Create Date: 2026-08-04 00:00:02
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260804_0004"
down_revision: str | None = "20260804_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    columns = {
        column["name"]
        for column in sa.inspect(op.get_bind()).get_columns("phone_verification_codes")
    }
    if "provider" not in columns:
        op.add_column(
            "phone_verification_codes",
            sa.Column(
                "provider",
                sa.String(length=20),
                nullable=False,
                server_default="development",
            ),
        )
        op.alter_column(
            "phone_verification_codes",
            "code_hash",
            existing_type=sa.String(length=255),
            nullable=True,
        )
        op.alter_column(
            "phone_verification_codes",
            "provider",
            existing_type=sa.String(length=20),
            server_default=None,
        )


def downgrade() -> None:
    op.execute("DELETE FROM phone_verification_codes WHERE code_hash IS NULL")
    op.alter_column(
        "phone_verification_codes",
        "code_hash",
        existing_type=sa.String(length=255),
        nullable=False,
    )
    op.drop_column("phone_verification_codes", "provider")
