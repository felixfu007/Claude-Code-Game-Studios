# 架構審查報告 — 2026-08-18(第二輪)

**模式**:`/architecture-review`(完整模式) | **引擎**:Godot 4.7.1 / GDScript
**已審查 GDD**:5 份(`game-concept.md` + 4 份系統 GDD) | **已審查 ADR**:4 份(ADR-0001~0004,全部 `Proposed`)
**上一輪**:`architecture-review-2026-08-18.md`(同日,FAIL,109/130 缺口,當時僅 ADR-0001)

## 需求基線的處理方式

本輪**未重新擷取**技術需求。以 `git diff 890046b..HEAD -- design/gdd/` 查證:兩輪之間 4 份系統 GDD 與 `game-concept.md` 皆**零變動**(唯一變更是 `systems-index.md` 的 7 行非需求性註記)。因此沿用 `docs/architecture/tr-registry.yaml` 的 **130 項需求基線**(24 affinity + 30 save + 43 tactical + 19 cursor + 14 concept;另有 3 項 `TR-combat-*` 為註解範例,不計入),全部 TR-ID 維持不變,無新增、無改寫、無棄用。

本輪的實質工作在 Phase 3(涵蓋判定)、Phase 4(跨 ADR 衝突——首次有 4 份 ADR 可比對)與 Phase 5(引擎交叉核對)。

---

## 涵蓋率總覽

| 狀態 | 首輪 | **第二輪** | 變化 |
|---|---|---|---|
| ✅ 已涵蓋 | 5(4%) | **50(38%)** | +45 |
| ⚠️ 部分涵蓋 | 16(12%) | **24(18%)** | +8 |
| ❌ 缺口 | 109(84%) | **56(43%)** | −53 |
| **合計** | **130** | **130** | |

| GDD | 系統 | 層級 | 需求數 | ✅ | ⚠️ | ❌ |
|---|---|---|---|---|---|---|
| affinity-data-pool.md | 好感度數值池 | Foundation | 24 | **22** | 2 | **0** |
| save-system.md | 存檔系統 | Foundation | 30 | **22** | 7 | **1** |
| tactical-combat-system.md | 戰棋移動與交戰系統 | Core | 43 | 5 | 11 | 27 |
| cursor-highlight-state.md | 單一游標/高亮狀態系統 | Foundation | 19 | 0 | 0 | **19** |
| game-concept.md | (跨系統) | — | 14 | 1 | 4 | 9 |

逐條 130 列的標記與理由在 `docs/architecture/traceability-index.md`(本輪已完整重建)。

### 本輪由 ❌ 轉為已涵蓋/部分的項目

- **全部 24 項 `TR-affinity-*`** → 22 ✅ / 2 ⚠️(ADR-0002)
- **29 項 `TR-save-*`** → 22 ✅ / 7 ⚠️(ADR-0003 + ADR-0004)
- `TR-tactical-023`(陣亡通知)→ ⚠️(ADR-0002 機制三提供介面側)
- `TR-concept-002`(存檔格式須內建跨版本遷移能力)→ ✅(ADR-0003 機制二 + ADR-0004 機制五)
- `TR-concept-003`(地形 Resource 深拷貝紀律)→ ⚠️(ADR-0003 機制一移除存檔側曝險)

---

## 本輪獨立推翻的涵蓋宣稱

`/architecture-decision` 的硬性規定是:涵蓋判定必須由獨立於撰寫脈絡的 `/architecture-review` 重新推導。逐項核對後,以下宣稱**不成立**:

### 1.「全部 30 項 `TR-save-*` 皆有 ADR 覆蓋」——不成立

此宣稱同時出現於三處:ADR-0004 的 `Enables` 欄、`design/gdd/systems-index.md` 開頭註記、`.claude/docs/technical-preferences.md` 的 ADR-0004 條目。實際為 **22 ✅ / 7 ⚠️ / 1 ❌**。

- **`TR-save-030`(雲端存檔同步 × 多檔案原子性)= ❌ 缺口**。ADR-0004 把它列在 Requirements Addressed 表內,但**同一格的說明文字明文寫「本 ADR 不解決此問題」**。列入表格不等於涵蓋。依 GDD 原文,此項須待平台策略(是否採 Steam 發行)定案,屬合理的待決事項——但它是缺口,不是覆蓋。
- **7 項 ⚠️ 部分涵蓋**:

