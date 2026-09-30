# Epic:本地化(i18n)基礎設施

> **層**:Cross-cutting Infrastructure
> **權威文件**:無 GDD(基礎設施,非遊戲系統 —— 先例 `screen-scaling`)
> **狀態**:🟢 **Ready**(2026-09-29 管理者裁決四項全數表態,見下方「需要管理者裁決的事」節的裁決紀錄。原狀態行為 `Draft(骨架完成,待管理者裁決本檔「需要管理者裁決的事」節後可過 Ready)`,條件已成立)
> **Stories**:~~待切分(草案見下方「Stories」節,本批不建立 story 檔)~~ → ✅ **2026-09-30 已切分完成**(`localization-lead`):`story-index.md` + `story-001`~`story-003` 三張完整 story 檔,**權威清單是 [story-index.md](story-index.md)，下方「Stories」節是切分前的草案，逐字保留供追溯、不再是正本**。
> **建立日期**:2026-09-29

## 為什麼這個 epic 存在

**2026-09-29 管理者裁決「現在就建翻譯機制」**——選的是非建議選項:協調者原建議
「明文決定本階段只出繁體中文、現在不建本地化基礎設施」,管理者選擇現在就建。
逐字理由見 `production/epics/tactical-combat/EPIC.md` 對本項的登記:這件事
**「做完再改成本高」**。

背景是 `tactical-combat` M1 開工前查證(`docs/reviews/tactical-combat-m1-current-state-audit-2026-09-29.md`
U-T11)實測:專案**零本地化基礎設施**。詳細指令與輸出見下方「現況查證」節。

📌 **對照本專案已登記的教訓**(`production/epics/index.md`):`screen-scaling` 的裁決
記在 8 個檔案裡,三天內沒有進入任何排程,純屬巧合才被發現。**本 epic 的存在就是不重演
那一次** —— 把「裁決」直接變成「工作單擁有它」。

## 🔴 這個 epic 沒有 GDD,也不會有

它不是遊戲系統,是跨切面基礎設施 —— 先例是 `screen-scaling`(呈現層基礎設施,已 Complete)。
差別在於 `screen-scaling` 只服務一個消費者(戰鬥畫面),本 epic 服務**全專案未來所有
會顯示文字的系統**,包含現有的 `tactical-combat`、`card-play-interface` 與尚未動工的
`affinity-position-chain`。

⚠️ **是否需要一份 ADR 記錄 `project.godot` 設定與 key 命名慣例,本 epic 不自行認定**——
依 `.claude/docs/coding-standards.md`,ADR 只在跨系統契約時才寫。本地化基礎設施是否構成
「跨系統契約」是一個技術架構問題,已列入下方「需要管理者裁決的事」,建議會同
`technical-director` 判斷,不是本 localization-lead 單方決定的事。

## 現況查證(2026-09-29,逐條指令與原始輸出)

派工單指定的三條指令,逐字執行:

```
$ grep -rn "\btr(\|TranslationServer\|translations" src/ --include=*.gd
(零命中,exit 1)

$ grep -n "locale\|translation" project.godot
(零命中,exit 1)

$ grep -rn "^const TEXT_" src/ --include=*.gd
(21 行命中,3 個檔案:battle_screen.gd 15 行、card_confirm_panel.gd 5 行、hand_bar.gd 4 行)
```

🔴 **第三條指令本身會低估範圍,已用補充查證確認**——完整分佈與遷移範圍見下方 Q2,
這裡只記結論:**實際是 4 個 `.gd` 檔案 27 個字串常數 + 2 個 `.tscn` 檔案 6 個裸字串,
命名慣例不一致**(`battle_menu.gd` 的 6 個常數不用 `TEXT_` 前綴,派工單給的 pattern
一個都抓不到)。

## 五個必答問題

### 1. Godot 4.7.1 的本地化管線具體是什麼

⚠️ **依 `docs/engine-reference/godot/VERSION.md` 的警告,本節只採信頂層兩份已更新到
4.7.1 的文件(`current-best-practices.md`、`breaking-changes.md`),不採信 `modules/`
(8 份卡在 4.6,且 `ui.md` 正是 VERSION.md 點名「這條捷徑是空的」兩份之一)。**

已查證(來源:上述兩份頂層文件,逐條標明版本):

- Godot 內建 `tr()` 函式 + `TranslationServer` + CSV 為底的 `Translation` 資源,是引擎
  原生管線,不是要自建的東西。
- **4.6 起 CSV 原生支援複數形式與 context 欄,不再需要 Gettext(`.po`)**
  (`breaking-changes.md` 第 39 行:「No longer requires Gettext for plurals. Context
  columns added.」)。這解決了本 agent 標準裡「使用 ICU MessageFormat 或等效方案處理複數」
  的需求 —— Godot 的 CSV 複數欄是「等效方案」,不需要另外接 ICU 函式庫。
- 編輯器有「Live translation preview」,可在編輯器內直接切語言預覽版面
  (`current-best-practices.md` 第 105 行,標記 4.5+)。

