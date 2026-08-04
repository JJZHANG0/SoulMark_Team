from pathlib import Path

from alembic.config import Config
from alembic.script import ScriptDirectory


def test_alembic_has_single_head() -> None:
    backend_root = Path(__file__).resolve().parents[1]
    config_path = backend_root / "alembic.ini"
    assert config_path.exists(), "Alembic configuration must exist"

    config = Config(config_path)
    script = ScriptDirectory.from_config(config)

    assert len(script.get_heads()) == 1
