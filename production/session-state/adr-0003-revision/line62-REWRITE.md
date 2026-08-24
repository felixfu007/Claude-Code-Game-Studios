# line62 重寫 —— 二維框架(取代 line62-SUPERSEDED.txt)

**執行者**:security-engineer。**狀態**:草稿,待併入 ADR-0003 修訂本文,尚未寫入任何正式檔案。

---

## 1. 原宣稱錯在哪

ADR-0003 原文(第 62 行)宣稱「型別白名單問題結構性地不存在」。協調者的第一版收窄
把它改成「這個洞見在**讀取側**成立,在**寫入側**不成立」。**這個收窄後的版本仍然是假的。**

錯誤的根源是把問題當成**一維**的(「讀取側 vs 寫入側」),但實測顯示至少需要
**兩個維度**才描述得完整:**型別**(哪一個 Variant type)× **側**(寫入/讀取)。
一維框架把 39 個型別當成單一個體處理,而 `Object`(24)與
`RID`/`Callable`/`Signal`(23/25/26)在這兩個維度上的行為組合**互不相同**,
合併敘述必然漏掉其中一種组合。

**定義域檢查**:「讀取側成立」這句話,若指「`bytes_to_var()` 對含危險型別的輸入
一律拒絕」,其真實定義域是 **39 型別中的 1 個**(`Object`,含其所有子類別
`Resource`/`RefCounted`/`Node`),而不是「危險型別」這個措辭所暗示的全體
(`Object`/`RID`/`Callable`/`Signal` 四者)。這正是本專案第二次「收窄到看起來合理的
範圍,而該範圍仍然比實測範圍寬」的案例——第一次是原 ADR 的全稱宣稱本身。

---

## 2. 二維框架:四象限實測結果

| 型別 | 寫入側(`var_to_bytes()`,plain) | 讀取側(`bytes_to_var()`,plain) |
|---|---|---|
| **`Object`(24)**,含所有 `Resource`/`RefCounted`/`Node` 子類別 | ❌ **不擋**——靜默編碼成 `EncodedObjectAsID`(型別碼 + 8 bytes ObjectID),零錯誤、零丟棄 | ✅ **整包原子性失敗**——回傳 `null`,不中止呼叫函式,伴隨 `ERR_UNAUTHORIZED` 錯誤訊息 |
| **`RID`(23)/`Callable`(25)/`Signal`(26)** | ❌ **不擋**——編碼成功,零錯誤 | ❌ **也不擋**——成功解碼出來,零 `ERR_UNAUTHORIZED`、零丟鍵、零整包失敗 |

**證據(`Object` 列)**:
- 寫入側靜默編碼:`docs/engine-reference/godot/modules/core-serialization.md` 第 2 節;
  原始量測 `prototypes/xcheck-adr0003-2026-08-21/README.md` 「F2-f 寫入側」
  (`var_to_bytes({"alpha": 1, "poison": RefCounted.new()})` → size=60,零錯誤;
  `bytes_to_var()` 讀回得 `typeof=24` 的 `EncodedObjectAsID`,原欄位全部讀為 `<null>`)。
  同型行為在 `Resource` 上重現於探針 G:`prototypes/xcheck-adr0003-2026-08-21/README.md`
  「G-2a/b/c」(自訂 `class_name` 子類別與內建 `Resource.new()` 行為一致)。
- 讀取側原子失敗:`core-serialization.md` 第 3 節;原始量測同檔「F2 —— `bytes_to_var()`
  對本應解碼出 Object 的輸入」表(F2-a/b/c/g,含逐字錯誤訊息
  `ERROR: Condition "!p_allow_objects" is true. Returning: ERR_UNAUTHORIZED`)。

