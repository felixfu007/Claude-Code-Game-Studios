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

> 🔴 **2026-10-05 管理者裁決(紀錄於第七十五批交接節,本檔是目前唯一的書面紀錄):
> 本 story 拆成兩張。** 管理者看到的選項描述逐字:「這是唯一真的切得開的地方 ——
> 核心半(計數器 + 守衛 + 15 個呼叫點改道)必須同一次落地,否則守衛一掛上去沒改道的
> 呼叫點全部被擋;而⑥⑦ 是純追加的包裝、不動守衛。拆後第一張回到今早的規模,第二張小。」
> 已知代價(管理者知情接受):「多一張工作單要管;而且⑥(回合轉換)今天就會真的改到
> 攻防值,拆出去就是多一段『機制做好了但這條路徑還漏著』的時間窗。」
>
> **本檔(`story-003b`)自此以下的範圍 revert 回路徑①~⑤(2026-09-30 當天的原始範圍)。**
> 下方內容裡所有與路徑⑥⑦(`begin_player_turn()`/`tick_all_modifiers()`,含 AC10/AC12、
> 對應 QA Test Cases、Test Evidence 附加要求)相關的段落**原文保留、不刪一字**,但已不是
> 本 story 的實作範圍——這些內容已搬至
> `production/epics/tactical-combat/story-003c-player-turn-start-commit-wrapping.md`,
> **實作時請以該檔為準**,本檔對應段落僅保留為決策紀錄供日後查閱「當初為什麼這樣判定」。
> 每一處搬遷點已在原文旁加註標記,不必通篇自行比對。
> ⚠️ **例外:AC11 不搬,留在本 story**——理由與跨檔案關係見下方 Acceptance Criteria
> 節的附加說明。

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

> 🔴 **已搬至 `story-003c`,本處保留為決策紀錄。** 以下「事實三」全段(含判定一、判定二)
> 是路徑⑥⑦的發現過程與推導依據,2026-10-05 管理者裁決後已整段搬至
> `story-003c-player-turn-start-commit-wrapping.md` 的「現況」節。**實作時請讀該檔,
> 不要依賴本處。** 唯一例外:判定二解答的「未決的實作細節第 3 項」(`_finalize_enemy_phase()`
> 是否獨立提交)屬路徑⑤,**該部分的結論(AC11)仍留在本 story**——見下方。

**事實三(2026-10-05 `technical-director` 裁決併入,協調者獨立複驗後發現範圍比原報告更大,
`lead-programmer` 本次再擴大一次並寫明判定):`begin_player_turn()`/`tick_all_modifiers()`
是第六、七條未登記的權威寫入路徑,且兩個驅動層(`BattleController`/`BattleLoop`)的呼叫
形狀不是同一件事的兩個入口,而是結構不同的兩組呼叫鏈,不能假設兩邊的補法一樣。**

`technical-director` 裁決 ADR-0001 巢狀語意時發現 `_finalize_enemy_phase()` 呼叫
`begin_player_turn()`,而 `begin_player_turn()` 改 `ATK_eff`/`DEF_eff`(ADR-0001 第 179 行
明文列入版本號背書範圍)卻不遞增版本號。協調者獨立複驗鏈路成立,並額外發現
`battle_loop.gd` 有兩處命中(第 88 行、第 152 行)而非 `technical-director` 報告提到的一處。
`lead-programmer` 依協調者要求讀過兩處上下文(`battle_loop.gd:79-90` 的建構子註解、
`battle_controller.gd:200-212` 的對應建構子註解、`battle_controller.gd:792-799` 的
`step_enemy_phase()`),判定如下:

**判定一:`battle_loop.gd` 第 88 行與第 152 行(以及 `battle_controller.gd` 對應的第 212 行
與 704 行)是兩條獨立路徑,不是同一條路徑的兩個入口。**

