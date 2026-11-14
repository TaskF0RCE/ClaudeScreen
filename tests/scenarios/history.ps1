# The steps of a task (what Claude said and did): shown while it runs, kept when it is stopped,
# saved with the result, and listed in the History menu.
try {
'--- a task in progress'
$script:ChoixModele = 'sonnet'
Verifier 'no task yet: the icon shows the welcome text' ((Texte-Resultat) -match '^No task yet')
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

'--- History menu'
Get-ChildItem $Runs -Directory | Remove-Item -Recurse -Force
Remplir-MenuHistorique
Verifier 'no task: one greyed line' ($menuHistorique.DropDownItems.Count -eq 1 -and -not $menuHistorique.DropDownItems[0].Enabled)
foreach ($i in 1..18) {
    $dossier = Join-Path $Runs ('20261113-16{0:D2}00' -f $i)
    New-Item -ItemType Directory -Force $dossier | Out-Null
    if ($i -ne 17) { [IO.File]::WriteAllText((Join-Path $dossier 'result.txt'), "[sonnet, 12 s] Result & number $i`nsecond line $('z' * 100)") }
}
Remplir-MenuHistorique
$libelles = @($menuHistorique.DropDownItems | ForEach-Object { $_.Text })
Verifier 'the 15 last tasks, newest first, the one without a result skipped' ($libelles.Count -eq 15 -and $libelles[0] -match 'number 18' -and $libelles[1] -match 'number 16' -and $libelles[-1] -match 'number 3 ') ($libelles -join ' | ')
Verifier 'label: date and time, start of the result on one line' ($libelles[0] -match '13.*16:18' -and $libelles[0] -match 'Result && number 18 second line z+\.\.\.$' -and $libelles[0].Length -lt 110) $libelles[0]
Verifier 'the item opens the whole result of that task' ((Test-Path $menuHistorique.DropDownItems[0].Tag) -and $menuHistorique.DropDownItems[0].Tag -like '*20261113-161800\result.txt')
Verifier 'History is in the menu, after Last result' (@($menu.Items | ForEach-Object { $_.Text })[0..1] -join '|' -eq 'Last result|History')
} catch { Verifier 'scenario ran to the end' $false ($_.Exception.Message + ' ' + $_.InvocationInfo.PositionMessage) }