| TR-ID | 為何是部分而非涵蓋 |
|---|---|
| `-005` | ADR-0004 機制一維持同步阻塞 + `SaveIOBackend` 抽象,但同節明文「此決策**不解決** GDD Open Question 9」。主機 SDK 驗證仍待 `/create-architecture` |
| `-015` | 架構層已定案「逐呼叫檢查 `SaveIOBackend` 回傳值」,但 `flush()` 本身的可檢查性在 4.7.1 仍未驗證;降級方案 `get_error()` 是粗粒度累積狀態,無法區分 `flush()` 失敗與前一次 `store_buffer()` 已設下的錯誤 |
| `-019` | 忠實記錄耐久性邊界(未誇大,值得肯定),但「是否採 GDExtension 取得硬體層落盤」本身未做決策 |
| `-021` | 機制五涵蓋逐步驟後置條件檢查 ✅,但遷移函數的**純函數性與 `O(該區塊筆數)` 委派給各擁有系統提供**,架構層無強制機制 |
| `-026` | **本輪最實質的降級**。需求要三桶一般寫入耗時、六桶遷移讀取耗時、加性下限成本模型、無界重跑鏈風險判準。機制十提供的是遷移**呼叫計數器**與**順序記錄**——那是正確性儀器,不是耗時儀器。GDD 第四輪明文的「總耗時 = Σ(各步驟計算耗時) + 鏈深度 × 每步讓出固定成本」這個加性下限模型,沒有任何 ADR 承接 |
| `-028` | 機制一拒絕 Resource 使存檔側曝險消失 ✅,但地形側深拷貝紀律明文「降級為未來系統自身責任」,隨 `TR-concept-001/003` 未決 |
| `-029` | 機制七路徑二保證資料前提成立,但觸發機制與 append-only 拼接程序明文留給 `/create-architecture` |

### 2. 我方一個假設也被推翻(記錄以免誤導後續)

機械稽核對 ADR-0001 grep 到 2 處 `duplicate_deep()`,一度懷疑 ADR-0003「拒絕 Resource 使此問題降級」的宣稱沒有涵蓋 ADR-0001 內的活用法。**逐行核對後推翻**:兩處分別在(a)**已被拒絕**的 Alternative 1 的 Cons 段落、(b)Engine Compatibility 明文聲明「本 ADR 的版本戳記方案**不複製盤面**,故此項僅在未來若改採深拷貝快照時才相關」。ADR-0001 對 `duplicate_deep()` **沒有活依賴**。`godot-specialist` 獨立核對得到同一結論(標記 REFUTED)。**教訓:grep 命中字串 ≠ 實際使用。**

---

## 跨 ADR 衝突與銜接缺口

**無阻塞級衝突**(無資料擁有權重疊、無依賴循環、無效能預算加總超支)。以下 5 項為銜接缺口與措辭問題,四份 ADR 皆為 `Proposed`,現在調和成本最低。

### C1 — 孤兒義務:`TOKEN_TIMEOUT_MS` 沒有任何 ADR 擁有

| 項目 | 內容 |
|---|---|
| **類型** | 整合契約 / 委派落空 |
| **ADR-0002 claims** | Risks 表:「具體數值留待**存檔系統 ADR** 或實測校準」;並自行指出風險「若設得過短,會誤將仍在合法進行中的慢速操作(**例如大型遷移的最後一步**)判定為逾時回收」 |
| **ADR-0004 claims** | 機制六:affinity 端權杖的逐權杖逾時後備機制是「**該系統的職責,非本系統補償**」 |
| **Impact** | 委派方指向被委派方,被委派方明文退回。而 ADR-0004 的分步遷移正好會跨越「數個至數十個影格」加磁碟 I/O——這正是 ADR-0002 自己預測會出問題的情境。後果不是資料損毀(`TIMED_OUT_RECLAIMED` 被設計為非故障結果),而是合法的慢速存檔操作被誤判、產生誤導性診斷紀錄 |
| **Resolution options** | 1. ADR-0004 增訂一節:依機制五的鏈深度上界推導 `TOKEN_TIMEOUT_MS` 下界(遷移鏈深度 × 每步讓出成本 + I/O 上界),把數值校準義務正式接下<br>2. ADR-0002 改為自行定案一個保守大值,並明文「存檔系統不得假設此值可容納任意長的遷移鏈,長鏈情境須自行分段開關視窗」<br>3. 留給 `/create-architecture`,但須在兩份 ADR 的 Risks 表同時明文登記「此項目前無人擁有」,不要互指 |

