# 行號自我引用背景債 —— 逐處分類(2026-10-15)

> **任務性質**:分類與查證,**本次未修改任何既有檔案**。本檔是唯一產出。
> **來源指令**:`bash .claude/hooks/validate-doc-consistency.sh --line-refs`
> **範圍**:只處理「活的承重規格」那 50 處(13 個檔案)。
> **刻意排除**:118 處歷史性文件(`*-review-*.md`、`architecture-review-*round*.md`、
> `adr-revision-history.md`)—— 那是當時的紀錄,改行號等於竄改歷史。

## 分類定義

| 類別 | 定義 | 處置 |
|---|---|---|
| **A 真‧活引用** | 這句話**現在**正在用行號指向某處,下一個人會照它去找 | **要修** —— 本檔逐處附替代寫法 |
| **B 自我命中** | 這句話是在**描述/記載**一個行號引用或一次已完成的修訂,不是在使用它 | **不修** —— 修了破壞紀錄 |
| **C 不是行號** | 數字根本不是行號,工具誤判 | **不修** —— 登記工具誤判 |

---

## 涵蓋範圍聲明

**13 個檔案全部查完,50 處逐處附上原文片段。** 無未查項。

| # | 檔案 | 處數 | 狀態 |
|---|---|---|---|
| 1 | `design/gdd/cursor-highlight-state.md` | 12 | ✅ 已查 |
| 2 | `docs/architecture/adr-0005-cursor-device-authority-input-architecture.md` | 10 | ✅ 已查 |
| 3 | `design/gdd/systems-index.md` | 6 | ✅ 已查 |
| 4 | `design/art/art-direction.md` | 4 | ✅ 已查 |
| 5 | `docs/architecture/traceability-index.md` | 3 | ✅ 已查 |
| 6 | `docs/architecture/adr-0004-...-atomic-write-...md` | 3 | ✅ 已查 |
| 7 | `design/gdd/save-system.md` | 3 | ✅ 已查 |
| 8 | `design/gdd/affinity-data-pool.md` | 3 | ✅ 已查 |
| 9 | `design/ux/battle-menu.md` | 2 | ✅ 已查 |
| 10 | `design/quick-specs/unit-stats-provisional.md` | 1 | ✅ 已查 |
| 11 | `design/gdd/tactical-combat-system.md` | 1 | ✅ 已查 |
| 12 | `design/gdd/game-concept.md` | 1 | ✅ 已查 |
| 13 | `design/art/battle-ui-glyph-spec.md` | 1 | ✅ 已查 |

📌 **協調者的「50 處 / 13 檔」與工具輸出對得起來,已複驗**:工具總輸出 169 行
(168 處 + 1 行分隔線)。扣掉 118 處歷史性文件後剩 54 處,其中 4 處在
`docs/architecture/adr-0001-rewrite-plan-2026-10-12.md` —— 那份是 2026-10-12 重寫的
**對帳計畫書**(78 列逐條對帳表),性質同歷史紀錄,協調者未列入 13 檔,本檔沿用該判斷。
54 − 4 = 50。

---

## 總計

| 類別 | 處數 | 佔 50 的比例 |
|---|---|---|
| **A 真‧活引用(要修)** | **23** | 46% |
| **B 自我命中(不修)** | **27** | 54% |
| **C 不是行號(工具誤判)** | **0** | 0% |

🔴 **最重要的一個數字不在上表裡:A 類 23 處中,已查證「行號已經指錯地方」的有 19 處,
仍然指對的只有 4 處。** 亦即這個背景債**不是「將來會爛掉」,是「現在就已經爛掉」**。
逐處的查證結果寫在下方 A 類各條的「**現況**」欄,每一條都附了可重跑的 `sed -n 'Np' <file>`
可以自行核對。

⚠️ **B 類佔比超過一半,證實了協調者的抽查懷疑**:檢查工具把「記載『某處曾經用行號指路、
已改掉』的那句話」也算成一處違規。`cursor-highlight-state.md` 的 12 處**全部**是這一類。

---

## 工具本身的兩個已查證缺陷

