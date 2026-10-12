# Story 002 — `.tscn` 場景檔裸字串遷移 證據檔

> 本檔由 `godot-specialist` 建立,記錄 `src/ui/battle/BattleScreen.tscn` 與
> `src/ui/menu/BattleMenu.tscn` 兩個場景檔的裸字串遷移過程與驗收證據。

## 狀態

- [x] 讀完 story 檔與檔頭落地狀況說明
- [x] `BattleScreen.tscn` 三處佔位符調查與處置 —— 已完成並已跑測試驗證
- [x] `BattleMenu.tscn` 五個按鈕文字遷移 —— **已裁決採方案 2,已完成**
- [x] CSV locale 新增 5 個 key —— 已完成
- [x] 端到端測試 —— 已完成(擴充既有 `i18n_migrated_strings_test.gd`)
- [x] 匯入 + 全套測試跑過(含本批全部改動)
- [x] 殘留驗收指令與定義域說明 —— 已完成,見第三節
- [x] 回報

---

## 一、`src/ui/battle/BattleScreen.tscn` —— 已完成

### 1.1 三處裸字串與處置

| 節點 | 原始 `text` | 處置 |
|---|---|---|
| `UILayer/StatusLabel` | `"Round 1 \| PLAYER phase"` | **刪除該行**(不留空字串佔位,與同檔案 `InfoLabel`/`LoadErrorLabel` 既有寫法一致) |
| `UILayer/ResultLabel` | `"VICTORY"` | **刪除該行** |
| `UILayer/ControlsHintBg/ControlsHintLabel` | `"移動 方向鍵/十字鍵/滑鼠　確認 Enter/A/左鍵　結束回合 Esc/B"` | **刪除該行** |

### 1.2 為什麼是「刪除」而不是「改成正確佔位」或「留著不動」—— 逐項證據

判斷原則:這三個節點的 `.text` 是否存在任何一條執行路徑讓玩家在它被程式覆寫**之前**看到它?逐一查證如下(皆為讀 `src/ui/battle/battle_screen.gd` 原始碼得出,非轉述):

**(a) `ControlsHintLabel` —— 最強的一個,`_ready()` 第一行就覆寫,沒有任何分支能繞過**

```gdscript
func _ready() -> void:
	_controls_hint_label.text = Loc.localize(TEXT_CONTROLS_HINT)

	var terrain_text: String = ""
	...
	if (terrain_failure != LoadFailure.NONE or ...):
		_fail_load({...})
		return
```

`_controls_hint_label.text = Loc.localize(TEXT_CONTROLS_HINT)` 是 `_ready()` 的**第一個陳述式**,在任何載入失敗分支判斷**之前**就執行。不論後面走成功路徑還是 `_fail_load()` 路徑,這一行都已經跑過。**沒有任何路徑能讓場景檔裡的原始字面值被畫面顯示。**

🔴 **這個佔位字面值本身已經是錯的,不只是無用** —— 它是 Story U-016(2026-09-24)之前的舊版單行提示,只列了「移動/確認/結束回合」三個動作;U-016 把「結束回合」移出這個提示列(改走選單),並新增了四個新動作(`battle_cancel`/`battle_open_hand`/`battle_next_target`+`battle_prev_target`/`battle_menu`),現在 `strings.csv` 的 `battle.hud.controls_hint` 真值是兩行、包含 5 個動作。場景檔裡的這行字面值即使有人去讀它,**讀到的也是過時且錯誤的內容**。這也是選「刪除」而非「改成正確佔位」的理由之一:正確佔位值會跟 CSV 內容重複維護兩份,正是本專案 `world_layout.gd`/`hud_layout.gd` 單一出處紀律要防的「同一公式兩份實作,只是今天答案一致」的形狀。

**(b) `StatusLabel` —— 兩條路徑都覆蓋,一條設文字、一條設隱藏**

成功路徑:`_ready()` 最後一行呼叫 `_refresh_view()`(函式本體最後一個陳述式),內部呼叫 `_update_status_label()`:

```gdscript
func _update_status_label() -> void:
	var faction_text: String = Loc.localize(TEXT_FACTION_PLAYER) if ... else Loc.localize(TEXT_FACTION_ENEMY)
	_status_label.text = Loc.localize(TEXT_STATUS_FORMAT) % [_order.round_number(), faction_text]
```

