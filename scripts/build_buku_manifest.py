#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Xing Mandarin -- Daftar isi audio buku (buku/audio-manifest.json)
=================================================================
Membaca buku/ch0.json .. ch10.json, lalu menuliskan satu berkas yang dipakai
halaman "dengarkan buku" di app untuk tahu ada trek apa saja, judulnya apa, dan
berkasnya di Storage bernama apa.

KENAPA DITURUNKAN, BUKAN DIKETIK
Judul bab, situasi tiap dialog, dan judul bacaan sudah ada di ch*.json. Kalau
disalin dengan tangan ke berkas kedua, dua-duanya akan berbeda pelan-pelan dan
tidak ada yang sadar sampai ada murid yang bingung. Di sini semuanya dibaca dari
ch*.json, jadi kalau bukunya diperbaiki, cukup jalankan ulang skrip ini.

Nama berkas mp3 juga TIDAK ditebak: pola dialog{i}/bacaan/latihan-a diambil dari
struktur yang sama dengan yang dipakai scripts/audio_buku.py waktu membuatnya,
dan tiap trek dicocokkan dengan berkas nyata di audio_out/buku (kalau ada).
LEVEL_BAB dibaca langsung dari sumber audio_buku.py -- bukan disalin -- supaya
tidak ada dua versi kebenaran soal bab mana setara HSK berapa.

KENAPA TIDAK MENGIMPOR audio_buku.py SAJA
audio_buku.py mengimpor audio_pipeline.py, yang mengimpor edge-tts dan pydub di
baris atas. Artinya sekadar membaca satu konstanta akan menuntut seluruh
perkakas TTS terpasang. Jadi konstantanya diambil dari teks sumbernya.

CARA PAKAI
----------
    python scripts/build_buku_manifest.py            # tulis buku/audio-manifest.json
    python scripts/build_buku_manifest.py --lihat    # tampilkan saja, tidak menulis
    python scripts/build_buku_manifest.py --paksa    # tulis walau belum lengkap

Durasi diambil pakai ffprobe -- tidak pernah ditaksir. Kalau ada trek yang mp3-nya
belum dibuat, atau ffmpeg belum terpasang sehingga durasinya tidak terbaca, skrip
MENOLAK menulis kecuali dipaksa: berkas ini ikut ke repo publik, dan manifest
setengah jadi yang sudah ter-commit tidak akan kelihatan salahnya lagi.

