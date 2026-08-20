# C2 —— ADR-0005 Verification Required #15(S-1 的整套防禦押在這上面)。
# 提供兩種 Callable 形式,供 runner 在本節點被釋放後比較 is_valid() 的行為。
extends Node

func probe_value() -> int:
	return 42

# 隱式捕獲 self 的 lambda —— 這正是第三次修訂「發現 G」判定為語意不明確、
# 因而改採具名綁定的那一種形式。
func make_capturing_lambda() -> Callable:
	return func(): return probe_value()
