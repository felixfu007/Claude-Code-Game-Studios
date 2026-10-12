---
name: outline-internal-parts-ruling
description: 2026-10-12 ruling — pixel-art outline only on outer silhouette edge, never on internal part boundaries (face-in-body, weapon-vs-body); not yet merged into art-direction.md
metadata:
  type: project
---

On 2026-10-12, adjudicating AI_IMG home-workstation's Q7
(`docs/ai-art-service-handoff/06-change-request-001-reply-2026-10-10.md`), I ruled that
**internal silhouette part boundaries never get a 1px outline — only the outer edge
(opaque pixel touching a transparent pixel or canvas boundary) does.** Internal material
transitions (face vs body, weapon vs hand) are communicated by the existing
`_shadow_/_base_/_highlight_` three-tier shading in the palette, not by outline strokes.

**Why:** `art-direction.md` §4's own stated reason for outlines is external readability
("尤其棋子要在多變地形背景上保持可讀性" — readability against varied *terrain backgrounds*),
which is about the silhouette's outer boundary, not internal clarity. Outlining every internal
material seam would also burn extra color budget against the project's hard 64-color cap
(§3) for a requirement the design rationale never asked for. This reading also resolves why
the acceptance table's "≥2 outline hues across different materials" criterion
(06a §5 item 4) is written the way it is — it already presupposes "multiple material regions
exposed at the outer edge," not "every internal seam painted."

**How to apply:** This ruling only lives in
`docs/ai-art-service-handoff/06a-art-clarifications-2026-10-12.md` right now — it has **not**
been merged into `art-direction.md` §4 itself. I recommended doing so (as a drafted addition,
shown to the user for approval first — never silently editing `design/art/` files per this
project's standing constraint) but did not execute it in that task. Before relying on
`art-direction.md` as having an answer to "do internal parts get outlined," check whether that
merge has since happened; if §4 still only says "1px, non-pure-black, tinted by material" with
no outer/inner distinction, the merge hasn't happened yet and this memory is still the only
record of the ruling.

Linked ruling in the same file: single-material assets (e.g. a plain terrain prop) are exempt
from the "≥2 outline hues" check (report N/A, not FAIL) — same session, same document, Q8.

See also [[project_color_palette_v0_and_06a_format_ambiguity]] for the adjacent CR-001/06a
handoff thread this ruling is part of.
