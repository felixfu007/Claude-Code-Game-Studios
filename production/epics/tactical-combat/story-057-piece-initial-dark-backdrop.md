# Story 057:我方棋子首字加深色襯底(α0.72),游標停在該棋子時也必須看得到

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: ✅ Done-pending-visual(2026-11-16,提交 `7cc0d1f`;游標格首字洗淡依管理者裁決接受;AC7 管理者本人逐張看五位角色待確認)(原狀態:Ready(2026-11-16,管理者已裁決方案)—— 🔴 排序前置見最後一節(047 之後))
> **Type**: Visual/UI(世界層)+ Logic(顯示規則)
> **Estimate**: S(約 1 天:襯底節點與池子 0.25、顯示規則與測試 0.25、敏感度證明 0.25、開窗驗「游標停在棋子上」0.25;若「游標蓋住底」的成因比預期難找,加 0.5)
> **依據**:
> - 管理者 2026-11-16 裁決(逐字):首字底 =「**A:全部加濃底(美術總監推薦)**」。紀錄:`production/session-state/active.md`(當場查 `grep -n "全部加濃底" production/session-state/active.md`)。
>   - 🔴 「全部」的範圍:**我方所有棋子**。敵方不套 —— art 補遺第 5 節 ① 已收回「所有棋子一律」,理由是敵兵紫底上的紅色編號本來就清楚。
> - 規格(權威):`docs/reviews/art-addendum-icons-contrast-salience-2026-11-13.md` **第 2.2 節**(襯底做法)與**第 5 節 ②方案 A**(只套我方、α0.72)。第 5 節 ① 對第 2.2 節「所有棋子一律」的收回,**以第 5 節為準**。
> - 並排實拍:`prototypes/label-backdrop-compare-2026-11-13/`(驅動以 `ColorRect` 模擬,**未改 `src/`**)。
> - 🔴 art 實拍發現(本單 AC2 的來源):`docs/reviews/lunch-capture-art-review-2026-11-16.md` **第 1 節** —— 游標停在徐培恩時,A/B/C 三版在 1920 圖上**徐的底都看不見**,但驅動 log 的 BACKDROP 行說底存在,art 疑為被游標格高亮或層序蓋住。**該檔寫在主 repo `docs/reviews/`;本單撰寫時所在 worktree 尚無此檔,以主 repo 為準。**

## 現況(實作者動工前先當場查證,不採信本節)

以下用指令查,**不寫死行號**(行號會漂):

- 圖層順序(`BoardView.tscn` 子節點順序即繪製順序):`grep -n "node name=" src/ui/battle/BoardView.tscn` → TerrainLayer … `PiecesLayer` … `MoveUnreachableLayer`、`AffinityLineLayer`、`ThreatHighlightLayer`、`AttackHighlightLayer`、`AttackLosBlockedLayer`、`CardTargetHighlightLayer`、`StatsLayer`、`ActionFlagLayer`、`CursorSprite`(最上)。
- 首字不在 `.tscn` 裡:`grep -n "_piece_label_layer\|PieceLabelLayer" src/ui/battle/board_view.gd` —— `_apply_piece_label()` 執行期才建立 `PieceLabelLayer`,並 `move_child(_piece_label_layer, _stats_layer.get_index() + 1)`,**即在 `StatsLayer` 之上、`ActionFlagLayer` 之下**。首字 `Label` 走池子(`_piece_label_pool`),`render_pieces` 結尾把用不到的池子項 `visible = false`。
- 首字矩形單一出處:`grep -n "static func piece_label_rect_in_cell" src/ui/battle/board_view.gd`(12×14,格內 (0,8)-(12,22));樣式:`grep -n "PIECE_LABEL_" src/ui/battle/board_view.gd`(白字 `#FFFFFF`、描邊 `#0E0F14` 1px,11px Cubic 11)。
- `render_pieces` 內首字呼叫點:`grep -n "_apply_piece_label(" src/ui/battle/board_view.gd`;已按 `faction == "PLAYER"` 區分我方。
- 棋子圖在 `PiecesLayer`,做完的棋子**只對棋子貼圖** `modulate` 變暗(story-054),首字不暗 —— 襯底同樣不得被暗化。

🔴 **本現況的推論(未驗證)**:依上面層序,首字 `Label` 與 `PieceLabelLayer` 本身已在 `StatsLayer` 之上,看起來沒有任何**棋盤高亮層**(都在 `StatsLayer` 之下)能蓋住它;能蓋住的候選只剩 `CursorSprite`(最上層,`cursor_outline.png`)。**但 art 實拍是「字還在、底看不見」**,這與「底和字同在 `PieceLabelLayer`」的做法矛盾 —— 暗示 art 看到的是**驅動用 `ColorRect` 模擬**掛的位置(驅動檔 `prototypes/label-backdrop-compare-2026-11-13/driver.gd`)被別層蓋住,**不必然代表正式實作也會被蓋**。這是推論,不是量測。**AC2 就是為了把它變成量測。**

