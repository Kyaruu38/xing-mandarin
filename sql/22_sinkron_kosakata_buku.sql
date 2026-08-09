-- ============================================================================
-- 22_sinkron_kosakata_buku.sql
--
-- MASALAH YANG DIPERBAIKI
-- Deck Business di web punya 60 kata dengan tema sendiri (Rapat, Negosiasi,
-- Presentasi, Email, Keuangan, Jabatan). Bukunya punya 469 kata yang ditata per
-- bab. Dua sumber, isinya beda. Murid yang pegang buku dan buka web akan lihat
-- daftar yang tidak sama, dan tidak ada cara tahu mana yang benar.
--
-- KEPUTUSAN: BUKU JADI SATU-SATUNYA SUMBER KEBENARAN.
-- Semua kosakata buku masuk ke track 'business', ditata per bab. Enam tema lama
-- dipetakan ke bab yang isinya sama -- bukan dihapus, cuma dipindah rumah:
--     Jabatan    -> Bab 1 (Perkenalan Profesional)
--     Email      -> Bab 6 (Telepon, Chat & Email)
--     Rapat      -> Bab 4 (Rapat & Penjadwalan)
--     Negosiasi  -> Bab 8 (Negosiasi)
--     Keuangan   -> Bab 8 (Negosiasi -- istilah pembayaran memang dipakai di sini)
--     Presentasi -> Bab 9 (Presentasi)
--
-- YANG SENGAJA TIDAK DILAKUKAN
-- Contoh kalimat pada 60 kata lama TIDAK ditimpa. Kata dari buku belum punya
-- contoh kalimat, jadi kalau di-UPDATE apa adanya, contoh yang sudah bagus akan
-- tertimpa NULL. Bagian (3) memakai coalesce supaya contoh lama selalu menang.
--
-- Track 'convo' TIDAK DISENTUH -- belum ada bukunya, temanya tetap per topik.
--
-- CARA PAKAI: jalankan apa adanya (diakhiri ROLLBACK), periksa angkanya, baru
-- ganti ROLLBACK jadi COMMIT.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- (1) Dua kolom baru. `chapter` dipakai untuk mengurutkan; `source` dipakai
--     supaya nanti ketahuan mana kata yang datang dari buku dan mana yang tidak.
-- ---------------------------------------------------------------------------
ALTER TABLE public.vocab_track ADD COLUMN IF NOT EXISTS chapter smallint;
ALTER TABLE public.vocab_track ADD COLUMN IF NOT EXISTS source  text
  NOT NULL DEFAULT 'deck';
ALTER TABLE public.vocab_track DROP CONSTRAINT IF EXISTS vocab_track_source_check;
ALTER TABLE public.vocab_track ADD CONSTRAINT vocab_track_source_check
  CHECK (source IN ('deck','buku'));

DROP INDEX IF EXISTS vocab_track_track_theme_idx;
CREATE INDEX IF NOT EXISTS vocab_track_urut_idx
  ON public.vocab_track (track, chapter, sort_order);

-- ---------------------------------------------------------------------------
-- (2) Pindahkan enam tema lama ke bab yang sesuai. Kata-kata ini tetap 'deck'
--     supaya jejaknya tidak hilang -- yang berubah cuma rumahnya.
-- ---------------------------------------------------------------------------
UPDATE public.vocab_track SET theme = 'Bab 1 - Perkenalan Profesional',   chapter = 1 WHERE track='business' AND theme='Jabatan';
UPDATE public.vocab_track SET theme = 'Bab 6 - Telepon, Chat & Email',    chapter = 6 WHERE track='business' AND theme='Email';
UPDATE public.vocab_track SET theme = 'Bab 4 - Rapat & Penjadwalan',      chapter = 4 WHERE track='business' AND theme='Rapat';
UPDATE public.vocab_track SET theme = 'Bab 8 - Negosiasi',                chapter = 8 WHERE track='business' AND theme IN ('Negosiasi','Keuangan');
UPDATE public.vocab_track SET theme = 'Bab 9 - Presentasi',               chapter = 9 WHERE track='business' AND theme='Presentasi';

