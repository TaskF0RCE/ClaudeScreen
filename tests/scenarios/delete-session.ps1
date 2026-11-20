# Delete session (Sessions window): everything a session left goes to the Recycle Bin in one folder (tasks,
# notes, title, roles, documents, Claude Code transcripts), the others are untouched, the session in use is
# replaced by an empty one with the same roles, the ghost session is only forgotten.
try {
$script:ChoixModele = 'sonnet'
New-Item -ItemType Directory -Force $ProjetsClaude | Out-Null
$projet = Join-Path $ProjetsClaude 'C--Users-someone-Documents-Claude-Work'
New-Item -ItemType Directory -Force $projet | Out-Null
# A finished task whose stream names the Claude Code session it ran in, with the transcript Claude Code kept.
function Tache-Finie([string]$consigne, [string]$reponse, [string]$sid) {
    $c = Fausse-Capture; Lancer-Tache $c $consigne
    $init = '{"type":"system","subtype":"init","cwd":"x","session_id":"' + $sid + '","tools":[]}'
    Ecrire-Flux $c @($init, (Evenement-Texte $reponse), (Evenement-Fin $reponse))
    [IO.File]::WriteAllText((Join-Path $projet "$sid.jsonl"), "{`"secret`":`"$consigne`"}")
    New-Item -ItemType Directory -Force (Join-Path $projet "$sid\subagents") | Out-Null
    $script:Proc = Faux-Proc 0; Processus-Fini; $script:Titrage = $null
    $c
}
function Sid([int]$n) { '{0:D8}-1111-2222-3333-444444444444' -f $n }
function Paquets { @(Get-ChildItem $global:FauxBac -Directory | Where-Object Name -like 'ClaudeScreen - deleted session*') }
function Session-Par-Id([string]$id) { (Lister-Sessions) | Where-Object { $_.Id -eq $id } }
$source = Join-Path $Racine 'doc-source'
New-Item -ItemType Directory -Force $source | Out-Null
[IO.File]::WriteAllText((Join-Path $source 'course.md'), 'a course')

'--- Claude Code keeps no transcript of the triage and of the title'
Verifier 'triage: --no-session-persistence' ($OptionsTri -match '--no-session-persistence')
$src = [IO.File]::ReadAllText((Join-Path $Racine 'ClaudeScreen.ps1'), [Text.Encoding]::UTF8)
Verifier 'session title: --no-session-persistence' ($src -match 'model haiku \$OptionsClaude --tools Read --effort low --no-session-persistence')

'--- a session that is not the one in use'
$a = Lire-Session
$a1 = Tache-Finie 'first secret task' "Done 1.`nMEMORY: a note of A" (Sid 1)
$a2 = Tache-Finie 'second secret task' 'Done 2.' (Sid 2)
[IO.File]::WriteAllText((Fichier-TitreSession $a), 'OSPF lab: routers', (New-Object System.Text.UTF8Encoding $false))
Enregistrer-RolesSession $a @('Network engineer')
[void](Ajouter-DocumentsSession $a @((Join-Path $source 'course.md')))
Start-Sleep -Milliseconds 1100   # the next session gets another id (the date, to the second)
[void](Nouvelle-Session)
$b = Lire-Session
$b1 = Tache-Finie 'a task of B' "Done B.`nMEMORY: a note of B" (Sid 3)
Enregistrer-RolesSession $b @('Professor')
Verifier 'setup: two sessions, A has its notes put away' ($a -ne $b -and (Test-Path (Fichier-NotesSession $a)) -and (Session-Par-Id $a).Taches.Count -eq 2)
$texte = Texte-Suppression (Session-Par-Id $a)
Verifier 'the question names the session and what goes' ($texte -match '^Delete the session "OSPF lab: routers" now\?' -and $texte -match '2 tasks' -and $texte -match 'Recycle Bin' -and $texte -notmatch 'session in use') $texte
$avant = @(Get-ChildItem $global:FauxBac).Count
Verifier 'deleted' (Supprimer-Session (Session-Par-Id $a))
Verifier 'its tasks are gone, not those of B' (-not (Test-Path $a1.Run) -and -not (Test-Path $a2.Run) -and (Test-Path $b1.Run))
Verifier 'its notes, title, roles and documents are gone' (-not (Test-Path (Fichier-NotesSession $a)) -and -not (Test-Path (Fichier-TitreSession $a)) -and -not (Test-Path (Fichier-RolesSession $a)) -and -not (Test-Path (Dossier-DocumentsSession $a)))
Verifier 'its Claude Code transcripts are gone, not those of B' (-not (Test-Path (Join-Path $projet "$(Sid 1).jsonl")) -and -not (Test-Path (Join-Path $projet (Sid 2))) -and (Test-Path (Join-Path $projet "$(Sid 3).jsonl")))
$p = Paquets
Verifier 'one folder in the Recycle Bin, named after the session' (@(Get-ChildItem $global:FauxBac).Count -eq $avant + 1 -and $p.Count -eq 1 -and $p[0].Name -like "ClaudeScreen - deleted session OSPF lab: routers ($a)*".Replace(':', '')) ($p.Name -join ' | ')
$dedans = $p[0].FullName
Verifier 'everything is in it' (@(Get-ChildItem (Join-Path $dedans 'tasks') -Directory).Count -eq 2 -and @(Get-ChildItem (Join-Path $dedans 'Claude Code transcripts')).Count -eq 4 -and (Test-Path (Join-Path $dedans "$a.md")) -and (Test-Path (Join-Path $dedans "$a.title.txt")) -and (Test-Path (Join-Path $dedans "$a\course.md")))
Verifier 'B is untouched and still in use' ((Lire-Session) -eq $b -and (Get-NoteMemoire $FichierNotes) -match 'a note of B' -and (@(Lire-RolesSession $b) -join '|') -eq 'Professor' -and -not (Session-Par-Id $a))
Verifier 'logged' ((Get-Content $Journal -Raw) -match "Session deleted: $a, 2 task\(s\), everything in the Recycle Bin")

'--- the session in use'
$texte = Texte-Suppression (Session-Par-Id $b)
Verifier 'the question says a new session replaces it' ($texte -match 'This is the session in use: a new, empty session replaces it, with the same roles')
Verifier 'deleted' (Supprimer-Session (Session-Par-Id $b))
$c = Lire-Session
Verifier 'a new empty session is in use, with the same roles' ($c -ne $b -and -not (Get-NoteMemoire $FichierNotes) -and (@(Lire-RolesSession $c) -join '|') -eq 'Professor' -and (Session-Par-Id $c).Taches.Count -eq 0)
Verifier 'its notes went to the Recycle Bin with it' (-not (Test-Path $b1.Run) -and @(Get-ChildItem $global:FauxBac -Recurse -Filter memory.md | Where-Object { (Get-Content $_.FullName -Raw) -match 'a note of B' }).Count -eq 1)
Verifier 'the window says so' ($script:Dernier -match '^Session deleted: Claude starts again from nothing')

'--- not during a task'
$script:Proc = [pscustomobject]@{ HasExited = $false }
Verifier 'refused while a task runs' (-not (Supprimer-Session (Session-Par-Id $c)) -and (Lire-Session) -eq $c)
$script:Proc = $null

'--- Ghost Mode'
$c1 = Tache-Finie 'a task of C' "Done C.`nMEMORY: a note of C" (Sid 4)
[void](Basculer-Fantome $true)
$g = Tache-Finie 'a ghost task' "Ghost.`nMEMORY: a ghost note" (Sid 5)
$avant = @(Get-ChildItem $global:FauxBac).Count
Verifier 'the ghost session is forgotten, nothing goes to the Recycle Bin' ((Supprimer-Session (Lire-SessionFantome)) -and $script:EntreesFantome.Count -eq 0 -and $script:NotesFantome.Count -eq 0 -and @(Get-ChildItem $global:FauxBac).Count -eq $avant -and $script:Fantome)
Verifier 'the persisted session in use is still there' ((Lire-Session) -eq $c -and (Test-Path $c1.Run) -and (Get-NoteMemoire $FichierNotes) -match 'a note of C')
Verifier 'from Ghost Mode, the persisted session in use can be deleted too, notes included' ((Supprimer-Session (Session-Par-Id $c)) -and (Lire-Session) -ne $c -and -not (Get-NoteMemoire $FichierNotes) -and -not (Test-Path $c1.Run) -and $script:Fantome)
[void](Basculer-Fantome $false)

'--- earlier tasks (from before sessions)'
$vieux = Join-Path $Runs '20251101-100000-old'
New-Item -ItemType Directory -Force $vieux | Out-Null
[IO.File]::WriteAllText((Join-Path $vieux 'result.txt'), 'an old result')
$fantomeEnCours = Join-Path $Runs '20251101-110000-ghost'
New-Item -ItemType Directory -Force $fantomeEnCours | Out-Null
Set-Content (Join-Path $fantomeEnCours 'ghost.txt') 'on'
$anciennes = Session-Par-Id ''
Verifier 'listed as Earlier tasks' ($anciennes -and $anciennes.Titre -match '^Earlier tasks')
Verifier 'the question' ((Texte-Suppression $anciennes) -match '^Delete the earlier tasks \(from before sessions\) now\?')
Verifier 'deleted; a ghost task folder is not touched' ((Supprimer-Session $anciennes) -and -not (Test-Path $vieux) -and (Test-Path $fantomeEnCours) -and -not (Session-Par-Id '') -and @(Paquets | Where-Object Name -like '*earlier tasks*').Count -eq 1)
} catch { Verifier "no error ($($_.Exception.Message) at line $($_.InvocationInfo.ScriptLineNumber))" $false }
