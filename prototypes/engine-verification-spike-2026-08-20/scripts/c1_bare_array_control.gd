# C1 對照組 —— 裸簽章形式(無冒號、無主體)。
# 2026-08-20 第一次執行結果:參考庫 current-best-practices.md 第 41-49 行的
# 「冒號 + pass 主體」形式在 4.7.1 是 parser error(An abstract function cannot have a body)。
# 本檔改測 ADR-0004 機制一原本採用、但被 VR #6 標為「與參考庫互斥、無法確認」的那一種形式。
@abstract
class_name SpikeBareArray extends RefCounted

@abstract
func get_items() -> Array[AffinityRecord]