- 第 88/212 行(各自在 `_init()` 建構子內)是**一次性、建構期**的 `tick_all_modifiers()`
  直接呼叫。兩處文件註解(`battle_loop.gd:79-87`、`battle_controller.gd:200-211`)逐字
  說明同一個理由:**回合一的玩家階段永遠不會經過 `advance_faction()` 那個分支**
  (`battle_loop.gd` 是 `run()` 迴圈裡的 `acting_ids.is_empty()` 分支,
  `battle_controller.gd` 是 `run_enemy_phase()`/`step_enemy_phase()` 觸發的
  `_finalize_enemy_phase()`),所以**若沒有這個建構期呼叫,回合一會是全場唯一一次
  「玩家回合開始」卻沒有被 tick 到的事件**。兩處註解都明寫「目前沒有任何修正值能在
  建構當下就存在,所以今天是 no-op」——**但這是現況事實,不是結構保證**:一旦有任何
  未來 story 讓戰鬥開始前就能套用修正值(例如賽前增益、開場被動效果),這個呼叫會從
  no-op 變成真正的靜默寫入。
- 第 152/704 行是**每次 ENEMY→PLAYER 轉換**都會執行的 `begin_player_turn()` 呼叫
  (`battle_loop.gd` 在 `run()` 的主迴圈裡,`battle_controller.gd` 在
  `_finalize_enemy_phase()` 裡),涵蓋的是**遊戲進行中**真正會修改修正值的情境
  (`CardModifier` 倒數到期)。這是今天**已經可觸發、非 no-op**的寫入路徑。
- 兩者呼叫的時機互斥(一個只在建構當下、一個只在之後的每個回合轉換),涵蓋的是
  GDD Formula 二「每次玩家回合開始都要 tick」這個單一語意下的**兩個不重疊時間窗**
  (比照兩處註解自己的用詞:「這兩個類別是本故事的鉤子必須一致涵蓋的兩個獨立戰鬥驅動層」)。
  **因此判定為兩條獨立路徑,各自需要納入 `commit_authoritative_change()` 的覆蓋範圍,
  不能只處理其中一個就視為兩者皆已覆蓋。**

**判定二:`_finalize_enemy_phase()` 有兩個呼叫者,這直接影響它該怎麼包委交入口,
且替「未決的實作細節」第 3 項提供了一個可用答案(見下方該節的補充註記)。**

```
$ grep -n "_finalize_enemy_phase()" src/gameplay/battle/battle_controller.gd
673:	_finalize_enemy_phase()
799:		_finalize_enemy_phase()
```

第 673 行是 `run_enemy_phase()`(整批同步迴圈,路徑③)結尾的收尾呼叫;第 799 行是
`step_enemy_phase()`(逐步、呈現層驅動,`battle_screen.gd` 唯一在用的生產路徑——
見該方法文件註解「Production code only ever calls this method」)在
`_next_enemy_step_id()` 回傳 `-1`(本階段已無單位可動)時的收尾呼叫。**這兩個呼叫者
在生產環境下是互斥但都真實存在的入口**——`run_enemy_phase()` 的整批同步只有測試與
未來的非呈現層驅動會用,正式遊戲走的是 `step_enemy_phase()` 逐步呼叫,而後者**不在
任何外層迴圈裡**,`_finalize_enemy_phase()` 是它唯一會執行的收尾動作。

