<!-- STATUS -->
Epic: 系統設計(/map-systems → /design-system → /design-review)
Feature: 存檔系統(含跨規則集遷移)GDD
Task: `/design-review` 第三輪完整模式對抗性覆核完成(NEEDS REVISION,11 組阻擋,去重合併自第二輪修訂本身「規則間接縫未言明」的問題),同一 session 內完成修訂——Core Rules #13/#14 寫入時序明文化(兩階段回寫、步驟零預清除)、存底保留策略改為創世保留(使用者裁決 D-1)、遷移執行模型改為分步執行(使用者裁決 D-2)、自動痊癒路徑(二)加註完成標記與拼接前提(使用者裁決 D-3)、一般位元腐蝕新增滾動備份(使用者裁決 D-4)、Player Fantasy 取捨殘餘成本誠實重新計價(使用者裁決 D-5)、Core Rules #10 範圍擴大至 `source_i` 並將退役名稱治理升級為硬性規則、manifest 新增頂層區塊清單完整性標記、新增 Core Rules #16 規則交互矩陣。`affinity-data-pool.md` 同步擴大索引鍵持久化範圍涵蓋 `source_i`(新增 AC-57)、修正 Open Question 5 殘留的矛盾舊敘述。詳見 `design/gdd/reviews/save-system-review-log.md`。狀態仍為 Designed(待審查),**使用者已選擇下一步:現在修訂完成後上傳到 Git**——修訂已完成,git commit + push 為本次 session 最後一步。
<!-- /STATUS -->

**`design/gdd/save-system.md` 第一、二、三輪 `/design-review` + 修訂完整記錄見 `design/gdd/reviews/save-system-review-log.md`。creative-director 第三輪收斂觀察**:發現數 24→9→11,非單調收斂,但發現性質已抵達「同輪新增規則間接縫未言明」的終末類別,建議第四輪只驗證三個性質、不開新領域(時序完整性、承諾可證成性、跨文件一致性含舊段落),通過即應 APPROVED、移交 `/create-architecture`。**下一輪(第四輪)待辦**:(1) 驗證本輪新增的 Core Rules #16 規則交互矩陣是否確實堵住了接縫類問題;(2) 驗證 Player Fantasy「殘餘成本」重新計價與新增的強制主動告知義務是否經得起再次檢視;(3) 序列化格式(Resource/.tres vs 自訂格式)仍是 Open Question,留給 `/create-architecture` 階段,本輪新增 fsync 電源中斷落盤保證查證、`OS.get_thread_caller_id()` API 名稱查證、`user://` 與同檔案系統前提三項架構階段必辦查證項;(4) `affinity-data-pool.md` 的序列化生命週期通知介面與 AC-47 仍為 provisional(本輪確認遷移執行模型改為分步執行不影響此二列的 provisional 狀態,見 `systems-index.md` Cross-System Obligations Registry)。

**`design/gdd/cursor-highlight-state.md` 第十輪 `/design-review` + spike + 修法完整記錄見 `design/gdd/reviews/cursor-highlight-state-review-log.md`。待辦**:(1) 正式覆核鎖死修法(AC-56/57)是否經得起對抗性審查——修法跳過了審查;(2) 補測 D-pad/鍵盤方向鍵的「新按下」判定與類比搖桿是否一致(spike 只測了類比搖桿);(3) 帳本 L15/L22/L23/L10 已達自動升級門檻,列為第十一輪優先阻擋項候選。

**`design/gdd/affinity-data-pool.md` 已於 2026-08-03 通過第七輪正式化 `/design-review`,狀態 Approved**(6 位專家並行審查 + creative-director 綜合裁決,8 項阻擋全數修訂完成)。creative-director 建議不需再跑第八輪全面審查。**2026-08-05 更新**:本文件的兩項對存檔系統的待清償義務(序列化生命週期通知介面、AC-47)因存檔系統首輪審查重新開放為 provisional——本文件本身未被回頭修改,見 `systems-index.md` Cross-System Obligations Registry。**第三輪存檔系統覆核後再次更新**:本文件已同步擴大索引鍵持久化範圍涵蓋 `source_i`(新增 AC-57)、修正 Open Question 5 殘留的矛盾舊敘述——皆為局部修訂,不構成對第七輪 Approved 判決的重開。

**系統拆解**:`/map-systems` 已完成,`design/gdd/systems-index.md` 已建立,14 個系統(12 個 MVP、2 個垂直切片)。

**概念原型歷史**(好感度—位置連鎖核心機制驗證,已於 2026-07-30 確認 PARTIALLY CONFIRMED / PROCEED,不再是進行中工作):v1-v5 全部原型與 spike 報告見 `prototypes/index.md`,細節見 `prototypes/affinity-position-concept-v5/REPORT.md`。角色規模裁決(固定 5 人主角群,不透過招募擴充)已同步修訂 `game-concept.md`。
