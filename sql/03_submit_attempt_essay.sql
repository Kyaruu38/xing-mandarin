-- Patch submit_attempt: soal question_type='essay' TIDAK dinilai lewat key-matching
-- (answer/explanation-nya nggak dipakai/nggak ada -- dinilai lewat Edge Function
-- grade-essay dan disimpan terpisah di essay_submissions).
--
-- Sebelum patch ini, soal essay ikut masuk hitungan total_points/correct_count
-- di loop scoring, jadi selalu keitung "salah" (v_ok jadi false/null karena
-- r.answer kosong) -- itu ngerusak skor objektif buat set yang isinya essay.
--
-- Setelah patch: soal essay tetap dihitung di total_questions (biar progress
-- "soal ke-N dari total" tetap benar), tapi TIDAK menyumbang ke total_points
-- atau correct_count, dan review item-nya dapet is_correct = null (bukan false)
-- supaya nggak salah kebaca "salah" di analitik/raport nanti.
--
-- Aman dijalankan ulang (CREATE OR REPLACE). Logika scoring untuk
-- reading_mc/fill_blank/sentence_match/ordering TIDAK diubah.

CREATE OR REPLACE FUNCTION public.submit_attempt(p_set_id text, p_answers jsonb, p_time_taken integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
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

  for r in
    select id, order_index, question_type, answer, explanation, points
    from public.question_bank
    where set_id = p_set_id
    order by order_index
  loop
    v_user_ans := p_answers -> r.id::text;
    v_total := v_total + 1;

    if r.question_type = 'essay' then
      -- Dinilai AI lewat grade-essay, bukan di sini. Nggak masuk total_points/correct_count.
      v_review := v_review || jsonb_build_object(
        'id', r.id,
        'order_index', r.order_index,
        'question_type', r.question_type,
        'user_answer', v_user_ans,
        'correct_answer', null,
        'is_correct', null,
        'explanation', r.explanation
      );
    else
      v_total_points := v_total_points + r.points;
      v_ok := (v_user_ans is not null and v_user_ans = r.answer);
      if v_ok then
        v_score := v_score + r.points;
        v_correct := v_correct + 1;
      end if;
      v_review := v_review || jsonb_build_object(
        'id', r.id,
        'order_index', r.order_index,
        'question_type', r.question_type,
        'user_answer', v_user_ans,
        'correct_answer', r.answer,
        'is_correct', v_ok,
        'explanation', r.explanation
      );
    end if;
  end loop;

  insert into public.test_attempts(
    user_id, set_id, hsk_level, section, score, total_points,
    correct_count, total_questions, answers, time_taken_seconds, finished_at)
  select v_uid, p_set_id, s.hsk_level, s.section, v_score, v_total_points,
         v_correct, v_total, p_answers, p_time_taken, now()
  from public.test_sets s where s.set_id = p_set_id;

  return jsonb_build_object(
    'score', v_score,
    'total_points', v_total_points,
    'correct_count', v_correct,
    'total_questions', v_total,
    'review', v_review
  );
end;
$function$;
