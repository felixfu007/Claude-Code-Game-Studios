<!-- STATUS -->
Epic: 系統設計(/map-systems → /design-system → /design-review)
Feature: 存檔系統(含跨規則集遷移)GDD
Task: `/design-review` 第二輪完整模式對抗性覆核完成(NEEDS REVISION,9 組阻擋,去重合併自第一輪修訂本身的 fail-open 邊界),同一 session 內完成修訂——manifest 語意驗證/完整性標記改為 fail-closed、索引鍵退役名稱治理規則、遷移回寫原始位元組保留機制(使用者裁決 B-甲)、原子置換安全序列重寫、Player Fantasy 嚴重度排序修正(使用者裁決 A2)、新增第四類拒絕原因代碼、AC-8/14 重新指派用途。`affinity-data-pool.md` 同步新增索引鍵持久化說明+AC-56(解決遺留項 S1,與 AC-47 解綁)。詳見 `design/gdd/reviews/save-system-review-log.md`。狀態仍為 Designed(待審查),**使用者已選擇下一步:開新 session,`/clear` 後執行 `/design-review design/gdd/save-system.md` 進行第三輪覆核**。Foundation 層三個系統(好感度數值池 Approved、存檔系統待第三輪覆核、單一游標/高亮狀態系統待第十一輪覆核鎖死修法)設計皆已完成多輪,可視覆核結果決定是否開始 Core 層(戰棋移動與交戰、好感度—位置連鎖、技能卡牌)
<!-- /STATUS -->

**`design/gdd/save-system.md` 第一、二輪 `/design-review` + 修訂完整記錄見 `design/gdd/reviews/save-system-review-log.md`。下一輪(第三輪)待辦**:(1) 正式覆核第二輪修訂是否經得起對抗性審查(原始位元組保留機制、退役名稱治理規則、fail-closed 翻轉是否徹底);(2) 序列化格式(Resource/.tres vs 自訂格式)仍是 Open Question,留給 `/create-architecture` 階段,已鎖定 4 項硬性護欄 + 新增型別白名單版本分域為架構階段必辦項;(3) `affinity-data-pool.md` 的序列化生命週期通知介面與 AC-47 仍為 provisional(見 `systems-index.md` Cross-System Obligations Registry),第二輪**未觸及**此二項,待同步/非同步真正定案時一併處理——但該文件已就索引鍵持久化(原遺留項 S1)獨立完成同步。

**`design/gdd/cursor-highlight-state.md` 第十輪 `/design-review` + spike + 修法完整記錄見 `design/gdd/reviews/cursor-highlight-state-review-log.md`。待辦**:(1) 正式覆核鎖死修法(AC-56/57)是否經得起對抗性審查——修法跳過了審查;(2) 補測 D-pad/鍵盤方向鍵的「新按下」判定與類比搖桿是否一致(spike 只測了類比搖桿);(3) 帳本 L15/L22/L23/L10 已達自動升級門檻,列為第十一輪優先阻擋項候選。

**`design/gdd/affinity-data-pool.md` 已於 2026-08-03 通過第七輪正式化 `/design-review`,狀態 Approved**(6 位專家並行審查 + creative-director 綜合裁決,8 項阻擋全數修訂完成)。creative-director 建議不需再跑第八輪全面審查。**2026-08-05 更新**:本文件的兩項對存檔系統的待清償義務(序列化生命週期通知介面、AC-47)因存檔系統首輪審查重新開放為 provisional——本文件本身未被回頭修改,見 `systems-index.md` Cross-System Obligations Registry。

**系統拆解**:`/map-systems` 已完成,`design/gdd/systems-index.md` 已建立,14 個系統(12 個 MVP、2 個垂直切片)。

**概念原型歷史**(好感度—位置連鎖核心機制驗證,已於 2026-07-30 確認 PARTIALLY CONFIRMED / PROCEED,不再是進行中工作):v1-v5 全部原型與 spike 報告見 `prototypes/index.md`,細節見 `prototypes/affinity-position-concept-v5/REPORT.md`。角色規模裁決(固定 5 人主角群,不透過招募擴充)已同步修訂 `game-concept.md`。
