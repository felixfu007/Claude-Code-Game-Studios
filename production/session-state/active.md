# Active Session State

<!-- STATUS -->
Epic: 架構階段(Foundation 層 ADR 系列)
Feature: 好感度數值池 + 存檔系統
Task: ADR-0002/0003/0004 已撰寫、registry 已更新;**尚未 commit**;下一步待裁示(見下方待處理清單)
<!-- /STATUS -->

**最後更新**:2026-08-18 —— `/architecture-decision`(ADR-0002、ADR-0003、ADR-0004,同一 session 連續撰寫)

## Session Extract — /architecture-decision 2026-08-18(ADR-0002~0004)

**本 session 的工作已於整理進度後 commit 並推送**(commit 訊息見 `git log`)——但本檔案先前段落(第四輪 `/design-review` 那節)記載的「已 commit、工作區乾淨」屬**當時**狀態,不保證任何後續時點仍成立;下一位接手者(或新 session)一律應先實跑 `git status` 確認,不可從任何文件敘述推斷工作區狀態。

- **ADR-0002「好感度數值池資料結構與並發契約」**(新增檔案):per-pair 索引 `Dictionary[AffinityTypes.Pair, Array[AffinityRecord]]`、獨立戰役刻度標記列表/陣亡標記表、單調遞增 int 權杖 + 無條件 Mutex 保護的序列化生命週期、依賴注入擁有模式(非 Autoload)。覆蓋 `affinity-data-pool.md` 全部 24 項 `TR-affinity-*`。經 `godot-specialist` 驗證修訂(共用列舉需集中包裝於 `AffinityTypes` 才能跨檔編譯,原始草稿的裸列舉會編譯失敗)。
- **ADR-0003「存檔系統序列化格式與型別安全」**(新增檔案):選定 `var_to_bytes()`/`bytes_to_var(bytes, false)` 二進位 Variant 序列化(取代 Resource/.tres 與 JSON),理由是型別白名單問題在引擎層級結構性消除。逐區塊獨立 `PackedByteArray` 緩衝區的 manifest 分層結構、雙層 SHA-256 雜湊鏈、`SaveBlockRegistry` 驗證器登記表(依賴注入)。**回填修訂 ADR-0002**:新增 `AffinityDataPool.validate_semantics()` 純函式,`import_state()` 內部改為呼叫它。經 `godot-specialist` 驗證修訂 2 項 BLOCKING(誤植不存在的 `get_var(true,false)` 雙參數形式、誤植不存在的「記憶體內 FileAccess」路徑,皆已改為 `var_to_bytes()`/`bytes_to_var()`)。
- **ADR-0004「存檔系統原子寫入與遷移執行模型」**(新增檔案):可替換 `SaveIOBackend` 抽象(現行實作同步阻塞,因主機平台 SDK 細節未知、無法驗證是否需要非同步——維持 GDD 現行決定但包一層可替換邊界)、Core Rules #14 六步驟原子置換序列(含 Step 0 分支邏輯)、`await scene_tree.process_frame` 跨幀讓出的分步遷移狀態機(沿用 ADR-0001 已驗證的宿主生命週期約束)、單一進入/單一釋放的逐槽重入鎖結構(GDScript 無 try/finally 下唯一能保證無條件釋放的方法)、序列化生命週期權杖消費(4 條終止路徑,3 條結構性保證、1 條 GDD 自陳殘留風險)。經 `godot-specialist` 驗證修訂 2 項 BLOCKING(誤引 ADR-0002/0003 為 `@abstract` 先例——全專案實際從未用過;機制一程式碼區塊的 `@abstract` 語法與專案唯一已查證範例互斥,已改為安全形式)。**`TR-save-*` 系列至此全部 30 項需求皆有 ADR 覆蓋。**

**Registry 更新**(`docs/registry/architecture.yaml`):三份 ADR 合計新增 7 項 state_ownership、6 項 interfaces(累計)、15 項 api_decisions(累計)、10 項 forbidden_patterns(累計)——逐項來源見各 ADR 自身的 GDD Requirements Addressed 與本次 registry diff。所有新增皆已依 skill 流程逐項向使用者確認後才寫入。

