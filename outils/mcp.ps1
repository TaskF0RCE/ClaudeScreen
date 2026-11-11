# MCP server (stdio) that gives Claude the PC control actions through one tool, "pc".
# Claude Code starts it once per task and keeps it open: an action does not start a new PowerShell,
# several actions go in one call, and the screenshot comes back in the answer instead of being read
# in a second step.
# Protocol: one JSON-RPC message per line on stdin/stdout (Model Context Protocol). Nothing else may be
# written to stdout. No network port is opened. The actions themselves are in actions.ps1.
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false
$entree = New-Object System.IO.StreamReader ([Console]::OpenStandardInput()), $utf8
$sortie = New-Object System.IO.StreamWriter ([Console]::OpenStandardOutput()), $utf8
$sortie.AutoFlush = $true
. (Join-Path $PSScriptRoot 'actions.ps1')

$MaxActions = 20
# Actions whose argument is one text or one path: everything after the action name, spaces included.
$ActionsTexte = @('ecrire', 'ecrire-fichier', 'corbeille')
$Outils = @'
[{"name":"pc","description":"Controls the user's PC with the mouse and keyboard. Runs the given actions in order and stops at the first error. By default the result ends with a new screenshot taken after the last action.","inputSchema":{"type":"object","properties":{"actions":{"type":"array","items":{"type":"string"},"minItems":1,"maxItems":20,"description":"Actions to run in order, one per string, written as listed in your instructions, e.g. [\"clic 412 300\", \"ecrire Paris\", \"touche enter\"]."},"capture":{"type":"boolean","description":"true (default): take a screenshot after the last action and return it. false: no screenshot."}},"required":["actions"]}}]
'@

function ConvertTo-Texte($valeur) { ConvertTo-Json -InputObject $valeur -Compress }

# Image file -> base64 JPEG (about 5 times lighter than the PNG kept in the task folder; same size in pixels).
function Get-ImageBase64([string]$png) {
    $image = [System.Drawing.Image]::FromFile($png)
    try {
        $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
        $p = New-Object System.Drawing.Imaging.EncoderParameters 1
        $p.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]90)
        $flux = New-Object System.IO.MemoryStream
        $image.Save($flux, $codec, $p)
        [Convert]::ToBase64String($flux.ToArray())
    } finally { $image.Dispose() }
}

function Format-Image([string]$png) { '{"type":"image","data":"' + (Get-ImageBase64 $png) + '","mimeType":"image/jpeg"}' }
function Format-Texte([string]$texte) { '{"type":"text","text":' + (ConvertTo-Texte $texte) + '}' }

# "clic 10 20" -> action + arguments, as pc.ps1 would receive them.
function Split-Action([string]$ligne) {
    $ligne = $ligne.Trim()
    $nom, $reste = $ligne -split '\s+', 2
    $reste = "$reste".Trim()
    if ($ActionsTexte -contains $nom.ToLower()) {
        # Quotes around the whole text are optional here (there is no shell): remove one pair.
        if ($reste.Length -ge 2 -and $reste[0] -eq '"' -and $reste[-1] -eq '"') { $reste = $reste.Substring(1, $reste.Length - 2) }
        $valeurs = @($reste)
    } elseif ($reste) { $valeurs = @($reste -split '\s+') } else { $valeurs = @() }
    [pscustomobject]@{ Nom = $nom; Valeurs = [string[]]$valeurs }
}

# tools/call: runs the actions and returns the JSON of the result (content + isError).
function Invoke-Outil($arguments) {
    $contenu = New-Object System.Collections.Generic.List[string]
    $lignes = New-Object System.Collections.Generic.List[string]
    $erreur = $false
    $actions = @($arguments.actions | Where-Object { "$_".Trim() })
    $capture = ($null -eq $arguments.capture) -or [bool]$arguments.capture
    $derniere = ''
    if (-not $actions.Count) { $erreur = $true; $lignes.Add('ERROR: "actions" is empty.') }
    elseif ($actions.Count -gt $MaxActions) { $erreur = $true; $lignes.Add("ERROR: $($actions.Count) actions, $MaxActions at most per call. Nothing was run.") }
    else {
        $n = 0
        foreach ($ligne in $actions) {
            $n++
            $a = Split-Action "$ligne"
            try {
                $resultat = Invoke-ActionPc $a.Nom $a.Valeurs
                $derniere = $a.Nom.ToLower()
                if ($script:ActionsImage) {
                    # The image itself follows: the path is of no use to Claude.
                    $lignes.Add("$n. $($a.Nom): image below" + $(if ($derniere -eq 'zoom') { ' (read-only, do not use its coordinates to click)' } else { '' }))
                    $contenu.Add((Format-Image $script:ActionsImage))
                } else { $lignes.Add("$n. $($a.Nom): $resultat") }
            } catch {
                $erreur = $true
                $lignes.Add("$n. $($a.Nom): ERROR: $($_.Exception.Message)")
                if ($n -lt $actions.Count) { $lignes.Add("The $($actions.Count - $n) action(s) after it were not run.") }
                break
            }
        }
        if ($capture -and $derniere -ne 'capture') {
            try {
                Start-Sleep -Milliseconds 350   # lets the screen react to the last action
                Invoke-ActionPc 'capture' @() | Out-Null
                $lignes.Add("Screenshot after the last action: below ($($ActionsEcran.largeur)x$($ActionsEcran.hauteur) px).")
                $contenu.Add((Format-Image $script:ActionsImage))
            } catch { $lignes.Add("Screenshot failed: $($_.Exception.Message)") }
        }
    }
    '{"content":[' + ((@(Format-Texte ($lignes -join "`n")) + $contenu) -join ',') + '],"isError":' + $(if ($erreur) { 'true' } else { 'false' }) + '}'
}

function Start-Serveur {
    while ($null -ne ($ligne = $entree.ReadLine())) {
        if (-not $ligne.Trim()) { continue }
        try { $requete = $ligne | ConvertFrom-Json } catch { continue }
        if ($null -eq $requete.id) { continue }   # notification (initialized, cancelled...): no answer
        $id = ConvertTo-Texte $requete.id
        $resultat = $null; $echec = $null
        try {
            switch ($requete.method) {
                'initialize' {
                    $version = if ($requete.params.protocolVersion) { [string]$requete.params.protocolVersion } else { '2024-11-05' }
                    $resultat = '{"protocolVersion":' + (ConvertTo-Texte $version) + ',"capabilities":{"tools":{}},"serverInfo":{"name":"claudescreen-pc","version":"1"}}'
                }
                'ping' { $resultat = '{}' }
                'tools/list' { $resultat = '{"tools":' + $Outils.Trim() + '}' }
                'tools/call' {
                    if ($requete.params.name -ne 'pc') { $echec = '{"code":-32602,"message":"Unknown tool"}' }
                    else { $resultat = Invoke-Outil $requete.params.arguments }
                }
                default { $echec = '{"code":-32601,"message":"Method not found"}' }
            }
        } catch { $echec = '{"code":-32603,"message":' + (ConvertTo-Texte $_.Exception.Message) + '}' }
        if ($echec) { $sortie.WriteLine('{"jsonrpc":"2.0","id":' + $id + ',"error":' + $echec + '}') }
        else { $sortie.WriteLine('{"jsonrpc":"2.0","id":' + $id + ',"result":' + $resultat + '}') }
    }
}
Start-Serveur | Out-Null
