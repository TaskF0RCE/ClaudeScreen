# Roles (folder, menu, prompt), Terminal access, finding Claude Code, a failed triage, a PC control tool
# that did not start.
try {
'--- roles'
$fournis = @(Get-ChildItem (Join-Path $Racine 'roles') -Filter *.md).Count
Verifier 'Roles folder created with the files of the app' ((Test-Path $DossierRoles) -and @(Get-ChildItem $DossierRoles -Filter *.md).Count -eq $fournis -and $fournis -ge 9 -and -not (Test-Path $AncienDossierContextes))
$noms = @(Lister-Roles)
Verifier 'General assistant comes first in the list' ($noms[0] -eq 'General assistant' -and $noms -contains 'Network engineer' -and $noms -contains 'Student') ($noms -join ' | ')
Verifier 'no choice yet: General assistant, nothing saved' ((Lire-RolesActifs).Noms -eq 'General assistant' -and -not (Test-Path (Fichier-RolesSession (Lire-Session))))
Verifier 'menu title names the roles' ($menuRoles.Text -eq 'Roles: General assistant') $menuRoles.Text
$items = @($menuRoles.DropDownItems | Where-Object { $_.Tag })
Verifier 'menu: one item per file, General assistant checked' ($items.Count -eq $fournis -and @($items | Where-Object Checked).Count -eq 1 -and ($items | Where-Object Checked).Text -eq 'General assistant')
Verifier 'menu: Open the Roles folder' (@($menuRoles.DropDownItems | ForEach-Object { $_.Text }) -contains 'Open the Roles folder')
$script:ChoixModele = 'auto'
$c = Fausse-Capture; Lancer-Tache $c ''
$p = Lire-Prompt $c
Verifier 'prompt: General assistant and its text' ($p -match 'Roles of this session: General assistant \(chosen by the user for this session\)\. Work in this role; it says who the user is' -and $p -match 'General assistant: the user can be anyone' -and $p -notmatch '<!--')
Verifier 'prompt: the roles say how to find the task' ($p -match 'their standing instructions; the roles of this session; your notes of this session; the documents of this session, then the other documents')
Verifier 'prompt: role files are not listed as documents' ($p -notmatch [regex]::Escape($DossierRoles))
Verifier 'triage: names the roles' ((Lire-Prompt $c 'triage') -match '(?m)^Roles of this session: General assistant\.')
($items | Where-Object { $_.Text -eq 'Network engineer' }).PerformClick()
Verifier 'click: role saved for the session, title and check updated' ((Get-Content (Fichier-RolesSession (Lire-Session)) -Raw).Trim() -eq 'Network engineer' -and $menuRoles.Text -eq 'Roles: Network engineer' -and ($menuRoles.DropDownItems | Where-Object Checked).Text -eq 'Network engineer')
$c = Fausse-Capture; Lancer-Tache $c ''
$p = Lire-Prompt $c
Verifier 'prompt: Network engineer replaces General assistant' ($p -match 'Roles of this session: Network engineer \(' -and $p -match 'addressing' -and $p -notmatch 'General assistant')
($menuRoles.DropDownItems | Where-Object { $_.Text -eq 'Student' }).PerformClick()
$c = Fausse-Capture; Lancer-Tache $c ''
$p = Lire-Prompt $c
Verifier 'a second role: both, in the menu and in the prompt' ($menuRoles.Text -eq 'Roles: Network engineer, Student' -and @($menuRoles.DropDownItems | Where-Object Checked).Count -eq 2 -and $p -match 'Roles of this session: Network engineer, Student \(chosen by the user for this session\)\. Work in all of these roles' -and $p -match 'addressing' -and $p -match 'Student: the user is studying') $menuRoles.Text
[IO.File]::WriteAllText((Join-Path $DossierRoles 'My job.md'), "<!-- mine -->`r`nI am an accountant.`r`n")
Remplir-MenuRoles
$mien = $menuRoles.DropDownItems | Where-Object { $_.Text -eq 'My job' }
Verifier 'a file added by the user shows in the menu' ($null -ne $mien)
($menuRoles.DropDownItems | Where-Object { $_.Text -eq 'General assistant' }).PerformClick()
Verifier 'General assistant unticks the others' ($menuRoles.Text -eq 'Roles: General assistant' -and -not (Test-Path (Fichier-RolesSession (Lire-Session))))
($menuRoles.DropDownItems | Where-Object { $_.Text -eq 'My job' }).PerformClick()
$c = Fausse-Capture; Lancer-Tache $c ''
Verifier 'prompt: the user''s own role, without its comment' ((Lire-Prompt $c) -match "Roles of this session: My job .*`nI am an accountant\.")
Move-Item (Join-Path $DossierRoles 'My job.md') (Join-Path $global:FauxBac 'My job.md')
Verifier 'its file gone: back to General assistant' ((Lire-RolesActifs).Noms -eq 'General assistant')
Move-Item (Join-Path $DossierRoles 'General assistant.md') (Join-Path $global:FauxBac 'General assistant.md')
$c = Fausse-Capture; Lancer-Tache $c ''
Verifier 'no General assistant file either: the task still starts' ((Lire-Prompt $c) -match 'Roles of this session: General assistant \(chosen by the user for this session\)\.\r?\n')
Move-Item (Get-ChildItem $global:FauxBac -Filter 'General assistant.md').FullName (Join-Path $DossierRoles 'General assistant.md')

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
[IO.File]::WriteAllText((Join-Path $DossierRoles 'General assistant.md'), ('General assistant. ' * 300))
$c = Fausse-Capture; Lancer-Tache $c ''
Ecrire-Reponse $c 'Done.'
$script:Proc = Faux-Proc 0; Processus-Fini
Verifier 'long role too: both are named' ($script:Dernier -match 'Warning: Roles\\General assistant\.md and instructions\.md is longer') $script:Dernier
[IO.File]::WriteAllText($FichierInstructions, $avantInstructions)
[IO.File]::WriteAllText((Join-Path $DossierRoles 'General assistant.md'), 'General assistant.')
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
