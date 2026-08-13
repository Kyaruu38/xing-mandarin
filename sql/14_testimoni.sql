-- ============================================================================
-- 14_testimoni.sql
-- Testimoni murid: ditulis di dalam aplikasi (Raport), dibaca di halaman depan.
--
-- SELURUH NILAI FITUR INI ADA DI SATU KALIMAT: angkanya tidak bisa dikarang.
-- Kalau skor, paket, dan lama belajar bisa diketik murid, halaman testimoni ini
-- persis sama dengan testimoni mana pun di internet dan tidak ada gunanya dibuat.
-- Karena itu KLIEN TIDAK PERNAH MENGIRIM ANGKA. Yang dikirim cuma dua kalimat dan
-- tiga pilihan tampilan; seluruh angka dihitung ulang di dalam database.
--
-- Ini pelajaran yang sudah pernah mahal di repo ini: sql/13 mencatat test_attempts
-- sempat di-GRANT INSERT langsung ke `authenticated`, sehingga skor bisa dikarang
-- dari DevTools lalu masuk ke Raport dan grafik prediksi. Pola yang sama tidak
-- diulang di sini.
--
-- YANG DIBUAT
--   (1) profiles.package_started_at  -- tanggal mulai paket, diisi admin
--   (2) profiles.is_minor            -- penanda murid anak, dikecualikan dari fitur ini
--   (3) tabel public.testimonials
--   (4) fungsi submit_testimonial()  -- satu-satunya jalan masuk, SECURITY DEFINER
--   (5) fungsi withdraw_testimonial()
--   (6) RLS + GRANT per kolom
--
-- CARA PAKAI
-- Jalankan apa adanya dulu. Bagian (7) menampilkan hasilnya tanpa menyimpan apa pun,
-- karena berkas ini diakhiri ROLLBACK. Kalau sudah sesuai, ganti ROLLBACK di baris
-- terakhir jadi COMMIT lalu jalankan ulang. Pola ini sama dengan sql/13.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- (1) Tanggal mulai paket.
--
-- profiles sekarang punya TIGA kolom tanggal dan tidak satu pun menandai kapan
-- seseorang mulai belajar: created_at (akun dibuat), subscription_end, dan
-- expires_at. Diperiksa 13 Agu 2026 lewat information_schema.
--
-- Sengaja NULL untuk semua murid yang sudah jalan. Tanggal mulai mereka cuma ada
-- di catatan Kyaru, bukan di sistem, dan menebaknya dari subscription_end dikurangi
-- durasi paket akan meleset diam-diam begitu ada perpanjangan atau jeda. Baris
-- "lama belajar" tidak ditampilkan kalau kolom ini kosong -- lebih baik hilang
-- daripada salah.
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists package_started_at date;

comment on column public.profiles.package_started_at is
  'Tanggal murid mulai paket berjalan. Diisi admin. NULL = tidak diketahui; '
  'lama belajar tidak ditampilkan, JANGAN ditaksir dari subscription_end.';

-- ---------------------------------------------------------------------------
-- (2) Penanda murid anak.
--
-- Kyaru minta kelas Kids (4-9 tahun) dikecualikan dari testimoni. Ternyata TIDAK
-- ADA cara mendeteksinya dari data yang ada: kode paket cuma hsk_1_4, hsk_5, hsk_6,
-- business, convo, vip -- kelas Kids dijual di luar platform dan tidak punya kode
-- sendiri. Tanpa kolom ini, "Kids dikecualikan" cuma niat, bukan pagar.
--
-- Default false karena mayoritas murid dewasa. Admin yang menyalakannya waktu
-- membuat akun anak.
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists is_minor boolean not null default false;

comment on column public.profiles.is_minor is
  'true = akun murid anak. Memblokir testimoni. Tidak ada data umur di sistem, '
  'jadi ini harus diisi admin -- tidak bisa disimpulkan dari package.';

