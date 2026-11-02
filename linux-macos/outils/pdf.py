"""PDF reading without an external program (pypdfium2), so Claude does not need pdftoppm.

  - extraire(pdf, cache): text of the PDF, page by page, in a cached .txt (reused as long as
    the PDF does not change). Claude reads this .txt with Read, and can search it with Grep.
  - rendre_page(pdf, n, png): one page as an image, to see a diagram or a scanned PDF.
"""
from __future__ import annotations

import hashlib
import os
import re
import tempfile

# Under 40 characters per page on average: scanned PDF (images without text).
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
    """Returns (path of the .txt, page count, scanned?); the .txt is created if it is not up to date."""
    import pypdfium2 as pdfium
    os.makedirs(cache, exist_ok=True)
    base = re.sub(r'[^\w.-]+', '_', os.path.splitext(os.path.basename(pdf))[0])[:40]  # no spaces
    nom = '%s-%s' % (base, _cle(pdf))
    txt = os.path.join(cache, nom + '.txt')
    if os.path.exists(txt):
        with open(txt, encoding='utf-8', errors='replace') as f:
            entete = f.readline()
        try:
            pages, scanne = entete.rsplit('|', 2)[1:]
            return txt, int(pages), scanne.strip() == 'scanne'
        except ValueError:
            pass  # cache in another format: rebuild it

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
    # 1st line: metadata read above (source|pages|texte/scanne).
    entete = 'ClaudeScreen: text extracted from %s|%d|%s\n' % (pdf, pages, 'scanne' if scanne else 'texte')
    fd, tmp = tempfile.mkstemp(dir=cache, suffix='.tmp')
    with os.fdopen(fd, 'w', encoding='utf-8') as f:
        f.write(entete + ''.join(morceaux))
    os.replace(tmp, txt)  # atomic write (two tasks at the same time do not interfere)
    return txt, pages, scanne


def nettoyer(cache, gardes):
    """Clears cached extracts of deleted or changed PDFs (gardes = paths still in use)."""
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
    """Saves page `numero` (starting at 1) as PNG; returns the PDF's page count."""
    import pypdfium2 as pdfium
    doc = pdfium.PdfDocument(pdf)
    try:
        pages = len(doc)
        if not 1 <= numero <= pages:
            raise ValueError('Page %d does not exist: this PDF has %d page(s).' % (numero, pages))
        page = doc[numero - 1]
        try:
            largeur, hauteur = page.get_size()  # in points (1/72 inch)
            echelle = min(150 / 72.0, cote_max / float(max(largeur, hauteur, 1)))  # 150 dpi, ≤ cote_max px
            image = page.render(scale=echelle).to_pil()
        finally:
            page.close()
        image.convert('RGB').save(png, 'PNG')
        return pages
    finally:
        doc.close()
