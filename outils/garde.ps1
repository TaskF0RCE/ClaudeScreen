# Hook PreToolUse : bloque toute suppression définitive dans les commandes de Claude.
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
        [Console]::Error.WriteLine("Bloqué : les suppressions définitives (et arrêts du PC) sont interdites. Pour enlever un fichier ou dossier, mets-le à la corbeille : $pc corbeille `"CHEMIN`". Si c'était du texte à taper qui a déclenché le blocage, écris-le dans un fichier et utilise ecrire-fichier.")
        exit 2
    }
}
exit 0
