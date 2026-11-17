# The title that Haiku gives to a session (asked in the background, with its name by date as a fallback),
# and how long the tasks of the persisted sessions are kept.
try {
$script:ChoixModele = 'sonnet'
function Tache-Finie([string]$consigne, [string]$reponse) {
    $c = Fausse-Capture; Lancer-Tache $c $consigne; Ecrire-Reponse $c $reponse; $script:Proc = Faux-Proc 0; Processus-Fini; $c
}
function Titre-Courant { ((Lister-Sessions) | Where-Object Courante).Titre }

'--- what counts as a title'
Verifier 'a plain title is kept' ((Format-TitreSession 'OSPF on 8 routers') -eq 'OSPF on 8 routers')
Verifier 'quotes, markup, "Title:", a final period and extra lines are removed' ((Format-TitreSession "`n  **Title: `"OSPF on  8 routers.`"**`nHere is why...") -eq 'OSPF on 8 routers')
Verifier 'empty, too short or too long: not a title' ((Format-TitreSession '') -eq '' -and (Format-TitreSession "`n `n") -eq '' -and (Format-TitreSession 'ab') -eq '' -and (Format-TitreSession ('word ' * 30)) -eq '')

'--- the first finished task names the session'
$id = Lire-Session
Verifier 'before any task: its name by number and date' ((Titre-Courant) -match '^Session 1 \(current\)  -  .*  -  0 tasks$') (Titre-Courant)
[void](Tache-Finie 'configure OSPF on the 8 routers' 'The 8 routers run OSPF and the traceroute works.')
Verifier 'a title is asked once, for this session, in the background' ($global:Titrages.Count -eq 1 -and $global:Titrages[0].Id -eq $id -and $script:Titrage.Id -eq $id)
$q = $global:Titrages[0].Question
Verifier 'the question: what was asked and done, the language, a title only' ($q -match 'configure OSPF on the 8 routers' -and $q -match 'The 8 routers run OSPF' -and $q -match [regex]::Escape("in $Langue") -and $q -match 'Answer with the title only')
Verifier 'while Haiku has not answered: the session keeps its name by date, nothing waits' ((Titre-Courant) -match '^Session 1 \(current\)  -  .*  -  1 task$' -and -not $script:Proc) (Titre-Courant)
[void](Tache-Finie '' 'Second task done.')
Verifier 'a second task meanwhile: no second request' ($global:Titrages.Count -eq 1)
Titre-Recu "`"OSPF on 8 routers.`"`n"
Verifier 'the answer of Haiku becomes the name of the session' ((Lire-TitreSession $id) -eq 'OSPF on 8 routers' -and (Titre-Courant) -match '^OSPF on 8 routers \(current\)  -  .*  -  2 tasks$' -and $null -eq $script:Titrage -and [bool]((Get-Content $Journal -Encoding UTF8) -match "Session $id named: OSPF on 8 routers")) (Titre-Courant)
Verifier 'the files of the request are removed' (-not (Get-ChildItem $DossierSessions -Filter '*title-*'))
[void](Tache-Finie '' 'Third task done.')
Verifier 'a named session is not named again' ($global:Titrages.Count -eq 1)
Verifier 'a long result does not make a long question' ((Texte-Titrage 'x' ('z' * 5000)).Length -lt 2000)

'--- when Haiku fails: the name by date stays'
[void](Nouvelle-Session)
$id2 = Lire-Session
Verifier 'the earlier session keeps its title in the list' (((Lister-Sessions) | Where-Object Id -eq $id).Titre -match '^OSPF on 8 routers  -  ')
[void](Tache-Finie '' 'First task of the second session.')
Titre-Recu $null
Verifier 'no answer: no title, the session keeps its name by date, nothing is blocked' ((Lire-TitreSession $id2) -eq '' -and (Titre-Courant) -match '^Session 2 \(current\)  -  ' -and $null -eq $script:Titrage -and [bool]((Get-Content $Journal -Encoding UTF8) -match "Session $id2`: no title from Haiku")) (Titre-Courant)
[void](Tache-Finie '' 'Another task.')
Verifier 'the next finished task asks again' ($global:Titrages.Count -eq 3 -and $global:Titrages[-1].Id -eq $id2)
Titre-Recu ('This is not a title but a very long answer that explains many things. ' * 4)
Verifier 'an answer that is not a title is refused' ((Lire-TitreSession $id2) -eq '')
[void](Tache-Finie '' 'Another task.'); Titre-Recu ''
[void](Tache-Finie '' 'Another task.')
Verifier 'three tries at most per session' ($global:Titrages.Count -eq 4 -and $null -eq $script:Titrage)
$script:EssaisTitre[$id2] = 0
[void](Tache-Finie '' 'Another task.')
# Id -1 is no process: the test must never have anything to kill.
$script:Titrage = [pscustomobject]@{ Proc = ([pscustomobject]@{ HasExited = $false; Id = -1 }); Id = $id2; Sortie = $script:Titrage.Sortie; Question = $script:Titrage.Question; Debut = (Get-Date).AddMinutes(-5) }
Finir-Titrage
Verifier 'Haiku that never answers is given up after 90 s' ($null -eq $script:Titrage -and (Lire-TitreSession $id2) -eq '')
$script:EssaisTitre[$id2] = 0
[void](Tache-Finie '' 'Another task.'); Titre-Recu 'Second topic'
Verifier 'a later try can still name it' ((Titre-Courant) -match '^Second topic \(current\)  -  ')
$c = Fausse-Capture; Lancer-Tache $c ''; Ecrire-Reponse $c ''; $script:Proc = Faux-Proc 1; Processus-Fini
$avant = $global:Titrages.Count
[void](Nouvelle-Session)
$c = Fausse-Capture; Lancer-Tache $c ''; Ecrire-Reponse $c ''; $script:Proc = Faux-Proc 1; Processus-Fini
$c = Fausse-Capture; Lancer-Tache $c ''; $script:Arret = 'hotkey'; $script:Proc = Faux-Proc 1; Processus-Fini
Verifier 'a failed or stopped task does not name a session' ($global:Titrages.Count -eq $avant)

'--- a ghost session is never named'
[void](Basculer-Fantome $true)
$avant = $global:Titrages.Count
[void](Tache-Finie 'a secret instruction' 'Secret answer.')
Verifier 'ghost: nothing is asked to Haiku, nothing is written' ($global:Titrages.Count -eq $avant -and -not (Get-ChildItem $DossierSessions -File | Select-String -Pattern 'Secret|secret' -List))
[void](Basculer-Fantome $false)

'--- how long the tasks are kept'
Verifier 'default: 30 days, nothing saved' ((Lire-Conservation) -eq 30 -and -not (Test-Path $FichierConservation))
Verifier 'the choices of the window' ((@($ChoixConservation.Keys) -join '|') -eq '7 days|30 days|90 days|1 year' -and (@($ChoixConservation.Values) -join '|') -eq '7|30|90|365')
Enregistrer-Conservation 90
Verifier 'a choice is kept in data and read back (as after a restart)' ((Get-Content $FichierConservation -Raw).Trim() -eq '90' -and $FichierConservation -like '*\data\retention.txt' -and (Lire-Conservation) -eq 90)
foreach ($mauvais in 'abc', '0', '-5', '99999', '') { [IO.File]::WriteAllText($FichierConservation, $mauvais); if ((Lire-Conservation) -ne 30) { $rate = $mauvais } }
Verifier 'an unreadable or absurd value: 30 days' (-not $rate) "$rate"
function Vieille-Tache([string]$nom, [string]$session, [int]$jours) {
    $d = Join-Path $Runs $nom; New-Item -ItemType Directory -Force $d | Out-Null
    Set-Content (Join-Path $d 'session.txt') $session
    [IO.File]::WriteAllText((Join-Path $d 'result.txt'), "result of $nom")
    [IO.File]::WriteAllText((Fichier-NotesSession $session), "- note of $session")
    [IO.File]::WriteAllText((Fichier-TitreSession $session), "Title of $session")
    (Get-Item $d).LastWriteTime = (Get-Date).AddDays(-$jours)
    $d
}
$d10 = Vieille-Tache '20200101-100000' '20200101-090000' 10
$d40 = Vieille-Tache '20200102-100000' '20200102-090000' 40
$d100 = Vieille-Tache '20200103-100000' '20200103-090000' 100
Enregistrer-Conservation 90
Nettoyer-Runs
Verifier '90 days: the tasks of 10 and 40 days stay, the one of 100 days goes' ((Test-Path $d10) -and (Test-Path $d40) -and -not (Test-Path $d100))
Verifier 'the notes and the title of a session go with its last task' (-not (Test-Path (Fichier-NotesSession '20200103-090000')) -and -not (Test-Path (Fichier-TitreSession '20200103-090000')) -and (Test-Path (Fichier-TitreSession '20200102-090000')))
Enregistrer-Conservation 30
Nettoyer-Runs
Verifier '30 days: the task of 40 days goes' ((Test-Path $d10) -and -not (Test-Path $d40))
Enregistrer-Conservation 7
Verifier 'a shorter time deletes nothing by itself' (Test-Path $d10)
Nettoyer-Runs
Verifier '7 days, at the next cleanup: the task of 10 days goes, the recent ones stay' (-not (Test-Path $d10) -and @(Get-ChildItem $Runs -Directory).Count -gt 5)
Verifier 'the title of the session in use is not touched by the cleanup' ((Lire-TitreSession $id2) -eq 'Second topic' -or (Test-Path (Fichier-TitreSession $id)))
Enregistrer-Conservation 365
[void](Basculer-Fantome $true)
$g = Tache-Finie '' 'Ghost answer.'
Verifier 'Ghost Mode keeps nothing, whatever the time chosen' (-not (Test-Path $g.Run) -and (Lire-Conservation) -eq 365)
[void](Basculer-Fantome $false)
} catch { Verifier 'scenario ran to the end' $false ($_.Exception.Message + ' ' + $_.InvocationInfo.PositionMessage) }
