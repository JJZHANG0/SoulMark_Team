"""Track relationship impacts applied automatically by saved reviews."""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260806_0010"
down_revision: str | None = "20260806_0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "review_relationship_impacts",
        sa.Column("review_id", sa.Uuid(), nullable=False),
        sa.Column("contact_id", sa.Uuid(), nullable=False),
        sa.Column("owner_id", sa.Uuid(), nullable=False),
        sa.Column("trust_delta", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("emotional_depth_delta", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("reciprocity_delta", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("support_delta", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("strength_delta", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("explanation", sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(
            ["review_id"],
            ["conversation_reviews.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(["contact_id"], ["contacts.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["owner_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("review_id", "contact_id"),
    )
    op.create_index(
        "ix_review_relationship_impacts_owner_id",
        "review_relationship_impacts",
        ["owner_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_review_relationship_impacts_owner_id",
        table_name="review_relationship_impacts",
    )
    op.drop_table("review_relationship_impacts")
