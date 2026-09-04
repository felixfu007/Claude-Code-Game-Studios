# Story 010:專屬游標 `CanvasLayer` + 圖層變換恆等防護測試

> **Epic**:單一游標/高亮狀態系統
> **Status**:Complete(2026-09-04,實作 `godot-specialist` / 覆核協調者,含補做的靈敏度量測)
> **Layer**:Core
> **Type**:UI
> **Estimate**:S(約 2–3 小時)
> **Manifest Version**:2026-09-03
> **Last Updated**:[由 /dev-story 於實作開始時設定]

## 🔴 本張已於 2026-09-03 依管理者裁決重寫 —— 原標題與原範圍已不成立

**原標題**:「全域待機指示宿主 + 專屬 CanvasLayer」。
**管理者裁決取消了「全域每裝置待機指示」需求(TR-cursor-016)**,裁決原文與查證依據見
`production/session-state/active.md` 第三十二批第一節。

🔴 **那層 `CanvasLayer` 不會跟著消失,但它的存在理由換人了**:
它原本是為待機指示建立的,而**機制十三的自繪替代游標節點掛在同一層**,Story 011 需要它。
**圖層留下,待機指示移除。**

⚠️ **連帶後果(誠實記錄)**:ADR 原本論證「既然這層 `CanvasLayer` 已經因為待機指示存在了,
自繪載體的**邊際成本接近零**」。需求取消後,**這層圖層的成本不再是邊際的,現在完全由自繪載體承擔。**
📌 **該論證改寫後「不等驗證結果直接選自繪載體」的決策是否仍成立,以 ADR-0005 機制十三該段的現行文字為準,本工作單不複述** —— 手抄的結論必然漂移,本專案 2026-09-01 稽核抓到過同一個數字在四個檔案有三個並存的值。

---

## Context

**GDD**:`design/gdd/cursor-highlight-state.md`(2026-08-13 第十六輪 Approved,2026-09-03 依管理者裁決做範圍縮減)
**Requirement**:🔴 **不再是 TR-cursor-016(已退役)。** 本張現在服務的是機制十三的載體需求。
**Governing ADR**:ADR-0005(**Accepted** 2026-09-01,2026-09-03 第六次修訂)
**本 story 對應的機制**:機制十二(Autoload 持有的全域 `CanvasLayer`,待機指示移除後只剩宿主職能)

**Engine**:Godot 4.7.1 | **Risk**:HIGH

**控制清單規則(本 story 適用)**:
- 🔴 **必須**:**游標圖層獨佔一顆 `CanvasLayer`**,不得與介面圖層共用。

---

## 🔴 本 story 綁定一條隨 ADR 核准生效的硬性義務(未受裁決影響,原樣保留)

