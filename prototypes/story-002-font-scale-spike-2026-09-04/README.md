# Spike:Story 002 字級規則候選方案 —— 三個候選公式在 8 個解析度下的實測數字

> PROTOTYPE - NOT FOR PRODUCTION / 拋棄式驗證探針
> **日期**:2026-09-04
> **執行**:`godot-specialist`,本機 Godot 4.7.1 headless
> **log**:`logs/font_scale_probe_output.txt`(逐字輸出,未編修)

## 假設 / 要回答的問題

`design/art/screen-architecture.md` 2026-09-01 裁決把介面設計基準畫布改為螢幕實際解析度後,
遺留一個待訂規則:「HUD 字級要隨螢幕怎麼調整」。本探針**不裁決規則**,只回答:

1. 三個候選公式(見下)在 5 個規格明文列舉的解析度 + 3 個規格明文標為「已知未定義」的邊界解析度,
   各自算出多少 N(Cubic 11 的整數放大倍率)?
2. 用引擎的 `Font.get_string_size()` 實測,現行畫面三句真實文字(取自
   `src/ui/battle/battle_screen.gd` 常數)在各組合下渲染出多寬多高?
3. 最長的那句提示文字(`TEXT_CONTROLS_HINT`)在每個解析度的 title-safe 安全區
   (每邊內縮 5%)裡放不放得下?

## 如何執行

```bash
cd prototypes/story-002-font-scale-spike-2026-09-04
"<Godot 4.7.1 執行檔路徑>" --headless --path . --import   # 首次或字型變動後必跑一次
"<Godot 4.7.1 執行檔路徑>" --headless --path . -s font_scale_probe.gd > logs/font_scale_probe_output.txt 2>&1
```

字型檔為主專案 `assets/fonts/Cubic_11.ttf` 的**複本**(自帶,不引用主專案路徑)——
理由:本探針不得修改主專案任何檔案,而 headless 執行需要 `res://` 底下真的有字型檔可載入。

## 狀態

**Concluded.** 三個候選公式的數字已完整量出,交回協調者供管理者裁決;本探針不選定規則。

## 候選公式(本次交付的核心產出)

- **A_board_locked**:`N = max(2, min(floor(W/480), floor(H/270)))` —— 與
  `world_layout.gd` 世界層倍率**同一條公式**(取塞得下的最大整數倍)。
- **B_height_capped**:`N = clamp(floor(H/300) + 1, 2, 6)` —— 只看高度,成長趨緩且封頂於 6。
- **C_percent_round**:`N = clamp(round(H×0.03 / 11), 2, 7)` —— 目標佔螢幕高度 3%,就近取整(非無條件捨去)。

三者皆保證 `字級 px = 11 × N`,故**在任何解析度下都自動滿足「整數倍」**,不只是 4 個規格列舉的解析度。

## 已知未涵蓋

- **`LoadErrorLabel` 未量測**——該節點 `autowrap_mode = 3`(WORD_SMART),字級是否合適取決於
  換行後的總高度是否放得進畫面,而不是單行寬度;這是排版問題,不是本次「字級規則」問題的同一個量。
  刻意排除,已在回報中列為邊界。
- **`ResultLabel`("勝利"/"戰敗",2 字)量了但不構成安全區風險**,任何候選在任何解析度下都輕鬆放得下,
  數字在 log 裡但不影響候選方案的取捨。
- **只驗證了寬度(水平安全區),未驗證垂直位置**——`ControlsHintLabel` 目前設計是貼齊螢幕底部的橫條,
  它的垂直安全區(是否被 5% 底部內縮線切到)取決於它在新版面裡的實際 y 座標,那是「套用到 6 個元件」
  的範圍(不在本張),本探針只回答字級大小本身撐不撐得住。
- **完全未涉及對話正文字型**——按管理者裁決,本張不選字型,規則寫成與字型無關的形式(整數 N 的算法),
  但本探針量測用的字串全部是 Cubic 11 HUD 文字,未含向量字型的度量。
