# Story 044:重做「被擋視線 / 可攻擊 / 威脅」高亮層級(可攻擊為主、被擋縮角標、威脅降調)

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-12)—— 🔴 **前置:art-director 須先交付「高亮層級規格」**(見「派工前須先決定」;沒有規格不得寫碼,數值不得由實作者自創)
> **Type**: Visual/UI(世界層)+ Logic(層級規則)
> **Estimate**: M(本批最大一張)
> **優先序**: 畫面可讀性批次 T5
> **依據**:
> - 管理者 2026-11-12 核准範圍,選項逐字「**修今天的字重疊 + 介面 + 重做高亮層次 + 圖例(UX 專家推薦)**」(含 T5)。紀錄:`active.md` 第九十九批節(grep「重做高亮層次」)。
> - 缺陷證據(兩份稽核一致):`docs/reviews/screen-readability-verified-art-2026-11-12.md` 新發現 2、4(橘框+斜線比「可攻擊」灰小點顯眼十倍,層級顛倒;
>   橘框蓋住敵兵編號;威脅紅斜紋覆蓋約四成棋盤);`docs/reviews/screen-readability-verified-ux-2026-11-12.md` N4(約 30 格橘斜線框壓住敵兵 3、4 本體)、V1。
>   圖:`21_1920x1080_02_selected_ranges.png`、`12_1440x810_03_...`。
> - 一致結論(計畫 `screen-readability-ticket-plan-2026-11-12.md` T5 節):被擋改弱、可攻擊改強、框線不壓字框區。

## 為什麼

選取單位後,橘色「被擋」標記數量多、最顯眼,真正可攻擊的格反而只有安靜的灰點;標記還把敵兵本體與首字/編號壓住。玩家看不出「我現在能打誰」。

## 派工前須先決定(lead-programmer 建議,待協調者/art-director 確認)

1. **規格先行(art-director 擁有)**:須有一份文件(建議 `design/art/highlight-hierarchy-spec-2026-11-12.md`)明定:
   ①層級順序(可攻擊 > 被擋 > 威脅,及與移動藍、游標白框的關係);②被擋標記的**角標**形狀、尺寸、位置(格內座標)、色(**色相是否入色票由 art-director 決**);
   ③威脅改「只畫邊」或降透明度的具體值;④**禁區**:任何標記不得涵蓋「字框區」(格左下 12×14,格內 x 0~12、y 8~22,見 story-041)與「目標單位本體」。
   **規格不到位前本單不開工;實作者不得自創顏色/尺寸**(專案已登記:色票外高亮色是未結案缺口,見計畫 D5)。
   此類規格不適合交 AI 繪圖。
2. **GDD 約束不得被規格破壞**:`design/gdd/tactical-combat-system.md` Visual/Audio §1.3 與 Core Rules #4 要求「視線被擋的格**必須**畫出,不得留白」
   (留白會讓被擋格看起來像射程外)。**「縮成角標」仍是「有畫」,合規;「拿掉」不合規。** 規格若想拿掉,須新裁決,實作者停下回報。
3. **48 格(640×360,草稿)**:世界層像素尺寸會變。本單要求**所有尺寸/位置抽成 `board_view.gd` 頂部具名常數**(已是現況慣例),
   層級**規則**與**繪製順序**不得寫死在像素上;48 格時只改常數。**不為 48 預先改尺寸**。

## Acceptance Criteria

- [ ] **AC1 層級規則(可測,結構斷言)**
      `BoardView` 的各高亮圖層繪製順序與「單格互斥」由程式表達並有測試:同一格不會同時畫出兩種攻擊相關標記;
      優先序(寫死,與 `BattleScreen` 傳入集合的排除邏輯一致):可攻擊 > 被擋 > 威脅。
      測試對**實際渲染出的節點樹**斷言(各圖層子節點數與位置),不只斷言常數。