**`battle_loop.gd` 沒有對應的「兩個呼叫者」問題**——它沒有拆出等價的 `_finalize_enemy_phase()`
輔助方法,第 119 行(`advance_faction()`)與第 152 行(`begin_player_turn()`,條件式)
是同一次 `run()` 迴圈疊代、同一個程式碼區塊內的兩行先後敘述,只有一種呼叫脈絡。

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

   > 🔴 **2026-10-05 補充(不修改上面這句原文的數字,僅附加——原文寫作當下只知道五條,
   > 以下是當天新增的理解):下表實際已擴充到八條,比原文多兩條(⑥⑦),原文仍落在本
   > story 範圍內的因此是七條,不是五條。** 新增的兩條見下表⑥⑦列,理由見上方「現況」
   > 節事實三的判定一/判定二。原本被排除的「第六條」(卡牌打出第 4 步確認)**仍然
   > 排除**,只是因為新增了⑥⑦兩列,它在下表中不再是最後一條——這只是表格排版位置
   > 的變化,排除的裁決本身未變。

   | 路徑 | 呼叫點 | 提交粒度 |
   |---|---|---|
   | ① 玩家已確認指令的結算步 | `battle_controller.gd:_apply_attack()`(1044-1062) | 單次提交(每次呼叫一次) |
   | ② 已確認的移動邏輯 | `battle_controller.gd:_apply_move()`(1068-1076) | 單次提交(每次呼叫一次) |
   | ③ 敵方回合整批結算 | `battle_controller.gd:run_enemy_phase()`(657-674)**外加** `battle_loop.gd:run()`(110-)/`_process_unit()`(211-)的等效整批範圍 | 🔴 **整個迴圈一次提交**,不是逐 `_process_enemy_unit()` 一次(見上方事實二) |
   | ④ 玩家主動結束單位行動 | `battle_controller.gd:end_unit_turn()`(606-615,呼叫點在 611) | 單次提交 |
   | ⑤ 玩家結束陣營回合 | `battle_controller.gd:end_faction_phase()`(633-641,呼叫點 640)、`_finalize_enemy_phase()`(呼叫點 703,需讀取該函式確認)、`battle_loop.gd:119` | 單次提交(各自獨立) |
   | 🔴 ⑥ 回合轉換時的玩家回合開始鉤子(`begin_player_turn()`/`tick_all_modifiers()`,2026-10-05 新增) | `battle_controller.gd:_finalize_enemy_phase()`(704,緊接 703 之後,同一函式——見判定二)、`battle_loop.gd:run()`(152,緊接 119 之後,同一程式碼區塊,條件式執行於 `current_faction()==PLAYER`) | **與⑤同一次提交範圍**,不得獨立另開一次——`_finalize_enemy_phase()` 的 703/704 兩行、`battle_loop.gd` 的 119/152 兩行,各自必須落在同一個 mutator Callable 內,不得其中一行在窗口內、另一行在窗口外 |
   | 🔴 ⑦ 建構期一次性玩家回合開始鉤子(`tick_all_modifiers()`,2026-10-05 新增,**本項為 `lead-programmer` 本次主動擴大的發現,非 `technical-director`/管理者今日原始指認範圍**——見下方附加說明) | `battle_controller.gd:_init()`(212)、`battle_loop.gd:_init()`(88) | 各自獨立單次提交(建構子執行一次、提交一次) |

   `battle_loop.gd` 是與 `battle_controller.gd` 平行的第二條驅動路徑(ADR 原文:
   「`BattleLoop` 是與 `BattleController` 平行的第二條驅動路徑,互不呼叫,提交方法
   必須是兩者共用的那一個」)——**兩者共用同一個 `commit_authoritative_change()`
   (掛在共同的 `BattleState` 實例上),不得各自複製一份包裝邏輯**。

   🔴 **路徑⑦的附加說明(誠實標註範圍來源,供管理者/`technical-director` 覆核時快速辨識)**:
   今天的管理者裁決與 `technical-director` 的原始報告只點名「`begin_player_turn()` 經
   `_finalize_enemy_phase()` 漏遞增版本號」這一件事(即路徑⑥)。路徑⑦(建構子內的
   一次性 `tick_all_modifiers()` 呼叫)是 `lead-programmer` 依協調者「判定兩處是否為
   同一路徑」的要求讀碼時,**額外**發現的同類寫入(同一個會改 `ATK_eff`/`DEF_eff` 的
   方法,只是觸發時機不同)。**建議納入**,理由:
   1. 今天是 no-op(兩處文件註解皆明寫「尚無修正值能在建構當下存在」),但這是**現況
      事實,不是結構保證**——未來任何「開場前效果」類設計都會讓它從 no-op 變成真正的
      靜默漏寫,而且因為它是建構子裡的一次性呼叫,不會被任何「每回合」類的回歸測試
      自然覆蓋到。
   2. 包裝成本極低(建構子已經呼叫 `tick_all_modifiers()`,改成包一層
      `commit_authoritative_change()` 不改變呼叫時機或既有的 no-op 行為)。
   3. 本 story 既有的「未決的實作細節」第 1 項已確認「沒有任何測試斷言建構完成後版本號
      恰為 `0`」——若路徑⑦讓建構完成後版本變成 `1`(no-op 提交仍會遞增版本,見下方
      AC12 的討論),**不會破壞任何既有測試**。
   **若管理者/`technical-director` 認為路徑⑦超出今天裁決的範圍,可單獨descope 這一項
   而不影響路徑⑥與本 story 其餘範圍**——兩者是獨立的表格列,刻意分開寫,方便單獨抽掉。

   > 🔴 **2026-10-05 後續裁決:上面⑥⑦兩列(含本段附加說明)已搬至 `story-003c`,
   > 原文保留僅供決策紀錄。實作時請讀 `story-003c-player-turn-start-commit-wrapping.md`
   > 的對應路徑表。** ①~⑤ 五列仍是本 story 的實際範圍。

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
| 🔴 10(2026-10-05 新增) | 路徑⑥:`battle_controller.gd:_finalize_enemy_phase()` 的 703/704 兩行(`advance_faction()` + `begin_player_turn()`)、`battle_loop.gd:run()` 的 119/152 兩行,各自落在**同一個** `commit_authoritative_change()` mutator Callable 內(不得其中一行在窗口內、另一行在窗口外) | 機制一(路徑⑥,現況「事實三」判定一) |
| 🔴 11(2026-10-05 新增) | `_finalize_enemy_phase()` 本身包一層 `commit_authoritative_change()`(涵蓋判定二發現的兩個呼叫者:`run_enemy_phase()` 673 行與 `step_enemy_phase()` 799 行);依 `技術總監` 已裁決的巢狀深度計數器機制(見「未決的實作細節」節的補丁),經 `run_enemy_phase()` 整批外層提交呼叫到時應收斂為同一次 +1,經 `step_enemy_phase()`(生產環境唯一呼叫路徑)單獨呼叫到時應獨立 +1 | 機制一(路徑⑥,現況「事實三」判定二;解決「未決的實作細節」第 3 項,見該節補充註記) |
| 🔴 12(2026-10-05 新增,**本項為 `lead-programmer` 主動擴大的建議範圍,非今日裁決原始指認,可單獨 descope**) | 路徑⑦:`battle_controller.gd:_init()`(212)、`battle_loop.gd:_init()`(88)的一次性 `tick_all_modifiers()` 呼叫各自包一層 `commit_authoritative_change()` | 機制一(路徑⑦,詳見 Scope 第 5 項路徑表下方的「附加說明」) |