### C2 — 介面契約不一致:同一驗證器有兩個回傳型別名

| 項目 | 內容 |
|---|---|
| **類型** | 整合契約 |
| **ADR-0003 claims** | 機制六:`validator: Callable(Dictionary) -> ValidationResult` |
| **ADR-0002 claims** | Key Interfaces:`func validate_semantics(data: Dictionary) -> ImportResult` |
| **Impact** | `AffinityDataPool.validate_semantics()` 是目前唯一的具體驗證器,也正是 ADR-0003 機制六要登記的對象。ADR-0004 機制五以 `.call(data)` 消費它。三份 ADR 引用同一介面,型別名有兩種 |
| **Resolution options** | 1. 統一為 `ValidationResult`,ADR-0002 的 `import_state()` 另行包裝(語意上 `import_state` 確實比純驗證多做了狀態替換,兩個型別名分開反而更清楚——但那要明文寫出兩者關係)<br>2. 統一為 `ImportResult` 並在 ADR-0003 改名<br>3. 明文定義 `ValidationResult` 為介面型別、`ImportResult` 為其子型別/別名 |

### C3 — 條件已被解答,但未回傳給提問的 ADR

| 項目 | 內容 |
|---|---|
| **類型** | 並發 / 架構模式 |
| **需求原文** | `TR-affinity-016` 是**條件式**需求:「**若**架構階段選擇背景執行緒序列化,權杖集合本身須執行緒安全(全專案唯一此類義務)」 |
| **ADR-0002 claims** | 機制七 + Alternative 5:**不等待**存檔系統執行模型定案,無條件上 `Mutex`。Ordering Note 明文理由:避免循環等待 |
| **ADR-0004 claims** | 機制五「不引入背景執行緒」;機制十第 4 項對存檔讀寫進入點加**主執行緒斷言**(debug build) |
| **Impact** | 條件前提現在已被判為「否」。ADR-0002 的 `Mutex` 防守的是一個 ADR-0004 已結構性排除、且會被斷言攔截的情境。這**不是正確性錯誤**——ADR-0002 當時不等待是正確的判斷,`Mutex` 開銷在該呼叫頻率下可忽略。但 ADR-0002 目前仍宣稱這是「本專案唯一宣告的執行緒安全義務」,而該義務的觸發條件已不存在 |
| **Resolution options** | 1. **保留 `Mutex` 作為縱深防禦**,但在 ADR-0002 明文交叉引用 ADR-0004:「背景執行緒序列化已被 ADR-0004 排除;本 `Mutex` 保留為未來翻轉(`AsyncSaveIOBackend`)時的前置準備,不是對當前執行模型的必要條件」<br>2. 移除 `Mutex`,改為在主執行緒斷言上依賴 ADR-0004——**不建議**,因為 ADR-0004 自己把非同步後端列為未來可能的翻轉方向 |

### C4 — 銜接空白:`write_temp()` 底層用 `store_buffer()` 還是 `store_var()` 沒有任何一份 ADR 拍板

| 項目 | 內容 |
|---|---|
| **類型** | 整合契約(由 `godot-specialist` 發現) |
| **ADR-0003 claims** | Risks 表提醒下一份 ADR:「若確實呼叫 `FileAccess.store_var()`/`store_buffer()` 寫入磁碟,須檢查其 `bool` 回傳值」 |
| **ADR-0004 claims** | 機制一只寫概念契約 `write_temp(path, buffer: PackedByteArray) -> bool`,未指定底層呼叫;機制三要求「每一步驟的成功與否皆由 `_io` 的回傳值實際檢查」 |
| **Impact** | 紀律要求已到位(不是漏洞),但**具體選擇**懸空。輸入既然已是 `PackedByteArray`(ADR-0003 的產物),理應是 `store_buffer()`;`store_buffer()` 自 4.4 起回傳 `bool` 已由 `breaking-changes.md` **明文確認**(這是本輪少數 CONFIRMED 的引擎事實) |
| **Resolution options** | 1. ADR-0004 機制一在 `SyncBlockingSaveIOBackend` 註解明文拍板 `store_buffer()`,並引用 `breaking-changes.md` 的 `bool` 回傳確認<br>2. 留給 `/create-architecture` |

