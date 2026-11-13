# Story 056:戰役戰敗改為直接重打同一場(不回標題)

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-13)—— 🔴 「下一步」行用字須 game-designer 定稿(見 AC4 與待決題 1);其餘可動工
> **Type**: Logic + UI(結果分流、一行文字)
> **Estimate**: S(約 1 天:分流 + 旗標 0.25、文字與列數 0.1、既有測試改寫 0.25、新測試含無殘留 0.25、敏感度 0.15)
> **依據**:
> - 管理者 2026-11-13 裁決,逐字「**直接重打同一場,不回標題(遊戲設計師推薦)**」。紀錄:`active.md`(當場查 `grep -n "直接重打同一場" production/session-state/active.md`;未找到就是還沒寫入,以派工訊息為準,實作者回報時註明)。
> - 方案與事實:`docs/reviews/title-flow-after-defeat-options-2026-11-13.md` 方案 A、第一節。

## 現況(2026-11-13 讀自程式;實作者動工前須自行當場驗證,不採信本單)

- 戰役戰敗:`battle_screen.gd` 的 `_on_battle_ended` 在 `elif campaign_ledger_override != null:` 區塊的 `else:` 分支只呼叫 `CampaignProgress.rollback_on_defeat()`(只回滾累積記錄,場次編號不動)。`_proceed_to_next_mission` 維持預設 `false`。
- 結果計時器(`RESULT_DISPLAY_SECONDS`)到 → `_on_result_display_finished()`:先 `match _tutorial_next`(教學戰敗 = `TUTORIAL_BATTLE` → `SceneRouter.enter_tutorial_battle` 重打同一場),**戰役戰敗 `_tutorial_next == NONE`**,落到 `if not _proceed_to_next_mission: return_to_title_screen()` → 回標題。**這就是要改的那一行行為。**
- `SceneRouter.enter_battle(tree)`:`TutorialProgress.end()` 後 `switch_to(..., _inject_campaign_ledger)`;`_inject_campaign_ledger` 呼叫 `CampaignProgress.start_mission_affinity_ledger()`,後者**內部先 `begin_mission()` 再回傳**(結構防線)。故走 `enter_battle` 重打 = 以「第 `current_mission()` 場」重新開始,場次沒前進(戰敗不呼叫 `advance_on_victory`)。
- 結果文字:`result_detail_text()` 戰役戰敗取 `TEXT_NEXT_DEFEAT_CAMPAIGN`(`battle.result.next_defeat_campaign`,`strings.csv` 現值「稍後回到標題畫面」);教學戰敗取 `battle.result.next_defeat_tutorial`(現值「稍後自動重來這一場」)。
- 既有的「重打狀態乾淨」測試只覆蓋到路由層:`tests/integration/ui/shell/campaign_single_source_seeding_test.gd` 的 `test_mission_one_defeat_replay_starts_in_same_state_without_duplicates` **手動呼叫** `rollback_on_defeat()` 再 `enter_battle`,**沒有走 `_on_battle_ended` → `_on_result_display_finished` 這條真實路徑**。

## 規則

1. 戰役戰敗(`campaign_ledger_override != null` 且非教學、結局非勝利)→ 結果顯示結束後 `SceneRouter.enter_battle(get_tree())`,**不呼叫** `return_to_title_screen()`。與教學戰敗(`TUTORIAL_BATTLE`)語意對稱。
2. 實作形狀建議(實作者可提更小的,但須說明):在戰役戰敗分支(`rollback_on_defeat()` 同一處)設一個與 `_proceed_to_next_mission` 並列的旗標(例:`_retry_same_mission: bool`),`_on_result_display_finished()` 在 `_proceed_to_next_mission` 判斷之前處理它。**不得**因此把「戰役戰敗」併進 `_proceed_to_next_mission`(它的語意是「勝利且非最後一場、可能接支援對話」,併入會讓戰敗誤入 `go_to_support_conversation` 分支)。
3. **不改**:勝利路徑、戰役完成(歸零後回標題)路徑、無戰役(`campaign_ledger_override == null`)回標題路徑、教學路徑、`abandon_mission_to_title()`。
4. 🔴 **重打不得殘留本場牌組/好感度累積**:唯一允許的重開途徑是 `SceneRouter.enter_battle()`(經 `start_mission_affinity_ledger()` → `begin_mission()`)。**不得**為重打另寫「就地重置」或自行持有 ledger 參照。

## Acceptance Criteria

