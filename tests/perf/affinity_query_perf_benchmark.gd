# Story-008（好感度／位置連鎖 Epic #5）AC-PERF 效能基準建立腳本。
#
# 對應 production/epics/affinity-position-chain/story-008-ac-perf-query-baseline-benchmark.md
#
# 🔴 這是基準建立，不是回歸驗證。AC-PERF 的判準已於 2026-10-15 由管理者裁決改寫為
# **絕對門檻**：至少重跑 3 次、取「各次執行中位數」的中位數 ≤ 300 usec/查詢；
# 另記錄單次最大值，> 5 ms 標記待人工複查但不單獨判定未通過。條文在
# design/gdd/affinity-position-chain.md 的 AC-PERF；裁決紀錄在
# docs/reviews/manager-rulings-2026-10-15.md 裁決二。
# 今天沒有這個基準——本腳本第一次執行時，寫出來的數字本身就是基準，不是「通過」或
# 「失敗」。比照 .claude/docs/coding-standards.md 對「沒有可測對象要寫 N/A、不得寫通過」
# 的紀律：第一次執行是建立起點，不是驗證回歸。
#
# 🔴 本腳本量測的是「遷移後」基準：story-005（好感度數值池遷移，M2）已於
# 2026-10-14 完成，配對表改為 AffinityPhiProvider 對 AffinityDataPool 的逐次查詢
# （combat_strength_read()），不再是建構時一次性解析的靜態檔。本檔原本（2026-10-14
# 之前）量的是「遷移前」基準——配對表來自靜態檔 AffinityLink.links_from_text() 一次性
# 解析，不含逐次查詢會新增的跨系統呼叫開銷；該舊基準已不能直接拿來當作本檔現在量出的
# 數字的回歸比較對象。⚠️ 舊的「較上一版基準劣化 ≤ 20%」判準【已失效】，見本檔第 5 行。
# 上一次（遷移後）執行寫出的基準，不是遷移前的歷史數字。
#
# ── 用法 ─────────────────────────────────────────────────────────────────
#   <godot> --headless --path . -s tests/perf/affinity_query_perf_benchmark.gd
#
# ── 為什麼是獨立腳本，不是 GdUnit4 測試（不會進全套，也不會進 CI 閘門）──────────
#
# 1. 本腳本會寫入一個進版控的基準檔案（production/qa/affinity-query-perf-baseline.md）。
#    .claude/rules/test-standards.md 的「Independence」規則與其登記的兩項唯讀例外
#    （真實資料檔讀取、原始碼紀律掃描）都只准讀，不含寫入——沒有任何例外涵蓋
#    GdUnit4 單元測試寫檔。把「量測」與「落地基準檔」分開成獨立腳本，是唯一同時
#    滿足「不違反單元測試紀律」與「AC 要求基準必須進版控」兩件事的做法。
# 2. 基準檔的更新應該是刻意動作——人工跑一次、人工核對、人工決定要不要覆蓋既有基準——
#    不該是每次 CI 跑測試時的自動副作用。若這支腳本是 GdUnit4 測試的一部分，基準會在
#    每次全套執行時被覆寫，基準本身會每次悄悄漂移，
#    這個 AC 就失去意義。
# 3. 本機實測「每開一個行程要 0.5～1.5 秒，負載中再慢 3～4 倍」（本次派工單的協調者
#    觀察）。本腳本量測的是行程內的迴圈耗時，不受行程啟動開銷影響，但機器負載仍會造成
#    個別樣本抖動——把一個時間數字的硬性 threshold 放進會在不同負載下重跑的自動化
#    閘門並不可靠；本 story 的 AC 本身也明文要求「本次執行結果不判定通過或失敗」，
#    所以沒有閘門可言，獨立腳本比塞進一個不會真的斷言任何東西的 GdUnit4 測試更誠實。
#
# ── (A) 級量測：本檔實際呼叫下列生產程式碼，自己不重新實作任何一條好感度規則 ──────
#   - src/gameplay/battle/battle_state.gd            BattleState.create()
#   - src/gameplay/affinity/affinity_link.gd         AffinityLink.links_from_text()
#   - src/gameplay/affinity/affinity_phi_provider.gd AffinityPhiProvider
#                                                     （positions() / positions_with()）
#   - src/gameplay/affinity/affinity_rules.gd        AffinityRules
#                                                     （bonus_for() / bonus_for_at() /
#                                                      board_lines()）
#   呼叫序列逐字複製自正式畫面每次游標移動觸發的「移動預覽」分支
#   （src/ui/battle/battle_screen.gd `_refresh_view()` 的 A 分支，2026-10-13 讀取確認；
#   行號會漂移，查證請重跑：
#   grep -n "positions_with(selected" src/ui/battle/battle_screen.gd | grep -v ":#"）。
#   本腳本只負責 orchestration（迴圈、計時、組字串寫檔），不重新推導任何
#   Φ／距離／delta 公式——這正是本次量測屬於 (A) 級而非 (C) 級的依據。
#
# ── 刻意未計入的因素（揭露，不是隱藏）───────────────────────────────────────
#   1. JIT／首次呼叫載入成本——計時迴圈前先跑 WARMUP_ITERATIONS 次暖機，暖機結果不計入
#      平均，但 GDScript 是否還有另一層一次性編譯成本未進一步拆解。
#   2. GC／記憶體配置抖動——每次迴圈都會配置新的 Dictionary／Array（position 快照、
#      line status 陣列），這是真實呼叫路徑本來就有的配置模式（不是本腳本額外引入的
#      負擔），但沒有另外拆解「純計算時間」與「配置時間」各佔多少。
#   3. 本機行程排程雜訊——只在單一行程內跑迴圈計時，不排除 OS 排程器搶佔造成的個別
#      離群值；本檔同時記錄平均與中位數以降低離群值對單一數字的影響，但未做更嚴謹的
#      統計處理（例如去除離群值後再平均）。
#   4. 只涵蓋 vs01 規模（10 個單位、2 條配對線）。不同規模（更多單位、更多配對線）下
#      的效能特性未量測，不應外推。
#   5. 游標格序列以「掃過一個 13×6 棋盤」的固定順序決定性產生（非 RNG——
#      本專案 rng_in_combat_settlement 禁令涵蓋結算路徑，Φ 查詢亦不應引入隨機性），
#      不代表真實玩家的移動分佈；這量的是「單次查詢的穩定成本」，不是「一局遊戲裡
#      查詢會被呼叫幾次」。
extends SceneTree