-- ---------------------------------------------------------------------------
-- (3) Muat 469 kosakata buku.
--     Urutan kolom: hanzi|pinyin|en|id|tema|bab|urut
--
--     ON CONFLICT memakai coalesce dua arah: bab dan tema selalu ikut buku
--     (buku yang jadi acuan), tapi contoh kalimat memakai yang sudah ada dulu
--     dan hanya diisi dari buku kalau sebelumnya kosong. Tanpa coalesce itu,
--     perintah ini akan menghapus 60 contoh kalimat yang sudah ditulis.
-- ---------------------------------------------------------------------------
WITH baris AS (
  SELECT string_to_array(btrim(replace(l, chr(13), '')), '|') AS c
  FROM unnest(string_to_array($blob$
零|líng|zero|nol|Bab 0 · Dasar Mandarin|0|0
一|yī|one|satu|Bab 0 · Dasar Mandarin|0|1
二|èr|two|dua|Bab 0 · Dasar Mandarin|0|2
三|sān|three|tiga|Bab 0 · Dasar Mandarin|0|3
四|sì|four|empat|Bab 0 · Dasar Mandarin|0|4
五|wǔ|five|lima|Bab 0 · Dasar Mandarin|0|5
六|liù|six|enam|Bab 0 · Dasar Mandarin|0|6
七|qī|seven|tujuh|Bab 0 · Dasar Mandarin|0|7
八|bā|eight|delapan|Bab 0 · Dasar Mandarin|0|8
九|jiǔ|nine|sembilan|Bab 0 · Dasar Mandarin|0|9
十|shí|ten|sepuluh|Bab 0 · Dasar Mandarin|0|10
百|bǎi|hundred|ratus|Bab 0 · Dasar Mandarin|0|11
千|qiān|thousand|ribu|Bab 0 · Dasar Mandarin|0|12
万|wàn|ten thousand|sepuluh ribu|Bab 0 · Dasar Mandarin|0|13
两|liǎng|two (before a measure word)|dua (sebelum kata bantu bilangan)|Bab 0 · Dasar Mandarin|0|14
年|nián|year|tahun|Bab 0 · Dasar Mandarin|0|15
月|yuè|month|bulan|Bab 0 · Dasar Mandarin|0|16
号|hào|date (spoken)|tanggal (lisan)|Bab 0 · Dasar Mandarin|0|17
日|rì|date (written)|tanggal (tulisan resmi)|Bab 0 · Dasar Mandarin|0|18
星期|xīngqī|week|minggu|Bab 0 · Dasar Mandarin|0|19
今天|jīntiān|today|hari ini|Bab 0 · Dasar Mandarin|0|20
明天|míngtiān|tomorrow|besok|Bab 0 · Dasar Mandarin|0|21
昨天|zuótiān|yesterday|kemarin|Bab 0 · Dasar Mandarin|0|22
点|diǎn|o’clock|pukul|Bab 0 · Dasar Mandarin|0|23
分|fēn|minute|menit|Bab 0 · Dasar Mandarin|0|24
半|bàn|half|setengah|Bab 0 · Dasar Mandarin|0|25
上午|shàngwǔ|morning (before noon)|pagi sampai menjelang siang|Bab 0 · Dasar Mandarin|0|26
中午|zhōngwǔ|noon|tengah hari|Bab 0 · Dasar Mandarin|0|27
下午|xiàwǔ|afternoon|siang sampai sore|Bab 0 · Dasar Mandarin|0|28
晚上|wǎnshang|evening|malam|Bab 0 · Dasar Mandarin|0|29
现在|xiànzài|now|sekarang|Bab 0 · Dasar Mandarin|0|30
钱|qián|money|uang|Bab 0 · Dasar Mandarin|0|31
块|kuài|unit of currency (spoken)|satuan mata uang (lisan)|Bab 0 · Dasar Mandarin|0|32
元|yuán|yuan (written)|yuan (tulisan)|Bab 0 · Dasar Mandarin|0|33
人民币|rénmínbì|renminbi, RMB|renminbi, mata uang Tiongkok|Bab 0 · Dasar Mandarin|0|34
印尼盾|yìnídùn|Indonesian rupiah|rupiah|Bab 0 · Dasar Mandarin|0|35
多少|duōshao|how many, how much|berapa (jumlah besar)|Bab 0 · Dasar Mandarin|0|36
几|jǐ|how many (small number)|berapa (jumlah kecil)|Bab 0 · Dasar Mandarin|0|37
电话|diànhuà|telephone|telepon|Bab 0 · Dasar Mandarin|0|38
号码|hàomǎ|number|nomor|Bab 0 · Dasar Mandarin|0|39
你好|nǐ hǎo|hello|halo|Bab 0 · Dasar Mandarin|0|40
您好|nín hǎo|hello (polite)|halo (sopan)|Bab 0 · Dasar Mandarin|0|41
谢谢|xièxie|thank you|terima kasih|Bab 0 · Dasar Mandarin|0|42
不客气|bú kèqi|you’re welcome|sama-sama|Bab 0 · Dasar Mandarin|0|43
对不起|duìbuqǐ|sorry|maaf|Bab 0 · Dasar Mandarin|0|44
没关系|méi guānxi|it’s all right|tidak apa-apa|Bab 0 · Dasar Mandarin|0|45
请问|qǐngwèn|excuse me, may I ask|permisi, boleh bertanya|Bab 0 · Dasar Mandarin|0|46
再见|zàijiàn|goodbye|sampai jumpa|Bab 0 · Dasar Mandarin|0|47
我|wǒ|I, me|saya|Bab 1 · Perkenalan Profesional|1|100
您|nín|you (polite)|Anda|Bab 1 · Perkenalan Profesional|1|101
叫|jiào|to be called|bernama, dipanggil|Bab 1 · Perkenalan Profesional|1|102
名字|míngzi|name|nama|Bab 1 · Perkenalan Profesional|1|103
姓|xìng|surname; to be surnamed|marga; bermarga|Bab 1 · Perkenalan Profesional|1|104
是|shì|to be|adalah|Bab 1 · Perkenalan Profesional|1|105
的|de|possessive / modifier particle|partikel kepemilikan|Bab 1 · Perkenalan Profesional|1|106
公司|gōngsī|company|perusahaan|Bab 1 · Perkenalan Profesional|1|107
工作|gōngzuò|work; to work|pekerjaan; bekerja|Bab 1 · Perkenalan Profesional|1|108
职位|zhíwèi|position, job title|jabatan|Bab 1 · Perkenalan Profesional|1|109
部门|bùmén|department|departemen|Bab 1 · Perkenalan Profesional|1|110
经理|jīnglǐ|manager|manajer|Bab 1 · Perkenalan Profesional|1|111
总经理|zǒngjīnglǐ|general manager|direktur, GM|Bab 1 · Perkenalan Profesional|1|112
主管|zhǔguǎn|supervisor|supervisor|Bab 1 · Perkenalan Profesional|1|113
助理|zhùlǐ|assistant|asisten|Bab 1 · Perkenalan Profesional|1|114
同事|tóngshì|colleague|rekan kerja|Bab 1 · Perkenalan Profesional|1|115
老板|lǎobǎn|boss|atasan, bos|Bab 1 · Perkenalan Profesional|1|116
员工|yuángōng|employee, staff|karyawan|Bab 1 · Perkenalan Profesional|1|117
销售部|xiāoshòubù|sales department|departemen penjualan|Bab 1 · Perkenalan Profesional|1|118
市场部|shìchǎngbù|marketing department|departemen pemasaran|Bab 1 · Perkenalan Profesional|1|119
财务部|cáiwùbù|finance department|departemen keuangan|Bab 1 · Perkenalan Profesional|1|120
人事部|rénshìbù|HR department|departemen personalia|Bab 1 · Perkenalan Profesional|1|121
采购部|cǎigòubù|purchasing department|departemen pembelian|Bab 1 · Perkenalan Profesional|1|122
生产部|shēngchǎnbù|production department|departemen produksi|Bab 1 · Perkenalan Profesional|1|123
负责|fùzé|to be in charge of|bertanggung jawab atas|Bab 1 · Perkenalan Profesional|1|124
主要|zhǔyào|mainly, chiefly|terutama|Bab 1 · Perkenalan Profesional|1|125
在|zài|at, in|di|Bab 1 · Perkenalan Profesional|1|126
做|zuò|to do|melakukan, mengerjakan|Bab 1 · Perkenalan Profesional|1|127
大学|dàxué|university|universitas|Bab 1 · Perkenalan Profesional|1|128
专业|zhuānyè|major, field of study|jurusan|Bab 1 · Perkenalan Profesional|1|129
毕业|bìyè|to graduate|lulus|Bab 1 · Perkenalan Profesional|1|130
经验|jīngyàn|experience|pengalaman|Bab 1 · Perkenalan Profesional|1|131
以前|yǐqián|before, previously|sebelumnya|Bab 1 · Perkenalan Profesional|1|133
印尼|Yìnní|Indonesia|Indonesia|Bab 1 · Perkenalan Profesional|1|135
中国|Zhōngguó|China|Tiongkok|Bab 1 · Perkenalan Profesional|1|136
人|rén|person|orang|Bab 1 · Perkenalan Profesional|1|137
认识|rènshi|to get to know|berkenalan, mengenal|Bab 1 · Perkenalan Profesional|1|138
高兴|gāoxìng|glad, pleased|senang|Bab 1 · Perkenalan Profesional|1|139
名片|míngpiàn|business card|kartu nama|Bab 1 · Perkenalan Profesional|1|140
这|zhè|this|ini|Bab 1 · Perkenalan Profesional|1|141
那|nà|that|itu|Bab 1 · Perkenalan Profesional|1|142
多久|duō jiǔ|how long|berapa lama|Bab 1 · Perkenalan Profesional|1|143
请多关照|qǐng duō guānzhào|please take good care of me|mohon bimbingannya|Bab 1 · Perkenalan Profesional|1|144
早上好|zǎoshang hǎo|good morning|selamat pagi|Bab 2 · Komunikasi Kantor|2|200
下午好|xiàwǔ hǎo|good afternoon|selamat siang|Bab 2 · Komunikasi Kantor|2|201
最近|zuìjìn|lately, recently|belakangan ini|Bab 2 · Komunikasi Kantor|2|202
怎么样|zěnmeyàng|how is it going|bagaimana|Bab 2 · Komunikasi Kantor|2|203
忙|máng|busy|sibuk|Bab 2 · Komunikasi Kantor|2|204
累|lèi|tired|lelah|Bab 2 · Komunikasi Kantor|2|205
还行|hái xíng|not bad, OK|lumayan|Bab 2 · Komunikasi Kantor|2|206
帮|bāng|to help|membantu|Bab 2 · Komunikasi Kantor|2|207
帮忙|bāngmáng|to lend a hand|membantu, menolong|Bab 2 · Komunikasi Kantor|2|208
帮我|bāng wǒ|help me|bantu saya|Bab 2 · Komunikasi Kantor|2|209
可以|kěyǐ|can, may|boleh, bisa|Bab 2 · Komunikasi Kantor|2|210
能|néng|to be able to|dapat, mampu|Bab 2 · Komunikasi Kantor|2|211
请|qǐng|please; to invite|tolong; mempersilakan|Bab 2 · Komunikasi Kantor|2|212
一下|yíxià|a moment, briefly|sebentar|Bab 2 · Komunikasi Kantor|2|213
麻烦|máfan|to trouble someone; troublesome|merepotkan; merepotkan|Bab 2 · Komunikasi Kantor|2|214
不好意思|bù hǎoyìsi|excuse me, sorry (light)|maaf (ringan), nggak enak hati|Bab 2 · Komunikasi Kantor|2|215
请假|qǐngjià|to ask for leave|minta izin tidak masuk|Bab 2 · Komunikasi Kantor|2|216
迟到|chídào|to be late|terlambat|Bab 2 · Komunikasi Kantor|2|217
早退|zǎotuì|to leave early|pulang lebih awal|Bab 2 · Komunikasi Kantor|2|218
出去|chūqu|to go out|keluar|Bab 2 · Komunikasi Kantor|2|219
回来|huílai|to come back|kembali|Bab 2 · Komunikasi Kantor|2|220
马上|mǎshàng|right away|segera|Bab 2 · Komunikasi Kantor|2|221
等一下|děng yíxià|wait a moment|tunggu sebentar|Bab 2 · Komunikasi Kantor|2|222
哪儿|nǎr|where|di mana|Bab 2 · Komunikasi Kantor|2|223
这儿|zhèr|here|di sini|Bab 2 · Komunikasi Kantor|2|224
那儿|nàr|there|di sana|Bab 2 · Komunikasi Kantor|2|225
办公室|bàngōngshì|office room|ruang kantor|Bab 2 · Komunikasi Kantor|2|226
会议室|huìyìshì|meeting room|ruang rapat|Bab 2 · Komunikasi Kantor|2|227
洗手间|xǐshǒujiān|restroom|toilet|Bab 2 · Komunikasi Kantor|2|228
前台|qiántái|reception desk|resepsionis|Bab 2 · Komunikasi Kantor|2|229
楼上|lóushàng|upstairs|lantai atas|Bab 2 · Komunikasi Kantor|2|230
楼下|lóuxià|downstairs|lantai bawah|Bab 2 · Komunikasi Kantor|2|231
旁边|pángbiān|beside, next to|di sebelah|Bab 2 · Komunikasi Kantor|2|232
里面|lǐmiàn|inside|di dalam|Bab 2 · Komunikasi Kantor|2|233
电脑|diànnǎo|computer|komputer|Bab 2 · Komunikasi Kantor|2|234
文件|wénjiàn|document, file|dokumen, berkas|Bab 2 · Komunikasi Kantor|2|235
打印|dǎyìn|to print|mencetak|Bab 2 · Komunikasi Kantor|2|236
复印|fùyìn|to photocopy|memfotokopi|Bab 2 · Komunikasi Kantor|2|237
发|fā|to send|mengirim|Bab 2 · Komunikasi Kantor|2|238
拿|ná|to take, to fetch|mengambil|Bab 2 · Komunikasi Kantor|2|239
找|zhǎo|to look for|mencari|Bab 2 · Komunikasi Kantor|2|240
用|yòng|to use|memakai|Bab 2 · Komunikasi Kantor|2|241
没问题|méi wèntí|no problem|tidak masalah|Bab 2 · Komunikasi Kantor|2|242
辛苦了|xīnkǔ le|thanks for your hard work|terima kasih sudah bekerja keras|Bab 2 · Komunikasi Kantor|2|243
什么|shénme|what|apa|Bab 3 · Bertanya & Memberi Informasi|3|300
谁|shéi|who|siapa|Bab 3 · Bertanya & Memberi Informasi|3|301
哪个|nǎge|which|yang mana|Bab 3 · Bertanya & Memberi Informasi|3|302
为什么|wèishénme|why|kenapa|Bab 3 · Bertanya & Memberi Informasi|3|303
怎么|zěnme|how|bagaimana|Bab 3 · Bertanya & Memberi Informasi|3|304
什么时候|shénme shíhou|when|kapan|Bab 3 · Bertanya & Memberi Informasi|3|305
吗|ma|question particle|partikel kalimat tanya|Bab 3 · Bertanya & Memberi Informasi|3|306
呢|ne|and how about…?|kalau…?|Bab 3 · Bertanya & Memberi Informasi|3|307
问|wèn|to ask|bertanya|Bab 3 · Bertanya & Memberi Informasi|3|308
回答|huídá|to answer|menjawab|Bab 3 · Bertanya & Memberi Informasi|3|309
告诉|gàosu|to tell|memberi tahu|Bab 3 · Bertanya & Memberi Informasi|3|310
知道|zhīdào|to know|tahu|Bab 3 · Bertanya & Memberi Informasi|3|311
明白|míngbai|to understand|paham|Bab 3 · Bertanya & Memberi Informasi|3|312
清楚|qīngchu|clear|jelas|Bab 3 · Bertanya & Memberi Informasi|3|313
确认|quèrèn|to confirm|mengonfirmasi|Bab 3 · Bertanya & Memberi Informasi|3|314
意思|yìsi|meaning|maksud, arti|Bab 3 · Bertanya & Memberi Informasi|3|315
情况|qíngkuàng|situation|situasi, kondisi|Bab 3 · Bertanya & Memberi Informasi|3|316
内容|nèiróng|content|isi|Bab 3 · Bertanya & Memberi Informasi|3|317
项目|xiàngmù|project|proyek|Bab 3 · Bertanya & Memberi Informasi|3|318
任务|rènwu|task|tugas|Bab 3 · Bertanya & Memberi Informasi|3|319
报告|bàogào|report|laporan|Bab 3 · Bertanya & Memberi Informasi|3|320
数据|shùjù|data|data|Bab 3 · Bertanya & Memberi Informasi|3|321
进度|jìndù|progress|progres|Bab 3 · Bertanya & Memberi Informasi|3|322
完成|wánchéng|to complete|menyelesaikan|Bab 3 · Bertanya & Memberi Informasi|3|323
开始|kāishǐ|to start|memulai|Bab 3 · Bertanya & Memberi Informasi|3|324
结束|jiéshù|to end|berakhir|Bab 3 · Bertanya & Memberi Informasi|3|325
负责人|fùzérén|person in charge|penanggung jawab|Bab 3 · Bertanya & Memberi Informasi|3|326
每天|měi tiān|every day|setiap hari|Bab 3 · Bertanya & Memberi Informasi|3|327
常常|chángcháng|often|sering|Bab 3 · Bertanya & Memberi Informasi|3|328
有时候|yǒu shíhou|sometimes|kadang-kadang|Bab 3 · Bertanya & Memberi Informasi|3|329
先|xiān|first|lebih dulu|Bab 3 · Bertanya & Memberi Informasi|3|330
然后|ránhòu|then, after that|lalu|Bab 3 · Bertanya & Memberi Informasi|3|331
最后|zuìhòu|finally|terakhir|Bab 3 · Bertanya & Memberi Informasi|3|332
因为|yīnwèi|because|karena|Bab 3 · Bertanya & Memberi Informasi|3|333
所以|suǒyǐ|so, therefore|jadi|Bab 3 · Bertanya & Memberi Informasi|3|334
如果|rúguǒ|if|kalau|Bab 3 · Bertanya & Memberi Informasi|3|335
需要|xūyào|to need|memerlukan|Bab 3 · Bertanya & Memberi Informasi|3|336
重要|zhòngyào|important|penting|Bab 3 · Bertanya & Memberi Informasi|3|337
具体|jùtǐ|specific, in detail|spesifik, rinci|Bab 3 · Bertanya & Memberi Informasi|3|338
大概|dàgài|roughly, about|kira-kira|Bab 3 · Bertanya & Memberi Informasi|3|339
一共|yígòng|in total|total|Bab 3 · Bertanya & Memberi Informasi|3|340
再说一遍|zài shuō yí biàn|say it again|ulangi sekali lagi|Bab 3 · Bertanya & Memberi Informasi|3|341
也就是说|yě jiùshì shuō|in other words|dengan kata lain|Bab 3 · Bertanya & Memberi Informasi|3|342
对不对|duì bu duì|is that right|benar tidak|Bab 3 · Bertanya & Memberi Informasi|3|343
会议|huìyì|meeting|rapat|Bab 4 · Rapat & Penjadwalan|4|400
开会|kāihuì|to hold a meeting|mengadakan rapat|Bab 4 · Rapat & Penjadwalan|4|401
安排|ānpái|to arrange, to schedule|mengatur, menjadwalkan|Bab 4 · Rapat & Penjadwalan|4|402
日程|rìchéng|schedule, agenda|jadwal|Bab 4 · Rapat & Penjadwalan|4|403
议程|yìchéng|agenda|agenda|Bab 4 · Rapat & Penjadwalan|4|404
约|yuē|to make an appointment|membuat janji|Bab 4 · Rapat & Penjadwalan|4|405
时间|shíjiān|time|waktu|Bab 4 · Rapat & Penjadwalan|4|406
地点|dìdiǎn|venue, location|tempat|Bab 4 · Rapat & Penjadwalan|4|407
参加|cānjiā|to attend|menghadiri|Bab 4 · Rapat & Penjadwalan|4|408
出席|chūxí|to be present|hadir|Bab 4 · Rapat & Penjadwalan|4|409
缺席|quēxí|to be absent|tidak hadir|Bab 4 · Rapat & Penjadwalan|4|410
推迟|tuīchí|to postpone|menunda|Bab 4 · Rapat & Penjadwalan|4|411
提前|tíqián|to move up, in advance|memajukan, lebih awal|Bab 4 · Rapat & Penjadwalan|4|412
取消|qǔxiāo|to cancel|membatalkan|Bab 4 · Rapat & Penjadwalan|4|413
改|gǎi|to change|mengubah|Bab 4 · Rapat & Penjadwalan|4|414
方便|fāngbiàn|convenient|nyaman, memungkinkan|Bab 4 · Rapat & Penjadwalan|4|415
有空|yǒu kòng|to be free|ada waktu luang|Bab 4 · Rapat & Penjadwalan|4|416
没空|méi kòng|to be busy, not free|tidak ada waktu|Bab 4 · Rapat & Penjadwalan|4|417
合适|héshì|suitable|cocok|Bab 4 · Rapat & Penjadwalan|4|418
准时|zhǔnshí|on time|tepat waktu|Bab 4 · Rapat & Penjadwalan|4|419
大约|dàyuē|approximately|kira-kira|Bab 4 · Rapat & Penjadwalan|4|420
小时|xiǎoshí|hour|jam (durasi)|Bab 4 · Rapat & Penjadwalan|4|421
分钟|fēnzhōng|minute|menit (durasi)|Bab 4 · Rapat & Penjadwalan|4|422
下周|xià zhōu|next week|minggu depan|Bab 4 · Rapat & Penjadwalan|4|423
上周|shàng zhōu|last week|minggu lalu|Bab 4 · Rapat & Penjadwalan|4|424
今天下午|jīntiān xiàwǔ|this afternoon|siang ini|Bab 4 · Rapat & Penjadwalan|4|425
记录|jìlù|minutes; to record|notulen; mencatat|Bab 4 · Rapat & Penjadwalan|4|426
主持|zhǔchí|to chair, to host|memimpin|Bab 4 · Rapat & Penjadwalan|4|427
发言|fāyán|to speak, to take the floor|berbicara, menyampaikan|Bab 4 · Rapat & Penjadwalan|4|428
讨论|tǎolùn|to discuss|membahas|Bab 4 · Rapat & Penjadwalan|4|429
决定|juédìng|to decide; decision|memutuskan; keputusan|Bab 4 · Rapat & Penjadwalan|4|430
总结|zǒngjié|to summarize; summary|merangkum; rangkuman|Bab 4 · Rapat & Penjadwalan|4|431
下次|xià cì|next time|lain kali|Bab 4 · Rapat & Penjadwalan|4|432
通知|tōngzhī|to notify; notice|memberi tahu; pemberitahuan|Bab 4 · Rapat & Penjadwalan|4|433
确定|quèdìng|to confirm, to finalize|memastikan|Bab 4 · Rapat & Penjadwalan|4|434
议题|yìtí|agenda item, topic|topik bahasan|Bab 4 · Rapat & Penjadwalan|4|435
首先|shǒuxiān|first of all|pertama-tama|Bab 4 · Rapat & Penjadwalan|4|436
其次|qícì|secondly|kedua|Bab 4 · Rapat & Penjadwalan|4|437
线上|xiànshàng|online|daring|Bab 4 · Rapat & Penjadwalan|4|440
链接|liànjiē|link|tautan|Bab 4 · Rapat & Penjadwalan|4|441
日历|rìlì|calendar|kalender|Bab 4 · Rapat & Penjadwalan|4|442
提醒|tíxǐng|to remind|mengingatkan|Bab 4 · Rapat & Penjadwalan|4|443
意见|yìjiàn|opinion|pendapat|Bab 5 · Diskusi Bisnis|5|500
看法|kànfǎ|view, standpoint|pandangan|Bab 5 · Diskusi Bisnis|5|501
觉得|juéde|to feel, to think|merasa, berpendapat|Bab 5 · Diskusi Bisnis|5|502
认为|rènwéi|to believe, to hold that|berpendapat (formal)|Bab 5 · Diskusi Bisnis|5|503
同意|tóngyì|to agree|setuju|Bab 5 · Diskusi Bisnis|5|504
赞成|zànchéng|to be in favour of|mendukung|Bab 5 · Diskusi Bisnis|5|505
反对|fǎnduì|to oppose|menentang|Bab 5 · Diskusi Bisnis|5|506
建议|jiànyì|to suggest; suggestion|menyarankan; saran|Bab 5 · Diskusi Bisnis|5|507
提议|tíyì|to propose; proposal|mengusulkan; usulan|Bab 5 · Diskusi Bisnis|5|508
方案|fāng’àn|plan, proposal|skema, rencana|Bab 5 · Diskusi Bisnis|5|509
办法|bànfǎ|method, way|cara|Bab 5 · Diskusi Bisnis|5|510
问题|wèntí|problem, question|masalah, pertanyaan|Bab 5 · Diskusi Bisnis|5|511
解决|jiějué|to solve|menyelesaikan|Bab 5 · Diskusi Bisnis|5|512
考虑|kǎolǜ|to consider|mempertimbangkan|Bab 5 · Diskusi Bisnis|5|513
补充|bǔchōng|to add (a point)|menambahkan|Bab 5 · Diskusi Bisnis|5|515
打断|dǎduàn|to interrupt|memotong pembicaraan|Bab 5 · Diskusi Bisnis|5|516
插一句|chā yí jù|to cut in briefly|menyela sebentar|Bab 5 · Diskusi Bisnis|5|517
可能|kěnéng|maybe, possibly|mungkin|Bab 5 · Diskusi Bisnis|5|518
也许|yěxǔ|perhaps|barangkali|Bab 5 · Diskusi Bisnis|5|519
应该|yīnggāi|should|seharusnya|Bab 5 · Diskusi Bisnis|5|520
最好|zuì hǎo|it would be best|sebaiknya|Bab 5 · Diskusi Bisnis|5|521
不过|búguò|however|tapi|Bab 5 · Diskusi Bisnis|5|522
但是|dànshì|but|tetapi|Bab 5 · Diskusi Bisnis|5|523
虽然|suīrán|although|meskipun|Bab 5 · Diskusi Bisnis|5|524
其实|qíshí|actually|sebenarnya|Bab 5 · Diskusi Bisnis|5|525
比较|bǐjiào|relatively, fairly|relatif, agak|Bab 5 · Diskusi Bisnis|5|526
有道理|yǒu dàolǐ|that makes sense|masuk akal|Bab 5 · Diskusi Bisnis|5|527
同感|tónggǎn|I feel the same|sependapat|Bab 5 · Diskusi Bisnis|5|528
风险|fēngxiǎn|risk|risiko|Bab 5 · Diskusi Bisnis|5|529
成本|chéngběn|cost|biaya|Bab 5 · Diskusi Bisnis|5|530
效率|xiàolǜ|efficiency|efisiensi|Bab 5 · Diskusi Bisnis|5|531
质量|zhìliàng|quality|kualitas|Bab 5 · Diskusi Bisnis|5|532
时间表|shíjiānbiǎo|timeline|linimasa|Bab 5 · Diskusi Bisnis|5|533
优点|yōudiǎn|advantage|kelebihan|Bab 5 · Diskusi Bisnis|5|534
缺点|quēdiǎn|drawback|kekurangan|Bab 5 · Diskusi Bisnis|5|535
从…来看|cóng…lái kàn|from the perspective of…|dilihat dari…|Bab 5 · Diskusi Bisnis|5|536
另外|lìngwài|besides, in addition|selain itu|Bab 5 · Diskusi Bisnis|5|537
总的来说|zǒng de lái shuō|overall|secara keseluruhan|Bab 5 · Diskusi Bisnis|5|538
支持|zhīchí|to support|mendukung|Bab 5 · Diskusi Bisnis|5|539
修改|xiūgǎi|to revise|merevisi|Bab 5 · Diskusi Bisnis|5|540
试试|shìshi|to give it a try|coba dulu|Bab 5 · Diskusi Bisnis|5|541
先这样|xiān zhèyàng|let’s leave it like this for now|untuk sekarang begini dulu|Bab 5 · Diskusi Bisnis|5|542
再看看|zài kànkan|let’s see how it goes|lihat nanti|Bab 5 · Diskusi Bisnis|5|543
打电话|dǎ diànhuà|to make a phone call|menelepon|Bab 6 · Telepon, Chat & Email|6|600
接电话|jiē diànhuà|to answer the phone|mengangkat telepon|Bab 6 · Telepon, Chat & Email|6|601
喂|wéi|hello (on the phone)|halo (di telepon)|Bab 6 · Telepon, Chat & Email|6|602
请问您是哪位|qǐngwèn nín shì nǎ wèi|who’s calling, please|boleh tahu ini siapa|Bab 6 · Telepon, Chat & Email|6|603
转|zhuǎn|to transfer (a call)|menyambungkan|Bab 6 · Telepon, Chat & Email|6|604
分机|fēnjī|extension|ekstensi|Bab 6 · Telepon, Chat & Email|6|605
占线|zhànxiàn|the line is busy|saluran sibuk|Bab 6 · Telepon, Chat & Email|6|606
留言|liúyán|to leave a message|meninggalkan pesan|Bab 6 · Telepon, Chat & Email|6|607
回电|huídiàn|to call back|menelepon balik|Bab 6 · Telepon, Chat & Email|6|608
听不清|tīng bu qīng|can’t hear clearly|tidak terdengar jelas|Bab 6 · Telepon, Chat & Email|6|609
信号|xìnhào|signal|sinyal|Bab 6 · Telepon, Chat & Email|6|610
挂|guà|to hang up|menutup telepon|Bab 6 · Telepon, Chat & Email|6|611
微信|Wēixìn|WeChat|WeChat|Bab 6 · Telepon, Chat & Email|6|612
消息|xiāoxi|message|pesan|Bab 6 · Telepon, Chat & Email|6|613
发给|fā gěi|to send to|kirim ke|Bab 6 · Telepon, Chat & Email|6|614
收到|shōudào|to receive|menerima, sudah terima|Bab 6 · Telepon, Chat & Email|6|615
回复|huífù|to reply|membalas|Bab 6 · Telepon, Chat & Email|6|616
附件|fùjiàn|attachment|lampiran|Bab 6 · Telepon, Chat & Email|6|617
邮件|yóujiàn|email|email|Bab 6 · Telepon, Chat & Email|6|618
主题|zhǔtí|subject line|subjek|Bab 6 · Telepon, Chat & Email|6|619
尊敬的|zūnjìng de|dear (formal)|yang terhormat|Bab 6 · Telepon, Chat & Email|6|620
此致敬礼|cǐzhì jìnglǐ|yours sincerely|hormat kami|Bab 6 · Telepon, Chat & Email|6|622
祝好|zhù hǎo|best regards|salam|Bab 6 · Telepon, Chat & Email|6|623
跟进|gēnjìn|to follow up|menindaklanjuti|Bab 6 · Telepon, Chat & Email|6|624
催|cuī|to urge, to chase|menagih, mengejar|Bab 6 · Telepon, Chat & Email|6|625
提醒一下|tíxǐng yíxià|just a reminder|sekadar mengingatkan|Bab 6 · Telepon, Chat & Email|6|626
尽快|jǐnkuài|as soon as possible|secepatnya|Bab 6 · Telepon, Chat & Email|6|627
截止|jiézhǐ|deadline|batas waktu|Bab 6 · Telepon, Chat & Email|6|628
之前|zhīqián|before|sebelum|Bab 6 · Telepon, Chat & Email|6|629
之后|zhīhòu|after|setelah|Bab 6 · Telepon, Chat & Email|6|630
安排好|ānpái hǎo|to have it arranged|sudah diatur|Bab 6 · Telepon, Chat & Email|6|631
处理|chǔlǐ|to handle|menangani|Bab 6 · Telepon, Chat & Email|6|632
确认一下|quèrèn yíxià|let me confirm|saya konfirmasi|Bab 6 · Telepon, Chat & Email|6|634
麻烦您|máfan nín|may I trouble you|mohon bantuannya|Bab 6 · Telepon, Chat & Email|6|635
辛苦|xīnkǔ|thanks for the effort|terima kasih atas kerja kerasnya|Bab 6 · Telepon, Chat & Email|6|636
方便的话|fāngbiàn de huà|if convenient|kalau memungkinkan|Bab 6 · Telepon, Chat & Email|6|637
随时|suíshí|any time|kapan saja|Bab 6 · Telepon, Chat & Email|6|638
以上|yǐshàng|the above|demikian di atas|Bab 6 · Telepon, Chat & Email|6|639
请查收|qǐng cháshōu|please check the attachment|mohon diperiksa|Bab 6 · Telepon, Chat & Email|6|640
期待|qīdài|to look forward to|menantikan|Bab 6 · Telepon, Chat & Email|6|641
回音|huíyīn|reply|kabar balasan|Bab 6 · Telepon, Chat & Email|6|642
打扰|dǎrǎo|to disturb|mengganggu|Bab 6 · Telepon, Chat & Email|6|643
客户|kèhù|client, customer|klien, pelanggan|Bab 7 · Melayani Pelanggan|7|700
产品|chǎnpǐn|product|produk|Bab 7 · Melayani Pelanggan|7|701
型号|xínghào|model number|tipe, model|Bab 7 · Melayani Pelanggan|7|702
规格|guīgé|specification|spesifikasi|Bab 7 · Melayani Pelanggan|7|703
尺寸|chǐcùn|size, dimensions|ukuran|Bab 7 · Melayani Pelanggan|7|704
颜色|yánsè|colour|warna|Bab 7 · Melayani Pelanggan|7|705
材料|cáiliào|material|bahan|Bab 7 · Melayani Pelanggan|7|706
功能|gōngnéng|function, feature|fungsi, fitur|Bab 7 · Melayani Pelanggan|7|707
特点|tèdiǎn|characteristic, selling point|ciri khas|Bab 7 · Melayani Pelanggan|7|708
耐用|nàiyòng|durable|awet|Bab 7 · Melayani Pelanggan|7|709
性价比|xìngjiàbǐ|value for money|rasio harga-kualitas|Bab 7 · Melayani Pelanggan|7|710
保修|bǎoxiū|warranty|garansi|Bab 7 · Melayani Pelanggan|7|711
价格|jiàgé|price|harga|Bab 7 · Melayani Pelanggan|7|712
报价|bàojià|quotation; to quote|penawaran harga|Bab 7 · Melayani Pelanggan|7|713
单价|dānjià|unit price|harga satuan|Bab 7 · Melayani Pelanggan|7|714
总价|zǒngjià|total price|harga total|Bab 7 · Melayani Pelanggan|7|715
含税|hánshuì|tax included|sudah termasuk pajak|Bab 7 · Melayani Pelanggan|7|716
不含|bù hán|not including|belum termasuk|Bab 7 · Melayani Pelanggan|7|717
折扣|zhékòu|discount|diskon|Bab 7 · Melayani Pelanggan|7|718
优惠|yōuhuì|preferential, better price|harga khusus|Bab 7 · Melayani Pelanggan|7|719
最低|zuì dī|lowest|paling rendah|Bab 7 · Melayani Pelanggan|7|720
库存|kùcún|stock|stok|Bab 7 · Melayani Pelanggan|7|721
有货|yǒu huò|in stock|ada barang|Bab 7 · Melayani Pelanggan|7|722
缺货|quē huò|out of stock|stok habis|Bab 7 · Melayani Pelanggan|7|723
现货|xiànhuò|goods in stock, ready stock|barang ready|Bab 7 · Melayani Pelanggan|7|724
补货|bǔ huò|to restock|mengisi ulang stok|Bab 7 · Melayani Pelanggan|7|725
数量|shùliàng|quantity|jumlah|Bab 7 · Melayani Pelanggan|7|726
起订量|qǐdìngliàng|minimum order quantity|minimum pemesanan|Bab 7 · Melayani Pelanggan|7|727
交货|jiāohuò|delivery|pengiriman barang|Bab 7 · Melayani Pelanggan|7|728
等|děng|to wait|menunggu|Bab 7 · Melayani Pelanggan|7|729
投诉|tóusù|to complain; complaint|komplain|Bab 7 · Melayani Pelanggan|7|730
坏了|huài le|broken|rusak|Bab 7 · Melayani Pelanggan|7|732
少了|shǎo le|short, missing|kurang|Bab 7 · Melayani Pelanggan|7|733
发错|fā cuò|sent the wrong item|salah kirim|Bab 7 · Melayani Pelanggan|7|734
退货|tuìhuò|to return goods|retur|Bab 7 · Melayani Pelanggan|7|735
换货|huànhuò|to exchange goods|tukar barang|Bab 7 · Melayani Pelanggan|7|736
赔|péi|to compensate|mengganti rugi|Bab 7 · Melayani Pelanggan|7|737
核实|héshí|to verify|memverifikasi|Bab 7 · Melayani Pelanggan|7|738
照片|zhàopiàn|photo|foto|Bab 7 · Melayani Pelanggan|7|739
理解|lǐjiě|to understand (a feeling)|memahami|Bab 7 · Melayani Pelanggan|7|740
抱歉|bàoqiàn|apologies|mohon maaf|Bab 7 · Melayani Pelanggan|7|741
谈|tán|to talk, to negotiate|berunding|Bab 8 · Negosiasi|8|800
谈判|tánpàn|negotiation|negosiasi|Bab 8 · Negosiasi|8|801
条件|tiáojiàn|terms, conditions|syarat|Bab 8 · Negosiasi|8|802
合作|hézuò|to cooperate|kerja sama|Bab 8 · Negosiasi|8|803
长期|chángqī|long-term|jangka panjang|Bab 8 · Negosiasi|8|804
订单|dìngdān|order|pesanan|Bab 8 · Negosiasi|8|805
下单|xiàdān|to place an order|memesan|Bab 8 · Negosiasi|8|806
批|pī|batch|batch, kelompok|Bab 8 · Negosiasi|8|807
降价|jiàngjià|to lower the price|menurunkan harga|Bab 8 · Negosiasi|8|808
让步|ràngbù|to concede|memberi kelonggaran|Bab 8 · Negosiasi|8|809
空间|kōngjiān|room (for negotiation)|ruang|Bab 8 · Negosiasi|8|810
底线|dǐxiàn|bottom line|batas bawah|Bab 8 · Negosiasi|8|811
利润|lìrùn|profit|keuntungan|Bab 8 · Negosiasi|8|813
预算|yùsuàn|budget|anggaran|Bab 8 · Negosiasi|8|814
超过|chāoguò|to exceed|melebihi|Bab 8 · Negosiasi|8|815
付款|fùkuǎn|payment|pembayaran|Bab 8 · Negosiasi|8|816
定金|dìngjīn|deposit|uang muka|Bab 8 · Negosiasi|8|817
尾款|wěikuǎn|balance payment|pelunasan|Bab 8 · Negosiasi|8|818
分期|fēnqī|by instalments|dicicil|Bab 8 · Negosiasi|8|819
预付|yùfù|to prepay|bayar di muka|Bab 8 · Negosiasi|8|820
电汇|diànhuì|wire transfer, T/T|transfer bank|Bab 8 · Negosiasi|8|821
信用证|xìnyòngzhèng|letter of credit, L/C|letter of credit|Bab 8 · Negosiasi|8|822
发票|fāpiào|invoice|faktur|Bab 8 · Negosiasi|8|823
账期|zhàngqī|payment term|tempo pembayaran|Bab 8 · Negosiasi|8|824
交货期|jiāohuòqī|delivery time|waktu pengiriman|Bab 8 · Negosiasi|8|825
发货|fāhuò|to ship out|mengirim barang|Bab 8 · Negosiasi|8|826
到货|dàohuò|goods arrive|barang tiba|Bab 8 · Negosiasi|8|827
运费|yùnfèi|freight|ongkos kirim|Bab 8 · Negosiasi|8|828
承担|chéngdān|to bear (a cost)|menanggung|Bab 8 · Negosiasi|8|829
责任|zérèn|responsibility|tanggung jawab|Bab 8 · Negosiasi|8|830
合同|hétong|contract|kontrak|Bab 8 · Negosiasi|8|831
签|qiān|to sign|menandatangani|Bab 8 · Negosiasi|8|832
盖章|gàizhāng|to stamp, to seal|membubuhkan stempel|Bab 8 · Negosiasi|8|833
双方|shuāngfāng|both parties|kedua pihak|Bab 8 · Negosiasi|8|834
接受|jiēshòu|to accept|menerima|Bab 8 · Negosiasi|8|835
为难|wéinán|to put someone in a difficult spot|menyulitkan|Bab 8 · Negosiasi|8|836
实在|shízài|really, honestly|sungguh|Bab 8 · Negosiasi|8|837
尽量|jǐnliàng|to do one’s best|sebisa mungkin|Bab 8 · Negosiasi|8|838
争取|zhēngqǔ|to strive for|mengupayakan|Bab 8 · Negosiasi|8|839
请示|qǐngshì|to ask a superior|meminta persetujuan atasan|Bab 8 · Negosiasi|8|840
回去商量|huíqu shāngliang|to discuss it back at the office|dibahas dulu di kantor|Bab 8 · Negosiasi|8|841
成交|chéngjiāo|deal is closed|deal|Bab 8 · Negosiasi|8|842
双赢|shuāngyíng|win-win|sama-sama untung|Bab 8 · Negosiasi|8|843
介绍|jièshào|to introduce|memperkenalkan|Bab 9 · Presentasi|9|900
演讲|yǎnjiǎng|presentation, speech|presentasi|Bab 9 · Presentasi|9|901
幻灯片|huàndēngpiàn|slide|salindia|Bab 9 · Presentasi|9|902
第一部分|dì yī bùfen|part one|bagian pertama|Bab 9 · Presentasi|9|903
成立|chénglì|to be founded|berdiri|Bab 9 · Presentasi|9|904
总部|zǒngbù|headquarters|kantor pusat|Bab 9 · Presentasi|9|905
分公司|fēngōngsī|branch office|kantor cabang|Bab 9 · Presentasi|9|906
工厂|gōngchǎng|factory|pabrik|Bab 9 · Presentasi|9|907
规模|guīmó|scale, size|skala|Bab 9 · Presentasi|9|908
行业|hángyè|industry|industri|Bab 9 · Presentasi|9|909
市场|shìchǎng|market|pasar|Bab 9 · Presentasi|9|910
份额|fèn’é|share|pangsa|Bab 9 · Presentasi|9|911
营业额|yíngyè’é|turnover, revenue|omzet|Bab 9 · Presentasi|9|912
增长|zēngzhǎng|to grow; growth|tumbuh; pertumbuhan|Bab 9 · Presentasi|9|913
百分之|bǎi fēn zhī|percent|persen|Bab 9 · Presentasi|9|914
主打产品|zhǔdǎ chǎnpǐn|flagship product|produk andalan|Bab 9 · Presentasi|9|915
优势|yōushì|advantage, strength|keunggulan|Bab 9 · Presentasi|9|916
竞争|jìngzhēng|competition|persaingan|Bab 9 · Presentasi|9|917
对手|duìshǒu|competitor|pesaing|Bab 9 · Presentasi|9|918
比如说|bǐrú shuō|for example|misalnya|Bab 9 · Presentasi|9|919
图表|túbiǎo|chart|grafik|Bab 9 · Presentasi|9|921
显示|xiǎnshì|to show|menunjukkan|Bab 9 · Presentasi|9|922
说明|shuōmíng|to explain; explanation|menjelaskan; penjelasan|Bab 9 · Presentasi|9|923
重点|zhòngdiǎn|key point|poin utama|Bab 9 · Presentasi|9|924
计划|jìhuà|plan|rencana|Bab 9 · Presentasi|9|925
目标|mùbiāo|target, goal|target|Bab 9 · Presentasi|9|926
实现|shíxiàn|to achieve|mencapai|Bab 9 · Presentasi|9|927
预计|yùjì|to project, to estimate|memperkirakan|Bab 9 · Presentasi|9|928
下一步|xià yí bù|next step|langkah berikutnya|Bab 9 · Presentasi|9|929
提问|tíwèn|to ask a question|bertanya|Bab 9 · Presentasi|9|932
补充说明|bǔchōng shuōmíng|further clarification|penjelasan tambahan|Bab 9 · Presentasi|9|934
会后|huì hòu|after the meeting|setelah acara|Bab 9 · Presentasi|9|935
资料|zīliào|material, document|materi|Bab 9 · Presentasi|9|936
联系方式|liánxì fāngshì|contact details|kontak|Bab 9 · Presentasi|9|937
感谢|gǎnxiè|to thank|berterima kasih|Bab 9 · Presentasi|9|938
各位|gèwèi|everyone (formal)|hadirin sekalian|Bab 9 · Presentasi|9|939
接下来|jiē xiàlai|next|selanjutnya|Bab 9 · Presentasi|9|941
简单来说|jiǎndān lái shuō|simply put|singkatnya|Bab 9 · Presentasi|9|942
清楚了吗|qīngchu le ma|is that clear|sudah jelas?|Bab 9 · Presentasi|9|943
进口|jìnkǒu|to import|impor|Bab 10 · Ekspor & Impor|10|1000
出口|chūkǒu|to export|ekspor|Bab 10 · Ekspor & Impor|10|1001
供应商|gōngyìngshāng|supplier|pemasok|Bab 10 · Ekspor & Impor|10|1002
买方|mǎifāng|buyer|pihak pembeli|Bab 10 · Ekspor & Impor|10|1004
卖方|màifāng|seller|pihak penjual|Bab 10 · Ekspor & Impor|10|1005
货代|huòdài|freight forwarder|forwarder|Bab 10 · Ekspor & Impor|10|1006
船公司|chuán gōngsī|shipping line|perusahaan pelayaran|Bab 10 · Ekspor & Impor|10|1007
装箱单|zhuāngxiāngdān|packing list|packing list|Bab 10 · Ekspor & Impor|10|1010
提单|tídān|bill of lading, B/L|bill of lading|Bab 10 · Ekspor & Impor|10|1011
产地证|chǎndìzhèng|certificate of origin|surat keterangan asal|Bab 10 · Ekspor & Impor|10|1012
报关|bàoguān|customs declaration|pemberitahuan pabean|Bab 10 · Ekspor & Impor|10|1014
清关|qīngguān|customs clearance|proses bea cukai|Bab 10 · Ekspor & Impor|10|1015
海关|hǎiguān|customs|bea cukai|Bab 10 · Ekspor & Impor|10|1016
关税|guānshuì|import duty|bea masuk|Bab 10 · Ekspor & Impor|10|1017
检验|jiǎnyàn|inspection|pemeriksaan|Bab 10 · Ekspor & Impor|10|1018
集装箱|jízhuāngxiāng|container|kontainer|Bab 10 · Ekspor & Impor|10|1019
整柜|zhěngguì|full container load, FCL|satu kontainer penuh|Bab 10 · Ekspor & Impor|10|1020
拼柜|pīnguì|less than container load, LCL|kontainer gabungan|Bab 10 · Ekspor & Impor|10|1021
装柜|zhuāngguì|to load the container|memuat kontainer|Bab 10 · Ekspor & Impor|10|1022
毛重|máozhòng|gross weight|berat kotor|Bab 10 · Ekspor & Impor|10|1023
净重|jìngzhòng|net weight|berat bersih|Bab 10 · Ekspor & Impor|10|1024
体积|tǐjī|volume, CBM|volume|Bab 10 · Ekspor & Impor|10|1025
唛头|màtóu|shipping mark|shipping mark|Bab 10 · Ekspor & Impor|10|1026
港口|gǎngkǒu|port|pelabuhan|Bab 10 · Ekspor & Impor|10|1027
装货港|zhuānghuògǎng|port of loading|pelabuhan muat|Bab 10 · Ekspor & Impor|10|1028
目的港|mùdìgǎng|port of destination|pelabuhan tujuan|Bab 10 · Ekspor & Impor|10|1029
海运|hǎiyùn|sea freight|pengiriman laut|Bab 10 · Ekspor & Impor|10|1030
空运|kōngyùn|air freight|pengiriman udara|Bab 10 · Ekspor & Impor|10|1031
船期|chuánqī|sailing schedule|jadwal kapal|Bab 10 · Ekspor & Impor|10|1032
开船|kāichuán|vessel departs|kapal berangkat|Bab 10 · Ekspor & Impor|10|1033
到港|dàogǎng|to arrive at port|tiba di pelabuhan|Bab 10 · Ekspor & Impor|10|1034
提货|tíhuò|to pick up the goods|mengambil barang|Bab 10 · Ekspor & Impor|10|1035
仓库|cāngkù|warehouse|gudang|Bab 10 · Ekspor & Impor|10|1036
运输|yùnshū|transport|pengangkutan|Bab 10 · Ekspor & Impor|10|1037
保险|bǎoxiǎn|insurance|asuransi|Bab 10 · Ekspor & Impor|10|1038
延误|yánwù|delay|keterlambatan|Bab 10 · Ekspor & Impor|10|1039
跟单|gēndān|to follow up on an order|memantau order|Bab 10 · Ekspor & Impor|10|1040
预计到港时间|yùjì dàogǎng shíjiān|ETA|perkiraan tiba|Bab 10 · Ekspor & Impor|10|1041
单据|dānjù|documents|dokumen|Bab 10 · Ekspor & Impor|10|1042
齐了|qí le|complete, all in|sudah lengkap|Bab 10 · Ekspor & Impor|10|1043
$blob$, chr(10))) AS l
  WHERE btrim(replace(l, chr(13), '')) <> ''
)
INSERT INTO public.vocab_track
  (track, hanzi, pinyin, meaning_en, meaning_id, theme, chapter, sort_order, source)
