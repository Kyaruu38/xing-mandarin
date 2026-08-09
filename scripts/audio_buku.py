#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Xing Mandarin -- Audio untuk buku Business Mandarin Foundation
==============================================================
Membaca berkas bab di buku/ch*.json, lalu membuat mp3 untuk:

  bab{N}/dialog{1..4}.mp3   -- percakapan, suara bergantian per pembicara
  bab{N}/bacaan.mp3         -- Reading Passage, satu narator
  bab{N}/latihan-a.mp3      -- satu trek utuh untuk Part A Listening:
                               dialog 1 + 2 pernyataan benar/salah,
                               dialog 2 + 2 pertanyaan pilihan ganda,
                               bacaan + 1 pertanyaan terbuka

KENAPA SCRIPT SENDIRI, BUKAN audio_pipeline.py
audio_pipeline.py menarik soal dari Supabase (question_bank). Buku ini belum masuk
DB dan bentuk datanya beda -- percakapan berlapis, bukan payload soal. Yang TIDAK
ditulis ulang di sini adalah cara merendernya: fungsi render() beserta VOICE, RATE,
GAP_MS, dan GAP_BEFORE_Q_MS diimpor langsung dari audio_pipeline.py, supaya klip
buku terdengar identik dengan klip HSK yang sudah ada. Kalau konstanta di sana
diubah suatu hari, berkas ini ikut berubah sendiri.

KECEPATAN BICARA MENGIKUTI BAB
audio_pipeline.RATE dan GAP_MS berindeks level HSK 1-6. Buku ini berjalan dari nol
sampai setara HSK 4, jadi tiap bab dipetakan ke level yang setara (lihat LEVEL_BAB).
Bab awal dibacakan lebih pelan dengan jeda lebih panjang, persis seperti soal HSK 1.

CARA PAKAI
----------
  pip install edge-tts pydub
  # ffmpeg wajib (dipakai pydub buat menggabung audio + memberi jeda):
  #   Windows: winget install ffmpeg    |   Mac: brew install ffmpeg

  python scripts/audio_buku.py --bab 1             # satu bab dulu, dengarkan hasilnya
  python scripts/audio_buku.py --bab 1 --limit 2   # dua berkas saja, tes cepat
  python scripts/audio_buku.py --all               # semua 11 bab (55 berkas)

  Hasil: ./audio_out/buku/bab1/dialog1.mp3 ...

RESUMABLE: berkas yang sudah ada dilewati. Pakai --force kalau mau ditimpa.

Script ini TIDAK mengunggah apa pun dan TIDAK menyentuh database. Hasilnya berkas
lokal; unggahnya belakangan, setelah kualitas suaranya kamu dengar sendiri.
"""
import sys, json, asyncio, argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

try:
    from audio_pipeline import render, VOICE
except ImportError as e:
    sys.exit(f"Gagal impor audio_pipeline.py: {e}\n"
             f"Jalankan dari dalam repo, dan pastikan 'pip install edge-tts pydub requests' sudah.")

OUT = ROOT / "audio_out" / "buku"

# Bab -> level HSK setara, dipakai buat menentukan kecepatan bicara & panjang jeda.
LEVEL_BAB = {0: 1, 1: 1, 2: 2, 3: 2, 4: 3, 5: 3, 6: 3, 7: 4, 8: 4, 9: 4, 10: 4}

# Adegan bertiga (mis. Bab 1 dialog 4) memakai penanda C. Tanpa ini C jatuh ke
# suara bawaan dan terdengar seperti satu orang menjawab dirinya sendiri.
VOICE.setdefault("C", "zh-CN-XiaoyiNeural")


def load(n: int) -> dict:
    p = ROOT / "buku" / f"ch{n}.json"
    if not p.exists():
        sys.exit(f"Tidak ketemu: {p}")
    return json.loads(p.read_text(encoding="utf-8"))


def baris_bacaan(reading: dict):
    return [("N", t.strip()) for t in reading["zh"].split("\n") if t.strip()]


def baris_dialog(dl: dict):
    return [(ln[0], ln[1]) for ln in dl["lines"]]


async def tulis(transcript, level, dest: Path, force: bool) -> bool:
    if dest.exists() and not force:
        print(f"    lewati  {dest.relative_to(ROOT)}")
        return False
    ok = await render(transcript, level, dest)
    print(("  +  " if ok else "  !! gagal ") + str(dest.relative_to(ROOT)))
    return ok


async def do_bab(n: int, force: bool, limit) -> int:
    d = load(n)
    lv = LEVEL_BAB[n]
    base = OUT / f"bab{n}"
    made = 0

    for i, dl in enumerate(d["dialogues"], 1):
        if await tulis(baris_dialog(dl), lv, base / f"dialog{i}.mp3", force):
            made += 1
        if limit and made >= limit:
            return made

    if await tulis(baris_bacaan(d["reading"]), lv, base / "bacaan.mp3", force):
        made += 1
    if limit and made >= limit:
        return made

    x = d["exercises"]
    part_a = []
    part_a += baris_dialog(d["dialogues"][0])
    part_a += [("Q", q[0]) for q in x["listening_tf"]]
    part_a += baris_dialog(d["dialogues"][1])
    part_a += [("Q", q["q"]) for q in x["listening_mc"]]
    part_a += baris_bacaan(d["reading"])
    part_a += [("Q", q[0]) for q in x["listening_open"]]
    if await tulis(part_a, lv, base / "latihan-a.mp3", force):
        made += 1

    return made


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bab", type=int, help="nomor bab (0-10)")
    ap.add_argument("--all", action="store_true", help="semua bab")
    ap.add_argument("--limit", type=int, help="berhenti setelah N berkas (buat tes)")
    ap.add_argument("--force", action="store_true", help="timpa berkas yang sudah ada")
    a = ap.parse_args()

    if a.bab is None and not a.all:
        ap.error("pilih --bab N atau --all")
    if a.bab is not None and a.bab not in LEVEL_BAB:
        ap.error("bab harus 0 sampai 10")

    babs = sorted(LEVEL_BAB) if a.all else [a.bab]
    total = 0
    for n in babs:
        print(f"Bab {n}  (kecepatan setara HSK {LEVEL_BAB[n]})")
        total += await do_bab(n, a.force, a.limit)
    print(f"\nSelesai. {total} berkas baru di {OUT}")


if __name__ == "__main__":
    asyncio.run(main())
