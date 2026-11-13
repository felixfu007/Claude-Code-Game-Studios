# 午休截圖審查:讀碼查事實(2026-11-13)

> lead-programmer 只查不改程式。證據等級:程式行 = 讀碼;「PROBE」= 我在 scratchpad 寫的拋棄式腳本,呼叫專案真實類別(`Board`/`CombatRules`),不在 repo 內。每項:事實 / 判定 / 建議歸屬。

## 1. 被擋集合的範圍(00 號圖,丙在 (4,3))

**事實**
- 集合來源:`battle_screen.gd:4935-4937` 呼叫 `_controller.attack_targets_blocked_by_los()` -> `battle_controller.gd:399` -> `_attack_targets_blocked_by_los_for()`(`battle_controller.gd:1384-1400`)。
- 演算法:走訪**整張棋盤每一格**,`current_pos` 為**單位目前所在格**(`:1391`,單一原點),只排除自身格,逐格問 `_state.is_attack_range_blocked_by_los(unit, current_pos, cell)`。**不是**移動後可達格的聯集(那是 `_threat_targets_for`,`:1436` 起,多原點;被擋集合的檔頭註解 `:1379-1380` 明寫「origin 永遠是目前格」)。
- 判定式 `CombatRules.is_attack_blocked_by_los`(`combat_rules.gd:157-168`):在射程內(`is_in_range`,min..max 曼哈頓)、距離 >= 2、且 `LineOfSight.is_clear` 為假。**不看格上有沒有單位**(純幾何圖層,`:1377-1378`)。
- 丙射程:`vs01_roster.txt` 與 `fixture_roster_044.txt` 皆為 `min_range=2, max_range=6`。
- PROBE(真實 `Board.from_ascii` + 真實 vs01 地形 + 真實 `CombatRules`,丙 (4,3),`ENGINE EXIT=0`):
  `PROBE in_range_cells=51 blocked=21 maxdist=6`,格為 (6,0)(7,0)(5,1)(6,1)(7,1)(8,1)(6,2)(7,2)(8,2)(9,2)(6,3)(7,3)(8,3)(9,3)(10,3)(6,4)(7,4)(8,4)(9,4)(7,5)(8,5)。
  **實際是 21 格,不是三十多格**(射程 51 格中 21 格被兩叢 `#` 倒木/密林擋住,最遠距離 6 = 射程上限,x 最大 10)。若截圖上看起來更多,是把「被擋章」與旁邊威脅/不可達標記混算,需人再核對 00 號圖,我沒逐格數圖。

**判定**:**語意如此,不是算錯**(單原點、純幾何、含空格)。可議處是**規格缺口**:story-003 的圖層是「純幾何」,於是空格也各蓋一個章,射程大的單位(丙 6)一次出現 21 個,視覺密度高。這是設計取捨,不是 bug。
**歸屬**:無需改碼。若 art/ux 認為太吵,另開一張 044 後續(例:只標有敵兵的格,或只標與選取單位同線的遮擋邊緣),需管理者/ux 裁決,不可由實作者自選。

## 2. 手牌列壓敵兵 5

**事實**
- 043 的測試 `tests/integration/ui/hand_bar_enemy_occlusion_test.gd` 載入**真實 `BattleScreen.tscn`**(即 vs01 真實名冊)取全部敵兵起始格,用 `HudLayout.cell_overlaps_frame(cell_window_rect(c, ws), rect)` 驗 7 種尺寸(960x540 ... 3840x2160)。
- 敵兵 5 在 vs01 真實名冊為 (11,5);合成名冊 `fixture_roster_044.txt` **沒動 E5**,同為 (11,5)。E4 (7,5)、E2 (11,1) 亦同。所以**站位與 043 驗證用的完全一樣,不是 043 範圍外站位**。
- 但 043 驗的是**格矩形**(32x32),而棋子視覺矩形為 40 高、向上突出 8px(`board_view.gd:320` `PIECE_SPRITE_HEIGHT = 40`)。看 00 號(1920x1080)與 13 號(960x540)圖:手牌列底緣貼到 (11,5) 格頂,敵兵 5 的頭部上緣被壓在列下方(1920 圖上 y≈764~797 的突出部分)。與測試的「格不相交」並不矛盾。
- 這個缺口 043 自己已揭露:測試檔頭「【未加】收合列與敵兵棋子視覺矩形的最小間隙」;story-043 `:72` 加註管理者裁決「最小間隙延到 48 格改造時一起做」;`active.md` 記 (9,4) 貼邊僅 1~2px。

**判定**:**不是 043 回歸;是 043 已裁決延後的「棋子視覺矩形最小間隙」缺口**,截圖正好證實它在 (11,5) 肉眼可見(頭部被壓)。AC1 字面(格矩形不相交)仍成立。
**歸屬**:併入已登記的「48 格改造/大地圖捲動」那張(`docs/reviews/big-map-scroll-requirements-2026-11-12.md` 第四節)。若管理者看過截圖想提前處理,需**撤銷該延後裁決**後新開工單(要先有「棋子視覺矩形」單一出處函式,測試檔頭已說明缺它)。

