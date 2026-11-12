# Story 042:資訊卡「遮蔽」行改字為「擋視線」,消除與「攻擊:視線被擋」的矛盾

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-12)
> **Type**: UI(文案/在地化資料)
> **Estimate**: S
> **優先序**: 畫面可讀性批次 T2
> **依據**:
> - 管理者 2026-11-12 核准範圍,選項逐字「**修今天的字重疊 + 介面 + 重做高亮層次 + 圖例(UX 專家推薦)**」(含 T2)。
> - 管理者 2026-11-12 就 T2 裁決,選項逐字「**先只改「遮蔽」那行的字,不加主詞**」。被跳過:攻擊行加主語(「董振豪攻擊：視線被擋」)。
>   紀錄:`production/session-state/active.md` 第九十九批節(grep「重做高亮層次」)。
> - 矛盾證據:`docs/reviews/screen-readability-verified-ux-2026-11-12.md` 第五節與 N7;`docs/reviews/screen-readability-ticket-plan-2026-11-12.md` T2。

## 為什麼

資訊卡同屏出現「遮蔽：否」(游標所在格)與「攻擊：視線被擋」(story-040),新玩家讀成互相矛盾。

## 查證結果(lead-programmer 2026-11-12 實讀程式,依 ux 清單兩支修法擇一)

**「遮蔽」欄位綁定的是:游標所在那一格自己的地形是否擋視線(`Board.blocks_sight(cell)`),與「該格有沒有單位」「誰打誰」都無關。**
證據(原始查法,可重跑):
- `src/ui/battle/battle_screen.gd` `format_tile_info_concealment_line(blocks_sight: bool)`:`true` → `concealment_yes`、`false` → `concealment_no`,別無他物。
- `build_tile_info_text(..., blocks_sight, ...)` 第 3 行即此行;呼叫端傳入的 `blocks_sight` 來源為該格 `Board.blocks_sight()`
  (`src/gameplay/board/board.gd`:「flag lookup only」,以 `BLOCKS_SIGHT` 表查地形字元)。
- `assets/data/locales/strings.csv` 第 73、74 列:`battle.tile_info.concealment_yes/no` = 「遮蔽：是/否」。
- 設計文件 `design/gdd/tactical-combat-system.md` Core Rules #4 把「地形的遮蔽標記」定義為視線阻擋的唯一依據,
  即「遮蔽」在 GDD 內就是「擋視線」的術語。**欄位語意與「擋視線」一致,故採 ux 清單的第一支修法**(改名為「擋視線：是／否」),
  不需要第二支(另增獨立一行)。

**矛盾的真正成因**:「攻擊：視線被擋」是**攻擊者到目標連線途中某一格**擋住,而「遮蔽：否」描述的是**游標所在的目標格自己**。
兩者描述不同格子,卻用了兩個不同的詞(遮蔽/視線),玩家對不上。改成同一個詞「視線」後,字面上就看得出「這格不擋視線」與「途中別格擋了視線」是兩件事。

## Acceptance Criteria

- [ ] **AC1 文案**
      `assets/data/locales/strings.csv`:`battle.tile_info.concealment_yes` 值改為 `擋視線：是`、`battle.tile_info.concealment_no` 值改為 `擋視線：否`。
      **鍵名不改**(避免無謂的呼叫端與測試漣漪;鍵名與文案不一致的代價已在「未涵蓋」登記)。
      **不改** story-040 的 `attack_*` 五個鍵,**不加主詞**(管理者裁決)。`.csv` 為唯一合法的 `.csv`(翻譯表),改完走 `run_tests_with_import.sh`。
- [ ] **AC2 既有測試同步**
      `tests/integration/ui/battle_screen_tile_info_test.gd` 的三處字面斷言(`"遮蔽：是"` / `"遮蔽：否"`,約 101、102、150、166 行)改為新字面。
      交付前 `grep -rn "遮蔽：" tests src` 確認無殘留(命令寫在回報,不寫進註解內,避免自我命中——見 `coding-standards.md`)。
      `locale_data_integrity_test.gd` 的資料列數**不變**(只改值、不增列),實作者須確認仍綠。
- [ ] **AC3 兩行並讀不矛盾(可測的部分)**
      新增一條整合測試:對一個「敵兵站在開闊地、視線被灌木/倒木擋住」的真實 `BattleController` 情境(依 `technical-preferences.md` 第 5 點,注入合成資料、載入真實場景檔),
      斷言資訊卡文字同時含 `擋視線：否` 與 `攻擊：視線被擋`,且**不含**子字串 `遮蔽`。
      ⚠️ 這條斷言證明的是「兩行用同一個詞」,**不證明玩家讀得懂**,後者是 AC5。
- [ ] **AC4 敏感度證明**(🔴 一個 mutant 一次獨立執行)
      ①把 `concealment_no` 值改回「遮蔽：否」 → AC3 紅 ②把 `format_tile_info_concealment_line` 的 true/false 分支對調 → 既有 tile_info 測試紅。
      交付前掃描殘留注入標記。
- [ ] **AC5 像素層待補拍(非單元門檻)**
      1440×810 與 1920×1080 各一張游標停在被擋敵兵(兩行同屏),**960×540 一張**(單行不換行;目前 960 無有效截圖,驅動須真的讓游標落在目標格)。
      人開圖確認兩行並讀不矛盾。依截圖規則先判類別。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## 未涵蓋(刻意)

- 攻擊行加主語(管理者跳過)。
- 「擋視線：否」緊鄰「攻擊：視線被擋」時,玩家仍不知道**是哪一格**擋住 → 由 T5(story-044,被擋標記縮成角標並指向擋住的格)與 T8(圖例)處理。
- 鍵名 `concealment_*` 與新文案不一致 → 兩單落地後視需要另開清理單。
- 設計文件同步(GDD 內「遮蔽」術語與 UI 字樣不同)→ 協調者另行請示。

## Affected Files

- `assets/data/locales/strings.csv`(2 列的值)
- `tests/integration/ui/battle_screen_tile_info_test.gd`(字面斷言)
- 新測試檔:`tests/integration/ui/battle_screen_los_wording_test.gd`(AC3)
- (`battle_screen.gd` 預期**不需**修改;要動先問。)

超出此清單先問。

## 與其他工單的順序

與 T9(story-048,資訊卡框)同在資訊卡區但**不同檔**(本單只動 CSV 與測試),可與任一單並行;
與 story-043 之外的 `battle_screen.gd` 單互不衝突。
