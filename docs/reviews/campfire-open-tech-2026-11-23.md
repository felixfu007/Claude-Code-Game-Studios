# 營火開放技術題(lead-programmer,2026-11-23)

> 只讀碼加一支拋棄式引擎探針;未改任何既有檔。行號會漂,要現值請重新 grep。
> 證據等級:(A) 引擎實跑專案程式碼並附檔案路徑與 log / (B) 讀碼 / (C) 推測。
> 「估計天」一律未驗證。

## 與前次回答、裁決檔不符之處(先看這裡)

1. **前次回答 ② 末段寫「標題畫面『開始』直接 `enter_battle()`(`title_screen.gd:173`)」不準確。**
   實查:標題的「開始」按鈕接的是 `start_tutorial`(`title_screen.gd:137`),會先 `TutorialProgress.begin()` 進教學場;
   `start_battle()`(直接進戰役)只有命令列旗標 `--capture-battle` 會走(148 行)。(B)
   **不變的部分**:兩條路都不重置戰役進度。`reset_campaign()` 的正式呼叫端仍只有一處,
   就是打贏最後一場(`battle_screen.gd:6135`)。(B,`grep -rn "reset_campaign()" src` 當場查)
   所以「同一次執行內回標題再按『開始』,會接續舊場次與舊累積記錄」的推論仍成立,只是中間多一段教學場。
2. **`CampaignProgress` 在 `src/core/campaign/campaign_progress.gd`**,不是前次引用的 `gameplay` 路徑。
   `CampaignAffinityLedger`、`CampaignAffinityPoolRebuilder` 在 `src/gameplay/campaign/`。(B)
3. 裁決檔「尚未處理」第 2 項(對話挑段是否已綁死)已查清,見題 2。

---

## 題 1:營火寫入的來源值

**結論:用 `SUPPORT_CONVERSATION`,下一場讀到的就是寫入值,不乘 alpha,也不受陣亡封鎖。(A)**

證據:`prototypes/lead-programmer-campfire-source-probe-2026-11-23/probe.gd`(`run_output.txt` 同資料夾,引擎 exit 0)。
它只呼叫專案自己的 `CampaignAffinityLedger.append()`、`CampaignAffinityPoolRebuilder.rebuild()`、
`AffinityDataPool.narrative_depth_read()` / `combat_strength_read()`,沒有重寫任何規則。原始輸出:

```
PROBE src=SUPPORT_CONVERSATION m=3.0 narrative_depth=3.0 combat_strength=3.0 n_pair=1 rej=0
PROBE src=SUPPORT_CONVERSATION m=-3.0 narrative_depth=-3.0 combat_strength=-3.0 n_pair=1 rej=0
PROBE src=STORY_EVENT m=3.0 narrative_depth=3.0 combat_strength=3.0 n_pair=1 rej=0
PROBE src=COMBAT_CARD m=3.0 narrative_depth=0.825 combat_strength=3.0 n_pair=1 rej=0
PROBE fresh pool t_death(C1_C2)=<null>
```

- `COMBAT_CARD` 的「敘事深度」被折成 0.825(約 0.275 倍),所以**不能用**,與前次結論一致。
- 「陣亡封鎖」只在**同一個池**內有效;每場戰鬥開局都由 `rebuild()` 建全新池,新池沒有陣亡記號(上面最後一行)。
  所以前次留的疑問「跨場陣亡配對是否仍被封鎖」的答案是**否**:重播進新池時不會被擋。(A)
- 比較 `SUPPORT_CONVERSATION` 與 `STORY_EVENT`:今天讀出值完全相同。**沒有更合適的既有值,也不需要新增。**
  若日後結局要「依來源分開計分」,才需要在 enum 尾端追加 `CAMPFIRE`(動好感池檔案、序列化名稱,約 0.5 估計天,未驗證)。今天沒有任何讀取點需要區分。(B)

**新發現(影響題 2 與營火內部順序):記錄的附加順序會微幅影響結果,因為較舊的記錄會衰減。** (A)

```
PROBE order=[2.0, 3.0] narrative_depth=4.88
PROBE order=[3.0, 2.0] narrative_depth=4.82
PROBE order=[3.0, -1.0] narrative_depth=1.82
PROBE order=[-1.0, 3.0] narrative_depth=2.06
```

同樣兩筆、順序對調,結果差 0.06~0.24。不是 bug,但營火「寫入的先後」要有確定規則(例如依玩家操作順序),測試不要假設順序無關。

---

## 題 2:裁決第 2 題順序「勝利 > 營火 > 對話 > 編牌組 > 下一場」

**結論:對話「挑哪一段」在勝利當下就已綁死,而且與好感度數值完全無關,所以營火改變好感度不會讓挑段用到舊值。
但另有一個副作用:對話造成的好感度變化在勝利當下就已寫進累積記錄,比玩家看到對話早。(B,未實跑)**

