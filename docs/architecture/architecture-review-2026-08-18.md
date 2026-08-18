# 架構審查報告 — 2026-08-18

**模式**:`/architecture-review`(完整模式) | **引擎**:Godot 4.7.1 / GDScript
**已審查 GDD**:5 份(`game-concept.md` + 4 份系統 GDD) | **已審查 ADR**:1 份(ADR-0001,Proposed)
**審查性質**:本專案第一次執行 `/architecture-review`。

從 GDD 本文擷取 116 項技術需求(TR),另從 `game-concept.md` 擷取 14 項跨系統技術需求,**合計 130 項技術需求**,對照現有的**唯一一份 ADR**(`adr-0001-tactical-query-atomicity-contract.md`,本身仍為 `Proposed` 狀態)逐項核對涵蓋情形。

---

## 涵蓋率總覽

| 狀態 | 數量 | 佔比 |
|---|---|---|
| ✅ 已涵蓋 | 5 | 4% |
| ⚠️ 部分涵蓋 | 16 | 12% |
| ❌ 缺口 | 109 | 84% |
| **合計** | **130** | **100%** |

全部 5 項 ✅ 與全部 16 項 ⚠️ 都落在 `tactical-combat-system.md`(以及 `affinity-data-pool.md` 對它的介面義務)——這是全專案唯一有 ADR 的系統,而那份 ADR 本身都還是 `Proposed`。**`affinity-data-pool.md`、`save-system.md`、`cursor-highlight-state.md` 三份文件的需求則是百分之百的缺口**——這三個 Foundation 層系統都已在設計層 Approved(分別為第十一/十二輪、第十五輪、第十六輪核准),但沒有任何一個有架構決策支撐。

---

## 依賴圖驗證

本次讀取的 5 份文件在磁碟上皆存在。`tactical-combat-system.md` 的 Dependencies 章節引用了單一游標/高亮狀態系統(存在)與好感度—位置連鎖系統 `#5`(尚未開始、無 GDD 檔案——此為預期中的現況,`systems-index.md` 已登記為 Not Started)。

---

## 追溯矩陣(依系統彙總)

| GDD | 系統 | 層級 | 需求數 | ✅ | ⚠️ | ❌ |
|---|---|---|---|---|---|---|
| tactical-combat-system.md | 戰棋移動與交戰系統 | Core | 43 | 5 | 10 | 28 |
| affinity-data-pool.md | 好感度數值池 | Foundation | 24 | 0 | 3 | 21 |
| save-system.md | 存檔系統 | Foundation | 30 | 0 | 0 | 30 |
| cursor-highlight-state.md | 單一游標/高亮狀態系統 | Foundation | 19 | 0 | 0 | 19 |
| game-concept.md | (跨系統) | — | 14 | 0 | 3 | 11 |
| **合計** | | | **130** | **5** | **16** | **109** |

全部 130 項的逐條細節(需求文字、領域、涵蓋理由)在 `docs/architecture/traceability-index.md`;供未來 story 引用的穩定 ID 在 `docs/architecture/tr-registry.yaml`。

### ✅ 已涵蓋(由 ADR-0001 涵蓋)

TR-tactical-012(跨幀攤分安全性)、-013(佔位資料擁有權)、-014(過期/版本契約)、-015(合成快照原子性)、-016(結算步不可重入閘門)。

### ⚠️ 部分涵蓋(機制已存在,但義務只兌現了一半)

TR-tactical-001、-011、-017、-018、-022、-032、-035、-036、-042、-043 · TR-affinity-007、-008、-014 · TR-concept-004、-009、-013 —— 每一項都是 ADR-0001 的版本戳記/不可重入機制提供了必要但不充分的基礎,各自仍需要一個後續決策才能真正落地。

### ❌ 涵蓋缺口(依系統分組)

