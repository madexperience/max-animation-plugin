/*
    Starts the Roblox Max Animations companion server from this folder.

    Usage:
    - Extract the Max plugin package.
    - Drag this file into the 3ds Max viewport, or run it from Scripting > Run Script.
*/

(
    global MaxAnimations_Rollout
    global MaxAnimations_pythonEntry
    global MaxAnimations_startServer

    local Path = dotNetClass "System.IO.Path"
    local scriptFile = getSourceFileName()
    local scriptDir = getFilenamePath scriptFile
    MaxAnimations_pythonEntry = Path.Combine scriptDir "start_max_server.py"

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

    try (destroyDialog MaxAnimations_Rollout) catch ()

    rollout MaxAnimations_Rollout "Max Animations" width:420 height:230
    (
        label titleLabel "Roblox Max Animations" align:#center
        label statusLabel "Status: idle" align:#left
        label portLabel "Port: 127.0.0.1:31337" align:#left
        button startButton "Start / Restart Local Server" width:370 height:28 align:#center
        label spacer1 "" height:6
        label flowLabel1 "Export is triggered from Roblox Studio." align:#left
        label flowLabel2 "1. Keep this Max scene open." align:#left
        label flowLabel3 "2. In Studio, select the rig and open Max Animations." align:#left
        label flowLabel4 "3. Click Connect, then Import Animation from Max." align:#left
        label spacer2 "" height:6
        label noteLabel "This window only runs the local bridge; Studio pulls the animation." align:#left

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
    )

    createDialog MaxAnimations_Rollout style:#(#style_titlebar, #style_sysmenu, #style_minimizebox)
)
