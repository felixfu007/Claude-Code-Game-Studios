## 玩家可調設定狀態:效果猜測標記(EGM)、隱藏好感度顯示,以及音量/靜音
## (audio-foundation story-001)。
## EGM 規格:`design/quick-specs/battle-hud-prediction-marker.md`。
##
## [b]設定值住在哪裡[/b](game-shell story-002 的原決定,仍有效)—— 【static var 於一個小型
## 設定類別】,不是 Autoload:新增 Autoload 須同步改 `.claude/docs/technical-preferences.md`
## 的 Autoload 表,static var 完全不經 Autoload 機制,不觸發該義務。
##
## [b]持久化(2026-11-06 管理者裁決,取代 game-shell story-002 原「跨啟動不持久化」)[/b]:
## 六項設定(EGM、隱藏好感度、主音量、音樂、音效、靜音)存進小型設定檔
## [code]user://settings.cfg[/code]([ConfigFile] 文字,由 [SettingsCodec] 編解碼、
## [SettingsFileStore] 讀寫)。【不經 ADR-0004 存檔系統】(它仍 Proposed 且不在 12 個月範圍內);
## 歷史脈絡:原先本類別明文「重啟回預設」,是因為當時沒有設定檔這條路。
##
## [b]啟動接點[/b]:[code]TitleScreen._ready()[/code] 呼叫一次 [method boot_load]
## ([code]project.godot[/code] 開機場景即標題畫面,故不需要 Autoload)。
## 🔴 [b]已知代價[/b]:從編輯器以 F6 單獨跑戰鬥/設定場景時不經標題畫面,
## 不會載入設定檔,用預設值。
##
## [b]測試污染防線[/b]:
## 1. 持久化【預設關閉】,只有 [method boot_load] 才啟用;setter 只在已啟用時寫檔。
## 2. headless 下 [method boot_load] 是 no-op → 全套自動測試零檔案讀寫。
## 3. [method reset_for_test] 恢復預設、關閉持久化、清除已載入旗標,且【絕不寫檔】。
## 4. 路徑可注入;探針與開窗證據驅動器必須注入暫存路徑,禁用預設路徑(紀律,無自動檢查)。
##
## 🔴 [b]跨測試共用狀態[/b]:static 欄位在整個 headless 測試期間只有一份,任何呼叫 setter
## 的測試都必須在收尾呼叫 [method reset_for_test]。
class_name GameSettings
extends RefCounted

## 音量預設值 —— 🔴 未驗證初值(保守:首次啟動不突然大聲),家中實聽後可能調。
const DEFAULT_MASTER_VOLUME: float = 0.7
const DEFAULT_MUSIC_VOLUME: float = 0.5
const DEFAULT_SFX_VOLUME: float = 0.7
const DEFAULT_MUTED: bool = false

## 效果猜測標記(EGM)是否開啟。預設關閉 —— EGM 關閉時行為必須與現狀完全相同。
static var _egm_enabled: bool = false

## 隱藏好感度顯示(story-009,驗收協議 2 忽視組用)。預設關閉 = 現行行為。
## 只影響【顯示】:好感度照常計算,戰鬥結算不變。BattleScreen 同 EGM,只在 _ready() 讀一次。
static var _hide_affinity_display: bool = false

static var _master_volume: float = DEFAULT_MASTER_VOLUME
static var _music_volume: float = DEFAULT_MUSIC_VOLUME
static var _sfx_volume: float = DEFAULT_SFX_VOLUME
static var _muted: bool = DEFAULT_MUTED

## 持久化狀態。_store 為 null 或 _persist_enabled 為 false 時 setter 不寫檔。
static var _persist_enabled: bool = false
static var _store: SettingsFileStore = null
static var _boot_loaded: bool = false


## 讀取 EGM 目前設定值。[BattleScreen] 依 AC2 在 [method Node._ready] 只呼叫一次
## 並快取結果(不支援戰鬥中途熱切換);本方法每次都讀即時值,快取責任在呼叫端。
static func is_egm_enabled() -> bool:
	return _egm_enabled


## 寫入 EGM 設定值。已啟用持久化則立即存檔。
static func set_egm_enabled(value: bool) -> void:
	_egm_enabled = value
	_save_if_enabled()


## 讀取「隱藏好感度顯示」目前設定值(預設 false)。
static func is_hide_affinity_display() -> bool:
	return _hide_affinity_display


## 寫入「隱藏好感度顯示」。已啟用持久化則立即存檔。
static func set_hide_affinity_display(value: bool) -> void:
	_hide_affinity_display = value
	_save_if_enabled()


## 主音量(線性 0~1)。
static func get_master_volume() -> float:
	return _master_volume


## 寫入主音量;超出 [0,1] 夾制,不報錯。已啟用持久化則存檔。
static func set_master_volume(value: float) -> void:
	_master_volume = _clamp01(value)
	_save_if_enabled()


## 音樂音量(線性 0~1)。
static func get_music_volume() -> float:
	return _music_volume


