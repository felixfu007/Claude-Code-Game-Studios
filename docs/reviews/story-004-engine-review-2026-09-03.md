# Story 004 引擎正確性 + ADR-0005 契約符合度覆核(2026-09-03)

覆核者:godot-specialist(唯讀)
標的:`src/ui/cursor/cursor_types.gd` 本次新增部分(`classify()` / `classify_action()` / 三份 action 清單)、
`tests/unit/cursor/device_classification_test.gd`、`prototypes/story-004-ui-action-probe-2026-09-03/`

**覆核進度**:6 項全部查完。

---

## 1. `classify()` 是否結構性不觸及 `.device`

**狀態:查完 —— PASS**

- `grep -n "\.device" src/ui/cursor/cursor_types.gd tests/unit/cursor/device_classification_test.gd`
  只命中 `tests/unit/cursor/device_classification_test.gd` 第 113/117/136 行,且全部是**賦值**
  (`key_event.device = device_id` 等),用途是製造「裝置 ID 不同但應得到相同分類」的測試案例
  ——這是驗證不變性的正確技巧,不是禁令要防的「讀取後拿去做分類依據」。
- `cursor_types.gd` 本身(含 `classify()` L.110-115 與 `classify_action()` L.146-163)**零筆 `.device`**,
  不論讀或寫。
- 比對禁令登記表原文(`docs/registry/architecture.yaml:1829` `reading_input_event_device_id`):
  「Never classify an input device by `InputEvent.device`...Classify by the InputEvent SUBCLASS」——
  `classify()` 確實只用 `event is InputEventKey` 等子類別判定(L.111/113),結構性符合。
- 判定:**PASS**,禁令零違反,測試檔的 `.device` 賦值用法正當。

---

## 2. echo 過濾的實作位置與範圍是否正確

**狀態:查完 —— PASS(附一項低嚴重度前瞻性觀察,非缺陷)**

**位置**:過濾放在 `classify_action()` 函式最開頭、任何 `InputMap.event_is_action()` 查詢之前
(`cursor_types.gd:154-155`)。這與 ADR-0005 Status 區塊(L.22)的硬性義務「機制四之二必須自行過濾
`InputEventKey.echo`」在**函式層級**一致 —— 過濾發生在 `classify_action()` 內部,呼叫端無感知差異。

**範圍(NAVIGATION 與 CONFIRM 一律過濾,而非只濾 NAVIGATION)—— 獨立判斷如下**:

追蹤 ADR-0005 本文對 `ActionClass.CONFIRM` 與 `ActionClass.OTHER` 兩者在**下游所有已定案的消費點**
的實際待遇,兩者在目前規格下**完全同構,沒有任何分支會依它們的差異走不同路徑**:

1. 機制六 `arbitrate_device_authority()`(L.554-574):唯一有資格主張裝置權威的兩類是
   「(a) 鍵盤/手把的 **NAVIGATION** 類 `ui_*` action」與「(b) 滑鼠達門檻位移」(L.555-556)。
   CONFIRM 與 OTHER **兩者皆不在此列** —— 兩者都不會進入仲裁,不只是「仲裁後輸」。
2. 觸發點 (d)(同幀否決,L.570-573)的明文條件是「鍵盤/手把的 **NAVIGATION** 類動作依固定優先序
   勝出」,並且原文明講「僅有 CONFIRM 類時不成立,滑鼠奪權正常完成」——這句話本身就把 CONFIRM
   歸在「不觸發 (d)」的那一側,而 OTHER 類事件因為第 1 點根本連候選資格都沒有,**同樣不觸發 (d)**。
   兩者在這條路徑上的觀察行為相同。
3. 機制七 (c) 的完整性驗證(L.617)遍歷的是 `InputMap.get_actions()`(**action 名稱**),不是
   runtime `InputEvent` 實例 —— 與 echo(事件實例的屬性)無關,不受本次過濾範圍決定影響。

