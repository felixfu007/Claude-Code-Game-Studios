# 手牌焦點被滑鼠晃動搶走 —— 探針(2026-11-11)

狀態:已結論(成立)。

## 假說
`battle_screen.gd` `_input()` 對每個 `InputEventMouseMotion` 呼叫 `_hover_hand_card()`,無位移門檻 →
鍵盤/手把選牌時,滑鼠 1px 晃動即搶走手牌焦點。

## 執行
`Godot_v4.7.1 console --headless --path . -s res://prototypes/hand-focus-mouse-steal-probe-2026-11-11/probe.gd`
原始輸出:`run_output.txt`。

## 方法與限制
- `load()` 真實 `BattleScreen.tscn`,`call_deferred("add_child")`,等 2 幀(技術偏好第 5 點)。
- 開手牌:呼叫 production 的 `_handle_open_hand_pressed()`;方向:`Input.action_press(ui_right)` + 對 `_input()` 送 InputEventAction(production 的 `_handle_hand_navigation` 用 `Input.is_action_pressed` 判定)。
- headless 引擎不派送 InputEvent,故直接呼叫 `BattleScreen._input()`(production 入口,非 `_unhandled_input`)。
- 卡格座標取自 `HandBar._slot_nodes` 的 global transform(與 `slot_index_at` 同一幾何;探針有印 `slot_index_at(centre)` 對得上)。
- 未量棋盤側 75px 門檻(未讀其實作,僅屬 ux-designer 推論)。

## 發現
```
PROBE after ui_right: cursor_index=1
PROBE control (mouse on same card, rel=(1,0)): cursor_index=1 expected unchanged=1
PROBE test (mouse on other card, rel=(1,0)): cursor_index=0 before=1 stolen=true
PROBE RESULT: CONFIRMED focus stolen by 1px motion
```
