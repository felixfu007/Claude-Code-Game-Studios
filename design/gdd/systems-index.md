# Systems Index:《弈緣》(暫定)

> **Status**: Draft
> **Created**: 2026-07-30
> **Last Updated**: 2026-08-05(`/design-review save-system.md` 第三輪完整模式對抗性覆核後修訂——**NEEDS REVISION(11 組阻擋,去重合併自第二輪修訂本身「規則間接縫未言明」的問題),同一 session 內完成修訂**,詳見 `design/gdd/reviews/save-system-review-log.md`;使用者裁決 D-1(創世保留)+D-2(遷移改分步執行)+D-3(自動痊癒路徑二加註完成標記與拼接前提)+D-4(一般位元腐蝕新增滾動備份)+D-5(Player Fantasy 取捨殘餘成本誠實重新計價);本輪再次觸及 `affinity-data-pool.md`——擴大索引鍵持久化範圍涵蓋 `source_i`(新增 AC-57)、修正 Open Question 5 殘留的矛盾舊敘述,該文件其餘內容與 Approved 判決不受影響;前次(第二輪)更新:NEEDS REVISION(9 組阻擋,去重合併自第一輪的防線缺失升級為第一輪修訂本身的 fail-open 邊界),同一 session 內完成修訂,詳見同一份 review log;使用者裁決 A2(Player Fantasy 三級嚴重度排序以取捨聲明為準)+ B-甲(遷移回寫保留原始位元組,第三輪修訂為創世保留);Cross-System Obligations Registry 兩列〔序列化生命週期通知介面、AC-47〕仍為「provisional」(第三輪未變動,待同步/非同步真正定案——第三輪的遷移執行模型改為分步執行〔D-2〕不影響此二列,分步執行仍是單執行緒模型,不需要序列化生命週期通知介面),因原判定所依賴的同步阻塞式寫入決定本身被判定越權花用而降格——`affinity-data-pool.md` 本身未就此二列被回頭修改;更早:2026-08-05 第一輪更新:MAJOR REVISION NEEDED(24 項阻擋),同一 session 內完成修訂,詳見同一份 review log;同日稍早,`/design-review cursor-highlight-state.md` 第十輪審查後修訂——滑鼠奪權子機制止損政策觸發,升級為 MAJOR REVISION;重新設計已於同一 session 內完成實作(重置觸發清單五項簡化為四項),待第十一輪覆核 + 已排程 spike 驗證校準值(見該 GDD Open Questions);Cross-System Obligations Registry 新增兩列〔下游預覽渲染義務、表面卸載前目標交接義務〕,並修正全域裝置狀態指示元件擁有者列的措辭(生命週期涵蓋要求,好感度視覺呈現 UI 補入候選),回應該輪 ui-programmer、ux-designer、game-designer、systems-designer、qa-lead、godot-specialist 六方審查發現;更早:2026-08-05 第九輪審查新增兩列〔表面類型標籤單一實例契約、全域裝置狀態指示元件擁有者待指派〕;2026-08-04 第八輪審查新增教學掛鉤依賴與運動無障礙孤兒義務兩列;2026-08-03,單一游標/高亮狀態系統 GDD 完成設計;另見 `/design-review affinity-data-pool.md` 第七輪審查新增的支援對話系統風險列)
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

