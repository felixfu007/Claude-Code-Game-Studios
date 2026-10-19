# 殼層(標題/主選單)可行性 —— 場景切換與 Autoload 跨場景生命週期實測(2026-10-19)

> **狀態**:量測完成,方案書,**不裁決路線**。
> **回答對象**:`docs/reviews/settings-screen-has-nowhere-to-live-2026-10-16.md` 第四節末
> 「協調者未查證」那句 —— `CursorStateHost` 跨場景切換的行為。

## 一、量測方法與物證

依 `.claude/docs/technical-preferences.md` 第 5 點紀律:`load()` production 真正啟動的
`res://src/ui/battle/BattleScreen.tscn`(`project.godot` 的 `run/main_scene`),不自組替身節點
鏈。headless 可跑(本次是結構/狀態量測,非像素)。探針產物:
`prototypes/shell-layer-scene-switch-probe-2026-10-19/`
(`probe_scene_switch.gd`、`probe_blank_scene.gd`、`ProbeBlankScene.tscn`、
`run_output_headless.txt`)。**ENGINE EXIT = 0**,全程零 `SCRIPT ERROR` / `WARNING`。

## 二、四題逐一結論

**Q1 —— `CursorStateHost` 全程同一實例,未被重建:**
```
Q1-SETUP: CursorStateHost.get_instance_id() before = 30484202971
Q1-FINAL: instance_id=30484202971 same_as_original=true
Q1-EXTRA: ... diagnostic_process_tick_count ... = 5
```

**Q2 —— 🔴 本題結論需要更正(由協調者指出,已查證屬實):原判定「tree_exited 安全網
成功解除了 BOARD_TILE」方向沒錯,但那個安全網不在 `CursorSurfaceRegistry` 裡,是
`BattleScreen` 自己手工接的。** 查證:
```
$ grep -n "tree_exited" src/ui/cursor/cursor_surface_registry.gd
341:## Auto-deregisters on [signal Node.tree_exited] — NOT   ← 只服務 Table 2(原生指標例外白名單)
$ grep -n "tree_exited" src/ui/battle/battle_screen.gd
1301:	tree_exited.connect(func() -> void: CursorStateHost.unregister_surface(CursorTypes.SurfaceType.BOARD_TILE))
```
`cursor_surface_registry.gd` 類別註解明文:Table 1(一般表面註冊)「lifecycle managed via
explicit unregister calls(no automatic cleanup)」。本次測到的乾淨釋放,**完全是
`battle_screen.gd:1301` 那一行手動接線的結果**,不是引擎或註冊表通用保障。該檔自己的註解
(1282~1301 行)記載了不接會怎樣:`CursorNavigationApplier._process()` 會在之後某個完全
無關的場景撞到已釋放節點,逐字 `SCRIPT ERROR: Trying to return a previously freed
instance`,實機驗證、曾經純因執行順序弄壞 `battle_menu_layout_test.gd`。探針物證:
```
Q2-BEFORE-SWITCH: ... DUPLICATE_TAG_REJECTED ...  (#1 自己佔著 BOARD_TILE)
PROBE: battle_instance_1.tree_exited fired at frame=1
Q2-AFTER-SWITCH: ... REGISTERED ...               (tag 已釋放)
Q4-BOARD-TILE: ... DUPLICATE_TAG_REJECTED ...      (#2 乾淨重新佔住)
```

**Q3 —— `change_scene_to_file()` 是混合時機,不是單純「立即」或單純「延後到幀尾」:**
舊場景的移除(`tree_exiting`/`tree_exited`)在呼叫當下**同步**觸發,呼叫端下一行照樣
執行、未被掛起;但新場景的 instantiate/add_child/`_ready()` 被延後到本幀稍後的
deferred-call 處理才跑(仍在同一個 frame 編號內,早於下一次 `_process` tick,但晚於
呼叫端自己接下來的程式碼)。
```
Q3-BEFORE-CALL: battle_instance_1.is_inside_tree()=true is_instance_valid=true
PROBE: battle_instance_1.tree_exited fired at frame=1
Q3-RETURN-VALUE: change_scene_to_file() returned Error=0 immediately upon return
Q3-IMMEDIATELY-AFTER: battle_instance_1.is_inside_tree()=false is_instance_valid=true frame=1
Q3-CALLER-CONTINUES: this line executes immediately after the call returned
PROBE[BlankScene]: _ready() fired at frame=1 instance_id=74759276263
Q3-AFTER-1-FRAME: battle_instance_1 is_instance_valid=false frame=2 current_scene=ProbeBlankScene
```
**實作後果**:呼叫 `change_scene_to_file()` 之後緊接著的程式碼不可假設新場景已掛上樹;
被切走的舊場景物件在呼叫當下已離樹但尚未真正釋放(下一幀才失效)。

**Q4 —— 來回切換(BattleScreen → 空白 → BattleScreen)全程乾淨,第二個 BattleScreen
是全新實例,非同一物件被搬回樹:**
```
Q4-RETURN-VALUE: change_scene_to_file(BattleScreen) returned Error=0
Q4-RESULT: battle_instance_2 is_inside_tree=true instance_id=74910271646  (異於已釋放的 #1)
Q4-BOARD-TILE: register_surface(dummy) after round-trip -> DUPLICATE_TAG_REJECTED
```

