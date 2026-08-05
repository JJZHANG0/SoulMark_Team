"""Reconcile databases created before the unified schema.

Earlier development branches reused revision IDs 20260804_0002 and
20260804_0003 for different schema changes. This idempotent migration fills
in application tables and columns that may be absent when upgrading an
existing SoulMark database.

Revision ID: 20260804_0005
Revises: 20260804_0004
Create Date: 2026-08-05 12:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260804_0005"
down_revision: str | None = "20260804_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _column_names(table_name: str) -> set[str]:
    return {column["name"] for column in sa.inspect(op.get_bind()).get_columns(table_name)}


def _index_names(table_name: str) -> set[str]:
    return {
        index["name"]
        for index in sa.inspect(op.get_bind()).get_indexes(table_name)
        if index["name"] is not None
    }


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())

    user_columns = _column_names("users")
    if "communication_goal" not in user_columns:
        op.add_column(
            "users",
            sa.Column("communication_goal", sa.String(length=80), nullable=True),
        )
    if "onboarding_completed" not in user_columns:
        op.add_column(
            "users",
            sa.Column(
                "onboarding_completed",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            ),
        )
    if "onboarding_completed_at" not in user_columns:
        op.add_column(
            "users",
            sa.Column("onboarding_completed_at", sa.DateTime(timezone=True), nullable=True),
        )

    contact_columns = _column_names("contacts")
    if "position_x" not in contact_columns:
        op.add_column(
            "contacts",
            sa.Column("position_x", sa.Float(), nullable=False, server_default="0.5"),
        )
    if "position_y" not in contact_columns:
        op.add_column(
            "contacts",
            sa.Column("position_y", sa.Float(), nullable=False, server_default="0.5"),
        )
    if "symbol" not in contact_columns:
        op.add_column(
            "contacts",
            sa.Column(
                "symbol",
                sa.String(length=80),
                nullable=False,
                server_default="person.fill",
            ),
        )
    if "memory" not in contact_columns:
        op.add_column("contacts", sa.Column("memory", sa.Text(), nullable=True))

    if "practice_sessions" not in tables:
        op.create_table(
            "practice_sessions",
            sa.Column("id", sa.Uuid(), nullable=False),
            sa.Column("owner_id", sa.Uuid(), nullable=False),
            sa.Column("contact_id", sa.Uuid(), nullable=True),
            sa.Column("participant_name", sa.String(length=100), nullable=False),
            sa.Column("mode_title", sa.String(length=100), nullable=False),
            sa.Column("mode_guidance", sa.Text(), nullable=True),
            sa.Column("duration_seconds", sa.Integer(), nullable=False),
            sa.Column("user_transcript", sa.Text(), nullable=False),
            sa.Column("assistant_transcript", sa.Text(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.CheckConstraint("duration_seconds >= 0", name="ck_practice_duration"),
            sa.ForeignKeyConstraint(["contact_id"], ["contacts.id"], ondelete="SET NULL"),
            sa.ForeignKeyConstraint(["owner_id"], ["users.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(
            op.f("ix_practice_sessions_owner_id"),
            "practice_sessions",
            ["owner_id"],
            unique=False,
        )
    elif "ix_practice_sessions_owner_id" not in _index_names("practice_sessions"):
        op.create_index(
            op.f("ix_practice_sessions_owner_id"),
            "practice_sessions",
            ["owner_id"],
            unique=False,
        )

    if "conversation_reviews" not in tables:
        op.create_table(
            "conversation_reviews",
            sa.Column("id", sa.Uuid(), nullable=False),
            sa.Column("owner_id", sa.Uuid(), nullable=False),
            sa.Column("practice_id", sa.Uuid(), nullable=True),
            sa.Column("title", sa.String(length=160), nullable=False),
            sa.Column("source", sa.String(length=30), nullable=False),
            sa.Column("transcript", sa.Text(), nullable=False),
            sa.Column("score", sa.Integer(), nullable=False),
            sa.Column("reason", sa.Text(), nullable=False),
            sa.Column("advice", sa.Text(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.CheckConstraint("score >= 0 AND score <= 100", name="ck_reviews_score"),
            sa.ForeignKeyConstraint(
                ["practice_id"],
                ["practice_sessions.id"],
                ondelete="SET NULL",
            ),
            sa.ForeignKeyConstraint(["owner_id"], ["users.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(
            op.f("ix_conversation_reviews_owner_id"),
            "conversation_reviews",
            ["owner_id"],
            unique=False,
        )
    elif "ix_conversation_reviews_owner_id" not in _index_names("conversation_reviews"):
        op.create_index(
            op.f("ix_conversation_reviews_owner_id"),
            "conversation_reviews",
            ["owner_id"],
            unique=False,
        )


def downgrade() -> None:
    # This migration only reconciles schema elements owned by the earlier
    # application-foundation revision. Removing them here could destroy data
    # from databases that already contain the unified application schema.
    pass
