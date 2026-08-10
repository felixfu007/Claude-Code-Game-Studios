# Cross-GDD Review Report

**Date**: 2026-08-09
**Trigger**: 驗證 2026-08-06/2026-08-07 對抗性覆核後的修訂(8 項 BLOCKING 修訂,尚未 commit)是否已收斂,依 creative-director 停止規則判定是否可移交 `/create-architecture`
**GDDs Reviewed**: 5 — `game-concept.md`、`systems-index.md`、`affinity-data-pool.md`、`save-system.md`、`cursor-highlight-state.md`
**Method**: 三個並行子審查(Phase 2 一致性 / Phase 3 設計整體性 / Phase 4 跨系統情境走查),各自完整讀畢全部五份文件

---

## Consistency Issues(Phase 2)

### Blocking

🔴 **B1｜序列化生命週期通知的「end 終止條件」兩份文件相反**
`save-system.md` Core Rules #5(2026-08-07 新增)定義了三條終止路徑,失敗路徑要求「本系統須在判定拒絕的同一次呼叫內立即呼叫 end」。但 `affinity-data-pool.md` Edge Cases「存檔期間寫入」條款(該介面權威定義處)仍寫「直到還原完全結束(含 Core Rules #13 兩階段回寫確認完成)才清除」——遷移失敗時該條件永遠不成立,旗標永久卡死、此後所有寫入被拒。修法落在 save-system 五處,唯獨未回頭同步擁有該介面的 `affinity-data-pool.md`。AC-47 本體亦只描述「讓出視窗」,未涵蓋失敗終止。

🔴 **B2｜save-system 對好感度數值池施加的義務,在下游文件與登記表零記載**
`save-system.md` Core Rules #5 終止路徑(三)要求 affinity 端「自行提供逾時或行程存活偵測機制作為防禦性後備」。`affinity-data-pool.md` 全文(Edge Cases、Dependencies、AC-47、Open Questions)完全沒有這條義務,`systems-index.md` 登記表第 151 列的承接系統也只寫「存檔系統」。違反 `.claude/rules/design-docs.md`「Dependencies must be bidirectional」。

🔴 **B3｜systems-index.md 與 affinity-data-pool.md 對後者 Status 的記載矛盾,且 affinity 的修訂註記本身不實**
`systems-index.md` Systems Enumeration 寫「Needs Revision」;`affinity-data-pool.md` 標頭寫「Approved」並宣稱「此處與 systems-index.md/save-system.md/entities.yaml 對本文件狀態的引用皆已寫 Approved」——查證後**兩個引用不實**(systems-index 寫 Needs Revision;entities.yaml 根本無文件狀態欄位)。

🔴 **B4｜systems-index.md 對存檔系統 Status 的記載與 save-system.md 矛盾,Progress Tracker 自我矛盾**
systems-index 寫「Needs Revision」,save-system.md 標頭寫「Approved(2026-08-07…跳過第六輪覆核,直接核准移交 `/create-architecture`)」。同時 systems-index 的 Progress Tracker 寫「Design docs approved | 2」,但 Systems Enumeration 表中 0 列標記 Approved。

🔴 **B5｜存檔系統宣告「無上游依賴」與其自身三條對好感度數值池的硬性依賴矛盾;循環依賴結論失守**
`save-system.md` Dependencies 明寫「本系統依賴的其他系統:無」,但同文件至少三處硬性依賴 affinity(begin 通知義務、驗證規則宣告的權威登記處、`Pair`/`source_i` 穩定字串名稱)。兩份文件互相把對方列為自己的下游,`systems-index.md` Dependency Map 對此零記載,並在「未發現循環依賴」處漏掉這組雙向硬性耦合。

🔴 **B6｜Cross-System Obligations Registry 第 171 列的告知文案,已被 save-system.md 2026-08-07 修訂明文禁止**
登記表第 171 列仍要求「唯讀資料可正常讀取時須告知『歷史已完整保存』」單一文案。`save-system.md` 第五輪已改為三分支分級告知,並明指沿用單一文案是「主動誤導式的資料遺失」,比靜默遺失更糟。登記表現行文字正指示下游做 save-system 已判定為最毒失敗類別的事。

