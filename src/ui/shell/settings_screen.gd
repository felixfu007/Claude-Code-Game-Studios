## 遊戲殼層 Epic,story-002(最小設定畫面,EGM 開關落地)。
## 本畫面是 story-001 TitleScreen 之後,殼層系統第二個「戰鬥外」畫面 ——
## 玩家從標題畫面的「設定」鈕進入,調整效果猜測標記
## (Effect-Guess Marker,EGM,`design/quick-specs/battle-hud-prediction-marker.md`)
## 開關,再返回標題畫面。
##
## 🔴 本畫面不向 [CursorStateHost] 註冊任何表面(與 `title_screen.gd` 同一理由、
## 同一做法,不重新發明):疊加型/獨立全螢幕畫面依 ADR-0005 Core Rules #7
## 本來就排除在游標註冊制之外,走引擎原生 [CheckButton]/[Button] focus +
## [code]ui_accept[/code],不是本系統的裝置權威判定路徑。本檔案全文不出現
## [code]CursorStateHost[/code] 或 [code]register_surface[/code]。
##
## 導覽機制比照 `title_screen.gd` / `battle_menu.gd`,不另外發明第二套:
## [member Control.focus_mode] = [constant Control.FOCUS_ALL] + 手動接
## [member Control.focus_neighbor_top] / [member Control.focus_neighbor_bottom]
## 做出「有界、不環繞」的二項清單。[CheckButton] extends [Button],原生同時
## 處理滑鼠點擊、[code]ui_accept[/code] 與 [signal BaseButton.toggled] ——
## 不需要額外的輸入分派邏輯即可滿足 AC5「鍵盤方向鍵、手把 d-pad、滑鼠」三種
## 輸入方式平權。
##
## [b]設定值住在哪裡(本 story 主要技術決定,工作單「開工前必答的一題」)[/b]:
## 選用 [GameSettings](`src/core/settings/game_settings.gd`)的 static var 方案,
## 不是 Autoload——理由與已知代價見該檔案類別文件註解,實機驗證見
## `prototypes/godot-specialist-static-var-probe-2026-10-19/README.md`。本畫面只是
## [GameSettings] 的其中一個讀寫端,不持有任何設定狀態的真實來源。
##
## 🔴 AC9(字級/版面於 1920×1080 / 2560×1440 下不溢出,字級走
## [method WorldLayout.compute_scale] 既有縮放規則)今天【未落地】,登記為明文缺口,
## 不是遺漏——比照 `title_screen.gd` 對 AC10 的同一類揭露:本畫面目前沒有呼叫
## [code]src/ui/battle/world_layout.gd[/code] 的 [method WorldLayout.compute_scale],
## [code]SettingsScreen.tscn[/code] 的 [code]Panel[/code] 是寫死的 320×160 偏移
## (與 `TitleScreen.tscn` 完全相同的數值,同一類判斷call),不隨解析度縮放。
## AC9 本身是 ADVISORY、需要管理者在家看畫面簽核,工作單明文「今天不驗收」。
class_name SettingsScreen
extends Control

## 三個可見文字的在地化 key,對應 `assets/data/locales/strings.csv` 新增的列。
## 全文字一律經 [method Loc.localize],不得硬編中文字面值(AC7)。
const TEXT_EGM_TOGGLE: StringName = &"shell.settings.egm_toggle"
const TEXT_HIDE_AFFINITY_TOGGLE: StringName = &"shell.settings.hide_affinity_toggle"
const TEXT_BACK: StringName = &"shell.settings.back"

## 場景路徑的單一出處是 [SceneRouter](story-005),本檔不再持有任何場景路徑常數。

@onready var _egm_toggle_row: CheckButton = $Panel/ContentMargin/Rows/EgmToggleRow
@onready var _hide_affinity_row: CheckButton = $Panel/ContentMargin/Rows/HideAffinityRow
@onready var _back_row: Button = $Panel/ContentMargin/Rows/BackRow


func _ready() -> void:
	_egm_toggle_row.text = Loc.localize(TEXT_EGM_TOGGLE)
	_hide_affinity_row.text = Loc.localize(TEXT_HIDE_AFFINITY_TOGGLE)
	_back_row.text = Loc.localize(TEXT_BACK)

	# AC1/AC4 —— 進畫面時把開關顯示值同步成 GameSettings 目前的真實值,而不是
	# CheckButton 節點宣告時的預設 false。只在這裡讀一次;之後的任何改動一律由
	# _on_egm_toggled() 寫回 GameSettings,畫面本身不持有第二份狀態。
	_egm_toggle_row.button_pressed = GameSettings.is_egm_enabled()
	_hide_affinity_row.button_pressed = GameSettings.is_hide_affinity_display()

	# AC5 —— 比照 title_screen.gd:FOCUS_ALL + 手動 focus_neighbor,做出有界
	# (不環繞)的二項清單。
	_egm_toggle_row.focus_mode = Control.FOCUS_ALL
	_hide_affinity_row.focus_mode = Control.FOCUS_ALL
	_back_row.focus_mode = Control.FOCUS_ALL
	_egm_toggle_row.focus_neighbor_top = _egm_toggle_row.get_path_to(_egm_toggle_row)
	_egm_toggle_row.focus_neighbor_bottom = _egm_toggle_row.get_path_to(_hide_affinity_row)
	_hide_affinity_row.focus_neighbor_top = _hide_affinity_row.get_path_to(_egm_toggle_row)
	_hide_affinity_row.focus_neighbor_bottom = _hide_affinity_row.get_path_to(_back_row)
	_back_row.focus_neighbor_top = _back_row.get_path_to(_hide_affinity_row)
	_back_row.focus_neighbor_bottom = _back_row.get_path_to(_back_row)

	_egm_toggle_row.toggled.connect(_on_egm_toggled)
	_hide_affinity_row.toggled.connect(_on_hide_affinity_toggled)
	_back_row.pressed.connect(back_to_title)

	_egm_toggle_row.grab_focus()


## 玩家切換開關時,立即寫回 [GameSettings](AC1 的唯一寫入點)。進行中的戰鬥
## 不受影響(AC3)—— 因為 [BattleScreen] 只在自己的 [method Node._ready] 讀一次,
## 不會重讀這裡剛寫入的新值;新值只對下一場尚未開始的戰鬥生效。
func _on_egm_toggled(button_pressed: bool) -> void:
	GameSettings.set_egm_enabled(button_pressed)


## story-009 —— 「隱藏好感度顯示」寫回點(同 EGM:進行中的戰鬥不受影響)。
func _on_hide_affinity_toggled(button_pressed: bool) -> void:
	GameSettings.set_hide_affinity_display(button_pressed)


## AC6 —— 測試直接呼叫本方法,不模擬 [InputEvent](headless 不送 InputEvent,
## `.claude/docs/coding-standards.md` CI 節已登記;`title_screen.gd` 的
## [method TitleScreen.start_battle] 同一慣例)。
func back_to_title() -> void:
	SceneRouter.go_to_title(get_tree())
