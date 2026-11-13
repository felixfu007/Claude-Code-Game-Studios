# Story 052:視線被擋章只畫在敵兵格(空格不畫)

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-13)—— ✅ **GDD 已由協調者同步**(`tactical-combat-system.md` 第 105/557/563/565 行共 4 行;下節建議文字保留作決策紀錄,以 GDD 現文為準)
> **Type**: Visual/UI(世界層)+ Logic(篩選規則)
> **Estimate**: S(約 0.5~1 天:篩選 0.25、改測試 0.25、補拍 0.25)
> **依據**:
> - 管理者 2026-11-13 裁決,選項逐字「**空格完全不畫,只畫在敵兵格(介面設計師推薦)**」(當場查 `grep -n "空格完全不畫" production/session-state/active.md`;裁決含須改 GDD §1.3 的前提)。
> - 事實:`docs/reviews/lunch-capture-code-facts-2026-11-13.md` 第 1 項 —— 丙在 (4,3) 時被擋集合 = 21 格(讀碼 + 真實類別 PROBE),語意是「單一原點、純幾何、含空格」,不是 bug,是密度問題。

## 為什麼

story-044 的被擋章對「射程內視線被擋的每一格」都蓋,含沒有任何東西的空格;射程 6 的單位一次 21 個章。玩家要判斷的是「那個敵人我打不打得到」,空格被擋對決策沒有價值。

## 規則(單一出處)

被擋章只畫在「被擋集合 ∩ 存活敵兵所在格」。**被擋集合本身(`BattleController.attack_targets_blocked_by_los()`)不改**,仍是純幾何、含空格 —— 控制器測試與 ADR-0001 的查詢契約不受影響。篩選發生在**顯示層**(`BattleScreen` 呼叫 `set_attack_los_blocked_highlights` 之前,依現有單位佔位資料過濾;**不得**在 `BoardView` 內自己查規則)。
敵兵死亡後該格不再是敵兵格 → 章消失(下一次重畫即可,不需特例)。

## GDD 修改建議(✅ 已同步,以下為當初建議,保留作紀錄;本單不改 GDD)

`design/gdd/tactical-combat-system.md` 兩處,現有文字為「視線被擋的格子須明確標示為不可攻擊而非隱藏選項」的語意:

1. **Core Rules #4**(約第 105 行)原句片段:`UI 須明確標示為不可攻擊而非隱藏選項`
   → 建議改為:`UI 須明確標示該次攻擊為不可攻擊而非隱藏選項:以「視線被擋」章標在被擋的敵兵所在格;沒有單位的空格不標(2026-11-13 管理者裁決,理由:空格上沒有可選的攻擊目標,標示只增加雜訊)`。
2. **Visual/Audio §1.3**(約第 555~566 行):
   - 第 557 行 `視線被擋的格子「須明確標示為不可攻擊而非隱藏選項」。` → `視線被擋的敵兵格「須明確標示為不可攻擊而非隱藏選項」(空格不標,見 Core Rules #4 修訂)。`
   - 表中第三列 `疊加:範圍內但不可攻擊` 條件欄尾加:`且該格有敵兵(空格不疊加)`。
   - 第 566 行 `若第三層被畫成與「無疊加」相同(即被隱藏),玩家會誤判可攻擊格數` → 末尾加 `此風險僅對有敵兵的格成立;空格無攻擊目標,不標不會造成誤判`。
   - 🔴 **同步檢查**:`grep -n "不留白\|不得留白\|隱藏選項" design/gdd/tactical-combat-system.md` 當場查,另有同語意處一併改(本單寫作時查到 105、557、566 三行,未逐字窮盡)。
3. 程式註解 `src/ui/battle/board_view.gd` 的 `set_attack_los_blocked_highlights` 文件註解(「must never be left undrawn for these cells」)與 BLOCKED 常數註解自稱「仍合 GDD」須隨改;屬本單 Affected Files。

## Acceptance Criteria

