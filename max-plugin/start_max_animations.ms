/*
    Starts the Roblox Max Animations companion server from this folder.

    Usage:
    - Extract the Max plugin package.
    - Drag this file into the 3ds Max viewport, or run it from Scripting > Run Script.
*/

(
    local Path = dotNetClass "System.IO.Path"
    local scriptFile = getSourceFileName()
    local scriptDir = getFilenamePath scriptFile
    local pythonEntry = Path.Combine scriptDir "start_max_server.py"

    if doesFileExist pythonEntry then
    (
        python.ExecuteFile pythonEntry
    )
    else
    (
        messageBox ("Could not find start_max_server.py next to:\n" + scriptFile) title:"Max Animations"
    )
)