- [ ] **AC2 被擋標記縮成角標**
      `set_attack_los_blocked_highlights` 不再畫整格 `ATTACK_LOS_BLOCKED_OUTLINE`(inset 4、寬 2)+ 對角斜線,改畫規格定義的角標。
      **角標矩形須落在字框區之外、且不涵蓋格中心**(依規格座標)。每個被擋格仍**恰好畫出一個**標記(GDD §1.3 不留白)。
- [ ] **AC3 可攻擊為主訊號**
      可攻擊格的標記視覺權重高於被擋與威脅(規格定義如何量:面積/不透明度);**用數字斷言**(例:可攻擊標記的「面積 × alpha」嚴格大於被擋標記的),
      **預言機取自規格常數,不得在測試內另設門檻**。防空洞:斷言三種標記各至少渲染了一個。
- [ ] **AC4 威脅降調**
      `THREAT_FILL_COLOR`(現 alpha 0.3)依規格降低或改為只畫邊;斜線形狀保留(它是不靠顏色的通道,見 `set_threat_highlights` 註解)。
      紅底透明度的既有約束「畫在棋子上方,不可把敵方棋子蓋掉」須仍成立並有測試。
- [ ] **AC5 禁區測試**
      對每個含單位的格,三種攻擊相關標記的矩形與該格的首字矩形(story-041 的單一出處函式)**不相交**;
      被擋/可攻擊標記不涵蓋「目標單位本體」規格所定義的區域。**真實場景檔載入**(`technical-preferences.md` 第 5 點)。
- [ ] **AC6 既有測試同步**
      受影響:`tests/integration/ui/movement_attack_range_overlay_test.gd`、`tests/integration/ui/battle/battle_screen_story_028_minor_hud_test.gd`、
      `tests/integration/ui/battle/battle_screen_playtest_feedback_2026_10_28_test.gd`、`tests/unit/ui/battle_screen_scene_test.gd`
      (實測它們引用了上述高亮方法/常數)。改斷言須逐條在回報說明「原斷言守什麼、為何仍守得住或為何作廢」,不得為了變綠而刪斷言。
- [ ] **AC7 敏感度證明**(🔴 一個 mutant 一次獨立執行)
      ①讓被擋標記回到整格框 → AC2 紅 ②對調可攻擊與被擋的優先序 → AC1 紅 ③威脅 alpha 改回 0.3 → AC4 紅 ④被擋角標移進字框區 → AC5 紅。
      交付前掃描殘留注入標記。
- [ ] **AC8 像素層待補拍(非單元門檻,且建議 48 格後再拍棋盤像素細節)**
      960×540 與 1920×1080 各一張「選取我方、有被擋敵兵」:人開圖確認可攻擊最醒目、被擋為角標、敵兵本體與編號可見、威脅不蓋棋子。
      依截圖規則先判類別。含世界層像素量測者依 Check 4 新判準(讀 `SubViewport` 原生緩衝區、無可測對象寫 N/A)。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## 未涵蓋(刻意)

- 地形紋理(D1)、敵兵外型(D2)、V5 頭部超出上緣(D4)—— 延後 48 格。
- 圖例內圖示 → T8(story-047),須本單定稿後才畫。
- 色票擴充(高亮色不在色票)→ D5。
- `design/gdd/tactical-combat-system.md` Visual/Audio 節文字同步 → 協調者另行請示。

## Affected Files

- `src/ui/battle/board_view.gd`(高亮建構函式與常數)
- `src/ui/battle/battle_screen.gd`(僅當集合排除邏輯需改;要動先問)
- 上列 4 支既有測試;新測試檔:`tests/integration/ui/board_view_highlight_hierarchy_test.gd`
- 規格檔(art-director 擁有,不在本單範圍):`design/art/highlight-hierarchy-spec-2026-11-12.md`

超出此清單先問。

## 與其他工單的順序

與 story-041(T1)**同檔 `board_view.gd`,須序列:041 先、本單後**(AC5 引用 041 的首字矩形函式)。
本單是 story-047(圖例)的前置。
