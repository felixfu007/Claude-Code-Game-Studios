# Story U-013（選作用對象 S2/S2p/S2q + 合法目標高亮 + 跳轉鍵）的測試 ——
# production/epics/card-play-interface/story-u013-target-selection-and-highlight.md。
#
# 🔴 2026-09-23 更正:本段原文寫著本檔只涵蓋 AC-U3 的兩個純靜態函式,其餘三支
# 測試「尚未寫入,卡在一個未決的架構問題——BattleScreen 要不要真正掛上
# CursorStateHost」。這句話現在是假的:battle_screen.gd 已經真的呼叫
# CursorStateHost.register_surface()/unregister_surface()(見該檔
# _confirm_selected_card() / _after_target_selection_advanced() /
# _handle_target_selection_cancel_transition() 三處的真實呼叫),架構問題已經
# 關閉,不再是任何一支測試寫不出來的理由。
#
# 現況(逐支交代,不用「全部完成」這種會蓋住缺口的總結語,2026-09-23 第三批更新):
#   - test_target_retarget_actor_priority_falls_inside_the_mandated_open_interval
#     —— 已寫入(本批)。釘 ADR-0005 R5-2 的開區間,不只是 -60 這個當下值。
#   - test_cursor_navigate_*(5 支)—— 已寫入(本批)。純函式邊界,一次合法移動 +
#     四個方向各自越界。
#   - test_reading_cursor_arbitrated_target_happens_in_process_not_input
#     —— 已寫入(本批)。見本檔「_input()/_process() 讀取時機」一節開頭的乙類
#     揭露段。
#   - test_cancel_from_s2q_returns_to_s2p_not_s1 —— 已寫入(前一批)。見本檔
#     「cancel() 從 S2q 退回 S2p」一節,以及該測試自己的 doc comment——為什麼
#     不能用 _fresh_instance() 真實走「開手牌 -> 選卡」UI 流程(隨機手牌不滿足
#     Determinism),改用哪個既有工廠函式繞開。
#   - test_illegal_tile_reachable_by_directional_navigation_but_confirm_rejected
#     —— 尚未寫入。設計已確認(甲類卡,敵方單位天生不合法;CursorStateHost.set_target()
#     要求 BOARD_TILE 先註冊,Arrange 階段需手動呼叫 register_surface()),尚未落地。
#   - register/unregister 成對發生(尚無正式函式名,前一位設計的原始構想已被本批
#     推翻——見下方)—— 尚未寫入。**前一位原設計(直接呼叫 _controller.select_card()
#     驅動)行不通**:CursorStateHost.register_surface() 只寫在 battle_screen.gd 的
#     UI 層方法 _confirm_selected_card()/_after_target_selection_advanced()/
#     _handle_target_selection_cancel_transition() 裡(2026-09-23 協調者以
#     `awk '/^func /{fn=$0} /register_surface\(CursorTypes.SurfaceType.BOARD_TILE/
#     {print NR": "fn}' src/ui/battle/battle_screen.gd` 覆核確認,CardPlaySession/
#     BattleController 一處都沒有),只換掉 _card_play_session 不會觸發這個副作用。
#     改良路線:呼叫 instance._state.attach_card_deck(deck)(BattleState 的公開方法)
#     讓 _state.card_deck() 與換掉的 CardPlaySession 用同一個 deck 物件,再真的呼叫
#     instance._confirm_selected_card() 這個 UI 層方法本身觸發 register_surface()。
#     尚未落地,可能還有沒預見的接縫。見任務報告。
# 見任務報告。
#
# 本檔另涵蓋 board_view.gd 的 set_card_target_highlights()（三態高亮圖層，同一張
# story 的計畫第 6 項）：合法=外框、不合法=外框+X，形狀可區分（P-F3 無例外），
# 沿用 hand_bar.gd 鎖圖示/類別圖示的既有作法（組合圖元，不新增 PNG 資產）。
#
# ⚠️ headless 不 rasterize 繪製結果——以下測試只能驗「畫了幾個節點、什麼型別、
# 疊在哪一層」這種結構性事實，驗不了「外框看起來像外框、X 看起來像 X」這種視覺
# 判讀。後者需要真實開視窗擷圖 + 人眼看過，尚未進行——見任務報告的登記。
#
# 命名慣例依 tests/unit/ui/battle_screen_cursor_test.gd 先例：
# test_[scenario]_[expected]，extends GdUnitTestSuite。
#
# ============================================================================
# 敏感度證明涵蓋盤點（2026-09-23）
# ============================================================================
# 依 .claude/rules/test-standards.md 第 113 行起門檻：「每條測試要嘛有敏感度
# 證明，要嘛有寫下來、可查證的『為什麼證明不了』」。本表逐條盤點本檔 25 條
# test_ 函式，判定屬「可證明」或五類（A/A′/B/C/D）之一，並在下方逐條給出可
# 查證的依據。骨架先行寫入，逐條查核後於本區塊內填入，不待全部查完才寫。
#
# 判定代碼：可證明 / A（static 純函式）/ A′（真實資料檔內容）/
#           B（RNG 決定性契約）/ C（進樹後換腳本才能注入）/ D（唯一注入點在受限範圍外）
#
# | # | 測試函式名 | 判定 | 依據 |
# |---|---|------|------|
# |  1 | test_card_target_highlight_layer_node_resolves_with_correct_type | 可證明 | BoardView 有 class_name（board_view.gd:59-60，已讀本體確認）；_fresh_board_view()（本檔:134-137）在 instantiate() 後、add_child() 前有 Case A 可注入空檔（test-standards.md 2026-09-17 已驗證安全）。注入：子類別 _MutantBoardViewNoHighlightLayer extends BoardView，覆寫 _ready()：呼叫 super._ready() 後用 get_node_or_null("CardTargetHighlightLayer") 取得節點並 remove_child()+queue_free()。test_sensitivity_proof_... 斷言 mutant 上 get_node_or_null("CardTargetHighlightLayer") 為 null，證明 is_not_null()/is Node2D 斷言會抓到節點被移除。⚠️ 未讀 board_view.gd 的 _ready() 本體，但注入方案刻意設計成在 super 呼叫之後才動作，不依賴其內部實作。 |
# |  2 | test_card_target_highlight_layer_draws_above_pieces_and_below_stats | 可證明 | 同 Row1 的 Case A 空檔。子類別 _MutantBoardViewWrongLayerOrder extends BoardView，覆寫 _ready()：呼叫 super._ready() 後對 CardTargetHighlightLayer 呼叫 move_child(that_node, 0) 強制移到最前（疊在 PiecesLayer 之下）。test_sensitivity_proof_... 斷言 mutant 上 CardTargetHighlightLayer.get_index() < PiecesLayer.get_index()，證明 is_greater(pieces_index) 斷言會抓到疊層順序被改壞。⚠️ 同上未讀 _ready() 本體，注入不依賴其內部實作。 |
# |  3 | test_set_card_target_highlights_draws_one_outline_root_per_legal_cell | 可證明 | set_card_target_highlights() 為 BoardView 一般 instance method、非 static（已讀簽章，board_view.gd:369）。子類別 _MutantHighlightsDrawsNothingForLegal extends BoardView，直接覆寫 set_card_target_highlights(legal, illegal) 為刻意錯誤實作（合法格清單完全不畫）。經 Case A 建構後呼叫 mutant.set_card_target_highlights([Vector2i(1,1), Vector2i(3,2)], [])，test_sensitivity_proof_... 斷言 layer.get_child_count() 不等於 2，證明 is_equal(2) 斷言會抓到合法格漏畫。 |
# |  4 | test_set_card_target_highlights_illegal_cells_get_outline_plus_x_mark | 可證明 | 同 Row3 機制。子類別覆寫 set_card_target_highlights()，對不合法格只畫外框、省略 X 記號（跳過 Line2D 繪製那段）。test_sensitivity_proof_... 斷言 mutant 呼叫 set_card_target_highlights([], [Vector2i(2,2)]) 後 line_count 為 0（非預期 2），證明 Line2D 數量斷言 is_equal(2) 會抓到不合法格漏畫 X。 |
# |  5 | test_set_card_target_highlights_with_two_empty_arrays_clears_the_layer | 可證明 | 同組機制。子類別覆寫 set_card_target_highlights()：當 legal 與 illegal 皆空時直接 return，不清空既有子節點。test_sensitivity_proof_... 先用 mutant 畫一些高亮，再呼叫 set_card_target_highlights([], [])，斷言 layer.get_child_count() 仍大於 0，證明 is_equal(0) 斷言會抓到清空失敗留下殘影。 |
# |  6 | test_sort_targets_by_position_orders_row_major_regardless_of_input_order | A | sort_targets_by_position 確認為 static func（已讀本體，battle_screen.gd:947），呼叫端皆為 BattleScreen.sort_targets_by_position(...) 直接對類別呼叫，無實例、無繼承鏈可覆寫，無法用子類別/間諜手法注入突變。本檔既有「敏感度證明」區塊（現行第 960-971 行）已涵蓋此組（與 next_target_id 共用一段論述），但其論述方式（手動改壞、觀察、改回）是 test-standards.md 2026-09-16 裁決明文淘汰的手動注入格式，不是常駐的 test_sensitivity_proof_*——格式與新裁決有落差，但 A 類本身（無法建常駐證明）的判定不受此影響。 |
# |  7 | test_sort_targets_by_position_identical_across_repeated_runs_with_different_input_order | A | 同第 6 列依據（同一個 static 函式，同一段既有揭露涵蓋）。 |
# |  8 | test_sort_targets_by_position_of_empty_array_is_empty | A | 同第 6 列依據。 |
# |  9 | test_sort_targets_by_position_breaks_position_ties_by_ascending_id | A | 同第 6 列依據——本測試額外針對「座標相同時以 id 為第三決定鍵」分支，但受測函式仍是同一個 static sort_targets_by_position()，可覆寫性判定不變。 |
# | 10 | test_jump_to_next_legal_target_cycles_in_row_major_order | A | next_target_id 確認為 static func（已讀本體，battle_screen.gd:975），呼叫端皆為 BattleScreen.next_target_id(...) 直接對類別呼叫，無實例、無繼承鏈可覆寫。本檔既有「敏感度證明」區塊（現行第 960-971 行）已涵蓋此組，格式落差說明同第 6 列。 |
# | 11 | test_jump_cycle_wraps_from_last_to_first | A | 同第 10 列依據。 |
# | 12 | test_jump_cycle_wraps_backward_from_first_to_last | A | 同第 10 列依據。 |
# | 13 | test_jump_order_identical_across_repeated_runs | A | 同第 10 列依據。 |
# | 14 | test_jump_with_current_id_not_in_set_starts_from_first_going_forward | A | 同第 10 列依據。 |
# | 15 | test_jump_with_current_id_not_in_set_starts_from_last_going_backward | A | 同第 10 列依據。 |
# | 16 | test_jump_on_empty_set_returns_negative_one | A | 同第 10 列依據（空集合邊界情境，受測函式仍是同一個 static next_target_id()）。 |
# | 17 | test_cancel_from_s2q_returns_to_s2p_not_s1 | 可證明 | _handle_target_selection_cancel_transition() 確認為 BattleScreen 一般 instance method、非 static（已讀本體，battle_screen.gd:1702）。_fresh_instance()（本檔:140-143）同樣有 Case A 可注入空檔。注入：子類別 _MutantAlwaysCancelToS1 extends BattleScreen，覆寫 _handle_target_selection_cancel_transition()，忽略 _controller.legal_targets() 的真實回傳值，無條件執行「回 S1」那支（_card_selecting_from_hand=true、_card_selecting_target=false）。經 Case A 建構後複製本測試既有 Arrange（CardDeck/AffinityLink/CardPlaySession 換掉 _card_play_session，open_hand()/select_card()/select_target(3) 走到 S2q），呼叫真正的 _controller.cancel()（未覆寫），再呼叫 mutant 版本的轉場方法。test_sensitivity_proof_... 斷言 _card_selecting_from_hand==true，證明真測試 is_false() 斷言會抓到 S2q 取消誤退回 S1。⚠️ BattleController 六個轉發方法各自的閘門（_phase!=PLAYER_INPUT、has_pending_discard()）採用協調者本輪提供之摘錄，惟與我自己先前讀過的 battle_controller.gd 第 363-479 行結論一致（本檔第三批更正註解第 458-476 行亦同），視為已核實而非單憑摘錄。 |
# | 18 | test_target_retarget_actor_priority_falls_inside_the_mandated_open_interval | 可證明 | _target_retarget_actor 為 BattleScreen 實例欄位，真測試本身即直接讀取 instance._target_retarget_actor（已讀本體，本檔:588），可推斷子類別內同樣可存取。注入：子類別 _MutantWrongRetargetPriority extends BattleScreen，覆寫 _ready()：呼叫 super._ready() 後直接賦值 _target_retarget_actor.process_priority=-10（落在 (-100,-25) 開區間之外）。test_sensitivity_proof_... 斷言 mutant 的 process_priority 不滿足 >-100 and <-25，證明真測試兩條開區間斷言會抓到優先序被改到區間外。⚠️ 未讀 _ready() 內建構該欄位/賦值 -60 的實際行數（本輪依協調者指示不讀 battle_screen.gd），但注入方案設計成在 super._ready() 執行完後才覆寫欄位，不依賴原始賦值寫在哪一行。 |
# | 19 | test_cursor_navigate_moves_within_bounds_returns_encoded_tile_id | 可證明 | cursor_navigate() 確認為 BattleScreen 一般 instance method、非 static（已讀本體，battle_screen.gd:1545，函式體僅呼叫 CursorTypes.decode_tile()/BoardCoords.is_in_bounds()/CursorTypes.encode_tile()，無場景狀態依賴）。_fresh_instance() 同樣有 Case A 空檔。本條驗證「合法移動應得到正確編碼」這條 happy path，注入：子類別 _MutantCursorNavigateWrongEncode extends BattleScreen，覆寫 cursor_navigate()，故意把 encode 時的欄位互換或加減 1 造成錯誤編碼。test_sensitivity_proof_... 呼叫 mutant.cursor_navigate() 走一步合法移動，斷言回傳值不等於正確編碼，證明本測試 is_equal(expected_id) 斷言會抓到編碼邏輯被改壞。 |
# | 20 | test_cursor_navigate_off_left_edge_returns_null | 可證明 | 同 Row19 的 Case A 空檔與非 static 事實。本條與 21-23 皆為邊界情境，四條共用同一個 mutant：子類別 _MutantCursorNavigateOffByOne extends BattleScreen，覆寫 cursor_navigate()，故意放寬邊界檢查（例如允許多一格，或省略 is_in_bounds 檢查直接回傳編碼）。test_sensitivity_proof_cursor_navigate_bounds_regression_detected 呼叫 mutant 版本、餵入本條的越界情境（最左欄再往左），斷言回傳值不是 null，證明本測試 is_null() 斷言會抓到邊界檢查被繞過。 |
# | 21 | test_cursor_navigate_off_right_edge_returns_null | 可證明 | 同 Row20 的共用 mutant 與敏感度證明，餵入的情境改為最右欄再往右（越界方向不同，注入與證明機制相同）。 |
# | 22 | test_cursor_navigate_off_top_edge_returns_null | 可證明 | 同 Row20 的共用 mutant 與敏感度證明，情境改為最上列再往上。 |
# | 23 | test_cursor_navigate_off_bottom_edge_returns_null | 可證明 | 同 Row20 的共用 mutant 與敏感度證明，情境改為最下列再往下。 |
# | 24 | test_reading_cursor_arbitrated_target_happens_in_process_not_input | D | 已直接讀過本測試本體（本檔:735-829）。斷言對象是原始碼文字本身：測試用 FileAccess.open("res://src/ui/battle/battle_screen.gd") 逐行讀取，搭配測試內部自訂的字串/RegEx 比對邏輯（非呼叫任何 production 類別方法），判斷兩個呼叫出現在哪個頂層函式體內。要證明這個掃描器抓得到違規，唯一有意義的做法是真的把該呼叫模式寫進 _input()/_unhandled_input()——但那正是修改 src/ui/battle/battle_screen.gd 這份正式程式碼本體，不在本測試檔案受限範圍內的合法注入手段（本輪任務本身亦明文禁止修改 src/）。屬「唯一有意義的注入點在受限範圍外」（D 類）。測試本體自己的 docstring（本檔:692-705）已自陳這是 test-standards.md 登記的乙類（唯讀原始碼文字斷言紀律）例外並列出兩項揭露義務——但乙類是檔案存取的許可證，不等於敏感度可證性的答案，兩者是分開的兩件事。 |
# | 25 | test_illegal_tile_reachable_by_directional_navigation_but_confirm_rejected | 可證明 | 已直接讀過 _apply_target_confirm_from_cursor_state() 本體（battle_screen.gd:1634-1650）：它讀游標目前目標格、解出站立單位，呼叫 _controller.select_target(unit.id)，失敗才試 select_second_target(unit.id)——本身不判斷該單位是否為合法目標，合法性判斷必然在更下層。已讀 CardPlaySession 類別宣告（card_play_session.gd:61-62，class_name CardPlaySession extends RefCounted，select_target/select_second_target/confirm 為一般 instance method、非 static）。本測試自己已示範「換掉 instance._controller._card_play_session 欄位」這個注入手法（與 Row17 相同技巧，RefCounted 直接欄位替換，不涉及 Node/_ready() 時機，連 Case A 疑慮都不適用）。注入：子類別 _MutantCardPlaySessionSkipsLegalityCheck extends CardPlaySession，覆寫 select_target(unit_id)，不檢查 legal_targets().has(unit_id) 就直接推進步驟。用這個 mutant session 取代 _card_play_session，重複本測試既有 Arrange（甲類卡、open_hand()/select_card()），呼叫 _apply_target_confirm_from_cursor_state() 對準敵方單位。test_sensitivity_proof_... 斷言 mutant session 的 step() 已前進（不再停在 SELECTING_TARGET），證明真測試 is_equal(SELECTING_TARGET) 斷言會抓到合法性檢查被繞過。⚠️ 未讀 CardPlaySession.select_target() 本體（card_play_session.gd:211 起，只讀了簽章與類別宣告），覆寫方案是整個蓋掉此方法、不依賴知道原始檢查寫在第幾行，但若該方法內部另肩負其他外部不可見的副作用，完全覆寫可能連帶蓋掉——此點未查證，留待下一步核實。 |
#
# 分佈統計（2026-09-23 盤點完成）：
#   可證明 13 條（#1-5、#17-23、#25）
#   A 類（static 純函式，無繼承鏈可覆寫）11 條（#6-16）
#   D 類（唯一有意義的注入點在受限範圍外——需修改 src/ 本身）1 條（#24）
#   A′ / B / C 類：0 條
#
# 本輪未查項目（逐項揭露，不因報告好看而省略）：
#   1. 未讀 board_view.gd 的 _ready() 本體（#1、#2 的注入方案刻意設計成不依賴其
#      內部實作，但沒有實際驗證過 CardTargetHighlightLayer 的節點樹是靜態定義在
#      .tscn 還是動態建構）。
#   2. 未讀 battle_screen.gd 中實際建構 _target_retarget_actor 並賦值
#      process_priority=-60 的那幾行（#18）——本輪依協調者指示不讀 battle_screen.gd。
#   3. 未讀 card_play_session.gd 的 select_target()/select_second_target()/
#      confirm() 本體邏輯（#25）——只讀了簽章與類別宣告（第 61-62、211、227、271
#      行），不知道合法性檢查具體寫在哪一行，也不知道這些方法是否有其他外部不可見
#      的副作用。
#   4. battle_controller.gd 六個轉發方法的閘門邏輯（#17 依據引用）本輪採用協調者
#      提供之摘錄，惟本任務更早回合已由本 agent 獨立讀過本體並核實一致（見 #17
#      依據欄的具體行號），不算純憑摘錄——列在此處是為了交代來源,不是保留疑慮。
#   5. 🔴 未實際跑過任何一個上表提議的 test_sensitivity_proof_*（本輪硬性禁止跑
#      引擎）——上述 13 條「可證明」判定全部是紙面設計，尚未經引擎驗證過 mutant
#      能否安全通過既有 _ready()、覆寫是否真的觸發預期行為。這是本次分類與實際
#      落地之間唯一保留的落差，下一棒落地時必須先跑一次確認,不能假設紙面設計一次
#      就對。
#   6. 未重新核對本檔既有「敏感度證明」區塊（現行第 960-971 行,涵蓋 #6-16）裡
#      「已手動核對(改壞、觀察斷言訊息、改回)」這句話本身是否真的做過——本輪只
#      指出它的格式已被 test-standards.md 2026-09-16 裁決明文淘汰(手動注入不留
#      版控痕跡),沒有查證那次手動核對是否確實發生過。
#
# 判不出來項目：無。25 條全部給出明確判定（13 可證明、11 類 A、1 類 D），沒有
# 需要留白或勉強塞類別的項目。
# ============================================================================
extends GdUnitTestSuite


