"""Claude Code PreToolUse hook: blocks any permanent deletion (and shutting down the computer),
and any write to the System-Context folder (read-only).

Equivalent of garde.ps1. Exit code 2 = command refused, the message goes to Claude.
"""
import json
import os
import re
import sys

MOTIFS = [
    # Deletion commands (at the start of a command or after ; & | ( ` " ').
    r'(^|[\s;&|(`"\'])(rm|rmdir|unlink|shred|srm|wipe|del|erase|rd|ri)(\s|$)',
    r'\bRemove-Item\b', r'\bClear-RecycleBin\b', r'\bClear-Content\b',
    r'\bfind\b.*\s-delete\b', r'\bfind\b.*-exec(dir)?\s+(rm|shred|unlink)\b', r'\bxargs\b.*\b(rm|shred|unlink)\b',
    r'\btruncate\b', r'\bos\.(remove|unlink|rmdir)\b', r'\bshutil\.rmtree\b', r'\.unlink\s*\(', r'\.Delete\s*\(',
    # Emptying the trash.
    r'\bgio\s+trash\s+--empty\b', r'\btrash-empty\b', r'empty\s+(the\s+)?trash',
    # Disks.
    r'\bmkfs(\.\w+)?\b', r'\bdd\b.*\bof=', r'\bwipefs\b', r'\b(s?fdisk|parted|gdisk)\b', r'\bblkdiscard\b',
    r'\bdiskutil\s+(erase\w*|zero\w*|secureErase|reformat|partitionDisk|apfs\s+delete\w*)',
    r'>\s*/dev/(sd|nvme|disk|hd|mmcblk)',
    # Destructive git.
    r'\bgit\s+clean\b', r'\bgit\s+reset\s+--hard\b', r'\bgit\s+push\b.*(--force|\s-f\b)',
    # Shutdown / reboot.
    # (only in command position: Cisco's "no shutdown" typed with ecrire is still allowed)
    r'(^|[;&|(`]\s*|\bsudo\s+|\bexec\s+)(shutdown|reboot|halt|poweroff)\b', r'\bsystemctl\s+(poweroff|reboot|halt|kexec)\b',
    r'\b(shut\s+down|restart)\b.*System Events', r'\bpmset\b.*\b(sleepnow|halt)\b',
]


def contexte():
    """Context folder (passed by ClaudeScreen; otherwise the default location)."""
    if os.environ.get('ECRAN_CONTEXTE'):
        return os.environ['ECRAN_CONTEXTE']
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import natif
    return os.path.join(natif.dossier_documents(), 'Claude-Travail', 'System-Context')


def dans(chemin, dossier):
    """Is chemin the folder itself or inside it? (symlinks and ".." resolved)"""
    c, d = os.path.realpath(chemin), os.path.realpath(dossier)
    if sys.platform == 'darwin':  # case-insensitive disk by default on macOS
        c, d = c.lower(), d.lower()
    return c == d or c.startswith(d.rstrip(os.sep) + os.sep)


def main():
    try:
        entree = json.loads(sys.stdin.buffer.read().decode('utf-8', 'replace') or '{}')
    except ValueError:
        return 0
    entrees = entree.get('tool_input') or {}

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
        return 0

    commande = str(entrees.get('command') or '')
    if not commande:
        return 0
    for motif in MOTIFS:
        if re.search(motif, commande, re.IGNORECASE):
            pc = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'data', 'pc')
            sys.stderr.write(
                'Blocked: permanent deletions (and shutting down the computer) are forbidden. '
                'To remove a file or folder, send it to the trash: %s corbeille PATH. '
                'If text you meant to type triggered the block, write it to a file '
                'and use ecrire-fichier.\n' % pc)
            return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
