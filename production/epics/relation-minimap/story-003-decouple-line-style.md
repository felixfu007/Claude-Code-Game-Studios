# Story 003: 線形/色調轉換抽離(解開 BattleScreen ↔ RelationMinimap 雙向相依)

Status: Draft(未排程 —— 2026-11-06 登記時管理者裁決不排程;開工需請示)
Type: Logic(純重構,零行為變更)
Epic: relation-minimap
來源:`docs/tech-debt-register.md` Open 區 2026-11-06 條(追蹤來源提交 `8bcbcea`)
預估工時:**S(約 0.5 天)** —— 搬 2 個靜態函式 + 改 4 處呼叫 + 改 2 條守衛測試 + 加 1 條新守衛
Owner:待開工時依派工評估(`.gd` 檔 → `godot-gdscript-specialist`)

## 為什麼做(白話)

關係圖畫面與戰鬥畫面現在互相「認識」對方:戰鬥畫面建立並持有關係圖,而關係圖為了拿「這條線該畫什麼形狀/顏色/符號」,反過來呼叫戰鬥畫面的靜態函式。
今天沒壞(引擎無循環引用錯誤、全套與 CI 皆綠)。日後若拆分戰鬥畫面,或讓 `-s` 腳本單獨引用關係圖,會被牽連(本專案已知:`-s` 腳本靜態引用會牽出相依類別的編譯失敗)。
**不是現在會痛的事,是將來動戰鬥畫面時會變貴的事。**

## 現況相依(查證,2026-11-11)

**方向一:RelationMinimap → BattleScreen(靜態呼叫,這是要拆掉的那條)**

```
$ grep -n "BattleScreen\." src/ui/battle/relation_minimap.gd
80:			"shape": BattleScreen.line_shape_for(s),
81:			"has_plaque": not BattleScreen.line_style_for(s).is_empty(),
121:		var style: Dictionary = BattleScreen.line_style_for(s)
128:			from, to, BattleScreen.line_shape_for(s),
```
(同檔第 6、12、13、59 行另有提及 `BattleScreen` 的文件註解,不是程式相依,但搬完要同步改。)

**方向二:BattleScreen → RelationMinimap(持有與建立,合理的組合關係,不必拆)**

```
$ grep -n "RelationMinimap" src/ui/battle/battle_screen.gd   # 型別/建構 3 處
1191:var _relation_minimap: RelationMinimap = null
1205:	_relation_minimap = RelationMinimap.new()
1206:	_relation_minimap.name = "RelationMinimap"
```
`BattleScreen` 持有 `RelationMinimap` 是正常的「父持子」;**問題只在子反過來依賴父**。本張只拆方向一,方向二保留。

**被搬的兩個函式(現住 BattleScreen)**

```
$ grep -n "^static func line_style_for\|^static func line_shape_for" src/ui/battle/battle_screen.gd
2792:static func line_style_for(status: AffinityLineStatus) -> Dictionary:
2812:static func line_shape_for(status: AffinityLineStatus) -> BoardView.LineShape:
```
`BattleScreen` 內部自己的呼叫點:`battle_screen.gd:2909`(`affinity_line_dicts()` 內 `line_style_for(status)`)。

## 目標結構

新增純類別(建議 `src/ui/battle/affinity_line_style.gd`,`class_name AffinityLineStyle`,`extends RefCounted`,不繼承 Node、不引用任何場景):

- `static func style_for(status) -> Dictionary` —— 原 `line_style_for` 逐字搬移(NEUTRAL 回空字典的契約不變)
- `static func shape_for(status) -> BoardView.LineShape` —— 原 `line_shape_for` 逐字搬移
- `BattleScreen.affinity_line_dicts()` 與 `RelationMinimap` 皆改呼叫它;**`BattleScreen` 與 `RelationMinimap` 彼此不再引用對方的靜態函式**。

⚠️ **誠實揭露:這個純類別仍依賴 `BoardView` 的三個 enum**(`LineTone` / `LineShape` / `LineSymbol`,`board_view.gd:251/255/258`)—— 它是「view 詞彙」。本張**不**把 enum 再抽出去(那會多動 `BoardView` 與所有引用 enum 的測試,超出債的範圍)。結果:`RelationMinimap` 仍依賴 `BoardView`(而 `BoardView` 刻意不認識 `AffinityLineStatus`,方向不變)。若日後連這條也要斷,另開一張把三個 enum 搬到獨立檔。**函式名是否沿用 `line_style_for` / `line_shape_for` 由實作者提案**;改名會讓下面兩條守衛測試的 `^static func` 錨點跟著改。

放置位置建議留在 `src/ui/battle/`:現有兩條守衛測試以目錄掃描 `static func line_style_for(` 計數 = 1,同目錄可讓「單一來源」守衛不必改掃描範圍(見風險節)。

## Affected Files(開工前請示確認;超出範圍的程式碼檔仍須先問)

| 檔 | 改動 |
|---|---|
| `src/ui/battle/affinity_line_style.gd`(新) | 純類別,承接兩個靜態函式 |
| `src/ui/battle/battle_screen.gd` | 刪除兩個靜態函式;`affinity_line_dicts()`(約第 2909 行)改呼叫新類別;第 432 行文件註解的 `[method line_style_for]` 交叉引用同步改 |
| `src/ui/battle/relation_minimap.gd` | 4 處 `BattleScreen.` 呼叫改為新類別;檔頭註解第 6/12/13/59 行同步 |
| `tests/unit/ui/battle_screen_preview_test.gd` | 第 54/60/67 行三條 `BattleScreen.line_style_for` 改呼叫新類別(或保留 `BattleScreen` 轉發薄殼,見風險) |
| `tests/unit/ui/affinity_line_shape_test.gd` | `test_ac_p7_board_side_has_single_status_to_style_conversion`(第 92 行附近)的錨點視函式是否改名而定 |
| `tests/unit/ui/relation_minimap_line_shape_test.gd` | `test_ac_p7_whole_project_has_single_status_to_style_conversion`(第 53/55 行)同上;另新增 1 條去耦守衛 |

