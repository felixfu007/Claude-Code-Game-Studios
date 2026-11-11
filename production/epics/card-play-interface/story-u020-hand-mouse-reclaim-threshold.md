# Story U-020:手牌加滑鼠奪權門檻(手把/鍵盤選牌時滑鼠微動不得搶焦點)

> **Epic**: `production/epics/card-play-interface/`(手牌列 `hand_bar.gd` 屬本 epic)
> **Status**: Ready(2026-11-11 協調者起草)
> **Type**: Logic + Integration
> **指派**: `godot-gdscript-specialist`

## 裁決來源

管理者 2026-11-11 逐字選項:「**手牌加同款門檻,設計文件註明「手牌例外」(推薦)**」(被跳過:手牌整個接入統一游標系統 / 先不修、今晚自己感受)。

證據:
- `prototypes/hand-focus-mouse-steal-probe-2026-11-11/run_output.txt`(真實 `BattleScreen.tscn`,headless 狀態量測):
  `PROBE test (mouse on other card, rel=(1,0)): cursor_index=0 before=1 stolen=true`。
- 成因(讀碼,探針 README):`battle_screen.gd` `_input()` 對每個 `InputEventMouseMotion` 呼叫 `_hover_hand_card()`,後者無位移門檻、無裝置權威。
- 偏離背景:`docs/reviews/card-slot-surface-decision-2026-11-11.md`(GDD `skill-card-system.md` 依賴表要求卡牌選取走單一游標狀態源;實作為私有焦點)。

## 範圍

1. 手牌焦點由**鍵盤/手把**最近一次移動後,滑鼠需累積位移超過門檻才可改變手牌焦點;門檻值**必須取自既有** `src/ui/cursor/mouse_reclaim_threshold_config.gd` 的 `card_slot_threshold_px`(現值 75.0),**不得另寫一份數字或公式**。
2. 滑鼠一旦奪回(超過門檻),之後的滑鼠懸停照現行即時跟隨,直到下一次鍵盤/手把移動。
3. 以滑鼠開啟手牌、純滑鼠操作者的手感不得改變(首次懸停即跟隨)—— 實作者依 ADR-0005 裝置權威語意判斷「最近輸入裝置」的取得方式,優先共用 `CursorStateHost` 既有狀態;若共用不可行,在回報寫明理由。
4. 不改 `CursorTypes.SurfaceType.CARD_SLOT` 的註冊狀態(手牌仍不接統一游標系統 —— 本裁決為「例外」)。

## Affected Files

- `src/ui/battle/battle_screen.gd`(`_input` 的滑鼠移動分支、`_hover_hand_card`)
- `src/ui/battle/hand_bar.gd`(若需記錄最近輸入來源)
- `src/ui/cursor/mouse_reclaim_threshold_config.gd`(**只讀取**;若需新增讀取介面才可改)
- 測試:`tests/integration/ui/battle/` 下新增一檔;既有手牌測試若需配合(只改輸入前置,不放寬斷言)

## Acceptance Criteria

- [ ] **AC-1**:鍵盤/手把把焦點移到第 2 張後,滑鼠在另一張牌上微動(累積 < 門檻)→ 焦點不變。**[自動]**(重現探針情境)
- [ ] **AC-2**:同上,累積位移 ≥ 門檻 → 焦點改到滑鼠下那張。**[自動]**
- [ ] **AC-3**:純滑鼠操作(開手牌後未用過鍵盤/手把)→ 首次懸停即跟隨(手感不變)。**[自動]**
- [ ] **AC-4**:門檻值來源是 `card_slot_threshold_px`(改該值會改變行為的測試或注入證明)。**[自動]**
- [ ] 敏感度證明:拿掉門檻判斷 → AC-1 紅 → 還原。
- [ ] 🔴 交付硬性義務:全套跑完,貼 `ENGINE EXIT`、`Overall Summary`、`Executed test suites` 原始三行。
- 實體手把與真實滑鼠的手感:在家驗收。

## Out of Scope

手牌接入統一游標系統(CARD_SLOT 註冊);設計文件「手牌例外」加註(協調者另派 ux-designer,已獲同一裁決授權)。
