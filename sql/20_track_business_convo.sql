-- ============================================================================
-- 20_track_business_convo.sql
--
-- Menambahkan dua deck kosakata baru (Business dan Convo) yang TIDAK berjenjang
-- HSK, lalu memagarinya per paket.
--
-- KENAPA PAKAI KOLOM `track`, BUKAN hsk_level
-- Paket HSK menjual KEDALAMAN LEVEL. Paket Business dan Convo menjual BIDANG.
-- Dua sumbu yang berbeda. Kalau kosakata bisnis dipaksa diberi hsk_level, dia
-- otomatis ikut terbuka untuk pemegang paket HSK yang tidak membelinya, karena
-- seluruh pemagaran vocab bertumpu pada hsk_level.
--
-- Baris baru diberi hsk_level = 0 supaya tidak pernah cocok dengan
-- allowed_levels() (yang hanya mengembalikan 1..7). Jadi secara bawaan baris ini
-- TIDAK TERLIHAT oleh siapa pun sampai policy di bagian (4) dipasang.
--
-- SATU JEBAKAN YANG HAMPIR TERLEWAT
-- Policy anon yang lama berbunyi `hsk_level <= 3`. Nol juga <= 3, jadi tanpa
-- perubahan, seluruh kosakata bisnis akan bocor ke pengunjung yang belum login.
-- Bagian (4) menutup itu dengan menambahkan syarat track = 'hsk'.
--
-- CARA PAKAI: jalankan apa adanya dulu (diakhiri ROLLBACK), periksa angkanya,
-- baru ganti ROLLBACK jadi COMMIT.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- (1) Kolom track. Semua 6.901 baris lama otomatis jadi 'hsk' -- tidak ada
--     perubahan perilaku untuk data yang sudah ada.
-- ---------------------------------------------------------------------------
ALTER TABLE public.vocab
  ADD COLUMN IF NOT EXISTS track text NOT NULL DEFAULT 'hsk';

ALTER TABLE public.vocab
  DROP CONSTRAINT IF EXISTS vocab_track_check;
ALTER TABLE public.vocab
  ADD CONSTRAINT vocab_track_check CHECK (track IN ('hsk','business','convo'));

CREATE INDEX IF NOT EXISTS vocab_track_theme_idx
  ON public.vocab (track, beginner_theme);

-- ---------------------------------------------------------------------------
-- (2) Helper: bidang apa saja yang boleh dibuka user yang sedang login.
--     Bentuknya sengaja dibuat kembar dengan allowed_levels() supaya aturan
--     kedaluwarsa langganan diperlakukan sama persis.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.allowed_tracks()
RETURNS text[]
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_role    text;
  v_status  text;
  v_end     date;
  v_package text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN ARRAY['hsk']::text[];          -- pengunjung: hanya jalur HSK (dibatasi lagi di policy)
  END IF;

  SELECT role, status, subscription_end, package
    INTO v_role, v_status, v_end, v_package
  FROM public.profiles WHERE id = v_uid;

  IF v_role = 'admin' THEN
    RETURN ARRAY['hsk','business','convo']::text[];
  END IF;

  IF v_status = 'expired' THEN
    RETURN ARRAY[]::text[];
  END IF;
  IF v_end IS NOT NULL AND v_end < (now() AT TIME ZONE 'Asia/Jakarta')::date THEN
    RETURN ARRAY[]::text[];
  END IF;

  RETURN CASE v_package
    WHEN 'business' THEN ARRAY['hsk','business']
    WHEN 'convo'    THEN ARRAY['hsk','convo']
    WHEN 'vip'      THEN ARRAY['hsk','business','convo']
    ELSE ARRAY['hsk']
  END;
END;
$$;

REVOKE ALL ON FUNCTION public.allowed_tracks() FROM public;
GRANT EXECUTE ON FUNCTION public.allowed_tracks() TO authenticated, anon;

COMMENT ON FUNCTION public.allowed_tracks() IS
  'Bidang kosakata yang boleh diakses user yang sedang login. Pendamping allowed_levels().';

