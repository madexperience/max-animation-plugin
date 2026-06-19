/*
    Starts the Roblox Max Animations companion server from this folder.

    Usage:
    - Extract the Max plugin package.
    - Drag this file into the 3ds Max viewport, or run it from Scripting > Run Script.
*/

(
    global MaxAnimations_Rollout
    global MaxAnimations_pythonEntry
    global MaxAnimations_bakeEntry
    global MaxAnimations_startServer
    global MaxAnimations_bakeClipboard

    local Path = dotNetClass "System.IO.Path"
    local scriptFile = getSourceFileName()
    local scriptDir = getFilenamePath scriptFile
    MaxAnimations_pythonEntry = Path.Combine scriptDir "start_max_server.py"
    MaxAnimations_bakeEntry = Path.Combine scriptDir "bake_to_clipboard.py"

    fn MaxAnimations_startServer =
    (
        if doesFileExist MaxAnimations_pythonEntry then
        (
            python.ExecuteFile MaxAnimations_pythonEntry
            true
        )
        else
        (
            messageBox ("Could not find start_max_server.py next to:\n" + MaxAnimations_pythonEntry) title:"Max Animations"
            false
        )
    )

    fn MaxAnimations_bakeClipboard =
    (
        if doesFileExist MaxAnimations_bakeEntry then
        (
            try
            (
                python.ExecuteFile MaxAnimations_bakeEntry
                true
            )
            catch
            (
                messageBox ("Bake to clipboard failed:\n" + getCurrentException()) title:"Max Animations"
                false
            )
        )
        else
        (
            messageBox ("Could not find bake_to_clipboard.py next to:\n" + MaxAnimations_bakeEntry) title:"Max Animations"
            false
        )
    )

    try (destroyDialog MaxAnimations_Rollout) catch ()

    rollout MaxAnimations_Rollout "Max Animations" width:440 height:300
    (
        label titleLabel "Roblox Max Animations" align:#center
        label statusLabel "Status: idle" align:#left
        label portLabel "Port: 127.0.0.1:31337" align:#left
        button startButton "Start / Restart Local Server" width:390 height:28 align:#center
        label spacer1 "" height:6
        label directLabel "Direct import: Studio -> Connect -> Import Animation from Max." align:#left
        label directNote "Requires Studio local HTTP permission." align:#left
        label spacer2 "" height:6
        button bakeButton "Bake Animation to Clipboard" width:390 height:28 align:#center
        label clipboardStatusLabel "Clipboard: idle" align:#left
        label clipLabel1 "Clipboard import: bake here, then Studio Legacy Import -> Clipboard." align:#left
        label clipLabel2 "Paste the copied text into the opened Studio script." align:#left
        label spacer3 "" height:6
        label noteLabel "Select the rig root in Max when multiple rigs are in the scene." align:#left

        on MaxAnimations_Rollout open do
        (
            if MaxAnimations_startServer() then
            (
                statusLabel.text = "Status: listening on localhost"
            )
            else
            (
                statusLabel.text = "Status: failed to start"
            )
        )

        on startButton pressed do
        (
            if MaxAnimations_startServer() then
            (
                statusLabel.text = "Status: listening on localhost"
            )
            else
            (
                statusLabel.text = "Status: failed to start"
            )
        )

        on bakeButton pressed do
        (
            if MaxAnimations_bakeClipboard() then
            (
                clipboardStatusLabel.text = "Clipboard: baked animation copied"
            )
            else
            (
                clipboardStatusLabel.text = "Clipboard: bake failed"
            )
        )
    )

    createDialog MaxAnimations_Rollout style:#(#style_titlebar, #style_sysmenu, #style_minimizebox)
)
