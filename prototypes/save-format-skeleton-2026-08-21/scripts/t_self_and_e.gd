extends RefCounted
# 驗證 E:白名單完整性斷言真的會擋嗎。

func _copy(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d:
		out[k] = true
	return out

func t_self_check() -> String:
	print("      ALLOWED_TYPES.size()=%d REJECTED_TYPES.size()=%d TYPE_MAX=%d"
		% [SaveFormat.ALLOWED_TYPES.size(), SaveFormat.REJECTED_TYPES.size(), TYPE_MAX])
	print("      self_check() = %s   (true = 兩條斷言都通過)" % str(SaveFormat.self_check()))
	print("      spec rule = %s" % str(SaveFormat.verify_type_table_spec_rule(
		SaveFormat.ALLOWED_TYPES, SaveFormat.REJECTED_TYPES)))
	print("      strict    = [%s]  (空字串 = 通過)" % SaveFormat.verify_type_table_strict(
		SaveFormat.ALLOWED_TYPES, SaveFormat.REJECTED_TYPES))
	return "E0-REACHED-END"

func t_e_remove_one_type() -> String:
	# 規格要求的情境:故意從允許集合拿掉一個型別
	var allowed := _copy(SaveFormat.ALLOWED_TYPES)
	allowed.erase(TYPE_COLOR)
	var rejected := _copy(SaveFormat.REJECTED_TYPES)
	print("      拿掉 TYPE_COLOR 後 allowed.size()=%d rejected.size()=%d sum=%d TYPE_MAX=%d"
		% [allowed.size(), rejected.size(), allowed.size() + rejected.size(), TYPE_MAX])
	var spec: bool = SaveFormat.verify_type_table_spec_rule(allowed, rejected)
	var strict: String = SaveFormat.verify_type_table_strict(allowed, rejected)
	print("      spec rule  = %s   <-- 必須是 false 才算擋住" % str(spec))
	print("      strict     = [%s]" % strict)
	print("      => 斷言擋住了嗎: %s" % str((not spec) or strict != ""))
	return "E1-REACHED-END"

func t_e_sum_correct_but_hole() -> String:
	# 反例:規格那一條斷言「size 相加 == TYPE_MAX」是必要條件,但不是充分條件。
	# 場景:有人把 TYPE_COLOR 誤刪、同一次編輯又把 TYPE_OBJECT 複製貼上進允許集合。
	# 兩個集合的 size 相加仍然是 39,規格斷言完全看不到 —— 而 TYPE_OBJECT
	# 現在在白名單上,也就是最壞的那一種失敗。
	var allowed := _copy(SaveFormat.ALLOWED_TYPES)
	allowed.erase(TYPE_COLOR)
	allowed[TYPE_OBJECT] = true
	var rejected := _copy(SaveFormat.REJECTED_TYPES)
	print("      allowed.size()=%d rejected.size()=%d sum=%d TYPE_MAX=%d"
		% [allowed.size(), rejected.size(), allowed.size() + rejected.size(), TYPE_MAX])
	print("      allowed.has(TYPE_OBJECT)=%s  allowed.has(TYPE_COLOR)=%s"
		% [str(allowed.has(TYPE_OBJECT)), str(allowed.has(TYPE_COLOR))])
	var spec: bool = SaveFormat.verify_type_table_spec_rule(allowed, rejected)
	var strict: String = SaveFormat.verify_type_table_strict(allowed, rejected)
	print("      spec rule  = %s   <-- 若為 true,規格那一條斷言對這個洞是瞎的" % str(spec))
	print("      strict     = [%s]  <-- 較強的那一條抓到了嗎" % strict)
	return "E2-REACHED-END"

func t_e_gate_is_not_injectable() -> String:
	# (c) 類發現的實證:verify_type_table_* 是可注入的(參數化),
	# 但 _walk() 的白名單是 const 綁死的。也就是說「壞掉的白名單會不會真的放毒藥過去」
	# 這件事「無法」用單元測試證明 —— 只能證明斷言看不看得到。
	print("      SaveFormat._walk 的白名單來源是 const ALLOWED_TYPES,無注入點。")
	print("      因此本骨架只能證明『斷言的偵測力』,不能證明『壞白名單的後果』。")
	print("      對照:一個實際帶 Object 的 payload 在「現行(正確)」白名單下的結果 ->")
	var g = SaveFormat.validate_payload_types_detailed({"poison": RefCounted.new()})
	print("        rejection=%d path=%s" % [g.rejection, g.path])
	return "E3-REACHED-END"
