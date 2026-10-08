import importlib.util
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations


def test_growth_migration_backfills_and_downgrades():
    path = Path(__file__).parents[1] / "alembic/versions/20261008_0013_growth_experience.py"
    assert path.exists()
    spec = importlib.util.spec_from_file_location("growth_migration", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    engine = sa.create_engine("sqlite://")
    metadata = sa.MetaData()
    users = sa.Table("users", metadata, sa.Column("id", sa.Uuid, primary_key=True))
    reviews = sa.Table(
        "conversation_reviews",
        metadata,
        sa.Column("id", sa.Uuid),
        sa.Column("owner_id", sa.Uuid),
        sa.Column("created_at", sa.DateTime(timezone=True)),
    )
    practices = sa.Table(
        "practice_sessions",
        metadata,
        sa.Column("id", sa.Uuid),
        sa.Column("owner_id", sa.Uuid),
        sa.Column("created_at", sa.DateTime(timezone=True)),
        sa.Column("user_transcript", sa.Text),
        sa.Column("assistant_transcript", sa.Text),
    )
    metadata.create_all(engine)
    owner = uuid4()
    now = datetime(2026, 1, 1, tzinfo=UTC)
    with engine.begin() as conn:
        conn.execute(users.insert(), {"id": owner})
        conn.execute(
            reviews.insert(),
            [{"id": uuid4(), "owner_id": owner, "created_at": now} for _ in range(2)],
        )
        conn.execute(
            practices.insert(),
            [
                {
                    "id": uuid4(),
                    "owner_id": owner,
                    "created_at": now,
                    "user_transcript": "hello",
                    "assistant_transcript": "hi",
                }
                for _ in range(12)
            ],
        )
        conn.execute(
            practices.insert(),
            {
                "id": uuid4(),
                "owner_id": owner,
                "created_at": now,
                "user_transcript": "",
                "assistant_transcript": "hi",
            },
        )
        with Operations.context(MigrationContext.configure(conn)):
            module.upgrade()
            growth = sa.Table("user_growth", sa.MetaData(), autoload_with=conn)
            row = conn.execute(sa.select(growth)).mappings().one()
            assert row["balance"] == 110
            assert row["peak_level"] == 2
            assert row["last_active_date"].year >= 2026
            assert conn.scalar(sa.text("select count(*) from experience_events")) == 14
            module.downgrade()
            assert "user_growth" not in sa.inspect(conn).get_table_names()