-- ---------------------------------------------------------------------------
-- (3) Tabel testimoni.
--
-- Kolom snap_* adalah POTRET saat testimoni dikirim, bukan sambungan hidup ke
-- profiles/test_attempts. Alasannya bukan performa: kalau angkanya ikut berubah
-- setiap murid latihan lagi, tiga bulan lagi tulisannya bercerita naik dari 118
-- sementara angka di sebelahnya sudah lain, dan testimoninya jadi omong kosong.
--
-- public_name sudah dalam bentuk siap tayang (nama depan / inisial / "Murid ...").
-- Nama asli disimpan terpisah di snap_display_name dan TIDAK di-GRANT ke anon.
-- Kalau penyamaran namanya dikerjakan di JavaScript halaman depan, nama aslinya
-- tetap harus dikirim ke browser dulu -- artinya "anonim" cuma anonim di layar.
-- ---------------------------------------------------------------------------
create table if not exists public.testimonials (
  user_id           uuid primary key references auth.users(id) on delete cascade,

  before_text       text not null,
  after_text        text not null,

  name_mode         text not null default 'first'
                    check (name_mode in ('first','initial','anon')),
  show_score        boolean not null default true,
  show_package      boolean not null default true,

  -- potret, diisi fungsi, bukan klien
  public_name       text,
  snap_display_name text,
  snap_package      text,
  snap_started_at   date,
  snap_months       integer,
  snap_level        integer,
  -- Seksi mana yang diukur: 'all' kalau murid pernah mengerjakan mock test utuh,
  -- kalau tidak diisi seksi yang paling sering dia kerjakan di level itu.
  snap_section      text,
  snap_score_first  integer,
  snap_score_last   integer,
  -- Deret skor buat grafik, DIPISAH PER SEKSI:
  --   {"listening":[{"d":"2026-05-01","v":47}, ...], "reading":[...],
  --    "writing":[...], "all":[...]}
  -- Dipisah, bukan satu deret gabungan, karena listening dan writing itu dua
  -- kemampuan yang berbeda dan naiknya tidak bersamaan -- menumpuknya jadi satu
  -- garis menyembunyikan justru bagian yang paling berguna dibaca.
  -- Kunci "all" hanya terisi kalau murid pernah mengerjakan mock test utuh.
  -- Ikut dibekukan seperti snap_* yang lain. Grafik di Raport dihitung hidup dari
  -- test_attempts; yang ini khusus untuk halaman depan, supaya gambar di testimoni
  -- tidak diam-diam berubah tiap murid latihan lagi.
  snap_series       jsonb not null default '{}'::jsonb,

  -- Tanggapan admin. Ditulis admin, tampil di bawah cerita murid di halaman depan.
  admin_reply       text,
  admin_reply_at    timestamptz,

  status            text not null default 'pending'
                    check (status in ('pending','published','hidden')),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  published_at      timestamptz
);

-- Satu baris per murid: primary key user_id. Murid menyunting testimoninya,
-- bukan menumpuk testimoni baru. Ini juga yang membuat spam tidak mungkin.

create index if not exists testimonials_published_idx
  on public.testimonials (published_at desc)
  where status = 'published';

-- ---------------------------------------------------------------------------
-- (4) Satu-satunya jalan masuk.
--
-- SECURITY DEFINER, dan seluruh angka dihitung DI SINI dari profiles serta
-- test_attempts milik pemanggil. Klien tidak punya cara mengirim skor.
--
-- Skor dipakai dalam PERSEN (score/total_points), bukan angka mentah, supaya
-- set soal dengan bobot berbeda tetap bisa dibandingkan -- sama dengan yang
-- ditampilkan layar Hasil Mock Test sekarang.
--
-- Percobaan section='all' (mock test utuh) yang paling dulu dipakai, karena itu
-- gambaran kemampuan paling lengkap.
--
-- TAPI: diperiksa 13 Agu 2026 di prod, dari 143 percobaan yang ada TIDAK SATU PUN
-- section='all' -- semuanya reading (64), listening (54), writing (25). Artinya
-- belum ada murid yang pernah menyelesaikan mock test utuh. Kalau fungsi ini cuma
-- menerima 'all', kolom skor di SETIAP testimoni akan kosong dan fiturnya mati
-- diam-diam sejak hari pertama.
--
-- Karena itu ada cadangan: seksi yang PALING SERING dikerjakan murid di level
-- terakhirnya. Yang dibandingkan tetap satu seksi yang sama dari awal ke akhir --
-- membandingkan listening lama dengan reading baru itu angka yang bohong.
-- Seksi mana yang dipakai ikut disimpan di snap_section supaya bisa ditulis apa
-- adanya di kartu testimoni ("Simulasi HSK 4 - Listening"), bukan disamarkan.
-- ---------------------------------------------------------------------------
create or replace function public.submit_testimonial(
  p_before       text,
  p_after        text,
  p_name_mode    text default 'first',
  p_show_score   boolean default true,
  p_show_package boolean default true
) returns public.testimonials
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid    uuid := auth.uid();
  v_prof   public.profiles%rowtype;
  v_first  integer;
  v_last   integer;
  v_level  integer;
  v_months integer;
  v_name   text;
  v_series jsonb;
  v_section text;
  v_out    public.testimonials%rowtype;
