# story-040 AC1/AC2 —— CombatRules.attack_block_reason 的規則層與一致性測試。
#
# 預言機一律是既有函式 CombatRules.is_attack_legal / is_attack_blocked_by_los;
# 本檔不自己算曼哈頓距離或視線(只在地形遮蔽樣式上用純資料 Dictionary 當遮蔽格集合)。
# 不碰檔案系統。
#
# 敏感度:static 純函式,無繼承鏈可覆寫(test-standards「已知證明不了」A 類);
# 改以「手動 mutant 一次一個」於交付回報揭露,並以防空洞斷言(每種原因至少出現一次)保護。
extends GdUnitTestSuite


func _occluder(cells: Array[Vector2i]) -> Callable:
	return func(cell: Vector2i) -> bool:
		return cells.has(cell)


func test_attack_block_reason_scan_matches_existing_predicates_and_covers_every_reason() -> void:
	var seen: Dictionary = {}
	var patterns: Array[Array] = [
		[] as Array[Vector2i],
		[Vector2i(2, 0)] as Array[Vector2i],
		[Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 0)] as Array[Vector2i],
	]
	var ranges: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 4), Vector2i(2, 6)]
	var from: Vector2i = Vector2i(0, 0)
	for pat: Array in patterns:
		var occ_cells: Array[Vector2i] = []
		for c: Variant in pat:
			occ_cells.append(c as Vector2i)
		var occ: Callable = _occluder(occ_cells)
		for rg: Vector2i in ranges:
			for x: int in range(0, 8):
				for y: int in range(0, 6):
					var to: Vector2i = Vector2i(x, y)
					var reason: CombatRules.AttackBlockReason = CombatRules.attack_block_reason(from, to, rg.x, rg.y, occ)
					seen[reason] = true
					assert_bool(reason == CombatRules.AttackBlockReason.NONE).is_equal(
						CombatRules.is_attack_legal(from, to, rg.x, rg.y, occ))
					assert_bool(reason == CombatRules.AttackBlockReason.LOS_BLOCKED).is_equal(
						CombatRules.is_attack_blocked_by_los(from, to, rg.x, rg.y, occ))
					assert_bool(reason == CombatRules.AttackBlockReason.ACTION_SPENT).is_false()
	for needed: CombatRules.AttackBlockReason in [
		CombatRules.AttackBlockReason.NONE, CombatRules.AttackBlockReason.OUT_OF_RANGE,
		CombatRules.AttackBlockReason.TOO_CLOSE, CombatRules.AttackBlockReason.LOS_BLOCKED,
	]:
		assert_bool(seen.has(needed)).override_failure_message(
			"防空洞:掃描未覆蓋原因 %d" % needed).is_true()


func test_attack_block_reason_too_close_vs_out_of_range_direction() -> void:
	var none: Callable = _occluder([] as Array[Vector2i])
	# min 2:距離 1 過近、距離 5(max 4)過遠。
	assert_int(CombatRules.attack_block_reason(Vector2i(0, 0), Vector2i(1, 0), 2, 4, none)).is_equal(CombatRules.AttackBlockReason.TOO_CLOSE)
	assert_int(CombatRules.attack_block_reason(Vector2i(0, 0), Vector2i(5, 0), 2, 4, none)).is_equal(CombatRules.AttackBlockReason.OUT_OF_RANGE)


func test_attack_block_reason_los_blocked_only_when_in_range() -> void:
	var occ: Callable = _occluder([Vector2i(1, 0)] as Array[Vector2i])
	assert_int(CombatRules.attack_block_reason(Vector2i(0, 0), Vector2i(2, 0), 1, 3, occ)).is_equal(CombatRules.AttackBlockReason.LOS_BLOCKED)
	# 超出射程且被擋 → 射程類優先。
	assert_int(CombatRules.attack_block_reason(Vector2i(0, 0), Vector2i(6, 0), 1, 3, occ)).is_equal(CombatRules.AttackBlockReason.OUT_OF_RANGE)