🔴 **B7｜「遷移失敗」→「拒絕讀取」狀態更名未傳播,且更名同時擴大了進入條件**
`save-system.md` 2026-08-07 已更名並擴大進入條件(涵蓋不限遷移的一般位元腐蝕),但 Core Rules #13 自動痊癒路徑(一)(三)、AC-17/22/35 仍用舊名「遷移失敗」。**AC-39 同一條 AC 內新舊名並存**(GIVEN 用新名、THEN 用舊名)。`systems-index.md` 第 171 列亦沿用舊名。因新進入條件涵蓋的一般位元腐蝕情境,舊名段落字面上不涵蓋。

🔴 **B8｜affinity-data-pool.md 內部殘留已被自己推翻的「同步/非同步」判準**
AC-47 本體與 Section M 標頭已於 2026-08-06/07 改為「是否存在非原子視窗」判準,但 Section L(AC-4/AC-47 的 DoD 範圍釐清段落)仍寫「存檔系統的同步/非同步架構決定」——2026-08-07 修法只改了 Section M,未同步 Section L,QA 可能誤判 AC-47 仍在等待架構決策。

🔴 **B9｜裝置權威判定依據:game-concept.md 與 cursor-highlight-state.md 字面相反**
`game-concept.md` 技術考量(第 308 行)仍寫「建議以 `ui_*` action 來源判定,而非原始事件型別」;`cursor-highlight-state.md` Core Rules #3 早已定案「判定機制須檢視觸發該 action 的原始 `InputEvent` 子類別」,且明文記錄這正是它修正過的誤解。2026-08-06 的權威收窄修訂只改了 game-concept 第 182 行,未涵蓋第 308 行對同一機制的另一處描述。

🔴 **B10｜entities.yaml 相對 affinity-data-pool.md 全面過期,且載有已被源文件舉反例推翻的宣稱**
`shape_feature_read` 只登記 3 個子特徵(現行 7 個);`time_distribution` 仍寫已被取代的 `span_t`(現行 `span_c`);三個 formula 皆缺 `t_query` 參數;公式四完全未登記;`narrative_depth_read` 的 notes 宣稱「`|narrative_depth_read| ≤ combat_strength_read`」——affinity 現行 Formulas 已明文舉反例推翻此不等式。基線資料本身錯誤,會讓後續 `/consistency-check`、`/architecture-review` 產生系統性誤判。

### Warnings

