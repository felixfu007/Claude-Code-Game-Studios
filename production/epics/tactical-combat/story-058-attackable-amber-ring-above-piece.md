# Story 058:可攻擊琥珀框在「只選取、游標不在該敵」時也成完整一圈

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-16,管理者已裁決方案)—— ⚠️ **步驟 1(查成因)的結果可能推翻裁決所依據的前提**,見「🔴 前提待查」;查證不符就停下回報,不要照裁決字面硬做
> **Type**: Visual/UI(世界層)+ Logic(環的幾何)
> **Estimate**: S~M(約 1~1.5 天:成因查證 0.25、環幾何與常數 0.25~0.5、測試預言機更新 0.25、敏感度證明 0.25、開窗兩狀態實拍 0.25~0.5)
> **依據**:
> - 管理者 2026-11-16 裁決(逐字):琥珀框 =「**框畫在棋子上層,成完整一圈(美術總監推薦)**」。紀錄:`production/session-state/active.md`(當場查 `grep -n "全部加濃底" production/session-state/active.md`,同批裁決兩項);🔴 該裁決的「畫在棋子上層」說法來自 art 的成因判斷,見下一節。
> - 證據:`docs/reviews/lunch-capture-art-review-2026-11-16.md` **第 3 節**(044 可攻擊琥珀框):游標停在該敵(02 圖)= 完整琥珀圈;**只選取、游標不在該敵(00 圖)= 只剩左、右、下三邊的 U 形薄線,art 判斷「上緣被棋子身體蓋住」**;截圖 `prototypes/lunch-capture-2026-11-13/out/00_1920x1080_s044_unit_selected_attackable_and_los_blocked.png`。**該 review 檔寫在主 repo `docs/reviews/`;本單撰寫時所在 worktree 尚無此檔,以主 repo 為準。**
> - 上游規格:story-044(T5 高亮層級重做;環省略 HP 文字條範圍的設計出處)、`docs/reviews/art-addendum-icons-contrast-salience-2026-11-13.md` 第 3 節(「可攻擊」醒目度階梯;本單**不屬**階梯 2/3 的加寬或降低移動藍 alpha)。

## 🔴 前提待查(讀程式得到的疑點,未經引擎驗證)

裁決是照 art 的成因判斷選的:「上緣被棋子身體蓋住」。lead-programmer 讀 `board_view.gd` 後有**兩處與這個成因對不上**:

1. **環本來就在棋子上層**:`AttackHighlightLayer` 在 `BoardView.tscn` 中位於 `PiecesLayer` 之後(`grep -n "node name=" src/ui/battle/BoardView.tscn`),類別文件註解亦明寫「threat and attack layers sit ABOVE them」。所以「把環改畫到棋子上層」**字面上已經是現況**。
2. **環的上緣根本沒有被畫出來,是設計如此**:`grep -n "static func ring_rects_in_cell" src/ui/battle/board_view.gd` —— 該函式只回傳**三個**矩形(下邊、右邊、左邊;右邊從 `hp_text_rect_in_cell().end.y` 起,左邊從 `piece_label_rect_in_cell().end.y` 起),**沒有上邊**;其函式上方註解寫「環省略 HP 文字條範圍(上邊整條不畫……)」。設計意圖是:游標停在該敵時,HP 文字條(StatsLayer,y0~8)出現並充當上緣,於是看起來是完整一圈(= art 看到的 02 圖)。**游標不在時沒有文字條,上緣就空著 —— U 形(00 圖)。**

**推論(未驗證)**:00 圖的 U 形成因是**環的幾何不含上邊**,不是**圖層被棋子蓋住**。若屬實,「畫在棋子上層」不會改變任何像素,真正的修法是**補一條上邊**。
**但裁決的意圖(「只選取時也成完整一圈」)清楚,與成因無關**,故本單的驗收以**結果**為準(AC1),而不是以「改了圖層」為準。

**步驟 1(實作者第一件事)**:用拋棄式開窗探針回答「00 圖狀態下,環的上緣位置那一列像素是什麼?」—— 取該敵格上緣 (0,0)~(31,1) 的實際像素:是琥珀色(被畫了但被蓋)、是棋子色(被棋子蓋)、還是底下的地形色(根本沒畫)。**探針須走真實 `BattleScreen` 場景檔**(第 5 點規則,留宿主鏈量測值 log)。把結果與上面兩條推論逐字對照回報:
- 與推論相符(沒畫)→ 照下方「規則」補上邊,**並向協調者回報「裁決的『畫在棋子上層』前提不成立、已按意圖修」**;
- 與推論不符(畫了但被蓋)→ **停下**,回報實際被誰蓋,再決定改層序或改別的 —— 不要自行擇一硬做。

## 現況(動工前先當場查證,不採信本節)

