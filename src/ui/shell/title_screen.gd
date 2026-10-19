## 遊戲殼層 Epic,story-001(標題畫面與場景切換骨架)。
## 本畫面是本專案第一個「戰鬥外」狀態 —— 開機進入點,也是戰鬥結束後的歸宿。
## 依 `production/epics/game-shell/EPIC.md` 與其量測依據
## `docs/reviews/shell-layer-feasibility-2026-10-19.md` 實作:`change_scene_to_file()`
## 是混合時機(舊場景同步移除、新場景延後掛載),`CursorStateHost` 跨場景為同一實例
## 且 `_process()` 未被中斷 —— 兩者皆已有引擎原始 log 佐證,本檔不重新假設。
##
## 🔴 AC9(本畫面不得向 `CursorStateHost` 註冊任何表面):本檔案全文不出現
## `CursorStateHost` 或 `register_surface` —— 疊加型選單依 ADR-0005 Core Rules #7
## 本來就排除在游標註冊制之外(比照 [code]src/ui/menu/battle_menu.gd[/code] 的既有
## 做法),走的是引擎原生 [Button] focus + [code]ui_accept[/code],不是本系統的
## 裝置權威判定路徑。若日後有人想讓本畫面註冊表面,依 EPIC 全域硬性實作義務,
## 必須同時接一條 `tree_exited -> unregister_surface` 並在這裡寫明理由。
##
## 導覽機制比照 [code]battle_menu.gd[/code],不另外發明第二套(本 epic 明文禁止
## 下游系統各自重實作裝置權威判定):[member Control.focus_mode] =
## [constant Control.FOCUS_ALL] + 手動接 [member Control.focus_neighbor_top] /
## [member Control.focus_neighbor_bottom] 做出「有界、不環繞」的清單 —— 原生
## [Button] 本身已同時處理滑鼠點擊與 [code]ui_accept[/code](兩者皆觸發
## [signal BaseButton.pressed]),不需要額外的輸入分派邏輯,也因此滿足 AC7
## 「鍵盤方向鍵、手把 d-pad、滑鼠」三種輸入方式。
## 🔴 AC10(字級/版面在 1920×1080 / 2560×1440 下不溢出、字級走既有縮放規則)
## 今天【未落地】,是明文登記的缺口,不是遺漏:本畫面目前沒有呼叫
## [code]src/ui/battle/world_layout.gd[/code] 的 [code]compute_scale()[/code],
## [code]TitleScreen.tscn[/code] 的 [code]Panel[/code] 是寫死的 320×160 偏移,
## 不隨解析度縮放。AC10 本身是 ADVISORY、需要管理者截圖簽核,工作單明文「今天
## 不驗收」——選擇今天不接 [code]compute_scale()[/code],留給簽核前的視覺收尾一併
## 處理,避免在還沒有人看過畫面長相之前,先用猜測的版面去套一個真正的縮放公式。
class_name TitleScreen
extends Control

## AC8 —— 三個可見文字的在地化 key,對應 `assets/data/locales/strings.csv`
## 新增的三列。全文字一律經 [method Loc.localize],不得硬編中文字面值。
const TEXT_START_BATTLE: StringName = &"shell.title.start_battle"
const TEXT_SETTINGS: StringName = &"shell.title.settings"
const TEXT_QUIT: StringName = &"shell.title.quit"

## AC4 —— 「開始戰鬥」的切換目標。與 `battle_screen.gd` 的
## `_TITLE_SCENE_PATH`(AC5 用,切回本畫面)是一對互相指向的常數,各自只知道
## 對方的路徑字串 —— 本專案目前只有這兩個「戰鬥外/戰鬥中」場景,未另抽共用路徑
## 常數檔;若殼層第三個場景出現(story-003),屆時應重新評估是否該抽成共用資源。
const _BATTLE_SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

@onready var _start_battle_row: Button = $Panel/ContentMargin/Rows/StartBattleRow
@onready var _settings_row: Button = $Panel/ContentMargin/Rows/SettingsRow
@onready var _quit_row: Button = $Panel/ContentMargin/Rows/QuitRow


func _ready() -> void:
	_start_battle_row.text = Loc.localize(TEXT_START_BATTLE)
	_settings_row.text = Loc.localize(TEXT_SETTINGS)
	_quit_row.text = Loc.localize(TEXT_QUIT)

	# AC3 —— 設定項目以停用狀態呈現,不是「可點但無反應」,也不是「暫代的假畫面」
	# (story-002 落地前,這顆鈕唯一合法的狀態就是「看得見、按不動」)。focus_mode
	# 一併設 FOCUS_NONE,讓它結構上被排除在鍵盤/手把焦點導覽之外 —— 停用的項目
	# 本來就不該能被「選取」,這是本實作對 AC7「三個項目可導覽」的解讀:指整個選單
	# 支援三種輸入裝置,不是要求一個停用項目也能被選取(與標準無障礙慣例一致,
	# 已在本檔 doc comment 與任務回報中明文揭露這個解讀,供覆核)。
	_settings_row.disabled = true
	_settings_row.focus_mode = Control.FOCUS_NONE

	# AC7 —— 比照 battle_menu.gd:FOCUS_ALL + 手動 focus_neighbor,做出有界
	# (不環繞)的二項清單。中間被跳過的 SettingsRow 因為上面已設 FOCUS_NONE,
	# 不會被焦點導覽選到 —— 等 story-002 把它改回可用狀態時,再補上它自己的
	# focus_neighbor 連線即可,本檔不預先假設它的位置。
	_start_battle_row.focus_mode = Control.FOCUS_ALL
	_quit_row.focus_mode = Control.FOCUS_ALL
	_start_battle_row.focus_neighbor_top = _start_battle_row.get_path_to(_start_battle_row)
	_start_battle_row.focus_neighbor_bottom = _start_battle_row.get_path_to(_quit_row)
	_quit_row.focus_neighbor_top = _quit_row.get_path_to(_start_battle_row)
	_quit_row.focus_neighbor_bottom = _quit_row.get_path_to(_quit_row)

	_start_battle_row.pressed.connect(start_battle)
	_quit_row.pressed.connect(_on_quit_pressed)

	_start_battle_row.grab_focus()


## AC4 —— 測試直接呼叫本方法,不模擬 [InputEvent](headless 不送 InputEvent,
## `.claude/docs/coding-standards.md` CI 節已登記;AC4 原文同一慣例)。
func start_battle() -> void:
	get_tree().change_scene_to_file(_BATTLE_SCENE_PATH)


## 「離開遊戲」—— 本畫面是全新場景,沒有 `BattleMenu` 的離開確認語意可繼承,
## 也不在本 story 範圍內新增一個(EPIC「本 epic 不涵蓋」節:不改
## `BattleMenu` 的離開確認語意;本畫面是另一個檔案,未被該條禁令觸及,但基於同一精神
## 保持最小 —— 標題畫面尚未開始任何戰鬥進度,沒有「進度會消失」的風險需要攔截)。
func _on_quit_pressed() -> void:
	get_tree().quit()