⚠️ W1 — `systems-index.md` 標頭仍載已被推翻的 provisional 結論(「仍為 provisional」與同文件第 151/153 列現行「✅ 已轉為確定需要」相反)
⚠️ W2 — `design/ux/accessibility-requirements.md` 已於 2026-08-06 建立,但 `systems-index.md` 第 158/160 列與 `cursor-highlight-state.md` Open Questions 仍三處記載「該檔案不存在」;第 160 列關閉條件實際已達成卻未關閉
⚠️ W3 — Cross-System Obligations Registry 存在兩組重複列(157/159、158/160),有殘留風險(其中一列關閉、另一列不同步殘留,即 W2)
⚠️ W4 — `cursor-highlight-state.md` Dependencies 表結論「全部 4 項依賴」實為 5 項,漏列教學/上手引導系統
⚠️ W5 — affinity 對好感度視覺呈現 UI 的硬性呈現義務(不得並列顯示兩讀值)未登記於 Cross-System Obligations Registry,`systems-index.md` 該系統 Depends On 亦未列好感度數值池
⚠️ W6 — `pure_combat_floor` 命名倒置(game-concept 稱「天花板」,affinity 稱「地板」),且校準順序未納入已知的谷值不可達風險
⚠️ W7 — Tuning Knob `M`(來源缺席確認門檻)歸屬含糊,無 Open Question/Registry 列追蹤
⚠️ W8 — `save-system.md` AC-68 的 GIVEN 情境數自我矛盾(宣稱三個情境,只列舉兩個)
⚠️ W9 — `game-concept.md` 仍把已在 cursor-highlight-state.md 定案的初始游標狀態規則(Core Rules #6)記為待補項
⚠️ W10 — `cursor-highlight-state.md` 對 `game-concept.md` 的行號/章節引用已因後續修訂偏移失效
⚠️ W11 — `cursor-highlight-state.md` 標頭 Last Updated 日期(2026-08-06)落後於文件內文(含 2026-08-07 新增的 Known Confirmed Defects 節)

**特別關注項查核結果**:
1. 劇情事件寫入性質(系統觸發 vs 玩家主動)—— ✅ 全文 12 處出現位置逐一查核,**無殘留**,已乾淨解決。
2. save-system Core Rules #5 三條終止路徑 vs affinity AC-47/Edge Cases vs Registry —— ❌ 三方皆不一致(見 B1/B2/W1/W8)。
3. 其他攜帶舊時間戳/未修訂措辭的重述段落 —— ❌ 另找到 B7(狀態更名未傳播)、B8(Section L 未同步)、B9(game-concept 保留已被修正的描述)、W2(檔案已建立但仍稱不存在)。

---

## Game Design Issues(Phase 3)

### Blocking

🔴 **B-1(3b)｜核心戰鬥瞬間同時活躍系統數 6+,遠超 3-4 舒適上限,且無任何文件擁有「總認知預算」**
game-concept.md 的「五層視覺資訊」清單(移動範圍/射程/好感度連線/聯動預覽/內鬨預覽)與教學揭露順序,完全未涵蓋游標系統被列為硬性行為要求的第三態視覺(一般高亮/待重新解析/滑鼠奪權漸進回饋)與全域裝置狀態指示。兩份文件各自認為自己管好了自己那層,實際疊加層數已超出五層清單本身,且從未有任一份文件承認總數。

🔴 **C-1(3c)｜負遠(負好感+拉開距離)以目前全文件規格仍是無代價的純正向結果**
game-concept.md 第五輪已明確判定負遠需要「非空間的維持成本」,但該義務(a)承接系統「好感度—位置連鎖系統」Status 為 Not Started,(b)完全未登記於 Cross-System Obligations Registry(同位階的另外兩條支柱層級約束都已登記),(c)tie-break 支柱層級約束同樣未登記。支柱四要求「無任何狀態組合可為無代價純正向結果」目前仍未被任何有約束力、可被承接系統看見的規則封住。

🔴 **C-2(3c)｜「結局深度門檻不得高於純戰鬥天花板」使深度軸對所有玩家恆真,座標空間退化**
任何做過支援對話的玩家,穩態值必嚴格大於 `pure_combat_floor`;而全部結局門檻 ≤ `pure_combat_floor`。推論:在穩態下,每個達到純戰鬥寫入速率的玩家都滿足每個結局的深度條件——深度軸對結局閘控的區辨力恆為零。這與 Track B「二維以上形狀空間」的宣稱(affinity 稱「四軸已超過二維最低要求」,深度軸是其中一軸)直接衝突,也與「均衡經營策略校準」的方向反向拉扯。affinity 現有的條件式風險登記(「若重疊」)低估了它——依現行規則字面,重疊是必然而非條件。

🔴 **D-1(3d)｜source_absence 並非單調不可逆特徵,但敘事可達性約束的範圍排除條款以「它是」為前提**
game-concept.md 把 `total_churn`/`reversal_count`/`source_absence` 一併列為「單調不可逆」以豁免敘事可達性約束並建立揭露義務。但 `source_absence` 的 `absent_confirmed` 可被任何一筆該來源的後續寫入翻轉,不具備前兩者的單調性。後果:(1) 以此為條件的「永久關閉」閘門實際上並非永久,豁免理由本身不成立;(2) 玩家事後補做互動時,系統處於「已宣告關閉、但條件已回復」的未定義狀態,全文無規則處理。

🔴 **E-1(3e)｜難度曲線唯一陳述的成長來源已隨主角群裁決失效,文件內部自相矛盾;MVP 無任何已定義難度曲線**
「難度曲線」段落仍寫「隨角色數量增加…複雜度自然提升」,但 2026-07-30 主角群固定 5 人裁決的回溯修訂範圍只點名技術考量與範疇分級表,漏掉此處——同文件「技術風險」章節已改寫為「複雜度低且不隨遊戲進程增加」,與難度曲線段落字面相反。疊加「MVP 明確不做活棋盤地形演變」與反支柱排除數值難度堆疊,MVP 的 5 場手工關卡沒有任何被文件承認的難度推進機制。

🔴 **F1(3f)｜已確認的奪權鎖死缺陷同時關閉漸進回饋,並使系統主動指示玩家執行不可能成功的補救**
重置觸發點 (b)(目標改變即重置)在持續按方向鍵情境下每次移動都觸發,導致漸進回饋視覺(0% 進度時不可見)在此缺陷下恆為不可見——這正是漸進回饋原本要消除的失敗情境。玩家嘗試點擊被拒絕,拒絕回饋依規則須指示「以滑鼠移動達到奪權門檻」,而缺陷保證此動作不可能成功——回饋的可區分性設計在此情境下把「無回應」升級為「主動誤導」。Player Fantasy 的自我揭露在存在性上充分,但未揭露漸進回饋與拒絕回饋兩套緩解機制同時失效。

🔴 **G-1(3g)｜affinity-data-pool.md 承諾二對支柱一的宣稱,被 game-concept.md 兩條支柱層級 UI 裁決結構性排除**
承諾二宣稱玩家能推算「劇情馬上會怎麼反應」,但 game-concept.md 的 UI 硬性約束(不得並列兩讀值)與卡牌揭露義務(結果層不透明、不得揭露 α)已裁定敘事讀值對玩家不可觀測。玩家永遠看不到 `narrative_depth_read`,形狀特徵也無任何呈現規格。這是有意識的上游設計選擇,但 `affinity-data-pool.md` 的 Player Fantasy 對支柱一做了一個超出上游裁決允許範圍的承諾,而該文件 Status 為 Approved。

### Warnings

⚠️ A-1(3a) — 卡組建構是未被「長期進程」承認的第二條個人化成長軸,方向未裁決
⚠️ B-2(3b) — 預判模式(已裁定為正式功能)未被納入任何注意力/揭露預算
⚠️ C-3(3c) — 「猛打戰鬥卡、不聊天」目前是弱被支配路線,唯一平衡機制(Track B 互斥可得性)承接系統為 Vertical Slice/Not Started——文件已誠實登記為常設風險,故降為 Warning
⚠️ D-2(3d) — 地板值在谷值時機可能實際不可達,支柱層級約束的驗證掛在 Open Question 而非 AC
⚠️ E-2(3e) — 「失敗可快速重來」的玩法承諾,一般完整讀取路徑(戰敗重來所走的路徑)沒有任何耗時旋鈕或 AC
⚠️ E-3(3e) — 無業界先例的滑鼠奪權機制,教學掛鉤設計順序排在全部 14 系統的倒數第三(Polish 層)
⚠️ F2(3f) — game-concept.md 把裝置權威規則的權威一律讓渡給 cursor-highlight-state.md,未註記該文件含未修復已知缺陷、Status 為 Needs Revision
⚠️ F3(3f) — ⛔ 硬性閘門未定義對 5 個下游依賴系統與 6+ 條硬性義務的傳播範圍
⚠️ F4(3f) — systems-index.md Status 欄(全部 Needs Revision)與 Progress Tracker(approved:2)與兩份 GDD 標頭(Approved)三方不一致,稀釋 ⛔ 閘門的訊號強度
⚠️ G-2(3g) — save-system.md 分級告知(乙)只給無量化的「可能不包含之後的部分進度」,但系統本身握有精確邊界資料(遷移完成標記),未加以利用

---

## Cross-System Scenario Issues(Phase 4)

**Scenarios walked**: 5 — (一)分步遷移讓出視窗中遊戲邏輯直接寫入好感度數值池;(二)暫停選單→存檔管理 UI→載入過場的游標交接;(三)負向劇情事件寫入,配對成員其後陣亡;(四)章節開場自動存檔/前進戰役刻度/序列化旗標三方定序;(五)存檔槽瀏覽器懸停預覽

### Blockers

🔴 **F1-1｜寫入被拒後的重試與資源回滾,三份文件皆無承接者**
`affinity-data-pool.md` 把重試責任推給呼叫方,`save-system.md` 明文承認同槽重入不變量不防護此路徑,`systems-index.md` 登記表對三個寫入方系統的相關列都不涉及「寫入遭拒時須重試或回滾」。失敗形狀:卡牌已打出、效果已演出,但 delta log 永遠沒有這筆記錄——遊戲已演出的事實與資料層記錄分歧,玩家消耗的資源是否回滾完全未定義。

🔴 **F2-1｜AC-23「暫停期間不變」與 Core Rules #7 一般化是真矛盾**
AC-23 斷言暫停選單「選單內以手把導覽選項」不改變游標狀態,但 Core Rules #7 要求任何具懸停/游標目標的表面都寫入同一份全域狀態、不得繞過。暫停選單的導覽操作必然改寫游標狀態,兩條規則不可能同時成立,文件從未明文排除暫停選單於 Core Rules #7 之外。

🔴 **F2-2｜載入存檔後的陳舊游標目標,無任何系統有義務標記其失效**
`save-system.md` 全文對「游標」零提及,`systems-index.md` 登記表沒有任何一列連結存檔系統與游標系統。第 155 列的「標記待重新解析」義務關閉條件明文限定為「單位死亡/移動」,不涵蓋「整個戰場被存檔載入替換」。結果:載入後游標可能持有指向已不存在單位的**有效**目標,下游依「下游預覽渲染義務」會渲染確信樣式的預覽——精準命中 cursor 系統 Player Fantasy 明訂的第一號失敗情境。

🔴 **F3-1｜登記表第 149 列與第 174 列在含陣亡角色的配對上結構性互斥**
第 174 列要求負向劇情事件之後玩家仍有主動行為可緩和/翻轉;第 149 列要求陣亡配對的讀值查詢必須用陣亡當下的 `t_query`,不得用呼叫當下的 `t_now`。兩者相加:陣亡之後寫入的任何緩解記錄,其 `t_i > t_query`,依 Core Rules #3 一律不納入計算——**敘事端永遠讀不到這筆緩解**。對「劇情事件寫負向 delta → 角色其後陣亡」序列,第 174 列的義務在敘事端結構上不可能被滿足,且其關閉條件完全不會觸及這個交互。

### Warnings

⚠️ F1-2 — `end` 中止路徑的後備義務(逾時/存活偵測)是單向孤兒義務,affinity 全文零記載
⚠️ F2-3 — 「存檔管理 UI」承接至少 10 條硬性義務(save-system 6 條 + cursor 4 條),卻不是 Systems Enumeration 中的第 15 個系統,備選承接者「好感度視覺呈現 UI」語意錯配
⚠️ F2-4 — 登記表第 164 列(表面卸載前目標交接)承接名單不含暫停/存檔流程,而載入過場正是「全部表面同時卸載」的典型時刻
⚠️ F2-5 — 已確認鎖死缺陷的硬性閘門範圍未涵蓋其對存檔管理 UI 槽瀏覽器的影響(d-pad 捲動時滑鼠完全喪失操作能力)
⚠️ F2-6 — 登記表第 171 列已相對 save-system.md 第五輪修訂(三分級告知)過期,仍登記已被判定為不誠實的舊版兩分支文案
⚠️ F3-2 — 第 174 列關閉條件未要求檢查「配對成員陣亡後緩解路徑的寫入端是否仍可用」
⚠️ F3-3 — 第 175 列(揭露義務)措辭假設閘門由玩家選擇觸發,不涵蓋 `story_event` 推動 `total_churn` 跨越閘門的情形(3g 明文規定 story_event 不得詮釋為玩家選擇,登記表卻用「這個選擇」措辭)
⚠️ F4-1 — 登記表第 177 列(自動存檔/刻度呼叫順序)遺漏第三條刻度遺失途徑:刻度呼叫落在序列化旗標視窗內被 AC-47 拒絕,與呼叫順序定案無關
⚠️ F4-2 — 單筆刻度遺失可複合放大為整槽不可讀(觸發 AC-59b 非法向量 → `SEMANTIC_VALIDATION_FAILED` → 拒絕讀取),此複合路徑未被任何文件承認
⚠️ F5-1 — 登記表第 163 列(下游預覽渲染義務)承接名單窄於規則文字,存檔槽瀏覽器的槽預覽符合規則卻無承接者
⚠️ F5-2 — manifest-only 介面自稱「流量最高路徑」,但與游標裝置權威模型結合後實際頻率被低估(每次目標改變一次,而非每次開啟一次),且無任何耗時旋鈕或效能 AC

### Info

ℹ️ F1-3 — 旗標涵蓋範圍的「非原子視窗」判準,affinity/save-system/systems-index 三方已對齊,無新發現
ℹ️ F3-4 — 「存檔拒絕讀取導致緩解路徑不可達」支線:檢查後不成立,新戰役 delta log 為空,不存在殘留的無代價惡化
ℹ️ F4-3 — AC-26 的 provisional 條件式處理已正確,與 AC-47 判準一致,無新發現
ℹ️ F5-3 — manifest-only 只驗頂層雜湊、不驗 payload 逐區塊雜湊,是文件已知的取捨,非矛盾;殘餘成本(payload 腐蝕槽仍呈現正常預覽)未見於任何範圍聲明
ℹ️ F5-4 — AC-59 第三組與游標目標改變節奏無衝突,接縫檢查乾淨

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| `affinity-data-pool.md` | B1/B2/B8/B10(一致性);C-1/C-2/D-1/G-1(設計理論);F1-1/F1-2/F3-1(情境) | Consistency + Design Theory + Scenario | Blocking |
| `save-system.md` | B1/B2/B4/B5/B6/B7(一致性);E-2/G-2(設計理論);F1-1/F1-2/F2-1/F2-2/F4-1/F4-2/F5-2(情境) | Consistency + Design Theory + Scenario | Blocking |
| `cursor-highlight-state.md` | B9(一致性);B-1/F1/F2/F3(設計理論);F2-1/F2-2/F2-4/F2-5/F5-1(情境) | Consistency + Design Theory + Scenario | Blocking |
| `game-concept.md` | B3/B4/B9/B10(一致性);A-1/C-1/D-1/D-2/E-1/E-2/E-3/F2/F3/G-1(設計理論);F3-3(情境) | Consistency + Design Theory + Scenario | Blocking |
| `systems-index.md` | B3/B4/B5/W1/W2/W3/W4/W5(一致性);F3/F4(設計理論);F2-3/F2-4/F2-5/F2-6/F3-2/F3-3/F4-1/F5-1(情境) | Consistency + Design Theory + Scenario | Blocking |
| `design/registry/entities.yaml` | B10(一致性)——基線資料本身過期且含被推翻的宣稱 | Consistency | Blocking |

---

## Verdict: FAIL

三個並行子審查合計:**21 項 Blocking**(一致性 10 + 設計理論 7 + 情境 4)、**30 項 Warning**、5 項 Info。

Creative-director 於前一輪(2026-08-06/07)訂下的停止規則是:「重跑後若剩餘發現全屬傳播/登記類、無新設計缺陷,不論 PASS/CONCERNS 皆應直接移交 `/create-architecture`」。本輪結果不滿足此條件——雖然約半數 Blocking 項確實是同一種「A 文件的裁決,其事實前提在 B 文件被修改/收窄/證實失效後,A 未回頭同步」的傳播失敗(B1/B6/B7/B8/B9/F2-6 等),但至少 **5 項是無法歸類為傳播失敗的新設計缺陷**:
- C-1(負遠仍是無代價純正向結果,直接違反支柱四本身,承接系統甚至還沒開始設計)
- C-2(深度門檻上限與二維形狀空間宣稱結構性衝突,非措辭問題)
- D-1(`source_absence` 的可逆性與其被賦予的「單調不可逆」豁免資格矛盾)
- F1(奪權鎖死缺陷的下游連鎖效應,首次被發現同時關閉了兩套緩解機制並產生誤導性回饋)
- F3-1(登記表第 149 列與第 174 列在陣亡情境下的結構性互斥,是全新發現的跨義務衝突,不是任一義務本身的錯字或漏同步)

此外,B3/B4/B5(狀態欄矛盾)與 B10(entities.yaml 全面過期)雖屬「登記類」,但其嚴重度足以讓下一階段(`/create-architecture`)在讀取「哪些系統已核准」「哪些公式/欄位是權威定義」時直接讀到錯誤或矛盾的基線資訊,不建議略過。

### Required actions before re-running

**第一優先(基線與狀態真實性,建議一次性修正)**:
1. `entities.yaml` 全面同步至 `affinity-data-pool.md` 現行 Formulas(7 個形狀子特徵、`t_query` 參數、公式四、移除已被推翻的不等式宣稱)
2. `systems-index.md` Systems Enumeration 的 Status 欄與三份系統 GDD 的標頭 Status 對齊;Progress Tracker 的 approved/reviewed 計數重新核算
3. `affinity-data-pool.md` 標頭的「三處引用皆已寫 Approved」註記改為誠實反映查證結果(或先完成第 2 項使其成立)

**第二優先(2026-08-07 修法的傳播,同源問題,建議一次處理完)**:
4. `affinity-data-pool.md` Edge Cases/AC-47 補上生命週期通知的失敗終止路徑(B1),新增逾時/存活偵測後備義務(B2)
5. `save-system.md`「遷移失敗」全文改名「拒絕讀取」(Core Rules #13、AC-17/22/35/39)(B7)
6. `affinity-data-pool.md` Section L 同步 Section M 的「非原子視窗」判準措辭(B8)
7. `systems-index.md` 登記表第 171 列改為三分支分級告知(B6),第 151/153 列標頭措辭同步(W1)
8. `game-concept.md` 第 308 行同步 cursor-highlight-state.md 已定案的裝置權威判定機制(B9)

**第三優先(新設計缺陷,需要 creative-director 裁決或指派承接系統)**:
9. 負遠狀態的非空間維持成本機制,登記至 Cross-System Obligations Registry,指派給好感度—位置連鎖系統(C-1)
10. 敘事結局深度門檻上限與 Track B 二維形狀空間宣稱的衝突,需 creative-director 裁決是否維持天花板約束或修正形狀空間宣稱(C-2)
11. `source_absence` 的可逆性與範圍排除條款的前提矛盾,需修正 game-concept.md 的排除條款措辭或改變其資格判定(D-1)
12. 難度曲線段落與主角群固定裁決同步(E-1)
13. cursor-highlight-state.md 的鎖死缺陷對漸進回饋與拒絕回饋的連鎖失效,需在 Player Fantasy 揭露範圍中補充(F1)
14. 存檔系統與游標系統之間補上依賴登記(暫停選單/載入過場的游標交接),解決 AC-23 與 Core Rules #7 的真矛盾(F2-1/F2-2)
15. 登記表第 149 列與第 174 列的陣亡情境結構性互斥,需 creative-director 裁決(放寬 149 列的 t_query 限制、或承認 174 列對陣亡配對的例外)(F3-1)

**建議**:第一、二優先項高度重複前兩輪已驗證有效的「一次性外科手術式修訂」模式,估計影響範圍與前兩輪相當。第三優先項的 5 條是本輪真正意義上的新設計缺陷,其中 C-2 和 F3-1 涉及支柱層級/跨系統義務表結構性衝突,建議比照 game-concept.md 過往做法明確走 creative-director 裁決,而非留給下游系統自由裁量。