**跨檔同步(本 session 一併完成,回應本專案最昂貴的「一處改、他處未同步」失敗模式)**:
- `.claude/docs/technical-preferences.md` Architecture Decisions Log:新增 ADR-0002/0003/0004 三條,並加註 registry 累計 38 項、全部 4 份皆 `Proposed` 尚無 `Accepted`。
- `docs/architecture/traceability-index.md`:**刻意不逐列改寫 54 個涵蓋標記**——涵蓋判定須由獨立於撰寫脈絡的 `/architecture-review` 重新推導。改為在涵蓋率總覽加註過期聲明(明列三份 ADR 各自宣稱涵蓋的 TR-ID 範圍,並標明「這是 ADR 自身的宣稱,不是已驗證的涵蓋結論」)、缺口清單第 1–3 項標記為已撰寫、存檔系統節標題移除已成假的「全部需求皆為缺口」字樣。
- `design/gdd/systems-index.md`:標頭新增本輪 ADR 系列記載;Cross-System Obligations Registry「序列化生命週期通知介面」列移除已成假的「序列化格式仍是 Open Question」宣稱(ADR-0003 已定案);Progress Tracker 新增 4 列 ADR 指標。

**待處理清單**:
1. **`/architecture-review` 必須在全新 session 執行**——本 session(撰寫 ADR 的同一 session)不得自行驗證,審查代理須獨立於撰寫脈絡。這也是 `traceability-index.md` 逐列標記唯一的正當更新途徑。
2. **ADR 缺口清單剩餘 3 項尚未動筆**:第 4(單一游標裝置權威輸入架構,`TR-cursor-001~019`)、5(戰棋盤面演算法層,`TR-tactical-002~010` 等)、6(回合結構擁有權 + 缺席的 AI/遭遇系統,`TR-tactical-034/-041`)。
3. **全部 4 份 ADR 皆為 `Proposed`,無一 `Accepted`**——依 `docs/CLAUDE.md`「Never skip `Accepted` — stories referencing a `Proposed` ADR are auto-blocked」,目前尚無任何 ADR 可支撐 story 實作。`Accepted` 的前置條件與裁決者本專案文件未明訂,需使用者裁示。
4. ADR-0004 機制七「路徑二(維運層級重跑)」的具體觸發機制/程序仍留給 `/create-architecture` 或維運工具鏈決定,本 ADR 只保證資料前提成立——非本次遺漏,是 GDD 自身的既有裁決。
5. 多項 Engine Compatibility Verification Required 項目(`@abstract` 語法、`DirAccess.rename()` 平台行為、`FileAccess.flush()` 可檢查性、`OS.get_thread_caller_id()`/`get_main_thread_id()` API 名稱)皆待 `/create-architecture` 階段取得 Godot 執行環境後實機驗證——本 session 全程無 Godot 執行環境可用,所有引擎層級判斷皆為 `godot-specialist` 訓練資料推測 + 對照 `docs/engine-reference/godot/` 既有文件,已在各 ADR 的 Engine Compatibility 表逐項標註信心等級。

---

**本 session 全部工作已 commit,工作區乾淨。** 三個 commit:
- `d5a482f` 第四輪修訂(6 項 BLOCKING-NOW + 2 補項)
- `08bf6ff` ADR-0001 + registry + GDD 指標回填
- `8dd25af` 修正 `technical-preferences.md` 的 stale「[No ADRs yet]」宣稱

---

## 一、第四輪 `/design-review`(完整模式)

7 位專家平行(`game-designer`、`systems-designer`、`qa-lead`、`ux-designer`、`gameplay-programmer`、`performance-analyst`、`godot-specialist`)+ `creative-director` 資深綜整。依 Phase 0b 升級門檻升級為完整模式。

判定 **NEEDS REVISION**:原始 15 項發現,去重後 **6 項 BLOCKING-NOW 全為設計內容缺陷** + 2 項低成本補項 + 3 項 DEFER + 3 項 ADVISORY(含 2 項由專家原評 BLOCKING 降級),**全部同輪修訂落地**。

### 去重是本輪最有價值的一步

