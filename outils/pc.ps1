# PC control for Claude. Coordinates are in screenshot pixels (see screen.json).
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Action,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Valeurs
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'natif.ps1')
. (Join-Path $PSScriptRoot 'pdf.ps1')
[ClaudeScreen.Natif]::DpiAware()
# Smooth mode (icon menu): human-like mouse moves and typing. Read at every action, so it applies at once.
$fichierSmooth = Join-Path $PSScriptRoot '..\data\smooth.txt'
[ClaudeScreen.Natif]::Doux = (Test-Path $fichierSmooth) -and ("$(Get-Content $fichierSmooth -Raw)".Trim() -eq 'on')

$run = $env:ECRAN_RUN
if (-not $run) { throw 'ECRAN_RUN is not set: this script must be started by ClaudeScreen.' }
$ecran = Get-Content (Join-Path $run 'screen.json') -Raw | ConvertFrom-Json
$images = Join-Path $run 'images'   # every image of the task: screenshots, zooms, PDF pages
New-Item -ItemType Directory -Force $images | Out-Null

function Nombre([int]$i) {
    if ($Valeurs.Count -le $i) { throw "Missing argument $($i + 1) for '$Action'." }
    [double]::Parse($Valeurs[$i].Replace(',', '.'), [Globalization.CultureInfo]::InvariantCulture)
}
function X([double]$x) { [int][math]::Round($ecran.gauche + $x * $ecran.echelle) }
function Y([double]$y) { [int][math]::Round($ecran.haut + $y * $ecran.echelle) }

$touches = @{
    ctrl = 0x11; control = 0x11; alt = 0x12; shift = 0x10; maj = 0x10; win = 0x5B
    enter = 0x0D; entree = 0x0D; return = 0x0D; tab = 0x09; esc = 0x1B; escape = 0x1B; echap = 0x1B
    backspace = 0x08; delete = 0x2E; suppr = 0x2E; insert = 0x2D; space = 0x20; espace = 0x20
    home = 0x24; end = 0x23; pageup = 0x21; pagedown = 0x22
    left = 0x25; up = 0x26; right = 0x27; down = 0x28; gauche = 0x25; haut = 0x26; droite = 0x27; bas = 0x28
}

switch ($Action.ToLower()) {
    'capture' {
        $n = @(Get-ChildItem $images -Filter 'screenshot-*.png').Count + 1
        $png = Join-Path $images ('screenshot-{0:D2}.png' -f $n)
        [ClaudeScreen.Natif]::Capture($png, $ecran.gauche, $ecran.haut, $ecran.largeurEcran, $ecran.hauteurEcran, $ecran.echelle)
        "Screenshot: $png ($($ecran.largeur)x$($ecran.hauteur) px)"
    }
    'zoom' {
        # zoom X Y W H: enlarges an area of the screenshot to read small details (read-only).
        $n = @(Get-ChildItem $images -Filter 'zoom-*.png').Count + 1
        $png = Join-Path $images ('zoom-{0:D2}.png' -f $n)
        $l = [int][math]::Round((Nombre 2) * $ecran.echelle); $h = [int][math]::Round((Nombre 3) * $ecran.echelle)
        [ClaudeScreen.Natif]::Capture($png, (X (Nombre 0)), (Y (Nombre 1)), $l, $h, 1.0)
        "Zoom: $png (read-only, do not use its coordinates to click)"
    }
    'clic'      { [ClaudeScreen.Natif]::Clic((X (Nombre 0)), (Y (Nombre 1)), $false, 1); 'OK' }
    'doubleclic' { [ClaudeScreen.Natif]::Clic((X (Nombre 0)), (Y (Nombre 1)), $false, 2); 'OK' }
    'clicdroit' { [ClaudeScreen.Natif]::Clic((X (Nombre 0)), (Y (Nombre 1)), $true, 1); 'OK' }
    'survol'    { [ClaudeScreen.Natif]::Deplacer((X (Nombre 0)), (Y (Nombre 1))); 'OK' }
    'glisser'   { [ClaudeScreen.Natif]::Glisser((X (Nombre 0)), (Y (Nombre 1)), (X (Nombre 2)), (Y (Nombre 3))); 'OK' }
    'defiler'   { [ClaudeScreen.Natif]::Molette((X (Nombre 0)), (Y (Nombre 1)), [int](Nombre 2)); 'OK' }
    'ecrire'    { [ClaudeScreen.Natif]::Taper(($Valeurs -join ' ')); 'OK' }
    'ecrire-fichier' {
        [ClaudeScreen.Natif]::Taper([IO.File]::ReadAllText(($Valeurs -join ' '), [Text.Encoding]::UTF8)); 'OK'
    }
    'touche' {
        $vks = foreach ($nom in ($Valeurs -join '').ToLower().Split('+')) {
            if ($touches.ContainsKey($nom)) { $touches[$nom] }
            elseif ($nom -match '^f([1-9]|1[0-2])$') { 0x6F + [int]$Matches[1] }
            elseif ($nom -match '^[a-z0-9]$') { [int][char]$nom.ToUpper() }
            else { throw "Unknown key: $nom" }
        }
        [ClaudeScreen.Natif]::Combo([uint16[]]$vks); 'OK'
    }
    'attendre'  { Start-Sleep -Milliseconds ([int](Nombre 0)); 'OK' }
    'corbeille' {
        Add-Type -AssemblyName Microsoft.VisualBasic
        $chemin = (Resolve-Path ($Valeurs -join ' ')).Path
        # The context folder (System-Context) is read-only: not the folder, not its contents, not a folder containing it.
        if ($env:ECRAN_CONTEXTE) {
            $a = [IO.Path]::GetFullPath($chemin).Replace('/', '\').TrimEnd('\') + '\'
            $b = [IO.Path]::GetFullPath($env:ECRAN_CONTEXTE).Replace('/', '\').TrimEnd('\') + '\'
            if ($a.StartsWith($b, [StringComparison]::OrdinalIgnoreCase) -or $b.StartsWith($a, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Refused: $($env:ECRAN_CONTEXTE) is read-only (the user's documents)."
            }
        }
        $fs = [Microsoft.VisualBasic.FileIO.FileSystem]
        $ui = [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs
        $corbeille = [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
        if (Test-Path $chemin -PathType Container) { $fs::DeleteDirectory($chemin, $ui, $corbeille) } else { $fs::DeleteFile($chemin, $ui, $corbeille) }
        "Sent to the Recycle Bin: $chemin"
    }
    'page-pdf' {
        # page-pdf PATH N: one PDF page as an image (read-only; the path may contain spaces).
        if ($Valeurs.Count -lt 2) { throw 'Usage: page-pdf PATH N' }
        $pdf = ($Valeurs[0..($Valeurs.Count - 2)] -join ' ')
        if ($pdf -notmatch '\.pdf$' -or -not (Test-Path -LiteralPath $pdf -PathType Leaf)) { throw "PDF not found: $pdf" }
        if (-not (Test-Poppler)) { throw 'Poppler (PDF reading) is not installed yet: try again in a minute.' }
        $n = @(Get-ChildItem $images -Filter 'pdf-*.png').Count + 1
        $png = Join-Path $images ('pdf-{0:D2}.png' -f $n)
        $numero = [int]$Valeurs[-1]
        $pages = Export-PdfPage (Resolve-Path -LiteralPath $pdf).Path $numero $png
        "Page $numero/$($pages): $png (read it with Read)"
    }
    default { throw "Unknown action: $Action" }
}
