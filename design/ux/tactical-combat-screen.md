# UX Specification: 戰棋介面(Tactical Combat Screen)

> **Status**: Draft
> **Author**: ux-designer
> **Last Updated**: 2026-09-29
> **Screen / Flow Name**: `BattleScreen`(對應 `src/ui/battle/battle_screen.gd`)
> **Platform Target**: PC, Console(鍵鼠 + 全手把支援,無觸控)
> **Related GDDs**: `design/gdd/tactical-combat-system.md`(Core Rules、Acceptance Criteria、Open Questions 三節)
> **Related ADRs**: ADR-0001(戰棋查詢介面原子性契約)、ADR-0005(單一游標/高亮狀態系統)
> **Related UX Specs**: `design/ux/skill-card-play.md`(打牌流程,本份僅在交界處引用)
> **Accessibility Tier**: **Standard**(專案級,2026-08-19 使用者裁決;見 `design/ux/accessibility-requirements.md`)

> **Note — Scope boundary**: 本份**含**:選取單位、移動範圍呈現與選格、攻擊目標選取、雙旗標
> (移動/攻擊各自已用未用)呈現、結束回合、陣亡呈現、地形資訊呈現、游標與高亮在本畫面的行為。
> **不含** #10 戰鬥 HUD 的面板排版(傷害拆解/格位資訊/預判/好感度貢獻,共 4 面板,見 GDD OQ-6)、
> 也不含打牌流程本身(見 `skill-card-play.md`)。

---

## 1. Purpose & Player Need

**玩家需求**:這是玩家唯一直接操作棋盤本體的畫面——移動棋子、選擇攻擊目標、讀懂射程與命中線,
每一回合實際做的事都在這裡發生(GDD Overview 逐字)。玩家打開這個畫面時想的不是「顯示我的
單位資料」,而是「這步棋的後果我現在就要能算清楚,不要等我按下去才知道」——GDD Player Fantasy
明訂三種會摧毀這個承諾的具體情境(顯示與結算不一致、陣亡等狀態轉換造成資訊斷裂、
敵我數值劣勢的翻轉路徑不可驗算),本畫面的每一項呈現判斷都以「這個呈現讓玩家算得更準,
還是更猜?」為判準——與 `skill-card-play.md` 明文共用同一句判準。

**玩家目標**:把游標移到任一格或任一單位,不需要額外確認鍵,就能讀出該格/該單位的完整戰術
資訊(地形、射程、佔位、行動旗標剩餘);選定攻擊目標後,在真正送出攻擊之前,能看到
`ATK`/`DEF`/`Φ` 各自的貢獻與最終傷害,而非只有一個猜結果的合併數字。

**遊戲目標**:本畫面是「好感度—位置連鎖系統」賴以運作的地基——它維護的單位站位資料
(誰跟誰相鄰)是好感度佈局轉譯成空間戰術規則的唯一輸入來源(GDD Overview)。本畫面因此
不只是戰鬥數值的呈現層,它每一次移動/攻擊確認都要正確觸發 GDD Core Rules #5 的結算順序、
Core Rules #10 的即時性與單一快照原子性義務,以及好感度數值池的陣亡通知——這些是本畫面
對外系統的契約義務,不是可自由裁量的呈現細節。

---

## 2. Player Context on Arrival

⚠️ **`design/player-journey.md` 不存在**(比照 `skill-card-play.md`/`interaction-patterns.md`
已登記的既有缺口 OQ-2),以下為 GDD 推導,非玩家旅程圖所載。

| 問題 | 答案 |
|---|---|
| 剛剛在做什麼 | 我方回合:剛結束上一個單位的操作,或剛看完敵方回合的演出;此為玩家在整場戰鬥中停留時間最長的畫面,不是路過畫面 |
| 情緒狀態 | **專注盤算,回合制無時間壓力**——與 `skill-card-play.md` 相同脈絡 |
| 認知負擔 | 高——同時追蹤:己方剩餘可行動單位、敵方威脅範圍、地形成本/遮蔽、好感度佈局後果 |
| 已有的資訊 | 若剛選定某單位,已知其位置與(現況下)可達格集合;**不含** GDD 要求但尚未實作的格位資訊面板欄位(見 5(b)) |
| 最可能想做的事 | 找到「這步棋的後果」——移動或攻擊前先看懂範圍與傷害,而非移動/攻擊後才發現算錯 |
| 最怕什麼 | 三種 Player Fantasy 具名失敗模式(見 1 節)——尤其「早知道」型:操作後才發現某個後果其實早就能被算出來,只是畫面沒讓他看懂 |

**本畫面的情感設計目標**:玩家應感覺「我看到的就是真的,我算的就是會發生的」——
不是視覺華麗,是**確定性帶來的信任感**。这与 GDD MDA 美學優先序一致:Challenge 第 1 優先,
Sensation 最低——任何讓玩家多花一次「重新確認」才能讀懂戰場的處理,即使更有打擊感,
都是錯誤選擇(GDD Visual/Audio Requirements 開頭逐字)。

---

## 3. Navigation Position

```text
[根 —— 未核對,推測為主選單或關卡選擇,本規格未讀相關程式碼]
  └── 戰鬥畫面(BattleScreen)——本文件範圍
        ├── 手牌介面(縮圖常駐/展開)—— skill-card-play.md,原地疊層,非子畫面
        ├── 戰鬥選單(BattleMenu)—— design/ux/battle-menu.md,模態疊層
        ├── 卡牌數值確認面板(CardConfirmPanel)—— skill-card-play.md,模態疊層
        └── 🔴 攻擊確認面板(規格新增,尚未實作)—— 模態疊層,見 5(a)/7.3
```

**模態行為**:`BattleScreen` 本身是 Overlay-live(遊戲世界持續存在,非疊在其他畫面上的彈窗)。
其疊層(選單、各確認面板)皆為 Modal——阻擋背景互動,需明確關閉。

**可達性——進入點**:⚠️ **本規格未核對**戰鬥畫面如何被進入(從主選單開始新遊戲?從關卡選擇?
是否有存讀檔銜接?)。`.claude/docs/technical-preferences.md` 的 `forbidden_patterns`
明訂 `networking_features` 與 `procedural_terrain_generation` 皆與本畫面無涉,但「玩家如何
抵達這裡」屬於尚未設計/未核對範圍,列入 Open Questions 而非猜測。

---

## 4. Entry & Exit Points

⚠️ **本節多數欄位未核對**(見 3 節),僅列出可從已讀程式碼確認的部分。

**進入**:未核對觸發來源;已知 `_ready()`(`battle_screen.gd:793`)會載入地形/名冊/好感度連線/
卡牌資料表(`TERRAIN_PATH`/`ROSTER_PATH`/`AFFINITY_PATH`/`CARDS_PATH`,見 8 節),失敗時顯示
`TEXT_LOAD_FAILURE_FORMAT` 錯誤畫面(`_fail_load()`)——這是本畫面**唯一已確認的例外進入態**。

