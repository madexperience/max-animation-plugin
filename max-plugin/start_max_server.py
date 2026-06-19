"""Development entry point for running the Max animation server inside 3ds Max."""

import builtins
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"

if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

from rbx_max_animations.server import start_server  # noqa: E402


SERVER_KEY = "_rbx_max_animations_server"
server = getattr(builtins, SERVER_KEY, None)

if server is None:
    server = start_server()
    setattr(builtins, SERVER_KEY, server)
    print(f"Roblox Max Animations server listening on {server.server_address[0]}:{server.server_address[1]}")
else:
    print(f"Roblox Max Animations server already running on {server.server_address[0]}:{server.server_address[1]}")
