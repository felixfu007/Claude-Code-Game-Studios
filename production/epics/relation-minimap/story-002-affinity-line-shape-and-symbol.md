# Story 002:好感度連線的形狀與符號(線形表關係、線色表效果、符號牌)

> **Epic**: `production/epics/relation-minimap/EPIC.md`
> **Status**: Ready(2026-11-06 起草,待協調者核可後派工)
> ✅ **2026-11-06 加註:程式完成,待在家實拍樣張與目視。** 棋盤 `d10c54e`、關係圖 `8bcbcea`、樣張驅動 `4a31fe4`(只經 headless 驗證)。樣張交 art-director 代看,最後管理者在家目視。
> **Type**: UI(像素類 AC 為開窗截圖;結構類 AC 為 headless 自動測試)
> **規格權威**: `design/ux/affinity-line-display.md`(2026-11-06 定案)。本工單**不新增任何設計決定**,AC 逐條引用該檔 AC-P1~P9,**不改寫內容**;規格與本工單有出入時以規格為準。
> **指派**: `ui-programmer`(`.gd` 檔路由 `godot-gdscript-specialist`;`.tscn` 若動則 `godot-specialist`)
> **前置**: story-001(關係圖開關與繪製)已完成。本 story **取代** story-001 範圍 3 中「未生效 → 淡虛線、符號 `0`」的畫法,並改動棋盤連線畫法。

## 範圍

1. **棋盤連線**(`board_view.gd` + `battle_screen.gd`):
   - 線形由 `AffinityLineStatus.polarity` 決定:好感 = 實線、惡感 = 鋸齒線(R1)。
   - 線色由 `AffinityLineStatus.state` 決定:正 = 綠、負 = 紅,沿用棋盤現行色值(R2)。
   - 效果為 0(`State.NEUTRAL`)**不畫**,連底襯也不畫(R3)。`MUTED` 筆畫從棋盤消失。
   - 線中點放符號牌:7×7 不透明深色牌 + 5×5 圖元 `+`/`−`,圖元繪製、不用字型(R5)。
   - `affinity_line_dicts` 的輸出字典**新增形狀欄**(欄位名與列舉名由實作者定,見「未決點」第 1 項)。
2. **關係圖**(`relation_minimap.gd`):
   - 十條關係一律畫出,形狀 = 關係(R4);效果非 0 時上 R2 色值並帶 R5 符號牌;效果為 0 時線用 `COLOR_NODE`、不透明度約 0.6、**不放符號**。
   - 刪除 NEUTRAL 虛線路徑與符號 `0`(`draw_dashed_line`、`SYMBOL_NEUTRAL`、`COLOR_NEUTRAL`)。
   - 關係圖色值統一為棋盤現行色值(R2),原 `COLOR_POSITIVE`/`COLOR_NEGATIVE` 廢止。
   - 詳情區:每列 = 對象名 + 關係文字(好感/惡感)+ 目前效果(R7)。**關係文字只准出現在關係圖內。**
3. 🔴 **單一來源(AC-P7)**:「`AffinityLineStatus` → (形狀, 色調, 符號)」的轉換**只能有一處** `^static func`,棋盤與關係圖共用。現況是棋盤在 `BattleScreen.line_tone_for`、關係圖在 `RelationMinimap.symbol_for`,兩處各一份——本 story 要收成一份。收在哪個類別由實作者提案,**超出 Affected Files 要先問**。
4. 色盲模式(R8):形狀與符號牌不隨模式變;模式只換色值。**查證結果:專案內目前沒有色盲模式的程式定義**(`grep -rni "colorblind\|色盲" src` 只命中 `board_view.gd` 一行註解)。故本 story **只把色值集中在常數、預留換色入口,不實作色盲模式本身**,見「未決點」第 6 項。
5. 🔴 **參數集中在常數,樣張後可能調整**:規格第 3 節全部數值(鋸齒振幅 ±2px、半週期 4px、線身 1px、底襯 3px、關係圖鋸齒 振幅 = 2×線寬 / 半週期 = 4×線寬、符號牌 7×7 / 圖元 5×5、關係圖 0 效果不透明度 0.6)**都是美術總監的未驗證初值**,必須各自是具名常數、集中放置,不得散落成魔術數字。樣張(下方 Test Evidence)給人看過之後,數值可能改;「不行時先怎麼調」欄的順序以規格第 3 節為準(**鋸齒糊成實線時先加振幅/半週期,不要先加粗線寬**)。