const _BOARD_VIEW_SCENE_PATH: String = "res://src/ui/battle/BoardView.tscn"

## Story U-013 —— test_cancel_from_s2q_returns_to_s2p_not_s1 用的完整
## BattleScreen 場景路徑,同 tests/integration/ui/battle/battle_screen_card_play_wiring_test.gd
## 的既有慣例(真正 load()/instantiate() 並 add_child(),觸發真實 _ready())。
const _BATTLE_SCREEN_SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


func _fresh_board_view() -> BoardView:
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _fresh_instance() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_BATTLE_SCREEN_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


## 2026-09-23(第三批)—— 本檔第一支會真的呼叫 CursorStateHost.register_surface()
## 的測試(test_illegal_tile_reachable_by_directional_navigation_but_confirm_rejected)
## 需要這道清理,沿用 tests/integration/ui/battle/battle_screen_card_play_wiring_test.gd
## 的既有 after_test() 慣例逐字——不確定呼叫是否成功都無妨,unregister() 對「本來就沒
## 註冊」是 idempotent 的 UNREGISTERED_NOT_FOUND,不是錯誤。
func after_test() -> void:
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host == null:
		return
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


# ─── CardTargetHighlightLayer —— 場景節點存在、疊層順序正確 ─────────────────────


func test_card_target_highlight_layer_node_resolves_with_correct_type() -> void:
	# Arrange / Act
	var instance: BoardView = _fresh_board_view()
	var node: Node = instance.get_node("CardTargetHighlightLayer")

	# Assert
	assert_object(node).is_not_null()
	assert_bool(node is Node2D).is_true()


