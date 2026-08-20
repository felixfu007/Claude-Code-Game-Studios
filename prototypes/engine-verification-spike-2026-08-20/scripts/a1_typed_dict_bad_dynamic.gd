# A1-d:經由 Variant 藏起來的錯誤鍵/值 —— 編譯器看不見,只能靠執行期檢查。
# 這是本批唯一「會被實際執行」的錯誤案例,因此排在整份報告的最後。
extends RefCounted

static func run_bad_key() -> void:
	var d: Dictionary[AffinityTypes.Pair, Array[AffinityRecord]] = {}
	var sneaky_key: Variant = "not_an_enum"
	d[sneaky_key] = []

static func run_bad_value() -> void:
	var d: Dictionary[AffinityTypes.Pair, Array[AffinityRecord]] = {}
	var sneaky_value: Variant = 12345
	d[AffinityTypes.Pair.C1_C2] = sneaky_value
