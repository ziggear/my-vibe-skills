---
name: web-ui-pitfalls
description: Web layout sizing model, common failure modes (width/height collapse, overflow, sticky, empty states), and root-cause checks to avoid cascading fixes. Framework-agnostic.
---

# Web UI Layout Model and Pitfalls

Reference when implementing or refactoring layout (grid, flex, sticky, scroll containers, empty states) in any web project. Focus on sizing mechanics and structural causes rather than patching symptoms.

---

## 1. The Sizing Model: How Browsers Decide Width and Height

Understand these before writing CSS:

- **Containing block**: Percentages resolve against the containing block. If the parent’s size is content-driven, percentage children inherit that instability.
- **Content-based sizing**: Elements without explicit width/height are sized by content (`max-content`, `min-content`, available space negotiation).
- **Auto minimum size (flex/grid)**:
  - Flex items default to `min-width: auto`.
  - This means they won’t shrink below their content’s min-content width.
  - Common symptom: overflow instead of shrinking.
  - Typical fix when shrink is desired: `min-width: 0` (or `overflow: hidden`).
- **Flex-basis vs content size**:
  - `flex: 1` is shorthand for `flex: 1 1 0%` (basis 0%).
  - `flex: auto` uses content size as basis.
  - Unexpected growth/shrink behavior often comes from misunderstood basis.
- **Height is not symmetric to width**:
  - `height: 100%` works only if all ancestors up the chain have a definite height.
  - Most vertical collapse issues are missing explicit height on an ancestor.

If layout breaks, inspect computed sizes and constraints before adding overrides.

---

## 2. Who Owns the Layout?

Layout should be defined at the highest stable ancestor with deterministic size.

Before styling:

- Decide which element sets:
  - overall width
  - overall height
  - scroll behavior
- Decide whether rows define columns, or a parent defines columns.

Prefer:

- One grid or flex container defining primary columns.
- Children participating in that structure.

Avoid:

- Repeating two-column grids per row unless row width is intentionally content-sized.
- Letting content wrappers implicitly determine layout width.

If a column ratio must remain stable (e.g. 70% / 30%), define it at a parent with explicit width (e.g. `width: 100%`, max-width container).

---

## 3. Width Collapse and Overflow Patterns

Common causes:

- Parent width determined by minimal content.
- Flex items blocked from shrinking due to `min-width: auto`.
- Long unbroken strings forcing min-content width expansion.
- Nested wrappers introducing unexpected shrink boundaries.

Root-cause fixes:

- Ensure layout container has explicit width (`width: 100%` or fixed/max).
- Use `min-width: 0` on flex children when shrink is required.
- Use `overflow-wrap: break-word` or `word-break` for long content.
- Remove unnecessary wrappers that create additional sizing contexts.

Do not:

- Add arbitrary `min-width` to “hold” layout unless it matches a real constraint.
- Stack percentage-based sizing inside content-sized parents.

---

## 4. Height, Scroll, and 100% Failures

Frequent issues:

- `height: 100%` not working because parent height is auto.
- Flex column layout where middle child should scroll but doesn’t.
- Double scrollbars due to nested overflow containers.
- Sticky footer/header failing due to incorrect height model.

Patterns:

- For full-height layouts, set:
  - `html, body { height: 100%; }`
  - top-level app container with defined height.
- In column flex layouts:
  - Parent: `display: flex; flex-direction: column;`
  - Scroll child: `flex: 1; overflow: auto; min-height: 0;`
- Avoid multiple nested `overflow: auto` unless intentionally creating separate scroll contexts.

Always identify:
- Which element is the scroll container.
- Whether scroll should belong to page or inner panel.

---

## 5. Sticky vs In-Flow Positioning

Understand the difference:

- **In-flow panel**:
  - Participates in grid/flex row.
  - Scrolls naturally with content.
- **Sticky panel**:
  - Uses `position: sticky`.
  - Requires `top` (or bottom).
  - Fails if any ancestor has `overflow` other than `visible`.
  - Constrained by its nearest scroll container.

Common sticky failures:

- Parent has `overflow: hidden/auto`.
- Sticky element taller than its container.
- No defined offset (`top` missing).

Do not attempt to make one global sticky panel “track” a specific row without structural alignment or JS measurement. That is a different pattern.

---

## 6. Empty and Minimal Content States

Always test:

- No items.
- Single item.
- All items collapsed.
- Extremely long content.
- Rapid dynamic updates.

Width or height collapse in empty state usually means:

- Container size depends on children.
- Layout was implicitly content-sized.

Fix by:

- Assigning width/height responsibility to a stable ancestor.
- Keeping structure identical between empty and non-empty states.
- Ensuring empty placeholders mirror real layout structure (not arbitrary blocks).

Placeholder rules:

- Placeholders may simulate final structure.
- They must not introduce new sizing logic.

---

## 7. Wrappers and Visual Responsibility

Separate concerns:

- Layout wrappers:
  - Only `display`, `gap`, `align`, sizing.
  - No border/background/shadow unless required.
- Visual components:
  - Own borders, background, elevation.

Unintended visual changes often come from layout wrappers adding styles that alter perceived structure.

Remove redundant wrappers that:

- Exist only due to previous patches.
- Introduce extra flex/grid contexts.

---

## 8. State Validation Checklist

After any layout change, verify:

- Empty state.
- Minimal-content state.
- Typical interaction state.
- Long-content overflow.
- Responsive breakpoints.
- Zoom (125% / 150%).
- Dynamic insertion/removal.

If specification requires fixed column ratios or invariant width during expand/collapse, confirm under all states.

---

## 9. Document Structural Decisions

In code or a short doc, record:

- Which element defines width.
- Which element defines height.
- Which element owns scroll.
- Whether column ratios are fixed or content-driven.

Future layout regressions usually stem from unclear ownership of size and scroll.

---

## 10. Two-Column Overlap: Overflow and Stacking

When a row has two columns (e.g. flex: left content + right panel), the **left column can visually cover the right column** even though the right has space. Root causes:

1. **Content overflow**
   - The left column has no `overflow` constraint; long text or wide content extends to the right and overlaps the right column.
   - **Fix**: `overflow: hidden` on the left column so it is clipped to its flex width. Use `min-width: 0` if the column is flex and must shrink.

2. **Stacking order**
   - Both columns are in-flow; paint order or stacking context can put the left on top, so the right column’s left/top edge appears “under” the left.
   - **Fix**: Give the right column a higher `z-index` (e.g. `position: relative; z-index: 2`) and the left a lower one (e.g. `z-index: 0`) so the right consistently paints on top when they overlap.

3. **Parent clipping**
   - A parent (e.g. card or inner wrapper) has `overflow: hidden`; the right column is partially outside the parent’s bounds and gets clipped (symptom: “left and top covered, right and bottom have space”).
   - **Fix**: Use `overflow: visible` on that parent, or add a modifier class (e.g. `card--no-clip`) so the summary/layout container does not clip children.

**Checklist for “element A is covered by B”**

- Does B overflow into A’s area? → Constrain B with `overflow: hidden` (and `min-width: 0` if flex).
- Does paint order put B on top? → Raise A’s `z-index` (and give A/B explicit stacking context if needed).
- Is a common ancestor clipping A? → Set that ancestor to `overflow: visible` where clipping is not intended.

Do not “fix” by shrinking the covered element or adding padding; fix who overflows and who clips.