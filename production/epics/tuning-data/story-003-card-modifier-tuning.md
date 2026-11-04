# Story 003:`CardModifierRules` 四項夾限資料驅動化

**Status**: ✅ Done(2026-11-04;原為 Ready)
> 提交:d6c6226(協調者重跑全套驗收)
**Epic**: `production/epics/tuning-data/EPIC.md` · **Type**: Logic + Integration · **規劃檔步 2**
**Depends On**: story-001

## 依據(管理者 2026-11-04 裁決,逐字)

- 「現在搬(推薦)」
- 「大聲報錯(推薦)」= 方案 B
- 搬的常數:`ATK_DELTA_MIN`(-4)、`ATK_DELTA_MAX`(6)、`DEF_DELTA_MIN`(-3)、`DEF_DELTA_MAX`(4)

## 設計約束

- 新增 `CardModifierTuning`(不可變 `RefCounted`,`defaults()` = 今日值;`from_text` 驗證 `*_MIN <= *_MAX`)。
- `CardModifierRules.effective_atk(...)`/`effective_def(...)` 增末位可選參數 `tuning: CardModifierTuning = null`(`null` → `defaults()`)。
- ⚠️ `Unit.effective_atk()/effective_def()` 內部呼叫上述函式(`unit.gd:274,281`),`Unit` 是 `RefCounted` 且大量被 `new`;**注入路徑須由實作者提案並在交付報告說明**(候選:`BattleState` 在建單位後設定;或 `Unit` 增可選欄位)。**會動 `Unit` 公開欄位/簽名超出下列範圍者,先問。**
- 資料檔鍵 `card_modifier,atk_delta_min,-4` 等,登錄進已知鍵清單。

## Affected Files(範圍;範圍外一律先問)

**新增**:`src/gameplay/tuning/card_modifier_tuning.gd`、`tests/unit/gameplay/tuning/card_modifier_tuning_test.gd`、`assets/data/tuning/test_fixture_tuning_card_modifier_narrow.txt`(夾具:縮窄夾限)、`tests/integration/ui/battle/battle_screen_card_modifier_tuning_wiring_test.gd`

**修改既有程式碼檔**:
`src/gameplay/cards/card_modifier_rules.gd`、`src/gameplay/units/unit.gd`、`src/gameplay/tuning/tuning_knobs.gd`、`src/gameplay/battle/battle_state.gd`、`src/ui/battle/battle_screen.gd`(`:4050-4051` 預覽呼叫處)、`assets/data/tuning/tuning_knobs.txt`

**修改既有測試檔(僅限必要)**:`tests/unit/gameplay/units/unit_test.gd`、`tests/unit/gameplay/cards/card_modifier_test.gd`、`tests/integration/ui/card_confirm_panel_test.gd`(常數零引用,只在簽名/注入路徑逼到時才改;改了須在報告說明原因)

## 驗收條件

1. **零行為變更**:`defaults()` 四值等於今日常數;初始資料檔等於 `defaults()`;全套 `Overall Summary` 除新增測試數外逐字相同。
2. **敏感度證明(走真實流程)**:以夾具縮窄夾限注入真實 `BattleScreen`/`BattleState`,斷言**真實戰鬥結算或卡牌確認面板預覽**的有效 ATK/DEF 跟著變;常駐 `test_sensitivity_proof_*`。
3. **資料檔錯誤大聲報錯**:缺鍵、非整數、`MIN > MAX` 各一條,回 `null` 且 `push_error`;`BattleScreen` 對壞檔明確失敗。
4. **單一出處**:戰鬥結算(`Unit.effective_*`)與 UI 預覽(`battle_screen.gd:4050`)必須讀**同一份**注入設定,不得各用一套(此為本專案登記過的「兩份複本只是今天答案一致」形狀);以測試證明兩處在夾具下答案一致。
5. 簽名只加末位可選參數(31 支 prototypes 不可壞)。
6. 交付含 `ENGINE EXIT`、`Overall Summary` 原始三行。

## `combat_rules_guard_test.gd` 釘死值

不適用(屬 story-004)。