### C5 — 措辭超出上游 ADR 實際驗證範圍

| 項目 | 內容 |
|---|---|
| **類型** | 架構模式 / 文件正確性(由 `godot-specialist` 發現) |
| **ADR-0004 claims** | 機制五:跨幀 `await` 是「**沿用 ADR-0001 已驗證的**跨幀生命週期約束」 |
| **ADR-0001 實際範圍** | 機制一講的是**一般性**宿主生命週期原則(持有協程的物件須有涵蓋整場戰鬥的生命週期),**未區分** `RefCounted`(參照計數歸零)與 `Node`(顯式 `queue_free()`)兩種失效路徑 |
| **Impact** | ADR-0004 選 `RefCounted`(Alternative 2 拒絕 `Node` + `_process()`)理由本身合理(與 DI 慣例一致)。但兩種宿主的失效**觸發條件不同**:「意外少掉一個參照」在程式碼審查中比「意外呼叫 `queue_free()`」更難被發現,因為看不到任何顯式呼叫。「已驗證的先例」這個措辭讓一個未被單獨驗證的風險藏進了一句看似已結案的引用裡 |
| **Resolution options** | 1. 把 Engine Compatibility 第 5 項改寫為「沿用 ADR-0001 的一般性生命週期約束**原則**,但 `RefCounted` 特有的參照計數釋放路徑未被 ADR-0001 或任何其他 ADR 單獨驗證過」,保留既有的「建議獨立煙霧測試」結論 |

### ADR 依賴順序

```
Foundation(無依賴):
  1. ADR-0001:戰棋查詢介面原子性契約(Proposed)
  2. ADR-0002:好感度數值池資料結構與並發契約(Proposed)

依賴 Foundation:
  3. ADR-0003:存檔系統序列化格式與型別安全(Proposed;requires ADR-0002)

Feature 層:
  4. ADR-0004:存檔系統原子寫入與遷移執行模型(Proposed;requires ADR-0003、ADR-0002)
```

**無依賴循環。** ADR-0002 的 Ordering Note 明文為了避免與存檔系統 ADR 循環等待而刻意不反向依賴——本輪查證此設計成立,依賴圖為一條乾淨的鏈。

**未解決的依賴(全部 3 項,同一成因)**:

```
⚠️  ADR-0003 depends on ADR-0002 —— 但 ADR-0002 仍為 Proposed。
⚠️  ADR-0004 depends on ADR-0003 —— 但 ADR-0003 仍為 Proposed。
⚠️  ADR-0004 depends on ADR-0002 —— 但 ADR-0002 仍為 Proposed。
```

**四份 ADR 無一 `Accepted`。** 依 `docs/CLAUDE.md`,引用 `Proposed` ADR 的 story 會被自動阻擋——目前整條鏈沒有任何一段可進入實作。這是次級阻塞項(不單獨構成 FAIL,但擋住所有下游 `/create-stories`/`/dev-story`)。

另需注意:ADR-0003 **回填修訂了** ADR-0002(新增 `validate_semantics()`)。若 ADR-0002 先行 `Accepted`,須確認該修訂已含入被接受的版本——目前 ADR-0002 檔案已包含此方法,一致。

---

## 引擎相容性交叉核對

**版本一致性**:四份 ADR 皆針對 Godot 4.7.1,與 `VERSION.md` 一致,無過時版本參照。

**棄用 API 檢查**:對 `deprecated-apis.md` 全表(節點/類別、方法/屬性、模式三節)做 grep,四份 ADR **零命中**。

**Engine Compatibility 章節**:4/4 皆有,且皆宣稱 Post-Cutoff API 依賴為「無 / 無已知」——本輪未發現反例。

**Post-Cutoff API 衝突**:無。四份 ADR 對同一 API 未做出互相矛盾的假設。

### 引擎專家查核結果(本輪諮詢的 godot-specialist)

專家明確聲明了證據等級的區分,這點值得直接保留:

**經查證(直接引用本專案文件,非訓練資料判斷)—— 3 項**

