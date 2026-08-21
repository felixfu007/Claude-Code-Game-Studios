extends RefCounted
# 額外測項(規格沒講,實作時發現非問不可):
# SaveBlockRegistry 存的是「綁在某個實例上的 Callable」。
# Callable 會不會讓那個 RefCounted 實例續命?若不會,登記完之後擁有者被回收,
# 全部讀取都會 fail-closed 成 DATA_CORRUPTED —— 而症狀是「存檔突然全部損毀」。

func _registry_from_local_source() -> SaveBlockRegistry:
	var src := FakeAffinitySource.new()
	var reg := SaveBlockRegistry.new()
	reg.register(FakeAffinitySource.SOURCE_ID, src.validate_semantics)
	reg.register(SkelFixture.TACTICAL_ID, src.validate_tactical)
	var v: Variant = reg.get_validator(FakeAffinitySource.SOURCE_ID)
	var cb: Callable = v
	print("      函式內(src 仍在作用域):is_valid=%s object=%s"
		% [str(cb.is_valid()), str(cb.get_object())])
	return reg  # src 在此離開作用域

func t_h_validator_lifetime() -> String:
	var reg := _registry_from_local_source()
	var v: Variant = reg.get_validator(FakeAffinitySource.SOURCE_ID)
	print("      函式外:typeof=%d (CALLABLE=%d)" % [typeof(v), TYPE_CALLABLE])
	var cb: Callable = v
	print("      is_valid() = %s" % str(cb.is_valid()))
	print("      get_object() = %s" % str(cb.get_object()))
	print("      get_method() = %s" % str(cb.get_method()))
	return "H1-REACHED-END"

func t_h_read_with_dangling_validator() -> String:
	# 拿那個可能已失效的登記表跑一次完整讀取。
	# 若 is_valid() 為 false -> 讀取器的 fail-closed 應回 DATA_CORRUPTED。
	# 若 is_valid() 說 true 但物件其實已死 -> 呼叫會中止本函式(sentinel 收到 "")。
	var fx := SkelFixture.new()
	var wr := fx.build(10)
	var reg := _registry_from_local_source()
	var rd := SaveReader.new(reg)
	print("      about to read_full with the possibly-dangling registry...")
	var res = rd.read_full(wr.buffer, SkelFixture.GAME_RULESET_VERSION)
	var names := ["OK", "DATA_CORRUPTED", "VERSION_TOO_NEW", "SEMANTIC_INVALID"]
	print("      status=%s 攔在=[%s] detail=%s" % [names[res.status], res.stopped_at, res.detail])
	return "H2-REACHED-END"

func t_h_double_register() -> String:
	var src := FakeAffinitySource.new()
	var reg := SaveBlockRegistry.new()
	reg.register("dup_id", src.validate_semantics)
	print("      第一次登記後 registered_ids=%s" % str(reg.registered_ids()))
	reg.register("dup_id", src.validate_tactical)
	print("      第二次登記(同 id,不同驗證器)後 registered_ids=%s" % str(reg.registered_ids()))
	var v: Variant = reg.get_validator("dup_id")
	print("      現在綁的是哪一個方法: %s" % str((v as Callable).get_method()))
	print("      get_validator('never_registered') = %s (typeof=%d)"
		% [str(reg.get_validator("never_registered")), typeof(reg.get_validator("never_registered"))])
	return "H3-REACHED-END"
