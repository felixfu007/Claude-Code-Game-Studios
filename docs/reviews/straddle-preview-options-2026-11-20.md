# 丙類確認面板「麥子健將失去騎牆」預告 —— 做法比較(story-020 AC4b)

日期 2026-11-20 · 作者 lead-programmer · 只讀程式、未改任何 src/tests 檔 · 凡寫「未驗證」者是我沒查證的宣稱。

## 0. 先講最重要的發現(會改變要不要做)

**以現有資料,丙類卡永遠寫不到麥子健的任何一組關係,所以這條預告今天永遠不會亮。**

- `PermanentAffinityWriteRules.play()` 在碰池之前先查 `has_canon_link`,沒有關係線的配對直接回 `INVALID_PAIR`、零寫入(`src/gameplay/cards/permanent_affinity_write_rules.gd` 第 140~141 行)。
- 五關的關係線檔 `assets/data/affinity/vs01~vs05_affinity_links.txt` 的非註解行只有 `1,2,POSITIVE,1` 與 `3,4,NEGATIVE,1`(用 `grep -vn "^#"` 實跑),**沒有任何一行含 5(麥子健)**。vs01/vs02 檔內註解明寫「戊(麥子健)沒有任何配對,這是刻意的」,且「要新增他的線,先改 characters.md」。
- 合法目標清單 `legal_pairs()` 也是由這份線推導,選目標畫面本來就不會列出麥子健。
- 但 `docs/reviews/straddle-q3-q4-recommendation-2026-11-17.md` 第 42 行的前提寫「他…被丙類卡寫過一次池,騎牆就永久失效」—— 與上述資料**不一致**。裁決「兩項都要」時這個前提看起來沒被對過資料。
- 營火(支援對話)路徑是否也有同樣的線閘門:**未驗證**(只看到 `support_conversation_pool_write_port.gd` 呼叫 `append_record`,沒讀它的前置檢查)。

## 1. 現行路徑(已讀)

1. 丙類確認:`CardPlaySession.confirm()` → `PermanentAffinityWriteRules.play(card, a, b, links, port)` → `AffinityPoolWritePort.append_record`(roster id 轉角色序數)→ `AffinityDataPool.append_record(pair, m, source)`。池內:附加記錄、全域 `_t_now` +1、發 `entry_appended`。
2. 讀值:`combat_strength_read` = Σ m·λ^(年齡),`_weighted_sum` 單一核心(`affinity_data_pool.gd`)。
3. 三態:`AffinityRelation.state_of(pool, pair, k)`(`src/gameplay/affinity/affinity_relation.gd`):n=0 或 |v|≤k → 冷淡;v>k 好感;v<-k 敵意。已有三處呼叫它:相位提供者、`card_play_session._resolve_relation`、騎牆判定。
4. 騎牆有效:`AffinityPhiProvider.straddle_valid(unit_id)`(第 239 行)= 他與場上活著的其餘我方每一組 `state_of` 皆冷淡;`BattleState.straddle_is_valid` 即時呼叫它,不快取。
5. 兩個對預告有影響的池性質:(a)寫入會讓**全部配對**多衰減一格(`_t_now` 全域);(b)ADR-0002 公式四 `speculative_read(pair, hypothetical_entries, mode)` **已在已核准契約內**(ADR 第 527~552 行,回傳 `AffinityReadResult`),但**程式裡還沒實作**(`src` 內只剩註解提到,標為 S-012「切片外」,用 grep `speculative_read` 實跑)。

## 2. 三個做法

