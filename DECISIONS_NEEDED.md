# Decisions needed

## 1. HSK6 ring treatment — RESOLVED

Rule = percentage-based ("0% seen → neutral gray ring, no colored arc, muted label"), not level-based. Confirmed against `02-dashboard-scroll.png`: HSK6 shows `0/300` words — has real content, zero progress — and renders gray. The rule tracks the percentage, not the level number.

**Consequence accepted**: real data is 0% across all 6 levels right now, so all 6 rings currently render neutral gray — the per-level colors (green/blue/gold/coral/purple) won't be visible at all until real progress exists. **This is correct behavior, not a bug** — do not fake partial color for 0% to make it "look less empty." The empty-state visual (six gray rings) is a backlog item, not something to work around now. Verified in-browser (see HANDOFF.md, Chunk C section) with a synthetic level-progress call showing both the colored and neutral branches render correctly.

## 2. Recent History icon/color — RESOLVED

Checked `.dc.html`'s Recent History block (lines 177-181) against the Section Breakdown block on the mock-result screen (`isMock`, lines 249-254) since these two components' color choices for reading/writing conflict with each other. Confirmed: Section Breakdown assigns Listening=blue/Reading=green/Writing=gold with scores 84/82/79 — not monotonic with score, so it's a fixed per-section mapping there, not a threshold. Recent History's own 2 rows assign Writing=green/Reading=gold — the opposite mapping for reading/writing. There's no conditional/threshold logic anywhere in the source (static prototype, colors hardcoded per example row), so this is a **design inconsistency between two independently-hardcoded components** (comparable to the `--ink-rgb` typo found during the theme-tokens step), not a rule to reconcile into one global mapping. Each block is ported verbatim from its own block.

