# A2 —— ADR-0002 Verification Required 第 2 項。
#
# 真正要問的不是「enum 能不能當鍵」(能),而是:
#   enum 鍵在底層是不是就是 int?若是,型別化 Dictionary 的鍵檢查對「傳入裸 int」是否形同虛設?
# 這直接決定 ADR-0002 機制四的 per-pair 索引有沒有型別安全可言。
extends RefCounted

static func run() -> Dictionary:
	var out := {}

	# 用未型別化的 Dictionary 先問「enum 鍵的相等/雜湊語意」本身
	var plain := {}
	plain[AffinityTypes.Pair.C1_C2] = "inserted_with_enum"

	out["lookup_with_enum"] = plain.get(AffinityTypes.Pair.C1_C2, "<MISS>")
	out["lookup_with_raw_int_0"] = plain.get(0, "<MISS>")
	out["enum_C1_C2_int_value"] = int(AffinityTypes.Pair.C1_C2)
	out["typeof_enum_key"] = typeof(AffinityTypes.Pair.C1_C2)
	out["typeof_int_literal"] = typeof(0)
	out["hash_enum"] = hash(AffinityTypes.Pair.C1_C2)
	out["hash_int_0"] = hash(0)

	var keys := plain.keys()
	out["stored_key_typeof"] = typeof(keys[0]) if keys.size() > 0 else -1

	# 兩個不同 enum 家族、相同序數值,是否互相碰撞
	var cross := {}
	cross[AffinityTypes.Pair.C1_C2] = "from_Pair"
	cross[AffinityTypes.Character.CHARACTER_1] = "from_Character"
	out["cross_enum_family_size"] = cross.size()
	out["cross_enum_final_value_at_0"] = cross.get(0, "<MISS>")

	return out
