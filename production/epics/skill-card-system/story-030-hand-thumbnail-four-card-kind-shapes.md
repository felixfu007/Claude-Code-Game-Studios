# Story 030:手牌縮圖卡類別形狀改為四種(加成/改關係/傷敵/補血)

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Ready(2026-11-20 管理者裁決「分 4 種,排進這批卡牌改造(推薦)」)—— 須在 story-029 合入 main 之後開工(兩者皆動 `hand_bar.gd` / `battle_screen.gd`)。
> **Type**: UI
> **Estimate**: S~M(粗估未驗證)
> **依據**:UX 判定 `docs/reviews/hand-thumbnail-new-card-kinds-ux-2026-11-20.md`;美術規格 `docs/reviews/hand-thumbnail-shapes-art-spec-2026-11-20.md`(7×7 原生像素遮罩;有出入以該檔為準)。

## 問題(2026-11-20 協調者驗證)

- `src/ui/battle/battle_screen.gd` 的 `hand_bar_slot_kind_for()` 只對應甲類/丙類;`DIRECT_DAMAGE`、`HEAL`、`COMBO_DAMAGE` 走預設分支:`push_error` 並畫成甲類形狀。第 2~5 場牌組多為新類別 → 玩家把打人牌看成加成牌。
- `src/ui/battle/hand_bar.gd` 的圖示是單一 `ColorRect`(菱形 = 轉 45°),畫不出三角與十字;邊長 `0.7 fpx` 非整數原生像素。
- 由 2026-11-20 午休截圖驅動的 headless log 發現(61 行 `unmapped Card.Category 3/4`),無任何既有規格或工單涵蓋。

## 規則

- `HandBar.SlotKind` 共 4 種:`TEMPORARY_MODIFIER`=正方、`PERMANENT_WRITE`=菱形、新增 `DAMAGE`=三角(直傷 + 合擊共用)、新增 `HEAL`=十字。新值追加在 enum 尾端(先 grep 有無依賴序號)。
- 四形皆照美術 7×7 遮罩逐格呈現(貼圖或程式自繪由實作者定,**不得再用旋轉色塊**);邊長為原生像素整數倍、最近鄰。Z2 用同一遮罩整數倍放大。
- 四形同色(不靠顏色區分),沿用現有透明度/暗化規則。
- 預設分支不得再靜默畫成甲類:五種 `Card.Category` 全部明確對應。

## Acceptance Criteria

- [ ] **AC1** 對應:五種 `Card.Category` → 四種 SlotKind 對應表有測試(含直傷與合擊同為 DAMAGE)。
- [ ] **AC2** 圖樣:四種 SlotKind 的實際繪製遮罩與美術規格逐格相等(以讀回像素或繪製資料斷言;headless 取不到像素時改斷言繪製資料,並揭露)。
- [ ] **AC3** 真實場景:真實 `BattleScreen.tscn` 以 vs02 牌表開場,手牌不再出現 `unmapped Card.Category` 錯誤。
- [ ] **AC4** Check 5 人眼:960×540 與 1920×1080 各一張(手牌含四種 + 一張暗化),art-director 逐一指認四類;十字與正方在 N=2 若分不開,依美術規格升 9×9,再不行回報(不得自行併入加成形狀)。
- [ ] **AC5** 敏感度證明(常駐 `test_sensitivity_proof_*`):①直傷映射回 TEMPORARY_MODIFIER → AC1 紅 ②三角與十字遮罩對調 → AC2 紅。
- [ ] 交付前全套(`TEST_TIMEOUT_SEC=2400`),回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files(暫定)

- `src/ui/battle/hand_bar.gd`、`src/ui/battle/battle_screen.gd`(只限 `hand_bar_slot_kind_for`)、(若用貼圖)`assets/art/ui/` 新圖檔、相關測試。超出先問。

## 連帶文件(擁有者處理,本單不改)

- `design/ux/skill-card-play.md` 第 143 行「類別(甲/丙…)」須改為四類(ux-designer,既有文件須請示)。
