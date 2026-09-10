# Story 007:強制棄牌的阻塞閘門

> **Epic**:技能卡牌系統
> **型別**:Integration(**BLOCKING**)
> **狀態**:📋 Ready
> **估時**:M
> **依賴**:006(已完成)

## 🔴 這張工作單的來源是 2026-09-10 管理者裁決,逐字如下

> **新增檢查機制:玩家因為獲得新手牌而造成手牌上限時,啟動棄牌流程,系統必須詢問玩家
> 要捨棄哪一張牌,玩家選擇後,系統棄掉該張牌,接著玩家才能動作。
> 如果玩家沒有執行棄牌行為,則一直等待玩家選擇好棄牌為止。**

**它推翻的是一個問法,不只是一個實作。** Story 006 留下一道守衛:上一回合的棄牌沒解決,
這一回合就**靜默不補牌**。當時的問題被寫成「棄牌沒解決時該怎麼辦」——
**管理者的答案是:它不可能沒解決,因為回合會一直等。**

⚠️ **Story 006 的實作者自己就標記了那道守衛是「防禦性直覺,不是查證過的判斷」**,
並誠實寫下「我自己選的方案,犯了我讀過的規則要防的那種錯」(指 `coding-standards.md`
關於「靜默吞掉」的整節)。**本 story 就是把它換掉。**

## 要做什麼

**補牌後手牌超過上限 → 玩家在棄掉一張之前,不能做任何動作。**

| 目前 | 改成 |
|---|---|
| `BattleState.begin_player_turn()` 帶 `not has_pending_discard()` 條件,**跳過補牌** | **無條件補牌**(滿手時就是撐到 6,那是 GDD 明訂的) |
| 沒有任何東西阻止玩家在欠棄牌時行動 | **欠棄牌時,所有玩家動作一律被拒且拒絕可觀測** |

🔴 **移除那道守衛是本 story 的一部分,不是副作用。** 它存在的唯一理由是防止
`CardDeck.draw_for_turn()` 的 `assert` 爆掉 —— 而有了阻塞之後,**那個狀態進不來了**。

## 要擋哪些動作(`BattleController`)

`select_unit()`、`click_tile()`、`end_unit_turn()`、`end_faction_phase()`
—— **凡是會改變盤面或推進回合的,一律擋。**

⚠️ **唯讀查詢不擋**(`phase()`、`selectable_units()`、`move_targets()`、`threat_targets()` 等)
—— 介面要能畫出盤面才能讓玩家看清楚再決定棄哪張。**擋的是動作,不是視野。**

🔴 **拒絕必須可觀測,不得靜默 no-op。** 比照專案既有慣例(`coding-standards.md`
與 ADR-0002 的錯誤處理哲學:GDScript 無 try/catch,錯誤一律以回傳值表達)。
`click_tile()` 已回傳 `Dictionary`,建議加一個明確的 `action` 值
(例 `&"blocked_pending_discard"`),**不要沿用 `&"none"`** ——
`&"none"` 現在代表「點到空地」,兩者混在一起,介面就分不出「按了沒反應」與「這裡沒東西」。
**而「看起來能按、按下去沒反應」正是本專案登記過最糟的方向。**

## 🔴 `BattleLoop` 沒有玩家,而它會因此卡死 —— 這是本 story 最需要判斷的一處

`BattleLoop` 是自動對打模擬(用於數值平衡量測),**兩邊都由 `decide` 驅動,沒有人類玩家**。
阻塞一旦生效,**它會在第一次滿手時永遠等下去** —— 而它有 `max_rounds` 安全閥,
所以實際結果是「每一場模擬都在那裡耗到回合上限」,**不是崩潰,是靜默失去量測價值。**

⚠️ **「系統不代為決定」是 GDD 對玩家的規則。模擬harness 裡沒有玩家,所以必須有人決定。**

**協調者的建議做法(非裁決,你可推翻但要說明理由)**:
給 `BattleLoop._init()` 一個**選配**的 `discard_policy: Callable`(預設空)。
- 有提供 → 由它挑一張棄掉,模擬繼續
- **沒提供且真的欠棄牌 → `run()` 立刻回傳,`aborted = true`,並在結果裡帶一個
  明確的原因欄位**(例 `"abort_reason": "forced_discard_unresolved"`)

