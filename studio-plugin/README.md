# Studio Plugin

Roblox Studio side of the Max Animations Plugin.

This source is a Max-oriented port of the Studio plugin from Cautioned's animation workflow. The UI, tabs, saved animation flow, upload flow, and localhost sync shape are kept close to the upstream plugin while the companion app target changes from Blender to 3ds Max.

## Status

The Studio plugin source is now present in this repository.

Implemented in this folder:

- `MaxAnimationsInternal` Studio plugin source
- Max-labeled Player, Rigging, Tools, and More tabs
- Max sync service names and UI copy
- localhost HTTP client still using the existing endpoint protocol
- vendored Fusion dependency for build-without-Wally packaging
- Rojo project file for packaging/syncing the plugin source

Still WIP:

- full 3ds Max rig conversion
- full animation conversion validation
- final release automation
- installer automation

## Animator Install

Animators should not need Rojo, Wally, or Rokit.

1. Download `MaxAnimationsPlugin.rbxm` from the GitHub release.
2. Copy it into Studio's local plugins folder:

   ```powershell
   $plugins = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
   New-Item -ItemType Directory -Force $plugins
   Copy-Item .\MaxAnimationsPlugin.rbxm $plugins\MaxAnimationsPlugin.rbxm -Force
   ```

3. Restart Roblox Studio.
4. Open the `Max Animations` toolbar button.
5. Run the 3ds Max companion server, then connect on port `31337`.

## Source Dependencies

Runtime dependencies are vendored so the plugin can be built without Wally.

Current vendored dependency:

```toml
Fusion = "elttob/fusion@0.2.0"
```

Location:

```text
studio-plugin/vendor/Fusion
```

Promise is not required by the current runtime source. If a future port step introduces Promise usage, add it only when the call site exists.

`wally.toml` is kept only as an update reference for developers. The default Rojo project files do not require `wally install`.

## Build / Sync

With Rojo installed:

```powershell
rokit install
cd studio-plugin
rojo build plugin.project.json -o MaxAnimationsPlugin.rbxm
```

For development, you can also use Rojo sync:

```powershell
cd studio-plugin
rojo serve default.project.json
```

Then connect from Roblox Studio with the Rojo plugin.

## Developer Local Plugin Install Flow

1. Build `MaxAnimationsPlugin.rbxm` with `rojo build plugin.project.json -o MaxAnimationsPlugin.rbxm`.
2. Copy the generated model into Studio's local plugins folder:

   ```powershell
   $plugins = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
   New-Item -ItemType Directory -Force $plugins
   Copy-Item .\MaxAnimationsPlugin.rbxm $plugins\MaxAnimationsPlugin.rbxm -Force
   ```

3. Restart or reload local plugins.
4. Open the `Max Animations` toolbar button.
5. Run the 3ds Max companion server, then connect on port `31337`.

The plugin uses `HttpService:RequestAsync()` to talk to `localhost`, so Studio must allow local HTTP/plugin network requests when prompted.

## Runtime Protocol

The Studio plugin still expects the existing localhost endpoints:

- `GET /list_armatures`
- `GET /get_bone_rest/{armature}`
- `GET /export_animation/{armature}`
- `POST /export_animation/{armature}`
- `POST /import_animation`
- `GET /animation_status`

See `docs/protocol.md` in the repository root for the payload shape.
