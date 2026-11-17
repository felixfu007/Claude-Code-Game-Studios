# 目標框 / 暫停 / 範圍格 探針 (2026-11-17)

狀態:已結論(headless;Godot 4.7.1;`ENGINE EXIT=0`)
執行:`godot --headless --path . -s res://prototypes/godot-specialist-objective-range-probe-2026-11-17/probe.gd`
原始 log:`run_output_headless.txt`(同目錄)。探針 `load()` 真實 `BattleScreen.tscn`,instantiate -> 注入 override -> call_deferred add_child -> 等幀(技術偏好第 5 點);
宿主鏈值已 log:`HOST WVC position=(0.0, 0.0) size=(960.0, 540.0) stretch_shrink=2 WorldViewport.size=(480, 270)`。
未動 `src/`、`tests/`、任何其他 md。

## 程式證據
- 目標框:`src/ui/battle/battle_screen.gd` 的 `show_objective()`(約 6033-6046)建子 `Timer`("ObjectiveTimer",one_shot,8 秒 = `OBJECTIVE_AUTO_HIDE_SECONDS` 約 199)。
  只有三條關閉路徑:Timer.timeout、`_input()`(約 2615-2617:`battle_confirm` 或滑鼠按下)、`_on_battle_ended` 內 `hide_objective()`(約 5686)。**沒有任何「進入敵方回合/換手」關閉。**
- 場景與 Timer 皆未設 `process_mode`(`src/ui` 內只有 battle_menu / cursor_state_host / music_player_host 設 ALWAYS)。BattleScreen 與 Timer 都是預設繼承 = 可暫停。
- 範圍格:`_refresh_view()` 約 5094 `if selected != -1:` 才畫 move/attack/threat/unreachable,else 分支(約 5221-5226)全清;
  `BattleController.end_faction_phase()`(`src/gameplay/battle/battle_controller.gd` 約 884-885)呼叫 `_clear_selection_internal()`。

## Q1 目標框在敵方回合/換手後仍顯示 —— 結論:驅動假象(僅限「未暫停」情境)
- 純計時:無輸入 8.5 秒真實時間後自動隱藏。
  `OBJ [Q1 8.5s real, no input] visible=false timer.time_left=0.00`
- 驅動做法:每個狀態都是全新實例,載入後約 0.2~0.3 秒就截圖,所以每張圖都是「開場 8 秒窗口內」。
  `Q1 sync enemy phase steps=10 phase_after=0 took_ms=183 (driver-style: zero real time)` 隨後
  `OBJ [Q1 right after enemy phase + back to player ...] visible=true timer.time_left=7.66`
  即:敵方整回合同步跑完只花 183 ms,Timer 只走了 0.2 秒,框當然還在。
- 真玩家情境:要在開場 8 秒內就按「結束回合」才會在敵方回合看到它;一般不會。**但見 Q2:開過選單會凍結計時,可延長到敵方回合之後。**
- 建議(可選):`_set_phase` 進入 ENEMY_ACTING 時順手 `hide_objective()`,語意最乾淨;非必要。

## Q2 選單開著時 Timer 是否暫停 —— 結論:遊戲真的會(真缺陷)
- `OBJ [Q2 menu opened] visible=true timer.time_left=7.73 timer.can_process=false tree.paused=true screen.process_mode=0 timer.process_mode=0`
- `OBJ [Q2 after 10.0s REAL wall time with menu open] visible=true timer.time_left=7.73 ...`
- `Q2 timer.time_left delta over 10s paused = 0.000 (0 = Timer frozen)`
- 關選單後恢復倒數:`OBJ [Q2 menu closed] ... timer.time_left=7.71 timer.can_process=true`,再 8.5 秒:`visible=false`。
- 所以:一開場就按 M -> 目標框在選單開著的全程都顯示(實測 10 秒不變,理論上無上限),選單關閉後才續跑剩餘約 7.7 秒。**不是「永遠蓋住」,而是「選單開著就不會消失」。**
- 加重:`BattleScreen` 本身 `process_mode=0`,paused 時 `_input()` 不會被呼叫(推論,同為可暫停節點,Timer 的 `can_process=false` 即同一規則;
  本探針未直接送輸入驗證),所以「確認鍵/點擊關閉」在選單開著時也無效,玩家無法用輸入收掉它。
- **未量測**:目標框(UILayer 內 ColorRect)是否實際遮住選單的「回到遊戲」列 —— 那是像素/繪製順序問題,headless 取不到,請看 00/09 號截圖(截圖本身已顯示在選單開啟時有框)。
- 建議修法:選單開啟時隱藏目標框(`_battle_menu.visibility_changed` 已接了 `_refresh_controls_hint`,同處加「若選單可見則 `hide_objective()`」),
  或 Timer 設 `process_mode = PROCESS_MODE_ALWAYS` 讓計時不受暫停影響(兩者擇一;前者同時解決遮擋)。注意選單的「目標」列經 `objective_requested` 呼叫 `show_objective()`,須確認此時選單已先關閉(未驗證)。

## Q3 敵方回合仍見綠/灰藍範圍格(07 號圖)—— 結論:不是範圍格,是地形(驅動/遊戲皆無缺陷)
- `Q3 fresh: selected=-1 layers: move=0 attack=0 threat=0 unreach=0 los=0`
- `Q3 after select, before end phase: selected=1 layers: move=48 attack=0 threat=12 unreach=47 los=0`
- `Q3 right after end_faction_phase (before any frame): selected=-1 phase=1 layers: move=0 attack=0 threat=0 unreach=0 los=0`
- `Q3 mid enemy phase step2: selected=-1 layers: move=0 ...`;回我方回合 `selected=-1 layers: move=0 ...`
- 07 號圖情境(全新實例 -> 立刻 end_faction_phase):`Q3 scenario-07 (fresh, end phase, 0.4s): selected=-1 phase=1 layers: move=0 attack=0 threat=0 unreach=0 los=0`
- 遊戲在 end_faction_phase 就清掉選取,範圍圖層全空。07 圖那個十字形(中央灰藍 2x2、四周綠)與 `assets/data/levels/vs01_terrain.txt` 第 2~5 列、第 4~7 欄的 `,`(綠)與 `##`(灰藍,倒木)完全吻合,
  每張圖位置相同是因為地形固定。它是棋盤地形,不是選取範圍。
