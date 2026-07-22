-- Survival Kit (Fitur 5, batch prompt-pack): "Level 0" beginner deck, 100 kata/frasa, 5 tema.
-- Kurasi lengkap + status UPDATE/INSERT (tebakan) ada di docs/survival_kit_curation.md.
--
-- KEPUTUSAN (bukan literal spec, lihat RELEASE_CHECKLIST.md):
-- 1. hsk_level diisi 1, BUKAN 0 -- vocab.hsk_level punya CHECK (hsk_level BETWEEN 1 AND 6)
--    di sql/01_vocab_schema.sql, 0 akan ditolak constraint itu. Filter fitur ini tetap
--    beginner_kit=true (bukan hsk_level), jadi hsk_level cuma metadata sekunder, aman diisi 1.
-- 2. Nambah beginner_theme TEXT (di luar 2 kolom yang disebut prompt) -- dibutuhkan buat
--    requirement "group per tema", tidak ada kolom kategori existing buat direuse.
--
-- IDEMPOTENT by design: INSERT ... ON CONFLICT (hanzi) DO UPDATE. Aman dijalankan berkali-kali,
-- dan aman terlepas dari tebakan status di docs/survival_kit_curation.md benar atau salah --
-- kalau hanzi-nya udah ada di vocab (row lain, hsk_level/pinyin/meaning_en apa pun), row itu
-- CUMA ditandai beginner_kit/beginner_order/beginner_theme, isi vocab existing-nya TIDAK
-- ditimpa (meaning_id di-backfill CUMA kalau masih NULL).

ALTER TABLE vocab ADD COLUMN IF NOT EXISTS beginner_kit boolean NOT NULL DEFAULT false;
ALTER TABLE vocab ADD COLUMN IF NOT EXISTS beginner_order integer;
ALTER TABLE vocab ADD COLUMN IF NOT EXISTS beginner_theme text;

CREATE INDEX IF NOT EXISTS idx_vocab_beginner_kit ON vocab (beginner_kit) WHERE beginner_kit = true;

COMMENT ON COLUMN vocab.beginner_kit IS 'true = bagian dari deck Survival Kit (Fitur 5), gratis semua user login, terlepas dari hsk_level/package';
COMMENT ON COLUMN vocab.beginner_order IS 'urutan tampil di deck Survival Kit, 1-100';
COMMENT ON COLUMN vocab.beginner_theme IS 'greetings|self_intro|numbers|survival|responses -- dipakai buat group-per-tema di UI, cocokkan sama survivalThemeXxx i18n keys di index.html';

-- RLS/GRANT vocab sudah ada (SELECT authenticated, INSERT/UPDATE admin-only via is_admin())
-- dari sql/01_vocab_schema.sql -- kolom baru otomatis ikut policy yang sama, tidak perlu policy
-- baru. INSERT di bawah ini dijalankan lewat SQL Editor (service_role/postgres), bukan lewat
-- app, jadi tidak kena policy INSERT admin-only itu.