| 觸發 | 來源 | 資料傳入 | 現況 |
|---|---|---|---|
| 資料載入失敗 | `_ready()` 內部檢查 | 失敗檔案清單、失敗原因 | ✅ `_fail_load()`,顯示錯誤文字+回報引導 |
| 正常進入戰鬥 | ⚠️ 未核對 | ⚠️ 未核對 | 列入 Open Questions |

**離開**:

| 觸發 | 去向 | 現況 |
|---|---|---|
| 戰鬥勝利 | `_on_battle_ended(Outcome.VICTORY)` | ✅ 顯示 `TEXT_RESULT_VICTORY`,之後去哪個畫面**未核對** |
| 戰鬥失敗 | `_on_battle_ended(Outcome.DEFEAT)` | ✅ 顯示 `TEXT_RESULT_DEFEAT`,之後去哪個畫面**未核對** |
| 選單「離開遊戲」 | `BattleMenu` 的破壞性確認(`design/ux/battle-menu.md`) | ✅ 已實作,非本份規格範圍;明文「目前沒有存檔功能,離開後這場戰鬥的進度會消失」 |

---

## 5. Layout Specification

> 本節先寫現況(附指令/輸出證據),再標「規格要求改動現行實作」與「尚未實作」項目。
> 兩層架構(世界層 480×270 / 介面層當下解析度)見 `design/art/screen-architecture.md`,
> 本節一律遵守「介面不得依賴棋盤旁邊有空位」硬性約束。

### 5.1 Wireframe(1080p,N=4,fpx=44 為例)