🔴 **未查證,標記清楚、不要填空**:

- `project.godot` 的 `[internationalization]` 區塊具體鍵名(例如 locale 清單、
  fallback locale 怎麼設定)—— 頂層兩份文件沒有逐鍵列出,官方文件無法連線查證,
  `modules/` 的內容因卡在 4.6 而不採信。**第一張 story 必須實機驗證這些鍵名**,
  不得憑訓練資料寫死(本專案已有 18 處憑記憶寫錯呼叫寫法的前例)。
- `tr()` 的 key 是否可直接使用階層式 dot-notation(例如 `menu.settings.audio.volume_label`)
  當作 CSV 第一欄 —— 這是本 agent 既有標準的慣例,技術上應該可行(`tr()` 對 key 字串
  格式沒有限制),但**沒有在本專案實機驗證過**,標未查證。
- 正體中文對應的 Godot locale 代碼(`zh_TW` 還是 `zh_Hant`,或兩者並存的差異)—— 本專案
  面向台灣使用者(繁體中文),常見選項是 `zh_TW`,但**具體選哪個是一次需要實機確認
  `TranslationServer` 行為的決定,不是本 epic 憑推測拍板的事**。

### 2. 既有 `TEXT_*` 常數怎麼遷移

**分佈**(見上方「現況查證」節逐條指令):27 個 GDScript 字串常數(`battle_screen.gd` 15、
`card_confirm_panel.gd` 4、`hand_bar.gd` 4、`battle_menu.gd` 6)+ 6 個 `.tscn` 場景檔
裸字串(`BattleScreen.tscn` 1、`BattleMenu.tscn` 5)。合計 **33 處、6 個檔案**。

> 🔴 **協調者更正(2026-09-29,稽核本檔時發現):上面那兩個總數不可信,逐檔分項才可信。**
>
> 本節原寫「**27 個** GDScript 字串常數」與「合計 **33 處**」,但**它自己列的分項加起來不是 27**
> (15 + 4 + 4 + 6 = 29)。協調者獨立複驗,逐檔實測如下:
>
> ```
> $ for f in src/ui/battle/battle_screen.gd src/ui/battle/hand_bar.gd \
>            src/ui/battle/card_confirm_panel.gd src/ui/menu/battle_menu.gd; do
>     m=$(grep -E '^const [A-Z_]+: String = "' "$f" | grep -vcE 'res://|^const _LOG')
>     printf "%-28s %s\n" "$(basename $f)" "$m"
>   done
> battle_screen.gd             15
> hand_bar.gd                   4
> card_confirm_panel.gd         5
> battle_menu.gd                6
> ```
>
> **差異的成因有兩個,方向相反,所以總數沒有單一正確答案**:
> ①`card_confirm_panel.gd` 實際 **5** 個而非 4 —— 多出來的是 `ARROW_GLYPH: String = " → "`,
> 它是顯示字串但不是「要翻譯的句子」,**算不算進遷移範圍是一個要決定的事,不是一個要查的數**;
> ②`battle_screen.gd` 的 23 個字串常數中有 8 個是 `res://` 資源路徑與 `_LOG_*` 開發者訊息,
> **不是玩家可見文字**,上面的指令已扣除。
>
> 🔴 **因此本檔各處出現的「27」「33」一律不要引用。** 要數量就當場跑上面那條指令,
> 再加上 `.tscn` 裡的裸字串(本檔另記 `BattleScreen.tscn` 1 + `BattleMenu.tscn` 5,**未經協調者複驗**)。
> **本專案已明文登記「手抄的數字必然漂移」,而這份檔案誕生當天就漂了。**
> 📌 **不影響本節的結論**(單批遷移、逐檔擁有者路由表),那兩項不依賴總數。

**建議:單批遷移,不分批。** 理由:量體小(33 處),分批的協調成本(誰先誰後、中間狀態
怎麼混用新舊兩套)高於直接一次做完的執行成本。這與 33 處分散在 6 個檔案、且已經有
現成的「一個檔案對應一個擁有者」路由表(下方)吻合。

**每個檔案的擁有者,依 `.claude/docs/technical-preferences.md` 副檔名路由表**:

| 檔案 | 型別 | 擁有者 |
|---|---|---|
| `battle_screen.gd` / `card_confirm_panel.gd` / `hand_bar.gd` / `battle_menu.gd` | `.gd` | `godot-gdscript-specialist` |
| `BattleScreen.tscn` / `BattleMenu.tscn` | `.tscn` | `godot-specialist` |

**本 localization-lead 的角色**:提供 key 命名慣例與 locale 檔案結構(見 Q1),
**不寫程式碼、不改 `src/`** —— 依「What This Agent Must NOT Do」,實作交上表兩位專家。

**證明沒漏的可執行檢查(不是紀律要求)**:遷移完成後,對這 6 個檔案重跑「現況查證」節
用過的同一條 grep pattern(排除註解行、排除 `Color(...)` 型別的假陽性),預期零命中裸
字串常數;可包成一條 GdUnit4 靜態紀律測試,長期防止新字串再次直接寫死
(見 Q5,依 `.claude/rules/test-standards.md` 的「乙類」例外)。

