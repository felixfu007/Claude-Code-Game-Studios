class_name SceneRouter
extends RefCounted
## 單一的手動切場景入口。
##
## 為什麼不用 `SceneTree.change_scene_to_file()`:引擎自己做 instantiate() 加 add_child(),
## 中間不交棒,切場景方沒有機會在 `_ready()` 之前注入資料。本專案明文的唯一注入窗是
## 「instantiate() 之後、add_child() 之前」,所以改由這裡手動做。
##
## 延後機制:交換以 `Callable.call_deferred()` 執行(綁定 static 函式)。
## 理由:`TitleScreen._ready()` 在帶 --capture-battle 旗標時會直接呼叫切換;
## 在 `_ready()` 內同步 add_child 到 root 會被引擎拒絕("Parent node is busy setting up children")。
## 本檔的測試證明延後路徑可行(見 scene_router_test.gd)。

const TITLE_SCENE_PATH: String = "res://src/ui/shell/TitleScreen.tscn"
const BATTLE_SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const SETTINGS_SCENE_PATH: String = "res://src/ui/shell/SettingsScreen.tscn"
const SUPPORT_CONVERSATION_SCENE_PATH: String = "res://src/ui/shell/SupportConversationScreen.tscn"


## 載入並切換到指定場景。
## `configure` 若有效,會在新實例【尚未進樹】時被呼叫一次(參數為新實例),供呼叫端注入資料。
## 實際的「移除舊場景、加入新場景、設為 current_scene」延後到空閒時執行。
## 載入失敗時 push_error 並回傳 null(不切換)。回傳新實例(此刻尚未進樹)。
static func switch_to(tree: SceneTree, scene_path: String, configure: Callable = Callable()) -> Node:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("SceneRouter: cannot load scene '%s'" % scene_path)
		return null
	var instance: Node = packed.instantiate()
	if instance == null:
		push_error("SceneRouter: instantiate() returned null for '%s'" % scene_path)
		return null
	if configure.is_valid():
		configure.call(instance)
	_perform_swap.bind(tree, instance).call_deferred()
	return instance


## 進入戰鬥場景,並把戰役累積記錄交給新戰鬥畫面。
## `CampaignProgress.start_mission_affinity_ledger()` 自己會先呼叫 begin_mission(),
## 不要在這裡另外呼叫。
static func enter_battle(tree: SceneTree) -> Node:
	# game-shell story-008:進戰役 = 教學狀態結束(結構保證戰役戰鬥不會在教學模式下跑)。
	TutorialProgress.end()
	return switch_to(tree, BATTLE_SCENE_PATH, _inject_campaign_ledger)


## game-shell story-008:進入【教學場】戰鬥。刻意不注入戰役累積記錄、不碰
## [CampaignProgress](AC5);教學第幾場由 [TutorialProgress] 決定(戰敗重打同一場也走這裡)。
static func enter_tutorial_battle(tree: SceneTree) -> Node:
	return switch_to(tree, BATTLE_SCENE_PATH)


## 進入支援對話畫面(support-conversation-ui story-004)。
## 新實例進樹前注入 [param conversation_ids] 並接上 all_conversations_finished,
## 播畢後進下一場戰鬥([method enter_battle])。
static func go_to_support_conversation(tree: SceneTree, conversation_ids: Array[String]) -> Node:
	var configure: Callable = func(instance: Node) -> void:
		var screen: SupportConversationScreen = instance as SupportConversationScreen
		if screen == null:
			push_error("SceneRouter: go_to_support_conversation target is not a SupportConversationScreen")
			return
		screen.conversation_ids = conversation_ids.duplicate()
		screen.all_conversations_finished.connect(_enter_battle_after_conversations.bind(tree))
	return switch_to(tree, SUPPORT_CONVERSATION_SCENE_PATH, configure)


static func _enter_battle_after_conversations(tree: SceneTree) -> void:
	enter_battle(tree)


## 回到標題畫面。
static func go_to_title(tree: SceneTree) -> Node:
	return switch_to(tree, TITLE_SCENE_PATH)


## 前往設定畫面。
static func go_to_settings(tree: SceneTree) -> Node:
	return switch_to(tree, SETTINGS_SCENE_PATH)


static func _inject_campaign_ledger(instance: Node) -> void:
	var battle: BattleScreen = instance as BattleScreen
	if battle == null:
		push_error("SceneRouter: enter_battle target is not a BattleScreen")
		return
	battle.campaign_ledger_override = CampaignProgress.start_mission_affinity_ledger()


## 交換順序刻意為「先同步移除舊、再加新」:BattleScreen 在 tree_exited 上註銷游標表面,
## 舊的先離樹,新戰鬥進樹時 BOARD_TILE 才是空的(scene_router_test.gd 的 (d) 釘住這個順序可行)。
## ⚠️ 未驗證:「反過來(新的先進樹)註冊會被拒」是依 story-001 測試行為推論,從未實測過
## —— (d) 只證明了本順序可行,沒有證明另一個順序會失敗。2026-10-27 協調者覆核標註。
static func _perform_swap(tree: SceneTree, instance: Node) -> void:
	if not is_instance_valid(instance):
		return
	var old: Node = tree.current_scene
	if is_instance_valid(old) and old.is_inside_tree():
		old.get_parent().remove_child(old)
		old.queue_free()
	tree.root.add_child(instance)
	tree.current_scene = instance
