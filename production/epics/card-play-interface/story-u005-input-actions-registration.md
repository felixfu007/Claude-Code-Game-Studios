# Story U-005: `project.godot` 新增 5 個動作,刻意不動 `battle_end_phase`

> **Epic**: 卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **狀態**: 📋 Ready
> **層**: Presentation(輸入設定,B/C 段的共用前置)
> **型別**: Integration
> **估時**: S
> **依賴**: U-004
> **解鎖**: U-007、U-016(後者不在本次 8 個單元授權範圍內)
> **波次**: 波 1(與 U-003 ∥ 真平行 —— `project.godot` vs `battle_screen.gd`,兩個不同檔)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)

## Context

**權威來源**:`design/ux/skill-card-play.md`「按鍵配置」節、`design/ux/battle-menu.md`
「Interaction Map」節。

**Governing ADR**:ADR-0005(**Accepted**)—— 呈現層規則「載入期必須驗證 Input Map
約束…鍵不存在時回報 UNKNOWN,不得視為通過」。

## 目標

在 `project.godot` 的 `[input]` 節新增 5 個動作(取消 `battle_cancel`、開/收手牌、跳下一個
合法目標、跳上一個合法目標、開啟選單 `battle_menu`),鍵盤與手把綁定皆依 U-004 探針量測
結果確定。**刻意不動 `battle_end_phase` 現有的 `Esc`/手把 `B` 綁定**——這是本 story 與
U-016 分開的關鍵決定。

## Implementation Notes

1. 🔴 **U-005 與 U-016 是刻意拆開的,而這是 EPIC.md 作者的架構判斷,無人覆核(EPIC.md
   第二節,轉錄)**:

   > 把「新增動作」與「解綁 `battle_end_phase`」放進同一張工作單,會讓中途每一次提交都是
   > **一個玩家無法結束回合的建置**。拆開之後 `battle_end_phase` 一直活到 U-016 為止,
   > **期間任何一次提交出來的遊戲都是可玩的。**

   **本 story 只新增動作,絕對不修改或移除 `battle_end_phase` 現有的任何綁定。**

2. 🔴 **中間狀態的 `Esc` 會同時觸發兩個動作,已由管理者裁決接受(EPIC.md 第八節第 2 項,
   原文轉錄)**:

   > **裁決內容**:**接受過渡期 `Esc` 同時觸發 `battle_end_phase` 與 `battle_cancel`。**
   > U-005 與 U-016 維持分開,不合併。
   >
   > 🔴 **知情代價(裁決當下明示)**:U-005 到 U-016(不在本次授權範圍)期間,按 `Esc`
   > 取消卡牌會**一併結束回合**。**這是已知且被接受的,不是 bug,不要當成缺陷去修**——
   > 它由 U-016 一次解決。

   **對本 story 的實際後果**:`battle_cancel` 這個新動作,鍵盤綁 `Esc`、手把綁 `B`
   ——**與 `battle_end_phase` 現有綁定完全相同**,兩個動作因此會同時觸發。這是刻意的,
   本 story **不需要**、也**不應該**用任何手段避免這個雙重觸發(例如不應該給 `battle_cancel`
   臨時綁一個不同的鍵來規避)——管理者已明確否決「臨時鍵」這個替代方案(EPIC.md 第八節
   第 2 項記載協調者提過這個方案並被否決,理由是「代價是一條沒有自動檢查的紀律:臨時鍵
   被忘記而出貨」)。

3. **依 U-004 探針結果決定最終按鍵**——若探針發現任何候選鍵有衝突,以探針報告為準調整,
   不得直接套用 UX 規格裡「建議值」字樣的按鍵而不核對探針結果(兩份 UX 規格都明文標註
   這些是「建議值,非驗證值」)。

4. **新動作的名稱**——`skill-card-play.md`/`battle-menu.md` 裡提到的
   `battle_cancel`/`battle_menu` 已是明確命名(兩份規格都用這兩個具體名稱),其餘 3 個
   (開/收手牌、跳下一個/上一個合法目標)兩份規格只給了行為描述與建議鍵位,未給出
   `project.godot` 裡的具體動作名稱——**本 story 需要在實作時定案這 3 個動作的實際名稱**,
   建議沿用專案既有的 `battle_*` 前綴慣例(例如 `battle_open_hand`、
   `battle_next_target`、`battle_prev_target`),但這不是裁決,實作者可依 GDScript/Godot
   輸入系統慣例自行決定,只要求與後續使用這些動作的單元(U-011~U-015,不在本次授權範圍)
   保持一致並在 commit / doc comment 裡明確記錄最終定案的名稱。

5. **`InputMap` 約束驗證(ADR-0005 呈現層規則)**——依控制清單「載入期必須驗證 Input Map
   約束…鍵不存在時回報 UNKNOWN,不得視為通過」,本 story 新增的 5 個動作在
   `project.godot` 寫入後,必須有一種可驗證的方式確認它們確實存在且綁定正確(例如一條
   smoke test 呼叫 `InputMap.has_action()` 逐一檢查),不能只靠人眼讀 `project.godot`
   文字確認。

## Acceptance Criteria

*本單元沒有對應的 AC-U / AC-M 條文——它的驗收條件在 U-016(AC-U12/AC-M1,不在本次 8 個
單元授權範圍內),EPIC.md 第三節已明文登記這件事。以下是本 story 自訂的驗收基準:*

- [ ] `project.godot` 的 `[input]` 節新增 5 個動作,每個動作皆有鍵盤與手把兩側綁定
- [ ] `battle_end_phase` 現有的 `Esc`/手把 `B` 綁定完全不變(逐一比對 diff,不得有任何
      刪除或修改)
- [ ] `battle_cancel` 的鍵盤/手把綁定與 `battle_end_phase` 相同(`Esc`/`B`),驗證兩者
      會同時觸發(這是預期行為,不是缺陷)
- [ ] 5 個新動作皆可透過 `InputMap.has_action()` 查詢確認存在
- [ ] 若 U-004 探針發現任何衝突,本 story 的最終按鍵選擇與探針報告的結論一致(不得沿用
      衝突的建議值)

## Test Evidence

**型別**:Integration
**測試檔**:`tests/integration/ui/input/battle_new_actions_registration_test.gd`
(建議路徑,若 `tests/` 既有子目錄結構有更合適的位置,依實作時判斷調整)

預期涵蓋:
- `test_five_new_actions_exist_in_input_map`
- `test_battle_cancel_shares_bindings_with_battle_end_phase_during_transition`
- `test_battle_end_phase_bindings_unchanged`

## Out of Scope

- **`battle_end_phase` 解綁**——屬 U-016(不在本次 8 個單元授權範圍內)
- **任何按鍵的實際行為實作**(選單開啟、手牌展開等)——屬 U-007 及以後的介面單元
- **操作提示橫條的文字更新**——屬 U-016(該工作單本身會撞到 12px 餘裕的陷阱,EPIC.md
  陷阱十,與本 story 無關)

## Dependencies

- 依賴:U-004(探針結果)
- 解鎖:U-007(選單畫面需要 `battle_menu` 動作已存在)、U-016(不在本次授權範圍)