### 3. 單語系(僅繁體中文)下的範圍 —— 要做什麼、明文不做什麼

**要做**:

- 建立 key-based 查找 API(封裝 `tr()` 或自建薄殼皆可,由後續 story 決定,見 Q1 未查證項)
  與 locale 檔案結構,**現在就套用到全部新字串,也套用到 Q2 的 33 個既有字串**。
- 至少一份 `zh_TW`(或裁決後確定的代碼)locale 檔案,內容就是現有這 33 處文字,
  用階層式 key 命名(例如 `battle.hud.status_format`、`battle.menu.leave_confirm_title`)。
- 缺 key 時的 fallback 行為:**絕不對玩家顯示裸 key**,至少要有一個明確定義的行為
  (例如顯示 key 本身僅限 debug build、release build 顯示空字串或預設佔位文字)——
  即使只有一個語系,「key 打錯字」這個情境現在就可能發生,必須現在就定義行為。
- 一條可執行的回歸測試,防止未來新字串繞過 key 系統直接寫死(見 Q5)。

**明文不做**(避免下一個人自行擴大範圍):

- **不翻譯成任何其他語言。** 支援哪些語言是 `producer` 的商業決定,不是本 epic 的範圍
  (依「What This Agent Must NOT Do」)。
- **不做語系切換 UI/選單。** 只有一個語系時,語系選單沒有使用者價值,現在做是純粹的
  超前部署。
- **不做 RTL(從右到左)支援。** 目前無 RTL 語言在範圍內。
- **不做字型抽換管線。** 對話正文字型本身尚未選定(見 `design/art/screen-architecture.md`
  「尚未涵蓋:對話正文字型」節,`technical-preferences.md` 亦有登記),那是美術方向的
  未決項,不是本 epic 要解決的問題 —— 本 epic 只保證「文字走 key 系統」,字型選什麼是
  另一條線。
- **不強制要求所有既有測試截圖重跑。** 這是文字管線變更,不是版面變更;`coding-standards.md`
  的截圖分類與 Check 4 世界層規則不受本 epic 影響。

### 4. 排程連帶後果 —— M5(不是 M4)開工前的阻擋條件

🔴 **更正派工單前提**:派工單寫「M4 要做兩個新面板」,**經查證這是錯的,已直接更正**。
依 `production/epics/tactical-combat/EPIC.md`:

- **M4 = 世界層呈現**(`board_view.gd` 的高亮圖層:移動範圍、攻擊範圍、非色彩標記)——
  **不含新增玩家可見文字**,以 placeholder 圖形驗收「形狀與非色彩通道是否成立」。
- **M5 = 介面層兩個面板**(格位資訊面板、攻擊二段確認面板)——**這兩個才是有文字的**,
  格位資訊面板明列欄位包含地形種類、陣營/HP/行動旗標狀態等文字內容。
- 該檔案並已定案**執行層序列化順序為 M6 → M5 → M4**(規劃層 M4/M5 產出互不依賴,
  但三者共用 `battle_screen.gd`,執行不可並行)。

**因此可檢查的條件是**:

> **本 epic 的「核心 key 查找 API + locale 檔案結構」模組(Stories 草案的 001),
> 必須在 M5 的 story 開工(而非規劃)之前完成並可用。**

**怎麼檢查它完成了**(可執行,不是紀律要求):

1. `grep -rn "tr(\|TranslationServer" src/` 由零命中變為非零命中,且至少涵蓋一個
   現有畫面(建議先套用在 Q2 的既有 33 處其中之一,證明管線真的接得起來,不只是空殼)。
2. 至少一份 locale 檔案存在,且以 M5 兩個面板已知的欄位名稱(地形種類、`terrain_cost`、
   遮蔽旗標、武器分層 `(min,max)`、當前 MP 等,依 `tactical-combat/EPIC.md` M5 節)
   可以預先登記對應 key —— **即使 M5 story 還沒開始寫,key 命名慣例必須已經存在**,
   讓 M5 的實作者一開始就用 key,不再新增裸字串常數。
3. M5 story 驗收條件裡必須包含「本 story 新增的面板文字一律透過 key 查找,零新增
   `const \w+: String = "..."` 型式的裸字串常數」——這條驗收條件本身要寫進 M5 的
   story 檔,不是本 epic 能替 M5 決定的事,但**本 epic 完成即是它能被寫進去的前提**。

⚠️ **M6 排在 M5 之前執行**,理論上留了一點緩衝,但不應該依賴這個緩衝 —— 本 epic
的目標是在 `/create-stories tactical-combat` 產生 M5 的 story 檔**之前**就緒,
而不是賭 M6 執行期間才趕工完成。

### 5. 測試怎麼寫

