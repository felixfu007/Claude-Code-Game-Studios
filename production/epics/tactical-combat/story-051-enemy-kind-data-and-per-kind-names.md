# Story 051: 敵方型別資料 + 依型別命名編號(裂殼 / 垂鉤 / 聽環)

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-13,三題皆已定,無待決)
> **Type**: Logic + UI(資料解析 + 顯示)
> **Estimate**: M+(約 2.5~3 天:解析 0.5、敵方顯示 + 規則 0.5、我方姓名併入與 3 處面板 0.5、名冊補欄 0.25、姓名鍵收斂 0.25、測試 0.75)
> **依據**:
> - 管理者 2026-11-13 裁決:敵方為怪物,名稱分種類,選項逐字「**裂殼 / 垂鉤 / 聽環(劇情總監推薦)**」,紀錄 `active.md`(當場查 `grep -n "裂殼 / 垂鉤 / 聽環" production/session-state/active.md`)。畫面稱呼格式與編號規則見 `design/narrative/enemy-monsters-concept-2026-11-13.md` 第六節 6.3、第七節 7.4(該檔標 Provisional,不影響此名稱已裁決)。
> - narrative-director 建議:型別由 roster 資料欄提供,不由程式用射程推算。

## 現況(2026-11-13 當場讀/grep)

- roster 欄位(`src/gameplay/units/unit.gd`):`id,code_name,faction,hp_max,atk,def,mp,min_range,max_range,start_x,start_y[,lone_guard]`,`FIELD_COUNT=11`、含 lone 旗標 12 欄;欄數不符 → `push_error` + `null` → 整份名冊「響亮地停」(2026-09-16 裁決)。
- 敵方 `code_name` 是 `E1~E5`;顯示編號由 `BattleScreen.enemy_number_from_code_name()` 剖 `E<N>`;字串鍵 `battle.tile_info.enemy_name_format,敵兵 %d`(`strings.csv:174`)。
- `assets/data/units/` 共 15 份名冊都有敵方列(`tut01~04` 4 份、`vs01~05` 5 份、`test_fixture_*` 6 份)；

## 設計

### 資料欄:加第 13 欄 `enemy_kind`(不另表、不改 `code_name`)

`...,start_y[,lone_guard[,enemy_kind]]`。`enemy_kind` 取值為資料鍵 `melee` / `mid` / `ranged`(英文小寫,對應 i18n 鍵 `battle.enemy_kind.<key>` = 裂殼 / 垂鉤 / 聽環)。
- **選第 13 欄的理由**:`lone_guard` 已是「選填後置欄」的前例;不改既有 11/12 欄列,既有 30 個測試檔內嵌列**零改動**(缺欄 = 無型別)。
- 敵方列要填 `enemy_kind` 而 `lone_guard` 為空時,第 12 欄留空(`...,10,0,,melee`);`lone_guard` 現行解析為 `== "1"`,空字串 = 否,**不需改**。
- **不採**「把型別塞進 `code_name`」(如 `裂殼1`):`code_name` 也流進攻擊確認面板與卡牌確認面板的文字(見顯示處),且 `tests` 與日誌引用它,塞中文會牽動極廣。
- **不採**另表(`enemy_kinds.txt` 以 id 對應):多一份要與名冊對得上的檔 = 多一個「兩份夾具互不相容、不報錯」的面(`technical-preferences.md` 2026-09-24 段)。

**欄數/驗證規則**(全部 `push_error` + 回 `null`,不用 `assert`):
- 欄數 11、12、13 皆合法;其他 → 照舊失敗。
- `enemy_kind` 非空但不在三個鍵內 → 失敗(整份名冊停,同既有格式)。
- **我方列帶 `enemy_kind` → 失敗**(防貼錯)。
- 敵方列缺 `enemy_kind`:**解析層允許**(保護 30 個內嵌測試),顯示層退回舊的「敵兵 %d」鍵(見待決題 2:是否保留此退回)。
- 🔴 **真實名冊的完整性由資料測試把關**:新測試讀 `assets/data/units/{tut01~04,vs01~05}_roster.txt`(版控唯讀固定資料,屬 `test-standards.md` 登記例外①,檔頭宣告 + 揭露「不證明窮盡」),斷言每個 ENEMY 列都有合法 `enemy_kind`。**這是「缺欄靜默退回舊名」唯一的防線。**

