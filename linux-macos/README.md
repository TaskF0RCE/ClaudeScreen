# ClaudeEcran pour macOS et Linux

Adaptation de [ClaudeEcran](../README.md) (version Windows) : un raccourci clavier donne à Claude ce qui est à l'écran, pour qu'il fasse la tâche à ta place (cocher un QCM, remplir un formulaire, taper des commandes dans Packet Tracer ou GNS3, créer un fichier...).

Il n'y a pas de fenêtre, seulement une icône dans la **barre des menus** (macOS) ou la **zone de notifications** (Linux).

> Projet perso, non officiel, sans lien avec Anthropic. Il utilise [Claude Code](https://docs.claude.com/en/docs/claude-code) avec ton propre compte Claude.

## Fonctionnement

Identique à la version Windows :

1. Tu appuies sur **⌃⌥C** (Ctrl+Option+C) sur Mac, ou **Ctrl+Alt+C** sous Linux.
2. L'appli capture l'écran où se trouve ta souris.
3. **Haiku** regarde la capture et choisit **Sonnet** (QCM, question de cours, formulaire simple) ou **Opus** (calculs, programmation, réseau, infra). Si la fenêtre active est Packet Tracer, GNS3, PuTTY, Wireshark, MATLAB, etc., Opus est choisi directement.
4. Claude fait la tâche avec la souris et le clavier, refait une capture après chaque action pour vérifier, puis écrit un court résumé.
5. Clique sur l'icône → **Dernier résultat** pour le lire.

**⌃⌥⇧C** / **Ctrl+Alt+Shift+C** capture l'écran puis ouvre une petite barre en bas à gauche : écris une consigne (« fais seulement la question 4 », « configure OSPF sur R1 et R2 »), puis **Entrée**. **Échap** ou un clic ailleurs annule.

Réappuyer sur le raccourci pendant une tâche l'arrête (ou menu **Arrêter la tâche en cours**). Arrêt automatique au bout de 20 minutes. Pendant une tâche, ne touche ni à la souris ni au clavier.

### Contexte permanent (facultatif)

Comme sous Windows, le dossier **`~/Documents/Claude-Travail/System-Context`** est créé au premier lancement, avec un `README.md` qui explique son usage (menu **Ouvrir le dossier Claude-Travail** pour y accéder).

- **`instructions.txt`** : tes consignes permanentes, une par ligne, ajoutées à chaque tâche tant que l'appli tourne (« je suis en BTS SIO », « ne clique jamais sur Terminer l'examen », « réponds en français »...). Les lignes qui commencent par `#` sont ignorées. Le fichier est relu à chaque tâche : une modification compte tout de suite.
- **Les autres fichiers**, sous-dossiers compris (cours, prises de notes, documentation technique, énoncés, bibliographie, sources...) : Claude reçoit leur liste à chaque tâche, les considère comme plus fiables que ses connaissances générales, lit ceux qui concernent la tâche et s'appuie d'abord sur eux. Formats lus le mieux : `.txt`, `.md`, `.pdf`, images, code, `.csv`, `.html` (un Word ou un Keynote : exporte-le aussi en PDF). Les fichiers cachés ou temporaires (`.DS_Store`, `~$...`) sont ignorés, ainsi que le `README.md` du dossier.
- **Lecture seule** : Claude peut lire ce dossier, mais ne peut rien y modifier, déplacer, mettre à la corbeille ni exécuter.

Ordre de priorité : la consigne de la barre (pour une tâche), puis `instructions.txt` (pour toutes les tâches), puis ce que Claude devine à l'écran.

Le dossier est dans tes Documents, hors du dépôt : son contenu ne part jamais sur GitHub.

### L'icône

| Icône | Signification |
|---|---|
| Étoile fixe | Prêt |
| Étoile qui tourne | En train de travailler |
| Point vert | Fini : ouvre « Dernier résultat » |
| Point rouge | Erreur : ouvre « Dernier résultat » pour le message |

Menu : **Dernier résultat**, **Modèle** (Auto, Toujours Sonnet, Toujours Opus ; le choix est gardé), **Ouvrir le dossier Claude-Travail**, **Arrêter la tâche en cours**, **Quitter**.

Sur macOS et avec la plupart des bureaux Linux (AppIndicator), un clic sur l'icône ouvre le menu ; « Dernier résultat » est la première ligne.

## Installation

