-- ============================================================================
-- 15_lihat_26_bug_hsk3.sql — TAMPILKAN ISI ASLI 26 SOAL YANG DILAPORKAN
--
-- SEPENUHNYA READ-ONLY.
--
-- KENAPA INI DULU, BUKAN LANGSUNG DIPERBAIKI
-- Isi soal disimpan di kolom `payload` bertipe jsonb, dan bentuk isinya
-- berbeda-beda per jenis soal (ada yang punya `options`, ada `image_options`,
-- ada `sentence`, ada `statement`). Menulis 26 perintah UPDATE tanpa pernah
-- melihat bentuk aslinya itu cara tercepat merusak bank soal: satu jalur kunci
-- jsonb yang salah tebak bisa menimpa isi soal dengan null tanpa peringatan.
--
-- Jalankan ini, kirim balik hasilnya, baru perbaikannya ditulis dengan tepat.
--
-- CATATAN NOMOR: kolom `order_index` belum tentu sama dengan nomor soal yang
-- kamu lihat di layar (bisa mulai dari 0, bisa dari 1). Blok (0) di bawah
-- memastikan itu dulu sebelum yang lain dibaca.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- (0) PENYELARASAN NOMOR — jalankan dan baca ini DULU
--     Kalau min = 0, berarti semua nomor di daftar bug harus dikurangi 1.
-- ---------------------------------------------------------------------------
SELECT '0. PENYELARASAN NOMOR' AS blok,
       q.set_id,
       min(q.order_index) AS nomor_terkecil,
       max(q.order_index) AS nomor_terbesar,
       count(*)           AS jml_soal
FROM public.question_bank q
WHERE q.set_id LIKE 'H3XING%'
GROUP BY q.set_id
ORDER BY q.set_id;


-- ---------------------------------------------------------------------------
-- (1) SEMUA SOAL YANG DISEBUT DI DAFTAR BUG
--     Satu baris per soal, lengkap dengan payload utuh.
-- ---------------------------------------------------------------------------
WITH sasaran(set_id, nomor, catatan) AS (VALUES
  ('H3XING001', 67, '就是... bisa diganti 但是'),
  ('H3XING002', 56, 'pilihan C: harusnya 还是, bukan 或者 (no 59 kalimat tanya)'),
  ('H3XING002', 57, 'bagian dari blok 56-60'),
  ('H3XING002', 58, 'bagian dari blok 56-60'),
  ('H3XING002', 59, 'kalimat tanya, penentu pilihan C'),
  ('H3XING002', 60, 'pilihan B: buang 嘛 -> 没事儿，我们是朋友。'),
  ('H3XING002', 63, 'pilihan A: 还有用 -> 还要用'),
  ('H3XING002', 67, '要求 -> 让 : 所以我每次回家都让她做'),
  ('H3XING003', 40, 'pertanyaan listening harusnya 女的怎么了, bukan 男的'),
  ('H3XING003', 57, 'pilihan A: 怎么 dan 现在 terbalik -> 你现在怎么才来'),
  ('H3XING003', 62, '味道很大 -> 味道很重'),
  ('H3XING004', 46, 'pilihan D: buang 好的 -> 我马上就洗'),
  ('H3XING004', 61, 'harusnya 虽然这本书不厚 (pasangan 虽然...但是...)'),
  ('H3XING005', 41, '等 dan 久 terbalik -> 对不起，让你等久了'),
  ('H3XING006', 58, 'pilihan B: 快到了 -> 快开始了 (film, bukan orang)'),
  ('H3XING006', 64, '会 -> 会议, dua tempat: 昨天的会议开了... dan 关于昨天的会议'),
  ('H3XING007', 46, 'pilihan D: buang 高吧 -> 差不多两米'),
  ('H3XING008', 57, 'pilihan A: 明天的会 -> 明天的会议'),
  ('H3XING009', 41, 'pilihan E: -> 在楼下，走路两分钟就到了'),
  ('H3XING009', 43, '最近 -> 附近'),
  ('H3XING009', 46, 'pilihan D: 是的 -> 会的'),
  ('H3XING009', 68, '他高兴得跳了起来 -> 他高兴地跳了起来'),
  ('H3XING010', 43, 'buang 是...的 -> 你们什么时候去北京'),
  ('H3XING010', 46, 'pilihan C: tambah 的 -> 因为他的汉语说得特别好'),
  ('H3XING010', 59, 'pilihan B: 还要一个小时 -> 还有一个小时')
)
SELECT
  '1. ISI SOAL' AS blok,
  t.set_id,
  t.nomor        AS nomor_dilaporkan,
  q.order_index  AS order_index_asli,
  q.question_type,
  t.catatan      AS yang_harus_diperbaiki,
  q.payload      AS isi_lengkap
FROM sasaran t
LEFT JOIN public.question_bank q
       ON q.set_id = t.set_id
      AND q.order_index IN (t.nomor, t.nomor - 1, t.nomor + 1)   -- jaring 3 nomor, jaga-jaga beda basis
ORDER BY t.set_id, t.nomor, q.order_index;


-- ---------------------------------------------------------------------------
-- (2) BLOK SOAL BERGAMBAR YANG DILAPORKAN ABSURD
--     Empat gambar ini yang paling banyak dipakai ulang. Tampilkan URL-nya
--     supaya bisa dibuka dan dilihat mana yang perlu digambar ulang.
--       - berenang : H3XING001 6-10 B, 003 1-5 F, 005 1-5 C, 006 6-10 E,
--                    007 1-5 B, 008 6-10 A, 010 6-10 B
--       - basket   : H3XING001 6-10 E, 004 1-5 A, 005 1-5 E, 006 1-5 E
--       - semangka : H3XING002 1-5 D, 003 6-10 E, 005 6-10 C
--       - menari   : H3XING002 6-10 C, 007 1-5 E, 010 1-5 C
-- ---------------------------------------------------------------------------
SELECT
  '2. SOAL BERGAMBAR HSK 3' AS blok,
  q.set_id,
  q.order_index,
  q.question_type,
  coalesce(q.payload->>'image_url','')          AS gambar_tunggal,
  q.payload->'image_options'                    AS gambar_pilihan,
  q.payload->'image_choices'                    AS gambar_pilihan_alt
FROM public.question_bank q
WHERE q.set_id LIKE 'H3XING%'
  AND q.order_index BETWEEN 1 AND 11
  AND (q.payload ? 'image_url' OR q.payload ? 'image_options' OR q.payload ? 'image_choices')
ORDER BY q.set_id, q.order_index;


-- ---------------------------------------------------------------------------
-- (3) BENTUK PAYLOAD PER JENIS SOAL DI HSK 3
--     Supaya perbaikannya menargetkan jalur kunci jsonb yang benar.
-- ---------------------------------------------------------------------------
SELECT
  '3. BENTUK PAYLOAD' AS blok,
  q.question_type,
  count(*)                                                       AS jml_soal,
  (array_agg(DISTINCT k ORDER BY k))                             AS kunci_yang_ada,
  left((array_agg(q.payload::text ORDER BY q.order_index))[1], 400) AS contoh_isi
FROM public.question_bank q
JOIN public.test_sets s USING (set_id)
CROSS JOIN LATERAL jsonb_object_keys(q.payload) AS k
WHERE s.hsk_level = 3
GROUP BY q.question_type
ORDER BY q.question_type;
