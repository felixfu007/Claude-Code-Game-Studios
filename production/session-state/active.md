# Active Session State

<!-- STATUS -->
Epic: 設計階段(Core Layer GDD)
Feature: 戰棋移動與交戰系統
Task: /design-review 第四輪修訂已落地,待 commit;下一步建 ADR(選項B)後跑第五輪
<!-- /STATUS -->

**最後更新**:2026-08-18 —— `/design-review design/gdd/tactical-combat-system.md` 第四輪(完整模式,7 專家 + creative-director)

---

## 本 session 完成的事

第四輪 `/design-review` **完整模式**覆核(依 Phase 0b 升級門檻升級——第三輪 7 項 BLOCKING-NOW 全為設計內容缺陷)。7 位專家平行派工:`game-designer`、`systems-designer`、`qa-lead`、`ux-designer`、`gameplay-programmer`、`performance-analyst`、`godot-specialist`,加 `creative-director` 資深綜整。

判定 **NEEDS REVISION**:原始發現 15 項,去重後 **6 項 BLOCKING-NOW 全為設計內容缺陷** + 2 項低成本補項 + 3 項 DEFER + 3 項 ADVISORY,**全部已於同輪修訂落地**。

### 本輪最重要的一項結構性改動

**新增 Core Rules #11「結算步的不可重入邊界」**。起因:四位專家從四個角度撞到同一根樑——文件從未回答「盤面權威狀態何時才准改變、一次改變的單位是什麼」。徵狀分別是:`game-designer` 發現 #10(a) 只約束「若重繪則正確」卻不定案重繪時機(渲染一次永不失效的實作完全合規);`gameplay-programmer` 發現 #5 宣稱結算步不可中斷卻無任何重入防護、而②c 呼叫的是未設計的 #6;`systems-designer` 發現 #10(c) 的 `occupied` 同步時點只錨定陣亡、AC-22 卻已在測試移動同步(AC 層憑空發明規範);`ux-designer` 發現陣亡淡出與同結算步佔位釋放在同格衝突。

Core Rules #11 三項內容:(1) 結算步進行中不接受任何操作(「可暫緩」的粒度是結算步**之間**,不是進行中);(2) 對 #6 定案**同步契約**——②c 的卡牌效果不得於結算中要求玩家輸入;(3) **邏輯狀態為唯一權威**,動畫/淡出/節點生命週期不得作為任何規則判定的依據。

### 其餘五項 BLOCKING-NOW

- **B-2**:#10(b) 的原子性綁在「一次查詢」,未定義合成查詢的原子單位。橫向(§1a 強制並存的兩張疊加圖)與縱向(`threat_range_all` 為 N 次子計算聯集)皆可產生「對應不到任何真實盤面」的組合畫面。已補「被合併判讀的一組輸出視為同一次查詢、共用同一份快照」+ AC-22 兩條向量。
- **B-3(跨文件真矛盾,已實查)**:Core Rules #6a 無陣營限定,字面要求任一單位(含敵方)陣亡皆呼叫 `affinity-data-pool.md` 陣亡通知;但該文件 Core Rules #1 明文將鍵域定為「5 名固定主角之一」。已收斂為**僅我方陣亡時呼叫**,並比照 6b 補上呼叫失敗的偵測/重試義務。
- **B-4**:②b 宣稱「語意與 Core Rules #8 相同」是事實錯誤(輸入集嚴格更大),邀請直接複用 #8 的預判介面 → 會使②b 重新查詢 `Φ`,正是前三輪堵住的危害換角度復發。已修正 + AC-6 新增向量。
- **B-5**:同一規範性斷言逐字重述於 AC-11/AC-20/AC-22(a) 三處,命中本專案明文列為最昂貴的招牌失敗模式。AC-11/AC-20 已收斂為指標引用。
- **B-6**:公式四以「寧可高估、絕不低估」正當化省略視線檢查,但佔位軸上確實低估且未揭露。已新增「保守性的邊界」段落 + 呈現/教學層揭露義務。

### 結構性診斷(creative-director,已影響策略裁決)

