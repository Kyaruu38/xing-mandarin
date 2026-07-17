# Handoff — session 12 (Gap #2 step 2 APPLIED to live + submit-button ratchet fix, #42-46)

Scope: continuation of Gap #2 (server-side enforcement audit, #22/#41/#42) — this session took
the RLS/GRANT/function snapshot from #42 and shipped the first real fix (`submit_attempt`'s
`is_published` gate), then caught and fixed an unrelated pre-existing bug surfaced by testing
that fix. Report-first at every step (plan → approve → SQL/code → verify → commit), same
pattern as every prior session in this sequence.

## `submit_attempt` is_published gate: DONE, APPROVED, VERIFIED LIVE, COMMITTED — `1500c94`

Full writeup: DECISIONS_NEEDED #42 (audit + agreed fix order: `submit_attempt` before table
RLS) → #43 (this fix, plus the essay-`total_questions` "fix" that was proposed, investigated,
and REJECTED — would have broken the #9 scoring formula for mixed objective+essay sections;
live behavior there was already correct, the OLD comment in `sql/03_submit_attempt_essay.sql`
was wrong, not the code).

**What shipped**: `sql/05_submit_attempt_gap2_fixes.sql` — one `CREATE OR REPLACE`, one real
change: reject `p_set_id` that doesn't match a published `test_sets` row. Previously
`submit_attempt` (SECURITY DEFINER) never checked `is_published` at all, meaning it could be
called directly for a draft/unpublished set and its answer key harvested through the RPC even
though the underlying `question_bank.answer`/`explanation` columns are correctly
column-GRANT-protected from direct SELECT (confirmed in #42's dump). **Verified live**: before
the fix, an unpublished set (`hsk6-reading-1`) returned `200` from the RPC; after, `400`
(`"set not found or not published"`). Normal submissions on published sets unaffected.

**Explicitly NOT done** (per #43): no throttle/rate-limit on repeated submissions (considered,
rejected — `startCombinedAttempt()` calls this RPC 3x in seconds for a combined HSK3-6
attempt, so any distinct-set-per-time-window threshold false-positives on a single legitimate
combined attempt, and a patient script could still nibble under any threshold anyway). The
underlying exam-integrity gap (server has no way to distinguish a genuine submission from a
scripted empty one — the real fix needs a server-tracked attempt-session token, which needs new
schema) is **accepted as open debt**, logged, with an explicit trigger: must be built before any
non-insider paying user exists. RLS-by-package on `vocab`/`test_sets`/`question_bank` (the
other half of Gap #2) is still not started — blocked on the `package_levels` source-of-truth
decision from #41/#42, deliberately sequenced after this fix per #43's reasoning.

## Submit-button ratchet bug: DONE, APPROVED, VERIFIED LIVE, COMMITTED

Found while verifying the `is_published` fix above (user noticed "Retake test" left Submit
permanently disabled) — audited first (no code), traced the real mechanism, then fixed.

**Root cause** (DECISIONS_NEEDED #46): `attemptSubmitBtn.disabled` was only ever touched in 3
places — set `true` at the start of `submitAttempt()`, reset `false` in its 2 error branches.
**Zero reset on the success path.** Not a retake-specific bug — session-wide: once any
submission succeeds, every subsequent attempt (retake OR a completely different fresh set from
Mock List) inherits the stale `disabled=true`, since both paths call the same
`startAttempt()`/`startCombinedAttempt()` and neither ever reset it. Confirmed via live console
testing that "fresh start works" and "retake doesn't" was never a real behavioral difference —
both are equally broken once triggered; the user's belief came from testing sequence, not code
divergence. Pure client-side, zero relation to the `submit_attempt` SQL change.

**Fix**: `$('attemptSubmitBtn').disabled = false;` added at the very start of both
`startAttempt()` and `startCombinedAttempt()` — confirmed (grep) these are the only 2 places in
the whole file that un-hide `attemptCard`, so this is a complete fix, not a partial one.
Deliberately NOT a `finally` block in `submitAttempt()` (considered, rejected) — entry-point
reset self-heals regardless of *why* the previous attempt didn't clean up (success without
reset, RPC error, or an unrelated crash like #45 below), where a `finally` only guards
`submitAttempt()`'s own execution and doesn't help once the user has already moved to
`resultCard` and clicks Retake.

**Verification caught a real process trap, logged in #46 so it doesn't repeat**: the first
verification pass tested stale cached JS — the local static server has no cache-busting
headers, so a normal reload didn't pick up the edited `index.html`, and the test would have
falsely reported PASS against the old, still-broken code. Caught by checking
`startAttempt.toString()` in the live tab before trusting any result. Fixed by forcing a
cache-busted URL (`?v=2`) and re-confirming the new source was actually loaded before
re-running verification. **Standing note for future sessions using this same local-server
pattern**: always confirm the served code is current before trusting a verification result,
same spirit as #38's "syntax check isn't verification" rule.

**Verified live**: 5 submissions in a row, one tab, zero reload (deliberately — this bug is
session-scoped, a reload would have hidden it): submit A → retake → submit → back to Mock List
→ different set B → submit → retake B → submit → switch to dark mode (no reload) → retake →
submit. `disabled` correctly `false` before every single submit, console clean throughout,
light and dark both checked.

## Logged, not fixed this session

- **#44**: `submit_attempt`'s error path (`errSubmitFailedNamed`/`.replace()`) was never
  exercised in production before this session's `is_published` fix made real errors possible —
  surfaced a likely frontend crash (`TypeError: Cannot read properties of undefined (reading
  'replace')`) on the combined-attempt error branch. Real scenario: admin unpublishes a set
  while a student already has it open. Out of scope (frontend error-handling, not Gap #2/RLS),
  needs its own diagnosis session.
- **#45**: `listeningAudioUrl()`/`listeningImageUrl()` crash unconditionally when a question's
  payload lacks `audio_url`/`image_url` — found live while investigating the ratchet bug.
  Root-caused precisely (queried the DB directly, not guessed): `image_tf` questions have two
  incompatible payload shapes in this data — the older `h1-listening-*`/`h2-listening-*` sets
  (150 rows, has `audio_url`/`image_url`, renders fine) vs. the newer `H1XING001`-`H1XING010`
  mock-exam sets (exactly 50 rows, ALL of them — uses `image_svg` inline instead, no audio at
  all). `renderImageTF()`/`buildReviewTF()` unconditionally assume the older shape. Verdict:
  **code issue** (renderer never updated for the newer payload shape), not missing data. Worse
  than "review breaks" — `renderImageTF()` also runs during the live timed attempt, so a student
  can crash mid-exam on any of these 10 sets. Flagged as blocking those 10 sets from demo use
  until fixed. Needs a design decision first (is `image_svg`-no-audio the intended new standard,
  or a content gap) before a fix shape can be chosen. Not started.

## Commits this session

- `1500c94` — `submit_attempt` is_published gate (`sql/05_submit_attempt_gap2_fixes.sql`,
  DECISIONS_NEEDED #42/#43 corrections).
- (this entry's commit) — submit-button ratchet fix (`index.html`), DECISIONS_NEEDED #44/#45/#46.

**Sengaja TIDAK di-commit** (sama seperti semua sesi sebelumnya): `supabase/functions/
grade-essay/index.ts` — perubahan uncommitted di file itu bukan dari sesi manapun di urutan
ini, dibiarkan apa adanya.

## Belum dikerjakan / kandidat follow-up

- **#44** — frontend crash on `submit_attempt` error path, needs its own session.
- **#45** — `image_tf` payload-shape crash on 10 `H1XING00N` sets, needs a design decision then
  a fix, blocks those sets from demo use meanwhile.
- **Gap #2 remainder** — RLS-by-package on `vocab`/`test_sets`/`question_bank`, blocked on
  `package_levels` source-of-truth decision (#41/#42).
- **Exam-integrity structural gap** (#43) — accepted debt, server-tracked attempt-session
  needed before any non-insider paying user.
- Carried over, unchanged: admin `service_role` GRANT gaps on 5/6 tables (#42 finding 10),
  `handle_new_user`'s `profiles.package` NULL-by-construction (#42 finding 9), `rls_auto_enable`
  implications for any future new table (#42 finding 8).

---

# Handoff — session 11 (1000-row PostgREST cap — dashboard/raport/Kamus/user_mastery, #41)

Scope: user reported "Progress by Level" denominators wrong (HSK4 `404` instead of `598`, HSK5
`1`, HSK6 `0`, total exactly `1000`) — audited first (report-only, no code) per standing rule,
confirmed hypothesis, then planned + implemented the fix across every call site sharing the same
root cause. Full writeup: DECISIONS_NEEDED #41.

## Root cause: unbounded `vocab`/`user_mastery` fetches hitting Supabase's default 1000-row cap

`loadBerandaExtras()` (dashboard) and `loadRaport()` both fetched the entire `vocab` table
(`select('hanzi,hsk_level')`, no `.limit()`/`.range()`) just to count rows per level in JS —
PostgREST's server-side max-rows (confirmed empirically: even an explicit `.range(0,2499)`
request gets truncated to 1000) silently cut the response to 1000 rows, skewed toward low HSK
levels. Reproduced the exact broken numbers (`150/147/298/404/1/0`) by replaying the identical
query directly against the DB. Real counts (verified via `count=exact` HEAD requests): HSK1=150,
HSK2=147, HSK3=298, **HSK4=598, HSK5=1298, HSK6=2500**.

**Wider disease, audited before fixing anything** (DECISIONS_NEEDED #41 has full detail): same
missing-bound pattern in 3 more shapes —
- `loadBrowseLevel()` (Kamus, per-level fetch) — safe for HSK1-4 (all under 1000) but **silently
  truncated HSK5 (1298→1000, missing 298 words) and HSK6 (2500→1000, missing 1500 words)** with
  zero error shown. Worse than the dashboard bug: a paying VIP/hsk_6-package user browsing the
  dictionary got 1000 of 2500 words with no indication anything was missing.
- `user_mastery` per-user unbounded fetches (`loadBerandaExtras`, `loadRaport`,
  `startSession`/flashcard) — dormant, not yet triggered by any real user's total review count,
  but same pattern, same eventual failure mode.

## Fix: DONE, VERIFIED, COMMITTED

Zero schema/RPC/view changes, per explicit constraint. New helpers (`index.html`, near the other
tuning constants):
- `VOCAB_BATCH_SIZE = 1000` — Supabase's own confirmed row cap, used as the page size for looped
  `.range()` fetches (`fetchAllRanged()`) wherever more than 1000 rows might exist.
- `MASTERY_IN_CHUNK = 200` — separate constant, separate concern: bounds `.in()` filter LIST
  length (URL query-string size), not response row count. Caught before coding: a power user's
  full `.in('hanzi', masteredKeys)` list could hit ~20k+ encoded characters, well past typical
  proxy/gateway URL limits. `fetchChunkedIn()` splits into 200-item chunks, runs in parallel,
  concatenates.
- `fetchVocabLevelCounts()` — 6 parallel `head:true` count requests (one per HSK level), zero
  rows in the response body. Replaces the "fetch 4991 rows just to count them" pattern in both
  dashboard and raport.

**Per call site**:
- `loadBerandaExtras()` / `loadRaport()` — `levelTotals` now from `fetchVocabLevelCounts()`.
  `levelOf` (hanzi→level lookup, previously built from the capped `vocabAll`) now built from
  `fetchChunkedIn(mastery.map(m=>m.item_key), ...)` — bounded by the user's own mastery size, not
  the vocab table size. This was also the fix for **Words Mastered silently under-reporting**:
  the stat was gated through `levelOf`, so any mastered word whose hanzi wasn't in the capped
  1000-row map got silently dropped from the count — explains why "Words Mastered" could show a
  wrong low/zero number in the same screen as a correct, ungated "Daily Goal reviewed today"
  count (that one never went through `levelOf`).
- `loadBrowseLevel()` (Kamus) — now `fetchAllRanged()` looped per level, reusing
  `loadWordOfDay()`'s existing count→range precedent rather than inventing a new pattern.
  `applyBrowseFilter()`/`renderBrowseChunk()`/`BROWSE_PAGE_SIZE` (client-side search + "Load
  More" chunking) untouched — they just now receive a complete `browseCache` instead of a
  truncated one.
- `startSession()` (flashcard `seenSet`) — same `fetchAllRanged()` loop, fixes the dormant
  same-shape risk before it could ever silently re-serve mastered words as "new" past 1000
  reviewed items.

**Explicitly not touched**, per constraint: `loadWordOfDay()`, `DUE_LIMIT`/`NEW_CANDIDATE_LIMIT`/
`WEAK_LIMIT`-bounded queries, schema, RPC/views.

## Verification — fresh login, console read at every step, per rule #38

Live site (`xingmandarin.com`) still ran the pre-fix code (fresh login there showed HSK4=`404`,
confirming the deployed version needed this fix) — switched to `python -m http.server` serving
the locally-edited `index.html` against the **real** Supabase backend (same technique as prior
sessions), fresh login each time, `claudecodelivetest@gmail.com` (VIP package, so HSK5/6 unlocked
for Kamus).

- **Dashboard Progress by Level**: HSK5 `1298`, HSK6 `2500` (0% since this account has zero
  mastery — expected). Light + dark, console clean.
- **Raport**: same denominators, HSK5 `1298`/HSK6 `2500`. Light + dark, console clean.
- **Kamus HSK6**: `50/2500` on open → drove "Load More" to exhaustion programmatically (49
  clicks) → `2500/2500`, button correctly hides. Confirmed `browseCache.length === 2500` directly
  (proves the data actually arrived, not just a correct-looking label).
- **Kamus HSK5**: same pattern, `1298/1298`, `browseCache.length === 1298`.
- **Network tab**: dashboard load fires exactly 6 `HEAD` requests
  (`vocab?...&hsk_level=eq.{1..6}`), zero bulk row fetch. One false alarm: the network panel
  showed `statusCode:503` on those HEAD requests — checked by calling `sb.from('vocab')...`
  directly from the console, got `status:206, count:2500, error:null` — confirmed a devtools
  logging quirk on HEAD responses, not a real failure (dashboard numbers were already correct,
  consistent with the requests actually succeeding).
- **Words Mastered silent-drop**: not testable with the disposable account (zero mastery data) —
  **verified separately by the user on their own HSK6-mastery account, confirmed fixed.**

Stopped before commit as instructed; this entry + DECISIONS_NEEDED #41 written up post-approval.

---

# Handoff — session 10 (Mock hub wiring VERIFIED + level-lock consistency, #37-followup/#38/#39/#40)

Scope: this session picked up mock-wiring work that had **already landed live via `8c1da2b`**
(hub Listening/Reading/Writing/Mock Paper cards, `mockOrigin`/`openMockList(section,origin)`,
`renderMockExitLabel`) without ever being verified — a second session appears to have committed
a working-tree snapshot that bundled this work in with an unrelated HSK6 renderer commit (see
#39). Nothing in this session's own diffs touches that renderer.

## Incident: `browseOrigin` ReferenceError, live down ~1h — RESOLVED, `57ca985`

Full writeup: DECISIONS_NEEDED #38. `let browseOrigin` was never declared anywhere (only ever
assigned inside `openBrowse()`) — reading it from `renderBrowseExitLabel()` on a fresh login
(before Kamus/hub had ever been opened that session) threw `ReferenceError`, killing
`doLogin -> loadProfile -> renderDash -> applyStaticI18n` and leaving the dashboard blank. Bug
predates this session (introduced in `15c245e`, confirmed via `git log -S`), surfaced now because
this was the first time a genuinely fresh-login path got exercised end-to-end. Fixed with one
added line, verified live (`xingmandarin.com`, console clean, dashboard populated), pushed.

**New standing rule, all future sessions** (DECISIONS_NEEDED #38): syntax check is not
verification; verification must start from a fresh login (incognito/hard refresh, not an
already-warm session); console must be read at every step, not just screenshotted.

## Mock hub wiring — VERIFIED (was live, unverified, since `8c1da2b`)

Full checklist + results: DECISIONS_NEEDED (conversation record, not a numbered entry — see
session transcript). Fresh-login verified, console clean at every step, light+dark, ID+EN:
hub Listening card no longer coming-soon (styling byte-identical to the other 5 cards, confirmed
via `getComputedStyle`, not just eyeballing a screenshot), hub→Reading/Listening/Writing/Mock
Paper each filter to the right section, exit label follows origin (`backToMateri` vs
`backToDashboard`), the hub→section→exit→sidebar-nav cross-navigation leak (`mockSection`
module-level state) does NOT reproduce, Writing+HSK1 empty state renders plain (not locked).

**Real gap found, fixed this session**: mock level picker only rendered `userPackageLevels`
(HSK5/6 simply absent for an `hsk_1_4` account) instead of the locked-visible pattern Kamus uses
(#22). Fixed — see below.

## Mock level picker → locked-visible, matching Kamus (#22) — DONE, VERIFIED

`renderMockLevelPicker()` rewritten to render all 6 HSK levels always (previously
`userPackageLevels.forEach`, silently omitting out-of-package levels). Out-of-package levels:
dim + 🔒, click → inline note (`#mockLevelLockedMsg`, reuses `.msg.lock` + `errLevelLocked` key
verbatim, zero new CSS/copy). `loadMockList()`/`test_sets` fetch only ever wired to the unlocked
branch — confirmed zero network request fires for a locked level (`read_network_requests`, not
assumed).

**CSS scoping bug caught before commit, self-corrected**: first pass added a bare
`.levelBtn.locked` rule. That collides with the pre-existing `button.levelBtn.locked` (Kamus's
pill, deliberately scoped to the `button` tag only since the #22 session, per its own comment) —
both would apply to Kamus's locked pill, two sources of truth for one appearance (values happened
to match today, but that's coincidence, not by design). Caught by the user before commit. Fixed
by scoping the new rule to `div.levelBtn.locked` — mirrors the existing `.levelBtn.active` split
(div and button variants already deliberately look different: rectangular chip vs. gold pill),
and removes the overlap entirely rather than relying on CSS specificity to resolve it.
**Re-verified after the scope fix**: Kamus's locked pill re-checked via `getComputedStyle`
(`opacity:0.5, cursor:not-allowed, boxShadow:none`, byte-identical to before this session touched
anything), mock's locked div separately confirmed (`opacity:0.5, cursor:not-allowed`) — zero
cross-contamination, light+dark, console clean throughout.

**Orthogonality confirmed, explicitly re-tested after the lock feature landed**: Writing+HSK1 for
an `hsk_1_4` account (unlocked level, zero matching `test_sets` rows) still renders the plain
`emptyNoMockForLevel` empty state, not the lock message — the two code paths (level-gate vs.
query-result-empty) never share a branch.

## Logged, not fixed this session

- **DECISIONS_NEEDED #40**: `renderLevelPicker()` (flashcard start screen, `index.html:2573`) has
  the same `userPackageLevels.forEach`-hides-locked-levels gap Mock had. Kamus and Mock are now
  both locked-visible; flashcard is the one picker still behind. Candidate follow-up, explicitly
  out of scope this session.
- **DECISIONS_NEEDED #39**: two Claude Code sessions apparently edited `index.html` concurrently
  at some point, one of which committed a snapshot mixing unrelated work. No damage this time,
  but flagged as a standing rule: don't run two CC sessions against the same file concurrently.
- Gap #2 (#22) — RLS-by-package server-side enforcement — still debt, still not started, severity
  unchanged (confirmed extending to `test_sets`+`question_bank` too, per the live `hsk_1_4`→HSK6
  probe noted in DECISIONS_NEEDED).

## Commits this session

- `57ca985` — `browseOrigin` missing-declaration fix (emergency, pushed immediately).
- Locked-visible mock level picker + `div.levelBtn.locked` scoping — see git log for hash (pushed
  same session as this handoff entry).

---

# Handoff — session 9 (Kamus → Vocab Deck hub + gating, #22/#37)

Scope: **Kamus pindah ke Materials hub sebagai Vocab Deck + level gating** (Gap #1 dari #22).
Report-first (git pull → baca #21/#22/#23 + HANDOFF sesi 8 → lapor rencana + 4 opsi terbuka →
tunggu approve) sebelum implementasi, sama pola kayak sesi-sesi sebelumnya.

## Kamus → Vocab Deck + gating: DONE, APPROVED, COMMITTED — `15c245e`

Full decision writeup: DECISIONS_NEEDED #22 (hub keputusan lama) → #36 (`.msg.lock` rgba debt) →
#37 (IA resolved: Materials = hub, Kamus jadi anak).

**Yang jadi**:
- Kamus (`browseCard`) bukan tujuan nav sendiri lagi — dibuka lewat kartu Vocab Deck di dalam
  `materialsHubCard`. `navMateri` (sidebar) dan `browseBtn` (dashboard quick action) dua-duanya
  sekarang → `openMaterialsHub()`, byte-identical.
- `renderBrowseLevelPicker()` render semua 6 level HSK selalu — level di luar
  `userPackageLevels` tampil locked-visible (dim + 🔒), bukan disembunyiin. **Gap #1 (#22) LUNAS**:
  nol fetch `vocab` buat level locked, diverifikasi langsung lewat network tab, bukan cuma
  keliatan gembok doang.
- Klik level locked → inline note (`.msg.lock`, modifier baru turunan `--navy`/`--gold` existing,
  zero hex baru, override dark mode sendiri) — bukan `alert()` (ditolak: blocking, gak bisa
  distyle, munculin nama domain di mobile), bukan `.msg.err` (ditolak: merah = "kamu salah",
  padahal ini pesan dagang bukan error).
- Semua teks hub (judul, subtitle, chip, judul+meta kartu, coming-soon pill) masuk sistem `t()`
  ID/EN/ZH — debt i18n dari sesi shell dibayar penuh.
- Tombol exit Kamus ngikut `browseOrigin` (`backToMateri` vs `backToDashboard`) — sebelumnya
  hardcode satu string yang boong pas masuk lewat hub.

**Diverifikasi live** (akun disposable `claudecodelivetest@gmail.com`, paket `hsk_1_4`), light +
dark, ID + EN, per checklist: hub buka dari kedua entry point, Vocab Deck → Kamus IA utuh, level
5/6 locked + toast/inline-note + zero network fetch, exit balik ke asal (hub vs dashboard) benar,
bahasa switch ikut ganti semua teks.

**Belum dibayar, dicatat eksplisit — Gap #2 (#22), SECURITY DEBT**: enforcement paket 100%
client-side. `vocab` RLS masih terbuka buat semua `authenticated` user tanpa filter package;
`startAttempt()`/`startCombinedAttempt()` juga belum re-check paket di server. Acceptable
**hanya** selama user cuma masuk lewat admin (bukan self-serve publik) — **WAJIB dibayar (RLS
by package) SEBELUM paket dijual komersial.** Belum disentuh sesi ini (di luar scope, butuh
sesi/keputusan sendiri).

**Debt kecil tercatat, bukan diutangin secara diam-diam**: #36 (`.msg.lock` hardcode 3 nilai
`rgba(242,176,30,X)` — kalau `--gold` di-tuning ntar, drift senyap; bayar kalau/pas bikin
`--gold-rgb` companion var, sama pola `--text-rgb`/`--muted-rgb` yang udah ada).

## Commit sesi ini

- **`15c245e`** — `index.html` (fitur) + `DECISIONS_NEEDED.md` (#36, #37).

**Sengaja TIDAK di-commit** (sama seperti sesi-sesi sebelumnya): `supabase/functions/grade-essay/
index.ts` — perubahan uncommitted di file itu bukan dari sesi ini, dibiarkan apa adanya.

## Belum dikerjakan / kandidat follow-up

- **Gap #2 (#22) — RLS by package** — prioritas tinggi, wajib sebelum jual paket komersial.
- 5 kartu hub lain (Grammar/Listening/Reading/Writing/Mock Paper) belum di-wire — sesi terpisah.
- `.msg.lock` rgba hardcode (#36) — bayar kalau `--gold-rgb` companion var dibikin.
- Balik `admin-users` Edge Function ke `SUPABASE_SECRET_KEYS` sekarang grant DB udah benar (#34).
- Must-change-password flag / invite-email buat admin v1.5's create-user (#31).

---

# Handoff — session 8 (session guard bug, #33)

Scope: **cuma §33** — bug session guard yang ditemukan sampingan pas verifikasi admin v1.5
(session 7). Report-first + diagnosis-before-fix, sama pola kayak sesi-sesi sebelumnya.

## Session guard fix: DONE, APPROVED, COMMITTED — `e274984`

Full writeup: DECISIONS_NEEDED #33 (RESOLVED).

**Bug asli**: `forceLogout()` manggil `sb.auth.signOut()` tanpa `scope` arg — default supabase-js
`'global'`, mencabut **semua sesi user itu di semua device**. Single-device enforcement maunya
device baru (B) nendang device lama (A); yang beneran kejadian: device A yang kalah klaim, dalam
proses nge-logout dirinya sendiri, ikut nyabut sesi device B yang justru baru menang. Ketemu pas
2 tab (live + localhost) login bareng buat testing admin panel — `createUser` gagal "Invalid
session" padahal baru login.

**Temuan penting sebelum fix**: `SESSIONS_SINGLE_PER_USER` di Supabase Dashboard **OFF dan
nggak bisa dinyalain** (fitur Pro plan ke atas, project ini Free plan). Konsekuensi ganda:
1. Mekanisme custom `active_session_id`/`claim_session` **satu-satunya** cara enforce
   single-device di sini — bukan lapisan redundan di atas fitur native GoTrue.
2. Kondisi itu **persis** precondition bug upstream `supabase/auth#2036` ("local logout
   invalidates all sessions") — jadi opsi fix yang dipertimbangkan (`{scope:'local'}` vs
   `{scope:'others'}`) punya risiko nyata, bukan teoretis, kena bug itu juga.

**Arsitektur baru — enforcement pindah arah, bukan cuma ganti scope**:
- **Sebelum**: device yang KALAH klaim (A) bunuh diri sendiri (`signOut()` global) pas ketauan
  ketendang lewat realtime. Enforcement-nya reaktif, bergantung tab A nyala + connect realtime.
- **Sekarang**: device yang MENANG klaim (B) yang aktif nendang — `doLogin()` manggil
  `signOut({scope:'others'})` **persis setelah** `claim_session` sukses. Device A ke-revoke di
  server **nggak peduli A online/offline** — nutup bug §33 (B nggak lagi ikut mati) **dan** gap
  lama yang baru ketauan (A offline pas ditendang = sesinya idup selamanya sebelum fix ini) dalam
  satu perubahan.
- `watchSession()`'s realtime handler + `boot()`'s stale-session check **nggak manggil
  `signOut()` lagi sama sekali** — diganti `localLogout()` (fungsi baru): bersih state lokal +
  tampilin pesan "logged in elsewhere" doang, karena sesinya udah dicabut di server oleh device
  pemenang. Ini murni cleanup/UX sekarang, bukan sumber enforcement.
- 3 titik `gateReason` (subscription expired/lewat tanggal — `loadProfile`, `doLogin`, `boot`)
  **tetap `global` scope, sengaja** (langganan abis = wajar ke-logout di semua device) — cuma
  sekarang eksplisit (`forceLogout(reason, 'global')`), bukan kebetulan dari argumen kosong.
- Titik lain (`logoutBtn` manual, profil gagal fetch, `claim_session` RPC gagal) — **nol
  perubahan**, `forceLogout()` tanpa argumen kedua = byte-identical ke perilaku lama.
- **Error handling**: kalau `signOut({scope:'others'})` gagal setelah `claim_session` sukses
  (network hiccup dsb.) — best-effort, `console.error` eksplisit + login tetap lanjut (nggak ada
  rollback bersih buat `claim_session` yang udah commit). Risiko sisa cuma di skenario ganda
  (kick gagal + device lama kebetulan offline bebarengan) — diterima, bukan dikerjain retry.

**Verifikasi — 2 ronde, sesuai standing rule "tes empiris, jangan tebak"**:
1. **Sebelum implementasi**: 2 browser context terpisah, `sb.auth.signInWithPassword()` dipanggil
   langsung dari console (skip `claim_session`, isolasi murni perilaku Supabase Auth) — B
   `signOut({scope:'others'})`, verifikasi B selamat (`getUser()` sukses) DAN A mati (403 dari
   server, `AuthSessionMissingError`, dites tanpa reload halaman A supaya kebukti pencabutan
   beneran server-side bukan cuma state lokal). `#2036` **tidak terpicu** meskipun kondisinya
   match.
2. **Setelah implementasi, di kode fix (`localhost:8796`, bukan live)**: login 2 device beda —
   device A dapet pesan "logged in elsewhere" ✅, device B **selamat total** (masuk dashboard,
   buka mock test H5XING002 100 soal, timer+audio jalan normal) ✅, dikonfirmasi query nyata
   (`profiles.select`) dari console B sukses = sesi B valid di server, bukan cuma UI ✅.

## Commit sesi ini

- **`e274984`** — `index.html` (fix) + `DECISIONS_NEEDED.md` (§33 RESOLVED).

**Sengaja TIDAK di-commit** (sama seperti sesi 7): `supabase/functions/grade-essay/index.ts` —
perubahan uncommitted di file itu bukan dari sesi ini, dibiarkan apa adanya.

## Belum dikerjakan / kandidat follow-up (nggak berubah dari sesi 7)

- Balik `admin-users` Edge Function ke `SUPABASE_SECRET_KEYS` sekarang grant DB udah benar (#34).
- Must-change-password flag / invite-email buat admin v1.5's create-user (#31).
- RLS-by-package sebelum paket dijual komersial (#22).

---

# Handoff — session 7 (admin panel v1.5, create user + email)

Scope: **Edge Function untuk create user + email column**, gated behind admin v1 (session 6,
`b7739f0`) being done and approved. Report-first (`git pull` → baca #30/#31 → lapor rencana,
nol kode) sebelum implementasi, sama pola kayak session 6.

## Admin panel v1.5: DONE, APPROVED, COMMITTED — `e3cb10d`

Full decision writeup: DECISIONS_NEEDED #31 (email/password/modal-shell/partial-failure
decisions, ditulis sebelum coding) → #32 (secret key choice + implementation) → #33 (bug session
guard, ditemukan sampingan, belum di-fix) → #34 (root cause investigation, lihat di bawah).

**Yang jadi**:
- Edge Function baru `admin-users` — gerbang `is_admin()` (forward caller JWT + anon key,
  sebelum client privileged dibuat sama sekali) → 2 action: `createUser` (bikin auth user +
  isi `profiles` dari form) dan `listEmails` (isi kolom Email di list, kosong sejak v1 karena
  `auth.users` nggak reachable dari anon key).
- Partial-failure (`createUser` sukses, UPDATE `profiles` gagal) dilaporkan eksplisit ke admin
  (`207` + alert jelas), nggak pernah disamarkan jadi sukses. Nggak ada rollback/delete-on-failure
  (nggak ada RLS DELETE, delete auth user CASCADE ke riwayat belajar — sama alasan #30).
- Frontend: tombol "+ Add User" + Create modal (reuse modal shell dari v1), kolom Email balik ke
  list (fetch async, soft-fail ke "—" kalau function gagal, nggak pernah fabricate).
- Password: admin set langsung di Create modal (opsi a) — **DEBT tercatat** (#31), wajib
  direvisi sebelum ada admin kedua atau paket dijual komersial.

**Root cause hunt "permission denied for table profiles" — 4 ronde, akhirnya GRANT-level**
(full detail #34, ringkasan di sini biar nggak perlu buka dua file buat ngerti urutannya):
1. **Ronde 1** — `SUPABASE_SECRET_KEYS['default']` (key format baru, direkomendasikan Supabase,
   diverifikasi dulu ke project ini sebelum dipakai — lihat #32). `listEmails` (GoTrue) sukses
   live. `createUser`'s UPDATE ke `profiles` (PostgREST) gagal `"permission denied for table
   profiles"`.
2. **Ronde 2** — hipotesis: raw secret key kesisip ke header `Authorization` sebagai session
   fallback, gateway salah konversi ke JWT `service_role` buat PostgREST. Dicoba
   `{ auth: { persistSession:false, autoRefreshToken:false } }` — **gagal identik**. Teori
   terbantahkan.
3. **Ronde 3** — fallback ke `SUPABASE_SERVICE_ROLE_KEY` (legacy JWT), dicatat sebagai DEBT
   (legacy ditarget deprecated akhir 2026). Kode ini yang dipakai buat verifikasi berikutnya.
4. **Ronde 4 — akar masalah sebenarnya**: Kyaru cek grant langsung ke DB — `service_role` cuma
   punya `REFERENCES, TRIGGER, TRUNCATE` di `public.profiles`, **NOL SELECT/INSERT/UPDATE/
   DELETE**. `vocab` sama persis (project-wide, kemungkinan sisa security hardening lama).
   `anon` juga ke-revoke. Nggak pernah kedeteksi sebelumnya karena app selalu jalan sebagai
   `authenticated` (grant lengkap) — Edit modal (client-side, sesi admin) selalu sehat,
   `admin-users` (server-side, `service_role`/`anon`) selalu kena, **apapun format key-nya**.
   Fix: `grant select, insert, update on public.profiles to service_role;` (sengaja tanpa
   DELETE, sama alasan #30). **Diverifikasi empiris**: test5 (sebelum grant) = semua field
   default/NULL; test6 (sesudah grant, kode identik nol redeploy) = semua field kepasang benar,
   200, nol partial. Ronde 1-2 (soal `sb_secret_`) **salah didiagnosis** — bukan soal key sama
   sekali. Kode tetap di `SUPABASE_SERVICE_ROLE_KEY` untuk sekarang; balik ke
   `SUPABASE_SECRET_KEYS` dicatat sebagai kandidat follow-up terpisah, sengaja nggak digabung
   sama perubahan grant supaya tiap perubahan diverifikasi sendiri-sendiri.

**Anomali "Mimilll" (create pertama, sempat kelihatan partial-success yang aneh) — CLOSED.**
`target_level`-nya ternyata kesentuh lewat Edit modal (sesi `authenticated`, grant lengkap,
nggak pernah kena masalah ini) di sesi diagnosis terpisah, bukan dari `createUser`'s UPDATE
sendiri. `createUser` Mimilll sebenarnya gagal total sama kayak test2/test3 — dua aksi manusia
(create yang gagal + edit manual belakangan) kelihatan kayak satu peristiwa. Bukan flakiness,
bukan jalur kode kedua.

**Verifikasi**: `listEmails` dan `createUser` dua-duanya sudah diverifikasi live oleh Kyaru
sendiri (login admin asli, browser asli) — Claude nggak pernah nyoba `createUser` sendiri
(kebijakan: nggak bikin auth user beneran tanpa Kyaru yang eksekusi/approve langsung).

**Bug sampingan ditemukan, sengaja belum di-fix** (#33): `forceLogout()` manggil `signOut()`
tanpa `scope` arg = default `'global'` = login di satu device nendang device lama **dan** ikut
matiin device baru yang justru menang klaim sesi. Ditemukan pas dua tab (live + localhost) login
bareng buat testing. Fix kandidat sudah ada (`signOut({scope:'local'})`), sengaja nggak dikerjain
bareng sesi ini biar nggak nyampur scope perubahan.

## Commit sesi ini

- **`e3cb10d`** — `index.html` + `supabase/functions/admin-users/index.ts` (baru) +
  `DECISIONS_NEEDED.md` (#31-34).

**Sengaja TIDAK di-commit**: `supabase/functions/grade-essay/index.ts` — ada perubahan
uncommitted di file itu yang bukan dari sesi ini (kerjaan Kyaru sendiri, paralel), dibiarkan
apa adanya sesuai instruksi eksplisit.

## Belum dikerjakan / kandidat follow-up

- Balik `admin-users` ke `SUPABASE_SECRET_KEYS` sekarang grant DB sudah benar (bukan blocker,
  cuma belum diverifikasi ulang — lihat #34).
- `signOut({scope:'local'})` fix di `forceLogout()` (#33) — bug nyata, dampak ke semua user,
  bukan cuma admin panel, tapi di luar scope sesi ini.
- v2/v1.5-adjacent yang masih kandidat: must-change-password flag atau invite-email (upgrade dari
  password-langsung-oleh-admin, #31), dan RLS-by-package sebelum paket dijual komersial (#22).

---

# Handoff — session 6 (admin panel v1, user management)

Scope: **Admin Panel v1 — user management**, client-side only (anon key, zero Edge Functions).
Comp: Admin_Panel PNG (6 screens, light+dark) + schema facts verified directly against Supabase
by the user (not inferred). Pre-implementation audit already existed in DECISIONS_NEEDED #30
from a prior session; this session resolved the remaining open points (email handling,
`display_name` NULL rendering, modal component, package-dropdown completeness, self-demotion
guard) before writing any code, per explicit "lapor dulu, jangan ngoding" instruction.

## Admin panel v1: DONE, APPROVED, COMMITTED — `b7739f0`

Full decision writeup: DECISIONS_NEEDED #31 (6 entries — email, `display_name` NULL, modal
shell, package dropdown, self-demotion guard, `target_level` NULL).

**What shipped**:
- Sidebar nav — "ADMIN" group + "User Management" item, hidden unless `profile.role==='admin'`
  (toggled in `renderDash()`). Existing sidebar (`.sbThemeToggle`/`.sbLangBtn`) untouched, no
  new toggle added, per #30.
- User list (`adminCard`) — search by `display_name`, filter by package (options built off
  `Object.keys(PACKAGE_LEVELS)`, never a separate hardcoded list — see corruption-risk note
  below) and status. Row: name (or NULL placeholder, see below), package badge, target_level,
  status pill (reuses `.resultBadge` pass/fail pill recipe), subscription_end. Click row → Edit
  modal. **No email column** — `auth.users` isn't reachable from the anon key/PostgREST;
  getting it needs `service_role` + `supabase.auth.admin.*`, deferred to v1.5 alongside
  create-user (same Edge Function, one build).
- Edit modal — `display_name`, package, target_level, status, subscription_end, role. Save =
  direct `profiles` UPDATE under RLS `is_admin()`, no Edge Function needed for any of these.
- Deactivate — `status='expired'`, confirm dialog via the new modal shell. The only destructive
  action in v1 (no RLS DELETE policy exists + FK CASCADE to `user_mastery`/`test_attempts`/etc.
  would permanently wipe a user's learning history — "Delete permanently" was cut in #30).
- **New modal shell** (`#modalOverlay`/`#modalPanel`) — codebase previously only had native
  `confirm()`. Overlay + panel + close (X/backdrop/Esc) + basic Tab-cycle focus trap, light+dark.
  Reused verbatim by Edit User and Deactivate confirm; intended for Create user in v1.5 too — no
  second modal component, no animation, no stacking, no generic design system.

**2 corruption-class bugs caught and fixed before commit** (both same shape: a `<select>` with
no explicit option for a real/possible DB value silently shows the first option as
browser-default-selected, so an admin who saves without touching that field silently overwrites
real data):
1. **Package dropdown** — `PACKAGE_LEVELS` has 6 keys (`hsk_1_4`/`hsk_5`/`hsk_6`/`vip` +
   `business`/`convo`, the last two content-empty "coming soon" tiers). A dropdown built off
   only 4 known-content keys would silently corrupt any `business`/`convo` user's package on
   Save. Fixed: dropdown options generated from `Object.keys(PACKAGE_LEVELS)` directly (single
   source of truth, can't drift), `business`/`convo` labeled honestly ("... (belum ada
   konten)"), and any DB value that still doesn't match any key is shown literally with a ⚠
   warning instead of falling back silently — caught by the user's own review before any code
   was written (see DECISIONS_NEEDED #31).
2. **`target_level` NULL** — same shape, caught by Claude during self-verification (screenshot
   testing against a synthetic NULL-`target_level` fixture), not by user report. Fixed with an
   explicit `"— Not set —"` option + save handler sending `target_level: null` instead of
   `Number('')`. Logged as a general pattern in DECISIONS_NEEDED #31: any dropdown representing
   a nullable/open-ended DB column needs an explicit "empty/unknown" option, never rely on
   browser default-select.

**Verification — 2 rounds, both required before commit** (per this project's standing
verify-before-commit rule):
1. **Claude, local static server + synthetic fixture** (same technique as every prior session —
   `currentUser`/`currentProfile`/`adminCache` pushed via console, bypassing Supabase auth
   entirely): confirmed nav visibility gating, NULL-name placeholder + UUID sub-id, unknown
   package literal-value warning, self-demotion guard (role `<select>` disabled + hint on own
   row), Deactivate confirm → Cancel returns to Edit modal, modal close via X/backdrop/Esc, both
   themes. This is where the `target_level` NULL bug above was caught and fixed.
2. **User, real Supabase login in their own browser** (fixture data was never proof RLS or the
   write path actually worked): nav ADMIN visible for `role='admin'` ✅, list of real users
   loads (RLS `is_admin()` SELECT confirmed live) ✅, Edit + Save writes to `profiles`
   (`display_name` NULL → "Wilbert", confirmed in Table Editor) ✅, self-demotion guard ✅,
   Deactivate ✅ **plus the full loop**: deactivated account's next login attempt correctly
   blocked by the existing `gateReason()` "subscription has ended" gate, then reactivating
   (`expired`→`active`) let that account log in again ✅. Modal Esc/X/backdrop ✅.

**Post-push production check** (`https://xingmandarin.com`, no login — Claude has no admin
credentials and does not enter passwords regardless, per standing policy): page loads clean, 0
console errors on load, login screen renders correctly in both themes. This confirms the deploy
itself is healthy; it is **not** a substitute for the logged-in verification above, which the
user already completed in their own browser before this commit landed.

## Not built this session (v1.5, explicit scope cut per #30)

- **Create user** — needs a `service_role` Edge Function (`supabase.auth.admin.createUser` or
  equivalent), gated by `is_admin()`.
- **Email column** — same Edge Function as create-user (`auth.admin.listUsers`/`getUserById`),
  nebeng di function yang sama, satu pekerjaan sekali jalan (per #31's reasoning: building a
  throwaway Edge Function just for email now would pay the full infra cost — service_role
  secret, `is_admin()` gate, CORS, deploy — for a feature that's getting rebuilt with
  create-user anyway).
- **Delete permanent** — cut permanently, not deferred (no RLS DELETE policy, FK CASCADE would
  wipe learning history — see #30).
- Analytics/billing/content management — untouched, out of scope.

## Commit this session

- **`b7739f0`** — Add admin panel v1 (user management): `index.html` (admin nav, list, modal
  shell, Edit modal, Deactivate) + `DECISIONS_NEEDED.md` (#31, 6 entries).

---

# Handoff — session 5 (dark mode sweep, continuation after /clear)

Scope this session: **dark mode**, the last item in the fixed restyle sequence. Mid-session,
user supplied 6 dark-mode design PNGs (`screens/08-13-*-dark.png` + `README-DARK.md`) that
weren't available before — this turned the session from a contrast-judgment sweep into a
**port** (same rule as every light-mode session: `.dc.html` wins, PNG is cross-check only).
`.dc.html` already had a `[data-theme="dark"]` token block (baris 17) nobody had diffed against
before.

## Dark mode port: DONE, APPROVED, COMMITTED — `f29a55c` + `32fb4dd` (2 rounds, same fix)

**Method**: grepped the whole file for `var(--text)`/`var(--muted)` used as `background` (not
`color`) before touching anything, per explicit instruction — found exactly 2 instances
(`.gridBtn.answered`, `.legendSwatch.answered`, both index.html:714/722), nothing else. 4 other
places use low-alpha `rgba(var(--text-rgb),X)` as background — confirmed correct token behavior
(translucent tint, not an opaque swap), left alone.

**The bug and why it survived 6 sessions**: `.dc.html`'s "Answered" navigator swatch (baris 348)
is a literal, unconditional `#1C2A5E` — same in both themes, same pattern as `.navBtn.navNext`
(which the app already matched correctly). App had `background:var(--text)` instead, which
happens to equal `#1C2A5E` in light mode (pure coincidence — the token and the literal value
compute to the same hex there) but flips to near-white in dark, since `--text` is theme-adaptive
and the source's literal isn't. Every prior light-mode screenshot review looked correct because
of that coincidence; only the dark comp gave a second data point to expose it.

**Round 1** ported the literal `#1C2A5E` verbatim (`f29a55c`), `[data-theme="dark"]`-scoped only.
Verified live via a synthetic attempt fixture pushed through the console (bypassing Supabase
auth entirely, same test-fixture precedent as prior sessions' flashcard/dashboard checks) and
`getComputedStyle` — **confirmed broken**: `#1C2A5E` (28,42,94) vs dark `--panel` (28,43,88), a
6-point RGB delta, cell functionally invisible against the card. The base rule's
`color:var(--panel)` compounded it (same coincidental-match bug, mirrored: correct in light
since `--panel` is white there, but `--panel` is dark in dark mode too, so the answered-cell
number collapsed to the exact same color as the card background). Cross-checked
`11-mocktest-attempt-dark.png` itself at this point — **the design comp has the same flaw**,
its own "answered" cells read as indistinguishable from "empty" ones in that screenshot.

**Round 2 — deliberate deviation from comp, decided by user** (`32fb4dd`): replaced the literal
`#1C2A5E` with `#2b3c78` (the login/dashboard brand-panel navy — an already-approved palette
color from the comp, not invented) + explicit `color:#fff`. Re-verified via `getComputedStyle`
(cell background `rgb(43,60,120)`, text `rgb(255,255,255)`, distinct from card `rgb(28,43,88)`)
and a screenshot showing all 4 navigator states (answered/current/flagged/empty) simultaneously
legible. **Light mode untouched in both rounds.** Full writeup: DECISIONS_NEEDED #29.

**Everything else checked against the comp came back already correct** (no code changes needed):
- `.navBtn.navNext` (`#1C2A5E`, navy-on-near-navy in dark) — confirmed matches `.dc.html` baris
  340 literally, deliberate design, not a bug (was flagged as a risk before the dark comp
  existed; comp settled it).
- `.qListeningBadge`, `.sectionBreak` colors, dashboard stat cards/quick actions/history cards,
  flashcard card shell/deckChip/gradeBtn/pinyin, result hero ring/badge/section-breakdown colors
  — all literal hex or token-based, all matched `.dc.html` exactly already.
- `.practiceExit` (Retake/Back to home, DECISIONS_NEEDED #24) — comp's own dark treatment is
  100% `var(--surface)`/`var(--ink)`/`rgba(ink-rgb,X)`, no separate dark override in source. No
  new information from the dark comp — **#24 is not reopened**, stays exactly as it was.
- Photo/image box (`.listeningImageWrap`/`.imageChoiceImg`, hardcoded white) — confirmed
  `.dc.html`'s `isTest` block has zero image element in either theme (source only ever
  demonstrates `listening_tf`). Stays deferred, not guessed at.
- `13-materials-dark.png` — confirmed **not used** for Kamus's dark pass (that PNG is the unbuilt
  hub product, #21/#22, a different IA). Kamus dark has no comp of its own.

**Logged, not fixed, out of scope** (DECISIONS_NEEDED #29 has full detail on both):
- `.resultBadge.pending`/`.sectionCard.pending .sectionCardBar` (the essay-pending state from
  #17) — unverified visually this session, no live essay-graded combined attempt to screenshot
  against, not faked with dummy data. Expected fine on the token math (low-alpha rgba over dark
  panel) but nobody has actually looked at it lit up.
- `.gridBtn.flagged`/`.legendSwatch.flagged` alpha values (`rgba(...,.18/.55)` app vs
  `.dc.html`'s `rgba(...,.3/.6)`) — pre-existing drift from the light-mode port (`8ec14ae`), same
  in both themes, not a dark-specific bug, not touched this round.

## Screenshot verification — 5 restyled screens + Kamus manual sweep

All 6 checked live via a local static server (`python -m http.server`, serving `index.html`
directly — Supabase auth isn't reachable in this environment) + synthetic fixtures pushed
through the console to bypass auth entirely (`sessionQueue`, `attemptQuestions`/`attemptAnswers`,
a fixture `result` object for `showResult()`), same technique as prior sessions' flashcard/
dashboard checks — not fabricated product data, test fixtures to exercise the real render
functions. All matched their respective dark PNGs / token expectations:

- **Login**: brand panel, moon/stars, word-of-day chip, form inputs, theme toggle — matches
  `08-login-dark.png`. Streak-waiting promo chip correctly absent (already-dropped decision).
- **Dashboard**: stat cards, continue-practice hero, daily goal, quick actions, sidebar — matches
  `09-dashboard-dark.png`. Empty-state dashes are correct (no session data in this fixture),
  same as the already-established light-mode empty-state precedent.
- **Flashcard**: card shell (navy in dark, confirmed via `var(--panel)`), badge, deckChips,
  Show answer / Done-Back buttons — matches `10-flashcard-dark.png`.
- **Mock attempt**: chrome + listening_tf question, navigator (post-fix, all 4 states legible) —
  matches `11-mocktest-attempt-dark.png` modulo the deliberate Answered-cell deviation above.
- **Mock result**: ring/badge/section-breakdown/exit buttons — matches
  `12-mocktest-result-dark.png`.
- **Kamus**: no comp (per #21/#22, this is the dictionary not the hub) — manual contrast check
  only. Wrapper/list/level-picker/search bar all legible against the dark panel via the existing
  `var(--panel)`/`var(--panel-2)` pairing. No issues found.

## Restyle sequence: COMPLETE

Login → Dashboard → Flashcard → Mock attempt chrome+listening_tf → Mock result → Materials/Kamus
chrome → #12 (answer-choice buttons) → dark mode. All 8 stages done, approved, committed.
**Materials hub build is next**, gated on the 3 prerequisites in DECISIONS_NEEDED #22 (still
unanswered) — do not start it without the user answering those first.

---



Scope this session: **#12 only** (`.choiceItem`/`.segmentItem` div→button, 4 call sites).
Plan was pre-approved from last session's writeup (see DECISIONS_NEEDED #12). Executed, verified
in-browser by user, committed. Stopping here as instructed.

## Answer-choice `<div>`s → real `<button>`s (#12): DONE, APPROVED, COMMITTED — `cd8d8ca`

Converted the 4 template-string call sites (`renderChoiceList`, `renderListeningOptions`,
`renderImageOptions`, `renderSegmentList`) from `<div class="choiceItem/segmentItem">` to
`<button type="button" class="...">`, same recipe as every prior div-to-button conversion in
this sequence (`8ec14ae`): delegated click handler (`index.html:4002-4029`) already used
`closest()`/`dataset`, tag-agnostic, zero logic changes needed.

**`button{}` leak (index.html:67-72) blocked explicitly** on `.choiceItem`/`.segmentItem`:
`width:auto`, `margin-top:0`, `color:var(--text)`, `font-weight:400`, `text-align:left`,
`line-height:normal` (restated, not a new value — nothing set it before). `background` was
already explicitly `var(--panel)` on both classes pre-conversion, so that part of the leak
(gold gradient) was already blocked without needing a new rule — confirmed, not assumed, by
reading the existing CSS before touching it. **Padding was deliberately left untouched** on
both classes — both already had identical pre-existing `padding:12px 14px`, restated as-is,
not unified or invented.

**`.imageChoiceItem` checked for conflict before touching `.choiceItem`**: it only sets
`flex-direction`/`align-items`/`gap`/`flex`/`min-width`, no `width` of its own — sizing is
governed by `flex-basis` (via the `flex` shorthand), which wins over `.choiceItem`'s new
`width:auto` for a flex item. No conflict, no extra CSS needed there.

**Verified in-browser by user** against `H4XING001` (combined "Semua" attempt): soal #1
(`listening_tf`) and soal #11 (`listening_mc`, via `renderListeningOptions` — turned out to
have real local-equivalent data after all, correcting last session's "no local data" note for
that renderer). Options render white background, navy text, left-aligned, zero regression.
`renderImageOptions`/`renderSegmentList` weren't separately re-verified this exact session
(no image_mc question surfaced in the tested attempt) but share the identical reset recipe.

**Correction**: `H4XING001` is confirmed **95 questions**, not 90 — the `7/45=16, 0/40=0,
0/5=0 → 16/300` verification numbers from #9 (recorded in the previous session's writeup below)
came from a **different** set, not this one. See DECISIONS_NEEDED's new correction note.

**2 pre-existing findings surfaced during verification, logged not fixed** (DECISIONS_NEEDED
#27/#28, full detail there):
- **#27**: `H4XING001` soal #1 shows two stacked "Listening" badges — traced via `git log -S`
  to two unrelated components (`.sectionBreak`, older, from `ec87492`'s combined-exam grouping
  work; `.qListeningBadge`, newer, from `37952ef`'s design-comp port) that only visually
  collide on a combined attempt's very first question. Not a regression, not fixed.
- **#28**: `.qListeningBadge` only renders on `listening_tf` (source's only comp'd type),
  not on `listening_mc`/`image_mc`/`image_tf` — was always this narrow by design-comp scope,
  now visibly inconsistent since #12 made those other types easier to actually reach/compare
  side-by-side. Not fixed, user to decide per-type vs per-section scope.

## Remaining session order: ~~result~~ → ~~materials~~ → ~~#12~~ → **dark mode** → materials hub

**Only dark mode left in the restyle sequence.** Materials hub build (new screen, comp's
6-card hub) stays gated behind dark mode + the 3 unanswered prerequisites (see previous
session's Materials section below) — do not start it next.

---

# Handoff — session 3 (continuation after /clear)

Scope is capped and paced explicitly (~1-2 screens per session, then `/clear`, verify-before-commit every time). This session's mandate was the mock test RESULT screen ONLY, not paired with #12 or dark mode. Landed, verified against real submitted attempts, approved before commit. Stopping here as instructed.

## Mock test RESULT screen: DONE (single-section + combined-HSK1-4-objective paths), CODE COMPLETE/UNVERIFIED on 2 branches (see below)

Source: `05-mocktest-result.png`, `.dc.html`'s `isMock` block (lines 232-262). Full drift table
and DECISIONS_NEEDED entries (#14-#21) are in that file — summary here.

**What got verified against a real submitted attempt** (user ran an actual combined "Semua"
HSK4 attempt, checked the math by hand): `7/45=16`, `0/40=0`, `0/5=0` → total `16/300`, ring
`5/100`, accuracy `7/90=8%` — all confirmed correct by manual calculation. #9's formula
(`round(correct/total*100)` per section, summed, max derived from section count not a hardcoded
level table) is working with zero fabricated numbers. Percentile (#14) and the "next focus
area" sentence (#15) were confirmed absent, as intended. Review/Retake/Back-to-home buttons all
confirmed working.

**Ring color overrides source**: `--ok`/`--danger` (app's existing pass/fail convention, used
in 6+ other places) used instead of source's literal `#34A98A`, since that hex is only a
2-location isolated example (both from the same commit) — same reasoning as decision #13,
applied in the other direction this time. Confirmed correct by the user.

**Reverted before commit**: an invented hero headline ("Mock test complete!", shown for every
badge state) was added, then caught in review and removed — source's actual headline needs a
user-name field the app has nowhere, and is pass-state-specific copy with no signal for the
other 3 states. See DECISIONS_NEEDED #21. Badge + subline carry the real info; no headline
element ships.

**Known, accepted, ported-as-is**: the sparkle dot (`.mockResultSparkle`) is hardcoded green
`#34A98A` regardless of ring state (matches source's own hardcoded/static treatment, same
precedent as the flashcard sparkle in `e40aaf1`) — looks slightly off against a red/fail ring,
not fixed, not blocking. Section Breakdown's `auto-fit` grid wrapping 2+1 instead of 3-across
is the literal same CSS rule as source (`repeat(auto-fit,minmax(240px,1fr))`) — a viewport-width
consequence, not a divergent port.

### CODE COMPLETE, UNVERIFIED — do not read the code above as "done" for these

- **HSK 1-2 branch** (`max=200`, pass line `120`, real PASSED/FAILED badge, `level <= 4`
  logic): no HSK 1-2 mock content exists yet to submit an attempt against. Code path has never
  executed against real data. **Blocked on content, not code** (DECISIONS_NEEDED #20) — retest
  the instant HSK 1-2 sets exist, don't assume it's fine because the logic reads correctly.
- **Pending state (#17, writing/essay section in combined mode)**: never triggered by the one
  real attempt tested — that attempt's writing section turned out to be objectively-gradable
  (not essay), confirmed by the app's own scoring behavior (`0/5 correct` rendered via the
  normal path, not the pending path). The `isEssay` detection code
  (`setQuestions.every(q => q.question_type === 'essay')`) has **zero real-data confirmation**.
  Needs an attempt against a genuinely essay-based writing section (HSK 5/6, per earlier
  session's finding that those levels' writing is a single 100-point essay task) to verify the
  pending card/hero state actually renders — not just that the code compiles.
- **Combined "Semua" mode generally**: only tested once, on one HSK4 attempt. HSK1-2 combined
  (2-section, no writing) and any essay-triggered combined attempt are both unverified live
  paths, not just the specific branches above.

Commit: index.html + DECISIONS_NEEDED.md + HANDOFF.md, this session.

## 7-renderer audit: DONE, 0 renderers ported — `14ac666` (**this was the correct outcome, not a shortfall**)

Audited `reading_mc`, `error_sentence`, `fill_blank`, `sentence_match`, `ordering`, `char_input`, `essay` — none have a source comp (source only ever demonstrated `listening_tf`). **Zero code changes to `index.html` this session.** That's the expected, correct result of an audit-only pass against renderers with no comp to port from — do not read "0 ported" as unfinished work next time this comes up.

Findings:
- **`char_input`/`essay` already correct**: real `<input type="text">`, real `<textarea>`, and `essayGradeBtn` already has its own `margin-top:0` (no `button{}` leak) — this code was written with real interaction in mind from the start, same pattern noted for `audioPlayBtn`/`tfBtn` in `37952ef`.
- **Side-effect check on `image_tf`** (top priority this session, since it inherited half a restyle from `37952ef`): investigated whether `.listeningImageWrap` sitting between the newly-shadow-styled `.audioPlayer`/`.tfBtn` was a "half-ported" seam. Counted occurrences instead of eyeballing it — the shadow-elevated style only exists in 2 places (both literal copies of the same source paragraph, same commit), while the bordered-flat style `.listeningImageWrap` already uses exists in 20+ pre-existing locations across the file. **Conclusion: `.listeningImageWrap` was never broken.** See DECISIONS_NEEDED #13 (now resolved) for the design rule this settled.
- **#12 (new, high priority)**: `.choiceItem`/`.segmentItem` — used by 6 of the 7 audited renderers — are non-semantic `<div>`s, same bug class as the toggleChip/gridBtn regressions from `8ec14ae`, but pre-existing and much wider (touches 4 render functions at once). This means **most of a 100-question mock test currently can't be answered by keyboard**. Elevated to the same priority tier as #9 (scoring) — both make the platform not launch-ready. Traced every click handler involved; it's mechanical (delegated click handler already works identically on `<button>` via `closest()`/`dataset`, no drag/hover/dblclick logic anywhere) — not fixed this session, footprint is too big for an audit pass, but logged with that risk assessment so it doesn't need re-deriving.

**Method note for next time a "no comp" audit comes up**: when asked to judge whether something looks "off"/"timpang" against existing style, count real occurrences of each competing pattern before concluding — a pattern that appears in 2 places from the same source commit is not equivalent to one with 20+ independently-established locations, even if both look plausible by eye.

## Flashcard + fix drift: DONE — `e40aaf1`

Follow-up round after pixel-level screenshot review surfaced 2 more drift items on top of `883a252`. Both fixed, verified in-browser (wrapper-white gone, sparkle visible, "Show answer" sentence case, lang switch + theme toggle spacing correct), committed as `e40aaf1`.

## Question card + listening_tf renderer: DONE — `37952ef`

Scoped strictly to the one question type source shows a worked example of (`isTest` block, `.dc.html` lines 322-336). Verified in-browser against a real `H4XING001` listening_tf question — badge, solid play button, solid progress fill, 23px prompt, True/False padding/radius, navigator + legend, submit button all confirmed matching. Audio playback confirmed working (0:04, pause state). Dark mode confirmed coherent without having been separately touched.

**Drift table**:

| Element | Source (`.dc.html`) | Was | Now |
|---|---|---|---|
| Audio play button | Solid `#F2B01E` circle, navy `#1c2a5e` icon, no border, drop shadow | Gradient circle, `#241a08` icon color, 1px border, no shadow | Matches source |
| Audio progress fill | Solid `#F2B01E` | Gradient | Matches source |
| Benar/Salah (`.tfBtn`) padding | `18px` uniform (`optStyle()` helper, `.dc.html` line 380) | `14px 0` | `18px` |
| `.tfBtn` radius/border/weight | `16px` / `2px` / `800` | `12px` / `1px` / `700` | Matches source |
| `.tfBtn` shadow | Shadow in both states (weaker inactive, gold-tinted active) | None | Matches source |
| "Listening" badge | Blue pill + speaker icon, per-question | Did not exist | Added, reusing existing `SECTION_ICON`/`SECTION_LABEL`/listening-color tokens rather than re-declaring them |
| Prompt text size | `23px` / weight `500` | Shared `.qStem` class at `16px` | Scoped to a **local override on this one render call**, not the shared class — 7 other renderers reuse `.qStem` and source gives no signal whether 23px is universal or listening_tf-specific |

**Shared-component note**: `.audioPlayer`/`.audioPlayBtn`/`.audioProgressTrack`/`.audioProgressFill`/`.audioTime` and `.tfRow`/`.tfBtn` are used by `image_tf`, `listening_mc`, and `image_mc` too (via the shared `renderAudioPlayer()`/`renderTFButtons()` helpers) — restyling them for `listening_tf` cosmetically changed those 3 renderers as an unavoidable side effect. Their own distinctive parts (`.listeningImageWrap`/`.listeningImage`, `.choiceList`/`.choiceItem`) were not touched.

**Consciously skipped**: play/pause glyph is still the existing unicode `▶`/`⏸` text, not source's SVG triangle — source only shows the "not playing" state, so porting just that one shape would leave the pause state visually inconsistent with nothing in source to match it to.

### Two items checked post-commit, not fixed (reported, not restyle bugs)

1. **Attempt header showing "H4XING001 LISTENING" in all-caps**: checked every `text-transform` rule in the file (6 total) — none touch `.attemptTitle`, `.attemptHeader`, `.attemptHeaderInfo`, `.pageCard`, or `.attempt`, and `$('attemptTitle').textContent = setRow.title` applies no transform in JS either. **Not a CSS bug** — the raw `title` value in `test_sets` for this set is almost certainly stored uppercase with the section name appended. Data content issue, not a restyle issue — flagging, not fixing.
2. **"Filled 1/45" while on question 8, only Q1 marked answered**: traced the full path — `.tfBtn` click sets `attemptAnswers[q.id] = {correct: bool}` for both True and False, then calls `renderAttemptQuestion()`, which unconditionally calls `renderAttemptNav()` and `renderQuestionGrid()` on every render. `isQuestionAnswered()` already special-cases `listening_tf`/`image_tf` with `typeof a.correct === 'boolean'` (catches `false` as answered, avoiding the falsy-value trap a naive `!!a.correct` would hit). This is pre-existing logic, untouched this session, and provably correct by reading — the counter re-syncs after every single answer, synchronously, no async/server dependency in this path. **"Filled 1/45" while parked on Q8 having only answered Q1 is the correct expected output**, not a bug.

## Mock test attempt chrome: DONE — `8ec14ae`

Header/toolbar/toggles/progress bar/nav buttons/question navigator/submit button ported from `.dc.html`'s `isTest` block (lines 302-358), chrome-only. Question card content and the 7 non-listening_tf question-type renderers are untouched — separate commit, separate audit (see DECISIONS_NEEDED.md #9 area / next-session section below). Verified in-browser and approved before commit.

## ⚠️ ROOT CAUSE — global `button{}` margin-top leak (relevant to every screen with buttons)

`button{ margin-top:22px }` is a **global rule that applies to every `<button>` in the file** unless a more specific selector explicitly resets `margin-top`. This was the actual cause of 3 separate rounds of "lang switch spacing looks off" complaints — the sidebar's `.langBtn`/`.themeToggle` classes never re-declared `margin-top`, so the base rule silently won. Fixed in `e40aaf1` by giving the sidebar lang switch its own standalone classes (`.sbThemeToggle`/`.sbLangPill`/`.sbLangBtn`) ported property-by-property from the design comp, instead of layering overrides onto the shared `.langBtn`/`.themeToggle` base.

**Confirmed a second time in `8ec14ae`**: `#attemptSubmitBtn` (mock test attempt) had zero explicit class and was fully inheriting the global rule — wrong radius/height/color/gradient-stops/shadow (margin-top happened to coincidentally match at 22px, everything else didn't). Fixed the same way: dedicated `.attemptSubmitBtn` class with every property declared explicitly.

**Still-open screens that are button-heavy** (check for this leak first, before suspecting layout):
- **Mock test attempt question card** — answer-choice/option buttons for the listening_tf renderer, still to port (commit 2, this session)
- **Mock test result** — Review/Retake/Back-to-home buttons
- **Materials** — filter chips (All/Vocab/Grammar/Listening/Mock)

**Rule going forward**: reset every property the base rule sets explicitly in a new dedicated class, never rely on a coincidental match, never patch the shared base rule.

## ⚠️ SECOND RECURRING RISK — source's static-prototype `<div>`s vs. this app's real interaction needs

Source (`.dc.html`) is a non-interactive prototype — clickable-looking elements (toggle chips, question navigator cells) are plain `<div>`s with an `onClick` prop, which is fine for a mockup nobody tabs through. Porting that literally into `index.html` is a real regression here: this is a live exam app, and a `<div>` can't be reached with Tab or activated with Space/Enter, and carries no screen-reader semantics.

Hit twice in `8ec14ae`, both caught before commit:
- **Toggle chips (Pinyin/Translation)**: first ported as bare `<div>`s. Reverted to `<input type="checkbox"> + <label class="toggleChip">` — input visually hidden via `clip` (not `display:none`, which would remove it from the tab order), `:focus-within` ring on the label for keyboard visibility (not `:has()` — see below).
- **Question navigator's 95-cell grid**: this one was **pre-existing** (`document.createElement('div')`, not introduced this session) but got fixed while in the area — converted to real `<button type="button">`. Converting a div to a button re-exposes it to the `button{}` leak above (a div never inherited that rule) — had to add explicit `margin-top:0; padding:0` resets that weren't needed before.

**Rule going forward**: when porting any clickable-looking element from `.dc.html`, check whether source used a real form control / button or a styled div — if source is a div, that's a byproduct of it being a prototype, not a spec to copy. Use the semantic element the interaction actually calls for.

## Still avoiding `:has()` / new CSS techniques — one addition

Needed a way to show a focus ring on a label when its visually-hidden child checkbox is focused. `:has()` would do it in one line but is still off-limits project-wide (no browser-support confidence yet, per the earlier `--muted-rgb` precedent). Used `:focus-within` instead — a different, much older pseudo-class (~2017, universally supported, not in the same risk category as `:has()`) — on the label itself. Noting this as the accepted pattern for "style a wrapper based on a hidden descendant's focus state" going forward, so it doesn't need re-litigating next time it comes up.

## Verification pattern (standing process)

You (Claude) port + syntax-check + report. The user screenshots in a live logged-in browser and approves. **Only then** commit. Claude cannot log in / drive the real app, so the user is the only one who can visually confirm a change — never commit on the strength of a syntax check alone.

## Commits this session

- **`78b9787`** — Port progress rings, quick action icons, and Recent History cards (Chunk C + Recent History)
- **`883a252`** — Port Flashcard & SRS session view to design handoff comp
- **`e40aaf1`** — Fix flashcard session chrome (`:has()` → `.sessionActive` class toggle) and sidebar lang switch button margin-top leak
- **`8ec14ae`** — Port mock test attempt chrome (header/toolbar/nav/navigator/submit), fixing two div-vs-semantic-element accessibility regressions and a second confirmed `button{}` leak
- **`37952ef`** — Port question card + listening_tf renderer (the only question type with a source comp)
- **`ae41660`** / **`38d78a8`** — Docs: post-`37952ef` checks, title/subtitle redundancy correction (#11)
- **`25ddc86`** — Resolve HSK scoring formula (#9), log full-mock data gap and HSK 3.0 risk (#10)
- **`14ac666`** — 7-renderer audit: 0 renderers ported (correct outcome, no comp exists), #13 resolved, #12 elevated to high priority — `index.html` untouched this commit, docs only

All confirmed via `git log` — nothing left uncommitted in `index.html`.

## Screenshot verification

- **Dashboard** (fresh tab, real/no-session state — genuine empty placeholders, not fabricated): greeting, stat cards, continue-practice card, daily goal, Progress by Level (empty since no session ever populated it — correct), Quick Actions (real icons: coral checkmark/green book/blue bar-chart), Recent History (empty, correct). Matches `01-dashboard.png` layout and colors everywhere real data exists to show.
- **Flashcard**: real Supabase auth isn't available in this environment, so this was verified with a synthetic single-card session pushed via console (`sessionQueue = [{hanzi:'图书馆', pinyin:'túshūguǎn', ...}]` then calling the real `renderCard()`/`revealCard()` functions directly — not fabricated product data, just a test fixture to exercise the real rendering code path, same method used for the Chunk C ring/history verification last session). Both not-flipped and flipped states screenshotted and match `03-flashcard.png` closely — chips, progress bar, badge, serif hanzi, pinyin, meaning+pos, grade-row colors and computed interval subtext all render correctly.

## Drift table — Flashcard & SRS (`.dc.html` lines 185-229 vs `index.html`)

| Element | Source (`.dc.html`) | Was (`index.html`) | Now | Verdict |
|---|---|---|---|---|
| Deck header | title + "Deck · HSK N Vocabulary" + New/Learning/Review chips, lines 187-189 | No deck header existed at all — just a bare `.sessionMeta` row showing "0/0" and "HSK N" | Added `.deckHeader` with title, subtitle, and 3 color-coded chips | **Ported.** Chip counts are real (computed from the actual session's due/new split), not copied from source's demo numbers (5/3/12). |
| New/Learning/Review split | static demo numbers, no logic behind them (prototype) | N/A (didn't exist) | New = never-seen count (real). Review vs Learning = split by `srs_reps` count on the due card (`LEARNING_REPS_THRESHOLD = 2`, our own convention) | **Not a source rule to violate** — source has zero logic here, so this is a reasonable real-data interpretation, not a guess overriding something source specified. Documented inline in code. |
| Progress bar | `height:10px`, gold→green fill, "Card N / Total" label beside it, line 191 | `height:4px`, gold-soft→gold fill, label above the bar, no "Card" word | Track height 10px, fill `linear-gradient(90deg,var(--gold),#34A98A)`, moved label beside the bar with "Card" prefix | **Fixed to match.** |
| Card area shell | `border-radius:28px`, `box-shadow:0 30px 60px -28px rgba(ink-rgb,.4)`, no padding on the shell itself (inner content carries its own padding), line 193 | `border-radius:18px`, flat `1px solid` border, flex-centered with a fixed `gap:10px` between hanzi/pinyin/meaning regardless of state | Shell now radius 28px, matching shadow, `overflow:hidden`, no padding; inner `.cardContent` carries state-specific padding instead of a fixed gap | **Fixed.** The old fixed-gap approach is the same class of bug flagged on the dashboard's continue-card text block last session (parent spacing stacking with children's own margins) — avoided here by not using gap at all, matching source's block-flow-with-margins approach. |
| HSK+word badge (top-left of card) | coral pill `HSK 4 · 图书`, line 194 | Did not exist | Added `.cardBadge`, showing `HSK {level} · {hanzi}` | **Ported, with one simplification**: source's badge text is a *different, shorter* string ("图书") than the card's main word ("图书馆") — likely a demo-content quirk, not a real second field. Used the same hanzi for both badge and main display since there's no separate "short form" data field to pull from. |
| Audio icon (top-right of card) | circular button with a speaker/volume SVG, line 195 | Did not exist | Added `.cardAudioBtn` with the literal speaker icon from source, positioned/styled to match | **Visual port only — not wired.** No audio data source exists for individual vocab words in the current schema. Clicking it does nothing right now. Backlog item, not fabricated. |
| Decorative sparkle on card | small twinkling star SVG, `position:absolute;top:40px;left:120px`, line 196 | Did not exist | Added `.cardSparkle`, same hardcoded `top:40px;left:120px` as source | **Ported in `e40aaf1`.** Position is hardcoded in source too (source's badge text is also fixed-width there), so kept hardcoded rather than inventing a badge-relative fix that doesn't exist upstream. Flagged as a real risk since our badge width is dynamic (e.g. "HSK 1 · 的" vs "HSK 4 · 图书馆") — revisit if it visibly misaligns on short/long badges. |
| Hanzi typography (not flipped) | `font-family:'Noto Serif SC',serif`, `font-size:80px`, `font-weight:700`, line 199 | `font-family:var(--hanzi-font)` (= Noto **Sans** SC, the sans-serif token used everywhere else in the app), `font-size:72px` | `font-family:'Noto Serif SC',serif` (font already loaded via the existing Google Fonts `<link>`, just never applied here), `font-size:80px` | **Fixed — this was a real, pre-existing drift** (wrong font family entirely, not just a size mismatch), independent of anything from Chunk A/C. |
| Hanzi typography (flipped) | `font-weight:600`, `font-size:46px`, line 205 | Same element/size as not-flipped state (no distinct flipped styling) | `.cardContent.flipped .hanzi-big` overrides to 46px/600 | **Fixed.** |
| Flip hint text | "Tap "Show answer" when you're ready", muted, line 200 | Did not exist | Added `.cardFlipHint`, shown only in not-flipped state | **Ported.** |
| Pinyin (flipped) | `font-size:22px`, `font-weight:800`, `color:#C7900F`, line 206 | `font-size:20px`, `color:var(--gold)` (different hex — gold token is `#F2B01E`, source uses the darker `#C7900F` amber here) | `22px`/`800`/`#C7900F` | **Fixed.** |
| Meaning + part-of-speech (flipped) | "library · noun", pos in a dimmer tone, line 207 | Just the meaning, no part-of-speech shown at all | Added `pos` to the vocab select queries (real DB column, already existed in schema) and render "meaning · pos" | **Ported — legitimate data-wiring, not fabrication** (`pos` already exists on `vocab`, just wasn't being selected/shown). |
| Example sentence block | hanzi+pinyin+translation example, divider above it, lines 208-212 | Did not exist | **Not added** | **Deliberately skipped.** `vocab` has no example-sentence column in this schema — there is no real content to show. Fabricating one would violate the no-fake-data rule. Flagged as backlog needing a new data source before it can be built. |
| Show-answer button | full-width, height 56, radius 16, gradient `#F8C13A→#F2B01E`, color `#1c2a5e`, shadow, hover lift, line 219 | Inherited the shared global `button{}` style (gold gradient but different stops/radius/height/weight/color), no shadow, no hover lift | Explicit overrides added to match source exactly | **Fixed.** |
| Grade row layout | CSS grid, 4 equal columns, gap 12px, line 222 | Flex row with `gap:10px` (visually similar but not identical) | Changed to `grid-template-columns:repeat(4,1fr)`, `gap:12px` | **Fixed (minor).** |
| Grade button colors | flat tinted pills: again=coral, hard=gold, good=green, easy=blue (rgba tints + solid text colors), lines 223-226 | Bold two-stop gradient buttons (danger-red/gold/ok-green/gold-again) — a completely different, higher-contrast visual language | Rewritten to the flat tinted pill style from source, colors matching exactly | **Fixed — this was the single biggest visual drift in this screen.** The old buttons looked like a different design system entirely. |
| Grade button subtext (interval preview) | small text under each label ("< 1 min", "6 min", "1 day", "4 days" — specific to source's one demo card's SRS state) | Did not exist — buttons had only a single label, no subtext at all | Added `.gradeBtnSub`, populated by calling the existing `sm2Update()` function speculatively (preview only, not committed) for each of the 4 grades against the real current card | **Ported the *feature*, not source's literal demo text.** The actual displayed intervals will differ from source's exact wording since they reflect this app's real SM-2 implementation (which has no sub-day intervals — "Again" always shows "N day(s)", never "< 1 min"). Changing the algorithm itself to produce sub-day intervals would be a functional change to core SRS logic, out of scope for a visual port — flagged, not silently changed. |
| Level-picker view, empty-state view | not shown in `03-flashcard.png` at all (comp only shows the active session) | Existing, functional, unstyled-by-this-effort | **Untouched** | Correctly out of scope — no design comp exists for these, same reasoning as leaving Raport/mock-result-review alone. |

## DECISIONS_NEEDED — both items closed, see that file for the full writeup

1. HSK ring 0% rule — confirmed correct (percentage-based, not level-6-specific).
2. Recent History icon/color — writing/reading restored to their literal Recent-History-block values after an earlier over-correction; listening = `#5B93D6`/`#4A7CBE` per explicit decision, documented inline in the CSS.

## Backlog items surfaced (not blockers, just noted)

- Flashcard audio icon — visual only, not wired, no data source yet.
- Flashcard example sentence — no schema field, not built.
- Deck chip Learning/Review split threshold (`LEARNING_REPS_THRESHOLD = 2`) is our own convention, not from source — flag if a different threshold is wanted.

## Remaining session order: ~~result~~ → ~~materials~~ → #12 → dark mode → materials hub (fixed, don't reshuffle)

Result screen: DONE (2 CODE COMPLETE/UNVERIFIED branches noted in that section, not blockers).
Materials screen: **DONE, approved, committed** — see section below. **#12
(`.choiceItem`/`.segmentItem` → real `<button>`) must land BEFORE the dark mode sweep, not
after.** That conversion adds new `button{}`-leak CSS resets (`margin-top`, `padding`, `width`,
`background`) on classes the dark-mode pass would otherwise need to re-check. Doing dark mode
first means redoing it once #12 lands. Dark mode is last among the *restyle* sessions on
purpose — only make that sweep once all markup for a screen is final.

**Materials hub (comp's 6-card content grid) is a separate, later item — not part of this
restyle sequence's normal flow.** It's a new-screen build, not a restyle of an existing one
(user decision, DECISIONS_NEEDED #21 UPDATE, 2026-07-16), scheduled **after #12 and dark mode**,
and gated on the user answering 3 prerequisites (what a card click does, where the dictionary
moves to, where each card's progress number comes from) — do not start it before all 3 are
answered, and do not fold it into the #12 or dark-mode sessions.

## Materials screen (Kamus Kosakata): DONE, APPROVED, COMMITTED

Source: `06-materials.png`, `.dc.html`'s `isMaterials` block (lines 264-300) — but this is a
**chrome-only styling pass on the existing Kamus (dictionary) screen**, not a port of that comp.
Full reasoning and DECISIONS_NEEDED entries (#21 UPDATE, #22, #23, #24, #25, #26) are in that
file — summary here.

**Central finding, load-bearing for everything else in this section**: the comp depicts a
content hub (6 resource-type cards: Vocab Deck, Grammar PDF, Listening Drills, Reading, Writing,
Mock Paper) that this app doesn't have built yet — the live `browseCard` screen is a vocabulary
dictionary (level picker + search + list over `vocab`, ~4,991 words), a completely different
information architecture, not a smaller/uglier version of the comp. **This screen is the Kamus,
not the Materials hub** — the comp's actual product wasn't ported at all this session, per user
decision (DECISIONS_NEEDED #21 UPDATE): the real hub gets built later, after #12 + dark mode,
once 3 prerequisites are answered. See DECISIONS_NEEDED #22 for the full gap analysis.

**What shipped this session** (chrome only on the existing Kamus screen, IA and card grid
untouched):
- **Outer white `.pageCard` wrapper — KEPT, not stripped.** First pass stripped it (reasoning:
  "the comp has no wrapper"), then **reverted** — wrong transfer of logic. This app's real rule
  is **content must contrast against the page's cream background**, not "no wrapper, ever":
  - Dashboard: no wrapper, content = white stat/continue cards → contrast ✓
  - Flashcard: no wrapper, hanzi card shell is white → contrast ✓
  - Mock List: white wrapper, cards inside are cream (`.mockSetCard`) → contrast ✓
  - Attempt: white wrapper, question card inside is cream → contrast ✓
  - **Kamus: white wrapper, word list inside is cream → contrast ✓** (this session's fix)

  Dashboard/flashcard drop the wrapper because their content *is already* a white card — a
  wrapper there would be a redundant second card. Kamus's content is a flat list, same shape as
  Mock List's — dropping the wrapper there produced cream-on-cream, zero contrast. Kamus has no
  design comp of its own (the comp's "Materials" is the different, unbuilt hub product above),
  so this wrapper call is a real product decision based on the app's own established pattern,
  not a port of anything. **This decision is scoped to Kamus's current content shape, not to
  "the Materials screen" as a fixed identity — if the hub above ever gets built, its content
  becomes actual white resource cards (matching the comp), and at that point the wrapper should
  come off again, same reasoning as dashboard/flashcard.** Don't carry "Materials keeps the
  wrapper" forward once the IA underneath it changes.
- **Cream-on-white contrast, inside the wrapper** — with the wrapper back, `.browseSearchInput`,
  `.browseList`, and `button.levelBtn`'s inactive state were all sitting at `var(--panel)`
  (white) directly against the white wrapper — invisible. Fixed by porting the exact token pair
  Mock List already uses for the same problem (`.mockSetCard{background:var(--panel-2);
  border:1px solid var(--line)}`), not inventing a new combo: `.browseSearchInput` and
  `button.levelBtn` (inactive) → `var(--panel-2)`; `.browseList` → `var(--panel-2)` +
  `1px solid var(--line)` border + `12px` radius. Divider correctness note: the container's own
  horizontal padding was deliberately left at `0` and moved onto `.browseItem` instead
  (`padding:10px 16px`), so each row's `border-bottom` divider still reaches the container's own
  left/right edge instead of floating with a gap.
- **Search bar** — comp's version is a fake `<div>+<span>` placeholder mockup (static prototype,
  not typeable). Ported the *recipe* onto the real `#browseSearch` `<input>` instead: new
  `.browseSearchWrap`/`.browseSearchIcon` wrapper + icon (dedicated classes, not reusing
  `.loginFormPanel`'s `.inputWrap`/`.inputIcon` directly, to avoid coupling the two screens),
  border/radius/shadow values matching the login input's already-proven recipe. Added an
  explicit `::placeholder` color rule scoped to `#browseSearch` only — **no `::placeholder` rule
  existed anywhere in this file before this change**; every input in the app was relying on
  unstyled browser default placeholder color until now.
- **Level picker → filter-chip shape, `div` → real `<button>`** — comp's filter chips
  (All/Vocab/Grammar/Listening/Mock, line 270) are non-semantic `<span>`s; ported the *shape*
  (pill, gold-solid active state, shadow on inactive, gap) onto the level picker's existing
  semantics (HSK 1-6 stays HSK 1-6, categories not adopted). New `button.levelBtn`/
  `button.levelBtn.active` rules, scoped to the `button` tag specifically. **Important scoping
  catch**: `.levelBtn`/`.levelPicker` is a *shared* class used by 3 render call sites —
  `renderBrowseLevelPicker()` (Materials/Kamus), `renderMockLevelPicker()`, and the section
  picker inside it (both Mock Test List, untouched screen). Only `renderBrowseLevelPicker()`'s
  `div` → `button` conversion happened; the other two still emit `<div>`s, so the tag-scoped
  `button.levelBtn` selector cannot leak onto them. Same recipe as every prior div-to-button
  conversion in this sequence (`8ec14ae`): `type="button"`, explicit `button{}`-leak reset. Two
  extra leaked properties caught by re-checking against the `.gridBtn` precedent specifically
  (not just eyeballing): `color` and `font-weight` were **not** set anywhere on `.choiceItem`-
  style elements before, so an unreset `<button>` would silently inherit the global `button{}`
  rule's `color:#241a08; font-weight:700` — reset explicitly to `color:var(--text)` /
  `font-weight:400` to preserve the pre-conversion look. `font-family` was checked and found
  already safe (global `button{}` declares `font-family:inherit`); `line-height` was checked and
  found genuinely unset anywhere in the cascade, reset to `line-height:normal` to preserve
  today's inherited value exactly (not a new arbitrary number).
- **"Load More" reclassified, "Back to Dashboard" left alone** — `browseMoreBtn` had been
  wearing `.practiceExit`'s outline styling (shared with 4 other screens' exit buttons) since it
  was first built, which was a semantic mismatch, not a contrast bug: comparing against Mock
  List's own pattern (`.mockSetCard`'s "Mulai"/"Ulangi" = primary gold action, its own "Back to
  Dashboard" = outline exit), Load More is a **primary action** (loads more dictionary entries),
  same role as "Mulai" — not an exit control. Moved to its own `.browseMoreBtn` class, ported
  minimally from `.mockSetBtn`'s own pattern (only `margin-top` overridden, everything else
  — gold gradient, navy text, padding, radius — falls through from the shared `button{}` base,
  same as `.mockSetBtn` itself does). `browseExitBtn` ("Back to Dashboard") stays on
  `.practiceExit`, untouched — it's a real exit control, same role as every other screen's Back
  to Dashboard button.
- **Page title** — `#browseHeader` got a new `.browseTitle` class (Baloo 2, 28px, 700) matching
  the comp's title styling. It had *no* dedicated styling before this (the bare `.sub` class
  only gets real styling inside `.dash`) — kept the `.sub` class alongside `.browseTitle` so the
  existing `body.lang-zh .sub` Chinese-font rule still applies. App's own text ("Kamus
  Kosakata"/"Vocabulary Dictionary") kept, not comp's ("Materials").
- **Subtitle — deliberately not added.** Comp's subtitle text ("...decks, grammar, drills & mock
  papers") describes the hub product this app doesn't have; the app has no subtitle element
  here today. Per this session's explicit scoping rule: port styling only where there's an
  existing element to restyle, never invent new copy/elements to carry text the comp specifies
  but the product doesn't support yet.
- **Card grid (`browseList`/`browseItem` content, information architecture) — untouched**, per
  hard scope boundary.

**DECISIONS_NEEDED #19 re-checked** (flagged in the prior session as something to re-verify if
this session added any new way to leave `browseCard`): no new buttons or exit paths were added —
search bar and level picker are input/filter controls, not navigation. `closeBrowse()` missing a
`hideAllPages()` safety net is still unreachable, conclusion unchanged, re-verified against the
actual new code rather than carried forward blind.

**Screenshot-approved by user, committed this session** — see `git log` for the commit hash
(index.html + HANDOFF.md + DECISIONS_NEEDED.md, one commit).

**2 items surfaced from the user's Mock List screenshots during review, logged not fixed** (see
DECISIONS_NEEDED #25/#26 for full detail) — both are about Mock List, which is out of scope for
this session:
- **#25**: pre-existing text-overlap bug on Mock List — long 2-line subtitles (e.g. `H6XING001`'s
  "HSK 6 · Listening + Reading + Writing · 101 questions · 125 minutes") get overlapped by the
  Start button. Not a regression from this session (Mock List hasn't been restyled yet).
- **#26**: `H6XING001` is a full HSK 6 mock with a writing section — real HSK 6 writing is a
  single essay, meaning this specific set is a plausible candidate to finally exercise the
  never-tested "pending" state from #17. **Could not be verified from this repo** — no local SQL
  file for `H6XING001` exists (only `sql/mocktest/hsk4-r-001.sql` is present locally) and no
  database-query tool was available this session. Needs the user to check
  `question_bank.question_type` for that set directly (Supabase dashboard/SQL editor) before
  #17 can be tested against it.

Budget note (superseded — see session 4 above): #12 is now DONE (`cd8d8ca`). Only dark mode is
left in the restyle sequence. Materials hub still does NOT come next — gated behind dark mode
and 3 unanswered prerequisites (see top of this section).