func test_card_target_highlight_layer_draws_above_pieces_and_below_stats() -> void:
	# Arrange — 同 tests/unit/ui/battle_screen_scene_test.gd 既有的疊層順序驗法：
	# Node2D 的繪製順序就是子節點順序，get_index() 越大越晚畫（越上層）
	var instance: BoardView = _fresh_board_view()

	# Act
	var pieces_index: int = instance.get_node("PiecesLayer").get_index()
	var attack_index: int = instance.get_node("AttackHighlightLayer").get_index()
	var card_target_index: int = instance.get_node("CardTargetHighlightLayer").get_index()
	var stats_index: int = instance.get_node("StatsLayer").get_index()

	# Assert — 必須畫在棋子之上（否則佔位格的目標標記會被棋子擋住，同
	# AttackHighlightLayer 的既有理由），但畫在血條/血量文字之下（HP 讀數不得被蓋住）
	assert_int(card_target_index).append_failure_message(
		"CardTargetHighlightLayer 必須畫在 PiecesLayer 之上，否則站著單位的合法/"
		+ "不合法標記會被棋子完全遮住"
	).is_greater(pieces_index)
	assert_int(card_target_index).is_greater(attack_index)
	assert_int(card_target_index).append_failure_message(
		"CardTargetHighlightLayer 必須畫在 StatsLayer 之下，否則會蓋住血條/血量文字"
	).is_less(stats_index)


# ─── set_card_target_highlights() —— 合法/不合法/清空 ──────────────────────────


func test_set_card_target_highlights_draws_one_outline_root_per_legal_cell() -> void:
	# Arrange
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("CardTargetHighlightLayer")

	# Act — 2 個合法格、0 個不合法格
	instance.set_card_target_highlights([Vector2i(1, 1), Vector2i(3, 2)], [])

	# Assert — 合法格只有外框（1 個根節點／格），沒有任何 Line2D（X 記號）
	assert_int(layer.get_child_count()).append_failure_message(
		"2 個合法格應各畫 1 個外框根節點，共 2 個，實得 %d" % layer.get_child_count()
	).is_equal(2)
	var line_count: int = 0
	for child: Node in layer.get_children():
		line_count += _count_line2d_descendants(child)
	assert_int(line_count).append_failure_message(
		"合法格不應出現任何 Line2D（那是不合法格才有的 X 記號）"
	).is_equal(0)


