# 逐字照抄 ADR-0002 機制三的 AffinityRecord 五個型別化欄位。
# 附帶驗證:enum 是否可直接當欄位型別註記(GDScript 4 應可,但本專案未實測)。
class_name AffinityRecord extends RefCounted

var pair: AffinityTypes.Pair
var m: float
var t: int
var c: int
var source: AffinityTypes.Source
