# Survival Kit — Kurasi 100 Kata/Frasa (Fitur 5, batch prompt-pack)

Kurasi mandiri (bukan spec dari owner), sesuai instruksi "tanpa menunggu kurasi saya". 5 tema,
~20 item/tema, urut `beginner_order`. Kolom **Status** adalah **TEBAKAN** (saya tidak punya akses
baca langsung ke tabel `vocab` di Supabase produksi sesi ini) — kata/frasa TUNGGAL umum HSK1-2
kemungkinan besar **sudah ada** (dataset `complete.json`, ~5000 kata standar HSK 2.0), sedangkan
FRASA/KALIMAT (mis. "你叫什么名字", "太贵了") kemungkinan besar **belum ada** karena tabel `vocab`
setahu saya berisi kata/kompoun, bukan kalimat.

**PENTING sebelum apply `sql/08_survival_kit.sql`**: SQL-nya ditulis idempotent
(`INSERT ... ON CONFLICT (hanzi) DO UPDATE`) supaya AMAN dijalankan terlepas dari tebakan status
ini benar atau salah — kalau row-nya udah ada, cuma `beginner_kit`/`beginner_order`/`beginner_theme`
yang di-set (hsk_level/pinyin/meaning_en/meaning_id existing TIDAK ditimpa); kalau belum ada,
baris baru diinsert. Tetap disarankan Kyaru spot-check kolom Status sebelum apply, terutama yang
ditandai "NEW?" (paling tidak pasti).

