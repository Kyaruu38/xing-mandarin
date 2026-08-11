#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Xing Mandarin — Upload Audio ke Supabase Storage
=================================================
Upload audio_out/ ke Storage dengan path PERSIS sesuai audio_url di DB.
RESUMABLE — file yang sudah ada di-skip.

Kenapa jangan drag-drop di dashboard:
  2350 file nested. Dashboard sering flatten struktur folder -> path meleset ->
  app 404 walaupun filenya ada. Script ini jamin path-nya sama persis.

CARA PAKAI
----------
  python upload_audio.py --buckets              # liat bucket yang ada
  python upload_audio.py --bucket audio --level 1 --limit 5   # tes 5 file dulu
  python upload_audio.py --bucket audio --level 1             # 1 level
  python upload_audio.py --bucket audio --all                 # semua

  Butuh SUPABASE_URL + SUPABASE_KEY (service_role) di environment.
"""
import os, sys, argparse
from pathlib import Path
from collections import defaultdict

try:
    import requests
except ImportError:
    sys.exit("pip install requests")

URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
KEY = os.environ.get("SUPABASE_KEY", "")
OUT = Path("audio_out")

if not URL or not KEY:
    sys.exit("SUPABASE_URL / SUPABASE_KEY belum di-set.")

H = {"apikey": KEY, "Authorization": f"Bearer {KEY}"}


def list_buckets():
    r = requests.get(f"{URL}/storage/v1/bucket", headers=H, timeout=30)
    r.raise_for_status()
    bs = r.json()
    if not bs:
        print("Belum ada bucket. Bikin dulu di dashboard Storage.")
        return
    print(f"{len(bs)} bucket:")
    for b in bs:
        print(f"  {b['name']:<24} public={b.get('public')}  id={b['id']}")
    print("\nCatatan: kalau bucket PRIVATE, app perlu signed URL buat muter audio.")
    print("Paling gampang buat audio soal: bucket PUBLIC.")


def existing(bucket, prefix):
    """Ambil daftar file yang sudah ada di Storage (biar skip)."""
    got = set()
    for folder in ("", prefix):
        r = requests.post(f"{URL}/storage/v1/object/list/{bucket}", headers=H,
                          json={"prefix": folder, "limit": 100000}, timeout=60)
        if r.status_code == 200:
            for o in r.json():
                if o.get("name"):
                    got.add(f"{folder}/{o['name']}".lstrip("/"))
    return got


def upload(bucket, local: Path, remote: str, force=False):
    url = f"{URL}/storage/v1/object/{bucket}/{remote}"
    h = dict(H)
    h["Content-Type"] = "audio/mpeg"
    h["x-upsert"] = "true" if force else "false"
    with open(local, "rb") as f:
        r = requests.post(url, headers=h, data=f.read(), timeout=120)
    if r.status_code in (200, 201):
        return "ok"
    if r.status_code == 409:
        return "skip"          # sudah ada
    return f"ERR {r.status_code}: {r.text[:120]}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--buckets", action="store_true", help="tampilkan daftar bucket")
    ap.add_argument("--bucket", help="nama bucket tujuan")
    ap.add_argument("--level", type=int)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--force", action="store_true", help="timpa yang sudah ada")
    a = ap.parse_args()

    if a.buckets:
        list_buckets(); return
    if not a.bucket:
        sys.exit("Pilih --bucket NAMA (liat pakai --buckets)")
    if not a.level and not a.all:
        sys.exit("Pilih --level N atau --all")

    root = OUT / "listening"
    if not root.exists():
        sys.exit(f"{root} ga ketemu. Jalanin audio_pipeline.py dulu.")

    files = sorted(root.rglob("*.mp3"))
    if a.level:
        files = [f for f in files if f.parent.parent.name == f"h{a.level}"]
    if a.limit:
        files = files[:a.limit]
    if not files:
        sys.exit("Ga ada file yang cocok.")

    per = defaultdict(int)
    for f in files:
        per[f.parent.parent.name] += 1
    mb = sum(f.stat().st_size for f in files) / 1e6
    print(f"{len(files)} file, {mb:.1f} MB -> bucket '{a.bucket}'")
    print("  per level:", dict(sorted(per.items())))

    ok = skip = fail = 0
    for i, f in enumerate(files, 1):
        remote = f.relative_to(OUT).as_posix()   # listening/h1/set1/p1q1.mp3
        res = upload(a.bucket, f, remote, a.force)
        if res == "ok":
            ok += 1
        elif res == "skip":
            skip += 1
        else:
            fail += 1
            if fail <= 5:
                print(f"  {remote}: {res}")
        if i % 50 == 0 or i == len(files):
            print(f"  {i}/{len(files)}  ok={ok} skip={skip} gagal={fail}")

    print(f"\nSelesai. ok={ok} skip={skip} gagal={fail}")
    if ok or skip:
        s = files[0].relative_to(OUT).as_posix()
        print(f"\nContoh URL publik (kalau bucket public):")
        print(f"  {URL}/storage/v1/object/public/{a.bucket}/{s}")
        print("  ^ buka di browser. Kalau audio muter -> path bener.")
        print("\nKalau sudah OK, publish:")
        lv = a.level or "<level>"
        print(f"  update public.test_sets set is_published = true")
        print(f"  where section='listening' and hsk_level = {lv};")


if __name__ == "__main__":
    main()