```text
┌──────────────────────────────────────────────────┐
│  ┌────────────────────────────────────────────┐  │ ← 安全區(5% 內縮,HudLayout.safe_rect)
│  │ 第 3 回合．我方行動                          │  │ ← StatusLabel(既有,_update_status_label()）
│  │                                              │  │
│  │              ┌────┐                         │  │
│  │              │我軍1│ ▨▨▨(移動範圍/攻擊/威脅  │  │ ← 世界層 480×270(BoardView)
│  │              └────┘   高亮,詳見 6/7 節)      │  │   terrain / pieces / highlights /
│  │        打擊 7　血量 12→5                     │  │   affinity lines / cursor
│  │              ┌────┐                         │  │ ← 資訊列(_info_label,錨點函式名稱
│  │              │敵1 │                          │  │   本規格未逐一核對,見下方 (c) 標記)
│  │                                              │  │
│  │        ▏▨▏▨▏▨▏▨▏▨▏   5/5                    │  │ ← HandBar Z1(既有,skill-card-play.md)
│  │  ════════════════════════════════════════   │  │
│  │   [移動 方向鍵/十字鍵/滑鼠  確認 Enter/A/左鍵 │  │ ← ControlsHintBg(既有,
│  │    取消 Esc/B  開/收手牌 C/X  跳目標 Tab/RB   │  │   hud_layout.gd controls_hint_bg_rect())
│  │    選單 M/Start]                              │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

**現況證據**(逐一附指令):

- `_info_label` 內容格式(三擇一,互斥):`TEXT_AFFINITY_PREVIEW_FORMAT = "好感度 %+d→%+d"`、
  `TEXT_AFFINITY_CURRENT_FORMAT = "好感度 %+d"`、`TEXT_DAMAGE_PREVIEW_FORMAT = "打擊 %d　血量 %d→%d"`
  ——見 `src/ui/battle/battle_screen.gd:166-168`(`grep -n "TEXT_AFFINITY_PREVIEW_FORMAT\|TEXT_DAMAGE_PREVIEW_FORMAT" src/ui/battle/battle_screen.gd`)。
- 操作提示文字現況:`TEXT_CONTROLS_HINT = "移動 方向鍵/十字鍵/滑鼠　確認 Enter/A/左鍵　取消 Esc/B\n開/收手牌 C/X　跳目標 Tab/RB　選單 M/Start"`
  (`grep -n "TEXT_CONTROLS_HINT" src/ui/battle/battle_screen.gd:255`)——按鍵配置與 `skill-card-play.md` 一致,無需另訂。
- `HudLayout` 已確認存在的錨點函式:`font_size(window_size)`、`safe_rect(window_size)`、
  `controls_hint_bg_rect(window_size)`(`grep -n "^static func" src/ui/battle/hud_layout.gd`)。
  `_info_label`/`StatusLabel` 各自呼叫的確切 rect 函式名稱,本規格**未逐一核對**——
  下一個實作故事應直接讀 `battle_screen.gd` 的 `_ready()`/`_apply_layout()` 確認現有錨點,
  不在此重述座標(避免像 `Φ` 曼哈頓距離那樣兩處各刻一份)。

### 5.2 Zone Definitions

| 區 | 層 | 內容 | 現況 |
|---|---|---|---|
| **世界層(BoardView)** | 世界層,480×270 原生,`WorldViewportContainer` 整數縮放 | 地形、棋子、HP 條/文字、移動/攻擊/威脅高亮、好感度連線、游標 | ✅ 已實作(`src/ui/battle/board_view.gd`) |
| **StatusLabel** | 介面層 | `第 N 回合．{我方/敵方}行動` | ✅ 已實作 |
| **資訊列(_info_label)** | 介面層 | 游標即時查詢結果(好感度預覽/現值/傷害預覽三擇一) | ⚠️ **尚未實作 P-N1 完整要求**——見下方 (c) |
| **HandBar Z1/Z2** | 介面層 | 手牌縮圖/展開(`skill-card-play.md` 擁有,本文件不重述) | ✅ 已實作,不在本份規格範圍 |
| **ControlsHintBg** | 介面層 | 操作提示橫條,貼安全區下緣 | ✅ 已實作 |
| **BattleMenu / CardConfirmPanel** | 介面層,模態疊層 | 選單、破壞性確認、卡牌數值確認面板 | ✅ 已實作(`src/ui/menu/battle_menu.gd`、`src/ui/battle/card_confirm_panel.gd`),各自有 UX 規格,本文件僅在交界處引用 |
| **🔴 攻擊確認面板** | 介面層,模態疊層 | `ATK`/`DEF`/`Φ`/結果傷害/目標剩餘 HP 拆解(GDD UI Requirements §4、P-M1) | 🔴 **尚未實作**——見下方 (a) |
| **🔴 格位資訊面板** | 介面層 | 地形種類/`terrain_cost`/遮蔽旗標/佔位單位陣營-HP-當前狀態/武器分層/當前 MP(GDD UI Requirements §1 逐字列舉的最小必要欄位) | 🔴 **尚未實作**——見下方 (b) |

### 5.3 現況與規格落差(逐項標記)

**(a) 🔴 規格要求改動現行實作 —— 攻擊確認面板(GDD UI Requirements §4、Visual/Audio §2、`P-M1`)**

現況:`_confirm_at_cursor()` 直接呼叫 `_controller.click_tile(_cursor_cell)`,而 `click_tile()`
一旦判定目標在 `_attack_targets_for()` 內,**同一次呼叫內直接執行 `_apply_attack()`**——
兩者之間沒有任何面板或第二次確認。
證據:
```
$ grep -n "_confirm_at_cursor\b" -A3 src/ui/battle/battle_screen.gd
2285:func _confirm_at_cursor() -> void:
2286:	if not BoardCoords.is_in_bounds(_cursor_cell):
2287:		return
2288:	_controller.click_tile(_cursor_cell)
```
```
$ grep -n "if occupant != null and _attack_targets_for" -A2 src/gameplay/battle/battle_controller.gd
559:		if occupant != null and _attack_targets_for(_selected_unit_id).has(pos):
560:			return _apply_attack(_selected_unit_id, occupant.id)
```
而 `_info_label` 目前只顯示 `format_damage_preview()` 的合併字串(`"打擊 %d　血量 %d→%d"`,
`src/ui/battle/battle_screen.gd:1481`)——**沒有任何地方單獨顯示 `ATK`、`DEF`、`Φ` 三個欄位**,
`grep -c "ATK\|DEF" src/ui/battle/battle_screen.gd`(排除註解後)在攻擊呈現路徑上為 0 處使用。

**規格要求**:新增一個攻擊確認面板(模態,比照 `card_confirm_panel.gd` 的既有模式,
不得沿用同一元件——`P-M2`「預判/確認元件不得共用」原則同樣適用於攻擊路徑),欄位比照
GDD UI Requirements §4:`ATK`(攻擊方有效攻擊力)、`DEF`(目標有效防禦力)、`Φ`(帶號,`=0` 仍顯示)、
結果傷害、目標結算後預估 HP。**確認鍵在此面板上變成第二次動作**:第一次選定目標鍵入確認→
開啟本面板(零寫入);面板上再次確認→執行 `click_tile()` 對應的攻擊路徑。
**影響檔案**:`src/ui/battle/battle_screen.gd`(`_confirm_at_cursor()` 需拆成「開面板」與
「面板上再次確認才呼叫 `click_tile()`」兩段,比照既有卡牌確認的 `_open_card_confirm_panel()`
/ `_apply_pending_card_confirm()` 兩段式寫法)、新檔案(暫名 `attack_confirm_panel.gd`,
比照 `card_confirm_panel.gd` 結構)。**不影響** `battle_controller.gd` 的公開介面——
`click_tile()`/`_apply_attack()` 的執行語意不變,改動只在 UI 層何時呼叫它。

**(b) 🔴 尚未實作 —— 格位資訊面板(GDD UI Requirements §1)**

現況:`_info_label` 只在三種情境顯示三選一的字串(好感度預覽/好感度現值/傷害預覽),
**從未顯示地形種類、`terrain_cost`、遮蔽旗標、佔位單位的陣營/HP/當前行動旗標狀態、
武器分層 `(min_range,max_range)`、或當前 MP**。GDD UI Requirements §1 逐字列舉這些為
「格位資訊面板的最小必要欄位」,且要求游標移到任一格即時更新、無效性旗標時走未解析態
(`P-F1`)。現行 `_info_label` 是三種特定情境的窄版摘要,不是該節要求的通用格位面板。
**這是本畫面目前最大的 GDD 未涵蓋項**——沒有這個面板,玩家無法只靠「把游標移過去」
算出敵方單位的威脅範圍組成(射程 + MP),必須依賴 §1a 敵方威脅範圍疊加圖(見 6/7 節)
單獨補足一部分,但威脅範圍疊加圖本身也未實作(見下)。

**(c) ⚠️ `_info_label` 現況與 `P-N1`(游標即檢視)的落差**

`P-N1` 要求「面板更新前必須先查詢游標系統的有效性旗標;旗標無效時走 P-F1 未解析態」。
現況 `_refresh_view()` 的三段判斷(`_is_move_preview_cell` / `_cursor_attack_target_id` /
`_cursor_active` 且有關係線)**沒有查詢任何獨立的「有效性旗標」**,而是直接用
`_cursor_active` 布林值 + 幾個查詢結果的存在與否來決定顯示哪一種文字,不顯示時
`info_text` 直接設為空字串(`""`)——這是「面板變空白」,不是 `P-F1` 要求的「明確的未解析態」。
本規格判定:**這不構成立即缺陷**(游標系統本身的有效性旗標語意主要針對「目標剛陣亡」
這類情境,見 GDD Core Rules #6b),但格位資訊面板(見 (b))補齊後,必須把「未解析態」
與「這格單純沒有可顯示資訊」兩者分開處理,不得沿用現在的空字串手法——已列入 Open Questions。

---

## 6. States & Variants

> 兩層狀態:①**單位自身的行動經濟狀態**(GDD Core Rules #9,已有程式碼);
> ②**本畫面的互動模式狀態**(選取/移動預覽/攻擊目標/確認…)。兩者正交,合併列出。

### 6.1 單位行動經濟狀態(GDD States and Transitions,現況已實作)

| 狀態 | 進入條件 | 現況呈現 | 規格要求但尚未實作 |
|---|---|---|---|
| 可行動·皆未用 | 回合開始 | 可被選取,`move_targets()`/`attack_targets()` 皆非空(依實際盤面) | 🔴 **無任何持久視覺標記**——見下方「行動旗標指示」 |
| 可行動·只剩攻擊 | 移動旗標已用 | 選取後 `move_targets()` 應回空陣列(現況:`_move_targets_for()` 依 `_order.can_move(unit_id)` 判斷,`grep -n "_order.can_move" src/gameplay/battle/battle_controller.gd:899`——邏輯已對,呈現未驗證) | 同上 |
| 可行動·只剩移動 | 攻擊旗標已用 | 同上,`_order.can_attack()` 對稱判斷(`battle_controller.gd:913`) | 同上 |
| 已行動 | 兩旗標皆用/主動結束 | 選取後兩查詢應皆空 | 🔴 **玩家無法在不選取的情況下,只靠看棋子就知道它是否已行動**——GDD 明文要求此為格位資訊面板欄位之一(見 5(b)),目前該面板不存在 |
| 陣亡 | HP≤0 | `_state` 邏輯層移除佔位(`Core Rules #10c`,已由 `battle_state.gd` 保證,`grep -n "tile becomes passable" src/gameplay/battle/battle_state.gd:267` 為既有文件內註解佐證陣亡即釋放佔位的既有共識);棋子從 `render_pieces()` 傳入清單消失 | ⚠️ **陣亡的「可視移除過渡」是否存在未核對**——`board_view.gd` 的 `render_pieces()` 現況為整批重繪(逐幀傳入完整 pieces 陣列),本規格未核對是否有淡出動畫,列入 Open Questions |

🔴 **規格要求改動現行實作 —— 行動旗標指示(GDD UI Requirements §1「當前狀態」欄、Visual/Audio §6.1)**:
四種可觀測值(皆未用/只剩攻擊/只剩移動/已行動)必須是**非色彩通道**可辨識的持久標記,
比照 `skill-card-play.md` Z4(世界層、貼棋子右上、像素圖形)的既有先例——不要求沿用同一美術,
但要求「常駐於棋盤上,不需要選取或開啟面板才看得到」。**影響檔案**:`board_view.gd`
(新增一層,比照 `StatsLayer` 的作法)、`battle_screen.gd`(`_refresh_view()` 需為每個
存活單位查詢其旗標狀態並傳入)。目前 `battle_controller.gd` 是否已有「查詢單一單位剩餘旗標」
的公開方法未核對(現有查詢皆是「這個單位選取後我能做什麼」的隱式判斷,非顯式列舉四態的
getter)——若沒有,`TurnOrder`(`_order`)需補一個公開查詢,列入 Open Questions。