## 驗收條件

- [ ] **AC-1 零行為變更**:既有全套測試全綠,數量不變(重構前先記基準數字;新增守衛 +1)。**交付時依 `CLAUDE.md` 2026-10-12 裁決貼出 `ENGINE EXIT` 與 `Overall Summary` 原始三行**,協調者自行重跑複驗。**[自動]**
- [ ] **AC-2 去耦守衛(新測試)**:`relation_minimap.gd` 的非註解行不得含 `BattleScreen`;`battle_screen.gd` 不得再有 `^static func line_style_for(` / `^static func line_shape_for(`。掃描需排除註解行,避免驗證字串命中註解自己(`coding-standards.md` 2026-10-12 條;沿用兩份現有測試的 `_code_lines()` 寫法)。**[自動]**
- [ ] **AC-3 單一來源不退步**:AC-P7(story-002)的「全專案只有一處 `^static func` 轉換」守衛仍成立且仍有效(沒有因搬家而掃不到)。**[自動]**
- [ ] **AC-4 畫面不變**:關係圖與棋盤線的樣張與重構前一致(形狀/色調/符號)。既有整合測試 `tests/integration/ui/battle/battle_screen_relation_minimap_test.gd` 綠即可,不要求新樣張;人眼開一次關係圖確認(`coding-standards.md` Check 5 的精神)。**[自動 + 手動]**
- [ ] **AC-5 headless 載入**:`RelationMinimap` 單獨 `load()`/`new()` 不再把 `BattleScreen.tscn` 的相依鏈牽進來(以 AC-2 的 grep 為主要證據;是否另做引擎實測,實作者提案)。

## 敏感度證明方式

沿 story-001/002 前例(`coding-standards.md` CI 節:一次注入只證明到第一個被抓到的斷言):

1. **AC-2 守衛**:在 `relation_minimap.gd` 臨時加回一行非註解的 `BattleScreen.line_shape_for(...)` → 去耦守衛轉紅 → 還原。
2. **AC-3**:臨時在 `battle_screen.gd` 加回第二份 `static func line_style_for(` → AC-P7 單一來源守衛轉紅 → 還原。
3. **零行為變更**:臨時把新類別 `shape_for` 的 SOLID/ZIGZAG 對調 → 既有形狀測試轉紅 → 還原。
4. 注入標記驗收前**必須掃乾淨**(`sensitivity_proof_leaves_broken_code` 前例:中斷就停在改壞狀態);每次注入用明確標記字串,交付前 grep 該標記為零。

## 風險與受影響測試(grep 實測)

```
$ grep -rn "line_style_for\|line_shape_for" tests --include=*.gd
tests/unit/ui/affinity_line_shape_test.gd:92:            ... begins_with("static func line_style_for(")
tests/unit/ui/battle_screen_preview_test.gd:54/60/67:  BattleScreen.line_style_for(...)   # 3 條直接呼叫
tests/unit/ui/relation_minimap_line_shape_test.gd:53/55: begins_with("static func line_style_for(") / ("static func line_shape_for(")
```

**直接受影響:3 個測試檔、5 條測試**(3 條直接呼叫 + 2 條原始碼文字守衛)。另有整合測試 `tests/integration/ui/battle/battle_screen_relation_minimap_test.gd` 經 `BattleScreen` 間接走這條路徑,不需改但是回歸主力。

主要風險:

1. **原始碼文字守衛會「安靜地失效」而不是變紅**:兩條 AC-P7 守衛掃的是 `src/ui/battle/` 目錄下以 `static func line_style_for(` 開頭的行,斷言計數 `== 1`。新類別若放在別的目錄、或函式改名,計數會變 0 → 轉紅(好);但若改名後有人只改一邊,另一邊可能掃不到而恆為 0 或恆為 1。**改名與搬目錄擇一做,不要同時;改完兩條守衛都要實際注入一次確認仍會紅。**
2. `battle_screen_preview_test.gd` 三條直接呼叫:兩個選擇 —— (a) 改呼叫新類別(乾淨,建議);(b) 在 `BattleScreen` 留轉發薄殼(會讓 `BattleScreen` 繼續出現在轉換路徑上,與本張目的相反,**不建議**)。
3. 新增 `class_name` 需要重新匯入(`global_script_class_cache`):本機測試走 `tools/build/run_tests_with_import.sh` 已含匯入;**若直接跑引擎而不匯入,會出現 `Identifier "AffinityLineStyle" not declared`**,且可能是 exit 105(收集階段炸掉、`Overall Summary` 與 ` FAILED` 兩個 grep 皆空)—— 驗收一律先看引擎 exit code。
4. 既有程式碼註解/文件仍寫「`BattleScreen.line_style_for` 是全專案單一轉換點」:`design/ux/affinity-line-display.md` 第 53 行(AC-P7)、`production/epics/relation-minimap/story-002-*.md` 第 24、100 行。**這些是文件,動它們需另行請示**;本張只列出,不自行改。

## 開工前須請示

- 本張為債務清償,2026-11-06 管理者裁決「不阻擋任何工作,不排程」;**開工、以及上列 Affected Files 是否照單核准,需請示管理者**。
- 完成後同步:`docs/tech-debt-register.md` 該條移到 Resolved(文件,先問)。
