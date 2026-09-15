# Story S-007:公式一/二 —— 兩個加權讀取 + 陣亡凍結預設 + `0^0:=1` + `O(n_p)` 診斷

> **Epic**:好感度數值池(Delta Log)—— 資料層(`production/epics/affinity-data-pool/EPIC.md`)
> **型別**:Logic
> **狀態**:📋 Ready
> **估時**:M
> **依賴**:S-003、S-006

## Context

- **GDD**:`design/gdd/affinity-data-pool.md` Formulas 公式一(戰鬥強度讀取)、公式二(敘事深度讀取)、Core Rules #1「效能介面要求」與「診斷可觀測性要求」、Core Rules #3(陣亡配對的預設查詢時點)、邊界值測試總表
- **Governing ADR**:ADR-0002(**Accepted**)—— 機制五(讀取路徑,條件式預設查詢時點的實際計算)、機制六(計數器可觀測性與 QA 診斷輸出的分離)
- **Engine**:Godot 4.7.1

## 目標

把 S-006 交付的空殼讀取函數,填入公式一(`combat_strength_read`)與公式二(`narrative_depth_read`)的真正加權計算邏輯。做完之後,「這對角色現在的好感度是正是負、有多強」與「這段關係走過什麼樣的軌跡(依來源加權)」這兩個問題**第一次真的算得出來**——這是本 epic 唯二的「數值端」讀取函數(第三個,形狀特徵讀取,屬 S-010/S-011)。

## 🔴 本 story 決定的原始碼目錄路徑

沿用既定決定:`src/gameplay/affinity_pool/affinity_data_pool.gd`(同檔,擴充 S-006 已建立的兩個函數本體)。

## Implementation Notes

出自 GDD Formulas 與 ADR-0002:

