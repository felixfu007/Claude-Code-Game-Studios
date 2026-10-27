# CursorStateHost 測試隔離稽核(2026-10-27)

> 唯讀稽核,未修改既有檔。量測【只完成一部分】:見「量測」節。其餘為靜態閱讀。

## 給管理者的白話摘要

- 有沒有「測試結果會因執行順序而不同」的真實風險?**有殘留,但沒有量到結果翻轉。**
  共用的游標 Autoload 被 15 支以上的測試檔碰過;其中兩支戰鬥選單/游標測試有完整的存檔-還原,
  其餘大多只清「註冊表」,沒清「游標目標」。已實測:跑完 battle_screen_scene_test 後,
  註冊表是空的(乾淨),但游標目標仍停在 BOARD_TILE/26 且標為有效(全新狀態應為無效)。
- 嚴重度:低到中。目前只有在某個測試假設「游標一開始是無效的」時才會被順序影響;
  我只讀了部分測試,沒有全庫搜過這種假設(未查證)。歷史上確實發生過一次:
  註冊表殘留造成 "Trying to return a previously freed instance."(多支測試的 after_test 註解有記載),
  那一類已被各檔 after_test 修掉。
- 建議(不必現在修):做一個共用輔助(例如測試基底或一支 helper),統一存檔/還原
  目標、裝置權威、暫停旗標、事件緩衝、註冊表;各檔 after_test 改呼叫它。
  再補一條「全套跑完後 Autoload 必須回到初始狀態」的收尾測試。
- 好消息:GdUnit4 原始碼顯示 after_test 對每個測試都會執行,包含失敗者
  (GdUnitTestCaseSingleExecutionStage.gd:先 before、再 test、`_stage_after.execute` 無條件)。
  失敗只會讓同一 suite 剩下的測試不跑。這是靜態閱讀,未用失敗測試實測。

## 寫入型公開 API(cursor_state_host.gd)
set_target、register_surface、unregister_surface、suspend_arbitration、resume_arbitration、
_input(填 _frame_events)、_process(仲裁,改裝置權威)、flush_buffered_navigation、
_notification(FOCUS_IN/OUT);測試另直接寫私有欄位 _state/_registry/_frame_events/_arbitration_suspended,
並直接對 _state 寫 _target/_device_authority。
間接:BattleScreen._ready 註冊 BOARD_TILE 並 set_target 播種;tree_exited 只解除註冊,不還原目標
(battle_screen.gd 的 `tree_exited.connect(` 一帶與 `CursorStateHost.set_target(` 播種處)。
BattleMenu.open/close 呼叫 suspend/resume_arbitration。

## 逐檔判定表
圖例:✅ 已隔離 / ⚠️ 正常路徑有還原但失敗路徑沒有或不完整 / ❌ 會殘留 / 未查證

