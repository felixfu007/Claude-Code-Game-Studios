# Cross-GDD Review Report

**Date**: 2026-08-06
**GDDs Reviewed**: 3(`affinity-data-pool.md`, `save-system.md`, `cursor-highlight-state.md`)+ `game-concept.md` + `systems-index.md`
**Systems Covered**: 好感度數值池(Delta Log)、存檔系統(含跨規則集遷移)、單一游標/高亮狀態系統
**Entity Registry**: `design/registry/entities.yaml` — 3 個 formulas 已登記(皆來源 `affinity-data-pool.md`),entities/items/constants 皆為空,`last_updated: 2026-07-30`(未反映後續多輪修訂)

---

## Consistency Issues(Phase 2)

### Blocking

🔴 **戰棋移動與交戰系統在 systems-index 登記為「零依賴」,但已累積 6 條來自游標系統的硬性義務**
`systems-index.md` Systems Enumeration #4「戰棋移動與交戰系統」Depends On 欄為 `—`;Dependency Map「Core Layer」第 1 項無任何依賴標註。但 `cursor-highlight-state.md` Dependencies 表把該系統列為「呼叫方 + 讀取方」,施加至少 5 條必須級義務(告知初始游標目標、失效時呼叫重新解析介面、旗標無效期間拒絕確認操作、拒絕須伴隨可感知回饋、呼叫時必須傳入目標識別);Cross-System Obligations Registry 另有 6 列承接系統含該系統。
→ **建議**:在 #4 的 Depends On 欄與 Dependency Map Core Layer 第 1 項補上「單一游標/高亮狀態系統」。

🔴 **章節/戰役結構對好感度數值池的依賴完全缺席,且「前進戰役刻度」義務未登記於義務登記表**
`affinity-data-pool.md` Dependencies:章節/戰役結構是「寫入 + 戰役刻度推進」方,須於每場戰鬥/每章**開始時**呼叫「前進戰役刻度」介面,是 `c_now≥1` 恆成立、`spread_ratio` 不出現 0/0 的唯一保證來源。Tuning Knobs 與 Open Question 6 另要求該系統定案「戰役刻度推進粒度」並回填本文件。但:(一)`systems-index.md` #7 章節/戰役結構的 Depends On 只有「存檔系統」;(二)Cross-System Obligations Registry 20 列中沒有任何一列登記此義務。
→ **建議**:補依賴邊 + 新增一列義務,關閉條件為「章節/戰役結構 GDD 定案粒度並回填 affinity Tuning Knobs 與 Open Question 6」。

🔴 **「劇情事件是否為玩家離散主動行為」,兩份文件給出相反答案——動搖寫入來源封閉性與支柱四的論證**
`game-concept.md`(第六輪裁決):「所有寫入必須是玩家的離散主動行為(打出好感度對話卡牌 / 消耗支援對話名額 / 觸發劇情事件),…任何配對惡化都源自玩家可選擇不做的主動行為,不是被迫的環境結果。」
`affinity-data-pool.md`(第七輪義務):「`source_absence_se`(劇情事件分量)額外禁止被詮釋為玩家的任何選擇(劇情事件由章節/戰役結構系統觸發,非玩家離散主動行為)。」
兩者對同一來源類別的性質判定字面相反。若 affinity 的語意成立,則存在一條「玩家不可選擇不做」的負向寫入路徑,game-concept 的排除性結論不成立,支柱四的對稱分析與敘事可達性硬性約束都需要重新檢視。
→ **建議**:由 creative-director 裁決——(甲)劇情事件寫入限定為玩家在劇情中做出的選擇(維持 game-concept 措辭),或(乙)修訂 game-concept,承認劇情事件是系統寫入,補上「系統寫入不得使任何配對單調惡化」的獨立約束。

🔴 **「不得同時呈現兩個好感度數值」與 affinity 給下游 UI 的「是否需要並列顯示」選項直接衝突**
`game-concept.md`:「同一對角色關係,任何介面上都不得同時呈現兩個好感度數值——這正是第三輪駁回雙軸分流『玩家會困惑哪個才是真的關係』的理由…列為 `/art-bible`、`/ux-design` 的硬性約束。」
`affinity-data-pool.md` Dependencies(好感度視覺呈現 UI 列):「設計時須明確處理『同一份底層資料、兩種讀值不一致』的呈現方式(是否需要並列顯示、是否需要提示文字說明差異來源)」。
affinity 把 game-concept 明文禁止的方案列為可選項交給下游。
→ **建議**:刪除「是否需要並列顯示」選項,改為明文複述 game-concept 的禁止條款,並要求下游以單一數值 + 定性提示滿足溝通需求。

