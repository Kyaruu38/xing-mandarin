## Project Context
- Xing Mandarin: platform simulasi HSK 1–6. SATU file `index.html` di GitHub Pages (xingmandarin.com) + Supabase backend (project xzgvhzmmqbijpbrhagjf).
- Semua UI, CSS, JS ada di index.html. Edge Functions terpisah di supabase/functions/.
- Design system: Apple-style, palette cream/navy/gold, font Plus Jakarta Sans, ada dark mode. SEMUA UI baru wajib pakai CSS variables/design tokens yang sudah ada di index.html — jangan hardcode warna baru.
- Vocab table: 6.899 kata **HSK 3.0** (bukan 2.0 lagi). Detail per level & kolom contoh kalimat ada di bagian "Vocab — standar HSK 3.0" di bawah.
- Naming convention set soal: H{level}XING{seq}.
- Audio existing di Supabase Storage, di-generate via pipeline edge-tts (Python).

## Hard Rules (WAJIB, pelanggaran = rollback)
1. JANGAN refactor kode yang tidak berhubungan dengan task. Minimal diff.
2. JANGAN menyentuh logika RLS, submit_attempt, auth, atau package gating kecuali task memintanya eksplisit.
3. Setiap variabel HARUS dideklarasikan (const/let). Pernah ada insiden `browseOrigin` undeclared yang bikin site down 1 jam.
4. Commit LOKAL per fitur. DILARANG menjalankan git push dalam bentuk apapun sampai diperintah eksplisit. Testing fungsional penuh dilakukan user secara batch di localhost nanti; tugas per fitur: pastikan render bersih tanpa console error di halaman yang bisa diakses, dan tulis checklist tes manual.
5. Semua fitur baru harus jalan di mobile viewport (375px) DAN dark mode.
6. Storage bucket: JANGAN pernah set public listing. Ikuti pola akses bucket audio yang sudah ada.
7. Satu fitur per commit. Format commit: "feat: <nama fitur> — <ringkas>".

---

## Versi aplikasi

Versi ditulis di **dua tempat** dan keduanya HARUS sama saat rilis:

1. `app/index.html` → `const APP_VERSION = '4.0';` (dekat `SUPABASE_URL`)
2. `version.json` di root repo → `{ "version": "4.0" }`

Aturan penomoran (mulai dari 4.0):

- Update **besar** → naik 1 angka penuh: `4.0` → `5.0`
- Update **kecil** → naik 0.1: `4.0` → `4.1`
- Setelah `x.9`, lanjut ke integer berikutnya: `4.9` → `5.0`

Versi tampil ke user di dua tempat: baris kecil di bawah form **login**, dan di dalam
**menu akun** di dashboard.

### Cara kerja notifikasi update

`APP_VERSION` = versi kode yang sedang jalan di tab user (ikut ter-cache bareng HTML).
`version.json` = versi yang sedang terpasang di server (di-fetch `no-store` + query string
supaya tidak kena cache CDN).

Kalau berbeda → user memegang tab lama → muncul banner "Versi baru tersedia" dengan tombol
Refresh. Dicek 60 detik setelah load, tiap 10 menit, dan setiap tab kembali difokus. Banner
bisa ditutup, dan tidak muncul lagi selama sesi itu.

**Kalau lupa update `version.json`, notifikasi tidak akan pernah muncul.**

---

## Vocab — standar HSK 3.0

Tabel `vocab` sudah sepenuhnya HSK 3.0. Total **6.899 kata**:

| Level | Jumlah | Arti + contoh |
|-------|--------|---------------|
| 1     | 506    | lengkap       |
| 2     | 750    | lengkap       |
| 3     | 953    | lengkap       |
| 4     | 972    | lengkap       |
| 5     | 1.059  | lengkap       |
| 6     | 1.123  | lengkap       |
| 7     | 1.536  | belum (coming soon) |

Kolom: `pinyin` (bacaan standar, 多音字 sudah dibetulkan), `meaning_id` (arti Indonesia),
plus `example_zh`, `example_pinyin`, `example_id`.

`hsk_level = 7` menampung band **HSK 7-9**. Kata-katanya sudah ada tapi belum ditampilkan
ke user. Saat mau dibuka nanti, tinggal generate arti + contohnya.

Migrasi: `sql/11_vocab_hsk30_migrate_1-4.sql` dan `sql/12_vocab_hsk30_migrate_5-6.sql`.

---

## Mock Test — alur 3 langkah

Halaman Mock Test (`#mockListCard`) punya **tiga tampilan** yang bergantian lewat
`showMockStep('level' | 'section' | 'detail')`:

1. **`#mockLevelStep`** — kotak HSK 1 sampai 9. Level 1-6 nyata (menampilkan jumlah set,
   atau "Terkunci" kalau di luar paket user). Level 7, 8, 9 masing-masing punya kotak
   sendiri bertanda "Segera" — tetap bisa diklik supaya user melihat bagian apa saja yang
   nanti tersedia. Cover memakai angka hanzi 一 sampai 九 lewat `.hubCardCoverGlyph`.
2. **`#mockSectionStep`** — kotak Set Test / Reading / Listening / Writing untuk level yang
   dipilih. Kalau levelnya 7/8/9 (`isSoonLevel()`), keempat kotak diredupkan dan
   di-disable dengan label "Segera".
3. **`#mockSectionDetail`** — daftar set, juga berbentuk kotak (`#mockList.mockSetGrid`).
   Cover menampilkan nomor urut besar (01, 02, …) berwarna sesuai level; set yang sudah
   pernah dikerjakan mendapat label nilai kecil di pojok kanan atas cover.

Semua kotak memakai `.hubCard` / `.hubCardCover` yang sama dengan halaman Materials —
jangan bikin komponen kartu baru.

