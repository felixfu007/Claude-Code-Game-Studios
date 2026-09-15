# AffinityRecordList(src/gameplay/affinity_pool/affinity_record_list.gd)的
# 單元測試,連帶覆蓋 AffinityRecord(src/gameplay/affinity_pool/affinity_record.gd)
# 的欄位形狀。
#
# Story:production/epics/affinity-data-pool/story-002-affinity-record.md(S-002)
#
# 🔴 本 story 的 GDD AC 歸屬為 0——驗收依據是 ADR-0002 Validation Criteria
# 第 11 項(見 EPIC.md「三張零 AC 的 story」段落),本檔逐條對照該項的 (b)/(c)
# 兩小項與其 2026-08-25 擴充項:
#   - VC-11(c) → test_internal_array_is_typed
#   - VC-11(b) 前半(append 後 is AffinityRecord)→
#     test_get_at_returns_appended_record_with_correct_type
#   - VC-11(b) 擴充(空 list get_at(0) / 非空 list get_at(-1) / get_at(size())
#     皆乾淨回傳 null)→ 對應三條測試
# ⚠️ VC-11(a)(`_records[pair] is AffinityRecordList`)本 story 不涵蓋——那個
# 容器(Dictionary[Pair, AffinityRecordList])是 S-004 的產物,本檔不宣稱涵蓋它。
#
# 純 RefCounted、無節點——不建立任何 Node,不需要 tear-down,不會留下孤兒節點。
# 每個測試自成一組斷言,不共用可變狀態,不依賴執行順序。
extends GdUnitTestSuite


# ---- 基本行為:append/size 反映記錄筆數 ------------------------------------

func test_append_and_size_reflect_record_count() -> void:
	# Arrange
	var list := AffinityRecordList.new()
	assert_int(list.size()).is_equal(0)

	# Act
	list.append(_make_record())
	list.append(_make_record())
	list.append(_make_record())

	# Assert
	assert_int(list.size()).is_equal(3)


# ---- VC-11(c):內層陣列必須是型別化的 --------------------------------------

func test_internal_array_is_typed() -> void:
	# Arrange — GDScript 沒有真正的私有成員(檔頭誠實聲明),`_items` 的底線
	# 前綴是命名慣例、不是語言層強制;本測試需要直接檢視內層陣列本身才能
	# 斷言 is_typed(),這是 ADR-0002 VC-11(c) 明文要求的斷言方式。
	var list := AffinityRecordList.new()

	# Act / Assert — 宣告式初始化保證型別,即使尚未 append 任何記錄
	assert_bool(list._items.is_typed()).is_true()

	# Assert — append 之後型別仍然保住(佐證型別不是被某次寫入意外抹除的)
	list.append(_make_record())
	assert_bool(list._items.is_typed()).is_true()


# ---- VC-11(b) 前半:append 後 get_at() 回傳正確元素型別 ---------------------

func test_get_at_returns_appended_record_with_correct_type() -> void:
	# Arrange
	var list := AffinityRecordList.new()
	var record := _make_record()

	# Act
	list.append(record)
	var result: AffinityRecord = list.get_at(0)

	# Assert — 不得用 get_class()(任何 RefCounted 子類都印 RefCounted),
	# 用 is_instanceof()(引擎 is_instance_of(),非本專案自造的 get_class() 比對)
	assert_object(result).is_instanceof(AffinityRecord)
	# Assert — 且是同一個實例,不是複本
	assert_object(result).is_same(record)


# ---- VC-11(b) 擴充:三種越界情境皆乾淨回傳 null、不中止 --------------------

func test_get_at_out_of_bounds_on_empty_list_returns_null() -> void:
	# Arrange
	var list := AffinityRecordList.new()

	# Act / Assert
	assert_object(list.get_at(0)).is_null()


func test_get_at_negative_index_on_non_empty_list_returns_null() -> void:
	# Arrange — 非空 list,才能排除「空 list 才回傳 null」這個較窄的假設
	var list := AffinityRecordList.new()
	list.append(_make_record())

	# Act / Assert — 不得沿用引擎對負索引的原生行為(非空陣列 -1 取最後一筆)
	assert_object(list.get_at(-1)).is_null()


func test_get_at_index_equal_to_size_returns_null() -> void:
	# Arrange
	var list := AffinityRecordList.new()
	list.append(_make_record())
	list.append(_make_record())

	# Act / Assert — index == size() 是最容易漏掉的邊界(差一錯誤的另一側)
	assert_object(list.get_at(list.size())).is_null()


# ---- 佐證 wholesale_reassignment_of_affinity_record_list_items 禁令的動機 ---
# ⚠️ 這條測試的定義域是三個列舉出來的具體名稱(items/get_items/to_array),
# 不是「任何取得內部陣列的方式」的全稱檢查——寫下「不存在」之前,必須先確認
# 檢查的定義域真的等於宣稱的範圍(本專案已登記的紅旗字紀律:全稱詞如
# 「不存在/皆/零」容易讓名字宣稱得比斷言多)。
#
# 🔴 這個定義域刻意是窄的,而不是疏忽:上面 test_internal_array_is_typed
# 就直接存取了 `list._items`,證明外部程式碼確實拿得到內部陣列——GDScript
# 沒有真正的私有成員,底線前綴只是命名慣例。兩條測試不互相矛盾:那一條驗證
# 「約定俗成的存取路徑事實上存在」,這一條驗證「公開介面沒有刻意設計出的
# 存取器」,分別回答不同問題。
#
# 本測試存在的理由是佐證禁令 wholesale_reassignment_of_affinity_record_list_items
# 的動機(工作單原話:「非硬性斷言結構保證」)——它示範的是,若真的需要繞過
# append() 整批寫入/取出,至少不能用這三個最直覺的名稱長驅直入;它不證明、
# 也不試圖證明「沒有任何路徑」能拿到內部陣列。

func test_public_interface_has_no_items_get_items_or_to_array_method() -> void:
	# Arrange
	var list := AffinityRecordList.new()

	# Act — append() 的靜態回傳型別是 void(GDScript 編譯期即拒絕承接其回傳值,
	# 這件事本身已由編譯通過佐證,不需要在執行期斷言)
	list.append(_make_record())

	# Assert — 公開介面上不存在這三個具體名稱的方法(僅此三者,見上方定義域說明)
	assert_bool(list.has_method("items")).is_false()
	assert_bool(list.has_method("get_items")).is_false()
	assert_bool(list.has_method("to_array")).is_false()


# ---- 測試用工廠函式 ---------------------------------------------------------

## 建立一筆合法形狀的 AffinityRecord,供不需要關心具體欄位值的測試使用。
## 不使用共用可變狀態——每次呼叫回傳一個全新實例。
func _make_record() -> AffinityRecord:
	var record := AffinityRecord.new()
	record.pair = AffinityTypes.Pair.C1_C2
	record.m = 1.0
	record.t = 1
	record.c = 0
	record.source = AffinityTypes.Source.COMBAT_CARD
	return record
