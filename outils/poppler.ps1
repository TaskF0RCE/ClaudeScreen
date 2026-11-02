# Installe Poppler pour Windows (pdftotext, pdftoppm, pdfinfo) dans outils\poppler, une seule fois.
# Sans lui, Claude Code ne peut pas lire les PDF (il lui faut pdftoppm), et ClaudeScreen ne peut pas
# extraire le texte des PDF du contexte.
# Version figée et empreinte SHA-256 vérifiée : un fichier modifié est refusé.
# Lancé en arrière-plan par ClaudeScreen.ps1 si besoin, ou à la main :
#   powershell -ExecutionPolicy Bypass -File outils\poppler.ps1
param([string]$Journal)
$ErrorActionPreference = 'Stop'
$Version = '25.12.0-0'
$Empreinte = '9499C7474E4DEB41C80EF5EA4A18CC1F3843695FBFA3C247DB5C46C6EAB2E26F'
$Adresse = "https://github.com/oschwartz10612/poppler-windows/releases/download/v$Version/Release-$Version.zip"
$Cible = Join-Path $PSScriptRoot 'poppler'
$Provisoire = Join-Path $PSScriptRoot 'poppler-provisoire'   # même disque que la cible (Move-Item)
$Zip = Join-Path ([IO.Path]::GetTempPath()) "poppler-$Version.zip"
$FichierJournal = $Journal

function Ecrire([string]$texte) {
    if ($FichierJournal) { Add-Content -Path $FichierJournal -Value ("{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $texte) -Encoding UTF8 }
    $texte
}

if (Test-Path (Join-Path $Cible 'Library\bin\pdftotext.exe')) { return }
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'   # sinon Invoke-WebRequest est très lent sous PowerShell 5.1
    Invoke-WebRequest -Uri $Adresse -OutFile $Zip -UseBasicParsing
    $obtenue = (Get-FileHash $Zip -Algorithm SHA256).Hash
    if ($obtenue -ne $Empreinte) { throw "empreinte inattendue ($obtenue) : fichier refusé" }
    if (Test-Path $Provisoire) { Remove-Item $Provisoire -Recurse -Force }
    Expand-Archive -Path $Zip -DestinationPath $Provisoire -Force
    $dossier = Get-ChildItem $Provisoire -Directory | Select-Object -First 1   # poppler-25.12.0
    if (Test-Path $Cible) { Remove-Item $Cible -Recurse -Force }
    Move-Item $dossier.FullName $Cible
    Ecrire "Poppler $Version installé (lecture des PDF) : $Cible"
} catch {
    Ecrire "Installation de Poppler impossible : $($_.Exception.Message). Les PDF ne pourront pas être lus."
} finally {
    Remove-Item $Zip, $Provisoire -Recurse -Force -ErrorAction SilentlyContinue
}
