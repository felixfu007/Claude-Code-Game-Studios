## 設定檔薄殼 —— 全專案【唯一】碰 [code]user://[/code] 設定檔的程式
## (audio-foundation story-001)。沒有任何邏輯:只讀/寫一段文字。
##
## 路徑可注入([method _init]);預設 [constant DEFAULT_PATH]。
## 🔴 探針與任何開窗證據驅動器一律注入暫存路徑,不得使用預設路徑。
## 單元測試以子類別覆寫 [method read_text]/[method write_text] 當假薄殼,不寫檔。
## 檔案層行為(寫→讀→往返、讀不到檔、寫入失敗)以
## [code]prototypes/audio-story001-probes-2026-11-06/[/code] 探針實跑驗證。
class_name SettingsFileStore
extends RefCounted

const DEFAULT_PATH: String = "user://settings.cfg"

var path: String = DEFAULT_PATH


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


## 讀整個檔;檔不存在或打不開回傳空字串(視為「用預設」)。
func read_text() -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## 寫整個檔;成功 true,失敗 false(不 push_error、不崩潰)。
func write_text(text: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	return true
