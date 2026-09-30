# Story 003: Fallback 與缺字偵測回歸測試

> **Epic**: 本地化(i18n)基礎設施 —— `production/epics/localization-infrastructure/EPIC.md`
> **Status**: 🟡 **核准開工,強烈建議與 story-001 同批交付**(見下方理由)
> **Layer**: Infrastructure
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: N/A —— 本 epic 無 GDD

## Context

**權威文件**:無 GDD。依據 `EPIC.md` Q5(「測試怎麼寫」)。

**為什麼建議與 story-001 同批**:`EPIC.md` 原文明講,「缺 key 不顯示裸 key」本身是
story-001 骨架的一部分行為 —— 本 story 是**證明**那個行為存在的測試,而不是一個獨立的
新行為。把測試與被測行為分兩批交付,中間會有一段「行為已宣稱存在但無測試證明」的空窗期。
本 story 獨立列出的理由是**篇幅與職責**(測試撰寫 vs. 行為實作),不是因為它們可以隨意
分開排程。

## Acceptance Criteria

### A. 管線行為測試(headless 可跑)

- [ ] locale 檔案載入/解析正確 —— 至少一個真實 key 正確命中 `zh_TW` 翻譯內容(逐字比對,
      不只是「非空字串」)。
- [ ] 缺 key 時不 crash —— 對 story-001 定義的「完全不存在的 key」情境呼叫查找 API,
      斷言不拋出未捕捉例外、不中止測試執行。
- [ ] 缺 key 時不顯示裸 key —— 斷言回傳值**不等於**該 key 字串本身,且等於 story-001
      已定義的明確替代值(例如 debug 佔位標記或空字串,依 story-001 實際決定的行為斷言,
      不得自行假設)。
- [ ] key 格式驗證:
      - 無重複 key(同一份 locale 資料檔內同一 key 出現兩次以上應被偵測)
      - 無空值(key 存在但翻譯內容為空字串,若非刻意設計應被偵測 —— 若 story-001 允許
        空字串作為某種合法佔位行為,本測試需區分「刻意留空」與「遺漏」,具體判準由本
        story 實作者依 story-001 實際設計決定)
- [ ] 🔴 **新增測試檔案位置若落在既有 `tests/unit/` 底下,不需改動 `tests/gdunit4_runner.gd`
      的 `FORCED_ARGS`**;但本 story 開工時必須**現場讀取** `tests/gdunit4_runner.gd`
      確認 `FORCED_ARGS` 的實際寫法(是否已用遞迴方式涵蓋 `tests/unit/` 任意深度子目錄),
      **不得假設**它一定涵蓋 —— `.claude/docs/coding-standards.md` 已登記過一次「本機只掃
      `tests/unit`,新增 `tests/integration` 後 5 條測試一次都沒跑,回報卻全綠」的前例,
      同一類疏漏可能以不同形式重演在新增子目錄上。

### B. 靜態紀律回歸測試(讀 `src/**/*.gd` 原始碼文字)

- [ ] 斷言「不存在裸中文字串常數」(或裸字串型式的 `const \w+: String = "..."`,依
      story-002 遷移後的定義為準) —— 這是本專案 `.claude/rules/test-standards.md`
      登記的**乙類例外**(唯讀 `src/**/*.gd` 與 `tests/**/*.gd` 文字,用於斷言原始碼紀律)。
- [ ] **必須遵守乙類例外的兩項附帶義務**(逐字轉錄自 `test-standards.md`,不得省略任一項):
      1. 測試檔檔頭必須寫明它屬乙類,以及為何不能用注入取代(掃描原始碼文字這件事本身
         無法用依賴注入替代,因為斷言對象就是原始碼字面內容)。
      2. 🔴 測試檔必須自陳「斷言範圍不等於窮盡性」——明確列出掃描抓不到的情況,至少包含:
         動態組字串(例如 `"a" + "b"` 或字串插值組出的裸文字)、`.tres` 資源檔內文字、
         `.tscn` 場景檔節點屬性內的裸字串(這部分屬 story-002 的 `.tscn` 遷移範圍,本測試
         的掃描範圍明文只涵蓋 `.gd`,不涵蓋 `.tscn`)。
