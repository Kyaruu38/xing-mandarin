-- Gap #2 step 2 (DECISIONS_NEEDED #42/#43) -- ONE fix to submit_attempt: is_published check.
-- Based on the LIVE deployed function body (sql/04_rls_snapshot.sql section 6, captured via
-- pg_get_functiondef 2026-07-17), NOT the older sql/03_submit_attempt_essay.sql -- that
-- tracked file had already drifted from what's actually live, so this patch starts from the
-- confirmed-live source rather than risk resurrecting an unknown second drift.
--
-- Fix -- is_published check (new): submit_attempt never checked test_sets.is_published at
-- all, unlike the RLS policies that gate direct reads on it ("qbank read published" / "test_sets
-- read published", sql/04_rls_snapshot.sql section 1). A p_set_id for an unpublished/draft set
-- could be submitted and its answer key harvested through this RPC regardless. Zero behavior
-- change for any set a real student can currently reach -- loadMockList() in index.html already
-- filters .eq('is_published', true), so every set students see is_published already.
--
-- ============================================================================
-- DO NOT "FIX" THE ESSAY total_questions COUNTING -- READ THIS BEFORE TOUCHING IT AGAIN.
-- ============================================================================
-- DECISIONS_NEEDED #42 finding 11 originally flagged that the live function's essay branch
-- hits `continue` before `v_total := v_total + 1` runs, so essay questions are excluded from
-- `total_questions`. This LOOKS like a counting bug (and sql/03_submit_attempt_essay.sql's own
-- comment claims essay "tetap dihitung di total_questions" -- it doesn't, live). It was
-- INVESTIGATED and REJECTED as a fix (DECISIONS_NEEDED #43 correction) -- do not re-add
-- `v_total := v_total + 1` to the essay branch without re-deriving this from scratch:
--
-- Every consumer of total_questions in index.html that computes a percentage pairs it with
-- correct_count (showResult()'s resScore/resCorrect ~line 4851-4854, the combined-attempt
-- Accuracy stat ~line 4918-4920, per-section breakdown percent ~line 4954) -- and correct_count
-- can NEVER include essay rows (essay's is_correct is always null, v_correct is never
-- incremented for question_type='essay', by design -- essays are graded separately by the
-- grade-essay AI Edge Function, not by key-matching here). If total_questions counted essay
-- rows while correct_count structurally cannot, a MIXED section (some objective questions +
-- some essay -- e.g. HSK5 writing = 完成句子 + 2 essay questions) would show a percentage that
-- can never reach 100% even when every gradable question is answered correctly (concrete
-- example verified: 8 objective questions all correct + 2 essay = correct_count/total_questions
-- = 8/10 = 80%, when the real objective accuracy is 8/8 = 100%). That's not a rounding
-- quirk, it's a straight-up wrong number shown to a paying user on their own result screen.
--
-- The "isEssaySection"/"isAllEssay" pending-state branch (DECISIONS_NEEDED #17,
-- index.html ~line 4753: `setQuestions.every(q => q.question_type === 'essay')`) only catches
-- sections that are 100% essay -- it does NOT catch mixed sections, so mixed sections go
-- straight through the normal percentage formula above and would take the hit directly.
--
-- The comment in sql/03_submit_attempt_essay.sql justifying "essay counted in total_questions"
-- (for progress display "soal ke-N dari total") does not describe any real, live need: the
-- in-progress "question N of M" indicator while an attempt is active is computed client-side
-- from `attemptQuestions.length` (index.html ~line 4364), never from test_attempts'
-- total_questions -- and the static "N soal" label on Mock List cards reads test_sets.total_
-- questions (a different column on a different table, same name by coincidence), also
-- unrelated. Nothing anywhere needs total_questions to include essay rows.
--
-- VERDICT: total_questions' real, in-use semantics across this whole app is "count of
-- objectively-gradable questions" (the percentage denominator paired with correct_count), NOT
-- "count of all questions in the set" -- the live behavior (excluding essay) is CORRECT. The
-- bug was sql/03's comment describing an intent that, if actually implemented, breaks the #9
-- scoring formula for every mixed objective+essay section. Do not implement it.
--
-- Safe to run standalone (CREATE OR REPLACE). No schema/table changes, no RLS changes, no
-- other function touched, no essay/total_questions counting change.

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
  v_published boolean;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  -- Fix: reject any set_id that isn't a real, published test_sets row. Previously this
  -- function did not check is_published at all.
  select is_published into v_published
  from public.test_sets
  where set_id = p_set_id;

  if v_published is not true then
    raise exception 'set not found or not published';
  end if;

  for r in
    select id, order_index, question_type, answer, explanation, points
    from public.question_bank
    where set_id = p_set_id
    order by order_index
  loop
    -- Soal essay dinilai oleh AI (grade-essay), bukan key-matching -> skip dari skor objektif.
    -- v_total SENGAJA tidak di-increment di sini -- lihat blok komentar besar di atas file ini
    -- sebelum "membenerkan" ini lagi.
    if r.question_type = 'essay' then
      v_review := v_review || jsonb_build_object(
        'id', r.id,
        'order_index', r.order_index,
        'question_type', r.question_type,
        'user_answer', p_answers -> r.id::text,
        'correct_answer', null,
        'is_correct', null,
        'explanation', r.explanation
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
      'id', r.id,
      'order_index', r.order_index,
      'question_type', r.question_type,
      'user_answer', v_user_ans,
      'correct_answer', r.answer,
      'is_correct', v_ok,
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
    'score', v_score,
    'total_points', v_total_points,
    'correct_count', v_correct,
    'total_questions', v_total,
    'review', v_review
  );
end;
$function$;
