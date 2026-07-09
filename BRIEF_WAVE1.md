# Xing Mandarin — Build Brief: WAVE 1
### Vocab Import + Flashcard/SRS + Raport
**Untuk dikerjakan oleh Claude Code. Baca semua sebelum mulai ngoding.**

---

## 1. KONTEKS — yang SUDAH ADA (JANGAN DIRUSAK)

- **App:** single-file `index.html`, deploy di GitHub Pages, custom domain `xingmandarin.com`.
- **Repo:** `Kyaruu38/xing-mandarin`.
- **Backend:** Supabase (project ref `xzgvhzmmqbijpbrhagjf`). URL + anon key **sudah di-hardcode** di `index.html` — pakai yang sudah ada, jangan ganti.
- **Fitur yang SUDAH JALAN (JANGAN diubah logikanya):**
  - Login email/password via Supabase Auth.
  - **Single-active-session lock** — RPC `claim_session(uuid,text)` + realtime kick lewat kolom `profiles.active_session_id`. Ini fitur anti-sharing, sensitif, jangan disentuh.
  - **Subscription gate** — cek `profiles.status` + `profiles.subscription_end`.
  - **Admin detection** — function `is_admin()`.
- **Tabel yang sudah ada:** `profiles`, `user_mastery`, `track_progress`.
- **Function/trigger yang sudah ada:** `claim_session(uuid,text)`, `is_admin()`, trigger `handle_new_user`.

### Security model (WAJIB DIPATUHI)
- RLS **ON by default** untuk semua tabel.
- "Auto-expose new tables" **OFF** — jadi **setiap tabel baru butuh GRANT eksplisit ke role `authenticated` DAN policy RLS eksplisit.** Tidak ada tabel yang boleh terbuka tanpa RLS.
- Pola akses: user hanya baca/tulis barisnya sendiri; admin (`is_admin()`) bisa baca semua.
- Referensi bersama (kayak daftar vocab) boleh dibaca semua user login, tapi tetap lewat policy SELECT eksplisit — bukan dibuka mentah.

---

## 2. KEPUTUSAN PRODUK (SUDAH FINAL)

- **Vocab:** HSK 2.0, **6 level**, ~5000 kata. Ambil dari **dataset open-source** (hanzi + pinyin + arti Inggris + level). Import sekali.
- **Track pertama:** HSK exam prep saja.
- **Wave ini membangun:** (1) import data vocab, (2) flashcard + SRS, (3) raport dasar.
- **Mock test, AI generation, terjemahan Indonesia massal = wave berikutnya, DI LUAR scope wave ini** (lihat §6).

---

## 3. CONSTRAINT TEKNIS KRITIS

1. **DILARANG panggil AI dari sisi client.** App ini jalan di GitHub Pages beneran, **BUKAN** di dalam artifact claude.ai. Kamu **TIDAK BISA** memanggil `api.anthropic.com` dari `index.html` (harus expose API key = forbidden). Semua AI generation nanti harus lewat **Supabase Edge Function** yang menyimpan key sebagai secret (pola yang sama dengan Edge Function `send-invoice`/ZeptoMail di project NHS milik owner). **Untuk wave ini, tidak ada AI sama sekali — tidak dibutuhkan.**
2. **Tetap single-file** (`index.html`). Ikuti gaya kode yang sudah ada.
3. **Jangan sentuh** jalur kode auth / session-lock / status-gate.
4. **Jangan pakai localStorage** untuk data app selain yang sudah ada (session id + auth Supabase).
5. **Tabel baru:** RLS + grants wajib.
6. **Jangan jalankan SQL destruktif** pada tabel yang sudah ada.

---

## 4. SCOPE BUILD — kerjakan URUT