Jalankan dari mana saja, path-nya dihitung dari lokasi berkas ini.
"""
import json, subprocess, argparse, ast, re, sys, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUKU = ROOT / "buku"
AUDIO = ROOT / "audio_out" / "buku"
KELUARAN = BUKU / "audio-manifest.json"
PREFIKS = "buku"          # sama dengan path di bucket listening-audio


def level_bab() -> dict:
    """Ambil LEVEL_BAB dari teks scripts/audio_buku.py, tanpa mengimpornya."""
    src = (ROOT / "scripts" / "audio_buku.py").read_text(encoding="utf-8")
    m = re.search(r"^LEVEL_BAB\s*=\s*(\{[^}]*\})", src, re.M)
    if not m:
        sys.exit("LEVEL_BAB tidak ketemu di scripts/audio_buku.py -- "
                 "berkas itu berubah bentuk, periksa dulu sebelum lanjut.")
    return {int(k): int(v) for k, v in ast.literal_eval(m.group(1)).items()}


def detik(p: Path):
    if not p.exists() or not shutil.which("ffprobe"):
        return None
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=nw=1:nk=1", str(p)],
            capture_output=True, text=True, timeout=30)
        return round(float(out.stdout.strip()), 1)
    except Exception:
        return None


def trek_bab(n: int, d: dict) -> list:
    """Susun daftar trek satu bab, urutannya sama dengan urutan di buku."""
    hasil = []

    for i, dl in enumerate(d["dialogues"], 1):
        hasil.append({
            "jenis": "dialog",
            "no": i,
            "judul_id": f"Dialog {i}",
            "situasi": dl["situasi"],
            "baris": len(dl["lines"]),
            "path": f"{PREFIKS}/bab{n}/dialog{i}.mp3",
        })

    r = d["reading"]
    hasil.append({
        "jenis": "bacaan",
        "no": 1,
        "judul_id": r["title_id"],
        "judul_zh": r["title_zh"],
        # audio_buku.py memecah reading["zh"] per baris, jadi jumlah barisnya
        # dihitung dengan cara yang sama supaya angkanya tidak beda sendiri.
        "baris": len([t for t in r["zh"].split("\n") if t.strip()]),
        "path": f"{PREFIKS}/bab{n}/bacaan.mp3",
    })

    x = d["exercises"]
    hasil.append({
        "jenis": "latihan",
        "no": 1,
        "judul_id": "Latihan Listening Bagian A",
        # Trek ini gabungan: dialog 1 + soal benar/salah, dialog 2 + pilihan
        # ganda, lalu bacaan + pertanyaan terbuka. Jumlahnya ditulis supaya
        # halaman bisa bilang "3 bagian, 5 pertanyaan" tanpa membuka ch*.json.
        "isi": {
            "benar_salah": len(x["listening_tf"]),
            "pilihan_ganda": len(x["listening_mc"]),
            "terbuka": len(x["listening_open"]),
        },
        "path": f"{PREFIKS}/bab{n}/latihan-a.mp3",
    })

    for t in hasil:
        lokal = AUDIO / Path(t["path"]).relative_to(PREFIKS)
        # _ada dipakai untuk laporan di layar saja lalu dibuang sebelum ditulis:
        # "berkasnya ada di disk saya" itu keadaan mesin yang menjalankan skrip,
        # bukan fakta tentang buku, dan berkas ini ikut ke repo publik.
        t["_ada"] = lokal.exists()
        t["detik"] = detik(lokal)
    return hasil


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lihat", action="store_true", help="tampilkan saja, jangan tulis berkas")
    ap.add_argument("--paksa", action="store_true",
                    help="tulis walau ada trek yang mp3-nya belum ada / durasinya kosong")
    a = ap.parse_args()

    lv_map = level_bab()
    bab_list = []
    total_trek = hilang = tanpa_durasi = 0

    for n in sorted(lv_map):
        p = BUKU / f"ch{n}.json"
        if not p.exists():
            sys.exit(f"Tidak ketemu: {p}")
        d = json.loads(p.read_text(encoding="utf-8"))
        if d.get("no") != n:
            sys.exit(f"{p.name} menulis no={d.get('no')} padahal namanya ch{n} -- "
                     f"jangan diteruskan sebelum itu jelas.")
        trek = trek_bab(n, d)
        total_trek += len(trek)
        hilang += sum(1 for t in trek if not t.pop("_ada"))
        tanpa_durasi += sum(1 for t in trek if t["detik"] is None)
        bab_list.append({
            "no": n,
            "title_id": d["title_id"],
            "title_en": d["title_en"],
            "setara_hsk": lv_map[n],
            "trek": trek,
        })

    total_detik = sum(t["detik"] or 0 for b in bab_list for t in b["trek"])
    manifest = {
        "_catatan": ("Dihasilkan oleh scripts/build_buku_manifest.py dari buku/ch*.json. "
                     "Jangan disunting tangan -- jalankan ulang skripnya."),
        "bucket": "listening-audio",
        "prefiks": PREFIKS,
        "jumlah_bab": len(bab_list),
        "jumlah_trek": total_trek,
        "total_detik": round(total_detik, 1) if total_detik else None,
        "bab": bab_list,
    }

    teks = json.dumps(manifest, ensure_ascii=False, indent=1) + "\n"

    durasi_txt = f"{total_detik/60:.1f} menit" if total_detik else "durasi tidak terbaca"
    print(f"{len(bab_list)} bab, {total_trek} trek, {durasi_txt}")
    if hilang:
        print(f"  {hilang} trek belum ada berkas mp3-nya di audio_out/buku "
              f"-- jalankan scripts/audio_buku.py --all dulu kalau mau lengkap.")
    if tanpa_durasi:
        alasan = "ffprobe tidak terpasang" if not shutil.which("ffprobe") else "berkasnya tidak terbaca"
        print(f"  {tanpa_durasi} trek tanpa durasi ({alasan}). Nilainya null, bukan tebakan.")

    if a.lihat:
        print(teks[:1500] + ("\n...(dipotong)" if len(teks) > 1500 else ""))
        print("\n(--lihat: belum ada yang ditulis)")
        return

    # Berkas ini masuk repo dan ikut tayang. Manifest dengan durasi null akan
    # membuat halaman "dengarkan buku" menampilkan trek tanpa panjang, dan
    # penyebabnya (mesin yang menulisnya kebetulan tidak punya mp3-nya) tidak
    # akan kelihatan lagi begitu sudah ter-commit. Jadi ditolak sejak awal.
    if (hilang or tanpa_durasi) and not a.paksa:
        sys.exit("\nTIDAK ditulis: manifest ini akan ikut ke repo publik dalam keadaan "
                 "tidak lengkap.\n"
                 "  Lengkapi dulu audio_out/buku (python scripts/audio_buku.py --all)\n"
                 "  atau pasang ffmpeg kalau yang kurang cuma durasinya,\n"
                 "  atau paksa dengan --paksa kalau memang sengaja.")

    KELUARAN.write_text(teks, encoding="utf-8")
    print(f"\nDitulis: {KELUARAN.relative_to(ROOT)}  ({len(teks)/1024:.1f} KB)")
    print("Berkas ini di-track git dan ikut tayang, jadi app bisa fetch")
    print("  /buku/audio-manifest.json  tanpa perlu query ke database.")


if __name__ == "__main__":
    main()