- [ ] **AC1 篩選**:選取丙(射程 min2/max6)於合成/真實 vs01 佈局,被擋章只出現在「被擋集合中有存活敵兵的格」;空格零章。對真實 `BattleScreen`(注入合成資料,載入真實場景檔)測;防空洞:斷言被擋集合本身 ≥1 格含空格(否則篩選沒被考驗)且至少 1 個敵兵格有章。
- [ ] **AC2 敵兵死亡**:敵兵被擊殺後重畫,該格章消失;其餘敵兵格章不受影響。
- [ ] **AC2b 威脅區不留洞(art 補遺第 4 節第 6 項)**:現行 `battle_screen.gd` 的威脅排除清單把**整個被擋集合**都排除(`threat_excluded.append_array(attack_los_blocked_cells)`,story-014 「被擋 > 威脅」互斥)。空格不畫章後,被擋的空格既無章又無威脅,會在威脅區裡留洞。**規則改為:威脅排除只套用在「真的畫了章的格」(被擋 ∩ 存活敵兵格);被擋的空格若屬威脅集合,照常畫威脅。** **動 `battle_screen.gd` 該排除邏輯在本單範圍內**(同一段、約 4935~4965 行)。測試:合成佈局使某被擋空格同時落在威脅集合 → 該格有威脅標記、無章;某被擋敵兵格同時在威脅集合 → 有章、無威脅標記(互斥仍成立)。🔴 **防空洞**:兩種格各至少 1 個(斷言集合非空,否則排除邏輯沒被考驗)。仍保留既有排除:移動格、可攻擊格、我方單位格。
- [ ] **AC3 控制器查詢不變**:`attack_targets_blocked_by_los()` 回傳值測試全綠、零修改。
- [ ] **AC4 既有測試調整(逐條說明)**:
      - `tests/integration/ui/board_view_highlight_hierarchy_test.gd` 的 `test_blocked_cell_draws_exactly_one_corner_stamp_outside_label_zone`:此測試直接餵 `BoardView.set_attack_los_blocked_highlights([(3,3),(6,1)])` 並斷言每格恰一章 —— **篩選放在 BattleScreen 側,故此測試(BoardView 單元層級)語意不變、預期仍綠**;實作者須確認並寫入回報。若實作者改把篩選放進 BoardView,則此測試須改並逐條說明(不推薦)。
      - 測試名稱與檔內註解中「每個被擋格恰好畫一個」的描述,補一句「由呼叫端決定餵哪些格」避免日後誤讀為「所有被擋格都畫」。
      - `tests/integration/ui/movement_attack_range_overlay_test.gd` 中 `set_attack_los_blocked_*` 各測試同樣直呼 BoardView,預期不受影響;實作者當場跑確認。
- [ ] **AC5 敏感度證明**(🔴 一個 mutant 一次獨立執行):①篩選拿掉(回到全部被擋格) → AC1 紅 ①b 威脅排除仍用整個被擋集合 → AC2b 紅 ②篩選反向(只畫空格) → AC1 紅 ③死亡敵兵仍計入 → AC2 紅。交付前掃殘留注入標記。
- [ ] **AC6 說明不退化**:滑鼠停在「被擋的空格」時,story-040 的被擋原因行與 story-042 的「擋視線」資訊卡文字**仍正常顯示**(章不畫不等於原因不告知);加一條測試或實測紀錄。
- [ ] **AC7 像素層待補拍**:960×540 與 1920×1080 各一張:丙選取(vs01 佈局,原 21 格情境)—— 人開圖確認只剩敵兵格有章、畫面明顯變清爽、章不蓋敵兵首字/血量條。依截圖規則先判類別。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## 未涵蓋(刻意)

- 被擋章樣式本身(story-044 已定,不動)。
- 「圖例」(story-047)若已寫「被擋章」說明,文字須與本規則一致(只標敵兵格)—— 047 落地時同步,不屬本單。
- 多原點(移動後可打到)的被擋判定 —— 現行刻意單原點,不動。

## Affected Files

- `src/ui/battle/battle_screen.gd`(呼叫 `set_attack_los_blocked_highlights` 前篩選 + 威脅排除邏輯改只排除有章的格,約第 4935~4965 行那段)
- `src/ui/battle/board_view.gd`(僅文件註解/常數註解)
- `tests/integration/ui/board_view_highlight_hierarchy_test.gd`(註解/測試名說明,斷言預期不變)
- 新測試檔:`tests/integration/ui/battle_screen_blocked_stamp_enemy_only_test.gd`

超出此清單先問。`design/gdd/tactical-combat-system.md` **不在清單內**(既有文件)。

## 與其他工單的順序

動 `battle_screen.gd` + `board_view.gd`,須序列。建議緊接 story-050 之後(050 也動 board_view、無待決;本單無美術前置、最小),在 046 之前。story-047(圖例)須在本單之後。
