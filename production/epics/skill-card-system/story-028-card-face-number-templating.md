# Story 028:牌面文字支援數字樣板 —— 數字由卡表帶入,不寫死

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Ready(2026-11-19 管理者裁決「先開小單做帶入功能(推薦)」)
> **Type**: Logic + UI(取用處)
> **Estimate**: S(約半天,粗估未驗證)
> **依據**:2026-11-18 管理者裁決「牌面數字用 `%d` 樣板由卡表帶入,不寫死」(`design/narrative/card-face-text-14-2026-11-18.md` 檔頭第 3 行);story-022 實作者 2026-11-19 停損回報(協調者已查證屬實,見下)。

## 背景(協調者 2026-11-19 實查)

- `src/gameplay/cards/card_text.gd`:`CardText.flavor_texts_from_text()` 只認 `id,flavor_text` 兩欄(`FIELD_COUNT = 2`),原樣存字串,無任何樣板替換。
- `src/ui/battle/battle_screen.gd`:`_card_flavor_texts.get(card.id, "")` 取出後原樣送到確認面板與手牌兩處(當場 `grep -n "_card_flavor_texts.get" src/ui/battle/battle_screen.gd`)。
- 現行 `assets/data/cards/*_card_text.txt` 沒有任何樣板記號。

## 規則

- 樣板記號用**具名欄位**(例如 `{cost_amount}`、`{effect_value}`、`{target_range}`、`{delta_atk}`、`{delta_def}`、`{duration_rounds}` —— 以 `Card` 實際欄位名為準),**不用位置式 `%d`**:位置式在 14 張欄位組合各不相同時,錯位不會報錯。裁決原文寫 `%d` 指的是「由卡表帶入」這個意圖;具名記號是實作手段,若實作者認為位置式較好,停下說明理由。
- 替換**集中一處**(建議 `CardText` 新增靜態函式,傳入 `Card` 與原字串回傳替換後字串);`battle_screen.gd` 所有取用處都改走它,不得各自替換。
- 不含記號的舊文字原樣輸出(現行 8 張舊卡、教學場文字不動)。
- 未知記號 / 欄位不存在:`push_error` + 保留原記號字樣(畫面看得出錯),**不得**靜默替換成空字串或 0。不得用 `assert()`(release 匯出會被剝除,`coding-standards.md`)。
- 負數(例:防禦 −2):顯示格式由實作者對照 `design/narrative/card-face-text-14-2026-11-18.md`(用 `−` U+2212)決定並寫測試;若需另一種記號(例如「帶正負號」),停下問。

## Acceptance Criteria

- [ ] **AC1** 含記號的文字經替換後數字等於該卡卡表欄位(單元測試,至少涵蓋 cost_amount、effect_value、負數欄位各一)。
- [ ] **AC2** 不含記號的文字原樣輸出;現行 vs01~vs05 牌面文字經替換後與替換前逐字相同(以真實資料檔驗,甲類例外)。
- [ ] **AC3** 未知記號 → 保留記號字樣 + 有錯誤紀錄,不是空字串。
- [ ] **AC4** `battle_screen.gd` 的確認面板與手牌兩處都走同一替換函式(真實場景測試:注入一張含記號的卡,兩處顯示皆為替換後數字)。
- [ ] **AC5** 敏感度證明(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①替換函式回傳原字串 → AC1 紅 ②手牌處繞過替換 → AC4 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`(本機慢,加 `TEST_TIMEOUT_SEC=2400`),回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files

- `src/gameplay/cards/card_text.gd`、`src/ui/battle/battle_screen.gd`(只限 `_card_flavor_texts` 取用處)、`tests/unit/gameplay/cards/`、`tests/integration/ui/battle/` 新測試。超出先問。

## 與其他工單的順序

- **022 等本單**(022 的 14 張牌面文字要用記號)。
- 與 020b/020c 同碰 `battle_screen.gd`(不同段落)→ 不在同一工作目錄同時進行。
