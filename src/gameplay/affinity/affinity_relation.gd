# AffinityRelation —— 一對角色的「關係三態」單一判定(NONE / POS / NEG)。
#
# 規格:production/epics/skill-card-system/story-012-relation-state-of-pair.md
# 放置位置裁決:docs/reviews/state-of-adr0002-ruling-2026-11-17.md
#   (不放池、不放 AffinityPhiProvider;不觸及 ADR-0002 契約)。
# 契約:docs/registry/architecture.yaml 的 affinity_relation_state_single_judgment。
#
# 判定(10 組同一條式子,不看配對名字):
#   n == 0 或 |v| <= k  -> NONE;v > k -> POS;v < -k -> NEG。
# 每次呼叫即時讀池,不快取;唯讀(只呼叫 combat_strength_read)。
class_name AffinityRelation
extends RefCounted


## 第 0 值 = NONE = 最安全預設(讀取被拒、錯誤分支都回它)。
enum RelationState { NONE, POS, NEG }

## 冷淡區旋鈕 neutral_band_centi 的預設值。k=0 是唯一與現行
## AffinityPhiProvider._link_for_pair 逐位相同的值(管理者 2026-11-17 裁決,
## 正式值待 story-025 量測;不得用占位值上線)。
const NEUTRAL_BAND_CENTI_DEFAULT: int = 0


## 判定 [param pair] 當下的關係三態。[param neutral_band] 即 k(已除以 100 的浮點數,
## 來源 [method AffinityTuning.neutral_band]);負值視為錯誤。
## 讀取被池拒絕時 push_error 並回 NONE(拒絕時 value 為 NAN,不得往下比較)。
static func state_of(
	pool: AffinityDataPool, pair: AffinityTypes.Pair, neutral_band: float
) -> RelationState:
	if pool == null:
		push_error("AffinityRelation.state_of: pool is null")
		return RelationState.NONE
	if is_nan(neutral_band) or neutral_band < 0.0:
		push_error("AffinityRelation.state_of: neutral_band must be >= 0, got %s" % neutral_band)
		return RelationState.NONE
	var result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)
	if result.rejection != AffinityDataPool.ReadRejection.NONE:
		push_error(
			"AffinityRelation.state_of: combat_strength_read() rejected pair %d (code %d)"
			% [pair, result.rejection]
		)
		return RelationState.NONE
	if result.n_pair == 0:
		return RelationState.NONE
	if result.value > neutral_band:
		return RelationState.POS
	if result.value < -neutral_band:
		return RelationState.NEG
	return RelationState.NONE
