# Builds ClaudeScreen-Setup.exe: the Windows app (the files tracked by git, without the tests and the
# macOS/Linux port) zipped inside a small program compiled from Setup.cs.
# Needs nothing but Windows and git: the C# compiler is the one that ships with .NET Framework 4.
#   powershell -ExecutionPolicy Bypass -File installer\Build-Setup.ps1
#   -Sortie PATH    where to write the exe (default: dist\ClaudeScreen-Setup.exe, ignored by git)
param([string]$Sortie)
$ErrorActionPreference = 'Stop'
$depot = Split-Path $PSScriptRoot -Parent
if (-not $Sortie) { $Sortie = Join-Path $depot 'dist\ClaudeScreen-Setup.exe' }
$Sortie = [IO.Path]::GetFullPath($Sortie)
New-Item -ItemType Directory -Force (Split-Path $Sortie -Parent) | Out-Null

# The version of the release (written by release-please).
$version = (Get-Content (Join-Path $depot '.release-please-manifest.json') -Raw | ConvertFrom-Json).'.'
if ("$version" -notmatch '^\d+\.\d+\.\d+$') { throw "Unexpected version in .release-please-manifest.json: $version" }

# What a Windows user needs, and nothing else.
$inclus = @('ClaudeScreen.ps1', 'Installer-Demarrage.ps1', 'Lancer.vbs', 'Lancer.lnk', 'LICENSE', 'README.md', 'CHANGELOG.md', 'outils', 'contexts', 'examples')
$fichiers = @(& git -C $depot ls-files -- $inclus)
if ($LASTEXITCODE -ne 0 -or $fichiers.Count -lt 10) { throw 'git ls-files did not list the files of the app' }

$travail = Join-Path ([IO.Path]::GetTempPath()) ('claudescreen-setup-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
try {
    $app = Join-Path $travail 'app'
    foreach ($f in $fichiers) {
        $cible = Join-Path $app $f
        New-Item -ItemType Directory -Force (Split-Path $cible -Parent) | Out-Null
        Copy-Item -LiteralPath (Join-Path $depot $f) -Destination $cible
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = Join-Path $travail 'app.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($app, $zip)
    $infos = Join-Path $travail 'Version.cs'
    @"
using System.Reflection;
[assembly: AssemblyTitle("ClaudeScreen Setup")]
[assembly: AssemblyProduct("ClaudeScreen")]
[assembly: AssemblyVersion("$version.0")]
[assembly: AssemblyFileVersion("$version.0")]
"@ | Set-Content $infos -Encoding UTF8

    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
    if (-not (Test-Path $csc)) { throw 'csc.exe (.NET Framework 4) was not found' }
    $messages = & $csc /nologo /target:winexe /optimize+ /platform:anycpu "/out:$Sortie" "/resource:$zip,app.zip" `
        /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll `
        (Join-Path $PSScriptRoot 'Setup.cs') $infos 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Setup.cs does not compile:`n$($messages -join "`n")" }
} finally {
    Remove-Item $travail -Recurse -Force -ErrorAction SilentlyContinue
}
"Built $Sortie (version $version, $($fichiers.Count) files, $([math]::Round((Get-Item $Sortie).Length / 1KB)) KB)"
