# Hook PreToolUse : bloque toute suppression définitive dans les commandes de Claude,
# et toute écriture dans le dossier de contexte (System-Context, en lecture seule).
[Console]::InputEncoding = [Text.Encoding]::UTF8
$entree = [Console]::In.ReadToEnd() | ConvertFrom-Json

# Outils qui écrivent des fichiers (Edit, Write, MultiEdit, NotebookEdit) : rien dans System-Context.
# Double sécurité avec la règle deny de reglages.json (dont la comparaison de chemins est peu fiable sous Windows).
$fichier = [string]$entree.tool_input.file_path
if (-not $fichier) { $fichier = [string]$entree.tool_input.notebook_path }
if ($fichier) {
    $contexte = $env:ECRAN_CONTEXTE
    if (-not $contexte) { $contexte = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Claude-Travail\System-Context' }
    $base = if ($entree.cwd) { [string]$entree.cwd } else { (Get-Location).Path }
    $cible = [IO.Path]::GetFullPath([IO.Path]::Combine($base, $fichier)).Replace('/', '\').TrimEnd('\') + '\'
    $racine = [IO.Path]::GetFullPath($contexte).Replace('/', '\').TrimEnd('\') + '\'
    if ($cible.StartsWith($racine, [StringComparison]::OrdinalIgnoreCase)) {
        [Console]::Error.WriteLine("Bloqué : $contexte est en lecture seule (documents et instructions de l'utilisateur). Tu peux lire ces fichiers, pas les modifier. Écris tes fichiers ailleurs dans le dossier courant.")
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
        $pc = (Join-Path $PSScriptRoot 'pc.ps1').Replace('\', '/')
        [Console]::Error.WriteLine("Bloqué : les suppressions définitives (et arrêts du PC) sont interdites. Pour enlever un fichier ou dossier, mets-le à la corbeille : $pc corbeille `"CHEMIN`". Si c'était du texte à taper qui a déclenché le blocage, écris-le dans un fichier et utilise ecrire-fichier.")
        exit 2
    }
}
exit 0
