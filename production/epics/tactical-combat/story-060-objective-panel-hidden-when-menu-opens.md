# Story 060:開戰鬥選單時隱藏開場目標框(目標框不得蓋住選單「回到遊戲」列)

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-17)—— 缺陷由 godot-specialist 探針實測證實;修法選擇見下方,推薦 A,待管理者/協調者核可。
> **Type**: UI(行為)+ Logic(可見性狀態)
> **Estimate**: S(約 0.5 天:修法 0.1、整合測試 0.15、常駐敏感度證明 0.15、開窗兩尺寸實拍 0.1;全套跑一次約 95 秒)
> **依據**:
> - 探針:`prototypes/godot-specialist-objective-range-probe-2026-11-17/run_output_headless.txt`(同目錄 README)。結論:開選單時整棵樹暫停,`ObjectiveTimer`(8 秒,`OBJECTIVE_AUTO_HIDE_SECONDS`)隨之停走,目標框一直蓋在選單「回到遊戲」列上。
> - 截圖:`prototypes/lunch-capture-2026-11-17/out/00_960x540_s046_menu_five_rows.png`、`09_1920x1080_...`(同目錄)。
> - ⚠️ 上述 log 與截圖為協調者轉述,**本單撰寫者未逐行讀過**;實作者第一步先 `grep -n "paused\|ObjectiveTimer" prototypes/godot-specialist-objective-range-probe-2026-11-17/run_output_headless.txt` 親眼確認再動工,不符就停下回報。

## 缺陷

開場自動顯示目標框(`show_objective()`,`battle_screen.gd`)並啟動一次性 8 秒 Timer。玩家在 8 秒內開戰鬥選單 → 選單開啟時 `get_tree().paused = true`(`grep -n "paused" src/ui/battle/battle_screen.gd` 的註解處有描述)→ Timer 不走 → 目標框(在 `UILayer`,位於選單之上或與之相疊)持續遮住選單底部「回到遊戲」列,直到玩家按確認鍵/點擊(`_input` 的 story-046 AC1 關閉路徑)。選單「目標」列本身就是用來重看目標的,開場自動顯示與之重複。

## 現況(讀碼所得,實作者動工前當場再查)

- 選單「目標」列路徑:`battle_menu.gd` `_on_objective_row_pressed()` 先 `close()` **再** `objective_requested.emit()`(`grep -n "func _on_objective_row_pressed" -A3 src/ui/menu/battle_menu.gd`)。所以經此路徑呼叫 `show_objective()` 時選單**已先關閉**(探針提醒的前提成立,但 AC2 須用測試證明,不靠讀碼)。
- 已有連線:`_battle_menu.visibility_changed.connect(_refresh_controls_hint.bind(true))`(`grep -n "visibility_changed" src/ui/battle/battle_screen.gd`)。
- `show_objective()` 內 Timer 為 lazy 建立,`hide_objective()` 只設 `_objective_panel.visible = false`,**不停 Timer**。
- 戰鬥結束路徑已呼叫 `hide_objective()`(`grep -n "hide_objective()" src/ui/battle/battle_screen.gd`)。

## 修法比較

| | A. 選單開啟時 `hide_objective()` | B. `ObjectiveTimer.process_mode = PROCESS_MODE_ALWAYS` |
|---|---|---|
| 做法 | 新增 `_on_battle_menu_visibility_for_objective()`,只在 `_battle_menu.visible == true` 時 `hide_objective()`;`hide_objective()` 同時 `timer.stop()` | Timer 不受暫停影響,照常 8 秒 |
| 開選單的那一刻 | 目標框立即消失,「回到遊戲」列可見 | 目標框仍蓋住選單,**最長 8 秒**,缺陷只是縮短不是消除 |
| 「目標」列重看 | 選單先關 → `show_objective()` 正常顯示、重啟 8 秒 | 同 |
| 風險 | 玩家在讀目標時開選單就看不到目標(選單有「目標」列可重看,代價小) | 面板與選單同時可見,版面疊字風險仍在 |
| 複雜度 | 一條連線 + 一個小函式 | 一行,但不解決問題 |

**推薦 A**。理由:B 只把「永遠蓋住」縮成「蓋 8 秒」,選單開啟期間疊兩個面板這件事本身就是缺陷;A 直接消除。**不另加「進敵方回合時 `hide_objective()`」**:結束我方回合只能經選單(`end_faction_phase_confirmed`),選單開啟時目標框已被 A 隱藏,敵方回合不會有目標框 —— AC4 以測試證明這點,不另加程式碼(若測試證明不成立再回報,不自行加)。

