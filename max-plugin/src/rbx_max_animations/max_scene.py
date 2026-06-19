"""Thin scene adapter for 3ds Max.

This module intentionally keeps Max API calls isolated. The HTTP layer can be
tested with normal Python, while real scene access is filled in and verified
inside 3ds Max through pymxs.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


try:
    from pymxs import runtime as rt  # type: ignore
except Exception:  # pragma: no cover - pymxs only exists inside 3ds Max.
    rt = None


@dataclass
class MaxSceneAdapter:
    """Scene operations required by the Studio protocol."""

    def is_available(self) -> bool:
        return rt is not None

    def list_armatures(self) -> list[str]:
        if rt is None:
            return []

        # Conservative first pass: report named root bones. Biped, CAT, and
        # custom rig support should be expanded once we test inside 3ds Max.
        armatures: list[str] = []
        for obj in list(rt.objects):
            try:
                parent = obj.parent
                class_name = str(rt.classOf(obj))
                if parent is None and ("Bone" in class_name or "Biped" in class_name):
                    armatures.append(str(obj.name))
            except Exception:
                continue
        return armatures

    def get_bone_rest(self, armature_name: str) -> dict[str, Any]:
        return {
            "success": True,
            "armature": armature_name,
            "bones": {},
        }

    def export_animation(self, armature_name: str, target_bone_rest: Any | None = None) -> bytes:
        raise NotImplementedError("Max animation export is not implemented yet.")

    def import_animation(self, animation_data: dict[str, Any], target_armature: str | None = None) -> None:
        raise NotImplementedError("Max animation import is not implemented yet.")
