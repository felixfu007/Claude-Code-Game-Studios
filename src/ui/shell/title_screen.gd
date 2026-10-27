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
##
## 🔴 Story-004(2026-10-19 管理者裁決,工作單尚未落檔)—— 本畫面新增
## [constant AUTO_START_BATTLE_FLAG] 這個命令列後門旗標,見該常數的 doc comment。
class_name TitleScreen
extends Control

## AC8 —— 三個可見文字的在地化 key,對應 `assets/data/locales/strings.csv`
## 新增的三列。全文字一律經 [method Loc.localize],不得硬編中文字面值。
const TEXT_START_BATTLE: StringName = &"shell.title.start_battle"
const TEXT_SETTINGS: StringName = &"shell.title.settings"
const TEXT_QUIT: StringName = &"shell.title.quit"

## 場景路徑的單一出處是 [SceneRouter](story-005),本檔不再持有任何場景路徑常數。

## Story-004(`production/epics/game-shell/` ——
## 管理者 2026-10-19 裁決「今天補,跟著 story-002 一起做」,工作單尚未落檔)。
##
## [b]背景[/b]:story-001 把 [code]run/main_scene[/code] 從 [code]BattleScreen.tscn[/code]
## 改成本畫面之後,匯出建置開機進標題畫面,而
## [code]tools/build/capture_window.ps1[/code] 完全沒有輸入能力(不送
## [code]SendInput[/code]/[code]keybd_event[/code]/[code]mouse_event[/code])——
## 自動截「戰鬥畫面」當 QA 證據這條路因此失效:它只拍得到標題畫面。本專案至今
## 全部畫面缺陷都是人開圖看到的,截圖是那道防線的輸入,所以需要一個不靠
## 真實輸入就能跳過標題畫面、直接進戰鬥的後門。
##
## [b]用法[/b]:命令列帶上 [constant AUTO_START_BATTLE_FLAG] 這個旗標字串,
## [b]且【不要】用 [code]--[/code] 分隔符[/b]。例如:
## [code]BlindInTheFaintLight.exe --capture-battle[/code]。
##
## 🔴 [b]2026-10-19 協調者覆核更正 —— 原文宣稱「不論有無 [code]--[/code] 分隔符
## 都會原樣收進回傳陣列」,那句話被它自己引用的探針 log 推翻了。[/b]
## 實測逐字(`prototypes/godot-specialist-static-var-probe-2026-10-19/`):
## [codeblock]
## run_output_cmdline_args.txt(不帶 --):
##   get_cmdline_args()      = ["-s", "...probe_cmdline_args.gd", "--capture-battle"]
##   get_cmdline_user_args() = []
## run_output_cmdline_args_with_separator.txt(帶 --):
##   get_cmdline_args()      = ["-s", "...probe_cmdline_args.gd"]      ← 旗標不在這裡
##   get_cmdline_user_args() = ["--capture-battle"]                     ← 跑到另一個 API
## [/codeblock]
## [b]亦即:帶了 [code]--[/code] 的話,本旗標會安靜地完全失效[/b] ——
## [method should_auto_start_battle] 只看 [method OS.get_cmdline_args]。
## ⚠️ [b]這是已登記的已知限制,不是缺陷[/b]:截圖工具的呼叫形式是
## [code]exe --capture-battle[/code](無分隔符),在該形式下行為正確。
## 若日後有人改用 [code]--[/code] 形式,**它不會報錯,只會什麼都不做** ——
## 屆時正確的修法是讓 [method should_auto_start_battle] 同時檢查
## [method OS.get_cmdline_user_args],而不是去猜為什麼旗標沒生效。
##
## ✅ [code]tools/build/capture_window.ps1[/code] 的檔頭已補上對應說明
## (2026-10-19 協調者補做)。📌 **本行原文在補做之前就宣稱「已補上」,而該檔
## 當時一個字都沒被改過** —— 同一次覆核發現並更正。留這句話不是記過,是因為
## 這正是本專案登記最多次的失效形狀:**一句讀起來像已完成的敘述,
## 會讓下一個人去找一段不存在的東西,而且沒有任何東西會報錯。**
const AUTO_START_BATTLE_FLAG: String = "--capture-battle"

@onready var _start_battle_row: Button = $Panel/ContentMargin/Rows/StartBattleRow
@onready var _settings_row: Button = $Panel/ContentMargin/Rows/SettingsRow
@onready var _quit_row: Button = $Panel/ContentMargin/Rows/QuitRow


