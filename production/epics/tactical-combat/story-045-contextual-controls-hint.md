# Story 045:提示列依裝置與目前狀態只顯示相關按鍵;勝敗/敵方回合不再顯示「移動…確認」

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-12)—— 🔴 含一項須先裁決的設計缺口(見「派工前須先決定」第 1 點)
> **Type**: Logic + UI
> **Estimate**: M
> **優先序**: 畫面可讀性批次 T6
> **依據**:
> - 管理者 2026-11-12 核准範圍,選項逐字「**修今天的字重疊 + 介面 + 重做高亮層次 + 圖例(UX 專家推薦)**」(含 T6)。紀錄:`active.md` 第九十九批節(grep「重做高亮層次」)。
> - 證據:`docs/reviews/screen-readability-verified-ux-2026-11-12.md` B3(鍵盤手把混寫一行,且**每個狀態都一模一樣**:手牌展開、敵方回合、勝敗皆仍寫「移動…確認…」)與 N6、B2。

## 為什麼

提示列恆為同一串「移動 方向鍵/十字鍵/滑鼠　確認 Enter/A/左鍵…」,鍵盤、手把、滑鼠混寫;勝敗後與敵方回合也不變,等於在說謊。

## 派工前須先決定

1. 🔴 **「依裝置」的資料來源有缺口(lead-programmer 2026-11-12 實查)**:現有裝置權威 `CursorState.get_device_authority()`(ADR-0005)
   只有 `Authority { UNINITIALIZED, MOUSE, KEYBOARD_GAMEPAD }` 三值 —— **分不出「鍵盤」與「手把」**,而提示列要區分的恰是這兩者。
   選項:
   - (甲)**提示列自己維護一個「最近一次輸入屬於鍵盤事件或手把事件」的檢視用旗標**(在 `BattleScreen` 輸入處理處更新;滑鼠仍取自 `CursorState` 權威)。
     只影響顯示、不碰游標系統、不需動 ADR-0005。**lead-programmer 推薦此案。**
   - (乙)擴充 `CursorTypes.Authority` 增第三個值。牽動 ADR-0005 契約(`Accepted`)與游標系統全部測試,**須 technical-director 裁決**,不推薦。
   實作者**採甲案時須在回報明寫**,並確認該旗標不寫入任何遊戲狀態;要採乙案則停下回報。
2. **各狀態該顯示什麼的文案**(下方 AC2 的表)為 lead-programmer 草擬,**須 ux-designer 覆核字句與鍵名**後再落字串;實作者不得自行增刪鍵名。

## Acceptance Criteria

- [ ] **AC1 純函式(單一出處)**
      新增可 `new()`/靜態呼叫的純函式(建議放 `HudLayout` 旁或新檔 `controls_hint_content.gd`):
      `segments_for(state: HintState, device: HintDevice) -> PackedStringArray`,回傳**在地化後**的片段陣列;
      `HintState { NO_SELECTION, UNIT_SELECTED, HAND_OPEN, MENU_OPEN, ENEMY_PHASE, FINISHED }`、`HintDevice { MOUSE, KEYBOARD, GAMEPAD }`。
      🔴 **UI 不得自行判斷狀態**:`BattleScreen` 只把已有的 `BattleController.Phase`、手牌是否展開、選單是否開啟、是否有選取單位**映射**到 `HintState`,映射寫在一處。
- [ ] **AC2 內容規則(可測,逐格斷言)**

      | 狀態 | 顯示 | 絕不含 |
      |---|---|---|
      | `ENEMY_PHASE` | 只顯示一句「敵方行動中」類提示(文案由 UX 覆核)與可用的「選單」鍵 | 「移動…確認…取消…」 |
      | `FINISHED` | 只顯示「確認/離開」類 | 「移動」「結束單位」「跳目標」 |
      | `HAND_OPEN` | 左右選牌、確認、關閉手牌 | 「結束單位」「跳目標」 |
      | `MENU_OPEN` | 上下選、確認、關閉 | 其餘一切 |
      | `NO_SELECTION` / `UNIT_SELECTED` | 該裝置的移動、確認、取消、開手牌、選單、結束單位 | 其他兩種裝置的按鍵名 |

      每種裝置只出現該裝置的鍵名(滑鼠:左鍵/右鍵;鍵盤:方向鍵/Enter/Esc/C/M/Q/Tab;手把:十字鍵/A/B/X/Start/Back/RB)。
      測試**逐一斷言「含」與「絕不含」**。🔴 **防空洞**:須斷言 6 個狀態 × 3 種裝置的回傳**都非空**,且至少有一組兩個狀態的回傳彼此不同(否則「全部回同一串」會綠)。
