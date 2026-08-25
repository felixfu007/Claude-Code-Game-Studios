# ADR-0002: 好感度數值池資料結構與並發契約

## Status

**Accepted**

> **2026-08-19 修訂(銜接缺口 C1/C3,不改動任何機制決策)**:連續三輪 `/architecture-review` 判定為仍開的兩項跨 ADR 銜接缺口。**C1** —— `TOKEN_TIMEOUT_MS` 的**定值責任**已由 ADR-0004 明文接下(該 ADR 掌握遷移鏈深度上界與兩階段回寫最壞 I/O 時間,本 ADR 對兩者一無所知);本 ADR 仍擁有逾時**機制**的執行(機制七逐權杖惰性清除),但不擁有那個數字。**C3** —— `TR-affinity-016` 是條件式需求,其條件(「若選擇背景執行緒序列化」)已由 ADR-0004 判為「否」;`Mutex` 決策**不變**,但理由由「必要」改為**縱深防禦**,措辭不再宣稱它是「全專案唯一已成立的執行緒安全義務」。兩項皆為措辭與擁有權澄清,**未新增、未移除、未改變任何資料結構或介面契約**。

> **2026-08-20 修訂(BLOCKING —— 引擎行為實機驗證)**:2026-08-20 的引擎行為驗證 spike 與 `godot-gdscript-specialist` 的獨立交叉覆核,在 Godot 4.7.1 實機測出本 ADR 機制二的**核心宣告無法編譯**(`Nested typed collections are not supported`),已改採包裝類別 `AffinityRecordList`(**本次驗證涵蓋的四個候選中唯一同時保住兩層型別者**)。同時:型別安全論述由單層改寫為**三層圖像**,並新增**鍵邊界與值邊界兩條規則**(分別把已實證的 subscript 空隙關在系統邊界外、以及讓 release 建置下未查證的容器驗證行為降為縱深防禦);`validate_semantics()` 的逐欄位檢查擴充為**型別 + 值域**,且型別檢查明訂只能用 `typeof()` 內省;新增機制四之三,明文呼叫端的型別義務與「7 類拒絕碼不涵蓋型別非法」這條先前隱含的範圍界線。Verification Required **由五項擴為八項**——**六項關閉**(#1/#2/#3/#5/#6/#8)、**兩項仍開**(#4 `Mutex` 可重入、#7 export release 建置下的容器驗證行為)、**三項新增**(#6/#8 新增即關閉,#7 新增且仍未查證)、**一項改寫**(#4 原附註「本專案無 Godot 執行環境可實測」的前提**已被推翻**——執行檔存在,只是不在 `PATH` 上;未關閉的原因改為尚未撰寫探針)。**本次修訂改變了資料結構的具體型別,但未改變任何介面語意、並發機制或錯誤分類。**
>
> **寫入前已執行 Step 5.5 雙軌覆核**(`godot-gdscript-specialist` + `godot-specialist`),抓出並修畢本次修訂初稿**自己引入的 2 項缺陷**:(a) 曾用鍵邊界規則去支撐值層的降級,推導鏈不成立;(b) VR 計數低估為「一項新增」,會讓讀者漏掉 #7。這與 ADR-0005 第三/四/五輪「修法本身引入新缺陷」是同一模式,第六次。
>
> **本 ADR 不自陳修訂後的需求涵蓋分佈** —— 留給全新 session 的獨立 `/architecture-review`(第七輪)重新推導。歷次自陳皆被獨立覆核判為高估。

> **2026-08-21 第四次修訂(第七輪 `/architecture-review` 的 17 項)**:兩項 BLOCKING(R7E-6 `t_query: Variant` 是本 ADR 真正的 `Variant` 入口而範圍宣告漏稽核它、R7E-4 enum 型別化參數對數值近親靜默轉換)+ R7-P1/P2/P3 + R7E-2 的二選一裁決 + 其餘 11 項。**機制層面的實質變更**:讀取路徑的拒絕改由結果物件的 `rejection` 欄位承載(`SpeculativeRejection` 併入 `ReadRejection`,四個簽章全部不再回傳 `Variant`);`t_query` 新增 `typeof()` 型別閘門;`_records` 建構子預填 10 對(`_death_marks` 刻意不預填 —— 鍵存在即語意);`AffinityRecordList.items` 改私有 + 最小存取面;**8 個帶 enum 參數的入口統一序數驗證**(`ReadRejection` 新增 `INVALID_PAIR`、`DeathNotifyResult` 新增 `INVALID_CHARACTER`、`can_write()` 回傳型別 `bool` → `WriteRejection`);`_reclaimed_tokens` 的次要逾時**撤回時間門檻**,改為固定容量 FIFO(不再引用任何外部常數)。
>
> **寫入前已執行 Step 5.5 雙軌覆核兩輪**(`godot-gdscript-specialist` + `godot-specialist`)。第一輪回傳 11 項 BLOCKING/高 + 12 項非阻塞,**其中 8 項是本次修訂初稿自己引入或漏掉的**;協調者另自行 grep 核實出範圍宣告**連續被低估三次**(4 處 → 17 處 → 約 30 處)。**第二輪針對「覆核之後才產生的兩項機制變更」窄範圍重驗,又抓到 4 項**,包括 `can_write() -> WriteRejection` 有 **3 個**結構上不可達的值(兩軌獨立收斂)、以及 `pair_of()` 是第 8 個入口且**無拒絕通道**。「修法本身引入新缺陷」的模式**第八次**。
>
> **本 ADR 不自陳修訂後的需求涵蓋分佈** —— 留給全新 session 的獨立第八輪 `/architecture-review`。**優先查核點**:修正 A/H(Step 5.5 第一輪之後才產生)、`can_write()` 是本次唯一改變既有公開簽章回傳型別之處、`pair_of()` 的呼叫端義務不與其他 7 個入口同級。

> **2026-08-24 修訂(範圍:同檔強制規則)**:`AffinityReadResult`/`ShapeFeatureResult` 因跨檔裸引用 `AffinityDataPool` 巢狀 enum 在 Godot 4.7.1 是編譯期限制(探針 `prototypes/xcheck-adr0002-review-2026-08-24/`),兩者由獨立 `class_name` 改為 `AffinityDataPool` 同檔的並列 inner class。⚠️ **範圍聲明的限度**:本則的範圍依據是「哪些地方帶 2026-08-24 日期標記」這一個訊號,兩次獨立 `grep` 確認全文只有兩處帶此標記——但這只證明「沒有更多帶標記的痕跡」,**不證明那一波沒有做過不帶日期標記的其他修改**。本則不宣稱這是 2026-08-24 那一波變更的完整範圍,只記載可追溯到日期標記的部分。
>
> **2026-08-25 修訂(第八輪覆核前的收斂批次)**:補完 `ImportResult`、`AdvanceRejection`、`DeathNotifyResult` 三個先前只被當成回傳型別使用、本體從未宣告的型別;`AffinityRecordList.get_at()` 契約修訂為越界不中止、回傳 `null`(VR#11 關閉);VR#9(`match typeof(x)` 對 `TYPE_NIL` 分支)、VR#12(`int`/`float` 序列化型別往返保真)兩項由探針關閉;Risks 表全域 `class_name` 命名碰撞計數修正;機制八「與 ADR-0003 的分工」段落範圍收窄並修正引號位置;`ADR Dependencies` 的 `Ordering Note` 補上對 ADR-0003/ADR-0004 兩條邊的「不構成 `Depends On`」防線。**本 ADR 不自陳修訂後的需求涵蓋分佈**——留給獨立的第八輪 `/architecture-review` 重新推導,理由與前幾次修訂相同。

> **2026-08-25 核准(`Proposed` → `Accepted`)**:由本專案管理者裁決核准,依據為 `docs/architecture/adr-acceptance-criteria.md` 的五個必要條件。**五條逐項成立**——**條件一**(所依賴的引擎行為每一項都在真的引擎上跑過):由 `prototypes/` 各探針關閉,VR#9(`match typeof()` 對 `TYPE_NIL`)、VR#11(`get_at()` 越界)、VR#12(`int`/`float` 序列化型別往返保真)為 2026-08-25 關閉的最後三項;**條件二**(沒有任何一句話被測試結果否證):被實測否證的敘述已全數修畢,含機制二核心宣告改採 `AffinityRecordList` 包裝類別;**條件三**(全稱句改為逐條清單或有自動檢查):範圍宣告已改為逐一列名,不再以項數表述——該項數曾連續被低估三次;**條件四**(兩道覆核都跑過且無「必須先修」級問題):`godot-gdscript-specialist` 與 `godot-specialist` 雙軌覆核,兩軌互不知情而各自查到同一反例,17 筆變更全部在寫入前攔下並修畢,**零項落進檔案**;**條件五**(依賴的上游文件已先核准):本 ADR `Depends On: None`,無上游,條件恆成立。
>
> ⚠️ **核准的定義**(門檻文件第二節):核准的意思是「**可以安全開始照這份文件寫正式程式碼**」,**不等於「完美無缺」**。仍開的不阻擋待辦——證據搬家(987 → 約 700 行)、登記表三項提案、`Mutex` 是否可重入(VR#4)與 export release 建置行為(VR#7)兩項未量測——記於 `production/session-state/active.md` 的「第六批」一節,依門檻文件第四節皆不阻擋本核准。

## Date

2026-08-18(初版) / 2026-08-19(C1/C3 銜接缺口修訂) / 2026-08-20(引擎行為實機驗證修訂) / 2026-08-21(第七輪 17 項修訂) / 2026-08-24(Key Interfaces 閱讀提醒段落所載的同檔強制規則,`AffinityReadResult`/`ShapeFeatureResult` 改為 inner class) / 2026-08-25(補完 `ImportResult`/`AdvanceRejection`/`DeathNotifyResult`、`get_at()` 契約修訂、機制八「與 ADR-0003 的分工」段落措辭修正、Risks 表計數修正)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core(資料結構與並發) |
| **Knowledge Risk** | MEDIUM——本領域無 `breaking-changes.md` 列出的 4.7 專屬破壞性變更(`Dictionary`/`enum`/`Mutex`/`RefCounted` 皆為 4.0 起語意穩定的機制),但仍屬 2026-01 訓練截止後未經本專案實機驗證的版本;無專屬模組參考文件(`docs/engine-reference/godot/modules/` 只有 animation/audio/input/navigation/networking/physics/rendering/ui,無 core/scripting)。**2026-08-20 更新**:本領域已首次取得實機驗證,八項 Verification Required 中六項關閉——其中一項(#6)推翻了本 ADR 的核心宣告。風險等級維持 MEDIUM 而非下調,理由是仍有兩項未查證,且 #7 屬本專案目前無法查證的類別 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`、`breaking-changes.md`、`deprecated-apis.md`、`current-best-practices.md` |
| **Post-Cutoff APIs Used** | 無——`Dictionary[K,V]` 型別化容器語法(4.4 起)、`enum`、`RefCounted`、`Mutex`、`Time.get_ticks_msec()`,以及 `Resource.DEEP_DUPLICATE_ALL`(本 ADR 不使用深拷貝,見 Decision,故此 API 與本 ADR 無交集)皆非本 ADR 依賴項。**2026-08-20 修正**:原本把 `Dictionary[K,V]` 一律當成「4.4 起語意穩定、非依賴項」——該判斷在**巢狀**用法上不成立(4.7.1 明確不支援巢狀型別容器,見 Verification Required #6)。單層型別化容器仍為穩定機制;本 ADR 修訂後**只使用單層**。另新增依賴 `typeof()` 與 `Variant.Type` 常數(機制八的型別檢查),兩者皆為 4.0 起穩定的核心 API |
| **Verification Required** | **2026-08-20 全欄改寫,五項擴為八項,六項已關閉、兩項仍開;2026-08-21 第七輪修訂新增 #9–#12 共四項(其中 #10 新增即關閉),達十二項、七項已關閉、五項仍開(此中間狀態先前未寫回本欄,是本次一併修正的計數漂移,與 A-5 同一種錯);2026-08-25 回填 #9/#11/#12 的核准階段判定後:十二項,十項已關閉、兩項仍開(#4 `Mutex` 可重入、#7 export release 建置下的容器驗證行為)。** 詳表見下方「Verification Required 明細」 |

**引擎知識落差聲明**:`godot-specialist` 於 2026-08-18 對本 ADR 初稿逐項查核(型別化 Dictionary 語意、enum 作為鍵、`RefCounted`+signal 的正確性、`Mutex` 用法、序列化替代方案 `inst_to_dict()`/`dict_to_inst()`、`class_name` 命名空間風險),結論(**⚠️ 2026-08-21 加限定語,R7E-16**:該覆核是 2026-08-18 的**靜態**覆核,當時本專案尚未取得實機執行證據;其「零 BLOCKING」結論已於 2026-08-20 被實機驗證**推翻一項** —— VR #6,巢狀型別容器無法編譯,即本 ADR 的原核心宣告。本段保留作為歷史紀錄,**不得再被引用為現況**):零 BLOCKING 級的機制決策問題(`Dictionary`/`RefCounted`/`enum`/`Mutex`/DI 擁有模式的選擇本身皆確認為 4.7.1 慣用做法),但發現初稿的 Key Interfaces **完整性缺口**——共用列舉(`Pair`/`Character`/`Source`)若不集中包裝於單一 `class_name`,會造成跨檔案引用無法編譯,已修訂為 `AffinityTypes` 包裝類別(見機制二)。另提出 5 項 minor notes,已全數採納並反映於機制四/七/八與本節、Risks 表。

### Verification Required 明細(2026-08-20 改寫)

| # | 項目 | 狀態 |
|---|---|---|
| **1** | 型別化 `Dictionary` 的編譯期鍵值型別檢查是否確實生效(而非僅靜態分析提示) | **已查證(2026-08-20)**,但答案分三層,見機制四之二:編譯期**確實擋** enum 家族與容器整體賦值(層一);**subscript 鍵路徑完全不擋**(層三)。**另:本項原本描述的型別 `Dictionary[AffinityTypes.Pair, Array[AffinityRecord]]` 本身在 4.7.1 無法編譯**,已於本次修訂改為 `Dictionary[AffinityTypes.Pair, AffinityRecordList]`(見機制二 BLOCKING 修訂) |
| **2** | `enum` 值作為 `Dictionary` 鍵的雜湊/相等語意是否與訓練資料涵蓋的版本一致 | **已查證(2026-08-20)**:一致。容器層把 enum 鍵型別抹成 `TYPE_INT`(`get_typed_key_builtin() == 2`),相等語意即 int 相等——這同時是層三空隙的機制解釋。`TR-affinity-003` 的「值型別鍵」決策因此成立且更明確 |
| **3** | GDScript `pow(0.0, 0.0)` 的實際回傳值是否為 `1.0` | **已查證(2026-08-20)**:是,`1.0`(`**` 運算子與 `pow(int,int)` 同)。**但顯式特判仍須保留**——GDD Formulas 邊界值測試總表要求的是「不建立對引擎預設行為的依賴」,不是「數值是否碰巧相符」;改變的只有理由措辭:從「答案未知故須特判」改為「答案已知相符,但契約不允許依賴它」 |
| **4** | `Mutex` 在 4.7.1 是否為可重入(同執行緒重複 `lock()` 不死結,但須成對 `unlock()`) | **仍未查證。**⚠️ 本項原本附註「`godot-specialist` 查核時本專案無 Godot 執行環境可實測」——**該前提已於 2026-08-20 被推翻**:Godot 4.7.1 可在本機 headless 完整執行(`which godot` 找不到只代表不在 `PATH` 上)。本項未關閉的原因改為**尚未撰寫該探針**,不是不能測。**2026-08-21 補充**:本專案至此已跑完四支探針(`prototypes/xcheck-round7-2026-08-20/`),證實單項探針的成本極低(探針 D 為 4 個 `.gd` 檔 + 一個 6 行場景),**建議列入下一批探針**。機制七的鎖定模式(單一進入點取鎖 + `_sweep_timed_out_tokens_unlocked()` 假設已持鎖)**維持不變**——該寫法在兩種答案下皆正確,故本項不影響可實作性,僅影響是否可移除防禦寫法 |
| **5** | 型別化 `Dictionary` 的值槽在 subscript 賦值情境下是否可靠推斷元素型別 | **已查證(2026-08-20)**:**不推斷**(未型別化字面量經 subscript 賦值後讀回 `is_typed() == false`)。包裝類別 `AffinityRecordList` 讓此問題不再適用於 `_records`——`items` 的型別來自宣告式初始化,不經推斷路徑,見機制四實作提醒 |
| **6** | GDScript 4.7.1 是否支援巢狀型別容器 | **已查證(2026-08-20):不支援**——`Parse Error: Nested typed collections are not supported`,class member(無初始化)/ 函式參數 / 回傳型別三種語法形狀皆同,兩個獨立專案重現。**本項為新增,原 VR 表沒有它,而它擊落了本 ADR 的核心宣告**(見機制二 BLOCKING 修訂) |
| **7** | **export release 建置下,C++ 容器驗證(層二)是否仍生效** | **未查證,且本專案目前無法查證**:`%APPDATA%/Godot/export_templates/` 存在但完全是空的、全域零個 `.tpz`;三條替代路皆已排除(`--headless` 只換 DisplayServer、`OS.is_debug_build()` 不可切換、無 template binary)。**🔴 2026-08-21 誠實改寫(R7E-7 / C7)**:本欄原寫「本 ADR **只**依賴層 A(容器驗證是否丟棄寫入),ADR-0005 依賴層 B(VM 中止語意)」—— **兩半都不成立**。(a) 本 ADR **同時依賴層 A 與層 B**:層 A 已由機制四之二的規則二降為縱深防禦,但**層 B 尚未降級** —— 機制四之三的整個論證押在「型別錯誤的阻擋方式是整段呼叫端函式中止」,Risks 表更明寫「失敗會表現為呼叫端函式靜默中止(在 release 建置下甚至可能連錯誤都不列印)」。(b) **ADR-0005 全文對層 B、export release、2026-08-20 的 spike 零命中** —— 本 ADR 單方面替它記帳,與第三輪的 C6 同一形狀。**ADR-0005 是否依賴層 B,由該 ADR 自行認定,本 ADR 不代為記帳。** C7 因此**只關本 ADR 這一半**,另一半需 ADR-0005 第四次修訂補上對應文字。另依 R7E-3,層二的定義域已擴為同時涵蓋鍵與值兩條路徑,故**本項的影響面比原記載更寬**。**建議的關閉方式不是手動測一次**,而是把探針改成建置無關(只斷言容器 `size()`,不管中止與否),掛進 CI 的 release-export job 成為永久回歸測試。**證據等級誠實聲明**:層 A 的關鍵論證是 `ERR_FAIL_COND_V(cond, false)` 的 `return false` 與錯誤列印在同一巨集內、巨集若被編掉則兩者一起消失——此推論的前提(4.7 的實際巨集定義)無 C++ 原始碼可查,屬**訓練資料推論** |
| **8** | 型別錯配的 `Variant` 傳給內建函式、比較運算子、與型別化賦值時的行為 | **已查證(2026-08-20,`XCHECK-4`)**:內建函式(`is_finite`/`is_nan`/`is_inf`)與比較運算子(`==`/`>=`)對 `String` **皆中止所在函式**,無一會靜默回傳 `false`;但 `var t: int = <float 1.5>` **靜默截斷為 `1`**,不中止不報錯。中止不往上層傳染。**本項為新增**——它坐實了機制八「先 `typeof()` 內省、後值域運算」的排序,並揭露了 `t`/`c` 型別檢查不可寬鬆到「int 或 float 皆可」的靜默截斷風險 |
| **9** | `match typeof(x)` 對 `TYPE_NIL` 分支的比對行為(機制五的 `t_query` 三分支閘門所依賴) | **已查證(2026-08-24,探針 `prototypes/xcheck-adr0002-vr9-vr11-2026-08-24/probe-vr9-match-typeof/`)**:`match typeof(null)` 確實命中 `TYPE_NIL` 分支;`TYPE_NIL` 具名常數與字面量 `0` 作為 case 標籤行為相同(13/13 組一致,額外覆蓋 `TYPE_FLOAT`/`TYPE_INT`/`TYPE_STRING`/`TYPE_BOOL`/`Array`/`Dictionary`/`Vector2`);完全沒有 `TYPE_NIL` 分支時 `null` 乾淨落入 `_`。**本項關閉。** 另量到一項獨立的實作陷阱(`_` 提前吃掉 `null` 的順序陷阱),已移出本欄,改記於機制五 `t_query` 型別閘門旁的實作提醒 |
| **10** | `AffinityTypes.Pair.values().has(int)` 與 `keys().has(String)` 對**越界 / 非法**輸入的回傳值 | **已查證(2026-08-21,探針 D)**:皆**乾淨回傳 `false`、不中止**,字面量與執行期動態組出兩形同行為。**新增即關閉。** 這是機制四步驟 4/5 的序數檢查與機制八名稱存在性檢查的共同地基 |
| **11** | **型別化 `Array` 對越界索引的讀取行為**(`AffinityRecordList.get_at(index)` 所依賴) | **已查證(2026-08-24,`prototypes/xcheck-adr0002-vr9-vr11-2026-08-24/probe-vr11-array-bounds/logs/run1-unfiltered.txt`)**:`[]` subscript 越界中止呼叫函式;`.get()` 越界印 ERROR 但不中止、回傳 `null`;負索引 `-1` 在非空陣列取到最後一筆,空陣列則中止。**`get_at()` 已依此重新設計(2026-08-25,見機制二契約修訂),本項關閉** |
| **12** | `var_to_bytes()` / `bytes_to_var()` 對 `int` 與 `float` 的**型別往返保真** | **已查證(2026-08-25,探針 `prototypes/xcheck-adr0002-vr12-2026-08-25/`)**:機制八對 `m` 嚴格 `TYPE_FLOAT`、`t`/`c` 嚴格 `TYPE_INT` 這兩條拒絕規則的前提——在測過的所有情況下(整數值/非整數值/極端量級 float、含超過 32 位元的 int、`export_state()` 實際容器巢狀形狀、`INF`/`-INF`/`NAN` 特殊值)——型別往返完整保真,無一被序列化過程本身改變型別。**⚠️ 窄劃界,不可弄丟**:本項只關閉 ADR-0002 自己這條窄依賴(「合法輸出的型別往返不會被序列化過程本身改變」),**不代表 ADR-0003 選擇二進位 Variant 序列化這個格式決策整體的 Knowledge Risk HIGH 評級一併降級**——探針測的範圍只是 ADR-0002 機制八用到的兩個具體純量欄位形狀,不是該格式決策涉及的其他面向(`Object` 靜默編碼、`Dictionary` 鍵順序敏感等)。**本 ADR 只登記依賴,不代為記帳**(與 C7 的立場一致) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None(**見下方 `Ordering Note`——本 ADR 有兩處具體點名其他 ADR 的構造,皆已於該欄位確認不構成 `Depends On` 意義的依賴**) |
| **Enables** | `docs/architecture/adr-0003-save-system-serialization-format-and-type-safety.md`(2026-08-18 已寫入,`TR-save-001` 及其下游)——引用本 ADR 的 `export_state()`/`import_state()`/`validate_semantics()` 通用 `Dictionary` 契約與反序列化語意驗證規則,決定實際容器格式;好感度—位置連鎖系統、敘事解鎖與結局分支系統、技能卡牌系統、支援對話系統、章節/戰役結構、戰棋移動與交戰系統(陣亡通知呼叫方)的後續設計/實作 |
| **Blocks** | 好感度數值池相關 story 的 `/create-stories`/`/dev-story`——目前 24 項 `TR-affinity-*` 缺口全數卡在此 |
| **Ordering Note** | 本 ADR 刻意**不**依賴尚未撰寫的存檔系統 ADR(序列化格式、寫入並發模型皆為該 ADR 的範圍)——`affinity-data-pool.md` Dependencies 章節明文本系統「仍是唯一不需要等待其他系統設計完成即可實作的資料層」,若本 ADR 反過來依賴存檔系統 ADR 的格式/執行模型決策,會違反這個明文的獨立性宣告,並造成循環等待(存檔系統 ADR 大概率會想引用本 ADR 的邏輯結構)。本 ADR 對「序列化生命週期權杖集合是否需要 Mutex 保護」的決定已在本 ADR 內**無條件**拍板(見 Decision),不等待存檔系統執行模型定案。**2026-08-25 新增,兩條邊的防線一次交代**:本 ADR 有兩處具體點名其他 ADR 的構造——(a) 機制七『逐權杖惰性逾時清除』引用 ADR-0004 擁有的 `TOKEN_TIMEOUT_MS`;(b) 機制八引用 ADR-0003 機制一之二的 `SaveTypeGate`(見『與 ADR-0003 的分工』段落)。**兩者皆不構成 `Depends On` 意義的依賴**,理由分開講:(a) 機制七的**主要**逾時清除確確實實在引用這個常數——本文件已就地把它標為 `Depends On: None` 的一個**既存例外**(見機制七的 C1 銜接缺口段落)。本 ADR 不把它升格為 `Depends On`,理由是本 ADR 擁有逾時**機制**的執行,不擁有 `TOKEN_TIMEOUT_MS` 這個**數字**,而該數字變動不會改變本 ADR 任何機制決策(定值依據、推導公式皆由 ADR-0004 掌握)。`_reclaimed_tokens` 的**次要**逾時已改為固定容量 FIFO、不再引用任何外部常數——這只是把例外面縮小為「機制七主要逾時清除」這一處,**不是**兩處都不再引用,不可拿次要逾時的事實去支撐整條邊已經沒有引用的結論。(b) 本 ADR 對 `SaveTypeGate` 的決定依據是「引擎原生 `allow_objects` 閘門只擋 `Object`」這個引擎事實,不是「ADR-0003 選擇用 `SaveTypeGate` 補洞」這個設計決定。**若這兩處被誤讀為 `Depends On`,會繞成 `ADR-0002 → ADR-0004 → ADR-0003 → ADR-0002` 的循環**(`ADR-0004 → {ADR-0003, ADR-0002}`、`ADR-0003 → ADR-0002` 已成立)——這正是為何本欄位維持 `None`,且兩處引用都只是「登記依賴,不代為記帳」(比照 VR#12 的既有寫法),不是反向依賴。 |

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

**共用列舉的檔案歸屬(2026-08-18 `godot-specialist` 驗證發現,BLOCKING 修訂)**:`godot-specialist` 審查本 ADR 初稿時指出,GDScript 沒有「不透過任何 class 包裝、跨檔案可見的裸列舉」這回事——列舉若定義在某個 `class_name` 的類別內,只能以 `ClassName.EnumName` 從其他檔案存取;若腳本連 `class_name` 都沒有,則只能靠 `preload()` 存取。若 `Pair`/`Character`/`Source` 三個跨系統共用的列舉裸露宣告、卻被 `AffinityRecord`(另一個檔案)未經限定地直接使用,不會通過編譯。修訂為:三者集中定義於獨立的 `affinity_types.gd`,以 `class_name AffinityTypes` 包裝,所有其他類別一律以 `AffinityTypes.Pair`、`AffinityTypes.Character`、`AffinityTypes.Source` 限定存取——這同時避免了三個高碰撞風險的裸全域類別名稱(`Pair`、`Character`、`Source` 本身語意過於通用,未來其他系統或 addon 命名衝突風險較高),集中為單一 `Affinity` 字首命名空間。各方法自身的結果列舉(`WriteRejection`、`AdvanceRejection`、`DeathNotifyResult`、`EndTokenResult`、`ReadRejection`、`ReadMode`;**2026-08-21:`SpeculativeRejection` 已刪除並併入 `ReadRejection`**)不受此修訂影響,維持巢狀於 `AffinityDataPool` 內、以 `AffinityDataPool.WriteRejection` 等方式限定存取(它們只在呼叫 `AffinityDataPool` 自身方法的上下文中使用,不需要獨立抽出)。

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
var _items: Array[AffinityRecord] = []      # 私有,唯一寫入路徑是 append()

func append(record: AffinityRecord) -> void
func size() -> int
func get_at(index: int) -> AffinityRecord   # 可為 null,見下方 2026-08-25 契約修訂
```

**2026-08-21 修訂(R7E-12,使用者裁決)**:`items` 由公開欄位改為私有 `_items` + 最小存取面。
**不提供任何回傳 `_items` 本身的方法** —— ADR-0001 已登記 `returning_internal_container_references`;
嚴格說 `AffinityRecordList` 從不跨出 `AffinityDataPool` 的系統邊界(該禁令逐字綁定「Board's internal storage」,
是 ADR-0001 對戰棋盤面的特定措辭),故**本 ADR 是類比套用該紀律,而非該註冊禁令本身適用** —— 但不開這個口的成本為零。

> **誠實聲明,不可省略**:**GDScript 沒有真正的私有成員**,`_items` 的底線前綴是命名慣例、不是語言層強制。
> 因此本項**不是結構保證**。相對於保留公開 `items` 的收益是:唯一被許可的寫入路徑收斂為
> `append(record: AffinityRecord)` 這個**型別化簽章**,任何對 `_items` 的整體賦值都成為明顯的慣例違反、
> 可被 lint 與 registry 的 `wholesale_reassignment_of_affinity_record_list_items` 偵測 —— 而公開 `items`
> 的整體賦值是**完全正常的用法**,無從辨識。**本 ADR 不宣稱這一項達到 Alternative 7 所要求的
> 「結構保證優於紀律要求」標準**;它是把紀律的作用面從「一個公開記載的欄位」收窄為
> 「一個底線前綴欄位 + 一個明文禁令」。

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
| `inner` 的內層陣列 `is_typed()` | `true`(2026-08-20 量測時該欄位名為 `items`;2026-08-21 已改為私有 `_items`,量測結論不變) |

> **不可引用 `get_class()` 的輸出作為此結論的證據**:它回傳**原生**類別,任何 `RefCounted` 子類別都印 `RefCounted`,無法區辨包裝類別、也從未碰到內層。2026-08-20 的覆核推翻了 spike 原本以 `get_class()` 為依據的同一結論——結論湊巧為真,證據無效。此處引用的是覆核者改測的三項。

**代價**:多一個全域 `class_name`(碰撞風險見 Risks 表既有列,前綴 `Affinity` 與其餘三個同帶字首者一致,但全域類別總數與字首比例已於 Risks 表修正(2026-08-25,見該表「全域 `class_name` 命名碰撞」列)——本句不再自行複述總數與比例,避免同一件事第三處各自維護),以及所有存取多一層方法呼叫(`append()`/`size()`/`get_at()`;**2026-08-21 修訂前為 `.items` 屬性存取**)。**收益**:內層元素型別由 `AffinityRecordList` 自身的宣告式 `var _items: Array[AffinityRecord] = []` **加上 `append()` 的型別化參數簽章**共同保證,**不經任何 subscript 型別推斷路徑**(見機制四的實作提醒——subscript 賦值已實測**不**推斷元素型別)。

**`get_at()` 契約修訂(2026-08-25,VR#11 關閉)**:`prototypes/xcheck-adr0002-vr9-vr11-2026-08-24/probe-vr11-array-bounds/logs/run1-unfiltered.txt` 實測——型別化 `Array` 的 `[]` subscript 對越界索引**中止呼叫函式**(`SCRIPT ERROR: Out of bounds get index`);`.get()` 存在,越界時印 ERROR 但**不中止、回傳 `null`**;負索引 `-1` 在非空陣列乾淨取到最後一個元素,空陣列則中止。**管理者裁決:`get_at()` 改為越界不中止、回傳 `null`**——中止正是本 ADR 花最大力氣在防的失敗形狀(機制八「逐欄位型別+值域」段落與其下的實測表:中止讓契約承諾的結構化回傳「永遠回不去」),且回 `null` 與 `from_dict()` 既有的失敗語意一致。

**簽章不變,仍為 `-> AffinityRecord`**:GDScript 允許 `null` 賦值給任何 Object 衍生型別的回傳值,`from_dict()` 已是同一種先例,不需要改成 `Variant`。

**實作:自行邊界檢查,不依賴 `.get()` 或 `[]` 對負索引的原生語意**:
```gdscript
func get_at(index: int) -> AffinityRecord:
    if index < 0 or index >= _items.size():
        return null
    return _items[index]
```
**負索引刻意不沿用引擎原生語意**:探針顯示型別化 `Array` 對負索引的原生行為在非空/空陣列下不一致(非空陣列的 `-1` 取到最後一筆,空陣列則中止)——這種「行為隨陣列當下狀態而變」的語意若直接暴露給呼叫端,會讓同一段呼叫端程式碼在不同時間點得到不同種類的失敗。`get_at()` 統一把任何 `index < 0` 或 `index >= size()` 都視為越界,一律回傳 `null`;`AffinityRecordList` 不對外提供「取倒數第 N 筆」語意,呼叫端若需要最後一筆,應自行 `get_at(size() - 1)` 表達(`size() == 0` 時該式為 `-1`,依本規則同樣回傳 `null`,**但仍受下方呼叫端義務約束,必須檢查 `null`**——呼叫端不需要另外判斷空陣列這件事本身,不代表可以省略檢查)。

**呼叫端義務**:所有呼叫端必須檢查 `get_at()` 回傳值是否為 `null`,不得假設索引一定落在合法範圍。

**Validation Criteria 11(b) 需同步擴充**:原「先 `append()` 一筆記錄後再斷言 `_records[pair].get_at(0) is AffinityRecord`」方向不變;**新增**:對空 list 呼叫 `get_at(0)`、對非空 list 呼叫 `get_at(-1)`/`get_at(size())`,斷言三者皆乾淨回傳 `null`、不中止。

`AffinityDataPool` 內部儲存:

```
var _records: Dictionary[AffinityTypes.Pair, AffinityRecordList]      # per-pair 索引,查詢 O(n_p)
var _t_now: int                                          # 執行期快取,見下方「衍生值」說明
var _campaign_tick_marks: Array[int]                     # append-only,見下方
var _death_marks: Dictionary[AffinityTypes.Character, int]             # 獨立於 Delta Log
var _next_token_id: int
var _serialization_tokens: Dictionary[int, int]          # token id → 發放當下 Time.get_ticks_msec()
var _reclaimed_tokens: Dictionary[int, bool]             # 已逾時回收的 ID,僅作查找(見機制七)
var _reclaimed_token_order: Array[int]                   # 2026-08-21:明確維護插入順序,供固定容量 FIFO 淘汰
var _token_mutex: Mutex

# 2026-08-21(修正 T):三個 enum 的合法序數快取。`.values()` 每次呼叫都重新配置一個新 Array,
# 而四個讀取函數是每回合多次的熱路徑。`_init()` 時快取一次即可 —— AffinityDataPool 是每場戰役
# 建構一次的 DI 實例,不是每幀重建。**不能用 `const`**:GDScript 的 `const` 不支援方法呼叫作初始化式。
var _pair_ordinals: Array
var _character_ordinals: Array
var _source_ordinals: Array
```

**`Dictionary[AffinityTypes.Pair, AffinityRecordList]` 直接滿足 `TR-affinity-002`(O(n_p+m) 效能契約)**:單一配對查詢只需 `_records[pair]`(O(1) 鍵查找)取得該配對自身的 `AffinityRecordList`,再以 `size()`/`get_at(i)` 走訪其型別化內層陣列,不掃描其他配對——這正是 GDD 明文排除的「單一扁平陣列 + 全表掃描過濾」反模式。**包裝層只改變值槽的型別,不改變鍵查找複雜度**,故此論證與初版完全相同。**`Pair`/`Character` enum 皆為值型別(底層是 int)**,直接滿足 `TR-affinity-003`(Dictionary 鍵須為值型別,不可為 Object/Resource 參照)——本專案已知的 GDScript 參照相等陷阱不適用於此:`AffinityRecord` 與 `AffinityRecordList` 雖皆為 `RefCounted`,但**兩者都只作為值、從未被用作任何 Dictionary 的鍵**(前者是 `AffinityRecordList` 內層陣列的元素,後者是 `_records` 的值)。

**`_t_now` 是執行期快取,不是獨立持久化欄位**(直接滿足 `TR-affinity-004`「衍生值,不得另存」):載入完成後(`import_state()` 執行完畢時)由 `_records` 各配對 `AffinityRecordList.size()` 總和一次性重建(`O(n_total)`,只在載入時發生一次,不影響任何單次查詢的複雜度保證)。**2026-08-21**:修訂前此處寫 `.items` 長度 —— `items` 已改私有,若不同步會編譯失敗;另,機制二的預填 10 個空 list **不改變總和**(空 list 的 `size()` 為 0);運行期每次 `append_record()` 成功時 `+1`。序列化時**不**輸出 `_t_now` 欄位本身,只輸出 `_records`——這避免了「儲存的衍生值與實際內容不同步」這一類本專案已知的傳播失敗模式(見 `.claude/docs/context-management.md` 對跨檔同步失敗的一般性警語)。

**建構子預填全部 10 對配對(2026-08-21,R7E-2,使用者裁決)**:

```
func _init() -> void:
    _pair_ordinals = AffinityTypes.Pair.values()
    _character_ordinals = AffinityTypes.Character.values()
    _source_ordinals = AffinityTypes.Source.values()
    for p in _pair_ordinals:
        _records[p] = AffinityRecordList.new()
```

**問題(探針 A 實測)**:型別化 `Dictionary` 對**從未寫入的鍵**做 subscript 讀取是
`SCRIPT ERROR: Out of bounds get index` 並**中止呼叫函式** —— 不是 `null`、不是預設值。而機制四原本只規定
「**寫入**時先建 `AffinityRecordList`」,讀取路徑零規定;戰役開場 `_records` 是空的,第一次
`combat_strength_read(pair)` 必然中止。而 `n(p) = 0` 是 GDD 跨結構不變量第 4 條明文的**合法**狀態,
不是邊緣情境。

`import_state()` 驗證通過、替換內部狀態後**同樣重新預填**(先預填 10 對空 list,再逐筆 `append()`)——
否則還原後又回到缺鍵狀態。**`n(p) = 0` 的表現形式因此是 `_records[p].size() == 0`,不是缺鍵**;
讀取路徑**零守衛**,`_records[pair]` 對任何合法配對在任何時點皆安全(非法序數在入口即被攔下,見機制四之四)。

> **`_death_marks` 刻意不預填,一律 `has()` 守衛** —— 兩個容器的策略不同,因為它們的**鍵存在性語意不同**:
> `_death_marks` 的**鍵存在本身就是「該角色已陣亡」**(機制三:「若 `character` 已存在於 `_death_marks`,
> 回傳 `DUPLICATE_DEATH_NOTIFICATION`」)。預填會讓 5 名角色全部變成「已陣亡」,**摧毀語意**。
> 因此 `t_death()` 對兩名成員的查找一律先 `_death_marks.has(character)`,`import_state()` 亦不預填。
> **這個不對稱是刻意的**,已登記 forbidden pattern `death_marks_prefill_or_unguarded_read`,
> 避免下游實作者「為了一致性」把 `_death_marks` 也預填。

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
4. `_source_ordinals.has(source) == false` → `INVALID_SOURCE`
5. `_pair_ordinals.has(pair) == false` → `INVALID_PAIR`

> **🔴 2026-08-21 修訂(R7-P1,原推論句已被實機證偽)**:步驟 4/5 原本附註「GDScript enum 本身型別化後
> 這條**理論上不可達**,但保留作為跨語言邊界輸入的防禦層」。**探針 B 實測證偽** —— 越界 int(`-1`/`999`)
> **原封不動抵達函式本體、零錯誤零檢查**。因此這兩個拒絕碼**不是防禦層,是唯一防線**。
> 檢查手段為 `.values().has(ordinal)`(探針 D 實測:對越界輸入**乾淨回傳 `false`、不中止**),
> 實作上讀 `_init()` 快取的 `_pair_ordinals`/`_source_ordinals`(修正 T:`.values()` 每次呼叫重新配置陣列)。
>
> **⚠️ 本 ADR 結構上無法攔截的一類(R7-P2)**:上游若夾帶 `float 3.7`,呼叫端**不中止**,參數靜默截斷為
> 合法序數 `3` → **步驟 4/5 會通過** → 記錄寫進**錯誤配對**、回傳 `WriteRejection.NONE`。值域檢查看到的
> 已經是「合法的 3」,**無從得知它原本是型別錯誤的浮點數**。這是本 ADR 唯一一類「寫入成功、回傳成功、
> 資料落在錯誤位置、且任何下游檢查都看不出異常」的失敗 —— 唯一防線是**呼叫端義務**(見機制四之三)。
6. `t_death(pair) != null and source == AffinityTypes.Source.COMBAT_CARD` → `DEAD_PAIR_COMBAT_CARD_FORBIDDEN`

全數通過 → 建立 `AffinityRecord`,以 `_records[pair].append(record)` 附加,`_t_now += 1`,回傳 `WriteRejection.NONE`,並 emit `entry_appended(pair, record)` 訊號(見機制七)。任何拒絕路徑皆不遞增 `_t_now`、不附加記錄,對應 GDD「不遞增全域計數器、不產生記錄」的一致慣例。

**實作提醒(2026-08-18 `godot-specialist` 提出,2026-08-20 實機驗證後改寫,2026-08-21 因建構子預填再次改寫)**:**寫入路徑假設 `_records[pair]` 對全部 10 個合法配對永遠存在**(機制二的建構子預填),不需要「檢查—建立」這一步;非法序數在入口即被 `_validate_pair_ordinal()` 攔下(機制四之四),不會走到這裡。**原文寫「首次對某配對寫入時需先建立」,那個前提在預填生效後不再為真,已刪除。** 原本「無法確認 subscript 賦值是否可靠推斷元素型別」的疑問**已實測定案:不推斷**(把未型別化字面量以 subscript 賦值存入型別化 `Dictionary` 的值槽後讀回,`is_typed()` 為 `false`)。這正是包裝類別相對 Alternative 7 的一項附帶收益:內層元素型別由 `AffinityRecordList` 自身的宣告式 `var _items: Array[AffinityRecord] = []` 與 `append()` 的型別化參數簽章共同保證,**完全不經 subscript 推斷路徑**;而值槽本身的型別(`AffinityRecordList`)由下述層一的編譯期檢查守住。

### 機制四之二:型別保證分三層,與兩條邊界規則(2026-08-20 實機驗證新增)

本 ADR 初版對「型別化容器」的措辭把型別標註當成**單一層**的保證。實機驗證顯示它是**三層**,且三層的強度、失敗方式、以及**是否可依賴**都不同:

| 層 | 機制 | 實測結果 | 可依賴? |
|---|---|---|---|
| **一** | GDScript 編譯期靜態檢查 | **確實擋 enum 家族**:`Cannot assign a value of type "AffinityTypes.Character" as "AffinityTypes.Pair"`;容器整體賦值同樣擋(`Dictionary[Character,int]` 不可賦給 `Dictionary[Pair,int]`) | **是**——編譯期錯誤,是結構保證 |
| **二** | C++ 容器驗證(`container_type_validate.h`)。**2026-08-21 定義域擴寫(R7E-3)**:原文只寫「值槽的錯誤 `Object` 類別」,實測層二**同時涵蓋鍵的錯誤內建型別**(`String` 當鍵會被擋)——因此 VR #7「層二在 release 是否生效」的**影響面比原記載更寬**,同時涵蓋鍵與值兩條路徑 | debug 建置下確實生效,但**兩種寫入路徑行為不同**:錯誤 `Object` 類別寫進 `Dictionary` 值槽 → 錯誤 + `SCRIPT ERROR` + **所在函式中止**;錯誤元素 `append` 進型別化 `Array` → 錯誤 + **寫入被丟棄**,`size()` 不變。⚠️ **差異的成因是「subscript 賦值運算子」vs「方法呼叫」,不是「`Dictionary`」vs「`Array`」**——這張表不可據以類推到 `Dictionary.merge()`、`Array.erase()` 等其他寫入路徑 | **否**——export release 建置下是否仍生效**未查證**(見 Verification Required 第 7 項) |
| **三** | **enum 家族在容器層不可區辨**(2026-08-21 改標;原標籤「型別化 `Dictionary` 的 subscript 鍵路徑」**按字面為假**——spike 實測把 `String` 當鍵寫入型別化 `Dictionary` **會被擋**,真正為假的只有跨 enum 家族那一格) | **對跨 enum 家族完全不擋**:`Dictionary[Pair,int][Character.CHARACTER_3] = 99` → `size=1`、`keys=[2]`、**零錯誤訊息**。機制是 `get_typed_key_builtin() == 2`(`TYPE_INT`)——enum 家族在容器層被抹成 `int`,`Character` 與 `Pair` 在鍵型別上不可區辨 | **否**——已實證為空隙 |

**因此本 ADR 明訂兩條邊界規則——鍵與值是兩件事,分別對應層三與層二**:

> **規則一(鍵邊界,對應層三)**:所有從本系統**外部**進入 `_records` / `_death_marks` 的**鍵**,一律經 `func f(pair: AffinityTypes.Pair)` 這類**型別化參數簽章**收斂;**禁止**把來源為 `Variant`(或未經型別化參數收斂的值)直接當作 subscript 鍵。**2026-08-21 澄清(修正 K)**:本規則的「外部」**不包含**本系統自身以 enum 權威值列表(`.values()`)產生的內部初始化迴圈(機制二的建構子預填)。**判準是值的來源,不是變數的靜態型別。**
>
> **規則二(值邊界,對應層二)**:`_records` / `_death_marks` 的**值**一律由本系統自身方法以**靜態型別**建構後賦值——`_records[pair] = AffinityRecordList.new()`(`.new()` 的回傳值靜態型別即 `AffinityRecordList`,在層一編譯期即受檢)、`_records[pair].append(record)`(`record` 為本系統內部建構的 `AffinityRecord`,且 `append()` 的參數簽章為型別化 `AffinityRecord`)、`_death_marks[character] = _t_now`(`int`)。**外部呼叫者沒有任何路徑可以把 `Variant`/`Object` 直接寫進這兩個容器的值槽**——三個公開寫入方法只接收型別化的純量與 enum,不接收容器或物件;`import_state()` 是唯一一條外來資料路徑,其防線見機制八。

> **⚠️ 2026-08-21:三層不再宣稱正交(R7E-3)**——層二與層三在「鍵」這個維度上**重疊**:層二擋錯誤內建型別的鍵,層三放過同為 `int` 的錯誤 enum 家族鍵。原文的正交宣稱已刪除。

**兩條規則各自關掉一層,不可互相代用**:

- **規則一關掉層三**。層三是已實證的空隙(錯誤家族的 enum 鍵經 subscript 寫入完全不被攔),規則一把外來鍵推回層一的編譯期檢查——那一層已實證會擋,空隙因此關在系統邊界之外。
- **規則二關掉對層二的依賴**。層二量測的是**值槽被塞進錯誤 `Object` 類別**,與「鍵是否跨 enum 家族」**是兩件不同的事**。⚠️ 本次修訂的初稿曾用規則一去支撐「層二可降級」,那是**不成立的推導鏈**(論證的是另一件事),已由寫入前的 Step 5.5 覆核抓出並改正。真正讓層二降為縱深防禦的是規則二:值從來不經 `Variant` 中介,層一在賦值處就檢查完畢,層二的 C++ 容器驗證只是同一件事的第二道確認。

**兩條邊界規則本身不改變任何既有簽章**——它們只約束鍵與值的**來源**,而本 ADR 的公開介面參數本來就全部符合(`append_record`/`can_write`/三個讀取函數/`notify_death` 的參數皆為型別化 enum 與純量)。**🔴 但 2026-08-21 的修訂另外改變了 `can_write()` 的回傳型別**(`bool` → `WriteRejection`,見機制九)——那是序數驗證的需要,**與這兩條邊界規則無關,兩件事不可混為一談**。(本註記本身即證據:原句逐字點名 `can_write`,而同一次修訂改了它的簽章;這是本專案「修法讓某個既有宣稱變得不成立」模式的**第八次**,由協調者寫入前 grep 核實抓到,兩軌 Step 5.5 覆核皆未抓到——因為該修法是覆核之後才產生的。)它們把兩個原本隱含的性質升級為明文的、可被 registry 強制的架構約束(見 `raw_variant_subscript_into_typed_container`),並指明未來新增介面時不得破壞。

**🔴 2026-08-21 修訂(R7E-4)——規則一的載重必須降級**:本節原本宣稱兩條規則「把型別空隙關在系統邊界外」,而規則一的整個載重是「型別化參數簽章會**收斂**鍵」。**探針 B 實測顯示它只是「轉換」**:enum 型別標註在這個邊界上**只抹平 `String` 一類**;對 `float`/`bool` 是**靜默轉換**(`3.7` → `3`、`true` → `1`),對越界 int 則**完全不作用**(原封不動抵達函式本體)。因此規則一關掉的是「跨 enum 家族的鍵誤用」,**不是**「所有型別非法的鍵」——後者需要機制四之四的序數驗證器,而那是值域層而非型別層的手段。

**效果**:層二在 export release 建置下是否仍生效(Verification Required 第 7 項,未查證),**不再影響本 ADR 對「值」的正確性論證**(規則二讓值從不經 `Variant` 中介);但依 R7E-3,層二的定義域同時涵蓋鍵,故 VR #7 對「鍵」這條路徑的影響**仍未被規則一完全吸收**。這與本 ADR C3 修訂對 `Mutex`、ADR-0004 對 `SaveIOBackend` 是**同一個手法**:把未查證的外部行為隔離成「有則更好」,而非「正確性所繫」。**但唯一的外來資料路徑 `import_state()` 不受這兩條規則保護**——它處理的就是本系統外部產生的 `Dictionary`,那條路徑的防線是 `validate_semantics()`,見機制八。

**失敗模式為何值得這樣防**(不是崩潰,是靜默存檔損壞、且出貨版本專屬):錯誤型別的鍵或值若被靜默寫入 `_records`(層三路徑:無錯誤、無中止、`size()` 增加),四個讀取函數迭代到型別不符的元素時,公式一/二會產生 `NaN` 或在**離寫入點很遠**的地方爆;更糟的是壞值會經 ADR-0003 的 `var_to_bytes()` 寫進存檔並**通過該 ADR 的兩層 SHA-256 雜湊鏈**——雜湊驗的是位元組完整性,不是語意合法性。存檔在位元層完全合法、在語意層已損壞。

### 機制四之三:驗證順序的安全性,與呼叫端的型別義務(2026-08-20 實機驗證新增)

**機制四的驗證順序不需要改,而理由現在是實測而非推論**:`append_record(pair, m: float, source)` 的 `m` 是**型別化參數**,實測確認一個夾帶 `String` 的 `Variant` 在**呼叫端**就被擋下——函式本體從未執行。因此步驟 2(`m == 0.0`)與步驟 3(`is_nan(m) or is_inf(m)`)在進入時 `m` 必為 `float`,兩者都不會踩到機制八記載的中止路徑。**這是規則二(值邊界)的保證,不是規則一(鍵邊界)的**——兩者不可互相引用。

**但這條保護有一個必須明文的代價——呼叫端義務**:型別化參數的阻擋方式是**整段呼叫端函式中止**,不是一個可判斷的回傳值。本 ADR 的錯誤處理哲學是「GDScript 無 try/catch,錯誤一律以回傳值表達」(見 Constraints),而型別錯誤是這條哲學**唯一涵蓋不到**的失敗類別:`append_record()` 不可能回傳一個 `INVALID_TYPE`,因為那個呼叫根本到不了函式本體。

因此:**上游系統若持有來源不明的 `Variant`(例如從存檔、從編輯器匯入的資料表、從尚未定案的角色系統傳來的識別碼),必須在呼叫 `append_record()`/`notify_death()` 之前自行以 `typeof()` 收斂型別**,不能把型別驗證的責任推給本系統的拒絕碼機制。本 ADR 的 7 類 `WriteRejection` 涵蓋的是**值域與狀態**的非法,**不涵蓋型別的非法**——這個範圍界線先前是隱含的,現在明文寫出。

**本 ADR 刻意不新增 `WriteRejection.INVALID_TYPE`** —— **結論不變,但 2026-08-21 理由改寫(R7E-4)**:原理由是「型別錯誤到不了函式本體,所以那會是死碼」,**已被探針 B 證偽**(數值近親確實到得了)。新理由:**到得了函式本體的那一類已經無法與合法值區辨** —— 截斷後就是合法序數 `3`,`typeof()` 看到的是 `TYPE_INT`。因此 `INVALID_TYPE` 依然不可能被回傳,只是原因從「到不了」變成「**到了也認不出**」。

### 機制四之三之二:本 ADR 全部 `Variant` 介面面的稽核清單(2026-08-21 新增,R7E-6 的根因修法)

第七輪的根因判定是:2026-08-20 的修訂在新增範圍宣告時,**只稽核了自己剛寫的 `append_record`/`notify_death`**(參數全是型別化 enum 與 `float`,根本不是 `Variant` 進入本系統的路徑),漏掉了 ADR 既有的 `Variant` 入口。本節採納第七輪的第四條自問——**「我這次新增的範圍宣告,涵蓋了本文件全部同類的介面面嗎?我列過那份清單嗎?」**——並以 grep 而非記憶回答它。

**`Variant` 入口(外部 → 本系統),共 5 條**

| # | 位置 | 防線 |
|---|---|---|
| 1 | `combat_strength_read(t_query: Variant)` | 機制五的 `typeof()` 三分支閘門 |
| 2 | `narrative_depth_read(t_query: Variant)` | 同上 |
| 3 | `shape_feature_read(t_query: Variant)` | 同上 |
| 4 | `import_state(data)` / `validate_semantics(data)` 的**欄位內容** | 機制八的「先 `typeof()`、後值域」 |
| 5 | **`AffinityRecord.from_dict(d: Dictionary)`** | 機制八:方法**自己內部**呼叫共用的 `AffinityRecord.check_record_fields()`(鍵集合 + 名稱合法性 + `m`/`t`/`c` 型別合法性,2026-08-25 補強),任一檢查失敗**回傳 `null`** |

> **第 5 條是 2026-08-21 Step 5.5 覆核抓到的漏項**:第 4 條已把稽核範圍從「型別字面為 `Variant`」擴大到「參數是 `Dictionary` 但內容是不可信 `Variant`」——**一旦接受這個更寬的範圍,`from_dict()` 必須在列**。它是**公開靜態方法**,任何呼叫方可直接 `AffinityRecord.from_dict({"pair": "GARBAGE"})`,**完全繞過 `validate_semantics()` → `import_state()` 的兩段式契約**,精準命中探針 C 實測的動態非法字串索引中止。**防線放在方法自己裡面,不依賴呼叫方一定先跑 `validate_semantics()`。**2026-08-25 補強**:原本的防線只擋列舉名稱非法,未擋 `m`/`t`/`c` 的型別錯配(例如直接呼叫 `AffinityRecord.from_dict({"pair":"C1_C2","source":"COMBAT_CARD","m":<Callable>,"t":1,"c":0})` 先前可繞過);現由共用的 `check_record_fields()` 同時檢查兩者,見機制八之二。**

**`Variant` 出口(本系統 → 外部),共 4 條 + 1 條本次消滅**

| # | 位置 | 呼叫端義務 |
|---|---|---|
| 6 | `t_death(pair) -> Variant`(`int` 或 `null`) | 先 `typeof()` / null 檢查,**絕不直接做數值比較** |
| 7 | `ShapeFeatureResult.time_distribution` | 同上(R7E-15) |
| 8 | `ShapeFeatureResult.segment_profile` | 同上(R7E-15) |
| 9 | `ShapeFeatureResult.low_confidence` | 同上(R7E-15) |
| ~~10~~ | ~~`speculative_read() -> Variant`~~ | **2026-08-21 消滅**(機制五改為結果物件帶 `rejection` 欄位) |

**為何出口也算義務**:實測 `is_finite`/`is_nan`/`is_inf` 與 `==`/`>=` 對 `String` 皆中止所在函式,對 `null` 同理。下游若對這四條出口寫數值比較,會**中止下游自己的函式**,而本系統對此無任何攔截能力。**布林判斷對 `null` 安全,數值比較不安全** —— 這個差別必須明文。

**呼叫端義務的孤兒狀態(誠實記錄,R7E-4)**:`append_record()` 的三個呼叫點(技能卡牌、支援對話、劇情事件)**全部無 GDD 亦無 ADR**。因此上述呼叫端義務目前**沒有任何文件承接** —— 這是一項已知的孤兒義務,本 ADR 不假裝它已解決。

### 機制四之四:8 個帶 enum 參數的入口統一序數驗證(2026-08-21 新增,R7-P1 的完整修法)

序數穿透**不是 `append_record` 專屬** —— 它附著在**任何** `Pair`/`Character`/`Source` 型別的參數上。2026-08-21 修訂初稿只在 `append_record` 加了檢查,Step 5.5 覆核指出還有 7 個入口零防線:

| # | 入口 | 非法序數的實際後果 |
|---|---|---|
| 1 | `append_record(pair, m, source)` | 步驟 4/5 攔下 |
| 2 | `notify_death(character)` | `has()` 安全,但接著 `_death_marks[非法序數] = _t_now` **靜默寫入非法鍵** |
| 3–5 | 三個讀取函數的 `pair` | `_records[非法序數]` 缺鍵讀取 → **當場中止**(探針 A 實測) |
| 6 | `speculative_read(pair, ...)` | 同上 |
| 7 | `can_write(pair, source)` | 同上;且原簽章回傳 `bool`,**無任何拒絕碼可用** |
| 8 | **`AffinityTypes.pair_of(a, b)`** | 內部固定查表查不到;回傳裸 `Pair`,**結構上無拒絕通道**——見下方 |

**中止比 R7E-4 的靜默寫錯更嚴重**:R7E-4 至少寫進了資料(壞但存在),缺鍵讀取是呼叫端函式**當場停止執行**,而讀取路徑是每回合都會走的熱路徑。

**修法**:

1. **`ReadRejection` 新增 `INVALID_PAIR`**;**`DeathNotifyResult` 新增 `INVALID_CHARACTER`**;**`can_write()` 回傳型別 `bool` → `WriteRejection`**(見機制九)。`WriteRejection` 本身不變(已有 `INVALID_PAIR`/`INVALID_SOURCE`)。
2. **`AffinityDataPool` 內定義三個私有驗證器**,各為一行,**讀 `_init()` 快取而非每次重新呼叫 `.values()`**(`.values()` 每次呼叫都重新配置一個新 `Array`,而四個讀取函數是每回合多次的熱路徑):

```
func _validate_pair_ordinal(pair: AffinityTypes.Pair) -> bool:      return _pair_ordinals.has(pair)
func _validate_character_ordinal(c: AffinityTypes.Character) -> bool: return _character_ordinals.has(c)
func _validate_source_ordinal(s: AffinityTypes.Source) -> bool:     return _source_ordinals.has(s)
```

   **入口 1–7 一律在觸碰任何容器之前**呼叫對應的驗證器。抽成私有函式而非散寫 `.has()` 的理由:同一個檢查出現在 7 處,散寫會重演本專案已被抓過八次的「只修了其中幾處」。
3. **入口 8(`pair_of()`)無法比照** —— 它回傳裸 `Pair`,不可為 null,**結構上容不下拒絕**。已排除的選項與理由:改回傳 `Variant`(違反本次修訂消滅 `Variant` 回傳的方向)、新增 `Pair.INVALID = -1`(會讓 `values().has(-1)` 判為合法,自毀第 2 點)、內部 `push_error()` + 回傳哨兵 `Pair`(違反 Constraints 明文,且靜默產生錯誤配對)。**採用:三個驗證器同時以公開靜態形式掛在 `AffinityTypes` 上,`pair_of()` 明文前置條件。**

```
# affinity_types.gd —— 公開,供 pair_of() 的呼叫端與任何外部使用者預先驗證
static func is_valid_character(c: Character) -> bool   # Character.values().has(c)
static func is_valid_pair(p: Pair) -> bool
static func is_valid_source(s: Source) -> bool
```

`pair_of()` 的前置條件:**呼叫端必須先以 `AffinityTypes.is_valid_character()` 驗證兩個參數。本函式對非法序數的行為未定義。** 已登記 forbidden pattern `unvalidated_character_into_pair_of`。

> **誠實聲明**:入口 8 是**呼叫端義務**,與入口 1–7 的「系統自己擋」**不同級別**。**本 ADR 不宣稱第 8 個入口與前 7 個受同等保護。**
>
> **兩條路徑的一致性義務**:`AffinityTypes.is_valid_*()`(公開靜態,低頻)與 `AffinityDataPool` 內部讀快取的檢查(熱路徑)**語意必須完全相同**。這是「同一個檢查散寫在兩個地方」的形狀,已新增 Validation Criteria 斷言兩條路徑對同一輸入回傳一致結果。

```gdscript
# 2026-08-25 補完:AdvanceRejection/DeathNotifyResult 兩個 enum 全文從未被
# 宣告本體,只被當成回傳型別使用,與 ImportResult 是同一種毛病。成員清單
# 依下列來源逐一蒐齊:
#   - 機制七 advance_campaign_tick() -> AdvanceRejection 宣告旁的註解:
#     「目前僅 SERIALIZATION_WINDOW_ACTIVE 一種拒絕情境」→ AdvanceRejection
#   - 機制七 notify_death() -> DeathNotifyResult 宣告旁的註解:
#     「SERIALIZATION_WINDOW_ACTIVE / DUPLICATE_DEATH_NOTIFICATION」→ DeathNotifyResult 原始兩值
#   - 機制三「陣亡標記表」段落:notify_death() 冪等性拒絕回傳 DUPLICATE_DEATH_NOTIFICATION
#   - 機制四之四「8 個帶 enum 參數的入口統一序數驗證」的修法列表:
#     「DeathNotifyResult 新增 INVALID_CHARACTER」→ 第三個值
#   - 機制七「操作進行中」判準段落:三個寫入方法(含這兩個)皆受
#     SERIALIZATION_WINDOW_ACTIVE 拒絕,確認該值同時屬於兩個 enum
# 維持巢狀於 AffinityDataPool 內(機制二「共用列舉的檔案歸屬」段落已明訂,
# 歸屬不重新決定)。
#
# ⚠️ NONE 是本次補完時的決定,不是對既有事實的推定 —— 這兩個 enum 從未被
# 宣告,本 ADR 是其唯一權威,因此不存在可供推定的既有事實。決定沿用 NONE
# 作為第一個成員,理由:兩者都是拒絕碼型 enum(回答「這次呼叫有沒有被拒
# 絕」),與 WriteRejection/ReadRejection 同型,而該型別在本 ADR 一律以 NONE
# 表示「未被拒絕」。EndTokenResult({ RELEASED, TIMED_OUT_RECLAIMED,
# INVALID_TOKEN })沒有 NONE 並非例外,而是不同型別:它回報的是「發生了什
# 麼」(權杖被正常釋放/被逾時回收/根本不存在),三個值地位對等,沒有一個
# 是「沒事發生」。因此本 ADR 的結果 enum 分兩型:拒絕碼型一律有 NONE,事
# 件回報型沒有。新增結果 enum 時先判斷屬於哪一型,不要套用單一通則。
enum AdvanceRejection {
    NONE,
    SERIALIZATION_WINDOW_ACTIVE,
}

enum DeathNotifyResult {
    NONE,
    SERIALIZATION_WINDOW_ACTIVE,
    DUPLICATE_DEATH_NOTIFICATION,
    INVALID_CHARACTER,          # 2026-08-21 新增(R7-P1 修法的一部分,機制四之四)
}
```

```
func advance_campaign_tick() -> AdvanceRejection   # 目前僅 SERIALIZATION_WINDOW_ACTIVE 一種拒絕情境
func notify_death(character: AffinityTypes.Character) -> DeathNotifyResult   # SERIALIZATION_WINDOW_ACTIVE / DUPLICATE_DEATH_NOTIFICATION
```

**恰兩個方法改變 Delta Log/戰役刻度本身的狀態**(`append_record`、`advance_campaign_tick`),回應 `TR-affinity-010`/AC-1——`notify_death`、`begin_non_atomic_window`、`end_non_atomic_window` 是額外的合法狀態改變方法,但它們改變的是**結構上獨立**的陣亡標記表與權杖集合,不是 AC-1 定義範圍內的「既有記錄(或既有標記)」,不構成對 AC-1 逐字宣稱的違反——這點在 GDD Requirements Addressed 表中進一步說明,以避免下游 QA 誤讀 AC-1 為涵蓋全系統唯二 mutator。

### 機制五:讀取路徑——三個純函數 + 公式四,條件式預設查詢時點

```
class AffinityReadResult extends RefCounted:
    var rejection: ReadRejection = ReadRejection.NONE   # 2026-08-21:必須先檢查此欄位
    var value: float
    var t_query: int
    var n_pair: int
    var diagnostic_visited_count: int  # QA-only,見機制六——業務邏輯不得依賴此欄位

class ShapeFeatureResult extends RefCounted:
    var rejection: ReadRejection = ReadRejection.NONE   # 2026-08-21:必須先檢查此欄位
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

**`t_query` 的型別閘門(2026-08-21 新增,R7E-6,BLOCKING)—— 機制五開頭,先於任何其他運算**:

```
match typeof(t_query):
    TYPE_NIL:   pass          # 走上方的條件式預設查詢時點
    TYPE_INT:   pass          # 繼續後續值域檢查
    _:          return <rejection = INVALID_T_QUERY_TYPE 的結果物件>
```

**實作提醒(2026-08-25,VR#9 探針關閉時的衍生發現,`prototypes/xcheck-adr0002-vr9-vr11-2026-08-24/probe-vr9-match-typeof/`)**:上方三分支 `match` 的 case **順序不可交換**。實測——若把 `_` 預設分支寫在 `TYPE_NIL` 分支**之前**,`null` 會被 `_` 提前吃掉,`TYPE_NIL` 分支變成不可達的死碼,且**引擎既不擋編譯、執行期也不印任何警告**(該檔案編譯成功,log 對 `warn`/`error` 零匹配)。這不是本 ADR 目前寫法的錯誤(`TYPE_NIL`/`TYPE_INT` 兩個具名分支已寫在 `_` 之前),而是**未來任何人重排這段 `match` 時的無聲陷阱**——沒有編譯期或執行期訊號會提醒重排已經改變行為。實作時不應調整這三個 `case` 的先後順序;若確實需要調整,須額外撰寫回歸測試斷言 `combat_strength_read`/`narrative_depth_read`/`shape_feature_read` 對 `t_query = null` 仍走「條件式預設查詢時點」分支,而非落入 `INVALID_T_QUERY_TYPE`。

**明文禁止** `if t_query != null and t_query > _t_now` —— 對 `String` 會在**比較運算子處中止所在函式**(2026-08-20 `XCHECK-4` 實測)。`t_query` 的型別判定**只能用 `typeof()`**:不可用 `!= null`、不可用比較、不可用賦值進型別化變數當檢查。**`TYPE_FLOAT` 一律拒絕**(不接受 `3.0`)——與機制八對 `t`/`c` 嚴格 `TYPE_INT` 的立場一致,理由同 R7-P2:浮點截斷後落入合法範圍會靜默通過所有後續值域檢查,而 `t_query` 決定的是整份 Delta Log 的截止點。

型別通過後,`t_query` 大於目前 `_t_now`(僅適用三個真實讀取函數,不適用公式四)一律視為非法呼叫。

> **🔴 為何這是 BLOCKING**:原文寫「回傳值以 `ReadRejection.FUTURE_TIME_QUERY` 表達(獨立於 `AffinityReadResult`)」,而三個讀取函數宣告回傳 `AffinityReadResult`/`ShapeFeatureResult` —— **一個宣告回傳物件的函式不可能回傳 enum**,`FUTURE_TIME_QUERY` 因此是死碼。且即使可以,那條比較正是本 ADR 自己實測出「對 `String` 中止所在函式」的比較 —— 型別錯誤的 `t_query` 會在比較處中止,永遠走不到拒絕碼。**修法:拒絕改由結果物件上的 `rejection` 欄位承載**(使用者裁決)。

公式四(預判/假設性讀取):

```
class HypotheticalEntry extends RefCounted:
    var source: AffinityTypes.Source
    var m: float

# 2026-08-21:SpeculativeRejection 已刪除,三個值併入下方統一的 ReadRejection(R7E-5:原 NONE 是死碼)
enum ReadRejection {
    NONE,                     # 成功
    INVALID_PAIR,             # pair 序數不在 10 個合法值內(機制四之四)
    INVALID_T_QUERY_TYPE,     # t_query 既非 TYPE_NIL 也非 TYPE_INT
    FUTURE_TIME_QUERY,        # t_query 為 int 但 > _t_now
    EMPTY_HYPOTHETICAL_SET,   # 僅 speculative_read
    DEAD_PAIR_NOT_ALLOWED,    # 僅 speculative_read
}
enum ReadMode { COMBAT, NARRATIVE }

func speculative_read(pair: AffinityTypes.Pair, hypothetical_entries: Array[HypotheticalEntry], mode: ReadMode) -> AffinityReadResult
# 2026-08-21:回傳型別自 Variant 改為 AffinityReadResult,拒絕由其 rejection 欄位承載。
# 原本「呼叫端以型別檢查區分」未指定用什麼區分(R7E-5),且 Variant 回傳與本次修訂的方向相反。
```

- `hypothetical_entries.is_empty()` → `EMPTY_HYPOTHETICAL_SET`(`TR-affinity-022`「呼叫合法性前提」,GDD 明文豁免只在至少一筆假設性記錄時成立)。
- `t_death(pair) != null` → `DEAD_PAIR_NOT_ALLOWED`(GDD 第十一輪裁決:公式四對陣亡配對一律拒絕呼叫,理由是陣亡配對唯一合法的假設性寫入來源本就不改變凍結讀值,拒絕優於「偽成功」)。
- 否則:依序指派嚴格遞增的虛擬 `t_new`(`_t_now+1, _t_now+2, ...`,依 `hypothetical_entries` 陣列順序),`t_query` 內部固定為最後一筆的 `t_new`(呼叫端不得覆寫此值——公式四本身即是「若現在依序打出全部假設性項目」的查詢,`t_query` 由假設性項目數量決定,不是自由參數,這點比 GDD 原文「呼叫慣例」更嚴格收斂,理由是本 ADR 選擇不對外開放看似自由實則有隱藏合法上下限的參數,降低誤用面)。

### 機制五之二:拒絕的回報形狀 —— 逐函數可達性表與哨兵值(2026-08-21 新增)

**每個函數可能回傳哪些 `rejection` 值**(明文列表,確保無死碼 —— 本 ADR 已兩次被抓到死碼:`SpeculativeRejection.NONE` 與 `FUTURE_TIME_QUERY`):

| 函數 | 可能的 `rejection` 值 |
|---|---|
| `combat_strength_read` / `narrative_depth_read` / `shape_feature_read` | `NONE`、`INVALID_PAIR`、`INVALID_T_QUERY_TYPE`、`FUTURE_TIME_QUERY` |
| `speculative_read` | `NONE`、`INVALID_PAIR`、`EMPTY_HYPOTHETICAL_SET`、`DEAD_PAIR_NOT_ALLOWED` |

`speculative_read` 無 `t_query` 參數,故結構上不可能回傳兩個 `t_query` 相關值。**6 個值每一個都在至少一個函數上可達 —— 無死碼。**

**拒絕時其餘欄位的哨兵值** —— **必須按類別分兩張表**(2026-08-21 Step 5.5 兩軌獨立收斂指出:`value` 只存在於 `AffinityReadResult`,`c_now` 只存在於 `ShapeFeatureResult`,修訂初稿把兩者寫在同一句且漏掉 `ShapeFeatureResult` 專屬的 5 個欄位):

**`AffinityReadResult`**

| 欄位 | 哨兵值 |
|---|---|
| `value` | **`NAN`** |
| `t_query` | `-1` |
| `n_pair` | `-1` |
| `diagnostic_visited_count` | `-1` |

**`ShapeFeatureResult`**(11 欄逐一列全)

| 欄位 | 哨兵值 | | 欄位 | 哨兵值 |
|---|---|---|---|---|
| `reversal_count` | `-1` | | `source_absence` | `{}` |
| `source_distribution` | `{}` | | `n_pair` | `-1` |
| `time_distribution` | `null` | | `t_query` | `-1` |
| `source_polarity` | `{}` | | `c_now` | `-1` |
| `total_churn` | **`NAN`** | | `diagnostic_visited_count` | `-1` |
| `segment_profile` | `null` | | `low_confidence` | `null` |

**為何 `value`/`total_churn` 用 `NAN` 而不是 `0.0`**:多筆記錄正負相消時,**成功呼叫**完全可能算出 `0.0`;呼叫端若漏檢 `rejection`,拿到 `0.0` **無法區分「淨值為零」與「被拒絕」**。同理 `diagnostic_visited_count` 用 `-1` 而非 `0` —— `n_pair == 0` 的**成功**呼叫自然就是 `0`。哨兵的設計原則是**讓誤讀在測試中立刻顯現**,因此絕不使用該欄位在成功路徑上也可能出現的值。`NAN` 不是新概念:本 ADR 已在機制四以 `is_nan()` 作為既有語彙。

**為何三個 `Dictionary` 欄位用 `{}` 而不是 `null`**:它們的成功型別是 `Dictionary`(**非雙態**),改成 `null` 會讓下游對它們的 `Dictionary` 操作變成機制四之三之二第 7–9 條那一類的中止風險;空 `Dictionary` 上的 `.has()`/`.get()` 是安全的。**三個雙態欄位維持 `null`**,因為 `null` 本來就是它們的合法成功值之一,下游**本來就必須**做 null 檢查。

**新增呼叫端義務**:**必須先確認 `result.rejection == ReadRejection.NONE`,才可讀取任何其他欄位。**

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
- **逐權杖惰性逾時清除**(`TR-affinity-015`,不使用獨立 `Timer` 節點輪詢):`begin_non_atomic_window`/`end_non_atomic_window`/任一寫入方法呼叫時,先檢查 `_serialization_tokens` 中是否有任何 `issue_time` 早於 `Time.get_ticks_msec() - TOKEN_TIMEOUT_MS`(Tuning Knob;**定值責任自 2026-08-19 C1 起由 ADR-0004 擁有**。⚠️ **2026-08-21 誠實標註**:本機制對 `TOKEN_TIMEOUT_MS` 的引用是 `Depends On: None` 的一個**既存例外**,沿革見 C1 修訂。使用者 2026-08-21 的裁決範圍是「本次新增的比例規則」,**不含這筆舊帳**;本次修訂不處理它,明文記錄於此,避免下一輪把它誤讀為新引入的依賴)的殘留權杖;若有,將其從 `_serialization_tokens` 移除、加入 `_reclaimed_tokens`(短期保留識別碼,供上方 `TIMED_OUT_RECLAIMED` 判斷用)。

> **🔴 2026-08-21 修訂(R7E-14,使用者裁決)——`_reclaimed_tokens` 的次要逾時撤回時間門檻,改為固定容量 FIFO**
>
> 原文寫「`_reclaimed_tokens` 本身也需要一個更長的次要逾時上限以避免無限成長,建議值同樣留待實測,
> **不在本 ADR 定案**」—— 這與 C1(`TOKEN_TIMEOUT_MS`)當初被判為**孤兒義務**的措辭**逐字同構**,而 C1 耗了
> 三輪才把定值責任交給 ADR-0004,且 ADR-0004 只接了那**一個**常數。修訂初稿曾提出
> `RECLAIMED_TOKEN_TTL_MS ≥ 2 × TOKEN_TIMEOUT_MS`,**Step 5.5 覆核判定該推導鏈自我矛盾**
> (宣稱「不需要 ADR-0004 的任何量」,而公式本身以 ADR-0004 擁有的常數為輸入),且 ADR-0004 全文對該常數
> **零命中** —— 那是 C7 的同一形狀。**已整段撤回。**
>
> **新規則(完全不引用任何外部常數)**:`_reclaimed_tokens` 為**固定容量 FIFO**,
> 容量 `RECLAIMED_TOKEN_CAPACITY = 64`,**由本 ADR 擁有**。超出容量時淘汰最舊的已回收 ID。
> **不使用任何時間門檻,因此不引用 `TOKEN_TIMEOUT_MS`。**
>
> ```
> var _reclaimed_tokens: Dictionary[int, bool]   # 只作查找
> var _reclaimed_token_order: Array[int]         # 明確維護插入順序
> # 移入:_reclaimed_tokens[id] = true;_reclaimed_token_order.push_back(id)
> # 溢出:var oldest := _reclaimed_token_order.pop_front();_reclaimed_tokens.erase(oldest)
> ```
>
> **為何需要第二個容器(Step 5.5 覆核發現,三層皆成立)**:(i) `Dictionary` 沒有語言層的 O(1) 出隊;
> (ii) 依賴 `.keys()` 的插入順序需要「`Dictionary` 迭代順序等於插入順序」這個**四支探針零覆蓋的引擎行為**,
> 且 `.keys()` 每次呼叫都重新配置一個新 `Array`,取最舊者變成 O(容量);(iii) **最關鍵** ——
> 權杖被移入 `_reclaimed_tokens` 的時間點是「該次逾時掃描發現它」的時點,**不等於 token id 的大小順序**
> (先發放的權杖可能因為操作真的比較久,比後發放但先逾時的權杖**更晚**被掃進來),
> 所以連「用 key 數值大小近似最舊」這個更便宜的替代方案**也不成立**。
>
> **明確的排序容器讓 FIFO 的正確性完全不依賴 `Dictionary` 的迭代順序** —— 因此那個未查證行為
> **不需要成為本 ADR 的依賴**,也不列入 Verification Required。這與本機制的取鎖模式是**同一個手法**
> (第七輪 `/architecture-review` 把「單一進入點取鎖讓正確性不依賴未查證的 `Mutex` 可重入性」評為
> **全專案處理未查證引擎行為的最佳範例**)。
>
> **`64` 的推導**:本集合的唯一用途是讓「持有已逾時權杖的呼叫方」在下次呼叫 `end_non_atomic_window()` 時
> 得到 `TIMED_OUT_RECLAIMED` 而非 `INVALID_TOKEN`,而這兩個回傳值**對內部狀態的影響完全相同**
> (皆不改變任何狀態、皆非故障結果)—— 區辨的價值是**診斷品質,不是正確性**。因此容量只需覆蓋
> 「實務上可能同時處於已回收狀態的權杖數」,而本機制既有論證已界定 `_serialization_tokens` 的規模上界為
> 「同時存在的非原子視窗發起者數」= 個位數。64 是該上界一個數量級以上的餘裕。
> **溢出的後果明確且良性**:最舊的已回收 ID 被淘汰,對它呼叫 `end_non_atomic_window()` 得到
> `INVALID_TOKEN` 而非 `TIMED_OUT_RECLAIMED` —— **診斷精度下降,資料正確性與狀態一致性不變。**
>
> **對 `TR-affinity-015` 無影響**:`_next_token_id` 仍單調遞增、ID 永不重新發放;`_serialization_tokens`
> 仍逐權杖判斷、非整批清空。FIFO 淘汰的是**已回收 ID 的診斷紀錄**,不是活躍權杖。
>
> **誠實修正一項自陳**:修訂初稿曾寫「機制七因此**少一條路徑**」——**不成立**。正確說法是
> 「**換掉**一條路徑:砍掉了逐權杖的時間門檻掃描,代價是新增一個排序容器」。淨效果是機制更簡單
> (無時間門檻、無外部常數依賴),但**不是純粹的簡化**。`_sweep_timed_out_tokens_unlocked()` 因此
> **只掃 `_serialization_tokens`**,不再掃 `_reclaimed_tokens`。
>
> **`Array.pop_front()` 的複雜度未查證**(推論為 O(n) 搬移)。因容量是固定小常數,
> **本 ADR 不宣稱 O(1) 出隊**,只宣稱「常數上界內的攤還常數成本」。**理由選擇惰性檢查而非專屬 `Timer`**:本系統的讀寫呼叫頻率(每次好感度事件、每次戰役刻度推進)已足夠密集,足以驅動逾時清除,額外常駐一個 `Timer` 節點的 `_process`/訊號成本是不必要的重複開銷,且會讓本系統重新產生「需要掛在場景樹上」的依賴,與機制一的 DI-only 擁有模式衝突。
- **無條件 Mutex 保護**(`TR-affinity-016`):`_serialization_tokens`(以及 `_reclaimed_tokens`)的所有讀寫皆由 `_token_mutex` 保護,不論存檔系統最終選擇同步阻塞式寫入或背景執行緒序列化。**理由**:GDD 條件句「若架構階段選擇背景執行緒序列化,須明確以 Mutex 保護」把決定權交給本 ADR,而存檔系統執行模型 ADR 尚未撰寫——若本 ADR 選擇「條件式加 Mutex」,等於讓本 ADR 的並發正確性論證懸空等待一個尚未存在的 ADR,且未來若真的選擇背景執行緒,需要回頭修改本 ADR 與已寫好的程式碼。無條件加 Mutex 的成本可忽略(集合規模上界是「同時存在的非原子視窗發起者數」,遠小於 Delta Log),換來的是本 ADR 現在就能宣告完整、不需要任何未來的條件式修訂。

**2026-08-19 修訂 —— C3 銜接缺口:條件已解,但保留為縱深防禦**(第二輪 `/architecture-review` 提出,第三、四輪重申仍開):`TR-affinity-016` 是**條件式**需求(「**若**架構階段選擇背景執行緒序列化,須明確以 `Mutex` 保護」)。該條件此後已由 **ADR-0004 判為「否」**——`SaveIOBackend` 的現行實作為**同步阻塞式**,不引入任何背景執行緒,且該 ADR 明文加上主執行緒斷言。因此本節原本的措辭「**全專案唯一已宣告的執行緒安全義務**」現在容易被誤讀為「專案內存在跨執行緒競爭」——實際上**目前不存在**。

**決策不變:`Mutex` 保留,理由改為縱深防禦而非必要性。** 理由:(i) 移除它需要修改本 ADR 與未來已寫好的程式碼,而 ADR-0004 的 `SaveIOBackend` **本來就是為了將來可替換而設計的抽象**(該 ADR 明文把主機 SDK 的非同步 I/O 列為未解決的 Open Question 9);若日後替換為背景執行緒實作,`Mutex` 已在位。(ii) 保留的成本可忽略(見上),移除的收益趨近於零,而移除後再加回來要重新推導一次並發正確性論證。**但本 ADR 不再宣稱這是「已成立的執行緒安全義務」——它是一個目前無競爭對手的鎖。** 見 `docs/architecture/adr-0004-save-system-atomic-write-and-migration-execution-model.md` 機制五/`SaveIOBackend`。
- **鎖定模式:單一進入點取鎖,逾時清除以「假設已持鎖」的私有輔助函式實作**(2026-08-18 `godot-specialist` 驗證發現,回應對「機制七是否會有巢狀 `lock()` 呼叫」的查核)——`begin_non_atomic_window`/`end_non_atomic_window`/每個寫入方法皆在**公開進入點**呼叫一次 `_token_mutex.lock()`,惰性逾時清除邏輯抽成私有的 `_sweep_timed_out_tokens_unlocked()`,**只假設鎖已持有、自己絕不呼叫 `lock()`/`unlock()`**,只能從已持鎖的區塊內呼叫。**理由**:`godot-specialist` 2026-08-18 查核時**當時認定**本專案無 Godot 執行環境可實測(⚠️ **該前提已於 2026-08-20 被推翻** —— 見上方 Engine Compatibility 表 Verification Required 第 4 項:Godot 4.7.1 可在本機 headless 執行,本項未關閉的原因已改為「尚未撰寫該探針」,不是不能測)、亦無對應模組參考文件,無法確認 4.7.1 的 `Mutex` 是否為可重入鎖(同執行緒重複 `lock()` 是否死結)——訓練資料傾向判斷是可重入,但這是**未經專案驗證**的假設(見上方 Engine Compatibility 表 Verification Required 第 4 項)。此鎖定模式讓正確性**不依賴這個未驗證的答案**:不論 `Mutex` 是否可重入,「只有一個地方真正呼叫 `lock()`」的設計都不會死結,也不會在得知答案前留下一個可能錯的假設。
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
    # 2026-08-21(修正 D):本方法是**公開靜態**方法,任何呼叫方可直接呼叫並繞過
    # validate_semantics() → import_state() 的兩段式契約。因此防線放在方法自己內部:
    # 2026-08-25 補強(管理者裁決,補檢查而非禁止外部呼叫):呼叫共用的
    # check_record_fields(d)(見機制八之二),涵蓋鍵集合、pair/source 名稱、
    # m/t/c 型別五類檢查;任一失敗**回傳 null**(而非中止,失敗語意與名稱
    # 非法時一致,不新增第二種失敗語意),呼叫端須檢查。
    # 與 validate_semantics() 的關係:兩者共用同一份 check_record_fields()
    # 邏輯,不是各自維護一份同義判斷——validate_semantics() 逐筆呼叫它,
    # 自己只額外負責 check_record_fields() 管不到的頂層鍵集合、m/t/c 值域、
    # death_marks/campaign_tick_marks 容器級檢查、5 條跨結構不變量。
    # 不依賴呼叫方一定先跑 validate_semantics()。
```

**回填修訂(2026-08-18,ADR-0003「存檔系統序列化格式與型別安全」新增要求)**:新增公開的 `validate_semantics()` 純函式,將原本內嵌於 `import_state()` 的驗證邏輯抽出、不再與「替換內部狀態」這個副作用綁死。**理由**:存檔系統的遷移執行模型(尚待撰寫的下一份 ADR)需要對遷移函數鏈的輸出做語意驗證(`save-system.md` Core Rules #7「語意驗證同樣套用於遷移函數的輸出」),但遷移鏈執行期間的中繼 `Dictionary` 不必然對應一個要被替換的 `AffinityDataPool` 活體實例——需要一個不觸發狀態替換副作用的純驗證呼叫,供存檔系統的 `SaveBlockRegistry`(ADR-0003 機制六)登記為本系統的驗證器。此修訂不改變任何既有資料結構、並發機制或已定案的錯誤分類,`import_state()` 對外行為(輸入/輸出/失敗語意)完全不變,純粹是內部重構為「先驗證、通過才替換狀態」的兩段式實作。**本 ADR 的 Proposed 狀態下修訂自身尚未實作的 Key Interfaces 屬正常的同波共同開發流程**,不同於修改已 Accepted 或已被下游程式碼消費的決策。

- `pair`/`source` 一律以**字串名稱**持久化,直接滿足 `TR-affinity-018`。**轉換方式(2026-08-18 `godot-specialist` 驗證發現修訂)**:正向轉換(enum → 字串)使用 `AffinityTypes.Pair.find_key(pair_value)`(GDScript enum 在執行期以類 `Dictionary` 物件呈現,`find_key()` 做的是**依值查鍵**,不受成員排列順序或未來是否出現非連續數值影響);反向轉換(字串 → enum)**必須先 `AffinityTypes.Pair.keys().has(name_string)` 做存在性檢查,通過後才 `AffinityTypes.Pair[name_string]`**(2026-08-21 明訂,R7-P3:原文寫「以 `values().has(...)` 風格的檢查 guard」——`values()` 檢查的是**序數**,`keys()` 檢查的才是**名稱**,兩者不可互換;且「風格」這個措辭不足以構成規則)。**不採用**原草稿描述的「依 `keys()[pair]` 位置索引」寫法——那是位置查找,一旦列舉成員未來被指派非連續或重新排列的底層數值就會靜默出錯,`find_key()`/`enum[name]` 的依值/依鍵查找沒有這個風險。**「退役名稱永久保留、不得重新指派」的治理規則與 CI 檢查本身,依 GDD Dependencies 明文屬於存檔系統的職責**(「並由存檔系統維護『字串名稱↔目前 enum 定義』的對照表」)——本 ADR 只負責提供穩定的字串轉換原語(`to_dict`/`from_dict`),不建立獨立的退役名稱登記機制,避免與存檔系統的既有機制重複實作。**已考慮並拒絕的內建替代方案**:Godot 提供 `inst_to_dict()`/`dict_to_inst()` 可自動將 `Object` 衍生實例的屬性轉為/還原自 `Dictionary`,但它會把 enum 欄位序列化成原始 `int`(而非 `TR-affinity-018` 要求的字串名稱),且還原時內嵌腳本路徑依賴——與本 ADR 刻意追求的「格式無關、enum 以字串名稱持久化」需求不符,故不採用,改以手寫 `to_dict()/from_dict()` 逐欄位轉換。
- **反序列化語意驗證規則,本系統為唯一權威**(`TR-affinity-019`,直接對應 GDD「反序列化語意驗證規則宣告」章節):`import_state()` 內部依序執行——
  1. **逐欄位型別 + 值域**(2026-08-20 實機驗證後擴充)——**必須先以 `typeof()` 內省確認型別,通過後才允許賦值或做任何值域運算。順序不可顛倒,檢查手段不可代換**(**2026-08-25 收窄措辭,避免假警報**:此規則指**對任一欄位,該欄位的 `typeof()` 檢查必須排在對該欄位的任何值域運算之前**;欄位與欄位之間**不要求**排序——`check_record_fields()` 先查 `pair`/`source` 的型別與名稱、再查 `m`/`t`/`c` 的型別,是實作選擇的欄位順序,不構成違規。原規則的理由與下方的『操作 / `Variant` 實際持有錯誤型別時 / 判定』實測表**不變、不撤回任何一項結論**,本次只收窄描述範圍。`docs/registry/architecture.yaml` 的 `forbidden_patterns` 目前沒有任何一項編碼「型別先於值域」這個順序規則,故此處收窄不與登記表衝突):
     - **型別**(以 `typeof(raw)` 比對 `Variant.Type` 常數,**不可用賦值當檢查**):**頂層 `data` 須恰含 3 個鍵**(`records`/`campaign_tick_marks`/`death_marks`)——**缺鍵或多鍵皆回傳結構化失敗**(2026-08-21 新增,R7E-9:原文只對 `records` 的元素寫了「恰含這 5 個鍵」,頂層完全未驗,而缺 `death_marks` 即是缺鍵存取,與 R7E-2 同類);`pair`/`source` 為 `TYPE_STRING`;**`m` 嚴格為 `TYPE_FLOAT`,不接受 `TYPE_INT`**(2026-08-21 明訂,R7E-10);**`t`/`c` 必須嚴格為 `TYPE_INT`——不可寬鬆到「`int` 或 `float` 皆可」**;`records` 為 `TYPE_ARRAY` 且每個元素為 `TYPE_DICTIONARY`、恰含這 5 個鍵;`campaign_tick_marks` 為 `TYPE_ARRAY` 且每個元素為 `TYPE_INT`;`death_marks` 為 `TYPE_DICTIONARY` 且鍵為 `TYPE_STRING`、值為 `TYPE_INT`。

       > **`m` 為何嚴格 `TYPE_FLOAT`(R7E-10)**:`export_state()` 的唯一生產者是 `AffinityRecord.m: float`(靜態型別),而 `var_to_bytes()` 保留 `Variant` 型別 —— 因此**任何合法存檔的 `m` 必為 `TYPE_FLOAT`**;還原後為 `TYPE_INT` 只可能來自人工編輯或位元損壞,**拒絕是正確行為**。不放寬為「int 或 float 皆可」,方向與 `t`/`c` 一致。
       > ⚠️ **此前提繼承自 ADR-0003 的二進位 Variant 序列化決策,而該 ADR 自陳該 API 家族為 Knowledge Risk HIGH 且未把型別往返保真列入其 Verification Required**(見本 ADR VR #12)。**本 ADR 不宣稱該前提已查證**,只登記依賴,不代為記帳。
     - **值域**(僅在型別檢查通過後執行):`pair`/`source` 為合法列舉名稱;**`death_marks` 的鍵為合法 `Character` 列舉名稱**(2026-08-21 新增,R7E-8);`m` 非零且有限;`t ≥ 1`;`c ≥ 0`;陣亡標記表值 `≥ 0`。

     > **R7E-8 的失敗位置為何嚴重**:原型別清單只驗到「鍵為 `TYPE_STRING`」,值域清單只有 `pair`/`source` 的名稱檢查,**`Character` 名稱缺席** —— 於是一個含非法角色名的表會通過 `validate_semantics()` **全部**檢查,到 `import_state()` 實際重建走 `AffinityTypes.Character[name]` 才失敗,**而那已在「驗證通過、開始替換內部狀態」之後**,直接違反機制八自己的兩段式契約。純清單漏一行,但失敗落在本 ADR 花最多力氣保護的那條邊界**內側**。

     **名稱轉換的形狀規則(2026-08-21 新增,R7-P3 —— 措辭必須點名形狀,不能只點名輸入來源)**:

     > **禁止形狀**:對任何來自存檔的字串**裸用** `AffinityTypes.Pair[name]` / `Character[name]` / `Source[name]`。動態非法字串索引是**執行期中止**(探針 C 實測),`validate_semantics()` 會在走到自己的拒絕碼邏輯**之前**就中止,契約承諾的結構化 `ImportResult` **永遠回不去**。
     >
     > **許可形狀(三條,皆已實測)**:`keys().has(name)` 先做存在性檢查(探針 D:非法名**乾淨回傳 `false`**,字面量與執行期動態組出**兩形同行為**);或 `find_key(value)` 反向查找(探針 C:值不存在時**乾淨回傳 `null`**);或 `values().has(ordinal)` 檢查序數(探針 D:越界輸入**乾淨回傳 `false`**)。
     >
     > **為何必須點名形狀**:探針 D 量到同一個非法名字串,走 `.has()` **方法呼叫**與走 `[]` **subscript** 是**兩種完全不同的命運** —— subscript 是 Parse Error(字面量)或函式中止(動態),方法呼叫**兩形皆編譯通過並回傳 `false`**。「不對不可信字串裸用 `Pair[name]`」禁的是**形狀**,「改用 `keys().has()` 先檢查」給的是**替代形狀**,**兩句都必須寫**,不是同一件事的兩種說法。
  2. 跨結構不變量 1—5(Delta Log 非空則標記列表非空;`c_i ≤ c_now`;全域 `t_i` 不重複且嚴格遞增;`n(p)=0` 哨兵不與非零筆數混淆;陣亡標記值不大於還原後 `t_now`)

  **為何型別與值域必須分成兩件事、且型別檢查只能用 `typeof()`**(2026-08-20 實機驗證,`XCHECK-4`):初版只寫「值域」,那在 ADR-0003 選定**二進位 Variant 序列化**(`bytes_to_var(bytes, false)`)之後不再足夠——該格式只擋自訂 `Object`,**任意內建型別都可被還原**,因此 `m` 可能還原成 `String`、`t` 可能還原成 `float`。實測結果:

  | 操作 | `Variant` 實際持有錯誤型別時 | 判定 |
  |---|---|---|
  | `is_finite(v)` / `is_nan(v)` / `is_inf(v)`,`v` 為 `String` | **SCRIPT ERROR + 所在函式中止**(`Invalid type in utility function … Cannot convert argument 1 from String to float.`) | 不可先做 |
  | `v == 0.0` / `v >= 1`(比較運算子),`v` 為 `String` | **同樣中止**(`Invalid operands 'String' and 'float'/'int' in operator`)。⚠️ **「比較運算子比較安全」是錯的假設,已被實測推翻**——沒有任何操作會對 `String` 誤配靜默回傳 `false` | 不可先做 |
  | `var t: int = raw`,`raw` 為 `float 1.5` | **不中止、不報錯、靜默截斷為 `1`** | ⚠️ **唯一一種「不出錯但也不安全」的情況** |

  **第三列是本次修訂最關鍵的一項發現**,它同時否定了兩種看似可行的寫法:(i) 不能用「賦值進型別化變數、指望賦值失敗當型別檢查」——賦值對 `String` 會中止、對 `float` 則靜默截斷,兩種都不是可判斷的檢查;(ii) `t`/`c` 的型別檢查不能寬鬆到「`int` 或 `float` 都算過」,否則存檔裡一個 `1.5` 會被靜默變成 `1`,而 `t` 是 Delta Log 的全域排序鍵——截斷會直接違反跨結構不變量 3(`t_i` 不重複且嚴格遞增),且違反的方式是**已經寫進內部狀態之後**才顯現。

  **中止的傳染範圍**:實測只影響直接執行該操作的函式,不往上層傳染。因此把每一項檢查放在 `validate_semantics()` 內是安全的——但那正是為什麼**不能靠中止當防線**:中止是無回傳值的失敗,而本方法的契約是回傳結構化 `ImportResult`。**先 `typeof()`** 讓每一種損壞都落在 `ImportResult` 裡,而不是變成一次未分類的執行期中止。

  **與 ADR-0003 的分工,範圍限定為存檔系統的正常讀取管線**(2026-08-25;原文「結構上不可能被產生」的用詞形狀與 `docs/consistency-failures.md` 2026-08-21 條目記錄的同型失誤——ADR-0004 草稿主張某機制「結構上不可能被實例化」,被 Step 5.5 抓出探針只測了直接構造路徑——是同一種錯):ADR-0003 的格式選擇(引擎原生解碼閘門 + 機制一之二 `SaveTypeGate`,拒絕集合 `{23,24,25,26}`)讓「`Object`/`RID`/`Callable`/`Signal` 四種型別」**在經由 `SaveFormat.deserialize_*() → SaveTypeGate` 這條存檔系統管線時**結構上不可能通過抵達本系統——那擋掉的是跨型別家族的注入(不分內建/自訂)。**這是存檔系統管線提供的架構保證,不是引擎層級的結構保證**:`SaveTypeGate` 是 ADR-0003 自寫的遞迴掃描器,其正確性本身依賴人工紀律(ADR-0003 機制一之二明文:「任何遞迴呼叫一律呼叫 `_walk()`,絕不可呼叫 `_walk_body()`」)。

  **本 ADR 自己就示範了不經過這條管線的入口**:`AffinityRecord.from_dict()` 是公開靜態方法,任何呼叫方可直接呼叫並繞過 `validate_semantics()` → `import_state()` 的兩段式契約,因此也完全不經過 `SaveTypeGate`(見機制八的 `from_dict()` 型別防線)。「四種型別結構上不可能抵達本系統」這句話只在存檔系統管線這一條路徑上成立,對 `from_dict()` 這條路徑本來不成立。

  本項(欄位級型別錯配檢查)擋的是**通過該四型別閘門之後、仍在合法內建型別範圍內的欄位級型別錯配**(如 `m` 應為 `TYPE_FLOAT` 卻還原成 `TYPE_STRING`)與**靜默截斷**,且在 `from_dict()` 補強之後,**對本 ADR 目前登記的兩條入口(存檔管線 / `from_dict()` 直接呼叫)成立;新增第三條入口時本句需重新評估**,兩者互補,不重疊。

  ⚠️ 本段對 ADR-0003 `SaveTypeGate`/機制一之二的具體點名,不構成 `Depends On` 意義的依賴——完整論證見 ADR Dependencies 的 `Ordering Note`,此處不重複第三份論證。

  **重建 `_records` 時一律經型別化邊界**:`from_dict()` 產出 `AffinityRecord` 後,以 `_records[pair].append(record)` 寫入(**先預填 10 對空 list,再逐筆 `append()`** —— 見機制二),其中 `pair` 必須是由字串名稱**先經 `keys().has(name)` 存在性檢查、通過後**才轉換的列舉值(**絕不裸用 `Pair[name]`**,見上方形狀規則)——**不得**把還原自存檔的原始 `Variant` 直接當作 subscript 鍵(見機制四之二的兩條邊界規則與 registry 的 `raw_variant_subscript_into_typed_container`)。**存檔還原是唯一一條「外來資料進入 `_records`」的路徑,層三空隙在這裡的暴露面最大。**

  任一檢查失敗回傳結構化 `ImportResult`(標明失敗的具體規則),對應存檔系統 `SEMANTIC_VALIDATION_FAILED` 路徑的輸入。**本方法回傳的失敗結果與 `append_record()` 等寫入端拒絕規則是兩個不同層級的檢查**(GDD「範圍聲明」段落已明訂),不共用同一個錯誤碼列舉,避免呼叫端誤判兩種來源的驗證失敗為同一件事。
- **容器格式本身由存檔系統 ADR 決定**:`export_state()`/`import_state()` 只交換通用 `Dictionary`,不論存檔系統最終選 `Resource`/`.tres`、JSON 或自訂二進位,只需在其序列化層外包一次 `Dictionary ↔ 目標格式` 的轉換,不需要碰觸本系統內部。

### 機制八之二:`ImportResult` 型別宣告

```gdscript
# ─── import_result.gd ────────────────────────────────────────
# 2026-08-24 補完:此型別先前只被兩處方法簽章引用(見機制八),
# 本體從未被宣告。亦為 ADR-0003 機制六 SaveBlockRegistry 的通用驗證器回傳
# 型別(任何向該登記表註冊驗證器的系統皆可回傳同一型別,不限本系統)。
class_name ImportResult extends RefCounted

# 粗粒度分類——刻意跨系統通用,不編碼任何單一系統專屬的規則名稱。
# 「哪一條具體規則」由 rule_id 承載(見下方),不由本列舉承載。
enum Rejection {
    NONE,                                  # 驗證通過
    STRUCTURE_KEY_MISMATCH,                # 容器的鍵集合不符預期(缺鍵或多鍵)
    FIELD_TYPE_MISMATCH,                   # 逐欄位型別檢查失敗(typeof() 不符預期)
    FIELD_VALUE_OUT_OF_RANGE,              # 逐欄位值域檢查失敗(型別正確但值不合法)
    CROSS_STRUCTURE_INVARIANT_VIOLATED,    # 跨結構不變量檢查失敗
}

var rejection: Rejection = Rejection.NONE

# 命名空間化的規則識別碼(如 "affinity.invariant.tick_exceeds_now")。
# 僅供測試精確斷言「是哪一條規則」與診斷輸出使用——
# 呼叫端的程式邏輯分支一律只依 rejection 判斷,不得依 rule_id 判斷。
# 成功時為空字串。
var rule_id: String = ""

# 人類可讀定位字串(如 "records[3].m"、"death_marks['CHARACTER_9']")。
# 純診斷用途,不作為程式判斷依據。成功時為空字串。
var offending_path: String = ""

# 人類可讀說明,純診斷用途,不作為程式判斷依據。成功時為空字串。
var detail: String = ""

func ok() -> bool:
    return rejection == Rejection.NONE
```

`AffinityDataPool` 自己的規則識別碼(定義於 `affinity_data_pool.gd`,不進 `import_result.gd`——這正是兩層設計要達成的擁有權分離):

```gdscript
# 於 affinity_data_pool.gd 內,供 validate_semantics() 內部使用:
const RULE_TOP_LEVEL_KEY_COUNT := "affinity.structure.top_level_key_count"
const RULE_RECORD_KEY_COUNT := "affinity.structure.record_key_count"
const RULE_DEATH_MARK_CHARACTER_NAME := "affinity.value.invalid_death_mark_character_name"
const RULE_INVARIANT_MARKS_EMPTY_WITH_RECORDS := "affinity.invariant.marks_empty_with_records"
const RULE_INVARIANT_TICK_EXCEEDS_NOW := "affinity.invariant.tick_exceeds_now"
const RULE_INVARIANT_TIMESTAMP_NOT_STRICT := "affinity.invariant.timestamp_not_strictly_increasing"
const RULE_INVARIANT_COUNT_SENTINEL_CONFUSED := "affinity.invariant.count_sentinel_confused"
const RULE_INVARIANT_DEATH_MARK_EXCEEDS_NOW := "affinity.invariant.death_mark_exceeds_now"
```

**架構張力與兩層式設計的理由**:機制八要求失敗要標明具體規則,而 ADR-0003 機制六把 `ImportResult` 定位成跨系統共用的驗證器回傳型別——`SaveBlockRegistry` 任何未來的區塊擁有者都回傳同一個 `ImportResult`。若 `Rejection` 列舉塞滿 Affinity 系統專屬的規則名,未來無關的系統要嘛硬塞進一個語意不合的既有值,要嘛得回頭改 `import_result.gd` 這個不屬於它的檔案。解法:`Rejection` 列舉保持粗粒度、跨系統通用,精確到「哪一條具體規則」交給命名空間化的 `rule_id` 字串,由各擁有系統自己定義自己的常數。`rule_id` 只供測試斷言與診斷輸出讀取,呼叫端的程式分支邏輯只能依 `rejection` 判斷。

**與其他型別的關係,四層失敗回報堆疊**(彼此不共用列舉):

```
SaveTypeGate.GateRejection     ← ADR-0003 機制一之二,解碼樹遞迴走訪,擋 {23,24,25,26}
SaveFormat.ReadRejection       ← ADR-0003 機制三,區塊級格式/雜湊失敗
ImportResult.Rejection         ← 本 ADR 機制八,單一區塊擁有者的語意驗證
(ADR-0004 尚待撰寫的更高層碼)  ← 上方非 NONE 一律粗化為 SEMANTIC_VALIDATION_FAILED

AffinityDataPool.WriteRejection ← 完全無關的另一條路徑:即時執行期 append_record() 呼叫
```

`ImportResult.Rejection` 與 `AffinityDataPool.WriteRejection` 是兩個獨立宣告的 enum**型別**,滿足機制八「本方法回傳的失敗結果與 `append_record()` 等寫入端拒絕規則是兩個不同層級的檢查⋯不共用同一個錯誤碼列舉」這條規則——**這裡的「不共用」指的是型別身分不可混用,不是要求成員名稱零重複**。`NONE` 這個名稱在 `WriteRejection`(機制四)、`ReadRejection`(機制五)、`ImportResult.Rejection`、`RecordFieldCheck` 中重複出現,是本 ADR 結果型別的通用命名慣例,**不違反**上述規則的要求;⚠️ 但**不是全部**結果型別都有 `NONE`——`EndTokenResult`(機制七:`{ RELEASED, TIMED_OUT_RECLAIMED, INVALID_TOKEN }`)沒有,`AdvanceRejection`/`DeathNotifyResult`(見機制七之二補完)採 `NONE` 是本次補完時的**決定**,不是推定——判準是「拒絕碼型 vs 事件回報型」(見機制七之二的說明),不是逐一猜測。**不應假設本 ADR 所有結果 enum 都有 `NONE`,先判斷屬於哪一型,不要套用單一通則。**

**單筆記錄的欄位合法性檢查**(由 `from_dict()` 與 `validate_semantics()` 的逐筆記錄檢查兩處共同呼叫,規則只在這裡定義一次):

```gdscript
# ─── affinity_record.gd(新增部分)─────────────────────────
class_name AffinityRecord extends RefCounted
# ...既有欄位不變...

enum RecordFieldCheck {
    OK,
    RECORD_KEY_MISMATCH,   # 該筆記錄的鍵集合不恰為 {pair,m,t,c,source} 五個(缺鍵或多鍵)
    INVALID_PAIR_TYPE,     # pair 不是 TYPE_STRING
    UNKNOWN_PAIR_NAME,     # pair 是 String 但不是合法 Pair 列舉名稱
    INVALID_SOURCE_TYPE,   # source 不是 TYPE_STRING
    UNKNOWN_SOURCE_NAME,   # source 是 String 但不是合法 Source 列舉名稱
    INVALID_M_TYPE,        # m 不是 TYPE_FLOAT
    INVALID_T_TYPE,        # t 不是 TYPE_INT
    INVALID_C_TYPE,        # c 不是 TYPE_INT
}

static func check_record_fields(d: Dictionary) -> RecordFieldCheck:
    if d.size() != 5 or not (d.has("pair") and d.has("m") and d.has("t") and d.has("c") and d.has("source")):
        return RecordFieldCheck.RECORD_KEY_MISMATCH
    if typeof(d.get("pair")) != TYPE_STRING:
        return RecordFieldCheck.INVALID_PAIR_TYPE
    if not AffinityTypes.Pair.keys().has(d.get("pair")):
        return RecordFieldCheck.UNKNOWN_PAIR_NAME
    if typeof(d.get("source")) != TYPE_STRING:
        return RecordFieldCheck.INVALID_SOURCE_TYPE
    if not AffinityTypes.Source.keys().has(d.get("source")):
        return RecordFieldCheck.UNKNOWN_SOURCE_NAME
    if typeof(d.get("m")) != TYPE_FLOAT:
        return RecordFieldCheck.INVALID_M_TYPE
    if typeof(d.get("t")) != TYPE_INT:
        return RecordFieldCheck.INVALID_T_TYPE
    if typeof(d.get("c")) != TYPE_INT:
        return RecordFieldCheck.INVALID_C_TYPE
    return RecordFieldCheck.OK
```

**`RecordFieldCheck` → `ImportResult.Rejection` 對應表**:

| `RecordFieldCheck` 值 | → `ImportResult.Rejection` | `rule_id` |
|---|---|---|
| `RECORD_KEY_MISMATCH` | `STRUCTURE_KEY_MISMATCH` | `RULE_RECORD_KEY_COUNT` |
| `INVALID_PAIR_TYPE` | `FIELD_TYPE_MISMATCH` | (空,由 `offending_path` 定位) |
| `UNKNOWN_PAIR_NAME` | `FIELD_VALUE_OUT_OF_RANGE` | (空) |
| `INVALID_SOURCE_TYPE` | `FIELD_TYPE_MISMATCH` | (空) |
| `UNKNOWN_SOURCE_NAME` | `FIELD_VALUE_OUT_OF_RANGE` | (空) |
| `INVALID_M_TYPE` | `FIELD_TYPE_MISMATCH` | (空) |
| `INVALID_T_TYPE` | `FIELD_TYPE_MISMATCH` | (空) |
| `INVALID_C_TYPE` | `FIELD_TYPE_MISMATCH` | (空) |

`OK` 不需要對應列(成功不產生 `Rejection`),故本表為 8 列,對應 `RecordFieldCheck` 的 8 個非 `OK` 值。

`check_record_fields()` 管不到、由 `validate_semantics()` 自己額外負責的部分(**此表現在與機制八「逐欄位型別+值域」段落逐項對應,無遺漏**):

| 檢查 | → `ImportResult.Rejection` | `rule_id` |
|---|---|---|
| 頂層 3 鍵不符(`records`/`campaign_tick_marks`/`death_marks`,缺鍵或多鍵) | `STRUCTURE_KEY_MISMATCH` | `RULE_TOP_LEVEL_KEY_COUNT` |
| `records` 不為 `TYPE_ARRAY` | `FIELD_TYPE_MISMATCH` | (空,`offending_path` = `"records"`) |
| `records` 某元素不為 `TYPE_DICTIONARY` | `FIELD_TYPE_MISMATCH` | (空,`offending_path` = `"records[i]"`) |
| `campaign_tick_marks` 不為 `TYPE_ARRAY` | `FIELD_TYPE_MISMATCH` | (空,`offending_path` = `"campaign_tick_marks"`) |
| `campaign_tick_marks` 某元素不為 `TYPE_INT` | `FIELD_TYPE_MISMATCH` | (空,`offending_path` = `"campaign_tick_marks[i]"`) |
| `death_marks` 不為 `TYPE_DICTIONARY`,或其鍵不為 `TYPE_STRING`,或其值不為 `TYPE_INT` | `FIELD_TYPE_MISMATCH` | (空,`offending_path` = `"death_marks"` 或 `"death_marks[key]"`) |
| `m` 非零且有限 / `t ≥ 1` / `c ≥ 0`(型別檢查通過後的值域,三個子檢查合併一列) | `FIELD_VALUE_OUT_OF_RANGE` | (空,`offending_path` = `"records[i].m"`/`.t`/`.c`) |
| `death_marks` 鍵非法角色名 | `FIELD_VALUE_OUT_OF_RANGE` | `RULE_DEATH_MARK_CHARACTER_NAME` |
| 陣亡標記表值 `≥ 0` | `FIELD_VALUE_OUT_OF_RANGE` | (空,`offending_path` = `"death_marks[key]"`) |
| 跨結構不變量 1–5 | `CROSS_STRUCTURE_INVARIANT_VIOLATED` | 對應 5 個 `RULE_INVARIANT_*` |

**明文維護義務**:新增 `RecordFieldCheck` 值或新增機制八的欄位/容器層檢查時,必須同時在本兩張表新增對應列——這兩張表、`check_record_fields()`、`ImportResult.Rejection`、機制八「逐欄位型別+值域」的散文,是同一組事實的四種呈現,任一處變更未同步即視為未完成。

### 機制九:全作用域封鎖成因登記處——維持文件層,提供窄範圍執行期查詢(部分升級)

`TR-affinity-023` 要求架構階段決定 GDD 中「全作用域封鎖成因登記處」(目前列出唯一一項:配對中任一成員陣亡 → 該配對的 `combat_card` 來源永久不可寫入)是否升級為執行期可查詢的 API。**本 ADR 的決定:不建立涵蓋全作品範圍、跨系統的通用查詢 API,但提供一個窄範圍、僅涵蓋本系統自身已知封鎖成因的執行期判斷式**:

```
func can_write(pair: AffinityTypes.Pair, source: AffinityTypes.Source) -> WriteRejection
# 2026-08-21(機制四之四):回傳型別自 bool 改為 WriteRejection —— bool 沒有地方表達「參數序數本身非法」。
# 語意:回傳 append_record(pair, <任意合法 m>, source) 若立即呼叫會得到的拒絕碼(NONE 代表可寫)。
# （不含 SERIALIZATION_WINDOW_ACTIVE——那是暫時性狀態，非本判斷式的目的）
```

**`can_write()` 的可達性表(2026-08-21 新增)—— 7 個 `WriteRejection` 值裡有 3 個對本函數結構上不可達**:

| 值 | 對 `can_write()` 可達? |
|---|---|
| `NONE` | ✅ |
| `INVALID_PAIR` / `INVALID_SOURCE` | ✅(機制四之四的序數驗證) |
| `DEAD_PAIR_COMBAT_CARD_FORBIDDEN` | ✅(本系統已知唯一封鎖成因) |
| `SERIALIZATION_WINDOW_ACTIVE` | ❌ **語意排除** —— 暫時性狀態,非本判斷式的目的 |
| `ZERO_AMPLITUDE` | ❌ **結構上不可達** —— 該檢查依賴 `m`,而 `can_write()` **沒有 `m` 參數** |
| `NON_FINITE_AMPLITUDE` | ❌ **同上** |

> **為何必須列這張表**:Step 5.5 覆核**兩軌獨立收斂**指出 —— 修訂初稿只寫了排除 `SERIALIZATION_WINDOW_ACTIVE` **一個**,漏了另外兩個。讀者看到 `-> WriteRejection` 會合理假設 7 值皆可能,實際只有 4 個;呼叫端可能寫出 `WriteRejection.ZERO_AMPLITUDE:` 這種**永遠不會命中的分支**。這與 R7E-5(`SpeculativeRejection.NONE` 死碼)是**同一形狀**,而本次修訂正在消滅那個形狀 —— 若不列表,等於在關掉一個死碼的同一份修訂裡新開三個。本表沿用機制五之二為四個讀取函數建的同一種模板。

**理由**:GDD 該登記處本身明文承認「目前僅通過文字適配檢驗,尚無第二個真實實例」——在只有一個已知封鎖成因、且該成因已是本系統 `append_record()` 內部驗證邏輯自然涵蓋的情況下,建立一個涵蓋「全作品範圍、跨未來系統」的通用註冊表/查詢 API 是對假設性未來需求的過度工程化(YAGNI)。`can_write()` 提供的是「呼叫方(例如 UI 想預先判斷某個動作是否會被拒絕、或未來的敘事解鎖系統想確認某來源是否已被結構性封死)不需要真的嘗試寫入就能查詢」的窄範圍能力,對現有唯一已知成因(陣亡)已經足夠。**若未來真的出現第二個獨立成因**(例如角色離隊、限定道具鎖定),應在該成因對應的系統設計時重新評估是否需要升級為跨系統的通用登記處查詢 API——本 ADR 不預先關閉這個路徑,只是不在只有一個實例時就建。

## Architecture Diagram

```
                    ┌───────────────────────────────────────────────┐
                    │           AffinityDataPool(DI 注入)            │
                    │                                                │
                    │  _records: Dictionary[AffinityTypes.Pair,       │
                    │             AffinityRecordList]                │
                    │             └─ _items(私有;經 append/    │
                    │                   size/get_at 存取)          │
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

> **閱讀提醒**:以下為概念契約,不是可直接貼上的單一檔案。Godot 每個 `.gd` 檔只能有一個 `class_name`,實作時多數類別應落在各自檔案(如 `affinity_record.gd`、`affinity_record_list.gd`、`affinity_types.gd`、`hypothetical_entry.gd`、`import_result.gd`、`affinity_data_pool.gd`)。
>
> **🔴 2026-08-24 同檔強制規則(Step 5.5 覆核抓到的編譯期矛盾修正,取代原本點名 `affinity_read_result.gd` 的錯誤建議)**:機制二已明文 `WriteRejection`/`AdvanceRejection`/`DeathNotifyResult`/`EndTokenResult`/`ReadRejection`/`ReadMode`(及未來比照此決策新增的同類方法結果列舉)維持巢狀於 `AffinityDataPool`、不獨立抽出。**規則(涵蓋任何未來新增型別,不是只點名目前這兩個)**:任何型別若在自己的宣告(欄位型別/方法簽章/內部邏輯)中裸引用(不加 `AffinityDataPool.` 前綴)這組列舉的任一成員,該型別**必須與 `AffinityDataPool` 同檔**(`affinity_data_pool.gd`,以並列的 inner class 宣告,因此不再擁有自己的全域 `class_name`)——這是 Godot 4.7.1 對巢狀 enum **跨檔**裸引用的編譯期限制,不是紀律建議(探針 `prototypes/xcheck-adr0002-review-2026-08-24/`:同檔裸引用 `COMPILED OK`,跨檔裸引用 `FAILED — Parse Error: Could not find type "MyEnum" in the current scope.`,跨檔加前綴 `COMPILED OK`)。不引用這組列舉的型別不受此規則約束,可自由獨立成檔並保留自己的 `class_name`。
>
> **目前落在同檔規則下**:`AffinityReadResult`、`ShapeFeatureResult`(欄位 `rejection: ReadRejection`,見機制五)——**原建議的獨立檔案 `affinity_read_result.gd` 已撤回**,兩者改為 `affinity_data_pool.gd` 內的並列 inner class,不再是全域 `class_name`(見下方 Risks 表計數修正)。`HypotheticalEntry` 只引用已加前綴的 `AffinityTypes.Source`,**不受**此規則約束,維持獨立成檔、保留自己的 `class_name`;但呼叫端建構 `speculative_read()` 的 `mode` 引數時仍須加前綴 `AffinityDataPool.ReadMode`(裸用 `ReadMode` 在跨檔情境下無法編譯,見機制五呼叫端範例)。`ImportResult` 的 `Rejection` 列舉巢狀於 `ImportResult` 自身、非 `AffinityDataPool`(見機制八),故 `ImportResult` 同樣不受此規則約束,可獨立成檔(`import_result.gd`)並保留自己的 `class_name`。

```gdscript
# ─── affinity_record.gd ──────────────────────────────────────
class_name AffinityRecord extends RefCounted
var pair: AffinityTypes.Pair
var m: float
var t: int
var c: int
var source: AffinityTypes.Source
func to_dict() -> Dictionary: ...
static func from_dict(d: Dictionary) -> AffinityRecord: ...   # 遇非法名稱回傳 null,見機制八

# ─── affinity_types.gd ───────────────────────────────────────
# 2026-08-24 補上 pair_of() 與三個共用列舉本身(原 Key Interfaces 只列驗證器,
# 照抄本節的實作者會漏掉正規化建構函式——完整列舉成員見機制二,此處不重複)。
class_name AffinityTypes extends RefCounted
enum Character { ... }   # 5 個佔位識別碼,完整成員見機制二
enum Pair { ... }         # 10 對固定組合,完整成員見機制二
enum Source { ... }       # 完整成員見機制二
static func pair_of(a: Character, b: Character) -> Pair

# 2026-08-21 新增三個公開驗證器,機制四之四:
# 公開靜態,供 pair_of() 的呼叫端與任何外部使用者預先驗證序數合法性。
# AffinityDataPool 內部的 7 個入口改讀 _init() 快取的序數陣列(熱路徑,見修正 T),
# 但兩條路徑的檢查語意必須完全相同(已列入 Validation Criteria)。
static func is_valid_character(c: AffinityTypes.Character) -> bool
static func is_valid_pair(p: AffinityTypes.Pair) -> bool
static func is_valid_source(s: AffinityTypes.Source) -> bool

# ─── affinity_record_list.gd ─────────────────────────────────
# 繞過 GDScript 不支援巢狀型別容器的包裝層,見機制二 2026-08-20 BLOCKING 修訂
# 2026-08-21(R7E-12):items 改私有 _items + 最小存取面。不提供任何回傳 _items 本身的方法。
class_name AffinityRecordList extends RefCounted
var _items: Array[AffinityRecord] = []
func append(record: AffinityRecord) -> void: ...
func size() -> int: ...
func get_at(index: int) -> AffinityRecord: ...   # 2026-08-25:索引越界回傳 null,不中止(見機制二契約修訂)

# ─── affinity_data_pool.gd ───────────────────────────────────
class_name AffinityDataPool extends RefCounted

signal entry_appended(pair: AffinityTypes.Pair, record: AffinityRecord)

func append_record(pair: AffinityTypes.Pair, m: float, source: AffinityTypes.Source) -> WriteRejection
func advance_campaign_tick() -> AdvanceRejection
func notify_death(character: AffinityTypes.Character) -> DeathNotifyResult

func combat_strength_read(pair: AffinityTypes.Pair, t_query: Variant = null) -> AffinityReadResult
func narrative_depth_read(pair: AffinityTypes.Pair, t_query: Variant = null) -> AffinityReadResult
func shape_feature_read(pair: AffinityTypes.Pair, t_query: Variant = null) -> ShapeFeatureResult
func speculative_read(pair: AffinityTypes.Pair, hypothetical_entries: Array[HypotheticalEntry], mode: ReadMode) -> AffinityReadResult

func can_write(pair: AffinityTypes.Pair, source: AffinityTypes.Source) -> WriteRejection   # 2026-08-21:自 bool 改

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
- **Pros**:不需要新增一個全域 `class_name`,不需要 `append()`/`size()`/`get_at()` 這一層間接(**2026-08-21 前為 `.items` 屬性存取**;R7E-12 修訂後成本形式改為方法呼叫)。
- **Cons(2026-08-20 實測修正)**:代價**不是**「內層完全無型別」——實測把 `Array[AffinityRecord]` 存進裸 `Array` 值槽後讀回,`is_typed()` 仍為 `true`(`x7_typed_inner_in_bare_slot.gd`)。真正的代價是**不強制**:該值槽同時接受型別化與未型別化的 `Array`(對照組:未型別化字面量 `is_typed = false`),編譯期與執行期都沒有任何一層會阻止未型別化的 `Array` 被放進去。
- **Rejection Reason**:「不強制」只能用 setter 或撰寫紀律收斂,而本 ADR 系列反覆主張的立場是**結構保證優於紀律要求**(見 ADR-0003 對反序列化型別白名單的處理——它選了一個「結構上不可能產生自訂 `Object`」的格式,而非維護一份 app 層白名單)。另外覆核者自陳此選項還有一項**未測**:未型別化的 `Array` 存進去後,能否再被當成 `Array[AffinityRecord]` 讀出使用——若採此方案就必須先補這項驗證,選包裝類別則不需要。

> **⚠️ 2026-08-21 誠實補註(R7E-12)**:第七輪指出**包裝類別把「不強制」從 `Dictionary` 值槽搬到了公開類別的公開可變欄位** —— 本選項被拒的逐字理由(「不強制」)在 `AffinityRecordList.items` 上原封不動重現。已於同日改為私有 `_items` + 最小存取面。**但 GDScript 沒有真正的私有成員**,因此該修法**不是結構保證**,只是把紀律的作用面從「一個公開記載的欄位」收窄為「一個底線前綴欄位 + 一個明文禁令」。**本 ADR 不宣稱它達到了本節據以拒絕 Alternative 7 的那個標準**;兩者的差距已縮小但未消除。

> **原巢狀宣告 `Dictionary[Pair, Array[AffinityRecord]]` 不列為 Alternative**——它不是被權衡後拒絕的方案,是**被引擎否決的原決策**。該事實記在 Status 的修訂註記與機制二內。

## Consequences

### Positive

- **24 項 `TR-affinity-*` 的具體型別與介面已定案**,`/create-architecture`/`/create-stories` 不需要再等待或重新推導本系統的資料結構。**涵蓋分佈本身不由本 ADR 自陳**——第五輪 `/architecture-review` 獨立推導的結果與後續輪次為權威來源。
- **核心資料結構已在真機編譯驗證過**(2026-08-20):這是本專案第一份經實機驗證的 ADR。驗證直接擊落了原本的核心宣告——若照原計畫把本 ADR 推上 `Accepted` 再往下走 story,那一行會在實作第一天就爆,而那時它已是「已核准的架構決策」。
- **與存檔系統 ADR 完全解耦**:`export_state()`/`import_state()` 的通用 `Dictionary` 契約讓存檔格式決策(`TR-save-001`)可以在本 ADR 之後任意時間點做出,不需要回頭修改本 ADR 或已寫好的程式碼。
- **並發保護已就位,但目前無競爭對手**(**2026-08-21 改寫,R7E-11**):本項原寫「執行緒安全義務**一次性、無條件滿足**……並發正確性**已經成立**」,與機制七 C3 修訂明文的「本 ADR **不再宣稱**這是已成立的執行緒安全義務——它是一個目前無競爭對手的鎖」**直接矛盾**(第六輪 R6-4 修的是 `technical-preferences.md`,沒涵蓋 ADR 本體這一處)。正確陳述:ADR-0004 已把背景執行緒的條件判為「否」,故 `_serialization_tokens` 的 `Mutex` 是**縱深防禦**而非已成立的義務。若日後 `SaveIOBackend` 替換為背景執行緒實作,鎖已在位,不需要回頭重新推導並發正確性論證 —— **這是保留它的理由,不是宣稱現在有競爭。**
- **可單元測試性**:DI 擁有模式 + 無場景樹依賴,讓 7 類拒絕情境、5 條跨結構不變量等大量邊界案例可以用乾淨、隔離、不需引擎執行環境的單元測試逐一覆蓋,直接對應 GDD Acceptance Criteria 章節的密集驗收條件。
- **與 ADR-0001 的機制保持風格一致但不誤用**:序列化生命週期的拒絕式閘門精神與 `settlement_in_progress` 相同,但本 ADR 正確辨識出兩者本質不同(單一結算步 vs. 多重疊視窗),沒有錯誤地複用單一布林旗標。

### Negative

- **多一份必須維護的文件與交叉指標**:GDD 現有多處指標指向未來的本 ADR;本 ADR 也回指 GDD 各章節。任一方修訂時須檢查另一方——本專案已知最容易產生傳播失敗的動作。
- **無條件 Mutex 是一個保守選擇,可能是不必要的成本**(雖然可忽略):若存檔系統最終確定選擇同步阻塞式寫入(`TR-save-005` 原本的 `provisional` 傾向),這個 Mutex 保護實際上永遠不會有並發競爭場景,只是純粹的鎖開銷。
- **多一層方法呼叫間接與一個額外的全域 `class_name`**(2026-08-20 新增,**2026-08-21 隨 R7E-12 改寫**):`AffinityRecordList` 是為了繞過 GDScript 不支援巢狀型別容器而存在的包裝層;每一處存取 `_records` 的程式碼都要多一次 `append()`/`size()`/`get_at()` 呼叫(**修訂前為 `.items` 屬性存取** —— 私有化把成本形式由屬性存取改為方法呼叫,絕對成本仍可忽略)。這是**語言限制的直接成本,不是設計偏好**——已實測確認本次涵蓋的候選中無其他能同時保住兩層型別的寫法。
- **型別錯誤是本 ADR 拒絕碼機制唯一涵蓋不到的失敗類別**(2026-08-20 新增):見機制四之三。7 類 `WriteRejection` 涵蓋值域與狀態的非法,不涵蓋型別的非法;型別非法的失敗形式是呼叫端函式中止,不是回傳碼。這把一部分驗證責任明文推給上游呼叫方。
- **`can_write()` 回傳型別由 `bool` 改為 `WriteRejection`**(2026-08-21 新增):這是本次修訂**唯一**改變既有公開簽章回傳型別的一處。收益是非法序數有容身之處、且回傳資訊量嚴格更大;代價是 7 個 `WriteRejection` 值裡有 3 個對本函數結構上不可達,必須靠明文表格而非型別系統來表達(見機制九的可達性表)。
- **序數驗證有兩條實作路徑**(2026-08-21 新增):`AffinityTypes.is_valid_*()`(公開靜態,供 `pair_of()` 呼叫端)與 `AffinityDataPool` 內部讀 `_init()` 快取(熱路徑)。**這是「同一個檢查散寫在兩個地方」的形狀**,本 ADR 反覆警告過它;此處刻意接受,理由是熱路徑不能每次重新配置 `.values()` 陣列、而靜態函式讀不到實例成員。已以 Validation Criteria 斷言兩條路徑語意一致作為補償,**但那是測試而非結構保證**。
- **`pair_of()` 的保護等級低於其他 7 個入口**(2026-08-21 新增):它回傳裸 `Pair`,結構上容不下拒絕碼,因此只能以呼叫端義務 + forbidden pattern 處理。**本 ADR 不宣稱第 8 個入口與前 7 個受同等保護。**
- **`can_write()` 的窄範圍決定隱含一個未來風險**:若第二個封鎖成因出現卻沒有被正確辨識為需要升級全作用域登記處,`can_write()` 只涵蓋本系統自知的邏輯,不會自動涵蓋未來其他系統引入的封鎖成因。

### Risks

| 風險 | 緩解 |
|---|---|
| **存檔系統 ADR 最終選擇的並發模型比背景執行緒更複雜**(例如多執行緒池而非單一背景執行緒),使單一 `Mutex` 不足以保護所有存取路徑 | 本 ADR 的 Mutex 保護範圍明確界定為 `_serialization_tokens`/`_reclaimed_tokens` 本身;若存檔系統 ADR 引入更複雜的並發模型觸及 `_records`/`_death_marks`/`_campaign_tick_marks` 本身的並發存取(目前 GDD 未預期此情境——這些結構的寫入方皆為遊戲邏輯執行緒),須回頭重新評估本 ADR |
| **`_records`/`_death_marks`/`_campaign_tick_marks` 本身未加鎖**:本 ADR 假設寫入(`append_record` 等)只發生在主執行緒/遊戲邏輯執行緒,唯有序列化的**讀取**(`export_state()`)可能發生在背景執行緒——若這個假設不成立(例如未來某系統嘗試在背景執行緒呼叫 `append_record`),會產生資料競爭 | 本 ADR 的隱含前提已於此處明文記載:唯一可能的背景執行緒存取路徑是存檔系統的**唯讀**匯出,且該路徑受 `_token_mutex` 保護的「非原子視窗期間拒絕寫入」規則保護(視窗開啟時所有寫入方法皆拒絕)——只要存檔系統遵守「匯出前必先 `begin_non_atomic_window()`」的契約,`export_state()` 執行期間不會有並行寫入,不需要對 `_records` 本身額外加鎖。若未來出現本 ADR 未預期的背景寫入路徑,須回頭重新評估 |
| **`TOKEN_TIMEOUT_MS` 未定案**,若設得過短,會誤將仍在合法進行中的慢速操作(例如大型遷移的最後一步)判定為逾時回收,造成 `end_non_atomic_window` 回傳非預期的 `TIMED_OUT_RECLAIMED` 而非 `RELEASED` | **2026-08-19 修訂(C1 銜接缺口關閉)**:此值的**定值責任已由 ADR-0004 明文接下**(見該 ADR 機制六「C1 銜接缺口」段落),不再是本表原本模糊的「留待存檔系統 ADR 或實測校準」——該模糊措辭與 ADR-0004 上一版的「非本系統補償」互相推諉,使本值連續三輪 `/architecture-review` 被判為**孤兒義務**。定值依據是遷移鏈深度上界 × 幀預算 + 兩階段回寫最壞 I/O 時間 × 安全係數,**只有 ADR-0004 掌握這些量**。本系統仍擁有逾時**機制**的執行(機制七的逐權杖惰性清除),但不擁有那個數字。`TIMED_OUT_RECLAIMED` 本身被設計為非故障結果,呼叫方可自行決定如何處理,不會導致資料損毀 |
| **`AffinityTypes.Pair` 的 10 個成員在角色系統定案實際命名前只是佔位符**,若角色系統設計時發現主角規模政策變動(理論上已由 `game-concept.md` 主角群規模裁決鎖定 5 人,但仍是一個交叉文件的相依) | 若角色數量變動,`Pair`/`Character` enum 需要重新生成(10 對 → 其他組合數),`AffinityTypes.pair_of()` 的查表邏輯集中在單一函式,重新生成的影響範圍侷限,不擴散到呼叫端邏輯 |
| **export release 建置下 C++ 容器驗證(層二)可能被編譯掉**,使錯誤型別的值寫入 `_records` 時既不中止也不被丟棄。⚠️ 最壞影響不是崩潰,是**靜默存檔損壞且出貨版本專屬**:壞值經 ADR-0003 的 `var_to_bytes()` 序列化並通過兩層 SHA-256 雜湊鏈(雜湊驗位元組完整性、不驗語意),形成「debug 測得出、release 測不出」的不一致 | 三重,且三者對應**不同**的進入路徑:(i) **機制四之二的規則二(值邊界)**——值一律經靜態型別建構賦值、從不經 `Variant` 中介,層一在賦值處即受檢(編譯期,建置無關),層二因此只是同一件事的第二道確認;**規則一(鍵邊界)關的是層三,與本列無關**——本次修訂的初稿曾把兩者混為一談,已由 Step 5.5 覆核抓出並改正;(ii) **`validate_semantics()` 的逐欄位檢查已擴充為「型別 + 值域」**(機制八)——這是唯一涵蓋 `import_state()` 那條外來資料路徑的防線,app 層、與建置組態無關;(iii) Verification Required #7 記錄了建置無關的探針設計與 CI 回歸測試建議 |
| **型別錯誤是本 ADR 拒絕碼機制唯一涵蓋不到的失敗類別**:型別化參數的阻擋方式是整段**呼叫端**函式中止(2026-08-20 實測),不是可判斷的回傳值。上游若持有來源不明的 `Variant` 並直接傳入,失敗有**兩種形式**(**2026-08-21 改寫,R7E-4**:原文只寫了第一種)——(a) **`String` 一類** → 呼叫端函式**中止**(在 release 建置下甚至可能連錯誤都不列印,見 VR #7);(b) **數值近親一類**(`float 3.7`、`bool true`)→ **不中止,靜默截斷為合法序數,成功回傳 `WriteRejection.NONE`,資料寫入錯誤配對**。**(b) 比 (a) 嚴重** —— (a) 至少會停,(b) 會靜默寫壞資料並經 ADR-0003 的兩層 SHA-256 雜湊鏈寫進存檔(雜湊驗位元組完整性,不驗語意合法性) | 明文列為**呼叫端義務**(機制四之三):上游必須在呼叫前自行以 `typeof()` 收斂型別。本系統 7 類拒絕碼的範圍界線同時明文化為「值域與狀態的非法,不含型別的非法」。**本 ADR 刻意不新增 `INVALID_TYPE` 拒絕碼**——那會是一個結構上不可能被回傳的死碼,反而誤導呼叫方以為型別錯誤會被本系統攔下並回報 |
| **全域 `class_name` 命名碰撞**(2026-08-18 `godot-specialist` 驗證發現,低風險前瞻性提醒;**2026-08-25 修正計數與字首統計,兩處算錯**):`class_name` 註冊是專案級扁平命名空間,`AffinityRecord`/`AffinityRecordList`/`HypotheticalEntry`/`AffinityDataPool`/`AffinityTypes`/`ImportResult` **六**個全域類別名稱(2026-08-20 由六增為七,新增 `AffinityRecordList`;**2026-08-25 由七改回六**——`AffinityReadResult`/`ShapeFeatureResult` 因**Key Interfaces 閱讀提醒段落所載的 2026-08-24 同檔強制規則**移入 `AffinityDataPool` 同檔的並列 inner class,不再是全域 `class_name`;同時新增 `ImportResult` 補上原本從未宣告的型別本體,見機制八之二)未來可能與其他系統或第三方 addon 的類別名稱碰撞。**⚠️ 字首統計本身也需要修正**:修訂前的原文寫「七個名稱中六個皆帶 `Affinity` 字首」,這個算法本身就是錯的——`HypotheticalEntry`/`ShapeFeatureResult` 兩者皆不帶字首,原本應是「五之七」;本次改寫的上一版草稿沿用了同一種算法,誤寫成「六個名稱中五個皆帶字首」。**重算:六個名稱中只有四個帶 `Affinity` 字首**(`AffinityRecord`/`AffinityRecordList`/`AffinityTypes`/`AffinityDataPool`),**兩個不帶**(`HypotheticalEntry`/`ImportResult`) | 四個帶字首的名稱碰撞風險低,目前 `src/` 為空、無碰撞對象,此為一次性命名慣例,無需額外機制。**兩個不帶字首者風險不對等,需分開講**:`ImportResult` 是刻意設計——ADR-0003 機制六已明訂它是 `SaveBlockRegistry` 消費的跨系統共用驗證器回傳型別,加 `Affinity` 字首反而誤導其他系統實作者以為它是本系統專屬。**`HypotheticalEntry` 才是更值得留意的一個**:「Hypothetical」是常見英文詞,比 `ImportResult` 更可能與其他系統或第三方 addon 的命名(例如任何做「假設性/預判」功能的系統)撞上,且它不像 `ImportResult` 有「必須通用」的架構理由支撐不加字首——純粹是初版命名時沿用了「不帶字首」的做法、從未重新檢視。若未來真的發生碰撞,修正只需重新命名此一類別並更新 `speculative_read()` 的呼叫端型別標註,影響面小,故本次不強制改名,但列為比 `ImportResult` 更應優先關注的候選。 |

## GDD Requirements Addressed

| TR-ID | 需求 | How This ADR Addresses It |
|---|---|---|
| TR-affinity-001 | Delta Log 5 欄型別化記錄,非 `Array[Dictionary]` | `AffinityRecord`(`RefCounted`,5 個型別化欄位:`pair: Pair`、`m: float`、`t: int`、`c: int`、`source: Source`) |
| TR-affinity-002 | per-pair 索引,`O(n_p+m)` | `Dictionary[AffinityTypes.Pair, AffinityRecordList]`(內層私有 `_items: Array[AffinityRecord]`,經 `append()`/`size()`/`get_at()` 存取;2026-08-20 修訂原巢狀寫法在 4.7.1 無法編譯,2026-08-21 修訂 `items` 為私有);`c_now(t_query)` 對 `_campaign_tick_marks` 線性計數,`O(m)` |
| TR-affinity-003 | Dictionary 鍵須為值型別,不可為 Object 參照 | `Pair`/`Character` enum(int 底層)作為 `_records`/`_death_marks` 的鍵;序列化權杖為單調遞增 int,非物件身分(見 Alternative 4 的拒絕理由) |
| TR-affinity-004 | 兩個獨立全域單調計數器,皆為衍生值,不得另存 | `_t_now`(執行期快取,載入時由記錄總筆數重建,不獨立持久化);戰役刻度計數器本身由 `_campaign_tick_marks.size()` 衍生 |
| TR-affinity-005 | 獨立戰役刻度標記列表,`c_now` 不得由 Delta Log 的 `c_i` 推導 | `_campaign_tick_marks: Array[int]`,`advance_campaign_tick()` 附加而非由 `_records` 反推 |
| TR-affinity-006 | 獨立陣亡標記表,讀寫 O(1) | `_death_marks: Dictionary[AffinityTypes.Character, int]`,獨立於 `_records`;`t_death()` 至多 2 次鍵查找 |
| TR-affinity-007 | 陣亡通知介面:單一方法、陣營閘控、反向依賴不轉接 | `notify_death(character: AffinityTypes.Character) -> DeathNotifyResult`,由戰棋移動與交戰系統直接呼叫,不經好感度—位置連鎖系統轉接(機制三)。**2026-08-21 新增 `INVALID_CHARACTER`**:非法序數原本會走到 `_death_marks[非法序數] = _t_now` **靜默寫入非法鍵**,現由機制四之四的序數驗證器攔下 |
| TR-affinity-008 | 同結算步呼叫順序決定寫入合法性 | `notify_death`/`append_record` 皆為單純同步方法,不排隊不緩衝,呼叫方實際呼叫順序即決定結果(機制三);順序本身由呼叫方(戰棋移動與交戰系統)定案,本 ADR 不預設 |
| TR-affinity-009 | 前進戰役刻度為獨立介面,單一呼叫方 | `advance_campaign_tick()`,由章節/戰役結構系統呼叫 |
| TR-affinity-010 | 附加記錄介面恰 3 呼叫點;公開方法中僅 2 個會改變 Delta Log/戰役刻度狀態 | `append_record`/`advance_campaign_tick` 是唯二改變 Delta Log/戰役刻度標記列表狀態的方法;`notify_death`/`begin_non_atomic_window`/`end_non_atomic_window` 改變的是結構獨立的其他狀態,不在 AC-1 定義範圍內(機制四說明) |
| TR-affinity-011 | 寫入驗證 fail-loud,涵蓋明文拒絕情境 | `WriteRejection`/`AdvanceRejection`/`DeathNotifyResult`/`ReadRejection`/`EndTokenResult` 分類拒絕情境,`append_record()` 驗證順序明訂於機制四,enum 序數合法性由 8 個入口的統一驗證把守(機制四之四)。**2026-08-21 刪除原文的「窮盡列出所有拒絕分類」** —— 「窮盡」是全稱量詞,而 R7E-4 已實測證明存在**一類本 ADR 結構上無法涵蓋**的失敗(數值近親截斷後與合法值不可區辨,見機制四之三);該類的唯一防線是呼叫端義務,而那三個呼叫點目前無 GDD 亦無 ADR |
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
| TR-affinity-023 | 全作用域封鎖成因登記處是否升級為執行期 API | 維持文件層為主,提供窄範圍 `can_write()` 涵蓋本系統已知唯一成因(陣亡),不建立跨系統通用登記處(機制九,YAGNI 理由)。**2026-08-21:回傳型別自 `bool` 改為 `WriteRejection`**,並附逐值可達性表(7 值中 3 值結構上不可達) |
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
11. **`AffinityRecordList` 包裝層的編譯驗證**(2026-08-20 新增):實作第一天即在真機編譯 `var _records: Dictionary[AffinityTypes.Pair, AffinityRecordList]` 的宣告,確認不再出現 `Nested typed collections are not supported`;並斷言兩層型別皆保住 —— **2026-08-21 隨 `_items` 私有化改寫**:(a) `_records[pair] is AffinityRecordList`;(b) **先 `append()` 一筆記錄後**再斷言 `_records[pair].get_at(0) is AffinityRecord`(以元素型別實證第二層);(c) `AffinityRecordList` 自身的單元測試斷言其內層陣列 `is_typed() == true`。⚠️ **(b) 必須先 `append()`** —— 型別化 `Array` 對**越界索引**的讀取行為**零探針覆蓋**(見 VR #11),**不得沿用探針 A 對 `Dictionary` 缺鍵的結論**(不同容器、不同操作)。**不可用 `get_class()` 做這項斷言**——它回傳原生類別,任何 `RefCounted` 子類都印 `RefCounted`;應用 `script.get_global_name()` 或 `is AffinityRecordList`。

12. **8 個入口的序數驗證測試矩陣(2026-08-21 新增,機制四之四)**:逐一針對 8 個帶 enum 參數的入口,各自構造非法序數輸入(`-1`、`999`),斷言回傳的**具體枚舉成員**與該入口應有的值完全一致(`append_record` → `INVALID_PAIR`/`INVALID_SOURCE`;`notify_death` → `INVALID_CHARACTER`;四個讀取函數 → `ReadRejection.INVALID_PAIR`;`can_write` → `WriteRejection.INVALID_PAIR`/`INVALID_SOURCE`;`pair_of` → 前置條件違反,行為未定義故只斷言呼叫端已先驗證)。**理由**:三個驗證器回傳 `bool`,8 處各自把 `false` 對應到正確拒絕碼 —— **跨 enum 型別誤用會被 GDScript 靜態型別檢查在編譯期擋下,但同一個 enum 內選錯成員不會**(兩者都是合法成員)。本項把「目前靠人工核對」轉成一份必須存在的測試矩陣。

13. **兩條序數驗證路徑的一致性測試(2026-08-21 新增)**:對同一組輸入(合法值、`-1`、`999`),斷言 `AffinityTypes.is_valid_pair/character/source()`(公開靜態)與 `AffinityDataPool` 內部讀 `_init()` 快取的檢查**回傳完全一致的結果**。**理由**:這是「同一個檢查散寫在兩個地方」的形狀,本 ADR 刻意接受它(熱路徑不能每次重配 `.values()` 陣列、靜態函式讀不到實例成員),此測試是唯一的補償手段。

14. **讀取路徑的拒絕形狀測試(2026-08-21 新增,機制五/五之二)**:(a) 四個讀取函數對每個可達的 `rejection` 值各構造一個觸發輸入,斷言回傳的是**結果物件**(非 enum、非 `null`)且 `rejection` 欄位正確;(b) 拒絕時斷言**全部**哨兵欄位符合機制五之二的兩張表 —— 特別是 `value`/`total_churn` 為 `NAN`(**不是 `0.0`**)、`diagnostic_visited_count` 為 `-1`(**不是 `0`**);(c) `t_query` 傳入 `"3"`(String)、`3.0`(float)、`3`(int)、`null` 四種,斷言前二者回傳 `INVALID_T_QUERY_TYPE` 而**不中止函式**。

15. **`n(p) = 0` 的讀取測試(2026-08-21 新增,R7E-2)**:建構子剛完成、`_records` 全為空 list 時,對全部 10 對配對各呼叫一次三個讀取函數,斷言**全部正常回傳**(`rejection == NONE`、`n_pair == 0`)且**無任何函式中止**。並斷言 `_death_marks` **未被預填**(5 名角色皆非「已陣亡」),`t_death()` 對每一對皆回傳 `null`。

**反向驗證(本 ADR 若錯了會如何顯現)**:若 per-pair 索引實作有誤(例如意外退化為全表掃描),會表現為 `diagnostic_visited_count` 隨全域總筆數增長而非配對自身筆數增長——`AC-55` 對應的自動化測試會直接攔截。若權杖逾時邏輯過於激進(逾時門檻太短),會表現為合法但較慢完成的存檔操作被誤判為 `TIMED_OUT_RECLAIMED`,雖非資料損毀但會產生誤導性診斷紀錄,應在校準 `TOKEN_TIMEOUT_MS` 時特別注意。

## Related Decisions

- `design/gdd/affinity-data-pool.md` — 本 ADR 服務的全部義務之權威定義處,本 ADR 只定案機制。
- `docs/architecture/adr-0001-tactical-query-atomicity-contract.md` — 拒絕式並發閘門(`settlement_in_progress`)的先例,本 ADR 的序列化生命週期機制借鑑其精神但因涉及多重疊視窗而採獨立的權杖式機制,非直接複用。
- `docs/registry/architecture.yaml` — 本 ADR 完成後將登記的新增立場(state ownership、api_decisions、forbidden_patterns 候選,見下方 Registry 更新提案)。
- `docs/architecture/architecture-review-2026-08-18.md` — 記錄本 ADR 為全專案最高優先 ADR 缺口的稽核結果。
- `docs/architecture/adr-0003-save-system-serialization-format-and-type-safety.md`(2026-08-18 新增)——消費本 ADR 的 `export_state()`/`import_state()` 契約作為好感度區塊的 payload 來源,並促成本 ADR 新增 `validate_semantics()`(見機制八回填修訂)。
- **待建**:存檔系統原子寫入與遷移執行模型 ADR(`TR-save-005` 及其下游)——可直接引用本 ADR 的 `export_state()`/`import_state()`/`validate_semantics()` 契約。
- `prototypes/engine-verification-spike-2026-08-20/` 與 `prototypes/xcheck-gdscript-specialist-2026-08-20/`(2026-08-20 新增)——本次修訂的**全部實測證據來源**。原始未過濾 log 已歸檔(`logs/run-final-2026-08-20-headless.txt`、`logs/xcheck{1,2,3,4}-unfiltered.txt`),檔頭自帶執行指令、exit code 與判讀陷阱,**下一輪覆核不需回讀對話**。⚠️ 兩份 README 皆自陳探針弱點與已被推翻的結論,引用前請讀「結論歸屬」一節。
- `prototypes/xcheck-round7-2026-08-20/`(2026-08-21 新增)——**第七輪四支探針**(A/B/C/D)的專案與未過濾 log,全部 exit code 0。本次修訂引用的實測事實全部出自此處:探針 A(型別化 `Dictionary` 缺鍵讀取**中止呼叫函式**;包裝類別宣告兩形皆編譯、兩層型別皆保住)、探針 B(enum 型別化參數對數值近親**靜默轉換**,越界 int **零檢查通過**)、探針 C(`find_key(999)` 乾淨回傳 `null`;動態非法字串 subscript **中止**)、探針 D(`values().has()` 越界輸入與 `keys().has()` 非法名皆**乾淨回傳 `false` 不中止**,字面量與動態組出兩形同行為)。**README 的「殘留未查證項」節記載 #3/#4 仍開。**
- `docs/architecture/adr-0005-cursor-device-authority-input-architecture.md`(2026-08-20 新增交叉引用)——Verification Required #7(export release 建置)。**🔴 2026-08-21 誠實改寫(R7E-7 / C7)**:本條原寫「依賴方向不同:本 ADR **只**依賴層 A;ADR-0005 依賴層 B」,**兩半都不成立**。(a) **本 ADR 同時依賴層 A 與層 B** —— 層 A 已由規則二降為縱深防禦,層 B(GDScript VM 是否中止所在函式)**尚未降級**,機制四之三與 Risks 表兩處都押在它上面。(b) **ADR-0005 全文對層 B、export release、2026-08-20 spike 零命中** —— 本 ADR 單方面替它記帳,與第三輪的 C6 同一形狀。**ADR-0005 是否依賴層 B 由該 ADR 自行認定,本 ADR 不代為記帳。** **C7 因此只關本 ADR 這一半**;另一半需 ADR-0005 第四次修訂補上對應文字,與 C6 的正解同型(由被記帳的那一方自己補一句)。
