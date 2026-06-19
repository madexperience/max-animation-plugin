# Max Companion Plugin

3ds Max side of the Max Animations Plugin.

This package starts a local HTTP server on `127.0.0.1:31337` so the Roblox Studio plugin can connect to 3ds Max.

## Animator Install

1. Download `releases/MaxAnimationsMaxPlugin.zip`.
2. Extract the zip anywhere, for example:

   ```text
   Documents\MaxAnimationsMaxPlugin
   ```

3. Open 3ds Max.
4. Drag `start_max_animations.ms` into the 3ds Max viewport.
5. In Roblox Studio, open `Max Animations` and connect to port `31337`.

Optional persistent install:

1. Drag `install_max_plugin.ms` into the 3ds Max viewport.
2. The installer copies the package into your user Scripts folder.
3. It registers a MacroScript action under the category `Roblox Max Animations`.
4. The server starts immediately after install.

## Current Status

The server and localhost protocol are packaged, but the full rig and animation conversion implementation is still WIP.

Supported now:

- starts the localhost bridge
- responds to `/health`
- responds to `/list_armatures`
- keeps the Studio plugin protocol shape stable

Still WIP:

- full Max rig discovery
- Roblox animation import/export conversion
- polished toolbar/menu UI inside 3ds Max

## Developer Notes

Run from inside 3ds Max Python:

```python
exec(open(r"C:\path\to\max-plugin\start_max_server.py", encoding="utf-8").read())
```
