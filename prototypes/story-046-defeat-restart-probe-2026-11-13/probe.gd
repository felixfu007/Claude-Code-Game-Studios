extends Node
## story-046 probe: campaign defeat -> title -> press the row labelled "開始戰鬥" -> which battle?
## Run: godot --headless --path . res://prototypes/story-046-defeat-restart-probe-2026-11-13/Probe.tscn
## (scene, not -s: autoloads must be registered when the scripts compile)

func _ready() -> void:
	# Not the current scene: SceneRouter frees current_scene on swap and would kill this coroutine.
	get_tree().current_scene = null
	_run.call_deferred()

func _run() -> void:
	var tree: SceneTree = get_tree()
	CampaignProgress.reset_for_test()
	TutorialProgress.end()
	CampaignProgress.advance_on_victory(5)
	CampaignProgress.advance_on_victory(5)
	print("PROBE before: campaign mission=", CampaignProgress.current_mission(), " tutorial_active=", TutorialProgress.is_active())
	SceneRouter.enter_battle(tree)
	for i in 4:
		await tree.process_frame
	var battle: BattleScreen = tree.current_scene as BattleScreen
	print("PROBE battle scene is BattleScreen? ", battle != null)
	if battle == null:
		tree.quit(2)
		return
	battle._on_battle_ended(BattleState.Outcome.DEFEAT)
	print("PROBE after defeat: mission=", CampaignProgress.current_mission(), " tutorial_active=", TutorialProgress.is_active())
	battle.return_to_title_screen()
	for i in 4:
		await tree.process_frame
	var title: TitleScreen = tree.current_scene as TitleScreen
	print("PROBE current scene is TitleScreen? ", title != null)
	if title == null:
		tree.quit(3)
		return
	var row: Button = title.get_node("Panel/ContentMargin/Rows/StartBattleRow") as Button
	print("PROBE row text=", row.text)
	row.pressed.emit()
	for i in 4:
		await tree.process_frame
	var b2: BattleScreen = tree.current_scene as BattleScreen
	print("PROBE after pressing it: BattleScreen? ", b2 != null, " tutorial_active=", TutorialProgress.is_active(), " tutorial_index=", TutorialProgress.current_index(), " campaign_mission=", CampaignProgress.current_mission())
	tree.quit()
