"""Add sequential public IDs for user-facing identity."""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260806_0012"
down_revision: str | None = "20260806_0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("CREATE SEQUENCE user_public_id_seq START WITH 1")
    op.add_column(
        "users",
        sa.Column(
            "public_id",
            sa.Integer(),
            server_default=sa.text("nextval('user_public_id_seq')"),
            nullable=True,
        ),
    )
    op.execute(
        """
        WITH numbered AS (
            SELECT id, row_number() OVER (ORDER BY created_at, id) AS value
            FROM users
        )
        UPDATE users
        SET public_id = numbered.value
        FROM numbered
        WHERE users.id = numbered.id
        """
    )
    op.execute(
        """
        SELECT setval(
            'user_public_id_seq',
            GREATEST(COALESCE((SELECT MAX(public_id) FROM users), 0) + 1, 1),
            false
        )
        """
    )
    op.alter_column("users", "public_id", nullable=False)
    op.create_index("ix_users_public_id", "users", ["public_id"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_users_public_id", table_name="users")
    op.drop_column("users", "public_id")
    op.execute("DROP SEQUENCE user_public_id_seq")
