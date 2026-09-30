# Story 003b: ADR-0001 原子性機制收斂 —— 版本號、寫入守衛、Board mutator 封裝

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M(單日以上,見下方「與管理者裁決的落差」)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)
> **派工來源**: 2026-09-30 管理者裁決(逐字:「開 story-003b 之類的工作單,由
> `gameplay-programmer` 把三個類別八個以上方法的遞增、寫入守衛、佔位改動收進單一入口
> 一次做齊,再開 004~007」)。本 story 由 `lead-programmer` 切出,**不實作**。

## Context

**GDD**: `design/gdd/tactical-combat-system.md` Core Rules #10a/#10b/#10c/#11、AC-9/AC-22/AC-24
—— 本 story 不新增或改變任何玩家可觀測義務,只把 ADR-0001 定案的機制落地。

**Governing ADR**: `docs/architecture/adr-0001-tactical-query-atomicity-contract.md`
(**Accepted**,2026-09-01 管理者裁決;第一次修訂 2026-09-09)——本 story **是**該 ADR
機制一「五條硬性義務」中前四條的落地工作單。第五條(Validation Criteria 逐路徑斷言)
一併落地,因為它與前四條共用同一批測試。

**Engine**: Godot 4.7.1 | **Risk**: LOW(純 GDScript 狀態機與守衛邏輯,無 post-cutoff API)

**Control Manifest Rules(Core 層)**:
- 「合成查詢的所有子結果必須攜帶同一版本號」——本 story 不新增查詢,但**是**該保證的
  底層機制本身
- 一般紀律(`.claude/docs/coding-standards.md`):**絕不用 `assert()` 保護「不可達」分支**;
  **絕不用 `call_deferred()`/`CONNECT_DEFERRED` 介入結算路徑**(ADR-0001 機制二明文禁止)

---

## ⚠️ 與管理者裁決的落差(必須在動工前確認,不是本 story 自行決定的)

管理者的派工原文估算代價是「多一張工作單的時間,且會動到 `board.gd` / `turn_order.gd` /
`battle_state.gd` **三個檔案**」。**本次切 story 時逐條 `grep` 查證後發現這個估算不完整**——
下方「Affected Files」節列出的檔案清單比三個多,理由如下,請在動工前讓管理者/
`technical-director` 知悉這個落差,而非悄悄多改兩個檔案:

```
$ grep -n "_order\.\(use_move\|use_attack\|end_unit_turn\|advance_faction\|remove_unit\)(" src/gameplay/battle/battle_controller.gd src/gameplay/battle/battle_loop.gd
```
`battle_controller.gd` 有 **10 處**、`battle_loop.gd` 有 **5 處**直接呼叫
`TurnOrder` 的五個 mutator——**不經過 `battle_state.gd`**。ADR-0001 硬性義務第 3 條要求
「三個零件的每個 mutator 第一行檢查 `authoritative_write_in_progress`」,而這 15 個呼叫點
是唯二呼叫 `TurnOrder` mutator 的地方。**若不改這兩個檔案,守衛機制加了等於沒加**——
這 15 處會直接繞過它。

`Board.set_occupant()`/`clear_occupant()` 則確實只有 `battle_state.gd` 一處呼叫(4 個呼叫點:
`create()` 1 處、`move_unit()` 2 處、`resolve_attack()` 1 處),與管理者估算一致。

---

## 現況(2026-09-30 實測,逐指令 —— 已存在什麼)

### 已經做好的部分(story-003,勿重做)

`battle_state.gd` 目前已有:

```gdscript
var _combat_state_version: int = 0
var combat_state_version: int:
	get: return _combat_state_version
	set(value): push_error(...)  # 拒絕外部寫入,值不變
```

以及 `move_unit()` 成功路徑結尾、`resolve_attack()` 結尾各一行 `_combat_state_version += 1`。
該欄位的文件註解(`battle_state.gd` 第 73–101 行)**明文自述這是刻意的部分實作**,
並逐條列出本 story 要補的東西——**本 story 就是把那份自述清單做完**,不是從零開始。

### 完全不存在的部分(本 story 的範圍)

```
$ grep -rn "authoritative_write_in_progress\|commit_authoritative_change\|write_window_is_open" src tests
```
零命中。寫入守衛、單一提交入口、佔位方法封裝,三者在全專案**一行都沒有**——
與 ADR-0001 自己記載的現況一致。

### 🔴 兩個關鍵相容性事實(直接決定本 story 的核心設計,不是次要細節)

