#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Xing Mandarin — Pipeline Audio Listening
=========================================
Baca soal listening langsung dari Supabase (sumber kebenaran), generate mp3 per
audio_url, simpan mirroring path. RESUMABLE — file yang udah ada di-skip.

Kenapa baca dari DB, bukan file JSON terpisah:
  audio_url di payload itu yang dipakai app buat manggil file. Kalau generate dari
  sumber lain, path bisa meleset dan file-nya ga ketemu walaupun ada.

CARA PAKAI
----------
  pip install edge-tts pydub requests
  # ffmpeg wajib (buat gabung audio + kasih jeda):
  #   Windows: winget install ffmpeg   |   Mac: brew install ffmpeg

  set SUPABASE_URL=https://xzgvhzmmqbijpbrhagjf.supabase.co
  set SUPABASE_KEY=<service_role key>

  python audio_pipeline.py --level 1              # 1 level dulu, cek kualitas
  python audio_pipeline.py --level 1 --limit 5    # 5 file doang, tes cepat
  python audio_pipeline.py --all                  # semua level

  Hasil: ./audio_out/listening/h1/set1/q1.mp3 ...
  Upload folder listening/ ke Supabase Storage (bucket sesuai app).
"""
import os, sys, json, asyncio, argparse, tempfile
from pathlib import Path
from collections import defaultdict

try:
    import edge_tts, requests
    from pydub import AudioSegment
except ImportError as e:
    sys.exit(f"Package kurang: {e}\n  pip install edge-tts pydub requests")

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")
OUT = Path("audio_out")

# ── Suara per pembicara ──────────────────────────────────────────────
# A = wanita, B = pria, Q = narator pertanyaan (suara berita, tegas & jelas)
VOICE = {
    "A": "zh-CN-XiaoxiaoNeural",
    "B": "zh-CN-YunxiNeural",
    "Q": "zh-CN-YunyangNeural",
    "N": "zh-CN-YunyangNeural",   # narator monolog
}
DEFAULT_VOICE = "zh-CN-XiaoxiaoNeural"

# ── Kecepatan per level ──────────────────────────────────────────────
# Ujian asli makin tinggi makin cepat. HSK 1-2 pemula -> pelan.
# HSK 5-6 harus mendekati kecepatan native, kalau ga murid kaget pas ujian.
RATE = {1: "-30%", 2: "-30%", 3: "-15%", 4: "-10%", 5: "-5%", 6: "+0%"}

# Jeda antar baris (ms). Ujian asli ada napas antar pembicara.
GAP_MS = {1: 700, 2: 700, 3: 550, 4: 450, 5: 400, 6: 350}
# Jeda ekstra sebelum baris pertanyaan (Q)
GAP_BEFORE_Q_MS = 900


def fetch(level=None, limit=None):
    """Ambil soal listening dari Supabase. Balikin dict audio_url -> (level, transcript)."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        sys.exit("SUPABASE_URL / SUPABASE_KEY belum di-set (environment variable).")
    url = f"{SUPABASE_URL}/rest/v1/question_bank"
    hdr = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
    # WAJIB paginasi: PostgREST cap 1000 baris per request, "limit" gede diabaikan.
    rows, off, PAGE = [], 0, 1000
    while True:
        params = {"select": "hsk_level,payload", "section": "eq.listening",
                  "limit": PAGE, "offset": off}
        if level:
            params["hsk_level"] = f"eq.{level}"
        r = requests.get(url, params=params, headers=hdr, timeout=60)
        r.raise_for_status()
        batch = r.json()
        if not batch:
            break
        rows += batch
        if len(batch) < PAGE:
            break
        off += PAGE

    jobs, skipped = {}, 0
    for row in rows:
        pl = row.get("payload") or {}
        au, tr = pl.get("audio_url"), pl.get("transcript")
        if not au or not tr:
            skipped += 1
            continue
        # audio_url bisa dipakai bareng beberapa soal (mis. 1 wawancara -> 5 soal).
        # Cukup generate sekali; ambil transcript terpanjang biar ga kepotong.
        if au in jobs and len(json.dumps(jobs[au][1])) >= len(json.dumps(tr)):
            continue
        jobs[au] = (row["hsk_level"], tr)

    print(f"  {len(rows)} soal | {len(jobs)} file audio unik | {skipped} tanpa audio_url/transcript")
    if len(rows) and len(jobs) == len(rows):
        print("  ⚠ 1 file per soal — bagian yang harusnya berbagi audio "
              "(HSK6 wawancara 5 soal, HSK4/5 dialog 1-2 soal) bakal diulang. Cek strukturnya.")
    if limit:
        jobs = dict(list(jobs.items())[:limit])
    return jobs


