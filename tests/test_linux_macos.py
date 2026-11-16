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


# Events as Claude Code writes them with --output-format stream-json, one JSON per line.
def ev_texte(texte):
    return {'type': 'assistant', 'message': {'role': 'assistant', 'content': [{'type': 'text', 'text': texte}]}}


def ev_outil(outil, entree):
    return {'type': 'assistant', 'message': {'role': 'assistant', 'content': [{'type': 'tool_use', 'name': outil, 'input': entree}]}}


EV_RETOUR = {'type': 'user', 'message': {'role': 'user', 'content': [{'type': 'tool_result', 'content': 'x' * 2000}]}}


def ecrire_flux(c, evenements, fin=''):
    with open(os.path.join(c['run'], 'responses', 'task.jsonl'), 'w', encoding='utf-8') as f:
        f.write(''.join(json.dumps(e, separators=(',', ':')) + '\n' for e in evenements) + fin)


def repondre(c, texte, nom='task'):
    """The answer of Claude: one word in a text file for the triage, a stream of events for the task."""
    if nom == 'task':
        return ecrire_flux(c, [ev_texte(texte), {'type': 'result', 'subtype': 'success', 'result': texte}] if texte else [])
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

verifier('notes are kept when memory.txt does not exist', memoire.active(os.path.join(bac, 'nothing.txt')) and not os.path.exists(os.path.join(bac, 'nothing.txt')))

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

print('--- texts longer than 4000 characters')
a.proc = None
a.memoire = False
avant_ins = lire(cs.FICHIER_INSTRUCTIONS)
with open(cs.FICHIER_INSTRUCTIONS, 'w', encoding='utf-8') as f:
    f.write('<!-- %s -->\n%s' % ('c' * 5000, 'Always answer briefly. ' * 200))
c7 = capture()
a.lancer_tache(c7, '')
open(os.path.join(c7['run'], 'mcp-started.txt'), 'w').close()
repondre(c7, 'Done.')
a.proc = types.SimpleNamespace(returncode=0)
a.processus_fini()
verifier('long instructions.md: said in the result', a.coupes == ['instructions.md']
         and re.search(r'Done\.\n\n\(Warning: instructions\.md is longer than 4000 characters, so its end was not sent', a.dernier) is not None, a.dernier)
with open(cs.FICHIER_INSTRUCTIONS, 'w', encoding='utf-8') as f:
    f.write(avant_ins)
c8 = capture()
a.lancer_tache(c8, '')
open(os.path.join(c8['run'], 'mcp-started.txt'), 'w').close()
repondre(c8, 'Done.')
a.proc = types.SimpleNamespace(returncode=0)
a.processus_fini()
verifier('shortened again: no warning any more', a.coupes == [] and 'Warning' not in a.dernier, a.dernier)

print('--- the task is worked out from the context')
with open(os.path.join(cs.TRAVAIL, 'exo7_notes.txt'), 'w') as f:
    f.write('work in progress')
cz = capture()
a.proc = None
a.lancer_tache(cz, '')
pz = prompt(cz)
verifier('prompt: never act at random, the order of what to rely on', '1. Find what is being asked before you act: never act at random' in pz
         and 'their standing instructions; the active context; your notes of this session; the documents and the recent files' in pz
         and 'do not guess an action: change nothing' in pz)
verifier('prompt: the recent files of the work folder, not those of System-Context', 'Most recent files of the work folder' in pz
         and os.path.join(cs.TRAVAIL, 'exo7_notes.txt') + '  (' in pz and 'instructions.md' not in pz[pz.index('Most recent files'):pz.index('1. Find what')])
a.proc = None

print('--- steps of a task and History')
a.memoire = True
a.choix_modele = 'sonnet'
shutil.rmtree(cs.RUNS)
os.makedirs(cs.RUNS)
verifier('no task in the history yet', cs.historique() == [])
c4 = capture()
a.lancer_tache(c4, 'cable the routers')
a.proc = types.SimpleNamespace(returncode=0)
a.etape = 'tri'
verifier('during the triage: nothing to show yet', a.texte_resultat() == 'Looking at the screen...')
a.etape = 'tache'
ecrire_flux(c4, [ev_texte('I cable the 8 routers.'), ev_outil('Read', {'file_path': '/x/screenshot-01.png'}), EV_RETOUR,
                 ev_outil('mcp__pc__pc', {'actions': ['clic 352 655', 'clic 500 360']}), EV_RETOUR,
                 ev_texte('Cabling done.\nMEMORY: must stay hidden'),
                 ev_outil('Write', {'file_path': '/home/x/Documents/Claude-Work/exo7_R1.txt', 'content': 'enable'})],
            fin='{"type":"assistant","message":{"content":[{"type":"text","text":"half wri')
