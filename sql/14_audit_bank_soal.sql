-- ============================================================================
-- 14_audit_bank_soal.sql — PEMERIKSA OTOMATIS BANK SOAL HSK 1–6
--
-- SEPENUHNYA READ-ONLY. Tidak ada UPDATE, tidak ada DELETE, tidak ada transaksi.
-- Aman dijalankan kapan saja, termasuk di jam sibuk.
--
-- LATAR BELAKANG
-- 26 bug HSK 3 yang ditemukan manual ternyata cuma segelintir dari pola yang sama.
-- Contoh paling jelas: satu gambar berenang yang absurd ternyata dipakai di TUJUH
-- set berbeda. Membetulkan tujuh soal itu tidak menyelesaikan apa pun kalau
-- gambarnya masih gambar yang sama. Skrip ini mencari POLA-nya di seluruh HSK 1–6,
-- bukan menunggu ditemukan satu per satu.
--
-- CARA BACA HASIL
-- Setiap blok diberi nomor. Jalankan semuanya sekaligus, lalu buka tab hasil satu
-- per satu. Blok yang tidak mengembalikan baris = bersih untuk pola itu.
--
-- CATATAN: beberapa blok sengaja "terlalu peka" (menandai yang sebenarnya benar).
-- Lebih baik menyaring 20 temuan palsu daripada melewatkan 1 yang asli.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- (1) GAMBAR DIPAKAI DI LEBIH DARI SATU SET
--     Ini akar masalah terbesar. Satu gambar rusak = N soal rusak sekaligus.
--     Urut dari yang paling banyak dipakai supaya perbaikannya paling berdampak.
-- ---------------------------------------------------------------------------
WITH gambar AS (
  -- gambar tunggal per soal
  SELECT q.set_id, s.hsk_level, q.order_index, q.payload->>'image_url' AS url
  FROM public.question_bank q
  JOIN public.test_sets s USING (set_id)
  WHERE q.payload ? 'image_url' AND q.payload->>'image_url' <> ''
  UNION ALL
  -- gambar pilihan ganda (A–F), dibongkar jadi satu baris per gambar
  SELECT q.set_id, s.hsk_level, q.order_index, opsi.url
  FROM public.question_bank q
  JOIN public.test_sets s USING (set_id)
  CROSS JOIN LATERAL jsonb_array_elements_text(
    CASE
      WHEN jsonb_typeof(q.payload->'image_options') = 'array' THEN q.payload->'image_options'
      WHEN jsonb_typeof(q.payload->'image_choices') = 'array' THEN q.payload->'image_choices'
      ELSE '[]'::jsonb
    END
  ) AS opsi(url)
  WHERE opsi.url <> ''
)
SELECT
  '1. GAMBAR DIPAKAI ULANG'          AS pemeriksaan,
  url                                 AS gambar,
  count(DISTINCT set_id)              AS jml_set,
  count(*)                            AS jml_pemakaian,
  string_agg(DISTINCT 'HSK'||hsk_level||':'||set_id, ', ' ORDER BY 'HSK'||hsk_level||':'||set_id) AS dipakai_di
FROM gambar
GROUP BY url
HAVING count(DISTINCT set_id) > 1
ORDER BY count(DISTINCT set_id) DESC, count(*) DESC;


-- ---------------------------------------------------------------------------
-- (2) 或者 DIPAKAI DI KALIMAT TANYA
--     Aturan HSK: 还是 untuk pertanyaan, 或者 untuk pernyataan.
--     Persis bug H3XING002 no 56-60.
-- ---------------------------------------------------------------------------
SELECT '2. 或者 DI KALIMAT TANYA' AS pemeriksaan,
       s.hsk_level, q.set_id, q.order_index, q.question_type,
       left(q.payload::text, 320) AS cuplikan
FROM public.question_bank q
JOIN public.test_sets s USING (set_id)
WHERE q.payload::text LIKE '%或者%'
  AND (q.payload::text LIKE '%？%' OR q.payload::text LIKE '%吗%' OR q.payload::text LIKE '%呢%')
ORDER BY s.hsk_level, q.set_id, q.order_index;


-- ---------------------------------------------------------------------------
-- (3) DUGAAN 得 / 地 TERTUKAR
--     得 = Kata Kerja + 得 + Kata Sifat   (他跑得很快)
--     地 = Kata Sifat + 地 + Kata Kerja   (他高兴地跳)
--     Persis bug H3XING009 no 68. Pola di bawah menangkap kata sifat umum yang
--     diikuti 得 lalu kata kerja gerak — susunan yang seharusnya memakai 地.
-- ---------------------------------------------------------------------------
SELECT '3. DUGAAN 得/地 TERTUKAR' AS pemeriksaan,
       s.hsk_level, q.set_id, q.order_index,
       left(q.payload::text, 320) AS cuplikan
FROM public.question_bank q
JOIN public.test_sets s USING (set_id)
WHERE q.payload::text ~ '(高兴|开心|快乐|认真|努力|安静|慢慢|急|难过|生气)得[^很好多少]'
   OR q.payload::text ~ '地(说得|跑得|走得|做得)'
