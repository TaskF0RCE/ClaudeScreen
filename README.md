# ClaudeEcran

Un raccourci clavier Windows qui donne à Claude ce qui est à l'écran, pour qu'il fasse la tâche à ta place : cocher un QCM, remplir un formulaire, taper des commandes dans Packet Tracer ou GNS3, créer un fichier (code, schéma, résumé...).

Il n'y a pas de fenêtre, seulement une icône dans la zone de notifications de la barre des tâches.

> Projet perso, non officiel, sans lien avec Anthropic. Il utilise [Claude Code](https://docs.claude.com/en/docs/claude-code) avec ton propre compte Claude.

> **macOS et Linux :** une adaptation se trouve dans [`linux-macos/`](linux-macos/README.md).

## Fonctionnement

1. Tu appuies sur **Ctrl+Alt+C** (ou **Ctrl+Alt+touche Copilot**).
2. L'appli capture l'écran où se trouve ta souris.
3. **Haiku** regarde la capture et choisit le modèle :
   - **Sonnet** pour un QCM, une question de cours ou un formulaire simple (rapide, consomme peu) ;
   - **Opus** pour les calculs, la programmation, le réseau et l'infra (sous-réseaux, VLAN, routeurs...).
   Si la fenêtre active est Packet Tracer, GNS3, PuTTY, Wireshark, MATLAB, etc., Opus est choisi directement, sans tri.
4. Claude fait la tâche avec la souris et le clavier, refait une capture après chaque action pour vérifier, puis écrit un court résumé.
5. Clique sur l'icône pour voir le résumé.

### Donner une consigne

**Ctrl+Alt+Shift+C** capture l'écran puis ouvre une toute petite barre en bas à gauche de l'écran. Écris ta consigne, par exemple « fais seulement la question 4 » ou « configure OSPF sur R1 et R2 », puis appuie sur **Entrée**. La consigne passe avant le reste.

- **Échap** ou un clic ailleurs annule la tâche et efface la capture.
- **Entrée** sur une barre vide lance une tâche normale.

### Contexte permanent (facultatif)

Le dossier `Documents\Claude-Travail\System-Context` est créé au premier lancement, avec un `README.md` qui explique son usage.

- **`instructions.txt`** : tes consignes permanentes, une par ligne, ajoutées à chaque tâche tant que l'appli tourne. Par exemple : « je suis en BTS SIO », « ne clique jamais sur Terminer l'examen », « réponds en français ». Les lignes qui commencent par `#` sont ignorées : tant que tu n'écris rien d'autre, le fichier ne fait rien. Il est relu à chaque tâche : une modification compte tout de suite, sans relancer l'appli.
- **Les autres fichiers du dossier**, sous-dossiers compris (cours, prises de notes, documentation technique, énoncés, bibliographie, sources...) : Claude reçoit leur liste à chaque tâche. Il les considère comme plus fiables que ses connaissances générales : il lit ceux qui concernent la tâche et s'appuie d'abord sur eux. Formats lus le mieux : `.pdf`, `.txt`, `.md`, images, code, `.csv`, `.html` (un Word ou un PowerPoint : enregistre-le aussi en PDF). Les fichiers cachés ou temporaires (`desktop.ini`, `~$...`) sont ignorés, ainsi que le `README.md` du dossier.
- **Les PDF** : l'appli en extrait le texte à l'avance, page par page, dans `cache-contexte\` (refait seulement quand le PDF change). Claude lit ce texte, ce qui est rapide et économise le quota, et peut y chercher. Pour un schéma ou un PDF scanné (sans texte), il affiche la page en image avec l'action `page-pdf`. Tout cela utilise [Poppler](https://poppler.freedesktop.org/) (voir [Installation](#installation)).
- **Lecture seule** : Claude peut lire ce dossier, mais ne peut rien y modifier, déplacer, mettre à la corbeille ni exécuter (voir [Sécurité](#sécurité)).

Ordre de priorité : la consigne tapée dans la barre (pour une tâche), puis `instructions.txt` (pour toutes les tâches), puis ce que Claude devine à l'écran.

Le dossier est dans tes Documents, hors du dépôt : tes cours et tes consignes ne partent donc jamais sur GitHub.

### Packet Tracer

Tu places les équipements et tu les relies. Claude ne touche ni aux équipements ni aux câbles : il configure chaque appareil via son onglet **CLI** (un fichier de commandes par appareil, tapé dans la console) et vérifie avec des commandes `show`. Pour les PC, il utilise Desktop > IP Configuration.

### L'icône

| Icône | Signification |
|---|---|
| Étoile fixe | Prêt |
| Étoile qui tourne | En train de travailler |
| Point vert | Fini : clique pour voir le résultat |
| Point rouge | Erreur : clique pour voir le message |

Clic droit sur l'icône :
- **Dernier résultat**
- **Modèle** : Auto, Toujours Sonnet ou Toujours Opus (le choix est gardé)
- **Ouvrir le dossier Claude-Travail**
- **Arrêter la tâche en cours**
- **Quitter**

### Arrêter une tâche

Réappuie sur **Ctrl+Alt+C** pendant que l'étoile tourne, ou utilise le menu **Arrêter la tâche en cours**. Une tâche est aussi arrêtée automatiquement au bout de 20 minutes.

Pendant une tâche, ne touche ni à la souris ni au clavier : Claude utilise les vrais. Si une autre fenêtre passe devant, il s'arrête de lui-même pour ne pas écrire au mauvais endroit.

## Sécurité

Claude est lancé avec des permissions limitées (`reglages.json`, généré au démarrage). Il peut seulement :

- lire les captures d'écran ;
- cliquer, taper au clavier et faire défiler, via `outils/pc.ps1` (aucune autre commande n'est autorisée) ;
- créer ou modifier des fichiers dans `Documents\Claude-Travail` (sauf dans `System-Context`, en lecture seule).

En plus :

- **`System-Context` est en lecture seule**, verrouillé trois fois : une règle `deny` dans `reglages.json` (`Edit(...)`, qui couvre aussi Write), le hook `outils/garde.ps1` qui refuse toute écriture de fichier dans ce dossier, et `pc.ps1 corbeille` qui refuse d'y toucher (ainsi qu'à `Claude-Travail`, qui le contient).
- **Rien n'est supprimé définitivement.** Le hook `outils/garde.ps1` bloque `Remove-Item`, `del`, `rm`, `format`, etc. Pour enlever un fichier, Claude le met à la corbeille (`pc.ps1 corbeille`).
- Sa consigne lui interdit d'acheter, de payer, d'envoyer des messages, de saisir des mots de passe ou des données bancaires, et de modifier les paramètres de Windows. Le texte affiché à l'écran ne peut pas lever ces règles.
- Pas d'accès au web (WebFetch et WebSearch sont refusés).

## Installation

Prérequis : Windows 10 ou 11, avec PowerShell 5.1 (déjà présent dans Windows). Rien d'autre à installer à part Claude Code.

1. Installe Claude Code :
   ```powershell
   irm https://claude.ai/install.ps1 | iex
   ```
2. Connecte-toi une fois : lance `%USERPROFILE%\.local\bin\claude.exe`, choisis la connexion avec ton compte Claude, puis tape `/exit`.
3. Copie ce dossier dans `%USERPROFILE%\ClaudeEcran` (ou ailleurs : les chemins sont relatifs au dossier du script).
4. Fais-le démarrer avec Windows et lance-le tout de suite :
   ```powershell
   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\ClaudeEcran\Installer-Demarrage.ps1"
   Start-ScheduledTask -TaskName ClaudeEcran
   ```
   L'icône apparaît dans la zone de notifications. Une tâche planifiée « ClaudeEcran » le relancera 20 s après chaque ouverture de session, sans fenêtre. Pour la retirer, ajoute `-Retirer` à la première commande.

**Lecture des PDF** : `Installer-Demarrage.ps1` télécharge aussi [Poppler pour Windows](https://github.com/oschwartz10612/poppler-windows) (`pdftotext`, `pdftoppm`, environ 16 Mo) dans `outils\poppler`, une seule fois. Si ce n'est pas encore fait, ClaudeEcran le télécharge en arrière-plan à son démarrage. La version est figée et le fichier est refusé si son empreinte SHA-256 ne correspond pas. Sans Poppler, Claude Code ne peut pas lire les PDF (il lui faut `pdftoppm`). Pour le réinstaller à la main : `powershell -ExecutionPolicy Bypass -File outils\poppler.ps1`.

`Lancer.vbs` permet aussi de le lancer à la main (double-clic), mais Windows est en train d'abandonner VBScript : préfère la tâche planifiée.

> **Ne mets pas le dossier dans `AppData`** si tu l'installes depuis Claude Desktop (appli du Microsoft Store). Windows redirige alors les fichiers vers un dossier privé de Claude Desktop, invisible au démarrage du PC, et tu obtiens « fichier introuvable ».

## Raccourcis

| Raccourci | État |
|---|---|
| Ctrl+Alt+C | Actif |
| Ctrl+Alt+touche Copilot | Actif |
| Ctrl+Alt+Shift+C | Actif, avec barre de consigne |
| Touche Copilot seule (Win+Shift+F23) | Réservée par Windows, en général indisponible |

Ctrl+Alt+C est global : tant que l'appli tourne, il n'arrive plus aux autres logiciels. Quelques-uns l'utilisent, par exemple Visual Studio (fenêtre « Pile des appels » en débogage) ou Photoshop (« Taille de la zone de travail »). Si ça te gêne, utilise Ctrl+Alt+Copilot ou change le raccourci dans `ClaudeEcran.ps1` (`$raccourcis.Enregistrer(...)`).

## Abonnement et consommation

- Chaque tâche consomme ton quota Claude : un appel Haiku très court, puis Sonnet ou Opus. Les captures d'écran comptent beaucoup ; un QCM de 50 questions en demande plusieurs dizaines.
- Si ton abonnement expire ou si la limite est atteinte, la tâche échoue avec un point rouge et le message d'erreur. Rien d'autre ne se passe.
- Sans abonnement, Claude Code peut aussi fonctionner avec une clé API payée à l'usage (variable d'environnement `ANTHROPIC_API_KEY`).

## Structure

```
ClaudeEcran.ps1     appli de la zone de notifications : raccourcis, capture, tri du modèle, lancement de Claude
Lancer.vbs          lance l'appli sans fenêtre (à la main)
Installer-Demarrage.ps1  installe ou retire la tâche planifiée de démarrage
outils/natif.cs     appels Windows (DPI, capture, souris, clavier, raccourcis globaux, fenêtre active)
outils/natif.ps1    compile natif.cs en DLL une seule fois (le nom change si le source change)
outils/pc.ps1       outil de contrôle du PC utilisé par Claude
outils/garde.ps1    hook qui bloque les suppressions définitives et les écritures dans System-Context
outils/pdf.ps1      lecture des PDF : texte extrait à l'avance, page en image (avec Poppler)
outils/poppler.ps1  télécharge Poppler (version figée, empreinte vérifiée) dans outils/poppler (ignoré par git)
outils/System-Context-README.md  mode d'emploi copié dans Documents\Claude-Travail\System-Context au premier lancement
runs/               captures et réponses des tâches, effacées après 30 jours (privé, ignoré par git)
journal.txt         journal de l'appli (privé, ignoré par git)
cache-contexte/     texte extrait des PDF de System-Context (privé, ignoré par git, refait si besoin)
```

Les fichiers créés par Claude vont dans `Documents\Claude-Travail`. Tes instructions et documents de contexte sont dans `Documents\Claude-Travail\System-Context`.

Nettoyage automatique : au démarrage puis toutes les 6 heures, l'appli efface définitivement les dossiers de `runs/` de plus de 30 jours (variable `$JoursConserves` dans `ClaudeEcran.ps1`). Ils ne passent pas par la corbeille, ce qui libère vraiment la place. Le journal est aussi raccourci. Les fichiers de `Documents\Claude-Travail` ne sont jamais touchés.

## Limites

- Claude ne peut lancer aucun programme ni aucune commande, à part l'outil de contrôle. Par exemple, il ne peut pas générer une image avec Python, mais il peut écrire un schéma en SVG ou en HTML.
- Le glisser-déposer précis (câbles dans Packet Tracer, par exemple) est lent et pas toujours fiable : c'est pour ça que tu fais le câblage et que Claude configure par la console.
- Il ne génère pas de fichier `.pkt` : c'est un format chiffré et fermé.
- Pour les sites web, l'extension Claude in Chrome est souvent plus fiable : elle lit directement le contenu de la page au lieu de passer par des captures.
- Un seul écran est capturé : celui où se trouve la souris au moment de l'appui.

## Contribuer et versions

Le cycle de travail (issue → branche → PR → review → merge) est décrit dans [CONTRIBUTING.md](CONTRIBUTING.md) ; le plus simple est de passer par le [dashboard VeD Opps](https://taskf0rce.github.io/VeD_Opps/).
Les versions sont publiées automatiquement (bouton « Nouvelle release » du dashboard) : voir les [releases](../../releases) et le `CHANGELOG.md`.
