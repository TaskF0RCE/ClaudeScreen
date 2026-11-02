"""Hook PreToolUse de Claude Code : bloque toute suppression définitive (et les arrêts de l'ordinateur),
et toute écriture dans le dossier de contexte System-Context (lecture seule).

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


def contexte():
    """Dossier de contexte (transmis par ClaudeEcran ; sinon l'emplacement par défaut)."""
    if os.environ.get('ECRAN_CONTEXTE'):
        return os.environ['ECRAN_CONTEXTE']
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import natif
    return os.path.join(natif.dossier_documents(), 'Claude-Travail', 'System-Context')


def dans(chemin, dossier):
    """chemin est-il dossier lui-même ou à l'intérieur ? (liens symboliques et « .. » résolus)"""
    c, d = os.path.realpath(chemin), os.path.realpath(dossier)
    if sys.platform == 'darwin':  # disque insensible à la casse par défaut sur macOS
        c, d = c.lower(), d.lower()
    return c == d or c.startswith(d.rstrip(os.sep) + os.sep)


def main():
    try:
        entree = json.loads(sys.stdin.buffer.read().decode('utf-8', 'replace') or '{}')
    except ValueError:
        return 0
    entrees = entree.get('tool_input') or {}

    # Outils qui écrivent des fichiers (Edit, Write, MultiEdit, NotebookEdit) : rien dans System-Context.
    # Double sécurité avec la règle deny de reglages.json.
    fichier = entrees.get('file_path') or entrees.get('notebook_path')
    if fichier:
        ctx = contexte()
        cible = os.path.join(entree.get('cwd') or os.getcwd(), os.path.expanduser(str(fichier)))
        if dans(cible, ctx):
            sys.stderr.write('Bloqué : %s est en lecture seule (documents et instructions de l\'utilisateur). '
                             'Tu peux lire ces fichiers, pas les modifier. Écris tes fichiers ailleurs dans le '
                             'dossier courant.\n' % ctx)
            return 2
        return 0

    commande = str(entrees.get('command') or '')
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
