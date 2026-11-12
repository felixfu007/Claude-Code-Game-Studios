# 棋子標字字形探針 (2026-11-12)

狀態:concluded。假說:Cubic 11 含姓名首字/敵兵我方/數字字形,且單一首字放得進 32x40 棋子。

## 執行
`GODOT --headless --path . -s res://prototypes/piece-label-glyph-probe-2026-11-12/probe.gd > run_output.txt`
(ENGINE EXIT=0;log:`run_output.txt`)

## 協調者事實查核
- 字型:`assets/fonts/Cubic_11.ttf`(正確,font name 回報 "Cubic 11")。
- 棋子 32x40:正確(5 張 `assets/art/characters/pieces/char_{jia,yi,bing,ding,wu}_piece_idle_01.png` 皆 32x40;敵人仍用 placeholder `piece_enemy_01.png`,未量)。
- `Font.has_char()` 在 docs/engine-reference 內零命中,故以引擎實際執行為準(呼叫成功、回傳 bool)。

## 結果 (A 級:執行檔 probe.gd,log run_output.txt;讀字型為引擎實跑,未重新實作規則)
- 要求的 19 字 + 0~9 共 29 字,has_char 全部 true,缺字 0。
- 字寬高:CJK 字 11px 為 12x14、22px 為 24x27;數字 11px 為 6x14(22px 為 11~13 x27)。字型 ascent 10 / descent 4 / height 14 @11px。
- 棋子 32x40,格子 32x32(BoardCoords.CELL_SIZE),棋子底對齊格底,頭部向上伸出格 8px(sprite y 範圍=格頂-8 ~ 格底)。

## 幾何(僅數字)
- 單一 CJK 首字 12x14 @原生 11px,小於 32 寬、40 高;放得下(寬餘 20、高餘 26),不需縮放。
- 已佔用:HP 條 20x3(格底上 3px);HP 文字條高 10px 貼格底(僅 show_hp_text 時);行動旗標小方塊在 sprite 右上角(格頂上方 8px 伸出區);
  無遮蔽的 sprite 區域垂直約為 sprite 頂 ~ 格底-10(或 -6 HP 條上緣)。12x14 的字可放進中段,但位置是否與角色圖案重疊需美術判斷(未量像素內容)。
- 注意:世界層 480x270 原生,Cubic 11 原生 11px 在世界層無需放大;Label 若放進世界層須用 11 的整數倍(22 → 24x27 會占 sprite 大半,不建議,僅回報數字)。
