# Contexts (folder, menu, prompt), Terminal access, finding Claude Code, a failed triage, a PC control tool
# that did not start.
try {
'--- contexts'
$fournis = @(Get-ChildItem (Join-Path $Racine 'contexts') -Filter *.md).Count
Verifier 'Contexts folder created with the files of the app' ((Test-Path $DossierContextes) -and @(Get-ChildItem $DossierContextes -Filter *.md).Count -eq $fournis -and $fournis -ge 9)
$noms = @(Lister-Contextes)
Verifier 'Default comes first in the list' ($noms[0] -eq 'Default' -and $noms -contains 'Networking' -and $noms -contains 'Studies') ($noms -join ' | ')
Verifier 'no choice yet: Default is active' ((Lire-ContexteActif).Nom -eq 'Default' -and -not (Test-Path $FichierContexte))
Verifier 'menu title names the active context' ($menuContexte.Text -eq 'Context: Default') $menuContexte.Text
$items = @($menuContexte.DropDownItems | Where-Object { $_.Tag })
Verifier 'menu: one item per file, Default checked' ($items.Count -eq $fournis -and @($items | Where-Object Checked).Count -eq 1 -and ($items | Where-Object Checked).Text -eq 'Default')
Verifier 'menu: Open the Contexts folder' (@($menuContexte.DropDownItems | ForEach-Object { $_.Text }) -contains 'Open the Contexts folder')
$script:ChoixModele = 'auto'
$c = Fausse-Capture; Lancer-Tache $c ''
$p = Lire-Prompt $c
Verifier 'prompt: Default context and its text' ($p -match 'Active context: Default \(chosen by the user in the icon menu\)' -and $p -match 'General assistant' -and $p -notmatch '<!--')
Verifier 'prompt: the context says how to find the task' ($p -match 'their standing instructions; the active context; your notes of this session')
Verifier 'prompt: context files are not listed as documents' ($p -notmatch [regex]::Escape($DossierContextes))
Verifier 'triage: names the context' ((Lire-Prompt $c 'triage') -match '(?m)^Active context: Default\.')
($items | Where-Object { $_.Text -eq 'Networking' }).PerformClick()
Verifier 'click: choice saved, title and check updated' ((Get-Content $FichierContexte -Raw).Trim() -eq 'Networking' -and $menuContexte.Text -eq 'Context: Networking' -and ($menuContexte.DropDownItems | Where-Object Checked).Text -eq 'Networking')
$c = Fausse-Capture; Lancer-Tache $c ''
$p = Lire-Prompt $c
Verifier 'prompt: Networking context replaces Default' ($p -match 'Active context: Networking' -and $p -match 'addressing' -and $p -notmatch 'General assistant')
[IO.File]::WriteAllText((Join-Path $DossierContextes 'My job.md'), "<!-- mine -->`r`nI am an accountant.`r`n")
Remplir-MenuContexte
$mien = $menuContexte.DropDownItems | Where-Object { $_.Text -eq 'My job' }
Verifier 'a file added by the user shows in the menu' ($null -ne $mien)
$mien.PerformClick()
$c = Fausse-Capture; Lancer-Tache $c ''
Verifier 'prompt: the user''s own context, without its comment' ((Lire-Prompt $c) -match "Active context: My job .*`nI am an accountant\.")
Move-Item (Join-Path $DossierContextes 'My job.md') (Join-Path $global:FauxBac 'My job.md')
Verifier 'active file gone: back to Default' ((Lire-ContexteActif).Nom -eq 'Default')
Move-Item (Join-Path $DossierContextes 'Default.md') (Join-Path $global:FauxBac 'Default.md')
$c = Fausse-Capture; Lancer-Tache $c ''
Verifier 'no Default file either: the task still starts' ((Lire-Prompt $c) -match 'Active context: Default \(chosen by the user in the icon menu\)\.\r?\n')

'--- Terminal access'
Verifier 'off by default, nothing saved yet' (-not $script:Terminal -and -not $menuTerminal.Checked -and -not (Test-Path $FichierTerminal))
$script:ChoixModele = 'opus'
$c = Fausse-Capture; Lancer-Tache $c ''
$p = Lire-Prompt $c
Verifier 'off: no terminal in the prompt' ($p -match 'There is no terminal\.' -and $p -notmatch 'PowerShell')
Verifier 'off: no PowerShell among the tools' ($global:Appels[-1] -like 'opus|task|--tools Read,Write,Edit,Glob,Grep --mcp-config *') $global:Appels[-1]
$global:ReponseTerminal = $false
$menuTerminal.PerformClick()
Verifier 'checked, then No to the question: stays off, the No is not remembered' ($global:QuestionsTerminal -eq 1 -and -not (Test-Path $FichierTerminalAccepte) -and -not $script:Terminal -and -not $menuTerminal.Checked -and (Get-Content $FichierTerminal -Raw).Trim() -eq 'off' -and [bool]((Get-Content $Journal -Encoding UTF8) -match 'Terminal access: not allowed'))
$global:ReponseTerminal = $true
$menuTerminal.PerformClick()
Verifier 'checked, then Yes: on saved, and the Yes is remembered' ($global:QuestionsTerminal -eq 2 -and $script:Terminal -and (Get-Content $FichierTerminal -Raw).Trim() -eq 'on' -and (Test-Path $FichierTerminalAccepte))
$c = Fausse-Capture; Lancer-Tache $c ''
$p = Lire-Prompt $c
Verifier 'on: prompt gives the PowerShell tool and its limits' ($p -match 'you also have the PowerShell tool' -and $p -match 'The screen comes first' -and $p -match 'No administrator rights' -and $p -notmatch 'There is no terminal')
Verifier 'on: PowerShell among the tools' ($global:Appels[-1] -like 'opus|task|--tools Read,Write,Edit,Glob,Grep,PowerShell --mcp-config *') $global:Appels[-1]
Verifier 'on: said in the log' ([bool]((Get-Content $Journal -Encoding UTF8) -match 'Model: opus, terminal$'))
$menuTerminal.PerformClick()
Verifier 'unchecked again: off saved, no question to turn it off' ($global:QuestionsTerminal -eq 2 -and -not $script:Terminal -and (Get-Content $FichierTerminal -Raw).Trim() -eq 'off')
$global:ReponseTerminal = $false
$menuTerminal.PerformClick()
Verifier 'checked a second time: on at once, the question is not asked again' ($global:QuestionsTerminal -eq 2 -and $script:Terminal -and $menuTerminal.Checked)
$menuTerminal.PerformClick()
$global:ReponseTerminal = $true

'--- texts longer than 4000 characters'
$c = Fausse-Capture; Lancer-Tache $c ''
Ecrire-Reponse $c 'Done.'
$script:Proc = Faux-Proc 0; Processus-Fini
Verifier 'short texts: no warning' ($script:Dernier -notmatch 'Warning') $script:Dernier
$avantInstructions = [IO.File]::ReadAllText($FichierInstructions)
[IO.File]::WriteAllText($FichierInstructions, "<!-- $('c' * 5000) -->`n" + (('Always answer briefly. ' * 200)))
$c = Fausse-Capture; Lancer-Tache $c ''
$p = Lire-Prompt $c
Verifier 'long instructions.md: 4000 characters are sent, comments not counted' ($p -match 'Always answer briefly' -and ([regex]::Matches($p, 'Always answer briefly')).Count -lt 180)
Ecrire-Reponse $c 'Done.'
$script:Proc = Faux-Proc 0; Processus-Fini
Verifier 'long instructions.md: said in the result and in the log' ($script:Dernier -match 'Done\.\s+\(Warning: instructions\.md is longer than 4000 characters, so its end was not sent' -and [bool]((Get-Content $Journal -Encoding UTF8) -match 'instructions\.md is longer than 4000 characters')) $script:Dernier
[IO.File]::WriteAllText((Join-Path $DossierContextes 'Default.md'), ('General assistant. ' * 300))
$c = Fausse-Capture; Lancer-Tache $c ''
Ecrire-Reponse $c 'Done.'
$script:Proc = Faux-Proc 0; Processus-Fini
Verifier 'long context too: both are named' ($script:Dernier -match 'Warning: Contexts\\Default\.md and instructions\.md is longer') $script:Dernier
[IO.File]::WriteAllText($FichierInstructions, $avantInstructions)
[IO.File]::WriteAllText((Join-Path $DossierContextes 'Default.md'), 'General assistant.')
$c = Fausse-Capture; Lancer-Tache $c ''
Ecrire-Reponse $c 'Done.'
$script:Proc = Faux-Proc 0; Processus-Fini
Verifier 'shortened again: no warning any more' ($script:Dernier -notmatch 'Warning') $script:Dernier

'--- prompt: fields and clicks'
Verifier 'remplacer is listed, with its warning' ($p -match '(?m)^  remplacer "text" ' -and $p -match 'Never in a document')
Verifier 'one click is enough, look before clicking again' ($p -match 'One clic is enough' -and $p -match 'a second click on the same spot often closes')

'--- instruction bar: the text is kept when the bar is closed without Enter'
function Capturer { Fausse-Capture }
function Fermer-Barre([string]$texte, [bool]$valider) {
    Demander-Consigne
    $script:Boite.Controls[0].Controls[0].Text = $texte
    $script:BoiteValidee = $valider; $script:BoiteFermeture = $true
    $script:Boite.Close()
}
$nbAppels = $global:Appels.Count
Fermer-Barre 'configure the DHCP pool' $false
Verifier 'closed without Enter: no task, text kept' ($global:Appels.Count -eq $nbAppels -and $script:Brouillon -eq 'configure the DHCP pool' -and $null -eq $script:Boite)
Demander-Consigne
Verifier 'opened again: the text is back in the bar' ($script:Boite.Controls[0].Controls[0].Text -eq 'configure the DHCP pool')
$script:BoiteValidee = $true; $script:BoiteFermeture = $true; $script:Boite.Close()
Verifier 'Enter: task started with it, draft cleared' ($global:Appels.Count -eq ($nbAppels + 1) -and $script:Brouillon -eq '' -and (Get-Content $Journal -Encoding UTF8 | Select-Object -Last 3) -match 'with instruction')
Demander-Consigne
Verifier 'after a sent instruction: the bar is empty' ($script:Boite.Controls[0].Controls[0].Text -eq '')
$script:BoiteFermeture = $true; $script:Boite.Close()

'--- a task that goes wrong'
$script:ChoixModele = 'auto'
$nbAppels = $global:Appels.Count
$c = Fausse-Capture; Lancer-Tache $c ''
[IO.File]::WriteAllText((Join-Path $c.Run 'responses\triage-errors.txt'), "error: unknown option '--effort'")
$script:Proc = Faux-Proc 1
Processus-Fini
Verifier 'failed triage: stops with the message of Claude Code' ($script:Dernier -match '^Claude Code could not start the task \(code 1\)' -and $script:Dernier -match "unknown option '--effort'" -and $script:Dernier -match 'claude update' -and $null -eq $script:Proc) $script:Dernier
Verifier 'failed triage: the task itself is not started' ($global:Appels.Count -eq ($nbAppels + 1) -and $global:Appels[-1] -like 'haiku|triage|*') "$nbAppels -> $($global:Appels.Count): $($global:Appels[-1])"
$script:ChoixModele = 'sonnet'
$c = Fausse-Capture -SansMcp; Lancer-Tache $c ''
Ecrire-Reponse $c 'I could not click.'
$script:Proc = Faux-Proc 0
Processus-Fini
Verifier 'PC control tool not started: warning in the result and the log' ($script:Dernier -match 'I could not click\.' -and $script:Dernier -match 'the PC control tool did not start' -and [bool]((Get-Content $Journal -Encoding UTF8) -match 'PC control tool \(MCP\) did not start')) $script:Dernier

'--- finding Claude Code'
$profil = $env:USERPROFILE; $chemins = $env:PATH; $appdata = $env:APPDATA
try {
    $faux = Join-Path (Split-Path $Racine) 'faux-profil'
    New-Item -ItemType Directory -Force (Join-Path $faux 'ailleurs'), (Join-Path $faux 'roaming\npm') | Out-Null
    $env:USERPROFILE = $faux; $env:APPDATA = Join-Path $faux 'roaming'; $env:PATH = "$env:WINDIR\System32"
    $defaut = Join-Path $faux '.local\bin\claude.exe'
    Verifier 'nowhere: the default path is returned (and reported as missing)' ((Trouver-Claude) -eq $defaut)
    [IO.File]::WriteAllText((Join-Path $faux 'roaming\npm\claude.cmd'), '@echo off')
    Verifier 'npm folder, not in the PATH: found' ((Trouver-Claude) -eq (Join-Path $faux 'roaming\npm\claude.cmd'))
    [IO.File]::WriteAllText((Join-Path $faux 'ailleurs\claude.cmd'), '@echo off')
    $env:PATH = (Join-Path $faux 'ailleurs') + ";$env:WINDIR\System32"
    Verifier 'in the PATH: found first' ((Trouver-Claude) -eq (Join-Path $faux 'ailleurs\claude.cmd')) (Trouver-Claude)
    New-Item -ItemType Directory -Force (Split-Path $defaut) | Out-Null
    [IO.File]::WriteAllText($defaut, '')
    Verifier 'official install: wins over the PATH' ((Trouver-Claude) -eq $defaut)
    $Claude = Join-Path $faux 'gone\claude.exe'
    Remove-Item -LiteralPath $defaut; Remove-Item -LiteralPath (Join-Path $faux 'ailleurs\claude.cmd'); Remove-Item -LiteralPath (Join-Path $faux 'roaming\npm\claude.cmd')
    $nbAppels = $global:Appels.Count
    $c = Fausse-Capture; Lancer-Tache $c ''
    Verifier 'Claude Code missing: clear error, nothing started' ($script:Dernier -match 'Claude Code not found' -and $global:Appels.Count -eq $nbAppels) $script:Dernier
    [IO.File]::WriteAllText($defaut, '')
    $c = Fausse-Capture; Lancer-Tache $c ''
    Verifier 'installed since: found again at the next task, without a restart' ($Claude -eq $defaut -and $global:Appels.Count -eq ($nbAppels + 1)) "$Claude $nbAppels -> $($global:Appels.Count)"
} finally { $env:USERPROFILE = $profil; $env:PATH = $chemins; $env:APPDATA = $appdata }
} catch { Verifier 'scenario ran to the end' $false ($_.Exception.Message + ' ' + $_.InvocationInfo.PositionMessage) }
