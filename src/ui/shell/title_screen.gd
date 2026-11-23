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
const TEXT_SKIP_TUTORIAL: StringName = &"shell.title.skip_tutorial"
const TEXT_SETTINGS: StringName = &"shell.title.settings"
const TEXT_QUIT: StringName = &"shell.title.quit"

## campfire story-014:「繼續」/「新遊戲」與確認框文字 key。
const TEXT_CONTINUE: StringName = &"shell.title.continue"
const TEXT_CONTINUE_NO_PROGRESS: StringName = &"shell.title.continue_no_progress"
const TEXT_NEW_GAME: StringName = &"shell.title.new_game"
const TEXT_CONFIRM_TITLE: StringName = &"shell.title.new_game_confirm_title"
const TEXT_CONFIRM_BODY: StringName = &"shell.title.new_game_confirm_body"
const TEXT_CONFIRM_CANCEL: StringName = &"shell.title.new_game_confirm_cancel"
const TEXT_CONFIRM_RESTART: StringName = &"shell.title.new_game_confirm_restart"

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

## story-010 —— 遊戲名稱的在地化 key(不可寫死在場景裡)。
const TEXT_GAME_NAME: StringName = &"shell.title.game_name"

@onready var _game_name_label: Label = $Panel/ContentMargin/Rows/GameNameLabel
@onready var _continue_row: Button = $Panel/ContentMargin/Rows/ContinueRow
## 節點名沿用 StartBattleRow(既有測試依名稱取用),文字與語意為「新遊戲」。
@onready var _start_battle_row: Button = $Panel/ContentMargin/Rows/StartBattleRow
@onready var _skip_tutorial_row: Button = $Panel/ContentMargin/Rows/SkipTutorialRow
@onready var _settings_row: Button = $Panel/ContentMargin/Rows/SettingsRow
@onready var _quit_row: Button = $Panel/ContentMargin/Rows/QuitRow
@onready var _confirm_overlay: Control = $ConfirmOverlay
@onready var _confirm_title_label: Label = $ConfirmOverlay/Panel/ContentMargin/Content/TitleLabel
@onready var _confirm_body_label: Label = $ConfirmOverlay/Panel/ContentMargin/Content/BodyLabel
@onready var _confirm_cancel: Button = $ConfirmOverlay/Panel/ContentMargin/Content/CancelButton
@onready var _confirm_restart: Button = $ConfirmOverlay/Panel/ContentMargin/Content/RestartButton

## 確認框開啟時,確認後要走的動作(新遊戲 / 略過教學)。
var _pending_restart: Callable = Callable()


func _ready() -> void:
	# audio-foundation story-001 —— 設定檔載入的啟動接點(開機場景即本畫面)。冪等;
	# headless 下為 no-op。代價:編輯器 F6 單跑戰鬥/設定場景不經此處,用預設值。
	GameSettings.boot_load()
	# audio-foundation story-003:開機場景不經 SceneRouter,自行加一個音效宿主(attach_to 冪等)。
	SfxPlayerHost.attach_to(self)
	# audio-foundation story-004:開機場景同樣自行確保音樂宿主(掛 root、冪等)並通知「標題」。
	MusicPlayerHost.ensure_on_root(get_tree()).enter_scene(MusicTrackTable.KEY_TITLE)

	# story-010 —— 遊戲名稱:HUD 點陣字 Cubic 11,字級 = HudLayout.font_size()
	# (倍率唯一出自 WorldLayout.compute_scale(),不自行計算)。純顯示、不可聚焦,
	# 不參與下方的焦點接線。
	_game_name_label.text = Loc.localize(TEXT_GAME_NAME)
	_game_name_label.add_theme_font_override(&"font", HudLayoutScaler.HUD_FONT)
	_apply_game_name_font_size()
	get_viewport().size_changed.connect(_apply_game_name_font_size)

	_start_battle_row.text = Loc.localize(TEXT_NEW_GAME)
	_skip_tutorial_row.text = Loc.localize(TEXT_SKIP_TUTORIAL)
	_settings_row.text = Loc.localize(TEXT_SETTINGS)
	_quit_row.text = Loc.localize(TEXT_QUIT)

	# Story-002(AC4)—— 「設定」鈕解除停用,接上 open_settings()。這顆鈕原本
	# (story-001)是明文的停用佔位狀態,不是「可點但無反應」;本行是那個登記在案的
	# 缺口落地的地方,不是繞過它。

	# AC5(本 story)/ AC7(story-001)—— 比照 battle_menu.gd:FOCUS_ALL + 手動
	# focus_neighbor,做出有界(不環繞)的三項清單。
	_confirm_title_label.text = Loc.localize(TEXT_CONFIRM_TITLE)
	_confirm_body_label.text = Loc.localize(TEXT_CONFIRM_BODY)
	_confirm_cancel.text = Loc.localize(TEXT_CONFIRM_CANCEL)
	_confirm_restart.text = Loc.localize(TEXT_CONFIRM_RESTART)
	_confirm_cancel.focus_neighbor_top = _confirm_cancel.get_path_to(_confirm_cancel)
	_confirm_cancel.focus_neighbor_bottom = _confirm_cancel.get_path_to(_confirm_restart)
	_confirm_restart.focus_neighbor_top = _confirm_restart.get_path_to(_confirm_cancel)
	_confirm_restart.focus_neighbor_bottom = _confirm_restart.get_path_to(_confirm_restart)
	_confirm_cancel.focus_mode = Control.FOCUS_ALL
	_confirm_restart.focus_mode = Control.FOCUS_ALL

	refresh_progress_state()

	# story-008:「開始」-> 教學第 1 場;「略過教學」-> 戰役第 1 場(即原本「開始」的行為)。
	_continue_row.pressed.connect(continue_game)
	_start_battle_row.pressed.connect(new_game)
	_skip_tutorial_row.pressed.connect(skip_tutorial)
	_confirm_cancel.pressed.connect(cancel_confirm)
	_confirm_restart.pressed.connect(confirm_restart)
	_settings_row.pressed.connect(open_settings)
	_quit_row.pressed.connect(_on_quit_pressed)

	# Story-004 —— 見 [constant AUTO_START_BATTLE_FLAG] 的 doc comment。放在
	# _ready() 的最後面,讓本畫面先完成一次正常初始化(文字、focus 接線)再決定
	# 要不要立刻切走,不改變上面每一行原本的行為。
	if should_auto_start_battle(OS.get_cmdline_args()):
		start_battle()


