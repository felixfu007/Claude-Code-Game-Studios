# 讀取流程三處取代文字

**目標檔案**:`production/session-state/adr-0003-revision/draft-v2.md`。以下三段可直接
貼進對應位置取代原文。取代後的引用一致性核對與需要同步調整的相鄰參照,列在文末。

---

## (i) 第 660 行 —— 機制三步驟 5,拆為 5a / 5b

**原文(第 660 行)**:

> 5. 通過雜湊驗證的區塊,以 `bytes_to_var(buffer)` 解碼其 `PackedByteArray`,取得該區塊的 payload `Dictionary`——此呼叫本身即是型別白名單閘門(機制一),解碼失敗(例如位元組本應解碼出一個 Object)視為 `DATA_CORRUPTED`。

**取代文字**:

5a. 通過雜湊驗證的區塊,以 `bytes_to_var(buffer)` 解碼其 `PackedByteArray`,取得結果 `decoded`。**這一步只擋一件事**:若位元組流本應解碼出一個 `Object`(typeof 24,含所有 `Resource`/`RefCounted`/`Node` 子類別),`bytes_to_var()` 對此整包解碼原子性失敗,回傳值不是 `Dictionary`。判定一律用 `decoded is Dictionary`,不用 `!= null`——全零 16 bytes 是合法的 NIL 編碼,`bytes_to_var()` 對它回傳 `null` 且零錯誤訊息,`!= null` 會把這種損毀誤判為成功。`decoded` 不是 `Dictionary`(涵蓋 Object 解碼失敗與任何其他非預期型別)一律視為 `DATA_CORRUPTED`。

5b. 對 5a 取得的 `decoded` payload,呼叫 `SaveTypeGate.scan(decoded)`(機制一之二)做獨立遞迴掃描,拒絕集合為 {23 `RID`、24 `Object`、25 `Callable`、26 `Signal`}。**這一步擋的是 5a 完全不擋的三個型別**:`RID`/`Callable`/`Signal` 在引擎讀取側不觸發任何拒絕行為,會被 `bytes_to_var()` 成功解碼並回傳,只有這道獨立掃描會擋。**這一步必須在步驟 6(語意驗證/遷移鏈)之前執行**——遷移函數操作的是已解碼的資料,型別閘控若晚於遷移鏈,危險型別會先被遷移函數讀取過一輪才被擋下(見機制七)。掃描結果是機制一之二定義的 `SaveTypeGate.GateResult`,其 `rejection` 欄位型別是 `GateRejection`——**不是** `SaveFormat.ReadRejection`;呼叫端讀到 `not gate.ok()` 時,對外一律轉譯為 `SaveFormat.ReadRejection.DATA_CORRUPTED`,兩個列舉本身不互通、不可混用其數值。

（步驟 6 內容不變,銜接 5b 的輸出。）

**證據**:
- `Object` 讀取側整包原子性失敗:`docs/engine-reference/godot/modules/core-serialization.md` 第 3 節;`prototypes/xcheck-adr0003-2026-08-21/README.md`「F2 —— `bytes_to_var()` 對本應解碼出 Object 的輸入」表。
- `RID`/`Callable`/`Signal` 讀取側完全不受 `allow_objects` 閘門管控:`core-serialization.md` 第 4 節逐字「這三個型別全部不受 `allow_objects` 那道閘門管控」;`prototypes/xcheck-adr0003-2026-08-21/README.md` 探針 G「結果 / G-1」表。
- 讀取側獨立掃描的必要性(四種毒位元組全部靜默通過 `bytes_to_var()`,只有閘門擋得住):`prototypes/save-format-skeleton-2026-08-21/README.md` 驗證 C 讀取側表(第 165–181 行)。
- `is Dictionary` 而非 `!= null` 的判定規則:`core-serialization.md` 第 3 節「`size()==0` 是可靠的失敗訊號,`== null` 不是」專節。
- 型別閘控須先於遷移鏈:本檔機制七(型別白名單版本域範圍問題的消解,Open Question 4)——見下方「順序核對」。

---

## (ii) 第 931–932 行 —— Architecture Diagram,一分為二並新增一個方框

**原文**:

```
                                          ④bytes_to_var(buffer) 解碼
                                            (= 型別白名單閘門)
                                                              │
                                                              ▼
                                          ⑤SaveBlockRegistry.get_validator(source_id)
                                            → validate_semantics() / 遷移鏈(下一份 ADR)
```

**取代文字**(縮排比照原圖:圈號行前 42 格空白,連接線 `│`/`▼` 前 62 格空白,括號附註行前 44 格空白):

```
                                          ④bytes_to_var(buffer) 解碼
                                            (只擋 Object,見機制一之二)
                                                              │
                                                              ▼
                                          ⑤SaveTypeGate.scan(payload) 獨立遞迴掃描
                                            (擋 RID/Object/Callable/Signal,機制一之二)
                                                              │
                                                              ▼
                                          ⑥SaveBlockRegistry.get_validator(source_id)
                                            → validate_semantics() / 遷移鏈(下一份 ADR)
```