const VS01_ROSTER_PATH: String = "res://assets/data/units/vs01_roster.txt"
const VS01_LINKS_PATH: String = "res://assets/data/affinity/vs01_affinity_links.txt"
const VS01_TERRAIN_PATH: String = "res://assets/data/levels/vs01_terrain.txt"
const BASELINE_PATH: String = "res://production/qa/affinity-query-perf-baseline.md"

# GDD Interactions②：游標移動觸發預覽，這是實際遊玩中最高頻的呼叫路徑——
# 量這條，而非只量 phi()/bonus_for() 的實際站位查詢。
const WARMUP_ITERATIONS: int = 100
const MEASURED_ITERATIONS: int = 1000

# 近似 vs01 場景棋盤範圍（src/ui/battle/battle_screen.gd 註解提及「13x6 board」），
# 用來產生決定性的游標格序列。Φ 計算本身不檢查格子是否在棋盤合法範圍內
# （AffinityRules 只做曼哈頓距離運算），故範圍選擇不影響量測的生產程式碼路徑正確性。
const BOARD_WIDTH: int = 13
const BOARD_HEIGHT: int = 6


func _initialize() -> void:
	var roster_text: String = FileAccess.get_file_as_string(VS01_ROSTER_PATH)
	var links_text: String = FileAccess.get_file_as_string(VS01_LINKS_PATH)
	if roster_text.is_empty() or links_text.is_empty():
		push_error(
			"AC-PERF 基準腳本：讀不到 vs01 roster/links 檔案，無法建立基準。"
			+ " roster_text.is_empty()=%s links_text.is_empty()=%s"
			% [roster_text.is_empty(), links_text.is_empty()]
		)
		quit(1)
		return

	var state: BattleState = BattleState.create(_load_vs01_terrain_rows(), roster_text)

	# story-005 更新(2026-10-14)—— AffinityPhiProvider 不再接受靜態 links 陣列,
	# 改接受即時查詢的 AffinityDataPool（見該類別建構子文件註解）。links_text
	# 仍讀入但只用於驗證 vs01_affinity_links.txt 本身可解析（下方 push_error 分支），
	# 不再餵給 provider —— 下方改用 pool.append_record() 植入與該檔同形狀的兩筆
	# 記錄（1,2,POSITIVE 與 3,4,NEGATIVE），讓本腳本量到的呼叫路徑與正式連線後的
	# AffinityPhiProvider.links()（逐次查詢 combat_strength_read()）一致，而不是
	# 量一個空池的退化情況。這原本是遷移前基準之後的最小必要同步，用來讓本腳本在
	# story-005 完成當下仍可編譯執行；本檔頭部註解與下方輸出標籤已隨本次更新改為
	# 「遷移後（逐次查詢）基準」，本腳本現在就是用來建立取代舊基準的權威版本
	# （見本檔頭「為什麼是獨立腳本」第 2 點所說的「另一次刻意執行與人工核對」）。
	var parsed_links: Variant = AffinityLink.links_from_text(links_text)
	if parsed_links == null:
		push_error("AC-PERF 基準腳本：AffinityLink.links_from_text() 回傳 null，vs01 配對表解析失敗。")
		quit(1)
		return

	var pool: AffinityDataPool = AffinityDataPool.new()
	var seed_rejection_1: AffinityDataPool.WriteRejection = pool.append_record(
		AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.STORY_EVENT
	)
	var seed_rejection_2: AffinityDataPool.WriteRejection = pool.append_record(
		AffinityTypes.Pair.C3_C4, -1.0, AffinityTypes.Source.STORY_EVENT
	)
	if (
		seed_rejection_1 != AffinityDataPool.WriteRejection.NONE
		or seed_rejection_2 != AffinityDataPool.WriteRejection.NONE
	):
		push_error(
			"AC-PERF 基準腳本：植入 AffinityDataPool 種子記錄被拒絕（%d, %d），無法建立基準。"
			% [seed_rejection_1, seed_rejection_2]
		)
		quit(1)
		return
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, pool)

	# 決定性的「單位 id ×游標格」序列，不用 RNG。單位 id 取 vs01 全部 10 個（含存活的
	# PLAYER 與 ENEMY 陣營），游標格掃過近似棋盤範圍。
	var roster_ids: Array[int] = []
	for unit: Unit in state.units_of(Unit.Faction.PLAYER):
		roster_ids.append(unit.id)
	for unit: Unit in state.units_of(Unit.Faction.ENEMY):
		roster_ids.append(unit.id)
	roster_ids.sort()

	var cells: Array[Vector2i] = []
	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			cells.append(Vector2i(x, y))

	# 暖機：不計時，讓首次呼叫成本（JIT／初次配置）不要污染量測迴圈。
	for i in range(WARMUP_ITERATIONS):
		_run_one_preview_query(provider, roster_ids[i % roster_ids.size()], cells[i % cells.size()])

	var samples_usec: Array[int] = []
	for i in range(MEASURED_ITERATIONS):
		var unit_id: int = roster_ids[i % roster_ids.size()]
		var cell: Vector2i = cells[i % cells.size()]
		var start_usec: int = Time.get_ticks_usec()
		_run_one_preview_query(provider, unit_id, cell)
		samples_usec.append(Time.get_ticks_usec() - start_usec)

	var total_usec: int = 0
	for sample in samples_usec:
		total_usec += sample
	var average_usec: float = float(total_usec) / samples_usec.size()

	var sorted_samples: Array[int] = samples_usec.duplicate()
	sorted_samples.sort()
	var median_usec: int = sorted_samples[sorted_samples.size() / 2]
	var min_usec: int = sorted_samples[0]
	var max_usec: int = sorted_samples[sorted_samples.size() - 1]

	var commit_hash: String = _current_commit_hash()
	var measured_date: String = Time.get_date_string_from_system()

	_write_baseline(average_usec, median_usec, min_usec, max_usec, samples_usec.size(), commit_hash, measured_date)

	print(
		"AC-PERF baseline established (POST-migration, per-query AffinityDataPool reads) — "
		+ "average=%.2f usec/query median=%d usec/query min=%d max=%d over %d queries, commit=%s"
		% [average_usec, median_usec, min_usec, max_usec, samples_usec.size(), commit_hash]
	)
	quit(0)


