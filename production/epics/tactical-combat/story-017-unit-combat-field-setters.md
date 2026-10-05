# Story 017: `Unit` 戰鬥數值欄位加 setter + 寫入守衛(ADR-0001 硬性義務第 2 條)

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(依賴 `story-003b` 完成,見下方 Dependencies——未完成前無法開工)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S(單一檔案 `unit.gd` 為主,`battle_state.gd` 少量接線;範圍小於
> `story-003b`,**但無人估過實際工時,本 story 的估計本身就是管理者裁決時已知的代價之一**)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)
> **派工來源**: 2026-10-05 管理者裁決(**唯一書面紀錄是本派工單**,協調者將在第七十五批
> 交接節補登,引用時請寫「2026-10-05 管理者裁決,紀錄於第七十五批交接節」,不要寫成某個
> 既有檔案的某一行)。背景:`story-003b` 的「未涵蓋範圍」節原寫「建議下一次
> `technical-director` 裁決是否另開工作單」,而 `technical-director` 2026-10-05 回報
> 「兩輪下來都沒排進我的交付物,這是目前唯一還掛在我名下、沒有人接手的項目」。管理者裁決
> 另切一張。已知代價(管理者知情接受):「本批已經切了一張新工作單(016),再切一張會讓
> 戰棋這條線的待做清單再長;且沒人估過它的工時。」本 story 由 `lead-programmer` 切出,
> **不實作**。

## Context

**GDD**: `design/gdd/tactical-combat-system.md`——本 story 不新增或改變任何玩家可觀測義務,
只把 ADR-0001 定案的機制(寫入守衛)套用到 `Unit` 的戰鬥數值欄位上。

**Governing ADR**: `docs/architecture/adr-0001-tactical-query-atomicity-contract.md`
(**Accepted**)——硬性義務第 2 條。**已讀 ADR 原文,不是只讀 `story-003b` 的轉述**
(`story-003b` 的 Out of Scope 節只寫了一句「`Unit` 的裸公開欄位加 setter」,未附精確
欄位清單與理由——本專案已付過「轉述與原文不符」的代價,故本次直接引用原文):

```
$ grep -n "硬性義務第 2 條\|Unit.*戰鬥數值欄位\|裸公開" docs/architecture/adr-0001-tactical-query-atomicity-contract.md
294:2. **`Unit` 的戰鬥數值欄位必須先長出 setter,再以 setter + `push_error()` 擋住非法賦值。** 現況 `unit.gd` 的 `hp`/`atk`/`def`/`mp`/`min_range`/`max_range` **一律是裸公開 `var`,連一個可以加守衛的方法都沒有** —— 這一層要先存在,第 3 條才談得上。
295:   > ⚠️ 攔截手法本身有實測(`prototypes/adr0001-board-property-spike-2026-09-01/`),**但那是在一個整數計數器上測的,套用到 `Unit` 未單獨驗證** —— 結構同構、風險低,**這是沿用,不是實測結論**。
```

**逐字解讀(本 story 直接依此定案範圍)**:
- **涵蓋欄位,恰好六個**:`hp`/`atk`/`def`/`mp`/`min_range`/`max_range`。
- **不涵蓋 `hp_max`**——ADR 原文刻意沒有列出它。本 story 不擴大範圍去猜測理由並加上去
  (`hp_max` 戰鬥中理論上不變,不是這次要防的「可能被任意外部程式碼繞過遞增機制直接改寫」
  的那類易變戰鬥數值,但這是推測,本 story 不代為裁決,原文沒列就不列)。
- **攔截手法沒有獨立實測**,是從 ADR 原文的 `Board`/`TurnOrder` 守衛模式沿用,風險標記
  為「結構同構、風險低」,不是「已證明在 `Unit` 上同樣有效」。

**Engine**: Godot 4.7.1 | **Risk**: LOW(純 GDScript 屬性/守衛邏輯,無 post-cutoff API)

**Control Manifest Rules(Core 層)**:
- 一般紀律(`.claude/docs/coding-standards.md`):**絕不用 `assert()` 保護「不可達」分支**
- 本 story 的守衛模式**必須沿用 `story-003b` 已為 `Board`/`TurnOrder` 建立的介面形狀**
  (`Callable[bool]` 注入,選擇性掛載),不得自創第三種掛載方式——理由見下方「與
  `story-003b` 的依賴關係」。