- [ ] **AC1 戰役戰敗重打同一場**:對真實 `BattleScreen`(載入真實場景檔、注入合成夾具,比照 `support_conversation_transition_flow_test.gd` 的 `_enter_fixture_battle` + `_ROSTER_DOOMED_PATH`,**set_script 在賦值 override 之前**,見 `coding-standards.md` 陷阱一):打到 DEFEAT → `_on_result_display_finished()` → 等換場 → `get_tree().current_scene` 是 `BattleScreen`(不是 `TitleScreen`),且 `CampaignProgress.current_mission()` 與戰敗前相同。防空洞:同一測試先斷言換場前 `current_scene` 是舊的那個實例、換場後是**不同實例**。
- [ ] **AC2 🔴 無殘留(核心 AC,必須有測試鎖住)**:戰敗前先讓本場累積東西 —— 至少:①往 `CampaignProgress` 取得的 ledger `append` 一筆本場好感度記錄;②讓本場牌組狀態有可觀察的變化(實作者當場查本場牌組的真實持有者與可讀取的快照方式,**不得憑本單猜**;查不到可觀察的牌組狀態 → 停下回報,不得只測好感度就宣稱牌組也無殘留)。走真實路徑 `_on_battle_ended(DEFEAT)` → `_on_result_display_finished()` → 新 `BattleScreen`,斷言新場的 ledger `records()` 數、好感度池快照(沿用 `campaign_single_source_seeding_test.gd` 的 `_pool_snapshot`)、牌組快照,與「第一次進入該場時」**逐項相等**,且**無重複記錄**(`records().size()` 不增加)。防空洞:斷言前先證明戰敗前累積確實存在(例如 `records().size()` 大於進場基準)。
- [ ] **AC3 其餘分流不變**:勝利且非最後一場仍接下一場/支援對話;戰役完成仍回標題;無戰役(未注入 ledger)戰敗仍回標題;教學戰敗仍 `enter_tutorial_battle`。以既有測試承擔(`support_conversation_transition_flow_test.gd` 的 AC1~AC4 其餘各條、`tutorial_sequence_test.gd`),**實作者須列出每條既有測試是否被本單動到**。
- [ ] **AC4 「下一步」行**:`battle.result.next_defeat_campaign` 改為與重打一致的字句。**用字須 game-designer 定稿**;`game-designer` 方案檔建議「稍後重打本場」(教學戰敗現用「稍後自動重來這一場」,可共用句型)。實作者**不自擬**;定稿前不改字串。新字串仍走 `strings.csv`(不新增列則 `locale_data_integrity_test.gd` 列數不變;若新增列須同步,當場 `grep -n "is_equal(" tests/unit/core/i18n/locale_data_integrity_test.gd` 取現值)。
- [ ] **AC5 既有測試改寫(逐條說明)**:
  1. `tests/integration/ui/battle_screen_objective_and_menu_test.gd::test_campaign_defeat_next_line_does_not_promise_restart_same_mission`:前提「標題進教學第 1 場,故不得承諾重打」**已不成立**(現在就是會重打)。**改寫**:改名為例如 `test_campaign_defeat_next_line_promises_retry_same_mission`;保留對 `Loc.localize(&"battle.result.next_defeat_campaign")` 的 `is_equal`;**拿掉** `contains("再次")` 為 false 的斷言(那條在防舊誤導,舊誤導已消失;若新字句恰好含「再次」它會誤紅);改為斷言行**非空**且**不等於** `battle.result.next_title`(防空洞:戰敗行不得退回「回標題」那句)。同檔註解「2026-11-13 實測:標題進教學第 1 場…」一併更新為指向本單。
  2. `tests/integration/ui/shell/support_conversation_transition_flow_test.gd::test_ac4_defeat_returns_to_title`(段標題「AC4:戰敗 / 戰役完成 -> 標題」):**斷言「戰敗後 `_scene_name() == "TitleScreen"`」與新行為正面衝突,必紅。改寫**:改名為 `test_ac4_defeat_retries_same_mission`,斷言換成「`current_scene is BattleScreen` 且不是 `TitleScreen`、`current_mission()` 不變」(可與 AC1 合併為同一條,避免兩條測同一件事,**合併須說明**)。段標題改為「戰役完成 -> 標題」。同檔 `test_ac4_campaign_complete_returns_to_title` 不動。
  3. 同檔 `_MutantAlwaysTitle`(「結果顯示後一律回標題(舊行為)」)僅用於勝利分流的敏感度證明,**不受影響**;實作者確認其使用處後在回報註明。
  4. `tests/integration/ui/shell/campaign_single_source_seeding_test.gd::test_mission_one_defeat_replay_starts_in_same_state_without_duplicates`:**不改**(手動呼叫路由層,仍有效);AC2 新測試是它缺的「真實路徑」那一半。
  5. 其餘有呼叫 `_on_result_display_finished()` 的測試(`tutorial_sequence_test.gd` 第 76 行附近)實作者 grep 後逐條確認不依賴戰役戰敗回標題。
