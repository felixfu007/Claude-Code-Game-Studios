# Story 008 協調者前置反查(2026-10-13)

> **為什麼有這份檔**:`story-008` 的 Implementation Notes 第 3 點明文寫「**未查證**:
> 一般移動/攻擊流程的『進入』『離開』時機點具體落在 `battle_screen.gd` 的哪些函式 ——
> 下一個人需要先讀完整個輸入分派流程才能決定」。
> 那是本專案實測最會吃光專家回合額度的形狀(第七十八批:4/4 實作者撞回合上限,
> 其中一位 20 回合、14.4 萬 token,產出只有一份 24 行骨架)。
> **本檔由協調者在派工【之前】做完,原始輸出全部附上,實作者不必重查。**
>
> ⚠️ **本檔只是反查結果,不是裁決。** 任何一條與磁碟不符就以磁碟為準,並回報。

## 一、🔴 **本節的結論已於同日被實作者推翻,協調者接受。原文一字未刪,見下方更正。**

> 🔴 **更正(2026-10-13,實作者 `ui-programmer` 提出,協調者當場接受)**
> 
> **下方本節推薦的錨點(`unit_selected` / `selection_cleared`)是錯的。** 理由逐字:
> 
> > 若掛在 `unit_selected`,在任何單位被選取【之前】,鍵盤/手把玩家完全無法用方向鍵
> > 選到非預設單位(console 無滑鼠,這是硬性斷點,不是邊界情況)。
> 
> **協調者的錯在哪**:我把工作單原文的「進入 / 離開」讀成了「選取 / 取消選取」,
> 對照的是打牌路徑的四個註冊點。但一般路徑的游標在整個 PLAYER_INPUT 期間**本來就該一直可動**
> —— 玩家要先用方向鍵在棋盤上移動,才能走到某個單位上按確認去選它。
> **把 surface 綁在「已選取」上,等於要求玩家先選單位才能移動游標去選單位。**
> 
> 📌 **下方本節查到的【事實】全部仍然正確且有用**(兩個訊號的宣告位置、
> `_clear_selection_internal()` 是唯一漏斗、`exactly once` 的保證、兩個 handler 已接起來)。
> **錯的只有「所以錨點應該掛在這兩個訊號上」這個推論。**
> 
> ⚠️ **實作者提出的替代錨點(`is_card_play_in_progress()` 的真/假轉換點,3 處)**
> **目前同樣只是讀碼結論,沒有引擎證據** —— 協調者已要求它先寫出一條會驗到
> 「未選取任何單位時游標仍可移動」的測試,再動 `battle_screen.gd`。
> **不要把這段更正讀成「替代方案已經確認可行」。**


**不必讀完 2772 行輸入分派流程。選取狀態的權威來源在 `BattleController`,不在畫面層。**

```
$ grep -n "^func selected_unit\|_selected_unit_id = " src/gameplay/battle/battle_controller.gd
229:func selected_unit() -> int:
1171:	_selected_unit_id = id
1180:	_selected_unit_id = -1
```

| | 時機 | 訊號 | emit 處 |
|---|---|---|---|
| **進入** | 選取成功 | `unit_selected(id)` | `battle_controller.gd:1172` |
| **離開** | 清除選取 | `selection_cleared()` | `battle_controller.gd:1181` |

🔴 **`selection_cleared` 是【唯一】的離開漏斗**,涵蓋四條路 —— `battle_controller.gd:1175-1177`
的註解逐字:

> Shared deselection logic for `deselect()`, `click_tile()`'s residual branch,
> `end_unit_turn()`, and `end_faction_phase()` — always leaves `_selected_unit_id`
> at -1 and emits `selection_cleared` exactly once.

**「exactly once」這個保證直接買到 register/unregister 的對稱性**,不必自己數路徑。

🔴 **而且這兩個訊號 `battle_screen.gd` 早就接起來了**,handler 目前只做 `_refresh_view()`:
```
$ grep -n "unit_selected.connect\|selection_cleared.connect" src/ui/battle/battle_screen.gd
970:	_controller.unit_selected.connect(func(_id: int) -> void: _refresh_view())
971:	_controller.selection_cleared.connect(func() -> void: _refresh_view())
```
**掛載點是現成的。**

## 二、✅ 已解決:兩份導航實作可以互換,橋接函式也已經存在

| | 定義 | 邊界行為 |
|---|---|---|
| `battle_screen.clamp_cursor_move(cell, delta)` (`:1233`) | 吃 `Vector2i` 格座標,逐軸 `clampi` | 到邊界**夾住**→ 回傳同一格 |
| `CursorState.apply_buffered_navigation(events)` (`cursor_state.gd:534`) | 吃 `CursorTarget(surface, id:int)`,向已註冊 surface **PULL** 查詢 | surface 回 `null` → `_target` **不動** |

