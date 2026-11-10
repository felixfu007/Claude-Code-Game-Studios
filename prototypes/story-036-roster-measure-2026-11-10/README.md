# story-036 名冊量測(2026-11-10)

工單:`production/epics/tactical-combat/story-036-vs03-vs04-roster-adjust.md`
裁定:`docs/reviews/vs03-vs04-difficulty-decision-2026-11-06.md`
狀態:concluded

## 檔案
- `vs03_roster_copy.txt` / `vs04_roster_copy.txt`:改後名冊副本
- `run_vs03_copy.log` / `run_vs04_copy.log`:protocol2_runner(--arms=use,明指三路徑)原始輸出
- `full_suite.log`:全套測試輸出

## 結果
- 第 3 場:勝 6/8(v0,1,2,3,5,7),判準 1(>=7/8)不成立 -> 退回,`assets/` 未動;未跑對照組。
- 第 4 場:8/8 勝、第 1~2 回合無敗局、勝局 neardeath 總和 4、最低剩餘 HP 5 -> 保留,已落地 `vs04_roster.txt`。
