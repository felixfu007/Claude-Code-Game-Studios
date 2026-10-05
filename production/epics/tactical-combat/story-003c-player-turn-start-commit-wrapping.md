# Story 003c: 玩家回合開始鉤子的提交覆蓋 —— `begin_player_turn()`/`tick_all_modifiers()`(路徑⑥⑦)

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(依賴 `story-003b` 完成,見下方 Dependencies——未完成前無法開工)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S(純追加包裝與測試,不建立任何新機制,不動守衛本身或 15 個驅動層呼叫點改道)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)
> **派工來源**: 2026-10-05 管理者裁決(**唯一書面紀錄是本派工單**,協調者將在第七十五批
> 交接節補登,引用時請寫「2026-10-05 管理者裁決,紀錄於第七十五批交接節」,不要寫成某個
> 既有檔案的某一行)。本 story 從 `story-003b` 拆分而來——該檔 2026-10-05 當天曾短暫
> 包含路徑⑥⑦,管理者看到的選項描述逐字:「這是唯一真的切得開的地方 —— 核心半(計數器 +
> 守衛 + 15 個呼叫點改道)必須同一次落地,否則守衛一掛上去沒改道的呼叫點全部被擋;而⑥⑦
> 是純追加的包裝、不動守衛。拆後第一張回到今早的規模,第二張小。」已知代價(管理者知情
> 接受):「多一張工作單要管;而且⑥(回合轉換)今天就會真的改到攻防值,拆出去就是多一段
> 『機制做好了但這條路徑還漏著』的時間窗。」本 story 由 `lead-programmer` 切出,**不實作**。

## Context

**GDD**: `design/gdd/tactical-combat-system.md` Core Rules #10a/#10b/#10c/#11、AC-9/AC-22/AC-24
——同 `story-003b`,本 story 不新增或改變任何玩家可觀測義務,只把 ADR-0001 定案的機制套用到
一組先前未登記的寫入路徑上。

**Governing ADR**: `docs/architecture/adr-0001-tactical-query-atomicity-contract.md`
(**Accepted**)——本 story 補齊機制一寫入路徑表的第⑥⑦兩條(2026-10-05 新發現,ADR 原文
與 `story-003b` 原始範圍皆未涵蓋;ADR 第 179 行明文把 `ATK_eff`/`DEF_eff` 列入版本號背書
範圍,而這兩條正是改動它們卻漏遞增版本號的路徑)。

**Engine**: Godot 4.7.1 | **Risk**: LOW(純 GDScript,無 post-cutoff API)

**Control Manifest Rules(Core 層)**:同 `story-003b`——**絕不用 `assert()` 保護「不可達」
分支**;**絕不用 `call_deferred()`/`CONNECT_DEFERRED` 介入結算路徑**。

🔴 **硬性依賴,不是建議順序**:本 story 不建立任何新機制,完全依賴 `story-003b` 已建好的
`commit_authoritative_change()` 與巢狀深度計數器。`story-003b` 的 Scope/AC 未完成前,
本 story 連第一行程式碼都無法動——見下方 Dependencies。

---

## 現況(承接自 `story-003b` 2026-10-05 寫入的「事實三」,原文照搬為本 story 的現況依據,
不是摘要)

`technical-director` 裁決 ADR-0001 巢狀語意時發現 `_finalize_enemy_phase()` 呼叫
`begin_player_turn()`,而 `begin_player_turn()` 改 `ATK_eff`/`DEF_eff`(ADR-0001 第 179 行
明文列入版本號背書範圍)卻不遞增版本號。協調者獨立複驗鏈路成立,並額外發現
`battle_loop.gd` 有兩處命中(第 88 行、第 152 行)而非 `technical-director` 報告提到的一處。
`lead-programmer` 讀過以下上下文後給出兩項判定:`battle_loop.gd:79-90` 的建構子註解、
`battle_controller.gd:200-212` 的對應建構子註解、`battle_controller.gd:792-799` 的
`step_enemy_phase()`。

```
$ grep -n "begin_player_turn\|tick_all_modifiers" src/gameplay/battle/battle_loop.gd
88:	_state.tick_all_modifiers()
152:				_state.begin_player_turn()
$ grep -n "begin_player_turn\|tick_all_modifiers" src/gameplay/battle/battle_controller.gd
212:	_state.tick_all_modifiers()
704:	_state.begin_player_turn()
```