begin
  if v_uid is null then
    raise exception 'Harus login' using errcode = '42501';
  end if;

  select * into v_prof from public.profiles where id = v_uid;
  if not found then
    raise exception 'Profil tidak ditemukan' using errcode = '42501';
  end if;

  if v_prof.is_minor then
    raise exception 'Akun murid anak tidak bisa mengirim testimoni'
      using errcode = '42501';
  end if;

  if coalesce(btrim(p_before), '') = '' or coalesce(btrim(p_after), '') = '' then
    raise exception 'Dua kalimatnya harus diisi' using errcode = '22023';
  end if;

  if length(btrim(p_before)) > 140 or length(btrim(p_after)) > 140 then
    raise exception 'Maksimal 140 karakter per kalimat' using errcode = '22023';
  end if;

  if p_name_mode not in ('first','initial','anon') then
    raise exception 'Pilihan nama tidak dikenal' using errcode = '22023';
  end if;

  -- Skor pertama dan terakhir dari percobaan gabungan, level tertinggi yang
  -- pernah dikerjakan. Level diambil dari percobaan TERAKHIR, bukan max(), supaya
  -- angkanya sepasang: skor awal dan skor akhir harus dari level yang sama, kalau
  -- tidak lompatannya membandingkan dua ujian yang berbeda kesulitannya.
  select a.hsk_level into v_level
    from public.test_attempts a
   where a.user_id = v_uid and coalesce(a.total_points,0) > 0
   order by a.created_at desc
   limit 1;

  if v_level is not null then
    -- 'all' menang kalau ada; kalau tidak, seksi terbanyak di level itu.
    select a.section into v_section
      from public.test_attempts a
     where a.user_id = v_uid and a.hsk_level = v_level
       and coalesce(a.total_points,0) > 0
     group by a.section
     order by (a.section = 'all') desc, count(*) desc, a.section
     limit 1;
  end if;

  if v_section is not null then
    select round(100.0 * a.score / a.total_points)::int into v_first
      from public.test_attempts a
     where a.user_id = v_uid and a.section = v_section
       and a.hsk_level = v_level and coalesce(a.total_points,0) > 0
     order by a.created_at asc
     limit 1;

    select round(100.0 * a.score / a.total_points)::int into v_last
      from public.test_attempts a
     where a.user_id = v_uid and a.section = v_section
       and a.hsk_level = v_level and coalesce(a.total_points,0) > 0
     order by a.created_at desc
     limit 1;
  end if;

  -- Deret skor untuk grafik, satu larik per seksi. Level yang sama dengan skor
  -- awal/akhir, urut waktu. Seksi yang belum pernah dikerjakan tidak muncul
  -- sebagai kunci kosong -- tidak ada, ya tidak ada.
  select coalesce(jsonb_object_agg(s.section, s.titik), '{}'::jsonb)
    into v_series
    from (
      select a.section,
             jsonb_agg(jsonb_build_object(
               'd', a.created_at::date,
               'v', round(100.0 * a.score / a.total_points)::int)
               order by a.created_at) as titik
        from public.test_attempts a
       where a.user_id = v_uid and a.hsk_level = v_level
         and coalesce(a.total_points,0) > 0
       group by a.section
    ) s;

  -- Lama belajar. NULL kalau tanggal mulainya belum diisi admin -- tidak ditaksir.
  if v_prof.package_started_at is not null then
    v_months := greatest(1, (
      (extract(year from age(current_date, v_prof.package_started_at)) * 12)
      + extract(month from age(current_date, v_prof.package_started_at))
    )::int);
  end if;

  -- Nama siap tayang. Dihitung di sini supaya nama asli tidak perlu ikut terkirim
  -- ke browser pengunjung sama sekali.
  v_name := case p_name_mode
    when 'first'   then split_part(btrim(coalesce(v_prof.display_name, '')), ' ', 1)
    when 'initial' then left(btrim(coalesce(v_prof.display_name, '')), 1) || '.'
    -- Bukan 'Murid ' || package: kode paketnya mentah (hsk_1_4, convo) dan bocor
    -- ke halaman publik sebagai nama orang. Paketnya sudah punya barisnya sendiri.
    else 'Murid Xing Mandarin'
  end;
  if coalesce(btrim(v_name), '') in ('', '.') then
    v_name := 'Murid Xing Mandarin';
  end if;

  insert into public.testimonials as t (
    user_id, before_text, after_text, name_mode, show_score, show_package,
    public_name, snap_display_name, snap_package, snap_started_at, snap_months,
    snap_level, snap_section, snap_score_first, snap_score_last, snap_series, status, updated_at, published_at
  ) values (
    v_uid, btrim(p_before), btrim(p_after), p_name_mode, p_show_score, p_show_package,
    v_name, v_prof.display_name, v_prof.package, v_prof.package_started_at, v_months,
    v_level, v_section, v_first, v_last, coalesce(v_series, '{}'::jsonb), 'pending', now(), null
  )
  on conflict (user_id) do update set
    before_text       = excluded.before_text,
    after_text        = excluded.after_text,
    name_mode         = excluded.name_mode,
    show_score        = excluded.show_score,
    show_package      = excluded.show_package,
    public_name       = excluded.public_name,
    snap_display_name = excluded.snap_display_name,
    snap_package      = excluded.snap_package,
    snap_started_at   = excluded.snap_started_at,
    snap_months       = excluded.snap_months,
    snap_level        = excluded.snap_level,
    snap_section      = excluded.snap_section,
    snap_score_first  = excluded.snap_score_first,
    snap_score_last   = excluded.snap_score_last,
    snap_series       = excluded.snap_series,
    -- Tanggapan admin TIDAK dihapus waktu murid menyunting: itu tulisan orang lain.
    -- Statusnya balik ke pending, jadi admin tetap meninjau ulang sebelum tayang.
    -- Disunting = harus ditinjau lagi. Kalau status dibiarkan 'published',
    -- murid bisa lolos moderasi sekali lalu mengganti isinya jadi apa saja.
    status            = 'pending',
    published_at      = null,
    updated_at        = now()
  returning * into v_out;

  return v_out;