## 規則

- **只畫我方**:`faction == "PLAYER"` 且 `label` 非空才畫襯底。敵方、無首字的棋子:不畫、也不留殘影(池子重用時要隱藏)。
- **位置/大小**:取 `piece_label_rect_in_cell()` 的回傳(12×14),**不另寫座標**。
- **色**:`nature_void_shadow_01` = `#0E0F14`,alpha **0.72**(art 補遺 2.2 逐字;常數,依 `.claude/rules` 慣例命名並寫 doc comment;α 未過時只改這一個常數,art 預備階梯:0.72 → 0.85)。
  - ⚠️ **未驗證的不一致**:補遺寫「與現行 `HP_TEXT_BG_COLOR` 同值」,但 `grep -n "const HP_TEXT_BG_COLOR:" src/ui/battle/board_view.gd` 讀到的是 `Color(0.0, 0.0, 0.0, 0.72)`(純黑),**RGB 與 `#0E0F14` 不同**,只有 alpha 相同。本單**按補遺的明文色 `#0E0F14`** 實作,不借用 `HP_TEXT_BG_COLOR`;兩者視覺差極小,**但實作者須在回報中寫明這個不一致,讓 art 決定要不要把它們統一**。
- **圖層**:在首字 `Label` **正下方**(同一個 `PieceLabelLayer` 內、先於 `Label` 加入,或其下相鄰),在棋子貼圖之上。**不得掛在 `CursorSprite` 之下的任何「可能被高亮蓋住」的層**之外的地方 —— 即:不得掛進 `PiecesLayer`(會被所有疊在棋子上的層蓋住)。實際位置以 AC2 的游標狀態量測為準。
- **不暗化**:做完(DONE)棋子的襯底與首字照舊不暗(054 規則:只暗棋子貼圖)。
- **字與描邊不動**(1px 描邊維持;不加粗)。
- 襯底與其他東西的空間關係:不碰 HP 條(y26~28)、被擋章 (21,8)-(27,14)(052 起只畫在敵兵格,與我方無關)、HP 文字條 (y0~8,襯底在其正下方相接)。
- 48 格版不在本單(補遺:矩形仍取 `piece_label_rect_in_cell()`,屆時隨 48 格改版一併做)。

## Acceptance Criteria

- [ ] **AC1 顯示規則(逐格斷言)**:`render_pieces` 餵入 {我方有首字, 我方無首字, 敵方有編號} → 襯底節點恰為 {有, 無, 無};襯底矩形 = `piece_label_rect_in_cell()` 平移到該格(預言機取函式,測試不另設座標);顏色 RGB = `#0E0F14`、alpha = 0.72(預言機取常數)。防空洞:三種輸入結果彼此不同,且至少出現一次「有」。
- [ ] **AC2 🔴 游標停在該棋子上,襯底仍看得到(必須是 AC,管理者裁決明文)**:
  - **結構層(headless 可跑)**:游標落在該我方棋子所在格(經真實 `BattleScreen` 的游標路徑,不直接呼叫私有方法)後,襯底節點 `visible == true`、其祖先鏈全程 `visible`、且在 scene tree 繪製順序上**位於所有可能覆蓋它的節點之後**——「可能覆蓋它的節點」由實作者列舉:`grep -n "add_child" src/ui/battle/board_view.gd` 產生的各高亮層 + `CursorSprite`;**逐一寫出它們與襯底的相對順序**於回報。
  - **像素層(只能開窗,headless 取不到像素)**:在「游標停在我方棋子上」狀態,取襯底矩形區域內**不被首字筆畫與描邊佔據**的像素,其顏色須接近 `#0E0F14` 疊在棋子色上的預期值(以 α0.72 合成算出,允許小容差,容差值寫明並說明來源);同一格在「游標不在」狀態取同一組像素作對照,**兩者差異須小於容差**(證明游標沒有蓋掉襯底)。
  - 🔴 **像素驗收必須走「載入真實 `BattleScreen` 場景檔」**(`technical-preferences.md` 第 5 點),**不得**自組替身節點鏈、**不得**沿用 `prototypes/label-backdrop-compare-2026-11-13/driver.gd` 的 `ColorRect` 模擬。原始 log 要留宿主鏈真實量測值(`WorldViewportContainer` 的 `position`/`size`/`stretch_shrink` 與 `WorldViewport.size`),沒有 log 的「(A) 級」降為 (C)。
  - 若量到襯底在游標狀態下被蓋住:**停下來回報成因**(哪一層、為何),不得用提高 `z_index` 之類的繞法蓋過去而不說明。
