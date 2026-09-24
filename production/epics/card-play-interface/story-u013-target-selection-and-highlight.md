# Story U-013:選作用對象 S2/S2p/S2q + 合法目標高亮 + 跳轉鍵

> **Epic**:卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **型別**:Integration
> **狀態**:✅ Complete(2026-09-24,管理者裁決。`ui-programmer` 實作;`tests/integration/ui/card_target_selection_test.gd` **39 條全綠**,其中 **11 條常駐 `test_sensitivity_proof_*`,涵蓋敏感度門檻全部 13 列、零改判**。工作單列的 6 條預期測試逐條核對**全部存在**。全套 **939 條、74/74 套件、939/939 全執行、0 errors、0 orphans**,唯一失敗是既有已核准的刻意紅燈(`affinity_phi_provider`),零回歸 —— 協調者於裁決當日自行跑引擎複驗,未採信報告。
> 🔴 **兩個協調者判定經管理者 2026-09-24 明文維持**:①#20-23 四條共用一條證明函式**不拆**(該函式內部對左/右/上/下各自組情境、各自斷言);②#17 證明強度**足夠**(mutant 無條件執行的正是真實方法 `if legal.is_empty()` 分支的同一組賦值,即「分支條件恆真」這個最可能的真實回歸形狀)。**兩項均可日後推翻。**
> ✅ **截圖證據規則第 5 點(人工開圖確認)已由管理者於 2026-09-24 完成**,對象為 P-F3 灰階兩態圖(`prototypes/godot-specialist-pf3-grayscale-prep-2026-09-24/legal_state.png` / `illegal_state.png`)。逐字回覆兩則:**「看過了,通過」**、**「一點都不像,不管它」**(後者針對下方那個假警報)。
> 🔴 **而這一關當天示範了它為什麼不能被代行 —— 協調者代看產生了一個假警報,管理者實際開圖當場否掉。**
> 管理者原先裁決「不用」親自開圖,協調者代為複核,判定「叉讀得出是完整的叉、襯底變深未蓋住它」(✅ 此項與管理者結論一致),**但另外提出一個灰階數字抓不到的疑慮**:好感度關係線與不合法叉使用同一種視覺語言(皆為細的淺色斜線),盤面線一多可能被誤讀為「兩條關係線交叉」。管理者一度裁決「先不處理」;隨後實際開圖,逐字判 **「一點都不像,不管它」**,該疑慮**結案為不成立**。
> **可推廣的教訓**:協調者代看**不等於**人眼複核 —— 這次代看的產出是一個**假警報**,而假警報在本專案已有前例會引發跨網域調查、差點去改一段本來正確的程式(見 `coding-standards.md` 的 194 格違規案例)。**該規則要求的是「人」,不是「有人看過就好」。**
> ⚠️ **`production/qa/evidence/u013-card-target-highlight-*-2026-09-22.png` 兩張仍無明確人工開圖紀錄** —— 管理者那句「看過了,通過」未確認是否涵蓋這一組(協調者問過,未獲指定)。**照實登記,不推定涵蓋。** 該目錄亦無對應證據 `.md`。
> **估時**:M
> **依賴**:U-012(Z2 展開層 + 選牌導覽)
> **波次**:波 4(可與 U-009/U-010 平行——寫 `battle_screen.gd` + `board_view.gd`,與選單 `battle_menu.gd` 無交集)

## Context

- **UX 規格**:`design/ux/skill-card-play.md`(AC-U3,`Interaction Map` 的「選作用對象的導覽」節,`States & Variants` S2/S2p/S2q)
- **權威 ADR**:ADR-0001(戰棋查詢原子性,**Accepted**)——本 story 全程零寫入(選對象不觸發任何權威寫入路徑);ADR-0005(游標/裝置權威,**Accepted**)——本 story 是**第一個**讓打牌流程接上單一游標狀態源的單元
- **Engine**:Godot 4.7.1

## 目標

讓玩家在選定一張牌後,能在棋盤上選取作用對象:方向鍵/十字鍵逐格走、`Tab`/`Shift+Tab`(RB/LB)跳到下一個合法目標,並讓合法/不合法的格子有可拆出成因的三態疊加圖。

## 🔴 本 story 決定的原始碼目錄路徑

本 story 修改兩個既有檔案(累加修改,不新建):

- `src/ui/battle/battle_screen.gd`——目標選擇的輸入分派、`_process(priority=100)` 讀取時機皆落在這支檔案。
- `src/ui/battle/board_view.gd`——合法目標高亮的疊加圖繪製落在這支檔案。

## 本 story 必須讀而非重寫的既有邏輯層

`card_play_session.gd` 已交付完整的目標選擇邏輯,本 story 只負責 UI 接線:

- `legal_targets() -> Array[int]`:在 `SELECTING_TARGET` 回傳甲類的全部我方存活單位,或丙類的 `_s2p_legal_first_targets()`;在 `SELECTING_TARGET_B` 回傳 `_s2q_legal_second_targets(first)`(垂直切片通常僅 1 個)。
- `select_target(unit_id: int) -> bool`:甲類直接進 `CONFIRMING`;丙類進 `SELECTING_TARGET_B`(S2p→S2q)。
- `select_second_target(unit_id: int) -> bool`:丙類 S2q→`CONFIRMING`。
- `cancel()`:在 `SELECTING_TARGET` 退回 `SELECTING_CARD`;在 `SELECTING_TARGET_B` 退回 `SELECTING_TARGET`(清空 `_selected_target_a`,回到 S2p 重選)。

🔴 **不要在 UI 層重算合法目標**——`legal_targets()` 已經是唯一真值來源,UI 只負責把它畫成疊加圖與跳轉順序。

## Implementation Notes

1. 🔴 **一條不會報錯的實作義務,逐字轉錄自 `skill-card-play.md`(ADR-0001 第一次修訂隨附)**:

   > **打牌確認若要讀「游標系統裁定後的狀態」(當前選了哪張卡、哪個目標、哪個裝置持權威),
   > 該讀取不得放在按鍵處理(`_input` / `_unhandled_input`)裡,必須放在 `_process(priority=100)`。**

   理由是實測的同幀分派順序:`_input()` → `_unhandled_input()` → `_physics_process()` → `_process()`,而游標裁定要到 `_process()` 才算出本幀結果——**在按鍵處理裡讀它,讀到的是上一幀的值。**

   ⚠️ **現有的攻擊確認(`battle_screen.gd:712` 的 `_confirm_at_cursor()`)不踩這條**——它讀自己本地追蹤的 `_cursor_cell`(見 `_handle_directional()`),不經過 `CursorStateHost`。**但本 story 依 GDD UI Requirements #3 必須走單一游標狀態源**,是本 epic 第一個真正接上 `CursorStateHost` 的打牌流程單元,接上去就會踩到這條義務——落地時務必把「讀取當前選取的目標格」放在 `_process(priority=100)`,不是 `_unhandled_input()`。

2. **AC-U3 的核心是決定性順序,不是循環本身**。跳轉鍵(`Tab`/`Shift+Tab`,RB/LB)在 `legal_targets()` 回傳的集合上跳轉,順序必須是**先列後行**(`y` 升冪、同列再 `x` 升冪)——`skill-card-play.md` 逐字:「這個順序必須寫成測試釘死,否則『今天的順序』與『規則』無法區分」。實作建議:寫一個純函式(不依賴節點)對 `Array[int]` unit id 集合依其棋盤座標排序,供測試直接呼叫,不必啟動場景。

3. **不合法的格子仍然走得進去**,方向鍵/十字鍵的逐格導覽不因為某格不合法就跳過它;只有**確認**會被拒絕,且拒絕原因須與 S6(權威寫入中)的拒絕外觀可區分(`P-F2`)。

4. **三態疊加圖**(合法 / 不合法 / 不可達或未涉及)不得只靠色彩區分(`P-F3` 無例外),沿用既有模式 `P-D1`(三態範圍疊加圖,拆出成因)、`P-D2`(並存疊加圖,不得做成互斥模式切換)的既有精神——若 `board_view.gd` 已有既有的移動範圍/威脅範圍疊加圖實作可參考其形狀,不必另創一套疊加機制。

5. **丙類 S2p→S2q 的視覺延續**:第一個已選者在 S2q 階段持續標示(`skill-card-play.md`:「第一個持續標示」),不是選完就消失。

6. **取消行為**:`Esc`/`B`(`battle_cancel`,由另一半 U-005 新增)在 S2 呼叫 `session.cancel()` 退回 S1;在 S2q 呼叫 `session.cancel()` 退回 S2p(重選第二人),**不是**直接跳回 S1——這是 `card_play_session.gd` 既有 `cancel()` 的既定行為,UI 只需忠實呼叫,不要自己另寫一套「退兩步」的邏輯。

## Acceptance Criteria

*以下為 `design/ux/skill-card-play.md` 的條文原文轉錄,未改寫:*

- [x] **AC-U3**:我方 5 隻存活、選定一張甲類 → 連按「跳下一個合法目標」5 次 → 游標依序停在該 5 隻上,第 6 次回到第 1 個;重跑一次順序完全相同(Logic,BLOCKING)
  **滿足依據**(三條測試各自對應 AC 的一個子句,2026-09-24 全綠):
  `test_jump_to_next_legal_target_cycles_in_row_major_order`(依序停在 5 隻上)、
  `test_jump_cycle_wraps_from_last_to_first`(第 6 次回到第 1 個)、
  `test_jump_order_identical_across_repeated_runs`(重跑順序完全相同)。

## Test Evidence

**型別**:Integration
**測試檔**:`tests/integration/ui/card_target_selection_test.gd`

預期涵蓋:

- `test_jump_to_next_legal_target_cycles_in_row_major_order`(AC-U3,純函式測試,不依賴節點——y 升冪、同列 x 升冪)
- `test_jump_cycle_wraps_from_last_to_first`
- `test_jump_order_identical_across_repeated_runs`(AC-U3 後半:「重跑順序相同」)
- `test_illegal_tile_reachable_by_directional_navigation_but_confirm_rejected`
- `test_reading_cursor_arbitrated_target_happens_in_process_not_input`(白箱,驗證讀取時機放在 `_process(priority=100)`,不在 `_input`/`_unhandled_input`)
- `test_cancel_from_s2q_returns_to_s2p_not_s1`(既有 `cancel()` 行為的整合驗證)

## Out of Scope

- **展開手牌、選牌(S1)**——屬 U-012(已交付,本 story 從其後接續)。
- **確認面板 S3**——屬 U-014。
- **`legal_targets()` / `select_target()` / `select_second_target()` 的邏輯本身**——已由既有 `card_play_session.gd` 交付,本 story 不重寫。
- **世界層的生效中修正標記(Z4)**——切片外(U-017)。
