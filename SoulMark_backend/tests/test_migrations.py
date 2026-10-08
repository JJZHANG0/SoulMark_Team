import importlib.util
from pathlib import Path
from types import ModuleType

import sqlalchemy as sa
from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.operations import Operations
from alembic.script import ScriptDirectory


def load_tutorial_migration(path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location("user_tutorial_migration", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_alembic_has_single_head() -> None:
    backend_root = Path(__file__).resolve().parents[1]
    config_path = backend_root / "alembic.ini"
    assert config_path.exists(), "Alembic configuration must exist"

    config = Config(config_path)
    script = ScriptDirectory.from_config(config)

    assert len(script.get_heads()) == 1
    assert script.get_current_head() == "20261008_0014"


def test_tutorial_migration_completes_existing_users_and_defaults_new_users() -> None:
    backend_root = Path(__file__).resolve().parents[1]
    migration_path = backend_root / "alembic/versions/20261008_0014_user_tutorial.py"
    assert migration_path.exists(), "tutorial migration must exist"
    migration = load_tutorial_migration(migration_path)

    engine = sa.create_engine("sqlite://")
    with engine.begin() as connection:
        connection.execute(sa.text("CREATE TABLE users (id VARCHAR(36) PRIMARY KEY)"))
        connection.execute(sa.text("INSERT INTO users (id) VALUES ('existing')"))
        migration.op = Operations(MigrationContext.configure(connection))

        migration.upgrade()

        existing = connection.execute(
            sa.text(
                "SELECT tutorial_step, tutorial_completed_at FROM users WHERE id = 'existing'"
            )
        ).one()
        assert existing.tutorial_step == 4
        assert existing.tutorial_completed_at is not None

        connection.execute(sa.text("INSERT INTO users (id) VALUES ('new')"))
        new_user = connection.execute(
            sa.text("SELECT tutorial_step, tutorial_completed_at FROM users WHERE id = 'new'")
        ).one()
        assert new_user.tutorial_step == 0
        assert new_user.tutorial_completed_at is None

        migration.downgrade()
        remaining_columns = {
            column["name"] for column in sa.inspect(connection).get_columns("users")
        }
        assert "tutorial_step" not in remaining_columns
        assert "tutorial_completed_at" not in remaining_columns