**兩者在棋盤邊界的對外行為一致**(都是「游標留在原地」),只是一個用夾擠、一個用拒絕。

🔴 **而且 `BOARD_TILE` 的橋接函式已經寫好了**(打牌路徑在用):
```
$ sed -n '1944,1950p' src/ui/battle/battle_screen.gd
func cursor_navigate(from_id: int, direction: Vector2i) -> Variant:
	var from_cell: Vector2i = CursorTypes.decode_tile(from_id, BoardCoords.BOARD_COLS)
	var to_cell: Vector2i = from_cell + direction
	if not BoardCoords.is_in_bounds(to_cell):
		return null
	return CursorTypes.encode_tile(to_cell, BoardCoords.BOARD_COLS)
```
**游標系統用的是整數 id,棋盤用的是 `Vector2i`,`CursorTypes.encode_tile`/`decode_tile`
是兩者之間唯一的轉換。** 實作者不需要設計新的編碼。

✅ **協調者已補驗(原本列為未驗證項):`_DIRECTION_VECTORS` 只含四個正交方向,無斜向。**
```
$ grep -n "_DIRECTION_VECTORS" -A 5 src/ui/battle/battle_screen.gd
290:const _DIRECTION_VECTORS: Dictionary = {
291-	&"ui_up": Vector2i.UP,
292-	&"ui_down": Vector2i.DOWN,
293-	&"ui_left": Vector2i.LEFT,
294-	&"ui_right": Vector2i.RIGHT,
295-}
```
**所以「逐軸夾擠」與「整體拒絕」在本專案的輸入集合下嚴格等價** —— 斜向才會不等價
(夾擠會沿邊滑動、拒絕則完全不動),而斜向不存在。

## 三、🔴 最可能炸掉的一件事:**游標會一次走兩格**(協調者的假說,未驗證)

兩條路徑今天**時間上互斥**,這是它們至今沒有打架的唯一原因:
```
$ sed -n '1138,1142p' src/ui/battle/battle_screen.gd   # 一般路徑
		if not _controller.is_card_play_in_progress():
			_handle_directional(event)
```
```
$ sed -n '1756,1762p' src/ui/battle/battle_screen.gd   # 它做了什麼
func _handle_directional(_event: InputEvent) -> void:
	for action: StringName in _DIRECTION_VECTORS:
		if _direction_just_pressed(action, _direction_was_pressed):
			_device.note_pad_input()
			_cursor_cell = clamp_cursor_move(_cursor_cell, _DIRECTION_VECTORS[action])
			_board_view.set_cursor(_cursor_cell)
```

而 `CursorStateHost` 是 Autoload,**它自己的 `_input()` 會緩衝導航事件、`_process()` 會沖刷**
(`cursor_state_host.gd:364` / `:384` / `:410`)。

🔴 **一旦一般路徑註冊了 `BOARD_TILE`,同一次按鍵就會有兩個東西去移動游標** ——
`_handle_directional()` 自己移一次,host 的 `apply_buffered_navigation()` 再移一次。

📌 **所以 AC 第 3 條「`_handle_directional()` 的導航邏輯改呼叫 `apply_buffered_navigation()`」
這句話的字面意思可能是個陷阱** —— 實作者**不該**在 `_handle_directional()` 裡去呼叫它
(host 已經會自動呼叫),而是該讓 `_handle_directional()` **停止自行移動游標**。
⚠️ **這是協調者的假說,沒有實機驗證。** 第一件事就去驗它:寫一條會抓到「按一次走兩格」的測試。

## 四、順帶撞到的兩處過時註解(**不在 story-008 範圍內**,只登記)

兩處仍宣稱 `authoritative_write_in_progress` 旗標不存在,而它 2026-10-12 起是真的:
```
$ grep -rn "NO field anywhere" src/ --include=*.gd
src/gameplay/battle/battle_controller.gd:1018:## flag has NO field anywhere in [code]src/[/code] yet (verified:
src/ui/battle/battle_screen.gd:2351:# _process frames. That flag has NO field anywhere in src/ today (see
```
🔴 **引用鏈三層深,而根已經修了**:`card_play_session.gd`(✅ 已修)
← `battle_controller.gd:1018` 引用它(**未修**)← `battle_screen.gd:2351` 又引用前者(**未修**)。
**這兩處超出 story-008 的明文範圍,須先經管理者核准才能動。**
