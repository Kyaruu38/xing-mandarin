-- Arsip dokumentasi -- APPLIED & DIVERIFIKASI KE PROD 2026-07-28. Status: arsip,
-- BUKAN pending action. Dijalankan manual di Supabase SQL Editor (project
-- xzgvhzmmqbijpbrhagjf) oleh user, bukan lewat Supabase CLI/migration.
--
-- MASALAH
-- -------
-- Pola soal listening_mc di sebagian set: transcript[0] = speaker "A" nanya
-- "你...?" ke lawan bicaranya, transcript[1] = speaker "B" jawab. Voice
-- mapping di audio_pipeline.py (dan tools/generate_listening_audio.py)
-- tetapkan A = suara PEREMPUAN, B = suara LAKI-LAKI (lihat VOICE dict kedua
-- file). Pertanyaan ujiannya (payload.question) nanya soal lawan bicara A
-- (yaitu B) tapi teksnya salah nyebut "女的" (perempuan) -- padahal B
-- suaranya laki-laki, harusnya "男的".
--
-- Filter yang dipakai buat nemuin baris kena bug (lihat query backup/update
-- di bawah): question_type='listening_mc', payload.question mengandung
-- "女的" tapi TIDAK mengandung "男的", transcript[0].speaker='A' dan isinya
-- ada "你" (A yang nanya duluan), transcript[1].speaker='B'.
--
-- Kenapa HSK 2 TIDAK kena: di h2 pola dialognya kebalik -- "B" yang nanya
-- duluan (transcript[0].speaker='B'), bukan "A". Filter update ini
-- mensyaratkan transcript[0]=A DAN transcript[1]=B, jadi baris h2 otomatis
-- tidak masuk -- bukan diverifikasi manual satu-satu bahwa "女的" di h2 selalu
-- benar, tapi karena pola dialognya beda, filter existing tidak match ke h2
-- sama sekali (h2 tidak pernah masuk hasil backup/update).
--
-- Kenapa TRANSCRIPT ikut diubah, bukan cuma payload.question:
-- Baris "Q" di transcript (narator baca ulang pertanyaan) ikut di-render jadi
-- audio (lihat tools/generate_listening_audio.py & audio_pipeline.py, baris Q
-- diproses sama seperti baris dialog, digabung ke 1 file mp3). Dan di app
-- (app/index.html, renderListeningMC/buildReviewListeningMC), kalau
-- payload.hide_question === true, teks p.question TIDAK ditampilkan ke murid --
-- baik saat ngerjain maupun saat review. Murid HANYA dengar pertanyaan dari
-- audio. Jadi ganti teks payload.question doang TIDAK CUKUP -- baris Q di
-- transcript juga harus diganti, DAN audio-nya wajib diregenerate, kalau tidak
-- murid akan lihat opsi jawaban yang benar (男的) tapi dengar narator masih
-- bilang 女的 di audio lama.
--
-- SKALA
-- -----
-- 160 baris question_bank kena (per level: h1=14, h3=60, h4=34, h5=52).
-- 147 file audio UNIK yang perlu diregenerate -- 13 audio_url dipakai lebih
-- dari 1 soal (mis. 1 dialog dipakai buat beberapa pertanyaan turunan),
-- sebelum dedup sudah diverifikasi pertanyaan & transcript identik across
-- baris yang berbagi audio_url yang sama (bukan cuma asumsi, dicek).
--
-- ============================================================
-- 1) BACKUP -- dibuat SEBELUM update, snapshot payload versi SALAH (referensi
--    rollback/audit, BUKAN sumber data buat regenerate audio -- lihat catatan
--    PENDING di bawah soal kapan tabel ini boleh dihapus)
-- ============================================================
create table question_bank_bak_20260728 as
select * from question_bank
where question_type='listening_mc'
  and payload->>'question' like '%女的%'
  and payload->>'question' not like '%男的%'
  and payload->'transcript'->0->>0 = 'A'
  and payload->'transcript'->0->>1 like '%你%'
  and payload->'transcript'->1->>0 = 'B';
-- hasil: 160 baris

-- Grant biar scripts/regen_fixed_audio.py (jalan sebagai service_role lewat
-- REST API, bukan lewat SQL Editor) bisa SELECT id dari tabel backup ini buat
-- narik daftar target -- lalu payload TERBARU (sudah benar) ditarik dari
-- question_bank, bukan dari tabel backup ini.
grant select on public.question_bank_bak_20260728 to service_role;
notify pgrst, 'reload schema';

