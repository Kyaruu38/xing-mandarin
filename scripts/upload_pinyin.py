#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Upload out/pinyin/*.mp3 ke Supabase Storage -- bucket 'listening-audio', prefix 'pinyin/'.

JANGAN DIJALANKAN sebelum owner (Kyaru) dengerin & approve 8 sample wajib
(ma1 ma2 ma3 ma4 zhi1 chi1 shi1 ri4) -- lihat RELEASE_CHECKLIST.md.

Kenapa bucket 'listening-audio', bukan bucket baru: bucket ini sudah ada, sudah
RLS-aman (non-public-listing, pola akses lewat getPublicUrl() persis yang sudah
dipakai listening section), dan menambah prefix baru di bucket existing tidak
perlu setup bucket/policy baru di Supabase dashboard. Keputusan diambil sendiri
(bukan dari spec) -- app-nya sendiri tidak punya bucket generik "audio", cuma
listening-audio dan listening-images (lihat DECISIONS_NEEDED #6). Dicatat di
RELEASE_CHECKLIST.md sebagai keputusan yang perlu di-review.

CARA PAKAI (manual, oleh Kyaru)
-------------------------------
  pip install supabase
  set SUPABASE_URL=https://xzgvhzmmqbijpbrhagjf.supabase.co
  set SUPABASE_SERVICE_KEY=<service_role key -- BUKAN anon key, upload butuh write access>

  python scripts/upload_pinyin.py                # upload semua, skip yang sudah ada di bucket
  python scripts/upload_pinyin.py --force         # timpa yang sudah ada
  python scripts/upload_pinyin.py --dry-run       # cuma list, tidak upload
"""
import os, sys, argparse
from pathlib import Path

try:
    from supabase import create_client
except ImportError as e:
    sys.exit(f"Package kurang: {e}\n  pip install supabase")

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")
BUCKET = "listening-audio"
PREFIX = "pinyin/"
LOCAL_DIR = Path("out/pinyin")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="timpa file yang sudah ada di bucket (upsert)")
    ap.add_argument("--dry-run", action="store_true", help="cuma tampilkan yang akan diupload, tidak upload")
    a = ap.parse_args()

    if not SUPABASE_URL or not SUPABASE_KEY:
        sys.exit("SUPABASE_URL / SUPABASE_SERVICE_KEY belum di-set (environment variable).")
    if not LOCAL_DIR.exists():
        sys.exit(f"{LOCAL_DIR} tidak ada -- jalankan tools/generate_pinyin_audio.py dulu.")

    files = sorted(LOCAL_DIR.glob("*.mp3"))
    if not files:
        sys.exit(f"Tidak ada file .mp3 di {LOCAL_DIR}.")

    print(f"{len(files)} file siap upload ke {BUCKET}/{PREFIX}")
    if a.dry_run:
        for f in files[:10]:
            print(f"  [dry-run] {f.name} -> {BUCKET}/{PREFIX}{f.name}")
        if len(files) > 10:
            print(f"  ... dan {len(files)-10} file lainnya")
        return

    sb = create_client(SUPABASE_URL, SUPABASE_KEY)
    ok = fail = 0
    for f in files:
        dest_path = f"{PREFIX}{f.name}"
        try:
            with open(f, "rb") as fh:
                sb.storage.from_(BUCKET).upload(
                    dest_path, fh.read(),
                    file_options={"content-type": "audio/mpeg", "upsert": "true" if a.force else "false"}
                )
            ok += 1
        except Exception as e:
            fail += 1
            print(f"  GAGAL {f.name}: {type(e).__name__}: {e}")
    print(f"\nSelesai. ok={ok} gagal={fail}")

if __name__ == "__main__":
    main()
