# PreToolUse hook: blocks any permanent deletion in Claude's commands,
# and any write to the context folder (System-Context, read-only).
[Console]::InputEncoding = [Text.Encoding]::UTF8
$entree = [Console]::In.ReadToEnd() | ConvertFrom-Json

# Tools that write files (Edit, Write, MultiEdit, NotebookEdit): nothing inside System-Context.
# Backs up the deny rule in data/settings.json (its path matching is unreliable on Windows).
$fichier = [string]$entree.tool_input.file_path
if (-not $fichier) { $fichier = [string]$entree.tool_input.notebook_path }
if ($fichier) {
    $contexte = $env:ECRAN_CONTEXTE
    if (-not $contexte) { $contexte = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Claude-Work\System-Context' }
    $base = if ($entree.cwd) { [string]$entree.cwd } else { (Get-Location).Path }
    $cible = [IO.Path]::GetFullPath([IO.Path]::Combine($base, $fichier)).Replace('/', '\').TrimEnd('\') + '\'
    $racine = [IO.Path]::GetFullPath($contexte).Replace('/', '\').TrimEnd('\') + '\'
    if ($cible.StartsWith($racine, [StringComparison]::OrdinalIgnoreCase)) {
        [Console]::Error.WriteLine("Blocked: $contexte is read-only (the user's documents and instructions). You can read these files, not modify them. Write your files elsewhere in the current folder.")
        exit 2
    }
    exit 0
}

$commande = [string]$entree.tool_input.command
if (-not $commande) { exit 0 }

$motifs = @(
    '\bRemove-Item\b', '\bRemove-ItemProperty\b', '\bClear-RecycleBin\b', '\bClear-Content\b', '\bClear-Item\b',
    '(^|[\s;&|(`"''])(rm|rmdir|rd|del|erase|ri)(\s|$)',
    '\bFormat-Volume\b', '\bformat(\.com)?\s+[a-z]:', '\bdiskpart\b', '\bvssadmin\b', '\bcipher\b.*\s/w',
    '\.Delete\s*\(', 'DeleteFile', 'DeleteDirectory', '\bunlink\b', '\bshred\b',
    '\bgit\s+clean\b', '\bgit\s+reset\s+--hard\b', '\bgit\s+push\b.*--force',
    '\bwevtutil\s+cl\b', '\bStop-Computer\b', '\bRestart-Computer\b', '\bshutdown(\.exe)?\s'
)
foreach ($motif in $motifs) {
    if ($commande -match $motif) {
        [Console]::Error.WriteLine("Blocked: permanent deletions (and shutting down the PC) are forbidden. To remove a file or folder, send it to the Recycle Bin with the corbeille action of the pc tool.")
        exit 2
    }
}
exit 0