t = a.texte_resultat()
verifier('while it works: what Claude said and did, in order',
         re.match(r'Working \(sonnet, \d+ s so far\)', t) is not None and 0 < t.index('I cable the 8 routers.') < t.index('Cabling done.')
         and '\n  > clic 352 655, clic 500 360\n' in t and t.endswith('\n  > file written: exo7_R1.txt'), t)
verifier('while it works: no file reading, no MEMORY line, no half-written line',
         'screenshot-01' not in t and 'MEMORY' not in t and 'half wri' not in t, t)
a.arret = 'raccourci'
a.proc = types.SimpleNamespace(returncode=-15)
a.processus_fini()
verifier('stopped: the steps are in the result', re.match(r'Task stopped \(raccourci\) after \d+ s\.\n\nWhat Claude did before the stop:\n', a.dernier) is not None
         and 'Cabling done.' in a.dernier and '  > clic 352 655' in a.dernier, a.dernier)
verifier('stopped: kept in the task folder', lire(os.path.join(c4['run'], 'result.txt')) == a.dernier)
reste = lire(os.path.join(c4['run'], 'responses', 'task.jsonl'))
verifier('the stream is kept without the tool results (screenshots)', 'tool_result' not in reste and 'Cabling done' in reste)
verifier('after the task: the icon shows the result again', a.texte_resultat() == a.dernier)
c5 = capture()
a.lancer_tache(c5, '')
a.proc = types.SimpleNamespace(returncode=0)
open(os.path.join(c5['run'], 'mcp-started.txt'), 'w').close()
ecrire_flux(c5, [ev_texte('I fill in the form.'), ev_outil('mcp__pc__pc', {'actions': ['clic 10 20', 'remplacer Paris']}), EV_RETOUR,
                 ev_texte('The form is filled in.\nMEMORY: form done'),
                 {'type': 'result', 'subtype': 'success', 'result': 'The form is filled in.\nMEMORY: form done'}])
a.processus_fini()
verifier('finished: the result is the final answer only', re.fullmatch(r'\[sonnet, \d+ s\] The form is filled in\.', a.dernier) is not None, a.dernier)
t = lire(os.path.join(c5['run'], 'result.txt'))
verifier('finished: result.txt = the answer, then the steps, the answer not repeated',
         t == a.dernier + '\n\n----- What Claude did -----\nI fill in the form.\n  > clic 10 20, remplacer Paris', t)
verifier('the note still went to memory.md', 'form done' in memoire.notes(cs.FICHIER_NOTES))
h = cs.historique()
verifier('history: the result files of the 2 tasks, oldest first', h == [os.path.join(c4['run'], 'result.txt'), os.path.join(c5['run'], 'result.txt')], h)
verifier('History window: the newest result is the last one, no separate last message', a.fichiers_resultat() == h)
verifier('a task keeps the id of its session, and its instruction', lire(os.path.join(c4['run'], 'session.txt')) == cs.lire_session()
         and lire(os.path.join(c4['run'], 'instruction.txt')) == 'cable the routers' and not os.path.exists(os.path.join(c5['run'], 'instruction.txt')))
a.echec('Could not start the task: test')
f = a.fichiers_resultat()
verifier('a task that could not start: the kept results, then its message', f == h + [cs.DERNIER] and lire(cs.DERNIER) == 'Could not start the task: test')
a.proc = types.SimpleNamespace(returncode=0)
a.etape = 'tri'
verifier('a task in progress: shown last', a.fichiers_resultat() == h + [cs.DERNIER] and lire(cs.DERNIER) == 'Looking at the screen...')
verifier('during a task: no new session, no ghost mode', not a.nouvelle_session() and not a.basculer_fantome(True) and not a.fantome)
a.proc = None
for i in range(20):
    d = os.path.join(cs.RUNS, '20261113-16%02d00' % i)
    os.makedirs(d)
    if i != 7:
        with open(os.path.join(d, 'result.txt'), 'w', encoding='utf-8') as f:
            f.write('Result number %d' % i)
h = cs.historique()
verifier('history: every kept result, the task without a result skipped', len(h) == 21 and h[18].endswith(os.path.join('20261113-161900', 'result.txt'))
         and os.path.dirname(os.path.dirname(h[18])) == cs.RUNS, h[:3])
sys.path.insert(0, os.path.join(app, 'outils'))
import fenetres  # noqa: E402
verifier('window title: the date of the task, and its session when it has one', fenetres._titre(h[18]) == '13/11/2026 16:19'
         and fenetres._titre(cs.DERNIER) == 'now' and re.fullmatch(r'.+   \(session of \d\d/\d\d/\d{4} \d\d:\d\d\)', fenetres._titre(os.path.join(c4['run'], 'result.txt'))) is None)
