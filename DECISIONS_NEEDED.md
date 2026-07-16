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

Nothing else pending a decision right now.