INSERT INTO vocab (hanzi, pinyin, meaning_en, meaning_id, hsk_level, pos, forms, beginner_kit, beginner_order, beginner_theme) VALUES
-- Tema 1: Sapaan & Sopan Santun
('你好','nǐ hǎo','hello','halo',1,'{}','[{"pinyin":"nǐ hǎo","meanings":["hello"]}]'::jsonb,true,1,'greetings'),
('你们好','nǐmen hǎo','hello (to a group)','halo (ke beberapa orang)',1,'{}','[{"pinyin":"nǐmen hǎo","meanings":["hello (to a group)"]}]'::jsonb,true,2,'greetings'),
('谢谢','xièxie','thank you','terima kasih',1,'{}','[{"pinyin":"xièxie","meanings":["thank you"]}]'::jsonb,true,3,'greetings'),
('不客气','bú kèqi','you''re welcome','sama-sama',1,'{}','[{"pinyin":"bú kèqi","meanings":["you''re welcome"]}]'::jsonb,true,4,'greetings'),
('再见','zàijiàn','goodbye','sampai jumpa',1,'{}','[{"pinyin":"zàijiàn","meanings":["goodbye"]}]'::jsonb,true,5,'greetings'),
('对不起','duìbuqǐ','sorry','maaf',1,'{}','[{"pinyin":"duìbuqǐ","meanings":["sorry"]}]'::jsonb,true,6,'greetings'),
('没关系','méi guānxi','it''s okay / no worries','tidak apa-apa',1,'{}','[{"pinyin":"méi guānxi","meanings":["it''s okay"]}]'::jsonb,true,7,'greetings'),
('请','qǐng','please','tolong / silakan',1,'{}','[{"pinyin":"qǐng","meanings":["please"]}]'::jsonb,true,8,'greetings'),
('早上好','zǎoshang hǎo','good morning','selamat pagi',1,'{}','[{"pinyin":"zǎoshang hǎo","meanings":["good morning"]}]'::jsonb,true,9,'greetings'),
('晚安','wǎn''ān','good night','selamat malam',1,'{}','[{"pinyin":"wǎn''ān","meanings":["good night"]}]'::jsonb,true,10,'greetings'),
('你好吗','nǐ hǎo ma','how are you','apa kabar',1,'{}','[{"pinyin":"nǐ hǎo ma","meanings":["how are you"]}]'::jsonb,true,11,'greetings'),
('老师','lǎoshī','teacher','guru',1,'{}','[{"pinyin":"lǎoshī","meanings":["teacher"]}]'::jsonb,true,12,'greetings'),
('先生','xiānsheng','Mr. / sir','Tuan / Bapak',1,'{}','[{"pinyin":"xiānsheng","meanings":["Mr. / sir"]}]'::jsonb,true,13,'greetings'),
('小姐','xiǎojiě','Miss','Nona',1,'{}','[{"pinyin":"xiǎojiě","meanings":["Miss"]}]'::jsonb,true,14,'greetings'),
('欢迎','huānyíng','welcome','selamat datang',1,'{}','[{"pinyin":"huānyíng","meanings":["welcome"]}]'::jsonb,true,15,'greetings'),
('麻烦你','máfan nǐ','sorry to bother you','maaf merepotkan',1,'{}','[{"pinyin":"máfan nǐ","meanings":["sorry to bother you"]}]'::jsonb,true,16,'greetings'),
('不好意思','bùhǎoyìsi','excuse me / my bad','maaf / permisi',1,'{}','[{"pinyin":"bùhǎoyìsi","meanings":["excuse me"]}]'::jsonb,true,17,'greetings'),
('请问','qǐngwèn','excuse me, may I ask','permisi, boleh tanya',1,'{}','[{"pinyin":"qǐngwèn","meanings":["excuse me, may I ask"]}]'::jsonb,true,18,'greetings'),
('拜拜','báibái','bye-bye','dadah',1,'{}','[{"pinyin":"báibái","meanings":["bye-bye"]}]'::jsonb,true,19,'greetings'),
('恭喜','gōngxǐ','congratulations','selamat',1,'{}','[{"pinyin":"gōngxǐ","meanings":["congratulations"]}]'::jsonb,true,20,'greetings'),
('打扰一下','dǎrǎo yíxià','sorry to interrupt','permisi mengganggu sebentar',1,'{}','[{"pinyin":"dǎrǎo yíxià","meanings":["sorry to interrupt"]}]'::jsonb,true,21,'greetings'),
('保重','bǎozhòng','take care','jaga diri baik-baik',1,'{}','[{"pinyin":"bǎozhòng","meanings":["take care"]}]'::jsonb,true,22,'greetings'),
-- Tema 2: Perkenalan Diri
('我叫','wǒ jiào','my name is','nama saya',1,'{}','[{"pinyin":"wǒ jiào","meanings":["my name is"]}]'::jsonb,true,23,'self_intro'),
('我的名字是','wǒ de míngzi shì','my name is','nama saya adalah',1,'{}','[{"pinyin":"wǒ de míngzi shì","meanings":["my name is"]}]'::jsonb,true,24,'self_intro'),
('你叫什么名字','nǐ jiào shénme míngzi','what is your name','siapa namamu',1,'{}','[{"pinyin":"nǐ jiào shénme míngzi","meanings":["what is your name"]}]'::jsonb,true,25,'self_intro'),
('名字','míngzi','name','nama',1,'{}','[{"pinyin":"míngzi","meanings":["name"]}]'::jsonb,true,26,'self_intro'),
('我是','wǒ shì','I am','saya adalah',1,'{}','[{"pinyin":"wǒ shì","meanings":["I am"]}]'::jsonb,true,27,'self_intro'),
('很高兴认识你','hěn gāoxìng rènshi nǐ','nice to meet you','senang berkenalan denganmu',1,'{}','[{"pinyin":"hěn gāoxìng rènshi nǐ","meanings":["nice to meet you"]}]'::jsonb,true,28,'self_intro'),
('认识你','rènshi nǐ','to know you','kenal kamu',1,'{}','[{"pinyin":"rènshi nǐ","meanings":["to know you"]}]'::jsonb,true,29,'self_intro'),
('朋友','péngyou','friend','teman',1,'{}','[{"pinyin":"péngyou","meanings":["friend"]}]'::jsonb,true,30,'self_intro'),
('我来自','wǒ láizì','I come from','saya berasal dari',1,'{}','[{"pinyin":"wǒ láizì","meanings":["I come from"]}]'::jsonb,true,31,'self_intro'),
('中国','Zhōngguó','China','Tiongkok',1,'{}','[{"pinyin":"Zhōngguó","meanings":["China"]}]'::jsonb,true,32,'self_intro'),
('印度尼西亚','Yìndùníxīyà','Indonesia','Indonesia',1,'{}','[{"pinyin":"Yìndùníxīyà","meanings":["Indonesia"]}]'::jsonb,true,33,'self_intro'),
('多大','duō dà','how old','berapa umur',1,'{}','[{"pinyin":"duō dà","meanings":["how old"]}]'::jsonb,true,34,'self_intro'),
('岁','suì','years old','tahun (umur)',1,'{}','[{"pinyin":"suì","meanings":["years old"]}]'::jsonb,true,35,'self_intro'),
('工作','gōngzuò','job / to work','pekerjaan',1,'{}','[{"pinyin":"gōngzuò","meanings":["job / to work"]}]'::jsonb,true,36,'self_intro'),
('学生','xuésheng','student','murid / siswa',1,'{}','[{"pinyin":"xuésheng","meanings":["student"]}]'::jsonb,true,37,'self_intro'),
('家','jiā','home / family','rumah / keluarga',1,'{}','[{"pinyin":"jiā","meanings":["home / family"]}]'::jsonb,true,38,'self_intro'),
('住在','zhùzài','to live in','tinggal di',1,'{}','[{"pinyin":"zhùzài","meanings":["to live in"]}]'::jsonb,true,39,'self_intro'),
('电话号码','diànhuà hàomǎ','phone number','nomor telepon',1,'{}','[{"pinyin":"diànhuà hàomǎ","meanings":["phone number"]}]'::jsonb,true,40,'self_intro'),
('结婚了吗','jiéhūn le ma','are you married','sudah menikah?',1,'{}','[{"pinyin":"jiéhūn le ma","meanings":["are you married"]}]'::jsonb,true,41,'self_intro'),
('单身','dānshēn','single (unmarried)','lajang',1,'{}','[{"pinyin":"dānshēn","meanings":["single (unmarried)"]}]'::jsonb,true,42,'self_intro'),
-- Tema 3: Angka
('零','líng','zero','nol',1,'{}','[{"pinyin":"líng","meanings":["zero"]}]'::jsonb,true,43,'numbers'),
('一','yī','one','satu',1,'{}','[{"pinyin":"yī","meanings":["one"]}]'::jsonb,true,44,'numbers'),
('二','èr','two','dua',1,'{}','[{"pinyin":"èr","meanings":["two"]}]'::jsonb,true,45,'numbers'),
('三','sān','three','tiga',1,'{}','[{"pinyin":"sān","meanings":["three"]}]'::jsonb,true,46,'numbers'),
('四','sì','four','empat',1,'{}','[{"pinyin":"sì","meanings":["four"]}]'::jsonb,true,47,'numbers'),
('五','wǔ','five','lima',1,'{}','[{"pinyin":"wǔ","meanings":["five"]}]'::jsonb,true,48,'numbers'),
('六','liù','six','enam',1,'{}','[{"pinyin":"liù","meanings":["six"]}]'::jsonb,true,49,'numbers'),
('七','qī','seven','tujuh',1,'{}','[{"pinyin":"qī","meanings":["seven"]}]'::jsonb,true,50,'numbers'),
('八','bā','eight','delapan',1,'{}','[{"pinyin":"bā","meanings":["eight"]}]'::jsonb,true,51,'numbers'),
('九','jiǔ','nine','sembilan',1,'{}','[{"pinyin":"jiǔ","meanings":["nine"]}]'::jsonb,true,52,'numbers'),
('十','shí','ten','sepuluh',1,'{}','[{"pinyin":"shí","meanings":["ten"]}]'::jsonb,true,53,'numbers'),
('百','bǎi','hundred','ratus',1,'{}','[{"pinyin":"bǎi","meanings":["hundred"]}]'::jsonb,true,54,'numbers'),
('千','qiān','thousand','ribu',1,'{}','[{"pinyin":"qiān","meanings":["thousand"]}]'::jsonb,true,55,'numbers'),
('半','bàn','half','setengah',1,'{}','[{"pinyin":"bàn","meanings":["half"]}]'::jsonb,true,56,'numbers'),
('多少','duōshao','how much / how many','berapa (jumlah)',1,'{}','[{"pinyin":"duōshao","meanings":["how much / how many"]}]'::jsonb,true,57,'numbers'),
('几','jǐ','how many (small numbers)','berapa (jumlah kecil)',1,'{}','[{"pinyin":"jǐ","meanings":["how many"]}]'::jsonb,true,58,'numbers'),
-- Tema 4: Situasi Darurat / Survival
('多少钱','duōshao qián','how much does it cost','berapa harganya',1,'{}','[{"pinyin":"duōshao qián","meanings":["how much does it cost"]}]'::jsonb,true,59,'survival'),
('太贵了','tài guì le','too expensive','terlalu mahal',1,'{}','[{"pinyin":"tài guì le","meanings":["too expensive"]}]'::jsonb,true,60,'survival'),
('便宜点','piányi diǎn','a bit cheaper','kasih murah dikit',1,'{}','[{"pinyin":"piányi diǎn","meanings":["a bit cheaper"]}]'::jsonb,true,61,'survival'),
('哪儿','nǎr','where','di mana',1,'{}','[{"pinyin":"nǎr","meanings":["where"]}]'::jsonb,true,62,'survival'),
('厕所','cèsuǒ','toilet','toilet',1,'{}','[{"pinyin":"cèsuǒ","meanings":["toilet"]}]'::jsonb,true,63,'survival'),
('厕所在哪儿','cèsuǒ zài nǎr','where is the toilet','toilet di mana',1,'{}','[{"pinyin":"cèsuǒ zài nǎr","meanings":["where is the toilet"]}]'::jsonb,true,64,'survival'),
('救命','jiùmìng','help! (emergency)','tolong! (darurat)',1,'{}','[{"pinyin":"jiùmìng","meanings":["help! (emergency)"]}]'::jsonb,true,65,'survival'),
('我不舒服','wǒ bù shūfu','I don''t feel well','saya tidak enak badan',1,'{}','[{"pinyin":"wǒ bù shūfu","meanings":["I don''t feel well"]}]'::jsonb,true,66,'survival'),
('医院','yīyuàn','hospital','rumah sakit',1,'{}','[{"pinyin":"yīyuàn","meanings":["hospital"]}]'::jsonb,true,67,'survival'),
('警察','jǐngchá','police','polisi',1,'{}','[{"pinyin":"jǐngchá","meanings":["police"]}]'::jsonb,true,68,'survival'),
('帮助','bāngzhù','help','bantuan / membantu',1,'{}','[{"pinyin":"bāngzhù","meanings":["help"]}]'::jsonb,true,69,'survival'),
('慢一点','màn yìdiǎn','a bit slower','pelan-pelan sedikit',1,'{}','[{"pinyin":"màn yìdiǎn","meanings":["a bit slower"]}]'::jsonb,true,70,'survival'),
('我听不懂','wǒ tīng bu dǒng','I don''t understand (hearing)','saya tidak mengerti',1,'{}','[{"pinyin":"wǒ tīng bu dǒng","meanings":["I don''t understand"]}]'::jsonb,true,71,'survival'),
('迷路了','mílù le','got lost','tersesat',1,'{}','[{"pinyin":"mílù le","meanings":["got lost"]}]'::jsonb,true,72,'survival'),
('护照','hùzhào','passport','paspor',1,'{}','[{"pinyin":"hùzhào","meanings":["passport"]}]'::jsonb,true,73,'survival'),
('机场','jīchǎng','airport','bandara',1,'{}','[{"pinyin":"jīchǎng","meanings":["airport"]}]'::jsonb,true,74,'survival'),
('出租车','chūzūchē','taxi','taksi',1,'{}','[{"pinyin":"chūzūchē","meanings":["taxi"]}]'::jsonb,true,75,'survival'),
('火车站','huǒchēzhàn','train station','stasiun kereta',1,'{}','[{"pinyin":"huǒchēzhàn","meanings":["train station"]}]'::jsonb,true,76,'survival'),
('手机','shǒujī','mobile phone','HP / ponsel',1,'{}','[{"pinyin":"shǒujī","meanings":["mobile phone"]}]'::jsonb,true,77,'survival'),
('密码','mìmǎ','password / PIN','kata sandi / PIN',1,'{}','[{"pinyin":"mìmǎ","meanings":["password / PIN"]}]'::jsonb,true,78,'survival'),
('药店','yàodiàn','pharmacy','apotek',1,'{}','[{"pinyin":"yàodiàn","meanings":["pharmacy"]}]'::jsonb,true,79,'survival'),
-- Tema 5: Respon Percakapan
('对','duì','correct','benar',1,'{}','[{"pinyin":"duì","meanings":["correct"]}]'::jsonb,true,80,'responses'),
('不对','bú duì','wrong','salah',1,'{}','[{"pinyin":"bú duì","meanings":["wrong"]}]'::jsonb,true,81,'responses'),
('不知道','bù zhīdào','don''t know','tidak tahu',1,'{}','[{"pinyin":"bù zhīdào","meanings":["don''t know"]}]'::jsonb,true,82,'responses'),
('听不懂','tīng bu dǒng','don''t understand (hearing)','tidak mengerti (dengar)',1,'{}','[{"pinyin":"tīng bu dǒng","meanings":["don''t understand"]}]'::jsonb,true,83,'responses'),
('请再说一遍','qǐng zài shuō yí biàn','please say it again','tolong ulangi sekali lagi',1,'{}','[{"pinyin":"qǐng zài shuō yí biàn","meanings":["please say it again"]}]'::jsonb,true,84,'responses'),
('可以','kěyǐ','can / may','boleh / bisa',1,'{}','[{"pinyin":"kěyǐ","meanings":["can / may"]}]'::jsonb,true,85,'responses'),
('不可以','bù kěyǐ','not allowed','tidak boleh',1,'{}','[{"pinyin":"bù kěyǐ","meanings":["not allowed"]}]'::jsonb,true,86,'responses'),
('没问题','méi wèntí','no problem','tidak masalah',1,'{}','[{"pinyin":"méi wèntí","meanings":["no problem"]}]'::jsonb,true,87,'responses'),
('好的','hǎo de','okay','oke / baik',1,'{}','[{"pinyin":"hǎo de","meanings":["okay"]}]'::jsonb,true,88,'responses'),
('当然','dāngrán','of course','tentu saja',1,'{}','[{"pinyin":"dāngrán","meanings":["of course"]}]'::jsonb,true,89,'responses'),
('也许','yěxǔ','maybe','mungkin',1,'{}','[{"pinyin":"yěxǔ","meanings":["maybe"]}]'::jsonb,true,90,'responses'),
('差不多','chàbuduō','almost / about the same','hampir sama / kira-kira',1,'{}','[{"pinyin":"chàbuduō","meanings":["almost the same"]}]'::jsonb,true,91,'responses'),
('没事','méishì','it''s nothing / no worries','tidak apa-apa',1,'{}','[{"pinyin":"méishì","meanings":["it''s nothing"]}]'::jsonb,true,92,'responses'),
('等一下','děng yíxià','wait a moment','tunggu sebentar',1,'{}','[{"pinyin":"děng yíxià","meanings":["wait a moment"]}]'::jsonb,true,93,'responses'),
('我同意','wǒ tóngyì','I agree','saya setuju',1,'{}','[{"pinyin":"wǒ tóngyì","meanings":["I agree"]}]'::jsonb,true,94,'responses'),
('我不同意','wǒ bù tóngyì','I disagree','saya tidak setuju',1,'{}','[{"pinyin":"wǒ bù tóngyì","meanings":["I disagree"]}]'::jsonb,true,95,'responses'),
('真的吗','zhēn de ma','really?','benarkah?',1,'{}','[{"pinyin":"zhēn de ma","meanings":["really?"]}]'::jsonb,true,96,'responses'),
('太好了','tài hǎo le','great!','bagus sekali!',1,'{}','[{"pinyin":"tài hǎo le","meanings":["great!"]}]'::jsonb,true,97,'responses'),
('加油','jiāyóu','go for it! (cheer)','semangat!',1,'{}','[{"pinyin":"jiāyóu","meanings":["go for it!"]}]'::jsonb,true,98,'responses'),
('随便','suíbiàn','whatever / up to you','terserah',1,'{}','[{"pinyin":"suíbiàn","meanings":["whatever"]}]'::jsonb,true,99,'responses'),
('我也是','wǒ yěshì','me too','saya juga',1,'{}','[{"pinyin":"wǒ yěshì","meanings":["me too"]}]'::jsonb,true,100,'responses')
ON CONFLICT (hanzi) DO UPDATE SET
  beginner_kit = true,
  beginner_order = EXCLUDED.beginner_order,
  beginner_theme = EXCLUDED.beginner_theme,
  meaning_id = COALESCE(vocab.meaning_id, EXCLUDED.meaning_id);