- [ ] **AC6 敏感度證明**(🔴 一個 mutant 一次獨立執行,常駐 `test_sensitivity_proof_*` 形式):①戰役戰敗分支漏設旗標(回標題)→ AC1 紅 ②重打改成「不經 `enter_battle`、就地重用舊 ledger/牌組不重置」或略過 `rollback_on_defeat()` → AC2 紅(**這條最重要,證明 AC2 真的在測無殘留而非只測換場**)③旗標誤併入 `_proceed_to_next_mission`(戰敗誤入對話分流)→ AC1 或 AC3 紅。注入須在進樹前 `set_script()`(Case A)。交付前掃殘留注入標記。**證明不了的須逐條寫下理由**(`test-standards.md` 兩項義務),不得硬湊。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。
- [ ] AC7 像素層(ADVISORY):960×540 與 1920×1080 各拍戰敗結果畫面(下一步行新字句不被截斷);依截圖規則判類別(全窗遮罩屬 Category B,須用真實矩形函式取樣),人開圖確認。

## 已知限制 / 未涵蓋(刻意,不擴範圍)

- **戰敗後想離開**:`_handle_battle_menu_pressed()` 只擋「選單已開」,**沒看到對結果期間(`_result_mask.visible`)的明確閘門**(grep `_result_mask\.visible` 只命中 `_on_battle_ended` 設定那一行;`_input` 內有無結果期擋輸入**本單未查證**)。需實作者查證:①結果計時期間選單是否可開、`abandon_mission_to_title()`(離開確認的「回主選單」)是否可用 ②若可開,選單開啟時「樹暫停」(見該函式 `_set_hud_hidden` 註解)→ 結果計時 Timer 一併暫停,重打會被延到選單關閉後 ③若可用,離開會**再呼叫一次** `rollback_on_defeat()`(`_on_battle_ended` 已呼叫過一次)—— 是否冪等需查 `CampaignAffinityLedger.rollback_current_mission`。**查證結論寫進回報;不可用 → 列為已知限制(玩家要離開須在重打開始後從戰鬥選單離開);可用但有副作用 → 停下回報,不自行修。**
- 「開始戰鬥」改名「開始遊戲」(方案檔第 4 項純文字)—— 不在本單。
- 跨啟動不持久化(`CampaignProgress` 為 static var)—— 既有已知限制,不變。
- 重打次數上限、難度調整、戰敗後調整牌組的機會 —— 未經裁決,不做。

## Affected Files

- `src/ui/battle/battle_screen.gd`(戰役戰敗旗標、`_on_result_display_finished` 分流、必要時 `result_detail_text` 取旗標;**不改** `scene_router.gd`、`campaign_progress.gd` —— 它們現成可用)
- `assets/data/locales/strings.csv`(`battle.result.next_defeat_campaign` 一列用字;新增列才動列數測試)
- `tests/integration/ui/battle_screen_objective_and_menu_test.gd`(AC5-1)
- `tests/integration/ui/shell/support_conversation_transition_flow_test.gd`(AC5-2)
- 新測試檔:`tests/integration/ui/shell/campaign_defeat_retry_same_mission_test.gd`(AC1 若未與 AC5-2 合併、AC2、AC6)
- `tests/unit/core/i18n/locale_data_integrity_test.gd`(僅在新增列時)

超出此清單先問。

## 與其他工單的順序

同動 `battle_screen.gd` 與 `strings.csv`,且 `battle_screen_objective_and_menu_test.gd` 是 046 的測試檔。**046 AC2(選單入口)進行中 → 056 須排在 046 全部交付之後**(046 AC3 的 `result_detail_text` 與 `next_defeat_campaign` 測試就是本單要改的對象,同時動會互踩)。與 053/054/055/052 動不同區段但同檔,仍須序列;建議 046 → 056 → 053 之後依既有順序。

## 待決題

1. **用字**:`next_defeat_campaign` 定稿字句(建議「稍後重打本場」),由 game-designer 定。
2. **戰敗後離開路徑**:見「已知限制」查證項,結果決定是否需新工單。
3. **牌組無殘留的可觀測面**:AC2 要的「牌組快照」當前能否讀取,實作者動工前確認;不能 → 停下回報,不降級驗收。