## Affected Files

**這份清單決定實作者可直接改哪些程式檔;清單外的程式檔要先問。**

程式:

- `src/ui/battle/board_view.gd` —— 線形列舉、鋸齒繪製、符號牌、略過效果 0;`LineTone.MUTED` 與 `AFFINITY_LINE_COLOR_MUTED` 移除或改名(實作者定)
- `src/ui/battle/battle_screen.gd` —— `line_tone_for`、`affinity_line_dicts`(加形狀欄)、`_refresh_view()` 內餵棋盤與關係圖的呼叫處
- `src/ui/battle/relation_minimap.gd` —— 線型、`symbol_for`、色值統一、刪虛線、詳情區關係文字
- `assets/data/locales/strings.csv` —— 關係詞鍵(好感/惡感)與詳情區所需鍵;**只准新增列**,不改既有列

測試(會紅或預期要動,依下方 grep 查出):

- `tests/unit/ui/battle_screen_preview_test.gd` —— 斷言 `line_tone_for` 與 `LineTone.MUTED`(必改)
- `tests/integration/ui/battle/battle_screen_relation_minimap_test.gd` —— 斷言 `symbol_for(NEUTRAL)` 與棋盤線層子節點數 `expected.size() * 2`(必改)
- `tests/integration/ui/battle/battle_screen_hide_affinity_test.gd` —— 以線層子節點數當前提與對照(**可能**紅,見下)
- `tests/unit/core/i18n/locale_data_integrity_test.gd` —— 僅當它釘死 CSV 列數、且本 story 新增了鍵;只改列數(story-001 前例)
- 新檔:`tests/unit/ui/` 與 `tests/integration/ui/battle/` 下依本 story 新增的測試檔(檔名 `[system]_[feature]_test.gd`)

不在清單內、**不得動**:`src/gameplay/affinity/affinity_line_status.gd`(規格預期不動,資料已齊)、`project.godot`、`BoardView.tscn`/`BattleScreen.tscn`(若需新增節點層,先問)。

### 會紅的既有測試:grep 原始輸出

指令:`grep -rn "LineTone\|line_tone_for\|symbol_for\|MUTED" tests src`(2026-11-06 協調者環境,以下僅列 `tests/` 命中行,`src/` 命中行是被改的對象,見該指令全文):

```
tests/integration/ui/battle/battle_screen_relation_minimap_test.gd:224:	var p: String = RelationMinimap.symbol_for(AffinityLineStatus.State.POSITIVE)
tests/integration/ui/battle/battle_screen_relation_minimap_test.gd:225:	var n: String = RelationMinimap.symbol_for(AffinityLineStatus.State.NEGATIVE)
tests/integration/ui/battle/battle_screen_relation_minimap_test.gd:226:	var z: String = RelationMinimap.symbol_for(AffinityLineStatus.State.NEUTRAL)
tests/unit/ui/battle_screen_preview_test.gd:54:	assert_int(BattleScreen.line_tone_for(AffinityLineStatus.State.POSITIVE)).is_equal(
tests/unit/ui/battle_screen_preview_test.gd:55:		BoardView.LineTone.POSITIVE
tests/unit/ui/battle_screen_preview_test.gd:60:	assert_int(BattleScreen.line_tone_for(AffinityLineStatus.State.NEGATIVE)).is_equal(
tests/unit/ui/battle_screen_preview_test.gd:61:		BoardView.LineTone.NEGATIVE
tests/unit/ui/battle_screen_preview_test.gd:66:	assert_int(BattleScreen.line_tone_for(AffinityLineStatus.State.NEUTRAL)).is_equal(
tests/unit/ui/battle_screen_preview_test.gd:67:		BoardView.LineTone.MUTED
tests/unit/ui/battle_screen_preview_test.gd:85:	assert_int(result[0]["tone"]).is_equal(BoardView.LineTone.POSITIVE)
tests/unit/ui/battle_screen_preview_test.gd:103:	assert_int(result[0]["tone"]).is_equal(BoardView.LineTone.NEGATIVE)
```

