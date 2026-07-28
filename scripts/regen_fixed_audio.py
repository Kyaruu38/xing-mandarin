#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Xing Mandarin — Regenerate audio buat soal listening yang barusan diperbaiki
=============================================================================
160 soal listening kena fix gender di DB (女的->男的 di payload.question DAN
di baris "Q" payload.transcript). Karena baris Q ikut dibakar jadi mp3 (app
sembunyiin p.question dari UI kalau hide_question=true -- murid WAJIB dengar
pertanyaannya dari audio), audio lama masih ngomongin gender yang salah.
question_bank_bak_20260728 adalah snapshot 160 baris itu SEBELUM di-fix --
dipakai di sini cuma buat narik daftar id-nya, BUKAN buat ambil payload
(payload di tabel _bak itu versi LAMA/salah -- payload yang benar ditarik
dari question_bank yang sekarang).

TARGETED, bukan --level: audio_pipeline.py cuma bisa --level (rerender
ribuan klip sekaligus). Script ini nembak PERSIS 160 baris yang kena fix,
lewat filter `id=in.(...)` ke question_bank.

Render pakai LOGIKA PERSIS audio_pipeline.py -- import render() + konstanta
VOICE/RATE/GAP_MS/GAP_BEFORE_Q_MS langsung dari situ, TIDAK ditulis ulang.
Ini penting: klip yang diregenerate harus kedengeran identik (voice, rate,
jeda) sama klip tetangganya di set yang sama yang tidak ikut di-regen.

CARA PAKAI
----------
  pip install edge-tts pydub requests
  # ffmpeg wajib (dipakai audio_pipeline.render() buat gabung + kasih jeda)

  set SUPABASE_URL=https://xzgvhzmmqbijpbrhagjf.supabase.co      (bash: export)
  set SUPABASE_SERVICE_KEY=<service_role key>                     (JANGAN commit ini)

  python scripts\regen_fixed_audio.py --dry-run       # liat daftar dulu, ga render/upload apa2
  python scripts\regen_fixed_audio.py --limit 5        # tes 5 file dulu
  python scripts\regen_fixed_audio.py                  # full 160, render + upload (upsert)
  python scripts\regen_fixed_audio.py --keep            # + simpan mp3 lokal di audio_out/