ORDER BY s.hsk_level, q.set_id, q.order_index;


-- ---------------------------------------------------------------------------
-- (4) 会 YANG KEMUNGKINAN KURANG 议  (会 vs 会议)
--     Bug H3XING006 no 64 dan H3XING008 no 57 dua-duanya kasus ini.
--     开会 itu SAH (kata kerja). Yang mencurigakan: 的会, 会开了, 关于...会.
-- ---------------------------------------------------------------------------
SELECT '4. DUGAAN 会 KURANG 议' AS pemeriksaan,
       s.hsk_level, q.set_id, q.order_index,
       left(q.payload::text, 320) AS cuplikan
FROM public.question_bank q
JOIN public.test_sets s USING (set_id)
WHERE (q.payload::text ~ '的会[^议员话儿]' OR q.payload::text ~ '关于[^"]{0,6}会[^议]' OR q.payload::text ~ '会开了')
  AND q.payload::text NOT LIKE '%会议%'
ORDER BY s.hsk_level, q.set_id, q.order_index;


-- ---------------------------------------------------------------------------
-- (5) 最近 DIPAKAI UNTUK TEMPAT, SEHARUSNYA 附近
--     最近 = belakangan ini (waktu). 附近 = di sekitar (tempat).
--     Persis bug H3XING009 no 43.
-- ---------------------------------------------------------------------------
SELECT '5. 最近 UNTUK TEMPAT' AS pemeriksaan,
       s.hsk_level, q.set_id, q.order_index,
       left(q.payload::text, 320) AS cuplikan
FROM public.question_bank q
JOIN public.test_sets s USING (set_id)
WHERE q.payload::text ~ '(在|去|到|离)[^"]{0,4}最近'
   OR q.payload::text ~ '最近的?(饭馆|商店|银行|医院|超市|车站|地铁|学校|公园|机场)'
ORDER BY s.hsk_level, q.set_id, q.order_index;


-- ---------------------------------------------------------------------------
-- (6) 还有 / 还要 YANG TERTUKAR
--     还有 + kata benda (masih ada).  还要 + kata kerja (masih harus/mau).
--     Bug H3XING002 no 63 dan H3XING010 no 59 saling berkebalikan arah.
-- ---------------------------------------------------------------------------
SELECT '6. 还有/还要 TERTUKAR' AS pemeriksaan,
       s.hsk_level, q.set_id, q.order_index,
       left(q.payload::text, 320) AS cuplikan
FROM public.question_bank q
JOIN public.test_sets s USING (set_id)
WHERE q.payload::text ~ '还要[一二三四五六七八九十两几半]'          -- 还要一个小时 -> harusnya 还有
   OR q.payload::text ~ '还有(用|做|去|吃|喝|买|写|说|看|学|问|回)'  -- 还有用 -> harusnya 还要用
ORDER BY s.hsk_level, q.set_id, q.order_index;


-- ---------------------------------------------------------------------------
-- (7) 虽然 TANPA PASANGANNYA
--     Di HSK, 虽然 hampir selalu berpasangan dengan 但是 atau 可是.
--     Persis bug H3XING004 no 61.
-- ---------------------------------------------------------------------------
SELECT '7. 虽然 TANPA PASANGAN' AS pemeriksaan,
       s.hsk_level, q.set_id, q.order_index,
       left(q.payload::text, 320) AS cuplikan
FROM public.question_bank q
JOIN public.test_sets s USING (set_id)
WHERE q.payload::text LIKE '%虽然%'
  AND q.payload::text NOT LIKE '%但是%'
  AND q.payload::text NOT LIKE '%可是%'
  AND q.payload::text NOT LIKE '%不过%'
ORDER BY s.hsk_level, q.set_id, q.order_index;


-- ---------------------------------------------------------------------------
-- (8) TEKS SOAL PERSIS SAMA DI LEBIH DARI SATU SET
--     Kalau murid mengerjakan 3 set dan menemukan soal yang sama, nilai
--     simulasinya jadi tidak berarti.
-- ---------------------------------------------------------------------------
SELECT '8. SOAL KEMBAR ANTAR SET' AS pemeriksaan,
       s.hsk_level,
       count(DISTINCT q.set_id)                       AS jml_set,
       string_agg(DISTINCT q.set_id, ', ')            AS set_terkait,
       left(coalesce(q.payload->>'question',
                     q.payload->>'stem',
                     q.payload->>'sentence',
                     q.payload->>'statement'), 110)   AS teks_soal
FROM public.question_bank q
JOIN public.test_sets s USING (set_id)
WHERE coalesce(q.payload->>'question', q.payload->>'stem',
               q.payload->>'sentence', q.payload->>'statement') IS NOT NULL
  AND length(coalesce(q.payload->>'question', q.payload->>'stem',
                      q.payload->>'sentence', q.payload->>'statement')) > 8
