"""Use the same app/helper locations for every unittest module."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
for folder in (ROOT / "app", ROOT.parent / "BBNotebook"):
    if str(folder) not in sys.path:
        sys.path.insert(0, str(folder))