🔴 **分步遷移執行模型落在 affinity「同步/非同步」二分之外,存檔系統單方面宣告不需要通知介面,上游文件從未同步**
`affinity-data-pool.md` Edge Cases/AC-47 只列舉兩種模型:非同步/執行緒化(規則生效)與同步阻塞式(規則 N/A)。
`save-system.md` Core Rules #5 引入第三種:分步執行——「每次只執行一個版本躍遷…步與步之間主動讓出控制權」,並斷言「不需要回頭補上好感度數值池的序列化生命週期通知介面(該介面服務的是背景執行緒序列化,與本模型無關)」。
但同一份文件 Core Rules #5 緊接著自承:「分步執行的存在理由本身…打破了 Core Rules #4『單執行緒⇒不需鎖定』結論原本免費成立的前提…讓出視窗期間…任何其他程式碼都能在同一條主執行緒上執行」——並據此新增「同槽重入不變量」。**該前提破裂的推論只套用到自己的槽介面,沒有套用到它對 affinity 施加的持久化義務**。
→ **建議**:回頭修訂 `affinity-data-pool.md` Edge Cases/AC-47 的前提列舉為三種模型(同步阻塞 / 單執行緒讓出 / 背景執行緒),明文裁定「單執行緒讓出」是否需要 begin/end 通知。

🔴 **退役名稱治理規則的措辭不雙向一致,且該規則在兩份文件皆無可執行的 AC**
`save-system.md` Core Rules #10:治理對象是「對照表成員」。`affinity-data-pool.md` Dependencies:治理對象是「實際被寫入過存檔的名稱」。兩者不等價。
更嚴重:affinity 的 AC-56/AC-57 完全不涵蓋退役/不得重用;save-system 側唯一的檢查 AC-51 標為不可執行;AC-41/AC-42 的 GIVEN 僅限「伴隨版本躍遷」的子情境,「未伴隨版本躍遷的重用」現有全部讀取端防線對此完全無感,曝險等同 R1 頭號風險。**兩份文件皆已 Approved,而各自自陳的最高風險失敗類別目前零條可執行 AC**。
→ **建議**:統一措辭為「曾經在對照表中出現過」,並在 affinity 新增一條 AC(enum 定義的全部合法名稱與退役名稱清單交集須為空)。

🔴 **裝置權威判定:game-concept 的無條件「最後操作裝置」規則與游標系統的兩項例外相牴觸**
`game-concept.md`(第四/五輪):「輸入裝置切換時,最後操作的裝置決定當前高亮的權威來源」——無任何例外。
`cursor-highlight-state.md` Core Rules #3:「此規則存在兩項例外」(滑鼠奪回權威的空間門檻、確認類動作不轉移權威)。
在「手把持有權威、玩家移動滑鼠並點擊」情境下,兩份文件給出相反的玩家可感知行為,且 `/ux-design`、`/art-bible` 讀的是 game-concept。
→ **建議**:回頭修訂 game-concept,加註「本規則的例外由 `cursor-highlight-state.md` Core Rules #3 定義,以該 GDD 為權威」(比照平台列的處理先例)。

🔴 **`save-system.md` AC-26 與 `affinity-data-pool.md` AC-47 在同步/非同步決定翻轉後無法同時成立**
AC-26:「確認本系統未實作 affinity-data-pool.md AC-47 原本要求的非同步生命週期介面」。AC-47 在非同步前提下要求存檔期間寫入必須被拒絕,依賴存檔系統提供 begin/end 通知介面。兩條 AC 的通過條件互斥於「非同步」分支,而 save-system 自己的 Open Questions 已把「同步阻塞式寫入在確認的主機平台目標上是否仍然成立」列為 `/create-architecture` 開始前必辦,並註明「主機平台的 SaveData API 常見設計上即為非同步」。
→ **建議**:AC-26 加註「本 AC 的 GIVEN 依賴 Core Rules #4 的 provisional 狀態;若該決定翻轉為非同步,本 AC 作廢並改由 affinity-data-pool.md AC-47 生效」。

### Warnings

