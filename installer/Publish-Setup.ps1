# Attaches ClaudeScreen-Setup.exe to the GitHub release of the commit that is checked out.
# Run by the release workflow after each push to main; needs the gh CLI (GH_TOKEN) and the git tags.
# Nothing to do when this commit is not the one of a release, or when the file is already there.
#   -Essai   say what would be done, build nothing, upload nothing
param([switch]$Essai)
$ErrorActionPreference = 'Stop'
$depot = Split-Path $PSScriptRoot -Parent
$version = (Get-Content (Join-Path $depot '.release-please-manifest.json') -Raw | ConvertFrom-Json).'.'
$tag = "v$version"

$ErrorActionPreference = 'Continue'   # git and gh write to stderr when a tag or a release does not exist
$commit = & git -C $depot rev-list -n 1 $tag 2>$null
$connu = $LASTEXITCODE -eq 0
$ici = & git -C $depot rev-parse HEAD
if (-not $connu -or $commit -ne $ici) { "This commit is not release ${tag}: nothing to attach."; exit 0 }
$present = & gh release view $tag --json assets --jq '.assets[].name' 2>$null
if ($LASTEXITCODE -ne 0) { "Release ${tag} does not exist yet: nothing to attach."; exit 0 }
if (@($present) -contains 'ClaudeScreen-Setup.exe') { "ClaudeScreen-Setup.exe is already on ${tag}."; exit 0 }
if ($Essai) { "Would build ClaudeScreen-Setup.exe and attach it to ${tag}."; exit 0 }

$ErrorActionPreference = 'Stop'
$exe = Join-Path $depot 'dist\ClaudeScreen-Setup.exe'
& (Join-Path $PSScriptRoot 'Build-Setup.ps1') -Sortie $exe
& gh release upload $tag $exe
if ($LASTEXITCODE -ne 0) { throw "gh release upload failed for ${tag}" }
"ClaudeScreen-Setup.exe attached to ${tag}."
