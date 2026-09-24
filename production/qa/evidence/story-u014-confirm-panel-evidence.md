# Story U-014 證據檔:確認面板 S3(不含截圖)

> **型別**:UI(ADVISORY)。依派工單第 3 節管理者裁決,**本批不做任何截圖證據**——
> 管理者座位旁會有人經過,遊戲畫面不得出現在螢幕上,本批全程 headless,不曾開窗。
> 本檔以自動化測試(`tests/integration/ui/card_confirm_panel_test.gd`)+ 本文字說明為證據。
>
> 🔴 本檔記錄的是**三個批次**疊加後的最終狀態,不是單一次交付:①面板本體與 S3 接線、
> ②獨立覆核抓到並修正的旗標順序缺陷、③管理者裁決「消除重複」後的架構重構
> (連帶重寫/刪除兩條回歸測試)+ 補上 AC-U14 涵蓋缺口。三批的過程各自保留在下方對應節,
> 不合併成一句「一次做對」。

## 交付物(最終狀態)

- `src/ui/battle/card_confirm_panel.gd`(新)
- `src/ui/battle/CardConfirmPanel.tscn`(新)
- `src/ui/battle/battle_screen.gd`(接線:S3 開關、確認/取消鍵分派、AC-U11 去重、
  AC-U13 殘留清除、`_open_card_confirm_panel()`;第二批修正旗標順序缺陷;
  第三批改為讀 `BattleController` 的唯讀 getter,移除畫面端鏡像欄位)
- `src/ui/battle/BattleScreen.tscn`(新增 `UILayer/CardConfirmPanel` 節點)
- `src/gameplay/cards/card_play_session.gd`(第三批新增:`selected_card()`/
  `selected_target_a()`/`selected_target_b()` 三個唯讀 getter,純新增、不改任何既有行為)
- `src/gameplay/battle/battle_controller.gd`(第三批新增:對應三個純轉發方法,
  同 `is_card_play_in_progress()` 的既有形狀——`_card_play_session == null` 回傳安全預設,
  否則轉發,零額外判斷邏輯)
- `tests/integration/ui/card_confirm_panel_test.gd`(最終 12 條測試)
- 本證據檔

## 最終測試結果(headless,實際執行,協調者已獨立重跑核對一致)