### Task 1 — Data vocab + schema
Buat tabel `vocab`:
- Kolom: `id` (uuid pk), `hanzi` (text), `pinyin` (text), `meaning_en` (text), `meaning_id` (text, nullable), `hsk_level` (int, 1–6), `created_at`.
- Unik pada `hanzi` (atau `(hanzi, hsk_level)` — putuskan yang masuk akal, hindari duplikat).
- RLS: semua user `authenticated` boleh **SELECT** (vocab = konten referensi bersama, bukan per-user). **INSERT/UPDATE hanya admin.**
- GRANT sesuai (SELECT untuk authenticated; tulis untuk admin lewat policy).

Lalu: cari **dataset HSK 2.0 open-source yang kredibel** (hanzi/pinyin/level/Inggris). Prefer dataset yang sudah dikenal luas (mis. dataset "complete-hsk-vocabulary" di GitHub). **Verifikasi jumlah kata per level** sebelum import (HSK 1≈150, 2≈150, 3≈300, 4≈600, 5≈1300, 6≈2500 — angka kasar, cek). Import via SQL/script sekali jalan.
- Kalau tidak yakin dengan akurasi dataset penuh, **import HSK 1–3 dulu** (lebih kecil, lebih pasti) dan tandai 4–6 sebagai follow-up. Jangan import data yang meragukan diam-diam.

### Task 2 — Flashcard + SRS
- User pilih level HSK (1–6). Hormati `track_progress`; default ke level 1 atau level terakhir dipakai.
- Tarik kartu dari `vocab` di level itu, dicampur dengan review SRS yang jatuh tempo dari `user_mastery`.
- **SRS:** pakai tabel `user_mastery` yang SUDAH ADA. `item_key` = hanzi. Field: `mastery_level`, `srs_interval`, `srs_ease`, `srs_reps`, `srs_due`, `times_seen`, `times_correct`, `last_reviewed`. Implementasi scheduler ala SM-2 standar.
- **UI kartu:** tampil hanzi → reveal pinyin + arti (`meaning_id` kalau ada, else `meaning_en`). Tombol grade (again/hard/good/easy) update `user_mastery`.
- Simpan setiap review ke `user_mastery` (baris sendiri — RLS sudah izinkan).
- **Tombol "Contoh kalimat":** baca dari tabel `example_bank` KALAU ada. Kalau tabel/baris belum ada, **sembunyikan tombolnya dengan rapi.** (`example_bank` = wave berikutnya — JANGAN bangun generator sekarang.)

### Task 3 — Raport dasar
- Baca `user_mastery` untuk user yang login.
- Tampilkan: total kata dilihat/dikuasai per level HSK, top kata lemah (mastery rendah / sering salah), jumlah due / streak review.
- Simpel, bersih, ikut UI gelap yang sudah ada.

---

## 5. TESTING CHECKLIST (verifikasi sebelum selesai)
- [ ] Login + session-lock + status gate lama **masih jalan** (regression test).
- [ ] Tabel `vocab` punya RLS + grants; user belum login **tidak bisa** baca.
- [ ] Flashcard load per level; grade **persist** setelah refresh (cek baris `user_mastery` di Supabase).
- [ ] Raport mencerminkan kartu yang sudah di-grade.
- [ ] Dashboard admin masih normal.

---

## 6. DI LUAR SCOPE WAVE INI (wave berikutnya — JANGAN mulai)
- Mock test / tabel `question_bank`.
- Example/story bank + AI generation apa pun (butuh Edge Function dulu).
- Terjemahan Indonesia untuk 5000 kata (batch task; ship dulu dengan `meaning_en` + sebagian `meaning_id`).
- Daily task engine (butuh data performa dulu).
- Admin content-generation panel.

Tulis ini sebagai TODO; **jangan setengah-bangun.**

---

## 7. WORKFLOW
- Commit bertahap dengan pesan jelas.
- Setelah perubahan schema, **kasih owner (Kyaru) SQL persis yang kamu jalankan** biar bisa diverifikasi di Supabase.
- Setelah selesai, push ke `main` (auto-deploy ke GitHub Pages). Beri tahu owner apa yang berubah.