《弈緣》是一款單人戰術戰棋+敘事策略遊戲,核心賣點是「好感度即戰場」——角色間的好感度直接轉譯為位置戰術規則(聯動加成/內鬨懲罰),同一份好感度數值池同時服務戰鬥端(即時強度讀取)與敘事端(累積軌跡讀取)。主角群固定 5 人,不透過招募擴充。已完成 5 輪概念原型(v1-v5)與 1 次戰役規模模擬,核心機制方向確認 PROCEED。本索引把概念文件的核心機制、隱含基礎設施、UI/敘事支撐系統拆解為 14 個可獨立設計的系統。

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | 好感度數值池(Delta Log) | Core | MVP | Approved(2026-08-03,第七輪 `/design-review` 後) | design/gdd/affinity-data-pool.md | — |
| 2 | 存檔系統(含跨規則集遷移) | Persistence | MVP | Designed(待審查——已完成第三輪 `/design-review` 修訂,待第四輪重新覆核) | design/gdd/save-system.md | — |
| 3 | 單一游標/高亮狀態系統 | Core | MVP | Designed(待審查) | design/gdd/cursor-highlight-state.md | — |
| 4 | 戰棋移動與交戰系統(含武器射程分層) | Gameplay | MVP | Not Started | — | — |
| 5 | 好感度—位置連鎖系統(含陣亡處理) | Gameplay | MVP | Not Started | — | 好感度數值池、戰棋移動與交戰系統 |
| 6 | 技能卡牌系統(含好感度對話卡牌) | Gameplay | MVP | Not Started | — | 好感度數值池、戰棋移動與交戰系統 |
| 7 | 章節/戰役結構 | Narrative | MVP | Not Started | — | 存檔系統 |
| 8 | 支援對話系統 | Narrative | MVP | Not Started | — | 好感度數值池、章節/戰役結構 |
| 9 | 好感度視覺呈現 UI | UI | MVP | Not Started | — | 好感度—位置連鎖系統、單一游標/高亮狀態系統 |
| 10 | 戰鬥 HUD | UI | MVP | Not Started | — | 戰棋移動與交戰系統、單一游標/高亮狀態系統 |
| 11 | 支援對話 UI | UI | MVP | Not Started | — | 支援對話系統、單一游標/高亮狀態系統 |
| 12 | 教學/上手引導系統 | Meta | MVP | Not Started | — | 戰棋移動與交戰系統、好感度—位置連鎖系統、技能卡牌系統、單一游標/高亮狀態系統 |
| 13 | 敘事解鎖與結局分支系統 | Narrative | Vertical Slice | Not Started | — | 好感度數值池、章節/戰役結構 |
| 14 | 活棋盤地形演變系統 | Gameplay | Vertical Slice | Not Started | — | 戰棋移動與交戰系統、章節/戰役結構 |

---

## Categories

| Category | Description | Systems in this project |
|----------|-------------|-----------------|
| **Core** | 所有其他系統依賴的基礎設施 | 好感度數值池、單一游標/高亮狀態系統 |
| **Gameplay** | 構成戰術玩法本體的系統 | 戰棋移動與交戰、好感度—位置連鎖、技能卡牌、活棋盤地形演變 |
| **Persistence** | 存檔與跨場次狀態延續 | 存檔系統 |
| **UI** | 玩家可見的資訊呈現 | 好感度視覺呈現 UI、戰鬥 HUD、支援對話 UI |
| **Narrative** | 故事與對話遞送 | 章節/戰役結構、支援對話系統、敘事解鎖與結局分支系統 |
| **Meta** | 核心迴圈之外的輔助系統 | 教學/上手引導系統 |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | 核心迴圈能運作、且能執行 MVP 驗收協議所需的最小系統集合 | 首個可玩原型/正式 MVP 建置 | 優先設計 |
| **Vertical Slice** | 完整一個章節體驗所需,含劇情分支雛形與活棋盤演變 | 垂直切片 | 次優先設計 |

*本專案角色規模固定為 5 人(2026-07-30 裁決),不存在因招募擴充角色數而新增的 Alpha/完整願景專屬系統——範疇分級表的 Alpha 與完整願景層級只涉及內容量與打磨程度,不涉及新系統。*

---

## Dependency Map

### Foundation Layer(無依賴)

1. 好感度數值池(Delta Log) — 幾乎所有玩法與敘事系統的共同資料來源(第三~六輪 design-review 裁決的「單一數值池、雙重讀取」架構核心)
2. 存檔系統 — 跨場次保存進度與 delta log,不依賴其他玩法系統定案內容即可先定架構
3. 單一游標/高亮狀態系統 — 純輸入/UI 基礎設施,技術方向已在概念文件定案(godot-specialist,第四輪)

### Core Layer(依賴 Foundation)

1. 戰棋移動與交戰系統(含武器射程分層) — 玩法本體,已通過三輪原型驗證
2. 好感度—位置連鎖系統(含陣亡處理) — 依賴:好感度數值池(讀取)、戰棋移動與交戰系統(讀取站位/陣亡事件)
3. 技能卡牌系統(含好感度對話卡牌) — 依賴:好感度數值池(寫入)、戰棋移動與交戰系統(卡牌效果作用於戰鬥狀態)
4. 章節/戰役結構 — 依賴:存檔系統(章節進度需持久化)

