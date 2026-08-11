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

Tabel `vocab` sudah sepenuhnya HSK 3.0. Total **6.901 kata**, level 1-6 berjumlah
**5.365 kata** (angka yang dipakai hero landing).

Angka di bawah diverifikasi ulang 10 Agustus 2026 lewat
`select hsk_level, count(*) from public.vocab group by 1` di SQL Editor. Versi
sebelumnya menulis level 2 = 750 dan level 4 = 972 sehingga totalnya meleset jadi
6.899. Jangan menyalin angka dari dokumen ini ke halaman publik tanpa query ulang.

| Level | Jumlah | Arti + contoh |
|-------|--------|---------------|
| 1     | 506    | lengkap       |
| 2     | 751    | lengkap       |
| 3     | 953    | lengkap       |
| 4     | 973    | lengkap       |
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

**Skor dengan rumus berbeda tidak boleh diadu langsung.** Tone Coach versi pertama
memberi tiap nada rumus skornya sendiri (nada 1 pakai "range", nada 2 "slope/6", nada 3
"dipDepth/4") lalu mengurutkannya untuk memilih pemenang. Satuannya beda, jadi urutannya
tidak berarti. Lebih parah: kalau semua rumus menghasilkan 0, `Object.entries().sort()`
mengembalikan kunci pertama, sehingga **nada 1 diam-diam jadi jawaban default setiap kali
sistem bingung** — dengan confidence 0% yang tetap ditampilkan sebagai hasil. Kalau
membandingkan beberapa kandidat, semuanya harus diukur dengan penggaris yang sama, dan
kasus "tidak ada yang cocok" harus ditangani eksplisit.

**Autokorelasi mentah bias ke lag pendek.** `Σ x[i]x[i+lag]` menjumlahkan `len-lag` suku,
jadi jumlahnya makin kecil hanya karena lag-nya makin besar. Membandingkan nilai antar lag
tanpa normalisasi = menghukum nada rendah. Ambang `clarity = best/energy0 >= 0.75` jadi
mustahil dicapai suara cowo (lag panjang cuma memakai ~75% frame), sehingga 84% rekaman
mereka ditolak mentah. Kalau butuh deteksi pitch, pakai YIN/NCCF yang sudah ternormalisasi.

**Gate energi relatif-puncak membunuh ekor nada 3 & 4.** Ambang `RMS >= 15% dari RMS
tertinggi` membuang 40%+ frame pada nada yang berakhir rendah: F0-nya turun, mic HP memang
memotong bass, jadi energinya jatuh jauh di bawah puncak suku kata padahal masih bersuara.
Ikat ambang ke **lantai derau rekaman**, bukan ke puncak sinyal, dan serahkan keputusan
bersuara/tidak ke clarity detektor pitch.

**Generator uji juga bisa salah.** Backtest pertama Tone Coach memberi angka yang terlalu
pesimis untuk dua-duanya karena konsonan sintetisnya dibuat 7x lebih keras dari vokal, dan
level derau dihitung dari RMS seluruh sinyal (ikut terangkat konsonan). Sebelum percaya
hasil benchmark, cek dulu asumsi generatornya masuk akal. Dan selalu uji di generator
KEDUA yang asumsinya beda (holdout), kalau tidak yang terukur cuma seberapa bagus kode
mencocoki simulator sendiri.

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

**Entitlement level SUDAH dijaga RLS.** Catatan lama di sini menulis sebaliknya dan itu
sudah tidak benar; diverifikasi ulang 11 Agustus 2026 langsung ke produksi.

Rantainya, dari luar ke dalam:

- `test_sets` SELECT: `is_admin() OR (is_published AND hsk_level = ANY(allowed_levels()))`
- `question_bank` SELECT: menempel ke baris `test_sets` yang lolos aturan di atas
- `vocab` SELECT untuk `authenticated`: dipagari `allowed_levels()` dan `allowed_tracks()`
- `vocab` SELECT untuk `anon`: `track='hsk' AND hsk_level >= 1 AND hsk_level <= 3`
- `profiles`: hanya `is_admin()` yang boleh INSERT/UPDATE. Tidak ada aturan yang
  mengizinkan user mengubah profilnya sendiri, jadi paket tidak bisa dinaikkan sendiri.

