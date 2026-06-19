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
    global MaxAnimations_inspectEntry
    global MaxAnimations_startServer
    global MaxAnimations_bakeClipboard
    global MaxAnimations_bakeFile
    global MaxAnimations_inspectAnimation
    global MaxAnimations_applySettings
    global MaxAnimations_restFrameModeFromSelection

    local Path = dotNetClass "System.IO.Path"
    local Environment = dotNetClass "System.Environment"
    local scriptFile = getSourceFileName()
    local scriptDir = getFilenamePath scriptFile
    MaxAnimations_pythonEntry = Path.Combine scriptDir "start_max_server.py"
    MaxAnimations_bakeEntry = Path.Combine scriptDir "bake_to_clipboard.py"
    MaxAnimations_inspectEntry = Path.Combine scriptDir "inspect_animation.py"

    fn MaxAnimations_restFrameModeFromSelection selection =
    (
        case selection of
        (
            1: "end"
            2: "start"
            3: "current"
            default: "end"
        )
    )

    fn MaxAnimations_applySettings unitScale restFrameMode =
    (
        Environment.SetEnvironmentVariable "RBX_MAX_UNIT_SCALE" (unitScale as string)
        Environment.SetEnvironmentVariable "RBX_MAX_REST_FRAME" restFrameMode
    )

    fn MaxAnimations_startServer unitScale restFrameMode =
    (
        if doesFileExist MaxAnimations_pythonEntry then
        (
            MaxAnimations_applySettings unitScale restFrameMode
            python.ExecuteFile MaxAnimations_pythonEntry
            true
        )
        else
        (
            messageBox ("Could not find start_max_server.py next to:\n" + MaxAnimations_pythonEntry) title:"Max Animations"
            false
        )
    )

    fn MaxAnimations_bakeClipboard unitScale restFrameMode =
    (
        if doesFileExist MaxAnimations_bakeEntry then
        (
            try
            (
                MaxAnimations_applySettings unitScale restFrameMode
                Environment.SetEnvironmentVariable "RBX_MAX_BAKE_OUTPUT" ""
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

    fn MaxAnimations_bakeFile unitScale restFrameMode outputPath =
    (
        if doesFileExist MaxAnimations_bakeEntry then
        (
            try
            (
                MaxAnimations_applySettings unitScale restFrameMode
                Environment.SetEnvironmentVariable "RBX_MAX_BAKE_OUTPUT" outputPath
                python.ExecuteFile MaxAnimations_bakeEntry
                Environment.SetEnvironmentVariable "RBX_MAX_BAKE_OUTPUT" ""
                true
            )
            catch
            (
                Environment.SetEnvironmentVariable "RBX_MAX_BAKE_OUTPUT" ""
                messageBox ("Bake to file failed:\n" + getCurrentException()) title:"Max Animations"
                false
            )
        )
        else
        (
            messageBox ("Could not find bake_to_clipboard.py next to:\n" + MaxAnimations_bakeEntry) title:"Max Animations"
            false
        )
    )

    fn MaxAnimations_inspectAnimation unitScale restFrameMode =
    (
        if doesFileExist MaxAnimations_inspectEntry then
        (
            try
            (
                MaxAnimations_applySettings unitScale restFrameMode
                python.ExecuteFile MaxAnimations_inspectEntry
                true
            )
            catch
            (
                messageBox ("Inspect animation failed:\n" + getCurrentException()) title:"Max Animations"
                false
            )
        )
        else
        (
            messageBox ("Could not find inspect_animation.py next to:\n" + MaxAnimations_inspectEntry) title:"Max Animations"
            false
        )
    )

    try (destroyDialog MaxAnimations_Rollout) catch ()

    rollout MaxAnimations_Rollout "Max Animations" width:460 height:440
    (
        label titleLabel "Roblox Max Animations" align:#center
        label statusLabel "Status: idle" align:#left
        label portLabel "Port: 127.0.0.1:31337" align:#left
        button startButton "Start / Restart Local Server" width:410 height:28 align:#center
        label spacer1 "" height:6
        label directLabel "Direct import: Studio -> Connect -> Import Animation from Max." align:#left
        label directNote "Requires Studio local HTTP permission." align:#left
        label spacer2 "" height:6
        checkbox fullRangeCheckbox "Full Range Bake" checked:true enabled:false align:#left
        spinner unitScaleSpinner "Manual Unit Scale: " range:[0.0001,1000,1] type:#float scale:0.1 fieldwidth:80 align:#left
        dropdownlist restFrameDropdown "Rest Pose: " items:#("End Frame", "Start Frame", "Current Frame") selection:1 width:210 align:#left
        label restFrameNote "Choose the frame that matches the Roblox imported bind pose." align:#left
        button inspectButton "Inspect Animation Data" width:410 height:28 align:#center
        button bakeButton "Bake Animation to Clipboard" width:410 height:28 align:#center
        button bakeFileButton "Bake to File (.rbxanim)" width:410 height:28 align:#center
        label clipboardStatusLabel "Clipboard: idle" align:#left
        label clipLabel1 "Clipboard import: bake here, then Studio Legacy Import -> Clipboard." align:#left
        label clipLabel2 "File import: Studio Legacy Import -> Import Animation from File(s)." align:#left
        label clipLabel3 "Clipboard import: paste the copied text into the opened Studio script." align:#left
        label spacer3 "" height:6
        label noteLabel "Select the rig root in Max when multiple rigs are in the scene." align:#left

        on MaxAnimations_Rollout open do
        (
            if MaxAnimations_startServer unitScaleSpinner.value (MaxAnimations_restFrameModeFromSelection restFrameDropdown.selection) then
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
            if MaxAnimations_startServer unitScaleSpinner.value (MaxAnimations_restFrameModeFromSelection restFrameDropdown.selection) then
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
            if MaxAnimations_bakeClipboard unitScaleSpinner.value (MaxAnimations_restFrameModeFromSelection restFrameDropdown.selection) then
            (
                clipboardStatusLabel.text = "Clipboard: baked animation copied"
            )
            else
            (
                clipboardStatusLabel.text = "Clipboard: bake failed"
            )
        )

        on unitScaleSpinner changed value do
        (
            MaxAnimations_applySettings value (MaxAnimations_restFrameModeFromSelection restFrameDropdown.selection)
        )

        on restFrameDropdown selected itemIndex do
        (
            MaxAnimations_applySettings unitScaleSpinner.value (MaxAnimations_restFrameModeFromSelection itemIndex)
        )

        on inspectButton pressed do
        (
            if MaxAnimations_inspectAnimation unitScaleSpinner.value (MaxAnimations_restFrameModeFromSelection restFrameDropdown.selection) then
            (
                clipboardStatusLabel.text = "Inspect: see Max Listener"
            )
            else
            (
                clipboardStatusLabel.text = "Inspect: failed"
            )
        )

        on bakeFileButton pressed do
        (
            local outputPath = getSaveFileName caption:"Bake Roblox Animation" filename:"animation.rbxanim" types:"Roblox Animation (*.rbxanim)|*.rbxanim|All Files (*.*)|*.*|"
            if outputPath != undefined then
            (
                if MaxAnimations_bakeFile unitScaleSpinner.value (MaxAnimations_restFrameModeFromSelection restFrameDropdown.selection) outputPath then
                (
                    clipboardStatusLabel.text = "File: baked animation saved"
                )
                else
                (
                    clipboardStatusLabel.text = "File: bake failed"
                )
            )
        )
    )

    createDialog MaxAnimations_Rollout style:#(#style_titlebar, #style_sysmenu, #style_minimizebox)
)
