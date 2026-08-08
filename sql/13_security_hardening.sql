-- ============================================================================
-- 13_security_hardening.sql
-- Menutup kebocoran konten berbayar & penulisan skor palsu.
--
-- LATAR BELAKANG
-- Snapshot sql/04_rls_snapshot.sql sendiri sudah mencatat masalah ini
-- (lihat "KEY FINDING" di file itu). Audit ulang mengonfirmasi keduanya:
--
--   1. test_sets / question_bank hanya dipagari `is_published`. Level/paket
--      TIDAK ikut dicek di RLS -- hanya di JavaScript. Akun paket hsk_1_4
--      (atau yang sudah expired) bisa membuka DevTools dan menarik seluruh
--      katalog soal HSK 5 & 6, yaitu barang yang dijual di tier hsk_5/hsk_6/vip.
--
--   2. vocab punya DUA policy SELECT. Salah satunya `public read vocab`
--      USING(true) dengan role {public} -- yang di Postgres mencakup `anon`.
--      Jadi seluruh 6.899 kata (termasuk arti Indonesia HSK 5-6) bisa ditarik
--      tanpa akun sama sekali, cukup dengan anon key yang memang publik.
--
--   3. test_attempts di-GRANT INSERT langsung ke `authenticated`. Artinya skor
--      bisa dikarang dari klien tanpa lewat submit_attempt, lalu masuk ke
--      Raport, grafik prediksi, dan tampilan admin.
--
-- CATATAN PENTING SEBELUM DIJALANKAN
-- Halaman LOGIN membaca vocab SEBELUM user login (kartu "Kata Hari Ini",
-- hsk_level <= 3) memakai role anon. Karena itu akses anon TIDAK dicabut total
-- -- hanya dipersempit ke level 1-3. Mencabutnya sepenuhnya akan mematikan
-- kartu tersebut di layar login.
--
-- CARA PAKAI
-- Jalankan apa adanya dulu. Bagian (6) di bawah menampilkan kondisi SEBELUM
-- dan SESUDAH tanpa menyimpan apa pun, karena file ini diakhiri ROLLBACK.
-- Kalau angkanya sudah sesuai, ganti ROLLBACK di baris terakhir jadi COMMIT
-- lalu jalankan ulang.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- (1) Helper: level apa saja yang boleh diakses user yang sedang login.
--     Cerminan persis PACKAGE_LEVELS di app/index.html dan blok yang sama di
--     sql/09_submit_attempt_entitlement.sql -- termasuk fallback ke hsk_1_4
--     untuk package NULL/tidak dikenal (bukan default-deny, supaya perilaku
--     tidak berubah bagi user yang datanya belum lengkap).
--     Admin dapat semua level. Belum login dapat array kosong.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.allowed_levels()
RETURNS int[]
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_role    text;
  v_status  text;
  v_end     date;
  v_package text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN ARRAY[]::int[];
  END IF;

  SELECT role, status, subscription_end, package
    INTO v_role, v_status, v_end, v_package
  FROM public.profiles
  WHERE id = v_uid;

  IF v_role = 'admin' THEN
    RETURN ARRAY[1,2,3,4,5,6,7];
  END IF;

  -- Langganan mati -> tidak ada level sama sekali.
  IF v_status = 'expired' THEN
    RETURN ARRAY[]::int[];
  END IF;
  IF v_end IS NOT NULL AND v_end < (now() AT TIME ZONE 'Asia/Jakarta')::date THEN
    RETURN ARRAY[]::int[];
  END IF;

  RETURN CASE v_package
    WHEN 'hsk_1_4'  THEN ARRAY[1,2,3,4]
    WHEN 'hsk_5'    THEN ARRAY[1,2,3,4,5]
    WHEN 'hsk_6'    THEN ARRAY[1,2,3,4,5,6]
    WHEN 'vip'      THEN ARRAY[1,2,3,4,5,6]
    WHEN 'business' THEN ARRAY[1,2,3,4,5]
    WHEN 'convo'    THEN ARRAY[1,2,3,4]
    ELSE ARRAY[1,2,3,4]
  END;
END;
$$;

REVOKE ALL ON FUNCTION public.allowed_levels() FROM public;
GRANT EXECUTE ON FUNCTION public.allowed_levels() TO authenticated, anon;

COMMENT ON FUNCTION public.allowed_levels() IS
  'Level HSK yang boleh diakses user yang sedang login. Dipakai di policy RLS test_sets/question_bank/vocab. Cerminan PACKAGE_LEVELS di frontend.';

-- ---------------------------------------------------------------------------
-- (2) test_sets: tambahkan pagar level di RLS, bukan cuma di JavaScript.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "test_sets read published" ON public.test_sets;
CREATE POLICY "test_sets read published"
  ON public.test_sets FOR SELECT
  USING (
    is_admin()
    OR (is_published = true AND hsk_level = ANY (public.allowed_levels()))
  );

-- ---------------------------------------------------------------------------
-- (3) question_bank: ikut level dari set induknya.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "qbank read published" ON public.question_bank;
CREATE POLICY "qbank read published"
  ON public.question_bank FOR SELECT
  USING (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM public.test_sets s
      WHERE s.set_id = question_bank.set_id
        AND s.is_published
        AND s.hsk_level = ANY (public.allowed_levels())
    )
  );

-- ---------------------------------------------------------------------------
-- (4) vocab: hapus policy {public} USING(true) yang bikin seluruh tabel
--     terbuka untuk anon. Ganti dengan dua policy sempit:
--       - anon  : HANYA level 1-3, supaya kartu "Kata Hari Ini" di layar
--                 login tetap hidup (lihat loadWordOfDay di app/index.html).
--       - login : sesuai paket masing-masing.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "public read vocab" ON public.vocab;
DROP POLICY IF EXISTS "vocab_select_authenticated" ON public.vocab;
DROP POLICY IF EXISTS "vocab anon sample" ON public.vocab;

CREATE POLICY "vocab anon sample"
  ON public.vocab FOR SELECT TO anon
  USING (hsk_level <= 3);

CREATE POLICY "vocab_select_authenticated"
  ON public.vocab FOR SELECT TO authenticated
  USING (is_admin() OR hsk_level = ANY (public.allowed_levels()));

-- ---------------------------------------------------------------------------
-- (5) test_attempts: cabut INSERT langsung. submit_attempt SECURITY DEFINER
--     yang menulis barisnya, jadi tidak ada alur sah yang butuh grant ini.
--     Sekalian cabut TRUNCATE yang ter-grant ke role tak tepercaya.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "attempts own insert" ON public.test_attempts;
REVOKE INSERT ON public.test_attempts FROM authenticated, anon;

REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM authenticated, anon;

-- ---------------------------------------------------------------------------
-- (6) VERIFIKASI -- tidak menulis apa pun, cuma menampilkan hasil.
-- ---------------------------------------------------------------------------
SELECT 'policy sesudah' AS tahap, tablename, policyname, roles::text, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('vocab','test_sets','question_bank','test_attempts')
ORDER BY tablename, cmd, policyname;

SELECT 'grant INSERT test_attempts (harusnya 0 baris)' AS tahap,
       grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND table_name = 'test_attempts'
  AND privilege_type = 'INSERT' AND grantee IN ('anon','authenticated');

SELECT 'contoh allowed_levels() untuk beberapa paket' AS tahap,
       package, count(*) AS jumlah_user
FROM public.profiles GROUP BY package ORDER BY package;

-- ---- DRY RUN: tidak menyimpan. Ganti jadi COMMIT; kalau sudah yakin. ----
ROLLBACK;
