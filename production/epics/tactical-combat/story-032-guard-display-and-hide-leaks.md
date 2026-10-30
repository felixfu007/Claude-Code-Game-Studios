# Story 032:減傷顯示(指到我方角色 + 移動預覽)+ 隱藏好感度設定補漏

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: ✅ Done-pending-visual(2026-10-30;協調者重跑 1731 條全綠 / ENGINE EXIT 0)。AC1 獨行段讀實況出手旗標;AC2 移動預覽為「若不出手」值(雙值顯示未裁決)。範圍外舊測試 egm_guess_selector 三處改用 `_expected_info_line`,維持 is_equal(裁決 17;第二、三處協調者視為同裁決範圍)(原狀態:Ready(2026-10-30))
> **Type**: UI
> **Estimate**: M
> **依據**(管理者裁決逐字,2026-10-30):
> - 「指到我方角色+移動預覽都顯示(推薦)」(被跳過:只在指到我方角色時 / 先不顯示)
> - 「補左下文字與卡牌,預判模式不動(推薦)」(被跳過:先不補,真人測試前再做)
> 起因:story-031 AC6 的「減傷 N」列只出現在我方攻擊預覽,而敵方 guard 恆 0 → 真實遊戲中永不顯示(協調者寫單假設錯誤)。story-009 實作者回報的洩漏清單。
> 規則權威:`design/gdd/affinity-position-chain.md` 公式四(guard)、公式五(戊獨行 lone_guard)。

## Acceptance Criteria

- [ ] **AC1 指到我方角色**:游標停在我方單位上時,右上資訊框顯示該單位**目前所在格**的減傷(guard ≠ 0 才顯示;正為「減傷 N」、負為「額外受傷 N」,沿用 story-031 AC6 的兩個字串鍵)。數值必須取自正式計算(`BattleState` 的 guard 計算 / `lone_guard_if_at`,以及防守方 Φ 的正式來源),**不得在 UI 重寫公式**。
- [ ] **AC2 移動預覽**:選取我方單位、游標移到可移動格時,左下資訊列現有「好感度 +a→+b」旁(或同一列),顯示「減傷 x→y」(移動前→站到該格後;皆為 0 時不顯示)。假設位置的計算必須呼叫正式函式;若正式程式缺「假設位置的好感度減傷」查詢,**停下回報**,不要在 UI 重寫。
- [ ] **AC3 隱藏好感度設定補漏**:設定開啟時,①左下資訊列的好感度文字(`battle.hud.affinity_preview_format` / `affinity_current_format`)不顯示 ②卡牌確認面板的「好感度:」那一列不顯示 ③AC1/AC2 中**好感度造成的減傷**部分不顯示,**戊獨行減傷照常顯示**(管理者裁決:獨行不是好感度)。預判模式(EGM)不動。
- [ ] **AC4** 每條 AC 至少一條測試;一條敏感度證明並確認還原。
- [ ] **AC5** 隱藏設定開啟時戰鬥結算不變(沿用 story-009 的同類斷言即可,不必重寫)。

## 🔴 防過擬合

不得以新規則在第 1 場(vs01)跑對局或自動對戰(協議 2 規則;attempt-2 已判定,但仍不得為 UI 目的跑 vs01 對局)。載入真實場景的整合測試照既有慣例。

## 不在範圍

預判模式、敵方減傷、數值調整(創意總監審查中,數值不動)、開窗目視(管理者在家)。

## Affected Files

`src/ui/battle/battle_screen.gd`、卡牌確認面板所在檔(實作者 grep `strength_label_format` 定位並列在回報)、`src/gameplay/battle/battle_state.gd`(**僅在**需要新增唯讀的「假設位置好感度減傷」查詢時,且須重用既有計算)、`assets/data/locales/strings.csv`、`tests/unit/core/i18n/locale_data_integrity_test.gd`(只改列數)、新測試檔。