依 `.claude/docs/coding-standards.md` 的 CI 規則(每次對話開場載入,細節不複述):
`tests/gdunit4_runner.gd`、`godot --headless --path . --import` 前置、
`--ignoreHeadlessMode` 必要旗標、exit code 陷阱(101 = 有警告非失敗、105 = 探索期
解析錯誤)。

**本 epic 需要的測試,分兩類**:

1. **管線行為測試**(headless 可跑):locale 檔案載入/解析正確、缺 key 時不 crash、
   缺 key 時不顯示裸 key(依 Q3 定義的 fallback 行為斷言)、key 格式驗證
   (無重複 key、無空值)。
2. **靜態紀律回歸測試**(讀 `src/**/*.gd` 原始碼文字,斷言「不存在裸中文字串常數」)——
   這屬於 `.claude/rules/test-standards.md` 登記的**乙類例外**(唯讀 `src/**/*.gd` 與
   `tests/**/*.gd` 文字,用於斷言原始碼紀律),**必須遵守該例外的兩項附帶義務**:
   ①測試檔檔頭寫明屬乙類、為何不能用注入取代;②自陳斷言範圍不等於窮盡性
   (例如:掃描抓不到動態組字串、`.tres` 資源檔內文字等情況要明講)。

🔴 **新增任何測試層級,必須同步加進 `tests/gdunit4_runner.gd` 的 `FORCED_ARGS`**——
`coding-standards.md` 已登記過一次「本機只掃 `tests/unit`,新增 `tests/integration`
後 5 條測試一次都沒跑,回報卻全綠」。若本 epic 的測試放在既有 `tests/unit/` 底下則
不受影響;若另立新目錄,必須檢查這件事。

## Stories(草案,本批不建立 story 檔)

> 🔴 **2026-09-30:本節已被 `story-index.md` 取代,不再是正本。** 下表是 2026-09-29 切分前的草案,**逐字保留供追溯**。實際切出來的三張 story 檔、依賴關係與 gating 判定以 `story-index.md` 為準;本表與它若有出入,以 `story-index.md` 為準。

| # | 暫定名稱 | 範圍 | 是否為 Q4 的 gating 模組 |
|---|---|---|---|
| 001 | 核心 key 查找 API + locale 檔案結構(骨架) | Q1 未查證項的實機驗證、`project.godot` 設定、至少一個 key 端到端可用 | ✅ 是 —— M5 story 開工前必須完成 |
| 002 | 既有 33 處字串遷移 | Q2 的 4 個 `.gd` + 2 個 `.tscn` 檔案,依上表擁有者分工 | 否(建議盡快做,但不阻擋 M5 —— 只要 001 的 API 存在,M5 可以邊做邊用新系統,不必等舊字串遷完) |
| 003 | Fallback 與缺字偵測回歸測試 | Q5 的兩類測試 | 否,但建議與 001 同批,理由是「缺 key 不顯示裸 key」本身是 001 骨架的一部分行為 |

## 標為「未查證」的項目

1. `project.godot` `[internationalization]` 區塊具體鍵名與 CSV 欄位格式(Q1)。
2. `tr()` key 是否可直接用階層式 dot-notation 字串,實機是否有限制(Q1)。
3. 繁體中文對應的 Godot locale 代碼該選 `zh_TW` 或 `zh_Hant`(Q1)。
   ✅ **2026-09-30 已關閉** —— 2026-09-29 探針實測 + `technical-director` 拍板 `zh_TW`,
   見下方「🔴 技術總監裁決:繁體中文 locale 代碼(2026-09-30)」節。
4. Godot 官方文件的即時查證 —— 本次沒有網路擷取工具可用,完全依賴專案內
   `docs/engine-reference/godot/` 現有文件,未做外部交叉核對。
5. 🔴 **(2026-09-30 新增,由上述 locale 裁決登記)真實 Windows/Steam 平台回報的系統 locale
   字串格式**,以及**萬一被 `set_locale()` 靜默降級成裸 `zh` 之後 `tr()` 還找不找得到
   `zh_TW` 那份翻譯** —— 後半是本專案覆核時新發現的,探針 log 裡一行都沒量過。
   **仍然開著。** 關閉者 `godot-specialist`、時機為 **Story 001 驗收之前**、要量什麼與
   證據等級要求,全部寫在該裁決節的第五節 (c) 表。
   ⚠️ **這一項不阻擋 locale 代碼的選擇**(理由見該節第五節 (a):它與欄位命名正交),
   但**它阻擋「本地化管線在玩家機器上會正確啟動」這個宣稱** —— 兩者不要混為一談。

> 📌 **上方第 1、2 項本節不動。** 同一支探針其實也量了第 1 項(`project.godot`
> `[internationalization]` 真實鍵名與預設值,見該探針 README 的 Q1 表),但**要不要據此關閉它,
> 是 `localization-lead` 與 Story 001 的事,不是本次 locale 裁決的職權** ——
> `technical-director` 在此只登記「材料已存在」,不代為關閉。第 2 項(dot-notation key)
> 該探針未測,仍完全開著。

