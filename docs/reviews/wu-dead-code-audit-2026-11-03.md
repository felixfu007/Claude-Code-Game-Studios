# 戊(麥子健)舊機制死碼盤點 — 2026-11-03

> 唯讀盤點(lead-programmer)。未改任何程式碼、測試或既有檔。**未跑測試、未跑引擎** —— 下列「死/活」判定來自讀碼與 grep,等級屬讀碼推論,不是引擎實測。
> 現行規則依據:`docs/reviews/affinity-core-redesign-spec-amend2-2026-10-30.md`(獨行表:d=1 → -1、d=2 → +2、d>=3 或無友軍 → 0;**出手條件取消**;新增「留一手」:旗標單位從 d=2 格出手少打 1)+ 現行 `src/gameplay/battle/battle_state.gd` / `combat_rules.gd`。

## 一句話結論

協調者清單 8 項中:**5 項確定死**(程式會跑到、但永遠不改變任何結果)、**1 項部分死**(函式活、一個參數死)、**2 項不是死碼**(常數與留一手本身都是現行規則在用,只是「寫死在程式裡」屬技術債)。
**移動預覽雙值整個功能目前已不會讓玩家看到任何雙值**,但它是管理者裁決做的,所以是否清除需要管理者明確點頭。

## 1. 逐項表格

