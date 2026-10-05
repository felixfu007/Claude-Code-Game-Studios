# Story 001: 核心 key 查找 API + locale 檔案結構(骨架)

> **Epic**: 本地化(i18n)基礎設施 —— `production/epics/localization-infrastructure/EPIC.md`
> **Status**: 🟢 **核准開工**(2026-09-29 管理者裁決「Story 001~003 是否核准開工」→「准」,
> 見 `EPIC.md`「✅ 管理者裁決紀錄」表第 4 列。本檔為 2026-09-30 由 `localization-lead` 切出)
> **Layer**: Infrastructure(跨切面,非 `tactical-combat` 的 Core/Presentation 分層 —— 本 epic

> ✅ **2026-10-05:A~E 五節全部完成,本 story 標記 `Complete`。** 逐節證據:
> - **A/B/C**(`godot-specialist`):`assets/data/locales/strings.csv`(標頭 `keys,zh_TW`,2 筆真實 key)、
>   匯入器產出 `strings.zh_TW.translation`、`project.godot` 新增 `[internationalization]`
>   (`locale/fallback="zh_TW"`,非預設 `en`)。
> - **D**(`godot-gdscript-specialist`):`src/core/i18n/loc.gd`(106 行,對外 API `Loc.localize(key)`)
>   + `tests/unit/core/i18n/loc_localize_test.gd`(136 行 / 8 條)。
>   🔴 **對外方法不叫 `tr`** —— `Object` 原生有 `tr()`,覆寫是**編譯期錯誤**;物證是兩份對照探針
>   (exit 1 vs exit 0)在 `prototypes/godot-gdscript-specialist-i18n-story001-d-probe-2026-10-05/shadow_check/`。
>   dot-notation 實機驗證通過(句點不截斷),缺字時 `tr()` 原樣回傳裸 key(已由薄殼攔截)。
> - **E**(`godot-specialist`,BLOCKING 項):**在 production 本體的正式匯出建置上量測**,
>   原始 log `prototypes/godot-specialist-i18n-story001-e-formal-2026-10-05/run_output.txt`:
>   ```
>   E_SECTION_PROBE OS.get_locale() = zh_TW
>   E_SECTION_PROBE OS.get_locale_language() = zh
>   E_SECTION_PROBE TranslationServer.get_locale() = zh_TW
>   E_SECTION_PROBE Loc.localize(battle.hud.status_format) = 第 %d 回合．%s
>   ```
>   **量到的就是 `zh_TW`,故不需要在啟動期顯式呼叫 `TranslationServer.set_locale()`** ——
>   E 節那個「若不是 zh_TW 怎麼辦」的設計決定因此不必做。
>   🔴 **零畫面曝光**:`window_poll_output.txt` 逐字 `SawMainWindowHandleNonZero=False`、
>   `IterationsPolled=7`、`ExitCode=0`。
> - **協調者獨立重跑全套測試**(不是採信回報):`1014 test cases | 0 errors | 1 failures |
>   0 flaky | 0 skipped | 0 orphans`,`Executed test suites: (82/82)`,唯一具名 ` FAILED` 是既有
>   那條已核准的刻意紅測試。
>
> ⚠️ **誠實揭露:本次沒有跑正式的 `/story-done` 逐條 AC 覆核關卡。** 上述是協調者依各專家
> 回報 + 自行複驗檔案與 log 做的驗收,**不是該 skill 的產出**。
> ⚠️ **Steam 客戶端語言那一半明文不在本 story 範圍**,留給未來的 Steam 整合工作單,
> **不得視為已關閉**。
> ⚠️ **匯出時引擎印出的 ICU 警告照錄在探針 README** —— 本次中文顯示正常,但日後若匯出建置
> 中文異常,那是第一個該查的方向。
> 沒有 GDD,見 `EPIC.md` 開頭「🔴 這個 epic 沒有 GDD,也不會有」節)
> **Type**: Logic + 一項無法自動化的平台驗證(見下方 Test Evidence 節,已明文標出為何不是
> 純 Logic 型)
> **Estimate**: M(骨架 + 兩項實機驗證 + 一份匯出建置探針)
> **Manifest Version**: N/A —— 本 epic 無 GDD,故無 `docs/architecture/control-manifest.md`
> 版本可引用

