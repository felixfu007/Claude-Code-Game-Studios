# 戰棋 M1 限時現況查證批(2026-09-29)

執行者:godot-gdscript-specialist
性質:唯讀查證,零實作,零測試執行,零引擎執行。

## U-T4 — battle_controller/turn_order 是否已有「不選取也能查任一單位四態」的 getter
**結論**:⚠️ 有缺口
**缺口形狀**:`TurnOrder.can_move(id)` / `can_attack(id)` / `is_done(id)` 三個方法都已接受任意 `id`
參數,**不需要先 `select_unit()`**——但 `can_move`/`can_attack` 內部經 `_is_actionable(id)` 閘門,
只要 `id` 不屬於當前 `_current_side`(輪到誰的回合),一律回傳 `false`,**不論該單位真正的
move/attack 旗標值為何**——也就是「非本回合單位」與「旗標已用完」被同一個 `false` 蓋掉,
無法從外部區分。`is_done(id)` 不受此閘門影響,可安全查任意單位。此外沒有任何一個方法
把 can_move+can_attack+is_done 三者合併成單一「四態」回傳值(fresh/moved-only/attacked-only/done)
——呼叫端得自己組合三次呼叫。`BattleController` 本身**沒有**轉發這三個查詢給任意 `id`
的公開方法(`move_targets()`/`attack_targets()`/`threat_targets()` 都只操作
`_selected_unit_id`)——`battle_screen.gd` 目前是靠自己持有與 `BattleController` 相同的
`TurnOrder` 實例(`_order` 欄位,兩者建構時傳入同一個物件)才繞得過去,這是巧合式耦合,
不是設計出來的介面。
**原始輸出**:
    $ Read src/gameplay/battle/battle_controller.gd(全檔 1126 行)
    $ Read src/gameplay/battle/turn_order.gd(全檔 193 行)
    can_move(id): return _is_actionable(id) and not _move_used.get(id, false)
    can_attack(id): return _is_actionable(id) and not _attack_used.get(id, false)
    is_done(id): if not _unit_side.has(id): return true \n return _done.get(id, false)
    _is_actionable(id): if _unit_side[id] != _current_side: return false ...
    BattleController 公開方法清單(grep "^func "):phase/round_number/selected_unit/
    selectable_units/move_targets/attack_targets/threat_targets/outcome/
    has_pending_discard/... 全部操作 _selected_unit_id 或不帶 id 參數;無 unit_action_state(id) 類方法。
    battle_screen.gd:387-388 `var _order: TurnOrder` / `var _controller: BattleController`;
    :917 `_order = TurnOrder.new(...)`;:938 `_controller = BattleController.new(_state, _order, ...)`
    ——同一個 _order 實例同時是 battle_screen.gd 的欄位與 BattleController 建構參數。
**對 story 的影響**:支持 M3 項目 3「單位行動四態 getter」維持在範圍內
(epic 已預期,`U-T4 若查證為「不存在」`——本次查證結果是「部分存在但形狀不對」,
比「完全不存在」更精確,不改變 M3 要補這個 getter 的結論)。

## U-T5 — render_pieces() 是否有陣亡淡出過渡
**結論**:❌ 不存在
**缺口形狀**:`board_view.gd` 的 `render_pieces(pieces)` 每次呼叫都先 `_clear_children(_pieces_layer)`
/ `_clear_children(_stats_layer)`,再對傳入的 `pieces` 陣列逐筆 new 一個全新的 `Sprite2D`——
全檔(`board_view.gd`)搜尋 `fade`/`tween`/`modulate`/`dying`/`death`/`dead` 全部零命中。
餵給它的 `pieces` 陣列來自 `battle_state.gd` 的 `units_of(faction)`,該方法過濾條件是
`unit.faction == faction and unit.is_alive()`——陣亡單位在下一次 `_refresh_view()` 就直接從
陣列消失。兩者合起來:單位死亡的下一格畫面,它的 sprite 就地瞬間消失,沒有任何淡出/過渡。
**原始輸出**:
    $ grep -n "func render_pieces|fade|tween|modulate|dying|death|dead" src/ui/battle/board_view.gd
    277:func render_pieces(pieces: Array[Dictionary]) -> void:
    (其餘關鍵字零命中)
    $ Read board_view.gd:277-303(render_pieces 全函式)—— _clear_children 兩層 + for 迴圈
    new Sprite2D,無 Tween/modulate。
    $ grep -n "func units_of" -A 6 src/gameplay/battle/battle_state.gd
    179: func units_of(faction: Unit.Faction) -> Array[Unit]:
    182:     if unit.faction == faction and unit.is_alive():