**戰棋移動與交戰系統(28 項缺口)**:TR-tactical-002 至 -010、-019 至 -021、-023 至 -031、-033、-034、-037 至 -041。涵蓋範圍包括:盤面/單位/武器/地形資料 schema、路徑搜尋與視線演算法、演算法層本身的決定性、陣亡通知的恰好一次呼叫與陣營閘控、游標目標失效重驗狀態、輸入閘控的委派、全手把平權與回饋事件列舉、疊加圖合成架構與可測試性、傷害拆解顯示、預判模式零寫入保證、回合旗標重置事件模型、**回合結構全域擁有權(全專案無人認領)**、`enemy_advantage_pct` 驗證、不可通行地形層級、戰鬥內存檔狀態,以及**專案中不存在任何 AI/遭遇系統,儘管 Core Rules #9 明文要求敵方回合要消費這些查詢**。

**好感度數值池(21 項缺口)**:TR-affinity-001 至 -006、-009 至 -013、-015 至 -023。涵蓋範圍包括:Delta Log 欄位 schema 與型別化鍵值紀律、兩個獨立的全域單調計數器 + 戰役刻度標記列表、陣亡標記表、僅可附加的寫入介面表面、讀取純函數性/決定性數值規範、**權杖式序列化生命週期介面及其執行緒安全要求**、存檔系統對三份結構的無損往返 + enum 字串持久化治理、**硬性的記憶化/快取介面契約**、條件式預設查詢語意、公式四的假設性寫入契約,以及全作用域封鎖成因登記處是否該升級為執行期可查詢的 API。

**存檔系統(30 項缺口——全部需求皆為缺口)**:TR-save-001 至 -030。影響最大的幾項:**序列化格式本身仍是懸而未決的 Open Question**(卡住型別白名單、浮點往返、表示法決定論等下游決策);**寫入模型的並發策略仍是 `provisional`,且已逾越自訂的解決期限**(主機平台早已定案);分步單執行緒遷移模型 + 同槽重入鎖;對好感度數值池權杖式生命週期介面在四條終止路徑上的消費;雙讀取路徑;兩層加密雜湊鏈;涉及未經查證 Godot API 的寫入失敗偵測;耐久性邊界(無確認的 fsync 等效物);`duplicate_deep()` 確切 enum 名稱未經查證。

**單一游標/高亮狀態系統(19 項缺口——全部需求皆為缺口)**:TR-cursor-001 至 -019。涵蓋範圍包括:全域權威狀態形狀 + Autoload 擁有權;共用「表面類型」enum 的實作位置(自第四輪起懸而未決);單一實例單一標籤的註冊機制;依子類別分類裝置的規則;Input Map 驗證;`_input()` 緩衝 + 同幀排序架構;**專案層級「Agile Event Flushing」設定鎖定(引擎行為尚未驗證)**;滑鼠奪權門檻數學;焦點/暫停生命週期閘控;**已知確認的永久鎖死缺陷(已降級為建議項,但架構層面仍未解決)**;兩個目標重指派寫入介面;兩個消費端讀取介面;卸載前目標交接的生命週期契約;全域每裝置待機指示元件(無擁有者);**原生游標連續透明度漸變能力(可能在 4.7.1 不受支援,屆時須改用其他渲染載體)**;原生雙焦點 vs. 自訂高亮的分離;交接視覺延遲的量測機制。

**game-concept.md 跨系統(11 項缺口)**:TR-concept-001 至 -003、-005 至 -008、-010 至 -012、-014。涵蓋範圍包括:活棋盤地形演變的場景/資源生命週期模型(與存檔格式遷移能力、Resource 深層複製紀律綁定);裝置權威兩層機制 + Input Map 禁令(應列為專案級 forbidden pattern);初始游標落點的注入介面;好感度連線發光效果的 shader 風險(經引擎專家收窄範圍);MVP 驗收協議所需的逐回合鄰接快照遙測;空間指標量測工具;**兩項專案級 forbidden pattern 從未登記到 `docs/registry/architecture.yaml`**(禁止程序化地形生成/禁止連線功能;戰鬥結算路徑禁用 RNG)。

---

## 跨 ADR 衝突

**不可能有衝突——目前只有一份 ADR。** `docs/registry/architecture.yaml` 與 ADR-0001 內部一致(3 項狀態擁有權、2 項介面契約、3 項 API 決策、5 項禁止模式——全部歸屬正確;`systems-index.md` 宣稱的「13 項架構立場」經直接讀取查證屬實)。

