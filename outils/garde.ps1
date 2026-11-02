# PreToolUse hook: blocks any permanent deletion in Claude's commands.
[Console]::InputEncoding = [Text.Encoding]::UTF8
$entree = [Console]::In.ReadToEnd() | ConvertFrom-Json
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
        $pc = (Join-Path $PSScriptRoot 'pc.ps1').Replace('\', '/')
        [Console]::Error.WriteLine("Blocked: permanent deletions (and shutting down the PC) are forbidden. To remove a file or folder, send it to the Recycle Bin: $pc corbeille `"PATH`". If text you meant to type triggered the block, write it to a file and use ecrire-fichier.")
        exit 2
    }
}
exit 0