**證據(`RID`/`Callable`/`Signal` 列)**:
`core-serialization.md` 第 4 節逐字:「這三個型別**全部不受 `allow_objects` 那道閘門
管控**——plain `bytes_to_var()` 對三者一律零 `ERR_UNAUTHORIZED`、零丟鍵、零整包失敗,
`_with_objects` 變體與 1 引數版逐位元組相同。」原始量測見
`prototypes/xcheck-adr0003-2026-08-21/README.md` 探針 G「結果 / G-1」表格
(三型別「plain `var_to_bytes()` 是否成功」「plain `bytes_to_var()` 是否觸發
`ERR_UNAUTHORIZED`」兩列均為「✅ 成功」「❌ 完全不觸發」)。此結果在
`prototypes/save-format-skeleton-2026-08-21/README.md` 驗證 C 的讀取側毒藥向量表中
獨立重現(「`Signal`/`RID`/`Callable`」一列標註「✅ ✅ ✅ **對稱閘門**(引擎完全不擋)」)。

> **這張表本身即回答了指示中所附四象限表格是否有誤的問題**:核對後**未發現錯誤**——
> 指示中的表格與上述證據逐格相符,可直接採用。

---

## 3. 三個「兩側都不擋」型別的實際危害(性質互不相同,不可合併敘述)

`RID`/`Callable`/`Signal` 雖然在「是否被閘門擋下」這一點上表現相同(都不擋),
但**通過閘門之後的命運完全不同**,危害性質也不同——這正是原 ADR 用單一句子
（「型別白名單問題結構性地不存在」）沒有能力表達的地方。

### Signal —— 同行程內是全功能物件,`is_null()` 不能當守衛

- **同行程**:還原後 `get_object()` 拿到的是**活體物件**(與來源 `get_instance_id()`
  完全相同),`connect()` 回傳 `0`(OK),`emit()` **處理函式真的執行**
  (`emit_count` 從 0 變 1)。
  **證據**:`prototypes/xcheck-adr0003-2026-08-21/README.md` 探針 G「結果 / G-1」表
  Signal 欄;逐字 log 見
  `prototypes/xcheck-adr0003-2026-08-21/logs/probeG-callable-resource-unfiltered.txt`。
- **跨行程**:`get_object()` 變回 `<Object#null>`,`connect()` 回傳
  `3`(`ERR_UNCONFIGURED`,報 `Parameter "obj" is null."`),`emit()` 未送達。
  但 **`is_null()` 仍回傳 `false`**——這個守衛在跨行程情境下**會誤判為「非空」**,
  必須改用 `get_object() != null` 判定。
  **證據**:`prototypes/save-format-skeleton-2026-08-21/README.md` 階段 2「F-2 `Signal`」
  表,及「判讀陷阱」第 9 項(逐字:「`Signal.is_null()` 回 `false` 但 `get_object()`
  回 `null`——跨行程還原的 Signal 會通過 `is_null()` 這個守衛」)。

### RID —— 跨行程 id 可重現,指向真實存在的活體資源

`RID` 沒有 `Signal`/`Object` 那種「跨行程變惰性」的降級行為——它的 id 直接是伺服器
配置計數器的產物,**沒有 validator 計數這種保護**。實測:行程 1 存下
`get_id()=94489280512`,行程 2 **第一個** `PhysicsServer2D.body_create()` 配到的 id
**完全相同**,`還原的RID == 本行程新配的RID` 為 `true`。

**證據**:`prototypes/save-format-skeleton-2026-08-21/README.md` 階段 2「F-3 `RID`」
(逐字:「這一格就是『最壞情況』,而且實測成立」「這不是機率碰撞——兩次獨立執行
逐字相同」),同行程對照見 `prototypes/xcheck-adr0003-2026-08-21/README.md` 探針 G
「G-1e 的 RID 來源」段(採用 `PhysicsServer2D.body_create()`,量到
`is_valid=true`/`get_id=94489280512`)。**⚠️ 範圍限定**:僅實測
`PhysicsServer2D`,`RenderingServer`/`NavigationServer` 等其他伺服器**未查證**
(見 skeleton README「(d) 未查證」第 4 項)。

### Callable —— 空殼,但呼叫它會中止呼叫端函式

