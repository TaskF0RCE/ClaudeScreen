# instructions.md (System-Context) and persistent memory. Dot-sourced by ClaudeScreen.ps1 and pc.ps1.
# instructions.md has two parts, split by a line of dashes ($MemoireSeparateur):
#   - above: the user's standing instructions. Neither the app nor Claude ever changes them;
#   - below: Claude's notes, added with "pc.ps1 memoire" while "Persistent memory" is checked
#     in the icon menu, and erased when it is unchecked.
# Comments (<!-- ... -->) are ignored everywhere. Same logic as linux-macos/outils/memoire.py.

$MemoireSeparateur = '---------------------'
# Any line made only of dashes (10 or more) counts, so the user can retype it by hand.
$MemoireLigne = '(?m)^[ \t]*-{10,}[ \t]*\r?$'
$MemoireEntete = "<!-- Claude's notes (persistent memory): erased when the mode is turned off. -->"
$MemoireMaxInstructions = 4000
$MemoireMaxNote = 300
$MemoireMax = 4000

$MemoireGabarit = @"
<!--
Standing instructions for Claude (optional): write them below this comment, one per line.
They are added to every task (Ctrl+Alt+C or Ctrl+Alt+Shift+C).
The instruction typed in the small bar takes priority over this file.
Comments like this one are ignored. You can also drop courses, PDFs or assignments
in this folder: Claude will read them if needed.

Examples:
I'm a BTS SIO student, SISR track. Cisco hardware, Packet Tracer 8.
For quizzes: tick the answers and click Next, but never click "Finish exam".
Always answer in French.

Keep the dashed line below. What you write above it is yours: it is never changed.
Below it, Claude writes its notes while "Persistent memory" is checked in the icon menu;
they are erased when you uncheck it.
-->



$MemoireSeparateur
$MemoireEntete

"@

function Read-FichierMemoire([string]$chemin) {
    if (Test-Path -LiteralPath $chemin) { [IO.File]::ReadAllText($chemin, [Text.Encoding]::UTF8) } else { '' }
}

function Write-FichierMemoire([string]$chemin, [string]$texte) {
    # UTF-8 with BOM and CRLF, like the other files the app writes for the user (Notepad-friendly).
    [IO.File]::WriteAllText($chemin, ($texte -replace '\r?\n', "`r`n"), (New-Object System.Text.UTF8Encoding $true))
}

function Test-MemoireActive([string]$fichierEtat) {
    (Test-Path -LiteralPath $fichierEtat) -and ("$(Get-Content -LiteralPath $fichierEtat -Raw)".Trim() -eq 'on')
}

# User part and memory part as written; Memoire is $null if there is no separator.
function Split-Instruction([string]$texte) {
    $m = [regex]::Match($texte, $MemoireLigne)
    if (-not $m.Success) { return [pscustomobject]@{ Utilisateur = $texte; Memoire = $null } }
    [pscustomobject]@{ Utilisateur = $texte.Substring(0, $m.Index); Memoire = $texte.Substring($m.Index + $m.Length) }
}

# Text without comments or empty lines.
function Format-Instruction([string]$texte) {
    $sans = [regex]::Replace($texte, '(?s)<!--.*?-->', '')
    $lignes = @(($sans -split '\r?\n') | ForEach-Object { $_.TrimEnd() } | Where-Object { $_.Trim() })
    $lignes -join "`n"
}

function Get-SectionVide([string]$utilisateur) {
    $utilisateur.TrimEnd() + "`n`n" + $MemoireSeparateur + "`n" + $MemoireEntete + "`n"
}

# The user's instructions (above the separator), cleaned, 4000 characters at most.
function Get-InstructionUtilisateur([string]$chemin) {
    $texte = Format-Instruction (Split-Instruction (Read-FichierMemoire $chemin)).Utilisateur
    if ($texte.Length -gt $MemoireMaxInstructions) { $texte = $texte.Substring(0, $MemoireMaxInstructions) }
    $texte
}

# Claude's notes (below the separator), cleaned.
function Get-NoteMemoire([string]$chemin) {
    $section = (Split-Instruction (Read-FichierMemoire $chemin)).Memoire
    if ($null -eq $section) { return '' }
    $texte = Format-Instruction $section
    if ($texte.Length -gt $MemoireMax) { $texte = $texte.Substring(0, $MemoireMax) }
    $texte
}

# Adds the separator at the end of the file if it is missing (the user's text is kept).
function Initialize-Memoire([string]$chemin) {
    $texte = Read-FichierMemoire $chemin
    if ($null -eq (Split-Instruction $texte).Memoire) { Write-FichierMemoire $chemin (Get-SectionVide $texte) }
}

# Erases Claude's notes. Everything above the separator stays as it is. $true if notes were erased.
function Clear-Memoire([string]$chemin) {
    $parties = Split-Instruction (Read-FichierMemoire $chemin)
    if ($null -eq $parties.Memoire -or -not (Format-Instruction $parties.Memoire)) { return $false }
    Write-FichierMemoire $chemin (Get-SectionVide $parties.Utilisateur)
    $true
}

# Adds a note at the end of the memory section. Throws if it is empty or too long.
function Add-NoteMemoire([string]$chemin, [string]$note) {
    $note = ($note -replace '\s+', ' ').Trim()
    if (-not $note) { throw 'Usage: memoire "note"' }
    if ($note.Length -gt $MemoireMaxNote) {
        throw "Note too long ($($note.Length) characters, $MemoireMaxNote max): keep one short fact per note."
    }
    if (-not (Test-Path -LiteralPath $chemin)) { throw "$chemin not found." }
    Initialize-Memoire $chemin
    $texte = Read-FichierMemoire $chemin
    if ((Format-Instruction (Split-Instruction $texte).Memoire).Length + $note.Length + 3 -gt $MemoireMax) {
        throw "Memory is full ($MemoireMax characters): the user must turn persistent memory off and on again to empty it. Do not save more notes."
    }
    Write-FichierMemoire $chemin ($texte.TrimEnd() + "`n- " + $note + "`n")
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
    Write-FichierMemoire $nouveau (Get-SectionVide (@($lignes) -join "`n"))
    Remove-Item -LiteralPath $ancien -Force
    $true
}