- [ ] **AC3 不暗化**:做完的我方棋子,襯底 `modulate` = `Color.WHITE`;首字 `modulate` 不變(與 story-054 AC4 一致)。防空洞:同測試先斷言未做完時亦為 `Color.WHITE`,且至少含一個做完案例。
- [ ] **AC4 池子重用不殘留**:連續兩次 `render_pieces`,第一次 3 個我方有首字、第二次 1 個 → 第二次畫面上襯底恰 1 個可見(其餘隱藏或移除,實作者擇一並寫明);**位置須隨棋子更新,不得停在舊格**。
- [ ] **AC5 敵方不套**:敵方棋子任何狀態下,首字襯底節點集合為 ∅(含游標停在敵方棋子上、含被攻擊預覽)。
- [ ] **AC6 敏感度證明**(🔴 一個 mutant 一次獨立執行,不可一次改多處):①敵方也畫襯底 → AC5/AC1 紅 ②α 改 0.3 → AC1 紅 ③襯底改掛 `PiecesLayer` → AC2 結構層紅 ④襯底改掛到 `CursorSprite` 之上以外的更低層使其被覆蓋(實作者依 AC2 列舉的結果挑一個真能被蓋住的層)→ AC2 紅 ⑤做完時襯底一起暗 → AC3 紅 ⑥池子重用不隱藏舊項 → AC4 紅。交付前掃殘留注入標記(🔴 測試線上「第一個紅就中止同檔其餘測試」,逐斷言證明需分次跑,見 `coding-standards.md`)。
- [ ] **AC7 Check 5 人眼確認(像素層,管理者本人看圖)**:960×540 與 1920×1080 各一張,各含「游標在徐培恩」與「總覽無游標」兩種狀態;**五位我方角色逐張確認**(art 補遺 2.2 副作用:襯底蓋住角色左側 12×14 一小塊,原本字就壓在那裡)。
  - 截圖類別先判(`coding-standards.md` 分類測試):全視窗 → Category A;Check 4 依 2026-09-23 裁決,首字襯底在世界層、無縮放 → **「沒有可測對象(N/A)」須寫 N/A,不得寫「通過」**。
  - 結論強度:受測者只有管理者本人且知道此設計 → 只證明「他在這個尺寸讀得出」,紀錄須明寫,**不得寫成「盲測通過」而不加限定**。
  - 未過:alpha 提到 0.85(只改一個常數)再回 art。
- [ ] **AC8 既有測試不得被刪斷言換綠**:`tests/integration/ui/board_view_hp_text_label_layout_test.gd`、`tests/integration/ui/battle_screen_unit_name_and_piece_initials_test.gd` 引用首字池子,新增襯底若造成子節點數或層序斷言變動,實作者讀懂其性質後調整並**逐條說明**;其他引用當場 `grep -rln "piece_label_rect_in_cell\|_piece_label_pool\|PieceLabelLayer" tests`。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(依 2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 敵方襯底(art:等真實敵兵圖上屏、紅號在其上不夠清楚時再回頭補)。
- 48 格版;名牌與血量合併成一條(art 補遺第 5 節方案 E,「不在本批範圍」)。
- 首字字級、描邊、換字型。
- 圖例(047)是否要新增「首字襯底」一列:**本單不加**;若 047 的標記清單設計成列舉全部 `BoardView` 畫的東西,由 047 的維護者決定。

## Affected Files

- `src/ui/battle/board_view.gd`(`_apply_piece_label` 與襯底節點、常數)
- `tests/integration/ui/board_view_hp_text_label_layout_test.gd`、`tests/integration/ui/battle_screen_unit_name_and_piece_initials_test.gd`(視需要調整)
- 新測試檔:`tests/integration/ui/board_view_piece_label_backdrop_test.gd`
- `prototypes/story-057-label-backdrop-cursor-evidence-<日期>/`(開窗驅動 + log + 截圖,不進 `src/`)

超出此清單先問。若需動 `battle_screen.gd`(例如 `render_pieces` 輸入字典缺欄位),先問。

## 與其他工單的順序

- 🔴 **排在 story-047(圖例)之後**:047 正在 worktree 實作,會在 `board_view.gd` 加標記清單/示範繪製;本單同檔。047 合併後再開工,避免兩邊對同一段(`render_pieces` 周邊、`_apply_piece_label`)衝突。
- **排在 story-055(傷害預覽血量字被截)之後**:055 可能「動三帶」(HP 文字條/首字/血條版面,其 Status 目前 Blocked,待 art + ux 選修法)。若 055 改了首字矩形或三帶高度,本單因取自 `piece_label_rect_in_cell()` 自動跟隨,但 AC2/AC7 的像素驗收須在 055 之後的版面上跑。055 若遲遲不解除 Blocked,本單**可先行**(只要 047 已完成),但須在回報註明未含 055。
- 與 story-058 同檔,**須序列,不可同批**;建議 057 先於 058(058 的環上緣與 HP 文字條相接,見 058)。
- story-051(敵方型別、我方姓名)、054(已完成,`0582b98`)不衝突:本單只讀 `label` 與 `faction`。
