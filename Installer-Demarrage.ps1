# Fait démarrer ClaudeScreen à l'ouverture de session : tâche planifiée, sans fenêtre, sans VBScript.
# Installer : powershell -ExecutionPolicy Bypass -File Installer-Demarrage.ps1
# Retirer   : powershell -ExecutionPolicy Bypass -File Installer-Demarrage.ps1 -Retirer
param([switch]$Retirer)
$ErrorActionPreference = 'Stop'
$nom = 'ClaudeScreen'
$utilisateur = "$env:USERDOMAIN\$env:USERNAME"

if ($Retirer) {
    Unregister-ScheduledTask -TaskName $nom -Confirm:$false -ErrorAction SilentlyContinue
    'Démarrage automatique retiré.'
    return
}

# Lecture des PDF : installe Poppler tout de suite (sinon ClaudeScreen le fait à son premier démarrage).
& (Join-Path $PSScriptRoot 'outils\poppler.ps1')

$script = Join-Path $PSScriptRoot 'ClaudeEcran.ps1'
# conhost --headless : lance PowerShell sans aucune fenêtre, même pas un éclair.
$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\conhost.exe" `
    -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File `"$script`"" `
    -WorkingDirectory $PSScriptRoot
# 20 s après l'ouverture de session : la barre des tâches est prête pour l'icône.
$declencheur = New-ScheduledTaskTrigger -AtLogOn -User $utilisateur
$declencheur.Delay = 'PT20S'
$reglages = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $utilisateur -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $nom -Action $action -Trigger $declencheur -Settings $reglages -Principal $principal `
    -Description 'Lance ClaudeScreen (icône Claude dans la zone de notifications).' -Force | Out-Null
"Démarrage automatique installé (tâche planifiée « $nom »)."
