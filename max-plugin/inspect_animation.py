"""Print sampled 3ds Max animation diagnostics for the selected rig."""

from __future__ import annotations

import json
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"

if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

for module_name in list(sys.modules):
    if module_name == "rbx_max_animations" or module_name.startswith("rbx_max_animations."):
        del sys.modules[module_name]

from rbx_max_animations.max_scene import MaxSceneAdapter, _node_handle, rt  # noqa: E402


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
            return name

    return str(max(armatures, key=lambda item: int(item.get("num_bones") or 0)).get("name") or "")


def _controller_name(controller: Any) -> str:
    if controller is None:
        return "<none>"
    if rt is not None:
        try:
            return str(rt.classOf(controller))
        except Exception:
            pass
    return type(controller).__name__


def _controller_key_count(controller: Any) -> int | None:
    if controller is None:
        return None
    if rt is not None:
        try:
            return int(rt.numKeys(controller))
        except Exception:
            pass
    try:
        return len(list(controller.keys))
    except Exception:
        return None


def _controller_for(node: Any, prop_name: str) -> Any | None:
    if rt is not None:
        keys: list[Any] = [prop_name, f"#{prop_name}"]
        try:
            keys.append(rt.Name(prop_name))
        except Exception:
            pass
        for key in keys:
            try:
                controller = rt.getPropertyController(node, key)
                if controller is not None:
                    return controller
            except Exception:
                pass

    try:
        value = getattr(node, prop_name)
        return getattr(value, "controller", None)
    except Exception:
        return None


def _component_signature(pose_data: Any) -> tuple[float, ...]:
    components = pose_data.get("components") if isinstance(pose_data, dict) else pose_data
    if not isinstance(components, list):
        return ()
    return tuple(round(float(value), 4) for value in components[:12])


def _node_name(node: Any) -> str:
    try:
        return str(node.name)
    except Exception:
        return "<unnamed>"


def _node_parent_name(node: Any) -> str:
    try:
        parent = node.parent
        return str(parent.name) if parent is not None else "<none>"
    except Exception:
        return "<none>"


def _node_class_name(node: Any) -> str:
    if rt is not None:
        try:
            return str(rt.classOf(node))
        except Exception:
            pass
    return type(node).__name__


def _matrix_signature(matrix: Any) -> tuple[float, ...]:
    rows = (matrix.row1, matrix.row2, matrix.row3, matrix.row4)
    values: list[float] = []
    for row in rows:
        values.extend((float(row.x), float(row.y), float(row.z)))
    return tuple(round(value, 4) for value in values)


def _controller_parts(node: Any) -> list[str]:
    parts = _controller_parts_from_maxscript(node)
    if parts:
        return parts

    parts: list[str] = []
    for prop_name in ("transform", "position", "rotation", "scale"):
        controller = _controller_for(node, prop_name)
        key_count = _controller_key_count(controller)
        if controller is not None or key_count:
            parts.append(f"{prop_name}={_controller_name(controller)} keys={key_count if key_count is not None else '?'}")
    return parts


def _controller_parts_from_maxscript(node: Any) -> list[str]:
    if rt is None:
        return []

    handle = _node_handle(node)
    if handle is None:
        return []

    expression = f"""
    (
        local n = maxOps.getNodeByHandle {handle}
        local parts = #()
        fn countControllerKeys ctrl =
        (
            local total = 0
            if ctrl != undefined do
            (
                try (total += numKeys ctrl) catch ()
                local subCount = 0
                try (subCount = numSubs ctrl) catch ()
                for index = 1 to subCount do
                (
                    local subAnim = undefined
                    try (subAnim = getSubAnim ctrl index) catch ()
                    if subAnim != undefined do
                    (
                        local subController = undefined
                        try (subController = subAnim.controller) catch ()
                        if subController != undefined do total += countControllerKeys subController
                    )
                )
            )
            total
        )
        fn appendController label ctrl =
        (
            if ctrl != undefined do
            (
                local keyCount = countControllerKeys ctrl
                if keyCount > 0 do append parts (label + "=" + ((classOf ctrl) as string) + " keys=" + (keyCount as string))
            )
        )
        if n != undefined do
        (
            appendController "transform" n.controller
            appendController "position" n.position.controller
            appendController "rotation" n.rotation.controller
            appendController "scale" n.scale.controller
        )
        parts
    )
    """

    try:
        return [str(part) for part in list(rt.execute(expression))]
    except Exception:
        return []


def _print_controller_summary(adapter: MaxSceneAdapter, armature_name: str) -> None:
    root = adapter._find_root_by_name(armature_name)
    if root is None:
        return

    nodes = adapter._collect_rig_nodes(root)
    print("Controller key summary:")
    for node in nodes:
        node_name = _node_name(node)
        parts = _controller_parts(node)
        print(f"  {node_name}: " + ("; ".join(parts) if parts else "no direct controller keys detected"))


