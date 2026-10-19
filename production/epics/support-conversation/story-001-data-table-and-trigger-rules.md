# Story 001:支援對話資料表、觸發判定與規則驗證(純邏輯)

> **Epic**: 支援對話系統 —— `production/epics/support-conversation/EPIC.md`
> **Status**: ✅ **Done(2026-10-19,協調者獨立重跑驗收,不採信回報)** —— AC1~AC7 全部有通過的自動化測試。全套 `ENGINE EXIT = 0` / `1335 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans` / `(114/114)` / 兩個 grep 零命中。新增 3 個測試套件、40 條測試。
> **Layer**: Domain(純邏輯,零節點、零場景)
> **Type**: Logic(**BLOCKING** —— 必須有自動化單元測試)
> **Estimate**: M
> **規格權威**:`design/quick-specs/support-conversation-system.md`
> **內容來源**:`design/quick-specs/mvp-five-levels-skeleton.md` 第三部分(Q1~Q3 已結案)

## 範圍:只做邏輯,**不接任何真實的好感度池**

**EPIC 的開工前查核發現兩個結構缺口**(池的來源送不出去、池活不過一場戰鬥),
**兩者都已交回管理者裁決,本 story 不等它們、也不碰它們**:
> **本 story 的寫入一律走依賴注入(吃一個介面型別的參數),由呼叫端決定寫到哪裡。
> 測試用假的寫入埠驗證「有沒有寫、寫了幾次、寫了什麼」,不碰 `AffinityDataPool`。**

這與本專案既有做法一致:`AffinityPoolWritePort` 自己的 `_init(pool)` 就是依賴注入
(`## [param pool] 是本轉接器實際寫入的目標(依賴注入,ADR-0002 機制一)`)。

## 🔴 必須照抄的既有慣例:解析與讀檔分離

```
src/gameplay/cards/card_text.gd:12:
## Parsing is deliberately split from file reading (this class never touches
## [FileAccess]) — mirrors [method Unit.roster_from_text]
```
**解析類別完全不碰 `FileAccess`**,吃一個 `String` 回傳結構化資料。
**這就是為什麼本專案的單元測試不必碰檔案系統。** 照同一條路走,不要自己發明第三種。

## Acceptance Criteria

- **AC1(資料表格式)**:新增版控資料檔 `assets/data/narrative/support_conversations.txt`
  (副檔名比照既有 `assets/data/` 慣例,**不要發明新格式** —— 先看 `assets/data/cards/vs01_cards.txt` 長什麼樣)。
  欄位依規格第 2 節:`conversation_id` / `trigger_after_mission` / `pair_a` / `pair_b` / `valence`。
  **內容就是五場骨架 Q2 那三列**(SC-01 甲乙 positive、SC-02 甲丙 negative、SC-03 乙丁 positive)。
- **AC2(解析器)**:一個**不碰 `FileAccess`** 的解析類別,`String → Array[記錄]`。
  畸形輸入(欄位數不對、未知 valence、未知角色)**必須有明確的拒絕行為**,不得靜默吞掉。
  🔴 **不得用 `assert()` 擋「不可能的分支」** —— 本專案實測:`assert()` 失敗會中止函式並回傳
  **宣告型別的序數 0**,而序數 0 慣例上就是「成功」,等於**失敗時靜默回報成功**
  (`.claude/docs/coding-standards.md` 有可重跑的重現步驟)。用 `push_error()` + 明確 return。
- **AC3(觸發狀態機)**:每筆對話有三個狀態 `not_triggered` / `completed` / `skipped`,
  且**只有合法轉移**(規格第 3 節、第 5 節)。
- **AC4(規則:負向不得排最後槽)**:一個驗證函式,對「`valence = negative` 且
  `trigger_after_mission` 是最後一場」回報違規(規格 AC-3)。
  📌 **現行資料剛好滿足**(SC-02 在 2→3),所以**這條測試必須用合成資料驗「違規會被抓到」**,
  不能只驗現行資料通過 —— 否則它是一條永遠綠燈、證明不了任何事的測試。
- **AC5(陣亡跳過)**:觸發時任一參與者已陣亡 → 整段跳過、**不產生任何寫入**、狀態記 `skipped`
  (**不是** `completed`,規格第 5 節明文要求可事後查核)。
- **AC6(寫入呼叫點恰好一處)**:規格 AC-6 逐字要求「對整個程式庫搜尋好感度池寫入介面的呼叫點,
  並篩出屬於支援對話系統的部分,**恰好找到 1 處**」。
  🔴 **寫這條的查核指令時,指令本身不得把自己算進去** —— 本專案 2026-10-12 實測:
  一條寫在註解裡的 `grep` 指令**會命中它自己那一行**,而且第一次修正又犯了同樣的錯。
  **把搜尋路徑排除掉註解所在的檔案,或 anchor 在 `^func`,或 `| grep -v ":#"`。**
- **AC7(自動觸發、不可延後)**:規格第 3 節的「沒有『可延後』這個狀態」要**體現在型別上**
  (狀態機裡根本不存在那個狀態),不是靠註解宣告。

## 本 story 不涵蓋(明文,不是疏漏)

- **不接真實好感度池、不接關卡轉場** —— epic 的兩個結構缺口待裁決(story-002)。
- **不寫對話文字內容**(`writer` 的工作)。
- **不做 UI**(系統 #11)。
- **不處理「對話播放中途存檔」**(規格開放問題 5,需 ADR-0004,明確不在 12 個月範圍內)。

## 交付前必做

跑一次全套,**貼出引擎原始三行**(`ENGINE EXIT` / `Overall Summary` / `Executed test suites`):

```
GODOT_BIN="C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  bash tools/build/run_tests_with_import.sh
```
⚠️ **先看 exit code 再 grep log**(105 代表測試一條都沒跑,而兩個 grep 都會回空)。
