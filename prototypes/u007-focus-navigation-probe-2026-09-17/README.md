# Spike: U-007 焦點導覽探針(2026-09-17)

> PROTOTYPE — NOT FOR PRODUCTION / 拋棄式驗證探針
> **執行**:`ui-programmer`,本機 Godot 4.7.1,headless
> **對應工作單**:`production/epics/card-play-interface/story-u007-battle-menu-screen-layout.md`
> Implementation Notes #3、EPIC.md 陷阱十三

## 量測目的

`design/ux/battle-menu.md` 明文:「`focus_mode` / `disabled` 的實際行為本專案從未量測過」。
本探針在寫任何 `battle_menu.gd` 正式程式碼之前,向真實引擎(而非訓練資料記憶)驗證三件事:

- **Claim 1**:Godot 4.7.1 的自動(未設定任何 `focus_neighbor_*`)幾何鄰居搜尋,
  從最上排的可聚焦節點按「↑」,**是否會繞到最下排**?(AC-M13 的前提)
- **Claim 2**:本 story 實際打算使用的生產機制 —— 把最上排的
  `focus_neighbor_top` 明確指向自己(self-loop)—— 是否確實把焦點釘住在原地?
  (不依賴 Claim 1 的自動行為是否可靠,顯式設定作為防禦性保證)
- **Claim 3**:自動幾何搜尋是否會正確跳過 `focus_mode = FOCUS_NONE` 的分隔線節點
  (M2 兩個項目與「離開遊戲」之間的分隔線),讓「結束回合」按「↓」直接到「離開遊戲」?

## 三個版本,為什麼 v1 被 v2/v3 取代(這是證據鏈的一部分,不是失敗紀錄要藏起來)

- **v1**(`probe_focus_navigation.gd`)把三個按鈕**直接**加到 `SceneTree.root`
  (即 `Window` 本體)。結果自相矛盾:「↑」(邊界,理論上不該動)確實沒動,
  但「↓」(中間,理論上該移到第二排)**也沒有動** —— 兩個方向都沒有反應,
  代表這不是在驗證「有沒有繞回」,而是**整個自動焦點搜尋在這個節點結構下根本沒有運作**。
  這個結果無法回答 Claim 1,必須先找出根因。
- **v2**(`probe_focus_navigation_v2.gd`)拆解變因:改把按鈕包在一個獨立的
  `Control` wrapper 底下(不再直接掛在 `Window` 上),同一組「↓」導覽**立刻正常運作**
  (`Row1` → `Row2`)。**根因確認**:自動幾何鄰居搜尋需要節點被包在一個 `Control`
  底下,直接掛在 `SceneTree.root`(`Window`)這個特例會讓搜尋失效 —— 這與 Claim 1/2/3
  本身無關,是 v1 探針自己的節點結構寫錯,不是引擎對「繞回」這件事的真實答案。
  v2 同時確認 `Control.find_valid_focus_neighbor(side)` 可以直接查詢引擎的搜尋結果,
  不需要透過完整的輸入事件鏈路。
- **v3**(`probe_focus_navigation_v3.gd`)用修正後的節點結構(`Control` wrapper
  包 4 個子節點,結構與 `battle_menu.tscn` 實際規劃一致:回到遊戲/結束回合/分隔線
  (`FOCUS_NONE`)/離開遊戲),一次跑完 Claim 1/2/3,並額外查了下緣對稱情況(非
  AC-M13 要求,僅供參考)。**這是本次採信的最終結果。**

## 執行指令

```bash
"<Godot 4.7.1 執行檔路徑>" --headless --path . -s prototypes/u007-focus-navigation-probe-2026-09-17/probe_focus_navigation_v3.gd
```

逐字輸出:`run_output_v3.txt`(v1/v2 的逐字輸出保留在 `run_output.txt` / `run_output_v2.txt`,
不刪除 —— 本專案紀律:第一次量出來的東西看不懂就換方式重量,三份並存本身是證據鏈)。

## 結論(逐字,來自 `run_output_v3.txt`)

```
Claim 1 (automatic search does not wrap top->bottom)      = true
Claim 2 (focus_neighbor_top=self pins focus, production)  = true
Claim 3 (FOCUS_NONE divider skipped by automatic search)  = true
```

- **Claim 1 為真**:`row1.find_valid_focus_neighbor(SIDE_TOP)` 直接回傳 `<null>`,
  且實際按「↑」後焦點確實留在 `ReturnToBattleRow` —— **自動搜尋本身就不會繞回**,
  即使完全不設定任何 `focus_neighbor_*` 屬性。
- **Claim 2 為真**:顯式設定 `focus_neighbor_top = row1.get_path_to(row1)`(指向自己)
  後,按「↑」焦點仍留在原地。**這是本 story 實際採用的生產機制**(不依賴 Claim 1
  的自動行為,顯式設定使結果不受未來版面調整影響)。
- **Claim 3 為真**:`row2.find_valid_focus_neighbor(SIDE_BOTTOM)` 直接回傳
  `QuitRow`(略過中間 `focus_mode = FOCUS_NONE` 的分隔線),實際按「↓」後焦點
  確實移到 `QuitRow`。