這整條呼叫鏈在 `_ready()` **返回之前**同步執行完畢,第一個畫格繪製之前 `.text` 已是真值。`_controller.phase_changed` 訊號也連到同一個函式,每次回合階段變化再設一次。

失敗路徑:`_fail_load()` 明確把它**隱藏**:`_status_label.visible = false`(`grep -c "_status_label.visible" src/ui/battle/battle_screen.gd` 確認全檔唯一一處),故失敗路徑下這個 Label 整個不會被畫出來。

**(c) `ResultLabel` —— 可見性與文字綁在同一行,不可能分離觀察到**

```gdscript
func _on_battle_ended(outcome: BattleState.Outcome) -> void:
	_result_label.visible = true
	_result_label.text = Loc.localize(TEXT_RESULT_VICTORY) if outcome == BattleState.Outcome.VICTORY else Loc.localize(TEXT_RESULT_DEFEAT)
```

`grep -n "_result_label.visible" src/ui/battle/battle_screen.gd` 確認全檔**唯一**一處把它設為 `true` 就是這裡,與設正確文字是連續兩行、同一次呼叫。場景檔本身該節點預設 `visible = false`(未被本次改動觸碰),**沒有任何時間窗口是「visible==true 且 `.text` 還是舊佔位字面值」**。

### 1.3 為什麼選「刪除」而非「設為空字串」

兩者執行期效果相同(`Label.text` 預設值就是空字串),差別只在 `.tscn` 可讀性。同檔案 `InfoLabel`/`LoadErrorLabel`(同樣完全由程式接管文字)本來就沒有 `text = ""` 這一行,刪除是跟既有風格一致,不新增一種「空字串」寫法徒增風格分歧。

### 1.4 測試驗證(本項改動單獨驗證時的結果,已被第四節的最終全批結果取代)

首次單獨驗證(只有這 3 行改動時):`Overall Summary: 1043 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans | Exit code: 100`,唯一具名 FAILED 是既有刻意紅項。完整最終結果見第四節。

---

## 二、`src/ui/menu/BattleMenu.tscn` —— 已完成(方案 2,協調者裁決)

### 2.1 裁決

協調者核准**方案 2**:清空 `.tscn` 的 5 處 `text =`,改由 `battle_menu.gd` 的 `_ready()` 用 `Loc.localize()` 設定。理由(協調者原話摘要):方案 1(靠引擎原生 `auto_translate` 自動翻譯)已用探針量到否定結果且會繞過「絕不顯示裸 key」安全網;方案 3(新建可重用腳本)是沒有先例的新模式,為 5 個字串不值得;方案 2 與既有 `_leave_confirm_title_label.text = Loc.localize(...)` 風格一致。

### 2.2 `BattleMenu.tscn` 改動

5 個節點的 `text = "..."` 行全部刪除(`ReturnToBattleRow`/`EndPhaseRow`/`QuitRow`/`CancelButton`/`LeaveButton`),其餘屬性不動。

### 2.3 `battle_menu.gd` 改動

新增 5 個 `StringName` key 常數,沿用本檔既有「不用 `TEXT_` 前綴」命名慣例(與 `LEAVE_CONFIRM_TITLE`/`LEAVE_CONFIRM_BODY` 同一風格):

```gdscript
const RETURN_TO_BATTLE_ROW: StringName = &"battle.menu.return_to_battle_row"
const END_PHASE_ROW: StringName = &"battle.menu.end_phase_row"
const QUIT_ROW: StringName = &"battle.menu.quit_row"
const LEAVE_CONFIRM_CANCEL: StringName = &"battle.menu.leave_confirm_cancel"
const LEAVE_CONFIRM_LEAVE: StringName = &"battle.menu.leave_confirm_leave"
```

`_ready()` 內新增 5 行賦值,位置與既有兩行(`_leave_confirm_title_label.text = Loc.localize(LEAVE_CONFIRM_TITLE)` 等)同一種寫法:M1 三列的賦值緊接在 `_focusable_rows = [...]` 之後、M4 兩個按鈕的賦值緊接在既有 `_leave_confirm_body_label.text = Loc.localize(LEAVE_CONFIRM_BODY)` 之後。每個節點的 `.text` 只在 `_ready()` 設定一次,之後不再改寫 —— 與本檔類別文件註解「Row TEXT itself is fixed for life once `_ready()` returns」的既有保證一致,我沒有破壞它。

### 2.4 `strings.csv` 新增 5 筆

