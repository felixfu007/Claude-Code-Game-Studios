# Story 016: 地形載入時驗證(`Board.from_ascii()` 結構性 + 組成性檢查)

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S(半天內 —— 單一檔案、單一載入函式,見下方「範圍」)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)
> **派工來源**: 2026-10-05 管理者裁決(逐字:「『地形載入時驗證』這個缺口,現在切一張
> 獨立小工作單」)。**本裁決目前唯一的書面紀錄就是本 story 檔** —— 協調者將在第七十五批
> 交接節補登,在那之前引用請寫「2026-10-05 管理者裁決,紀錄於第七十五批交接節」,
> 不要寫成某個既有檔案的某一行。本 story 由 `lead-programmer` 切出,**不實作**。

## Context

**GDD**: `design/gdd/tactical-combat-system.md` Formulas 公式三、Tuning Knobs #4 ——
地形三個正交逐格屬性(`terrain_cost`、遮蔽布林值、`passable`)皆已由 story-001/002 落地
為查詢方法,但**載入時**(棋盤建構當下)尚無任何主動掃描,僅有「查詢當下才檢查」的
被動防護(見下方現況)。

⚠️ **GDD 本文未逐字使用「載入時驗證」這個詞,也未定義它的具體形狀**
(`grep -n "載入時驗證" design/gdd/tactical-combat-system.md` → 零命中)。
本 story 的驗證形狀(結構性 + 組成性兩項,見下方 Scope)**是本次派工的設計判斷**,
依 GDD 公式三/Tuning Knobs #4 的既有約束(固定 13×6、二欄查表)推導,
不是從 GDD 原文照抄。這與 story-001「資料表擴欄的具體形狀由本 story 決定」是同一種授權。

**Requirement**: `TR-tactical-002`

```
$ grep -n "TR-tactical-002" docs/architecture/tr-registry.yaml
55:  - {id: TR-tactical-002, ..., requirement: "地形須有三個正交逐格屬性(terrain_cost>=1、
     遮蔽布林值、passable 可通行布林旗標)，並有載入時驗證", ...}
```

`docs/architecture/traceability-index.md` 第 86 行現標本項為 **❌ 缺口**——「三個屬性」
部分已由 story-001/002 滿足,「並有載入時驗證」這一截**全專案尚未有任何實作**,是本 story
要關閉的那一半缺口。**本 story 不修改 `tr-registry.yaml`/`traceability-index.md`**——
兩檔的擁有者是 `technical-director`(EPIC.md C5 既有指派),本 story 完成後請該擁有者
重新判定 TR-tactical-002 是否可轉綠。

**ADR Governing Implementation**: 無直接管轄 ADR —— `ADR: N/A —— 純資料驗證與既有查詢的
防禦性修正,不涉及 BattleState/TurnOrder 的原子性契約`(與 story-001 同一種「無跨系統契約」
判斷:本 story 只動 `Board` 資料層本身的載入與內部查詢,不碰 ADR-0001 管轄的快照/版本號/
寫入守衛機制)。

**Engine**: Godot 4.7.1 | **Risk**: LOW(純 GDScript 資料驗證邏輯,無 post-cutoff API)

**Control Manifest Rules(Core 層)**:
- 一般紀律(`.claude/docs/coding-standards.md`):**絕不用 `assert()` 保護「不可達」分支**——
  本 story 的設計核心就是這一條的延伸應用(載入時驗證同樣必須用 `push_error()` + 顯式
  非成功路徑,不得用 `assert()`)

## 範圍裁決(管理者已定邊界)

✅ **在範圍內**:地形載入時驗證(`TR-tactical-002` 的「並有載入時驗證」那一截)
❌ **不在範圍內**:武器資料表驗證(`TR-tactical-005`)。

理由(已查證):
```
$ grep -rln "weapon" src/ --include=*.gd
src/gameplay/combat/combat_rules.gd
```
唯一命中是 `combat_rules.gd` 文件註解裡討論「近戰武器」這個概念(`max_range = 1` 的武器),
**不是一個被載入的資料檔**。

