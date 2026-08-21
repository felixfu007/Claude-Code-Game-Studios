class_name FakeAffinitySource
extends RefCounted
# 假的資料來源:模擬好感度區塊。零 RNG,資料由索引算術決定,重跑逐位元相同。

const SOURCE_ID: String = "affinity_data_pool"
const FORMAT_VERSION: int = 3

const PAIR_NAMES: Array = [
	"ALICE_BRUNO", "ALICE_CLARA", "ALICE_DIETER", "ALICE_ELIN",
	"BRUNO_CLARA", "BRUNO_DIETER", "BRUNO_ELIN",
	"CLARA_DIETER", "CLARA_ELIN", "DIETER_ELIN",
]
const SOURCE_KINDS: Array = ["DIALOGUE_CARD", "BATTLE_ASSIST", "CAMPAIGN_EVENT", "STORY_BEAT"]
const RECORD_KEYS: Array = ["pair", "m", "t", "c", "source"]
const TOP_KEYS: Array = ["records", "campaign_tick_marks", "death_marks"]

const M_MIN: float = -1000.0
const M_MAX: float = 1000.0
const C_MAX: int = 3

func export_state(record_count: int) -> Dictionary:
	var records: Array = []
	for i in record_count:
		records.append({
			"pair": PAIR_NAMES[i % PAIR_NAMES.size()],
			"m": float((i % 41) - 20) * 0.25,
			"t": i * 3,
			"c": i % (C_MAX + 1),
			"source": SOURCE_KINDS[i % SOURCE_KINDS.size()],
		})
	# 刻意用型別化陣列:X-1 已實測型別化容器經 var_to_bytes/bytes_to_var 往返後
	# 仍然 is_typed()==true,故骨架保留這個形狀以持續驗證它。
	var marks: Array[int] = []
	for i in 12:
		marks.append(i * 7)
	var deaths: Dictionary = {"BRUNO": 84, "CLARA": 133}
	return {"records": records, "campaign_tick_marks": marks, "death_marks": deaths}

# 逐欄位「正向」白名單驗證器:檢查型別 + 值域。
# 一律以 typeof() 內省判型別 —— 已實測比較運算子對錯型別會中止所在函式。
func validate_semantics(payload: Dictionary) -> SaveImportResult:
	var r := SaveImportResult.new()
	for k in payload.keys():
		if not TOP_KEYS.has(k):
			r.add("頂層有未預期的鍵: %s" % str(k))
	for k in TOP_KEYS:
		if not payload.has(k):
			r.add("頂層缺少鍵: %s" % k)
	if not r.ok:
		return r

	if typeof(payload["records"]) != TYPE_ARRAY:
		r.add("records 必須是 Array,實得 typeof=%d" % typeof(payload["records"]))
		return r
	var records: Array = payload["records"]
	for i in records.size():
		var e: Variant = records[i]
		if typeof(e) != TYPE_DICTIONARY:
			r.add("records[%d] 必須是 Dictionary,實得 typeof=%d" % [i, typeof(e)])
			return r
		var rec: Dictionary = e
		if rec.size() != RECORD_KEYS.size():
			r.add("records[%d] 欄位數 %d != %d" % [i, rec.size(), RECORD_KEYS.size()])
			return r
		for k in RECORD_KEYS:
			if not rec.has(k):
				r.add("records[%d] 缺少欄位 %s" % [i, k])
				return r
		if typeof(rec["pair"]) != TYPE_STRING:
			r.add("records[%d].pair 型別錯誤 typeof=%d" % [i, typeof(rec["pair"])])
			return r
		if not PAIR_NAMES.has(rec["pair"]):
			r.add("records[%d].pair 不在合法名稱集合: %s" % [i, str(rec["pair"])])
			return r
		if typeof(rec["m"]) != TYPE_FLOAT:
			r.add("records[%d].m 必須是 float,實得 typeof=%d" % [i, typeof(rec["m"])])
			return r
		var m: float = rec["m"]
		if m < M_MIN or m > M_MAX:
			r.add("records[%d].m 超出值域: %f" % [i, m])
			return r
		if typeof(rec["t"]) != TYPE_INT:
			r.add("records[%d].t 必須是 int,實得 typeof=%d" % [i, typeof(rec["t"])])
			return r
		if int(rec["t"]) < 0:
			r.add("records[%d].t 為負: %d" % [i, int(rec["t"])])
			return r
		if typeof(rec["c"]) != TYPE_INT:
			r.add("records[%d].c 必須是 int,實得 typeof=%d" % [i, typeof(rec["c"])])
			return r
		var c: int = rec["c"]
		if c < 0 or c > C_MAX:
			r.add("records[%d].c 超出值域 0..%d: %d" % [i, C_MAX, c])
			return r
		if typeof(rec["source"]) != TYPE_STRING:
			r.add("records[%d].source 型別錯誤 typeof=%d" % [i, typeof(rec["source"])])
			return r
		if not SOURCE_KINDS.has(rec["source"]):
			r.add("records[%d].source 不在合法名稱集合: %s" % [i, str(rec["source"])])
			return r

	if typeof(payload["campaign_tick_marks"]) != TYPE_ARRAY:
		r.add("campaign_tick_marks 必須是 Array,實得 typeof=%d" % typeof(payload["campaign_tick_marks"]))
		return r
	var marks: Array = payload["campaign_tick_marks"]
	var prev: int = -1
	for i in marks.size():
		if typeof(marks[i]) != TYPE_INT:
			r.add("campaign_tick_marks[%d] 必須是 int,實得 typeof=%d" % [i, typeof(marks[i])])
			return r
		var v: int = marks[i]
		if v < 0:
			r.add("campaign_tick_marks[%d] 為負: %d" % [i, v])
			return r
		if v <= prev:
			r.add("campaign_tick_marks 必須嚴格遞增,[%d]=%d <= 前一項 %d" % [i, v, prev])
			return r
		prev = v

	if typeof(payload["death_marks"]) != TYPE_DICTIONARY:
		r.add("death_marks 必須是 Dictionary,實得 typeof=%d" % typeof(payload["death_marks"]))
		return r
	var deaths: Dictionary = payload["death_marks"]
	for k in deaths:
		if typeof(k) != TYPE_STRING:
			r.add("death_marks 的鍵必須是 String,實得 typeof=%d" % typeof(k))
			return r
		if typeof(deaths[k]) != TYPE_INT:
			r.add("death_marks[%s] 必須是 int,實得 typeof=%d" % [str(k), typeof(deaths[k])])
			return r
		if int(deaths[k]) < 0:
			r.add("death_marks[%s] 為負" % str(k))
			return r
	return r

# 第二個區塊用的最小驗證器(讀取路徑要求「每個 manifest 條目都必須有登記」)
func validate_tactical(payload: Dictionary) -> SaveImportResult:
	var r := SaveImportResult.new()
	if not payload.has("turn") or typeof(payload["turn"]) != TYPE_INT:
		r.add("tactical_board.turn 缺失或型別錯誤")
		return r
	if int(payload["turn"]) < 0:
		r.add("tactical_board.turn 為負")
	return r