func test_set_card_target_highlights_illegal_cells_get_outline_plus_x_mark() -> void:
	# Arrange
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("CardTargetHighlightLayer")

	# Act — 1 個不合法格
	instance.set_card_target_highlights([], [Vector2i(2, 2)])

	# Assert — 不合法格得到「外框根節點 + X 記號根節點」兩個子節點，且 X 記號那個
	# 根節點底下恰有 2 條 Line2D（兩條對角線）——形狀可區分於合法格，不靠顏色
	assert_int(layer.get_child_count()).append_failure_message(
		"1 個不合法格應畫「外框 + X 記號」兩個根節點，實得 %d" % layer.get_child_count()
	).is_equal(2)
	var line_count: int = 0
	for child: Node in layer.get_children():
		line_count += _count_line2d_descendants(child)
	assert_int(line_count).append_failure_message(
		"不合法格應有恰好 2 條 Line2D 組成 X 記號，實得 %d" % line_count
	).is_equal(2)


func test_set_card_target_highlights_with_two_empty_arrays_clears_the_layer() -> void:
	# Arrange — 先畫一些東西
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("CardTargetHighlightLayer")
	instance.set_card_target_highlights([Vector2i(0, 0)], [Vector2i(1, 1)])
	assert_int(layer.get_child_count()).is_greater(0)

	# Act
	instance.set_card_target_highlights([], [])

	# Assert
	assert_int(layer.get_child_count()).is_equal(0)


func _count_line2d_descendants(node: Node) -> int:
	var count: int = 1 if node is Line2D else 0
	for child: Node in node.get_children():
		count += _count_line2d_descendants(child)
	return count


# ─── sort_targets_by_position() —— 先列後行（y 升冪、同列再 x 升冪）─────────────


func test_sort_targets_by_position_orders_row_major_regardless_of_input_order() -> void:
	# Arrange — 刻意打亂的輸入順序（既非 id 遞增、也非任何顯而易見的次序），
	# 座標本身分佈跨三列，同列內 x 不遞增
	var unit_ids: Array[int] = [50, 10, 30, 20, 40]
	var positions: Dictionary[int, Vector2i] = {
		50: Vector2i(5, 2),
		10: Vector2i(3, 0),
		30: Vector2i(1, 1),
		20: Vector2i(4, 1),
		40: Vector2i(0, 0),
	}

	# Act
	var result: Array[int] = BattleScreen.sort_targets_by_position(unit_ids, positions)

	# Assert — y=0 的 40 最先、y=1 的兩者依 x 遞增（30 於 x=1、20 於 x=4）、
	# y=2 的 50 最後
	assert_array(result).append_failure_message(
		"排序結果應為先列(y)後行(x)：%s" % [result]
	).is_equal([40, 10, 30, 20, 50])


func test_sort_targets_by_position_identical_across_repeated_runs_with_different_input_order() -> void:
	# Arrange — 同一組座標，兩次呼叫刻意給不同的輸入陣列順序，證明結果不受
	# 容器走訪序（本例即引數陣列本身的排列）影響 —— AC-U3「重跑一次順序完全相同」
	var positions: Dictionary[int, Vector2i] = {
		1: Vector2i(0, 2),
		2: Vector2i(0, 0),
		3: Vector2i(2, 0),
		4: Vector2i(1, 3),
		5: Vector2i(1, 1),
	}
	var order_a: Array[int] = [1, 2, 3, 4, 5]
	var order_b: Array[int] = [5, 4, 3, 2, 1]

	# Act
	var result_a: Array[int] = BattleScreen.sort_targets_by_position(order_a, positions)
	var result_b: Array[int] = BattleScreen.sort_targets_by_position(order_b, positions)

	# Assert
	assert_array(result_a).append_failure_message(
		"兩次呼叫（輸入順序不同）應得到完全相同的結果，實得 %s vs %s" % [result_a, result_b]
	).is_equal(result_b)
	# 手算覆核（座標為 Vector2i(x, y)）：id2(x=0,y=0)、id3(x=2,y=0) 同列(y=0)
	# 依 x 升冪為 [2,3]；id5(x=1,y=1) 次之；id1(x=0,y=2) 再次之；id4(x=1,y=3) 最後
	# —— 依序合併為 [2,3,5,1,4]。此行原寫 [2,1,5,4,3]（手算錯誤，已由本測試
	# 實際跑出的失敗抓到並更正——2026-09-22 實測 FAILED，見任務報告）。
	assert_array(result_a).is_equal([2, 3, 5, 1, 4])


func test_sort_targets_by_position_of_empty_array_is_empty() -> void:
	# Arrange / Act
	var result: Array[int] = BattleScreen.sort_targets_by_position([], {})

	# Assert
	assert_int(result.size()).is_equal(0)


# 2026-09-22 協調者指出:「若兩個目標的 (y, x) 完全相同,那就不是全序 —— 需要第三
# 個決定性鍵(例如 unit id)」。實測確認：本檔上面兩條測試用的資料其實沒有真正的
# (y, x) 撞值(上一條失敗是手算錯誤,不是排序鍵不足——見上一條測試內的更正註解),
# 但這條顧慮本身是對的、值得直接測:真實對局中兩個單位不可能同格(佔位不變量),
# 但排序函式收到的是呼叫端建構的 Dictionary,不該假設呼叫端一定守這條規則。
# sort_targets_by_position() 已加上 id 作為第三決定鍵，本測試直接命中那個分支。
func test_sort_targets_by_position_breaks_position_ties_by_ascending_id() -> void:
	# Arrange — id 30 與 id 10 座標完全相同(y=1, x=1),其餘鍵無法分出誰先誰後
	var unit_ids: Array[int] = [30, 10, 20]
	var positions: Dictionary[int, Vector2i] = {
		30: Vector2i(1, 1),
		10: Vector2i(1, 1),
		20: Vector2i(0, 0),
	}

	# Act
	var result: Array[int] = BattleScreen.sort_targets_by_position(unit_ids, positions)

	# Assert — 20 在 y=0 必然最先；10 與 30 座標相同,id 較小的 10 排在前面
	assert_array(result).append_failure_message(
		"座標相同的兩個目標應以 id 遞增排序，實得 %s" % [result]
	).is_equal([20, 10, 30])


# ─── next_target_id() —— 跳轉 + 循環包回 ───────────────────────────────────────


func test_jump_to_next_legal_target_cycles_in_row_major_order() -> void:
	# Arrange — AC-U3 逐字情境：我方 5 隻存活、連按「跳下一個合法目標」5 次
	var sorted_ids: Array[int] = [40, 10, 30, 20, 50]

	# Act — 從「尚未選取」（-1）開始，連續跳 5 次
	var visited: Array[int] = []
	var current: int = -1
	for _i in range(5):
		current = BattleScreen.next_target_id(current, sorted_ids, true)
		visited.append(current)

	# Assert — 依序停在 5 隻上，順序與 sorted_ids 完全一致
	assert_array(visited).append_failure_message(
		"連按 5 次應依序走完整個合法目標集合，實得 %s" % [visited]
	).is_equal(sorted_ids)


func test_jump_cycle_wraps_from_last_to_first() -> void:
	# Arrange
	var sorted_ids: Array[int] = [40, 10, 30, 20, 50]

	# Act — 第 6 次跳轉（已在最後一個，40/10/30/20/50 走完後再跳一次）
	var result: int = BattleScreen.next_target_id(50, sorted_ids, true)

	# Assert
	assert_int(result).append_failure_message(
		"第 6 次跳轉應回到第 1 個目標，實得 %d" % result
	).is_equal(40)


func test_jump_cycle_wraps_backward_from_first_to_last() -> void:
	# Arrange — Shift+Tab/LB（forward=false）從第一個往回跳，同一個循環的另一側
	var sorted_ids: Array[int] = [40, 10, 30, 20, 50]

	# Act
	var result: int = BattleScreen.next_target_id(40, sorted_ids, false)

	# Assert
	assert_int(result).is_equal(50)


