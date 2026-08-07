<!-- STATUS -->
Epic: 系統設計(/map-systems → /design-system → /design-review → /review-all-gdds)
Feature: 存檔系統 + 好感度數值池 + 游標高亮狀態 + game-concept 的跨文件一致性收斂
Task: `/review-all-gdds` 於 2026-08-06 首次執行,**Verdict: FAIL**(13 項去重後 BLOCKING:Consistency 8 + Design Theory 2 + Scenario 3,核心成因是「單份文件內部完備、跨文件宣稱從未被交叉驗證」)。同一 session 內 13 項已全數修訂完成——2 項經 creative-director 裁決(劇情事件寫入定性為系統寫入;敘事可達性硬性約束收窄範圍、排除刻意設計的互斥閘門),其餘 11 項直接修訂(依賴邊補齊、affinity 新增反序列化驗證規則宣告小節、分步遷移 Delta Log 寫入防線補上、退役名稱治理措辭統一、cursor 競態防呆靜默丟棄漏洞修正等)。詳見 `design/gdd/gdd-cross-review-2026-08-06.md` 第 183–207 行的修訂紀錄。同一 session 另建立 `design/ux/accessibility-requirements.md` 最小骨架,清償 cursor-highlight-state 第六輪起連續 6 輪孤兒化的無障礙轉交義務。**以上全部修訂(5 份 GDD + 1 份新 UX 文件)目前只在工作目錄,尚未 commit。** **下一步(報告建議路徑)**:(1) 針對受影響章節重跑對應 GDD 的 `/design-review`(不需全篇重審),確認本輪修訂沒有製造新接縫;(2) 重新執行 `/review-all-gdds` 確認 Verdict 轉為 PASS 或 CONCERNS;(3) 通過後 commit,方可移交 `/create-architecture`。
<!-- /STATUS -->

**`design/gdd/save-system.md` 第一、二、三輪 `/design-review` + 修訂完整記錄見 `design/gdd/reviews/save-system-review-log.md`。creative-director 第三輪收斂觀察**:發現數 24→9→11,非單調收斂,但發現性質已抵達「同輪新增規則間接縫未言明」的終末類別,建議第四輪只驗證三個性質、不開新領域(時序完整性、承諾可證成性、跨文件一致性含舊段落),通過即應 APPROVED、移交 `/create-architecture`。**下一輪(第四輪)待辦**:(1) 驗證本輪新增的 Core Rules #16 規則交互矩陣是否確實堵住了接縫類問題;(2) 驗證 Player Fantasy「殘餘成本」重新計價與新增的強制主動告知義務是否經得起再次檢視;(3) 序列化格式(Resource/.tres vs 自訂格式)仍是 Open Question,留給 `/create-architecture` 階段,本輪新增 fsync 電源中斷落盤保證查證、`OS.get_thread_caller_id()` API 名稱查證、`user://` 與同檔案系統前提三項架構階段必辦查證項;(4) `affinity-data-pool.md` 的序列化生命週期通知介面與 AC-47 仍為 provisional(本輪確認遷移執行模型改為分步執行不影響此二列的 provisional 狀態,見 `systems-index.md` Cross-System Obligations Registry)。

**`design/gdd/cursor-highlight-state.md` 第十輪 `/design-review` + spike + 修法完整記錄見 `design/gdd/reviews/cursor-highlight-state-review-log.md`。待辦**:(1) 正式覆核鎖死修法(AC-56/57)是否經得起對抗性審查——修法跳過了審查;(2) 補測 D-pad/鍵盤方向鍵的「新按下」判定與類比搖桿是否一致(spike 只測了類比搖桿);(3) 帳本 L15/L22/L23/L10 已達自動升級門檻,列為第十一輪優先阻擋項候選。

**`design/gdd/affinity-data-pool.md` 已於 2026-08-03 通過第七輪正式化 `/design-review`,狀態 Approved**(6 位專家並行審查 + creative-director 綜合裁決,8 項阻擋全數修訂完成)。creative-director 建議不需再跑第八輪全面審查。**2026-08-05 更新**:本文件的兩項對存檔系統的待清償義務(序列化生命週期通知介面、AC-47)因存檔系統首輪審查重新開放為 provisional——本文件本身未被回頭修改,見 `systems-index.md` Cross-System Obligations Registry。**第三輪存檔系統覆核後再次更新**:本文件已同步擴大索引鍵持久化範圍涵蓋 `source_i`(新增 AC-57)、修正 Open Question 5 殘留的矛盾舊敘述——皆為局部修訂,不構成對第七輪 Approved 判決的重開。

**系統拆解**:`/map-systems` 已完成,`design/gdd/systems-index.md` 已建立,14 個系統(12 個 MVP、2 個垂直切片)。

**概念原型歷史**(好感度—位置連鎖核心機制驗證,已於 2026-07-30 確認 PARTIALLY CONFIRMED / PROCEED,不再是進行中工作):v1-v5 全部原型與 spike 報告見 `prototypes/index.md`,細節見 `prototypes/affinity-position-concept-v5/REPORT.md`。角色規模裁決(固定 5 人主角群,不透過招募擴充)已同步修訂 `game-concept.md`。

## Session Extract — /review-all-gdds 2026-08-06
- Verdict: FAIL
- GDDs reviewed: 3(affinity-data-pool.md, save-system.md, cursor-highlight-state.md)+ game-concept.md + systems-index.md
- Flagged for revision: affinity-data-pool.md, save-system.md, cursor-highlight-state.md(Blocking), game-concept.md(Blocking), systems-index.md(Warning)
- Blocking issues: 13 去重後(Consistency 8 + Design Theory 2 + Scenario 3)——多為單份文件內部完備但跨文件宣稱未被交叉驗證所致(例:save-system 宣稱 affinity 已宣告驗證規則但查證不成立;分步遷移讓出視窗期間 Delta Log 寫入無任何防線;游標系統競態防呆靜默丟棄導致失效目標被判定為有效;劇情事件是否為玩家主動行為兩文件相反;敘事可達性硬性約束與 Track B 互斥可得性字面矛盾,需 creative-director 裁決)。多數為一到三句話的外科手術式修訂,不需推翻既有架構裁決。
- Report: design/gdd/gdd-cross-review-2026-08-06.md

**狀態更新(同日追加,同一 session 內)**:上述 13 項 BLOCKING 已全數修訂完成,記錄於報告本身第 183–207 行(2 項 creative-director 裁決 + 11 項直接修訂)。`design/ux/accessibility-requirements.md` 骨架同步建立。**尚未 commit,尚未重跑 `/design-review` 或 `/review-all-gdds` 驗證修訂本身無新接縫。** systems-index.md 三系統 Status 欄目前寫的 Needs Revision 標記也尚未隨這輪修訂更新——下一步驗證通過後應一併同步。