> 🔴 **2026-10-05 拆 story 後的歸屬裁決(`lead-programmer` 決定,理由寫在此處——
> 管理者裁決原文明寫「兩邊都說得通,不代為決定」):**
> - **AC10、AC12 已搬至 `story-003c`**,原文保留為決策紀錄,實作時以該檔為準。
> - **AC11 留在本 story,不搬。** 理由:AC11 解答的是本 story 自己既有的「未決的實作
>   細節第 3 項」(`_finalize_enemy_phase()` 的 `advance_faction()` 呼叫,即路徑⑤,
>   從本 story 原始範圍切出 story-003b 當下就已經存在的開放問題),不是路徑⑥⑦本身
>   帶來的新問題——路徑⑥⑦只是「順便」讓這個既有問題有了更清楚的解法(巢狀深度計數器)。
>   若把 AC11 也搬走,`_finalize_enemy_phase()` 的提交包裝(路徑⑤的 `advance_faction()`
>   呼叫)在 story-003c 完工前會完全沒有任何 story 負責,等於讓本 story 自己範圍內的
>   開放問題無人接手。`_finalize_enemy_phase()` 函式本體只有兩行(703 `advance_faction()`、
>   704 `begin_player_turn()`),實作上沒有理由把提交包裝拆成兩次呼叫分兩個 story 各包
>   一行——**本 story 的 AC11 要求實作者包住整個函式本體(兩行)**,`story-003c` 則只需要
>   另外新增測試,證明 704 那一行(`begin_player_turn()`)的寫入確實落在本 story 已經
>   建好的提交窗口內,**不需要重新設計或重新包裝**。兩張 story 對同一段程式碼的分工是
>   「003b 負責讓它存在且正確,003c 負責多驗一條本來不在 003b 驗收範圍內的斷言」,
>   不是「各包一半」。

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

