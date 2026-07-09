-- HSK 2.0 (lama) vocab table
-- Sumber: data/complete.json, difilter cuma level "old-1".."old-6" (HSK 2.0), BUKAN new-*/newest-* (HSK 3.0)
-- 4991 kata total: L1=150, L2=147, L3=298, L4=598, L5=1298, L6=2500

CREATE TABLE vocab (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- kolom utama, dipakai langsung sama flashcard/SRS (ga usah bongkar JSONB)
  hanzi        TEXT NOT NULL UNIQUE,           -- simplified, ini juga jadi item_key buat user_mastery
  pinyin       TEXT NOT NULL,                  -- pelafalan utama (dari forms[0])
  meaning_en   TEXT NOT NULL,                  -- arti utama (dari forms[0].meanings[0])
  meaning_id   TEXT,                           -- arti Indonesia, nullable — diisi belakangan (wave berikutnya), UI fallback ke meaning_en kalau NULL
  hsk_level    SMALLINT NOT NULL CHECK (hsk_level BETWEEN 1 AND 6),

  -- metadata tambahan
  radical      TEXT,
  frequency    INTEGER,
  pos          TEXT[] NOT NULL DEFAULT '{}',   -- part-of-speech tags, mis. {"n","v"}

  -- data lengkap/cadangan: SEMUA form (termasuk yang jadi kolom utama di atas),
  -- dipake kalau nanti butuh fitur "pelafalan/arti lain"
  forms        JSONB NOT NULL,

  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_vocab_hsk_level ON vocab (hsk_level);

COMMENT ON TABLE vocab IS 'HSK 2.0 (lama) vocab, level old-1..old-6, sumber complete.json';
COMMENT ON COLUMN vocab.hanzi IS 'simplified hanzi, unique, dipakai sebagai item_key di user_mastery (UNIQUE(user_id, item_key))';
COMMENT ON COLUMN vocab.forms IS 'array lengkap semua form (pinyin/arti/classifier) dari dataset asli, form[0] = sumber kolom pinyin/meaning_en di atas';

-- ============================================================
-- RLS: wajib, "Auto-expose new tables" OFF di project ini.
-- Pola: vocab = referensi bersama -> semua user login (authenticated) boleh SELECT.
--       Tulis (INSERT/UPDATE) cuma admin, lewat is_admin() (function yang sudah ada).
-- ============================================================

ALTER TABLE vocab ENABLE ROW LEVEL SECURITY;

CREATE POLICY vocab_select_authenticated
  ON vocab
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY vocab_insert_admin
  ON vocab
  FOR INSERT
  TO authenticated
  WITH CHECK (is_admin());

CREATE POLICY vocab_update_admin
  ON vocab
  FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- Tidak ada policy DELETE -> default-deny, nobody (termasuk admin) bisa DELETE lewat role authenticated.
-- Kalau nanti butuh admin bisa DELETE, tambah policy FOR DELETE TO authenticated USING (is_admin()) terpisah.

-- GRANT eksplisit ke role authenticated (wajib, karena auto-expose OFF).
-- GRANT ini menentukan operasi apa yang BOLEH dicoba; RLS policy di atas yang nentuin baris mana.
-- Tanpa GRANT INSERT/UPDATE di sini, is_admin() di policy pun ga akan pernah kepanggil (ditolak duluan di level privilege).
GRANT SELECT ON vocab TO authenticated;
GRANT INSERT, UPDATE ON vocab TO authenticated;

-- role anon TIDAK di-GRANT apa pun -> vocab tidak bisa diakses tanpa login, sesuai brief.