---

## 現況(2026-10-05 實測,逐指令)

`unit.gd` 全文已讀(252 行)。六個欄位現況:

```gdscript
var hp_max: int
var hp: int
var atk: int
var def: int
var mp: int
var min_range: int
var max_range: int
```

全部是裸公開 `var`,無任何守衛、無 getter/setter、無攔截點——與 ADR 原文描述一致。

**既有內部寫入點(`unit.gd` 自己)**:
- `from_csv_line()`(66-84 行):解析 roster 文字時直接賦值全部六個欄位(含 `hp_max`)。
  **此時 `Unit` 剛 `new()`,尚未被任何 `BattleState` 收編**——與 `Board`/`TurnOrder` 的
  「選擇性掛載」情境相同,不受掛載後的守衛影響。
- `take_damage()`(226-229 行):`hp = maxi(0, hp - amount)`——**這是唯一一個「`Unit` 已經
  上場、戰鬥進行中」才會被呼叫的內部寫入點**,也是本 story 設計上最關鍵的相容性問題
  (見下方「未決的實作細節」第 1 項)。

**既有外部呼叫點(當場數,`take_damage()`)**:

```
$ grep -rln "\.take_damage(" src/ tests/ --include=*.gd
src/gameplay/battle/battle_state.gd
tests/integration/gameplay/cards/card_play_session_test.gd
tests/unit/gameplay/cards/card_modifier_test.gd
tests/unit/gameplay/units/unit_test.gd
$ grep -c "\.take_damage(" src/gameplay/battle/battle_state.gd tests/integration/gameplay/cards/card_play_session_test.gd tests/unit/gameplay/cards/card_modifier_test.gd tests/unit/gameplay/units/unit_test.gd
src/gameplay/battle/battle_state.gd:1
tests/integration/gameplay/cards/card_play_session_test.gd:1
tests/unit/gameplay/cards/card_modifier_test.gd:2
tests/unit/gameplay/units/unit_test.gd:3
```

共 4 個檔案、7 處呼叫。`battle_state.gd` 那 1 處是生產呼叫點(`resolve_attack()` 內),
其餘 6 處是測試直接呼叫、**不經過任何 `BattleState`**。

**既有外部直接欄位賦值(繞過 `take_damage()`,當場數)**:

```
$ grep -rn "\.hp *= *[0-9a-zA-Z_]\|\.atk *= *[0-9a-zA-Z_]\|\.def *= *[0-9a-zA-Z_]\|\.mp *= *[0-9a-zA-Z_]\|\.min_range *= *[0-9a-zA-Z_]\|\.max_range *= *[0-9a-zA-Z_]" --include=*.gd src/ tests/
tests/unit/ai/greedy_tactical_ai_test.gd:140:	unit_ea.hp = 12
tests/unit/ai/greedy_tactical_ai_test.gd:141:	unit_eb.hp = 25
```

全repo 唯二的直接欄位賦值,皆在 `greedy_tactical_ai_test.gd`,用於建立 AI 目標優先序測試
的血量夾具,**不經過任何 `BattleState`**。

**推論(與 `story-003b` 事實一同一個形狀)**:若守衛做成「未設定來源時預設拒絕寫入」,
上述 7(`take_damage`)+ 2(直接賦值)= **9 處既有呼叫點會全部開始失敗**,外加
`from_csv_line()` 自己的 6 處內部賦值(若 setter 不分辨「尚未掛載」與「已掛載但窗口未開」)
也會失敗。**守衛必須比照 `story-003b` 的 `Board`/`TurnOrder` 模式,是「選擇性掛載」**——
未掛載時行為與今日完全相同,只有被 `BattleState` 收編後才連上真正的守衛。

---

## 與 `story-003b` 的依賴關係

**先後依賴,不是無關**。理由:

