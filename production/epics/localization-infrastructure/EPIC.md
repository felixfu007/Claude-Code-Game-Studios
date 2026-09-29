# Epic:本地化(i18n)基礎設施

> **層**:Cross-cutting Infrastructure
> **權威文件**:無 GDD(基礎設施,非遊戲系統 —— 先例 `screen-scaling`)
> **狀態**:🟢 **Ready**(2026-09-29 管理者裁決四項全數表態,見下方「需要管理者裁決的事」節的裁決紀錄。原狀態行為 `Draft(骨架完成,待管理者裁決本檔「需要管理者裁決的事」節後可過 Ready)`,條件已成立)
> **Stories**:待切分(草案見下方「Stories」節,本批不建立 story 檔)
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

| # | 暫定名稱 | 範圍 | 是否為 Q4 的 gating 模組 |
|---|---|---|---|
| 001 | 核心 key 查找 API + locale 檔案結構(骨架) | Q1 未查證項的實機驗證、`project.godot` 設定、至少一個 key 端到端可用 | ✅ 是 —— M5 story 開工前必須完成 |
| 002 | 既有 33 處字串遷移 | Q2 的 4 個 `.gd` + 2 個 `.tscn` 檔案,依上表擁有者分工 | 否(建議盡快做,但不阻擋 M5 —— 只要 001 的 API 存在,M5 可以邊做邊用新系統,不必等舊字串遷完) |
| 003 | Fallback 與缺字偵測回歸測試 | Q5 的兩類測試 | 否,但建議與 001 同批,理由是「缺 key 不顯示裸 key」本身是 001 骨架的一部分行為 |

## 標為「未查證」的項目

1. `project.godot` `[internationalization]` 區塊具體鍵名與 CSV 欄位格式(Q1)。
2. `tr()` key 是否可直接用階層式 dot-notation 字串,實機是否有限制(Q1)。
3. 繁體中文對應的 Godot locale 代碼該選 `zh_TW` 或 `zh_Hant`(Q1)。
4. Godot 官方文件的即時查證 —— 本次沒有網路擷取工具可用,完全依賴專案內
   `docs/engine-reference/godot/` 現有文件,未做外部交叉核對。

## ✅ 管理者裁決紀錄(2026-09-29,協調者當日呈報並記錄)

**管理者逐字選項**:**「照建議全部開工(建議)」** —— 下方四項一次全數表態。

| # | 原問題 | 裁決 | 執行狀態 |
|---|---|---|---|
| 1 | locale 檔案放哪個目錄 | **`assets/data/locales/`** —— 採本檔原提案的第一候選,理由亦採原文:`assets/data/` 現有定義就是「資料驅動的設定檔」 | ⏳ 待建立。🔴 **`.claude/docs/directory-structure.md` 是逐條稽核過的圖,明文「需要新目錄時先建立再畫」—— 目錄實際建立之後才更新那張圖,不得預先畫上去** |
| 2 | 要不要寫一份架構決策文件(ADR) | **不寫** —— 採本檔自己的傾向。依據是 `.claude/docs/coding-standards.md` 2026-09-01 管理者裁決:架構文件只在**跨系統契約**時才寫,且流程劑量規則預期剩下六個系統只再產生 0~1 份 | ✅ 已裁決,無待辦 |
| 3 | `zh_TW` vs `zh_Hant` | **先實機探針,再由 `technical-director` 依探針結果拍板** —— 管理者不憑感覺選字串 | ⏳ 探針已於同日派工 `godot-specialist`,產出路徑 `prototypes/godot-specialist-i18n-locale-probe-2026-09-29/` |
| 4 | Story 001~003 准不准開工 | **准** | ⏳ 待 `localization-lead` 切 story 檔 |

🔴 **本裁決解鎖的下游**:`production/epics/tactical-combat/` 的 **story-012 / story-013**
(格位資訊面板、攻擊二段確認面板)兩張標 `Blocked`,等的就是本 epic 的 Story 001。
**那兩張的 Dependencies 節明文列著 `localization Story 001`** —— 本 epic 的 Story 001 一完成就要回去解鎖它們。

⚠️ **裁決 1 有一個順序不可顛倒的地方,寫在這裡以免被跳過**:目錄圖(`directory-structure.md`)
是一份 2026-09-01 全庫稽核重畫過的文件,它自己的檔頭逐字寫著舊版「畫著 `src/networking/` ——
但 `networking_features` 是本專案的**專案級禁令**」,並因此立下規則:**只畫實際存在的東西**。
所以是「先建目錄、放進真的檔案,然後才更新那張圖」,不是「先改圖再建」。

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
