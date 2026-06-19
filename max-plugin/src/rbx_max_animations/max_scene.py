"""Thin scene adapter for 3ds Max.

This module intentionally keeps Max API calls isolated. The HTTP layer can be
tested with normal Python, while real scene access is filled in and verified
inside 3ds Max through pymxs.
"""

from __future__ import annotations

from dataclasses import dataclass
from contextlib import contextmanager, nullcontext
import json
import os
from typing import Any


try:
    import pymxs  # type: ignore
    from pymxs import runtime as rt  # type: ignore
except Exception:  # pragma: no cover - pymxs only exists inside 3ds Max.
    pymxs = None
    rt = None


DEFAULT_FPS = 30.0
DEFAULT_SAMPLE_STEP = 1.0
VECTOR_EPSILON = 1e-8


def _as_name(value: Any) -> str:
    try:
        return str(value.name)
    except Exception:
        return str(value)


def _class_name(value: Any) -> str:
    if rt is None:
        return ""
    try:
        return str(rt.classOf(value))
    except Exception:
        return ""


def _super_class_name(value: Any) -> str:
    if rt is None:
        return ""
    try:
        return str(rt.superClassOf(value))
    except Exception:
        return ""


def _parent(node: Any) -> Any | None:
    try:
        return node.parent
    except Exception:
        return None


def _children(node: Any) -> list[Any]:
    try:
        return list(node.children)
    except Exception:
        return []


def _has_transform(node: Any) -> bool:
    try:
        _ = node.transform
        return True
    except Exception:
        return False


def _is_exportable_transform_node(node: Any) -> bool:
    if not _has_transform(node):
        return False

    class_name = _class_name(node).lower()
    super_name = _super_class_name(node).lower()
    blocked = ("camera", "light", "target")
    return not any(token in class_name or token in super_name for token in blocked)


def _looks_like_rig_node(node: Any) -> bool:
    class_name = _class_name(node).lower()
    super_name = _super_class_name(node).lower()
    name = _as_name(node).lower()

    if any(token in class_name for token in ("bone", "biped", "cat", "dummy", "point")):
        return True
    if any(token in super_name for token in ("helper", "shape")):
        return True
    if any(token in name for token in ("bone", "joint", "root", "rig")):
        return True

    return False


def _matrix_inverse(matrix: Any) -> Any:
    if rt is not None:
        try:
            return rt.inverse(matrix)
        except Exception:
            pass
    return matrix.inverse


def _vec_dot(left: tuple[float, float, float], right: tuple[float, float, float]) -> float:
    return left[0] * right[0] + left[1] * right[1] + left[2] * right[2]


def _vec_cross(left: tuple[float, float, float], right: tuple[float, float, float]) -> tuple[float, float, float]:
    return (
        left[1] * right[2] - left[2] * right[1],
        left[2] * right[0] - left[0] * right[2],
        left[0] * right[1] - left[1] * right[0],
    )


def _vec_sub(left: tuple[float, float, float], right: tuple[float, float, float]) -> tuple[float, float, float]:
    return (left[0] - right[0], left[1] - right[1], left[2] - right[2])


def _vec_mul(value: tuple[float, float, float], scalar: float) -> tuple[float, float, float]:
    return (value[0] * scalar, value[1] * scalar, value[2] * scalar)


def _vec_unit(
    value: tuple[float, float, float],
    fallback: tuple[float, float, float],
) -> tuple[float, float, float]:
    length_sq = _vec_dot(value, value)
    if length_sq <= VECTOR_EPSILON:
        return fallback
    inv_length = length_sq ** -0.5
    return (value[0] * inv_length, value[1] * inv_length, value[2] * inv_length)


def _orthonormalize_rows(
    row1: tuple[float, float, float],
    row2: tuple[float, float, float],
    row3: tuple[float, float, float],
) -> tuple[tuple[float, float, float], tuple[float, float, float], tuple[float, float, float]]:
    """Remove Max bone scale/shear so Roblox receives a valid rotation matrix."""

    x_axis = _vec_unit(row1, (1.0, 0.0, 0.0))
    y_axis = _vec_sub(row2, _vec_mul(x_axis, _vec_dot(row2, x_axis)))
    if _vec_dot(y_axis, y_axis) <= VECTOR_EPSILON:
        y_axis = _vec_cross(row3, x_axis)
    y_axis = _vec_unit(y_axis, (0.0, 1.0, 0.0))

    z_axis = _vec_cross(x_axis, y_axis)
    if _vec_dot(z_axis, row3) < 0:
        y_axis = _vec_mul(y_axis, -1.0)
        z_axis = _vec_cross(x_axis, y_axis)
    z_axis = _vec_unit(z_axis, (0.0, 0.0, 1.0))
    return x_axis, y_axis, z_axis


