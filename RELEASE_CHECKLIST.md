# Release Checklist — Batch Prompt-Pack (Fitur 1–6)

Mode: commit lokal per fitur, **TIDAK ADA PUSH**. Semua di bawah ini perlu Anda eksekusi manual
sebelum fitur-fitur ini live. Dikerjakan tanpa berhenti tanya (sesuai instruksi mega-prompt) —
semua keputusan yang saya ambil sendiri di sepanjang jalan dicatat di bagian (f).

---

## (a) Daftar commit, urut lama → baru

| Hash | Pesan |
|---|---|
| `76aebfd` | feat: latihan goresan (stroke practice) — Hanzi Writer modal + stroke_progress table |
| `d7ff152` | feat: radikal dasar — Hanzi Starter Kit (grid + Hanzi Writer animation) |
| `a911dd8` | feat: panduan pinyin — chart initial x final + audio suku kata (belum diupload) |
| `291d138` | feat: tone sandhi guide — 4 bab, kurva nada SVG, kuis, audio (belum diupload) |
| `4faea22` | feat: survival kit — 100 kata/frasa pemula, reuse flashcard SRS existing |
| `0b9f70c` | fix: hideAllPages() crash from stale survivalKitCard/toneCoachCard ids |
| `5144a09` | feat: tone coach — deteksi & klasifikasi nada dari mic, 100% client-side |

`CLAUDE.md` juga diupdate (rule commit-lokal/no-push) tapi **belum di-commit** — file itu
sendiri masih `??` (untracked) dari sebelum sesi ini mulai, jadi saya ikuti apa adanya, tidak
saya commit tanpa diminta.

---

## (b) Urutan SQL yang harus dijalankan di Supabase SQL Editor (project `xzgvhzmmqbijpbrhagjf`)

Jalankan **berurutan**, satu-satu, cek tidak ada error sebelum lanjut ke berikutnya:

1. `sql/06_stroke_progress.sql` — tabel `stroke_progress` (dari sesi sebelumnya, belum di-apply)
2. `sql/07_radicals.sql` — tabel `radicals` + seed ~106 radikal
3. `sql/08_survival_kit.sql` — kolom baru di `vocab` (`beginner_kit`, `beginner_order`,
   `beginner_theme`) + upsert 100 kata/frasa

Fitur 3 (Pinyin) dan Fitur 4 (Sandhi) **tidak butuh SQL** — cuma storage (lihat bagian c).

**Sebelum apply #3**, disarankan baca `docs/survival_kit_curation.md` — ada ~5 baris ditandai
"NEW?" yang saya kurang yakin (nama negara/istilah kurang inti di HSK standar). SQL-nya aman
dijalankan meski Anda skip review itu (idempotent, `ON CONFLICT (hanzi) DO UPDATE`), tapi kalau
mau presisi, cek dulu.

---

## (c) Audio — generate lokal, dengerin sample, baru upload

### Pinyin (Fitur 3)
```
pip install edge-tts
python tools/generate_pinyin_audio.py
```
Hasil ke `out/pinyin/` (~1.636 file, 409 suku kata × 4 nada). **Dengerin 8 sample wajib dulu**:
`ma1.mp3 ma2.mp3 ma3.mp3 ma4.mp3 zhi1.mp3 chi1.mp3 shi1.mp3 ri4.mp3`