**對 story 的影響**:確認 M3 依賴表第 142 行「下游:M3 的三個切面、M4 的四態高亮、M5 的
第四態貼圖,全部等這裡」之外,**M3 節列出的五組切面本身不含陣亡過渡**——這是 M4(世界層
呈現)範圍的缺口,不是 M3。依 epic 原判斷「決定 M3 要不要多一張 story」:目前查證結果是
這件事完全不存在,且落點應在 M4(繪製層)而非 M3(查詢層)——若管理者仍要補這項,建議
story 應掛在 M4 底下,而非 M3。

## U-T6 — `_input()` 對敵方回合(ENEMY_ACTING)的拒絕是否逐幀生效
**結論**:⚠️ 有缺口
**缺口形狀**:`_input(event)` 頂部只擋 `_load_failed` 與 `phase() == FINISHED` 兩種狀況,
**沒有對 `ENEMY_ACTING` 的頂層檢查**。往下分派到 `_handle_mouse_button()` 與
鍵盤/手把分支(`_handle_directional()` → `_confirm_at_cursor()`)時,這兩條路徑**都沒有
自己的 phase 檢查**——`_handle_mouse_button()` 只檢查 `is_card_play_in_progress()` /
`has_pending_discard()`,`_handle_directional()`/`_confirm_at_cursor()` 完全不檢查任何守衛。
真正擋下遊戲狀態變更的是更深一層的 `BattleController.click_tile()` 內部的
`if _phase != Phase.PLAYER_INPUT: return {"action": &"none"}`——所以 **BattleState 本身
不會被敵方回合中的滑鼠/鍵盤輸入改動**,但兩個可觀察的副作用不受這層保護:
①`_cursor_cell = cell` 與 `_board_view.set_cursor(cell)` 在 `_handle_mouse_button()` 與
`_handle_directional()` 中都會照常執行,即敵方回合中游標仍會隨滑鼠點擊/方向鍵移動;
②`click_tile()` 回傳的 `{"action": &"none"}` 沒有被上層以「敵方回合」為由特別辨識或提示
(見 U-T7,同一個 `&"none"` 也用於「什麼都沒選,點到空地」)。**這正是 epic M6 範圍②
「補查證批查出的輸入缺口(U-T6 敵方回合拒絕)」預期會找到的形狀。**
**原始輸出**:
    $ Read battle_screen.gd:1047-1052(_input 開頭)
    func _input(event: InputEvent) -> void:
        if _load_failed: return
        if _controller.phase() == BattleController.Phase.FINISHED: return
    $ Read battle_screen.gd:1682-1708(_handle_mouse_button 全函式)
        if _controller.is_card_play_in_progress() or _controller.has_pending_discard(): return
        ...(無 phase 檢查)... _cursor_cell = cell; _board_view.set_cursor(cell); _controller.click_tile(cell)
    $ Read battle_screen.gd:1729-1734(_handle_directional 全函式)——無 phase 檢查,
        直接 _cursor_cell = clamp_cursor_move(...); _board_view.set_cursor(_cursor_cell)
    $ Read battle_screen.gd:2285-2288(_confirm_at_cursor 全函式)——只檢查 in_bounds,無 phase 檢查
    $ battle_controller.gd:547-549 click_tile() 頂部:
        if _phase != Phase.PLAYER_INPUT: return {"action": &"none"}
**對 story 的影響**:支持 M6 範圍②維持在範圍內——建議 story 描述精確化為「頂層輸入分派
需在 ENEMY_ACTING 時擋下游標移動等視覺副作用,不只是靠深層 click_tile() 擋狀態變更」,
而不只是「補一個閘門」這麼籠統。