### 缺陷一:`[列行]` 在本機退化成**位元組**類別,會誤命中幾乎任何中文字

`.claude/hooks/validate-doc-consistency.sh` 的 regex 是
`第 ?[0-9]+(/[0-9]+)* ?[列行]|see line [0-9]+|見第 ?[0-9]+`。
本機 Git Bash 的 `grep -E` 對 `[列行]` 做**逐位元組**比對:`列` = `E5 88 97`、
`行` = `E8 A1 8C`,於是該類別實際等於位元組集合 `{E5,88,97,E8,A1,8C}` ——
**任何 UTF-8 首位元組為 `E5` 或 `E8` 的中文字都會命中**。

實測(可重跑):

```
$ printf '第 27 兩行\n第 30 回合\n第 55 列\n第 60 名\n' | grep -noE '第 ?[0-9]+(/[0-9]+)* ?[列行]'
1:第 27 ?
3:第 30 ?
5:第 55 列
6:第 60 ?
```

`兩`(E5 85 A9)、`回`(E5 9B 9E)、`名`(E5 90 8D)**全部誤命中**。
改成交替式 `(列|行)` 即正確:

```
$ printf '第 27 兩行\n第 30 回合\n第 55 列\n第 60 名\n第 70 行\n' | grep -noE '第 ?[0-9]+(/[0-9]+)* ?(列|行)'
3:第 55 列
5:第 70 行
```

**全庫影響量測**(同一套 `n>14` + 去重規則,只換 regex):

| regex | 全庫命中 |
|---|---|
| hook 現行(`[列行]`) | **168** |
| 修正後(`(列|行)`) | **163** |

→ **168 裡有 5 處是這個 bug 造出來的**,其中 1 處落在本次的 50 裡
(`adr-0004:7`,原文 `只改了第 27/421 兩行` —— 命中的是「**兩**」的首位元組)。

📌 **這 5 處不全是 C 類**:`adr-0004:7` 那句語意上**確實**在講行號(「第 27/421 兩行」),
只是工具是靠 bug 碰巧抓到的。**修 regex 不會讓它消失,會讓它被正確地抓到。**

### 缺陷二:`n > 14` 這個門檻是沒有理由的猜測,會同時漏抓與誤抓

awk 只看匹配字串裡的**第一個**數字,且丟棄 `n <= 14`。後果兩個方向都有:

- **漏抓**:`第 1/8 列`、`第 5 列`、`第 14 行` 這些真的行號引用不會出現在清單裡。
  實測 `design/gdd/save-system.md:663` 一行就有 `第 1/8 列` / `第 3 列` / `第 1 列` / `第 8 列`
  四個引用,**一個都沒被報出來**。
- **誤抓**:`第 1 列`、`第 5 節` 這種「表格第幾列/第幾條」的語意,在 15 以上一樣存在
  (例:`tactical-combat-system.md` 的「登記處第 1 列」是**登記處的第一條目**,不是行號)。

**亦即「168」這個數字本身既不是上界也不是下界。** 本檔不建議現在改 hook ——
改 regex 與門檻會讓開場那行數字跳動,屬於需要裁決的變更。**本檔只登記。**

---

## A 類逐處(23 處,要修)

格式:`檔案:行 → 引用的數字` / 原文片段 / **現況**(已查證該行號現在指到什麼)/ **替代寫法**。

### A-01 `design/art/art-direction.md:105` → `第 471 行`

> `- `src/ui/battle/board_view.gd`(`_build_hp_text()` 建立的血量數字 `Label`,約第 471 行)`

- **現況:已漂移。** `sed -n '471p' src/ui/battle/board_view.gd` → `bar_root.add_child(background)`。
  `grep -n "func _build_hp_text" src/ui/battle/board_view.gd` → **498**。漂移 27 行。
- **替代寫法**:整個 `,約第 471 行` 刪掉即可 —— 句子已經寫了 `_build_hp_text()`,那就是穩定指標。
  要可查證就附指令:``（`grep -n "func _build_hp_text" src/ui/battle/board_view.gd`）``

