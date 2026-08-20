# A1-b:靜態可見的錯誤鍵型別(字面量 String 當鍵)。
#
# ⚠️ 2026-08-20 第三次執行後改寫:原本用 Dictionary[Pair, Array[AffinityRecord]],
# 但那個宣告本身就因「巢狀型別容器不支援」而編譯失敗 —— 會把「錯誤鍵被擋下」與
# 「巢狀不支援」兩個原因混在一起,測不出想測的東西。改用**非巢狀**的型別化字典隔離變因。
extends RefCounted

static func run() -> void:
	var d: Dictionary[AffinityTypes.Pair, int] = {}
	d["this_is_not_an_enum"] = 1
