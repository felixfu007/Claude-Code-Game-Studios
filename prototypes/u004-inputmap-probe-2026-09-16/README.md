# U-004:`InputMap` 探針 —— 5 個候選鍵是否已被內建動作佔用

> Story: `production/epics/card-play-interface/story-u004-input-map-probe.md`
> Epic: 卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> 狀態: **concluded**
> 依 `.claude/rules/prototype-code.md`:本目錄為拋棄式探針,不受 `src/` 規範約束,
> 也不得被正式程式碼引用。**產物是量測報告,不是功能。**

## 假設 / 要回答的問題

在把 5 個新動作(`battle_cancel`、`open_hand`、`next_target`、`prev_target`、`battle_menu`)
寫進 `project.godot` 之前(這是 U-005 的工作),先問引擎:這 10 個候選鍵(5 動作 ×
鍵盤+手把)有沒有哪一個已經被任何既有動作(內建 `ui_*` 或本專案自訂的 `battle_confirm` /
`battle_end_phase`)佔用?尤其要覆核 EPIC.md 陷阱九轉錄的結論——手把左動作鍵(X)是否
真的比上動作鍵(Y)更安全。

## 怎麼量的(等級標示)

**(A) 級**,執行檔案:`prototypes/u004-inputmap-probe-2026-09-16/probe_input_map.gd`

判準依 `.claude/docs/technical-preferences.md`「(A) 的精確定義」節:量測是否執行了引擎/
專案自己的程式碼,而非重新實作一份規則。本探針:

- 直接呼叫 `InputMap.get_actions()` 取得**這個引擎/專案當下真正存在**的全部動作(93 個,
  含本專案沒有寫在 `project.godot` 裡的引擎內建 `ui_*` 預設值——這正是為什麼必須問引擎,
  不能只讀 `project.godot` 文字內容)。
- 對每個動作呼叫 `InputMap.action_get_events()`,直接讀取引擎回傳的真實 `InputEventKey`
  / `InputEventJoypadButton` 物件的欄位(`keycode`、`physical_keycode`、`shift_pressed`、
  `ctrl_pressed`、`alt_pressed`、`meta_pressed`、`button_index`)。
- `KEY_ESCAPE`、`KEY_C`、`KEY_TAB`、`KEY_M`、`JOY_BUTTON_B`、`JOY_BUTTON_X`、
  `JOY_BUTTON_Y`、`JOY_BUTTON_START`、`JOY_BUTTON_LEFT_SHOULDER`、
  `JOY_BUTTON_RIGHT_SHOULDER` 全部是 GDScript 全域列舉常數,由**這個引擎建置當場解析**
  ——不是我從訓練資料記憶的整數,原始輸出把每個常數解析出的實際整數都印出來供覆核
  (見下方「原始輸出」第 8~9 行)。

**本腳本自己重新實作、不是查詢引擎得來的唯一一條規則**(依「(A) 的精確定義」規則 2,
逐條揭露):

- `_key_event_matches()` 的欄位比對邏輯(`keycode`/`physical_keycode` 擇一非零者比對、
  且要求 `shift_pressed` 精確符合目標、`ctrl`/`alt`/`meta` 皆須為否)是**本腳本自己寫的
  比對規則**,不是呼叫引擎的 `InputEventKey.is_match()`。原因:本專案從未驗證過
  `is_match()` 在有無 `exact_match` 參數下對 device 通配、修飾鍵處理的確切語意,
  與其信任一個沒驗證過的引擎方法,不如自己寫一條規則、把規則攤開在這支檔案裡讓人看得到
  ——這條規則本身**不是** (A) 級,是本腳本的判斷,已如實標示。
- 手把比對(`button_index` 相等)為直接欄位比對,無 device id 比較——見下方「刻意未計入
  的因素」。

## 執行方式

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path . -s prototypes/u004-inputmap-probe-2026-09-16/probe_input_map.gd
```

Exit code:**0**(執行兩次皆為 0;第二次重跑加了完整原始欄位傾印,結果與第一次的判定
逐項一致,沒有因為多印欄位而改變任何一項結論)。

## headless 下 `InputMap` 讀得到真東西嗎?

**讀得到。** `InputMap.get_actions()` 在 `--headless` 下回傳 93 個動作(非 0),且逐一
`action_get_events()` 都回傳真實填好欄位的 `InputEventKey` / `InputEventJoypadButton`
物件(見原始輸出第 62~106 行的完整欄位傾印)。這與本專案登記過的「`headless` 下某些引擎
寫入是 no-op」(`Input.mouse_mode` 案例)不是同一類問題——那是**寫入**在 headless 被引擎
忽略,而 `InputMap` 的資料是**專案啟動時載入的靜態設定**,不涉及視窗/顯示子系統,
**讀取**不受 headless 影響。本探針沒有觀察到任何跡象顯示這裡有 headless 特有的失真。

## 原始輸出(完整貼上,兩次執行結果一致)

```
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

