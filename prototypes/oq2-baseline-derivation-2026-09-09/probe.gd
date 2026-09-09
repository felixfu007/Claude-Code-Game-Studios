extends SceneTree
## OQ-2 探針:現行 vs01 名冊的敵方數值,是否恰好由公式二從我方數值推出?
##
## 🔴 本探針【不重新實作任何規則】——
##   - 名冊解析呼叫 Unit.roster_from_text()(專案的真實解析器)
##   - 公式二呼叫 CombatRules.enemy_stat()(專案的真實實作)
##   - 讀的是 assets/data/units/vs01_roster.txt(專案的真實資料)
## 故本探針的輸出為 (A) 級。它唯一自己做的事是「窮舉 pct 並比對」。
##
## 刻意未計入:只涵蓋 vs01 這一關;不檢查 mp / 射程 / 起始座標。

func _init() -> void:
	var text: String = FileAccess.get_file_as_string("res://assets/data/units/vs01_roster.txt")
	var roster: Array[Unit] = Unit.roster_from_text(text)
	var players: Dictionary = {}
	var enemies: Array[Unit] = []
	for u: Unit in roster:
		if u.faction == Unit.Faction.PLAYER:
			players[u.code_name] = u
		else:
			enemies.append(u)

	print("敵方 | 基準 | pct | ceil 推得 HP/ATK/DEF | 名冊實際 | 相符")
	for e: Unit in enemies:
		var found: bool = false
		for name: String in players:
			var b: Unit = players[name]
			for step: int in range(1, 41):
				var pct: float = float(step) * 0.05
				var h: int = CombatRules.enemy_stat(b.hp_max, pct)
				var a: int = CombatRules.enemy_stat(b.atk, pct)
				var d: int = CombatRules.enemy_stat(b.def, pct)
				if h == e.hp_max and a == e.atk and d == e.def:
					print("%s | %s | %.2f | %d/%d/%d | %d/%d/%d | ✅" % [
						e.code_name, name, pct, h, a, d, e.hp_max, e.atk, e.def])
					found = true
					break
			if found:
				break
		if not found:
			print("%s | —— | 找不到任何 pct 能從任一我方角色推出 | 實際 %d/%d/%d | ❌" % [
				e.code_name, e.hp_max, e.atk, e.def])
	quit()
