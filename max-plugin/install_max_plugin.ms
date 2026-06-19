/*
    Installs the Roblox Max Animations companion plugin for the current user.

    Usage:
    - Extract the Max plugin package.
    - Drag this file into the 3ds Max viewport, or run it from Scripting > Run Script.
*/

(
    fn combinePath left right =
    (
        (dotNetClass "System.IO.Path").Combine left right
    )

    fn copyDirectory sourceDir targetDir =
    (
        local Directory = dotNetClass "System.IO.Directory"
        local File = dotNetClass "System.IO.File"
        local Path = dotNetClass "System.IO.Path"

        if not (Directory.Exists targetDir) do
        (
            Directory.CreateDirectory targetDir
        )

        for filePath in Directory.GetFiles sourceDir do
        (
            local fileName = Path.GetFileName filePath
            File.Copy filePath (Path.Combine targetDir fileName) true
        )

        for childDir in Directory.GetDirectories sourceDir do
        (
            local childName = Path.GetFileName childDir
            copyDirectory childDir (Path.Combine targetDir childName)
        )
    )

    fn quotePathForMaxScript value =
    (
        substituteString value "\"" "\\\""
    )

    local sourceFile = getSourceFileName()
    local sourceDir = getFilenamePath sourceFile
    local userScriptsDir = getDir #userScripts
    local installDir = combinePath userScriptsDir "MaxAnimationsPlugin"

    copyDirectory sourceDir installDir

    local launcherPath = combinePath installDir "start_max_animations.ms"
    local pythonEntry = combinePath installDir "start_max_server.py"

    local userMacrosDir = try (getDir #userMacros) catch (undefined)
    if userMacrosDir == undefined do userMacrosDir = userScriptsDir

    local macroPath = combinePath userMacrosDir "MaxAnimations_StartServer.mcr"
    local macroFile = createFile macroPath
    format "macroScript MaxAnimations_StartServer\n" to:macroFile
    format "category:\"Roblox Max Animations\"\n" to:macroFile
    format "toolTip:\"Start Roblox Max Animations Server\"\n" to:macroFile
    format "buttonText:\"Max Animations\"\n" to:macroFile
    format "(\n" to:macroFile
    format "    on execute do\n" to:macroFile
    format "    (\n" to:macroFile
    format "        local scriptPath = @\"%\"\n" (quotePathForMaxScript launcherPath) to:macroFile
    format "        if doesFileExist scriptPath then\n" to:macroFile
    format "        (\n" to:macroFile
    format "            fileIn scriptPath\n" to:macroFile
    format "        )\n" to:macroFile
    format "        else\n" to:macroFile
    format "        (\n" to:macroFile
    format "            messageBox \"Could not find the Max Animations launcher script.\" title:\"Max Animations\"\n" to:macroFile
    format "        )\n" to:macroFile
    format "    )\n" to:macroFile
    format ")\n" to:macroFile
    close macroFile

    fileIn macroPath

    if doesFileExist pythonEntry then
    (
        fileIn launcherPath
        messageBox ("Max Animations installed.\n\nInstalled to:\n" + installDir + "\n\nThe server has been started. In future sessions, run the action under category:\nRoblox Max Animations") title:"Max Animations"
    )
    else
    (
        messageBox ("Install finished, but start_max_server.py was not found at:\n" + pythonEntry) title:"Max Animations"
    )
)
