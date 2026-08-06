<!-- STATUS -->
Epic: 系統設計(/map-systems → /design-system → /design-review)
Feature: 存檔系統(含跨規則集遷移)GDD
Task: `/design-review` 第四輪完整模式對抗性覆核完成(NEEDS REVISION,8 組阻擋,creative-director 查證確認全部源自第三輪 D-1~D-5 新增規則自身缺了「矩陣列/專屬 AC/範圍聲明」三件套之一,非新設計缺陷),同一 session 內完成修訂——路徑(二)維運拼接完整性重算義務補上(三方獨立收斂,本輪最高優先)、分步執行同槽重入不變量補上、D-4 滾動備份接縫修正(含步驟 4a 防永久卡死)、manifest-only 介面補上完整性檢查+AC、創世存底過度宣稱改為誠實措辭+條件式告知、Core Rules #10 補上過渡期殘餘風險聲明、Player Fantasy 舊句補上範圍聲明、Cross-System Obligations Registry 補登 8 列。**意外發現並解決專案級文件矛盾**:`technical-preferences.md`(PC+Console)與 `game-concept.md`(原僅 PC)矛盾,使用者裁決以前者為權威,已回頭修訂 `game-concept.md` 平台登記,連帶使 save-system.md Core Rules #4 的 provisional 解決時點提前至「`/create-architecture` 開始前必須」。詳見 `design/gdd/reviews/save-system-review-log.md`。狀態仍為 Designed(待審查),creative-director 建議第五輪只驗證兩件事(本輪修法有無製造新接縫、矩陣完備性檢查表本身是否完備),通過即 APPROVED 移交 `/create-architecture`。**下一步待使用者選擇**:(a) 現在跑第五輪 `/design-review` 覆核,或 (b) 先 commit + push 本輪修訂再決定,或 (c) 轉向其他工作(例如單一游標/高亮狀態系統的第十一輪覆核)。
<!-- /STATUS -->

**`design/gdd/save-system.md` 第一、二、三輪 `/design-review` + 修訂完整記錄見 `design/gdd/reviews/save-system-review-log.md`。creative-director 第三輪收斂觀察**:發現數 24→9→11,非單調收斂,但發現性質已抵達「同輪新增規則間接縫未言明」的終末類別,建議第四輪只驗證三個性質、不開新領域(時序完整性、承諾可證成性、跨文件一致性含舊段落),通過即應 APPROVED、移交 `/create-architecture`。**下一輪(第四輪)待辦**:(1) 驗證本輪新增的 Core Rules #16 規則交互矩陣是否確實堵住了接縫類問題;(2) 驗證 Player Fantasy「殘餘成本」重新計價與新增的強制主動告知義務是否經得起再次檢視;(3) 序列化格式(Resource/.tres vs 自訂格式)仍是 Open Question,留給 `/create-architecture` 階段,本輪新增 fsync 電源中斷落盤保證查證、`OS.get_thread_caller_id()` API 名稱查證、`user://` 與同檔案系統前提三項架構階段必辦查證項;(4) `affinity-data-pool.md` 的序列化生命週期通知介面與 AC-47 仍為 provisional(本輪確認遷移執行模型改為分步執行不影響此二列的 provisional 狀態,見 `systems-index.md` Cross-System Obligations Registry)。

**`design/gdd/cursor-highlight-state.md` 第十輪 `/design-review` + spike + 修法完整記錄見 `design/gdd/reviews/cursor-highlight-state-review-log.md`。待辦**:(1) 正式覆核鎖死修法(AC-56/57)是否經得起對抗性審查——修法跳過了審查;(2) 補測 D-pad/鍵盤方向鍵的「新按下」判定與類比搖桿是否一致(spike 只測了類比搖桿);(3) 帳本 L15/L22/L23/L10 已達自動升級門檻,列為第十一輪優先阻擋項候選。

**`design/gdd/affinity-data-pool.md` 已於 2026-08-03 通過第七輪正式化 `/design-review`,狀態 Approved**(6 位專家並行審查 + creative-director 綜合裁決,8 項阻擋全數修訂完成)。creative-director 建議不需再跑第八輪全面審查。**2026-08-05 更新**:本文件的兩項對存檔系統的待清償義務(序列化生命週期通知介面、AC-47)因存檔系統首輪審查重新開放為 provisional——本文件本身未被回頭修改,見 `systems-index.md` Cross-System Obligations Registry。**第三輪存檔系統覆核後再次更新**:本文件已同步擴大索引鍵持久化範圍涵蓋 `source_i`(新增 AC-57)、修正 Open Question 5 殘留的矛盾舊敘述——皆為局部修訂,不構成對第七輪 Approved 判決的重開。

**系統拆解**:`/map-systems` 已完成,`design/gdd/systems-index.md` 已建立,14 個系統(12 個 MVP、2 個垂直切片)。

**概念原型歷史**(好感度—位置連鎖核心機制驗證,已於 2026-07-30 確認 PARTIALLY CONFIRMED / PROCEED,不再是進行中工作):v1-v5 全部原型與 spike 報告見 `prototypes/index.md`,細節見 `prototypes/affinity-position-concept-v5/REPORT.md`。角色規模裁決(固定 5 人主角群,不透過招募擴充)已同步修訂 `game-concept.md`。
