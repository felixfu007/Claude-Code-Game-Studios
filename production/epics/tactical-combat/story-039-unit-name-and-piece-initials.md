# Story 039:資訊卡顯示正式姓名 + 棋子標姓名首字/敵兵編號

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-12)
> **Type**: UI
> **Estimate**: S~M
> **依據**:
> - 管理者 2026-11-11 試玩回報(逐字):「重點不是圖片,是你的資訊卡根本沒有說他是誰啊」。
> - 管理者 2026-11-11 裁決 2:「**現在就標字 + 寫進美術規範(推薦)**」;裁決 7「明天再做」= 2026-11-12。
>   紀錄:`production/session-state/active.md` 第九十八批節「管理者裁決(7 項)」表第 2、7 列。
> - 管理者 2026-11-11:「不要再用甲乙丙丁戊來代稱腳色了,他們現在都有名字」。
> - 樣式:art-director `docs/reviews/piece-initial-label-style-2026-11-12.md`(位置/色/描邊/敵方只標數字)。
> - 字形與幾何(A 級):`prototypes/piece-label-glyph-probe-2026-11-12/README.md`(Cubic 11 對所需 29 字缺字 0;11px 中文 12×14、數字 6×14;棋子 32×40)。

## 為什麼

資訊卡的單位分支只有陣營/HP/狀態/射程/MP,沒有名字(根源:`tactical-combat-system.md` UI Requirements §1 最小欄位清單漏列)。
棋子圖只靠顏色區分,玩家「靠色塊根本不知道誰是誰」。姓名早已在 `strings.csv` 的 `character.name.1~5`,
關係圖與對話畫面已在用(`relation_minimap.gd` / `support_conversation_screen.gd` 的 `"character.name.%d"`)。

## Acceptance Criteria

- [ ] **AC1** 游標指到**我方**單位時,資訊卡第一行顯示「<正式姓名>(我方)」,例:「藍亭萱(我方)」;取代原「陣營」行,**總行數不變**。
      姓名一律經 `Loc.localize("character.name.%d" % unit_id)` 取得,不得寫死。
- [ ] **AC2** 游標指到**敵方**單位時,第一行顯示「敵兵 N(敵方)」,N 為該敵兵固定編號(取自名冊 `code_name` 的 `E<N>`;擊倒後其他敵兵編號不重排)。
      「敵兵 %d」新增在地化鍵(放 `assets/data/locales/strings.csv`),不得寫死中文。`code_name` 不符 `E<數字>` 格式 → `push_error` + 該行退回原陣營文字(不得 `assert`,見 `coding-standards.md` release 移除 assert 條)。
- [ ] **AC3** 每個**我方**棋子顯示姓名首字(取正式姓名的第一個字,不另設字串鍵),**敵方**棋子顯示編號數字 N(與 AC2 同一個 N)。
      樣式照 art-director 文件:Cubic 11 原生 11px、1px 描邊、無底色塊;我方字 `#FFFFFF`、敵方字 `#FF5252`、描邊 `#0E0F14`;
      字框左上角在棋子圖座標 (0,16)。畫在世界層(隨棋子移動、整數像素對齊)。
- [ ] **AC4** 首字/編號跟著棋子:移動、陣亡移除、敵方回合播放時皆同步(不得殘留在舊格)。
- [ ] **AC5** 不影響既有:HP 條、HP 文字、行動旗標、棋子排序(story-037 `piece_draw_order`)。
- [ ] **AC6** 敏感度證明:AC1、AC2、AC3 各至少一條(故意改壞 → 紅 → 還原)。
- [ ] 交付前全套:`GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始行。

## 未涵蓋(刻意,勿擴大)

- 文件同步(`tactical-combat-system.md` UI §1、`design/ux/tactical-combat-screen.md`、`design/art/art-direction.md`「不得只靠顏色」條文)—— 屬既有文件,協調者另行請示管理者。
- 空格顯示地形(管理者 2026-11-12 裁決延到畫面捲動完成後)、「無法攻擊:原因」一行(另開工單)。
- 像素層實機確認(字蓋不蓋到角色圖案、紅字在灌木/倒木上的對比)—— 由午休截圖或在家目視,非本單驗收門檻。

## Affected Files

`src/ui/battle/battle_screen.gd`(`build_tile_info_text` 及其呼叫端)、`src/ui/battle/board_view.gd`(`render_pieces` 一帶)、
`assets/data/locales/strings.csv`(新增 1 鍵)、新測試檔;斷言「陣營」行字面值的既有測試(逐一列在交付報告)。
超出此清單的檔案先問。