1. **公式一(戰鬥強度讀取)**:`combat_strength_read(p, t_query=t_now) = Σ (m_i · λ_combat^(t_query − t_i))`,對配對 `p` 中所有 `t_i ≤ t_query` 的記錄加總,所有來源權重相同(=1.0)。
2. **公式二(敘事深度讀取)**:`narrative_depth_read(p, t_query=t_now) = Σ (w(source_i) · m_i · λ_narrative^(t_query − t_i))`,其中戰鬥好感度對話卡牌來源 `w=α`,其餘來源 `w=1`。
3. 🔴 **`0^0 := 1` 顯式特判,不得依賴引擎預設行為**(ADR-0002 Verification Required #3 已實測 GDScript `pow(0.0, 0.0)` 回傳 `1.0`,`**` 運算子同):**即使答案已知相符,契約仍不允許依賴它**——理由是 GDD Formulas 邊界值測試總表要求的是「不建立對引擎預設行為的依賴」,不是「數值是否碰巧相符」。實作必須顯式處理 `age_i=0`(即 `t_query=t_i`)的情形,不可只寫 `pow(lambda, age)` 了事。
4. 🔴 **陣亡配對的條件式預設查詢時點(Core Rules #3,銜接 S-003 的 `t_death()`)**——省略 `t_query`(`null`)時:

   - **對存活配對**(`t_death(pair) == null`):預設為目前 `_t_now`。
   - **對陣亡配對**(`t_death(pair) != null`):預設為 `t_death(pair)`,**不是** `_t_now`——即使陣亡後全域計數器持續推進、甚至有合法的死後追憶寫入(來源為支援對話/劇情事件),這兩個函數省略 `t_query` 時的讀值**凍結**在陣亡當下,不再隨後續全域推進而衰減。
   - **`shape_feature_read` 不受此規則影響**(S-006 已建立、S-010/S-011 補完其計算邏輯),省略 `t_query` 時恆預設 `_t_now`,本 story 不改動這個既有分流。
5. **λ/α 一律為注入參數,不得寫死成常數**(EPIC.md「本次推翻的一項舊結論」段落結論,`.claude/docs/coding-standards.md`「Gameplay values must be data-driven」的可執行證據):`λ_combat`、`λ_narrative`、`α` 三者是**呼叫端/設定檔提供的參數**,不是實作要去查出來的常數——GDD AC-14(屬 S-010)已用三組不同的 `(λ_combat, λ_narrative, α)` 呼叫同一函數驗證這件事。校準值未定不阻擋本 story 的任何一條 AC。
6. **`λ=0` 的全域計數器行為(AC-31)**:因 `t_i` 是全域(跨所有配對共用)計數器,`λ=0` 時某配對的讀值只有在「該配對自己最新一筆記錄剛好是全域最新一筆好感度寫入」時才會非零;只要期間任何其他配對有更新的寫入,該配對的讀值會變成 `0`(而非「看到它自己的最新一筆」)。**不得寫死「無衰減」的特例分支**去繞過這個行為——這是全域計數器架構下的必然結果,不是缺陷。
7. **`λ=1` 的合法邊界行為(AC-16/AC-32)**:讀值退化為無界的全歷程累積總和,是刻意保留的合法校準狀態,不得拋出例外或產生 NaN/Infinity。
8. 🔴 **`O(n_p)` 效能與診斷輸出(Core Rules #1 效能介面要求 + 診斷可觀測性要求,機制六)**:兩個函數對配對 `p` 的單次查詢時間複雜度須為 `O(該配對自身的記錄筆數)`,不得為 `O(全域總筆數)`——底層儲存必須經由 S-004 已建立的 `_records[pair]`(`AffinityRecordList`)依配對索引存取,**絕不做「全表掃描後過濾 `pair_i=p`」**。額外提供一個**僅供 QA/除錯用途**的診斷輸出:本次呼叫實際走訪的記錄筆數(`diagnostic_visited_count`,S-006 已在型別上預留此欄位)。**此診斷輸出不是正式回傳簽章的一部分**(正式簽章只含 `t_query`/`n_pair`,見 Core Rules #3 計數器可觀測性規則),下游系統的**業務邏輯不得依賴此欄位**,純粹作為 QA 驗證 `O(n_pair)` 保證是否成立的確定性斷言依據(AC-55)。
9. **`t_death(pair)` 查詢的效能聲明**:計算 `t_death(p)` 所需的至多兩次陣亡標記表鍵值查找(S-003 交付)是 O(1),不影響本 story 的 O(n_p) 保證。
10. **輸出範圍(公式一)**:理論上無上限,本層不做夾限;`λ_combat<1` 且寫入速率有界時依等比級數收斂至穩態值,`λ_combat=1` 時退化為無界累積總和。衰減只會把讀值拉向中性(0),不會推向負值。
11. **輸出範圍(公式二)**:每一項的貢獻量值恆 ≤ 同一項在權重 1.0 時的量值(折扣只會縮小單項貢獻),但這個逐項上界**不能**推廣成「整體讀值的絕對值恆 ≤ 全權重讀值的絕對值」——不同來源記錄符號相反時,折扣可能讓加總後絕對值反而變大(GDD 已有具體反例,見 AC-12/AC-13 對照)。
12. 🔴 **`AC-25`/`AC-75` 的測試建構(GDD 明文,第十一/十二輪修訂,轉錄進本節供實作者對照)**:驗證「陣亡後凍結」須同時滿足三個前提,缺一都無法排除「完全未凍結、直接沿用 `t_now`」的錯誤實作:①陣亡後**其他配對**接續發生多筆寫入,使全域計數器明顯推進至遠大於 `t_death(p)` 的值;②本次查詢使用的 `λ_combat<1`、`λ_narrative<1`(排除合法邊界值 `λ=1`,該值下凍結/未凍結兩讀值代數上恆等);③陣亡當下的凍結基準本身**不為精確 0**,且所選 `λ` 與計數器推進量須使凍結/未凍結兩讀值差距明顯大於本章數值比對容許誤差(±0.01)。**建議做法**:採用 Tuning Knobs 建議校準範圍 `λ∈[0.90, 0.98]`,搭配顯著計數器推進量(例如 ≥10 個全域刻度)。

## Acceptance Criteria

*以下為 `design/gdd/affinity-data-pool.md` 的條文**原文轉錄**,未改寫:*

- **AC-3**: **GIVEN** 好感度—位置連鎖系統在戰鬥中對任意數量的站位/鄰近狀態進行讀取(呼叫 `combat_strength_read`),**WHEN** 記錄這些讀取呼叫前後的全域計數器數值(透過任一讀取呼叫回傳的 `t_query` 欄位觀測,見計數器可觀測性規則),**THEN** 計數器數值不變——純讀取呼叫不論次數多寡,絕不新增記錄。
- **AC-5**: **GIVEN** 配對 B 在全域計數器 t=1 時寫入一筆記錄(m=+5),其後配對 A(與 B 無共用角色)接續發生 4 筆寫入,使全域計數器推進至 t=5,期間配對 B 未再發生任何寫入,**WHEN** 在 t_now=5 時查詢配對 B 的 `combat_strength_read`,**THEN** 該筆記錄的 `age` = 5−1 = 4(而非 0),讀值 = 5 × λ_combat^4——證明配對 B 的 age 會因其他配對的活動而增長,而非只因自己被寫入才變舊。
- **AC-6**: **GIVEN** AC-5 情境,**WHEN** 查詢配對 B 的 `n(p)`,**THEN** `n(p)=1`(僅計入配對 B 自己的記錄筆數),即使全域計數器 t_now 已推進到 5——證明 `n(p)` 與 `t_now` 是兩個獨立追蹤的量。
- **AC-9**: **GIVEN** 配對 p 恰有兩筆記錄,幅度分別為 +5(t=10)與 −5(t=20),**WHEN** 以 λ_combat=1.0(合法邊界值,精確抵銷,不受衰減干擾)呼叫 `combat_strength_read(p)`,**THEN** 讀值精確等於 0,但同時回傳的 `n(p)=2`——驗證下游系統必須以 `n(p)` 而非讀值是否為 0 判斷「有無資料」。(注意:一般 λ_combat<1 時,兩筆不同 age 的記錄加權後幾乎不會精確抵銷為 0,此 AC 刻意選用 λ=1 排除這個混淆因素。)
- **AC-11**: **GIVEN** 兩份記錄集合,`pair`/`m_i`/`t_i` 完全相同,唯一差異是 `source_i`(集合甲全標 `combat_card`,集合乙全標 `support_conversation`),**WHEN** 分別呼叫 `combat_strength_read`,**THEN** 兩者回傳數值相同(誤差 <1e-9)——證明戰鬥強度讀取對來源不敏感,所有來源權重恆為 1.0。
- **AC-12**: **GIVEN** 配對 p 有三筆記錄:`(m=+2, t=10, source=combat_card)`、`(m=−1, t=25, source=support_conversation)`、`(m=+1, t=40, source=story_event)`,查詢於 t_now=42,λ_narrative=0.9,α=0.3,**WHEN** 呼叫 `narrative_depth_read(p)`,**THEN** 回傳值 ≈ 0.664(誤差 ±0.01)。**(2026-08-03 第七輪修訂,回應正式化 /design-review qa-lead 審查發現)**:原版本 THEN 子句額外斷言逐筆貢獻量(例如「第一筆貢獻被壓低為 0.0206」),但依 Acceptance Criteria 章節開頭的定義,讀取函數的回傳值僅為 `(數值, n(p), t_query)`,逐筆貢獻不在回傳簽章內,QA 無法黑箱驗證——已移除,僅保留可觀測的聚合值斷言。逐筆貢獻的推導僅為輔助說明,見下方「推導參考」,不構成本 AC 通過/失敗的判定依據。
  - **推導參考(非驗收依據)**:第一筆(`combat_card`)貢獻被壓低為 `0.3×2×0.9^32≈0.0206`,第二、三筆貢獻不受來源折扣影響(≈−0.1668、0.81),三者加總 ≈0.664。
- **AC-13**: **GIVEN** AC-12 同一份記錄集合,**WHEN** 呼叫 `combat_strength_read(p)`(λ_combat=0.9,t_now=42),**THEN** 回傳值 ≈ 0.712——對照 AC-12 的 0.664,證明同一份底層資料,`combat_strength_read` 不因來源打折,`narrative_depth_read` 因源自 `combat_card` 的那筆記錄而讀值較低。
- **AC-15**: **GIVEN** 配對 p 僅有一筆記錄 `(m=+2, t_i=t_now)`(age=0),**WHEN** 以 λ_combat=0(合法輸入,2026-07-30 裁決,範圍 [0,1])呼叫 `combat_strength_read(p)`,**THEN** 回傳值精確等於 2(即 `m_1 × λ^0 = m_1 × 1`,不得因 `0^0` 被引擎預設當作 0 而回傳 0)。
- **AC-16**: **GIVEN** 對同一配對連續寫入 100 筆記錄,每筆 m=+2(r=2),**WHEN** 以 λ_combat=1(合法邊界值)在第 100 筆寫入後立即查詢 `combat_strength_read`,**THEN** 回傳值精確等於 200(=Σm_i),呼叫不拋出例外、不產生 NaN 或 Infinity。**WHEN** 再寫入 100 筆同速率記錄(共 200 筆)後重新查詢,**THEN** 回傳值精確等於 400——證明 λ=1 時讀值隨筆數線性無界成長,是被接受的合法校準結果而非程式錯誤。
- **AC-17**: **GIVEN** 對同一配對連續寫入 100 筆記錄,每筆 m=+2(r=2),λ_combat=0.9,**WHEN** 在第 100 筆寫入後立即查詢 `combat_strength_read`,**THEN** 回傳值落在 20 ± 0.01 範圍內(對照封閉解 `r/(1−λ)=2/(1−0.9)=20`)。**WHEN** 再寫入 100 筆相同速率記錄(共 200 筆)後重新查詢,**THEN** 回傳值與前次查詢結果的差異 < 0.001——證明 λ<1 時讀值收斂至穩態,不隨記錄數量無限增長(與 AC-16 對照)。
- **AC-18**: **GIVEN** 一個「純戰鬥玩家」模擬配對,僅接收 `combat_card` 來源的寫入,固定速率 r_card=2、**寫入間隔固定為每 1 個全域刻度一筆(即 `t_i=1,2,3,...,100`,亦即週期 `k=1`,2026-08-03 第六輪補上明確假設,回應正式化 /design-review qa-lead 審查發現——原版本未指定寫入間隔,而本文件自身的校準注意章節已證明週期注入與連續近似在 `k` 較大時可能有明顯落差,QA 若不知道 `k` 無法建構出唯一對應的記錄集合)**、λ_narrative=0.9、α=0.3,累積至少 100 筆記錄,**WHEN** 於最新一筆寫入後立即呼叫 `narrative_depth_read(p)`,**THEN** 回傳值落在 6 ± 0.01 範圍內(對照封閉解 `pure_combat_floor = α·r_card/(1−λ_narrative) = 0.3×2/0.1 = 6`;`k=1` 時週期注入精確解與連續近似解相等,故此 AC 在 `k=1` 下無論用哪一種公式驗算結果相同)——此數值即為本系統提供給敘事解鎖系統校準地板值的驗證依據。此 AC 驗證的是 `k=1` 情境;真實 `k`(平均每戰寫入筆數)定案後,若 `k>1`,須另補一條以週期注入精確解重新驗證的 AC(見 Formulas 穩態封閉解章節的校準注意)。**測試建構方式的說明**:本 AC 的定位是**單元測試層級的公式驗證**(以人工建構的記錄集合直接餵入函數,不透過真實遊戲流程產生),用於確認 `k=1` 時 `pure_combat_floor` 的封閉解與函數實作一致,不主張這是遊戲實際運作中會出現的典型場景。
- **AC-25**(2026-08-10 第八輪修訂,2026-08-10 第十/十一/十二輪疊代修訂,轉錄最終版): **GIVEN** 配對中一名角色於戰役中陣亡,陣亡後未對該配對本身發生任何新寫入,**但陣亡後其他配對接續發生多筆寫入,使全域計數器明顯推進至遠大於 `t_death(p)` 的值**(比照 AC-5/AC-31 的建構手法,確保 `t_now` 與 `t_death(p)` 在查詢當下確實不同,而非因建構情境本身巧合相等),**且本次查詢使用的 `λ_combat<1`、`λ_narrative<1`(排除合法邊界值 `λ=1`),陣亡當下的凍結基準 `combat_strength_read(p, t_death(p))` 與 `narrative_depth_read(p, t_death(p))` 皆不為精確 0**,**且所選 `λ` 與陣亡後計數器推進量須使 `weighted_sum(t_death(p)) − λ^(t_now−t_death(p))·weighted_sum(t_death(p))` 的絕對值明顯大於本章開頭訂定的數值比對容許誤差(±0.01)**(**建議做法**:採用 Tuning Knobs 建議校準範圍 `λ∈[0.90, 0.98]`,搭配 AC-5/AC-31 建構手法產生的顯著計數器推進量〔例如推進 ≥10 個全域刻度〕,可穩定滿足此條件而不需逐案計算),**WHEN** 陣亡後對該配對呼叫 `combat_strength_read`/`narrative_depth_read`(省略 `t_query`),**THEN** 函數正常執行不拋出例外,回傳值與「以角色陣亡當下的全域計數器值為 `t_query` 呼叫」完全相同(即凍結於 `t_death(p)`),且**明確不等於**以目前推進後的 `t_now` 為 `t_query` 呼叫的結果——測試建構時真正需要選用的是滿足上述 `λ<1`、非零凍結基準、以及可觀測差距三個前提的參數/記錄組合,不是任意「看起來不同」的記錄——證明讀值確實凍結,不隨陣亡後流逝的 `t_now` 繼續衰減;**WHEN** 呼叫 `shape_feature_read`(省略 `t_query`),**THEN** 回傳值與角色存活時同一組記錄的計算結果相同(形狀特徵讀取不受此凍結規則影響,見 AC-62)。三個函數皆不拋出例外、不存在因陣亡觸發的清空,但戰鬥強度/敘事深度讀取確實存在因陣亡觸發的**凍結**分支,不再與形狀特徵讀取共用同一種「無特殊分支」的描述。
- **AC-31**: **GIVEN** 配對 B 於全域好感度寫入計數器 t=1 時寫入一筆記錄(m=+5),其後配對 A~J(B 以外的其他配對)接續發生多筆寫入,將全域計數器推進至 t=10,期間配對 B 未再被寫入,**WHEN** 以 λ_combat=0(合法邊界值)在 t_now=10 查詢配對 B 的 `combat_strength_read`,**THEN** 回傳值為 0(而非 5)——證明 λ=0 在多配對交錯寫入的場景下,只有「本配對是全域最後一次寫入」時才會反映該筆記錄,不是「永遠反映本配對自己最近一次互動」。同一情境以 λ_narrative=0 查詢 `narrative_depth_read`,結果同樣為 0。
- **AC-32**: **GIVEN** 對同一配對連續寫入 100 筆記錄,每筆 m=+2,來源皆為 `support_conversation`,**WHEN** 以 λ_narrative=1(合法邊界值)在第 100 筆寫入後立即查詢 `narrative_depth_read`,**THEN** 回傳值精確等於 200,不拋出例外、不產生 NaN 或 Infinity——與 AC-16(戰鬥端 λ=1 情境)對稱,證明敘事端同樣正確支援 λ_narrative=1 這個合法邊界值。
- **AC-33**: **GIVEN** 配對 p 僅有一筆記錄 `(m=+2, t_i=t_now, source=support_conversation)`(age=0),**WHEN** 以 λ_narrative=0(合法輸入)呼叫 `narrative_depth_read(p)`,**THEN** 回傳值精確等於 2(即 `w(source_1)·m_1·λ^0 = 1.0×2×1 = 2`,不得因 `0^0` 被引擎預設當作 0 而回傳 0)——與 AC-15(戰鬥端 0^0 慣例)對稱。
- **AC-34**: **GIVEN** 配對 p 有記錄 `(m=+3, t=5)`、`(m=+2, t=15)`,**WHEN** 以 `t_query=10`(早於第二筆記錄的寫入時間,但晚於第一筆)呼叫 `combat_strength_read(p, t_query=10)`,**THEN** 回傳值只計入第一筆記錄(age=10−5=5),完全不受第二筆記錄影響(即使第二筆記錄在「目前」的 Log 裡確實存在)——證明 `t_query` 能正確重現「回到某個歷史時間點」的讀值,不洩漏該時間點之後才發生的資訊。
- **AC-35**: **GIVEN** 配對 p 最早一筆記錄的 `t_i=20`,**WHEN** 以 `t_query=10`(早於該配對任何記錄)查詢任一讀取函數,**THEN** 三個讀取函數皆回傳 `n(p, t_query=10)=0` 與對應的中性/哨兵值,行為與「從未有任何記錄」完全一致。⚠️ **範圍註記**:`shape_feature_read` 分支本 story 只驗證 `n_pair=0` 與 S-006 已建立的六個非 `source_absence` 欄位哨兵值(`reversal_count=0`/`source_distribution=(0,0,0,0,0,0)`/`source_polarity=(0,0,0)`/`total_churn=0`/`time_distribution=null`/`segment_profile=null`/`low_confidence=null`)——這些是 GDD「空記錄邊界情況」段落定義的結構性哨兵,不依賴 `Q`/`n_min_segment`/`M` 任何 Tuning Knob。`source_absence` 分量的正確性(依賴 `M`)屬 S-011,本 story 不驗證該分量。
- **AC-55**(效能:`O(n_pair)` 存取複雜度): **GIVEN** 配對 p 有 `n_p` 筆記錄、其餘 9 對配對合計有 `N_other` 筆記錄(`N_other ≫ n_p`,`N_other` 至少改變一個數量級以上以排除量測雜訊),**WHEN** 呼叫任一真實讀取函數(`combat_strength_read`/`narrative_depth_read`/`shape_feature_read`)對配對 p 查詢,並讀取其診斷輸出(見 Core Rules #1「診斷可觀測性要求」)取得「本次呼叫實際走訪的記錄筆數」,**THEN** 該診斷值須精確等於 `n_p`,且在 `n_p` 不變、`N_other` 改變的兩次呼叫之間,診斷值完全相同(不隨 `N_other` 增減)——這是不依賴計時器雜訊的確定性斷言,直接證明底層儲存依配對索引存取、未對整份 Delta Log 做全表過濾掃描,取代原本的耗時量測。**輔助佐證(非本 AC 通過/失敗的判定依據)**:額外可用效能分析工具量測實際耗時,佐證診斷值差異確實反映在真實耗時上,但診斷值比對才是本 AC 的權威判定依據。
- **AC-62**: **GIVEN** 配對 (A,B),A 於全域計數器 `t_death` 陣亡,陣亡前有 N 筆記錄、陣亡後有 M ≥ 1 筆「支援對話」來源的追憶記錄,**WHEN** 呼叫 `narrative_depth_read(p)` 不帶 `t_query`,**THEN** 回傳值與 `narrative_depth_read(p, t_query=t_death)` 完全相同(誤差 < 1e-12),且不隨 M 增加而變化;**WHEN** 呼叫 `shape_feature_read(p)` 不帶 `t_query`,**THEN** 七項特徵納入全部 N+M 筆記錄,且 `source_polarity`/`total_churn`/`segment_profile` 三項與 M=0 的對照組**可觀測地不同**。**補充(2026-08-10 第九輪,回應 qa-lead 發現原版本未涵蓋 `combat_strength_read`,而 Core Rules #3 明文兩個讀取函數皆凍結)**:**WHEN** 呼叫 `combat_strength_read(p)` 不帶 `t_query`(沿用同一 GIVEN 情境),**THEN** 回傳值與 `combat_strength_read(p, t_query=t_death)` 完全相同(誤差 < 1e-12),且不隨 M 增加而變化——與上方對 `narrative_depth_read` 的斷言對稱。⚠️ **範圍註記**:本 story 只驗證 `combat_strength_read`/`narrative_depth_read` 兩者的凍結行為;`shape_feature_read` 對 `source_polarity`/`total_churn` 的可觀測差異部分本 story 可驗(這兩個子特徵不依賴 Tuning Knobs),`segment_profile` 部分依賴 S-010(分段剖面本體),本 story 不驗證 `segment_profile` 分量。
- **AC-75**(`t_death(p)` 的資料來源驗證): **GIVEN** 配對 (A,B),先以正常寫入介面對該配對寫入 2 筆記錄,再以角色 A 呼叫陣亡通知介面,**之後對其他配對(與 A、B 皆無共用角色)接續寫入若干筆記錄,使全域計數器明顯推進至遠大於陣亡標記表中 A 的標記值**,**且本次查詢使用的 `λ_combat<1`,陣亡當下的凍結基準 `combat_strength_read((A,B), t_death(A,B))` 不為精確 0**(排除前提同 AC-25),**且所選 `λ_combat` 與陣亡後計數器推進量須使凍結/未凍結兩讀值的差距明顯大於本章數值比對容許誤差(±0.01),理由與建議做法同 AC-25**,**WHEN** 之後呼叫 `combat_strength_read((A,B))` 省略 `t_query`,**THEN** 回傳值與明確帶入 `t_query=` 陣亡標記表中 A 的標記值時完全相同,且**明確不等於**以目前推進後的 `t_now` 為 `t_query` 呼叫的結果——證明 `t_death(p)` 確實由陣亡標記表計算並確實用於凍結,不是抽象量,也不是「省略 `t_query` 時單純沿用當下 `t_now`」的誤判空間。**本 AC 不依賴戰棋移動與交戰系統的實際程式碼**——直接呼叫本系統自身的陣亡通知介面即可構造 GIVEN,今日即可執行(比照 AC-59a/59b 的執行前提慣例)。

## Test Evidence

**型別**:Logic
**測試檔**(獨立單一檔):`tests/unit/gameplay/affinity_pool/affinity_data_pool_weighted_reads_test.gd`

預期涵蓋(逐條對應上方 20 條 AC,合併同源案例):

- `test_combat_strength_read_does_not_advance_t_now`(AC-3)
- `test_age_grows_from_other_pairs_activity`(AC-5)
- `test_n_pair_independent_of_t_now`(AC-6)
- `test_lambda_one_exact_cancellation_with_n_pair_two`(AC-9)
- `test_combat_strength_read_insensitive_to_source`(AC-11)
- `test_narrative_depth_read_matches_worked_example`(AC-12)
- `test_combat_strength_read_matches_worked_example_same_records`(AC-13)
- `test_zero_zero_convention_combat`(AC-15)
- `test_lambda_one_unbounded_linear_growth_combat`(AC-16)
- `test_lambda_less_than_one_converges_to_steady_state_combat`(AC-17)
- `test_pure_combat_floor_k_equals_one`(AC-18)
- `test_dead_pair_freezes_combat_and_narrative_but_not_shape`(AC-25)
- `test_lambda_zero_global_interleaving`(AC-31)
- `test_lambda_narrative_one_unbounded_linear_growth`(AC-32)
- `test_zero_zero_convention_narrative`(AC-33)
- `test_historical_t_query_does_not_leak_future_records`(AC-34)
- `test_t_query_before_earliest_record_returns_n_pair_zero_sentinel`(AC-35,範圍限定見上)
- `test_diagnostic_visited_count_equals_n_pair_regardless_of_other_pairs_size`(AC-55)
- `test_posthumous_writes_do_not_change_frozen_combat_and_narrative_reads`(AC-62,範圍限定見上)
- `test_t_death_actually_used_as_frozen_query_point`(AC-75)

## Out of Scope

- **形狀特徵讀取的七項子特徵計算本身**(公式三)——屬 S-010/S-011,本 story 只驗證 `shape_feature_read` 在陣亡/`n(p)=0` 情境下**不受本 story 新增邏輯影響**的既有骨架行為。
- **`source_absence`(3g)子特徵**——依賴 `M` Tuning Knob,屬 S-011。
- **`λ_combat`/`λ_narrative`/`α` 的實際校準數值**——留待 playtest 階段(Open Questions),本 story 只保證三者可注入、不寫死。
- **公式四(預判/假設性讀取)**——屬 S-012(切片外)。
