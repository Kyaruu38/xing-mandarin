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

## 10. HSK 3.0 rollout (July 2026) — out of scope, strategic risk only, user will verify

Not a restyle task, not something to act on. Noting for awareness: HSK 3.0 is scheduled for
full worldwide implementation this month (July 2026) — syllabus released 2025-11-15, took
effect 2025-11-18, global trial ran 2026-01-31. Changes: 9 levels instead of 6, beginner/
intermediate vocabulary lowered, speaking becomes mandatory from level 3 onward. This
platform is built on HSK 2.0 (6 levels, 4,991-word vocab list, matching the level/vocab
structure `vocab.meaning_id` and the level-picker UI already assume throughout the app).

**Not something to implement or plan around right now** — user will verify against primary
sources separately. Recorded here only so it's on record as a known structural risk to the
platform's core level model, should it come up later.

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

Nothing else pending a decision right now.