```
$ find assets/data -iname "*weapon*"
(零輸出)
$ grep -n "weapon" docs/architecture/tr-registry.yaml
58:  - {id: TR-tactical-005, ..., requirement: "武器資料表需要載入時的結構性與組成性驗證
     (AC-3、AC-23)", ...}
```
武器還沒有成為一個被載入的資料檔(目前武器屬性如何賦值屬 `Unit`/`CardModifier` 的既有
機制,未查證,本 story 不處理)——現在為它寫驗證是對不存在的東西立法。
**TR-tactical-005 仍留 ❌ 缺口,本 story 不關閉它**,留給下一次有武器資料檔落地時的
工作單處理。

## 現況(2026-10-05 實測,逐指令)

```
$ grep -n "func from_ascii" src/gameplay/board/board.gd
66:static func from_ascii(rows: PackedStringArray) -> Board:
```

```gdscript
static func from_ascii(rows: PackedStringArray) -> Board:
	var board: Board = Board.new()
	for y: int in range(rows.size()):
		var row: String = rows[y]
		for x: int in range(row.length()):
			var pos: Vector2i = Vector2i(x, y)
			board._terrain[pos] = row.substr(x, 1)
	return board
```

**零驗證。** 這個靜態工廠方法:
1. 不檢查 `rows.size()` 是否等於 `BOARD_HEIGHT`(13×6 固定棋盤,`board.gd` 第 10-13 行
   `const BOARD_WIDTH`/`BOARD_HEIGHT` 明文)。
2. 不檢查任一列的 `row.length()` 是否等於 `BOARD_WIDTH`。
3. 不檢查每個字元是否登記於 `TERRAIN_TABLE`——未登記字元就這樣原封不動存進 `_terrain`。

**已存在的被動防護**(story-001 落地,不是本 story 的產出,也不會被本 story 動到):
`get_move_cost()`(第 96-102 行)與 `passable()`(第 140-146 行)各自在**被查詢當下**
透過 `_terrain_entry()` 檢查字元是否登記,未登記時 `push_error()` + 回傳對應哨兵
(`MOVE_COST_UNKNOWN_TERRAIN` / `false`)。這是「查詢時才知道」,不是「載入時就知道」——
一個有問題的地形檔,若遊戲過程中剛好沒有任何單位移動經過那一格,問題可能全程不被發現。

🔴 **第 250 行呼叫端把查詢時的哨兵值直接拿去做加法,目前沒有任何防護**:
```
$ sed -n '242,256p' src/gameplay/board/board.gd
		for neighbor: Vector2i in _get_orthogonal_neighbors(current):
			if not is_in_bounds(neighbor):
				continue
			if not ignore_occupancy and has_occupant(neighbor):
				continue
			if not ignore_passability and not passable(neighbor):
				continue

			var candidate_cost: int = best_cost[current] + get_move_cost(neighbor)
			if candidate_cost > mp:
				continue
```
`ignore_passability=false`(預設/一般移動合法性查詢)時,第 247 行的 `passable(neighbor)`
已經先把未登記地形字元擋下(未登記字元觸發 `passable()` 的顯式失敗路徑,回傳 `false`,
故在第 247 行被 `continue` 排除,根本不會走到第 250 行)。

**但 `ignore_passability=true` 時,第 247 行整行被短路跳過**——這正是 story-007
「移動範圍四態查詢」要用來標示「僅被地形擋死」(`C` 集合)的那個開關。此時未登記地形
字元會直接流進 `get_move_cost(neighbor)`,拿到 `MOVE_COST_UNKNOWN_TERRAIN`(`-1`),
再被加進 `candidate_cost`——**一個負數成本貢獻,而不是「此格視為不可達」。**

**這個路徑在 story-002 之前無法被觸發**:`ignore_passability` 參數是 story-002 才新增的
(`reachable_tiles()` 原簽章只有 `(origin, mp)`,一律經過 `passable()` 閘門)。
本 story 要補的防護,是 story-002 新增雙開關後才浮現的既有缺口,不是本 story 新造成的問題,
但也從未被任何測試或 story 的驗收條件覆蓋過。

## Scope

### In Scope

1. **結構性驗證**(新,`from_ascii()` 內):檢查 `rows.size() == BOARD_HEIGHT`,以及
   每一列 `row.length() == BOARD_WIDTH`。任何一項不符即 `push_error()`(不中止、不改變
   既有儲存行為——見下方「決策二」)。
