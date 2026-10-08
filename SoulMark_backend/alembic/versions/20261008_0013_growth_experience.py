"""Persist growth rewards and backfill historical activities once."""

from collections import defaultdict
from datetime import UTC, datetime
from uuid import uuid4
from zoneinfo import ZoneInfo

import sqlalchemy as sa

from alembic import op

revision = "20261008_0013"
down_revision = "20260806_0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_growth",
        sa.Column(
            "owner_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
        ),
        sa.Column("balance", sa.Integer(), nullable=False),
        sa.Column("peak_level", sa.Integer(), nullable=False),
        sa.Column("last_active_date", sa.Date(), nullable=False),
        sa.Column("decay_settled_through", sa.Date(), nullable=False),
        sa.CheckConstraint("balance >= 0", name="ck_growth_balance"),
    )
    op.create_table(
        "experience_events",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "owner_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("event_key", sa.String(160), nullable=False),
        sa.Column("kind", sa.String(20), nullable=False),
        sa.Column("delta", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("source_id", sa.Uuid(), nullable=True),
        sa.Column("request_hash", sa.String(64), nullable=True),
        sa.UniqueConstraint("owner_id", "event_key", name="uq_experience_event"),
    )
    op.create_index("ix_experience_events_owner_id", "experience_events", ["owner_id"])
    conn = op.get_bind()
    growth = sa.table(
        "user_growth",
        sa.column("owner_id", sa.Uuid()),
        sa.column("balance", sa.Integer()),
        sa.column("peak_level", sa.Integer()),
        sa.column("last_active_date", sa.Date()),
        sa.column("decay_settled_through", sa.Date()),
    )
    events = sa.table(
        "experience_events",
        sa.column("id", sa.Uuid()),
        sa.column("owner_id", sa.Uuid()),
        sa.column("event_key"),
        sa.column("kind"),
        sa.column("delta"),
        sa.column("created_at", sa.DateTime(timezone=True)),
        sa.column("source_id", sa.Uuid()),
    )
    users = sa.table("users", sa.column("id", sa.Uuid()))
    totals = defaultdict(int)
    daily = defaultdict(int)
    zone = ZoneInfo("Asia/Singapore")
    today = datetime.now(UTC).astimezone(zone).date()
    for table_name, kind in [("conversation_reviews", "review"), ("practice_sessions", "practice")]:
        columns = [
            sa.column("id", sa.Uuid()),
            sa.column("owner_id", sa.Uuid()),
            sa.column("created_at", sa.DateTime(timezone=True)),
        ]
        if kind == "practice":
            columns += [sa.column("user_transcript"), sa.column("assistant_transcript")]
        table = sa.table(table_name, *columns)
        for row in conn.execute(
            sa.select(table).order_by(table.c.created_at, table.c.id)
        ).mappings():
            amount = 30
            if kind == "practice":
                if (
                    not (row["user_transcript"] or "").strip()
                    or not (row["assistant_transcript"] or "").strip()
                ):
                    continue
                stamp = row["created_at"]
                if stamp.tzinfo is None:
                    stamp = stamp.replace(tzinfo=UTC)
                key = (row["owner_id"], stamp.astimezone(zone).date())
                amount = min(5, 50 - daily[key])
                daily[key] += amount
            totals[row["owner_id"]] += amount
            conn.execute(
                events.insert().values(
                    id=uuid4(),
                    owner_id=row["owner_id"],
                    event_key=f"legacy:{kind}:{row['id']}",
                    kind=kind,
                    delta=amount,
                    created_at=row["created_at"],
                    source_id=row["id"],
                )
            )
    for owner in conn.scalars(sa.select(users.c.id)):
        total = totals[owner]
        level = 1
        while 25 * level * (level + 3) <= total:
            level += 1
        conn.execute(
            growth.insert().values(
                owner_id=owner,
                balance=total,
                peak_level=level,
                last_active_date=today,
                decay_settled_through=today,
            )
        )


def downgrade() -> None:
    op.drop_index("ix_experience_events_owner_id", table_name="experience_events")
    op.drop_table("experience_events")
    op.drop_table("user_growth")