**理由**:不崩潰、不卡死、不靜默 —— 三者都避開了。而且 `run()` 的回傳 `Dictionary`
**已經有 `aborted` 欄位**,不是新概念。
🔴 **不得讓 `BattleLoop` 自己隨便棄一張** —— 那會讓模擬結果取決於一個沒人裁決過的策略,
而本專案用這個模擬在驗數值平衡。**一個沒人知道的策略會污染平衡結論。**

## 驗收條件

| # | GIVEN / WHEN / THEN |
|---|---|
| **AC-D1** | 手牌已滿、玩家回合開始 → 補牌後手牌為 6,且「欠棄牌」為真 |
| **AC-D2** | 欠棄牌時 → `select_unit()` / `click_tile()` / `end_unit_turn()` / `end_faction_phase()` **全部被拒**,且**拒絕可觀測**(非 `&"none"`) |
| **AC-D3** | 欠棄牌時 → 盤面**逐字未變**(單位位置、HP、行動旗標、回合數皆與補牌後相同) |
| **AC-D4** | 玩家棄掉一張 → 手牌回到 5、「欠棄牌」為假 → **上述四個動作全部恢復可用** |
| **AC-D5** | 🔴 **唯讀查詢在欠棄牌期間仍正常**(`selectable_units()`、`move_targets()` 等回傳與補牌後相同的內容)—— 介面要能讓玩家看清楚再決定 |
| **AC-D6** | 未附卡池的戰鬥 → 行為與 Story 006 之後逐字相同(閘門永不觸發) |
| **AC-D7** | `BattleLoop` 未提供棄牌策略且欠棄牌 → `run()` 回傳 `aborted = true` 與明確原因,**不卡到回合上限、不崩潰** |
| **AC-D8** | `BattleLoop` 提供棄牌策略 → 模擬正常跑完,棄掉的是策略選的那一張 |

🔴 **AC-D3 是本 story 最容易寫成「永遠會通過」的一條** —— 若測試在欠棄牌期間
只呼叫了被擋的動作、然後斷言盤面沒變,那它同時也會在「動作根本沒被實作」的情況下通過。
**必須先在不欠棄牌的情況下證明同一個動作確實會改變盤面**(正面控制組),
**再證明欠棄牌時它不會。** 兩者缺一,訊號強度打折。

## 測試

`tests/integration/gameplay/cards/card_forced_discard_gate_test.gd`(**獨立檔**)

只跑自己那一檔(已實測 `-a <單一檔案>` 有效):
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/integration/gameplay/cards/card_forced_discard_gate_test.gd
```
⚠️ **路徑打錯會回報「找不到、無測試」然後 exit 0** —— 看 `Executed test cases` 條數。

**你改的是兩個驅動器 + `BattleState`,務必跑全套:**
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s tests/gdunit4_runner.gd
```
**基準 532 條 / 0 errors / 1 failures / 0 orphans / exit 100** + 你新增的。
唯一容許失敗是 `tests/unit/gameplay/affinity/affinity_phi_provider_test.gd`(刻意留紅,**勿動**)。

⚠️ **移除那道守衛很可能弄紅 Story 006 的既有測試** —— 那是**預期的**,
因為它們斷言的是舊行為。**改它們是本 story 的工作,但要逐條說明改了什麼、為什麼。**
🔴 **不得為了讓測試變綠而放寬斷言** —— 若某條測試的舊斷言與新裁決衝突,
說明衝突在哪,改成驗新行為,不要只是刪掉。

## 完成判準

1. 你那一檔全綠 + 全套無非預期失敗
2. **敏感度證明**:🔴 至少涵蓋 **AC-D2 與 AC-D3** —— 把閘門拿掉,兩者必須轉紅。
   **注入一律加大寫標記**(`# INJECT_xxx`)。
   ⚠️ 一次注入只證明第一條被撞到的斷言;要證明後面的,把前面的 `test_` 暫時改名,**跑完務必改回**
3. 注入與改名全部還原,自己 grep 核對

## 不做

- 任何按鍵綁定、任何畫面 —— 🔴 `Esc`/手把 `B` 目前是玩家唯一能結束回合的手段,
  重綁必須與戰鬥選單同批上線
- 「詢問玩家棄哪一張」的**介面** —— 本 story 只做**邏輯層的阻塞與可觀測狀態**,
  讓介面之後能照著畫。**裁決的「系統必須詢問玩家」那一句,邏輯層的兌現方式就是
  「欠棄牌狀態可查詢 + 動作被拒 + 玩家指定哪一張的入口存在」**
- 把 `CardPlaySession` 接到輸入上(仍屬介面層,且它目前仍是零呼叫點)
