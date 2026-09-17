# Story U-007（戰鬥選單畫面 M0~M2 版面、原生 focus、上下導覽不繞回）測試證據

**Story Type**：UI
**日期**：2026-09-17
**執行者**：ui-programmer

## AC-M10（四螢幕 × 字級 100%,M1 落在安全區內;M0 覆蓋整個視窗,四周無亮邊）

**部分涵蓋**——依工作單第 4 節與 EPIC.md 限制表,75%/150% 字級功能未實作
（UX-5/BM-6),只驗 100% 檔的部分。M4 本身不在本 story 範圍（U-010),僅驗其
尺寸算術（見下方「版面驗算複驗」)。

### 自動化測試涵蓋（headless,`(A)` 級 —— 皆為呼叫 `HudLayout` 靜態函式，非重推公式）

`tests/unit/ui/menu/battle_menu_layout_test.gd`：
- `test_panel_rect_matches_hud_layout_font_size_and_safe_rect_at_every_defined_resolution`
- `test_panel_rect_stays_within_safe_rect_at_every_defined_resolution`（AC-M10 核心主張）
- `test_mask_node_resolves_as_colorrect_covering_full_rect`（決定層：Mask 錨點為
  FULL_RECT、四個 offset 皆 0,保證恆等於 BattleMenu 自身的完整 rect）

### 真實視窗擷圖（套用層,機械檢查 + 人眼確認）

**這一條需要真的開視窗擷取畫面**（headless 沒有渲染目標可擷取)。

`prototypes/u007-battle-menu-evidence-capture-2026-09-17/EvidenceDriver.tscn`
（拋棄式驅動場景,直接載入正式場景 `res://src/ui/menu/BattleMenu.tscn` 本體,
不是複本),以
`godot --path . prototypes/u007-battle-menu-evidence-capture-2026-09-17/EvidenceDriver.tscn`
執行（真實 GPU、非 headless)。逐字輸出見該目錄 `run_output.txt`。

⚠️ **本 story 的截圖規則只套用第 1/2/3/5 點,不套用第 4 點**（工作單第三節第 6 點 /
EPIC.md 陷阱十四明文,理由:本畫面全部在介面層,一般中文字型抗鋸齒文字在真實畫面
產生的網格違規比啟動畫面還多,第 4 點的判準對它是反的)。

| 解析度 | 擷圖尺寸=視窗尺寸 | 12 點抽樣相異色 | 主色佔比 ≤80% | M0 四邊/角像素一致 | 存檔 |
|---|---|---|---|---|---|
| 1920×1080 | ✅ 1920×1080 | ⚠️ **見下方說明** | 🔴 **0.9160,超過門檻** | ✅ 一致 | ✅ |
| 2560×1440 | ✅ 2560×1440 | ⚠️ **見下方說明** | 🔴 **0.9269,超過門檻** | ✅ 一致 | ✅ |

🔴 **兩項機械檢查沒有乾淨過關,誠實記錄如下(不是隱藏,是說明為何本案例套用
既有門檻會誤判)：**

1. **12 點盲測網格(coding-standards.md 原始規則)本身只量到 1 種顏色。**
   實測輸出逐字：`blind 12-point grid distinct colors = 1`。原因：該網格是為
   **世界層滿版內容**設計的(棋盤、單位涵蓋畫面大部分),而 M1 面板刻意是安全區內
   一個精確置中的小區塊(1080p 下僅 440×396,佔全螢幕約 8.9%)——4×3 均勻網格
   有很高機率 12 個點全部落在面板之外的遮罩區,量到「只有一種顏色」不代表畫面
   空白或錯誤,而是網格對這個版面形狀不敏感。**本檔額外加了取自
   `BattleMenu.panel_rect()`（不重推座標）的面板內取樣點**,盲測網格 + 面板感知
   點合併後兩種解析度皆為 **3 種相異色**,達到門檻——見驅動器程式碼與其 doc
   comment 對此的完整揭露。
2. **主色佔比兩種解析度皆超過 80% 門檻(91.6% / 92.7%)。** 這是「暫停選單本來就
   該是大面積暗色遮罩 + 一個小面板」這個設計形狀的直接後果,不是內容空白——
   已用第 5 點的人眼開圖確認畫面確實顯示完整選單(見下)。**但誠實地說,這條
   門檻本身是為了抓「全螢幕遊戲畫面主色佔比過高=可能是啟動畫面之類的空白幀」
   而設計的,套用到「模態選單本來就該以單一暗色遮罩為主」這種畫面形狀上,
   高佔比不具有同樣的判別力。這是本次交付發現、需要協調者/QA 判斷是否要
   為模態選單類畫面另訂門檻的一項,本文件不擅自更動規則本身。**

3. **M0 四邊/角像素一致性檢查(本檔為本 story 另加,量的正是 AC-M10 的直接主張)：**
   取視窗四個角落與四個邊中點共 8 個點,與面板外一個已知遮罩點(2,2)比較,
   兩種解析度**全部一致**——即遮罩確實從物理邊緣到邊緣連續覆蓋,沒有出現
   設計文件擔心的「安全區外留白發亮」現象。

### 人眼確認（規則第 5 條,機械檢查不能取代)

**本 agent 已用 Read 工具開圖檢視,以下四張截圖逐一確認**（1920×1080 / 2560×1440
各兩張:焦點在「回到遊戲」、焦點在「結束回合」)：

