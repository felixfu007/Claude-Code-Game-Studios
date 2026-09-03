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


- **2026-09-03**(Story 004 裝置分類 + 動作語意分類):
  🔴 **本引擎有 91 個 `ui_*` action,三份分類清單只涵蓋 14 個,77 個未分類** ——
  ADR-0005 機制七 (c) 的載入期完整性驗證器(**Story 006 的產出**)若照現行設計原樣實作,
  **每次啟動會噴出 77 行 `UI_ACTION_UNCLASSIFIED`**。
  ⚠️ **這正是 ADR 的 R4-5 段落選擇三分割方案時明文說要避免的結果**
  (原文:「會在啟動時把數十個引擎內建 `ui_* action` 全部報成待分類,噪音大到會被實作者
  直接關掉,反而製造比靜默更糟的結果」)。**探針把那句擔憂變成了具體數字。**
  那 77 項經引擎覆核者獨立複核,**全屬編輯器控制項語意**(`ui_text_*` / `ui_graph_*` /
  `ui_filedialog_*` / `ui_colorpicker_*`),**沒有任何一項該被移入 `NAVIGATION_ACTIONS`** ——
  亦即這是**噪音量**的問題,不是分類錯誤的問題。
  🔴 **要防的風險是真的**:將來新增一個語意上屬導覽的 `ui_*` action 卻忘了登記,
  會被靜默歸為非導覽、失去主張裝置權威的資格,而沒有任何檢查會攔下。
  📌 **需管理者裁決,已於 2026-09-03 呈報。此處不記錄任何裁決結論** ——
  在本行被更新為指向實際紀錄位置之前,**不存在關於本項的裁決,不要引用一個**。
  證據:`prototypes/story-004-ui-action-probe-2026-09-03/logs/probe_output.txt`(91/14/77 全清單)
  追蹤來源:`production/epics/cursor-highlight-state/story-006-startup-validation.md`

- **2026-09-03**(Story 004 覆核發現,引擎覆核者):
  **`battle_screen.gd` 那份「機制四行內複本」其實不是同一段邏輯的複製,兩份的 echo 語意
  可能本來就不等價** —— 先前(2026-09-02)登記的收斂項只涵蓋 `DeviceAuthority` 的
  **列舉兩值 vs 三值**,**沒有記錄這一件事**。實測差異:
  `src/ui/battle/battle_screen.gd:659-667` 的方向鍵用 `Input.is_action_pressed()`
  **逐幀輪詢 + 手動 edge-detection**;`src/ui/cursor/cursor_types.gd` 用
  `InputMap.event_is_action()` **逐事件分類**。確認鍵(L.383/387)走的又是第三個 API:
  `InputEvent.is_action_pressed()`。
  🔴 **三個不同的引擎 API,對 echo 的預設處理是否一致「本次未實機查證,屬推測」**
  (覆核者原話)。**今天兩者表現一致很可能只是巧合** —— `battle_confirm` 從未被
  壓住不放測試過。
  ⚠️ **Story 005 收斂兩份時必須實機驗證 `InputEvent.is_action_pressed()` 的 echo 預設行為,
  不得假設等價。** 這正是本專案 R2 記載過的失效模式(兩份實作「只是今天答案一致」)。
  追蹤來源:`production/epics/cursor-highlight-state/story-005-frame-buffer-ordering.md`、
  `docs/reviews/story-004-engine-review-2026-09-03.md`

- **2026-09-03**(Story 004 覆核發現,引擎覆核者):
  **ADR-0005 的 `Key Interfaces` 契約段從未列出 `classify()`** —— 只列了
  `classify_action()`(L.1349)。這是 ADR 自己在 2026-08-19 修訂新增 `classify_action()`
  時的登記遺漏,**不是 Story 004 的缺陷**(該 story 已依既有先例把兩者放在 `cursor_types.gd`,
  覆核判 PASS)。
  ⚠️ **後果**:契約段是本專案明訂「衝突時以此為準」的權威位置。一個實際存在、
  且被機制四明文定案的靜態方法不在契約段裡,**下一個比對契約段的人會找不到它**。
  追蹤來源:`docs/architecture/adr-0005-cursor-device-authority-input-architecture.md`

