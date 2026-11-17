# Story 014:麥子健騎牆改為「場上 4 組全 NONE 才有效」,減傷與留守同開同關

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: ✅ Done(2026-11-17,提交 `62b71b4`)(原狀態:Ready(2026-11-17:整份重寫已完成 `8213cfe`;依序:012、013 完成後才可派工)(原狀態:Blocked —— 等 `design/gdd/affinity-position-chain.md` 整份重寫完成(管理者 2026-11-17 裁決 B,進行中;同 story-013);另依賴 012、013。)原卡點「公式五須先修訂」已被此取代。)
> **Type**: Logic
> **Estimate**: M(1~1.5 天,粗估未驗證;排程 N3)
> **依據**:規格 v1.0 第 3 節「麥子健騎牆」(身上沒關係時有效、一有關係即失效;`lone_guard` 與 `hold_back` 同開同關,**不得只關一項**;判定範圍只看場上存活者;結果以布林交給 `CombatRules`)、第 9 節驗收 (6)。現況:`grep -rln "lone_guard\|hold_back" src` 命中 `battle_state.gd`、`combat_rules.gd`、`combat_tuning.gd`、`tuning_knobs.gd`、`unit.gd`、`battle_screen.gd`(2026-11-17 查);各自如何判定騎牆:**未驗證,實作者第一步全讀**。

## 派工前須先決定

1. `affinity-position-chain.md` 整份重寫完成(同 013;管理者 2026-11-17 裁決 B)。
   - **已決:騎牆失效時三項一起歸零**(管理者 2026-11-17 裁決「三項一起歸零(設計師推薦)」;`docs/reviews/straddle-q3-q4-recommendation-2026-11-17.md` Q3-A)。三項 = 獨行減傷表的貼身 d=1 的 −1、d=2 的 +2、`hold_back`(留一手)。**不得只關兩項、不得保留貼身 −1。** 實作者第一步須對照 `combat_rules.gd` 確認三項的實際符號名稱(該推薦檔自述 d=1/d=2 屬 `lone_guard` 減傷表,本單撰寫者未逐行驗證)。
   - **已決:k=0 先行**(管理者 2026-11-17):本單只讀 `state_of`、不含 k;AC4「池空、k=0 回歸」即以此為基準。
2. 「場上存活者」與規格註「任一我方陣亡即戰敗,故等於看全部 4 組」(規格稱協調者已核實 `battle_state.gd` `outcome()`)—— 實作仍按「只看存活者」寫,不依賴該巧合;**無**待裁決,僅提醒。
3. 騎牆開關是「每次戰鬥查詢即時算」還是「戰鬥開始快取」:規格要求 S 即時讀,故**每次查詢即時算**(丙類寫池可在戰鬥中翻轉 S)。無待裁決。

## 規則

- 判定:麥子健與其餘四人 4 組的 `state_of` 全為 NONE ⇔ 騎牆有效;結果為布林,由呼叫端傳入 `CombatRules`(`CombatRules` 維持不認識好感度池)。
- **同一個布林同時驅動 `lone_guard`(含貼身 d=1 的 −1、d=2 的 +2 兩列)與 `hold_back`,共三項同開同關**,不得各算一次、不得只關其中一部分(管理者 2026-11-17 裁決,Q3-A)。
- 現行「麥子健恆無線」的寫死處改為上述判定;`k=0` 且池空時行為與現行相同(回歸)。

## Acceptance Criteria

- [ ] **AC1 全 NONE → 三項皆開**(貼身 d=1 的 −1、d=2 的 +2、`hold_back`);任一組非 NONE → **三項皆歸零**(各 1 條,逐項斷言各自的可觀察結果,不只斷言布林;尤其須有一條斷言「騎牆失效時貼身 d=1 沒有額外 −1」)。
- [ ] **AC2 即時**:戰鬥中丙類寫池使一組 S 翻轉,下一次傷害/行動查詢立即反映。
- [ ] **AC3 `CombatRules` 無池知識**:`combat_rules.gd` 內不出現任何好感度池/`state_of` 的引用(`grep -n "affinity\|state_of" src/gameplay/combat/combat_rules.gd | grep -v "^\S*:[0-9]*:\s*#"` 回報原始輸出;🔴 搜尋指令不得寫進被搜尋檔)。
- [ ] **AC4 回歸**:池空、`k=0` 時,既有麥子健相關測試全綠且斷言不改。
- [ ] **AC5 含麥子健的非人設關係**:麥子健×其他人任一組 POS 或 NEG 即失去騎牆(逐組 4 條)。
- [ ] **AC6 敏感度證明**(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①只關 `lone_guard`、`hold_back` 不關 → AC1 紅(另一個 mutant:只關 +2 與 `hold_back`、保留貼身 −1 → AC1 紅;各自獨立執行) ②只看 4 組中的 3 組 → AC5 紅 ③開機快取 → AC2 紅 ④`CombatRules` 內直接讀池 → AC3 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 營火畫面「麥子健將失去騎牆」提示(營火部分,不在本批)。

## Affected Files

- `src/gameplay/battle/battle_state.gd`、`src/gameplay/combat/combat_rules.gd`(僅接收布林,先讀後定)、相關呼叫端;實際清單於第一步確認後回報,超出先問。
- 新測試:`tests/integration/gameplay/combat/lone_guard_relation_state_test.gd`

## 與其他工單的順序

- **依賴 012、013**。
