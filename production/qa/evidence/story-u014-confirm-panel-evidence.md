# Story U-014 證據檔:確認面板 S3(不含截圖)

> **型別**:UI(ADVISORY)。依派工單第 3 節管理者裁決,**本批不做任何截圖證據**——
> 管理者座位旁會有人經過,遊戲畫面不得出現在螢幕上,本批全程 headless,不曾開窗。
> 本檔以自動化測試(`tests/integration/ui/card_confirm_panel_test.gd`)+ 本文字說明為證據。

## 交付物

- `src/ui/battle/card_confirm_panel.gd`(新)
- `src/ui/battle/CardConfirmPanel.tscn`(新)
- `src/ui/battle/battle_screen.gd`(接線:S3 開關、確認/取消鍵分派、AC-U11 去重、
  AC-U13 殘留清除、`_open_card_confirm_panel()`)
- `src/ui/battle/BattleScreen.tscn`(新增 `UILayer/CardConfirmPanel` 節點)
- `tests/integration/ui/card_confirm_panel_test.gd`(新,10 條測試)
- 本證據檔

## 測試結果(headless,實際執行)

指令:

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s tests/gdunit4_runner.gd
```

原始輸出(第二次跑,已修掉第一次跑發現的既有測試回歸):

```
Overall Summary: 949 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (75/75)
Executed test cases : (949/949)
Exit code: 100
```

唯一一條紅的(既有、已核准的刻意紅燈,非本批造成):

```
res://tests/unit/gameplay/affinity/affinity_phi_provider_test.gd > test_phi_reflects_a_pairing_polarity_flip_made_after_construction FAILED 12ms
```

**基線 939 條 + 本批新增 10 條 = 949 條,全數執行,除既有那條紅燈外全過,0 orphans。**

### 🔴 第一次跑時發現並修掉的既有測試回歸(誠實記錄,不是本批一次做對)

第一次執行結果為 `949 test cases | 1 errors | 1 failures`——新增的 1 條 `errors` 是
`tests/integration/ui/card_target_selection_test.gd` 的
`test_sensitivity_proof_illegal_tile_confirm_legality_check_skipped_regression_detected`
出現 `SCRIPT ERROR: Invalid access to property or key 'id' on a base object of type 'Nil'.`。

**成因**:該既有測試(U-013 遺留)直接呼叫 `BattleController.select_card()`,繞過
`battle_screen.gd` 的 `_confirm_selected_card()`,因此本 story 新增的 `_card_confirm_card`
鏡像欄位從未被設定(維持 `null`)。該測試後續呼叫 `_apply_target_confirm_from_cursor_state()`
讓一個刻意跳過合法性檢查的 mutant session 前進到 CONFIRMING,觸發本 story 新增的
`_after_target_selection_advanced()` → `_open_card_confirm_panel()` 呼叫鏈,而後者原本直接
讀 `_card_confirm_card.id`,在 `_card_confirm_card == null` 時當場崩潰。

**修法**:`_open_card_confirm_panel()` 開頭加一道 `if card == null: push_error(...); return`
的防禦性早退——不猜測、不靜默,響亮地記錄下「有呼叫端繞過本畫面自己的封裝方法」這件事,
同時讓該既有測試原本要驗的斷言(`session.step()` 已前進到 CONFIRMING)維持有效。
第二次執行確認修復生效,無新回歸。

## 逐條 AC 涵蓋

| AC | 涵蓋測試 | 說明 |
|---|---|---|
| **AC-U1** | `test_damage_preview_reflects_new_effective_atk_after_confirm` | 呼叫 `BattleState.preview_damage()` 兩次(confirm 前/後),斷言差值恰為 `delta_atk`——不自算傷害公式,取自與結算同一份查詢 |
| **AC-U5** | `test_gamepad_only_path_completes_full_and_cancel_flows` | 純 `InputEventJoypadButton`(不含任何 `InputEventKey`)分別驗證 S3 的確認與取消皆可達 |
| **AC-U7** | `test_cancel_before_confirm_leaves_zero_new_records` | 用間諜 `AffinityWritePort` 斷言確認前取消時 `append_record()` 呼叫次數為 0 |
| **AC-U11** | `test_second_confirm_same_frame_applies_only_once` | 同幀鍵盤+手把各送一次 `battle_confirm`,斷言目標只被附加一筆修正 |
| **AC-U13** | `test_confirm_panel_丙類_reflects_player_selected_pair_not_card_fields`、`test_confirm_panel_丙類_pair_updates_after_reselecting_without_residue` | 卡片 `affinity_character_a/b` 故意填不存在的 99/98;面板顯示的姓名來自玩家實際選取;換一對後斷言前一對姓名不殘留(`not_contains`) |
| **AC-U14** | `test_confirm_panel_arrow_layout_required_two_column_no_arrow_variant_must_fail`、`test_confirm_panel_丙類_strength_field_shows_placeholder_not_zero_when_unavailable` | 判準函式對「兩欄無箭頭」版本斷言為 false;佔位提示不得顯示 0 或省略欄位,且不得被誤判為合法箭頭格式 |

另外兩條(甲類欄位)不對應任何單一 AC 編號,但直接落實 Implementation Notes 1/2 與
GDD UI Requirements #7:

- `test_confirm_panel_甲類_shows_delta_atk_def_with_sign_and_zero_visible`——`ΔDEF=0` 仍必須顯示
- `test_confirm_panel_甲類_shows_per_entry_modifiers_alongside_merged_effective_value`——逐條修正與合併有效值並列,不得互相取代;合併值用 `CardModifierRules.effective_atk/effective_def`(與生產程式碼相同函式)計算預期值,不重新實作公式

## 涵蓋範圍的誠實揭露

🔴 **本檔測試不透過真實 `CursorStateHost` 裁定管線驅動「選目標」這一步。**
`_apply_target_confirm_from_cursor_state()` 內新增的兩行賦值
(`_card_confirm_target_a/_b = unit.id`)本身,是靠直接呼叫
`BattleController.select_target()`/`select_second_target()`(真實呼叫,非重新實作)
+ 手動指派這兩個欄位(模擬那兩行賦值會做的事)來驅動,不是靠真實游標事件走完整條
ADR-0005 機制六管線。理由:那條管線是 U-013 自己的既有職責與既有測試涵蓋範圍
(`tests/integration/ui/card_target_selection_test.gd`),重新驅動一次只會重覆造成本
story 沒有新增的耦合。**這代表:那兩行賦值本身「有沒有從真實呼叫端接對」是讀過程式碼
確認過的,不是被本檔測試直接證明的。**

⚠️ 兩項未做的敏感度證明(依 `.claude/rules/test-standards.md` 的門檻誠實登記,非裝飾):
本批 10 條測試皆未撰寫對應的 `test_sensitivity_proof_*`。逐條判定:

- `test_confirm_panel_arrow_layout_required_two_column_no_arrow_variant_must_fail`——
  受測對象 `CardConfirmPanel.format_strength_arrow`/`text_uses_required_arrow_format`
  皆為 `static func`,無繼承鏈可覆寫子類別注入突變,屬本專案登記的 A 類(「已知證明不了」)。
- 其餘 9 條——受測對象是 `BattleScreen` 的一般 instance method
  (`_open_card_confirm_panel()`/`_apply_pending_card_confirm()`/
  `_handle_card_confirm_cancel_transition()`),理論上可用同一套「`set_script()` 換腳本 +
  覆寫特定方法」手法建立敏感度證明(同本批新測試已重度使用的 `_MutantCardPlaySessionSkipsLegalityCheck`
  等注入慣例),但**本批未實作**——時間分配優先給「10 條測試涵蓋 story 列的驗收範圍」,
  敏感度證明留待下一輪覆核時補做。這是誠實登記的缺口,不是判定「做不到」。

## 已知會落在測試範圍以外的事(不影響本批交付判定)

- **好感度數值欄位維持留白+提示**(2026-09-24 管理者裁決),`card_confirm_strength_provider`
  Callable 保留未接上任何真實資料來源,`test_confirm_panel_丙類_strength_field_shows_placeholder_not_zero_when_unavailable`
  驗的正是「今天唯一存在的真實狀態」。
- **像素/版面截圖驗證本批不做**(管理者裁決全程 headless)——`CardConfirmPanel` 的
  版面尺寸常數(`PANEL_WIDTH_FPX_MULTIPLIER` 等)是本檔自己的判斷,尚未經過任何實機或
  灰階複驗,doc comment 內已如實揭露。
