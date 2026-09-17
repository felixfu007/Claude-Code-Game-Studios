# Story U-011:Z1 手牌縮圖帶(常駐 + S5 不可用 + S7 空狀態三態可區分)

> **Epic**:卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **型別**:UI
> **狀態**:✅ Complete(2026-09-17,`ui-programmer` 實作;15 + 9 條測試、4 條常駐敏感度證明,其餘逐條標明不可證分類。AC-U4 前後半皆滿足。🔴 **S5 證據的宣稱範圍刻意寫窄**:證明 HandBar 收到 LOCKED 會畫成什麼樣子,**不**證明現行遊戲跑得到那個畫面(敵方階段同步執行,見無主開放項)。✅ **截圖證據規則第 5 點(人工開圖確認)已由管理者於 2026-09-17 完成**(逐字「兩張圖看過了 OK」,轉錄於證據文件末節)。⚠️ 該 OK **不涵蓋**三項視覺發現(鎖圖示不像鎖、圖示壓到「不」字、空格對比極低),均歸 `art-director`,尚未裁決)
> **估時**:M
> **依賴**:U-003(戰鬥畫面已建 `CardDeck` 並傳進 `BattleController`,另一半交付)、U-005(project.godot 新增動作,另一半交付)
> **波次**:波 2(與 U-007 真平行——`hand_bar.gd`(新)vs `battle_menu.gd`(新),零交集)

## Context

- **UX 規格**:`design/ux/skill-card-play.md`(AC-U4、`Layout Zones` Z1、`States & Variants` S0/S5/S7、`Component Inventory`)
- **權威 ADR**:ADR-0001(戰棋查詢原子性,**Accepted**)——本 story 全程唯讀 `CardDeck`,不涉及任何權威寫入路徑
- **Engine**:Godot 4.7.1

## 本 story 決定的原始碼目錄路徑

新檔:`src/ui/battle/hand_bar.gd`(+ 對應 `.tscn`)。**U-012 / U-015 之後會繼續往這個檔案長**,見 EPIC.md 第四節的序列化點表——`hand_bar.gd` 是 U-011/U-012/U-015 三者共用的檔案,彼此不可平行。

## 目標

建立手牌縮圖帶(Z1),讓玩家在自己回合期間**不需要展開手牌**就能看到「有幾張、各是什麼類別」,並讓 S0(常態)、S5(敵方回合不可用)、S7(空手牌)三種狀態在灰階下仍可互相區分。

## Implementation Notes

1. **位置與尺寸**(`Layout Zones` 表,呼叫既有函式,不自行重刻換算):

   > Z1 手牌縮圖帶:介面層;安全區水平置中;下緣 = 操作提示橫條**上緣**再往上 `0.5 fpx`;單卡 `2 × 3 fpx`,間距 `0.5 fpx`(合計 `12 fpx` 寬)

   🔴 **必須在操作提示橫條上方,不是螢幕底部**——底部已被既有的 `ControlsHintBg` 佔用(`hud_layout.gd` 的 `controls_hint_bg_rect` 貼齊安全區下緣)。寫成「畫面最底部」會直接疊住它。

2. **卡縮圖的通道**(`Component Inventory`):類別(甲/丙)靠**形狀 + 圖示**區分,非顏色(`P-F3` 無例外)。張數指示為 `n/5` 文字,Cubic 11 字型。

3. 🔴 **S0/S5/S7 三態必須用非色彩通道互相區分**,`States & Variants` 節逐字定義:

   | 玩家看到 | 意思 | 他該做什麼 |
   |---|---|---|
   | 空槽輪廓 + `0/5` | **空狀態**——真的沒有牌 | 等下回合補牌 |
   | 卡在位但整排壓暗 + 鎖 | **不可用**——現在不是你的回合/結算中 | 等 |
   | 卡在位、可選,但確認被拒 | **無合法對象**——這張牌對當前盤面無用 | 換一張牌 |

   S5(敵方回合)的處置是刻意的,`skill-card-play.md` 明文兩種直覺做法都壞掉:**不得隱藏**(玩家分不出「手牌空了」與「現在不能用」,兩者補救動作相反),**也不得看起來照常**(會讓玩家按了沒反應)。做法:Z1 持續在原位,以**降對比 + 鎖狀圖示 + 文案**三通道標示不可用。

4. **S7 是本專案第一個被定義的空狀態**(`skill-card-play.md`:「互動模式庫的 Gaps 表明文登記……而空狀態從未被定義」)。本 story 的空槽輪廓 + `0/5` 就是那個定義的落地,三者的視覺區分不得留到後面才補。

5. **資料來源**:`CardDeck.hand()`(回傳 `Array[Card]` 的拷貝)與 `CardDeck.hand_size()`——U-003 已把 `CardDeck` 傳進 `BattleController`,本 story 只讀,不建構。

6. ⚠️ **`CardDeck` 的 RNG 若用預設值,每次開遊戲手牌都不同**(`card_deck.gd:81` 的 `_init` 預設 `rng: RandomNumberGenerator = null` 時自建一個新實例)——本 story 的截圖 / 灰階測試證據要求可重現,**注入形狀由 U-003 決定**,本 story 只需確認測試裡使用的 `CardDeck` 實例是以固定種子或固定牌組建構,不依賴這裡自己重新處理隨機性。

7. **不可與 S0 混淆的既有節點**:操作提示橫條(`TEXT_CONTROLS_HINT`)是 `battle_screen.gd` 既有常數,**本 story 不修改它**——那是 U-016 的範圍(它會撞到 12px 餘裕問題,見 EPIC.md 陷阱十)。

## Acceptance Criteria

*以下為 `design/ux/skill-card-play.md` 的條文原文轉錄,未改寫:*

- [ ] **AC-U4**:手牌 0 張 → Z1 顯示空槽輪廓與 `0/5`;且該畫面與 S5「不可用」畫面外觀可區分(兩張截圖並列比對)(UI,ADVISORY)

## Test Evidence

**型別**:UI
**測試檔 / 證據**:`tests/unit/ui/hand_bar_test.gd` + `production/qa/evidence/story-u011-hand-bar-evidence.md`

預期涵蓋:

- `test_hand_bar_shows_n_of_5_matching_deck_hand_size`
- `test_empty_hand_shows_empty_slot_outline_and_0_of_5`(AC-U4 前半)
- 手動截圖並列比對:S7(空狀態)vs S5(不可用),轉灰階後仍可區分(AC-U4 後半,依 `coding-standards.md` 截圖規則——須有人打開圖檔確認)
- `test_category_icon_distinguishable_without_color`(白箱,為 U-012 的 AC-U6 預先鋪墊——AC-U6 的「可用 vs 不可用」一組畫面實際落在本 story,驗收跨兩個單元,見 EPIC.md 第三節備註)

## Out of Scope

- **展開層 Z2、卡牌細節 Z3、選牌導覽**——屬 U-012(同檔案 `hand_bar.gd`,後續往下長)。
- **強制棄牌 S4 的阻塞行為**——屬 U-015。
- **卡面美術**(像素尺寸、色數、描邊、字型)——`art-director` + `/art-bible`(UX-3)。🔴 不得沿用 128×128 立繪,它是為世界層整數縮放設計的,本介面屬介面層。
- **字級 75%/150% 兩檔**——功能不存在(UX-5),本 story 僅在 100% 檔位下驗證。