# 複製正式畫面「移動預覽」分支的呼叫序列（src/ui/battle/battle_screen.gd `_refresh_view()`
# 的 A 分支）：positions() → board_lines(現況) → positions_with() → board_lines(假設) →
# bonus_for()（現況）→ bonus_for_at()（假設）。這就是 GDD 點名「游標移動即觸發預覽」的
# 那條最高頻呼叫路徑——不是只量 bonus_for_at() 單一次呼叫。
func _run_one_preview_query(
	provider: AffinityPhiProvider,
	unit_id: int,
	cell: Vector2i
) -> void:
	# story-005 更新 —— links 不再是呼叫端持有的靜態陣列，改為每次都呼叫
	# provider.links() 逐次查詢 AffinityDataPool（見 AffinityPhiProvider.links()
	# 文件註解）。這一行呼叫本身現在也是量測對象的一部分，與正式畫面
	# battle_screen.gd `_refresh_view()` 的 `_phi.links()` 呼叫時機一致。
	var positions: Dictionary[int, Vector2i] = provider.positions()
	var links: Array[AffinityLink] = provider.links()
	var _current_lines: Array[AffinityLineStatus] = AffinityRules.board_lines(positions, links)
	var hypo: Dictionary[int, Vector2i] = provider.positions_with(unit_id, cell)
	var _hypo_lines: Array[AffinityLineStatus] = AffinityRules.board_lines(hypo, links)
	var _current_bonus: int = AffinityRules.bonus_for(unit_id, positions, links)
	var _hypo_bonus: int = AffinityRules.bonus_for_at(unit_id, cell, hypo, links)


