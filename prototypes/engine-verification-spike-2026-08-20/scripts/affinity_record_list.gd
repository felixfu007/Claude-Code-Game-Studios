# 候選替代方案 D 用的包裝類別。
# 巢狀型別容器不支援 → 把內層 Array[AffinityRecord] 包進一個 RefCounted,
# 讓外層 Dictionary 的值型別變成「類別」而非「容器」,兩層型別都保住。
class_name AffinityRecordList extends RefCounted

var items: Array[AffinityRecord] = []