**結論**:在 ADR-0005 目前定案的規格下,把 echo 的 CONFIRM 事件併入 OTHER **沒有任何可觀察的行為
差異**——CONFIRM 與 OTHER 目前是兩個「不同名字、相同待遇」的桶。實作者程式碼註解裡的理由
(「CONFIRM 本來就不給權威,一併濾掉成本為零」)與上述獨立追蹤結果一致,判定成立。

**低嚴重度前瞻性觀察(不阻擋本 story,供 Story 005/006 留意)**:這個折疊會讓「這是一個被按住的
確認鍵重複事件」這個資訊在 `classify_action()` 的輸出邊界永久消失,變成與「這是一個完全未分類的
`ui_*` action」不可區分。目前規格沒有任何消費者需要這個區分,但若未來(例如對話快轉、長按確認)
需要區分「echo 的 CONFIRM」與「真正的 OTHER」,`classify_action()` 目前的輸出形狀已經丟失這個資訊,
需要在呼叫端另開一層才能補回。**這是設計選擇的已知代價,不是本次的缺陷。**

---

## 3. `classify()` 放在 `cursor_types.gd` 是否恰當

**狀態:查完 —— PASS(附一項低嚴重度 ADR 文件缺口,非 Story 004 缺陷)**

**確認 Key Interfaces 契約段(L.1329-1350)只列 `classify_action()`(L.1349),完全沒有
`classify()`**——`grep -n "classify("` 全文只在下列位置命中:機制四本文(L.390,程式碼區塊,
無檔案標頭)、機制四之二本文(L.407/438,散文引用)、Key Interfaces(L.1349,僅
`classify_action`)、Traceability 表(L.1567)。`classify()` 本身**從未出現在 Key Interfaces 契約
清單裡**,這點覆核前的提示已經講對。

**獨立判斷放置是否恰當**:

1. 機制四程式碼區塊(L.384-396)緊接在機制三的 `cursor_surface_registry.gd` 區塊(L.324-376)之後,
   **沒有新的 `# ─── xxx.gd ─── ` 檔案標頭**,語意上是模糊的接續,不是明確宣告的新檔案。
2. 但 `classify()` 回傳型別是 `CursorTypes.Authority`(L.390),而 `Authority` enum 已在
   `cursor_types.gd` 的檔案標頭區塊定案(L.257-269,`enum Authority { UNINITIALIZED, MOUSE,
   KEYBOARD_GAMEPAD }`)。`classify_action()` 是完全同構的先例:同樣是靜態純函式、同樣操作
   `CursorTypes` 底下的 enum(`ActionClass`)、同樣在機制四之二本文寫成不掛檔案標頭的程式碼區塊,
   而它**確實**被明文收進 Key Interfaces 的 `cursor_types.gd` 區段(L.1349)。
3. `encode_tile`/`decode_tile` 已由 Key Interfaces(L.1347-1348)確認落在 `cursor_types.gd`,
   顯示這個檔案的定位本來就不只是「enum 命名空間」,也包含與這些 enum 搭配使用的純靜態工具函式。
4. 沒有任何段落暗示 `classify()` 應該落在 `cursor_surface_registry.gd`(它與表面登記無關)或
   `cursor_target.gd`(它與目標值型別無關)。

**判定**:放在 `cursor_types.gd` 是與既有先例(`classify_action`、`encode_tile`/`decode_tile`)
一致、結構上站得住腳的選擇。**PASS。**

**低嚴重度 ADR 文件缺口(不歸咎於本 story 的實作)**:Key Interfaces 是 ADR 自己聲明的
「定案契約形狀」段落(L.1331),而 `classify()` 完全不在其中 —— 這比較像是 ADR 在
2026-08-19 新增 `classify_action()`(N1)那次修訂時,只把新函式補進 Key Interfaces,
沒有回頭把機制四原有的 `classify()` 也一併登記進去的遺漏。建議回報給 ADR-0005 的維護者
(非本 story 阻擋項,`classify()` 的存在與簽章在機制四本文與 Story 004 工作單裡都無歧義)。

---

## 4. 三份 action 清單的內容是否與探針量到的引擎實況相符;`ACKNOWLEDGED_OTHER_ACTIONS` 8 項是否都不是導覽類

