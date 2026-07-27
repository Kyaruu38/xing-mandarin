-- Applied to prod: 2026-07-27
-- Fix: submit_attempt bocorin answer+explanation semua soal
--      ke user manapun tanpa cek entitlement.
-- Gate mirror PACKAGE_LEVELS + gateReason() di frontend.
-- Sisa (belum ditambal): user masih bisa narik correct_answer
--    dalam paket sendiri dengan submit p_answers kosong.
--
-- Sumber: bukan hasil query live (Claude tidak punya akses SQL Editor, lihat
-- sql/04_rls_snapshot.sql). Basis fungsi diambil dari snapshot live terakhir
-- (dicapture 2026-07-17, section 6 file itu) -- kalau definisi di prod sudah
-- berubah sejak itu, tolong tempel versi aktual sebelum menjalankan file ini.
--
-- Entitlement yang ditambahkan MENIRU PERSIS 2 lapis gating yang sudah ada di
-- app/index.html supaya tidak ada logic baru yang bisa divergen dari frontend:
--   1. gateReason(profile) -- admin selalu lolos; status='expired' -> tolak;
--      subscription_end < hari ini -> tolak.
--   2. PACKAGE_LEVELS -- profiles.package menentukan level HSK maksimum yang
--      boleh diakses (hsk_1_4=1..4, hsk_5=1..5, hsk_6/vip=1..6,
--      business/convo=tidak ada level sama sekali). package NULL/tidak
--      dikenal fallback ke hsk_1_4, sama seperti userPackageLevels fallback
--      di frontend (baris ~2139 app/index.html).
--
-- Efek: kalau set_id yang diminta levelnya di luar entitlement caller, fungsi
-- RAISE EXCEPTION sebelum sempat query question_bank -- jadi answer/explanation
-- tidak pernah lolos ke response, bukan cuma disembunyikan di UI.

CREATE OR REPLACE FUNCTION public.submit_attempt(p_set_id text, p_answers jsonb, p_time_taken integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_status text;
  v_sub_end date;
  v_package text;
  v_max_level int;
  v_set_level int;
  v_score int := 0;
  v_total_points int := 0;
  v_correct int := 0;
  v_total int := 0;
  v_review jsonb := '[]'::jsonb;
  r record;
  v_user_ans jsonb;
  v_ok boolean;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select role, status, subscription_end, package
    into v_role, v_status, v_sub_end, v_package
  from public.profiles
  where id = v_uid;

  -- Lapis 1: gate langganan -- mirror gateReason() di app/index.html. Admin selalu lolos.
  if v_role is distinct from 'admin' then
    if v_status = 'expired' then
      raise exception 'subscription expired';
    end if;
    if v_sub_end is not null and v_sub_end < (now() at time zone 'Asia/Jakarta')::date then
      raise exception 'subscription past due';
    end if;

    -- Lapis 2: gate level per package -- mirror PACKAGE_LEVELS. package NULL/tidak
    -- dikenal fallback ke hsk_1_4 (sama seperti frontend, bukan default deny).
    v_max_level := case v_package
      when 'hsk_1_4' then 4
      when 'hsk_5'   then 5
      when 'hsk_6'   then 6
      when 'vip'     then 6
      when 'business' then 0
      when 'convo'    then 0
      else 4  -- fallback hsk_1_4, mirror `PACKAGE_LEVELS[profile.package] || PACKAGE_LEVELS.hsk_1_4`
    end;

    select hsk_level into v_set_level from public.test_sets where set_id = p_set_id;
    if v_set_level is null then
      raise exception 'set not found';
    end if;
    if v_max_level = 0 or v_set_level > v_max_level then
      raise exception 'level not included in package';
    end if;
  end if;

  for r in
    select id, order_index, question_type, answer, explanation, points
    from public.question_bank
    where set_id = p_set_id
    order by order_index
  loop
    -- Soal essay dinilai oleh AI (grade-essay), bukan key-matching -> skip dari skor objektif
    if r.question_type = 'essay' then
      v_review := v_review || jsonb_build_object(
        'id', r.id, 'order_index', r.order_index, 'question_type', r.question_type,
        'user_answer', p_answers -> r.id::text,
        'correct_answer', null, 'is_correct', null, 'explanation', r.explanation
      );
      continue;
    end if;
    v_total := v_total + 1;
    v_total_points := v_total_points + r.points;
    v_user_ans := p_answers -> r.id::text;
    v_ok := (v_user_ans is not null and v_user_ans = r.answer);
    if v_ok then
      v_score := v_score + r.points;
      v_correct := v_correct + 1;
    end if;
    v_review := v_review || jsonb_build_object(
      'id', r.id, 'order_index', r.order_index, 'question_type', r.question_type,
      'user_answer', v_user_ans, 'correct_answer', r.answer, 'is_correct', v_ok,
      'explanation', r.explanation
    );
  end loop;
  insert into public.test_attempts(
    user_id, set_id, hsk_level, section, score, total_points,
    correct_count, total_questions, answers, time_taken_seconds, finished_at)
  select v_uid, p_set_id, s.hsk_level, s.section, v_score, v_total_points,
         v_correct, v_total, p_answers, p_time_taken, now()
  from public.test_sets s where s.set_id = p_set_id;
  return jsonb_build_object(
    'score', v_score, 'total_points', v_total_points, 'correct_count', v_correct,
    'total_questions', v_total, 'review', v_review
  );
end;
$function$;

-- Execute grant -- fungsi ini SECURITY DEFINER, jadi eksplisit batasi siapa yang boleh
-- panggil (bukan andalkan default Postgres yang bisa beda-beda tergantung riwayat GRANT).
REVOKE ALL ON FUNCTION public.submit_attempt(text, jsonb, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_attempt(text, jsonb, integer) TO authenticated;