四位專家從四個不同角度撞到的是**同一根樑** —— 文件從未回答「盤面權威狀態何時才准改變、一次改變的單位是什麼」:
- `game-designer`:#10(a) 只約束「若重繪則正確」卻明文不定案重繪時機 → 渲染一次永不失效的實作完全合規,卻重現規則要防的失敗模式
- `gameplay-programmer`:#5 宣稱結算步不可中斷卻無任何重入防護,而②c 呼叫的是尚未設計的 #6
- `systems-designer`:#10(c) 的 `occupied` 同步時點只錨定陣亡,AC-22 卻已在測試移動同步 → AC 層憑空發明規範
- `ux-designer`:陣亡淡出與同結算步佔位釋放在同格衝突

→ 以**新增 Core Rules #11「結算步的不可重入邊界」**一次解決,而非補四條個案條款。

### 六項 BLOCKING-NOW

| # | 缺陷 | 修法 |
|---|---|---|
| B-1 | 盤面異動邊界模型缺席(上述四徵狀) | **新增 Core Rules #11**;#10(a) 補最低限度過期標記義務;#10(c) 改原則陳述;**新增 AC-24** |
| B-2 | #10(b) 原子性綁在「一次查詢」,未定義合成查詢的原子單位(橫向並存疊加圖 + 縱向多敵聯集皆破) | #10(b) 補「合併判讀的一組輸出視為同一次查詢、共用同一份快照」+ AC-22 兩向量 |
| B-3 | #6a 無陣營限定,字面要求**每次擊殺敵人**都對 `affinity-data-pool.md` 陣亡通知傳入域外識別碼(該文件鍵域明文為「5 名固定主角之一」,已實查);且 6a 無失敗處理而 6c 無條件執行 | 收斂為僅我方陣亡呼叫;比照 6b 補失敗偵測/重試義務 |
| B-4 | ②b 宣稱「語意與 Core Rules #8 相同」是事實錯誤(輸入集嚴格更大),邀請複用 #8 介面 → 會使②b 重新查詢 `Φ`,正是前三輪堵住的危害換角度復發 | 新增「關係說明」;AC-6 THEN + 新增向量 |
| B-5 | 同一規範性斷言逐字重述於 AC-11/AC-20/AC-22(a) 三處,命中本專案明文列為最昂貴的招牌失敗模式 | AC-11/AC-20 收斂為指標引用 |
| B-6 | 公式四以「寧可高估、絕不低估」正當化省略視線檢查,但佔位軸上確實低估且未揭露 | 新增「保守性的邊界」+ 呈現/教學層揭露義務 |

補項:AC-9 擴充涵蓋公式三/四;武器分層結構不變量升級為 **AC-23**(Logic/BLOCKING)。
降級登記:**新增 OQ-21**;OQ-4/13/16 擴充。

### 結構性診斷(`creative-director`)—— 改變了策略方向