> 🔴 **2026-10-05 `technical-director` 裁決:第 1 項已裁決,第 2、3 項仍留給實作者。**
> **裁決落在 ADR-0001 第二次修訂(不是本檔)** —— 理由:版本號語意與 `commit_authoritative_change()`
> 的巢狀語意是 ADR 的契約面,把補丁寫在 story 檔裡,下一個讀 ADR 的人不會看到它(本專案已登記
> 「散文複本與登記表脫節」的反覆前例)。查閱位置:
> `docs/architecture/adr-0001-tactical-query-atomicity-contract.md` 機制二末段的
> 「第二次修訂(2026-10-05)」三節。
>
> **第 1 項(`create()` 的初始站位)的裁決結論**:採**選項 B 的語意**(版本號維持 0),
> **但不採選項 B 描述的實作**。不新增任何繞過守衛的私有方法 ——
> **改為「守衛在 `create()` 的放置迴圈完成之後才掛載」**:放置期間 `Board` 尚未指定守衛來源,
> 依本 story 自己要求的「選擇性掛載」語意,行為與今日完全相同,因此選項 B 原本要付的
> 「多一條繞過守衛的路徑」這項代價**不必付**。
> 🔴 **硬性順序(做反了不報錯,只會讓 `create()` 整支失敗)**:
> `Board.from_ascii()` → 放置迴圈 → **最後**接上守衛來源 → `return state`。
> `attach_turn_order()` 同理,在掛載該 `TurnOrder` 的那一刻才接上。
>
> **另外兩項同批裁決,直接改變本 story 的實作形狀,動工前必讀**:
> 1. **`commit_authoritative_change()` 的旗標是深度計數器,不是布林。** 本 story Scope 第 1 項
>    寫的四步(設 `true` → 呼叫 mutator → 版本 +1 → 設 `false`)**必須改為**:深度 +1 →
>    呼叫 mutator → 深度 −1 → **僅當深度由 1 歸 0 時**版本 +1。
>    **理由**:本 story 的 AC-5(`move_unit`/`resolve_attack` 改走提交入口)與 AC-6/AC-7
>    (驅動層 15 處改走提交入口、整批恰好 +1)**在布林下互斥** —— 兩者都成立時
>    `_apply_attack()` → `resolve_attack()` 就是巢狀。逐格推導見 ADR 該節的表。
>    `write_window_is_open() -> bool` 與對外屬性 `authoritative_write_in_progress: bool`
>    **形狀不變**,故 `card_play_session.gd` / `battle_menu.gd` 既有的
>    `authoritative_write_in_progress_check: Callable` 佔位**一個字都不必改**。
> 2. **新增一條驗收向量 4l(巢狀提交 → 恰好 +1)**,請併入 AC-8 的清單:
>    外層提交內再開一次內層,斷言版本恰好 +1、內層結束後窗口仍開、外層結束後才關、深度歸零。
>
> ⚠️ **本 story「現況」節事實一的「26 處」已複驗為誤,但結論不變。**
> 實測 `grep -rn "set_occupant(\|clear_occupant(" tests --include="*.gd" | wc -l` 是個位數;
> 原 26 是因為該節引用的指令把 `Board.from_ascii(` / `Board.new()` 一起算了進去,而
> `from_ascii` 佔絕大多數。**「守衛必須選擇性掛載」這個結論不受影響**(`TurnOrder.new(` 的
> 63 處 / 15 檔已獨立複驗為正確),且該結論已於同批升格為 ADR-0001 的契約。
> **原文保留不動**,此處只加註 —— 下一個引用那個數字的人請當場重數。


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

