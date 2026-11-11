Verifier 'renamed at the next start' ($Travail -like '*\Claude-Work' -and -not (Test-Path (Join-Path $Documents 'Claude-Travail')) -and (Get-NoteMemoire $FichierNotes) -match 'Dupont')
