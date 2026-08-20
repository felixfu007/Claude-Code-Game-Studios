# ADR-0002: 好感度數值池資料結構與並發契約

## Status

**Proposed**

> **2026-08-19 修訂(銜接缺口 C1/C3,不改動任何機制決策)**:連續三輪 `/architecture-review` 判定為仍開的兩項跨 ADR 銜接缺口。**C1** —— `TOKEN_TIMEOUT_MS` 的**定值責任**已由 ADR-0004 明文接下(該 ADR 掌握遷移鏈深度上界與兩階段回寫最壞 I/O 時間,本 ADR 對兩者一無所知);本 ADR 仍擁有逾時**機制**的執行(機制七逐權杖惰性清除),但不擁有那個數字。**C3** —— `TR-affinity-016` 是條件式需求,其條件(「若選擇背景執行緒序列化」)已由 ADR-0004 判為「否」;`Mutex` 決策**不變**,但理由由「必要」改為**縱深防禦**,措辭不再宣稱它是「全專案唯一已成立的執行緒安全義務」。兩項皆為措辭與擁有權澄清,**未新增、未移除、未改變任何資料結構或介面契約**。

> **2026-08-20 修訂(BLOCKING —— 引擎行為實機驗證)**:2026-08-20 的引擎行為驗證 spike 與 `godot-gdscript-specialist` 的獨立交叉覆核,在 Godot 4.7.1 實機測出本 ADR 機制二的**核心宣告無法編譯**(`Nested typed collections are not supported`),已改採包裝類別 `AffinityRecordList`(**本次驗證涵蓋的四個候選中唯一同時保住兩層型別者**)。同時:型別安全論述由單層改寫為**三層圖像**,並新增**鍵邊界與值邊界兩條規則**(分別把已實證的 subscript 空隙關在系統邊界外、以及讓 release 建置下未查證的容器驗證行為降為縱深防禦);`validate_semantics()` 的逐欄位檢查擴充為**型別 + 值域**,且型別檢查明訂只能用 `typeof()` 內省;新增機制四之三,明文呼叫端的型別義務與「7 類拒絕碼不涵蓋型別非法」這條先前隱含的範圍界線。Verification Required **由五項擴為八項**——**六項關閉**(#1/#2/#3/#5/#6/#8)、**兩項仍開**(#4 `Mutex` 可重入、#7 export release 建置下的容器驗證行為)、**三項新增**(#6/#8 新增即關閉,#7 新增且仍未查證)、**一項改寫**(#4 原附註「本專案無 Godot 執行環境可實測」的前提**已被推翻**——執行檔存在,只是不在 `PATH` 上;未關閉的原因改為尚未撰寫探針)。**本次修訂改變了資料結構的具體型別,但未改變任何介面語意、並發機制或錯誤分類。**
>
> **寫入前已執行 Step 5.5 雙軌覆核**(`godot-gdscript-specialist` + `godot-specialist`),抓出並修畢本次修訂初稿**自己引入的 2 項缺陷**:(a) 曾用鍵邊界規則去支撐值層的降級,推導鏈不成立;(b) VR 計數低估為「一項新增」,會讓讀者漏掉 #7。這與 ADR-0005 第三/四/五輪「修法本身引入新缺陷」是同一模式,第六次。
>
> **本 ADR 不自陳修訂後的需求涵蓋分佈** —— 留給全新 session 的獨立 `/architecture-review`(第七輪)重新推導。歷次自陳皆被獨立覆核判為高估。

## Date

2026-08-18(初版) / 2026-08-19(C1/C3 銜接缺口修訂) / 2026-08-20(引擎行為實機驗證修訂)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core(資料結構與並發) |
| **Knowledge Risk** | MEDIUM——本領域無 `breaking-changes.md` 列出的 4.7 專屬破壞性變更(`Dictionary`/`enum`/`Mutex`/`RefCounted` 皆為 4.0 起語意穩定的機制),但仍屬 2026-01 訓練截止後未經本專案實機驗證的版本;無專屬模組參考文件(`docs/engine-reference/godot/modules/` 只有 animation/audio/input/navigation/networking/physics/rendering/ui,無 core/scripting)。**2026-08-20 更新**:本領域已首次取得實機驗證,八項 Verification Required 中六項關閉——其中一項(#6)推翻了本 ADR 的核心宣告。風險等級維持 MEDIUM 而非下調,理由是仍有兩項未查證,且 #7 屬本專案目前無法查證的類別 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`、`breaking-changes.md`、`deprecated-apis.md`、`current-best-practices.md` |
| **Post-Cutoff APIs Used** | 無——`Dictionary[K,V]` 型別化容器語法(4.4 起)、`enum`、`RefCounted`、`Mutex`、`Time.get_ticks_msec()`,以及 `Resource.DEEP_DUPLICATE_ALL`(本 ADR 不使用深拷貝,見 Decision,故此 API 與本 ADR 無交集)皆非本 ADR 依賴項。**2026-08-20 修正**:原本把 `Dictionary[K,V]` 一律當成「4.4 起語意穩定、非依賴項」——該判斷在**巢狀**用法上不成立(4.7.1 明確不支援巢狀型別容器,見 Verification Required #6)。單層型別化容器仍為穩定機制;本 ADR 修訂後**只使用單層**。另新增依賴 `typeof()` 與 `Variant.Type` 常數(機制八的型別檢查),兩者皆為 4.0 起穩定的核心 API |
| **Verification Required** | **2026-08-20 全欄改寫,五項擴為八項。六項已關閉、兩項仍開。** 詳表見下方「Verification Required 明細」 |

**引擎知識落差聲明**:`godot-specialist` 於 2026-08-18 對本 ADR 初稿逐項查核(型別化 Dictionary 語意、enum 作為鍵、`RefCounted`+signal 的正確性、`Mutex` 用法、序列化替代方案 `inst_to_dict()`/`dict_to_inst()`、`class_name` 命名空間風險),結論:零 BLOCKING 級的機制決策問題(`Dictionary`/`RefCounted`/`enum`/`Mutex`/DI 擁有模式的選擇本身皆確認為 4.7.1 慣用做法),但發現初稿的 Key Interfaces **完整性缺口**——共用列舉(`Pair`/`Character`/`Source`)若不集中包裝於單一 `class_name`,會造成跨檔案引用無法編譯,已修訂為 `AffinityTypes` 包裝類別(見機制二)。另提出 5 項 minor notes,已全數採納並反映於機制四/七/八與本節、Risks 表。

### Verification Required 明細(2026-08-20 改寫)

| # | 項目 | 狀態 |
|---|---|---|
| **1** | 型別化 `Dictionary` 的編譯期鍵值型別檢查是否確實生效(而非僅靜態分析提示) | **已查證(2026-08-20)**,但答案分三層,見機制四之二:編譯期**確實擋** enum 家族與容器整體賦值(層一);**subscript 鍵路徑完全不擋**(層三)。**另:本項原本描述的型別 `Dictionary[AffinityTypes.Pair, Array[AffinityRecord]]` 本身在 4.7.1 無法編譯**,已於本次修訂改為 `Dictionary[AffinityTypes.Pair, AffinityRecordList]`(見機制二 BLOCKING 修訂) |
| **2** | `enum` 值作為 `Dictionary` 鍵的雜湊/相等語意是否與訓練資料涵蓋的版本一致 | **已查證(2026-08-20)**:一致。容器層把 enum 鍵型別抹成 `TYPE_INT`(`get_typed_key_builtin() == 2`),相等語意即 int 相等——這同時是層三空隙的機制解釋。`TR-affinity-003` 的「值型別鍵」決策因此成立且更明確 |
| **3** | GDScript `pow(0.0, 0.0)` 的實際回傳值是否為 `1.0` | **已查證(2026-08-20)**:是,`1.0`(`**` 運算子與 `pow(int,int)` 同)。**但顯式特判仍須保留**——GDD Formulas 邊界值測試總表要求的是「不建立對引擎預設行為的依賴」,不是「數值是否碰巧相符」;改變的只有理由措辭:從「答案未知故須特判」改為「答案已知相符,但契約不允許依賴它」 |
| **4** | `Mutex` 在 4.7.1 是否為可重入(同執行緒重複 `lock()` 不死結,但須成對 `unlock()`) | **仍未查證。**⚠️ 本項原本附註「`godot-specialist` 查核時本專案無 Godot 執行環境可實測」——**該前提已於 2026-08-20 被推翻**:Godot 4.7.1 可在本機 headless 完整執行(`which godot` 找不到只代表不在 `PATH` 上)。本項未關閉的原因改為**尚未撰寫該探針**,不是不能測。機制七的鎖定模式(單一進入點取鎖 + `_sweep_timed_out_tokens_unlocked()` 假設已持鎖)**維持不變**——該寫法在兩種答案下皆正確,故本項不影響可實作性,僅影響是否可移除防禦寫法 |
| **5** | 型別化 `Dictionary` 的值槽在 subscript 賦值情境下是否可靠推斷元素型別 | **已查證(2026-08-20)**:**不推斷**(未型別化字面量經 subscript 賦值後讀回 `is_typed() == false`)。包裝類別 `AffinityRecordList` 讓此問題不再適用於 `_records`——`items` 的型別來自宣告式初始化,不經推斷路徑,見機制四實作提醒 |
| **6** | GDScript 4.7.1 是否支援巢狀型別容器 | **已查證(2026-08-20):不支援**——`Parse Error: Nested typed collections are not supported`,class member(無初始化)/ 函式參數 / 回傳型別三種語法形狀皆同,兩個獨立專案重現。**本項為新增,原 VR 表沒有它,而它擊落了本 ADR 的核心宣告**(見機制二 BLOCKING 修訂) |
| **7** | **export release 建置下,C++ 容器驗證(層二)是否仍生效** | **未查證,且本專案目前無法查證**:`%APPDATA%/Godot/export_templates/` 存在但完全是空的、全域零個 `.tpz`;三條替代路皆已排除(`--headless` 只換 DisplayServer、`OS.is_debug_build()` 不可切換、無 template binary)。**跨 ADR:ADR-0005 的 S-1 必要性論證依賴同一問題的另一半**(GDScript VM 是否在 release 中止所在函式),但依賴方向不同——本 ADR 依賴層 A(容器驗證是否丟棄寫入)且已由機制四之二的規則二降為縱深防禦,ADR-0005 依賴層 B(VM 中止語意)且尚未降級。**建議的關閉方式不是手動測一次**,而是把探針改成建置無關(只斷言容器 `size()`,不管中止與否),掛進 CI 的 release-export job 成為永久回歸測試。**證據等級誠實聲明**:層 A 的關鍵論證是 `ERR_FAIL_COND_V(cond, false)` 的 `return false` 與錯誤列印在同一巨集內、巨集若被編掉則兩者一起消失——此推論的前提(4.7 的實際巨集定義)無 C++ 原始碼可查,屬**訓練資料推論** |
| **8** | 型別錯配的 `Variant` 傳給內建函式、比較運算子、與型別化賦值時的行為 | **已查證(2026-08-20,`XCHECK-4`)**:內建函式(`is_finite`/`is_nan`/`is_inf`)與比較運算子(`==`/`>=`)對 `String` **皆中止所在函式**,無一會靜默回傳 `false`;但 `var t: int = <float 1.5>` **靜默截斷為 `1`**,不中止不報錯。中止不往上層傳染。**本項為新增**——它坐實了機制八「先 `typeof()` 內省、後值域運算」的排序,並揭露了 `t`/`c` 型別檢查不可寬鬆到「int 或 float 皆可」的靜默截斷風險 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | `docs/architecture/adr-0003-save-system-serialization-format-and-type-safety.md`(2026-08-18 已寫入,`TR-save-001` 及其下游)——引用本 ADR 的 `export_state()`/`import_state()`/`validate_semantics()` 通用 `Dictionary` 契約與反序列化語意驗證規則,決定實際容器格式;好感度—位置連鎖系統、敘事解鎖與結局分支系統、技能卡牌系統、支援對話系統、章節/戰役結構、戰棋移動與交戰系統(陣亡通知呼叫方)的後續設計/實作 |
| **Blocks** | 好感度數值池相關 story 的 `/create-stories`/`/dev-story`——目前 24 項 `TR-affinity-*` 缺口全數卡在此 |
| **Ordering Note** | 本 ADR 刻意**不**依賴尚未撰寫的存檔系統 ADR(序列化格式、寫入並發模型皆為該 ADR 的範圍)——`affinity-data-pool.md` Dependencies 章節明文本系統「仍是唯一不需要等待其他系統設計完成即可實作的資料層」,若本 ADR 反過來依賴存檔系統 ADR 的格式/執行模型決策,會違反這個明文的獨立性宣告,並造成循環等待(存檔系統 ADR 大概率會想引用本 ADR 的邏輯結構)。本 ADR 對「序列化生命週期權杖集合是否需要 Mutex 保護」的決定已在本 ADR 內**無條件**拍板(見 Decision),不等待存檔系統執行模型定案 |

## Context

### Problem Statement

`design/gdd/affinity-data-pool.md`(Foundation 層,已 Approved,歷經 12 輪 `/design-review` 收斂)是《弈緣》好感度系統的唯一資料來源,但在架構層完全零覆蓋——`docs/architecture/architecture-review-2026-08-18.md` 記錄該文件 24 項技術需求(`TR-affinity-001` 至 `-024`)全數為缺口,且明文列為「全專案最高優先的 ADR 缺口」,理由是其中 `TR-affinity-016` 是**全專案唯一已宣告的執行緒安全義務**(**2026-08-19 C3 修訂後的現況說明**:此句是 2026-08-18 首輪稽核當時把本 ADR 列為最高優先的**理由**,不是本 ADR 現在的宣稱。`TR-affinity-016` 的條件句此後已由 ADR-0004 判為「否」,`Mutex` 保留為縱深防禦——見機制七的 C3 段落)。GDD 本身已把「要做什麼」定案得極其詳盡(五輪以上的對抗性覆核收斂出逐欄位值域、7 類拒絕情境、跨結構不變量、權杖式並發語意),但完全沒有回答「用什麼 Godot/GDScript 資料結構、什麼並發機制實作」——這是本 ADR 存在的理由:把 GDD 已鎖定的義務對應到具體、可實作、可測試的型別與介面,讓下游 `/create-architecture`、`/create-stories`、`/dev-story` 有型別可依循。

### Constraints

- **GDD 的規則是輸入,不是本 ADR 的裁量範圍**:`affinity-data-pool.md` 的 Core Rules/Formulas/Edge Cases/Dependencies/Tuning Knobs 章節已定案「要做什麼」,本 ADR 只決定「如何實作」——與 ADR-0001 對 `tactical-combat-system.md` 的關係同型,修訂方向單向:GDD 的義務變更須回頭檢查本 ADR 是否仍能滿足;本 ADR 的機制變更**不得**擴大或縮小 GDD 的義務。
- **`coding-standards.md`**:「All public methods must be unit-testable (dependency injection over singletons)」——本 ADR 的擁有模式決策(見 Decision)直接回應此約束。
- **`.claude/rules/design-docs.md`**:single source of truth per term——本 ADR 不重述 GDD 已定義的規則細節(例如公式一/二/三/四的完整數學式),只在需要說明「為何選這個型別/機制」時引用 GDD 章節名稱,不複製規則本身。
- **5 名主角尚未定名**:`design/registry/entities.yaml` 目前無任何角色命名,角色系統本身尚未設計(`systems-index.md` 標記 Not Started)。本 ADR 的 `Character`/`Pair` enum 必須使用佔位識別碼,且設計上須讓角色系統定案實際命名時,只需改動 enum 值名稱本身,不影響任何呼叫端邏輯。
- **存檔格式與並發模型皆為 Open Question**(`TR-save-001`、`TR-save-005`):本 ADR 不得對存檔系統的最終選擇做任何假設,見上方 ADR Dependencies「Ordering Note」。
- **無例外處理機制**:GDScript 無 try/catch,錯誤處理須以回傳值(enum 結果碼或結構化 Result 物件)表達,不得以 `push_error()` 取代呼叫方需要程式化判斷的錯誤路徑(`push_error()` 僅用於「理論上不該發生、發生了代表呼叫方邏輯錯誤」的斷言式警告,例如逾時卡死偵測)。

### Requirements

本 ADR 須同時滿足 `affinity-data-pool.md` 的下列義務群組(義務原文以該文件為準,此處僅列出機制須支撐的內容,完整逐項對應見下方 GDD Requirements Addressed):

1. **資料結構**(Core Rules #1、共用符號表):Delta Log 為只增不減的 5 欄型別化記錄集合,依配對索引,查詢複雜度 `O(n_p + m)`;獨立的戰役刻度標記列表;獨立的陣亡標記表;三者皆非 Delta Log 本身衍生。
2. **寫入契約**(Core Rules #2、Edge Cases):附加記錄、前進戰役刻度、陣亡通知三個獨立寫入介面,合計 7 類明文拒絕情境,fail-loud、不靜默糾正。
3. **讀取契約**(Core Rules #3/#4/#5、Formulas 公式一至四):三個純函數讀取 + 公式四純函數預判,依配對/來源/查詢時間點運作,陣亡配對的預設查詢時點依函數性質分流,計數器可觀測性隨回傳值附帶,QA 專用走訪筆數診斷輸出獨立於正式回傳簽章。
4. **並發契約**(Core Rules #6):序列化生命週期通知介面為權杖式(非布林),支援多個同時存在的非原子視窗,逐權杖逾時偵測(非整批清空),權杖 ID 永不重新發放,若涉及背景執行緒須執行緒安全。
5. **持久化契約**(Dependencies 存檔系統列、反序列化語意驗證規則宣告):無損序列化/還原 Delta Log、戰役刻度標記列表、陣亡標記表三份結構;`Pair`/`source_i` 以字串名稱持久化;本系統是逐欄位值域與 5 條跨結構不變量的唯一權威來源,格式本身不受本 ADR 決定。

## Decision

採用**依配對索引的 typed GDScript class**(非 Resource、非扁平陣列)承載 Delta Log,搭配**三個結構上互相獨立的持久化結構**(Delta Log、戰役刻度標記列表、陣亡標記表),以及**單調遞增 int 權杖 + 無條件 Mutex 保護**的序列化生命週期機制。擁有模式為**依賴注入的一般物件實例**,不採 Autoload。

### 核心洞見:為什麼本 ADR 的資料結構決策要與存檔格式解耦

`affinity-data-pool.md` 明文自己是「唯一不需要等待其他系統設計完成即可實作的資料層」,但存檔系統的序列化格式(`TR-save-001`)與寫入並發模型(`TR-save-005`)兩者都還是 Open Question。若本 ADR 選擇 Godot `Resource` 子類別作為 Delta Log 的載體,等於預先替存檔系統 ADR 做了格式決定(`Resource` 天然綁定 `ResourceSaver`/`.tres` 或至少強烈傾向該路徑)——這正是 GDD 明文排除的耦合。因此本 ADR 的資料結構全部採用**格式無關的 plain typed class**(`RefCounted` 基底),並額外定義 `to_dict()`/`from_dict()` 轉接層,讓存檔系統 ADR 未來選擇任何容器格式都能直接消費同一份邏輯結構,不需要回頭修改本 ADR。

### 機制一:擁有模式——依賴注入,非 Autoload

`AffinityDataPool` 為一般類別(`RefCounted` 基底,無場景樹依附需求——本系統不持有任何 `Node`,不需要 `_process`/訊號連線以外的場景樹能力),於戰役開始時由持有者(戰役層級的 controller,具體節點留待 `/create-architecture` 決定)建構一次,以參照方式注入給需要它的系統(技能卡牌、支援對話、章節/戰役結構、戰棋移動與交戰系統、好感度—位置連鎖、敘事解鎖與結局分支、存檔系統)。

**理由**:`.claude/docs/coding-standards.md` 明文要求「All public methods must be unit-testable (dependency injection over singletons)」。Autoload 單例雖是 Godot 慣用手法,但會讓單元測試必須清空/重建全域狀態才能隔離測試案例(本系統的 7 類拒絕情境、跨結構不變量等需要大量獨立、確定性的測試案例,見 GDD Acceptance Criteria 章節與 `.claude/docs/coding-standards.md` Testing Standards)。依賴注入模式下,測試可直接 `new` 一個乾淨實例,不受其他測試案例殘留狀態污染,也不需要引擎執行環境即可測試(純 GDScript 物件,無場景樹依賴)。

### 機制二:Delta Log 儲存——per-pair 索引的 typed class

**共用列舉的檔案歸屬(2026-08-18 `godot-specialist` 驗證發現,BLOCKING 修訂)**:`godot-specialist` 審查本 ADR 初稿時指出,GDScript 沒有「不透過任何 class 包裝、跨檔案可見的裸列舉」這回事——列舉若定義在某個 `class_name` 的類別內,只能以 `ClassName.EnumName` 從其他檔案存取;若腳本連 `class_name` 都沒有,則只能靠 `preload()` 存取。若 `Pair`/`Character`/`Source` 三個跨系統共用的列舉裸露宣告、卻被 `AffinityRecord`(另一個檔案)未經限定地直接使用,不會通過編譯。修訂為:三者集中定義於獨立的 `affinity_types.gd`,以 `class_name AffinityTypes` 包裝,所有其他類別一律以 `AffinityTypes.Pair`、`AffinityTypes.Character`、`AffinityTypes.Source` 限定存取——這同時避免了三個高碰撞風險的裸全域類別名稱(`Pair`、`Character`、`Source` 本身語意過於通用,未來其他系統或 addon 命名衝突風險較高),集中為單一 `Affinity` 字首命名空間。各方法自身的結果列舉(`WriteRejection`、`AdvanceRejection`、`DeathNotifyResult`、`EndTokenResult`、`ReadRejection`、`SpeculativeRejection`、`ReadMode`)不受此修訂影響,維持巢狀於 `AffinityDataPool` 內、以 `AffinityDataPool.WriteRejection` 等方式限定存取(它們只在呼叫 `AffinityDataPool` 自身方法的上下文中使用,不需要獨立抽出)。

```
# ─── affinity_types.gd ───────────────────────────────────────
class_name AffinityTypes extends RefCounted

enum Character { CHARACTER_1, CHARACTER_2, CHARACTER_3, CHARACTER_4, CHARACTER_5 }
# 佔位識別碼——角色系統(Not Started)定案實際命名時,只需重新命名這 5 個 enum 值本身,
# 呼叫端邏輯（一律以 AffinityTypes.Character 列舉值溝通,不假設任何具體名稱字串）不受影響。

enum Pair {
    C1_C2, C1_C3, C1_C4, C1_C5,
    C2_C3, C2_C4, C2_C5,
    C3_C4, C3_C5,
    C4_C5,
}  # 5 名固定主角、10 對固定組合,遊戲全程封閉且固定（GDD Edge Cases「配對集合是封閉且固定的」）

enum Source { COMBAT_CARD, SUPPORT_CONVERSATION, STORY_EVENT }

static func pair_of(a: Character, b: Character) -> Pair: ...
```

`AffinityTypes.pair_of(a: Character, b: Character) -> Pair`:正規化建構函式,內部以固定查表(而非依賴呼叫順序)消除 `pair_of(A,B)` 與 `pair_of(B,A)` 的歧義,呼叫端永遠不需要自行決定兩個 `Character` 的排列順序。

`AffinityRecord`(`RefCounted` 基底,5 個型別化欄位——直接回應 `TR-affinity-001` 對「須用具型別類別而非 `Array[Dictionary]`」的要求):

```
class_name AffinityRecord extends RefCounted
var pair: AffinityTypes.Pair
var m: float       # 帶號幅度,非零有限浮點數
var t: int          # 全域好感度寫入計數器值,寫入時指派,≥1
var c: int          # 戰役刻度計數器值,寫入當下的現值,≥0
var source: AffinityTypes.Source
```

**`AffinityRecordList` —— 繞過 GDScript 不支援巢狀型別容器的包裝層(2026-08-20 BLOCKING 修訂)**:

```
class_name AffinityRecordList extends RefCounted
var items: Array[AffinityRecord] = []
```

本 ADR 初版把 per-pair 儲存寫成 `var _records: Dictionary[AffinityTypes.Pair, Array[AffinityRecord]]`。2026-08-20 的引擎行為驗證 spike 與 `godot-gdscript-specialist` 的獨立交叉覆核在 Godot 4.7.1 實機測出**這一行無法編譯**:

```
Parse Error: Nested typed collections are not supported.
   at: GDScript::reload (res://scripts/x9_adr_member_exact.gd:2)
```

探針第 2 行的型別註記與本 ADR 原文**逐位元組相同**,parse error 定位在**宣告那一行本身**。覆核者另補測 **class member 無初始化 / 函式參數 / 回傳型別三種語法形狀,全部同一錯誤**,並在**完全獨立的專案**(不同 `project.godot`、不同 `.godot` 快取)重現——這不是快取或專案設定問題,是語言層限制,沒有語法逃生口。

在**本次驗證實際涵蓋的四個候選方案**中,`AffinityRecordList` 是**唯一同時保住兩層型別**的選項(其餘三個:`Dictionary[AffinityTypes.Character, int]` 單層合法但不適用於 Delta Log;`Array[AffinityRecord]` 單獨合法但失去 per-pair 索引,即 GDD 明文排除的扁平陣列反模式;`Dictionary[Pair, Array]` 見 Alternative 7)。實測(`x3_wrapper_two_layer.gd`):

| 量測項 | 值 |
|---|---|
| `script.get_global_name()` | `AffinityRecordList` |
| `v is AffinityRecordList` | `true` |
| `inner.items.is_typed()` | `true` |

> **不可引用 `get_class()` 的輸出作為此結論的證據**:它回傳**原生**類別,任何 `RefCounted` 子類別都印 `RefCounted`,無法區辨包裝類別、也從未碰到內層。2026-08-20 的覆核推翻了 spike 原本以 `get_class()` 為依據的同一結論——結論湊巧為真,證據無效。此處引用的是覆核者改測的三項。

**代價**:多一個全域 `class_name`(碰撞風險見 Risks 表既有列,前綴 `Affinity` 與其餘六個一致),以及所有存取多一層 `.items`。**收益**:內層元素型別由 `AffinityRecordList` 自身的宣告式 `var items: Array[AffinityRecord] = []` 保證,**不經任何 subscript 型別推斷路徑**(見機制四的實作提醒——subscript 賦值已實測**不**推斷元素型別)。

`AffinityDataPool` 內部儲存:

```
var _records: Dictionary[AffinityTypes.Pair, AffinityRecordList]      # per-pair 索引,查詢 O(n_p)
var _t_now: int                                          # 執行期快取,見下方「衍生值」說明
var _campaign_tick_marks: Array[int]                     # append-only,見下方
var _death_marks: Dictionary[AffinityTypes.Character, int]             # 獨立於 Delta Log
var _next_token_id: int
var _serialization_tokens: Dictionary[int, int]          # token id → 發放當下 Time.get_ticks_msec()
var _token_mutex: Mutex
```

**`Dictionary[AffinityTypes.Pair, AffinityRecordList]` 直接滿足 `TR-affinity-002`(O(n_p+m) 效能契約)**:單一配對查詢只需 `_records[pair]`(O(1) 鍵查找)取得該配對自身的 `AffinityRecordList`,再以 `.items` 取得其型別化 `Array`,不掃描其他配對——這正是 GDD 明文排除的「單一扁平陣列 + 全表掃描過濾」反模式。**包裝層只改變值槽的型別,不改變鍵查找複雜度**,故此論證與初版完全相同。**`Pair`/`Character` enum 皆為值型別(底層是 int)**,直接滿足 `TR-affinity-003`(Dictionary 鍵須為值型別,不可為 Object/Resource 參照)——本專案已知的 GDScript 參照相等陷阱不適用於此:`AffinityRecord` 與 `AffinityRecordList` 雖皆為 `RefCounted`,但**兩者都只作為值、從未被用作任何 Dictionary 的鍵**(前者是 `items` 的元素,後者是 `_records` 的值)。

**`_t_now` 是執行期快取,不是獨立持久化欄位**(直接滿足 `TR-affinity-004`「衍生值,不得另存」):載入完成後(`import_state()` 執行完畢時)由 `_records` 各配對 `AffinityRecordList.items` 長度總和一次性重建(`O(n_total)`,只在載入時發生一次,不影響任何單次查詢的複雜度保證);運行期每次 `append_record()` 成功時 `+1`。序列化時**不**輸出 `_t_now` 欄位本身,只輸出 `_records`——這避免了「儲存的衍生值與實際內容不同步」這一類本專案已知的傳播失敗模式(見 `.claude/docs/context-management.md` 對跨檔同步失敗的一般性警語)。

**`_campaign_tick_marks: Array[int]` 是獨立於 Delta Log 的 append-only 結構**(滿足 `TR-affinity-005`):每次 `advance_campaign_tick()` 呼叫時,附加當下的 `_t_now` 值。`c_now(t_query)` 的重建演算法(見 GDD Formulas 3c 精確定義)為「`_campaign_tick_marks` 中 `≤ t_query` 的標記筆數」——本 ADR 的實作選擇是對 `_campaign_tick_marks` 做線性計數(`O(m)`,`m` = 標記總數),滿足 GDD 鎖定的 `O(n_p+m)` 契約;**由於 `_campaign_tick_marks` 依寫入順序天然遞增排序,`/create-architecture` 或未來效能優化階段可選擇改用二分搜尋降至 `O(log m)`,但這是超出 GDD 契約的加分優化,本 ADR 不強制要求**,以免對尚未有實測需求的效能項目過度工程化。

### 機制三:陣亡標記表——獨立結構,O(1)

```
func notify_death(character: AffinityTypes.Character) -> DeathNotifyResult
```

`_death_marks: Dictionary[AffinityTypes.Character, int]`:鍵為 `Character`(5 名固定主角之一,值型別),值為呼叫當下的 `_t_now`(**不遞增** `_t_now` 本身——比照 GDD Core Rules #1「此呼叫不遞增全域好感度寫入計數器」)。冪等性拒絕:若 `character` 已存在於 `_death_marks`,回傳 `DUPLICATE_DEATH_NOTIFICATION`,不覆寫既有標記。

`t_death(pair: AffinityTypes.Pair) -> Variant`(回傳 `int` 或 `null`):對 `pair` 的兩名成員各查一次 `_death_marks`(至多 2 次鍵查找,O(1),不影響 `TR-affinity-002`/`Core Rules #1` 的效能保證),取較早值;兩者皆不存在時回傳 `null`。

**呼叫順序不由本系統裁決**(`TR-affinity-008`):`notify_death()` 與 `append_record()` 皆為單純同步方法,呼叫立即生效、不排隊、不緩衝——這保證「呼叫方實際呼叫這兩個介面的順序」就是唯一決定同結算步內寫入合法性的因素,如 GDD Core Rules #1「範圍澄清」段落所要求。**戰棋移動與交戰系統的死亡結算流程須自行定案這兩個呼叫的相對順序**(見 `affinity-data-pool.md` Dependencies 章節新增義務),本 ADR 不預設任一順序為正確,只保證系統本身不引入任何會打亂呼叫順序的內部佇列或非同步排程。

### 機制四:寫入路徑——7 類拒絕情境,fail-loud

```
enum WriteRejection {
    NONE,
    SERIALIZATION_WINDOW_ACTIVE,      # 序列化/還原非原子視窗期間
    ZERO_AMPLITUDE,                    # m == 0
    NON_FINITE_AMPLITUDE,              # m 為 NaN 或 ±Infinity
    INVALID_SOURCE,                    # source 不在三個合法值之內
    INVALID_PAIR,                      # pair 不在 10 對固定組合內
    DEAD_PAIR_COMBAT_CARD_FORBIDDEN,   # 配對已符合 t_death(pair) 條件,且 source == COMBAT_CARD
}

func append_record(pair: AffinityTypes.Pair, m: float, source: AffinityTypes.Source) -> WriteRejection
```

`append_record()` 的驗證順序(由本 ADR 決定,GDD 未規定順序,只規定情境本身須被涵蓋):

1. `_serialization_tokens` 非空 → `SERIALIZATION_WINDOW_ACTIVE`(最先檢查,避免任何副作用發生在資料被視為凍結快照的期間)
2. `m == 0.0` → `ZERO_AMPLITUDE`
3. `is_nan(m) or is_inf(m)` → `NON_FINITE_AMPLITUDE`
4. `source` 不在合法列舉值 → `INVALID_SOURCE`(GDScript enum 本身型別化後這條理論上不可達,但保留作為跨語言邊界輸入的防禦層,例如若上游從存檔還原路徑之外的其他管道注入)
5. `pair` 不在合法列舉值 → `INVALID_PAIR`(同上)
6. `t_death(pair) != null and source == AffinityTypes.Source.COMBAT_CARD` → `DEAD_PAIR_COMBAT_CARD_FORBIDDEN`

全數通過 → 建立 `AffinityRecord`,附加至 `_records[pair].items`,`_t_now += 1`,回傳 `WriteRejection.NONE`,並 emit `entry_appended(pair, record)` 訊號(見機制七)。任何拒絕路徑皆不遞增 `_t_now`、不附加記錄,對應 GDD「不遞增全域計數器、不產生記錄」的一致慣例。

**實作提醒(2026-08-18 `godot-specialist` 提出,2026-08-20 實機驗證後改寫)**:首次對某配對寫入時,需先建立該配對的 `AffinityRecordList`——`_records[pair] = AffinityRecordList.new()`,再 `_records[pair].items.append(record)`。原本「無法確認 subscript 賦值是否可靠推斷元素型別」的疑問**已實測定案:不推斷**(把未型別化字面量以 subscript 賦值存入型別化 `Dictionary` 的值槽後讀回,`is_typed()` 為 `false`)。這正是包裝類別相對 Alternative 7 的一項附帶收益:`items` 的元素型別由 `AffinityRecordList` 自身的宣告式 `var items: Array[AffinityRecord] = []` 保證,**完全不經 subscript 推斷路徑**;而值槽本身的型別(`AffinityRecordList`)由下述層一的編譯期檢查守住。

### 機制四之二:型別保證分三層,與兩條邊界規則(2026-08-20 實機驗證新增)

本 ADR 初版對「型別化容器」的措辭把型別標註當成**單一層**的保證。實機驗證顯示它是**三層**,且三層的強度、失敗方式、以及**是否可依賴**都不同:

| 層 | 機制 | 實測結果 | 可依賴? |
|---|---|---|---|
| **一** | GDScript 編譯期靜態檢查 | **確實擋 enum 家族**:`Cannot assign a value of type "AffinityTypes.Character" as "AffinityTypes.Pair"`;容器整體賦值同樣擋(`Dictionary[Character,int]` 不可賦給 `Dictionary[Pair,int]`) | **是**——編譯期錯誤,是結構保證 |
| **二** | C++ 容器驗證(`container_type_validate.h`) | debug 建置下確實生效,但**兩種寫入路徑行為不同**:錯誤 `Object` 類別寫進 `Dictionary` 值槽 → 錯誤 + `SCRIPT ERROR` + **所在函式中止**;錯誤元素 `append` 進型別化 `Array` → 錯誤 + **寫入被丟棄**,`size()` 不變。⚠️ **差異的成因是「subscript 賦值運算子」vs「方法呼叫」,不是「`Dictionary`」vs「`Array`」**——這張表不可據以類推到 `Dictionary.merge()`、`Array.erase()` 等其他寫入路徑 | **否**——export release 建置下是否仍生效**未查證**(見 Verification Required 第 7 項) |
| **三** | 型別化 `Dictionary` 的 **subscript 鍵**路徑 | **完全不擋**:`Dictionary[Pair,int][Character.CHARACTER_3] = 99` → `size=1`、`keys=[2]`、**零錯誤訊息**。機制是 `get_typed_key_builtin() == 2`(`TYPE_INT`)——enum 家族在容器層被抹成 `int`,`Character` 與 `Pair` 在鍵型別上不可區辨 | **否**——已實證為空隙 |

**因此本 ADR 明訂兩條邊界規則——鍵與值是兩件事,分別對應層三與層二**:

> **規則一(鍵邊界,對應層三)**:所有從本系統**外部**進入 `_records` / `_death_marks` 的**鍵**,一律經 `func f(pair: AffinityTypes.Pair)` 這類**型別化參數簽章**收斂;**禁止**把來源為 `Variant`(或未經型別化參數收斂的值)直接當作 subscript 鍵。
>
> **規則二(值邊界,對應層二)**:`_records` / `_death_marks` 的**值**一律由本系統自身方法以**靜態型別**建構後賦值——`_records[pair] = AffinityRecordList.new()`(`.new()` 的回傳值靜態型別即 `AffinityRecordList`,在層一編譯期即受檢)、`_records[pair].items.append(record)`(`record` 為本系統內部建構的 `AffinityRecord`)、`_death_marks[character] = _t_now`(`int`)。**外部呼叫者沒有任何路徑可以把 `Variant`/`Object` 直接寫進這兩個容器的值槽**——三個公開寫入方法只接收型別化的純量與 enum,不接收容器或物件;`import_state()` 是唯一一條外來資料路徑,其防線見機制八。

**兩條規則各自關掉一層,不可互相代用**:

- **規則一關掉層三**。層三是已實證的空隙(錯誤家族的 enum 鍵經 subscript 寫入完全不被攔),規則一把外來鍵推回層一的編譯期檢查——那一層已實證會擋,空隙因此關在系統邊界之外。
- **規則二關掉對層二的依賴**。層二量測的是**值槽被塞進錯誤 `Object` 類別**,與「鍵是否跨 enum 家族」**是兩件不同的事**。⚠️ 本次修訂的初稿曾用規則一去支撐「層二可降級」,那是**不成立的推導鏈**(論證的是另一件事),已由寫入前的 Step 5.5 覆核抓出並改正。真正讓層二降為縱深防禦的是規則二:值從來不經 `Variant` 中介,層一在賦值處就檢查完畢,層二的 C++ 容器驗證只是同一件事的第二道確認。

**兩條規則都不改變任何既有簽章**——本 ADR 的公開介面本來就全部符合(`append_record`/`can_write`/三個讀取函數/`notify_death` 的參數皆為型別化 enum 與純量)。它們把兩個原本隱含的性質升級為明文的、可被 registry 強制的架構約束(見 `raw_variant_subscript_into_typed_container`),並指明未來新增介面時不得破壞。

**效果**:層二在 export release 建置下是否仍生效(Verification Required 第 7 項,未查證),**不再影響本 ADR 的正確性論證**。這與本 ADR C3 修訂對 `Mutex`、ADR-0004 對 `SaveIOBackend` 是**同一個手法**:把未查證的外部行為隔離成「有則更好」,而非「正確性所繫」。**但唯一的外來資料路徑 `import_state()` 不受這兩條規則保護**——它處理的就是本系統外部產生的 `Dictionary`,那條路徑的防線是 `validate_semantics()`,見機制八。

**失敗模式為何值得這樣防**(不是崩潰,是靜默存檔損壞、且出貨版本專屬):錯誤型別的鍵或值若被靜默寫入 `_records`(層三路徑:無錯誤、無中止、`size()` 增加),四個讀取函數迭代到型別不符的元素時,公式一/二會產生 `NaN` 或在**離寫入點很遠**的地方爆;更糟的是壞值會經 ADR-0003 的 `var_to_bytes()` 寫進存檔並**通過該 ADR 的兩層 SHA-256 雜湊鏈**——雜湊驗的是位元組完整性,不是語意合法性。存檔在位元層完全合法、在語意層已損壞。

### 機制四之三:驗證順序的安全性,與呼叫端的型別義務(2026-08-20 實機驗證新增)

**機制四的驗證順序不需要改,而理由現在是實測而非推論**:`append_record(pair, m: float, source)` 的 `m` 是**型別化參數**,實測確認一個夾帶 `String` 的 `Variant` 在**呼叫端**就被擋下——函式本體從未執行。因此步驟 2(`m == 0.0`)與步驟 3(`is_nan(m) or is_inf(m)`)在進入時 `m` 必為 `float`,兩者都不會踩到機制八記載的中止路徑。**這是規則二(值邊界)的保證,不是規則一(鍵邊界)的**——兩者不可互相引用。

**但這條保護有一個必須明文的代價——呼叫端義務**:型別化參數的阻擋方式是**整段呼叫端函式中止**,不是一個可判斷的回傳值。本 ADR 的錯誤處理哲學是「GDScript 無 try/catch,錯誤一律以回傳值表達」(見 Constraints),而型別錯誤是這條哲學**唯一涵蓋不到**的失敗類別:`append_record()` 不可能回傳一個 `INVALID_TYPE`,因為那個呼叫根本到不了函式本體。

因此:**上游系統若持有來源不明的 `Variant`(例如從存檔、從編輯器匯入的資料表、從尚未定案的角色系統傳來的識別碼),必須在呼叫 `append_record()`/`notify_death()` 之前自行以 `typeof()` 收斂型別**,不能把型別驗證的責任推給本系統的拒絕碼機制。本 ADR 的 7 類 `WriteRejection` 涵蓋的是**值域與狀態**的非法,**不涵蓋型別的非法**——這個範圍界線先前是隱含的,現在明文寫出。

**本 ADR 刻意不新增 `WriteRejection.INVALID_TYPE`**:那會是一個結構上不可能被回傳的死碼,反而誤導呼叫方以為型別錯誤會被本系統攔下並回報。

```
func advance_campaign_tick() -> AdvanceRejection   # 目前僅 SERIALIZATION_WINDOW_ACTIVE 一種拒絕情境
func notify_death(character: AffinityTypes.Character) -> DeathNotifyResult   # SERIALIZATION_WINDOW_ACTIVE / DUPLICATE_DEATH_NOTIFICATION
```

**恰兩個方法改變 Delta Log/戰役刻度本身的狀態**(`append_record`、`advance_campaign_tick`),回應 `TR-affinity-010`/AC-1——`notify_death`、`begin_non_atomic_window`、`end_non_atomic_window` 是額外的合法狀態改變方法,但它們改變的是**結構上獨立**的陣亡標記表與權杖集合,不是 AC-1 定義範圍內的「既有記錄(或既有標記)」,不構成對 AC-1 逐字宣稱的違反——這點在 GDD Requirements Addressed 表中進一步說明,以避免下游 QA 誤讀 AC-1 為涵蓋全系統唯二 mutator。

### 機制五:讀取路徑——三個純函數 + 公式四,條件式預設查詢時點

```
class AffinityReadResult extends RefCounted:
    var value: float
    var t_query: int
    var n_pair: int
    var diagnostic_visited_count: int  # QA-only,見機制六——業務邏輯不得依賴此欄位

class ShapeFeatureResult extends RefCounted:
    var reversal_count: int
    var source_distribution: Dictionary  # {n_cc, n_sc, n_se, p_cc, p_sc, p_se}
    var time_distribution: Variant       # {span_c, spread_ratio} 或 null(n_pair==0 時)
    var source_polarity: Dictionary      # {net_cc, net_sc, net_se}
    var total_churn: float
    var segment_profile: Variant         # Array 或 null(n_pair==0 時)
    var low_confidence: Variant          # bool 或 null(n_pair==0 時)
    var source_absence: Dictionary       # {cc, sc, se} 三態 enum
    var n_pair: int
    var t_query: int
    var c_now: int
    var diagnostic_visited_count: int

func combat_strength_read(pair: AffinityTypes.Pair, t_query: Variant = null) -> AffinityReadResult
func narrative_depth_read(pair: AffinityTypes.Pair, t_query: Variant = null) -> AffinityReadResult
func shape_feature_read(pair: AffinityTypes.Pair, t_query: Variant = null) -> ShapeFeatureResult
```

**條件式預設查詢時點**(`TR-affinity-021`,實作 GDD Core Rules #3):`t_query` 省略(`null`)時——

- `combat_strength_read`/`narrative_depth_read`:若 `t_death(pair) != null`,預設為 `t_death(pair)`;否則預設為目前 `_t_now`。
- `shape_feature_read`:一律預設為目前 `_t_now`,不受陣亡凍結規則影響(GDD 明文要求形狀特徵須能反映陣亡後的追憶寫入)。

`t_query` 大於目前 `_t_now`(僅適用三個真實讀取函數,不適用公式四)一律視為非法呼叫,回傳值以 `ReadRejection.FUTURE_TIME_QUERY` 表達(獨立於 `AffinityReadResult`,見下方公式四段落的錯誤處理模式一併說明)。

公式四(預判/假設性讀取):

```
class HypotheticalEntry extends RefCounted:
    var source: AffinityTypes.Source
    var m: float

enum SpeculativeRejection { NONE, EMPTY_HYPOTHETICAL_SET, DEAD_PAIR_NOT_ALLOWED }
enum ReadMode { COMBAT, NARRATIVE }

func speculative_read(pair: AffinityTypes.Pair, hypothetical_entries: Array[HypotheticalEntry], mode: ReadMode) -> Variant
# 回傳 AffinityReadResult 或 SpeculativeRejection(呼叫端以型別檢查區分)
```

- `hypothetical_entries.is_empty()` → `EMPTY_HYPOTHETICAL_SET`(`TR-affinity-022`「呼叫合法性前提」,GDD 明文豁免只在至少一筆假設性記錄時成立)。
- `t_death(pair) != null` → `DEAD_PAIR_NOT_ALLOWED`(GDD 第十一輪裁決:公式四對陣亡配對一律拒絕呼叫,理由是陣亡配對唯一合法的假設性寫入來源本就不改變凍結讀值,拒絕優於「偽成功」)。
- 否則:依序指派嚴格遞增的虛擬 `t_new`(`_t_now+1, _t_now+2, ...`,依 `hypothetical_entries` 陣列順序),`t_query` 內部固定為最後一筆的 `t_new`(呼叫端不得覆寫此值——公式四本身即是「若現在依序打出全部假設性項目」的查詢,`t_query` 由假設性項目數量決定,不是自由參數,這點比 GDD 原文「呼叫慣例」更嚴格收斂,理由是本 ADR 選擇不對外開放看似自由實則有隱藏合法上下限的參數,降低誤用面)。

### 機制六:計數器可觀測性與 QA 診斷輸出的分離

`AffinityReadResult`/`ShapeFeatureResult` 的 `t_query`/`n_pair`(/`c_now`)欄位是正式回傳簽章的一部分(`TR-affinity-013` 前半),`diagnostic_visited_count` 是**同一個回傳物件上的獨立唯讀欄位**,但以文件明確標記為 QA/除錯專用——不透過額外的方法多載或旁路查詢介面提供(避免介面爆炸),而是直接附掛在既有回傳物件上,呼叫端的業務邏輯**不得**讀取此欄位做任何判斷,只有 `AC-55` 對應的自動化測試允許讀取它來驗證 `O(n_pair)` 保證是否成立。**此診斷刻意不涵蓋陣亡標記表與權杖集合的存取次數**(GDD Core Rules #1 診斷可觀測性要求的明文排除),理由同 GDD:兩者鍵集合規模上界為 5,遠低於任何實務可觀測的效能風險門檻。

### 機制七:序列化生命週期——單調遞增 int 權杖 + 無條件 Mutex

```
enum EndTokenResult { RELEASED, TIMED_OUT_RECLAIMED, INVALID_TOKEN }

func begin_non_atomic_window() -> int
func end_non_atomic_window(token: int) -> EndTokenResult
signal entry_appended(pair: AffinityTypes.Pair, record: AffinityRecord)
```

- **權杖型別為單調遞增 `int`**(`_next_token_id` 只增不減,絕不重新發放),取代 GDD 原文允許的「不透明權杖」之抽象描述的一個具體實作選擇。**理由**:`RefCounted` 物件身分作為權杖雖然能讓 GC 自動回收未持有的權杖,但本專案已在 `TR-affinity-003` 明文警告過 GDScript 的參照相等陷阱——用物件身分做權杖等值比對,容易在除錯/日誌輸出時無法印出穩定 ID(只能印記憶體位址或依賴 `get_instance_id()`,間接繞回同一類問題),且與本 ADR 已選擇的「值型別鍵」慣例(`Pair`/`Character` enum)不一致。單調遞增 int 沒有這個問題,序列化/記錄檔輸出也天然可讀。
- **`begin_non_atomic_window()`**:取得 `_token_mutex` 鎖,`_next_token_id += 1`,記錄 `_serialization_tokens[new_id] = Time.get_ticks_msec()`,釋放鎖,回傳 `new_id`。
- **`end_non_atomic_window(token)`**:取得鎖後檢查—— 若 `token` 存在於 `_serialization_tokens`:移除該項,釋放鎖,回傳 `RELEASED`。若 `token` 存在於下方「短期保留的已逾時權杖集合」`_reclaimed_tokens: Dictionary[int, bool]`:回傳 `TIMED_OUT_RECLAIMED`(非故障結果,不移除——已在逾時回收時處理過)。皆不存在:回傳 `INVALID_TOKEN`(涵蓋未知權杖、重複釋放、空集合時呼叫三種情境,統一為單一驗證錯誤分類,對應 GDD Core Rules #6「非法呼叫一律拒絕」)。
- **「操作進行中」判準**:`_serialization_tokens` 非空 ⇔ 寫入方法(`append_record`/`advance_campaign_tick`/`notify_death`)一律拒絕(`SERIALIZATION_WINDOW_ACTIVE`)——與 ADR-0001 的 `settlement_in_progress` 拒絕式輸入閘門精神一致,但機制上是獨立的多權杖集合而非單一布林,滿足 `save-system.md` Core Rules #2 允許多槽並行操作的前提(見 GDD Core Rules #6「為何不能是布林旗標或裸計數」段落)。
- **逐權杖惰性逾時清除**(`TR-affinity-015`,不使用獨立 `Timer` 節點輪詢):`begin_non_atomic_window`/`end_non_atomic_window`/任一寫入方法呼叫時,先檢查 `_serialization_tokens` 中是否有任何 `issue_time` 早於 `Time.get_ticks_msec() - TOKEN_TIMEOUT_MS`(Tuning Knob,待校準,GDD 未定案具體值——本 ADR 亦不定案,留給實測)的殘留權杖;若有,將其從 `_serialization_tokens` 移除、加入 `_reclaimed_tokens`(短期保留識別碼,供上方 `TIMED_OUT_RECLAIMED` 判斷用;`_reclaimed_tokens` 本身也需要一個更長的次要逾時上限以避免無限成長,建議值同樣留待實測,不在本 ADR 定案)。**理由選擇惰性檢查而非專屬 `Timer`**:本系統的讀寫呼叫頻率(每次好感度事件、每次戰役刻度推進)已足夠密集,足以驅動逾時清除,額外常駐一個 `Timer` 節點的 `_process`/訊號成本是不必要的重複開銷,且會讓本系統重新產生「需要掛在場景樹上」的依賴,與機制一的 DI-only 擁有模式衝突。
- **無條件 Mutex 保護**(`TR-affinity-016`):`_serialization_tokens`(以及 `_reclaimed_tokens`)的所有讀寫皆由 `_token_mutex` 保護,不論存檔系統最終選擇同步阻塞式寫入或背景執行緒序列化。**理由**:GDD 條件句「若架構階段選擇背景執行緒序列化,須明確以 Mutex 保護」把決定權交給本 ADR,而存檔系統執行模型 ADR 尚未撰寫——若本 ADR 選擇「條件式加 Mutex」,等於讓本 ADR 的並發正確性論證懸空等待一個尚未存在的 ADR,且未來若真的選擇背景執行緒,需要回頭修改本 ADR 與已寫好的程式碼。無條件加 Mutex 的成本可忽略(集合規模上界是「同時存在的非原子視窗發起者數」,遠小於 Delta Log),換來的是本 ADR 現在就能宣告完整、不需要任何未來的條件式修訂。

**2026-08-19 修訂 —— C3 銜接缺口:條件已解,但保留為縱深防禦**(第二輪 `/architecture-review` 提出,第三、四輪重申仍開):`TR-affinity-016` 是**條件式**需求(「**若**架構階段選擇背景執行緒序列化,須明確以 `Mutex` 保護」)。該條件此後已由 **ADR-0004 判為「否」**——`SaveIOBackend` 的現行實作為**同步阻塞式**,不引入任何背景執行緒,且該 ADR 明文加上主執行緒斷言。因此本節原本的措辭「**全專案唯一已宣告的執行緒安全義務**」現在容易被誤讀為「專案內存在跨執行緒競爭」——實際上**目前不存在**。

**決策不變:`Mutex` 保留,理由改為縱深防禦而非必要性。** 理由:(i) 移除它需要修改本 ADR 與未來已寫好的程式碼,而 ADR-0004 的 `SaveIOBackend` **本來就是為了將來可替換而設計的抽象**(該 ADR 明文把主機 SDK 的非同步 I/O 列為未解決的 Open Question 9);若日後替換為背景執行緒實作,`Mutex` 已在位。(ii) 保留的成本可忽略(見上),移除的收益趨近於零,而移除後再加回來要重新推導一次並發正確性論證。**但本 ADR 不再宣稱這是「已成立的執行緒安全義務」——它是一個目前無競爭對手的鎖。** 見 `docs/architecture/adr-0004-save-system-atomic-write-and-migration-execution-model.md` 機制五/`SaveIOBackend`。
- **鎖定模式:單一進入點取鎖,逾時清除以「假設已持鎖」的私有輔助函式實作**(2026-08-18 `godot-specialist` 驗證發現,回應對「機制七是否會有巢狀 `lock()` 呼叫」的查核)——`begin_non_atomic_window`/`end_non_atomic_window`/每個寫入方法皆在**公開進入點**呼叫一次 `_token_mutex.lock()`,惰性逾時清除邏輯抽成私有的 `_sweep_timed_out_tokens_unlocked()`,**只假設鎖已持有、自己絕不呼叫 `lock()`/`unlock()`**,只能從已持鎖的區塊內呼叫。**理由**:`godot-specialist` 查核時本專案無 Godot 執行環境可實測、亦無對應模組參考文件,無法確認 4.7.1 的 `Mutex` 是否為可重入鎖(同執行緒重複 `lock()` 是否死結)——訓練資料傾向判斷是可重入,但這是**未經專案驗證**的假設(見上方 Engine Compatibility 表 Verification Required 第 4 項)。此鎖定模式讓正確性**不依賴這個未驗證的答案**:不論 `Mutex` 是否可重入,「只有一個地方真正呼叫 `lock()`」的設計都不會死結,也不會在得知答案前留下一個可能錯的假設。
- **`entry_appended` 訊號**(`TR-affinity-024`):`append_record()` 成功時 emit,供好感度視覺呈現 UI 等下游做反應式更新。GDD 明文此為「實作慣例決策,非已承諾的契約」——本 ADR 選擇加入,理由是 Godot 訊號機制是慣用的反應式更新原語,成本(一次 emit)可忽略,但**下游系統不得假設此訊號的存在會被其他 ADR 或未來重構保留**——若 UI 系統設計時發現不需要它,可以忽略不連接,不構成對本契約的違反。

### 機制八:持久化——格式無關的 Dictionary 轉接層

```
func export_state() -> Dictionary
# {
#   "records": Array[Dictionary],       # 每筆 AffinityRecord.to_dict()
#   "campaign_tick_marks": Array[int],
#   "death_marks": Dictionary[String, int],  # 鍵為 Character 的字串名稱
# }

func validate_semantics(data: Dictionary) -> ImportResult
# 純函式，不修改任何內部狀態——執行逐欄位值域檢查 + 5 條跨結構不變量檢查（見下方），
# 僅回傳驗證結果，不論成功或失敗皆不觸碰 _records/_death_marks/_campaign_tick_marks。
# （2026-08-18 回填修訂，見下方 ADR-0003 回填說明）

func import_state(data: Dictionary) -> ImportResult
# 內部先呼叫 validate_semantics(data)；驗證失敗直接回傳其結果，內部狀態不變。
# 驗證成功時才完全取代內部狀態並重建 _t_now 快取（原子性由呼叫方——存檔系統——的
# 更高層流程保證，本方法本身不做部分套用）。

class AffinityRecord:
    func to_dict() -> Dictionary       # {"pair": "C1_C2", "m": 2.0, "t": 10, "c": 3, "source": "combat_card"}
    static func from_dict(d: Dictionary) -> AffinityRecord
```

**回填修訂(2026-08-18,ADR-0003「存檔系統序列化格式與型別安全」新增要求)**:新增公開的 `validate_semantics()` 純函式,將原本內嵌於 `import_state()` 的驗證邏輯抽出、不再與「替換內部狀態」這個副作用綁死。**理由**:存檔系統的遷移執行模型(尚待撰寫的下一份 ADR)需要對遷移函數鏈的輸出做語意驗證(`save-system.md` Core Rules #7「語意驗證同樣套用於遷移函數的輸出」),但遷移鏈執行期間的中繼 `Dictionary` 不必然對應一個要被替換的 `AffinityDataPool` 活體實例——需要一個不觸發狀態替換副作用的純驗證呼叫,供存檔系統的 `SaveBlockRegistry`(ADR-0003 機制六)登記為本系統的驗證器。此修訂不改變任何既有資料結構、並發機制或已定案的錯誤分類,`import_state()` 對外行為(輸入/輸出/失敗語意)完全不變,純粹是內部重構為「先驗證、通過才替換狀態」的兩段式實作。**本 ADR 的 Proposed 狀態下修訂自身尚未實作的 Key Interfaces 屬正常的同波共同開發流程**,不同於修改已 Accepted 或已被下游程式碼消費的決策。

- `pair`/`source` 一律以**字串名稱**持久化,直接滿足 `TR-affinity-018`。**轉換方式(2026-08-18 `godot-specialist` 驗證發現修訂)**:正向轉換(enum → 字串)使用 `AffinityTypes.Pair.find_key(pair_value)`(GDScript enum 在執行期以類 `Dictionary` 物件呈現,`find_key()` 做的是**依值查鍵**,不受成員排列順序或未來是否出現非連續數值影響);反向轉換(字串 → enum)使用 `AffinityTypes.Pair[name_string]` 並以 `AffinityTypes.Pair.values().has(...)` 風格的檢查guard 非法字串輸入。**不採用**原草稿描述的「依 `keys()[pair]` 位置索引」寫法——那是位置查找,一旦列舉成員未來被指派非連續或重新排列的底層數值就會靜默出錯,`find_key()`/`enum[name]` 的依值/依鍵查找沒有這個風險。**「退役名稱永久保留、不得重新指派」的治理規則與 CI 檢查本身,依 GDD Dependencies 明文屬於存檔系統的職責**(「並由存檔系統維護『字串名稱↔目前 enum 定義』的對照表」)——本 ADR 只負責提供穩定的字串轉換原語(`to_dict`/`from_dict`),不建立獨立的退役名稱登記機制,避免與存檔系統的既有機制重複實作。**已考慮並拒絕的內建替代方案**:Godot 提供 `inst_to_dict()`/`dict_to_inst()` 可自動將 `Object` 衍生實例的屬性轉為/還原自 `Dictionary`,但它會把 enum 欄位序列化成原始 `int`(而非 `TR-affinity-018` 要求的字串名稱),且還原時內嵌腳本路徑依賴——與本 ADR 刻意追求的「格式無關、enum 以字串名稱持久化」需求不符,故不採用,改以手寫 `to_dict()/from_dict()` 逐欄位轉換。
- **反序列化語意驗證規則,本系統為唯一權威**(`TR-affinity-019`,直接對應 GDD「反序列化語意驗證規則宣告」章節):`import_state()` 內部依序執行——
  1. **逐欄位型別 + 值域**(2026-08-20 實機驗證後擴充)——**必須先以 `typeof()` 內省確認型別,通過後才允許賦值或做任何值域運算。順序不可顛倒,檢查手段不可代換**:
     - **型別**(以 `typeof(raw)` 比對 `Variant.Type` 常數,**不可用賦值當檢查**):`pair`/`source` 為 `TYPE_STRING`;`m` 為 `TYPE_FLOAT`;**`t`/`c` 必須嚴格為 `TYPE_INT`——不可寬鬆到「`int` 或 `float` 皆可」**;`records` 為 `TYPE_ARRAY` 且每個元素為 `TYPE_DICTIONARY`、恰含這 5 個鍵;`campaign_tick_marks` 為 `TYPE_ARRAY` 且每個元素為 `TYPE_INT`;`death_marks` 為 `TYPE_DICTIONARY` 且鍵為 `TYPE_STRING`、值為 `TYPE_INT`。
     - **值域**(僅在型別檢查通過後執行):`pair`/`source` 為合法列舉名稱;`m` 非零且有限;`t ≥ 1`;`c ≥ 0`;陣亡標記表值 `≥ 0`。
  2. 跨結構不變量 1—5(Delta Log 非空則標記列表非空;`c_i ≤ c_now`;全域 `t_i` 不重複且嚴格遞增;`n(p)=0` 哨兵不與非零筆數混淆;陣亡標記值不大於還原後 `t_now`)

  **為何型別與值域必須分成兩件事、且型別檢查只能用 `typeof()`**(2026-08-20 實機驗證,`XCHECK-4`):初版只寫「值域」,那在 ADR-0003 選定**二進位 Variant 序列化**(`bytes_to_var(bytes, false)`)之後不再足夠——該格式只擋自訂 `Object`,**任意內建型別都可被還原**,因此 `m` 可能還原成 `String`、`t` 可能還原成 `float`。實測結果:

  | 操作 | `Variant` 實際持有錯誤型別時 | 判定 |
  |---|---|---|
  | `is_finite(v)` / `is_nan(v)` / `is_inf(v)`,`v` 為 `String` | **SCRIPT ERROR + 所在函式中止**(`Invalid type in utility function … Cannot convert argument 1 from String to float.`) | 不可先做 |
  | `v == 0.0` / `v >= 1`(比較運算子),`v` 為 `String` | **同樣中止**(`Invalid operands 'String' and 'float'/'int' in operator`)。⚠️ **「比較運算子比較安全」是錯的假設,已被實測推翻**——沒有任何操作會對 `String` 誤配靜默回傳 `false` | 不可先做 |
  | `var t: int = raw`,`raw` 為 `float 1.5` | **不中止、不報錯、靜默截斷為 `1`** | ⚠️ **唯一一種「不出錯但也不安全」的情況** |

  **第三列是本次修訂最關鍵的一項發現**,它同時否定了兩種看似可行的寫法:(i) 不能用「賦值進型別化變數、指望賦值失敗當型別檢查」——賦值對 `String` 會中止、對 `float` 則靜默截斷,兩種都不是可判斷的檢查;(ii) `t`/`c` 的型別檢查不能寬鬆到「`int` 或 `float` 都算過」,否則存檔裡一個 `1.5` 會被靜默變成 `1`,而 `t` 是 Delta Log 的全域排序鍵——截斷會直接違反跨結構不變量 3(`t_i` 不重複且嚴格遞增),且違反的方式是**已經寫進內部狀態之後**才顯現。

  **中止的傳染範圍**:實測只影響直接執行該操作的函式,不往上層傳染。因此把每一項檢查放在 `validate_semantics()` 內是安全的——但那正是為什麼**不能靠中止當防線**:中止是無回傳值的失敗,而本方法的契約是回傳結構化 `ImportResult`。**先 `typeof()`** 讓每一種損壞都落在 `ImportResult` 裡,而不是變成一次未分類的執行期中止。

  **與 ADR-0003 的分工**:ADR-0003 的格式選擇讓「自訂 `Object` 結構上不可能被產生」——那擋掉的是**類別**注入;本項擋的是**內建型別錯配**與**靜默截斷**。兩者互補,不重疊。`TR-affinity-019` 明訂本系統是反序列化語意驗證規則的唯一權威,故此規則歸本 ADR,不歸 ADR-0003。

  **重建 `_records` 時一律經型別化邊界**:`from_dict()` 產出 `AffinityRecord` 後,以 `_records[pair].items.append(record)` 寫入,其中 `pair` 必須是由字串名稱經 `AffinityTypes.Pair[name]` 轉換並驗證過的列舉值——**不得**把還原自存檔的原始 `Variant` 直接當作 subscript 鍵(見機制四之二的兩條邊界規則與 registry 的 `raw_variant_subscript_into_typed_container`)。**存檔還原是唯一一條「外來資料進入 `_records`」的路徑,層三空隙在這裡的暴露面最大。**

  任一檢查失敗回傳結構化 `ImportResult`(標明失敗的具體規則),對應存檔系統 `SEMANTIC_VALIDATION_FAILED` 路徑的輸入。**本方法回傳的失敗結果與 `append_record()` 等寫入端拒絕規則是兩個不同層級的檢查**(GDD「範圍聲明」段落已明訂),不共用同一個錯誤碼列舉,避免呼叫端誤判兩種來源的驗證失敗為同一件事。
- **容器格式本身由存檔系統 ADR 決定**:`export_state()`/`import_state()` 只交換通用 `Dictionary`,不論存檔系統最終選 `Resource`/`.tres`、JSON 或自訂二進位,只需在其序列化層外包一次 `Dictionary ↔ 目標格式` 的轉換,不需要碰觸本系統內部。

### 機制九:全作用域封鎖成因登記處——維持文件層,提供窄範圍執行期查詢(部分升級)

`TR-affinity-023` 要求架構階段決定 GDD 中「全作用域封鎖成因登記處」(目前列出唯一一項:配對中任一成員陣亡 → 該配對的 `combat_card` 來源永久不可寫入)是否升級為執行期可查詢的 API。**本 ADR 的決定:不建立涵蓋全作品範圍、跨系統的通用查詢 API,但提供一個窄範圍、僅涵蓋本系統自身已知封鎖成因的執行期判斷式**:

```
func can_write(pair: AffinityTypes.Pair, source: AffinityTypes.Source) -> bool
# 回傳 append_record(pair, <任意合法 m>, source) 若立即呼叫是否會通過驗證
# （不含 SERIALIZATION_WINDOW_ACTIVE——那是暫時性狀態，非本判斷式的目的）
```

**理由**:GDD 該登記處本身明文承認「目前僅通過文字適配檢驗,尚無第二個真實實例」——在只有一個已知封鎖成因、且該成因已是本系統 `append_record()` 內部驗證邏輯自然涵蓋的情況下,建立一個涵蓋「全作品範圍、跨未來系統」的通用註冊表/查詢 API 是對假設性未來需求的過度工程化(YAGNI)。`can_write()` 提供的是「呼叫方(例如 UI 想預先判斷某個動作是否會被拒絕、或未來的敘事解鎖系統想確認某來源是否已被結構性封死)不需要真的嘗試寫入就能查詢」的窄範圍能力,對現有唯一已知成因(陣亡)已經足夠。**若未來真的出現第二個獨立成因**(例如角色離隊、限定道具鎖定),應在該成因對應的系統設計時重新評估是否需要升級為跨系統的通用登記處查詢 API——本 ADR 不預先關閉這個路徑,只是不在只有一個實例時就建。

## Architecture Diagram

```
                    ┌───────────────────────────────────────────────┐
                    │           AffinityDataPool(DI 注入)            │
                    │                                                │
                    │  _records: Dictionary[AffinityTypes.Pair,       │
                    │             AffinityRecordList]                │
                    │             └─ items: Array[AffinityRecord]    │
                    │  _t_now: int  ← 執行期快取,載入時由總筆數重建   │
                    │  _campaign_tick_marks: Array[int]              │
                    │  _death_marks: Dictionary[AffinityTypes.Character, int]      │
                    │  _serialization_tokens: Dictionary[int, int]   │
                    │  _token_mutex: Mutex  ← 無條件保護              │
                    └───────┬───────────────────────────┬───────────┘
                            │ 寫入                        │ 讀取(純函數)
        ┌───────────────────┼───────────┐       ┌─────────┴─────────┐
        │                   │           │       │                   │
  ┌─────▼─────┐      ┌──────▼─────┐ ┌───▼───┐ ┌─▼──────────┐ ┌──────▼──────┐
  │技能卡牌系統│      │支援對話系統 │ │章節/戰│ │好感度—位置 │ │敘事解鎖與   │
  │(combat_    │      │(support_   │ │役結構 │ │連鎖系統     │ │結局分支系統 │
  │ card)      │      │ conversation)│ │(story_│ │(combat_    │ │(narrative_  │
  │            │      │            │ │event, │ │ strength,   │ │ depth,      │
  │            │      │            │ │ tick) │ │ 記憶化快取A)│ │ shape_      │
  └────────────┘      └────────────┘ └───┬───┘ └────────────┘ │ feature)    │
                                          │                     └─────────────┘
                            ┌─────────────▼──────────────┐
                            │ 戰棋移動與交戰系統            │
                            │（陣亡通知,反向依賴;         │
                            │  同結算步呼叫順序自行定案）   │
                            └─────────────────────────────┘

  持久化路徑：
    存檔系統
      → begin_non_atomic_window()          ← 取得權杖,Mutex 保護
      → export_state() / import_state()    ← 格式無關 Dictionary
      → end_non_atomic_window(token)        ← RELEASED / TIMED_OUT_RECLAIMED / INVALID_TOKEN
    非原子視窗期間，_serialization_tokens 非空 ⇒ 所有寫入方法拒絕（SERIALIZATION_WINDOW_ACTIVE）
```

## Key Interfaces

以下為本 ADR 定案的契約形狀。**具體命名與型別簽章可在實作時微調,但語意不得改變**;任何改變語意的調整須回頭修訂本 ADR。

> **閱讀提醒**:以下為概念契約,不是可直接貼上的單一檔案。Godot 每個 `.gd` 檔只能有一個 `class_name`,實作時各類別應落在各自檔案(如 `affinity_record.gd`、`affinity_record_list.gd`、`affinity_data_pool.gd`、`affinity_read_result.gd`)。

```gdscript
# ─── affinity_record.gd ──────────────────────────────────────
class_name AffinityRecord extends RefCounted
var pair: AffinityTypes.Pair
var m: float
var t: int
var c: int
var source: AffinityTypes.Source
func to_dict() -> Dictionary: ...
static func from_dict(d: Dictionary) -> AffinityRecord: ...

# ─── affinity_record_list.gd ─────────────────────────────────
# 繞過 GDScript 不支援巢狀型別容器的包裝層,見機制二 2026-08-20 BLOCKING 修訂
class_name AffinityRecordList extends RefCounted
var items: Array[AffinityRecord] = []

# ─── affinity_data_pool.gd ───────────────────────────────────
class_name AffinityDataPool extends RefCounted

signal entry_appended(pair: AffinityTypes.Pair, record: AffinityRecord)

func append_record(pair: AffinityTypes.Pair, m: float, source: AffinityTypes.Source) -> WriteRejection
func advance_campaign_tick() -> AdvanceRejection
func notify_death(character: AffinityTypes.Character) -> DeathNotifyResult

func combat_strength_read(pair: AffinityTypes.Pair, t_query: Variant = null) -> AffinityReadResult
func narrative_depth_read(pair: AffinityTypes.Pair, t_query: Variant = null) -> AffinityReadResult
func shape_feature_read(pair: AffinityTypes.Pair, t_query: Variant = null) -> ShapeFeatureResult
func speculative_read(pair: AffinityTypes.Pair, hypothetical_entries: Array[HypotheticalEntry], mode: ReadMode) -> Variant

func can_write(pair: AffinityTypes.Pair, source: AffinityTypes.Source) -> bool

func begin_non_atomic_window() -> int
func end_non_atomic_window(token: int) -> EndTokenResult

func export_state() -> Dictionary
func validate_semantics(data: Dictionary) -> ImportResult   # 純函式,見機制八回填修訂(ADR-0003)
func import_state(data: Dictionary) -> ImportResult          # 內部呼叫 validate_semantics()
```

**記憶化契約的兩種快取形狀**(`TR-affinity-020`,呼叫方義務,本 ADR 只負責讓兩種形狀在介面上清楚可辨,不在本系統內部實作快取):

- **純站位評估快取**:鍵 `(pair)` → 快取 `combat_strength_read(pair)` 在當下 `t_now` 的回傳值,呼叫方(好感度—位置連鎖系統)於每回合開始時清空。
- **假設性/預判評估快取**:鍵 `(pair, mode)` → 快取「不含任何假設性項目時的基準讀值」(即 `t_last` 基準,概念上等同 `combat_strength_read(pair)`/`narrative_depth_read(pair)` 本身),`speculative_read()` 呼叫時只需疊加新增假設性項目的貢獻,不必每次重算整份記錄。

兩者**不得混用同一份快取**(GDD 明文要求):純站位評估的快取鍵不含 `mode`,因為它就是 `combat_strength_read` 本身;假設性評估的快取鍵含 `mode`,因為公式四同時支援 `COMBAT`/`NARRATIVE` 兩種加權模式,基準值不同。

## Alternatives Considered

### Alternative 1:`Resource` 子類別

- **Description**:`AffinityRecord extends Resource`,Delta Log 為持有 `Array[Resource]` 的 `Resource` 子類別,直接用 `ResourceSaver.save()`/`ResourceLoader.load()` 存取。
- **Pros**:與 Godot 內建序列化管線直接整合,不需要額外的 `to_dict()`/`from_dict()` 轉接層,`.tres` 格式在編輯器內可直接檢視。
- **Cons**:`TR-save-001`(存檔系統序列化格式)仍是 Open Question——若存檔系統最終選擇 JSON 或自訂二進位格式(理由可能是跨平台雲端存檔相容性、雜湊鏈驗證的位元組控制需求,見 `TR-save-013`/`TR-save-014`),`Resource`-based 的 Delta Log 會與該選擇直接衝突,屆時需要回頭重寫本 ADR 的資料結構。且 `Resource` 帶有 Godot 引擎物件的額外開銷(`resource_path`、`resource_name` 等欄位),對純資料記錄而言是不必要的负担。
- **Rejection Reason**:違反本 ADR「不得反向依賴尚未撰寫的存檔系統 ADR」的明確定位——選 A(格式無關 typed class)讓本 ADR 現在就能宣告完整,選 B 讓本 ADR 的正確性懸空等待存檔系統的格式決策。

### Alternative 2:單一扁平 `Array[AffinityRecord]`

- **Description**:所有記錄存在單一陣列,查詢時逐筆過濾 `record.pair == p`。
- **Pros**:實作最簡單,無需維護 per-pair 索引結構的一致性。
- **Cons**:查詢複雜度為 `O(n_total)`(全域總筆數),直接違反 `TR-affinity-002` 明文鎖定的 `O(n_p+m)` 契約——GDD 明文此為「GDD 層級已定案的契約,非架構師可自由裁量」。
- **Rejection Reason**:不是效能取捨的問題,是直接牴觸 GDD 已鎖定條款,不構成合法的架構選項。

### Alternative 3:Autoload 單例

- **Description**:`AffinityDataPool` 註冊為 Autoload,任何腳本以 `AffinityDataPool.append_record(...)` 全域呼叫。
- **Pros**:實作最省事,不需要手動傳遞參照。
- **Cons**:違反 `.claude/docs/coding-standards.md` 明文的 DI-over-singleton 偏好;單元測試需要在每個測試案例前後手動重置全域狀態,無法簡單 `new` 一個乾淨實例隔離測試。
- **Rejection Reason**:與專案既有編碼標準直接衝突。

### Alternative 4:`RefCounted` 物件身分作為序列化權杖

- **Description**:`begin_non_atomic_window()` 回傳一個新建的空 `RefCounted` 實例,以物件參照本身作為權杖,存於 `Dictionary`(鍵為 Object)。
- **Pros**:GC 自動回收未持有的權杖,不需要手動逾時偵測作為唯一防線(雖然本 ADR 仍需要逾時偵測作為 GDD 要求的後備義務,GC 不能替代它——一個仍被某處變數持有但邏輯上「該視窗早已結束」的權杖不會被 GC 回收)。
- **Cons**:與 `TR-affinity-003` 明文警告的 GDScript 參照相等陷阱同一類風險——物件身分比對容易因「兩個變數指向同一底層物件」或「誤用弱參照」產生非預期行為;診斷輸出/記錄檔難以印出穩定可讀的 ID(只能印記憶體位址或 `get_instance_id()`)。
- **Rejection Reason**:單調遞增 int 完全避開這一類風險,且與本 ADR 已選擇的「值型別鍵」慣例(`Pair`/`Character` enum)一致,不引入第二套鍵慣例。

### Alternative 5:條件式 Mutex(僅背景執行緒序列化時才加)

- **Description**:`_serialization_tokens` 預設不加鎖,待存檔系統 ADR 決定採背景執行緒時才回頭補上 `Mutex`。
- **Pros**:更貼近 GDD 條文的字面條件句「若選擇背景執行緒才需要」,同步阻塞情境下省去(可忽略的)鎖開銷。
- **Cons**:讓本 ADR 的並發正確性論證依賴一個尚未存在的 ADR 的未來決定,且該決定改變時需要回頭修改已完成、已測試的程式碼與本 ADR 本身——這正是本專案已知最昂貴的失敗模式(跨檔案/跨 ADR 的傳播失敗)的一個新發生面。
- **Rejection Reason**:無條件加 Mutex 的成本可忽略(集合規模小),換取的是本 ADR 現在即可完整、不留下未來必然要處理的技術債。

### Alternative 6:Array 組合鍵(不預先枚舉 10 對配對)

- **Description**:不定義 `enum Pair`,改用執行期正規化的 `Array[AffinityTypes.Character]`(排序後的二元素陣列)作為 `Dictionary` 鍵。
- **Pros**:省去手動維護 10 個 enum 成員的組合列表。
- **Cons**:GDScript `Array` 作為 `Dictionary` 鍵雖技術上可行(依內容雜湊/比對,不同於 `Object` 參照鍵),但**可變物件作為鍵值本身是已知風險模式**——若該 `Array` 實例在被用作鍵之後又被其他程式碼路徑意外修改(例如誤用同一個陣列變數),會破壞雜湊桶一致性。這與 `TR-affinity-003` 明文示警的參照/可變性陷阱精神相通,不建議在本專案已知唯一一類陷阱旁邊,再引入同類風險的第二種形式。
- **Rejection Reason**:`enum Pair` + `Pair.of()` 正規化建構函式同時消除了組合列舉的手動維護負擔(建構函式內部查表,呼叫端不需要知道 10 個成員叫什麼)與可變鍵風險,是嚴格更安全的選項,額外成本只是一次性寫死 10 個 enum 成員與一張查表。

### Alternative 7:`Dictionary[AffinityTypes.Pair, Array]`(值槽不帶元素型別)

- **Description**:值槽宣告為裸 `Array`,靠寫入紀律保證裡面裝的是 `Array[AffinityRecord]`。與機制二採用的 `AffinityRecordList` 一樣可繞過巢狀型別容器的語言限制,但不需要新增類別。
- **Pros**:不需要新增一個全域 `class_name`,不需要 `.items` 這一層間接。
- **Cons(2026-08-20 實測修正)**:代價**不是**「內層完全無型別」——實測把 `Array[AffinityRecord]` 存進裸 `Array` 值槽後讀回,`is_typed()` 仍為 `true`(`x7_typed_inner_in_bare_slot.gd`)。真正的代價是**不強制**:該值槽同時接受型別化與未型別化的 `Array`(對照組:未型別化字面量 `is_typed = false`),編譯期與執行期都沒有任何一層會阻止未型別化的 `Array` 被放進去。
- **Rejection Reason**:「不強制」只能用 setter 或撰寫紀律收斂,而本 ADR 系列反覆主張的立場是**結構保證優於紀律要求**(見 ADR-0003 對反序列化型別白名單的處理——它選了一個「結構上不可能產生自訂 `Object`」的格式,而非維護一份 app 層白名單)。另外覆核者自陳此選項還有一項**未測**:未型別化的 `Array` 存進去後,能否再被當成 `Array[AffinityRecord]` 讀出使用——若採此方案就必須先補這項驗證,選包裝類別則不需要。

> **原巢狀宣告 `Dictionary[Pair, Array[AffinityRecord]]` 不列為 Alternative**——它不是被權衡後拒絕的方案,是**被引擎否決的原決策**。該事實記在 Status 的修訂註記與機制二內。

## Consequences

### Positive

- **24 項 `TR-affinity-*` 的具體型別與介面已定案**,`/create-architecture`/`/create-stories` 不需要再等待或重新推導本系統的資料結構。**涵蓋分佈本身不由本 ADR 自陳**——第五輪 `/architecture-review` 獨立推導的結果與後續輪次為權威來源。
- **核心資料結構已在真機編譯驗證過**(2026-08-20):這是本專案第一份經實機驗證的 ADR。驗證直接擊落了原本的核心宣告——若照原計畫把本 ADR 推上 `Accepted` 再往下走 story,那一行會在實作第一天就爆,而那時它已是「已核准的架構決策」。
- **與存檔系統 ADR 完全解耦**:`export_state()`/`import_state()` 的通用 `Dictionary` 契約讓存檔格式決策(`TR-save-001`)可以在本 ADR 之後任意時間點做出,不需要回頭修改本 ADR 或已寫好的程式碼。
- **執行緒安全義務一次性、無條件滿足**:不論存檔系統未來選擇同步或背景執行緒,`_serialization_tokens` 的並發正確性已經成立,不會有「存檔系統 ADR 選了背景執行緒才發現這裡忘了加鎖」的風險。
- **可單元測試性**:DI 擁有模式 + 無場景樹依賴,讓 7 類拒絕情境、5 條跨結構不變量等大量邊界案例可以用乾淨、隔離、不需引擎執行環境的單元測試逐一覆蓋,直接對應 GDD Acceptance Criteria 章節的密集驗收條件。
- **與 ADR-0001 的機制保持風格一致但不誤用**:序列化生命週期的拒絕式閘門精神與 `settlement_in_progress` 相同,但本 ADR 正確辨識出兩者本質不同(單一結算步 vs. 多重疊視窗),沒有錯誤地複用單一布林旗標。

### Negative

- **多一份必須維護的文件與交叉指標**:GDD 現有多處指標指向未來的本 ADR;本 ADR 也回指 GDD 各章節。任一方修訂時須檢查另一方——本專案已知最容易產生傳播失敗的動作。
- **無條件 Mutex 是一個保守選擇,可能是不必要的成本**(雖然可忽略):若存檔系統最終確定選擇同步阻塞式寫入(`TR-save-005` 原本的 `provisional` 傾向),這個 Mutex 保護實際上永遠不會有並發競爭場景,只是純粹的鎖開銷。
- **多一層 `.items` 間接與一個額外的全域 `class_name`**(2026-08-20 新增):`AffinityRecordList` 純粹是為了繞過 GDScript 不支援巢狀型別容器而存在的包裝層,本身沒有任何行為;每一處存取 `_records` 的程式碼都要多寫 `.items`。這是**語言限制的直接成本,不是設計偏好**——已實測確認本次涵蓋的候選中無其他能同時保住兩層型別的寫法。
- **型別錯誤是本 ADR 拒絕碼機制唯一涵蓋不到的失敗類別**(2026-08-20 新增):見機制四之三。7 類 `WriteRejection` 涵蓋值域與狀態的非法,不涵蓋型別的非法;型別非法的失敗形式是呼叫端函式中止,不是回傳碼。這把一部分驗證責任明文推給上游呼叫方。
- **`can_write()` 的窄範圍決定隱含一個未來風險**:若第二個封鎖成因出現卻沒有被正確辨識為需要升級全作用域登記處,`can_write()` 只涵蓋本系統自知的邏輯,不會自動涵蓋未來其他系統引入的封鎖成因。

### Risks

| 風險 | 緩解 |
|---|---|
| **存檔系統 ADR 最終選擇的並發模型比背景執行緒更複雜**(例如多執行緒池而非單一背景執行緒),使單一 `Mutex` 不足以保護所有存取路徑 | 本 ADR 的 Mutex 保護範圍明確界定為 `_serialization_tokens`/`_reclaimed_tokens` 本身;若存檔系統 ADR 引入更複雜的並發模型觸及 `_records`/`_death_marks`/`_campaign_tick_marks` 本身的並發存取(目前 GDD 未預期此情境——這些結構的寫入方皆為遊戲邏輯執行緒),須回頭重新評估本 ADR |
| **`_records`/`_death_marks`/`_campaign_tick_marks` 本身未加鎖**:本 ADR 假設寫入(`append_record` 等)只發生在主執行緒/遊戲邏輯執行緒,唯有序列化的**讀取**(`export_state()`)可能發生在背景執行緒——若這個假設不成立(例如未來某系統嘗試在背景執行緒呼叫 `append_record`),會產生資料競爭 | 本 ADR 的隱含前提已於此處明文記載:唯一可能的背景執行緒存取路徑是存檔系統的**唯讀**匯出,且該路徑受 `_token_mutex` 保護的「非原子視窗期間拒絕寫入」規則保護(視窗開啟時所有寫入方法皆拒絕)——只要存檔系統遵守「匯出前必先 `begin_non_atomic_window()`」的契約,`export_state()` 執行期間不會有並行寫入,不需要對 `_records` 本身額外加鎖。若未來出現本 ADR 未預期的背景寫入路徑,須回頭重新評估 |
| **`TOKEN_TIMEOUT_MS` 未定案**,若設得過短,會誤將仍在合法進行中的慢速操作(例如大型遷移的最後一步)判定為逾時回收,造成 `end_non_atomic_window` 回傳非預期的 `TIMED_OUT_RECLAIMED` 而非 `RELEASED` | **2026-08-19 修訂(C1 銜接缺口關閉)**:此值的**定值責任已由 ADR-0004 明文接下**(見該 ADR 機制六「C1 銜接缺口」段落),不再是本表原本模糊的「留待存檔系統 ADR 或實測校準」——該模糊措辭與 ADR-0004 上一版的「非本系統補償」互相推諉,使本值連續三輪 `/architecture-review` 被判為**孤兒義務**。定值依據是遷移鏈深度上界 × 幀預算 + 兩階段回寫最壞 I/O 時間 × 安全係數,**只有 ADR-0004 掌握這些量**。本系統仍擁有逾時**機制**的執行(機制七的逐權杖惰性清除),但不擁有那個數字。`TIMED_OUT_RECLAIMED` 本身被設計為非故障結果,呼叫方可自行決定如何處理,不會導致資料損毀 |
| **`AffinityTypes.Pair` 的 10 個成員在角色系統定案實際命名前只是佔位符**,若角色系統設計時發現主角規模政策變動(理論上已由 `game-concept.md` 主角群規模裁決鎖定 5 人,但仍是一個交叉文件的相依) | 若角色數量變動,`Pair`/`Character` enum 需要重新生成(10 對 → 其他組合數),`AffinityTypes.pair_of()` 的查表邏輯集中在單一函式,重新生成的影響範圍侷限,不擴散到呼叫端邏輯 |
| **export release 建置下 C++ 容器驗證(層二)可能被編譯掉**,使錯誤型別的值寫入 `_records` 時既不中止也不被丟棄。⚠️ 最壞影響不是崩潰,是**靜默存檔損壞且出貨版本專屬**:壞值經 ADR-0003 的 `var_to_bytes()` 序列化並通過兩層 SHA-256 雜湊鏈(雜湊驗位元組完整性、不驗語意),形成「debug 測得出、release 測不出」的不一致 | 三重,且三者對應**不同**的進入路徑:(i) **機制四之二的規則二(值邊界)**——值一律經靜態型別建構賦值、從不經 `Variant` 中介,層一在賦值處即受檢(編譯期,建置無關),層二因此只是同一件事的第二道確認;**規則一(鍵邊界)關的是層三,與本列無關**——本次修訂的初稿曾把兩者混為一談,已由 Step 5.5 覆核抓出並改正;(ii) **`validate_semantics()` 的逐欄位檢查已擴充為「型別 + 值域」**(機制八)——這是唯一涵蓋 `import_state()` 那條外來資料路徑的防線,app 層、與建置組態無關;(iii) Verification Required #7 記錄了建置無關的探針設計與 CI 回歸測試建議 |
| **型別錯誤是本 ADR 拒絕碼機制唯一涵蓋不到的失敗類別**:型別化參數的阻擋方式是整段**呼叫端**函式中止(2026-08-20 實測),不是可判斷的回傳值。上游若持有來源不明的 `Variant` 並直接傳入,失敗會表現為呼叫端函式靜默中止(在 release 建置下甚至可能連錯誤都不列印,見 Verification Required #7),而非一個 `WriteRejection` | 明文列為**呼叫端義務**(機制四之三):上游必須在呼叫前自行以 `typeof()` 收斂型別。本系統 7 類拒絕碼的範圍界線同時明文化為「值域與狀態的非法,不含型別的非法」。**本 ADR 刻意不新增 `INVALID_TYPE` 拒絕碼**——那會是一個結構上不可能被回傳的死碼,反而誤導呼叫方以為型別錯誤會被本系統攔下並回報 |
| **全域 `class_name` 命名碰撞**(2026-08-18 `godot-specialist` 驗證發現,低風險前瞻性提醒):`class_name` 註冊是專案級扁平命名空間,`AffinityRecord`/`AffinityRecordList`/`HypotheticalEntry`/`AffinityReadResult`/`ShapeFeatureResult`/`AffinityDataPool`/`AffinityTypes` **七**個全域類別名稱(2026-08-20 由六增為七,新增 `AffinityRecordList`)未來可能與其他系統或第三方 addon 的類別名稱碰撞 | 七個名稱中六個皆帶 `Affinity` 字首(`AffinityTypes` 包裝三個共用 enum,避免了原草稿 `Pair`/`Character`/`Source` 這類過於通用、碰撞風險較高的裸命名),目前 `src/` 為空、無碰撞對象;此為一次性命名慣例,無需額外機制 |

## GDD Requirements Addressed

| TR-ID | 需求 | How This ADR Addresses It |
|---|---|---|
| TR-affinity-001 | Delta Log 5 欄型別化記錄,非 `Array[Dictionary]` | `AffinityRecord`(`RefCounted`,5 個型別化欄位:`pair: Pair`、`m: float`、`t: int`、`c: int`、`source: Source`) |
| TR-affinity-002 | per-pair 索引,`O(n_p+m)` | `Dictionary[AffinityTypes.Pair, AffinityRecordList]`(內層 `items: Array[AffinityRecord]`;2026-08-20 修訂,原巢狀寫法在 4.7.1 無法編譯);`c_now(t_query)` 對 `_campaign_tick_marks` 線性計數,`O(m)` |
| TR-affinity-003 | Dictionary 鍵須為值型別,不可為 Object 參照 | `Pair`/`Character` enum(int 底層)作為 `_records`/`_death_marks` 的鍵;序列化權杖為單調遞增 int,非物件身分(見 Alternative 4 的拒絕理由) |
| TR-affinity-004 | 兩個獨立全域單調計數器,皆為衍生值,不得另存 | `_t_now`(執行期快取,載入時由記錄總筆數重建,不獨立持久化);戰役刻度計數器本身由 `_campaign_tick_marks.size()` 衍生 |
| TR-affinity-005 | 獨立戰役刻度標記列表,`c_now` 不得由 Delta Log 的 `c_i` 推導 | `_campaign_tick_marks: Array[int]`,`advance_campaign_tick()` 附加而非由 `_records` 反推 |
| TR-affinity-006 | 獨立陣亡標記表,讀寫 O(1) | `_death_marks: Dictionary[AffinityTypes.Character, int]`,獨立於 `_records`;`t_death()` 至多 2 次鍵查找 |
| TR-affinity-007 | 陣亡通知介面:單一方法、陣營閘控、反向依賴不轉接 | `notify_death(character: AffinityTypes.Character) -> DeathNotifyResult`,由戰棋移動與交戰系統直接呼叫,不經好感度—位置連鎖系統轉接(機制三) |
| TR-affinity-008 | 同結算步呼叫順序決定寫入合法性 | `notify_death`/`append_record` 皆為單純同步方法,不排隊不緩衝,呼叫方實際呼叫順序即決定結果(機制三);順序本身由呼叫方(戰棋移動與交戰系統)定案,本 ADR 不預設 |
| TR-affinity-009 | 前進戰役刻度為獨立介面,單一呼叫方 | `advance_campaign_tick()`,由章節/戰役結構系統呼叫 |
| TR-affinity-010 | 附加記錄介面恰 3 呼叫點;公開方法中僅 2 個會改變 Delta Log/戰役刻度狀態 | `append_record`/`advance_campaign_tick` 是唯二改變 Delta Log/戰役刻度標記列表狀態的方法;`notify_death`/`begin_non_atomic_window`/`end_non_atomic_window` 改變的是結構獨立的其他狀態,不在 AC-1 定義範圍內(機制四說明) |
| TR-affinity-011 | 寫入驗證 fail-loud,涵蓋明文拒絕情境 | `WriteRejection`/`AdvanceRejection`/`DeathNotifyResult`/`EndTokenResult` 列舉窮盡列出所有拒絕分類,`append_record()` 驗證順序明訂(機制四) |
| TR-affinity-012 | 三讀取函數+公式四為純函數,`0^0:=1` 慣例 | 讀取方法不修改任何內部狀態;`0^0:=1` 列為 Verification Required 項目(GDScript `pow()` 實際行為未經本專案驗證,不可假設) |
| TR-affinity-013 | 回傳簽章攜帶 `t_query`/`n(p)`,QA 診斷輸出獨立 | `AffinityReadResult`/`ShapeFeatureResult` 的 `t_query`/`n_pair`/`c_now` 為正式欄位;`diagnostic_visited_count` 明文標記 QA-only(機制六) |
| TR-affinity-014 | 序列化生命週期為權杖式,支援並行重疊視窗 | `begin_non_atomic_window()`/`end_non_atomic_window()`,`_serialization_tokens: Dictionary[int, int]` 支援任意數量同時存在的權杖 |
| TR-affinity-015 | 逐權杖逾時偵測,非整批清空,ID 永不重新發放 | `_next_token_id` 只增不減;惰性逾時清除依 `issue_time` 逐一判斷,移入 `_reclaimed_tokens` 而非清空整個集合(機制七) |
| TR-affinity-016 | 若背景執行緒序列化,權杖集合須執行緒安全 | `_token_mutex` 無條件保護 `_serialization_tokens`/`_reclaimed_tokens`,不等待存檔系統執行模型 ADR(機制七、Alternative 5)。**2026-08-19 修訂(C3)**:該條件式需求的條件此後已由 ADR-0004 判為「否」(同步阻塞式 `SaveIOBackend` + 主執行緒斷言),`Mutex` 因此由「必要」降為**縱深防禦**——決策不變、措辭修正,見機制七的 C3 段落 |
| TR-affinity-017 | 存檔須無損往返 3 份結構 | `export_state()`/`import_state()` 涵蓋 `records`/`campaign_tick_marks`/`death_marks` 三者(機制八) |
| TR-affinity-018 | `Pair`/`source_i` 以字串名稱持久化,退役名稱永久保留 | `to_dict()`/`from_dict()` 以字串名稱轉換;退役名稱治理規則明訂為存檔系統職責(依 GDD Dependencies 原文),本系統只提供轉換原語(機制八) |
| TR-affinity-019 | 本系統為反序列化語意驗證規則唯一權威 | `validate_semantics()` 純函式實作逐欄位值域 + 5 條跨結構不變量檢查,回傳結構化 `ImportResult`(機制八);`import_state()` 內部呼叫此函式,通過才替換內部狀態(2026-08-18 回填修訂,見 ADR-0003) |
| TR-affinity-020 | 記憶化為硬性介面契約,兩種模式不得混用 | Key Interfaces 章節明文兩種快取鍵形狀(純站位 `(pair)` vs 假設性 `(pair, mode)`),供呼叫方遵循 |
| TR-affinity-021 | 讀取進入點依函數性質分流的條件式預設查詢時點 | `combat_strength_read`/`narrative_depth_read` 預設 `t_death(pair)`(若已定義)否則 `t_now`;`shape_feature_read` 恆預設 `t_now`(機制五) |
| TR-affinity-022 | 公式四假設性記錄嚴格遞增虛擬 `t_new`,唯一合法豁免 | `speculative_read()` 依陣列順序指派遞增 `t_new`,`t_query` 內部固定為最後一筆(機制五) |
| TR-affinity-023 | 全作用域封鎖成因登記處是否升級為執行期 API | 維持文件層為主,提供窄範圍 `can_write()` 判斷式涵蓋本系統已知唯一成因(陣亡),不建立跨系統通用登記處(機制九,YAGNI 理由) |
| TR-affinity-024 | `entry_appended` 信號為實作慣例,非承諾契約 | 加入該訊號作為實作選擇,明文下游不得假設其被保留(機制七) |

## Performance Implications

- **CPU**:`append_record`/`notify_death`/`advance_campaign_tick` 皆為 O(1)(至多常數次 Dictionary 鍵查找 + Array append);三個讀取函數與公式四為 `O(n_p)`(或 `O(n_p+m)`,若涉及 `time_distribution`/`segment_profile`),滿足 GDD 鎖定的效能契約。`Mutex.lock()/unlock()` 的開銷在權杖集合規模(同時發起者數,預期個位數)下可忽略。
- **Memory**:`_records` 的記憶體與 Delta Log 總筆數成正比,不隨遊戲進程以外的因素膨脹;`_death_marks` 上界為 5 筆;`_campaign_tick_marks` 上界與戰鬥/章節數成正比(遠小於好感度事件數)。
- **Load Time**:`import_state()` 需要 `O(n_total)` 重建 `_t_now` 快取與執行跨結構不變量檢查,發生於存檔讀取時,非每幀路徑,不構成影格預算風險。
- **Network**:不適用(單人遊戲)。

**明確未定案**:`_records` 的實際規模上界(取決於好感度對話卡牌觸發頻率、支援對話/劇情事件節奏,皆為其他系統未定案的旋鈕,見 GDD Tuning Knobs);`TOKEN_TIMEOUT_MS` 的具體數值——**但其定值責任與推導規則自 2026-08-19 起由 ADR-0004 擁有(C1),不再是無主項**。

## Migration Plan

不適用——本專案 `src/` 目前為空,尚無任何實作程式碼,處於設計階段。本 ADR 為前瞻性決策,不涉及既有程式碼遷移。

## Validation Criteria

1. **GDD Acceptance Criteria 章節的 A~D 分類(及後續分類)全數向量通過**——這是本 ADR 資料結構/介面是否真的支撐 GDD 義務的直接證據,尤其 AC-1(方法行為窮盡檢視)、AC-4(呼叫圖分析,待下游系統有程式碼後才可執行)、AC-55(O(n_pair) 診斷筆數斷言)。
2. **7 類 `WriteRejection`/相關拒絕情境的獨立單元測試**:逐一構造觸發每種拒絕碼的輸入,驗證回傳正確拒絕碼且內部狀態(`_t_now`、`_records`)未被改變。
3. **權杖生命週期測試**:(a) 同時開啟 N 個權杖,任意順序釋放,驗證 `SERIALIZATION_WINDOW_ACTIVE` 只在至少一個權杖存活時觸發;(b) 未知 token/重複釋放/空集合時呼叫 `end_non_atomic_window` 均回傳 `INVALID_TOKEN`;(c) 逾時後呼叫回傳 `TIMED_OUT_RECLAIMED` 而非 `INVALID_TOKEN`。
4. **`import_state()` 的 5 條跨結構不變量各自的失敗案例測試**:逐一構造違反單一不變量的輸入(其餘皆合法),驗證回傳對應失敗、不誤判為其他不變量的違反。
5. **`0^0 := 1` 慣例的顯式測試**(對應 Verification Required 第 3 項):`λ=0`、`age=0` 的邊界輸入,驗證 `combat_strength_read`/`narrative_depth_read` 回傳精確等於 `m_i`,不依賴 `pow()` 的引擎預設行為。
6. **`t_death(pair)` 凍結行為測試**:陣亡配對的 `combat_strength_read`/`narrative_depth_read` 省略 `t_query` 時,驗證回傳值不隨陣亡後 `_t_now` 繼續推進而改變(除非有合法的死後追憶寫入,此時仍應凍結於 `t_death(pair)`,不含追憶寫入的影響);`shape_feature_read` 則相反,驗證確實反映追憶寫入。
7. **公式四邊界測試**:零筆假設性項目呼叫回傳 `EMPTY_HYPOTHETICAL_SET`;陣亡配對呼叫回傳 `DEAD_PAIR_NOT_ALLOWED`;多筆假設性項目驗證 `t_new` 嚴格遞增且結果與「依序真實寫入後再讀取」完全一致(GDD 明文的等價性要求)。
8. **後續 `/architecture-review`** 判定本 ADR 與其他 ADR(尤其 ADR-0001 的拒絕式閘門模式、`settlement_in_progress` 先例)無衝突、且對 `affinity-data-pool.md` 24 項需求的涵蓋無缺口。

9. **兩條邊界規則各自的迴歸測試(兩項,不可合併)**(2026-08-20 新增):(a) **鍵邊界**——驗證「以 `Variant` 直接當 subscript 鍵寫入 `_records`/`_death_marks`」不存在於本系統任何程式碼路徑(靜態檢查/lint 層,非執行期),且所有公開寫入介面的鍵參數簽章皆為型別化 enum;(b) **值邊界**——驗證 `_records`/`_death_marks` 的每一處值槽賦值,其右手側的靜態型別皆為 `AffinityRecordList`/`AffinityRecord`/`int`,無任何一處是 `Variant`。**兩者必須是兩個獨立的測試**——(a) 通過不蘊含 (b) 通過,這正是本次修訂初稿把兩者混為一談時 Step 5.5 覆核抓到的錯誤。
10. **`validate_semantics()` 的型別錯配案例測試(三類,缺一不可)**(2026-08-20 新增):對每個欄位各構造 (a)「型別正確、值域非法」、(b)「型別錯誤為 `String`」、(c)「型別錯誤為數值近親」三種輸入,驗證**三者都回傳結構化 `ImportResult` 而非執行期中止或靜默通過**。(b) 對應已實測的中止路徑:`m` 為 `String` 時不得走到 `is_nan()`/`is_inf()`,`t` 為 `String` 時不得走到 `t >= 1` 的比較。**(c) 是最容易漏的一類,且它不會中止**:`t`/`c` 給 `float 1.5`,驗證回傳型別失敗而**不是**被靜默截斷為 `1` 後通過全部檢查——這一類沒有任何引擎層錯誤可依賴,是本 ADR 自己的檢查漏掉就完全沒有人擋的唯一一類。
11. **`AffinityRecordList` 包裝層的編譯驗證**(2026-08-20 新增):實作第一天即在真機編譯 `var _records: Dictionary[AffinityTypes.Pair, AffinityRecordList]` 的宣告,確認不再出現 `Nested typed collections are not supported`;並斷言 `_records[pair].items.is_typed() == true`(兩層型別皆保住)。**不可用 `get_class()` 做這項斷言**——它回傳原生類別,任何 `RefCounted` 子類都印 `RefCounted`;應用 `script.get_global_name()` 或 `is AffinityRecordList`。

**反向驗證(本 ADR 若錯了會如何顯現)**:若 per-pair 索引實作有誤(例如意外退化為全表掃描),會表現為 `diagnostic_visited_count` 隨全域總筆數增長而非配對自身筆數增長——`AC-55` 對應的自動化測試會直接攔截。若權杖逾時邏輯過於激進(逾時門檻太短),會表現為合法但較慢完成的存檔操作被誤判為 `TIMED_OUT_RECLAIMED`,雖非資料損毀但會產生誤導性診斷紀錄,應在校準 `TOKEN_TIMEOUT_MS` 時特別注意。

## Related Decisions

- `design/gdd/affinity-data-pool.md` — 本 ADR 服務的全部義務之權威定義處,本 ADR 只定案機制。
- `docs/architecture/adr-0001-tactical-query-atomicity-contract.md` — 拒絕式並發閘門(`settlement_in_progress`)的先例,本 ADR 的序列化生命週期機制借鑑其精神但因涉及多重疊視窗而採獨立的權杖式機制,非直接複用。
- `docs/registry/architecture.yaml` — 本 ADR 完成後將登記的新增立場(state ownership、api_decisions、forbidden_patterns 候選,見下方 Registry 更新提案)。
- `docs/architecture/architecture-review-2026-08-18.md` — 記錄本 ADR 為全專案最高優先 ADR 缺口的稽核結果。
- `docs/architecture/adr-0003-save-system-serialization-format-and-type-safety.md`(2026-08-18 新增)——消費本 ADR 的 `export_state()`/`import_state()` 契約作為好感度區塊的 payload 來源,並促成本 ADR 新增 `validate_semantics()`(見機制八回填修訂)。
- **待建**:存檔系統原子寫入與遷移執行模型 ADR(`TR-save-005` 及其下游)——可直接引用本 ADR 的 `export_state()`/`import_state()`/`validate_semantics()` 契約。
- `prototypes/engine-verification-spike-2026-08-20/` 與 `prototypes/xcheck-gdscript-specialist-2026-08-20/`(2026-08-20 新增)——本次修訂的**全部實測證據來源**。原始未過濾 log 已歸檔(`logs/run-final-2026-08-20-headless.txt`、`logs/xcheck{1,2,3,4}-unfiltered.txt`),檔頭自帶執行指令、exit code 與判讀陷阱,**下一輪覆核不需回讀對話**。⚠️ 兩份 README 皆自陳探針弱點與已被推翻的結論,引用前請讀「結論歸屬」一節。
- `docs/architecture/adr-0005-cursor-device-authority-input-architecture.md`(2026-08-20 新增交叉引用)——Verification Required #7(export release 建置)是兩份 ADR 共同的待驗證項,但**依賴方向不同**:本 ADR 只依賴層 A(容器驗證是否丟棄寫入)且已由機制四之二的規則二降為縱深防禦;ADR-0005 的 S-1 必要性論證依賴層 B(GDScript VM 是否中止所在函式),**尚未降級**。