| # | 結論 | 依據 |
|---|---|---|
| 1 | `FileAccess.store_*` 系列自 4.4 起回傳 `bool` | **CONFIRMED** — `breaking-changes.md` 4.3→4.4 表格逐名列出 `store_buffer` |
| 2 | `Time.get_ticks_msec()` 為當前建議 API(ADR-0002 用於逾時判斷) | **CONFIRMED** — `deprecated-apis.md`「Use Instead」欄明文;4.6/4.7 無異動記錄 |
| 3 | ADR-0001 是否真的使用 `duplicate_deep()` | **REFUTED** — 逐行核對推翻機械稽核的誤判 |

**訓練資料印象,未經本專案任何形式驗證 —— 其餘全部**

`var_to_bytes`/`bytes_to_var` 簽章與 `allow_objects` 行為(高信心度)、`HashingContext` 三段式 API(高信心度)、`DirAccess.rename_absolute()`/`remove_absolute()` 方法名與 `Error` 回傳(中高信心度)、`FileAccess.flush()` 無回傳值(傾向)、GDScript 無 fsync 等效物(傾向)、`Mutex` 開銷與 `Mutex`+`RefCounted` 陷阱(無已知陷阱)、typed `Dictionary` 是否支援自訂 enum 作為鍵型別(僅類比推論)。

專家結論:**既有 ADR 把這些標記為「待驗證」本身是恰當的自我克制,沒有依據可以把任何一項從「待驗證」升級為「已確認」。**

**專家新發現的風險(尚未被任何既有文件追蹤)—— 4 項**

| # | 風險 | 建議處置 |
|---|---|---|
| E1 | **`Callable`/`Signal`/`RID` 不是 `Object` 衍生類,不受 `allow_objects=false` 管控**。ADR-0003 機制一「型別白名單問題結構性不存在」的論證隱含前提是 payload 只含原生 Variant 型別;若某擁有系統的 `export_state()` 不慎把 `Callable`(例如驗證器參照本身)放進 payload,`bytes_to_var(buffer, false)` 仍會把它還原。這不是白名單問題的反例,但也不是想出現在存檔位元組裡的東西 | ADR-0003 Validation Criteria 補一條:確認 payload 建構路徑不會意外含入 `Callable`/`Signal`/`RID` |
| E2 | **`RefCounted` 宿主的協程失效機制與 `Node` 不同**(同 C5) | 見 C5 |
| E3 | **`docs/engine-reference/godot/modules/` 沒有 core/scripting 模組文件**。現有 8 份為 animation/audio/input/navigation/networking/physics/rendering/ui——而四份 ADR 幾乎全部的 HIGH Knowledge Risk 項(序列化、雜湊、檔案 I/O、並發原語)剛好整批落在這個結構性空白裡,導致每份新 ADR 都要重新聲明同一批「未經查證」 | 建議 technical-director 評估新增 `modules/core-scripting.md`,集中記錄 `var_to_bytes`/`bytes_to_var`/`HashingContext`/`Mutex`/`FileAccess`/`DirAccess` 的版本檔案 |
| E4 | **`@abstract` 語法是四份 ADR 裡信心度最低、且錯了會整檔案編譯失敗的賭注**。ADR-0004 自己已標記(Verification Required 6/6a),但專家強調其**優先度應高於** `HashingContext`/`DirAccess` 方法名——後兩者頂多是執行期的簡化機會或降級處理,`@abstract` 寫錯會擋下整個 `save_io_backend.gd` | 若只能優先驗證一件事,選這件 |

**另一項措辭問題**:ADR-0002 的「Post-Cutoff APIs Used」欄寫「無——`Dictionary[K,V]`…皆非本 ADR 依賴項」,字面易被誤讀為「不依賴 `Dictionary[K,V]`」(通篇明顯大量依賴)。正確語意是「這些都不是 *post-cutoff* 依賴項(4.4 早於訓練截止)」。措辭問題,非事實錯誤。

---

## GDD 修訂旗標(架構 → 設計端回饋)

**無 GDD 修訂旗標——全部 GDD 假設與已驗證的引擎行為一致。**

理由與首輪相同:本輪所有引擎項目都是「**未驗證**」而非「**已被推翻**」。沒有任何一項已查證的引擎現實與某份 GDD 的假設矛盾。上方 E1~E4 屬於 ADR 層面的補強項與專案文件結構缺口,不是 GDD 的設計假設錯誤。因此**不需要更新 `systems-index.md` 的 Status 欄**,無任何系統需要標記 `Needs Revision`。

