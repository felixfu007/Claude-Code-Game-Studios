# Story 003:支援對話畫面

> **Epic**: `production/epics/support-conversation-ui/EPIC.md`
> **Status**: 等 001/002(2026-10-28 建立)
> **Type**: UI
> **規格權威**: `design/ux/support-conversation-screen.md` 第 2~9 節、AC-3~AC-14、AC-16~AC-18(**AC-1/AC-2 屬 story-004;AC-15 不適用,見 EPIC 處置**)

## 範圍

一個獨立場景(建議 `src/ui/shell/SupportConversationScreen.tscn` + `support_conversation_screen.gd`),
**只負責播放**:接收「要播哪幾段」(conversation_id 陣列,於 `instantiate()` 後、進樹前注入,比照 `SceneRouter.switch_to()` 的 `configure` 參數),
依 story-002 的 `SupportConversationScript` 取台詞,播完發出一個「全部播畢」訊號或呼叫可注入的完成回呼。
**不寫好感度、不改 CampaignProgress、不決定下一個畫面去哪** —— 那些屬 story-004。

## 必守

- 字型:story-001 入庫的霞鶩文楷 TC。字級:**暫行規則** `max(24, round(視窗高 ÷ 30))` 取偶數
  (`docs/reviews/dialogue-font-shortlist-2026-10-28.md` 的提案,**管理者尚未核准,待在家目視**)。
  寫成**一支** static 函式,不得在多處複製公式。🔴 不得套用 HUD 點陣字的 `11 × N` 規則(那是點陣字專用)。
- 輸入沿用既有 `battle_*` 動作(EPIC 處置 Q6),按住不得連推(自行過濾 `InputEventKey.echo`,ADR-0005 硬性義務)。
- 跳過整段:確認面板、預設焦點「取消」;確認後先顯示最後一句再結束(EPIC 處置 Q8)。
- 逐字顯示,速度固定;按確認立即顯示整句(EPIC 處置 Q4)。無自動前進。
- 說話者名牌為文字(在地化鍵),無立繪時版面成立。
- 游標義務:UX 規格第 9 節(OBL-011/013/018/021/022)逐條落實;卸載前照 `CursorStateHost` 交接介面(參考 cursor story-015 的戰鬥畫面做法)。
- 版面不得依賴側邊欄位;對話框貼下緣。

## Acceptance Criteria

UX 規格 AC-3~AC-14、AC-16(本 story 只驗「跳過與讀完走同一條完成路徑 —— 發出同一個完成訊號」)、AC-17、AC-18。
AC-9 只驗預設字級下最長一句不截斷(目前無字級設定)。
畫面相關(AC-10/11/18 的外觀)待管理者在家簽核;截圖屬 Category A 或 B,依 `coding-standards.md` 分類法。

## Affected Files

`src/ui/shell/SupportConversationScreen.tscn`、`src/ui/shell/support_conversation_screen.gd`(新)、`assets/data/locales/strings.csv`(按鈕/面板文字)、`tests/unit/core/i18n/locale_data_integrity_test.gd`(只改列數)、`tests/integration/ui/shell/...`(新)。
