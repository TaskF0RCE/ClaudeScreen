# Installs Poppler for Windows (pdftotext, pdftoppm, pdfinfo) in outils\poppler, only once.
# Without it, Claude Code cannot read PDFs (it needs pdftoppm), and ClaudeScreen cannot
# extract the text of the context PDFs.
# Pinned version and verified SHA-256 hash: a modified file is rejected.
# Started in the background by ClaudeScreen.ps1 when needed, or by hand:
#   powershell -ExecutionPolicy Bypass -File outils\poppler.ps1
param([string]$Journal)
$ErrorActionPreference = 'Stop'
$Version = '25.12.0-0'
$Empreinte = '9499C7474E4DEB41C80EF5EA4A18CC1F3843695FBFA3C247DB5C46C6EAB2E26F'
$Adresse = "https://github.com/oschwartz10612/poppler-windows/releases/download/v$Version/Release-$Version.zip"
$Cible = Join-Path $PSScriptRoot 'poppler'
$Provisoire = Join-Path $PSScriptRoot 'poppler-provisoire'   # same drive as the target (Move-Item)
$Zip = Join-Path ([IO.Path]::GetTempPath()) "poppler-$Version.zip"
$FichierJournal = $Journal

function Ecrire([string]$texte) {
    if ($FichierJournal) { Add-Content -Path $FichierJournal -Value ("{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $texte) -Encoding UTF8 }
    $texte
}

if (Test-Path (Join-Path $Cible 'Library\bin\pdftotext.exe')) { return }
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'   # otherwise Invoke-WebRequest is very slow under PowerShell 5.1
    Invoke-WebRequest -Uri $Adresse -OutFile $Zip -UseBasicParsing
    $obtenue = (Get-FileHash $Zip -Algorithm SHA256).Hash
    if ($obtenue -ne $Empreinte) { throw "unexpected hash ($obtenue): file rejected" }
    if (Test-Path $Provisoire) { Remove-Item $Provisoire -Recurse -Force }
    Expand-Archive -Path $Zip -DestinationPath $Provisoire -Force
    $dossier = Get-ChildItem $Provisoire -Directory | Select-Object -First 1   # poppler-25.12.0
    if (Test-Path $Cible) { Remove-Item $Cible -Recurse -Force }
    Move-Item $dossier.FullName $Cible
    Ecrire "Poppler $Version installed (PDF reading): $Cible"
} catch {
    Ecrire "Could not install Poppler: $($_.Exception.Message). PDFs will not be readable."
} finally {
    Remove-Item $Zip, $Provisoire -Recurse -Force -ErrorAction SilentlyContinue
}
