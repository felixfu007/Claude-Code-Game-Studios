# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.7.1
- **Language**: GDScript
- **Rendering**: Forward+ (Godot 4.7 default renderer)
- **Physics**: Jolt Physics (Godot 4.6+ default)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC, Console
- **Input Methods**: Keyboard/Mouse, Gamepad
- **Primary Input**: Keyboard/Mouse (full Gamepad support required for console parity)
- **Gamepad Support**: Full
- **Touch Support**: None
- **Platform Notes**: All UI must support both mouse hover/click and d-pad/analog-stick navigation equally — no hover-only interactions, since console has no cursor.

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables**: snake_case (e.g., `move_speed`)
- **Signals/Events**: snake_case, past tense (e.g., `health_changed`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`)

## Performance Budgets

- **Target Framerate**: 60 fps
- **Frame Budget**: 16.6ms
- **Draw Calls**: < 1000 (turn-based tactics — modest scene complexity, generous budget)
- **Memory Ceiling**: [TO BE CONFIGURED — set once content volume and target hardware are known]

## Testing

- **Framework**: **GdUnit4**(2026-08-19 `/test-setup` 由使用者裁決;此前本行寫 `GUT`,
  與 `coding-standards.md` 的 CI 指令 `tests/gdunit4_runner.gd` 互相矛盾——兩者是不相容的框架。
  判定 `GUT` 為範本預設值而非實際決定,理由:同區塊其餘欄位皆為未設定佔位符,
  而 CI 指令是具體到檔名的。基礎設施見 `tests/README.md`)
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->

**權威清單在 `docs/registry/architecture.yaml` 的 `forbidden_patterns` 節,連同每項的
完整理由(`why:` 欄)。本節不複述** —— 2026-08-21 實測發現散文複本已與登記表脫節
(散文寫「其餘 26 項」實際 27 項、「ADR-0005 共 11 項」實際 12 項),
且登記表的 `why:` 欄比散文摘要詳細數倍。複述只會製造漂移面。

🔴 **本節原有一張「逐節實測數」表,已於 2026-09-01 全庫稽核移除。**
它寫著合計 31、ADR-0003 為 1;實測是 **35 / 5**。而**同一份文件下方另一處寫的 35 是對的**
—— 一份文件裡兩個互斥的數字,**兩處都自稱「逐節實測」**。

**它移除的理由,正是它上方那段話自己說的**:散文複本會與登記表脫節。上方那段是在
2026-08-21 為了記取這個教訓而寫的,而這張表就寫在它正下方,然後照樣脫節了。
**要逐 ADR 的分佈就當場數**:

```bash
awk '/^forbidden_patterns:/{f=1} f&&/^    adr:/{print $2}' docs/registry/architecture.yaml \
  | sort | uniq -c | sort -rn
```

以下 3 項是**專案級身分/範圍裁決**,來源為 `design/gdd/game-concept.md` 而非任何 ADR,
因此在任何 ADR 被 `Accepted` 之前就已生效,寫在這裡供實作時直接查閱:

- **`rng_in_combat_settlement`** — 戰鬥結算路徑絕不可使用 RNG(無骰子、無隨機事件、
  無機率決定的結算結果,亦無機率造成的 permadeath)。
  **唯一豁免**:好感度對話卡牌的**牌面**隨機,但**發牌節奏固定**(`game-concept.md`
  第三輪 creative-director 裁決)——隨機只出現在「提供什麼選項」,絕不出現在
  「結算如何解出」。
- **`networking_features`** — 無連線/多人/線上功能,單機遊戲。
  (與 `TR-save-030` 的 Steam Cloud 待決問題無關:雲端**存檔同步**是平台提供的
  檔案層服務,不是本作的連線功能。)
- **`procedural_terrain_generation`** — 棋盤地形與其演變一律手工設計、劇情觸發,
  絕不程序化/隨機生成。

第 4 項專案級禁令是 **`abstract_func_with_body`**(抽象方法宣告必須是裸簽章,不可帶
`pass` 主體 —— 帶主體是**編譯期錯誤**,已實機驗證)。它 `adr: none`,因為根因在參考庫的
錯誤範例而非任一 ADR;ADR-0004/0005 兩份的症狀已於 2026-08-21 修畢,該條目仍
`active` 作為**前瞻性禁令**。

其餘各項由 ADR-0001~0005 各自推導,**一律查登記表,不在此複述**。
(此處原寫「其餘 27 項」,2026-09-01 稽核實測為 31,已改為不寫數字 —— 同上,手抄必漂移。)
查法:`docs/registry/architecture.yaml` 的 `forbidden_patterns` 節,每項都有
`pattern:`(名稱)、`adr:`(來源文件)、`why:`(完整理由與實測依據)。
## 流程劑量上限(2026-08-25 管理者裁決,自即日生效)

**權威全文在 `production/milestones/one-year-plan.md` 第六節②。本節是每次對話開場都會載入的
執行摘要** —— 寫在這裡的理由是計畫檔不會自動載入,規則若只寫在那裡就不會被遵守。

| | 規則 | 超過時怎麼辦 |
|---|---|---|
| 1 | 每個系統的設計文件 **≤ 400 行** | 拆系統,不是加行數 |
| 2 | 每份設計文件 `/design-review` **≤ 2 輪** | 第 2 輪殘留項降級為實作期處理,不開第 3 輪 |
| 3 | 架構文件(ADR)**只在跨系統契約時才寫** | 單一系統內部技術細節寫在該系統設計文件裡 |
| 4 | 同一份文件**不做第三次以上修訂** | 要改第 3 次表示該重寫或該擱置,不是該再修 |

**規則 1 有兩項明文例外(2026-08-31 裁決,不拆)**:`affinity-position-chain.md` 與
`tactical-combat-system.md` **兩份檔案本身**。理由與登記見計畫檔第六節②。
🔴 **是例外不是放寬,其餘文件仍為 400 行。**

⚠️ **例外登記的是「這兩份檔案」,不是某個行數。** 2026-09-01 稽核:原文在三處寫死
`tactical-combat-system.md` 為 1038 行,而它**在登記豁免的同一天、後續兩次提交就長到 1077**
—— 沒有任何人發現。這正是下一句警告的事,只是它自己也沒躲過:

> **行數上限沒有自動檢查。** 那份超限 2.5 倍,是上限生效六天後被順手量到才發現的。
> 要現值就當場量:`wc -l design/gdd/*.md`

⚠️ **只往後生效,不追改已完成的 5 份 ADR。** 拿新規則回頭砍已寫好的東西是重工而非改善。
**裁決背景**:28 天內產出 4 份設計文件 8857 行、16 輪 `/design-review`、7 輪
`/architecture-review`、**0 行遊戲程式碼**。該流程實測抓出過 18 處會讓程式跑不起來的呼叫寫法
與一個擴散到兩份文件的編譯期錯誤 —— **問題是劑量,不是有無。**
**實務後果**:剩下 6 個系統預期只會再產生 0~1 份新 ADR。

## 美術方向與像素風專案設定

**權威全文在 `design/art/art-direction.md`。** 2026-08-25 管理者裁決:像素風、開發者本人繪製、
**480×270 套裝**(立繪 128×128、棋盤單格 32×32、棋子 32×40、64 色、1px 描邊、
對話正文用一般繁體中文字型而非像素字型)。

### `project.godot` 相關設定(2026-08-25 `godot-specialist` 實機驗證)

驗證方式:本機 `Godot_v4.7.1-stable_win64_console.exe --headless`,於系統暫存目錄建立拋棄式
空專案,用 `ProjectSettings.get_setting()` / `get_property_list()` 直接向引擎讀取真實預設值與
enum 值域,並實際匯入測試 PNG 檢查產生的 `.import` 檔。**未觸碰專案根目錄。**

| 設定鍵 | 建議值 | 來源等級 |
|---|---|---|
| `display/window/size/viewport_width` / `_height` | `480` / `270` | (A) 鍵名與預設值 1152×648 已實測 |
| `display/window/stretch/mode` | 🔴 **`"disabled"`(2026-09-01 管理者裁決)** | (A) enum 三值已實測;**裁決依據見下方「畫面架構裁決」** |
| `display/window/stretch/aspect` | `"keep"` | (A) enum 已實測,預設即 `keep`;選用理由屬 (C) 設計推理。⚠️ `mode="disabled"` 下本鍵不再產生作用 |
| `display/window/stretch/scale_mode` | `"integer"` | (A) enum 僅 `fractional` / `integer` 兩值,已實測。⚠️ 同上,`disabled` 下不再產生作用 |
| `rendering/textures/canvas_textures/default_texture_filter` | `0`(Nearest) | (A) 預設實測為 `1`(Linear);已實測此設定**不寫入 `.import` 檔** |

**來源等級三分法**:(A) 實機驗證 / (B) 專案參考庫明文記載 / (C) 訓練資料推測、未經驗證。
**(C) 級不得當成既定事實引用** —— 本專案已實測抓到 18 處憑記憶寫錯的呼叫寫法。

#### 🔴 (A) 的精確定義:引擎必須執行過**專案自己的程式碼**(2026-08-31 補,因一次實際誤標)

**「我寫了一個腳本、讀了專案真實資料檔、跑出數字」不是 (A)。** 那是 (B) 或 (C) ——
取決於腳本裡那些規則是抄自何處。判準只有一條:

> **這次量測,是執行了專案的程式碼,還是重新實作了一份?**
> 凡腳本自行實作的每一條規則,該規則就**不是** (A) 級,不論腳本跑得多順、數字多漂亮。

**成因是本專案已知的失效模式,只是換了地方發作。** R2(`affinity-position-chain.md`)
記載:好感度與戰鬥模組各有一份曼哈頓距離實作,「只是今天答案一致」,而黑箱比對輸出
**永遠無法區分「共用同一份」與「兩份碰巧一致」**。拋棄式分析腳本會再長出第三份、第四份,
而且因為它「只是分析用」,沒有任何規則管到它。

**實際案例(2026-08-31,本規則的由來)**:`/design-review` 為裁決對立路線可行性寫了一個
awk 棋盤量測,結論被以「實機量測」名義寫進 GDD、審查紀錄與提交訊息。該腳本假定地形字元
`#` 不可通行 —— 但 `board.gd` 的 `MOVE_COST` 表**根本沒有「不可通行」這個概念**
(`#` 是倒木,成本 3、可以走,只擋視線)。發布的三個數字全錯。
**結論方向沒有反轉純屬運氣,不是流程擋下來的。**
⚠️ **這種錯不留痕跡** —— 假設錯誤的腳本會順利跑完、輸出漂亮的數字、看起來完全正常。
subagent 中斷至少會弄壞程式庫;這個不會。

**因此,凡量測結果要進入設計文件或架構決策**:

1. **優先讓引擎跑專案自己的類別**(headless GDScript 或拋棄式 GdUnit4 測試,直接呼叫
   `Board` / `CombatRules` / `AffinityRules`),而不是用 awk/bash/其他語言重寫一份規則。
   本專案已具備此能力 —— 測試指令見 `coding-standards.md`。
2. **做不到時,腳本必須列出它重新實作的每一條規則,並逐條標明真值來源**
   (檔案 + 符號),讓下一個人**不必相信作者**就能逐條查證。
3. **一併揭露刻意未計入的因素**(例:視線、移動力、佔位)。未揭露的簡化與錯誤的假設,
   對讀者而言無法區分。
4. 🔴 **凡文件裡寫下「(A) 級」,必須同時附上它實際執行的那支檔案的路徑**
   (spike 腳本、拋棄式 GdUnit4 測試、或正式測試檔皆可)。**沒有附檔案路徑的
   「(A) 級」不成立,一律降為 (C)。**
   **這一條是前三條唯一的執行手段。** 2026-08-31 第二輪查核發現:第 1~3 點全部是
   寫給「未來寫量測的那個人」看的自律要求,而專案裡沒有任何 skill、lint 或閘門會在
   「(A) 級」這個標籤被寫進文件前查核它 —— 亦即這條規則本身,結構上與它要防的東西
   (一個沒被覆核的單人作者宣告自己嚴謹)一樣脆弱。
   ⚠️ **附檔案路徑不等於自動檢查**,它只是把「純自述」變成「自述加上可查證的物證」:
   第三方不必相信作者,可以自己打開那支檔案,逐條核對第 2 點的規則來源與第 3 點的
   未計入因素。**本專案的前例說明為何連這麼低的門檻都值得設**:`docs/CLAUDE.md` 的
   `TD-ADR` 覆核閘門是「規則存在、無人執行、且不執行不留痕」,九次 ADR 修訂全部跳過,
   而跳過這件事本身沒有留下任何紀錄。**一條沒有物證要求的規則,它有沒有被遵守
   是不可觀測的。**

##### 兩項刻意未定義的邊界(2026-08-31 第二輪查核提出,管理者裁定暫不立法)

以下兩種情況目前**沒有規定**,而且是刻意的 —— 兩者都還沒真的害過人,現在立法等於
對假想情況立法。**碰到時停下來問,不要自行類推:**

- **輸入資料的真偽不在判準內。** 本節只管「有沒有跑專案的類別」,沒管餵進去的是不是
  真實關卡資料。拿手打的假 ASCII 地形去呼叫真的 `Board.from_ascii()`,字面上完全符合
  (A) 級,卻在回答一個不存在的棋盤的問題。(2026-08-31 那次量測讀了真實的
  `vs01_terrain.txt` / `vs01_roster.txt`,但那是做法剛好正確,不是本節要求的。)
- **混合情況沒有等級可標。** 若 4 個數字裡 3 個來自真實類別呼叫、1 個來自自製 helper,
  三分法沒有對應的標籤。第 2 點把揭露粒度降到**逐條規則**,卻沒說怎麼把逐條結果收斂回
  一個總標籤。⚠️ 附帶澄清:2026-08-31 的 OQ-7 二次重驗**不是**這種案例 —— 該次四項
  數字全部來自真實類別呼叫、一條規則都沒重新實作,**故本節從未被真正的混合案例測試過。**

### ⚠️ 三項會反噬的實測事實

1. **`stretch/mode` 絕不可設 `"viewport"`。** `godot-specialist` 第一輪建議該值,第二輪自行撤回:
   已實測 `CanvasLayer` 的繼承鏈為 `CanvasLayer → Node → Object`,**不繼承 `Viewport`**,
   因此該模式下介面**無法**逃脫低解析度緩衝區,對話文字會模糊。**照第一輪報告寫入的話,
   要等到排完介面才會發現。**
2. **貼圖濾波是最可逆的設定,不是不可逆的。** 它不是逐檔案的匯入期設定;即使匯入 30 張圖
   才發現模糊,改該單一設定即可,**無須重新匯入任何檔案**。唯一副作用:若有節點的
   `texture_filter` 被手動從 `Inherit` 蓋掉,需人工挑出改回。
   **真正不可逆的只有基礎解析度。**
3. **世界層/介面層分層要用 `SubViewport` + `SubViewportContainer`**,並以
   `SubViewportContainer.stretch_shrink` 讓引擎自動反推內部緩衝區尺寸 ——
   **不可手動設定 `SubViewport.size`**。
   ⚠️ **2026-08-26 修正機制描述**:本項原寫「容器會在下一 frame 覆寫回去」,
   實機驗證(`godot-specialist`,headless,`stretch=true` 時對 `SubViewport.size`
   手動賦值 `(9999, 9999)`)顯示這個描述**不準確**——引擎並非「先改了、下一格再
   改回來」,而是**當場拒絕這個賦值**,賦值前後讀回的值一路維持容器反推出的
   `(480, 270)`,從未變成 `(9999, 9999)` 哪怕一個畫格。引擎印出的警告逐字:
   ```
   WARNING: Can't change the size of a `SubViewport` with a `SubViewportContainer`
   parent that has `stretch` enabled. Set `SubViewportContainer.stretch` to `false`
   to allow changing the size manually.
      at: _internal_set_size (scene/main/viewport.cpp:5627)
   ```
   **結論不變**(不要手動設定 `SubViewport.size`),但機制是「賦值被擋下」不是
   「賦值後被覆寫」——除錯時循「賦值生效但被覆寫」的方向找,會找錯地方。
   另:`SubViewportContainer.texture_filter` 預設 `Inherit`,**須手動覆寫為 Nearest**,
   否則世界層貼回外層畫面那一步仍會被 Linear 模糊一次。此項極易漏掉。

⚠️ **跨文件衝突 —— 世界層那一半已實測結案,介面層那一半仍開**
(2026-08-27 實測,2026-09-01 補寫回本檔)

分層後畫面表面上有兩套座標系(介面收原生座標、世界層收 480×270 座標),轉換發生在
`SubViewportContainer` 邊界。**擔心 ADR-0005「單一根 Viewport 假設」因此不成立** ——
已由 `prototypes/board-render-input-spike-2026-08-27/` 實測回答,判定 **條件成立**
(非 headless、真實 GPU、四種視窗尺寸、來回換算 20/20 自洽;主 session 另以
`_verify/` 四個最小場景獨立複驗):

- **條件一**:世界層容器以滿版錨點貼齊基準畫布,起點恆為 `(0,0)`。
- **條件二**:換算一律呼叫引擎的 `Window.get_final_transform()`,**不自己重刻**
  `stretch`/`keep`/`integer` 公式。

兩條同時滿足時,數學上收斂成**單一個仿射變換 + 一個固定位移**,呼叫端只需一條轉換公式,
不必為世界層/介面層各維護一套。**條件二是紀律要求,不是自動保證** —— 手刻公式在非 16:9
視窗會悄悄算錯而不報錯。

✅ **另一半也已於 2026-09-01 關閉**(VR #11b:「承載自繪游標的 `CanvasLayer` 全程維持恆等變換」)。
`prototypes/ui-canvas-scale-spike-2026-09-01/` 實測結論:**決定它安不安全的不是介面基準畫布選什麼,
而是游標圖層有沒有自己獨佔一顆節點** —— 而 ADR-0005 本來就是這樣設計的(Autoload `CursorStateHost`
持專屬 `CanvasLayer`),專屬節點下四種解析度實測全部恆等。同批實測另確認本檔原先推導的前提成立:
該 Autoload 掛在 `/root`、不在 `SubViewport` 內,四種解析度下 `get_viewport() == get_tree().root` 皆為真。

🔴 **但它留下一條實作義務,不是「沒事了」**:若架構上誤把游標圖層與介面圖層混成同一顆節點,
實測誤差為 1080p **1440px** / 2K **2178px** / 4K **3304px** —— 游標系統實質失效。
**必須把「游標圖層 transform 恆等」寫成一條會執行的自動化測試,不得只靠紀律。**

### 🔴 畫面架構裁決(2026-09-01 管理者裁決,連帶改動上表)

**權威全文在 `design/art/screen-architecture.md`,逐項數字與 log 在
`prototypes/ui-canvas-scale-spike-2026-09-01/README.md`。本節只記會影響寫程式的三件事:**

1. **`window/stretch/mode` 改為 `"disabled"`** —— 原 `"canvas_items"` 下,`keep`+`integer` 的
   縮放很少剛好填滿視窗(2K 為 480×5.333 → 取整 5),**剩下那圈留白是引擎渲染目標沒有涵蓋的範圍,
   物理上不存在,任何 transform 都畫不進去**(實測:2560×1440 視窗截圖尺寸為 2400×1350)。
2. **介面設計基準畫布 = 當下螢幕實際解析度**,不設固定基準、不做二次縮放。
   理由是 HUD 用的 Cubic 11 是 11×11 點陣且放大 2 倍使用,固定 1920×1080 基準在 2K 上
   合併縮放為 2.667 倍,實測像素塊 2/3px 交錯、肉眼可見鋸齒。
3. **世界層縮放與定位改為手動管理**,引擎不再自動整數縮放 —— **整數對齊要自己保證。**
   規則:**取該螢幕塞得下的最大整數倍,永遠置中**。實際結果(2K/超寬為實測,1080p/4K 為算術):

   | 螢幕 | 倍率 | 棋盤尺寸 | 剩餘邊區 |
   |---|---|---|---|
   | 1920×1080 | 4× | 1920×1080 | **零** |
   | 2560×1440 | 5× | 2400×1350 | 四周 80 / 45 px |
   | 3840×2160 | 8× | 3840×2160 | **零** |
   | 3440×1440 | 5× | 2400×1350 | 左右各 520 px |

🔴 **由第 3 點導出的介面硬性約束(排任何介面前必讀)**:
**介面不得依賴「棋盤旁邊有空位」** —— 兩種最常見的螢幕(1080p、4K)邊區為零。
對話框、HUD、好感度關係圖**必須設計成疊在棋盤上方**(半透明 / 可收合 / 遷入遷出),
**不得設計成佔用側邊固定欄位的版面。** 連帶:黑邊裝飾邊框一項已因前提消失而取消。

⚠️ **兩項連帶義務,不會自動解決**:世界層倍率/位置要自己寫程式管;**字級要自己訂一套隨螢幕
調整的規則**(基準等於實際解析度,代表 20px 的字在 4K 上仍是 20px,相對螢幕顯著變小)。
後者是 `ux-designer` 同日評估中最擔心的一項,**本裁決沒有消除它,是把它從引擎自動處理
換成我們自己處理。排介面前必須先訂這套規則。**

⚠️ **同一支 spike 另外抓到一個正式檔案的缺陷並已修掉**:`src/ui/GameRoot.tscn` 原本根節點是
`Node2D`,而 `SubViewportContainer` 掛在 `Node2D` 底下**錨點永遠不生效**(容器恆 `(0,0)`、
內部畫布恆 `2×2px`,世界層會整片糊掉)。實測 `Node` 與 `CanvasLayer` 兩種父節點正常,
**裸 `Control` 同樣壞掉**。現行檔案根節點已是 `Node`。

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- **GdUnit4 v6.2.1** — 單元測試框架。**本專案第一個相依套件**,2026-08-26 安裝。
  來源 `godot-gdunit-labs/gdUnit4`(倉庫已自 `MikeSchulze/gdUnit4` 遷移)。
  🔴 **`addons/gdUnit4/` 進版控**(2026-09-01 實測:git 追蹤 **512 檔 / 約 1.9 MB**;其中 GDScript
  原始碼 **236 檔 / 約 1.3 MB**。原寫「272 檔,約 484 KB」,**三種算法沒有一種對得上**,已更正)。
  理由:版本被釘死在提交裡,
  CI 不需要抓取步驟,任何人 clone 下來測試指令就能跑。抓取式安裝會讓 CI 多一個對外相依,
  而且不同時間 clone 可能拿到不同版本 —— 本專案已為「憑記憶對著沒驗證過的 API 寫程式」
  付過代價,不需要再加一個「不同人跑的是不同版本」的變數。
  ⚠️ **測試報告 `reports/` 不進版控**(每次執行重新產生,已加入 `.gitignore`)。
  ⚠️ **GdUnit4 預設拒絕 headless 模式**,CI 指令必須帶 `--ignoreHeadlessMode`,
  詳見 `coding-standards.md` 的 CI 指令列(含 exit code 101 的完整說明)。

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
**修訂歷史全文在 `docs/architecture/adr-revision-history.md`。** 本節只記現況。
2026-08-21 起本節不再累積修訂敘述 —— 該檔每次對話開場載入,歷史屬按需查閱。

**核准門檻**:`docs/architecture/adr-acceptance-criteria.md`(白話,含五個必要條件與
五項明確不阻擋核准的事)。**立場登記表(權威來源)**:`docs/registry/architecture.yaml`,
🔴 **本行刻意不寫項數。** 2026-09-01 全庫稽核實測:同一個項數在四個檔案有 **81 / 85 / 87**
三個並存的值,而**被指定為權威來源的登記表檔頭本身是錯的**(寫 85,實測 87)——
亦即「有疑義以登記表為準」這句話當時會把人導向錯的數字。手抄的數字必然漂移,故不再抄。

**要數字就當場數**(一秒,結果永遠是真的):

```bash
awk '/^state_ownership:/{s="state"} /^interfaces:/{s="interface"} /^api_decisions:/{s="api"} \
     /^forbidden_patterns:/{s="forbidden"} /^  - /{c[s]++} END{for(k in c) print k, c[k]}' \
    docs/registry/architecture.yaml
```

✅ **2026-08-25:ADR-0002、ADR-0003 兩份已 `Accepted`**(管理者同批裁決;0003 的核准條件五就是
0002 已核准,故必須同一次動作)。**ADR-0001、0004、0005 三份仍為 `Proposed`。**
依 `docs/CLAUDE.md`,引用 `Proposed` ADR 的 story 會被自動阻擋 —— 這擋的是 `src/` 正式開發,
**不擋 `prototypes/` 的驗證性試作**。`/story-readiness` 已於同日補上遞迴追 `Depends On` 鏈與循環偵測,
因此「已核准的壓在草案上」不再會被自動放行。

| ADR | 主題 | 最近動作 | 現在卡在什麼 |
|---|---|---|---|
| 0001 | 戰棋查詢介面原子性契約 | 2026-08-18 建立,**從未修訂**;引擎專家已於 `#4` 第四輪查核(2026-08-31 更正,見下) | ⚠️ 卡在核准門檻**條件一與條件四**:①它自列 6 項待驗證全部未做,但**其中只有 4 項需要跑引擎探針**——第 (5) 項是一條要寫的自動化測試、第 (6) 項是程式碼審查檢查項(結算鏈不得有 `call_deferred()`/`CONNECT_DEFERRED`),而該系統尚無程式碼,那一項現在**無從做**而非未做;②**架構總監覆核對本份未跑過**。<br>🔴 **2026-09-01 稽核兩處更正**:(a) 原寫「6 項全部需碰真引擎」不精確,實際 4 項,**這會改變排程**(四支探針 vs 六支);(b) 原寫「這一項對五份 ADR 皆然」**是假的** —— `adr-acceptance-criteria.md`、`adr-0003` 本體、`architecture.yaml` 檔頭三處一致記載 **2026-08-24 對 ADR-0003 執行過**(CONCERNS → 窄範圍複驗 APPROVE)。該句在 2026-08-21 為真,之後沒改。**差別是「要從零建一道流程」還是「照抄現成前例」。** |

> 🔴 **本列於 2026-08-31 更正:原寫「從未驗證…唯一未被檢查過的一份」,不準確。**
> `godot-specialist` 確實在 `/design-review tactical-combat-system.md` 第四輪對本 ADR
> 四個面向逐項查核、判零 BLOCKING,**而且那次查核產出了三條實質新約束**
> (禁止 deferred 路徑介入結算、`settlement_in_progress` 卡死偵測、跨幀協程的宿主
> 生命週期約束)—— 那不是一次空轉的檢查。
> **差別會改變下一步該做什麼**:它不是一份沒人看過的文件,而是一份**看過文件層、
> 沒碰過引擎層**的文件。前者要從零審一道,後者要跑 6 支實機探針。
> ⚠️ 另註:第七輪 `/architecture-review` 中 `godot-specialist` 明確自陳**未逐行比對
> 本 ADR**,故該輪對本份的判定是「未查證」而非「零命中」—— 這兩件事也不一樣。
| 0002 | 好感度數值池資料結構與並發契約 | ✅ **2026-08-25 `Accepted`**(收斂批次補完三個未宣告型別、關閉 VR#9/#11/#12) | 可開始寫正式程式碼。剩下的皆不阻擋:證據搬家、登記表三項提案、VR#4/#7 未量測。第八輪獨立審查優先查核點:第一輪覆核後才產生的兩項修正、`can_write()` 簽章、`pair_of()` 保護等級 |
| 0003 | 存檔系統序列化格式與型別安全 | ✅ **2026-08-25 `Accepted`**(2026-08-24 六組必修已執行完畢;2026-08-25 再修三項並修掉參考庫根因) | 可開始寫正式程式碼。剩下的皆不阻擋:技術總監列的 8 項(B-1~B-8,B-6 已修)、延後項見 `adr-0003-deferred-to-implementation.md`(41 項)。⚠️ 歷史教訓保留:2026-08-21 探針曾推翻其全文 18 處呼叫寫法 |
| 0004 | 存檔系統原子寫入與遷移執行模型 | 事實層修訂 2026-08-21(零決策變更) | 待第八輪。已知缺口 1 項:雲端存檔同步無人擁有 |
| 0005 | 單一游標/高亮狀態系統:裝置權威輸入架構 | 第四次修訂 2026-08-21 | 待第八輪。1609 行、四次修訂,是否凍結未決 |

**最新權威涵蓋數字**:見 `docs/architecture/traceability-index.md`(**唯一來源,本行不複述**)。
⚠️ 2026-09-01 稽核發現該組數字散在 **6 處**;同輪另發現追溯索引把 `TR-concept-012`/`-014`
誤判為「尚未登記」而實際 2026-08-18 已登記 —— **修正後總數會變動**,故此處不再抄任何數字。
三個 Foundation 系統合計 73 項**只有 1 項缺口**。判定 CONCERNS。
**第八輪從未執行** —— 上表「待第八輪」全部指同一次尚未進行的審查。

**跨文件銜接缺口**:C1~C7 **全部已關閉**。C1~C6 於第五輪關閉;**C7 於 2026-08-21 由兩側各自
關閉**(ADR-0005 第四次修訂自行認定依賴層 B,不再被 ADR-0002 單方面記帳),見
`docs/consistency-failures.md` 的模式 G 節。
(2026-09-01 稽核更正:本行原寫「C7 仍開」,而 `consistency-failures.md` 早已記載它關閉。
**兩邊講相反的話,而本檔每次對話開場載入** —— 照它做的人會去找一個不存在的洞。)

**重複失誤紀錄**:`docs/consistency-failures.md`(七種模式 A~G,其中「修東西反而修出新
問題」已第九次)。撰寫或修訂 ADR 前請先讀該檔。

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
