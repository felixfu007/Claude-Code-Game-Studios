# 系統索引與 MVP 骨架加註草稿(2026-11-05)

> **起草**:`producer`(只起草,未改任何既有檔)。**套用**:協調者以錨點腳本套用(與 `docs/reviews/plan-and-status-annotations-draft-2026-11-05.md` 同一支)。
> **依據**:管理者 2026-11-05 裁決(逐字):「**加註更新(推薦)**」—— 對象:`design/gdd/systems-index.md` 第 6 列、第 10 列的過時狀態,以及 `design/quick-specs/mvp-five-levels-skeleton.md` 開放問題 #2。
>
> **操作型別只有兩種**:
> - **【行後插入】**:在「含錨點的那一行」之後插入整段文字。
> - **【行內附加】**:在錨點字串**緊接其後**插入一段文字,錨點本身一字不改。
>
> **每個錨點的命中數皆於 2026-11-05 實測為 1**(`grep -c -F -- '<錨點>' <檔>`)。
> 🔴 **插入文字刻意不含任何錨點字串**,套用後重跑同一條 `grep -c` 仍應為 1。套用前請再跑一次。
> **舊文一字不改**;下列數字皆為 2026-11-05 快照,會漂 —— 要現值就重跑附上的指令。

---

## A. `design/gdd/systems-index.md`

### A-1 【行內附加】第 6 列(技能卡牌系統)狀態格的最後一句之後

第 6 列狀態格仍停在設計審查期(「Revised」「只剩一輪審查額度」「OQ-13 新鎖擋介面」),未記載之後的實作。附加文字以 `<br>` 開頭,落在同一格內;錨點之後原有的 ` | design/gdd/skill-card-system.md | …` 不動。

- 錨點:`**看到這種措辭先 grep 產出物是否已存在。**`
- 驗證:`grep -c -F -- '**看到這種措辭先 grep 產出物是否已存在。**' design/gdd/systems-index.md` → `1`
- 附加於錨點**緊接其後**(逐字):

```
<br>✅ **2026-11-05 加註(本格上方原文未改):邏輯層與介面層皆已實作完畢,上方設計審查期的描述已過時。** ①邏輯層 `production/epics/skill-card-system/` story-001~008 皆 ✅ Complete(2026-09-10 實作完成),story-009(點名卡限定)✅ Done(2026-11-03,提交 `90bb933`);②介面層由 `production/epics/card-play-interface/` 承接,19 張 story 檔全部 ✅(18/18 收尾提交 `6c92014`,2026-09-29;U-019 於 2026-10-13 Done)—— 上方 OQ-13 擋的「結束回合的新家」即 U-009(結束回合選單列)與 U-016(`battle_end_phase` 解綁),兩張皆在其中。查證:`grep -l -E '^> \*\*[^*]*\*\*[:：] *✅' production/epics/skill-card-system/story-*.md` 與同一條換成 `card-play-interface`,數列出的檔名(2026-11-05 實測 9 與 19,即兩目錄全部 story 檔)
```

### A-2 【行內附加】第 10 列(戰鬥 HUD)狀態格的最後一句之後

第 10 列寫「story-002(畫面與輸入)Ready」,實際 story-002~004 皆已交付、待管理者畫面簽核。

- 錨點:`**本次只更正事實欄位,未改動範圍(範圍收窄仍為 2026-08-25 那次裁決)**`
- 驗證:`grep -c -F -- '**本次只更正事實欄位,未改動範圍(範圍收窄仍為 2026-08-25 那次裁決)**' design/gdd/systems-index.md` → `1`
- 附加於錨點**緊接其後**(逐字):

```
<br>✅ **2026-11-05 加註(本格上方原文未改):上方「story-002 Ready」已過時 —— 預判標記已實作,待管理者畫面簽核。** `production/epics/battle-hud/` 四張:story-001 ✅ Done(2026-10-16);story-002(猜測選擇器)與 story-003(一致率計數器)✅ Done-pending-visual(2026-10-28,提交 `025c36d`);story-004(介面蓋到棋盤)✅ Done-pending-visual(2026-11-03,`git log --oneline -1 -- production/epics/battle-hud/story-004-hud-board-overlap.md` → `539bc36`)。查證:`grep -m1 Status production/epics/battle-hud/story-00*.md`。🔴 **「pending-visual」= 畫面尚未經管理者簽核,本加註不代為宣告完成。**<br>📌 **協議 1(本系統服務的驗收協議)今日有一筆電腦替代量測**:提交 `f508090`,`prototypes/protocol1-computer-baseline-2026-11-05/README.md`(鎖定計畫提交 `6dc9a82`)。🔴 **只量了每關的開場局面**(逐階段站位未做),且依該 README 自述「**不是**協議 1 的證據,也不使協議 1 達成」、只有診斷結論、無通過/未通過;另揭露 tut04 的電腦基準 P0=92.45 ≥ 80,80% 門檻在該關無鑑別力。協議 1 真人半未做
```