async def render(transcript, level, dest: Path):
    """Render 1 transcript multi-suara jadi 1 mp3."""
    lines = []
    for item in transcript:
        if isinstance(item, (list, tuple)) and len(item) >= 2:
            spk, text = str(item[0]).strip().upper(), str(item[1]).strip()
        else:
            spk, text = "N", str(item).strip()
        if text:
            lines.append((spk, text))
    if not lines:
        return False

    rate = RATE.get(level, "-10%")
    gap = AudioSegment.silent(duration=GAP_MS.get(level, 500))
    gap_q = AudioSegment.silent(duration=GAP_BEFORE_Q_MS)
    track = AudioSegment.silent(duration=250)   # padding awal, biar ga kepotong

    with tempfile.TemporaryDirectory() as td:
        for i, (spk, text) in enumerate(lines):
            part = Path(td) / f"{i}.mp3"
            await edge_tts.Communicate(text, VOICE.get(spk, DEFAULT_VOICE),
                                       rate=rate).save(str(part))
            if i > 0:
                track += gap_q if spk == "Q" else gap
            track += AudioSegment.from_mp3(part)

    track += AudioSegment.silent(duration=250)
    dest.parent.mkdir(parents=True, exist_ok=True)
    track.export(dest, format="mp3", bitrate="64k")   # mono-ish, hemat kuota user
    return True


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", type=int, help="1-6")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--limit", type=int, help="batasi jumlah file (buat tes)")
    ap.add_argument("--force", action="store_true", help="timpa file yang sudah ada")
    a = ap.parse_args()
    if not a.level and not a.all:
        sys.exit("Pilih --level N atau --all")

    print("Ambil data dari Supabase...")
    jobs = fetch(a.level, a.limit)
    if not jobs:
        sys.exit("Tidak ada job.")

    per_lv = defaultdict(int)
    for lv, _ in jobs.values():
        per_lv[lv] += 1
    print("  per level:", dict(sorted(per_lv.items())))
    print("  kecepatan:", {k: RATE[k] for k in sorted(per_lv)})

    todo = [(au, lv, tr) for au, (lv, tr) in sorted(jobs.items())
            if a.force or not (OUT / au).exists()]
    print(f"\n{len(jobs)} total | {len(jobs)-len(todo)} sudah ada (skip) | {len(todo)} digenerate\n")

    ok = fail = 0
    for i, (au, lv, tr) in enumerate(todo, 1):
        try:
            if await render(tr, lv, OUT / au):
                ok += 1
            else:
                fail += 1
                print(f"  [{i}] transcript kosong: {au}")
        except Exception as e:
            fail += 1
            print(f"  [{i}] GAGAL {au}: {type(e).__name__}: {e}")
        if i % 25 == 0 or i == len(todo):
            print(f"  {i}/{len(todo)}  ok={ok} gagal={fail}")

    print(f"\nSelesai. ok={ok} gagal={fail}")
    print(f"Hasil di: {OUT.resolve()}")
    if ok:
        n = sum(1 for _ in OUT.rglob('*.mp3'))
        mb = sum(f.stat().st_size for f in OUT.rglob('*.mp3')) / 1e6
        print(f"Total {n} file, {mb:.1f} MB")
        print("\nLangkah berikutnya:")
        print("  1. DENGERIN 3-5 file random dulu — kecepatan pas? jeda enak?")
        print("  2. Kalau kecepatan meleset, ubah RATE di script, hapus folder, re-gen")
        print("  3. Upload isi audio_out/ ke Supabase Storage (jaga struktur folder)")
        print("  4. Baru publish set-nya:")
        print("     update public.test_sets set is_published = true")
        print("     where section='listening' and hsk_level = <level>;")

if __name__ == "__main__":
    asyncio.run(main())
