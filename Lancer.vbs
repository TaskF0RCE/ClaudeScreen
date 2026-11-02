' Starts ClaudeScreen without any window (only the icon in the notification area).
Set fso = CreateObject("Scripting.FileSystemObject")
dossier = fso.GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & dossier & "\ClaudeScreen.ps1""", 0, False
