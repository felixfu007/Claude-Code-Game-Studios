---
name: affinity-data-pool-perf
description: Performance-relevant state of design/gdd/affinity-data-pool.md (好感度數值池/Delta Log) after design-review round 6 — what's settled vs. what's still open for this agent's domain
metadata:
  type: project
---

`design/gdd/affinity-data-pool.md` (Delta Log / 好感度數值池) is a Foundation-layer
GDD for 《弈緣》, read by combat AI (好感度—位置連鎖系統) and narrative unlock
(敘事解鎖與結局分支系統). Six `/design-review` rounds complete as of 2026-08-03.

**Settled by round 6 (do not re-flag without new evidence):**
- Core Rules #1 requires O(n_pair) query complexity for all 3 real read fns +
  Formula 4, not O(global total) — per-pair indexed storage required (AC-55).
- Position-linkage system's memoization caching of read results is a HARD
  dependency-interface requirement (upgraded from suggestion in round 6),
  explicitly modeled on Formula 4's `read(t_last)` per-pair-per-turn cache.
- Open Question 9 explicitly scopes the "low hundreds to low thousands total
  records" estimate to raw data volume / single-query cost only — it explicitly
  does NOT claim AI's repeated formula-4 calls per turn or save serialization
  frequency are validated safe. Do not treat OQ9 as having cleared those.

**New findings raised in this round's audit (not yet in the GDD, worth checking
next `/design-review` round for a response):**
1. Possible internal inconsistency: Core Rules #2 states position/adjacency
   "永遠只讀取,不寫入" (position never writes affinity), but Formula 4's stated
   use-case #2 (line ~235) describes AI evaluating hypothetical *positions* via
   assumed NEW hypothetical records + `read(t_last)` cache — which implies a
   hypothetical-write pattern that Core Rules #2 says shouldn't exist for
   position eval. Either position eval should just be cheap cached formula-1
   reads (no Formula 4 involvement), or there's an undocumented pathway where
   position simulation produces hypothetical writes. Worth a clarifying pass.
2. The memoization hard requirement is explicitly scoped to "單一回合評估範圍"
   (single-turn evaluation). If the position-linkage AI does any multi-ply /
   lookahead search (simulating sequences of hypothetical future turns, not just
   one turn's candidate tiles), the per-turn base-read cache doesn't bound the
   combinatorial growth of distinct hypothetical states across plies — this is
   outside what AC-55 measures (single-call scaling vs. n_p) and outside what
   Open Question 9 scopes. Not yet addressed anywhere in the document.
3. The memoization hard requirement is applied only to 好感度—位置連鎖系統, not to
   敘事解鎖與結局分支系統, even though the narrative system also calls
   shape_feature_read (O(n_pair) but recomputes 7 sub-features incl. segment_profile
   tuples per call). Likely low real risk since narrative eval isn't a tight
   per-frame loop like combat AI, but the asymmetry in the GDD's caching
   obligations is unexplained.

See also: `.claude/docs/technical-preferences.md` for 60fps/16.6ms budget.