## ✅ 管理者裁決紀錄(2026-09-29,協調者當日呈報並記錄)

**管理者逐字選項**:**「照建議全部開工(建議)」** —— 下方四項一次全數表態。

| # | 原問題 | 裁決 | 執行狀態 |
|---|---|---|---|
| 1 | locale 檔案放哪個目錄 | **`assets/data/locales/`** —— 採本檔原提案的第一候選,理由亦採原文:`assets/data/` 現有定義就是「資料驅動的設定檔」 | ⏳ 待建立。🔴 **`.claude/docs/directory-structure.md` 是逐條稽核過的圖,明文「需要新目錄時先建立再畫」—— 目錄實際建立之後才更新那張圖,不得預先畫上去** |
| 2 | 要不要寫一份架構決策文件(ADR) | **不寫** —— 採本檔自己的傾向。依據是 `.claude/docs/coding-standards.md` 2026-09-01 管理者裁決:架構文件只在**跨系統契約**時才寫,且流程劑量規則預期剩下六個系統只再產生 0~1 份 | ✅ 已裁決,無待辦 |
| 3 | `zh_TW` vs `zh_Hant` | **先實機探針,再由 `technical-director` 依探針結果拍板** —— 管理者不憑感覺選字串 | ✅ **已拍板(2026-09-30,`technical-director`):採用 `zh_TW`,CSV 只設一個繁體欄位、標頭逐字 `zh_TW`。** 全文、原始輸出行依據、不涵蓋範圍、以及一項仍然開著的未查證遺留,見下方「🔴 技術總監裁決:繁體中文 locale 代碼(2026-09-30)」節。原狀態行逐字保留:「⏳ 探針已於同日派工 `godot-specialist`,產出路徑 `prototypes/godot-specialist-i18n-locale-probe-2026-09-29/`」——探針已完成,條件已成立 |
| 4 | Story 001~003 准不准開工 | **准** | ⏳ 待 `localization-lead` 切 story 檔 |

🔴 **本裁決解鎖的下游**:`production/epics/tactical-combat/` 的 **story-012 / story-013**
(格位資訊面板、攻擊二段確認面板)兩張標 `Blocked`,等的就是本 epic 的 Story 001。
**那兩張的 Dependencies 節明文列著 `localization Story 001`** —— 本 epic 的 Story 001 一完成就要回去解鎖它們。

⚠️ **裁決 1 有一個順序不可顛倒的地方,寫在這裡以免被跳過**:目錄圖(`directory-structure.md`)
是一份 2026-09-01 全庫稽核重畫過的文件,它自己的檔頭逐字寫著舊版「畫著 `src/networking/` ——
但 `networking_features` 是本專案的**專案級禁令**」,並因此立下規則:**只畫實際存在的東西**。
所以是「先建目錄、放進真的檔案,然後才更新那張圖」,不是「先改圖再建」。

## 🔴 技術總監裁決:繁體中文 locale 代碼(2026-09-30)

**授權依據**:上方「管理者裁決紀錄」表第 3 列逐字 ——「先實機探針,再由 `technical-director`
依探針結果拍板」。探針已於 2026-09-29 完成,證據目錄
`prototypes/godot-specialist-i18n-locale-probe-2026-09-29/`。**本節未重跑探針,亦未開新探針。**

### 一、裁決

**採用 `zh_TW`。** 連帶兩項可直接執行的具體化:

1. **CSV 只設一個繁體欄位,標頭逐字寫 `zh_TW`**(大小寫照這樣寫,理由見第五節的降級陷阱)。
   **不同時提供 `zh_Hant` 欄位** —— 這一併避開探針自陳未查證的「兩份同時註冊時誰勝出」
   的註冊順序相依性(見第四節第 4 點)。
2. `.translation` 檔名與 `Translation.locale` 屬性會逐字沿用該標頭字串,故本裁決實際落在
   **CSV 標頭那一格**,不需要另外在程式碼裡寫死 locale 字串。

**一句話理由**:目標平台的引擎自己解析出來的 locale 就是 `zh_TW` —— 選它等於執行期字串
**完全相等**,不依賴任何 fallback 比對邏輯。

### 二、依據 —— 原始輸出行(整行貼上,不寫行號)

證據檔:`prototypes/godot-specialist-i18n-locale-probe-2026-09-29/run_output_headless.txt`。
**本節刻意不引用行號**(依 `.claude/rules/design-docs.md`「No line-number self-references」
的同一理由:行號會漂)。每一段都附當場可重跑的 `grep` 定位指令。

#### (1) 決定性的那一行 —— 也是探針自己的建議理由裡沒有用到的一行

```
BEFORE any set_locale, get_locale() = zh_TW
```
定位:`grep -n "BEFORE any set_locale" prototypes/godot-specialist-i18n-locale-probe-2026-09-29/run_output_headless.txt`

