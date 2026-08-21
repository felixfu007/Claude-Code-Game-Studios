# J4b(隔離)—— ADR-0002 Key Interfaces 的「各類別落在各自檔案」讀法:
#   AffinityReadResult 成為獨立 class_name,欄位型別為擁有者的巢狀 enum(限定寫法)
class_name JReadResultQualified extends RefCounted

var rejection: JOwner.ReadRejection = JOwner.ReadRejection.NONE
var value: float