def _print_scene_motion_summary(adapter: MaxSceneAdapter) -> None:
    nodes = adapter._all_nodes()
    frame_start, frame_end, _fps = adapter._frame_range()
    if frame_end < frame_start:
        frame_start, frame_end = frame_end, frame_start

    frames: list[float] = []
    frame = frame_start
    step = max(float(adapter.sample_step or 1.0), 1.0)
    while frame <= frame_end + 1e-6:
        frames.append(frame)
        frame += step

    moving_nodes: list[tuple[str, int, list[int], str, str]] = []
    jump_nodes: list[tuple[str, int, list[int], str, str]] = []
    keyed_nodes: list[tuple[str, str, str, str]] = []

    for node in nodes:
        signatures: list[tuple[float, ...]] = []
        for sample_frame in frames:
            matrices = adapter._capture_local_matrices([node], sample_frame)
            matrix = matrices.get(_node_name(node))
            if matrix is not None:
                signatures.append(_matrix_signature(matrix))

        unique_count = len(set(signatures))
        change_frames = [index for index in range(1, len(signatures)) if signatures[index] != signatures[index - 1]]
        node_info = (_node_name(node), unique_count, change_frames, _node_parent_name(node), _node_class_name(node))
        if unique_count > 2:
            moving_nodes.append(node_info)
        elif unique_count == 2:
            jump_nodes.append(node_info)

        parts = _controller_parts(node)
        if parts:
            keyed_nodes.append((_node_name(node), _node_parent_name(node), _node_class_name(node), "; ".join(parts)))

    print("Scene-wide motion scan:")
    print(f"  Sampled transform nodes: {len(nodes)}")
    print("  Nodes with animated transforms (>2 unique poses):")
    if moving_nodes:
        for name, unique_count, change_frames, parent_name, class_name in moving_nodes[:30]:
            print(
                f"    {name}: unique poses={unique_count}, "
                f"change frames={change_frames[:8]}{'...' if len(change_frames) > 8 else ''}, "
                f"parent={parent_name}, class={class_name}"
            )
    else:
        print("    <none>")

    print("  Nodes with only a frame-1 jump:")
    if jump_nodes:
        for name, unique_count, change_frames, parent_name, class_name in jump_nodes[:30]:
            print(
                f"    {name}: unique poses={unique_count}, "
                f"change frames={change_frames[:8]}{'...' if len(change_frames) > 8 else ''}, "
                f"parent={parent_name}, class={class_name}"
            )
    else:
        print("    <none>")

    print("  Nodes with direct controller keys:")
    if keyed_nodes:
        for name, parent_name, class_name, controller_text in keyed_nodes[:30]:
            print(f"    {name}: parent={parent_name}, class={class_name}; {controller_text}")
    else:
        print("    <none>")


def main() -> None:
    adapter = MaxSceneAdapter()
    armature_name = _selected_or_single_armature_name(adapter)
    payload = adapter.export_animation(armature_name)
    data = json.loads(payload.decode("utf-8"))
    keyframes = data.get("kfs") if isinstance(data.get("kfs"), list) else []
    export_info = data.get("export_info") if isinstance(data.get("export_info"), dict) else {}
    frame_range = export_info.get("frame_range")
    fps = export_info.get("fps")
    rest_frame = export_info.get("rest_frame")
    rest_frame_source = export_info.get("rest_frame_source")

    print("=== Max Animation Inspect ===")
    print(f"Rig: {armature_name}")
    print(f"Duration: {float(data.get('t') or 0.0):.3f}s")
    print(f"Keyframes sampled: {len(keyframes)}")
    print(f"Frame range: {frame_range} @ {fps} fps")
    if rest_frame is not None:
        print(f"Rest pose frame: {rest_frame} ({rest_frame_source or 'unknown'})")

    if not keyframes:
        print("No sampled keyframes.")
        return

    first_pose_table = keyframes[0].get("kf") if isinstance(keyframes[0], dict) else {}
    names = sorted(name for name in first_pose_table if isinstance(name, str) and not name.endswith("_deform"))
    low_motion_nodes: list[str] = []
    for name in names:
        signatures: list[tuple[float, ...]] = []
        for keyframe in keyframes:
            pose_table = keyframe.get("kf") if isinstance(keyframe, dict) else {}
            if isinstance(pose_table, dict) and name in pose_table:
                signatures.append(_component_signature(pose_table[name]))
        unique_count = len(set(signatures))
        change_frames = [index for index in range(1, len(signatures)) if signatures[index] != signatures[index - 1]]
        if 0 < unique_count <= 2 and len(keyframes) > 2:
            low_motion_nodes.append(name)
        print(
            f"  {name}: unique poses={unique_count}, "
            f"change frames={change_frames[:8]}{'...' if len(change_frames) > 8 else ''}"
        )

    if len(low_motion_nodes) == len(names):
        print(
            "Warning: every sampled node has only one or two unique poses. "
            "This usually means the Max range is correct, but the animated keys are not on these exported nodes "
            "or Max is evaluating only the start/end pose for this rig."
        )

    _print_controller_summary(adapter, armature_name)
    _print_scene_motion_summary(adapter)
    print("=== End Max Animation Inspect ===")


if __name__ == "__main__":
    main()
