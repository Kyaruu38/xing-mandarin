-- 23_perbaikan_bank_soal_hsk1-3.sql
-- SUDAH DIJALANKAN KE PROD: 14 Agustus 2026, lewat SQL Editor.
-- File ini ARSIP (biar riwayatnya kebaca di repo), bukan pending action.
--
-- Sumber temuan: QA manual seluruh bank soal HSK 1-3 (70 set, +-2.150 soal)
-- dikerjain satu per satu lewat UI asli, bukan lewat query. Nol kunci jawaban
-- yang salah. Yang di bawah ini masalah lain yang ketemu selama proses itu.

-- =====================================================================
-- (1) 200 dari 300 penjelasan image_mc nunjuk huruf yang SALAH
-- =====================================================================
-- Contoh: audio 「这是超市。」 kuncinya D, penjelasannya nulis "pilih gambar A".
-- Kena di HSK 1 (37), HSK 2 (83), HSK 3 (80).
--
-- Sebelum ditulis ulang, kuncinya sendiri diaudit dulu: dicek apakah kalimat
-- audio memuat kata Mandarin dari gambar yang jadi kunci. 300/300 cocok --
-- jadi yang rusak murni teks penjelasannya.
--
-- Penjelasan digenerate ulang dari (transcript, kunci, nama konsep gambar),
-- jadi hurufnya mustahil meleset lagi. Bentuknya:
--   「这是鱼。」 — yang dimaksud ikan. Jadi pilih gambar A.
--
-- Verifikasi:
--   select count(*) from question_bank
--    where question_type='image_mc'
--      and explanation ~ 'pilih gambar ([A-F])'
--      and substring(explanation from 'pilih gambar ([A-F])') <> (answer->>'correct');
--   -- harus 0

-- =====================================================================
-- (2) Gambar rusak: concepts/chāoshi.jpg (pakai huruf ā bervokal)
-- =====================================================================
-- File-nya memang tidak pernah ada di storage -> murid lihat ikon gambar patah.
-- Parahnya soal 17 set h2-listening-9 (「这是超市。」) kuncinya JUSTRU pilihan itu.
--
-- Gambar 超市 baru dibuat + di-upload sebagai concepts/chaoshi.jpg (nama ASCII),
-- lalu 5 baris payload diarahkan ulang:
--
--   update public.question_bank
--      set payload = replace(payload::text,
--            'concepts/ch'||chr(257)||'oshi.jpg', 'concepts/chaoshi.jpg')::jsonb
--    where payload::text like '%ch'||chr(257)||'oshi%';
--
-- Seluruh bank (HSK 1-6) di-scan: 62 gambar unik + 2.300 file audio,
-- cuma satu ini yang rusak. ATURAN: nama file aset jangan pernah pakai
-- karakter non-ASCII.

-- =====================================================================
-- (3) Jawaban listening HSK 1 & 2 numpuk di satu huruf
-- =====================================================================
-- HSK 2 listening_mc: 150 dari 150 jawabannya A. Pencet A 15x = 43% nilai
--   listening tanpa dengerin apa pun.
-- HSK 1 listening_mc: 34 A / 16 B / 0 C -- opsi C tidak pernah jadi jawaban.
--
-- 200 soal diacak ulang: nilai opsinya dipermutasi antar huruf, kunci +
-- penjelasan ikut digeser. Urutannya diacak (BUKAN dirotasi ABC-ABC, itu
-- bakal jadi celah baru).
--
-- Hasil: HSK 2 = 50/50/50, HSK 1 = 17/17/16.
-- Level 3-6 dicek juga, distribusinya sudah wajar, tidak disentuh.
--
-- Verifikasi:
--   select hsk_level,
--          count(*) filter (where answer->>'correct'='A') as a,
--          count(*) filter (where answer->>'correct'='B') as b,
--          count(*) filter (where answer->>'correct'='C') as c
--     from question_bank
--    where question_type='listening_mc' and section='listening' and hsk_level in (1,2)
--    group by 1;