func _ready() -> void:
	_start_battle_row.text = Loc.localize(TEXT_START_BATTLE)
	_settings_row.text = Loc.localize(TEXT_SETTINGS)
	_quit_row.text = Loc.localize(TEXT_QUIT)

	# Story-002(AC4)—— 「設定」鈕解除停用,接上 open_settings()。這顆鈕原本
	# (story-001)是明文的停用佔位狀態,不是「可點但無反應」;本行是那個登記在案的
	# 缺口落地的地方,不是繞過它。

	# AC5(本 story)/ AC7(story-001)—— 比照 battle_menu.gd:FOCUS_ALL + 手動
	# focus_neighbor,做出有界(不環繞)的三項清單。
	_start_battle_row.focus_mode = Control.FOCUS_ALL
	_settings_row.focus_mode = Control.FOCUS_ALL
	_quit_row.focus_mode = Control.FOCUS_ALL
	_start_battle_row.focus_neighbor_top = _start_battle_row.get_path_to(_start_battle_row)
	_start_battle_row.focus_neighbor_bottom = _start_battle_row.get_path_to(_settings_row)
	_settings_row.focus_neighbor_top = _settings_row.get_path_to(_start_battle_row)
	_settings_row.focus_neighbor_bottom = _settings_row.get_path_to(_quit_row)
	_quit_row.focus_neighbor_top = _quit_row.get_path_to(_settings_row)
	_quit_row.focus_neighbor_bottom = _quit_row.get_path_to(_quit_row)

	_start_battle_row.pressed.connect(start_battle)
	_settings_row.pressed.connect(open_settings)
	_quit_row.pressed.connect(_on_quit_pressed)

	_start_battle_row.grab_focus()

	# Story-004 —— 見 [constant AUTO_START_BATTLE_FLAG] 的 doc comment。放在
	# _ready() 的最後面,讓本畫面先完成一次正常初始化(文字、focus 接線)再決定
	# 要不要立刻切走,不改變上面每一行原本的行為。
	if should_auto_start_battle(OS.get_cmdline_args()):
		start_battle()


## Story-004 —— 純函式:給定一組命令列參數,判斷是否應該自動跳過標題畫面直接
## 開始戰鬥。🔴 [b]抽成純函式(吃 [PackedStringArray] 而非本函式自己呼叫
## [method OS.get_cmdline_args])的理由[/b]:[method OS.get_cmdline_args] 在
## GdUnit4 headless 測試執行環境下實際回傳什麼內容,本次未查證 —— 誠實登記為
## 已知限制,不是忽略。本函式的判斷邏輯本身(「陣列裡有沒有這個字串」)因此可以
## 被測試直接驅動,`_ready()` 裡實際呼叫 [method OS.get_cmdline_args] 那一行
## 本身,未被自動化測試涵蓋,只能靠真的用旗標跑一次匯出建置手動驗證。
static func should_auto_start_battle(args: PackedStringArray) -> bool:
	return args.has(AUTO_START_BATTLE_FLAG)


## AC4 —— 測試直接呼叫本方法,不模擬 [InputEvent](headless 不送 InputEvent,
## `.claude/docs/coding-standards.md` CI 節已登記;AC4 原文同一慣例)。
## 經 [SceneRouter] 手動切場景(story-005):路由器在新戰鬥畫面進樹之前注入戰役累積記錄,
## 交換延後到空閒時執行,所以在 [method Node._ready] 期間呼叫(--capture-battle 路徑)也安全。
func start_battle() -> void:
	SceneRouter.enter_battle(get_tree())


## Story-002(AC4)—— 測試直接呼叫本方法,不模擬 [InputEvent],與
## [method start_battle] 同一慣例。
func open_settings() -> void:
	SceneRouter.go_to_settings(get_tree())


## 「離開遊戲」—— 本畫面是全新場景,沒有 `BattleMenu` 的離開確認語意可繼承,
## 也不在本 story 範圍內新增一個(EPIC「本 epic 不涵蓋」節:不改
## `BattleMenu` 的離開確認語意;本畫面是另一個檔案,未被該條禁令觸及,但基於同一精神
## 保持最小 —— 標題畫面尚未開始任何戰鬥進度,沒有「進度會消失」的風險需要攔截)。
func _on_quit_pressed() -> void:
	get_tree().quit()
