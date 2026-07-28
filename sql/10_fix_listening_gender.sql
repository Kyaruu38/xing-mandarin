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

-- ============================================================
-- BATCH 2 -- QA KONTEN TIM XING, 2026-07-28
-- ============================================================
-- Semua di bawah ini SUDAH di-apply & diverifikasi ke prod oleh user.

-- (a) Reading H1XING010, order 7-10 -- ganti 这个 jadi nama benda konkret +
-- perbaikan lain. Untuk order 9, DIVERIFIKASI dulu gambar kunci jawaban
-- cocok dengan kata benda barunya sebelum apply: usulan awal tim tulis
-- 米饭 (nasi), TAPI gambar kunci jawaban C adalah MI -- jadi yang dipakai
-- 面条 (mi), BUKAN 米饭. Kalau paksa pakai usulan awal (米饭), murid yang
-- jawab benar (pilih gambar mi) justru dinilai salah.
update question_bank set payload = payload
  || jsonb_build_object('prompt','我看书学汉语。',
                        'prompt_id','Aku belajar bahasa Mandarin dengan buku.')
where set_id='H1XING010' and order_index=7;

update question_bank set payload = payload
  || jsonb_build_object('prompt','我生病了，要吃药。',
                        'prompt_id','Aku sakit, harus minum obat.')
where set_id='H1XING010' and order_index=8;

update question_bank set payload = payload
  || jsonb_build_object('prompt','中午我吃了一碗面条。',
                        'prompt_id','Siang tadi aku makan semangkuk mi.')
where set_id='H1XING010' and order_index=9;

update question_bank set payload = payload
  || jsonb_build_object('prompt','晚上我在家看电视。',
                        'prompt_id','Malam aku nonton TV di rumah.')
where set_id='H1XING010' and order_index=10;

-- (b) H1XING010 order 14 -- soal lama pakai 去 tapi kunci jawaban 在北京
-- (nyambungnya ke "berada di", bukan "pergi ke"). Diperbaiki dari SISI
-- SOAL (prompt), bukan opsi jawaban -- karena array choices di order 14
-- ini DIPAKAI BERSAMA oleh order 11 (kalau opsi yang diubah, order 11 ikut
-- kena, itu di luar scope QA ini).
update question_bank set payload = payload
  || jsonb_build_object('prompt','你在哪儿工作？')
where set_id='H1XING010' and order_index=14;

-- (c) H1XING008 order 10 -- 天冷了 -> 天气冷了 (冷 butuh subjek 天气,
-- bukan 天 -- 天冷了 secara gramatikal janggal buat HSK1).
update question_bank set payload = payload
  || jsonb_build_object('prompt','天气冷了，我穿这个。')
where set_id='H1XING008' and order_index=10;

-- (d) Listening 来/去, set h1-listening-3 & h1-listening-7 order 17:
-- speaker A tanya "明天你来吗？" ke B, B jawab "我来。" -- salah
-- perspektif, sebab B yang BERGERAK ke tempat A (harusnya 去 dari sudut
-- pandang B), bukan 来. Pertanyaan & pilihan jawaban TETAP pakai 来
-- (sudut pandang narator/A tidak diubah, sesuai pola soal HSK asli) --
-- yang diperbaiki CUMA baris jawaban B di transcript, kunci jawaban
-- (answer) TIDAK berubah.
update question_bank
set payload = jsonb_set(payload, '{transcript,1,1}', '"我去。"'::jsonb)
where set_id in ('h1-listening-3','h1-listening-7') and order_index=17;

-- AUDIO: 2 baris (d) ditambahkan ke question_bank_bak_20260728, lalu
-- diregenerate bareng lewat scripts/regen_fixed_audio.py. Run terakhir:
-- 149/149 berhasil, 0 gagal (147 sisa dari batch gender + 2 dari 来/去).
--
-- CATATAN PENTING soal tabel backup: question_bank_bak_20260728 sekarang
-- isinya CAMPUR -- 160 baris batch gender (bagian atas file ini) + 2 baris
-- 来/去 (poin d) = 162 baris. Tabel ini dipakai scripts/regen_fixed_audio.py
-- sebagai DAFTAR TARGET (sumber id buat query "apa yang perlu diregenerate"),
-- BUKAN sekadar snapshot backup pasif -- PENDING #1 di bagian batch gender
-- di atas ("drop table setelah QA batch gender selesai") perlu ditinjau
-- ulang: jangan drop tabel ini sampai SEMUA batch yang masih bergantung
-- padanya (termasuk batch 2 ini) selesai diverifikasi.

-- ============================================================
-- YANG TIDAK DIKERJAKAN + ALASANNYA
-- ============================================================
-- - Usulan tim "这个给你的" untuk H1XING010 order 11: TIDAK diterapkan.
--   Kalimat yang sekarang, 这是给你的。, sudah gramatikal. Usulan tim
--   kurang 是 -- kalau mau versi "这个", yang benar 这个是给你的。
-- - H1XING003 order 24, keluhan "tidak ada gambar": dicek, gambarnya ADA
--   (payload.image_svg, bulan sabit) dan renderer image_tf punya fallback
--   ke image_svg kalau image_url kosong (app/index.html:7690). Kemungkinan
--   SVG-nya kurang jelas/kecil, bukan hilang. Perlu screenshot dari tim
--   buat pastikan sebelum diputuskan ini bug atau bukan.
-- - Semua keluhan GAMBAR (打电话 vs 玩手机, "他们" digambar 2 orang,
--   gambar E/F ambigu, D sama persis dengan F, baju digambar bukan
--   jaket): BELUM dikerjakan. SVG inline di payload, dan beberapa gambar
--   dipakai lintas set (ubah 1 gambar bisa kena beberapa soal sekaligus,
--   sama kayak isu choices di poin (b) di atas) -- butuh audit terpisah,
--   batch tersendiri.
