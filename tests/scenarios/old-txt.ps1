# A very old version: instructions.txt, where lines starting with # were comments.
$t = [IO.File]::ReadAllText($FichierInstructions, [Text.Encoding]::UTF8) -replace "`r`n", "`n"
Verifier 'instructions.txt converted' ($t -eq "<!-- Comments like this one are ignored. Write your instructions below, one per line. -->`n<!-- Example - - one -->`nAlways answer briefly.`n") $t
Verifier 'instruction read' ((Get-InstructionUtilisateur $FichierInstructions) -eq 'Always answer briefly.')
Verifier 'instructions.txt in the bin, not destroyed' (-not (Test-Path $AnciennesInstructions) -and @(Get-ChildItem $global:FauxBac -Filter 'instructions.txt.*').Count -eq 1)
Verifier 'folder renamed' ($Travail -like '*\Claude-Work')