| # | 符號 / 檔案 | 現行規則下 | 證據 | 刪除連帶影響(測試) | 會不會弄壞 prototypes |
|---|---|---|---|---|---|
| 1 | `CombatRules.lone_guard_effective(lone, _attacked)` — `src/gameplay/combat/combat_rules.gd:68` | **死**。函式本體就是 `return lone`,第二參數底線開頭、完全不用。唯一呼叫者是 `lone_guard_if_at`。 | `combat_rules.gd:68-69`:`static func lone_guard_effective(lone: int, _attacked: bool) -> int:` / `return lone`;檔內註解自述「Kept only so existing callers still compile; a follow-up story removes it」。 | `combat_rules_guard_test.gd` 的 `test_lone_guard_effective_ignores_attacked_flag`(-1 條);`battle_state_straddle_hold_back_test.gd` 的 `test_will_attack_param_is_ignored_same_result_true_false`(內含 2 行對它的斷言,整條測試同時測第 2 項,見下,-1 條)。 | 否。prototypes 零命中(grep 全部 `*.gd`)。 |
| 2 | `will_attack` 參數 — `BattleState.lone_guard_if_at(unit_id, tile, will_attack=false)`(`battle_state.gd:750`)與 `BattleScreen._displayed_guard_at(..., will_attack=false)`(`battle_screen.gd:2810-2814`) | **死**。參數傳進去、傳給第 1 項,結果恆等於不傳。 | `battle_state.gd:745-746` 文件註解「已棄用,忽略」;`battle_state.gd:755`:`return CombatRules.lone_guard_effective(CombatRules.lone_guard(d_min), will_attack)`。 | `battle_screen.gd` 4 個呼叫點(4413/4414/4415/4830)需改;測試:`battle_state_lone_guard_conditional_test.gd` 的 `test_lone_guard_if_at_will_attack_param_is_ignored`、`battle_screen_guard_display_test.gd` 內 `_find_dual_cell`(傳 true/false)。`battle_state_lone_guard_if_at_test.gd`(7 條)全用 2 參數呼叫,**不受影響**。 | **會(預測)**。3 參數呼叫:`protocol2-computer-measure-v3/p2_decision.gd:121`、`protocol2-diagnosis-attempt3-2026-10-30/p2_decision.gd:121`、`protocol2-diagnosis-attempt4-2026-10-30/p2_decision.gd:121`、兩支 `protocol2_runner_traced.gd`(attempt3:176、attempt4:188,傳 `false`)。移除參數後這些行應變成解析錯誤(**未實跑驗證**)。v2 的 `p2_decision.gd:119` 是 2 參數,不受影響。 |
| 3 | `attacked_this_phase()` 與 `_attacked_this_phase` 字典(`battle_state.gd:734-741`、寫入 517、清除 882) | **死**。寫入與清除仍在跑,但唯一的讀取者只把它餵進第 2 項(被忽略)。程式註解自述「旗標寫入暫留、不再被讀取」。 | 讀取點:`battle_screen.gd:4831` `_state.attacked_this_phase(occupant.id)` → 傳進 `_displayed_guard_at` 的 `will_attack`(被忽略)。`battle_state.gd:517` `_attacked_this_phase[attacker_id] = true`(在 `resolve_attack` 的提交窗口內);`882` `_attacked_this_phase.clear()`。 | 刪除 517/882 兩行寫入與清除不改變提交次數(仍是同一個 `commit_authoritative_change`,版本號仍 +1 一次)。測試:`battle_state_lone_guard_conditional_test.gd` 前 5 條(旗標初值/設定/不因被打設定/新階段清除/寫入走提交窗口)全是在測這個旗標;`...conditional_test` 的 `test_breakdown_equals_lone_guard_if_at_with_real_position_and_real_flag` 也呼叫它(整條可改為 2 參數版本保留)。 | **會**。`protocol2-diagnosis-attempt3/protocol2_runner_traced.gd:177` 與 `protocol2-diagnosis-attempt4/protocol2_runner_traced.gd:193` 在列印行裡呼叫 `s.attacked_this_phase(tg)`。這兩支是「診斷追蹤」版本,不是正式量測 runner(正式 `protocol2_runner.gd` 未呼叫)。 |
| 4 | `BattleScreen.format_guard_move_dual()` 與 `_displayed_guard_at(..., true)` 呼叫(`battle_screen.gd:2792-2795`、`4413-4418`) | **死**(對玩家而言)。呼叫端算了「不出手」與「出手」兩個值,但兩者必然相等(第 2 項已忽略參數),`format_guard_move_dual` 的 `no_attack == attack` 分支每次都成立、直接轉給單值的 `format_guard_move`。**雙值字串從不會顯示。** | `battle_screen.gd:4414-4415` 同一個格子連呼兩次 `_displayed_guard_at(..., hypo)` 與 `(..., hypo, true)`;`2793-2794`:`if no_attack == attack: return format_guard_move(current, no_attack)`。測試自己承認:`battle_screen_guard_display_test.gd:221` `test_move_preview_has_no_attack_dependent_cell_after_amend2` 斷言「不應存在出手與否減傷不同的格」。 | `battle_screen_guard_display_test.gd`(共 14 條)中可刪 3 條:`test_format_guard_move_dual_differs_and_same`、`test_move_preview_has_no_attack_dependent_cell_after_amend2`、`test_move_preview_shows_single_when_attack_does_not_change_guard`,連同輔助函式 `_find_dual_cell` / `_dual_case`(`_dual_case` 只被這 3 條中的後者用到;已 grep 確認)。**注意**:`test_move_preview_has_no_attack_dependent_cell_after_amend2` 的價值只是「規則不會被改回去」的回歸護欄,刪了之後這個保護就沒了(見下「風險」)。 | 否。prototypes 零命中。 |
| 5 | 字串鍵 `battle.hud.guard_move_dual_format`(`assets/data/locales/strings.csv:167`) | **死**。唯一使用者是第 4 項的 `format_guard_move_dual`(只在它的不可達分支用)。 | `grep` 命中:`battle_screen.gd:2795`、`strings.csv:167`、兩處測試。 | `locale_data_integrity_test.gd:260` 的列數常數 159 → 158(**不是少測試,是改一個數字**;依該檔慣例需附註解一行,並屬「依工作單 Affected Files」才可改)。`strings.csv` 少一列。 | 否。 |
| 6 | `battle_state.gd:604` 陳舊註解「populates all 6 [member DamageBreakdownResult.breakdown] keys」 | **註解錯**(不是死碼)。`_attack_damage_breakdown` 現在回傳 atk/def/phi/phi_input/phi_def/guard_phi/lone_guard/guard/hold_back/damage + `target_hp_after` 共 **11** 鍵。`grep` 全庫沒有任何測試斷言「6 鍵」。 | `battle_state.gd:660-671`、`625`(`breakdown["target_hp_after"] = ...`)。 | 只改註解,零測試。順帶:協調者說的「hold_back」陳舊註解我**沒有找到**(`hold_back` 在 `battle_state.gd` 的註解與程式一致);若有,請提供位置,查證不符就照實寫。 | 否。 |
| 7 | `lone_guard_if_at` 函式本身 | **活**。`_lone_guard_of`(結算路徑,`battle_state.gd:704`)與 `_displayed_guard_at`(顯示)都在用,還是 protocol2 v2/v3/attempt 全部 prototypes 的共用入口。**不可刪,只可去掉第 3 個參數。** | `battle_state.gd:704`、`battle_screen.gd:2814`、`prototypes/protocol2-computer-measure-v2/p2_decision.gd:119`。 | 其 7 條專屬測試(`battle_state_lone_guard_if_at_test.gd`)留著。 | 去參數才會壞,見第 2 項。 |
| 8 | `HOLD_BACK_DISTANCE/PENALTY`、`LONE_*` 常數、`GUARD_MIN/MAX`(`combat_rules.gd:18-19,43-48,73-74`)寫死在程式 | **活**。現行規則直接在用。問題是「違反『數值要資料驅動』」,屬技術債,不是死碼。 | `combat_rules.gd:43-48,73-74`(`const`);`assets/data` 下 grep 這些名稱零命中。 | 若日後資料驅動化,會動 `combat_rules_guard_test.gd`(12 條)與 `battle_state_straddle_hold_back_test.gd`(14 條)裡的常數引用。 | 否(prototypes 只引用函式,不引用常數名稱)。 |

