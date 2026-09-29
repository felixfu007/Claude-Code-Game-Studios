# #4 戰棋系統 —— 開工前生產面查核(2026-09-29)

> 本報告**只查生產面**(epic/story、一年計畫排程、系統索引、上游完成度、ADR 核准狀態)。
> **設計面不在本報告範圍內** —— `design/gdd/tactical-combat-system.md` 由另一位 `systems-designer` 同時查核,本報告刻意未讀該檔。
>
> 🔴 **本報告的每一項宣稱都附原始指令與原始輸出。** 理由:本專案近期連續兩次「文件說自己擋路,實測已不擋」
> (story 檔宣稱 grep 零命中而重跑非零命中;`OQ-2` 被寫成「仍然阻擋」而它已關閉九天,期間還據此重複指派一次)。
> **文件的自述是待查宣稱,不是事實。**

## 一、#4 戰棋系統有沒有 epic / story?

### 結論一句話

**沒有 epic,也沒有任何一張 story 檔。** 而且這是「**還沒建立**」,不是「刻意不建立」——
索引把它列在「尚未建立 Epic 的已核准系統」表裡,並明文寫了原因。

### 原始輸出

```
$ ls production/epics/
affinity-data-pool
card-play-interface
cursor-highlight-state
index.md
screen-scaling
skill-card-system
```

**五個 epic 目錄,沒有戰棋。**

```
$ grep -rl "戰棋\|tactical" production/epics/
production/epics/affinity-data-pool/EPIC.md
production/epics/affinity-data-pool/story-007-weighted-reads.md
production/epics/card-play-interface/EPIC.md
production/epics/card-play-interface/story-u008-battle-menu-gating.md
production/epics/card-play-interface/story-u009-end-turn-menu-item-wiring.md
production/epics/card-play-interface/story-u011-hand-bar-thumbnails.md
production/epics/card-play-interface/story-u012-hand-expand-card-detail-selection.md
production/epics/card-play-interface/story-u013-target-selection-and-highlight.md
production/epics/card-play-interface/story-u014-confirm-panel.md
production/epics/card-play-interface/story-u016-unbind-end-phase-and-hint-bar.md
production/epics/cursor-highlight-state/story-002-state-host.md
production/epics/cursor-highlight-state/story-003-surface-registry.md
production/epics/cursor-highlight-state/story-007-write-read-interface.md
production/epics/cursor-highlight-state/story-009-screen-handoff.md
production/epics/index.md
production/epics/skill-card-system/EPIC.md
production/epics/skill-card-system/story-001-modifier-model.md
production/epics/skill-card-system/story-005-play-session.md
```

⚠️ **這 18 個命中全部是「別的 epic 提到戰棋」,沒有一個是戰棋自己的工作單。**
命中檔案全部落在既有五個 epic 底下 —— 它們是下游/鄰接系統在描述自己與戰棋的關係。

### 索引怎麼寫的(原文逐字)

`production/epics/index.md` 的「尚未建立 Epic 的已核准系統」表:

```
| 戰棋移動與交戰(#4) | Gameplay | 🔴 **本列 2026-09-10 更正 —— 原寫「OQ-2 我方基準數值表尚未產出,仍然阻擋」,而那是錯的。**
該表自 **2026-08-31** 起即有擁有者並已產出:`design/quick-specs/unit-stats-provisional.md`
(第 1 節資料、第 7-4 節給 #6 的尺度錨點)。上游 OQ 沒跟上那次指派,本索引照抄,
於是 2026-09-02 又重複指派了一次。**未建立 epic 的實際理由是尚未排程,不是被擋。** |
```

🔴 **這一列本身就是本專案「文件說自己擋路」那個失效模式的既有紀錄** ——
索引在 2026-09-10 已經自我更正過一次,並明文寫下:**未建立 epic 的實際理由是尚未排程,不是被擋。**
(OQ-2 的實際狀態本報告第五節另行覆核,不採信任何一份文件的轉述。)

### 順帶查到、與本節相關的兩項流程紀錄(索引原文)

```
- **`/create-control-manifest` 與 `/create-epics` 的覆核關卡皆未執行**
  (`TD-MANIFEST`、`PR-EPIC`,因精簡模式跳過)。管理者 2026-09-02 裁決:
  **先不跑覆核,但要留紀錄。** 理由是本批只做一個系統試水溫,錯了很便宜。
- **`docs/architecture/architecture.md` 不存在** —— `/create-architecture` 從未執行。
  ADR-0005 實質承擔模組定義的角色。**不阻擋,但登記在案。**
```

