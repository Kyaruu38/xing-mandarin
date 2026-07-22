#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Xing Mandarin — Generator Audio "Ucapan Asli" buat Tone Sandhi Guide (Fitur 4)
================================================================================
Generate audio ucapan NATURAL (bukan suku kata lepas) buat ~29 kata contoh di
4 bab tone sandhi. Beda dari generate_pinyin_audio.py: input TTS di sini adalah
HANZI KATA UTUH (bukan pinyin), karena tujuannya ngedengerin gimana kata itu
BENERAN diucapkan natural (termasuk efek sandhi-nya) -- feeding pinyin lepas
ke TTS ga representatif buat ini, feeding hanzi asli (pola sama kayak
audio_pipeline.py) yang paling reliable.

CARA PAKAI
----------
  pip install edge-tts

  python tools/generate_sandhi_audio.py              # generate semua (~29 file)
  python tools/generate_sandhi_audio.py --limit 5     # tes cepat
  python tools/generate_sandhi_audio.py --force        # timpa yang sudah ada

  Hasil: ./out/sandhi/{pinyin_slug}_natural.mp3
  (pinyin_slug dipilih daripada hanzi buat nama file -- ASCII-safe, hindari
  masalah encoding path di storage/CDN. Lihat RELEASE_CHECKLIST.md.)

  Setelah selesai:
    1. DENGERIN 5 sample wajib (lihat RELEASE_CHECKLIST.md).
    2. Kalau oke, jalankan scripts/upload_sandhi.py (belum dijalankan otomatis).
"""
import sys, asyncio, argparse
from pathlib import Path

try:
    import edge_tts
except ImportError as e:
    sys.exit(f"Package kurang: {e}\n  pip install edge-tts")

OUT = Path("out/sandhi")
VOICE = "zh-CN-XiaoxiaoNeural"
CONCURRENCY = 4
MAX_RETRY = 2

# (pinyin_slug, hanzi) -- daftar ini HARUS sinkron dengan SANDHI_CHAPTERS di index.html
# (chapter JS punya hanzi + dictionary-tone syllables buat tombol "Ejaan kamus"; ini cuma
# generate audio "Ucapan asli"-nya). Dikelompokkan per bab buat gampang cross-check.
SANDHI_WORDS = [
    # Bab A -- nada3+nada3 -> nada2+nada3
    ("nihao", "你好"), ("henhao", "很好"), ("laohu", "老虎"),
    ("meihao", "美好"), ("shoubiao", "手表"), ("yusan", "雨伞"),
    # Bab B -- 不 bu4 -> bu2 sebelum nada 4
    ("budui", "不对"), ("bushi", "不是"), ("buqu", "不去"), ("buyao", "不要"),
    ("buting", "不听"), ("bunan", "不难"), ("buhao", "不好"), ("buyong", "不用"),
    # Bab C -- 一 yi1 -> yi2 (sebelum nada4) / yi4 (sebelum nada1/2/3)
    ("yiyang", "一样"), ("yici", "一次"), ("yiding", "一定"), ("yiban", "一半"),
    ("yiqi", "一起"), ("yitian", "一天"), ("yinian", "一年"), ("yizhi", "一直"),
    # Bab D -- half-third tone (nada3 sebelum nada bukan-3 dibaca setengah turun doang)
    ("henmang", "很忙"), ("haode", "好的"), ("xiaoxin", "小心"), ("keshi", "可是"),
    ("women", "我们"), ("dasuan", "打算"), ("xiezi", "写字"), ("xiangdao", "想到"),
]


async def render_one(slug, hanzi, sem):
    dest = OUT / f"{slug}_natural.mp3"
    async with sem:
        for attempt in range(1, MAX_RETRY + 2):
            try:
                await edge_tts.Communicate(hanzi, VOICE).save(str(dest))
                return True, slug
            except Exception as e:
                if attempt > MAX_RETRY:
                    return False, f"{slug} ({hanzi}): {type(e).__name__}: {e}"
                await asyncio.sleep(1.5 * attempt)


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, help="batasi jumlah file (buat tes cepat)")
    ap.add_argument("--force", action="store_true", help="timpa file yang sudah ada")
    a = ap.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    jobs = SANDHI_WORDS
    if not a.force:
        jobs = [(s,h) for (s,h) in jobs if not (OUT / f"{s}_natural.mp3").exists()]
    if a.limit:
        jobs = jobs[:a.limit]

    print(f"{len(SANDHI_WORDS)} kata total | {len(jobs)} file akan digenerate")
    if not jobs:
        print("Tidak ada job (semua sudah ada -- pakai --force buat timpa).")
        return

    sem = asyncio.Semaphore(CONCURRENCY)
    results = await asyncio.gather(*[render_one(s, h, sem) for s, h in jobs])
    ok = sum(1 for r,_ in results if r)
    fail_lines = [info for r, info in results if not r]

    if fail_lines:
        (OUT / "sandhi_failed.txt").write_text('\n'.join(fail_lines) + '\n', encoding='utf-8')
        print(f"{len(fail_lines)} gagal, dicatat di out/sandhi/sandhi_failed.txt")

    print(f"\nSelesai. ok={ok} gagal={len(fail_lines)}")
    print(f"Hasil di: {OUT.resolve()}")
    print("\nLangkah berikutnya (JANGAN otomatis):")
    print("  1. Dengerin 5 sample wajib (lihat RELEASE_CHECKLIST.md)")
    print("  2. Kalau oke, jalankan scripts/upload_sandhi.py")

if __name__ == "__main__":
    asyncio.run(main())
