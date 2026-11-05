# protocol2-computer-measure-v4(協議 2 量測工具,回歸檢查用)

自 v3 複製;唯一差異是移除對已刪除的三參數呼叫的多餘引數(行為等價),見 story-035
(`production/epics/tactical-combat/story-035-wu-dead-code-step2.md`)。原型,不進 `src/`。
v3 資料夾原封不動,當歷史紀錄。

## 與 v3 的差異(逐項)
| 檔案 | 改動 |
|---|---|
| `p2_decision.gd` | 刪步驟 2 的區域旗標變數(宣告與賦值各一行);步驟 3 改呼叫兩參數版 `s.lone_guard_if_at(id, t)` |
| `protocol2_runner.gd` | `preload` 路徑 v3 -> v4;HEADER 的 `tool=` 字串改 `protocol2-computer-measure-v4` |
| `guard_check.gd` | 無改動(不含舊參數,無路徑指向 v3) |

使用方式、參數、輸出格式與 v3 相同。
等價證明的三次輸出(`run_v3_before.txt` / `run_v4_before.txt` / `run_v4_after.txt`)與過濾法見 `equivalence_filter.txt`。