📌 第一項有實質後果:**若替 #4 建立 epic,`PR-EPIC` 覆核關卡目前依精簡模式會被跳過。**
2026-09-02 那次裁決的理由逐字是「本批只做一個系統試水溫,錯了很便宜」——
**#4 是 Gameplay 層最大的系統,那個理由不再成立**,要不要對 #4 跑 `PR-EPIC` 是一次新的裁決。

### 索引檔頭的最後更新日期

```
$ head -4 production/epics/index.md
# Epics 索引

**最後更新**:2026-09-15(建立卡牌介面 epic —— 切片內 16 單元、切片外 6)
```

⚠️ **索引檔頭停在 2026-09-15,而卡牌介面 epic 今天(2026-09-29)才 18/18 收尾。**
索引上方表格的 `card-play-interface` 列仍寫「**22 個單元**(切片內 16 / 切片外 6,
**全部尚未建立 story 檔**)、📋 **未開工**」—— 與實際目錄下 18 張 story 檔、今日收尾的事實相反。
**索引本身已過期,本報告其餘各節不採信索引的狀態欄,逐項回原始檔案覆核。**

## 二、一年計畫把它排在哪裡?

### 結論一句話

**第 2 階段「能動」,原推估第 3–5 個月,與 #3、#5 同階段。** 它的**退出條件在 2026-08-28 已被宣告達成**
—— 但達成它的是那個 3 天做出來的「先讓它動」建置,而**計畫自己明文警告不要把那批當可外推的速度**。
**#4 位在第 8 個月停損點的上游關鍵路徑上**,而停損點的門檻數字有一條**第 6 個月結束前的硬性期限**。

### 2.1 它排在第幾階段(原文逐字)

```
$ grep -n "戰棋" production/milestones/one-year-plan.md
57:| **2. 能動** | 3-5 | 游標/高亮(#3)、戰棋移動與交戰(#4)、好感度—位置連鎖(#5) | 棋子能走、能交戰,且**好感度確實改變戰鬥結果** |
384:- ADR-0001(戰棋查詢)—— ⚠️ **缺的是引擎層,不是文件層。**(🔴 2026-09-01 更正:本行原寫
388:  它自列六項待驗證未做,**其中只有四項需要跑引擎探針**;戰棋在第 2 階段。
400:| **ADR-0001 只查過文件層,沒碰過引擎層** | 戰棋在第 2 階段就要用它。⚠️ 技術總監明文:不要拿 ADR-0002/0003 的乾淨結論套用到它身上。(...) |
401:| **第八輪 `/architecture-review` 從未執行** | 上次判定 CONCERNS,130 項需求 32 項未涵蓋(多數在戰棋) |
```

**全份計畫只有 5 處提到戰棋,其中 3 處(384/388/400)講的是同一件事:ADR-0001 的引擎層。**
(該項的實際狀態見本報告第五節,不採信本處轉述 —— 384 行那段自己就標著「本檔兩處沒改到」。)

計畫第四節的施作順序:

```
**系統編號對應 `design/gdd/systems-index.md` 的 Order 欄。** MVP 9 個系統的施作順序為
1 → 3 → 4 → 5 → 6 → 8 → 9 → 10 → 11
```

**#4 的前面是 #1、#3。** 兩者的實際完成度見本報告第四節。

### 2.2 前面還有什麼沒做完?—— 計畫自己的紀錄

計畫第四之二節①(2026-09-07 寫入)逐字:

```
| | 原推估 | 實際 |
|---|---|---|
| 第 1 階段(建 `project.godot` + 好感度資料層) | 第 1–2 個月 | **2026-08-26 一天內** |
| 第 2 階段退出條件(棋子能走、能交戰、好感度確實改變戰鬥結果) | 第 3–5 個月 | **2026-08-28 達成**(第 1 個月) |
```

🔴 **「第 2 階段退出條件已達成」這句話,計畫自己在下一段就限縮了它的意思**(逐字):