2. **組成性驗證**(新,`from_ascii()` 內):掃描每一格,檢查該格字元是否存在於
   `TERRAIN_TABLE`。**每一個**未登記的格子各自觸發一次 `push_error()`(不是只報第一個就
   停止掃描——見「決策二」的理由)。
3. **`reachable_tiles()` 第 250 行呼叫端加一道防護**(修正上方現況揭露的既有缺口):
   `get_move_cost(neighbor)` 回傳 `MOVE_COST_UNKNOWN_TERRAIN` 時,該鄰居視為不可達
   (等同一個 `passable=false` 的格子的效果),不得把哨兵值併入 `candidate_cost` 的加法。
4. 對應的新測試檔。

### Out of Scope(附理由)

- **武器資料表驗證(`TR-tactical-005`)**——見上方「範圍裁決」節,理由是武器尚未成為一個
  被載入的資料檔。
- **拒絕建構 / 讓 `from_ascii()` 回傳 `null` 或拋出例外**——刻意排除,見下方「決策二」的
  完整理由:這會是本專案第一個「建構失敗」的資料載入路徑,與既有的「push_error + 顯式
  非成功回傳值,但繼續執行」慣例不一致,屬於一次獨立的架構決策,不是本 story 的範圍。
- **改變 `from_ascii()` 既有的解析/儲存邏輯**(例如截斷過長列、補齊過短列、拒絕越界座標)
  ——本 story 的驗證是**純附加的診斷訊號**,不改變任何格子最終被儲存或查詢時的行為。
  越界座標仍如既往由 `is_in_bounds()` 把關,不在本 story 改動。
- **地形中途動態改變的驗證**——GDD Edge Cases 明文「本系統目前不定義行為」,待系統 #14。
- **`TR-tactical-002`/`traceability-index.md` 文字本身的更正**——擁有者為
  `technical-director`(EPIC.md C5 既有指派),不由本 story 代為修改。
- **新增一個對外可查詢的「驗證是否曾經失敗」API**(例如 `Board.had_load_errors() -> bool`)
  ——刻意不加,見下方「決策二」的最小化理由。測試改用 GdUnit4 的
  `assert_error(<callable>).is_push_error(...)` 驗證(與 `board_passable_test.gd` 既有
  手法一致),不需要額外的公開狀態。

## 四項裁決(依派工單要求,逐項寫下裁決與理由)

### 決策一:驗證發生在哪個入口

**裁決:`Board.from_ascii()`(靜態工廠方法)。**

理由:
- `from_ascii()` 是全專案**唯一**的地形載入入口——`grep -rln "Board\.from_ascii(" --include=*.gd .`
  命中 9 個檔案、24 處呼叫,沒有第二條建構路徑(`Board.new()` 本身只建空棋盤,靠
  `_terrain[pos] = ...` 逐格寫入才有內容,而所有逐格寫入目前都經過 `from_ascii()`)。
- `BattleState.create()`(唯一的生產呼叫點,`battle_state.gd:116`)直接把 `from_ascii()`
  的回傳值指派給 `state.board`,中間沒有任何其他環節可以插入驗證——選別處驗證
  (例如 `BattleState.create()` 內)會讓測試直接建構 `Board`(26+ 處既有呼叫點裡的多數)
  繞過驗證,而這些呼叫點**正是**驗證最需要覆蓋的對象(story-001/002 的既有測試夾具)。

### 決策二:驗證失敗的行為是什麼

**裁決:`push_error()` + 繼續執行(不中止建構、不回傳 `null`、不拋例外),且掃描到底
(不因第一個失敗就停止),與既有 `get_move_cost()`/`passable()` 的慣例一致。**

🔴 **已讀 `.claude/docs/coding-standards.md` 2026-09-15 條目全文**(非僅轉述):
`assert()` 失敗會中止呼叫函式並讓函式回傳宣告型別的序數 `0`,而近乎普遍慣例下序數 `0`
就是「成功」值——該條目附的可重跑探針(`extends SceneTree` + `enum R { NONE = 0, ... }`)
量測結果逐字為 `returned = 0  is NONE? true`。**本 story 的驗證路徑絕不使用 `assert()`**,
理由與 `get_move_cost()`/`passable()` 既有的文件註解完全一致(`board.gd` 第 91-95、
117-122 行已各自引用同一條規則)。