**這一行為什麼是決定性的**:它是 `probe.gd` 第一次讀 `TranslationServer.get_locale()`,
在此之前腳本沒有呼叫過 `set_locale()`,探針專案也沒有 `[internationalization]` 區塊、
沒有設 `internationalization/locale/test`。**亦即這個值是引擎自己從本機 Windows 系統
locale 解析出來的,不是腳本餵進去的。** 本技術總監獨立覆核兩點:

```
$ grep -n "OS\." prototypes/godot-specialist-i18n-locale-probe-2026-09-29/probe.gd
(零命中,exit 1)
```
→ 探針全程沒有呼叫 `OS.get_locale()` 之類的方法,那個 `zh_TW` 不可能是腳本自己組出來的。

```
$ grep -n "BEFORE any set_locale" -B 20 probe.gd
...
64-	print("--- Q2b: TranslationServer.set_locale() round-trip / normalization ---")
65:	print("BEFORE any set_locale, get_locale() = ", TranslationServer.get_locale())
```
→ 其上 20 行全是 `ClassDB` 內省與列印,沒有任何 `set_locale()`。

🔴 **這條依據比探針 README 列的四條都強,而 README 一條都沒提到它。** README 的四條理由
談的是「哪個名字語意比較貼切」與「兩個都不會壞」;這一行談的是**在目標平台上,哪一個字串
會與執行期實際值完全相等**。前者是偏好,後者是事實。

#### (2) 兩者的顯示名稱差異(支持,但只是次要)

```
get_locale_name(zh_TW)   = Chinese, Taiwan
get_locale_name(zh_Hant) = Chinese (Traditional Han)
```
定位:`grep -n "get_locale_name" ... run_output_headless.txt`

#### (3) 證明「選錯也不會壞」的三組量測 —— 這降低本決定的風險,但不構成選擇依據

```
compare_locales(zh_TW,zh_Hant)   = 10
compare_locales(zh_TW,zh_TW)     = 10
compare_locales(zh_Hant,zh_TW)   = 10
```

```
--- Case A: ONLY zh_TW translation registered, active locale forced to zh_Hant ---
get_locale() = zh_Hant
tr(test_key) = [測試甲_zhTW]  -- empty or literal test_key echoed back means FALLBACK FAILED; seeing the zh_TW string means FALLBACK SUCCEEDED
```

```
--- Case B: ONLY zh_Hant translation registered, active locale forced to zh_TW ---
get_locale() = zh_TW
tr(test_key) = [測試乙_zhHant]  -- empty or literal test_key echoed back means FALLBACK FAILED; seeing the zh_Hant string means FALLBACK SUCCEEDED
```
定位:`grep -n "compare_locales\|Case A:\|Case B:" ... run_output_headless.txt`

#### (4) 本裁決實際落在哪一格 —— CSV 標頭字串

```
res_zh_tw.locale (verbatim from CSV header zh_TW) = zh_TW
res_zh_hant.locale (verbatim from CSV header zh_Hant) = zh_Hant
```
定位:`grep -n "verbatim from CSV header" ... run_output_headless.txt`

### 三、對探針執行者「建議 `zh_TW`」的表態

**採納它的結論,但不採納它的主要理由。** 逐項:

| 探針 README 的理由 | 本技術總監的判定 |
|---|---|
| 理由 1:`get_locale_name()` 顯示「Chinese, Taiwan」語意更精確 | **降為次要。** 那是**給人看的顯示字串**差異,實測不影響任何執行期行為。以它當主要依據,等於用偏好拍板 —— 而管理者裁決表第 3 列逐字要求的正是「不憑感覺選字串」 |
| 理由 2:`compare_locales` 同分、雙向 fallback 皆成功 | **複核無誤,但它證明的是「兩個都可以」,不是「該選哪個」。** 它的正確用途是說明**本決定可逆性高、風險低**(決策框架第 6 條),不是選擇依據 |
| 理由 3:`standardize_locale()` 不會互相正規化 | **複核無誤。** 同上,是「兩者並非別名」的事實,不偏向任一方 |
| 理由 4:`zh` / `Hant` / `TW` 三個組成部分在引擎資料庫皆存在 | **複核無誤。** 同上,排除了「一個合法一個不合法」,不構成選擇依據 |
| **(README 沒有列)** `BEFORE any set_locale, get_locale() = zh_TW` | 🔴 **本裁決的主要依據。** 見第二節(1) |

**結論方向與探針相同,推導路徑不同。** 記在這裡是因為下一個人若要推翻本裁決,
**要推翻的是第二節(1),不是 README 那四條** —— 推翻那四條不會動搖本裁決。

### 四、本裁決**不涵蓋**什麼

1. 🔴 **這是命名慣例的選擇,不是功能的選擇。** 第二節(3)的三組量測已實測排除功能差異:
   `compare_locales` 兩個方向都是 10(與完全相同字串同分),Case A/B 雙向 fallback 皆成功。
   **沒有任何功能是選 `zh_TW` 才有、選 `zh_Hant` 就沒有的。** 不要把本裁決引用成技術能力的依據。
