-- ============================================================================
-- 19_audit_hsk1-6_hasil.sql — HASIL AUDIT SELURUH BANK SOAL. Sudah diterapkan.
--
-- Cakupan: 160 set terbit, 5.175 butir soal, HSK 1 sampai 6.
--
-- ---------------------------------------------------------------------------
-- HASIL AKHIR: 1 CACAT NYATA DITEMUKAN DAN DIPERBAIKI
-- ---------------------------------------------------------------------------
--   H6XING001 #3 : 妹妹高兴得跳了起来。 -> 妹妹高兴地跳了起来。
--   Jenis kesalahan yang sama persis dengan yang dilaporkan di H3XING009 no68.
--   Aturannya: Kata Kerja + 得 + Kata Sifat (他跑得很快)
--              Kata Sifat + 地 + Kata Kerja (他高兴地跳)
--
-- ---------------------------------------------------------------------------
-- CATATAN PENTING SOAL PEMERIKSA OTOMATIS (sql/14)
-- ---------------------------------------------------------------------------
-- Jalan pertama pemeriksa menandai SEKITAR 60 kandidat. Setelah dibaca satu per
-- satu, 59 di antaranya TERNYATA BENAR dan yang salah adalah pemeriksanya.
-- Kalau 59 itu "diperbaiki" tanpa dibaca, hasilnya justru merusak 59 soal yang
-- sudah benar. Rincian salah alarmnya, supaya tidak diulang:
--
--   15x "会 kurang 议"  -> semuanya dari pola 男的会做…, 女的会说…
--        的 di situ bagian dari 男的/女的, dan 会 adalah kata bantu "bisa",
--        bukan potongan 会议. Regex '的会' terlalu polos.
--
--   20x "或者 di kalimat tanya" -> 或者 muncul di dalam pernyataan yang kebetulan
--        berada di soal bertanda tanya. Aturan 还是-untuk-tanya hanya berlaku
--        kalau 或者 itu sendiri yang menawarkan pilihan (A 或者 B？).
--
--   21x "虽然 tanpa pasangan" -> di Mandarin natural, 虽然 TIDAK wajib berpasangan
--        dengan 但是, apalagi di HSK 5-6. Pemeriksa ini memang sengaja peka
--        berlebihan; hasilnya harus selalu dibaca manusia.
--
--    3x "还要/还有 tertukar" -> 还要半个小时才能结束 dan 这个方案还有问题 dua-duanya
--        benar. 还要 + durasi = "masih butuh sekian lama". 还有问题 = "masih ada
--        masalah", bukan pola 还有 + kata kerja.
--
-- Kesimpulan yang layak diingat: pemeriksa otomatis bagus untuk MEMPERSEMPIT
-- tempat mencari, bukan untuk memutuskan. Setiap temuan tetap harus dibaca.
-- ============================================================================

BEGIN;

WITH upd AS (
  UPDATE public.question_bank q
  SET payload = replace(q.payload::text, '高兴得跳了起来', '高兴地跳了起来')::jsonb
  WHERE q.set_id = 'H6XING001' AND q.order_index = 3
    AND q.payload::text LIKE '%高兴得跳了起来%'
  RETURNING 1
)
SELECT 'H6XING001#3: 高兴得跳 -> 高兴地跳' AS perbaikan, count(*) AS kena FROM upd;

COMMIT;

-- Terverifikasi sesudah COMMIT: status = TERSIMPAN.