Kalau oke:
```
set SUPABASE_URL=https://xzgvhzmmqbijpbrhagjf.supabase.co
set SUPABASE_SERVICE_KEY=<service_role key>
python scripts/upload_pinyin.py
```
Upload ke bucket **`listening-audio`** (existing, bukan bucket baru — lihat keputusan (f)#3),
prefix `pinyin/`.

### Tone Sandhi (Fitur 4)
```
python tools/generate_sandhi_audio.py
```
Hasil ke `out/sandhi/` (30 file, `{pinyin_slug}_natural.mp3`). **Dengerin 5 sample wajib**:
`nihao_natural.mp3 budui_natural.mp3 yiyang_natural.mp3 henmang_natural.mp3 laohu_natural.mp3`

Kalau oke:
```
python scripts/upload_sandhi.py
```
Upload ke bucket `listening-audio`, prefix `sandhi/`.

**Catatan**: tombol "Ejaan kamus" di Sandhi Guide reuse file `pinyin/` (jadi otomatis hidup
begitu upload Pinyin selesai, tidak perlu audio terpisah). Tombol audio di kartu Survival Kit
(Fitur 5) dan tombol "Dengar contoh" di Tone Coach (Fitur 6) **juga** reuse `pinyin/` /
konvensi `survival/{pinyin_slug}.mp3` — yang terakhir ini **belum ada generator-nya** (di luar
scope batch ini, lihat (d) known limitation Fitur 5/6).

---

## (d) Checklist tes manual per fitur

Semua: **incognito**, login fresh, cek dark mode toggle, cek viewport 375px (DevTools device
toolbar atau HP asli), cek console (F12) bersih sepanjang interaksi.

**Fitur 1 — Latihan Goresan**
- [ ] Materi → kartu "Latihan Goresan" → pilih level → grid kata muncul
- [ ] Klik ✍️ di kata mana pun → modal buka, animasi goresan jalan
- [ ] Tab Jiplak/Tes → gated kalau level di luar paket, ada pesan lock
- [ ] Mode Tes: selesai 1 karakter → cek row baru masuk `stroke_progress` (butuh SQL #1 di-apply)
- [ ] ✍️ di flashcard biasa (Latihan & Tes) juga buka modal yang sama

**Fitur 2 — Radikal Dasar** (butuh SQL #2)
- [ ] Materi → kartu "Radikal Dasar" → grid ~106 radikal muncul (bukan empty-state)
- [ ] Filter stroke count + search arti/pinyin jalan
- [ ] Klik radikal varian (mis. 氵) → animasi pakai bentuk induk (水), ada catatan "bentuk induk"
- [ ] Klik salah satu dari 3 contoh karakter → buka stroke practice modal
- [ ] Reload → radikal yang udah dibuka ada centang ✓ (localStorage)

**Fitur 3 — Panduan Pinyin** (butuh audio pinyin di-upload buat full test)
- [ ] Tab Chart render, scroll horizontal jalan di mobile, header sticky
- [ ] Klik sel valid → popup 4 tombol nada muncul
- [ ] SEBELUM upload: klik tombol nada → disabled + tooltip "belum tersedia", **console bersih**
- [ ] SESUDAH upload: klik tombol nada → audio kedengeran, bener nadanya
- [ ] Tab Dasar → penjelasan render (cuma bahasa Indonesia, lihat known limitation di bawah)

**Fitur 4 — Tone Sandhi Guide** (butuh audio pinyin + sandhi di-upload buat full test)
- [ ] 4 bab render, kurva SVG before/after muncul
- [ ] SEBELUM upload: kedua tombol audio per contoh kata → disabled setelah diklik, console bersih
- [ ] SESUDAH upload: "Ucapan asli" muter audio natural; "Ejaan kamus" muter 2 suku kata berurutan
  dengan jeda (bisa beda nada dari ucapan asli — itu yang dimaksud "ejaan" vs "diucapkan")
- [ ] Kuis: klik jawaban → benar/salah keliatan, feedback teks muncul

**Fitur 5 — Survival Kit** (butuh SQL #3 buat full test)
- [ ] SEBELUM SQL di-apply: buka Survival Kit → empty-state "Deck belum tersedia", console bersih
- [ ] SESUDAH SQL di-apply: 100 kartu muncul urut tema, badge kartu nunjukin nama tema
- [ ] Grade kartu (Lupa/Susah/Oke/Gampang) → cek `user_mastery` ke-update
- [ ] Selesai deck (100 kartu) → CTA "Lanjut simulasi HSK 1" muncul, klik → masuk Mock Test
- [ ] Tombol keluar (⏎) balik ke Materials hub, BUKAN dashboard

**Fitur 6 — Tone Coach**
- [ ] Buka di HP asli (mic browser butuh device asli, bukan emulator DevTools)
- [ ] Klik Rekam → browser minta izin mic
- [ ] **Tolak izin** → pesan "akses mikrofon ditolak" muncul, console bersih (sudah saya
  verifikasi otomatis lewat mock, tapi tolong konfirmasi manual sekali di HP asli juga)
- [ ] Izinkan → ucapkan salah satu dari 4 kata (妈麻马骂) → kurva target vs suara muncul,
  verdict + tips keluar
- [ ] Coba di tempat berisik → cek pesan "kebisingan" (bukan crash)
- [ ] Diam saja / tidak ngomong → cek pesan "coba lebih deket"
- [ ] Tombol "Dengar contoh" — disabled sebelum audio pinyin di-upload, jalan sesudahnya

---

## (e) File di working tree yang TIDAK berhubungan — untuk Anda review

- **`supabase/functions/grade-essay/index.ts`** — perubahan `picture_essay` grading, sudah ada
  di working tree SEBELUM sesi ini mulai. Tidak saya sentuh sama sekali, tidak saya commit.
  Silakan review/commit terpisah sesuai konteks task itu sendiri.
- File untracked lain yang juga sudah ada sebelum sesi ini (tidak disentuh): `audio_pipeline.py`,
  `audit_vocab_hsk1-2.csv`, `check_audio.py`, `check_images.py`, `clips.json`,
  `generate_images.py`, `images.json`, `logo_transparent.png`, `test_images.py`, `test_img/`,
  `tools/generate_listening_audio.py`, `upload_audio.py`, `vocab_gap_candidates.csv`,
  `supabase/.temp/`.
- **`CLAUDE.md`** — sudah diupdate (rule commit-lokal/no-push) tapi masih untracked, belum
  di-commit (lihat bagian (a)).

---

## (f) Keputusan yang saya ambil sendiri (di luar spec literal, semua karena alasan teknis)

1. **`hsk_level = 1`, bukan `0`**, buat 100 kata Survival Kit — kolom `vocab.hsk_level` punya
   `CHECK (hsk_level BETWEEN 1 AND 6)` dari skema existing, 0 akan ditolak constraint. Filter
   fitur ini tetap `beginner_kit=true` (bukan hsk_level), jadi hsk_level cuma metadata sekunder.
2. **Nambah kolom `vocab.beginner_theme`** (di luar `beginner_kit`/`beginner_order` yang
   disebut prompt) — dibutuhkan buat requirement "group per tema", tidak ada kolom kategori
   existing yang bisa direuse.
3. **Bucket audio: reuse `listening-audio` existing** (prefix `pinyin/`, `sandhi/`, konvensi
   `survival/{slug}.mp3`), bukan bikin bucket baru — app ini sebelumnya cuma punya
   `listening-audio` + `listening-images` (dikonfirmasi baca kode, DECISIONS_NEEDED #6), jadi
   "bucket audio existing" di spec saya artikan sebagai bucket ini.
4. **Nama file audio pakai pinyin-slug (ASCII), bukan hanzi** — buat "Ucapan asli" Sandhi dan
   konvensi Survival Kit. Hindari risiko encoding path Unicode di storage/CDN. `docs/`/komentar
   kode mencatat ini di setiap tempat relevan.
5. **`docs/survival_kit_curation.md` status UPDATE/INSERT adalah TEBAKAN** — saya tidak punya
   akses baca langsung ke tabel `vocab` produksi sesi ini (tidak ada MCP/tool Supabase yang
   dimuat). SQL ditulis idempotent jadi aman terlepas dari tebakan ini benar/salah.
6. **Tone Coach gating 10/hari: `isToneCoachLimited()` selalu `false`** — app ini TIDAK punya
   tier "free" sungguhan di model data-nya (semua `profiles.package` adalah salah satu tier
   berbayar di `PACKAGE_LEVELS`). Mekanisme counter localStorage tetap dibangun & siap pakai,
   tapi butuh keputusan produk kapan/apakah pernah diaktifkan.
7. **`#cardAudioBtn` cuma dinyalakan saat `survivalModeActive`** — tombol ini biasanya
   dead/unwired di flashcard reguler (DECISIONS_NEEDED #6, "jangan implementasi tanpa
   sign-off"). Scoped ketat cuma buat Survival Kit sesuai instruksi eksplisit prompt ini,
   TIDAK resolve #6 secara umum — flashcard reguler tetap seperti sebelumnya.
8. **Tab "Dasar" (Pinyin) dan konten 4 bab (Sandhi) cuma bahasa Indonesia**, belum
   di-i18n-kan ke EN/中 — beda dari UI chrome (tombol/header) yang tetap trilingual penuh.
   Konten panjang linguistik-berat ini saya prioritaskan ship dulu daripada nunggu terjemahan
   3 bahasa buat semuanya. Dicatat sebagai debt, pola sama kayak "hub shell i18n debt" yang
   sudah pernah dicatat sebelumnya di project ini.
9. **Web Speech API (opsional, sekunder, di spec Fitur 6) TIDAK diimplementasikan** — di luar
   inti (pitch-detection DSP sendiri sudah jalan penuh dan itu yang utama), dan feature-detect
   + silent-fail-nya butuh testing lintas-browser yang saya tidak bisa lakukan di sesi ini
   (perlu Chrome asli vs Firefox vs Safari mobile). Bisa ditambah belakangan kalau mau.
10. **Canvas kurva pitch (Tone Coach) reuse `SANDHI_TONE_CURVE_POINTS`** (bukan bikin dataset
    kurva kedua) — data kurva ideal per-nada sama persis kebutuhannya di kedua fitur.
11. **Tone Coach: tap start/stop dipilih daripada hold-to-record** — sesuai catatan spec sendiri
    ("pilih yang paling reliable di mobile"), tap lebih predictable lintas device dibanding
    gesture hold+release yang gampang ke-cancel touch-nya.

---

## (g) TODO keamanan (nanti, tidak blocking)

- Batasi panjang semua input tak-terpercaya di grade-essay (scene_cn, word,
  article, student_text) — mis. maxlength 2000 char + tolak jika melebihi.
  Cegah abuse token API. Berlaku untuk field lama juga, bukan hanya picture_essay.

---

## (h) Security: submit_attempt entitlement leak — CLOSED

**Bug**: `submit_attempt()` (SECURITY DEFINER) mengembalikan `answer`+`explanation`
semua soal non-essay ke caller manapun lewat RPC, tanpa cek `package`/`subscription_end`
sama sekali (ditemukan `sql/04_rls_snapshot.sql` §6, 2026-07-17). Authenticated user
dari paket mana pun bisa panggil RPC ini langsung dengan `set_id` di luar entitlement-nya
dan membaca kunci jawaban lengkap.

**Fix**: `sql/09_submit_attempt_entitlement.sql` — nambah 2 lapis gate di awal fungsi,
mirror persis `gateReason()` + `PACKAGE_LEVELS` yang sudah ada di `app/index.html`
(gate langganan admin/expired/past-due, lalu gate level per package). Set di luar
entitlement → `RAISE EXCEPTION` sebelum query `question_bank`, jadi kunci jawaban
tidak pernah lolos ke response.

**✅ SUDAH di-apply & diverifikasi manual** di SQL Editor project
`xzgvhzmmqbijpbrhagjf` oleh Kyaru, tanggal 2026-07-27. Verifikasi:
- User package `hsk_1_4` submit set `H5XING004` (HSK 5) → **ditolak**,
  error `'level not included in package'`
- User package `hsk_1_4` submit set `h1-listening-1` (HSK 1) → **berhasil**,
  balik JSON review lengkap seperti biasa

`sql/09_submit_attempt_entitlement.sql` sekarang berstatus **arsip/dokumentasi**
(catatan definisi fungsi yang live di prod), **bukan** pending action lagi.

**Sumber definisi fungsi**: basis awal dari snapshot `sql/04_rls_snapshot.sql` §6
(2026-07-17), lalu disesuaikan 2 hal setelah dibandingkan dengan definisi live:
timezone (`current_date` UTC → `(now() at time zone 'Asia/Jakarta')::date`, biar
gate langganan tidak nge-blok user Indonesia 7 jam lebih awal dari seharusnya)
dan teks pesan error (disamakan persis ke `'level not included in package'`).

**Sisa masalah (belum ditambal, di luar scope fix ini)**: user tetap bisa menarik
`correct_answer` untuk set yang MEMANG masuk paketnya sendiri, dengan cara panggil
`submit_attempt` berulang kali pakai `p_answers` kosong/asal — fix ini cuma menutup
kebocoran LINTAS-paket/lintas-level, bukan harvesting kunci jawaban dalam satu
level yang sah diakses. Butuh keputusan produk terpisah (mis. rate-limit per
set_id, atau pisahkan endpoint "practice/review" dari "scored attempt").

---

## Catatan proses (bukan buat Anda eksekusi, cuma transparansi)

Sempat ada regresi nyata: `hideAllPages()` rusak total (throw di SETIAP navigasi, termasuk
`openMaterialsHub()`/`openStrokePractice()` yang sudah ada sebelum batch ini) gara-gara saya
nambah id `survivalKitCard`/`toneCoachCard` ke daftar sebelum elemen HTML-nya benar-benar ada.
Ketauan pas saya cross-check ulang dengan memanggil fungsi navigasi ASLI satu-satu (bukan cuma
fungsi render internal yang saya tes sebelumnya) — sudah diperbaiki di commit `0b9f70c`
sebelum commit Tone Coach. Pelajaran: verifikasi "render bersih" ke depannya harus lewat
entry-point navigasi sungguhan, bukan cuma fungsi render yang dipanggil langsung.

Setiap fitur juga diverifikasi: sintaks JS (`node --check` semua blok `<script>`), reload
browser + console bersih, dan panggilan langsung ke fungsi-fungsi baru (termasuk simulasi
getUserMedia ditolak buat Tone Coach, dan 4 sinyal sintetis flat/naik/dip/turun buat DSP —
keempatnya terklasifikasi benar 100% confidence).
