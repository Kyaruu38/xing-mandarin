#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Cari file audio YATIM: ada di Storage tapi ga dipanggil audio_url manapun di DB.
   Juga cari yang HILANG: dipanggil DB tapi ga ada di Storage (ini yang bahaya).

   python check_audio.py            # cuma laporan
   python check_audio.py --delete   # hapus yang yatim (konfirmasi dulu)
"""
import os, sys, requests
from collections import defaultdict

URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
KEY = os.environ.get("SUPABASE_KEY", "")
BUCKET = "listening-audio"
if not URL or not KEY:
    sys.exit("SUPABASE_URL / SUPABASE_KEY belum di-set.")
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}"}

# 1) semua audio_url dari DB — WAJIB paginasi, PostgREST cap 1000 baris/request
print("Ambil audio_url dari DB...")
db = set()
off, PAGE = 0, 1000
while True:
    r = requests.get(f"{URL}/rest/v1/question_bank",
                     params={"select": "payload", "section": "eq.listening",
                             "limit": PAGE, "offset": off},
                     headers=H, timeout=60)
    r.raise_for_status()
    rows = r.json()
    if not rows:
        break
    for row in rows:
        au = (row.get("payload") or {}).get("audio_url")
        if au:
            db.add(au)
    print(f"  ...{off + len(rows)} baris")
    if len(rows) < PAGE:
        break
    off += PAGE
print(f"  DB butuh {len(db)} file unik")

# 2) semua file di Storage (telusuri folder)
print("Scan Storage...")
store = set()
def walk(prefix=""):
    off = 0
    while True:
        res = requests.post(f"{URL}/storage/v1/object/list/{BUCKET}", headers=H,
                            json={"prefix": prefix, "limit": 1000, "offset": off},
                            timeout=60)
        res.raise_for_status()
        items = res.json()
        if not items:
            break
        for o in items:
            name = o.get("name")
            if not name:
                continue
            full = f"{prefix}/{name}".lstrip("/") if prefix else name
            if o.get("id") is None:        # folder
                walk(full)
            else:
                store.add(full)
        if len(items) < 1000:
            break
        off += 1000
walk()
print(f"  Storage punya {len(store)} file")

# 3) bandingkan
yatim  = sorted(store - db)
hilang = sorted(db - store)

print(f"\n{'='*58}")
print(f"  DB butuh    : {len(db)}")
print(f"  Storage ada : {len(store)}")
print(f"  ✅ cocok    : {len(db & store)}")
print(f"  🗑  YATIM    : {len(yatim)}  (ada di Storage, ga dipakai DB)")
print(f"  🔴 HILANG   : {len(hilang)}  (dipanggil DB, ga ada di Storage)")
print("="*58)

if hilang:
    print("\n🔴 HILANG — soal ini bakal BISU di app:")
    for f in hilang[:20]:
        print("   ", f)
    if len(hilang) > 20:
        print(f"    ... +{len(hilang)-20} lagi")
    lv = defaultdict(int)
    for f in hilang:
        lv[f.split("/")[1] if "/" in f else "?"] += 1
    print("    per level:", dict(sorted(lv.items())))
    print("    FIX: python upload_audio.py --bucket listening-audio --all")

if yatim:
    print("\n🗑 YATIM — sisa lama, aman dihapus:")
    for f in yatim[:20]:
        print("   ", f)
    if len(yatim) > 20:
        print(f"    ... +{len(yatim)-20} lagi")
    lv = defaultdict(int)
    for f in yatim:
        lv[f.split("/")[1] if "/" in f else "?"] += 1
    print("    per level:", dict(sorted(lv.items())))

    if "--delete" in sys.argv:
        # Pagar pengaman: kalau angka DB kelihatan pas di kelipatan 1000, kemungkinan
        # ke-truncate -> "yatim" palsu -> bisa ngehapus file yang masih kepakai.
        if len(db) % 1000 == 0:
            sys.exit(f"\n⛔ STOP: DB butuh {len(db)} — pas kelipatan 1000, "
                     "kemungkinan hasilnya ke-truncate. JANGAN hapus. Cek paginasi dulu.")
        if input(f"\nHapus {len(yatim)} file yatim? ketik 'ya': ").strip().lower() != "ya":
            sys.exit("Batal.")
        done = 0
        for i in range(0, len(yatim), 100):
            batch = yatim[i:i+100]
            d = requests.delete(f"{URL}/storage/v1/object/{BUCKET}", headers=H,
                                json={"prefixes": batch}, timeout=120)
            if d.status_code == 200:
                done += len(batch)
            else:
                print(f"  gagal batch {i}: {d.status_code} {d.text[:100]}")
        print(f"Terhapus {done} file.")
    else:
        print("\n    Hapus dengan: python check_audio.py --delete")

if not yatim and not hilang:
    print("\n🎉 SEMPURNA — Storage cocok 100% sama DB.")