func test_jump_order_identical_across_repeated_runs() -> void:
	# Arrange — AC-U3 後半：「重跑一次順序完全相同」。跑兩輪完整的 5 次跳轉，
	# 兩輪的輸入（sorted_ids）獨立建構（不是同一個物件參照），驗證輸出序列相等
	var sorted_ids_run_1: Array[int] = [40, 10, 30, 20, 50]
	var sorted_ids_run_2: Array[int] = [40, 10, 30, 20, 50]

	# Act
	var visited_1: Array[int] = []
	var current_1: int = -1
	for _i in range(6):
		current_1 = BattleScreen.next_target_id(current_1, sorted_ids_run_1, true)
		visited_1.append(current_1)

	var visited_2: Array[int] = []
	var current_2: int = -1
	for _i in range(6):
		current_2 = BattleScreen.next_target_id(current_2, sorted_ids_run_2, true)
		visited_2.append(current_2)

	# Assert
	assert_array(visited_1).append_failure_message(
		"重跑一次應得到完全相同的走訪順序，實得 %s vs %s" % [visited_1, visited_2]
	).is_equal(visited_2)
	assert_array(visited_1).is_equal([40, 10, 30, 20, 50, 40])


func test_jump_with_current_id_not_in_set_starts_from_first_going_forward() -> void:
	# Arrange — 游標尚未落在任何合法目標上（例如剛選定卡片、還沒按過跳轉鍵）
	var sorted_ids: Array[int] = [40, 10, 30, 20, 50]

	# Act
	var result: int = BattleScreen.next_target_id(-1, sorted_ids, true)

	# Assert
	assert_int(result).is_equal(40)


func test_jump_with_current_id_not_in_set_starts_from_last_going_backward() -> void:
	# Arrange
	var sorted_ids: Array[int] = [40, 10, 30, 20, 50]

	# Act
	var result: int = BattleScreen.next_target_id(-1, sorted_ids, false)

	# Assert
	assert_int(result).is_equal(50)


func test_jump_on_empty_set_returns_negative_one() -> void:
	# Arrange / Act
	var result: int = BattleScreen.next_target_id(-1, [], true)

	# Assert
	assert_int(result).is_equal(-1)


# ─── cancel() 從 S2q 退回 S2p,不是 S1(既有 cancel() 行為的整合驗證)──────────


## Story U-013 Implementation Note #6(逐字):「取消行為:Esc/B...在 S2 呼叫
## session.cancel() 退回 S1;在 S2q 呼叫 session.cancel() 退回 S2p(重選第二
## 人),不是直接跳回 S1——這是 card_play_session.gd 既有 cancel() 的既定行為,
## UI 只需忠實呼叫,不要自己另寫一套『退兩步』的邏輯」。
##
## 本測試驗的是 BattleScreen 這一層的分派邏輯
## (_handle_target_selection_cancel_transition()):它讀 BattleController.cancel()
## 呼叫之後 legal_targets() 的回傳值決定回到 S2p 還是 S1——不是重新驗證
## CardPlaySession.cancel() 本身(那是「本 story 必須讀而非重寫的既有邏輯層」,
## 已交付,見 story 文件該節)。
##
## 🔴 [b]為什麼不能用 _fresh_instance() 真實走「開手牌 -> 選卡」UI 流程走到
## S2q[/b]:battle_screen.gd 的 _ready() 用 CardDeck.new(cards, rng=null)——
## 真實、未指定種子的 RandomNumberGenerator(見該行自己的 doc comment:「rng=null
## 這裡意味著生產環境、時間種子洗牌」)——從 vs01_cards.txt 的 8 張卡隨機抽 5 張
## 開局手牌。其中只有 2 張是 PERMANENT_AFFINITY_WRITE(丙類,card_07/card_08),
## 兩張都沒被抽進手牌的機率是 C(6,5)/C(8,5) = 6/56 ≈ 10.7%,並非零——這與
## .claude/rules/test-standards.md 的 Determinism 規則(「必須每次執行結果相同」)
## 直接牴觸,寫了也只是一支偶爾紅、偶爾綠的測試,而非本測試要證明的行為本身
## 不成立。
##
## 改用一副「刻意只有一張丙類卡」的 CardDeck,取代 _controller 內部
## BattleController 原本建構的 CardPlaySession——池只有 1 張牌時
## CardDeck._draw_one_into_hand() 呼叫的 _rng.randi_range(0, 0) 恆為索引 0,
## 抽到哪張與 RNG 種子無關,不需要固定種子也是決定性的(不是「机率很低所以
## 可以接受」,是「結構上不存在隨機分支」)。卡片本身用既有工廠函式
## Card.new_permanent_affinity_write()(in-test 常數,不讀 assets/data/ 任何
## 檔案)構造;好感度連結同理直接建構 AffinityLink 物件,不讀
## vs01_affinity_links.txt——PermanentAffinityWriteRules.legal_pairs() 只看
## AffinityLink.unit_a/unit_b 是否存活,不看 Card 自己的
## affinity_character_a/b(vs01_cards.txt 檔頭原話:「這兩欄僅供牌面敘事」)。
## 單位 3/4(丙/丁)直接沿用 _fresh_instance() 建出的真實 _state——這兩個是
## vs01_roster.txt 真實存在的 PLAYER 單位,開局必然存活,不需要另建一份假的
## BattleState。
##
## 只替換 instance._controller._card_play_session 這一個欄位,不重建整個
## BattleController。
##
## 🔴 2026-09-23 更正(協調者覆核,讀過 battle_controller.gd 本體,不是只 grep
## 簽章):本段原文寫「open_hand()/select_card()/legal_targets()/select_target()/
## cancel() 皆只轉發給 _card_play_session」——不精確,這句話本身當時也只是沿用
## 上一棒沒有附物證的宣稱,轉一手變成「已確認」。實測本體(battle_controller.gd
## 第 363~479 行):
## - open_hand()/select_card()/legal_targets():轉發前先擋
##   `_phase != Phase.PLAYER_INPUT`(legal_targets() 不符時回傳空陣列,其餘回傳
##   false),沒有 has_pending_discard() 這道閘。
## - select_target()/select_second_target()/confirm()/cancel():除了同一道
##   phase 閘,還多擋 `_state.has_pending_discard()`。
## 「換掉 _card_play_session 就等於換掉這些呼叫的行為」因此只在「真實 _state
## 當下處於 PLAYER_INPUT 且沒有待棄牌」時成立——這是本測試的隱含前提,不是保證。
## 本測試能過,代表 _fresh_instance() 剛建好的開局狀態確實滿足這兩個閘門
## (預設 phase 即 PLAYER_INPUT,開局也不會有待棄牌),但下一個沿用本手法的
## 測試如果在別的時機點(例如已經推進過回合、或有 forced-discard 情境)做同樣
## 的替換,兩道閘門有可能擋下轉發呼叫——先用 assert_bool(...).is_true() 的
## PRECONDITION 斷言確認每一步真的成功(本檔以下正是這樣寫的),不要假設換了
## _card_play_session 就保證後續呼叫一定通過。
## 不需要另外重建 _state/_order/TurnOrder/phi 等其餘依賴。
func test_cancel_from_s2q_returns_to_s2p_not_s1() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()

	var card: Card = Card.new_permanent_affinity_write("test_card_c3c4", 3, 4, -2)
	var cards: Array[Card] = [card]
	var deck: CardDeck = CardDeck.new(cards)
	deck.deal_opening_hand()

	var link: AffinityLink = AffinityLink.new()
	link.unit_a = 3
	link.unit_b = 4
	link.polarity = AffinityLink.Polarity.NEGATIVE
	link.amp = 1
	var links: Array[AffinityLink] = [link]

	var session: CardPlaySession = CardPlaySession.new(
		deck, instance._state, links, NullAffinityWritePort.new()
	)
	instance._controller._card_play_session = session

	assert_bool(instance._controller.open_hand()).append_failure_message(
		"PRECONDITION: open_hand() 失敗——夾具本身有問題,不是本測試要驗的行為"
	).is_true()
	assert_bool(instance._controller.select_card(card)).append_failure_message(
		"PRECONDITION: select_card() 失敗——夾具的 CardDeck/CardPlaySession 沒接對"
	).is_true()
	assert_array(instance._controller.legal_targets()).append_failure_message(
		"PRECONDITION: S2p 合法目標應為 [3, 4](丙丁配對),實得 %s"
		% [instance._controller.legal_targets()]
	).is_equal([3, 4])
	assert_bool(instance._controller.select_target(3)).append_failure_message(
		"PRECONDITION: select_target(3) 失敗——無法進入 S2q"
	).is_true()
	assert_int(session.step()).append_failure_message(
		"PRECONDITION: 選完第一個目標後應進入 SELECTING_TARGET_B(S2q = %d),實得 %d"
		% [CardPlaySession.Step.SELECTING_TARGET_B, session.step()]
	).is_equal(CardPlaySession.Step.SELECTING_TARGET_B)

	# _confirm_selected_card() 在真實流程裡會把這兩個呈現層欄位擺到這個狀態——
	# 這裡直接設定,避免重新走一次 hand_bar 游標導覽 UI(與本測試無關)。
	instance._card_selecting_from_hand = false
	instance._card_selecting_target = true

	# Act — 複製 _input() 那個分支的真實分派順序(battle_screen.gd 的
	# _card_selecting_target 分支,battle_cancel 那一支):先呼叫
	# _controller.cancel(),再呼叫 _handle_target_selection_cancel_transition()
	# 讀 cancel() 之後的 legal_targets() 決定去處。
	assert_bool(instance._controller.cancel()).append_failure_message(
		"PRECONDITION: BattleController.cancel() 本身被閘門擋下(phase 不是 "
		+ "PLAYER_INPUT,或有待處理的強制棄牌)——與本測試要驗的行為無關"
	).is_true()
	instance._handle_target_selection_cancel_transition()

	# Assert
	assert_int(session.step()).append_failure_message(
		"cancel() 應該讓 CardPlaySession 退回 SELECTING_TARGET(S2p = %d),實得 %d"
		% [CardPlaySession.Step.SELECTING_TARGET, session.step()]
	).is_equal(CardPlaySession.Step.SELECTING_TARGET)
	assert_bool(instance._card_selecting_target).append_failure_message(
		"S2q -> S2p 仍在目標選取中,_card_selecting_target 不應該變成 false"
	).is_true()
	assert_bool(instance._card_selecting_from_hand).append_failure_message(
		"S2q -> S2p 不是退回 S1,_card_selecting_from_hand 不應該變成 true——"
		+ "這正是本測試名字要釘死的那個區別(不是 S1)"
	).is_false()
	assert_array(instance._controller.legal_targets()).append_failure_message(
		"退回 S2p 後合法目標應重新是 [3, 4](丙丁重選第二人),實得 %s"
		% [instance._controller.legal_targets()]
	).is_equal([3, 4])


