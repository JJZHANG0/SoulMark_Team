"""Add phone verification and WeChat identities.

Revision ID: 20260804_0003
Revises: 20260804_0002
Create Date: 2026-08-04 00:00:01
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260804_0003"
down_revision: str | None = "20260804_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column("users", "email", existing_type=sa.String(length=320), nullable=True)
    op.alter_column(
        "users",
        "password_hash",
        existing_type=sa.String(length=255),
        nullable=True,
    )
    op.add_column("users", sa.Column("phone_number", sa.String(length=20), nullable=True))
    op.add_column("users", sa.Column("wechat_openid", sa.String(length=128), nullable=True))
    op.add_column("users", sa.Column("wechat_unionid", sa.String(length=128), nullable=True))
    op.create_index("ix_users_phone_number", "users", ["phone_number"], unique=True)
    op.create_index("ix_users_wechat_openid", "users", ["wechat_openid"], unique=True)
    op.create_index("ix_users_wechat_unionid", "users", ["wechat_unionid"], unique=True)

    op.create_table(
        "phone_verification_codes",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("phone_number", sa.String(length=20), nullable=False),
        sa.Column("code_hash", sa.String(length=255), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_phone_verification_codes_phone_number",
        "phone_verification_codes",
        ["phone_number"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_phone_verification_codes_phone_number",
        table_name="phone_verification_codes",
    )
    op.drop_table("phone_verification_codes")
    op.drop_index("ix_users_wechat_unionid", table_name="users")
    op.drop_index("ix_users_wechat_openid", table_name="users")
    op.drop_index("ix_users_phone_number", table_name="users")
    op.drop_column("users", "wechat_unionid")
    op.drop_column("users", "wechat_openid")
    op.drop_column("users", "phone_number")
    op.alter_column(
        "users",
        "password_hash",
        existing_type=sa.String(length=255),
        nullable=False,
    )
    op.alter_column("users", "email", existing_type=sa.String(length=320), nullable=False)
