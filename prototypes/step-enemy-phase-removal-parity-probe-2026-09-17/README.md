# 探針:`step_enemy_phase()` vs `run_enemy_phase()` —— 快照未走訪區段被移除的時間窗

## 假設 / 要回答的問題

覆核 U-018(`story-018-enemy-phase-stepped-playback.md`)時,判定「兩條路徑共用同一份規則」
成立,依據是逐行手動推演 —— 但推演本身沒有另外拿引擎跑一次。協調者指出這正好落在
`step_enemy_phase()` 快照**跨呼叫存活**、`run_enemy_phase()` 快照**單次呼叫內用完就丟**
這個結構差異最可能真的分岔的地方:

> 當某個敵方單位在「舊快照已建立、但該單位尚未被走訪」的時間窗內被移出回合序時,
> `run_enemy_phase()` 與 `step_enemy_phase()` 的最終盤面與 log 是否仍然逐項一致?

## 怎麼跑

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path . -s prototypes/step-enemy-phase-removal-parity-probe-2026-09-17/probe_removal_parity.gd
```

⚠️ 引擎路徑是這台開發機的,不是專案常數。檢查**引擎自己的 exit code**(本探針最後一行
`quit(0 if ok else 1)`),不要只看管線有沒有輸出——本機 `godot` 不在 PATH,呼叫錯誤時
會在約一秒內無聲回傳空結果,與「全過」無法區分。

## 做了什麼(零規則重新實作)

直接呼叫專案自己的類別:`BattleController.run_enemy_phase()` / `.step_enemy_phase()` /
`.end_faction_phase()`、`TurnOrder.remove_unit()` / `.is_done()`、`BattleState.can_attack()` /
`.unit_by_id()` / `.position_of()`。本檔沒有重寫這些方法的任何一行邏輯。

**Part 0**:先直接呼叫 `BattleState.can_attack(2, 3)`(兩個都是 ENEMY),確認「敵人殺敵人」
這條路徑在目前規則下是否可達——這是唯一會呼叫 `TurnOrder.remove_unit()` 的正式程式碼路徑
(`battle_controller.gd:1017`,在 `_process_enemy_unit()` 裡,前提是 `_state.can_attack()`
回傳 true)。

**Part 1**:Part 0 證實同陣營攻擊被 `can_attack()` 擋下之後,改用側效應注入的 `decide`
callable——處理 E2(id=3)時,直接呼叫真正的 `TurnOrder.remove_unit(4)`(E3 的 id)。
兩條完全獨立的 `BattleState`/`TurnOrder`/`BattleController` 各跑一遍同一個情境:一份走
`run_enemy_phase()`,一份走 `step_enemy_phase()` 反覆呼叫直到不再是 `ENEMY_ACTING`,
逐項比對 log、`phase()`、`round_number()`、`TurnOrder.is_done()`、`BattleState` 的
HP/座標。

## 現況

**已結案(單次執行,單一情境)。**

## 實測發現

1. **Part 0 確認自然觸發路徑不可達**:`BattleState.can_attack(2, 3)`(同陣營)回傳
   `false`——目前規則下,敵方階段裡一個敵人無法透過正式攻擊解算殺死另一個敵人,
   `TurnOrder.remove_unit()` 在 `_process_enemy_unit()` 裡完全不會因為「敵人互殺」被觸發。
   `move_unit()`(`battle_state.gd:198-205`)也沒有任何傷害副作用,`take_damage()` 全專案
   只有 `resolve_attack()` 一處呼叫。**這個時間窗,今天無法透過遊戲的正常規則(玩家操作 /
   `_decide`/`GreedyTacticalAI` 的合法回傳值)自然產生。**
2. **Part 1(合成觸發後)兩條路徑逐項一致**:
   ```
   batch_log   = ["R1 ENEMY: E1 ends turn without acting", "R1 ENEMY: E2 ends turn without acting"]
   stepped_log = ["R1 ENEMY: E1 ends turn without acting", "R1 ENEMY: E2 ends turn without acting"]
   logs_equal? true
   batch  : phase=0 round=2      stepped: phase=0 round=2      phase_equal? true   round_equal? true
   id=2  batch.is_done=false  stepped.is_done=false  equal=true
   id=3  batch.is_done=false  stepped.is_done=false  equal=true
   id=4  batch.is_done=true   stepped.is_done=true   equal=true
   id=1..4  hp_equal=true  pos_equal=true(全部)
   RESULT: PASS
   ```
   逐次呼叫紀錄(`stepped` 路徑,`call #2` 就是側效應觸發移除 E3 的那次呼叫,`call #3`
   顯示下一次呼叫時 `_next_enemy_step_id()` 內部的 `is_done()` 防衛分支被真正走到、
   跳過了已被移除的 id=4,回傳 `-1`,直接收尾):
   ```
   call #1: log=["R1 ENEMY: E1 ends turn without acting"] has_next=true phase=1
   call #2: log=["R1 ENEMY: E2 ends turn without acting"] has_next=true phase=1
   call #3: log=[] has_next=false phase=0
   ```
   **這個結果本身也順帶推翻了 `battle_controller.gd` 裡 `_next_enemy_step_id()` 文件註解
   對這個防衛分支的描述("NOT covered by any test... 目前不可達")——它在這支探針裡確實
   被走到了。差別在觸發手法:正式攻擊解算走不到(Part 0 已確認),但只要
   `TurnOrder.remove_unit()` 被呼叫(不論觸發方式),這個分支就會被使用,而且行為正確
   (兩條路徑一致地跳過了失效的 id)。**

## 誠實揭露的限制

- **側效應注入不是真實死亡。** 只有 `TurnOrder` 的簿記被動了手腳(`remove_unit()`),
  `BattleState` 裡 E3 的 HP/座標全程沒變——因為 Part 0 已確認正式攻擊解算走不到這條路徑,
  要製造這個時間窗只能繞開戰鬥解算、直接呼叫 `TurnOrder` 的真實 API。這驗證的是
  **`TurnOrder` 快照/游標機制本身**在「某個 id 中途失效」時是否等價,不是驗證一次完整的
  死亡流程(HP 歸零 → occupancy 清除 → `remove_unit()`)三者同步發生時是否等價。
- **只測了一種名冊、一種觸發時機**(移除發生在快照的最後一個位置,且只隔一次呼叫)。
  沒有測試「移除發生在快照中段、後面還有多個未走訪 id」或「同一次呼叫裡連續移除兩個」
  這類變體。
- **沒有測試 `run_enemy_phase()` 内部這個等價情境**——因為它是單次同步呼叫,理論上無法
  被外部「跨呼叫」介入,這點沒有另外驗證(只推演過,原因是 GDScript 單執行緒、
  `run_enemy_phase()` 呼叫期間沒有任何讓出點,外部程式碼不可能在它執行到一半時插入呼叫;
  這個推演本身沒有另外拿引擎驗證,因為據我所知目前沒有可行的驗證手法能在不修改
  `battle_controller.gd` 本體的前提下做到)。
