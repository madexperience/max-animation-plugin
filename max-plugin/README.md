# Max Companion Plugin

3ds Max side of the Max Animations Plugin.

This package can either start a local HTTP server on `127.0.0.1:31337` or bake the current Max animation to the clipboard.

## Animator Install

1. Download `releases/MaxAnimationsMaxPlugin.zip`.
2. Extract the zip anywhere, for example:

   ```text
   Documents\MaxAnimationsMaxPlugin
   ```

3. Open 3ds Max.
4. Drag `start_max_animations.ms` into the 3ds Max viewport.
5. Keep the `Max Animations` window open.
6. In Roblox Studio, open `Max Animations`.

Optional persistent install:

1. Drag `install_max_plugin.ms` into the 3ds Max viewport.
2. The installer copies the package into your user Scripts folder.
3. It registers a MacroScript action under the category `Roblox Max Animations`.
4. The server starts immediately after install.

## Current Status

The server, localhost protocol, and first-pass transform animation bridge are packaged.

Supported now:

- starts the localhost bridge
- shows a small 3ds Max launcher/status window
- bakes sampled Max animation data to the clipboard in the same compressed base64 format used by the Blender workflow
- bakes sampled Max animation data to `.rbxanim` files
- exposes Full Range Bake and Manual Unit Scale controls in the Max launcher
- restarts the localhost bridge without keeping stale Python exporter modules alive
- responds to `/health`
- responds to `/list_armatures` with rig names, bone counts, and frame range
- exports sampled Max transform animation as Studio-compatible JSON
- imports Studio animation payloads back onto matching Max nodes
- keeps the Studio plugin protocol shape stable

Still WIP:

- polished Biped/CAT/custom rig validation
- automatic target-rig deform scale calibration for clipboard-only exports
- curve tangent/easing preservation beyond linear keyframes
- Roblox account login and UGC emote validation

## Export From Max To Studio

### Option A: Clipboard bake

Use this when Studio HTTP/local network access is disabled or unreliable.

1. In 3ds Max, make sure the animated rig node names match the Roblox rig part or bone names.
2. Start `start_max_animations.ms`.
3. Select the rig root in Max if the scene has multiple rigs. If nothing is selected, the baker prefers a rig named `Root`.
4. Leave `Full Range Bake` on. The baker uses the active 3ds Max animation range.
5. If the imported motion scale is wrong, adjust `Manual Unit Scale` and bake again.
6. Click `Bake Animation to Clipboard`.
7. In Roblox Studio, select the target rig.
8. Open `Max Animations`.
9. In `Legacy Import`, click `Import Animation from Clipboard`.
10. Paste the copied text into the opened Studio script.

### Option B: File bake

Use this when the clipboard payload is too large or you want a reusable file.

1. In 3ds Max, set the animation range and select the rig root if needed.
2. Click `Bake to File (.rbxanim)`.
3. In Roblox Studio, select the target rig.
4. Open `Max Animations`.
5. In `Legacy Import`, click `Import Animation from File(s)`.
6. Select the saved `.rbxanim` file.

### Option C: Direct localhost import

Use this when Studio has local HTTP/plugin network access enabled.

1. In 3ds Max, make sure the animated rig node names match the Roblox rig part or bone names.
2. Start the companion server with `start_max_animations.ms` and keep the `Max Animations` window open.
3. If the imported motion scale is wrong, adjust `Manual Unit Scale`, then click `Start / Restart Local Server`.
4. In Roblox Studio, select the target rig.
5. Open `Max Animations`.
6. Connect to port `31337`.
7. Select the Max armature.
8. Click `Import Animation from Max`.

The bridge samples the active Max animation range at one key per frame. Set the scene animation range before exporting.

After baking, the 3ds Max Listener should report a useful range, for example:

```text
Baked Roblox animation to clipboard from 'Root' (31 keyframes, 1.000s, frames 0.000-30.000, ... base64 chars).
```

If it reports `1 keyframes` or `0.000s`, check the 3ds Max animation range and make sure you are running the newest package.

If position scale is wrong, change `Manual Unit Scale` in the Max launcher before baking or restarting the local server. The default is `1`.

## Blender Feature Parity Notes

The Max plugin ports the Blender addon workflow where Max exposes equivalent APIs:

- Start Server: supported.
- Full Range Bake: supported through the active 3ds Max animation range.
- Bake Clipboard: supported.
- Bake to File: supported.
- Auto Deform Scale: partially supported by `Manual Unit Scale`; automatic target-rig calibration is only available through direct localhost imports.
- Apply Object Transform: not yet implemented as a separate Max operation.
- Import from `.fbx`: use 3ds Max's native FBX import for now.
- Roblox Account / UGC Emote Validation: not implemented in the Max companion.

## Developer Notes

Run from inside 3ds Max Python:

```python
exec(open(r"C:\path\to\max-plugin\start_max_server.py", encoding="utf-8").read())
```
