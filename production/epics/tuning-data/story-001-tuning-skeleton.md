# Story 001:調整旋鈕共用骨架(不搬任何常數)

**Status**: Ready
**Epic**: `production/epics/tuning-data/EPIC.md` · **Type**: Logic + Integration · **規劃檔步 0**
**Depends On**: 無(其餘 story 依賴本張)

## 依據(管理者 2026-11-04 裁決,逐字)

- 「現在搬(推薦)」
- 「大聲報錯(推薦)」= 方案 B:不可變設定物件 + 注入,讀檔留在組裝點(`battle_screen.gd`),資料檔錯誤明確失敗
- 全文脈絡:`docs/reviews/tuning-knobs-data-driven-plan-2026-11-04.md` §3、§4

## 目標

建立「資料檔 → 純解析 → 注入 `BattleState`」的管線,**本張不搬任何常數、不改任何規則行為**。
證明管線通、且壞檔會大聲失敗。後續 story 各自往裡加一個系統的鍵。

## 設計約束

- 純解析 `TuningKnobs.from_text(text) -> Variant`(失敗回 `null`),**不碰 `FileAccess`**,比照 `Unit.roster_from_text` / `AffinityLink.links_from_text`。形狀比照 `AffinityCalibration`(不可變 `RefCounted`、`Rejection` 列舉)。
- 檔案格式:`section,key,value` 逗號分隔、`#` 註解、表頭註解說明欄位(與 `assets/data/units/vs01_roster.txt` 慣例一致)。
- 驗證:未知 section/key → 失敗(防打錯字靜默失效)、重複鍵 → 失敗、值非整數 → 失敗。已知鍵清單由各 story 增補;本張清單為空。
- **不得使用 `assert()`**;失敗用 `push_error()` + 顯式回 `null`。
- `battle_screen.gd` 新增 `tuning_path_override`(比照既有 `*_path_override`),讀檔、解析、失敗時比照既有載入失敗路徑(`push_error` 並明確失敗,**不靜默回預設**),成功時注入 `BattleState`。
- `BattleState` 持有一份 `TuningKnobs`(建構時注入、可選參數,未傳則 `TuningKnobs.defaults()`)。

## Affected Files(實作者可不先問直接改/建的範圍;範圍外一律先問)

**新增**
- `src/gameplay/tuning/tuning_knobs.gd`(新)
- `assets/data/tuning/tuning_knobs.txt`(新,僅表頭註解,無鍵)
- `assets/data/tuning/test_fixture_tuning_valid.txt`、`test_fixture_tuning_unknown_key.txt`、`test_fixture_tuning_duplicate_key.txt`、`test_fixture_tuning_non_integer.txt`(新,測試夾具)
- `tests/unit/gameplay/tuning/tuning_knobs_test.gd`(新)
- `tests/integration/ui/battle/battle_screen_tuning_load_test.gd`(新)

**修改既有程式碼檔**
- `src/ui/battle/battle_screen.gd`(載入、`tuning_path_override`、注入)
- `src/gameplay/battle/battle_state.gd`(持有 `tuning`、可選建構參數)

**不在範圍(要動必須先問)**:`tests/gdunit4_runner.gd`(若新增測試層級才需要;本張不新增層級)、任何規則類(`combat_rules.gd` 等)、任何文件。

## 驗收條件

1. **零行為變更**:全套測試前後 `Overall Summary` 除新增測試數外逐字相同;不搬任何常數。
2. `TuningKnobs.from_text`:正常輸入回物件;未知鍵、重複鍵、非整數、空字串以外的格式錯誤各一條測試,**皆回 `null` 且 `push_error` 有訊息**(測試須證明訊息有發出,不只回傳值)。
3. **資料檔錯誤大聲報錯**:`BattleScreen`(走真實場景,`instantiate()` → 設 `tuning_path_override` → `call_deferred("add_child")` → 等幀)對壞夾具明確失敗(行為比照既有載入失敗路徑),**不靜默用預設**;對合法夾具成功,且 `BattleState` 持有的 `tuning` 即為解析結果(以實例同一性或可觀測欄位斷言)。
4. **敏感度骨架**:常駐 `test_sensitivity_proof_*`,證明「換掉注入的夾具路徑,`BattleState.tuning` 跟著換」—— 這是後續各 story 敏感度證明的接線基礎。
5. 資料檔真實檔 `assets/data/tuning/tuning_knobs.txt` 可解析(甲類例外,檔頭聲明並自陳不證明窮盡性)。
6. 簽名變更只能是末位有預設值的可選參數;31 支 `prototypes/` 呼叫端不得壞(未改任何既有公開簽名為必填)。
7. 交付含 `ENGINE EXIT`、`Overall Summary` 原始三行(`GODOT_BIN=<路徑> ./tools/build/run_tests_with_import.sh`),先確認引擎 exit code。

## `combat_rules_guard_test.gd` 釘死值

本張**不動**(屬 story-004)。
