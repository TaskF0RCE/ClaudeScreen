# What Claude said and did during a task, read from the stream that Claude Code writes while it works
# (responses\task.jsonl, one JSON event per line: --output-format stream-json).
# Used to show the steps of a task: while it runs, when it was stopped, and in the History menu.
# Dot-sourced by ClaudeScreen.ps1. Same logic as linux-macos/outils/deroule.py.

$DerouleMaxEtapes = 80     # only the last steps are kept
$DerouleMaxTexte = 400     # characters per step

function Limit-Deroule([string]$texte, [int]$max) {
    $texte = ($texte -replace '\s+', ' ').Trim()
    if ($texte.Length -gt $max) { $texte.Substring(0, $max - 3) + '...' } else { $texte }
}

# One tool call as a short line, or $null for the calls that say nothing to the user (reading, searching).
function Format-OutilDeroule($bloc) {
    $nom = [string]$bloc.name
    $e = $bloc.input
    if ($nom -like 'mcp__pc__*') {
        $actions = @($e.actions | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
        if ($actions.Count) { return '  > ' + (Limit-Deroule ($actions -join ', ') 160) }
        return $null
    }
    if ($nom -in 'Write', 'Edit', 'MultiEdit', 'NotebookEdit') {
        $fichier = if ($e.file_path) { [string]$e.file_path } else { [string]$e.notebook_path }
        if ($fichier) { return '  > file written: ' + (Split-Path $fichier -Leaf) }
        return $null
    }
    if ($nom -in 'PowerShell', 'Bash') { return '  > command: ' + (Limit-Deroule ([string]$e.command) 160) }
    $null
}

# Reads the stream of a task. Returns Etapes (what Claude said and did, in order) and Resultat (its final
# answer, $null while the task is not finished or when it was stopped).
# The file may still be being written: it is opened without locking it, and a half-written line is skipped.
function Read-Deroule([string]$chemin) {
    $etapes = New-Object System.Collections.Generic.List[string]
    $resultat = $null
    if (Test-Path -LiteralPath $chemin) {
        $flux = New-Object System.IO.FileStream $chemin, 'Open', 'Read', 'ReadWrite'
        $lecteur = New-Object System.IO.StreamReader $flux, ([Text.Encoding]::UTF8)
        try {
            while ($null -ne ($ligne = $lecteur.ReadLine())) {
                # The results of the tools hold the screenshots (hundreds of KB per line): never parsed.
                if ($ligne.Length -lt 20 -or $ligne.Length -gt 200000) { continue }
                if ($ligne.StartsWith('{"type":"user"') -or $ligne.StartsWith('{"type":"system"') -or $ligne.StartsWith('{"type":"rate')) { continue }
                try { $o = $ligne | ConvertFrom-Json } catch { continue }
                if ($o.type -eq 'result') { if ("$($o.result)".Trim()) { $resultat = ([string]$o.result).Trim() }; continue }
                if ($o.type -ne 'assistant') { continue }
                foreach ($bloc in @($o.message.content)) {
                    $etape = $null
                    if ($bloc.type -eq 'text') {
                        # The "MEMORY: ..." lines are for the app, not for the user.
                        $texte = (("$($bloc.text)" -split '\r?\n') | Where-Object { $_ -notmatch '^\s*(?:[-*]\s*)?\**MEMORY:' }) -join "`n"
                        if ($texte.Trim()) { $etape = Limit-Deroule $texte $DerouleMaxTexte }
                    } elseif ($bloc.type -eq 'tool_use') { $etape = Format-OutilDeroule $bloc }
                    if ($etape -and ($etapes.Count -eq 0 -or $etapes[$etapes.Count - 1] -ne $etape)) { $etapes.Add($etape) }
                }
            }
        } finally { $lecteur.Dispose() }
    }
    # The last thing Claude says is its final answer: shown as the result, not as a step.
    if ($resultat -and $etapes.Count -and -not $etapes[$etapes.Count - 1].StartsWith('  > ')) {
        $fin = $etapes[$etapes.Count - 1].TrimEnd('.')
        $debut = (Limit-Deroule $resultat $DerouleMaxTexte).TrimEnd('.')
        if ($debut.StartsWith($fin) -or $fin.StartsWith($debut)) { $etapes.RemoveAt($etapes.Count - 1) }
    }
    $omises = 0
    if ($etapes.Count -gt $DerouleMaxEtapes) { $omises = $etapes.Count - $DerouleMaxEtapes; $etapes.RemoveRange(0, $omises) }
    [pscustomobject]@{ Etapes = [string[]]$etapes; Resultat = $resultat; Omises = $omises }
}

# The steps as a text, one per line ('' when there is none).
function Format-Deroule($deroule) {
    if (-not $deroule.Etapes.Count) { return '' }
    $debut = if ($deroule.Omises) { "(... $($deroule.Omises) earlier steps not shown)`n" } else { '' }
    $debut + ($deroule.Etapes -join "`n")
}

# Once a task is over, the stream is only kept for its steps: the lines that hold the screenshots are
# dropped (a long task would otherwise leave tens of MB behind).
function Compress-Deroule([string]$chemin) {
    if (-not (Test-Path -LiteralPath $chemin)) { return }
    $garde = New-Object System.Collections.Generic.List[string]
    foreach ($ligne in [IO.File]::ReadLines($chemin, [Text.Encoding]::UTF8)) {
        if ($ligne.Length -le 200000 -and -not $ligne.StartsWith('{"type":"user"')) { $garde.Add($ligne) }
    }
    [IO.File]::WriteAllLines($chemin, $garde, (New-Object System.Text.UTF8Encoding $false))
}