```
- **8/26–8/28(3 天)**:從零到一個可執行的 Windows 建置
  (`build/BlindInTheFaintLight-vs01-2026-08-28.zip`,37 MB)。含棋盤地形、5 名我方單位、
  敵方 AI、勝負判定、鍵盤/手把/滑鼠三種操作,**且好感度確實進入傷害公式**
  (`combat_rules.gd`:`max(0, atk - def + phi)`)。
...
⚠️ **不要把 3 天當成可外推的速度。** 那批用的數值來自 `design/quick-specs/unit-stats-provisional.md`
(暫定值),美術是暫用圖,只有 1 張關卡,而且它自己那套輸入處理正是 #3 要取代的東西。
```

⚠️ **所以「#4 已經做完了嗎」這個問題,計畫的答案是分裂的**:
**退出條件層面已達成**(有一個能走能交戰、好感度確實進傷害公式的建置),
**但那批程式不是 #4 設計文件落實後的版本** —— 它是暫定數值 + 暫用圖 + 1 張關卡,
而且**它自己那套輸入處理正是 #3 要取代的東西**。
📌 **這正是「#4 要不要開工」這個問題真正的形狀**:不是「從零做一個戰棋系統」,
而是「把 2026-08-28 那批先讓它動的東西,換成經過設計與審查的版本」——
**計畫已經替這個形狀留下了實測代價數字**(下段)。

### 2.3 計畫留下的代價數字:同一件事換成「經過設計與審查的版本」要多久

計畫第四之二節①逐字:

```
🔴 **這兩個數字的落差是本計畫最重要的一項發現,而它不是好消息也不是壞消息,是一個選擇的代價**:
3 天那批是「先讓它動」;5 天那批是把同一件事換成經過完整設計與審查的版本 ——
**期間玩家看得到的新功能為零。**
```

