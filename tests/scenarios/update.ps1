# Claude Code update: started hidden, never twice at once, never during a task. $Claude is a harmless program here.
try {
Verifier 'not started at load (the timer does it)' ($null -eq $script:Maj -and $script:DerniereMaj -eq [datetime]::MinValue)
$script:Proc = [pscustomobject]@{ HasExited = $false }
Mettre-A-Jour-Claude
Verifier 'not during a task' ($null -eq $script:Maj -and $script:DerniereMaj -eq [datetime]::MinValue)
$script:Proc = $null
Mettre-A-Jour-Claude
Verifier 'started through cmd with the update argument, hidden' ($null -ne $script:Maj -and $script:Maj.StartInfo.FileName -eq 'cmd.exe' -and $script:Maj.StartInfo.Arguments -eq "/d /s /c `"`"$Claude`" update`"" -and $script:Maj.StartInfo.CreateNoWindow -and ((Get-Date) - $script:DerniereMaj).TotalSeconds -lt 10) $script:Maj.StartInfo.Arguments
$premier = $script:Maj
[void]$premier.WaitForExit(10000)
Verifier 'the fake update ran and finished' $premier.HasExited
$script:Maj = [pscustomobject]@{ HasExited = $false } | Add-Member ScriptMethod Dispose { } -PassThru
Mettre-A-Jour-Claude
Verifier 'not twice at once' ($script:Maj.GetType().Name -eq 'PSCustomObject')
$script:Maj = $null
$Claude = 'C:\nowhere\claude.exe'
$script:DerniereMaj = [datetime]::MinValue
Mettre-A-Jour-Claude
Verifier 'no Claude Code: nothing started, no error' ($null -eq $script:Maj)
} catch { Verifier 'scenario ran to the end' $false ($_.Exception.Message + ' ' + $_.InvocationInfo.PositionMessage) }