-- =====================================================================
-- (4) Kunci jawaban bocor ke browser lewat isi kolom payload
-- =====================================================================
-- Kolom `answer` & `explanation` memang sudah tidak di-grant ke murid
-- (lihat 09 & 13). Tapi di DALAM payload masih ikut terkirim:
--   transcript            -> 2.350 soal (teks lengkap audio)
--   question              -> 1.550 soal yang hide_question=true
--   answer_sentence       ->   230 soal writing (kalimat jawabannya)
--
-- Dicek dulu: submit_attempt tidak pernah menyentuh ketiganya, dan kata
-- "transcript" nol kemunculan di app/index.html. answer_sentence cuma dipakai
-- sebagai penanda tipe soal (dicek `!!`, bukan isinya).
--
-- Jadi ketiganya dipindah ke kolom sendiri yang TIDAK di-grant ke murid --
-- tanpa perlu ubah kode app sama sekali:
--
--   alter table public.question_bank
--     add column if not exists transcript jsonb,
--     add column if not exists answer_sentence text,
--     add column if not exists hidden_question text;
--
--   update public.question_bank set transcript = payload->'transcript'
--    where payload ? 'transcript';
--   update public.question_bank set answer_sentence = payload->>'answer_sentence'
--    where payload ? 'answer_sentence';
--   update public.question_bank set hidden_question = payload->>'question'
--    where (payload->>'hide_question')='true' and payload ? 'question';
--
--   update public.question_bank set payload = payload - 'transcript'
--    where payload ? 'transcript';
--   update public.question_bank
--      set payload = jsonb_set(payload,'{answer_sentence}','true'::jsonb)
--    where payload ? 'answer_sentence';   -- sisain penanda, buang isinya
--   update public.question_bank set payload = payload - 'question'
--    where (payload->>'hide_question')='true' and payload ? 'question';
--
-- PENTING buat soal baru: kolom SELECT yang di-grant ke `authenticated` cuma
-- hsk_level,id,order_index,payload,points,question_type,section,set_id.
-- Kolom baru otomatis TIDAK ikut ke-grant -- jangan tambahkan grant-nya.

-- =====================================================================
-- (5) Nomor soal di layar review geser satu
-- =====================================================================
-- Layar review nyetak order_index mentah. 70 set mulai dari 0, 139 set mulai
-- dari 1 -- jadi di set yang mulai dari 0, "Question 12" sebenarnya soal ke-13.
-- (app/index.html baris ~10685 memang sudah mengasumsikan 1-based.)
--
--   with baru as (
--     select id, row_number() over (partition by set_id order by order_index, id) as n
--       from public.question_bank)
--   update public.question_bank q set order_index = b.n
--     from baru b where q.id=b.id and q.order_index <> b.n;
--
-- Sekarang 209/209 set mulai dari 1.

-- =====================================================================
-- (6) Soal susun-kalimat yang punya DUA jawaban sama-sama benar
-- =====================================================================
-- Grader-nya cocok-persis (v_user_ans = r.answer), jadi susunan yang secara
-- grammar benar tapi beda dari kunci tetap dihitung salah. Dibuktikan dengan
-- sengaja menjawab 「我下个月打算去旅游」 di hsk3-writing-2 no.4 -> dinilai salah,
-- padahal itu Mandarin yang benar.
--
-- Diperbaiki dari sisi SOAL, bukan grader: potongan katanya digabung supaya
-- cuma ada satu susunan yang mungkin. Grader tidak disentuh.
--
--   id 453 (hsk3-writing-10 no.1) 我的|新|比|你的|手机
--          -> 我的 | 你的手机 | 新 | 比        (你的手机 jadi satu blok)
--   id 454 (hsk3-writing-10 no.2) 比|跑得|快|我|他
--          -> 比我 | 快 | 他 | 跑得
--   id 456 (hsk3-writing-10 no.4) 我家|很近|离|图书馆
--          -> 离我家 | 很近 | 图书馆
--   id 376 (hsk3-writing-2  no.4) 打算|旅游|去|下个月|我
--          -> 下个月 | 旅游 | 去 | 我打算
--
-- Keempatnya sekaligus dikasih penjelasan grammar beneran (sebelumnya kosong).
--
-- MASIH TERBUKA: pola yang sama ada di HSK 4 (mis. H4XING001 no.13,
-- 「因为工作上需要」 bisa di depan atau di belakang). Belum disentuh karena
-- fokus sesi ini HSK 1-3.

