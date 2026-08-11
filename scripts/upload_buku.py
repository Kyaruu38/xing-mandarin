#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Xing Mandarin -- Unggah audio buku ke Supabase Storage
======================================================
Mengunggah audio_out/buku/**/*.mp3 ke bucket 'listening-audio', memakai path
yang sama persis dengan struktur foldernya:

    audio_out/buku/bab1/dialog1.mp3   ->   buku/bab1/dialog1.mp3

KENAPA BERKAS SENDIRI, BUKAN MENUMPANG upload_audio.py
upload_audio.py mematok `root = OUT / "listening"` di badan main()-nya, jadi
folder buku memang tidak pernah terlihat olehnya. Menambahkan cabang di sana
berarti menyentuh skrip yang sudah dipakai untuk 2350 berkas soal HSK yang
sekarang tayang -- risikonya tidak sebanding dengan hematnya. Yang ditiru di
sini hanya BENTUK PERMINTAANNYA (header, x-upsert, arti kode 409), karena
bentuk itu sudah terbukti benar di produksi.

KENAPA BUCKET 'listening-audio', BUKAN BUCKET BARU
app/index.html menyelesaikan URL audio lewat satu fungsi saja:
    sb.storage.from('listening-audio').getPublicUrl(path)
Bucket baru berarti fungsi kedua di berkas 595KB yang rapuh itu. Prefiks
'buku/' sudah cukup memisahkan isinya dari 'listening/'.

DUA NAMA VARIABEL KUNCI, SENGAJA
Repo ini punya dua kebiasaan yang berbeda: upload_audio.py di root membaca
SUPABASE_KEY, sedangkan scripts/upload_pinyin.py dan scripts/upload_sandhi.py
membaca SUPABASE_SERVICE_KEY. Berkas ini ada di scripts/, jadi kalau cuma menerima
satu nama, orang yang mengikuti skrip tetangganya akan dibilang "kunci belum
di-set" padahal sudah. Keduanya diterima; SUPABASE_SERVICE_KEY didahulukan.
Nama flag juga punya alias Inggris (--dry-run, --force, --all) supaya kebiasaan
dari skrip sebelah tetap jalan.

CARA PAKAI
----------
    set SUPABASE_URL=https://xzgvhzmmqbijpbrhagjf.supabase.co
    set SUPABASE_SERVICE_KEY=<service_role key>

    python scripts/upload_buku.py --daftar          # lihat apa yang akan diunggah, TANPA mengunggah
    python scripts/upload_buku.py --bab 1           # satu bab dulu (6 berkas)
    python scripts/upload_buku.py --semua           # semua 66 berkas
    python scripts/upload_buku.py --semua --timpa   # timpa yang sudah ada di Storage

RESUMABLE: berkas yang sudah ada di Storage dilewati (Storage menjawab 409).