## Context

**權威文件**:無 GDD。依 `EPIC.md` 開頭段落,本 epic 是跨切面基礎設施,先例為
`screen-scaling`(已 Complete)。

**Requirement**:無對應 `docs/architecture/tr-registry.yaml` 條目 —— 本 epic 服務全專案
未來所有顯示文字的系統,不對映單一 TR。

**ADR Governing Implementation**:無。依 `EPIC.md`「✅ 管理者裁決紀錄」表第 2 列,管理者
已裁決不為本地化管線寫 ADR(尚未構成跨系統契約),`ADR: N/A`。

**Engine**: Godot 4.7.1 | **Risk**: MEDIUM —— 純設定與薄殼 API 本身風險低,但牽涉兩項
「本專案從未驗證過」的引擎實機行為(dot-notation key 格式、完全不存在 key 時 `tr()` 的
預設回傳值),且有一項義務性平台驗證必須在匯出建置上執行(非編輯器)。

**為什麼這張是 gating story**:依 `EPIC.md` Q4,本 epic 的「核心 key 查找 API + locale
檔案結構」模組必須在 `tactical-combat` M5 的 story 開工(而非規劃)之前完成並可用。
`production/epics/tactical-combat/story-012-tile-info-panel.md` 與
`story-013-attack-confirm-panel.md` 兩張目前 `Status: Blocked`,各自的「阻擋條件」節
逐字寫著本 story 完成的檢查方式:`grep -rn "tr(\|TranslationServer" src/ --include=*.gd`
須由零命中轉為非零命中。**本 story 一旦驗收完成,下一步是回頭把那兩張的 `Status` 改掉**
(不在本 story 範圍內執行,屬 `tactical-combat` epic 的檔案)。

## Acceptance Criteria

### A. 目錄與檔案落地順序(不可顛倒)

- [ ] **先**建立 `assets/data/locales/` 目錄並放入至少一份真實 `zh_TW` locale 資料
      (CSV 來源檔 + 引擎匯入產生的 `.translation`,或直接手寫 `.translation`,由實作者
      判斷哪種形式更適合版控 —— 依探針 Q1 結論,CSV 匯入器名稱是 `csv_translation`,
      每個語系欄位各自產生獨立 `.translation` 檔),**之後**才更新
      `.claude/docs/directory-structure.md` 加入這個目錄的一行描述。
      **不得先改圖後建目錄** —— 該圖檔頭逐字寫著舊版教訓:「需要新目錄時先建立再畫,
      不要預先畫出『將來可能會有的』」。
- [ ] 更新 `directory-structure.md` 時**僅新增這一行**,不得動到圖中其他任何目錄的既有
      描述或檔頭稽核紀錄。
- [ ] 依 `EPIC.md`「✅ 管理者裁決紀錄」表第 1 列,目錄位置確定為 `assets/data/locales/`
      (理由沿用原提案:`assets/data/` 現有定義就是「資料驅動的設定檔」),**不是**另立
      頂層 `locales/`。

### B. locale 代碼與 CSV 結構(依技術總監裁決)

- [ ] locale 代碼採 **`zh_TW`**(`EPIC.md`「🔴 技術總監裁決:繁體中文 locale 代碼
      (2026-09-30)」節第一節裁決,授權依據為該節第二節「決定性的那一行」——
      `TranslationServer.get_locale()` 在未呼叫任何 `set_locale()` 前,於本機 Windows
      系統上直接讀回 `zh_TW`)。
- [ ] CSV(或等效來源)**只設一個繁體欄位,標頭逐字寫 `zh_TW`**(大小寫照抄)。
      **不得同時提供 `zh_Hant` 欄位** —— 技術總監裁決節第四節第 4 點明文:兩欄同時註冊時
      的勝出順序僅測過一種註冊順序,只設一欄可讓這個未查證的相依性現在咬不到。