**狀態:查完 —— PASS**

**與探針比對**(`prototypes/story-004-ui-action-probe-2026-09-03/logs/probe_output.txt`):

- `NAVIGATION_ACTIONS`(`ui_up`/`down`/`left`/`right`,4 項):探針 diff 全部標記
  `ok (NAVIGATION)`(L.180-183),且探針額外對這 4 個 action 呼叫真正的 `classify_action()`
  驗證回傳值為 `0`(即 `NAVIGATION`,探針輸出 L.274-277)。相符。
- `CONFIRM_ACTIONS`(`ui_accept`/`ui_cancel`,2 項):探針 diff 全部標記 `ok (CONFIRM)`
  (L.188/190),`classify_action()` 回傳 `1`(即 `CONFIRM`,L.278-279)。相符。
- `ACKNOWLEDGED_OTHER_ACTIONS`(8 項):探針 diff 全部標記 `ok (ACKNOWLEDGED_OTHER)`
  (`ui_menu` L.117、`ui_end`/`ui_home`/`ui_page_down`/`ui_page_up` L.176-179、
  `ui_focus_prev`/`ui_focus_next` L.184-185、`ui_select` L.189)。相符,無一遺漏或誤植。
- 探針宣稱「91 個 `ui_*` action、77 個未分類」與 log 逐項計數一致(L.192-194 + L.195-271
  逐一列名),與 `cursor_types.gd` 註解(L.77-90)的數字完全對得上,無誇大或落差。

**獨立判斷這 8 項是否真的都不是導覽類**(不只是「與 ADR 原文一致」,因為 ADR 原文自己也可能錯):

| Action | 引擎綁定(探針量到) | 語意 | 是否導覽類 |
|---|---|---|---|
| `ui_focus_next`/`ui_focus_prev` | Tab / Shift+Tab | Control 焦點於節點樹間跳轉(Tab 序) | 否 —— 且本系統的已註冊表面本來就禁止原生 focus/hover(`native_control_hover_or_focus_on_registered_surface` 禁令),Tab 序在此系統管轄範圍內無意義 |
| `ui_page_up`/`ui_page_down` | 翻頁鍵 | 列表/文字捲動翻頁 | 否 —— 非逐格移動,是捲動概念,與本系統的方向性游標移動無關 |
| `ui_home`/`ui_end` | Home/End 鍵 | 跳至行首/行尾、列表首/尾 | 否 —— 是「跳轉」不是「移動一格」,且與棋盤格游標語意無對應 |
| `ui_select` | Space + Joypad 頂鍵 | 列表/選單內選取項目(語意上更接近確認/切換,而非移動) | 否 —— 不論歸為 CONFIRM 還是 OTHER,都確定不是「移動游標」語意 |
| `ui_menu` | 選單鍵 | 開啟選單/內容選單 | 否 —— 與游標移動無關 |

八項逐一檢視皆確認非導覽語意,與 ADR 原文的預先分類結論一致,**不是實作者盲目照抄 ADR 就通過**,
而是獨立複核後結論相同。

**77 項未分類是否有漏網的導覽類**(工作提示明確要求:若有,屬本 story 缺陷而非 Story 006 範圍):
逐一瀏覽 77 項清單(`ui_text_caret_up/down/left/right`、`ui_graph_follow_left/right`、
`ui_filedialog_*`、`ui_colorpicker_delete_preset`、`ui_swap_input_direction` 等),
**全部屬於 `LineEdit`/`TextEdit`/`GraphEdit`/`FileDialog`/`ColorPicker` 等編輯器內建控制項的內部
操作語意**(文字插入點移動、圖表視圖平移、色盤預設值刪除等),**本專案的玩法完全不使用這些控制項**
(`cursor_types.gd` 註解 L.83-85 已如此聲明,經瀏覽清單內容獨立核實非虛)。這些 action 雖然名字
裡有「方向」字眼(如 `ui_text_caret_up`),但語意標的是文字插入點/圖表視圖,不是本系統定義的
「移動游標」(棋盤格/迷你地圖/卡牌槽/對話選項四種表面上的目標移動)。**判定:77 項中沒有一項應該
被移入 `NAVIGATION_ACTIONS`,本 story 在這一點上沒有缺陷。**77 項留給 Story 006 的完整性驗證器
處理,方向正確。

