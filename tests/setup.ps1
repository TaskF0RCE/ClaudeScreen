# The installer (installer\Build-Setup.ps1, installer\Setup.cs): built, then run silently into a temporary
# folder with /NoStart, so no scheduled task is made and the app is not started.
# -Complet (CI only, never on your own PC): also runs a whole install, which replaces the scheduled task
# "ClaudeScreen" of the machine and starts the app, then removes it.
param([string]$Bac, [switch]$Complet)
$ErrorActionPreference = 'Stop'
$depot = Split-Path $PSScriptRoot -Parent
$tests = 0; $echecs = 0
function Verifier([string]$nom, [bool]$ok, [string]$detail = '') {
    $script:tests++
    if ($ok) { "  ok    $nom" } else { $script:echecs++; "  FAIL  $nom  $detail" }
}
function Installer([string]$dossier) {
    $p = Start-Process $exe -ArgumentList '/S', '/NoStart', "/D=`"$dossier`"" -Wait -PassThru
    $p.ExitCode
}
try {
    $exe = Join-Path $Bac 'ClaudeScreen-Setup.exe'
    $sortie = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $depot 'installer\Build-Setup.ps1') -Sortie $exe 2>&1
    Verifier 'the Setup is built' ($LASTEXITCODE -eq 0 -and (Test-Path $exe)) ($sortie -join ' ')
    $version = (Get-Content (Join-Path $depot '.release-please-manifest.json') -Raw | ConvertFrom-Json).'.'
    Verifier 'it carries the version of the release' ((Get-Item $exe).VersionInfo.FileVersion -eq "$version.0") (Get-Item $exe).VersionInfo.FileVersion

    $cible = Join-Path $Bac 'install here\ClaudeScreen'
    Verifier 'first install: done' ((Installer $cible) -eq 0)
    $manque = @('ClaudeScreen.ps1', 'Installer-Demarrage.ps1', 'LICENSE', 'outils\mcp.ps1', 'outils\natif.cs', 'outils\garde.ps1', 'outils\deroule.ps1', 'contexts\Default.md', 'examples\packet-tracer.md') |
        Where-Object { -not (Test-Path (Join-Path $cible $_)) }
    Verifier 'the files of the app are there' (-not $manque) ($manque -join ', ')
    Verifier 'same content as the repository' ((Get-FileHash (Join-Path $cible 'ClaudeScreen.ps1')).Hash -eq (Get-FileHash (Join-Path $depot 'ClaudeScreen.ps1')).Hash)
    Verifier 'no tests, no macOS/Linux port, no git folder' (-not (Test-Path (Join-Path $cible 'tests')) -and -not (Test-Path (Join-Path $cible 'linux-macos')) -and -not (Test-Path (Join-Path $cible '.git')) -and -not (Test-Path (Join-Path $cible 'installer')))
    Verifier '/NoStart: no settings written, the app was not started' (-not (Test-Path (Join-Path $cible 'data')))

    # An update: the user's data and an old file of the app are left alone, the app files are replaced.
    New-Item -ItemType Directory -Force (Join-Path $cible 'data\runs\20261113-161334') | Out-Null
    [IO.File]::WriteAllText((Join-Path $cible 'data\memory.txt'), 'off')
    [IO.File]::WriteAllText((Join-Path $cible 'data\runs\20261113-161334\result.txt'), 'kept')
    [IO.File]::WriteAllText((Join-Path $cible 'outils\old-tool.ps1'), 'from an older version')
    [IO.File]::WriteAllText((Join-Path $cible 'ClaudeScreen.ps1'), 'old version')
    Verifier 'update: done' ((Installer $cible) -eq 0)
    Verifier 'update: the app is replaced' ((Get-FileHash (Join-Path $cible 'ClaudeScreen.ps1')).Hash -eq (Get-FileHash (Join-Path $depot 'ClaudeScreen.ps1')).Hash)
    Verifier 'update: settings and tasks are kept, nothing is deleted' ((Get-Content (Join-Path $cible 'data\memory.txt') -Raw) -eq 'off' -and (Test-Path (Join-Path $cible 'data\runs\20261113-161334\result.txt')) -and (Test-Path (Join-Path $cible 'outils\old-tool.ps1')))

    # A copy made with git is left to git.
    $clone = Join-Path $Bac 'clone'
    New-Item -ItemType Directory -Force (Join-Path $clone '.git') | Out-Null
    Verifier 'a git copy is refused and left untouched' ((Installer $clone) -eq 2 -and -not (Test-Path (Join-Path $clone 'ClaudeScreen.ps1')))
    if ($Complet) {
        $entier = Join-Path $Bac "whole install\it's here"
        $p = Start-Process $exe -ArgumentList '/S', "/D=`"$entier`"" -Wait -PassThru
        Verifier 'whole install: done' ($p.ExitCode -eq 0) "exit code $($p.ExitCode)"
        $tache = Get-ScheduledTask -TaskName ClaudeScreen -ErrorAction SilentlyContinue
        Verifier 'whole install: the scheduled task starts the app of that folder' ($tache -and $tache.Actions[0].Arguments -like "*$entier\ClaudeScreen.ps1*") "$($tache.Actions[0].Arguments)"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $entier 'Installer-Demarrage.ps1') -Retirer | Out-Null
        Verifier 'removed again' (-not (Get-ScheduledTask -TaskName ClaudeScreen -ErrorAction SilentlyContinue))
    } else { '  skip  whole install with the scheduled task (-SetupComplet, CI only)' }
} catch { Verifier 'the test ran to the end' $false ($_.Exception.Message + ' ' + $_.InvocationInfo.PositionMessage) }
"=== $tests checks, $echecs failure(s)"
exit $echecs
