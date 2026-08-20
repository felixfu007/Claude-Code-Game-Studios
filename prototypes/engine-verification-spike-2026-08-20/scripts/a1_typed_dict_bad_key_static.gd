# A1-b:靜態可見的錯誤鍵型別(字面量 String 當鍵)。
# 問題:4.7.1 會在「編譯期」擋下,還是要等執行期?
# 本檔只被 load(),不被執行 —— load() 成功與否就是答案。
extends RefCounted

static func run() -> void:
	var d: Dictionary[AffinityTypes.Pair, Array[AffinityRecord]] = {}
	d["this_is_not_an_enum"] = []
