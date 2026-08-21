extends RefCounted
# ROUND7 Probe E — 加碼量測(非委派 brief 硬性要求,屬「額外發現」範疇)。
# @abstract 類別本身被 `.new()` 時的確切行為:是乾淨拒絕(函式仍走完、回傳某個
# 可判讀的值或錯誤),還是硬中止(呼叫端連錯誤都拿不到)?
#
# 本檔對 SpikeBareVariant(e1)與 SaveIOBackend(e3)兩個 @abstract 類別都各測
# 一次 `.new()`。刻意同檔是因為兩者都只是「呼叫 .new() 觀察結果」這一種形狀,
# 且都是選配的加碼項 —— 若 e1 或 e3 任一編譯失敗,本檔會連帶編譯失敗,E0 的
# 逐檔編譯檢查會照實反映,runner 會整段 SKIP 這個加碼區塊,不影響 E1-E4 主線。
#
# 沿用 REACHED END 慣例:中止的判讀依據是空字串回傳,不是任何印出來的標籤。

static func test_new_on_bare_variant_abstract() -> String:
	print("      >> test_new_on_bare_variant_abstract: entering")
	var inst = SpikeBareVariant.new()
	print("      >> test_new_on_bare_variant_abstract: call done, about to return")
	return "REACHED END inst=%s typeof=%d" % [str(inst), typeof(inst)]

static func test_new_on_save_io_backend_abstract() -> String:
	print("      >> test_new_on_save_io_backend_abstract: entering")
	var inst = SaveIOBackend.new()
	print("      >> test_new_on_save_io_backend_abstract: call done, about to return")
	return "REACHED END inst=%s typeof=%d" % [str(inst), typeof(inst)]