第二組補查(grep 沒抓到、但同樣依賴舊畫法的測試),指令 `grep -rn "_affinity_line_layer" tests`:

```
tests/integration/ui/battle/battle_screen_hide_affinity_test.gd:61:	return instance._board_view._affinity_line_layer.get_child_count()
tests/integration/ui/battle/battle_screen_relation_minimap_test.gd:180:	var board_children: int = instance._board_view._affinity_line_layer.get_child_count()
```

與其斷言:

```
tests/integration/ui/battle/battle_screen_relation_minimap_test.gd:181:	assert_int(board_children).is_equal(expected.size() * 2)
tests/integration/ui/battle/battle_screen_hide_affinity_test.gd:107:	assert_int(_board_line_node_count(instance)).append_failure_message(
tests/integration/ui/battle/battle_screen_hide_affinity_test.gd:108:		"PRECONDITION/對照組:設定關閉時開局棋盤應畫有好感度連線(否則『隱藏』測不出差異)"
```

判讀(協調者讀碼所得,**未實跑**;實作者以實跑為準):

- `battle_screen_preview_test.gd` 的 `NEUTRAL → MUTED` 案例(行 66~67)必紅;其餘 `line_tone_for` 案例視實作者是否保留該函式簽章而定。
- `battle_screen_relation_minimap_test.gd` 行 181「每條線 = 2 個節點」必紅:效果 0 的線不再畫、惡感線是鋸齒、另有符號牌節點。行 226 `symbol_for(NEUTRAL)` 與另兩者互異:若 NEUTRAL 改為「無符號」(空字串),`p != n and n != z and p != z` 仍可能成立,但意義變了,須有意識改寫。
- `battle_screen_hide_affinity_test.gd` 行 107 的前提「開局棋盤有連線 > 0」:**若開局佈陣的每一對都落在距離 2,新規則下節點數為 0,前提測試會紅**(規格第 6 節已預告「教學關出生佈陣是否落在距離 2 —— 未驗證」)。實作者要實跑確認;若紅,是被測前提變了,不是 bug,**要有意識地改前提(例如先移到有效果的站位),不得刪測試**。同檔行 115、208 同理檢查。
- 規格第 4 節末條:「既有測試斷言 `line_tone_for`、`LineTone.MUTED`、關係圖 NEUTRAL 虛線者會紅 —— 須有意識地改斷言,不得刪測試。」
- 另有一條不會紅但**必須保持綠**的:`test_ac13_minimap_source_never_touches_affinity_layer`(`relation_minimap.gd` 原始碼不得含 `AffinityRules.`、`AffinityPhiProvider`、`AffinityDataPool`、`.links()`)。共用轉換函式若放進關係圖檔,不得違反這條。

## Acceptance Criteria

標記說明:**[自動]** = headless 可測的結構/字典欄位,必須有自動測試;**[開窗]** = 像素類,headless 取不到像素(dummy rendering driver 限制),只能開窗截圖由人確認;**[自動+開窗]** = 結構部分自動測、外觀部分開窗看。