Upload ke bucket "listening-audio" (bucket yang sama yang dibaca app, lihat
app/index.html renderAudioPlayer -> sb.storage.from('listening-audio')...),
path = payload.audio_url APA ADANYA, x-upsert selalu true (memang harus
nimpa file lama yang salah gender).
"""
import os, sys, argparse, asyncio
from pathlib import Path

# Biar bisa "from audio_pipeline import ..." walau dijalanin dari folder scripts/
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

try:
    import requests
    from audio_pipeline import render, VOICE, RATE, GAP_MS, GAP_BEFORE_Q_MS  # reuse identik, JANGAN tulis ulang
except ImportError as e:
    sys.exit(f"Package/modul kurang: {e}\n  pip install edge-tts pydub requests"
              f"\n  (dan pastikan audio_pipeline.py ada di root repo)")

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")
BUCKET = "listening-audio"
OUT = Path("audio_out")
BAK_TABLE = "question_bank_bak_20260728"


def _headers():
    if not SUPABASE_URL or not SUPABASE_KEY:
        sys.exit("SUPABASE_URL / SUPABASE_SERVICE_KEY belum di-set (environment variable).")
    return {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}


def fetch_rows():
    """Ambil id dari tabel backup, lalu tarik hsk_level+payload TERBARU dari
    question_bank (bukan dari _bak -- _bak itu snapshot SEBELUM fix, payload-nya salah)."""
    hdr = _headers()

    r = requests.get(f"{SUPABASE_URL}/rest/v1/{BAK_TABLE}", params={"select": "id"},
                      headers=hdr, timeout=60)
    r.raise_for_status()
    ids = [row["id"] for row in r.json()]
    if not ids:
        sys.exit(f"{BAK_TABLE} kosong -- ga ada id buat diproses.")

    # WAJIB batch: url in.(...) bisa kepanjangan kalau 160 id sekaligus di-join.
    rows, PAGE = [], 150
    for i in range(0, len(ids), PAGE):
        id_list = ",".join(str(x) for x in ids[i:i + PAGE])
        params = {"select": "id,hsk_level,payload", "id": f"in.({id_list})"}
        r = requests.get(f"{SUPABASE_URL}/rest/v1/question_bank", params=params,
                          headers=hdr, timeout=60)
        r.raise_for_status()
        rows += r.json()

    print(f"  {len(ids)} id di {BAK_TABLE} | {len(rows)} baris ketemu di question_bank (versi terbaru)")
    if len(rows) != len(ids):
        missing = sorted(set(ids) - {row["id"] for row in rows})
        print(f"  ⚠ {len(missing)} id ga ketemu di question_bank (mungkin sudah dihapus/diganti set_id): "
              f"{missing[:10]}{' ...' if len(missing) > 10 else ''}")

    return rows


def build_jobs(rows):
    """Balikin (jobs, skipped). Skip baris tanpa audio_url/transcript -- JANGAN tebak nama file.
    Dedup per audio_url (mirror audio_pipeline.fetch()): 1 audio_url bisa dipakai
    bareng beberapa soal (mis. 1 dialog -> beberapa pertanyaan) -- render sekali,
    ambil transcript terpanjang biar ga kepotong."""
    by_audio_url = {}
    skipped = []
    for row in rows:
        pl = row.get("payload") or {}
        au, tr = pl.get("audio_url"), pl.get("transcript")
        if not au or not tr:
            skipped.append({"id": row.get("id"), "audio_url": au})
            continue
        if au in by_audio_url:
            prev_lv, prev_tr = by_audio_url[au]
            if len(str(tr)) <= len(str(prev_tr)):
                continue
        by_audio_url[au] = (row.get("hsk_level"), tr)

    jobs = [(au, lv, tr) for au, (lv, tr) in sorted(by_audio_url.items())]
    return jobs, skipped


def upload_file(local: Path, remote: str, hdr):
    url = f"{SUPABASE_URL}/storage/v1/object/{BUCKET}/{remote}"
    h = dict(hdr)
    h["Content-Type"] = "audio/mpeg"
    h["x-upsert"] = "true"   # WAJIB nimpa -- audio lama salah gender
    with open(local, "rb") as f:
        data = f.read()
    r = requests.post(url, headers=h, data=data, timeout=120)
    if r.status_code in (200, 201):
        return "ok"
    return f"ERR {r.status_code}: {r.text[:150]}"


async def main():
    ap = argparse.ArgumentParser(
        description="Regenerate audio buat soal listening yang barusan diperbaiki (gender fix), "
                    f"targeted dari id di {BAK_TABLE}.")
    ap.add_argument("--dry-run", action="store_true", help="cuma list yang bakal diproses, jangan render/upload")
    ap.add_argument("--limit", type=int, help="proses N file pertama aja (buat tes)")
    ap.add_argument("--keep", action="store_true", help="simpan mp3 lokal di audio_out/, jangan dihapus setelah upload")
    a = ap.parse_args()

    print(f"Ambil daftar id dari {BAK_TABLE}...")
    rows = fetch_rows()
    jobs, skipped = build_jobs(rows)

    if a.limit:
        jobs = jobs[:a.limit]

    per_lv = {}
    for _, lv, _ in jobs:
        per_lv[lv] = per_lv.get(lv, 0) + 1
    print(f"\n{len(jobs)} file audio unik akan diproses | {len(skipped)} baris di-skip (audio_url/transcript kosong)")
    print("  per level:", dict(sorted((k, v) for k, v in per_lv.items() if k is not None)))

    if skipped:
        print("\nDi-skip (audio_url atau transcript kosong/null -- CEK MANUAL, tidak ditebak):")
        for s in skipped:
            print(f"  - id={s['id']} audio_url={s['audio_url']!r}")

    if a.dry_run:
        print("\n--dry-run: daftar file yang akan diregenerate (render/upload TIDAK dijalankan):")
        for au, lv, _ in jobs:
            print(f"  h{lv}  {au}")
        return

    if not jobs:
        print("\nTidak ada job untuk diproses.")
        return

    hdr = _headers()
    ok = fail = 0
    for i, (au, lv, tr) in enumerate(jobs, 1):
        dest = OUT / au
        try:
            rendered = await render(tr, lv, dest)
            if not rendered:
                fail += 1
                print(f"  [{i}/{len(jobs)}] transcript kosong setelah parse: {au}")
                continue
            res = upload_file(dest, au, hdr)
            if res == "ok":
                ok += 1
                print(f"  [{i}/{len(jobs)}] ✅ {au}")
            else:
                fail += 1
                print(f"  [{i}/{len(jobs)}] ❌ upload gagal {au}: {res}")
        except Exception as e:
            fail += 1
            print(f"  [{i}/{len(jobs)}] ❌ GAGAL {au}: {type(e).__name__}: {e}")
        finally:
            if not a.keep and dest.exists():
                dest.unlink()

    print("\n=== Ringkasan ===")
    print(f"Total target: {len(jobs)}  Berhasil: {ok}  Gagal: {fail}  Di-skip (data kosong): {len(skipped)}")
    if a.keep:
        print(f"MP3 lokal disimpan di: {OUT.resolve()}")
    if fail:
        print("\nGagal bisa di-retry manual dengan --limit atau re-run (yang sukses akan ke-upsert ulang, aman).")


if __name__ == "__main__":
    asyncio.run(main())
