## Pure aggregation math for [CardModifier] stacks — the single place the
## clamp/floor arithmetic from `design/gdd/skill-card-system.md` 公式一 lives.
##
## Stateless utility — every function is a [code]static func[/code] with no
## side effects, no node access, and no randomness, mirroring
## [CombatRules] ([code]src/gameplay/combat/combat_rules.gd[/code]).
## [Unit] holds the modifier list and delegates all arithmetic here; this is
## deliberate so [code]src/gameplay/units/unit.gd[/code]'s "pure data holder"
## header stays true rather than becoming a second, drifting copy of this
## clamp logic.
##
## Formula (`story-001-modifier-model.md`):
## [codeblock]
## ATK_eff(u) = max(0, ATK_base(u) + clamp(Σⱼ Δatkⱼ, ATK_DELTA_MIN, ATK_DELTA_MAX))
## DEF_eff(u) = max(0, DEF_base(u) + clamp(Σⱼ Δdefⱼ, DEF_DELTA_MIN, DEF_DELTA_MAX))
## [/codeblock]
## Stacking is plain per-modifier summation — never a max, never mutually
## exclusive, never an overwrite. The clamp applies once, to the *sum*, not
## per modifier.
class_name CardModifierRules
extends RefCounted

## Cumulative ΣΔatk clamp bounds. Source: `design/quick-specs/unit-stats-provisional.md`
## §7-4, and `production/epics/skill-card-system/EPIC.md`'s 數值錨點 table.
const ATK_DELTA_MIN: int = -4
const ATK_DELTA_MAX: int = 6

## Cumulative ΣΔdef clamp bounds — deliberately narrower than the ATK side;
## see the same source for the rationale (kept intentionally conservative
## relative to current DEF base values).
const DEF_DELTA_MIN: int = -3
const DEF_DELTA_MAX: int = 4


## Computes ATK_eff: sums every modifier's [member CardModifier.atk_delta],
## clamps the sum to [constant ATK_DELTA_MIN]..[constant ATK_DELTA_MAX], adds
## it to [param base_atk], and floors the result at 0.
##
## The ≥0 floor is a hard requirement, not a defensive default — see this
## file's and the story's doc comments: without it, a DEF-side floor
## violation elsewhere could let [code]ATK - DEF[/code] exceed [code]ATK[/code]
## itself, which is outside the damage formula's declared domain.
static func effective_atk(base_atk: int, modifiers: Array[CardModifier]) -> int:
	var total_delta: int = 0
	for modifier: CardModifier in modifiers:
		total_delta += modifier.atk_delta
	var clamped_delta: int = clampi(total_delta, ATK_DELTA_MIN, ATK_DELTA_MAX)
	return maxi(0, base_atk + clamped_delta)


## Computes DEF_eff — see [method effective_atk] for the full rationale; the
## same shape applies symmetrically to DEF, using
## [member CardModifier.def_delta] and the DEF-side clamp bounds.
static func effective_def(base_def: int, modifiers: Array[CardModifier]) -> int:
	var total_delta: int = 0
	for modifier: CardModifier in modifiers:
		total_delta += modifier.def_delta
	var clamped_delta: int = clampi(total_delta, DEF_DELTA_MIN, DEF_DELTA_MAX)
	return maxi(0, base_def + clamped_delta)
