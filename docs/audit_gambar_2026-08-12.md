# Audit gambar bank soal — 12 Agustus 2026

Dibuat untuk menutup enam keluhan gambar dari tim konten yang selama ini
tercatat tanpa nomor soal, jadi tidak bisa dikerjakan.

Semua angka di bawah hasil query ke prod, bukan taksiran.

## Peta gambar

| | |
|---|---|
| Soal `image_match` | 100 (20 set × 5 soal) |
| Slot gambar | 500 (5 opsi per soal) |
| **Gambar UNIK** | **71** |
| Rata-rata pemakaian | 7 slot per gambar |
| Soal `image_tf` dengan SVG | 50 |

Satu set memakai 5 gambar yang sama untuk kelima soalnya. Sebagian gambar juga
dipakai lintas set, sampai 15 slot untuk satu gambar. **Mengubah satu SVG bisa
mengubah tiga set sekaligus** — ini yang bikin perbaikan gambar tidak pernah
bisa dikerjakan satu-satu.

## Keluhan tim, satu per satu

### "Gambar D kembar dengan F" — TIDAK DITEMUKAN
Dua pemeriksaan, dua-duanya nol:
- SVG identik byte-per-byte dalam satu soal: **0 pasang**
- Judul gambar (`<title>`) sama dalam satu soal: **0 pasang**

Diperiksa juga per set: kedua puluh set punya 5 konsep yang berbeda semua, tidak
ada sinonim yang bertabrakan (`kasur` dan `tempat tidur` memang dua gambar untuk
benda yang sama, tapi tidak pernah muncul di set yang sama).

Kesimpulan: kalau tim melihat dua gambar yang terasa kembar, itu **mirip secara
visual**, bukan berkas yang sama. Tidak bisa ditemukan lewat query — butuh tim
menunjuk nomor soalnya.

### "Gambar E/F ambigu" — TIDAK BISA DIKERJAKAN
Soal `image_match` di bank ini opsinya **A sampai E**, tidak ada F. Perlu tim
menyebut set dan nomor soal.

### "H1XING003 order 24 tidak ada gambar" — NOMORNYA TIDAK ADA
Set `H1XING003` isinya **order 1 sampai 20**, tidak sampai 24. Susunannya:
`image_tf` 1-5, `image_match` 6-10, `sentence_match` 11-15, `fill_blank` 16-20.
Nomor 24 kemungkinan nomor tampilan di layar (gabungan beberapa bagian), bukan
`order_index`. Perlu tangkapan layar dari tim.

### "打电话 tergambar 玩手机" — PEMETAANNYA BENAR
Satu-satunya soal yang menyinggung telepon: `H2XING007 #2`,
`我的这个坏了，不能给你打电话。` dengan gambar berjudul `ponsel`. Kalimat dan
gambar cocok. Kalau yang dikeluhkan cara menggambarnya (orang memegang HP
seperti sedang main, bukan menelepon), itu soal gaya gambar, bukan salah pasang.

### "他们 digambar 2 orang" dan "baju digambar bukan jaket" — BELUM BISA DILACAK
Tidak ada gambar berjudul orang di bank ini; semuanya benda. Untuk "jaket",
gambar berjudul `jaket` dipakai di `H1XING008 #10` (`天气冷了，我穿这个。`) dan
`H2XING010 #3` — pemetaannya benar, jadi keluhannya soal bentuk gambarnya.

## Yang JUSTRU ditemukan: dua kalimat rusak

Bukan soal gambar, tapi ketemu waktu mencocokkan kalimat dengan gambarnya.

| Set | Soal | Kalimat | Masalah |
|---|---|---|---|
| `H2XING002` | #1 | `我有太阳。` | "Saya punya matahari." Tidak masuk akal, dan tanpa kata bantu bilangan. |
| `H2XING003` | #5 | `我有月亮。` | "Saya punya bulan." Masalah yang sama. |

Kedua set ini polanya `我有 + kata bantu + benda`: `我有一张床`, `我有一本书`,
`我有一个篮球`, `我有一条鱼`, `我有一支笔`, `我有一朵花`. Hanya dua kalimat di
atas yang tidak punya kata bantu, dan dua-duanya benda langit yang memang tidak
bisa dimiliki. Kelihatannya cetakan pola yang dipakai membabi buta.

**SUDAH DIPERBAIKI 12 Agu 2026** atas persetujuan Kyaru. Kunci jawaban tidak
disentuh, jadi gambar yang benar tetap yang sama (A = matahari, E = bulan) dan
tidak ada audio yang perlu diregenerasi (`image_match` memang tanpa audio).

| Set | Soal | Sebelum | Sesudah |
|---|---|---|---|
| `H2XING002` | #1 | `我有太阳。` / "Aku punya matahari." | `今天太阳很大。` / "Hari ini mataharinya terik." |
| `H2XING003` | #5 | `我有月亮。` / "Aku punya bulan." | `晚上我看见月亮了。` / "Malam ini aku melihat bulan." |

Kenapa keluar dari pola `我有...`: polanya sendiri yang tidak bisa dipakai untuk
benda langit. Kalimat penggantinya dipilih yang tetap membuat gambar yang sama
jadi jawaban benar, memakai kosakata HSK 2 (`今天`, `太阳`, `很`, `大`, `晚上`,
`看见`, `月亮`), dan sejalan dengan gaya kalimat yang sudah dipakai di set
tetangga (`H2XING009 #4` juga memakai bentuk `今天 ... 很大`).

Disapu juga seluruh bank soal untuk pola yang sama: kalimat berawalan `我有`
tanpa kata bantu bilangan sekarang **nol**. Satu-satunya yang tersaring
(`H2XING004 #2`, `我有一根香蕉。`) ternyata benar — `根` memang kata bantu untuk
pisang, cuma tidak ada di daftar pemeriksa.

## Pemeriksaan otomatis yang LOLOS

- 50 soal `image_tf`: pasangan gambar-kalimat-kunci **konsisten semua**.
- 100 soal `image_match`: gambar pada opsi yang benar cocok dengan kata benda di
  kalimatnya. Set HSK 2 memang menulis `这个` alih-alih menyebut bendanya, jadi
  bagian itu diperiksa manual, bukan lewat kata kunci.

## Yang audit ini TIDAK bisa lihat

Semua di atas memeriksa **teks**: judul di dalam SVG, kalimat soal, kunci
jawaban. Tidak ada satu pun gambar yang benar-benar dilihat. Kalau gambarnya
sendiri jelek, ambigu, atau salah bentuk, audit ini akan tetap bilang lolos.
Untuk itu perlu lembar kontak 71 gambar bernomor supaya tim bisa menunjuk.
