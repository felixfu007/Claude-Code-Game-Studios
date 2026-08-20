# A3 —— ADR-0002 Verification Required 第 3 項。
# GDD Formulas 邊界值測試總表明文要求「不可依賴引擎預設行為」,所以這一項不是
# 「確認它等於 1.0」,而是「把它實際印出來,好決定要不要在公式一/二裡顯式特判」。
extends RefCounted

static func run() -> Dictionary:
	var out := {}
	out["pow(0.0, 0.0)"] = pow(0.0, 0.0)
	out["0.0 ** 0.0"] = 0.0 ** 0.0
	out["pow(0, 0)"] = pow(0, 0)
	out["is_equal_approx_to_1"] = is_equal_approx(pow(0.0, 0.0), 1.0)
	# 相鄰邊界,用來判斷是特例還是連續行為
	out["pow(0.0, 1.0)"] = pow(0.0, 1.0)
	out["pow(1.0, 0.0)"] = pow(1.0, 0.0)
	return out
