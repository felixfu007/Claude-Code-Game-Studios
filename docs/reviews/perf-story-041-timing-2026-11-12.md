# story-041 對 real_level_battle 測試時間的影響(2026-11-12)

結論:不是真實退步。041 的 clip 容器確實每次重畫都新建(每個顯示 HP 文字的棋子多 1 個 Control),
但實測 render_pieces 成本與 HEAD 無可分辨差異。50s 判為機器負載雜訊。

## 量法
- 腳本:prototypes/perf-story-041-2026-11-12/bench.gd(改自 piece-label-perf bench,載入真實 BoardView.tscn,
  棋子資料加 show_hp_text=true,否則不會走 _build_hp_text,先前的 bench 量不到這段)。
- 交錯:CURRENT(041)與 HEAD(只 stash src/ui/battle/board_view.gd)各跑 3 輪交錯,每輪 7 組 x 60 次 render x 10 棋子,取 min。
- 已 pop 還原,git diff --stat 與開始時相同(5 files, 77+/37-)。stash@{0} 為先前就存在的別人的項目,未動。

## 數字(60 次 render 的毫秒,min)
| 輪 | CURRENT | HEAD |
|---|---|---|
| 1 | 1258 | 1968 |
| 2 | 1698 | 2002 |
| 3 | 1840 | 1953 |
CURRENT 不慢於 HEAD(甚至偏快);同一程式單次量測自身波動約 +-30%(中位數 2.0~2.5s),大於任何差異。
節點數:10 棋子 StatsLayer 82 -> 92(+1 容器/棋子,+12%),重畫不累積(82/92 皆穩定)。
推估最壞每次 render 多 10 個節點的建立,量測落在雜訊內。

## 為何可信/限制
- 同進程、交錯、取 min,排除排程尖峰;用真實類別與場景。
- 限制:headless 無真實繪製,量的是節點建立與佈局;整場戰鬥測試的 50s 未直接重現(今日同碼曾差 47s vs 25s)。
- 建議:協調者重跑該測試一次(機器閒時);若仍 >30s 再查 042/043 的 hand_bar.gd 改動(本次未量)。
  若要預防性降成本:容器可像棋子標籤池一樣常駐複用,但目前無證據需要。
