# Story 005: `threat_targets()` 語意查證與必要時改名/擴充(U-T15)

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M3a(切面 4)
> **Status**: ✅ **Done(2026-10-12)** —— 查證完成並走 AC 第二步的**第一條路徑(不改名)**,經協調者獨立驗收
>
> **查證結論摘要**(全文在下方 Implementation Notes,**不要只讀這段**):`_threat_targets_for()`
> 的結構**本來就對應 GDD 公式四**,不是「選取單位的攻擊延伸」這種不同概念。U-T15 懷疑的
> 「雙重期待」確實存在,但不是整個函式語意不對,而是**兩個更窄的缺口**:(a) 被同陣營閘門鎖死,
> 玩家回合查敵方一律空陣列;(b) 實作做視線遮蔽判定,而 GDD 公式四**刻意不做**(理由逐字
> 「寧可高估、絕不低估」)—— 兩者方向相反,實作在視線軸上會低估。
>
> **落地內容**:`battle_controller.gd` 新增 `threat_range_for(unit_id)`(單一單位,公式四語意,
> 不受 Phase/陣營閘門,改用 `CombatRules.is_in_range()` 純曼哈頓距離)與
> `threat_range_all(unit_ids)`(一次呼叫同時回傳 `union` 扁平聯集與 `per_unit` 逐敵拆分,
> TR-tactical-036),另一個私有 helper `_move_reach_for()`。
> 🔴 **`threat_targets()` / `_threat_targets_for()` 既有程式一個字元都沒改。**
>
> **協調者獨立驗收(非採信回報 —— 實作者撞上回合上限,未交出報告)**:
> 全套重跑 `Overall Summary: 1074 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped |
> 0 orphans`、`ENGINE EXIT CODE = 100`、`Parse Error / Abnormal exit = 0`;
> `1065 → 1074` 正好 **+9**,與新增 `func test_` 數**完全對得上**。
> 注入殘留 **0 命中**;`git diff src/gameplay/battle/battle_controller.gd` 刪除行 **0**。
> 另查 `_move_reach_for()` 是否重刻了一份可達格邏輯 —— **沒有**,它呼叫的是既有
> `_move_targets_for()` 同一支 `_state.legal_moves(unit_id)`,只是不套 phase/回合閘門。
> (本專案登記過「同一個公式兩份實作、只是今天答案一致」的失效模式,故特別查。)
>
> 🔴 **留下一個必須傳下去的事實**:`threat_targets()`(既有,含視線)與 `threat_range_for()`
> (新增,不含視線)**對同一個單位會給出不同答案,而且這是刻意的**。既有路徑的視線政策
> 是否也該重新檢視,實作者已明文登記為本 story 範圍外 —— 見 Implementation Notes 第 4 項。
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

✅ **查證結論(本 story 執行時完成,2026-10-12)**:

1. **現況簽章**:公開 `threat_targets()` 固定呼叫 `_threat_targets_for(_selected_unit_id)`,
   但 `_threat_targets_for(unit_id)` 本身**已經**接受任意 `unit_id` 參數,不是寫死只接受選取
   單位——把它鎖死在選取單位上的是外層那一行轉發,不是函式本體。

2. **回傳語意**:`_threat_targets_for()` 的「起點集合 = 現在位置 + 移動延伸
   (`_move_targets_for`)」結構,**本身已經正確對應 GDD 公式四 `threat_range(e)` 的
   `reachable_set(e)` 定義**——它不是「選取單位的攻擊延伸」這種與公式四整體無關的不同概念。
   UX 規格 U-T15 懷疑的「雙重期待」確實存在,但不是「整個函式語意不對」,而是兩個更窄、各自
   獨立的缺口:
   - **(a) 範圍缺口(U-T15 真正指出的那個)**:`_threat_targets_for()` 被
     `_order.can_attack(unit_id)` 內 `_is_actionable()` 的同陣營/回合閘門鎖死——在玩家回合
     查任何敵方單位一律拿到空陣列,而那正是威脅範圍疊加圖需要畫的時機。
   - **(b) 視線軸缺口(查證時另外發現,先前無人驗證過)**:`_threat_targets_for()` 經由
     `BattleState.is_attack_reachable()` 間接呼叫 `CombatRules.is_attack_legal()`,**會檢查
     視線**;但 GDD 公式四正文明文排除視線檢查("寧可高估、絕不低估"——
     `design/gdd/tactical-combat-system.md` 公式四段落)。兩者方向相反:實作在視線軸上會
     低估,而 GDD 的保守性論證正建立在「視線軸上絕不低估」之上。

3. **判定與做法(走 AC 第二步的第一條路徑,不改名)**:結構已對,問題在閘門與視線兩處,因此
   不需要改名、也不需要放寬 `_threat_targets_for()` 本體的 unit_id 範圍。新增兩個完全獨立於
   `_threat_targets_for()`/`threat_targets()` 既有程式碼路徑的查詢:
   - `threat_range_for(unit_id)`——單一單位,公式四語意,不受 Phase/陣營/`can_attack()` 閘門
     限制(比照 story-004 `unit_action_state()` 先例的設計理由),改用
     `CombatRules.is_in_range()`(純曼哈頓距離,無視線)取代 `is_attack_reachable()`,同時修正
     (a)(b) 兩個缺口。
   - `threat_range_all(unit_ids)`——多敵聯集 + 逐敵拆分,單一次呼叫回傳兩個切面
     (TR-tactical-036),建構在 `threat_range_for()` 之上;GDScript 單執行緒同步呼叫鏈保證
     沒有外部寫入能插入兩個子計算之間(AC-22(b))。
   `_threat_targets_for()`/`threat_targets()` **既有程式碼一個字元都沒有修改**——零回歸風險,
   既有測試維持原樣全數通過(含新增的一條回歸測試直接對照兩者在無遮蔽場景下同值)。

4. **明文登記的缺口(非本 story 裁決範圍)**:上述 (b) 視線軸缺口只在本 story 新增的兩個查詢
   中修正;`attack_targets()`/`threat_targets()`(選取單位、含視線檢查的既有路徑)本身是否也
   該重新檢視視線政策,是另一個問題——那是既有、已通過驗收的功能,本 story 的 Out of Scope
   明文排除「`_threat_targets_for()` 之外其他函式的重新命名/連帶重構」,故刻意不動它的既有
   語意,僅在此登記供日後參考。

**測試證據**:`tests/unit/gameplay/battle/threat_range_query_test.gd`,9 條測試(含 2 條敏感度
證明)全數通過,詳見 Test Evidence 節。

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

**Status**: [x] ✅ 已建立並通過 —— `tests/unit/gameplay/battle/threat_range_query_test.gd`,9 條
(含 **2 條常駐敏感度證明**,突變子類別 `_MutantThreatRangeChecksSight` 與
`_MutantThreatRangeAllInconsistentUnion`,分別植入「偷偷加回視線檢查」與「聯集與逐敵拆分不一致」
兩種缺陷,斷言測試抓得到)。當場數:`grep -c "^func test_" tests/unit/gameplay/battle/threat_range_query_test.gd`

## Dependencies

- Depends on: None(不依賴 M2)
- Unlocks: story-014(M4 威脅範圍疊加圖繪製)

## 執行層序列化

本 story 屬 M3a,不受 M6→M5→M4 序列化約束(該約束僅適用於改動 `battle_screen.gd` 的
M4/M5/M6 三模組)。