> 🔴 **2026-10-05 `lead-programmer` 補充註記(不修改上面第 3 項原文,僅附加):
> 已讀 `_finalize_enemy_phase()` 全文與其呼叫者,原本「傾向獨立」的直覺現在有具體依據,
> 且 2026-10-05 的巢狀深度計數器裁決(本節上方)剛好把「獨立 vs 共用」這個二選一問題
> 變得不再互斥。**
>
> `_finalize_enemy_phase()` 有兩個呼叫者,不是一個:
> ```
> $ grep -n "_finalize_enemy_phase()" src/gameplay/battle/battle_controller.gd
> 673:	_finalize_enemy_phase()
> 799:		_finalize_enemy_phase()
> ```
> 673 是 `run_enemy_phase()`(路徑③,整批同步迴圈)結尾的收尾呼叫;799 是
> `step_enemy_phase()`(逐步呼叫,其文件註解逐字「Production code only ever calls this
> method」——**生產環境實際只走這一條**)在本階段已無單位可動時的收尾呼叫。
> `step_enemy_phase()` 不在任何外層迴圈裡,`_finalize_enemy_phase()` 是它唯一的收尾動作,
> **沒有外層提交可以依附**——這意味著「獨立成第二次提交」在 `step_enemy_phase()` 這條
> (生產環境的實際路徑)上**不是選項之一,是唯一可行的做法**。
>
> **建議裁決**:`_finalize_enemy_phase()` 本身包一層自己的 `commit_authoritative_change()`。
> 依本節上方已裁決的巢狀深度計數器機制(深度 +1 → mutator → 深度 −1 → 僅深度歸零時版本
> +1):經 `run_enemy_phase()` 呼叫到時,此內層提交會巢狀在外層已開啟的提交窗口內,
> 深度計數器自然收斂為外層的那一次 +1,不會額外多算;經 `step_enemy_phase()` 獨立呼叫到時
> (生產環境實際情形),沒有外層窗口,它自己的提交會獨立產生 +1。**兩種呼叫者都正確,
> 不需要為兩者分別寫不同的包裝邏輯**——這正是巢狀深度計數器設計要解決的情境,
> 比「獨立 vs 共用」二選一的原始提問更適合用這個新機制回答。
> ⚠️ **未查證範圍**:`step_enemy_phase()` 的其餘寫入面(例如它經由 `_process_enemy_unit()`
> 觸發的 move/attack 是否已被路徑①②③的既有覆蓋涵蓋)本次未逐行覆核,
> 本補充只處理 `begin_player_turn()`/`tick_all_modifiers()` 這一條,不代表
> `step_enemy_phase()` 全函式的原子性已被本 story 窮盡覆核。
> 📌 **2026-10-05 拆 story 後的分工**:上面這個判定(`_finalize_enemy_phase()` 包一層
> 自己的提交,AC11)留在本 story,**由本 story 的實作者包住整個函式本體(703+704 兩行)**。
> 但「704 行(`begin_player_turn()`)的寫入確實被這個提交窗口涵蓋」這條斷言的測試,
> 已搬至 `story-003c-player-turn-start-commit-wrapping.md`——本 story 的測試只需驗證
> 703 行(`advance_faction()`,路徑⑤本身)與整體的巢狀收斂行為,不必驗 704 行的語意。

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

🔴 **以下為 2026-10-05 新增(路徑⑥/⑦,對應 AC10/AC11/AC12)**:

