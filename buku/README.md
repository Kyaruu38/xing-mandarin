# Sumber buku Business Mandarin Foundation

Folder ini berisi isi buku dalam bentuk data, bukan dokumen jadi. Dokumen `.docx`
dibangun ulang dari sini, jadi kalau ada yang salah ketik, perbaiki di sini —
jangan di file Word-nya, karena itu bakal ketimpa waktu dibangun ulang.

## Isi folder

| Berkas | Isi |
|---|---|
| `ch0.json` … `ch10.json` | Satu berkas per bab: tujuan belajar, kosakata, ungkapan, 4 dialog, 1 bacaan, grammar, dan seluruh soal latihan beserta kuncinya. |
| `extras.json` | Lampiran: ungkapan bisnis, ungkapan email, ungkapan telepon, dan singkatan dagang. |
| `render.js` | Pembangun dokumen `.docx`. |

## Membangun ulang dokumen

```bash
npm install docx
node buku/render.js "Business Mandarin Foundation.docx" \
  buku/ch0.json buku/ch1.json buku/ch2.json buku/ch3.json buku/ch4.json \
  buku/ch5.json buku/ch6.json buku/ch7.json buku/ch8.json buku/ch9.json buku/ch10.json
```

Appendix (listening script, answer key, rubrik penilaian speaking, dan ringkasan
kosakata) dibuat otomatis dari berkas bab — tidak ditulis tangan, jadi tidak bisa
melenceng dari isi babnya.

## Membuat audio

```bash
pip install edge-tts pydub    # ffmpeg wajib terpasang
python scripts/audio_buku.py --bab 1     # coba satu bab dulu
python scripts/audio_buku.py --all       # 55 berkas
```

## Hubungannya dengan kosakata di web

469 kosakata di berkas-berkas bab ini adalah sumber kebenaran untuk deck Business
di aplikasi. `sql/22_sinkron_kosakata_buku.sql` yang memuatnya ke tabel
`public.vocab_track`, ditata per bab. Kalau menambah kosakata di bab mana pun,
SQL itu perlu dibuat ulang supaya web dan buku tidak berbeda isi lagi.

## Bentuk data satu bab

```
no, title_en, title_id, note
objectives[]                   daftar tujuan belajar
primer[]                       penjelasan pembuka (hanya Bab 0 dan 10)
vocab[]                        [hanzi, pinyin, english, indonesia]
expressions[]                  [hanzi, pinyin, english, indonesia]
dialogues[]                    { situasi, lines: [pembicara, hanzi, pinyin, en, id] }
reading                        { title_zh, title_id, zh, py, en, id }
grammar[]                      { point, penjelasan, pola, contoh[], tips }
exercises                      seluruh soal Part A–D beserta kuncinya
```

Penanda pembicara di `dialogues` adalah `A`, `B`, atau `C`. Tiga-tiganya dapat
suara berbeda waktu dirender jadi audio.
