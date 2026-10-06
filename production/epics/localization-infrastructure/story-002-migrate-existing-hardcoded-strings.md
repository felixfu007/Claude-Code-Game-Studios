# Story 002: 既有裸字串遷移至 key 系統

> **Epic**: 本地化(i18n)基礎設施 —— `production/epics/localization-infrastructure/EPIC.md`
> **Status**: 🟡 **In Progress —— 四個 `.gd` 檔全數遷移完成,兩個 `.tscn` 尚未開始**
>
> 🔴 **2026-10-06 落地狀況(協調者獨立驗收)**:
> **已完成**:四個 `.gd` 檔共 **40 個字串**進 key 系統(`strings.csv` 40 筆);
> 9 個因此連帶變紅的既有測試檔已修復;新增端到端測試
> `tests/unit/core/i18n/i18n_migrated_strings_test.gd`(逐 key 斷言查出的內容與遷移前
> 字面值逐字相同)。全套測試 **1022 條、僅 1 條既有刻意紅**、exit 100、零 Parse Error。
> **未完成**:`src/ui/battle/BattleScreen.tscn` 與 `src/ui/menu/BattleMenu.tscn`
> (本 story 的 AC 明文列入,擁有者 `godot-specialist`)。
>
> 🔴 **本 story 的驗收條件有一個結構性盲點,已實測,下一個引用它的人必須知道**:
> AC 第一條指定的 grep 樣式是 `^const [A-Z_]+: String = "`,**它在結構上看不見
> 函式本體裡的行內字面值**。照它做會得到「零殘留」,而實際上還有 **10 處玩家可見的
> 中文**寫死在程式中間(全部直接寫進 Label 的 `.text`)。
> **2026-10-06 管理者裁決當場補完這 10 處**,並把驗收改用定義域更寬的指令:
> ```bash
> for f in src/ui/battle/battle_screen.gd src/ui/battle/hand_bar.gd \
>          src/ui/battle/card_confirm_panel.gd src/ui/menu/battle_menu.gd; do
>     echo "--- $(basename $f) ---"
>     LC_ALL=C grep -n '"[^"]*[^ -~][^"]*"' "$f" | LC_ALL=C grep -v ':[[:space:]]*#'
> done
> ```
> ⚠️ **這條會同時命中開發者訊息(`_LOG_*`、`push_error`),那是刻意的** ——
> 逐條肉眼分類比一條「剛好全過」的 grep 可信。現況應只剩 `battle_screen.gd` 的 3 處
> 開發者訊息。
>
> 📌 **視覺無回歸(ADVISORY)未執行,替代方案已說明**:開發者在公司,遊戲畫面
> 不能出現在螢幕上(零畫面曝光紀律)。協調者指派以上述端到端測試替代 ——
> 它比肉眼嚴格(逐位元組),但**驗不到版面**。版面複核仍是待辦。
> **Layer**: Infrastructure / Presentation(橫跨 4 個 `.gd` + 2 個 `.tscn`,分屬不同擁有者)
> **Type**: Integration(單一批次遷移,跨 6 個檔案、2 位不同擁有者,需協調但不改變任何
> 系統行為契約)
> **Estimate**: S~M(量體小,但跨 6 個檔案 + 2 位擁有者的協調成本是主要工作量來源)
> **Manifest Version**: N/A —— 本 epic 無 GDD

## Context

**權威文件**:無 GDD。依據 `EPIC.md` Q2(「既有 `TEXT_*` 常數怎麼遷移」)。

**現況(`EPIC.md` 已記載,本 story 開工時須重新現場核對,不得引用其手抄總數)**:

`EPIC.md` 本節有一段協調者更正,明文指出「27」「33」這兩個手抄總數**不可信**,理由是
它自己列的分項加總對不上,且 `card_confirm_panel.gd` 的計數本身依「算不算 `ARROW_GLYPH`」
而有 4 或 5 兩種答案。**本 story 開工時必須重新現場執行以下指令,不得引用 `EPIC.md`
裡的任何總數**:

```bash
for f in src/ui/battle/battle_screen.gd src/ui/battle/hand_bar.gd \
         src/ui/battle/card_confirm_panel.gd src/ui/menu/battle_menu.gd; do
    m=$(grep -E '^const [A-Z_]+: String = "' "$f" | grep -vcE 'res://|^const _LOG')
    printf "%-28s %s\n" "$(basename $f)" "$m"
done
```

`EPIC.md` 上次執行結果(2026-09-29,供比對,不保證現在仍相同):
`battle_screen.gd` 15、`hand_bar.gd` 4、`card_confirm_panel.gd` 5、`battle_menu.gd` 6。

另有 `.tscn` 場景檔裸字串,`EPIC.md` 記載 `BattleScreen.tscn` 1 處、`BattleMenu.tscn` 5 處
——**這組數字明文標記「未經協調者複驗」**,本 story 開工時同樣須重新現場確認(建議
`godot-specialist` 直接檢視兩份 `.tscn` 檔案的文字節點屬性,而非只靠 grep pattern,
場景檔格式與 `.gd` 不同,既有 grep pattern 未必適用)。

## Acceptance Criteria

- [ ] 開工時重新執行上方 grep 指令(以及 `.tscn` 的等效人工核對),取得**本次**的實際計數,
      不得引用 `EPIC.md` 裡任何已標記不可信的總數。
- [ ] **明確決定 `card_confirm_panel.gd` 的 `ARROW_GLYPH: String = " → "` 是否算入遷移
      範圍**,並記錄理由 —— `EPIC.md` 已標記這是「要決定的事,不是要查的數」,決定權
      交給本 story 的實作者。(判斷提示,非答案:它是顯示字串但可能不是「要翻譯的句子」,
      而是一個排版用的箭頭符號 —— 若 `zh_TW` 不需要不同符號,可能不需要走 key 系統,但
      若未來排版方向會需要依語言調整,則應納入。)
