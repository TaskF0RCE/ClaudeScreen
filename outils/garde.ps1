# PreToolUse hook: checks every terminal command and every file write of Claude before it runs.
# Refuses permanent deletions, what is outside a task (see the list below) and any write to the
# context folder (System-Context, read-only).
[Console]::InputEncoding = [Text.Encoding]::UTF8
$entree = [Console]::In.ReadToEnd() | ConvertFrom-Json

# Tools that write files (Edit, Write, MultiEdit, NotebookEdit): nothing inside System-Context.
# Backs up the deny rule in data/settings.json (its path matching is unreliable on Windows).
$fichier = [string]$entree.tool_input.file_path
if (-not $fichier) { $fichier = [string]$entree.tool_input.notebook_path }
if ($fichier) {
    $contexte = $env:ECRAN_CONTEXTE
    if (-not $contexte) { $contexte = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Claude-Work\System-Context' }
    $base = if ($entree.cwd) { [string]$entree.cwd } else { (Get-Location).Path }
    $cible = [IO.Path]::GetFullPath([IO.Path]::Combine($base, $fichier)).Replace('/', '\').TrimEnd('\') + '\'
    $racine = [IO.Path]::GetFullPath($contexte).Replace('/', '\').TrimEnd('\') + '\'
    if ($cible.StartsWith($racine, [StringComparison]::OrdinalIgnoreCase)) {
        [Console]::Error.WriteLine("Blocked: $contexte is read-only (the user's documents and instructions). You can read these files, not modify them. Write your files elsewhere in the current folder.")
        exit 2
    }
    exit 0
}

$commande = [string]$entree.tool_input.command
if (-not $commande) { exit 0 }

# Terminal commands (Terminal access in the icon menu). The app runs without administrator rights, which is
# the real limit on what a command can do to the system. On top of that, this list refuses what has no place
# in a task: it is a safety net against mistakes and against instructions hidden in a page or a document,
# not a sandbox. Each entry: the reason shown to Claude, then the patterns.
$interdits = @(
    @('permanent deletions and shutting down the PC are forbidden; to remove a file or folder, send it to the Recycle Bin with the corbeille action of the pc tool', @(
        '\bRemove-Item\b', '\bRemove-ItemProperty\b', '\bClear-RecycleBin\b', '\bClear-Content\b', '\bClear-Item\b',
        '(^|[\s;&|(`"''])(rm|rmdir|rd|del|erase|ri)(\s|$)',
        '\bFormat-Volume\b', '\bformat(\.com)?\s+[a-z]:', '\bdiskpart\b', '\bvssadmin\b', '\bcipher\b.*\s/w',
        '(\.|::)Delete\s*\(', 'DeleteFile', 'DeleteDirectory', '\bunlink\b', '\bshred\b',
        '\bgit\s+clean\b', '\bgit\s+reset\s+--hard\b', '\bgit\s+push\b.*--force',
        '\bwevtutil\s+cl\b', '\bStop-Computer\b', '\bRestart-Computer\b', '\bshutdown(\.exe)?\s')),
    @('administrator rights are not allowed', @(
        '-Verb\s+[''"]?RunAs', '\brunas(\.exe)?\s', '\bsudo\s', '\bgsudo\b')),
    @('installing, downloading or running code from the internet is not allowed', @(
        '\bwinget\s+(install|upgrade|uninstall|import)\b', '\bchoco(latey)?\s', '\bscoop\s+(install|update|uninstall)\b', '\bmsiexec\b',
        '\b(Install|Update|Uninstall)-(Module|Package|Script)\b', '\bAdd-AppxPackage\b', '\b(npm|pnpm|yarn)\s+(i|install|add)\s+(-g|--global)\b',
        '\bpip3?\s+install\b', '\b(iex|Invoke-Expression)\b', '\b(Invoke-WebRequest|Invoke-RestMethod|iwr|irm|curl|wget)\b',
        '\bStart-BitsTransfer\b', '\bbitsadmin\b', '\bcertutil\b.*-urlcache', 'DownloadFile|DownloadString|Net\.WebClient|Net\.Http',
        '-enc(odedcommand)?\s', 'FromBase64String')),
    @('changing Windows (registry, services, scheduled tasks, accounts, permissions, security settings) is not allowed', @(
        '\breg(\.exe)?\s+(add|delete|import|load|restore|copy)\b', '\bregedit\b', '\b(Set|New|Remove|Rename|Clear)-ItemProperty\b', '\bNew-Item\b.*\bHK(LM|CU|CR|U)\b',
        '\b(New|Set|Remove|Stop|Suspend|Restart)-Service\b', '\bsc(\.exe)?\s+(create|delete|config|stop|failure)\b',
        '\bschtasks(\.exe)?\b.*/(create|delete|change|run)\b', '\b(Register|Unregister|Set|Disable|Enable)-ScheduledTask\b',
        '\bnet1?(\.exe)?\s+(user|localgroup|accounts|share)\b', '\b(New|Set|Remove|Add|Disable|Enable|Rename)-Local(User|Group|GroupMember)\b',
        '\b(Set|Add|Remove)-MpPreference\b', '\bnetsh\b.*\b(advfirewall|firewall)\b', '\b(Set|New|Remove|Disable|Enable)-NetFirewall',
        '\bSet-ExecutionPolicy\b', '\bbcdedit\b', '\bdism(\.exe)?\s', '\b(Enable|Disable)-WindowsOptionalFeature\b',
        '\btakeown\b', '\bicacls\b', '\bcacls\b', '\bSet-Acl\b', '\bsetx\b', '\[Environment\]::SetEnvironmentVariable')),
    @('stopping other programs is not allowed', @(
        '\bStop-Process\b', '\btaskkill\b', '(^|[\s;&|(])(kill|spps)\s', '\.Kill\s*\(')),
    @('reading stored passwords or keys is not allowed', @(
        '\bcmdkey\b', '\bvaultcmd\b', 'CredentialManager|Get-StoredCredential|PasswordVault', '\blsass\b', '\bmimikatz\b',
        'Login Data|logins\.json|key4\.db', '\\\.ssh\\id_', 'ConvertFrom-SecureString', '\bnetsh\b.*\bkey\s*=\s*clear'))
)
foreach ($interdit in $interdits) {
    foreach ($motif in $interdit[1]) {
        if ($commande -match $motif) {
            [Console]::Error.WriteLine("Blocked by ClaudeScreen: $($interdit[0]). Do not try another way round: do the task differently, or explain in your final answer what you could not do.")
            exit 2
        }
    }
}

# Folders a command may read but never write to: System-Context (the user's documents and instructions)
# and ClaudeScreen itself (its scripts, its settings and this guard).
$ecriture = '\b(Set|Add|Clear)-Content\b|\bOut-File\b|\b(Move|Rename|Copy|New)-Item\b|(^|[\s;&|(])(mv|move|ren|cp|copy|ni|md|mkdir|xcopy|robocopy)\s|(^|[^-=])>|\bTee(-Object)?\b|\bExport-\w+|\bStart-Transcript\b|WriteAll|AppendAll|\.Save\w*\s*\(|::(Move|Copy|Create|Replace)\w*\s*\('
if ($commande -match $ecriture) {
    $contexte = $env:ECRAN_CONTEXTE
    if (-not $contexte) { $contexte = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Claude-Work\System-Context' }
    $plat = $commande.Replace('/', '\')
    foreach ($dossier in @($contexte, (Split-Path $PSScriptRoot -Parent))) {
        $d = $dossier.TrimEnd('\')
        # Full path, or for the context folder its name alone (a relative path from the work folder).
        if ($plat.IndexOf($d, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
            ($d -eq $contexte.TrimEnd('\') -and $plat.IndexOf((Split-Path $d -Leaf), [StringComparison]::OrdinalIgnoreCase) -ge 0)) {
            [Console]::Error.WriteLine("Blocked by ClaudeScreen: $d is read-only. You can read its files, not change them. Write your files in the current folder.")
            exit 2
        }
    }
}
exit 0