- 好感度視覺呈現 UI 缺少兩條上游依賴邊(affinity、save-system 皆列其為讀取方,systems-index 依賴圖未完整反映)
- 活棋盤地形演變系統與存檔系統之間無依賴邊,且與 Foundation Layer「不依賴玩法系統」的敘述方向相反
- game-concept 第七輪兩條 UI 硬性約束(不得並列數值、卡牌 UI 揭露義務)從未進入義務登記表
- AC-47 與序列化生命週期通知介面的 provisional 標記,affinity/save-system/systems-index 三方描述不一致
- `affinity-data-pool.md` Status 仍寫「In Design」,與 systems-index、save-system、entities.yaml 的 Approved 引用直接矛盾
- `systems-index.md` 對游標系統的狀態落後一整輪(仍寫「待第十一輪覆核」,但第十一輪已完成並判定 MAJOR REVISION NEEDED,撤回同日修法),Progress Tracker 未反映此風險
- `design/ux/accessibility-requirements.md` 已於 2026-08-06 建立,但 Registry 兩列與游標 GDD 一列仍宣稱它不存在
- game-concept 技術考量對游標系統的三項描述已過期(Control offset transform 風險已由 spike 關閉、裝置權威判定已從建議升級為規則、初始游標狀態已定義)
- save-system Open Questions 的 Steam Cloud 列引用一個已關閉的 game-concept 平台缺口,觸發條件懸空
- 游標 GDD 對 game-concept 的行號引用已漂移(引用小節標題更穩健)
- Progress Tracker「Design docs reviewed 2」把「已審查」與「已核准」混同,未反映游標系統已投入 11 輪審查仍未收斂
- 存檔系統對 UI 施加的六項義務被指派給一個範疇不涵蓋它們的系統(好感度視覺呈現 UI)與一個不存在於 14 系統列舉的系統(存檔管理 UI)
- 全域裝置狀態指示元件的擁有者要求(必須是全域生命週期節點)與 Registry 承接系統欄(三個畫面範圍候選)互相排斥
- 義務登記表有兩組重複列(教學掛鉤義務、無障礙需求轉交聲明各自重複一次)
- save-system 完備性執行紀錄表二聲稱「共 67 條」,實際計數為 63 條,表二列舉範圍加總為 61 條,遺漏 AC-59(同槽重入不變量的唯一驗收依據)與 AC-60

**Consistency Verdict: FAIL**

---

## Game Design Issues(Phase 3)

### Blocking

🔴 **敘事可達性硬性約束 vs Track B「互斥可得性」字面矛盾**
`game-concept.md` 敘事可達性硬性約束(支柱層級,全稱):「任何敘事結局,都不得因為前 N 場戰鬥的數值累積而變成永久不可達」。但 `affinity-data-pool.md` 已交付的形狀特徵中,`total_churn`(非遞減,無上界)、`reversal_count`(非遞減)、`source_absence`(`absent_confirmed→active` 單向)在 append-only 模型下單調不可逆——任何以它們為條件的結局,一旦跨過門檻即永久不可達。而 game-concept Track B 交付項第 4 項(硬性交付項)要求的正是這種永久不可達:「純戰鬥路線必須有只有它拿得到、聊過天的玩家永遠拿不到的獨佔敘事內容」。兩條約束字面直接衝突,`source_absence` 正是把衝突具體化的資料原語。
→ **建議**:交由 creative-director 裁決,收窄敘事可達性硬性約束的適用範圍——建議僅適用於深度/強度連續量門檻(戰役模擬證實會產生不可達的機制),不適用於刻意設計的互斥形狀閘門;並要求互斥閘門觸發前對玩家有明確揭露。裁決後須同步寫入 game-concept 兩處與 affinity Dependencies,並登記至 Registry。

🔴 **`affinity-data-pool.md` 向下游 UI 提出一個被支柱層級 UI 硬性約束明文禁止的選項**(與 Consistency 2b 同一發現,Phase 2 與 Phase 3 獨立收斂於同一處)

### Warnings