- 環單一出處:`grep -n "static func ring_rects_in_cell\|static func attack_ring_rects_in_cell\|static func threat_ring_rects_in_cell" src/ui/battle/board_view.gd`;可攻擊與威脅**共用 `ring_rects_in_cell(width)`**,只差寬度與色(`ATTACK_RING_WIDTH`/`ATTACK_RING_COLOR` 與威脅對應常數:`grep -n "RING_" src/ui/battle/board_view.gd`)。
- 面積不等式:044 的 `W_可攻擊 > W_威脅 > W_被擋` 由程式依矩形求值(`grep -n "rect.get_area()" src/ui/battle/board_view.gd` 附近的加總函式)。**若只給可攻擊環補上邊而威脅環不動,可攻擊環面積變大 → 不等式更成立,不會破;若兩者都補,三者須重算。**
- 建構:`grep -n "_build_ring_marker" src/ui/battle/board_view.gd` —— 可攻擊環由 `set_attack_highlights` 路徑畫進 `AttackHighlightLayer`;**同一函式也被圖例路徑呼叫**(`MarkerKind` 那段 `_build_ring_marker(cell, attack_ring_rects_in_cell(), ATTACK_RING_COLOR)`;本 worktree 已見該呼叫點,**047 圖例是否已併入主線未驗證**)。
- 上邊會與 HP 文字條相疊:文字條在 `StatsLayer`(在 `AttackHighlightLayer` 之上,`grep -n "node name=" src/ui/battle/BoardView.tscn`),y0~8;游標停在該敵時它會**蓋住**環的上邊(若補了的話)。這在視覺上等於「文字條充當上緣」不變,**但環上邊那 2px 被蓋住屬預期,不是缺陷**。
- 游標白框(`CursorSprite`,最上層)與環的間隙:art 補遺第 3 節階梯 2 已警告「環向內長會吃掉與游標白框的 1px 空隙,須先量實際間隙」—— **本單不加寬環,但補上邊後上緣也新增了與游標白框的相鄰關係,須量一次**(AC4)。

## 規則

- **結果規格(以此為準)**:攻擊可達的敵兵格,環在以下兩種狀態都是**閉合的四邊**:①游標停在該敵(HP 文字條出現)②只選取我方、游標不在該敵(沒有 HP 文字條)。
- **做法(建議,依步驟 1 結果確認)**:給**可攻擊環**(`attack_ring_rects_in_cell`)加一個上邊矩形 `Rect2(0, 0, CELL_SIZE, width)`;**切點與寬度由同一個 `ring_rects_in_cell` 式的單一出處算出,不另寫死數字**。威脅環是否同補:**預設不補**(威脅環降調是 044 的設計,補上邊會讓它變醒目);若實作者認為必須同補,先問。
- **單一出處、不複製公式**:上邊矩形併入 `attack_ring_rects_in_cell()` 的回傳(或其內部共用函式),使**建構、測試預言機、047 圖例三者讀同一份矩形集合** —— 因為圖例路徑已呼叫 `attack_ring_rects_in_cell()`,**只要改在這個函式裡,圖例自動同源**,不得在圖例另畫一份(047 的明文要求:圖例圖示由 `BoardView` 同一組建構函式/常數繪出)。
- **層序**:不搬層(環已在棋子上層)。若步驟 1 發現環被蓋住,才依實測結果決定,且**回報前不動層序**。
- **色與寬度不動**:`ATTACK_RING_COLOR`(`#FFBF4D` 等值,實作者當場讀常數)、`ATTACK_RING_WIDTH` 不變(art 補遺第 3 節階梯 1 =「現在不改環」)。
- 不改:被擋章(052 起只畫敵兵格)、威脅環、移動藍填色。

## Acceptance Criteria

- [ ] **AC1 兩狀態皆閉合(結果驗收,核心)**:對一個可攻擊的敵兵格,環的矩形集合覆蓋四邊(上、下、左、右各至少一個矩形,且四邊在角落相接無缺口);在「HP 文字條**未**顯示」與「顯示」兩種狀態下,該格 `AttackHighlightLayer` 內的環矩形集合**相同**(上邊不隨文字條有無而變;文字條顯示時是它蓋在環上邊之上,不是環消失)。預言機取自 `attack_ring_rects_in_cell()`,測試不另設座標。防空洞:同測試斷言「補上邊之前」的三邊集合不同於現在的四邊集合(證明這條斷言真的會因本單的改動而翻轉)。
- [ ] **AC2 像素層(只能開窗)**:在真實 `BattleScreen`(第 5 點規則)取兩個狀態各一張:①只選取我方、游標不在該敵 ②游標停在該敵。兩張中該敵格上緣 y0~width 區域的像素,①須為 `ATTACK_RING_COLOR`(容差寫明);②該區域被 HP 文字條覆蓋,不要求琥珀色,但**須記錄實際像素**供對照。960×540 與 1920×1080 各做。
  - 🔴 **像素驗收在「只選取、游標不在該敵」狀態**必須做(這是缺陷發生的狀態);只拍游標在敵的狀態不算。
  - 原始 log 留宿主鏈真實量測值(`WorldViewportContainer` 的 `position`/`size`/`stretch_shrink`、`WorldViewport.size`);沒有 log 的「(A) 級」降為 (C)。
  - 截圖類別先判(`coding-standards.md` 分類):全視窗 → Category A;**Check 4:環與格是原生像素、無縮放 → 「沒有可測對象(N/A)」須寫 N/A,不得寫「通過」**。
