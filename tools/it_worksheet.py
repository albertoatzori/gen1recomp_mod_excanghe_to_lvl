#!/usr/bin/env python3
"""Estrae il copione di una disassemblata pret in un worksheet TSV.

Legge i file `text/*.asm` di un albero pokered/pokeyellow e ne ricava, per
ogni etichetta, il testo nella forma che l'engine usa a runtime: `\\n` per
l'a-capo dentro la finestra, `\\v` per lo scorrimento, `\\f` per la pagina
nuova, `{RAM:nome}` per i buffer e `{PLAYER}` / `{RIVAL}` per i due nomi.
Sono le stesse convenzioni che src/core/RomText.lua si aspetta, quindi una
riga tradotta nel worksheet si incolla in lang/dialogue.lua senza altri
passaggi.

Il worksheet NON va dentro la cartella della mod: `modkit pack` zippa tutto
quello che ci sta sotto, e questo file contiene il copione della ROM.  Lo
strumento si rifiuta di scriverci dentro.

  python3 tools/it_worksheet.py --src ~/pokeyellow --out ~/italiano-worksheet
"""
import argparse
import os
import re
import sys

# I macro che portano testo, e cosa antepongono al pezzo che seguono.
# `text` apre la finestra, `line` va a capo, `cont` scorre, `para`/`page`
# aprono una pagina nuova, `next` e' un a-capo secco.
LEAD = {
    "text": "", "text_start": "",
    "line": "\n", "next": "\n",
    "cont": "\v",
    "para": "\f", "page": "\f",
}
TERMINATORS = {"done", "prompt", "text_end", "text_promptbutton", "text_waitbutton"}

LABEL = re.compile(r"^(\w+)::")
DIRECTIVE = re.compile(r'^\s+([a-z_]+)\b\s*(.*)$')
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')


# I due nomi che l'engine risolve da solo.  In asm sono <PLAYER> / <RIVAL>,
# a runtime TextBox.substitute cerca la forma in graffe (src/core/RomText.lua),
# quindi la conversione va fatta qui: una riga tradotta col token in forma asm
# arriverebbe a schermo con il segnaposto stampato in chiaro.
NAME_TOKENS = {"<PLAYER>": "{PLAYER}", "<RIVAL>": "{RIVAL}"}


def decode_piece(raw):
    """Il testo dentro le virgolette. `@` e' il terminatore della stringa in
    formato pokered: chiude il pezzo, non e' un carattere da stampare."""
    out = STRING.search(raw)
    if not out:
        return ""
    text = out.group(1).replace("@", "")
    for asm, engine in NAME_TOKENS.items():
        text = text.replace(asm, engine)
    return text


def parse_file(path):
    """[(etichetta, testo), ...] nell'ordine del file."""
    blocks, label, parts = [], None, []

    def flush():
        if label is not None:
            text = "".join(parts)
            # un blocco di solo terminatore non ha niente da tradurre
            if text.strip():
                blocks.append((label, text))

    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            hit = LABEL.match(line)
            if hit:
                flush()
                label, parts = hit.group(1), []
                continue
            if label is None:
                continue
            hit = DIRECTIVE.match(line.rstrip("\n"))
            if not hit:
                continue
            name, rest = hit.group(1), hit.group(2)
            if name in LEAD:
                parts.append(LEAD[name] + decode_piece(rest))
            elif name == "text_ram":
                buf = rest.split(";")[0].strip()
                if buf:
                    parts.append("{RAM:%s}" % buf)
            elif name in ("text_decimal", "text_bcd"):
                # un numero stampato da RAM: uno slot, come i buffer
                buf = rest.split(",")[0].strip()
                parts.append("{RAM:%s}" % buf if buf else "{RAM}")
            elif name in TERMINATORS:
                continue
    flush()
    return blocks


def escape(text):
    """Una riga TSV per blocco: niente a-capo veri, o il file si spezza."""
    return (text.replace("\\", "\\\\").replace("\t", "\\t")
                .replace("\n", "\\n").replace("\r", "\\r")
                .replace("\v", "\\v").replace("\f", "\\f"))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", required=True,
                    help="radice della disassemblata (quella che contiene text/)")
    ap.add_argument("--out", required=True,
                    help="cartella del worksheet, FUORI da mods/")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    src = os.path.abspath(args.src)
    if not os.path.isdir(src):
        sys.exit(f"it_worksheet: {args.src} non e' una cartella")

    out = os.path.abspath(args.out)
    # il copione non deve poter finire in un pacchetto
    parts = out.replace("\\", "/").split("/")
    if "mods" in parts:
        sys.exit("it_worksheet: --out non puo' stare sotto mods/ -- modkit pack "
                 "zippa tutto quello che ci trova, e questo e' testo della ROM")

    # Il copione non sta tutto sotto text/: in pokeyellow il grosso e' in
    # data/text/text_*.asm, e altri blocchi vivono accanto al codice che li
    # stampa (engine/, scripts/).  Si scandisce quindi l'albero intero, e le
    # etichette duplicate le risolve il primo che le definisce.
    blocks, seen = [], set()
    for root, dirs, names in os.walk(src):
        dirs[:] = [d for d in dirs if d not in (".git", "garbage")]
        for name in sorted(names):
            if not name.endswith(".asm"):
                continue
            for label, text in parse_file(os.path.join(root, name)):
                if label in seen:
                    continue
                seen.add(label)
                blocks.append((label, text))
    blocks.sort()

    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "dialogue.tsv")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("# etichetta\\ttesto originale.  Riferimento: NON copiarlo\n")
        handle.write("# dentro la mod, e non versionarlo.\n")
        for label, text in blocks:
            handle.write(f"{label}\t{escape(text)}\n")

    if not args.quiet:
        slots = sum(len(re.findall(r"\{[^}]*\}", t)) for _, t in blocks)
        print(f"{len(blocks)} blocchi -> {path}")
        print(f"{slots} marcatori ({{PLAYER}}, {{RIVAL}}, {{RAM:...}}) da riportare")


if __name__ == "__main__":
    main()
