# lunch-capture-2026-11-17

**目的**:午休開窗實機截圖,驗 story-046 / 056 / 051 / 054 / 052 / 047 / 053 的像素層。
**狀態**:in-progress。driver.gd 與兩份合成夾具已寫好;headless 流程驗證進行中(見下方「進度」)。開窗截圖尚未執行。

## 開窗指令(辦公室:靜音、標題 x、不在最上層以外的限制由協調者控管)

```
timeout 100 "C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --audio-driver Dummy --title=x --position 0,0 --path . -s res://prototypes/lunch-capture-2026-11-17/driver.gd > prototypes/lunch-capture-2026-11-17/run_output_windowed.txt 2>&1; echo ENGINE EXIT=$?
```

- 預設依序 960x540 -> 1920x1080;只跑單一尺寸:尾端加 `-- 960x540`。
- 內建 WATCHDOG 150 秒;截圖存 `out/NN_<寬>x<高>_<tag>_<狀態>.png`。
- log 的 `STATE_RESULT [..] REACHED|UNREACHABLE`、`HOST [..]`(宿主鏈物證)、`FACTS [..]`(狀態事實)。

## 狀態清單

| tag | 狀態 | 資料 |
|---|---|---|
| s046 | 選單五列 | 真實 vs01 |
| s056 | 戰役戰敗「重打」文案 | 真實 vs01 + 戰役 ledger 注入,擊倒甲後 `_check_outcome_and_finish()` |
| s051 | 敵方型別名(游標停 E1/E3) | 真實 vs01 |
| s054 | 鞋/劍/被結束變暗 | 合成夾具 `fixture_roster_054.txt`(vs01 地形) |
| s052 | 被擋章 | 先試真實 vs01(丙移動後重選);構不成才用 `fixture_roster_052.txt`,兩者分開標示 |
| s047 | 圖例 | 真實 vs01 |
| s053 | 結束角色行動 禁用+變淡 / 啟用+變淡 | 真實 vs01,游標真實停在與提示列框重疊的格 |

## 進度 / 未完成

- 已寫:driver.gd、兩份夾具。
- headless 已跑(`run_output_headless.txt`,EXIT 0,14 次取像 skipped 為預期)。s053 在 960x540 與 1920x1080 皆 UNREACHABLE:真實 vs01 沒有任何棋盤格與提示列框矩形重疊(提示列在棋盤下方),「真高亮壓框」構不成;s052 真實 vs01 UNREACHABLE,已有合成夾具補拍。

## 未驗證事項

- 全部像素層(headless 取不到像素)。
- s056 擊倒甲的方式為直接 `take_damage` + 控制器私有 `_check_outcome_and_finish()`,非真實戰鬥流程。
- s054 以控制器 `click_tile` 驅動移動/攻擊,非滑鼠點擊。
