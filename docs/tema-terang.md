# Tema terang: model token permukaan

Catatan permanen dari sesi 10 Agustus 2026. Dibuat karena alasan di balik
perubahan warna sesi itu tidak muat di pesan commit, dan tanpa ini perbaikannya
gampang dibatalkan tanpa sengaja oleh orang yang mengira nilainya asal pilih.

Baca ini sebelum menambah warna, permukaan, atau kartu baru.

---

## Masalahnya

Xing lahir **dark-first**. Di tema gelap, cara menaikkan permukaan satu tingkat
adalah menumpuk putih transparan, dan cara menurunkannya adalah menumpuk hitam
transparan. Keduanya bekerja karena latar dasarnya gelap.

Tema terang ditambahkan belakangan, dan seluruh nilai transparan itu ikut
terbawa apa adanya. Di atas krem `#F7F1DE`, mekanismenya terbalik:

- putih 2% di atas panel putih → beda **nol**
- hitam 22% di atas krem → berubah jadi slab abu `#C1BAA5`, bukan "sedikit lebih
  dalam"

Akibat konkretnya, semuanya di tema terang:

| Elemen | Sebabnya | Kontras |
|---|---|---|
| `.flagship-big` "Rp62.500" | emas `#F2B01E` di atas slab abu | **1,02:1** |
| `.flagship-per` | `--text` diredupkan `opacity:.62` | 3,16:1 |
| `.flagship-bundle` | `opacity:.66` | 3,46:1 |
| `.flagship-tot` | `opacity:.78` | 4,47:1 |
| `.box`, `.opt` di `paket.html` | putih 2% di atas kartu putih | tidak terlihat |
| 3 border | `rgba(255,255,255,.09–.14)`, semuanya di `index.html` | tidak terlihat |

Ditambah dua token yang rusak diam-diam:

- **`--raise` dirujuk `.plan-meta span` tapi tidak pernah didefinisikan di berkas
  manapun.** Pil "1×8 pertemuan" karena itu tampil tanpa latar sama sekali. Ini
  bukan pilihan desain, ini variabel mati.
- **`--gold-ink` dirujuk `CLAUDE.md` sebagai token yang benar untuk teks emas,
  tapi juga tidak pernah ada wujudnya.** `index.html` malah menulis `#F2B01E`
  langsung — persis yang dilarang catatannya sendiri — dan `paket.html` membuat
  nama tandingan `--gold-text`.

---

## Solusinya

Token dinamai menurut **peran**, bukan menurut warna atau arah. Tiap tema
mengisi mekanismenya sendiri, dan mekanismenya boleh berlawanan.

| Token | Peran | Gelap | Terang |
|---|---|---|---|
| `--raise` | kotak/pil bersarang yang ringan | putih 5,5% | `#F6F0DE` |
| `--inset` | panel angka di dalam kartu | hitam 22% (**turun**) | `#FFFFFF` + bayangan (**naik**) |
| `--hairline` | garis pemisah di atas permukaan bersarang | putih 11% | `var(--line)` |
| `--gold-ink` | emas **sebagai teks** | `#F2B01E` | `#8A5A00` |
| `--gold-wash` | latar samar bernuansa emas | emas 5% | emas 13% |

`--inset` adalah inti idenya. Panel harga di tema gelap **turun** supaya angka
emasnya menyembul; di tema terang dia **naik jadi putih** supaya angkanya
menyembul. Hierarki visualnya sama, caranya berlawanan. Kalau nanti ada yang
merasa `--inset` "salah" karena isinya putih, itu justru yang dimaksud.

`--gold-text` di `paket.html` di-rename jadi `--gold-ink` supaya kedua halaman
memakai satu nama dan panduan di `CLAUDE.md` akhirnya jadi benar.

---

## Hasilnya

Diukur dari **piksel tangkapan layar** hasil render Chromium, bukan dari nilai
CSS — supaya gradien `body::before`, `opacity` bertingkat, dan tumpukan alpha
ikut terhitung. Tujuh belas elemen di dua tema, semuanya lulus 4,5.

| Elemen | Sebelum | Sesudah |
|---|---|---|
| Rp62.500 | **1,02** | **5,93** |
| PER PERTEMUAN | 3,16 | 5,98 |
| Rp3.000.000 untuk 4 bulan penuh | 4,47 | 13,62 |
| Rp4.000.000 kalau sekalian… | 3,46 | 5,98 |