### 驗證補充

- **留一手(hold_back)** 不是死碼:`_attack_damage_breakdown` 把 `hold_back` 減進傷害(`battle_state.gd:671`),`battle_screen.gd:4903-4906` 顯示「留一手」一列,有測試 `test_attack_preview_shows_hold_back_row_only_at_d2`。
- **移動預覽(單值「減傷 x→y」)是活的**:`format_guard_move`(`strings.csv:166`)與 `battle_screen.gd:4413-4418` 的單值路徑照常顯示。管理者 2026-10-30 裁決的「雙值」是在舊規則(出手與否減傷不同)之下才有意義;amend2 取消出手條件後,雙值的第二個值永遠等於第一個,所以**功能存在但已無輸出差異**。管理者的裁決並未被違反 —— 是前提(出手條件)被後來的裁決取消了。
- 所有 `*.gd.uid` 之類未追蹤檔與本盤點無關。

## 2. 清理方案

**方案 A:全清(第 1~6 項一次做)**
- 做什麼:刪 `lone_guard_effective`、`will_attack` 參數、`_attacked_this_phase` 旗標、`format_guard_move_dual`、雙值字串鍵、陳舊註解;同步刪/改對應測試。
- 優點:程式與現行規則一致,日後沒人會被「為什麼出手還要傳旗標」誤導;死碼不再誤導下一次改戊的人。
- 缺點:**會弄壞 5 支協議 2 的診斷/量測腳本**(3 參數呼叫與 `attacked_this_phase`),除非同時修補它們(它們是歸檔的拋棄式工具,修補等於改歷史證據);移除「雙值」等於推翻管理者 10-30 親自裁決做出的功能(雖然已無輸出)。
- 工作量:約半天(改 3 個 src 檔、1 個 csv、4 個測試檔 + 1 個 locale 計數、須跑全套)。
- 測試總數:約 **-15 條**(conditional 檔 11 條中保留 1~2 條改寫為 2 參數版 → 淨 -9~-10;guard_display -3;combat_rules_guard -1;straddle -1)。

**方案 B:只清「確定死、且不會弄壞任何東西」的**
- 做什麼:只做第 1、6 項的一部分 —— 即不碰函式簽名的部分:改正陳舊註解(第 6 項);把 `lone_guard_effective` 留著但標註;並**不**刪 `will_attack` / `attacked_this_phase` / 雙值。實際上只有第 6 項零風險,第 5 項(字串鍵)與第 4 項要一起刪才不留下孤兒。
- 優點:零風險,不動任何量測工具與管理者裁決的功能。
- 缺點:大部分死碼仍在;第 4 項雙值每次移動預覽仍白算一次(不影響效能);下一個人仍會被誤導。
- 工作量:約 30 分鐘。測試總數:不變。

