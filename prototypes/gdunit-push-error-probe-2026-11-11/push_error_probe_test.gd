extends GdUnitTestSuite
## 拋棄式探針:被測程式呼叫 push_error 時,GdUnit4 是否判失敗?如何斷言?

func _emit_error() -> int:
	push_error("PROBE push_error message")
	return -1

func test_plain_push_error_does_not_fail() -> void:
	var r: int = _emit_error()
	assert_int(r).is_equal(-1)

func test_assert_error_captures_push_error() -> void:
	await assert_error(func() -> void: _emit_error()).is_push_error("PROBE push_error message")

func test_real_parser_push_error_plain() -> void:
	var l: AffinityLink = AffinityLink.from_csv_line("1,2,NOPE,3")
	assert_object(l).is_null()