end;
$$;

-- Menarik testimoni sendiri. Dihapus, bukan disembunyikan: ini permintaan murid
-- atas datanya sendiri, jadi tidak ada alasan menyimpan salinannya.
create or replace function public.withdraw_testimonial()
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  delete from public.testimonials where user_id = auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- (5) RLS.
-- ---------------------------------------------------------------------------
alter table public.testimonials enable row level security;

drop policy if exists "testimoni: baca punya sendiri" on public.testimonials;
create policy "testimoni: baca punya sendiri"
  on public.testimonials for select to authenticated
  using (user_id = auth.uid());

-- Yang sudah disetujui boleh dibaca siapa pun, termasuk pengunjung halaman depan
-- yang belum login. Kolom yang boleh mereka lihat dibatasi GRANT di bagian (6),
-- bukan di sini -- policy tidak bisa menyaring kolom.
drop policy if exists "testimoni: baca yang sudah tayang" on public.testimonials;
create policy "testimoni: baca yang sudah tayang"
  on public.testimonials for select to anon, authenticated
  using (status = 'published');

-- Admin TIDAK diberi policy select/update di sini. Moderasi lewat dua fungsi di
-- bagian (6b), karena admin juga role `authenticated`: memberinya policy select
-- semua baris otomatis membuka kolom yang sama untuk SEMUA murid yang login --
-- policy menyaring baris, GRANT menyaring kolom, dan keduanya tidak bisa saling
-- menggantikan. Itu persis lubang yang ketahuan waktu berkas ini diuji.

-- ---------------------------------------------------------------------------
-- (6) GRANT per kolom.
--
-- Tidak ada INSERT dan tidak ada UPDATE untuk `authenticated`. Satu-satunya jalan
-- menulis adalah submit_testimonial(), dan fungsi itu yang menghitung angkanya.
-- Ini pagar yang sesungguhnya; RLS di atas cuma mengatur siapa boleh MEMBACA.
--
-- anon TIDAK boleh melihat: user_id, snap_display_name (nama asli, yang justru
-- disembunyikan kalau murid memilih inisial/anonim), status, dan snap_started_at
-- (tanggal itu tidak perlu diketahui publik, cukup lama belajarnya).
-- ---------------------------------------------------------------------------
revoke all on public.testimonials from anon, authenticated;

-- Kolom yang boleh dilihat pengunjung halaman depan. snap_display_name TIDAK ada
-- di daftar ini, dan itu inti seluruh janji "anonim": kalau nama asli ikut sampai
-- ke browser, penyamaran di JavaScript cuma penyamaran di layar.
grant select (public_name, before_text, after_text, show_score, show_package,
              snap_package, snap_months, snap_level, snap_score_first,
              snap_section, snap_score_last, snap_series, admin_reply, admin_reply_at,
              published_at)
  on public.testimonials to anon;

