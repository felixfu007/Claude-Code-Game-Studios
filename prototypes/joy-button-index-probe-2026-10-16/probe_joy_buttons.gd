# 探針:向【釘死的那一版引擎】直接讀 JoyButton 常數的實際序數。
#
# 為什麼需要它:design/quick-specs/battle-hud-prediction-marker.md 第 7 節第 6 項
# 把「手把 battle_guess_cycle 建議的按鈕序號 3 對應哪顆實體按鈕」列為未決,
# 理由是 docs/engine-reference/godot/VERSION.md 把 Godot 4.7 的輸入裝置變動
# 列為 post-cutoff 風險區,而 modules/input.md 停在 4.6。
#
# 🔴 本探針【不需要實體手把】—— 它讀的是引擎自己的列舉常數,不是任何裝置的輸入。
# 這是 (A) 級證據(引擎執行了專案釘死的那一版),不是訓練資料推測。
extends SceneTree


func _init() -> void:
	print("ENGINE = ", Engine.get_version_info())
	print("JOY_BUTTON_A              = ", JOY_BUTTON_A)
	print("JOY_BUTTON_B              = ", JOY_BUTTON_B)
	print("JOY_BUTTON_X              = ", JOY_BUTTON_X)
	print("JOY_BUTTON_Y              = ", JOY_BUTTON_Y)
	print("JOY_BUTTON_BACK           = ", JOY_BUTTON_BACK)
	print("JOY_BUTTON_START          = ", JOY_BUTTON_START)
	print("JOY_BUTTON_LEFT_SHOULDER  = ", JOY_BUTTON_LEFT_SHOULDER)
	print("JOY_BUTTON_RIGHT_SHOULDER = ", JOY_BUTTON_RIGHT_SHOULDER)
	print("JOY_BUTTON_LEFT_STICK     = ", JOY_BUTTON_LEFT_STICK)
	print("JOY_BUTTON_RIGHT_STICK    = ", JOY_BUTTON_RIGHT_STICK)
	print("JOY_BUTTON_MAX            = ", JOY_BUTTON_MAX)
	quit()
