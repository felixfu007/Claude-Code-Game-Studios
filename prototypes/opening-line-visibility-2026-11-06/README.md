# 每關開場好感度連線可見性量測(2026-11-06)

狀態:concluded

## 問題
新規則(`design/ux/affinity-line-display.md`:效果 0 / 距離 2 時棋盤不畫線)下,每一關開場棋盤上有幾對關係、距離、效果、是否畫線、形狀。

## 執行
```
timeout 100 <Godot console exe> --headless --path . -s res://prototypes/opening-line-visibility-2026-11-06/driver.gd > run_output_headless.txt 2>&1
```
EXIT=0,跑完 `tasklist | grep -i godot` 無殘留。只 headless,未開窗。

## 方法(A 級物證:真實場景檔)
- 對序列檔(`tutorial_sequence.txt` 4 關、`campaign_sequence.txt` vs01~vs05)每一列:`load("res://src/ui/battle/BattleScreen.tscn")` → `instantiate()` → 設 terrain / roster / affinity(及 cards / card_text)`_path_override` → `root.call_deferred("add_child")` → 等 2 個 process_frame。無替身節點。
- 路徑解析切欄只是讀序列檔的路徑欄,不涉規則。
- 距離 / 效果 / 狀態讀自 BattleScreen 實際算出並餵給關係圖的 `AffinityLineStatus`;「是否畫線」呼叫真實 `BattleScreen.line_style_for()`(空字典 = 不畫),並與棋盤 `_affinity_line_layer` 實際 `Line2D` 子節點數交叉核對(每條線 2 條筆畫:襯底 + 色線)。形狀呼叫真實 `line_shape_for()`,並與 `diagnostic_relation_minimap_lines()` 的 shape 交叉核對,兩者一致。
- 讀取的私有成員:`_relation_minimap._statuses`、`_board_view._affinity_line_layer`、`_hide_affinity_display_for_this_battle`(皆為唯讀存取)。
- 腳本不用全域類別名(皆 `load()`):`-s` 腳本編譯時 Autoload 尚未註冊,靜態引用 BattleScreen 會出現 `Identifier not found: CursorStateHost`。第一次執行即因此失敗(log 已被覆蓋)。

## 結果(每關一行,開場第一幀)
| 關 | 對數 | 不畫線 | 棋盤實際線數 | 明細 |
|---|---|---|---|---|
| 教學 1 | 0 | 0 | 0 | 無連線檔 |
| 教學 2 | 0 | 0 | 0 | 無連線檔 |
| 教學 3 | 0 | 0 | 0 | 無連線檔 |
| 教學 4 | 1 | 0 | 1 | 1-2 距1 +3 實線 |
| vs01 | 2 | 1 | 1 | 1-2 距1 +3 實線畫;3-4 距2 效果0 鋸齒(負向關係)不畫 |
| vs02 | 2 | 0 | 2 | 1-2 距1 +3 實線;3-4 距1 -1 鋸齒 |
| vs03 | 2 | 0 | 2 | 同 vs02 |
| vs04 | 2 | 0 | 2 | 同 vs02 |
| vs05 | 2 | 0 | 2 | 同 vs02 |
| 總計 | 11 | 1 | 10 | |

結論:開場不畫線的只有 vs01 的 3-4 一對(距離 2、效果 0)。教學 1~3 無任何連線,故開場棋盤上沒有線(非「被隱藏」,是零關係)。教學 4 與 vs02~vs05 開場全部關係都畫線。`hide_affinity_flag` 每關皆 false,未影響結果。

## 限制
- 只量開場第一幀,不含敵我回合後、移動後的變化。
- 只在 headless 執行,不含像素 / 外觀,僅結構與狀態。
- 距離為 BattleScreen 傳給關係圖的 `AffinityLineStatus.distance`,未獨立重算。
- 讀到私有成員(見上),屬 QA 診斷性讀取。

## 物證
`run_output_headless.txt`:每關 `LEVEL ... injected terrain= roster= affinity=` 行、`PAIR` 行、`LEVEL_SUMMARY` 行與 `TOTAL`。