- **回合轉換的 `begin_player_turn()` 使版本恰好 +1(`BattleController` 路徑,對應 AC10)**
  - Given: 一個含至少一個有倒數中 `CardModifier` 的單位、敵方回合即將結束的情境
  - When: 經 `run_enemy_phase()` 觸發 `_finalize_enemy_phase()`(`advance_faction()` +
    `begin_player_turn()` 依序發生)
  - Then: `combat_state_version` 相對呼叫前**恰好 +1**(不是 +2——即使兩行各自理論上
    是一次寫入,也必須收斂成同一次提交,見 AC10)
- **回合轉換的 `begin_player_turn()` 使版本恰好 +1(`BattleLoop` 路徑,對應 AC10)**
  - Given: 同上情境,但透過 `BattleLoop.run()` 驅動
  - Then: `combat_state_version` 恰好 +1(`battle_loop.gd` 119/152 兩行同一次提交)
- **`step_enemy_phase()` 獨立觸發 `_finalize_enemy_phase()` 時版本恰好 +1(對應 AC11,
  生產環境實際路徑,敏感度證明——需要間諜/突變子類別,比照
  `.claude/rules/test-standards.md` 2026-09-16 條目的要求)**
  - Given: 一個敵方階段只剩最後一步的情境(`_next_enemy_step_id()` 即將回傳 `-1`)
  - When: 呼叫 `step_enemy_phase()`(**不經過** `run_enemy_phase()`,模擬生產環境
    `battle_screen.gd` 的實際呼叫方式)
  - Then: `combat_state_version` 恰好 +1;另寫一條 `test_sensitivity_proof_*` 測試,
    證明若 `_finalize_enemy_phase()` 的 `commit_authoritative_change()` 包裝被移除,
    此測試會偵測到版本號**沒有**遞增而轉紅(不是一條恆綠的裝飾測試)
- **經 `run_enemy_phase()` 整批呼叫到 `_finalize_enemy_phase()` 時,巢狀提交正確收斂
  (對應 AC11,複驗巢狀深度計數器機制)**
  - Given: 至少兩個敵方單位皆有可執行動作、且敵方回合結束後會觸發
    `_finalize_enemy_phase()` 的情境
  - When: 呼叫 `run_enemy_phase()`(整個迴圈,含收尾的 `_finalize_enemy_phase()` 呼叫)
  - Then: `combat_state_version` 相對呼叫前**恰好 +1**(涵蓋整批動作 + 收尾轉換,
    不是 +2 或更多——`_finalize_enemy_phase()` 自己的內層提交必須巢狀收斂進外層,
    不得額外多算)
- **建構期一次性 `tick_all_modifiers()` 呼叫是否遞增版本(對應 AC12,若該項未被
  descope)**
  - Given: 一個剛建構完成、尚未呼叫 `run()`/`run_enemy_phase()` 的 `BattleController`
    或 `BattleLoop`
  - When: 讀取建構後立即的 `combat_state_version`
  - Then: 依路徑⑦是否被採納而定——若採納,版本為 `1`(建構子的一次性提交,即使
    no-op 仍計入一次);若 AC12 被 descope,版本維持 `0`(與既有行為一致)。
    **本測試向量的期望值必須與實作者最終對 AC12 的取捨一致**,不得兩者不同步

> 🔴 **2026-10-05 拆 story 後,上方 5 條「2026-10-05 新增」向量的歸屬(原文保留不動,
> 僅在此註記去向)**:
> - 第 1、2 條(`BattleController`/`BattleLoop` 的「回合轉換使版本恰好 +1」,對應 AC10)
>   ——**已搬至 `story-003c`**。
> - 第 5 條(建構期一次性呼叫,對應 AC12)——**已搬至 `story-003c`**。
> - 第 3、4 條(`step_enemy_phase()` 獨立觸發時版本恰好 +1 的敏感度證明、`run_enemy_phase()`
>   整批呼叫時巢狀收斂,對應 AC11)——**留在本 story**,理由見 Acceptance Criteria 節的
>   AC11 歸屬說明。

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

