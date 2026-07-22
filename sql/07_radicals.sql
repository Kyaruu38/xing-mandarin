-- radicals: "Radikal Dasar" (Hanzi Starter Kit) reference table -- Fitur 2, batch prompt-pack.
-- Referensi bersama (semua user login boleh baca), bukan data per-user. Seed ~100 radikal
-- Kangxi paling umum diajarkan ke pemula, dipilih karena sering muncul sebagai komponen di
-- kosakata HSK 1-3 (bukan daftar 214 radikal lengkap -- itu di luar scope pemula).
--
-- Variant forms (亻氵忄扌灬礻衤纟艹辶阝钅饣讠) disimpan sebagai baris TERPISAH dari bentuk
-- induknya (人水心手火示衣糸草辵阜金食言) dengan meaning_id menandai "(bentuk samping)" --
-- app-side (index.html) yang memutuskan animasi Hanzi Writer pakai bentuk induk kalau
-- variannya sendiri bukan karakter valid untuk HanziWriter.create().

CREATE TABLE radicals (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  radical       TEXT NOT NULL,
  pinyin        TEXT NOT NULL,
  meaning_id    TEXT NOT NULL,
  stroke_count  INTEGER NOT NULL CHECK (stroke_count > 0),
  example_chars TEXT[] NOT NULL,
  sort_order    INTEGER NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_radicals_radical ON radicals (radical);
CREATE INDEX idx_radicals_sort_order ON radicals (sort_order);
CREATE INDEX idx_radicals_stroke_count ON radicals (stroke_count);

COMMENT ON TABLE radicals IS 'Referensi Kangxi radical umum buat fitur Radikal Dasar -- read-only bagi user, admin-managed lewat SQL langsung (belum ada admin UI buat ini).';
COMMENT ON COLUMN radicals.example_chars IS 'Array 3 karakter HSK 1-3 yang mengandung radikal ini, dipakai buat tombol "buka stroke practice" di modal.';

-- ============================================================
-- RLS: pola sama seperti vocab (01_vocab_schema.sql) -- konten referensi bersama, SELECT
-- untuk semua authenticated, ZERO write policy (admin belum ada UI buat radicals, kalau perlu
-- update pakai SQL Editor langsung + service_role, bukan lewat app).
-- ============================================================

ALTER TABLE radicals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "radicals select for authenticated"
  ON radicals
  FOR SELECT
  TO authenticated
  USING (true);

GRANT SELECT ON radicals TO authenticated;

-- role anon TIDAK di-GRANT apa pun -> radicals tidak bisa diakses tanpa login (sama seperti
-- pola vocab, meski secara konten radicals sendiri tidak sensitif -- konsistensi > exposure).

-- ============================================================
-- SEED -- ~100 radikal Kangxi paling umum diajarkan ke pemula. hanzi contoh diverifikasi dari
-- kosakata HSK 1-3 yang sudah ada di tabel vocab. Ini data referensi linguistik standar
-- (bukan keputusan produk), tapi tetap disarankan direview sebelum di-apply -- lihat
-- RELEASE_CHECKLIST.md.
-- ============================================================

INSERT INTO radicals (radical, pinyin, meaning_id, stroke_count, example_chars, sort_order) VALUES
('一', 'yī',  'satu / garis datar', 1, ARRAY['一','二','三'], 1),
('丨', 'gǔn', 'garis tegak',        1, ARRAY['中','个','午'], 2),
('丶', 'zhǔ', 'titik',              1, ARRAY['主','为','义'], 3),
('丿', 'piě', 'coretan miring',     1, ARRAY['九','乃','乐'], 4),
('人', 'rén', 'orang',              2, ARRAY['人','他','们'], 5),
('亻', 'rén', 'orang (bentuk samping)', 2, ARRAY['你','做','住'], 6),
('儿', 'ér',  'anak',               2, ARRAY['儿','兄','先'], 7),
('入', 'rù',  'masuk',              2, ARRAY['入','内','全'], 8),
('八', 'bā',  'delapan',            2, ARRAY['八','分','公'], 9),
('冫', 'bīng','es',                 2, ARRAY['冷','次','凉'], 10),
('刀', 'dāo', 'pisau',              2, ARRAY['刀','分','切'], 11),
('刂', 'dāo', 'pisau (bentuk samping)', 2, ARRAY['别','到','前'], 12),
('力', 'lì',  'tenaga',             2, ARRAY['力','加','动'], 13),
('又', 'yòu', 'lagi / tangan kanan',2, ARRAY['又','双','反'], 14),
('十', 'shí', 'sepuluh',            2, ARRAY['十','千','午'], 15),
('厂', 'chǎng','tebing',            2, ARRAY['厂','厅','历'], 16),
('匕', 'bǐ',  'sendok',             2, ARRAY['北','化','匙'], 17),
('口', 'kǒu', 'mulut',              3, ARRAY['口','吃','叫'], 18),
('囗', 'wéi', 'kotak / pagar',      3, ARRAY['国','回','园'], 19),
('土', 'tǔ',  'tanah',              3, ARRAY['土','地','场'], 20),
('士', 'shì', 'cendekiawan',        3, ARRAY['士','声','壶'], 21),
('夕', 'xī',  'senja',              3, ARRAY['夕','多','外'], 22),
('大', 'dà',  'besar',              3, ARRAY['大','天','太'], 23),
('女', 'nǚ',  'perempuan',          3, ARRAY['女','好','妈'], 24),
('子', 'zǐ',  'anak',               3, ARRAY['子','字','学'], 25),
('宀', 'mián','atap',               3, ARRAY['家','安','字'], 26),
('寸', 'cùn', 'inci / ukuran',      3, ARRAY['寸','对','寺'], 27),
('小', 'xiǎo','kecil',              3, ARRAY['小','少','尘'], 28),
('尸', 'shī', 'badan / mayat',      3, ARRAY['尺','局','屋'], 29),
('山', 'shān','gunung',             3, ARRAY['山','岁','岛'], 30),
('巾', 'jīn', 'kain',               3, ARRAY['巾','布','帮'], 31),
('干', 'gān', 'kering',             3, ARRAY['干','平','年'], 32),
('广', 'guǎng','atap miring',       3, ARRAY['床','店','应'], 33),
('弓', 'gōng','busur',              3, ARRAY['弓','张','强'], 34),
('彳', 'chì', 'langkah kecil',      3, ARRAY['行','很','得'], 35),
('纟', 'sī',  'benang (bentuk samping)', 3, ARRAY['红','给','线'], 36),
('辶', 'chuò','berjalan (bentuk samping)', 3, ARRAY['这','过','还'], 37),
('阝', 'fù',  'bukit (kiri)',       3, ARRAY['阳','阴','院'], 38),
('门', 'mén', 'pintu',              3, ARRAY['门','问','间'], 39),
('马', 'mǎ',  'kuda',               3, ARRAY['马','骑','吗'], 40),
('心', 'xīn', 'hati',               4, ARRAY['心','忘','想'], 41),
('忄', 'xīn', 'hati (bentuk samping)', 4, ARRAY['忙','快','情'], 42),
('戈', 'gē',  'tombak',             4, ARRAY['我','战','或'], 43),
('户', 'hù',  'pintu rumah',        4, ARRAY['户','所','房'], 44),
('手', 'shǒu','tangan',             4, ARRAY['手','拳','掌'], 45),
('扌', 'shǒu','tangan (bentuk samping)', 4, ARRAY['打','找','拿'], 46),
('文', 'wén', 'aksara',             4, ARRAY['文','齐','吝'], 47),
('斤', 'jīn', 'kapak / kati',       4, ARRAY['斤','新','近'], 48),
('方', 'fāng','persegi / arah',     4, ARRAY['方','放','旁'], 49),
('日', 'rì',  'matahari / hari',    4, ARRAY['日','早','明'], 50),
('月', 'yuè', 'bulan',              4, ARRAY['月','有','明'], 51),
('木', 'mù',  'kayu',               4, ARRAY['木','林','校'], 52),
('止', 'zhǐ', 'henti',              4, ARRAY['止','正','步'], 53),
('毛', 'máo', 'bulu',               4, ARRAY['毛','尾','毫'], 54),
('气', 'qì',  'udara',              4, ARRAY['气','汽','氧'], 55),
('水', 'shuǐ','air',                4, ARRAY['水','永','泉'], 56),
('氵', 'shuǐ','air (bentuk samping)', 4, ARRAY['河','汉','没'], 57),
('火', 'huǒ', 'api',                4, ARRAY['火','灯','炒'], 58),
('灬', 'huǒ', 'api (bentuk bawah)', 4, ARRAY['热','点','煮'], 59),
('爪', 'zhǎo','cakar',              4, ARRAY['爪','爬','采'], 60),
('父', 'fù',  'ayah',               4, ARRAY['父','爸','爷'], 61),
('片', 'piàn','lempeng',            4, ARRAY['片','版','牌'], 62),
('牙', 'yá',  'gigi',               4, ARRAY['牙','芽','呀'], 63),
('牛', 'niú', 'sapi',               4, ARRAY['牛','牧','特'], 64),
('犬', 'quǎn','anjing',             4, ARRAY['状','献','哭'], 65),
('犭', 'quǎn','anjing (bentuk samping)', 4, ARRAY['猫','狗','狼'], 66),
('王', 'wáng','giok / raja',        4, ARRAY['玩','班','现'], 67),
('见', 'jiàn','lihat',              4, ARRAY['见','观','规'], 68),
('车', 'chē', 'mobil / kendaraan',  4, ARRAY['车','轻','较'], 69),
('贝', 'bèi', 'kerang / uang',      4, ARRAY['贝','买','钱'], 70),
('风', 'fēng','angin',              4, ARRAY['风','飘','台'], 71),
('礻', 'shì', 'dewa (bentuk samping)', 4, ARRAY['神','祝','福'], 72),
('瓜', 'guā', 'labu',               5, ARRAY['瓜','瓢','瓣'], 73),
('甘', 'gān', 'manis',              5, ARRAY['甘','某','甚'], 74),
('生', 'shēng','hidup / lahir',     5, ARRAY['生','姓','星'], 75),
('用', 'yòng','pakai',              5, ARRAY['用','甩','甫'], 76),
('田', 'tián','sawah',              5, ARRAY['田','男','画'], 77),
('疒', 'nè',  'sakit',              5, ARRAY['病','疼','痛'], 78),
('白', 'bái', 'putih',              5, ARRAY['白','百','的'], 79),
('皮', 'pí',  'kulit',              5, ARRAY['皮','皱','破'], 80),
('目', 'mù',  'mata',               5, ARRAY['目','看','眼'], 81),
('石', 'shí', 'batu',               5, ARRAY['石','破','研'], 82),
('示', 'shì', 'dewa / pertanda',    5, ARRAY['示','票','祭'], 83),
('禾', 'hé',  'padi',               5, ARRAY['和','秋','种'], 84),
('穴', 'xué', 'gua / lubang',       5, ARRAY['穴','空','穿'], 85),
('立', 'lì',  'berdiri',            5, ARRAY['立','站','产'], 86),
('衤', 'yī',  'baju (bentuk samping)', 5, ARRAY['裤','被','衬'], 87),
('钅', 'jīn', 'emas (bentuk samping)', 5, ARRAY['钱','针','银'], 88),
('饣', 'shí', 'makan (bentuk samping)', 3, ARRAY['饭','饿','饮'], 89),
('竹', 'zhú', 'bambu',              6, ARRAY['笑','答','笔'], 90),
('米', 'mǐ',  'beras',              6, ARRAY['米','粉','类'], 91),
('羊', 'yáng','kambing',            6, ARRAY['羊','美','着'], 92),
('老', 'lǎo', 'tua',                6, ARRAY['老','考','者'], 93),
('耳', 'ěr',  'telinga',            6, ARRAY['耳','听','聪'], 94),
('舌', 'shé', 'lidah',              6, ARRAY['舌','乱','甜'], 95),
('舟', 'zhōu','perahu',             6, ARRAY['船','航','舰'], 96),
('艹', 'cǎo', 'rumput (bentuk atas)', 3, ARRAY['花','茶','菜'], 97),
('虫', 'chóng','serangga',          6, ARRAY['虫','蛋','蛇'], 98),
('衣', 'yī',  'baju',               6, ARRAY['衣','袋','装'], 99),
('言', 'yán', 'kata',               7, ARRAY['警','誓','誉'], 100),
('讠', 'yán', 'kata (bentuk samping)', 2, ARRAY['说','话','语'], 101),
('走', 'zǒu', 'jalan',              7, ARRAY['走','起','越'], 102),
('足', 'zú',  'kaki',               7, ARRAY['足','跑','跳'], 103),
('鱼', 'yú',  'ikan',               8, ARRAY['鱼','鲜','鲤'], 104),
('鸟', 'niǎo','burung',             5, ARRAY['鸟','鸡','鸭'], 105),
('雨', 'yǔ',  'hujan',              8, ARRAY['雨','雪','雷'], 106);