- **2026-09-03**(Story 004 覆核發現,引擎覆核者,低嚴重度):
  **echo 的確認類事件被折疊進 `OTHER`,與「真正未分類」變得不可區分** ——
  `classify_action()` 的 echo 過濾在所有查詢之前,對 NAVIGATION 與 CONFIRM 一律生效。
  覆核者追蹤 ADR-0005 全部下游消費點後確認 **CONFIRM 與 OTHER 目前完全同構**,
  折疊沒有可觀察的行為差異,**故判 PASS,非缺陷**。
  ⚠️ 但這是**設計選擇的已知代價**:若 Story 005/006 未來需要區分這兩者,
  現在的輸出形狀已經丟失該資訊。**知悉即可,現在不必動。**
  追蹤來源:`docs/reviews/story-004-engine-review-2026-09-03.md`

- **2026-09-03**(Story 007,✅ **2026-09-03 同日全部關閉** —— ADR-0005 第五次修訂,見 `docs/architecture/adr-revision-history.md`):
  原登記為「四處自我矛盾,全部是『同一事實兩份副本只更新一份』,呈管理者裁決」。**處置**:
  ① **Validation Criteria #16(iv)**(最急,會讓人主動破壞正確實作)→ 改為斷言順序與不變式四條,不斷言次數;
  ② **L.934 vs R6-10 的診斷計數**(測試端與引擎端各自獨立撞到)→ **管理者裁決:仍然遞增**,語意界定為
  「偵測到一次不該發生的重入呼叫」;實作原本就如此,文件補正,測試側同批解鎖一條原本留白的斷言;
  ③ **VC #13(iv) 六 vs 七** → 實測七個全部呼叫;🔴 **該句在 ADR 內有兩份複本,兩份同批更正**
  (第二份是還原重做時才發現的 —— 若第一次就改對,只會改到一半);
  ④ **登記表 `public_cursor_write_entry_calling_another` 描述只列 5 個入口** → 補為七個並註明舊描述年代。
  ① **Validation Criteria #16(iv) 已過期(最急)** —— 斷言 `_reclaim` 在一次外層寫入內只 reset 一次,
  而 R6-10 之後實際是兩次不同觸發點。**其餘三項讓人漏檢,只有這項會讓照規矩辦事的人主動去破壞一個正確的實作。**
  引擎覆核已寫出替代斷言(改斷順序與不變式,不斷次數 —— 次數隨外層入口而異:2/2/2/1/0)。
  ② **L.934 vs R6-10**:重入 reseed 算不算遞增診斷計數,兩段講不一樣(**測試端與引擎端各自獨立撞到**)。
  ③ **VC #13(iv) 說六 / Key Interfaces 說七。** ④ **登記表 L.1930-1933 只列 5 個公開入口,實際 7 個。**
  ⚠️ ADR-0005 **已 `Accepted`**,修訂須走既有流程。—— 追蹤來源 `docs/reviews/story-007-engine-review-2026-09-03.md` 總結表
- **2026-09-03**(Story 007,✅ **已裁決,轉為帶期限的延後項**):ADR L.1041 明文承諾
  「`set_target()` 於 `from_ui_action == true` 時連動裝置權威轉移」,**但沒說轉移到哪個裝置,簽章也不帶裝置資訊**。
  現況:**無實作、無測試會失敗**,實作端留明確 no-op 分支並在公開 doc comment 標明為未定案。
  方向與 AC-39 一致但 **AC-39 未回答此問題**,不得讀成已結案。—— 追蹤 同上報告第 10(c) 項
