# System-Context : le contexte permanent de Claude

Ce dossier sert à donner à Claude des informations en plus de ce qu'il voit à l'écran.
Tout est facultatif : s'il est vide, ClaudeEcran fonctionne comme d'habitude.

## instructions.txt : tes consignes permanentes

Écris une consigne par ligne. Elles sont ajoutées à **chaque** tâche, tant que ClaudeEcran tourne.
Les lignes qui commencent par `#` sont ignorées. Le fichier est relu à chaque tâche : tu peux le modifier à tout moment.

Exemples :

```
Je suis en BTS SIO option SISR. Matériel Cisco, Packet Tracer 8.
Pour les QCM : coche les réponses et clique sur Suivant, mais ne clique jamais sur « Terminer l'examen ».
Réponds toujours en français.
```

## Tes documents

Dépose ici tout ce qui peut aider : cours, prises de notes, documentation technique, énoncés, bibliographie, sources...
Tu peux faire des sous-dossiers.

À chaque tâche, Claude reçoit la liste de ces fichiers. Il les considère comme plus fiables que ses connaissances générales : il lit ceux qui concernent la tâche et s'appuie dessus pour répondre.

Formats lus le mieux : `.txt`, `.md`, `.pdf`, images (`.png`, `.jpg`), code, `.csv`, `.html`.
Un document Word ou PowerPoint ? Enregistre-le aussi en PDF.

## Priorités

1. La consigne tapée dans la petite barre (Ctrl+Alt+Shift+C, ou ⌃⌥⇧C sur Mac), pour une seule tâche.
2. `instructions.txt`, pour toutes les tâches.
3. Ce que Claude devine à l'écran.

## Sécurité

Claude peut **seulement lire** ce dossier : il ne peut rien y modifier, déplacer, mettre à la corbeille ni exécuter.
Ce fichier README.md n'est pas envoyé à Claude ; il est recréé s'il est supprimé.
