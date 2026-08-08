-- ============================================================================
-- 13a_cek_sebelum_commit.sql  —  JALANKAN INI DULU sebelum COMMIT 13.
-- Read-only. Tidak mengubah apa pun.
--
-- Kenapa perlu: allowed_levels() mengembalikan array KOSONG kalau
--   status = 'expired'  ATAU  subscription_end < hari ini (WIB).
-- Selama ini pagar itu cuma di JavaScript. Begitu masuk ke RLS, user yang
-- kena kondisi tersebut TIDAK akan melihat soal/vocab sama sekali dari
-- database — bukan cuma diblokir tampilannya.
--
-- Kalau ada user AKTIF yang subscription_end-nya kelewat karena lupa
-- diperpanjang, dia bakal langsung "kosong" begitu di-COMMIT. Perbaiki
-- tanggalnya dulu, baru COMMIT.
--
-- Catatan: tabel profiles TIDAK punya kolom email (email ada di auth.users,
-- diambil aplikasi lewat edge function admin-users). Jadi di sini dipakai
-- display_name + id.
-- ============================================================================

SELECT
  CASE
    WHEN role = 'admin' THEN 'ADMIN — selalu penuh'
    WHEN status = 'expired' THEN '>>> AKAN KOSONG (status expired)'
    WHEN subscription_end IS NOT NULL
         AND subscription_end < (now() AT TIME ZONE 'Asia/Jakarta')::date
      THEN '>>> AKAN KOSONG (tanggal lewat: ' || subscription_end || ')'
    ELSE 'aman'
  END                                   AS dampak,
  display_name,
  id,
  package,
  status,
  subscription_end,
  CASE
    WHEN role = 'admin' THEN '1-6 (+7)'
    WHEN status = 'expired'
      OR (subscription_end IS NOT NULL
          AND subscription_end < (now() AT TIME ZONE 'Asia/Jakarta')::date)
      THEN '(tidak ada)'
    WHEN package = 'hsk_5'    THEN '1-5'
    WHEN package = 'hsk_6'    THEN '1-6'
    WHEN package = 'vip'      THEN '1-6'
    WHEN package = 'business' THEN '1-5'
    ELSE '1-4'
  END                                   AS level_setelah_perubahan
FROM public.profiles
ORDER BY
  CASE
    WHEN role = 'admin' THEN 3
    WHEN status = 'expired'
      OR (subscription_end IS NOT NULL
          AND subscription_end < (now() AT TIME ZONE 'Asia/Jakarta')::date) THEN 1
    ELSE 2
  END,
  package, display_name;