-- ---------------------------------------------------------------------------
-- (3) Isi 120 kata. hsk_level = 0 menandai "di luar penjenjangan HSK".
-- ---------------------------------------------------------------------------
INSERT INTO public.vocab
  (hanzi, pinyin, meaning_en, meaning_id, hsk_level, track, beginner_theme, forms, example_zh, example_id)
SELECT t.hanzi, t.pinyin, t.meaning_en, t.meaning_id, 0, t.track, t.tema,
       jsonb_build_array(jsonb_build_object(
         'meanings',       jsonb_build_array(t.meaning_en),
         'classifiers',    '[]'::jsonb,
         'transcriptions', jsonb_build_object('pinyin', t.pinyin))),
       t.example_zh, t.example_id
FROM (VALUES
('会议','huìyì','meeting','rapat','business','Rapat','下午三点开会议，别迟到。','Rapatnya jam tiga sore, jangan telat.'),
('安排','ānpái','to arrange; to schedule','mengatur; menjadwalkan','business','Rapat','我来安排时间和地点。','Biar saya yang atur waktu dan tempatnya.'),
('推迟','tuīchí','to postpone','menunda','business','Rapat','客户临时有事，会议推迟到明天。','Klien ada urusan mendadak, rapatnya ditunda ke besok.'),
('参加','cānjiā','to attend','ikut; menghadiri','business','Rapat','这次会议你参加吗？','Rapat kali ini kamu ikut?'),
('议程','yìchéng','agenda','agenda rapat','business','Rapat','议程我已经发到群里了。','Agendanya sudah saya kirim ke grup.'),
('记录','jìlù','to record; minutes','mencatat; notulen','business','Rapat','今天谁做会议记录？','Hari ini siapa yang bikin notulen?'),
('讨论','tǎolùn','to discuss','membahas','business','Rapat','这个问题我们下次再讨论。','Masalah ini kita bahas lain kali saja.'),
('决定','juédìng','to decide; decision','memutuskan; keputusan','business','Rapat','最后的决定要等经理点头。','Keputusan akhirnya menunggu manajer setuju.'),
('确认','quèrèn','to confirm','memastikan','business','Rapat','麻烦你确认一下时间。','Tolong dipastikan dulu waktunya.'),
('取消','qǔxiāo','to cancel','membatalkan','business','Rapat','明天的会取消了。','Rapat besok dibatalkan.'),
('邮件','yóujiàn','email','email','business','Email','我刚给你发了一封邮件。','Saya baru kirim email ke kamu.'),
('附件','fùjiàn','attachment','lampiran','business','Email','合同在附件里，请查收。','Kontraknya ada di lampiran, silakan dicek.'),
('抄送','chāosòng','to CC','mengirim tembusan (CC)','business','Email','记得抄送给财务部。','Jangan lupa tembuskan ke bagian keuangan.'),
('回复','huífù','to reply','membalas','business','Email','他到现在还没回复我。','Sampai sekarang dia belum balas.'),
('联系','liánxì','to contact','menghubungi','business','Email','有问题随时联系我。','Kalau ada masalah, hubungi saya kapan saja.'),
('通知','tōngzhī','to notify; notice','memberitahu; pemberitahuan','business','Email','这件事我会通知大家。','Soal ini nanti saya kabari semua.'),
('转发','zhuǎnfā','to forward','meneruskan (forward)','business','Email','你把那封邮件转发给我。','Email itu tolong teruskan ke saya.'),
('催','cuī','to urge; to chase up','menagih; mendesak','business','Email','客户又来催报价了。','Klien nagih penawaran lagi.'),
('紧急','jǐnjí','urgent','mendesak; darurat','business','Email','这件事比较紧急。','Urusan ini agak mendesak.'),
('截止','jiézhǐ','deadline','batas waktu','business','Email','报名截止到本周五。','Pendaftaran ditutup Jumat ini.'),
('报价','bàojià','price quotation','penawaran harga','business','Negosiasi','这是我们的报价，您看一下。','Ini penawaran kami, silakan dilihat.'),
('折扣','zhékòu','discount','diskon','business','Negosiasi','量大的话可以给折扣。','Kalau jumlahnya banyak, bisa dikasih diskon.'),
('合同','hétong','contract','kontrak','business','Negosiasi','合同下周签。','Kontraknya ditandatangani minggu depan.'),
('谈判','tánpàn','to negotiate','bernegosiasi','business','Negosiasi','这次谈判进行得很顺利。','Negosiasi kali ini berjalan lancar.'),
('条件','tiáojiàn','condition; terms','syarat','business','Negosiasi','这个条件我们接受不了。','Syarat ini tidak bisa kami terima.'),
('考虑','kǎolǜ','to consider','mempertimbangkan','business','Negosiasi','给我们两天时间考虑。','Beri kami dua hari untuk mempertimbangkan.'),
('让步','ràngbù','to make a concession','mengalah; berkompromi','business','Negosiasi','价格上我们已经让步了。','Soal harga kami sudah mengalah.'),
('合作','hézuò','to cooperate','bekerja sama','business','Negosiasi','希望以后有机会合作。','Semoga nanti ada kesempatan kerja sama.'),
('签字','qiānzì','to sign','menandatangani','business','Negosiasi','请在这里签字。','Silakan tanda tangan di sini.'),
('保证','bǎozhèng','to guarantee','menjamin','business','Negosiasi','我保证下周一交货。','Saya jamin barangnya sampai Senin depan.'),
('经理','jīnglǐ','manager','manajer','business','Jabatan','经理今天出差了。','Manajer hari ini sedang dinas luar.'),
('部门','bùmén','department','departemen; bagian','business','Jabatan','你是哪个部门的？','Kamu dari bagian mana?'),
('同事','tóngshì','colleague','rekan kerja','business','Jabatan','这位是我的同事小李。','Ini rekan kerja saya, Xiao Li.'),
('客户','kèhù','client','klien; pelanggan','business','Jabatan','下午我要见一个客户。','Sore ini saya mau ketemu klien.'),
('总公司','zǒnggōngsī','head office','kantor pusat','business','Jabatan','总公司在上海。','Kantor pusatnya di Shanghai.'),
('分公司','fēngōngsī','branch office','kantor cabang','business','Jabatan','我们在雅加达有分公司。','Kami punya cabang di Jakarta.'),
('上司','shàngsi','superior; boss','atasan','business','Jabatan','这件事得先问上司。','Urusan ini harus tanya atasan dulu.'),
('加班','jiābān','to work overtime','lembur','business','Jabatan','这周天天加班。','Minggu ini lembur tiap hari.'),
('出差','chūchāi','business trip','dinas luar kota','business','Jabatan','他去北京出差三天。','Dia dinas ke Beijing tiga hari.'),
('请假','qǐngjià','to ask for leave','izin tidak masuk','business','Jabatan','我明天想请一天假。','Besok saya mau izin sehari.'),
('发票','fāpiào','invoice','faktur','business','Keuangan','发票开好了吗？','Fakturnya sudah dibuat?'),
('付款','fùkuǎn','to pay; payment','membayar; pembayaran','business','Keuangan','付款方式怎么定？','Cara pembayarannya bagaimana?'),
('预算','yùsuàn','budget','anggaran','business','Keuangan','这个超出预算了。','Ini melewati anggaran.'),
('成本','chéngběn','cost','biaya produksi','business','Keuangan','今年成本涨了不少。','Tahun ini biayanya naik lumayan.'),
('利润','lìrùn','profit','laba','business','Keuangan','利润比去年高。','Labanya lebih tinggi dari tahun lalu.'),
('转账','zhuǎnzhàng','bank transfer','transfer uang','business','Keuangan','钱我今天转账过去。','Uangnya hari ini saya transfer.'),
('报销','bàoxiāo','to claim reimbursement','klaim penggantian biaya','business','Keuangan','车费可以报销。','Ongkos transport bisa diklaim.'),
('定金','dìngjīn','deposit','uang muka','business','Keuangan','先付三成定金。','Bayar uang muka tiga puluh persen dulu.'),
('结算','jiésuàn','to settle accounts','menyelesaikan pembayaran','business','Keuangan','月底一起结算。','Akhir bulan diselesaikan sekaligus.'),
('涨价','zhǎngjià','to raise prices','naik harga','business','Keuangan','原材料又涨价了。','Bahan bakunya naik harga lagi.'),
('介绍','jièshào','to introduce','memperkenalkan','business','Presentasi','我先介绍一下我们公司。','Saya perkenalkan dulu perusahaan kami.'),
('报告','bàogào','report','laporan','business','Presentasi','报告我明天交。','Laporannya saya serahkan besok.'),
('数据','shùjù','data','data','business','Presentasi','这些数据是上个月的。','Data ini dari bulan lalu.'),
('结论','jiélùn','conclusion','kesimpulan','business','Presentasi','结论很简单。','Kesimpulannya sederhana.'),
('建议','jiànyì','suggestion; to suggest','saran; menyarankan','business','Presentasi','我建议先做小规模测试。','Saya sarankan uji coba kecil-kecilan dulu.'),
('重点','zhòngdiǎn','key point','poin utama','business','Presentasi','重点我用红色标出来了。','Poin pentingnya saya tandai merah.'),
('补充','bǔchōng','to add; to supplement','menambahkan','business','Presentasi','我补充一句。','Saya tambahkan satu hal.'),
('目标','mùbiāo','target; goal','target','business','Presentasi','今年的目标是翻一倍。','Target tahun ini naik dua kali lipat.'),
('效率','xiàolǜ','efficiency','efisiensi','business','Presentasi','这样做效率更高。','Kalau begini lebih efisien.'),
('风险','fēngxiǎn','risk','risiko','business','Presentasi','风险不大，可以试。','Risikonya kecil, boleh dicoba.'),
('请问','qǐngwèn','excuse me, may I ask','permisi, boleh tanya','convo','Perkenalan','请问，你是新来的吗？','Permisi, kamu yang baru datang ya?'),
('认识','rènshi','to know (a person)','kenal','convo','Perkenalan','认识你很高兴。','Senang kenal kamu.'),
('叫','jiào','to be called','bernama; memanggil','convo','Perkenalan','你叫什么名字？','Namamu siapa?'),
('来自','láizì','to come from','berasal dari','convo','Perkenalan','我来自印尼。','Saya dari Indonesia.'),
('专业','zhuānyè','major (of study)','jurusan','convo','Perkenalan','你学什么专业？','Kamu jurusan apa?'),
('住','zhù','to live; to stay','tinggal','convo','Perkenalan','我住在学校附近。','Saya tinggal dekat kampus.'),
('微信','Wēixìn','WeChat','WeChat','convo','Perkenalan','加个微信吧。','Tukeran WeChat yuk.'),
('聊','liáo','to chat','mengobrol','convo','Perkenalan','改天再聊。','Lain kali kita ngobrol lagi.'),
('熟','shú','familiar; close','akrab; kenal baik','convo','Perkenalan','我们不太熟。','Kami tidak terlalu akrab.'),
('再见','zàijiàn','goodbye','sampai jumpa','convo','Perkenalan','那我先走了，再见。','Kalau begitu saya duluan ya, sampai jumpa.'),
('点菜','diǎncài','to order food','memesan makanan','convo','Makan','我们先点菜吧。','Kita pesan makanan dulu ya.'),
('好吃','hǎochī','tasty','enak','convo','Makan','这家的面特别好吃。','Mie di sini enak banget.'),
('辣','là','spicy','pedas','convo','Makan','我不能吃太辣。','Saya tidak kuat terlalu pedas.'),
('清真','qīngzhēn','halal','halal','convo','Makan','请问这里有清真餐厅吗？','Permisi, di sini ada restoran halal?'),
('打包','dǎbāo','to take away','dibungkus','convo','Makan','吃不完，打包吧。','Tidak habis, dibungkus saja.'),
('结账','jiézhàng','to pay the bill','membayar (di restoran)','convo','Makan','服务员，结账。','Mas, mau bayar.'),
('饿','è','hungry','lapar','convo','Makan','我快饿死了。','Saya lapar banget.'),
('渴','kě','thirsty','haus','convo','Makan','有点儿渴，想喝水。','Agak haus, mau minum.'),
('味道','wèidào','taste; smell','rasa; aroma','convo','Makan','味道有点儿重。','Rasanya agak kuat.'),
('推荐','tuījiàn','to recommend','merekomendasikan','convo','Makan','你推荐哪个？','Kamu rekomendasikan yang mana?'),
('多少钱','duōshao qián','how much','berapa harganya','convo','Belanja','这个多少钱？','Ini berapa?'),
('便宜','piányi','cheap','murah','convo','Belanja','能不能便宜一点儿？','Bisa kurang sedikit tidak?'),
('贵','guì','expensive','mahal','convo','Belanja','太贵了，我再看看。','Kemahalan, saya lihat-lihat dulu.'),
('试','shì','to try','mencoba','convo','Belanja','可以试一下吗？','Boleh dicoba tidak?'),
('号','hào','size','ukuran','convo','Belanja','有大一号的吗？','Ada ukuran yang lebih besar?'),
('颜色','yánsè','colour','warna','convo','Belanja','还有别的颜色吗？','Ada warna lain?'),
('扫码','sǎomǎ','to scan a QR code','scan kode QR','convo','Belanja','扫码付款就行。','Tinggal scan buat bayar.'),
('现金','xiànjīn','cash','uang tunai','convo','Belanja','可以用现金吗？','Bisa pakai tunai?'),
('退','tuì','to return; to refund','mengembalikan; retur','convo','Belanja','不合适可以退吗？','Kalau tidak cocok bisa dikembalikan?'),
('找钱','zhǎoqián','change (money)','kembalian','convo','Belanja','这是找您的钱。','Ini kembaliannya.'),
('怎么走','zěnme zǒu','how to get there','lewat mana','convo','Arah','请问，地铁站怎么走？','Permisi, stasiun kereta lewat mana?'),
('附近','fùjìn','nearby','di sekitar sini','convo','Arah','附近有便利店吗？','Di sekitar sini ada minimarket?'),
('往','wǎng','towards','ke arah','convo','Arah','往前走两百米。','Jalan lurus dua ratus meter.'),
('拐','guǎi','to turn','belok','convo','Arah','到路口往右拐。','Sampai perempatan belok kanan.'),
('对面','duìmiàn','opposite side','seberang','convo','Arah','就在银行对面。','Persis di seberang bank.'),
('打车','dǎchē','to take a taxi','naik taksi','convo','Arah','我们打车过去吧。','Kita naik taksi saja ke sana.'),
('堵车','dǔchē','traffic jam','macet','convo','Arah','这个点儿肯定堵车。','Jam segini pasti macet.'),
('迷路','mílù','to get lost','tersesat','convo','Arah','我好像迷路了。','Kayaknya saya nyasar.'),
('远','yuǎn','far','jauh','convo','Arah','离这儿远不远？','Dari sini jauh tidak?'),
('到','dào','to arrive','sampai; tiba','convo','Arah','快到了，还有五分钟。','Hampir sampai, lima menit lagi.'),
('有空','yǒu kòng','to be free','ada waktu luang','convo','Waktu','你周末有空吗？','Kamu weekend kosong?'),
('约','yuē','to make an appointment','janjian','convo','Waktu','我们约几点？','Kita janjian jam berapa?'),
('迟到','chídào','to be late','terlambat','convo','Waktu','对不起，我迟到了。','Maaf, saya terlambat.'),
('提前','tíqián','in advance','lebih awal','convo','Waktu','我提前十分钟到。','Saya sampai sepuluh menit lebih awal.'),
('来不及','láibují','not enough time','tidak keburu','convo','Waktu','现在走已经来不及了。','Berangkat sekarang sudah tidak keburu.'),
('顺便','shùnbiàn','while you are at it','sekalian','convo','Waktu','顺便帮我买杯咖啡。','Sekalian belikan saya kopi ya.'),
('改天','gǎitiān','another day','lain hari','convo','Waktu','今天不行，改天吧。','Hari ini tidak bisa, lain hari saja.'),
('随时','suíshí','any time','kapan saja','convo','Waktu','你随时可以来。','Kamu boleh datang kapan saja.'),
('马上','mǎshàng','right away','segera','convo','Waktu','我马上就到。','Saya segera sampai.'),
('等一下','děng yíxià','wait a moment','tunggu sebentar','convo','Waktu','等一下，我拿个东西。','Tunggu sebentar, saya ambil sesuatu.'),
('累','lèi','tired','capek','convo','Perasaan','今天累死了。','Hari ini capek banget.'),
('开心','kāixīn','happy','senang','convo','Perasaan','听到这个消息我很开心。','Dengar kabar ini saya senang sekali.'),
('担心','dānxīn','to worry','khawatir','convo','Perasaan','别担心，会好的。','Jangan khawatir, nanti juga baik.'),
('没事','méishì','it''s fine','tidak apa-apa','convo','Perasaan','没事，我不介意。','Tidak apa-apa, saya tidak keberatan.'),
('辛苦','xīnkǔ','hard work; thanks for your effort','repot; terima kasih atas jerih payah','convo','Perasaan','辛苦了，早点休息。','Terima kasih ya, istirahat lebih awal.'),
('麻烦','máfan','trouble; to bother','merepotkan; tolong','convo','Perasaan','麻烦你了。','Merepotkan kamu ya.'),
('不好意思','bù hǎoyìsi','sorry; embarrassed','maaf; tidak enak hati','convo','Perasaan','不好意思，让你久等了。','Maaf ya, sudah bikin kamu menunggu lama.'),
('当然','dāngrán','of course','tentu saja','convo','Perasaan','当然可以。','Tentu boleh.'),
('其实','qíshí','actually','sebenarnya','convo','Perasaan','其实我也不太清楚。','Sebenarnya saya juga kurang tahu.'),
('加油','jiāyóu','keep it up','semangat','convo','Perasaan','明天考试，加油！','Besok ujian, semangat!')
) AS t(hanzi,pinyin,meaning_en,meaning_id,track,tema,example_zh,example_id)
WHERE NOT EXISTS (
  SELECT 1 FROM public.vocab v WHERE v.hanzi = t.hanzi AND v.track = t.track
);

