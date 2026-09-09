extends SceneTree
## OQ-2 提案驗證:把 systems-designer 手算的命中數表,改用專案真實程式碼重算。
##
## 🔴 本探針【不重新實作任何規則】:
##   - 傷害 = CombatRules.damage()      (專案真實實作)
##   - 敵方數值 = CombatRules.enemy_stat() (專案真實實作,即公式二)
## 探針自己只做一件事:把「打幾下才死」用整數迴圈數出來(不是套 ceil 公式),
## 亦即連 hits_to_kill 都不重新實作,而是實際反覆扣血直到 <= 0。
##
## 刻意未計入:視線、移動力、佔位、地形成本、行動旗標、卡牌。
## 亦即這是「站定原地互砍」的純數值上限,不是實際對局。

const TIERS := {"前哨": 0.05, "標準": 0.20, "菁英": 0.35}

func _hits(target_hp: int, atk: int, def_val: int, phi: int) -> int:
	var dmg: int = CombatRules.damage(atk, def_val, phi)
	if dmg <= 0:
		return -1
	var hp: int = target_hp
	var n: int = 0
	while hp > 0:
		hp -= dmg
		n += 1
		if n > 999:
			return -1
	return n

func _run_set(label: String, sets: Array) -> void:
	print("\n===== %s =====" % label)
	print("原型 | 階梯 | 敵HP/ATK/DEF | 無Φ | Φ=+3 | Φ=+2 | 敵殺我")
	for s: Dictionary in sets:
		for tier: String in TIERS:
			var pct: float = TIERS[tier]
			var e_hp: int = CombatRules.enemy_stat(s["hp"], pct)
			var e_atk: int = CombatRules.enemy_stat(s["atk"], pct)
			var e_def: int = CombatRules.enemy_stat(s["def"], pct)
			# Φ 只加攻擊方,且敵方攻擊我方時 Φ 恆為 0(專案既有裁決)
			print("%s | %s | %d/%d/%d | %d | %d | %d | %d" % [
				s["name"], tier, e_hp, e_atk, e_def,
				_hits(e_hp, s["atk"], e_def, 0),
				_hits(e_hp, s["atk"], e_def, 3),
				_hits(e_hp, s["atk"], e_def, 2),
				_hits(s["hp"], e_atk, s["def"], 0)])

func _init() -> void:
	_run_set("現行數值(vs01_roster.txt)", [
		{"name": "均衡", "hp": 30, "atk": 16, "def": 8},
		{"name": "中庸", "hp": 26, "atk": 14, "def": 6},
		{"name": "玻璃砲", "hp": 22, "atk": 20, "def": 4}])
	_run_set("systems-designer 提案", [
		{"name": "均衡", "hp": 30, "atk": 15, "def": 4},
		{"name": "中庸", "hp": 24, "atk": 13, "def": 4},
		{"name": "玻璃砲", "hp": 26, "atk": 20, "def": 3}])
	print("\n目標(管理者 2026-08-31):無加成 4 下、有加成 3 下")
	quit()