本輪 15 項原始發現中,落在文件**原生設計**(Core Rules #1–#4/#7/#8、公式一至三、AC-1 至 AC-19)的數量為 **0** —— 連續四輪未再產生任何發現;100% 落在第二至四輪由審查自己新增的治理層材料(公式四、UI §1/§1a、Core Rules #10、AC-20/21/22)。

診斷:**設計已收斂,未收斂的是治理層錯置**。第三輪的 Core Rules #10 是反應式通則,把症狀一般化(「查詢輸出要正確」)而非成因一般化(「盤面何時允許改變」),故必須反覆聲明自己不管什麼。**使用者裁決:採選項 B**(內容修法 + 契約外移至 ADR)。

### 專家分歧(`creative-director` 與專家,已裁決)

- `ux-designer` F4-A → 降為 **OQ-21**(§6 原則陳述已涵蓋兩分支,不產生錯誤實作)。但其抓到的流程失誤屬實:此項第二輪已列 DEFER 卻從未登記,消失整整一輪。
- `game-designer` 自評 DEFER 的威脅範圍低估 → **升為 BLOCKING**(自我否定,非精確度問題)。
- `performance-analyst` F4-PERF-1 → 降為 **OQ-16 擴寫**(穩態成本疑慮已由 B-1 的結算邊界模型解答)。
- `godot-specialist` **零 BLOCKING** —— 四個引擎面查核角度全數通過 4.7.1 核對。

---

## 二、ADR-0001「戰棋查詢介面原子性契約」(專案首份 ADR)

`docs/architecture/adr-0001-tactical-query-atomicity-contract.md`,狀態 **Proposed**。

**核心決策**:以單調遞增的 `board_version` 版本戳記作為快照身分,**取代深拷貝盤面**。關鍵洞見:Core Rules #11 已把所有盤面異動限制在已提交的結算邊界、且結算不可重入,故盤面在**兩個邊界之間實質不可變** —— 快照只需要身分識別,不需要拷貝。成本從每次查詢深拷貝降到一次 int 比較(對「游標即檢視」高頻路徑很關鍵),且**版本相等同時實現過期偵測、合成一致性、跨幀原子性三件事**,三條義務共用一個機制而非三套獨立失效邏輯。

另兩項使用者裁決:`settlement_in_progress` 閘門採**拒絕式**(非佇列 —— 延遲生效的意外與可預判性支柱衝突);佔位採**稀疏 `Dictionary[Vector2i, int]`**(不需預先定案棋盤尺寸上限,該上限仍未決)。

**`godot-specialist` 驗證零 BLOCKING**,「Post-Cutoff APIs Used: 無」宣稱經核對成立。5 項 minor notes 全數納入,最有價值的一項是**比原本要防的失效更嚴重的模式**:旗標的防禦推理隱含假設「意外的 `await` 終將恢復」;若永不恢復,`settlement_in_progress` 永停在 `true`,後果是**整場戰鬥輸入永久鎖死且無錯誤訊息**。已加 `push_error` 偵測斷言。另納入:跨幀協程宿主生命週期約束(`is_instance_valid` 防衛)、禁止 `call_deferred`/`CONNECT_DEFERRED` 介入結算路徑(搜尋 `await` 字樣抓不到)、禁止回傳 board 內部結構參照(版本戳記結構上無法防禦的旁路)、禁止依賴 Dictionary 迭代順序。

**Registry**:`docs/registry/architecture.yaml` 首次填入 —— 13 項立場(state_ownership 3、interfaces 2、api_decisions 3、forbidden_patterns 5)。

**單向修訂方向(已明訂於 ADR 與 GDD 標頭)**:GDD 的義務變更須回頭檢查 ADR 是否仍能滿足;**ADR 的機制變更不得擴大或縮小 GDD 的義務範圍**。

---

## 三、自核抓到的兩項自身失誤(已修)

1. 新增 AC-23/AC-24 章節時,誤將 AC-22 的「測試撰寫提醒」隔到兩節之後(該段以「本 AC」指稱 AC-22)—— 已移回 AC-22 節內。
2. ADR 已 commit 後,`technical-preferences.md` 仍宣稱「[No ADRs yet]」—— 已修正並 grep 全庫確認無其他同類殘留(剩餘命中皆為 skill 範本文字,非專案狀態宣稱)。

---

## 四、現況

| 項目 | 狀態 |
|---|---|
| `tactical-combat-system.md` | **Designed,尚未 Approved**。不得移交 `/create-architecture` |
| **收斂狀態(Phase 0b)** | 連續零 BLOCKING-NOW 輪數 = **0**(第一輪 6、第二輪 5、第三輪 7、第四輪 6;**四輪皆 body-scoped**)。距 APPROVED 尚需**連續兩輪**零 BLOCKING-NOW |
| ADR-0001 | **Proposed**(尚未 Accepted) |
| 目前無待清償 BLOCKING | 是 —— 六項全於同輪修訂落地。但依 Phase 0b 收斂規則仍不得判 Approved |

---

## 五、下一步(兩件都**必須**在全新 session)

1. **第五輪 `/design-review design/gdd/tactical-combat-system.md`** —— 本 session 脈絡已很長(9 個 agent)。
   **驗證判準(`creative-director` 提供,比單純數 BLOCKING 數量更有用)**:若新發現仍落在查詢介面義務/AC 治理層,代表治理層外移**沒有真正解決問題**;若落在 Core Rules #1–#9 或公式一至三,才是設計本身還有問題。
2. **`/architecture-review`** 驗證 ADR-0001 對 GDD 需求的涵蓋 —— **這是硬性規定**:審查代理必須獨立於撰寫脈絡,與 `/architecture-decision` 同 session 執行會使審查結果無效。

---

## 六、待處理清單

### 已知 stale,尚未修正(本次記錄進度時發現,待裁示)

- **`systems-index.md` Systems Enumeration 第 4 列**:狀態仍寫「Designed(…**尚未經 `/design-review`**)」—— **已跑完四輪,此宣稱為假**。
- **`systems-index.md` Progress Tracker**:`Design docs reviewed: 3` 未計入戰棋移動與交戰系統(依該指標自身定義「已經歷至少一輪 `/design-review`」應為 4)。`Design docs approved: 3` 仍正確,但其定義寫的是「目前無待清償 Blocking」,而戰棋系統目前確實無待清償 Blocking、卻因收斂規則不得判 Approved —— 定義與 Status 欄會在此處分歧,需明文註記而非默默選一邊。
- `systems-index.md` 標頭 `Last Updated` 為 2026-08-09,未反映後續四輪。

### 文件自陳的下游阻擋項

- **OQ-2** `player_baseline_stat` 全專案無擁有者;**OQ-10** 無「不可通行」地形層級 —— 須在 `/create-architecture` 前指派/裁決。
- **OQ-16 新增兩項**:敵方單位數上限全專案無擁有者;效能測試須以「格數 × 敵數」兩軸參數化。

### 本輪 DEFER 尚未落地

- `enemy_advantage_pct < 0` 無驗證拒絕(與既有 `≥1.0` 拒絕不對稱,會靜默反轉 Core Rules #7)。
- 公式二 `ceil()` 浮點精度邊界噪聲。

### 其他

- `systems-index.md` 標頭部分歷史段落仍有行號式自我引用,與 `.claude/rules/design-docs.md` 的「禁止行號自我引用」規則相衝。
- ADR-0001 的 Verification Required 有 6 項待實機確認(含 `queue_free()` 幀尾語意、型別化 Dictionary 編譯、同幀可見性順序保證)。

---

## Session Extract — /architecture-review 2026-08-18

- **Verdict**: FAIL — advisory, not a hard stop. 3 Foundation-layer GDDs (好感度數值池、存檔系統、單一游標/高亮狀態系統), all Approved at design layer, have **zero** ADR coverage each.
- **Requirements**: 130 total(戰棋 43、好感度 24、存檔 30、游標 19、game-concept.md 跨系統 14) — 5 covered、16 partial、109 gaps。
- **New TR-IDs registered**: 130(`docs/architecture/tr-registry.yaml` 首次填入實際條目,此前為空)。
- **GDD revision flags**: None — no verified engine reality contradicts a GDD assumption(數項為「未驗證」而非「已推翻」,見下方待查證清單)。
- **Top ADR gaps**(依 Foundation-before-Feature 排序,完整清單見報告):
  1. 好感度數值池資料結構與並發契約(24 項需求零覆蓋,含專案唯一已宣告的執行緒安全義務)
  2. 存檔系統序列化格式與型別安全(格式本身仍是 Open Question,下游近 1/3 需求卡在此處)
  3. 存檔系統原子寫入與遷移執行模型(寫入並發模型 `provisional` 已逾期——主機平台已定案)
- **Report**: `docs/architecture/architecture-review-2026-08-18.md`(另見 `docs/architecture/traceability-index.md` 全量矩陣、`docs/architecture/tr-registry.yaml` 穩定 ID)。
- **本輪新增待查證清單(godot-specialist 諮詢,非 revision flag,是 verification item)**:`FileAccess.flush()` 是否有可檢查回傳值(傾向無)、GDScript 是否有 fsync 等效物(傾向無)、`duplicate_deep()` 的確切 enum 成員名稱(未知)、cursor 系統「Agile Event Flushing」單幀批次保證(未驗證)。**新風險旗標**:4.6 雙焦點系統(滑鼠/觸控 vs 鍵盤/手把焦點分離)影響**所有** Control 選單畫面,不只戰棋游標系統本身——待 UI 系統(#9/#10/#11)設計時留意。
