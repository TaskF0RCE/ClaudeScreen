# instructions.md and memory.md (System-Context). Dot-sourced by ClaudeScreen.ps1.
#   instructions.md: the user's standing instructions. It is the user's file: once it exists,
#     neither the app nor Claude ever changes it.
#   memory.md: Claude's notes (persistent memory). While "Persistent memory" is checked in the icon
#     menu, the app saves there the "MEMORY: ..." lines found at the end of Claude's final answer.
#     Unchecking the mode sends the file to the Recycle Bin.
# Comments (<!-- ... -->) are ignored in both files. Same logic as linux-macos/outils/memoire.py.

$MemoireMaxInstructions = 4000
$MemoireMaxNote = 300
$MemoireMax = 4000
$MemoireEntete = @"
<!--
Claude's notes (persistent memory), one per line. The app adds them after each task
while "Persistent memory" is checked in the icon menu. You can edit or remove lines.
Unchecking the mode sends this file to the Recycle Bin.
-->
"@

$MemoireGabarit = @"
<!--
Standing instructions for Claude (optional): write them below this comment, one per line.
They are added to every task (Ctrl+Alt+C or Ctrl+Alt+Shift+C).
The instruction typed in the small bar takes priority over this file.
Comments like this one are ignored. You can also drop courses, PDFs or assignments
in this folder: Claude will read them if needed.

Examples:
I'm a second-year computer science student.
For quizzes: tick the answers and click Next, but never click "Finish exam".
Always answer in English.

This file is yours: neither the app nor Claude ever changes it.
Claude's notes (Persistent memory in the icon menu) go to memory.md, next to this file.
-->

"@

function Read-FichierMemoire([string]$chemin) {
    if (Test-Path -LiteralPath $chemin) { [IO.File]::ReadAllText($chemin, [Text.Encoding]::UTF8) } else { '' }
}

function Write-FichierMemoire([string]$chemin, [string]$texte) {
    # UTF-8 with BOM and CRLF, like the other files the app writes for the user (Notepad-friendly).
    [IO.File]::WriteAllText($chemin, ($texte -replace '\r?\n', "`r`n"), (New-Object System.Text.UTF8Encoding $true))
}

