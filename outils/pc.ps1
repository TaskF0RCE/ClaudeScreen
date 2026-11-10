# PC control for Claude, one action per call: pc.ps1 <action> [arguments]. The actions are in actions.ps1.
# Used when "Fast control" is unchecked in the icon menu; otherwise Claude goes through mcp.ps1.
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Action,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Valeurs
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'actions.ps1')
Invoke-ActionPc $Action $Valeurs