### Feature Layer(依賴 Core)

1. 支援對話系統 — 依賴:好感度數值池(讀寫)、章節/戰役結構(排程於戰鬥之間)
2. 敘事解鎖與結局分支系統 — 依賴:好感度數值池(讀取軌跡形狀特徵)、章節/戰役結構(結局與戰役進度綁定)
3. 活棋盤地形演變系統 — 依賴:戰棋移動與交戰系統(地形改變移動/戰鬥規則)、章節/戰役結構(演變隨劇情章節觸發)

### Presentation Layer(依賴 Feature)

1. 好感度視覺呈現 UI — 依賴:好感度—位置連鎖系統、單一游標/高亮狀態系統
2. 戰鬥 HUD — 依賴:戰棋移動與交戰系統、單一游標/高亮狀態系統
3. 支援對話 UI — 依賴:支援對話系統、單一游標/高亮狀態系統

### Polish Layer(依賴全部)

1. 教學/上手引導系統 — 依賴:戰棋移動與交戰系統、好感度—位置連鎖系統、技能卡牌系統(教學須涵蓋這三者的核心操作)、單一游標/高亮狀態系統(2026-08-04 新增,回應 `/design-review cursor-highlight-state.md` 第八輪審查——該系統的滑鼠奪權漸進回饋機制缺乏教學掛鉤,見 Cross-System Obligations Registry)

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | 好感度數值池(Delta Log) | MVP | Foundation | systems-designer | M |
| 2 | 存檔系統 | MVP | Foundation | systems-designer, engine-programmer | M |
| 3 | 單一游標/高亮狀態系統 | MVP | Foundation | ux-designer, gameplay-programmer | S |
| 4 | 戰棋移動與交戰系統(含武器射程分層) | MVP | Core | game-designer, systems-designer, ai-programmer | L |
| 5 | 好感度—位置連鎖系統(含陣亡處理) | MVP | Core | game-designer, systems-designer | L |
| 6 | 技能卡牌系統(含好感度對話卡牌) | MVP | Core | game-designer, systems-designer | M |
| 7 | 章節/戰役結構 | MVP | Core | narrative-director, game-designer | S |
| 8 | 支援對話系統 | MVP | Feature | narrative-director, game-designer | M |
| 9 | 好感度視覺呈現 UI | MVP | Presentation | ux-designer, ui-programmer, art-director | M |
| 10 | 戰鬥 HUD | MVP | Presentation | ux-designer, ui-programmer | S |
| 11 | 支援對話 UI | MVP | Presentation | ux-designer, ui-programmer | S |
| 12 | 教學/上手引導系統 | MVP | Polish | ux-designer, game-designer | S |
| 13 | 敘事解鎖與結局分支系統 | Vertical Slice | Feature | narrative-director, writer | L |
| 14 | 活棋盤地形演變系統 | Vertical Slice | Feature | level-designer, game-designer | M |

*Effort estimates: S = 1 session,M = 2-3 sessions,L = 4+ sessions。*

---

## Circular Dependencies

