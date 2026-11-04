# Story 005:`AffinityRules` 曲線與夾限資料驅動化(距離門檻不搬)

**Status**: Ready
**Epic**: `production/epics/tuning-data/EPIC.md` · **Type**: Logic + Integration · **規劃檔步 4**
**Depends On**: story-001(建議排在 002~004 之後,最敏感)

## 依據(管理者 2026-11-04 裁決,逐字)

- 「現在搬(推薦)」
- 「大聲報錯(推薦)」= 方案 B
- 「距離留在程式(推薦)」= `DISTANCE_ADJACENT` / `DISTANCE_FAR` **不搬**
- 搬的常數:`DELTA_POSITIVE_ADJACENT`(3)、`DELTA_POSITIVE_FAR`(-1)、`DELTA_NEGATIVE_ADJACENT`(-1)、`DELTA_NEGATIVE_FAR`(2)、`DELTA_NEUTRAL`(0)、`PHI_MIN`(-4)、`PHI_MAX`(12)

## 承重不變式(必讀,來自 `docs/registry/architecture.yaml` forbidden pattern `phi_clamp_treated_as_a_safety_net`)

- **夾限只夾一次,且只在 `AffinityRules.bonus_for_at()` 內、對加總後的總和夾**:不得逐線夾、不得挪到呼叫端、不得為了注入把夾限拆開。
- 搬進資料檔**不違反**該條(它禁的是「把夾限當保險絲」),但調這兩個值**就是**調戰鬥力上下限;資料檔該段須有註解寫明此事。
- 該登記表條文以常數名點名 `AffinityRules.PHI_MIN`,**文字同步屬文件修改,不在本 story 範圍**:實作者**不得動** `docs/registry/architecture.yaml`;完成後由協調者另行請示(見 EPIC.md)。

## 設計約束

- 新增 `AffinityTuning`(不可變 `RefCounted`,`defaults()` = 今日值;`from_text` 驗證 `PHI_MIN <= PHI_MAX`)。
- `AffinityRules.delta(...)`、`bonus_for`、`bonus_for_at`、`bonus_breakdown_for(_at)` 增末位可選參數 `tuning: AffinityTuning = null`(`null` → `defaults()`)。
- `DISTANCE_ADJACENT`/`DISTANCE_FAR` **留在程式內**,維持 `const`。
- ⚠️ 好感度查詢經多層(`AffinityPhiProvider`、`AffinityBonusBreakdown`、`RelationMinimap`、`EffectGuessTracker`、`BattleState`)。**注入路徑漏接一層就會在該層悄悄用 `defaults()`**——這是本張最大風險,由驗收 2、4 專門防。
- 資料檔鍵 `affinity,delta_positive_adjacent,3` 等,登錄已知鍵清單;檔內註解標明 `phi_min/phi_max` 為承重值。

## Affected Files(範圍;範圍外一律先問)

**新增**:`src/gameplay/tuning/affinity_tuning.gd`、`tests/unit/gameplay/tuning/affinity_tuning_test.gd`、`assets/data/tuning/test_fixture_tuning_affinity_phi_narrow.txt`(夾具:例如 `PHI_MAX=6`)、`tests/integration/ui/battle/battle_screen_affinity_tuning_wiring_test.gd`

**修改既有程式碼檔**:
`src/gameplay/affinity/affinity_rules.gd`、`src/gameplay/affinity/affinity_phi_provider.gd`、`src/gameplay/affinity/affinity_bonus_breakdown.gd`(多為註解中的常數名,更新引用)、`src/gameplay/affinity/affinity_line_status.gd`、`src/gameplay/affinity/affinity_link.gd`(註解引用)、`src/gameplay/affinity/affinity_roster_character_mapper.gd`(僅限必要)、`src/gameplay/cards/permanent_affinity_write_rules.gd`(僅限必要)、`src/gameplay/battle/battle_state.gd`、`src/gameplay/tuning/tuning_knobs.gd`、`src/ui/battle/battle_screen.gd`、`src/ui/battle/relation_minimap.gd`、`src/ui/battle/effect_guess_tracker.gd`、`assets/data/tuning/tuning_knobs.txt`

**修改既有測試檔(僅限必要)**:`tests/unit/gameplay/affinity/affinity_rules_test.gd`(`PHI_MIN/PHI_MAX` 只在註解出現、斷言用字面值 `+12`;更新註解,不改斷言)、`tests/unit/gameplay/affinity/affinity_phi_provider_test.gd`、`tests/unit/gameplay/affinity/affinity_manhattan_implementation_count_test.gd`、`tests/unit/ui/effect_guess_tracker_test.gd`、`tests/integration/ui/battle/battle_screen_egm_guess_selector_test.gd`、`tests/integration/ui/battle/battle_screen_guard_display_test.gd`、`tests/integration/ui/battle/battle_screen_relation_minimap_test.gd`、`tests/perf/affinity_query_perf_benchmark.gd`(因簽名只加可選參數,多數不應需改;改了須說明原因)

**不在範圍**:`docs/registry/architecture.yaml`、`design/gdd/affinity-position-chain.md`、任何其他文件。

## 驗收條件

1. **零行為變更**:`defaults()` 七值等於今日常數;初始資料檔等於 `defaults()`;`AffinityRules` 既有測試(含 `AC-R7`/`AC-R7b`/`AC-MIX`/`AC-F3` 的夾限案例)**斷言一個字不改**仍全綠;全套 `Overall Summary` 除新增測試數外逐字相同。
2. **敏感度證明(走真實流程)**:夾具改 `PHI_MAX=6`,注入真實 `BattleScreen`/`BattleState`,斷言**真實傷害預覽/結算**的 Φ 被夾在新上限;另一條改 `DELTA_POSITIVE_ADJACENT` 看曲線跟著變。常駐 `test_sensitivity_proof_*`。
3. **資料檔錯誤大聲報錯**:缺鍵、非整數、`PHI_MIN > PHI_MAX` 各一條,回 `null` 且 `push_error`;`BattleScreen` 對壞檔明確失敗。
4. **每層讀同一份設定**:`BattleState` 結算、`AffinityPhiProvider`、`RelationMinimap`、`EffectGuessTracker` 在夾具下答案互相一致(以測試證明,不是以讀程式聲稱)。
5. **夾限只夾一次**:新增一條測試,在夾具 `PHI_MAX` 下,以「逐線各夾一次會得到不同答案、總和夾一次得到另一個答案」的資料,證明結果為後者(防止搬家時把夾限挪位)。
6. 簽名只加末位可選參數;`prototypes/` 呼叫端不得壞。
7. 交付含 `ENGINE EXIT`、`Overall Summary` 原始三行。

## `combat_rules_guard_test.gd` 釘死值

不適用(屬 story-004)。本張不得動該檔。
