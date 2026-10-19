## 本次執行期間有效的玩家可調設定狀態 —— 目前只有一項:效果猜測標記
## (Effect-Guess Marker,EGM,`design/quick-specs/battle-hud-prediction-marker.md`)
## 的開關。
##
## [b]Story 002(`production/epics/game-shell/story-002-minimal-settings-screen.md`)
## 主要技術決定:設定值住在哪裡[/b] —— 本類別選用【static var 於一個小型設定類別】,
## 不是 Autoload,也不是存檔系統。理由:
## 1. 新增 Autoload 的代價是必須同步更新 [code].claude/docs/technical-preferences.md[/code]
##    的 Autoload 表 —— 那是既有文件,依 2026-10-12 管理者裁決,改動既有文件須先問
##    管理者;本 story 的工作單明文要求碰到這個分岔時停下回報,不要為了避開它而
##    改選較差的方案,也不要擅自改動該文件。static var 方案完全不經過 Autoload
##    機制(不出現在 [code]project.godot[/code] 的 [code][autoload][/code] 節),
##    不觸發這個義務。
## 2. 存檔系統(第三條路)已被工作單明文排除:ADR-0004 仍 [code]Proposed[/code],
##    且依一年計畫明確不在 12 個月範圍內。
## 3. 本類別目前只有一個布林欄位,沒有初始化順序或跨單例依賴的需求 ——
##    Autoload 解決的「場景啟動時機」問題在這裡不存在,靜態欄位從程式一啟動就有
##    確定的預設值(見下方 [member _egm_enabled] 的宣告式預設值,不需要任何
##    [code]_ready()[/code] 或 [code]_init()[/code] 時機才會就緒)。
##
## [b]已知代價(裁決接受,工作單明文要求寫成 doc comment,不要讓下一個人以為它
## 壞了)[/b]:
## 1. 🔴 [b]跨啟動不持久化[/b] —— [code]static var[/code] 的值只在本次程式執行期間
##    存在,重啟遊戲會回到下方宣告的預設值 [code]false[/code]。這是工作單明文
##    範圍:「本階段不要求跨啟動持久化」——「關掉遊戲再開還記得」需要存檔系統,
##    不在本 story 範圍內,也呼應
##    `design/quick-specs/battle-hud-prediction-marker.md` 第 5 節對一致率統計
##    本身的同一類裁決(「不持久化,只留記憶體,關閉遊戲即歸零」)。
## 2. 🔴 [b]跨測試共用狀態[/b] —— 本類別的靜態欄位在整個 headless 測試執行期間
##    只有一份,若某條測試呼叫 [method set_egm_enabled] 卻忘記在收尾還原,會污染
##    後續任何依賴預設值 [code]false[/code] 的測試,即使那些測試與 EGM 完全無關。
##    因此提供 [method reset_for_test],任何呼叫 [method set_egm_enabled] 的測試
##    都必須在收尾呼叫它 —— 與
##    `.claude/docs/technical-preferences.md` Autoload 表「同一個 Autoload 實例被
##    全部測試共用」段落記載的是同一類風險,只是這裡是 static var 版本。
class_name GameSettings
extends RefCounted

## 效果猜測標記(EGM)是否開啟。預設關閉 —— 規格 AC1 要求的迴歸安全:EGM 關閉時
## 行為必須與現狀完全相同。
static var _egm_enabled: bool = false


## 讀取 EGM 目前設定值。[BattleScreen] 依 AC2 在 [method Node._ready] 只呼叫一次
## 並快取結果,整場戰鬥不再重讀 —— 這是規格「不支援戰鬥中途熱切換」的落地點
## (見 [code]battle_screen.gd[/code] 的 [code]_egm_enabled_for_this_battle[/code])。
## 本方法本身不做任何快取或節流,每次呼叫都讀取目前的即時值,快取責任在呼叫端。
static func is_egm_enabled() -> bool:
	return _egm_enabled


## 寫入 EGM 設定值。設定畫面(`settings_screen.gd`)在玩家切換開關時呼叫;
## 已在進行中的戰鬥不受影響(AC3)—— 因為 [BattleScreen] 從不重讀本類別,
## 只有下一場新戰鬥的 [method Node._ready] 才會看到新值。
static func set_egm_enabled(value: bool) -> void:
	_egm_enabled = value


## 測試專用:將本類別的靜態狀態重置回預設值。任何呼叫 [method set_egm_enabled] 的
## 測試都必須在收尾呼叫本方法,避免污染同一次 headless 執行期間的其他測試
## (見本檔類別文件註解「已知代價」第 2 點)。
static func reset_for_test() -> void:
	_egm_enabled = false
