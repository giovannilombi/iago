#!/usr/bin/env python3
"""Italian and English kept aligned (ADR-0077).

Italian is the source; every Markdown document and every string of the app has its English version.

  scripts/i18n.py check            what is missing or out of date (pre-commit hook and CI; exit 1 if anything)
  scripts/i18n.py record [FILE…]   after translating: records the Italian sources the English files now follow
                                   (all of them without arguments)
  scripts/i18n.py missing OUT.json strings of the app without English, from an export of the project (needs Xcode)
  scripts/i18n.py apply IN.json    writes those translations ({id: english}) into Localizable.xcstrings

Documents: App/Resources/Guide/NN-x.md → App/Resources/Guide/en/NN-x.md, docs/…/x.md → docs/en/…/x.md,
README.md, README-collaborators.md, CLAUDE.md → *.en.md. i18n/sources.json keeps, for each English file, the
SHA-256 of the Italian text it was translated from: a change to the Italian makes it out of date.
"""

import hashlib
import json
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "i18n" / "sources.json"
CATALOG = ROOT / "App" / "Resources" / "Localizable.xcstrings"
GENERATED = ("docs/en/", "docs/guida/", "docs/.vitepress/", "docs/node_modules/")


def pairs():
    """(italian, english) paths, relative to the repository."""
    result = []
    guide = ROOT / "App" / "Resources" / "Guide"
    for source in sorted(guide.glob("[0-9][0-9]-*.md")):
        result.append((source, guide / "en" / source.name))
    for source in sorted((ROOT / "docs").rglob("*.md")):
        relative = source.relative_to(ROOT).as_posix()
        if relative.startswith(GENERATED):
            continue
        result.append((source, ROOT / "docs" / "en" / source.relative_to(ROOT / "docs")))
    for name in ("README.md", "README-collaborators.md", "CLAUDE.md"):
        result.append((ROOT / name, ROOT / name.replace(".md", ".en.md")))
    return [(s.relative_to(ROOT).as_posix(), e.relative_to(ROOT).as_posix()) for s, e in result]


def digest(path):
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def load_manifest():
    return json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}


def save_manifest(manifest):
    MANIFEST.parent.mkdir(exist_ok=True)
    MANIFEST.write_text(json.dumps(dict(sorted(manifest.items())), indent=1, ensure_ascii=False) + "\n")


# MARK: Strings of the app


def catalog_problems():
    catalog = json.loads(CATALOG.read_text())
    missing = []
    for key, entry in catalog["strings"].items():
        if not key.strip() or entry.get("shouldTranslate") is False or entry.get("extractionState") == "stale":
            continue
        if not re.search(r"[A-Za-zÀ-ú]{2}", key):
            continue
        unit = entry.get("localizations", {}).get("en", {})
        state = unit.get("stringUnit", {}).get("state")
        if state != "translated" and "variations" not in unit:
            missing.append(key)
    return catalog, missing


def normalized(key):
    """A catalog key with its format specifiers as one placeholder, to compare with the keys found in the code."""
    key = key.replace("%%", "\0")
    key = re.sub(r"%(\d+\$)?(lld|ld|d|@|f|\.\d+f|u|llu)", "%", key)
    return key.replace("\0", "%")


def literal_at(text, start):
    """The Swift string literal starting at `start` (just after its opening quote): its text with each
    interpolation \\(…) as one placeholder, and where it ends."""
    out, i = [], start
    while i < len(text):
        c = text[i]
        if c == '"':
            return "".join(out), i + 1
        if c == "\\" and i + 1 < len(text):
            n = text[i + 1]
            if n == "(":
                depth, i = 1, i + 2
                while i < len(text) and depth:
                    if text[i] == '"':
                        _, i = literal_at(text, i + 1)
                        continue
                    depth += {"(": 1, ")": -1}.get(text[i], 0)
                    i += 1
                out.append("%")
                continue
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(n, n))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out), i


def code_keys():
    """Literal keys of String(localized: "…") in the app's sources, interpolations as one placeholder."""
    keys = set()
    pattern = re.compile(r'String\(\s*localized:\s*"(?!"")')
    for source in (ROOT / "App" / "Sources").rglob("*.swift"):
        text = source.read_text()
        for match in pattern.finditer(text):
            key, _ = literal_at(text, match.end())
            if re.search(r"[A-Za-zÀ-ú]{2}", key):
                keys.add(key)
    return keys


