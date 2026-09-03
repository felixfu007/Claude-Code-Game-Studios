# Story 001:共用列舉、目標值型別與策略契約

> **Epic**:單一游標/高亮狀態系統
> **Status**:Complete
> **Layer**:Core
> **Type**:Logic
> **Estimate**:S(約 3–4 小時)
> **Manifest Version**:2026-09-02
> **Last Updated**:2026-09-02

## Context

**GDD**:`design/gdd/cursor-highlight-state.md`(2026-08-13 第十六輪 Approved)
**Requirement**:TR-cursor-002
*(需求原文在 `docs/architecture/tr-registry.yaml`,審查時請當場讀最新版)*

**Governing ADR**:ADR-0005 單一游標/高亮狀態系統:裝置權威輸入架構(**Accepted** 2026-09-01)
**本 story 對應的機制**:機制二(`CursorTypes` 包裝類別)、機制三的 `CursorTarget` 值型別、機制八的 `MouseReclaimPolicy` 抽象基底

**Engine**:Godot 4.7.1 | **Risk**:HIGH
**引擎注意事項**:本系統的兩個核心領域(Input、UI)在 4.6 與 4.7 **各有一項直接相關的破壞性變更**。
🔴 **引擎判斷一律以 `docs/engine-reference/godot/breaking-changes.md` 與 `current-best-practices.md` 為準**
—— `modules/input.md` 與 `modules/ui.md` 停在 4.6,對這兩項變更**各自零命中**。

**控制清單規則(本 story 適用)**:
- **必須**:跨檔共用列舉必須包在類別裡 —— GDScript **沒有**跨檔可見的裸列舉。這是 ADR-0002 撰寫時 `godot-specialist` 查核發現的 BLOCKING 級問題,本專案已有一個查證過的先例(`AffinityTypes`),**沒有理由讓第二個系統重蹈同一個錯誤**。
- **必須**:抽象方法宣告是**裸簽章**(`@abstract func f() -> T`,無冒號無主體)。
- **禁止**:`abstract_func_with_body` —— 帶 `pass` 主體是**編譯期錯誤**,已實機驗證。
- **禁止**:`enum_value_positional_string_conversion` —— 持久化一律 `find_key(value)` / `enum[name]`,不得 `keys()[value]`。

---

## Implementation Notes

*出自 ADR-0005 機制二、機制三、機制八:*

1. **`CursorTypes`(`cursor_types.gd`)** —— 表面類型標籤的單一集中定義,包裝於 `class_name CursorTypes`。
2. **`CursorTarget` 值型別** —— 目標識別為**值型別**,需實作 `equals()` 供機制十的競態判定使用(`mark_pending_reresolve()` 靠它判斷「呼叫方以為的目標」與「系統當下的目標」是否相符)。**不含碰撞箱幾何**。
3. **`MouseReclaimPolicy` 抽象基底** —— 一個 `signal reset_triggered` + 四個 `@abstract func`,回傳型別涵蓋 `bool` / `float` / `void` / `Vector2` **四種**。
   ✅ **已實機驗證**(2026-08-20,`prototypes/engine-verification-spike-2026-08-20/`):`@abstract` 類別內**可以**同時含 `signal` 與多個 `@abstract func`;漏實作抽象方法是編譯期錯誤且訊息會指名缺哪一個。
   🔴 **但該次只測了部分回傳型別。ADR 明文要求四種各建一檔分別編譯。** 本 story 應涵蓋這一步。

🔴 **ADR 的 Key Interfaces 示意程式碼刻意只有簽章、主體從略,直接貼上是 Parse Error。**
**不要「順手加個 `pass` 讓它能編譯」** —— 那會撞上上面那條禁令。
**本專案已為「照 ADR 示意碼直接寫」付過 18 處編譯錯誤的代價。**

---

## Out of Scope

- Story 002:狀態物件本體與 Autoload 宿主
- Story 003:註冊表的行為(本 story 只出型別)
- Story 014:`MouseReclaimPolicy` 的**具體實作**(本 story 只出抽象契約)

---

## Acceptance Criteria

*以下為 `design/gdd/cursor-highlight-state.md` 的條文**原文轉錄**,未改寫:*

