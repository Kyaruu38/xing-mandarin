-- ============================================================================
-- 13z_undo.sql  —  TOMBOL BATAL untuk 13_security_hardening.sql
--
-- Jalankan HANYA kalau setelah COMMIT ada yang rusak di aplikasi
-- (mis. kartu "Kata Hari Ini" di layar login hilang, murid tidak bisa
-- membuka soal, atau daftar set jadi kosong padahal paketnya benar).
--
-- Ini mengembalikan policy ke kondisi SEBELUM pengetatan, persis seperti
-- yang tercatat di sql/04_rls_snapshot.sql.
--
-- CATATAN: setelah dijalankan, kebocoran yang ditutup 13 akan TERBUKA LAGI
-- (paket HSK 1-4 bisa menarik soal HSK 5-6, vocab bisa ditarik tanpa akun).
-- Jadi ini memang darurat, bukan solusi akhir.
--
-- Sama seperti 13, file ini diakhiri ROLLBACK. Ganti jadi COMMIT kalau
-- memang mau dijalankan sungguhan.
-- ============================================================================

BEGIN;

-- test_sets: balik ke pagar is_published saja
DROP POLICY IF EXISTS "test_sets read published" ON public.test_sets;
CREATE POLICY "test_sets read published"
  ON public.test_sets FOR SELECT
  USING ((is_published = true) OR is_admin());

-- question_bank: balik ke pagar is_published set induknya saja
DROP POLICY IF EXISTS "qbank read published" ON public.question_bank;
CREATE POLICY "qbank read published"
  ON public.question_bank FOR SELECT
  USING (
    is_admin()
    OR EXISTS (
      SELECT 1 FROM public.test_sets s
      WHERE s.set_id = question_bank.set_id AND s.is_published
    )
  );

-- vocab: balik ke dua policy lama
DROP POLICY IF EXISTS "vocab anon sample" ON public.vocab;
DROP POLICY IF EXISTS "vocab_select_authenticated" ON public.vocab;

CREATE POLICY "public read vocab"
  ON public.vocab FOR SELECT
  USING (true);

CREATE POLICY "vocab_select_authenticated"
  ON public.vocab FOR SELECT TO authenticated
  USING (true);

-- test_attempts: kembalikan INSERT langsung
CREATE POLICY "attempts own insert"
  ON public.test_attempts FOR INSERT
  WITH CHECK (user_id = auth.uid());
GRANT INSERT ON public.test_attempts TO authenticated;

-- Fungsi helper dibiarkan ada (tidak mengganggu apa pun kalau tidak dipakai).
-- Kalau mau bersih total: DROP FUNCTION public.allowed_levels();

SELECT 'policy setelah undo' AS tahap, tablename, policyname, roles::text, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('vocab','test_sets','question_bank','test_attempts')
ORDER BY tablename, cmd, policyname;

-- ---- DRY RUN: tidak menyimpan. Ganti jadi COMMIT; kalau memang mau membatalkan. ----
ROLLBACK;