---

## B. `design/quick-specs/mvp-five-levels-skeleton.md`

### B-1 【行後插入】第四部分開放問題 #2(探針關卡方法論落差)第二行之後

#2 問的是:Level 1「逐位置比較」的 AC 是否滿足 `game-concept.md` 要求的「忽視好感度 vs 運用好感度」**整體**比較。協議 2 電腦對照實際就是以該整體比較方法、在探針關 vs01 上跑完並結案,故此題的事實面已被回答。插入文字比照同節第 4 項 2026-10-28 加註的縮排(3 個空格,維持在清單項內)。

- 錨點:`「忽視好感度 vs 運用好感度」整體比較方法論——交 qa-lead/game-designer 確認。`
- 驗證:`grep -c -F -- '「忽視好感度 vs 運用好感度」整體比較方法論——交 qa-lead/game-designer 確認。' design/quick-specs/mvp-five-levels-skeleton.md` → `1`
- 插入文字(逐字):

```
   ✅ **2026-11-05 加註(上方原文未改):本題已由協議 2 電腦對照實際回答 —— 整體比較的對照跑法已在探針關 vs01 上做了,並已結案。**
   協議 2 用的正是「忽視好感度臂 vs 運用好感度臂」整體比較(兩臂同一張探針關、各 8 組變體),不是逐位置比較:
   attempt-5(`production/qa/protocol2/computer-attempt-5-20261102T0809Z/`,檔頭「探針關 vs01」;結果提交 `d3e266b`、判定提交 `818c9e0`)判**通過(壓線)**——忽視臂 6/8、運用臂 8/8,通關數差 +2 恰等於門檻。
   五次結論(未通過/壓線通過/壓線通過/未通過/壓線通過)與管理者 2026-11-05 結案裁決全文,見 `production/milestones/one-year-plan.md` 第五節的 2026-11-05 加註(`grep -n "協議 2 正式結案" production/milestones/one-year-plan.md`)。
   🔴 **限制,回答本題時一併繼承**:兩臂都是工程師寫的電腦打法,證明「程式會用好感度」不等於「玩家會用」;8 組非獨立樣本;兩項門檻剛好壓線。
   ⚠️ **未發生的事,照實寫**:本題原指定「交 qa-lead/game-designer 確認」—— 本加註只記錄「對照跑法已實際執行並結案」這個事實,**查無 qa-lead/game-designer 對「逐位置 AC 是否足夠」的書面確認**;Level 1 的逐位置 AC(`vertical-slice-level-01.md` AC#2/#3)本身未因此改動。
```

---

## C. 給協調者(非管理者裁決)

- 本次動到的既有檔共 **2 份**:`design/gdd/systems-index.md`(A-1、A-2)、`design/quick-specs/mvp-five-levels-skeleton.md`(B-1)。三個錨點互不重疊,套用順序無依賴。
- A-1、A-2 是表格列內附加:附加文字不含換行、不含 `|` 字元(A-1 的查證指令因此刻意不用 `(a|b)` 交替式與管線),以 `<br>` 分段(比照同檔第 6、10 列既有寫法)。
- **刻意未起草(範圍外,待您決定要不要追加)**:同一份骨架檔第一部分「探針關卡:第 1 場」那段的「⚠️ **未驗證的方法論落差**……(第四部分#2)」與 #2 是同一件事,套用 B-1 後該段仍寫「未驗證」。若要一起處理,建議用同樣格式在該段末加一行指向第四部分 #2 的加註。
- 第 10 列「Design Doc」欄仍為 `—`(規格 `design/quick-specs/battle-hud-prediction-marker.md` 只寫在狀態格裡),本草稿**不改**,屬格式統一而非狀態同步。
- 套用後請對三個錨點重跑 `grep -c -F`,應全部仍為 `1`。