def check():
    problems = []
    manifest = load_manifest()
    for italian, english in pairs():
        if not (ROOT / english).exists():
            problems.append(f"manca la traduzione: {english} (da {italian})")
        elif manifest.get(english) != digest(italian):
            problems.append(f"traduzione da aggiornare: {english} ({italian} è cambiato)")
    catalog, missing = catalog_problems()
    for key in missing[:20]:
        problems.append(f"stringa senza inglese nel catalogo: {key!r}")
    if len(missing) > 20:
        problems.append(f"… e altre {len(missing) - 20} stringhe senza inglese")
    known = {normalized(key) for key in catalog["strings"]}
    absent = sorted(key for key in code_keys() if key not in known)
    for key in absent[:20]:
        problems.append(f"stringa del codice non ancora nel catalogo: {key!r}")
    if len(absent) > 20:
        problems.append(f"… e altre {len(absent) - 20} stringhe non ancora nel catalogo")
    if problems:
        print("Traduzioni in inglese mancanti o da aggiornare (ADR-0077):", file=sys.stderr)
        for line in problems:
            print(f"  - {line}", file=sys.stderr)
        print(
            "Traduci e poi: scripts/i18n.py record <file inglesi> per i documenti; scripts/i18n.py missing/apply "
            "per le stringhe dell'app.",
            file=sys.stderr,
        )
        return 1
    print("Italiano e inglese allineati.")
    return 0


def record(files):
    manifest = load_manifest()
    by_english = {english: italian for italian, english in pairs()}
    targets = files or list(by_english)
    for english in targets:
        english = Path(english).resolve().relative_to(ROOT).as_posix() if Path(english).is_absolute() else english
        italian = by_english.get(english)
        if italian is None:
            sys.exit(f"{english} non è la traduzione di nessun file")
        if not (ROOT / english).exists():
            sys.exit(f"{english} non esiste ancora")
        manifest[english] = digest(italian)
    save_manifest(manifest)
    print(f"Registrate {len(targets)} traduzioni.")


# MARK: Export and import through Xcode


def export(directory):
    subprocess.run(
        ["xcodebuild", "-exportLocalizations", "-project", str(ROOT / "IAGO.xcodeproj"), "-localizationPath",
         directory, "-exportLanguage", "en"],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return Path(directory) / "en.xcloc" / "Localized Contents" / "en.xliff"


NS = {"x": "urn:oasis:names:tc:xliff:document:1.2"}


def missing(out):
    with tempfile.TemporaryDirectory() as directory:
        tree = ET.parse(export(directory))
    units = []
    for unit in tree.getroot().iter("{urn:oasis:names:tc:xliff:document:1.2}trans-unit"):
        target = unit.find("x:target", NS)
        if target is None or not (target.text or "").strip():
            note = unit.find("x:note", NS)
            units.append({"id": unit.get("id"), "source": unit.find("x:source", NS).text or "",
                          "note": note.text if note is not None else ""})
    Path(out).write_text(json.dumps(units, ensure_ascii=False, indent=1))
    print(f"{len(units)} stringhe senza inglese in {out}")


def apply(translations_file):
    translations = json.loads(Path(translations_file).read_text())
    with tempfile.TemporaryDirectory() as directory:
        xliff = export(directory)
        ET.register_namespace("", NS["x"])
        tree = ET.parse(xliff)
        count = 0
        for unit in tree.getroot().iter("{urn:oasis:names:tc:xliff:document:1.2}trans-unit"):
            text = translations.get(unit.get("id"))
            if text is None:
                continue
            target = unit.find("x:target", NS)
            if target is None:
                target = ET.SubElement(unit, "{urn:oasis:names:tc:xliff:document:1.2}target")
            target.text = text
            target.set("state", "translated")
            count += 1
        tree.write(xliff, encoding="UTF-8", xml_declaration=True)
        subprocess.run(
            ["xcodebuild", "-importLocalizations", "-project", str(ROOT / "IAGO.xcodeproj"), "-localizationPath",
             str(xliff.parent.parent)],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"Scritte {count} traduzioni nel catalogo.")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "check"
    if command == "check":
        sys.exit(check())
    elif command == "record":
        record(sys.argv[2:])
    elif command == "missing" and len(sys.argv) == 3:
        missing(sys.argv[2])
    elif command == "apply" and len(sys.argv) == 3:
        apply(sys.argv[2])
    else:
        sys.exit(__doc__)
