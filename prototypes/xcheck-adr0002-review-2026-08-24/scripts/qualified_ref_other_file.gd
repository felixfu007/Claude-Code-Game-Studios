class_name QualifiedRefOtherFile extends RefCounted
# Control group: same cross-file nested-enum reference, but QUALIFIED
# (OuterHolder.MyEnum) -- the form ADR-0002 mechanism two already prescribes
# for Pair/Character/Source (AffinityTypes.Pair etc). Expected to compile.

var rejection: OuterHolder.MyEnum = OuterHolder.MyEnum.A
