#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Upload out/sandhi/*.mp3 ke Supabase Storage -- bucket 'listening-audio', prefix 'sandhi/'.

JANGAN DIJALANKAN sebelum owner (Kyaru) dengerin & approve 5 sample wajib --
lihat RELEASE_CHECKLIST.md. Sama polanya persis kayak scripts/upload_pinyin.py
(bucket existing, prefix baru, service_role key dari env var).

CARA PAKAI (manual, oleh Kyaru)
-------------------------------
  pip install supabase
  set SUPABASE_URL=https://xzgvhzmmqbijpbrhagjf.supabase.co
  set SUPABASE_SERVICE_KEY=<service_role key>

  python scripts/upload_sandhi.py                # upload semua
  python scripts/upload_sandhi.py --force          # timpa yang sudah ada
  python scripts/upload_sandhi.py --dry-run        # cuma list, tidak upload
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
PREFIX = "sandhi/"
LOCAL_DIR = Path("out/sandhi")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    if not SUPABASE_URL or not SUPABASE_KEY:
        sys.exit("SUPABASE_URL / SUPABASE_SERVICE_KEY belum di-set (environment variable).")
    if not LOCAL_DIR.exists():
        sys.exit(f"{LOCAL_DIR} tidak ada -- jalankan tools/generate_sandhi_audio.py dulu.")

    files = sorted(LOCAL_DIR.glob("*.mp3"))
    if not files:
        sys.exit(f"Tidak ada file .mp3 di {LOCAL_DIR}.")

    print(f"{len(files)} file siap upload ke {BUCKET}/{PREFIX}")
    if a.dry_run:
        for f in files:
            print(f"  [dry-run] {f.name} -> {BUCKET}/{PREFIX}{f.name}")
        return

    sb = create_client(SUPABASE_URL, SUPABASE_KEY)
    ok = fail = 0
    for f in files:
        try:
            with open(f, "rb") as fh:
                sb.storage.from_(BUCKET).upload(
                    f"{PREFIX}{f.name}", fh.read(),
                    file_options={"content-type": "audio/mpeg", "upsert": "true" if a.force else "false"}
                )
            ok += 1
        except Exception as e:
            fail += 1
            print(f"  GAGAL {f.name}: {type(e).__name__}: {e}")
    print(f"\nSelesai. ok={ok} gagal={fail}")

if __name__ == "__main__":
    main()