### 6.2 本畫面互動模式狀態

| 狀態 | 觸發 | 世界層呈現 | 玩家能做什麼 | 現況 |
|---|---|---|---|---|
| **T0 無選取** | 預設、取消、選取失敗 | 無高亮 | 移游標、選取我方可行動單位、開手牌、開選單 | ✅ 已實作 |
| **T1 已選取·移動預覽** | 選取單位、游標停在可達格或原地 | 三態高亮(見 7 節)+ 好感度預覽線(隨游標即時甩動) | 逐格移動游標、確認移動、取消回 T0 | ✅ 已實作(`_is_move_preview_cell` + Mode A 好感度預覽) |
| **T2 已選取·攻擊目標可視** | 游標停在合法攻擊目標 | 攻擊/威脅高亮 + 傷害預覽文字 | 確認攻擊、取消 | ⚠️ 確認**直接執行**,見 5(a) 之規格要求改動 |
| **🔴 T2' 攻擊確認中(規格新增,尚未實作)** | T2 按下確認 | 攻擊確認面板疊上(比照 `card_confirm_panel`) | 再次確認執行 / 取消回 T2,**取消零寫入** | 🔴 尚未實作,見 5(a) |
| **T3 敵方回合** | `_end_faction_phase_pressed()` 觸發、`Phase.ENEMY_ACTING` | 棋盤唯讀播放(逐步演出,`step_enemy_phase()`) | 無——手把/鍵盤輸入應被拒絕或忽略 | ✅ 已實作(Story U-018 跨幀演出) |
| **T4 強制棄牌** | 補牌後手牌達上限 | 同 T0 但手牌被迫展開 | 見 `skill-card-play.md` S4,本文件不重述 | ✅ 已實作,非本份範圍 |
| **T5 打牌流程(S1~S3)** | 開手牌/選牌/選目標 | 見 `skill-card-play.md` | 見該文件 | ✅ 已實作,非本份範圍;與 T1/T2 的邊界見 7 節 |
| **T6 選單開啟** | `battle_menu` 鍵 | 世界層維持最後畫面,選單疊上 | 見 `design/ux/battle-menu.md`,本文件不重述 | ✅ 已實作 |
| **T7 結算演出中(權威寫入進行中)** | `_apply_attack()`/`_apply_move()` 執行期間 | 棋盤演出動畫(若有) | 🔴 **所有操作須被拒絕,拒絕須可觀測**(GDD AC-24) | ⚠️ 現況 `click_tile()` 為同步呼叫,`_apply_attack`/`_apply_move` 是否曾經跨幀化未核對——若皆為單幀同步完成,AC-24 的「結算中」窗口可能寬度為零,天然滿足;若未來改為跨幀演出,必須補這道拒絕閘門。列入 Open Questions,不在此假設答案 |
| **T8 勝負結算** | `_on_battle_ended()` | Result 文字(`TEXT_RESULT_VICTORY`/`TEXT_RESULT_DEFEAT`) | 唯讀 | ✅ 已實作 |

### 6.3 🔴 尚未實作 —— 移動範圍三態、攻擊範圍三層(GDD Visual/Audio §1.1/§1.3、`P-D1`)

現況實測:
```
$ grep -n "func reachable_tiles" -A2 src/gameplay/board/board.gd
106:func reachable_tiles(origin: Vector2i, mp: int) -> Array[Vector2i]:
```
`reachable_tiles()` **沒有 `ignore_occupancy` 參數**——GDD 公式三明訂的 `B = reachable_set(u, ignore_occupancy=true)` 在程式碼裡不存在,因此「不可達——被佔位擋死」與「不可達——移動力不足」
兩種成因**無法被區分查詢**,更談不上呈現。`battle_controller.move_targets()` 只回傳可達集合
`A`,`_refresh_view()` 只呼叫 `set_move_highlights(move_cells)`——**未選中的格子一律不畫任何東西**,
玩家看不到「不可達」本身,更別提兩種成因。這是 GDD Visual/Audio §1.1 明文的硬性需求
(直接命中 Player Fantasy「早知道」失敗模式),目前**完全未落地**。

攻擊範圍同理:`_attack_targets_for()` 回傳的已是「距離在射程內**且**視線暢通」的最終合法集合
(`grep -n "_attack_targets_for" -A15 src/gameplay/battle/battle_controller.gd`),**沒有單獨的
「範圍內但視線被擋」查詢**——GDD Visual/Audio §1.3 要求的第三層(「範圍內但不可攻擊」)
目前無資料來源可畫,`board_view.gd` 也沒有對應的高亮層。

**規格要求改動現行實作,影響檔案**:
1. `src/gameplay/board/board.gd`——`reachable_tiles()` 新增 `ignore_occupancy: bool = false` 參數。
2. `src/gameplay/battle/battle_controller.gd`——新增查詢(暫名 `move_targets_blocked()`/
   `move_targets_out_of_range()`,或回傳一個含三個切面的 Dictionary,由 `/create-architecture`
   決定介面形狀,本規格只定案「三個切面必須都能查到」)。
3. `src/gameplay/battle/battle_state.gd`(或 `LineOfSight` 相關檔案)——新增「距離在射程內但
   視線被擋」的查詢,與現有 `can_attack()`(合法)、純距離判斷分開。
4. `src/ui/battle/board_view.gd`——新增至少兩層高亮(不可達·移動力不足 / 不可達·被佔位擋死),
   與新增一層(範圍內但視線擋)。**三態/三層一律不得只靠顏色**(`P-F3` 無例外)——
   現有 `THREAT_HIGHLIGHT_PATH` 已示範「環狀 vs 實心」的非色彩做法,新增層應延續此手法
   而非另創一套。

### 6.4 尚未實作 —— 預判模式(GDD Core Rules #8、UI Requirements §5、`P-M2`)

現況的 `_info_label` 傷害/好感度預覽,語意上接近但**不等於**預判模式:GDD 要求預判是玩家
**主動**啟用的動作(「玩家可在確認移動/攻擊前,對候選目的地啟用『預判標記』」),且明訂
「不得與確認面板共用元件」。現況沒有獨立的「預判標記」輸入,現有的 hover 即時預覽是否已經
充分滿足預判模式的全部語意(尤其「三態摘要:正效果/負效果/無效果」的好感度佈局預判,
非僅傷害數字)**未核對**——`_refresh_view()` 的 Mode A 只算好感度差值文字,不產出正/負/無
三態的獨立摘要物件。列入 Open Questions,待攻擊確認面板(5(a))落地時一併設計,
避免預判與確認面板的元件邊界問題重演一次。

---

## 7. Interaction Map

**輸入裝置**:鍵盤/滑鼠(主要)+ 完整手把,主機無游標,禁止任何僅滑鼠可達的互動
(`.claude/docs/technical-preferences.md`、`P-I2` 無例外)。

### 7.1 現況按鍵配置(已實作,證據見下)

