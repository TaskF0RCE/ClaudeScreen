"""Claude Code PreToolUse hook: blocks any permanent deletion (and shutting down the computer).

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


def main():
    try:
        entree = json.loads(sys.stdin.buffer.read().decode('utf-8', 'replace') or '{}')
    except ValueError:
        return 0
    commande = str((entree.get('tool_input') or {}).get('command') or '')
    if not commande:
        return 0
    for motif in MOTIFS:
        if re.search(motif, commande, re.IGNORECASE):
            pc = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'donnees', 'pc')
            sys.stderr.write(
                'Blocked: permanent deletions (and shutting down the computer) are forbidden. '
                'To remove a file or folder, send it to the trash: %s corbeille PATH. '
                'If text you meant to type triggered the block, write it to a file '
                'and use ecrire-fichier.\n' % pc)
            return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
