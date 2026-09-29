# Epics 索引

**最後更新**:2026-09-29(管理者四項裁決同批落地:①**建立 #5 好感度—位置連鎖 epic**;②**#4 戰棋 epic 由 `Draft` 改 `Ready` 並首次入表**;③#5 不跑 `PR-EPIC` 閘門,照 2026-09-02 精簡模式預設;④下方「尚未建立 Epic」表**已清空**)
**前次更新**:2026-09-29(事實同步:`card-play-interface` 與 `affinity-data-pool` 兩列的 Stories / 狀態欄。依據 `docs/reviews/tactical-combat-readiness-production-2026-09-29.md` 表 B)—— 原文保留供追溯
**前次更新**:2026-09-29(事實同步:`card-play-interface` 與 `affinity-data-pool` 兩列的 Stories / 狀態欄。依據 `docs/reviews/tactical-combat-readiness-production-2026-09-29.md` 表 B)—— 原文保留供追溯
**前次更新**:2026-09-15(建立卡牌介面 epic —— 切片內 16 單元、切片外 6)—— 原文保留供追溯

> 🔴 **本檔檔頭曾停在 2026-09-15 整整 14 天,而期間兩個 epic 都動過,這是下方兩列同時寫錯的共同成因。**
> 兩列都寫著「全部尚未建立 story 檔 / 未開工」,而實際各有 18 張與 9 張 story 檔。
> **修正任一列時必須同時更新本行** —— 否則下一次還是同一種錯。
**引擎**:Godot 4.7.1
**控制清單版本**:2026-09-02

| Epic | 層 | 系統 | 權威文件 | Stories | 狀態 |
|---|---|---|---|---|---|
| [cursor-highlight-state](cursor-highlight-state/EPIC.md) | Core | 單一游標/高亮狀態系統 | `design/gdd/cursor-highlight-state.md` | **14 張**(完成 9) | 進行中 |
| [screen-scaling](screen-scaling/EPIC.md) | Presentation | 畫面縮放與定位(手動管理) | `design/art/screen-architecture.md`(**非 GDD**) | **2 張**(全部完成) | ✅ **Complete** |
| [skill-card-system](skill-card-system/EPIC.md) | Gameplay | 技能卡牌系統(僅好感度對話卡牌) | `design/gdd/skill-card-system.md` + `design/ux/skill-card-play.md` | **8 張**(邏輯層 5 + 接線 3,**全部完成**;介面層未建立) | 🟡 進行中(邏輯層完成;**介面層已由 [card-play-interface](card-play-interface/EPIC.md) 接手,不要再開第三份**) |
| [affinity-data-pool](affinity-data-pool/EPIC.md) | Core | 好感度數值池(Delta Log) | `design/gdd/affinity-data-pool.md` + ADR-0002(**Accepted**) | **9 張 story 檔**(原規劃 16 個單元:切片內 9 + 切片外 7。⚠️ **「16」是規劃單元數,不是 story 檔數** —— 切片外 7 單元至今未建 story 檔,**不是有 7 個檔案不見了**) | 🔴 **2026-09-29 事實更正,原文保留供追溯** —— 本列原寫「**16 張**(切片內 9 / 切片外 7,全部尚未建立 story 檔)｜📋 **未開工**(2026-09-15 建立 epic)」,**自 story 檔建立起即為假**;與上一列同一成因(檔頭停在 2026-09-15)。<br>**現況(只陳述事實,本次不判定本 epic 完成與否)**:9 張 story 檔存在;其中 **8 張 `Complete`**;第 9 張 `story-009-wiring.md` 狀態為「**不單獨執行 —— 已併入卡牌介面**」。**實測依據**:`ls production/epics/affinity-data-pool/story-*.md` 計 **9** 張;狀態列統計為 8 × `Complete` + 1 × `不單獨執行` |
| [card-play-interface](card-play-interface/EPIC.md) | Presentation | 卡牌介面 + 戰鬥選單 + 取消鍵重綁 | `design/ux/skill-card-play.md` + `design/ux/battle-menu.md`(**非 GDD**) | **18 張 story 檔**(原規劃 22 個單元:切片內 16 + 切片外 6;實作期另立 U-017、U-018,切片外 6 單元至今未建 story 檔) | ✅ **Complete(2026-09-29 收尾,18/18)**<br>🔴 **2026-09-29 事實更正,原文保留供追溯** —— 本列原寫「**22 個單元**(切片內 16 / 切片外 6,全部尚未建立 story 檔)｜📋 **未開工**(2026-09-15 建立 epic)」,**自 story 檔建立起即為假**;成因是本檔檔頭停在 2026-09-15 未更新。**實測依據**:`ls production/epics/card-play-interface/story-*.md` 計 **18** 張;18 條狀態列**全部** `✅ Complete`;收尾提交 `6c92014`(2026-09-29) |
| [tactical-combat](tactical-combat/EPIC.md) | Gameplay | 戰棋移動與交戰系統(含武器射程分層) | `design/gdd/tactical-combat-system.md` + `design/ux/tactical-combat-screen.md` + ADR-0001(**Accepted**) | 尚未建立(規劃為 M2~M6 五模組 + M1 限時查證批) | ✅ **Ready(2026-09-29 管理者核可)** —— 可執行 `/create-stories`。<br>🔴 **本列 2026-09-29 首次入表,而 epic 檔案自當日稍早即存在(598 行)** —— 不是漏更新:該檔原第 593 行明文規定「閘門通過之前……`production/epics/index.md` 不更新」。閘門(`docs/reviews/pr-epic-tactical-combat-2026-09-29.md`,判 CONCERNS)五項必辦全數關閉後才入表。<br>⚠️ **執行層必須序列化 `M6 → M5 → M4`**(三者共用 `src/ui/battle/battle_screen.gd`);規劃層 M4/M5 互不依賴但**不可並行執行** |
| [affinity-position-chain](affinity-position-chain/EPIC.md) | Gameplay | 好感度—位置連鎖系統(含陣亡處理) | `design/gdd/affinity-position-chain.md`(**Approved** 2026-08-31) | 尚未建立(規劃為 5 模組 + 1 治理前置) | 📝 **Draft(2026-09-29 建立)** —— 🔴 **2026-09-29 管理者裁決:不跑 `PR-EPIC` 閘門**,照 2026-09-02 精簡模式預設(不跑覆核但留紀錄)。**本列原寫「pending `PR-EPIC` gate」,該前提已由裁決移除。**<br>⚠️ **`Draft` 的理由改為「尚有 5 項待裁決」**(見該檔第 9 節),其中 3 項已於 2026-09-29 裁決(不 Blocked / 不跑閘門 / #4 那列不單獨動),**第 4 項「資料池讀取被拒時 `Φ` 回什麼」已派 `systems-designer` 查證中**,第 2 項(UX Flag 未滿足)未裁決 |

⚠️ **第三欄原名「GDD」,2026-09-04 改為「權威文件」** —— `screen-scaling` 是呈現層基礎設施,
不是遊戲系統,沒有 GDD 也不會有。硬塞一個 GDD 欄位會讓下一個人去找一份不存在的文件。

🔴 **`screen-scaling` 建立於 2026-09-04,起因值得記住**:它的內容是 **2026-09-01 的管理者裁決**,
被記載在 8 個檔案裡,**但沒有任何工作單擁有它,因此三天內沒有進入任何排程**。
發現方式是盤點下一步時察覺 `project.godot` 的實際值與 `.claude/docs/technical-preferences.md`
(**每次對話開場載入**)寫的值不一致。
📌 **通則:裁決被記錄 ≠ 裁決被排程。** 凡裁決帶有執行動作,當天就要有一張工作單擁有它,
否則它只會活在紀錄裡。

---

## 尚未建立 Epic 的已核准系統

以下系統的設計文件皆已 `Approved`,尚未建立 epic。

> ✅ **2026-09-15 更新:好感度數值池(#1)已建立 epic,已從本段移出至上方表格。**
> 建立理由是管理者裁決「要讓玩家在畫面上真的打得到卡牌」,而它是那條路上斷掉的一段 ——
> 打牌的寫入端目前接的是 `NullAffinityWritePort`(收下、丟掉的空殼)。

🔴 **本段原寫「各自另有阻擋」,2026-09-10 更正:三項裡只有一項是真的被擋。**
#4 那把鎖九天前就開了(見下表),#1 只是沒排到。**寫成「被擋」與寫成「沒排到」
會導向完全不同的下一步 —— 前者永遠不會自己結束。**

> ⚠️ **2026-09-15 補:上面那段話寫的是「三項」,而下表現在只剩兩項** —— 因為 #1 當天
> 建了 epic、移到上方表格去了。**留著上面那段不改,是因為它記的是 2026-09-10 那次更正
> 本身**,而那次更正的教訓(「被擋」與「沒排到」會導向完全不同的下一步)仍然成立。
> 📌 而 #1 的結局正好證實了它:#1 當時被寫成「擋著卡牌系統」,實際只是沒排到 ——
> 一旦排了,當天就開了 epic。

> 🔴 **2026-09-29:本表已清空 —— 所有已核准且在 12 個月範圍內的系統都已建立 epic。**
> 原表最後一列是 #4 戰棋(#5 已於同日稍早移出),隨 #4 的 epic 判 `Ready` 一併移入上方表格。
>
> **清空是實測結論,不是宣告。** 當場可重跑:
> ```
> awk -F'|' '/^\| *[0-9]+ *\|/ { n=$2; nm=$3; st=$6; gsub(/^ +| +$/,"",n); gsub(/\*|✅| /,"",st); \
>   if (st ~ /^Approved/) printf "#%s %s\n", n, nm }' design/gdd/systems-index.md
> ```
> 2026-09-29 實測輸出為 **#1 #2 #3 #4 #5** 五項(#6 技能卡牌狀態為 `Revised` 非 `Approved`,但它**已有 epic**)。
> 五項中 **#1 #3 #4 #5 皆已有 epic**;**唯一沒有的是 #2 存檔系統**,而它的處置寫在下一段 ——
> 依一年計畫第七節明確不在 12 個月範圍內。**亦即本表為空不代表有東西被遺漏,#2 是刻意的。**
>
> ⚠️ **本表不該被刪掉。** 未來 #7~#14 任一系統核准後、建 epic 前,它就會重新有內容。
> 🔴 **而它為空的時候最危險** —— 一張空表看起來像「沒事」,但它真正的意思是
> 「**現在所有的進度都壓在已建立的 epic 上,沒有任何東西在排隊**」。

> 🔴 **2026-09-29:#5 那一列已移出本表**(epic 已建立,見上方表格)。**移出時一併更正了它的「卡在什麼」欄** ——
> 原寫「**依賴 #4 的輸出**」,那是錯的。依據 `design/gdd/systems-index.md` 第 189–194 行逐字:
> #4 與 #5 是**窄介面的雙向關係**(#5 提供 `Φ`、#4 提供站位與陣亡事件),
> 「**不需要兩個系統同時完成**」,且「#4 與 #5 的先後**不能單看依賴箭頭決定**,因為箭頭是雙向的」。
> 📌 **這不是紙上更正**:#5 的 `Φ` 早已接進 `src/ui/battle/battle_screen.gd` 在垂直切片中運作
> (`grep -n "AffinityRules\.\|AffinityPhiProvider" src/ui/battle/battle_screen.gd` → **9 行命中,其中 6 個是呼叫點**、1 個變數宣告、2 個文件註解。⚠️ **本行原寫「→ 6 處」,與它自己貼的指令輸出對不上** —— 協調者複驗時發現並更正;本專案已登記「貼數字而非貼原始輸出」是重複失誤模式),
> 而 #4 的 story 一張都還沒有。**若 #5 真的依賴 #4 的輸出,今天的畫面不可能跑得出好感度預覽。**
>
> ⚠️ **本表現在只剩一列(#4)。** 而 #4 的 epic 檔案**其實已經存在**
> (`production/epics/tactical-combat/EPIC.md`,592 行),只是依該檔第 593 行自訂規則
> 「在閘門通過之前……`production/epics/index.md` 不更新」而尚未入表。
> 🔴 **本表標題是「尚未建立 Epic」,對 #4 而言字面上已不準確** —— 已登記為待裁決項
> (`production/epics/affinity-position-chain/EPIC.md` 第 9 節第 5 項),
> **本批刻意不自行更動 #4 那一列**,因為那會推翻 #4 epic 自己的規則。

**存檔系統**:ADR-0004(原子寫入與遷移)仍為 `Proposed`,且依一年計畫第七節**明確不在
12 個月範圍內**(「不在最短路徑上,維持 `Proposed` 即可,不要再投入」)。

---

## 本批的流程紀錄(不靜默略過)

- **`/create-control-manifest` 與 `/create-epics` 的覆核關卡皆未執行**
  (`TD-MANIFEST`、`PR-EPIC`,因精簡模式跳過)。管理者 2026-09-02 裁決:
  **先不跑覆核,但要留紀錄。** 理由是本批只做一個系統試水溫,錯了很便宜。
- **`docs/architecture/architecture.md` 不存在** —— `/create-architecture` 從未執行。
  ADR-0005 實質承擔模組定義的角色。**不阻擋,但登記在案。**
