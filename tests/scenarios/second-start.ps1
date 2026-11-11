# Second start on the same folders: nothing is converted twice, the user's files are left alone.
Verifier 'second start: same work folder' ($Travail -like '*\Claude-Work')
Verifier 'second start: nothing converted again' (-not ((Get-Content $Journal -Encoding UTF8 | Select-Object -Last 3) -match 'renamed|moved to memory|converted'))
Verifier 'second start: Contexts folder not copied again' (@((Get-Content $Journal -Encoding UTF8) -match 'Contexts folder created').Count -eq 1)
