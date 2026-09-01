# ADR-0001: 戰棋查詢介面原子性契約

## Status

Proposed

## Date

2026-08-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core(狀態管理與排程) |
| **Knowledge Risk** | **HIGH**(4.7 為 LLM 訓練截止後發布);**但本 ADR 所依賴的具體事實已於 2026-08-18 由 `godot-specialist` 對照 engine-reference 逐項查核通過** |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`、`breaking-changes.md`、`deprecated-apis.md`、`current-best-practices.md` |
| **Post-Cutoff APIs Used** | **無**。本 ADR 只使用 Godot 4.0 以來語意穩定的機制(`Dictionary`、`Vector2i`、`await`、`queue_free()` 的延後移除語意)。⚠️ **2026-09-01 `TD-ADR` 覆核補上一項本清單原先漏列的**:機制一實際使用的是**型別化** `Dictionary[Vector2i, int]`,而型別化容器是 4.4 引入(**此版本歸屬為 (C) 級推測,專案參考庫未記載引入版本**)。本欄結論「無 Post-Cutoff API」仍成立(4.4 在訓練截止之前),但支撐它的清單原先不完整 —— 而本 ADR 自列的待驗證第 (3) 項要驗的正是這個型別。4.6/4.7 的變更(Jolt 預設、D3D12 預設、輸入裝置 ID 重新編號、Control offset transforms)皆與本 ADR 無交集——本系統的可達格/視線計算為純格狀幾何,不觸及物理伺服器或渲染管線 |
| **Verification Required** | ✅ **2026-09-01:需要跑引擎的四項全部已驗證,四項全部成立,無一項推翻本 ADR。**<br>證據:`prototypes/adr0001-engine-probes-2026-09-01/`(逐支腳本 + 逐字 log + README)。<br>**(5) 已解除未查證**:GdUnit4 斷言 `push_error()` 的做法為 `assert_error(<Callable>).is_push_error(<message>)`,已實跑通過(見該目錄 `gdunit4_push_error/`)。🔴 **(6) 已可執行,且現況通過** —— 2026-09-01 窄範圍複驗更正:**本欄原寫「仍無從做(該系統尚無程式碼)」是錯的。** 實測 `src/` 有 **17 個 `.gd` / 3,791 行**,其中 `src/gameplay/battle/`(`battle_controller.gd` 591 行、`battle_loop.gd`、`battle_state.gd`、`turn_order.gd`)**就是結算路徑**。全庫 grep `call_deferred` / `CONNECT_DEFERRED` / `set_deferred`:**零命中**,唯一字面命中是 `src/ui/battle/battle_screen.gd:692` 一行**引用本禁令的註解**(亦即已有人在做這項人工檢查)。**本項為持續性檢查,非一次性驗證。**<br>⚠️ **這個錯的方向值得記住**:它把一個好消息(檢查做得到、而且是過的)寫成了做不到的藉口,而條件一「4 項需跑引擎、2 項不算缺口」的整套拆分就建立在這個 6 項判讀上。<br>⚠️ **執行過程本身有一個值得記住的插曲**:第 (4) 項的**第一版探針時序假設寫錯**,5 次 trial 中 4 次的查詢在結算真正發生前就恢復,回報「無結論」。**那是探針錯,不是引擎或 ADR 錯**;已改寫為「單一查詢迴圈 8 次恢復、結算刻意排在第 4 次」的形狀重跑,新版才是有效證據。舊版與捨棄理由記在該 README。**這正是本專案已登記的失效模式:假設錯誤的腳本會順利跑完、輸出漂亮數字、看起來完全正常。**<br>**額外查證所得(非原問題)**:`process_frame` 訊號在同一幀內**晚於** `_process()` 鏈觸發 —— 這是機制一的中止判定與機制二的結算走 `_process` 能協同成立的底層原因,本 ADR 原先未明講。<br>**原文如下(保留供追溯)**:(1) 確認 `queue_free()` 在 4.7.1 實際仍延後至幀尾生效(本 ADR 的 §機制三 以此為前提,雖已對照文件查核,仍建議實機以最小測試場景確認);(2) 跨幀展開若採 `await get_tree().process_frame`,須實測確認該 await 前後 `board_version` 的讀取行為符合本 ADR 的中止語意;**(3) 確認型別化 `Dictionary[Vector2i, int]`(struct-like key + 型別化容器)在 4.7.1 編譯無警告**;**(4) 實測「同幀可見性」順序保證——若結算發生在某跨幀查詢的 await 恢復點之前,該查詢恢復時必須讀到遞增後的 `board_version`(本 ADR 的中止語意隱含此假設,但未經實測)**;**(5) `settlement_in_progress` 卡死斷言的自動化測試(見 Validation Criteria 第 7 項)**;**(6) 程式碼審查明文檢查項:結算呼叫鏈中不存在任何 `call_deferred()` 或 `CONNECT_DEFERRED` 連線——此項無法靠搜尋 `await` 字樣抓到**(項次 3–6 為 2026-08-18 `godot-specialist` 驗證後新增) |

**引擎知識落差聲明**:`godot-specialist` 於 `/design-review tactical-combat-system.md` 第四輪針對本 ADR 涵蓋的四個面向逐項查核,結論為零 BLOCKING:(a) `queue_free()` 的幀尾延後移除語意在 4.6/4.7 未變,亦無新增的立即移除 API 使本 ADR 的邏輯佔位方案過時;(b) 巢狀 Resource 的 `duplicate()` 自 4.5 起不建議使用、應改用 `duplicate_deep()`(本 ADR 的版本戳記方案不複製盤面,故此項僅在未來若改採深拷貝快照時才相關);(c) 本 ADR 明確排除以 `PhysicsServer`/`RayCast` 實作視線,故 Jolt 預設化與本 ADR 無關;(d) 跨幀 Dijkstra 在 GDScript 中可正確實作,但需要本 ADR 提供的架構約束才能保證原子性——這正是本 ADR 存在的理由之一。

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None(本專案第一份 ADR) |
| **Enables** | 未來的「戰棋移動與交戰系統」實作 ADR/epic;戰鬥 HUD(#10)的渲染架構決策;技能卡牌系統(#6)的效果掛鉤介面設計 |
| **Blocks** | 戰棋移動與交戰系統的任何實作 epic——本 ADR 未 Accepted 前,`reachable_set`/`threat_range`/佔位資料的實作缺少定案的正確性機制 |
| **Ordering Note** | 本 ADR 定案的是**機制**;它所服務的**義務**由 `design/gdd/tactical-combat-system.md` Core Rules #10/#11 擁有。兩者的修訂方向是單向的:GDD 的義務變更須回頭檢查本 ADR 是否仍能滿足;本 ADR 的機制變更**不得**擴大或縮小 GDD 的義務。本 ADR 目前為 Proposed。<br>🔴 **2026-09-01 事實更正**:本欄原寫「`tactical-combat-system.md` 本身尚未經 `/design-review` 判定 Approved(第四輪後仍為 Designed),兩者應一併推進」。**該句已不成立** —— 該 GDD 已於 **2026-08-31 由管理者裁決 Approved**(依據:劑量裁決位階高於收斂規則;四輪發現全數同輪修畢、無待清償 BLOCKING;第五輪 `/design-review` 已取消。見 `design/gdd/systems-index.md` 第 4 列)。**因此「兩者應一併推進」不再適用:上游 GDD 已 Approved。**<br>⚠️ **但本 ADR 不是該 GDD 唯一的鎖**(2026-09-01 `TD-ADR` 覆核指出本句初稿寫成「單向卡在本 ADR」不準確,已更正):該 GDD 的實作**另受其自身的 OQ-2 阻擋**(我方基準數值表無人擁有 —— 非「等別人」,是沒人被指派;公式二無它無法實作),見該檔檔頭第 13 行。**即使本 ADR 今日核准,該 GDD 仍不得移交 `/create-architecture`。** |

## Context

### Problem Statement

`design/gdd/tactical-combat-system.md` 在連續四輪 `/design-review` 中,累積出三條關於「對外查詢介面必須滿足什麼」的規則(Core Rules #10 a/b/c 與 #11)。這些規則的**義務陳述**屬於設計範疇(玩家看到的東西必須等於實際結算的東西),但它們的**內部實現機制**——快照怎麼取、跨幀計算怎麼保持原子、重入怎麼防止、佔位資料由誰承載——是架構決策。

第四輪 `/design-review` 的 `creative-director` 綜整明確診斷了這個錯置造成的後果:該輪 15 項原始發現中,落在文件原生設計(Core Rules #1–#4/#7/#8、公式一至三、AC-1 至 AC-19)的數量為 **0**,連續四輪未再產生任何發現;100% 的發現落在第二至四輪由審查自己新增的治理層材料。診斷結論是「設計已收斂,治理層錯置」——這些架構級契約寫在 GDD 裡,就會被 `/design-review` 以設計審查的深度、每一輪、永遠地稽核下去,且每加一條通則就產生新的邊界供下一輪發現。

本 ADR 的目的是把機制搬到它該在的地方,使 GDD 只保留玩家可觀測的義務,審查職責隨之分流:GDD 的規則正確性由 `/design-review` 審,機制的架構合理性由 `/architecture-review` 審。

### Constraints

- **引擎**:Godot 4.7.1 / GDScript。無例外處理機制(無 try/catch),錯誤處理須以回傳值或 `push_error()` 表達。
- **`queue_free()` 的幀尾延後語意**:Godot 移除節點的慣用手法延後至當前幀結束才真正生效。這是引擎穩定的既有行為,不是某個版本的特性。
- **效能預算**:目標 60fps / 16.6ms(見 `.claude/docs/technical-preferences.md`)。棋盤尺寸上限與單場戰鬥敵方單位數上限**皆尚未定案**(見 `tactical-combat-system.md` OQ-16),故本 ADR 不得依賴任何具體規模假設。
- **零隨機承諾**:`tactical-combat-system.md` Core Rules #7 與 AC-9 要求傷害、敵方數值縮放、選路、可達格、威脅範圍在相同輸入下逐次呼叫結果完全相同,不得讀取亂數源、系統時間或幀計數器。本 ADR 的任何機制不得引入非決定性。
- **全手把對等**:無滑鼠假設、禁止 hover-only,因此「游標移動即檢視」是高頻查詢路徑,任何每次查詢的固定成本都會被放大。

### Requirements

本 ADR 須同時滿足 `tactical-combat-system.md` 的下列義務(義務原文以該文件為準,此處僅列出機制須支撐的內容):

1. **即時性(Core Rules #10a)**:任一查詢輸出恆等於「以呼叫/重繪當下的盤面從頭重算一次」的結果;且任一改變某查詢正確答案的已提交結算邊界事件發生時,顯示中的輸出至少須被標記為過期,不得以過期輸出接受下一個玩家輸入。
2. **單一快照原子性(Core Rules #10b)**:單一查詢的計算須對單一盤面快照完成;**且被合併判讀為單一畫面的一組輸出**(UI §1a 強制並存的移動範圍與威脅範圍疊加圖、`threat_range_all(E)` 的多敵聯集)**視為同一次查詢、共用同一份快照**,不得由對應不同時刻的多份快照拼接。<br>🔴 **2026-09-01 補述**:GDD 原句有三個子句,本點原先只轉述了第一句。漏述的是「**不得中途套用**」與「**須排入佇列**於計算結束後處理」。本 ADR 依該條末句的授權(論證見機制一該段)裁定改採**中止重算**而非佇列;「不得中途套用」則由中止重算本身滿足(整趟計算丟棄,從未套用混合狀態)。**漏述本身是缺陷** —— 本 ADR 的 `Ordering Note` 明文禁止縮小 GDD 的義務,而只轉述前半句就是縮小。
3. **佔位資料所有權(Core Rules #10c)**:`occupied(tile)` 須由邏輯資料結構承載,不得由場景/節點樹存在性或視覺/動畫狀態導出;須隨任一改變單位邏輯位置或存活狀態的事件同步更新(陣亡、移動邏輯完成皆為實例,非窮盡)。
4. **結算步不可重入(Core Rules #11)**:結算步(①→②→③→④)進行中不接受任何操作輸入;②c 的卡牌效果須同步、不得於結算中要求玩家輸入;邏輯狀態為唯一權威。
5. **跨幀展開的合法性**:OQ-16 預告 `reachable_set` 可能需要有界前緣展開、並可能攤到多幀以壓進單幀預算。本 ADR 須讓跨幀實作合法且安全,不得禁止它。

## Decision

採用**盤面版本戳記(board version stamp)**作為快照識別機制,搭配**結算邊界作為唯一的盤面異動窗口**,以及**單調遞增的邏輯佔位表**。

### 核心洞見:為什麼不需要真的複製盤面

Core Rules #11 已定案兩件事:(a) 盤面權威狀態只在**已提交的結算邊界**改變;(b) 結算步本身不可重入,進行中不接受任何操作。這兩件事合起來的推論是:**兩個結算邊界之間,盤面實質上是不可變的**——沒有任何路徑能在查詢進行中改動它。

因此「快照」不需要是一份資料的拷貝,只需要一個能回答「我算的是哪一版盤面、那一版還是不是當前版」的識別符。這使本方案的成本趨近於零:一個整數比較,而不是每次查詢複製一份佔位表。

### 機制一:`board_version` 版本戳記

盤面持有一個單調遞增的整數 `board_version`,初始值 0。

- **唯一遞增時機**:每個**已提交的結算邊界**完成時 `+1`。「已提交的結算邊界」定義為 Core Rules #5 結算步④執行完畢、或一次已確認的移動邏輯完成、或任一其他改變盤面權威狀態的已提交指令完成。**不得**因為玩家移動游標、開關疊加圖、觸發預判等唯讀操作而遞增(這些依 Core Rules #8/#10 皆為零寫入)。
- **每個查詢結果攜帶它所計算的版本號**。結果的有效性判準:`result.version == board.board_version`。
- **過期(stale)的定義即為版本不符**。這直接實現 Core Rules #10a 新增的最低限度過期標記義務——不需要另一套失效通知機制,版本比對本身就是過期偵測。
- **合成查詢的一致性由版本相等斷言保證**:並存疊加圖、`threat_range_all(E)` 的 N 個子計算,全部必須攜帶**同一個**版本號;任一子結果版本不符,整組作廢重算。這實現 Core Rules #10b 的合成原子性,且**不需要**協調多份快照的生命週期。
- **跨幀展開的原子性**:一趟跨幀計算在開始時記下 `start_version`;每次跨幀恢復時比對 `board.board_version != start_version` 即**中止並重算**(不是套用部分結果,也不是繼續用舊資料算完)。因為 Core Rules #11 保證盤面只在結算邊界改變,而結算邊界期間不接受玩家操作,這種中止在實務上罕見(只會發生在跨幀計算橫跨一次已提交結算的情形)。

  🔴 **關於「盤面變動要不要排隊」—— 本 ADR 行使 GDD 的明文授權,裁定不排隊**
  (2026-09-01 `TD-ADR` 覆核發現本節與 GDD 的字面落差,補寫此段;**決定未變**)

  `tactical-combat-system.md` Core Rules #10b 的文字是「計算期間發生的盤面變動不得中途套用,
  **須排入佇列於計算結束後處理**」,而本 ADR 選的是**中止並重算**。兩者看似相反,實際不是。

  **授權的依據是該條末句的後半,不是前半**(2026-09-01 窄範圍複驗更正了本段原先的論證重心):
  末句逐字為「跨幀展開等內部機制的具體實作手段(重入鎖、快照資料結構、佇列處理方式)由 ADR-0001
  定案,**本條只定案玩家可觀測的正確性義務**」。
  ⚠️ **「佇列處理方式」這個鉤子較弱** —— 它字面上預設佇列存在,講的是「佇列要怎麼處理」,
  不明顯涵蓋「乾脆不佇列」。**真正成立的是「本條只定案玩家可觀測的正確性義務」這句**:
  它把整條規則的效力縮到可觀測正確性,而「須排入佇列」是機制規定、不是正確性義務。
  可觀測的正確性義務是「變動不得中途套用」,**中止重算完全滿足**(整趟計算丟掉,從未套用混合狀態)。
  **修法史支撐這個讀法**:佇列那句是第三輪寫的,兩句授權句是第四輪選項 B(「GDD 只保留玩家可觀測
  義務,治理層外移至 ADR」)才追加上去把它範圍縮掉的。

  **本 ADR 的裁定**:不佇列盤面變動,改為中止並重算。

  ⚠️ **兩種做法對玩家是可分辨的**:佇列 = 確認後停頓數幀才生效;中止 = 疊加圖閃一次重畫。
  **但可分辨 ≠ 正確性差異** —— 授權句限定的是「正確性」義務,手感差異不在其中。
  (這句化解是複驗補上的:上一版把讓步寫上去卻沒把化解寫下來,而那正是最能反咬本段論證的一句。)

  🔴 **不得自行改採佇列,理由是機制二,不是 #11**(複驗更正):
  上一版寫「佇列會牴觸 #11 的『不得排入無限期等待』」——**該引用是過度延伸**。
  #11 那句的主詞是「結算進行中,**玩家的任何操作嘗試**」,管的是結算期間的玩家輸入,
  不是查詢期間的盤面變動排隊;且「數幀」是有界的,不是無限期。**#11 並沒有禁止佇列。**
  真正的理由來自本 ADR 自己的機制二:佇列意味著玩家確認後,結算要延後數幀才啟動,
  而那幾幀裡 `settlement_in_progress` 仍為 `false`(結算根本還沒開始),
  **機制二的閘門擋不住第二次輸入** —— 要佇列就得再加一個「結算待處理」鎖。
- **跨幀計算主體的生命週期約束(2026-08-18 `godot-specialist` 驗證發現)**:跨幀展開若以 `await get_tree().process_frame` 實作(該訊號在 4.4–4.7 語意未變,是正確的原語選擇),**持有該協程的物件必須是生命週期涵蓋整場戰鬥的物件**(例如 Board 自身或戰鬥層級的 manager),**不得**掛在可能隨場景切換、UI 面板關閉而被釋放的暫時性節點上。理由:GDScript 協程若在 `await` 期間其宿主實例被 `queue_free()` 或回收,恢復時會嘗試回呼一個已不存在的實例,結果是靜默丟失或執行期錯誤,而非本 ADR 定義的「中止並重算」——這會直接違反 AC-9 的確定性承諾。**每次 `await` 恢復後須先以 `is_instance_valid()`(或等效防衛)確認宿主仍存活,否則一律視為中止。**

### 機制二:結算步的不可重入閘門

以一個布林旗標 `settlement_in_progress` 表達結算步的進行狀態。

- 結算步①開始時設為 `true`,④完成(含所有跨系統呼叫回傳)後設為 `false`,並於此時遞增 `board_version`。
- **`settlement_in_progress == true` 期間,所有玩家輸入一律拒絕並觸發拒絕回饋**(使用者裁決;比照 UI Requirements §6 的既有合法性閘門機制)。**不採佇列**——理由見下方 Alternatives。
- **結算步執行於 `_process` 鏈**(2026-09-01 `TD-ADR` 覆核補上,原先只在卡死偵測處隱含以 `_process` 幀計數,從未明講)。⚠️ **這一句有後果**:ADR-0005 記載 `process_priority` 只排序 `_process`/`_physics_process` 各自的鏈、**兩鏈之間無排序保證**,故若實作者把結算放進 `_physics_process`,該 ADR 的全部定序保證會**靜默失效且不報錯**。
- 結算步**不得**跨幀讓出。②c 的卡牌效果契約為同步執行、不得要求玩家輸入(見 `tactical-combat-system.md` Core Rules #11 對 #6 的契約)。這使結算步天然是單幀原子的,`settlement_in_progress` 實務上只在單一幀內為 `true`。
- **禁止 deferred 路徑介入結算(2026-08-18 `godot-specialist` 驗證發現)**:結算步內任何改動 `occupied` 或 `board_version` 的呼叫,**禁止**經由 `call_deferred()` 或以 `CONNECT_DEFERRED` 旗標連線的訊號執行。理由:Godot 的 deferred 機制會把該呼叫排到本幀稍後的安全點才執行,而非立即同步生效——效果等同於在結算步中間插入一個讓出點,**但呼叫端不會出現任何 `await` 字樣**,程式碼審查時看不出來。這是與「意外引入 `await`」同源、但更隱蔽的一條失效路徑(`queue_free()` 本身正是靠此機制實作延後移除,見機制三)。
- **卡死偵測(2026-08-18 `godot-specialist` 驗證發現的一個比重入更嚴重的失效模式)**:`settlement_in_progress` **不得跨越兩個連續的 `_process` 幀仍為 `true`**;若偵測到,須以 `push_error()` 明確曝光。理由:旗標的防禦性推理隱含假設「意外引入的 `await` 終將恢復」。但若該 `await` 永遠不恢復(等待一個不再發出的訊號、或等待的節點被釋放導致協程掛死),旗標會永遠停在 `true`,後果不是「一次可觀測的拒絕」而是**整場戰鬥輸入永久鎖死且無任何錯誤訊息**——比本旗標原本要防的情境更糟。此斷言可直接寫成自動化測試(見 Validation Criteria)。

> **為何仍需要這個旗標,即使結算是單幀的**:防禦性。GDScript 的呼叫鏈中若有任何一處意外引入讓出點(顯性的 `await`,或上述隱性的 deferred 路徑),旗標會讓該情形**變成一個可觀測的拒絕或一個明確的錯誤**,而不是一個靜默的重入 bug。這是本專案「錯誤不得靜默」既有慣例的延伸。

### 機制三:邏輯佔位表

`occupied` 由 `Dictionary[Vector2i, unit_id]` 承載(使用者裁決)。

- **稀疏儲存**:只記錄有單位的格。棋盤上的單位數遠少於格數,稀疏結構更貼合實際分布,且不需要預先定案棋盤尺寸上限(該上限目前未定案,見 OQ-16)。
- `Vector2i` 在 Godot 中是合法的 `Dictionary` 鍵。查詢為 O(1)。
- **同步時機**:任一改變單位邏輯位置或存活狀態的事件發生時立即更新,與 `board_version` 的遞增在同一個原子區段內完成。已知實例:結算步④的陣亡佔位釋放、移動的**邏輯**完成。
- **嚴禁**:以 `get_node()`/場景樹查詢導出佔位;以動畫/Tween 的完成狀態驅動佔位更新;以視覺位置作為佔位判定依據。

**兩條由 GDScript 參照語意衍生的額外約束(2026-08-18 `godot-specialist` 驗證發現)**:

- **查詢結果攜帶的容器必須是新配置的物件**。`Dictionary`/`Array` 在 GDScript 是**參照型別**;若某個查詢結果直接回傳 `board.occupied` 本身的參照(而非計算過程中新配置的容器),則即使 `version` 戳記正確地把它標記為過期,呼叫端若繞過 `is_stale()` 直接讀取該容器,仍會看到被回溯修改的內容。**版本戳記機制無法防禦這條旁路**——它管的是「該用哪一份資料」,不是「這份資料是不是共享的可變物件」。故:**禁止任何查詢回傳 board 內部儲存結構的參照。**
- **禁止依賴 `Dictionary`/`Array` 的原生迭代順序作為輸出順序**。Godot 的 `Dictionary` 保留插入順序但不按 key 排序,而語意相同的兩個集合經不同程式路徑算出時插入順序可能不同。本 ADR 的 AC-9 驗收明訂以**集合相等**(而非序列相等)斷言,正是為迴避此陷阱。若某消費端確實需要穩定序列(記錄檔比對、replay log 等),**須自行以固定排序鍵顯式排序**(例如先 `y` 後 `x`),不得信任容器的原生順序。

> **這條約束的具體攻擊面**:Godot 的 `queue_free()` 延後至幀尾才真正移除節點。若 `occupied()` 以節點樹存在性導出,一個在結算步④陣亡的單位,其節點在**同一結算步內**仍掛在場景樹上,該格會被讀為已佔據——直接違反 `tactical-combat-system.md` AC-7(c) 要求的同結算步釋放。同理,移動若把邏輯位置更新綁在 Tween 的 `finished` 訊號上,動畫播放期間(可能長達數百毫秒)的任何查詢都會讀到過期佔位。

### Architecture Diagram

```
                    ┌─────────────────────────────────────────┐
                    │          Board (權威狀態)                │
                    │                                         │
                    │  board_version: int  ← 只在結算邊界 +1   │
                    │  occupied: Dictionary[Vector2i, unit_id]│
                    │  terrain: (地形成本 / 遮蔽標記)          │
                    │  settlement_in_progress: bool           │
                    └───────────┬─────────────────────────────┘
                                │ 唯讀
          ┌─────────────────────┼─────────────────────┐
          │                     │                     │
    ┌─────▼──────┐      ┌───────▼───────┐     ┌──────▼───────┐
    │reachable_  │      │ threat_range_ │     │ 預判摘要 /    │
    │set(u)      │      │ all(E)        │     │ 旗標總覽 ...  │
    │            │      │  ├ e1 ─┐      │     │              │
    │            │      │  ├ e2 ─┼→聯集 │     │              │
    │            │      │  └ e3 ─┘      │     │              │
    └─────┬──────┘      └───────┬───────┘     └──────┬───────┘
          │                     │                     │
          └─────────────────────┴─────────────────────┘
                                │
                    每個結果攜帶 version 戳記
                                │
                    ┌───────────▼────────────┐
                    │  呈現層 (戰鬥 HUD #10)  │
                    │                        │
                    │  有效 ⇔ version ==     │
                    │        board_version   │
                    │  合成畫面 ⇒ 各子結果    │
                    │        version 須相等   │
                    └────────────────────────┘

  寫入路徑(唯一能改變盤面的路徑):
    玩家已確認的指令
      → settlement_in_progress = true   ← 此後所有輸入被拒絕
      → 結算步 ① → ② → ③ → ④           ← 單幀、同步、不可重入
      → occupied 同步更新
      → board_version += 1              ← 所有既有查詢結果就此變為過期
      → settlement_in_progress = false
```

### Key Interfaces

以下為本 ADR 定案的契約形狀。**具體命名與型別簽章可在實作時微調,但語意不得改變**;任何改變語意的調整須回頭修訂本 ADR。

> **閱讀提醒**:以下為**概念契約**,不是可直接貼上的單一檔案。Godot 每個 `.gd` 檔只能有一個 `class_name`,實作時各類別應落在各自檔案(如 `board.gd`、`query_result.gd`)。
>
> 🔴 **2026-09-01 `TD-ADR` 覆核補強**:以下的 `func` 宣告**刻意只有簽章、主體從略**,直接貼上會是 GDScript 的 Parse Error。
> ⚠️ **不要「順手加個 `pass` 讓它能編譯」** —— 帶 `pass` 主體撞上專案級禁令 `abstract_func_with_body`(已實機驗證為編譯期錯誤,見 `docs/registry/architecture.yaml`)。
> **本專案已為「照 ADR 的示意程式碼直接寫」付過 18 處編譯錯誤的代價**,故此處明寫而非只靠上一句提醒。

```gdscript
# ─── board.gd ────────────────────────────────────────────────
# 盤面權威狀態。唯一能改變 board_version 與 occupied 的路徑
# 是已提交的結算邊界。

class_name Board
# ⚠️ 2026-09-01:`class_name Board` 已被 `src/gameplay/board/board.gd` 佔用(2026-08-26 進 repo,
#    166 行,地形/移動成本/視線/佔位的幾何雛形,與本契約職責不重疊)。Godot 專案內
#    `class_name` 全域唯一 —— 落地時須二選一:把本契約併進該檔(順帶把它的 `_occupants`
#    改名對齊 `_occupied`),或改掉其中一個名字。**已登記,未處置。**

# board_version / settlement_in_progress 皆為對外唯讀屬性。
# 外部 `board.board_version = x` 會觸發 setter 的 push_error() 並拒絕寫入。
# 內部合法寫入一律走底線私有欄位,不經過本屬性自己的 setter。
#
# 驗證範圍(2026-09-01 窄範圍複驗校正,原註解把一項驗證的結論套到了兩項上):
#   - board_version(int)          —— 已實機驗證,prototypes/adr0001-board-property-spike-2026-09-01/
#                                     (外部賦 999 被拒、值不變、錯誤訊息指名檔案行號)
#   - settlement_in_progress(bool) —— 未單獨驗證,沿用同一形狀。結構同構、風險低,但不是實測結論。
#   - 全部結論限定 debug / headless。release 建置未查證(本機無 export template)。

var _board_version: int = 0            # 單調遞增,只在結算邊界 +1
var board_version: int:
	get:
		return _board_version
	set(value):
		push_error("board_version is read-only outside Board; rejected external write of %d" % value)

var _settlement_in_progress: bool = false
var settlement_in_progress: bool:
	get:
		return _settlement_in_progress
	set(value):
		push_error("settlement_in_progress is read-only outside Board; rejected external write of %s" % value)

# 邏輯佔位表:key = 座標,value = unit_id(int)
# 注意 value 型別是 int —— `unit_id` 是該 int 值的語意名稱,不是型別名
var _occupied: Dictionary[Vector2i, int]

# 佔位查詢 —— 唯一合法的佔位判定來源
func is_occupied(tile: Vector2i) -> bool
func occupant_of(tile: Vector2i) -> int   # 無單位時回傳 INVALID_UNIT_ID

# ─── query_result.gd ─────────────────────────────────────────
# 每個對外查詢的回傳值都攜帶它所計算的版本號。
# 容器型別欄位一律為計算過程中新配置的物件,
# 禁止持有 Board 內部儲存結構的參照(見機制三的參照語意約束)。

class_name QueryResult

var version: int                # 計算時的 board_version

func is_stale(board: Board) -> bool:
    return version != board.board_version

# 合成查詢的一致性斷言:
# 被合併判讀為單一畫面的一組結果,必須全部同版本。
static func assert_same_version(results: Array[QueryResult]) -> bool
```

**呈現層的義務**:任何一組要合併呈現給玩家的查詢結果,渲染前須通過 `assert_same_version`;任一結果 `is_stale()` 為真時,**不得**以該結果接受玩家輸入(須重算或拒絕該輸入)。

## Alternatives Considered

### Alternative 1: 顯式快照物件(真的拷貝一份盤面)

- **Description**:查詢開始時把佔位表與地形資料深拷貝成一個 `BoardSnapshot` 物件,整趟計算只讀該物件。合成查詢共用同一個快照實例。
- **Pros**:即使未來 Core Rules #11 的不可重入保證被放寬(例如某天真的需要非同步的卡牌效果),此方案仍然正確——它不依賴「盤面在查詢期間不會變」這個前提。是三者中最保守的。
- **Cons**:每次查詢都付出拷貝成本。而「游標即檢視」模型下,格位資訊面板隨游標每次移動即時更新,是高頻查詢路徑;再疊上 `threat_range_all(E)` 的 N 敵成本(OQ-16 已標記為未量化風險),固定拷貝成本會被放大。且 GDScript 的深拷貝在巢狀結構上有 `duplicate()` vs `duplicate_deep()` 的既有陷阱(見 `deprecated-apis.md`),多一個出錯面。
- **Rejection Reason**:它付出的成本是為了防禦一個**本專案已經用規則排除掉**的情境(Core Rules #11 的不可重入)。在規則已保證盤面不會在查詢中途改變的前提下,拷貝是純粹的重複防禦。**但這個方案的價值不為零**:若未來 Core Rules #11 的同步契約被 #6 推翻(見 OQ-4 登記的條件),本 ADR 應回頭重新評估此方案——已記入下方 Risks。

### Alternative 2: 幀邊界批次化

- **Description**:所有查詢固定在每幀某一個點(例如 `_process` 開頭)一次算完,幀內其餘時間一律供應該批結果。
- **Pros**:同一幀內的一致性天然成立,合成查詢的版本問題自動消失。呈現層的心智模型極簡單。
- **Cons**:即使玩家完全沒動作,也可能每幀重算全部查詢。與 OQ-16 已標記的 N 敵 Dijkstra 成本相乘,這是三個方案中效能風險最高的。且它把「何時重算」這個決定從「狀態改變時」改成「每幀」,與 Core Rules #10a「輸出恆等於以當下狀態重算一次」的義務其實是脫鉤的——每幀重算既不必要(狀態沒變時是浪費)、在最壞情況下也不充分(若某幀的計算超出預算而被迫跨幀,又回到原本的問題)。
- **Rejection Reason**:成本結構與本專案的實際存取模式(回合制、狀態長時間不變、偶爾一次結算)嚴重不匹配。回合制戰棋的盤面在玩家思考期間可能數十秒不變,每幀重算是最不划算的一種安排。

### Alternative 3: 不定案機制,只在 GDD 保留義務

- **Description**:維持現狀,不建 ADR,讓 `/create-architecture` 階段一併處理。
- **Pros**:不需要維護一份額外文件與交叉指標。
- **Cons**:這正是第四輪 `creative-director` 診斷為問題根源的狀態——架構級契約住在 GDD 裡,被以設計審查的深度反覆稽核,且每輪新增的通則都產生新邊界供下一輪發現。預期還需 2–3 輪才收斂。
- **Rejection Reason**:使用者已於第四輪明確裁決採選項 B(結構修法 + 契約外移)。本 ADR 即該裁決的執行。

## Consequences

### Positive

- **查詢正確性的判準收斂為一個整數比較**。過期偵測、合成一致性、跨幀原子性三件事共用同一個機制(版本相等),不需要三套獨立的失效邏輯——這直接減少了第三、四輪反覆出現的「規則之間有縫」的發生面。
- **成本趨近於零**。相較於每次查詢深拷貝盤面,版本戳記只多一個 int 欄位與一次比較,對「游標即檢視」的高頻路徑幾乎無影響。
- **跨幀展開合法且安全**。OQ-16 預告的有界前緣展開/多幀攤分不被禁止,只需在恢復點比對版本。
- **審查職責分流**。GDD 只留玩家可觀測義務,由 `/design-review` 審;機制由本 ADR 承載,由 `/architecture-review` 審。第五輪 `/design-review` 的標的因此縮回玩法與規則正確性。
- **佔位資料的攻擊面被明確關閉**。`queue_free()` 延後移除與動畫驅動更新這兩個具體陷阱,在 ADR 層被明文禁止,而非只在 AC 層被測試攔截。

### Negative

- **多一份必須維護的文件與交叉指標**。GDD 現有 3 處指標指向本 ADR;本 ADR 亦回指 GDD 的義務。任一方修訂時須檢查另一方——而**跨檔搬移正是本專案最容易產生傳播失敗的動作**(第三、四輪各發生過一次同類失敗)。
- **本 ADR 的正確性依賴 Core Rules #11 成立**。版本戳記方案之所以不需要拷貝盤面,前提是「盤面在兩個結算邊界之間不可變」。這個前提若被推翻,方案需要重新評估(見 Risks)。
- **拒絕式重入策略會丟棄玩家在結算期間的輸入**。雖然結算步是單幀的、實務影響極小,但快速連續操作時理論上可能丟失一次輸入。

### Risks

| 風險 | 緩解 |
|---|---|
| **技能卡牌系統(#6)設計時發現某類效果無法滿足同步契約**(例如「請玩家選擇加成對象」是該系統的核心玩法之一),導致 Core Rules #11 的前提被推翻 | 已於 `tactical-combat-system.md` OQ-4 與 systems-index 跨系統義務登記表登記為 #6 的確認義務,且明訂「須回頭修訂 Core Rules #11 與 AC-24,不得單方面繞過」。**若該契約真被推翻,本 ADR 須回頭重新評估 Alternative 1(顯式快照物件)**——該方案不依賴不可重入前提 |
| **跨檔傳播失敗**:GDD 義務修訂後未同步本 ADR,或反之 | 本 ADR 的 ADR Dependencies 段已明訂修訂方向為單向(GDD 義務變更 → 檢查本 ADR;本 ADR 機制變更**不得**改變 GDD 義務範圍)。`/architecture-review` 的 traceability matrix 應涵蓋此對應 |
| **`queue_free()` 的幀尾語意在未來 Godot 版本改變**,使本 ADR 的理由陳述過時(雖然機制本身仍正確) | 本 ADR 的決定(邏輯資料結構承載佔位)**不因該語意改變而失效**——它在任何情況下都是正確的做法,引擎語意只是它最迫切的理由之一。已列入 Verification Required |
| **實作者誤把 `board_version` 的遞增掛在錯誤的事件上**(例如每幀 +1,或游標移動時 +1),使所有查詢結果恆為過期、退化成每次重算 | 本 ADR 明文列出唯一遞增時機並明文排除唯讀操作。建議實作時對「連續 N 次唯讀操作後 `board_version` 不變」寫一條斷言測試 |
| **N 敵 Dijkstra 的絕對成本仍未量化**——本 ADR 讓跨幀展開合法,但沒有解決「總量是否壓得進預算」 | 明確不在本 ADR 範圍。已由 `tactical-combat-system.md` OQ-16 登記(含「敵方單位數上限全專案無擁有者」與「效能測試須以格數×敵數兩軸參數化」兩項待補) |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `tactical-combat-system.md` | Core Rules #10a — 即時性;輸出恆等於以當下狀態重算一次;改變答案的結算邊界事件發生時須至少標記為過期,不得以過期輸出接受下一個玩家輸入 | `board_version` 版本戳記:結果有效 ⇔ 版本相等;版本不符即為過期。呈現層義務明訂為「`is_stale()` 為真時不得以該結果接受玩家輸入」 |
| `tactical-combat-system.md` | Core Rules #10b — 單一快照原子性;**且被合併判讀為單一畫面的一組輸出視為同一次查詢、共用同一份快照** | 合成查詢的所有子結果須攜帶同一版本號(`assert_same_version`);跨幀展開於恢復點比對 `start_version`,不符即中止重算 |
| `tactical-combat-system.md` | Core Rules #10c — 佔位資料所有權;不得由節點樹或視覺狀態導出;須隨任一改變邏輯位置或存活狀態的事件同步更新 | `Dictionary[Vector2i, unit_id]` 稀疏邏輯佔位表;同步時機與 `board_version` 遞增在同一原子區段;明文禁止節點樹導出與動畫驅動更新,並記載 `queue_free()` 延後移除的具體攻擊面 |
| `tactical-combat-system.md` | Core Rules #11 — 結算步不可重入;②c 卡牌效果須同步不得要求玩家輸入;邏輯狀態為唯一權威 | `settlement_in_progress` 閘門 + 拒絕式輸入策略;結算步單幀同步不跨幀讓出;佔位/HP/旗標一律以邏輯狀態為準 |
| `tactical-combat-system.md` | AC-9 — 零隨機/確定性;相同輸入逐次呼叫結果完全相同(含公式三/四的集合型輸出) | 版本戳記機制不引入任何非決定性(無亂數、無時間、無幀計數器);跨幀中止採「作廢重算」而非「部分結果沿用」,確保同版本下的輸出唯一 |
| `tactical-combat-system.md` | AC-22 / AC-24 — 上述義務的驗收條件 | 本 ADR 的機制為這些 AC 提供可實作的具體形狀;AC 本身的斷言內容不變 |
| `affinity-data-pool.md` | Core Rules #1 — 陣亡通知介面於結算步內呼叫;同結算步呼叫順序影響寫入合法性 | 結算步不可重入 + 單幀同步,保證 `tactical-combat-system.md` Core Rules #5 定案的 ①②③④ 順序在執行期不被打斷,跨系統呼叫順序因此是確定性的 |

## Performance Implications

- **CPU**:版本戳記本身的開銷可忽略(一個 int 欄位 + 一次比較)。**本 ADR 不解決** `reachable_set` 雙趟展開與 `threat_range_all(E)` 的 N 敵成本——那是演算法層的問題,見 OQ-16。本 ADR 的貢獻是讓「跨幀攤分」這個緩解手段合法且安全。
- **Memory**:稀疏 `Dictionary` 佔位表的記憶體與單位數成正比,與棋盤格數無關。相較密集二維陣列,在單位稀疏的戰棋盤面上顯著較省,且不需要預先定案棋盤尺寸上限。
- **Load Time**:無影響。
- **Network**:不適用(單人遊戲)。

**明確未定案**:單幀 16.6ms 預算內能容納多少格 × 多少敵人,本 ADR 不作任何宣稱。`.claude/docs/technical-preferences.md` 的 Memory Ceiling 亦仍為 `[TO BE CONFIGURED]`。

## Migration Plan

🔴 **2026-09-01 更正**:本節原寫「本專案尚無任何實作程式碼(`src/` 為空,專案處於設計階段)」——
**該句撰寫當下(2026-08-18)為真,現已不成立。** 現值當場數(**不寫死數字,手抄必漂移**):

```bash
find src -name '*.gd' | xargs wc -l | tail -1
```

🔴 **本段的第一版更正只點名了 `board.gd` 與 `line_of_sight.gd`(合計 261 行),
漏掉其餘約 3,530 行 —— 而漏掉的正是 `src/gameplay/battle/` 與 `src/ui/battle/`,
本 ADR 管轄的戰鬥層本身。** 窄範圍複驗抓到並更正。
**修「數字不完整」的更正自己也數不完整,是本專案登記過的同一種失效。**

**本 ADR 對既有程式碼的關係,精確陳述如下**(不再用「無關」這種全稱說法):

- **三個契約欄位零命中**:全庫 grep `board_version` / `settlement_in_progress` / `_occupied` 皆無。
  ⚠️ 但 `_occupied` 零命中**只是因為現有程式碼叫 `_occupants`**(`board.gd`),
  而本 ADR 的 Key Interfaces 已寫明落地時要改名對齊 —— **同一份文件一處說零命中、一處說要改名,
  講的是同一個概念。**
- 🔴 **未登記的待處置項**:`battle_controller.gd` 的 `_apply_attack()` / `_apply_move()`
  **是否已構成本 ADR 定義的「已提交結算邊界」、落地時要不要退回改寫,目前沒有人登記。**
  判斷它需要逐行讀那 591 行並比對契約,**不在本批範圍**。

⚠️ **真正需要遷移的是命名**:`board.gd` 已佔用 `class_name Board`,而 Godot 專案內
`class_name` 全域唯一。落地時須二選一(併檔或改名),詳見上方 Key Interfaces 的警告。
**已登記,未處置。**

## Validation Criteria

本 ADR 的決策是否正確,由下列可判定條件驗證:

1. **`tactical-combat-system.md` 的 AC-22 全部向量通過**(含第四輪新增的並存疊加圖共用快照、`threat_range_all` 多敵共用快照兩條)——這是本 ADR 機制是否真的滿足 Core Rules #10 的直接證據。
2. **AC-24 全部向量通過**(結算中切換單位被拒、重複發起同一攻擊不產生第二次結算、結算後恢復正常、卡牌效果不於結算中要求輸入)。
3. **AC-9 的集合型輸出向量通過**:盤面不變時 `reachable_set(u)` ×100 與 `threat_range_all(E)` ×100 皆集合相等。
4. **`board_version` 遞增時機的斷言測試**:連續 N 次唯讀操作(游標移動、開關疊加圖、預判標記)後 `board_version` 不變;一次已提交結算後恰好 +1。
5. **佔位同步的時效測試**:單位陣亡後於**同一結算步內**(引擎尚未實際移除節點時)查詢該格為可通行;單位移動後於動畫播放中查詢佔位已反映邏輯目的格。
6. **後續 `/architecture-review`** 判定本 ADR 與其他 ADR 無衝突、且對 GDD 需求的涵蓋無缺口。
7. **`settlement_in_progress` 卡死防衛斷言**(2026-08-18 `godot-specialist` 驗證後新增):自動化測試斷言該旗標不得跨越兩個連續 `_process` 幀仍為 `true`。此測試是「意外引入永不恢復的 await」這個最壞情況的安全網——該情況的後果是整場戰鬥輸入永久鎖死且無錯誤訊息,比本旗標原本要防的重入更嚴重。
8. **查詢結果容器獨立性測試**(同上):取得一份查詢結果後,對 board 執行一次已提交結算,斷言該結果攜帶的容器內容**未被回溯改變**(只有 `is_stale()` 轉為 true)——此測試攔截「查詢回傳 board 內部結構參照」的錯誤實作。
9. 🔴 **對外寫入攔截測試**(2026-09-01 `TD-ADR` 覆核導出,已實機驗證):自 `Board` 外部對 `board.board_version` 或 `board.settlement_in_progress` 賦值,斷言觸發 `push_error()` 且**欄位值不變**。證據與三種做法的比較見 `prototypes/adr0001-board-property-spike-2026-09-01/`。✅ **斷言做法已查證**(2026-09-01 同日稍晚):`assert_error(<Callable>).is_push_error(<message>)`,已實跑通過(`2 test cases | 0 failures | 0 orphans`,exit 0,含證明該斷言非恆為 pass 的對照組),見 `prototypes/adr0001-engine-probes-2026-09-01/gdunit4_push_error/`。<br>⚠️ **本句原寫「本專案尚未確認」,而同一天稍晚的探針就解決了它,檔頭第 20 行也已寫成已解除** —— 一份文件在自己剛驗出答案的同一天,還留著說那件事沒答案的句子。窄範圍複驗抓到並更正。**這是 `docs/consistency-failures.md` 登記的「修東西反而修出新問題」的又一例。**

**反向驗證(本 ADR 若錯了會如何顯現)**:若版本戳記的粒度過粗(某些改變答案的事件未遞增版本),會表現為玩家看到過期疊加圖而系統未察覺——即 Player Fantasy 具名的「顯示與實際結算不一致」失敗模式。若粒度過細(唯讀操作也遞增),會表現為所有查詢恆為過期、每次操作都全量重算,在 N 敵盤面上直接撞上效能預算。

## Related Decisions

- `design/gdd/tactical-combat-system.md` — Core Rules #10(對外查詢介面的共用義務)、Core Rules #11(結算步的不可重入邊界)、AC-9/AC-22/AC-24、Open Questions OQ-4/OQ-16。**義務的權威定義在該文件,本 ADR 只定案機制。**
- `design/gdd/reviews/tactical-combat-system-review-log.md` — 第四輪條目記載本 ADR 的成因(結構性診斷與選項 B 裁決)。
- `design/gdd/systems-index.md` — Cross-System Obligations Registry 的兩列(Core Rules #10 查詢介面義務、Core Rules #11 對 #6 的同步契約)。
- `design/gdd/affinity-data-pool.md` — Core Rules #1(陣亡通知介面與同結算步呼叫順序義務)。
- `docs/architecture/adr-0005-cursor-device-authority-input-architecture.md` — **雙向關係,2026-09-01 `TD-ADR` 覆核補上**(此前為單向:ADR-0005 有回指本份,本份對它零提及)。該 ADR 沿用本 ADR 的兩條禁令;其優先序梯把「游標改標」排在「確認鍵讀取」之前,**本 ADR 給呈現層的「`is_stale()` 為真時不得接受玩家輸入」義務能否成立,依賴該排序**。兩份對延後執行的禁令方向一致,非牴觸(該 ADR 另有專節說明兩者易被誤判為矛盾)。
- `docs/engine-reference/godot/` — VERSION.md、breaking-changes.md、deprecated-apis.md、current-best-practices.md。
- **待建**:戰棋移動與交戰系統的實作 ADR(演算法層:有界前緣展開、N 敵成本控制),應在 OQ-16 的棋盤規模與敵方單位數上限定案後撰寫。
