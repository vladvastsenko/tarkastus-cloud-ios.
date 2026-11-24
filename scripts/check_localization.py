from pathlib import Path
import re, json
root = Path("TarkastusCloud")
langs = "en fi et sv nb da lv lt ru".split()
errors = []
tables = {}
pattern = re.compile(r'^\s*("(?:\\.|[^"\\])*")\s*=\s*("(?:\\.|[^"\\])*");\s*$')
for lang in langs:
    table = {}
    for n, line in enumerate((root / f"{lang}.lproj/Localizable.strings").read_text().splitlines(), 1):
        if not line.strip() or line.strip().startswith("//"):
            continue
        m = pattern.fullmatch(line)
        if not m:
            errors.append(f"{lang}:{n}: malformed entry")
            continue
        k, v = map(json.loads, m.groups())
        if k in table or not v.strip():
            errors.append(f"{lang}: duplicate or empty key {k}")
        table[k] = v
    tables[lang] = table
base = tables["en"]
formats = lambda s: sorted(re.findall(r'%(?:\d+\$)?(?:lld|ld|d|@|f|s)', s))
for lang, table in tables.items():
    for k in base.keys() ^ table.keys():
        errors.append(f"{lang}: key mismatch {k}")
    for k in base.keys() & table.keys():
        if formats(base[k]) != formats(table[k]):
            errors.append(f"{lang}: format mismatch {k}")
calls = re.compile(r'\b(?:Text|Button|Section|TextField|SecureField|Picker|Toggle|Label|NavigationLink|navigationTitle|alert|confirmationDialog|AppMessage\.text)\("([^"\\]+)"')
for path in root.rglob("*.swift"):
    for k in calls.findall(path.read_text()):
        if k not in base:
            errors.append(f"{path}: missing UI key {k}")
pdf = (root / "PDF/PDFTranslation.swift").read_text()
pdf_keys = set()
for k, values in re.findall(r'^\s*"([^"]+)": (\[.*\]),?$', pdf, re.M):
    values = json.loads(values)
    if k in pdf_keys or len(values) != 9 or any(not isinstance(v, str) or not v.strip() for v in values):
        errors.append(f"PDF: invalid translation {k}")
    pdf_keys.add(k)
report = (root / "PDF/ReportPDF.swift").read_text()
for k in re.findall(r'\b(?:tr|field)\("([^"]+)"', report):
    if k not in pdf_keys:
        errors.append(f"PDF: missing key {k}")
if errors:
    raise SystemExit("\n".join(errors))
print(f"Localization OK: {len(base)} UI keys x {len(langs)} languages; {len(pdf_keys)} PDF keys")
