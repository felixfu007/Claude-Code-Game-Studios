# Story U-017: 兩張卡表的編號集合一致性 —— 從 U-003 搬出來的孤兒測試

> **Epic**: 卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **狀態**: ✅ Complete(2026-09-16 建立即完成 —— 測試本體早已存在且綠燈,本工作單是為它補上擁有者與驗收範圍)
> **層**: Data(卡表資料一致性,不涉 UI)
> **型別**: Logic
> **估時**: XS
> **依賴**: U-001(卡表解析)、U-002(牌面文字解析)
> **解鎖**: 無
> **波次**: 不適用(補登記)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)

## Context

**這張工作單不是新工作,是替一條既有測試補上戶籍。**

`test_cards_table_and_card_text_table_have_identical_id_sets` 原本寫在
`tests/integration/ui/battle/battle_screen_card_deck_wiring_test.gd`(U-003 的驗收證據檔)
裡,測試檔頭記載它是「依協調者 2026-09-16 續做指示新增」。

但它:

- **不對應 U-003 任何一條 AC**,而且 U-003 工作單的 `## Out of Scope` 節**明文排除它**。
- **不測 `battle_screen.gd` 的任何行為** —— 它只借用了 `BattleScreen.CARDS_PATH` /
  `CARD_TEXT_PATH` 兩個路徑常數,實質檢查的是兩張資料表本身的一致性。

**後果**:日後任何人掃描「U-003 的驗收證據涵蓋了哪些 AC」時,會把它誤算進去。
`ui-programmer` 於 2026-09-16 驗收 U-003 時主動指出這件事並建議搬離,
**管理者同日裁決採納**。

## 目標

把該測試搬到 `tests/integration/gameplay/cards/` 底下的獨立檔案,
讓它有自己的擁有者與驗收範圍。**測試邏輯本身不改動** —— 它已經是綠燈且抓真實風險。

## Implementation Notes

1. 🔴 **它保護的是一個真實踩過的坑。** 本專案 2026-09-16 實測發現
   `vs01_cards.txt:66` 與 `vs01_card_text.txt:44` 各有一行**沒加 `#` 的裸表頭**,
   長得跟真資料一模一樣。舊規則下被靜默跳過、測試全綠、永遠不會有人發現。
   **兩張表的編號集合比對,正是這類錯誤的第二道網。**
2. **路徑常數怎麼拿**,由實作者裁量並在新檔檔頭寫明選擇與理由:
   繼續從 `BattleScreen` 借 → 新檔對 UI 類別產生概念上不必要的相依;
   改為自有常數 → 多一個漂移面(路徑改了測試不會跟著改)。**兩種都可接受,但不得不寫理由。**
3. 本測試讀 `assets/data/` 底下已進版控的真實資料檔,**屬 `.claude/rules/test-standards.md`
   的「甲類」明文例外**。依該節義務,**檔頭必須寫明它屬甲類、以及為什麼不能用注入取代**。

## Acceptance Criteria

- **AC-1**:**GIVEN** `vs01_cards.txt` 與 `vs01_card_text.txt` 兩張真實資料表,
  **WHEN** 各自解析出卡片編號集合,**THEN** 兩個集合完全相等(無多、無少)。
- **AC-2**:該測試**不再存在於** `battle_screen_card_deck_wiring_test.gd`,
  且該檔搬家後剩 **14 條**測試。
- **AC-3**:新測試檔有配對的 `.uid` 檔,且檔頭註明歸屬 U-017 與甲類例外理由。
- **AC-4**:全套測試總條數維持 **748**(純移動,不增不減),套件數 61 → 62。

## Test Evidence

型別 Logic,證據為自動化測試本身:`tests/integration/gameplay/cards/` 底下的新檔案。

🔴 **敏感度證明**:依 `.claude/rules/test-standards.md` 的完成門檻,本測試
**屬「已知證明不了的 A′ 類」**(斷言對象是真實資料檔內容,沒有類別可注入錯誤版本)。
**不可證理由已記錄,依門檻視為達標** —— 不得為此硬生假證明。

## Out of Scope

- 不改動測試邏輯本身。
- 不處理 `coding-standards.md` 第 140/142 行那處自我矛盾(獨立文件動作,見
  `.claude/rules/test-standards.md` 末節)。

## Dependencies

- U-001 / U-002:兩張表的解析器,本測試依賴它們產出編號集合。