- [ ] **AC3 在地化**
      所有字串走 `assets/data/locales/strings.csv`(不得寫死);新增列後 `tests/unit/core/i18n/locale_data_integrity_test.gd` 的資料列數斷言同步
      (實作者當場 `grep -n "is_equal(1" tests/unit/core/i18n/locale_data_integrity_test.gd` 取現值,不抄本單的數字)。
      既有 `battle.hud.controls_hint` 鍵的兩行字串:若不再使用則移除並確認無殘留引用,若保留作後備須說明。改完走 `run_tests_with_import.sh`。
- [ ] **AC4 單行與窄視窗**
      與 story-004 AC3(說明列單行)與 story-028 G(`HudLayout.compact_hint_text`)的契約相容:每個(狀態 × 裝置)的文字在 960×540 實測寬度
      `<= HudLayout.compact_hint_available_width(size)`(用真實 HUD 字型量,不得估算);放不下時的退路沿用既有「依段落位置取前 N 段」機制。
      既有測試 `tests/integration/ui/battle/battle_screen_story_028_minor_hud_test.gd` 全綠;若斷言隨之改,逐條說明。
- [ ] **AC5 即時更新**
      狀態(`HintState`)或裝置改變時提示列同幀更新:對真實 `BattleScreen`(注入合成資料,載入真實場景檔)測試:
      切到敵方回合 → 文字不含「確認」;開手牌 → 內容變;滑鼠權威 → 含「左鍵」不含 `Enter`。
- [ ] **AC6 敏感度證明**(🔴 一個 mutant 一次獨立執行)
      ①`ENEMY_PHASE` 回傳改成 `UNIT_SELECTED` 的內容 → AC2 紅 ②裝置參數被忽略(一律回鍵盤) → AC2 紅 ③`FINISHED` 映射漏掉 → AC5 紅。
      交付前掃描殘留注入標記。
- [ ] **AC7 像素層待補拍**:960×540 與 1920×1080 各拍:選取單位、敵方回合、戰敗畫面三態;人開圖確認提示列各自相關、不被截斷。依截圖規則先判類別。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## 未涵蓋(刻意)

- 敵方回合橫幅/標題色 → T11(story-049),須本單後做(提示列同步)。
- 選單內容調整(「效果猜測標記：關閉」開發味標籤)→ T7(story-046)。
- 手把按鍵圖示化(用圖示取代文字)。

## Affected Files

- `src/ui/battle/battle_screen.gd`(狀態映射、裝置旗標、呼叫純函式更新提示列)
- `src/ui/battle/hud_layout.gd`(`compact_hint_text` 與新函式的相容)或新檔 `src/ui/battle/controls_hint_content.gd`
- `assets/data/locales/strings.csv`
- `tests/unit/core/i18n/locale_data_integrity_test.gd`(列數)
- 新測試檔:`tests/unit/ui/controls_hint_content_test.gd`、`tests/integration/ui/battle_screen_contextual_hint_test.gd`
- `tests/integration/ui/battle/battle_screen_story_028_minor_hud_test.gd`(若斷言隨之調整)

超出此清單先問。

## 與其他工單的順序

與 story-043(T3)、story-046(T7)、story-049(T11)**同動 `battle_screen.gd`,須序列**。建議:043 → **045** → 046 → 049。

> 📌 **2026-11-12 加註**(管理者 2026-11-12 核准加註(選項「三張新工單補 UX 實拍發現」;紀錄 `production/session-state/active.md` 第九十九批節)):依 `docs/reviews/screen-readability-verified-ux-addendum-2026-11-12.md`:M2 —— 底部提示列的「取消 Esc/B/右鍵」「選單 M/Start」在 960、1920、2560 不見(推測依寬度被丟,未讀碼),須定義寬度不足時的優先序(UX 建議取消優先)並加驗收;M4 —— 選牌選目標、確認面板兩個狀態提示列內容不變,須納入本單狀態清單。
