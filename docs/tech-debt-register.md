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

## Resolved

*(尚無)*
