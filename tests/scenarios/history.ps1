# The steps of a task (what Claude said and did): shown while it runs, kept when it is stopped,
# saved with the result, and browsed in the History window.
try {
'--- a task in progress'
$script:ChoixModele = 'sonnet'
Verifier 'no task yet: the icon shows the last message' ((Texte-Resultat) -eq $script:Dernier -and $script:Dernier -match '^(No task yet|Claude Code not found)')
$cap = Fausse-Capture
Lancer-Tache $cap 'cable the routers'
Verifier 'task started as a stream of events' ($global:Appels[-1] -like 'sonnet|task|*')
Verifier 'a persisted task keeps its Claude Code transcript' ($global:Appels[-1] -notmatch 'no-session-persistence')
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
Verifier 'stopped: the icon shows the stop sign (red square), not the error dot' ([object]::ReferenceEquals($icone.Icon, $IconeArret) -and -not [object]::ReferenceEquals($IconeArret, $IconeErreur))
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
$t1 = Tache-Finie 'only question 4' "Answer A.`nMEMORY: note of the first session"
$t2 = Tache-Finie '' 'Answer B.'
Verifier 'a task keeps the id of its session, and its instruction' ((Get-Content (Join-Path $t1.Run 'session.txt') -Raw).Trim() -eq $premiere -and [IO.File]::ReadAllText((Join-Path $t1.Run 'instruction.txt')) -eq 'only question 4' -and -not (Test-Path (Join-Path $t2.Run 'instruction.txt')))
[void](Nouvelle-Session)
$deuxieme = Lire-Session
$t3 = Tache-Finie '' "Answer C.`nMEMORY: note of the second session"
$s = Lister-Sessions
Verifier 'three sessions, oldest first: earlier tasks, Session 1, Session 2 (current)' ($s.Count -eq 3 -and $s[0].Id -eq '' -and $s[0].Titre -match '^Earlier tasks  -  2 tasks$' -and $s[1].Id -eq $premiere -and $s[1].Titre -match '^Session 1  -  .*  -  2 tasks$' -and -not $s[1].Courante -and $s[2].Courante -and $s[2].Titre -match '^Session 2 \(current\)  -  .*  -  1 task$') (($s | ForEach-Object { $_.Titre }) -join ' | ')
$milieu = $s[1]
Verifier 'a session holds all its tasks, oldest first' ($milieu.Taches.Count -eq 2 -and $milieu.Taches[0].Fichier -eq (Join-Path $t1.Run 'result.txt') -and $milieu.Taches[1].Fichier -eq (Join-Path $t2.Run 'result.txt'))
$e = Lister-Entrees $milieu
Verifier 'the newest task is the last entry (2 / 2); its text starts with the instruction' ($e.Count -eq 2 -and (Texte-Entree $e[0]) -match '^Instruction: only question 4\s+\[sonnet, \d+ s\] Answer A\.' -and (Texte-Entree $e[1]) -match '^\[sonnet, \d+ s\] Answer B\.')
$c = Lister-Choix
Verifier 'the drop-down list: the session in use first, then the others, newest first' ($c.Count -eq 3 -and $c[0].Id -eq $deuxieme -and $c[1].Id -eq $premiere -and $c[2].Id -eq '')
Echec 'Could not start the task: test'
$e = Lister-Entrees (Lister-Sessions)[2]
Verifier 'a task that could not start: its message last, in the current session only' ($e.Count -eq 2 -and -not $e[1].Fichier -and $e[1].Titre -eq 'last message' -and (Texte-Entree $e[1]) -eq 'Could not start the task: test' -and (Lister-Entrees $milieu).Count -eq 2)
$script:Etape = 'tri'
$script:Proc = Faux-Proc 0
$e = Lister-Entrees (Lister-Sessions)[2]
Verifier 'a task in progress: shown last' ($e.Count -eq 2 -and $e[1].Titre -eq 'in progress' -and (Texte-Entree $e[1]) -eq 'Looking at the screen...')
Verifier 'during a task: no resume' (-not (Reprendre-Session $premiere) -and (Lire-Session) -eq $deuxieme)
$script:Proc = $null

'--- resuming a session'
Verifier 'each session has its own notes' ((Get-NoteMemoire $FichierNotes) -eq '- note of the second session' -and (Get-NoteMemoire (Fichier-NotesSession $premiere)) -match '(?m)^- note of the first session$' -and (Get-NoteMemoire (Fichier-NotesSession $premiere)) -notmatch 'second session')
Verifier 'resume the first session: done' (Reprendre-Session $premiere)
Verifier 'resumed: it is the current one again, with its notes; the other one keeps its own' ((Lire-Session) -eq $premiere -and (Get-NoteMemoire $FichierNotes) -match '(?m)^- note of the first session$' -and (Get-NoteMemoire $FichierNotes) -notmatch 'second session' -and (Get-NoteMemoire (Fichier-NotesSession $deuxieme)) -eq '- note of the second session')
$t4 = Tache-Finie '' 'Answer D.'
Verifier 'resumed: the next task gets its notes and joins it' ((Lire-Prompt $t4) -match 'note of the first session' -and (Lire-Prompt $t4) -notmatch 'note of the second session' -and ((Lister-Sessions) | Where-Object Id -eq $premiere).Taches.Count -eq 3)
Verifier 'earlier tasks and unknown ids cannot be resumed' (-not (Reprendre-Session '') -and -not (Reprendre-Session '..\x') -and (Lire-Session) -eq $premiere)
Remove-Item $milieu.Taches[0].Fichier
Verifier 'a result removed while the window is open' ((Texte-Entree $milieu.Taches[0]) -eq 'This result is no longer kept.')
Get-ChildItem $Runs -Directory | Where-Object { (Test-Path (Join-Path $_.FullName 'session.txt')) -and (Get-Content (Join-Path $_.FullName 'session.txt') -Raw).Trim() -eq $deuxieme } | Remove-Item -Recurse -Force
Nettoyer-Runs
Verifier 'the notes of a session go away with its last task' (-not (Test-Path (Fichier-NotesSession $deuxieme)))

'--- Ghost Mode'
[void](Nouvelle-Session)
$persistee = Lire-Session
[void](Tache-Finie '' "Kept.`nMEMORY: a note of the persisted session")
Verifier 'Persisted Memory is the default' (-not $script:Fantome -and -not (Test-Path $FichierFantome))
Verifier 'the mode cannot change during a task' (-not (& { $script:Proc = Faux-Proc 0; $r = Basculer-Fantome $true; $script:Proc = $null; $r }) -and -not $script:Fantome)
Verifier 'Ghost Mode selected' ((Basculer-Fantome $true) -and $script:Fantome -and $script:Dernier -eq $script:AccueilFantome)
$c = Lister-Choix
Verifier 'ghost: the ghost session is first in the list, no persisted session is "current"' ($c[0].Fantome -and $c[0].Titre -eq 'Ghost session (current)  -  0 tasks' -and -not ($c | Where-Object { -not $_.Fantome -and $_.Courante }) -and ($c | Where-Object Id -eq $persistee))
$nbAvant = @(Get-ChildItem $Runs -Directory).Count
$g = Fausse-Capture
Lancer-Tache $g 'a secret instruction'
$p = Lire-Prompt $g
Verifier 'ghost: the notes of the persisted session are not sent' ($p -notmatch 'a note of the persisted session' -and $p -match '\(no notes yet\)' -and $p -match 'a secret instruction')
Verifier 'ghost: Claude Code keeps no transcript of it' ($global:Appels[-1] -match ' --no-session-persistence$') $global:Appels[-1]
Verifier 'ghost: no session id, no instruction file in the task folder' (-not (Test-Path (Join-Path $g.Run 'session.txt')) -and -not (Test-Path (Join-Path $g.Run 'instruction.txt')) -and (Test-Path (Join-Path $g.Run 'ghost.txt')))
Ecrire-Reponse $g "Secret answer.`nMEMORY: a ghost note"
$script:Proc = Faux-Proc 0
Processus-Fini
Verifier 'ghost: the answer is shown, its note is hidden' ((Sans-Duree $script:Dernier) -eq '[sonnet] Secret answer.')
Verifier 'ghost: nothing on disk (task folder gone, no note written anywhere)' (-not (Test-Path $g.Run) -and @(Get-ChildItem $Runs -Directory).Count -eq $nbAvant -and (Get-NoteMemoire $FichierNotes) -eq '- a note of the persisted session' -and -not (Get-ChildItem $Donnees -Recurse -File | Where-Object { $_.Name -ne 'log.txt' } | Select-String -Pattern 'Secret answer|a ghost note|a secret instruction' -List))
$g2 = Fausse-Capture; Lancer-Tache $g2 ''
Verifier 'ghost: the next task of the ghost session gets its note' ((Lire-Prompt $g2) -match '- a ghost note' -and (Lire-Prompt $g2) -notmatch 'persisted session')
$script:Arret = 'hotkey'; $script:Proc = Faux-Proc 1; Processus-Fini
$e = Lister-Entrees (Lister-Choix)[0]
Verifier 'ghost: the session shows its two tasks, with the instruction, from memory' ($e.Count -eq 2 -and (Texte-Entree $e[0]) -match '^Instruction: a secret instruction\s+\[sonnet, \d+ s\] Secret answer\.' -and (Texte-Entree $e[1]) -match '^Task stopped' -and -not (Test-Path $g2.Run))
$g3 = Fausse-Capture; Lancer-Tache $g3 ''; $script:Proc = $null
Nettoyer-Runs
Verifier 'ghost: a task that never ended (app closed) is deleted at the next cleanup' (-not (Test-Path $g3.Run))
Verifier 'New session in Ghost Mode: another ghost session, still ghost, the old one forgotten' ((Nouvelle-Session) -and $script:Fantome -and (Lister-Entrees (Lister-Choix)[0]).Count -eq 1 -and $script:NotesFantome.Count -eq 0 -and (Lire-Session) -eq $persistee)
[void](Tache-Finie '' 'Ghost again.')
Verifier 'back to Persisted Memory' ((Basculer-Fantome $false) -and -not $script:Fantome -and (Get-Content $FichierFantome -Raw).Trim() -eq 'off')
$c = Lister-Choix
Verifier 'persisted again: the ghost session is forgotten, the session that was current is back as it was' ($script:EntreesFantome.Count -eq 0 -and $script:Dernier -eq $script:Accueil -and $c[0].Id -eq $persistee -and $c[0].Courante -and $c[0].Taches.Count -eq 1 -and -not ($c | Where-Object Fantome))
$k = Tache-Finie '' 'After the ghost.'
Verifier 'persisted again: tasks are kept, with the notes of the session' ((Test-Path (Join-Path $k.Run 'result.txt')) -and (Lire-Prompt $k) -match 'a note of the persisted session')
[void](Basculer-Fantome $true)
Verifier 'New session after Persisted Memory is chosen: a persisted one' ((Basculer-Fantome $false) -and (Nouvelle-Session) -and -not $script:Fantome -and (Lire-Session) -ne $persistee)
[void](Basculer-Fantome $true)
Verifier 'Resume from Ghost Mode: Persisted Memory is selected again, in that session' ((Reprendre-Session $persistee) -and -not $script:Fantome -and (Lire-Session) -eq $persistee -and (Get-NoteMemoire $FichierNotes) -match 'a note of the persisted session')

'--- the two shortcuts'
Verifier 'the waiting message names both shortcuts and what each does' ($script:Accueil -match 'Ctrl\+Alt\+C: type what you want' -and $script:Accueil -match 'Ctrl\+Alt\+Shift\+C: automatic' -and $script:AccueilFantome -match 'Ghost session' -and $script:AccueilFantome -match 'Ctrl\+Alt\+Shift\+C: automatic')
[void](Basculer-Fantome $false); [void](Nouvelle-Session)
Verifier 'a new session says them too' ($script:Dernier -match '^New session\.' -and $script:Dernier -match 'Ctrl\+Alt\+C: type' -and $script:Dernier -match 'Ctrl\+Alt\+Shift\+C: automatic')
$global:Lances = @()
function Demander-Consigne { $global:Lances += 'bar' }
function Lancer-Tache { $global:Lances += 'auto' }
function Arreter-Tache([string]$raison) { $global:Lances += "stop:$raison" }
$script:Proc = $null; $script:Boite = $null
foreach ($id in 1, 2, 3, 4, 99) { $raccourcis.SurAppui.Invoke($id) }
Verifier 'Ctrl+Alt+C and the Copilot keys open the instruction bar, Ctrl+Alt+Shift+C is automatic' (($global:Lances -join ',') -eq 'bar,bar,bar,auto') ($global:Lances -join ',')
$global:Lances = @(); $script:Proc = Faux-Proc 0
$raccourcis.SurAppui.Invoke(1); $raccourcis.SurAppui.Invoke(4)
Verifier 'during a task, both shortcuts stop it' (($global:Lances -join ',') -eq 'stop:hotkey,stop:hotkey') ($global:Lances -join ',')
$global:Lances = @(); $script:Proc = $null; $script:Boite = 1
$raccourcis.SurAppui.Invoke(1); $raccourcis.SurAppui.Invoke(4)
Verifier 'while the instruction bar is open, a shortcut starts nothing else' ($global:Lances.Count -eq 0)
$script:Boite = $null
$src = [IO.File]::ReadAllText((Join-Path $Racine 'ClaudeScreen.ps1'), [Text.Encoding]::UTF8)
Verifier 'the two shortcuts are two different key combinations' ($src -match [regex]::Escape('Enregistrer(1, 0x3, 0x43)') -and $src -match [regex]::Escape('Enregistrer(4, 0x7, 0x43)'))

'--- size of the Sessions window'
$zone = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
Verifier 'no saved size: the default one, compact' (-not (Test-Path $FichierFenetre) -and (Lire-TailleFenetre) -eq $TailleDefaut -and $TailleDefaut.Width -le 460 -and $TailleDefaut.Height -le 440)
Enregistrer-TailleFenetre (New-Object System.Drawing.Size 520, 480)
Verifier 'a size chosen by the user is kept in data and read back (as after a restart)' ((Get-Content $FichierFenetre -Raw).Trim() -eq '520,480' -and $FichierFenetre -like '*\data\window.txt' -and (Lire-TailleFenetre) -eq (New-Object System.Drawing.Size ([math]::Min(520, $zone.Width - 20)), ([math]::Min(480, $zone.Height - 20))))
[IO.File]::WriteAllText($FichierFenetre, '90,40')
Verifier 'never too small to use' ((Lire-TailleFenetre) -eq $TailleMin -and $TailleMin.Width -ge 380 -and $TailleMin.Height -ge 300)
[IO.File]::WriteAllText($FichierFenetre, '9000,9000')
$t = Lire-TailleFenetre
Verifier 'never larger than the screen' ($t.Width -le $zone.Width -and $t.Height -le $zone.Height -and $t.Width -ge $TailleMin.Width)
[IO.File]::WriteAllText($FichierFenetre, 'not a size')
Verifier 'an unreadable file: the default size' ((Lire-TailleFenetre) -eq $TailleDefaut)
Enregistrer-TailleFenetre $TailleDefaut
Verifier 'back to the default size: nothing is kept' (-not (Test-Path $FichierFenetre))
} catch { Verifier 'scenario ran to the end' $false ($_.Exception.Message + ' ' + $_.InvocationInfo.PositionMessage) }