### ADR 依賴順序

```
Foundation(無依賴):
  1. ADR-0001:戰棋查詢介面原子性契約(Proposed)

目前無其他 ADR。
```

無循環依賴,無未解決的 `Depends On` 參照。

---

## 引擎相容性交叉檢查

**版本一致性**:唯一一份 ADR,目標為 Godot 4.7.1,與 `VERSION.md` 一致,無過時參照。

**棄用 API 檢查**:ADR-0001 正確迴避了巢狀 Resource 的 `duplicate()`(改用 `duplicate_deep()`),也正確排除以 `PhysicsServer`/`RayCast` 實作視線。**未發現任何棄用 API 違規。**

**Post-Cutoff API 一致性**:不適用——ADR-0001 依設計宣稱零 post-cutoff API 使用,沒有第二份 ADR 可供交叉核對。

**缺少 Engine Compatibility 章節**:不適用——唯一的 ADR 本身就有這個章節,且內含一段先前 `godot-specialist` 查核的知識落差聲明,附日期。

### 引擎專家查核結果(本次 session 諮詢的 godot-specialist)

| # | 問題 | 結論 |
|---|---|---|
| 1 | 游標系統以 `InputEvent` 子類別分類裝置,是否會撞上 4.7 的裝置 ID 重新編號? | **CONFIRMED 安全**——分類邏輯從未讀取 `.device`,結構上與該項變更無交集 |
| 2 |「Agile Event Flushing」設定的原子性保證是否成立? | **LIKELY-BUT-UNVERIFIED**——設定本身確實存在,但「一幀=一個原子批次」這個具體保證需要實機計時測試才能確認 |
| 3 | `_input()` vs `_unhandled_input()`——聚焦中的 Control 是否會靜默吃掉 `ui_up`/`ui_down`? | **CONFIRMED**,`_input()` 是正確的修法 |
| 4 | `FileAccess.flush()`(存檔系統)是否有可檢查的回傳值? | **傾向沒有**——4.4 版 `store_*` 的布林回傳值清單明確不含 `flush()`,須對照實機 class reference 查證 |
| 5 | GDScript 是否有 fsync/硬體層強制落盤的等效物? | **傾向沒有**——真正的斷電耐久性可能需要 GDExtension |
| 6 | `duplicate_deep(Resource.DEEP_DUPLICATE_ALL)` 的確切 enum 成員名稱? | **UNKNOWN——明確未經確認**,須在鎖進 ADR 前對照實機 4.7.1 class reference 查證 |
| 7 | `queue_free()` 的幀尾延後移除語意 | **CONFIRMED** 在 4.7.1 未變 |
| 8 | 4.7 shader 前處理器限制收緊,是否影響本作的疊加圖 shader? | **RISK-FLAG,範圍窄**——僅在共用 `.gdshaderinc`/大量巨集的情境下才是問題,簡單的格線高亮/發光 shader 大機率不受影響 |
| 9 | 是否有其他尚未被任何文件追蹤的新風險? | **RISK-FLAG(新)**:4.6 的雙焦點系統(滑鼠/觸控焦點與鍵盤/手把焦點分離)會影響**所有**標準 Control 選單畫面,不只是本作自訂的戰棋游標——待好感度視覺呈現 UI / 戰鬥 HUD / 支援對話 UI / 教學系統(皆尚未設計)開始設計時應留意 |

---

## GDD 修訂旗標(架構 → 設計端回饋)

**無。** 沒有任何已驗證的引擎現實與某份 GDD 的假設矛盾。上方數項屬於「尚未驗證」而非「已被推翻」,已在對應的未來 ADR 中登記為 Verification Required 項目,而非修訂旗標。

---

## 架構文件涵蓋度

`docs/architecture/architecture.md` 尚不存在——這是本階段的預期現況(僅一份 ADR,尚處於架構文件之前的階段),本輪不評估。

---

## 判定:**FAIL**