- [ ] `battle_screen.gd` 的既有字串常數中,有一部分是 `res://` 資源路徑與 `_LOG_*`
      開發者訊息,**不是玩家可見文字** —— 上方 grep 指令已扣除這些,遷移範圍**不包含**
      這部分,不得誤遷移。
- [ ] `battle_menu.gd` 現有 6 個字串常數**不使用 `TEXT_` 前綴命名慣例**(與其他三個檔案
      不同)。`EPIC.md` 已明文警告這個命名不一致的陷阱 —— 遷移時必須連同這批一起處理,
      不得因為某個 grep pattern 抓不到這個命名風格而遺漏。
- [ ] 依既有副檔名/職責路由表分工(`.claude/docs/technical-preferences.md`):
      - `.gd` 四檔(`battle_screen.gd` / `card_confirm_panel.gd` / `hand_bar.gd` /
        `battle_menu.gd`) → `godot-gdscript-specialist`
      - `.tscn` 兩檔(`BattleScreen.tscn` / `BattleMenu.tscn`) → `godot-specialist`
- [ ] **單批遷移,不分階段** —— 依 `EPIC.md` 建議,理由是量體小(6 個檔案),分批的協調
      成本(誰先誰後、中間狀態怎麼混用新舊兩套 key/裸字串)高於直接一次做完的執行成本。
- [ ] 每處遷移的字串使用階層式 dot-notation key,例如
      `battle.hud.status_format`、`battle.menu.leave_confirm_title` —— 命名應反映該字串
      實際出現的畫面/元件位置(依本 agent 標準的 key 命名慣例:
      `menu.settings.audio.volume_label` 這類階層式風格)。
- [ ] 遷移完成後零殘留:對上方 6 個檔案重新執行「現況查證」的 grep pattern(排除註解行、
      排除 `Color(...)` 型別的假陽性),預期零命中裸字串常數。若 story-003 的靜態紀律
      回歸測試已存在,可直接跑該測試取代手動 grep。
- [ ] 遷移不得改變任何既有畫面的視覺版面或文字內容(逐字內容仍是繁體中文原文,只是
      改為透過 key 查找而非常數字面值) —— 這是文字管線變更,不是版面變更,依
      `EPIC.md` Q3 明文「不強制要求所有既有測試截圖重跑」。

## Implementation Notes

1. **與 story-001 的邊界**:story-001 的 D 節 AC 已允許「先套用在既有 33 處字串其中之一,
   證明管線真的接得起來」——若 story-001 已提前遷移了某一處作為驗證用途,本 story 開工
   時應先核對該處是否已完成,避免重複工作(核對方式:檢查該字串是否已從常數改為
   key 查找呼叫)。
2. **不需要新增檔案** —— 本 story 只修改既有 6 個檔案的字串定義方式,以及新增/擴充
   story-001 建立的 locale 資料檔內容(新增這 6 個檔案對應的 key-value 列)。
3. **`.tscn` 場景檔的裸字串遷移方式**,由 `godot-specialist` 判斷是否需要改為腳本動態
   設定文字(呼叫 key 查找 API)取代場景檔內寫死的 `text` 屬性 —— 這通常意味著場景檔
   本身的節點文字屬性清空或改為佔位,實際文字由對應腳本的 `_ready()`(或等效生命週期
   函式)透過 key 查找 API 設定。具體實作方式由 `godot-specialist` 判斷。

## Out of Scope

- **新字串的撰寫或修改** —— 本 story 只搬遷既有字串的儲存方式,不改變任何字串的實際
  文字內容。
- **locale 檔案結構本身的設計** —— story-001 已完成,本 story 只是這個結構的第一批
  真實使用者。
- **測試怎麼寫** —— story-003(但若 story-003 尚未完成,本 story 仍需手動執行上方
  grep 驗證零殘留,不得跳過驗證步驟)。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 `Task` 工具不可用而跳過。

- **零殘留裸字串**
  - Setup: 完成全部 6 個檔案的遷移
  - Verify: 重新執行「現況查證」grep pattern(排除註解行、排除 `Color(...)` 假陽性)
  - Pass condition: 零命中
- **視覺無回歸**
  - Setup: 遷移前後各截一次圖(或人工走查),比對同一畫面的文字內容與版面
  - Verify: 逐字內容相同,版面無變化
  - Pass condition: 人工複核確認一致(Category 依實際畫面形狀,見
    `.claude/docs/coding-standards.md` 的截圖分類規則)
- **key 端到端命中**
  - Setup: 任取遷移後的一個 key
  - Verify: 呼叫查找 API 回傳與遷移前常數字面值逐字相同的字串
  - Pass condition: 完全相等,無因 key 格式或 locale 設定問題導致的空字串/裸 key 顯示

## Test Evidence

**Story Type**: UI(涉及 6 個既有畫面的文字管線變更,需要人工複核確認視覺無回歸)+
一項可執行的靜態檢查(零裸字串殘留)。

**Required evidence**:
- `production/qa/evidence/`(依 Category A/B/C 分類)下的手動走查文件或截圖,涵蓋
  6 個檔案對應的畫面 —— ADVISORY,依測試證據表既有規則(Story Type: UI)。
- 零殘留 grep 結果(或 story-003 的靜態紀律回歸測試通過結果)—— BLOCKING,這是一個
  可執行的機械檢查,不依賴人工判斷。

**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-001(核心 key 查找 API 與 locale 檔案結構必須先存在)
- Unlocks: None(本 story 不阻擋任何下游 story —— `EPIC.md` 明文「只要 001 的 API
  存在,M5 可以邊做邊用新系統,不必等舊字串遷完」)