GROUP BY s.hsk_level, teks_soal
HAVING count(DISTINCT q.set_id) > 1
ORDER BY count(DISTINCT q.set_id) DESC, s.hsk_level;


-- ---------------------------------------------------------------------------
-- (9) PILIHAN JAWABAN KEMBAR DI DALAM SATU SOAL
--     Kalau dua pilihan isinya sama, soalnya otomatis cacat.
-- ---------------------------------------------------------------------------
SELECT '9. PILIHAN KEMBAR' AS pemeriksaan,
       s.hsk_level, q.set_id, q.order_index,
       o.teks AS pilihan_yang_kembar,
       count(*) AS muncul_berapa_kali
FROM public.question_bank q
JOIN public.test_sets s USING (set_id)
CROSS JOIN LATERAL jsonb_array_elements_text(
  CASE
    WHEN jsonb_typeof(q.payload->'options') = 'array' THEN q.payload->'options'
    WHEN jsonb_typeof(q.payload->'choices') = 'array' THEN q.payload->'choices'
    ELSE '[]'::jsonb
  END
) AS o(teks)
WHERE o.teks <> ''
GROUP BY s.hsk_level, q.set_id, q.order_index, o.teks
HAVING count(*) > 1
ORDER BY s.hsk_level, q.set_id, q.order_index;


-- ---------------------------------------------------------------------------
-- (10) KATA PEMBUKA BERLEBIH DI PILIHAN JAWABAN
--      Bug H3XING004 no 46-50 (好的 tidak perlu), H3XING007 no 46-50 (高吧),
--      H3XING009 no 46-50 (是的 seharusnya 会的). Pola: pilihan jawaban yang
--      diawali basa-basi padahal soalnya minta jawaban langsung.
-- ---------------------------------------------------------------------------
SELECT '10. PILIHAN DIAWALI BASA-BASI' AS pemeriksaan,
       s.hsk_level, q.set_id, q.order_index, o.teks AS pilihan
FROM public.question_bank q
JOIN public.test_sets s USING (set_id)
CROSS JOIN LATERAL jsonb_array_elements_text(
  CASE
    WHEN jsonb_typeof(q.payload->'options') = 'array' THEN q.payload->'options'
    WHEN jsonb_typeof(q.payload->'choices') = 'array' THEN q.payload->'choices'
    ELSE '[]'::jsonb
  END
) AS o(teks)
WHERE o.teks ~ '^(好的|是的|对的|行的)[，,、]'
ORDER BY s.hsk_level, q.set_id, q.order_index;


-- ---------------------------------------------------------------------------
-- (11) KESEHATAN STRUKTUR SET
--      Jumlah soal tidak cocok dengan total_questions, atau ada set kosong.
-- ---------------------------------------------------------------------------
SELECT '11. STRUKTUR SET JANGGAL' AS pemeriksaan,
       s.hsk_level, s.set_id, s.section, s.title,
       s.total_questions        AS ditulis,
       count(q.id)              AS sebenarnya,
       count(q.id) - s.total_questions AS selisih
FROM public.test_sets s
LEFT JOIN public.question_bank q USING (set_id)
WHERE s.is_published
GROUP BY s.hsk_level, s.set_id, s.section, s.title, s.total_questions
HAVING count(q.id) <> s.total_questions OR count(q.id) = 0
ORDER BY s.hsk_level, s.set_id;


-- ---------------------------------------------------------------------------
-- (12) NOMOR URUT SOAL BOLONG ATAU DOBEL
-- ---------------------------------------------------------------------------
SELECT '12. NOMOR URUT BERMASALAH' AS pemeriksaan,
       s.hsk_level, q.set_id, q.order_index, count(*) AS muncul
FROM public.question_bank q
JOIN public.test_sets s USING (set_id)
GROUP BY s.hsk_level, q.set_id, q.order_index
HAVING count(*) > 1
ORDER BY s.hsk_level, q.set_id, q.order_index;


-- ---------------------------------------------------------------------------
-- (13) SOAL LISTENING TANPA AUDIO
-- ---------------------------------------------------------------------------
SELECT '13. LISTENING TANPA AUDIO' AS pemeriksaan,
       s.hsk_level, q.set_id, q.order_index, q.question_type
FROM public.question_bank q
JOIN public.test_sets s USING (set_id)
WHERE s.section = 'listening'
  AND (NOT q.payload ? 'audio_url' OR coalesce(q.payload->>'audio_url','') = '')
ORDER BY s.hsk_level, q.set_id, q.order_index;


-- ---------------------------------------------------------------------------
-- (14) RINGKASAN — dijalankan terakhir supaya gampang dilihat
-- ---------------------------------------------------------------------------
SELECT '14. RINGKASAN' AS pemeriksaan,
       s.hsk_level,
       count(DISTINCT s.set_id) AS jml_set,
       count(q.id)              AS jml_soal
FROM public.test_sets s
LEFT JOIN public.question_bank q USING (set_id)
WHERE s.is_published
GROUP BY s.hsk_level
ORDER BY s.hsk_level;
