# 營火 —— 2026-11-23 管理者裁決(逐字)

接續 `docs/reviews/campfire-rulings-2026-11-20.md`。依據:game-designer `docs/reviews/campfire-default-deck-12-2026-11-23.md`;lead-programmer `docs/reviews/campfire-open-tech-2026-11-23.md`(第 1 題探針 `prototypes/lead-programmer-campfire-source-probe-2026-11-23/run_output.txt`,協調者已讀原始行:`SUPPORT_CONVERSATION m=3.0 → narrative_depth=3.0`、`COMBAT_CARD m=3.0 → narrative_depth=0.825`)。

## 協調者查證的前提

- 第 1 場牌表 `assets/data/cards/vs01_cards.txt` **8 張**,第 2~5 場 `vs02~vs05_cards.txt` 各 **14 張**(`grep -c '^card_'`,2026-11-23)。11-20 第 4 題「預設 14 = 上限 14」的前提只對第 2~5 場成立。
- `reset_campaign()` 正式呼叫端只有 `src/ui/battle/battle_screen.gd`(打贏最後一場);標題「開始」接 `start_tutorial`(`src/ui/shell/title_screen.gd`)。

## 裁決

| # | 題目 | 管理者答(逐字) | 推薦項 | 連帶影響 |
|---|---|---|---|---|
| 1 | 預設牌組 12 張拿哪 2 張 | 「照設計師建議(推薦)」 | 是 | 第 1 場 8 張不動;第 2~5 場拿掉 card_19 聯手破門、card_21 臨時搭檔 |
| 2 | 支援對話的好感度寫入時機 | 「改成對話播完才寫入(推薦)」 | 是 | 營火看到的關係不含尚未播放的對話;lead 估 +0.5~1 估計天(未驗證) |
| 3 | 關掉遊戲後的「繼續」 | 「只在這次開著遊戲時有效(推薦)」 | 是 | 不新增存檔;lead 估 0.5~1 估計天(未驗證) |
| 4 | 尚無進度時「繼續」 | 「灰掉不能按(推薦)」 | 是 | 按鈕位置固定,手把游標不需處理按鈕數量變化 |

## 營火寫入來源值(lead 實測,非管理者題)

用 `SUPPORT_CONVERSATION`(讀回值 = 寫入值,不乘 alpha、新池無陣亡封鎖)。⚠️ lead 另測到記錄附加順序微幅影響結果([2,3] 讀 4.88 對 [3,2] 讀 4.82)→ 營火寫入先後須有確定規則,寫進 story-002。

## 仍未決(交 producer 列入工單待決,不阻擋 001)

- 打輸後「回營火」時:牌組是否一起回滾(需牌組快照,lead 估 +0.5 估計天)、營火使用次數是否歸零。第 1 場戰敗無營火可回。