- [ ] **AC-P1 形狀只由關係決定**:同一對角色在距離 1、≥3 時形狀相同;以 `affinity_line_dicts` 輸出斷言形狀欄只取決於 `polarity`。**[自動]**
- [ ] **AC-P2 顏色只由效果決定**:好感 + 太遠(負)= 實線 + 紅;惡感 + 相鄰(負)= 鋸齒 + 紅;兩者形狀不同、顏色相同。**[自動]**(字典欄位 + 線節點的 `default_color`)
- [ ] **AC-P3 棋盤 0 效果不畫**:效果為 0 的對不產生任何線節點,且棋盤上不存在 `MUTED` 筆畫。**[自動]**(節點數與 `MUTED` 常數/筆畫不存在;「不存在」用 `^` 錨定的 grep 或實際節點掃描,**不得讓驗證指令命中自己的註解**,見 `coding-standards.md` 2026-10-12 條)
- [ ] **AC-P4 關係圖十條全畫**:十對全部有線;0 效果對用節點色、無符號牌;不存在虛線路徑。**[自動+開窗]**(`diagnostic_relation_minimap_lines()` 十筆、0 效果者無符號、原始碼無 `draw_dashed_line`;外觀由樣張 E、F 人眼確認)
- [ ] **AC-P5 預覽一致**:游標停在假想目標格時,棋盤連線依假想站位重算,距離變為 2 的線消失、離開距離 2 的線出現,形狀正確。**[自動]**(沿用 `affinity_line_dicts(statuses, hypothetical)` 的測試手法,見 `battle_screen_preview_test.gd` 行 99 前後)
- [ ] **AC-P6 非色彩**:灰階截圖下,僅憑形狀 + 符號牌即可分辨「好感/惡感 × 加成/懲罰」四種組合。**[開窗]**(樣張 A 灰階版 + 樣張 D)
- [ ] **AC-P7 同一來源**:「`AffinityLineStatus` → (形狀, 色調, 符號)」轉換只有一處,棋盤與關係圖共用(以 `^static func` 錨定 grep 驗證)。**[自動]**(grep 腳本錨 `^static func`,檔頭註解不得含該 grep 字串而自我命中)
- [ ] **AC-P8 棋盤無字**:棋盤連線不出現「好感」「惡感」等文字。**[自動]**(棋盤連線層節點不含 `Label`;關係詞鍵只被 `relation_minimap.gd` 引用)
- [ ] **AC-P9 無強度**:棋盤與關係圖皆無強度數字,線寬恆定。**[自動+開窗]**(線寬為常數且各線相同;外觀由樣張確認)
- [ ] 規格第 4 節末條:既有測試中斷言舊畫法者,**有意識地改斷言,不得刪**;PR 說明列出每個被改的測試與改前/改後語意。
- [ ] 敏感度證明門檻(沿 story-001 前例):至少對 AC-P1、AC-P3、AC-P7 各做一次「故意改壞 → 測試轉紅」,注入標記驗收前須清乾淨;一次注入只能證明到第一個被抓到的斷言,見 `coding-standards.md` CI 節。注意 `set_script()` 會清掉先前賦值的屬性,順序見 `coding-standards.md` 2026-10-16 條。
- [ ] 預設行為:`hide_affinity` 設定開啟時,棋盤與關係圖仍不顯示連線/關係(既有行為不變)。
- [ ] 🔴 **交付硬性義務**(`CLAUDE.md` 2026-10-12 裁決):依本工單直接改既有程式檔者,交付前必須用 `GODOT_BIN=<引擎路徑> ./tools/build/run_tests_with_import.sh` 跑全套,並在回報貼出引擎自己的 `ENGINE EXIT` 與 `Overall Summary` 原始三行(不是只說「通過」)。先查 exit code 再 grep(exit 105 兩個 grep 都回空)。協調者會自行重跑。

## Test Evidence

**自動測試**:`tests/unit/ui/`(靜態函式、字典欄位)與 `tests/integration/ui/battle/`(載入真實 `BattleScreen.tscn`)。

**截圖樣張(規格第 5 節 A~F)**,證據檔放 `production/qa/evidence/`,檔名建議 `affinity-line-shape-[樣張字母]-[描述].png`,另附一份 `production/qa/evidence/affinity-line-shape-evidence.md` 記錄每張的對應 AC、解析度、擷取方式、原始 log。

| 樣張 | 內容 | 對應 AC |
|---|---|---|
| A | 實線 vs 鋸齒:水平、垂直、45°、約 26.6°,附灰階版 | AC-P1、AC-P6 |
| B | 紅綠色值的色盲模擬 | AC-P2、R8 |
| C | 穿過棋子、移動區、攻擊區的疊圖 | AC-P2、AC-P3 |
| D | 符號牌(含被棋子遮住、兩線中點重疊) | AC-P6 |
| E | 關係圖,N=2/4/8 三種倍率 | AC-P4、AC-P9 |
| F | 關係圖鋸齒 vs 舊虛線並列(確認舊虛線已不存在) | AC-P4 |

規則:

