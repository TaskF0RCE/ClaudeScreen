# Loads natif.cs, compiled only once into a DLL (the name changes when the source changes).
if (-not ('ClaudeEcran.Natif' -as [type])) {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $source = Join-Path $PSScriptRoot 'natif.cs'
    $hash = (Get-FileHash $source -Algorithm MD5).Hash.Substring(0, 8)
    $dll = Join-Path $PSScriptRoot "natif-$hash.dll"
    if (-not (Test-Path $dll)) {
        Add-Type -Path $source -ReferencedAssemblies System.Windows.Forms, System.Drawing -OutputAssembly $dll -OutputType Library
    }
    if (-not ('ClaudeEcran.Natif' -as [type])) { Add-Type -Path $dll }
}
