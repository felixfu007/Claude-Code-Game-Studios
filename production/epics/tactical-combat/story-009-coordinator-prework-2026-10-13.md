# Story 009 協調者前置反查(2026-10-13)

> ⚠️ **本檔把「我量到的事實」與「我推論的建議」分開寫。**
> 理由:同一天 `story-008` 的前置檔給了一個**錯的建議**,被實作者當場推翻 ——
> 而它之所以只推翻建議、保留了事實,正是因為兩者分開寫。**請照樣對待本檔。**

## 〇、本 story 今天剛變大,先讀這個

🔴 **2026-10-13 管理者裁決把 `story-008` 的滑鼠路徑移交本 story。**
本檔的 AC 已新增一項(見該檔),`Depends on` 行也改了。
**完整的五選項評估在 `docs/architecture/cursor-device-authority-for-board-tile-2026-10-13.md`(407 行)**
—— 那份是 `technical-director` 寫的意見書,**裡面有本 story 大部分的設計思考,先讀它再動手。**

## 一、【事實】`_device` 的全部呼叫點,逐類精確計數

```
$ grep -rn "_device\.\|DeviceAuthority" src/ --include=*.gd | grep -v ":\s*#" | grep -v ":##"
src/ui/battle/battle_screen.gd:416:  var _device: DeviceAuthority          ← 宣告
src/ui/battle/battle_screen.gd:968:  _device = DeviceAuthority.new()       ← 建構
src/ui/battle/battle_screen.gd:1115: _device.resolve_frame()               ← 每幀解析
src/ui/battle/battle_screen.gd:2600: if _device.current() == DeviceAuthority.Device.MOUSE:   ← 唯一讀取點
src/ui/battle/device_authority.gd:47: class_name DeviceAuthority
(其餘 17 行全部是 note_* 呼叫)
```

| 類別 | 數量 | 精確指令 |
|---|---|---|
| `note_pad_input()` | **15** | `grep -rn "_device\.note_pad_input()" src/ --include=*.gd \| grep -v ":\s*#" \| wc -l` |
| `note_mouse_motion()` | **2** | 同上換字串 |
| `resolve_frame()` | 1 | `battle_screen.gd:1115` |
| `current()` | **1** | `battle_screen.gd:2600` |
| 宣告 + 建構 | 2 | `:416`、`:968` |

📌 **工作單寫「約 15 處 `note_*`」—— `note_pad_input()` 剛好 15,加上 2 處滑鼠是 17。**
**不是工作單寫錯,是它只數了手把那一類。動手前自己再量一次,行號會漂。**

🔴 **最值得注意的一件事**:`current()` **只有一個讀取點**(`:2600`,`_update_cursor_visual()`
的滑鼠分支)。亦即那 17 處 `note_*` 餵進去的狀態,**全部只為了服務這一個 if**。
**退役它的實質工作量,遠小於 17 這個數字給人的印象。**

## 二、【事實】替代品已經在跑了,不需要新建任何東西

```
$ grep -n "arbitrate_device_authority" src/ui/cursor/cursor_state_host.gd
391:	_state.arbitrate_device_authority(_frame_events)

$ grep -n "^func get_device_authority" -A 2 src/ui/cursor/cursor_state_host.gd
552:func get_device_authority() -> CursorTypes.Authority:
553-	return _state.get_device_authority()
```
**host 已經自動從引擎事件流解析裝置權威(priority −100),公開查詢也已存在。**
所以那 17 處 `note_*` 是在**手動重做一件 host 已經自動在做的事**。

## 三、【事實】`story-008` 已經做完的那一半(不要重做)

提交 `b4c8e6d` + `a01cdd2`,已落地並經協調者獨立重跑驗收:
- `_ready()` 註冊 `BOARD_TILE`,並在 `is_card_play_in_progress()` 的三個轉換點與打牌路徑交接
- `_handle_directional()` **已停止自行寫入** `_cursor_cell`
- `_update_cursor_visual()` 的**鍵盤/手把分支**已改讀 `CursorStateHost.get_current_target()`
- `tree_exited` 安全網(修掉 Autoload 登記表留著已釋放 `BattleScreen` 的跨測試污染)
- **測試在 `tests/integration/ui/battle_cursor_navigation_convergence_test.gd`,檔頭有約 200 行
  前人留下的引擎實跑驗證紀錄 —— 讀它,不要重新發現。**

🔴 **其中一條是回歸鎖**:
`test_directional_navigation_can_select_a_non_default_unit_before_any_selection_exists_today`
—— 它釘住「**未選取任何單位時,鍵盤/手把仍能移動游標去找單位**」(主機端沒有滑鼠,
這是硬性斷點)。**動這一帶時若它變紅,那是真的退步,不是測試過時。**

## 四、【事實】已知且已被管理者接受的兩項代價(不要再拿來當理由停下)

1. **滑鼠奪回高亮將需達 `board_tile_threshold_px` 的累積淨位移**,不再是任意微小移動。
   ```
   $ grep -rn "board_tile_threshold_px" src/ --include=*.gd | grep -v ":\s*#"
   src/ui/cursor/mouse_reclaim_threshold_config.gd:31:@export var board_tile_threshold_px: float = 75.0
   src/ui/cursor/mouse_reclaim_threshold_config.gd:82:			value = board_tile_threshold_px
   ```
   ⚠️ 該檔檔頭自標 **`PROVISIONAL VALUES — an acknowledged gap, not a design decision`**。
   1080p 4× 下一格 128px → 75px ≈ **0.59 格**。
2. **E1(按住方向鍵可無限期否決滑鼠奪權,100% 可重現、所在子機制為使用者明文凍結)
   自此可從主棋盤路徑觸及。**

**兩項都已在管理者裁決時明文揭露並被接受,已寫進本 story 的 AC。**

## 五、【建議,可推翻】三個可編譯單位的切法

🔴 **以下是協調者的推論,不是裁決。** `battle_screen.gd` 實測 **2939 行**,
而本專案對「大型破壞式工作單」有登記在案的失效模式 —— `story-008` 自己就是切成四個單位才落地的。

| 單位 | 內容 | 性質 |
|---|---|---|
| 1 | 🔴 **先做滑鼠路徑**(`_TargetRetargetActor` 加 pending 欄位 + owner 方法,閘門讀 `get_device_authority()`) | 破壞式,但範圍小 |
| 2 | `:2600` 那唯一一個 `current()` 讀取點改讀 host | 一行 |
| 3 | 17 處 `note_*` 移除 + `device_authority.gd` 整份退役 + 建構呼叫移除 | 機械性,但量大 |

**為什麼建議這個順序**:單位 3 是純刪除,**但在單位 1、2 完成之前刪掉 `_device`,
`:2600` 那個 if 會當場沒有來源** —— 那正是工作單原本那條「結構性依賴」講的事。

⚠️ **協調者沒有驗證過這個切法可行。** 若你讀完意見書後認為有更好的切法,直接用你的,寫明理由。