- 🔴 **必須 `load()` 真實 `src/ui/battle/BattleScreen.tscn`**,`instantiate()` 後以 `get_tree().root.call_deferred("add_child", instance)` 掛入並等 2 個 `process_frame`;**不得自組替身節點鏈**(`.claude/docs/technical-preferences.md`「第 5 點」)。資料注入只有一個時機窗:`instantiate()` 之後、`add_child()` 之前(順序:`instantiate()` → 設 override → `call_deferred("add_child")` → 等幀)。現有注入點:`grep -n "_path_override" src/ui/battle/battle_screen.gd`。需要合成佈陣(例如逼出水平/垂直/45° 線)就**寫合成資料檔餵進去**,先驗 terrain 與 roster 兩份夾具彼此對得上。
- 物證是**原始 log 裡留著真實宿主鏈自己算出來的量測值**:`WorldViewportContainer` 的 `position`/`size`/`stretch_shrink` 與 `WorldViewport.size`。沒有 log 的標記降為 (C)。
- 像素量測與截圖**只能開窗**。證據文件要分類(`coding-standards.md` 截圖分類):樣張 A~D 為整窗畫面,Category A;若只裁線段局部則 Category C,須用真實版面函式算裁切矩形。Check 4(整數縮放格線)依 2026-09-23 新判準,讀 `WorldViewport.get_texture().get_image()` 且被測物位置對齊倍率;**目前世界層無 `.scale != (1,1)` 的節點時要寫「沒有可測對象(N/A)」,不得寫「通過」**。鋸齒本身是否糊成實線,看樣張 A,不靠 Check 4。
- 🔴 **樣張由 `art-director` 代看並決定**(`art_review_delegated_to_art_director`);它無法決定的才做成選項交管理者。每張要附 Check 5 人眼確認紀錄。
- **本工單為 UI 類,證據 gate 為 ADVISORY**;但「樣張未經人看過就宣稱參數定案」不允許——規格第 3 節明寫參數須依樣張才算定。
- 📌 擷圖工具若需要:`tools/build/capture_window.ps1`(讀其檔頭四個陷阱)。**注意:管理者上班時螢幕不得出現遊戲畫面**(`private_dev_at_work`),開窗擷圖由協調者視情況安排,**實作者不得自行長時間開窗**。

## 未決點(實作者遇到就停下回報,不得自行裁決設計)

以下是協調者讀規格與程式現況查到、規格沒講清楚、實作者會卡住的地方。**一律停下回報,不要自行選一種做。**