### 編號規則

`Unit` 新增 `enemy_kind: StringName`(空 = 無)與 `kind_ordinal: int`。`roster_from_text()` 在整份解析成功後做一次後處理:**同一 `enemy_kind` 的敵方,依名冊列順序給 1、2、…**(E1→裂殼 1,E5→裂殼 2;E2→垂鉤 1,E4→垂鉤 2;E3→聽環 1)。
- 好處:編號由資料順序決定,不依賴 E 編號、不依射程;調數值不會悄悄換名。
- 規則:**編號固定、不隨存活順序變**(同 story-039 既有 AC)。
- 每場名冊獨立編號(場內唯一即可)。

### 顯示處(皆已當場 grep;`grep -rn "enemy_name_format" src tests assets`、`grep -rn "敵兵" src tests assets`)

| # | 位置 | 現行 | 改為 |
|---|---|---|---|
| 1 | `battle_screen.gd` `format_tile_info_identity_line()`(~3216) | 「敵兵 N（敵方）」 | 「裂殼 1（敵方）」(`Loc` 取型別名 + 序號) |
| 2 | `battle_screen.gd` `piece_label_text()`(~3205)→ `board_view.gd` 棋子標記 | 敵方標記 = 編號數字 N | 型別內序號(AC4,取 `kind_ordinal`) |
| 3 | `battle_screen.gd:5268` 攻擊確認面板標題 `[attacker.code_name, target.code_name]` | 顯示 raw `E1` / `甲` | **敵方** → 型別名+序號;**我方** → 正式姓名(管理者裁決併入)。兩方皆走單一函式 `unit_display_name(unit)` |
| 4 | `battle_screen.gd:4315/4326` 卡牌確認面板目標文字 `target.code_name`(單目標 + 雙目標 `target_a/target_b`) | raw `E1`/`甲` | 同 #3 |
| 5 | `strings.csv:174` `enemy_name_format` | `敵兵 %d` | 改為 `%s %d` 形;新增 3 列 `battle.enemy_kind.melee/mid/ranged`(**列數 +3,連動 `locale_data_integrity_test.gd` 計數,當場取現值,沿用其 story-039 註解的做法**) |
| — | `battle_controller.gd` / `battle_loop.gd` 的 `log.append("... %s ...", code_name)` | 英文開發者日誌,內含 `code_name` | **不改**:這是除錯字串、不顯示給玩家(已 grep 無 UI 消費者);另 `commit_authoritative_change_version_test.gd:96` 斷言日誌含 `"E1"`,改了會白白紅 |

> 「戰鬥紀錄」:現行程式沒有玩家可見的戰鬥紀錄面板;`log` 為內部字串陣列。若管理者指的是未來的面板,屆時直接用本單的名稱函式。

名稱格式化抽成**單一出處的靜態函式**(例:`BattleScreen.enemy_display_name(kind, ordinal)`),#1、#3、#4 都呼叫它,**不得各自拼字串**(防多份實作漂移)。

### 測試影響

- 改:`tests/integration/ui/battle_screen_unit_name_and_piece_initials_test.gd`(斷言 `"敵兵 3（敵方）"` / `"敵兵 5（敵方）"`、`enemy_number_from_code_name` 系列、`piece_label_text` 斷言 `"4"` —— 隨設計改寫);`tests/unit/core/i18n/locale_data_integrity_test.gd`(列數 +3,依 Affected Files 授權);`tests/unit/gameplay/units/unit_test.gd`(新增 13 欄解析/拒絕案例)。
- 新:`tests/unit/gameplay/units/unit_enemy_kind_test.gd`(解析、編號、拒絕);`tests/unit/gameplay/units/roster_enemy_kind_integrity_test.gd`(真實名冊完整性)。
- **不動**:~30 個內嵌 `,ENEMY,` 列的測試檔(缺欄合法)。

## Acceptance Criteria