⚠️ **跨系統注意力預算疊加,教學揭露順序擁有權分裂**
game-concept 對「五層 UI 資訊疊加」的處理紮實(跨棋子比較能力、全圖模式降維、色盲友善、教學揭露順序),但該清單已被後續設計實質超出而未同步:cursor-highlight-state 強制的三態視覺狀態、全域裝置狀態指示元件、預判模式標記(已裁定為正式功能)、每單位淨聯動聚合值——實際層數已達 8-9 層,但下游 `/art-bible`、`/ux-design` 收到的仍是「五層」預算。且擁有權分裂:game-concept 把教學揭露順序指派給 `/art-bible`/`/ux-design`,systems-index Registry 卻把滑鼠奪權漸進回饋的教學掛鉤另外指派給教學/上手引導系統,兩者互不知情。
→ **建議**:game-concept 心流狀態設計節改為可增補清單並納入新增 4 項;教學揭露順序指定單一擁有者(建議教學/上手引導系統),Registry 補列。

⚠️ **無界形狀特徵(`total_churn`/`net_source`)缺穩態校準指引**
穩態封閉解章節只為深度/強度軸提供封閉解與校準地板,`net_source`/`total_churn` 不受 λ 影響、無界、無穩態,但 Dependencies 又要求敘事解鎖系統必須交叉參照它們。絕對門檻會隨戰役長度漂移,與第六輪引入時近性加權要解決的問題同型,只是發生在被刻意豁免加權的軸上。
→ **建議**:affinity Dependencies 補一句硬性提醒——形狀特徵中的無界量不得作為絕對門檻使用,須以戰役刻度或筆數正規化後再設門檻。

⚠️ **「以弱勝強」數值劣勢設計義務在 `/map-systems` 後成孤兒**
game-concept 明文指派此要求給「日後負責戰鬥公式的系統 GDD」,`/map-systems` 已確定為 #4 戰棋移動與交戰系統,但 High-Risk Systems 表與 Cross-System Obligations Registry 皆無此系統的相應列。連帶地,Registry 目前 31 列的登記來源全部是三份已完成系統 GDD,**game-concept.md 來源零列**——而 game-concept 累積了大量指向 Not Started 系統的支柱層級硬性約束(取捨結構非空間軸線、疊加規則定案順序、tie-break 規則、負遠狀態維持成本、Track B 五項交付項、支援對話機制形狀差異化、地形壓縮測試位置)全數未登記。
→ **建議**:Registry 補上一組 game-concept.md 來源的列,High-Risk Systems 表新增戰棋移動與交戰系統一列。

⚠️ **`cursor-highlight-state.md` 的「無直接美學支柱(純基礎設施)」聲稱站不住腳**
該文件擁有跨系統視覺狀態語言(三態視覺兩兩可辨別)、強制存在的全域 HUD 元件(硬性行為要求)、無障礙硬性約束(色盲友善)、以及需要教學的新回饋機制(漸進回饋),不是「無直接美學支柱」的系統。
→ **建議**:改寫為「無獨立美學支柱,但擁有跨系統視覺狀態契約,須納入 `/art-bible` 範圍;服務支柱一的前提」。

### 可執行且未發現問題

- 好感度雙重讀取設計與 game-concept 最新裁決完全一致(逐條核對通過)
- 無任何一份 GDD 違反反支柱
- 三份 Player Fantasy 共同建構一致的「軍師」認同,方法論高度一致(值得記錄為既有優勢);唯發現承諾一在 affinity 為絕對措辭、在 save-system 被加上「已成功寫入的最後一個進度邊界」範圍限制,上游未回頭同步(WARNING,已併入 Consistency 未列出的細項,建議 affinity Player Fantasy 承諾一補範圍註記)
- 玩家稱代詞不一致:affinity 使用「妳」,其餘全部用「你」——與本作反戀愛路線定位裁決方向相反,建議統一為「你」

### 因系統未完成而延後的檢查項

| 檢查項 | 解除條件 |
|---|---|
| 3a 進度迴圈競爭 | 戰棋移動與交戰、技能卡牌、章節/戰役結構、支援對話四系統完成(至少 2 份含迴圈定義) |
| 3c 支配性策略偵測 | 好感度—位置連鎖系統(疊加規則、同時生效對數上限、tie-break、陣亡處理)+ 戰棋移動與交戰系統完成 |
| 3e 難度曲線一致性(主體) | 戰棋移動與交戰系統定案「以弱勝強」數值劣勢設計,MVP 驗收協議須以劣勢條件重新驗證 |
| 3d 經濟迴圈分析(完整版) | 技能卡牌系統定案手牌上限/棄牌/持有時限;支援對話系統定案完成時機規則 |
| 3f 支柱對齊(Track B 五項交付項驗證) | 敘事解鎖與結局分支系統完成,並寫出至少兩組「深度相近、形狀不同」判定草案 |
| 3b 注意力預算(實測驗證) | 垂直切片階段以新玩家實測完整層數可讀性 |