證據(讀碼):
- 挑段只看兩件事:資料表欄位 `trigger_after_mission == 剛打完的場次`,以及兩位參與者勝利當下是否存活
  (`support_conversation_transition.gd` 的 `trigger_for_mission_transition`;`battle_screen.gd:6254` 的 `_trigger_support_conversations_for_finished_mission`,
  存活判斷用勝利當下的 `_state`)。**完全不讀好感度池。**
- 在 `_on_battle_ended` 勝利分支(約 6110~6123 行),順序是:挑對話並寫累積記錄 → `advance_on_victory`。
  被選中(COMPLETED)的對話 id 存進 `_completed_support_conversation_ids`,結果顯示結束後才播(6205~6208 行)。
- 對話畫面本身(`support_conversation_screen.gd`)沒有讀好感池或累積記錄的程式碼(`grep -n "AffinityDataPool\|ledger\|CampaignProgress"` 無命中)。
- 對話的好感度變化量由資料表的「正向/負向/中性」決定固定值(`SupportConversationRules.trigger`,中性不寫)。與營火寫入無關。

**白話後果:**
- 順序「勝利 → 營火 → 對話」要成立,營火畫面必須插在「結果顯示」和「對話畫面」之間。
  現行 `_on_result_display_finished`(6184 行)是直接「有對話就進對話,沒有就進下一場」,要在這裡多一個營火分流,再由營火畫面交給對話畫面。(B)
- 管理者的原意是「對話造成好感度變化之後,我才知道怎麼調整牌組」。但現在對話的好感度變化是**勝利當下就寫了**。
  所以營火畫面看到的好感度,**已經包含**玩家還沒看到的那段對話造成的變化(等於先劇透)。
  營火產出的卡牌也是依這個已含對話變化的數值產的。
  - 若可接受:不用改任何現有程式。
  - 若不可接受:要把對話的好感度寫入從「勝利當下」延後到「對話播畢」,
    得把勝利當下的存活名單帶到對話畫面,改 `battle_screen.gd` 與 `support_conversation_screen.gd`,
    並處理「播到一半關掉」時寫不寫的問題。估 0.5~1 估計天(未驗證)。**這需要管理者選。**
- 無論哪種,編牌組放在對話之後在技術上沒有阻礙:牌組不屬於累積記錄。

---

## 題 3:裁決第 1 題「打輸後可直接重打,也可回營火調整再打」

**結論:直接重打現成;回營火要新增「營火基準點」,動 4 個既有檔案,估 +0.5~1 估計天(未驗證)。(B)**

現況(讀碼):
- 累積記錄只有**一個**基準點 `_mission_start_count`,每次進場 `enter_battle` → `start_mission_affinity_ledger()` → `begin_mission()` 重設
  (`campaign_progress.gd:81`、`campaign_affinity_ledger.gd:88`)。
- 戰敗:`rollback_on_defeat()` 截回基準點,並設 `_retry_same_mission = true`(`battle_screen.gd:6140~6143`);
  結果顯示後 `_on_result_display_finished` 的 `if _retry_same_mission:` 進 `enter_battle`(6199~6201)。**目前是自動、沒有玩家選擇。**
- 場次編號在勝利當下已前進,所以戰敗的是「新場次」,營火是在它之前舉行的。

兩條路各自回滾到哪裡(營火寫入在 `enter_battle` 之前發生):

| 路線 | 累積記錄回到 | 營火結果 | 牌組 |
|---|---|---|---|
| **直接重打** | 該場開打前(基準點 = 營火寫入之後) | 保留 | 保留 |
| **回營火** | 營火開始前(營火基準點;含對話寫入,因為對話在營火前已寫) | 作廢,可重選 | **規格未定**,見下 |

要動的檔案與函式(估計):
1. `campaign_affinity_ledger.gd`:新增 `mark_campfire_start()`、`rollback_to_campfire_start()`,`clear()` 要一併歸零新基準點。
   既有契約的陷阱:基準點「忘了標就過度回滾」,檔頭已警告;新基準點同樣要有結構性防線。
2. `campaign_progress.gd`:新增對應包裝;`rollback_on_defeat()` 語意不改,另加 `rollback_to_campfire_on_defeat()`。
3. `battle_screen.gd`:`_retry_same_mission` 改成三態(不重打 / 直接重打 / 回營火),
   戰敗結果後要讓玩家選(目前是計時自動),動 `_on_battle_ended`(6139~6143)與 `_on_result_display_finished`(6199)。
   順帶要新增結果畫面的按鈕與文案(UI 另計)。
4. `scene_router.gd`:新增進營火畫面的入口(營火畫面本身屬 story-006 範圍)。
5. 測試:基準點重設時機是本機制已知陷阱,要補敏感度測試。