2. **不涵蓋未來加簡體 `zh_CN` 時會發生什麼 —— 但可以說它不會比另一個選項更擋路。**
   ```
   compare_locales(zh_TW,zh_CN)     = 3
   compare_locales(zh_Hant,zh_Hans) = 3
   ```
   兩個候選對各自的簡體對立面**都是 3 分**,對稱。
   ⚠️ **但 log 沒有量過「`zh_TW` 與 `zh_CN` 兩份同時註冊、系統 locale 是 `zh_CN` 時誰勝出」。**
   故「將來加得進去」是**推論,不是實測**。真要加簡體時,必須另跑一次探針,不得引用本節當依據。
3. **不涵蓋 `internationalization/locale/fallback` 該設什麼。**
   ```
   PROP name=internationalization/locale/fallback type=4 hint=32 hint_string= usage=6
     get_setting() -> en
   ```
   實測預設是 `en`(不是空字串)。本專案不出英文版,**這個預設值指向一份不存在的翻譯**——
   它與 Q3「缺 key 時絕不對玩家顯示裸 key」是同一件事的兩半,**由 Story 001 決定,本裁決不代它決定。**
4. **不涵蓋合併形式 `zh_Hant_TW`,也不涵蓋兩份同時註冊時的勝出順序。**
   探針 Case E 實測「兩者同時註冊、locale = `zh_Hant_TW` 時 `zh_TW` 勝出」,
   但它**自陳只測了一種註冊順序**。第一節第 1 點(只設一欄)使這個相依性**現在咬不到**;
   **若將來有人加第二個繁體欄位,這一項會立刻回來。**
5. **不涵蓋 locale 檔案放哪個目錄**(已由上方管理者裁決 1 決定為 `assets/data/locales/`)、
   **不涵蓋 key 命名慣例**(Q1 未查證項 2,仍開著)、**不涵蓋字型**(Q3 明文不做)。
6. **不涵蓋「要不要為本地化寫一份 ADR」** —— 上方管理者裁決 2 已裁定不寫,本裁決不推翻它。
   本節本身即是「一次跨系統技術選擇記在擁有它的 epic 檔裡」的實例,與該裁決一致。

### 五、🔴 仍然開著的未查證項(逐字登記,不得在本裁決裡消失)

探針執行者誠實標記的一項,**逐字轉錄自
`prototypes/godot-specialist-i18n-locale-probe-2026-09-29/README.md` 的「未查證(Q2)」節**:

> - **實際 Windows/Steam 平台回報的系統 locale 字串格式**(`OS.get_locale()` /
>   `OS.get_locale_language()`)——**本次探針完全沒有測試這兩個方法**,只測了
>   `TranslationServer` 這一側。**若系統回報的字串本身就帶著奇怪的大小寫或格式,第 1 點
>   發現的「大小寫陷阱」可能在真實裝置上發生,而本次探針無法確認 Windows/Steam 實際會回報
>   什麼字串** —— 這是下一步若要收斂到「production 環境會不會踩到這個陷阱」需要另外驗證的項目。

對應的陷阱原始輸出行:
```
after set_locale(zh_HANT_tw) mixed case -> get_locale() = zh
```
定位:`grep -n "mixed case" ... run_output_headless.txt`

#### (a) 判定:**不阻擋本次拍板**,理由是結構性的

這個陷阱與「我們把 CSV 欄位命名成什麼」**正交**:不論標頭寫 `zh_TW` 或 `zh_Hant`,只要
系統送進來的字串大小寫不規範,`set_locale()` 都會同樣降級。
**它不是兩個選項之間的鑑別因子,因此結構上不可能改變本裁決的方向。**

#### (b) 🔴 但本次覆核發現這個洞比 README 寫的更大一塊

README 說的是「不知道系統會送什麼字串進來」。本技術總監另外查了**降級之後會怎樣**,
結果是 log 裡**一行都沒量過**:

```
$ grep -nE "compare_locales\((zh,|.*,zh\))" run_output_headless.txt
(零命中,exit 1)
```
→ 全份 log 的 5 條 `compare_locales` 量測(`zh_TW`/`zh_Hant`/`zh_CN`/`zh_Hans` 之間)
**沒有任何一條的任一側是裸 `zh`**。

```
$ grep -n "get_locale() = zh$" run_output_headless.txt
129:after set_locale(zh_HANT_tw) mixed case -> get_locale() = zh
```
→ 全份 log 中 active locale 變成裸 `zh` 只出現這一次,**而其後沒有任何一次 `tr()` 量測**。

**亦即:萬一降級真的在玩家機器上發生,`tr()` 還找不找得到 `zh_TW` 那份翻譯,目前無人知道。**
Case A/B 證明的是 `zh_TW` ↔ `zh_Hant` 之間互相 fallback 成功,**不能外推到 `zh` → `zh_TW`。**
⚠️ **下一個人不得把 Case A/B 當成「降級也沒關係」的證據。**

#### (c) 誰在什麼時候關掉它

