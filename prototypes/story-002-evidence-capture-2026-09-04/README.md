# Spike:Story 002 AC-S002-d 擷圖證據驅動器

> PROTOTYPE - NOT FOR PRODUCTION / 拋棄式驗證探針
> **日期**:2026-09-04
> **執行**:`godot-specialist`,本機 Godot 4.7.1,真實 GPU(非 headless)

## 假設 / 要回答的問題

`story-002-adaptive-font-scale.md` 的 AC-S002-d 要求「在 1920×1080 與 2560×1440
兩種視窗下實機檢視」`BattleScreen.tscn` 的 6 個 UILayer 元件,確認每一個都出現在
它原意圖的位置,而不是縮在視窗左上角。本探針**不做人眼判定**,只負責:

1. 載入真正的正式場景(`res://src/ui/battle/BattleScreen.tscn` 本體,非複本)
2. 依序把視窗設成兩種目標尺寸、等待版面穩定
3. 擷取畫面、跑 `.claude/docs/coding-standards.md` 的機械檢查、存檔成 PNG
4. 存檔後由本 agent 與協調者分別用 Read 工具打開圖檔,人眼確認元件位置

## 如何執行

```bash
"<Godot 4.7.1 執行檔路徑>" --path . prototypes/story-002-evidence-capture-2026-09-04/EvidenceDriver.tscn
```

非 headless(需要真實視窗/GPU)。輸出兩張 PNG 至
`production/qa/evidence/adaptive-font-scale-1080p-2026-09-04.png` 與
`adaptive-font-scale-2k-2026-09-04.png`,逐字輸出見 `run_output.txt`。

## 狀態

**Concluded.** 兩張擷圖與機械檢查數字已產出,人眼確認結果見
`production/qa/evidence/adaptive-font-scale-evidence.md`。

## 已知未涵蓋

- 只驗證 AC-S002-d 點名的兩種視窗,不含 4K / ultrawide / 最小視窗 960×540。
- 不驗證真人拖曳視窗邊框改變尺寸的路徑(沿用既有 spike 的一貫揭露)。
