# Probe: 用 GdUnit4 斷言 push_error() 是否可行——用來回答 ADR-0001
# Validation Criteria 第 9 項自陳的未查證項。
#
# 本檔刻意不宣告 class_name（避免與 src/gameplay/board/board.gd 既有的
# `class_name Board` 全域衝突），內部用一個本檔案私有的 `_BoardProbe`
# inner class 鏡射 ADR 的 board_version 屬性攔截寫法。
#
# PROTOTYPE - NOT FOR PRODUCTION — 僅用於驗證 GdUnit4 API 存在與行為，
# 不是正式測試,不會被 tests/ 的既有測試套件引用或執行。
extends GdUnitTestSuite


class BoardProbe:
	var _board_version: int = 0
	var board_version: int:
		get:
			return _board_version
		set(value):
			push_error("board_version is read-only outside BoardProbe; rejected external write of %d" % value)

	func commit_settlement_boundary() -> void:
		_board_version += 1


func test_external_write_triggers_push_error_and_value_unchanged() -> void:
	var board := BoardProbe.new()
	board.commit_settlement_boundary()
	board.commit_settlement_boundary()

	# 斷言:呼叫 `board.board_version = 999` 這個 callable 會觸發
	# push_error(),且訊息符合預期。
	await assert_error(func() -> void: board.board_version = 999) \
		.is_push_error("board_version is read-only outside BoardProbe; rejected external write of 999")

	# 斷言:值真的沒有被改變(GdUnitGodotErrorAssertImpl.is_push_error 本身
	# 只斷言「有沒有噴出這則訊息」,不斷言副作用——欄位值需要另外斷言)。
	assert_int(board.board_version).is_equal(2)


func test_baseline_no_push_error_when_untouched() -> void:
	# 對照組:確認 assert_error 不是恆為 pass——若期間真的沒有 push_error(),
	# is_push_error 應該回報失敗。用 is_success() 驗證「無錯誤路徑」本身。
	var board := BoardProbe.new()
	board.commit_settlement_boundary()

	await assert_error(func() -> void: var _v: int = board.board_version) \
		.is_success()

	assert_int(board.board_version).is_equal(1)