=== Story U-004 InputMap probe (2026-09-16) ===
Engine version: { "major": 4, "minor": 7, "patch": 1, "hex": 263937, "status": "stable", "build": "official", "hash": "a13da4feb8d8aefc283c3763d33a2f170a18d541", "timestamp": 0, "string": "4.7.1-stable (official)" }
InputMap 在 headless 下可讀: true (get_actions() 回傳 93 個動作,非空即為可讀)

--- 本次使用的引擎常數,由本引擎建置即時解析,非記憶中的數字 ---
KEY_ESCAPE=4194305  KEY_C=67  KEY_TAB=4194306  KEY_M=77
JOY_BUTTON_A=0  JOY_BUTTON_B=1  JOY_BUTTON_X=2  JOY_BUTTON_Y=3  JOY_BUTTON_START=6  JOY_BUTTON_LEFT_SHOULDER=9  JOY_BUTTON_RIGHT_SHOULDER=10

--- 5 個候選鍵逐項查核(鍵盤 + 手把兩側,共 10 個按鍵) ---

[battle_cancel — 取消 / 退一步]  鍵盤建議=Esc  手把建議=B (右動作鍵)
  鍵盤 Esc -> 已被佔用: [&"ui_cancel", &"ui_close_dialog", &"ui_close_dialog.macos", &"ui_text_clear_carets_and_selection", &"battle_end_phase"]
    - ui_cancel | 該動作同時有鍵盤與手把綁定: 否(僅單側)
    - ui_close_dialog | 該動作同時有鍵盤與手把綁定: 否(僅單側)
    - ui_close_dialog.macos | 該動作同時有鍵盤與手把綁定: 否(僅單側)
    - ui_text_clear_carets_and_selection | 該動作同時有鍵盤與手把綁定: 否(僅單側)
    - battle_end_phase | 該動作同時有鍵盤與手把綁定: 是(同時有鍵盤+手把)
  手把 B (右動作鍵) -> 已被佔用: [&"battle_end_phase"]
    - battle_end_phase | 該動作同時有鍵盤與手把綁定: 是(同時有鍵盤+手把)

[open_hand — 開 / 收手牌]  鍵盤建議=C  手把建議=X (左動作鍵)
  鍵盤 C -> 未被佔用
  手把 X (左動作鍵) -> 已被佔用: [&"ui_colorpicker_delete_preset"]
    - ui_colorpicker_delete_preset | 該動作同時有鍵盤與手把綁定: 是(同時有鍵盤+手把)

[next_target — 跳下一個合法目標]  鍵盤建議=Tab  手把建議=RB
  鍵盤 Tab -> 已被佔用: [&"ui_focus_next", &"ui_text_completion_accept", &"ui_text_indent"]
    - ui_focus_next | 該動作同時有鍵盤與手把綁定: 否(僅單側)
    - ui_text_completion_accept | 該動作同時有鍵盤與手把綁定: 否(僅單側)
    - ui_text_indent | 該動作同時有鍵盤與手把綁定: 否(僅單側)
  手把 RB -> 未被佔用

[prev_target — 跳上一個合法目標]  鍵盤建議=Shift+Tab  手把建議=LB
  鍵盤 Shift+Tab -> 已被佔用: [&"ui_focus_prev", &"ui_text_completion_replace", &"ui_text_dedent"]
    - ui_focus_prev | 該動作同時有鍵盤與手把綁定: 否(僅單側)
    - ui_text_completion_replace | 該動作同時有鍵盤與手把綁定: 否(僅單側)
    - ui_text_dedent | 該動作同時有鍵盤與手把綁定: 否(僅單側)
  手把 LB -> 未被佔用

[battle_menu — 開啟選單]  鍵盤建議=M  手把建議=Start
  鍵盤 M -> 未被佔用
  手把 Start -> 未被佔用

