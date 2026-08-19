#!/usr/bin/env python3
"""Controlla lang/dialogue.lua contro il worksheet, prima che il testo arrivi
a schermo.

Cerca i tre guasti che non si vedono rileggendo la traduzione:

  ERRORE  marcatori diversi dall'originale.  src/core/RomText.lua riempie gli
          slot in ordine e pretende che il conteggio combaci: se non combacia
          NON stampa la riga tradotta, ripiega sull'inglese.  Una riga a cui
          manca un {RAM:...} sparisce quindi in silenzio, e sembra semplicemente
          non tradotta.
  ERRORE  caratteri che il font vanilla non sa disegnare (le vocali accentate
          in primis): a schermo diventano un buco.
  AVVISO  riga oltre le 18 colonne.  L'engine manda a capo da solo, quindi non
          si perde niente, ma va a capo dove capita.

  python3 tools/it_validate.py --worksheet ~/italiano-worksheet/dialogue.tsv
"""
import argparse
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAX_COLS = 18

MARKER = re.compile(r"\{[^{}]*\}")

# Righe che possono legittimamente avere meno slot dell'originale, con il
# perche'.  La regola generale resta giusta -- meno slot di solito vuol dire
# riga che ripiega sull'inglese -- ma qualche etichetta non passa dal
# controllo di arieta' di RomText.lua perche' chi la stampa fa le
# sostituzioni per conto suo.
EXCEPTIONS = {
    "_GymStatueText1":
        "la targa e' stampata da OverworldController, che fa il gsub dei due "
        "slot per conto suo senza passare da RomText: gli slot mancanti non "
        "la fanno ripiegare.  La citta' e' omessa apposta (arriva in inglese "
        "da data/scripts/gyms.lua)",
    "_GymStatueText2": "come _GymStatueText1",
}
ENTRY = re.compile(r'^\s*\["((?:[^"\\]|\\.)*)"\]\s*=\s*"((?:[^"\\]|\\.)*)"\s*,')

UNESCAPE = {"n": "\n", "r": "\r", "t": "\t", "v": "\v", "f": "\f",
            "\\": "\\", '"': '"'}


def unescape(text):
    out, i = [], 0
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text):
            nxt = text[i + 1]
            if nxt.isdigit():
                num = ""
                i += 1
                while i < len(text) and text[i].isdigit() and len(num) < 3:
                    num += text[i]; i += 1
                out.append(chr(int(num))); continue
            out.append(UNESCAPE.get(nxt, nxt)); i += 2; continue
        out.append(c); i += 1
    return "".join(out)


def vanilla_glyphs():
    """Cosa il font a tile sa disegnare, letto dal manifest invece che
    elencato a mano: una lista scritta a mano si stacca dal gioco."""
    manifest = json.load(open(os.path.join(REPO, "tools", "rom_manifest.json"),
                              encoding="utf-8"))
    drawable = set(manifest["charmap"].values())
    drawable |= {e["seq"] for e in manifest["fontCharmap"]}
    return {g for g in drawable if g}


def chars(text):
    """Caratteri, non byte: una vocale accentata e' un carattere solo."""
    return list(text)


def load_worksheet(path):
    source = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("#") or "\t" not in line:
                continue
            label, text = line.rstrip("\n").split("\t", 1)
            source[label] = unescape(text)
    return source


def load_catalog(path):
    out = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            hit = ENTRY.match(line)
            if hit and hit.group(2):
                out[unescape(hit.group(1))] = unescape(hit.group(2))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--worksheet", required=True)
    ap.add_argument("--catalog",
                    default=os.path.join(REPO, "mods", "Italiano", "lang", "dialogue.lua"))
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    source = load_worksheet(args.worksheet)
    catalog = load_catalog(args.catalog)
    glyphs = vanilla_glyphs()

    errors, warnings = [], []
    for label in sorted(catalog):
        italian = catalog[label]
        english = source.get(label)

        if english is None:
            warnings.append(f"{label}: non e' nel worksheet "
                            "(etichetta di un'altra versione del gioco?)")
        else:
            want = sorted(MARKER.findall(english))
            got = sorted(MARKER.findall(italian))
            if want != got:
                if label in EXCEPTIONS:
                    warnings.append(f"{label}: marcatori {got} invece di "
                                    f"{want}, ammesso -- {EXCEPTIONS[label]}")
                else:
                    errors.append(f"{label}: marcatori {got} invece di {want} "
                                  "-- la riga ripieghera' sull'inglese")

        # I marcatori non vengono disegnati: sono sostituiti prima, quindi le
        # graffe e i due punti che contengono non passano dal font.
        for c in chars(MARKER.sub("", italian)):
            if c in "\n\r\v\f":
                continue
            if c not in glyphs:
                errors.append(f"{label}: il font vanilla non disegna {c!r}")
                break

        for piece in re.split(r"[\n\v\f]", italian):
            visible = MARKER.sub("", piece)
            if len(visible) > MAX_COLS:
                warnings.append(f"{label}: riga di {len(visible)} colonne "
                                f"(max {MAX_COLS}), andra' a capo da sola")

    for line in errors:
        print("ERRORE  " + line)
    for line in warnings:
        print("avviso  " + line)

    if not args.quiet:
        print(f"\n{len(catalog)} voci tradotte su {len(source)} del worksheet")
        print(f"{len(errors)} errori, {len(warnings)} avvisi")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
