# Story 008:把「打牌」這個動作接上

> **Epic**:技能卡牌系統
> **型別**:Integration(**BLOCKING**)
> **狀態**:📋 Ready
> **估時**:M
> **依賴**:005(打牌流程資料層)、006(接線)、007(棄牌閘門)—— 全部已完成

## 目標

**牌現在會進手、會過期、會被強制棄掉 —— 就是打不出去。**
`CardPlaySession` 在 `src/` 仍是零呼叫點(已 grep 覆驗)。本 story 把它接上。

## 範圍

**只做邏輯層的接線。不碰按鍵、不碰畫面。**
🔴 `Esc`/手把 `B` 目前是玩家唯一能結束回合的手段,重綁必須與戰鬥選單同批上線
(`skill-card-play.md` AC-U12 / `battle-menu.md` AC-M1)。**本 story 完全不碰輸入。**

## 🔴 打牌是第五個玩家動作,而 Story 007 的閘門只擋了四個

Story 007 擋了 `select_unit` / `click_tile` / `end_unit_turn` / `end_faction_phase`。
**當時打牌沒被擋,因為它還沒接上。** 接上之後它必須落入同一個閘門 ——
否則玩家在欠棄牌時打不了單位、卻打得出牌,**而裁決逐字要求「玩家才能動作」。**

## 🔴 但閘門不是「全擋」,而這是規格寫死的,不是判斷題

`design/ux/skill-card-play.md` 的 **S4 強制棄牌** 逐字:

> **Z2 展開,🔴 無法收起。只能選一張棄掉;取消鍵在此狀態無效。**

**亦即強制棄牌時手牌是攤開的**,而且**收不起來** —— 否則玩家沒有辦法棄牌。

| 動作 | 欠棄牌時 |
|---|---|
| 開手牌(`open_hand`) | ✅ **不擋** —— 玩家要靠它挑棄哪一張 |
| 瀏覽/選牌(`select_card`)、查合法對象(`legal_targets`) | ✅ **不擋** —— 唯讀,且玩家要看得見才能挑 |
| 選作用對象(`select_target` / `select_second_target`) | 🔴 **擋** |
| **確認打出(`confirm`)** | 🔴 **擋** —— 這是真正的寫入 |
| 取消(`cancel`) | 🔴 **擋**(規格:取消鍵在此狀態無效) |

⚠️ **判準是「會不會寫入或推進」,不是「跟卡牌有沒有關」** ——
與 Story 007 擋動作不擋視野的分工一致。

## 落點建議(可調整,說明理由即可)

`BattleController` 持有 `CardPlaySession`(比照它已經持有 `BattleState` / `TurnOrder`),
並轉出打牌流程的方法。**卡池為選配,故打牌流程也必須是選配** ——
未附卡池的戰鬥,打牌相關查詢一律安全回傳「沒有」而非崩潰(比照 AC-W6)。

🔴 **`CardPlaySession._init()` 需要五個東西**(`deck` / `state` / `links` / `write_port` /
`authoritative_write_in_progress_check`)。**`write_port` 目前沒有任何實作**
(好感度數值池零實作,見 Story 004)—— **它必須維持可注入且允許為空**,
未附埠時丙類確認一律回傳可觀測的拒絕,**不得崩潰、不得靜默成功**。

## 驗收條件

| # | GIVEN / WHEN / THEN |
|---|---|
| **AC-P1** | 附卡池與埠的戰鬥 → 開手牌 → 選甲類 → 選我方單位 → 確認 → **該單位 `effective_atk()` 反映卡片的 `delta_atk`**,且該牌離開手牌 |
| **AC-P2** | 同上但**確認前取消** → 手牌逐字未變、無任何修正產生、盤面未變 |
| **AC-P3** | 🔴 **欠棄牌時**:`open_hand()` / `select_card()` **成功**;`select_target()` / `confirm()` / `cancel()` **全部被拒且拒絕可觀測** |
| **AC-P4** | 欠棄牌 → 棄掉一張 → **上述被擋的三個動作全部恢復可用** |
| **AC-P5** | 打牌**不消耗**移動/攻擊旗標(打牌前後該單位兩個旗標逐字不變),且**同回合可連打** |
| **AC-P6** | 未附卡池 → 打牌相關查詢安全回傳「沒有」,整場戰鬥不崩潰(比照 AC-W6) |
| **AC-P7** | 未附寫入埠 → 丙類確認回傳**可觀測的拒絕**,好感度零寫入,**不崩潰、不靜默成功** |
| **AC-P8** | 打牌後,**與畫面呈現同一份**的傷害預判查詢反映新值 —— 🔴 **必須呼叫 `BattleState.preview_damage()`,不得自行重算公式** |

🔴 **AC-P3 必須有正面控制組**:先證明**不**欠棄牌時 `select_target()`/`confirm()` **確實會成功**,
再證明欠棄牌時被拒。**少了控制組,那條測試在「方法根本沒接上」時也會通過。**

## 測試

`tests/integration/gameplay/cards/card_play_wiring_test.gd`(**獨立檔**)

只跑自己那一檔:
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/integration/gameplay/cards/card_play_wiring_test.gd
```
⚠️ **路徑打錯會回報「找不到、無測試」然後 exit 0** —— 看 `Executed test cases` 條數。

**跑全套(必跑,你改 `BattleController`):**
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s tests/gdunit4_runner.gd
```
**基準 544 條 / 0 errors / 1 failures / 0 orphans / exit 100** + 你新增的。
唯一容許失敗是 `tests/unit/gameplay/affinity/affinity_phi_provider_test.gd`(刻意留紅,**勿動**)。
⚠️ `failures` 數的是失敗的**斷言**不是**測試** —— `grep " FAILED"` 數被點名的測試名稱。

## 🔴 兩道提交閘門
①產品碼含 `INJECT`/`INJECTED FAULT`/`DO NOT COMMIT` → BLOCK
②測試檔含函式名有 `test_` 但不以 `test_` 開頭 → BLOCK

⚠️ **閘門只擋帶標記的注入。** 本 epic 有一位專家把一個欄位換成字面 `0` 證明驗收條件、
沒加標記,閘門完全沒反應 —— 後果是「所有攻擊加成牌一律無效」,不崩潰不編譯失敗。
**注入一律加大寫標記,那是你自己的保險**(本 epic 有 4 位專家停在還原步驟之前)。

## 完成判準
1. 你那一檔全綠 + 全套無非預期失敗
2. **敏感度證明至少涵蓋 AC-P1 與 AC-P3**;注入加標記;誠實列出沒證明的
3. 注入與改名全部還原,自己 grep 核對

## 不做
- 任何按鍵綁定、任何畫面、手牌顯示
- 卡表本體(測試自建卡片即可)
- 好感度數值池的實作(丙類端到端仍待 #1)