## U-T7 — click_tile() 的 {"action":"none"} 回傳是否觸發可辨識拒絕回饋
**結論**:❌ 不存在
**缺口形狀**:`src/ui/` 底下呼叫 `click_tile()` 的兩處(`_handle_mouse_button()` 內、
`_confirm_at_cursor()` 內)都是裸呼叫,回傳值完全未被接收,更遑論檢查。`&"none"` 這個
action 值在整個 `src/` 裡只在 `battle_controller.gd` 內部被產生(4 處 return 語句 + 文件
註解),**沒有任何一處消費它**——不論是分支判斷、音效觸發、閃爍動畫還是 `push_error`。
epic 原文的擔憂「回傳一個被忽略的 Dictionary = 靜默」成立,且是**目前程式碼的實際狀態**,
不只是風險。
**原始輸出**:
    $ grep -rn "click_tile" src/ui/ --include=*.gd
    src/ui/battle/battle_screen.gd:1708:	_controller.click_tile(cell)
    src/ui/battle/battle_screen.gd:2288:	_controller.click_tile(_cursor_cell)
    $ grep -rn '&"none"' src/ --include=*.gd
    src/gameplay/battle/battle_controller.gd:549:		return {"action": &"none"}
    src/gameplay/battle/battle_controller.gd:566:	return {"action": &"none"}
    src/gameplay/battle/battle_controller.gd:984:		return {"action": &"none"}
    src/gameplay/battle/battle_controller.gd:1008:		return {"action": &"none"}
    src/gameplay/battle/battle_controller.gd:1011:		return {"action": &"none"}
    (其餘命中皆為 battle_controller.gd 自己的文件註解)
**對 story 的影響**:支持 M5/M6 補「可辨識拒絕回饋(P-F2)」這件事維持在範圍內——目前是
徹底的 0 分,不是部分實作,規模估計上不應被低估為「補個小分支」;至少需要在
`battle_screen.gd` 兩個呼叫點接住回傳值並依 action 值分派(至少要能區分
`&"none"`/`&"blocked_pending_discard"`/其餘合法 action,呼應 `click_tile()` 自己文件註解
裡對「兩種靜默不可混淆」的既有設計意圖)。

## U-T8 — 「結束該單位行動」的輸入路徑
**結論**:❌ 不存在
**缺口形狀**:`end_unit_turn(id)` 全專案只有兩個呼叫端——`battle_loop.gd`(自動化模擬迴圈)
與測試——**`src/ui/` 底下零命中**。另以實體名擴大搜尋 `end_unit|end_turn|EndTurn|end_faction|
結束.*行動`,`src/ui/` 命中的全部是 `end_faction_phase()`(結束整個陣營回合),沒有任何一處
是 `end_unit_turn()`。**這是兩件不同的事,不能混為一談**:「結束整個陣營回合」有完整的介面
路徑(`battle_menu.gd` 選單列 → `end_faction_phase_confirmed` 訊號 → `battle_screen.gd` 的
`_end_faction_phase_pressed()`);「主動結束單一單位、放棄剩餘的移動/攻擊旗標」則完全沒有
玩家可觸發的路徑——`BattleController.end_unit_turn(id)` 這個公開方法存在且可用
(`battle_controller.gd:575`),但沒有任何 UI 呼叫端會呼叫它。若 GDD/UX 規格要求玩家能主動
放棄單位的剩餘行動(而非只能靠「移動+攻擊都用完自動變 done」或「結束整個陣營回合」兩種
方式跳過),這個能力目前確實不存在。
**原始輸出**:
    $ grep -rn "end_unit_turn" src/ --include=*.gd
    src/gameplay/battle/battle_controller.gd:575:func end_unit_turn(id: int) -> bool:
    src/gameplay/battle/battle_controller.gd:580:	if not _order.end_unit_turn(id):
    src/gameplay/battle/battle_controller.gd:1068:		_order.end_unit_turn(id)
    src/gameplay/battle/battle_loop.gd:245:		_order.end_unit_turn(id)
    src/gameplay/battle/turn_order.gd:117:func end_unit_turn(id: int) -> bool:
    (其餘命中皆為文件註解)
    $ grep -rn "end_unit\|end_turn\|EndTurn\|end_faction\|結束.*行動" src/ui/ --include=*.gd
    src/ui/menu/battle_menu.gd:856:	controller.end_faction_phase()
    src/ui/menu/battle_menu.gd:857:	end_faction_phase_confirmed.emit()
    src/ui/battle/battle_screen.gd:998:	_battle_menu.end_faction_phase_confirmed.connect(_end_faction_phase_pressed)
    src/ui/battle/battle_screen.gd:2379:		_controller.end_faction_phase()
