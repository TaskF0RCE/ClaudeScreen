# The steps of a task (what Claude said and did): shown while it runs, kept when it is stopped,
# saved with the result, and browsed in the History window.
try {
'--- a task in progress'
$script:ChoixModele = 'sonnet'
Verifier 'no task yet: the icon shows the last message' ((Texte-Resultat) -eq $script:Dernier -and $script:Dernier -match '^(No task yet|Claude Code not found)')
$cap = Fausse-Capture
Lancer-Tache $cap 'cable the routers'
Verifier 'task started as a stream of events' ($global:Appels[-1] -like 'sonnet|task|*')
$src = [IO.File]::ReadAllText((Join-Path $Racine 'ClaudeScreen.ps1'), [Text.Encoding]::UTF8)
Verifier 'the task writes task.jsonl, the triage a text file' ($src -match [regex]::Escape('--output-format stream-json --verbose <') -and $src -match [regex]::Escape('responses\$nom.jsonl') -and $src -match [regex]::Escape('--output-format text <'))
$flux = @(
    (Evenement-Texte 'I cable the 8 routers, then I will set the addresses.'),
    (Evenement-Outil 'Read' @{ file_path = 'C:\x\screenshot-01.png' }),
    (Evenement-Retour),
    (Evenement-Outil 'mcp__pc__pc' @{ actions = @('clic 352 655', 'clic 500 360') }),
    (Evenement-Retour),
    (Evenement-Texte "Cabling done.`nMEMORY: must stay hidden"),
    (Evenement-Outil 'Write' @{ file_path = 'C:\Users\x\Documents\Claude-Work\exo7_R1.txt'; content = 'enable' }),
    (Evenement-Outil 'PowerShell' @{ command = 'Get-ChildItem *.txt' })
)
Ecrire-Flux $cap ($flux + '{"type":"assistant","message":{"content":[{"type":"text","text":"half wri')
$script:Proc = Faux-Proc 0
$t = Texte-Resultat
Verifier 'while it works: what Claude said, in order' ($t -match '^Working \(sonnet, \d+ s so far\)' -and $t.IndexOf('I cable the 8 routers') -gt 0 -and $t.IndexOf('I cable the 8 routers') -lt $t.IndexOf('Cabling done.')) $t
Verifier 'while it works: actions, files and commands as short lines' ($t -match '(?m)^  > clic 352 655, clic 500 360$' -and $t -match '(?m)^  > file written: exo7_R1\.txt$' -and $t -match '(?m)^  > command: Get-ChildItem \*\.txt$') $t
Verifier 'while it works: no file reading, no MEMORY line, no half-written line' ($t -notmatch 'screenshot-01|MEMORY|half wri') $t

'--- stopped before the end'
$script:Arret = 'hotkey'
$script:Proc = Faux-Proc 1
Processus-Fini
Verifier 'stopped: the steps are in the result' ($script:Dernier -match '^Task stopped \(hotkey\) after \d+ s\.' -and $script:Dernier -match 'What Claude did before the stop:' -and $script:Dernier -match 'Cabling done\.' -and $script:Dernier -match '  > clic 352 655') $script:Dernier
$resultat = Join-Path $cap.Run 'result.txt'
Verifier 'stopped: kept in the task folder' ((Test-Path $resultat) -and [IO.File]::ReadAllText($resultat, [Text.Encoding]::UTF8) -eq $script:Dernier)
$reste = [IO.File]::ReadAllText((Join-Path $cap.Run 'responses\task.jsonl'))
Verifier 'the stream is kept without the tool results (screenshots)' ($reste -notmatch 'tool_result' -and $reste -match 'Cabling done')
Verifier 'after the task: the icon shows the result again' ((Texte-Resultat) -eq $script:Dernier)
$cap0 = Fausse-Capture
Lancer-Tache $cap0 ''
$script:Arret = 'menu'
$script:Proc = Faux-Proc 1
Processus-Fini
Verifier 'stopped during the triage: says that nothing was done' ($script:Dernier -match '^Task stopped \(menu\) after \d+ s\.\s+Claude had not done anything yet\.$') $script:Dernier

'--- finished'
$cap2 = Fausse-Capture
Lancer-Tache $cap2 ''
Ecrire-Flux $cap2 @(
    (Evenement-Texte 'I fill in the form.'),
    (Evenement-Outil 'mcp__pc__pc' @{ actions = @('clic 10 20', 'remplacer Paris') }),
    (Evenement-Retour),
    (Evenement-Texte "The form is filled in.`nMEMORY: form done"),
    (Evenement-Fin "The form is filled in.`nMEMORY: form done")
)
$script:Proc = Faux-Proc 0
Processus-Fini
Verifier 'finished: the result is the final answer only' ((Sans-Duree $script:Dernier) -eq '[sonnet] The form is filled in.') $script:Dernier
$texte = [IO.File]::ReadAllText((Join-Path $cap2.Run 'result.txt'), [Text.Encoding]::UTF8)
Verifier 'finished: result.txt = the answer, then the steps' ($texte.StartsWith($script:Dernier + "`n`n----- What Claude did -----`nI fill in the form.`n  > clic 10 20, remplacer Paris")) $texte
Verifier 'finished: the final answer is not repeated among the steps' (([regex]::Matches($texte, 'The form is filled in')).Count -eq 1 -and $texte -notmatch 'MEMORY') $texte
Verifier 'the note still went to memory.md' ((Get-NoteMemoire $FichierNotes) -match 'form done')
$cap3 = Fausse-Capture
Lancer-Tache $cap3 ''
Ecrire-Reponse $cap3 ''
$script:Proc = Faux-Proc 1
Processus-Fini
Verifier 'failed: kept too' ((Test-Path (Join-Path $cap3.Run 'result.txt')) -and $script:Dernier -match '^The task failed')

'--- long task'
$d = Read-Deroule (Join-Path $cap.Run 'none.jsonl')
Verifier 'no stream: no step, no result' ($d.Etapes.Count -eq 0 -and $null -eq $d.Resultat -and (Format-Deroule $d) -eq '')
$long = Join-Path $cap.Run 'long.jsonl'
[IO.File]::WriteAllLines($long, [string[]](1..100 | ForEach-Object { Evenement-Texte "step $_ $('y' * 600)" }))
$d = Read-Deroule $long
Verifier 'only the last 80 steps, 400 characters each' ($d.Etapes.Count -eq 80 -and $d.Omises -eq 20 -and $d.Etapes[0] -match '^step 21 ' -and $d.Etapes[0].Length -eq 400 -and (Format-Deroule $d).StartsWith('(... 20 earlier steps not shown)'))

'--- sessions'
Get-ChildItem $Runs -Directory | Remove-Item -Recurse -Force
$script:Proc = $null
$script:DernierHorsHistorique = $false
$s = Lister-Sessions
Verifier 'no task kept: the current session alone, one entry, the last message' ($s.Count -eq 1 -and $s[0].Courante -and $s[0].Taches.Count -eq 0 -and (Lister-Entrees $s[0]).Count -eq 1 -and (Texte-Entree (Lister-Entrees $s[0])[0]) -eq $script:Dernier)
# Tasks from before the sessions existed: no session.txt in their folder.
foreach ($i in 1..3) {
    $dossier = Join-Path $Runs ('20261101-10{0:D2}00' -f $i); New-Item -ItemType Directory -Force $dossier | Out-Null
    if ($i -ne 2) { [IO.File]::WriteAllText((Join-Path $dossier 'result.txt'), "old result $i") }
}
function Tache-Finie([string]$consigne, [string]$reponse) {
    $c = Fausse-Capture; Lancer-Tache $c $consigne; Ecrire-Reponse $c $reponse; $script:Proc = Faux-Proc 0; Processus-Fini; $c
}
$premiere = Lire-Session
$t1 = Tache-Finie 'only question 4' 'Answer A.'
$t2 = Tache-Finie '' 'Answer B.'
Verifier 'a task keeps the id of its session, and its instruction' ((Get-Content (Join-Path $t1.Run 'session.txt') -Raw).Trim() -eq $premiere -and [IO.File]::ReadAllText((Join-Path $t1.Run 'instruction.txt')) -eq 'only question 4' -and -not (Test-Path (Join-Path $t2.Run 'instruction.txt')))
[IO.File]::WriteAllText($FichierSession, '20991231-090000')
$t3 = Tache-Finie '' 'Answer C.'
$s = Lister-Sessions
Verifier 'three sessions, oldest first: earlier tasks, the first one, the current one' ($s.Count -eq 3 -and $s[0].Id -eq '' -and $s[0].Titre -match '^Earlier tasks  -  2 tasks$' -and -not $s[0].Courante -and $s[2].Courante -and $s[2].Taches.Count -eq 1) (($s | ForEach-Object { $_.Titre }) -join ' | ')
$milieu = $s | Where-Object { $_.Id -eq $premiere }
Verifier 'a session holds all its tasks, oldest first' ($milieu.Taches.Count -eq 2 -and $milieu.Titre -match '^Session of .*  -  2 tasks$' -and $milieu.Taches[0].Fichier -eq (Join-Path $t1.Run 'result.txt') -and $milieu.Taches[1].Fichier -eq (Join-Path $t2.Run 'result.txt')) $milieu.Titre
Verifier 'the title of the current session says so' ($s[2].Titre -match '^Session of .*  -  1 task, current$') $s[2].Titre
$e = Lister-Entrees $milieu
Verifier 'the newest task is the last entry (2 / 2); its text starts with the instruction' ($e.Count -eq 2 -and (Texte-Entree $e[0]) -match '^Instruction: only question 4\s+\[sonnet, \d+ s\] Answer A\.' -and (Texte-Entree $e[1]) -match '^\[sonnet, \d+ s\] Answer B\.')
Verifier 'the results live in the task folders: they go away with them' ((Split-Path (Split-Path $e[0].Fichier -Parent) -Parent) -eq $Runs)
Echec 'Could not start the task: test'
$e = Lister-Entrees (Lister-Sessions)[2]
Verifier 'a task that could not start: its message last, in the current session only' ($e.Count -eq 2 -and -not $e[1].Fichier -and $e[1].Titre -eq 'last message' -and (Texte-Entree $e[1]) -eq 'Could not start the task: test' -and (Lister-Entrees $milieu).Count -eq 2)
$script:Etape = 'tri'
$script:Proc = Faux-Proc 0
$e = Lister-Entrees (Lister-Sessions)[2]
Verifier 'a task in progress: shown last' ($e.Count -eq 2 -and $e[1].Titre -eq 'in progress' -and (Texte-Entree $e[1]) -eq 'Looking at the screen...')
$script:Proc = $null
Remove-Item $milieu.Taches[0].Fichier
Verifier 'a result removed while the window is open' ((Texte-Entree $milieu.Taches[0]) -eq 'This result is no longer kept.')

'--- ghost mode'
[void](Nouvelle-Session)
$sessionGhost = Lire-Session
[void](Tache-Finie '' "Kept.`nMEMORY: a note of the session")
Verifier 'ghost mode is off by default' (-not $script:Fantome -and -not (Test-Path $FichierFantome))
Verifier 'ghost mode cannot change during a task' (-not (& { $script:Proc = Faux-Proc 0; $r = Basculer-Fantome $true; $script:Proc = $null; $r }) -and -not $script:Fantome)
[void](Basculer-Fantome $true)
$nbAvant = @(Get-ChildItem $Runs -Directory).Count
$g = Fausse-Capture
Lancer-Tache $g 'a secret instruction'
$p = Lire-Prompt $g
Verifier 'ghost: the notes of the session are not sent, none is asked for' ($p -notmatch 'MEMORY|Persistent memory|a note of the session' -and $p -match 'a secret instruction')
Verifier 'ghost: no session id, no instruction file in the task folder' (-not (Test-Path (Join-Path $g.Run 'session.txt')) -and -not (Test-Path (Join-Path $g.Run 'instruction.txt')))
Ecrire-Reponse $g "Secret answer.`nMEMORY: must not be saved"
$script:Proc = Faux-Proc 0
Processus-Fini
Verifier 'ghost: the answer is shown, with its lines as they are' ($script:Dernier -match 'Secret answer\.' -and $script:DernierHorsHistorique)
Verifier 'ghost: the task folder is gone (screenshots, prompt, answer), no note saved' (-not (Test-Path $g.Run) -and @(Get-ChildItem $Runs -Directory).Count -eq $nbAvant -and (Get-NoteMemoire $FichierNotes) -eq '- a note of the session')
$e = Lister-Entrees ((Lister-Sessions) | Where-Object Courante)
Verifier 'ghost: the answer is the last entry, marked as not kept' ($e.Count -eq 2 -and $e[1].Titre -eq 'ghost mode, not kept' -and (Texte-Entree $e[1]) -eq $script:Dernier)
$g2 = Fausse-Capture; Lancer-Tache $g2 ''; $script:Arret = 'hotkey'; $script:Proc = Faux-Proc 1; Processus-Fini
Verifier 'ghost, stopped task: nothing kept either' (-not (Test-Path $g2.Run) -and $script:Dernier -match '^Task stopped')
[void](Basculer-Fantome $false)
Verifier 'ghost off: the ghost answer is forgotten, the session is back as it was' ($script:Dernier -eq $script:Accueil -and -not $script:DernierHorsHistorique -and (Lire-Session) -eq $sessionGhost -and (Lister-Entrees ((Lister-Sessions) | Where-Object Courante)).Count -eq 1 -and (Get-Content $FichierFantome -Raw).Trim() -eq 'off')
$c = Tache-Finie '' 'After the ghost.'
Verifier 'after ghost mode: tasks are kept again, with the notes of the session' ((Test-Path (Join-Path $c.Run 'result.txt')) -and (Lire-Prompt $c) -match 'a note of the session')
$libelles = @($menu.Items | ForEach-Object { $_.Text })
Verifier 'menu: History first, then New session' (($libelles[0..1] -join '|') -eq 'History|New session') ($libelles -join '|')
} catch { Verifier 'scenario ran to the end' $false ($_.Exception.Message + ' ' + $_.InvocationInfo.PositionMessage) }
