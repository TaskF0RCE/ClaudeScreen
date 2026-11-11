# Runs one PC control action by hand, to try it: pc.ps1 <action> [arguments], with ECRAN_RUN set to a task
# folder (data/runs/<date>, it needs its screen.json). Claude itself goes through mcp.ps1. The actions are in actions.ps1.
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Action,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Valeurs
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'actions.ps1')
Invoke-ActionPc $Action $Valeurs
