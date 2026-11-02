"""Lecture des PDF sans programme externe (pypdfium2), pour que Claude n'ait pas besoin de pdftoppm.

  - extraire(pdf, cache) : texte du PDF, page par page, dans un .txt mis en cache (réutilisé tant que
    le PDF ne change pas). Claude lit ce .txt avec Read, et peut y chercher avec Grep.
  - rendre_page(pdf, n, png) : une page en image, pour voir un schéma ou un PDF scanné.
"""
from __future__ import annotations

import hashlib
import os
import re
import tempfile

# Moins de 40 caractères par page en moyenne : PDF scanné (images sans texte).
SEUIL_SCANNE = 40


def disponible():
    try:
        import pypdfium2  # noqa: F401
        return True
    except ImportError:
        return False


def _cle(pdf):
    st = os.stat(pdf)
    brut = '%s|%d|%d' % (os.path.abspath(pdf), st.st_size, int(st.st_mtime))
    return hashlib.sha1(brut.encode('utf-8', 'replace')).hexdigest()[:16]


def extraire(pdf, cache):
    """Renvoie (chemin du .txt, nombre de pages, scanné?) ; le .txt est créé s'il n'est pas à jour."""
    import pypdfium2 as pdfium
    os.makedirs(cache, exist_ok=True)
    base = re.sub(r'[^\w.-]+', '_', os.path.splitext(os.path.basename(pdf))[0])[:40]  # sans espaces
    nom = '%s-%s' % (base, _cle(pdf))
    txt = os.path.join(cache, nom + '.txt')
    if os.path.exists(txt):
        with open(txt, encoding='utf-8', errors='replace') as f:
            entete = f.readline()
        try:
            pages, scanne = entete.rsplit('|', 2)[1:]
            return txt, int(pages), scanne.strip() == 'scanne'
        except ValueError:
            pass  # cache d'un autre format : on le refait

    doc = pdfium.PdfDocument(pdf)
    try:
        morceaux, total = [], 0
        for i in range(len(doc)):
            page = doc[i]
            try:
                texte = page.get_textpage().get_text_bounded()
            finally:
                page.close()
            texte = texte.replace('\r\n', '\n').replace('\r', '\n').strip()
            total += len(texte)
            morceaux.append('\n===== Page %d =====\n%s\n' % (i + 1, texte))
        pages = len(doc)
    finally:
        doc.close()
    scanne = pages > 0 and total / pages < SEUIL_SCANNE
    # 1re ligne : métadonnées lues ci-dessus (source|pages|texte/scanne).
    entete = 'ClaudeEcran : texte extrait de %s|%d|%s\n' % (pdf, pages, 'scanne' if scanne else 'texte')
    fd, tmp = tempfile.mkstemp(dir=cache, suffix='.tmp')
    with os.fdopen(fd, 'w', encoding='utf-8') as f:
        f.write(entete + ''.join(morceaux))
    os.replace(tmp, txt)  # écriture atomique (deux tâches en même temps ne se gênent pas)
    return txt, pages, scanne


def nettoyer(cache, gardes):
    """Efface du cache les extraits de PDF supprimés ou modifiés (gardes = chemins encore utiles)."""
    try:
        noms = os.listdir(cache)
    except OSError:
        return
    gardes = {os.path.basename(g) for g in gardes}
    for nom in noms:
        if nom not in gardes:
            try:
                os.unlink(os.path.join(cache, nom))
            except OSError:
                pass


def rendre_page(pdf, numero, png, cote_max=1600):
    """Enregistre la page `numero` (à partir de 1) en PNG ; renvoie le nombre de pages du PDF."""
    import pypdfium2 as pdfium
    doc = pdfium.PdfDocument(pdf)
    try:
        pages = len(doc)
        if not 1 <= numero <= pages:
            raise ValueError('Page %d inexistante : ce PDF a %d page(s).' % (numero, pages))
        page = doc[numero - 1]
        try:
            largeur, hauteur = page.get_size()  # en points (1/72 de pouce)
            echelle = min(150 / 72.0, cote_max / float(max(largeur, hauteur, 1)))  # 150 dpi, ≤ cote_max px
            image = page.render(scale=echelle).to_pil()
        finally:
            page.close()
        image.convert('RGB').save(png, 'PNG')
        return pages
    finally:
        doc.close()
