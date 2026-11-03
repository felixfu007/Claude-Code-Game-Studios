# Story 009:點名角色的卡牌只能給點名者使用

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Ready(2026-11-03)—— 🔴 GDD 修訂需另行核准(見下),程式可先做
> **Type**: Logic
> **Estimate**: M
> **依據**:管理者裁決逐字(2026-11-03):「限定只能給點名者」(**非推薦**;推薦為「給點名者有額外效果」;另被跳過:維持現狀記成知情接受)。
> 協調者提問時已揭露代價:**點名者倒下或沒上場時,這張就是廢牌 —— 正是 2026-09-10 對配對卡否決過的做法。** 管理者知情選擇。
> 背景:`docs/reviews/card-named-character-options-2026-11-03.md`(game-designer;方案 B)。

## 為什麼

甲類卡(暫時數值修正,`Card.Category.TEMPORARY_STAT_MODIFIER`)牌面點名角色(例 card_06「丙壓低身形」),但 `src/gameplay/cards/card_play_session.gd` `legal_targets()` 對甲類回傳 `_alive_player_unit_ids()` —— 任何存活我方都可。卡資料**沒有**「點名誰」的欄位。

## Acceptance Criteria

- [ ] **AC1** 卡資料加「點名單位」欄位(資料驅動,不寫死在程式);只對甲類生效。實作者先查清 vs01~vs05 全部卡的牌面點名誰(`assets/data/cards/*_card_text.txt`),逐張列入回報;**牌面點名兩人以上、或點名對象不在我方名冊的卡,停下回報,不要自行決定**。
- [ ] **AC2** 甲類 `legal_targets()` 只回傳「點名單位且存活」;點名者已倒下或不在本場 → 空清單。
- [ ] **AC3** 空清單時這張卡在手牌中呈現為**不可打出**(沿用既有「無合法目標」的呈現;若沒有既有呈現就停下回報,不要自行設計畫面)。廢牌仍佔手牌格、仍可被強制棄牌選中(行為與現行不可打出的牌一致;不一致就回報)。
- [ ] **AC4** 乙/丙類(配對類)行為**完全不變**。
- [ ] **AC5** 測試:點名者存活 → 唯一目標;點名者倒下 → 空;未上場 → 空;乙丙類回歸測試不變;一條敏感度證明。
- [ ] **AC6** 回報:協議 2 量測腳本 `prototypes/protocol2*` 是否受影響(game-designer 已 grep 零命中,請以 grep 原始輸出複驗)。

## 🔴 文件(不在本單程式範圍,需管理者另行核准)

`design/gdd/skill-card-system.md` 需加一段「甲類卡限定點名者」與其代價。由 game-designer 交逐字 diff,協調者問過管理者後才套用。

## Affected Files(可直接改)

`src/gameplay/cards/card_play_session.gd`、`src/gameplay/cards/card.gd`(或卡資料載入處,實作者 grep 確認)、`assets/data/cards/vs0*_cards.txt`、手牌不可打出呈現若需改則為 `src/ui/battle/hand_bar.gd`(🔴 與 battle-hud story-004 同檔 —— 先停下回報,由協調者排序)、對應 `tests/` 檔。