**「游標圖層 transform 恆等」必須寫成一條會執行的自動化測試**(ADR-0005 Validation Criteria #20),
**不得只靠紀律。**

**理由是實測數字**:誤把游標圖層與介面圖層混成同一顆節點時,偏差為
1080p **1440 px** / 2K **2178 px** / 4K **3304 px** —— **不是歪一點,是游標系統實質失效。**

✅ 已實測:專屬節點下四種解析度(1080p / 2K / 4K / 超寬)**全部恆等**;
該 Autoload 掛 `/root`、不在 `SubViewport` 內,四種解析度 `get_viewport() == get_tree().root` 皆為真。
證據:`prototypes/ui-canvas-scale-spike-2026-09-01/`

**這條測試沒過,本 story 不得結案。**

⚠️ **這條測試是本張存在的主要價值。** 待機指示移除後,若把剩下的圖層併進 Story 011,
這條防護測試會變成附屬品 —— 協調者判定維持獨立工作單,理由記於此。

---

## Implementation Notes

1. **`CursorStateHost` 持有一顆專屬 `CanvasLayer`。** `CursorStateHost` 是本專案唯一生命週期跨所有畫面的實體。
2. 🔴 **必須是獨佔的節點,不得與介面圖層或其他用途共用。** 除了上方的變換恆等理由外,
   `modulate.a` 是**逐節點**屬性 —— 機制十三會在 `_process()` 末尾寫 `modulate.a = _presented_alpha`,
   共用節點會讓那一行波及不該被淡出的東西。
3. **`CanvasLayer.layer`(繪製疊放順序)與 `process_priority`(更新順序)是兩個獨立概念**,
   ADR 明文要求不得混用同一組數值。
4. **本張不畫任何東西。** 自繪游標本體屬 Story 011。本張交付的是宿主節點與那條防護測試。

---

## Out of Scope

- Story 011:自繪游標本體、原生指標隱藏、白名單例外
- **待機指示元件** —— 🔴 **已由管理者裁決取消,不是延後,是不做。**

---

## Acceptance Criteria

🔴 **原本的 AC-27 / AC-55 已隨管理者裁決退役**,不再是本張的驗收標準。
以下 2 條編號 `AC-S010-*`,不佔用 GDD 的 AC 號碼。

- **AC-S010-a(圖層變換恆等)** —— *源自 ADR-0005 Validation Criteria #20*:
  **GIVEN** 游標圖層已建立,**WHEN** 在 1080p / 2K / 4K / 超寬四種解析度下讀取該 `CanvasLayer`
  的變換矩陣,**THEN** 四者皆為恆等變換。
  🔴 **失敗長相是游標畫在離滑鼠一千多到三千多像素外的地方** —— 不是歪一點,是系統實質失效。

- **AC-S010-b(獨佔性)** —— *源自控制清單的硬性規則*:
  **GIVEN** 游標圖層節點,**WHEN** 檢視其子節點與用途,**THEN** 它只承載游標系統自己的內容,
  不與任何介面圖層共用。

⚠️ **邊界值未定義處請停下來問,不要自己選一個。**
特別是:AC-S010-a 的「四種解析度」在 headless 測試環境下如何模擬,若做不到,
**如實登記為未涵蓋,不要用一個測得到但驗不到東西的替代寫法** —— 本專案已有三次同形失效
(Story 003 AC-51、Story 007 AC-32、Story 012 全案)。

---

## Test Evidence

**Story Type**:UI
**必要證據**:`production/qa/evidence/cursor-canvas-layer-evidence.md`
**Status**:[x] 已建立 —— `tests/unit/cursor/cursor_layer_transform_test.gd`(11 條、0 失敗、0 orphans);證據文件 `production/qa/evidence/cursor-canvas-layer-evidence.md`

---

## Dependencies

- **Depends on**:002
- **Unlocks**:011

---

## 結案紀錄(2026-09-04)

**交付**:`CursorStateHost` 持有的專屬 `CanvasLayer`(`_cursor_layer`,名稱 `CursorLayer`)+ 11 條自動化測試。
**測試**:全專案 345 → **356** 條,0 errors / 0 orphans / 27 suites,唯一失敗為既有已核准的 `affinity_phi_provider` 紅燈。

### 逐條驗收

| AC | 判定 |
|---|---|
| **AC-S010-a**(圖層變換恆等) | ✅ **完整涵蓋** —— 四種解析度對**正式圖層**斷言,且四條逐條實測在注入破壞時會紅 |
| **AC-S010-b**(獨佔性) | ⚠️ **部分涵蓋(刻意收窄)** —— 已驗:獨立節點、直掛宿主、目前零子節點、繪製順序值與更新順序值不相等。未驗:「永遠只承載游標系統內容」這個完整宣稱,**要等 Story 011 有真的子節點才驗得到** |

### 🔴 覆核補做的一件事(不是實作者的疏漏,是工具行為造成的)

實作者的靈敏度證明**只證明了 11 條裡的 1 條**。成因是 GdUnit4 **一條失敗就中止同 suite 其餘測試**
(`coding-standards.md` 已記載),他那次注入跑只執行到第 2 條就停了,而扛 AC-S010-a 的是第 3~6 條。

「注入之後測試紅了」**字面為真,但會讓讀者以為 AC 那四條驗過了**。協調者覆核時逐條重做,
四條全部**觀測到**紅燈而非推論。逐項數字與方法在證據文件的 Sensitivity proof 節。

📌 **通則(已寫進證據文件)**:一次注入紅燈,只能證明「跑到第一個失敗為止」那些測試的靈敏度。
**要證明一支測試檔每條都有靈敏度,需要一條一次。**

### 兩項判斷已由管理者裁決(2026-09-04)

1. **headless 測試取代 ADR 敘述的「有視窗整合測試」** —— ✅ **接受**,但**「真的開視窗看畫面」的義務已落到 Story 011**(該張已寫入,見其 Test Evidence 前一節)。
2. **`CURSOR_LAYER_DRAW_ORDER = 100`** —— ✅ **維持現狀,不寫進 ADR-0005**。程式碼內已明文標註為「實作時自行判斷、非架構規定」,後人分得出來即可。

### 覆核時另外撞到的一個假綠燈陷阱(已寫入 `coding-standards.md`)

GdUnit4 的 `-a 檔案:測試名` 篩選寫法**不支援**;字串打錯時它印 `No test cases found, abort test run!`
然後回報 **exit code 0**。亦即**篩選打錯 = 零測試執行 = CI 判定通過**。
目前 CI 未使用篩選功能,不受影響。