1. 本 story 要用的「選擇性守衛 + `Callable[bool]` 注入」介面形狀,是 `story-003b` 的
   「未決的實作細節」第 2 項已建議、且是 `Board`/`TurnOrder` 唯一已知的既定模式——本
   story 應該沿用同一個介面契約,不應該自己發明一套不同的掛載方式。若三個零件
   (`Board`/`TurnOrder`/`Unit`)各自長出不同形狀的守衛掛載介面,會違反
   `.claude/docs/coding-standards.md` 的「Pattern Enforcement」(同一個 ADR 硬性義務,
   三種零件三種寫法)。
2. `BattleState.create()` 本身是 `story-003b` 要大幅修改的函式(新增 `Board`/`TurnOrder`
   守衛掛載邏輯)——在它穩定之前去改它會互相踩踏同一段程式碼。本 story 也需要在
   `create()` 裡,為每個建立出來的 `Unit` 掛載守衛來源,這段新增程式碼最好接在
   `story-003b` 已經寫好的掛載邏輯之後,而不是搶在它之前。
3. 📌 **與 `story-016`/`story-003b` 的檔案層排序無關**(本 story 不碰 `board.gd`),
   但完整施工序仍是 **`story-016` → `story-003b` → `story-017`(本檔)**,理由同上
   第 2 點。

**本 story 與 `story-003c`(路徑⑥⑦)彼此無依賴,可並行**——兩者都依賴 `story-003b`,
但互不影響對方的檔案或邏輯。

---

## Scope

### In Scope

1. **六個欄位改為 property**(`hp`/`atk`/`def`/`mp`/`min_range`/`max_range`,不含
   `hp_max`——理由見上方 Context 的逐字解讀):改為 `var x: int: get: ...; set(value): ...`
   形式,實際值由私有 backing field(例如 `_hp`)持有。
2. **選擇性守衛**(比照 `story-003b` 的 `Board`/`TurnOrder` 模式):`Unit` 接受一個可選的
   守衛檢查來源(`Callable[bool]`,未設定時預設恆回傳 `true`)。setter 第一行呼叫守衛
   檢查;為 `false` 時 `push_error()` 並拒絕該次賦值(值不變)。
3. **`BattleState.create()` 為每個建立出來的 `Unit` 掛載守衛來源**(接上
   `self.write_window_is_open`,與 `Board`/`TurnOrder` 同一個方法)——需讀
   `story-003b` 完工後 `create()` 的實際寫法,接在其既有掛載邏輯之後。
4. **`take_damage()` 的相容性處理**(見下方「未決的實作細節」第 1 項,需實作者或
   `lead-programmer` 在動工前二選一確認)。
5. **`from_csv_line()` 的六處內部賦值**——不需要改動呼叫方式,因為此時 `Unit` 尚未掛載
   守衛(選擇性掛載的預設放行行為)。
6. 新增對應測試。

### Out of Scope(附理由)

- **`hp_max`/`id`/`code_name`/`faction`/`start_pos` 加守衛**——ADR 原文只列六個戰鬥數值
  欄位,不含這些,本 story 不擴大範圍。
- **改變 `take_damage()` 的扣血公式或 `tick_modifiers()` 的修正值邏輯**——本 story 只加
  守衛,不改變任何既有戰鬥數值計算行為。
- **`_modifiers`(`CardModifier` 清單)加守衛**——ADR 原文沒有提到它,且它已經是私有欄位
  (`_modifiers`),不符合「裸公開 `var`」這個 ADR 原文描述的問題。
- **`story-003b`/`story-003c` 涵蓋的 `Board`/`TurnOrder`/`BattleState` 寫入路徑**——
  本 story 不重做。

---

## 未決的實作細節(動工時必須先確認,不是本 story 代為裁決)

