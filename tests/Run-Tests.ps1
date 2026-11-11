# Runs the whole test suite. Nothing touches your real folders, your screen or Claude: every scenario gets its
# own copy of the app and its own fake "Documents" in a temporary folder, deleted at the end.
#   powershell -ExecutionPolicy Bypass -File tests\Run-Tests.ps1
#   -Seul upgrade      run one scenario only (file name in tests\scenarios, without .ps1; or guard, mcp)
#   -SansEcran         skip the one check that takes a real screenshot (used by the CI)
#   -Garder            keep the temporary folder, to look at what a scenario left
param([string]$Seul, [switch]$SansEcran, [switch]$Garder)
$ErrorActionPreference = 'Stop'
$depot = Split-Path $PSScriptRoot -Parent
$base = Join-Path ([IO.Path]::GetTempPath()) ('claudescreen-tests-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$modele = Join-Path $base 'modele'
$utf8Bom = New-Object System.Text.UTF8Encoding $true

# The app as a user has it: scripts, tools, contexts, examples. natif.cs is compiled once here.
New-Item -ItemType Directory -Force (Join-Path $modele 'outils') | Out-Null
Copy-Item (Join-Path $depot 'ClaudeScreen.ps1') $modele
Copy-Item (Join-Path $depot 'outils\*') (Join-Path $modele 'outils') -Include *.ps1, *.cs, *.md
Copy-Item (Join-Path $depot 'contexts'), (Join-Path $depot 'examples') $modele -Recurse
& powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ". '$modele\outils\natif.ps1'"
if ($LASTEXITCODE -ne 0) { throw 'natif.cs does not compile' }

# Documents of a user coming from an old version: Claude-Travail, notes at the end of instructions.md.
$ancienInstructions = @'
<!--
Standing instructions for Claude (optional): write them below this comment, one per line.
They are added to every task (Ctrl+Alt+C or Ctrl+Alt+Shift+C).

Keep the dashed line below. What you write above it is yours: it is never changed.
Below it, Claude writes its notes while "Persistent memory" is checked in the icon menu;
they are erased when you uncheck it.
-->


---------------------
<!-- Claude's notes (persistent memory): erased when the mode is turned off. -->
- User writes reports in Word; report for client Dupont in progress
- Budget sheet 2026: columns A to F checked on 09/11
- Lab 3: routers R0 to R3 configured, PCs not addressed yet
'@

function Nouveau-Bac([string]$nom, [string]$documents) {
    $bac = Join-Path $base $nom
    New-Item -ItemType Directory -Force (Join-Path $bac 'docs'), (Join-Path $bac 'bin') | Out-Null
    Copy-Item $modele (Join-Path $bac 'app') -Recurse
    New-Item -ItemType Directory -Force (Join-Path $bac 'app\data') | Out-Null
    if ($documents -eq 'ancien') {
        $ctx = Join-Path $bac 'docs\Claude-Travail\System-Context'
        New-Item -ItemType Directory -Force $ctx | Out-Null
        [IO.File]::WriteAllText((Join-Path $ctx 'instructions.md'), ($ancienInstructions -replace '\r?\n', "`r`n"), $utf8Bom)
        [IO.File]::WriteAllText((Join-Path $ctx 'README.md'), 'old guide', $utf8Bom)
        [IO.File]::WriteAllText((Join-Path $bac 'docs\Claude-Travail\report.txt'), 'a file made by Claude earlier')
        [IO.File]::WriteAllText((Join-Path $bac 'app\data\memory.txt'), 'on')
    } elseif ($documents -eq 'txt') {
        $ctx = Join-Path $bac 'docs\Claude-Travail\System-Context'
        New-Item -ItemType Directory -Force $ctx | Out-Null
        [IO.File]::WriteAllText((Join-Path $ctx 'instructions.txt'), "# Lines starting with # are ignored.`r`n# Example -- one`r`nAlways answer briefly.`r`n")
    }
    $bac
}

$total = 0; $echecs = 0
function Lancer([string]$titre, [string]$fichier, [string[]]$arguments) {
    "##### $titre"
    $sortie = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fichier @arguments 2>&1
    $code = $LASTEXITCODE
    $sortie | Where-Object { "$_" -match '^\s*(FAIL|skip)\b|^=== ' -or $code -ne 0 -and "$_" -notmatch '^\s*ok\b' } | ForEach-Object { "  $_" }
    $bilan = $sortie | Where-Object { "$_" -match '^=== (\d+) checks, (\d+) failure' } | Select-Object -Last 1
    if ("$bilan" -match '^=== (\d+) checks, (\d+) failure') { $script:total += [int]$Matches[1]; $script:echecs += [int]$Matches[2] }
    else { $script:total++; $script:echecs++; '  FAIL  the test did not run to the end' }
}

$harnais = Join-Path $PSScriptRoot 'harness.ps1'
$scenarios = @(
    @('upgrade', 'ancien', $null), @('fresh', 'vide', $null), @('old-txt', 'txt', $null),
    @('locked', 'ancien', 'locked-before.ps1'), @('contexts-terminal', 'vide', $null), @('update', 'vide', $null)
)
try {
    foreach ($s in $scenarios) {
        if ($Seul -and $Seul -ne $s[0]) { continue }
        $bac = Nouveau-Bac $s[0] $s[1]
        $arguments = @('-Bac', $bac, '-Corps', (Join-Path $PSScriptRoot "scenarios\$($s[0]).ps1"))
        if ($s[2]) { $arguments += @('-Avant', (Join-Path $PSScriptRoot "scenarios\$($s[2])")) }
        Lancer "scenario: $($s[0])" $harnais $arguments
        if ($s[0] -eq 'upgrade') { Lancer 'scenario: second start' $harnais @('-Bac', $bac, '-Corps', (Join-Path $PSScriptRoot 'scenarios\second-start.ps1')) }
        if ($s[0] -eq 'locked') { Lancer 'scenario: unlocked at the next start' $harnais @('-Bac', $bac, '-Corps', (Join-Path $PSScriptRoot 'scenarios\locked-after.ps1')) }
    }
    if (-not $Seul -or $Seul -eq 'guard') { Lancer 'guard hook (outils\garde.ps1)' (Join-Path $PSScriptRoot 'guard.ps1') @('-Bac', (Nouveau-Bac 'guard' 'vide')) }
    if (-not $Seul -or $Seul -eq 'mcp') {
        $arguments = @('-Bac', (Nouveau-Bac 'mcp' 'vide')); if ($SansEcran) { $arguments += '-SansEcran' }
        Lancer 'MCP server (outils\mcp.ps1)' (Join-Path $PSScriptRoot 'mcp-server.ps1') $arguments
    }
} finally {
    if ($Garder) { "Kept: $base" } else { Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue }
}
"`n=== TOTAL: $total checks, $echecs failure(s)"
exit $echecs