還原後是 `null::null` 空殼(`is_valid()=false`、`get_object()=<Object#null>`)——
綁定資訊(bound method 的目標物件、lambda 的閉包)從未寫進位元組流,裸值只有
4 bytes(僅型別標頭)。**呼叫這個空殼會中止呼叫端函式**:
`SCRIPT ERROR: Attempt to call function "null::null (Callable)" on a null instance.`,
且常見的守衛寫法(`has()`、`is Callable`)**兩者都會通過**,不會攔下這個中止。

**證據**:`prototypes/xcheck-adr0003-2026-08-21/README.md` 探針 G「結果 / G-1」表
Callable 欄與「G-N1」項;逐位元組編碼相同性見同檔「Callable 的細節」段。

### 資料是垃圾 vs. 控制代碼跨界指向活體資源——兩種不同性質的問題

- **`Object`(EncodedObjectAsID)是「資料是垃圾」型**:寫入側靜默遺失欄位,讀出的
  ID **同行程內**可用 `instance_from_id()` 復活成完整原物件(欄位齊全、同一實例),
  但**跨行程**已測 2,000 次物件配置、slot 範圍涵蓋舊 slot 後仍回傳 `null`——
  這是觀察到的行為、非引擎保證,但至少目前**未觀察到**跨行程復活。
  **證據**:`core-serialization.md` 第 2 節;`prototypes/save-format-skeleton-2026-08-21/README.md`
  階段 2「F-1 `EncodedObjectAsID`」。
- **`RID`/`Signal` 是「控制代碼跨界指向活體資源」型**:`RID` 已實測**具決定性地**
  指向新行程裡一個真實存在、屬於別人的活體資源(非機率碰撞);`Signal` 同行程內
  是全功能物件,跨行程降級為指向 nothing,但守衛判定本身有陷阱(`is_null()`)。
  這一類問題**不是「資料遺失」,而是「存檔裡的一個號碼,在另一個行程裡恰好對應到
  一個目前正在使用中的真實資源」**——危害的機制與 `Object` 完全不同,不能用同一句
  「型別白名單擋得住」去涵蓋。

**危害排序(沿用探針 G/骨架的排序,附出處)**:`Signal`(同行程時全功能)>
`RID`(跨行程仍是有效的伺服器 handle,且已證實具決定性)> `Callable`(空殼,
但誤用會中止呼叫端函式)。**證據**:`core-serialization.md` 第 4 節「危險程度排序」列;
`prototypes/xcheck-adr0003-2026-08-21/README.md` 探針 G「E1 的一句話答案」段。

---

## 4. 由此推導出的架構義務(推論,依 §2/§3 的實測結果推導)

1. **寫入側閘門不可省**:`Object` 在寫入側被引擎靜默放行(編成 `EncodedObjectAsID`),
   `RID`/`Callable`/`Signal` 在寫入側也被引擎靜默放行——**四個危險型別在寫入側全部
   沒有引擎層級的安全網**。若只做讀取側閘門,含這四種型別的存檔仍會被成功寫出。
2. **讀取側獨立掃描不可省,且不能只擋 `Object`**:`bytes_to_var()` 只在 `Object`
   一個型別上提供拒絕行為;`RID`/`Callable`/`Signal` 三者讀取側**全部靜默通過**。
   若讀取側只依賴引擎既有的 `ERR_UNAUTHORIZED` 機制(即只防 `Object`),存檔裡的
   `RID`/`Callable`/`Signal` 會被成功解碼並进入應用層,而其後果如 §3 所述並非均等
   ——`Signal`/`RID` 可能是活體資源的參照,`Callable` 呼叫會中止呼叫端函式。
3. **寫入側與讀取側閘門必須擋同一組型別(至少 {23 RID, 24 Object, 25 Callable, 26 Signal}),
   且建議共用同一份實作**——避免兩處清單各自維護、各自漂移成不同的集合(此為推論:
   已量到的是「引擎在兩側都不管這四個型別」,「共用實作可避免漂移」屬工程判斷而非
   量測結果,已在 `production/session-state/adr-0003-revision/CROSSCHECK.md`
   「兩軌獨立收斂」欄位記錄為 security-engineer 與 godot-gdscript-specialist
   各自獨立得出的一致結論)。

