# ⚠️ 這一檔**故意保留錯誤寫法**,作為永久證據。
#
# 它逐字照抄 docs/engine-reference/godot/current-best-practices.md 第 41-49 行的範例。
# 2026-08-20 實測:在 Godot 4.7.1 為 parser error ——
#   Error at (N, 5): An abstract function cannot have a body.
#
# 保留的理由:那個範例是 ADR-0004 與 ADR-0005 對 @abstract 語法的**唯一依據**,
# 而第三輪 /architecture-review 正是靠逐字比對它,把該假設從「印象」升級為「已查證」。
# 刪掉這一檔,下一個人就只會看到「已修好的版本」,看不到那次升級是錯的。
@abstract
extends RefCounted   # 刻意不給 class_name:避免專案載入時就被掃描而中斷 F5

@abstract
func get_attack_pattern() -> Array[AffinityRecord]:
	pass