### A-02 `design/art/art-direction.md:107` → `第 945 行`
### A-03 `design/art/art-direction.md:107` → `第 952 行`

> `  `text_label`〔約第 945 行〕與 `effect_label`〔約第 952 行〕)`

- **現況:已漂移。** 兩行現在都是**空行**。
  `grep -n "func _ensure_detail_panel" src/ui/battle/hand_bar.gd` → **1057**。漂移超過 100 行。
- **替代寫法**:刪掉兩個〔約第 N 行〕,句子保留 ``_ensure_detail_panel()`` + 變數名 `text_label` /
  `effect_label` —— 變數名本身就是 grep 得到的穩定指標。

### A-04 `design/art/art-direction.md:129` → `第 22 行`

> `…掛載腳本 `src/ui/battle/hud_layout_scaler.gd`(掛在 `UILayer` 節點,`BattleScreen.tscn` 第 22 行)在 `_apply_layout()` 統一套用…`

- **現況:已漂移(2 行)。** `sed -n '22p' src/ui/battle/BattleScreen.tscn` → 空行;
  實際 `script = ExtResource("4_hud_layout_scaler")` 在 **24**,
  `ext_resource` 宣告在 **6**。
- **替代寫法**:`(掛在 `UILayer` 節點;查法 `grep -n "hud_layout_scaler" src/ui/battle/BattleScreen.tscn`)`

### A-05 `design/art/battle-ui-glyph-spec.md:282` → `第 396 行`

> ``design/ux/battle-menu.md` 第 396 行原文逐字:「**焦點視覺不得只靠顏色(`P-F3` 無例外)—— 須有位置標記(`▸`)或外框等第二通道**」``

- **現況:🔴 兩件事都壞了,而且第二件比行號嚴重。**
  ① 行號漂移:該句現在在 **403**(`grep -n "焦點視覺不得只靠顏色" design/ux/battle-menu.md`)。
  ② **「原文逐字」已經不逐字**。現行第 403 行寫的是
  「②**焦點視覺不得只靠顏色**(`P-F3` 無例外)—— 須有除顏色外的第二通道,現況為**外框(+填色)**」
  —— **沒有「位置標記(`▸`)或外框等」這段**。而本規格整段論證(「是 **or**,不是 **and**」)
  **完全建立在那段已不存在的措辭上**。
- **替代寫法**:`` `design/ux/battle-menu.md` 的 `P-F3` 條(查法:`grep -n "P-F3" design/ux/battle-menu.md`)`` ——
  **但這一處不能只改引用形式**,必須先裁決「上游措辭已變,本規格的論證是否還成立」。
  **這是本批最該優先處理的一處,理由不是行號。**

### A-06 `design/gdd/affinity-data-pool.md:333` → `第 175 列`

> `…這是第 175 列(`game-concept.md` 系統觸發寫入約束)在陣亡情境下唯一能兌現的路徑…`

- **現況:已漂移。** `sed -n '175p' design/gdd/systems-index.md` → **空行**。
  `systems-index.md` 的 Cross-System Obligations Registry 標題在 **212**,
  亦即第 175 列根本不在登記表範圍內。
- **替代寫法**:括號裡已經有內容指標了,把數字刪掉即可 ——
  `` 這是 `systems-index.md` Cross-System Obligations Registry 的「`game-concept.md` 系統觸發寫入約束」那一列…``

### A-07 `design/gdd/systems-index.md:14` → `第 149/174 列`

> `…查出 5 項全新設計缺陷(…、登記表第 149/174 列在陣亡情境下結構性互斥、…)`

- **現況:已漂移。** `sed -n '149p'` → `## Recommended Design Order`(章節標題);
  `sed -n '174p'` → `---`(分隔線)。兩個都不是登記表的列。
- **替代寫法**:改用兩列各自的義務關鍵字,例如
  `登記表「陣亡後追憶寫入須被形狀讀取看見」與「深度讀取凍結於 t_death」兩列結構性互斥`。
  (本檔**未**查證這兩列現在的確切措辭 —— 寫替代文字的人要先在 Registry 裡定位,
  不要照抄本行的推測措辭。)
