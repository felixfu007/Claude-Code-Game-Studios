# Story 014:麥子健騎牆改為「場上 4 組全 NONE 才有效」,減傷與留守同開同關

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Blocked —— 卡在 `design/gdd/affinity-position-chain.md` 公式五(麥子健恆無線)須先修訂(同 story-013);另依賴 012、013。
> **Type**: Logic
> **Estimate**: M(1~1.5 天,粗估未驗證;排程 N3)
> **依據**:規格 v1.0 第 3 節「麥子健騎牆」(身上沒關係時有效、一有關係即失效;`lone_guard` 與 `hold_back` 同開同關,**不得只關一項**;判定範圍只看場上存活者;結果以布林交給 `CombatRules`)、第 9 節驗收 (6)。現況:`grep -rln "lone_guard\|hold_back" src` 命中 `battle_state.gd`、`combat_rules.gd`、`combat_tuning.gd`、`tuning_knobs.gd`、`unit.gd`、`battle_screen.gd`(2026-11-17 查);各自如何判定騎牆:**未驗證,實作者第一步全讀**。

## 派工前須先決定

1. 公式五文件先改(同 013)。
2. 「場上存活者」與規格註「任一我方陣亡即戰敗,故等於看全部 4 組」(規格稱協調者已核實 `battle_state.gd` `outcome()`)—— 實作仍按「只看存活者」寫,不依賴該巧合;**無**待裁決,僅提醒。
3. 騎牆開關是「每次戰鬥查詢即時算」還是「戰鬥開始快取」:規格要求 S 即時讀,故**每次查詢即時算**(丙類寫池可在戰鬥中翻轉 S)。無待裁決。

## 規則

- 判定:麥子健與其餘四人 4 組的 `state_of` 全為 NONE ⇔ 騎牆有效;結果為布林,由呼叫端傳入 `CombatRules`(`CombatRules` 維持不認識好感度池)。
- **同一個布林同時驅動 `lone_guard` 與 `hold_back`**,不得各算一次。
- 現行「麥子健恆無線」的寫死處改為上述判定;`k=0` 且池空時行為與現行相同(回歸)。

## Acceptance Criteria

- [ ] **AC1 全 NONE → 兩項皆開**;任一組非 NONE → **兩項皆關**(各 1 條,斷言兩個行為各自的可觀察結果,不只斷言布林)。
- [ ] **AC2 即時**:戰鬥中丙類寫池使一組 S 翻轉,下一次傷害/行動查詢立即反映。
- [ ] **AC3 `CombatRules` 無池知識**:`combat_rules.gd` 內不出現任何好感度池/`state_of` 的引用(`grep -n "affinity\|state_of" src/gameplay/combat/combat_rules.gd | grep -v "^\S*:[0-9]*:\s*#"` 回報原始輸出;🔴 搜尋指令不得寫進被搜尋檔)。
- [ ] **AC4 回歸**:池空、`k=0` 時,既有麥子健相關測試全綠且斷言不改。
- [ ] **AC5 含麥子健的非人設關係**:麥子健×其他人任一組 POS 或 NEG 即失去騎牆(逐組 4 條)。
- [ ] **AC6 敏感度證明**(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①只關 `lone_guard`、`hold_back` 不關 → AC1 紅 ②只看 4 組中的 3 組 → AC5 紅 ③開機快取 → AC2 紅 ④`CombatRules` 內直接讀池 → AC3 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 營火畫面「麥子健將失去騎牆」提示(營火部分,不在本批)。

## Affected Files

- `src/gameplay/battle/battle_state.gd`、`src/gameplay/combat/combat_rules.gd`(僅接收布林,先讀後定)、相關呼叫端;實際清單於第一步確認後回報,超出先問。
- 新測試:`tests/integration/gameplay/combat/lone_guard_relation_state_test.gd`

## 與其他工單的順序

- **依賴 012、013**。