**判定一:`battle_loop.gd` 第 88 行與第 152 行(以及 `battle_controller.gd` 對應的第 212 行
與 704 行)是兩條獨立路徑,不是同一條路徑的兩個入口。**

- 第 88/212 行(各自在 `_init()` 建構子內)是**一次性、建構期**的 `tick_all_modifiers()`
  直接呼叫。兩處文件註解逐字說明同一個理由:**回合一的玩家階段永遠不會經過
  `advance_faction()` 那個分支**,所以**若沒有這個建構期呼叫,回合一會是全場唯一一次
  「玩家回合開始」卻沒有被 tick 到的事件**。兩處註解都明寫「目前沒有任何修正值能在
  建構當下就存在,所以今天是 no-op」——**但這是現況事實,不是結構保證**:一旦有任何
  未來 story 讓戰鬥開始前就能套用修正值(例如賽前增益、開場被動效果),這個呼叫會從
  no-op 變成真正的靜默寫入。
- 第 152/704 行是**每次 ENEMY→PLAYER 轉換**都會執行的 `begin_player_turn()` 呼叫,
  涵蓋的是**遊戲進行中**真正會修改修正值的情境(`CardModifier` 倒數到期)。這是今天
  **已經可觸發、非 no-op**的寫入路徑。
- 兩者呼叫的時機互斥,涵蓋的是 GDD Formula 二「每次玩家回合開始都要 tick」這個單一語意下
  的**兩個不重疊時間窗**。**因此判定為兩條獨立路徑,各自需要納入
  `commit_authoritative_change()` 的覆蓋範圍,不能只處理其中一個就視為兩者皆已覆蓋。**

**判定二(`_finalize_enemy_phase()` 的兩個呼叫者,屬 `story-003b` AC11 範圍,本處僅作為
背景——詳見下方「與 story-003b 的分工」)**:

```
$ grep -n "_finalize_enemy_phase()" src/gameplay/battle/battle_controller.gd
673:	_finalize_enemy_phase()
799:		_finalize_enemy_phase()
```

673 是 `run_enemy_phase()`(整批同步迴圈)結尾的收尾呼叫;799 是 `step_enemy_phase()`
(逐步、呈現層驅動,`battle_screen.gd` 唯一在用的生產路徑——其文件註解逐字「Production
code only ever calls this method」)在本階段已無單位可動時的收尾呼叫。`story-003b` 的
AC11 已要求把 `_finalize_enemy_phase()` 整個函式本體(703+704 兩行)包在同一層
`commit_authoritative_change()` 內——**本 story 承接這個既成事實,不重新設計它**。

`battle_loop.gd` 沒有對應的「兩個呼叫者」問題,也沒有拆出等價的輔助方法——第 119 行
(`advance_faction()`,屬 `story-003b` 路徑⑤)與第 152 行(`begin_player_turn()`,本 story
的路徑⑥)是同一次 `run()` 迴圈疊代、同一個程式碼區塊內的兩行先後敘述,只有一種呼叫脈絡。
但**兩行分屬兩張不同的 story**,這正是下方「與 story-003b 的分工」要處理的協調問題。

---

## 與 `story-003b` 的分工(本 story 最重要的一節,兩個驅動層的處理方式不對稱,務必先讀)

### `battle_controller.gd`:預期**不需要改動程式碼**,只需要新增測試

`story-003b` 的 AC11 要求實作者把 `_finalize_enemy_phase()` **整個函式本體**(703 行
`advance_faction()` + 704 行 `begin_player_turn()`)包在**同一層** `commit_authoritative_change()`
內——這是因為把一個兩行的函式拆成兩次個別包裝,在實作上沒有任何好處,`story-003b` 的
歸屬說明已指出這一點。**亦即:只要 `story-003b` 依其 AC11 正確實作,704 行的寫入理論上
已經被涵蓋在同一個提交窗口內。**

**本 story 的工作是驗證這件事,不是重新實作它**:
- 新增測試證明 `step_enemy_phase()` 觸發的那次 `_finalize_enemy_phase()` 呼叫,
  其**版本遞增確實反映了 704 行 `begin_player_turn()` 造成的修正值變化**(例如:斷言
  一個原本存在倒數中 `CardModifier` 的單位,在這次呼叫後 `active_modifiers()` 反映
  修正值已到期,且 `combat_state_version` 的遞增與修正值變化發生在同一次提交內,而非
  修正值變了但版本沒跟著動的不一致狀態)。