`allowed_levels()` dan `is_admin()` keduanya `SECURITY DEFINER` dengan
`SET search_path TO 'public'`, dan identitasnya diambil dari `auth.uid()`. Tidak ada
jalan melingkar: `is_admin()` membaca `profiles`, dan `profiles` hanya bisa diubah
`is_admin()`.

Bug `hsk_level <= 3` yang dulu kebobolan karena nol juga `<= 3` **sudah ditambal** —
policy anon sekarang memuat `hsk_level >= 1`.

Diuji empiris sebagai anon (tanpa login) lewat REST API memakai kunci anon publik:
kosakata HSK 6, deck non-HSK, `test_sets`, `question_bank`, dan `profiles` semuanya
ditolak; `test_sets`/`question_bank`/`profiles` bahkan gagal di level GRANT dengan
`42501`, sebelum RLS sempat dievaluasi. Yang lolos hanya kosakata HSK 1-3 track `hsk`,
dan itu memang disengaja untuk kartu Kata Hari Ini di layar login.

**Yang BELUM diuji:** semua di atas diuji sebagai anon. Skenario "murid sudah login
tapi paketnya rendah, lalu mencoba menarik HSK 6" belum pernah dibuktikan secara
empiris — konstruksinya benar, tapi belum diamati. Untuk menutup itu perlu login
memakai akun uji berpaket rendah lalu memanggil `/rest/v1/test_sets?hsk_level=eq.6`
dengan token sesi tersebut.

**Halaman login membaca `vocab` SEBELUM user login** (kartu Kata Hari Ini, `hsk_level<=3`,
role anon). Jangan pernah mencabut SELECT anon pada `vocab` sepenuhnya — persempit saja.

**`Success. No rows returned` bukan jaminan berhasil.** Pesan ini sama persis baik saat
`UPDATE` mengenai ribuan baris maupun saat tidak mengenai apa pun. Selalu verifikasi dengan
`SELECT count(*)`. Pernah kejadian migrasi masih `ROLLBACK` sehingga semua file arti/contoh
jalan tanpa efek sama sekali.

**Claude sisi cloud TIDAK boleh menjalankan git di folder ini.** Device bridge bisa menulis
berkas tapi tidak punya izin `unlink`. Akibatnya `git status` membuat `.git/index.lock`,
gagal menghapusnya, dan lock-nya nyangkut sehingga SELURUH operasi git terkunci sampai
dihapus manual dari Windows. Sudah kejadian 10 Agustus 2026 dan sempat disalahartikan
sebagai editor atau Git GUI yang crash. Kalau terpaksa membaca status dari sisi cloud,
pakai `git --no-optional-locks`. Pola yang benar: Claude cloud menyiapkan isi berkas,
Claude Code di mesin sendiri yang menjalankan git.

**`pkill` tidak bisa melihat proses Windows.** Alat Bash di mesin ini menjalankan skrip
POSIX, jadi `pkill -f 'http.server 8899'` melaporkan sukses sambil tidak membunuh apa pun.
Server uji tetap hidup dan port tetap terpakai. Pakai `Stop-Process` lewat PowerShell, dan
cocokkan berdasarkan BARIS PERINTAH (`*http.server <port>*`), bukan nama proses, supaya
proses lain yang kebetulan bernama python tidak ikut mati.

**Jangan mengukur lebar layout lewat `file://`.** `.logo-img` di `paket.html` memakai
`width:auto`, jadi kalau `logo-landing.png` tidak ikut tersedia, teks `alt` membuat logo
terbaca 119px alih-alih 28px dan seluruh pengukuran nav meleset 91px. Sudah kejadian:
sempat disimpulkan nav overflow padahal tidak. Sajikan lewat HTTP dengan gambar tersedia.

**Kontras jangan pernah dihitung di kepala.** Angka 2,99:1 untuk `--star-core` pernah
ditulis ke dokumen sebagai hasil ukur padahal cuma taksiran. Nilai sebenarnya 2,69, dan
2,99 bahkan mustahil: luminansi relatif `#D98E00` adalah 0,341, jadi kontras maksimumnya
terhadap putih murni pun hanya 2,69. Semua angka kontras harus keluar dari skrip, dan
idealnya dari piksel tangkapan layar supaya gradien dan `opacity` bertingkat ikut terhitung.