指令(產生下方數字的指令,不要手抄數字本身——見 `technical-preferences.md` 對「手抄的數字
必然漂移」的既有登記):

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s tests/gdunit4_runner.gd
```

原始輸出:

```
Overall Summary: 951 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (75/75)
Executed test cases : (951/951)
Exit code: 100
```

唯一一條紅的(既有、已核准的刻意紅燈,非本 story 造成,不要去修):

```
res://tests/unit/gameplay/affinity/affinity_phi_provider_test.gd > test_phi_reflects_a_pairing_polarity_flip_made_after_construction FAILED 7ms
```

`grep -c "SCRIPT ERROR"` 對本次執行輸出為 `0`。

## 逐條 AC 涵蓋

| AC | 涵蓋測試 | 說明 |
|---|---|---|
| **AC-U1** | `test_damage_preview_reflects_new_effective_atk_after_confirm` | 呼叫 `BattleState.preview_damage()` 兩次(confirm 前/後),斷言差值恰為 `delta_atk`——不自算傷害公式,取自與結算同一份查詢 |
| **AC-U5** | `test_gamepad_only_path_completes_full_and_cancel_flows` | 純 `InputEventJoypadButton`(不含任何 `InputEventKey`)分別驗證 S3 的確認與取消皆可達 |
| **AC-U7** | `test_cancel_before_confirm_leaves_zero_new_records` | 用間諜 `AffinityWritePort` 斷言確認前取消時 `append_record()` 呼叫次數為 0 |
| **AC-U11** | `test_second_confirm_same_frame_applies_only_once` | 同幀鍵盤+手把各送一次 `battle_confirm`,斷言目標只被附加一筆修正 |
| **AC-U13** | `test_confirm_panel_丙類_reflects_player_selected_pair_not_card_fields`、`test_confirm_panel_丙類_pair_updates_after_reselecting_without_residue` | 卡片 `affinity_character_a/b` 故意填不存在的 99/98;面板顯示的姓名來自玩家實際選取;換一對後斷言前一對姓名不殘留(`not_contains`) |
| **AC-U14** | `test_confirm_panel_arrow_layout_required_two_column_no_arrow_variant_must_fail`、`test_confirm_panel_丙類_strength_field_shows_arrow_format_when_available`、`test_confirm_panel_丙類_strength_field_shows_placeholder_not_zero_when_unavailable` | 判準函式對「兩欄無箭頭」版本斷言為 false;`strength_available=true` 時直接驅動元件本體、斷言其輸出通過箭頭格式判準(第三批新增,見下方「AC-U14 涵蓋缺口」節);佔位提示不得顯示 0 或省略欄位,且不得被誤判為合法箭頭格式 |

另外兩條(甲類欄位)不對應任何單一 AC 編號,但直接落實 Implementation Notes 1/2 與
GDD UI Requirements #7:

- `test_confirm_panel_甲類_shows_delta_atk_def_with_sign_and_zero_visible`——`ΔDEF=0` 仍必須顯示
- `test_confirm_panel_甲類_shows_per_entry_modifiers_alongside_merged_effective_value`——逐條修正與合併有效值並列,不得互相取代;合併值用 `CardModifierRules.effective_atk/effective_def`(與生產程式碼相同函式)計算預期值,不重新實作公式

另有一條不對應任何單一 AC、但保護第二批修正的防禦分支(見下方「第二批」節):
`test_open_confirm_panel_with_selected_card_lying_null_does_not_leave_card_confirming_stuck_true`。

## 第二批:獨立覆核抓到的缺陷與修正

**覆核者的判定只到 (C) 級——讀程式碼推導出崩潰,自陳未經引擎驗證**(覆核者自己的探針
兩次都沒跑成)。**本 story 的處理是用注入把它從 (C) 級變成引擎證實的事實**,這是本專案
明文要求的做法(見 `.claude/docs/technical-preferences.md`「(A) 的精確定義」)。

**缺陷一:`_open_card_confirm_panel()` 把 `_card_confirming = true` 設在 null 檢查之前。**
早退分支對 null card 早退時,`_card_confirming` 會殘留 `true`,讓 `_input()` 誤把後續按鍵
導向「S3 進行中」分支卻沒有面板資料。修法:把該賦值移到 null 檢查通過之後。
**注入驗證**:暫時把賦值搬回函式最前面重現舊行為,跑全套,原始輸出:
```
res://tests/integration/ui/card_confirm_panel_test.gd > test_open_confirm_panel_with_null_card_does_not_leave_card_confirming_stuck_true FAILED 144ms
```

**缺陷二:`_handle_card_confirm_cancel_transition()` 對 `_card_confirm_card.category` 完全
沒有 null 防護——與缺陷一同一個崩潰形狀,只是換了呼叫點。** 修法:加 null 檢查,
category 未知時防禦性清空兩個目標鏡像。**注入驗證**:暫時把 null 檢查拿掉,跑全套,
原始輸出逐字重現覆核者的推導:
```
SCRIPT ERROR: Invalid access to property or key 'category' on a base object of type 'Nil'.
res://tests/integration/ui/card_confirm_panel_test.gd > test_handle_card_confirm_cancel_transition_with_null_card_does_not_crash FAILED 169ms
```

兩次注入後皆已還原成修正版本,並各自跑過全套確認轉綠。

## 第三批:管理者裁決「消除重複」與其後果

**裁決**(`production/session-state/active.md` 第六十六批,提交 `70eb0e7`)：`card_play_session.gd`
加唯讀 getter,`battle_screen.gd` 不再自行維護鏡像。裁決依據:①`card_play_session.gd`
沒有任何「刻意不對外公開選取狀態」的設計理由記載;②第二批的覆核已逐分支比對過,
鏡像與真實轉移表當時完全一致——這次改動買的是**結構保證**,不是修 bug,行為不應改變。

**做了什麼**:
1. `CardPlaySession` 新增三個唯讀 getter:`selected_card()`/`selected_target_a()`/
   `selected_target_b()`,純新增,直接讀出已存在的私有欄位。
2. `BattleController` 新增三個對應的純轉發方法,形狀比照既有的 `is_card_play_in_progress()`
   (`_card_play_session == null` 回傳安全預設,否則轉發,零判斷邏輯)——延續
   「畫面只透過 `BattleController` 認識 `CardPlaySession`」這條既有架構邊界,
   不讓正式程式碼繞過去直接碰 `_controller._card_play_session` 的私有欄位。
3. `battle_screen.gd` 移除 `_card_confirm_card`/`_card_confirm_target_a`/`_card_confirm_target_b`
   三個欄位與所有讀寫點,`_open_card_confirm_panel()` 改讀
   `_controller.selected_card()`/`selected_target_a()`/`selected_target_b()`。
   `_handle_card_confirm_cancel_transition()` 因此不再需要判斷卡片 category 才能決定清哪個
   目標鏡像(沒有鏡像可清了)——整段 category 分支與其 null 防護一併移除,函式大幅簡化。

**兩條第二批寫的回歸測試,一條改寫、一條刪除,理由逐條交代**(不是因為欄位改名了才動,
是先判斷各自防禦的失效模式在新架構下是否還可能發生):

- **`test_handle_card_confirm_cancel_transition_with_null_card_does_not_crash`——刪除。**
  它防禦的那段程式碼(`_card_confirm_card.category` 的解參考與其 null 防護)已經整段被移除,
  不是被繞過或變得難以觸發——**沒有程式碼留下,就沒有東西可以測**。
- **`test_open_confirm_panel_with_null_card_does_not_leave_card_confirming_stuck_true`——改寫,
  不是刪除**,改名為
  `test_open_confirm_panel_with_selected_card_lying_null_does_not_leave_card_confirming_stuck_true`。
  逐步核對 `card_play_session.gd` 的狀態機後判定:能讓 `_step` 走到 `SELECTING_TARGET`/
  `SELECTING_TARGET_B`/`CONFIRMING` 的每一條路徑都必然先經過 `select_card()` 設定
  `_selected_card`(`select_target()`/`legal_targets()` 自己的本體都會解參考
  `_selected_card.category` 才能決定下一步,若 `_selected_card` 是 null,這兩個方法自己會先
  崩潰,不會讓呼叫端看到「成功」)——**舊架構下讓這個分支被觸發的成因(畫面自己的鏡像
  可能跟真實 session 失步)已經隨鏡像本身被移除而結構上不再可能自然發生。**
  但 `_open_card_confirm_panel()` 裡的 null 防禦分支選擇**保留**(防禦性判斷,防未來有人
  不小心破壞 `CardPlaySession` 自己的不變量),因此改寫測試,改用一個刻意說謊的間諜
  `CardPlaySession` 子類別(`_MutantCardPlaySessionLiesAboutSelectedCard`,覆寫
  `selected_card()` 使其回傳 null,其餘方法皆不覆寫、真實行為不變)來觸發這個防禦分支,
  讓它繼續有測試覆蓋,而不是變成一段沒有人知道還算不算數的死碼。
  **這個新測試的觸發情境是刻意的、對抗性的注入(覆寫一個單行 getter 說謊)**,不是重現
  一個狀態機自然會走到的情境——這點在測試檔與 `_open_card_confirm_panel()` 的 doc comment
  裡都已如實標註,不偽裝成「自然發生的 bug」。

## AC-U14 涵蓋缺口(第三批新增)

獨立覆核指出:既有測試只驗過 `strength_available=false`(佔位提示)那一支,若有人把
元件裡呼叫 `format_strength_arrow()` 那一行改壞成兩欄無箭頭,而兩個 static 函式本身不變,
既有測試抓不到。新增 `test_confirm_panel_丙類_strength_field_shows_arrow_format_when_available`,
直接以 `strength_available=true` 驅動 `CardConfirmPanel` 本體,斷言
`diagnostic_strength_text()` 通過 `text_uses_required_arrow_format()` 判準。

**已驗紅燈**:暫時把 `card_confirm_panel.gd` 裡
`format_strength_arrow(current_strength, projected_strength) if strength_available`
改成兩欄無箭頭格式(`"%s\t%s" % [format_signed(...), format_signed(...)]`),跑全套,
原始輸出:
```
res://tests/integration/ui/card_confirm_panel_test.gd > test_confirm_panel_丙類_strength_field_shows_arrow_format_when_available FAILED 65ms
Overall Summary: 949 test cases | 0 errors | 3 failures | 0 flaky | 0 skipped | 0 orphans |
```
(總數 949 而非 951、失敗數 3 而非 2 具名測試,皆為本專案已登記的既知形狀——一條失敗
會中止同一套件裡排在後面的測試,且 `failures` 數的是失敗斷言不是失敗測試,非新問題。)
還原修正後重跑,轉綠,全套回到 951/0/1/0。

## 涵蓋範圍的誠實揭露(原始登記,照實保留)

🔴 **本檔測試不透過真實 `CursorStateHost` 裁定管線驅動「選目標」這一步。**
`_apply_target_confirm_from_cursor_state()` 內的目標選取,本檔改用「直接呼叫
`BattleController.select_target()`/`select_second_target()`(真實呼叫,非重新實作)」的方式
驅動到 CONFIRMING,不透過真實游標事件走完整條 ADR-0005 機制六管線。理由:那條管線是
U-013 自己的既有職責與既有測試涵蓋範圍(`tests/integration/ui/card_target_selection_test.gd`),
重新驅動一次只會重覆造成本 story 沒有新增的耦合。
📌 第三批之後,這段驅動方式**不再需要手動指派任何鏡像欄位**(舊版本需要模擬
`_card_confirm_target_a/_b` 的賦值;新版本讀的是 `CardPlaySession` 真實的內部狀態,
真實呼叫本身就會讓它正確)。

⚠️ **未寫常駐 `test_sensitivity_proof_*`**(依 `.claude/rules/test-standards.md` 的門檻誠實
登記,非裝飾)。本 story 三批加總的敏感度證明,採用的是「暫時改壞生產程式碼 → 跑 → 轉紅
→ 還原 → 跑 → 轉綠」這個手動注入格式,原始輸出留在本檔各節,**不是**該規則要求的常駐
間諜子類別 + `test_sensitivity_proof_*` 形式(該規則明文:手動注入已淘汰,理由是它在版本庫
裡不留任何痕跡——本檔試圖用「把原始輸出寫進證據檔」部分緩解這一點,但仍不等同常駐測試)。
逐條判定:
- `test_confirm_panel_arrow_layout_required_two_column_no_arrow_variant_must_fail`——
  受測對象 `CardConfirmPanel.format_strength_arrow`/`text_uses_required_arrow_format`
  皆為 `static func`,無繼承鏈可覆寫子類別注入突變,屬本專案登記的 A 類(「已知證明不了」)。
- 其餘 11 條——理論上可用「`set_script()` 換腳本」或「換掉 `_card_play_session`」等本檔
  已示範過的手法建立常駐敏感度證明,但**尚未實作**,留待下一輪覆核時補做。

## 已知會落在測試範圍以外的事(照實保留,不因收工而刪除)

- **好感度數值欄位維持留白+提示**(2026-09-24 管理者裁決),`card_confirm_strength_provider`
  Callable 保留未接上任何真實資料來源。**這不是本 story 的缺陷**——UX-13
  (`combat_strength_read` 在 `src/` 尚無實作)是 `affinity-data-pool` epic 的 S-007 的職責,
  本 story 交付的是箭頭版面本體與留白+提示的正確分支,兩者皆已測試覆蓋
  (`test_confirm_panel_丙類_strength_field_shows_arrow_format_when_available` 驗
  `true` 分支、`test_confirm_panel_丙類_strength_field_shows_placeholder_not_zero_when_unavailable`
  驗 `false` 分支)。
- **像素/版面截圖驗證本批不做**(管理者裁決全程 headless,座位旁會有人經過)——
  `CardConfirmPanel` 的版面尺寸常數(`PANEL_WIDTH_FPX_MULTIPLIER` 等)是本檔自己的判斷,
  尚未經過任何實機或灰階複驗,doc comment 內已如實揭露。
- **未做「從頭讀整份 story 逐條 AC 對照」的總覆核**——本檔的「逐條 AC 涵蓋」節是三批
  分別累加寫成的,沒有一次性重新對照 `story-u014-confirm-panel.md` 全文逐條複核過。
  下一輪若需要這個層級的確認,應獨立進行。
