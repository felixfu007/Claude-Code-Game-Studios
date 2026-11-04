# Story 004:`CombatRules` 旋鈕資料驅動化 + 刪除 `LONE_MID_DISTANCE`

**Status**: ✅ Done(2026-11-04;原為 Ready)
> 提交:194eac3 + 18fb6f5(協調者重跑全套驗收)
**Epic**: `production/epics/tuning-data/EPIC.md` · **Type**: Logic + Integration · **規劃檔步 3**
**Depends On**: story-001
**備註**:派工訊息稱此張為「story-003」,依步序編為 004,內容照派工要求(併入刪除 `LONE_MID_DISTANCE`)。

## 依據(管理者 2026-11-04 裁決,逐字)

- 「現在搬(推薦)」
- 「大聲報錯(推薦)」= 方案 B
- 「刪掉(推薦)」= `LONE_MID_DISTANCE` 刪除
- 搬的常數:`GUARD_MIN`(-2)、`GUARD_MAX`(3)、`LONE_FAR_DISTANCE`(3)、`LONE_FAR_GUARD`(0)、`LONE_NEAR_DISTANCE`(1)、`LONE_NEAR_GUARD`(-1)、`LONE_MID_GUARD`(2)、`HOLD_BACK_DISTANCE`(2)、`HOLD_BACK_PENALTY`(1)
- 不搬:`NO_ALLY`(哨兵)、`guard()` 內的 ÷2 進位(公式形狀)

## 設計約束

- 新增 `CombatTuning`(不可變 `RefCounted`,`defaults()` = 今日值;`from_text` 驗證 `GUARD_MIN <= GUARD_MAX`、`LONE_NEAR_DISTANCE < LONE_FAR_DISTANCE` 等不變式,**推導不出者停下來問**)。
- `CombatRules` 的 `guard_total`、`lone_guard`、`hold_back` 增末位可選參數 `tuning: CombatTuning = null`(`null` → `defaults()`)。**`damage()` 簽名不動**。
- **刪除 `LONE_MID_DISTANCE`**:全 `src/` 只有宣告與一行註解,`lone_guard()` 以 fallthrough 得中段、從不讀它(規劃檔 §1.3 當場 grep)。刪除須**行為不變**,並同步修正 `combat_rules.gd` 內提到它的註解(`:42`)。刪後以 `grep -rnw LONE_MID_DISTANCE src tests` 確認零殘留(注意:驗證指令寫在註解裡會自我命中,請把它寫在交付報告而非程式註解)。
- 資料檔鍵 `combat,guard_min,-2` 等,登錄已知鍵清單。

## Affected Files(範圍;範圍外一律先問)

**新增**:`src/gameplay/tuning/combat_tuning.gd`、`tests/unit/gameplay/tuning/combat_tuning_test.gd`、`assets/data/tuning/test_fixture_tuning_combat_guard.txt`(夾具:例如 `GUARD_MAX=1`)、`tests/integration/ui/battle/battle_screen_combat_tuning_wiring_test.gd`

**修改既有程式碼檔**:
`src/gameplay/combat/combat_rules.gd`、`src/gameplay/tuning/tuning_knobs.gd`、`src/gameplay/battle/battle_state.gd`、`src/gameplay/battle/battle_controller.gd`、`src/gameplay/battle/turn_order.gd`、`src/gameplay/units/unit.gd`、`src/ui/battle/attack_confirm_panel.gd`、`src/ui/battle/battle_screen.gd`、`src/ai/greedy_tactical_ai.gd`(僅限因簽名/注入而必要的呼叫端)、`assets/data/tuning/tuning_knobs.txt`

**修改既有測試檔**:
- 釘死值(見下節):`tests/unit/gameplay/combat/combat_rules_guard_test.gd`
- 直接引用常數:`tests/unit/gameplay/battle/battle_state_guard_test.gd`(`GUARD_MAX`)、`tests/integration/ui/battle/battle_screen_guard_display_test.gd`(`LONE_MID_GUARD`,`:225`)
- 其餘呼叫 `CombatRules.` 的測試檔(`grep -rlw CombatRules tests`,約 20 支)因簽名只加可選參數而不應需要改;**某檔非改不可時先問**。

## `combat_rules_guard_test.gd` 釘死值兩條的處置

現況(當場讀):`:31 assert_int(CombatRules.GUARD_MAX).is_equal(3)`、`:37 assert_int(CombatRules.GUARD_MIN).is_equal(-2)`——釘的是「常數等於某數」本身,資料驅動後等於把資料檔釘死,每次調旋鈕都要改測試,與本案目的牴觸。**處置**:
1. **刪除這兩條「常數等於字面值」斷言**(不是改成釘資料檔)。
2. **以行為斷言取代**,並用 `CombatTuning.from_text(inline)`/`defaults()` 而非常數名:例如「`guard_total` 在 Φ 極大時等於**所用設定**的 `guard_max`」「極小時等於 `guard_min`」,且**至少一組用非預設夾限**(證明夾限真的來自設定,而非碰巧等於 3/-2)。
3. 同檔 `:29-30`、`:36` 原本用 `CombatRules.GUARD_MAX/MIN` 當期望值的行為斷言,改以 `defaults()` 取值;保留其測試意圖。
4. 交付報告須逐條列出被刪除/改寫的斷言與取代它的測試名,讓覆核者能對照「沒有淨減少把關力」。

## 驗收條件

1. **零行為變更**:`defaults()` 九值等於今日常數;初始資料檔等於 `defaults()`;`LONE_MID_DISTANCE` 刪除前後 `lone_guard()` 對 `d_min ∈ {-1,0,1,2,3,4}` 回傳值逐一相同(以測試證明);全套 `Overall Summary` 除新增/改寫測試數外逐字相同。
2. **敏感度證明(走真實流程)**:夾具改 `GUARD_MAX` 或 `HOLD_BACK_PENALTY`,注入真實 `BattleScreen`/`BattleState`,斷言**真實傷害預覽或結算**跟著變;常駐 `test_sensitivity_proof_*`。
3. **資料檔錯誤大聲報錯**:缺鍵、非整數、`GUARD_MIN > GUARD_MAX`、`LONE_NEAR_DISTANCE >= LONE_FAR_DISTANCE` 各一條,回 `null` 且 `push_error`;`BattleScreen` 對壞檔明確失敗。
4. **單一出處**:`attack_confirm_panel.gd` 的預覽與 `BattleState` 結算讀同一份設定;以測試證明夾具下兩處答案一致。結算路徑**仍無 RNG**(`rng_in_combat_settlement` 禁令不受影響)。
5. 簽名只加末位可選參數;`prototypes/` 內協議 2 量測腳本(`autoplay_*`、`formation_*`、`retreat_*`)呼叫 `CombatRules` 函式的寫法必須仍可編譯且行為不變(未動既有參數順序/個數為必填)。這些腳本為已簽歷史量測,**不得動**。
6. 交付含 `ENGINE EXIT`、`Overall Summary` 原始三行。