**對 story 的影響**:若 P-I2(無滑鼠路徑)或 GDD 要求玩家能主動結束單一單位行動,M5/M6
需要新增一條輸入路徑(選單列新增一行,或現有輸入分支新增一個 action)呼叫
`end_unit_turn(_selected_unit_id)`——這是目前完全不存在的功能,不是「補強現有路徑」規模。

## U-T10 — Tab/RB 跳轉排序是否決定性且有測試釘死
**結論**:⚠️ 有缺口(機制與測試皆存在,但未查證戰棋單位跳轉與卡牌選標跳轉是否共用同一實作)
**缺口形狀**:輸入機制確實存在——`project.godot` 有 `battle_next_target`/`battle_prev_target`
兩個輸入動作,`battle_screen.gd` 有對應的 `_target_jump_requested`/`_target_jump_forward`
旗標(第 632-633、1156-1162 行一帶)。測試也確實存在,共 7 條,涵蓋 row-major 順序、
正反向循環、重複執行結果一致、當前 id 不在合法集合內的邊界情況、空集合回傳 -1。
**但這 7 條測試全部位於 `tests/integration/ui/card_target_selection_test.gd`**——字面上測的
是「卡牌打出時選標的」的跳轉,不是「戰棋一般攻擊選單位」的跳轉,而 GDD/UX 規格要求的
Tab/RB 排序(UI Requirements §3)語境上聽起來是後者。`battle_screen.gd:1231` 附近的註解
確實引用了 `test_jump_order_identical_across_repeated_runs` 這個測試名——這**暗示**兩條路徑
可能共用同一段排序邏輯(例如同一個 helper 函式被兩處呼叫),但**沒有人實際追過呼叫鏈去
確認**「戰棋一般攻擊的目標跳轉」與「卡牌選標的跳轉」是不是走同一份程式碼,還是兩份各自
獨立、只是測試剛好只覆蓋到其中一份。
**原始輸出**:
    $ grep -n "battle_next_target\|battle_prev_target" project.godot
    (輸入動作已註冊,確切行號未附)
    $ grep -n "_target_jump_requested\|_target_jump_forward" src/ui/battle/battle_screen.gd
    632-633、1156-1162 行一帶命中
    $ grep -rn "func test_.*jump" tests/ --include=*.gd
    tests/integration/ui/card_target_selection_test.gd:665:func test_jump_to_next_legal_target_cycles_in_row_major_order() -> void:
    tests/integration/ui/card_target_selection_test.gd:682:func test_jump_cycle_wraps_from_last_to_first() -> void:
    tests/integration/ui/card_target_selection_test.gd:695:func test_jump_cycle_wraps_backward_from_first_to_last() -> void:
    tests/integration/ui/card_target_selection_test.gd:706:func test_jump_order_identical_across_repeated_runs() -> void:
    tests/integration/ui/card_target_selection_test.gd:732:func test_jump_with_current_id_not_in_set_starts_from_first_going_forward() -> void:
    tests/integration/ui/card_target_selection_test.gd:743:func test_jump_with_current_id_not_in_set_starts_from_last_going_backward() -> void:
    tests/integration/ui/card_target_selection_test.gd:754:func test_jump_on_empty_set_returns_negative_one() -> void:
**對 story 的影響**:M5/M6(或對應戰棋一般攻擊流程的 story)在動工前應先確認這件事——
若戰棋跳轉與卡牌跳轉共用同一個排序 helper,測試涵蓋是足夠的,GDD UI Requirements §3
可視為已滿足;**若是兩套各自獨立的實作,戰棋一般攻擊的 Tab/RB 跳轉目前是零測試覆蓋**,
需要補一張獨立的 story/測試,規模判斷會完全不同。這個「先確認是不是同一份程式碼」本身
應該是下一步(story 切分前或第一張 story 的第一步)要做的事,不應該假設任一個方向。