| 測試檔 | 改寫了什麼 | 還原方式 | 判定 | 依據 |
|---|---|---|---|---|
| integration/ui/battle_cursor_navigation_convergence_test.gd | 暫停旗標、緩衝、目標、裝置權威、BOARD_TILE、輸入動作 | before_test 存、after_test 還原(每測試必跑) | ✅ | 該檔 before_test/after_test(約 413-440 行) |
| integration/ui/menu/battle_menu_gating_test.gd | 暫停旗標、緩衝、目標、權威、BOARD_TILE、tree.paused | 同上,且先還原 paused | ✅ | 該檔 94-120 行 |
| integration/ui/menu/battle_menu_leave_confirmation_test.gd | 經 BattleMenu 開關 suspend/resume、tree.paused | after_test 強制 paused=false、suspended=false;不存檔目標/權威 | ✅(目標/權威是否被動未查證) | 137-147 行 |
| integration/cursor/focus_pause_gating_test.gd | 自建的 CursorStateHost 實例(`.new()`+`_ready()`),非 Autoload | 實例私有,不共用 | ✅(實例是否掛進樹、有無洩漏未查證) | 164-187 行 |
| unit/cursor/cursor_host_pause_exclusion_test.gd | Autoload 部分(約 112-165 行)是否改 tree.paused;另有自建實例(210 行) | 未讀還原段 | 未查證 | 僅讀 grep 命中行 |
| integration/cursor/frame_buffer_ordering_test.gd | 無(只有比對原始碼字串) | 不需要 | ✅ | 341-347 行 |
| unit/cursor/cursor_layer_transform_test.gd | 看似唯讀(host.get(&"_cursor_layer")) | 有 before_test/after_test,內容未讀 | 未查證 | 109-131 行 |
| integration/ui/attack_confirm_panel_test.gd | BattleScreen 掛樹 → 註冊 BOARD_TILE + 播種目標 | after_test 只 unregister BOARD_TILE | ❌ 目標殘留(註冊表 ✅) | 40-46 行;殘留現象見下「量測」 |
| integration/ui/battle/battle_screen_card_play_wiring_test.gd | 同上 | 同上 | ❌ 目標殘留 | 78-84 行 |
| integration/ui/card_confirm_panel_test.gd | 同上 | 同上 | ❌ 目標殘留 | 47-53 行 |
| integration/ui/card_target_selection_test.gd | 同上,另直接 `CursorStateHost.set_target`(1450、1553 行) | 同上 | ❌ 目標殘留 | 151-157 行 |
| unit/ui/direction_key_debounce_test.gd | 同上 | 同上 | ❌ 目標殘留 | 110-116 行 |
| unit/cursor/state_host_test.gd | 對 Autoload:reseed 訂閱 lambda 掛在共用 _state 上未斷開(438-455 行);register/set_target(target id 7)/unregister(732-775 行);換入 spy 取代 _state/_registry(857-862 行) | 全部是測試尾端內嵌還原(775、915-916 行),不在 after_test | ⚠️ 內嵌還原:測試函式若被執行期錯誤中斷就不跑;目標 id 7 殘留 | 該檔對應行 |
| integration/ui/shell/scene_router_test.gd | 經 SceneRouter 掛真實戰鬥場景;自行 register 探針節點 | 尾端內嵌 `_free_if_valid`/unregister(約 135-165 行);after_test 只重設 CampaignProgress | ⚠️ 前置斷言失敗時探針被 free 但仍註冊 | 135-165 行 |
| integration/ui/shell/title_screen_scene_switch_test.gd | 同上,多次 register 探針 | 同上 | ⚠️ 同上 | 140-230 行 |
| unit/ui/battle_screen_scene_test.gd(無 after_test) | BattleScreen 掛樹 | 靠 auto_free + tree_exited 解除註冊 | ❌ 目標殘留(已實測) | run_output.txt |
| 其餘約 20 支掛 BattleScreen/BattleMenu 但無 after_test 的檔(battle_screen_*、battle_input_gaps、forced_discard、battle_menu_end_turn_wiring 等) | 推測同上 | 靠 tree_exited | 未查證(逐檔) | 以 grep 得知它們 add_child 且無 after_test,未逐檔讀 |

## 量測(部分完成,等級:實測執行了專案真實 Autoload 與真實測試檔;探針本身不重寫任何規則)
- 探針:prototypes/cursor-host-isolation-probe-2026-10-27/zz_host_state_probe_test.gd;原始輸出:同目錄 run_output.txt;README 記載狀態。
- 基線(探針單跑):`surfaces=[] authority=UNINITIALIZED target=BOARD_TILE/0/valid=false suspended=false frame_events=0 tree_paused=false`
- 先跑 battle_screen_scene_test 再跑探針(兩次 EXIT=0,suite 順序依參數順序,已驗證):
  `surfaces=[] authority=UNINITIALIZED target=BOARD_TILE/26/valid=true suspended=false ...`
  → 註冊表乾淨、目標殘留且有效。`CursorState.is_current_target_valid()` 僅檢查 `_target.is_valid`(不查註冊表),所以殘留是真的。
- 未量:其他所有檔案(每組約 52 秒);未做「換順序導致測試結果翻轉」的證明。

## 未查證清單
1. 除上述一組外的所有檔案之殘留狀態(僅靜態閱讀)。
2. 全庫是否有測試斷言「Autoload 目標一開始是無效/null」(只讀了 state_host_test 的一部分)。
3. cursor_host_pause_exclusion_test 與 cursor_layer_transform_test 的還原段。
4. focus_pause_gating 自建實例是否掛樹、是否被釋放。
5. after_test 在失敗測試上會執行:僅讀 GdUnit4 原始碼,未用故意失敗的測試實測;逾時(interrupted)路徑亦未實測。
6. state_host_test 的未斷開訊號連線(438-455 行)對後續測試有無影響。
7. battle_menu_leave_confirmation 是否間接改動目標/權威。
8. 約 20 支無 after_test 的 BattleScreen 掛載檔是否都用 auto_free(只知道 add_child 次數)。

## CP log
- CP0 骨架;CP1 讀 API 與還原段;CP2 探針兩次執行;CP3(協調者指示停止新量測)寫完報告。
