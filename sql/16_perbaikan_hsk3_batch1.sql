-- ============================================================================
-- 16_perbaikan_hsk3_batch1.sql — SUDAH DITERAPKAN ke produksi.
--
-- 8 perbaikan pertama dari 26 laporan bug HSK 3. Dry run lebih dulu: setiap
-- perbaikan kena tepat 1 baris, tidak ada efek samping. Sesudah COMMIT,
-- kedelapannya diverifikasi ulang di luar transaksi: semua berstatus TERSIMPAN.
--
-- CATATAN PENOMORAN (ini yang bikin perbaikan buta pasti meleset):
--   listening : order_index 0-39  -> soal no 1-40  (basis NOL)
--   reading   : order_index 1-30  -> soal no 41-70 (basis SATU, digeser 40)
--   writing   : order_index 1-10  -> soal no 71-80
--   set_id reading = 'H3XING001', tapi set_id listening = 'h3-listening-1'.
--
-- YANG SENGAJA TIDAK DITERAPKAN:
--   H3XING005 no41. Laporan minta 'let you 等久了', tapi isi database sudah
--   '让你久等了' yang justru bentuk bakunya. Menerapkannya akan merusak soal
--   yang sudah benar.
--   H3XING003 no62 ('味道很大' -> '很重'): kena 0 baris, teks aslinya berbeda
--   dari yang dilaporkan. Perlu dilihat isinya dulu.
-- ============================================================================

BEGIN;

CREATE TEMP TABLE hasil(no int, perbaikan text, kena int) ON COMMIT DROP;

WITH f(no,setid,oi,lama,baru,ket) AS (VALUES
 (1,'H3XING002',20,'我们是朋友嘛','我们是朋友','no60 B: buang 嘛'),
 (2,'H3XING003',17,'你怎么现在','你现在怎么','no57: urutan 怎么/现在'),
 (3,'H3XING002',23,'还有用','还要用','no63 A: 还有用 -> 还要用'),
 (4,'H3XING009',3,'最近的药店','附近的药店','no43: 最近 -> 附近'),
 (5,'H3XING010',3,'你们是什么时候去的北京','你们什么时候去北京','no43: buang 是...的'),
 (6,'H3XING008',17,'明天的会你','明天的会议你','no57 A: 会 -> 会议'),
 (7,'H3XING010',19,'还要一个小时','还有一个小时','no59 B: 还要 -> 还有'),
 (8,'H3XING009',28,'高兴得跳','高兴地跳','no68: 得 -> 地')
), upd AS (
  UPDATE public.question_bank q
  SET payload = replace(q.payload::text, f.lama, f.baru)::jsonb
  FROM f
  WHERE q.set_id=f.setid AND q.order_index=f.oi AND q.payload::text LIKE '%'||f.lama||'%'
  RETURNING f.no, f.ket
)
INSERT INTO hasil SELECT no, ket, count(*) FROM upd GROUP BY no, ket;

SELECT h.no, h.perbaikan, h.kena AS baris_kena FROM hasil h
UNION ALL SELECT 99, '>>> TOTAL BARIS BERUBAH', sum(kena) FROM hasil
ORDER BY 1;

COMMIT;