- [ ] **AC1 解析**:13 欄列解析出 `enemy_kind`;11/12 欄列行為與改動前逐字相同(既有 `unit_test.gd` 全綠不改斷言)。非法型別鍵、我方列帶型別 → 整份名冊失敗(`push_error`,回空陣列)。
- [ ] **AC2 編號**:vs01 名冊解出 E1→裂殼 1、E5→裂殼 2、E2→垂鉤 1、E4→垂鉤 2、E3→聽環 1;打亂名冊列順序,編號隨列順序變、不隨 `id` 變(證明資料驅動)。
- [ ] **AC3 顯示單一出處**:資訊卡、攻擊確認面板、卡牌確認面板的敵方名稱皆來自同一函式;測試對三處各斷言同一字串。
- [ ] **AC4 棋子標記(art-director 已定 (b))**:敵方棋子標記 = 型別內序號(1/2…),數字取自與 `unit_display_name` 同一出處的 `kind_ordinal`,**不得另算**(不依 `id`、不剖 `E<N>`)。**本單只斷言標記內容**;字框位置與大小沿用 story-041 現行函式(`piece_label_rect_in_cell()` 等,32 格座標)**不變**,不得在 32 格下斷言 48 格淨空區。測試:vs01 名冊 E1/E5/E2/E4/E3 的標記依序為 "1""2""1""2""1";缺 `enemy_kind` 的敵方退回舊行為(剖 `E<N>`)並斷言;我方標記(姓名首字)不變。
  - 📌 **48 格改造時的驗收項(不在本單)**:敵方標記字框須落在淨空區 格內 x=0~9、y=12~27(`design/art/enemy-embryo-piece-spec-2026-11-13.md` 第五節;棋子 48×60)。48 格改造延到大地圖捲動一起做,見 `docs/reviews/big-map-scroll-requirements-2026-11-12.md`(僅在此註明,該檔不改)。
- [ ] **AC5 真實名冊完整性**:`tut01~04`、`vs01~05` 每個 ENEMY 列皆有合法 `enemy_kind`;防空洞:斷言掃到的 ENEMY 列總數 == 檔案實際數(當場數,不寫死)。檔頭宣告資料檔讀取例外與「不證明窮盡」。
- [ ] **AC6 敏感度證明**(🔴 一個 mutant 一次獨立執行):①編號改依 `id` → AC2 紅 ②某真實名冊刪一個 `enemy_kind` → AC5 紅 ③#3 敵方改回 `code_name` → AC3 紅 ④#3 我方改回 `code_name` → AC8 紅。交付前掃描殘留注入標記。
- [ ] **AC7 像素層待補拍**:960×540、1920×1080 各一張游標停在不同型別敵兵;人開圖確認資訊卡全名與棋子序號標記一致(同型兩隻可分辨)、標記未截字(32 格下不驗淨空區)。依截圖規則判類別。
- [ ] **AC8 我方姓名**:攻擊確認面板標題、卡牌確認面板(單/雙目標)中的我方單位顯示正式姓名(如「藍亭萱」),不再出現 `甲`~`戊`;測試對甲、乙各斷言姓名字串且**不含**代號;與資訊卡同一函式。
- [ ] **AC9 姓名鍵收斂**(見「姓名鍵收斂判斷」):`Loc.character_name(id)` 為唯一出處;`character.name.%d` 的格式字串在 `src/` 只剩 `loc.gd` 一處。驗證指令(不得寫進被掃檔註解):`grep -rn "character.name." src --include=*.gd | grep -v "^src/core/i18n/loc.gd"` 應為 0 行。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行;`strings.csv` 改動後必走此入口(匯入快取假綠燈)。

## 未涵蓋(刻意)

- 敵方棋子美術(圖)與徽章 —— art-director / 美術另案。
- 心魔變體稱呼(「某某的心魔」,概念檔題 5)—— 未決,不做。
- 日誌字串、`code_name` 欄本身(`E1~E5` 保留,仍是名冊內部識別)。
- 修改 roster 檔頭「追兵/集團」敘事註解(level-designer / narrative-director,概念檔 6.4)。

## Affected Files

