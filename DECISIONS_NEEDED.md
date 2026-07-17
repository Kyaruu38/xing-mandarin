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

## 8. Mock test navigator legend "Flagged" — dead state, same class as #6 — OPEN, product decision

Ported the 4-swatch legend (Answered/Current/Flagged/Empty) verbatim from `.dc.html`'s
`isTest` block (literal colors from the `tile()` helper, lines 380-393) as part of the mock
test attempt chrome pass. The app has **no flag-a-question feature** — no click/long-press
handler anywhere sets a `.gridBtn.flagged` state, and source itself doesn't show how one
would flag a question either (the `qNav` demo array just hardcodes 2 of 95 cells as
`'flagged'` for the screenshot, no real interaction exists in source). Result: the legend
permanently advertises a color that can never appear. Same category of issue as #6 (dead
speaker button) — a visible affordance/explanation for something inert.

Options for user to decide, not to be implemented without sign-off:
- **(a)** Hide the "Flagged" legend entry until a real flag feature exists
- **(b)** Build the feature — some way to flag a question (right-click / long-press on a
  grid cell), source gives no interaction spec for this, would need its own design decision
- **(c)** Leave it as-is (harmless, just permanently unused)

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

Diputuskan Kyaru + Claude Code, 17 Jul 2026.

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

Nothing else pending a decision right now.