## campfire story-014:依「本次遊玩是否有進度」設定「繼續」狀態、焦點接線與預設焦點。
## 兩顆鈕位置固定(不隱藏);無進度時「繼續」停用、不可聚焦,上下鄰居接線一律不指向它。
func refresh_progress_state() -> void:
	var progress: bool = _has_progress()
	_apply_continue_availability(progress)
	var items: Array[Button] = []
	if progress:
		items.append(_continue_row)
	items.append_array([_start_battle_row, _skip_tutorial_row, _settings_row, _quit_row])
	for i: int in items.size():
		var row: Button = items[i]
		row.focus_mode = Control.FOCUS_ALL
		var up: Button = items[maxi(i - 1, 0)]
		var down: Button = items[mini(i + 1, items.size() - 1)]
		row.focus_neighbor_top = row.get_path_to(up)
		row.focus_neighbor_bottom = row.get_path_to(down)
	items[0].grab_focus()


## 可被覆寫(測試變種):是否有進度。
func _has_progress() -> bool:
	return CampaignProgress.has_progress()


## 可被覆寫(測試變種):依進度設定「繼續」的停用與文字。
func _apply_continue_availability(has_progress: bool) -> void:
	_continue_row.visible = true
	_continue_row.disabled = not has_progress
	_continue_row.text = Loc.localize(TEXT_CONTINUE if has_progress else TEXT_CONTINUE_NO_PROGRESS)
	if not has_progress:
		_continue_row.focus_mode = Control.FOCUS_NONE


## story-010 —— 依目前視窗尺寸重設名稱字級。
func _apply_game_name_font_size() -> void:
	# 已離樹(場景切換後尚未被釋放)時 viewport 為 null;size_changed 連線仍會觸發。
	if not is_inside_tree():
		return
	var window_size: Vector2i = Vector2i(get_viewport().get_visible_rect().size)
	_game_name_label.add_theme_font_size_override(&"font_size", HudLayout.font_size(window_size))


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


## 「繼續」:回到目前場次(累積記錄與牌組保留)。無進度時無作用。
func continue_game() -> void:
	if not _has_progress():
		return
	SceneRouter.enter_battle(get_tree())


## 「新遊戲」:有進度先跳確認框,無進度直接開始。
func new_game() -> void:
	_request_restart(_start_fresh_campaign)


## 「略過教學」:同樣會清掉本次進度,所以有進度時同樣先確認。
func skip_tutorial() -> void:
	_request_restart(_start_fresh_campaign_skipping_tutorial)


func is_confirm_open() -> bool:
	return _confirm_overlay.visible


func cancel_confirm() -> void:
	_confirm_overlay.hide()
	_pending_restart = Callable()
	_start_battle_row.grab_focus()


func confirm_restart() -> void:
	var action: Callable = _pending_restart
	_confirm_overlay.hide()
	_pending_restart = Callable()
	if action.is_valid():
		action.call()


func _request_restart(action: Callable) -> void:
	if not _has_progress():
		action.call()
		return
	_pending_restart = action
	_confirm_overlay.show()
	_confirm_cancel.grab_focus()


## 可被覆寫(測試變種):清掉本次進度並從教學開始。
func _start_fresh_campaign() -> void:
	CampaignProgress.reset_campaign()
	start_tutorial()


func _start_fresh_campaign_skipping_tutorial() -> void:
	CampaignProgress.reset_campaign()
	start_battle()


func _unhandled_input(event: InputEvent) -> void:
	if is_confirm_open() and event.is_action_pressed(&"ui_cancel"):
		cancel_confirm()
		get_viewport().set_input_as_handled()


## story-008 AC1:「開始」—— 從教學第 1 場開始。
func start_tutorial() -> void:
	TutorialProgress.begin()
	SceneRouter.enter_tutorial_battle(get_tree())


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