-- ============================================================
-- 2) UPDATE -- ganti 女的 -> 男的 di payload.question DAN di setiap baris
--    transcript berlabel "Q" (baris lain di transcript, mis. dialog A/B,
--    TIDAK disentuh -- cuma teks pertanyaan yang salah, dialognya sendiri benar)
-- ============================================================
update question_bank q
set payload = jsonb_set(
      jsonb_set(q.payload, '{question}',
        to_jsonb(replace(q.payload->>'question','女的','男的'))),
      '{transcript}',
      (select jsonb_agg(
          case when line->>0='Q'
               then jsonb_build_array('Q', replace(line->>1,'女的','男的'))
               else line end order by ord)
       from jsonb_array_elements(q.payload->'transcript')
            with ordinality as t(line, ord)))
where q.question_type='listening_mc'
  and q.payload->>'question' like '%女的%'
  and q.payload->>'question' not like '%男的%'
  and q.payload->'transcript'->0->>0 = 'A'
  and q.payload->'transcript'->0->>1 like '%你%'
  and q.payload->'transcript'->1->>0 = 'B';
-- hasil: UPDATE 160

-- ============================================================
-- VERIFIKASI (dijalankan setelah UPDATE) -- query SAMA dengan filter backup di
-- atas, dijalankan ulang. Hasil: NOL BARIS (sebelum update: h1=14, h3=60,
-- h4=34, h5=52 -- total 160, cocok dengan hasil "UPDATE 160").
-- ============================================================
-- select count(*) from question_bank
-- where question_type='listening_mc'
--   and payload->>'question' like '%女的%'
--   and payload->>'question' not like '%男的%'
--   and payload->'transcript'->0->>0 = 'A'
--   and payload->'transcript'->0->>1 like '%你%'
--   and payload->'transcript'->1->>0 = 'B';
-- => 0

-- ============================================================
-- AUDIO -- regenerate 147 file unik via scripts/regen_fixed_audio.py (baca id
-- dari question_bank_bak_20260728, tapi tarik payload TERBARU dari
-- question_bank, render pakai render()/VOICE/RATE/GAP_MS yang di-import
-- LANGSUNG dari audio_pipeline.py biar identik dengan klip tetangga yang
-- tidak ikut diregen, upload ke bucket listening-audio dengan x-upsert=true).
--
-- Hasil run (2026-07-28):
--   160 id di question_bank_bak_20260728 | 160 baris ketemu di question_bank
--   147 file audio unik diproses | 0 di-skip (audio_url/transcript kosong)
--   per level: {1: 14, 3: 60, 4: 34, 5: 39}
--   Total target: 147  Berhasil: 147  Gagal: 0
--
-- Run TANPA --keep, jadi mp3 lokal dihapus otomatis setelah tiap upload sukses
-- -- jejaknya cuma ada di Supabase Storage (bucket listening-audio) prod, tidak
-- ada salinan di audio_out/ lokal.
--
-- ============================================================
-- STATUS
-- ============================================================
-- ✅ APPLIED ke prod 2026-07-28. UPDATE + verifikasi ulang (0 baris) sudah
--    dikonfirmasi. Audio 147/147 sudah diregenerate & diupload, 0 gagal.
--
-- ⏳ PENDING #1: DROP TABLE question_bank_bak_20260728 setelah QA konfirmasi.
--    Tabel ini `select * from question_bank` -- salinan LENGKAP termasuk
--    kolom `answer` (kunci jawaban) untuk 160 soal. Jangan dibiarkan lama --
--    ini bukan tabel yang di-cover RLS policy question_bank yang normal (baca
--    sql/04_rls_snapshot.sql), dan sudah di-grant SELECT ke service_role di
--    atas. Hapus begitu QA (poin di bawah) selesai:
--      drop table public.question_bank_bak_20260728;
--
-- ⏳ PENDING #2: verifikasi DENGAR oleh tim konten -- putar ulang beberapa dari
--    147 klip di app langsung (bukan cuma cek "upload sukses"), terutama yang
--    audio_url-nya dipakai bareng >1 soal. CDN/browser cache bisa bikin klip
--    LAMA (versi 女的) masih kedengeran beberapa jam meski file di Storage
--    sudah ketimpa -- jangan langsung simpulkan "masih salah" tanpa hard
--    refresh / cek versi file di Storage dashboard dulu.
