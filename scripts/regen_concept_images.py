#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Xing Mandarin — Regenerate concept images, TARGETED & LOCAL-FIRST
====================================================================
6 gambar concepts/*.jpg (dadianhua/xuexi/zoulu/maidongxi/kanshu/shu) belum
ada / ambigu — daftar + prompt-nya di images_fix.json (bukan images.json).

KENAPA SCRIPT BARU, BUKAN JALANIN generate_images.py LANGSUNG
---------------------------------------------------------------
generate_images.py TIDAK BISA dipakai buat regenerate SEBAGIAN konsep — ia
selalu loop SEMUA entry di images.json (24 gambar) dan upload dengan
upsert=true. AI image gen (Pollinations) hasilnya NON-DETERMINISTIK tiap
panggil, jadi jalanin generate_images.py apa adanya bakal TIMPA 24 gambar
yang sekarang sudah benar dengan hasil acak baru.

CATATAN KEAMANAN: script ini SENGAJA TIDAK `import generate_images` sebagai
modul, walau secara harfiah diminta reuse. generate_images.py manggil
main() di baris PALING AKHIR file TANPA guard `if __name__ == "__main__":`
— jadi sekadar `import generate_images` saja sudah cukup buat men-trigger
proses generate+upload PENUH 24 gambar (efek samping saat import, bukan
cuma definisi fungsi) — persis hal yang mau dihindari task ini. Sebagai
gantinya, STYLE string & pola retry di bawah DISALIN NILAINYA dari
generate_images.py (bukan ditulis dari nol, bukan di-import). Kalau STYLE
di generate_images.py berubah nanti, sinkronkan manual di sini juga.

generate_images.py dan images.json TIDAK disentuh oleh script ini sama
sekali (tidak dibaca, tidak diimpor, tidak diubah).

CARA PAKAI
----------
  pip install requests          # + `supabase` kalau mau pakai --upload

  # default: generate ke lokal SAJA, TIDAK upload
  python scripts\\regen_concept_images.py
  python scripts\\regen_concept_images.py --only dadianhua --only shu
  python scripts\\regen_concept_images.py --file images_fix.json --out img_out

  # setelah hasil di folder --out DILIHAT MANUAL dan oke, baru upload:
  set SUPABASE_URL=https://xzgvhzmmqbijpbrhagjf.supabase.co
  set SUPABASE_SERVICE_KEY=<service_role key>
  python scripts\\regen_concept_images.py --upload
  # -> script cetak daftar file yang akan DITIMPA di bucket, minta ketik
  #    "YA" (persis) di stdin sebelum benar-benar upload. Selain itu = batal.
"""
import argparse, os, sys, time, urllib.parse, json
from pathlib import Path

try:
    import requests
except ImportError as e:
    sys.exit(f"Package kurang: {e}\n  pip install requests")

# Nilai disalin dari generate_images.py (BUKAN di-import -- lihat docstring
# di atas soal kenapa import langsung berbahaya untuk script ini).
STYLE = ", clean flat vector illustration, simple, minimal, white background, no text, no words"
BUCKET = "listening-images"
SUPABASE_URL = "https://xzgvhzmmqbijpbrhagjf.supabase.co"


def gen_one(item, out_dir: Path):
    """Download 1 gambar dari Pollinations ke lokal. Retry 3x -- mirror
    pola generate_images.gen() (request -> cek ukuran min 2000 byte -> tulis
    file), TAPI tidak upload di sini -- upload dipisah, opsional, manual."""
    prompt = item["prompt"] + STYLE
    url = f"https://image.pollinations.ai/prompt/{urllib.parse.quote(prompt)}?width=512&height=512&nologo=true"
    dest = out_dir / item["path"]
    dest.parent.mkdir(parents=True, exist_ok=True)

    for attempt in range(3):
        try:
            r = requests.get(url, timeout=120)
            r.raise_for_status()
            data = r.content
            if len(data) < 2000:
                raise Exception("gambar terlalu kecil, mungkin gagal generate")
            with open(dest, "wb") as f:
                f.write(data)
            print(f"  OK    {item['path']}  ({len(data)//1024}KB)  -> {dest}")
            return "ok", dest
        except Exception as e:
            if attempt == 2:
                print(f"  GAGAL {item['path']}: {e}")
                return "fail", dest
            time.sleep(3)
    return "fail", dest


def matches_only(item, only_list):
    if not only_list:
        return True
    stem = Path(item["path"]).stem.lower()
    only_lower = [o.lower() for o in only_list]
    return stem in only_lower or item["path"].lower() in only_lower


def upload_all(results):
    """results = list of (item, dest_path) yang sukses digenerate lokal.
    Wajib konfirmasi manual "YA" sebelum benar-benar upload/timpa Storage."""
    try:
        from supabase import create_client
    except ImportError as e:
        sys.exit(f"Package kurang: {e}\n  pip install supabase")

    key = os.environ.get("SUPABASE_SERVICE_KEY", "")
    if not key:
        sys.exit("SUPABASE_SERVICE_KEY belum di-set (environment variable). Wajib buat --upload.")
    sb = create_client(SUPABASE_URL, key)

    print(f"\nFile yang akan DITIMPA (upsert) di bucket '{BUCKET}':")
    for item, dest in results:
        print(f"  {item['path']}")
    confirm = input('\nKetik "YA" (persis, huruf besar) buat lanjut upload -- selain itu batal: ')
    if confirm != "YA":
        print("Dibatalkan -- tidak ada yang diupload. File lokal tetap ada di folder --out.")
        return

    ok = fail = 0
    for item, dest in results:
        try:
            with open(dest, "rb") as f:
                sb.storage.from_(BUCKET).upload(item["path"], f,
                    {"content-type": "image/jpeg", "upsert": "true"})
            print(f"  UPLOADED {item['path']}")
            ok += 1
        except Exception as e:
            print(f"  GAGAL UPLOAD {item['path']}: {e}")
            fail += 1
    print(f"\nUpload selesai. ok={ok} gagal={fail}")


def main():
    ap = argparse.ArgumentParser(
        description="Regenerate concept images, targeted & local-first (lihat docstring file ini).")
    ap.add_argument("--file", default="images_fix.json",
                     help="sumber daftar konsep+prompt (default: images_fix.json, BUKAN images.json)")
    ap.add_argument("--only", action="append",
                     help="nama konsep tanpa .jpg (mis. dadianhua) -- bisa diulang, buat regenerate sebagian aja")
    ap.add_argument("--out", default="img_out", help="folder output lokal (default: img_out/)")
    ap.add_argument("--upload", action="store_true",
                     help="upload hasil ke Storage setelah generate (default: TIDAK upload, cuma lokal)")
    a = ap.parse_args()

    items = json.load(open(a.file, encoding="utf-8"))
    targets = [it for it in items if matches_only(it, a.only)]
    if not targets:
        sys.exit(f"Tidak ada entry yang cocok di {a.file} (--only={a.only}).")

    out_dir = Path(a.out)
    print(f"{len(targets)}/{len(items)} konsep akan digenerate dari {a.file} -> folder {out_dir}/\n")

    results, ok, fail = [], 0, 0
    for it in targets:
        status, dest = gen_one(it, out_dir)
        if status == "ok":
            ok += 1
            results.append((it, dest))
        else:
            fail += 1
        time.sleep(16)  # sama kayak generate_images.py -- jaga rate Pollinations

    print(f"\n=== Lokal selesai. Total:{len(targets)}  OK:{ok}  Gagal:{fail} ===")
    if fail:
        print("Ada yang gagal -- cek koneksi/prompt, atau re-run dengan --only buat yang gagal aja.")

    if a.upload:
        if not results:
            print("\nTidak ada file sukses buat diupload.")
            return
        upload_all(results)
    else:
        print(f"\nTIDAK diupload (default). Cek dulu hasil di {out_dir.resolve()} satu-satu, "
              f"baru jalanin ulang dengan --upload kalau sudah oke.")


if __name__ == "__main__":
    main()
