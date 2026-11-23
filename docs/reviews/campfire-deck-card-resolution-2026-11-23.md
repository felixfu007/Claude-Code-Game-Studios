# 營火卡解析與牌表權威來源 — 建議(2026-11-23,lead-programmer)

證據等級:本文只讀碼 + 對真實資料檔做逐行文字比對(awk,未跑引擎)。依專案三分法,**資料檔比對為「檔案內容事實」(B 以上、非 (A));程式行為推論為 (C)**。各條逐項標示。

## 一、結論(一句話)
推薦 **A 的修正版**:登記區放在 `CampaignDeck`(同一物件、同一次快照),`add_new_card` 多收 `Card`;檔案型卡一律以 **`vs02_cards.txt` 為權威**,並用一支測試釘住 vs02~vs05 的 card_07~22 逐行相同。C 不建議(只是延後,005 的 AC2「新營火卡會出現」就驗不到)。

## 二、card_07/08(及預設牌組全部 id)實查
(B)awk 逐行比對 `assets/data/cards/vsNN_cards.txt`:
- card_07、card_08:vs01~vs05 **五份牌表的卡面行逐字相同**(`sort -u` 皆 1 行)。
- 預設牌組用到的 card_11~22 共 14 個 id(含收藏區 19、21):vs02~vs05 四份逐字相同。
- vs01 只含到 card_08(104 行檔,另含其他編號);不含 card_11 以後的比對,vs01 不能當權威(第 1 場本來就不走牌組)。
- **文字檔不同**:`vsNN_card_text.txt` 中 **card_08 在 vs04 與其他三份不同**(vs04 寫「這是他待過的地方,心虛被她看穿」,其餘三份相同);card_07 與 card_11~22 的文字四份相同。
  - 後果:若戰役中用牌組解析,card_08 的敘述文字不再隨第 4 場變成「舊地盤」版本。這是**設計取捨**(game-designer/narrative 決定是否可接受),不是程式問題。(B)

權威來源建議:
1. 卡面(`*_cards.txt`):固定 `vs02_cards.txt`(戰役第 2 場的牌表,也是預設牌組檔頭自述的來源);**用一支資料一致性測試釘住** vs02~vs05 中 card_07 與 card_11~22 逐行相同(依 test-standards 已登記的「讀 `assets/data/` 真實夾具」例外,檔頭須宣告該例外,並揭露它不證明窮盡)。
2. 文字(`*_card_text.txt`):同樣取 vs02;card_08 差異在測試中**明列為已知允許差異**,不要靜默忽略。
3. 不建議「依當場關卡牌表」解析:同一 id 會因場次而內容不同的可能性被保留下來,而目前資料證明沒有這個需求。若將來有檔案型卡在各檔分歧,測試會紅,屆時再裁決。

## 三、三案比較
- **A(登記區放 CampaignDeck)—— 推薦。** 理由:牌組/收藏區/「新」標記/登記區是同一個領域概念的狀態,放一起才能用同一個快照入口;`CampaignDeck` 目前刻意不碰 FileAccess,不違反(Card 是 RefCounted,執行期物件)。修正:`add_new_card(card_id, card: Card)` 簽章雖可,但更建議**拆成 `register_card(card)` + `add_new_card(card_id)`** 或維持單一方法並在內部登記;須決定「id 已擁有回 false」時是否仍覆蓋登記(建議不覆蓋,維持現行『不動任何狀態』語意)。
- **B(登記區放 CampaignProgress)。** `CampaignProgress` 是靜態單例(規則檔登記的例外之一,明文「不再有第三個」)。把更多狀態塞進它違背該例外的精神,且牌組快照要跨兩個物件同步,易漏。不推薦。
- **C(005 只做檔案型卡)。** 風險:005 AC2「新營火卡會出現」無法驗收;營火卡 id 進入牌組後,戰鬥端遇到無法解析的 id 的行為要另訂(靜默略過 = 牌庫張數悄悄少於確認牌組,與 AC1 衝突)。只有在營火卡實際產出路徑(story-006 之後)還沒接上時才有意義。不推薦,除非 003/006 接線排程在 005 之後。

## 四、與 story-015 的相容性
015 已裁決「牌組退回營火之前、需牌組快照」。(B)讀 015 工單。
- **登記區要一起快照**——但理由是「單一入口、不會漏」而非「不快照會錯」:登記區是只增表,孤兒條目無害(id 不在牌組就不會被戰鬥讀到);重回營火再產同一 id 時,`add_new_card` 在 id 未擁有時會再度入帳,登記區應**覆蓋為新產生的 Card**。(C 推論,未跑引擎)
- 建議 `CampaignDeck` 提供 `snapshot() -> Dictionary` 與 `restore(snapshot)`,內容含 `_confirmed_deck`、`_confirmed_collection`、`_new_marks`、登記區(Dictionary 淺拷貝;Card 若執行期不再被改動可共用參照,**此點未查證,實作者須確認 Card 是否有可變狀態**)。這樣 015 只需加呼叫,不必再改 deck 內部。
- 另一個要提醒 015:`cancel_edit()` 會把編輯中牌組丟回已確認狀態;快照應存「已確認」那組,restore 後須同時重設編輯中副本。

## 五、005 的另一個設計點(提醒,非本題)
- 005 AC3 要求未注入戰役者行為不變;解析器建議做成獨立小類別(例如 `CampaignCardResolver`:輸入 `Array[String]` + 登記區 + 檔案型卡目錄,輸出 `Array[Card]`,**找不到 id 時 push_error 並整批回 null,不要靜默略過**)。檔案型卡目錄由 `battle_screen.gd` 讀 vs02 檔(既有 `Card.cards_from_text` 可用),維持 `CampaignDeck` 不碰 FileAccess。

## 六、要動的檔(只列)
- `src/gameplay/campaign/campaign_deck.gd`(登記區、`add_new_card` 簽章、`snapshot()`/`restore()`——snapshot 可延至 015)
- 新檔 `src/gameplay/campaign/campaign_card_resolver.gd`(建議;005)
- `src/ui/battle/battle_screen.gd`、`src/ui/shell/scene_router.gd`(005 注入點,工單已列)
- `src/gameplay/cards/card_deck.gd`(必要時,005 已列)
- 呼叫 `CampfireCardGenerator.generate()` → `add_new_card` 的接線點:story-006 之後的營火流程(`src/core/campaign/campaign_progress.gd` 或營火場景;**目前沒人呼叫,需另確認歸屬工單**)
- 新測試:`campaign_deck_test.gd` 增補、資料一致性測試(vs02~05 逐行比對)、005 整合測試
- 文件(須先問):story-004/005 的 Affected Files 與 AC 加註;`default_deck.txt` 檔頭無需改

## 七、未驗證項(逐字)
- 未跑引擎、未讀 `Card` 是否有可變欄位、未讀 `CampfireCardGenerator`(story-003)的 id 產生規則(是否同配對恆產同 id)。後者決定「回營火重選」時 id 衝突行為——**實作者查證不符就停下**。
- vs01 card_07/08 行與 vs02~05 相同,是上方 awk 的第一次 grep 輸出(每檔一行、`sort -u` 為 1)得出。
