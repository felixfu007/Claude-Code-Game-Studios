# Story U-002: 牌面文字表解析(id → flavor_text 對照)

> **Epic**: 卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **狀態**: ✅ Complete(2026-09-16)
> **層**: Gameplay(資料層 —— A 段,不碰按鍵,不受取消鍵同批義務約束)
> **型別**: Logic
> **估時**: S
> **依賴**: 無
> **解鎖**: U-003
> **波次**: 波 0(與 U-001 ∥ U-004 ∥ U-006 四路真平行 —— 四個不同檔,零交集)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)

## Context

**權威來源**:`assets/data/cards/vs01_card_text.txt` 檔頭。

🔴 **本單元沒有對應的 AC-U / AC-M 條文,這不是缺陷** —— 理由同 U-001:兩份 UX 規格都不管轄
資料載入(EPIC.md 第三節)。

**Governing ADR**:N/A —— 純資料解析,不涉及任何跨系統契約或架構模式。

**為什麼這張表獨立於 `vs01_cards.txt`(2026-09-15 管理者裁決,`vs01_card_text.txt` 檔頭轉錄)**:
1. `card.gd` 的 `Card` 類別沒有任何欄位儲存牌面顯示文字 —— 混在同一張表會讓人誤以為
   `flavor_text` 也是 `Card` 的欄位。
2. `design/ux/skill-card-play.md` 的 Localization Considerations 節指出中文翻成其他語言
   常膨脹 2~3 倍字元數,而卡面正文是本介面最緊的版面(HIGH 風險)。數值與文字分離,
   將來換字級/排版/加翻譯只需要動這一張表。
3. 「不動已提交的資料」——本檔獨立以後,日後修牌面用詞不需要重新提交 `vs01_cards.txt`。

## 目標

寫一個能把 `vs01_card_text.txt` 解析成 `id → flavor_text` 對照的解析器,跳過空行與 `#`
註解列。做完之後,牌面顯示文字第一次有程式讀得到 —— 但**本 story 不把它接進 `Card` 物件**
(`vs01_card_text.txt` 檔頭已明文建議:呼叫端各自解析兩張表、各自產生對照,不建議在解析時
就把 `flavor_text` 塞進 `Card` 物件本身,以維持 `Card` 是 pure data holder 的既有定案)。

## Implementation Notes

1. **新增檔案** `src/gameplay/cards/card_text.gd`(EPIC.md 單元清單指定的目錄)。建議形狀:
   一個 `class_name CardText`(或等效靜態工具類別)上的靜態方法
   `flavor_texts_from_text(text: String) -> Dictionary`,回傳 `Dictionary[String, String]`
   (鍵為 `id`,值為 `flavor_text`)——沿用 `AffinityLink.links_from_text()` 回傳陣列、
   `Unit.roster_from_text()` 回傳陣列的既有慣例精神,只是這裡回傳的容器形狀是對照表而非陣列
   (因為呼叫端要用 `id` 查找,不是逐一走訪)。

2. **欄位格式**:`id,flavor_text`,每行僅在**第一個逗號**處分割(`split(",", true, 1)` 或
   等效寫法),不得用「以逗號分割整行取全部子字串」的寫法。理由:`vs01_card_text.txt` 檔頭
   明文警告「內容避免使用逗號(改用「、」或破折號),本表沿用專案既有簡單 CSV 慣例,沒有
   引號跳脫機制」——這句話本身承認了慣例的脆弱性,**分割時限制在第一個逗號可以讓「文字裡
   不小心多一個逗號」的後果從「解析出兩個欄位、資料錯位」降級為「flavor_text 保留了原本
   該被視為分隔符的那個逗號」**,錯誤更容易被人眼發現,也不會炸出例外或吃掉半句話。

3. **空行與 `#` 開頭的註解列必須跳過**——沿用既有慣例,與 U-001 一致。

4. **本 story 不驗證 `vs01_card_text.txt` 與 `vs01_cards.txt` 的 `id` 是否一一對應**——
   這是一項跨檔案不變量(`vs01_card_text.txt` 檔頭:「本檔沒有任何一列可以脫離
   `vs01_cards.txt` 存在」),但本 story 的解析器對 `vs01_cards.txt` 零認知,無從驗證。
   📌 **這是我核對後主動發現的一個缺口,不在 EPIC.md 的陷阱清單裡**:目前沒有任何一張
   story(含 U-003)明文承擔「兩表 id 集合是否一致」的檢查職責。U-003 的整合測試若使用
   真實的兩份資料檔,兩表目前恰好一致,但沒有一條測試把這件事釘死。**建議 U-003 或其後續
   工作單補一條「兩表 id 集合相等」的檢查**,但本 story 不擅自把它塞進自己的範圍(那會混淆
   「這張表自己好不好解析」與「兩張表合起來一不一致」兩個不同問題)。

## Acceptance Criteria

*本單元沒有對應的 AC-U / AC-M 條文,理由同 Context。以下是本 story 自訂的驗收基準:*

- [ ] `CardText.flavor_texts_from_text()` 解析 `vs01_card_text.txt` 全文得到恰好 8 筆對照,
      鍵為 `card_01`~`card_08`
- [ ] 對照表的值與檔案內容逐字相符(含中文標點,例如「——」與「、」)
- [ ] 只在第一個逗號分割 —— 用一筆刻意構造的、`flavor_text` 內容含逗號的測試資料驗證
      解析結果不會在 `flavor_text` 裡被錯誤截斷或产生第三個欄位
- [ ] 空行與 `#` 註解列被跳過,不產生任何對照項或錯誤

## Test Evidence

**型別**:Logic
**測試檔**:`tests/unit/gameplay/cards/card_text_test.gd`

預期涵蓋:
- `test_flavor_texts_from_text_parses_vs01_card_text_txt_into_eight_entries`
- `test_flavor_text_content_matches_source_file_verbatim`
- `test_split_only_on_first_comma_preserves_commas_in_flavor_text`
- `test_blank_and_comment_lines_are_skipped`

## Out of Scope

- **卡牌機制數值解析(`Card` 物件本身)**——屬 U-001,不同檔案 `vs01_cards.txt`
- **把 `flavor_text` 接進 `Card` 物件或任何顯示層**——`vs01_card_text.txt` 檔頭明文建議
  兩表各自解析、呼叫端以 `id` 分別查找,顯示層何時查詢是後續介面單元(U-011 以後)的職責,
  不在本次 8 個單元的授權範圍內
- **兩表 `id` 集合一致性檢查**——見第 4 點,登記為缺口,交由 U-003 或後續工作單判斷是否補上

## Dependencies

- 依賴:無
- 解鎖:U-003(需要本 story 交付的 `flavor_texts_from_text()`,雖然 U-003 本身不接畫面,
  但它是本 epic 第一個同時載入兩張表的地方)
