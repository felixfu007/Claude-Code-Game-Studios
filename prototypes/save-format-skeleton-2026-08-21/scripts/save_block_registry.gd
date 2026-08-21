class_name SaveBlockRegistry
extends RefCounted
# 依賴注入實例,非靜態。查無登記 -> 讀取路徑回 DATA_CORRUPTED(fail-closed)。

var _validators: Dictionary = {}

func register(source_id: String, validator: Callable) -> void:
	# (c) 決定:重複登記同一個 source_id -> 拒絕覆寫並 push_error。
	# 設計規格沒講。選 fail-loud 的理由:靜默覆寫等於讓後載入的系統
	# 綁架另一個系統的語意驗證器,而症狀會出現在「別人的區塊驗證通過了但值是錯的」。
	if _validators.has(source_id):
		push_error("SaveBlockRegistry: source_id '%s' 已登記,拒絕覆寫" % source_id)
		return
	# (c) 決定:登記時就拒絕失效 Callable。
	# 但呼叫前「仍然要再檢查一次」—— 兩者不是重複:登記時有效的 Callable,
	# 其目標物件可能在登記之後才被釋放。
	if not validator.is_valid():
		push_error("SaveBlockRegistry: source_id '%s' 的 validator 在登記時就已失效" % source_id)
		return
	_validators[source_id] = validator

func get_validator(source_id: String) -> Variant:
	# 規格/ADR 的簽章就是 Variant(Callable 或 null)。
	# (c) 注意:呼叫端不能寫 `if v == null` 之後就當成 Callable 用 ——
	# 必須 typeof(v) == TYPE_CALLABLE。見 save_reader.gd 的 S6。
	if not _validators.has(source_id):
		return null
	return _validators[source_id]

func registered_ids() -> Array:
	return _validators.keys()
