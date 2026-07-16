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

## Remaining session order: ~~result~~ → materials → #12 → dark mode (fixed order, don't reshuffle)

Result screen is DONE (this session, see top section — with the 2 CODE COMPLETE/UNVERIFIED
branches noted there, not blockers). **#12 (`.choiceItem`/`.segmentItem` → real `<button>`) must
land BEFORE the dark mode sweep, not after.** That conversion adds new `button{}`-leak CSS resets
(`margin-top`, `padding`, `width`, `background`) on classes the dark-mode pass would otherwise
need to re-check. Doing dark mode first means redoing it once #12 lands. Dark mode is last on
purpose — only make that sweep once all markup for a screen is final.

## Next session: MATERIALS ONLY — do not pair with anything

Source comp: `06-materials.png`. Solo scope, same as every session in this sequence — don't fold
in #12 or dark mode.

**Relevant open item from this session**: DECISIONS_NEEDED #19 found that `closeBrowse()` (the
exit function for the Materials/`browseCard` screen) hides only `browseCard` and shows
`dashCard`, without a `hideAllPages()` safety net — same shape as the `#resultCard` leak this
session caught and fixed in `navTo(goBerandaContent)`. Currently unreachable as a live bug
(traced every entry point), but if this session's port adds any *new* way to leave `browseCard`
(a new button, a filter-chip that also exits, etc.), re-verify that assumption before assuming
`hideAllPages()` isn't needed — don't just carry the "it's fine, I checked once" conclusion
forward without re-checking against the new code.

Budget this screen alone.