---

## 5. 自我核對表(每一個範圍限定詞的定義域)

| 本文用語 | 措辭字面範圍 | 實際定義域 | 是否相符 |
|---|---|---|---|
| 「這三個型別**全部**不受 `allow_objects` 那道閘門管控」 | RID/Callable/Signal 三者 | 探針 G 逐一測了三者的 `var_to_bytes`/`bytes_to_var` 行為,三者結果一致 | ✅ 相符(定義域=措辭範圍,3=3) |
| 「`Object`(24,**含所有** Resource/RefCounted/Node)」 | Object 及其一切子類別 | 已測:內建 `RefCounted`、自訂 `class_name` `RefCounted` 子類、自訂 `class_name` `Resource` 子類、內建 `Resource.new()`——四種形狀皆同一行為。`Node` **未在探針 F/G 中實測**(仅 skeleton README「(d) 未查證」第6項標註「`Node` 未測」) | ⚠️ **不完全相符**——「含所有」對 `Node` 是推論延伸,非直接量測 |
| 「跨行程仍是有效的伺服器 handle」(RID) | 一般化的「伺服器」 | 僅實測 `PhysicsServer2D.body_create()` 一種伺服器 | ⚠️ 已在 §3 RID 段落加註「僅實測 PhysicsServer2D」的範圍限定,不宜再擴大到其他伺服器 |
| 「`is_null()` **仍**回傳 `false`」(Signal) | 泛指跨行程情境 | 僅實測「來源物件在寫入時存活,程式結束後於新行程讀取」這一種跨行程情境;「來源物件在同行程內先死亡再讀」**未測**(skeleton README「(d)」第5項) | ✅ 本文措辭已限定為「跨行程」,未逾越量測範圍 |
| 「已測 2,000 次物件配置...仍回傳 `null`」(EncodedObjectAsID 跨行程) | 特定次數與情境 | 具體數字直接引自 log,非推論 | ✅ 相符,且已明文加註「觀察到的行為,非引擎保證」 |
| 「不是機率碰撞」(RID 跨行程) | 具決定性 | 兩次獨立執行(探針 G 同行程 + 骨架跨行程)id 逐字相同,来自同一決定性配置計數器機制 | ✅ 相符,來源明確標註「兩次獨立執行逐字相同」 |

**本文沒有使用「一律」「全部」等全稱量詞去描述超出上表定義域的宣稱**——僅有的
「全部」用法(RID/Callable/Signal 三者)已核對定義域相符。

---

## 6. 無法附出處的宣稱

無。本文所有具體行為宣稱均可追溯至上列探針 log 或 README;§4「架構義務」段落中
標記為「推論」的部分已明文區分,不與量測結果混列。

---
---

# Consequences → Negative 補充:兩塊未受完整性標記涵蓋的區域(組合後果)

**執行者**:security-engineer。**擬併入位置**:ADR-0003「Consequences → Negative」。
**性質**:組合後果分析,結合兩項已各自存在、但從未合併檢視的既有決策/行為。
**建議處置**:登記為延後項,**不阻擋本次修訂**——等實作階段再決定是否擴大頂層雜湊
的涵蓋範圍。

## 背景:兩項各自獨立、各自有理由的決定

1. **信封層未知額外鍵——2026-08-24 管理者裁決:忽略,不拒絕。**
   `production/session-state/adr-0003-revision/CROSSCHECK.md`「🔨 衝突 2 已裁決」段:
   「與骨架 c-14 的既有行為一致,與延後清單 D-13 記錄的決定一致……換到的是:未來加
   欄位不必升版本號、新舊版存檔仍可互通」。
