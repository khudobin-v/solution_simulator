import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "server"))

from main import app  # noqa: F401, E402