def _matrix_to_components(matrix: Any, unit_scale: float = 1.0) -> list[float]:
    """Convert a Max Matrix3-like value into Roblox CFrame components.

    The Studio importer expects CFrame.new(x, y, z, r00, r01, ... r22).
    Max Matrix3 exposes row vectors. For this first-pass bridge we keep the
    transform in the same local basis and only apply unit scaling to position.
    """

    row1 = matrix.row1
    row2 = matrix.row2
    row3 = matrix.row3
    row4 = matrix.row4
    clean_row1, clean_row2, clean_row3 = _orthonormalize_rows(
        (float(row1.x), float(row1.y), float(row1.z)),
        (float(row2.x), float(row2.y), float(row2.z)),
        (float(row3.x), float(row3.y), float(row3.z)),
    )

    return [
        float(row4.x) * unit_scale,
        float(row4.y) * unit_scale,
        float(row4.z) * unit_scale,
        clean_row1[0],
        clean_row1[1],
        clean_row1[2],
        clean_row2[0],
        clean_row2[1],
        clean_row2[2],
        clean_row3[0],
        clean_row3[1],
        clean_row3[2],
    ]


def _components_to_matrix(components: list[float], unit_scale: float = 1.0) -> Any:
    if rt is None:
        raise RuntimeError("3ds Max runtime is not available.")

    inv_scale = 1.0 / unit_scale if unit_scale else 1.0
    return rt.matrix3(
        rt.point3(components[3], components[4], components[5]),
        rt.point3(components[6], components[7], components[8]),
        rt.point3(components[9], components[10], components[11]),
        rt.point3(components[0] * inv_scale, components[1] * inv_scale, components[2] * inv_scale),
    )


def _frame_to_time(frame: float) -> Any:
    if rt is None:
        return frame

    try:
        return int(round(frame * float(rt.ticksPerFrame)))
    except Exception:
        pass

    try:
        return rt.frameToTime(frame)
    except Exception:
        return frame


def _time_to_frame(time_value: Any) -> float:
    if rt is None:
        return float(time_value)

    try:
        return float(rt.timeToFrame(time_value))
    except Exception:
        pass

    try:
        raw_value = float(time_value)
    except Exception:
        return 0.0

    try:
        zero_time = float(rt.frameToTime(0))
        one_time = float(rt.frameToTime(1))
        frame_delta = one_time - zero_time
        if abs(frame_delta) > 1e-9:
            return (raw_value - zero_time) / frame_delta
    except Exception:
        pass

    try:
        ticks_per_frame = float(rt.ticksPerFrame)
        if abs(ticks_per_frame) > 1e-9:
            return raw_value / ticks_per_frame
    except Exception:
        pass

    return raw_value


@contextmanager
def _time_context(frame: float):
    if rt is None:
        yield
        return

    time_value = _frame_to_time(frame)
    try:
        time_context = pymxs.attime(time_value) if pymxs is not None else None
    except Exception:
        time_context = None

    if time_context is not None:
        with time_context:
            yield
        return

    try:
        previous_time = rt.sliderTime
    except Exception:
        previous_time = None

    try:
        rt.sliderTime = time_value
        yield
    finally:
        if previous_time is not None:
            try:
                rt.sliderTime = previous_time
            except Exception:
                pass


def _animate_context(enabled: bool):
    if pymxs is None:
        return nullcontext()
    try:
        return pymxs.animate(enabled)
    except Exception:
        return nullcontext()


