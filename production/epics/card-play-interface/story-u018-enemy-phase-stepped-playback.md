# Story U-018:敵方階段逐步演出 —— 新增「走一步」入口,原有「一次跑完」入口零改動

> **Epic**:卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **型別**:Integration
> **狀態**:📋 Ready
> **估時**:M
> **依賴**:無(`battle_controller.gd` / `battle_screen.gd` 均已存在)
> **波次**:波 3(與 U-008 ∥ U-012 真平行 —— 三張各自動不同檔案,零交集)
> **來源**:2026-09-17 管理者裁決(第五十四批開場)

## Context

**問題**:`battle_screen.gd` 的 `_end_faction_phase_pressed()` 同步依序呼叫
`end_faction_phase()` → `run_enemy_phase()` → `_refresh_view()`,中間無任何跨幀點。
敵方整個階段在**同一格畫面內**跑完,玩家看到的是棋子瞬間跳位,不是敵人在行動。

**連帶後果**:`design/ux/skill-card-play.md:301` 的 **S5(敵方回合 Z1 標示為不可用)**
在現行遊戲中**永遠畫不出一格** —— U-011 已實作並以測試驗證該狀態正確,但玩家看不到。

## 🔴 禁令邊界 —— 這是本 story 最重要的一段,開工前必讀

`docs/registry/architecture.yaml` 的 `deferred_calls_in_settlement_path` 逐字為:

```
Within the settlement step, any call that mutates occupied, unit combat stats,
turn flags or combat_state_version must not go through call_deferred() or a
CONNECT_DEFERRED signal connection.
```

**它管的是「一個結算步驟的內部」,不是「兩個結算步驟之間」。**
`run_enemy_phase()` 的迴圈逐一呼叫 `_process_enemy_unit(id, log)`
(`battle_controller.gd:806`),**每一次呼叫是一個完整的結算步驟**。
在兩次呼叫「之間」跨幀,不落入本禁令。

🔴 **但 ADR-0001 有兩條對跨幀的既有約束,兩條都適用**:
1. **宿主生命週期**(`adr-0001...md:262`):持有協程的物件生命週期必須涵蓋整場戰鬥,
   不得掛在會被 `queue_free()` 的暫時性節點上;每次 `await` 恢復後須先
   `is_instance_valid()` 防衛,否則視為中止。
2. **卡死偵測**(`adr-0001...md:341`):`authoritative_write_in_progress`
   **不得跨越兩個連續 `_process` 幀仍為 `true`**。
   ⚠️ **這一條直接決定暫停點的位置** —— 暫停必須發生在該旗標為 `false` 的時刻,
   亦即嚴格在兩個結算步驟「之間」。若在旗標為 `true` 時跨幀,會觸發既有的卡死偵測。

## 目標

新增一個「一次只處理一個敵方單位」的入口給呈現層驅動,**`run_enemy_phase()` 本身
一個字都不改**,讓現有 35 處測試引用與唯一的 `src/` 呼叫點全部不受影響。

## 🔴 不動舊程式 —— 這是管理者裁決的具體內容,不是實作者的裁量

現況(實測原始輸出):

```
$ grep -rn "run_enemy_phase" src/
src/gameplay/battle/battle_controller.gd:586:func run_enemy_phase() -> Array[String]:
src/ui/battle/battle_screen.gd:1012:	_controller.run_enemy_phase()
(其餘 8 處為文件註解)

$ grep -rc "run_enemy_phase" tests/ | grep -v ":0"
tests/integration/gameplay/cards/card_battle_wiring_test.gd:7
tests/integration/gameplay/cards/card_forced_discard_gate_test.gd:3
tests/integration/gameplay/cards/card_play_wiring_test.gd:2
tests/unit/gameplay/battle/battle_controller_test.gd:15
tests/unit/gameplay/battle/battle_loop_test.gd:1
tests/unit/gameplay/cards/card_modifier_lifecycle_test.gd:7
```

**把 `run_enemy_phase()` 改成協程會讓上列 6 支測試檔全部要加 `await`。**
本 story 明文禁止那條路徑。

## 本 story 決定的原始碼目錄路徑

- **累加**:`src/gameplay/battle/battle_controller.gd`(新增逐步入口,不改既有函式)
- **累加**:`src/ui/battle/battle_screen.gd`(`_end_faction_phase_pressed()` 改走逐步入口)

⚠️ **本 story 不新建任何檔案。**

## Implementation Notes

1. **逐步入口的形狀由實作者決定,但必須滿足三件事**:
   ①呼叫一次只推進一個敵方單位;②能明確回報「還有沒有下一個」;
   ③`run_enemy_phase()` 可以改寫成「重複呼叫它直到沒有下一個」而行為逐位元組不變
   —— 亦即**兩條路徑共用同一份規則,不是兩份實作**。
   🔴 本專案已登記過「同一個公式兩份實作、只是今天答案一致」的案例,
   而黑箱比對輸出**永遠無法區分「共用同一份」與「兩份碰巧一致」**。

2. **暫停長度必須是可設定的常數,不得寫死在邏輯層。**
   預設值由實作者提議(建議 0.25~0.4 秒之間),寫成 `battle_screen.gd` 的常數。
   ⚠️ 這是**呈現層**的數值,不進 `battle_controller.gd`。