static func set_music_volume(value: float) -> void:
	_music_volume = _clamp01(value)
	_save_if_enabled()


## 音效音量(線性 0~1)。
static func get_sfx_volume() -> float:
	return _sfx_volume


static func set_sfx_volume(value: float) -> void:
	_sfx_volume = _clamp01(value)
	_save_if_enabled()


## 是否靜音。靜音不改寫三個音量值。
static func is_muted() -> bool:
	return _muted


static func set_muted(value: bool) -> void:
	_muted = value
	_save_if_enabled()


## 六項預設值(鍵為 [SettingsCodec].KEY_*),供編解碼回退用。
static func default_values() -> Dictionary:
	return {
		SettingsCodec.KEY_EGM: false,
		SettingsCodec.KEY_HIDE_AFFINITY: false,
		SettingsCodec.KEY_MASTER: DEFAULT_MASTER_VOLUME,
		SettingsCodec.KEY_MUSIC: DEFAULT_MUSIC_VOLUME,
		SettingsCodec.KEY_SFX: DEFAULT_SFX_VOLUME,
		SettingsCodec.KEY_MUTED: DEFAULT_MUTED,
	}


## 目前六項設定的快照(鍵為 [SettingsCodec].KEY_*)。
static func snapshot() -> Dictionary:
	return {
		SettingsCodec.KEY_EGM: _egm_enabled,
		SettingsCodec.KEY_HIDE_AFFINITY: _hide_affinity_display,
		SettingsCodec.KEY_MASTER: _master_volume,
		SettingsCodec.KEY_MUSIC: _music_volume,
		SettingsCodec.KEY_SFX: _sfx_volume,
		SettingsCodec.KEY_MUTED: _muted,
	}


## 把目前音量/靜音套用到 [AudioServer](薄入口;headless 下無實際輸出)。
static func apply_audio_to_engine() -> void:
	AudioBuses.apply_settings(_master_volume, _music_volume, _sfx_volume, _muted)


## 持久化是否已啟用(診斷/測試用)。
static func is_persistence_enabled() -> bool:
	return _persist_enabled


## 啟動接點(由 `TitleScreen._ready()` 呼叫一次)。冪等:只有第一次實際載入。
## 啟用持久化 → 讀檔解碼(壞資料回預設,不寫回)→ 套用音量到 AudioServer。
## headless 下為 no-op(回傳 false,不讀不寫),所以自動測試零檔案存取。
## [param store] 可注入(測試傳假薄殼;預設用 [constant SettingsFileStore.DEFAULT_PATH])。
## [param headless] 預設自動偵測;只有測試為驗證載入邏輯才覆寫。
## 回傳是否真的執行了載入。
static func boot_load(store: SettingsFileStore = null, headless: bool = _detect_headless()) -> bool:
	if headless or _boot_loaded:
		return false
	_boot_loaded = true
	_store = store if store != null else SettingsFileStore.new()
	var values: Dictionary = SettingsCodec.decode(_store.read_text(), default_values())
	_egm_enabled = bool(values[SettingsCodec.KEY_EGM])
	_hide_affinity_display = bool(values[SettingsCodec.KEY_HIDE_AFFINITY])
	_master_volume = float(values[SettingsCodec.KEY_MASTER])
	_music_volume = float(values[SettingsCodec.KEY_MUSIC])
	_sfx_volume = float(values[SettingsCodec.KEY_SFX])
	_muted = bool(values[SettingsCodec.KEY_MUTED])
	_persist_enabled = true
	apply_audio_to_engine()
	return true


## 測試專用:恢復全部預設,關閉持久化、清除已載入旗標與薄殼,且【絕不寫檔】。
## 任何呼叫 setter 的測試都必須在收尾呼叫本方法。
static func reset_for_test() -> void:
	_egm_enabled = false
	_hide_affinity_display = false
	_master_volume = DEFAULT_MASTER_VOLUME
	_music_volume = DEFAULT_MUSIC_VOLUME
	_sfx_volume = DEFAULT_SFX_VOLUME
	_muted = DEFAULT_MUTED
	_persist_enabled = false
	_store = null
	_boot_loaded = false


## 測試專用:以注入的薄殼啟用持久化(不經 [method boot_load] 的 headless 判斷)。
static func enable_persistence_for_test(store: SettingsFileStore) -> void:
	_store = store
	_persist_enabled = true


static func _detect_headless() -> bool:
	return DisplayServer.get_name() == "headless"


static func _clamp01(value: float) -> float:
	if is_nan(value):
		return 0.0
	return clampf(value, 0.0, 1.0)


static func _save_if_enabled() -> void:
	if not _persist_enabled or _store == null:
		return
	_store.write_text(SettingsCodec.encode(snapshot()))


## 測試專用:只注入薄殼、【不】啟用持久化(驗證「未啟用時 setter 不寫檔」,AC-9)。
static func inject_store_without_enabling_for_test(store: SettingsFileStore) -> void:
	_store = store
	_persist_enabled = false
