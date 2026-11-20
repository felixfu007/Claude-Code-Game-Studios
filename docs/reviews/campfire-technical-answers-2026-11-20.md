# 營火技術三題回答(lead-programmer,2026-11-20)

> 只讀程式碼,未跑引擎、未改 src/tests。「(未驗證)」= 只讀了程式、沒實跑。行號為今天實查,會漂,要現值請重新 grep。

## ① 營火寫入好感池:要不要新許可/來源值

**結論:不需要新許可;ADR-0002 契約涵蓋;營火走自己的入口、不經 `PermanentAffinityWriteRules` 是安全的。來源值:沿用既有值,不追加 `CAMPFIRE`。**

證據:
- 池的 `append_record(pair, m, source)` 只做 6 步驗證:寫入窗口、`m==0`、`m` 非有限、`source` 序數、`pair` 序數、陣亡配對+`COMBAT_CARD`(`affinity_data_pool.gd:554-575`)。**沒有任何「誰有資格寫」的許可層**。丙類卡的 `legal_pairs()` 是卡牌端自己的前置過濾(`permanent_affinity_write_rules.gd:142` 之前),不在池內。
- 支援對話寫入口(`support_conversation_ledger_write_port.gd:30-34`)明寫「不做任何驗證,ledger 只是記帳」,真正驗證在下一場開局重播時(`battle_screen.gd:2261-2268` → `_apply_opening_affinity_record` 2522-2532,被拒只 `push_error`)。營火照同一形狀即可,**與支援對話同一條路徑**,ADR 機制不變。
- `can_write()` 在 production 無呼叫端(grep `can_write` 於 src 的非註解命中為 0);營火不必碰它。
- **來源值有計分後果,不是中性的**:`narrative_depth_read` 對 `COMBAT_CARD` 乘 `alpha`、其餘 `1.0`(`affinity_data_pool.gd:812-813`);`COMBAT_CARD` 另被陣亡配對封鎖(575)。規格 v1.0 要「與丙類同等計分」——營火若用 `COMBAT_CARD` 反而會被 alpha 折算並受陣亡封鎖,**不能用**。`SUPPORT_CONVERSATION`(權重 1.0)或 `STORY_EVENT`(權重 1.0;開局種子在用,`battle_screen.gd:2237`)都可。
- 追加 `CAMPFIRE` 的代價:改好感池檔案(story-002 已標「超出範圍須先問」)、`Source.values()` 序數驗證與序列化名稱(ADR 機制八 `Source.keys()`)連動,且目前所有 1.0 權重分支(`!= COMBAT_CARD`)本來就會自動涵蓋——**今天沒有任何讀取點需要區分營火**。

推薦:營火寫 `Source.SUPPORT_CONVERSATION`?或 `STORY_EVENT`?——我推薦 **`SUPPORT_CONVERSATION`**:v1.0 4.3 說營火與支援對話同一份記錄、同等計分。⚠️ 這是推論:若結局系統日後要「分來源計分」,兩者語意都不精確,屆時才需要追加值(追加只能加在 enum 尾端,保序數)。
`design/quick-specs/card-campfire-rework-v1-2026-11-12.md` 的「不再有營火用標記」我只在 story-002 的轉述中看到,**未直接讀該規格原文(未驗證)**。

需管理者決定:**無**(不觸及 ADR-0002 契約,不需轉 `technical-director`)。唯一注意:陣亡配對——營火在勝利之後、戰敗即全隊失敗,故營火時五人皆存活(EPIC 推論;重播進的是**新池**,陣亡狀態本就不會帶過去,見 `affinity_data_pool.gd:575` 只在同一池內有效。**跨場陣亡配對是否仍該被封鎖,未驗證**)。

## ② 牌組放哪個執行期物件

**結論:做成一般可 `new()` 的 `RefCounted` 類別(暫名 `CampaignDeck`,放 `src/gameplay/campaign/`),由 `CampaignProgress` 掛成第二份靜態資料,比照 `_affinity_ledger` 的先例;戰敗重打可保留;依先例判讀不算第三個靜態持有者,但這是「依先例的解釋」,建議請管理者一句話確認。**

