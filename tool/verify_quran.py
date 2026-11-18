"""Validate bundled data against the pinned upstream reference metadata."""
import hashlib
import json
import sqlite3
import xml.etree.ElementTree as ET

from import_quran import ROOT, SOURCES, OUTPUT

manifest = json.loads((SOURCES / "manifest.json").read_text())
for name, expected in manifest["sha256"].items():
    assert hashlib.sha256((SOURCES / name).read_bytes()).hexdigest() == expected, name
assert hashlib.sha256((OUTPUT / "quran.db").read_bytes()).hexdigest() == (
    OUTPUT / "quran.db.sha256").read_text().strip()
db = sqlite3.connect(f"file:{OUTPUT / 'quran.db'}?mode=ro", uri=True)
metadata = ET.parse(SOURCES / "quran-data.xml").getroot()
assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
assert db.execute("SELECT count(*) FROM surahs").fetchone()[0] == 114
assert db.execute("SELECT count(*) FROM ayahs").fetchone()[0] == 6236
for surah in metadata.find("suras"):
    index, count = int(surah.attrib["index"]), int(surah.attrib["ayas"])
    assert db.execute("SELECT count(*) FROM ayahs WHERE surah=?", (index,)).fetchone()[0] == count
for group, column, count in (("pages", "page", 604), ("juzs", "juz", 30)):
    assert [r[0] for r in db.execute(f"SELECT DISTINCT {column} FROM ayahs ORDER BY {column}")] == list(range(1, count + 1))
    for entry in metadata.find(group):
        first = db.execute(f"SELECT surah, number FROM ayahs WHERE {column}=? ORDER BY id LIMIT 1",
                           (int(entry.attrib["index"]),)).fetchone()
        assert first == (int(entry.attrib["sura"]), int(entry.attrib["aya"]))
original = [line for line in (SOURCES / "quran-uthmani.txt").read_bytes().splitlines()
            if line and line[:1].isdigit()]
stored = [f"{s}|{n}|{t}".encode() for s, n, t in db.execute(
    "SELECT surah, number, text FROM ayahs ORDER BY id")]
assert original == stored, "Quran text bytes changed"
assert db.execute("SELECT count(*) FROM ayahs WHERE basmalah_prefix != ''").fetchone()[0] == 112
try:
    db.execute("DELETE FROM ayahs")
    raise AssertionError("Quran database allowed a write")
except sqlite3.OperationalError:
    pass
db.close()
print("PASS: checksums, exact text bytes, 114 surahs, 6236 ayahs, 604 pages, 30 juz, and read-only access.")