**事實一:`Board`/`TurnOrder` 目前被大量測試直接 `new()`/`from_ascii()`,完全不經過
`BattleState`。**

```
$ grep -rn "set_occupant(\|clear_occupant(\|Board\.from_ascii(\|Board\.new()" tests --include="*.gd" -c
```
`board_test.gd`(11)、`board_reachable_tiles_test.gd`(7)、`board_passable_test.gd`(4)、
另 3 個檔案各 1~2 處,**合計 26 處**,全部在建立測試夾具時直接呼叫
`set_occupant()`/`clear_occupant()`,**不經過任何 `BattleState`、不持有任何「寫入窗口」的
概念**。

```
$ grep -rln "TurnOrder\.new(" tests --include="*.gd" | wc -l
```
**15 個測試檔、合計 63 處**直接 `TurnOrder.new(...)`,其中 `turn_order_test.gd` 一檔就有
**21 處**——這正是 ADR-0001 本文自己承諾過的:「`turn_order_test.gd` 的 21 處不受影響
(`TurnOrder` 仍是獨立可 `new()` 的 `RefCounted`)」。

**推論(這是本 story 最重要的一條設計約束)**:若把守衛做成「未設定來源時預設拒絕寫入」,
上述至少 26+63 = **89 處既有呼叫點會全部開始失敗**——這不是本 story 要付的代價,
是一個會讓現有測試套件從 993 崩到大量紅燈的迴歸。**守衛必須是「選擇性掛載」**:
`Board`/`TurnOrder` 未被指定守衛來源時,行為與今天完全相同(mutator 直接執行,
不檢查任何東西);只有當它們被 `BattleState` 建構/掛載時,才連上真正的守衛。
ADR-0001 自己那句「`TurnOrder` 仍是獨立可 `new()` 的 `RefCounted`」正是這個約束的
文本依據——本 story 只是把它同樣套用到 `Board`。

**事實二:`run_enemy_phase()` 的「整批結算」在 ADR 的驗收條件裡是單一次遞增,不是逐動作遞增。**

`docs/architecture/adr-0001-tactical-query-atomicity-contract.md` Validation Criteria
第 4 項逐字:「4d 🔴 一次敵方回合整批結算完成 → **恰好 +1**」——這句話的主詞是**整個
`run_enemy_phase()`**,不是它內部逐一呼叫的 `_process_enemy_unit()`。已讀
`battle_controller.gd:657-674` 確認 `run_enemy_phase()` 是一個 `while` 迴圈,對
`_order.units_with_flags_remaining()` 逐一呼叫 `_process_enemy_unit()`,可能為多個敵方
單位各觸發一次移動/攻擊。**若逐動作各包一次 `commit_authoritative_change()`,version
在整批結算中會 +N(N=本回合敵方動作數),直接違反 4d 這條已核准的驗收條件**——
這不是實作細節,是本 story 最容易做錯的地方,故在此明寫。

---

## Scope

### In Scope

1. **`BattleState` 新增**(硬性義務第 1 條,同物件):
   - `authoritative_write_in_progress: bool` 對外唯讀屬性,與 `combat_state_version`
     同一種攔截寫法(外部賦值 `push_error()` + 值不變)。
   - `commit_authoritative_change(mutator: Callable) -> void`——唯一提交入口:
     設旗標為 `true` → 同步呼叫 `mutator.call()`(全程無 `await`/`call_deferred`)
     → `_combat_state_version += 1` → 設旗標為 `false`。四步為一個不可分割的呼叫。
   - `write_window_is_open() -> bool`——回傳 `_authoritative_write_in_progress`,
     供 `Board`/`TurnOrder` 的守衛判斷式呼叫。

2. **`Board`/`TurnOrder` 新增「選擇性守衛」**(硬性義務第 3 條,且**必須**是選擇性的,
   理由見上方「現況」節事實一):
   - 兩者各自接受一個可選的守衛檢查來源(建議:建構子或一個 `attach_write_guard()`
     方法接受 `Callable[bool]`,未設定時預設一個恆回傳 `true` 的空 Callable)。
   - `Board.set_occupant()`/`clear_occupant()`、`TurnOrder.use_move()`/`use_attack()`/
     `end_unit_turn()`/`advance_faction()`/`remove_unit()`——**七個方法**,各自第一行
     呼叫守衛檢查;為 `false` 時 `push_error()` 並拒絕該次寫入(狀態不變)。
   - `BattleState.create()` 建構 `Board` 後、`attach_turn_order()` 掛載 `TurnOrder` 時,
     把兩者的守衛來源接上 `self.write_window_is_open`。