**Keputusan yang saya ambil sendiri** (lihat RELEASE_CHECKLIST.md untuk daftar lengkap):
- `hsk_level` semua diisi **1** (BUKAN 0 seperti disebut di prompt) — kolom `vocab.hsk_level` punya
  `CHECK (hsk_level BETWEEN 1 AND 6)` di skema existing (`sql/01_vocab_schema.sql`), jadi 0 akan
  DITOLAK constraint. Saya pilih tidak mengubah constraint existing (di luar izin "jangan sentuh
  gating existing" tanpa instruksi eksplisit) — filter yang sebenarnya dipakai UI tetap
  `beginner_kit=true`, `hsk_level` cuma metadata sekunder.
- Nambah kolom `beginner_theme TEXT` (di luar 2 kolom yang disebut prompt: `beginner_kit`,
  `beginner_order`) — dibutuhkan buat requirement "group per tema" yang ga bisa dipenuhi tanpa
  kolom ini (tidak ada kolom kategori/tema existing di `vocab`).

## Tema 1 — Sapaan & Sopan Santun

| # | Hanzi | Pinyin | Arti ID | Status |
|---|---|---|---|---|
| 1 | 你好 | nǐ hǎo | halo | UPDATE (ada) |
| 2 | 你们好 | nǐmen hǎo | halo (ke beberapa orang) | INSERT (frasa) |
| 3 | 谢谢 | xièxie | terima kasih | UPDATE (ada) |
| 4 | 不客气 | bú kèqi | sama-sama | INSERT (frasa) |
| 5 | 再见 | zàijiàn | sampai jumpa | UPDATE (ada) |
| 6 | 对不起 | duìbuqǐ | maaf | UPDATE (ada) |
| 7 | 没关系 | méi guānxi | tidak apa-apa | INSERT (frasa) |
| 8 | 请 | qǐng | tolong / silakan | UPDATE (ada) |
| 9 | 早上好 | zǎoshang hǎo | selamat pagi | INSERT (frasa) |
| 10 | 晚安 | wǎn'ān | selamat malam | UPDATE (ada) |
| 11 | 你好吗 | nǐ hǎo ma | apa kabar | INSERT (frasa) |
| 12 | 老师 | lǎoshī | guru | UPDATE (ada) |
| 13 | 先生 | xiānsheng | Tuan / Bapak | UPDATE (ada) |
| 14 | 小姐 | xiǎojiě | Nona | UPDATE (ada) |
| 15 | 欢迎 | huānyíng | selamat datang | UPDATE (ada) |
| 16 | 麻烦你 | máfan nǐ | maaf merepotkan | INSERT (frasa) |
| 17 | 不好意思 | bùhǎoyìsi | maaf / permisi | INSERT (frasa umum) |
| 18 | 请问 | qǐngwèn | permisi, boleh tanya | UPDATE (ada) |
| 19 | 拜拜 | báibái | dadah | UPDATE (ada) |
| 20 | 恭喜 | gōngxǐ | selamat (congrats) | UPDATE (ada) |
| 21 | 打扰一下 | dǎrǎo yíxià | permisi mengganggu sebentar | INSERT (frasa) |
| 22 | 保重 | bǎozhòng | jaga diri baik-baik | UPDATE (ada) |

## Tema 2 — Perkenalan Diri

| # | Hanzi | Pinyin | Arti ID | Status |
|---|---|---|---|---|
| 23 | 我叫 | wǒ jiào | nama saya (…) | INSERT (frasa) |
| 24 | 我的名字是 | wǒ de míngzi shì | nama saya adalah | INSERT (frasa) |
| 25 | 你叫什么名字 | nǐ jiào shénme míngzi | siapa namamu | INSERT (frasa) |
| 26 | 名字 | míngzi | nama | UPDATE (ada) |
| 27 | 我是 | wǒ shì | saya adalah | INSERT (frasa) |
| 28 | 很高兴认识你 | hěn gāoxìng rènshi nǐ | senang berkenalan denganmu | INSERT (frasa) |
| 29 | 认识你 | rènshi nǐ | kenal kamu | INSERT (frasa) |
| 30 | 朋友 | péngyou | teman | UPDATE (ada) |
| 31 | 我来自 | wǒ láizì | saya berasal dari | INSERT (frasa) |
| 32 | 中国 | Zhōngguó | Tiongkok | UPDATE (ada) |
| 33 | 印度尼西亚 | Yìndùníxīyà | Indonesia | NEW? (nama negara, mungkin tidak ada di dataset standar) |
| 34 | 多大 | duō dà | berapa umur | INSERT (frasa) |
| 35 | 岁 | suì | tahun (umur) | UPDATE (ada) |
| 36 | 工作 | gōngzuò | pekerjaan | UPDATE (ada) |
| 37 | 学生 | xuésheng | murid / siswa | UPDATE (ada) |
| 38 | 家 | jiā | rumah / keluarga | UPDATE (ada) |
| 39 | 住在 | zhùzài | tinggal di | INSERT (frasa) |
| 40 | 电话号码 | diànhuà hàomǎ | nomor telepon | UPDATE (ada, kompoun umum) |
| 41 | 结婚了吗 | jiéhūn le ma | sudah menikah? | INSERT (frasa) |
| 42 | 单身 | dānshēn | lajang | NEW? (kurang umum di HSK inti) |

## Tema 3 — Angka

| # | Hanzi | Pinyin | Arti ID | Status |
|---|---|---|---|---|
| 43 | 零 | líng | nol | UPDATE (ada) |
| 44 | 一 | yī | satu | UPDATE (ada) |
| 45 | 二 | èr | dua | UPDATE (ada) |
| 46 | 三 | sān | tiga | UPDATE (ada) |
| 47 | 四 | sì | empat | UPDATE (ada) |
| 48 | 五 | wǔ | lima | UPDATE (ada) |
| 49 | 六 | liù | enam | UPDATE (ada) |
| 50 | 七 | qī | tujuh | UPDATE (ada) |
| 51 | 八 | bā | delapan | UPDATE (ada) |
| 52 | 九 | jiǔ | sembilan | UPDATE (ada) |
| 53 | 十 | shí | sepuluh | UPDATE (ada) |
| 54 | 百 | bǎi | ratus | UPDATE (ada) |
| 55 | 千 | qiān | ribu | UPDATE (ada) |
| 56 | 半 | bàn | setengah | UPDATE (ada) |
| 57 | 多少 | duōshao | berapa (jumlah) | UPDATE (ada) |
| 58 | 几 | jǐ | berapa (jumlah kecil) | UPDATE (ada) |

## Tema 4 — Situasi Darurat / Survival

| # | Hanzi | Pinyin | Arti ID | Status |
|---|---|---|---|---|
| 59 | 多少钱 | duōshao qián | berapa harganya | INSERT (frasa) |
| 60 | 太贵了 | tài guì le | terlalu mahal | INSERT (frasa) |
| 61 | 便宜点 | piányi diǎn | kasih murah dikit | INSERT (frasa) |
| 62 | 哪儿 | nǎr | di mana | UPDATE (ada) |
| 63 | 厕所 | cèsuǒ | toilet | UPDATE (ada) |
| 64 | 厕所在哪儿 | cèsuǒ zài nǎr | toilet di mana | INSERT (frasa) |
| 65 | 救命 | jiùmìng | tolong! (darurat) | UPDATE (ada) |
| 66 | 我不舒服 | wǒ bù shūfu | saya tidak enak badan | INSERT (frasa) |
| 67 | 医院 | yīyuàn | rumah sakit | UPDATE (ada) |
| 68 | 警察 | jǐngchá | polisi | UPDATE (ada) |
| 69 | 帮助 | bāngzhù | bantuan / membantu | UPDATE (ada) |
| 70 | 慢一点 | màn yìdiǎn | pelan-pelan sedikit | INSERT (frasa) |
| 71 | 我听不懂 | wǒ tīng bu dǒng | saya tidak mengerti | INSERT (frasa) |
| 72 | 迷路了 | mílù le | tersesat | NEW? (kurang umum di HSK inti) |
| 73 | 护照 | hùzhào | paspor | UPDATE (ada) |
| 74 | 机场 | jīchǎng | bandara | UPDATE (ada) |
| 75 | 出租车 | chūzūchē | taksi | UPDATE (ada) |
| 76 | 火车站 | huǒchēzhàn | stasiun kereta | UPDATE (ada) |
| 77 | 手机 | shǒujī | HP / ponsel | UPDATE (ada) |
| 78 | 密码 | mìmǎ | kata sandi / PIN | NEW? (kurang umum di HSK inti) |
| 79 | 药店 | yàodiàn | apotek | NEW? (kurang umum di HSK inti) |

## Tema 5 — Respon Percakapan

| # | Hanzi | Pinyin | Arti ID | Status |
|---|---|---|---|---|
| 80 | 对 | duì | benar | UPDATE (ada) |
| 81 | 不对 | bú duì | salah | INSERT (frasa) |
| 82 | 不知道 | bù zhīdào | tidak tahu | INSERT (frasa) |
| 83 | 听不懂 | tīng bu dǒng | tidak mengerti (dengar) | INSERT (frasa) |
| 84 | 请再说一遍 | qǐng zài shuō yí biàn | tolong ulangi sekali lagi | INSERT (frasa) |
| 85 | 可以 | kěyǐ | boleh / bisa | UPDATE (ada) |
| 86 | 不可以 | bù kěyǐ | tidak boleh | INSERT (frasa) |
| 87 | 没问题 | méi wèntí | tidak masalah | INSERT (frasa) |
| 88 | 好的 | hǎo de | oke / baik | INSERT (frasa) |
| 89 | 当然 | dāngrán | tentu saja | UPDATE (ada) |
| 90 | 也许 | yěxǔ | mungkin | UPDATE (ada) |
| 91 | 差不多 | chàbuduō | hampir sama / kira-kira | UPDATE (ada) |
| 92 | 没事 | méishì | tidak apa-apa | UPDATE (ada) |
| 93 | 等一下 | děng yíxià | tunggu sebentar | INSERT (frasa) |
| 94 | 我同意 | wǒ tóngyì | saya setuju | INSERT (frasa) |
| 95 | 我不同意 | wǒ bù tóngyì | saya tidak setuju | INSERT (frasa) |
| 96 | 真的吗 | zhēn de ma | benarkah? | INSERT (frasa) |
| 97 | 太好了 | tài hǎo le | bagus sekali! | INSERT (frasa) |
| 98 | 加油 | jiāyóu | semangat! | UPDATE (ada) |
| 99 | 随便 | suíbiàn | terserah | UPDATE (ada) |
| 100 | 我也是 | wǒ yěshì | saya juga | INSERT (frasa) |

## Ringkasan

- Total: 100 item, `beginner_order` 1–100 sesuai urutan tabel di atas (per tema, berurutan).
- Tebakan status: ~45 UPDATE (kata tunggal umum), ~50 INSERT (frasa/kalimat), ~5 NEW? (tidak
  yakin, nama negara/istilah kurang inti — cek manual sebelum apply kalau mau presisi).
- SQL idempotent (`ON CONFLICT (hanzi) DO UPDATE`) — status di atas TIDAK memengaruhi keamanan
  menjalankan `sql/08_survival_kit.sql`, cuma informasi buat ekspektasi Kyaru.
