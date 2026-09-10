# Story 006:把卡牌接進戰鬥迴圈

> **Epic**:技能卡牌系統
> **型別**:Integration(**BLOCKING**)
> **狀態**:📋 Ready
> **估時**:M
> **依賴**:001 ~ 005(全部已完成並提交)

## 目標

讓 `CardDeck` 真的在戰鬥裡運作:開局發牌、每個玩家回合補牌、戰鬥結束收回。

🔴 **現況:`CardDeck` 與 `CardPlaySession` 在 `src/` 皆零呼叫點。**
68 條測試守著它們的規則,**而沒有任何生產程式碼把它們接進戰鬥。**
本 story 只做接線,不新增任何卡牌規則。

## 🔴 這張工作單真正的風險是順序,不是程式量

> **玩家回合開始:必須先 `tick_all_modifiers()`,再 `draw_for_turn()`。**

**理由不是實作偏好**:若先補牌而觸發滿手強制棄牌,玩家會在一個**還掛著已到期修正**的
盤面上,做那個**不可逆**的棄牌決定。**盤面是假的,而決定是真的。**

⚠️ **順序錯了不會報錯、不會崩潰、測試不寫就抓不到。**
Story 002 已用測試證明「若遵守此序,棄牌決策點看到的盤面就是對的」——
**但那是在測試裡手動維持次序,不等於證明 production 接對了。本 story 要補上那一半。**

## 既有的接線點(已查證,2026-09-10)

| 檔案:行 | 現在做什麼 | 本 story 要加什麼 |
|---|---|---|
| `battle_controller.gd:149`(`_init()` 尾) | `tick_all_modifiers()` —— 第一個玩家回合不經轉換路徑 | 開局發牌 + 補牌?**見下方判斷題** |
| `battle_controller.gd:339`(`run_enemy_phase()` 尾) | `tick_all_modifiers()` | **緊接著** `draw_for_turn()` |
| `battle_controller.gd:606` | `clear_all_modifiers()`(戰鬥結束) | **緊接著** `return_all_to_pool()` |
| `battle_loop.gd:46`(`_init()` 尾) | `tick_all_modifiers()` | 同 controller |
| `battle_loop.gd:81`(轉回玩家方) | `tick_all_modifiers()` | **緊接著** `draw_for_turn()` |
| `battle_loop.gd:96`(戰鬥結束) | `clear_all_modifiers()` | **緊接著** `return_all_to_pool()` |

🔴 **判斷題(由你決定並說明理由)**:第一個玩家回合該「開局發 5 張」還是「發 5 張再補 1 張」?
GDD Core Rules 二 寫「開局手牌 5 張」+「每回合開始補 1 張」——
**兩句話對第一回合的合成結果是 5 還是 6,文件沒有明說。**
⚠️ **6 張會立刻觸發滿手強制棄牌**,亦即玩家第一個動作就是被迫棄牌。
**這很可能不是設計意圖,但我不裁決** —— 請選一個、說明理由,並在回報裡標為待管理者確認。

## 🔴 硬性約束:不得弄壞既有 516 條測試

現有測試建構 `BattleController` / `BattleLoop` 時**都沒有卡池**。
**卡池必須是選配的**(比照 `BattleState.attach_turn_order()` 的既有形狀),
沒有附卡池時所有卡牌相關呼叫為 no-op。

⚠️ **但這帶來一個必須正視的後果**:既有測試全部走 no-op 路徑,
**亦即接線本身完全沒有被既有測試覆蓋。** 新測試是唯一的覆蓋來源,**不能省。**

## 落點建議(可調整,說明理由即可)

卡池掛在 `BattleState`(比照 `TurnOrder` 的先例:2026-09-09 把它併進來的理由**逐字**是
「計數器必須與唯一寫入口同物件」「`BattleState` 是唯二被兩個驅動器都持有引用的物件」)。
🔴 **但這是我的建議不是裁決** —— 若你認為驅動器自己持有更合適,說明理由即可。

## 驗收條件

| # | GIVEN / WHEN / THEN |
|---|---|
| **AC-W1** | 附卡池的戰鬥開打 → 手牌為開局張數(見上方判斷題),卡池少掉對應張數 |
| **AC-W2** | 敵方回合結束、轉回玩家 → 手牌 +1 |
| **AC-W3** | 🔴 **順序契約**:單位身上有一個 `r=1` 的修正、且手牌已滿 → 玩家回合開始 → **在「等待棄牌」狀態為真的那一刻,該修正已經不在** `active_modifiers()` 裡。**這是本 story 存在的主要理由** |
| **AC-W4** | 戰鬥結束 → 手牌與已用區全部回到卡池,總張數與開局相同 |
| **AC-W5** | **敵方回合不補牌** —— 敵方回合中手牌張數不變 |
| **AC-W6** | **未附卡池**時,建構與整場戰鬥皆不崩潰,且行為與接線前逐字相同 |

🔴 **AC-W3 怎麼寫才不會是「永遠會通過」**:必須在**補牌之後、玩家做棄牌決定之前**
的那個時點取值。若測試在整個回合開始處理跑完之後才查,它驗不到順序 ——
**兩種順序在事後看起來是一樣的。** 請說明你怎麼取到那個中間時點。

## 測試

`tests/integration/gameplay/cards/card_battle_wiring_test.gd`(**獨立檔**)

**只跑你自己那一檔**(已實測 `-a <單一檔案>` 有效):
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/integration/gameplay/cards/card_battle_wiring_test.gd
```
⚠️ **路徑打錯會回報「找不到、無測試」然後 exit 0** —— 看 `Executed test cases` 條數。

**你改的是兩個驅動器,一定要跑全套確認沒弄壞既有的:**
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s tests/gdunit4_runner.gd
```
**基準 516 條 / 0 errors / 1 failures / 0 orphans / exit 100**,加上你新增的條數。
唯一容許的失敗是 `tests/unit/gameplay/affinity/affinity_phi_provider_test.gd`(刻意留紅,**勿動**)。

## 🔴 兩道提交閘門

①產品碼含 `INJECT`/`INJECTED FAULT`/`DO NOT COMMIT` → BLOCK;
②測試檔含函式名有 `test_` 但不以 `test_` 開頭 → BLOCK。

⚠️ **閘門只擋帶標記的注入。** 2026-09-10 有一位專家把 `delta_atk` 換成字面 `0` 證明 AC-5,
沒加標記,閘門完全沒反應 —— 而那個改法的後果是「所有攻擊加成牌一律無效」,
不崩潰不編譯失敗。**你的注入一律加大寫標記,那是你自己的保險**
(當天 10 次報告截斷有 3 次停在注入還活著的狀態)。

## 完成判準

1. 你那一檔全綠 + 全套無新增失敗
2. **敏感度證明**:🔴 **至少要證明 AC-W3** —— 把 `tick` 與 `draw` 的順序對調,AC-W3 必須轉紅。
   **那個對調是本 story 唯一真正危險的錯誤,它不會報錯。**
   其餘各條盡量,誠實列出沒證明的
3. 注入與改名全部還原,自己 grep 核對

## 不做

- 任何按鍵綁定 —— 🔴 `Esc`/手把 `B` 目前是玩家唯一能結束回合的手段,
  重綁必須與戰鬥選單同批上線(`skill-card-play.md` AC-U12 / `battle-menu.md` AC-M1)
- 任何畫面、節點、手牌顯示
- 卡表本體(GDD OQ-6 待定)—— 測試自建卡片即可
- 把 `CardPlaySession` 接到輸入上(那屬介面層)