--- 陷阱九覆核:手把 X(左動作鍵)是否真的比 Y(上動作鍵)更安全? ---
既有結論(2026-08-27,轉錄於 EPIC.md):ui_select 的手把綁定 = Y(上動作鍵),
鍵盤綁定 = Space,而 Space 已被 battle_confirm 佔用 → 同一次按鍵觸發兩個動作。
本次覆核 JOY_BUTTON_Y 佔用者:
  手把 Y -> 已被佔用: [&"ui_select"]
    - ui_select | 該動作同時有鍵盤與手把綁定: 是(同時有鍵盤+手把)
本次覆核 JOY_BUTTON_X 佔用者(即 open_hand 建議鍵,上方已查過,這裡重列以便對照):
  手把 X -> 已被佔用: [&"ui_colorpicker_delete_preset"]
    - ui_colorpicker_delete_preset | 該動作同時有鍵盤與手把綁定: 是(同時有鍵盤+手把)

--- Esc / B 特別檢查:除了 battle_end_phase 之外,是否還有其他動作佔用? ---
鍵盤 Esc 佔用者(全部): [&"ui_cancel", &"ui_close_dialog", &"ui_close_dialog.macos", &"ui_text_clear_carets_and_selection", &"battle_end_phase"]
鍵盤 Esc 佔用者(排除 battle_end_phase 之後): [&"ui_cancel", &"ui_close_dialog", &"ui_close_dialog.macos", &"ui_text_clear_carets_and_selection"]
手把 B 佔用者(全部): [&"battle_end_phase"]
手把 B 佔用者(排除 battle_end_phase 之後): []

--- 附:project.godot 自訂動作(battle_confirm / battle_end_phase)的完整綁定原始資料 ---
  battle_confirm:
    InputEventKey keycode=4194309 physical_keycode=0 shift=false ctrl=false alt=false meta=false
    InputEventKey keycode=4194310 physical_keycode=0 shift=false ctrl=false alt=false meta=false
    InputEventKey keycode=32 physical_keycode=0 shift=false ctrl=false alt=false meta=false
    InputEventJoypadButton button_index=0
  battle_end_phase:
    InputEventKey keycode=4194305 physical_keycode=0 shift=false ctrl=false alt=false meta=false
    InputEventJoypadButton button_index=1

--- 附:上面每一項判定為「已被佔用」的動作,其完整綁定原始資料(逐一列出,供覆核不必相信本腳本的布林判定) ---
  battle_end_phase:
    InputEventKey keycode=4194305 physical_keycode=0 shift=false ctrl=false alt=false meta=false
    InputEventJoypadButton button_index=1
  ui_colorpicker_delete_preset:
    InputEventJoypadButton button_index=2
    InputEventKey keycode=4194312 physical_keycode=0 shift=false ctrl=false alt=false meta=false
  ui_text_clear_carets_and_selection:
    InputEventKey keycode=4194305 physical_keycode=0 shift=false ctrl=false alt=false meta=false
  ui_text_dedent:
    InputEventKey keycode=4194306 physical_keycode=0 shift=true ctrl=false alt=false meta=false
  ui_text_indent:
    InputEventKey keycode=4194306 physical_keycode=0 shift=false ctrl=false alt=false meta=false
  ui_text_completion_replace:
    InputEventKey keycode=4194306 physical_keycode=0 shift=true ctrl=false alt=false meta=false
    InputEventKey keycode=4194309 physical_keycode=0 shift=true ctrl=false alt=false meta=false
    InputEventKey keycode=4194310 physical_keycode=0 shift=true ctrl=false alt=false meta=false
  ui_text_completion_accept:
    InputEventKey keycode=4194306 physical_keycode=0 shift=false ctrl=false alt=false meta=false
    InputEventKey keycode=4194309 physical_keycode=0 shift=false ctrl=false alt=false meta=false
    InputEventKey keycode=4194310 physical_keycode=0 shift=false ctrl=false alt=false meta=false
  ui_focus_prev:
    InputEventKey keycode=4194306 physical_keycode=0 shift=true ctrl=false alt=false meta=false
  ui_focus_next:
    InputEventKey keycode=4194306 physical_keycode=0 shift=false ctrl=false alt=false meta=false
  ui_close_dialog.macos:
    InputEventKey keycode=87 physical_keycode=0 shift=false ctrl=false alt=false meta=true
    InputEventKey keycode=4194305 physical_keycode=0 shift=false ctrl=false alt=false meta=false
  ui_close_dialog:
    InputEventKey keycode=4194305 physical_keycode=0 shift=false ctrl=false alt=false meta=false
  ui_cancel:
    InputEventKey keycode=4194305 physical_keycode=0 shift=false ctrl=false alt=false meta=false
  ui_select:
    InputEventJoypadButton button_index=3
    InputEventKey keycode=32 physical_keycode=0 shift=false ctrl=false alt=false meta=false