## Acceptance Criteria

- [ ] **AC1 開選單即隱藏(核心)**:真實 `BattleScreen` 場景(`load()` 真實 `.tscn`,第 5 點規則;順序 `instantiate()` → 設路徑 override → `call_deferred("add_child")` → 等 2 個 `process_frame`;**先 `set_script()` 再設任何屬性**,見 test-standards 陷阱一)。開場後 `is_objective_visible() == true` → 開戰鬥選單(走真實開啟入口,不直接設 `visible`)→ 斷言 `is_objective_visible() == false`,且斷言當下 `get_tree().paused == true`(證明斷言發生在暫停狀態,即缺陷發生的條件)。
- [ ] **AC2 「目標」列重看正常**:承 AC1,選單開著時觸發「目標」列(走真實按鈕/真實 `_on_objective_row_pressed` 路徑)→ 選單已關(`not menu.visible`)、`is_objective_visible() == true`、**之後等待一個短於 8 秒的步進後仍可見**(證明沒被「選單關閉」的可見性回呼立刻關掉;時間用 `OBJECTIVE_AUTO_HIDE_SECONDS` 常數衍生,不寫死數字)。
- [ ] **AC3 Timer 不殘留**:AC1 後 `ObjectiveTimer` 已停(`is_stopped()`);AC2 重看後 Timer 重啟且 `time_left` 約為 `OBJECTIVE_AUTO_HIDE_SECONDS`。防止舊 Timer 在重看後提早關面板。
- [ ] **AC4 敵方回合無目標框**:開場 → 開選單 → 結束我方回合(走真實入口)→ 敵方回合進行中 `is_objective_visible() == false`。若此條不成立,**停下回報**,不自行加 `hide_objective()`。
- [ ] **AC5 其餘路徑不退**:確認鍵/點擊關閉(story-046 AC1)與自動 8 秒隱藏的既有測試不改、不刪斷言;選單關閉(未按「目標」列)後目標框**不會自己重新出現**。
- [ ] **AC6 常駐敏感度證明**(🔴 一個 mutant 一次獨立執行;`test_sensitivity_proof_*` 形式,常駐 mutant 子類別 + `set_script()`):①移除選單開啟時的隱藏 → AC1 紅 ②隱藏條件寫成「選單可見性任何變化」(關閉時也隱藏)→ AC2 紅 ③`hide_objective()` 不停 Timer → AC3 紅 ④Timer 改 `PROCESS_MODE_ALWAYS` 而無隱藏(即修法 B)→ AC1 紅(證明 B 不達標)。不可證者逐條寫理由。交付前掃殘留注入標記。
- [ ] **AC7 開窗實拍(只能開窗)**:真實 `BattleScreen`,960×540 與 1920×1080 各一張「開場 8 秒內開選單」截圖,存 `production/qa/evidence/`,可見「回到遊戲」列無遮蔽。截圖類別先判(`coding-standards.md` 分類);Check 4 世界層為「沒有可測對象(N/A)」,須寫 N/A 不得寫「通過」。原始 log 留宿主鏈量測值。
- [ ] **AC8 Check 5 人眼確認**:管理者本人開圖確認;紀錄寫明受測者只有管理者本人。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 目標框的版面、文字、字級、教學場附加行(046 範圍)。
- 選單「回到遊戲」列本身的版面/焦點。
- 其他疊層(圖例、橫幅)與暫停的互動。

## Affected Files

- `src/ui/battle/battle_screen.gd`(新增可見性回呼與連線;`hide_objective()` 加停 Timer)
- 新測試檔:`tests/integration/ui/battle/battle_screen_objective_menu_test.gd`
- `prototypes/story-060-objective-menu-evidence-<日期>/`(開窗驅動 + log + 截圖,不進 `src/`)

超出此清單先問。

## 與其他工單的順序

- **與 story-059 不同檔、順序不限**:059 動 `legend_panel.gd` 與 `board_view.gd`(圖例版面、範例外框)及其測試,**不動 `battle_screen.gd` 與 `battle_menu.gd`**;060 只動 `battle_screen.gd`。唯一交集是兩者的開窗實拍都用真實 `BattleScreen`,各自驅動、互不依賴。
- ⚠️ `battle_screen.gd` 目前在工作樹有他人未提交修改(`git status` 顯示 `M src/ui/battle/battle_screen.gd`):動工前先確認該批已提交,避免同檔併改衝突。
- 本單自 story-059「不併入則另開 story-060」的預留號取走:059 已裁決併入鞋/劍示範,該預留不再使用,故 060 號給本單。