📌 **`board.gd` 第 124-139 行的既有文件註解**(`passable()` 的設計取捨)已先一步處理了
「測試如何分辨『合法的 false/失敗值』與『未登記地形的失敗路徑』」這個問題,給出兩個選項:
`(1) call get_move_cost() … (2) assert that push_error() …`。**本 story 的裁決與它一致,
不是推翻它**——本 story 新增的載入時驗證同樣只靠 `push_error()` 發出訊號,測試同樣改用
選項 (2)(`assert_error(<callable>).is_push_error(...)`)而非比對回傳值,因為
`from_ascii()` 的回傳型別是 `Board`(一個有效物件),**不經由回傳值傳遞失敗訊息**。

**為什麼不中止建構 / 不回傳 `null`**:
1. 本專案目前沒有任何「拒絕載入」的既有路徑——`Board`、`TurnOrder`、`Unit` 的建構方法
   全部是「建構必定成功,查詢時才可能顯式失敗」的慣例(`get_move_cost()`/`passable()`
   皆如此)。讓 `from_ascii()` 變成第一個會建構失敗的工廠方法,是一個新的失敗架構
   (需要呼叫端處理 `null`/例外),屬於跨方法慣例的架構決策,不是一個「小工作單」
   該順手帶的改動。
2. 若回傳 `null`,`BattleState.create()`(`battle_state.gd:116`)的下一行
   `state.board.set_occupant(unit.start_pos, unit.id)` 會在 `null` 參照上當掉——
   一個未受控的執行期錯誤,比目前「顯式失敗 + 繼續執行」更難診斷,且不符合本專案
   「失敗必須顯式、但遊戲仍可運行以利除錯」的既有哲學(`get_move_cost()`/`passable()`
   的回傳哨兵值皆服務於「可以繼續查詢,但查到的是明確的失敗標記」這個設計)。
3. **地形資料是手工設計的靜態文字檔**(GDD 明文禁止程序化生成),載入時驗證的目的是
   讓開發者在編輯 ASCII 關卡檔打錯字時**立刻在終端機看到**,而不是讓遊戲在該次執行
   直接拒絕啟動——後者對一個仍在開發中、地形檔會頻繁手動編輯的系統而言,診斷價值
   低於「當場列出全部錯誤的格子,一次性看到問題全貌」。

**為什麼掃描到底,不因第一個失敗就停止**:關卡地形是一次性手寫的 ASCII 文字塊,
一次打字錯誤往往伴隨同類型的其他錯誤(例如整列打錯、複製貼上帶出多個同樣的錯字)。
每修一個、重新載入一次才看到下一個,對開發者是不必要的來回;13×6=78 格的掃描成本
可忽略,一次性報告全部問題更符合這個資料是「手工編輯、偶爾出錯」的使用模式。

### 決策三:第 250 行呼叫端要不要一併改

**裁決:改。這是一個獨立於載入時驗證存在與否的既有缺口,必須在本 story 一併修正,
理由見上方「現況」節的完整分析,此處只寫結論。**

- 載入時驗證**只負責發出訊號**(`push_error()`),不移除、不修改 `_terrain` 裡已經
  存在的錯誤字元——這是決策二刻意的設計(繼續執行,不中止)。意思是:即使載入時驗證
  已經對一個壞字元報過一次錯,該壞字元仍然留在棋盤裡,`get_move_cost()` 仍會在後續
  每次被查詢時對它回傳 `MOVE_COST_UNKNOWN_TERRAIN`——載入時驗證**不能**讓第 250 行的
  問題自動消失。
- 這個缺口**只有在 `ignore_passability=true` 時才會被觸發**,而這正是 story-007
  「移動範圍四態查詢」要用來計算 `C` 集合(僅被地形擋死)的開關。若不修,story-007
  上線後,任何含有未登記地形字元的關卡檔(不論是否已被載入時驗證報過錯),都可能讓
  `C` 集合的計算結果摻入負數成本貢獻,產生一個數學上錯誤、但不會再報任何新錯誤的
  可達性判定——因為 `get_move_cost()` 已經在載入時報過一次,查詢時不會為同一個查詢
  重複報錯(它每次呼叫都會報,但問題在於呼叫端沒有檢查回傳值,錯誤訊息被忽略)。
