# Story U-015:強制棄牌 S4(無法收起、取消鍵無效、選單亦拒絕開啟)

> **Epic**:卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **型別**:Integration
> **狀態**:📋 Ready
> **估時**:M
> **依賴**:U-012(Z2 展開層 + 選牌導覽)
> **波次**:波 5(與 U-014 真平行——本 story 寫 `hand_bar.gd` + `battle_screen.gd`,U-014 寫 `card_confirm_panel.gd`(新);⚠️ 前置不同,本 story 需 U-012,U-014 需 U-013)

## Context

- **UX 規格**:`design/ux/skill-card-play.md`(`States & Variants` S4、`Entry & Exit Points`、「兩個不可逆出口都不得只靠一次按鍵」)、`design/ux/battle-menu.md`(AC-M16、Entry 表的 2026-09-11 管理者裁決)
- **權威 ADR**:ADR-0001——棄牌本身不是權威寫入路徑意義上的「盤面異動」,但它是玩家在回合開始被系統送來的阻塞狀態
- **Engine**:Godot 4.7.1

## 🔴 本 story 是兩條線的匯流點

本 story 同時寫 `src/ui/battle/hand_bar.gd`(U-011/U-012 已在此檔累加)**與** `src/ui/battle/battle_screen.gd`(U-003/U-013/U-016 也寫這個檔案,946 行,EPIC.md 第四節列為本 epic 最大的序列化點)。**排這張工作單時,前面的 011/012 與 013 都必須先落地**,否則本 story 一開始就要處理兩份還在變動的介面。實作順序上不要與 U-013/U-014 同時動 `battle_screen.gd` 的相鄰區塊。

## 目標

當回合開始補牌後手牌達 6 張,強制進入棄牌態:手牌介面被系統打開且無法收起,取消鍵在此狀態失效,選單也拒絕開啟——玩家唯一能做的事是選一張牌棄掉。

## 本 story 必須讀而非重寫的既有介面

- `CardDeck.has_pending_discard() -> bool`(`card_deck.gd:127`,讀 `_pending_discard`)。
- `CardDeck.discard_card(card: Card) -> bool`(`card_deck.gd:143`),成功時把 `_pending_discard` 設回 `false`。
- `BattleController.has_pending_discard() -> bool`(`battle_controller.gd:287`,轉呼叫 `_state.has_pending_discard()`)——doc comment 明文：「A caller wiring up a discard-prompt UI polls this to know whether to show one」,本 story 就是那個呼叫方。

🔴 **不要新建第二個「是否強制棄牌」的旗標**——上面三層查詢已經是完整的既有鏈,UI 只需要輪詢 `BattleController.has_pending_discard()`。

## Implementation Notes

1. **S4 呈現**(`States & Variants` 表):Z2 展開,**無法收起**;只能選一張棄掉;**取消鍵在此狀態無效**。與一般的 S1(自願開手牌)共用 Z2 的展示邏輯(來自 U-012),差異只在於：入口不是玩家按鍵而是系統偵測到 `has_pending_discard()`,且退出路徑被鎖死成唯一一條(棄牌)。

2. 🔴 **「永遠可以選擇不打」與「強制棄牌是阻塞的」兩者並存,不矛盾**(`skill-card-play.md` 逐字):

   > **可以拒絕「打出」,不可以拒絕「棄掉」。** S4 是唯一取消鍵無效的狀態,而它必須讓玩家
   > 看得出來自己不是按錯(拒絕須可觀測,`P-F2`)。

   實作時,`battle_cancel` 在 S4 期間必須被顯式吞掉並給出可觀測的拒絕回饋(而非「按了沒反應」的靜默失敗)——這與其他情境的拒絕外觀必須可區分(`P-F2`)。

3. **選單也拒絕開啟(AC-M16),但這條判斷式已經存在,不是本 story 新增的**。`battle-menu.md` 逐字記載其來源與裁決依據:

   > 沿用既有 N5 拒絕開啟路徑,判斷式沿用既有查詢 `BattleController.has_pending_discard()`
   > (Story 007 已用它擋 `end_faction_phase()`)——**不需要新的判斷式,也不需要設計任何新畫面**。

   🔴 **選單側「按 `battle_menu` 時檢查 `has_pending_discard()` 並拒絕開啟」的實作屬 U-007/U-008(另一半)的職責範圍**——`battle_menu.gd` 目前不存在,U-015 不建立它。本 story 的職責是**交付會讓 `has_pending_discard()` 變 `true` 的 S4 狀態本身**,並在整合測試裡驗證 AC-M16 這個跨檔案的行為(手牌側觸發、選單側拒絕)確實成立。若撿到工作單時 U-008 尚未落地選單的 N5 判斷,先與該工作單的實作者確認銜接時點,不要為了讓測試先過而在 `hand_bar.gd` 或 `battle_screen.gd` 裡重寫一份選單拒絕邏輯。

4. **拒絕外觀須與 AC-M8(權威寫入拒絕)可區分**(AC-M16 明文要求)——強制棄牌須明說原因(比照「請先完成棄牌」一類文字),不得與權威寫入那種拒絕共用同一個外觀。這條外觀差異的具體實作落在選單側(U-008),本 story 需要提供的是**觸發它的正確前提條件**與**能驗證此區分的整合測試**。

5. **強制棄牌不需要處理的邊界**：陣亡標記表、逐條修正到期(那是回合開始三件事裡的另外兩件,①②不歸本 story 管,見 EPIC.md「回合開始三件事的呈現」節)——本 story 只接手第③件(強制棄牌本身)。

## Acceptance Criteria

*以下為 `design/ux/battle-menu.md` 的條文原文轉錄,未改寫:*

- [ ] **AC-M16**:🔴 強制棄牌(S4)進行中按 `battle_menu` → 選單未開啟,且拒絕回饋明說原因(「請先完成棄牌」一類文字),與 AC-M8(權威寫入拒絕)的外觀可區分(Integration,BLOCKING——2026-09-11 管理者裁決;擋的是「看起來可選、按下去沒反應」這條會讓玩家以為遊戲壞了的路徑)

## Test Evidence

**型別**:Integration
**測試檔**:`tests/integration/ui/forced_discard_test.gd`

預期涵蓋:

- `test_hand_reaching_six_cards_forces_z2_open_and_uncollapsible`
- `test_cancel_key_rejected_during_forced_discard_with_observable_feedback`
- `test_discarding_one_card_clears_pending_discard_and_returns_to_normal_flow`
- `test_battle_menu_rejected_during_forced_discard`(AC-M16,跨檔驗證——需 U-008 的選單 N5 判斷已接上 `has_pending_discard()`,若撿到時該判斷尚未存在,本測試先標記為待補並在 story 狀態裡註記)
- `test_forced_discard_rejection_appearance_distinguishable_from_authoritative_write_rejection`(AC-M16 後半,與 AC-M8 外觀可區分)

## Out of Scope

- **選單本身的開關、N5 拒絕外觀的具體渲染**——屬 U-007/U-008(另一半),本 story 只提供觸發前提與跨檔整合驗證。
- **回合開始的甲類到期移除、補牌呈現**——不屬本 story(那是「回合開始三件事」的①②,見 EPIC.md 對應節)。
- **`has_pending_discard()` / `discard_card()` 的邏輯本身**——已由既有 `card_deck.gd`/`battle_controller.gd` 交付,本 story 不重寫。
- **確認面板 S3**——屬 U-014,強制棄牌不經過確認面板(選定要棄的牌即直接生效,無二次確認)。
