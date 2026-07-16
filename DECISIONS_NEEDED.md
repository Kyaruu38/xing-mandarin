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

---

Nothing else pending a decision right now.
