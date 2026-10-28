# Story 002:台詞資料檔與解析

> **Epic**: `production/epics/support-conversation-ui/EPIC.md`
> **Status**: Ready(2026-10-28)
> **Type**: Logic
> **依據**: 劇本 `design/narrative/support-conversations-script.md`(管理者 2026-10-28「先照初稿用」);UX 規格 `design/ux/support-conversation-screen.md` 第 6、8 節與 AC-12、AC-13

## 設計(協調者判斷,實作者發現不合理就停下回報)

- **台詞文字一律進 `assets/data/locales/strings.csv`**(專案規則:所有玩家可見文字走在地化)。
  鍵名建議 `support.sc01.line01` …;角色顯示名若 CSV 尚無,新增 `character.name.1` … 之類的鍵(先 grep 既有是否已有角色名鍵,有就沿用)。
- **順序與說話者放資料檔** `assets/data/narrative/support_conversation_lines.txt`,欄位:
  `conversation_id,seq,speaker_roster_id,text_key`(比照 `support_conversations.txt` 的檔頭註解風格)。
- 〔〕舞台指示**不轉入**(EPIC 處置 Q5)。
- 解析器:`src/gameplay/narrative/` 下新增純 `RefCounted` 類別(例如 `SupportConversationScript`),提供「給 conversation_id → 依序的 (speaker_roster_id, text_key) 陣列」。比照 `SupportConversationRecord.records_from_text()` 的錯誤處理風格(解析失敗回 null + `push_error`)。

## Acceptance Criteria

- [ ] **AC1** 三段的句數與劇本逐字相符(SC-01 12、SC-02 14、SC-03 13),順序相同,說話者相同。**用測試讀真實資料檔驗證**(甲類例外,檔頭聲明)。
- [ ] **AC2** 每個 `text_key` 在 CSV 中存在,在地化後的文字與劇本逐字相同(抽樣即可,但三段各至少首句、末句)。
- [ ] **AC3** 格式錯誤(欄位數錯、seq 不連續、speaker 不在 1~5、conversation_id 不在 `support_conversations.txt`)→ 回 null 並 `push_error`。
- [ ] **AC4** `strings.csv` 列數測試(`tests/unit/core/i18n/locale_data_integrity_test.gd` 寫死的總數)照新增列數更新,在 2026-10-28 註解下加一行(管理者 2026-10-28 裁決過同樣處理方式)。
- [ ] 敏感度證明門檻(`.claude/rules/test-standards.md` 2026-09-16 節)。

## Affected Files

`assets/data/locales/strings.csv`、`assets/data/narrative/support_conversation_lines.txt`(新)、`src/gameplay/narrative/support_conversation_script.gd`(新)、`tests/unit/gameplay/narrative/...`(新)、`tests/unit/core/i18n/locale_data_integrity_test.gd`(只改列數)。

⚠️ 改 CSV 後一律 `GODOT_BIN=... bash tools/build/run_tests_with_import.sh`。
