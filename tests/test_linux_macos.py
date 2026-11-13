"""Tests of the logic of linux-macos/claude_screen.py, on any system (Windows included).

The system modules (natif, raccourcis, pdf, fcntl) are replaced by small fakes, and everything happens in a
temporary folder: nothing touches the screen, your Documents or Claude.
Usage: python tests/test_linux_macos.py
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import types

depot = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bac = tempfile.mkdtemp(prefix='claudescreen-tests-')
app = os.path.join(bac, 'depot', 'linux-macos')
shutil.copytree(os.path.join(depot, 'linux-macos'), app, ignore=shutil.ignore_patterns('data', '__pycache__'))
shutil.copytree(os.path.join(depot, 'contexts'), os.path.join(bac, 'depot', 'contexts'))
docs, poubelle = os.path.join(bac, 'docs'), os.path.join(bac, 'bin')
tests = echecs = 0


def verifier(nom, ok, detail=''):
    global tests, echecs
    tests += 1
    if ok:
        print('  ok    ' + nom)
    else:
        echecs += 1
        print('  FAIL  %s  %s' % (nom, detail))


def faux(nom, **attributs):
    m = types.ModuleType(nom)
    m.__dict__.update(attributs)
    sys.modules[nom] = m
    return m


def corbeille(chemin):
    os.makedirs(poubelle, exist_ok=True)
    shutil.move(chemin, os.path.join(poubelle, '%s.%d' % (os.path.basename(chemin), len(os.listdir(poubelle)))))


def lire(chemin):
    with open(chemin, encoding='utf-8-sig') as f:
        return f.read()


# Documents of a user coming from an old version: Claude-Travail, notes at the end of instructions.md.
ancien = os.path.join(docs, 'Claude-Travail', 'System-Context')
os.makedirs(ancien)
with open(os.path.join(docs, 'Claude-Travail', 'report.txt'), 'w') as f:
    f.write('a file made by Claude earlier')
with open(os.path.join(ancien, 'README.md'), 'w') as f:
    f.write('old guide')
with open(os.path.join(ancien, 'instructions.md'), 'w', encoding='utf-8') as f:
    f.write('<!--\nStanding instructions for Claude (optional): write them below this comment, one per line.\n\n'
            'Keep the dashed line below. What you write above it is yours: it is never changed.\n'
            'Below it, Claude writes its notes while "Persistent memory" is checked in the icon menu;\n'
            'they are erased when you uncheck it.\n-->\n\n\n---------------------\n'
            "<!-- Claude's notes (persistent memory): erased when the mode is turned off. -->\n"
            '- User writes reports in Word; report for client Dupont in progress\n'
            '- Budget sheet 2026: columns A to F checked on 09/11\n'
            '- Lab 3: routers R0 to R3 configured, PCs not addressed yet\n')

faux('fcntl')
faux('natif', MAC=False, LINUX=True, SESSION='x11', dossier_documents=lambda: docs, corbeille=corbeille,
     ouvrir=lambda c: None)
faux('raccourcis', NORMAL=1, CONSIGNE=4, noms=lambda: {1: 'Ctrl+Alt+C', 4: 'Ctrl+Alt+Shift+C'})
faux('pdf', disponible=lambda: False)
os.getuid = lambda: 0
sys.path.insert(0, app)
import claude_screen as cs  # noqa: E402
memoire = cs.memoire
os.makedirs(os.path.join(cs.DONNEES), exist_ok=True)
with open(cs.FICHIER_MEMOIRE, 'w') as f:
    f.write('on')

print('--- startup')
cs.renommer_travail()
os.makedirs(cs.TRAVAIL, exist_ok=True)
cs.preparer_contexte()
verifier('work folder is Claude-Work', cs.TRAVAIL == os.path.join(docs, 'Claude-Work') and os.path.isdir(cs.TRAVAIL))
verifier('old folder is gone', not os.path.exists(os.path.join(docs, 'Claude-Travail')))
verifier('files followed the rename', os.path.exists(os.path.join(cs.TRAVAIL, 'report.txt')))
ins = lire(cs.FICHIER_INSTRUCTIONS)
verifier('instructions.md: no dashed line, no notes', '----------' not in ins and 'Dupont' not in ins)
verifier('instructions.md: stale lines replaced', 'dashed line' not in ins and 'go to memory.md' in ins)
verifier('instructions.md: ends with the comment', ins.rstrip().endswith('-->'), repr(ins[-40:]))
verifier('instructions.md: no instruction', cs.lire_instructions() == '')
mem = memoire.notes(cs.FICHIER_NOTES)
verifier('memory.md: the 3 notes moved', len(mem.split('\n')) == 3 and 'Dupont' in mem and 'Lab 3' in mem, mem)
verifier('guide replaced, old one in the trash',
         cs._memes_fichiers(os.path.join(cs.OUTILS, 'System-Context-README.md'), cs.FICHIER_LISEZMOI)
         and any(n.startswith('README.md') for n in os.listdir(poubelle)))
verifier('Contexts folder created with the files of the app',
         sorted(os.listdir(cs.DOSSIER_CONTEXTES)) == sorted(os.listdir(os.path.join(depot, 'contexts'))))
avant = lire(cs.FICHIER_INSTRUCTIONS)
cs.preparer_contexte()
verifier('second start changes nothing', lire(cs.FICHIER_INSTRUCTIONS) == avant and memoire.notes(cs.FICHIER_NOTES) == mem)

print('--- prompt and end of a task')
a = cs.Appli()
a.icone = types.SimpleNamespace(icon=None, title='')
appels = []
a.demarrer_claude = lambda modele, nom, options: appels.append((modele, nom, options))
a.memoire = True
os.makedirs(cs.RUNS, exist_ok=True)


def capture():
    run = os.path.join(cs.RUNS, 'test-%d' % len(os.listdir(cs.RUNS)))
    for d in ('images', 'prompts', 'responses'):
        os.makedirs(os.path.join(run, d))
    return dict(run=run, png=os.path.join(run, 'images', 'screenshot-01.png'), fenetre=('gedit', 'Test'), ident=None,
                ecran={}, largeur=1398, hauteur=787)


def prompt(c, nom='task'):
    return lire(os.path.join(c['run'], 'prompts', nom + '.txt'))


def repondre(c, texte, nom='task'):
    with open(os.path.join(c['run'], 'responses', nom + '.txt'), 'w', encoding='utf-8') as f:
        f.write(texte)


c = capture()
a.lancer_tache(c, 'connect R0 and R1')
verifier('triage started with the light options', appels[-1] == ('haiku', 'triage', ['--tools', 'Read', '--effort', 'low']), appels[-1:])
p = prompt(c)
fixe = p[p.index('1. Find what'):]
verifier('prompt: actions, MEMORY, notes', '\n  relier X1 Y1 X2 Y2 ' in p and 'starting with "MEMORY: "' in p and 'Dupont' in p
         and 'Do not add, move or delete what the user has set up' in p)
verifier('prompt: nothing specific to a software, a field or a profile',
         not re.search('Packet Tracer|GNS3|OSPF|subnetting|VLAN|Cisco|BTS|student|course', fixe))
verifier('prompt: answer in the language of the computer', 'language code: ' + cs.LANGUE in p and 'in French' not in p, cs.LANGUE)
verifier('prompt: work folder', 'current folder: ' + cs.TRAVAIL in p)
verifier('prompt: Default context and its text', 'Active context: Default (chosen by the user in the icon menu)' in p
         and 'General assistant' in p and '<!--' not in p)
verifier('prompt: context files are not listed as documents', cs.DOSSIER_CONTEXTES not in p)
verifier('triage: names the context', '\nActive context: Default.\n' in prompt(c, 'triage'))
a.proc = types.SimpleNamespace(returncode=0)
repondre(c, 'OPUS', 'triage')
a.processus_fini()
verifier('task started with the MCP config of this task',
         appels[-1] == ('opus', 'task', ['--tools', 'Read,Write,Edit,Glob,Grep', '--mcp-config', os.path.join(c['run'], 'mcp.json')]), appels[-1:])
with open(os.path.join(c['run'], 'mcp.json'), encoding='utf-8') as f:
    serveur = json.load(f)['mcpServers']['pc']
verifier('mcp.json starts mcp.py for this task', serveur['command'] == sys.executable and serveur['args'] == [os.path.join(cs.OUTILS, 'mcp.py')]
         and serveur['env']['ECRAN_RUN'] == c['run'] and serveur['env']['ECRAN_CONTEXTE'] == cs.CONTEXTE, serveur)
verifier('prompt: pc tool (MCP), no terminal, no launcher', 'the "pc" tool (mcp__pc__pc)' in p and '\nThere is no terminal.\n' in p
         and 'Chain only clicks on things you have already seen' in p and 'data/pc' not in p and 'in the terminal' not in p)
cs.preparer_outils()
with open(cs.REGLAGES, encoding='utf-8') as f:
    reglages = json.load(f)
verifier('settings.json: pc tool allowed, no Bash', reglages['permissions']['allow'] == ['Read', 'Glob', 'Grep', 'mcp__pc'], reglages['permissions'])
repondre(c, 'R0 and R1 are linked.\nThe link is green.\n\nMEMORY: R0 and R1 linked on 10/11\n- **MEMORY:** PC0 not addressed yet\n'
            'MEMORY: Budget sheet 2026: columns A to F checked on 09/11\n')
a.proc = types.SimpleNamespace(returncode=0)
a.processus_fini()
verifier('result: duration shown, MEMORY lines hidden, warning when the control tool did not start',
         re.fullmatch(r'\[opus, \d+ s\] R0 and R1 are linked\.\nThe link is green\.\n\n\(Warning: the computer control tool did not start.*\)', a.dernier) is not None, a.dernier)
mem = memoire.notes(cs.FICHIER_NOTES)
verifier('memory.md: 2 new notes, duplicate skipped', len(mem.split('\n')) == 5 and '\n- PC0 not addressed yet' in mem, mem)
verifier('tooltip named Claude-Work', a.icone.title.startswith('Claude-Work - done: '), a.icone.title)
verifier('instructions.md untouched', lire(cs.FICHIER_INSTRUCTIONS) == avant)

print('--- contexts')
noms = cs.lister_contextes()
verifier('Default comes first in the list', noms[0] == 'Default' and 'Networking' in noms and 'Studies' in noms, noms)
cs.ecrire_texte(cs.FICHIER_CONTEXTE, 'Networking')
a.choix_modele = 'sonnet'
c = capture()
a.lancer_tache(c, '')
p = prompt(c)
verifier('chosen context replaces Default', 'Active context: Networking' in p and 'addressing' in p and 'General assistant' not in p)
with open(os.path.join(cs.DOSSIER_CONTEXTES, 'My job.md'), 'w', encoding='utf-8') as f:
    f.write('<!-- mine -->\nI am an accountant.\n')
verifier("a file added by the user is listed", 'My job' in cs.lister_contextes())
cs.ecrire_texte(cs.FICHIER_CONTEXTE, 'My job')
verifier("the user's own context, without its comment", cs.contexte_actif() == ('My job', 'I am an accountant.'), cs.contexte_actif())
corbeille(os.path.join(cs.DOSSIER_CONTEXTES, 'My job.md'))
verifier('active file gone: back to Default', cs.contexte_actif()[0] == 'Default')
corbeille(os.path.join(cs.DOSSIER_CONTEXTES, 'Default.md'))
c = capture()
a.lancer_tache(c, '')
verifier('no Default file either: the task still starts', 'Active context: Default (chosen by the user in the icon menu).\n' in prompt(c))

print('--- memory full, then off')
n, retirees = memoire.ajouter(cs.FICHIER_NOTES, ['note %d %s' % (i, 'x' * 280) for i in range(1, 17)])
mem = memoire.notes(cs.FICHIER_NOTES)
verifier('memory full: the oldest notes make room', n == 16 and retirees >= 5 and 3000 < len(mem) <= 4000
         and 'Dupont' not in mem and '\n- note 16 x' in mem and lire(cs.FICHIER_NOTES).startswith('<!--'), (n, retirees, len(mem)))
c2 = capture()
a.lancer_tache(c2, '')
repondre(c2, 'Done.\nMEMORY: the newest note')
open(os.path.join(c2['run'], 'mcp-started.txt'), 'w').close()  # what outils/mcp.py leaves when Claude Code reaches it
a.proc = types.SimpleNamespace(returncode=0)
a.processus_fini()
verifier('a task on a full memory: note saved, nothing said to the user',
         re.fullmatch(r'\[sonnet, \d+ s\] Done\.', a.dernier) is not None and '\n- the newest note' in memoire.notes(cs.FICHIER_NOTES), a.dernier)
verifier('memory off: memory.md emptied, the cleared notes kept once in data, nothing in the trash',
         memoire.vider(cs.FICHIER_NOTES, cs.FICHIER_NOTES_AVANT) and memoire.notes(cs.FICHIER_NOTES) == ''
         and lire(cs.FICHIER_NOTES).startswith('<!--') and 'the newest note' in memoire.notes(cs.FICHIER_NOTES_AVANT)
         and not any(n.startswith('memory') for n in os.listdir(poubelle)))
verifier('memory off with no notes: the kept notes are not replaced',
         not memoire.vider(cs.FICHIER_NOTES, cs.FICHIER_NOTES_AVANT) and 'the newest note' in memoire.notes(cs.FICHIER_NOTES_AVANT))
a.memoire = False
c3 = capture()
a.lancer_tache(c3, '')
verifier('memory off: nothing about memory in the prompt', 'MEMORY' not in prompt(c3) and 'Persistent memory' not in prompt(c3))

verifier('memory is on unless switched off', memoire.active(os.path.join(bac, 'nothing.txt')) and not os.path.exists(os.path.join(bac, 'nothing.txt')))

print('--- instructions.txt from an old version')
vieux = os.path.join(bac, 'old')
os.makedirs(vieux)
with open(os.path.join(vieux, 'instructions.txt'), 'w', encoding='utf-8') as f:
    f.write('# Lines starting with # are ignored.\n# Example -- one\nAlways answer briefly.\n')
verifier('converted, old file to the trash',
         memoire.migrer(os.path.join(vieux, 'instructions.txt'), os.path.join(vieux, 'instructions.md'), corbeille)
         and not os.path.exists(os.path.join(vieux, 'instructions.txt'))
         and lire(os.path.join(vieux, 'instructions.md')) ==
         '<!-- Comments like this one are ignored. Write your instructions below, one per line. -->\n'
         '<!-- Example - - one -->\nAlways answer briefly.\n', repr(lire(os.path.join(vieux, 'instructions.md'))))
with open(os.path.join(vieux, 'mine.md'), 'w', encoding='utf-8') as f:
    f.write('My own text.\n\n---------------------\nnot a note of Claude\n')
verifier('a dashed line written by the user is left alone',
         not memoire.migrer_memoire(os.path.join(vieux, 'mine.md'), os.path.join(vieux, 'memory.md'))
         and not os.path.exists(os.path.join(vieux, 'memory.md')))

print('--- Claude Code update')
cs.trouver_claude = lambda: sys.executable  # a fake claude: "python update" fails at once
a.proc = None
a.mettre_a_jour_claude()
verifier('update started with the update argument', a.maj is not None and a.maj.args == [sys.executable, 'update'], getattr(a.maj, 'args', None))
a.maj.wait(timeout=30)
a.maj = types.SimpleNamespace(poll=lambda: None)
a.mettre_a_jour_claude()
verifier('not twice at once', isinstance(a.maj, types.SimpleNamespace))
a.maj = None
cs.trouver_claude = lambda: None
a.mettre_a_jour_claude()
verifier('no Claude Code: nothing started', a.maj is None)

print('--- guard hook (outils/garde.py)')


def garde(entree):
    r = subprocess.run([sys.executable, os.path.join(app, 'outils', 'garde.py')], input=entree.encode(), capture_output=True,
                       env=dict(os.environ, ECRAN_CONTEXTE=cs.CONTEXTE))
    return r.returncode


verifier('a harmless command is allowed', garde('{"tool_input":{"command":"ls -la"}}') == 0)
verifier('rm is blocked', garde('{"tool_input":{"command":"rm -rf build"}}') == 2)

print('--- MCP server (outils/mcp.py), driven as Claude Code drives it')
# The only actions run are waits and refused ones: nothing is clicked, typed or captured.
run_mcp = os.path.join(bac, 'run-mcp')
os.makedirs(run_mcp)
with open(os.path.join(run_mcp, 'screen.json'), 'w') as f:
    json.dump(dict(gauche=0, haut=0, largeurEcran=1920, hauteurEcran=1080, echelle=1920 / 1398, largeur=1398, hauteur=787), f)
mcp = subprocess.Popen([sys.executable, os.path.join(app, 'outils', 'mcp.py')], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, env=dict(os.environ, ECRAN_RUN=run_mcp, ECRAN_CONTEXTE=cs.CONTEXTE))


def appel(methode, params=None, ident=1):
    message = {'jsonrpc': '2.0', 'id': ident, 'method': methode}
    if params is not None:
        message['params'] = params
    mcp.stdin.write((json.dumps(message) + '\n').encode())
    mcp.stdin.flush()
    return json.loads(mcp.stdout.readline().decode('utf-8'))


def outil(actions, capture=False):
    r = appel('tools/call', {'name': 'pc', 'arguments': {'actions': actions, 'capture': capture}}, 50)['result']
    return r['isError'], r['content'][0]['text'], len(r['content'])


r = appel('initialize', {'protocolVersion': '2025-06-18', 'capabilities': {}, 'clientInfo': {'name': 't', 'version': '1'}})
verifier('initialize: echoes the protocol version', r['id'] == 1 and r['result']['protocolVersion'] == '2025-06-18'
         and r['result']['serverInfo']['name'] == 'claudescreen-pc', r)
verifier('initialize: leaves mcp-started.txt for the app', os.path.exists(os.path.join(run_mcp, 'mcp-started.txt')))
mcp.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
r = appel('tools/list', ident=2)
verifier('tools/list: one tool, pc', len(r['result']['tools']) == 1 and r['result']['tools'][0]['name'] == 'pc'
         and r['result']['tools'][0]['inputSchema']['required'] == ['actions'], r)
r = outil(['attendre 5', 'attendre 5'])
verifier('two actions in one call, no screenshot', not r[0] and r[2] == 1 and r[1].startswith('1. attendre: OK\n2. attendre: OK'), r)
r = outil(['attendre 5', 'relier 1 2', 'attendre 5', 'attendre 5'])
verifier('an error stops the batch', r[0] and r[1].startswith("1. attendre: OK\n2. relier: ERROR: Missing argument 3 for 'relier'.\n"
                                                              'The 2 action(s) after it were not run.'), r)
r = outil(['clic abc 10'])
verifier('bad number', r[0] and "Invalid argument 1 for 'clic': abc" in r[1], r)
r = outil(['fly away'])
verifier('unknown action', r[0] and 'Unknown action: fly' in r[1], r)
r = outil(['corbeille "%s"' % cs.FICHIER_INSTRUCTIONS])
verifier('trash: System-Context refused', r[0] and 'is read-only' in r[1] and os.path.exists(cs.FICHIER_INSTRUCTIONS), r)
r = outil(['attendre 1'] * 41)
verifier('more than 40 actions refused', r[0] and 'Nothing was run' in r[1], r)
verifier('unknown tool', appel('tools/call', {'name': 'other', 'arguments': {}}, 7)['error']['code'] == -32602)
verifier('unknown method', appel('resources/list', ident=9)['error']['code'] == -32601)
r = appel('ping', ident=10)
verifier('ping', r['id'] == 10 and r['result'] == {})
mcp.stdin.close()
try:
    mcp.wait(timeout=5)
    verifier('the server stops when its input closes', True)
except subprocess.TimeoutExpired:
    mcp.kill()
    verifier('the server stops when its input closes', False)
mcp.stdout.close()
mcp.stderr.close()

print('=== %d checks, %d failure(s)' % (tests, echecs))
shutil.rmtree(bac, ignore_errors=True)
sys.exit(echecs)
