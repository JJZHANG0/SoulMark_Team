"""Self-awareness challenges: per-user progress and step reflections."""

import sqlalchemy as sa

from alembic import op

revision = "20261015_0015"
down_revision = "20261008_0014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "challenge_progress",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "owner_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("challenge_key", sa.String(60), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="active"),
        sa.Column("completed_steps", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("completion_count", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("owner_id", "challenge_key", name="uq_challenge_progress_owner_key"),
    )
    op.create_index("ix_challenge_progress_owner_id", "challenge_progress", ["owner_id"])
    op.create_table(
        "challenge_reflections",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "progress_id",
            sa.Uuid(),
            sa.ForeignKey("challenge_progress.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "owner_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("step_index", sa.Integer(), nullable=False),
        sa.Column("response", sa.Text(), nullable=False),
        sa.Column("rating", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("progress_id", "step_index", name="uq_challenge_reflection_step"),
    )
    op.create_index(
        "ix_challenge_reflections_progress_id", "challenge_reflections", ["progress_id"]
    )
    op.create_index("ix_challenge_reflections_owner_id", "challenge_reflections", ["owner_id"])


def downgrade() -> None:
    op.drop_index("ix_challenge_reflections_owner_id", table_name="challenge_reflections")
    op.drop_index("ix_challenge_reflections_progress_id", table_name="challenge_reflections")
    op.drop_table("challenge_reflections")
    op.drop_index("ix_challenge_progress_owner_id", table_name="challenge_progress")
    op.drop_table("challenge_progress")
