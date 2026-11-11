# The old folder cannot be renamed (a file is open): the app keeps working in it.
Verifier 'still working in Claude-Travail' ($Travail -like '*\Claude-Travail' -and -not (Test-Path (Join-Path $Documents 'Claude-Work')))
Verifier 'context usable in the old folder' ((Test-Path $FichierNotes) -and $FichierNotes -like '*\Claude-Travail\System-Context\memory.md' -and (Get-NoteMemoire $FichierNotes) -match 'Dupont')
Verifier 'logged' ([bool]((Get-Content $Journal -Encoding UTF8) -match 'Could not rename Claude-Travail to Claude-Work'))
$r = Get-Content $Reglages -Raw -Encoding UTF8 | ConvertFrom-Json
Verifier 'deny rule follows the folder in use' (($r.permissions.deny -join '|') -match '/Claude-Travail/System-Context/\*\*')
$global:verrou.Dispose()