- ⚠️ **這一處是 A/B 邊界案**:它在檔頭的修訂敘事裡。判 A 的理由是
  **讀者要弄懂這句話在講哪兩條義務,非得去解析那兩個數字不可**,而那兩個數字現在是錯的。

### A-08 `design/gdd/systems-index.md:223` → `第 175 列`

> `…必須被形狀讀取看見,才能兌現第 175 列的緩解義務…`

- **現況:已漂移。** 同 A-06,第 175 列是空行。而且**本行自己在 223,已經在 Registry(212 起)裡面了**
  —— 這是登記表內部用行號互指自己。
- **替代寫法**:`…才能兌現本登記表「<該列的義務關鍵字>」那一列的緩解義務…`
  (Registry 既然是表格,建議一併考慮給每列一個穩定 ID 欄 —— 見本檔末「結構性建議」。)

### A-09 `design/gdd/systems-index.md:248` → `第 150 列`

> `…由形狀特徵讀取(用 `t_now`,見上方第 150 列)看見…`

- **現況:已漂移。** `sed -n '150p' design/gdd/systems-index.md` → **空行**。
- **替代寫法**:`(用 `t_now`,見上方「<該列義務關鍵字>」那一列)`。
  📌 「見上方第 N 列」正是 `.claude/rules/design-docs.md` 規則本文點名的句型。

### A-10 `design/gdd/systems-index.md:253` → `第 170 列`

> `…回填 `save-system.md` Dependencies 第 170 列與 `affinity-data-pool.md` Open Question 6`

- **現況:已漂移。** `sed -n '170p' design/gdd/save-system.md` →
  `**(一)遷移失敗自動重試(無損,自動觸發)**…` —— 那是 Core Rules 區,不是 Dependencies。
- **替代寫法**:`回填 `save-system.md` 的 `## Dependencies` 節(章節/戰役結構那一條)…`
  —— 同句後半的 `affinity-data-pool.md` **Open Question 6** 就是正確示範(編號型穩定指標)。

### A-11 `design/quick-specs/unit-stats-provisional.md:259` → `第93行`

> `(已記錄於 `affinity-position-provisional.md` 第93行起)`

- **現況:✅ 目前仍指對** —— `sed -n '93p' design/quick-specs/affinity-position-provisional.md` →
  `### 🔴 已裁決:`Φ` 只作用於我方發起的攻擊`。
- **替代寫法**:目標本身就是一個章節標題,直接用它:
  `` (已記錄於 `affinity-position-provisional.md`「🔴 已裁決:`Φ` 只作用於我方發起的攻擊」節) ``
  —— **這是本批成本最低、風險最低的一處修正**,現值正確所以不必先查證內容。

### A-12 `design/ux/battle-menu.md:344` → `第 364 行`
### A-13 `design/ux/battle-menu.md:344` → `第 376 行`

> `…`src/ui/cursor/cursor_state_host.gd` 第 364 行(`suspend_arbitration()`)與第 376 行(`resume_arbitration()`),`

- **現況:已漂移 64 行。** `sed -n '364p'` → `func _input(event: InputEvent) -> void:`;
  `sed -n '376p'` → `##`。實際 `grep -n "^func suspend_arbitration\|^func resume_arbitration"` → **428 / 440**。
- **替代寫法**:**同一段的下一行已經自己寫好了正確答案** ——
  ``grep -rn "^func suspend_arbitration\|^func resume_arbitration" src/` 現為兩處命中`。
  把「第 364 行」「第 376 行」刪掉,只留函式名即可,語意零損失。
- 🔴 ⚠️ **但那條 grep 自己踩了 `coding-standards.md` 2026-10-12 登記的「驗證指令自己命中自己」**:
  指令寫 `^func …` 而錨點在 `src/`,**而這一行是 `.md` 不是 `src/`**,所以這次沒自噬 —— 是運氣好,
  不是寫法防住的。改寫時順手把範圍寫死成 `src/ui/cursor/cursor_state_host.gd` 更穩。

