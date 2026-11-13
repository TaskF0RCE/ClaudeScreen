# A user coming from an old version: folder renamed, notes moved to memory.md, then a whole task
# (prompt, triage, result, memory notes) and the Persistent memory menu.
try {
'--- startup'
Verifier 'work folder is Claude-Work' ($Travail -eq (Join-Path $Documents 'Claude-Work')) $Travail
Verifier 'old folder is gone' (-not (Test-Path (Join-Path $Documents 'Claude-Travail')))
Verifier 'files followed the rename' (Test-Path (Join-Path $Travail 'report.txt'))
$ins = [IO.File]::ReadAllText($FichierInstructions, [Text.Encoding]::UTF8)
Verifier 'instructions.md: no dashed line left' ($ins -notmatch '(?m)^-{10,}')
Verifier 'instructions.md: no notes left' ($ins -notmatch 'Dupont|Budget|persistent memory\)')
Verifier 'instructions.md: stale lines replaced' (($ins -notmatch 'dashed line') -and ($ins -match 'This file is yours') -and ($ins -match 'go to memory\.md'))
Verifier 'instructions.md: ends with the comment' ($ins.TrimEnd().EndsWith('-->')) $ins.Substring([math]::Max(0, $ins.Length - 40))
Verifier 'instructions.md: no instruction (comments only)' ((Get-InstructionUtilisateur $FichierInstructions) -eq '')
$mem = Get-NoteMemoire $FichierNotes
Verifier 'memory.md: the 3 notes moved' ((@($mem -split "`n")).Count -eq 3 -and $mem -match 'Dupont' -and $mem -match 'Budget' -and $mem -match 'Lab 3') $mem
Verifier 'memory.md: starts with its comment' ([IO.File]::ReadAllText($FichierNotes, [Text.Encoding]::UTF8).StartsWith('<!--'))
Verifier 'guide replaced by the new one, old one in the bin' ((Get-FileHash $FichierLisezMoi).Hash -eq (Get-FileHash (Join-Path $Outils 'System-Context-README.md')).Hash -and @(Get-ChildItem $global:FauxBac -Filter 'README.md.*').Count -eq 1)
$lignesJournal = Get-Content $Journal -Encoding UTF8
Verifier 'log: rename' ([bool]($lignesJournal -match 'Claude-Travail folder renamed to Claude-Work'))
Verifier 'log: notes moved' ([bool]($lignesJournal -match 'notes moved to memory.md'))

'--- settings.json'
$r = Get-Content $Reglages -Raw -Encoding UTF8 | ConvertFrom-Json
Verifier 'allow: files, pc tool, PowerShell' (($r.permissions.allow -join '|') -eq 'Read|Glob|Grep|mcp__pc|PowerShell') ($r.permissions.allow -join '|')
Verifier 'deny: web and System-Context' (($r.permissions.deny -join '|') -match 'WebFetch\|WebSearch' -and ($r.permissions.deny -join '|') -match '/Claude-Work/System-Context/\*\*') ($r.permissions.deny -join '|')
Verifier 'hooks: commands and file writes go through garde.ps1' (@($r.hooks.PreToolUse).Count -eq 2 -and $r.hooks.PreToolUse[0].matcher -eq 'PowerShell|Bash' -and $r.hooks.PreToolUse[0].hooks[0].command -match 'garde\.ps1')

'--- prompt'
Copy-Item (Join-Path $Racine 'examples\packet-tracer.md') $Contexte
$cap = Fausse-Capture
Lancer-Tache $cap 'connect R0 and R1'
Verifier 'triage started with the light options' ($global:Appels[-1] -eq 'haiku|triage|--tools Read --effort low') ($global:Appels[-1])
$p = Lire-Prompt $cap
Verifier 'prompt: chained clicks only on what was already seen' ($p -match 'Chain only clicks on things you have already seen' -and $p -match 'says at which action another window came to the front')
Verifier 'prompt: pc tool (MCP)' ($p -match 'the "pc" tool \(mcp__pc__pc\)' -and $p -match '(?m)^  relier X1 Y1 X2 Y2 ')
$appTxt = $p.Substring($p.IndexOf('1. Find what is being asked'))
Verifier 'prompt: nothing specific to a software, a field or a profile' ($appTxt -notmatch 'Packet Tracer|GNS3|OSPF|subnetting|VLAN|Cisco|BTS|student|course') ([regex]::Matches($appTxt, '.{0,30}(Packet Tracer|GNS3|OSPF|subnetting|VLAN|Cisco|BTS|student|course).{0,20}') -join ' | ')
Verifier 'prompt: answer in the language of the computer' ($p -match [regex]::Escape("short, in $Langue (the language of this computer) unless the user's instructions"))
Verifier 'prompt: generic set-up rule' ($p -match 'Do not add, move or delete what the user has set up on screen')
Verifier 'prompt: example file listed as a document' ($p -match [regex]::Escape((Join-Path $Contexte 'packet-tracer.md') + '  ('))
Verifier 'prompt: notes from memory.md' ($p -match 'Persistent memory is ON' -and $p -match 'Dupont' -and $p -match 'starting with "MEMORY: "')
Verifier 'prompt: work folder' ($p -match [regex]::Escape("current folder: $Travail"))
Verifier 'prompt: instruction of the bar' ($p -match 'connect R0 and R1')
Verifier 'prompt: memory.md and instructions.md not listed as documents' ($p -notmatch 'memory\.md  \(' -and $p -notmatch 'instructions\.md  \(')
$tri = Lire-Prompt $cap 'triage'
Verifier 'triage: nothing specific either' ($tri -notmatch 'Packet Tracer|GNS3|subnetting|VLAN|course')
Ecrire-Reponse $cap 'SONNET' 'triage'
$script:Proc = Faux-Proc 0
Processus-Fini
Verifier 'task started with the MCP config of this task' ($global:Appels[-1] -eq "sonnet|task|--tools Read,Write,Edit,Glob,Grep --mcp-config `"$(Join-Path $cap.Run 'mcp.json')`"") ($global:Appels[-1])
$j = Get-Content (Join-Path $cap.Run 'mcp.json') -Raw | ConvertFrom-Json
Verifier 'mcp.json starts mcp.ps1 for this task' ($j.mcpServers.pc.command -eq 'powershell.exe' -and $j.mcpServers.pc.args[-1] -eq (Join-Path $Outils 'mcp.ps1') -and $j.mcpServers.pc.env.ECRAN_RUN -eq $cap.Run -and $j.mcpServers.pc.env.ECRAN_CONTEXTE -eq $Contexte -and [IO.File]::ReadAllBytes((Join-Path $cap.Run 'mcp.json'))[0] -eq 123)

'--- end of a task'
Ecrire-Reponse $cap "R0 and R1 are linked.`nThe link is green.`n`nMEMORY: R0 and R1 linked with a crossover cable on 10/11`n- **MEMORY:** PC0 not addressed yet`nMEMORY: Budget sheet 2026: columns A to F checked on 09/11`n"
$script:Proc = Faux-Proc 0
Processus-Fini
Verifier 'result: duration shown, MEMORY lines hidden' ($script:Dernier -match '^\[sonnet, \d+ s\] ' -and (Sans-Duree $script:Dernier) -eq "[sonnet] R0 and R1 are linked.`nThe link is green.") $script:Dernier
$mem = Get-NoteMemoire $FichierNotes
Verifier 'memory.md: 2 new notes, duplicate skipped' ((@($mem -split "`n")).Count -eq 5 -and $mem -match 'crossover' -and $mem -match '(?m)^- PC0 not addressed yet$') $mem
Verifier 'log: notes saved, duration' ([bool]((Get-Content $Journal -Encoding UTF8) -match 'Persistent memory: 2 note\(s\) saved') -and [bool]((Get-Content $Journal -Encoding UTF8) -match 'Task finished \(code 0, \d+ s\)'))
Verifier 'instructions.md untouched by the task' ([IO.File]::ReadAllText($FichierInstructions, [Text.Encoding]::UTF8) -eq $ins)
Verifier 'tooltip named Claude-Work' ($icone.Text.StartsWith('Claude-Work - done: ')) $icone.Text

'--- memory full: the oldest notes make room'
$grosses = 1..16 | ForEach-Object { "note $_ " + ('x' * 280) }
$a = Add-NoteMemoire $FichierNotes $grosses
$mem = Get-NoteMemoire $FichierNotes
Verifier 'all the new notes are written, old ones removed' ($a.Ajoutees -eq 16 -and $a.Retirees -ge 5) "$($a.Ajoutees) $($a.Retirees)"
Verifier 'never more than 4000 characters' ($mem.Length -le 4000 -and $mem.Length -gt 3000) $mem.Length
Verifier 'the oldest are gone, the newest are kept' ($mem -notmatch 'Dupont' -and $mem -notmatch '(?m)^- note 1 x' -and $mem -match '(?m)^- note 16 x')
Verifier 'the comment at the top of memory.md is kept' ([IO.File]::ReadAllText($FichierNotes, [Text.Encoding]::UTF8).StartsWith('<!--'))
$cap2 = Fausse-Capture
$script:ChoixModele = 'sonnet'
Lancer-Tache $cap2 ''
Ecrire-Reponse $cap2 ("Done.`nMEMORY: the newest note " + ('y' * 250))
$script:Proc = Faux-Proc 0
Processus-Fini
Verifier 'a task on a full memory: note saved, nothing said to the user' ((Sans-Duree $script:Dernier) -eq '[sonnet] Done.' -and (Get-NoteMemoire $FichierNotes) -match '(?m)^- the newest note y+$' -and [bool]((Get-Content $Journal -Encoding UTF8) -match '1 note\(s\) saved, \d+ oldest removed')) $script:Dernier

'--- Persistent memory menu'
$libelles = @($menu.Items | ForEach-Object { $_.Text })
Verifier 'menu: Open the Claude-Work folder' ($libelles -contains 'Open the Claude-Work folder') ($libelles -join ' | ')
Verifier 'menu: memory checked at start' ($menuMemoire.Checked)
$menuMemoire.PerformClick()
Verifier 'unchecked: memory.md emptied (comment kept), state off' ((Get-NoteMemoire $FichierNotes) -eq '' -and [IO.File]::ReadAllText($FichierNotes, [Text.Encoding]::UTF8).StartsWith('<!--') -and -not $script:Memoire -and (Get-Content $FichierMemoire -Raw).Trim() -eq 'off')
Verifier 'unchecked: the cleared notes are kept once in data, nothing goes to the bin' ((Get-NoteMemoire $FichierNotesAvant) -match 'the newest note y+' -and $FichierNotesAvant -like '*\data\memory-previous.md' -and @(Get-ChildItem $global:FauxBac -Filter 'memory*').Count -eq 0 -and [bool]((Get-Content $Journal -Encoding UTF8) -match 'Persistent memory: off \(notes cleared'))
Verifier 'unchecked: instructions.md untouched' ([IO.File]::ReadAllText($FichierInstructions, [Text.Encoding]::UTF8) -eq $ins)
$cap3 = Fausse-Capture
Lancer-Tache $cap3 ''
Verifier 'memory off: nothing about memory in the prompt' ((Lire-Prompt $cap3) -notmatch 'MEMORY|Persistent memory')
Ecrire-Reponse $cap3 "Done.`nMEMORY: must not be read"
$script:Proc = Faux-Proc 0
Processus-Fini
Verifier 'memory off: answer shown as is, nothing saved' ($script:Dernier -match 'MEMORY: must not' -and (Get-NoteMemoire $FichierNotes) -eq '') $script:Dernier
$menuMemoire.PerformClick()
Verifier 'checked again: memory.md is there and empty' ((Test-Path $FichierNotes) -and (Get-NoteMemoire $FichierNotes) -eq '' -and $script:Memoire)
$menuMemoire.PerformClick()
Verifier 'unchecked with no notes: the kept notes are not replaced by an empty file' ((Get-NoteMemoire $FichierNotesAvant) -match 'the newest note y+' -and [bool]((Get-Content $Journal -Encoding UTF8) -match 'Persistent memory: off \(no notes\)'))
$menuMemoire.PerformClick()
Ecrire-Reponse $cap3 ''
$script:Proc = Faux-Proc 1
Processus-Fini
Verifier 'failed task: error shown' ((Sans-Duree $script:Dernier) -match '^The task failed \(code 1, sonnet\)') $script:Dernier
} catch { Verifier 'scenario ran to the end' $false ($_.Exception.Message + ' ' + $_.InvocationInfo.PositionMessage) }