@dataclass
class MaxSceneAdapter:
    """Scene operations required by the Studio protocol."""

    sample_step: float = DEFAULT_SAMPLE_STEP

    def is_available(self) -> bool:
        return rt is not None

    def list_armatures(self) -> list[dict[str, Any]]:
        if rt is None:
            return []

        armatures: list[dict[str, Any]] = []
        seen: set[str] = set()

        for root in self._find_rig_roots():
            nodes = self._collect_rig_nodes(root)
            if not nodes:
                continue

            name = _as_name(root)
            if name in seen:
                continue
            seen.add(name)

            frame_start, frame_end, fps = self._frame_range()
            armatures.append(
                {
                    "name": name,
                    "num_bones": len(nodes),
                    "has_animation": self._has_animation(nodes),
                    "frame_range": [frame_start, frame_end],
                    "fps": fps,
                }
            )

        return armatures

    def get_bone_rest(self, armature_name: str) -> dict[str, Any]:
        root = self._find_root_by_name(armature_name)
        if root is None:
            return {
                "success": False,
                "armature": armature_name,
                "bones": {},
                "error": f"Armature not found: {armature_name}",
            }

        nodes = self._collect_rig_nodes(root)
        rest_locals = self._capture_local_matrices(nodes)
        bones: dict[str, Any] = {}
        for node in nodes:
            name = _as_name(node)
            local_matrix = rest_locals.get(name)
            if local_matrix is None:
                continue
            parent_node = _parent(node)
            bones[name] = {
                "parent": _as_name(parent_node) if parent_node in nodes else None,
                "components": _matrix_to_components(local_matrix, self._unit_scale()),
            }

        return {
            "success": True,
            "armature": armature_name,
            "bones": bones,
        }

    def export_animation(self, armature_name: str, target_bone_rest: Any | None = None) -> bytes:
        if rt is None:
            raise RuntimeError("3ds Max runtime is not available.")

        root = self._find_root_by_name(armature_name)
        if root is None:
            raise ValueError(f"Armature not found: {armature_name}")

        nodes = self._collect_rig_nodes(root)
        if not nodes:
            raise ValueError(f"Armature has no exportable nodes: {armature_name}")

        frame_start, frame_end, fps = self._frame_range()
        if frame_end < frame_start:
            frame_start, frame_end = frame_end, frame_start

        rest_locals = self._capture_local_matrices(nodes, frame_start)
        parent_names = self._parent_names(nodes)
        unit_scale = self._unit_scale()

        keyframes: list[dict[str, Any]] = []
        frame = frame_start
        while frame <= frame_end + 1e-6:
            pose_table: dict[str, Any] = {}
            with _time_context(frame):
                current_locals = self._capture_local_matrices(nodes)
                for node in nodes:
                    name = _as_name(node)
                    current_local = current_locals.get(name)
                    rest_local = rest_locals.get(name)
                    if current_local is None or rest_local is None:
                        continue

                    # Roblox Bone.Transform is the delta applied after the
                    # rest CFrame, so currentLocal = restLocal * delta.
                    delta = _matrix_inverse(rest_local) * current_local
                    pose_table[name] = {
                        "components": _matrix_to_components(delta, unit_scale),
                        "easingStyle": "Linear",
                        "easingDirection": "In",
                    }
                    pose_table[name + "_deform"] = True

            keyframes.append(
                {
                    "t": (frame - frame_start) / fps,
                    "kf": pose_table,
                }
            )
            frame += self.sample_step

        payload = {
            "t": max(0.0, (frame_end - frame_start) / fps),
            "kfs": keyframes,
            "is_deform_rig": True,
            "is_deform_bone_rig": True,
            "bone_hierarchy": parent_names,
            "export_info": {
                "source": "3dsmax",
                "time_unit": "seconds",
                "fps": fps,
                "frame_range": [frame_start, frame_end],
                "sample_step": self.sample_step,
                "format": "max-animation-plugin-json-v1",
                "delta_order": "inverse_rest_times_current",
                "rotation_basis": "orthonormalized_rows",
                "target_bone_rest_received": target_bone_rest is not None,
            },
        }

        return json.dumps(payload, separators=(",", ":")).encode("utf-8")

    def import_animation(self, animation_data: dict[str, Any], target_armature: str | None = None) -> None:
        if rt is None:
            raise RuntimeError("3ds Max runtime is not available.")

        root = self._find_root_by_name(target_armature) if target_armature else self._first_rig_root()
        if root is None:
            raise ValueError("No target armature found.")

        nodes = self._collect_rig_nodes(root)
        node_by_name = {_as_name(node): node for node in nodes}
        rest_locals = self._capture_local_matrices(nodes)
        unit_scale = self._unit_scale()
        fps = self._fps()

        keyframes = animation_data.get("kfs")
        if not isinstance(keyframes, list):
            raise ValueError("Animation payload missing kfs array.")

        with _animate_context(True):
            for keyframe in keyframes:
                if not isinstance(keyframe, dict):
                    continue
                time_seconds = float(keyframe.get("t", 0.0) or 0.0)
                pose_table = keyframe.get("kf")
                if not isinstance(pose_table, dict):
                    continue

                frame = time_seconds * fps
                with _time_context(frame):
                    for name, pose_data in pose_table.items():
                        node = node_by_name.get(str(name))
                        if node is None:
                            continue
                        components = self._pose_components(pose_data)
                        if components is None:
                            continue
                        rest_local = rest_locals.get(str(name))
                        if rest_local is None:
                            continue

                        delta = _components_to_matrix(components, unit_scale)
                        local_matrix = rest_local * delta
                        parent_node = _parent(node)
                        if parent_node in nodes:
                            node.transform = local_matrix * parent_node.transform
                        else:
                            node.transform = local_matrix

    def _all_nodes(self) -> list[Any]:
        if rt is None:
            return []
        try:
            return [node for node in list(rt.objects) if _is_exportable_transform_node(node)]
        except Exception:
            return []

    def _find_rig_roots(self) -> list[Any]:
        nodes = self._all_nodes()
        node_set = set(nodes)
        roots: list[Any] = []

        for node in nodes:
            if not _looks_like_rig_node(node):
                continue
            parent_node = _parent(node)
            if parent_node not in node_set or not _looks_like_rig_node(parent_node):
                collected = self._collect_rig_nodes(node)
                if collected:
                    roots.append(node)

        if roots:
            return roots

        # Fallback for very simple temporary scenes: use selected transform
        # hierarchy, otherwise use top-level transform nodes with children.
        try:
            selected = [node for node in list(rt.selection) if _has_transform(node)]
            if selected:
                return selected
        except Exception:
            pass

        return [node for node in nodes if _parent(node) not in node_set and _children(node)]

    def _first_rig_root(self) -> Any | None:
        roots = self._find_rig_roots()
        return roots[0] if roots else None

    def _find_root_by_name(self, name: str | None) -> Any | None:
        if not name:
            return None
        for root in self._find_rig_roots():
            if _as_name(root) == name:
                return root
        return None

    def _collect_rig_nodes(self, root: Any) -> list[Any]:
        result: list[Any] = []
        seen: set[int] = set()

        def walk(node: Any) -> None:
            node_id = id(node)
            if node_id in seen or not _is_exportable_transform_node(node):
                return
            seen.add(node_id)

            result.append(node)

            for child in _children(node):
                walk(child)

        walk(root)
        return result

    def _capture_local_matrices(self, nodes: list[Any], frame: float | None = None) -> dict[str, Any]:
        context = _time_context(frame) if frame is not None else nullcontext()
        node_set = set(nodes)
        matrices: dict[str, Any] = {}

        with context:
            for node in nodes:
                try:
                    parent_node = _parent(node)
                    world_matrix = node.transform
                    if parent_node in node_set:
                        local_matrix = world_matrix * _matrix_inverse(parent_node.transform)
                    else:
                        local_matrix = world_matrix
                    matrices[_as_name(node)] = local_matrix
                except Exception:
                    continue

        return matrices

    def _parent_names(self, nodes: list[Any]) -> dict[str, str | None]:
        node_set = set(nodes)
        names: dict[str, str | None] = {}
        for node in nodes:
            parent_node = _parent(node)
            names[_as_name(node)] = _as_name(parent_node) if parent_node in node_set else None
        return names

    def _has_animation(self, nodes: list[Any]) -> bool:
        for node in nodes:
            try:
                controller = node.controller
                if controller is not None:
                    return True
            except Exception:
                continue
        return False

    def _frame_range(self) -> tuple[float, float, float]:
        if rt is None:
            return 0.0, 0.0, DEFAULT_FPS

        fps = self._fps()
        try:
            start = float(rt.animationRange.start)
            end = float(rt.animationRange.end)
            try:
                ticks_per_frame = float(rt.ticksPerFrame)
                raw_span = abs(end - start)
                tick_span = raw_span / ticks_per_frame if ticks_per_frame > 0 else 0
                if raw_span >= ticks_per_frame and abs(tick_span - round(tick_span)) < 1e-6:
                    start /= ticks_per_frame
                    end /= ticks_per_frame
            except Exception:
                pass
            return start, end, fps
        except Exception:
            try:
                start = _time_to_frame(rt.animationRange.start)
                end = _time_to_frame(rt.animationRange.end)
                return start, end, fps
            except Exception:
                return 0.0, 0.0, fps

    def _fps(self) -> float:
        if rt is None:
            return DEFAULT_FPS
        try:
            fps = float(rt.frameRate)
            return fps if fps > 0 else DEFAULT_FPS
        except Exception:
            return DEFAULT_FPS

    def _unit_scale(self) -> float:
        raw = os.environ.get("RBX_MAX_UNIT_SCALE", "1")
        try:
            scale = float(raw)
            return scale if scale > 0 else 1.0
        except ValueError:
            return 1.0

    @staticmethod
    def _pose_components(pose_data: Any) -> list[float] | None:
        if isinstance(pose_data, dict):
            components = pose_data.get("components")
        elif isinstance(pose_data, list) and pose_data and isinstance(pose_data[0], list):
            components = pose_data[0]
        else:
            components = pose_data

        if not isinstance(components, list) or len(components) < 12:
            return None

        try:
            return [float(components[i]) for i in range(12)]
        except Exception:
            return None