**Design Theory Verdict: CONCERNS**

---

## Cross-System Scenario Issues(Phase 4)

**走查情境**:(1) 戰鬥中從暫停選單載入存檔、遷移鏈分步執行;(2) 章節開始的自動存檔 → 關機 → 載入還原;(3) 一場戰鬥中單位在游標對準時死亡;(4) 游標目標失效期間的好感度連線/聚合值預覽;(5) 未來新增第四種好感度變化來源。

### Blockers

🔴 **S1 — 分步遷移讓出視窗期間,Delta Log 寫入無任何防線**(存檔系統 × 好感度數值池)
遷移鏈分步執行時每步之間讓出控制權,活的戰鬥場景可能在此視窗寫入正在被遷移/還原的 Delta Log。save-system 的重入拒絕範圍明文只涵蓋「完整讀取介面、一般寫入介面」,不含 Delta Log 寫入;affinity 的序列化旗標規則字面只涵蓋「序列化」方向,不涵蓋「還原/遷移」方向,且其二分法(同步/非同步)未涵蓋分步讓出這第三種模型——save-system 自己在同一條規則下方已發現「單執行緒不再蘊含不會交錯」,卻只回頭修了槽層級重入,沒有回頭修第三輪那句「不需要好感度數值池通知介面」的結論。失效後果:遷移完成覆蓋記憶體狀態時,期間發生的好感度寫入被靜默丟棄——同時違反兩份文件自陳最毒的失敗類別(靜默資料遺失)。
→ **需要解決**:(一)save-system Core Rules #5 的「不需要通知介面」結論須重新判定;(二)affinity Edge Cases 規則範圍須從「序列化」擴大到「序列化與還原/遷移」;(三)其二分法前提須新增第三項(分步讓出模型);(四)save-system Core Rules #16 矩陣建議新增「跨文件接縫」分區。

🔴 **S3 — 競態防呆的靜默丟棄使永久失效目標被判定為有效**(游標系統 × 戰棋移動與交戰系統)
三條各自正確的規則組合後失效:「標記待重新解析」的競態防呆對不相符的目標識別靜默忽略且不回傳任何結果 → 呼叫方無從得知標記被丟棄 → 玩家導覽自動解析等同呼叫「設定新目標」,翻回有效。具體場景:單位 A 死亡瞬間玩家已導覽離開(過期標記被靜默丟棄),之後玩家導覽回 A 格,游標系統回報 `target=A, valid=true`——移動範圍/攻擊射程/好感度連線預覽以確信樣式渲染一個屍體格,確認鍵不攔截,精準命中游標系統自己定義的頭號失敗情境。AC-24 只考慮「完全沒有呼叫」的停滯情境,AC-37 反而把靜默忽略正典化為通過條件。
→ **需要解決**:二選一——(a)「標記待重新解析」介面新增明確回傳值(已套用/已過期被忽略)並要求呼叫方對過期結果重試;或(b)新增「每次設定新目標後須重新驗證新目標遊戲語意有效性」的下游義務。systems-index 第 153 列關閉條件須同步擴大。

🔴 **S2 — save-system 對 affinity 已宣告驗證規則的事實宣稱不成立**(存檔系統 × 好感度數值池)
save-system Core Rules #7 宣稱:「目前唯一已定案的來源系統(好感度數值池)已在 Dependencies 章節宣告其驗證規則」——查證後此宣稱不成立。affinity Dependencies 存檔系統列只有持久化要求與索引鍵治理,沒有任何欄位值域/型別宣告。套用 save-system 自己的 AC-44 字面,今天執行會直接觸發 `DATA_CORRUPTED`。更深一層:跨欄位/跨結構不變量完全無人宣告(例如「Delta Log 非空則標記列表必非空」),違反此不變量會直接導致 `spread_ratio` 除以零——affinity 對「除以零不會發生」的安全性論證只涵蓋執行期呼叫時機,對存檔還原/遷移產生的狀態零涵蓋。
→ **需要解決**:affinity Dependencies 須新增真正的「反序列化語意驗證規則宣告」小節(逐欄位值域 + 跨結構不變量)並補對應 AC;save-system Core Rules #7 的事實宣稱須改為指向該新小節。**建議在移交 `/create-architecture` 之前完成**——否則實作階段會產出一個名目存在、實質為空的驗證器。

