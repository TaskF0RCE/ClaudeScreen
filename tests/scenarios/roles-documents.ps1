# Coming from 0.9 (contexts), the roles of each session, the documents of each session, and both in Ghost Mode.
try {
$script:ChoixModele = 'sonnet'
$idAvant = '20261110-090000'
function Tache([string]$consigne = '') { $c = Fausse-Capture; Lancer-Tache $c $consigne; $c }
function Finir($c, [string]$reponse = 'Done.') { Ecrire-Reponse $c $reponse; $script:Proc = Faux-Proc 0; Processus-Fini }

'--- contexts of 0.9 become roles'
$noms = @(Lister-Roles)
Verifier 'Roles folder created, General assistant first' ($noms[0] -eq 'General assistant' -and $noms -contains 'Network engineer' -and $noms -contains 'Professor') ($noms -join ' | ')
Verifier 'the old Contexts folder is in the Recycle Bin, not deleted' (-not (Test-Path $AncienDossierContextes) -and @(Get-ChildItem $global:FauxBac -Directory | Where-Object Name -like 'Contexts.*').Count -eq 1)
Verifier 'context files left as installed do not come back as roles' (-not (Test-Path (Join-Path $DossierRoles 'Networking.md')) -and -not (Test-Path (Join-Path $DossierRoles 'Default.md')))
Verifier 'a context the user changed is kept as a role, under its name' ((Get-InstructionUtilisateur (Join-Path $DossierRoles 'Studies.md')) -match 'BTS SIO')
Verifier 'a context the user wrote is kept as a role' ((Get-InstructionUtilisateur (Join-Path $DossierRoles 'My job.md')) -match 'accountant')
Verifier 'the active context (Networking) is the role of the current session (Network engineer)' ((Lire-Session) -eq $idAvant -and (@(Lire-RolesSession $idAvant) -join '|') -eq 'Network engineer' -and -not (Test-Path $FichierContexte))
Verifier 'menu: Roles: Network engineer' ($menuRoles.Text -eq 'Roles: Network engineer') $menuRoles.Text
Verifier 'logged' ([bool]((Get-Content $Journal -Encoding UTF8) -match 'Contexts replaced by Roles') -and [bool]((Get-Content $Journal -Encoding UTF8) -match 'Context Networking: the current session has the role Network engineer'))
$c = Tache
$p = Lire-Prompt $c
Verifier 'prompt: the role of the session, its text, on top of the standing instructions' ($p -match 'Roles of this session: Network engineer \(chosen by the user for this session\)\. Work in this role' -and $p -match 'Work out the addressing first' -and $p -notmatch 'Active context')
Finir $c
$script:ChoixModele = 'auto'
$c = Tache
Verifier 'triage too' ((Lire-Prompt $c 'triage') -match '(?m)^Roles of this session: Network engineer\.')
$script:ChoixModele = 'sonnet'

'--- roles belong to a session'
Basculer-Role $idAvant 'Professor'
Verifier 'several roles for one session' ((@(Lire-RolesSession $idAvant) -join '|') -eq 'Network engineer|Professor' -and (Lire-RolesActifs).Noms -eq 'Network engineer, Professor')
[void](Nouvelle-Session)
$id2 = Lire-Session
Verifier 'a new session starts with the roles of the previous one' ((@(Lire-RolesSession $id2) -join '|') -eq 'Network engineer|Professor')
Basculer-Role $id2 'Professor'
Basculer-Role $id2 'Security analyst'
Verifier 'changing them there does not change the earlier session' ((@(Lire-RolesSession $id2) -join '|') -eq 'Network engineer|Security analyst' -and (@(Lire-RolesSession $idAvant) -join '|') -eq 'Network engineer|Professor')
$c = Tache; $p = Lire-Prompt $c; Finir $c
Verifier 'the task gets the roles of its session' ($p -match 'Roles of this session: Network engineer, Security analyst' -and $p -match 'Defensive work only' -and $p -notmatch 'Professor: the user')
[void](Reprendre-Session $idAvant)
Verifier 'resuming a session brings its roles back' ((Lire-RolesActifs).Noms -eq 'Network engineer, Professor')
[void](Reprendre-Session $id2)
Basculer-Role $id2 'General assistant'
Verifier 'General assistant = no specific role: nothing kept for the session' ((Lire-RolesActifs).Noms -eq 'General assistant' -and -not (Test-Path (Fichier-RolesSession $id2)))
Basculer-Role $id2 'Network engineer'
Set-Content (Fichier-RolesSession $id2) "Network engineer`r`nNo such role`r`n`r`nNetwork engineer"
Verifier 'a role whose file is gone, an empty line or a repeat is ignored' ((@(Lire-RolesSession $id2) -join '|') -eq 'Network engineer')

'--- roles in Ghost Mode'
[void](Basculer-Fantome $true)
Verifier 'the ghost session starts with the roles of the session it comes from' ((Lire-RolesActifs).Noms -eq 'Network engineer')
$fichiers = @(Get-ChildItem $DossierSessions -File | ForEach-Object { $_.FullName + '=' + $_.LastWriteTime.Ticks })
Basculer-Role '' 'Professor'
Verifier 'its roles change in memory only' ((Lire-RolesActifs).Noms -eq 'Network engineer, Professor' -and (@(Get-ChildItem $DossierSessions -File | ForEach-Object { $_.FullName + '=' + $_.LastWriteTime.Ticks }) -join '|') -eq ($fichiers -join '|') -and $menuRoles.Text -match '^Roles' )
Remplir-MenuRoles
Verifier 'the icon menu shows the roles of the ghost session' ($menuRoles.Text -eq 'Roles: Network engineer, Professor') $menuRoles.Text
$c = Tache; $p = Lire-Prompt $c; Finir $c
Verifier 'a ghost task gets the ghost roles' ($p -match 'Roles of this session: Network engineer, Professor')
[void](Nouvelle-Session)
Verifier 'a new ghost session keeps them' ((Lire-RolesActifs).Noms -eq 'Network engineer, Professor')
[void](Basculer-Fantome $false)
Verifier 'back to Persisted Memory: the roles of the persisted session, untouched' ((Lire-RolesActifs).Noms -eq 'Network engineer')

'--- documents of a session'
$source = Join-Path $Racine 'source-docs'
New-Item -ItemType Directory -Force $source | Out-Null
[IO.File]::WriteAllText((Join-Path $source 'course OSPF.md'), "# OSPF`nAreas, LSA, cost.")
[IO.File]::WriteAllText((Join-Path $source 'lab.txt'), 'Lab 4: 8 routers, area 0.')
[IO.File]::WriteAllText((Join-Path $Contexte 'global notes.md'), 'For every task.')
Verifier 'no document yet' (@(Lister-DocumentsSession $id2).Count -eq 0)
$n = Ajouter-DocumentsSession $id2 @((Join-Path $source 'course OSPF.md'), (Join-Path $source 'lab.txt'), (Join-Path $source 'missing.pdf'))
$n2 = Ajouter-DocumentsSession $id2 @((Join-Path $source 'lab.txt'))
$docs = @(Lister-DocumentsSession $id2 | ForEach-Object { $_.Name })
Verifier 'added: copies in System-Context\Session documents\<id>, a second file of the same name gets a number' ($n -eq 2 -and $n2 -eq 1 -and ($docs -join '|') -eq 'course OSPF.md|lab (2).txt|lab.txt' -and (Dossier-DocumentsSession $id2) -eq (Join-Path $Contexte "Session documents\$id2")) ($docs -join '|')
Verifier 'the originals are not touched' ((Test-Path (Join-Path $source 'course OSPF.md')) -and (Test-Path (Join-Path $source 'lab.txt')))
$c = Tache; $p = Lire-Prompt $c; Finir $c
$iSession = $p.IndexOf('Documents of this session'); $iAutres = $p.IndexOf('Context documents provided by the user')
Verifier 'prompt: the documents of the session, first, then the others' ($iSession -ge 0 -and $iAutres -gt $iSession -and $p -match [regex]::Escape((Join-Path (Dossier-DocumentsSession $id2) 'course OSPF.md')) -and $p -match [regex]::Escape((Join-Path $Contexte 'global notes.md')))
Verifier 'prompt: on top of the standing instructions, never instead' ($p -match 'on top of the standing instructions and the other documents, never instead of them')
Verifier 'prompt: a document of the session is not listed twice' ([regex]::Matches($p, [regex]::Escape('course OSPF.md')).Count -eq 1)
$c = Tache; $p = Lire-Prompt $c; Finir $c
Verifier 'the next task of the session gets them again' ($p -match [regex]::Escape((Join-Path (Dossier-DocumentsSession $id2) 'lab.txt')))
[void](Reprendre-Session $idAvant)
$c = Tache; $p = Lire-Prompt $c; Finir $c
Verifier 'another session: not its documents, still the global ones' ($p -cnotmatch 'Documents of this session' -and $p -notmatch 'course OSPF' -and $p -match 'global notes\.md')
[void](Reprendre-Session $id2)
Retirer-DocumentSession $id2 (Join-Path (Dossier-DocumentsSession $id2) 'lab (2).txt')
Verifier 'removed: to the Recycle Bin' (@(Lister-DocumentsSession $id2).Count -eq 2 -and @(Get-ChildItem $global:FauxBac -Filter 'lab (2).txt.*').Count -eq 1)
Retirer-DocumentSession $id2 (Join-Path $source 'lab.txt')
Verifier 'never a file outside the documents of the session' (Test-Path (Join-Path $source 'lab.txt'))
# A session with documents and no task: listed, so that it can be resumed.
[void](Nouvelle-Session)
$id3 = Lire-Session
[void](Ajouter-DocumentsSession $id3 @((Join-Path $source 'lab.txt')))
[void](Nouvelle-Session)
$s3 = (Lister-Sessions) | Where-Object Id -eq $id3
Verifier 'a session with documents but no task stays in the list' ($null -ne $s3 -and $s3.Titre -match '0 tasks$') "$($s3.Titre)"

'--- documents in Ghost Mode'
[void](Basculer-Fantome $true)
[void](Ajouter-DocumentsSession '' @((Join-Path $source 'course OSPF.md')))
$dossierFantome = Dossier-DocumentsSession ''
Verifier 'a ghost session has its own documents' ((Test-Path (Join-Path $dossierFantome 'course OSPF.md')) -and @(Lister-DocumentsSession '').Count -eq 1)
$c = Tache; $p = Lire-Prompt $c; Finir $c
Verifier 'a ghost task gets them, not those of the persisted session' ($p -match [regex]::Escape((Join-Path $dossierFantome 'course OSPF.md')) -and $p -notmatch [regex]::Escape((Dossier-DocumentsSession $id2)))
$bac = @(Get-ChildItem $global:FauxBac).Count
[void](Nouvelle-Session)
Verifier 'a new ghost session: they are deleted, not kept in the Recycle Bin' (-not (Test-Path $dossierFantome) -and @(Get-ChildItem $global:FauxBac).Count -eq $bac)
[void](Ajouter-DocumentsSession '' @((Join-Path $source 'lab.txt')))
[void](Basculer-Fantome $false)
Verifier 'back to Persisted Memory: deleted too' (-not (Test-Path $dossierFantome) -and @(Get-ChildItem $global:FauxBac).Count -eq $bac)
[void](Basculer-Fantome $true)
[void](Ajouter-DocumentsSession '' @((Join-Path $source 'lab.txt')))
Vider-DocumentsFantome   # what the next start does: the ghost session of the last run is over
Verifier 'after a restart: deleted' (-not (Test-Path $dossierFantome))
[void](Basculer-Fantome $false)
Verifier 'the ghost session never wrote roles or documents of its own on disk' (-not (Get-ChildItem $DossierSessions -File | Where-Object { $_.Name -notmatch '^\d{8}-\d{6}' }))

'--- documents expire with their session'
Enregistrer-Conservation 30
$vieux = '20200101-090000'
[void](Ajouter-DocumentsSession $vieux @((Join-Path $source 'lab.txt')))
Enregistrer-RolesSession $vieux @('Professor')
(Get-Item (Dossier-DocumentsSession $vieux)).LastWriteTime = (Get-Date).AddDays(-40)
(Get-Item (Dossier-DocumentsSession $id3)).LastWriteTime = (Get-Date).AddDays(-5)
Nettoyer-Runs
Verifier 'old session, no task, old documents: they go to the Recycle Bin with its roles' (-not (Test-Path (Dossier-DocumentsSession $vieux)) -and @(Get-ChildItem $global:FauxBac -Directory | Where-Object Name -like "$vieux.*").Count -eq 1 -and -not (Test-Path (Fichier-RolesSession $vieux)))
Verifier 'recent documents keep their session' ((Test-Path (Dossier-DocumentsSession $id3)) -and (Test-Path (Fichier-RolesSession $id3)))
Verifier 'a session with tasks keeps its documents' (@(Lister-DocumentsSession $id2).Count -eq 2)

'--- Haiku is not asked about a ghost session, the title question has no document in it'
Verifier 'the title question only holds the first task' (-not ($global:Titrages | Where-Object { $_.Question -match 'course OSPF|Session documents' }))
} catch { Verifier 'scenario ran to the end' $false ($_.Exception.Message + ' ' + $_.InvocationInfo.PositionMessage) }
