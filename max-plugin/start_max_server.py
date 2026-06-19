"""Development entry point for running the Max animation server inside 3ds Max."""

import builtins
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"

if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))


SERVER_KEY = "_rbx_max_animations_server"
existing_server = getattr(builtins, SERVER_KEY, None)

if existing_server is not None:
    try:
        existing_server.shutdown()
        existing_server.server_close()
        print("Roblox Max Animations server stopped for restart.")
    except Exception as exc:
        print(f"Warning: could not stop existing Roblox Max Animations server: {exc}")
    finally:
        setattr(builtins, SERVER_KEY, None)

# 3ds Max keeps one Python interpreter alive for the session. Reload our
# package so replacing the plugin files does not keep using an older exporter.
for module_name in list(sys.modules):
    if module_name == "rbx_max_animations" or module_name.startswith("rbx_max_animations."):
        del sys.modules[module_name]

from rbx_max_animations.server import start_server  # noqa: E402


server = start_server()
setattr(builtins, SERVER_KEY, server)
if existing_server is None:
    print(f"Roblox Max Animations server listening on {server.server_address[0]}:{server.server_address[1]}")
else:
    print(f"Roblox Max Animations server restarted on {server.server_address[0]}:{server.server_address[1]}")
