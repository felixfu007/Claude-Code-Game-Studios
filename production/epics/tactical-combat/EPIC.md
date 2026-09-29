# Epic: 戰棋移動與交戰系統(#4 Tactical Combat)

> **Layer**: Gameplay(`systems-index.md` 分類;依 `/create-epics` 四層模型對應 Core→Feature 交界)
> **GDD**: `design/gdd/tactical-combat-system.md`(Approved 2026-08-31)
> **UX Spec**: `design/ux/tactical-combat-screen.md`(2026-09-29)
> 🔴 **實作 story 一律引用 UX spec,不得直接引用 GDD** —— `systems-index.md` #4 列的 UX Flag 明文要求。
> **Architecture Module**: 戰棋查詢核心(`src/gameplay/board`、`src/gameplay/battle`)+ 戰棋呈現層(`src/ui/battle`)
> ⚠️ **這格的名稱為本 epic 自行命名,自訂而非取自架構文件,沒有上游出處。**
> `/create-epics` Step 2b 要求從
> `docs/architecture/architecture.md` 取模組歸屬,但**該檔不存在** —— 本專案從未跑過
> `/create-architecture`(與 2026-08-25 流程劑量裁決一致,非疏失)。上面的名稱是依
> `src/` 目錄結構自訂,**不要當成有出處的既有模組名去別處對照。**
> **Status**: ✅ **Ready — 2026-09-29 管理者裁決,可執行 `/create-stories`**(前為 `Draft`)。<br>依據:`docs/reviews/pr-epic-tactical-combat-2026-09-29.md` 判 CONCERNS 並列五項必辦,該報告第六節標題明文「**寫 story 之前**必須調整的事項」——五項擋的是 `/create-stories`,不是本檔狀態,且明文「五項調整全部是**定點修正**,不需要拆 epic、不需要重排」(未要求重跑閘門)。五項現況:**C1/C3 已修**(`technical-director`)、**C2 由 2026-09-29 裁決一關閉**(M6 三份重複實作收斂 ADR-0005)、**C5 擁有者已指派**(期限綁 story 不綁日期)、**C4 由 `production/epics/affinity-position-chain/EPIC.md` 的建立關閉**(2026-09-29 同日)。
> **Review Mode**: `full`(第六十七批管理者裁決五:本 epic 恢復覆核,理由為 #4 被六個系統依賴)
> **Stories**: 尚未切分 — 閘門通過後執行 `/create-stories tactical-combat`

## Overview

本 epic 把 #4 戰棋移動與交戰系統從「2026-08-28 那批『先讓它動』的可跑原型」推進到
「經過 GDD 與 UX 規格審查、可驗收」的版本。涵蓋三件事:①棋盤查詢核心補齊 GDD 公式三
已定案但程式未落地的參數(`passable`、`ignore_occupancy`、`ignore_passability`);
②查詢介面補齊呈現層需要但目前查不到的切面(不可達成因、視線擋、單位行動四態、
基準值 vs 有效值);③呈現層與介面層把 UX 規格標記的 2 項「規格要求改動現行實作」
與 6 項「尚未實作」補上。**外加一項治理性工作**:把一般移動/攻擊路徑的游標接進
ADR-0005 的游標系統 —— ✅ **2026-09-29 管理者裁決已選「全部收成一份」**,
這不再是待決選項,是已定案的實作範圍(見 M6 節與「A3 查證結果」節)。

## 🔴 這不是從零開工 —— 本 epic 的實際形狀

`#4` 的程式碼已經在跑。現況規模(2026-09-29 實測):

```
$ find src/gameplay src/ui/battle -name "*.gd" | xargs wc -l | sort -rn | head -8
  2702 src/ui/battle/battle_screen.gd
  1125 src/gameplay/battle/battle_controller.gd
   635 src/ui/battle/board_view.gd
   465 src/gameplay/battle/battle_state.gd
   308 src/gameplay/battle/battle_loop.gd
   192 src/gameplay/battle/turn_order.gd
   166 src/gameplay/board/board.gd
    95 src/gameplay/board/line_of_sight.gd
```

**多數 story 是替換 / 補齊 / 接線,不是新建。** 只有兩個面板(格位資訊面板、
攻擊確認面板)與一個高亮層集合是真正的新檔案。切 story 時若照「從零建一個系統」
的形狀切(先資料層、再邏輯層、再 UI),會切出一批實際上是「讀懂現況 → 改三行 → 補測試」
的工作單,估時與依賴序都會錯。

⚠️ **連帶的紀律要求**:UX 規格全篇以「現況證據 + 落差」的形式寫成,且**自陳多處
「未核對」**。凡 story 的第一步是「核對現況」的,不得把 UX 規格的描述當成現況事實引用
—— 規格自己說了它沒讀那段程式碼。

---

## Scope(**五個模組**:M2~M6。M1 已移出 epic,見下)

> 模組是 story 的分群邊界,不是檔案邊界。每個模組一句話範圍 + 主要改動檔案 + 新建/替換比重。

### 〔前置,不是模組〕M1 — 限時現況查證批

> 🔴 **2026-09-29 `PR-EPIC` 閘門 C3:M1 不列為本 epic 的第六個模組,改列為 epic 之前的
> 前置查證,與 `/create-stories` 分開執行。**
>
> **閘門的理由是邏輯上的,不是偏好**:本檔自己說 M1 的答案「決定 M3/M4/M5/M6 的 story 數
> 與大小」——**那就不可能與 M3~M6 在同一次 `/create-stories` 裡被正確切出來。**
>
> ⏱ **上限:1 個開發日,8 項全數回答。**
> **逾時處置**:未答項**明文降級**為「該模組第一張 story 的第一步」,**不得無限延長**。
> (依據:一年計畫第六節②劑量規則的同一精神 —— 查證有價值,問題是劑量。)
>
> 📄 **產出是一份查證報告。M2~M6 的 story 在該報告存在之後才切**
> ——`/create-stories tactical-combat` 的前置條件之一。

**範圍**:把 UX 規格自陳「未核對」的八項逐項查證,每項產出「已滿足 / 有缺口 + 缺口形狀」
的結論與原始輸出,不做實作。

| UX OQ | 要查什麼 | 為何非查不可 |
|---|---|---|
| U-T4 | `battle_controller`/`turn_order` 是否已有「不選取也能查任一單位四態」的 getter | 沒有的話 M2 要補,M3 的行動旗標指示才有資料源 |
| U-T5 | `render_pieces()` 是否有陣亡淡出過渡 | 決定 M3 要不要多一張 story |
| U-T6 | `_input()` 對 T3 敵方回合的拒絕是否逐幀生效 | 決定 M6 要不要補閘門 |
| U-T7 | `click_tile()` 的 `{"action":"none"}` 回傳是否觸發可辨識拒絕回饋(`P-F2`) | 目前可能是「回傳一個被忽略的 Dictionary」= 靜默 |
| U-T8 | 「結束該單位行動」的輸入路徑 | 若不存在,違反 `P-I2`(無滑鼠路徑);`end_unit_turn(id)` 存在但呼叫端未知 |
| U-T10 | Tab/RB 跳轉排序是否決定性且有測試釘死 | GDD UI Requirements §3 硬性要求 |
| U-T11 | `TEXT_*` 常數是否走本地化管線 | 影響兩個新面板的文字寫法,做完再改成本高 |
| U-T12 | `_apply_attack()`/`_apply_move()` 是否單幀同步完成 | 決定 AC-24 的重入窗口寬度是否為零、M6 要不要補閘門 |

**性質**:全部是替換/核對,零新建。**輸出是文件與測試,不是功能。**
🔴 **這批的價值是讓 M3~M6 的估時建立在事實上** —— 現在它們建立在「規格說它沒讀」上面。

⚠️ **逾時降級後仍要留痕**:降級的項目要寫進接手模組第一張 story 的敘述,
**不是默默不查了**。八項裡任何一項沒有答案而 story 照切,就是拿「規格說它沒讀」當事實用
—— 那正是風險 R6。

### M2 — 棋盤資料與可達性核心(`src/gameplay/board/`)

**範圍**:把 GDD 公式三已定案、程式零落地的三個東西寫進 `board.gd` ——
`passable` 地形旗標、`reachable_tiles()` 的 `ignore_occupancy` / `ignore_passability`
兩個獨立開關(四種布林組合皆須良定義)、以及 OQ-16 要求的**有界前緣展開**
(不得「全盤展開後過濾」)。

**現況**(2026-09-29 實測):
```
$ grep -c "passable" src/gameplay/board/board.gd
0
$ grep -n "func reachable_tiles" src/gameplay/board/board.gd
106:func reachable_tiles(origin: Vector2i, mp: int) -> Array[Vector2i]:
```
兩個開關都不存在,`passable` 概念不存在。

🔴 **切這張 story 前必讀 GDD OQ-10 關閉記錄裡的實作期靜默陷阱警語。** 本 epic 另行實測到
陷阱的確切位置:
```
$ sed -n '69,71p' src/gameplay/board/board.gd
func get_move_cost(pos: Vector2i) -> int:
	var terrain: String = get_terrain(pos)
	return MOVE_COST.get(terrain, MOVE_COST[TERRAIN_OPEN])
```
**未登記的地形字元會靜默取得平地成本,不報錯、不回傳哨兵值。** 新增 `passable` 欄位時
若資料表與 `MOVE_COST` 沒同步,新地形會同時「成本當平地」且「`passable` 取預設 `true`」
—— 一面牆會變成一片可以走過去的空地,而且畫面上看起來完全正常。

✅ **關卡地形檔的表達方式已定,不是未決項**(GDD Tuning Knobs #4;本 epic 初版誤列為「未決」,
2026-09-29 查證後更正)。逐字依據:

> 未來新增牆壁/水域/懸崖等不可通行地形時,**只需在本表新增一列並將該欄設為 `false`**,
> 不需要新增地形「階層」,也不需要用極大成本模擬

**對實作的三個直接後果**:
1. **單層 ASCII 不變**,`Board.from_ascii(rows: PackedStringArray)` **簽章不用動**
   —— 不需要第二個字元平面、不需要另一個檔案。
2. `passable` 走**地形字元查表**取得,與 `terrain_cost` 同一張表的第二欄。
3. **`passable=false` 的地形其 `terrain_cost` 永不生效,但資料層仍須填一個合法值**
   (建議沿用平地的 `1`)當佔位,以免留空造成驗證歧義 —— GDD 同節明文
   (`grep -n "永不生效" design/gdd/tactical-combat-system.md` → 命中 1 處)。

🔴 **這一條與上方的靜默陷阱是同一件事的兩面**:表新增一列時,`MOVE_COST` 與 `passable`
兩欄**必須同批加**。只加後者、前者漏了,就落回 `get_move_cost()` 的平地 fallback,
而那不會報錯。

**比重**:替換為主(`reachable_tiles()` 改簽章 + 改演算法)、資料表擴欄為新增。
**下游**:M3 的三個切面、M4 的四態高亮、M5 的第四態貼圖,全部等這裡。

### M3 — 戰鬥查詢介面層(`battle_controller.gd` / `battle_state.gd` / `turn_order.gd`)

**範圍**:補齊呈現層需要、但目前**查不到**的五組切面。

1. **移動範圍三切面**(可達 `A` / 不可達-移動力不足 / 不可達-被佔位擋死)+ **第四態**
   (地形不可通行)。GDD AC-13 要求四類互斥且窮盡、聯集等於整張棋盤。介面形狀
   (三個方法 vs 一個回傳多切面的結構)由本模組定案,UX 規格只定案「三個切面必須都查得到」。
2. **「射程內但視線被擋」查詢**——現況 `_attack_targets_for()` 只回最終合法集合,
   第三層無資料源(GDD Visual/Audio §1.3)。
3. **單位行動四態 getter**(U-T4 若查證為「不存在」)。
4. **`threat_targets()` 語意釐清**(U-T15)——UX 規格判定這是「最需要優先釐清的技術假設
   落差之一」:現況命名是威脅範圍,實際可能回傳「選取單位自身的攻擊延伸」,
   與 GDD UI Requirements §1a 要求的「敵方威脅範圍疊加圖 + 逐敵拆分」不是同一件事。
   **可能是同一份程式碼被雙重期待。**
5. **`ATK` / `DEF` / `Φ` 拆解查詢** + **基準值 vs 有效值存取層**(#6 卡牌系統登記的反向依賴,
   管理者已許可)。現況只有合併後的 `preview_damage()` 單一整數。

🔴 **本模組全程受 ADR-0001(戰棋查詢原子性契約)管轄** —— 新增的每一個查詢都要落在
單一快照原子性與 `combat_state_version` 的既有規則內,不得繞過。
**比重**:補齊為主,無新檔案。

### M4 — 世界層呈現(`src/ui/battle/board_view.gd`)

**範圍**:把 M2/M3 新查得到的東西畫出來 —— 移動範圍三態 + 第四態、攻擊範圍三層、
單位行動旗標的持久非色彩標記、不可通行地形的呈現。

🔴 **`P-F3`(非色彩通道)無例外**,且必須延續現有手法(`THREAT_HIGHLIGHT_PATH` 的
「環狀 vs 實心」)而非另創一套。全部新增層須通過灰階複驗,比照 `skill-card-play.md`
HP 對比度修復批次的既有紀律。
**比重**:新增圖層為主(比照既有 `StatsLayer` 的作法),`board_view.gd` 現有繪製路徑不動。

### M5 — 介面層兩個面板(`src/ui/battle/` 新檔 + `battle_screen.gd`)

**範圍**:兩個 UX 規格明文要求、目前不存在的面板。

- **格位資訊面板**(GDD UI Requirements §1)——UX 規格稱之為「本畫面目前最大的 GDD
  未涵蓋項」。最小欄位:地形種類、`terrain_cost`、遮蔽旗標、佔位單位陣營/HP/當前行動旗標
  狀態、武器分層 `(min,max)`、當前 MP。現況 `_info_label` 是三選一的窄版摘要,不是這個。
- **攻擊確認面板**(GDD UI Requirements §4,T2' 新狀態)——**這是本 epic 唯一一項
  改變既有互動語意的工作**:`_confirm_at_cursor()` 目前一鍵直達結算
  (`battle_screen.gd:2288` → `click_tile()` → `battle_controller.gd:560` → `_apply_attack()`),
  要拆成「第一次確認開面板(零寫入)/ 面板上再次確認才寫入」兩段。
  🔴 **不得與預判元件共用**(`P-M2`)。🔴 **移動維持單鍵直接執行,不加面板** ——
  UX 規格 7.2 已明文判定,不要「順手也給移動加一個」。

🔴 **兩條隨面板落地生效的既有紀律,不是新規則**:①裁定狀態必須在
`_process(priority=100)` 讀,不得在按鍵處理常式內讀(否則讀到上一幀值,`skill-card-play.md`
已記載過同一個錯誤);②鍵盤+手把同幀各送一次確認的去重保護。
**比重**:兩個新檔案 + `battle_screen.gd` 的 `_confirm_at_cursor()` 拆段。

### M6 — 游標系統接線與輸入缺口(`battle_screen.gd` + ADR-0005 邊界)

> ✅ **2026-09-29 管理者裁決:選 (甲) —— 全部收成一份。** 逐字選項為「**全部收成一份**」。
> 被跳過的是「明文保留兩份,登記為已知重複」與「只收『滑鼠 vs 手把誰說了算』那一份」。
> 🔴 **管理者是在看過「選(乙)會讓 GDD line 644 在移動/攻擊路徑上永久無法滿足」這句代價
> 之後選的(甲)** —— 該句由協調者依本檔「A3 查證結果」節的發現補進選項表代價欄。
> **這是知情下的選擇,不是預設值。**
>
> **連帶效果**:M6 **不再是外部阻塞點**,而是已定案的實作範圍。依賴圖上原本唯一的
> 「等裁決」節點消失,**M5 不必再等**(見下方「依賴與實作順序」節已重畫的圖)。

**範圍**:①**依上述裁決,把三處重複全部收斂到 ADR-0005 那一份**;
②補查證批查出的輸入缺口(U-T6 敵方回合拒絕、U-T7 拒絕回饋、U-T8 結束單位行動路徑)。

**①的三處重複,逐處對應的收斂目標**(每一處的現況證據見下方「A3 查證結果」節):

| # | 現況的那一份 | 收斂到 | 落地形狀 |
|---|---|---|---|
| 1 | **游標導航** —— `battle_screen._handle_directional()` → `clamp_cursor_move()`(`battle_screen.gd:1206`)→ 直寫 `_cursor_cell` | `CursorState.apply_buffered_navigation()`(`cursor_state.gd:534`),經 `CursorStateHost` | 一般移動/攻擊路徑須註冊 `BOARD_TILE` surface(目前只有打牌路徑註冊);`_cursor_cell` 的 4 個寫入點改為讀 `CursorStateHost.get_current_target()` |
| 2 | **裝置權威** —— `battle_screen.gd:941` 自行 `DeviceAuthority.new()`,靠約 15 處手動 `note_pad_input()`/`note_mouse_motion()` 餵資料 | `CursorState.arbitrate_device_authority()`(由 `cursor_state_host.gd:391` 以引擎事件流自動驅動) | `src/ui/battle/device_authority.gd`(116 行)預期整份退役;15 處手動呼叫全部移除 |
| 3 | **方向鍵去抖** —— `battle_screen._direction_just_pressed()` 自維護 pressed-state Dictionary | ADR-0005 的 `InputEventKey.echo` 過濾(`cursor_types.gd:165`) | ⚠️ **兩者解決同一問題但手法不同,語意未必等價** —— 收斂前必須先確認 echo 過濾涵蓋「手把類比搖桿長按」(Dictionary 那份明文是為它寫的),否則會收掉一個還在用的行為 |

🔴 **收斂的順序是「先接線、再退役」,不是反過來。** 第 2 項的 `device_authority.gd` 退役
必須排在第 1 項接線驗證通過之後 —— 現況 `_update_cursor_visual()`(`battle_screen.gd:2417`)
以 `_device.current()` 決定游標走滑鼠座標還是走 `_cursor_cell`,**先拆裝置權威會讓游標
當場沒有來源**。

⚠️ **裁決給的是方向,不是免除驗證。** (甲)的已知代價原文即列明:「ADR-0005 的有效性旗標
語意會**首次**套用到移動/攻擊路徑,**可能暴露既有行為差異**」。收斂後的第一件事是跑完整
回歸,把差異當成發現而非退步 —— **今天兩條路徑時間上互斥,所以沒有任何既有測試在比較它們。**

🔴 **本模組的硬性驗收條件:不得破壞 ADR-0005 已落地的兩條義務。**
那兩條(游標圖層獨佔 `CanvasLayer`、自行過濾 `InputEventKey.echo`)屬 #3 游標系統、
**已在 #3 的程式碼落地並有測試釘住**,#4 不需要重做:
```
$ grep -rn "\.echo" src/
src/ui/cursor/cursor_types.gd:165:	if event is InputEventKey and (event as InputEventKey).echo:
$ grep -n "_cursor_layer" src/ui/cursor/cursor_state_host.gd | head -2
198:var _cursor_layer: CanvasLayer
```
外加 `tests/unit/cursor/cursor_layer_transform_test.gd` 已釘住圖層變換恆等。
**#4 在本模組動輸入路徑時,這兩條是回歸測試必須維持綠燈的項目,而非要新寫的功能。**

---

## Out of Scope(附理由)

| 不做 | 理由 | 誰擁有 |
|---|---|---|
| **戰鬥 HUD 的面板排版** | GDD OQ-6 明文指給 #10。本 epic 的兩個面板(格位資訊、攻擊確認)與 #10 未來的面板**可能有版面重疊或元件重用機會**,UX 規格 U-T13 已登記此邊界,由下一輪核對決定,本 epic 不自行擴大 | #10 戰鬥 HUD |
| **回合層級剩餘旗標總覽(`P-D4`)、傷害拆解面板最終版面優先序、好感度逐條貢獻面板** | 同上,GDD OQ-6 三項皆明文歸屬 #10 | #10 戰鬥 HUD |
| **打牌流程本身(S1~S4)** | 已有 `design/ux/skill-card-play.md` 與 18 張完成的 story。本 epic 只在 T1/T2 與 T5 的**邊界**上動刀(見 M6),不重做打牌 | #6 技能卡牌系統(已完成) |
| **`Φ_max` 與 `enemy_advantage_pct` 的交叉校準(OQ-1)** | 屬 #5 好感度—位置連鎖系統,且待首次可玩建置才測得準 | #5 |
| **`amp` 量化(OQ-3)** | 屬 #14 | #14 |
| **音效資產本體(OQ-7/8)** | 本 epic 只定義「拒絕音必須與靜默明確不同」,不定義它聽起來怎樣 | `audio-*` |
| **正式美術資產的取得路線(OQ-5)** | ✅ **2026-09-29 管理者裁決:M4 照常用 placeholder 推進,不阻塞。** 正式美術的取得方式是**獨立議題**,選項書已產出:`design/art/art-production-paths-2026-09-29.md`。⚠️ **不要把這一列讀成「交給 `art-director` 平行處理就會有圖」** —— 見下方說明 | `art-director`(追蹤於該選項書) |

🔴 **關於美術這一列,有一項前提在 2026-09-29 被推翻,必須寫下來:**
`design/art/art-direction.md` 寫的是「像素風、**開發者本人繪製**、不外包不用素材庫」,
本 epic 初版據此把美術當成「同一個人的同一段行事曆」而判它是 M4 的隱藏阻塞項。
**管理者 2026-09-29 告知:他本人不會畫圖。** 亦即**美術方向文件寫的生產方式本身不成立**,
這已超出本 epic 範圍、另行處理中。

**對 M4 的實際影響:零阻塞,但要正確理解「零阻塞」是什麼意思。**
現況 `assets/art/` 底下**只有 `placeholder/`,一張正式圖都沒有**(`ls assets/art/` → `placeholder`)。
M4 以 placeholder 推進,驗收的是**形狀與非色彩通道是否成立**(環狀 vs 實心、圖示、邊框),
**不是美術品質**。**換成正式資產時會再過一次灰階複驗** —— 那一輪不屬本 epic。
| **已確認行動的 undo(OQ-11)** | 牽涉回合模型與存檔互動,GDD 明文「不在本系統範圍」 | 使用者 + #2 存檔系統 |
| **待 playtest 才有答案的項(OQ-13/14/18)、OQ-15/16/17、OQ-20/21** | 見下方「Open Questions 現況」節,一律引用不重新盤點 | 見該表 |
| **戰鬥中途地形改變的重新計算時機** | GDD Edge Cases 明文「本系統目前不定義行為」,留待 #14 設計時雙方共同確認。⚠️ `passable` 的動態改變風險高於 `terrain_cost`(可能打破「`passable(origin)` 恆為 true」的隱性不變量),但**那是 #14 要回頭補的,不是本 epic** | #14 活棋盤地形演變 |
| **停損門檻數字(A6)** | 期限已算出 = 2027-01-28,**數字本身是管理者獨有的裁決**。不擋建 epic,本 epic 不試圖解它 | 管理者 |
| **是否移交 `/create-architecture`** | `systems-index.md` #4 列明文:原本擋住它的理由已消失,但「是否移交是管理者裁決,尚未進行」。本 epic 不代為宣告 | 管理者 |

⚠️ **一項刻意留在範圍內、但容易被誤判為 Out of Scope 的**:UX 規格 U-T1(攻擊確認面板
是否需要把 `click_tile()`/`_apply_attack()` 拆成 propose/commit 兩段)。它看起來像架構決策,
但 UX 規格已定案「必須有二段確認」,**只剩介面形狀未定**——那是 M5 的第一張 story
要決定的事,不是另開一份 ADR 的理由(依劑量規則 3:單一系統內部技術細節寫在設計文件裡)。

---

## 依賴與實作順序

> 🔴 **本節於 2026-09-29 依 `PR-EPIC` 閘門 C1 重寫。** 原文寫「M4 與 M5 可並行」,
> 而同一份檔案的風險 R4 寫「M4/M5/M6 對 `battle_screen.gd` 序列化,不要並行」——
> **兩句直接互相否定**,而 `/create-stories` 會把本節文字直接翻成 story 的 `Depends On` 欄。
> 照原文切出來的 story 會宣告 M4/M5 無依賴關係,**而它們改同一個 2702 行的檔案。**

### 🔴 規劃層與執行層是兩件事,原文把它們混為一談

- **規劃層(產出依賴)**:**M4 與 M5 的產出互不依賴** —— 世界層高亮與介面層面板
  沒有任何一方需要另一方的輸出。**規劃上可並行。**
- **執行層(檔案衝突)**:**M4 / M5 / M6 三者共用 `battle_screen.gd`(2702 行),
  執行上必須序列化,不得並行。**

**兩層都要寫進 story**:`Depends On` 欄記規劃層依賴,另以明文順序記執行層序列化。
只寫一層就會重演本節原本的矛盾。

### 順序圖(取代原圖;採閘門報告第 3-4 節)

```
第 0 步(epic 之前)  M1 查證批 ── 限時 1 個開發日,產出是文件與測試
                          │
        ┌─────────────────┴─────────────────┐
        ↓ 工作線 A                          ↓ 工作線 B(第一天即可開)
   M2 棋盤核心                        M3 切面 2/3/4/5
   (src/gameplay/board/)              (src/gameplay/battle/)
        └─────────────────┬─────────────────┘
                          ↓
                   M3 切面 1(移動範圍四態)
                          ↓
        ┌─────────────────┴─────────────────┐
        ↓                                   ↓
   M4 世界層呈現  ←─ 序列化 ─→  M5 面板  ←─ 序列化 ─→  M6 輸入
        └──────── 三者共用 battle_screen.gd,不得並行 ────────┘
```

🔴 **兩條工作線的切點是第一天,不是 M3 完成之後。** 原文寫「切點在 M3 完成之後」是錯的
—— 閘門實測 **M2(`src/gameplay/board/`)與 M3 切面 2/3/4/5(`src/gameplay/battle/`)
跨目錄、無檔案衝突**,第一天就能各開一條。
**只有 M3 的切面 1(移動範圍四態)真的等 M2** —— 因為只有它吃 `passable` 與兩個 ignore 開關。
亦即「M2→M3 不可壓縮」**只對五分之一成立**。

### 執行層序列化的先後:**M6 → M5 → M4**

| 序 | 模組 | 為什麼排這裡 |
|---|---|---|
| 1 | **M6 輸入** | **輸入語意先定。** 游標三處重複收斂完,`_cursor_cell` 的讀寫語意才固定;M5 的面板要讀「裁定後的狀態」,讀的是哪一份必須在它動工前就是唯一解 |
| 2 | **M5 面板** | **面板再接。** 兩個面板都掛在 `battle_screen.gd` 的互動狀態機上,狀態機由 M6 定型 |
| 3 | **M4 繪製** | **最後才是繪製傳參。** M4 對 `battle_screen.gd` 的改動最輕(`_refresh_view()` 多傳幾個參數),放最後受前兩者影響最小 |

**這三個序號要寫進 story 的執行順序欄。** 規劃層的 `Depends On` 則是:
M4 ← M3 切面 1;M5 ← M3 切面 1 + M3 切面 5;M6 ← M1(U-T6/7/8)。

✅ **M6 不再是外部阻塞點** —— 2026-09-29 管理者裁決已選 (甲) 全部收成一份(見 M6 節)。
原文此處的「若裁決遲遲不下,先做格位資訊面板」整段**已失效並刪除**,不要再照它排程。

---

## Governing ADRs

| ADR | 狀態(實測) | 對本 epic 的管轄範圍 | Engine Risk |
|---|---|---|---|
| **ADR-0001** 戰棋查詢介面原子性契約 | ✅ **Accepted**(2026-09-01 管理者裁決)· 第一次修訂 2026-09-09(擴大契約管轄範圍、計數器改名 `combat_state_version` 並移交 `BattleState`、寫入路徑補齊至六條 mutator、新增寫入守衛) | **M3 全部五組新查詢**、M2 的 `reachable_tiles()` 改簽章。單一快照原子性、查詢組不得跨版本混用 | **HIGH**(Godot 4.7 為 LLM 訓練截止後發布)——但本 ADR 所依賴的具體引擎事實已於 2026-08-18 由 `godot-specialist` 對照 engine-reference 逐項查核通過 |
| **ADR-0005** 單一游標/高亮狀態系統:裝置權威輸入架構 | ✅ **Accepted**(2026-09-01 管理者裁決) | **M6 全部**、M5 的輸入讀取時機。兩條硬性義務(游標圖層獨佔 `CanvasLayer`、自行過濾 `InputEventKey.echo`)**已在 #3 落地**,本 epic 的責任是接線時不破壞它們 | 同上 |

**不管轄本 epic 的已核准 ADR**:ADR-0002(好感度數值池)僅在 `Φ` 取值處交界,介面已穩定;
ADR-0003(存檔序列化)與 ADR-0004(存檔原子寫入,仍 `Proposed`)與本 epic 無交集。

🔴 **本 epic 預期不產生新的 ADR。** 依 2026-08-25 劑量裁決規則 3(架構文件只在跨系統契約時才寫)
與 `coding-standards.md` 2026-09-01 改寫,剩下 6 個系統預期只再產生 0~1 份新 ADR。
本 epic 唯一可能觸及跨系統契約的是 **M3 的「基準值 vs 有效值存取層」(#6 反向依賴)** ——
但那是 #6 已經登記、管理者已許可的既有契約,**補實作不等於補 ADR**。
**若 `/create-stories` 或實作期有人主張要開 ADR-0006,請先回到這一行。**

---

## 已知風險

| # | 風險 | 形狀 | 緩解 |
|---|---|---|---|
| R1 | **`get_move_cost()` 的靜默 fallback** | `MOVE_COST.get(terrain, MOVE_COST[TERRAIN_OPEN])` —— 未登記地形字元靜默取平地成本。加 `passable` 欄位時資料表若沒同步,一面牆會變成可以走過去的空地,**畫面上完全正常** | M2 第一張 story 必須把未知地形字元改為明確失敗(`push_error` + 非成功回傳值,**不得用 `assert()`** —— `coding-standards.md` 已記載 `assert()` 在回傳 enum 的函式裡會靜默回傳序數 0) |
| R2 | **兩份游標/裝置權威實作**(A3,見下節) | 已查證屬實。目前**時間上互斥**,所以今天沒有可觀測的分歧 —— 這正是本專案登記過最危險的形狀:黑箱比對永遠無法區分「共用同一份」與「兩份碰巧一致」 | ✅ **2026-09-29 管理者裁決已選 (甲) 全部收成一份**,M6 為已定案實作範圍(三處逐處對應表見 M6 節)。⚠️ **收斂完成前不要用「跑起來一樣」當作它們一致的證據** —— 兩條路徑時間上互斥,沒有任何測試在比較它們 |
| R3 | **`threat_targets()` 可能是同一份程式碼被雙重期待**(U-T15) | UX 規格自評為「最需要優先釐清的技術假設落差之一」:名字是威脅範圍,實際可能回傳選取單位自身的攻擊延伸。GDD UI Requirements §1a 要的是**敵方**的威脅範圍疊加 + 逐敵拆分 | M1 查證 → M3 定案。**若真是雙重期待,改名比加參數安全** |
| R4 | **`battle_screen.gd` 2702 行** | 五個模組裡有三個要改它(M5 拆 `_confirm_at_cursor()`、M6 動輸入分派、M4 的 `_refresh_view()` 傳參)。三條線同時動同一個檔案 | 🔴 **已由「依賴與實作順序」節定案:執行層序列化順序 M6 → M5 → M4**(規劃層 M4/M5 產出互不依賴,兩層都要寫進 story)。或先做一次針對性的拆檔(**但拆檔本身要另開工作單,不要夾帶**) |
| R5 | **AC-24(結算中不可重入)的窗口可能寬度為零** | 若 `_apply_attack()`/`_apply_move()` 皆單幀同步完成,AC-24 天然滿足、測不出東西;但 M4 若替陣亡/攻擊加了跨幀演出,窗口就會**憑空長出來**,而那時沒有人會想起要補閘門 | M1 的 U-T12 先查證;M4 的動畫 story 驗收條件必須包含「若本 story 讓結算跨幀,同批補上 AC-24 閘門」 |
| R6 | **UX 規格多處自陳「未核對」被當成現況事實引用** | 規格全篇「現況 + 落差」的寫法很容易讀成「現況已核實」。實際上 8 項明文未核對 | M1 存在的理由。**story 敘述引用 UX 規格時,凡該處標了「未核對」,不得轉述為事實** |
| R7 | **像素/畫面證據的截圖驗收** | M4 全部產出都是視覺的,而 `coding-standards.md` 的截圖三分類與 Check 4 世界層量法(2026-09-23 裁決)沒有任何自動檢查 | M4 的每張 story 都要指定截圖類別(A/B/C)並附人工複核。⚠️ **管理者有實體視線約束**(上班時間、有人會經過座位),截圖驗收的呈現方式要先問 |

---

## A3 查證結果:游標系統接線的實際形狀

**派工單的推論**:「打牌選目標時棋盤走 #3 的游標系統,一般的移動/攻擊選格似乎走另一條路」,
並註明協調者只驗到「註冊點全在打牌路徑」,推論本身未驗證。

🔴 **查證結論:推論成立,而且比推論更具體 —— 重複的不只是游標,連「裝置權威仲裁」也有兩份。**
以下四段指令與原始輸出可逐條重跑。

### (1) `BOARD_TILE` surface 的註冊點確實全部落在打牌流程

```
$ awk '/^func /{fn=$0} /register_surface|unregister_surface/{print NR": ["fn"] "$0}' src/ui/battle/battle_screen.gd
1887: [func _confirm_selected_card() -> void:]  ... CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, self)
2052: [func _after_target_selection_advanced() -> void:]  ... CursorStateHost.unregister_surface(CursorTypes.SurfaceType.BOARD_TILE)
2226: [func _handle_card_confirm_cancel_transition() -> void:]  ... CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, self)
2263: [func _handle_target_selection_cancel_transition() -> void:]  ... CursorStateHost.unregister_surface(CursorTypes.SurfaceType.BOARD_TILE)
```

四個函式全部是打牌路徑(選卡確認 → 選目標 → 前進/取消)。**一般移動/攻擊路徑沒有任何一處
註冊 `BOARD_TILE` surface。**

### (2) 一般移動/攻擊的游標是 `battle_screen.gd` 自己的一份,完全不經 `CursorStateHost`

```
$ awk '/^func /{fn=$0} /_cursor_cell *=/{print NR": ["fn"] "$0}' src/ui/battle/battle_screen.gd
955:  [func _ready()]                 _cursor_cell = _state.position_of(player_ids[0])
1706: [func _handle_mouse_button()]   _cursor_cell = cell
1733: [func _handle_directional()]    _cursor_cell = clamp_cursor_move(_cursor_cell, _DIRECTION_VECTORS[action])
2421: [func _update_cursor_visual()]  _cursor_cell = cell
```
```
$ sed -n '1729,1734p' src/ui/battle/battle_screen.gd
func _handle_directional(_event: InputEvent) -> void:
	for action: StringName in _DIRECTION_VECTORS:
		if _direction_just_pressed(action, _direction_was_pressed):
			_device.note_pad_input()
			_cursor_cell = clamp_cursor_move(_cursor_cell, _DIRECTION_VECTORS[action])
			_board_view.set_cursor(_cursor_cell)
```
`clamp_cursor_move()` 是 `battle_screen.gd:1206` 的自有 static 函式,與
`CursorState.apply_buffered_navigation()`(`src/ui/cursor/cursor_state.gd:534`)是兩份
各自實作的方向鍵導航。

### (3) 🔴 **裝置權威(滑鼠 vs 手把)也有兩份獨立實作** —— 這是派工單推論之外的發現

```
$ grep -n "^func \|^enum " src/ui/battle/device_authority.gd
51:enum Device { MOUSE, PAD }
64:func _init(initial: Device = Device.MOUSE) -> void:
69:func current() -> Device:
75:func note_mouse_motion() -> void:
81:func note_pad_input() -> void:
94:func resolve_frame() -> bool:
$ wc -l src/ui/battle/device_authority.gd src/ui/cursor/cursor_state.gd
  116 src/ui/battle/device_authority.gd
 1206 src/ui/cursor/cursor_state.gd
```

`battle_screen.gd:941` 自行 `DeviceAuthority.new()`,由**約 15 處手動 `note_pad_input()` /
`note_mouse_motion()` 呼叫**餵資料,每幀在 `_process()`(line 1019)呼叫 `resolve_frame()`。
而 ADR-0005 的那一份是 `CursorState.arbitrate_device_authority(events)`,由
`cursor_state_host.gd:391` 以引擎事件自動驅動。

**兩份的差別不只是位置,是資料來源的性質**:一份靠人工在每個輸入分支手動插呼叫
(漏插不會報錯),一份靠引擎事件流。**漏插一處的後果是裝置權威在那個分支不切換,
而畫面看起來完全正常。**

### (4) 兩條路徑目前**時間上互斥**,所以今天量不到分歧

```
$ sed -n '1111,1112p' src/ui/battle/battle_screen.gd
		if not _controller.is_card_play_in_progress():
			_handle_directional(event)
```

`_handle_directional()` 被 `is_card_play_in_progress()` 閘住,打牌期間不執行。
**因此不存在「同一幀兩個游標各走各的」這種會當場炸出來的 bug。**

🔴 **這正是為什麼要把它寫進 epic 而不是放著。** 本專案已登記過這個形狀
(`affinity-position-chain.md` R2:好感度與戰鬥各有一份曼哈頓距離實作,「只是今天答案一致」)
—— **黑箱比對輸出永遠無法區分「共用同一份」與「兩份碰巧一致」。** 目前兩份互斥執行,
連「答案一致」都不會被檢驗到;它們是否語意一致**沒有任何機制在看**。

### 額外查到的第三份:方向鍵邊緣偵測

```
$ sed -n '1756,1760p' src/ui/battle/battle_screen.gd
func _direction_just_pressed(action: StringName, tracker: Dictionary) -> bool:
	var pressed_now: bool = Input.is_action_pressed(action)
	var was_pressed: bool = tracker.get(action, false)
	tracker[action] = pressed_now
	return pressed_now and not was_pressed
```

`battle_screen.gd` 用「自己維護 pressed-state Dictionary」做長按去抖,
ADR-0005 那邊走的是 `InputEventKey.echo` 過濾(`src/ui/cursor/cursor_types.gd:165`)。
**兩者解決同一個問題(長按/echo 重複觸發),手法不同。**

### 這對 epic 的意思

> ✅ **裁決已於 2026-09-29 做出:選 (甲) —— 全部收成一份。**
> **以下三個選項與其取捨保留為決策紀錄**(它記載了裁決當時可選的是什麼、代價各為何),
> **但不要再照「本節不做推薦」那句行動** —— 已經有答案了,實作範圍見 M6 節的逐處收斂表。

**當時送出的三個選項(已裁決,原文保留):**

| 選項 | 代價 | 好處 |
|---|---|---|
| **(甲)一般移動/攻擊路徑接進 `CursorStateHost`** | 要動 `battle_screen.gd` 的輸入分派與 `_cursor_cell` 全部寫入點(4 處);ADR-0005 的有效性旗標語意會**首次**套用到移動/攻擊路徑,可能暴露既有行為差異 | 單一出處。順帶讓 UX 規格 5(c) 的 `P-N1`「面板更新前先查有效性旗標」有東西可查 —— 現況根本沒有那個旗標 |
| **(乙)明文裁決保留兩份,登記為已知重複** | 重複永遠在,且沒有任何機制會發現它們漂移 | 零改動風險,M5/M6 立刻可動工 |
| **(丙)只收斂裝置權威(`DeviceAuthority`),游標導航維持兩份** | 折衷;`note_pad_input()` 的 15 處手動呼叫要全部改掉 | 收掉風險最高的那一份(漏插不報錯) |

⚠️ **原文寫「本節不做推薦,取捨屬管理者」—— 那句在 2026-09-29 之前是對的,現在已被裁決取代。**
本節不做推薦這一點沒有變(本 epic 確實沒有代為決定),變的是**管理者已經決定了**。

但當時寫下的這一句是事實而非意見,**它是裁決的依據,所以要留著**:
**選(乙)的話,`design/ux/tactical-combat-screen.md` 5(c) 與
GDD line 644「確認鍵生效前須先查詢有效性旗標,旗標無效時輸入必須被丟棄並觸發拒絕回饋」
這條硬性要求,在一般移動/攻擊路徑上將**永久無法滿足**——因為那條路徑上沒有旗標可查。

🔴 **協調者已把這一句補進送交管理者的選項表代價欄,管理者是看過它之後才選 (甲) 的。**
**這是知情下的選擇,日後不要被描述成「因為(甲)比較乾淨」** —— 它是因為(乙)會讓一條
已核准的硬性要求永久無法滿足。

---

## GDD Requirements / 未追溯項

**權威涵蓋數字在 `docs/architecture/traceability-index.md`(唯一來源,本節不複述數字)** ——
2026-09-01 稽核已記載該組數字曾散在 6 處並各自漂移。要現值就當場讀該檔的
`tactical-combat-system.md` 列與「完整矩陣 — 戰棋移動與交戰系統」節。

🔴 **本 epic 查證時發現追溯層有兩處落後,兩處都不擋建 epic,但會擋 story 的驗收判定:**

**(一)`TR` 登記表尚未收錄 2026-09-29 新增的 `passable` / `ignore_passability`**

```
$ grep -c "passable" docs/architecture/tr-registry.yaml
0
```

而 `TR-tactical-002` 現行文字仍寫「地形須有**兩個**正交逐格屬性(`terrain_cost`、遮蔽布林值)」,
`TR-tactical-006` 仍寫「`reachable_set(u, ignore_occupancy)`」**單一參數**。
GDD 公式三在 2026-09-29 已改為**三個**地形屬性與**兩個**獨立開關。
**後果**:M2 的 story 若照 `TR-tactical-002`/`-006` 的文字寫驗收條件,會少驗第三個屬性與
第二個開關,而且**不會有任何東西報錯** —— 登記表看起來是滿的。

**(二)追溯索引把本 GDD 標為「未 Approved」**

```
$ grep -n "tactical" docs/architecture/traceability-index.md | head -1
20:| tactical-combat-system.md | Core | **未 Approved** | 43 | 5 | 13 | 25 |
```
GDD 實際狀態為 **Approved(2026-08-31 管理者裁決)**(`systems-index.md` #4 列)。

### 🔴 擁有者指派(`PR-EPIC` 閘門 C5,2026-09-29)

**閘門的判定**:本檔初版誠實查證並登記了這兩處,但寫「不在本 epic 的實作範圍,
**也不由本 epic 修改**」—— **結果是它現在無人擁有。** 「登記了」不等於「有人會修」。

| # | 落後項 | **擁有者** | 何時要修 |
|---|---|---|---|
| 1 | `TR-tactical-002` 仍寫「兩個」地形屬性、`TR-tactical-006` 仍寫單一參數(`grep -c "passable" docs/architecture/tr-registry.yaml` → `0`) | **`technical-director`**(`docs/architecture/` 屬其網域;需一次小型派工 + 覆核) | **M2 的 story 切出來之前** |
| 2 | `traceability-index.md` 第 20 行把本 GDD 標為「未 Approved」(實際 Approved 2026-08-31) | **`technical-director`**(同上,建議與 #1 同批) | 同上;`/story-readiness` 之類的關卡可能據此誤判 |
| 3 | **#6 反向依賴的文件那一半無人擁有** —— `systems-index.md` #6 列逐字要求「須為本系統新增數值存取層,**並在其設計文件補一節**」。程式面已放進 M3 切面 5;**文件面零命中**(`grep -c "存取層" design/gdd/tactical-combat-system.md` → `0`;GDD 第 171 行只是 2026-08-17 的舊佔位句「具體介面待該系統設計時定案」。⚠️ 不要改用 `有效值` 當搜尋詞 —— 它命中 1 處,是別的東西) | **`systems-designer`**(GDD 作者網域,非 `technical-director`) | **M3 切面 5 的 story 切出來之前** |

🔴 **三項都不必在本批修掉,但都必須在對應 story 切出來之前有人動過。**

⚠️ **更新前的保險(閘門 C5 明文要求,寫進 M2 的 story 驗收條件)**:
**以 GDD 公式三為準,不以 `TR-tactical-002` / `TR-tactical-006` 的現行文字為準。**
沒有這一句,照 TR 文字寫的驗收條件會少驗第三個地形屬性與第二個開關,**而且不會有任何東西報錯。**

📌 **第 3 項與 A3/M6 是同一個形狀**:一項已核准的義務,兩半只接了一半 ——
程式面有主人、文件面沒有。差別只在 A3 那一半今天會影響執行,這一半今天只影響可追溯性。

---

## Open Questions 現況(引用,不重新盤點)

🔴 **21 項 OQ 的全表現況見 `docs/reviews/tactical-combat-readiness-design-2026-09-29.md` 第一節。
本 epic 直接引用該表,不重新盤點** —— 手抄複本必然漂移,本專案已為此付過多次代價。

本 epic **範圍內**的 OQ(其餘見上方 Out of Scope 表):

| OQ | 現況 | 落在哪個模組 |
|---|---|---|
| **OQ-10** | ✅ 已關閉 2026-09-29(管理者裁決,`passable` 獨立布林旗標)。設計面三處已落地(公式三 / Edge Cases / AC-13),**`src/` 零落地** | M2 |
| **OQ-2** | ✅ 已關閉 2026-09-09,擁有者為 `design/quick-specs/unit-stats-provisional.md` 第 1 節 | M3(基準值 vs 有效值存取層的資料源) |
| **OQ-16** | 效能無量化門檻,但**真正的風險變數是演算法是否有界**——`reachable_set` 若實作為「全盤展開後過濾」,效能隨棋盤格數而非 `MP` 惡化 | M2(有界前緣展開是實作要求,不是效能調校) |
| **OQ-6** | 三項面板明文指給 #10 | Out of Scope |

**UX 規格自己的 15 項 Open Questions(U-T1~U-T15)** 全文見
`design/ux/tactical-combat-screen.md` 第 15 節。分派:
U-T4/5/6/7/8/10/11/12 → **M1 查證批**;U-T2 → **M2**;U-T1 → **M5**;
U-T15 → **M1 查證 + M3 定案**;U-T3/U-T9 → **M5 落地時由 `ux-designer` 一併設計**;
U-T13/U-T14 → **Out of Scope**(分屬 #10 與尚未存在的關卡流程)。

---

## Definition of Done

本 epic 完成的條件:

- 全部 story 經 `/story-done` 關閉,測試證據依 `coding-standards.md` 的
  **Test Evidence by Story Type** 分級備齊(Logic/Integration 為 BLOCKING)
- `design/ux/tactical-combat-screen.md` 第 14 節標記 **🔴 阻擋 Approved** 的五項驗收條件全部通過:
  移動範圍三態(+第四態)互斥且窮盡、攻擊範圍三層、格位資訊面板最小欄位、
  攻擊確認面板五欄位拆解且非預判元件、行動旗標非色彩持久標記
- GDD 的 AC-13 / AC-14 / AC-20 / AC-22 / AC-24 有對應的自動化測試
- **M6 依 2026-09-29 管理者裁決 (甲) 落地:三處重複(游標導航 / 裝置權威 / 方向鍵去抖)
  全部收斂到 ADR-0005 那一份**,`src/ui/battle/device_authority.gd` 退役。
  同時 ADR-0005 的兩條硬性義務回歸測試維持綠燈
  (`tests/unit/cursor/cursor_layer_transform_test.gd` 與 `cursor_types.gd` 的 echo 過濾)
- 全部視覺驗收以 **placeholder 資產**完成即算通過(2026-09-29 管理者裁決)——
  驗的是形狀與非色彩通道是否成立,**不是美術品質**。換上正式資產時的灰階複驗不屬本 epic
- 全部視覺驗收截圖依 `coding-standards.md` 的三分類(A/B/C)明確分類,
  **並經人工開圖複核**(Check 5 在任何類別都不可被自動化取代)

⚠️ **不列為 DoD 的兩件事,以免被誤當成阻擋**:①停損門檻數字(A6,管理者獨有);
②是否移交 `/create-architecture`(管理者裁決,尚未進行)。

---

## Next Step

1. **`PR-EPIC` 閘門**(`producer` 執行,覆核模式 `full`,第六十七批管理者裁決五)
2. 閘門通過 + 管理者核可後,`Status` 改 `Ready`,並更新 `production/epics/index.md`
3. 執行 `/create-stories tactical-combat`

> ✅ **2026-09-29:本條件已滿足,原文保留供追溯。** 原文逐字:「🔴 **在閘門通過之前,本檔 `Status` 維持 `Draft`,`production/epics/index.md` 不更新。**」
> 閘門已於 2026-09-29 執行(判 CONCERNS,五項必辦全數關閉,詳見本檔開頭的 `Status` 行),管理者同日核可,
> 故 `Status` 已改 `Ready`、`production/epics/index.md` 已補上本 epic 那一列。
> 📌 **這條規則曾造成一次可預見的誤讀**:索引裡沒有 `tactical-combat` 一列,看起來像「漏更新」,
> 實際是本行刻意規定的。協調者 2026-09-29 就這樣誤判過一次並寫進了派工單,在專家動手前收回。
> **下一個 epic 若沿用本規則,請把這句話一併帶過去。**