### A. 實作 ADR 已寫好的公式四,加一支「寫入後三態」純函式(推薦)
- 改:`affinity_data_pool.gd`(補 `speculative_read`,重用 `_weighted_sum`,t_new=`_t_now+1`)、`affinity_relation.gd`(把「n/v/k → 三態」那 8 行抽成 `classify(value,n,k)`,`state_of` 與新的 `state_after_write(pool,pair,m,k)` 都呼叫它)、`card_play_session.gd`(新增唯讀 `preview_straddle_loss()`)、`card_confirm_panel.gd` 顯示、新測試。strings 鍵已有。
- 第二份規則?**否**:衰減數學在池的同一個核心,門檻判斷抽成同一支。風險只在「抽 `classify` 時改壞 `state_of`」—— 既有 story-012/013 測試會擋。
- 證明預告=實際結算:測試跑「預告 → 真的 `confirm()` → 讀 `state_of`」,兩者逐組相等;至少涵蓋 m 正/負、k=0 與 k>0、衰減邊界、已死配對(公式四本就回 `DEAD_PAIR_NOT_ALLOWED`,預告當作「不會變」)。再加一條敏感度測試:故意讓預告少算一格衰減,必須變紅。
- ADR-0002:**不新增契約**,是補實作 ADR 已核准的簽章(仍需在池檔註明 S-012 補完);不動寫入路徑與並發規則。
- 工作量:約 1~2 天(池 1、關係 0.5、會話+面板 0.5、測試 0.5)。估計值,未驗證。

### B. 複製一份池、真寫一次、再 `state_of`
- 改:池要新增「複製」介面(現在沒有,`export_state/import_state` 也還沒做,S-013),再加會話與面板。
- 第二份規則?否(完全重用真規則)。代價:新增複製 API **不在 ADR-0002 契約內**,要走一次 ADR 修訂;複製副本的記錄陣列為私有欄位。預告=結算天然成立,但測試照樣要寫。
- 工作量約 2~3 天,且需要技術總監先點頭。不推薦。

### C. 在會話裡自己算「λ·舊值 + m」
- 改 1~2 支檔,最快(約半天)。但這就是「第二份規則」:衰減與來源權重寫兩份,今天一致、日後校準 λ 或加來源權重就悄悄分叉。違反 story-020 AC4b「UI 不自算」的精神。不推薦。

### 補充:另一個「做」之外的選項 D —— 暫緩
因第 0 節,今天這條預告只能靠合成資料測到、玩家永遠看不到。可把 AC4b 標為「暫緩,待麥子健有關係線時啟動」,不花工。

## 3. 推薦
**先由管理者決定第 4 節的問題一;若仍要做,選 A。**
一個顯示規則請一併定下(問題二):只在「現在還有騎牆、打完會沒有」時顯示;若他已經失去騎牆,不顯示「將失去」(說「將失去」就是錯的)。我的推論:衰減只會讓數值往冷淡靠、不會把冷淡變成非冷淡,所以判斷「會不會失去」只需看被寫的那一組(未用程式驗證,但 λ 被校準檢查限制在 0~1,見 `affinity_calibration.gd` 第 126 行)。

## 4. 需要管理者決定的事(白話)
1. **這條預告要不要現在做?** 現在的關係設定裡,麥子健和任何人都沒有「關係線」,所以丙類卡根本選不到他,「將失去騎牆」今天不會出現。你當初的裁決假設丙類卡能寫到他,但資料不是這樣。三條路:(甲)現在照做,功能先備好,等你日後替他加關係線才會被玩家看到;(乙)先不做,AC4b 暫緩;(丙)改變設定,讓他有關係線(這會改變角色設計——「他中立、站哪都一樣」的設計,需要先改角色設定檔,不是工程能決定的)。
2. **他已經失去騎牆時要不要再顯示?** 我建議不顯示。
3. **營火那邊同一條預告**(規格 4.4 同樣要求)是否也受第 0 節影響,我沒查;要不要連營火一起查清楚再決定,請你定。

## 5. 未驗證清單
- 營火支援對話路徑是否也被關係線擋住。
- 「衰減不會把冷淡變非冷淡」只是推論,未跑程式。
- 工作量天數皆為估計。
- 確認面板出現時,所選配對(`_selected_target_a/b`)是否已定、面板能否取得:未讀 `battle_screen.gd` 該段,未驗證。
- `speculative_read` 未實作是用 grep 看到只剩註解;沒有逐檔排除放在別的名字下。