| | 內容 |
|---|---|
| **關閉者** | `godot-specialist`(平台/引擎行為,依 `.claude/docs/technical-preferences.md` 路由表) |
| **時機** | **Story 001 驗收之前**,不是之後 —— Story 001 是 `tactical-combat` story-012/013 的解鎖前提,這項若留到驗收後才查,發現問題時下游已經在跑 |
| **要量什麼** | 在**匯出建置**(不是編輯器、不是暫存空專案)上讀出並留 log:①`OS.get_locale()` ②`OS.get_locale_language()` ③`TranslationServer.get_locale()` 三者的**原始字串**;④在該 locale 下對一個已知 key 做一次 `tr()`,確認命中的是 `zh_TW` 那份 |
| **證據要求** | 依 `.claude/docs/technical-preferences.md`「(A) 級必須附它實際執行的那支檔案的路徑」與「留 log,不要只留結論」。**沒有附檔案路徑與原始 log 的結論一律降為 (C) 級,不得據以關閉本項。** |
| **量到的若不是 `zh_TW` 怎麼辦** | **不回頭改本裁決**(欄位名不是問題所在,見上方 (a))。處置是「啟動期要不要顯式呼叫 `TranslationServer.set_locale()`」——**那是 Story 001 的設計決定,本裁決刻意不代它決定。** |
| **Steam 那一半** | Steam 客戶端語言與 OS locale 是兩件事,本機無 Steam 環境。**這一半留在 Story 001 之外**,由未來的 Steam 整合工作單承接;現在只登記它存在,不假裝 Story 001 能關掉它。 |

⚠️ **沒有任何 skill、lint 或閘門會檢查上表有沒有被執行** —— 與本專案其餘同類規則一樣,
遵守與否目前不可觀測。寫在這裡買到的是「下一個人有明文可查對」,不是「一定會有人做」。

### 六、我們怎麼知道這個裁決是對的(驗證條件)

- ✅ **成立的樣子**:Story 001 完成後,在匯出建置上 `TranslationServer.get_locale()` 讀回
  `zh_TW`,且 `tr()` 命中的是 `zh_TW` 那份翻譯 —— **完全相等命中,沒有經過 fallback**。
- ❌ **不成立的樣子**:任一台目標機器讀回的不是 `zh_TW`。那表示第二節(1)的依據**只在
  這一台開發機上成立**,本裁決的主要理由被抽掉。
  🔴 **但即使如此,正確反應多半不是改 locale 字串,而是在啟動期顯式 `set_locale()`** ——
  因為第二節(3)已實測 `zh_TW` ↔ `zh_Hant` 雙向 fallback 皆成功,改字串換不到東西。

## 需要管理者裁決的事

1. **locale 檔案該放哪個目錄**——`docs/directory-structure.md` 是逐條稽核過的目錄圖,
   明文「只畫實際存在的東西,需要新目錄時先建立再畫」。本 epic 需要新增一個資料夾
   (候選:`assets/data/locales/`,理由是 `assets/data/` 現有定義就是「資料驅動的設定檔」;
   或另立頂層 `locales/`)。**這張圖不是本 localization-lead 能單方修改的稽核文件**,
   需要裁決後由該圖的擁有者畫上去。
2. **是否需要一份 ADR** 記錄本地化管線的 `project.godot` 設定與 key 命名慣例 ——
   本 epic 判斷傾向不需要(尚未構成跨系統契約,只有一個消費方 M5 即將啟用),
   但建議會同 `technical-director` 確認,不由本 epic 自行拍板。
3. **`zh_TW` vs `zh_Hant` 的 locale 代碼選擇**(見上方未查證項 3)—— 屬於需要實機驗證
   後才能拍板的技術決定,建議指派 `godot-specialist` 或 `godot-gdscript-specialist`
   做一次探針查證後,由 `technical-director` 或管理者拍板。
4. **Story 001~003 是否核准開工** —— 本 epic 目前狀態為 `Draft`,依本專案慣例
   （`screen-scaling`、`tactical-combat` 皆先過管理者/技術總監核可才轉 `Ready`）。

## Next Step

**本 epic 完成骨架與五題查證,等待管理者對上方「需要管理者裁決的事」四項表態。**
表態後:

1. 若裁決 locale 目錄位置與 ADR 需求,由 `technical-director` 協調對應擁有者更新
   `docs/directory-structure.md`(若需要)。
2. 指派 `godot-specialist`/`godot-gdscript-specialist` 執行 Story 001 的實機驗證段落
   (Q1 未查證項 1、2),產出結果後由 `localization-lead` 補完 locale 檔案結構與 key
   命名慣例文件。
3. Story 001 完成、可用之後,`/create-stories tactical-combat` 的 M5 才可以在其驗收條件
   裡引用「零新增裸字串常數」這條規則(見 Q4)。
4. `production/epics/index.md` 的「🔴 尚未建立 Epic 的跨切面基礎設施」節狀態欄
   需同步從「📋 尚未建立 epic」改為「📋 Draft,待管理者裁決」或對應狀態
   (由本次派工一併處理,見下方索引更新)。
