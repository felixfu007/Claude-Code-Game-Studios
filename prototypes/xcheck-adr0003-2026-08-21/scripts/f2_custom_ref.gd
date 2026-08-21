class_name F2CustomRef extends RefCounted
# F2-g 用:帶 class_name 的自訂 RefCounted 子類別。
# 與裸 RefCounted.new() 的差別是編碼時會夾帶 script 路徑,解碼側要載入腳本。
@export var payload_int: int = 7
@export var payload_str: String = "custom-ref"
