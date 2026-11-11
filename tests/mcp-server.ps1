# The MCP server (outils\mcp.ps1), driven as Claude Code drives it: one JSON-RPC message per line.
# The only actions run are waits and refused ones, plus one screenshot (skipped with -SansEcran):
# nothing is clicked or typed.
param([string]$Bac, [switch]$SansEcran)
$ErrorActionPreference = 'Stop'
$run = Join-Path $Bac 'app\data\runs\mcp'
$contexte = Join-Path $Bac 'docs\Claude-Work\System-Context'
New-Item -ItemType Directory -Force $run, $contexte | Out-Null
[IO.File]::WriteAllText((Join-Path $contexte 'instructions.md'), 'mine')
# The screen as the app describes it for a task: a 1920x1080 screen shown to Claude at 1398x787.
@{ gauche = 0; haut = 0; largeurEcran = 1920; hauteurEcran = 1080; echelle = 1920 / 1398; largeur = 1398; hauteur = 787 } |
    ConvertTo-Json | Set-Content (Join-Path $run 'screen.json') -Encoding UTF8
$env:ECRAN_RUN = $run
$env:ECRAN_CONTEXTE = $contexte
$psi = New-Object System.Diagnostics.ProcessStartInfo 'powershell.exe', "-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $Bac 'app\outils\mcp.ps1')`""
$psi.UseShellExecute = $false; $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.CreateNoWindow = $true
$p = [Diagnostics.Process]::Start($psi)
$tests = 0; $echecs = 0
function Appel([string]$nom, [string]$json, [scriptblock]$test) {
    $p.StandardInput.WriteLine($json)
    $tache = $p.StandardOutput.ReadLineAsync()
    $rep = if ($tache.Wait(30000)) { $tache.Result } else { '(no answer in 30 s)' }
    try { $o = $rep | ConvertFrom-Json } catch { $o = $null }
    $script:tests++
    if ($o -and (& $test $o)) { "  ok    $nom" }
    else { $script:echecs++; "  FAIL  $nom  " + $(if ("$rep".Length -gt 300) { "$rep".Substring(0, 300) + '...' } else { $rep }) }
}
function Outil([string[]]$actions, $capture) {
    $arguments = @{ actions = $actions }; if ($null -ne $capture) { $arguments.capture = $capture }
    @{ jsonrpc = '2.0'; id = 50; method = 'tools/call'; params = @{ name = 'pc'; arguments = $arguments } } | ConvertTo-Json -Depth 6 -Compress
}

Appel 'initialize: echoes the protocol version' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}' { param($o) $o.id -eq 1 -and $o.result.protocolVersion -eq '2025-06-18' -and $o.result.serverInfo.name -eq 'claudescreen-pc' }
$tests++; if (Test-Path (Join-Path $run 'mcp-started.txt')) { '  ok    initialize: leaves mcp-started.txt for the app' } else { $echecs++; '  FAIL  initialize: mcp-started.txt is missing' }
$p.StandardInput.WriteLine('{"jsonrpc":"2.0","method":"notifications/initialized"}')
Appel 'tools/list: one tool, pc' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' { param($o) @($o.result.tools).Count -eq 1 -and $o.result.tools[0].name -eq 'pc' -and $o.result.tools[0].inputSchema.required[0] -eq 'actions' }
Appel 'two actions in one call, no screenshot, active window named' (Outil @('attendre 5', 'attendre 5') $false) { param($o) -not $o.result.isError -and @($o.result.content).Count -eq 1 -and $o.result.content[0].text -match "^1\. attendre: OK\n2\. attendre: OK\nActive window: .* - `".*`"$" }
Appel 'an error stops the batch' (Outil @('attendre 5', 'relier 1 2', 'attendre 5', 'attendre 5') $false) { param($o) $o.result.isError -and $o.result.content[0].text -match "^1\. attendre: OK\n2\. relier: ERROR: Missing argument 3 for 'relier'\.\nThe 2 action\(s\) after it were not run\." }
Appel 'bad number' (Outil @('clic abc 10') $false) { param($o) $o.result.isError -and $o.result.content[0].text -match "Invalid argument 1 for 'clic': abc" }
Appel 'unknown action' (Outil @('fly away') $false) { param($o) $o.result.isError -and $o.result.content[0].text -match 'Unknown action: fly' }
Appel 'unknown key' (Outil @('touche ctrl+banana') $false) { param($o) $o.result.isError -and $o.result.content[0].text -match 'Unknown key: banana' }
Appel 'Recycle Bin: System-Context refused' (Outil @('corbeille "' + (Join-Path $contexte 'instructions.md') + '"') $false) { param($o) $o.result.isError -and $o.result.content[0].text -match 'Refused: .* is read-only' -and (Test-Path (Join-Path $contexte 'instructions.md')) }
Appel 'Recycle Bin: Windows refused' (Outil @("corbeille $env:WINDIR\System32\drivers\etc") $false) { param($o) $o.result.isError -and $o.result.content[0].text -match 'Refused: .* part of Windows' }
Appel 'Recycle Bin: the whole profile refused' (Outil @("corbeille $env:USERPROFILE") $false) { param($o) $o.result.isError -and $o.result.content[0].text -match 'Refused: ' -and (Test-Path $env:USERPROFILE) }
Appel 'Recycle Bin: a whole drive refused' (Outil @("corbeille $env:SystemDrive\") $false) { param($o) $o.result.isError -and $o.result.content[0].text -match 'Refused: ' }
Appel 'more than 40 actions refused' (Outil (1..41 | ForEach-Object { 'attendre 1' }) $null) { param($o) $o.result.isError -and $o.result.content[0].text -match 'Nothing was run' }
if ($SansEcran) { '  skip  screenshot after the last action (-SansEcran)' }
else {
    Appel 'screenshot after the last action, as a JPEG' (Outil @('attendre 5') $null) { param($o) -not $o.result.isError -and @($o.result.content).Count -eq 2 -and $o.result.content[1].type -eq 'image' -and $o.result.content[1].mimeType -eq 'image/jpeg' -and $o.result.content[1].data.Length -gt 5000 -and $o.result.content[0].text -match 'Screenshot after the last action' }
}
Appel 'unknown method' '{"jsonrpc":"2.0","id":9,"method":"resources/list"}' { param($o) $o.error.code -eq -32601 }
Appel 'ping' '{"jsonrpc":"2.0","id":10,"method":"ping"}' { param($o) $o.id -eq 10 -and $null -ne $o.result }
$p.StandardInput.Close()
$tests++
if ($p.WaitForExit(5000)) { '  ok    the server stops when its input closes' } else { $echecs++; '  FAIL  the server is still running'; $p.Kill() }
$erreurs = $p.StandardError.ReadToEnd(); if ($erreurs) { "stderr: $erreurs" }
"=== $tests checks, $echecs failure(s)"
exit $echecs