### Warnings

⚠️ **S2 — 自動存檔與「前進戰役刻度」的相對順序未定義**(存檔系統 × 好感度數值池 × 章節/戰役結構)
兩份 GDD 對章節/戰鬥開始的同一時刻各自指派一個呼叫,無任何文件定義先後順序。若定案「先存檔、後前進刻度」而載入路徑走捷徑(不重跑章節開場邏輯),本章刻度前進永久遺失,污染 `segment_profile`/`spread_ratio`。systems-index 第 170 列關閉條件不涵蓋此順序問題。
→ **需要解決**:關閉條件擴大為「觸發點清單 + 與前進戰役刻度的相對順序 + 載入路徑是否重跑章節開場刻度前進」。

⚠️ **S5 — 新增第四種好感度來源會讓讀取層窮舉表靜默失效**(存檔跨規則集遷移 × 好感度數值池讀取層)
持久化四道防線對新增來源成員的處理正確,但讀取層的窮舉表(`w(source_i)` 權重表、3b/3d/3e/3g 的逐來源分量)全是硬編碼三分量,新增第四種來源後查表未命中/輸出範圍宣稱失效,而 affinity 對此無任何約束或 AC。cursor-highlight-state 對完全同型問題(表面類型列舉新增成員但門檻表未同步)已建立原子同步約束與 AC-46b,affinity 沒有對應防護。
→ **需要解決**:比照 cursor 先例新增「來源列舉成員 ⊆ 權重表鍵值集合」的原子同步約束與對應 AC;Player Fantasy 承諾一加註範圍(對新增讀取函數成立,對新增寫入來源不成立)。

⚠️ **S3 — 「陣亡當下」缺乏跨系統共用定義,捕捉責任未指派**(游標 × 好感度數值池 × 戰棋移動與交戰 × 好感度—位置連鎖)
三份文件各自對「陣亡」下義務,但沒有任何一份定義陣亡的權威時刻,也沒有任何系統被指派在陣亡當下捕捉並保存全域計數器值(affinity 要求下游用此值查詢,但取得此值的唯一途徑是有人在陣亡當下呼叫一次讀取函數,無規則要求誰做)。此值還須跨戰役持久化才能在存檔載入後供結局判定使用,但 save-system 持久化清單中沒有這個欄位。
→ **需要解決**:systems-index 第 147 列關閉條件擴大為「陣亡時刻捕捉責任歸屬 + 持有位置 + 是否納入存檔持久化」,並在三份文件間確立共用的「陣亡權威時刻」定義。

### Info

ℹ️ **S4 — 釘選集合聚合值預覽逃脫「下游預覽渲染義務」字面範圍**(游標 × 好感度視覺呈現 UI)
游標系統的下游預覽渲染義務範圍限定於「讀取目前游標目標座標值」的預覽,不涵蓋以釘選集合為輸入的淨聯動聚合值(game-concept 第五輪裁決)。同一畫面可能出現「A 格顯示待重新解析」與「關係圖迷你地圖為 A 顯示確信聚合數字」並存。因好感度視覺呈現 UI 尚未設計,可在該 GDD 設計時一併處理,標記 INFO 而非 WARNING。
→ **建議**:systems-index 第 161 列關閉條件加一句「須明確處理釘選集合聚合值是否亦受此義務約束」。

**核心模式觀察**:三個 BLOCKER 全部落在「單份文件內部完備、跨文件接縫無人負責」的位置——各文件自己的完備性檢查表都只掃自己的規則,不掃跨文件宣稱。`save-system.md` 第五輪剛建立的完備性執行紀錄表構造上只掃自己的 16 條規則。建議在 Registry 增設「宣稱依賴」欄(A 文件的某條規則是否引用了 B 文件的事實 / B 文件是否確認該事實成立)。