# ─── _TargetRetargetActor.process_priority —— ADR-0005 機制六②的開區間義務 ──────
#
# battle_screen.gd 的 doc comment 自己寫明:角色② 需要 process_priority 嚴格大於 -100、
# 嚴格小於 -25,而角色⑥ 需要正好 100 —— 單一節點無法同時滿足,故拆出這顆薄子節點。
# 本測試釘死的是那個「開區間」契約,不只是 -60 這個當下值:日後有人把 -60 改成 -10
# 或 -200,這裡要變紅。


func test_target_retarget_actor_priority_falls_inside_the_mandated_open_interval() -> void:
	# Arrange / Act
	var instance: BattleScreen = _fresh_instance()
	var actor: Node = instance._target_retarget_actor

	# Assert
	assert_object(actor).append_failure_message(
		"BattleScreen._ready() 應該已經建構並掛上 _target_retarget_actor"
	).is_not_null()
	var priority: int = actor.process_priority
	assert_int(priority).append_failure_message(
		"角色②的 process_priority 必須嚴格大於 -100(ADR-0005 R5-2 開區間),實得 %d"
		% priority
	).is_greater(-100)
	assert_int(priority).append_failure_message(
		(
			"角色②的 process_priority 必須嚴格小於 -25(ADR-0005 R5-2 開區間,避免撞進角色⑥"
			+ "的 100 或其他保留區間),實得 %d"
		) % priority
	).is_less(-25)


# ─── cursor_navigate() —— 純函式邊界行為(只查 BoardCoords.is_in_bounds()）───────
#
# 不需要場景狀態、不需要 CursorStateHost 註冊——cursor_navigate() 本身只用
# CursorTypes.decode_tile() 解出來源格、加上方向、再用 BoardCoords.is_in_bounds()
# 判斷落點是否還在棋盤內。board_coords.gd 明文:BOARD_COLS=13、BOARD_ROWS=6。


func test_cursor_navigate_moves_within_bounds_returns_encoded_tile_id() -> void:
	# Arrange — 從 (5, 2) 往右移一格,落點 (6, 2) 仍在棋盤內
	var instance: BattleScreen = _fresh_instance()
	var from_id: int = CursorTypes.encode_tile(Vector2i(5, 2), BoardCoords.BOARD_COLS)

	# Act
	var result: Variant = instance.cursor_navigate(from_id, Vector2i(1, 0))

	# Assert
	var expected_id: int = CursorTypes.encode_tile(Vector2i(6, 2), BoardCoords.BOARD_COLS)
	assert_int(result).append_failure_message(
		"從 (5,2) 往右一格應落在 (6,2),編碼後應為 %d,實得 %s" % [expected_id, result]
	).is_equal(expected_id)


func test_cursor_navigate_off_left_edge_returns_null() -> void:
	# Arrange — 從最左欄 (0, 0) 往左移一格,x 會變成 -1,越界
	var instance: BattleScreen = _fresh_instance()
	var from_id: int = CursorTypes.encode_tile(Vector2i(0, 0), BoardCoords.BOARD_COLS)

	# Act
	var result: Variant = instance.cursor_navigate(from_id, Vector2i(-1, 0))

	# Assert
	assert_object(result).append_failure_message(
		"從最左欄再往左應該越界,cursor_navigate() 應回傳 null,實得 %s" % [result]
	).is_null()


func test_cursor_navigate_off_right_edge_returns_null() -> void:
	# Arrange — 從最右欄 (BOARD_COLS-1, 0) 往右移一格,x 會等於 BOARD_COLS,越界
	var instance: BattleScreen = _fresh_instance()
	var from_id: int = CursorTypes.encode_tile(
		Vector2i(BoardCoords.BOARD_COLS - 1, 0), BoardCoords.BOARD_COLS
	)

	# Act
	var result: Variant = instance.cursor_navigate(from_id, Vector2i(1, 0))

	# Assert
	assert_object(result).append_failure_message(
		"從最右欄再往右應該越界,cursor_navigate() 應回傳 null,實得 %s" % [result]
	).is_null()


func test_cursor_navigate_off_top_edge_returns_null() -> void:
	# Arrange — 從最上列 (0, 0) 往上移一格,y 會變成 -1,越界
	var instance: BattleScreen = _fresh_instance()
	var from_id: int = CursorTypes.encode_tile(Vector2i(0, 0), BoardCoords.BOARD_COLS)

	# Act
	var result: Variant = instance.cursor_navigate(from_id, Vector2i(0, -1))

	# Assert
	assert_object(result).append_failure_message(
		"從最上列再往上應該越界,cursor_navigate() 應回傳 null,實得 %s" % [result]
	).is_null()


func test_cursor_navigate_off_bottom_edge_returns_null() -> void:
	# Arrange — 從最下列 (0, BOARD_ROWS-1) 往下移一格,y 會等於 BOARD_ROWS,越界
	var instance: BattleScreen = _fresh_instance()
	var from_id: int = CursorTypes.encode_tile(
		Vector2i(0, BoardCoords.BOARD_ROWS - 1), BoardCoords.BOARD_COLS
	)

	# Act
	var result: Variant = instance.cursor_navigate(from_id, Vector2i(0, 1))

	# Assert
	assert_object(result).append_failure_message(
		"從最下列再往下應該越界,cursor_navigate() 應回傳 null,實得 %s" % [result]
	).is_null()


# ─── _input()/_process() 讀取時機 —— Implementation Note #1 的原始碼紀律掃描 ────
#
# Story U-013 Implementation Note #1 逐字:「打牌確認若要讀『游標系統裁定後的狀態』
# (當前選了哪張卡、哪個目標、哪個裝置持權威),該讀取不得放在按鍵處理(_input /
# _unhandled_input)裡,必須放在 _process(priority=100)」。
#
# 本測試是 .claude/rules/test-standards.md 登記的兩個唯讀例外之【乙類】
# (唯讀 src/**/*.gd 的文字,斷言原始碼紀律)——依該規則附帶的兩項義務逐條交代:
#
# 1. 為什麼不能用依賴注入/執行期檢查取代:這個義務本身就是「某段呼叫寫在哪個
#    函式體內」這種文字層級的事實,不是任何物件的執行期行為——CursorStateHost
#    的 get_current_target()/is_current_target_valid() 兩個方法本身完全正確
#    (有自己的單元測試),要防的是「呼叫它們的那一行,錯誤地被寫進 _input()」
#    這種撰寫錯誤,只有掃描原始碼文字能斷言「這個模式不存在於這裡」,執行期
#    測試斷言不出「這行程式碼寫在哪個函式體內」。
# 2. 掃描範圍不等於窮盡性(逐條揭露,見下方 docstring)。
#
# 只掃 res://src/ui/battle/battle_screen.gd 這一個檔案,刻意比
# affinity_link_no_direct_return_test.gd 的全庫兩根目錄掃描窄——因為 Implementation
# Note #1 這條義務是這一個檔案自己的內部呼叫時機紀律(quoted verbatim,只針對這個
# 檔案的 _input()/_process() 邊界),不是像「某個 parser 不能被錯誤呼叫」那樣可能
# 出現在全專案任何呼叫端的通用反模式——沒有理由掃到這個檔案以外。


