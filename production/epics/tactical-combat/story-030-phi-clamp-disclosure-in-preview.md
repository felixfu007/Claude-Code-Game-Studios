# Story 030:傷害預覽框補回「好感度原始值/夾限值」說明

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Backlog(2026-10-29 登記,未排期)
> **Type**: UI
> **Estimate**: S
> **依據**: 管理者 2026-10-29 裁決「**開工作單,之後做(推薦)**」;被跳過:「今天就做」、「不做」。

## 為什麼

story-013 的攻擊確認框在 `Φ` 被夾限時,會多顯示一行「好感度原始值 X,結算夾限為 Y」
(字串鍵 `battle.attack_confirm.phi_clamped_format`)。story-023 拿掉確認框、story-026 把拆解搬進右上資訊框時,
這行因框寬不足(約 17 字)**沒有移植**(`4645c9d` 提交訊息與 `_build_attack_preview_text()` 的註解已記載)。
傷害數字正確,但玩家看不到夾限發生過。

📌 **不急的理由**:現行真實關卡的 `Φ` 值域極小(甲乙 +3/−1、丙丁 +2/−1、戊 0),幾乎不會觸發夾限。
**卡牌系統或好感度強度倍率(`amp`)一旦放大 `Φ`,這張就會變急** —— 那時回來做。

## Acceptance Criteria

- [ ] **AC1** 夾限發生時(原始 `Φ` ≠ 結算 `Φ`),預覽框顯示夾限說明(沿用既有字串鍵),且不截斷。
- [ ] **AC2** 未夾限時不顯示該行。
- [ ] **AC3** 數字取自 `preview_damage_breakdown()`,不另算。
- [ ] 敏感度證明 AC1 一條。

## Affected Files

`src/ui/battle/battle_screen.gd`、`src/ui/battle/hud_layout.gd`、新測試檔。