# 逐字沿用既有先例的讀檔手法（tests/unit/gameplay/battle/battle_state_test.gd
# `_load_terrain_rows()`，同樣的邏輯也出現在 board_test.gd）：逐行讀取，捨棄檔尾
# 那一行「EOF 時讀到的空字串」，避免 Board.from_ascii() 收到一列多餘的空白行。
# 本函式不是重新發明地形解析規則——它只是把同一支既有測試已經驗證過的讀檔手法複製
# 過來，解析本身仍然全部交給 Board.from_ascii()（經由 BattleState.create()）。
func _load_vs01_terrain_rows() -> PackedStringArray:
	var file: FileAccess = FileAccess.open(VS01_TERRAIN_PATH, FileAccess.READ)
	if file == null:
		push_error(
			"AC-PERF 基準腳本：讀不到 %s，error=%d" % [VS01_TERRAIN_PATH, FileAccess.get_open_error()]
		)
		return PackedStringArray()
	var rows: PackedStringArray = PackedStringArray()
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.is_empty() and file.eof_reached():
			break
		rows.append(line)
	file.close()
	return rows


func _current_commit_hash() -> String:
	var output: Array = []
	var exit_code: int = OS.execute("git", ["rev-parse", "--short", "HEAD"], output, true)
	if exit_code == 0 and output.size() > 0:
		return String(output[0]).strip_edges()
	return "unknown(git rev-parse failed, exit=%d)" % exit_code