## 追蹤「目前在哪個頂層 func 定義內」的逐行掃描,同
## tests/unit/gameplay/affinity/affinity_link_no_direct_return_test.gd 的既有慣例,
## 但這裡追蹤的是函式【名稱】而非回傳型別。
##
## [b]已知盲點(揭露而非默默略過)[/b]:
## - 只認column 0(完全沒有縮排)的 `^func ` 開頭當作「頂層函式」邊界——這正是
##   用來排除 battle_screen.gd 內巢狀 `class _TargetRetargetActor` 的
##   `func _process(_delta: float) -> void:`(該行縮排一個 tab,不會被這個
##   pattern 命中,不會被誤判成頂層 `_process()`)。前提是本檔案內所有頂層函式
##   簽章皆為單行、無縮排——本檔實測確認battle_screen.gd 的 _input()/_process()/
##   _apply_target_confirm_from_cursor_state() 三者皆符合這個前提
##   (`^func _input|^func _unhandled_input|^func _process|
##   ^func _apply_target_confirm_from_cursor_state` 逐行 grep 只各命中一次,行號見
##   本測試自己的失敗訊息)。
## - 若函式體內含有巢狀 lambda(`func(...):`),lambda 內容仍會被算進外層函式,
##   而非獨立追蹤——本檔案這三個函式目前皆無巢狀 lambda,但掃描器本身不驗證這一點。
## - 字串常值/註解內若恰好出現這些呼叫的文字(例如描述這個規則的註解本身),
##   已用「trimmed 開頭是 # 就整行跳過」擋掉——但同一行程式碼後面接的行內
##   `#` 註解不會被剝離,理論上可能誤判,本檔尚未實際遇過這個情況。
## - 這是文字掃描,不執行、不進場景樹——它只能證明「這個文字模式今天不在這裡」,
##   不能證明 CursorStateHost 兩個方法「不可能」被繞道呼叫(例如透過
##   Callable/字串方法名/反射),這些管道完全在掃描視野之外。
func test_reading_cursor_arbitrated_target_happens_in_process_not_input() -> void:
	# Arrange
	const _SCAN_PATH: String = "res://src/ui/battle/battle_screen.gd"
	const _FORBIDDEN_READ_SUBSTRINGS: Array[String] = [
		"CursorStateHost.get_current_target(",
		"CursorStateHost.is_current_target_valid(",
	]
	const _APPLY_CONFIRM_CALL_SUBSTRING: String = "_apply_target_confirm_from_cursor_state("
	const _FORBIDDEN_FUNCS: Array[String] = ["_input", "_unhandled_input"]
	const _REQUIRED_READ_FUNC: String = "_apply_target_confirm_from_cursor_state"
	const _REQUIRED_CALL_SITE_FUNC: String = "_process"

	var signature_regex := RegEx.new()
	var compile_error: Error = signature_regex.compile("^func\\s+(\\w+)\\s*\\(")
	assert_int(compile_error).append_failure_message(
		"本測試自己的函式簽章 RegEx 編譯失敗(error %s)——掃描本身壞了,與受測程式碼無關,先修 pattern。"
		% error_string(compile_error)
	).is_equal(OK)

	var f: FileAccess = FileAccess.open(_SCAN_PATH, FileAccess.READ)
	assert_object(f).append_failure_message(
		"無法開啟 %s——檔案路徑是否變動了?" % _SCAN_PATH
	).is_not_null()

	# Act
	var read_in_forbidden_func_violations: Array = []
	var call_site_in_forbidden_func_violations: Array = []
	var found_read_in_required_func: bool = false
	var found_call_site_in_process: bool = false
	var current_func: String = ""
	var line_number: int = 0
	while not f.eof_reached():
		var raw_line: String = f.get_line()
		line_number += 1
		var trimmed: String = raw_line.strip_edges()
		if trimmed.begins_with("#"):
			continue

		var signature_match: RegExMatch = signature_regex.search(raw_line)
		if signature_match != null:
			current_func = signature_match.get_string(1)
			continue

		if current_func.is_empty():
			continue

		var has_forbidden_read: bool = false
		for banned: String in _FORBIDDEN_READ_SUBSTRINGS:
			if trimmed.contains(banned):
				has_forbidden_read = true
				break
		var has_apply_confirm_call: bool = trimmed.contains(_APPLY_CONFIRM_CALL_SUBSTRING)

		if _FORBIDDEN_FUNCS.has(current_func):
			if has_forbidden_read:
				read_in_forbidden_func_violations.append(
					"%s:%d (func %s): %s" % [_SCAN_PATH, line_number, current_func, trimmed]
				)
			if has_apply_confirm_call:
				call_site_in_forbidden_func_violations.append(
					"%s:%d (func %s): %s" % [_SCAN_PATH, line_number, current_func, trimmed]
				)
		if current_func == _REQUIRED_READ_FUNC and has_forbidden_read:
			found_read_in_required_func = true
		if current_func == _REQUIRED_CALL_SITE_FUNC and has_apply_confirm_call:
			found_call_site_in_process = true

	# Assert
	assert_int(read_in_forbidden_func_violations.size()).append_failure_message(
		(
			"Implementation Note #1 違反:_input()/_unhandled_input() 內不得直接讀取 "
			+ "CursorStateHost.get_current_target()/is_current_target_valid()——那是上一幀的值。"
			+ "命中:\n%s"
		) % "\n".join(read_in_forbidden_func_violations)
	).is_equal(0)
	assert_int(call_site_in_forbidden_func_violations.size()).append_failure_message(
		(
			"_apply_target_confirm_from_cursor_state() 不應該被 _input()/_unhandled_input() "
			+ "直接呼叫——它必須只被 _process() 呼叫,讀取才會落在 priority=100 那一幀。命中:\n%s"
		) % "\n".join(call_site_in_forbidden_func_violations)
	).is_equal(0)
	assert_bool(found_read_in_required_func).append_failure_message(
		(
			"_apply_target_confirm_from_cursor_state() 內應該要讀取 "
			+ "CursorStateHost.get_current_target()/is_current_target_valid()"
			+ "——一次都沒掃到,表示這段讀取邏輯被搬走了或函式被改名/刪除,"
			+ "本測試的正向斷言就是為了在那種情況下當場變紅,而不是只在「多了違規」時變紅。"
		)
	).is_true()
	assert_bool(found_call_site_in_process).append_failure_message(
		(
			"_process() 內應該要呼叫 _apply_target_confirm_from_cursor_state()"
			+ "——一次都沒掃到,表示讀取時機的呼叫路徑被改掉了。"
		)
	).is_true()


# ─── 不合法格可達,但確認被拒(Implementation Note #3)──────────────────────────
#
# Story U-013 Implementation Note #3 逐字:「不合法的格子仍然走得進去,方向鍵/十字鍵
# 的逐格導覽不因為某格不合法就跳過它;只有確認會被拒絕」。
#
# 用甲類卡(Card.new_temporary_stat_modifier)而非前一位原設計的丙類配對卡——甲類的
# legal_targets() 就是「全體存活我方單位」(card_play_session.gd:196-197),敵方單位
# 天生不合法,不需要另外構造「兩個丙類單位以外」的敵方情境,場景更直接。
#
# 🔴 CursorStateHost.set_target() 要求目標的 surface 必須已經被註冊
# (cursor_state.gd _validate_target_writable():`_registry.get_surface(target.surface)
# == null` 時回傳 SURFACE_NOT_REGISTERED,寫入不生效)——這一步前一位的原始設計沒提到,
# 是讀碼後補上的:必須在 Arrange 階段手動呼叫
# CursorStateHost.register_surface(BOARD_TILE, instance),不能只靠換掉
# _card_play_session。清理見上方 after_test()。


