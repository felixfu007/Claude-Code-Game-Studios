# A1-(e) ⚠️ **故意保留的失敗案例** —— ADR-0002 機制四的原始宣告逐字照抄。
#
# 2026-08-20 第三次執行實測:
#   Parse Error: Nested typed collections are not supported.
#
# 保留理由同 c1_pass_body_record.gd:刪掉的話,下一個人只會看到已改好的版本,
# 看不到 ADR-0002 的核心資料結構原本寫不出來這件事。
# 刻意不給 class_name,避免專案載入時就被掃描而中斷 F5。
extends RefCounted

static func build() -> Dictionary:
	var d: Dictionary[AffinityTypes.Pair, Array[AffinityRecord]] = {}
	return d
