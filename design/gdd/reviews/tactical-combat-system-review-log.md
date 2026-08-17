# Review Log — `design/gdd/tactical-combat-system.md`(戰棋移動與交戰系統)

> **本檔建立於 2026-08-17 第三輪 `/design-review`** —— 第一、二輪的審查記錄先前只存在於 GDD 標頭與 commit message,從未寫入 review-log,使 Phase 0b 的收斂追蹤缺少正式依據。此缺口本身是第三輪 Phase 4 標記的發現之一,本檔為其補救。第一、二輪的內容依當時的 GDD 標頭與 commit message 重建,標示為回溯登錄。
>
> **壓縮協定**:某一輪的發現一旦已被後續輪次解決並取代,將其 `Summary` 散文收斂為修訂表列即可(表列是「改了什麼、為什麼」的載重記錄,保留);段落長度的敘事移除,完整歷史由 git 保存。

---

## Review — 2026-08-17 — Verdict: NEEDS REVISION(第三輪)

Review target: **GDD body**(目標型覆核,範圍限定於第二輪修訂觸及的章節 —— Core Rules #4/#5/#6/#9、States and Transitions、Edge Cases、UI Requirements §1/§1a/§6、Visual/Audio §6.1、Formulas 公式四、AC-2/3/4/5/6/7/11/13/16/19/20/21)。**計入 Phase 0b 兩輪收斂追蹤**(非 process-files-only)。
Scope signal: **L**(依賴 8 項、公式 4 條、跨系統契約 2 條、查詢介面 4 個、AC 22 條;F3-4/5/6 的修法直接產生 `/create-architecture` 階段的架構約束。偏 XL 邊界)
Specialists: `qa-lead`、`godot-specialist`、`ux-designer`(依使用者裁示縮小為三位;`creative-director` 未諮詢,綜整由主 session 執行。`godot-specialist` 第一次派工因 session 額度上限中斷,已重派完成)
Blocking-now: **7**(design-content: 7 / propagation: 2 —— 傳播失敗另計,見下)| Deferred: 0(新增) | Advisory: 8

**Summary**:本輪發現分兩個性質不同的族群。**視線幾何族**(F3-1/F3-2 + P-1):第二輪的 B-1 裁決方向正確,但落地時把穿角的觸發條件寫成一個錯誤的等價敘述(`|dx|=|dy|`),且以單數描述一個實際會出現多次的幾何事件 —— 遠程 `max_range=4` 下 `(1,3)`/`(3,1)` 皆穿角卻落在規則外,中繼格清單重回實作分歧。**查詢介面族**(F3-4/F3-5/F3-6 + F3-7):三位專家從三個不同角度(UX 的資料陳舊、Godot 的跨幀協程、Godot 的節點生命週期)獨立撞到同一結構 —— 本文件所有對外查詢介面只有數學定義,沒有橫向義務規定何時重算/對誰快照/由哪層資料承載。這是同一缺口連續第三次復發(前兩輪各補一次個案條款,每次漏掉下一個),故**本輪改立總則**(新增 Core Rules #10 + AC-22),不再逐項補丁。F3-3 為獨立一項:AC-6 的向量斷言了 Core Rules #5 明文放棄的保證。設計骨架(零隨機、曼哈頓單一量尺、雙旗標行動經濟、結算步固定順序、Φ 快照語意)三輪下來未被動搖,本輪七項全落在「上輪修法的落地精度」與「一條未被明文化的橫向義務」上,無一要求重開核心裁決。

**專家分歧(未單方消解,已呈報使用者)**:`godot-specialist` 主張「`|dx|=|dy|` 是整數格盤上唯一產生角點歧義的情形,規則不殘缺」;`qa-lead` 主張 `(2,2)` 與 `(1,1)` 不同型。主 session 驗算判定兩者皆不完整 —— 穿角充要條件為 `v₂(|dx|) = v₂(|dy|)`,`(1,3)` 為可獨立重現的反例。使用者裁示採用此驗算結果,不另派 `systems-designer` 複驗。

**修訂表列(同輪落地)**:

| # | 類別 | 問題 | 修法 |
|---|---|---|---|
| F3-1 | design-content | 穿角規則觸發條件寫成 `\|dx\|=\|dy\|`,`(1,3)`/`(3,1)`(`d=4`,遠程射程內)同樣穿角卻不受涵蓋 | Edge Cases 穿角條款第 3 條:觸發條件改為 `v₂(\|dx\|) = v₂(\|dy\|)`,附 `(1,3)` 反例推導;AC-16 新增 `\|dx\|≠\|dy\|` 穿角向量兩列 + 非穿角對照組 |
| F3-2 | design-content | 多穿角點的組合規則未定;非歧義格心中繼格是否併入未寫;AC-5 對角向量「中繼格集合可能為空」與規則互斥、不可測 | Edge Cases 穿角條款重寫為三條(單點判定 / 逐點獨立套用 + 與普通中繼格 OR 合併 / 觸發條件);AC-16 新增多穿角點與格心中繼格向量三列;AC-5 對角向量拆為「至多一格遮蔽→合法」「雙格皆遮蔽→不合法」兩列,並補正交偏移對照列 |
| F3-3 | design-content | AC-6 新向量斷言②b 與③「不應出現矛盾」,與 Core Rules #5 明文允許落差並定案「恆以③為準」直接對撞;真正的落差分支零向量 | AC-6 該向量限縮為「②c 未回改傷害」情境;新增「②c 回改傷害造成落差,③勝出」向量(預測致命但實際未死 → 陣亡通知全程未呼叫);既有殺招向量補上與新增兩列的職責劃分 |
| F3-4 | design-content | §1 回合層級旗標總覽 與 §1a 威脅範圍疊加圖未繼承 AC-11/AC-20 的即時性義務(公式三 `occupied` 明文「不論敵我」+ Core Rules #9 可暫緩模型,保證正確答案會在疊加圖顯示期間改變) | **新增 Core Rules #10 總則 a 項**;§1/§1a 各補即時性指標;新增 AC-22 含兩條直接向量;Dependencies #10 列補上約束;systems-index 跨系統義務登記表新增一列 |
| F3-5 | design-content | 跨幀增量展開(OQ-16 自己建議的最佳化)缺快照原子性義務,可讀到新舊混合狀態,靜默違反 AC-20 且測試抓不到 | **Core Rules #10 b 項**(對計算開始時的單一快照完成,期間變動排入佇列;不禁止跨幀);AC-22 兩條向量;OQ-16 追加此架構約束 |
| F3-6 | design-content | 佔位資料所有權未聲明;引擎延後移除節點的慣用語意會使該格在同一結算步內仍讀為已佔據,違反 AC-7(c) | **Core Rules #10 c 項**(佔位須由邏輯資料結構承載,不得由節點樹存在性導出);AC-7(c) 與 Edge Cases 佔位釋放條款各補指標;AC-22 兩條向量 |
| F3-7 | design-content | §6 全手把清單兩輪內漏兩項,而其行內註記聲稱「已於 §6.1 一併改為結構性修法」—— 結構性修法實際只套用到 §6.1(僅漂移一次的那份清單),漂移兩次的 §6 反而仍是裸列舉,文件持有不實的「已修好」宣稱 | §6 改寫為原則陳述(「本文件含未來修訂新增所定義的每一個玩家可發起的操作,一律須有非滑鼠路徑」+ 非窮盡盤點),移除不實宣稱,附修法史 |
| P-1 | propagation | Edge Cases 佔位釋放條款 + AC-7(c) 的「自陣亡起…不遮蔽視線」句式暗示陣亡解除了視線阻擋,與 Core Rules #4(B-5:單位不論生死皆不遮蔽視線)矛盾 | 兩處拆分為「移動可通行」與「視線不受陣亡影響」兩句,並明文記錄舊措辭的缺陷與會誘導出的錯誤實作 |
| P-2 | propagation | AC-3 的 THEN 點名兩種非法組合,向量表只測 `min=max` 那一種 | 新增 `(3,2)`(`max<min`)向量,附「區間為空 → 靜默歸類為遠程會使該武器永遠無法攻擊」的理由 |
| ADV×8 | advisory | 見 GDD 各處 2026-08-17(四) 標記 | `duplicate_deep()` 取代巢狀 Resource 的 `duplicate()`;公式四補多敵聯集定義 + 回傳兩切面;§1a 補並存性義務;§6.1「三態」改為「各個可觀測值」(實為四值);AC-22 附集合比對與測試證據撰寫提醒;AC-6 向量職責劃分 |

**Phase 5a-ter 永久封鎖事件檢查**:本輪未新增任何永久封鎖成因(七項修訂全屬視線幾何精確化、查詢介面共用義務、AC 向量補完與措辭同步)。已確認 `game-concept.md` D-1 通則無須修改即涵蓋現況;本輪目標非 `game-concept.md`,故未編輯該檔。

**Grep 自核 pass 結果**:檢查 `正對角穿角`、`正對角(穿角)`、`|dx| = |dy|`、`單位當前狀態三態`、`不遮蔽視線`、`duplicate(true)`、AC 編號與 Core Rules 計數。全部殘留命中經逐一查核皆屬**刻意保留**(修法史中引述舊措辭以說明缺陷、`Dictionary` 仍正確適用 `.duplicate(true)`、標頭對第二輪的歷史描述)。`.claude/agent-memory/ux-designer/` 中一處提及舊「三態」措辭屬 agent 記憶的歷史紀錄,非規範文件,不修。無未同步的規範性殘留。

**Prior verdict resolved**: Yes —— 第二輪的 5 項 BLOCKING-NOW(B-1~B-5)經本輪覆核,B-2/B-3/B-4(核心部分)/B-5 站得住腳;**B-1 的落地不完整**,已於本輪修正(見 F3-1/F3-2)。

**收斂狀態**:連續零 BLOCKING-NOW 輪數 = **0**。距 APPROVED 尚需連續兩輪 body-scoped 零 BLOCKING-NOW。**第四輪建議升級為完整模式** —— 本輪 7 項 BLOCKING-NOW 全為設計內容缺陷,已觸發 Phase 0b 升級門檻;第三輪因使用者裁示與 session 額度限制維持三位專家,升級延至第四輪。

---

## Review — 2026-08-17 — Verdict: NEEDS REVISION(第二輪,回溯登錄)

Review target: GDD body(完整模式)
Scope signal: L
Specialists: `game-designer`、`systems-designer`、`qa-lead`、`ux-designer`、`gameplay-programmer`、`performance-analyst`、`godot-specialist` + `creative-director` 資深綜整
Blocking-now: **5**(design-content: 5)| 另有傳播失敗與 AC 完整性缺口,同輪修訂

| # | 問題 | 修法 |
|---|---|---|
| B-1 | 對角視線的中繼格清單未定案(Bresenham/supercover/DDA 各自自洽卻互異) | Edge Cases 新增正對角穿角判定慣例(兩側皆遮蔽才擋);AC-16 新增兩向量。**註:本項落地不完整,第三輪 F3-1/F3-2 修正** |
| B-2 | 敵方威脅範圍不可讀(玩家無法判斷某格是否安全) | 新增 Formulas 公式四 `threat_range_formula`、UI Requirements §1a 威脅範圍疊加圖、AC-21;§1 格位面板補「當前 MP」欄位 |
| B-3 | 陣亡通知的游標介面回傳值缺補救分支 | Core Rules #6b 明訂「已過期,未套用」須保有重新偵測/重新呼叫機制,且不得僅以前置檢查取代;AC-7 拆分兩階段向量 |
| B-4 | 殺招卡牌的致死時序未定(條件式效果與陣亡判定的先後) | Core Rules #5 步驟②拆為 ②a 傷害修正 → ②b 致死預測(唯讀)→ ②c 條件式效果;AC-6 新增向量。**註:該向量的斷言有誤,第三輪 F3-3 修正** |
| B-5 | 單位是否遮蔽視線從未定案 | Core Rules #4 明訂單位(不論生死不論敵我)不影響視線判定;AC-20 向量改寫。**註:Edge Cases/AC-7(c) 措辭未同步,第三輪 P-1 修正** |

**Prior verdict resolved**: Yes（第一輪 6 項經第二輪覆核確認站得住腳）

---

## Review — 2026-08-17 — Verdict: NEEDS REVISION(第一輪,回溯登錄)

Review target: GDD body(完整模式)
Scope signal: L
Specialists: 同第二輪七位 + `creative-director`
Blocking-now: **6**(design-content: 6)| Propagation: 3

| # | 問題 | 修法 |
|---|---|---|
| #1 | 行動經濟的旗標重置只掛在「已行動」出口,被暫緩/未主動結束的單位永遠碰不到重置 | Core Rules #9 新增獨立的「回合邊界重置」規則;States and Transitions 補「旗標重置與狀態轉換相互獨立」說明;AC-19 新增向量;Dependencies 補回合順序系統擁有權聲明 |
| #2 | 攻擊旗標的「各限一次」未對稱驗證 | AC-19 補重複使用攻擊旗標向量 |
| #3 | `Φ` 的取值時點未定(步驟②的寫入是否影響步驟③) | Core Rules #5 新增「`Φ` 取值時點為快照」段落 + 參照型別的別名風險提醒;AC-6 補 THEN 與向量 |
| #4 | 移動/攻擊範圍疊加圖的即時性未定案 | Edge Cases 新增疊加圖即時狀態條款;新增 AC-20。**註:此為查詢介面缺口的第二個實例,第三輪改立 Core Rules #10 總則** |
| #5 | 「我方這回合還有誰沒動完」無法有效率回答 | UI Requirements §1 新增回合層級剩餘旗標總覽介面;Dependencies #10 列同步 |
| #6 | 陣亡時游標介面的回傳值未檢查 | Core Rules #6b 補回傳值檢查義務;AC-7 補 THEN 與向量。**註:第二輪 B-3 進一步收緊** |
| P1–P3 | Visual/Audio §5 拒絕音表漏「旗標已用過」;§6.1 非色彩清單漏新增狀態;§6 手把清單漏「主動結束行動」 | 三處同輪補上。**註:§6 清單於第二輪再漏一次、第三輪 F3-7 改為原則陳述** |

**Prior verdict resolved**: First review
