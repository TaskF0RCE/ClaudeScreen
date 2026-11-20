"""Claude Code PreToolUse hook: checks every terminal command (see INTERDITS: deletions, sudo, installs and
downloads, system changes, stopping programs, reading stored passwords), blocks any permanent deletion (and shutting down the computer),
any write to the System-Context folder (read-only), and any read outside the folders ClaudeScreen
gives (ECRAN_LECTURE: work folder, task folder, PDF text).

Equivalent of garde.ps1. Exit code 2 = command refused, the message goes to Claude.
"""
import json
import os
import re
import sys

# Terminal commands (Terminal access in the icon menu). The app runs as the user, without sudo, which is the real
# limit on what a command can do to the system. On top of that, this list refuses what has no place in a task:
# a safety net against mistakes and against instructions hidden in a page or a document, not a sandbox.
# Same rules as outils/garde.ps1 (Windows). Each entry: the reason shown to Claude, then the patterns.
INTERDITS = [
    ('permanent deletions and shutting down the computer are forbidden; to remove a file or folder, send it to the '
     'trash with the "corbeille PATH" action of the pc tool', [
        # Deletion commands (at the start of a command or after ; & | ( ` " ').
        r'(^|[\s;&|(`"\'])(rm|rmdir|unlink|shred|srm|wipe|del|erase|rd|ri)(\s|$)',
        r'\bRemove-Item\b', r'\bClear-RecycleBin\b', r'\bClear-Content\b',
        r'\bfind\b.*\s-delete\b', r'\bfind\b.*-exec(dir)?\s+(rm|shred|unlink)\b', r'\bxargs\b.*\b(rm|shred|unlink)\b',
        r'\btruncate\b', r'\bos\.(remove|unlink|rmdir)\b', r'\bshutil\.rmtree\b', r'\.unlink\s*\(', r'\.Delete\s*\(',
        r'\brsync\b.*--delete', r'\bsrm\b',
        # Emptying the trash.
        r'\bgio\s+trash\s+--empty\b', r'\btrash-empty\b', r'empty\s+(the\s+)?trash', r'\.Trash\b',
        # Disks.
        r'\bmkfs(\.\w+)?\b', r'\bdd\b.*\bof=', r'\bwipefs\b', r'\b(s?fdisk|parted|gdisk)\b', r'\bblkdiscard\b',
        r'\bdiskutil\s+(erase\w*|zero\w*|secureErase|reformat|partitionDisk|apfs\s+delete\w*)',
        r'>\s*/dev/(sd|nvme|disk|hd|mmcblk)', r'\btmutil\s+(delete|disable)',
        # Destructive git.
        r'\bgit\s+clean\b', r'\bgit\s+reset\s+--hard\b', r'\bgit\s+push\b.*(--force|\s-f\b)',
        # Shutdown / reboot (only in command position: Cisco's "no shutdown" typed with ecrire is still allowed).
        r'(^|[;&|(`]\s*|\bsudo\s+|\bexec\s+)(shutdown|reboot|halt|poweroff)\b', r'\bsystemctl\s+(poweroff|reboot|halt|kexec|suspend)\b',
        r'\b(shut\s+down|restart)\b.*System Events', r'\bpmset\b.*\b(sleepnow|halt)\b',
    ]),
    ('administrator rights are not allowed', [
        r'(^|[\s;&|(`])(sudo|doas|pkexec|su)(\s|$)', r'with administrator privileges', r'\bosascript\b.*\badministrator\b',
    ]),
    ('installing, downloading or running code from the internet is not allowed', [
        r'\bbrew\s+(install|reinstall|upgrade|uninstall|remove|rm|tap|untap|bundle|cask)\b', r'\bport\s+(install|uninstall|upgrade)\b',
        r'\b(apt|apt-get|aptitude)\s+(install|remove|purge|upgrade|dist-upgrade|full-upgrade)\b', r'\bdpkg\s+-[ir]\b',
        r'\b(dnf|yum|zypper)\s+(install|remove|erase|upgrade|update)\b', r'\bpacman\s+-S', r'\bsnap\s+(install|remove)\b',
        r'\bflatpak\s+(install|uninstall|update)\b', r'\b(pip3?|pipx|uv\s+pip|conda|mamba)\s+install\b', r'\bpython3?\s+-m\s+pip\s+install\b',
        r'\b(npm|pnpm|yarn)\s+(i|install|add)\s+(-g|--global)\b', r'\bgem\s+install\b', r'\bcargo\s+install\b', r'\bgo\s+install\b',
        r'\bsoftwareupdate\b', r'\binstaller\s+-pkg\b', r'\bmas\s+install\b',
        r'\b(curl|wget|aria2c|nc|ncat|netcat|socat|scp|sftp|rsync\s+\S*::|ftp)\b', r'\b(import|from)\s+(urllib|requests|httpx|http\.client|aiohttp|socket)\b',
        r'\|\s*(sh|bash|zsh|python3?|perl|ruby)\b', r'\bbase64\s+(-d|--decode|-D)\b', r'\beval\b',
        r'\bxattr\b.*com\.apple\.quarantine', r'\bspctl\b',
    ]),
    ('changing the system (settings, services, scheduled tasks, accounts, permissions, security) is not allowed', [
        r'\bdefaults\s+(write|delete|import)\b', r'\blaunchctl\s+(load|unload|bootstrap|bootout|enable|disable|submit|remove|kickstart|setenv)\b',
        r'\bcrontab\b', r'\bat\s+-f\b', r'\bsystemctl\b.*\b(enable|disable|start|stop|restart|mask|unmask|edit|set-property)\b',
        r'\b(dscl|sysadminctl|dseditgroup|useradd|usermod|userdel|groupadd|groupmod|passwd|chpasswd|visudo)\b',
        r'\b(chown|chgrp|chflags)\b', r'\bchmod\b.*\s(/|~/(Library|\.ssh))', r'\b(csrutil|nvram|bless|kextload|kmutil|fdesetup|profiles)\b',
        r'\b(networksetup|scutil\s+--set|pfctl|socketfilterfw|iptables|ip6tables|nft|ufw|firewall-cmd)\b', r'\bpmset\b',
        r'\btccutil\b', r'\bsystemsetup\b', r'\b(gsettings|dconf)\s+(set|reset|write|load)\b', r'\bupdate-alternatives\b',
        r'(>|\btee\b).*(\.(zshrc|zprofile|zshenv|bashrc|bash_profile|profile)|LaunchAgents|LaunchDaemons|/etc/)',
    ]),
    ('stopping other programs is not allowed', [
        r'(^|[\s;&|(`])(kill|pkill|killall|xkill)(\s|$)', r'\bos\.kill\b', r'\bquit\s+app\b', r'\bto\s+quit\b',
    ]),
    ('reading stored passwords or keys is not allowed', [
        r'\bsecurity\s+(find-generic-password|find-internet-password|dump-keychain|export|unlock-keychain|find-certificate)\b',
        r'Keychains', r'\.ssh/id_', r'\.gnupg', r'\bgpg\b.*--export-secret', r'\.aws/credentials', r'\.netrc\b',
        r'Login Data|logins\.json|key4\.db|Cookies\b', r'\b(secret-tool|kwallet-query)\b', r'/etc/shadow',
    ]),
]
# Kept for older callers: the flat list of every pattern.
MOTIFS = [m for _raison, motifs in INTERDITS for m in motifs]
# A command that writes (redirection, copy, move, edit in place...).
ECRITURE = (r'(^|[^-=<0-9&])>|\btee\b|(^|[\s;&|(`])(mv|cp|ln|touch|mkdir|install|ditto|rsync|sed\s+-i|perl\s+-[pi]*i|patch)(\s|$)'
            r'|\bopen\s*\(.*[\'"][wax]|\.write(_text|_bytes)?\s*\(')
APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # the ClaudeScreen folder (linux-macos)



def contexte():
    """Context folder (passed by ClaudeScreen; otherwise the default location)."""
    if os.environ.get('ECRAN_CONTEXTE'):
        return os.environ['ECRAN_CONTEXTE']
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import natif
    return os.path.join(natif.dossier_documents(), 'Claude-Work', 'System-Context')


def dans(chemin, dossier):
    """Is chemin the folder itself or inside it? (symlinks and ".." resolved)"""
    c, d = os.path.realpath(chemin), os.path.realpath(dossier)
    if sys.platform == 'darwin':  # case-insensitive disk by default on macOS
        c, d = c.lower(), d.lower()
    return c == d or c.startswith(d.rstrip(os.sep) + os.sep)


LECTURE = ('Read', 'Glob', 'Grep', 'NotebookRead', 'LS')


def racine_motif(motif):
    """The fixed part of a glob pattern (before the first wildcard): /a/b/**/*.md -> /a/b."""
    morceaux = []
    for morceau in str(motif).replace('\\', '/').split('/'):
        if any(c in morceau for c in '*?[{'):
            break
        morceaux.append(morceau)
    return '/'.join(morceaux) or '.'


def lecture_refusee(entree, entrees):
    """For the read tools: the first path outside ECRAN_LECTURE, otherwise None. No list = no limit."""
    liste = [d for d in os.environ.get('ECRAN_LECTURE', '').split(os.pathsep) if d]
    if not liste:
        return None
    cwd = entree.get('cwd') or os.getcwd()
    chemins = [entrees.get(k) for k in ('file_path', 'notebook_path', 'path') if entrees.get(k)]
    if entree.get('tool_name') in ('Glob', 'Grep'):
        for cle in ('pattern', 'glob'):
            motif = entrees.get(cle)
            if motif and (os.path.isabs(str(motif)) or str(motif).startswith('~') or '..' in str(motif)):
                base = entrees.get('path') or cwd
                chemins.append(os.path.join(base, os.path.expanduser(racine_motif(motif))))
    if not chemins:
        chemins = [cwd]
    for chemin in chemins:
        cible = os.path.join(cwd, os.path.expanduser(str(chemin)))
        if not any(dans(cible, d) for d in liste):
            return cible
    return None