## U-T11 — TEXT_* 常數是否走本地化管線
**結論**:❌ 不存在
**缺口形狀**:全 `src/` 搜尋 `tr(`/`TranslationServer`/`translations` 零命中,`project.godot`
搜尋 `locale`/`translation` 也零命中——**專案沒有任何本地化基礎設施**。`battle_screen.gd`
裡的 `TEXT_*` 常數(如 `TEXT_STATUS_FORMAT`、`TEXT_FACTION_PLAYER`、
`TEXT_AFFINITY_PREVIEW_FORMAT`、`TEXT_LOAD_FAILURE_FORMAT`)都是**繁體中文字面直接寫死在
常數宣告裡**,不是本地化 key。
**原始輸出**:
    $ grep -rn "\btr(\|TranslationServer\|translations" src/ --include=*.gd
    (零命中)
    $ grep -n "locale\|translation" project.godot
    (零命中)
    $ grep -rn "^const TEXT_" src/ --include=*.gd | head
    src/ui/battle/battle_screen.gd:153:const TEXT_STATUS_FORMAT: String = "第 %d 回合．%s"
    src/ui/battle/battle_screen.gd:154:const TEXT_FACTION_PLAYER: String = "我方行動"
    src/ui/battle/battle_screen.gd:166:const TEXT_AFFINITY_PREVIEW_FORMAT: String = "好感度 %+d→%+d"
    src/ui/battle/battle_screen.gd:198:const TEXT_LOAD_FAILURE_FORMAT: String = "遊戲資料載入失敗,無法開始戰鬥。"
**對 story 的影響**:epic 原文把這項標為「做完再改成本高」——**這代表 M5 新增兩個面板時
必須現在就決定,不能拖到之後**:若比照現行 `TEXT_*` 慣例繼續寫死中文字面,兩個新面板的
文字之後要接本地化管線時,改動規模等於「全部重寫」;若要現在就打好本地化的底(即使管線
本身還沒做),至少應該讓新面板的文字走同一個常數集中管理的模式,不要再擴大寫死的面積。
**這件事需要管理者/技術總監就「本階段是否明文接受寫死」做一次裁決,不是本查證批能自己
決定的**——本項只負責把「現況是徹底寫死、沒有任何本地化基礎設施」這個事實釘死。

## U-T12 — `_apply_attack()`/`_apply_move()` 是否單幀同步完成
**結論**:✅ 已滿足(高把握,但未逐字搜尋 await/yield 佐證,標記從寬)
**缺口形狀**:無
**原始輸出**:
    $ Read battle_controller.gd:982-1014(_apply_attack()、_apply_move() 全函式,
      憑本次任務稍早已完整讀過的全檔內容回憶)
    _apply_attack(): 直接呼叫 _compute_phi() → _state.resolve_attack() → _order.use_attack()
      → _state.unit_by_id() → 視情況 _order.remove_unit() → emit → _check_outcome_and_finish()
      → return Dictionary。全程無 await、無 call_deferred、無 CONNECT_DEFERRED。
    _apply_move(): _state.position_of() → _state.move_unit() → _order.use_move() → emit → return。
      同樣全程同步。
    另外 step_enemy_phase() 的類別文件註解(battle_controller.gd 第 730-736 行一帶)明文自陳
    「Fully synchronous — contains no await, no call_deferred(), and no CONNECT_DEFERRED」
    並列出其呼叫鏈只含 _process_enemy_unit/_finalize_enemy_phase/TurnOrder 幾個同步方法。
**對 story 的影響**:支持 R5 風險登記的判斷方向——AC-24 重入窗口目前寬度為零,天然滿足、
測不出東西;若 M4 未來替陣亡/攻擊動畫加上跨幀演出(呼應 U-T5 的發現——目前確實沒有陣亡
過渡,但這正是 M4 可能會新增的東西),窗口會憑空長出來,屆時 M6 才需要補 AC-24 閘門。
**誠實揭露**:本項未另外對全檔案做 `await`/`yield`/`call_deferred` 關鍵字的獨立 grep 覆核
——結論建立在稍早完整讀檔的記憶與函式本身的可見程式碼上,未重新執行指令驗證,若要更高
把握度應在下一步補一次 `grep -n "await\|call_deferred\|CONNECT_DEFERRED" battle_controller.gd`。