---

## 5. 探針的證據等級——(A) 級宣稱成不成立

**狀態:查完 —— PASS,(A) 級宣稱成立**

依 `technical-preferences.md` 的判準:「這次量測,是執行了專案的程式碼,還是重新實作了一份?」

- `probe_ui_actions.gd` 對「NAVIGATION/CONFIRM/OTHER 分類是否正確」這件事,**呼叫的是專案自己的
  `CursorTypes.classify_action()`**(L.74:`CursorTypes.classify_action(events[0])`),沒有另外
  重新實作任何分類規則。
- 對「三份清單是否涵蓋了引擎實際註冊的 91 個 action」這件事,探針做的是
  `CursorTypes.NAVIGATION_ACTIONS.has(action)` 這類**對專案自己陣列常數的成員檢查**
  (L.46-48),不是重新判斷某個 action 語意上算不算導覽類——那個判斷早已由人工寫入
  `cursor_types.gd` 的三個常數,探針只是核對「有沒有涵蓋」,不涉入語意判斷本身。
- 91/77 這兩個數字來自對**引擎真實 `InputMap.get_actions()`**的直接查詢(L.29-33),不是
  手打的假資料 —— 滿足「刻意未定義的邊界」段落排除的「拿假資料餵真類別」陷阱(這裡餵的資料
  就是真引擎狀態本身,沒有中間層)。
- 測試檔(`device_classification_test.gd`)的方法論一致:多處測試（如 L.144-193、L.219-252）
  改用 `InputMap.action_get_events(action)` 取得**真實註冊事件**,再餵給正式函式 `classify_action()`,
  而非手刻猜測的 keycode —— 這正是文件裡「優先讓引擎跑專案自己的類別」的作法。
- 交叉核對 VR #13 的既有探針(`prototypes/adr0005-engine-probes-2026-09-01/logs/probe13_and_3_headless.txt`):
  `event_is_action(pressed=true, echo=true, ui_up)` 與 `echo=false` 皆回傳 `true`,與
  `cursor_types.gd` 註解引用的證據逐字一致,未發現引用失真。

**唯一沒有滿足的次要慣例(不影響 (A) 級成立,但值得記錄)**:`prototypes/story-004-ui-action-probe-2026-09-03/`
目錄下只有 `probe_ui_actions.gd` 與 `logs/probe_output.txt`,**沒有 README.md**——探針腳本自己的
檔頭註解(L.1-20)已經包含技術偏好文件要求的「揭露規則來源」說明,實質內容不缺,但沒有依專案慣例
另立一份 README 供快速查閱。**低嚴重度的流程小疵,不影響本項判定。**

判定:**(A) 級宣稱成立**,理由與物證皆可獨立查證,未發現重新實作被誤標為執行專案類別的情形。

---

## 6. 有無「已裁決」「manager ruling」字眼而指不出紀錄位置

**狀態:查完 —— PASS**

- `grep -n "裁決\|manager ruling\|已核准\|已裁定\|使用者裁決\|管理者"` 對
  `cursor_types.gd`、`device_classification_test.gd`、`probe_ui_actions.gd` 三個本次產出檔案
  **零命中**——這三個檔案本身沒有任何自稱「已裁決」的文字。
- 唯一命中處在工作單 `production/epics/cursor-highlight-state/story-004-device-classification.md:73-74`:
  「🔴 本批未經 qa-lead 產生測試規格(**管理者 2026-09-02 裁決**:精簡模式,覆核關卡不跑;
  且本工作環境未經授權不得動用 Agent)。」——**這不是本次新增內容**(是工作單既有文字,
  非本次程式碼改動的一部分),但既然覆核指示要求逐處查,仍予以查證。
