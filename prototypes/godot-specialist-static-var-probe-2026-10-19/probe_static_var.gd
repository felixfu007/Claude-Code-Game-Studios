extends SceneTree

func _init() -> void:
	print("Q1 initial GameSettingsProbe.is_egm_enabled() = ", GameSettingsProbe.is_egm_enabled())
	GameSettingsProbe.set_egm_enabled(true)
	print("Q2 after set(true), same class access = ", GameSettingsProbe.is_egm_enabled())
	GameSettingsProbe.reset_for_test()
	print("Q3 after reset_for_test() = ", GameSettingsProbe.is_egm_enabled())
	quit()