-- =====================================================================
-- (7) 363 soal HSK 1-3 penjelasannya kosong -> kerender jadi tanda strip "-"
-- =====================================================================
-- Pecahannya: sentence_match 95, fill_blank 65, char_input 50, image_match 45,
-- ordering 43, reading_mc 40, image_tf 25.
--
-- Semuanya diisi, digenerate dari data yang memang sudah ada di payload
-- (kalimat + terjemahan + opsi yang benar). Contoh:
--   char_input : Pinyin páng di sini ditulis 「旁」, jadi kalimatnya
--                「银行就在超市（旁）边。」 — "Bank ada di sebelah supermarket."
--   fill_blank : Jawaban B: 喝 (hē). Kalimatnya jadi 「我口渴了，想（喝）水。」 ...
--   image_tf   : Gambarnya segelas air. Pernyataannya 「这是一杯水。」 ...
--
-- Sekarang HSK 1-3 (1.900 soal) nol penjelasan kosong.
--
-- Sisi app-nya ikut ditambal di v5.8: kalau penjelasan memang kosong,
-- barisnya dihilangkan, bukan dirender jadi "-" (lihat blokPenjelasan()).

-- =====================================================================
-- (8) BARU: review_attempt() -- buka lagi pembahasan dari attempt lama
-- =====================================================================
-- Sebelumnya baris di halaman Riwayat cuma div mati: skornya kelihatan tapi
-- pembahasannya tidak bisa dibuka lagi. Satu-satunya cara ya mengulang tesnya,
-- yang justru menimpa riwayat itu sendiri.
--
-- Jawaban lama sudah tersimpan di test_attempts.answers, yang kurang cuma
-- jalan buat menampilkannya balik. submit_attempt SENGAJA TIDAK DIUBAH.
--
-- Fungsi di bawah ini sudah dijalankan ke prod. Ditulis lengkap di sini karena
-- ini objek BARU (beda dari blok 1-7 yang cuma catatan perubahan data).

create or replace function public.review_attempt(p_attempt_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_uid uuid := auth.uid();
  a record;
  v_review jsonb := '[]'::jsonb;
  r record;
  v_user_ans jsonb;
  v_ok boolean;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  -- Filter user_id DI SINI, bukan di klien: id attempt milik orang lain
  -- kena 'attempt not found', bukan cuma disembunyikan di UI.
  select * into a from public.test_attempts
   where id = p_attempt_id and user_id = v_uid;
  if a.id is null then raise exception 'attempt not found'; end if;

  for r in
    select id, order_index, question_type, answer, explanation
    from public.question_bank where set_id = a.set_id order by order_index
  loop
    v_user_ans := a.answers -> r.id::text;
    if r.question_type = 'essay' then
      v_review := v_review || jsonb_build_object(
        'id', r.id, 'order_index', r.order_index, 'question_type', r.question_type,
        'user_answer', v_user_ans, 'correct_answer', null, 'is_correct', null,
        'explanation', r.explanation);
    else
      v_ok := (v_user_ans is not null and v_user_ans = r.answer);
      v_review := v_review || jsonb_build_object(
        'id', r.id, 'order_index', r.order_index, 'question_type', r.question_type,
        'user_answer', v_user_ans, 'correct_answer', r.answer, 'is_correct', v_ok,
        'explanation', r.explanation);
    end if;
  end loop;

  return jsonb_build_object(
    'set_id', a.set_id, 'score', a.score, 'total_points', a.total_points,
    'correct_count', a.correct_count, 'total_questions', a.total_questions,
    'time_taken_seconds', a.time_taken_seconds, 'created_at', a.created_at,
    'review', v_review);
end;
$fn$;

revoke all on function public.review_attempt(bigint) from public;
grant execute on function public.review_attempt(bigint) to authenticated;

-- Sudah diuji dari akun murid beneran:
--   attempt sendiri      -> review lengkap keluar
--   attempt id 155 & 66  -> 'attempt not found' (punya user lain)
