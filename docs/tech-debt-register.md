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


- **2026-09-02**(Story 002,**覆核補登** —— 首次登記時漏掉,由測試涵蓋覆核判 BLOCKING 抓出):
  **AC-16 的窄化程度比 AC-2 / AC-15 更極端,而它原本一條登記都沒有** ——
  AC-16 要求「任一裝置產生第一個 `ui_*` action 時,系統立即離開未初始化狀態、依裝置類別
  進入對應權威狀態」。實際測到的只是「`_device_authority` 這個欄位可以被改成別的值」,
  **沒有任何裝置輸入、沒有經過裁決邏輯** —— 裁決邏輯(`arbitrate_device_authority()`)
  屬 Story 007,此時不存在。測試自己的註解坦承這「接近套套邏輯」。
  ⚠️ **窄化本身是誠實且必要的,問題是它沒被登記。** 補驗時機:Story 007。
  追蹤來源:`production/epics/cursor-highlight-state/story-002-state-host.md`、
  `production/epics/cursor-highlight-state/story-007-write-read-interface.md`

- **2026-09-02**(Story 003,**覆核補登** —— 同上,首次登記時漏掉):
  **AC-4 的行為那一半完全不在註冊表這層** —— AC-4 要求「對一表面產生有效輸入時,
  另一表面原本顯示的高亮**立即消失**」,證明兩表面共享同一狀態源。
  實際測到的是「兩個表面類型可同時註冊、互相獨立存取、互不影響」——
  那是共用狀態源得以成立的**必要基礎**,不是 AC-4 斷言的行為。
  **高亮消失是 `CursorState` 的行為**,補驗時機 Story 007。
  追蹤來源:`production/epics/cursor-highlight-state/story-003-surface-registry.md`、
  `production/epics/cursor-highlight-state/story-007-write-read-interface.md`


- **2026-09-02**(Story 001 AC-53 補驗結論,**管理者當日裁決:誠實登記為擋不住**):
  🔴 **「所有已掛載表面的標籤都來自同一份共用列舉」這件事,程式碼結構上擋不住,只能靠紀律。**
  這是 Story 001 遺留的 AC-53 後半段,原註明「Story 003 完成時必須回頭補驗」——
  **今天補驗了,答案是否定的。** 依據(測試涵蓋覆核 2026-09-02):
  1. `_surfaces` 宣告為 `Dictionary[CursorTypes.SurfaceType, Node]`、`register()` 參數亦標註該型別,
     **但那只是靜態型別提示,不是執行期防線**。
  2. 本專案引擎參考庫 `modules/scripting-typing.md` 第 3 節(✅ 已驗證)明載:型別化容器的
     enum 鍵在內省 API 上會被抹成底層內建型別;**enum 標註對越界 int 完全不設防** ——
     GDScript 的 enum 本質就是一組 int 常數,沒有獨立的執行期型別標籤。
  3. 因此:**任何人拿另一份「恰好數字相同」的自製標籤清單呼叫 `register()`,會成功,
     而且不會有任何錯誤訊息。**
  ⚠️ **為什麼不加執行期成員檢查就解決**:加了也只擋得掉越界數字,**擋不掉「另一份數字恰好相同的清單」**
  —— 那正是 AC-53 真正要防的東西。部分有效不等於結構性保證,不應以「已補驗」的外觀結案。
  📌 **裁決結果**:登記為「**依賴呼叫端紀律,無結構性保證**」,不標記為已補驗完成。
  **後續義務**:每當有新的 UI 表面接入本系統,必須人工確認它的標籤取自 `CursorTypes.SurfaceType`
  而非自製來源。最早的實質檢查點是 Story 007(寫入/讀取介面接上真實表面時)。
  追蹤來源:`production/epics/cursor-highlight-state/story-001-shared-types.md`、
  `production/epics/cursor-highlight-state/story-003-surface-registry.md`、
  `production/epics/cursor-highlight-state/story-007-write-read-interface.md`

## Resolved

*(尚無)*