- [ ] `.translation` 檔名/`.locale` 屬性值會逐字沿用 CSV 標頭字串(探針已實測,見
      `prototypes/godot-specialist-i18n-locale-probe-2026-09-29/README.md`「CSV 匯入行為」
      節),**不需要**另外在程式碼裡寫死 locale 字串。

### C. `project.godot` 設定(依探針 Q1 表格,已是實機驗證過的材料,本 story 負責套用)

- [ ] 設定 `internationalization/locale/translations`(型別 `Array`)指向新增的
      `.translation` 資源路徑。**探針已實測:CSV 匯入這個動作本身不會自動把產生的
      `.translation` 路徑寫進這個陣列** —— 這是額外的手動動作,必須在本 story 完成。
- [ ] **明確決定並設定 `internationalization/locale/fallback`**。探針已實測其預設值是
      `en`(非空字串),而本專案不出英文版,此預設值指向一份不存在的翻譯。
      **建議**:設為 `zh_TW` 本身,讓 fallback 落回同一份翻譯而非不存在的 `en` ——
      但具體做法由實作者判斷,**不得放著預設值不管**,這與下方 D 節「絕不顯示裸 key」
      是同一件事的兩半(`EPIC.md` Q3 原文)。

### D. Key 查找 API 與 Fallback 行為

- [ ] 決定「封裝 `tr()`」或「自建薄殼」,並記錄理由(`EPIC.md` Q1 未查證項 2 明文交由本
      story 決定)。
- [ ] 🔴 **實機驗證:`tr()` 的 key 是否可直接使用階層式 dot-notation 字串**
      (例如 `battle.hud.status_format`)作為 CSV 第一欄/查找參數 —— `EPIC.md` 標記為
      「技術上應該可行,但沒有在本專案實機驗證過」,且 2026-09-29 的探針**沒有測試這一項**
      (探針 README 逐條列出的未查證項不含此項,已由本次派工逐段核對確認)。本 AC 完成
      前不得假設它可行。
- [ ] 🔴 **實機驗證:對一個「完全不存在於任何已註冊語系」的 key 呼叫 `tr()`,預設回傳值是
      什麼**。這與「系統 locale 缺翻譯後的 fallback」是不同情境(那個情境探針已測,見
      技術總監裁決節第二節(3)的 Case A/B) —— **本次派工已逐行核對探針原始輸出
      (`grep -n "Case C|Case D|tr(test_key)" run_output_headless.txt`),確認探針的
      Case A~E 全部是「key 存在、語系不同」的情境,沒有一個是「key 本身不存在」的情境**。
      本專案只有一個語系(`zh_TW`),故這裡的「缺字」情境現實中就是「key 打錯字」,
      必須現在就定義行為,不能等多語系時才處理。
- [ ] 依上一項實機驗證結果,決定是否需要在 `tr()` 外包一層薄殼攔截裸 key 回傳
      (Godot 內建行為若證實會原樣回傳 key 字串本身,則**必須**包薄殼,不得讓玩家看到
      `battle.hud.status_format` 這種字串出現在畫面上 —— `EPIC.md` Q3 原文「絕不對玩家
      顯示裸 key」是本 epic 的硬性要求,不是建議)。
- [ ] 至少一個 key 端到端可用,可執行檢查:
      `grep -rn "tr(\|TranslationServer" src/ --include=*.gd` 由零命中轉為非零命中。
      建議先套用在 `EPIC.md` Q2 記載的既有 33 處字串其中之一,證明管線真的接得起來,
      不只是空殼(此舉與 story-002 的遷移範圍有重疊,允許提前遷移這一處作為驗證用途,
      story-002 開工時應核對這一處是否已完成,避免重複工作)。

### E. 🔴 匯出建置平台驗證(技術總監裁決第五節 (c),Story 001 驗收前必須關閉)

- [ ] **owner**: `godot-specialist`(平台/引擎行為,依 `.claude/docs/technical-preferences.md`
      副檔名/職責路由表)。
- [ ] **時機**:Story 001 驗收之前,不是之後 —— 本 story 是下游兩張 story 的解鎖前提,
      這項若留到驗收後才查,發現問題時下游已經在跑。