3. **暫停期間玩家輸入的處置必須明確決定並寫進註解。**
   最小要求:敵方階段期間 `_end_faction_phase_pressed()` 不得可重入
   (現行 `if _controller.phase() != BattleController.Phase.PLAYER_INPUT: return`
   在跨幀後是否仍足夠,必須實測而非推理)。

4. **`_refresh_view()` 的呼叫時機**:每推進一個單位後重畫一次,否則跨幀沒有意義。
   ⚠️ 該函式的註解自述會「free 並重建 ~50 個節點」,每格重建一次是刻意的代價,
   請在註解裡寫明這是知情選擇。

## Acceptance Criteria

| | 條件 | 型別 | 閘門 |
|---|---|---|---|
| **AC-E1** | 逐步入口單獨呼叫一次,恰好推進一個敵方單位;呼叫回傳時不存在「寫入進行中」的狀態(見下方 🔴 AC-E1 就地改寫) | Logic | BLOCKING |
| **AC-E2** | `run_enemy_phase()` 的簽章與可觀測行為,在改動前後保持不變 —— 以現有 6 支測試檔全綠為證(2026-09-17 管理者裁決:「一個字都不改」指簽章與行為零變動,不是原始碼位元組零變動;extract method 不改簽章、不改行為,AC-E2 本身就是這個宣稱的證明) | Logic | BLOCKING |
| **AC-E3** | 敵方階段跨越 **≥ 2 個 `_process` 幀**(敵方單位 ≥ 2 時);以測試或探針量測實際幀數 | Integration | BLOCKING |
| **AC-E4** | 敵方階段進行中重複按結束回合鍵不造成第二次階段推進(可重入防護) | Integration | BLOCKING |
| **AC-E5** | 真實遊戲畫面截圖:敵方階段進行中的一格,手牌帶呈現 S5「不可用」外觀 | UI | ADVISORY |

### 🔴 AC-E1 就地改寫(2026-09-17 實作期發現,協調者獨立複驗後裁決)

**原文引用了一個在 `src/` 裡零實作的機制。** 原始 AC-E1 的措辭直接借用了 ADR-0001 的
`authoritative_write_in_progress` 這個名詞,但實測(逐字):

```
$ grep -rn "authoritative_write_in_progress" src/
src/gameplay/battle/battle_controller.gd:695:## [code]authoritative_write_in_progress[/code] flag has NO field anywhere in
src/gameplay/cards/card_play_session.gd:109:var _authoritative_write_in_progress_check: Callable
src/gameplay/cards/card_play_session.gd:333:func _is_authoritative_write_in_progress() -> bool:
（其餘皆為文件註解或建構子參數,非實體欄位)
```

**沒有實體布林欄位** —— 只有一個可注入、預設未設定的 `Callable` 代打
(`CardPlaySession._authoritative_write_in_progress_check`)。這是 ADR-0001 機制二
「寫入守衛」尚未建成的已知缺口(`card_play_session.gd` 的文件註解 2026-09-10 已記載此發現),
不是本 story 的範圍要補的東西。

**替代證據**:`step_enemy_phase()` 呼叫鏈(`step_enemy_phase()` /
`_next_enemy_step_id()` / `_finalize_enemy_phase()`)全程同步 —— 不含
`await`、`call_deferred()`、`CONNECT_DEFERRED` 訊號連線。由
`tests/unit/gameplay/battle/battle_controller_step_enemy_phase_test.gd` 的
`test_step_enemy_phase_call_chain_has_no_yield_point()`(原始碼文字掃描)與其
`test_sensitivity_proof_yield_point_scan_catches_an_injected_await()`(敏感度證明)
兩條測試驗證。

🔴 **這是比原 AC 措辭弱的證據,不是等價證據**:結構性證明保證的是「今天這支呼叫鏈沒有
暫停點」,保證不了「日後有人加了暫停點會被抓到」——一支原始碼文字掃描沒有 ADR-0001
機制二「連續兩個 `_process` 幀仍為 `true` 即 `push_error()`」那種執行期卡死偵測的能力。

🔴 **給未來的義務**:日後實作 ADR-0001 寫入守衛(`authoritative_write_in_progress` 真正
落地為 `BattleState` 的欄位)的人,**必須回頭讓 `step_enemy_phase()` 的跨呼叫邊界納入
卡死偵測的涵蓋範圍** —— 不寫下這條,這個缺口會在守衛建好的那天安靜地留在外面(它今天
「合規」純粹是因為呼叫鏈裡沒有 await,不是因為有任何機制在把關這件事將來是否仍然成立)。

## Test Evidence

- 自動化測試落點:`tests/unit/gameplay/battle/`(AC-E1/E2)、
  `tests/integration/gameplay/battle/`(AC-E3/E4)
- 🔴 **新增 `tests/integration/gameplay/battle/` 這個目錄前,先確認
  `tests/gdunit4_runner.gd` 的 `FORCED_ARGS` 已含 `tests/integration`** ——
  本專案登記過「新增測試層級沒加進 runner,5 條測試一次都沒跑卻回報全綠」。
- AC-E5 截圖落點:`production/qa/evidence/`
