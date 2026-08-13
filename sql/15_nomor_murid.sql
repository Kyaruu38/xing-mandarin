-- ============================================================================
-- 15_nomor_murid.sql
-- Nomor murid untuk kartu murid: XM26-0142
--   XM   = Xing Mandarin
--   26   = dua digit tahun murid itu mulai
--   0142 = urutan dalam tahun itu
--
-- KENAPA DISIMPAN, BUKAN DIHITUNG WAKTU KARTUNYA DIBUKA
-- Kalau nomornya dihitung dari urutan baris, nomor seorang murid berubah begitu
-- ada murid lain dihapus atau tanggalnya dibetulkan. Nomor yang bisa berubah itu
-- bukan nomor: murid sudah terlanjur menyebutkannya di WhatsApp, dan admin sudah
-- terlanjur mencatatnya. Sekali diberikan, tidak pernah diganti.
--
-- KENAPA ADA ADVISORY LOCK
-- Nomor urut diambil dari nomor terbesar tahun itu, lalu ditambah satu. Dua
-- pendaftaran yang jatuh bersamaan akan membaca nomor terbesar yang sama dan
-- keduanya minta nomor yang sama. Unique constraint akan menolak yang kedua --
-- artinya pembuatan akunnya GAGAL, bukan sekadar nomornya bergeser. Kunci ini
-- membuat dua pendaftaran mengantre, dan hanya untuk tahun yang sama.
--
-- YANG DIBUAT
--   (1) profiles.student_id, unik
--   (2) fungsi nomor_murid_baru()
--   (3) trigger untuk murid baru
--   (4) pengisian untuk murid yang sudah ada
--
-- CARA PAKAI
-- Jalankan apa adanya dulu. Bagian (5) menampilkan hasilnya tanpa menyimpan apa
-- pun, karena berkas ini diakhiri ROLLBACK. Kalau angkanya sudah sesuai, ganti
-- ROLLBACK di baris terakhir jadi COMMIT lalu jalankan ulang.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- (1) Kolomnya.
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists student_id text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_student_id_key') then
    alter table public.profiles add constraint profiles_student_id_key unique (student_id);
  end if;
end$$;

comment on column public.profiles.student_id is
  'Nomor murid untuk kartu murid, bentuk XM26-0142. Diberikan sekali oleh trigger '
  'dan TIDAK PERNAH diganti, termasuk kalau paket atau tanggalnya berubah.';

-- ---------------------------------------------------------------------------
-- (2) Pembuat nomor.
--
-- Tahunnya diambil dari package_started_at kalau ada, kalau tidak dari created_at.
-- Bukan dari tanggal hari ini: murid yang dibetulkan datanya tahun depan tidak
-- boleh tiba-tiba jadi angkatan tahun depan.
-- ---------------------------------------------------------------------------
create or replace function public.nomor_murid_baru(p_acuan date)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_yy   text := to_char(coalesce(p_acuan, current_date), 'YY');
  v_urut integer;
begin
  perform pg_advisory_xact_lock(hashtext('nomor_murid_' || v_yy));

  select coalesce(max(substring(p.student_id from 9 for 4)::int), 0) + 1
    into v_urut
    from public.profiles p
   where p.student_id like 'XM' || v_yy || '-%';

  return 'XM' || v_yy || '-' || lpad(v_urut::text, 4, '0');
end;
$$;

-- ---------------------------------------------------------------------------
-- (3) Murid baru dapat nomor otomatis.
--
-- Trigger, bukan panggilan dari aplikasi. Akun dibuat lewat Edge Function
-- admin-users yang sumbernya tidak ada di repo, jadi jalur pembuatannya tidak
-- bisa diandalkan untuk memanggil apa pun. Trigger berlaku untuk siapa pun yang
-- melakukan insert, termasuk lewat SQL Editor.
--
-- Kalau student_id sudah diisi pemanggil, dibiarkan apa adanya: pemindahan data
-- dari sistem lain tidak boleh kehilangan nomor lamanya.
-- ---------------------------------------------------------------------------
create or replace function public.isi_nomor_murid()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.student_id is null then
    new.student_id := public.nomor_murid_baru(
      coalesce(new.package_started_at, new.created_at::date, current_date));
  end if;
  return new;
end;
$$;

drop trigger if exists trg_isi_nomor_murid on public.profiles;
create trigger trg_isi_nomor_murid
  before insert on public.profiles
  for each row execute function public.isi_nomor_murid();

-- ---------------------------------------------------------------------------
-- (4) Murid yang sudah ada.
--
-- Diurutkan menurut created_at supaya nomor kecil betul-betul berarti "daftar
-- lebih dulu". Tahun ikut tahun masing-masing murid, bukan tahun sekarang, jadi
-- angkatan lama tetap terbaca sebagai angkatan lama.
-- ---------------------------------------------------------------------------
with urut as (
  select p.id,
         to_char(coalesce(p.package_started_at, p.created_at::date), 'YY') as yy,
         row_number() over (
           partition by to_char(coalesce(p.package_started_at, p.created_at::date), 'YY')
           order by p.created_at, p.id
         ) as n
    from public.profiles p
   where p.student_id is null
)
update public.profiles p
   set student_id = 'XM' || u.yy || '-' || lpad(u.n::text, 4, '0')
  from urut u
 where p.id = u.id;

-- ---------------------------------------------------------------------------
-- (5) Lihat hasilnya. Tidak menyimpan apa pun -- berkas ini diakhiri ROLLBACK.
-- ---------------------------------------------------------------------------
select count(*) filter (where student_id is null) as belum_punya_nomor,
       count(*) filter (where student_id is not null) as sudah_punya_nomor,
       count(distinct student_id) as nomor_unik,
       count(*) as total_murid
  from public.profiles;

select student_id, display_name, package,
       coalesce(package_started_at, created_at::date) as acuan_tahun
  from public.profiles
 order by student_id
 limit 20;

ROLLBACK;
