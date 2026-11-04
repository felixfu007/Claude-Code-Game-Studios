# EPIC:調整旋鈕資料驅動化(tuning-data)

**Status**: ✅ Done(2026-11-04;原為 Ready)
**建立**: 2026-11-04 · 擁有者:lead-programmer
**規劃來源**:`docs/reviews/tuning-knobs-data-driven-plan-2026-11-04.md`(盤點、查核、方案比較全文在該檔)
**技術債來源**:`docs/tech-debt-register.md`(2026-10-12 第八十批,「約 17 個遊戲平衡數值硬編碼」)

## 管理者裁決(2026-11-04,選項逐字,經協調者轉述 —— 紀錄所在:本次派工訊息)

1. 「**現在搬(推薦)**」(被跳過:繼續等 / 只搬戰鬥與好感度那些)
2. 「**大聲報錯(推薦)**」= 方案 B(不可變設定物件 + 注入,讀檔留在組裝點,資料檔錯誤明確失敗)
3. 「**距離留在程式(推薦)**」= `DISTANCE_ADJACENT` / `DISTANCE_FAR` **不搬**
4. 「**刪掉(推薦)**」= `LONE_MID_DISTANCE` 刪除
5. 手感秒數(`ENEMY_STEP_PAUSE_SECONDS` 等)**這次不搬**(協調者依規劃檔建議決定,未問管理者)

## 範圍

| Story | 系統 | 規劃檔步驟 |
|---|---|---|
| story-001 | 共用骨架(資料檔、載入、注入、敏感度骨架)—— 不搬任何常數 | 步 0 |
| story-002 | `CardDeck`(3 項) | 步 1 |
| story-003 | `CardModifierRules`(4 項) | 步 2 |
| story-004 | `CombatRules`(`GUARD_*`/`LONE_*`/`HOLD_BACK_*`)+ 刪除 `LONE_MID_DISTANCE` | 步 3 |
| story-005 | `AffinityRules`(`DELTA_*` 5 項 + `PHI_MIN/MAX`;距離門檻不搬) | 步 4 |

> 註:派工訊息稱 story-003 為 CombatRules;依規劃檔步序,本 EPIC 編號為 story-004。
> 若協調者要求照原編號,以步序重編號即可,內容不變。

**不在範圍**:`TERRAIN_TABLE.cost`(規劃檔步 5)、手感秒數(步 6)、UI 版面常數、
`DISTANCE_ADJACENT/FAR`、`BOARD_WIDTH/HEIGHT` 重複定義(另一筆債)。

## 全 epic 共通規則(各 story 驗收條件皆含)

- **零行為變更**:`defaults()` 值逐個等於今日常數;初始資料檔內容等於 `defaults()`。
- **簽名只能加「末位、有預設值」的可選參數,不可改必填**:31 支 `prototypes/` `.gd`(含協議 2 量測腳本)呼叫這些規則函式。
- **資料檔錯誤必須大聲失敗**:缺鍵、未知鍵、重複鍵、非整數、違反不變式 → `from_text` 回 `null`,組裝點 `push_error` 並明確失敗,不靜默回預設。**不得用 `assert()`**(`coding-standards.md` 禁令)。
- **敏感度證明**:每張 story 至少一條走真實流程(`BattleScreen`/`BattleState`,依 `technical-preferences.md` 第 5 點:`instantiate()` → 設 override → `call_deferred("add_child")` → 等幀)的測試,改注入的資料值後可觀測行為跟著變;形式為常駐 `test_sensitivity_proof_*`,不用手動注入。
- **交付硬性義務**(`CLAUDE.md` 2026-10-12 裁決):依 Affected Files 直接改既有程式碼檔者,交付前跑一次全套(`GODOT_BIN=<路徑> ./tools/build/run_tests_with_import.sh`),回報貼 `ENGINE EXIT`、`Overall Summary` 原始三行,不只說「通過」;先看引擎 exit code(exit 105 會讓兩個 grep 都空)。協調者自行重跑複驗。
- Affected Files 以外的檔:**文件必須先問;程式碼檔也必須先問。**
- 測試讀真實資料檔屬已登記「甲類例外」,檔頭須聲明並自陳不證明窮盡性(`.claude/rules/test-standards.md`)。
- Story 之間依序執行(001 先),002~005 彼此獨立。

## 文件修改備忘(不在任何 story 範圍內)

`docs/registry/architecture.yaml` 的 forbidden pattern **`phi_clamp_treated_as_a_safety_net`**
以常數名 `AffinityRules.PHI_MIN/PHI_MAX` 點名;story-005 完成後該文字需同步改寫。
那是**文件修改**,**由協調者於 story-005 完成後另行請示**,實作者不得動。
同理 `docs/tech-debt-register.md` 的結案標註、`.claude/docs/technical-preferences.md` 的相關描述亦不在範圍。

## 已知張力(登記,未解決)

`defaults()` 與資料檔是同一組值的兩份複本。遷移當下以一次性等值證明(留在 `prototypes/` 證據)確認一致;
常駐測試只斷言「真實檔可解析且通過驗證」,不長期釘等值,否則每次調旋鈕都要改測試。
