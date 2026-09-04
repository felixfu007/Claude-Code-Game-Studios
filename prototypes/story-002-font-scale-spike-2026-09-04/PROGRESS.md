# PROGRESS — Story 002 字級規則候選方案量測

派工範圍:只出候選方案 + 數字,不改 `BattleScreen.tscn`,不選定規則。

- [x] 讀規格文件(story-002、fonts README、art-direction §5/§6、screen-architecture、story-001 結案)
- [x] 查參考庫確認 `Font.get_string_size()` 簽章未受 4.7 影響變動(breaking-changes.md / deprecated-apis.md 均無命中)
- [x] 建立拋棄式量測專案 `prototypes/story-002-font-scale-spike-2026-09-04/`(自帶字型複本,不動主專案)
- [x] 從 `battle_screen.gd` 取得真實現行文字常數(非杜撰句子)
- [x] 設計 3 個候選規則(公式形式,能回答未列舉解析度):A 鎖定世界層倍率 / B 高度分段封頂 / C 固定比例就近取整
- [x] 寫 headless 量測腳本 `font_scale_probe.gd`:對每個候選規則 × 8 個解析度,算出 N、字級px、真實字串渲染尺寸、佔螢幕高度百分比、安全區是否放得下
- [x] 執行腳本(`--headless -s font_scale_probe.gd`,exit 0),存 log 至 `logs/font_scale_probe_output.txt`(156 行,三個區塊皆完整:N 值表 / 真實字串渲染尺寸表 / 安全區寬度是否放得下表)
- [x] 整理候選方案並排表 + 逐候選「最糟解析度」分析(協調者 2026-09-04 中途明確要求)
- [x] 回報

## 已完成,無殘留項。
