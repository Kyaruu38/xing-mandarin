#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate ulang gambar konsep, TAPI simpan ke disk dulu — TIDAK langsung upload.

Kenapa terpisah dari generate_images.py: skrip itu langsung meng-upload hasilnya
ke bucket, jadi gambar yang salah sudah tayang sebelum ada yang sempat melihatnya.
Persis itu yang terjadi pada concepts/shu.jpg — promptnya minta buku TERTUTUP,
yang keluar buku terbuka, dan sejak 28 Juli itu yang dilihat murid.

Alurnya sekarang: generate ke disk -> manusia (atau Claude) LIHAT hasilnya ->
baru upload yang terpilih pakai upload_terpilih.py.

Tiap item digenerate beberapa kali dengan seed berbeda, supaya sekali jalan
langsung ada beberapa pilihan dan tidak perlu bolak-balik.

    python scripts/regen_review.py

Hasil: img_review/<nama>_seed<N>.jpg
Tidak butuh kunci Supabase sama sekali — murni mengunduh dari pollinations.
"""
import os, time, json, urllib.parse, pathlib
import requests

# Gaya yang sama persis dengan generate_images.py supaya hasilnya tidak
# terlihat asing di samping gambar-gambar lama.
STYLE = (", clean flat vector illustration, simple, minimal, white background, "
         "no text, no words")

OUT = pathlib.Path("img_review")
SEEDS = [11, 27, 43]          # tiga percobaan per item

# Prompt ditulis dengan larangan eksplisit, bukan cuma deskripsi positif.
# Pelajaran dari shu.jpg: "a single closed book" saja tidak cukup — model
# gambar cenderung menggambar buku terbuka karena itu yang paling umum.
# Larangan yang menyebut bentuk salahnya secara harfiah jauh lebih efektif.
ITEMS = [
    {
        "nama": "shu",
        "prompt": ("a closed hardcover book resting flat on a table, seen from a "
                   "slight angle, front cover facing up and fully visible, the book "
                   "is completely shut with all pages inside, NOT open, no visible "
                   "pages, no spread pages, no bookmark, no people, no hands"),
    },
]


def gen(nama, prompt, seed):
    url = ("https://image.pollinations.ai/prompt/"
           + urllib.parse.quote(prompt + STYLE)
           + f"?width=512&height=512&nologo=true&seed={seed}")
    for percobaan in range(3):
        try:
            r = requests.get(url, timeout=120)
            r.raise_for_status()
            if len(r.content) < 2000:
                raise Exception(f"hasil cuma {len(r.content)} byte, kemungkinan gagal")
            OUT.mkdir(exist_ok=True)
            f = OUT / f"{nama}_seed{seed}.jpg"
            f.write_bytes(r.content)
            print(f"  OK   {f}  ({len(r.content)//1024} KB)")
            return True
        except Exception as e:
            if percobaan == 2:
                print(f"  GAGAL {nama} seed{seed}: {e}")
                return False
            time.sleep(3)


def main():
    total = ok = 0
    for it in ITEMS:
        print(f"\n{it['nama']}:")
        for s in SEEDS:
            total += 1
            ok += bool(gen(it["nama"], it["prompt"], s))
            time.sleep(16)      # pollinations rate limit, sama seperti skrip lama
    print(f"\n=== {ok}/{total} berhasil. Ada di folder {OUT}/ ===")
    print("BELUM di-upload. Lihat dulu hasilnya, baru pilih satu.")


if __name__ == "__main__":
    main()
