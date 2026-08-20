# A1-d:經由 Variant 藏起來的錯誤鍵/值 —— 編譯器看不見,只能靠執行期檢查。
#
# ⚠️ 2026-08-20 第四次執行後重寫:上一版只回報「有沒有硬中止」,
# **沒有斷言寫入到底成功還是被拒** —— 那是探針本身的缺口,問題等於沒答。
# 本版回傳寫入後的實際容器狀態,由呼叫方判讀。
#
# 注意 A2 已測出:enum 在執行期就是 int(typeof 皆 TYPE_INT、hash 相同)。
# 因此「錯誤鍵」真正在問的是:執行期擋不擋得住一個**非 int** 的鍵。
extends RefCounted

static func run_bad_key() -> Dictionary:
	var d: Dictionary[AffinityTypes.Pair, int] = {}
	var sneaky_key: Variant = "not_an_enum"
	d[sneaky_key] = 1
	return {
		"size_after_write": d.size(),
		"keys": str(d.keys()),
		"write_took_effect": d.size() > 0,
	}

static func run_bad_value() -> Dictionary:
	var d: Dictionary[AffinityTypes.Pair, int] = {}
	var sneaky_value: Variant = "not_an_int"
	d[AffinityTypes.Pair.C1_C2] = sneaky_value
	var stored: Variant = d.get(AffinityTypes.Pair.C1_C2, "<ABSENT>")
	return {
		"size_after_write": d.size(),
		"stored_value": str(stored),
		"stored_typeof": type_string(typeof(stored)),
		"write_took_effect": d.size() > 0,
	}
