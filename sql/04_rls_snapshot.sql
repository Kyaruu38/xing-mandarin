-- RLS/GRANT/function snapshot -- READ-ONLY DUMP, not a migration.
-- Captured 2026-07-17 by Kyaru via Supabase SQL Editor (Claude has no SQL Editor access --
-- these queries were handed to Kyaru to run, results pasted back). Purpose: Gap #2
-- (DECISIONS_NEEDED #22/#41) server-side package enforcement was about to be designed, but
-- 5 of 6 relevant tables' RLS + 5 helper functions live ONLY in the Supabase Dashboard, never
-- committed here -- this file is that missing source of truth, captured before any policy
-- gets written or changed. See DECISIONS_NEEDED #42 for the findings + execution order this
-- snapshot fed into.
--
-- STATUS: COMPLETE. All 6 queries captured with real data, 2026-07-17.
--
-- Nothing in this file is executable as a unit -- it's a captured record of SELECT query
-- output, reformatted as commented tables for readability, plus the 6 re-runnable queries
-- themselves (each individually valid, safe, read-only) for refreshing this snapshot later.

-- ============================================================
-- 1. RLS POLICIES (pg_policies)
-- ============================================================

-- tablename       | policyname                  | permissive | roles          | cmd    | qual                                                                                                    | with_check
-- ----------------+------------------------------+------------+----------------+--------+---------------------------------------------------------------------------------------------------------+------------
-- profiles        | admin inserts profiles      | PERMISSIVE | {public}       | INSERT | null                                                                                                   | is_admin()
-- profiles        | admin reads all profiles    | PERMISSIVE | {public}       | SELECT | is_admin()                                                                                             | null
-- profiles        | user reads own profile      | PERMISSIVE | {public}       | SELECT | (auth.uid() = id)                                                                                      | null
-- profiles        | admin updates all profiles  | PERMISSIVE | {public}       | UPDATE | is_admin()                                                                                             | is_admin()
-- question_bank   | qbank admin all             | PERMISSIVE | {public}       | ALL    | is_admin()                                                                                             | is_admin()
-- question_bank   | qbank read published        | PERMISSIVE | {public}       | SELECT | (is_admin() OR (EXISTS (SELECT 1 FROM test_sets s WHERE ((s.set_id = question_bank.set_id) AND s.is_published)))) | null
-- test_attempts   | attempts own insert         | PERMISSIVE | {public}       | INSERT | null                                                                                                   | (user_id = auth.uid())
-- test_attempts   | attempts own select         | PERMISSIVE | {public}       | SELECT | ((user_id = auth.uid()) OR is_admin())                                                                | null
-- test_sets       | test_sets admin all         | PERMISSIVE | {public}       | ALL    | is_admin()                                                                                             | is_admin()
-- test_sets       | test_sets read published    | PERMISSIVE | {public}       | SELECT | ((is_published = true) OR is_admin())                                                                 | null
-- user_mastery    | own mastery rw              | PERMISSIVE | {public}       | ALL    | (auth.uid() = user_id)                                                                                 | (auth.uid() = user_id)
-- user_mastery    | admin reads mastery         | PERMISSIVE | {public}       | SELECT | is_admin()                                                                                             | null
-- vocab           | vocab_insert_admin          | PERMISSIVE | {authenticated}| INSERT | null                                                                                                   | is_admin()
-- vocab           | public read vocab           | PERMISSIVE | {public}       | SELECT | true                                                                                                   | null
-- vocab           | vocab_select_authenticated  | PERMISSIVE | {authenticated}| SELECT | true                                                                                                   | null
-- vocab           | vocab_update_admin          | PERMISSIVE | {authenticated}| UPDATE | is_admin()                                                                                             | is_admin()
--
-- KEY FINDING: `vocab` has TWO SELECT policies. `vocab_select_authenticated` is the one in
-- sql/01_vocab_schema.sql (role {authenticated} only). `public read vocab` (role {public},
-- USING true) is NOT in any tracked file -- added directly in the Dashboard at some point.
-- {public} in Postgres is the implicit pseudo-role every role (including anon) is a member
-- of, so this second policy is exactly why anon can SELECT vocab despite
-- sql/01_vocab_schema.sql's comment claiming "role anon TIDAK di-GRANT apa pun".
--
-- test_sets/question_bank read policies gate ONLY on is_published (+ is_admin()) -- zero
-- reference to hsk_level, package, or any per-user column. Matches the empirically-proven
-- leak (authenticated user of any package can read all 150 test_sets rows / any
-- question_bank set's non-answer columns, regardless of level).
--
-- user_mastery / test_attempts are correctly row-isolated to auth.uid() = user_id (plus a
-- separate admin-read policy) -- previously UNVERIFIED (disposable test account had zero
-- rows), now confirmed correct at the policy-definition level.
--
-- profiles has no "user updates own profile" policy -- INSERT/UPDATE are both admin-only,
-- SELECT is own-row-or-admin. Consistent with there being no self-service profile-edit
-- feature anywhere in index.html today; not a gap unless that feature gets built later.

-- Query 1 (re-runnable, plain valid SQL, safe/read-only):
SELECT tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('vocab','test_sets','question_bank','test_attempts','profiles','user_mastery')
ORDER BY tablename, cmd, policyname;


-- ============================================================
-- 2. TABLE-LEVEL GRANTS (information_schema.role_table_grants)
-- ============================================================
-- REFERENCES/TRIGGER/TRUNCATE on every row below are Postgres default grants that come with
-- table ownership/creation context, not meaningful app-level access -- the columns that
-- matter are SELECT/INSERT/UPDATE/DELETE.

-- table_name     | grantee        | privilege_type
-- ----------------+----------------+----------------
-- profiles        | anon           | REFERENCES, TRIGGER, TRUNCATE
-- profiles        | authenticated  | INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- profiles        | postgres       | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- profiles        | service_role   | INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- question_bank   | anon           | REFERENCES, TRIGGER, TRUNCATE
-- question_bank   | authenticated  | REFERENCES, TRIGGER, TRUNCATE   -- (SELECT is column-level, see section 4 -- not a table-level grant)
-- question_bank   | postgres       | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- question_bank   | service_role   | REFERENCES, SELECT, TRIGGER, TRUNCATE
-- test_attempts   | anon           | REFERENCES, TRIGGER, TRUNCATE
-- test_attempts   | authenticated  | INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE
-- test_attempts   | postgres       | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- test_attempts   | service_role   | REFERENCES, TRIGGER, TRUNCATE   -- NO SELECT
-- test_sets       | anon           | REFERENCES, TRIGGER, TRUNCATE
-- test_sets       | authenticated  | REFERENCES, SELECT, TRIGGER, TRUNCATE
-- test_sets       | postgres       | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- test_sets       | service_role   | REFERENCES, SELECT, TRIGGER, TRUNCATE
-- user_mastery    | anon           | REFERENCES, TRIGGER, TRUNCATE
-- user_mastery    | authenticated  | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- user_mastery    | postgres       | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- user_mastery    | service_role   | REFERENCES, TRIGGER, TRUNCATE   -- NO SELECT
--
-- (vocab broken out separately in section 2b, full detail.)
--
-- KEY FINDING (`service_role` grant gaps -- see DECISIONS_NEEDED #42 finding 10, corrected):
-- `service_role` is missing SELECT entirely on test_attempts, user_mastery, AND vocab (see
-- 2b) -- not just vocab as first reported. It's also missing INSERT/UPDATE/DELETE on
-- question_bank and test_sets (read-only there). The ONLY table where service_role has a full
-- working grant set is `profiles` -- which is exactly the table DECISIONS_NEEDED #34 (session
-- 7) manually GRANT-fixed after the admin-users Edge Function hit "permission denied for
-- table profiles". That fix was never extended to the other 5 tables; all 5 are still in the
-- same REFERENCES/TRIGGER/TRUNCATE-only (or SELECT-only) state profiles was in before #34.
-- Any future service_role-based Edge Function touching those tables will hit the identical
-- wall #34 already diagnosed once.
--
-- `authenticated` on question_bank shows NO SELECT at this table-level view -- this is
-- expected, not a bug: its SELECT access is granted at the COLUMN level instead (section 4),
-- and information_schema.role_table_grants only reports whole-table grants, not partial
-- column-level ones.

-- Query 2 (re-runnable, plain valid SQL, safe/read-only):
SELECT table_name, grantee, privilege_type, is_grantable
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN ('vocab','test_sets','question_bank','test_attempts','profiles','user_mastery')
  AND grantee IN ('anon','authenticated','service_role')
ORDER BY table_name, grantee, privilege_type;


-- ============================================================
-- 2b. VOCAB GRANTS, FULL DETAIL (all grantees)
-- ============================================================

-- grantee        | privilege_type
-- ----------------+----------------
-- anon            | REFERENCES, SELECT, TRIGGER, TRUNCATE
-- authenticated   | INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- postgres        | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- service_role    | REFERENCES, TRIGGER, TRUNCATE   -- NO SELECT, NO INSERT, NO UPDATE, NO DELETE
--
-- Confirms the anon-SELECT drift at the grant level (matches the "public read vocab" policy
-- in section 1) and confirms service_role's vocab gap precisely: zero CRUD access at all,
-- same class as test_attempts/user_mastery above -- not an isolated vocab-only anomaly.

-- Query 2b (re-runnable, plain valid SQL, safe/read-only):
SELECT grantee, privilege_type, is_grantable
FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND table_name = 'vocab'
ORDER BY grantee, privilege_type;


-- ============================================================
-- 3. RLS ENABLED STATUS (pg_class)
-- ============================================================

-- table_name     | rls_enabled | rls_forced
-- ----------------+-------------+------------
-- profiles       | true        | false
-- question_bank  | true        | false
-- test_attempts  | true        | false
-- test_sets      | true        | false
-- user_mastery   | true        | false
-- vocab          | true        | false
--
-- All 6 tables have RLS enabled, none FORCED (rls_forced=false is the Supabase default --
-- table owner/superuser roles still bypass RLS on their own reads even with RLS "enabled").
-- This is standard, not itself a finding -- but it's the mechanism that lets a
-- SECURITY DEFINER function owned by a bypass-privileged role read past RLS entirely,
-- relevant background for the submit_attempt finding in section 6.

-- Query 3 (re-runnable, plain valid SQL, safe/read-only):
SELECT c.relname AS table_name, c.relrowsecurity AS rls_enabled, c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('vocab','test_sets','question_bank','test_attempts','profiles','user_mastery')
ORDER BY c.relname;


-- ============================================================
-- 4. COLUMN-LEVEL PRIVILEGES, question_bank
-- ============================================================

-- grantee        | SELECT columns granted                                                          | SELECT columns NOT granted (REFERENCES only)
-- ----------------+----------------------------------------------------------------------------------+-----------------------------------------------
-- anon            | (none)                                                                            | all 11 columns (REFERENCES only, matches 401 on anon)
-- authenticated   | hsk_level, id, order_index, payload, points, question_type, section, set_id (8)  | answer, explanation, created_at
-- postgres        | all 11 columns (full CRUD)                                                        | --
-- service_role    | all 11 columns (SELECT only)                                                      | --
--
-- CONFIRMS the empirically-observed 403 (error=42501) on a direct REST SELECT of
-- answer/explanation by an authenticated non-admin user: this is a genuine, deliberate
-- column-level GRANT (SELECT granted on a specific column list that excludes answer/
-- explanation/created_at for `authenticated`), not a REVOKE carved out of a broader
-- table-level grant, and not a client-side omission. This protection is real and correctly
-- configured -- the only way past it is submit_attempt's SECURITY DEFINER bypass (section 6).

-- Query 4 (re-runnable, plain valid SQL, safe/read-only):
SELECT table_name, column_name, grantee, privilege_type
FROM information_schema.column_privileges
WHERE table_schema = 'public'
  AND table_name = 'question_bank'
ORDER BY column_name, grantee;


-- ============================================================
-- 5. FUNCTION LIST + SECURITY DEFINER FLAG (pg_proc)
-- ============================================================

-- function_name    | security_definer | args
-- ------------------+-------------------+----------------------------------------------
-- claim_session     | true              | p_session_id uuid, p_device_label text
-- handle_new_user   | true              | (none)
-- is_admin          | true              | (none)
-- rls_auto_enable   | true              | (none)
-- submit_attempt    | true              | p_set_id text, p_answers jsonb, p_time_taken integer
--
-- ALL 5 functions in the public schema are SECURITY DEFINER. Full source for all 5 in
-- section 6.

-- Query 5 (re-runnable, plain valid SQL, safe/read-only):
SELECT p.proname AS function_name, p.prosecdef AS security_definer, pg_get_function_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
ORDER BY p.proname;


-- ============================================================
-- 6. FULL FUNCTION SOURCE (pg_get_functiondef) -- captured live, 2026-07-17
-- ============================================================

-- --- is_admin() ---
-- CREATE OR REPLACE FUNCTION public.is_admin()
--  RETURNS boolean
--  LANGUAGE sql
--  STABLE SECURITY DEFINER
--  SET search_path TO 'public'
-- AS $function$
--   select exists (
--     select 1 from public.profiles
--     where id = auth.uid() and role = 'admin'
--   );
-- $function$
--
-- Simple own-caller role check, SECURITY DEFINER + STABLE. Matches every observed usage
-- (vocab_insert_admin, qbank/test_sets/profiles/user_mastery admin policies, admin-users
-- Edge Function). No surprises.

-- --- claim_session(p_session_id uuid, p_device_label text) ---
-- CREATE OR REPLACE FUNCTION public.claim_session(p_session_id uuid, p_device_label text)
--  RETURNS void
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO 'public'
-- AS $function$
-- begin
--   update public.profiles
--   set active_session_id = p_session_id,
--       device_label      = p_device_label,
--       last_seen         = now()
--   where id = auth.uid();
-- end;
-- $function$
--
-- Scoped to auth.uid()'s own row only (WHERE id = auth.uid()) -- no cross-user write surface.
-- No surprises, matches single-device session enforcement (DECISIONS_NEEDED #33) usage.

-- --- handle_new_user() ---
-- CREATE OR REPLACE FUNCTION public.handle_new_user()
--  RETURNS trigger
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO 'public'
-- AS $function$
-- begin
--   insert into public.profiles (id, display_name)
--   values (new.id, new.raw_user_meta_data->>'display_name');
--   return new;
-- end;
-- $function$
--
-- Auth trigger (on auth.users insert). Only sets id + display_name -- package, role, status,
-- subscription_end, target_level are ALL left to their column defaults (not visible in this
-- function; the profiles table DDL itself isn't tracked in this repo either). Confirms
-- DECISIONS_NEEDED #42 finding 9: profiles.package is NULL for a newly-created user by
-- construction, not by omission in some other code path -- this is the one and only place a
-- profiles row gets created, and it never touches package at all.

-- --- rls_auto_enable() ---
-- CREATE OR REPLACE FUNCTION public.rls_auto_enable()
--  RETURNS event_trigger
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO 'pg_catalog'
-- AS $function$
-- DECLARE
--   cmd record;
-- BEGIN
--   FOR cmd IN
--     SELECT *
--     FROM pg_event_trigger_ddl_commands()
--     WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
--       AND object_type IN ('table','partitioned table')
--   LOOP
--      IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
--       BEGIN
--         EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
--         RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
--       EXCEPTION
--         WHEN OTHERS THEN
--           RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
--       END;
--      ELSE
--         RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
--      END IF;
--   END LOOP;
-- END;
-- $function$
--
-- Event trigger on CREATE TABLE. Any new table created in schema `public` gets
-- `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` run against it automatically -- and ONLY that;
-- this function never adds any policy. Confirms DECISIONS_NEEDED #42 finding 8 exactly: a
-- future `package_levels` table (candidate fix for #41 finding 3, PACKAGE_LEVELS having no DB
-- representation) would come up RLS-enabled with zero policies = default-deny-everything,
-- including to the app's own `authenticated` reads, the moment it's created. A read policy
-- for `authenticated` must be added in the SAME migration/session that creates the table, not
-- as a follow-up step.

-- --- submit_attempt(p_set_id text, p_answers jsonb, p_time_taken integer) ---
-- CREATE OR REPLACE FUNCTION public.submit_attempt(p_set_id text, p_answers jsonb, p_time_taken integer)
--  RETURNS jsonb
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO 'public'
-- AS $function$
-- declare
--   v_uid uuid := auth.uid();
--   v_score int := 0;
--   v_total_points int := 0;
--   v_correct int := 0;
--   v_total int := 0;
--   v_review jsonb := '[]'::jsonb;
--   r record;
--   v_user_ans jsonb;
--   v_ok boolean;
-- begin
--   if v_uid is null then raise exception 'not authenticated'; end if;
--   for r in
--     select id, order_index, question_type, answer, explanation, points
--     from public.question_bank
--     where set_id = p_set_id
--     order by order_index
--   loop
--     -- Soal essay dinilai oleh AI (grade-essay), bukan key-matching -> skip dari skor objektif
--     if r.question_type = 'essay' then
--       v_review := v_review || jsonb_build_object(
--         'id', r.id, 'order_index', r.order_index, 'question_type', r.question_type,
--         'user_answer', p_answers -> r.id::text,
--         'correct_answer', null, 'is_correct', null, 'explanation', r.explanation
--       );
--       continue;
--     end if;
--     v_total := v_total + 1;
--     v_total_points := v_total_points + r.points;
--     v_user_ans := p_answers -> r.id::text;
--     v_ok := (v_user_ans is not null and v_user_ans = r.answer);
--     if v_ok then
--       v_score := v_score + r.points;
--       v_correct := v_correct + 1;
--     end if;
--     v_review := v_review || jsonb_build_object(
--       'id', r.id, 'order_index', r.order_index, 'question_type', r.question_type,
--       'user_answer', v_user_ans, 'correct_answer', r.answer, 'is_correct', v_ok,
--       'explanation', r.explanation
--     );
--   end loop;
--   insert into public.test_attempts(
--     user_id, set_id, hsk_level, section, score, total_points,
--     correct_count, total_questions, answers, time_taken_seconds, finished_at)
--   select v_uid, p_set_id, s.hsk_level, s.section, v_score, v_total_points,
--          v_correct, v_total, p_answers, p_time_taken, now()
--   from public.test_sets s where s.set_id = p_set_id;
--   return jsonb_build_object(
--     'score', v_score, 'total_points', v_total_points, 'correct_count', v_correct,
--     'total_questions', v_total, 'review', v_review
--   );
-- end;
-- $function$
--
-- CONFIRMED 1:1 finding (DECISIONS_NEEDED #42 finding 7, upgraded from "repo cross-reference"
-- to "confirmed live dump"): every non-essay question's real `answer`/`explanation` is placed
-- straight into `v_review`, returned in the RPC's JSON response to WHATEVER `p_set_id` the
-- caller passes -- zero package/level check anywhere in this function body. Combined with
-- SECURITY DEFINER (section 5) and RLS not FORCED (section 3), this bypasses the correctly-
-- configured column-level protection in section 4 entirely. Any authenticated user (any
-- package, including their own paid tier) can harvest the real answer key for any set_id by
-- calling this RPC directly with dummy answers -- no UI path, no RLS gap on question_bank
-- itself, needed.
--
-- DRIFT FOUND vs the tracked repo file (sql/03_submit_attempt_essay.sql): the live function's
-- `v_total` (-> `total_questions` in the API response and the `test_attempts` row) is
-- incremented ONLY for non-essay rows (the essay branch hits `continue` before reaching
-- `v_total := v_total + 1`). The TRACKED file increments `v_total` unconditionally for EVERY
-- row before branching on question_type, and its own comment says so explicitly ("soal essay
-- tetap dihitung di total_questions (biar progress "soal ke-N dari total" tetap benar)"). The
-- live behavior currently contradicts that stated intent -- for a writing section that is
-- 100% essay questions (HSK3+ writing, per DECISIONS_NEEDED #9 prereq 3), `total_questions`
-- comes back as 0 in that section's `submit_attempt` result and the persisted
-- `test_attempts` row, not the real question count. This is a live, currently-active
-- correctness bug independent of Gap #2's security scope -- surfaced as a byproduct of this
-- dump, logged here since it's exactly the kind of drift this exercise exists to catch. Not
-- triaged/fixed -- flagged for its own decision.

-- Query 6 (re-runnable, plain valid SQL, safe/read-only):
SELECT p.proname AS function_name, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('is_admin','claim_session','submit_attempt','handle_new_user','rls_auto_enable')
ORDER BY p.proname;
