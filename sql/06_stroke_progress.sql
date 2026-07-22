-- stroke_progress: hasil TES mode dari fitur Latihan Goresan (Hanzi Writer stroke practice).
-- Satu row per karakter per attempt selesai (TES mode aja -- LIHAT/TRACE tidak nulis apa-apa
-- ke sini, itu cuma latihan bebas). character bukan FK ke vocab.hanzi -- vocab.hanzi nyimpen
-- KATA (bisa multi-karakter, mis. "动物"), sedangkan stroke_progress.character adalah SATU
-- karakter hasil pecah per-huruf (Array.from(word.hanzi) di client), jadi tidak selalu ada
-- padanan baris vocab.hanzi = character.

CREATE TABLE stroke_progress (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  character    TEXT NOT NULL,
  mistakes     INTEGER NOT NULL DEFAULT 0 CHECK (mistakes >= 0),
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_stroke_progress_user_id ON stroke_progress (user_id);

COMMENT ON TABLE stroke_progress IS 'Hasil TES mode di fitur Latihan Goresan (Hanzi Writer), satu row per karakter per attempt selesai';
COMMENT ON COLUMN stroke_progress.character IS 'satu hanzi (bukan kata) -- word multi-karakter dipecah per-huruf di client sebelum insert';

-- ============================================================
-- RLS: wajib, "Auto-expose new tables" OFF di project ini (sama seperti vocab, lihat
-- 01_vocab_schema.sql). Pola: user cuma boleh baca/tulis baris miliknya sendiri.
-- SENGAJA tidak ada policy UPDATE atau DELETE -- riwayat latihan goresan bersifat
-- append-only, sama seperti test_attempts, jadi default-deny (RLS enabled + no policy)
-- sudah cukup, tidak perlu is_admin() override kayak vocab.
-- ============================================================

ALTER TABLE stroke_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own stroke progress select"
  ON stroke_progress
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "own stroke progress insert"
  ON stroke_progress
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Tidak ada policy UPDATE/DELETE -> default-deny, tidak ada yang bisa update/hapus row lewat
-- role authenticated (termasuk admin -- kalau nanti butuh admin baca semua row buat laporan,
-- tambah policy SELECT admin terpisah pakai is_admin(), jangan modif 2 policy di atas).

-- GRANT eksplisit ke role authenticated (wajib, karena auto-expose OFF). Sengaja cuma
-- SELECT+INSERT -- tidak GRANT UPDATE/DELETE, biar konsisten sama larangan policy di atas.
GRANT SELECT, INSERT ON stroke_progress TO authenticated;

-- role anon TIDAK di-GRANT apa pun -> stroke_progress tidak bisa diakses tanpa login.