1. 🔴 **`take_damage()` 的內部賦值,是否也受守衛約束?這是本 story 最關鍵的設計問題。**

   `take_damage()` 是**公開**方法,目前直接 `hp = maxi(0, hp - amount)`。一旦 `hp` 變成
   受守衛的 setter,這行賦值有兩種可能寫法,取捨不同:

   - **選項 A:`take_damage()` 透過公開 setter 賦值,一樣受守衛約束。**
     好處:設計單純,只有一種賦值路徑。代價:`take_damage()` 本身也必須只能在窗口開啟時
     呼叫——目前它有 6 處測試直接呼叫、不經過任何 `BattleState`(見上方現況),若守衛
     「未掛載時預設放行」,這些測試不受影響;但**生產呼叫點**(`battle_state.gd` 的
     `resolve_attack()`)已經是 `story-003b` 要包進 `commit_authoritative_change()` 的
     既有路徑之一,此時窗口已開,呼叫合法——理論上選項 A 在生產環境下應該直接可行。
   - **選項 B:`take_damage()` 寫入私有 backing field(`_hp = maxi(0, _hp - amount)`),
     繞過公開 setter 的守衛檢查**,比照 `Board.set_occupant()`/`clear_occupant()` 在
     `story-003b` 裡「收進提交方法內部,不再對外公開」的同一種特權內部方法處置。
     好處:`take_damage()` 永遠可以呼叫,不受守衛狀態影響,既有 6 處測試呼叫點**完全
     不受本 story 影響**(連「未掛載時預設放行」這個相容性讓步都不需要討論)。代價:
     `take_damage()` 變成一個「繞過自己剛加的守衛」的特殊方法,需要在文件註解裡明確
     說明為什麼,否則下一個讀者會困惑「為什麼 `hp` 有守衛,但 `take_damage()` 不受它管」。

   **本 story 傾向選項 B**(與 `story-003b` 處理 `Board.set_occupant()`/`clear_occupant()`
   的既有先例一致:佔位/戰鬥數值的*正式*改動入口本來就該是一個受信任的內部方法,而不是
   逐欄位的裸 setter),但**請實作者動工前與 `lead-programmer` 確認**,不要自行選擇後
   才發現與既有 `Board`/`TurnOrder` 的設計慣例不一致。

2. **守衛來源的介面形狀**:沿用 `story-003b` 已確定的 `Callable[bool]` 注入模式——
   若 `story-003b` 完工時介面細節與本 story 預期的不同(例如方法名稱),本 story 以
   `story-003b` 實際完工的形狀為準,不堅持本檔描述的確切方法名。

3. **`greedy_tactical_ai_test.gd` 的 2 處直接 `.hp = ` 賦值是否需要改寫**——理論上不需要
   (這些 `Unit` 從未經過 `BattleState`,屬選擇性掛載的預設放行情境),但實作者動工時
   應該實際跑一次這個測試檔確認未受影響,而非只憑推論。

---

## Acceptance Criteria

| # | AC |
|---|---|
| 1 | `Unit` 的 `hp`/`atk`/`def`/`mp`/`min_range`/`max_range` 六個欄位改為 property,
   由私有 backing field 持有實際值 |
| 2 | 六個 setter 各自第一行檢查一個可選的守衛來源(`Callable[bool]`);未掛載時預設放行
   (向後相容既有 9+ 處直接賦值/`take_damage()` 呼叫);已掛載且窗口未開時 `push_error()`
   並拒絕該次賦值(值不變) |
| 3 | `BattleState.create()` 為每個建立出來的 `Unit` 掛載守衛來源,接上
   `self.write_window_is_open` |
| 4 | `take_damage()` 的相容性處理依「未決的實作細節」第 1 項的裁決結果實作,且該裁決
   結果已寫回本節與該節,不得只改程式碼不留文字紀錄 |
| 5 | `from_csv_line()` 的六處內部賦值不受影響(建構期尚未掛載守衛) |
| 6 | 新增 Validation Criteria 向量:「窗口未開時直接對已掛載守衛的 `Unit` 賦值 → 觸發
   `push_error()` 且值不變」,六個欄位各一條,不得合併成一條只測其中一個 |
| 7 | 全部新測試遵守 `coding-standards.md` 對 GdUnit4 的三項紀律 |

---

## Affected Files

| 檔案 | 改動性質 |
|---|---|
| `src/gameplay/units/unit.gd` | 六個欄位改為 property + 守衛檢查;`take_damage()` 依裁決結果調整 |
| `src/gameplay/battle/battle_state.gd` | `create()` 為每個 `Unit` 掛載守衛來源(接在 `story-003b` 既有掛載邏輯之後) |
| 新增測試檔(建議與既有 `unit_test.gd` 分開,理由同 `story-003b` 的分散測試檔紀律) | AC1-7 的斷言 |

