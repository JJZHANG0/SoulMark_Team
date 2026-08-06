"""Require ten timeline events before calculating intimacy."""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260806_0011"
down_revision: str | None = "20260806_0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "contacts",
        sa.Column("event_count", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "contacts",
        sa.Column(
            "intimacy_calculated",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.execute(
        """
        UPDATE contacts
        SET event_count = (
            SELECT count(*) FROM contact_events
            WHERE contact_events.contact_id = contacts.id
        ),
        strength = 0,
        trust_score = 0,
        emotional_depth_score = 0,
        reciprocity_score = 0,
        support_score = 0,
        intimacy_calculated = false
        """
    )


def downgrade() -> None:
    op.drop_column("contacts", "intimacy_calculated")
    op.drop_column("contacts", "event_count")