### Kenapa begini

Pola lama menumpuk semuanya di satu layar: chip level + chip bagian + seluruh kartu set
sekaligus. Karena tiap level punya puluhan set dan terbagi 4 bagian, halamannya langsung
penuh dan sulit dibaca. Sekarang satu layar = satu keputusan.

### Catatan performa

Seluruh hitungan jumlah set diambil **sekali** lewat satu query ringan (`fetchMockCounts()`,
hanya kolom `hsk_level` + `section`) saat halaman dibuka, lalu dipakai ulang oleh kedua hub.
Pindah antar langkah tidak memicu query baru. Query berat (judul, durasi, jumlah soal,
riwayat attempt) hanya jalan di langkah 3 lewat `loadMockList()`.

Kalau user masuk dari kartu Materials yang sudah menentukan bagian tertentu, bagian itu
disimpan di `mockPendingSection`; user tetap memilih level dulu, lalu langsung dilempar ke
bagian tersebut.

---

## Jebakan yang sudah pernah kena — jangan diulang

**`button { width:100% }` global.** Ada aturan global untuk `button` di CSS (width 100%,
margin-top 22px, background emas). Setiap tombol baru yang bukan tombol utama WAJIB reset
`width:auto; margin:0;` secara eksplisit, kalau tidak tombolnya melar memenuhi kontainer.
Sudah kejadian dua kali: banner update, dan tombol kembali `.mockBackBtn`.

**Selector ID mengalahkan class.** Ada `#mockList{ display:grid; ...minmax(320px) }` yang
lebih kuat daripada class baru `.mockSetGrid`, sehingga grid hanya jadi 2 kolom. Solusinya
menulis `#mockList.mockSetGrid`. Sebelum menambah class layout ke elemen ber-ID, cek dulu
apakah ID-nya sudah punya aturan sendiri.

**Maskot login vs kartu Word of the Day.** `.loginMascot` posisinya absolute. Dulu di
`left:44px` dan menutupi hanzi di `.loginWordOfDay` yang juga menempel kiri. Sekarang di
`right:40px` dengan `z-index:1`. Kalau menambah elemen di panel brand, cek ulang tabrakan.

**Perubahan mobile jangan bocor ke desktop.** Semua override khusus mobile harus di dalam
media query (`max-width:880px` untuk login, `760px` untuk app shell). Pernah kejadian
desktop ikut berubah karena aturan ditulis di luar media query.

**Batas ukuran SQL Editor Supabase.** File di atas ~250 KB ditolak dengan "Query is too
large". 211 KB masih lolos, 272 KB gagal. Pecah file besar jadi beberapa bagian.

**Komentar CSS jangan mengandung `*/` di dalam teksnya.** Pernah kejadian: komentar
berisi `--shadow-*/dst` menutup dirinya lebih awal, sehingga deklarasi di baris
berikutnya (`--dv4-panel`) ikut tertelan dan tidak pernah terdefinisi di tema terang —
semua kartu dashboard kehilangan background. Tulis `--shadow-* / dst` (pakai spasi).

**Override di dalam `@media` harus ditulis SETELAH aturan dasarnya.** Specificity-nya
sama, jadi yang belakangan menang. `.adminListHead`/`.adminRow` pernah punya override
mobile di blok media yang posisinya lebih awal dari aturan dasar, jadi tabel admin tetap
6 kolom di HP.

**Elemen `position:fixed` baru harus dicek terhadap `.bottomNav`.** Nav mobile ada di
`bottom:0` dengan `z-index:20`. Banner update pernah dipasang di `bottom:18px` dengan
`z-index:9999` sehingga menutupi seluruh nav *dan menelan sentuhannya*. Aturan sekarang:
di bawah 760px naikkan ke `bottom:calc(78px + env(safe-area-inset-bottom))`, dan pakai
z-index di bawah modal overlay (200).

**`position:sticky` + `z-index` membuat stacking context.** `.mobileHeader` punya
`z-index:20`; dropdown di dalamnya tidak akan pernah bisa melewati nilai itu di level
root, berapa pun z-index-nya. Kalau seri dengan `.bottomNav` (juga 20), nav menang karena
lebih belakang di DOM — tombol Keluar jadi tidak bisa diklik di layar pendek.

**Warna emas `--gold` jangan dipakai sebagai warna TEKS.** Di tema terang kontrasnya
cuma ~1,7:1 di atas panel krem. Pakai `--gold-ink` (gelap di terang, emas di gelap).

**`git diff --stat` tidak berguna untuk `grammar-data.js`.** Seluruh data ada dalam satu
baris raksasa, jadi menambah 44 poin pun terbaca "6 baris berubah". Verifikasi dengan
menghitung `"hsk":` di dalamnya, bukan jumlah baris.

**Entitlement level TIDAK dijaga RLS (belum).** `test_sets`/`question_bank`/`vocab` hanya
dipagari di JavaScript sampai `sql/13_security_hardening.sql` di-COMMIT. Selama belum,
jangan anggap konten level tinggi aman dari akun paket rendah.

**Halaman login membaca `vocab` SEBELUM user login** (kartu Kata Hari Ini, `hsk_level<=3`,
role anon). Jangan pernah mencabut SELECT anon pada `vocab` sepenuhnya — persempit saja.

**`Success. No rows returned` bukan jaminan berhasil.** Pesan ini sama persis baik saat
`UPDATE` mengenai ribuan baris maupun saat tidak mengenai apa pun. Selalu verifikasi dengan
`SELECT count(*)`. Pernah kejadian migrasi masih `ROLLBACK` sehingga semua file arti/contoh
jalan tanpa efek sama sekali.