3. **`Board.set_occupant()`/`clear_occupant()` 不再對外公開**(硬性義務第 4 條)——
   具體形狀(改名加底線前綴 / 僅文件註解標記 / 其他)由實作者決定,**但必須同時處理**
   `battle_state.gd` 現有的 4 個直接呼叫點(`create()` 1、`move_unit()` 2、
   `resolve_attack()` 1),使它們全部落在 `commit_authoritative_change()` 的
   mutator callable 內部執行(此時守衛已開啟,呼叫合法)。

4. **`battle_state.gd` 既有兩個 mutator 改走單一入口**:
   - `move_unit()`:把「清空原格、佔用目標格、更新 `_positions`」這段邏輯包成一個
     Callable,傳給 `commit_authoritative_change()`,取代現有的手動
     `_combat_state_version += 1`。
   - `resolve_attack()`:同理,把「扣血、陣亡時清佔位」包成 Callable。
   - `create()`:把「逐一放置初始站位」路徑同樣走 `commit_authoritative_change()`
     ——見下方「未決的實作細節」第一項,這是唯一需要在動工時二選一的地方。

5. **六條寫入路徑中,五條落在本 story 範圍內,全部改走 `commit_authoritative_change()`**
   (第六條——卡牌打出第 4 步確認——**明確排除**,見 Out of Scope):

   | 路徑 | 呼叫點 | 提交粒度 |
   |---|---|---|
   | ① 玩家已確認指令的結算步 | `battle_controller.gd:_apply_attack()`(1044-1062) | 單次提交(每次呼叫一次) |
   | ② 已確認的移動邏輯 | `battle_controller.gd:_apply_move()`(1068-1076) | 單次提交(每次呼叫一次) |
   | ③ 敵方回合整批結算 | `battle_controller.gd:run_enemy_phase()`(657-674)**外加** `battle_loop.gd:run()`(110-)/`_process_unit()`(211-)的等效整批範圍 | 🔴 **整個迴圈一次提交**,不是逐 `_process_enemy_unit()` 一次(見上方事實二) |
   | ④ 玩家主動結束單位行動 | `battle_controller.gd:end_unit_turn()`(606-615,呼叫點在 611) | 單次提交 |
   | ⑤ 玩家結束陣營回合 | `battle_controller.gd:end_faction_phase()`(633-641,呼叫點 640)、`_finalize_enemy_phase()`(呼叫點 703,需讀取該函式確認)、`battle_loop.gd:119` | 單次提交(各自獨立) |

   `battle_loop.gd` 是與 `battle_controller.gd` 平行的第二條驅動路徑(ADR 原文:
   「`BattleLoop` 是與 `BattleController` 平行的第二條驅動路徑,互不呼叫,提交方法
   必須是兩者共用的那一個」)——**兩者共用同一個 `commit_authoritative_change()`
   (掛在共同的 `BattleState` 實例上),不得各自複製一份包裝邏輯**。

6. **Validation Criteria 逐路徑斷言測試**(硬性義務第 5 條,ADR 原文 4a–4k,
   排除 4g/與卡牌相關的部分):
   - 4a 連續唯讀操作版本不變(既有測試已覆蓋一部分,需擴充)
   - 4b/4c 單次玩家指令結算/移動邏輯完成 → 恰好 +1(既有測試已覆蓋,需在重構後複驗仍成立)
   - 4d 一次敵方整批結算完成 → **恰好 +1**(新增,含多單位動作的情境)
   - 4e 玩家主動結束單位行動 → 恰好 +1(新增)
   - 4f 玩家結束陣營回合 → 恰好 +1(新增,含經 `run_enemy_phase()` 自動觸發的
     `advance_faction()` 呼叫點——與玩家主動呼叫 `end_faction_phase()` 是**不同呼叫點**,
     ADR 原文明寫兩者要分開驗)
   - 4i 單位選取/取消選取 → 版本不變(明文裁定不算權威寫入——若現有程式碼有這類操作,
     需確認它們確實未接入 `commit_authoritative_change()`)
   - 4j 經 `BattleLoop` 而非 `BattleController` 驅動的同類寫入 → 恰好 +1
     (只測其中一條驅動路徑,另一條的繞過完全不可觀測——ADR 原文明寫此風險)
   - 4k **守衛測試**:七個 mutator 各一條——寫入窗口未開時直接呼叫,斷言
     `push_error()` 觸發且目標值不變

