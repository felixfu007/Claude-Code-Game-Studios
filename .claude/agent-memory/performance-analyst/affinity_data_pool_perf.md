---
name: affinity-data-pool-perf
description: Performance-relevant state of design/gdd/affinity-data-pool.md (好感度數值池/Delta Log) after design-review round 11 — what's settled vs. what's still open for this agent's domain
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

**Round 11 audit (2026-08-10), covering rounds 8-10's additions (陣亡標記表 /
death-marker table, Core Rules #2 death-write-restriction, Core Rules #6
token-set serialization lifecycle):**

Settled — the O(n_pair)/O(n_p+m) read guarantee is NOT eroded by rounds 8-10.
The death-marker table is `Dictionary[角色, int]` bounded to 5 keys (fixed cast
size), so any lookup against it is O(1) in the strict sense regardless of
implementation quality (even a linear scan over 5 items is O(1)). Token-set
begin/end/timeout checks are similarly bounded by concurrent non-atomic-window
count, which is inherently small.

New gaps found this round (not yet in the GDD):
1. **AC-55's diagnostic ("walked/accessed record count") was never extended to
   cover death-marker-table or token-set accesses.** Core Rules #1's "診斷可觀測性
   要求" text is textually scoped to "記錄筆數" (Delta Log records) only. A future
   implementation that accidentally makes the death-lookup non-constant would not
   be caught by AC-55 — the verification apparatus has a real coverage gap, even
   though real-world risk is low (table capped at 5 entries).
2. **The death-marker lookup is not just a write-path cost.** Core Rules #3
   requires combat_strength_read/narrative_depth_read to consult the death-marker
   table on every call where `t_query` is omitted, to decide whether the default
   is `t_death(p)` or `t_now` — this is the AI position-evaluation hot path
   (Dependencies row citing "數十萬次元素存取" per turn), not just the write path.
   Core Rules #1's formal complexity statement was never updated to acknowledge
   this read-side addition, even though Core Rules #2 explicitly states the
   O(1) claim for the write-side check. Asymmetric documentation rigor, not a
   real risk (still O(1), and shielded by the existing per-turn memoization
   requirement once (pair,t_query) is cached).
3. **Formula 4's `t_last`/`read(t_last)` never cross-references Core Rules #3's
   dead-pair freeze default.** `t_last` is defined as "該配對『目前』最新一筆已寫入
   記錄的 t_i" — for a dead pair this conflicts with combat_strength_read's frozen
   default (`t_death(p)`, ignoring posthumous records). Until resolved
   (correctness question, systems-designer track), the caching basis for
   dead-pair predictive reads is ambiguous — can't confirm whether it should be
   cached as invariant-forever or refreshed per-turn like a live pair.
4. **Dependencies row's hard memoization requirement for 好感度—位置連鎖系統 never
   mentions dead pairs at all.** No explicit guidance on whether dead-pair reads
   (which are provably invariant for the rest of the game once frozen) warrant
   more aggressive cross-turn caching, or just the standard single-turn cache.
   Missed optimization-guidance opportunity, not a blocking risk given small n.
5. **Token-set max concurrent count is never explicitly bounded/cited in this
   GDD** — only qualitative reasoning ("save-system.md 槽隔離性...可能同時存在多個
   發起者"), no numeric cap referenced. Negligible real risk (concurrent
   non-atomic windows are inherently few), but the reasoning trail is thinner
   than the doc's usual rigor (cf. explicit domain constraints on `Q`/`n_gate_min`).

Confirmed: OQ9's existing generic multi-ply/lookahead exclusion (2026-08-03
third amendment) already covers dead-pair formula-4 usage — rounds 8-10 don't
introduce a NEW class of combinatorial risk, they just compound the existing
unaddressed OQ9 risk with an additional unresolved semantic question (#3 above).