---

## QA Test Cases

⚠️ 本節由 `lead-programmer` 直接撰寫,非 `qa-lead` 產出(本次派工環境無 `Task` 工具)。
建議下一次有 `Task` 工具可用時補跑一次 QL-STORY-READY 覆核。

- **未掛載守衛時,六個欄位可直接賦值(向後相容)**
  - Given: 一個未經任何 `BattleState` 收編的 `Unit`(直接 `Unit.from_csv_line(...)`)
  - When: 直接對六個欄位逐一賦值
  - Then: 正常執行,不觸發 `push_error()`(既有 `greedy_tactical_ai_test.gd` 2 處呼叫點
    的行為必須維持)
- **已掛載守衛、窗口未開時,六個欄位各自拒絕賦值**
  - Given: 一個已掛載守衛來源、窗口未開的 `Unit`
  - When: 逐一直接對六個欄位賦值
  - Then: 每一個都觸發 `push_error()` 且值不變(六條各自獨立測試)
- **`take_damage()` 的相容性**(依「未決的實作細節」第 1 項裁決結果,二選一對應測試)
  - 若選項 A:`take_damage()` 在窗口未開時呼叫應比照其他欄位拒絕;窗口開啟時正常扣血
  - 若選項 B:`take_damage()` 不受守衛狀態影響,任何時候呼叫皆正常扣血(與既有 6 處測試
    呼叫點行為一致,零迴歸)
- **`BattleState.create()` 建構出的 `Unit` 正確掛載守衛**
  - Given: 透過 `BattleState.create()` 建立的戰鬥
  - When: 在窗口未開時,直接對某個 `Unit` 的欄位賦值(繞過 `commit_authoritative_change()`)
  - Then: 觸發 `push_error()`,值不變——證明守衛確實被掛載,不是只在「選擇性掛載」下
    永遠放行

---

## Test Evidence

**Story Type**: Logic

**現行測試基線**:需於動工前由實作者重新執行並記錄——以 `story-003b` 完工後的基線為準,
不沿用 2026-09-30 的舊快照。

**Required evidence**:
- 新增測試檔通過 QA Test Cases 全部向量
- 依 `coding-standards.md` 的敏感度證明紀律:對至少一條「窗口未開仍放行賦值」的故意
  錯誤實作,重跑對應測試確認會轉紅
- 重跑全套測試(含 `greedy_tactical_ai_test.gd`、`unit_test.gd`、`card_modifier_test.gd`、
  `card_play_session_test.gd` 這 4 個既有呼叫 `take_damage()`/直接賦值的檔案),確認
  失敗數不高於 `story-003b`/`story-003c` 完工後的基線

---

## Dependencies

- **Depends on: `story-003b`(必須先 Done)**——本 story 沿用其已確定的守衛介面形狀,
  且 `BattleState.create()` 的新增掛載邏輯需要接在它既有的修改之後。
- 與 `story-003c` 無直接依賴,兩者可並行(皆依賴 `story-003b`,互不影響)。
- 📌 完整施工序:**`story-016` → `story-003b` → {`story-003c`、`story-017`(本檔)}**
  (後兩者之間無固定先後)。
- Unlocks: 無——本 story 關閉的是 ADR-0001 硬性義務第 2 條這個獨立缺口,不阻擋
  `story-004~007`(那四張已依賴 `story-003b`,不需要額外依賴本 story)。

## ⚠️ 誠實揭露(未涵蓋範圍)

- **`take_damage()` 的相容性處理是二選一的未決項**,本 story 傾向選項 B 但未代為裁決,
  留給實作者/`lead-programmer` 動工前確認(見「未決的實作細節」第 1 項)。
- **攔截手法套用到 `Unit` 未單獨實測**——ADR 原文自己標註這是沿用 `Board`/`TurnOrder`
  的既有結構,「結構同構、風險低」,不是已證明有效的結論。
- **本次切 story 時未重新執行全套測試基線**——理由同 `story-003c`,基線應由實際動工者
  在 `story-003b` 完工後當場重跑。
