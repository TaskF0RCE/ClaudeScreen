# Starts ClaudeEcran at logon: scheduled task, no window, no VBScript.
# Install: powershell -ExecutionPolicy Bypass -File Installer-Demarrage.ps1
# Remove : powershell -ExecutionPolicy Bypass -File Installer-Demarrage.ps1 -Retirer
param([switch]$Retirer)
$ErrorActionPreference = 'Stop'
$nom = 'ClaudeEcran'
$utilisateur = "$env:USERDOMAIN\$env:USERNAME"

if ($Retirer) {
    Unregister-ScheduledTask -TaskName $nom -Confirm:$false -ErrorAction SilentlyContinue
    'Autostart removed.'
    return
}

$script = Join-Path $PSScriptRoot 'ClaudeEcran.ps1'
# conhost --headless: starts PowerShell without any window, not even a flash.
$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\conhost.exe" `
    -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File `"$script`"" `
    -WorkingDirectory $PSScriptRoot
# 20 s after logon: the taskbar is ready for the icon.
$declencheur = New-ScheduledTaskTrigger -AtLogOn -User $utilisateur
$declencheur.Delay = 'PT20S'
$reglages = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $utilisateur -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $nom -Action $action -Trigger $declencheur -Settings $reglages -Principal $principal `
    -Description 'Starts ClaudeEcran (Claude icon in the notification area).' -Force | Out-Null
"Autostart installed (scheduled task '$nom')."