=== Probe complete ===
```

完整 log 檔:`prototypes/u004-inputmap-probe-2026-09-16/logs/probe_output.txt`

## 逐項結論(U-005 要用的答案)

| 候選動作 | 鍵盤鍵 | 鍵盤側結論 | 手把鍵 | 手把側結論 |
|---|---|---|---|---|
| `battle_cancel` | Esc | 🔴 **已被佔用**——除了刻意的 `battle_end_phase` 之外,還有 4 個內建動作也綁 Esc(見下方說明) | B | 已被佔用,但**只有** `battle_end_phase`(即設計文件描述的刻意過渡狀態,無其他佔用) |
| `open_hand` | C | ✅ 未被佔用 | X(左動作鍵) | 🔴 **已被佔用**——`ui_colorpicker_delete_preset`(見下方陷阱九說明) |
| `next_target` | Tab | 🔴 **已被佔用**——3 個內建動作(`ui_focus_next`、`ui_text_completion_accept`、`ui_text_indent`),全部單側(僅鍵盤) | RB | ✅ 未被佔用 |
| `prev_target` | Shift+Tab | 🔴 **已被佔用**——3 個內建動作(`ui_focus_prev`、`ui_text_completion_replace`、`ui_text_dedent`),全部單側(僅鍵盤) | LB | ✅ 未被佔用 |
| `battle_menu` | M | ✅ 未被佔用 | Start | ✅ 未被佔用 |

**手把動作鍵的實際佔用情形(逐項,對應工作單「①/②」查核項目)**:

- **RB / LB / Start 三個手把鍵完全乾淨**,沒有任何內建動作佔用。
- **B(battle_cancel 手把建議)只被 `battle_end_phase` 佔用**,這正是 UX 規格明文承認且
  刻意接受的過渡狀態(`battle_end_phase` 的兩個綁定要「接手」給 `battle_cancel`)——不是
  本探針的新發現,是覆核既有假設成立。
- **X(open_hand 手把建議)被 `ui_colorpicker_delete_preset` 佔用,且該內建動作同時綁了
  鍵盤(Delete)與手把(X)** ——見下方「陷阱九覆核」的完整討論,這是本次量測**推翻
  UX 規格字面陳述**的一項發現。

## 🔴 陷阱九覆核:X 真的比 Y 安全嗎?——字面答案是「否」,但風險量級不同

工作單 AC 第 3 條字面要求驗證「X 未被任何同時綁鍵盤+手把的內建動作佔用」。**實測結果是
這句話不成立**:

- **Y(上動作鍵)**:被 `ui_select` 佔用,`ui_select` 同時綁鍵盤 **Space**(keycode=32)
  與手把 **Y**(button_index=3)。而 Space **已經**被 `battle_confirm` 佔用
  ——這正是 2026-08-27 探針記錄的既有結論,本次覆核**逐位元組重現**,沒有推翻。
- **X(左動作鍵)**:被 `ui_colorpicker_delete_preset` 佔用,該動作同時綁鍵盤
  **Delete**(keycode=4194312)與手把 **X**(button_index=2)。
  **字面上,X 與 Y 是同一種形狀的衝突**——兩者都被一個「鍵盤+手把雙側綁定」的內建動作佔用。

**但兩者的實際風險量級不是同一回事,理由是觸發條件的類別不同,而這是本檔的判斷,不是
引擎告訴我的事實,必須明確標示為判斷而非量測**:

1. `ui_select` 的鍵盤側(Space)與本專案**現有的** `battle_confirm` 直接重疊——這代表
   **不需要 `open_hand` 存在**,`ui_select`/`battle_confirm` 這組衝突今天就已經在跑
   (按 Space 已經同時觸發兩者)。若把 `open_hand` 也綁到 Y,是在既有衝突之上疊加
   第三個受影響的動作。
2. `ui_colorpicker_delete_preset` 的鍵盤側(Delete)**與本專案目前任何一個自訂動作或
   本次候選清單都不重疊**,故它不構成「一鍵三果」的疊加情況——它是獨立的一組
   雙側衝突,只影響 `open_hand`/手把 X 這一組。
3. 兩個內建動作的**實際觸發前提**在 Godot 引擎裡是不同類別的元件:`ui_select` 是
   `Tree`/`ItemList`/`OptionButton` 等**清單類原生元件**在擁有引擎焦點時處理的動作,
   這類元件在任何有選單/清單導覽需求的介面都可能出現(本 epic 的 `battle-menu.md`
   明文記載「本畫面**可以**用引擎原生 focus,這是明文豁免」);`ui_colorpicker_delete_preset`
   則專屬 `ColorPicker`/`ColorPickerButton` 元件的「刪除色票」子功能。**本專案的
   `design/` 全文檢索沒有任何色彩選擇器介面的需求**(戰鬥、手牌、選單三份規格皆未提及)。
   ⚠️ **這一條是本檔基於「該元件類別是否可能出現在這個專案」的判斷,不是對
   `src/` 已實作介面的量測**——因為 `battle_menu`、`skill-card-play` 兩個介面目前都
   尚未實作(`grep -rn "battle_menu" src/` 零命中,已在派工單引用的 UX 規格中確認),
   無法對真正的節點樹做二次驗證。

**結論**:UX 規格「手把用 X 是為了避開已知的那一個」這句話,**若照字面理解(X 完全零
佔用)是不成立的**;但**方向性判斷(X 優於 Y)仍然成立**,理由是 X 唯一的衝突對象
(`ui_colorpicker_delete_preset`)觸發條件與本專案的介面元件類別無重疊,而 Y 的衝突對象
(`ui_select`)觸發條件(清單類原生元件的焦點)與本 epic 明文允許使用原生 focus 的
`battle-menu.md` **存在真實交集**。**U-005 落地時,若 `battle_menu` 的選單列真的用了會
處理 `ui_select` 的原生元件類型(`Tree`/`ItemList`/`OptionButton`),應該重新檢查——
本探針量的是 `InputMap` 靜態綁定,不是節點行為,這一步留給實作期。**

## Esc 的 4 個額外佔用者——鍵盤側风险揭露

工作單明文要求:「除了 `battle_end_phase` 之外,鍵盤 `Esc` 與手把 `B` 有沒有同時被任何
內建 `ui_*` 動作佔用」。**手把 B 沒有;鍵盤 Esc 有 4 個**,全部單側(僅鍵盤,不影響手把):

| 內建動作 | 實際觸發前提(依 Godot 元件慣例,非本專案量測) |
|---|---|
| `ui_cancel` | 泛用「取消」語意,多數原生 `Window`/`Popup`/`Control` 在有引擎焦點時的預設 Esc 行為 |
| `ui_close_dialog` | `AcceptDialog`/`ConfirmationDialog` 等對話框視窗開啟且有焦點時 |
| `ui_close_dialog.macos` | 同上,macOS 專用變體(鍵盤側額外綁 `Cmd+W`,與本專案平台無關) |
| `ui_text_clear_carets_and_selection` | `TextEdit`/`LineEdit` 有輸入焦點時 |

**這比 2026-08-27 及 EPIC.md 的既有陳述(只講到 `battle_end_phase` 一項)多出 4 個**,是
本次探針測到、先前文件未列舉的具體項目。**風險評估與 X/Y 那條同一套邏輯**:這 4 個
內建動作全部依附**原生 Control 節點的焦點**,而 `skill-card-play.md` 的介面明文走
ADR-0005 的**自訂游標狀態源**、不用引擎原生 focus;`battle-menu.md` 則**明文豁免**、
**允許**原生 focus。**若 `battle_menu` 的實作在遮罩開啟期間讓某個原生 `Window`/
`Popup`/`TextEdit`/`Dialog` 類節點意外取得引擎焦點,按 Esc 時 `battle_cancel` 會與其中
一個內建動作同時觸發**——這是一個必須在 `battle_menu` 實作時主動避免(不使用
`AcceptDialog`/`ConfirmationDialog`/`TextEdit` 等原生對話框類節點,改用自訂 `Control`
組裝)的實作約束,建議寫入 U-005 或 `battle-menu.md` 的實作注意事項。

## 刻意未計入的因素

1. **只查 `InputMap` 的靜態綁定,不查節點在執行期的實際 focus/hover 行為。**
   `ui_select`/`ui_cancel` 等內建動作是否真的會在本專案的畫面上觸發,取決於實作時選用
   的節點類型(`Tree`/`Button`/`AcceptDialog` 等)有沒有拿到引擎焦點——這不是
   `InputMap` 能回答的問題,必須等 `battle_menu`/`skill-card-play` 實際寫出節點樹後,
   在非 headless 環境用真實輸入裝置量測。
2. **只做「無修飾鍵完全精確比對」,不查部分修飾鍵組合。** `battle_cancel` 的 Esc 檢查
   只比對「Esc,且 Ctrl/Alt/Shift/Meta 皆為否」——若有任何內建動作綁的是
   `Ctrl+Esc`、`Alt+Esc` 等組合鍵,本探針**不會**回報為衝突(因為玩家單按 Esc 不會觸發
   那個組合鍵動作,這樣的排除是刻意且正確的,但明文寫出以免誤解為疏漏)。
3. **手把比對不分裝置 id(`device` 欄位)。** 本專案是單機單一本地玩家,不需要區分
   哪一把實體手把,故只比對 `button_index`。若本專案未來加入本地多人,這條假設需要
   重新檢查(目前 `technical-preferences.md` 明文禁止連線/多人功能,但**本機多手把**
   與網路連線是兩回事,未在此排除範圍內討論)。
4. **不查滑鼠鍵。** 5 個候選鍵都不是滑鼠輸入,故未檢查任何 `InputEventMouseButton`/
   `InputEventMouseMotion` 的佔用情形。
5. **`InputMap.get_actions()` 回傳的 93 個動作已經是引擎+`project.godot` 合併後的完整
   集合**(而不是只有 `project.godot` 自訂的兩個),因此涵蓋所有 addon(本專案僅
   `addons/gdUnit4/`)可能註冊的動作——但**沒有另外反向確認 gdUnit4 沒有註冊任何
   `[input]` 動作**,只是依賴「93 個裡沒有看到明顯以 gdunit 命名的動作」這個間接觀察,
   未逐一排查 gdUnit4 原始碼。

## 我沒做到或不確定的事

1. **battle_menu / skill-card-play 兩個介面都還沒有 `src/` 實作**,所以「Esc 的 4 個
   額外佔用者是否真的會在本專案畫面上發生二次觸發」無法在今天驗證——本報告只能指出
   風險存在,不能確認風險已發生或已排除。這件事**留給實作期用真實節點樹複驗**。
2. **X vs Y 的風險量級判斷(上方「陷阱九覆核」第三點)是我依 Godot 元件慣例的推理,
   不是對這個引擎版本 4.7.1 的實機行為驗證** ——我沒有寫一個真的放 `Tree`/`ItemList`
   節點、給它引擎焦點、然後量測按下 Y 是否真的觸發 `ui_select` 訊號的探針。若這個
   量級判斷對後續決策很關鍵,建議另開一支非 headless 探針驗證。
3. **沒有驗證 `ui_close_dialog.macos` 在非 macOS 平台是否真的不會被觸發。** 它出現在
   `InputMap.get_actions()` 的清單裡(引擎似乎不分平台全部註冊),但它的鍵盤綁定含
   `Cmd+W`(`meta_pressed=true`),在 Windows 上 `meta` 鍵語意不同——我沒有查證這個
   動作在 Windows 執行期是否真的無法被觸發,只是依名稱與 `meta` 修飾鍵推測它是
   macOS 專用,**這是推測,不是量測**。
4. **沒有另外對照 `docs/architecture/control-manifest.md` 之外的其他架構文件**
   是否還有第三份地方也記載了這 5 個候選鍵的清單版本(只核對了派工單指定的兩份 UX
   規格與 EPIC.md 轉錄的段落)。

## 派工單哪幾處我認為有出入

整體而言派工單與工作單本體(`story-u004-input-map-probe.md`)一致,我沒有找到派工單
與工作單本體衝突之處。以下兩點不是「錯誤」,是派工單沒提到、但我認為值得記錄的落差:

1. 派工單引用「UX 規格建議手把用 X(左動作鍵),正是為了避開已知的那一個」時,語氣
   暗示 X 的安全性已經確立、探針只是「覆核」。**實測結果是這句話的字面版本(X 零佔用)
   不成立**——X 一樣被一個雙側內建動作佔用,只是風險量級與 Y 不同。派工單與工作單
   本體都沒有預期到這個結果(兩份文件都只問了是非題),這是本次探針量出的**新資訊**,
   不是對既有文件的糾正,但足以影響 U-005 的措辭(不應繼續寫「X 未被佔用」,應寫
   「X 的衝突對象與本專案介面元件類別無重疊,風險遠低於 Y」)。
2. 派工單的候選鍵清單與工作單本體一致(逐字核對過表格),沒有發現派工單抄錯任何一個
   建議鍵位。