def main():
    try:
        entree = json.loads(sys.stdin.buffer.read().decode('utf-8', 'replace') or '{}')
    except ValueError:
        return 0
    entrees = entree.get('tool_input') or {}

    if entree.get('tool_name') in LECTURE:
        refuse = lecture_refusee(entree, entrees)
        if refuse:
            sys.stderr.write('Blocked: %s is outside the folders you may read (the work folder, the task folder and '
                             'the PDF text). Private files of the computer are off limits.\n' % refuse)
            return 2
        return 0

    # Tools that write files (Edit, Write, MultiEdit, NotebookEdit): nothing inside System-Context.
    # Backs up the deny rule in data/settings.json.
    fichier = entrees.get('file_path') or entrees.get('notebook_path')
    if fichier:
        ctx = contexte()
        cible = os.path.join(entree.get('cwd') or os.getcwd(), os.path.expanduser(str(fichier)))
        if dans(cible, ctx):
            sys.stderr.write('Blocked: %s is read-only (the user\'s documents and instructions). '
                             'You can read these files, not modify them. Write your files elsewhere in the '
                             'current folder.\n' % ctx)
            return 2
        if dans(cible, APP):
            sys.stderr.write('Blocked: %s is ClaudeScreen itself (its scripts, its settings and this guard): read-only. '
                             'Write your files in the current folder.\n' % APP)
            return 2
        return 0

    commande = str(entrees.get('command') or '')
    if not commande:
        return 0
    for raison, motifs in INTERDITS:
        for motif in motifs:
            if re.search(motif, commande, re.IGNORECASE):
                sys.stderr.write('Blocked by ClaudeScreen: %s. Do not try another way round: do the task differently, '
                                 'or explain in your final answer what you could not do.\n' % raison)
                return 2
    # Folders a command may read but never write to: System-Context (the user's documents and instructions)
    # and ClaudeScreen itself (its scripts, its settings and this guard).
    if re.search(ECRITURE, commande, re.IGNORECASE):
        ctx = contexte()
        plat = os.path.expanduser(commande)
        for dossier in (ctx, APP):
            d = os.path.realpath(dossier).rstrip(os.sep)
            nom = os.path.basename(d)
            if (d.lower() in plat.lower() or dossier.rstrip(os.sep).lower() in plat.lower()
                    or (dossier == ctx and nom.lower() in plat.lower())):
                sys.stderr.write('Blocked by ClaudeScreen: %s is read-only. You can read its files, not change them. '
                                 'Write your files in the current folder.\n' % dossier)
                return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
