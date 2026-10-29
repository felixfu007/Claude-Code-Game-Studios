# Story 026:游標指到可攻擊的敵人時,右上資訊框顯示傷害拆解

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-10-29)—— 🔴 **須在 story-025 交付後才開工**(同一個檔)
> **Type**: UI
> **Estimate**: M
> **依據**: 管理者 2026-10-29 裁決,選項逐字「**游標指到可攻擊的敵人時,右上資訊框顯示傷害拆解(推薦)**」;
> 被跳過:「恢復確認框(撤回今天的改動)」、「接受,暫時不顯示」。

## 為什麼

story-023 拿掉攻擊確認框後,遊戲裡**沒有任何地方**在出手前顯示傷害與好感度修正 `Φ` 的貢獻 ——
確認框是唯一使用 `BattleState.preview_damage_breakdown()` 的畫面。而 GDD `tactical-combat-system.md`
UI Requirements 第 4 節把「拆解出 `Φ` 的貢獻」定為支柱二在回饋層的硬性約束。
(協調者上午問確認框裁決時**沒有揭露這個連帶**,下午發現後重新請管理者裁決。)

## Acceptance Criteria

- [ ] **AC1** 我方已選定一個可攻擊的單位,游標(鍵盤/手把游標或滑鼠懸停)停在**該單位攻擊範圍內的敵人**上 → 右上資訊框顯示傷害拆解,至少五欄:`ATK`、`DEF`、`Φ`(**帶號**)、結果傷害 `max(0, ATK − DEF + Φ)`、目標剩餘 HP 預估。
- [ ] **AC2** `Φ = 0` 時**仍顯示該欄並標示 0**,不得隱藏(GDD 第 4 節硬性約束)。
- [ ] **AC3** 數字一律取自 `BattleState.preview_damage_breakdown()`(不得另算一份);`Φ` 取自畫面現行的好感度來源(與實際結算同一個 `phi` 提供者)。以測試斷言「預覽傷害 == 隨後實際扣血」。
- [ ] **AC4** 游標移到非攻擊目標(空地、我方、範圍外敵人)→ 回到 story-024 的行為(有單位顯示單位資訊,空地隱藏)。
- [ ] **AC5** 每次游標進入目標格都重新計算,不沿用上一次結果(GDD 第 5 節)。
- [ ] **AC6** 文字走 `strings.csv` 新鍵,不得寫死中文;框高容納五欄不截斷。
- [ ] 敏感度證明:AC1、AC2 各一條。

## Affected Files

`src/ui/battle/battle_screen.gd`、`src/ui/battle/hud_layout.gd`、`assets/data/locales/strings.csv`、`tests/unit/core/i18n/locale_data_integrity_test.gd`(只改列數)、新測試檔。
