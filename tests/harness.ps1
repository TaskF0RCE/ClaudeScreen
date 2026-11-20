# Runs the real ClaudeScreen.ps1 in a sandbox ($Bac): its own app folder, its own "Documents", no tray icon,
# no hotkeys, no message loop, a fake Recycle Bin ($Bac\bin). The scenario ($Corps) is dot-sourced where
# Application.Run() was, so it sees every variable and function of the app.
# It works by replacing a few exact lines of ClaudeScreen.ps1: if one of them changes, the error names it.
param([string]$Bac, [string]$Corps, [string]$Avant)
$ErrorActionPreference = 'Stop'
$global:Echecs = 0
$global:Tests = 0
function global:Verifier([string]$nom, [bool]$ok, [string]$detail = '') {
    $global:Tests++
    if ($ok) { "  ok    $nom" } else { $global:Echecs++; "  FAIL  $nom  $detail" }
}
$app = Join-Path $Bac 'app'
$docs = Join-Path $Bac 'docs'
$global:FauxBac = Join-Path $Bac 'bin'
$commun = Join-Path $PSScriptRoot 'common.ps1'
$src = [IO.File]::ReadAllText((Join-Path $app 'ClaudeScreen.ps1'), [Text.Encoding]::UTF8)
function Remplacer([string]$ancien, [string]$nouveau) {
    $n = ([regex]::Matches($script:src, [regex]::Escape($ancien))).Count
    if ($n -ne 1) { throw "tests\harness.ps1: $n occurrence(s) in ClaudeScreen.ps1 of: $ancien" }
    $script:src = $script:src.Replace($ancien, $nouveau)
}
Remplacer "`$mutex = New-Object System.Threading.Mutex(`$false, 'Local\ClaudeScreen')" ''
Remplacer 'if (-not $mutex.WaitOne(0)) { exit }' ''
Remplacer '$mutex.ReleaseMutex()' ''
Remplacer '$Racine = $PSScriptRoot' "`$Racine = '$app'"
# Claude Code's transcripts: a folder of the sandbox, never the real ~\.claude.
Remplacer "`$ProjetsClaude = Join-Path `$env:USERPROFILE '.claude\projects'" "`$ProjetsClaude = '$Bac\claude-projects'"
Remplacer "[Environment]::GetFolderPath('MyDocuments')" "'$docs'"
Remplacer 'if (-not (Test-Poppler)) {' 'if ($false) {'
Remplacer '$icone.Visible = $true' '$icone.Visible = $false'
Remplacer '$raccourcis = New-Object ClaudeScreen.Raccourcis' '$raccourcis = [pscustomobject]@{ Handle = 0; SurAppui = $null } | Add-Member ScriptMethod Enregistrer { $false } -PassThru | Add-Member ScriptMethod Liberer { } -PassThru | Add-Member ScriptMethod DestroyHandle { } -PassThru'
# "Sent to the Recycle Bin" = moved to the sandbox's own bin folder.
Remplacer ". (Join-Path `$Outils 'memoire.ps1')" ". (Join-Path `$Outils 'memoire.ps1'); function Send-Corbeille([string]`$chemin) { Move-Item -LiteralPath `$chemin (Join-Path `$global:FauxBac ((Split-Path `$chemin -Leaf) + '.' + [guid]::NewGuid().ToString('N').Substring(0, 6))) }"
Remplacer '[System.Windows.Forms.Application]::Run()' ". '$commun'; . '$Corps'"
if ($Avant) { . $Avant }
. ([scriptblock]::Create($src))
'--- log'
Get-Content (Join-Path $app 'data\log.txt') -Encoding UTF8
"=== $($global:Tests) checks, $($global:Echecs) failure(s)"
exit $global:Echecs
