# story-044 實作前置事實查核(2026-11-12)

查核者:lead-programmer。範圍:只讀碼,未跑引擎。依據規格 `docs/reviews/highlight-and-info-panel-art-spec-2026-11-12.md` 要求的兩項,加上 ③④。
所有行號為 2026-11-12 工作樹現值(`battle_screen.gd` 有未提交改動,行號可能漂移;下方附 grep 指令可重跑)。

## ① 選牌模式下,攻擊範圍標記是否被隱藏:【否,沒有任何隱藏】

證據:
- `src/ui/battle/battle_screen.gd` 的 `_refresh_view()`:範圍標記區塊的唯一閘門是 `if selected != -1:`(約 4806 行),`selected = _controller.selected_unit()`。
  區塊內寫入 `set_attack_highlights` / `set_attack_los_blocked_highlights` / `set_threat_highlights` / `set_move_*`,**整段不讀 `_card_selecting_target`**。
- `_card_selecting_target` 在同函式只出現在三處:4762(算合法目標)、4783/4800(旗標 `card_target_illegal`)、4930(card-target 三態疊圖)。三處都不碰範圍標記。
- 進入選牌的路徑不清除單位選取:`_handle_open_hand_pressed()` -> `BattleController.open_hand()`(`battle_controller.gd` 647 行起)只轉交 `_card_play_session.open_hand()`;`select_card()`(661 行)同。控制器內 `_selected_unit_id` 只在 1215(`_select_unit_internal`)與 1224(`_clear_selection_internal`)被寫。
- 結論:若進入手牌前已選了一個單位,範圍標記與 card-target 疊圖**同時顯示**。若沒選單位,範圍標記本來就不畫。

重跑:
```
grep -n "_card_selecting_target" src/ui/battle/battle_screen.gd | sed -n '/47[0-9][0-9]\|48[0-9][0-9]\|49[0-9][0-9]/p'
grep -n "_selected_unit_id = " src/gameplay/battle/battle_controller.gd
```
(誠實揭露:這是讀碼推論,「open_hand 路徑不呼叫 `_clear_selection_internal`」依據是 `_card_play_session` 之外的控制器碼只有上述兩處寫入;`CardPlaySession` 內部未讀,但它沒有控制器的 `_selected_unit_id` 寫入權。未實機開窗驗證。)

044 含意:規格若要求選牌時隱藏攻擊範圍標記,**需要新增閘門**(在 `_refresh_view()` 的 `if selected != -1` 加 `and not _card_selecting_target`,或在 else 分支一併清空),現況不存在。

## ② 「可攻擊」集合(`attack_targets().cells`)是否含空格:【否,只含敵兵所在格】

證據:`src/gameplay/battle/battle_controller.gd` 的 `_attack_targets_for()`(1332 行):
```
for enemy: Unit in _state.units_of(opposing):
    if _state.can_attack(unit_id, enemy.id):
        result.append(_state.position_of(enemy.id))
```
只對敵方單位迴圈,結果即「可被打的敵兵所在格」,**不可能含空格**。`attack_targets()`(368 行)直接包它。

對照:`attack_targets_blocked_by_los()`(399 行)文件明寫「unoccupied-agnostic」,是純幾何集合,**會含空格也會含敵兵格**。
且 `_refresh_view()` 的 `threat_excluded` 排除 `attack_cells`,所以「可攻擊」標記只會畫在敵兵格上。
若 044 要「空格也標可攻擊範圍」,資料來源不在 `attack_targets()`,需要另一支查詢(目前沒有)。

重跑:`grep -n "func _attack_targets_for" -A12 src/gameplay/battle/battle_controller.gd`

## ③ 044 用 041 的兩個 rect 函式當禁區:【可行】

證據(`src/ui/battle/board_view.gd`,提交 `74fbce7`):
- 1011:`static func hp_text_rect_in_cell() -> Rect2` = `Rect2(0, HP_TEXT_TOP_MARGIN=0, 32, HP_TEXT_HEIGHT=8)` -> 格內 x[0,32) y[0,8)
- 1015:`static func piece_label_rect_in_cell() -> Rect2` = `Rect2((0, 8), (12,14))` -> x[0,12) y[8,22)
- 1019:`static func hp_bar_rect_in_cell()`(同批新增,規格未提,可一併當禁區):x[6,26) y[26,29)
- 皆為 static、相對格左上、不需實例;`_build_hp_text`/`_apply_piece_label`/`_build_hp_bar` 都呼叫它們,是單一出處。測試已引用(`tests/integration/ui/board_view_hp_text_label_layout_test.gd` 69-70、90 行)。
注意:格是 32x32,但棋子精靈 32x40 向上伸出格頂 8px(`PIECE_SPRITE_HEIGHT`),精靈區不在這三個矩形內,禁區只涵蓋文字/血條,不涵蓋精靈上緣。

重跑:`grep -n "static func .*_rect_in_cell" src/ui/battle/board_view.gd`

## ④ 被擋 6x6 章 (21,5)-(27,11) 與 HP 文字條 y[0,8) 是否相交:【相交 —— 依規格,到此停下回報】

算術(格內座標,章 x[21,27) y[5,11)):
- 對 HP 文字條 x[0,32) y[0,8):x 全含於內;y 交集 [5,8) = 3 列,**6x3 = 18 像素重疊**(章 36 像素的一半)。
- 對首字框 x[0,12) y[8,22):x 交集為空(21 >= 12),不相交。
- 對血條 x[6,26) y[26,29):y 交集為空,不相交。
章的下半 y[8,11) 落在文字條之下、首字框右側的空地,是安全的;上半 3 列壓在 HP 文字條上。
該章會出現的格:`attack_targets_blocked_by_los()` 是占位不可知(含敵兵格),所以被擋格上**可能有敵兵且 `show_hp_text` 為真**,相交不是理論上的。
(現行被擋標記是 `_build_attack_los_blocked_outline`/`_slash`:外框 inset 4、寬 2、斜線 inset 8,同樣會穿過 y[0,8),相交問題在現況就存在,與新章無關。)

可行修法(由 art-director/管理者裁,不是我決定):章下移到 y>=8(例如 (21,8)-(27,14),仍避開首字框 x<12 與血條 y>=26),或章上緣改為 y>=8 的圖形。

## 結論

044 **目前不可原樣開工**,還差三件:
1. 被擋章座標 (21,5)-(27,11) 與 HP 文字條重疊 18px,規格自己要求停下 —— 需 art-director 改座標(建議 y 起點 >= 8)。
2. ① 若規格要求選牌時隱藏範圍標記,`_refresh_view()` 需新增閘門(現況無)—— 屬 044 範圍內程式改動,但需確認規格是否真要隱藏。
3. ② 若規格要「空格也標可攻擊」,`attack_targets()` 做不到(只回敵兵格),需新查詢或改由 `attack_targets_blocked_by_los()` 類幾何集合 —— 需規格先裁決資料來源。
③ 沒有阻礙,041 的兩個(加上 `hp_bar_rect_in_cell`)rect 函式可直接當禁區。
