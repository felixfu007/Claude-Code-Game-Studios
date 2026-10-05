# Story Index — Epic: 本地化(i18n)基礎設施

> 本檔先於逐張 story 內容寫出,供任何一次寫作中斷後的接手依據。完成後仍保留(不刪除)
> 作為 story 檔全集的目錄,但 `EPIC.md` 的「## Stories」表才是正式狀態欄
> (本次派工未更動該表,見本檔末「本次派工的邊界」節)。

## Story 清單

| # | 檔名 | 型別 | 一句話範圍 | 依賴 | 是否為 M5 開工前 gating 項 |
|---|---|---|---|---|---|
| 001 | story-001-core-lookup-api-and-locale-structure.md | Logic/Integration | 核心 key 查找 API + `assets/data/locales/` 結構 + `project.godot` 設定 + `zh_TW` locale 骨架 | 無 | ✅ 是 —— `tactical-combat` story-012/013 開工前置條件 |
| 002 | story-002-migrate-existing-hardcoded-strings.md | Integration | 既有 4 個 `.gd` + 2 個 `.tscn` 裸字串遷移至 key 系統 | 001 | 否 —— 建議盡快做,不阻擋 M5 |
| 003 | story-003-fallback-missing-key-regression-tests.md | Logic | Fallback 行為 + 缺字偵測的管線測試與靜態紀律回歸測試 | 001(建議同批) | 否,但「缺 key 不顯示裸 key」本身是 001 骨架行為的一部分 |

## ✅ Story 001 已完成(2026-10-05)

A~E 五節全部落地:locale 目錄與 CSV(`godot-specialist`)、`project.godot` 的
`[internationalization]` 設定、核心查找 API `Loc.localize()` 與 8 條 GdUnit4 測試
(`godot-gdscript-specialist`)、以及 E 節在 **production 本體匯出建置**上的實機量測
(`godot-specialist`,BLOCKING 項已關閉)。

**協調者獨立重跑全套測試**:`1014 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped |
0 orphans`,`Executed test suites: (82/82)`;唯一具名 ` FAILED` 是既有那條已核准的刻意紅測試。

🔴 **連帶效果已執行**:`production/epics/tactical-combat/` 的 **story-012 與 story-013 已解除封鎖**
(`Blocked` → `Ready`),兩檔的 Status 行各自加註了解除依據與原文。

⚠️ **誠實揭露**:本次沒有跑正式的 `/story-done` 逐條 AC 覆核關卡,上述是協調者依專家回報
加上自行複驗檔案與原始 log 做的驗收。
⚠️ **Steam 客戶端語言那一半不在 Story 001 範圍**,留給未來的 Steam 整合工作單,**未關閉**。

🔴 **story-002 的範圍因 Story 001 的一項發現而需要注意**:對外方法**不能**命名為 `tr`
(`Object` 原生有 `tr()`,覆寫是編譯期錯誤),本專案的查找入口是 **`Loc.localize(key)`**。
遷移既有字串時請呼叫它,不要自行再包一層叫 `tr` 的東西。
物證:`prototypes/godot-gdscript-specialist-i18n-story001-d-probe-2026-10-05/shadow_check/`
(兩份對照探針,exit 1 vs exit 0)。

## 三件實質約束各自落在哪裡(供覆核者快速核對,不重複全文)

1. **目錄先建立、locale 檔案先落地,之後才更新 `.claude/docs/directory-structure.md`** ——
   寫入 story-001 的 Acceptance Criteria(不是只寫在說明裡)。**本批派工不修改該圖檔本身**,
   依派工單明文邊界,更新它是 story-001 實作者的事。
2. **locale 代碼 `zh_TW`、CSV 只設一個繁體欄位、標頭逐字 `zh_TW`** —— 寫入 story-001 的
   Acceptance Criteria,並在 Context 節引用 `EPIC.md`「🔴 技術總監裁決:繁體中文 locale
   代碼(2026-09-30)」節作為授權依據。
3. **技術總監第五節 (c) 登記的未查證項(匯出建置上系統 locale 字串格式 + 降級後 `tr()`
   命中行為)** —— 寫成 story-001 的一條明確 Acceptance Criteria(非附註),owner 標
   `godot-specialist`、時機標「Story 001 驗收之前」,並在該 AC 旁註明:此項未關閉前,
   本 story 不得標記 Complete。

## 兩個下游解鎖關係

`production/epics/tactical-combat/story-012-tile-info-panel.md` 與
`story-013-attack-confirm-panel.md` 兩張現況皆為 `Blocked`,各自的「阻擋條件」節與
Dependencies 節逐字寫著 `localization Story 001`(已於本次派工讀檔覆核原文一致,見
兩檔第 10-22 行 / 10-13 行)。此關係寫入 **story-001 的 Context 節**與**本檔上方表格**
兩處 —— story-001 一完成、`grep -rn "tr(\|TranslationServer" src/` 由零命中轉非零命中,
下一步就是回頭把那兩張的 `Status` 從 `Blocked` 改掉(**本次派工不代為執行這一步**,
理由是那是 `tactical-combat` epic 的檔案,不在本次授權範圍內)。

## 本次派工的邊界(誠實登記,供管理者核對涵蓋範圍)

- **未涵蓋**:`EPIC.md` 本身的「Stories」表(仍寫「待切分」)、`Status` 行、「Next Step」節 ——
  本批派工判斷這些屬於 `EPIC.md` 擁有者(非本次授權明確要求)的更新範圍,**刻意不動**,
  以免與同日 `technical-director` 寫入的裁決節產生編輯衝突。若管理者希望同步這些欄位,
  需另外一次派工。
- **未涵蓋**:`production/epics/index.md` 的本 epic 狀態欄同步 —— 同上理由,未在本次派工
  的授權清單內。
- **未涵蓋**:`.claude/docs/directory-structure.md` 本身 —— 依派工單明文禁止。
- **未涵蓋**:任何 `src/` 檔案、任何 locale 實體資料檔 —— 依派工單明文禁止,三張 story
  皆只是規劃文件,不含實作產出。
- **標為「未查證」**(逐項見下):
  1. `assets/data/locales/` 目錄底下,除了 `zh_TW` 這一份之外,是否還需要放一份英文
     `en`(工程占位用,非玩家可見)—— `EPIC.md` 明文「不翻譯成任何其他語言」,但
     `internationalization/locale/fallback` 引擎預設是 `en`,兩者的交互留給 story-001
     自行決定,本次派工未替它拍板,只在 story-001 的 AC 裡指出這個決定點存在。
  2. `card_confirm_panel.gd` 的 `ARROW_GLYPH: String = " → "` 算不算入 story-002 的遷移
     範圍 —— `EPIC.md` 已標記這是「要決定的事,不是要查的數」,本次派工把決定權原樣
     轉交給 story-002 的實作者,未預先裁決。
  3. `tests/gdunit4_runner.gd` 的 `FORCED_ARGS` 是否已遞迴涵蓋 `tests/unit/` 底下任意
     深度的新子目錄 —— 本次派工未實際讀該檔案逐行確認寫法,已在 story-003 標記為
     開工前須現場查證,不得假設。