SELECT 'business', c[1], c[2], c[3], c[4], replace(c[5], chr(183), '-'), c[6]::smallint, c[7]::int, 'buku'
FROM baris
ON CONFLICT (track, hanzi) DO UPDATE SET
  theme      = EXCLUDED.theme,
  chapter    = EXCLUDED.chapter,
  sort_order = EXCLUDED.sort_order,
  pinyin     = EXCLUDED.pinyin,
  meaning_en = EXCLUDED.meaning_en,
  meaning_id = EXCLUDED.meaning_id,
  example_zh = coalesce(public.vocab_track.example_zh, EXCLUDED.example_zh),
  example_id = coalesce(public.vocab_track.example_id, EXCLUDED.example_id),
  source     = 'buku';

-- ---------------------------------------------------------------------------
-- (4) VERIFIKASI -- tidak menulis apa pun.
-- ---------------------------------------------------------------------------
SELECT 'A. jumlah per track' AS cek, track AS rincian, count(*)::text AS nilai
FROM public.vocab_track GROUP BY track
UNION ALL
SELECT 'B. business per bab', lpad(coalesce(chapter,99)::text,2,'0') || ' - ' || theme, count(*)::text
FROM public.vocab_track WHERE track='business' GROUP BY chapter, theme
UNION ALL
SELECT 'C. business tanpa bab (harus 0)', 'total', count(*)::text
FROM public.vocab_track WHERE track='business' AND chapter IS NULL
UNION ALL
SELECT 'D. tema lama masih tersisa (harus 0)', 'total', count(*)::text
FROM public.vocab_track WHERE track='business'
  AND theme IN ('Rapat','Negosiasi','Presentasi','Email','Keuangan','Jabatan')
UNION ALL
SELECT 'E. contoh kalimat selamat (harus 60)', 'total', count(*)::text
FROM public.vocab_track WHERE track='business' AND coalesce(example_zh,'') <> ''
UNION ALL
SELECT 'F. convo tidak tersentuh (harus 60)', 'total', count(*)::text
FROM public.vocab_track WHERE track='convo'
UNION ALL
SELECT 'G. convo temanya tetap (harus 6)', 'total', count(DISTINCT theme)::text
FROM public.vocab_track WHERE track='convo'
UNION ALL
SELECT 'H. public.vocab tidak berubah (harus 6901)', 'total', count(*)::text
FROM public.vocab
ORDER BY 1, 2;

-- ---- DRY RUN. Ganti jadi COMMIT; kalau angkanya sudah sesuai. ----
ROLLBACK;
