# Story 016:折損扣減並肩貢獻(規格 5.1,依 S 分列)

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Blocked —— 依賴 012、013、015;`affinity-position-chain.md` 公式五修訂後(同 013)才能在文件一致的前提下實作。
> **Type**: Logic
> **Estimate**: M(1.5 天,粗估未驗證)
> **依據**:規格 v1.0 第 5.1 節(表:NONE→0;POS:`c0>0` 時 `max(0, c0−N×phi_loss_positive)`、`c0≤0` 維持 `c0`;NEG:`c0−N×phi_loss_negative`,無下限)與算例、「扣減疊在 `delta()` 結果上、總和夾限之前;夾限仍只在 `bonus_breakdown_for_at` 內做一次;不改 `amp`」、第 9 節驗收 (3)。`delta()`、`PHI_MIN=−4`、`PHI_MAX=12` 規格稱已自讀 `affinity_rules.gd` 第 35~98 行;`bonus_breakdown_for_at` 位置**撰寫者未查**。

## 派工前須先決定

1. **扣減口位置**:v0.3 已列「本場折損扣減口」,但實際介面形狀(參數傳入 `N` 還是讀 `BattleState`)**未驗證**。為避免「同一規則兩份實作」,扣減必須**只在一處**(`bonus_breakdown_for_at` 內)做;`N` 如何傳入(注入 `Callable`/參數)由 lead-programmer 第一步決定並寫入回報。**無需管理者裁決。**
2. creative-director 10B(2):「POS 距離 2 不付戰場代價」縫隙是否可接受 —— **不阻擋本單**(規格已標 DEFER-TO-CALIBRATION,M6 追蹤),僅在 AC 內留測試把現況鎖住。

## 規則

- 逐列實作 5.1 表;`N` = 本場該配對已累計折損(0~`pair_cost_cap`),取自 015 存在 `BattleState` 的計數器。
- S 取**當下**值(012);S 在累計後改變,依當下 S 套對應列(NONE 時暫無作用、回到 POS/NEG 重新生效)。
- 夾限仍只做一次(不在扣減處夾)。

## Acceptance Criteria

- [ ] **AC1 5.1 表每列 1 條**:NONE 恆 0(任何 N、任何距離);POS 相鄰 N=1:3→1、N=2:3→0(下限);**POS 距離 ≥3:折損前後同為 −1;POS 距離 2:前後同為 0**;NEG 相鄰 N=1:−1→−2;NEG 距離 ≥3 N=1:2→1;NEG 距離 2 N=1:0→−1。
- [ ] **AC2 夾限順序**:扣減在夾限之前,夾限只在 `bonus_breakdown_for_at` 內一次(測試:構造 Σ 超 `PHI_MAX` 時,折損先扣再夾,結果與「先夾再扣」不同 → 證明順序)。
- [ ] **AC3 S 翻轉**:`N=2` 後 S 由 POS→NONE 再回 POS,貢獻 3→0(NONE)→0(POS,N=2 下限)的實際輸出。
- [ ] **AC4 `N=0` 回歸**:所有既有 Φ 測試全綠且斷言不改。
- [ ] **AC5 不改池**:折損影響 Φ 但不寫池、不改 S(`state_of` 前後相同)。
- [ ] **AC6 敏感度證明**(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①POS 的 `c0≤0` 也被扣(抬/壓)→ AC1 紅 ②NEG 用 `phi_loss_positive` → AC1 紅 ③先夾限後扣減 → AC2 紅 ④NONE 也扣 → AC1 紅 ⑤改 `amp` 代替扣減 → AC1 紅 ⑥扣減與夾限兩處各做一次 → AC2 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 付款(015)、`phi_loss_*` 旋鈕調校(量測 025/M6)。

## Affected Files

- `src/gameplay/affinity/affinity_rules.gd`、`src/gameplay/affinity/affinity_phi_provider.gd`(`bonus_breakdown_for_at` 所在檔,第一步確認)、旋鈕檔
- 新測試:`tests/unit/gameplay/affinity/pair_cost_phi_deduction_test.gd`

超出此清單先問。

## 與其他工單的順序

- **依賴 012、013、015**;025 依賴本單。