Applied (in `index.html`, `.historyCardIcon.*` / `.historyCardScore.*`):
- **Writing** = `#34A98A` icon / `#2E9E6B` pill, **Reading** = `#F2B01E` icon / pill — both ported literally from the Recent History block specifically (not from Section Breakdown). Confirmed still in place: `.historyCardIcon.writing`, `.historyCardIcon.reading`, `.historyCardScore.writing`, `.historyCardScore.reading` all match the literal source values.
- **Listening** = `#5B93D6` icon / `#4A7CBE` pill — no listening example exists in the Recent History block itself, so per explicit decision: use `#5B93D6`, the listening color already established elsewhere in this design system (Section Breakdown's listening color, and the stat-card badge blue from chunk A). This is documented as a decision in the CSS comment directly above the rule, not an assumption.
- Icon **shape** (not color) is separately confirmed consistent across every place it appears in source: pencil = writing, book = reading, speaker/volume = listening (copied verbatim from the Section Breakdown's Listening icon).

---

## 3. Flashcard "Done / Back" button — NO ACTION TAKEN, flagging for review

Checked `.dc.html`'s `isPractice` block (lines 185-229) in full — there is genuinely no
exit/close/back control anywhere in that block. Only the "Show answer" button and the 4
grade buttons exist once a session is active.

`index.html`'s `#practiceExitBtn2` ("Selesai / Kembali" / "Done / Back", below the grade
row) is functional — it's wired to `backToDash()`, the only way to leave an active flashcard
session without using the sidebar nav. Since source has zero exit affordance here (not "a
different-looking one", literally none), per the standing rule this reads as a gap in the
design comp, not a component to delete. **Kept as-is, untouched.** Flag if there's a reason
it should be removed (e.g. sidebar nav is considered sufficient exit) or restyled to fit
the card-shell's visual language once a comp exists for it.

---

---

## 4. Streak card gold color — OPEN, investigation in progress (do not touch color)

Pixel-measured `.sidebarStreak` in-browser vs design comp: identical dimensions (226×66px),
5-point sampling gives a *consistent* delta across every point:

```
app    #E3A34D #E3A14F #E3A150 #E3A849 #E3A54C
design #F5A135 #F69E38 #F69D3A #F4A62C #F5A232
delta: R -18, B +25 at every sampled point
```

Background cream is near-identical (`#F4F0E0` vs `#F6F0DD`, delta ≤3) — i.e. the near-gray
background barely shifts while the saturated gold shifts hard. That pattern = **~20%
desaturation**, not a CSS mismatch. Verified: desaturating the design's cream by 20% lands
on `#F5F0E1`, matching the app almost exactly. Source hex in the CSS file itself was already
confirmed identical (`linear-gradient(135deg,#F2B01E,#F79C3D)`) — the drift is happening
between CSS and rendered pixels, not in the file.

**Not yet checked** (next step when this is picked back up):
1. `getComputedStyle($('.sidebarStreak')).backgroundImage` in a live logged-in tab vs the
   source gradient string — confirms whether anything overrides it at runtime.
2. Walk every ancestor of `.sidebarStreak` up to `<html>`, checking `filter`, `opacity`,
   `mix-blend-mode`, `backdrop-filter`, `isolation` for a non-default value.
3. If both of those come back clean: most likely Chrome sRGB rendering vs the design tool's
   wider gamut — i.e. **not a bug in this codebase**, CSS is correct as written.

**HARD RULE**: do not "brighten the gold to match" — that would mean hardcoding a *more
saturated* color than the design spec, which would look oversaturated/off-brand on any
display that isn't under-rendering it the way this one sample appears to be. If the cause
turns out to be color management, the correct fix is **no code change** — confirm and close.

## 5. Daily Goal showing 200% ("40 / 20 words reviewed today") — OPEN, product decision

Real data, not a bug — user has reviewed 40 words against a goal of 20, so the copy honestly
reads "40 / 20" and the progress bar is maxed out/full. Open question: cap the displayed
number at the goal (show "20 / 20"), or keep the honest overshoot with some "exceeded" treatment
(e.g. "40/20 ✓")? This is a product/copy decision, not a restyle — **do not implement either
option without explicit sign-off.** Backlog.

## 6. Flashcard speaker button — dead/unwired — OPEN, product decision

`.cardAudioBtn` was ported as a visual-only element in `883a252` — "not wired, clicking does
nothing," no audio data source exists for individual vocab words in the current schema. A
button that looks live but does nothing is worse than no button. Options for user to decide:
- **(a)** Hide the button until a real audio source exists
- **(b)** Leave it as a visible placeholder (current state)

Noted: user has an existing `edge-tts` pipeline for the listening section that might be
reusable here — but that's a separate project/scope, not something to pull in as part of a
visual-drift fix. **Do not implement either option — decision pending.**

## 7. Flashcard badge redundant with main hanzi — OPEN, product decision

Badge currently renders `HSK {level} · {hanzi}` using the *same* hanzi as the card's main
word — e.g. "HSK 6 · 哦" over hanzi "哦". Identical string shown twice, zero added information.

In source, badge ("HSK 4 · 图书") and main hanzi ("图书馆") are *different* — 图书 (book) vs
图书馆 (library). That means source's badge is very likely showing a **topic/category**, not
the word itself, since it's clearly not just a truncation. `883a252`'s port ("no second field
to pull from data → filled with the same hanzi") was an **assumption that should have been
skipped per the standing no-guessing rule**, not silently substituted — flagged here as the
correction. Low-stakes but makes the badge currently useless.

Options for user to decide, not to be implemented without sign-off:
- **(a)** Drop the word portion, badge shows just "HSK {level}"
- **(b)** Use the `pos` (part-of-speech) column, already selected as of `883a252`
- **(c)** Use a radical field (would need to check if one exists in the `vocab` schema)
- **(d)** Leave the redundant duplicate as-is

## 8. Mock test navigator legend "Flagged" — dead state, same class as #6 — RESOLVED, 19 Jul 2026

Ported the 4-swatch legend (Answered/Current/Flagged/Empty) verbatim from `.dc.html`'s
`isTest` block (literal colors from the `tile()` helper, lines 380-393) as part of the mock
test attempt chrome pass. The app has **no flag-a-question feature** — no click/long-press
handler anywhere sets a `.gridBtn.flagged` state, and source itself doesn't show how one
would flag a question either (the `qNav` demo array just hardcodes 2 of 95 cells as
`'flagged'` for the screenshot, no real interaction exists in source). Result: the legend
permanently advertises a color that can never appear. Same category of issue as #6 (dead
speaker button) — a visible affordance/explanation for something inert.

### FIX — DONE, APPROVED, VERIFIED, 19 Jul 2026 — opsi (b), fitur beneran dibangun

**Audit pre-implementasi**: dikonfirmasi cuma lapisan presentasi yang ada (CSS `.gridBtn.flagged`
+ `.legendSwatch.flagged` + legend markup + i18n `legendFlagged` 3 bahasa) — nol state variable,
nol handler, sama persis catatan di atas. Nol resiko dobel-bangun.

**Implementasi, ~25 baris `index.html`**: `flaggedQuestions` (`Set`), sibling `attemptAnswers` —
reset di 2 titik yang sama (`startAttempt()`/`startCombinedAttempt()`). Toggle chip baru (reuse
`.toggleChip` apa adanya), ditaro di `.attemptNav` di antara Prev/Next (aksi per-soal, bukan
setting tampilan global kayak Pinyin/Translation). Checked-state di-recompute tiap
`renderAttemptNav()` dari `flaggedQuestions.has(q.id)`, pola sama kayak tombol TF/MC baca
`attemptAnswers[q.id]`. Grid dapet 1 cabang `' flagged'` tambahan.

**Keputusan desain (Kyaru)**: flag JANGAN override current — diimplementasi sebagai dot coral
kecil via `::after` (position:relative di `.gridBtn`, dot absolute di pojok), bukan
`background`/`color`, jadi nggak nabrak cascade sama `.current`/`.answered`. Current tetep gold
penuh + dot flagged kebaca bareng.

**Persist**: ikut `attemptAnswers` (in-memory doang, ilang pas refresh) — konsisten, bukan
regresi (attemptAnswers sendiri emang belum persist, #35). **Nol sentuh** `submit_attempt`,
`gatherAttemptAnswers`, review screen — flag murni client-side visual, RPC nggak pernah tau.

**Acceptance test, localhost, 5/5 lolos**: flag soal → dot muncul di navigator; buka soal itu →
current (gold) DAN flagged (dot) bareng; unflag → dot ilang; submit dengan 1 flag aktif → skor
5/200 (1/40 bener) — matematis persis buat 1 jawaban bener, **flag nol pengaruh ke angka**,
dikonfirmasi eksplisit (`flaggedQuestions.size` masih 1 pas `submitAttempt(true)` dipanggil);
console bersih di semua langkah.

Diputuskan Kyaru + Claude Code, 19 Jul 2026.

---

## 9. Mock test scoring doesn't map to the real HSK scale — core product logic, high priority

Result screen currently shows "2/90 Score" and "2/90 Correct" — two cards, identical raw
numbers, zero added information. Real HSK: HSK 3-6 = /300 (listening 100 + reading 100 +
writing 100), HSK 1-2 = /200 (no writing). Per-question point weight differs **by section by
level**, not by question type — e.g. HSK 6 writing is a single essay worth 100 of the 300
points; HSK 1 listening is 20 questions at 5 points each. No per-section minimum exists
anywhere in the real exam — only the total decides pass/fail.

The design comp (`05-mocktest-result.png`) shows the *target* presentation — percentage ring,
scaled score text (245/300), per-section breakdown each /100, PASSED/FAILED badge — but gives
no computation logic (static prototype, hardcoded demo numbers).

### Formula — RESOLVED by user, 2026-07-16

```
score_section = round(correct_in_section / total_in_section * 100)
total         = listening + reading + (writing if level >= 3)
max           = 200 (HSK 1-2) | 300 (HSK 3-6)
```

`total_in_section` must be read from the actual set's real question count at scoring time,
**never hardcoded** from the reference table below — it's context, not a lookup table to
bake into code. Real HSK's official published scoring formula is proprietary, but this
matches the HSK's own publicly-documented estimation method (correct/total × section max),
which is legitimate for a mock. This also automatically absorbs any mismatch between our
sets' question counts and the real exam's (e.g. our HSK 4 reading set has 40 questions,
matching the real exam's split exactly per `sql/mocktest/hsk4-r-001.sql` — but even where a
set's count differs, the proportional formula doesn't care).

Reference table (context only, not for hardcoding):

| Level | Listening | Reading | Writing | Max | Pass |
|---|---|---|---|---|---|
| HSK 1 | 20 (5pt) | 20 (5pt) | — | 200 | 120 |
| HSK 2 | 35 (2.86pt) | 25 (4pt) | — | 200 | 120 |
| HSK 3 | 40 (2.5pt) | 30 (3.33pt) | 10 (10pt) | 300 | 180 |
| HSK 4 | 45 (2.22pt) | 40 (2.5pt) | 15 (6.67pt) | 300 | 180 |
| HSK 5 | 45 (2.22pt) | 45 (2.22pt) | 10 (10pt) | 300 | **none** |
| HSK 6 | 50 (2pt) | 50 (2pt) | 1 (100pt!) | 300 | **none** |

### Passing line — RESOLVED by user, 2026-07-16 (option b)

HSK 5 and 6 have had **no official passing score since Feb 2013** — real HSK only issues a
raw score report for those levels, no pass/fail line. This matters here specifically: the
user's own level is HSK 6, so a PASSED/FAILED badge at that level would be factually wrong
if built naively off the HSK 3-6 180-point line.

**Decision**: HSK 1-4 → real PASSED/FAILED badge, line 180 (HSK 3-4) / 120 (HSK 1-2). HSK 5-6
→ still show 180 as a **target**, but with a label and color distinct from PASSED/FAILED —
e.g. "Target tercapai" / "Belum sampai target" (not "PASSED"/"FAILED", not the same visual
treatment). **HSK 5-6 must never render the literal words PASSED/FAILED.**

**Reasoning, on record so it doesn't get re-litigated**: writing "FAILED" at HSK 5-6 would be
a factual lie — no such line exists in the real exam past that level. But this platform is a
*practice tool*, and a practice tool without any readiness benchmark isn't useful either —
180 is the de facto benchmark serious HSK 5-6 test-takers already use to judge themselves,
even without it being an official pass line. Showing it as a labeled *target* rather than a
*pass/fail verdict* keeps the number useful without asserting something false.

### Prerequisite findings — checked in code, reporting only, nothing implemented

1. **`question_bank.section` exists as a column**, but it's a denormalized copy written at
   insert time (`sql/mocktest/hsk4-r-001.sql` line 19 inserts `section` per-row) — every row
   in a set carries its parent set's section, since a set is single-section by construction.
   Not an independent per-question value.
2. **`test_sets.section` is per-set, one of listening/reading/writing** — confirmed via
   `sql/03_submit_attempt_essay.sql`'s `submit_attempt` RPC, which joins `test_sets` by
   `set_id` to stamp a single `section` onto each `test_attempts` row. A "full mock"
   (HSK 4 all sections) isn't one set — it's 3 separate single-section sets stitched together
   client-side (`startCombinedAttempt`, the "Semua" tab), grouped by shared title base code.
   **For a combined attempt, `submit_attempt` gets called 3 times (once per underlying
   set_id)**, and the JS sums the 3 results for the on-screen total — but **no single
   combined row gets persisted**; 3 independent section-level rows land in `test_attempts`,
   with no FK/group id linking them back together. If a historical "full mock" score view is
   ever wanted later, reconstructing it means joining those rows by `user_id` + close
   `created_at` timestamps, which is fragile — flagging this as a real structural gap, not
   something to silently work around.
3. **Writing is graded per-question by the `grade-essay` Edge Function**, literal `"score":
   <0-100 integer>` from the AI (`supabase/functions/grade-essay/index.ts` line 29's rubric
   spec), stored in `essay_submissions.ai_score`. This is **completely separate from
   `submit_attempt`** — `sql/03_submit_attempt_essay.sql` explicitly excludes `essay`-type
   questions from that RPC's `total_points`/`correct_count`/`score` (patch comment: essay
   answers used to be counted as always-wrong before this fix). `index.html`'s `showResult()`
   already has an `isAllEssay` branch (~line 3438) that averages the per-question AI scores
   client-side instead of reading the RPC's score field — confirms writing-section sets are
   100% essay-type rows (no mixed objective+essay set exists in this data model). For a
   multi-question writing section (HSK 4 = 15 essay rows), the section score would need
   averaging (or summing then rescaling) those per-question 0-100 AI scores into the
   section's /100 — not yet decided which.
4. **`test_attempts` stores, per single-section row**: `score`, `total_points` (both
   points-weighted — but real data currently has `points = 1` on every question row, flat, no
   per-level weighting baked in yet, confirmed in `sql/mocktest/hsk4-r-001.sql`), and
   `correct_count`, `total_questions` (raw counts). The raw counts needed for the resolved
   formula already exist per-section. What does **not** exist: any persisted combined/full
   -mock record (see #2 above) — that's the real gap, not the per-section raw data.

**Sequencing note unchanged**: this is scoring logic, not a restyle. Port the result screen's
visual chrome first using whatever real numbers already exist (raw counts, per-section RPC
results); if a number needed for that port doesn't exist yet (a properly-scaled combined
score), skip it and point back here rather than inventing a formula.

## 10. HSK 3.0 rollout (July 2026) — RESOLVED by user, 2026-07-16

Background (unchanged): HSK 3.0 is scheduled for full worldwide implementation this month
(July 2026) — syllabus released 2025-11-15, took effect 2025-11-18, global trial ran
2026-01-31. Changes: 9 levels instead of 6, beginner/intermediate vocabulary lowered, speaking
becomes mandatory from level 3 onward. This platform is built on HSK 2.0 (6 levels, 4,991-word
vocab list, matching the level/vocab structure `vocab.meaning_id` and the level-picker UI
already assume throughout the app).

**Decision**: Platform commit ke HSK 2.0 sampai seluruh fitur stabil. HSK 3.0 = future feature
(track/mode terpisah), BUKAN migrasi. Konsekuensi: `meaning_id` translate 595 kata TIDAK lagi
gated, boleh dikerjain. Diputuskan Kyaru, 16 Jul 2026.

## 11. Attempt header title/subtitle now redundant ("...LISTENING" shown twice) — OPEN, display-only

Corrected characterization from the post-`37952ef` report: `.attemptTitle` showing
"H4XING001 LISTENING" in caps is **not a data quality issue** — `H{level}XING{seq} SECTION`
is the user's own deliberate `test_sets.title` naming scheme, not junk data. Confirmed
harmless as a naming convention.

The actual issue: `8ec14ae` **added the subtitle line** ("HSK 4 · Listening · 45 questions")
that didn't exist before. Before that commit, the title carrying the section name was the
*only* place section showed up in the header, so it was doing necessary work. Now the
subtitle also states the section, so "Listening" appears twice in the same header. The
redundancy is a side effect of adding the subtitle, not a pre-existing data problem.

**Do not fix by editing `test_sets.title` in the DB** — that column is read directly (not
reprocessed) in the mock list, mock/attempt history, and Recent History displays too; a DB
edit would ripple everywhere those render, not just this one header.

Options for user to decide, not to be implemented without sign-off:
- **(a)** Strip the section token from the title *display-only*, just in the attempt header
  (e.g. regex/split on the known `H{level}XING{seq} SECTION` pattern), leaving the stored
  `title` and every other screen that reads it untouched.
- **(b)** Leave the redundancy as-is (harmless, just slightly repetitive).
- **(c)** Drop the section from the subtitle instead, since the title already carries it.

---

## 12. Answer-selection `<div>`s across ~6 renderers aren't keyboard-reachable — OPEN, HIGH PRIORITY (elevated 2026-07-16, same tier as #9)

Same class of bug as the toggle-chip/gridBtn regressions caught and fixed in `8ec14ae` (real
exam app, `<div onclick>` can't be Tab'd to or activated with Space/Enter) — but this instance
is **pre-existing** (not introduced this session) and spans a much bigger footprint:

- `.choiceItem` (via `renderChoiceList()`) — used by `reading_mc`, `error_sentence`,
  `fill_blank`, `sentence_match`
- `.choiceItem` (via `renderListeningOptions()`) — used by `listening_mc`
- `.choiceItem.imageChoiceItem` (via `renderImageOptions()`) — used by `image_mc`
- `.segmentItem` (via `renderSegmentList()`) — used by `ordering`

That's 6 of the 7 audited renderers relying on the same non-semantic pattern — meaning most
of a 100-question mock test currently cannot be answered without a mouse. **This is
functional, not cosmetic**: elevated to the same priority tier as #9 (scoring), since both
make the platform not sellable as-is (one can't be trusted for accurate results, this one
locks out keyboard-only users from most of the exam).

**Honest risk assessment** (read every relevant code path before writing this, not guessing):
this is a **mechanical fix, no hidden traps found**. All four render functions
(`renderChoiceList`, `renderListeningOptions`, `renderImageOptions`, `renderSegmentList`)
just emit a template-string `<div class="...">`; the ordering picker's multi-select logic
(push/remove from an `order` array) lives entirely in the delegated click handler, keyed off
`e.target.closest('.segmentItem')` / `.choiceItem` and `.dataset.key` — `closest()` and
`dataset` work identically on a `<button>`. There is no drag, hover, dblclick, or long-press
interaction anywhere in this path — confirms `ordering` really is click-only, consistent with
what you'd already guessed. The delegated-click pattern is the exact same one already proven
working for `.tfBtn`/`.essayGradeBtn`, which are already real buttons today. Converting is:
swap the tag in 4 template strings, add `type="button"`, and reset the `button{}` leak
(`margin-top`, `padding`, `width`, `background`) explicitly on `.choiceItem` /
`.imageChoiceItem` / `.segmentItem` — same recipe as `8ec14ae`'s two fixes, just wider.
**No logic changes needed, no interaction mechanism changes** (multi-select stays click/tap,
not drag). Still not touched this session — this needs its own explicit go-ahead given the
footprint, but there's no technical reason to expect surprises.

## 13. Shadow-elevated vs. bordered-flat container convention — RESOLVED by user, 2026-07-16

Flagged while checking whether `listening_tf`'s port left `image_tf` visually "timpang"
(your priority check this session). Investigated by counting real occurrences, not by feel —
here's the count:

- **Shadow-elevated, no border** (`.audioPlayer`, `.tfBtn` — both from `37952ef`): exactly
  **2 locations**, both literal copies of the *same single paragraph* in `.dc.html`'s `isTest`
  block, added in the *same commit*. Per this session's own 2-location rule, that's not an
  independently-established convention — it's one source example applied to two sibling
  elements.
- **Bordered, no shadow** (`border:1px solid var(--line)`, no `box-shadow`): **20+ locations**
  across the whole file, pre-dating this session — `.choiceItem`, `.segmentItem`,
  `.orderingReveal`, `.qEssayArticle`, `.essayTextarea`, `.essayResult`, `.mockSetCard`,
  `.statBox`, `.reviewItem`, `.reviewChoice`, and — the one in question —
  `.listeningImageWrap` itself. This is the app's genuinely dominant, long-established
  container pattern.

**Rule, settled**: shadow-elevated styling applies **only to interactive elements** (audio
player, answer buttons) — matching the one thing source actually shows (its only two
shadow-styled components are both interactive). Bordered-flat stays correct for **passive
content** (images, article excerpts, previews) — matching the 20+ existing locations, none
of which get touched or "upgraded." **Nothing is broken; `.listeningImageWrap` was already
right.** Do not move the app toward shadow-elevated more broadly — this was a real design
rule, not a compromise, and it doesn't need re-litigating next time a passive-content
container sits next to a newly-ported interactive one.

Extending the 2-location shadow pattern to override the 20+-location bordered convention
would have been exactly the kind of rationalized invention this session was told to avoid —
counting caught it before it happened. **No code change made or needed.**

---

## 14. Mock result "Top 18% Percentile" — dead data, not ported, same class as #6/#8

`05-mocktest-result.png`'s stat row shows "1h 42m Time taken | 81% Accuracy | Top 18%
Percentile". Percentile needs a cohort (comparing this score against other users') — the
platform's user base is a handful of people right now, no source of that data exists and
won't for a while. **Not ported.** Time taken and Accuracy were ported (both are real,
derivable from data already in memory at result time).

Options for user to decide, not to be implemented without sign-off:
- **(a)** Leave it out permanently (current state) until real user volume exists
- **(b)** Build it once enough users exist to make a cohort meaningful
- **(c)** Something else (e.g. compare against the user's own past attempts of the same set)

## 15. "Writing is your next focus area" sentence — SKIPPED, needs weakest-section logic

Design's hero subline: "You scored 245/300 — above the HSK 4 passing line. **Writing is your
next focus area.**" The second sentence implies picking the user's weakest section
automatically. Not built — open questions with no signal from source (static prototype,
no logic behind the one hardcoded example):
- Single-section attempts have nothing to compare against.
- Tie-breaking when two sections score equally.
- Threshold — does it always name the lowest section even at 95%, or only below some cutoff?

**Not ported.** Hero subline currently ends at the score/pass-line sentence.

Options for user to decide, not to be implemented without sign-off:
- **(a)** Always name the lowest-scoring section (no threshold)
- **(b)** Only show it below some score threshold (needs a number)
- **(c)** Drop the feature entirely, keep the subline as just the score sentence (current state)

## 16. Single-section result screen — no design comp, kept on the old layout

`05-mocktest-result.png` (`isMock` block) only ever shows the **combined** "Semua" attempt
(3-section breakdown, single ring/badge for the whole exam). A single-section attempt (e.g.
`H4XING001 LISTENING`, 45 questions) has no equivalent comp — there's nothing in source to
port a ring/badge/breakdown treatment *from* for that mode.

**Implemented**: `showResult()` now branches on `attemptGroupSets` (existing flag, already
used by `submitAttempt()` to distinguish combined vs single). Combined attempts get the new
hero card (ring, badge, Section Breakdown grid). Single-section attempts keep the original
`.statRow`/`.statBox` layout untouched, with one real fix: `resScore` now shows the
#9-resolved `correct/total*100` percentage instead of raw `score/total_points` (numerically
identical today since every question row has `points=1` flat — see #9 prereq 4 — but this is
the number the resolved formula actually specifies, and it's forward-compatible once real
per-level point weighting exists).

Options for user to decide, not to be implemented without sign-off:
- **(a)** Leave single-section on the plain statRow permanently (current state) — it's not
  broken, just visually plainer than the combined hero
- **(b)** Design a single-section-specific hero/ring treatment later (would need its own
  design decision, no comp to port from)
- **(c)** Something else

## 17. Combined attempts with an essay-graded writing section — hero total shows "pending", not a number

Surfaced while wiring #9's resolved formula into the result screen. `submit_attempt`
excludes essay-type questions from `correct_count`/`total_points` (#9 prereq 3) — so for a
combined "Semua" attempt where the writing section is essay-based (true for every HSK3+ writing
set in this data model, per prereq 3's own finding), the RPC literally cannot report that
section's score. This isn't a hypothetical edge case — it's the **normal case** for any real
HSK3+ full-mock attempt.

**What was built**: `submitAttempt()`'s combined branch now also captures each section's raw
RPC result *before* summing (`sectionResults`, in-memory only, no schema/RPC change). A
section made entirely of essay questions is flagged `isEssay:true` — its Section Breakdown
card shows a "Menunggu nilai menulis" / "Awaiting writing score" state (with a "{graded}/{total}
graded" note, reusing the exact same per-question `ai_result.score` data the pre-existing
`isAllEssay` branch already reads) **instead of a computed number**. The hero ring/badge/score
also switch to a distinct "pending" state (muted ring, neutral badge) showing only the
listening+reading subtotal, explicitly labeled as partial in the subline — never a "245/300"-
looking number that could pass for the real total.

**Deliberately not decided here**: *how* to fold a writing section's average AI score into
the /300 total (average vs. sum-then-rescale) is exactly the still-open question from #9
prereq 3 ("Biarin apa adanya" instruction for `isAllEssay`). Reusing that averaging math for a
*new* per-section combined-mode number would mean silently deciding that open question, not
just leaving existing code alone — so it was skipped instead, consistent with the standing
no-guessing rule. **This ties directly back to #9 prereq 3** — resolving that unblocks this
too, same decision, two call sites.

For HSK 1-2 (no writing section exists at all) this never triggers — hero total renders fully,
same as any other combined attempt.

---

## 18. "Reading" color differs between two live screens — now real, not hypothetical

Confirmed in the app (not just in source) after building Section Breakdown: **Recent History**
renders reading = gold (`.historyCardIcon.reading`, ported literally from the Recent History
block per decision #2). **Section Breakdown** renders reading = green `#34A98A` (ported
literally from the `isMock` block, same session). Same word, two different colors, two
different screens a user can see in the same session.

This is the same design inconsistency #2 already found between these two blocks in source
(source itself never reconciled them — two independently-hardcoded prototype blocks) — #2
resolved to port each verbatim rather than invent a shared mapping, and that's what happened
here too. Confirmed correct call, not a bug to silently fix.

Options for user to decide, not to be implemented without sign-off:
- **(a)** Leave both as-is, source is inconsistent and each screen matches its own source block
- **(b)** Change Section Breakdown's reading color to gold, matching Recent History
- **(c)** Change Recent History's reading color to green, matching Section Breakdown

## 19. `backToDash()` / `closeRaport()` / `closeBrowse()` / `closeMockList()` — same shape as the `#resultCard` leak, currently unreachable

Checked whether the bug caught in `navTo(goBerandaContent)` (hiding only one card by name
instead of `hideAllPages()`) exists anywhere else. It does — as a **pattern**, not a one-off:

| Function | Hides | Shows | Called from |
|---|---|---|---|
| `backToDash()` | `practiceCard` only | `dashCard` | `practiceExitBtn1/2/3` (inside `practiceCard`) |
| `closeRaport()` | `raportCard` only | `dashCard` | `raportExitBtn` (inside `raportCard`) |
| `closeBrowse()` | `browseCard` only | `dashCard` | `browseExitBtn` (inside `browseCard`) |
| `closeMockList()` | `mockListCard` only | `dashCard` | `mockListExitBtn` (inside `mockListCard`) |

**Traced every entry point**: all 4 trigger buttons live *inside* the card each function hides
— none of them are reachable while `#resultCard` (or any other card) is showing, since you'd
have to already be looking at `practiceCard`/`raportCard`/`browseCard`/`mockListCard` to click
them. The only cross-card jump is the sidebar, and all 5 sidebar items already go through
`navTo(fn)` → `hideAllPages()` first (confirmed by reading every `navItem` listener). **So
`#resultCard` cannot currently get stuck visible through any of these 4 — the bug shape exists
but has no live path to trigger it today.**

Flagging because **`closeBrowse()` is directly in scope for next session (Materials,
`06-materials.png`)** — if that session's port adds any new way to leave `browseCard` (a new
button, a filter-chip interaction that also exits, etc.), re-check this exact assumption before
assuming `hideAllPages()` isn't needed there. Not fixed here — no live bug to fix, and this
result-screen session shouldn't touch 4 functions outside its scope.

## 20. HSK 1-2 scoring branch (max 200, pass line 120) — CODE COMPLETE, UNVERIFIED

See HANDOFF.md — no HSK 1-2 mock content exists yet to submit an attempt against, so this
branch (`HSK_PASS_LINE(200) === 120`, `level <= 4` badge logic) has never executed against
real data. Blocked on content, not code. Re-test once HSK 1-2 sets exist.

## 21. Result hero headline — reverted, no design-safe copy exists yet

First pass added a generic headline ("Mock test complete!") shown for every badge state.
Caught in review: source's actual headline is "Great work, Kyaru! 🎉" — celebratory copy
paired with a user name the app has no field for anywhere else (dashboard greeting doesn't
personalize with a real name either), and a tone that only fits the pass state — source never
shows what a fail/target/pending headline should say. Generalizing it to one flat sentence for
all 4 states was inventing copy source doesn't specify, same class of issue as #15. **Reverted
before commit** — badge + subline already state the real result; no headline is shown.

Options for user to decide, not to be implemented without sign-off:
- **(a)** Add a real user-name field somewhere and port source's exact copy for the pass state
  only, something neutral for the other 3
- **(b)** Write copy for all 4 states without a name (e.g. "Nice work!" / "Keep practicing!" /
  "Almost there!" / "Writing still pending")
- **(c)** Leave it out permanently, badge + subline are enough (current state)

---

## 22. Materials comp assumes a product this app doesn't have — CORE FINDING, product decision needed

`06-materials.png` / `.dc.html`'s `isMaterials` block (lines 264-300) shows a **content hub**:
6 card types — Vocab Deck, Grammar PDF, Listening Drills (audio), Reading passages (PDF),
Writing practice (PDF), Mock Paper. This app has real data for exactly **2** of those (vocab,
mock test sets) — there is no PDF storage, no audio-drill library, no schema for grammar/
reading/writing "resource" entities of this kind anywhere in the project.

This is a **product gap, not a design gap** — same class as #14 (percentile needs a user
cohort that doesn't exist yet) and #6 (speaker button needs an audio source that doesn't
exist yet). It is not a smaller/uglier version of the comp; it's a different feature that
happens to share a nav label.

**What this app's "Materials" actually is today**: `browseCard`, wired to `openBrowse()` —
a vocabulary dictionary (`Kamus Kosakata`): HSK 1-6 level picker + search + paginated list of
all ~4,991 `vocab` rows (hanzi/pinyin/meaning). Real, live, functional information
architecture, unrelated to the comp's card-grid-of-resource-types.

**Checked per this session's ask**: the dashboard's "Dictionary" quick action (`#browseBtn`,
`index.html:989`) calls the exact same `openBrowse()` as the sidebar's Materials nav item
(`#navMateri`, `index.html:4003`) — **both point at the same `browseCard` screen today.** If
Materials ever becomes a hub (options b/c below), this quick action needs its own destination
or it silently breaks / becomes redundant with a new Materials hub.

**Decision deferred to user, not implemented**:
- **(a)** Materials stays the dictionary permanently; the comp's hub concept is dropped
- **(b)** Materials becomes a hub later; the dictionary moves to its own nav item (Dictionary
  quick action would point there instead)
- **(c)** Materials becomes a hub once real hub content (PDFs/audio drills) exists to back it

**This session's scope** (per explicit instruction): restyle only the chrome that has a literal
shape-match in the comp — search bar (comp line 269) and the filter-chip row → level picker
(comp line 270, chip *shape* ported, semantics stay HSK 1-6, not All/Vocab/Grammar/Listening/
Mock). The card grid itself is untouched. No hub built, no card types invented.

### UPDATE by user, 2026-07-16 — hub is a planned build, not an open question; gap was undercounted

**Decision made**: the Materials hub from the comp **will be built** — this is no longer
"(a)/(b)/(c), pick one," it's confirmed direction. What's still open is *timing* and the 3
prerequisites below, not *whether*.

**Timing, fixed**: hub build happens **after #12 (choiceItem/segmentItem → real buttons) and
the dark-mode sweep**, not folded into any restyle session. Reason: this is a **new screen**,
not a restyle of an existing one — different class of work from every session in this
sequence so far. Doing it now would be scope creep into a session budgeted for chrome-only
changes.

**Corrected gap assessment** — the "2 of 6 real" count above undercounted real content:
- **Vocab Deck** — data exists (`vocab` + `user_mastery`)
- **Mock Paper** — data exists (`test_sets` + `test_attempts`)
- **Reading** — content exists, ~150 SQL files across HSK 1-6 in `question_bank` — not a PDF,
  shape is a question set, not a document
- **Writing** — same: content exists as a question set, not a PDF
- **Listening** — an `edge-tts` pipeline exists (HSK 1 already generated), not yet a full
  library across levels
- **Grammar PDF** — genuinely nothing backs this, no schema, no content anywhere → **drop this
  card type**, it's the one real fabrication risk of the 6

Realistic count is **4-5 of 6 fillable**, not 2 — the original assessment conflated "not a PDF"
with "no content," which was wrong. Still true that the *shape* (deck/PDF/audio-track cards
from the comp) doesn't match the *shape* of the real content (question sets) — see prerequisite
(a) below, that mismatch is exactly why this needs a real design pass, not a literal port.

**3 prerequisites — hub build does not start until user has answered all three**:
- **(a) What does clicking a card do?** If "Reading: Short Passages" opens a real reading
  question set, the hub is a **launcher that re-categorizes existing content**, not a document/
  media library like the comp depicts. That's a different product shape than the comp shows,
  even with real data behind every card — needs its own decision, not just "port the comp."
- **(b) Where does the dictionary go?** The 4,991-word searchable Kamus is a real, working
  feature (see #23 below) — if Materials nav becomes the hub, the dictionary needs a new home,
  and the dashboard's "Dictionary" quick action (`#browseBtn`) needs a new target or it silently
  points at the wrong screen.
- **(c) Where does each card's progress number come from?** ("186/404 learned", "3 of 12
  done", "7/10 tracks" in the comp.) Vocab → `user_mastery` (real). Reading → `test_attempts`
  (real). Writing/Listening/Mock → not yet traced. **Any card without a real source for its
  progress number must not get a fabricated one** — same no-fake-data rule as #14/#15/#21.

**Not started, not to be started early.**

### UPDATE by user, 2026-07-16 — outer `.pageCard` wrapper: kept for Kamus, reverses if/when the hub is built

First pass on the Materials session stripped Kamus's outer white `.pageCard` wrapper, reasoning
"the comp has no wrapper, so neither should we" (same treatment as `.pageCard.dash` /
flashcard's `.sessionActive`). **Reverted** — that reasoning doesn't transfer, because the
*content* isn't the same shape:

- Dashboard / flashcard drop the wrapper because their content **is already a white card**
  (stat cards, the hanzi card shell) — contrast against the page's cream background comes from
  the card itself, a wrapper would just be a second redundant card.
- Mock List / Attempt **keep** the wrapper because their content is flat cream-toned rows/panels
  — without the wrapper, that content sits directly on the page's cream background with no
  contrast at all.
- Kamus's content (`.browseList`/`.browseItem`, plain text rows) is the **second shape**, not
  the first — same as Mock List. Stripping the wrapper produced cream-on-cream.

**The actual rule this app follows**: content must contrast against the page background — not
"no wrapper, ever" and not "match whatever the comp shows." Kamus has no design comp at all
(the comp's "Materials" is the unbuilt hub product from this section, a different IA) — so the
wrapper call here is a **real product decision** based on this app's own established pattern,
not a port of anything.

**This reverses if the hub gets built.** The wrapper decision is about *Kamus's content shape*
(flat cream list), not about "the Materials screen" as a fixed identity. If/when the hub from
this section ships, its content becomes actual white resource cards (matching the comp) — at
that point the wrapper should come back off, by the same contrast rule, same reasoning as
dashboard/flashcard. Don't carry "Materials keeps the wrapper" forward without re-deriving it
from the contrast rule once the IA underneath it changes — this note (and the matching comment
in `index.html` next to `.browse{max-width:640px}`) exists so that re-derivation doesn't have to
happen from scratch.

### UPDATE by user, 2026-07-16 — 3 prasyarat RESOLVED + sistem paket diaudit

**(a) RESOLVED — Hub = launcher + workspace, bukan document library.** Per kartu:
- **Vocab Deck**: Kamus existing pindah ke sini, dipecah per level HSK. Dashboard "Dictionary"
  quick action diarahkan ke kartu ini. (= jawaban prasyarat (b) di atas — dictionary pindah ke
  hub, dashboard quick action ikut retarget.)
- **Mock Paper**: klik = redirect ke mock test flow existing.
- **Reading**: launcher ke question set reading existing.
- **Listening**: kartu "Coming soon", belum clickable (pipeline `edge-tts` nyusul).
- **Writing**: workspace ngetik bebas (notepad). Fase 1 typed only; integrasi `grade-essay` =
  fase berikutnya; handwriting/canvas = fase 2, tidak dibangun sekarang.
- **Grammar**: AKAN dibangun — konten grammar per level HSK + contoh penggunaan, difilter sesuai
  paket user. Proyek konten baru (schema + generate), track terpisah dari hub shell. Sampai
  kontennya ada: kartu "Coming soon".

**(c) RESOLVED — Progress numbers hanya dari sumber real** (`user_mastery`, `test_attempts`).
Kartu tanpa sumber real = tampil TANPA angka. Angka di comp (186/404, 7/10, 82%) = placeholder,
jangan direplikasi.

### UPDATE by user, 2026-07-16 — hub shell dibangun (`materialsHubCard`), 2 keputusan visual

Screen baru `#materialsHubCard`, terpisah dari `browseCard`/Kamus (yang masih hidup di nav
Materials seperti sekarang — hub belum menggantikan apa pun). Static markup + styling doang,
nol JS wiring (search input, filter chip, dan 4 kartu clickable-nanti semuanya tanpa listener).

- **Hub subtitle**: klausa level ("for HSK 4") di-drop di shell karena belum ada wiring.
  Kandidat: isi dari `profile.target_level` saat hub di-wire. Bukan larangan permanen, cuma
  belum ada sumbernya.
- **Badge dekoratif cover di comp** (🌙/✨/pill "HSK 4") di-drop: polanya tidak konsisten,
  maknanya tidak jelas, kemungkinan artefak designer. TAPI pill level per-kartu = kandidat
  nyata untuk fase locked-visible (badge level + gembok untuk konten di luar paket). Diputuskan
  Kyaru, 16 Jul 2026.

### UPDATE by user, 2026-07-16 — status slot reusable (`.hubStatusPill`)

Status slot hub = pill di pojok cover + cover dim. Coming-soon dan locked-visible WAJIB pakai
komponen yang sama, beda isi doang. Diputuskan Kyaru, 16 Jul 2026.

Diimplementasikan: `.hubStatusPill` (posisi `top:12px;right:12px` di dalam `.hubCardCover`,
bukan di `.hubCardBody`/slot deskripsi — itu masalah yang lagi dibenerin, status kebaca kayak
deskripsi) + `.hubCard.comingSoon .hubCardCover{filter:saturate(.6) brightness(.85)}` buat dim
ringan. Grammar & Listening pakai slot ini sekarang isinya "Coming soon". Locked-visible nanti
reuse class & posisi yang sama, ganti isi jadi ikon gembok + label paket — **jangan bikin
komponen status kedua**, extend yang ini.

### CATATAN — hub shell i18n debt, ditemukan 16 Jul 2026

Hub shell: semua teks (judul kartu, subtitle, coming-soon pill, placeholder search, chip
filter) HARDCODE English, tidak lewat sistem i18n. App trilingual (ID/EN/中) — hub belum pernah
dites di ID/中. Debt tercatat, dibayar saat hub di-wire.

**BARU — Sistem paket (hasil audit sesi ini, verdict: ada sebagian, lihat audit lengkap di
percakapan sesi ini untuk bukti baris kode):**
- Tier: `hsk_1_4` / `hsk_5` / `hsk_6` / `vip`, **KUMULATIF**: `hsk_5` = level 1-5, `hsk_6` =
  level 1-6, `vip` = level 1-6 (vip = marketing label, isi sama dengan `hsk_6`). Diputuskan
  Kyaru, 16 Jul 2026.
- **KONSEKUENSI — DONE, 2026-07-16**: `PACKAGE_LEVELS` di `index.html:1350-1358` diubah —
  `hsk_5: [5]` → `[1,2,3,4,5]`, `hsk_6: [6]` → `[1,2,3,4,5,6]`. Diverifikasi via fixture profile
  (hsk_5 → picker flashcard/mock/dashboard nunjukin 1-5, query mock list ikut; vip & hsk_1_4
  spot-check tidak berubah). `business`/`convo`/`hsk_1_4` tidak disentuh.
- **Konten di luar paket**: LOCKED-VISIBLE (keliatan + gembok + CTA "contact admin untuk
  upgrade"), menggantikan pola hide total yang sekarang ada di flashcard/dashboard/raport/mock.
  Preseden pola: business/convo "coming soon" yang sudah ada.
- **Pricing**: TBD, di luar scope.
- **Admin WAJIB isi `target_level` saat create user**; user tanpa `target_level` default ke
  level terendah paketnya (by design, bukan bug) — dicek ulang saat audit kumulatif fix
  (2026-07-16): akar masalahnya profil bolong, bukan logic `defaultLevel`. Tidak diubah.
- **GAP tercatat #1**: Kamus (`renderBrowseLevelPicker`, `index.html:2668-2685`) tidak cek
  `userPackageLevels` — user paket bawah bisa akses vocab level 5/6. Dibayar saat Kamus pindah
  ke hub.
- **GAP tercatat #2 (SECURITY DEBT)**: enforcement 100% client-side. `vocab` RLS
  (`sql/01_vocab_schema.sql`) terbuka untuk semua `authenticated` user tanpa filter package;
  `startAttempt()`/`startCombinedAttempt()` tidak re-check paket sebelum fetch soal. Acceptable
  selama user cuma lewat admin (bukan self-serve publik); **WAJIB dibayar (RLS by package)
  SEBELUM paket dijual komersial.**

**Urutan build:**
1. ~~`PACKAGE_LEVELS` kumulatif fix~~ — **DONE, 2026-07-16.**
2. Hub shell + Vocab/Kamus (dengan gating) + Mock redirect + coming-soon cards
   (Listening, Grammar) + locked-visible untuk level/tier di luar paket
3. Writing typed workspace
4. Grammar content project (paralel)
5. `grade-essay` integration, handwriting, RLS hardening — belakangan

## 23. Three names, one screen — dictionary/Materials/Dictionary all point at the same place

Confirmed: this screen's own header says "Vocabulary Dictionary" / "Kamus Kosakata"
(`#browseHeader`), the sidebar nav item that opens it says "Materials" (`#navMateri`), and the
dashboard quick action that also opens it says "Dictionary" (`#browseBtn`, confirmed same
`openBrowse()` target as the nav item — see #22). Three different labels on one real feature is
itself evidence this screen's identity is "dictionary," not "materials hub" — the "Materials"
label was borrowed from the comp before the comp's actual scope (a content hub) was understood
to be a different, not-yet-built product.

**Option for #21, not to be implemented**: **(d)** rename the nav item from "Materials" to
"Dictionary"/"Kamus" now, matching what the screen actually is, and let a *new* nav item called
"Materials" be added later when the hub from #21 actually gets built. This would make nav
label, page title, and quick-action label agree today, and leaves room for the real hub to get
its own honest nav entry later instead of colliding with the dictionary's. **Do not implement
without sign-off** — this is a nav/IA change, out of scope for a chrome-only restyle session.

## 24. `.practiceExit` (Back to Dashboard / exit buttons) — thin contrast on the white wrapper, GLOBAL issue, not Materials-specific

`.practiceExit{ background:transparent; border:1px solid var(--line); color:var(--muted) }` —
used identically by `browseExitBtn` (Materials), plus `raportExitBtn` (`raportCard`),
`mockListExitBtn` (`mockListCard`), `attemptExitBtn` (`attemptCard`), `resultCloseBtn`
(`resultCard`). All 5 sit inside the same default white `.pageCard` wrapper, so all 5 have the
identical thin `border:1px solid var(--line)` outline on white — low contrast by the same
measure that motivated the `.browseList`/search-bar/level-picker cream fix in this session.

### REVISED, 2026-07-16 — `browseMoreBtn` ("Load More") removed from this item, it was miscategorized

`browseMoreBtn` was originally lumped in here as a 6th `.practiceExit` instance, same contrast
issue. It isn't one: comparing against Mock List's pattern (`.mockSetCard`'s "Mulai"/"Ulangi"
button = primary gold action, its own "Back to Dashboard" = outline exit), "Load More" is a
**primary action** (loads more dictionary entries) — same role as "Mulai," not an exit control.
It had been wearing `.practiceExit`'s outline styling since it was first built, which was a
semantic mismatch from the start, not a contrast bug. **Fixed this session**: moved to its own
`.browseMoreBtn` class (gold, ported minimally from `.mockSetBtn`'s pattern — only margin-top
overridden, everything else falls through from the shared gold `button{}` base, same as
`.mockSetBtn` itself does). `browseExitBtn` ("Back to Dashboard") stays on `.practiceExit`,
untouched — it's a real exit control, same role as every other screen's Back to Dashboard.

**What's still open here is only the exit-button contrast itself** (the 5 screens listed above)
— **not fixed this session**, shared class touching 5 screens at once; fixing it inside a
Materials-only session would either leave the other 4 inconsistent (partial fix) or silently
expand scope past "Materials doang." **Do not implement without sign-off.** Likely timing: the
dark-mode sweep, since that session already needs to walk every screen's contrast checking both
themes — bundling this global contrast pass into it avoids a second full sweep.

## 25. Mock List text-overlap bug — "minutes" gets covered by the Start button, pre-existing, not a Materials regression

User-reported from live screenshots of `H6XING001`/`002`/`003`: the subtitle line ("HSK 6 ·
Listening + Reading + Writing · 101 questions · 125 minutes") wraps to 2 lines for these longer
combined-mock entries, and the wrapped second line ("minutes") gets visually overlapped by the
"Mulai"/"Ulangi" (Start) button instead of the layout making room for it.

**Not a regression from this session** — Mock List (`mockListCard`/`.mockSetCard`) has not been
restyled yet in this sequence (it's not on the fixed session order until its own turn comes up),
so this bug predates any work done here. **Logged only, not fixed** — out of scope for the
Materials session. Likely cause (not yet traced in code): `.mockSetCard` probably doesn't
reserve enough bottom space / doesn't let the meta line push the button down when it wraps to 2
lines — needs its own investigation when Mock List is actually in scope.

## 26. `H6XING001` (HSK 6 full mock, has a writing section) — possible candidate to finally test #17's "pending" state

HSK 6's real writing section is a single 100-point essay (per DECISIONS_NEEDED #9's reference
table) — `H6XING001` is a combined HSK 6 mock (101 questions across listening/reading/writing)
surfaced in the user's Mock List screenshots. If its writing section is genuinely `essay`-type in
`question_bank`, submitting a real attempt against it would be the first live test of #17's
"pending" hero/Section-Breakdown state (combined attempt + essay-graded writing section), which
has had **zero real-data confirmation** since it was built.

**Could not be verified from this repository** — only one local mock-test SQL file exists
(`sql/mocktest/hsk4-r-001.sql`); there is no `H6XING001` file in this repo to read
`question_type` from, and no database-query tool was available this session to check the live
`question_bank` table directly. **User needs to confirm directly** (Supabase dashboard/SQL
editor: `select question_type from question_bank where set_id = (select set_id from test_sets
where title ilike '%H6XING001%' and section = 'writing')` or equivalent) before treating this as
a real #17 test candidate. Reporting only, nothing implemented or assumed.

---

## 27. Double "Listening" badge on `H4XING001` soal #1 — traced, not fixed

User-reported from live verification of #12 (`H4XING001`, combined "Semua" attempt, soal #1,
`listening_tf`): two stacked pills both reading "Listening" — a gold-outline pill on top, a
blue pill+speaker-icon underneath.

**Traced via `git log -S`, not guessed** — these are two independent, unrelated components that
happen to share the word "Listening":

- **Gold outline pill = `.sectionBreak`** (CSS `index.html:682`, logic
  `attemptSectionBreaks`/`index.html:3211-3222,3295-3297`) — **older**, introduced in `ec87492`
  ("Group writing/reading sets into one combined exam per base code"), well before any of this
  restyle sequence. It's a **section-transition divider** for combined "Semua" attempts: only
  renders once, at the first question of each new section (`distinctSections.size > 1` gate,
  only when the combined exam actually spans >1 section). Nothing to do with question type.
- **Blue pill+icon = `.qListeningBadge`** (CSS `index.html:829`, logic `index.html:3003` inside
  `renderListeningTF`) — **newer**, added in `37952ef` (the listening_tf design-comp port,
  this restyle sequence). It's a **per-question-type indicator**, rendered unconditionally on
  every `listening_tf` question regardless of position.

**Why it only doubles on soal #1, not every listening_tf question**: the gold divider only
fires at a section boundary (first question of the listening section within the combined
attempt) — since `H4XING001` (the listening component set) happens to be first in the combined
"Semua" order, its first question hits both conditions at once. Any other `listening_tf`
question later in the same section would show only the blue badge, not both — **not checked
this session, worth confirming if this comes up again.**

**Not a regression from `37952ef`** — both components are independently correct for what they
each do; they were simply never checked against each other because no prior session's
verification happened to land on a combined attempt's very first question. **Not fixed** —
reporting only, per instruction. Options once the user decides:
- **(a)** Keep both — they answer different questions ("which section am I in" vs "what type
  of question is this") and only visually collide on one specific question per combined attempt
- **(b)** Suppress `.qListeningBadge` specifically when `attemptSectionBreaks` also fires for
  that index (avoids the one-question collision, keeps both features otherwise)
- **(c)** Drop `.qListeningBadge` entirely, rely on the section divider + the existing audio
  player as sufficient "this is a listening question" signal

## 28. `.qListeningBadge` only exists on `listening_tf`, not on `listening_mc`/`image_mc`/`image_tf` — scope was always this narrow, now visibly inconsistent

User-reported: `H4XING001` soal #11 (`listening_mc`, same set, same section, has its own audio
player) shows **no** badge at all, while soal #1 (`listening_tf`) shows one (doubled, see #27).

**Confirmed by reading `37952ef`'s own scope**: the blue badge was ported *specifically* for
`listening_tf` because that's the **only** question type source's design comp (`.dc.html`
`isTest` block) ever demonstrates — `renderListeningMC`/`renderImageMC`/`renderImageTF` were
never touched by that commit (consistent with HANDOFF's own shared-component note: audio
player/TF buttons are shared across all 4 listening-adjacent types, but the badge was not).
Not a bug introduced by accident — it's the literal, intentional scope of that port — but it
does mean 3 of the 4 audio-bearing question types currently show no "this is a listening
question" signal while 1 does, which reads as inconsistent to a test-taker moving between them.

**Not fixed — reporting only, per instruction.** Open question for user to decide, not to be
implemented without sign-off: should `.qListeningBadge` (or equivalent) show on **every**
question in the listening section (per-section basis — badge reflects `test_sets.section`,
not `question_type`), or stay scoped to **only** `listening_tf` (per-type basis, current
state)? Per-section would need moving the badge's render call out of `renderListeningTF`
specifically and into wherever all 4 listening-adjacent renderers share a common wrapper (none
currently exists — `renderListeningTF`/`renderListeningMC`/`renderImageMC`/`renderImageTF` are
4 separate functions dispatched independently from the `question_type` switch at
`index.html:3338-3344`).

---

## Correction, 2026-07-16 — `H4XING001` is 95 questions, not 90

The `7/45=16, 0/40=0, 0/5=0 → 16/300` verification numbers recorded under #9 (and repeated in
HANDOFF.md) came from a **different** set than `H4XING001`. `H4XING001` itself is confirmed 95
questions by live verification this session. Not re-deriving which set the original 45/40/5
split belongs to here — flagging only so the two numbers aren't conflated if #9's verification
history gets revisited.

---

## 29. Dark mode port — `.gridBtn.answered`/`.legendSwatch.answered` fixed; 2 items logged, not fixed

Dark mode turned out to have a real comp (`screens/08–13-*-dark.png` + `.dc.html`'s existing
`[data-theme="dark"]` token block, baris 17) — this changed the session from a contrast-judgment
sweep into a **port**, same rule as light mode: `.dc.html` is source of truth, PNG is cross-check
only. Full comparison table (screen | design dark | app dark | verdict) worked through in-session;
summary of what came out of it:

**Fixed, in 2 rounds** — `.gridBtn.answered`/`.legendSwatch.answered` (`index.html:714,722`).
`.dc.html`'s "Answered" navigator swatch (baris 348) is a **literal, unconditional `#1C2A5E`** —
same across both themes, same pattern as `.navBtn.navNext`. App had `background:var(--text)`
instead, which **happens to equal `#1C2A5E` in light mode** (coincidence — `--text` and the
literal value are numerically identical there) but flips to near-white (`#EAF0FF`) in dark,
since `--text` is a theme-adaptive token and the source's value isn't. This is *why the bug
survived 6 prior restyle sessions* — every light-mode screenshot review looked correct, because
the wrong-token and the right-literal computed to the same pixel. Only surfaced once the dark
comp gave a second data point to diff against.

**Round 1** ported the literal `#1C2A5E` verbatim, `[data-theme="dark"]`-scoped only. Verified
live via a synthetic attempt fixture (`getComputedStyle`) and it was **broken**: `#1C2A5E`
(28,42,94) vs dark `--panel` (28,43,88) — a 6-point RGB delta, functionally identical, cell
invisible against the card. Worse, the base rule's `color:var(--panel)` (same coincidental-match
bug, mirrored — correct in light where `--panel` is white, but `--panel` is also dark in dark
mode) made the number text collapse to the exact same color as the card background too.
Cross-checked `11-mocktest-attempt-dark.png` itself at this point — **the design comp has the
same flaw**: its own "answered" cells (should be 1-4, 6-8, 10-12 per "Filled 12/95") render
visually indistinguishable from "empty" cells in that screenshot. Grepped for the mirrored
pattern (`color:var(--panel)` used as foreground on a fixed-dark background) — only this 1
instance exists, contained.

**Round 2 — DELIBERATE DEVIATION from comp, decided by user, 2026-07-16**: since the literal
port is confirmed broken (both by direct pixel measurement and by the comp's own screenshot
showing the same collapse), replaced with `background:#2b3c78` (the login/dashboard brand-panel
navy — already an approved palette color from the comp, not invented) + explicit `color:#fff`.
Re-verified via `getComputedStyle` (`cell1_bg: rgb(43,60,120)`, `cell1_color: rgb(255,255,255)`,
distinct from `card_bg: rgb(28,43,88)`) and screenshot showing all 4 navigator states (answered/
current/flagged/empty) simultaneously legible. **Light mode untouched in both rounds** — its
rule (`var(--text)`/`var(--panel)`) already renders correctly and was never touched.

**Confirmed correct by design, no change** — `.navBtn.navNext` (`#1C2A5E` navy-on-near-navy-panel
in dark): matches `.dc.html` baris 340 literally, unconditional across themes. Looked like a
contrast risk before the dark comp existed; comp confirms this is the deliberate design, not a
bug — do not "fix" this to a higher-contrast color later without re-checking this note.

**Grepped for the same failure shape elsewhere** (`var(--text)`/`var(--muted)` used as
`background`, not `color`) before fixing anything, per instruction — found exactly these 2
instances, nothing else. Also found 4 places using `rgba(var(--text-rgb),X)` as background at
low alpha (`.audioPlayBtn`-adjacent `index.html:335`, `.cardAudioBtn:491`, `.resultBadge.pending:555`,
`.sectionCard.pending .sectionCardBar:577`) — **decided: leave alone, this is correct token
behavior** (translucent tint blending with whatever panel sits behind it), not the same bug
class as an opaque literal-vs-token mismatch. No fix applied, no fix needed.

**Logged, not verifiable this session** — `.resultBadge.pending` and `.sectionCard.pending
.sectionCardBar` (the "writing section awaiting AI grade" pending state from #17) won't appear
in this session's dark-mode screenshots, since triggering them needs a real combined attempt with
an essay-graded writing section in progress (same live-data gap #17/#26 already describe) — not
faked with dummy data per standing rule. **Dark mode: unverified visually — pending states, rgba
tint, expected fine** based on the token math (low-alpha rgba over `var(--panel)` dark), but
nobody has actually looked at it lit up. Re-check the instant `H6XING001` (#26) or any other
essay-graded combined attempt gets tested in dark mode.

**Logged, not fixed, out of scope** — `.gridBtn.flagged`/`.legendSwatch.flagged` alpha values
(`rgba(232,111,82,.18/.55)` in app vs `.dc.html` baris 350's `rgba(232,111,82,.3/.6)`) are a
**pre-existing drift from the light-mode port** (`8ec14ae`), not something dark mode introduced
— same value in both themes today, so it's not a theme-specific bug, just an unresolved literal-
value mismatch from an earlier session. Not touched this round (already-approved light mode,
plus the underlying feature is dead per #8 — flagging isn't worth reopening two settled items
at once). If #8 (flag feature) or the light-mode Materials-adjacent polish ever comes back into
scope, re-check this alpha value against `.dc.html` then.

**`.dc.html` dark-block findings that resolved earlier open questions**:
- Photo/image box (`.listeningImageWrap`/`.imageChoiceImg`, hardcoded `#FFFFFF`) — confirmed
  `.dc.html`'s `isTest` block has **zero image element**, in light or dark (source only ever
  demonstrates `listening_tf`). No comp signal either way — stays deferred, not guessed.
- `.practiceExit` contrast (#24) — comp's Retake/Back-to-home buttons (`.dc.html` baris 258-259)
  are **100% `var(--surface)`/`var(--ink)`/`rgba(ink-rgb,X)`-based, no dark-specific override
  exists in source**. This gives no new information beyond what light mode already established —
  **#24 is not reopened by this finding**, stays exactly as it was (still logged, still not
  implemented without sign-off).
- Materials hub PNG (`13-materials-dark.png`) — confirmed **not used** for the Kamus screen's
  dark pass, per standing #21/#22 product-gap distinction. Kamus dark mode still has no comp of
  its own; that pass is judgment-based contrast checking, tracked separately from this port.

---

## 30. Admin panel v1 (user management) — pre-implementation audit + final decisions

Comp for admin panel v1 (user management) exists. Before implementation, audited 3 things the
comp itself can't answer (backend capability, current account-creation mechanism, delete
semantics) — full findings recorded in this session's conversation, not duplicated here.
Verdict summary: create/delete auth users and password reset are **not currently possible from
the client at all** (anon-key-only app, confirmed no `service_role` key anywhere in
`index.html`) — these need a new Edge Function using `SUPABASE_SERVICE_ROLE_KEY` +
`supabase.auth.admin.*`, gated by the existing `is_admin()` Postgres function (already used in
`vocab`'s RLS policies) or an equivalent server-side admin check. Editing `profiles` fields
(display_name, target_level, package, status, subscription_end) and deactivating (`status =
'expired'`) **can** happen straight from the client under RLS, same pattern as everything else
in this app — no Edge Function needed for those. FK/cascade behavior for permanent delete
**could not be verified** — no local schema file exists for `profiles`/`user_mastery`/
`test_attempts`/`essay_submissions` (only `vocab` has a committed `CREATE TABLE`), so cascade
vs. restrict vs. orphaned-row behavior is unknown until checked directly in Supabase.

**Final decisions, both diputuskan Kyaru, 16 Jul 2026**:
- Admin page pakai sidebar existing apa adanya. Comp TIDAK menggambar toggle theme/lang karena
  area sidebar bawah di luar frame comp — bukan berarti dihapus. `.sbThemeToggle` +
  `.sbLangBtn` yang sudah ada tetap berlaku. JANGAN bikin toggle baru di dalam admin page.
- Form pattern: 1a MODAL (bukan slide-over/full page). Alasan: task pendek, konteks list tetap
  terlihat, konsisten dengan pola dialog delete-confirm.

## 31. Admin panel v1 (user management) — implementation decisions, 2026-07-17

Follow-up to #30, resolving the remaining open points before coding started.

**Email — DI-SKIP dari v1, bukan ditunda tanpa alasan.** `profiles` tidak punya kolom email;
`auth.users` tidak ter-expose lewat anon key/PostgREST (skema `auth` bukan bagian dari exposed
schema Supabase). Satu-satunya jalan ambil email adalah `supabase.auth.admin.listUsers()` /
`getUserById()`, yang butuh `service_role` key — sama Edge Function yang sudah pasti dibangun
untuk create-user di v1.5 (keputusan #30, opsi B). Bangun Edge Function tipis khusus email di v1
= bayar ongkos infra penuh (service_role secret, `is_admin()` gate, CORS, deploy) untuk manfaat
kecil. **v1: tidak ada kolom email sama sekali** (bukan kosong, bukan read-only-blank) —
`display_name` jadi identifier utama di list dan modal. Diputuskan Kyaru, 17 Jul 2026.

**`display_name` NULL** — akun dibuat manual di Supabase tanpa `raw_user_meta_data`, trigger
`handle_new_user()` cuma isi dari `raw_user_meta_data->>'display_name'`, jadi hasilnya NULL.
Render: baris 1 = "(Nama belum diisi)" / "(No name set)", muted+italic; baris 2 = 8 karakter
pertama UUID, kecil+muted, sebagai sub-identifier (placeholder saja bikin semua row-tanpa-nama
identik, UUID saja kelihatan seperti data corrupt — gabungan keduanya kasih status jelas +
tetap bisa dibedakan). Row tetap full-clickable → admin isi nama lewat Edit modal. Admin page
jadi alat deteksi profil bolong. Diputuskan Kyaru, 17 Jul 2026.

**Modal shell — komponen baru, dibangun sekali, reusable.** Codebase sebelumnya cuma punya
native `confirm()` — native dialog abu-abu browser di tengah UI navy+gold app = dua gaya dialog
di satu layar, kelas masalah yang sama dengan "dua sistem status" yang dihindari di Materials
hub. Scope sengaja minimal: overlay + panel + close (X / backdrop click / Esc) + focus trap
dasar, styled light+dark. Reusable untuk Edit modal, Deactivate confirm, dan Create user (v1.5)
tanpa nambah komponen baru. Tidak dibangun: animasi/transition, modal stacking, varian di luar
2 dialog ini, generic design system. Diputuskan Kyaru, 17 Jul 2026.

**Package dropdown wajib memuat SEMUA value yang ada di `PACKAGE_LEVELS`** (`hsk_1_4`, `hsk_5`,
`hsk_6`, `vip`, `business`, `convo` — termasuk `business`/`convo` yang `PACKAGE_LEVELS`-nya
array kosong, "coming soon"). Dropdown yang tidak memuat value existing = data corruption saat
Save: kalau user existing punya `package='business'` dan dropdown cuma 4 opsi, select jatuh ke
opsi pertama secara diam-diam, Save menulis paket yang salah. `business`/`convo` dikasih label
jujur ("Business (belum ada konten)" / "Conversation (belum ada konten)"), tidak disembunyikan
dan tidak dihapus dari opsi. **Value dari DB yang tidak match opsi manapun**: tampilkan apa
adanya (literal value-nya) + tandai visual sebagai tidak dikenal, JANGAN diam-diam fallback ke
opsi pertama — dan lapor ke user kalau ini terjadi. Diputuskan Kyaru, 17 Jul 2026.

**Self-demotion guard.** Saat ini hanya ada 1 admin. Kalau admin itu membuka profilnya sendiri
di Edit modal dan mengganti role jadi `user`, dia kehilangan akses admin permanen — tidak ada
admin lain yang bisa mengembalikan lewat UI, recovery cuma lewat Supabase SQL Editor. Guard:
role dropdown **disabled** (bukan dicegah lewat `confirm()` tambahan) ketika row yang diedit
== user yang sedang login, dengan hint text menjelaskan kenapa. Diputuskan Kyaru, 17 Jul 2026.

**`target_level` NULL — same corruption class as the package dropdown, caught during
self-verification, not by user report.** Ditemukan pas screenshot-testing modal untuk row
dengan `target_level=NULL` (kasus nyata: admin lupa isi saat create user, lihat #30's catatan
"Admin WAJIB isi target_level saat create user"): dropdown Target Level cuma punya opsi HSK 1-6,
tidak ada satupun yang dapet atribut `selected` waktu `target_level` NULL, jadi browser
default-select opsi pertama ("HSK 1") — terlihat seperti pilihan sengaja padahal bukan. Kalau
admin buka modal cuma buat benerin field lain (misal nama) lalu langsung Save tanpa nyentuh
dropdown ini, `target_level` NULL bakal ke-overwrite jadi `1` diam-diam. Sama persis kelasnya
dengan bug package yang di atas — dropdown tanpa representasi eksplisit untuk "belum
diisi/tidak dikenal" = data ditulis ulang secara tidak sengaja saat Save.

Fix: opsi eksplisit `"— Not set —"` (value kosong) ditambahkan & di-`selected` saat
`profile.target_level` falsy; save handler mengirim `target_level: null` kalau opsi itu yang
aktif, bukan `Number('')` (yang jadi `NaN`/`0`, dua-duanya salah). Ditemukan dan diperbaiki
sebelum dilaporkan ke user (bukan hasil user-report) — dicatat di sini juga sebagai pengingat
pola: **setiap dropdown yang mewakili kolom DB nullable/open-ended butuh opsi eksplisit
untuk "kosong"/"tidak dikenal", jangan andalkan browser default-select.** Kalau ada dropdown
lain ditambahkan ke admin panel nanti (mis. saat Create user v1.5), cek ulang pola ini duluan.

## 32. Admin panel v1.5 (create user + email) — implementation decisions

Edge Function baru `admin-users` (2 action: `createUser`, `listEmails`), satu gerbang admin di
awal sebelum client service_role/secret dibuat — full reasoning ada di komentar kode
(`supabase/functions/admin-users/index.ts`). Ringkasan keputusan:

**Secret key: `SUPABASE_SECRET_KEYS['default']`, bukan `SUPABASE_SERVICE_ROLE_KEY`.** Diverifikasi
langsung ke project ini (`supabase projects api-keys`) sebelum dipakai, bukan asumsi dari
dokumentasi doang — legacy service_role dikonfirmasi ditandai deprecated (target akhir 2026 per
Supabase), key baru `sb_secret_...` di project ini sudah ada duluan (sejak 2026-07-08) dengan
`secret_jwt_template.role === "service_role"` (privilege identik). Diputuskan Kyaru, 17 Jul 2026.

**Password: opsi (a), admin set langsung di Create modal.** Sama persis alur manual yang sudah
jalan sekarang (Kyaru bikin akun, Kyaru set password, Kyaru kasih ke murid) — nol regresi.
**DEBT, dicatat eksplisit**: acceptable karena Kyaru satu-satunya admin & sudah tahu credential
murid di alur manual sekarang. **WAJIB direvisi sebelum** (1) ada admin kedua selain owner, atau
(2) paket dijual komersial — admin tidak boleh tahu credential murid. Opsi upgrade nanti: invite
email (butuh SMTP, belum dicek statusnya) atau must-change-password flag (butuh kolom baru di
`profiles`). Diputuskan Kyaru, 17 Jul 2026.

**Partial failure (createUser sukses, UPDATE profiles gagal): tidak pernah dilaporkan sebagai
sukses.** Response `207` + pesan eksplisit ke UI ("User dibuat tapi setting paket/level gagal —
perbaiki lewat Edit modal"), bukan silent success. User itu tetap muncul di list dengan default
DB (`hsk_1_4`/`active`/`user`) — recoverable via Edit modal yang sudah ada. **Tidak ada
rollback/delete-on-failure**: tidak ada RLS DELETE policy, dan delete auth user CASCADE ke
`user_mastery`/`test_attempts`/dll — terlalu bahaya buat automatic recovery path. Diputuskan
Kyaru, 17 Jul 2026.

**`listUsers` page size**: single-page fetch (`perPage: 200`), cukup di skala sekarang (2 user).
**Revisit item, bukan dikerjain sekarang**: kalau jumlah user tembus ~50, butuh pagination beneran.

**Deploy + verifikasi live, 2026-07-17**: `admin-users` deployed (`supabase functions deploy`,
status `ACTIVE`). Diverifikasi dari 2 arah:
- Tanpa kredensial (curl langsung, tanpa `Authorization` / dengan token palsu): ditolak `401` di
  **platform gateway Supabase** (`verify_jwt` layer), request tidak pernah nyampe kode function.
- Dari browser Kyaru yang login admin beneran: `listEmails` **SUKSES** —
  `{"data":{"emails":{...2 user...}},"error":null}`. Ini mengonfirmasi dua hal sekaligus: gerbang
  `is_admin()` di dalam function jalan (bukan cuma platform layer), **dan** kekhawatiran soal
  supabase-js issue #1568 (`bad_jwt` dari `auth.admin.*` dengan key format baru) **tidak
  terjadi** — `SUPABASE_SECRET_KEYS['default']` jalan apa adanya lewat `auth.admin.listUsers()`.
  **Fallback ke `SUPABASE_SERVICE_ROLE_KEY` TIDAK dipakai** — komentar di kode yang menjelaskan
  fallback itu dibiarkan sebagai catatan konteks, bukan langkah yang perlu diambil.

`createUser` (satu-satunya action yang benar-benar menulis data — bikin auth user beneran di
project live) **belum diverifikasi** — sengaja ditunda, Kyaru yang akan test end-to-end lewat
browser sendiri (bukan Claude, biar tidak ada auth user tidak sengaja tercipta dari sesi testing).

## 33. BUG — session guard's `signOut()` kills the session that just won, not just the old one — RESOLVED

Ditemukan saat verifikasi admin v1.5 (`createUser` gagal "Invalid session" padahal baru login).

**Root cause**: `forceLogout()` manggil `sb.auth.signOut()` tanpa `scope` arg — default supabase-js
adalah `'global'`, yang mencabut **semua sesi user itu di semua device**, bukan cuma sesi yang
manggil `forceLogout()`. Single-device enforcement maunya: login di device B nendang device A
(device lama). Yang beneran kejadian: login di device B nendang device A **DAN** device B ikut
mati juga — karena device A yang kalah klaim tetap jalanin `forceLogout()` → `signOut()` global →
server cabut sesi device B (yang justru baru menang) bareng sesi device A. UI device B tidak sadar
sampai ada request yang divalidasi server (`admin-users`'s `auth.getUser()`) baru ketauan sesinya
udah dicabut.

**Konteks penting — kenapa `active_session_id` bukan lapisan redundan**: dicek ke Supabase
Dashboard, `SESSIONS_SINGLE_PER_USER` **OFF dan tidak bisa dinyalain** — fitur itu cuma tersedia
di Pro plan ke atas, project ini di Free plan. Artinya mekanisme custom `active_session_id` +
`claim_session` **satu-satunya** cara enforce single-device di project ini, bukan lapisan
tambahan di atas fitur native GoTrue. Ini juga berarti kondisi persis yang dibutuhkan bug
`supabase/auth#2036` ("Multi-Session Authentication Bug: Local Logout Invalidates All Sessions",
butuh `SESSIONS_SINGLE_PER_USER=false`) **match state project ini** — risiko itu nyata, bukan
teoretis, makanya opsi fix diverifikasi empiris dulu sebelum dipasang (lihat di bawah).

**Opsi dipertimbangkan** (3 dibandingkan trade-off-nya sebelum milih, bukan langsung pilih satu):
1. Device yang KALAH (A) `signOut({scope:'local'})` pas ketendang — reaktif, tapi bergantung tab A
   nyala+connect ke realtime pas ditendang. Kalau A offline pas B login, sesi A tetap valid
   sampai expired natural — bolong nyata, bukan cuma soal scope.
2. Device yang MENANG (B) `signOut({scope:'others'})` pas klaim — proaktif, nggak bergantung A
   hidup/mati sama sekali. Risiko: apakah kena bug `#2036` juga (nggak ada laporan konkret buat
   scope `others` spesifik, cuma buat `local`).
3. Kombinasi: (2) jadi sumber enforcement, (1) LEPAS bagian `signOut()`-nya, disisain cuma buat UX
   (pesan + bersih state lokal) — nutup bug kill-the-winner **dan** gap A-offline sekaligus.

**Tes empiris dijalanin sebelum implementasi** (bukan asumsi dari dokumentasi) — 2 browser
context terpisah, `sb.auth.signInWithPassword()` dipanggil langsung dari console (skip
`claim_session` sama sekali, biar yang ketes murni perilaku Supabase Auth, bukan mekanisme app),
verifikasi pakai `getUser()` + query nyata (bukan cuma state UI):

```
B (yang nendang) — SELAMAT:
  B signOut(others): null
  B getUser AFTER kick: 35a2edff-8cb1-4ad0-9a87-85bfeae639d8  null

A (yang ketendang) — MATI DI SERVER:
  GET /auth/v1/user → 403 (Forbidden)
  A getUser AFTER B kicked others: undefined
  AuthSessionMissingError: Auth session missing!
```

403 dari server terhadap token A yang masih utuh di localStorage (halaman A nggak pernah
di-reload) = pencabutan beneran di server, bukan cuma state lokal ilang. `#2036` **tidak
terpicu** meskipun `SESSIONS_SINGLE_PER_USER=false` match kondisi laporan bug-nya — kesimpulan:
`scope:'others'` aman dipakai di project ini, khusus buat kasus ini (belum tentu generalize ke
semua kondisi Supabase lain, tapi cukup buat keputusan ini).

**Fix diimplementasikan** (opsi 4/kombinasi, RESOLVED):
- `doLogin()` — persis setelah `claim_session` sukses, panggil `sb.auth.signOut({scope:'others'})`.
  Ini jadi **sumber enforcement**, bukan lagi device yang kalah bunuh diri sendiri.
- `watchSession()`'s realtime handler + `boot()`'s stale-session check — **tidak manggil
  `signOut()` lagi sama sekali**. Diganti fungsi baru `localLogout()`: bersih-bersih state lokal
  + tampilin pesan "logged in elsewhere", karena sesinya udah dicabut di server oleh device
  pemenang. Ini nutup bug §33 **dan** gap "device lama offline pas ditendang" sekaligus (opsi 1
  murni nggak nutup gap itu).
- 3 titik `gateReason` (`loadProfile`, `doLogin`, `boot` — subscription expired/lewat tanggal,
  account-level, **tetap sengaja global**: kalau langganan abis, wajar user itu ke-logout di
  semua device) — `forceLogout(reason, 'global')` **eksplisit**, bukan lagi kebetulan dari
  argumen kosong. `forceLogout()` sekarang terima `scope` opsional; dipanggil tanpa argumen kedua
  (titik-titik yang sengaja tidak disentuh: `logoutBtn`, profil gagal di-fetch, `claim_session`
  RPC gagal) tetap persis perilaku lama (`sb.auth.signOut()` tanpa arg = default `'global'`
  library, byte-identical, nol regresi).
- **Error handling `signOut(others)` gagal setelah `claim_session` sukses**: best-effort,
  `console.error` jelas + login tetap lanjut (nggak ada cara rollback `claim_session` yang
  bersih). Risiko sisa: kalau device lama JUGA kebetulan offline pas kick ini gagal, sesinya
  tetap hidup sampai expired natural — sama seperti kondisi sebelum fix ini, cuma di skenario
  ganda (kick gagal + device lama offline) yang lebih sempit. Diterima sebagai risiko sisa,
  bukan dikerjain retry/rollback (scope creep untuk kasus yang sangat jarang), keputusan Kyaru
  17 Jul 2026.

Ditemukan & diselesaikan Kyaru + Claude Code, 17 Jul 2026.

## 34. Root cause "permission denied for table profiles" — RESOLVED, GRANT-level, bukan soal key sama sekali

3 ronde sebelumnya (default `sb_secret_` client, `persistSession:false` client, fallback ke
`SUPABASE_SERVICE_ROLE_KEY`) **salah didiagnosis sebagai isu key format**. Akar masalah
sebenarnya: `service_role` **tidak punya GRANT DML di `public` schema** — cek langsung ke
`profiles`: cuma `REFERENCES, TRIGGER, TRUNCATE`, **NOL SELECT/INSERT/UPDATE/DELETE**. `vocab`
sama persis — ini **project-wide**, bukan spesifik `profiles`. `anon` juga ter-revoke (nggak
punya SELECT di `profiles`). Kemungkinan sisa security hardening lama. Nggak pernah kedeteksi
sebelumnya karena app selalu jalan sebagai `authenticated` (grant lengkap) — makanya Edit modal
(client-side, sesi admin `authenticated`) selalu sehat, sementara `admin-users` (server-side,
`service_role`/`anon`) selalu kena, apapun format key-nya.

`"permission denied for table"` itu error **level-GRANT**, bukan level-RLS-policy — persis
seperti yang diidentifikasi dari awal, cuma penyebabnya bukan yang dikira (bukan `sb_secret_`
gagal dikonversi jadi JWT `service_role` di gateway — itu teori yang masuk akal berdasarkan
riset dokumentasi, tapi terbantahkan empiris: grant yang beneran hilang, bukan
role-recognition-nya).

**Fix**: `grant select, insert, update on public.profiles to service_role;` — **sengaja TANPA
DELETE**, konsisten dengan keputusan #30 (delete permanen dicoret, FK CASCADE bahaya) —
pertahanan berlapis, bukan cuma soal RLS.

**RESOLVED, dikonfirmasi empiris — bukti before/after, kode identik nol redeploy antara dua
titik ini**:
- **test5 (sebelum grant)**: `package`/`target_level`/`subscription_end` semua default/NULL —
  UPDATE tertolak total, konsisten sama test2/test3.
- **test6 (sesudah grant)**: `package=vip` ✅, `target_level=6` ✅, `subscription_end=2026-07-31`
  ✅ — status 200, nol alert, nol `207`. `admin-users` tetap v3 (`SUPABASE_SERVICE_ROLE_KEY`,
  legacy JWT) di kedua test, **tidak ada perubahan kode/deploy di antaranya** — satu-satunya
  variabel yang berubah adalah grant DB. Ini mengunci kesimpulan: root cause GRANT-level,
  bukan format key.

**`sb_secret_` TIDAK bermasalah.** Kandidat balik ke `SUPABASE_SECRET_KEYS` sekarang terbuka lagi
(sesuai alasan awal #32: legacy key ditarget deprecated akhir 2026) — **belum dikerjakan di
commit ini**, sengaja diverifikasi satu perubahan per satu waktu (grant dulu, key nanti kalau mau
dicoba lagi), jangan gabung dua perubahan dalam satu langkah.

**Anomali "Mimilll" — CLOSED, bukan hantu.** `target_level=6` di Mimilll ternyata datang dari
**Edit modal** (Kyaru sempat ngedit Mimilll buat tes package=VIP secara terpisah, target_level
ikut kesentuh di sesi edit yang sama), **bukan** dari `createUser`'s UPDATE. Edit modal jalan
sebagai sesi `authenticated` (grant lengkap, nggak pernah kena masalah GRANT ini) — jadi
konsisten 100% sama root cause: `createUser` (jalur `service_role`) Mimilll sebenarnya **gagal
total** sama seperti test2/test3, cuma hasil edit belakangan bikin datanya kelihatan "sebagian
sukses". Nggak ada jalur kedua, nggak ada flakiness — cuma dua aksi (create yang gagal + edit
manual belakangan) yang keliatannya satu peristiwa.

Ditemukan & diselesaikan Kyaru, 17 Jul 2026.

## 35. Essay AI-grading pindah ke submit-time — review-reload & retry-persist DIUTANGKAN, bukan dibangun

Konteks: tombol "Nilai" per-soal esai dihapus. Semua esai (essay_text non-kosong) sekarang
digrading otomatis sekali, paralel, pas murid pencet Submit — hasilnya (`ai_result`/`ai_error`)
langsung kepakai buat skor rata-rata dan halaman review, persis kayak alur lama, cuma pemicunya
pindah dari klik tombol ke event submit.

**Dicek dulu (via `supabase db query --linked`, skema di-inspect langsung, bukan nebak)**:
- `test_attempts.answers` — kolom `jsonb`, dan `submit_attempt()` nyimpen `p_answers` **apa
  adanya, tanpa validasi bentuk**. Artinya nempelin `ai_result`/`ai_error` ke entry esai di
  `gatherAttemptAnswers()` itu **gratis** — nol migrasi, nol kolom baru. Ini SUDAH dikerjakan
  (write-through) di `gatherAttemptAnswers()`.
- `essay_submissions` (ai_score/ai_feedback) sudah ada dan sudah nerima insert di setiap
  panggilan `grade-essay`, tapi murni audit log tulis-doang — nggak punya `attempt_id` (nggak
  bisa dikorelasiin ke attempt tertentu kalau murid ngulang set yang sama), dan **tidak ada satu
  pun kode di frontend yang baca tabel ini balik**.
- `submit_attempt()` return value (`score/total_points/correct_count/total_questions/review`)
  **tidak termasuk `id` baris `test_attempts` yang baru diinsert**.
- Halaman Riwayat cuma nampilin ringkasan (`score/correct_count/total_questions/created_at`) —
  **tidak ada satupun jalur kode yang buka ulang satu attempt lama dan rebuild halaman review
  item-per-item dari situ.** Ini berlaku buat SEMUA tipe soal, bukan cuma esai — refresh browser
  di halaman review hari ini sudah menghilangkan review reading_mc/fill_blank/ordering juga,
  karena seluruh `renderReview()` cuma jalan sekali dari return value RPC + `attemptAnswers` di
  memori, nggak pernah dibangun ulang dari data tersimpan.

**Diputuskan DIUTANGKAN, bukan dikerjakan sekarang** (dua item, satu paket):
1. **RPC `submit_attempt` balikin `id` attempt yang baru diinsert.** Perubahan kecil (`insert
   ... returning id into v_id`, tambahin ke `jsonb_build_object`), tapi tetap perubahan fungsi
   backend yang dipakai semua submit, jadi butuh keputusan eksplisit, bukan nyelip di tengah task
   lain.
2. **Fitur "buka ulang attempt lama"** — baca balik satu baris `test_attempts`, join ulang ke
   `question_bank` buat `correct_answer`/`is_correct`, rebuild `buildReviewHTML()` dari situ.
   Baru fitur ini yang bikin halaman review bisa selamat dari refresh — buat SEMUA tipe soal,
   bukan cuma esai.

**Kenapa retry-grading-di-review nggak sekalian ditulis ke DB sekarang**: nilainya nol tanpa #2.
Kalau retry nulis ke `test_attempts` sekarang padahal belum ada yang baca balik, itu nambah
kerumitan (ubah signature RPC + `UPDATE` di client) demi data yang nggak pernah kepakai. #1 itu
bagian dari #2, bukan pekerjaan berdiri sendiri — dikerjain bareng pas #2 beneran dibangun, biar
`id` attempt yang dibalikin RPC dipakai buat dua-duanya sekaligus (reload awal + update abis
retry).

**Apa yang tetap jalan meski dua ini diutangin**: retry tombol grading di halaman review tetap
ada dan berguna DALAM SATU SESI (grading gagal → pencet Retry → berhasil, tanpa ngulang test).
Cuma nggak selamat dari refresh — dan itu konsisten, karena review-nya sendiri juga nggak
(bukan regresi baru, cuma belum pernah ada dari awal).

Diputuskan Kyaru + Claude Code, 17 Jul 2026.

## 36. `.msg.lock` hardcodes `--gold`'s rgba expansion — small debt, not urgent

Kamus's locked-level inline note (`browseLevelLockedMsg`, DECISIONS_NEEDED #22 wiring session)
uses a new `.msg` modifier, `.msg.lock` (`index.html` ~line 205), styled navy-on-gold instead of
`.err`'s red/warning language — this is an upsell message ("you don't own this yet"), not an
error the user caused, so red was rejected. Value: `rgba(242,176,30,X)` in 3 places (background/
border, light + dark) — this is `--gold` (`#F2B01E`) expanded to decimal, not an invented color.

**Debt**: hardcoded literally, same as `.msg.err`/`.msg.ok` already are (neither has a shared
`--danger-rgb`/`--ok-rgb` companion var either — this matches existing convention, not a new
problem). Consequence: if `--gold` is ever retuned, these 3 `rgba()` values won't follow —
silent drift, no error thrown. **Not worth fixing now** (only 3 usages, one component). Pay this
if/when a `--gold-rgb` companion var gets introduced generally (mirroring the existing
`--text-rgb`/`--muted-rgb` pattern) — at that point, swap these 3 to `rgba(var(--gold-rgb),X)` in
the same pass rather than one-off.

Diputuskan Kyaru + Claude Code, 17 Jul 2026.

## 37. IA RESOLVED — Materials = hub, Kamus adalah anaknya (opsi (d) dari #23, konteks penuh di #22)

Ditemukan sepanjang sesi wiring Vocab Deck/gating (#22): dua pintu masuk ke Kamus dengan label
sama-sama "Materi"/"Materials" tapi tujuan beda (`navMateri` → langsung Kamus, `browseBtn` →
hub) — IA pecah, versi kebalik dari temuan #23 ("three names, one screen"). Ini yang disebut
Kyaru sebagai "#21" di sesi ini secara lisan; entri file yang cocok sebenarnya **#22** (hub
build) dan **#23** (opsi (d): satu label nav konsisten) — dicatat di sini biar nggak nyasar
kalau ada yang nyari "#21" nanti.

**RESOLVED**: Materials = hub secara definitif. Kamus/`browseCard` bukan tujuan nav sendiri
lagi, statusnya anak dari hub (dibuka lewat kartu Vocab Deck). Kedua pintu masuk (`navMateri`
sidebar, `browseBtn` dashboard quick action) sekarang **sama-sama** → `openMaterialsHub()`,
byte-identical, nol pengecualian.

**Konsekuensi**: `openBrowse()` sekarang cuma punya satu caller nyata (`hubCardVocab`, selalu
`origin:'hub'`) — `browseOrigin` praktis selalu `'hub'` sekarang. Cabang `'dash'` (fallback
default kalau `openBrowse()` dipanggil tanpa argumen) **sengaja tidak dihapus** — disiapkan
kalau nanti dashboard quick action dipisah lagi jadi tujuan sendiri (bukan lewat hub). Fix
terkait (label tombol exit Kamus ngikut `browseOrigin`, bukan hardcode "Back to Dashboard") ada
di komit yang sama.

Diputuskan Kyaru + Claude Code, 17 Jul 2026.

## 38. POST-MORTEM — `browseOrigin` never declared, live down ~1 jam, 17 Jul 2026

**Sebab**: `let browseOrigin` ga pernah dideklarasi di mana pun. Kode NULIS ke situ di
`openBrowse()` (`browseOrigin = origin === 'hub' ? 'hub' : 'dash';`) — assignment ke variabel
yang belum pernah dideklarasi bikin JS nyiptain implicit global, jadi ini "aman" (nol error)
selama `openBrowse()` udah pernah kepanggil duluan. Kode BACA dari situ di
`renderBrowseExitLabel()`, dipanggil dari `applyStaticI18n()` → dipanggil dari alur
login/`renderDash`. Kalau `renderBrowseExitLabel()` kepanggil SEBELUM `openBrowse()` pernah
sekalipun kejalan (login segar, user belum pernah buka Kamus/hub sesi itu) →
`ReferenceError: browseOrigin is not defined`, dan itu motong seluruh rantai
`doLogin → loadProfile → renderDash → applyStaticI18n`, jadi dashboard render kosong ("—"
di semua angka) meski login-nya sendiri sukses.

**Kenapa lolos verifikasi sesi 9**: bug ini cuma reproducible dari login segar SEBELUM Kamus
pernah dibuka di sesi itu. Verifikasi sesi 9 (yang nge-build fitur ini) selalu dilakuin dari
sesi browser yang udah sempet buka Kamus/hub duluan (implicit global udah kebentuk), jadi
jalur crash-nya ga pernah ketriger pas testing.

**Bukan sabotase commit `8c1da2b`** — dicek pakai `git log -S browseOrigin`: deklarasi
`let browseOrigin` ga pernah ada di commit manapun sebelum fix (`57ca985`). Bug ada sejak
`15c245e` pertama kali nulis pola ini, cuma ke-mask sama urutan testing yang kebetulan aman.

**Fix**: `let browseOrigin = 'dash';` ditambahin sebaris sama `let mockOrigin` (`57ca985`),
nol perubahan lain. Diverifikasi live: login segar, console bersih, dashboard keisi angka
beneran.

**Aturan verifikasi baru, berlaku semua sesi ke depan**:
1. Syntax check (`node --check`/`new Function()`) BUKAN verifikasi — cuma nangkep parse error,
   nol runtime coverage buat bug kelas ini (ReferenceError yang bergantung urutan pemanggilan).
2. Verifikasi WAJIB dari login segar (incognito atau hard refresh + logout dulu), bukan sesi
   browser yang udah "anget"/udah pernah buka layar lain — persis kondisi yang nge-mask bug ini.
3. WAJIB baca console (F12) tiap verifikasi, lapor eksplisit bersih/enggak. Screenshot dashboard
   doang ga cukup — dashboard bisa keliatan normal padahal ada error yang udah kejadian sebelum
   render (atau sebaliknya, ke-skip kalau screenshot diambil dari state yang salah).
4. **(Ditambahin 18 Jul 2026, dari kesalahan nyata #48)** Query DB pake JWT non-admin (akun
   test biasa) buat audit KEBERADAAN data (ada/nggak ada baris) itu TERBATAS oleh RLS — hasil
   "0 rows" dari akun non-admin **CUMA BUKTI "nggak keliatan buat role ini"**, BUKAN bukti
   "nggak ada di DB". Kasus nyata: query `test_sets`/`question_bank` HSK6 listening pake akun
   test (`role='user'`) balikin 0 baris, disimpulin "verdict (c): data nggak ada sama sekali"
   — SALAH. Data ADA (10 set, `is_published=false`), cuma ke-filter policy `USING(is_published
   =true OR is_admin())` — akun non-admin nggak pernah bisa liat baris unpublished siapapun,
   `question_bank`-nya ikut ke-gate lewat EXISTS ke `test_sets.is_published` yang sama.
   **Aturan**: sebelum nyimpulin "data nggak ada" dari hasil query non-admin, WAJIB declare
   eksplisit "ini cuma yang keliatan buat role non-admin, unpublished/baris user lain bisa
   nggak kebaca" — dan kalau pertanyaannya soal KEBERADAAN (bukan soal "apa yang authenticated
   biasa bisa akses", yang itu justru pertanyaan yang tepat buat akun non-admin), **minta user
   jalanin query lewat SQL Editor** (jalan sebagai `postgres`, bypass RLS) alih-alih nyimpulin
   dari hasil yang ke-filter.
5. **(Ditambahin 18 Jul 2026, koreksi metode dari poin 4 di atas)** Poin 4 ("minta user jalanin
   SQL Editor") itu **cuma bener kalau Claude beneran nggak punya akses lain**. Faktanya:
   `SUPABASE_KEY` di environment sesi ini **role-nya `service_role`** (dicek dari payload JWT-nya
   langsung — bukan `anon`), yang artinya **bypass RLS SEPENUHNYA**, sama kayak SQL Editor.
   Insiden #48 (verdict awal (c) "HSK6 listening data nggak ada" SALAH) sebenarnya **bukan
   keterbatasan akses** — key yang bisa liat semua baris udah ada di environment dari awal,
   cuma nggak kepake pas audit itu. Itu **kelalaian metode**, bukan RLS beneran ngeblokir.
   **Aturan yang benar**: audit soal KEBERADAAN data **WAJIB pake `SUPABASE_KEY` (service_role)
   lewat REST API langsung** (`$SUPABASE_URL/rest/v1/...` + header `apikey`/`Authorization:
   Bearer $SUPABASE_KEY`) — BUKAN minta user jalanin SQL manual buat kasus yang Claude sendiri
   bisa jawab. **Rule lama TETAP BERLAKU, nggak berubah**: ini cuma buat BACA (`GET`/`select`).
   **Nol write** ke Supabase lewat jalur ini — `INSERT`/`UPDATE`/`DELETE`/`UPSERT` apapun tetep
   harus lewat user (SQL Editor, tempel query dari Claude), sama kayak semua migrasi/fix data
   sebelumnya. Kalau butuh verifikasi lewat aplikasi (bukan query mentah), tetep pake akun test
   biasa (`authenticated`, bukan `service_role`) — biar hasil yang dicek representasi pengalaman
   user asli, bukan pandangan admin-god-mode.

Diputuskan Kyaru + Claude Code, 17-18 Jul 2026.

## 39. Commit `8c1da2b` nyampur kerjaan dua sesi — indikasi 2 sesi CC paralel di file yang sama

Commit `8c1da2b` ("feat: listening_mc_stmt renderer (HSK6 听力 第一部分)") pesannya cuma nyebut
fitur HSK6 renderer, tapi diff-nya ikut kebawa seluruh kerjaan mock-wiring sesi ini (hub card
Listening jadi button, `mockOrigin`/`openMockList(section, origin)`, `renderMockExitLabel`).
Indikasi kuat: 2 sesi Claude Code jalan paralel nulis ke `index.html` yang sama, terus salah
satu sesi commit snapshot working-tree yang isinya udah kecampur kerjaan sesi lain, tanpa sadar.

Kali ini nol kerusakan nyata dari percampurannya sendiri (dua-duanya kode yang valid) — masalah
yang muncul (#38) murni bug pre-existing dari `15c245e`, bukan akibat commit ini nyampur. Tapi
percampuran ini yang bikin revert `15c245e` konflik pas dicoba (lihat #38 punya thread), jadi
langsung nambah friksi pas insiden.

**Aturan**: JANGAN jalanin 2 sesi Claude Code yang ngedit file yang sama secara bersamaan.

Diputuskan Kyaru + Claude Code, 17 Jul 2026.

## 40. `renderLevelPicker()` (flashcard) — level di luar paket ngumpet, bukan locked-visible

Sama penyakit kayak #8 (mock, sekarang udah difix): `renderLevelPicker()` (`index.html:2573`,
level picker buat mulai sesi flashcard) masih pakai `userPackageLevels.forEach` — level di luar
paket user nggak dirender sama sekali, bukan ditampilin dim+🔒 kayak pola Kamus (#22).

Status per 3 level picker yang ada: Kamus (#22) ✅ locked-visible, Mock (#8, sesi ini) ✅
locked-visible, **Flashcard ❌ masih ngumpet**. Kandidat follow-up buat nyamain sisa satu ini ke
pola yang sama (`div.levelBtn.locked`, reuse komponen yang sama persis kalau dikerjain — jangan
bikin inline-note ketiga). **JANGAN dikerjain sesi ini** — di luar scope (#8 cuma minta fix mock).

Diputuskan Kyaru + Claude Code, 17 Jul 2026.

## 41. 1000-row PostgREST cap — dashboard/raport/Kamus/user_mastery — RESOLVED

**Gejala**: "Progress by Level" nunjukin HSK1=150, HSK2=147, HSK3=298, HSK4=404, HSK5=1, HSK6=0 —
total PERSIS 1000.

**Verdict audit (sebelum kode ditulis)**: hipotesis user BENAR. `loadBerandaExtras()` (dashboard)
dan `loadRaport()` sama-sama fetch SELURUH tabel `vocab` (`select('hanzi,hsk_level')`, nol
`.limit()`/`.range()`) cuma buat dihitung per level di JS — kena default max-rows PostgREST
(dibuktikan empiris: bahkan `.range(0,2499)` eksplisit tetep dipotong ke 1000, bukan cuma query
tanpa range). Direplay query persis itu langsung ke DB, hasilnya byte-identical ke angka di
layar. Angka DB real (`count=exact` HEAD request): HSK1=150, HSK2=147, HSK3=298, **HSK4=598,
HSK5=1298, HSK6=2500**.

**Sebaran penyakit, diaudit sebelum fix apapun ditulis** — pola sama muncul di 3 bentuk lain:
- `loadBrowseLevel()` (Kamus per-level) — aman buat HSK1-4 (di bawah 1000), tapi **HSK5
  (1298→1000, hilang 298 kata) dan HSK6 (2500→1000, hilang 1500 kata) kepotong diam-diam, nol
  error**. Lebih serius dari bug dashboard — user paket VIP/hsk_6 yang bayar 2500 kata cuma
  dapet 1000 di Kamus, tanpa tau ada yang ilang.
- `user_mastery` per-user unbounded fetch di 3 titik (`loadBerandaExtras`, `loadRaport`,
  `startSession`/flashcard) — dorman, belum ada user yang lewat 1000 baris interaksi, tapi pola
  identik, bakal gagal sama persis begitu ke-trigger.

**Fix, nol schema/RPC/view baru**:
- `VOCAB_BATCH_SIZE = 1000` (row cap Supabase, dibuktikan empiris) + `fetchAllRanged()` — loop
  `.range()` sampe halaman pendek/kosong, dipakai di `loadBrowseLevel()` dan `startSession()`'s
  `seenSet`.
- `MASTERY_IN_CHUNK = 200` (concern beda — panjang URL query-string buat `.in()` list, bukan row
  cap) + `fetchChunkedIn()` — `.in('hanzi', masteredKeys)` di-split 200 per chunk, paralel,
  digabung. Ranjau ini ditemuin SEBELUM kode ditulis: `.in()` list user rajin (2500 hanzi) bisa
  ~20rb+ char di URL, lewat limit proxy/gateway umum (~8rb).
- `fetchVocabLevelCounts()` — 6× `head:true` count paralel, ganti fetch-4991-baris-buat-ngitung.
- `levelOf` map (gerbang "Words Mastered") dibalik arahnya: dulu dibangun dari `vocabAll` yang
  kepotong, sekarang dari `fetchChunkedIn` bounded by ukuran mastery user sendiri — ini juga yang
  jelasin kenapa **"Words Mastered" bisa 0 padahal "Daily Goal reviewed today" benar**: dua-duanya
  dari array `mastery` yang sama, tapi Words Mastered digerbang `levelOf` (ikut kepotong), Daily
  Goal enggak (langsung count, nggak lewat gerbang itu).

**Tidak disentuh**, sesuai batasan: `loadWordOfDay()`, `DUE_LIMIT`/`NEW_CANDIDATE_LIMIT`/
`WEAK_LIMIT`, schema, RPC/view.

**Verifikasi — login segar, console dibaca tiap langkah, sesuai aturan #38** (full detail di
HANDOFF.md sesi 11): live site (`xingmandarin.com`) masih kode lama (HSK4 masih `404` pas login
segar dicek — konfirmasi belum ke-deploy) → pindah ke `python -m http.server` serving file lokal
yang udah diedit, tetep connect ke Supabase asli. Dashboard + Raport: HSK5=1298, HSK6=2500, light+
dark, console bersih. Kamus HSK6: Load More di-drive sampe abis (49 klik terprogram) → `2500/2500`,
`browseCache.length` dicek langsung = 2500 (data beneran nyampe, bukan cuma label). Kamus HSK5:
sama, `1298/1298`. Network tab dashboard: persis 6 request `HEAD` count, nol bulk fetch (satu
false-alarm `statusCode:503` di panel network ternyata artefak devtools buat HEAD response —
dicek manual manggil `sb.from('vocab')...` dari console, hasilnya `status:206, count:2500,
error:null`, beneran sukses). **Words Mastered silent-drop**: nggak bisa dites pake akun
disposable (nol mastery data) — **diverifikasi terpisah oleh user pake akun HSK6 sendiri,
dikonfirmasi fixed.**

Diputuskan + diverifikasi Kyaru + Claude Code, 17 Jul 2026.

## 42. Gap #2 (RLS server-side enforcement) — audit lanjutan: RLS/GRANT/function snapshot + urutan eksekusi disepakati

Lanjutan #22 Gap #2. Audit sebelumnya (dalam sesi ini, sebelum entry ini ditulis) nemuin
sebagian besar RLS tabel (`test_sets`/`question_bank`/`profiles`/`user_mastery`) + 5 helper
function (`is_admin`, `claim_session`, `submit_attempt`, plus 2 yang baru ketauan:
`handle_new_user`, `rls_auto_enable`) **nggak ada di SQL yang di-track repo** — cuma idup di
Supabase Dashboard, sama pola drift kayak GRANT fix session 7 (#34). Sebelum nulis policy
baru, Kyaru jalanin 6 query read-only lewat SQL Editor (Claude nggak punya akses) buat dump
kondisi asli. Hasil lengkap (yang berhasil ke-capture): `sql/04_rls_snapshot.sql`.

**CAPTURE LENGKAP**: 5 percobaan pertama paste query 2/2b/4/6 gagal (placeholder text doang,
bukan data — Kyaru sendiri konfirmasi belakangan itu placeholder yang ketinggalan, bukan data
ilang), ditandain PENDING dulu biar nggak ada yang dikarang. Percobaan berikutnya semua 6
query berhasil ke-paste sebagai data asli. `sql/04_rls_snapshot.sql` sekarang lengkap, nol
section PENDING.

### Temuan — SEMUA dikonfirmasi lewat dump asli (query 1-6, `sql/04_rls_snapshot.sql`)

1. **`vocab` punya 2 policy SELECT** — `vocab_select_authenticated` (role `{authenticated}`,
   ADA di `sql/01_vocab_schema.sql`) DAN `public read vocab` (role `{public}`, `USING(true)`,
   **TIDAK ADA di file manapun di repo**). `{public}` di Postgres otomatis nyakup `anon` —
   ini persis mekanisme di balik drift yang udah kekonfirmasi 2 sesi lalu (anon bisa `SELECT
   vocab` padahal komentar file bilang enggak). Sekarang punya nama policy persis, bukan cuma
   dugaan dari perilaku REST.
2. **`test_sets read published`** (`is_published=true OR is_admin()`) dan **`qbank read
   published`** (`is_admin() OR EXISTS(...s.is_published)`) — **nol referensi ke hsk_level
   atau paket apapun**. Konfirmasi persis temuan audit sebelumnya (raw REST tanpa filter
   balikin semua 150 baris `test_sets`, semua level).
3. **`user_mastery`/`test_attempts` row-isolation — SEKARANG KEBUKTI**, sebelumnya
   "inconclusive" (akun test nol data, nggak bisa mastiin). `own mastery rw` (`auth.uid() =
   user_id`, semua command) + `admin reads mastery` terpisah; `attempts own
   select`/`attempts own insert` (`user_id = auth.uid()` (OR `is_admin()` buat select)).
   **Bener, nggak perlu disentuh.**
4. **`profiles` nol policy "user updates own profile"** — cuma admin insert/update, user
   cuma bisa baca baris sendiri. Konsisten sama nggak adanya fitur edit-profil-sendiri di
   app — dicatet sebagai observasi, bukan gap (belum ada fitur yang butuh itu).
5. **Semua 5 function `SECURITY DEFINER=true`**, termasuk 2 yang baru ketauan
   (`handle_new_user`, `rls_auto_enable`) — source lengkap tiap function sekarang ADA di
   `sql/04_rls_snapshot.sql` section 6 (query 6, real dump).
6. **`rls_forced=false` di semua 6 tabel** (default Supabase, owner/superuser tetep bypass
   RLS-nya sendiri) — konteks teknis kenapa `submit_attempt` (SECURITY DEFINER) bisa nembus
   proteksi kolom `question_bank.answer`/`explanation`.
7. **`submit_attempt` balikin `answer`+`explanation` buat `set_id` APAPUN, nol cek paket —
   DIKONFIRMASI 1:1 dari source live** (query 6, bukan lagi cross-reference ke file repo).
   SECURITY DEFINER nembus column GRANT yang bener-bener ngelindungin `answer`/`explanation`
   (dikonfirmasi query 4 — cuma 8 dari 11 kolom yang di-GRANT SELECT ke `authenticated`,
   `answer`/`explanation`/`created_at` sengaja nggak masuk). Source live nulis
   `'correct_answer': r.answer, 'explanation': r.explanation` ke `v_review` buat tiap soal
   non-essay, dikirim balik ke caller RPC manapun, nol cek level/paket di seluruh function
   body. **Ini lubang TERBESAR** — lebih gede dari RLS tabel, karena nembus proteksi yang
   UDAH bener (column grant), dan kena SEMUA user (bukan cuma yang di luar paket) — user
   `hsk_1_4` yang sah pun bisa panen kunci jawaban HSK1-4 yang dia bayar tanpa ngerjain soal
   beneran, karena RPC ini nggak peduli itu percobaan "asli" atau bukan.

   **BUKTI NYATA, bukan teori (ditemuin 18 Jul 2026, audit #48)**: Kyaru punya baris
   `test_attempts` beneran — set `h6-listening-3`, `is_published=false`, attempt tanggal
   16 Jul 2026 — **SEBELUM** fix `is_published` (#43) di-deploy 17 Jul. Ini attempt yang
   beneran nembus ke set yang belum published, persis lubang yang #43 tutup, bukan skenario
   hipotetis. Dicatet di sini sesuai instruksi eksplisit Kyaru, biar temuan #43 punya bukti
   konkret nempel di entry asal masalahnya, bukan cuma di entry fix-nya.
8. **`rls_auto_enable`** — event trigger, DIKONFIRMASI dari source live (query 6): pada
   `CREATE TABLE` di schema `public`, otomatis jalanin `ALTER TABLE ... ENABLE ROW LEVEL
   SECURITY` — dan CUMA itu, nol policy pernah ditambahin sama function ini. Relevan buat
   rencana bikin `package_levels` (kalau opsi migrasi-ke-tabel dari #41's poin 3 diambil):
   tabel baru bakal RLS-enabled otomatis + nol policy = default-deny total, termasuk ke app
   sendiri. **Harus direncanain eksplisit** (bikin policy READ buat `authenticated` di sesi/
   migrasi yang SAMA pas tabelnya dibuat), bukan diasumsikan "nanti nyala sendiri kalau udah
   ada datanya."
9. **`handle_new_user`** — DIKONFIRMASI dari source live (query 6): trigger bikin baris
   `profiles` pas user baru signup, `insert into profiles (id, display_name) values (new.id,
   ...)` — **cuma 2 kolom itu doang yang diisi**. `package`, `role`, `status`,
   `subscription_end`, `target_level` semua nggak disentuh function ini, jatuh ke DB default
   masing-masing (DDL `profiles` sendiri nggak ke-track di repo, jadi default persisnya nggak
   diketahui dari sini — tapi function-nya sendiri konfirmasi nggak pernah nyetel eksplisit).
   `profiles.package` NULL buat user baru itu konsekuensi LANGSUNG dari sini, bukan bug di
   tempat lain. Beda sama catatan lama soal `target_level` NULL (yang udah ada fallback JS:
   `PACKAGE_LEVELS[profile.package] || PACKAGE_LEVELS.hsk_1_4`, aman di client) — **kalau
   nanti RLS ditulis langsung ngerujuk `profiles.package` di SQL, perbandingan `package =
   'hsk_1_4'` di Postgres balikin `NULL`/false buat user yang package-nya NULL, BUKAN
   otomatis fallback ke hsk_1_4 kayak JS**. Policy SQL yang naif bakal default-deny total
   buat user yang belum di-set admin, beda perilaku sama app hari ini. Harus ditangani
   eksplisit kalau/pas RLS per-paket ditulis.
10. **Anomali GRANT `service_role` — DIKONFIRMASI query 2/2b, LEBIH LUAS dari laporan awal.**
    Awalnya dilaporkan "nol SELECT di `vocab` doang." Dump asli nunjukin polanya jauh lebih
    lebar — tabulasi per tabel:
    - `profiles`: INSERT, SELECT, UPDATE (+ REFERENCES/TRIGGER/TRUNCATE) — **lengkap**, satu-
      satunya tabel yang lengkap.
    - `question_bank` / `test_sets`: SELECT doang — **nol INSERT/UPDATE/DELETE**.
    - `test_attempts` / `user_mastery` / `vocab`: **NOL SELECT JUGA** (cuma REFERENCES/
      TRIGGER/TRUNCATE) — 3 tabel, bukan cuma vocab.
    `profiles` lengkap itu bukan kebetulan — itu persis tabel yang di-GRANT manual di session
    7 (`#34`, abis `admin-users` Edge Function kena "permission denied for table profiles").
    Fix itu nggak pernah di-extend ke 5 tabel lain — kelimanya masih di state yang sama
    persis kayak `profiles` SEBELUM `#34` dibenerin. Resiko konkret: Edge Function
    `service_role` manapun ke depan (pipeline audio, dsb.) yang nyentuh salah satu dari 5
    tabel ini bakal kena "permission denied" identik sama saga `#34`, tinggal nunggu
    ke-trigger.
11. **KOREKSI, 17 Jul 2026 — BUKAN bug.** Awalnya dicatet sebagai bug korektnes: live version
    (query 6) nge-`continue` duluan buat soal essay SEBELUM `v_total := v_total + 1` sempet
    jalan, jadi `v_total` (-> `total_questions`) cuma ngitung soal non-essay — kontradiksi
    komentar `sql/03_submit_attempt_essay.sql` yang bilang "soal essay tetap dihitung di
    total_questions". **Diinvestigasi sebelum ditulis fix-nya (DECISIONS_NEEDED #43), verdict
    dibalik**: `total_questions` semantiknya SEKARANG (dan di SETIAP titik pemakaiannya)
    adalah "penyebut rasio objektif", bukan "jumlah soal literal". Bukti — 3 titik formula
    persen di `index.html` semuanya masangin `total_questions` sama `correct_count`
    (`showResult()` :~4851-4854, Accuracy stat combined :~4918-4920, per-section breakdown
    :~4954), dan `correct_count` STRUKTURAL nggak pernah nyakup essay (`is_correct` essay
    selalu `null`, `v_correct` nggak pernah nambah buat `question_type='essay'`). Kalau
    `total_questions` ikut nyakup essay sementara `correct_count` mustahil, section CAMPURAN
    (sebagian objektif + sebagian essay — cth HSK5 writing = 完成句子 + 2 essay) bakal nunjukin
    persen yang MUSTAHIL nyampe 100% walau semua soal objektif dijawab bener (kasus konkret:
    8 objektif bener semua + 2 essay = 8/10 = 80%, padahal akurasi objektif beneran 8/8=100%).
    Jalur "all-essay pending" (#17, `setQuestions.every(q=>q.question_type==='essay')`) cuma
    nangkep section 100% essay, BUKAN section campuran — jadi section campuran bakal langsung
    kena formula yang salah itu. Justifikasi komentar `sql/03` ("progress soal ke-N dari
    total") juga nggak match kebutuhan nyata manapun — indikator progress pas attempt LAGI
    JALAN dihitung dari `attemptQuestions.length` (client-side, :~4364), bukan dari
    `total_questions` yang di-persist RPC ini. **Kesimpulan**: perilaku live (essay exclude
    dari `total_questions`) SUDAH BENAR. Yang salah komentar `sql/03`, bukan kodenya. **TIDAK
    DIFIX** — lihat blok komentar besar di `sql/05_submit_attempt_gap2_fixes.sql` (di atas
    definisi function) biar sesi depan nggak "nemuin" ini lagi dan ngulang kesalahan yang
    sama (termasuk kesalahan Claude Code sendiri sesi ini, yang sempet ngusulin fix ini
    sebelum dikoreksi Kyaru).

### Urutan eksekusi Gap #2 — DISEPAKATI Kyaru + Claude Code, 17 Jul 2026

**`submit_attempt` fix DULUAN, RLS tabel per-paket NYUSUL.** Bukan urutan sembarang — alasan:

- **Blast radius lebih gede**: RLS tabel yang bocor (poin 2 di atas) itu "orang liat konten
  di luar paketnya" — nggak enak, tapi masih di dalam pagar (harus login, baca kolom yang
  emang boleh dibaca). `submit_attempt` (poin 7) nembus pagar yang UDAH bener (column grant)
  dan kena SEMUA user termasuk yang di dalam paketnya sendiri — integritas exam bolong dari
  dalem, bukan cuma soal batas paket.
- **Scriptable, nol UI**: nggak perlu exploit RLS, tinggal panggil RPC-nya langsung buat
  `set_id` manapun — satu script bisa nyapu seluruh bank soal.
- **Nol dependency ke keputusan `package_levels`** (#41 poin 3 — RLS tabel per-paket butuh
  itu duluan sebagai prasyarat, `PACKAGE_LEVELS` sekarang cuma ada di JS, nol representasi
  DB). Fix `submit_attempt` versi paling minimal (jangan pernah balikin `correct_answer`/
  `explanation` asli lewat RPC) nggak butuh tau paket user itu apa — bisa jalan duluan,
  independen.
- **Lebih isolated buat diverifikasi**: satu function, satu `CREATE OR REPLACE`, gampang
  dites terpisah (panggil sebelum/sesudah, cek `v_review` nggak lagi bawa jawaban asli).
  RLS tabel per-paket itu proyek lebih gede (exempt anon word-of-day, tetep izinin COUNT
  buat level locked biar #41 nggak regresi, handle histori mastery user yang levelnya
  sekarang di luar paket) — resiko regresi lebih tinggi, pantas sesi sendiri.

**Catatan**: benerin `submit_attempt` doang NGGAK nutup semua lubang — user tetep bisa baca
TEKS soal (bukan jawabannya) di luar paketnya lewat `startAttempt(setId)` langsung (poin 2
RLS tabel, jalur beda). Dua-duanya tetep harus dibenerin, cuma `submit_attempt` duluan.

**Belum ditulis SQL fix apapun** — sesi ini scope-nya audit + dump doang, per instruksi
eksplisit.

Diputuskan Kyaru + Claude Code, 17 Jul 2026.

## 43. Gap #2 step 2 — `submit_attempt`: fix `is_published` + bug #11 DIKERJAIN, throttle (opsi b) DITOLAK, exam-integrity hole DICATET SEBAGAI DEBT TERBUKA

Lanjutan #42. Rencana awal (2 opsi) buat nutup temuan #42 poin 7 (`submit_attempt` balikin
`answer`/`explanation` buat `set_id` apapun, nol cek paket, nol cek submission asli-atau-bukan):
opsi (a) validasi `test_sets.is_published` (bug murni, ketauan pas nyusun rencana — RPC ini
nggak pernah ngecek publish status sama sekali, beda dari RLS `qbank read published`/
`test_sets read published` yang eksplisit ngecek itu buat direct-read) dan opsi (b) throttle
berbasis hitungan `distinct set_id` per window waktu dari `test_attempts` yang udah ada (nol
tabel baru).

### Opsi (b) DITOLAK Kyaru — alasannya benar, dicatet biar nggak dicoba lagi tanpa re-derive

`startCombinedAttempt()` (tab "Semua") manggil `submit_attempt` **sekali per set_id di dalam
group, loop, dalam hitungan detik** — combined HSK3-6 = 3 set_id (listening/reading/writing)
kepanggil beruntun. Ambang throttle manapun yang masuk akal (dicoba: >3 set_id beda dalam 5
menit) **ketrigger sama SATU mock combined + sedikit aktivitas normal lain** — false positive
ke murid rajin, bukan ke penyerang. Ditambah, oleh laporan sendiri: script yang sabar (submit
pelan, di bawah ambang) tetep nyicil panen tanpa kena — jadi throttle nggak nangkep ancaman
yang serius, cuma ngerusak UX user sah. Nambah failure mode di jalur paling kritis (SEMUA
submit mock test lewat `submit_attempt`) buat proteksi yang secara desain nggak efektif =
tradeoff negatif. **Jangan dicoba lagi tanpa alasan baru** — kelemahan ini struktural
(combined attempt's call pattern), bukan soal salah pilih angka ambang.

### Exam-integrity hole (panen `answer`/`explanation` dalam paket sendiri via RPC "kosong") — STRUKTURAL, DITERIMA SEBAGAI DEBT TERBUKA

Kesimpulan dari rencana sebelumnya, dikonfirmasi di sini: **server nggak punya cara ngebedain
"submit asli abis ngerjain" vs "panggil RPC langsung, jawaban kosong"** — dua-duanya request
yang identik bentuknya (`p_set_id`, `p_answers`, `p_time_taken` — semua nilai `p_time_taken`
pun disuplai client, nggak diverifikasi server-side sama sekali). Nggak ada token/session
server-side yang bisa nyatetin "user ini beneran buka soal duluan." Ini bukan bug yang bisa
ditambal dari DALAM `submit_attempt` — proteksi apapun yang cuma baca ulang `test_attempts`
(kayak opsi b) cuma nge-throttle, nggak nutup akarnya, dan kebukti dari kasus combined attempt
sendiri kalau throttle malah salah sasaran.

**Fix beneran = opsi (c) dari rencana sebelumnya**: konsep exam-session server-side —
`startAttempt` bikin baris/token attempt DI SERVER dulu (dengan timestamp mulai, expiry),
`submit_attempt` WAJIB nyocokin token itu sebelum ngasih skor+review. Ini **butuh schema baru**
(tabel/kolom token session) — di luar batasan sesi ini (`nol tabel baru`, `package_levels` juga
udah ditunda ke step 3 dengan alasan yang sama).

**Keputusan**: **DITERIMA sebagai debt terbuka, DICATET, BUKAN ditambal setengah-setengah**
dengan opsi (b) yang justru nambah resiko di jalur kritis buat proteksi yang lemah. Diterima
selama user cuma masuk lewat admin (bukan self-serve publik), sama persis pola penerimaan
debt di #22 Gap #2 sebelumnya.

**TRIGGER buat wajib dikerjain**: **sebelum ada user berbayar yang bukan orang dalam/partner
test.** Begitu ada penjualan self-serve publik, exam-session server-side (opsi c) jadi
prasyarat, bukan nice-to-have — proteksi klien-side + RLS + `is_published` check doang nggak
cukup buat produk yang integritas exam-nya jadi janji komersial ke pembeli.

### Yang DIKERJAIN sesi ini (satu `CREATE OR REPLACE FUNCTION submit_attempt`, is_published-only)

1. **Validasi `test_sets.is_published`** — RPC sekarang nolak (`raise exception`) kalau
   `p_set_id` nggak match baris `test_sets` yang `is_published = true`. Sebelumnya nol
   validasi ini sama sekali (RPC bisa dipanggil buat set_id apapun, published atau draft).
   Zero behavior change buat set yang beneran dipakai user (semua yang keliatan di Mock List
   udah pasti `is_published=true`, dijamin filter `loadMockList()` sendiri).
2. **Bug #11 — TIDAK DIFIX, dikoreksi jadi BUKAN bug** (lihat #42 finding 11, revisi). Fix yang
   sempet diusulin (increment `v_total` di cabang essay) DITOLAK setelah investigasi: bakal
   ngerusak formula #9 (`correct_count/total_questions`) buat section campuran objektif+essay
   (skor jadi mustahil 100% walau semua soal objektif bener). Live behavior (essay exclude
   dari `total_questions`) sudah benar, dipertahankan apa adanya.
3. **`correct_answer`/`explanation` TETAP dibalikin normal** — nol perubahan ke fitur review,
   sesuai keputusan bahwa opsi (b) ditolak dan opsi (c) di luar scope. Exam-integrity hole di
   atas masih terbuka, dicatet, bukan disembunyiin.

SQL final + kerangka verifikasi: lihat commit/HANDOFF sesi ini.

### VERIFIED live, 17 Jul 2026

- Sebelum paste: `hsk6-reading-1` (`is_published=false`) → RPC sukses (200), balikin data
  (kunci jawaban ke-panen dari set yang belum publish — persis lubang yang dimaksud).
- Sesudah paste: `hsk6-reading-1` → ditolak (`400`), server-side, sesuai fix.
- Submit normal (set published) → jalan sama persis kayak sebelumnya, review utuh, nol
  regresi.

Diputuskan Kyaru + Claude Code, 17 Jul 2026.

## 44. Frontend belum siap buat `submit_attempt` gagal — RPC error path baru pernah ke-trigger sekarang, JANGAN DIKERJAIN SEKARANG

Ditemuin pas verifikasi live fix #43 (`is_published` gate): abis RPC balikin error (`400`,
`"set not found or not published"`), console nunjukin **`TypeError: Cannot read properties of
undefined (reading 'replace')`** — bukan pesan error yang rapi ke user, crash JS.

**Sebab, ditelusuri dari kode (belum dikonfirmasi baris persis dari stack trace, tapi ini
satu-satunya kandidat yang cocok)**: jalur combined attempt (`submitAttempt()`,
`index.html:4734-4735`) manggil `t('errSubmitFailedNamed').replace('{title}', s.title)` pas
`error` ada. Selama ini `submit_attempt` **NGGAK PERNAH gagal** (nol validasi apapun sebelum
fix #43) — jadi jalur `if(error){...}` di kedua call site (combined :4734, single :4791) itu
kode yang DITULIS tapi **belum pernah beneran ke-exercise sama produksi nyata sampai fix ini
ada**. Begitu RPC BISA gagal (fix #43 sengaja bikin ini terjadi), jalur error yang selama ini
"aman di atas kertas" ketauan belum teruji beneran.

**Skenario nyata yang bisa kena**: admin nge-unpublish satu set (misal lagi direvisi) PAS ada
user yang udah kadung buka attempt buat set itu (fetch soal duluan lewat `startAttempt`/
`startCombinedAttempt` sebelum status berubah) — begitu dia Submit, `submit_attempt` nolak
(set udah nggak published), frontend crash, **layar mati tanpa pesan yang jelas ke user**
(bukan cuma "gagal submit," tapi JS exception yang bisa nyetop render lanjutan).

**Kenapa nggak dikerjain sekarang**: di luar scope Gap #2 (ini bug frontend error-handling,
bukan security/RLS), butuh diagnosis sendiri (harus dikonfirmasi persis baris mana yang
nge-throw, dicek juga jalur single-section yang KELIHATANNYA lebih aman — nol `.replace()` di
:4792 — apa beneran aman atau ada TypeError lain di situ juga). **Kandidat follow-up sesi
terpisah.**

Diputuskan Kyaru + Claude Code, 17 Jul 2026.

## 45. `listeningAudioUrl`/`listeningImageUrl` crash pada `image_tf` di 10 set `H1XING001`-`H1XING010` — verdict: CODE issue, **PRIORITAS 1, KONFIRMASI RUSAK DI LIVE** — RESOLVED, 18 Jul 2026

Ditemuin pas verifikasi live bug ratchet-disabled (lihat sesi ini) — `submitAttempt(true)` di
`H1XING001` sukses tapi `showResult()`/`renderReview()` MELEDAK:
```
TypeError: Cannot read properties of undefined (reading 'replace')
  at Qt._getFinalPath ... at Qt.getPublicUrl ...
  at listeningAudioUrl (index.html:4043) at renderAudioPlayer (index.html:4057)
  at buildReviewTF (index.html:4202) ... at renderReview (index.html:4981) at showResult
```
Muncul lagi pas `renderAttemptQuestion()` (bukan cuma review) kena soal `image_tf` yang sama.

**Sebab persis**: `renderImageTF()` (:4144-4153) dan `buildReviewTF()` (:4201-4217)
**UNCONDITIONAL** manggil `renderAudioPlayer(p.audio_url)` di baris PERTAMA function-nya —
nol cek apakah `p.audio_url` ada. `listeningAudioUrl()`/`listeningImageUrl()` (:4042-4047)
manggil `sb.storage.from(...).getPublicUrl(path)` — kalau `path` `undefined`, supabase-js
internal (`_getFinalPath`) coba `.replace()` di situ, throw.

**Verdict, dicek langsung ke DB (bukan tebakan)**: `question_type='image_tf'` punya **DUA
BENTUK PAYLOAD BEDA** tergantung asal datanya —
- **`h1-listening-*`/`h2-listening-*`** (20 set, 150 baris): payload `{audio_url, image_url,
  transcript}` — cocok sama yang dibutuhin `renderImageTF`/`buildReviewTF`. **Aman, nggak
  crash.**
- **`H1XING001` s/d `H1XING010`** (10 set, TEPAT 50 baris — SEMUA `image_tf` di set ini):
  payload `{choices, image_svg, statement, instruction, statement_id, instruction_id}` — **NOL
  `audio_url`, NOL `image_url`** (gambar-nya di key `image_svg`, kemungkinan inline SVG, bukan
  path Supabase Storage). Ini dataset yang lebih baru (seri mock-exam `H{level}XING{seq}`) —
  rendererernya nggak pernah di-update buat bentuk payload ini. **200 total baris `image_tf` di
  seluruh tabel = 150+50, pas — nggak ada `image_tf` di tempat lain, jadi 10 set ini scope-nya
  PERSIS dan LENGKAP, bukan sampling.**

**Ini bukan cuma "review pecah"** — `renderImageTF()` dipanggil dari `renderAttemptQuestion()`
juga (attempt LAGI JALAN, bukan cuma abis submit). Artinya siswa yang ngerjain salah satu dari
10 set `H1XING00N` ini bisa **crash pas soal-nya sendiri lagi dijawab**, bukan cuma pas liat
hasil — lebih parah dari yang kekira awalnya.

**Kenapa CODE issue, bukan data issue**: data-nya nggak "kosong"/rusak — `image_svg` ADA dan
keisi (bukan `null`), cuma field-nya beda nama dari yang dibaca renderer. Ini dua skema payload
yang legit buat 2 generasi konten beda, dan renderer cuma pernah di-tulis buat skema yang lama.

**Kenapa nggak dikerjain sekarang (revisi — dinaikin ke PRIORITAS 1, bukan lagi "kandidat
follow-up")**: perlu keputusan desain (apakah `image_tf` di seri `H*XING*` emang sengaja
audio-less + pakai `image_svg` inline sebagai standar baru, atau itu sendiri gap konten yang
belum lengkap — dua-duanya nentuin bentuk fix beda: guard-doang vs render `image_svg`
beneran). Itu masih perlu diputusin sebelum FIX ditulis — tapi urgensinya udah beda kelas dari
awal ditulis.

### KONFIRMASI RUSAK DI LIVE, 18 Jul 2026 — bukan lagi cuma teori dari test harness

**SQL Editor (Kyaru, bypass RLS)**: `H1XING001`-`H1XING010` — **`is_published=TRUE` SEMUA**,
masing-masing 5 baris `image_tf` pake `image_svg` = **50 soal rusak DI PRODUCTION**, bukan
draft/unpublished yang bisa ditunda.

**Bukti nyata bukan simulasi**: attempt beneran malem ini di `H1XING004` — console nunjukin
PERSIS error yang sama:
```
TypeError: Cannot read properties of undefined (reading 'replace')
```
di layar hasil, render Question 1 MELEDAK. Ini KEJADIAN NYATA, bukan efek RPC `400` dari fix
#43 (`is_published` gate) — jalur error yang beda sama sekali, dikonfirmasi terpisah.

**Kenapa naik ke Prioritas 1**: HSK1 = level pemula, populasi user PALING BANYAK dari 6 level.
5 dari 10 set `H1XING00N` (yang punya `image_tf`) crash di attempt ATAU review — bukan edge
case, bukan skenario aneh, ini jalur normal user paling umum ngerjain mock test HSK1. **Fix
harus ditulis SEBELUM sesi konten/fitur baru manapun** — audit desain (guard vs render
`image_svg`) masih perlu diputusin, tapi keputusan itu sendiri sekarang prioritas tinggi,
bukan nunggu antrian. **Belum ditulis kodenya — direncanain besok.**

**Line number referensi ter-update** (bergeser dari draft awal karena edit mobile fase 1 sesi
lalu): `listeningAudioUrl`/`listeningImageUrl` :4169/:4173, `renderAudioPlayer` :4183,
`renderImageTF` :4271-4280, `buildReviewTF` :4328-4344 (dipake bareng `listening_tf`+
`image_tf`). Semua 7 titik pemanggil `renderAudioPlayer`/`listeningAudioUrl` udah dipetain
lengkap di audit ini — lihat percakapan sesi buat tabel lengkapnya kalau perlu.

Diputuskan Kyaru + Claude Code, 17-18 Jul 2026.

### FIX — DONE, APPROVED, VERIFIED LIVE, 18 Jul 2026

Keputusan poin 3 (guard vs render `image_svg` beneran): **render beneran**, bukan guard-doang —
guard-doang bikin 50 soal `H1XING00N` jadi teks+True/False tanpa gambar sama sekali, padahal
`image_tf` = 看图判断对错 (soal GAMBAR) — nggak mungkin dijawab bener tanpa liat gambarnya. Itu
dianggap "rusak yang diem", lebih parah dari crash karena user cuma ngerasa bego, bukan liat
error.

**Kode, 3 titik guard + 2 titik render `image_svg`** (`index.html`):
- `listeningAudioUrl(path)`/`listeningImageUrl(path)` — `if(!path) return null;` sebelum
  `getPublicUrl`. Nutup KEDUA fungsi (bukan cuma audio kayak draft awal) — `listeningImageUrl`
  ternyata punya lubang identik, kalau cuma audio yang di-guard, crash cuma pindah baris ke
  `listeningImageUrl(p.image_url)` persis di baris berikutnya (skema baru juga NOL `image_url`).
- `renderAudioPlayer(path)` — `if(!path) return '';` — audio player disembunyiin TOTAL buat
  soal yang emang nggak ada audionya (reading section), bukan fallback player kosong.
- `renderImageTF`/`buildReviewTF` — ditambahin cabang `else if(p.image_svg){ ...div... }`,
  URUTAN `image_url` dicek DULUAN (150 baris lama nol perubahan perilaku), `image_svg` fallback
  kalau `image_url` kosong. `renderImageTF` juga dapet guard `if(p.image_url)` yang sebelumnya
  cuma ada di `buildReviewTF` (asimetri pre-existing, ketauan pas nulis fix ini).

**Verifikasi — login segar, `H1XING001`, akun `claudecodelivetest@gmail.com`, sesuai aturan #38**:
- Attempt Q21 (skema baru, `image_svg` gelas air): render bersih, nol audio player, nol console
  error.
- Submit (`submitAttempt(true)`, native `confirm()` dialog bikin CDP freeze — bukan bug, cuma
  automation quirk, dikonfirmasi via bypass) → review: **40/40 soal muncul, nggak mati di
  Question 1**. 5 soal skema baru (Q21-25: gelas air/kucing/jam/apel/buku) semua render SVG-nya.
- **Kontrol, 150 baris lama nol regresi**: Q1-4 (skema lama, `image_url`+`audio_url`) masih pakai
  `<img>`, audio player masih ada DAN **beneran bisa diputer** (dicek langsung, progress
  `0:00→0:03`, bukan cuma elemen-nya ada).
- Console bersih di setiap langkah (attempt, submit, review).
- Dark mode: Q21/Q22 SVG tetap kontras (card putih di atas background gelap), nol regresi visual.
- Mobile 390px (iframe same-origin, teknik dari HANDOFF sesi 13 karena `resize_window` inert):
  login ulang, bottom-nav → Mock Test → HSK1 → H1XING001 → Retry, Q21 render benar, submit →
  review 40/40 blocks, console bersih.

**Temuan sampingan selama verifikasi, DINAIKIN jadi #49** (bukan bagian dari fix ini): Q25
(`H1XING001`) — `statement` "他在看电视" (nonton TV) tapi `image_svg`-nya render BUKU. Bukan
render bug (kode-nya bener, nampilin apa yang ada di data) — ini **data quality issue**, di luar
batasan "jangan ubah data/payload" sesi ini. Lihat #49 buat detail lengkap + kenapa ini
PRIORITAS TINGGI, bukan cuma dicatet doang.

## 46. `attemptSubmitBtn` ratchet — disabled selamanya abis 1 submit sukses, RESOLVED

**Gejala**: klik "Retake test" abis submit sukses → tombol Submit di layar attempt pudar/nggak
bisa dipencet. Awalnya dikira bug retake-spesifik, ternyata **session-wide**: SEMUA attempt
berikutnya kena (retake ATAU fresh set dari Mock List), bukan cuma retake.

**Akar masalah**: `attemptSubmitBtn.disabled` cuma disentuh 3 tempat di seluruh file —
`= true` di awal `submitAttempt()` (:4705), `= false` di 2 cabang ERROR-nya doang
(:4736 combined, :4793 single). **Nol reset di jalur SUKSES** — begitu satu submit berhasil,
tombolnya mati permanen sampe reload halaman. Murni bug client-side, NOL hubungan ke fix
`submit_attempt` SQL malem ini (#42-45) — pola exit-point-reset ini emang udah salah dari
sebelum sesi ini mulai, ketauan sekarang cuma karena kebetulan lagi ngetes ulang jalur submit.

**Fix — DONE, entry-point reset, bukan tambahan exit-point ke-4**: `$('attemptSubmitBtn').
disabled = false;` ditambahin di AWAL `startAttempt()` (:4283-an) dan `startCombinedAttempt()`
(:4328-an) — 2 baris doang, `submitAttempt()` nol disentuh. Alasan pilih entry-point ketimbang
nambahin reset ke-4 di exit `submitAttempt()` (atau `finally` block): 2 fungsi ini KEBUKTI
(grep, bukan asumsi) satu-satunya jalur yang nampilin `attemptCard` — reset di sini otomatis
nutup SEMUA cara sebelumnya bisa gagal reset (sukses tanpa reset, error tak terduga, bahkan
crash kayak #45), tanpa perlu tau/enumerate persis kenapa state sebelumnya kotor. `finally` di
`submitAttempt()` ditolak eksplisit — kalau `submitAttempt()` crash (kayak #45), user udah
pindah ke `resultCard` (bukan `attemptCard`), jadi reset tombol Submit di sana sia-sia; entry-
point reset tetep nutup efek lanjutannya pas user Retake, `finally` enggak.

**Verifikasi — live, login segar, satu tab, NOL reload sepanjang tes** (wajib, karena bug ini
session-scoped — reload di tengah nyembunyiin gejalanya). **Catatan proses**: percobaan
pertama verifikasi ternyata nge-test kode LAMA — browser nge-cache `index.html` (server statis
lokal, nol cache-busting header), fresh reload biasa nggak narik file yang baru diedit. Ketauan
karena `startAttempt.toString()` yang lagi jalan di tab nggak ngandung kode baru sama sekali.
Dibenerin pake cache-busted URL (`?v=2`), dikonfirmasi kode baru beneran ke-load sebelum
lanjut — dicatet biar sesi depan nggak kejebak hal yang sama kalau pake pola local-server yang
sama.

Sesudah itu, urutan lengkap **5 submit berturut-turut, nol reload, HSK2 Reading**
(`H2XING002`/`H2XING003`, dipilih spesifik karena dikonfirmasi nol `image_tf` — hindarin #45):
1. `H2XING002` submit pertama → sukses (`0/100`), `resultCard` muncul.
2. Retake → `disabled:false` (BENAR, sebelumnya bakal `true`) → submit lagi → sukses.
3. Balik Mock List → `H2XING003` (set BEDA) → `disabled:false` → submit → sukses.
4. Retake `H2XING003` lagi → `disabled:false` → submit → sukses (submission ke-4 berturut,
   nol reload — buktiin ratchet-nya beneran mati, bukan cuma mundur satu langkah).
5. Ganti ke dark mode (di tengah sesi yang sama, nol reload) → Retake sekali lagi →
   `disabled:false`, dikonfirmasi VISUAL juga (tombol gold penuh, bukan `opacity:.6` pudar) →
   submit ke-5 → sukses.

Console dibaca di tiap titik (awal, abis tiap submit, abis ganti theme) — **bersih total, nol
error**, di semua 5 submission, light maupun dark.

Diputuskan + diverifikasi Kyaru + Claude Code, 17 Jul 2026.

## 47. Console error `invalid input syntax for type uuid: "null"` pas testing mobile fase 1 — REAL bug, BUKAN artefak devtools, JANGAN DIKERJAIN SEKARANG

Ketemu pas verifikasi mobile fase 1 (login screen port + label fix), sesi ini. Awalnya
dikategoriin salah — dicap "artefak test harness" (iframe di-destroy+dibikin ulang cepet)
karena reproduksi bersih di tab isolated pake klik pelan. **Koreksi Kyaru, benar**: kesimpulan
"artefak" itu cuma nutup pertanyaan "kapan ini kejadian", bukan "apa ini beneran bug".
`"invalid input syntax for type uuid"` itu error dari **Postgres sendiri** — beda kelas total
dari temuan `statusCode:503` di #42 (itu devtools salah nge-log response HEAD, request-nya
sendiri sukses, dibuktiin manggil `sb.from(...)` langsung dari console dapet `status:206`).
Kali ini: **request beneran nyampe DB bawa value yang gagal di-parse sebagai UUID** — itu
fakta, independen dari kenapa/kapan triggernya.

**Kandidat root cause, ditelusuri dari kode (bukan tebakan)**: `watchSession(userId)`
(`index.html:2594-2606`) baris 2598:
```js
filter:'id=eq.'+userId
```
**String concatenation mentah, bukan parameterized.** Kalau `userId` itu JS `null`/`undefined`
pas function ini dipanggil, hasilnya literal `"id=eq.null"` (atau `"id=eq.undefined"`) —
dikirim ke Supabase Realtime sebagai filter, diteruskan ke Postgres, ditolak `"invalid input
syntax for type uuid: null"`. **Match persis** sama pesan error yang kebukti.

**Jalur pemanggilan NORMAL — ditelusuri, kelihatannya aman**: `watchSession(userId)` cuma
dipanggil dari `loadProfile(userId)` (:2651), yang cuma dipanggil dari `doLogin()` (:2704,
`userId = data.user.id` — UUID asli dari Supabase Auth) dan `boot()` (`session.user.id` —
sama). Di jalur NORMAL, `userId` seharusnya SELALU UUID asli, nggak pernah null. Jadi bug ini
**bukan soal parameter salah di jalur biasa** — kemungkinan besar soal **race pas teardown**:
halaman/tab dihancurin di tengah rantai async (`boot()`/`loadProfile()` lagi jalan), dan
sisa promise yang masih nyambung entah gimana manggil `watchSession` dengan `userId` yang
udah nggak valid. Trigger yang kebukti kejadian (iframe test di-destroy cepet berkali-kali)
itu skenario nggak biasa buat user asli — tapi BENTUKNYA sama kayak skenario nyata: user
nutup tab / navigasi keluar di tengah proses login/boot. **Belum direproduksi di skenario user
asli** — baru kebukti di teardown paksa test harness.

**Kemungkinan nyambung**: `TypeError: Cannot read properties of null (reading
'addEventListener')` di `$('modalOverlay').addEventListener(...)` (:3503) muncul bareng di
sesi test yang sama. Beda mekanisme (DOM element nggak ketemu, bukan string filter), tapi
**kelas bug yang sama**: kode yang nganggep state/DOM tertentu udah siap, nol guard buat
kondisi "halaman lagi di-teardown/re-load di tengah jalan." Belum dikonfirmasi satu akar
sama `watchSession`, dicatet sebagai kemungkinan terkait, bukan kepastian.

**Kandidat audit** (diusulin Kyaru, cocok sama temuan): `watchSession()` (paling kuat,
match persis bentuk error), `claim_session` heartbeat (`:2657`, baca
`localStorage.getItem(SESSION_KEY)` — beda mekanisme, RPC param bukan string filter, tapi
worth dicek), jalur `localLogout()`/`forceLogout()` (:2614-2638) — nggak manggil
`watchSession` sendiri, tapi nentuin KAPAN `currentUser` di-null-in, relevan buat nyari race
window-nya.

**Kenapa nggak dikerjain sekarang**: butuh reproduksi yang lebih terkontrol (bukan cuma
iframe-destroy-berkali-kali) buat mastiin skenario user ASLI yang bisa micu ini (tab close
mid-login? navigasi cepet antar halaman? race logout+realtime callback?), sebelum nulis fix
yang bisa jadi nambal gejala yang salah. **Nggak blocking** rilis mobile fase 1 (nggak
kejadian di flow normal manapun yang udah dites), tapi harus di-treat sebagai bug beneran di
backlog, bukan "sekali muncul terus ilang."

Diputuskan Kyaru + Claude Code, 17 Jul 2026.

## 48. HSK 6 listening — verdict FINAL (a): konten LENGKAP, kerjaan = publish bukan generate, 1 blocker (bukan 2 — #45 dicoret) + bom waktu grouping title-vs-set_id — JANGAN DIKERJAIN SEKARANG

Audit diminta karena kontradiksi kelihatan: `H6XING001` combined cuma nunjukin "Reading +
Writing", padahal level lain (mis. `H4XING001`) nunjukin listening+reading+writing, dan Mock
Test History user ada baris naming lama ("H6-listening-1").

### KOREKSI — verdict awal (c) SALAH, sebab metodologi (dicatet juga di #38 poin 4)

Audit pertama dijalanin pake JWT akun test (`role='user'`, bukan admin), query `test_sets`
balikin 0 baris buat `hsk_level=6 AND section='listening'`, disimpulin "data nggak ada sama
sekali". **SALAH** — dibuktikan Kyaru lewat SQL Editor (jalan sebagai `postgres`, bypass RLS):
**data ADA — 10 baris, `set_id: h6-listening-1..10`, `title: H6XING001-010 LISTENING`,
`is_published: FALSE` SEMUA.** RLS `test_sets read published`
(`USING(is_published=true OR is_admin())`) nyaring baris unpublished dari akun non-admin —
`question_bank`-nya ikut ke-gate karena policy-nya sendiri gerbang lewat
`EXISTS(...test_sets.is_published)`. "0 rows" yang saya laporin itu bukti "nggak keliatan
buat role non-admin", bukan bukti "nggak ada di DB" — dua hal beda yang kegabung jadi
kesimpulan yang salah.

**Fakta yang SEKARANG diketahui (dari SQL Editor Kyaru, bukan REST akun test)**: 10
`test_sets` HSK6 listening ADA, `is_published=false`, **title-nya UDAH BENAR** ikut skema baru
(`H6XING00N LISTENING`) — beda dari dugaan awal kalau HSK6 "ketinggalan" total.

### VERDICT FINAL: (a) — konten LENGKAP, kerjaan = PUBLISH, bukan generate

`question_bank` dicek (Kyaru, SQL Editor): **10 set × 50 soal, tipe `listening_mc` +
`listening_mc_stmt`, cocok spec Hanban** (听力 第一部分/第二部分 HSK6). **Nol yang perlu
digenerate dari nol** — koreksi total dari dugaan awal "proyek 500 soal + audio pipeline".

**Renderer-nya JUGA udah ada** — `listening_mc_stmt` itu persis tipe yang di-render commit
`8c1da2b` ("feat: listening_mc_stmt renderer (HSK6 听力 第一部分)"), commit misterius dari sesi
CC paralel yang udah dicatet di #39 (dua sesi Claude Code kepentok nulis `index.html` yang
sama, satu sesi commit snapshot working-tree yang kecampur). Jadi: **konten ada, renderer ada
— murni soal publish.**

### #45 DICORET sebagai blocker HSK6 — audit lanjutan (18 Jul) nunjukin beda tipe soal, beda jalur render

Awalnya #45 ditulis jadi prasyarat wajib di sini. **Dikoreksi** setelah audit lengkap
(dipaginate bener, bukan kena cap 1000-row kayak insiden #41) ngecek `audio_url` per
`question_type` di SEMUA baris yang bisa dicek:

| Tipe | Total | Punya `audio_url` | Nggak punya |
|---|---|---|---|
| `listening_tf` | 200 | 200 | 0 |
| `listening_mc` | 1200 | **1200** | **0** |
| `image_mc` | 300 | 300 | 0 |
| `image_tf` | 200 | 150 | 50 (CUMA `H1XING001`-`010`, section READING, bukan listening) |

`listening_mc` — tipe yang sama yang dipake HSK6 listening — **NOL pengecualian, 1200/1200**.
#45 itu masalah SATU tipe spesifik (`image_tf`) yang punya 2 bentuk payload beda tergantung
generasi konten, kena di 10 set `H1XING00N` **section reading**, bukan listening sama sekali.
Jalur render HSK6 listening (`renderListeningMC`/`buildReviewListeningMC`) konsisten sama
1200 baris `listening_mc` lain yang kebukti nol masalah — **beda kode, beda data, beda
section dari yang #45 rusakin**.

**Blocker HSK6 listening sekarang tinggal SATU**:

1. **File MP3 di Supabase Storage** — `audio_url` di payload BENER ADA (dikonfirmasi Kyaru
   lewat SQL Editor), tapi field ada ≠ file-nya beneran ke-upload di path itu. Perlu dicek
   `getPublicUrl()` buat path-path itu beneran resolve ke file yang exist, bukan cuma string
   path yang bener bentuknya. **Belum dicek** — kandidat kerjaan besok.

**Belum dimulai apapun** — tinggal nunggu kejelasan file MP3 (poin di atas) sebelum publish.
#45 tetep PRIORITAS 1 (lihat entry #45 sendiri) tapi **independen dari HSK6 listening** — dua
antrian terpisah sekarang, bukan satu prasyarat-mengunci-yang-lain.

### BOM WAKTU tersembunyi — grouping combined jalan KARENA KEBETULAN, bukan by design

Ditemuin pas audit ini (efek samping, bukan tujuan awal): rename ke skema `H{level}XING{seq}`
**cuma pernah nyentuh kolom `title`**, nggak pernah nyentuh `set_id`. Dibuktikan langsung —
HSK4/HSK5 listening: `set_id:"h4-listening-1"` (skema lama, apa adanya) tapi
`title:"H4XING001 LISTENING"` (skema baru). Sementara `renderMockGroupedList()`
(`index.html:4125-4131`) ngelompokin combined attempt pake `getBaseCode(s.title)` —
**JUDUL, bukan `set_id`**.

**Kenapa ini bom waktu**: combined mock test (listening+reading+writing jadi satu attempt)
SEKARANG jalan bukan karena `set_id`-nya konsisten/terhubung secara struktural — jalan karena
STRING `title`-nya KEBETULAN cocok base code-nya sama section lain di level yang sama. Nggak
ada constraint/relasi DB yang jamin itu tetep gitu. **Begitu ada yang ngedit/ngerapiin title**
(typo fix, konsistensi copy, migrasi konten, dsb.) **tanpa sadar title itu juga fungsi sebagai
grouping key** — combined attempt buat level itu pecah SENYAP: listening ilang dari grup,
NOL ERROR yang keliatan (bukan crash, bukan pesan — cuma section yang tau-tau nggak nongol di
combined attempt lagi, persis kayak gejala HSK6 yang awalnya (salah) diduga soal data absen).

**HSK6 sendiri udah ikut pola yang sama** (`set_id:h6-listening-N` skema lama, `title:
H6XING00N LISTENING` skema baru) — jadi begitu di-publish nanti, combined HSK6 otomatis bakal
kegrup bareng reading/writing lewat mekanisme title yang sama persis, rapuh yang sama persis.

**Kandidat fix** (keputusan nanti, BUKAN sekarang):
- (a) Samain `set_id` listening HSK1-5 ke skema baru (`H{level}XING{seq}` konsisten sama
  reading/writing) — tapi `set_id` kemungkinan direferensiin `question_bank`/`test_attempts`
  histori lama, jadi ini migrasi data, bukan sekadar rename kolom.
  bukan cuma nyentuh `test_sets`.
- (b) Grouping pindah dari `title` ke kolom/skema khusus (mis. kolom `base_code` eksplisit di
  `test_sets`, diisi programatik bukan dari parsing string judul) — lebih aman dari perubahan
  copy di masa depan, tapi butuh schema change (kolom baru).
- (c) Minimal: dokumentasiin eksplisit di kode (`renderMockGroupedList()`) kalau `title` itu
  DUA FUNGSI SEKALIGUS (label tampilan DAN grouping key) — biar sesi depan yang mau "rapiin
  copy judul" nggak nyentuh ini tanpa sadar. Ini paling murah, bisa jadi mitigasi sementara
  sambil (a)/(b) belum diputusin, tapi TETEP nggak dikerjain sesi ini per instruksi eksplisit.

**Kenapa nggak dikerjain sekarang**: audit doang yang diminta, keputusan desain (a) vs (b)
vs (c) belum diambil, dan (a)/(b) dua-duanya nyentuh area yang lebih luas dari scope HSK6
listening yang lagi diaudit.

Diputuskan Kyaru + Claude Code, 17 Jul 2026.

### UPDATE 18 Jul 2026 — blocker file MP3 LUNAS, `H6XING001` LISTENING udah di-flip published

**Blocker (poin 1, file MP3 beneran ke-upload) — VERIFIED LUNAS**: 10 path (`p1q1-5`.mp3 +
`p2q1-5`.mp3 dari `h6-listening-1`) dicek satu-satu via HTTP HEAD ke Storage public URL — 10/10
`200`, `Content-Type: audio/mpeg`, ukuran file beda-beda (94-141KB, bukan halaman-error
seragam), `ETag`/`Last-Modified` nyata. Bukan cuma pola nama path yang bener — filenya
BENERAN ada.

**`H6XING001` LISTENING sekarang `is_published=true`** (50 soal) — beda dari status pas audit
ini ditulis (`is_published=false`). **INI RISIKO NYATA, bukan status netral**: 15 dari 50 soal
di set ini adalah `listening_mc_stmt` — tipe yang renderer-nya ADA (lolos gerbang #55) tapi
**NOL JAM TERBANG** terhadap data real sejak `8c1da2b` nulis renderernya (dulu selalu
`is_published=false` di semua 10 set `h6-listening-N`, sampe entry ini di-update). Live sekarang
TAPI BELUM PERNAH DITES manual. **WAJIB jadi item pertama sesi berikutnya** (lihat HANDOFF.md
antrian #1) — kerjain soal 1-15 (`listening_mc_stmt`) di `H6XING001` dulu sebelum flip 9 set
sisa (`h6-listening-2` s/d `-10`). Kalau mulus → lanjut flip sisanya. Kalau rusak → STOP, cuma
1 set yang kena, belum nyebar.

Diputuskan Kyaru + Claude Code, 18 Jul 2026.

## 49. `image_tf` skema baru (10 set `H1XING001`-`H1XING010`) — SVG salah sama statement-nya — AUDITED, **FALSE ALARM**, 18 Jul 2026

Ketemu SAMPINGAN pas verifikasi fix #45 (render crash) — Question 25 (`H1XING001`, `image_tf`
skema baru): `statement` = "他在看电视" ("Dia sedang nonton TV"), tapi `image_svg`-nya render
gambar **buku**, bukan TV. Diverifikasi visual langsung di browser (screenshot), bukan tebakan
dari baca data mentah.

**Kenapa ini bukan cosmetic**: `image_tf` = 看图判断对错 ("lihat gambar, tentukan benar/salah") —
gambar ITU SENDIRI bagian dari soal, bukan dekorasi. Kalau `image_svg` nggak cocok sama
`statement`, kunci jawaban yang "benar" secara logis (gambar vs pernyataan) jadi nggak jelas
mana yang dianggap sumber kebenaran sama grader — siswa yang jawab sesuai apa yang dia LIAT
(buku) bisa aja disalahin kalau `answer` di DB ngikut asumsi `statement` (TV), atau sebaliknya.
**Belum dicek `answer` field-nya buat soal ini** — baru ketauan gambar-nya salah, belum
ditelusurin dampak ke kunci jawaban.

**Kenapa dicurigai POLA, bukan 1 soal doang**: kecurigaan awal (belum diverifikasi) — kemungkinan
ada script/lib generate (`svg_lib.py` atau semacamnya, disebut user, belum dikonfirmasi
namanya persis) yang matching SVG ke statement secara programatik/otomatis, dan matching-nya
bisa salah di lebih dari satu tempat. Scope potensial: **50 soal `image_tf` skema baru, 10 set,
SEMUA `is_published=TRUE`, semua HSK 1** — level pemula, populasi user terbesar dari 6 level
(sama alasan #45 dinaikin ke Prioritas 1).

**Preseden linguistik dari sesi audit HSK6 listening (#48)**: "jumlah soal bener ≠ format bener"
(jumlah baris cocok bukan bukti kontennya lengkap/benar). Temuan ini versi ketiga dari pola yang
sama: **"render bener ≠ isi bener"** — #45 buktiin renderer-nya sekarang jalan tanpa crash, tapi
itu nggak otomatis berarti apa yang dirender itu KONTEN YANG BENAR. Dua lapis masalah berbeda,
dua fix berbeda, jangan dianggap kelar cuma karena satu udah RESOLVED.

**JANGAN DIKERJAIN SEKARANG** — butuh audit sesi terpisah:
1. Cek seluruh 50 baris `image_tf` skema baru (10 set): `statement` vs `image_svg` vs `answer`,
   satu-satu, bukan sampling — buktiin ini pola atau cuma Q25 yang kena.
2. Kalau pola konfirmed: telusurin sumber generatornya (kalau ada script terpisah kayak
   `svg_lib.py`) buat ngerti KENAPA matching-nya salah, sebelum mutusin fix-nya regenerate vs
   perbaikan manual per-baris.
3. Ini masalah DATA, bukan kode — beda kelas dari #45 (yang itu genuinely kode belum di-update
   buat skema baru). Jangan campur perbaikannya jadi satu sesi/commit sama fix kode manapun.

Diputuskan Kyaru + Claude Code, 18 Jul 2026.

### AUDIT HASIL — FALSE ALARM, ditutup 18 Jul 2026

Audit penuh 50/50 baris (query lewat `SUPABASE_KEY` service_role, bukan RLS-terbatas), pakai
`<title>` di dalam `image_svg` sebagai identitas objek. Hasil: **nol pengecualian di 50 baris**
— kalau `svg_title` cocok makna sama `statement` → `answer` SELALU "A" (对/Benar). Kalau nggak
cocok → `answer` SELALU "B" (错/Salah). Distribusi 30 True / 20 False (60/40), nggak degenerate.

Q25 sendiri (svg=buku, statement="nonton TV", awalnya dicurigai): `answer.correct = "B"` (错) —
**BENAR secara desain**. Gambar sengaja nggak cocok, jawaban yang benar memang "Salah", user
yang jawab "Salah" dapet nilai bener.

**Verdict: (a) — fitur yang salah dibaca, bukan bug.** `image_tf` = 看图判断对错 — mekanismenya
MEMANG butuh sebagian soal punya gambar yang sengaja nggak cocok, biar user harus bisa DETEKSI
ketidakcocokan (kalau semua gambar cocok, jawabannya selalu "Benar" dan soal jadi percuma).
Kesalahan sesi lalu: liat Q25 mismatch, langsung asumsi data rusak, tanpa cek `answer` field
dulu buat lihat apakah mismatch itu bagian dari desain soal.

**`svg_lib.py`**: dicek 3 cara (file search, grep semua `.py` di repo, `git log --all` di semua
commit/branch) — **nol jejak, di mana pun, kapan pun**. Kalau script generatornya beneran
pernah ada, dia hidup di luar repo ini. Dicatet sebagai temuan sendiri, bukan diselidiki lebih
lanjut (di luar scope).

**Status**: ditutup sebagai false alarm, entry **DIBIARIN** (tidak dihapus) biar nggak
dicurigain ulang tanpa alasan kalau ada yang nemu pola serupa nanti — tinggal rujuk ke sini.

Diputuskan Kyaru + Claude Code, 18 Jul 2026.

## 50. `image_match` (看图选择) — NOL RENDERER, 100 soal LIVE PUBLISHED, HSK1+HSK2 — RESOLVED, 18 Jul 2026

Ditemuin lewat laporan langsung: `H1XING001` Reading Q6-10 cuma nampilin instruksi "看图选择"
terus KOSONG — nol gambar, nol pilihan jawaban, soal nggak bisa dijawab. Awalnya dikira sodara
#45 (renderer `image_mc` kelewat cabang `image_svg`) — **SALAH, beda kelas masalah**.

**Root cause**: `question_type` soal ini `image_match`, BUKAN `image_mc`. Payload-nya:
```json
{
  "prompt": "我很喜欢这只小猫。", "prompt_id": "...",
  "instruction": "看图选择", "instruction_id": "...",
  "image_choices": [
    {"key":"A","svg":"<svg...><title>buku</title>...</svg>"},
    {"key":"B","svg":"..."}, {"key":"C","svg":"..."},
    {"key":"D","svg":"..."}, {"key":"E","svg":"..."}
  ]
}
```
`grep "image_match"` di seluruh `index.html` → **0 hasil**. Bukan payload-shape-mismatch di
renderer yang udah ada (kelas #45) — **function-nya sendiri nggak pernah ditulis**, di attempt
dispatcher (`renderAttemptQuestion()`, if/else-chain :4578-4627) maupun review dispatcher
(`buildReviewHTML()`, :5156-5184). `qInstruction` (baris 4576) render UNCONDITIONAL sebelum
chain-nya, itu sumber "看图选择" yang tetep nongol — abis itu nggak ada cabang yang match, `html`
berenti di situ. **Nol crash** (nggak ada kode yang jalan buat nyoba baca field yang nggak ada,
beda dari #45 yang genuinely throw) — cuma diem-diem kosong.

**Blast radius, full sweep DB (5175 baris, paginated bener)**: **100 baris**, bukan 50 kayak
laporan awal — `H1XING001`-`010` (HSK1, 50) **DAN** `H2XING001`-`010` (HSK2, 50), **20 set,
SEMUA `is_published=true`, SEMUA reading section**. HSK1+HSK2 = dua level pemula terbesar.

**Dampak nilai**: tiap set Reading HSK1/2 = 20 soal, 5 di antaranya (`image_match`) otomatis
nggak kejawab (nol pilihan buat diklik) → **user Reading HSK1/HSK2 mentok maksimal 15/20
SELAMANYA**, diem-diem, nol pesan error yang bilang kenapa. Ini integritas nilai, bukan cosmetic
— beda dari #45 (yang crash, keliatan) ini malah senyap, mungkin lebih parah karena user nggak
tau ada yang salah.

### Investigasi pre-implementasi (audit, nol kode ditulis)

**Soal 1 — bank gambar shared, dikonfirmasi 100%**: dicek program-matically, ke-20 set, **5 baris
`image_match` per set punya `image_choices` yang PERSIS IDENTIK** (bukan sampling — literal
string comparison tiap baris). Dan tiap gambar (A-E) dipakai sebagai jawaban benar TEPAT SEKALI
per set (`sorted(answers) == ['A','B','C','D','E']`, semua 20 set match) — ini **format asli
Hanban 看图选择 HSK1/2**: satu bank 5 gambar, 5 kalimat, pemetaan bijektif.

**Rekomendasi UX — JANGAN bikin "render sekali, dipakai bareng"**: dicek preseden yang UDAH ADA
di app — `reading_mc` (mis. `H6XING003` order_index 42 & 43) juga punya passage yang IDENTIK
diulang di 2+ baris soal beruntun, dan app SEKARANG render passage itu ULANG di tiap soal (nol
dedup, nol mekanisme "shared block"). Arsitektur `renderAttemptQuestion()` emang satu-soal-
sekali-render, konsisten di semua 12 tipe yang udah ada. Bikin UI "bank gambar tampil sekali
buat 5 soal" bakal jadi pola arsitektur baru yang nggak ada preseden-nya — rekomendasi: **ikutin
pola existing, render 5-gambar bank itu ULANG di tiap 5 soal** (sama kayak reading_mc ngulang
passage), bukan restrukturisasi ke grouped-view.

**Soal 2 — reuse `.imageChoiceItem`, YA, styling zero-baru**: `.imageChoiceItem`/`.imageChoiceList`
(dipake `image_mc` via `renderImageOptions()`) itu modifier di atas `.choiceItem`/`.choiceList`
based (:881-887, base button/active-state generik dipakai 4+ renderer lain) — struktur visualnya
(grid tile gambar, klik buat pilih, state aktif) PERSIS sama kebutuhan `image_match`. Beda cuma
konten: `image_mc` pake `<img src="...">` (Storage path), `image_match` butuh svg inline
(`<div class="imageChoiceImg">{svg}</div>`, sama pola kayak fix #45's `.listeningImageWrap`).
**Satu potensi CSS tweak** (bukan CSS baru, penyesuaian): `.imageChoiceImg` sekarang nge-style
tag `<img>` langsung (`width:100%; max-width:140px`) — kalau dipasang di `<div>` pembungkus svg,
mungkin butuh baris tambahan `.imageChoiceImg svg{width:100%;height:auto;display:block}` biar
svg-nya ngisi kotak yang sama persis kayak `<img>` biasanya ngisi. Rekomendasi: function baru
`renderImageMatchOptions()`/`buildReviewImageMatchChoices()` (sibling dari
`renderImageOptions()`/`buildReviewImageChoices()`, bukan nulis ulang yang lama) — array-based
(`image_choices`) bukan dict-based (`image_options`), tapi reuse class CSS yang sama persis.

**Soal 3 — review screen**: `p.prompt`/`p.prompt_id` itu field yang SAMA persis kayak yang udah
dipake `sentence_match` (baris 4592-4595 attempt, 5168-5171 review) — reuse pola stem itu apa
adanya, bukan nemuin field baru. Buat pilihan jawaban, `buildReviewImageChoices()` (:4363-4378,
dict-based, `image_mc`) punya pola marking `isCorrect`/`isWrongPick` yang persis bisa
di-adaptasi ke versi array-based buat `image_choices` — logic markingnya identik, cuma sumber
datanya beda bentuk (array vs dict).

**Soal 4 — `sentence_cloze`/`word_cloze` — DICATET, JANGAN DIKERJAIN**: ikut kena penyakit yang
sama (nol renderer, grep 0 hasil di dispatcher), tapi keduanya cuma ada di `hsk6-reading-1`
(judul `H6XING001 READING`), **`is_published=false`** — bom waktu dorman, bukan bug live. Udah
jadi bagian dari blocker publish `hsk6-reading-1` yang dicatet #48 (HSK6 listening/reading belum
di-publish) — nambah 2 item baru ke list blocker itu, bukan kerjaan terpisah. **Nggak disentuh
sesi ini.**

**Belum diimplementasi apapun** — ini laporan rencana, nunggu approve buat mulai nulis kode.

Diputuskan Kyaru + Claude Code, 18 Jul 2026.

## 51. POLA — konten generate duluan, renderer ketinggalan, 4x kejadian — bukan 4 bug, 1 penyakit

Kejadian yang sama, 4 kali, beda tipe soal tiap kali:
1. **HSK6 listening** (#48) — konten `listening_mc` lengkap, renderer-nya (`8c1da2b`) sempet
   ketunda ke-publish gara-gara commit nyampur (#39), bukan renderer-nya sendiri yang kurang.
2. **`image_tf` + `image_svg`** (#45) — renderer ADA tapi ditulis buat skema lama doang
   (`audio_url`/`image_url`), skema baru (`image_svg`) nggak pernah di-tambahin pas konten baru
   itu di-generate.
3. **`image_match`** (#50) — konten di-generate LENGKAP (100 baris, 20 set, published), renderer
   buat tipe ini **nggak pernah ditulis sama sekali**.
4. **`sentence_cloze`/`word_cloze`** (ditemuin dalam audit #50) — sama kayak #3, konten ada
   (`hsk6-reading-1`), renderer nol — untungnya masih `is_published=false`, ketauan sebelum
   sempet live.

**Ini bukan 4 bug independen** — polanya konsisten: proses generate konten (entah manual, AI-
assisted, atau script) jalan LEBIH DULU dan LEBIH CEPAT dari proses nulis/update renderer di
`index.html`. Setiap kali tipe soal baru (atau skema payload baru buat tipe lama) di-generate,
ada jeda sebelum renderer-nya nyusul — dan kalau konten itu ke-publish di jeda itu, hasilnya
soal yang nggak bisa dijawab (kelas #45/#50) atau bahkan crash (kelas #45 sebelum di-fix).

**Aturan baru, berlaku semua sesi ke depan**: **sebelum publish set/konten apapun** (`UPDATE
test_sets SET is_published=true` atau setara), **WAJIB cek**:
1. `question_type` di baris-baris yang mau di-publish ada di dispatcher (`renderAttemptQuestion`
   DAN `buildReviewHTML`) — grep nama tipe-nya, pastiin ada cabang yang match.
2. Kalau tipe-nya udah punya cabang, cek juga BENTUK payload-nya (field apa yang ADA) cocok sama
   yang dibaca renderer-nya — skema lama vs baru (kelas #45) nggak selalu ketauan dari sekadar
   "tipe udah ada".

Ini melengkapi 2 aturan verifikasi yang udah ada (#38: "syntax check ≠ verifikasi",
"jumlah soal bener ≠ format bener") — versi keempat dari keluarga aturan yang sama:
**"konten ada ≠ konten bisa dirender"**.

Diputuskan Kyaru + Claude Code, 18 Jul 2026.

### FIX — DONE, APPROVED, VERIFIED, 18 Jul 2026

Implementasi persis sesuai rencana yang di-approve (poin 1-4 di atas), 5 titik di `index.html`:
`renderImageMatchOptions()` (sibling `renderImageOptions()`, array-based `image_choices`, emit
`class="choiceItem imageChoiceItem"` + `data-key` — delegated click handler yang udah ada
`(~line 5339)` nangkep otomatis, NOL JS wiring baru), `buildReviewImageMatchChoices()` (sibling
`buildReviewImageChoices()`, marking `isCorrect`/`isWrongPick` sama persis), 2 cabang dispatcher
baru (`renderAttemptQuestion()` + `buildReviewHTML()`, pola `sentence_match` — `p.prompt`/
`p.prompt_id`), 1 baris CSS (`.imageChoiceImg svg{width:100%;height:auto;display:block}`).
**NOL perubahan SQL, NOL write ke Supabase** — sesuai batasan.

**Acceptance test — 4 poin, dijalanin Claude Code, hasil per-soal (bukan angka agregat doang)**:
- **Test A** (`H1XING001`, 20/20 benar): hasil 15/20. **Root-caused per soal**: Q1-5 (`image_tf`)
  SEMUA "Incorrect" (bug lain, lihat #52 — BUKAN #50), Q6-10 (`image_match`, ini fix-nya) SEMUA
  "Correct", Q11-20 SEMUA "Correct" (pre-existing, nol regresi). **#50 sendiri 5/5 benar** —
  15/20 itu sinyal ada masalah LAIN nutupin hasil #50, bukan #50 gagal.
- **Test B** (1 salah sengaja di `image_match`): pilihan salah (A) merah + label "Your answer",
  jawaban benar (E) ijo + label "Correct answer" — persis diminta, dikonfirmasi screenshot.
- **Test C** (console): bersih di semua run, nol error/exception.
- **Test D** (`H2XING001`, sanity beda set): render RUSAK — nemuin #53 (SVG smart-quote
  corruption, bug data terpisah). **Dikonfirmasi bukan kode #50**: `H2XING002` (bersih per scan
  #53) render sempurna, grid rapi, 5 gambar utuh.

**Verdict**: #50 verified benar secara independen (granular per-soal), 2 bug baru ketemu
SAMPINGAN lewat acceptance test yang jalan sungguhan (terutama Test D) — dicatet terpisah di
#52/#53, DILUAR scope commit #50.

Diputuskan Kyaru + Claude Code, 18 Jul 2026.

## 52. `image_tf` scoring — boolean vs string mismatch, 50 baris `H1XING001`-`010` — RESOLVED, 18 Jul 2026

Ketemu SAMPINGAN pas acceptance test #50 (Test A) — Q1-5 (`image_tf`, `H1XING001`) SEMUA
"Incorrect" walau jawaban yang diklik genuinely benar (dicek manual, gambar cocok statement).

**Root cause**: `renderTFButtons()` (dipake `listening_tf` + `image_tf`) SELALU ngirim jawaban
sebagai **boolean** — `attemptAnswers[q.id] = { correct: tfEl.dataset.value === 'true' }`
(`index.html` ~5335). Tapi kolom `answer` di DB buat 50 baris skema baru `image_tf`
(`H1XING001`-`010`, sama scope #45) isinya **STRING** — `{"correct": "A"}`/`{"correct": "B"}`,
bukan `{"correct": true}`/`{"correct": false}`. `submit_attempt`'s `v_ok := v_user_ans =
r.answer` — JSONB `{"correct":true}` vs `{"correct":"A"}` **TIDAK PERNAH equal**, apapun yang
diklik user. Review-nya juga ikut kena: `buildReviewTF()`'s `typeof correctAns?.correct ===
'boolean' ? ... : '-'` nampilin dash karena "A" bukan boolean.

**Beda dari #45**: #45 fix CRASH-nya (render), sukses — tapi verifikasi #45 cuma ngecek
"nggak crash", nggak pernah ngecek "jawaban bener kehitung bener". Ini lapisan MASALAH BEDA di
data yang SAMA (50 baris `H1XING00N` skema baru) — render sekarang bener, SCORING-nya yang
salah.

**Dampak**: SEMUA 50 soal `image_tf` skema baru nggak bisa dijawab bener SAMA SEKALI, apapun
yang diklik user — permanen "Incorrect", sama kelas dampak kayak #50 (integritas nilai) tapi
mekanismenya beda (tipe data salah, bukan renderer nggak ada).

**FIX — DONE by Kyaru via SQL, VERIFIED, 18 Jul 2026**: DB disamain ke boolean (bukan frontend
ke string) — keputusan Kyaru based on payload `choices` sendiri (对=A=`true`, 错=B=`false`,
mapping yang sama yang `renderTFButtons()` udah pakai dari awal). Ke-50 baris `image_tf` skema
baru di-update: `{"correct":"A"}`→`{"correct":true}`, `{"correct":"B"}`→`{"correct":false}`.
**Verified**: query ulang 200 baris `image_tf` total (150 lama + 50 baru), SEMUA `answer.correct`
sekarang boolean, nol baris string tersisa. **Acceptance test #50 (live, 18 Jul)** re-run
`H1XING001` full 20/20 — Q1-5 (`image_tf`) yang kemarin merah semua sekarang ijo semua,
bukti nyata bukan cuma query check.

Diputuskan Kyaru + Claude Code, 18 Jul 2026.

## 53. SVG smart-quote corruption — 24 baris (`image_match` + `image_tf`), 5 set — RESOLVED, 18 Jul 2026

Ketemu SAMPINGAN pas acceptance test #50 (Test D, sanity check `H2XING001`) — render RUSAK
TOTAL: layout numpuk vertikal, 4 dari 5 gambar kosong. Investigasi DOM: satu `<button>` nyerap
teks "ABCDE" gabung jadi satu, 4 elemen `<svg>` lain jadi sibling lepas di luar button (HTML
parser gagal, bukan kode salah).

**Root cause, dikonfirmasi di raw data**: attribute SVG-nya pakai **smart/curly quote**
(`"`/`"`, U+201C/U+201D) bukan straight quote ASCII (`"`) — `role=\"img"` (curly di akhir),
bukan `role=\"img\"`. Browser HTML parser nyari straight-quote penutup buat attribute value,
ketemu curly quote yang nggak match → attribute value "bocor" ke karakter berikutnya → seluruh
struktur elemen korup. Kemungkinan besar dari proses generate konten yang lewatin
"smart quotes" auto-convert (word processor atau text pipeline), ngerusak sebagian batch doang.

**Scope, full scan (bukan sampling)**:
- `image_match` (`image_choices[].svg`): **20/100 baris kena** — `H1XING007`(5), `H1XING008`(5),
  `H1XING009`(5), `H2XING001`(5).
- `image_tf` (`image_svg`): **4/200 baris kena** — 1 baris masing-masing di `H1XING006`/`007`/
  `008`/`010`.

**Dikonfirmasi BUKAN bug kode**: `H2XING002` (bersih per scan) render sempurna — grid rapi, 5
gambar utuh, sama function (`renderImageMatchOptions()`) yang dipake `H2XING001` yang rusak.

**Query buat verifikasi/fix (Kyaru, SQL Editor)** — cari baris yang kena:
```sql
select set_id, order_index, question_type
from question_bank
where question_type in ('image_match','image_tf')
  and (
    payload::text like '%' || chr(8220) || '%' or
    payload::text like '%' || chr(8221) || '%'
  );
```

**FIX — DONE by Kyaru via SQL, VERIFIED 0/0 tersisa, 18 Jul 2026**: dibenerin pake **`translate()`
karakter langsung** (`chr(8220)`/`chr(8221)` → `"` ASCII), **BUKAN regex posisi-atribut**.

**Jebakan metodologi ketemu di tengah jalan (contoh nyata #38 lagi)**: percobaan pertama pake
regex yang nyari pola posisi spesifik (attribute value diapit quote) buat locate-and-replace —
balikin **NOL baris kena**, padahal baris yang korup jelas ADA (udah dibuktiin visual di
`H2XING001` sebelumnya). Regex posisi-nya salah asumsi bentuk string persis, jadi false negative
— kalau berhenti di situ, kesimpulannya "nggak ada yang perlu difix" itu SALAH TOTAL. Ganti
pendekatan ke `translate()` karakter-demi-karakter (nggak peduli posisi, langsung tukar tiap
kemunculan `"`/`"` di manapun) — baru ketemu match yang bener, 24 baris. **Pelajaran sama persis
#38**: hasil query/tool BUKAN otomatis bukti kebenaran — kalau hasilnya "nol" padahal ada bukti
visual/independen yang bilang sebaliknya, curigain METODE-nya duluan, bukan langsung percaya
angka nol itu.

**Verifikasi**: query ulang pola `chr(8220)`/`chr(8221)` di `image_match`+`image_tf` payload →
**0/0** tersisa. **Acceptance test #50 (live, 18 Jul)** re-run `H1XING007` (5 baris image_match
kena) dan `H2XING001` (yang tadinya rusak total, numpuk vertikal) — dua-duanya render grid rapi
5-gambar-utuh sekarang, screenshot dikonfirmasi.

Diputuskan Kyaru + Claude Code, 18 Jul 2026.

## 54. `ordering` (330 baris HSK4) — DIAUDIT, SEHAT, bukan bug

Diminta audit spesifik karena kelas masalah yang sama (#50/#52) udah 2x kejadian di tipe soal
lain — perlu mastiin `ordering` nggak ikut kena sebelum dianggap aman. **Catatan penomoran**:
sempet disebut informal "#52" pas diminta (sebelum #52 formal di file ini kepake buat
`image_tf` scoring) — entry resminya jadi #54 di sini, biar nggak nabrak nomor yang udah ada.

**Renderer**: `renderSegmentList()` (:4693-4707), dipanggil dari `ordering` branch di
`renderAttemptQuestion()`. Klik ditangani **handler sendiri** (delegated click, :5392-5402,
keyed ke `.segmentItem` — CSS class beda, bukan `.choiceItem` yang dipake tipe lain), push/splice
key ke array `attemptAnswers[q.id].order` sesuai urutan klik user.

**Shape dikonfirmasi COCOK ke DB** (sample nyata `H4XING011` #11/#12: `answer:{"order":
["B","A","C"]}`) — key `"order"`, array of string, urutan array = urutan user nyusun (bukan
sorted/alphabetical). `submit_attempt`'s `v_ok := v_user_ans = r.answer` (JSONB equality
penuh termasuk urutan elemen) otomatis bener buat bentuk ini — nol perubahan RPC diperlukan.

**Review ADA cabangnya**: `buildReviewOrdering()` (:5269-5288) — describe urutan user vs benar
(hanzi+pinyin+terjemahan), tandain "Correct order" cuma kalau mismatch.

**Acceptance test #50's Test D (live, 18 Jul)** — `H4XING001`, blok penuh 10 soal `ordering`
(order_index 10-19) dijawab manual (klik sesuai urutan semantik kalimat), submit: **10/10
Correct**, review nampilin kalimat lengkap tersusun + "Urutan benar: X → Y → Z" match persis
klik. **Nutup audit ini dengan bukti data nyata, bukan cuma baca kode.**

**Verdict: SEHAT, nol tindakan lanjut.** 330 baris `ordering` published aman dari kelas bug
#50/#52.

Diputuskan Kyaru + Claude Code, 18 Jul 2026.

## 55. Gerbang pre-publish (#51 diformalkan) — WAJIB run sebelum tiap publish, TAPI ada blind spot

`#51` udah nyaranin aturan "cek dispatcher kenal tipe sebelum publish" — entry ini formalisasi
konkretnya, plus satu batasan penting yang ketauan hari ini.

**Gerbang**: sebelum publish set/konten apapun, jalanin — semua `question_type` di baris yang
mau di-publish, dikurangi daftar putih tipe yang punya cabang di **KEDUA** dispatcher
(`renderAttemptQuestion()` DAN `buildReviewHTML()`). Selisihnya harus KOSONG. Kalau nggak
kosong = ada tipe yang bakal render blank/rusak begitu di-publish (kelas #50).

Daftar putih saat ini (12 tipe): `char_input`, `error_sentence`, `essay`, `fill_blank`,
`image_match`, `image_mc`, `image_tf`, `listening_mc`, `listening_mc_stmt`, `listening_tf`,
`ordering`, `reading_mc`, `sentence_match`. **WAJIB di-update tiap renderer baru landing** —
daftar ini bukan statis.

**BATASAN, dicatet eksplisit biar nggak overconfidence**: gerbang ini **CUMA nangkep renderer
YANG NGGAK ADA SAMA SEKALI**. Dia **BUTA** sama kasus `listening_mc_stmt` — renderer-nya ADA
(masuk daftar putih, lolos gerbang), tapi **NOL JAM TERBANG** terhadap data nyata (150 baris,
10 set, semua `is_published=false` sampai hari ini — lihat #48). Renderer yang "ada di kode"
dan renderer yang "kebukti jalan pake data real" itu dua klaim beda — gerbang ini cuma
mem-verifikasi klaim pertama. **Konsekuensi**: begitu `H6XING001` (atau set `h6-listening-N`
manapun) di-flip `is_published=true`, itu jadi kali PERTAMA `listening_mc_stmt` kena traffic
nyata sejak renderer-nya ditulis — WAJIB dites manual (bukan cuma lolos gerbang) sebelum
dianggap aman. Lihat antrian di HANDOFF.md buat urutan tes-nya.

Diputuskan Kyaru + Claude Code, 18 Jul 2026.

## 56. Konvensi `reading_mc` dipakai sebagai wadah TF-teks (判断对错), `image_tf` cuma buat TF-bergambar — SENGAJA, JANGAN migrasi

Dicatet Kyaru (bukan temuan audit) — HSK2 reading Part 3: soal 判断对错 (benar/salah) **tanpa
gambar** dibangun pakai `question_type='reading_mc'` (2 pilihan tetap 对/错, `choices[].hanzi`),
BUKAN `image_tf`. `image_tf` khusus dipakai buat 看图判断对错 (TF **dengan** gambar). Ini konvensi
konten yang disengaja, **70 soal konsisten**, bukan salah kategorisasi.

**Konsekuensi buat sesi depan**: statistik/analitik/filter "by `question_type`" bakal ngitung
TF-teks ini sebagai `reading_mc` biasa (soal pilihan ganda), BUKAN sebagai TF, walau secara UX
tampilannya 2-tombol 对/错 sama persis kayak `image_tf`/`listening_tf`. Kalau nanti ada kerjaan
yang butuh "semua soal TF" (bukan "semua soal reading_mc"), filter `question_type='image_tf' OR
question_type='listening_tf'` **BAKAL NGELEWATIN 70 soal ini** — filter yang bener butuh cek pola
`choices` (2 pilihan, `hanzi` isinya persis 对/错) di dalam `reading_mc`, bukan cuma nama tipe.

**JANGAN migrasi ke `image_tf`/tipe baru** — 70 soal ini jalan sempurna lewat `renderChoiceList()`
(dispatcher `reading_mc` yang udah ada), nol bug, nol renderer gap. Migrasi cuma bakal nambah
resiko (kelas #45/#50) buat nutup gap yang sebenernya nggak ada gap fungsional — cuma gap
semantik di NAMA tipe, yang udah didokumentasiin di sini biar nggak ke-anggep bug lagi.

Dicatet Kyaru, 19 Jul 2026.

Nothing else pending a decision right now.
