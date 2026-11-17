# Helpers shared by the scenarios. Dot-sourced inside the app, just before the scenario.
# Claude Code is never started: Demarrer-Claude only records how it would have been called.
$Claude = Join-Path $env:WINDIR 'System32\whoami.exe'   # any existing program: the app only checks that it exists
$global:Appels = @()
$global:NumeroCapture = 0
# The question asked when Terminal access is checked: answered here, no dialog box.
$global:ReponseTerminal = $true
$global:QuestionsTerminal = 0
function Confirmer-Terminal { $global:QuestionsTerminal++; $global:ReponseTerminal }
function Demarrer-Claude([string]$modele, [string]$nom, [string]$options) { $global:Appels += "$modele|$nom|$options"; $script:Proc = $null }
# The title of a session is never asked to Claude either: the call is recorded, and Titre-Recu answers it.
$global:Titrages = @()
function Demarrer-Titrage([string]$id, [string]$instruction, [string]$resultat) {
    if ($script:Titrage -or -not $id -or [int]$script:EssaisTitre[$id] -ge $EssaisTitreMax) { return }
    $script:EssaisTitre[$id] = [int]$script:EssaisTitre[$id] + 1
    New-Item -ItemType Directory -Force $DossierSessions | Out-Null
    $global:Titrages += [pscustomobject]@{ Id = $id; Question = (Texte-Titrage $instruction $resultat) }
    $script:Titrage = [pscustomobject]@{ Proc = (Faux-Proc 0); Id = $id; Sortie = (Join-Path $DossierSessions "$id.title-answer.txt"); Question = (Join-Path $DossierSessions "$id.title-prompt.txt"); Debut = Get-Date }
}
# What Haiku answers to the title being asked for ($null: no answer at all), then the app reads it.
function Titre-Recu($texte) {
    if ($null -ne $texte) { [IO.File]::WriteAllText($script:Titrage.Sortie, [string]$texte, (New-Object System.Text.UTF8Encoding $false)) }
    Finir-Titrage
}
function Sans-Duree([string]$t) { ($t -replace '^(\[\w+), \d+ s\]', '$1]') -replace '(\(code \d+, \w+), \d+ s\)', '$1)' }
function Faux-Proc([int]$code) { [pscustomobject]@{ ExitCode = $code; HasExited = $true } | Add-Member ScriptMethod Dispose { } -PassThru }
# A task folder as Capturer makes it, without any screenshot. -SansMcp: as if the PC control tool had not started.
function Fausse-Capture([switch]$SansMcp) {
    # Names that sort in the order the tasks were made, like the real ones (a date).
    $global:NumeroCapture++
    $run = Join-Path $Runs ('test-{0:D4}-{1}' -f $global:NumeroCapture, [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Force (Join-Path $run 'images'), (Join-Path $run 'prompts'), (Join-Path $run 'responses') | Out-Null
    if (-not $SansMcp) { [IO.File]::WriteAllText((Join-Path $run 'mcp-started.txt'), '') }
    @{ Run = $run; Png = (Join-Path $run 'images\screenshot-01.png'); Fenetre = @('notepad', 'Test'); Hwnd = [IntPtr]::Zero
       Rect = (New-Object System.Drawing.Rectangle 0, 0, 1920, 1080); Largeur = 1398; Hauteur = 787 }
}
function Lire-Prompt($capture, [string]$nom = 'task') { [IO.File]::ReadAllText((Join-Path $capture.Run "prompts\$nom.txt"), [Text.Encoding]::UTF8) }
# Events as Claude Code writes them with --output-format stream-json, one JSON per line.
function Evenement-Texte([string]$texte) { @{ type = 'assistant'; message = @{ role = 'assistant'; content = @(@{ type = 'text'; text = $texte }) } } | ConvertTo-Json -Depth 6 -Compress }
function Evenement-Outil([string]$outil, $entree) { @{ type = 'assistant'; message = @{ role = 'assistant'; content = @(@{ type = 'tool_use'; id = 'toolu_1'; name = $outil; input = $entree }) } } | ConvertTo-Json -Depth 6 -Compress }
# The result of a tool: in a real task, this line holds a screenshot (hundreds of KB).
function Evenement-Retour { '{"type":"user","message":{"role":"user","content":[{"tool_use_id":"toolu_1","type":"tool_result","content":"' + ('x' * 2000) + '"}]}}' }
function Evenement-Fin([string]$texte) { @{ type = 'result'; subtype = 'success'; is_error = $false; result = $texte } | ConvertTo-Json -Compress }
function Ecrire-Flux($capture, [string[]]$lignes) {
    [IO.File]::WriteAllLines((Join-Path $capture.Run 'responses\task.jsonl'), $lignes, (New-Object System.Text.UTF8Encoding $false))
}
# The answer of Claude: one word in a text file for the triage, a stream of events for the task.
function Ecrire-Reponse($capture, [string]$texte, [string]$nom = 'task') {
    if ($nom -ne 'task') { [IO.File]::WriteAllText((Join-Path $capture.Run "responses\$nom.txt"), $texte, (New-Object System.Text.UTF8Encoding $false)); return }
    if ($texte) { Ecrire-Flux $capture @((Evenement-Texte $texte), (Evenement-Fin $texte)) } else { Ecrire-Flux $capture @() }
}