**Scenario Verdict: FAIL**

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| `affinity-data-pool.md` | Status 仍寫 In Design;劇情事件寫入性質矛盾;並列顯示選項違反硬性約束;分步遷移下無寫入防線;驗證規則宣告不存在;新增來源缺同步約束;敘事可達性 vs Track B 矛盾;承諾一缺範圍註記;稱代詞不一致 | Consistency + Design Theory + Scenario | Blocking |
| `save-system.md` | 分步遷移二分法未涵蓋;AC-26/47 provisional 未同步;完備性表算術缺口;對 affinity 驗證規則的事實宣稱不成立 | Consistency + Scenario | Blocking |
| `cursor-highlight-state.md` | 競態防呆靜默丟棄漏洞;裝置權威判定與 game-concept 矛盾;「無美學支柱」聲稱站不住腳 | Scenario + Design Theory | Blocking |
| `game-concept.md` | 敘事可達性 vs Track B 互斥可得性矛盾(需 creative-director 裁決);劇情事件性質矛盾;技術考量三處過期;「以弱勝強」等多項義務零登記 Registry | Design Theory + Consistency | Blocking |
| `systems-index.md` | 游標系統狀態落後一輪;多項依賴邊/義務登記缺口與重複;完備性表引用需更新;多個關閉條件範圍過窄(第 147/153/161/170 列) | Consistency + Scenario | Warning |

---

## 使用者裁決紀錄(2026-08-06,同日追加)

**裁決 1(劇情事件寫入性質)**:**乙——劇情事件是系統寫入**,維持 `affinity-data-pool.md` 既有措辭。已修訂 `game-concept.md`「寫入來源封閉性」段落:區分玩家離散主動行為(類別一)與系統觸發寫入(類別二),新增系統觸發寫入不得無代價單調惡化的獨立約束,已登記至 `systems-index.md` Cross-System Obligations Registry(承接系統:章節/戰役結構、支援對話系統、技能卡牌系統)。

**裁決 2(敘事可達性約束範圍)**:**收窄約束,排除單調形狀特徵**。已修訂 `game-concept.md`「敘事可達性硬性約束」段落:約束範圍限縮為深度/強度連續量門檻,明文排除刻意設計的互斥形狀閘門(呼應 Track B 交付項第4條),新增觸發前揭露義務,已登記至 `systems-index.md` Cross-System Obligations Registry(承接系統:敘事解鎖與結局分支系統)。

兩項裁決皆已於同一 session 內完成 `game-concept.md` 與 `systems-index.md` 的對應修訂。**Consistency 2b 的兩項 BLOCKING(劇情事件性質矛盾、敘事可達性矛盾)與 Design Theory 3f/3d 對應的 BLOCKING 項已解決。**

## 剩餘 11 項 BLOCKING 修訂紀錄(2026-08-06,同日追加,不需裁決之項目)

以下 11 項已於同一 session 內全數修訂完成,依報告 Required Actions 清單逐項處理:

1. ✅ **依賴圖補邊**:`systems-index.md` #4 戰棋移動與交戰系統補上依賴單一游標/高亮狀態系統;#7 章節/戰役結構補上依賴好感度數值池。
2. ✅ **前進戰役刻度義務登記**:Cross-System Obligations Registry 新增兩列(呼叫時機粒度回填義務;自動存檔與前進戰役刻度相對順序義務)。
3. ✅ **移除並列顯示選項**:`affinity-data-pool.md` Dependencies 好感度視覺呈現 UI 列改為明文複述 game-concept UI 硬性約束,禁止並列顯示。
4. ✅ **分步遷移二分法擴充+ Delta Log 寫入防線**:`affinity-data-pool.md` Edge Cases/AC-47 判準由「同步/非同步」改為「是否存在非原子視窗」,分步遷移對此視窗生效;`save-system.md` Core Rules #5 撤回「不需要通知介面」的錯誤結論,改為須呼叫好感度數值池生命週期通知介面;`systems-index.md` Registry 兩列由 provisional 轉為確定需要。
5. ✅ **退役名稱治理措辭統一**:`affinity-data-pool.md` 改用「曾經在對照表中出現過」對齊 `save-system.md`,新增 AC-58(退役名稱不重用,交集驗證)。
6. ✅ **裝置權威判定引用權威**:`game-concept.md` 補充「本規則具體例外以 `cursor-highlight-state.md` Core Rules #3 為權威」。
7. ✅ **AC-26 加註 provisional 條件**:明確排除遷移執行模型範圍,加註若 Core Rules #4 翻轉為非同步則作廢。
8. ✅ **反序列化語意驗證規則宣告**:`affinity-data-pool.md` Dependencies 新增完整小節(逐欄位值域 + 跨結構不變量),新增 AC-59;`save-system.md` Core Rules #7 的事實宣稱改為指向該新小節。
9. ✅ **競態防呆靜默丟棄修正**:`cursor-highlight-state.md` 「標記待重新解析」介面新增結構化回傳值(已套用/已過期未套用),呼叫方新增重驗義務;AC-37 擴充斷言;Registry 對應列擴大範圍。
10. ✅ **完備性執行紀錄表二算術修正**:`save-system.md` 總數由「67」修正為「63」,補齊遺漏的 AC-59/AC-60 至 G2 列。
11. ✅ **`affinity-data-pool.md` Status 更新為 Approved**,並順帶修正稱代詞不一致(「妳」→「你」)、Player Fantasy 承諾一補上與 `save-system.md` 對稱的範圍聲明。