- **AC-53(表面類型共用列舉型別契約驗證,回應 qa-lead 審查發現——AC-47 只驗證同標籤實例基數 ≤1,未驗證每個標籤本身確實來自同一份共用列舉,見 Core Rules #7「表面類型標籤的型別契約」)**: **GIVEN** 目前系統中所有已掛載 UI 表面所使用的表面類型標籤集合,**WHEN** 檢視每個標籤的宣告來源,**THEN** 全部標籤皆為 Core Rules #7 所定義之單一共用列舉的成員,不存在任何下游系統自行發明的獨立字串或型別。**(驗證方式:程式碼審查/靜態分析——確認共用列舉的成員定義與各下游系統實際使用的標籤來源一致。)**

🔴 **AC-53 在本 story 只做得到部分涵蓋(2026-09-02 實作時登記,`/code-review` 獨立確認)**

AC-53 原文要求檢視「目前系統中**所有已掛載** UI 表面」的標籤來源。**Story 002(狀態容器)與
003(註冊表)尚未實作,系統裡沒有任何已掛載表面可檢視** —— 這一半在本 story 的時間點
**結構上不可驗**,不是省略。

**本 story 實際驗到的是**:共用列舉是單一份宣告、成員與順序與 ADR-0005 機制二完全一致
(順序也驗,因為底層 int 值會進入相等判定與未來的持久化)。

**還沒驗到的是**:下游有沒有人另開一份自己的標籤。**那要等 Story 003 有真實掛載表面才驗得到。**

⚠️ **本註記刻意寫在 story 檔而不只寫在測試檔註解裡** —— 原本只寫在
`tests/unit/cursor/shared_types_test.gd` 的檔頭,而**只讀 story 檔、不翻測試碼的人看不到**,
會誤以為 AC-53 已經完整結案。

---

*以下 3 條為**本 story 自訂**的驗收條文,編號 `AC-S001-*`,不佔用 GDD 的 AC 號碼。*
*🔴 來源為 **ADR-0005**,不是 GDD —— 每條都標了它抄自哪一節,查證時一律以 ADR 原文為準。*

- **AC-S001-a(目標值型別的相等判定)** —— *源自 ADR-0005 機制三,`CursorTarget.equals()` 的 2026-08-21 定案(R6-7)*:
  **GIVEN** 兩個 `CursorTarget` 實例,**WHEN** 兩者的 `surface` 與 `id` 皆相同、但 `is_valid` 一為 `true` 一為 `false`,**THEN** `equals()` 回傳 `true` —— `is_valid` **不參與**比較。**AND WHEN** `surface` 或 `id` 任一不同,**THEN** 回傳 `false`。
  🔴 **這條守著一個會讓整條路徑失效的陷阱**:若 `is_valid` 參與比較,機制十的 `mark_pending_reresolve()` 會**恆回 `STALE_NOT_APPLIED`**,該入口整條廢掉。

- **AC-S001-b(棋盤座標編解碼為雙射)** —— *源自 ADR-0005 機制三,`CursorTypes.encode_tile()` / `decode_tile()`*:
  **GIVEN** 任一合法棋盤座標 `Vector2i`,**WHEN** 先 `encode_tile()` 再 `decode_tile()`,**THEN** 得回完全相同的座標。**AND GIVEN** 任兩個相異的合法座標,**THEN** 兩者的編碼結果相異(不得碰撞)。

- **AC-S001-c(策略抽象契約的形狀與編譯期強制)** —— *源自 ADR-0005 機制八,含 2026-08-19 第四輪 R4-2 修訂*:
  **GIVEN** `MouseReclaimPolicy` 基底類別,**WHEN** 檢視其宣告,**THEN** 含 1 個 `signal reset_triggered(trigger: CursorTypes.ResetTrigger)` 與 **4 個** `@abstract func`(回傳型別分別為 `bool` / `float` / `void` / `Vector2`),且每一個皆為**裸簽章、無主體**。**AND WHEN** 建立一個子類別只實作其中 3 個,**THEN** 編譯期失敗,且錯誤訊息**指名缺少的是哪一個**。
  📌 這條把實作備註裡「四種回傳型別各建一檔分別編譯」從備註升格為**會被驗收的條件** —— 備註可以跳過,驗收條文不行。

---

## QA Test Cases

🔴 **本批未經 qa-lead 產生測試規格**(管理者 2026-09-02 裁決:精簡模式,覆核關卡不跑;
且本工作環境未經授權不得動用 Agent)。

> 🔴 **2026-09-03 更正:括號裡「不得動用 Agent」那半句已不成立。**
> 管理者於 2026-09-03 開工時明文授權派工,同日稍後再次確認「由你負責派工與監督」。
> 原文保留供追溯,**但不要照它跳過覆核** —— Story 004 正是在這句話仍寫在檔案裡的當天,
> 實際跑完了引擎覆核與測試涵蓋覆核兩關。前半句(qa-lead 精簡模式)是否仍適用,
> 依當次派工指示為準,不由本檔決定。

**替代做法**:上方驗收標準**本身就寫成 GIVEN / WHEN / THEN 形式**,直接作為測試規格使用。
這不是省略 —— 該 GDD 的 AC 是 qa-lead 於 2026-08-03 諮詢草擬、並經十六輪審查修訂的成果,
明文要求「所有標準以可觀測不變式書寫,避免『感覺清楚』等無法驗證的措辭」。

⚠️ **但有一項它不能替代**:AC 沒有列邊界值與失敗態。實作時若發現某條 AC 的邊界不明確,
**停下來問,不要自己選一個** —— 本專案已有「假設錯誤的腳本順利跑完、輸出漂亮數字」的前例。

---

## 效能影響

**無效能影響預期** —— 本 story 只產出型別宣告與純函式編解碼,不在任何逐幀路徑上。

⚠️ **一個要記著的連帶**:`CursorTarget.equals()` 會被機制十的每幀競態判定呼叫,`CursorTypes.encode_tile()` / `decode_tile()` 亦可能落在每幀路徑。兩者現行皆為 O(1)(兩欄位比較 / 一次算術)。**若日後任一變得非 O(1),須回頭重估本節。**

*本系統效能宣稱的權威來源為 ADR-0005 `Performance Implications` 節,本節不複述其內容。*

---

## Test Evidence

**Story Type**:Logic
**必要證據**:`tests/unit/cursor/shared_types_test.gd`

**Status**:[x] 已建立(2026-09-02)—— `tests/unit/cursor/shared_types_test.gd`,8 條測試全過。

**驗證方式**:主 session 自行重跑全庫測試,不採信 subagent 回報。
`Overall Summary: 249 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans`,
引擎實際 exit code **100** —— 唯一失敗是既有的**故意紅**測試
(`affinity_phi_provider_test.gd`),與本 story 無關。本 story 8 條 **0 failures / 0 orphans**。

---

## Dependencies

- **Depends on**:無
- **Unlocks**:002, 003, 004, 006, 014

---

## Completion Notes

**Completed**:2026-09-02
**Verdict**:COMPLETE WITH NOTES

**Criteria**:4/4 —— 其中 **AC-53 為部分涵蓋**(共用列舉本身已驗;「下游有無另開一份」
結構上要等 Story 003 有真實掛載表面才驗得到,理由見上方 Acceptance Criteria 節的登記)。
其餘三條(AC-S001-a/b/c)完整涵蓋。**零 UNTESTED。**

**Test Evidence**:`tests/unit/cursor/shared_types_test.gd`,8 條。
AC-S001-c 的負面半段(漏實作一個方法會編譯失敗)由外部探針驗證,
`prototypes/story-001-abstract-probe-2026-09-02/scripts/real-type-verification/`。
🔴 **第二輪探針用的是專案正式的 `MouseReclaimPolicy`,不是替身型別** —— 第一輪用 `int` 佔位,
被 `/code-review` 判定不符本專案 (A) 級量測的定義(「執行了專案的程式碼,還是重新實作了一份」),
已重跑。log 的錯誤訊息逐字指名 `MouseReclaimPolicy.diagnostic_seed_position()`。

**Code Review**:Complete(`/code-review` 2026-09-02)。
三方平行覆核:`godot-gdscript-specialist`(程式品質)、`godot-specialist`(ADR 合規)、
`qa-tester`(測試涵蓋)。**架構層零違規、零偏移;測試無假通過。**
判定 CHANGES REQUIRED,**五項發現全數修畢後才結案**。

**驗證方式**:主 session 自行重跑全庫測試,不採信 subagent 回報 ——
`249 test cases | 0 errors | 1 failures | 0 orphans`,引擎實際 exit code 100
(唯一失敗為既有的故意紅測試,與本 story 無關)。

### Deviations(兩項 ADVISORY,皆已登記至 `docs/tech-debt-register.md`)

1. **`assert()` 前置條件防呆在正式發行版建置會被移除** —— 本機無匯出範本,
   **此點未經實測驗證,登記為待查證而非既定事實**。
2. **AC-53 的下游檢查待 Story 003** —— 見上方登記。

### 一項曾被誤判為偏離、實際不是的事(留痕以免下一個人改錯方向)

`encode_tile()` / `decode_tile()` 的**兩參數**簽章一度被記為「刻意偏離 ADR」。
**那個判斷是錯的**:ADR-0005 的 `Key Interfaces` 節(明文「本 ADR 定案的契約形狀」)
本身寫的就是兩參數,單參數只出現在機制三一句較早的說明性文字。
🔴 **程式碼註解原本寫著「deliberate deviation」,會誘導後人改回單參數 —— 那才會真的違約。**
該註解已於 `/code-review` 後修正。

### 範圍外但同批處理的獨立變更(非 Story 001 內容)

`src/ui/battle/device_authority.gd` 與其測試:平手裁決由「滑鼠優先」改為「方向鍵/手把優先」,
執行 2026-09-02 管理者裁決(推翻 `active.md` 第十七批的平手條款)。
**與 Story 001 無關**,是本日派工時查既有程式碼撞見的矛盾,已另行提交。
