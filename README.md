# Roblox Max Animations Plugin

## License

This project is free and open source under `GPL-3.0-or-later`.

It is a 3ds Max companion workflow inspired by the open-source `Cautioned/Blender-Animations-Plugin` project. See [NOTICE.md](NOTICE.md) for attribution and third-party dependency notices.

## Roblox Studio Plugin Installation

Use this when you only need to install the Roblox Studio plugin.

1. Download [MaxAnimationsPlugin.rbxm](releases/MaxAnimationsPlugin.rbxm).
2. Copy `MaxAnimationsPlugin.rbxm` into your local Roblox plugins folder:

   ```powershell
   $plugins = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
   New-Item -ItemType Directory -Force $plugins
   Copy-Item .\releases\MaxAnimationsPlugin.rbxm $plugins\MaxAnimationsPlugin.rbxm -Force
   ```

3. Restart Roblox Studio, or reload local plugins.
4. Open the `Plugins` tab.
5. Click `Max Animations`.

The Studio plugin includes its Lua dependencies statically, so animators do not need Wally, Rokit, Rojo, or a repository clone to install it.

## 3ds Max Plugin Installation

Use this when you only need to install the 3ds Max companion plugin.

1. Download [MaxAnimationsMaxPlugin.zip](releases/MaxAnimationsMaxPlugin.zip).
2. Extract the zip anywhere on your machine.
3. Start 3ds Max.
4. Drag `start_max_animations.ms` from the extracted folder into the 3ds Max viewport.
5. The `Max Animations` window should open and start listening on `127.0.0.1:31337`.

For repeated use, drag `install_max_plugin.ms` into the 3ds Max viewport once. It copies the companion files to your user scripts folder and registers a `Roblox Max Animations` MacroScript action.

Typical animation import flow:

1. Import the same FBX model into Roblox Studio and 3ds Max.
2. In 3ds Max, select the rig root if the scene has multiple rigs.
3. Set the 3ds Max animation range.
4. In the Max companion window, keep `Rest Pose` set to the frame that matches the Roblox imported bind pose.
5. Click `Bake Animation to Clipboard`.
6. In Roblox Studio, select the target rig.
7. In `Max Animations`, use `Legacy Import` -> `Import Animation from Clipboard`.
