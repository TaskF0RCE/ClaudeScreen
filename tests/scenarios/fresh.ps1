# First start on a PC that never had ClaudeScreen.
Verifier 'Claude-Work and System-Context created' ((Test-Path $Contexte) -and $Travail -like '*\Claude-Work')
Verifier 'instructions.md: template, no instruction' ((Test-Path $FichierInstructions) -and (Get-InstructionUtilisateur $FichierInstructions) -eq '' -and [IO.File]::ReadAllText($FichierInstructions) -match 'go to memory\.md')
Verifier 'guide copied, no memory.md (mode off)' ((Test-Path $FichierLisezMoi) -and -not (Test-Path $FichierNotes) -and -not $menuMemoire.Checked)
Verifier 'Contexts folder created' (Test-Path (Join-Path $DossierContextes 'Default.md'))
Verifier 'nothing sent to the bin' (@(Get-ChildItem $global:FauxBac).Count -eq 0)
$libelles = @($menu.Items | ForEach-Object { $_.Text })
Verifier 'menu items' (($libelles -join '|') -eq 'Last result|Model|Smooth mode|Persistent memory|Terminal access|Context: Default|Open the Claude-Work folder|Stop the current task||Quit') ($libelles -join '|')