- 若測試顯示 704 行的寫入**沒有**被涵蓋(例如 `story-003b` 的實作者出於某種理由把包裝
  範圍縮小成只含 703 行),**本 story 需要回頭擴大那個既有的 `commit_authoritative_change()`
  呼叫範圍,把 704 行納入同一個 Callable**——這是修正 `story-003b` 遺留的落差,不是
  重新設計。

### `battle_loop.gd`:**預期需要改動程式碼**,可能要擴充 `story-003b` 已寫好的包裝

`story-003b` 的路徑⑤只明確要求包裝第 119 行(`_order.advance_faction()`)。`battle_loop.gd`
**沒有** `_finalize_enemy_phase()` 那樣的輔助函式可以讓兩行自然共用一次包裝——119/152
是 `run()` 同一個 `if acting_ids.is_empty():` 分支裡先後兩行獨立敘述,`story-003b` 的
實作者完全可能只看著路徑⑤的要求、只包裝 119 行,而對 152 行(路徑⑥,不在 `story-003b`
範圍內)視而不見——這不是 `story-003b` 的錯,是兩張 story 刻意拆分後自然會出現的縫隙。

🔴 **本 story 的 AC 要求 119/152 兩行最終落在同一個 `commit_authoritative_change()`
Callable 內**(理由:若各自獨立提交,敵方回合轉換那一刻版本號會 +2 而非 +1,直接違反
`story-003b` 既有 AC-7「整批恰好 +1」的精神,也與 Validation Criteria 4f「玩家結束陣營
回合 → 恰好 +1」的既有向量衝突)。這代表:

- **若 `story-003b` 完工時,119/152 兩行已經被包在同一個 Callable 內**(實作者自行判斷
  兩行屬同一次轉換、一起包了)——本 story 同 `battle_controller.gd` 側,只需新增測試
  驗證。
- **若 `story-003b` 完工時,119 行已包裝、152 行未包裝**(更可能的情形,因為
  `story-003b` 的 AC 文字沒有要求 152 行)——本 story 的實作者**必須修改**
  `story-003b` 已經寫好的那個 `commit_authoritative_change()` 呼叫,把它的 Callable
  擴充為同時執行 119 行與 152 行的邏輯,而不是在旁邊另開一個新的、獨立的
  `commit_authoritative_change()` 呼叫(後者會違反「同一次提交」的要求)。

⚠️ **這是一個會動到 `story-003b` 程式碼的 story,不是純粹獨立的追加**——下一個接手
本 story 的人,動工前必須先讀 `story-003b` 完工時 `battle_loop.gd` 實際長什麼樣子,
不能只看本檔的描述就假設 119 行是獨立一個 Callable。

---

## Scope

### In Scope

1. **路徑⑥:回合轉換時的玩家回合開始鉤子**
   - `battle_controller.gd`:驗證(必要時擴充)`_finalize_enemy_phase()` 的既有提交範圍
     涵蓋 704 行。
   - `battle_loop.gd`:確保 119/152 兩行落在同一個 `commit_authoritative_change()` 內
     (可能需要擴充 `story-003b` 已寫的包裝,見上方「分工」節)。
2. **路徑⑦:建構期一次性玩家回合開始鉤子(建議納入,可 descope——見下方說明)**
   - `battle_controller.gd:_init()`(212 行)、`battle_loop.gd:_init()`(88 行)的
     `tick_all_modifiers()` 呼叫各自包一層獨立的 `commit_authoritative_change()`。
   - 🔴 **本項是 `lead-programmer` 主動擴大的建議範圍,非 2026-10-05 管理者裁決或
     `technical-director` 報告的原始指認**——理由:①今天是 no-op(兩處文件註解皆明寫
     尚無修正值能在建構當下存在),但這是現況事實不是結構保證;②包裝成本極低;
     ③不會破壞任何既有測試(`story-003b` 已確認沒有測試斷言建構完成後版本號恰為 `0`)。
     **若管理者/`technical-director` 認為超出範圍,可單獨 descope,不影響路徑⑥。**
3. **對應的 Validation Criteria 斷言測試**(新增,見下方 QA Test Cases)。