### 1. Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude        # connecte-toi une fois avec ton compte Claude, puis tape /exit
```

### 2. ClaudeEcran

Copie le dossier `linux-macos` où tu veux (dans un chemin **sans espace**, par exemple `~/ClaudeEcran`), puis :

```bash
cd ~/ClaudeEcran/linux-macos      # adapte le chemin
./installer.sh
```

Le script crée un environnement Python dans `donnees/.venv`, installe les dépendances, crée le lanceur, propose le démarrage automatique et affiche un diagnostic. Options : `--demarrage-auto`, `--sans-demarrage-auto`, `--raccourcis-gnome`, `-y` (sans questions), `--desinstaller`.

### macOS (10.15 ou plus récent)

- Prérequis : Python 3.9+ ([python.org](https://www.python.org/downloads/macos/) conseillé : Tk est inclus, donc la barre de consigne et la fenêtre de résultat sont de vraies fenêtres. Avec Homebrew : `brew install python python-tk`).
- L'installation crée **`~/Applications/ClaudeEcran.app`** : ouvre-la (Spotlight → « ClaudeEcran »).
- **Autorisations** : au premier lancement, macOS demande
  - **Enregistrement de l'écran** (pour les captures) ;
  - **Accessibilité** (pour cliquer et taper).

  Accepte les deux dans *Réglages Système → Confidentialité et sécurité*, puis **quitte et relance** ClaudeEcran. Selon la version de macOS, l'élément à cocher s'appelle « ClaudeEcran », « Python » ou « Terminal » (si tu l'as lancé depuis le Terminal). En cas de doute : `./lancer.sh diagnostic`.
- Le raccourci ⌃⌥C est enregistré comme sous Windows (RegisterEventHotKey) : aucune autorisation supplémentaire, et il n'arrive plus aux autres applis tant que ClaudeEcran tourne.
- Démarrage automatique : l'installateur ajoute `~/Library/LaunchAgents/local.claudeecran.plist`.
- Raccourcis clavier pour Claude : sur Mac il utilise `cmd+c`, `cmd+v`, `cmd+s`... (sa consigne le lui indique), et `ctrl` reste disponible pour les terminaux.

### Linux

Une session **X11** (« Ubuntu sur Xorg », « GNOME sur Xorg », KDE X11, Xfce, MATE, Cinnamon...) fonctionne entièrement. Sous **Wayland**, voir plus bas.

Paquets système utiles (l'installateur indique ceux qui manquent) :

```bash
# Debian / Ubuntu / Mint
sudo apt install python3-venv python3-tk python3-gi gir1.2-ayatanaappindicator3-0.1
# Fedora
sudo dnf install python3-tkinter python3-gobject libayatana-appindicator-gtk3
# Arch
sudo pacman -S tk python-gobject libayatana-appindicator
```

- Sous GNOME, l'icône a besoin de l'extension **AppIndicator** (active par défaut sur Ubuntu ; ailleurs : « AppIndicator and KStatusNotifierItem Support »).
- Lancement : menu des applications → **ClaudeEcran**, ou `./lancer.sh`.
- Démarrage automatique : `~/.config/autostart/claude-ecran.desktop`.

#### Wayland

Wayland empêche volontairement les applis d'écouter le clavier, de lire l'écran et de piloter la souris des autres fenêtres. ClaudeEcran s'y adapte en partie :

| Fonction | Sous Wayland |
|---|---|
| Raccourci | Déclaré dans les réglages du bureau ; l'installateur le fait pour GNOME (`--raccourcis-gnome`). Ailleurs (KDE...), ajoute deux raccourcis personnalisés : Ctrl+Alt+C → `".../lancer.sh" declencher` et Ctrl+Alt+Shift+C → `".../lancer.sh" consigne`. |
| Capture | Avec `grim` (Sway, Hyprland), `gnome-screenshot` (GNOME) ou `spectacle` (KDE). Toujours le premier écran. |
| Souris et clavier | Avec [`ydotool`](https://github.com/ReimuNotMoe/ydotool) (version 1.x, service `ydotoold` lancé, accès à `/dev/uinput`). Désactive l'accélération de la souris pour des clics précis. Frappe limitée à la disposition QWERTY. Sans ydotool, seules les applis XWayland reçoivent les clics. |
| Fenêtre active | Inconnue (le tri Packet Tracer → Opus direct ne marche pas, Haiku choisit). |

**Conseil : pour une utilisation fiable, ouvre une session X11** (écran de connexion → roue dentée → « Ubuntu sur Xorg »).

## Commandes

```bash
./lancer.sh               # lance l'appli
./lancer.sh declencher    # comme Ctrl+Alt+C
./lancer.sh consigne      # comme Ctrl+Alt+Shift+C
./lancer.sh arreter       # arrête la tâche en cours
./lancer.sh resultat      # affiche le dernier résultat
./lancer.sh etat          # prêt / en cours
./lancer.sh quitter
./lancer.sh diagnostic    # vérifie capture, autorisations, Claude Code, modules...
```

## Sécurité

Comme sous Windows, Claude est lancé avec des permissions limitées (`reglages.json`, généré au démarrage). Il peut seulement :

- lire les captures d'écran ;
- cliquer, taper au clavier et faire défiler, via `donnees/pc` (aucune autre commande n'est autorisée) ;
- créer ou modifier des fichiers dans `~/Documents/Claude-Travail` (sauf dans `System-Context`, en lecture seule).

En plus :

- **`System-Context` est en lecture seule**, verrouillé trois fois : une règle `deny` dans `reglages.json` (`Edit(//...)`, qui couvre aussi Write), le hook `outils/garde.py` qui refuse toute écriture de fichier dans ce dossier (y compris via un lien symbolique ou `..`), et `pc corbeille` qui refuse d'y toucher (ainsi qu'à `Claude-Travail`, qui le contient).
- **Rien n'est supprimé définitivement.** Le hook `outils/garde.py` bloque `rm`, `rmdir`, `unlink`, `shred`, `find -delete`, `dd`, `mkfs`, `diskutil erase`, `git clean`, `shutdown`, etc. Pour enlever un fichier, Claude le met à la corbeille (`pc corbeille`).
- Sa consigne lui interdit d'acheter, de payer, d'envoyer des messages, de saisir des mots de passe ou des données bancaires, et de modifier les réglages du système. Le texte affiché à l'écran ne peut pas lever ces règles.
- Pas d'accès au web (WebFetch et WebSearch sont refusés).

## Abonnement et consommation

Identique à la version Windows : chaque tâche consomme ton quota Claude (un appel Haiku très court, puis Sonnet ou Opus ; les captures comptent beaucoup). Si la limite est atteinte, la tâche échoue avec un point rouge. Sans abonnement, Claude Code peut utiliser une clé API (`ANTHROPIC_API_KEY`, transmise à Claude).

## Structure

```
claude_ecran.py     appli (barre des menus / zone de notifications) : raccourcis, capture, tri du modèle, lancement de Claude
installer.sh        installation : environnement Python, dépendances, ClaudeEcran.app (macOS) ou entrée de menu (Linux), démarrage auto
lancer.sh           lance l'appli en arrière-plan, ou lui envoie une commande (declencher, consigne...)
requirements.txt    dépendances Python
outils/natif.py     appels système : écrans, capture, souris, clavier (XTest sous X11), fenêtre active, corbeille
outils/raccourcis.py raccourcis globaux (Carbon sur macOS, écouteur X11 sous Linux)
outils/fenetres.py  fenêtre « dernier résultat » et barre de consigne (Tk, processus séparé)
outils/pc.py        outil de contrôle de l'ordinateur utilisé par Claude
outils/garde.py     hook qui bloque les suppressions définitives et les écritures dans System-Context
outils/System-Context-README.md  mode d'emploi copié dans ~/Documents/Claude-Travail/System-Context au premier lancement
donnees/            TOUT ce qui est généré, à part du programme (privé, ignoré par git) :
  runs/               captures et réponses des tâches, effacées après 30 jours
  journal.txt         journal de l'appli
  reglages.json       permissions données à Claude (régénéré à chaque démarrage)
  pc                  lanceur de outils/pc.py utilisé par Claude (régénéré à chaque démarrage)
  modele.txt          choix du modèle (menu Modèle)
  dernier-resultat.txt
  icone.png           icône du menu des applications (Linux)
  .venv/              environnement Python créé par installer.sh
  cache/              fichiers compilés de Python
```

Correspondance avec la version Windows : `ClaudeEcran.ps1` → `claude_ecran.py`, `Lancer.vbs` → `lancer.sh` / `ClaudeEcran.app`, `natif.cs` + `natif.ps1` → `natif.py` + `raccourcis.py`, `pc.ps1` → `pc.py`, `garde.ps1` → `garde.py`.

## Limites

- Mêmes limites que la version Windows : Claude ne lance aucun programme à part l'outil de contrôle ; le glisser-déposer précis est lent ; pas de fichier `.pkt` ; un seul écran capturé (celui de la souris).
- Wayland : voir le tableau ci-dessus.
- macOS : si tu déplaces le dossier après l'installation, relance `./installer.sh` (l'appli et le démarrage auto contiennent le chemin). Sur macOS 15 et plus, le système peut redemander périodiquement l'autorisation d'enregistrement de l'écran.