```
battle.menu.return_to_battle_row,回到遊戲
battle.menu.end_phase_row,結束回合
battle.menu.quit_row,離開遊戲
battle.menu.leave_confirm_cancel,取消
battle.menu.leave_confirm_leave,離開
```

與既有 `battle.menu.*` 命名空間核對無衝突(遷移前已 grep 過現有 7 筆:`leave_confirm_title`/`leave_confirm_body`/`rejection_authoritative_write`/`rejection_forced_discard`/`reason_card_play_in_progress`/`reason_not_player_turn`/`disabled_row_prefix_glyph`)。後兩個 key 命名沿用既有 `leave_confirm_` 前綴慣例。

### 2.5 端到端測試

擴充既有 `tests/unit/core/i18n/i18n_migrated_strings_test.gd`(而非另開新檔)——原因:該檔本來就是「每個來源檔一個字典 + 一個迴圈斷言函式」的結構,`battle_menu.gd` 既有的 7 個 key 已經有自己的 `_EXPECTED_BATTLE_MENU` 字典與 `test_battle_menu_migrated_keys_resolve_to_original_literals()`,這 5 個新 key 來源同樣是 `battle_menu.gd`(遷移後),延用同一個字典與同一條測試函式是最小且一致的擴充,不產生一支內容重疊的近似複製檔。

具體改動:
1. `_EXPECTED_BATTLE_MENU` 字典新增 5 筆(key → 遷移前字面值:`回到遊戲`/`結束回合`/`離開遊戲`/`取消`/`離開`),該字典共 12 筆。
2. 檔頭說明段落更新:總筆數 40 → 45,新增一段說明這 5 筆的來源(`BattleMenu.tscn` 而非 `.gd` 的 `const` 宣告,因此從未被任何「零殘留」grep 掃到過)。
3. `test_total_migrated_key_count_is_forty()` 更名為 `test_total_migrated_key_count_is_forty_five()`,斷言值 40 → 45。

🔴 **誠實揭露:這次擴充沒有新增任何 `func test_*`,是在既有的迴圈斷言函式與字典裡新增條目。** GdUnit4 的測試案例數是以 `func test_*` 計數,不是以斷言數計數 —— 所以這次變動**不會**讓總測試案例數增加(只有總筆數守衛那條測試的斷言邏輯變了,它本身還是同一條測試案例,只是改了名字跟期望值)。這是本次「總數對帳」會與協調者給的基線 1055 剛好打平、而不是 1055+N 的原因,見第四節說明,不是漏做。

---

## 三、殘留驗收 —— 已完成,兩段式指令涵蓋 `.tscn` 與 `.gd` 兩種殘留形式

### 3.1 指令與原始輸出(逐字,未刪節)

```bash
$ grep -n "^text = " src/ui/battle/BattleScreen.tscn src/ui/menu/BattleMenu.tscn
(零命中,grep exit code 1)

$ for f in src/ui/battle/battle_screen.gd src/ui/battle/hand_bar.gd \
           src/ui/battle/card_confirm_panel.gd src/ui/menu/battle_menu.gd; do
    echo "--- $(basename "$f") ---"
    LC_ALL=C grep -n '"[^"]*[^ -~][^"]*"' "$f" | LC_ALL=C grep -v ':[[:space:]]*#'
  done
--- battle_screen.gd ---
136:const _LOG_AFFINITY_ZERO_LINKS_FORMAT: String = "BattleScreen: %s parsed to zero affinity links (%s) — proceeding with no pairings"
143:const _LOG_CARDS_ZERO_PARSED_FORMAT: String = "BattleScreen: %s parsed to zero cards — proceeding with an empty CardDeck"
1419:				"BattleScreen.hand_bar_slot_kind_for: unmapped Card.Category %s -- Z1 falls back to 甲類's shape, but this is now logged rather than silent"
--- hand_bar.gd ---
(零命中)
--- card_confirm_panel.gd ---
(零命中)
--- battle_menu.gd ---
(零命中)
```

### 3.2 這 3 處命中是什麼 —— 逐一核對,確認皆非玩家可見文字

- `_LOG_AFFINITY_ZERO_LINKS_FORMAT` / `_LOG_CARDS_ZERO_PARSED_FORMAT`:兩者本檔自己的doc comment已註明是「Developer-facing log line only (never shown to the player)」,分別配 `push_warning()`,不是 `const TEXT_*`。
- 第 1419 行:我讀了上下文確認,它在 `hand_bar_slot_kind_for()` 的 `match` 預設分支內,完整陳述式是 `push_error("BattleScreen.hand_bar_slot_kind_for: unmapped Card.Category %s -- Z1 falls back to 甲類's shape, but this is now logged rather than silent" % category)`——是 `push_error()` 參數,開發期診斷訊息,不是任何 UI 節點的 `.text` 賦值來源。

