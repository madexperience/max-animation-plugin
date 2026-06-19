"""Development entry point for running the Max animation server inside 3ds Max."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"

if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

from rbx_max_animations.server import start_server  # noqa: E402


server = start_server()
print(f"Roblox Max Animations server listening on {server.server_address[0]}:{server.server_address[1]}")