**方案 C:分兩步 —— 先清「畫面與資料」那一組,「簽名」那組留到協議 2 結案後**
- 步驟一(現在):刪第 4+5 項(雙值格式函式、字串鍵)與 `battle_screen.gd` 的三連呼叫,改回單一呼叫;改第 6 項註解。此組 prototypes 零命中,不會弄壞任何東西。
- 步驟二(協議 2 結案、診斷腳本不再需要重跑之後):刪第 1~3 項。
- 優點:拿到大部分清潔度、零量測工具風險;第 4 項推翻管理者 10-30 裁決的部分只在「前提已消失」的情況下做,理由明確(下方)。
- 缺點:`will_attack` / `lone_guard_effective` / `attacked_this_phase` 還要再留一段時間;要記得做步驟二。
- 工作量:步驟一約 2 小時(含全套測試)。測試總數:步驟一 **-3 條**(guard_display 的 3 條)。步驟二再 **-12 條上下**。

## 3. 推薦:方案 C

理由:
1. 雙值整套(第 4+5 項)已是**百分之百不可達**,留著是淨誤導;而且它不連帶任何 prototypes,最乾淨。需要管理者確認的只有一件事:**10-30 裁決的前提(出手條件)已被 amend2 取消,所以雙值失去存在理由,是否同意移除**(請白話給他:「這個功能現在永遠只會顯示一個數字,清掉不影響畫面」)。
2. 第 1~3 項的清除會讓 5 支協議 2 診斷腳本無法再跑。協議 2 attempt-5 剛判定「通過(壓線)」,需要重跑復驗的機率不低(B1a 恰等於門檻),留著這些簽名換重現能力是划算的。協議 2 結案後再做步驟二。
3. 常數資料驅動(第 8 項)不是死碼,應另走技術債登記,不併進這張清理單。

## 4. 風險與誠實揭露

- **刪除 `test_move_preview_has_no_attack_dependent_cell_after_amend2` 會失去一道護欄**:它防的是「有人把出手條件改回來卻沒發現畫面」。方案 C 步驟一刪它之後,保護改由 `battle_state_lone_guard_if_at_test.gd` 與 `test_lone_guard_part_still_shown_after_unit_attacked` 承擔(兩者仍在)。
- prototypes「會壞」是**預測**,未實跑(依你的指示不跑測試/引擎)。GDScript 對型別化變數多傳參數通常是解析錯誤,但我未驗證 prototypes 裡 `s` 是否為型別化變數。
- 測試條數來自 `grep -c "^func test_"`,屬 (C) 級計數;實際刪除時以引擎全套輸出為準。
- 協調者清單中的「hold_back 陳舊註解」我沒找到;「6 keys」確認存在。

## 5. 實際讀過的檔案

- `src/gameplay/combat/combat_rules.gd`(1-110)
- `src/gameplay/battle/battle_state.gd`(495-525、598-760、875-886)
- `src/ui/battle/battle_screen.gd`(2770-2850、4400-4425、4810-4850;其餘為 grep 命中行)
- `tests/integration/ui/battle/battle_screen_guard_display_test.gd`(186-240 與函式清單)
- `tests/unit/gameplay/battle/battle_state_lone_guard_conditional_test.gd`(108-125 與函式清單)
- `tests/unit/gameplay/battle/battle_state_straddle_hold_back_test.gd`(50-60)
- `tests/unit/gameplay/battle/battle_state_lone_guard_if_at_test.gd`(grep)
- `tests/unit/gameplay/combat/combat_rules_guard_test.gd`(grep)
- `tests/unit/core/i18n/locale_data_integrity_test.gd`(255-264)
- `assets/data/locales/strings.csv`(160-170)
- `docs/reviews/affinity-core-redesign-spec-amend2-2026-10-30.md`(grep 關鍵段)
- `prototypes/protocol2-*`(僅 grep:v2、v3、diagnosis-attempt3、diagnosis-attempt4 的 `.gd`)
