# Story 011: 輸入缺口補強(敵方回合拒絕逐幀生效、拒絕回饋、結束單位行動路徑)

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M6(範圍②)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-09-09

## Context

**GDD**: UI Requirements §6(輸入、合法性閘與取消——確認鍵須先查詢有效性旗標,無效時必須被
丟棄並觸發拒絕回饋)、Visual/Audio §5(拒絕音須與靜默明確不同)、Core Rules #9(主動結束行動
須有明確輸入路徑)、`P-I2`(全手把對等,無滑鼠專屬功能)、`P-F2`(可辨識拒絕回饋)。

**M1 查證依據**(`docs/reviews/tactical-combat-m1-current-state-audit-2026-09-29.md`):

本 story 對應三項 M1 查證結論,**逐項摘錄「對 story 的影響」**:

### U-T6(敵方回合拒絕是否逐幀生效)—— ⚠️ 有缺口
> `_input(event)` 頂部只擋 `_load_failed` 與 `phase()==FINISHED`,**沒有對 `ENEMY_ACTING` 的
> 頂層檢查**。`_handle_mouse_button()`/`_handle_directional()` 都沒有自己的 phase 檢查。
> 真正擋下遊戲狀態變更的是更深一層 `BattleController.click_tile()` 的
> `if _phase != Phase.PLAYER_INPUT: return {"action": &"none"}`——**BattleState 本身不會被
> 敵方回合中的輸入改動,但游標仍會照常隨滑鼠/方向鍵移動**,這是一個可觀測的副作用未被擋下。
> **對 story 的影響**:建議 story 描述精確化為「頂層輸入分派需在 `ENEMY_ACTING` 時擋下游標
> 移動等視覺副作用,不只是靠深層 `click_tile()` 擋狀態變更」。

### U-T7(`{"action":"none"}` 是否觸發可辨識拒絕回饋)—— ❌ 不存在
> `src/ui/` 底下呼叫 `click_tile()` 的兩處都是裸呼叫,回傳值完全未被接收。`&"none"` 這個 action
> 值**沒有任何一處消費它**——不論是分支判斷、音效觸發、閃爍動畫還是 `push_error`。
> **對 story 的影響**:目前是徹底的 0 分,不是部分實作,規模估計上不應被低估為「補個小分支」;
> 至少需要在 `battle_screen.gd` 兩個呼叫點接住回傳值並依 action 值分派(至少要能區分
> `&"none"`/`&"blocked_pending_discard"`/其餘合法 action)。

### U-T8(結束該單位行動的輸入路徑)—— ❌ 不存在
> `end_unit_turn(id)` 全專案只有兩個呼叫端——`battle_loop.gd`(自動化模擬)與測試——**`src/ui/`
> 底下零命中**。`src/ui/` 只有 `end_faction_phase()`(結束整個陣營回合)的完整介面路徑,
> **沒有任何一處是 `end_unit_turn()`**。這是兩件不同的事:「結束整個陣營回合」有完整介面路徑
> (`battle_menu.gd` 選單列 → `end_faction_phase_confirmed` 訊號),「主動結束單一單位」完全
> 沒有玩家可觸發的路徑。
> **對 story 的影響**:若 P-I2 或 GDD 要求玩家能主動結束單一單位行動,需要新增一條輸入路徑
> (選單列新增一行,或現有輸入分支新增一個 action)呼叫 `end_unit_turn(_selected_unit_id)`——
> 這是目前完全不存在的功能,不是「補強現有路徑」規模。

**ADR Governing Implementation**: `ADR-0001`(結算不可重入邊界,AC-24)+ `ADR-0005`
(拒絕回饋須為明確結果碼,不得靜默忽略——控制清單:「拒絕一律回傳明確結果碼……絕不靜默忽略、
絕不回傳 `void`」)。

**Engine**: Godot 4.7.1 | **Risk**: MEDIUM

## Acceptance Criteria

**U-T6 子項**:
- [ ] 頂層輸入分派(`_input()` 或其直接分派的函式)須在 `ENEMY_ACTING` 期間擋下**視覺副作用**
      (游標移動、`_board_view.set_cursor()`),不只依賴 `click_tile()` 的深層拒絕
- [ ] 敵方回合逐步演出的**每一幀**皆須生效(不得只在演出開始時擋一次)

**U-T7 子項**:
- [ ] `battle_screen.gd` 兩個 `click_tile()` 呼叫點(`_handle_mouse_button()` 內、
      `_confirm_at_cursor()` 內)須接住回傳值,依 `action` 欄位分派