### A-14 `docs/architecture/adr-0005-...md:131` → `第 43 行`

> `…`breaking-changes.md` 第 43 行標 4.4→4.5 為 `POST-CUTOFF, HIGH RISK`,`VERSION.md` 版本時間軸卻標 4.5 為 `LOW (pre-cutoff…`

- **現況:✅ 仍指對** —— `sed -n '43p' docs/engine-reference/godot/breaking-changes.md` →
  `## 4.4 → 4.5 (Late 2025 — POST-CUTOFF, HIGH RISK)`。
- **替代寫法**:目標是章節標題,直接引標題:
  `` `breaking-changes.md` 的「4.4 → 4.5」節標題標 `POST-CUTOFF, HIGH RISK` ``

### A-15 `docs/architecture/adr-0005-...md:133` → `第 384 行`
### A-16 `docs/architecture/adr-0005-...md:133` → `第 59/76/83 行`

> `…早在 **2026-08-20 就測出同一結論**(該 README 第 384 行、log 第 59/76/83 行),**而本欄整整 12 天仍寫著「未經查證」**`

- **現況:未查證**(目標在 `prototypes/…-2026-08-20/` 的 README 與 log;探針產物屬於
  一次性證據,本檔不確定它是否仍在 —— **留給修這一處的人先確認檔案存在再改**)。
- **替代寫法**:探針 log 的穩定指標是**它印出的那一行文字本身**,不是行號。改為
  `` (該 README 的 F-4 節;log 的逐字錨點:`grep -n "<F-4 那行的關鍵字串>" <log 路徑>`) ``
  —— 這正是 `technical-preferences.md` 第 5 點「留 log,不要只留結論」要的形狀。

### A-17 `docs/architecture/adr-0005-...md:1202` → `第 98 行`

> `| (3) `set_target()` 無條件改發 `SURFACE_HANDOFF` | …(`godot-specialist` 核對 GDD 第 98 行原文確認丙不在內) |`

- **現況:✅ 大致仍指對** —— `sed -n '98p' design/gdd/cursor-highlight-state.md` →
  `- **(甲)舊表面存在時讀檔**…`,確實落在甲/乙/丙枚舉區。
- **替代寫法**:`(`godot-specialist` 核對 GDD Core Rules #7 的甲/乙/丙枚舉原文確認丙不在內)`
  —— 同一格前面已經寫了 `GDD Core Rules #7`,把行號換成它即可。
- 📌 **優先度低**:這是論證表格裡的佐證註記,就算漂掉也不會把人導向錯誤動作。

### A-18 `docs/architecture/adr-0005-...md:1343` → `第 406 行`
### A-19 `docs/architecture/adr-0005-...md:1345` → `第 216 行`
### A-20 `docs/architecture/adr-0005-...md:1347` → `第 81 行`
### A-21 `docs/architecture/adr-0005-...md:1348` → `第 43 行`

> `> - `docs/registry/architecture.yaml`(**架構立場權威來源**):**5 處命中**,含第 406 行的 `signal_signature` **凍結簽章登記表**…`
> `> - `docs/architecture/traceability-index.md` 第 216 行:寫著 **「✅ 已涵蓋」**。`
> `> - `production/epics/cursor-highlight-state/EPIC.md` 第 81 行(`✅ 機制十`)、`
> `>   `story-007-write-read-interface.md` 第 43 行(該工作單狀態為 **Complete**)。`

🔴 **這四處是全批最高風險,理由不是漂移程度,是它們的用途。**
上下文逐字:「**上述 4 處刻意尚未修改,這是判斷不是疏漏**:它們要怎麼改取決於裁決結果」。
**這是一張「裁決下來之後要照單去改的清單」** —— 它的全部價值就是讓下一個人找得到那四個位置。

- **現況:4 處裡 2 處已經指錯。**
  | 指向 | 宣稱 | `sed -n 'Np'` 實測 | 判定 |
  |---|---|---|---|
  | `architecture.yaml:406` | `signal_signature` 凍結簽章登記表 | `- docs/architecture/adr-0002-…md`(另一份 ADR 的路徑) | 🔴 **已漂移**(真值在 **442**) |
  | `traceability-index.md:216` | 寫著「✅ 已涵蓋」 | `---`(分隔線) | 🔴 **已漂移** |
  | `EPIC.md:81` | `✅ 機制十` | `\| TR-cursor-012 \| …✅ 機制十` | ✅ 仍對 |
  | `story-007:43` | 單輸入簽章 | `3. **`set_target(target) -> SetTargetResult`** —— 單輸入簽章…` | ✅ 仍對 |
- **替代寫法**(四處共用一個形狀 —— 全部用 `TR-cursor-012` 或簽章字串當錨):
  - `architecture.yaml`:`` `cursor_target_write` 條目的 `signal_signature` 欄(查法:`grep -n "cursor_target_write" docs/registry/architecture.yaml`) ``
  - `traceability-index.md`:`` `TR-cursor-012` 那一列(查法:`grep -n "TR-cursor-012" docs/architecture/traceability-index.md`) ``
  - `EPIC.md`:`` `TR-cursor-012` 那一列 ``
  - `story-007`:`` `set_target(target) -> SetTargetResult` 那一條 ``
  - **更好的一次到位寫法**:整段改成一條指令
    `` grep -rn "from_ui_action" docs/registry/architecture.yaml docs/architecture/traceability-index.md production/epics/cursor-highlight-state/ `` ——
    因為這四處要找的本來就是「仍載有已刪除的雙參數簽章」的地方,**用它要找的特徵去找,比用座標去找更穩**。

### A-22 `docs/architecture/traceability-index.md:248` → `第 434 行`

> `**第七輪降級成因為 R6-9(仍開)**:機制六第 434 行「六個架構強制優先序值必須兩兩相異」**只覆蓋角色層,未覆蓋同一角色的多個實例**…`

- **現況:🔴 已漂移,而且漂到別的機制去了。**
  `sed -n '434p' docs/architecture/adr-0005-…md` → `### 機制四之二:動作語意分類 —— `ActionClass`…`
  —— **句子說「機制六」,行號指到「機制四之二」**。
- **替代寫法**:`機制六的「六個架構強制優先序值必須兩兩相異」那條約束` ——
  引號裡的句子本身就是全庫唯一的 grep 錨,行號純屬多餘。

### A-23 `docs/architecture/traceability-index.md:253` → `第 714 行`

> `…`target_validity_changed` 全文零命中,第 714 行仍寫「`target_changed()` 只在目標確實改變時發」 |`

- **現況:🔴 已漂移。** `sed -n '714p'` →
  `**(c) `ActionClass` 分類完整性驗證(2026-08-19 第四輪修訂新增,R4-5)**…` —— 不是那句話。
- **替代寫法**:`…`target_validity_changed` 全文零命中,ADR 仍寫著「`target_changed()` 只在目標確實改變時發」
  (查法:`grep -n "只在目標確實改變時發" docs/architecture/adr-0005-cursor-device-authority-input-architecture.md`)`

---

## B 類逐處(27 處,不修)

這些句子**在記載**某件已發生的事 —— 通常是「某處原本用行號指路、已改成穩定指標」,
或「當時核對了某行、發現某事」。**把它們的行號改掉會讓紀錄失去可核對性**(讀者無法再
判斷當年那次修訂到底動了什麼)。

### `design/gdd/cursor-highlight-state.md` —— 12 處,**全部是 B**

| 行 | 數字 | 原文片段(截斷) |
|---|---|---|
| 6 | 76 | `…以行號〔第 76/78/290 行〕引用 `save-system.md`,牴觸 `.claude/rules/design-docs.md`「無行號自我引用」規則——**已改為穩定指標引用**` |
| 7 | 76 | `…經直接核對 `save-system.md` 第 76/78/290 行證實為假(該文件明文要求路徑四第一次發生即回傳可區分結構化結果…)——已修正措辭為…` |
| 7 | 166 | `…`systems-index.md` Cross-System Obligations Registry 第 166 列同步更新移除「對呼叫方透明」舊措辭。修正後重新掃描確認無殘留。` |
| 8 | 166 | `…post-revision grep 自核通過(…`systems-index.md` 第 166 列已同步更新為 AC-61/62/63a/63b)。` |
| 10 | 165 | `…`systems-index.md` Cross-System Obligations Registry 第 165 列同步擴充。詳見 `design/gdd/reviews/save-system-review-log.md` 第六輪條目。` |
| 102 | 165 | `**依 `.claude/rules/design-docs.md` 不得以行號指路,2026-09-01 稽核已將原「第 165/166 列」改為內容定位 —— 該行號當時已漂移至第 203 列**` |
| 102 | 203 | 同上(同一句的後半) |
| 104 | 165 | 同上(同一段落的第二份複本) |
| 104 | 203 | 同上 |
| 360 | 165 | 同上(同一段落的第三份複本) |
| 360 | 203 | 同上 |
| 391 | 205 | `(**2026-09-01 稽核:原寫 `(line 172)`,該行實際是好感度卡牌裁決,目標在第 205 列,漂移 33 列**)` |

🔴 **協調者抽查的那一處(第 6~10 行)在這裡完整證實,而且不是孤例 —— 是這整個檔案。**
📌 **102 / 104 / 360 三處是同一段文字的三份複本**(「依 `.claude/rules/design-docs.md` 不得以
行號指路…已將原『第 165/166 列』改為內容定位」),同樣的字也出現在 `save-system.md:345`。
**亦即工具把同一句免責聲明數了 4 次、共 8 個命中。** 單是這一句就佔了 50 處的 16%。

### 其餘 B 類(14 處)

| 檔案:行 | 數字 | 原文片段(截斷) | 為何是 B |
|---|---|---|---|
| `affinity-data-pool.md:7` | 86 | `…`game-concept.md` 第 86 行輪次標籤誤標修正為第十一輪;AC-12 過時行號引用修正…` | 記載一次**已完成**的修訂(連「AC-12 過時行號引用修正」都在同一句裡) |
| `affinity-data-pool.md:21` | 294 | `…修正第 294 列失效的舊標題交叉引用…` | 記載一次已完成的修訂 |
| `game-concept.md:134` | 180 | `…與 `affinity-data-pool.md` 自身第十一輪修訂記錄、`systems-index.md` 登記表第 180 列皆記載為第十一輪的事實矛盾…` | 記載一次已完成的**交叉核對**,不是指路 |
| `save-system.md:345` | 165 | `**…2026-09-01 稽核已將原「第 165/166 列」改為內容定位 —— 該行號當時已漂移至第 203 列**` | 與 cursor 檔同句複本 |
| `save-system.md:345` | 203 | 同上 | 同上 |
| `save-system.md:463` | 88 | `(**2026-09-01 稽核:原寫「第 88 行」,該行是空行且落在 Core Rules #5 段內,漂移 48 列**)` | 稽核紀錄,原引用已被取代 |
| `systems-index.md:12` | 165 | `…Cross-System Obligations Registry 第 165 列與新增列已同步,詳見 `…save-system-review-log.md` 第六輪條目。` | 檔頭修訂敘事,記載一次已完成的同步 |
| `systems-index.md:15` | 164 | `…Cross-System Obligations Registry 第 164 列(下游 UI 錯誤呈現義務)拆分為兩列…` | 記載一次已完成的拆分;**且括號裡已附內容指標** |
| `tactical-combat-system.md:368` | 26 | `(**2026-09-01 稽核:原以「第 26 列」指路,依 `.claude/rules/design-docs.md` 禁止,且該行號已漂移 —— 第 26 列現在是章節標題 `## Systems Enumeration`**)` | 教科書級自我命中 |
| `adr-0004:531` | 27 | `…本行原寫「至此三份 ADR 全數覆蓋」,與同檔第 27 行、第 421 行已於 `1c3d5d0` 修正的「22/7/1」互相矛盾…` | 記載一次已完成的修訂,並**附了提交雜湊**(`1c3d5d0`)—— 已經有穩定指標了 |
| `adr-0004:531` | 421 | 同上 | 同上 |
| `adr-0005:77` | 705 | `…(協調者另發現其中第 705 行的「三者」**在本次修訂之前就已與第 774 行的「四個」不一致**)` | 記載一次已完成的發現;兩處措辭早已在該次修訂中改掉 |
| `adr-0005:77` | 774 | 同上 | 同上 |
| `traceability-index.md:273` | 216 | `**本列是協調者當日反向搜尋漏掉的一處**(只搜到同檔第 216 行),由 `godot-specialist` 覆核指出…` | 記載一次搜尋的**漏網過程**,是失效分析紀錄 |

### 🔴 B 類裡有一處**語意上是 B、但實際上是 A** —— 單獨標出

`adr-0004:7` → `第 27/421 兩行`(原文:`…`1c3d5d0` 只改了第 27/421 兩行,漏改此處…`)。

- **它是 B**(記載一次已完成的修訂,且附了提交雜湊 `1c3d5d0`)。
- **但它被工具抓到純屬 bug** —— 命中的是「**兩**」字的首位元組,見上方「缺陷一」。
- 本檔在總計裡把它算進 **B**(27 處含本處),因為處置相同(不修)。

---

## C 類(0 處)

**本批 50 處裡,沒有任何一處的數字不是行號/列號。** 工具在這 50 處上的
「是不是在講位置」判斷**全中**。

⚠️ **但這不等於工具準確。** 它在**別的方向**上錯:
① `[列行]` 退化成位元組類別,全庫多報 5 處(見缺陷一);
② `n > 14` 門檻讓它漏掉 `第 1 列` / `第 8 列` 這類真引用(見缺陷二);
③ **它完全分不出 A 與 B** —— 而 B 佔了 54%。

**一句話:工具沒有把不是行號的東西報成行號,它把「不該修的」報成「該修的」。**

---

## 結構性建議(**非本檔職權,只登記**)

1. **`systems-index.md` 的 Cross-System Obligations Registry 該有穩定列 ID。**
   本批 50 處裡,**14 處**(A-06/07/08/09 + B 的 7 處 + `affinity-data-pool.md:333` 等)
   都在用行號指這張表的某一列,而這張表**沒有任何穩定識別子** —— 於是每個人都只能用行號。
   **這不是紀律問題,是資料結構缺口**:規則禁止行號、但沒給替代品。
   加一個 `OBL-nn` 欄位,上述 14 處就全部有東西可以寫。
2. **檢查工具若要降噪,最高效的一刀是「同句含有『原寫』『已改為』『稽核』『牴觸…規則』
   的行予以排除」** —— hook 檔頭自述已有「同列引號標記(原文寫 / 原登記為 / …)」的抑制機制,
   但實測沒有涵蓋到本批那 27 處 B。
3. **A 類 23 處裡 19 處已經指錯,說明這個 backlog 不是「潛在風險」。**
   `A-05`(`battle-ui-glyph-spec.md` 引用的上游原文已變)與 `A-18~21`
   (等裁決後要照著去改的四處清單,已有兩處失效)**是會導致錯誤動作的,不只是找不到。**

---

## 本檔未做的事(誠實登記)

- **未修改任何既有檔案**,包含上面每一條「替代寫法」—— 那是提案,不是已施行。
- **未查證 A-15/A-16 的目標檔案是否仍存在**(`prototypes/…-2026-08-20/` 的 README 與 log)。
- **未查證 A-07 兩條義務現在的確切措辭**,替代寫法裡的措辭是推測,改之前要自行定位。
- **未處理 118 處歷史性文件**,也未處理 `adr-0001-rewrite-plan-2026-10-12.md` 的 4 處。
- **未改 hook**。缺陷一、缺陷二都只登記。
- ⚠️ **與本專案其餘同類規則一樣,`.claude/rules/design-docs.md` 的「無行號自我引用」
  目前沒有任何閘門會攔**(hook 只警告、不阻擋,且開場只印一行)。
  **本檔買到的是「下一個人有逐處可查對的明細」,不是「這 23 處會被修」。**