- **附帶發現(非 Claim,但與 U-008 有關)**:v2/v3 執行期間,`CursorState.apply_buffered_navigation()`
  (`src/ui/cursor/cursor_state.gd:611`,透過 `cursor_state_host.gd:404` 的
  `flush_buffered_navigation()` 於每個 `_process()` tick 被呼叫)對這些測試用的
  `ui_up`/`ui_down` 事件印出一次性錯誤:「a NAVIGATION-class ui_* event arrived
  while KEYBOARD_GAMEPAD holds device authority, but the surface registered under
  this target's CursorTypes.SurfaceType tag either has no registration at all...」。
  **這不是本探針的缺陷,是專案自己既有的游標系統程式碼對「未註冊表面上的原生方向鍵導覽」
  的既有反應** —— `CursorStateHost._input()` 的 doc comment 明文只是把事件複製進
  `_frame_events` 緩衝(不呼叫 `accept_event()`/不消費事件),所以不會阻擋 GUI 焦點導覽
  本身,但會讓 `CursorState.diagnostic_surface_navigation_unsupported_count` 持續累加。
  詳細交接見本 story 回報第五節。

## 補充探針:`probe_set_script_timing.gd`(2026-09-17,獨立覆核後補上)

**由來**:獨立覆核(`godot-specialist`)實測 grep 本目錄,`set_script`/`instantiate`/
`.tscn` 皆為零命中——上面三支探針全程用 `Button.new()` 手搭節點,從未載入過
`BattleMenu.tscn` 或呼叫過 `set_script()`。但
`tests/unit/ui/menu/battle_menu_layout_test.gd` 的敏感度證明測試(突變子類別
於進樹前 `set_script()`)卻在檔頭聲稱這個前提「已在本目錄驗證過」——**方向對,
路徑內容不對**,比沒附路徑更容易騙過下一個查核的人。本探針把那句話補成真的。

**量測目的**:
1. 進樹**前** `set_script()`(本專案測試檔實際採用的技巧)是否保留
   `@onready` 節點解析、`_ready()` 填入的實例變數狀態、與繼承呼叫鏈?
2. 對照組:進樹**後**才 `set_script()`(`.claude/rules/test-standards.md`
   類 C 描述的「本專案從未驗證」情境)會發生什麼?

**執行指令**:

```bash
"<Godot 4.7.1 執行檔路徑>" --headless --path . -s prototypes/u007-focus-navigation-probe-2026-09-17/probe_set_script_timing.gd
```

逐字輸出:`run_output_set_script_timing.txt`。本探針**真的載入
`res://src/ui/menu/BattleMenu.tscn`**(非複本),第一次執行因為漏了
`await process_frame`(與 v1 同一類時序陷阱)得到誤導性結果,已在探針檔頭
與下方保留說明,第二次執行(現存 `run_output_set_script_timing.txt`)修正後的
結論如下。

### 結論(逐字,來自 `run_output_set_script_timing.txt`)

- **Case A(進樹前換腳本,本專案測試檔實際使用的時機)—— 安全**:
  `@onready` 節點解析正常(`get_node()` 找得到真實子節點)、預設焦點邏輯正常
  執行(`return_row.has_focus() = true`)、突變子類別覆寫的方法確實被呼叫到
  (`mutant_focus_entered_called = true`)、`super` 呼叫鏈正常(標記文字
  `'▸ 結束回合'` 正確套用)。
- **Case B(進樹後才換腳本,`test-standards.md` 類 C 描述的未驗證情境)——
  🔴 不安全,且已量到具體的壞法**:`get_node()` 仍能解析到**同一顆節點**
  (節點樹本身不受腳本替換影響),**但 `_ready()` 當時填入的實例變數狀態
  (`_row_base_text` 字典)會被重設回宣告時的預設值(空字典)**——導致
  `_apply_unfocused_text()` 對字典取值時直接噴執行期錯誤
  (`Invalid access to property or key ... on a base object of type 'Dictionary'`)。
  **這印證了類 C 原本的疑慮確實成立**:進樹後換腳本不保留舊腳本填入的實例
  變數狀態,只是節點樹結構本身(以及後續呼叫透過新腳本的方法解析)不受影響。

⚠️ **本專案的敏感度證明測試全部只用 Case A(進樹前)**,不受 Case B 這個新發現
的缺陷影響。**Case B 的發現是給整個專案測試手法的一個新事實**,不是本 story
交付範圍要處理的東西——已在交付回報中登記,由協調者決定是否要更新
`test-standards.md` 類 C 的敘述(現行文字只說「本專案從未驗證」,而現在有了
具體、可查證的答案)。

## 刻意未計入的因素

- 只驗了鍵盤方向鍵(`InputEventKey`),未驗手把方向鍵/搖桿(`InputEventJoypadMotion`/
  `InputEventJoypadButton`)—— `Control` 的自動焦點導覽兩者共用同一套內部機制
  (皆映射到 `ui_up`/`ui_down` 等內建動作),但本探針沒有另外注入手把事件實測。
- 未驗證滑鼠 hover 對焦點的影響(`FOCUS_ALL` 也接受滑鼠點擊取得焦點,但本探針
  只測方向鍵導覽路徑)。
- 未驗證 `Button.disabled = true` 時是否被自動搜尋跳過 ——「跳過不可選項目」是
  U-009 的範圍(本 story 的「結束回合」恆為可選),故未在本探針涵蓋。
- 全部在 headless 下執行,`Input.parse_input_event()` / `Viewport.push_input()`
  兩種注入方式皆有測到(見 `run_output_v2.txt`),但真實硬體鍵盤/手把輸入的
  windowed 行為本身沒有另外驗證。
