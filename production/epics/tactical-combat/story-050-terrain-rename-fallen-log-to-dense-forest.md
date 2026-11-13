# Story 050: 地形名稱「倒木」改為「密林」

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-13 草擬;待管理者看過後轉 Ready 亦可,無待決題)
> **Type**: UI / Data(文字)
> **Estimate**: S(約 0.5 天,純字串 + 2 條測試斷言)
> **依據**: 管理者 2026-11-13 裁決(`production/session-state/active.md` 第一百批節);`docs/reviews/log-line-of-sight-rule-options-2026-11-13.md` 第六節

## 為什麼

地形「倒木」改名「密林」。**規則不動**(cost 3、可走、擋視線),**關卡資料字元 `#` 不動**,只換玩家看到的名稱。圖(地形格圖案)另案,不在本單。

## 命中清單(2026-11-13 當場 grep;命令都對 `src tests assets` 下,不含本工單檔與 docs,故無自我命中)

```
grep -rn "倒木" --include=*.gd --include=*.csv --include=*.txt --include=*.tscn --include=*.tres src tests assets
```
命中 **40 行**(12 個測試檔)(逐行可重跑)。分類:

| 類別 | 命中 | 處置 |
|---|---|---|
| **玩家可見字串** `assets/data/locales/strings.csv:69` `battle.tile_info.terrain_fallen_log,倒木` | 1 | 改為 `密林`。**唯一**面向玩家的字串來源 |
| **斷言舊字面值的測試** `tests/integration/ui/battle_screen_tile_info_test.gd:44`(`is_equal("倒木")`)、`:148`(`"地形：倒木"`) | 2 | 改斷言為 `密林` / `地形：密林` |
| 測試註解/說明(倒木字樣,不影響行為) | 約 27(分布在 12 個測試檔,含上列 tile_info 檔) | 順手改字(同批 sed 可;**不改會留下與資料矛盾的註解**)。註解不計入驗收,但列入 AC4 的殘留掃描 |
| 關卡 roster 檔頭註解 `assets/data/units/vs02~vs05_roster.txt`、`vs03` | 約 8 | 只改註解文字;🔴 **不得動資料列、不得動 terrain 檔**。這些檔屬 level-designer 網域 → 派工時一併授權或另交 |

另:`strings.zh_TW.translation` 為匯入產物(依 .gitignore 不進版控),命中不算;改 CSV 後靠 `run_tests_with_import.sh` 重匯(2026-10-15 裁決的單一入口,**必須用它跑**,否則引擎服務舊快取 = 第六種假綠燈)。

## 程式符號是否改名:**判定不改**

`Board.TERRAIN_FALLEN_LOG`、`TEXT_TILE_INFO_TERRAIN_FALLEN_LOG`、i18n 鍵 `battle.tile_info.terrain_fallen_log`、測試名 `test_..._fallen_log_...` **全部保留**。
理由:(1) 管理者裁決是「規則不動、資料字元不動、只換名稱」,符號是規則層識別碼不是顯示名;(2) 改名牽動 `board.gd`、`battle_screen.gd`、5 個測試檔、`locale_data_integrity_test.gd` 的鍵集合,**零玩家可見收益、純風險**;(3) 鍵名曾以舊名進過資料完整性測試的鍵集,改鍵會連帶要動那份帶列數斷言的檔。
代價:程式碼讀者看到 `FALLEN_LOG` 要知道它顯示為「密林」。緩解:在 `board.gd:18` 常數上方加一行註解(`## 顯示名「密林」(2026-11-13 改名);符號沿用以免牽動規則層`)。**若管理者日後要符號也改,另開重構單。**

## Acceptance Criteria

- [ ] **AC1**:`strings.csv` 該鍵值為 `密林`;游標停在 `#` 格,資訊卡地形行顯示「地形：密林」。測試:`battle_screen_tile_info_test.gd` 兩處斷言改新字面值並綠。
- [ ] **AC2 資料不動**:`assets/data/levels/*.txt` 內容與 `Board` 的 cost/passable/blocks_sight 表 diff 為空。
- [ ] **AC3 敏感度**:把 CSV 還原成「倒木」→ AC1 的測試紅(一個 mutant 一次獨立執行;交付前掃描殘留注入標記)。
- [ ] **AC4 殘留掃描**:上方 grep 在 `src tests assets` 只剩 0 行**玩家可見**命中(註解已改則 0 行全部);回報貼指令與原始輸出。⚠️ 指令不得寫進被掃檔案的註解(自我命中陷阱,`coding-standards.md`)。
- [ ] **AC5**:交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。
- [ ] `strings.csv` 列數不變(改值不增列),`locale_data_integrity_test.gd` 計數斷言無須動。

## 未涵蓋(刻意)

- 地形格圖(倒木圖 → 密林圖)—— art-director / 美術另案。
- 圖例面板(story-047)與目標/圖例入口(story-046)若已寫死「倒木」字樣:本次 grep 於 `src tests assets` **未發現**(圖例文字尚未進 CSV);047/046 落地時直接用「密林」。
- 設計文件(`design/`、`docs/`)內的「倒木」措辭:不在本單,交 narrative / level-designer 另 grep。

## Affected Files

- `assets/data/locales/strings.csv`(第 69 行值)
- `tests/integration/ui/battle_screen_tile_info_test.gd`(兩處斷言 + 註解)
- tests/ 下含「倒木」註解的其餘 11 個檔(只改註解)
- `src/gameplay/board/board.gd`(僅加一行註解)
- `assets/data/units/vs02~vs05_roster.txt`(僅檔頭註解;**需 level-designer 授權**)

超出此清單先問。

## 與其他工單的順序

獨立,可最先做。與 story-051 無檔案衝突(051 只動 `strings.csv` 的別列;**同檔不同列,若並行須序列合併**)。圖例 047 之前做完最好。