## 3. 傷害預覽「23→7」被裁最後一字

**事實**
- 預覽字串:`board_view.gd:1174-1176` `"%d→%d" % [hp, hp_preview]`,字型大小 8(`HP_TEXT_FONT_SIZE`,`:337`),Label 沒覆寫字型(僅 `font_size`、顏色)。
- 文字條矩形:`hp_text_rect_in_cell()`(`:1063-1064`)= `Rect2(0, 0, CELL_SIZE=32, 8)`,寬 32。`:1156-1162` 把 Label 放進 `clip_contents` 容器裁切。
- 檔內註解(約 `:1100` 起的 story-041 說明)自稱實測「22/22 = 22px、22→15 = 27px」,結論放得進 32px。
- PROBE(`Label` + `font_size=8`,headless,未帶遊戲內主題):`get_minimum_size()` 寬 = `22/22`:43、`23→7`:44、`30→15`:53、`9→0`:35,全部 > 32。**但這支探針的高度是 23,與程式註解的 12 不符,代表探針的字型環境與遊戲內不同,寬度數字不能直接當遊戲內實值**(不是 (A) 級渲染證據)。
- 02 號圖(1920x1080)人眼可見:文字條內為 `23→` + 被切一半的 `7`,右緣被裁。同圖 00 號的 `22/22`(丙)顯示完整,但 `22/22` 比 `23→7` 短 1 字元。
- 成因推測(**未驗證**):Label 實際最小寬 > 32 時 `label.size = Vector2(32, ...)` 會被引擎夾回最小寬,置中對齊失效、右側被 `clip_contents` 切掉。我沒開窗量,不下定論。

**判定**:**bug(常態性)**。兩位數對兩位數(例 `30→15`,hp_max 上限 30)比 `23→7` 更長,必然更嚴重;041 的「放得下」是靠註解中的實測宣稱,而這張圖直接反證它。測試 `board_view_hp_text_label_layout_test.gd` 驗的是節點幾何,headless 不 rasterize(檔頭 `:14`),所以抓不到。
**歸屬**:story-041 後續(`production/epics/tactical-combat/story-041-hp-text-vs-piece-label-overlap.md`)開一張修補單:先開窗量實際字寬,再決定縮字級/去掉箭頭/改兩行(要動 041 的三帶版面算術,屬 art-director + ux 裁決,不是實作者自選)。短期證據:拿 `30→15` 再拍一張。

## 4. 乙(徐培恩)白色首字對比

**事實**
- 首字有描邊:`board_view.gd:1031-1036` `_piece_label_settings()`:`outline_color = PIECE_LABEL_OUTLINE_COLOR`(`#0E0F14`,`:345`)、`outline_size = 1`;字色 `PIECE_LABEL_COLOR_ALLY = #FFFFFF`(`:343`);字型 Cubic 11 原生 11px(`:339-340`)。
- 樣式依 `docs/reviews/piece-initial-label-style-2026-11-12.md`(art-director,1px 描邊、無底色塊)。
- 截圖(00 號圖左側我方一排)人眼:`保`、`藍` 等首字落在淺灰/淺綠衣物上,1px 深色描邊在 4x 放大下只是一條細線,字形仍偏糊。我沒量對比比。

**判定**:**不是漏描邊;是規格缺口**——「1px 描邊 + 無底色塊」本身在淺色衣物上不夠。實作符合規格。
**歸屬**:art-director 決定(加粗描邊至 2px / 半透明襯底 / 依衣色換字色);核准後另開一張 039 後續工單。不屬 041 範圍。

## 5. story-043 狀態 vs git log

**事實**
- 檔頭 `:4` 仍寫 `Status: Ready(2026-11-12)—— 須先交「版面提案」並經 lead-programmer 同意才能寫碼`。
- `git log -- <story-043 檔>`:僅 `b7005b1`(延後加註)與 `6e851b1`;`git show 74fbce7 --stat` 對該檔的命中數 = 0,即**實作提交沒有更新工單狀態**。
- `74fbce7` 提交訊息明列 043,並含 `hand_bar_enemy_occlusion_test.gd` 與 `hand_bar.gd` 改動;`active.md` 亦記 043 已交件、舊測試已刪、全套 2042/0。

**判定**:**ux 審查的說法是讀工單檔頭得到的,錯在檔頭過期,不是 043 沒做**。協調者紀錄(043 已於 `74fbce7` 提交)正確。正確現況:AC1(格矩形不相交)已做;AC2 展開態與最小間隙為已裁決延後;AC5 像素層補拍本批截圖算是補拍(待人看)。
**歸屬**:需要有人更新 story-043 檔頭(狀態改為「AC1 完成、AC2/最小間隙延後」)。這是既有文件,我先不動;請協調者同意後改。另提醒:ux 審查 `lunch-capture-ux-review-2026-11-13.md:57` 該句應更正。

## 附註
- 探針腳本在 scratchpad(`probe_blocked.gd`、`probe_hp_label.gd`),不在 repo;未改任何既有檔。