- 未發現循環依賴。

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| 好感度數值池(Delta Log) | Design | 時近性加權 λ 校準與敘事可達性硬性約束(結局不得永久不可達)是全新設計,戰役規模模擬已驗證方向但僅為紙上手算,實際實作與校準未經驗證 | 已完成 `prototypes/affinity-campaign-simulation-2026-07-29/`;設計時須先定義冷落/復原場數節奏再反推 λ,並用敘事可達性測試逐一驗證 |
| 好感度—位置連鎖系統 | Design | 疊加規則、同時生效對數上限、tie-break 規則、陣亡處理方案四者互相牽動,且陣亡處理有明確不合格判定(不得優於存活情境) | 依 game-concept.md 已裁決的硬性約束逐條設計,`/design-system` 階段須先定案疊加規則才能定案陣亡方案(既有裁決順序) |
| 技能卡牌系統 | Scope | v5 原型發現牌組/抽卡機制完全未定義,負面效果卡用途不明,卡牌池深度不足 | 詳見 `prototypes/affinity-position-concept-v5/REPORT.md`;`/design-system` 階段需完整設計牌組建構與抽卡規則,不能只延伸原型的簡化實作 |
| 敘事解鎖與結局分支系統 | Design | 「沉默即表層」是先於本作存在的敘事慣例常設風險,Track B 紙上原型僅 N=1 樣本,五項硬性交付項(平行代價寫作、命名同位階等)尚未實際寫作驗證過 | 垂直切片階段須用未看過任何分支名稱的新讀者重測,通過條件為讀者能主動說出純戰鬥路線獨有的獲得 |
| 活棋盤地形演變系統 | Design | 與空間餘裕原則的互動從未被任何原型測試過,是文件中持續三輪被列為最高優先度的設計風險 | 垂直切片階段強制至少三次地形演變測試(含一次刻意壓縮測試),測試須發生在主要不可迴避路徑上 |
| 支援對話系統 | Design | 好感度數值池的 Dependencies 章節對本系統登記了「硬性交接義務」(若支援對話可無限期延後完成、玩家自由選擇何時觸發,讀值會逼近未加權總和,規避時近性衰減設計本意),但本系統設計尚未開始,此義務目前僅存在於上游文件、未被本系統的設計者看見(2026-08-03 第七輪 `/design-review` 新增,回應 game-designer 審查發現——本列此前完全缺席於本表) | `/design-system 支援對話系統` 開始時必須先讀 `design/gdd/affinity-data-pool.md` 的 Dependencies 章節,將完成時機規則(是否有時限、是否隨章節推進強制觸發)列為必須解決的設計輸入,另見下方「跨系統義務登記表」 |

---

## Cross-System Obligations Registry(跨系統義務登記表)

*2026-08-03 第七輪 `/design-review affinity-data-pool.md` 新增,回應 game-designer、qa-lead 三方獨立收斂發現:好感度數值池已累積 6+ 條「硬性交接義務」寫在自己的 Dependencies 章節裡,但承接系統的未來設計 session 不會自動載入這份文件、也無從得知義務存在。此表提供跨文件的可追蹤登記,任何系統的 GDD 在 Dependencies 章節新增「硬性交接義務」給尚未設計的系統時,應同步在此表登記一列。設計該承接系統時(`/design-system` 或 `/design-review`),應先查此表確認是否有待清償的義務。*

