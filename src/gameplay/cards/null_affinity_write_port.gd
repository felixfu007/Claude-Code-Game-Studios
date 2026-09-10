## Null-object stand-in for [AffinityWritePort] (Story 004,
## [code]src/gameplay/cards/affinity_write_port.gd[/code]) — the default
## [BattleController] wires [CardPlaySession] with whenever a battle attaches
## a [CardDeck] but the caller supplies no real write port
## (story-008-play-session-wiring.md AC-P7).
##
## [b]Why this class needs to exist at all[/b]: [method CardPlaySession.confirm]
## calls [code]port.append_record(...)[/code] unconditionally for a
## [constant Card.Category.PERMANENT_AFFINITY_WRITE] card whose pair passes
## [method PermanentAffinityWriteRules.has_canon_link] — if [param port] were
## a bare [code]null[/code] there, that call would be a method call on a null
## instance (a crash), not a rejection. [BattleController] therefore never
## hands [CardPlaySession] a literal [code]null[/code] write port: when its
## own [code]write_port[/code] constructor parameter is unset, it substitutes
## an instance of THIS class instead — mirroring this project's existing
## "unset injected dependency -> harmless concrete default" idiom
## ([member BattleController._decide] falling back to [GreedyTacticalAI],
## [member BattleController._phi_provider] falling back to a constant 0 when
## invalid).
##
## Always rejects, and never mutates anything — no real affinity data pool
## exists anywhere in [code]src/[/code] yet (see [AffinityWritePort]'s own
## class doc comment), so there is nothing for a "no port configured" write
## to succeed against. This class is not, and must never become, a step
## toward implementing that pool (#1's own scope) — it exists solely to keep
## an unconfigured battle from crashing.
class_name NullAffinityWritePort
extends AffinityWritePort


## Always returns [constant Rejection.NO_PORT_CONFIGURED] — never appends
## anything and never inspects [param character_a] / [param character_b] /
## [param m] / [param source] beyond receiving them, matching every other
## rejection path in this system (a rejected write leaves zero trace).
func append_record(_character_a: int, _character_b: int, _m: int, _source: StringName) -> Rejection:
	return Rejection.NO_PORT_CONFIGURED
