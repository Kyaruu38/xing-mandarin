-- 24_attempt_progress.sql
-- SUDAH DIJALANKAN KE PROD: 14 Agustus 2026, lewat SQL Editor.
-- File ini ARSIP (biar riwayatnya kebaca di repo), bukan pending action.
--
-- Kebutuhan: set mock test PER-BAGIAN (Listening/Reading/Writing sendiri-sendiri)
-- diposisikan sebagai LATIHAN, bukan ujian. Murid boleh berhenti di tengah jalan,
-- nutup tab, ganti device, lalu lanjut dari soal & detik yang sama.
--
-- Yang TIDAK berubah: exam gabungan (tab "Semua") tetap simulasi ujian betulan --
-- hitung mundur, nggak bisa di-pause, nggak pernah nyentuh tabel ini.
--
-- Kenapa di database, bukan localStorage: murid sering mulai di laptop lalu lanjut
-- di HP. localStorage nggak ikut pindah device dan hilang begitu clear browsing data.

create table if not exists public.attempt_progress (
  user_id         uuid    not null references public.profiles(id) on delete cascade,
  set_id          text    not null references public.test_sets(set_id),
  answers         jsonb   not null default '{}'::jsonb,   -- {question_id: jawaban}
  current_index   int     not null default 0,             -- posisi soal terakhir (0-based)
  elapsed_seconds int     not null default 0,             -- stopwatch, NAIK (bukan sisa waktu)
  flagged         jsonb   not null default '[]'::jsonb,   -- id soal yang ditandai murid
  updated_at      timestamptz not null default now(),
  primary key (user_id, set_id)
);

alter table public.attempt_progress enable row level security;

-- Pola RLS-nya sengaja disamain persis dengan public.user_mastery yang sudah ada,
-- bukan bikin gaya baru: murid cuma bisa nyentuh barisnya sendiri, admin boleh baca.
drop policy if exists "own progress rw" on public.attempt_progress;
create policy "own progress rw" on public.attempt_progress
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "admin reads progress" on public.attempt_progress;
create policy "admin reads progress" on public.attempt_progress
  for select using (is_admin());

grant select, insert, update, delete on public.attempt_progress to authenticated;

-- CATATAN KEAMANAN: isi tabel ini murni milik murid sendiri (jawaban, posisi, waktu).
-- TIDAK ada kunci jawaban di sini -- kunci tetap cuma keluar lewat submit_attempt /
-- review_attempt. Jadi walaupun barisnya dibaca klien, nggak ada yang bocor.
--
-- Barisnya dihapus otomatis oleh app begitu set-nya di-submit (lihat submitAttempt),
-- dan pas murid milih "Mulai dari awal" di dialog lanjutan.