**結論:兩個 `.tscn` 檔案零殘留;四個 `.gd` 檔案僅剩 3 處,且全部是開發者診斷訊息(`push_error`/`push_warning`),與 story 檔頭「現況應只剩 `battle_screen.gd` 的 3 處開發者訊息」的預期逐字吻合。**

### 3.3 🔴 這條指令看不見什麼(定義域揭露,本 story 自己的教訓)

1. **`.tscn` 那條只看靜態寫死的 `text =` 屬性這一種寫法**——它看不見場景檔裡其他可能攜帶玩家可見文字的屬性欄位(例如 `tooltip_text`、`placeholder_text`,本次兩個場景檔皆未使用這些欄位,但這條指令本身不會告訴你這件事,是我額外讀過整份 `.tscn` 內容才確認的,見第一節、第二節逐節列出的節點屬性)。
2. **`.gd` 那條的 pattern `"[^"]*[^ -~][^"]*"` 只抓「含非 ASCII 可見字元(例如中文)的雙引號字串」**——純 ASCII 的玩家可見字串(理論上不會出現在這個全繁體中文文案的專案裡,但若未來新增純英數字面值,例如 `"OK"`,這條指令看不到)。這條指令也看不到單引號字串、字串以外的方式組字(例如逐字元 `PackedStringArray` 拼接)。
3. **兩條指令都看不到執行期才動態組出來的字串**是否正確——這件事由第一節的程式碼路徑分析、以及第二節的端到端 `Loc.localize()` 測試覆蓋,不是這條 grep 的責任。
4. **不涵蓋 `.tres` 或其他資源檔**——不在本 story 範圍(`EPIC.md` Q3 明文)。

---

## 四、測試執行紀錄(完整,含本批全部改動:BattleScreen.tscn + BattleMenu.tscn + battle_menu.gd + strings.csv + 測試檔)

```bash
E="C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
"$E" --headless --path . --import
"$E" --headless --path . -s tests/gdunit4_runner.gd
```

- `--import`:exit 0。
- `gdunit4_runner.gd` 原始輸出:
  ```
  Overall Summary: 1055 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans |
  Executed test suites: (89/89)
  Executed test cases : (1055/1055)
  Exit code: 100
  ```
- 具名 `FAILED` 只有一條,是既有刻意紅項,未去動它:
  ```
  res://tests/unit/gameplay/affinity/affinity_phi_provider_test.gd > test_phi_reflects_a_pairing_polarity_flip_made_after_construction FAILED
  ```
- **ENGINE EXIT CODE = 100**(= 有失敗,但唯一的失敗是既有刻意紅項;0 errors、0 orphans)。

🔴 **總數對帳說明**:協調者給的基線是 1055(另外兩位實作者收工後的總數)。我這批測得的總數**也是 1055,打平、不是 1055+N**——原因見第二節 2.5 的誠實揭露:本批新增的 5 個字串驗證是擴充既有迴圈斷言函式與字典的內容,沒有新增 `func test_*`,GdUnit4 以函式計數測試案例,所以總數不會因為字典多了 5 筆而增加。**這不是遺漏**——可查證方式:`test_battle_menu_migrated_keys_resolve_to_original_literals()` 現在內部跑 12 次 `_assert_keys_resolve_to_expected` 迴圈斷言(原 7 筆 + 新 5 筆),`test_total_migrated_key_count_is_forty_five()` 斷言總和為 45(可用 `grep -n "is_equal(45)" tests/unit/core/i18n/i18n_migrated_strings_test.gd` 核對)。

---

## 五、未驗證項(誠實登記)

- **版面複核:未執行**(零畫面曝光紀律,不得開窗/截圖)。
- **方案 1(原生 auto_translate)在「繪製層」是否真的生效:無法驗證**——headless 不 rasterize `Control` 繪製,開窗驗證違反零畫面曝光紀律。這是判定方案 1 不採用的理由之一(已由協調者裁決採方案 2,此項不再阻擋任何工作,僅留存為紀錄)。
- 本次殘留驗收指令的定義域限制,見第三節 3.3 逐項列出,不再重複。