### Out of Scope(附理由)

- **重新設計 `commit_authoritative_change()`/巢狀深度計數器本身**——那是 `story-003b`
  (實際上是 ADR-0001 第二次修訂)的產出,本 story 只使用它。
- **`_finalize_enemy_phase()` 的寫入守衛本體、15 處驅動層呼叫點改道**——`story-003b`
  範圍,本 story 不重做。
- **`step_enemy_phase()` 經 `_process_enemy_unit()` 觸發的 move/attack 是否已被路徑①②③
  完整涵蓋**——`story-003b` 已誠實標註此項未逐行覆核,本 story 同樣不覆核(不是本 story
  要新增的寫入路徑,不擴大範圍)。
- **卡牌打出第 4 步確認(路徑⑥原本在 `story-003b` 表格中的舊編號,與本 story 的路徑⑥
  不是同一件事——命名巧合)**——仍是 `story-003b` Out of Scope 的既有排除項,不受本 story
  影響。
- **`Unit` 裸公開欄位加 setter(ADR-0001 硬性義務第 2 條)**——另一張獨立 story,見
  `story-017-unit-combat-field-setters.md`,與本 story 無直接依賴(兩者皆依賴
  `story-003b`,彼此之間無先後要求)。

---

## Acceptance Criteria

| # | AC | 對應 |
|---|---|---|
| 1 | `battle_controller.gd`:`_finalize_enemy_phase()` 的既有提交包裝(`story-003b` AC11)
   確認(必要時擴充)涵蓋 704 行 `begin_player_turn()` 的寫入——同一個 Callable,不是
   在它之外另開一次提交 | 路徑⑥ |
| 2 | `battle_loop.gd`:119 行(`advance_faction()`)與 152 行(`begin_player_turn()`,
   條件式執行於 `current_faction()==PLAYER`)最終落在同一個 `commit_authoritative_change()`
   Callable 內——若 `story-003b` 完工時兩者分屬不同包裝,本 AC 要求合併,不得並存兩次獨立提交 | 路徑⑥ |
| 3 | 透過 `BattleController`(`step_enemy_phase()`,生產環境實際路徑)與 `BattleLoop`
   (`run()`)兩個驅動層,各自驗證一次「回合轉換使版本恰好 +1,且修正值的實際變化與
   這次版本遞增同步發生」 | 路徑⑥ |
| 4(建議,可 descope) | `battle_controller.gd:_init()`(212)、`battle_loop.gd:_init()`(88)
   各自包一層獨立的 `commit_authoritative_change()` | 路徑⑦ |
| 5 | 新增 Validation Criteria 向量 4m(緊接 `story-003b` 已新增的 4l):「玩家回合開始的
   屬性修正遞減(`tick_all_modifiers()`)→ 恰好 +1,不論經由 ENEMY→PLAYER 轉換或建構期
   一次性呼叫觸發」 | 機制一硬性義務第 5 條 |
| 6 | 全部新測試遵守 `coding-standards.md` 對 GdUnit4 的三項紀律(直接呼叫 `RefCounted`
   方法、分散測試檔、敏感度證明) | 同 `story-003b` AC9 |

---

## Affected Files

| 檔案 | 改動性質 |
|---|---|
| `src/gameplay/battle/battle_controller.gd` | **預期不需要改動**(見上方「分工」節),僅在測試揭露落差時才需要擴充既有包裝範圍 |
| `src/gameplay/battle/battle_loop.gd` | **預期需要改動**——擴充或新建涵蓋 119/152 兩行的提交包裝,視 `story-003b` 完工時的既有狀態而定 |
| 新增測試檔(建議與 `story-003b` 的新增測試檔分開,或視命名空間合併,由實作者判斷——兩者不共用同一條 Validation Criteria 向量故不強制合併) | AC1-6 的斷言 |

---

## 未決的實作細節(動工時必須先確認)

1. **動工前第一步,不是寫程式碼**:讀 `story-003b` 完工時 `battle_loop.gd` 119 行附近的
   實際實作,確認它是否已經把 152 行一併包了進去。這決定本 story 在 `battle_loop.gd`
   上要做的是「新增測試」還是「擴充既有包裝 + 新增測試」。
2. **路徑⑦是否納入**:見 Scope 第 2 項,建議納入但可 descope,descope 需同步在本節與
   Acceptance Criteria 節註記理由,不要只改程式碼不留文字紀錄。

