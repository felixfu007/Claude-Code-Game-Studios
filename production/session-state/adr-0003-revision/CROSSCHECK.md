# 三方產出交叉比對

## security-engineer(已交付 2026-08-24)

### 🔴 修正協調者草稿:line62.txt 的框架本身是錯的

協調者寫「這個洞見在**讀取側成立**,在寫入側完全不成立」。**錯。**

實測(`modules/core-serialization.md` 第 4 節,逐字):
> 這三個型別(`RID`/`Callable`/`Signal`)**全部不受 `allow_objects` 那道閘門管控**
> —— plain `bytes_to_var()` 對三者一律零 `ERR_UNAUTHORIZED`、零丟鍵、零整包失敗。

**正確的框架是二維的,不是「讀取側 vs 寫入側」:**

| 型別 | 寫入側 | 讀取側 |
|---|---|---|
| `Object`(24,含所有 Resource/RefCounted/Node) | ❌ 靜默編成 EncodedObjectAsID | ✅ 整包原子性失敗 |
| `RID`(23) / `Callable`(25) / `Signal`(26) | ❌ 不擋 | ❌ **也不擋** —— 成功解碼出來 |

**後果**:ADR 原句「型別白名單問題結構性地不存在」的定義域是 **39 型別裡的 1 個**,
而措辭是全稱。協調者的修訂草稿把它收窄成「讀取側成立」—— **收窄後仍然是假的**。

⚠️ 這是本專案「收窄宣稱到實測範圍,收窄後仍被否證」的**第二次**
(第一次是 2026-08-21 的草案)。**line62.txt 作廢,待重寫。**

### 其他裁決(採納)
- 寫入側 fail-closed,拒絕整次寫入;既有存檔因原子寫入天然不受影響,傷害上限是「這次沒存到」
- 寫入側失敗**不可**併入 `ReadRejection`(語意不同),應匯入既有的「寫入失敗偵測」路徑
- 讀取側**必須**新增一道獨立掃描(解碼後、語意驗證前),擋 23/25/26 —— 現有機制三步驟 5 完全沒管到
- 該掃描應與寫入側**共用同一份實作**,避免兩套邏輯各自漂移
- **Dictionary 的鍵也要掃**,不能只掃 values()(GDScript 允許任何 Variant 當鍵)
- 遞迴掃描的**回傳型別選擇會影響安全性**:若用帶欄位的結果物件而非 bool,堆疊溢位展開時會在 null 上取屬性,從「意外安全」變成「呼叫端無聲中止」
- 威脅模型**不擴大**,但需精確化:區分「資料是垃圾」與「控制代碼跨界指向活體資源」
- `NodePath`(22)不列入拒絕(合法常用),但消費端不得拿存檔裡的路徑直接餵 `get_node()`

## 協調者對 security-engineer 的反查(一項不成立)

**他說 VR#4(巢狀 PackedByteArray 往返保真 / 外層不遞迴解讀)「至今仍未查證」—— 不成立。**
探針 F4'-a 已測:外層一次解碼得 `typeof=27`,`blocks['...']` 為 `typeof=29`
(**TYPE_PACKED_BYTE_ARRAY,未解碼**),與 `inner_buf` `==` 為 true、hex 逐位元組相同、
長度皆 160。協調者的 line20 草稿標「✅ 關閉」**正確**。

**但他的誤判有正當原因,且指出一個真缺口**:證據在探針 README,**不在**參考庫
`core-serialization.md`(我叫他信參考庫)。→ **參考庫該補這條**(待辦)。

**而他真正問的是另一個問題,那個確實開著**:若某區塊 payload 裡巢狀了一個
**已經序列化過的** `PackedByteArray`,閘門該掃「解碼前的原生 Dictionary」還是
**打開內層緩衝區一起掃**?這是**閘門掃描範圍的定義問題**,不是往返保真問題。
→ **新開問題,需交 GDScript 專家裁決。**

## 待其他兩份產出
- [ ] godot-gdscript-specialist(第 3/5/6 組契約)
- [ ] godot-specialist(第 2/4 組 + 覆核 line58/line62/檔頭風險等級)

---

# 三份全數交付 —— 完整交叉比對(2026-08-24)

## ✅ 兩軌獨立收斂(最強訊號)

`security-engineer` 與 `godot-gdscript-specialist` **互不知道對方寫什麼**,結論一致:

| 項目 | 收斂結果 |
|---|---|
| 必須拒絕的型別 | **兩邊都是 {23 RID, 24 Object, 25 Callable, 26 Signal},一字不差** |
| `NodePath`(22) | 兩邊都主張**不**拒絕(合法常用),但消費端不得直接餵 `get_node()` |
| 寫入側失敗**不可**併入 `ReadRejection` | 一致(gdscript 另開 `GateRejection` + `WriteResult`) |
| 讀取側需要獨立閘門 | 一致 |
| 寫入/讀取**共用同一份實作** | 一致 |
| Dictionary 的**鍵**也要掃 | security 提出,gdscript 實作且更嚴(鍵白名單只留 String/StringName/int) |

`hash_matches()` 先驗長度再比內容:`godot-specialist` 與 `godot-gdscript-specialist`
**各自獨立寫出同一個函式**,理由也相同(兩邊都失敗時空陣列 `==` 會假通過)。

## 🔴 需協調者裁決的真衝突

### 衝突 1(最重要):我的 line62 到底對不對 —— 兩位專家互相矛盾

- `security-engineer`:**框架錯了**。「讀取側成立」是假的,`bytes_to_var()` 對 23/25/26 完全不擋
- `godot-specialist`:**逐句核對全部成立**,並說「這個修訂精準指出它只在讀取側成立——這個批評本身是準確的」

**裁決:security-engineer 對。** 依據是 `godot-specialist` **自己寫的**
`modules/core-serialization.md` 第 4 節逐字:
> 這三個型別**全部不受 `allow_objects` 那道閘門管控**——plain `bytes_to_var()` 對三者
> 一律零 `ERR_UNAUTHORIZED`、零丟鍵、零整包失敗。

⚠️ **引擎專家背書了一個他自己的參考文件所否證的框架。**
而他同一份報告裡又建議「line62 漏了 Signal,而 Signal 是三者中最危險的」——
**他注意到了症狀,卻沒把它連回框架本身是錯的**。

→ **line62.txt 作廢**,重寫為二維表(Object 讀取側擋/寫入側不擋;RID/Callable/Signal 兩側都不擋)。
→ 這也證明了平行雙軌的價值:單靠引擎專家這一軌,錯誤會原樣進入文件。

### 衝突 2:信封層的未知額外鍵,兩位專家主張相反

- `godot-gdscript-specialist`:**拒絕**(推翻骨架的「忽略」)。理由:格式演進該走版本號,不該開旁路
- `godot-specialist`:信封層應**維持寬容**(「預留未來版本擴充的彈性」),嚴格只該用在 manifest **entry** 層

→ **未裁決,需管理者或 TD 決定。** 這會影響未來能不能不升版本號就加欄位。

### 衝突 3:兩份欄位清單各自維護(漂移風險)

`godot-specialist` 明文要求:S1B 形狀檢查與雜湊 canonicalization **必須共用同一份
`MANIFEST_ENTRY_FIELDS`**,否則兩處清單漂移會重演同一種洞。

但 `godot-gdscript-specialist` 的 `SaveEnvelope.REQUIRED_MANIFEST_ENTRY_KEYS` 是**獨立常數**,
與雜湊那一側無關聯。→ **兩份清單,正是被警告的形狀。必須合併。**

## ⚠️ 協調者反查出的專家錯誤

1. **`godot-specialist` 說 `draft.md` 只有 13 行、且檔頭改動「已經在正式檔案裡」——不成立。**
   實測:`git status docs/architecture/` 乾淨;正式檔 `MEDIUM` 零命中、`機制一之二` 零命中;
   `draft.md` 是完整 350 行且含 MEDIUM。他評的內容是對的(確實是我的草案),但**檔案位置說錯**。
   ⚠️ 若照他的話行事,會誤以為正式檔已被修改。

2. **但他由此得出的發現是對的,而且重要**:我的草案檔頭表格**前向引用了兩個還沒寫的章節**
   (「機制一之二」「機制四之二」)。表格說「已關閉、詳見某節」,而那一節是空的 ——
   這正是 `consistency-failures.md` 記錄的模式。**併入時必須先有內文再有引用。**

3. **`security-engineer` 說 VR#4「至今仍未查證」——不成立**,探針 F4'-a 已測(見前段)。
   但誤判有正當原因:證據在探針 README,不在參考庫。→ 參考庫待補。

4. **`godot-gdscript-specialist` 的深度數字差一**:他寫「骨架實測 64 通過、65 被擋」,
   骨架 README 第 158 行實際是「10/62/63 → NONE;**64**/65/100 → DEPTH_EXCEEDED」,
   即 **63 通過、64 被擋**。機制不受影響,但數字要改對。
   (另注意:延後清單 D-5 的「256 可正常往返」講的是**引擎能力**,不是閘門上限,兩者不衝突。)

