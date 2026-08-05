"""Add detailed advice to conversation reviews."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260805_0006"
down_revision: str | None = "20260804_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "conversation_reviews",
        sa.Column(
            "detailed_advice",
            sa.Text(),
            nullable=False,
            server_default="暂无详细建议。",
        ),
    )
    op.alter_column("conversation_reviews", "detailed_advice", server_default=None)


def downgrade() -> None:
    op.drop_column("conversation_reviews", "detailed_advice")