**需先決定(白話):**
- 回營火後,牌組要不要回到「營火之前」的樣子?牌組有兩段變動(營火產卡、編牌組)。
  若不回滾,玩家可在營火反覆刷出更好的牌;若回滾,牌組需自己的快照(約 +0.5 估計天)。
- 營火「每輪 3 次、同組不重複」的使用紀錄也要一併歸零,否則回營火時次數已被扣掉。
- 第 1 場戰敗前沒有營火,「回營火」按鈕應隱藏(不是壞掉)。
- 教學場戰敗不涉及營火(教學場不碰戰役記錄),沿用現狀。

---

## 題 4:標題「繼續」「新遊戲」

**結論:現在關掉遊戲再開,戰役進度與好感度記錄都不會保留;只有音量與兩個顯示設定會存。
「繼續」關掉遊戲後可行的做法有 3 種,各有代價。(B)**

### 現在會存什麼、不會存什麼(讀碼:全專案只有一個 `user://` 檔案)

| 項目 | 關掉遊戲後 |
|---|---|
| 音量、靜音、EGM 開關、好感度顯示開關 | **會存**(`user://settings.cfg`,`settings_file_store.gd`) |
| 目前第幾場 | **不會**,重開回到第 1 場(`campaign_progress.gd` 檔頭已寫明) |
| 好感度累積記錄(含對話與營火寫入) | **不會**,重開是空的 |
| 場次內的牌組 | 不會(11-13 裁決不進存檔,且尚未實作) |
| 教學進度 | 不會 |

專案的存檔系統(ADR-0004 原子寫入)仍是 `Proposed`,一年計畫明列不在範圍內。`SettingsFileStore` 的檔頭說它是全專案「唯一碰 `user://`」的程式,
任何新存檔檔案都要新增一個同形狀的薄殼並登記。

### 白話:按「繼續」關掉遊戲後可以怎麼做

**做法 A:「繼續」只在同一次開著遊戲時有用**
- 剛開遊戲時「繼續」是灰的(或不顯示);玩到一半回標題,才亮起,按了回到目前場次並保留好感度與牌組。
- 「新遊戲」:清掉戰役進度、好感度記錄、牌組,從頭來。
- 代價:最小。只加兩個按鈕和一個「有沒有進度」的判斷;順便修掉現在「按『開始』會接續舊進度」的怪行為。
  玩家關掉遊戲就全部重來,裁決檔已預告這點(「只在本次遊玩內有效」)。
- 估 0.5~1 估計天(未驗證)。

**做法 B:關掉遊戲後「繼續」從上次的場次接著打,好感度也還在,牌組重發預設 12 張**
- 要新增一個存檔檔案:存「第幾場」與好感度累積記錄(很小的幾筆資料)。
- 代價:要新寫存檔讀寫(不能借用 ADR-0004,它未核准),要處理壞檔、舊版檔;
  而且「好感度還在、牌組卻重發」會讓玩家覺得不一致,通常得讓玩家一繼續就進編牌組畫面。
  也等於部分推翻「牌組不進存檔」所預設的單次遊玩假設(你只是沒存牌組,不是推翻裁決)。
- 估 2~3 估計天(未驗證),另需新增測試與檔案毀損處理。

**做法 C:關掉遊戲後只記得「打到第幾場」,好感度重新開始**
- 最便宜的跨啟動版本:只存一個整數。
- 代價:好感度與營火、對話的累積全部歸零,第 N 場的角色關係與前面打的不連貫,劇情上是錯的。**不建議**,只是列出以便你知道它存在。
- 估 1~1.5 估計天(未驗證)。

**我的推薦:A。** 理由:符合你 11-20 的裁決(「繼續」只在本次遊玩內有效),成本最低,
也不碰未核准的存檔系統。若之後想要 B,A 的兩個按鈕與「有沒有進度」判斷都可以直接沿用,不會白做。
需要你決定:標題在「剛開遊戲、還沒有進度」時,「繼續」是**灰掉**還是**直接不顯示**。

---

## 一句話總表

| 題 | 結論 | 證據 |
|---|---|---|
| 1 | 用 `SUPPORT_CONVERSATION`:下一場讀到的就是寫入值,不乘 alpha、不受陣亡封鎖;不需新增來源值 | (A) |
| 2 | 對話挑段在勝利當下綁死且與好感度無關,不會用到舊值;但對話的好感度變化也在勝利當下就寫了,營火畫面會先看到(可接受則零改動,否則延後寫入約 0.5~1 估計天) | (B) |
| 3 | 直接重打現成;回營火要新增營火基準點,動累積記錄、戰役進度、戰鬥畫面、場景路由 4 個檔,約 +0.5~1 估計天;牌組回不回滾待決 | (B),估時未驗證 |
| 4 | 關掉遊戲只存音量等設定;「繼續」建議做法 A(只限本次開著遊戲),B/C 另有代價 | (B) |