-- Murid yang login dapat kolom yang sama, ditambah name_mode dan status supaya
-- formnya bisa diisi ulang waktu dia menyunting.
--
-- SENGAJA TIDAK diberi `grant select on ... to authenticated` polos. Bentuk itu
-- kelihatan wajar dan lolos semua pemeriksaan RLS, tapi digabung dengan policy
-- "baca yang sudah tayang" hasilnya: murid mana pun yang login bisa menarik
-- snap_display_name milik murid LAIN -- termasuk yang memilih tampil anonim.
-- Ketahuan waktu berkas ini dijalankan di Postgres lokal, bukan dari membaca ulang.
grant select (public_name, before_text, after_text, show_score, show_package,
              snap_package, snap_months, snap_level, snap_score_first,
              snap_section, snap_score_last, snap_series, admin_reply, admin_reply_at,
              published_at, name_mode, status, created_at, updated_at)
  on public.testimonials to authenticated;

-- Tidak ada INSERT, UPDATE, atau DELETE untuk siapa pun. Seluruh penulisan lewat
-- fungsi di bawah, dan fungsi itu yang menghitung angkanya.
grant execute on function public.submit_testimonial(text,text,text,boolean,boolean)
  to authenticated;
grant execute on function public.withdraw_testimonial() to authenticated;

-- ---------------------------------------------------------------------------
-- (6b) Moderasi. Dua fungsi, bukan policy, karena alasan di bagian (5).
-- ---------------------------------------------------------------------------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from public.profiles p
                  where p.id = auth.uid() and p.role = 'admin');
$$;

create or replace function public.admin_list_testimonials(p_status text default null)
returns setof public.testimonials
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_admin() then
    raise exception 'Khusus admin' using errcode = '42501';
  end if;
  return query
    select * from public.testimonials t
     where p_status is null or t.status = p_status
     order by t.updated_at desc;
end;
$$;

create or replace function public.admin_set_testimonial_status(
  p_user_id uuid, p_status text
) returns public.testimonials
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_out public.testimonials%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Khusus admin' using errcode = '42501';
  end if;
  if p_status not in ('pending','published','hidden') then
    raise exception 'Status tidak dikenal' using errcode = '22023';
  end if;
  update public.testimonials
     set status = p_status,
         published_at = case when p_status = 'published' then now() else null end,
         updated_at = now()
   where user_id = p_user_id
  returning * into v_out;
  return v_out;
end;
$$;

-- Tanggapan admin. Fungsi terpisah dari persetujuan status supaya admin bisa
-- membalas tanpa harus ikut mengubah status, dan sebaliknya.
create or replace function public.admin_reply_testimonial(
  p_user_id uuid, p_reply text
) returns public.testimonials
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_out public.testimonials%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Khusus admin' using errcode = '42501';
  end if;
  if length(coalesce(btrim(p_reply), '')) > 400 then
    raise exception 'Tanggapan maksimal 400 karakter' using errcode = '22023';
  end if;
  update public.testimonials
     set admin_reply    = nullif(btrim(p_reply), ''),
         admin_reply_at = case when nullif(btrim(p_reply), '') is null
                               then null else now() end,
         updated_at     = now()
   where user_id = p_user_id
  returning * into v_out;
  return v_out;
end;
$$;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.admin_list_testimonials(text) to authenticated;
grant execute on function public.admin_set_testimonial_status(uuid,text) to authenticated;
grant execute on function public.admin_reply_testimonial(uuid,text) to authenticated;

-- ---------------------------------------------------------------------------
-- (7) Tampilkan hasilnya. Tidak menyimpan apa pun -- berkas ini diakhiri ROLLBACK.
-- ---------------------------------------------------------------------------
select 'kolom baru di profiles' as bagian, column_name, data_type
  from information_schema.columns
 where table_schema = 'public' and table_name = 'profiles'
   and column_name in ('package_started_at','is_minor')
union all
select 'kolom testimonials', column_name, data_type
  from information_schema.columns
 where table_schema = 'public' and table_name = 'testimonials'
 order by 1, 2;

select policyname, cmd, roles::text
  from pg_policies
 where schemaname = 'public' and tablename = 'testimonials'
 order by policyname;

-- Yang paling penting diperiksa: anon TIDAK boleh punya hak apa pun di kolom
-- snap_display_name, user_id, dan status.
select grantee, column_name, privilege_type
  from information_schema.column_privileges
 where table_schema = 'public' and table_name = 'testimonials'
   and grantee in ('anon','authenticated')
 order by grantee, column_name;

ROLLBACK;
