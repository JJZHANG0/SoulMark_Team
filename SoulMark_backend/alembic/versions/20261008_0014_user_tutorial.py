"""Persist four-step new-user tutorial progress."""

from datetime import UTC, datetime

import sqlalchemy as sa

from alembic import op

revision = "20261008_0014"
down_revision = "20261008_0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "tutorial_step",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.add_column(
        "users",
        sa.Column("tutorial_completed_at", sa.DateTime(timezone=True), nullable=True),
    )

    users = sa.table(
        "users",
        sa.column("tutorial_step", sa.Integer()),
        sa.column("tutorial_completed_at", sa.DateTime(timezone=True)),
    )
    op.get_bind().execute(
        users.update().values(
            tutorial_step=4,
            tutorial_completed_at=datetime.now(UTC),
        )
    )


def downgrade() -> None:
    op.drop_column("users", "tutorial_completed_at")
    op.drop_column("users", "tutorial_step")
