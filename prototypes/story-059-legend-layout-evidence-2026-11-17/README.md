# story-059 圖例版面證據(2026-11-17)

- 假設:圖例圖示錯位成因 = 範例以 `BoardCoords.BOARD_ORIGIN` 偏移畫,面板未扣除。
- 結果:已確認(`cause_probe_before_fix.log`,真實 BattleScreen;1080p 圖示左緣 160 = 96+64、上緣高出列頂 94px)。
  另發現第二個成因:`_add_affinity_sample` 以格內座標畫,沒加格原點,線與銘牌畫在底磚之外(已修)。
- 開窗實拍:`driver.gd`(真實 BattleScreen.tscn),log `run_output_windowed.txt`(含 WorldViewportContainer position/size/stretch_shrink 與 WorldViewport.size),截圖 `production/qa/evidence/story-059/`。
- 截圖類別:四尺寸 content_rect 面積/視窗 = 80%/63%/81%/77%(>= 50%) -> Category A。Check 4:世界層被圖例遮罩覆蓋、圖例本身非世界層 -> 沒有可測對象(N/A),不寫「通過」。
- 狀態:concluded。AC6(管理者人眼確認)未做。