**未驗證項(逐項揭露)**:僅測一種 Surface tag(`BOARD_TILE`)、一個 Autoload;未測多
Autoload 共存順序;未開窗驗證像素/視覺過場;未測 ADR-0005 機制五
(`_frame_events`/`_arbitration_suspended`)在切場景瞬間是否殘留 ——
`suspend_arbitration()` 從未被任何殼層程式碼呼叫過。

## 三、最小殼層需要什麼

- **新增場景**:至少一個「戰鬥外」容器場景(標題/主選單),由某節點呼叫
  `get_tree().change_scene_to_file()`。
- **誰負責切換**:待裁決;Q3 證明呼叫端只要自行 `await` 至少一幀,不必擔心新場景
  「還沒掛上」。
- 🔴 **離開戰鬥的生命週期硬性義務**:任何向 `CursorStateHost` 註冊
  `CursorSurfaceRegistry` 表面的畫面,**必須自己接一條 `tree_exited → unregister_surface`**,
  比照 `battle_screen.gd:1301` —— 這不是風格建議,是本專案已有一次真實事故逼出來的紀律
  (見上方 Q2),而 Table 1 設計上刻意不自動清理。
- **意外的好消息**:`BattleMenu.quit_callable`(`src/ui/menu/battle_menu.gd:373`)是現成
  可注入點 —— M4「離開確認」預設呼叫 `get_tree().quit()`,而 `BattleScreen` 目前從未注入它
  (已 grep 確認零命中)。把「離開戰鬥」從「結束遊戲」改成「切回主選單」,在這一點上
  不必碰 `BattleMenu` 本體,只需殼層接線時注入一個改叫 `change_scene_to_file()` 的 `Callable`。
- **仍待裁決**:`BattleScreen` 的關卡資料全部在 `_ready()` 讀取(terrain/roster/
  affinity/cards 四個路徑常數),已有 `*_path_override` 注入點
  (`battle_screen.gd` 433~471 行)可用於日後「選關卡」,本次未重新驗證,僅確認其存在。

## 四、要不要一份 ADR

**不建議現在寫。** 理由:
- `coding-standards.md` 規則是「只在跨系統契約時才寫 ADR」。本次量測顯示場景切換與既有
  ADR-0005 的唯一交集,就是上面那條「`tree_exited` 解除註冊」義務 —— 這是「新畫面要遵守
  舊契約的既有規則」,不是新契約,不構成跨系統。
- 流程劑量上限預期剩餘系統僅再產生 0~1 份新 ADR;現有 5 份中仍有 1 份(0004)`Proposed`。
- 兩個看似需要跨系統協調的點(CursorSurfaceRegistry 解除註冊義務、存檔系統要不要認得
  「戰鬥外」狀態)都不是新技術決策,是把既有規則套用到新場景 —— 建議寫進該 story 的
  設計文件 Implementation Note,不必升格 ADR。
- 若日後量到場景切換與 ADR-0005 機制五有真正衝突(上方「未驗證項」已列),屆時才有
  寫 ADR 的理由。

## 五、更新甲/乙/丙三條路的技術成本

- **甲**(`BattleMenu` 加一列唯讀顯示)、**乙**(戰鬥選單內直接改):技術成本不變 ——
  兩者皆零場景切換,本次量測對它們無影響。
- **丙**(最小標題/主選單):原文件寫「很可能需要一次 ADR」與「未查證是否與 ADR-0005
  衝突」,現在都有答案:
  - **不需要 ADR**(第四節)。
  - **與 ADR-0005 不衝突** —— `CursorStateHost` 全程同一實例、乾淨存活過場景切換(Q1),
    既有的 BOARD_TILE 註冊/解除註冊模式經實測可行(Q2)。
  - 🔴 但**新增成本一項**:丙案要求殼層的每個新畫面,若向 `CursorStateHost` 註冊表面,
    都必須複製 `battle_screen.gd:1301` 那條 `tree_exited` 安全網 —— 一行等級,但是
    每個新畫面都要記得做,無自動檢查。
  - **額外利多**:`BattleMenu.quit_callable` 現成可注入(第三節),降低「離開戰鬥回到
    主選單」這段生命週期的成本。
  - 丙案仍真實存在的成本:新場景本身、`run/main_scene` 要不要改指向殼層(目前指向
    `BattleScreen`)、存檔/關卡選擇等下游功能仍待設計,本次皆未觸及。

## 六、本檔不涵蓋什麼

- **不裁決甲/乙/丙選哪條** —— 交管理者。
- 未開窗驗證任何像素/視覺層面的場景過場(本題屬結構/狀態,依量測紀律 headless 已足夠)。
- 未測多 Autoload 共存順序(本專案目前只有一個 Autoload)、未測 ADR-0005 機制五在切場景
  瞬間的殘留風險(已列入第二節未驗證項)。
- 未查證 `settings-screen-has-nowhere-to-live-2026-10-16.md` 第五節自留的另一缺口
  (#8/#11 是否也預設「戰鬥外狀態」)。
- 未重新驗證 `*_path_override` 注入點在殼層情境下的實際行為,僅確認其存在。