🔴 **2026-10-05 新增(路徑⑥/⑦,對應 AC10/AC11/AC12/Validation Criteria 4l/4m)**:
- 新增測試檔同時涵蓋 AC10(回合轉換雙行同一次提交)、AC11(`_finalize_enemy_phase()`
  自身巢狀提交,`run_enemy_phase()` 與 `step_enemy_phase()` 兩個呼叫者各驗一次)、
  AC12(若未 descope)
- AC11 的 `step_enemy_phase()` 向量**必須**附 `test_sensitivity_proof_*`(依
  `.claude/rules/test-standards.md` 2026-09-16 條目,敏感度證明用間諜/突變子類別,
  不得只做一次性手動改壞)
- 若實作者判定 AC12(路徑⑦)應 descope,請在本節與 Scope 節同步註記裁決結果與理由,
  不要只改測試、不留文字紀錄——理由見本 story 其餘各處反覆出現的「手抄複本會脫節」教訓

> 🔴 **2026-10-05 拆 story 後**:上方這段「2026-10-05 新增」要求裡,**AC10/AC12 相關部分
> 已搬至 `story-003c`**;**AC11 相關部分(`_finalize_enemy_phase()` 自身巢狀提交,
> 兩個呼叫者各驗一次)留在本 story**。歸屬理由同 Acceptance Criteria 節。

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
  > ✅ **2026-10-05 更新:已另切為 `story-017-unit-combat-field-setters.md`**
  > (管理者裁決,紀錄於第七十五批交接節)。建議此處不再視為開放項,改讀該檔。
- **卡牌打出第 4 步確認(路徑⑥)接入 `commit_authoritative_change()`**——不在本 story
  範圍,由 `skill-card-system` 既有程式碼另行接線(是否需要新工作單,由該系統擁有者判斷)。
- **`_finalize_enemy_phase()` 的提交粒度歸屬**(路徑③ 還是路徑⑤ 的一部分)——留給實作者
  讀該函式全文後確認,見上方「未決的實作細節」第 3 項。
- **`class_name Board` 命名衝突**——本 story 完成後三個零件的所有權已落地,但是否處置
  該衝突由下一次裁決決定,不由本 story 代為處置。
- **後續 `/architecture-review`**(ADR Validation Criteria 第 6 項)——需獨立會話執行,
  不是本 story 的產出範圍。

## ⚠️ 2026-10-05 新增範圍的誠實揭露(路徑⑥/⑦)

> 🔴 **本節連同下方三個項目,整段已搬至 `story-003c-player-turn-start-commit-wrapping.md`
> 的對應揭露節,原文保留於此處僅供決策紀錄。** 路徑⑥⑦的實作與驗收現在以 `story-003c`
> 為準;本 story(`story-003b`)自此之後只保留 AC11(`_finalize_enemy_phase()` 自身的
> 巢狀提交,見 Acceptance Criteria 節的歸屬說明)屬於實際範圍。

- **`step_enemy_phase()` 的其餘寫入面未被本次新增內容逐行覆核**——本次只處理
  `begin_player_turn()`/`tick_all_modifiers()` 這一條(路徑⑥),`step_enemy_phase()`
  經 `_process_enemy_unit()` 觸發的 move/attack 是否已被路徑①②③既有覆蓋完整涵蓋,
  本次未重新驗證,留給實作者或下一輪 `/architecture-review` 確認。
- **路徑⑦(建構期一次性 `tick_all_modifiers()` 呼叫)是 `lead-programmer` 本次主動擴大
  的發現,不是今日管理者裁決或 `technical-director` 報告的原始範圍**——已在 Scope 節
  與 AC12 逐一標註,建議納入但可單獨 descope,不影響路徑⑥與本 story 其餘範圍。
  若 descope,`traceability-index.md`/ADR-0001 的對應揭露由誰補記未定,本 story 不代為
  裁決。
- **本次新增內容未重新執行全套測試基線**——理由同本 story 既有的「排在
  story-004~007 之前」施工序安排,基線應由實際動工者在動工前當場重跑,不沿用
  2026-09-30 的舊快照作為本次新增範圍的對照基準。