2. **`blocks` 字典的額外條目——骨架既有行為 c-4。**
   `prototypes/save-format-skeleton-2026-08-21/README.md`「(c) 設計沒講到」表 c-4:
   「`blocks` 的鍵集合不被任何雜湊涵蓋。manifest 少一條 → 頂層雜湊抓到;但 `blocks`
   少一條 → 頂層雜湊完全看不到」,決定為「在 S4 加明確守衛……刻意不把它提前到 S1B」,
   其副作用逐字記載:「**`blocks` 裡多出來的條目會被靜默忽略(從未讀取、從未檢查)**」。

兩項單獨看都有各自的工程理由(前者換取格式演進彈性,後者是「manifest↔blocks
交叉檢查該放哪一關」這個設計張力下的必要取捨,c-4 原文明說「兩者不能同時滿足」)。

## 頂層雜湊的實際涵蓋範圍(用於界定「未受涵蓋」的精確意思)

頂層雜湊的輸入是 `(ruleset_version, block_manifest 依 source_id 字典序排列的 tuple
清單)`——**不包含** `blocks` 字典本身的鍵集合,也不包含信封層任何未列在
必要鍵清單中的欄位。**證據**:
`production/session-state/adr-0003-revision/draft.md` 第 51 行(「manifest 頂層雜湊
(涵蓋規則集版本號 + 逐區塊 tuple 清單……)」)、第 104 行(重算公式)、第 224 行
(`compute_top_level_hash(ruleset_version, block_manifest)` 簽章——參數只有這兩個)。

## 組合後果:兩塊區域都不受頂層雜湊涵蓋,但風險輪廓不同——不可等量齊觀

合起來看,存檔裡確實存在**兩塊不受頂層雜湊涵蓋的區域**。但這兩塊區域被下一層
防線(型別閘門)涵蓋的程度**並不相同**,必須分開講清楚,否則會把兩者的風險
誤判為同一等級。

### 區域一:信封層未知額外鍵——型別閘門仍會掃到

依 gdscript 專家的既有設計,`deserialize_manifest()` 的順序是
`bytes_to_var()` → **`SaveTypeGate.validate_payload(整個信封)`** → `check_shape()`。
型別閘門跑在形狀檢查**之前**,而且掃描對象是**整個信封 Dictionary**(遞迴掃描
所有鍵與值)。因此即使信封層出現一個未列在必要鍵清單中的額外鍵,它的**內容**仍會
被這道閘門掃過。

| 未知欄位能夾帶什麼 | 是否可行 |
|---|---|
| `RID`/`Object`/`Callable`/`Signal`(危險型別,見上半篇二維框架) | ❌ **擋得住**——型別閘門涵蓋整個信封,§2 表格四個危險型別無論放在信封的哪個位置都會被掃到並拒絕 |
| 一般資料(字串、數字、陣列等白名單型別) | ✅ 可夾帶,且**不受頂層雜湊保護**——放進去之後,即使被外部竄改,`top_level_hash` 比對仍會通過(因為它本來就沒涵蓋這個鍵) |

**⚠️ 界線務必寫準,不要誇大**:管理者的裁決只開放了「任意資料」這一面,
**沒有**開放「危險型別」那一面。這一點在原提問時沒有明講,此處補記以免日後
誤解裁決範圍。**證據**:`CROSSCHECK.md`「⚠️ 協調者向管理者提問時漏講的一項保護」段,
逐字表格與此處一致。

### 區域二:`blocks` 的額外條目——型別閘門**不會**掃到內容,是更深的盲區

`blocks` 字典本身是信封的一部分,所以它的**外層形狀**(每個值的外層型別是否為
`PackedByteArray`)會被信封層型別閘門掃到。但 `blocks` 的值是**已經序列化過的
巢狀 `PackedByteArray`**——依 gdscript 專家已裁決的設計(見
`CROSSCHECK.md`「📌 新開的未查證項」c 項:「閘門對已序列化的巢狀 `PackedByteArray`
該不該打開來掃?……gdscript 已決定:不打開,視為葉節點」),信封層型別閘門**不會
解碼**這個 `PackedByteArray` 的內容,只把它當成一個不透明的葉節點通過。這個設計
本身已由 F4'-a 驗證為安全前提的一部分(manifest 層讀取不遞迴解讀區塊內容,
見上半篇 §2 引用的 `core-serialization.md`)。