**全部 13 項 BLOCKING(2 項需裁決 + 11 項不需裁決)已於本 session 內修訂完成。** 建議下一步:針對受影響章節重跑對應 GDD 的 `/design-review`(不需全篇重審),確認修訂無新接縫後,重新執行 `/review-all-gdds` 驗證 Verdict 轉為 PASS 或 CONCERNS,再進入 `/create-architecture`。WARNING 級項目(承諾一範圍已隨機修訂,其餘如 game-concept 技術考量過期描述、以弱勝強義務登記等)可與架構階段並行處理,不阻擋移交。

---

## Verdict: **FAIL**

### 為何是 FAIL

三個 Phase 各自獨立收斂於同一類根因:**單份文件內部審查已高度成熟**(affinity 七輪 + 兩次局部修訂、save-system 五輪、cursor-highlight-state 十一輪),**但跨文件的宣稱從未被交叉驗證**——一份文件引用另一份文件的「事實」(例如 save-system 宣稱 affinity 已宣告驗證規則、affinity 宣稱序列化旗標機制涵蓋所有並發模型),從未查證該事實是否真的成立。這正是本專案 Cross-System Obligations Registry 存在的理由本身要防止的失敗模式,只是這次發生在「宣稱」層級而非「登記」層級。

去重後合計 **13 項 BLOCKING**(Consistency 8 + Design Theory 2 + Scenario 3),多數是一到三句話的外科手術式修訂,**不需要推翻任何一輪既有架構裁決**。兩項需要 creative-director 裁決(劇情事件寫入性質、敘事可達性約束收窄範圍),其餘皆可由對應 GDD 的 owner 直接修訂並經標準 `/design-review` 復核。

### Required Actions Before Re-running

1. **`affinity-data-pool.md`**:更新 Status;裁決劇情事件寫入性質(或修訂措辭);刪除「並列顯示」選項;新增反序列化語意驗證規則宣告小節(逐欄位值域 + 跨結構不變量)並補 AC;新增來源列舉原子同步約束(比照 cursor-highlight-state 先例)並補 AC;Edge Cases/AC-47 前提列舉擴充第三種執行模型;Player Fantasy 承諾一補範圍註記;稱代詞統一為「你」;裁決敘事可達性約束的適用範圍收窄。
2. **`save-system.md`**:Core Rules #5 對「不需要通知介面」結論重新判定;AC-26 加註 provisional 條件;完備性執行紀錄表二補齊 AC-59/AC-60 並修正總數;Core Rules #7 對 affinity 驗證規則的事實宣稱改為指向新小節。
3. **`cursor-highlight-state.md`**:「標記待重新解析」介面新增明確回傳值或補上下游重驗義務;裝置權威判定與 game-concept 的關係加註;「無直接美學支柱」措辭修正。
4. **`game-concept.md`**:敘事可達性約束收窄範圍(等待 creative-director 裁決);劇情事件性質裁決同步;技術考量三處過期描述更新;「以弱勝強」等義務補登記至 Cross-System Obligations Registry;UI 硬性約束補登記。
5. **`systems-index.md`**:依賴圖補邊(#4、#7、#9、#14);游標系統狀態同步至第十一輪結果;Registry 補列(game-concept 來源義務、存檔管理 UI 承接系統)並去重(第 155/157、156/158 列);第 147/153/161/170 列關閉條件擴大範圍;Progress Tracker 反映實際審查輪次。

建議完成上述修訂後,針對受影響章節重跑 `/design-review`(不需要全篇重審),再重新執行 `/review-all-gdds` 確認 Verdict 轉為 PASS 或 CONCERNS 後,方可進入 `/create-architecture`。