原本的 ⑤ 現為 ⑥,語意不變,只是編號後移一位以容納新增的方框。

---

## (iii) 第 52 行——判定:不需要更動

原文:

> 5. **讀取路徑檢查順序**(Core Rules #16,本輪鎖定):頂層完整性標記 → 規則集版本比對(`VERSION_TOO_NEW` 短路)→ 型別白名單閘門 → 語意驗證/遷移鏈。

這一句只是把「型別白名單閘門」當成流程裡一個**具名步驟**來指涉,沒有寫成「這個步驟就是 `bytes_to_var()` 這個呼叫」——它與 (i)/(ii) 的差別在於:(i)/(ii) 明確斷言「解碼呼叫本身即是型別白名單閘門」(把兩件事等同),這一句沒有做這個等同,只是說順序上有這麼一個步驟。而且全篇現在只有一個具體、有明確定義的「型別白名單閘門」實體——機制一之二定義的 `SaveTypeGate`——讀者讀到這句時唯一能對應到的具名機制就是它,不會被誤導成單指引擎的 `bytes_to_var()` 原生行為。**不需要更動。**

---

## 順序核對(依要求逐一比對)

引擎專家在機制七(型別白名單版本域範圍問題的消解,Open Question 4)寫下的順序主張:

> 型別閘控必須發生在遷移鏈之前(遷移函數本身會操作已解碼的資料),語意驗證在遷移之後,不能替代型別閘控。

比對機制一之二已定案的讀取側接入點順序(`deserialize_block()`/`deserialize_manifest()`):

```
bytes_to_var(buffer) → decoded is Dictionary? → SaveTypeGate.scan(decoded) → [語意驗證 / 遷移鏈]
```

以及上面 (i) 拆出的 5a(解碼)→ 5b(`SaveTypeGate` 獨立掃描)→ 6(語意驗證/遷移鏈)——**兩者順序一致**:`SaveTypeGate` 的掃描(5b)在語意驗證與遷移鏈(6)之前執行,對每一個需要被讀取的區塊皆然,不論該區塊之後是否還需要進入遷移鏈。這代表遷移函數在拿到 payload 之前,payload 已經先通過型別閘控,滿足機制七要求的順序。**一致,沒有發現衝突。**

**一項超出本次核對範圍、但值得記錄的觀察(推論,非本次要求解決)**:機制一之二與機制三保證的是「進入遷移鏈**之前**的 payload 已通過 `SaveTypeGate`」,但沒有宣稱「遷移鏈**每一步的輸出**也會被重新掃描」。若某個遷移函數本身有缺陷、意外在輸出的 `Dictionary` 裡引入了一個危險型別,現行順序不會攔到——這在後續進入 `validate_semantics()` 前，並不會重新觸發 `SaveTypeGate`。這屬於遷移執行模型(下一份 ADR)的範圍,本文件目前的措辭沒有對此做任何(隱含或明確的)保證,故不構成矛盾,僅提示下一份 ADR 定案遷移鏈時需要明確這一點是否需要處理。

---

## 因應 (i)/(ii) 拆分,需同步更新的既有參照(否則會產生新的不一致)

以下兩處不是同一個假框架的重複出現,而是**因為 (i)/(ii) 把一步拆成兩步/一個圈號拆成兩個**,若不同步更新,會變成指向錯誤步驟的懸空參照:

1. **第 1049 行**(TR-save-002 對應表):「……讀取順序上型別閘控(機制三步驟 5)先於語意驗證/遷移(步驟 6)不變」——這句本身內容正確(它已經正確區分了 `Object` 由引擎原生行為擋下、`RID`/`Callable`/`Signal` 由本 ADR 機制一之二擋下,不是本次要處理的假框架)。但「機制三步驟 5」拆分後應改為「機制三步驟 5b」,因為型別閘控具體對應的是新拆出的 5b,不是整個原步驟 5(5a 只是解碼)。建議取代文字:「……讀取順序上型別閘控(機制三步驟 5b)先於語意驗證/遷移(步驟 6)不變」。

2. **第 982 行**(`SaveReader.read_block()` 契約註解):「執行機制三步驟 ①~⑤」——這裡的圈號對應的是 Architecture Diagram 的圈號,而 (ii) 把原本的 ④ 拆成 ④+⑤,原本的 ⑤ 後移為 ⑥。若 diagram 依 (ii) 更新,這裡的範圍需同步改為「①~⑥」。建議取代文字:「執行機制三步驟 ①~⑥」。

兩處都只是編號指涉,內容本身沒有錯誤框架問題,但若整合時只換掉 (i)/(ii) 而漏掉這兩處,會製造出「文字說步驟 5、圖上卻找不到單一步驟 5」的新不一致——這正是本專案已登記的「修東西反而修出新問題」模式,所以一併列出。
