#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Xing Mandarin — Generator Audio Suku Kata Pinyin (Fitur 3: Panduan Pinyin)
===========================================================================
Generate SEMUA suku kata pinyin valid x 4 nada (nada netral di-skip) ke
out/pinyin/. RESUMABLE -- file yang udah ada di-skip (kecuali --force).

Tabel suku kata (VALID_SYLLABLES) di-generate dari aturan fonotaktik standar
Mandarin (inisial + final), bukan data spesifik produk -- referensi linguistik
umum, sama kelasnya kayak seed radicals di Fitur 2. TETAP disarankan random-
check beberapa entri sebelum upload massal -- kombinasi jarang (mis. "dei",
"nen") ada risiko kecil salah/hilang. Lihat RELEASE_CHECKLIST.md.

Input TTS = suku kata BERTONE-MARK ("mā", "xiǎng", "lǜ") sesuai instruksi --
BUKAN substitusi hanzi. Kalau pas didengerin kualitasnya kurang natural
(voice Azure zh-CN kadang kurang lancar baca romanisasi lepas tanpa konteks
kalimat), alternatif yang sudah terbukti dipakai proyek sejenis: ganti input
per-suku-kata jadi hanzi asli yang bacaannya persis sama (mis. ma1 -> 妈,
ma2 -> 麻, ma3 -> 马, ma4 -> 骂) -- BELUM diimplementasi di sini, cuma dicatat
sebagai fallback siap pakai kalau approval sample menemukan masalah kualitas.

CARA PAKAI
----------
  pip install edge-tts

  python tools/generate_pinyin_audio.py                 # generate semua (~1300 file)
  python tools/generate_pinyin_audio.py --limit 20       # tes cepat, 20 file
  python tools/generate_pinyin_audio.py --only ma,zhi,chi,shi,ri   # suku kata tertentu (semua nada)
  python tools/generate_pinyin_audio.py --force          # timpa yang udah ada

  Hasil: ./out/pinyin/{pinyin_polos}{nada}.mp3   (contoh: ma1.mp3, xiang3.mp3, lv4.mp3)
  Gagal dicatat di: ./out/pinyin_failed.txt

  Setelah selesai:
    1. DENGERIN 8 sample wajib sebelum upload (lihat RELEASE_CHECKLIST.md):
       ma1 ma2 ma3 ma4 zhi1 chi1 shi1 ri4
    2. Kalau oke, jalankan scripts/upload_pinyin.py (belum dijalankan otomatis).
