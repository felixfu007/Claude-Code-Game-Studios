class_name GCustomRes extends Resource
# ============================================================================
# 探針 G-2 用:帶「可辨識欄位值」的自訂 Resource 子類別
# ============================================================================
# registry `resource_based_save_payload` 的 why: 欄宣稱把 raw Resource 交給存檔
# 寫入路徑「would fail to serialize at all」。探針 F 的 F2-g 測的是
# RefCounted.new() 與 F2CustomRes(欄位皆為預設值),兩者都無法回答
# 「欄位資料有沒有跟著過去」。本類別的三個欄位在測試中會被設成刻意好認的值,
# 使「只剩一個 ID」與「資料真的被帶過去」在 log 上一眼可分。
@export var payload_int: int = -1
@export var payload_str: String = "G-RES-UNSET"
@export var payload_dict: Dictionary = {}
