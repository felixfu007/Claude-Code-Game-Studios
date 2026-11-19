# Story 029:牌面文字表拆成「牌名、效果」兩欄 —— 修正新卡牌面溢出手牌說明框

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Ready(2026-11-19 管理者裁決「先合入,另開單拆欄(推薦)」)—— 依賴 022 合入 main。
> **Type**: Logic(解析)+ UI
> **Estimate**: M(約 1 天,粗估未驗證)
> **依據**:ux-designer 判定 `docs/reviews/card-face-one-line-ux-ruling-2026-11-19.md`(方案 A);story-022 實作者回報(文字表只能單行、無牌名欄,牌面被串成「【牌名】效果；條件；代價」)。

## 問題(2026-11-19 已知缺陷,022 合入時登記)

- vs02~vs05 新卡牌面約 45~70 字;手牌 Z3 卡面文字區推估約 27~36 字(算術推估,**未截圖驗證**),Label `AUTOWRAP_WORD_SMART`、無 `clip_text`、Panel 無 `clip_contents` → **溢出蓋住「不可打原因」行,不報錯**。
- 單行裡的「代價：…」與確認面板既有代價列重複,兩者數字來源不同,日後可能不一致。
- `【】` 是寫進資料的裝飾字面,日後無法統一換樣式(ux 不接受長期保留)。

## 規則(以 ux 判定檔方案 A 為準;下列為摘要,有出入以該檔為準)

- 文字表改為 `id,card_name,effect_line`(舊 8 張卡 `card_name` 可留空,解析器須接受舊兩欄格式或明訂遷移 —— 實作者先讀 ux 判定檔再定,不確定就停下問)。
- Z3 顯示牌名 + 效果行;確認面板標題用牌名。**條件與代價不放在牌面文字**,交給既有專屬列(020a 代價區塊、020b 不可打原因)。
- 條件句(例:c03「該單位 2 格內有隊友」)在牌面上要不要出現、放哪裡 → **narrative-director 先裁**,實作者不自擬文案。
- 數字記號沿用 story-028 `CardText.render`。

## Acceptance Criteria

- [ ] **AC1** 解析:新三欄與舊兩欄(或遷移後)皆正確解析;欄數錯誤拒絕(push_error + 明確失敗值,不用 assert)。
- [ ] **AC2** 一致性:5 關牌表 id 集合 == 文字表 id 集合(沿用 022 測試)。
- [ ] **AC3** 資料內不再含 `【`、`】`、`代價：`(以 grep 驗,指令不得自我命中)。
- [ ] **AC4** 真實場景:Z3 顯示牌名 + 效果;確認面板標題為牌名(真實 `BattleScreen.tscn`)。
- [ ] **AC5** Check 5 人眼:1280×720 最小視窗下,最長新卡的 Z3 不溢出、不蓋住原因行(午休開窗,受測者只有管理者本人)。
- [ ] **AC6** 敏感度證明(常駐 `test_sensitivity_proof_*`):①牌名欄與效果欄對調 → AC4 紅 ②解析器接受錯誤欄數 → AC1 紅。
- [ ] 交付前全套(加 `TEST_TIMEOUT_SEC=2400`),回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files(暫定)

- `src/gameplay/cards/card_text.gd`、`assets/data/cards/vs0N_card_text.txt`(含教學場若適用)、`src/ui/battle/hand_bar.gd`、`src/ui/battle/card_confirm_panel.gd`、`src/ui/battle/battle_screen.gd`(只限牌面取用處)、相關測試。超出先問。

## 與其他工單的順序

- 依賴 022 合入;與 020c 同碰 `battle_screen.gd`/`card_confirm_panel.gd` → 不同時在同一目錄進行。