- 修正方式是在第 250 行呼叫 `get_move_cost(neighbor)` 後,檢查回傳值是否等於
  `Board.MOVE_COST_UNKNOWN_TERRAIN`,是則視同 `passable(neighbor)=false`(`continue`
  跳過該鄰居),而非把哨兵值併入 `best_cost` 的加法。

### 決策四:AC 與 QA Test Cases

⚠️ **本次派工環境無 `Task` 工具,無法依 `/create-stories` 既有流程產出 `qa-lead`
覆核的測試規格**——與 story-001/003b 相同情況,已比照其前例誠實標註(見下方 QA Test Cases
節開頭)。建議下一次有 `Task` 工具可用時,對本節內容補跑一次 QL-STORY-READY 覆核。

## Acceptance Criteria

- [ ] **AC1**:`Board.from_ascii()` 新增結構性驗證——`rows.size() != BOARD_HEIGHT` 時
      觸發一次 `push_error()`;任一列 `row.length() != BOARD_WIDTH` 時,該列觸發一次
      `push_error()`(訊息含列索引)。驗證不中止建構,既有的逐格儲存邏輯不變。
- [ ] **AC2**:`Board.from_ascii()` 新增組成性驗證——掃描每一格,字元不存在於
      `TERRAIN_TABLE` 時,該格觸發一次 `push_error()`(訊息含座標與字元,格式比照
      `get_move_cost()`/`passable()` 既有慣例)。多個未登記字元各自觸發各自的
      `push_error()`,不因第一個就停止掃描。
- [ ] **AC3**:結構性與組成性驗證均**絕不使用 `assert()`**(`.claude/docs/coding-standards.md`
      2026-09-15 條目)。
- [ ] **AC4**:既有合法棋盤(平地/灌木/倒木三種地形,13×6 完整尺寸)載入時觸發
      **零次**新增的 `push_error()`——不得對現有 24 處 `from_ascii()` 呼叫點產生迴歸
      (見下方 Affected Files)。
- [ ] **AC5**:`from_ascii(rows: PackedStringArray) -> Board` 簽章不變,**永遠**回傳一個
      有效的 `Board` 物件(不回傳 `null`,不拋例外)——見「決策二」。
- [ ] **AC6**:`reachable_tiles()` 內 `get_move_cost(neighbor)` 回傳
      `Board.MOVE_COST_UNKNOWN_TERRAIN` 時,該鄰居視為不可達(等同 `passable=false`
      的效果),不得把哨兵值併入 `candidate_cost` 的加法——見「決策三」。此防護在
      `ignore_passability=true` 與 `ignore_passability=false` 兩種情況下皆須成立
      (後者目前已被 `passable()` 間接擋下,此 AC 要求的是即使該間接防護未來被改動,
      `get_move_cost()` 呼叫端自身也要有獨立防護,不得只依賴上游的 `passable()` 閘門)。
- [ ] **AC7**:`TERRAIN_TABLE`、`MOVE_COST_UNKNOWN_TERRAIN` 的值、`get_move_cost()`/
      `passable()` 既有的查詢時顯式失敗行為(story-001 產出)**不變**——本 story 新增的
      是載入時的**額外**檢查層,不是既有查詢時檢查的替代品(兩者併存,defense-in-depth,
      與 `board.gd` 第 300-316 行 `_terrain_entry()` 文件註解記載的既有設計精神一致)。

## Affected Files

| 檔案 | 改動性質 |
|---|---|
| `src/gameplay/board/board.gd` | `from_ascii()` 新增結構性 + 組成性驗證;`reachable_tiles()` 第 250 行附近新增 `MOVE_COST_UNKNOWN_TERRAIN` 防護 |
| 新增測試檔(建議 `tests/unit/gameplay/board/board_load_validation_test.gd`,與 `board_test.gd`/`board_passable_test.gd`/`board_reachable_tiles_test.gd` 分開,理由同 story-003b:同套件內任一測試失敗會中止其後全部測試,見 `.claude/docs/coding-standards.md`) | AC1-AC7 的斷言 |

🔴 **僅此一個正式程式碼檔案**——與管理者裁決原文「一個檔、一個載入函式」一致,已於
派工時由協調者查證確認(`get_move_cost`/`MOVE_COST_UNKNOWN_TERRAIN` 的唯一呼叫端皆在
`board.gd` 內)。**不涉及** `battle_state.gd`/`battle_controller.gd`/`battle_loop.gd`/
`turn_order.gd`。