Setelah selesai skrip ini MEMERIKSA SENDIRI hasilnya lewat HEAD ke URL publik,
bukan cuma percaya pada kode 200 waktu unggah.
"""
import os, sys, argparse, re
from pathlib import Path

try:
    import requests
except ImportError:
    sys.exit("pip install requests")

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "audio_out"          # dasar penghitungan path remote
BUKU = OUT / "buku"
BUCKET = "listening-audio"

URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
KEY = (os.environ.get("SUPABASE_SERVICE_KEY")
       or os.environ.get("SUPABASE_KEY")
       or "")
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}"}


def urut(f: Path):
    """bab10 harus datang setelah bab9, bukan setelah bab1.

    sorted() biasa membandingkan sebagai teks sehingga urutannya jadi
    bab0, bab1, bab10, bab2 -- benar secara hasil, membingungkan waktu dibaca.
    """
    m = re.search(r"bab(\d+)", f.parent.name)
    return (int(m.group(1)) if m else 999, f.name)


def kumpulkan(bab=None, batas=None):
    if not BUKU.exists():
        sys.exit(f"{BUKU} tidak ada. Jalankan dulu: python scripts/audio_buku.py --all")
    files = sorted(BUKU.rglob("*.mp3"), key=urut)
    if bab is not None:
        files = [f for f in files if f.parent.name == f"bab{bab}"]
    if batas:
        files = files[:batas]
    return files


def unggah(local: Path, remote: str, timpa=False):
    url = f"{URL}/storage/v1/object/{BUCKET}/{remote}"
    h = dict(H)
    h["Content-Type"] = "audio/mpeg"
    h["x-upsert"] = "true" if timpa else "false"
    # Jaringan putus di berkas ke-40 tidak boleh membatalkan 26 berkas sisanya.
    # Skrip ini resumable, jadi yang gagal cukup diulang dengan perintah yang sama.
    try:
        r = requests.post(url, headers=h, data=local.read_bytes(), timeout=180)
    except requests.RequestException as e:
        return f"GAGAL jaringan: {str(e)[:120]}"
    if r.status_code in (200, 201):
        return "ok"
    # Storage menolak duplikat dengan 409. Sebagian versi gateway membungkusnya
    # jadi 400 dengan pesan Duplicate -- keduanya artinya "sudah ada", bukan gagal.
    if r.status_code == 409 or (r.status_code == 400 and "uplicate" in r.text):
        return "lewat"
    return f"GAGAL {r.status_code}: {r.text[:140]}"


def periksa(remote: str):
    """HEAD ke URL publik. Ini yang membuktikan file benar-benar bisa diambil app."""
    u = f"{URL}/storage/v1/object/public/{BUCKET}/{remote}"
    try:
        r = requests.head(u, timeout=30)
        return r.status_code, int(r.headers.get("content-length", 0)), u
    except Exception as e:
        return 0, 0, f"{u}  ({e})"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bab", type=int, help="nomor bab 0-10")
    ap.add_argument("--semua", "--all", action="store_true", dest="semua")
    ap.add_argument("--batas", "--limit", type=int, dest="batas",
                    help="berhenti setelah N berkas (buat tes)")
    ap.add_argument("--timpa", "--force", action="store_true", dest="timpa",
                    help="timpa yang sudah ada di Storage")
    ap.add_argument("--daftar", "--dry-run", action="store_true", dest="daftar",
                    help="cuma tampilkan daftarnya, tidak mengunggah, tidak butuh kunci")
    a = ap.parse_args()

    if not a.daftar and a.bab is None and not a.semua:
        ap.error("pilih --bab N, atau --semua, atau --daftar")

    files = kumpulkan(a.bab, a.batas)
    if not files:
        sys.exit("Tidak ada berkas yang cocok.")

    mb = sum(f.stat().st_size for f in files) / 1e6
    print(f"{len(files)} berkas, {mb:.1f} MB -> bucket '{BUCKET}'")

    if a.daftar:
        for f in files:
            print(f"  {f.relative_to(OUT).as_posix():<34} {f.stat().st_size/1024:6.0f} KB")
        print("\n(--daftar: belum ada yang diunggah)")
        return

    if not URL or not KEY:
        sys.exit("SUPABASE_URL / SUPABASE_SERVICE_KEY belum di-set. "
                 "(SUPABASE_KEY juga diterima.)")

    ok = lewat = gagal = 0
    contoh_gagal = []
    for i, f in enumerate(files, 1):
        remote = f.relative_to(OUT).as_posix()      # buku/bab1/dialog1.mp3
        hasil = unggah(f, remote, a.timpa)
        if hasil == "ok":
            ok += 1
        elif hasil == "lewat":
            lewat += 1
        else:
            gagal += 1
            if len(contoh_gagal) < 5:
                contoh_gagal.append(f"  {remote}: {hasil}")
        if i % 10 == 0 or i == len(files):
            print(f"  {i}/{len(files)}  baru={ok} sudah-ada={lewat} gagal={gagal}")

    for baris in contoh_gagal:
        print(baris)
    print(f"\nSelesai. baru={ok} sudah-ada={lewat} gagal={gagal}")

    # --- Pembuktian, bukan pengakuan ---------------------------------------
    # Kode 200 waktu POST cuma bilang "server menerima". Yang penting buat app
    # adalah file itu bisa DIAMBIL lewat URL publik. Tiga titik diperiksa:
    # yang pertama, yang tengah, yang terakhir.
    if ok == 0 and lewat == 0:
        print("\nTidak ada satu pun yang berhasil naik, jadi tidak ada yang diperiksa.")
        print("Betulkan dulu penyebab gagalnya di atas, lalu jalankan lagi perintah yang sama.")
        return

    titik = sorted({0, len(files) // 2, len(files) - 1})
    print("\nPemeriksaan URL publik (HEAD):")
    semua_lulus = True
    for idx in titik:
        remote = files[idx].relative_to(OUT).as_posix()
        kode, panjang, u = periksa(remote)
        lokal = files[idx].stat().st_size
        cocok = "ukuran cocok" if panjang == lokal else f"ukuran BEDA (remote {panjang}, lokal {lokal})"
        print(f"  {kode}  {remote}  {cocok}")
        if kode != 200 or panjang != lokal:
            semua_lulus = False
            print(f"       {u}")

    if semua_lulus:
        print("\nTiga titik itu terambil utuh lewat URL publik.")
    else:
        print("\nAda yang tidak lolos. Kalau kodenya 400/404 padahal unggahnya sukses,")
        print("kemungkinan besar bucket-nya PRIVATE -- app butuh signed URL, bukan public URL.")

    print("\nYang pemeriksaan ini TIDAK bisa lihat:")
    print("  - isi audionya benar atau tertukar (HEAD cuma melihat ukuran berkas)")
    print(f"  - {len(files) - len(titik)} berkas lain yang tidak ikut diperiksa")
    print("  Kalau mau tuntas: jalankan lagi tanpa --timpa; semuanya harus 'sudah-ada'.")


if __name__ == "__main__":
    main()