- 查證結果:**這項裁決有紀錄可指**。`production/session-state/active.md` 第二十七批
  (標題「2026-09-02 第二十七批寫入」,約 L.215-232)明文記載:
  「三道覆核關卡本批未跑(`TD-MANIFEST` / `PR-EPIC` / `QL-STORY-READY`,精簡模式 +
  本環境未授權動用 Agent),已明文寫進 `control-manifest.md` 檔頭與 `epics/index.md`。
  **管理者裁決**:先不跑,但要留紀錄。理由是只做一個系統試水溫,錯了很便宜。」
  ——工作單的引用與 `active.md` 的紀錄在內容與日期上一致,**不是冒用管理者名義的假裁決**。

判定:**PASS**。本次新增的三個檔案(`cursor_types.gd`、測試檔、探針)未見任何無法溯源的
「已裁決」字眼;工作單既有的那一句經查證為真實且可溯源的裁決。

---

## 附註:battle_screen.gd 的行內複本(超出「已知重複」範圍的觀察)

指示已明確本次刻意不動 `src/ui/battle/battle_screen.gd:371-380` 的機制四行內複本、且不需要
重複回報其存在。以下記錄一項**超出單純重複**的觀察,依指示的例外條款回報,供 Story 005 收斂時參考
(**非本 story 的缺陷,不影響本次判定**):

- `battle_screen.gd` 的方向鍵處理(`_handle_directional`,L.659-667)採**逐幀輪詢** +
  手動 edge-detection(`Input.is_action_pressed(action)` 比對前一影格快取值),而非
  `cursor_types.gd` 的**逐事件**分類(`classify_action()` 對每個 `InputEvent` 判定)。
  這是兩種不同的機制,不是同一段邏輯的複製貼上——輪詢式 edge-detection 本身不需要另外過濾 echo
  (echo 事件不會讓 `pressed_now and not was_pressed` 條件重新成立)。
- 確認鍵處理(L.383/387)呼叫的是 `event.is_action_pressed(&"battle_confirm")`
  ——這是 `InputEvent` 的方法,與 `cursor_types.gd` 使用的 `InputMap.event_is_action()`
  是**不同的引擎 API**。⚠️ **以下屬推測、本次未實機查證**:印象中 `InputEvent.is_action_pressed()`
  帶有 `allow_echo` 參數且預設排除 echo,若屬實,則這兩份「複本」對 echo 的處理**依賴的是兩個
  預設行為可能不同的 API**,而不是同一套邏輯的重複——今天兩者表現一致很可能只是巧合(battle_confirm
  沒有被玩家壓住不放測試過),而非同一份邏輯保證一致。**這點沒有本專案的探針或參考文件佐證,
  建議 Story 005 收斂複本時實機驗證 `InputEvent.is_action_pressed()` 的 echo 預設行為**,
  不應假設兩份「複本」在 echo 語意上真的等價。

---

## 總結判定

**總體:PASS**(6 項全數查完,無 BLOCKING/FAIL,零 forbidden pattern 違反)

| # | 項目 | 判定 | 嚴重度 |
|---|---|---|---|
| 1 | `classify()` 結構性不觸及 `.device` | PASS | — |
| 2 | echo 過濾位置與範圍 | PASS | 附一項低嚴重度前瞻觀察(CONFIRM/OTHER 折疊,Story 005/006 知悉即可) |
| 3 | `classify()` 放在 `cursor_types.gd` | PASS | 附一項低嚴重度 ADR 文件缺口(Key Interfaces 漏列 `classify()`,建議回報 ADR-0005 維護者) |
| 4 | 三份清單內容與探針相符、8 項非導覽類 | PASS | — |
| 5 | 探針 (A) 級證據宣稱 | PASS | 附一項極低嚴重度流程小疵(缺 README.md) |
| 6 | 「已裁決」字眼可溯源性 | PASS | — |

無一項需要退回實作者修正。三項低/極低嚴重度觀察均不阻擋本 story,建議一併轉交主 session 留存供
後續 story(005/006)參考。