- `src/gameplay/units/unit.gd`(第 13 欄、`enemy_kind`/`kind_ordinal`、後處理)
- `src/ui/battle/battle_screen.gd`(#1~#4、單一名稱函式 `unit_display_name`、`player_display_name` 改呼叫 Loc、:5445 倒下者姓名)
- `src/core/i18n/loc.gd`(新增 `character_name(id)`)
- `src/ui/battle/relation_minimap.gd`、`src/ui/shell/support_conversation_screen.gd`(僅把姓名鍵拼接改呼叫 `Loc.character_name`,**行為不變**)
- `src/ui/battle/board_view.gd`(敵方標記改取 `kind_ordinal`、字框位置沿用 041 不變)
- `assets/data/locales/strings.csv`(改 `enemy_name_format`、增 3 列)
- `assets/data/units/{tut01~04,vs01~05}_roster.txt`(敵方列補第 13 欄;**不改資料數值**;test_fixture 名冊可不動)
- 既有測試:`battle_screen_unit_name_and_piece_initials_test.gd`、`locale_data_integrity_test.gd`、`unit_test.gd`、`tests/integration/ui/attack_confirm_panel_test.gd`(傳入 `"甲"`/`"E1"` 處約 11 行 code_name 引用)、`tests/integration/ui/card_confirm_panel_test.gd`(斷言 `contains(unit_1.code_name)` 等,改斷言姓名)
- 新測試兩檔(見上)

超出此清單先問。

## 與其他工單的順序

- **與 story-048(資訊卡改造)**:048 改資訊卡矩形/底/框,本單改資訊卡**文字內容**,兩者同動 `battle_screen.gd` 資訊卡區段 → **序列做,048 先**(048 已 Ready),本單後;名稱變長(「垂鉤 1（敵方）」比「敵兵 1（敵方）」多 0~1 字)不改變寬度預算,但 048 的位置不變式測試以新名稱再跑一次。
- **與 story-049**:無檔案交集。
- **與敵方棋子美術**:**本單不依賴美術**(標記是 Label 疊在棋子圖上,無圖照樣運作)。美術晚到只影響待決題 1 的最終選擇(若棋子剪影夠辨識,標記可降級)。建議**本單先做、美術後補**,但待決題 1 要在 AC7 截圖前定案。
- 與 story-050:同動 `strings.csv`(不同列)→ 序列合併,050 先。

## 待決題目(2026-11-13 更新)

- **題 1(棋子標記)**:已由 art-director 定 (b) 型別內序號;型別由剪影與資訊卡全名讀出,(c) 約 19px 超出淨空區。見 AC4。
- **題 2(缺 `enemy_kind`)**:已採 (a) 退回舊「敵兵 N」,由 AC5 完整性測試把關(技術面,協調者採用,未問管理者)。
- **題 3(確認面板我方顯示甲乙)**:🔴 管理者裁決選項逐字「**一起改,我方也改成姓名**」,**併入本單**(見上方顯示處表 #3、#4 與 AC8)。

## 姓名鍵收斂判斷(回覆協調者)

**判斷:可以、建議在本單一併完成,理由與界線如下。**
- 現況 4 處各自拼 `character.name.%d`:`battle_screen.gd`(`player_display_name` 與 :5445 倒下者名單)、`relation_minimap.gd:22`(`NAME_KEY_FORMAT`)、`support_conversation_screen.gd:34`(`SPEAKER_NAME_KEY_FORMAT`)。本單**必須**新增我方姓名單一函式(AC8),不收斂就會變成第 5 份拼接。
- 做法:`Loc` 加 `static func character_name(id: int) -> String`(內部 `localize(StringName("character.name.%d" % id))`);4 處改呼叫。**純機械替換、行為不變**,既有 minimap 與對話畫面測試是保護網(不改它們的斷言;若有斷言要改,表示替換不是機械的,停下回報)。
- 界線:只收斂「姓名鍵拼接」,**不動** minimap/對話畫面的其他邏輯;跨到 `shell` 與 `minimap` 兩個檔屬本單授權範圍(已列 Affected Files)。
- 風險低、增量約 0.25 天;若覺得動到對話畫面不放心,可降為「battle_screen 內 2 處 + Loc 函式,其餘 2 處另單」,AC9 改為「src 內只剩 minimap/shell 兩處未收斂,已登記」。
