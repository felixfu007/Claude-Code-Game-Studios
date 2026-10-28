# Story 022:戰敗畫面顯示「誰倒下了」

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: ✅ **Done-pending-visual(2026-10-28)** —— 5 條測試;協調者重跑 1559 全綠。範圍外舊測試 `battle_screen_battle_outcome_test.gd` 一行連帶修改,管理者 10/28 裁決「接受」。原狀態:Ready(2026-10-28)
> **Type**: UI
> **Estimate**: S
> **依據**: 管理者 2026-10-28 裁決,選項逐字「**只做一個「戰敗原因」文字,其餘仍不做提示(推薦)**」;
> 被跳過:「接教學關流程」、「今天到此,收工」。

## 為什麼

本作敗北規則是「我方任一人 HP 歸零即敗」(`BattleState.outcome()`)。戰敗時畫面只顯示「戰敗」,
玩家不知道是誰倒了。今天兩件事指向同一處:自動對戰顯示這條規則是最常見的敗因
(`docs/reviews/difficulty-analysis-2026-10-28.md`);教學關初稿與關卡設計專家指出,
不做提示文字的情況下這條規則教不出來(`design/quick-specs/tutorial-level.md` P3)。
🔴 **這是管理者「教學關不做提示文字」裁決的一個明文小例外**,不是推翻它。

## Acceptance Criteria

- [ ] **AC1** 戰敗時結果文字為「戰敗」加上倒下的我方角色名(例「戰敗——丙倒下了」),格式走 `strings.csv` 新鍵;角色名用既有 `character.name.N`(`N` = roster id)。
- [ ] **AC2** 同一敵方回合倒下多人 → 全部列出(在地化的分隔符號,例「、」)。
- [ ] **AC3** 勝利、戰役完成的文字**逐字不變**(既有測試全綠)。
- [ ] **AC4** 倒下者判定讀 `BattleState` 既有的存活資料(不得另記一份)。
- [ ] 敏感度證明門檻。

## Affected Files

`src/ui/battle/battle_screen.gd`、`assets/data/locales/strings.csv`、`tests/unit/core/i18n/locale_data_integrity_test.gd`(只改列數)、`tests/integration/ui/battle/...`(新)。