---

## 架構文件涵蓋度

`docs/architecture/architecture.md` 尚不存在——這是本階段的預期現況(4 份 ADR,尚未進入 `/create-architecture`),本輪不評估。

---

## 判定:**FAIL**

### 阻塞項(必須解決才能 PASS)

1. **`cursor-highlight-state.md` 的 19 項需求零涵蓋,且它是 Foundation 層系統。**
   這是本輪唯一的硬阻塞。該系統已於 2026-08-13 第十六輪 `/design-review` **Approved**,`tactical-combat-system.md` 的 Dependencies 明文依賴它,`systems-index.md` 的 Dependency Map 把它列在 Foundation Layer 第 3 位。19 項需求中至少兩項是架構級未解問題:
   - **一個已確認的永久鎖死缺陷**(第十六輪已降級為建議項,但架構層面仍未解決)
   - **原生游標連續透明度漸變能力可能在 4.7.1 不受支援**,屆時須改用其他渲染載體
   - 另有專案層級「Agile Event Flushing」設定鎖定(引擎行為尚未驗證)、`_input()` 緩衝與同幀排序架構、滑鼠奪權門檻數學、共用「表面類型」enum 的實作位置(自第四輪起懸而未決)

### 次級阻塞(不構成 FAIL,但擋住所有實作)

2. **四份 ADR 全為 `Proposed`,無一 `Accepted`。** 依 `docs/CLAUDE.md`,引用 `Proposed` ADR 的 story 會被自動阻擋。ADR-0002 對 24 項 `TR-affinity-*` 已達零缺口——它是最接近可 `Accepted` 的一份,建議優先推進。

### 建議的 ADR 清單(最基礎優先)

1. **單一游標裝置權威輸入架構**(`TR-cursor-001` 至 `-019`)—— Foundation 層唯一零涵蓋系統,唯一的 FAIL 成因
   `/architecture-decision 單一游標裝置權威輸入架構`
   Domain:Input / UI / State · Engine Risk:**HIGH**(4.7 裝置 ID 重新編號、雙焦點系統、Agile Event Flushing、原生游標透明度)
2. **戰棋盤面演算法層**(可達格/威脅範圍/視線)(`TR-tactical-002`~`-010`、`-019`~`-021`、`-037`~`-039`)
   Domain:Algorithms / Performance · Engine Risk:LOW(純格狀幾何,不觸物理伺服器)
3. **回合結構擁有權 + 缺席的 AI/遭遇系統**(`TR-tactical-034`、`-041`)—— 全專案無人認領回合結構;`tactical-combat-system.md` Core Rules #9 明文要求敵方回合消費這些查詢,但專案中不存在任何 AI/遭遇系統
   Domain:Architecture / Gameplay · Engine Risk:LOW

### 低成本修補項(不需要新 ADR)

| # | 項目 | 狀態 |
|---|---|---|
| R1 | **`TR-concept-012`/`-014` 的兩項專案級 forbidden pattern 未登記**。首輪即指出,本輪查證仍然缺席——`docs/registry/architecture.yaml` 原 38 項立場中,無任何 RNG / networking / procedural terrain 相關條目(以 grep `rng|random|procedural|程序化|連線|network|multiplayer` 全檔零命中確認) | ✅ **本輪已完成**,見下方「本輪後續處置」 |
| R2 | C1~C5 五項銜接缺口的調和(四份 ADR 皆 `Proposed`,現在改動成本最低) | 部分 — C2/C4/C5 ✅ 已修正;**C1/C3 仍待處理** |
| R3 | E1(payload 不得含 `Callable`/`Signal`/`RID`)、E3(新增 `modules/core-scripting.md`)、ADR-0002 的 Post-Cutoff 欄措辭 | ❌ 待處理 |

---

## 本輪後續處置(審查後同 session 執行,使用者逐項核准)

### 已完成

**R1 — 3 項專案級 forbidden pattern 已登記** 至 `docs/registry/architecture.yaml`:
`rng_in_combat_settlement`、`networking_features`、`procedural_terrain_generation`。
Registry 累計 38 → **41 項**(forbidden_patterns 10 → 13)。

