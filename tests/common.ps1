# Helpers shared by the scenarios. Dot-sourced inside the app, just before the scenario.
# Claude Code is never started: Demarrer-Claude only records how it would have been called.
$Claude = Join-Path $env:WINDIR 'System32\whoami.exe'   # any existing program: the app only checks that it exists
$global:Appels = @()
function Demarrer-Claude([string]$modele, [string]$nom, [string]$options) { $global:Appels += "$modele|$nom|$options"; $script:Proc = $null }
function Sans-Duree([string]$t) { ($t -replace '^(\[\w+), \d+ s\]', '$1]') -replace '(\(code \d+, \w+), \d+ s\)', '$1)' }
function Faux-Proc([int]$code) { [pscustomobject]@{ ExitCode = $code; HasExited = $true } | Add-Member ScriptMethod Dispose { } -PassThru }
# A task folder as Capturer makes it, without any screenshot. -SansMcp: as if the PC control tool had not started.
function Fausse-Capture([switch]$SansMcp) {
    $run = Join-Path $Runs ('test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force (Join-Path $run 'images'), (Join-Path $run 'prompts'), (Join-Path $run 'responses') | Out-Null
    if (-not $SansMcp) { [IO.File]::WriteAllText((Join-Path $run 'mcp-started.txt'), '') }
    @{ Run = $run; Png = (Join-Path $run 'images\screenshot-01.png'); Fenetre = @('notepad', 'Test'); Hwnd = [IntPtr]::Zero
       Rect = (New-Object System.Drawing.Rectangle 0, 0, 1920, 1080); Largeur = 1398; Hauteur = 787 }
}
function Lire-Prompt($capture, [string]$nom = 'task') { [IO.File]::ReadAllText((Join-Path $capture.Run "prompts\$nom.txt"), [Text.Encoding]::UTF8) }
function Ecrire-Reponse($capture, [string]$texte, [string]$nom = 'task') {
    [IO.File]::WriteAllText((Join-Path $capture.Run "responses\$nom.txt"), $texte, (New-Object System.Text.UTF8Encoding $false))
}