## ⚠️ 與 story-003b 的檔案層衝突(排程限制,非邏輯依賴)

`story-003b`(現況 `Ready`,尚未開工)同樣會修改 `src/gameplay/board/board.gd`——它改的
是 `set_occupant()`/`clear_occupant()` 加寫入守衛,與本 story 改的 `from_ascii()`/
`reachable_tiles()` 是**不同函式、邏輯上互不相關**。但兩者是**同一個檔案**,
`story-index.md` 已明文「003b 動工期間不得並行其他戰棋工作單」——本 story 繼承同一條
限制:**不得與 story-003b 同時動工**,須排在其之前或之後(哪一個排前面屬排程裁決,
不由本 story 決定;本 story 不修改 `story-index.md`,相關改動需求見本報告最後一節)。

## QA Test Cases

⚠️ **本節由 `lead-programmer` 依上方 Acceptance Criteria 直接撰寫,非 `qa-lead` 產出**
(本次派工環境無 `Task` 工具)。建議下一次有 `Task` 工具可用時補跑一次 QL-STORY-READY 覆核。

- **既有合法棋盤零誤報(迴歸防護,對應 AC4)**
  - Given: 一份 13×6、全部字元皆登記於 `TERRAIN_TABLE` 的棋盤(沿用 story-001 既有的
    平地/灌木/倒木混合夾具)
  - When: 呼叫 `Board.from_ascii(rows)`
  - Then: 結構性與組成性驗證皆**不**觸發 `push_error()`(可用 GdUnit4 的
    `assert_error(<callable>).is_push_error(...)` 配合 `is_false()`/等價手法驗證
    零觸發,或驗證既有查詢行為不受影響)
- **列數不符觸發結構性驗證(對應 AC1)**
  - Given: 一份只有 5 列(非 `BOARD_HEIGHT=6`)的 `rows`
  - When: 呼叫 `Board.from_ascii(rows)`
  - Then: 觸發至少一次 `push_error()`;回傳值仍是可用的 `Board` 物件(不為 `null`),
    既有列的內容仍正確儲存(查詢行為不變)
- **列長不符觸發結構性驗證(對應 AC1)**
  - Given: 一份某一列只有 10 字元(非 `BOARD_WIDTH=13`)的 `rows`
  - When: 呼叫 `Board.from_ascii(rows)`
  - Then: 觸發 `push_error()`(訊息含該列索引);該列已有的字元仍正確儲存
- **單一未登記地形字元觸發組成性驗證(對應 AC2)**
  - Given: 一份棋盤,其中恰好一格使用一個不在 `TERRAIN_TABLE` 的字元(例如測試專用字元
    `"Z"`,比照 `board_passable_test.gd` 既有的 `_BoardWithImpassableTestTerrain` 手法,
    但此處是「真的未登記」而非「已登記但 passable=false」)
  - When: 呼叫 `Board.from_ascii(rows)`
  - Then: 恰好觸發一次 `push_error()`,訊息含該格座標與字元
- **多個未登記地形字元各自觸發、不因第一個就停止掃描(對應 AC2)**
  - Given: 一份棋盤,至少兩個分散於不同列的未登記字元
  - When: 呼叫 `Board.from_ascii(rows)`
  - Then: 觸發的 `push_error()` 次數 ≥ 2,且涵蓋兩個座標(不是只報第一個)
- **驗證路徑不使用 `assert()`(對應 AC3)**
  - Given: 任一組會觸發驗證失敗的輸入(結構性或組成性皆可)
  - When: 呼叫 `Board.from_ascii(rows)`
  - Then: 不觸發 GdUnit4 可識別的 `SCRIPT_ERROR`(`assert()` 失敗專屬的錯誤類型),
    只觸發 `push_error()`——比照 `board_passable_test.gd` 既有的
    `test_unregistered_terrain_character_triggers_push_error_not_assert`,用
    `is_push_error()` 而非回傳值判定
