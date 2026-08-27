---
name: feedback-name-verification-no-search-tool
description: This agent has no WebSearch tool — real-person name-collision checks are knowledge-based only and must be disclosed as such
metadata:
  type: feedback
---

When asked to verify that a candidate character name does not match a real public
figure (athlete, celebrity, politician, news anchor, criminal case), this agent's
toolset in this environment is Read/Glob/Grep/Write/Edit only — **no WebSearch or
any live lookup tool is available**. Verification can only be a cross-reference
against trained knowledge (cutoff ~January 2026), not a live database check.

**Why:** A prior round for 《盲目於微光》 put forward 林郁婷 as a candidate name for
a female firefighter protagonist without catching that it is the real name of the
2024 Paris Olympics boxing gold medalist and the athlete at the center of that
Games' gender-eligibility controversy — an association no player would miss. The
manager explicitly flagged this as the failure to not repeat.

**How to apply:**
- Always state plainly, up front, that verification is knowledge-based cross-
  referencing, not a live search, and name this limitation every time a naming
  task carries this requirement — do not let the disclaimer get dropped just
  because a prior round already covered it once.
- Recommend the human do a live-search confirmation pass before names are
  finalized/committed to files, precisely because this is where the last miss
  happened.
- Treat surname-level association with major political figures as a soft risk
  too, not just full-name collisions — e.g. avoid 韓/柯/蔡/賴/蕭 as protagonist
  surnames in a Taiwan-set story even when the given name clearly differs,
  because the surname alone can trigger the association for Taiwanese players.
- When in doubt about a specific candidate, drop it rather than list it — per
  the manager's own instruction ("不確定的就不要列進候選").