# Sends a file to the Recycle Bin (never a permanent deletion).
function Send-Corbeille([string]$chemin) {
    Add-Type -AssemblyName Microsoft.VisualBasic
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($chemin,
        [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
}

# Persistent memory is on unless the user unchecked it (data/memory.txt = off).
function Test-MemoireActive([string]$fichierEtat) {
    -not ((Test-Path -LiteralPath $fichierEtat) -and ("$(Get-Content -LiteralPath $fichierEtat -Raw)".Trim() -eq 'off'))
}

# Text without comments or empty lines.
function Format-Instruction([string]$texte) {
    $sans = [regex]::Replace($texte, '(?s)<!--.*?-->', '')
    $lignes = @(($sans -split '\r?\n') | ForEach-Object { $_.TrimEnd() } | Where-Object { $_.Trim() })
    $lignes -join "`n"
}

# The user's instructions (instructions.md), cleaned, 4000 characters at most.
function Get-InstructionUtilisateur([string]$chemin) {
    $texte = Format-Instruction (Read-FichierMemoire $chemin)
    if ($texte.Length -gt $MemoireMaxInstructions) { $texte = $texte.Substring(0, $MemoireMaxInstructions) }
    $texte
}

# Claude's notes (memory.md), cleaned, 4000 characters at most.
function Get-NoteMemoire([string]$chemin) {
    $texte = Format-Instruction (Read-FichierMemoire $chemin)
    if ($texte.Length -gt $MemoireMax) { $texte = $texte.Substring(0, $MemoireMax) }
    $texte
}

# Creates memory.md (comment only) if it does not exist.
function Initialize-Memoire([string]$chemin) {
    if (-not (Test-Path -LiteralPath $chemin)) { Write-FichierMemoire $chemin ($MemoireEntete + "`n") }
}

# Persistent memory turned off: memory.md goes to the Recycle Bin. $true if it held notes.
function Remove-Memoire([string]$chemin) {
    if (-not (Test-Path -LiteralPath $chemin)) { return $false }
    $notes = Format-Instruction (Read-FichierMemoire $chemin)
    Send-Corbeille $chemin
    [bool]$notes
}

# Splits Claude's final answer: Texte = what the user sees, Notes = the "MEMORY: ..." lines.
function Find-NoteReponse([string]$reponse) {
    $texte = New-Object System.Collections.Generic.List[string]
    $notes = New-Object System.Collections.Generic.List[string]
    foreach ($ligne in ($reponse -split '\r?\n')) {
        if ($ligne -cmatch '^\s*(?:[-*]\s+)?\**MEMORY\**\s*:\s*\**\s*(.*?)\s*$') {
            if ($Matches[1]) { $notes.Add($Matches[1]) }
        } else { $texte.Add($ligne) }
    }
    [pscustomobject]@{ Texte = ($texte -join "`n").Trim(); Notes = @($notes) }
}

# Adds notes at the end of memory.md (created if needed). One line per note, 300 characters at most,
# a note already there is skipped. The notes hold 4000 characters in all: when a new one does not fit, the oldest
# ones (the first lines) are removed to make room. Ajoutees = notes written; Retirees = old notes removed.
function Add-NoteMemoire([string]$chemin, [string[]]$notes) {
    Initialize-Memoire $chemin
    $lignes = New-Object System.Collections.Generic.List[string]
    $lignes.AddRange([string[]]((Read-FichierMemoire $chemin).TrimEnd() -split '\r?\n'))
    $existantes = Format-Instruction ($lignes -join "`n")
    $deja = @($existantes -split "`n" | ForEach-Object { ($_ -replace '^\s*-\s*', '').Trim() })
    $taille = $existantes.Length
    $ajoutees = 0; $retirees = 0
    foreach ($note in $notes) {
        $note = ((($note -replace '<!--|-->', '') -replace '\s+', ' ').Trim() -replace '^-\s*', '')
        if ($note.Length -gt $MemoireMaxNote) { $note = $note.Substring(0, $MemoireMaxNote - 3).TrimEnd() + '...' }
        if (-not $note -or $deja -contains $note) { continue }
        while ($taille + $note.Length + 3 -gt $MemoireMax) {
            $i = $lignes.FindIndex([Predicate[string]] { param($l) $l -match '^\s*-\s' })
            if ($i -lt 0) { break }
            $taille -= $lignes[$i].TrimEnd().Length + 1
            $lignes.RemoveAt($i)
            $retirees++
        }
        $lignes.Add('- ' + $note)
        $taille += $note.Length + 3
        $deja += $note
        $ajoutees++
    }
    if ($ajoutees) { Write-FichierMemoire $chemin (($lignes -join "`n") + "`n") }
    [pscustomobject]@{ Ajoutees = $ajoutees; Retirees = $retirees }
}

# instructions.txt (older versions) -> instructions.md: lines starting with # become comments.
function Convert-AncienneInstruction([string]$ancien, [string]$nouveau) {
    if (-not (Test-Path -LiteralPath $ancien) -or (Test-Path -LiteralPath $nouveau)) { return $false }
    $lignes = foreach ($ligne in ((Read-FichierMemoire $ancien) -split '\r?\n')) {
        if ($ligne.TrimStart().StartsWith('#')) {
            $reste = $ligne.TrimStart().Substring(1).Trim().Replace('--', '- -')
            # The old templates said that # lines are ignored: no longer true in instructions.md.
            $reste = $reste -creplace '^(Lines starting with # are ignored|Les lignes qui commencent par # sont ignor.es)\b.*$', 'Comments like this one are ignored. Write your instructions below, one per line.'
            if ($reste) { "<!-- $reste -->" } else { '' }
        } else { $ligne.TrimEnd() }
    }
    Write-FichierMemoire $nouveau ((@($lignes) -join "`n").TrimEnd() + "`n")
    Send-Corbeille $ancien
    $true
}

# The previous version kept Claude's notes at the end of instructions.md, below a line of dashes.
# Done once: the notes move to memory.md and that end (which the app had added) leaves instructions.md.
# Nothing is changed unless what follows the dashes is the app's own section: its comment, then only "- note" lines.
function Convert-AncienneMemoire([string]$instructions, [string]$memoire) {
    $texte = (Read-FichierMemoire $instructions) -replace '\r\n', "`n"
    $m = [regex]::Match($texte, '(?m)^[ \t]*-{10,}[ \t]*$')
    if (-not $m.Success) { return $false }
    $fin = $texte.Substring($m.Index + $m.Length)
    if (-not $fin.Contains("<!-- Claude's notes (persistent memory)")) { return $false }
    $notes = @((Format-Instruction $fin) -split "`n" | Where-Object { $_ })
    if (@($notes | Where-Object { $_ -notmatch '^\s*- ' }).Count) { return $false }
    if ($notes.Count) { Add-NoteMemoire $memoire $notes | Out-Null }
    $utilisateur = $texte.Substring(0, $m.Index).TrimEnd()
    # The old template explained the dashed line: say where the notes go now.
    $utilisateur = $utilisateur -creplace 'Keep the dashed line below\. What you write above it is yours: it is never changed\.\nBelow it, Claude writes its notes while "Persistent memory" is checked in the icon menu;\nthey are erased when you uncheck it\.', "This file is yours: neither the app nor Claude ever changes it.`nClaude's notes (Persistent memory in the icon menu) go to memory.md, next to this file."
    Write-FichierMemoire $instructions ($utilisateur + "`n")
    $true
}
