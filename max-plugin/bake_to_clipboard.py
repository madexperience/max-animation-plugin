"""Bake the current 3ds Max animation to the Roblox clipboard format."""

from __future__ import annotations

import base64
import ctypes
from pathlib import Path
import sys
from typing import Any
import zlib


ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"

if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

from rbx_max_animations.max_scene import MaxSceneAdapter, rt  # noqa: E402


CF_UNICODETEXT = 13
GMEM_MOVEABLE = 0x0002


def _selected_or_single_armature_name(adapter: MaxSceneAdapter) -> str:
    armatures = adapter.list_armatures()
    if not armatures:
        raise RuntimeError("No exportable Max rig found.")

    armature_by_name = {str(item.get("name")): item for item in armatures if item.get("name")}

    if rt is not None:
        try:
            selected_nodes = list(rt.selection)
        except Exception:
            selected_nodes = []

        for selected_node in selected_nodes:
            node: Any | None = selected_node
            while node is not None:
                try:
                    node_name = str(node.name)
                except Exception:
                    node_name = ""
                if node_name in armature_by_name:
                    return node_name
                try:
                    node = node.parent
                except Exception:
                    node = None

    if len(armatures) == 1:
        return str(armatures[0]["name"])

    for armature in armatures:
        name = str(armature.get("name") or "")
        if name.casefold() == "root":
            print("Multiple rig candidates found; baking 'Root'.")
            return name

    def score_armature(armature: dict[str, Any]) -> tuple[int, int]:
        has_animation = 1 if armature.get("has_animation") else 0
        try:
            num_bones = int(armature.get("num_bones") or 0)
        except Exception:
            num_bones = 0
        return has_animation, num_bones

    selected = max(armatures, key=score_armature)
    selected_name = str(selected.get("name") or "")
    names = ", ".join(sorted(armature_by_name))
    print(f"Multiple rig candidates found; baking '{selected_name}'. Candidates: {names}")
    return selected_name


def _encode_clipboard_payload(payload: bytes) -> str:
    compressed = zlib.compress(payload)
    return base64.b64encode(compressed).decode("ascii")


def _copy_text_to_windows_clipboard(text: str) -> None:
    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32

    kernel32.GlobalAlloc.argtypes = [ctypes.c_uint, ctypes.c_size_t]
    kernel32.GlobalAlloc.restype = ctypes.c_void_p
    kernel32.GlobalLock.argtypes = [ctypes.c_void_p]
    kernel32.GlobalLock.restype = ctypes.c_void_p
    kernel32.GlobalUnlock.argtypes = [ctypes.c_void_p]
    kernel32.GlobalUnlock.restype = ctypes.c_bool
    kernel32.GlobalFree.argtypes = [ctypes.c_void_p]
    kernel32.GlobalFree.restype = ctypes.c_void_p

    user32.OpenClipboard.argtypes = [ctypes.c_void_p]
    user32.OpenClipboard.restype = ctypes.c_bool
    user32.EmptyClipboard.argtypes = []
    user32.EmptyClipboard.restype = ctypes.c_bool
    user32.SetClipboardData.argtypes = [ctypes.c_uint, ctypes.c_void_p]
    user32.SetClipboardData.restype = ctypes.c_void_p
    user32.CloseClipboard.argtypes = []
    user32.CloseClipboard.restype = ctypes.c_bool

    encoded = text.encode("utf-16-le") + b"\x00\x00"
    handle = kernel32.GlobalAlloc(GMEM_MOVEABLE, len(encoded))
    if not handle:
        raise RuntimeError("Could not allocate clipboard memory.")

    locked = kernel32.GlobalLock(handle)
    if not locked:
        kernel32.GlobalFree(handle)
        raise RuntimeError("Could not lock clipboard memory.")

    try:
        ctypes.memmove(locked, encoded, len(encoded))
    finally:
        kernel32.GlobalUnlock(handle)

    if not user32.OpenClipboard(None):
        kernel32.GlobalFree(handle)
        raise RuntimeError("Could not open Windows clipboard.")

    try:
        if not user32.EmptyClipboard():
            raise RuntimeError("Could not clear Windows clipboard.")
        if not user32.SetClipboardData(CF_UNICODETEXT, handle):
            raise RuntimeError("Could not write Windows clipboard data.")
        handle = None
    finally:
        user32.CloseClipboard()
        if handle:
            kernel32.GlobalFree(handle)


def main() -> None:
    adapter = MaxSceneAdapter()
    armature_name = _selected_or_single_armature_name(adapter)
    payload = adapter.export_animation(armature_name)
    clipboard_text = _encode_clipboard_payload(payload)
    _copy_text_to_windows_clipboard(clipboard_text)
    print(
        "Baked Roblox animation to clipboard "
        f"from '{armature_name}' ({len(clipboard_text)} base64 chars)."
    )


if __name__ == "__main__":
    main()