證據:
- `CampaignProgress._affinity_ledger` 就是這個形狀:`static var`,終生單一實例,`reset_campaign()` 呼叫它的 `clear()`(`campaign_progress.gd:67, 122-124`);檔頭明寫「持有者選『甲』:既有戰役層靜態持有者多帶一份資料,不是第三個」(25-30)。
- 規則出處 `.claude/rules/gameplay-code.md:37`:「再要第三個,請重新裁決,不要援引本條」——例外名單是**持有者(`GameSettings`/`CampaignProgress`)**。牌組掛進 `CampaignProgress` = 同一個持有者多帶資料,字面上沒新增持有者;**但那句「不要援引本條」也意味著 2026-10-19 那次的解讀是否能再用一次,不是我能裁決的**。
- 戰敗重打:`rollback_on_defeat()` 只動 `_affinity_ledger`(`campaign_progress.gd:106-107`);牌組物件不被碰到,**重打自然保留**。重打經 `enter_battle()`(`battle_screen.gd:6197-6200`)不重置 `CampaignProgress`。若管理者要「戰敗回滾牌組」,需新增牌組自己的基準點/快照(約 0.5 估計天,未驗證)。
- 替代案:牌組放 `CampaignAffinityLedger` 內——不建議,那類別語意是「好感度記錄」,混放會讓 `clear()`/`begin_mission()` 語意模糊。替代案二:牌組為場景持有、經 `SceneRouter` 注入——**做不到跨場**(營火畫面與戰鬥畫面是不同場景,`change_scene` 無資料注入時機窗,見 rules 檔第 2 點)。
- 🔴 **一個與 story-004 AC4 相關的發現**:`reset_campaign()` 的 production 呼叫端**只有一處**——打贏最後一場(`battle_screen.gd:6136`)。標題畫面「開始」直接 `enter_battle()`(`title_screen.gd:173`),**我沒讀到任何重置**;中途放棄只 `rollback_on_defeat`(`battle_screen.gd:6243-6244`)。字面推論:現在「回標題再開始」會**接續當前場次與累積記錄**,而 v1.0 4.6 把「一輪」定義為「新遊戲起至回標題或關閉止」。**兩者不一致(未實跑驗證)**,story-004 AC4 實作者要新增「標題開始 → 重置」的接線,並可能改變現有戰役接續行為。

需管理者決定(白話):
1. 牌組可以像「戰役進度」一樣,放在同一個全域保管處裡嗎?(我的推薦:可以,理由同上次累積記錄;若不放心,唯一替代是改動場景切換架構,成本高。)
2. 「回到標題再按開始」要重新開始整個戰役嗎?現在看起來是接續。這會影響好感度累積記錄與牌組,屬玩法裁決。

## ③ `start_mission_affinity_ledger()` 是否呼叫 `begin_mission()`:打輸時營火寫入會不會被回滾

**結論:是,逐行確認呼叫(`campaign_progress.gd:81-83`);營火寫入在下一場開局前發生,打輸重打時不會被回滾——「甲:直接重打」是現行機制自然結果。**

逐行鏈:
- `scene_router.gd:91` `_inject_campaign_ledger` → `start_mission_affinity_ledger()` → `_affinity_ledger.begin_mission()` → `_mission_start_count = _entries.size()`(`campaign_affinity_ledger.gd:88-89`)。
- `enter_battle()` 是唯一入口,勝利後下一場(`battle_screen.gd:6204-6206`)與戰敗重打(6197-6200)都走它;每次進場重設基準點。
- 營火寫入(`ledger.append`)發生在 victory → `advance_on_victory` → 營火 → `enter_battle` 之間,故落在**下一場的基準點之前**。戰敗 `rollback_on_defeat()` → `rollback_current_mission()` 只截回基準點(105-107),營火筆數保留。重打時 `begin_mission` 以截斷後筆數重設基準,營火仍在。
- 第 1 場的開局種子是例外的反面:`current_mission()==1` 時種子寫在 begin 之後,打輸被丟棄、重打重寫(`battle_screen.gd:2195-2237`)。營火在第 1 場**之後**才有,不受影響;若日後要有「第 1 場之前的營火」,其寫入會被視為第 1 場內容?——**否**,若在 `enter_battle` 之前寫入就在基準前(未驗證,無此需求)。

選項「乙:回到上一次營火」的實作成本:
- **現有機制做不到**:ledger 只有**一個**基準點,且 `enter_battle` 每次進場強制重設。要讓營火寫入可回滾,需在 ledger 新增「營火基準點」(營火開始時記錄、戰敗時截回)或讓 `start_mission_affinity_ledger` 在重打時不重設——**改動 `campaign_affinity_ledger.gd`/`campaign_progress.gd` 既有契約,連帶改 `rollback_on_defeat()` 語意**,故估 0.5~1 估計天是合理下限(未驗證),且要補敏感度測試(基準點重設時機是本機制已知陷阱,見 ledger 檔頭 23-26)。另需決定:乙之下牌組是否回滾(②)。
- 「乙」之下玩家流程要回到營火畫面而不是戰鬥,還要改 `_retry_same_mission` 分流(6197-6200)——**屬 story-006**,未估。

需管理者決定:打輸後回哪(甲/乙)——技術上甲零額外成本、乙約多 0.5~1 天且動既有累積記錄機制(上述)。**推薦甲**,理由:成本最低、不碰已驗收機制;乙是玩法取捨,非技術阻礙。

## 一句話總表
① 不需新許可,沿用 `SUPPORT_CONVERSATION`;② 牌組做成 `RefCounted` 掛 `CampaignProgress`,戰敗自然保留,需管理者一句話確認「不算第三個持有者」;③ 是,`begin_mission()` 有呼叫,營火寫入打輸不回滾(甲現成,乙另加成本)。
