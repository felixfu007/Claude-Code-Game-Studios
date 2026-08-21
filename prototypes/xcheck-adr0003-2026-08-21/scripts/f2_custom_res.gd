class_name F2CustomRes extends Resource
# F2-g 用:自訂 Resource 子類別 —— ADR-0003 Alternative 1 拒絕 Resource 的理由
# 正是「ResourceLoader 會依檔案聲明的類別逕行實例化」。此處測的是 Variant 二進位
# 路徑上 Resource 的命運,與 ResourceLoader 路徑無關。
@export var payload_int: int = 9
@export var payload_str: String = "custom-res"
