"""Add owner-scoped contact event timelines."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260805_0007"
down_revision: str | None = "20260805_0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "contact_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("owner_id", sa.Uuid(), nullable=False),
        sa.Column("contact_id", sa.Uuid(), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("details", sa.Text(), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("image_url", sa.String(length=2048), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["contact_id"], ["contacts.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["owner_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_contact_events_owner_id", "contact_events", ["owner_id"])
    op.create_index("ix_contact_events_contact_id", "contact_events", ["contact_id"])
    op.create_index("ix_contact_events_occurred_at", "contact_events", ["occurred_at"])


def downgrade() -> None:
    op.drop_index("ix_contact_events_occurred_at", table_name="contact_events")
    op.drop_index("ix_contact_events_contact_id", table_name="contact_events")
    op.drop_index("ix_contact_events_owner_id", table_name="contact_events")
    op.drop_table("contact_events")