```
$ grep -n "TEXT_CONTROLS_HINT" -A1 src/ui/battle/battle_screen.gd
255:const TEXT_CONTROLS_HINT: String = "移動 方向鍵/十字鍵/滑鼠　確認 Enter/A/左鍵　取消 Esc/B\n開/收手牌 C/X　跳目標 Tab/RB　選單 M/Start"
```

| 動作 | 鍵盤 | 手把 | 滑鼠 | 現況 |
|---|---|---|---|---|
| 移動游標 | 方向鍵 | 十字鍵/左搖桿 | 移動即改變游標所在格(裝置權威見 `P-I1`) | ✅ `_handle_directional()` |
| 選取/確認 | Enter/小鍵盤 Enter/Space | A | 左鍵 | ✅ `battle_confirm`,`_handle_mouse_button()` |
| 取消/退一步 | Esc | B | — | ✅ `battle_cancel` |
| 開/收手牌 | C | X(左動作鍵) | — | ✅,非本份範圍(`skill-card-play.md`) |
| 跳下一個/上一個合法目標 | Tab / Shift+Tab | RB / LB | — | ✅ `_apply_pending_target_jump()` |
| 開啟選單 | M | Start | — | ✅,非本份範圍(`design/ux/battle-menu.md`) |
| 結束該單位行動 | ⚠️ 未在提示文字中列出 | 同左 | 點擊已選單位本身?**未核對** | ⚠️ `end_unit_turn(id)` 存在於 `battle_controller.gd:575`,但呼叫路徑(哪個按鍵/是否經選單)本規格未核對,列入 Open Questions |
| 結束我方回合 | 選單內項目 | 同左 | — | ✅ `BattleMenu` 的 `_on_end_phase_row_pressed()` → `end_faction_phase_confirmed` 訊號 |

### 7.2 移動/選取流程(現況已實作)

| 步 | 輸入 | 前置條件 | 結果 | 零寫入? |
|---|---|---|---|---|
| 1 選取我方單位 | 確認鍵於己方棋子格 | 該單位存活、屬我方陣營 | `selected_unit()` 更新,顯示三態高亮(6.3 節尚未實作前僅顯示可達格) | ✅ 零寫入 |
| 2 逐格檢視 | 方向鍵/十字鍵/滑鼠移動 | 已選取 | `_info_label` 更新(見 5(b)/(c) 落差)、好感度預覽線隨游標甩動 | ✅ 零寫入 |
| 3 確認移動 | 確認鍵於可達格 | 該格在 `move_targets()` 內 | **直接執行** `_apply_move()` | ⚠️ 移動本身按 GDD 屬「已確認執行」,非「尚未確認」,故直接執行**符合** GDD(`UI Requirements §6` 只要求「尚未確認的選取」可取消零寫入;移動落點的選擇過程——游標移動——本身零寫入,落點一旦確認鍵按下即视为已確認,與攻擊的差異在於 GDD 從未要求移動也要有二段確認面板) |
| 4 取消選取 | 取消鍵 | 已選取、無更深層狀態 | 回 T0,`deselect()` | ✅ 零寫入 |

🔴 **移動與攻擊的確認語意不對稱,這是本規格的判斷,不是既有裁決**:GDD UI Requirements §4
只對「攻擊確認」明訂欄位拆解與言下之意的二段確認,對移動未提出同等要求(移動沒有
ATK/DEF/Φ 這類需要拆解的隱藏數值,格子本身在踏上前已经由三態高亮完整揭露後果)。
**因此移動維持現況的單鍵直接執行,不需要新增確認面板**——5(a) 的規格要求改動**僅針對攻擊**。

### 7.3 攻擊流程(現況 + 規格新增的攻擊確認面板)

