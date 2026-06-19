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
- responds to `/health`
- responds to `/list_armatures` with rig names, bone counts, and frame range
- exports sampled Max transform animation as Studio-compatible JSON
- imports Studio animation payloads back onto matching Max nodes
- keeps the Studio plugin protocol shape stable

Still WIP:

- polished Biped/CAT/custom rig validation
- axis/unit calibration presets for production rigs
- curve tangent/easing preservation beyond linear keyframes

## Export From Max To Studio

### Option A: Clipboard bake

Use this when Studio HTTP/local network access is disabled or unreliable.

1. In 3ds Max, make sure the animated rig node names match the Roblox rig part or bone names.
2. Start `start_max_animations.ms`.
3. Select the rig root in Max if the scene has multiple rigs. If nothing is selected, the baker prefers a rig named `Root`.
4. Click `Bake Animation to Clipboard`.
5. In Roblox Studio, select the target rig.
6. Open `Max Animations`.
7. In `Legacy Import`, click `Import Animation from Clipboard`.
8. Paste the copied text into the opened Studio script.

### Option B: Direct localhost import

Use this when Studio has local HTTP/plugin network access enabled.

1. In 3ds Max, make sure the animated rig node names match the Roblox rig part or bone names.
2. Start the companion server with `start_max_animations.ms` and keep the `Max Animations` window open.
3. In Roblox Studio, select the target rig.
4. Open `Max Animations`.
5. Connect to port `31337`.
6. Select the Max armature.
7. Click `Import Animation from Max`.

The bridge samples the active Max animation range at one key per frame. Set the scene animation range before exporting.

If position scale is wrong, set the environment variable `RBX_MAX_UNIT_SCALE` before starting 3ds Max. The default is `1`.

## Developer Notes

Run from inside 3ds Max Python:

```python
exec(open(r"C:\path\to\max-plugin\start_max_server.py", encoding="utf-8").read())
```