-- ---------------------------------------------------------------------------
-- (4) Perbarui policy vocab supaya track ikut dipagari.
--     PENTING: syarat track = 'hsk' pada policy anon adalah yang mencegah
--     kosakata bisnis bocor lewat celah hsk_level = 0 <= 3.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "vocab anon sample" ON public.vocab;
CREATE POLICY "vocab anon sample"
  ON public.vocab FOR SELECT TO anon
  USING (track = 'hsk' AND hsk_level BETWEEN 1 AND 3);

DROP POLICY IF EXISTS "vocab_select_authenticated" ON public.vocab;
CREATE POLICY "vocab_select_authenticated"
  ON public.vocab FOR SELECT TO authenticated
  USING (
    is_admin()
    OR (track = 'hsk' AND hsk_level = ANY (public.allowed_levels()))
    OR (track <> 'hsk' AND track = ANY (public.allowed_tracks()))
  );

-- ---------------------------------------------------------------------------
-- (5) VERIFIKASI -- tidak menulis apa pun.
-- ---------------------------------------------------------------------------
SELECT 'A. jumlah per track' AS cek, track, count(*)::text AS nilai
FROM public.vocab GROUP BY track
UNION ALL
SELECT 'B. tema baru', beginner_theme, count(*)::text
FROM public.vocab WHERE track <> 'hsk' GROUP BY beginner_theme
UNION ALL
SELECT 'C. bocor ke anon (harus 0)', 'track<>hsk & hsk_level<=3',
       count(*)::text FROM public.vocab WHERE track <> 'hsk' AND hsk_level BETWEEN 1 AND 3
ORDER BY 1, 2;

SELECT 'policy vocab sesudah' AS tahap, policyname, roles::text, qual
FROM pg_policies WHERE schemaname='public' AND tablename='vocab' ORDER BY policyname;

-- ---- DRY RUN. Ganti jadi COMMIT; kalau angkanya sudah sesuai. ----
ROLLBACK;