with open(os.path.join(cs.RUNS, '20261113-161900', 'session.txt'), 'w') as f:
    f.write('20261113-160000')
with open(os.path.join(cs.RUNS, '20261113-161900', 'instruction.txt'), 'w') as f:
    f.write('only question 4')
verifier('window: session in the title, instruction before the result', fenetres._titre(h[18]) == '13/11/2026 16:19   (session of 13/11/2026 16:00)'
         and fenetres._texte(h[18]) == 'Instruction: only question 4\n\nResult number 19' and fenetres._texte(h[17]) == 'Result number 18')

print('--- New session and ghost mode')
with open(cs.FICHIER_NOTES, 'w', encoding='utf-8') as f:
    f.write(memoire.ENTETE + '- a note of the session\n')
avant = cs.lire_session()
verifier('New session: notes emptied, those of the session that ended put away with it, a new session id',
         a.nouvelle_session() and memoire.notes(cs.FICHIER_NOTES) == ''
         and 'a note of the session' in memoire.notes(os.path.join(cs.DOSSIER_SESSIONS, avant + '.md')) and cs.lire_session() != avant
         and re.match(r'^\d{8}-\d{6}', cs.lire_session()) is not None)
with open(cs.FICHIER_NOTES, 'w', encoding='utf-8') as f:
    f.write(memoire.ENTETE + '- a note of the new session\n')
verifier('notes are always kept: an old memory.txt (on or off) does not turn them off, only "never" does',
         memoire.active(cs.FICHIER_MEMOIRE) and memoire.active(os.path.join(bac, 'nothing.txt')))
with open(os.path.join(bac, 'never.txt'), 'w') as f:
    f.write('never')
verifier('memory.txt = never: no notes at all', not memoire.active(os.path.join(bac, 'never.txt')))
verifier('ghost mode: off by default, turned on', not a.fantome and a.basculer_fantome(True) and a.fantome and lire(cs.FICHIER_FANTOME) == 'on')
nb = len(os.listdir(cs.RUNS))
g = capture()
a.lancer_tache(g, 'a secret instruction')
pg = prompt(g)
verifier('ghost: the notes of the session are not sent, none is asked for', 'MEMORY' not in pg and 'a note of the new session' not in pg and 'a secret instruction' in pg)
verifier('ghost: no session id, no instruction file', not os.path.exists(os.path.join(g['run'], 'session.txt')) and not os.path.exists(os.path.join(g['run'], 'instruction.txt')))
open(os.path.join(g['run'], 'mcp-started.txt'), 'w').close()
repondre(g, 'Secret answer.\nMEMORY: must not be saved')
a.proc = types.SimpleNamespace(returncode=0)
a.processus_fini()
verifier('ghost: the answer is shown, the task folder is gone, no note saved', 'Secret answer.' in a.dernier and not os.path.exists(g['run'])
         and len(os.listdir(cs.RUNS)) == nb and memoire.notes(cs.FICHIER_NOTES) == '- a note of the new session', a.dernier)
verifier('ghost: the answer is the last entry of the window', a.fichiers_resultat()[-1] == cs.DERNIER and 'Secret answer.' in lire(cs.DERNIER))
ident = cs.lire_session()
verifier('New session in Ghost Mode: still ghost, the answer forgotten, the persisted session untouched', a.nouvelle_session() and a.fantome
         and a.dernier.startswith('Ghost session') and not os.path.exists(cs.DERNIER) and cs.lire_session() == ident)
verifier('ghost off: the ghost answer is forgotten', a.basculer_fantome(False) and a.dernier.startswith('No task yet') and not os.path.exists(cs.DERNIER)
         and a.fichiers_resultat() == cs.historique() and lire(cs.FICHIER_FANTOME) == 'off')
k = capture()
a.lancer_tache(k, '')
verifier('after ghost mode: the notes of the session are sent again', 'a note of the new session' in prompt(k))
a.proc = None

long = os.path.join(bac, 'long.jsonl')
with open(long, 'w', encoding='utf-8') as f:
    f.write(''.join(json.dumps(ev_texte('step %d %s' % (i, 'y' * 600))) + '\n' for i in range(1, 101)))
etapes, fin, omises = cs.deroule.lire(long)
verifier('only the last 80 steps, 400 characters each', len(etapes) == 80 and omises == 20 and etapes[0].startswith('step 21 ')
         and len(etapes[0]) == 400 and fin is None and cs.deroule.texte(etapes, omises).startswith('(... 20 earlier steps not shown)'))
verifier('no stream: no step, no result', cs.deroule.lire(os.path.join(bac, 'none.jsonl')) == ([], None, 0))

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