本輪 15 項原始發現中,落在文件**原生設計**(Core Rules #1–#4/#7/#8、公式一/二/三、AC-1 至 AC-19)的數量為 **0**——連續四輪未再產生任何發現。100% 落在第二至四輪由審查自己新增的材料。診斷:**設計已收斂,未收斂的是治理層**。

**使用者裁決:採選項 B** —— 本輪先完成內容修法(已完成),接著把架構級契約外移至專屬 ADR,GDD 只留玩家可觀測義務。

### 專家分歧(creative-director 與專家,已呈報並裁決)

- `ux-designer` F4-A 由 BLOCKING **降為** OQ-21(§6 原則陳述已涵蓋兩種分支,不會產生錯誤實作);但其抓到的流程失誤屬實——此項第二輪已列 DEFER 卻從未登記,消失整整一輪,本輪補登。
- `game-designer` 自評 DEFER 的威脅範圍低估由 creative-director **升為** BLOCKING(自我否定,非精確度問題)。
- `performance-analyst` F4-PERF-1 由 BLOCKING **降為** OQ-16 擴寫(其穩態成本疑慮已由 B-1 的結算邊界模型解答)。
- `godot-specialist` **零 BLOCKING-NOW**——四個引擎面查核角度全數通過 4.7.1 版本核對。

---

## 落地修訂範圍(逐檔)

- **`design/gdd/tactical-combat-system.md`**:新增 Core Rules #11;Core Rules #10 a/b/c 三項各自擴充;Core Rules #6a 陣營限定 + 失敗處理;Core Rules #5 步驟②b 新增「與 Core Rules #8 的關係」段落;Formulas 公式四新增「保守性的邊界」;**新增 AC-23(武器資料表結構完整性)、AC-24(結算步不可重入)**;AC-6/9/11/20/22 修訂;Dependencies #6/#12 列補義務;Open Questions **新增 OQ-21**,OQ-4/13/16 擴充;標頭全面改寫(含第四輪結構性診斷與選項B裁決)。
- **`design/gdd/systems-index.md`**:Cross-System Obligations Registry —— 既有「Core Rules #10 查詢介面義務」列擴充(a/b/c 三項的第四輪修訂 + 新增呈現/教學義務),**新增一列**(Core Rules #11 對 #6 的同步契約)。
- **`design/gdd/reviews/tactical-combat-system-review-log.md`**:新增第四輪條目;依本檔壓縮協定將第三輪的 Summary 散文收斂為表列 + 一段後記。
- **`production/session-state/active.md`**:本檔。

## Grep 自核 pass 結果

檢查 AC 編號完整性(AC-1～AC-24,無重號無跳號,共 24 條)、AC-11/AC-20 舊斷言措辭殘留(**0 筆**,已全部收斂為指標)、「語意與 Core Rules #8」(1 筆,經查為**刻意保留**——修法史引述舊措辭以說明缺陷)、跨檔 Core Rules #10/#11 引用、systems-index 兩列。**發現並修正一項自身失誤**:新增 AC-23/AC-24 章節時誤將 AC-22 的「測試撰寫提醒」隔在兩節之後(該段以「本 AC」指稱 AC-22),已移回 AC-22 節內。**無未同步的規範性殘留。**

**未修改 `affinity-data-pool.md`**(已 Approved):B-3 的修法是讓本文件的呼叫域**向該文件既有的鍵域定義對齊**,該文件本身不持有任何過時宣稱,故無需回頭修改;方向性正確,無雙向不一致殘留。

---

## 下一步

1. **尚未 commit** —— 四個檔案待提交(3 改 1 改為本檔)。
2. **依選項 B 執行 `/architecture-decision`** 建立 **[ADR:戰棋查詢介面原子性契約]**,承接 Core Rules #10 b/c 的內部機制與 #11 的重入防護實作。GDD 內現有 `[ADR:戰棋查詢介面原子性契約]` 佔位指標**須於該 ADR 建立後回填實際編號與路徑**(共 3 處:Core Rules #10 b 項、#11 末段)。注意:本專案 `docs/architecture/` 目前只有 `tr-registry.yaml`,尚未進入 `/create-architecture` 階段,這將是**第一份 ADR**(提前單點建立,非完整架構階段)。
3. **第五輪 `/design-review` 應於全新 session 執行**。**驗證判準(creative-director 提供)**:若新發現仍落在查詢介面義務/AC 治理層,代表治理層錯置尚未解決;若落在 Core Rules #1–#9 或公式一至三,才是設計本身真的還有問題。
4. **收斂狀態**:連續零 BLOCKING-NOW 輪數 = **0**(第一輪 6、第二輪 5、第三輪 7、第四輪 6,四輪皆 body-scoped)。距 APPROVED 尚需**連續兩輪** body-scoped 零 BLOCKING-NOW。
5. 本系統仍為 **Designed, 尚未 Approved**,不得移交 `/create-architecture`。

## 仍未處理(非本輪範圍)

- **OQ-2**(`player_baseline_stat` 全專案無擁有者)與 **OQ-10**(無「不可通行」地形層級)—— 文件自陳的兩項下游阻擋項,須在 `/create-architecture` 前指派/裁決。
- **OQ-16 本輪新增的兩項待補**:敵方單位數上限全專案無擁有者;效能測試須以「格數 × 敵方單位數」兩軸參數化。
- **本輪 2 項 DEFER 尚未落地為資料驗證項**:`enemy_advantage_pct < 0` 無驗證拒絕(與既有 `≥1.0` 拒絕不對稱);公式二 `ceil()` 浮點精度邊界噪聲。
- `systems-index.md` 標頭部分歷史段落仍有行號式自我引用,與 `.claude/rules/design-docs.md` 的「禁止行號自我引用」規則相衝;本輪未追蹤修正(非本輪覆核範圍)。