**主要理由**:好感度數值池、存檔系統、單一游標/高亮狀態系統三個 Foundation 層系統,皆已在設計層 Approved(意味著全專案幾乎所有其他系統都被授權在其上建構),卻沒有任何一個有 ADR 涵蓋。`tactical-combat-system.md`(Core 層,連 Approved 都還沒)反而是唯一有架構支撐的系統,而它所依賴的 Foundation 層卻完全空白。依本 skill 自身的規則,Foundation 層需求未涵蓋一律判 FAIL,不論 ADR-0001 本身寫得多乾淨。此判定為建議性質,不強制中止——本次審查真正的價值在於下方的優先順序缺口清單。

### 阻擋項(判為 PASS 前必須解決)

1. 存檔系統的序列化格式決策(TR-save-001/002)是一個貨真價實、目前無 ADR 的架構分岔點——該 GDD 30 項需求中近三分之一下游都卡在這裡。
2. 存檔系統的寫入模型並發策略仍是 `provisional`,且已逾越自己訂下的解決期限(「待平台策略定案時」——平台策略早已定案,主機是既定目標)。
3. 沒有任何系統擁有全域回合結構(TR-tactical-034)或敵方 AI(TR-tactical-041)——兩者都被既有 Core Rules 消費,卻在 `systems-index.md` 的 14 個系統條目中無人認領。
4. 游標系統的核心原子性主張(Agile Event Flushing 的一幀一批次)尚未對照實機引擎驗證。

---

## 建議的 ADR 清單(依優先順序,Foundation 先於 Feature)

| # | 優先度 | 建議 ADR | 領域 | 引擎風險 |
|---|---|---|---|---|
| 1 | 最高 | `/architecture-decision 好感度數值池資料結構與並發契約` —— Delta Log schema、依配對索引的儲存、雙獨立單調計數器、陣亡標記表、權杖式序列化生命週期介面 + 其執行緒安全義務、記憶化契約 | 資料/並發 | 低-中 |
| 2 | 最高 | `/architecture-decision 存檔系統序列化格式與型別安全` —— 解決懸而未決的序列化格式問題,以及其型別白名單/浮點精度/表示法決定論等連鎖後果 | 持久化/引擎能力 | 高 |
| 3 | 最高 | `/architecture-decision 存檔系統原子寫入與遷移執行模型` —— 寫入模型並發策略(解決逾期的 provisional 狀態)、分步遷移 + 重入鎖、雜湊鏈、寫入失敗偵測、原子置換序列 | 持久化/並發 | 中-高 |
| 4 | 高 | `/architecture-decision 單一游標裝置權威輸入架構` —— 全域單例形狀、共用表面類型 enum 擁有權、`_input()` 緩衝架構、同幀排序、Agile Event Flushing 驗證 | 輸入/UI 架構 | 中 |
| 5 | 高 | `/architecture-decision 戰棋盤面演算法層(可達格/威脅範圍/視線)` —— 延伸 ADR-0001:有界前緣展開 Dijkstra、Bresenham 視線、N 敵成本模型、盤面/單位/武器/地形資料 schema | 效能/資料 | 低-中 |
| 6 | 中 | 小型決策(未必需要完整 ADR):指派全域回合結構的擁有者,並將 AI/遭遇系統列為第 15 個候選系統 | 架構/流程 | 低 |
| 7 | 中 | 現在就把 2 項缺失的 forbidden pattern 登記到 `docs/registry/architecture.yaml`(零成本):禁止程序化地形生成/禁止連線功能;戰鬥結算路徑禁用 RNG | 治理 | 低 |

---

## 進入下一階段前的檢查清單

| 項目 | 狀態 |
|---|---|
| `tests/unit/` 與 `tests/integration/` | ❌ 未建立 |
| `.github/workflows/tests.yml` | ❌ 未建立 |
| `design/accessibility-requirements.md` | ❌ 未建立(`cursor-highlight-state.md` 在 systems-index 跨系統義務登記表中另外欠這份文件) |
| `design/ux/interaction-patterns.md` | ❌ 未建立 |

四項皆為 ❌——不論 ADR 進度如何,`/gate-check` 之前都需要先跑 `/test-setup` 與 `/ux-design`。

---

*逐條需求細節見 `docs/architecture/traceability-index.md`;供 story 引用的穩定 TR-ID 見 `docs/architecture/tr-registry.yaml`。*