- [ ] 至少區分 `&"none"`(拒絕)/`&"blocked_pending_discard"`(既有靜默,不得與 `&"none"`
      混淆)/其餘合法 action 三類
- [ ] `&"none"` 須觸發可辨識的拒絕回饋(視覺與/或音效,依 Visual/Audio §5——**具體音效資產
      本身不在本 story 範圍**,見 Out of Scope,但拒絕**事件**本身須被觸發,不得繼續靜默丟棄)

**U-T8 子項**:
- [ ] 新增一條輸入路徑呼叫 `end_unit_turn(_selected_unit_id)`(具體形狀:選單新增一行,或
      既有輸入分支新增一個 action——**由本 story 決定**)
- [ ] 依 `P-I2`(全手把對等),此路徑須同時有鍵盤/手把可達的方式,**不得**是滑鼠專屬功能
- [ ] `TEXT_CONTROLS_HINT` 提示文字須同步更新以反映新路徑(⚠️ 若走本地化管線已在此時可用,
      比照 `localization-infrastructure` Story 001 的 key 查找慣例,不新增裸字串)

## Implementation Notes

1. **三個子項可視為同一 story 內三個獨立可測試單元**,不強制互相依賴,可分別開發/驗收,
   但因三者皆改動 `battle_screen.gd` 的輸入分派區塊,建議同一 story 一次做完以避免重複改動
   同一段程式碼。
2. ⚠️ **未查證**:U-T7 的拒絕回饋觸發後,實際的視覺/音效呈現由誰負責——GDD Visual/Audio §5
   的具體音效資產屬「明確不寫的項目」表歸屬 `/ux-design` + 未來音訊方向文件,本 story 只需要
   讓拒絕**事件**可被觸發(例如發送一個 signal,或呼叫一個目前可能是 no-op 的拒絕回饋 hook),
   不需要等音效資產就緒才能完成。
3. **U-T6 的修復方式建議**:在 `_input()` 頂層新增一個 `phase() == Phase.ENEMY_ACTING` 的
   守衛,直接 `return` 而非往下分派——這比在 `_handle_mouse_button()`/`_handle_directional()`
   內各自加守衛更集中,但兩種寫法皆滿足驗收條件,取捨屬實作者判斷。

## Out of Scope

- **拒絕音效資產本身**——GDD 明文歸屬 `/ux-design` + 音訊方向文件,本 story 只需觸發拒絕事件。
- **U-T10(Tab/RB 跳轉排序是否決定性)**——M1 查證已回答「機制與測試皆存在,但未查證戰棋單位
  跳轉與卡牌選標跳轉是否共用同一實作」,此為另一項獨立查證(EPIC.md 未明確指派模組,若需要
  補測試屬另一張獨立 story,不在本 story 範圍)。
- **U-T11(本地化)**、**U-T12(結算是否單幀同步)**——已由 M1 分別回答為「需管理者裁決」與
  「✅ 已滿足」,不在本 story 範圍。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 Task 工具不可用而跳過。

- **敵方回合游標移動被擋(U-T6)**
  - Given: `phase() == ENEMY_ACTING`,敵方演出逐步進行中
  - When: 玩家按方向鍵/移動滑鼠
  - Then: 游標位置不變,每一幀皆生效(非只在演出開始瞬間生效)
- **拒絕回饋觸發(U-T7)**
  - Given: 玩家點擊一個不合法的目標(`click_tile()` 回傳 `&"none"`)
  - When: 檢查是否有可觀測的拒絕回饋
  - Then: 拒絕回饋事件被觸發,且與 `&"blocked_pending_discard"` 情境的回饋可區分
- **合法 action 不誤觸發拒絕回饋**
  - Given: 玩家點擊一個合法目標
  - When: 檢查回饋
  - Then: 不觸發拒絕回饋
- **結束單位行動路徑存在且鍵盤/手把皆可達(U-T8)**
  - Given: 一個選取中的可行動單位
  - When: 觸發新增的「結束行動」路徑(鍵盤與手把分別測試)
  - Then: 呼叫 `end_unit_turn(id)` 成功,單位轉為「已行動」

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ui/battle_input_gaps_test.gd` —— BLOCKING

**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-008(建議游標導航收斂先完成,U-T6 的游標副作用擋下邏輯與收斂後的游標讀寫
  路徑相關;非嚴格結構性依賴)
- Unlocks: None

## 執行層序列化(M6 → M5 → M4)

本 story 屬 M6,M6 全部(008-011)須先於 M5、M4 執行完成。
