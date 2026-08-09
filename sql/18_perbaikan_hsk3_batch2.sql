-- ============================================================================
-- 18_perbaikan_hsk3_batch2.sql — SUDAH DITERAPKAN ke produksi.
--
-- Lanjutan dari 16. Dengan file ini, SEMUA bug BERBASIS TEKS dari daftar 26
-- laporan HSK 3 sudah selesai: 20 diterapkan, 2 sengaja ditolak, 4 sisanya
-- adalah masalah gambar yang tidak bisa disentuh SQL.
--
-- PETA PENOMORAN (wajib dibaca sebelum menambah perbaikan baru):
--   listening : set_id 'h3-listening-N', order_index 0-39  -> soal no 1-40
--   reading   : set_id 'H3XINGNNN',      order_index 1-30  -> soal no 41-70
--   writing   : set_id (lihat test_sets), order_index 1-10 -> soal no 71-80
--   Dua konvensi penamaan berbeda di level yang sama. Selalu verifikasi dulu.
--
-- Soal pasangan kalimat (sentence_match) menyimpan SATU set pilihan A-E di
-- SETIAP soal dalam bloknya. Karena itu perbaikan satu pilihan mengenai 5 baris,
-- bukan 1. Angka 5 di kolom "kena" pada dry run adalah hasil yang BENAR.
-- ============================================================================

BEGIN;
CREATE TEMP TABLE hasil(no int, perbaikan text, kena int) ON COMMIT DROP;

-- ---- Batch 2: perbaikan pada teks bacaan -----------------------------------
WITH f(no,setid,oi,lama,baru,ket) AS (VALUES
 (10,'H3XING002',27,'都要求她做','都让她做','no67: 要求 -> 让'),
 (11,'H3XING003',22,'觉得味道太大','觉得味道太重','no62: 太大 -> 太重'),
 (12,'H3XING006',18,'到了，还有五分钟','开始了，还有五分钟','no58: 到了 -> 开始了'),
 (13,'H3XING006',24,'昨天的会开了','昨天的会议开了','no64: 会 -> 会议'),
 (14,'H3XING001',27,'就是房间小','但是房间小','no67: 就是 -> 但是')
), upd AS (
  UPDATE public.question_bank q SET payload = replace(q.payload::text, f.lama, f.baru)::jsonb
  FROM f WHERE q.set_id=f.setid AND q.order_index=f.oi AND q.payload::text LIKE '%'||f.lama||'%'
  RETURNING f.no, f.ket
)
INSERT INTO hasil SELECT no, ket, count(*) FROM upd GROUP BY no, ket;

-- ---- Batch 3: perbaikan pada pilihan jawaban (mengenai 5 baris per blok) ----
WITH f(no,setid,lo,hi,lama,baru,ket) AS (VALUES
 (15,'H3XING004',6,10,'好的，我马上就去洗','我马上就去洗','no46-50 D: buang 好的'),
 (16,'H3XING007',6,10,'差不多两米高吧','差不多两米','no46-50 D: buang 高吧'),
 (17,'H3XING009',6,10,'是的，从小就学','会的，从小就学','no46-50 D: 是的 -> 会的'),
 (18,'H3XING010',6,10,'因为他汉语说得','因为他的汉语说得','no46-50 C: tambah 的'),
 (19,'H3XING002',16,20,'或者','还是','no56-60 C: 或者 -> 还是 (tanya pakai 还是)'),
 (20,'h3-listening-3',39,39,'男的怎么了','女的怎么了','no40: pertanyaan untuk 女的'),
 (21,'H3XING009',1,5,'在楼下的药店，走路','在楼下，走路','no41-45 E: buang 药店 yang diulang')
), upd AS (
  UPDATE public.question_bank q SET payload = replace(q.payload::text, f.lama, f.baru)::jsonb
  FROM f WHERE q.set_id=f.setid AND q.order_index BETWEEN f.lo AND f.hi
    AND q.payload::text LIKE '%'||f.lama||'%'
  RETURNING f.no, f.ket
)
INSERT INTO hasil SELECT no, ket, count(*) FROM upd GROUP BY no, ket;

SELECT no, perbaikan, kena FROM hasil
UNION ALL SELECT 99, '>>> TOTAL BARIS', sum(kena) FROM hasil ORDER BY 1;

COMMIT;

-- ============================================================================
-- DUA KOREKSI YANG SENGAJA DITOLAK, DENGAN ALASANNYA
--
-- H3XING005 no41 — laporan: "seharusnya 让你等久了, 等 dan 久 terbalik".
--   Isi database: 对不起，让你久等了。 Itu SUDAH bentuk bakunya. 久等了 adalah
--   ungkapan lazim penutur asli; 等久了 justru tidak lazim. Menerapkannya akan
--   mengubah soal yang benar menjadi salah.
--
-- H3XING004 no61 — laporan: "seharusnya 虽然这本书不厚".
--   Isi database: 这本书虽然不厚，但是里面的故事非常… Pasangan 虽然…但是 sudah
--   lengkap, dan menaruh 虽然 setelah subjek adalah susunan yang sah. Bentuk
--   yang diminta juga sah. Ini soal selera, bukan kesalahan.
--
-- EMPAT MASALAH GAMBAR — TIDAK BISA DIPERBAIKI LEWAT SQL
--   berenang : H3XING001(6-10 B), 003(1-5 F), 005(1-5 C), 006(6-10 E),
--              007(1-5 B), 008(6-10 A), 010(6-10 B)
--   basket   : H3XING001(6-10 E), 004(1-5 A), 005(1-5 E), 006(1-5 E)
--   semangka : H3XING002(1-5 D), 003(6-10 E), 005(6-10 C)
--   menari   : H3XING002(6-10 C), 007(1-5 E), 010(1-5 C)
--   Yang harus diganti adalah BERKAS GAMBARNYA di bucket listening-images,
--   bukan soalnya. Secara keseluruhan ada 147 gambar dipakai 650 kali, dan 50
--   di antaranya dipakai di lebih dari satu set — jadi satu gambar yang keliru
--   merusak banyak soal sekaligus. Lihat sql/14 blok (1) untuk daftar lengkapnya.
-- ============================================================================
