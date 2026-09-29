# Story 005: `threat_targets()` 語意查證與必要時改名/擴充(U-T15)

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M3a(切面 4)
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M(含查證步驟)
> **Manifest Version**: 2026-09-09

## Context

**GDD**: Formulas 公式四(威脅範圍公式 `threat_range(e)`,含多敵聯集 `threat_range_all(E)`)、
UI Requirements §1a(敵方威脅範圍疊加圖,要求「任一敵方單位/多敵聯集+逐敵拆分」通用查詢)、
AC-21(威脅範圍)、AC-22(對外查詢介面的共用義務,含威脅範圍即時性向量)。

**Requirement**: `TR-tactical-036`(威脅範圍介面須在一次呼叫內同時回傳扁平聯集與逐敵拆分兩個切面)

**UX 規格原文(U-T15,`design/ux/tactical-combat-screen.md` 15 節)**:「`threat_targets()` 是否
已支援 GDD UI Requirements §1a 要求的『任一敵方單位/多敵聯集+逐敵拆分』通用查詢,或現況簽章
只回傳『目前選取單位』的威脅範圍……現況命名雖為 `threat_targets` 但實際回傳的是選取單位自身的
攻擊延伸,兩者可能是同一份程式碼被雙重期待……這是本規格中最需要優先釐清的技術假設落差之一」。

🔴 **本 story 的第一步是查證,不是假設答案**——依 UX 規格與 M1 查證報告的誠實揭露,
`threat_targets()` 是否已支援公式四的通用威脅範圍查詢**目前無人驗證過**。⚠️ **未查證的具體
缺口**:EPIC.md「Open Questions 現況」表把 U-T15 標為「M1 查證 + M3 定案」,但實際執行的
`docs/reviews/tactical-combat-m1-current-state-audit-2026-09-29.md` 8 項清單(U-T4/5/6/7/8/
10/11/12)**不包含 U-T15**——這是 EPIC.md 自身兩處記載互相不一致(「Open Questions 現況」表
與「M1 範圍」表對 U-T15 的歸屬不同),M1 那一批實際上**沒有**查證這件事。依 EPIC.md M1 節
「逾時處置」規則(未答項降級為接手模組第一張 story 的第一步),本 story 的第一步即是補上
這項查證。

**ADR Governing Implementation**: `ADR-0001`(**Accepted**)—— 威脅範圍查詢受 Core Rules #10/
AC-22 的即時性 + 單一快照原子性義務約束(公式四多敵聯集「兩者由同一次查詢一併回傳,不是兩個
介面」,原子性單位是整趟聯集)。

**Engine**: Godot 4.7.1 | **Risk**: LOW

## Acceptance Criteria

**第一步(查證,BLOCKING 於後續步驟之前)**:
- [ ] 讀 `_threat_targets_for()`(或現行實際函式名)完整內文,明確回答:現況簽章是否只接受
      「目前選取單位」,還是已支援任意敵方單位 id;回傳的座標集合語意上是「該單位的攻擊延伸」
      還是「依公式四定義的完整威脅範圍(可達格 × 射程投影聯集)」。**把查證結論寫回本 story
      檔案的 Implementation Notes 節**(供下一個讀者不必重查)。

**第二步(依查證結果二選一,擇一執行)**:
- [ ] **若查證結果為「現有函式已正確實作公式四語意,只是命名/呼叫範圍需要擴充」**:
      擴充簽章支援任意敵方單位/多敵聯集輸入,新增逐敵拆分切面,兩者由同一次呼叫回傳
      (TR-tactical-036);不需要改名。
- [ ] **若查證結果為「現有函式實際上是選取單位的攻擊延伸,與公式四的威脅範圍是不同概念」**:
      **改名優先於加參數**(EPIC.md R3 風險緩解原文:「若真是雙重期待,改名比加參數安全」)——
      保留現有函式服務其原本用途(不論該用途叫什麼),另外新增一個正確實作公式四語意的新查詢,
      不得讓兩種不同語意共用同一個名字。
- [ ] 不論走哪條路徑,最終須滿足:單一敵方單位輸入回傳其 `threat_range(e)`(公式四);多敵輸入
      同時回傳扁平聯集與逐敵拆分兩個切面(TR-tactical-036);遵守 AC-22(b)多敵聯集共用同一份
      快照的原子性義務

## Implementation Notes

⚠️ **未查證,待本 story 執行時補**:`_threat_targets_for()` 的實際函式名、現行簽章、現行回傳
語意——本 story 撰寫時未讀該函式內文(依 UX 規格與 M1 報告皆明文「未讀該函式內文,不代為斷言」,
本 story 沿用同一誠實揭露,不假設答案)。**下一個人從 `grep -n "threat_targets\|_threat_targets_for"
src/gameplay/battle/battle_controller.gd` 開始查**,完整讀該函式後,把查證結論寫回本節取代
這段文字。

**與 R3 風險的關聯**:EPIC.md 已將此列為風險 R3,判定「若真是雙重期待,改名比加參數安全」——
本 story 執行時若確認是雙重期待,不需要另外提出裁決請求,直接依此原則改名即可,不需回頭問。

## Out of Scope

- **威脅範圍疊加圖的世界層繪製**——story-014(M4),消費本 story 的輸出。
- **回合層級的多敵疊加圖切換 UI**——歸屬 #10 戰鬥 HUD,由本 story 只提供資料查詢。
- **`_threat_targets_for()` 之外其他函式的重新命名**——僅本 story 明確涉及的函式,不做範圍外
  的連帶重構。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 Task 工具不可用而跳過。**本節測試規格假設「查證結果為需要改名/
新增查詢」的較保守情境撰寫;若查證結果是「現有函式已正確」,測試對象改為擴充後的同一函式,
測試內容邏輯上等價。**

- **單一敵方單位的威脅範圍(AC-21 向量)**
  - Given: `reachable_set(e)={(0,0)}`,武器 `(2,4)`
  - When: 查詢威脅範圍
  - Then: 回傳以 `(0,0)` 為中心、曼哈頓半徑 `[2,4]` 的環
- **視線刻意不檢查(AC-21 向量)**
  - Given: 威脅範圍內某格實際被地形遮蔽
  - When: 查詢威脅範圍
  - Then: 該格仍計入輸出(公式四明文排除視線檢查)
- **多敵扁平聯集與逐敵拆分同時回傳(TR-tactical-036)**
  - Given: `E` 含 3 名存活敵方單位
  - When: 呼叫多敵威脅範圍查詢
  - Then: 單一次呼叫同時回傳扁平聯集(座標集合)與逐敵拆分(座標集合對每個 `e` 的歸屬)兩種切面
- **多敵共用同一份快照(AC-22(b) 縱向向量)**
  - Given: 跨幀計算 `threat_range_all(E)`,在第 1 名敵人子計算完成後、第 2 名開始前改動盤面佔位
  - Then: 整趟輸出恆等於「對計算開始時的同一份快照完整計算全部敵人並聯集一次」的結果,不得由
    對應不同時刻的子結果拼接

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gameplay/battle/threat_range_query_test.gd` —— BLOCKING

**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(不依賴 M2)
- Unlocks: story-014(M4 威脅範圍疊加圖繪製)

## 執行層序列化

本 story 屬 M3a,不受 M6→M5→M4 序列化約束(該約束僅適用於改動 `battle_screen.gd` 的
M4/M5/M6 三模組)。