"""
import os, sys, asyncio, argparse
from pathlib import Path

try:
    import edge_tts
except ImportError as e:
    sys.exit(f"Package kurang: {e}\n  pip install edge-tts")

OUT = Path("out/pinyin")
FAILED_LOG = Path("out/pinyin_failed.txt")
VOICE = "zh-CN-XiaoxiaoNeural"   # sama seperti audio_pipeline.py -- suara wanita, jelas buat pemula
CONCURRENCY = 4                  # kecil sengaja, biar aman dari rate limit edge-tts
BATCH_GAP_SEC = 1.5              # jeda antar batch
MAX_RETRY = 2

# ── Tabel suku kata valid per inisial (fonotaktik standar Mandarin) ─────────
# 'v' dipakai gantiin ü (nü, lü, nüe, lüe, ju, qu, xu, yu, jue, que, xue, yue,
# juan, quan, xuan, yuan, jun, qun, xun, yun) -- dikonversi ke ü cuma pas bikin
# teks TTS, filename tetap pakai 'v' sesuai spec ("lv4.mp3").
INITIAL_FINALS = {
    'b': ['a','o','ai','ei','ao','an','en','ang','eng','i','ie','iao','ian','in','ing','u'],
    'p': ['a','o','ai','ei','ao','ou','an','en','ang','eng','i','ie','iao','ian','in','ing','u'],
    'm': ['a','o','e','ai','ei','ao','ou','an','en','ang','eng','i','ie','iao','iu','ian','in','ing','u'],
    'f': ['a','o','ei','ou','an','en','ang','eng','u'],
    'd': ['a','e','ai','ei','ao','ou','an','en','ang','eng','ong','i','ie','iao','iu','ian','ing','u','ui','uo','uan','un'],
    't': ['a','e','ai','ao','ou','an','ang','eng','ong','i','ie','iao','ian','ing','u','ui','uo','uan','un'],
    'n': ['a','e','ai','ei','ao','ou','an','en','ang','eng','ong','i','ia','ie','iao','iu','ian','in','iang','ing','u','uo','uan','un','v','ve'],
    'l': ['a','e','ai','ei','ao','ou','an','ang','eng','ong','i','ia','ie','iao','iu','ian','in','iang','ing','u','uo','uan','un','v','ve'],
    'g': ['a','e','ai','ei','ao','ou','an','en','ang','eng','ong','u','ua','uo','uai','ui','uan','un','uang'],
    'k': ['a','e','ai','ei','ao','ou','an','en','ang','eng','ong','u','ua','uo','uai','ui','uan','un','uang'],
    'h': ['a','e','ai','ei','ao','ou','an','en','ang','eng','ong','u','ua','uo','uai','ui','uan','un','uang'],
    # j/q/x: TIDAK pakai 'v' -- konvensi ejaan pinyin BAKU membuang umlaut sepenuhnya setelah
    # j/q/x/y (ditulis "ju/que/xuan/yun", bukan "jü/qüe/xüan/yün" ATAUPUN "jv/qve/xvan/yvn")
    # karena j/q/x/y tidak pernah punya bentuk final-u POLOS yang bersaing (beda dari n/l:
    # nu vs nü, lu vs lü -- itu satu-satunya alasan n/l masih butuh 'v'). add_tone_mark() jalan
    # normal untuk 'u'/'ue'/'uan'/'un' di sini karena memang bukan ü secara ejaan.
    'j': ['i','ia','ie','iao','iu','ian','in','iang','ing','iong','u','ue','uan','un'],
    'q': ['i','ia','ie','iao','iu','ian','in','iang','ing','iong','u','ue','uan','un'],
    'x': ['i','ia','ie','iao','iu','ian','in','iang','ing','iong','u','ue','uan','un'],
    'zh': ['a','e','i','ai','ei','ao','ou','an','en','ang','eng','ong','u','ua','uo','uai','ui','uan','un','uang'],
    'ch': ['a','e','i','ai','ao','ou','an','en','ang','eng','ong','u','ua','uo','uai','ui','uan','un','uang'],
    'sh': ['a','e','i','ai','ei','ao','ou','an','en','ang','eng','u','ua','uo','uai','ui','uan','un','uang'],
    'r':  ['e','i','ao','ou','an','en','ang','eng','ong','u','ua','uo','ui','uan','un'],
    'z':  ['a','e','i','ai','ei','ao','ou','an','en','ang','eng','ong','u','uo','ui','uan','un'],
    'c':  ['a','e','i','ai','ao','ou','an','en','ang','eng','ong','u','uo','ui','uan','un'],
    's':  ['a','e','i','ai','ao','ou','an','en','ang','eng','ong','u','uo','ui','uan','un'],
}
# Zero-initial (tanpa konsonan) -- dieja pakai konvensi y/w, disimpan di sini SEBAGAI ejaan
# pinyin lengkap (bukan initial+final concatenation) karena konvensinya tidak beraturan.
ZERO_INITIAL_SYLLABLES = [
    'a','o','e','ai','ei','ao','ou','an','en','ang','eng','er',
    'yi','ya','ye','yao','you','yan','yin','yang','ying','yong',
    'wu','wa','wo','wai','wei','wan','wen','wang','weng',
    'yu','yue','yuan','yun'
]

def build_valid_syllables():
    """Balikin list (pinyin_polos_dengan_v) semua suku kata valid, initial+final digabung."""
    out = []
    for initial, finals in INITIAL_FINALS.items():
        for f in finals:
            out.append(initial + f)
    out += ZERO_INITIAL_SYLLABLES
    return sorted(set(out))

VALID_SYLLABLES = build_valid_syllables()

# ── Penempatan tone mark (aturan standar: a > o > e > (iu: tandai u) > (ui: tandai i) > i/u/ü) ──
TONE_VOWELS = {
    'a': 'aāáǎà', 'o': 'oōóǒò', 'e': 'eēéěè',
    'i': 'iīíǐì', 'u': 'uūúǔù', 'ü': 'üǖǘǚǜ',
}

def add_tone_mark(syl_v, tone):
    """syl_v pakai 'v' buat ü. tone 1-4. Balikin string dengan diacritic + ü asli (bukan v)."""
    s = syl_v.replace('v', 'ü')
    if 'a' in s: idx = s.index('a')
    elif 'o' in s: idx = s.index('o')
    elif 'e' in s: idx = s.index('e')
    elif 'iu' in s: idx = s.index('iu') + 1
    elif 'ui' in s: idx = s.index('ui')
    else:
        idx = None
        for v in 'üiu':
            if v in s:
                idx = s.rindex(v)
                break
        if idx is None:
            return s  # harusnya ga kejadian buat suku kata valid
    base = s[idx]
    key = 'ü' if base == 'ü' else base
    marked = TONE_VOWELS[key][tone]
    return s[:idx] + marked + s[idx+1:]


async def render_one(syl_v, tone, sem):
    fname = f"{syl_v}{tone}.mp3"
    dest = OUT / fname
    text = add_tone_mark(syl_v, tone)
    async with sem:
        for attempt in range(1, MAX_RETRY + 2):
            try:
                await edge_tts.Communicate(text, VOICE).save(str(dest))
                return True, fname
            except Exception as e:
                if attempt > MAX_RETRY:
                    return False, f"{fname} ({text}): {type(e).__name__}: {e}"
                await asyncio.sleep(1.5 * attempt)


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, help="batasi jumlah file (buat tes cepat)")
    ap.add_argument("--only", type=str, help="cuma suku kata ini (semua nada), pisah koma, contoh: ma,zhi,chi")
    ap.add_argument("--force", action="store_true", help="timpa file yang sudah ada")
    a = ap.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)

    syllables = VALID_SYLLABLES
    if a.only:
        wanted = set(a.only.split(','))
        syllables = [s for s in syllables if s in wanted]
        missing = wanted - set(syllables)
        if missing:
            print(f"  ⚠ tidak ada di tabel valid, di-skip: {sorted(missing)}")

    jobs = [(s, tone) for s in syllables for tone in (1,2,3,4)]
    if not a.force:
        jobs = [(s,tn) for (s,tn) in jobs if not (OUT / f"{s}{tn}.mp3").exists()]
    if a.limit:
        jobs = jobs[:a.limit]

    print(f"{len(syllables)} suku kata unik | {len(jobs)} file akan digenerate (nada netral di-skip)")
    if not jobs:
        print("Tidak ada job (semua sudah ada -- pakai --force buat timpa).")
        return

    sem = asyncio.Semaphore(CONCURRENCY)
    ok = fail = 0
    failed_lines = []
    # Batch kecil + jeda, bukan asyncio.gather sekaligus semua -- edge-tts rate-limit kalau
    # terlalu banyak koneksi bersamaan dalam waktu singkat.
    BATCH = CONCURRENCY * 5
    for i in range(0, len(jobs), BATCH):
        chunk = jobs[i:i+BATCH]
        results = await asyncio.gather(*[render_one(s, tn, sem) for s, tn in chunk])
        for success, info in results:
            if success: ok += 1
            else:
                fail += 1
                failed_lines.append(info)
        print(f"  {min(i+BATCH,len(jobs))}/{len(jobs)}  ok={ok} gagal={fail}")
        await asyncio.sleep(BATCH_GAP_SEC)

    if failed_lines:
        FAILED_LOG.write_text('\n'.join(failed_lines) + '\n', encoding='utf-8')
        print(f"\n{len(failed_lines)} gagal, dicatat di {FAILED_LOG}")

    print(f"\nSelesai. ok={ok} gagal={fail}")
    n = sum(1 for _ in OUT.glob('*.mp3'))
    mb = sum(f.stat().st_size for f in OUT.glob('*.mp3')) / 1e6
    print(f"Total {n} file di {OUT.resolve()}, {mb:.1f} MB")
    print("\nLangkah berikutnya (JANGAN otomatis):")
    print("  1. Dengerin 8 sample wajib: ma1 ma2 ma3 ma4 zhi1 chi1 shi1 ri4")
    print("  2. Kalau oke, jalankan scripts/upload_pinyin.py")

if __name__ == "__main__":
    asyncio.run(main())