func _write_baseline(
	average_usec: float,
	median_usec: int,
	min_usec: int,
	max_usec: int,
	sample_count: int,
	commit_hash: String,
	measured_date: String
) -> void:
	var content: String = """# 好感度 Φ 查詢效能基準（AC-PERF）

> 本檔由 `tests/perf/affinity_query_perf_benchmark.gd` 產生，每次重跑會整份覆寫。
> **不要手動編輯「現行基準」區塊的數字**——要更新基準，重跑腳本。

對應 `design/gdd/affinity-position-chain.md` Acceptance Criteria 節 AC-PERF（ADVISORY）與
`production/epics/affinity-position-chain/story-008-ac-perf-query-baseline-benchmark.md`。

## 🔴 這是基準，不是「通過／失敗」判定

AC-PERF 的判準自 2026-10-15 起是**絕對門檻**（管理者裁決）：至少重跑 3 次、取「各次執行中位數」
不代表任何回歸驗證已經發生。下一次任何觸及 Φ 查詢路徑的變更完成後，應重新執行本腳本，
的中位數，**≤ 300 usec/查詢**。另記錄各次單次最大值，> 5 ms 時標記待人工複查但不單獨判定未通過。

## 現行基準

| 欄位 | 值 |
|---|---|
| 基準類型 | 遷移後（逐次查詢 `AffinityDataPool.combat_strength_read()`）基準 —— story-005（好感度數值池遷移）已於 2026-10-14 完成 |
| 量測日期 | %s |
| 程式碼版本（commit） | `%s` |
| 連續查詢次數 | %d（另有 100 次暖機，不計入） |
| 平均耗時 | %.2f usec／次 |
| 中位數耗時 | %d usec／次 |
| 最小值／最大值 | %d usec ／ %d usec |
| 資料規模 | vs01 同規模（`assets/data/units/vs01_roster.txt` 10 個單位、`assets/data/affinity/vs01_affinity_links.txt` 2 條配對線） |
| 查詢種類 | 移動預覽路徑（GDD Interactions②「游標移動即觸發預覽」）：`positions()` + `board_lines()`×2 + `positions_with()` + `bonus_for()` + `bonus_for_at()`，逐字複製自 `src/ui/battle/battle_screen.gd` `_refresh_view()` 的移動預覽分支 |
| (A) 級來源 | `tests/perf/affinity_query_perf_benchmark.gd`（實跑輸出，非手抄） |

## ⚠️ 量測環境備註（誠實揭露，非理想條件）

**本次量測時，這台機器上同時有其他工作負載在跑**（本 story 由協調者同批派工時，
另有其他 agent session 並行在同一台機器上執行其他工作單）。本專案已實測記錄
「每開一個行程要 0.5～1.5 秒，負載中再慢 3～4 倍」的現象；本腳本量的是行程內迴圈耗時、
不是行程啟動開銷，但 OS 排程器在有其他負載時仍可能搶佔，導致個別樣本偏高
（見下表最大值與平均值的落差）。**下一次重新量測時，機器負載不保證相同** ——
這一點本身就可能是雜訊來源之一，不是只有程式碼變更——**而這正是舊的相對判準被換掉的理由**。

## ✅ 遷移後的重新量測 —— 已於 2026-10-15 執行完畢

本節原本寫的是一條待辦:「若 story-005(逐次查詢資料池)完成,本基準即失效……屆時應重跑
本腳本、標註『遷移後(逐次查詢)基準』,取代上表作為未來回歸比對的權威版本。」
**story-005 已於 2026-10-14~15 完成(提交 `bbdc0f6`),該待辦已執行,上表即是遷移後基準。**

🔴 **它記載的技術事實仍然成立,保留在此**:GDD 明文警告呼叫頻率為輸入事件級,
而遷移後每次 `links()` 查詢會對每一組候選配對各多一次跨系統呼叫
(`AffinityDataPool.combat_strength_read()`),不再是回傳一份建構時凍結的陣列。
**這是遷移前後數字可比性的主要變因,比對劣化幅度時必須納入考量。**

## 刻意未計入的因素

1. JIT／首次呼叫載入成本——已用 100 次暖機隔離，但未進一步拆解是否還有其他一次性編譯成本。
2. GC／記憶體配置抖動——每次查詢都配置新的 Dictionary／Array，這是真實呼叫路徑本來就有的
   配置模式，未拆解「純計算」與「配置」各佔多少時間。
3. 本機行程排程雜訊——同時記錄平均與中位數以降低離群值影響，未做去離群值等更嚴謹統計。
4. 只涵蓋 vs01 規模；不同規模（更多單位、更多配對線）下的效能特性未量測，不應外推。
5. 游標格序列為決定性掃描一個 13×6 範圍，不代表真實玩家的移動分佈；量的是「單次查詢的
   穩定成本」，不是「一局遊戲裡查詢會被呼叫幾次」。
6. **本機同時有其他工作負載**（見上方「量測環境備註」）——這不是程式碼本身的特性，
   是這次執行當下的環境狀態，下次重跑時負載很可能不同。

## 量測方法腳本

`tests/perf/affinity_query_perf_benchmark.gd`（獨立 headless 腳本，不在 GdUnit4 全套測試
範圍內——理由見該檔檔頭）。重跑指令：

```
<godot 執行檔> --headless --path . -s tests/perf/affinity_query_perf_benchmark.gd
```
""" % [
		measured_date, commit_hash, sample_count, average_usec, median_usec, min_usec, max_usec,
	]

	var file: FileAccess = FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("AC-PERF 基準腳本：無法開啟 %s 寫入，error=%d" % [BASELINE_PATH, FileAccess.get_open_error()])
		return
	file.store_string(content)
	file.close()