## 📌 新開的未查證項(本輪產生)

| # | 項目 | 誰提出 |
|---|---|---|
| a | `FileAccess.store_var()` 與全域函式「共用同一線格式」**是繼承自舊稿的推論,本輪未量測** | godot-specialist |
| b | `HashingContext.update()` 傳空陣列**之後**,同一 context 後續 `update()` 是否仍正常累積(只測過單次情境) | godot-specialist |
| c | 閘門對**已序列化的巢狀 `PackedByteArray`** 該不該打開來掃 | security(gdscript 已決定:不打開,視為葉節點) |
| d | `assert()` 在 release build 是否被移除(gdscript 因此改用 `push_error()`+回傳值,屬預防性選擇) | gdscript |

→ (d) 已有登記:registry `silent_freeze_fallback_for_invalid_provider` 的 `why:` 欄
記著「`push_error()` 不是 `assert()`;`assert()` 在 release 依設計被移除」但標明
**impression-high-confidence,非本專案驗證**。應引用該處,不要各自重述。

## 待辦(協調者)
- [ ] 重寫 line62(二維表)
- [x] 裁決衝突 2(管理者:忽略)
- [ ] 從 check_shape() 移除額外鍵拒絕邏輯
- [ ] Consequences 補「兩塊未受雜湊涵蓋的區域」組合後果 + 登記延後項
- [ ] 修正衝突 3(合併兩份欄位清單)
- [ ] 修正深度數字 63/64
- [ ] line58 的「共用線格式」標為推論
- [ ] 併入順序:先寫機制一之二、機制四之二**內文**,再讓檔頭表格引用它們
- [ ] 一行級 7 項
- [ ] 然後才跑 Step 5.5 / 5.6 正式覆核

---

# 🔨 衝突 2 已裁決 —— 管理者 2026-08-24

## 裁決:**忽略**(信封層出現未知額外鍵時不拒絕,維持現狀)

- 與骨架 c-14 的既有行為一致,與延後清單 D-13 記錄的決定一致
- 採 `godot-specialist` 的立場;**推翻 `godot-gdscript-specialist` 的「拒絕」建議**
- 換到的是:未來加欄位不必升版本號,新舊版存檔仍可互通

## 對草案的具體影響

**必須從 `SaveEnvelope.check_shape()` 移除這段**(gdscript 專家寫的):
```gdscript
# 額外鍵一律視為損毀 —— 見下方 D-13 決策說明
for key_name in envelope:
    if not REQUIRED_TOP_LEVEL_KEYS.has(key_name):
        return SaveFormat.ReadRejection.DATA_CORRUPTED
```
其餘檢查(必要鍵存在、型別正確、雜湊長度 32、`source_id` 不重複)全部保留。

## ⚠️ 協調者向管理者提問時**漏講**的一項保護(對他有利,補記)

依 gdscript 專家的設計,`deserialize_manifest()` 的順序是:
`bytes_to_var()` → **`SaveTypeGate.validate_payload(整個信封)`** → `check_shape()`

**型別閘門跑在形狀檢查之前,而且掃的是整個信封** —— 所以即使未知欄位被放行,
**它的內容仍然會被型別閘門遞迴掃過**。結論:

| 未知欄位能夾帶什麼 | 是否可行 |
|---|---|
| `RID` / `Object` / `Callable` / `Signal`(危險型別) | ❌ **擋得住** —— 型別閘門涵蓋整個信封 |
| 一般資料(字串、數字、陣列) | ✅ 可夾帶 |
| 夾帶後再被外部修改 | ✅ 可修改,且**不受完整性標記保護**(頂層雜湊只涵蓋版本號 + 區塊清單) |

→ 管理者的選擇因此**只開放「任意資料」的面,沒有開放「危險型別」的面**。
   這一點在提問當下沒說到,現在補記以免日後誤解裁決範圍。

## 🔴 這個裁決使一項既有缺口變得更需要盯

信封層寬容 + `blocks` 額外條目也被忽略(骨架 c-4)= **兩個都不受雜湊涵蓋的面**。
兩者單獨看都有理由,合起來看是**存檔裡有兩塊沒人管、也沒人驗的區域**。

**建議(不阻擋本次修訂)**:在 Consequences → Negative 明文寫下這個組合後果,
並登記為延後項,等實作階段決定要不要把頂層雜湊的涵蓋範圍擴大。
→ 已加入待辦。
