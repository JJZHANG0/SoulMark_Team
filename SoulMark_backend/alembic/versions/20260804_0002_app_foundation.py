"""Add onboarding, relationship layout, practices, and reviews.

Revision ID: 20260804_0002
Revises: 20260804_0001
Create Date: 2026-08-04 20:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260804_0002"
down_revision: str | None = "20260804_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("users", sa.Column("communication_goal", sa.String(length=80), nullable=True))
    op.add_column(
        "users",
        sa.Column("onboarding_completed", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        "users", sa.Column("onboarding_completed_at", sa.DateTime(timezone=True), nullable=True)
    )

    op.add_column(
        "contacts", sa.Column("position_x", sa.Float(), nullable=False, server_default="0.5")
    )
    op.add_column(
        "contacts", sa.Column("position_y", sa.Float(), nullable=False, server_default="0.5")
    )
    op.add_column(
        "contacts",
        sa.Column("symbol", sa.String(length=80), nullable=False, server_default="person.fill"),
    )
    op.add_column("contacts", sa.Column("memory", sa.Text(), nullable=True))

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
        op.f("ix_practice_sessions_owner_id"), "practice_sessions", ["owner_id"], unique=False
    )

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
        sa.ForeignKeyConstraint(["practice_id"], ["practice_sessions.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["owner_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_conversation_reviews_owner_id"),
        "conversation_reviews",
        ["owner_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_conversation_reviews_owner_id"), table_name="conversation_reviews")
    op.drop_table("conversation_reviews")
    op.drop_index(op.f("ix_practice_sessions_owner_id"), table_name="practice_sessions")
    op.drop_table("practice_sessions")
    op.drop_column("contacts", "memory")
    op.drop_column("contacts", "symbol")
    op.drop_column("contacts", "position_y")
    op.drop_column("contacts", "position_x")
    op.drop_column("users", "onboarding_completed_at")
    op.drop_column("users", "onboarding_completed")
    op.drop_column("users", "communication_goal")