- [ ] **要量什麼**(逐字沿用技術總監裁決節原文,不得簡化):在**匯出建置**(不是編輯器、
      不是暫存空專案)上讀出並留 log:
      1. `OS.get_locale()` 原始字串
      2. `OS.get_locale_language()` 原始字串
      3. `TranslationServer.get_locale()` 原始字串
      4. 在該 locale 下對一個已知 key 做一次 `tr()`,確認命中的是 `zh_TW` 那份翻譯
- [ ] **證據要求**:依 `.claude/docs/technical-preferences.md`「(A) 級必須附它實際執行的
      那支檔案的路徑」與「留 log,不要只留結論」。**沒有附檔案路徑與原始 log 的結論一律
      降為 (C) 級,不得據以關閉本項,也不得據以將本 story 標記 Complete。**
- [ ] **量到的若不是 `zh_TW` 怎麼辦**:不回頭改 locale 代碼裁決(欄位名不是問題所在)。
      處置是「啟動期要不要顯式呼叫 `TranslationServer.set_locale()`」——這是本 story 的
      設計決定,技術總監裁決刻意不代為決定。
- [ ] Steam 客戶端語言與 OS locale 是兩件事,本機無 Steam 環境,**這一半留在本 story 之外**,
      由未來的 Steam 整合工作單承接 —— 不得假裝本 story 能關掉它。

## Implementation Notes

1. **擁有者分工建議**(依 `.claude/docs/technical-preferences.md` 副檔名/職責路由表):
   - `project.godot` 設定變更、CSV/`.translation` 匯入行為驗證、匯出建置平台探針(E 節)
     → `godot-specialist`
   - 核心 key 查找 API 的 GDScript 實作(薄殼或封裝) → `godot-gdscript-specialist`
   - 本 localization-lead 的角色僅止於提供 key 命名慣例、locale 檔案結構與本 story 的
     驗收條件,**不寫程式碼**(依「What This Agent Must NOT Do」)。
2. **建議檔案位置**(建議,非強制,由實作者判斷是否合適):`src/core/i18n/` ——
   `directory-structure.md` 現有 `src/core/` 定義即容納跨切面核心邏輯。
3. **2026-09-29 探針已完成的材料,可直接引用、不需重跑**(`prototypes/godot-specialist-i18n-locale-probe-2026-09-29/`):
   - `internationalization/locale/*` 全部鍵名、型別、預設值(見該探針 README「Q1」節表格)
   - CSV 匯入器行為(`csv_translation`,產出獨立 `.translation` 檔,標頭字串逐字沿用)
   - `zh_TW`/`zh_Hant` 的 `compare_locales()`/`standardize_locale()`/fallback 行為全套實測
4. **大小寫陷阱**(探針已實測,適用於任何未來需要顯式呼叫 `set_locale()` 的程式碼):
   混合大小寫的 locale 字串(例如 `zh_HANT_tw`)會被引擎砍成只剩語言碼 `zh`。若本 story
   決定在啟動期顯式呼叫 `set_locale()`,傳入字串必須是規範大小寫 `zh_TW`,不得憑印象拼寫。

## Out of Scope

- **翻譯成任何其他語言** —— `producer` 的商業決定,不在本 epic 範圍(`EPIC.md` Q3 明文)。
- **語系切換 UI/選單** —— 只有一個語系時無使用者價值。
- **RTL 支援** —— 目前無 RTL 語言在範圍內。
- **字型抽換管線** —— 對話正文字型本身尚未選定,是美術方向的未決項,不是本 epic 要解決
  的問題。
- **既有 33 處字串的實際遷移** —— story-002。
- **Fallback/缺字的回歸測試撰寫** —— story-003(但本 story D 節的「決定行為」與
  story-003 的「測試該行為」是兩件不同的事,本 story 必須先把行為定義並實作出來,
  story-003 才有東西可以測)。
- **Steam 客戶端語言整合** —— 見上方 E 節最後一條,留給未來工作單。

## QA Test Cases

⚠️ 本節由 `localization-lead` 依 `EPIC.md` Q1/Q3/Q5 與技術總監裁決節直接撰寫,非
`qa-lead` 產出 —— 本次派工的執行環境未提供 `Task` 工具,無法執行 QL-STORY-READY 覆核
關卡。建議下一次有 `Task` 工具可用時,對本節補跑一次覆核。

