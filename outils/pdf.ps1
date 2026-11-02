# PDF reading with Poppler (outils\poppler, installed by poppler.ps1).
# Claude Code needs pdftoppm to read a PDF itself, so ClaudeScreen extracts the text of the context PDFs
# in advance (cached .txt file, with page numbers) and renders pages as images
# on demand (pc.ps1 page-pdf).
$PopplerBin = Join-Path $PSScriptRoot 'poppler\Library\bin'
$SeuilScanne = 40   # under 40 characters per page on average: scanned PDF (images without text)

function Test-Poppler { Test-Path (Join-Path $PopplerBin 'pdftotext.exe') }

# Runs a Poppler tool without a window. No "& tool 2>$null": under PowerShell 5.1 with
# $ErrorActionPreference = 'Stop', the slightest warning on stderr would become an error.
function Invoke-Poppler([string]$outil, [string[]]$arguments) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo (Join-Path $PopplerBin "$outil.exe")
    $psi.Arguments = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $p = [Diagnostics.Process]::Start($psi)
    $erreurs = $p.StandardError.ReadToEndAsync()
    $sortie = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    [pscustomobject]@{ Code = $p.ExitCode; Sortie = $sortie; Erreurs = $erreurs.Result }
}

function Get-PdfPageCount([string]$pdf) {
    $r = Invoke-Poppler 'pdfinfo' @('-enc', 'UTF-8', $pdf)
    if ($r.Sortie -match '(?m)^Pages:\s+(\d+)') { [int]$Matches[1] } else { 0 }
}

# Text of the PDF page by page in $cache; reused as long as the PDF does not change.
# Returns { Txt ; Pages ; Scanne }.
function Export-PdfTexte([string]$pdf, [string]$cache) {
    New-Item -ItemType Directory -Force $cache | Out-Null
    $f = Get-Item -LiteralPath $pdf
    $sha = [Security.Cryptography.SHA1]::Create()
    $octets = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("$($f.FullName)|$($f.Length)|$($f.LastWriteTimeUtc.Ticks)"))
    $cle = -join ($octets[0..7] | ForEach-Object { $_.ToString('x2') })
    $base = $f.BaseName -replace '[^\w.-]+', '_'   # no spaces
    if ($base.Length -gt 40) { $base = $base.Substring(0, 40) }
    $txt = Join-Path $cache "$base-$cle.txt"

    if (Test-Path -LiteralPath $txt) {
        # 1st line: metadata (source|pages|texte or scanne).
        $lecteur = New-Object IO.StreamReader($txt, [Text.Encoding]::UTF8)
        try { $parties = $lecteur.ReadLine().Split('|') } finally { $lecteur.Close() }
        if ($parties.Count -ge 3) { return [pscustomobject]@{ Txt = $txt; Pages = [int]$parties[-2]; Scanne = ($parties[-1] -eq 'scanne') } }
    }

    $brut = "$txt.brut"
    $r = Invoke-Poppler 'pdftotext' @('-enc', 'UTF-8', $f.FullName, $brut)
    if ($r.Code -ne 0) { throw "pdftotext : $($r.Erreurs.Trim())" }
    $texte = [IO.File]::ReadAllText($brut, [Text.Encoding]::UTF8)
    Remove-Item -LiteralPath $brut -Force
    # pdftotext ends each page with a form feed (character 12): the last chunk is empty.
    $morceaux = $texte.Split([char]12)
    $pages = New-Object System.Collections.Generic.List[string]
    $total = 0
    for ($i = 0; $i -lt $morceaux.Count - 1; $i++) {
        $t = $morceaux[$i].Replace("`r`n", "`n").Trim()
        $total += $t.Length
        $pages.Add("`n===== Page $($i + 1) =====`n$t`n")
    }
    $n = $pages.Count
    $scanne = $n -gt 0 -and ($total / $n) -lt $SeuilScanne
    $genre = if ($scanne) { 'scanne' } else { 'texte' }
    $provisoire = "$txt.tmp"
    [IO.File]::WriteAllText($provisoire, "ClaudeScreen: text extracted from $($f.FullName)|$n|$genre`n" + ($pages -join ''), (New-Object Text.UTF8Encoding $false))
    Move-Item -LiteralPath $provisoire -Destination $txt -Force
    [pscustomobject]@{ Txt = $txt; Pages = $n; Scanne = $scanne }
}

# Clears cached extracts of deleted or changed PDFs ($gardes = files still in use).
function Clear-PdfCache([string]$cache, [string[]]$gardes) {
    Get-ChildItem -LiteralPath $cache -File -ErrorAction SilentlyContinue |
        Where-Object { $gardes -notcontains $_.FullName } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# Page $numero (starting at 1) as PNG, at most 1600 px on the long side. Returns the page count.
function Export-PdfPage([string]$pdf, [int]$numero, [string]$png) {
    $pages = Get-PdfPageCount $pdf
    if ($numero -lt 1 -or $numero -gt $pages) { throw "Page $numero does not exist: this PDF has $pages page(s)." }
    $prefixe = [IO.Path]::Combine([IO.Path]::GetDirectoryName($png), [IO.Path]::GetFileNameWithoutExtension($png))
    $r = Invoke-Poppler 'pdftoppm' @('-png', '-singlefile', '-f', "$numero", '-l', "$numero", '-scale-to', '1600', $pdf, $prefixe)
    if ($r.Code -ne 0 -or -not (Test-Path -LiteralPath $png)) { throw "pdftoppm : $($r.Erreurs.Trim())" }
    $pages
}
