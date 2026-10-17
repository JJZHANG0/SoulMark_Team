"""Weekly self page and evidence rows."""

import sqlalchemy as sa

from alembic import op

revision = "20261016_0016"
down_revision = "20261015_0015"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "self_pages",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "owner_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("week_start", sa.Date(), nullable=False),
        sa.Column("who_text", sa.Text(), nullable=True),
        sa.Column("pursuit_text", sa.Text(), nullable=True),
        sa.Column("fear_text", sa.Text(), nullable=True),
        sa.Column("pattern_1_text", sa.Text(), nullable=True),
        sa.Column("pattern_2_text", sa.Text(), nullable=True),
        sa.Column("pattern_3_text", sa.Text(), nullable=True),
        sa.Column("blind_spot_text", sa.Text(), nullable=True),
        sa.Column("weekly_step_text", sa.Text(), nullable=True),
        sa.Column("weekly_step_completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("paused_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("owner_id", "week_start", name="uq_self_pages_owner_week"),
    )
    op.create_index("ix_self_pages_owner_id", "self_pages", ["owner_id"])
    op.create_table(
        "self_evidence",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "page_id",
            sa.Uuid(),
            sa.ForeignKey("self_pages.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "owner_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("slot", sa.String(20), nullable=False),
        sa.Column("source_type", sa.String(40), nullable=False),
        sa.Column("source_id", sa.Uuid(), nullable=True),
        sa.Column("quote", sa.Text(), nullable=False),
        sa.Column("detail", sa.Text(), nullable=False),
        sa.Column("occurred_on", sa.Date(), nullable=False),
        sa.Column("confirmed", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_self_evidence_page_id", "self_evidence", ["page_id"])
    op.create_index("ix_self_evidence_owner_id", "self_evidence", ["owner_id"])


def downgrade() -> None:
    op.drop_index("ix_self_evidence_owner_id", table_name="self_evidence")
    op.drop_index("ix_self_evidence_page_id", table_name="self_evidence")
    op.drop_table("self_evidence")
    op.drop_index("ix_self_pages_owner_id", table_name="self_pages")
    op.drop_table("self_pages")
