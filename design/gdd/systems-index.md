# Systems Index:《盲目於微光》

> **2026-08-25 範疇裁決**:本表 MVP 層級自 12 個系統收斂為 **9 個**(垂直切片 5 個),
> 依據 `game-concept.md`「MVP 定義」節。降級:#2 存檔系統、#7 章節/戰役結構、#12 教學系統。
> **完整理由與兩項連帶處置寫在下方 Priority Tiers 節**,修訂本表任何層級標記前必須先讀該節。

> **Status**: Draft
> **2026-08-18 更新(架構階段:Foundation 層 ADR 系列)**:同日晚間以 `/architecture-decision` 連續撰寫三份 ADR,皆 `Proposed`——**ADR-0002 好感度數值池資料結構與並發契約**(**24 項 `TR-affinity-*` 為 21 完整 / 3 部分 / 0 缺口** —— 2026-08-20 第七輪 `/architecture-review` 獨立重推;⚠️ **2026-08-21 修正**:本處原寫「涵蓋全部 24 項」,那是過度宣稱(零缺口成立,「全部涵蓋」不成立),第六、七輪已各自點名而本索引未跟上。**注意同一行的 `TR-save-*` 部分早已修正為 22/7/1** —— 這一行先前只被修了一半:per-pair 索引 `Dictionary` 滿足 GDD 已鎖定的 `O(n_p+m)` 契約、獨立戰役刻度標記列表/陣亡標記表、單調遞增 int 權杖 + **無條件** `Mutex`、依賴注入擁有模式非 Autoload);**ADR-0003 存檔系統序列化格式與型別安全**(解決 `save-system.md` Open Question 3:選 `var_to_bytes()`/`bytes_to_var(bytes, false)` 二進位 Variant 序列化,使 Core Rules #9 型別白名單在引擎層級**結構性消除**而非靠應用層維護清單,並一併消解 Open Question 4;逐區塊 `PackedByteArray` 分層緩衝區支撐 manifest-only 讀取路徑;雙層 SHA-256 雜湊鏈依 `source_id` 字典序;回填修訂 ADR-0002 新增 `validate_semantics()`);**ADR-0004 存檔系統原子寫入與遷移執行模型**(可替換 `SaveIOBackend` 抽象把 Open Question 9 的主機 SDK 未知性限縮至單一檔案、Core Rules #14 六步驟原子置換含 Step 0 分支、`await scene_tree.process_frame` 分步遷移沿用 ADR-0001 已驗證的跨幀生命週期約束、單一進入/單一釋放的逐槽重入鎖——GDScript 無 `try`/`finally` 下唯一能保證無條件釋放的結構;**至此 30 項 `TR-save-*` 為 22 項完整涵蓋、7 項部分涵蓋、1 項缺口**(`TR-save-030` 雲端同步;2026-08-18 第二輪 `/architecture-review` 獨立推導修正,原宣稱「全數覆蓋」不成立))。三份皆經 `godot-specialist` 驗證,各抓到並修正 BLOCKING 級問題(ADR-0002:裸列舉跨檔無法編譯,已包裝為 `AffinityTypes`;ADR-0003:`get_var(true,false)` 雙參數形式與「記憶體內 `FileAccess`」路徑皆不存在,已改用 `var_to_bytes`/`bytes_to_var`;ADR-0004:誤引 `@abstract` 先例〔全專案實際從未用過〕+ 語法與專案唯一已查證範例互斥)。`docs/registry/architecture.yaml` 累計 **38 項**架構立場(7 state-ownership、6 interface contracts、15 API decisions、10 forbidden patterns)。**2026-08-18 第二輪 `/architecture-review` 已於全新 session 執行完畢**——判定 **FAIL**,130 項需求為 50 ✅ / 24 ⚠️ / 56 ❌(首輪為 5/16/109);`traceability-index.md` 全部 130 列標記已重建。唯一硬阻塞為**單一游標/高亮狀態系統 19 項需求零涵蓋**(Foundation 層)。報告:`docs/architecture/architecture-review-2026-08-18-round2.md`。
>
> **Last Updated**: **2026-08-18**(`/design-review design/gdd/tactical-combat-system.md` 第四輪 + `/architecture-decision` 建立專案首份 ADR。下方原有的「Last Updated: 2026-08-09」為該次 `/review-all-gdds` 當下的歷史記載,保留於原處以維持修法史可追溯性,**但現況以本列為準**)
> **2026-08-18 更新(第四輪 + 首份 ADR)**:`tactical-combat-system.md` 第四輪 `/design-review`(完整模式 7 專家 + creative-director)判定 **NEEDS REVISION**——原始 15 項發現去重後 **6 項 BLOCKING-NOW 全為設計內容缺陷**,全部同輪修訂落地。核心修法為**新增 Core Rules #11「結算步的不可重入邊界」**(四位專家從四個角度撞到同一缺口:文件從未定義盤面權威狀態何時才准改變)。另修正一項**跨文件真矛盾**:Core Rules #6a 原無陣營限定,字面要求每次擊殺敵人都對 `affinity-data-pool.md` 陣亡通知傳入域外識別碼(該文件鍵域明文為「5 名固定主角之一」),已收斂為僅我方陣亡呼叫。`creative-director` 結構性診斷:**連續四輪零發現落在文件原生設計,100% 落在審查自己新增的治理層材料** → 設計已收斂、治理層錯置,使用者裁決採選項 B(契約外移)。**Cross-System Obligations Registry 本輪擴充一列(Core Rules #10 a/b/c 的第四輪修訂 + 呈現/教學義務)並新增一列(Core Rules #11 對技能卡牌系統 #6 的同步契約)**。架構級機制已外移至 **ADR-0001「戰棋查詢介面原子性契約」**(`docs/architecture/adr-0001-tactical-query-atomicity-contract.md`,Proposed,`godot-specialist` 驗證零 BLOCKING),`docs/registry/architecture.yaml` 首次填入 13 項架構立場。詳見 `design/gdd/reviews/tactical-combat-system-review-log.md` 第四輪條目。
> **2026-08-11 更新**:`save-system.md` 第六輪 `/design-review`(完整模式六專家 + creative-director)解決三項長期擱置的跨文件殘留缺口——D-1(`source_absence` 可逆性,採終局判定+誠實告知方向,`game-concept.md`/`affinity-data-pool.md` 已修訂)、F2-1(AC-23 與 `cursor-highlight-state.md` Core Rules #7 真矛盾,改為登記制管轄判準)、F2-2(存檔載入後游標失效無人處理,責任歸屬呼叫方系統)——另新發現並同輪處理「三路終止漏第四支」與存檔完整性鏈條缺口(雜湊輸入來源、寫入失敗偵測義務)。Cross-System Obligations Registry 第 165 列與新增列已同步,詳見 `design/gdd/reviews/save-system-review-log.md` 第六輪條目。`/review-all-gdds` 2026-08-09 報告列出的其餘 Warning 級發現(F2-3/F2-4/F2-5/F2-6)未隨本輪處理,留待下一輪或相關下游系統設計時。
> **Created**: 2026-07-30
> **Last Updated**: 2026-08-09(`/review-all-gdds` 重新執行後修訂——**FAIL(21 項 Blocking:一致性 10 + 設計理論 7 + 情境走查 4,另 30 項 Warning)**,詳見 `design/gdd/gdd-cross-review-2026-08-09.md`。本輪查證發現 2026-08-06/07 對抗性覆核後的 8 項修訂並未如預期收斂為純傳播類問題,查出 5 項全新設計缺陷(負遠狀態仍無代價純正向、敘事結局深度門檻上限與 Track B 二維形狀空間宣稱結構性衝突、登記表第 149/174 列在陣亡情境下結構性互斥、`source_absence` 可逆性與其豁免資格前提矛盾、游標鎖死缺陷連鎖關閉兩套緩解機制)。**本輪已完成第一、二優先(基線真實性 + 2026-08-07 修法傳播)的外科手術式修訂,詳見下方各系統對應段落與 Cross-System Obligations Registry『序列化生命週期通知介面(begin/end)』列、『遭拒存檔(唯讀存取入口與甲/乙/丙分級告知)』列**;第三優先(5 項新設計缺陷,部分需 creative-director 裁決)**尚未修訂,留待下一輪**。本輪同步修正下方三系統 Status 欄與各自 GDD 標頭的真實狀態不一致問題(2c B3/B4)——`affinity-data-pool.md`、`save-system.md` 兩份文件標頭原記為 Approved,但鑑於本輪對兩者皆有新 Blocking 發現,已同步改為 Needs Revision,與本表原有記載一致(即本表原判定為真、兩份 GDD 標頭原判定為誤);Progress Tracker 的 approved/reviewed 計數同步重新核算為 0/3。
> **前次(第五輪存檔系統覆核)更新**:2026-08-07(`/design-review save-system.md` 第五輪完整模式對抗性覆核後修訂——**NEEDS REVISION(11 組阻擋,去重合併,creative-director 查證確認全部溯源至第四輪具體修法或第四輪新增的矩陣完備性檢查表本身,無新類別、無需使用者裁決項),同一 session 內完成修訂**,詳見 `design/gdd/reviews/save-system-review-log.md`;Cross-System Obligations Registry 第 164 列(下游 UI 錯誤呈現義務)拆分為兩列,各自獨立關閉條件,回應 game-designer 發現原列雙義務單關閉條件可被靜默視為已清償;creative-director 建議本輪修訂完即移交 `/create-architecture`、不再安排第六輪 `/design-review`,待使用者裁決;前次(第四輪)更新:2026-08-06(`/design-review save-system.md` 第四輪完整模式對抗性覆核後修訂——**NEEDS REVISION(8 組阻擋,creative-director 查證確認全部源自第三輪 D-1~D-5 新增規則自身缺了矩陣列/專屬 AC/範圍聲明三件套之一,非新設計缺陷),同一 session 內完成修訂**,詳見 `design/gdd/reviews/save-system-review-log.md`;Cross-System Obligations Registry 新增 8 列〔存檔系統對存檔管理 UI 的六項義務、對章節/戰役結構與活棋盤地形演變系統各一項〕;本輪意外發現 `technical-preferences.md` 與 `game-concept.md` 對主機平台矛盾,使用者裁決以前者為權威,已回頭修訂 `game-concept.md` 平台登記);前次(第三輪)更新:2026-08-05(`/design-review save-system.md` 第三輪完整模式對抗性覆核後修訂——**NEEDS REVISION(11 組阻擋,去重合併自第二輪修訂本身「規則間接縫未言明」的問題),同一 session 內完成修訂**,詳見 `design/gdd/reviews/save-system-review-log.md`;使用者裁決 D-1(創世保留)+D-2(遷移改分步執行)+D-3(自動痊癒路徑二加註完成標記與拼接前提)+D-4(一般位元腐蝕新增滾動備份)+D-5(Player Fantasy 取捨殘餘成本誠實重新計價);本輪再次觸及 `affinity-data-pool.md`——擴大索引鍵持久化範圍涵蓋 `source_i`(新增 AC-57)、修正 Open Question 5 殘留的矛盾舊敘述,該文件其餘內容與 Approved 判決不受影響;前次(第二輪)更新:NEEDS REVISION(9 組阻擋,去重合併自第一輪的防線缺失升級為第一輪修訂本身的 fail-open 邊界),同一 session 內完成修訂,詳見同一份 review log;使用者裁決 A2(Player Fantasy 三級嚴重度排序以取捨聲明為準)+ B-甲(遷移回寫保留原始位元組,第三輪修訂為創世保留);Cross-System Obligations Registry 兩列〔序列化生命週期通知介面、AC-47〕仍為「provisional」**(2026-08-09 讀者提醒:此為第三輪〔2026-08-05〕當下的歷史狀態描述,非現況——該二列已於本節下方「第四輪」更新記載的 2026-08-06 修訂中轉為「✅ 確定需要」,見下方 Cross-System Obligations Registry『序列化生命週期通知介面(begin/end)』列與『AC-47(存檔進行中拒絕寫入,含還原/遷移方向)須在存檔系統架構定案後補跑』列本文與 W1 finding of `gdd-cross-review-2026-08-09.md`)**(第三輪未變動,待同步/非同步真正定案——第三輪的遷移執行模型改為分步執行〔D-2〕不影響此二列,分步執行仍是單執行緒模型,不需要序列化生命週期通知介面),因原判定所依賴的同步阻塞式寫入決定本身被判定越權花用而降格——`affinity-data-pool.md` 本身未就此二列被回頭修改;更早:2026-08-05 第一輪更新:MAJOR REVISION NEEDED(24 項阻擋),同一 session 內完成修訂,詳見同一份 review log;同日稍早,`/design-review cursor-highlight-state.md` 第十輪審查後修訂——滑鼠奪權子機制止損政策觸發,升級為 MAJOR REVISION;重新設計已於同一 session 內完成實作(重置觸發清單五項簡化為四項),待第十一輪覆核 + 已排程 spike 驗證校準值(見該 GDD Open Questions);Cross-System Obligations Registry 新增兩列〔下游預覽渲染義務、表面卸載前目標交接義務〕,並修正全域裝置狀態指示元件擁有者列的措辭(生命週期涵蓋要求,好感度視覺呈現 UI 補入候選),回應該輪 ui-programmer、ux-designer、game-designer、systems-designer、qa-lead、godot-specialist 六方審查發現;更早:2026-08-05 第九輪審查新增兩列〔表面類型標籤單一實例契約、全域裝置狀態指示元件擁有者待指派〕;2026-08-04 第八輪審查新增教學掛鉤依賴與運動無障礙孤兒義務兩列;2026-08-03,單一游標/高亮狀態系統 GDD 完成設計;另見 `/design-review affinity-data-pool.md` 第七輪審查新增的支援對話系統風險列)
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

《盲目於微光》是一款單人戰術戰棋+敘事策略遊戲,核心賣點是「好感度即戰場」——角色間的好感度直接轉譯為位置戰術規則(聯動加成/內鬨懲罰),同一份好感度數值池同時服務戰鬥端(即時強度讀取)與敘事端(累積軌跡讀取)。主角群固定 5 人,不透過招募擴充。已完成 5 輪概念原型(v1-v5)與 1 次戰役規模模擬,核心機制方向確認 PROCEED。本索引把概念文件的核心機制、隱含基礎設施、UI/敘事支撐系統拆解為 14 個可獨立設計的系統。

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | 好感度數值池(Delta Log) | Core | MVP | Approved(2026-08-10 第十二輪核准,見下方註記) | design/gdd/affinity-data-pool.md | 戰棋移動與交戰系統(2026-08-10 第九輪新增,窄介面依賴——僅需「陣亡通知」單一方法的呼叫契約,不需等待該系統其餘設計定案;不透過好感度—位置連鎖系統轉接以避免循環依賴,見 `affinity-data-pool.md` Dependencies) |
| 2 | 存檔系統(含跨規則集遷移) | Persistence | **Vertical Slice**(2026-08-25 自 MVP 降級,見檔頭裁決) | Approved(2026-08-13 第十五輪核准,見 `design/gdd/reviews/save-system-review-log.md` 第十五輪條目) | design/gdd/save-system.md | — |
| 3 | 單一游標/高亮狀態系統 | Core | MVP | Approved(2026-08-13 第十六輪核准,使用者裁決收斂,見 `design/gdd/reviews/cursor-highlight-state-review-log.md` 第十六輪條目) | design/gdd/cursor-highlight-state.md | — |
| 4 | 戰棋移動與交戰系統(含武器射程分層) | Gameplay | MVP | ✅ **Approved(2026-08-31 管理者裁決)** —— 與 #5 同一裁定:劑量裁決位階高於收斂規則,「連續零 BLOCKING 輪數 = 0」不再是不核准的理由。四輪發現全數同輪修畢,**無待清償 BLOCKING**。<br>🔴 **核准不解鎖實作,鎖在三處他方**:①**ADR-0001 仍為 `Proposed`**(卡核准門檻條件一:自列 6 項待驗證未做,⚠️ **2026-09-01 更正:其中僅 4 項需跑引擎探針**;條件四:架構總監覆核未對本 ADR 跑過,⚠️ **原寫「五份皆然」為假** —— 2026-08-24 已對 ADR-0003 執行過)——引用它的 story 一律判 BLOCKED;②**OQ-2 我方基準數值表無人擁有**;~~③**OQ-16(b) 敵方單位數上限無人擁有**~~ ⚠️ **2026-09-01 更正:③ 已於 2026-08-31 同日降級、不再列為鎖**(GDD 檔頭第 14 行已刪除線標註,本列落後一手)。**② 為本文件自列的「架構工作開始前必須解決」項**,故**仍不得移交 `/create-architecture`** —— 但理由已不是「差第五輪審查」。<br>**第五輪 `/design-review` 已取消**(劑量上限 2 輪,本文件已跑四輪)。<br>**前次狀態(追溯)**:Designed 尚未 Approved(2026-08-18)——`/design-system` 已於 2026-08-17 完成全部必要節 + Visual/Audio + UI + Open Questions;**已經歷四輪 `/design-review`**(第一輪 6 項、第二輪 5 項、第三輪 7 項、第四輪 6 項 BLOCKING-NOW,四輪皆判 NEEDS REVISION 且皆於同輪修訂落地,見 `design/gdd/reviews/tactical-combat-system-review-log.md`)。**目前無待清償 BLOCKING,但依 Phase 0b 收斂規則仍需連續兩輪 body-scoped 零 BLOCKING 才得判 Approved,故尚不得移交 `/create-architecture`**。第四輪的架構級契約已外移至 **ADR-0001**(`docs/architecture/adr-0001-tactical-query-atomicity-contract.md`,Proposed)<br>📌 **UX Flag**:本系統有實質 UI 需求。Pre-Production 須先跑 `/ux-design` 產出 UX spec,**再**寫 epic;實作故事引用 `design/ux/[screen].md`,不得直接引用本 GDD | design/gdd/tactical-combat-system.md | 單一游標/高亮狀態系統(2026-08-06 補上,回應 `/review-all-gdds` 發現該系統已被 `cursor-highlight-state.md` 施加至少 5 條硬性義務,但依賴圖從未登記);**好感度—位置連鎖系統(#5)的 `Φ` 輸出(2026-08-17 新增的反向依賴,見下方第 5 列註記)** |
| 5 | 好感度—位置連鎖系統(含陣亡處理) | Gameplay | MVP | ✅ **Approved(2026-08-31 管理者裁決)** —— 已跑完兩輪 `/design-review` 並依劑量裁決離開審查流程。第一輪 7 項 BLOCKING 同輪修訂;第二輪查核確認其中 6 項乾淨落實、第 7 項(變更面盤點過時)當輪修畢,三項新發現全部落在審查流程自己加的治理材料上、原始設計零發現。**477 行,超上限 77 行,已由管理者裁定記為明文例外、不拆**(見 `production/milestones/one-year-plan.md` 第六節②)。<br>**核准依據**:劑量裁決規則 2(第 2 輪殘留項降級為實作期處理)。`/design-review` 自身的收斂規則要求連續兩輪零發現、指向相反答案,**管理者裁決位階較高,收斂規則讓步** —— 此衝突已於第一輪就地裁定並記錄在案,本次為同一裁定的套用,非新例外。<br>殘留未決項皆已判定不阻擋實作:OQ-3(`amp` 量化,擁有者為 #6 卡牌系統)、OQ-6(死前 `Φ` 快照擁有權,只擋陣亡回饋呈現)、`Φ` 與 `enemy_advantage_pct` 的交叉校準(待首次可玩建置)、`_links` 建構時快取缺陷(已有紅色回歸測試釘住,見 `docs/registry/architecture.yaml` 的 `affinity_pairing_data_per_query_refetch`)。審查全紀錄見 `design/gdd/reviews/affinity-position-chain-review-log.md` | design/gdd/affinity-position-chain.md | 好感度數值池、戰棋移動與交戰系統。**⚠️ 雙向依賴(2026-08-17 補登):本系統同時是戰棋移動與交戰系統的上游——後者的傷害公式以本系統的 `Φ`(好感度—位置修正)為輸入,且 `Φ_max` 與 `enemy_advantage_pct` 負有硬性交叉校準義務(不得各自獨立調整)。本系統設計時須與 `tactical-combat-system.md` Dependencies 及 Open Questions OQ-1/OQ-15 對齊** |
| 6 | 技能卡牌系統(含好感度對話卡牌) | Gameplay | MVP(**範圍收窄 2026-08-25**:MVP 只需好感度對話卡牌這一種子類型;「完整卡牌技能池」是 `game-concept.md` 的 MVP 明確不做項) | Not Started | — | 好感度數值池、戰棋移動與交戰系統 |
| 7 | 章節/戰役結構 | Narrative | **Vertical Slice**(2026-08-25 自 MVP 降級,見檔頭裁決) | Not Started | — | 存檔系統、好感度數值池(2026-08-06 補上,回應 `/review-all-gdds` 發現該系統須呼叫 `affinity-data-pool.md` 的「前進戰役刻度」介面,但依賴圖從未登記) |
| 8 | 支援對話系統 | Narrative | MVP | Not Started | — | 好感度數值池、章節/戰役結構。⚠️ **2026-08-25 範圍降級的連帶處置**:章節/戰役結構已自 MVP 降級,本系統的上游因此在 MVP 階段懸空。**MVP 解法**:3 段支援對話以寫死的觸發點掛在 5 場手工關卡之間,不需要排程系統;對「排程於戰鬥之間」的完整依賴在垂直切片階段才回來。**設計本系統時不得因此去等章節/戰役結構定案。** |
| 9 | 好感度視覺呈現 UI | UI | MVP | Not Started | — | 好感度—位置連鎖系統、單一游標/高亮狀態系統 |
| 10 | 戰鬥 HUD | UI | MVP(**範圍收窄 2026-08-25**:MVP 只需驗收協議 1 要求的「預判標記」互動,其餘 HUD 元件留待垂直切片) | Not Started | — | 戰棋移動與交戰系統、單一游標/高亮狀態系統 |
| 11 | 支援對話 UI | UI | MVP | Not Started | — | 支援對話系統、單一游標/高亮狀態系統 |
| 12 | 教學/上手引導系統 | Meta | **Vertical Slice**(2026-08-25 自 MVP 降級,見檔頭裁決)。⚠️ **MVP 仍需一張手工教學關卡** —— 驗收協議 1 明文要求「新手測試者在教學關卡後的前 2-3 場戰鬥」;降級的是「引導系統」這套程式,不是那張關卡,關卡屬內容製作項而非系統 | Not Started | — | 戰棋移動與交戰系統、好感度—位置連鎖系統、技能卡牌系統、單一游標/高亮狀態系統 |
| 13 | 敘事解鎖與結局分支系統 | Narrative | Vertical Slice | Not Started | — | 好感度數值池、章節/戰役結構 |
| 14 | 活棋盤地形演變系統 | Gameplay | Vertical Slice | Not Started | — | 戰棋移動與交戰系統、章節/戰役結構 |

**（原硬性閘門,2026-08-11 第十二輪降級為建議事項,不再是 ⛔ 硬性阻擋)**:單一游標/高亮狀態系統有一個已用 spike 實測證實成立的缺陷(持續按住方向鍵/搖桿造成滑鼠奪權永久鎖死,見 `cursor-highlight-state.md` Known Confirmed Defects 節),第十輪同日修法經第十一輪判定不成立並正確撤回,撤回後無任何暫行防線。**使用者裁決:因《盲目於微光》為回合制戰棋、不需要即時操作反應,此缺陷對玩家體驗影響有限,原「解決前不得 Approved、不得進垂直切片」的硬性閘門降級為一般建議事項**——本系統不再因此缺陷被阻擋進度。子機制重新設計暫停,待手把硬體到位且有明確理由時再重啟,詳見 `cursor-highlight-state.md` Known Confirmed Defects 節與 Open Questions。

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
| **MVP** | `game-concept.md`「MVP 必要內容」5 項所需的最小系統集合。**9 個系統**:#1 #3 #4 #5 #6 #8 #9 #10 #11 | 首個可玩原型/正式 MVP 建置 | 優先設計 |
| **Vertical Slice** | 完整一個章節體驗所需,含劇情分支雛形與活棋盤演變。**5 個系統**:#2 #7 #12 #13 #14 | 垂直切片 | 次優先設計 |

*本專案角色規模固定為 5 人(2026-07-30 裁決),不存在因招募擴充角色數而新增的 Alpha/完整願景專屬系統——範疇分級表的 Alpha 與完整願景層級只涉及內容量與打磨程度,不涉及新系統。*

> **2026-08-25 範疇裁決(管理者)——本表的兩個層級以 `game-concept.md` 為權威來源。**
>
> **問題**:本檔案原將 14 個系統裡的 **12 個**標為 MVP,而 `game-concept.md`「MVP 定義」節
> 明列的 MVP 必要內容只有 5 項、範疇分級表寫 MVP 時程為「數週」。兩份都是專案正式文件,
> 而它們對「MVP 是什麼」的說法差了一個量級。原標記法的根因是**把「MVP 會碰到的系統」
> 全部算成「MVP 必需的系統」**,於是存檔、章節結構、教學系統都被拉進來。
>
> **裁決**:以 `game-concept.md` 為準。把該節 5 項必要內容逐項對照回系統,得 **MVP 9 個、
> 垂直切片 5 個**。降級的三個是 **#2 存檔系統、#7 章節/戰役結構、#12 教學/上手引導系統**;
> 另有兩個維持 MVP 但範圍收窄(#6 只做好感度對話卡牌、#10 只做預判標記),依據是
> `game-concept.md`「MVP 明確不做」清單已明文排除「完整卡牌技能池」。
>
> **理由**:概念文件的 MVP 帶有可量測的驗收協議,其唯一目的是驗證一個假說
> (「好感度佈局是通關的自然高效路徑」)。加上存檔與章節結構不會讓那個假說測得更準,
> 只會把第一次能玩到東西的時間往後推。
>
> ⚠️ **降級不等於那些工作白做。** #2 存檔系統的 GDD 已 Approved、兩份架構文件已完成
> (ADR-0003 已核准、ADR-0004 為草案)。存檔終究要做 —— 本裁決只認定**它不在通往可玩
> 版本的最短路徑上**,不影響已完成成果的效力。
>
> ⚠️ **降級的連帶處置(兩項,已就地寫入對應列,不得漏讀)**:
> (一)#8 支援對話系統的上游 #7 被降級,其 MVP 解法見該列;
> (二)#12 降級的是「引導系統」這套程式,**MVP 仍需一張手工教學關卡**,否則驗收協議 1
> 無法執行,見該列。

---

## Dependency Map

### Foundation Layer(無依賴)

1. 好感度數值池(Delta Log) — 幾乎所有玩法與敘事系統的共同資料來源(第三~六輪 design-review 裁決的「單一數值池、雙重讀取」架構核心)
2. 存檔系統 — 跨場次保存進度與 delta log,不依賴其他玩法系統定案內容即可先定架構
3. 單一游標/高亮狀態系統 — 純輸入/UI 基礎設施,技術方向已在概念文件定案(godot-specialist,第四輪)

### Core Layer(依賴 Foundation)

1. 戰棋移動與交戰系統(含武器射程分層) — 玩法本體,已通過三輪原型驗證。**依賴:單一游標/高亮狀態系統**(2026-08-06 補上,見 Cross-System Obligations Registry 該系統對本系統施加的義務)
2. 好感度—位置連鎖系統(含陣亡處理) — 依賴:好感度數值池(讀取)、戰棋移動與交戰系統(讀取站位/陣亡事件)
3. 技能卡牌系統(含好感度對話卡牌) — 依賴:好感度數值池(寫入)、戰棋移動與交戰系統(卡牌效果作用於戰鬥狀態)
4. 章節/戰役結構 — 依賴:存檔系統(章節進度需持久化)、**好感度數值池**(2026-08-06 補上——須呼叫「前進戰役刻度」介面,見 Cross-System Obligations Registry)

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

> **2026-08-25:Order 欄是穩定編號,不是現在的施作順序。** 本次範疇裁決把 #2、#7、#12
> 降級為垂直切片,但**編號刻意不重排** —— 全庫多處以「Order N」指路,重排會讓那些引用
> 靜默指向別的系統。**讀法**:依 Order 由小到大進行,遇到標 `Vertical Slice` 的列直接跳過。
> MVP 的實際施作順序因此是 1 → 3 → 4 → 5 → 6 → 8 → 9 → 10 → 11。
| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | 好感度數值池(Delta Log) | MVP | Foundation | systems-designer | M |
| 2 | 存檔系統 | **Vertical Slice**(2026-08-25 降級) | Foundation | systems-designer, engine-programmer | M |
| 3 | 單一游標/高亮狀態系統 | MVP | Foundation | ux-designer, gameplay-programmer | S |
| 4 | 戰棋移動與交戰系統(含武器射程分層) | MVP | Core | game-designer, systems-designer, ai-programmer | L |
| 5 | 好感度—位置連鎖系統(含陣亡處理) | MVP | Core | game-designer, systems-designer | L |
| 6 | 技能卡牌系統(含好感度對話卡牌) | MVP(僅對話卡牌) | Core | game-designer, systems-designer | M |
| 7 | 章節/戰役結構 | **Vertical Slice**(2026-08-25 降級) | Core | narrative-director, game-designer | S |
| 8 | 支援對話系統 | MVP | Feature | narrative-director, game-designer | M |
| 9 | 好感度視覺呈現 UI | MVP | Presentation | ux-designer, ui-programmer, art-director | M |
| 10 | 戰鬥 HUD | MVP(僅預判標記) | Presentation | ux-designer, ui-programmer | S |
| 11 | 支援對話 UI | MVP | Presentation | ux-designer, ui-programmer | S |
| 12 | 教學/上手引導系統 | **Vertical Slice**(2026-08-25 降級) | Polish | ux-designer, game-designer | S |
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
| 陣亡配對的讀取依函數性質拆分:**深度/強度讀取**(敘事深度、戰鬥強度)須以陣亡當下的 `t_query`(`t_death(p)`)呼叫,不得使用預設的呼叫當下 `t_now`;**形狀特徵讀取**則相反,須用預設的呼叫當下 `t_now`,不得凍結於 `t_death(p)`——陣亡後的追憶寫入(見 affinity-data-pool.md Edge Cases「陣亡後的寫入」)必須被形狀讀取看見,才能兌現第 175 列的緩解義務(2026-08-10 第八輪裁決拆分,回應 `/review-all-gdds` F3-1 發現原「任一讀取函數」無差別套用會讓陣亡後的緩解在敘事端結構上永遠不可見) | affinity-data-pool.md Dependencies + Core Rules #3(第七輪新增,2026-08-10 第八輪拆分) | 敘事解鎖與結局分支系統、好感度—位置連鎖系統 | 兩系統的 GDD 對陣亡配對明確採用「深度/強度用 `t_death(p)`、形狀用 `t_now`」的雙規則,並各有對應 Acceptance Criteria(見 affinity-data-pool.md AC-62) |
| `pure_combat_floor` 只保證數學可達,不保證玩家讀成「不同形狀」而非「較差」;`低信心(low_confidence)` 是弱證據標記,不是退回單軸判定的訊號。**深度軸定性(2026-08-10 第八輪裁決,回應 C-2)**:`narrative_depth_read` 已重新定性為服務中盤解鎖判定的量,不是形狀空間的一軸——結局判定須完全依賴分布/波動/順序三軸區辨。**結局資格閘改版(2026-08-10 第九輪,回應對抗性覆核發現原深度資格閘門檻未定義且與 `game-concept.md` 範例互斥)**:資格閘本身自「比較 `narrative_depth_read` 與 `pure_combat_floor`」改為「比較 `n(p)` 與新 Tuning Knob `n_gate_min`」,`pure_combat_floor` 僅保留其原本職責(結局深度門檻上限),不再兼任資格閘門檻(見 affinity-data-pool.md「形狀特徵集合與 Track B 形狀空間的對應」) | affinity-data-pool.md Dependencies + Formulas 3f(第三、七輪;2026-08-10 第八輪補充深度軸定性;第九輪改版資格閘) | 敘事解鎖與結局分支系統 | 該系統 GDD 明確處理「深度地板值校準」(僅適用中盤解鎖判定)、「`n_gate_min` 結局資格閘校準」與「順序軸低信心情境」三項因應策略,且結局區辨邏輯完全建立在分布/波動/順序三軸上,不得以深度純量或 `pure_combat_floor` 作為結局資格或結局之間的區辨依據 |
| 序列化生命週期通知介面(begin/end)須於**任何存在非原子視窗的執行模型下**提供(2026-08-10 第八輪修正本欄位措辭,回應 `/review-all-gdds` 一致性驗證發現 A-5——原措辭「須於非同步存檔架構下提供」與本列關閉條件「不論本系統執行模型是否引入背景執行緒」自相矛盾),**自本輪起為權杖式**(`begin` 回傳不透明權杖,`end` 須帶入同一權杖釋放,支援重疊視窗——見 `affinity-data-pool.md` Core Rules #6),且旗標(存活權杖集合)本身須執行緒安全 | affinity-data-pool.md Dependencies + Core Rules #6(第六、七輪;2026-08-10 第八輪升級為權杖式) | 存檔系統 | ✅ **2026-08-06 由 provisional 轉為確定需要**——`design/gdd/save-system.md` Core Rules #5 原宣稱分步遷移模型「不需要回頭補上此介面」的結論不成立,已修正為「遷移期間仍須通知」,不論本系統執行模型是否引入背景執行緒。`affinity-data-pool.md` Edge Cases/AC-47 已同步擴大範圍涵蓋「還原/遷移」方向。**2026-08-10 第八輪追加**:`save-system.md` 對每一個產生非原子視窗的操作(不論屬於哪一個槽)皆須明確指派各自的 begin/end 權杖,不得共用,且 AC-68/AC-72 涵蓋重疊視窗情境。~~**序列化格式本身(Resource/.tres vs 自訂格式)仍是 Open Question**~~ → **2026-08-18 已定案**:`ADR-0003`(`docs/architecture/adr-0003-save-system-serialization-format-and-type-safety.md`,Proposed)選定 `var_to_bytes()`/`bytes_to_var(bytes, false)` 二進位 Variant 序列化,拒絕 Resource/.tres 與 JSON。本列的介面義務本身當時即已不等待該決策,現在該決策也已做出;**權杖式介面的消費端實作見 `ADR-0004` 機制六**(四條終止路徑),`affinity-data-pool.md` 側的權杖機制實作見 `ADR-0002` 機制七(單調遞增 int + 無條件 Mutex)。三份 ADR 皆為 `Proposed`,尚未 `Accepted` |
| AC-4(呼叫圖分析驗證寫入介面呼叫點恰為三處)須在承接系統有實際程式碼後補跑 | affinity-data-pool.md Acceptance Criteria 第 L 節 | 技能卡牌系統、支援對話系統、章節/戰役結構(三者皆須完成實作) | `producer`/`qa-lead` 於三系統整合驗收里程碑追蹤並執行,執行前不計入好感度數值池自身 DoD |
| AC-47(存檔進行中拒絕寫入,含還原/遷移方向)須在存檔系統架構定案後補跑 | affinity-data-pool.md Acceptance Criteria 第 L 節 | 存檔系統 | ✅ **2026-08-06 由 provisional 轉為確定需要**,理由同上一列——AC-47 判準已改為「該執行模型是否存在非原子視窗」,分步遷移模型下此 AC 對遷移的讓出視窗生效(不判定 N/A),唯有真正的同步阻塞式一般寫入路徑仍判定 N/A。待 `/create-architecture` 階段選定具體實作後補跑 |
| 單一游標/高亮狀態的裝置權威判定與高亮渲染規則不限棋盤格,適用於所有具懸停/游標目標的 UI 表面,下游 UI 系統不得各自重新實作一套邏輯 | cursor-highlight-state.md Core Rules #7 + Dependencies(2026-08-03 新增) | 好感度視覺呈現 UI、戰鬥 HUD、支援對話 UI | 三系統的 GDD 皆讀取單一游標/高亮狀態系統的共用介面決定高亮顯示,不自行實作裝置權威判定 |
| 游標指向的目標(棋盤格上的單位)失效時(死亡/被移動),呼叫方須呼叫單一游標/高亮狀態系統新增的「標記目前目標為待重新解析」介面,不得放任舊高亮視覺原樣顯示。**2026-08-06 擴大義務範圍(回應 `/review-all-gdds` Scenario Walkthrough 發現、使用者裁決)**:呼叫方須檢查該介面回傳值——若回傳「已過期,未套用」(代表玩家已在偵測與呼叫之間導覽離開該目標),呼叫方不得視為已妥善處理,須保有於玩家日後再次導覽回該目標時重新偵測並重新呼叫本介面的機制,或在自己的確認/選定前置檢查中獨立核對該目標的遊戲語意是否仍合法 | cursor-highlight-state.md Core Rules #2 + Edge Cases(2026-08-04 新增,`/design-review` 完整模式第三輪審查後;2026-08-06 擴大回應競態防呆靜默丟棄漏洞) | 戰棋移動與交戰系統 | 該系統 GDD 的 Detailed Rules 或 Edge Cases 明確定案單位死亡/移動時呼叫本介面的時機與呼叫時序,**且明確定案「已過期,未套用」回傳值的重驗處理機制**,並在其 Dependencies 章節回應此義務 |
| 「表面類型標籤」(見 cursor-highlight-state.md Core Rules #1)必須是單一共用列舉的成員,任何下游系統新增自己的表面類型時須在此列舉新增對應成員,不得自行發明字串或獨立型別 | cursor-highlight-state.md Core Rules #7 + Dependencies(2026-08-04 第七輪新增,回應 ui-programmer 審查發現) | 好感度視覺呈現 UI、戰鬥 HUD、支援對話 UI、戰棋移動與交戰系統(四者皆為單一游標/高亮狀態系統的下游依賴方) | 四系統的 GDD 皆引用同一份共用列舉作為「表面類型標籤」的合法值來源,不各自定義字串或獨立型別;列舉的實作位置與擁有者於 `/create-architecture` 定案後,本列關閉條件同步更新 |
| 滑鼠奪權漸進回饋機制(累積位移接近門檻時原生指標淡入)缺乏新手教學掛鉤——機制本身無真實世界玩家先例,直接坐落於本文件宣稱服務的支柱(玩家從不需要探測性輸入)之上 | cursor-highlight-state.md Open Questions(2026-08-04 第八輪新增,回應 ux-designer 審查發現、creative-director 裁決——第七輪已裁決本義務須從本輪起正式登記,不再以建議項循環) | 教學/上手引導系統 | 該系統 GDD 的 Detailed Rules 明確涵蓋此機制的教學/上手引導設計,並回應 `cursor-highlight-state.md` Open Questions 對應列 |
| 運動無障礙需求(motor accessibility,例如奪權門檻可調整性、瞄準輔助)先前僅口頭轉交 `design/ux/accessibility-requirements.md`,但該檔案不存在,義務先前從未登記於任何可追蹤位置 | cursor-highlight-state.md Open Questions(2026-08-04 第八輪新增,回應 ux-designer 審查發現、creative-director 裁決) | `design/ux/accessibility-requirements.md`(尚未建立;本專案目前無對應系統條目) | `design/ux/accessibility-requirements.md` 依 `.claude/docs/templates/accessibility-requirements.md` 範本實際建立,並回應本系統的像素門檻/死區依賴機制 |
| 單一游標/高亮狀態系統的滑鼠奪權漸進回饋機制(累積位移接近門檻時原生指標淡入)缺乏新手教學掛鉤,`/design-review` 已連續多輪列為建議項循環,第七輪 creative-director 明確裁決第八輪起須正式轉為登記義務 | cursor-highlight-state.md Open Questions(2026-08-04 第八輪新增,回應 ux-designer 審查發現、creative-director 裁決) | 教學/上手引導系統 | 該系統 GDD 的 Detailed Rules 明確涵蓋滑鼠奪權機制的教學掛鉤設計(觸發時機、呈現方式),並回應本義務 |
| 本系統核心機制(像素為單位的奪權門檻、死區依賴的零門檻方向鍵豁免)恰好命中運動無障礙(motor accessibility)典型關注項(瞄準輔助、時間調整、按鍵重新綁定),但 `design/ux/accessibility-requirements.md` 目前不存在,先前的轉交聲明僅存在於 review log、從未正式登記 | cursor-highlight-state.md Open Questions(2026-08-04 第八輪新增,回應 ux-designer 審查發現、creative-director 裁決) | `design/ux/accessibility-requirements.md`(尚待建立)的擁有者(ux-designer) | `design/ux/accessibility-requirements.md` 實際建立,且其 Motor Accessibility 章節回應本系統列出的關注項 |
| 「表面類型標籤」(見 cursor-highlight-state.md Core Rules #7)在任一時刻,同一標籤至多只能有一個實例掛載於場景樹中——若某類 UI 表面天生有多個同時存在的變體(例如同時提供完整檢視與縮圖檢視),須在共用列舉中為每個變體登記獨立成員,不得共用同一成員 | cursor-highlight-state.md Core Rules #7 + Dependencies(2026-08-05 第九輪新增,回應 ui-programmer 審查發現、綜合裁決收窄範圍) | 好感度視覺呈現 UI、戰鬥 HUD、支援對話 UI、戰棋移動與交戰系統(四者皆為單一游標/高亮狀態系統的下游依賴方) | 四系統的 GDD 皆確認自己的表面實例不違反單一標籤單一實例的約束,若天生需要多實例則在共用列舉登記獨立成員,並同步在 `mouse_reclaim_threshold_px_by_surface_type` 表新增對應門檻常數 |
| 全域裝置狀態指示元件(待機指示,例如手把/滑鼠圖示的明暗或啟用狀態)由哪個下游系統擁有/渲染尚未指派——第九輪已將待機指示規則從「四個表面各自顯示」改為「每裝置一個全域指示」,擁有者仍待確認;**第十輪修正措辭**:AC-27 要求無條件存在於任何使用本系統的畫面,候選擁有者若皆為畫面範圍元件則在構造上無法滿足,擁有者須為生命週期涵蓋所有游標系統畫面的節點 | cursor-highlight-state.md Open Questions + Visual/Audio Requirements(2026-08-05 第九輪新增,第十輪修正措辭,回應 ui-programmer、ux-designer 審查發現) | 戰鬥 HUD(候選,未定案)、支援對話 UI、好感度視覺呈現 UI(第十輪新增候選,回應 ux-designer 發現該系統擁有的關係圖迷你地圖是高懸停歧義表面) | 相關下游系統的 GDD 明確指派此全域指示元件的擁有者(生命週期須涵蓋所有游標系統畫面)與呈現位置 |
| 讀取目前游標目標座標以渲染玩家可見預覽(移動範圍/攻擊射程預覽、好感度連線/關係圖預覽)的下游系統,須在渲染前查詢本系統的有效性旗標;旗標為無效(待重新解析)期間,該預覽須被抑制或以明確不確定佔位樣式呈現,不得渲染成確信樣式 | cursor-highlight-state.md Core Rules #2「下游預覽渲染義務」(2026-08-05 第十輪新增,回應帳本 L1 連續四輪未處置達自動升級門檻、game-designer/ux-designer/ui-programmer 三方收斂發現) | 戰棋移動與交戰系統、好感度視覺呈現 UI | 兩系統的 GDD 皆定案預覽渲染前查詢有效性旗標的邏輯,並各自新增對應驗收標準 |
| 若下游 UI 表面自身即為目前游標目標所屬的表面類型,須在卸載/關閉前呼叫單一游標/高亮狀態系統的「標記目前目標為待重新解析」或「設定新目標」介面完成交接,不得直接卸載而不通知。**觸發情境明文擴充涵蓋存檔讀取導致表面內容整批替換(2026-08-11 第六輪新增,回應對抗性覆核發現 F2-2)**:不只是玩家主動切換畫面或單一目標局部失效(單位死亡/移動),存檔系統讀取存檔導致目前表面被整批替換時同樣適用——責任歸屬於呼叫存檔系統讀取介面、擁有游標目標所在表面的下游系統(見 `cursor-highlight-state.md` Core Rules #7 兩種進入情境〔甲:舊表面存在時讀檔;乙:無舊表面時讀檔,複用 Core Rules #6 初始狀態流程〕的完整定案),不歸屬存檔系統或游標系統本身(兩者皆聲明不理解遊戲實體語意)。**觸發情境再擴充涵蓋讀檔取消(2026-08-12 第七輪新增,回應對抗性覆核 systems-designer 發現——`save-system.md` Core Rules #5 路徑〔三〕自己明文點名「非互動式載入過場被取消」為真實情境,但第六輪定案只涵蓋甲/乙兩條前進路徑,未涵蓋這條回頭路)**:新增**(丙)讀檔流程被取消、返回原表面**——若已執行「標記目前目標為待重新解析」之後讀檔中止(玩家取消、或存檔系統回傳拒絕讀取/「該槽處理中」),而原表面未被拆除或已還原,呼叫方**必須**在返回互動式畫面之前重新呼叫「設定新目標」完成收尾(原目標仍有效時得直接沿用原值),不得讓游標停留在待重新解析狀態返回一個可互動畫面 | cursor-highlight-state.md Core Rules #7「表面卸載前的目標交接義務」(2026-08-05 第十輪新增;2026-08-11 第六輪擴充觸發情境;**2026-08-12 第七輪新增丙分支 + AC-61/62/63a/63b**(2026-08-13 第十三輪 AC-63 拆分為 63a/63b,並明文排除 `save-system.md` 路徑四不落入丙分支〔分支路由結論視同成功、走甲/乙,但呼叫方仍會收到可區分結果並負有告知義務,2026-08-13 第十四輪修正措辭,不再宣稱「對呼叫方透明」〕,見該文件 Core Rules #7)) | 好感度視覺呈現 UI、戰鬥 HUD、支援對話 UI、戰棋移動與交戰系統 | 四系統的 GDD 皆確認自己的表面卸載邏輯包含此交接呼叫,且戰棋移動與交戰系統(或承接讀檔流程編排的系統)的 GDD 須確認**甲/乙/丙三種**存檔讀取進入情境皆已處理(**含取消路徑的收尾呼叫**) |
| 下游表面呈現的三種可辨識視覺狀態(一般高亮、待重新解析、滑鼠奪權漸進回饋)須跨系統一致——同一種狀態在不同下游表面上的呈現邏輯不得互相矛盾或各自發明額外的中間狀態(2026-08-04 第七輪 review 曾提出此建議項,但在第八輪的遺留清單中無聲消失,未經解決或明文延期,第九輪回應 ux-designer 審查發現正式補回登記) | cursor-highlight-state.md Visual/Audio Requirements + AC-48/AC-49(2026-08-05 第九輪補回登記) | 好感度視覺呈現 UI、戰鬥 HUD、支援對話 UI、戰棋移動與交戰系統 | 四系統的 GDD 皆確認自己對三態視覺的呈現邏輯與本系統定義的三態一致,不各自發明額外的中間視覺狀態 |
| 下游 UI 不得允許玩家在未看到結構化錯誤原因的情況下重試同一個已知失敗的操作而不告知後果(2026-08-06 第四輪新增,回應 game-designer 審查發現——save-system.md 對存檔管理 UI 施加的八項硬性義務先前零列登記於本表,重演本表創建理由本身要防止的失敗;2026-08-07 第五輪拆分自原合併列,回應 game-designer 審查發現——原列同時綁定本義務與下一列的四類區分呈現義務,但關閉條件只驗證後者,本義務可被靜默視為已清償) | save-system.md Interactions with Other Systems「最低呈現契約」 | 好感度視覺呈現 UI / 未來的存檔管理 UI | 該系統 GDD 的錯誤呈現流程明確包含「重試前必先向玩家揭露結構化錯誤原因與後果」的設計,不存在任何無告知即可重試的路徑 |
| 須將四類拒絕原因(`DATA_CORRUPTED`/`MIGRATION_FAILED`/`VERSION_TOO_NEW`/`SEMANTIC_VALIDATION_FAILED`)以玩家可理解的方式區分呈現,不得統一顯示成單一「讀取失敗」訊息(2026-08-06 第四輪新增,回應 game-designer 審查發現;2026-08-07 第五輪拆分自原合併列) | save-system.md Interactions with Other Systems「最低呈現契約」 | 好感度視覺呈現 UI / 未來的存檔管理 UI | 該系統 GDD 的錯誤呈現設計明確區分四類拒絕原因,不得合併顯示 |
| `VERSION_TOO_NEW` 須框為「可回復」(切回較新版本遊戲即可繼續讀取),不得與資料損毀使用相同措辭或視覺樣式 | save-system.md Interactions with Other Systems | 好感度視覺呈現 UI / 未來的存檔管理 UI | 該系統 GDD 明確區分 `VERSION_TOO_NEW` 與其他三類拒絕原因的呈現樣式與措辭 |
| 遷移進行中(「待遷移」狀態)須呈現明確的進行中/忙碌指示,不得表現為無回應的凍結畫面;可透過存檔系統的遷移進度查詢介面呈現「第 X 步/共 Y 步」的真實進度 | save-system.md Interactions with Other Systems + Core Rules #15 | 好感度視覺呈現 UI / 未來的存檔管理 UI | 該系統 GDD 明確設計遷移進行中的進度/忙碌呈現,並串接存檔系統的進度查詢介面 |
| 互動式情境(例如存檔槽瀏覽器懸停預覽)不得呼叫會觸發遷移鏈的完整讀取介面,須改用 manifest-only 輕量讀取介面;只有明確標示為「載入存檔」的非互動式載入過場,才可呼叫會觸發遷移的完整讀取介面 | save-system.md Core Rules #5 + Interactions with Other Systems | 好感度視覺呈現 UI / 未來的存檔管理 UI | 該系統 GDD 的存檔槽瀏覽器等互動情境明確走 manifest-only 介面,載入過場明確走完整讀取介面,兩者不得混用 |
| 遭拒存檔(「拒絕讀取」狀態,舊稱「遷移失敗」——2026-08-07 更名並擴大進入條件涵蓋不限遷移的一般位元腐蝕)須提供唯讀存取入口供玩家檢視/匯出,含**依實際回退來源分三級**的主動告知義務(2026-08-09 修正,回應 `/review-all-gdds` 發現本列沿用已被 save-system.md 第五輪判定為「主動誤導式資料遺失」的舊版兩分支文案——舊版「唯讀資料可正常讀取時一律告知『歷史已完整保存』」在回退命中創世存底時字面不實)——**(甲)**回退命中 `.dat` 或 `.prev.bak`(高完整度來源):告知「此槽的完整歷史已安全保存,可隨時檢視或匯出」;**(乙)**回退命中創世存底 `.pre_migration.bak`(可能遺漏大量後續進度):**不得**使用「完整歷史已安全保存」字樣,須告知「已保存這個存檔較早版本的完整快照,可能不包含之後的部分進度」;**(丙)**全部回退來源皆已損毀:告知「此槽的備份本身也已損毀」,不得呈現任何「已安全保存」字樣。**判斷依據(2026-08-10 第八輪釐清,回應 `/review-all-gdds` 驗證發現 B-2——甲/乙的區分讀取唯讀存取介面回傳的「命中來源類別」中繼資訊 AC-69;丙不經由此欄位判斷,AC-69 本身只定義兩個類別,丙是唯讀存取介面走的另一條回傳通道:AC-53 定義的「存底本身無法讀取」結果**):下游 UI 先檢查唯讀存取介面的回傳是否為 AC-53 的「無法讀取」結果(是則丙),否則讀取 AC-69 的「命中來源類別」欄位判斷甲或乙。**復原前景語句(2026-08-10 第八輪新增,見 save-system.md Interactions「復原前景語句義務」)**:與甲/乙/丙分級**正交**的另一維度,依「是否有已定義的自動痊癒路徑」二分,不合併為甲/乙/丙之外的第四級 | save-system.md Interactions with Other Systems + Core Rules #13(Player Fantasy「此取捨的殘餘成本」第五、八輪修訂) | 好感度視覺呈現 UI / 未來的存檔管理 UI | 該系統 GDD 的拒絕讀取狀態呈現明確包含甲/乙/丙三分支主動告知邏輯(不是條件式二分)、丙的判斷依據為 AC-53 而非 AC-69 欄位、以及與分級正交的復原前景語句,且不呈現「繼續等待 vs 放棄」形式的持續性選擇 |
| 章節/戰役結構系統定案後,自動存檔的實際觸發點清單(例如每場戰鬥結束、每章開始/結束)須回填 save-system.md | save-system.md Dependencies | 章節/戰役結構 | 章節/戰役結構 GDD 定案自動存檔觸發點清單,並回填 save-system.md 對應段落 |
| 若採 Resource 子類別實作地形規則資料且存在跨格共享子資源,須遵循 `duplicate_deep(Resource.DEEP_DUPLICATE_ALL)` 深層複製紀律,並先判斷是否需保留跨格共享語意再決定存檔快照做法(整個地形資源圖單次遍歷,或逐格獨立) | save-system.md Dependencies + Open Questions | 活棋盤地形演變系統 | 該系統 GDD 明確處理跨格共享語意判斷,存檔快照做法與此判斷一致 |
| 系統觸發的好感度數值池寫入(劇情事件)不得使任何配對產生無代價的單調惡化——若某劇情事件對配對寫入負向變化,玩家在該事件之後的劇情進程中必須仍有主動行為(好感度對話卡牌或支援對話)可以緩和或翻轉此變化,不得存在玩家無法選擇不遭遇、事後也無任何緩解路徑的單向懲罰式寫入(2026-08-06 新增,回應 `/review-all-gdds` 跨文件審查發現、使用者裁決,見 `game-concept.md`「寫入來源封閉性」)。**陣亡情境下的兌現方式(2026-08-10 第八輪裁決新增,回應 F3-1)**:若緩解前配對成員陣亡,緩解仍算數——以追憶形式寫入(限支援對話/劇情事件來源,見 affinity-data-pool.md Edge Cases「陣亡後的寫入」),由形狀特徵讀取(用 `t_now`,見上方第 150 列)看見,但不回補深度讀值(凍結於 `t_death(p)`)。本約束不因陣亡而豁免 | game-concept.md 獨特賣點(第六輪裁決,2026-08-06 修訂;2026-08-10 第八輪擴充陣亡情境) | 章節/戰役結構、支援對話系統、技能卡牌系統(需提供對應的緩解/翻轉路徑) | 章節/戰役結構 GDD 定案劇情事件的好感度寫入規則時,明確確認每個負向劇情事件皆有對應的玩家可主動觸發之緩解路徑存在於支援對話系統或技能卡牌系統的既有機制內,且該確認涵蓋配對成員陣亡後仍可透過追憶形式緩解的情境 |
| 以**真正單調不可逆**形狀特徵(`total_churn`/`reversal_count`,**2026-08-11 第七輪修正——`source_absence` 已移出此清單,見下方新增列**)為條件、會導致某段獨佔敘事內容永久關閉的閘門觸發時,必須在觸發當下或觸發前對玩家明確揭露「這個選擇會關閉某條路線」的事實本身(不要求揭露會關閉哪個具體結局的細節),不得靜默鎖死(2026-08-06 新增,回應 `/review-all-gdds` 跨文件審查發現敘事可達性硬性約束與 Track B 交付項第4條的字面矛盾、使用者裁決收窄約束範圍,見 `game-concept.md`「敘事可達性硬性約束」範圍排除與揭露義務段落) | game-concept.md 獨特賣點(第六輪裁決,2026-08-06 修訂;2026-08-11 第七輪收窄適用特徵範圍) | 敘事解鎖與結局分支系統 | 該系統 GDD 的解鎖/分支判定邏輯明確包含觸發前揭露機制,並確認揭露時機(事件觸發當下或觸發前)與呈現方式 |
| **`source_absence`(2026-08-11 第七輪新增,D-1 修法;**2026-08-12 第七輪 `/design-review` 修正為逐(配對, 來源)判定**,回應對抗性覆核 narrative-director 發現原全稱宣稱有具體反例)**:拿 `source_absence` 判定互斥獨佔內容,僅得於戰役終局判定當下呼叫一次,不得在戰役中途做「永久關閉」式的即時宣告。**中途呈現依該(配對, 來源)組合的實際可逆性分兩類,不得一概而論**:**(甲)可逆組合**——僅能以可逆的事實呈現(例如「至今未曾透過此來源互動」),不得宣稱永久關閉;此呈現為**許可非強制**,沉默不構成失格。**(乙)玩法結構已永久封鎖的組合**——任何使來源 X 對配對 p 永久不可寫入的事件發生後(**權威登記處見 `affinity-data-pool.md` 3g「全作用域封鎖成因登記處」,2026-08-12 第八輪新增,本列不複述清單,依 single-source-of-truth 規則單向指標**),該組合自該時點起為**真正的單調不可逆特徵**,適用上一列的豁免資格,且揭露為**強制**;但揭露方式**不採**上一列的「這個選擇會關閉某條路線」式結算語彙,須改以**角色語言陳述事實、不使用關閉語言**(使用者裁決 U-2 丙案,例如「你和她之間,再也不會有並肩作戰時的那種話了」),不得使用「永久關閉/已無法達成/錯過了」等結算語彙,亦不得暗示玩家仍可透過該來源互動;**此語氣僅陣亡成因適用,其餘成因的語域由承接系統依情境決定,不得套用哀悼語域,但同受本段前三項硬性限制約束**(見 `game-concept.md` D-1 修正二「結構規則/語氣基調」兩層拆分,2026-08-12 第八輪)。**`source_absence_se`(劇情事件分量)的呈現另須排除任何暗示玩家能動性的措辭**(劇情事件非玩家離散主動行為,見 `affinity-data-pool.md` 3g 語意範圍澄清) | `game-concept.md`「範圍排除與揭露義務」D-1 修法(2026-08-11)+ D-1 修法的三項修正(2026-08-12 第七輪)+ **D-1 修正一驗證範圍聲明與修正二兩層拆分(2026-08-12 第八輪)** + `affinity-data-pool.md` 3g「可逆性的正確範圍」與「全作用域封鎖成因登記處」+ AC-80/AC-81 | 敘事解鎖與結局分支系統、好感度視覺呈現 UI | 該系統 GDD 的獨佔內容判定邏輯明確僅於終局呼叫 `source_absence`;**且判定邏輯涵蓋 `affinity-data-pool.md` 3g 登記處當下的全部列(非其 GDD 定案當下的快照——登記處新增列時本系統須回頭確認涵蓋,此為持續性義務,2026-08-12 第八輪明文)**;甲類組合的中途呈現(若有)採用非永久性措辭;乙類組合的強制揭露採角色語言陳述、不含結算語彙(陣亡)或依情境決定的非哀悼語域(其餘成因);`source_absence_se` 呈現不含能動性措辭。通過 `game-concept.md` 常設風險段落既有的沉默可辨識性重測協定不受本列影響(兩者為獨立驗證維度) |
| **存檔回寫持續失敗的主動告知與唯讀存取入口(2026-08-12 第七輪 `/design-review` 新增——第六輪標頭曾宣稱 AC-76 的呈現規範「已同步登記至本 Registry」,經本輪逐列查證該列**從未存在**,是與 `save-system.md` Dependencies 表格列同型的第六輪修訂宣稱高估,本輪實際補上)**:同一存檔槽連續兩次讀取嘗試皆因 Core Rules #5 路徑(四)的回寫 I/O 失敗而未完成時,下游 UI 須**同時**履行兩項義務:(一)呈現與「正常仍在待遷移、尚未嘗試過」及四類拒絕原因皆可明確區分的主動告知,不得讓玩家反覆讀檔卻感受不到任何回饋;(二)提供唯讀檢視/匯出入口(此時 Core Rules #13 唯讀存取介面已對該槽開放,使用者裁決 U-1 甲案),比照「拒絕讀取」狀態的既有規範含 AC-69 分級告知文案——**理由**:此情境下該槽的 `.dat` 通常完好無損,若只給一句錯誤訊息,本系統對資料完好的槽提供的保護會低於對資料已損毀的槽。**復原前景語句須與拒絕讀取三類區分**:須指向玩家可執行的動作(「這個槽的資料本身完好,只是目前無法寫入;釋放儲存空間或修正權限後,下次讀取即會自動完成」),不得使用「有機會在未來的遊戲更新後自動恢復」——這是唯一一處玩家動作確實有效的情境 | `save-system.md` Interactions with Other Systems「重複回寫失敗須主動告知」+ Core Rules #5 路徑(四)+ Core Rules #13 唯讀存取可用條件擴大 + AC-76/AC-77 | 好感度視覺呈現 UI / 未來的存檔管理 UI | 該系統 GDD 的存檔錯誤呈現流程明確涵蓋此第四類「非拒絕、非成功」結果,**且同時提供唯讀檢視/匯出入口(不只是錯誤訊息)**,並使用指向玩家可執行動作的復原前景語句,與四類拒絕原因及「該槽處理中」皆可區分 |
| 須於每場戰鬥/每章**開始時**呼叫好感度數值池的「前進戰役刻度」介面(不得於結束時呼叫),這是 `c_now≥1` 恆成立、`spread_ratio` 不出現 0/0 的唯一保證來源;並須定案「戰役刻度推進粒度」(以戰鬥數或章節數為單位)回填該文件 Tuning Knobs(2026-08-06 新增,回應 `/review-all-gdds` 跨文件審查發現此義務先前完全零登記) | affinity-data-pool.md Core Rules #1/#2 + Tuning Knobs + Open Question 6 | 章節/戰役結構 | 章節/戰役結構 GDD 明確定案呼叫時機(章節/戰鬥開始時)與刻度推進粒度,並回填 `affinity-data-pool.md` Tuning Knobs 與 Open Question 6 |
| 自動存檔觸發點清單與「前進戰役刻度」介面呼叫,兩者在章節/戰鬥開始時的相對順序須明確定案,且須驗證「載入存檔」路徑是否會重跑章節開場的刻度前進呼叫(2026-08-06 新增,回應 `/review-all-gdds` Scenario Walkthrough 發現——若定案為「先存檔後前進刻度」而載入路徑走捷徑不重跑開場邏輯,該章的刻度前進會永久遺失,污染 `spread_ratio`/`segment_profile`) | save-system.md Dependencies + affinity-data-pool.md Core Rules #2(交會點,無單一權威來源) | 章節/戰役結構 | 章節/戰役結構 GDD 明確定案兩次呼叫的相對順序,並確認載入路徑的行為,回填 `save-system.md` Dependencies 第 170 列與 `affinity-data-pool.md` Open Question 6 |
| 角色陣亡當下須呼叫好感度數值池新增的「陣亡通知」介面,傳入該角色識別碼——這是 `affinity-data-pool.md` Core Rules #3 `t_death(p)` 凍結規則唯一的資料來源,先前完全零介面定義(2026-08-10 第九輪新增,回應對抗性覆核 game-designer/systems-designer/qa-lead/godot-specialist/performance-analyst 五方獨立收斂發現) | affinity-data-pool.md Core Rules #1「陣亡標記表」+ Dependencies(第九輪新增) | 戰棋移動與交戰系統 | 該系統 GDD 明確定案角色陣亡判定時機,並在該時機同一結算步內呼叫本介面;同時確認與同結算步內其他好感度寫入呼叫(例如殺招觸發的好感度對話卡牌結算)的呼叫順序符合設計意圖(見 `affinity-data-pool.md` Core Rules #2「陣亡配對的寫入限制」的順序論證) |
| 結局資格閘改採 `n(p) ≥ n_gate_min` 判定,不得使用 `narrative_depth_read` 或 `pure_combat_floor`;未過閘配對須沉默或給予結構相異的內容,禁止共用淡化版 fallback(義務 A);過閘餘裕不得作為品質/語氣槓桿,中盤解鎖判定與結局資格閘須用不同詞彙描述(義務 B);至少一條結局/支線判定輸入須來自陣亡配對追憶寫入造成的形狀差異(2026-08-10 第九輪新增,回應 creative-director 對 Track B 交付項第 3 條範圍的裁決)。**沉默處置的驗證義務(2026-08-10 第十一輪新增,回應對抗性覆核 narrative-director 發現義務 A 允許的「沉默」處置此前未經任何驗證機制涵蓋)**:若承接系統選擇沉默處置(而非結構相異的專屬片段),須通過 `game-concept.md`「常設風險」段落新增的第二個重測通過條件(讀者能區分「刻意沉默」與「內容缺漏」),不得未經此驗證即視為義務 A 已兌現 | affinity-data-pool.md Dependencies「結局資格閘義務」+ game-concept.md Track B 交付項第 3 條範圍裁決(第九輪)+ 常設風險通過條件擴充(第十一輪) | 敘事解鎖與結局分支系統 | 該系統 GDD 的結局/解鎖判定明確採用 `n(p)`/`n_gate_min` 作為資格閘、明確定案未過閘配對的沉默或專屬內容處置方式、明確採用不同詞彙區分中盤解鎖判定與結局資格閘、且至少一條判定輸入可觀測地依賴陣亡後追憶寫入的形狀差異;**若選擇沉默處置,須額外通過 game-concept.md 常設風險的沉默可辨識性重測** |
| **戰棋移動與交戰系統的所有對外查詢介面皆受其 Core Rules #10「對外查詢介面的共用義務」總則約束,下游渲染方不得自行快取查詢輸出並跨盤面變動沿用**(2026-08-17 第三輪 `/design-review tactical-combat-system.md` 新增,回應 BLOCKING-NOW F3-4——該文件連續三輪各自獨立撞到同一結構性缺口:查詢介面的數學定義不保證互動式 UI 的正確性,前兩輪逐一補個案條款,每次都漏掉下一個新增的介面,故第三輪改立總則)。具體義務:(一)**即時性**——輸出恆須等於「以呼叫/重繪當下的棋盤狀態從頭重新計算一次」的結果;實作可快取,但輸出不得偏離此斷言;**且任一改變某查詢正確答案的已提交結算邊界事件發生時,顯示中的輸出至少須被標記為過期,不得以過期輸出接受下一個玩家輸入**(2026-08-18 第四輪新增,回應 BLOCKING-NOW B-1:原條文只約束「若重繪則須正確」、卻明文不定案重繪時機,使「渲染一次、永不失效」的實作完全合規,卻精準重現規則要防的失敗模式);(二)**單一快照原子性**——跨幀計算須對計算開始時的同一份盤面快照完成;**且若一組查詢輸出被合併判讀為單一畫面呈現給玩家(並存疊加圖、`threat_range_all(E)` 的多敵聯集),該組視為同一次查詢、共用同一份快照,不得由對應不同時刻的多份快照拼接**(2026-08-18 第四輪新增,回應 BLOCKING-NOW B-2:原條文把原子性綁在「一次查詢」上,兩張各自正確但彼此不同時的疊加圖,合起來會對應不到任何真實存在過的盤面狀態);(三)**佔位資料所有權**——`occupied(tile)` 不得由場景/節點樹存在性導出,**亦不得由視覺/動畫狀態導出;該資料須隨任一改變單位邏輯位置或存活狀態的事件同步更新(陣亡、移動邏輯完成皆為實例,非窮盡)**(2026-08-18 第四輪擴大範圍,回應 BLOCKING-NOW B-1:原條文只點名陣亡一種觸發事件,AC-22 卻已有測試移動同步的向量,規範與驗收條件不對稱)。**另一項並存性義務**:敵方威脅範圍疊加圖須可與被操作單位自身的移動範圍疊加圖**同時可見**,不得實作為互斥的模式切換——該疊加圖的存在目的是讓玩家在評估候選落點時同時看到該落點是否受威脅,若須關掉移動範圍才能看威脅範圍,該用途即失效。**另一項呈現/教學義務(2026-08-18 第四輪新增)**:威脅範圍疊加圖**不得**被呈現、命名或教學為「絕對安全/絕對危險」的保證——它在視線軸上偏保守(高估)、在佔位軸上偏樂觀(低估,因 `reachable_set(e)` 受其他敵方單位當下站位限制,而該站位在敵方回合內會改變),見該文件 Formulas 公式四「保守性的邊界」 | tactical-combat-system.md Core Rules #10 + UI Requirements §1/§1a + Formulas 公式四 + AC-22(2026-08-17 第三輪新增,2026-08-18 第四輪擴充) | 戰鬥 HUD(#10);教學/上手引導系統(#12,僅適用上述呈現/教學義務);其餘讀取本系統查詢介面的下游渲染方同受約束 | 戰鬥 HUD GDD 明確確認其渲染流程不快取本系統查詢輸出跨盤面變動沿用(或雖快取但可證明滿足 Core Rules #10 a 項的輸出斷言)、並存疊加圖共用同一份快照、且威脅範圍疊加圖與移動範圍疊加圖可同時可見;#12 GDD 確認其教學涵蓋威脅範圍的近似性質;雙方並在其 Dependencies 章節回應此義務 |
| **技能卡牌系統(#6)的卡牌效果須為同步執行,不得於戰棋結算步進行中要求玩家輸入**(2026-08-18 第四輪 `/design-review tactical-combat-system.md` 新增,回應 BLOCKING-NOW B-1——該文件 Core Rules #5 宣稱結算步「硬性、不受平台/引擎排程影響」,但其步驟②c 呼叫的正是 #6 尚未設計的效果掛鉤點,而「請玩家選擇加成對象」一類的卡牌效果會在結算中途要求玩家輸入;同時 Core Rules #9 的「可暫緩」模型明文允許玩家在回合內交錯操作多個單位,兩者相乘會產生「結算停在②c 等待玩家選擇、玩家轉頭移動了另一個單位」的重入情境,而該文件此前沒有任何重入防護)。具體義務:需要玩家選擇作用對象一類的效果,其輸入須在本次結算**開始之前**完成;②c 執行期間不得阻塞等待玩家輸入。**若 #6 設計時確認某類效果無法滿足此契約,須回頭修訂 `tactical-combat-system.md` 的 Core Rules #11 與 AC-24,不得由 #6 單方面繞過** | tactical-combat-system.md Core Rules #11 + AC-24 + Dependencies #6 列 + Open Questions OQ-4(2026-08-18 第四輪新增) | 技能卡牌系統(#6,Not Started) | #6 GDD 明確確認其規劃的卡牌效果類型皆可滿足同步契約(或已依上述程序回頭修訂 Core Rules #11/AC-24),並在其 Dependencies 章節回應此義務 |
| 「與已陣亡角色的支援對話」是尚未設計的內容型別——好感度數值池的追憶寫入機制假設此類內容可能存在,但支援對話系統(Not Started)從未明確決定是否支援 posthumous 變體(2026-08-10 第九輪新增,回應對抗性覆核 game-designer 發現) | affinity-data-pool.md Dependencies「結局資格閘義務」段落(第九輪新增) | 支援對話系統 | 該系統 GDD 明確決定是否支援對已陣亡角色的支援對話,若支援則定案呈現形式(書信/回憶場景等);若不支援,「陣亡後的寫入」義務改由劇情事件單一通道承接,須回填 `affinity-data-pool.md` 對應段落 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 14 |
| Design docs started | **5**(2026-08-31 更新——新增好感度—位置連鎖系統;前次 4,2026-08-17 新增戰棋移動與交戰系統) |
| Design docs reviewed | **5**(2026-08-31 更新——好感度—位置連鎖系統已歷兩輪 `/design-review`,補計入;前次 4,戰棋移動與交戰系統已歷四輪;更前三份於 2026-08-09 核算時已各經歷至少一輪 `/design-review` 與該次 `/review-all-gdds`) |
| Design docs approved | **5**(2026-08-31 更新——同日兩份經管理者裁決核准:好感度—位置連鎖系統〔#5〕與戰棋移動與交戰系統〔#4〕;前次 3:好感度數值池〔第十一、十二輪〕、存檔系統〔第十五輪〕、單一游標/高亮狀態系統〔第十六輪〕)<br>✅ **本欄與 Status 欄自 2026-08-31 起不再分歧。** 2026-08-18 曾明文記載一項分歧:#4 雖無待清償 Blocking 卻不計入本數,因為 `/design-review` 收斂規則要求連續兩輪零 BLOCKING 而它為 0。**該規則已於 2026-08-31 由管理者裁決明文讓步**(劑量裁決明訂每份文件 ≤ 2 輪,收斂規則在該上限之下結構上不可能達成;管理者裁決位階較高),#5 與 #4 同批依此核准,分歧隨之消失。<br>🔴 **但「已核准」不等於「可以開始寫程式」,#4 是活生生的例子** —— 它的實作被 ADR-0001(`Proposed`)與兩張無人擁有的資料表擋著,詳見第 4 列。**本欄追蹤的是設計文件是否定案,不是實作是否解鎖,兩者不可互相推論。** |
| MVP systems designed | **4/9**(2026-08-31 更新——分子四項為好感度數值池、單一游標/高亮狀態系統、好感度—位置連鎖系統、戰棋移動與交戰系統,**四者現皆 Approved**〔後二者為同日管理者裁決〕。分子數不變、組成狀態改變。分母 9 見 Priority Tiers 的 2026-08-25 裁決。⚠️ 存檔系統雖已 Approved 但不再計入本欄,它現屬垂直切片層)<br>📌 **剩餘 5 個 MVP 系統尚未設計**:#6 技能卡牌、#8 支援對話、#9 好感度視覺呈現 UI、#10 戰鬥 HUD、#11 支援對話 UI |
| Vertical Slice systems designed | **1/5**(2026-08-25 更新——分母自 2 改為 5〔存檔系統、章節/戰役結構、教學系統降級進本層〕;分子為存檔系統,已 Approved) |
| ADRs written | **5**(2026-08-25 更新;本欄先前寫 4,漏計 ADR-0005 單一游標裝置權威輸入架構〔2026-08-18 建立〕) |
| ADRs Accepted | **2**(2026-08-25 更新——ADR-0002 好感度數值池、ADR-0003 存檔序列化格式,管理者同批裁決,專案首次有 ADR 離開 `Proposed`。ADR-0001/0004/0005 三份仍為 `Proposed`)。⚠️ 本欄先前寫 **0** 並附「尚無任何 ADR 可支撐 story 實作」——該句已不成立:引用 ADR-0002 的好感度資料層 story 現在可以動工 |
| 架構立場已登記(`docs/registry/architecture.yaml`) | **85**(2026-08-25 更新;10 state-ownership、11 interface contracts、29 API decisions、35 forbidden patterns)。⚠️ 本欄歷來落後於登記表,**數字有疑義時一律以 `docs/registry/architecture.yaml` 為準** |
| ADR 缺口清單剩餘項 | **2/6**(2026-08-25 更新——已撰寫:好感度數值池、存檔格式/型別、存檔原子寫入/遷移、**單一游標裝置權威輸入架構**〔ADR-0005,2026-08-18 建立,本欄先前漏計〕。尚未動筆:戰棋盤面演算法層、回合結構擁有權 + 缺席的 AI/遭遇系統——見 `docs/architecture/traceability-index.md`) |

---

## Next Steps

- [ ] Review and approve this systems enumeration
- [ ] Design MVP-tier systems first(use `/design-system [system-name]`)——依 Recommended Design Order 從「好感度數值池」開始
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when MVP systems are designed
- [ ] Validate the highest-risk systems with `/vertical-slice` before committing to Production
