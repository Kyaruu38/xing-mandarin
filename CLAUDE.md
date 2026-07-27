## Project Context
- Xing Mandarin: platform simulasi HSK 1–6. SATU file `index.html` di GitHub Pages (xingmandarin.com) + Supabase backend (project xzgvhzmmqbijpbrhagjf).
- Semua UI, CSS, JS ada di index.html. Edge Functions terpisah di supabase/functions/.
- Design system: Apple-style, palette cream/navy/gold, font Plus Jakarta Sans, ada dark mode. SEMUA UI baru wajib pakai CSS variables/design tokens yang sudah ada di index.html — jangan hardcode warna baru.
- Vocab table: 4.991 kata HSK 2.0 (kolom: hanzi, pinyin, arti, level, dst — baca schema dulu sebelum asumsi).
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