func test_illegal_tile_reachable_by_directional_navigation_but_confirm_rejected() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()

	var card: Card = Card.new_temporary_stat_modifier("test_card_atk_buff", 1, 0, 1)
	var cards: Array[Card] = [card]
	var deck: CardDeck = CardDeck.new(cards)
	deck.deal_opening_hand()

	var links: Array[AffinityLink] = []
	var session: CardPlaySession = CardPlaySession.new(
		deck, instance._state, links, NullAffinityWritePort.new()
	)
	instance._controller._card_play_session = session

	assert_bool(instance._controller.open_hand()).append_failure_message(
		"PRECONDITION: open_hand() 失敗——夾具本身有問題,不是本測試要驗的行為"
	).is_true()
	assert_bool(instance._controller.select_card(card)).append_failure_message(
		"PRECONDITION: select_card() 失敗——夾具的 CardDeck/CardPlaySession 沒接對"
	).is_true()
	assert_int(session.step()).append_failure_message(
		"PRECONDITION: 選完甲類卡後應進入 SELECTING_TARGET(S2 = %d),實得 %d"
		% [CardPlaySession.Step.SELECTING_TARGET, session.step()]
	).is_equal(CardPlaySession.Step.SELECTING_TARGET)

	var enemy_units: Array[Unit] = instance._state.units_of(Unit.Faction.ENEMY)
	assert_int(enemy_units.size()).append_failure_message(
		"PRECONDITION: vs01_roster.txt 應該至少有 1 個敵方單位,實得 0——資料檔變動了?"
	).is_greater(0)
	var enemy_unit: Unit = enemy_units[0]
	var enemy_cell: Vector2i = instance._state.position_of(enemy_unit.id)
	var legal_targets_before: Array[int] = instance._controller.legal_targets()
	assert_bool(legal_targets_before.has(enemy_unit.id)).append_failure_message(
		(
			"PRECONDITION: 敵方單位 id=%d 不應該出現在甲類卡的合法目標集合 %s 裡——"
			+ "若出現,代表這個情境本來就不是『不合法目標』,後面的拒絕斷言就測不到東西"
		) % [enemy_unit.id, legal_targets_before]
	).is_false()

	# _confirm_selected_card() 在真實流程裡會把這兩個呈現層欄位擺到這個狀態——
	# 這裡直接設定,避免重新走一次 hand_bar 游標導覽 UI(與本測試無關)。
	instance._card_selecting_from_hand = false
	instance._card_selecting_target = true

	# 找敵方單位格左右任一側的合法鄰格,證明「方向鍵逐格導覽走得到不合法格」
	# (Implementation Note #3 的前半句)——cursor_navigate() 只查 BoardCoords.is_in_bounds(),
	# 不查目標格站的單位是否合法。
	var neighbor_cell: Vector2i = enemy_cell + Vector2i(-1, 0)
	var direction: Vector2i = Vector2i(1, 0)
	if not BoardCoords.is_in_bounds(neighbor_cell):
		neighbor_cell = enemy_cell + Vector2i(1, 0)
		direction = Vector2i(-1, 0)
	assert_bool(BoardCoords.is_in_bounds(neighbor_cell)).append_failure_message(
		"PRECONDITION: 敵方單位格 %s 左右兩側都不在棋盤內——棋盤是否只有 1 欄寬?"
		% [enemy_cell]
	).is_true()

	var from_id: int = CursorTypes.encode_tile(neighbor_cell, BoardCoords.BOARD_COLS)
	var navigate_result: Variant = instance.cursor_navigate(from_id, direction)
	var enemy_tile_id: int = CursorTypes.encode_tile(enemy_cell, BoardCoords.BOARD_COLS)
	assert_int(navigate_result).append_failure_message(
		(
			"cursor_navigate() 應該能移動到敵方單位所在格 %s(不合法格仍然走得到,"
			+ "Implementation Note #3),實得 %s,預期 %d"
		) % [enemy_cell, navigate_result, enemy_tile_id]
	).is_equal(enemy_tile_id)

	var register_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(
		CursorTypes.SurfaceType.BOARD_TILE, instance
	)
	assert_int(register_result).append_failure_message(
		(
			"PRECONDITION: CursorStateHost.register_surface(BOARD_TILE) 沒有回傳 REGISTERED"
			+ "(實得 %s)——是不是上一支測試沒清乾淨,或本次呼叫本身有誤?"
		) % register_result
	).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)

	var set_result: CursorState.SetTargetResult = CursorStateHost.set_target(
		CursorTarget.make(CursorTypes.SurfaceType.BOARD_TILE, enemy_tile_id)
	)
	assert_int(set_result).append_failure_message(
		(
			"PRECONDITION: CursorStateHost.set_target() 沒有回傳 APPLIED(實得 %s)——"
			+ "surface 是否真的註冊成功?"
		) % set_result
	).is_equal(CursorState.SetTargetResult.APPLIED)

	# Act — 複製 _process() 那個分支的真實呼叫(battle_confirm 按下時排入的
	# pending flag,由 _process() 消費——見 Implementation Note #1)。這裡直接呼叫
	# 被消費的那個方法本身,略過 _pending_target_confirm_press 這層佇列(佇列本身
	# 已由 test_reading_cursor_arbitrated_target_happens_in_process_not_input
	# 驗過只被 _process() 呼叫,不是本測試要重驗的行為)。
	instance._apply_target_confirm_from_cursor_state()

	# Assert — 確認被拒絕,session 停在原地,沒有前進
	assert_int(session.step()).append_failure_message(
		(
			"敵方單位是甲類卡的不合法目標,確認應該被拒絕、session 停在 SELECTING_TARGET"
			+ "(S2 = %d),實得 %d——是不是合法性檢查被繞過了?"
		) % [CardPlaySession.Step.SELECTING_TARGET, session.step()]
	).is_equal(CardPlaySession.Step.SELECTING_TARGET)
	assert_bool(instance._card_selecting_target).append_failure_message(
		"確認被拒絕後仍應停留在目標選取中,_card_selecting_target 不應該變成 false"
	).is_true()
	assert_array(instance._controller.legal_targets()).append_failure_message(
		"確認被拒絕不應該改變合法目標集合,實得 %s,預期與拒絕前相同 %s"
		% [instance._controller.legal_targets(), legal_targets_before]
	).is_equal(legal_targets_before)


# ─── 敏感度證明 ────────────────────────────────────────────────────────────────
#
# .claude/rules/test-standards.md「已知證明不了的五類」之 A 類：受測對象是
# static 純函式，沒有繼承鏈可覆寫子類別注入突變 —— 與
# tests/unit/ui/battle_screen_hand_bar_wiring_test.gd 對其餘 BattleScreen 純函式
# 的既有登記方式相同。上面每一條斷言的都是「給定輸入 -> 唯一可能的正確輸出」，
# 手動改壞 sort_targets_by_position()/next_target_id() 任何一步都會讓對應斷言
# 當場變紅（例如把 `pos_a.y < pos_b.y` 改成 `>` 會讓
# test_sort_targets_by_position_orders_row_major_regardless_of_input_order 與
# test_sort_targets_by_position_identical_across_repeated_runs_with_different_input_order
# 兩條同時變紅）——這是本檔對「哪一條測試會因為我改錯而變紅」的具體回答，
# 已手動核對（改壞、觀察斷言訊息、改回），不是宣稱。
#
# 🔴 2026-09-23 協調者更正(記帳,非新裁決):上面最後一句的【格式】已於
# 2026-09-16 管理者裁決明文淘汰。該裁決逐字:「手動注入(改壞 → 跑 → 改回)
# 已淘汰,理由是它在版本庫裡不留任何痕跡。」——亦即「不是宣稱」這個自我聲明,
# 正好就是該裁決說的「無法查證,只能選擇相信」。
#
# ⚠️ 被淘汰的是【那句話的形式】,不是上面的 A 類判定。A 類(static 純函式、
# 無繼承鏈可覆寫)本身正確,且經 2026-09-23 逐條盤點覆核維持不變
# (battle_screen.gd:947 / :975 兩者皆為 static func,已實查)。
#
# 📌 原文保留不刪,因為刪掉會讓下一個人看不出這裡曾經有過一個已作廢的宣稱。