而**具體到 `blocks` 額外條目**——即 `blocks` 字典裡存在一個 `source_id` 不在
`block_manifest` 中的條目——c-4 已明文記載這種條目「從未讀取、從未檢查」,也就是
它**永遠不會被送進 `deserialize_block()`**(該函式才是真正對區塊內容做
「讀取側對稱型別閘門」的地方,見骨架驗證 C 讀取側毒藥向量表)。

**結論(推論,綜合上述兩項已測事實推導,非單獨一次量測)**:`blocks` 額外條目的
**位元組內容**,目前的設計下**不會被任何一道型別閘門檢查**——既不是信封層閘門
(視為葉節點,不開封)、也不是逐區塊閘門(從未被選中解碼)。它比區域一更深一層:
區域一至少保證「危險型別擋得住,只有一般資料能夾帶」;區域二連這個保證都沒有——
一段完整編碼的危險型別位元組理論上可以原封不動地放在一個孤兒 `blocks` 條目裡,
不觸發雜湊不符,也不觸發任何一道型別閘門的拒絕。**但需同時說清楚它不是一個可
即時利用的攻擊面**:因為這段位元組從未被 `bytes_to_var()` 解碼,危險型別本身
不會被「解出」成活體 `Signal`/`RID` 控代碼或空殼 `Callable`——它就是一段永遠
不會被讀取的死位元組,除非未來實作變更成「遍歷 `blocks` 全部鍵」而非「只依
`block_manifest` 選讀」,那時才需要重新評估是否要在該路徑上補一道閘門(這是
針對假設中的未來變更的推論,不是對現行程式碼的宣稱)。

### 兩塊區域的風險輪廓對照

| | 區域一:信封層未知額外鍵 | 區域二:`blocks` 額外條目 |
|---|---|---|
| 受頂層雜湊涵蓋 | ❌ 否 | ❌ 否 |
| 受型別閘門涵蓋(危險型別會被擋) | ✅ 是 | ❌ 否(內容從未被開封檢查) |
| 可夾帶什麼而不觸發任何檢查 | 一般資料(字串/數字/陣列) | 任意位元組,理論上包含危險型別的完整編碼 |
| 該危險型別是否會被「解出」成活體控代碼 | 不適用(已被閘門擋下,不會寫入/讀出) | 不會——除非未來變更讀取路徑改為遍歷全部 `blocks` 鍵 |
| 目前性質 | 未受完整性保護的「合法資料」旁路 | 未受完整性保護**且**未受型別檢查的「不透明位元組」盲區,目前不可觸發解碼 |

## 建議登記為延後項

建議在延後清單(依循 `adr-0003-deferred-to-implementation.md` 既有格式)新增一條,
記錄以下待實作階段裁決的問題:

- 是否要把頂層雜湊的涵蓋範圍擴大到包含 `blocks` 的鍵集合(可偵測「多了/少了
  一個區塊」而不必依賴 S4 的個別守衛)?
- 若日後任何程式碼路徑改為遍歷 `blocks` 全部鍵(而非只依 `block_manifest` 選讀),
  是否需要在該路徑上額外掛一道型別閘門(現行 `deserialize_block()` 那一道只在
  被 manifest 選中時才會執行)?
- 信封層是否需要一個「已知但未使用」的稽核記錄(例如記錄下有哪些未知鍵/孤兒
  區塊被忽略),供人工排查存檔異常時使用?這不是安全性要求,是可觀測性要求。

**威脅模型範圍註記**:以上分析全部在單機、無連線威脅模型下進行——攻擊面是本機
存檔檔案被使用者本人或本機其他程式修改,不涉及網路傳輸或多人連線。所有引用的
量測結果均取自 debug/headless 建置,release build 下是否維持一致**未查證**
(`core-serialization.md`「未查證」第 1 項;`save-format-skeleton-2026-08-21/README.md`
「(d) 未查證」第 1 項),本文不宣稱這些行為在 release build 下同樣成立。
