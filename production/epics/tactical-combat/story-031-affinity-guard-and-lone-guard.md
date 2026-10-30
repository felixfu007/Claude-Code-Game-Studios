# Story 031:好感度減傷(guard)+ 戊獨行減傷

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: ✅ Done-pending-visual(2026-10-30;AC6 `23acffc`,其「我方攻擊時才出現」缺陷由 story-032 補上顯示位置)。以下為前一狀態:🟡 進行中(2026-10-30)—— AC1~5、7、8 完成(規則程式提交 = attempt-2 登記的 S;協調者重跑 1695 條全綠 / ENGINE EXIT 0)。**AC6(畫面「減傷 N」列)未做**。⚠️ 技術債:`GUARD_MIN/MAX`、獨行常數為程式常數(同既有 `PHI_MIN/MAX` 慣例),字面違反 gameplay-code「數值資料驅動」。⚠️ 防守方 Φ 需 `attach_defense_phi_provider()`,**未接即靜默為 0**(遊戲本體 battle_screen 已接)(原狀態:Ready(2026-10-30))
> **Type**: Logic + Integration
> **Estimate**: L
> **權威規格**:`docs/reviews/affinity-core-redesign-spec-2026-10-30.md` 第 1、2 節(公式、值域、算例、同步點)。**本單不複述公式,以該檔為準。** GDD 正在同步改寫(另派),衝突時以規格檔為準並回報。
> **依據**(管理者裁決逐字,2026-10-30):
> - 「重新設計核心,美術照常」(非推薦項)
> - 「好感度減傷+戊獨行機制(推薦)」(選項原文誤植「戈」,指戊)
> - 「獨行減傷(推薦)」(被跳過:獨行加攻加防)
> - 「可以,舊文保留加註(推薦)」(文件同步)
> 起因:協議 2 探針關電腦對照 attempt-1 未通過(`production/qa/protocol2/computer-attempt-1-20261030T0120Z/VERDICT.md`),敗因診斷 `prototypes/protocol2-diagnosis-2026-10-30/README.md`。

## Acceptance Criteria

- [ ] **AC1 guard 純函式**:依規格 1.2 實作 `guard(Φ_def)` 與 `guard_total` 夾限(`GUARD_MIN=-2`、`GUARD_MAX=+3`,常數具名、可調);負 Φ 依 1.3 為額外受傷。單元測試涵蓋規格 1.4 三個算例 + 夾限上下界 + Φ=0。
- [ ] **AC2 戊獨行 lone_guard**:依規格 2.2 候選 X:`d_min≥3 → +2`、`=2 → 0`、`=1 → −1`、無存活隊友 → `+2`;距離用 `AffinityRules.manhattan_distance()`(不得另寫)。🔴 「誰適用獨行」**不得寫死單位 id 或代號** —— 資料驅動(例:名冊或關係資料中的旗標/欄位),實作者選定做法並寫明。
- [ ] **AC3 防守方 Φ 取得**:先查證 `affinity_phi_provider.gd` 能否取得防守方所在格 Φ;不能則新增唯讀方法。只對 PLAYER 防守方生效;敵方防守 guard 恆 0。
- [ ] **AC4 單一出處**:`BattleState._attack_damage_breakdown()` 加 `phi_def`、`guard` 欄位;`preview_damage()`、`preview_damage_breakdown()`、`resolve_attack()` 共用它。🔴 **敵方攻擊時 Φ_att 仍為 0,但 guard 必須照算**(規格 1.5 最後一點 —— 最容易漏)。以測試斷言:敵方攻擊站在 Φ=+3 格的我方單位,實際扣血比舊規則少 2。
- [ ] **AC5 電腦/AI 傷害預估**:`src/ai/` 內若自行算傷害,改走同一 helper;查證並寫明。
- [ ] **AC6 UI 預覽**:右上資訊框傷害拆解新增「減傷 N」一列(N≠0 時顯示);story-009「隱藏好感度顯示」開啟時,好感度造成的減傷列比照 Φ 列隱藏(戊獨行減傷在該設定開啟時是否也隱藏:**未裁決** —— 實作者先維持顯示,於回報中提出,交協調者轉呈)。字串走 `strings.csv`。
- [ ] **AC7 既有測試**:因規則改變而失效的既有斷言,**逐條列出舊值→新值與理由**;只改受新規則影響的數字,不得放寬斷言。
- [ ] **AC8 敏感度證明**:①拿掉敵方攻擊時的 guard → AC4 測試變紅 ②戊獨行閾值改錯 → AC2 測試變紅;各一次,確認還原。

## 🔴 防過擬合(管理者裁決的重測規則)

**不得用新規則在第 1 場(vs01)跑任何東西**,包括載入測試以外的對戰/自動對戰。既有測試若本來就載入 vs01 並斷言數值,照 AC7 處理,不得新增跑 vs01 對局的測試。

## 不在範圍

GDD 文件修改(另派 game-designer)、電腦對照工具 attempt-2(另派)、畫面開窗驗證(管理者在家)。

## Affected Files

`src/gameplay/combat/combat_rules.gd`、`src/gameplay/battle/battle_state.gd`、`src/gameplay/battle/battle_loop.gd`(只動傷害相關)、`src/gameplay/affinity/affinity_phi_provider.gd`、`src/gameplay/affinity/affinity_rules.gd`(只在需要新增唯讀查詢時)、`src/ai/` 內傷害預估檔、`src/ui/battle/battle_screen.gd`(只動傷害拆解列)、`src/ui/battle/attack_confirm_panel.gd`(若仍被引用)、名冊/關係資料格式與其解析器(若 AC2 選用資料欄位,逐一列在回報)、`assets/data/locales/strings.csv`、`tests/unit/core/i18n/locale_data_integrity_test.gd`(只改列數)、新測試檔;AC7 列出的既有測試檔。
