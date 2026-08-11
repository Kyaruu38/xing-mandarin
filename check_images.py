#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Cek gambar soal: image_url yang dipanggil DB vs file di bucket listening-images.

   Cuma soal yang punya field `image_url` (file) yang dicek.
   Soal bergambar SVG inline (image_options / image_choices / image_svg) DILEWATI —
   gambarnya ada di dalam payload, ga butuh Storage.

   python check_images.py
"""
import os, sys, requests
from collections import defaultdict

URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
KEY = os.environ.get("SUPABASE_KEY", "")
BUCKET = "listening-images"
if not URL or not KEY:
    sys.exit("SUPABASE_URL / SUPABASE_KEY belum di-set.")
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}"}

# 1) semua image_url dari DB (paginasi — PostgREST cap 1000/request)
print("Ambil image_url dari DB...")
db = {}          # image_url -> (level, tipe)
inline = defaultdict(int)
off, PAGE = 0, 1000
while True:
    r = requests.get(f"{URL}/rest/v1/question_bank",
                     params={"select": "hsk_level,section,question_type,payload",
                             "limit": PAGE, "offset": off},
                     headers=H, timeout=60)
    r.raise_for_status()
    rows = r.json()
    if not rows:
        break
    for row in rows:
        pl = row.get("payload") or {}
        if pl.get("image_url"):
            db[pl["image_url"]] = (row["hsk_level"], row["question_type"])
        elif any(k in pl for k in ("image_options", "image_choices", "image_svg")):
            inline[f'HSK{row["hsk_level"]} {row["question_type"]}'] += 1
    if len(rows) < PAGE:
        break
    off += PAGE

print(f"  {len(db)} soal pakai FILE gambar (image_url)")
print(f"  {sum(inline.values())} soal pakai SVG INLINE (aman, ga butuh Storage):")
for k, v in sorted(inline.items()):
    print(f"      {k}: {v}")

if not db:
    print("\n🎉 Semua gambar inline. Bucket ga dipakai sama sekali.")
    sys.exit()

lv = defaultdict(int)
for l, t in db.values():
    lv[f"HSK{l} {t}"] += 1
print("\n  butuh file, per level:", dict(sorted(lv.items())))

# 2) scan bucket
print(f"\nScan bucket '{BUCKET}'...")
store = set()
def walk(prefix=""):
    off = 0
    while True:
        res = requests.post(f"{URL}/storage/v1/object/list/{BUCKET}", headers=H,
                            json={"prefix": prefix, "limit": 1000, "offset": off}, timeout=60)
        res.raise_for_status()
        items = res.json()
        if not items:
            break
        for o in items:
            n = o.get("name")
            if not n:
                continue
            full = f"{prefix}/{n}".lstrip("/") if prefix else n
            if o.get("id") is None:
                walk(full)
            else:
                store.add(full)
        if len(items) < 1000:
            break
        off += 1000
walk()
print(f"  {len(store)} file di bucket")

hilang = sorted(set(db) - store)
yatim  = sorted(store - set(db))

print(f"\n{'='*58}")
print(f"  DB butuh    : {len(db)}")
print(f"  Bucket ada  : {len(store)}")
print(f"  ✅ cocok    : {len(set(db) & store)}")
print(f"  🔴 HILANG   : {len(hilang)}   <- soal ini gambarnya BLANK di app")
print(f"  🗑  yatim    : {len(yatim)}")
print("="*58)

if hilang:
    per = defaultdict(int)
    for f in hilang:
        l, t = db[f]
        per[f"HSK{l} {t}"] += 1
    print("\n🔴 HILANG per level:", dict(sorted(per.items())))
    print("\n   contoh:")
    for f in hilang[:10]:
        print("   ", f)
    if len(hilang) > 10:
        print(f"    ... +{len(hilang)-10} lagi")
else:
    print("\n🎉 Semua gambar ada.")