1. **形狀欄的名稱、列舉、對外型別未定。** 規格 AC-P1 只說「`affinity_line_dicts` 輸出的形狀欄」。現有字典鍵是 `from`/`to`/`tone`,`tone` 是 `BoardView.LineTone`(`POSITIVE, NEGATIVE, MUTED`),且 `BoardView` 刻意不認識 `AffinityLineStatus`。規格沒說:形狀欄叫什麼、用新列舉還是布林、`tone` 是否保留 `MUTED` 成員(R3 說棋盤上不再出現,但列舉成員要不要刪沒講)、符號(`+`/`−`/無)是否也進字典。
2. **符號牌與 HP 文字、游標、高亮的層次。** 現況層序(`BoardView.tscn`):`PiecesLayer` < `MoveUnreachableLayer` < **`AffinityLineLayer`** < `ThreatHighlightLayer` < `AttackHighlightLayer` < `AttackLosBlockedLayer` < `CardTargetHighlightLayer` < **`StatsLayer`**(HP 條與 HP 文字)< `ActionFlagLayer` < `CursorSprite`。符號牌若放在 `AffinityLineLayer`(線中點的自然位置),會被攻擊/威脅高亮、HP 文字、行動旗標、游標**蓋住**;若為了不被蓋而另開一層或拉高層序,會與 `render_pieces` 的「每子單位一個子節點」之類既有約束、以及 `_clear_children` 的清除範圍互動。規格第 5 節樣張 D 只要求「含被棋子遮住」,**沒說被遮住是可接受還是要避免**。哪一種?要不要新增圖層節點(動 `BoardView.tscn`,超出 Affected Files)?
3. **兩條線中點重疊時的符號牌。** 樣張 D 列了「兩線中點重疊」,但規則沒說:兩塊牌疊在同一點時畫兩塊(後畫蓋前畫)、只畫一塊、還是錯開?五人兩兩十對,幾何上棋盤上共線或中點重合是會發生的。**重疊時符號可能互相遮蔽(一正一負疊成誰?),這會直接破壞 AC-P6 的「靠符號牌分辨」。**
4. **符號牌位置取整。** 規格說 7×7 牌、5×5 圖元,世界層 480×270 像素對齊。兩端格中心的中點若落在半像素(例如兩格中心座標和為奇數),牌的左上角怎麼取整?規格只對鋸齒頂點寫了「取整」,沒對牌寫。
5. **鋸齒線與底襯、線端、短線的邊界。** 規格:段數取最接近 `L/4` 的奇數。相鄰兩格(`L` = 32px)與斜向長線的差別、`L < 4` 或最近奇數為 1 時(線太短)怎麼畫,規格沒寫;45° 線頂點取整後是否仍在格內也沒寫。另「底襯 3px 跟著鋸齒折線走」——`Line2D` 對折線轉折處的接頭/端帽(joint/cap)模式沒指定,預設值可能讓鋸齒頂點被磨圓。
6. **色盲模式:專案目前沒有定義。** R8 說「若專案已有色盲模式定義則以既有者為準」,查證結果是沒有(只有 `board_view.gd` 一行談「色盲玩家可分辨」的註解,不是模式)。`.claude/rules/ui-code.md` 寫「colorblind modes are mandatory」。本 story 只留色值集中常數與換色入口;**要不要順手做一個最小色盲模式、替代色用什麼(美術回答第 6 題初值)、設定放哪,不在本 story**,遇到要實作的壓力就停下回報。
7. **關係圖「十條」與現有資料的對應。** 規格 AC-P4 寫「十對全部有線」。現況 `RelationMinimap.set_lines` 收的是 `AffinityRules.board_lines` 的結果,而規格 R4 要求效果 0 的也畫;`board_lines` 是否**永遠**回傳全部十對(含 `NEUTRAL`、含雙向重複),以及陣亡角色的線(現況「statuses never contain them」)怎麼處理,規格沒逐項講。實作者先實測 `board_lines` 的輸出筆數,若不是 10 就停下回報,**不要改 `AffinityRules` 湊數**(不在 Affected Files)。
8. **關係圖 0 效果線與節點的視覺區隔。** R4:0 效果線用 `COLOR_NODE`、不透明度約 0.6。`COLOR_NODE` 同時是節點圓點與標題文字的顏色;線畫在節點下方,線端靠近節點時是否看起來像節點的延伸,規格沒說。這是樣張 E 要由人看的事,**看了覺得有問題就回報,不要先調**。
9. **詳情區的版面與在地化鍵。** R7 只說「每列 = 對象名 + 關係文字 + 目前效果」。效果的文字(加成/懲罰/無)用現有鍵還是新鍵、詳情區是否在 `HudLayout.relation_minimap_rect()` 現有矩形內放得下(現況面板只畫標題與圖,沒有詳情區)、「選哪個角色的詳情」的互動(story-001 已決定關係圖維持純顯示、不做地圖游標,見 EPIC 裁決表第 5 項)——**一個純顯示的面板上,詳情區要列誰的?** 規格沒講。這點可能需要設計決定,停下回報。
10. **關係詞「好感/惡感」的詞彙守則。** 規格第 1 節要求「中立」只能形容效果、不得形容關係;新增在地化鍵與註解時照此命名(如 `relation.kind.positive`),不要沿用 `NEUTRAL` 字樣指關係。

## Out of Scope

- 色盲模式本身的實作(未決點 6)。
- 教學關 S4 的提示措辭(交 narrative/game-designer,未派)、教學關出生佈陣是否落在距離 2 的設計判斷(只在 hide_affinity 測試前提紅時,才要求實作者回報事實)。
- `design/gdd/vertical-slice-level-01.md` 驗收第 3 條(玩家自發歸因)的通過標準重訂(第 4 階段陌生人試玩一起做)。
- 強度數字/線寬隨強度變化(R6;若卡牌系統日後讓 `amp` 變化,是新裁決)。
- 關係圖地圖游標、`RELATION_MINIMAP_NODE` 表面登記(EPIC 裁決表第 5 項:維持純顯示)。
- 改 `AffinityRules`、`AffinityLineStatus`、`AffinityPhiProvider` 與任何好感度規則/資料。
- 改 `design/ux/*`、`EPIC.md`、`systems-index.md` 等文件(由協調者另行處理)。