兩項刻意的規則例外,已在登記處明文記錄:
- 這三項的 `adr:` 欄為 `none` —— 它們源自 `game-concept.md`,不是任何 ADR 的推論。registry 檔頭定義 `adr:` 為「the authoritative source」,故新增 `gdd:`/`tr:`/`registered_by:` 三欄並在區塊註解說明,是該慣例的明文例外。**未來若有 ADR 正式承接其中任一項,把 `adr:` 改為該 ADR 路徑並保留 `gdd:` 欄。**
- registry 檔頭的 `WRITTEN BY: /architecture-decision` 慣例,本次由 `/architecture-review` 寫入 —— 理由是這三項已連續兩輪審查缺席,而「等一份專屬 ADR 才登記」等於讓約束在無人看守的狀態下繼續存在。
- `rng_in_combat_settlement` 的 `why:` 欄刻意寫入**唯一豁免**(好感度對話卡牌「發牌節奏固定、牌面隨機」,`game-concept.md` 第三輪 creative-director 裁決)。不寫的話,實作卡牌系統的人會直接撞上該裁決而不知該相信哪一份文件。

**順帶修正的過期宣稱**:`.claude/docs/technical-preferences.md` 的 `## Forbidden Patterns` 節原寫「None configured yet」,而 registry 當時已有 10 項。已改為指向 registry 為權威清單,並就地列出 3 項專案級裁決(它們在任何 ADR `Accepted` 之前就已生效,實作者需要能直接查到)。

**C2 已修正** — `adr-0003` 機制六:`validator` 回傳型別統一為 `ImportResult`(原寫 `ValidationResult`)。
**C4 已修正** — `adr-0004` 機制一:正式拍板 `write_temp()` 底層使用 `FileAccess.store_buffer()`,並引用 `breaking-changes.md` 已確認的 `bool` 回傳。
**C5 已修正** — `adr-0004` 機制五:標題改為「沿用 ADR-0001 的一般性原則;`RefCounted` 特有路徑未經單獨驗證」,並補一段說明兩種宿主失效路徑的差異,明訂 Verification Required 第 5 項的煙霧測試須涵蓋「`await` 期間宿主參照被釋放」這個 `RefCounted` 專屬情境。

### 仍待處理:C1 與 C3

兩者都會**新增或改變 ADR 的決策內容**,屬 `/architecture-decision` 的領域而非審查的領域,故刻意不在審查 session 內執行:

| | 建議解 | 為何留待 ADR 修訂 session |
|---|---|---|
| **C1** `TOKEN_TIMEOUT_MS` 無人擁有 | **由 ADR-0004 接下**:只有它掌握遷移鏈深度上界,擁有資訊的一方才有能力定這個數。ADR-0002 改為明文「本值由 ADR-0004 依鏈深度 × 每步讓出成本 + I/O 上界推導」 | 需新增一段推導論證,是撰寫工作而非修正工作 |
| **C3** `Mutex` 條件前提已消失 | **保留為縱深防禦**,但 ADR-0002 明文交叉引用 ADR-0004:「背景執行緒序列化已被排除;本 `Mutex` 是未來 `AsyncSaveIOBackend` 翻轉的前置準備,非當前執行模型的必要條件」 | 牽動 ADR-0002 的 Alternative 5 論證,須連同重讀 |

---

## Pre-gate 檢查

| 項目 | 狀態 | 需要的動作 |
|---|---|---|
| `tests/unit/` `tests/integration/` | ❌ | `/test-setup` |
| `.github/workflows/tests.yml` | ❌ | `/test-setup` |
| `design/accessibility-requirements.md` | ❌ | `/ux-design` |
| `design/ux/interaction-patterns.md` | ❌ | `/ux-design` |

四項全缺 —— `/gate-check pre-production` 目前不可執行。

`docs/consistency-failures.md` 不存在,依 skill 規定不建立,故本輪的 C1~C5 未寫入 reflexion log(僅存在於本報告)。

---

## 重跑建議

每寫完一份新 ADR 後重跑 `/architecture-review` 驗證涵蓋率確實改善。下一輪的最大單筆改善空間是**游標系統 ADR**(19 項,佔目前 56 項缺口的 34%);若同時完成戰棋演算法層 ADR,缺口可望降至 20 項以下。
