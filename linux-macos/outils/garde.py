"""Hook PreToolUse de Claude Code : bloque toute suppression définitive (et les arrêts de l'ordinateur).

Équivalent de garde.ps1. Code de sortie 2 = commande refusée, le message va à Claude.
"""
import json
import os
import re
import sys

MOTIFS = [
    # Commandes de suppression (en début de commande ou après ; & | ( ` " ').
    r'(^|[\s;&|(`"\'])(rm|rmdir|unlink|shred|srm|wipe|del|erase|rd|ri)(\s|$)',
    r'\bRemove-Item\b', r'\bClear-RecycleBin\b', r'\bClear-Content\b',
    r'\bfind\b.*\s-delete\b', r'\bfind\b.*-exec(dir)?\s+(rm|shred|unlink)\b', r'\bxargs\b.*\b(rm|shred|unlink)\b',
    r'\btruncate\b', r'\bos\.(remove|unlink|rmdir)\b', r'\bshutil\.rmtree\b', r'\.unlink\s*\(', r'\.Delete\s*\(',
    # Corbeille vidée.
    r'\bgio\s+trash\s+--empty\b', r'\btrash-empty\b', r'empty\s+(the\s+)?trash',
    # Disques.
    r'\bmkfs(\.\w+)?\b', r'\bdd\b.*\bof=', r'\bwipefs\b', r'\b(s?fdisk|parted|gdisk)\b', r'\bblkdiscard\b',
    r'\bdiskutil\s+(erase\w*|zero\w*|secureErase|reformat|partitionDisk|apfs\s+delete\w*)',
    r'>\s*/dev/(sd|nvme|disk|hd|mmcblk)',
    # Git destructif.
    r'\bgit\s+clean\b', r'\bgit\s+reset\s+--hard\b', r'\bgit\s+push\b.*(--force|\s-f\b)',
    # Arrêt / redémarrage.
    # (seulement en position de commande : « no shutdown » de Cisco tapé avec ecrire reste permis)
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
                'Bloqué : les suppressions définitives (et arrêts de l\'ordinateur) sont interdites. '
                'Pour enlever un fichier ou dossier, mets-le à la corbeille : %s corbeille CHEMIN. '
                'Si c\'était du texte à taper qui a déclenché le blocage, écris-le dans un fichier '
                'et utilise ecrire-fichier.\n' % pc)
            return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
