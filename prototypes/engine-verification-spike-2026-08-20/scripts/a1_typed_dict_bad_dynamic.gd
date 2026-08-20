# A1-d:經由 Variant 藏起來的錯誤鍵/值 —— 編譯器看不見,只能靠執行期檢查。
# 這是本批唯一「會被實際執行」的錯誤案例,因此排在整份報告的最後。
#
# ⚠️ 2026-08-20 第三次執行後改寫為非巢狀宣告,理由同 a1_typed_dict_bad_key_static.gd。
#
# 注意 A2 已經測出:enum 在執行期就是 int(typeof 皆為 TYPE_INT、hash 相同)。
# 因此「錯誤鍵」這一項真正在問的是:執行期擋不擋得住一個**非 int** 的鍵。
extends RefCounted

static func run_bad_key() -> void:
	var d: Dictionary[AffinityTypes.Pair, int] = {}
	var sneaky_key: Variant = "not_an_enum"
	d[sneaky_key] = 1

static func run_bad_value() -> void:
	var d: Dictionary[AffinityTypes.Pair, int] = {}
	var sneaky_value: Variant = "not_an_int"
	d[AffinityTypes.Pair.C1_C2] = sneaky_value