- `battle-menu-m1-focus-return-1080p-2026-09-17.png`
- `battle-menu-m1-focus-end-phase-1080p-2026-09-17.png`
- `battle-menu-m1-focus-return-2k-2026-09-17.png`
- `battle-menu-m1-focus-end-phase-2k-2026-09-17.png`

**確認內容**：畫面確實是完整的戰鬥選單（半透明深色遮罩壓暗背景、置中面板、
「回到遊戲」/「結束回合」/分隔線/「離開遊戲」三列文字皆可讀、焦點列有外框
+ `▸` 標記兩個通道、遮罩四周無亮邊)，不是空白幀、不是啟動畫面、不是版面跑掉。
2560×1440 這張額外確認了畫面架構裁決文件點名的「2K 有留白會亮」風險並未發生
——遮罩覆蓋到視窗邊緣，沒有看到任何未覆蓋的邊區。

⚠️ **本文件未經第二人（協調者）獨立開圖覆核**——依 coding-standards.md 前例，
建議協調者在核准本 story 前自行用 Read 工具再開一次至少一張圖，不要只信本回報。

## AC-M11（焦點與不可選狀態的截圖轉為灰階,仍可區分)—— 僅涵蓋焦點半部

📌「不可選」狀態要到 U-009 才有真實觸發條件（本 story「結束回合」恆為可選）,
本檔只驗證焦點視覺半部。

- `battle-menu-grayscale-focus-return-1080p-2026-09-17.png`
- `battle-menu-grayscale-focus-end-phase-1080p-2026-09-17.png`

**人眼確認**：灰階轉換後（Rec.601 亮度公式,`Y=0.299R+0.587G+0.114B`，本驅動器
自行揭露公式，不依賴 `Image.convert(FORMAT_L8)` 未經查證的確切權重），外框與
`▸` 標記在兩張灰階圖上都清楚可辨識、且會隨焦點移動而移動——兩個非色彩通道
（外框形狀 + 位置標記字元）在灰階下依然足以分辨焦點在哪一列，滿足 `P-F3`
「不得只靠顏色」的要求。

### 自動化測試涵蓋（headless,常駐敏感度證明）

`tests/unit/ui/menu/battle_menu_layout_test.gd`：
- `test_focus_visual_has_position_marker_not_color_only`
- `test_sensitivity_proof_focus_marker_detection_catches_missing_marker_logic`
  （突變子類別覆寫 `_on_row_focus_entered()` 使其不套用標記，證明偵測方式確實
  對「標記邏輯被拿掉」這一類迴歸缺陷敏感）

## AC-M13（焦點在「回到遊戲」按「↑」不繞到「離開遊戲」）

**完整涵蓋，兩層證據皆有：**

1. **決定層**：`return_row.focus_neighbor_top` 顯式指向自己（`"."`）。
2. **套用層**：真的用 `Viewport.push_input()` 注入真實 `ui_up` 事件（自
   `InputMap.action_get_events()` 抓取，不手猜 keycode），確認焦點確實留在
   「回到遊戲」列，沒有繞到「離開遊戲」。

`test_pressing_up_on_first_row_does_not_wrap_to_last_row` +
`test_sensitivity_proof_no_wrap_detection_catches_reintroduced_wrap`
（突變子類別把 `focus_neighbor_top` 誤指向最後一列，證明偵測方式確實對
「繞回」這一類迴歸缺陷敏感）。

引擎行為驗證見 `prototypes/u007-focus-navigation-probe-2026-09-17/`
（Claim 1/2，headless，真實呼叫 `Control.find_valid_focus_neighbor()` 與真實
`InputEventKey` 注入）。

## AC-M15（按 battle_menu → M1 完全可讀 ≤200ms）—— ADVISORY，間接/部分滿足

本 story 不含選單開關接線（U-008 才會呼叫 `battle_menu` 動作實際開啟畫面），
故無法測「按鍵到畫面出現」的端到端耗時。可驗證的是：`BattleMenu._ready()` /
`_apply_layout()` 全程同步呼叫（無 `await`、無非同步資源載入），意即一旦 U-008
把本場景加入樹並顯示，畫面在同一影格內即完整佈局完畢，不會因為本檔自身的邏輯
產生額外延遲——200ms 預算的消耗（如果有）將完全來自 U-008 的開啟時機與過場，
不是本檔引入的。

---

## ✅ 截圖證據規則第 5 點:人工開圖確認(2026-09-17)

**確認人:管理者本人。** 逐字回覆:「兩張圖看過了 OK」。

確認的檔案:
- `production/qa/evidence/battle-menu-m1-focus-return-1080p-2026-09-17.png`
- `production/qa/evidence/story-u011-hand-bar-s7-empty-2026-09-17.png`

**確認的問題是「這是它宣稱的那個畫面嗎」,不是「畫得好不好看」。**
🔴 **本節不得由任何 agent 代填。** 本次由協調者於管理者答覆後轉錄,
協調者另於同日先行代看 3 張確認非假圖 —— **代看不是簽核,兩者分開記錄。**

⚠️ **美術層面的四項視覺發現(鎖圖示不像鎖、圖示壓到「不」字、空手牌格對比極低、
焦點列文字因 `▸` 右移約 15px)不在本次確認範圍** —— 它們歸 `art-director`,
管理者尚未裁決是否現在派工。**本節的 OK 不涵蓋它們。**
