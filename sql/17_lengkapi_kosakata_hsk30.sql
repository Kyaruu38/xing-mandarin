-- ============================================================================
-- 17_lengkapi_kosakata_hsk30.sql — SUDAH DITERAPKAN ke produksi.
--
-- LATAR BELAKANG DAN KOREKSI
-- Sebelumnya sempat disimpulkan bank kosakata kurang 93 kata dibanding silabus
-- HSK 3.0. Kesimpulan itu SALAH: angkanya didapat dari membandingkan JUMLAH per
-- level, bukan isinya. Setelah dibandingkan kata per kata dengan daftar resmi
-- (5.456 istilah HSK 1-6, dari github.com/ivankra/hsk30 yang jumlah per levelnya
-- cocok persis dengan silabus: 500/772/973/1000/1071/1140), hasilnya:
--
--   * HILANG SUNGGUHAN : 2 kata saja  ->  表示 (HSK 2), 森林 (HSK 4)
--   * LEVEL BERBEDA    : 84 kata      ->  BELUM disentuh, lihat catatan di bawah
--
-- CATATAN SOAL 84 KATA YANG LEVELNYA BERBEDA
-- Jangan digeser massal tanpa dipilah. Sebagian besar kemungkinan adalah efek
-- pencocokan varian, bukan salah penempatan. Contoh: 一下儿 tercatat L5 di daftar
-- resmi sementara di sini L1 -- tapi daftar resmi menaruh bentuk dasar 一下 di L1
-- dan varian 一下儿 di L5. Menggeser membabi buta akan memindahkan kata dasar ke
-- level tinggi, dan karena RLS memagari akses berdasarkan hsk_level, murid paket
-- HSK 1-4 serta pengunjung yang belum login akan kehilangan kata yang seharusnya
-- mereka dapat. Ini perubahan produk, bukan sekadar rapi-rapi data.
--
-- CATATAN: total kosakata HSK 1-6 sekarang 5.365 (sebelumnya 5.363). Angka di
-- landing page (hero counter) perlu ikut diperbarui.
-- ============================================================================

BEGIN;

INSERT INTO public.vocab (hanzi, pinyin, meaning_en, meaning_id, hsk_level, radical, pos, forms, example_zh, example_id)
SELECT * FROM (VALUES
 ('表示','biǎoshì','to express; to indicate','menyatakan atau menunjukkan sikap dan perasaan',2::smallint,'衣',
  ARRAY['v','n']::text[],
  '[{"meanings": ["to express", "to indicate", "to show"], "classifiers": [], "transcriptions": {"pinyin": "biǎo shì"}}]'::jsonb,
  '他点点头，表示同意。','Dia mengangguk, tanda setuju.'),
 ('森林','sēnlín','forest','hutan',4::smallint,'木',
  ARRAY['n']::text[],
  '[{"meanings": ["forest"], "classifiers": [], "transcriptions": {"pinyin": "sēn lín"}}]'::jsonb,
  '这片森林里有很多小动物。','Di hutan ini ada banyak binatang kecil.')
) AS t(hanzi,pinyin,meaning_en,meaning_id,hsk_level,radical,pos,forms,example_zh,example_id)
WHERE NOT EXISTS (SELECT 1 FROM public.vocab v WHERE v.hanzi = t.hanzi);

SELECT hanzi, pinyin, hsk_level, meaning_id, example_zh, example_id
FROM public.vocab WHERE hanzi IN ('表示','森林') ORDER BY hsk_level;

COMMIT;

-- Hasil sesudah COMMIT (terverifikasi):
--   HSK 1: 506 | HSK 2: 751 | HSK 3: 953 | HSK 4: 973 | HSK 5: 1059 | HSK 6: 1123
--   Total HSK 1-6: 5.365
