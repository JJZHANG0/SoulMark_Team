"""Add explainable relationship strength dimensions and event impacts."""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260806_0008"
down_revision: str | None = "20260805_0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    for column_name in (
        "trust_score",
        "emotional_depth_score",
        "reciprocity_score",
        "support_score",
    ):
        op.add_column(
            "contacts",
            sa.Column(column_name, sa.Integer(), nullable=False, server_default="50"),
        )
        op.execute(
            sa.text(
                f"UPDATE contacts SET {column_name} = strength"  # noqa: S608
            )
        )

    for column_name in (
        "trust_delta",
        "emotional_depth_delta",
        "reciprocity_delta",
        "support_delta",
        "strength_delta",
    ):
        op.add_column(
            "contact_events",
            sa.Column(column_name, sa.Integer(), nullable=False, server_default="0"),
        )
    op.add_column(
        "contact_events",
        sa.Column("impact_explanation", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("contact_events", "impact_explanation")
    for column_name in (
        "strength_delta",
        "support_delta",
        "reciprocity_delta",
        "emotional_depth_delta",
        "trust_delta",
    ):
        op.drop_column("contact_events", column_name)
    for column_name in (
        "support_score",
        "reciprocity_score",
        "emotional_depth_score",
        "trust_score",
    ):
        op.drop_column("contacts", column_name)