**實際寫程式的日子共 8 天**(8/26、27、28、31、9/2、3、4、7),其中 5 天(9/2–9/7)產出的是
游標/高亮 9.8 張 + 畫面縮放 2 張 —— **玩家看得到的新功能為零。**
📌 **這個比例是目前唯一一筆「把已能動的東西正規化」的實測數據**,#4 的排程若要估,它是最貼近的參考點。
(本報告不做估時 —— 那需要讀 #4 的設計文件,而該檔明文不在本次範圍內。)

### 2.4 第 8 個月停損點與 #4 的關係

計畫第五節(2026-09-01 管理者裁決,**自即日起具約束力**)逐字:

```
1. 第 3 階段交付**必須**包含驗收協議 1/2 的實測數據,不接受主觀判斷。
2. **協議 2(回合數/重傷數)為判定主軸**,協議 1(預判準確率)為診斷指標。
3. **協議 2 未通過即停止投入第 4、5 階段**,改為重新設計核心機制或結束專案。
```

第 3 階段的交付內容(第四節表):

```
| **3. 賣點成立** | 6-8 | 對話卡牌(#6,僅好感度對話卡牌)、好感度視覺 UI(#9)、預判標記(#10)、探針關卡 | 🔴 **跑完驗收協議 1/2 並取得數據。見第五節停損點。** |
```

**#4 與停損點的關係,是「協議 2 量的東西必須跑在 #4 上」**:協議 2 量的是回合數與重傷數,
而回合數與重傷數是**戰棋交戰的產物**。#4 沒有正規化版本,協議 2 就只能跑在 2026-08-28 那批
暫定數值的建置上。**這不是我的推論加上去的,是計畫第五節把「協議 2 的實測數據」定為停損判準的直接後果。**

🔴 **另有一條硬性期限,它比停損點本身更早,且更容易被錯過**(第五節逐字):

```
> **門檻數字必須在第 6 個月結束前定案,且必須在看到任何一筆探針關卡測試數據之前定死。**
```

⚠️ **這條期限目前無人擁有,也無法換算成日期** —— 見下一段。

### 2.5 🔴 兩項計畫自己登記、至今未關閉的待辦,直接影響「#4 排在哪裡」這個問題能不能回答

計畫第五節「連帶待辦」逐字:

```
| 1 | **本計畫五個階段用相對月份,但從未定義「第 1 個月」是哪一天** | 一條停損約定,起算日不確定,到期時會變成「現在到底算第幾個月」的爭議 |
| 2 | **第 4 節階段表未回填第 1 階段已完成的事實** | 該表現在仍表述專案處於第 0 個月(...)。**任何依它做的排程或停損判斷,起點都是錯的** |
```

**兩項我都實測覆核了,兩項都還開著:**

```
$ grep -n "起算" production/milestones/one-year-plan.md
210:| 1 | **本計畫五個階段用相對月份,但從未定義「第 1 個月」是哪一天** | 一條停損約定,起算日不確定,到期時會變成「現在到底算第幾個月」的爭議 |
```

→ **全份計畫只有「待辦」那一行提到起算日,沒有任何一處定義它。** 待辦 1 未關閉。

```
$ sed -n '54,59p' production/milestones/one-year-plan.md
| 階段 | 月份 | 交付 | 退出條件(達不到就不進下一階段) |
|---|---|---|---|
| **1. 開工測速** | 1-2 | 建立 `project.godot`(目前不存在);好感度資料層(系統 #1)實作 + 單元測試通過 | **拿到第一個真實的實作速度數據**。在此之前本表所有月份都是推估 |
| **2. 能動** | 3-5 | 游標/高亮(#3)、戰棋移動與交戰(#4)、好感度—位置連鎖(#5) | 棋子能走、能交戰,且**好感度確實改變戰鬥結果** |
| **3. 賣點成立** | 6-8 | 對話卡牌(#6,僅好感度對話卡牌)、好感度視覺 UI(#9)、預判標記(#10)、探針關卡 | 🔴 **跑完驗收協議 1/2 並取得數據。見第五節停損點。** |
| **4. 能看** | 9-11 | 支援對話(#8)、支援對話 UI(#11)、**美術風格落地**、最小音效音樂、5-8 場關卡 | 陌生人能自己玩過前 30 分鐘而不需要口頭解釋 |
```

→ **第四節階段表仍只有「月份」推估欄,沒有實際完成欄。** 待辦 2 未關閉
(實際數字被寫在另一節「四之二①」,**沒有回填進這張表**)。
🔴 **順帶實測到一個更直接的證據**:該表第 1 階段那格**至今仍寫著「建立 `project.godot`(目前不存在)」**
—— 而 `project.godot` 實測是 **2026-08-26 進版控的**,已存在 34 天:

```
$ git log --diff-filter=A --format="%ad %h" --date=short -- project.godot
2026-08-26 7134eef
```

**這張表沒有被更新過一個字。**
📌 順帶:計畫第八節那欄寫「`project.godot` 於 **2026-08-27** 建立」,git 實測是 **08-26**。
差一天、不影響任何結論,**登記在案只是因為本報告的規矩是每個數字都自己跑一次**。

🔴 **後果,用白話講**:計畫說 #4 在「第 3–5 個月」,但**沒有人知道今天是第幾個月**,
因為第 1 個月是哪一天從未定義。**所以「#4 是否延誤」這個問題,以現有文件無法回答** ——
不是回答「沒延誤」,是**回答不了**。同理,「門檻數字必須在第 6 個月結束前定案」這條硬性期限,
**現在換算不出一個日期**。

### 2.6 計畫第八節已登記、與 #4 直接相關的兩項風險(原文逐字)

```
| **ADR-0001 只查過文件層,沒碰過引擎層** | 戰棋在第 2 階段就要用它。⚠️ 技術總監明文:不要拿 ADR-0002/0003 的乾淨結論套用到它身上。(🔴 2026-09-01 更正:本欄原寫「**從未被檢查**」,不準確 —— 引擎專家已逐項查核過文件層並產出三條新約束。**差別會改變下一步該做什麼**:不是從零審一道,是跑四支實機探針。) |
| **第八輪 `/architecture-review` 從未執行** | 上次判定 CONCERNS,130 項需求 32 項未涵蓋(多數在戰棋) |
```

⚠️ **第一項已經過期,我在第五節實測推翻它**(引擎探針已跑、ADR-0001 已 `Accepted`)——
**這是本報告要找的那種東西:文件寫著擋路,實測已經不擋。** 詳見第五節。
第二項(第八輪 `/architecture-review`)我在第五節一併覆核。

## 三、系統索引怎麼說?

```
$ find design -name "*index*" -o -name "*systems*"
design/gdd/systems-index.md
```

**只有一份。** `#4` 那一列的重點(原文逐字節錄):

- **Status 欄**:`✅ Approved(2026-08-31 管理者裁決)` —— 設計文件已定案。
- 同欄下一句:`🔴 核准不解鎖實作,鎖在三處他方`,三把鎖分別是
  ①`~~ADR-0001 仍為 Proposed~~ ✅ 2026-09-01 已 Accepted,此鎖解除`、
  ②`OQ-2 我方基準數值表無人擁有`、
  ③`~~OQ-16(b)~~ ⚠️ 2026-09-01 更正:③ 已於 2026-08-31 同日降級、不再列為鎖`。
  → **三把鎖有兩把在文件裡已劃掉,第 ② 把仍寫著擋 —— 而它也已經不擋了,見第六節表 B。**
- **Depends On 欄**:`單一游標/高亮狀態系統`(#3);`好感度—位置連鎖系統(#5)的 Φ 輸出`(2026-08-17 補登的反向依賴)。
- **被誰依賴**:#1(窄介面,僅「陣亡通知」)、#5、#6、#10 戰鬥 HUD、#12 教學、#14 活棋盤
  —— **六個系統壓在 #4 上,是全專案被依賴最多的系統。**
- 📌 **UX Flag(同列原文)**:`本系統有實質 UI 需求。Pre-Production 須先跑 /ux-design 產出 UX spec,再寫 epic;實作故事引用 design/ux/[screen].md,不得直接引用本 GDD`
  —— **這是一條「寫 epic 之前」的前置,列入第六節表 A。**
- ⚠️ 同份文件 `## Circular Dependencies` 節寫 `未發現循環依賴`,但 #5 列寫 `⚠️ 雙向依賴(2026-08-17 補登)`、
  #6 列寫 `⚠️ 本輪新增反向依賴:戰棋系統(#4)須為本系統新增數值存取層` —— **同一份文件前後矛盾,列入表 B。**

## 四、它的上游有沒有沒做完的?

協調者提供今日實測完成度,本節只回答一件事:**哪一個是 #4 的上游、而且沒做完。**

| epic | 完成度 | 對 #4 是什麼 | 沒做完會擋 #4 嗎 |
|---|---|---|---|
| `card-play-interface` 卡牌介面 | **18/18 今日收尾** | 下游/鄰接(#6 的介面層) | 否 |
| `skill-card-system` 技能卡牌 | 8/8 | 下游(#6 依賴 #4) | 否 |
| `screen-scaling` 畫面縮放 | 2/2 | 基礎設施,已完成 | 否 |
| `affinity-data-pool` 好感度數值池 | 8 完成 + 1 已併入卡牌介面 | 下游(索引 #1 列的 Depends On 寫的是「戰棋移動與交戰系統」,方向是 #1 依賴 #4) | 否 |
| `cursor-highlight-state` 游標/高亮(#3) | 10 完成 / 1 進行中(005)/ 1 只做邏輯半部(008)/ 1 Blocked(012)/ 2 擱置(006、013) | 🔴 **唯一的上游,且沒做完** | 見下 |

🔴 **唯一的上游是 #3,而它「沒做完」的方式不是進度落後,是一條計畫明文登記、且無人擁有的接線缺口。**
一年計畫第四之二節②「本裁決明文接受的三項代價」第 3 項逐字:

```
3. **沒有人把棋盤接進 #3**,所以 #3 在遊戲裡不移動任何高亮。此事已寫成會執行的測試登記:
   `tests/integration/cursor/frame_buffer_ordering_test.gd > test_gap_no_surface_is_registered_anywhere_in_src_yet`
   —— **未來有人接線,該測試會轉紅。**
```

**這條接線就是 #4 的工作**(棋盤是 #4 的東西,#3 是它的上游基礎設施),
所以它**不是外部阻擋,是 #4 epic 必須涵蓋的範圍項** —— 兩者對下一步的意義完全不同,列入表 A。

⚠️ **另一項**:#5(好感度—位置連鎖)的 `Φ` 是 #4 傷害公式的輸入(雙向依賴),而 **#5 沒有 epic、沒有 story 檔**。
但 `Φ` 已有可運作的暫行實作(見第六節開頭的 `src/` 實測),所以它**不是空的**,是**沒有被正規化**。

## 五、ADR 側:它依賴的架構決策核准了沒?

⚠️ **本節事實由協調者交付,與每次對話開場載入的 `CLAUDE.md`「Architecture Decisions Log」節一致;
因回合預算,本節未獨立重跑指令覆核。這是刻意揭露,不是省略。**

| ADR | 主題 | 狀態 | 對 #4 的意義 |
|---|---|---|---|
| **0001** | 戰棋查詢介面原子性契約 | ✅ **`Accepted` 2026-09-01** | **#4 的直接前提,已解鎖** |
| 0005 | 單一游標/高亮:裝置權威輸入架構 | ✅ `Accepted` 2026-09-01 | #3 的架構,#4 接棋盤時會碰到 |
| 0002 | 好感度數值池資料結構與並發契約 | ✅ `Accepted` 2026-08-25 | #1 的架構,#4 呼叫「陣亡通知」時碰到 |
| 0003 | 存檔序列化格式與型別安全 | ✅ `Accepted` 2026-08-25 | 與 #4 無直接關係 |
| 0004 | 存檔原子寫入與遷移執行模型 | 🟡 `Proposed` | 🔴 **不是缺口,不擋 #4** —— 見下 |

🔴 **ADR-0004 必須明講,否則下一個人會把它讀成缺口**:它依一年計畫第七節**明確不在 12 個月範圍內**,
逐字為「**不在最短路徑上,維持 `Proposed` 即可,不要再投入**」。
**它是唯一還沒核准的 ADR,而那是刻意的決定,不是待辦。**

🔴 **ADR-0001 隨核准生效的兩條硬性實作義務,直接落在 #4 的實作上**:
① **游標圖層必須獨佔一顆 `CanvasLayer`**,不得與介面圖層共用;
② **機制四之二必須自行過濾 `InputEventKey.echo`**(引擎 `event_is_action()` **不過濾**,已實測)。
**這兩條不擋建 epic,但會決定 story「寫完算不算 Done」** —— 列入表 A。

## 六、判定:要開工,生產面還缺什麼?

### 先講清楚:「開工」在這裡不是從零

```
$ find src/gameplay -name "*.gd" | xargs grep -c "" | sort -t: -k2 -rn | head -20
src/gameplay/battle/battle_controller.gd:1125
src/gameplay/affinity_pool/affinity_data_pool.gd:856
src/gameplay/battle/battle_state.gd:465
src/gameplay/cards/card_play_session.gd:405
src/gameplay/battle/battle_loop.gd:308
src/gameplay/cards/card.gd:270
src/gameplay/units/unit.gd:251
src/gameplay/cards/card_deck.gd:238
src/gameplay/affinity/affinity_rules.gd:224
src/gameplay/affinity/affinity_link.gd:213
src/gameplay/affinity_pool/affinity_calibration.gd:193
src/gameplay/battle/turn_order.gd:192
src/gameplay/cards/affinity_pool_write_port.gd:166
src/gameplay/board/board.gd:166
src/gameplay/affinity_pool/affinity_types.gd:149
src/gameplay/cards/permanent_affinity_write_rules.gd:147
src/gameplay/cards/affinity_write_port.gd:123
src/gameplay/board/line_of_sight.gd:95
src/gameplay/affinity/affinity_phi_provider.gd:94
src/gameplay/cards/card_text.gd:82

$ grep -rn "phi" src/gameplay/combat/combat_rules.gd | head -4
17:## [param phi], floored at 0 (damage never goes negative).
18:static func damage(atk: int, def: int, phi: int) -> int:
19:	return max(0, atk - def + phi)
```

🔴 **棋盤(`board.gd`)、視線(`line_of_sight.gd`)、回合序(`turn_order.gd`)、戰鬥迴圈
(`battle_loop.gd`)、傷害公式(含 `Φ`)全部已經在 `src/` 裡跑著。**
所以 #4 的「開工」實際形狀是 **把 2026-08-28 那批「先讓它動」的東西,換成經過設計與審查的版本**
—— 一年計畫已為這個形狀留下唯一一筆實測代價(3 天 vs 5 天,期間玩家看得到的新功能為零,見 2.3 節)。
**這會改變 epic 該怎麼切**:多數 story 是「替換 / 補齊 / 接線」,不是「新建」。

---

### 表 A —— 真的還在擋的

| # | 是什麼 | 誰擁有 | 最小動作 | 我跑的指令與原始輸出 |
|---|---|---|---|---|
| **A1** | **#4 沒有 epic,也沒有任何一張 story 檔** | `producer` | 建 `production/epics/tactical-combat/EPIC.md` + story 檔(`/create-epics`) | `$ ls production/epics/` → `affinity-data-pool / card-play-interface / cursor-highlight-state / index.md / screen-scaling / skill-card-system`(**五個目錄,無戰棋**);`$ grep -rl "戰棋\|tactical" production/epics/` 的 18 個命中**全部是別的 epic 提到它** |
| **A2** | **沒有 #4 的 UX spec,而系統索引把它寫成「寫 epic 之前」的前置** | `ux-designer` | 跑 `/ux-design` 產出 `design/ux/` 底下的戰棋畫面規格 | `$ ls design/ux/` → `accessibility-requirements.md / battle-menu.md / interaction-patterns.md / skill-card-play.md`(**四份,無戰棋畫面規格**)。索引 #4 列原文:`Pre-Production 須先跑 /ux-design 產出 UX spec,再寫 epic` |
| **A3** | **「把棋盤接進 #3」無人擁有** —— 一年計畫明文登記的三項代價之一,而它正是 #4 的範圍 | `producer`(決定它進不進 #4 epic) | 建 epic 時明文納入這條接線,並指定它會讓哪條測試轉紅 | 一年計畫第四之二②逐字:`沒有人把棋盤接進 #3,所以 #3 在遊戲裡不移動任何高亮` + 登記測試 `tests/integration/cursor/frame_buffer_ordering_test.gd > test_gap_no_surface_is_registered_anywhere_in_src_yet` |
| **A4** | **ADR-0001 隨核准生效的兩條硬性實作義務,尚未掛在任何工作單上** | `technical-director` | 建 epic 時寫成驗收條件:①游標圖層獨佔 `CanvasLayer` ②自行過濾 `InputEventKey.echo` | ⚠️ **本列事實由協調者交付、與開場載入的 `CLAUDE.md` 一致,本次未獨立重跑指令覆核** —— 誠實揭露 |
| **A5** | **一年計畫的「第 1 個月是哪一天」從未定義,階段表從未回填** | `producer` | 定義起算日;把第四節階段表補上「實際完成」欄 | `$ grep -n "起算" production/milestones/one-year-plan.md` → **只有第 210 行那條「待辦」本身提到它**;`$ sed -n '54,59p'` 顯示該表第 1 階段格**至今仍寫「建立 `project.godot`(目前不存在)」**,而 `git log --diff-filter=A` 實測它 **2026-08-26** 就進版控了 |
| **A6** | **停損點門檻數字未定案,且有一條「第 6 個月結束前、看到任何探針數據之前」的硬性期限** —— 因 A5,這條期限現在換算不出日期 | 管理者(`creative-director` 提供依據) | 先關 A5,再排定門檻定案的時點 | 一年計畫第五節逐字:`門檻數字必須在第 6 個月結束前定案,且必須在看到任何一筆探針關卡測試數據之前定死。` |
| **A7** | **若替 #4 建 epic,`PR-EPIC` 覆核關卡依現行精簡模式會被跳過** | 管理者 | 裁決 #4 要不要跑 `PR-EPIC` | `production/epics/index.md` 逐字:`/create-control-manifest 與 /create-epics 的覆核關卡皆未執行(TD-MANIFEST、PR-EPIC,因精簡模式跳過)`,理由是「**本批只做一個系統試水溫,錯了很便宜**」—— **#4 是被六個系統依賴的最大系統,那個理由不再成立** |

📌 **OQ 側(設計面未決項)不在本報告範圍** —— 見 `docs/reviews/tactical-combat-readiness-design-2026-09-29.md`(`systems-designer` 同日產出)。

---

### 表 B —— 寫著擋、但已經不擋的

🔴 **這張表和表 A 一樣重要。** 本專案今天已經抓到兩次「結論被抄走、理由後來變了、沒人發現」,
而 `OQ-2` 那次**錯了九天,中間還據此重複指派了一次**。

| # | 哪裡還寫著擋 | 為什麼其實不擋(我跑的指令與原始輸出) | 誰該去更正那句話 |
|---|---|---|---|
| **B1** | `design/gdd/systems-index.md` 的 **#4 列第 ② 把鎖**:`OQ-2 我方基準數值表無人擁有`,並據此寫 `仍不得移交 /create-architecture` | **OQ-2 已於 2026-09-09 在 GDD 自己的表裡關閉。** `$ grep -n "OQ-2" design/gdd/tactical-combat-system.md` 第 1044 行逐字:`~~OQ-2~~ ✅ 已關閉 2026-09-09 —— 擁有者自 2026-08-31 起為 design/quick-specs/unit-stats-provisional.md 第 1 節`;第 1087 行逐字:`~~OQ-2~~ ✅ 已解除(2026-09-09 更正)…本處原寫「表尚未產出 —— 仍然阻擋」是過期九天的錯誤記錄` | `systems-designer`(索引維護者) |
| **B2** | 同檔 **Progress Tracker「ADRs Accepted」列**:`#4 戰棋系統雖然 ADR-0001 已核准,仍受其自身 OQ-2(…✅ 2026-09-02 已指派 systems-designer,表尚未產出)阻擋` | **「表尚未產出」實測為假。** `$ ls -la design/quick-specs/` → `-rw-r--r-- … 35014 Sep  9 11:37 unit-stats-provisional.md`(**35 KB、9 月 9 日最後修改**);`$ head -20` 該檔第 7 行逐字:`## 🔴 本檔是 player_baseline_stat 的正式擁有者(2026-08-31 管理者指派)` | `systems-designer` |
| **B3** | `production/milestones/one-year-plan.md` **第七節與第八節風險表**:`ADR-0001(戰棋查詢)—— 缺的是引擎層,不是文件層…它自列六項待驗證未做`、`ADR-0001 只查過文件層,沒碰過引擎層｜戰棋在第 2 階段就要用它` | **ADR-0001 已於 2026-09-01 `Accepted`,引擎探針四支全過。** 計畫第七節那段**自己就標著「本檔兩處沒改到」** —— 它知道自己過期,但沒有人回來改。`$ grep -n "戰棋" production/milestones/one-year-plan.md` 命中 5 處,其中 384 / 388 / 400 三處講的都是這同一件已過期的事 | `producer`(計畫檔擁有者) |
| **B4** | `production/epics/index.md` 上方表格 **`card-play-interface` 列**:`22 個單元(…全部尚未建立 story 檔)｜📋 未開工` | **今天 18/18 收尾。** `$ ls production/epics/card-play-interface/` → `EPIC.md` + **18 張 `story-u001` ~ `story-u018`**。索引檔頭 `最後更新:2026-09-15` —— **停了 14 天。** 這一條會直接害人誤判「#4 的鄰接工作還沒開始」 | `producer` |
| **B5** | `design/gdd/systems-index.md` 的 `## Circular Dependencies` 節:`- 未發現循環依賴。` | **同一份文件裡至少兩處登記了反向依賴。** #5 列逐字:`⚠️ 雙向依賴(2026-08-17 補登):本系統同時是戰棋移動與交戰系統的上游`;#6 列逐字:`⚠️ 本輪新增反向依賴:戰棋系統(#4)須為本系統新增數值存取層,並在其設計文件補一節`。**這會影響 #4 與 #5 的排序判斷** | `systems-designer` |
| **B6** | **ADR-0004 仍是 `Proposed`** —— 看起來像「五份 ADR 有一份沒核准」的缺口 | **它是刻意的。** 一年計畫第七節逐字:`存檔系統(#2)… 不在最短路徑上,ADR-0004 維持 Proposed 即可,不要再投入`。**登記在表 B 的理由不是有人寫錯,是它長得像缺口** —— 下一個盤點 ADR 的人會想去關它 | 不需動作;**本列的用途是防止未來有人把它當缺口去補** |

---

### 這張單上最容易被漏掉的一件事

**A1 與 A2 的順序是反直覺的。** 索引明文寫 `先跑 /ux-design 產出 UX spec,再寫 epic`,
但 `src/ui/battle/` 底下 `BattleScreen.tscn` / `BoardView.tscn` / `board_view.gd`(635 行)**已經在跑**。

🔴 **所以 A2 不是「畫面不存在,要先設計」,而是「畫面已經存在,但沒有一份規格描述它」** ——
要不要為一個已經在跑的畫面補寫 UX spec、還是改成就地補規格,**是一次管理者裁決,本報告不代做。**

### 本報告沒有回答、也不該由本報告回答的

- **要不要開工、什麼時候開工** —— 判定留給協調者與管理者。本報告只寫「每一項的現況分別是什麼」。
- **設計面未決項(OQ 全表)** —— 見 `docs/reviews/tactical-combat-readiness-design-2026-09-29.md`。
- **工期估算** —— 需要讀 `design/gdd/tactical-combat-system.md`,該檔明文不在本次範圍內,本報告未讀。