- **目錄建立順序可查證**
  - Given: 本 story 完成後的 git 歷史
  - When: 檢視 `assets/data/locales/` 的建立提交與 `directory-structure.md` 的修改提交
  - Then: 前者的提交時間戳/commit 順序早於或等於後者(人工複核,難以完全自動化)
- **至少一個 key 端到端可用**
  - Given: 本 story 完成的程式碼與 locale 檔案
  - When: 執行 `grep -rn "tr(\|TranslationServer" src/ --include=*.gd`
  - Then: 非零命中
- **dot-notation key 實機可用**
  - Given: 一個階層式 key(例如 `test.smoke.key`)寫入 CSV 並呼叫 `tr()`
  - Then: 正確回傳對應翻譯字串,不因句點字元而查找失敗或被截斷
- **完全不存在的 key 不顯示裸 key**
  - Given: 一個不存在於 `zh_TW` locale 資源中的 key 字串
  - When: 呼叫封裝後的查找 API(不是裸 `tr()`,除非 D 節驗證後決定裸 `tr()` 本身已安全)
  - Then: 不得回傳該 key 字串本身;回傳明確定義的替代值(例如 debug build 顯示可辨識的
    佔位標記、release build 顯示空字串或其他明確定義行為 —— 具體選擇由本 story 決定並
    記錄理由)
- **匯出建置 locale 偵測**
  - Given: 一份匯出建置(非編輯器)
  - When: 依 E 節四項逐一讀值並執行一次 `tr()` 命中驗證
  - Then: 四項數值皆留 log,且 `tr()` 命中 `zh_TW` 翻譯

## Test Evidence

**Story Type**: 本 story 不完全符合 `.claude/docs/coding-standards.md` 測試證據表的任何
單一分類 —— 明確拆成兩個部分,分別套用不同規則:

1. **管線行為部分(A~D 節)**:歸類為 **Logic**,`Required evidence`:
   `tests/unit/core/i18n/`(或實作者選定的等效路徑)下的 GdUnit4 測試,涵蓋上方 QA Test
   Cases 的前四項(不含匯出建置那一項)。**BLOCKING**,依測試證據表既有規則。
   ⚠️ headless 下確認:引擎不會投遞真實視窗事件,但 `TranslationServer`/`tr()` 屬純邏輯
   查詢,不涉及像素/輸入裝置,`--headless` 下可正常測試(與
   `Input.mouse_mode` 那類「headless 下引擎端寫入是 no-op」的陷阱不同類)。
2. **平台驗證部分(E 節)**:**不是自動化單元測試**,依 `.claude/docs/coding-standards.md`
   「What NOT to Automate」的「Platform-specific rendering (test on target hardware,
   not headlessly)」同一精神 —— locale 偵測依賴真實作業系統/Steam 環境回報值,無法
   headless 驗證。`Required evidence`:一份匯出建置探針的 log + 檔案路徑(依 E 節「證據
   要求」)。🔴 **技術總監裁決明文本項為 BLOCKING**(「這項未完成前,本 story 不得標記
   Complete」),即使它不完全符合測試證據表既有的分類形狀 —— **本 story 明確記錄這個
   偏離**:技術總監的明文裁決優先於證據表的既有分類框架。

**Status**: ✅ **已完成**(A~D 的 GdUnit4 測試 8 條全過;E 節匯出建置量測完成,原始 log 見上方完成註記)

## Dependencies

- Depends on: None(本 story 是本 epic 的第一張、gating 項)
- Unlocks:
  - story-002(既有字串遷移需要本 story 的 API 與 locale 結構先存在)
  - story-003(fallback/缺字回歸測試需要本 story 先定義並實作該行為)
  - `production/epics/tactical-combat/story-012-tile-info-panel.md`(開工前置條件,非規劃
    前置條件 —— 該檔規劃已完成,只是不得開工)
  - `production/epics/tactical-combat/story-013-attack-confirm-panel.md`(同上)
