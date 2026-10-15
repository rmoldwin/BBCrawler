"""Shared file locations for commands, generators and notebook helpers."""
from pathlib import Path
import json

APP = Path(__file__).resolve().parent
ROOT = APP.parent
SQL = ROOT / "sql"
LOCAL = ROOT / "local"
COMPANION = ROOT.parent / "BBNotebook"
CHART = ROOT.parent / "CancerPathCHART"
DEFAULT_CONFIG = ROOT / "config.json"


def load_config(path: str | Path = DEFAULT_CONFIG) -> dict:
    """Resolve saved file paths beside the settings file, not the working folder."""
    path = Path(path).resolve()
    with path.open(encoding="utf-8") as stream:
        config = json.load(stream)
    for key in ("db_path", "auth_state_path"):
        value = Path(config[key])
        config[key] = str(value if value.is_absolute() else path.parent / value)
    return config