- [ ] 若本測試需要示範水準參考,`test-standards.md` 已指出
      `tests/unit/cursor/cursor_modulate_alpha_single_writer_test.gd` 與
      `cursor_mouse_mode_single_writer_test.gd` 是既有乙類範例中「寫得比要求更徹底」的
      參考水準 —— 建議比照該水準撰寫,而非只滿足最低要求。

### C. 敏感度證明(依 `test-standards.md` 2026-09-16 管理者裁決)

- [ ] 每條測試要嘛有敏感度證明(間諜子類別 + 會通過的 `test_sensitivity_proof_*` 測試,
      斷言「偵測器真的抓到了這個植入的缺陷」),要嘛寫下可查證的「為什麼證明不了」
      (`test-standards.md` 已登記至少五類結構性做不到的形狀,新測試若落在其中一類,
      直接引用該分類,不必重新推導理由)。
- [ ] **不准為了湊數硬生假證明** —— 收到「N 條裡 M 條可證、其餘不可證且理由如下」是
      正確交件標準,不是「N 條全部完成」。

## Implementation Notes

1. **測試檔案建議位置**:比照 story-001 的建議,`tests/unit/core/i18n/` 或實作者選定的
   等效路徑,與 story-001 的實作程式碼位置對應。
2. **與 story-002 的關係**:B 節的靜態紀律測試若在 story-002 完成遷移之前先寫好並跑,
   預期會在 story-002 完成前呈現失敗(因為既有 6 個檔案的裸字串常數尚未遷移)——這是
   預期中的紅燈,不是本測試寫錯。`EPIC.md` Q2 已建議把這條測試包成「長期防止新字串再次
   直接寫死」的回歸測試,故此測試的存在本身跨越 story-002 前後兩個階段是設計上允許的。
3. **A 節「完全不存在的 key」情境的測試資料**,依 `.claude/rules/test-standards.md` 的
   「Test fixtures use in-test constants, factory functions」規則,應在測試內用一個
   刻意不存在於 locale 資料檔的 key 字串常數,不需要讀取真實 `assets/data/locales/`
   之外的任何檔案。

## Out of Scope

- **story-001 D 節「決定 fallback 行為」本身** —— 那是行為的設計與實作,不是本 story
  的範圍;本 story 只負責測試已定義的行為。
- **`.tscn` 場景檔內容的靜態掃描** —— B 節明文排除,原因是乙類例外的掃描範圍限定
  `src/**/*.gd` 與 `tests/**/*.gd` 文字,不涵蓋 `.tscn`。
- **匯出建置平台驗證的自動化** —— story-001 E 節已明文這項無法自動化,本 story 不重複
  嘗試。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 `Task` 工具不可用而跳過。本 story 本身即為測試撰寫工作單,
其「QA Test Cases」即上方 Acceptance Criteria 逐項展開,不重複列一份等價清單。

## Test Evidence

**Story Type**: Logic

**Required evidence**:
- `tests/unit/core/i18n/`(或等效路徑)下的管線行為測試(A 節)—— BLOCKING
- 靜態紀律回歸測試(B 節)—— BLOCKING,但預期在 story-002 完成前呈現紅燈(見上方
  Implementation Notes 第 2 點,不視為本 story 失敗)
- 敏感度證明或「為什麼證明不了」的逐條登記(C 節)—— BLOCKING,依測試證據表對 Logic
  型 story 的既有規則

**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-001(必須先有被測的查找 API 與已定義的 fallback 行為,測試才有
  對象可測;強烈建議同批交付,見上方 Context)
- Unlocks: None 直接解鎖項,但本 story 是「story-001 宣稱的 fallback 行為確實成立」這件
  事唯一的可查證證明來源 —— 沒有本 story,story-001 的 D 節 AC 只是自述,不是已驗證事實。
