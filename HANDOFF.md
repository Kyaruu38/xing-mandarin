# Handoff — session 2 (continuation after /clear)

Scope for this session was capped at 4 items by explicit instruction (context-budget pacing: ~2 screens per session, then `/clear`). All done, verified in-browser with screenshots, committed. Stopping here as instructed.

## Flashcard + fix drift: DONE — `e40aaf1`

Follow-up round after pixel-level screenshot review surfaced 2 more drift items on top of `883a252`. Both fixed, verified in-browser (wrapper-white gone, sparkle visible, "Show answer" sentence case, lang switch + theme toggle spacing correct), committed as `e40aaf1`.

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

## Next session: Mock test attempt ONLY — do not pair with anything else

This is the screen you flagged as highest-risk (audio player, question navigator, listening badge, multiple question-type renderers) and the one most likely to exhaust a context budget on its own.

**Located in `.dc.html`: `isTest` block, lines 302-358** (NOT `isMock`, which is lines 232-262 and is actually the *result* screen — confusingly named, easy to grab the wrong block). Cross-check against `04-mocktest-attempt.png`.

What's in that block, so next session doesn't have to re-derive it:
- **Header row** (lines 305-310): set icon (coral checkmark/rect, same icon already used for Mock Test everywhere else in this app) + set title/subtitle, and a timer pill (clock icon + monospace `94:58` countdown, gold-tinted).
- **Toolbar row** (lines 313-320): Pinyin/Translation toggle chips (checkmark shown when active), "Question 13 / 95" label, then a progress bar (`height:8px`, gold→green gradient — a third, slightly different progress-bar treatment vs. the ones already ported on dashboard/flashcard).
- **Question card** (lines 322-336): only ONE worked example in source — a **listening, true/false** question. Shows: section badge (blue "Listening" pill with speaker icon — same icon now already ported for Recent History), an audio player (play circle button, progress track, `0:12 / 0:38` time label), Chinese sentence prompt (Noto Sans SC, not serif — different from the flashcard's serif hanzi), optional pinyin/translation lines below it (toggled by the toolbar chips), then Benar/Salah (True/False) answer buttons.
- **Nav buttons** (lines 338-341): Previous (outlined, muted) / Next (solid navy `#1C2A5E`, high contrast — a new accent color not used elsewhere yet).
- **Question navigator** (lines 343-352): "Question navigator" label + "Filled 12/95" counter, then a grid of numbered cells (`sc-for` over `qNav`, ~30 shown as placeholder count but real count would be 95), plus a legend (Answered=navy, Current=gold, Flagged=coral outline, Empty=track-gray).
- **Submit button** (line 354): full-width gold gradient, same treatment as the flashcard's Show-answer button (reuse that styling).

**Why this is the risky one**: source only demonstrates ONE of what the app calls "8 question types" (true/false + listening). The existing app already has CSS for several other question renderers (`.qPassage`, `.choiceHanzi`, `.segmentHanzi`, `.orderingPreview`/`.orderingReveal`, `.charInputBox`, `.qEssayPrompt`/`.qEssayWord`/`.qEssayArticle` — at minimum reading passages, multiple choice, sentence ordering, character input, and essay). None of those have a source example to port from directly — the plan should be: port the shared chrome (card shell, header, toolbar, progress, nav buttons, question navigator, legend) faithfully from the one example given, then bring each existing question-renderer's *inner* content styling in line with that shared card shell's conventions (same badge style, same fonts/sizes/spacing patterns used elsewhere) rather than inventing new designs for types with zero source reference. Expect this to need its own DECISIONS_NEEDED entries for any question type where "how should this specifically look" isn't inferable from the one given example.

Budget this screen alone. Don't start anything else after it in the same session.