- [ ] **AC3 不等式與其他環不破**:`W_可攻擊 > W_威脅 > W_被擋` 仍成立(由程式依矩形求值,預言機取現有求值函式,不另算);威脅環矩形集合與本單前**逐字相同**(預設不補上邊時);被擋章不受影響。防空洞:測試同時斷言可攻擊環面積**嚴格大於**本單前的值。
- [ ] **AC4 與游標白框的間隙(art 補遺第 3 節階梯 2 的警告延伸)**:實作者當場量「環上邊」與 `CursorSprite` 白框的像素間隙(讀 `cursor_outline.png` 實際像素與其置中位置),**寫入回報**。若環上邊與游標框**相接或重疊**:停下回 art,不自行調整。(art 原話:「若相接就停下回我」。)
- [ ] **AC5 圖例同源**:`grep -n "attack_ring_rects_in_cell" src/` 的結果中,建構與圖例呼叫點**都**讀同一函式;圖例範例的可攻擊環須同樣是閉合四邊(047 若已併入,補一條測試;未併入則此條改為在 047 的單裡加註,並於回報寫明)。🔴 搜尋指令不得寫進被搜尋檔的註解。
- [ ] **AC6 敏感度證明**(🔴 一個 mutant 一次獨立執行):①拿掉上邊(回到三邊)→ AC1 紅 ②上邊只在「HP 文字條未顯示」時才畫(讓兩狀態集合不同)→ AC1 紅 ③上邊寬度與左右邊不同 → AC1 紅(角落缺口或溢出)④威脅環也被補上邊 → AC3 紅 ⑤圖例另畫一份三邊環 → AC5 紅 ⑥上邊位置挪到格外(y 為負)→ AC2 像素層紅。交付前掃殘留注入標記。
- [ ] **AC7 既有測試調整(逐條說明)**:`tests/integration/ui/board_view_highlight_hierarchy_test.gd`、`tests/integration/ui/legend_panel_test.gd` 引用環矩形/面積,實作者讀懂其性質後改為斷言新幾何的同一性質,**不得刪斷言換綠**;其他引用當場 `grep -rln "ring_rects_in_cell\|attack_ring\|ATTACK_RING" tests`。
- [ ] **AC8 Check 5 人眼確認**:管理者本人開 AC2 兩張圖確認「只選取時也是完整一圈」。結論強度:受測者只有管理者本人 → 紀錄須寫明限定,不得寫成「盲測通過」而不加限定。**未過**:回 art(階梯 2 加寬環屬 art 補遺第 3 節,不屬本單)。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 環加寬(3px)、降低移動藍 alpha(art 補遺第 3 節階梯 2/3,待重拍後 art/ux 判斷)。
- 威脅環、被擋章、對應 U 形缺口(044 的「首字框缺口」維持:左邊仍從首字框下緣起畫,**不因本單補上邊而改**)。
- 48 格版。

## Affected Files

- `src/ui/battle/board_view.gd`(`ring_rects_in_cell` / `attack_ring_rects_in_cell` 及其呼叫者)
- `tests/integration/ui/board_view_highlight_hierarchy_test.gd`、`tests/integration/ui/legend_panel_test.gd`(調整)
- 新測試檔:`tests/integration/ui/board_view_attack_ring_closed_test.gd`
- `prototypes/story-058-attack-ring-evidence-<日期>/`(步驟 1 探針 + 開窗驅動 + log + 截圖,不進 `src/`)

超出此清單先問。

## 與其他工單的順序

- 🔴 **排在 story-047(圖例)之後**:047 正在 worktree 實作,會動 `board_view.gd` 的標記清單;圖例的可攻擊環範例與本單**必須同源**(AC5)。若 047 先併入,本單改 `attack_ring_rects_in_cell()` 即自動帶動圖例;若本單先做,047 實作者須改讀新函式回傳 —— 故排 047 之後較省事。
- **排在 story-055 之後**:環的左右邊切點取自 `hp_text_rect_in_cell()`,上邊與文字條相疊;055 若改文字條尺寸/三帶版面(其 Status 目前 Blocked),環的幾何與 AC2 像素驗收都須在 055 之後的版面上做。055 若遲遲不解除 Blocked,本單可先行,但須在回報註明未含 055。
- **排在 story-057 之後**(同檔須序列,不同批):057 加我方首字襯底(格內 (0,8)-(12,22)),與本單環的左邊「從首字框下緣起」切點同依賴 `piece_label_rect_in_cell()`,但互不改對方的矩形;先 057 後 058 可讓 058 的像素實拍同時看到首字襯底與環的左邊缺口。
- story-052(被擋章只畫敵兵格)已完成不衝突;story-054(已完成,`0582b98`)不衝突。
