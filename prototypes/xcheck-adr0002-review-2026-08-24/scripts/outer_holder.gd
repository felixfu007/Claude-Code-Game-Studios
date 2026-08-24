class_name OuterHolder extends RefCounted
# Mirrors AffinityDataPool: a class_name class with a NESTED enum, exactly
# like ADR-0002 mechanism two's own explicit rule for Pair/Character/Source
# ("列舉若定義在某個 class_name 的類別內,只能以 ClassName.EnumName 從其他
# 檔案存取"). This probe asks: does that same rule apply to AffinityDataPool's
# own result enums (WriteRejection/ReadRejection/etc), which the ADR's Key
# Interfaces section suggests should be usable from a SEPARATE file
# (affinity_read_result.gd) via a bare reference?

enum MyEnum { A, B }

func f() -> MyEnum:
	return MyEnum.A