---

## QA Test Cases

⚠️ 本節由 `lead-programmer` 直接撰寫,非 `qa-lead` 產出(本次派工環境無 `Task` 工具)。
建議下一次有 `Task` 工具可用時補跑一次 QL-STORY-READY 覆核。

- **回合轉換的 `begin_player_turn()` 使版本恰好 +1(`BattleController` 路徑,對應 AC1/AC3)**
  - Given: 一個含至少一個有倒數中 `CardModifier` 的單位、敵方回合即將結束的情境
  - When: 經 `step_enemy_phase()`(生產環境實際路徑,**不經過** `run_enemy_phase()`)
    觸發 `_finalize_enemy_phase()`
  - Then: `combat_state_version` 相對呼叫前**恰好 +1**;且該次呼叫後,過期的
    `CardModifier` 已從 `active_modifiers()` 消失(證明 704 行的效果與版本遞增發生在
    同一次提交)
- **回合轉換的 `begin_player_turn()` 使版本恰好 +1(`BattleLoop` 路徑,對應 AC2/AC3)**
  - Given: 同上情境,但透過 `BattleLoop.run()` 驅動
  - Then: `combat_state_version` 恰好 +1(119/152 兩行同一次提交)
- **敏感度證明:若把 704 行(或 152 行)排除在提交窗口之外,測試必須轉紅**
  - 依 `.claude/rules/test-standards.md` 2026-09-16 條目,間諜/突變子類別手法,不得只做
    一次性手動改壞
- **建構期一次性 `tick_all_modifiers()` 呼叫是否遞增版本(對應 AC4,若未 descope)**
  - Given: 一個剛建構完成、尚未呼叫 `run()`/`run_enemy_phase()` 的 `BattleController`
    或 `BattleLoop`
  - When: 讀取建構後立即的 `combat_state_version`
  - Then: 依 AC4 是否被採納而定(版本為 `1` 或維持 `0`,期望值須與實作者最終取捨一致)

---

## Test Evidence

**Story Type**: Logic

**現行測試基線**:需於動工前由實作者重新執行並記錄——`story-003b` 完工後的基線,
不是 2026-09-30 的舊快照(本 story 依賴 `story-003b` 已落地的程式碼)。

**Required evidence**:
- 新增測試檔通過 QA Test Cases 全部向量 + Validation Criteria 4m
- 至少一條敏感度證明(間諜/突變子類別),證明移除路徑⑥的提交覆蓋會讓測試轉紅
- 重跑全套測試,失敗數不高於 `story-003b` 完工時的基線(同一條既有核准失敗,非新增失敗)

---

## Dependencies

- **Depends on: `story-003b`(必須先 Done)**——本 story 使用 `story-003b` 建立的
  `commit_authoritative_change()`、巢狀深度計數器、以及 `_finalize_enemy_phase()`/
  `battle_loop.gd` 路徑⑤的既有包裝。未完成前無法開工,見上方「與 story-003b 的分工」節。
- 📌 **2026-10-05 管理者另一項裁決(與本 story 間接有關,紀錄於第七十五批交接節)**:
  `story-016`(地形載入時驗證)排在 `story-003b` 之前,兩者皆改 `board.gd`、不得並行。
  本 story 不改 `board.gd`,不受此檔案衝突影響,但完整施工序因此是
  **`story-016` → `story-003b` → `story-003c`(本檔)**。
- Unlocks: 無——本 story 關閉的是 ADR-0001 路徑⑥⑦的覆蓋缺口,不阻擋 story-004~007
  (那四張已經依賴 `story-003b`,不需要額外依賴本 story)。

## ⚠️ 誠實揭露(未涵蓋範圍)

- **`battle_loop.gd` 側的實際改動形狀未知**——取決於 `story-003b` 完工時的實作細節,
  本 story 只能預先描述兩種可能情形(已包/未包 152 行),無法在 `story-003b` 完工前
  確定實際要做哪一種。
- **`step_enemy_phase()` 的其餘寫入面**(`_process_enemy_unit()` 觸發的 move/attack)
  未被本 story 覆核,沿用 `story-003b` 既有的誠實揭露。
- **路徑⑦是否納入**由實作者/下一次裁決決定,見 Scope 節。