- **2026-09-03**(Story 007,引擎覆核 S-1,判定可延後但後果嚴重):**重入閘門的兩條 abort 路徑在閘門內**
  (`assert` 與 `_registry.get_surface()`)。一次中止 = `_mutation_in_progress` 永久卡住 = **游標系統無聲死亡**。
  ⚠️ `assert` **在 release 建置可能被整條剝離** → 開發時大聲報錯、玩家手上無聲卡死;
  **本機無匯出範本,此點結構上查證不了**(ADR L.123-127 已登記為層 B)。
  修法二選一或並用:①把 `_validate_target_writable()` 前移到升旗之前;②比照 **ADR-0001 L.141** 已成文的
  `settlement_in_progress` 卡死偵測(同一形狀、同一後果,ADR-0005 未繼承)。
  ⚠️ Story 014 的 `_reclaim.reset()` 會在閘門內長出修法①蓋不到的第三個 abort 面。—— 追蹤 同上報告第 4 項
- **2026-09-03**(Story 007,跨工作單陷阱,建議掛 **Story 014**、驗收影響**交叉登記 Story 011**):
  `reclaim_progress()` 在 `_reclaim` 為 null 時回 `0.0`,**與真實量測的 `0.0` 在回傳值上不可區分**。
  Story 014 解凍前它恆為 `0.0` → **Story 011 的 AC-31 GIVEN 永遠成立、AC-31b(進度非零)永遠觸發不到**,
  測試會全綠卻從未驗到它要防的東西。與 `story-011` 工作單第 69 行記載的教訓同形。
  已在 `reclaim_progress()` 的 doc comment 寫入二義性警告。—— 追蹤 `docs/reviews/story-007-test-evidence-review-2026-09-03.md` G-1 節
- **2026-09-03**(Story 007,N-1 的殘留):**接縫的縮排層級是一項規格,但沒有任何自動檢查。**
  已改用具名區域旗標讓依賴關係不再靠縮排表達、並在註解逐字寫明,**但實作端誠實指出「註解不是自動檢查」**,
  而真正該擋住回歸的測試要等 Story 005 填入主體才寫得出來。—— 追蹤 同上引擎報告第 15(c) 項
- **2026-09-03**(Story 007,測試側五個已登記缺口,不阻擋):**G-3** 閘門中止路徑落旗只有論證沒有證據
  (與引擎覆核 S-1 同一處)、**G-4** 乙分支從未跨表面測過(fixture 只註冊一個表面,「同 id 不同 surface」零涵蓋)、
  **G-5** `SetTargetResult.INVALID_SURFACE_TYPE` 整個列舉成員零斷言、**G-6** 只在 release 生效的 null 分支
  在 debug 測不到(`assert()` 先擋)、**G-7** `arbitrate` 的 provider 失效路徑零涵蓋
  (R6-11 的「錯誤只報一次、計數持續累加」不變式完全沒測)。—— 追蹤 同上測試報告第 8 節
- **2026-09-03**(Story 007,引擎覆核 S-2~S-5,四項建議):**S-2** `_registry` 是三個協作者中唯一沒有建構期
  null 處置的;**S-3** `technical-preferences.md` 的 (A) 級三分法**沒有涵蓋「量測對象是引擎行為本身」的情況**
  —— 本張探針按字面不成立 (A) 級,但那是分類法缺口而非探針缺陷,建議補釐清而非降級;
  **S-4** Story 014 加一條驗收「開機 `ERR_RECLAIM_POLICY_ABSENT` 紅字消失」,給它一個到期日;
  **S-5** `MarkResult`/`SetTargetResult` 的未定義邊界在 ADR 補非規範性註記。—— 追蹤 同上引擎報告建議表
- **2026-09-03**(**流程問題,非任何專家之過,主 session 自陳**):**並行派工會製造一個「綠燈不代表涵蓋」的窗口。**
  本批為縮短時間讓實作與測試並行,實作端在測試端填完前跑了全套並得到綠燈 —— 字面為真,
  但當時 36 條裡有 30 條是零斷言空殼,**GdUnit4 對空殼一律判通過**。若該綠燈被當成「Story 007 測試通過」上報,
  就是一個假的完成訊號。**往後採並行派工必須在派工單與回報中明文區分「程式能編譯 / 既有測試沒壞 / 新測試涵蓋」三件事。**
## Resolved

*(尚無)*