- **`reachable_tiles()` 的 `ignore_passability=true` 路徑不再被未登記地形腐蝕成本(對應 AC6,
  敏感度證明——需要間諜/突變子類別,比照 `.claude/rules/test-standards.md` 2026-09-16
  條目的要求,不得只手動改壞一次)**
  - Given: 一份含一格未登記地形字元的棋盤(鄰接一個可達起點),以及一個會把
    `_terrain_entry()` 覆寫為「對該字元回傳 `null`」的測試子類別(模擬真實的未登記情境,
    手法比照 `board_passable_test.gd` 的 `_BoardWithImpassableTestTerrain`)
  - When: 以 `ignore_passability=true` 呼叫 `reachable_tiles(origin, mp)`,`mp` 設定為
    一個若該格被誤判為負成本就會被錯誤納入結果、但正確防護下不會被納入結果的邊界值
  - Then: 該格**不**出現在回傳的可達集合中;另寫一條
    `test_sensitivity_proof_*` 測試,證明移除本 story 新增的防護(以一個刻意繞過防護的
    植入版本,或暫時註解防護邏輯)會讓該格重新出現於結果中——即此測試向量真的會因為
    AC6 的防護被拿掉而轉紅,不是一條恆綠的裝飾測試

## Test Evidence

**Story Type**: Logic

**現行測試基線**:需於動工前由實作者重新執行並記錄(`godot --headless --path . -s
tests/gdunit4_runner.gd`,`.claude/docs/coding-standards.md` CI 指令列),本 story 切出時
未重跑(與 story-003b 同期,避免與該 story 的基線量測互相覆蓋;且本 story 與 003b 存在
檔案衝突,不應同時動工,基線應在確定排程順序後由實際動工者當場重跑)。

**Required evidence**:
- 新增測試檔(建議 `tests/unit/gameplay/board/board_load_validation_test.gd`)通過全部
  QA Test Cases 向量
- `test_sensitivity_proof_*` 測試依 `.claude/rules/test-standards.md` 2026-09-16 條目,
  證明 AC6 的防護被移除時測試真的會轉紅(間諜子類別手法,非手動改壞一次性驗證)
- 重跑全套測試,確認除本 story 新增測試外,既有測試數與既有失敗數(唯一容許:既有已核准的
  `affinity_phi_provider_test.gd` 那條刻意紅)不受影響——24 處既有 `Board.from_ascii()`
  呼叫點(`grep -rln "Board\.from_ascii(" --include=*.gd .` 可重新列出清單)逐一確認
  未產生新增的 `push_error()` 噪音

## Dependencies

- Depends on: story-001(**Done**——沿用其 `TERRAIN_TABLE`/`get_move_cost()`/`passable()`
  的既有慣例與訊息格式)、story-002(**Done**——`reachable_tiles()` 的 `ignore_passability`
  開關是決策三要修正的缺口被觸發的前提條件)
- 檔案層排程限制(非邏輯依賴):**不得與 story-003b 同時動工**,見上方專節
- Unlocks: 無——本 story 不阻擋任何下游 story 的驗收條件。它關閉的是 TR-tactical-002
  的追溯缺口,並修正一個目前沒有任何 story 的驗收條件涵蓋到的既有缺口(第 250 行)。
  ⚠️ **建議(非本 story 可自行裁決的排程)**:若可行,本 story 應排在 story-007
  (「移動範圍四態查詢介面」,依賴 `ignore_passability=true` 計算 `C` 集合)動工之前
  完成,理由見上方「決策三」——但 story-007 現況已標 `Ready` 且依賴 001/002/003b,
  是否要再加上對本 story 的依賴,由排程擁有者(`producer`/`technical-director`)裁決,
  本 story 只誠實揭露這個關聯,不代為決定。

## 未涵蓋範圍(誠實揭露)

- **武器資料表驗證(`TR-tactical-005`)**——見「範圍裁決」節,理由是武器尚未成為一個
  被載入的資料檔。`traceability-index.md` 第 89 行的 ❌ 缺口**不會因本 story 關閉**。
- **`TR-tactical-002`/`traceability-index.md` 文字本身的更正**——本 story 完成後,
  是否可以把 TR-tactical-002 的 ❌ 標記轉為 ✅,由該欄擁有者 `technical-director` 判定,
  不由本 story 自行宣告已關閉。
- **是否要讓 story-007 正式依賴本 story**——已在上方 Dependencies 節誠實揭露關聯與理由,
  排程裁決本身不屬本 story 的職權。
- **本次切 story 時未重新執行全套測試基線**——理由見 Test Evidence 節,與 story-003b
  同期避免互相覆蓋量測結果,留給實際動工者在確認排程順序後當場重跑。
