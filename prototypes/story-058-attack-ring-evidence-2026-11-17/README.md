# story-058 證據(進行中,2026-11-17)

狀態:in-progress

## 步驟 1 探針結果(已完成;driver.gd,log=run_output_probe.txt,開窗)
宿主鏈:960x540 時 WorldViewportContainer position=(0,0) size=(960,540) stretch_shrink=2、WorldViewport.size=(480,270);
1920x1080 時 size=(1920,1080) stretch_shrink=4、WorldViewport.size=(480,270)。敵格(4,0) 原生座標原點 (160,39)。

只選取我方丙、游標不在該敵(select_only):格內 y=0..4 取樣 12 點,全為 #2d0f37(= 格外 y=-2,-1 同色,即底下的背景/地形色),
無琥珀、無棋子色 -> 上緣「根本沒畫」。右 (31,16) 與下 (16,31) 為 #ffbf4d(琥珀),左 (0,16) 為 #2d0f37(首字框缺口)。
游標停該敵(cursor_on_enemy):y=0 整列 #ffffff(游標白框),y=1..4 為 #312933(HP 文字條底)+文字,環上緣被文字條蓋住。
結論:與工單兩條推論「相符」(環在棋子上層已是現況;上緣是幾何上沒有上邊,不是被蓋)。

## 實作(已完成)
- `src/ui/battle/board_view.gd`:`attack_ring_rects_in_cell()` 改為四個矩形:上邊 Rect2(0,0,32,w)、底邊、右邊(自 y=w 起至 32-w,與上/底邊角落相接)、左邊(仍自首字框下緣起)。威脅環不動。
- 偏離工單字面處(需回報):右邊起點由 HP 文字條下緣改為上邊下緣(否則上邊與右邊在角落有 6px 缺口,違反 AC1「角落相接」);左邊維持首字框缺口(工單明文),故 y 2..22 的左側仍有缺口。
- 測試:新檔 `tests/integration/ui/board_view_attack_ring_closed_test.gd`(6 條);`board_view_highlight_hierarchy_test.gd` 的禁區測試改為 AttackHighlightLayer 豁免「HP 文字條」一個禁區(其餘三禁區與另兩層不放寬)。

## 未完成
- AC2 開窗像素驗收(用修好的 driver 重跑 select_only/cursor_on_enemy 兩解析度)
- AC4 與游標白框間隙數字(已知:游標框 y=0 一列白 1px;環上邊 y=0..1 -> 重疊 y=0,零間隙;既有底/左/右邊同樣與游標框疊 1px)
- AC6 六個 mutant 逐一
- 全套最終一次

## 更新(完成)
AC2 開窗像素:run_output_windowed.txt;select_only 兩解析度格內 y=0,1 全為 #ffbf4d。AC6:mutant 1~5 各自獨立執行皆紅,#6 單元層紅(未開窗)。全套 ENGINE EXIT=0,2175 條、0 failures。
狀態:concluded
