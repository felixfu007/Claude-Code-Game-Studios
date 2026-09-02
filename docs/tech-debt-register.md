# Tech Debt Register

專案的技術債登記表。**建立於 2026-09-02**,起因是 `/story-done` 結掉第一張工作單時,
有兩項 ADVISORY 級發現需要一個「不依賴任何人記得」的地方存放 ——
寫在已結案的工作單裡等於沒寫,沒人會再打開一張標著 Complete 的工作單。

**每一項的格式**:`- **[日期]**(來源工作單):描述 —— 追蹤來源 [檔案路徑]`

⚠️ **登記不等於排程。** 這裡的每一項都是「已知、已判定不阻擋、但沒有人被指派去做」。
要動它需要另開工作單。

---

## Open

- **2026-09-02**(Story 001 共用列舉、目標值型別與策略契約):
  **`assert()` 前置條件防呆在正式發行版建置會被引擎移除** —— `src/ui/cursor/cursor_types.gd`
  的 `encode_tile()` / `decode_tile()` 共 5 條、`src/ui/cursor/cursor_target.gd` 的 `equals()`
  1 條,全部是防「呼叫方傳錯值」的前置條件檢查。若引擎確實在發行版移除斷言,
  **玩家實際玩到的版本裡這些防呆不存在**。
  🔴 **此點未經實測驗證** —— 本機沒有匯出範本,無法建置發行版來測。屬**待查證**,不是既定事實。
  與 ADR-0005 已登記的「export release 建置下 VM 是否中止所在函式」是同一類本機測不了的問題,
  建議取得匯出範本後兩項一起驗。
  追蹤來源:`production/epics/cursor-highlight-state/story-001-shared-types.md`

- **2026-09-02**(Story 001 共用列舉、目標值型別與策略契約):
  **AC-53 只做到部分涵蓋,補齊要等 Story 003** —— 該條文要求檢視「所有**已掛載** UI 表面」
  的標籤是否都來自同一份共用列舉。Story 001 驗到的是「共用列舉本身正確」;
  **「下游有沒有人另開一份自己的標籤」尚未驗證**,因為表面註冊表(Story 003)還沒實作,
  系統裡沒有已掛載表面可查。
  ⚠️ **Story 003 完成時必須回頭補驗這一半**,否則 AC-53 會以「Story 001 已結案」的外觀
  永遠停在半驗證狀態。
  追蹤來源:`production/epics/cursor-highlight-state/story-001-shared-types.md`、
  `production/epics/cursor-highlight-state/story-003-surface-registry.md`


- **2026-09-02**(Story 002 Autoload 薄殼 + 依賴注入核心 + 三欄位狀態):
  **AC-2 與 AC-15 在本階段只能用假造替身驗證,真實驗證要等 Story 007 / 010** ——
  AC-2 要求「跨**全部已掛載表面**加總恰有一個高亮」,AC-15 要求「**對應的高亮視覺已顯示**
  於該目標」。Story 002 只建狀態容器與宿主,**此時系統裡既沒有任何已掛載表面,也還沒有
  任何會畫出高亮的東西** —— 兩條都只能對測試替身斷言,證明的是「狀態容器這一側的行為正確」,
  不是「畫面上真的恰有一個高亮」。
  ⚠️ **補驗時機**:表面註冊表接上真實表面後(Story 007 寫入/讀取介面)可驗 AC-2 的實體部分;
  高亮視覺由 Story 010 產出,AC-15 的「視覺已顯示」要到那時才驗得到。
  🔴 **這與 AC-53 是同一個形狀的問題**(見上一項)—— 由下往上蓋必然產生,
  但**結案後沒人會再打開標著 Complete 的工作單**,故在開工前先登記於此。
  追蹤來源:`production/epics/cursor-highlight-state/story-002-state-host.md`、
  `production/epics/cursor-highlight-state/story-007-write-read-interface.md`、
  `production/epics/cursor-highlight-state/story-010-idle-indicator-host.md`

- **2026-09-02**(Story 003 表面註冊表):
  **AC-51 的「每個下游表面」目前是空集合** —— 該條文要求「確認**每個**下游表面的卸載邏輯
  皆包含目標交接呼叫」。Story 003 實作的是註冊表**這一側**的交接介面;
  **消費端(真正會卸載的 UI 表面)一個都還不存在**,所以「每個」現在恆真而無意義。
  ⚠️ **補驗時機**:每當有新的 UI 表面接入本系統時,都必須檢查它的卸載路徑有呼叫交接介面。
  **這不是一次性補驗,是一條持續義務** —— 與上面兩項(一次性補驗)性質不同。
  最早的實質檢查點是 Story 011 / 012(白名單消費端、focus/hover 停用)。
  追蹤來源:`production/epics/cursor-highlight-state/story-003-surface-registry.md`

## Resolved

*(尚無)*