Tema gelap tidak bergeser: emas di panel harga tetap 9,94.

`--muted` tema terang juga diturunkan dari `#6B7192` ke `#5C6280` pada commit
terpisah. Nilai lama cuma 3,95:1 di atas hero (krem tertimpa gradien emas .13)
dan 4,22 di krem polos. Nilai baru: hero 4,95 · krem 5,29 · panel putih 5,98 ·
panel-2 5,63. Tema gelap tidak disentuh, di sana sudah 6,2–7,6.

---

## Aturan untuk UI baru

1. **Jangan pernah menulis `rgba(0,0,0,…)` atau `rgba(255,255,255,…)` di aturan
   dasar.** Itu asumsi satu tema yang diam-diam terbalik di tema lain. Setelah
   sesi ini jumlahnya **nol** di kedua berkas, tidak menghitung tiga hal yang
   memang bukan aturan tema: definisi token itu sendiri, nilai `--shadow-*`,
   dan satu baris `ctx.fillStyle` di JavaScript penggambar bintang
   (`index.html`, di dalam blok `<script>`). Biarkan tetap nol.
2. **Jangan memakai `opacity` untuk meredupkan teks.** Hasilnya bergantung pada
   apa yang kebetulan ada di belakangnya dan tidak bisa diaudit. Pakai
   `var(--muted)`.
3. **Emas sebagai teks selalu `var(--gold-ink)`.** `var(--gold)` hanya untuk
   latar, border, dan gradien. Di tema terang `--gold` cuma 1,91:1 di atas panel
   putih.
4. **Kalau butuh tingkat permukaan baru, tambahkan token baru dengan nama peran
   di kedua tema.** Jangan menumpuk transparan.

### Catatan `.skymap-foot b`, sudah dibereskan

Sebelum sesi ini aturan `.skymap-foot b{color:var(--star-core)}` memakai
`#D98E00` di tema terang. Kontrasnya **2,69:1** di atas panel putih, dan itu
sudah nilai terbaiknya: luminansi relatif `#D98E00` adalah 0,341, sehingga
kontras maksimumnya terhadap permukaan seterang apa pun tidak bisa melewati
2,69. Tidak ada latar yang bisa menyelamatkannya — warnanya sendiri yang tidak
layak jadi teks di tema terang.

Aturan itu kebetulan tidak kena ke elemen mana pun, jadi cacatnya tidak pernah
terlihat. Commit token permukaan sudah membetulkannya ke `--gold-ink`. Teks
yang ditambahkan pada commit sebelumnya memakai `<strong>` alih-alih `<b>`
untuk menghindari aturan lama itu, dan dipertahankan begitu supaya tidak ada
perubahan tampilan tanpa alasan.

---

## Yang sengaja TIDAK dikerjakan

- **Overflow horizontal di lebar sempit** pada `paket.html`. Catatan versi
  sebelumnya menulis "8px di 320px (`div.opt`)"; angka dan penyebabnya dua-duanya
  meleset. Diukur ulang 11 Agustus 2026 lewat iframe di atas HTTP: **24px di
  320px, 4px di 340px, hilang di 359px**. Nav-nya bukan pelaku — yang melar
  `.opt-price` di kartu Business, karena `<span class="strike">Rp1.500.000</span>`
  yang langsung disambung `Rp1.350.000` tidak punya satu pun titik putus,
  sehingga `min-content`-nya 263px sementara ruang yang tersedia di 320px cuma
  236px. Muncul di ketiga bahasa, jadi bukan efek i18n.

  Dibiarkan **sadar**, bukan terlewat: CLAUDE.md mewajibkan 375px, dan di 359px
  ke atas overflow-nya sudah nol. Kalau nanti mau dikejar, titik masuknya
  memberi kesempatan patah di antara harga coret dan harga akhir, bukan
  mengecilkan `.opt-price`.
- **Ambang 3 kolom `#privategroup` dibulatkan ke 960px**, bukan ke angka hasil
  pengukuran. Dua pengukuran independen memberi lebar `min-content` kartu 288px
  dan 296,8px — selisih 18px pada kebutuhan viewport (936 lawan 942), besar
  kemungkinan dari kondisi pemuatan font saat diukur. Justru karena dua
  pengukuran tidak sepakat, ambangnya dinaikkan. **Jangan dirapatkan ke 940px.**