| 步 | 輸入 | 現況 | 規格要求(見 5(a)) |
|---|---|---|---|
| 1 選取單位、游標移到攻擊目標 | 同上 | ✅ 傷害預覽文字即時更新 | 不變 |
| **2 確認攻擊** | 確認鍵 | 🔴 **直接呼叫 `click_tile()`,同一次呼叫內完成結算** | 🔴 **改為開啟攻擊確認面板**(T2'),本次呼叫**零寫入** |
| **3 面板上再次確認** | 確認鍵(面板取得輸入焦點) | (面板不存在) | 呼叫既有的 `click_tile()`/`_apply_attack()`路徑,**權威寫入** |
| 取消(步 2 或 3) | 取消鍵 | 現況步 2 已是最終執行,取消無意義 | 面板開啟後取消 → 回攻擊目標檢視,**零寫入**(比照 `P-N3`) |

🔴 **確認去重與 `_process(priority=100)` 讀取時機,比照 `skill-card-play.md` 既有規則同樣適用**:
若攻擊確認面板讀取「游標系統裁定後的狀態」,同幀分派順序
(`_input`→`_unhandled_input`→`_physics_process`→`_process`)下,不得在按鍵處理裡讀,
必須放在 `_process(priority=100)`——理由與該文件「一條不會報錯的實作義務」小節逐字相同,
本規格不重複整段論證,僅指出攻擊確認面板一旦落地,**必須套用同一條紀律**,否則會複製
該文件已經記載過的同一個「讀到上一幀值」錯誤。同理需要去重保護(鍵盤與手把同幀各送一次
確認不得提交兩次攻擊)。

### 7.4 跳轉合法目標(現況已實作,細節未逐一核對)

`_apply_pending_target_jump()` 存在(`battle_screen.gd:1958`),對應 Tab/RB 鍵。**是否滿足
GDD UI Requirements §3 的決定性排序要求(先列後行,`y` 升冪、同列 `x` 升冪)且有測試釘死**,
本規格未讀該函式內文,列入 Open Questions,不代為斷言。

### 7.5 狀態限定的輸入限制

| 狀態 | 限制 | 理由 |
|---|---|---|
| T3 敵方回合 | 玩家操作應被拒絕/忽略 | 唯讀播放期間,GDD Core Rules #11 精神(結算中不受理操作)——**是否對敵方逐步演出的每一幀都生效,本規格未逐一核對** `_input()` 的頂端守衛邏輯,列入 Open Questions |
| T4 強制棄牌 | 取消鍵、選單鍵皆無效 | `skill-card-play.md` S4 既有規則,本文件沿用不重述 |
| **T2' 攻擊確認中(規格新增)** | 移動游標、開手牌、開選單皆應被拒絕,僅接受「再次確認」與「取消」 | 比照 `card_confirm_panel` 開啟期間的既有模式(`P-M1`「模態」性質) |
| T7 結算演出中(若存在,見 6.2) | 全部操作拒絕,拒絕須可觀測 | GDD AC-24(結算步不可重入)——**現況是否已有這個窗口**,見 6.2 T7 列的誠實登記,未核對前不斷言 |

### 7.6 拒絕回饋(`P-F2`)——現況未核對

`click_tile()` 在多種情境回傳 `{"action": &"none"}` 或 `{"action": &"deselected"}`
(`battle_controller.gd:547-566`)。**呼叫端(`battle_screen.gd`)是否對這些回傳值觸發
可辨識的拒絕音/拒絕視覺回饋,本規格未讀 `_confirm_at_cursor()` 之外呼叫 `click_tile()`
的完整脈絡,不代為斷言**——列入 Open Questions。GDD Visual/Audio §5 要求拒絕音與「靜默」
明確不同,若目前只是回傳一個被忽略的 Dictionary,即為尚未實作。

---

## 8. Data Requirements

**規則**(`.claude/rules/ui-code.md`):本畫面只讀資料、不直接改狀態;所有玩家動作透過
`BattleController` 的公開方法送出,由該類與 `BattleState` 決定是否接受。

| 資料元素 | 來源 | 更新頻率 | 格式(現況) |
|---|---|---|---|
| 地形 | `assets/data/levels/vs01_terrain.txt` → `Board.from_ascii()` | 載入時一次 | `PackedStringArray`(ASCII 逐字元:`.`/`,`/`#`) |
| 名冊/單位 | `assets/data/units/vs01_roster.txt` | 載入時一次 | 未逐一核對解析後型別 |
| 好感度連線 | `assets/data/affinity/vs01_affinity_links.txt` | 載入時一次 | `AffinityLink` 陣列,供 `AffinityRules.board_lines()` |
| 卡牌資料 | `assets/data/cards/vs01_cards.txt` + `vs01_card_text.txt` | 載入時一次 | 供 `CardDeck`,非本份範圍 |
| 可達格集合 | `Board.reachable_tiles()` → `BattleController.move_targets()` | 每次選取/盤面變動 | `Array[Vector2i]`,🔴 現況僅回傳 A,不含 B/Grid\B(見 6.3) |
| 攻擊合法目標 | `BattleController.attack_targets()` | 同上 | `Array[Vector2i]`,已含 LoS/射程/佔位判定 |
| 威脅範圍 | `BattleController.threat_targets()` | 同上 | `Array[Vector2i]`——回合層級查詢(GDD UI Requirements §1a 的逐敵拆分切面**未核對**是否已實作,目前簽章看似只回傳單一選取單位的威脅範圍,非「任一敵方單位」的通用查詢,列入 Open Questions |
| 傷害預覽 | `_phi.phi()` + `_state.preview_damage()` | 游標停在攻擊目標時 | `int`(僅合併後總數,無 `ATK`/`DEF` 拆解介面確認存在——見 5(a)) |
| 好感度預覽/現值 | `AffinityRules.bonus_for()` / `bonus_for_at()` | 同上 | `int` |
| 單位行動旗標狀態 | ⚠️ 未核對是否有公開 getter | — | 見 Open Questions U-T4 |

**本畫面不得直接寫入**上述任何來源;所有寫入經由 `BattleController.click_tile()` /
`select_unit()` / `end_unit_turn()` / `end_faction_phase()` 等既有公開方法(見 9 節)。

---

## 9. Events Fired

⚠️ **本專案沒有 analytics/telemetry 系統**(比照 `skill-card-play.md` 已登記的同一事實),
下表是遊戲狀態變更,不是分析事件。

| 玩家動作 | 對應方法(現況) | 遊戲狀態變更 | 訊號(現況已確認存在) |
|---|---|---|---|
| 選取單位 | `select_unit(id)` / `click_tile()` | 選取狀態改變,無盤面寫入 | `unit_selected(id)` |
| 取消選取 | `deselect()` | 選取清空 | `selection_cleared()` |
| 確認移動 | `click_tile()` → `_apply_move()` | 單位位置改變、移動旗標消耗 | `unit_moved(id, from, to)` |
| 確認攻擊(現況,單次) | `click_tile()` → `_apply_attack()` | 傷害套用、可能陣亡、攻擊旗標消耗 | `attack_resolved(attacker_id, target_id, damage, target_died)` |
| **確認攻擊(規格新增,兩段)** | 見 5(a) | 第一次確認**零狀態變更**(僅開面板);第二次確認才觸發上列同一組狀態變更 | 沿用既有 `attack_resolved`,不新增訊號 |
| 結束單位行動 | `end_unit_turn(id)` | 該單位轉「已行動」 | ⚠️ 未核對是否有專屬訊號 |
| 結束我方回合 | `end_faction_phase()` | 陣營切換、旗標重置 | `phase_changed(new_phase)` |
| 戰鬥結束 | (內部判定) | — | `battle_ended(outcome)` |

**不遞增/遞增 `combat_state_version` 的區分**(呼應 GDD ADR-0001 概念,比照
`skill-card-play.md` 既有表格精神):選取、取消、游標移動皆不算改變盤面;移動、攻擊結算、
陣亡皆算。本規格不重新定義該版本號機制本身,僅指出何時觸發屬 `battle_controller.gd`
既有職責,UI 層不得繞過。

---

## 10. Transition & Animation

⚠️ **本節多數項目未核對現況,不臆測動畫細節。**

| 轉場 | 觸發 | 規格要求 | 現況 |
|---|---|---|---|
| 移動 | 確認移動 | 路徑須依 GDD UI Requirements §3 決定性 tie-break 顯示,且與實際動畫路徑一致(`P-D3`) | ⚠️ **尚未實作路徑預覽本身**(見 6.3 節末段推論——`board_view.gd` 無 `_build_path` 一類方法),動畫是否走同一路徑無從核對 |
| 攻擊結算 | 面板二次確認(規格新增) | 結算飄字(`P-D5`):只顯示總傷害+`Φ`方向標記,0 傷害仍顯示 | ⚠️ 現況只有 `_info_label` 文字更新,是否有飄字動畫未核對 |
| 陣亡 | HP≤0 | 須有可視移除過渡,非瞬間跳變(GDD Visual/Audio §4) | 見 Open Questions U-T5 |
| 敵方回合演出 | `step_enemy_phase()` 跨幀 | 每步之間應有可讀停頓 | ✅ `ENEMY_STEP_PAUSE_SECONDS = 0.3`(`battle_screen.gd:287`) |
| 攻擊確認面板開關(規格新增) | 見 5(a) | 比照 `card_confirm_panel` 既有開關手法,無需另創新動效語言 | 尚未實作 |

**Reduce Motion**:本文件未核對專案是否已有 reduce-motion 設定入口;若有,GDD Visual/Audio
§6 第 4 點要求「動畫/轉場類回饋須有可讀的靜態終態」對本畫面全部轉場同樣適用,列入
Open Questions 而非新增假設。

---

## 11. Input Method Completeness Checklist

**Keyboard**
- [x] 移動、確認、取消、開/收手牌、跳轉目標、開選單皆有鍵盤路徑(7.1 節)
- [ ] 「結束該單位行動」的鍵盤路徑未核對(U-T8)
- [x] 全手把對等原則已知適用於本畫面(`P-I2` 無例外)

**Gamepad**
- [x] 十字鍵/左搖桿、A/B、X、RB/LB、Start 皆已對應(7.1 節)
- [ ] 攻擊確認面板(規格新增)的手把路徑待其落地時一併設計

**Mouse**
- [x] 滑鼠可移動游標、左鍵確認(`_handle_mouse_button()`)
- [ ] 滑鼠右鍵/滾輪行為未核對,若無對應功能應明確定義為無操作而非未定義

**Touch**
- 不適用(`.claude/docs/technical-preferences.md`:本專案無觸控支援)

---

## 12. Screen-Level Accessibility Requirements

依 `design/ux/accessibility-requirements.md`(Tier: Standard)。本節只記本畫面特有項目,
不重複專案級承諾。

**非色彩通道**(`P-F3` 無例外,現況已示範的手法):
- 威脅範圍(環狀)vs 攻擊範圍(實心)——形狀區分,已實作
- 卡牌目標合法/不合法——外框 vs 外框+X,已實作(`skill-card-play.md` 血量對比度修復批次)
- 🔴 移動範圍三態、攻擊範圍三層、行動旗標指示(6.3/6.1 節,尚未實作)**必須延續同一手法**
  (形狀/圖示/邊框,不得只用色相),落地時同樣需要灰階複驗(比照 `skill-card-play.md`
  HP 對比度修復批次的既有紀律)

**色盲友善**:三態/三層/四值高亮全部須通過灰階測試——本節與 5/6/7 節的「規格要求改動現行實作」
項目共用同一批驗收動作,不重複列。

**字級可調**:攻擊確認面板、格位資訊面板一旦落地,須通過 150% 放大不溢出安全區測試
(見 14 節)。

**焦點順序**:攻擊確認面板開啟時,確認鍵預設應落在「確認執行」而非「取消」——
⚠️ **這與 `P-M4`(破壞性動作確認,預設焦點在取消)不同**:攻擊在盤面上早已被三態高亮
與傷害預覽揭露過後果,玩家按下第一次確認鍵已表達明確意圖,第二次確認是「拆解後再看一眼」
而非「你可能誤觸的破壞性動作」——不宜比照離開遊戲的預設焦點規則。此為本規格的判斷,
待攻擊確認面板落地時由 `/ux-review` 覆核。

---

## 13. Localization Considerations

⚠️ 本專案目前**僅支援繁體中文**(`.claude/docs/technical-preferences.md` 未列多語言為
目標平台需求;無其他證據顯示已規劃在地化)。本節僅登記結構性風險,供未來若擴充多語言時參照,
不代表本畫面現階段需要投入在地化工程。

| 文字元素 | 現況長度 | 風險 |
|---|---|---|
| `TEXT_STATUS_FORMAT`("第 %d 回合．%s") | 短 | 低 |
| `TEXT_DAMAGE_PREVIEW_FORMAT`("打擊 %d　血量 %d→%d") | 中 | 中——若擴充英文,數字+箭頭排版須重新驗證寬度 |
| `TEXT_CONTROLS_HINT` | 長(雙行) | 高——已是雙行,若翻譯成擴張率高的語言(見 `skill-card-play.md` 已登記的 40% 擴張基準)可能三行溢出安全區,現況未測試 |
| 🔴 攻擊確認面板欄位標籤(規格新增) | 未定 | 待落地時比照 `skill-card-play.md` 確認面板欄位的既有處理方式 |

**全形/半形數字**:傷害、HP、`Φ` 帶號數值目前為 ASCII 阿拉伯數字混排繁體中文,
與專案既有慣例一致,無需特別處理。

---

## 14. Acceptance Criteria

> 依 `.claude/docs/coding-standards.md` Test Evidence by Story Type 分級。凡本節下方標記
> 「阻擋 Approved」的項目,對應 5/6/7 節登記的「尚未實作」缺口——這些 AC 目前**無法通過**,
> 不是漏寫測試。

**Layout & Rendering**
- [ ] 世界層在 1080p(N=4)、4K(N=8)兩種整數倍剛好填滿的解析度下,棋盤四周無留白裁切
      (`design/art/screen-architecture.md` 已實測數字,本畫面沿用不重驗)
- [ ] 世界層在 2560×1440、3440×1440 兩種有留白的解析度下,介面元素不依賴該留白版面
      (硬性約束,見 `screen-architecture.md`「介面不得依賴棋盤旁邊有空位」)
- [ ] 🔴 **阻擋 Approved**:移動範圍呈現三態互斥且窮盡(可達/不可達-移動力不足/
      不可達-被佔位擋死),三集合聯集等於整張棋盤,無第四類殘留——對應 GDD AC-13、`P-D1`
- [ ] 🔴 **阻擋 Approved**:攻擊範圍呈現三層(無疊加/合法可攻擊/範圍內但視線擋)——
      對應 GDD Visual/Audio §1.3
- [ ] 🔴 **阻擋 Approved**:格位資訊面板顯示 GDD UI Requirements §1 列舉的全部最小欄位
      (地形種類、`terrain_cost`、遮蔽旗標、佔位單位陣營/HP/當前行動旗標狀態、武器分層、當前 MP)
- [ ] 🔴 **阻擋 Approved**:攻擊確認面板顯示 `ATK`/`DEF`/`Φ`(帶號,`=0` 仍顯示)/結果傷害/
      目標結算後預估 HP,且與預判模式非同一 UI 元件——對應 GDD UI Requirements §4/§5、`P-M1`/`P-M2`
- [ ] 單位當前行動旗標狀態(皆未用/只剩攻擊/只剩移動/已行動)有非色彩通道的持久視覺標記——
      對應 GDD Visual/Audio §6.1、`P-F3`(無例外)
- [ ] 陣亡單位於同一結算步內從畫面移除,移除有可視過渡(非瞬間跳變)——對應 GDD Visual/Audio §4;
      現況是否已滿足**未核對**,不預先斷言通過或不通過

**Input**
- [ ] 全部操作(選取、移動、攻擊確認、取消、跳轉目標、結束行動、開選單)有不依賴滑鼠的路徑——
      `P-I2` 無例外;現況鍵盤/手把對應表(7.1 節)已涵蓋除「結束該單位行動」外的全部項目,
      該項路徑未核對,見 Open Questions
- [ ] 攻擊確認面板開啟期間,游標移動/開手牌/開選單皆被正確拒絕(見 7.5 節狀態限制表)
- [ ] 確認鍵的裁定狀態讀取發生在 `_process(priority=100)`,不在按鍵處理常式內——
      比照 `skill-card-play.md` 既有義務,新增的攻擊確認面板須同樣滿足
- [ ] 同幀鍵盤+手把各送一次確認,不得提交兩次攻擊(去重保護)

**Events & Data**
- [ ] 攻擊確認面板開啟(T2')期間發生的一切操作**零寫入**;僅面板上「再次確認」觸發
      `_apply_attack()` 的實際結算
- [ ] 移動/攻擊/威脅範圍疊加圖符合 GDD Core Rules #10 的即時性與單一快照原子性——
      對應 GDD AC-20/AC-22,本規格不重新定義,僅要求呈現層遵守

**Accessibility**
- [ ] 三態移動範圍、三層攻擊範圍、行動旗標指示、陣亡回饋,一律不得只靠顏色區分(`P-F3` 無例外)
- [ ] 全部新增互動(攻擊確認面板)在最小(960×540)與最大(3840×2160)測試解析度下不溢出安全區
- [ ] 格位資訊面板、攻擊確認面板的文字在 `HudLayout.font_size()` 150% 放大下仍不溢出
      (比照 `skill-card-play.md` 已驗證的 150% 判準,理由同該文件:無障礙 Standard 承諾字級可調)

**Localization**
- [ ] 本畫面全部面向玩家文字經由 `.claude/rules/ui-code.md`「不得硬編碼使用者文字」規則,
      走本地化系統——現況 `TEXT_*` 常數是否已走本地化管線**未核對**,列入 Open Questions

---

## 15. Open Questions

| # | 問題 | 擁有者 | 備註 |
|---|---|---|---|
| U-T1 | **攻擊確認面板的介面形狀**(`click_tile()`/`_apply_attack()` 是否需要拆成 propose/commit 兩段,或維持現有簽章、僅由 UI 層插入一次額外確認)——本規格只定案「必須有二段確認」,不定案 `battle_controller.gd` 是否要改公開介面 | `ui-programmer` + `godot-gdscript-specialist` | 阻擋 5(a)/7.3 落地,見兩節的「規格要求改動現行實作」 |
| U-T2 | ✅ **GDD 端已落地(2026-09-29 更正)**——原文下方保留供追溯:~~地形「不可通行」布林旗標的落地——本 session 管理者裁決採獨立 `passable` 布林旗標(非第四級成本、非極大成本模擬),`design/gdd/tactical-combat-system.md` OQ-10 由 `systems-designer` 同批處理,但本規格撰寫時實測 `grep -n "passable" src/gameplay/board/board.gd` 零命中、`grep -n "OQ-10" design/gdd/tactical-combat-system.md` 仍顯示該項為開放狀態——尚未確認 GDD 端是否已同步落地~~。**複查結果(2026-09-29)**:`grep -n "~~OQ-10~~" design/gdd/tactical-combat-system.md` 命中「✅ 已關閉 2026-09-29(管理者裁決)」,GDD 公式三/Edge Cases/AC-13 已新增 `passable`/`ignore_passability` 與第四種互斥分類。`grep -c "passable" src/gameplay/board/board.gd` 仍為 `0`——**此為刻意**:本批只動設計文件,程式碼落地是 #4 epic 的事,不代表 GDD 端未完成。①`board_view.gd` 需要新地形貼圖 + 對應第四種呈現狀態、②`interaction-patterns.md` 的 `P-D1` 改寫成四態——**兩項已於 2026-09-29 由本規格作者完成**(`design/ux/interaction-patterns.md` P-D1 目錄列與模式本體共 2 處,原三態文字以刪除線保留、四態內容緊接其後) | `godot-gdscript-specialist`(`board.gd`/`board_view.gd` 實作,#4 epic 範圍) | 阻擋 6.3 節第四態的**程式落地**(設計面已不阻擋) |
| U-T3 | **格位資訊面板的「未解析態」與「無資訊可顯示」是否需要區分**——見 5(c)。現況 `_info_label` 空字串手法在窄範圍情境下可接受,格位資訊面板(5(b))補齊後是否會踩到 `P-F1` 的區分要求 | `ux-designer` | 待 5(b) 落地時一併設計 |
| U-T4 | **單位剩餘旗標的公開查詢介面是否已存在**——`battle_controller.gd` 現有查詢皆是「選取後我能做什麼」的隱式判斷,未核對是否有「不選取也能查詢任一單位四態」的 getter;若沒有,`TurnOrder` 需新增 | `godot-gdscript-specialist` | 阻擋 6.1 節「行動旗標指示」與 §1 格位資訊面板欄位 |
| U-T5 | **陣亡移除的可視過渡是否存在**——`board_view.gd` 的 `render_pieces()` 現況為整批重繪,未核對是否有淡出動畫;若無,是否要在本系統或 #10 戰鬥 HUD 補 | `art-director` + `ui-programmer` | GDD Visual/Audio §4 |
| U-T6 | **`_input()` 對 T3 敵方回合逐步演出期間的輸入拒絕是否逐幀生效**——未讀 `_input()` 頂端守衛邏輯的完整條件,不代為斷言 | `godot-gdscript-specialist` | 6.2 節 T3 |
| U-T7 | **`click_tile()` 的拒絕回傳值(`{"action": "none"}` 等)是否觸發可辨識拒絕回饋**——未核對呼叫端处理,`P-F2` 要求拒絕不得靜默 | `ui-programmer` | 7.6 節 |
| U-T8 | **「結束該單位行動」的輸入路徑**——`end_unit_turn(id)` 存在但呼叫路徑未核對,`TEXT_CONTROLS_HINT` 未列出對應按鍵 | `ui-programmer` | 7.1 節;若無專屬路徑,可能違反 `P-I2` |
| U-T9 | **預判模式(Core Rules #8)是否需要獨立於攻擊確認面板另外設計**,或現有 hover 即時預覽已足夠滿足「三態摘要」語意——見 6.4 節 | `ux-designer` + `game-designer` | 待攻擊確認面板落地時一併決定 |
| U-T10 | **跳轉合法目標(Tab/RB)的排序是否為決定性且已測試釘死**——GDD UI Requirements §3 要求,`_apply_pending_target_jump()` 內文未讀 | `qa-lead` | 7.4 節 |
| U-T11 | **本畫面文字是否已走本地化系統**——`TEXT_*` 常數現況為 GDScript `const String`,是否經由本地化管線未核對 | `ui-programmer` | 14 節 Localization |
| U-T12 | **T7(權威寫入進行中)這個狀態窗口在現況是否真實存在**——若 `_apply_attack()`/`_apply_move()` 皆為單幀同步完成,AC-24 的重入防護窗口寬度可能為零、天然滿足;若未來改為跨幀演出才需要補閘門,本規格不預先假設答案 | `godot-specialist` | 6.2 節 T7 |
| U-T13 | **跨邊界確認**:回合層級剩餘旗標總覽(`P-D4`,GDD OQ-21)、傷害拆解面板的最終版面優先序、好感度逐條貢獻面板——三者皆明文歸屬 #10 戰鬥 HUD(GDD OQ-6),本規格的 5(a) 攻擊確認面板與 #10 未來面板之間**可能有版面重疊或元件重用機會**,若跨在邊界上,由下一輪核對而非本規格自行決定 | `ux-designer` + 戰鬥 HUD 系統(#10) | 明確登記,不擴大本規格範圍 |
| U-T14 | **戰鬥畫面如何被進入/離開**(從主選單?關卡選擇?勝負後去哪個畫面?)——3/4 節未核對,本規格不臆測 | `ux-designer` + `game-designer` | 3/4 節 |
| U-T15 | **`threat_targets()` 是否已支援 GDD UI Requirements §1a 要求的「任一敵方單位/多敵聯集+逐敵拆分」通用查詢**,或現況簽章只回傳「目前選取單位」的威脅範圍(語意與 §1a 的「敵方威脅範圍疊加圖」不同——後者查的是敵人的威脅範圍,前者現況命名雖為 `threat_targets` 但實際回傳的是選取單位自身的攻擊延伸,兩者可能是同一份程式碼被雙重期待)——本規格未讀 `_threat_targets_for()` 完整內文,不代為斷言,**這是本規格中最需要優先釐清的技術假設落差之一** | `godot-gdscript-specialist` | 阻擋 GDD UI Requirements §1a 的完整驗證,亦影響 6.3/8 節 |