### Out of Scope(明確排除,附理由)

- **路徑⑥(卡牌打出第 4 步確認)**——`skill-card-system` 已完成的既有程式碼是否/如何
  呼叫 `commit_authoritative_change()`,不在本 story 範圍。本 story 只負責把入口建好;
  卡牌系統何時接上是該系統自己的工作單(#6 已完成 18 張 story,若需要接線是新工作單)。
- **`Unit` 的裸公開欄位加 setter**(ADR-0001 硬性義務第 2 條)——**刻意排除**,理由:
  ①管理者的派工原文只點名 `board.gd`/`turn_order.gd`/`battle_state.gd` 三個檔案,
  未提及 `unit.gd`;②它防的是另一種失效模式(單位數值被任意外部程式碼繞過遞增機制
  直接改寫),與本 story 的核心(版本號遞增 + 寫入守衛 + 佔位封裝)是可獨立驗收的
  不同關注點;③`story-003` 已驗證過 `is_attack_range_blocked_by_los` 這個查詢不依賴
  它。**這不代表義務已消失**——已在下方「未涵蓋範圍」誠實登記,建議另開工作單。
- **`class_name Board` 命名衝突的處置**——ADR 自己註明「所有權落地後、或第一張實作
  story 之前,孰早」處置,本 story 完成後所有權已落地,但**是否處置由下一次裁決決定**,
  不由本 story 代為裁決。
- **後續 `/architecture-review`**(ADR Validation Criteria 第 6 項)——需要獨立會話執行,
  不是本 story 的產出。

---

## Acceptance Criteria

*逐條對照 ADR-0001 五條硬性義務 + Validation Criteria,缺的已在上方 Out of Scope 說明理由:*

| # | AC | 對應 ADR 條文 |
|---|---|---|
| 1 | `BattleState` 新增 `authoritative_write_in_progress`(唯讀屬性,外部賦值 `push_error()` 且值不變)、`commit_authoritative_change(mutator: Callable) -> void`、`write_window_is_open() -> bool` | 硬性義務第 1 條 |
| 2 | `Board`/`TurnOrder` 的七個 mutator(`set_occupant`/`clear_occupant`/`use_move`/`use_attack`/`end_unit_turn`/`advance_faction`/`remove_unit`)第一行檢查守衛;守衛未掛載時預設放行(向後相容既有 89 處直接建構的測試);已掛載且窗口未開時 `push_error()` 並拒絕寫入 | 硬性義務第 3 條 |
| 3 | `BattleState.create()`/`attach_turn_order()` 把 `Board`/`TurnOrder` 的守衛來源接上 `write_window_is_open` | 硬性義務第 1+3 條的接線 |
| 4 | `Board.set_occupant()`/`clear_occupant()` 不再對外公開(具體形狀由實作者決定),`battle_state.gd` 的 4 個直接呼叫點全部改為經由 `commit_authoritative_change()` 執行 | 硬性義務第 4 條 |
| 5 | `move_unit()`/`resolve_attack()` 改走 `commit_authoritative_change()`,移除手動 `_combat_state_version += 1` | 機制一(遞增時機收攏至單一入口) |
| 6 | `battle_controller.gd` 10 處、`battle_loop.gd` 5 處對 `TurnOrder` mutator 的直接呼叫,全部改為透過 `commit_authoritative_change()` 執行(單次提交或整批提交,見上方粒度表) | 機制一(六條路徑其五) |
| 7 | `run_enemy_phase()`(及 `battle_loop.gd` 對應的整批範圍)的版本遞增為**整批一次**,不是逐單位動作一次 | Validation Criteria 4d(逐字驗收) |
| 8 | Validation Criteria 4a/4b/4c/4d/4e/4f/4i/4j/4k 各有至少一條對應斷言測試,且與既有 993 條測試共存、不使基線失敗數上升 | 硬性義務第 5 條 |
| 9 | 全部新測試遵守 `coding-standards.md` 對 GdUnit4 的三項紀律(直接呼叫 `RefCounted` 方法而非模擬按鍵、分散測試檔避免同套件中止污染敏感度證明、故意弄壞產品程式碼逐條證明測試真的會紅) | ADR Validation Criteria 第 4 項附帶紀律 |

---

## Affected Files

🔴 **比管理者原估算多兩個檔案,理由見上方「與管理者裁決的落差」節**:

| 檔案 | 改動性質 |
|---|---|
| `src/gameplay/battle/battle_state.gd` | 新增守衛屬性 + 提交入口;`move_unit()`/`resolve_attack()`/`create()` 改走它;掛載 `Board`/`TurnOrder` 的守衛來源 |
| `src/gameplay/board/board.gd` | 新增可選守衛來源;`set_occupant`/`clear_occupant` 加守衛檢查 + 不再對外公開 |
| `src/gameplay/battle/turn_order.gd` | 新增可選守衛來源;五個 mutator 加守衛檢查 |
| 🔴 `src/gameplay/battle/battle_controller.gd` | **管理者估算未列出此檔**——10 處 `_order.*` 呼叫改走提交入口,`run_enemy_phase()` 整批包一次 |
| 🔴 `src/gameplay/battle/battle_loop.gd` | **管理者估算未列出此檔**——5 處 `_order.*` 呼叫改走同一個提交入口(與 controller 共用) |
| 新增測試檔(建議與既有 `attack_los_blocked_query_test.gd` 分開,理由見 coding-standards.md 「同套件內任一測試失敗會中止其後全部測試」的紀律) | Validation Criteria 4a–4k 的斷言 |

---

## 未決的實作細節(動工時必須先確認,不是本 story 代為裁決)

1. **`BattleState.create()` 的初始站位放置,是否也走 `commit_authoritative_change()`?**
   - 選項 A(建議預設):放置也走提交入口,每個單位一次或整批一次皆可——已查證
     `tests/unit/gameplay/battle/attack_los_blocked_query_test.gd` 現有的
     `combat_state_version` 測試皆以「建構後的某個時刻」為基準點(`before = state.combat_state_version`
     再比較差值),**沒有任何測試斷言建構完成後版本號恰為 `0`**,故此選項不會破壞現有測試。
   - 選項 B:另開一個不經守衛的建構期專用私有方法,建構完成後版本號維持 `0`。
     好處是語意更乾淨(「0 = 全新未變動的戰鬥」),代價是多一條繞過守衛的路徑。
   - **本 story 傾向選項 A**(單一機制,無例外路徑),但請實作者動工前再次確認
     `board_reachable_tiles_test.gd`/`board_passable_test.gd` 等直接建構 `Board`
     (不經 `BattleState`)的測試不受影響——這些測試從未經過 `create()`,不受此項選擇牽動。

2. **守衛來源的介面形狀**:建議 `Callable` 注入(建構子參數或
   `attach_write_guard(checker: Callable) -> void`),優於讓 `Board`/`TurnOrder`
   持有 `BattleState` 的具體型別參照——後者會讓 `Board`「不持有旗標」這條 ADR 明文的
   分層原則出現一個間接違反的灰色地帶(見 ADR 原文「已否決的替代做法:讓 `Board`
   反過來持有單位集合的參照」)。**若實作者認為 `Callable` 注入不可行,請先回報
   `lead-programmer` 再改變設計**,不要自行改用具體型別參照。

3. **`_finalize_enemy_phase()` 是否也在整批提交的範圍內**(路徑⑤ 的第二個
   `advance_faction()` 呼叫點,行號 703)——需要讀該函式全文確認它是否與
   `run_enemy_phase()` 的整批提交共用同一次 `commit_authoritative_change()`,
   還是獨立成第二次提交。**傾向獨立**(它是「整批結算完成後」的收尾步驟,語意上是
   路徑⑤ 而非路徑③),但未讀該函式全文,留給實作者確認。

---

## QA Test Cases

⚠️ 本節由 `lead-programmer` 依 ADR-0001 原文直接撰寫,非 `qa-lead` 產出(本次派工的執行
環境未提供 Task 工具)。建議下一次有 Task 工具可用時,對本節補跑一次 QL-STORY-READY 覆核。

- **守衛預設放行(向後相容)**
  - Given: 一個未掛載守衛的 `Board`(直接 `Board.from_ascii(...)`,不經 `BattleState`)
  - When: 呼叫 `set_occupant()`
  - Then: 正常執行,不觸發 `push_error()`(既有 26 處測試呼叫點的行為必須維持)
- **守衛掛載後,窗口未開時拒絕寫入**
  - Given: 一個 `BattleState`(已掛載守衛,`authoritative_write_in_progress` 為 `false`)
  - When: 繞過 `commit_authoritative_change()`,直接呼叫 `state.board.set_occupant(...)`
  - Then: 觸發 `push_error()`,佔位表不變
- **單次玩家攻擊 → 版本恰好 +1**(複驗既有行為在重構後仍成立)
  - Given: 一個合法攻擊情境
  - When: 呼叫 `_apply_attack()`
  - Then: `combat_state_version` 恰好 +1
- **敵方整批結算(多單位、多動作)→ 版本恰好 +1,不是 +N**
  - Given: 至少兩個敵方單位皆有可執行動作的盤面
  - When: 呼叫 `run_enemy_phase()`,該回合內至少發生兩次獨立的移動/攻擊動作
  - Then: `combat_state_version` 相對呼叫前**恰好 +1**(不是 +2 或更多)
- **`BattleLoop` 路徑的敵方整批結算同樣恰好 +1**
  - Given: 透過 `BattleLoop.run()` 驅動的等效情境
  - Then: 同上,+1
- **玩家結束單位行動 / 結束陣營回合各自恰好 +1,且是各自獨立的呼叫**
  - Given: 一個玩家主動呼叫 `end_unit_turn()` 的情境,以及一個獨立的 `end_faction_phase()` 情境
  - Then: 兩者分別使版本恰好 +1(不因為呼叫了其中一個而讓另一個的斷言失去意義)
- **七個 mutator 逐一驗證窗口未開時拒絕**
  - Given: 已掛載守衛、窗口未開的 `Board`/`TurnOrder`
  - When: 逐一直接呼叫 `set_occupant`/`clear_occupant`/`use_move`/`use_attack`/
    `end_unit_turn`/`advance_faction`/`remove_unit`
  - Then: 每一個都觸發 `push_error()` 且狀態不變(七條各自獨立的測試,不得合併成一條
    只測其中一個就代表全部)

---

## Test Evidence

**Story Type**: Logic
**現行測試基線(2026-09-30,協調者獨立跑過,`Overall Summary` 整行)**:
```
Overall Summary: 993 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans
```
Exit code 100。**唯一容許的失敗**:既有已核准的
`tests/unit/gameplay/affinity/affinity_phi_provider_test.gd >
test_phi_reflects_a_pairing_polarity_flip_made_after_construction`
(刻意紅、已核准,非本 story 造成)。

**Required evidence**(本 story 完成時):
- 新增測試檔(建議與 `attack_los_blocked_query_test.gd` 分開放置)通過 QA Test Cases
  全部向量 + Validation Criteria 4a/4b/4c/4d/4e/4f/4i/4j/4k
- 重跑全套測試,`Overall Summary` 的失敗數維持 `1`(同一條既有核准失敗),新增測試數
  = 993 + 本 story 新增條數
- 依 `coding-standards.md` 的敏感度證明紀律:對至少一條「窗口未開仍放行寫入」的
  故意錯誤實作,重跑對應測試確認會轉紅(不是只跑一次綠燈就結案)

---

## Dependencies

- Depends on: story-003(**Done**——本 story 直接承接其 `combat_state_version` 欄位與
  文件註解裡明列的待補清單)
- 依管理者裁決,**排在 story-004~007 之前**:本 story 完成前,004~007 不應開工
  (施工序調整見 `story-index.md` 與 `EPIC.md` 的對應更新)
- Unlocks: story-004、story-005、story-006、story-007(四者皆標「受 ADR-0001 管轄」但
  原本沒有任何一張負責把機制做出來——本 story 補上這個缺口)

## ⚠️ 本次切 story 的誠實揭露(未涵蓋範圍)

- **`Unit` 裸公開欄位加 setter**(ADR-0001 硬性義務第 2 條)——刻意排除於本 story,
  理由見上方 Out of Scope。**這不代表義務已消失**,建議下一次 `technical-director`
  裁決是否另開工作單,或併入某張手足 story。
- **卡牌打出第 4 步確認(路徑⑥)接入 `commit_authoritative_change()`**——不在本 story
  範圍,由 `skill-card-system` 既有程式碼另行接線(是否需要新工作單,由該系統擁有者判斷)。
- **`_finalize_enemy_phase()` 的提交粒度歸屬**(路徑③ 還是路徑⑤ 的一部分)——留給實作者
  讀該函式全文後確認,見上方「未決的實作細節」第 3 項。
- **`class_name Board` 命名衝突**——本 story 完成後三個零件的所有權已落地,但是否處置
  該衝突由下一次裁決決定,不由本 story 代為處置。
- **後續 `/architecture-review`**(ADR Validation Criteria 第 6 項)——需獨立會話執行,
  不是本 story 的產出範圍。