| 義務內容 | 登記來源 | 承接系統 | 關閉條件 |
|---|---|---|---|
| 好感度對話卡牌若可無限期囤積後於戰役尾聲集中打出,會規避時近性衰減設計 | affinity-data-pool.md Dependencies(第三輪) | 技能卡牌系統 | 該系統 GDD 的 Detailed Rules 明確定案手牌上限/棄牌/持有時限規則,並在 Dependencies 或 Edge Cases 章節回應此義務 |
| 支援對話若可無限期延後完成,同樣規避時近性衰減,且影響權重高於卡牌來源(無 α 折扣) | affinity-data-pool.md Dependencies(第四輪) | 支援對話系統 | 該系統 GDD 定案解鎖後的完成時機規則(是否有時限、是否隨章節推進強制觸發) |
| AI 評估多個假設站位時,須對讀取結果做單回合記憶化快取,不得每次假設性查詢都重新掃描 | affinity-data-pool.md Dependencies + Core Rules #1(第三/六輪) | 好感度—位置連鎖系統 | 該系統 GDD 的 Formulas/Detailed Rules 明確採用 `read(t_last)` 快取模式,並定案是否涉及多回合前瞻搜尋(見 performance-analyst 第七輪發現,若涉及多回合前瞻,單回合快取範圍不足以擔保效能) |
| 解鎖/分支判定不得只依賴 `narrative_depth_read` 純量,須交叉參照 `spread_ratio`/`total_churn`/`source_polarity`/`segment_profile`/`source_absence` 與 `n(p)` | affinity-data-pool.md Dependencies(第三~六輪) | 敘事解鎖與結局分支系統 | 該系統 GDD 的解鎖/分支判定公式明確納入上述形狀特徵的交叉參照,且至少寫出兩組「深度相近、形狀不同」的判定草案驗證可操作性(見 Formulas「形狀特徵集合與 Track B 二維形狀空間的對應」) |
| `source_absence` 的 `absent_confirmed` 只斷言事實(零記錄),不斷言玩家意圖;若解鎖判定閘控某來源的開放與否,須自行確認該來源在相關期間確實已對玩家開放,才能把 `absent_confirmed` 讀成主動選擇;`story_event` 分量禁止被詮釋為玩家選擇 | affinity-data-pool.md Formulas 3g + Dependencies(第七輪新增) | 敘事解鎖與結局分支系統 | 該系統 GDD 明確處理「來源是否曾開放」與「來源零記錄」兩者的區分邏輯 |
| 陣亡角色的讀值查詢須以陣亡當下的 `t_query` 呼叫,不得使用預設的呼叫當下 `t_now` | affinity-data-pool.md Dependencies(第七輪新增) | 敘事解鎖與結局分支系統、好感度—位置連鎖系統 | 兩系統的 GDD 對陣亡配對的讀取邏輯明確採用歷史 `t_query`,並有對應 Acceptance Criteria |
| `pure_combat_floor` 只保證數學可達,不保證玩家讀成「不同形狀」而非「較差」;`低信心(low_confidence)` 是弱證據標記,不是退回單軸判定的訊號 | affinity-data-pool.md Dependencies + Formulas 3f(第三、七輪) | 敘事解鎖與結局分支系統 | 該系統 GDD 明確處理「深度地板值校準」與「順序軸低信心情境」的因應策略,不得系統性退回深度單軸 |
| 序列化生命週期通知介面(begin/end)須於非同步存檔架構下提供,且旗標本身須執行緒安全 | affinity-data-pool.md Dependencies + Edge Cases(第六、七輪) | 存檔系統 | ⚠️ **重新開放為 provisional(2026-08-05)**——`design/gdd/save-system.md` 第一輪 `/design-review` 判定原本的「已關閉」越權花用了尚未定案的同步/非同步決定;Core Rules #4 已改標 provisional,並列出重新啟用時需回補的介面清單(即本列)。`affinity-data-pool.md` 本身**未被回頭修改**,狀態仍記錄為 N/A,待序列化格式/同步-非同步真正定案時一併處理(見 save-system.md Open Questions) |
| AC-4(呼叫圖分析驗證寫入介面呼叫點恰為三處)須在承接系統有實際程式碼後補跑 | affinity-data-pool.md Acceptance Criteria 第 L 節 | 技能卡牌系統、支援對話系統、章節/戰役結構(三者皆須完成實作) | `producer`/`qa-lead` 於三系統整合驗收里程碑追蹤並執行,執行前不計入好感度數值池自身 DoD |
| AC-47(存檔進行中拒絕寫入)須在存檔系統架構定案後補跑或標記 N/A | affinity-data-pool.md Acceptance Criteria 第 L 節 | 存檔系統 | ⚠️ **重新開放為 provisional(2026-08-05)**——理由同上一列,`design/gdd/save-system.md` 第一輪 `/design-review` 判定 AC-47=N/A 的定案基礎(同步阻塞式寫入)本身已降格為 provisional。`affinity-data-pool.md` 的 AC-47 狀態**未被回頭修改**,仍記錄為 N/A,待同一決策點一併處理 |
| 單一游標/高亮狀態的裝置權威判定與高亮渲染規則不限棋盤格,適用於所有具懸停/游標目標的 UI 表面,下游 UI 系統不得各自重新實作一套邏輯 | cursor-highlight-state.md Core Rules #7 + Dependencies(2026-08-03 新增) | 好感度視覺呈現 UI、戰鬥 HUD、支援對話 UI | 三系統的 GDD 皆讀取單一游標/高亮狀態系統的共用介面決定高亮顯示,不自行實作裝置權威判定 |
| 游標指向的目標(棋盤格上的單位)失效時(死亡/被移動),呼叫方須呼叫單一游標/高亮狀態系統新增的「標記目前目標為待重新解析」介面,不得放任舊高亮視覺原樣顯示 | cursor-highlight-state.md Core Rules #2 + Edge Cases(2026-08-04 新增,`/design-review` 完整模式第三輪審查後) | 戰棋移動與交戰系統 | 該系統 GDD 的 Detailed Rules 或 Edge Cases 明確定案單位死亡/移動時呼叫本介面的時機與呼叫時序,並在其 Dependencies 章節回應此義務 |
| 「表面類型標籤」(見 cursor-highlight-state.md Core Rules #1)必須是單一共用列舉的成員,任何下游系統新增自己的表面類型時須在此列舉新增對應成員,不得自行發明字串或獨立型別 | cursor-highlight-state.md Core Rules #7 + Dependencies(2026-08-04 第七輪新增,回應 ui-programmer 審查發現) | 好感度視覺呈現 UI、戰鬥 HUD、支援對話 UI、戰棋移動與交戰系統(四者皆為單一游標/高亮狀態系統的下游依賴方) | 四系統的 GDD 皆引用同一份共用列舉作為「表面類型標籤」的合法值來源,不各自定義字串或獨立型別;列舉的實作位置與擁有者於 `/create-architecture` 定案後,本列關閉條件同步更新 |
| 滑鼠奪權漸進回饋機制(累積位移接近門檻時原生指標淡入)缺乏新手教學掛鉤——機制本身無真實世界玩家先例,直接坐落於本文件宣稱服務的支柱(玩家從不需要探測性輸入)之上 | cursor-highlight-state.md Open Questions(2026-08-04 第八輪新增,回應 ux-designer 審查發現、creative-director 裁決——第七輪已裁決本義務須從本輪起正式登記,不再以建議項循環) | 教學/上手引導系統 | 該系統 GDD 的 Detailed Rules 明確涵蓋此機制的教學/上手引導設計,並回應 `cursor-highlight-state.md` Open Questions 對應列 |
| 運動無障礙需求(motor accessibility,例如奪權門檻可調整性、瞄準輔助)先前僅口頭轉交 `design/ux/accessibility-requirements.md`,但該檔案不存在,義務先前從未登記於任何可追蹤位置 | cursor-highlight-state.md Open Questions(2026-08-04 第八輪新增,回應 ux-designer 審查發現、creative-director 裁決) | `design/ux/accessibility-requirements.md`(尚未建立;本專案目前無對應系統條目) | `design/ux/accessibility-requirements.md` 依 `.claude/docs/templates/accessibility-requirements.md` 範本實際建立,並回應本系統的像素門檻/死區依賴機制 |
| 單一游標/高亮狀態系統的滑鼠奪權漸進回饋機制(累積位移接近門檻時原生指標淡入)缺乏新手教學掛鉤,`/design-review` 已連續多輪列為建議項循環,第七輪 creative-director 明確裁決第八輪起須正式轉為登記義務 | cursor-highlight-state.md Open Questions(2026-08-04 第八輪新增,回應 ux-designer 審查發現、creative-director 裁決) | 教學/上手引導系統 | 該系統 GDD 的 Detailed Rules 明確涵蓋滑鼠奪權機制的教學掛鉤設計(觸發時機、呈現方式),並回應本義務 |
| 本系統核心機制(像素為單位的奪權門檻、死區依賴的零門檻方向鍵豁免)恰好命中運動無障礙(motor accessibility)典型關注項(瞄準輔助、時間調整、按鍵重新綁定),但 `design/ux/accessibility-requirements.md` 目前不存在,先前的轉交聲明僅存在於 review log、從未正式登記 | cursor-highlight-state.md Open Questions(2026-08-04 第八輪新增,回應 ux-designer 審查發現、creative-director 裁決) | `design/ux/accessibility-requirements.md`(尚待建立)的擁有者(ux-designer) | `design/ux/accessibility-requirements.md` 實際建立,且其 Motor Accessibility 章節回應本系統列出的關注項 |
| 「表面類型標籤」(見 cursor-highlight-state.md Core Rules #7)在任一時刻,同一標籤至多只能有一個實例掛載於場景樹中——若某類 UI 表面天生有多個同時存在的變體(例如同時提供完整檢視與縮圖檢視),須在共用列舉中為每個變體登記獨立成員,不得共用同一成員 | cursor-highlight-state.md Core Rules #7 + Dependencies(2026-08-05 第九輪新增,回應 ui-programmer 審查發現、綜合裁決收窄範圍) | 好感度視覺呈現 UI、戰鬥 HUD、支援對話 UI、戰棋移動與交戰系統(四者皆為單一游標/高亮狀態系統的下游依賴方) | 四系統的 GDD 皆確認自己的表面實例不違反單一標籤單一實例的約束,若天生需要多實例則在共用列舉登記獨立成員,並同步在 `mouse_reclaim_threshold_px_by_surface_type` 表新增對應門檻常數 |
| 全域裝置狀態指示元件(待機指示,例如手把/滑鼠圖示的明暗或啟用狀態)由哪個下游系統擁有/渲染尚未指派——第九輪已將待機指示規則從「四個表面各自顯示」改為「每裝置一個全域指示」,擁有者仍待確認;**第十輪修正措辭**:AC-27 要求無條件存在於任何使用本系統的畫面,候選擁有者若皆為畫面範圍元件則在構造上無法滿足,擁有者須為生命週期涵蓋所有游標系統畫面的節點 | cursor-highlight-state.md Open Questions + Visual/Audio Requirements(2026-08-05 第九輪新增,第十輪修正措辭,回應 ui-programmer、ux-designer 審查發現) | 戰鬥 HUD(候選,未定案)、支援對話 UI、好感度視覺呈現 UI(第十輪新增候選,回應 ux-designer 發現該系統擁有的關係圖迷你地圖是高懸停歧義表面) | 相關下游系統的 GDD 明確指派此全域指示元件的擁有者(生命週期須涵蓋所有游標系統畫面)與呈現位置 |
| 讀取目前游標目標座標以渲染玩家可見預覽(移動範圍/攻擊射程預覽、好感度連線/關係圖預覽)的下游系統,須在渲染前查詢本系統的有效性旗標;旗標為無效(待重新解析)期間,該預覽須被抑制或以明確不確定佔位樣式呈現,不得渲染成確信樣式 | cursor-highlight-state.md Core Rules #2「下游預覽渲染義務」(2026-08-05 第十輪新增,回應帳本 L1 連續四輪未處置達自動升級門檻、game-designer/ux-designer/ui-programmer 三方收斂發現) | 戰棋移動與交戰系統、好感度視覺呈現 UI | 兩系統的 GDD 皆定案預覽渲染前查詢有效性旗標的邏輯,並各自新增對應驗收標準 |
| 若下游 UI 表面自身即為目前游標目標所屬的表面類型,須在卸載/關閉前呼叫單一游標/高亮狀態系統的「標記目前目標為待重新解析」或「設定新目標」介面完成交接,不得直接卸載而不通知 | cursor-highlight-state.md Core Rules #7「表面卸載前的目標交接義務」(2026-08-05 第十輪新增,回應 ui-programmer 審查發現) | 好感度視覺呈現 UI、戰鬥 HUD、支援對話 UI、戰棋移動與交戰系統 | 四系統的 GDD 皆確認自己的表面卸載邏輯包含此交接呼叫 |
| 下游表面呈現的三種可辨識視覺狀態(一般高亮、待重新解析、滑鼠奪權漸進回饋)須跨系統一致——同一種狀態在不同下游表面上的呈現邏輯不得互相矛盾或各自發明額外的中間狀態(2026-08-04 第七輪 review 曾提出此建議項,但在第八輪的遺留清單中無聲消失,未經解決或明文延期,第九輪回應 ux-designer 審查發現正式補回登記) | cursor-highlight-state.md Visual/Audio Requirements + AC-48/AC-49(2026-08-05 第九輪補回登記) | 好感度視覺呈現 UI、戰鬥 HUD、支援對話 UI、戰棋移動與交戰系統 | 四系統的 GDD 皆確認自己對三態視覺的呈現邏輯與本系統定義的三態一致,不各自發明額外的中間視覺狀態 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 14 |
| Design docs started | 3 |
| Design docs reviewed | 1 |
| Design docs approved | 1 |
| MVP systems designed | 3/12 |
| Vertical Slice systems designed | 0/2 |

---

## Next Steps

- [ ] Review and approve this systems enumeration
- [ ] Design MVP-tier systems first(use `/design-system [system-name]`)——依 Recommended Design Order 從「好感度數值池」開始
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when MVP systems are designed
- [ ] Validate the highest-risk systems with `/vertical-slice` before committing to Production
