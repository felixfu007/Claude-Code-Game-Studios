# Story 018: 整場戰鬥端到端結算 —— 畫面側第一條防線

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md`
> **Status**: ✅ **Done(2026-10-16,協調者獨立重跑驗收)** —— 六條 AC 全部落地,`src/` **零改動**。全套 `ENGINE EXIT = 0` / `1268 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans` / `(107/107)` / `grep " FAILED"` 零命中 / `Parse Error` 零命中,六條逐條具名 PASSED。🔴 **本 story 最有價值的產出不是測試本身,是它揭穿的兩個陷阱**:①`set_script()` 會把先前賦值的 override 屬性清回預設 —— 順序顛倒會讓敏感度證明靜默測錯情境;②GdUnit4 在實際值為**空字串**時,失敗報告的 `Expecting` 與 `but was` 兩行**去色後逐字相同**(它用底色標缺字),足以把人導向完全錯誤的方向 —— 實測已發生一次。兩者皆已寫進測試檔註解。⚠️ **誠實登記**:AC-1「`battle_ended` 恰好發出一次」這個保證**沒有、也不可能有**留在本檔範圍內的敏感度證明(D 類,唯一注入點在 `battle_controller.gd`,不在本 story 授權範圍)。
> **Layer**: Presentation / Integration
> **Type**: Integration
> **Estimate**: M
> **開單依據**: 2026-10-16 管理者裁決 —— 選項逐字為「**先證明一場打得完(推薦)**」,
> 四個選項(證明打得完 / 寫戰鬥 HUD 預判標記 / 寫支援對話系統 / 清債與收尾)中選本案。
> 裁決在本日對話中做成;**本工作單是該裁決的執行契約,不是協調者的提議。**

## Context

### 🔴 這張工作單要關的洞,是一條當場可重跑的空結果

```
$ grep -n "battle_ended\|_on_battle_ended\|TEXT_RESULT_VICTORY" src/ui/battle/battle_screen.gd
168:const TEXT_RESULT_VICTORY: StringName = &"battle.hud.result_victory"
169:const TEXT_RESULT_DEFEAT: StringName = &"battle.hud.result_defeat"
1240:	_controller.battle_ended.connect(_on_battle_ended)
3907:func _on_battle_ended(outcome: BattleState.Outcome) -> void:

$ grep -rln "VICTORY\|outcome()\|TEXT_RESULT" tests/integration/ui/ tests/unit/ui/
(零命中)
```

**亦即:勝負結算在畫面這一側確實接好了(訊號已連、處理函式存在、文字鍵存在且 CSV 有值),
但全專案沒有任何一條測試走過它。**

⚠️ **「`battle_loop_test.gd` 已經測到 VICTORY」不能拿來充數。** 那條走的是
`BattleLoop`(純 `RefCounted`,無節點),**不經過 `BattleScreen`**。本專案已登記過
「真的類別 + 假的宿主」這個失效形狀(`technical-preferences.md` 第 5 點,2026-09-22
那支證據驅動器報 194 格違規、走真實管線複驗是 0)。**本 story 要的就是真實宿主鏈。**

### 現成可用的三樣東西(不要重新發明)

1. **真實場景載入的既有測試範本** ——
   `tests/integration/ui/battle/battle_screen_enemy_phase_playback_test.gd`(164 行)
   已經在做 `auto_free(load("res://src/ui/battle/BattleScreen.tscn").instantiate())`,
   並含兩個**常駐 mutant 子類別**的敏感度證明先例。**照抄它的結構。**
2. **資料注入點已經存在**:
   ```
   $ grep -n "_path_override" src/ui/battle/battle_screen.gd
   449:var terrain_path_override: String = ""
   453:var roster_path_override: String = ""
   463:var affinity_path_override: String = ""
   467:var cards_path_override: String = ""
   471:var card_text_path_override: String = ""
   ```
3. **「同時注入 terrain + roster 兩個路徑」已經走通過一次**(2026-09-23 第六十二批),
   夾具在 `assets/data/levels/test_fixture_terrain.txt` 與
   `assets/data/units/test_fixture_roster.txt`。⚠️ **那組夾具 `hp_max=999 / atk=1`,
   打不死人 —— 本 story 必須另外寫一組「一擊見勝負」的夾具。**

**GDD**: `design/gdd/tactical-combat-system.md` 的勝負條件(`BattleState.Outcome` 的
`## Three-state battle result. Victory requires every ENEMY unit dead.` 已逐字寫在
`src/gameplay/battle/battle_state.gd:18`)

**ADR Governing Implementation**: ADR-0001(戰棋查詢介面原子性契約,`Accepted`)——
本 story 只消費既有查詢與既有提交入口,**不新增任何 mutator**。

**Engine**: Godot 4.7.1 | **Risk**: MEDIUM(跨幀 + 真實場景 + 真實計時器)

## Acceptance Criteria

- [ ] **AC-1 勝利路徑**:載入真實 `BattleScreen.tscn`,注入合成夾具,由玩家側把敵方
      全部擊殺後,`_controller.outcome() == BattleState.Outcome.VICTORY`,
      且 `battle_ended` 訊號**恰好發出一次**。
- [ ] **AC-2 勝利的畫面後果**:同一條測試另行斷言 `_result_label.visible == true`
      且 `_result_label.text == Loc.localize(TEXT_RESULT_VICTORY)`(當前語系下為「勝利」)。
      🔴 **AC-1 與 AC-2 是兩件事**:訊號發出不等於畫面有變。兩個都要斷言。
- [ ] **AC-3 戰敗路徑**:另一組夾具(敵強我弱),由敵方 AI 把我方單位擊殺後,
      `outcome() == DEFEAT`,`_result_label.text == Loc.localize(TEXT_RESULT_DEFEAT)`。
      ⚠️ `battle_state.gd:778` 逐字寫 `victory: if any PLAYER unit has died, the result
      is DEFEAT even if every` —— **請先讀完那段 doc comment 再設計夾具**,DEFEAT 的
      成立條件可能比「我方全滅」寬鬆。
- [ ] **AC-4 開局不得誤報**:戰鬥尚未結束時 `_result_label.visible == false`
      且 `outcome() == ONGOING`。(防的是「結果標籤一開場就亮著」這種恆真通過。)
- [ ] **AC-5 敏感度證明**:AC-1/AC-2/AC-3 各自要有**常駐 mutant 子類別**證明它真的會紅。
      🔴 **不得用手動注入**(2026-09-16 管理者裁決已淘汰該手法,`.claude/rules/test-standards.md`,
      理由是它在版本庫裡不留痕跡)。範本見
      `battle_screen_enemy_phase_playback_test.gd` 的 `_MutantSynchronousEnemyPhase`
      與 `_MutantSkipsPhaseGuard`。
- [ ] **AC-6 檔案 I/O 揭露**:新測試檔檔頭必須比照
      `battle_screen_enemy_phase_playback_test.gd` 的既有寫法,逐字宣告它屬於
      `.claude/rules/test-standards.md` 的哪一類明文例外,並宣告它證明不了什麼。

## Affected Files(🔴 本節就是 2026-10-12 管理者裁決所稱的「工作單明文範圍」)

**依該裁決:下列【既有程式碼檔】在本工作單範圍內,實作者可直接修改,不必先問。**
**超出本清單的程式碼檔、以及任何文件檔,仍須先問。**

| 檔案 | 預期動作 |
|---|---|
| `tests/integration/ui/battle/battle_screen_battle_outcome_test.gd` | 🔴 **新建(第一個動作就寫這個檔)** |
| `assets/data/levels/test_fixture_terrain_duel.txt` | 新建(合成地形,1v1 用) |
| `assets/data/units/test_fixture_roster_duel.txt` | 新建(我強敵弱,一擊見勝負) |
| `assets/data/units/test_fixture_roster_doomed.txt` | 新建(敵強我弱,供 AC-3) |
| `src/ui/battle/battle_screen.gd` | **僅在必要時**:若測試無法觀察結果狀態,可新增 `diagnostic_*` 唯讀 getter。**不得改動任何既有行為。** |

⚠️ **若發現必須改動既有行為才能讓測試通過,那就是真的抓到 bug 了 —— 停下來回報,
不要自行修改遊戲邏輯。** 本 story 的價值在於「它可能會紅」,把它改綠不是目的。

## 🔴 五個會咬人的陷阱(不先寫下來,每個照做的人都會各撞一次)

1. **資料注入只有一個時機窗:`instantiate()` 之後、`add_child()` 之前。**
   `_ready()` 只讀一次,而 `_ready()` 要進樹才跑。
2. **在 `_ready()` 裡直接 `add_child()` 會被引擎當場拒絕**(`Parent node is busy
   setting up children`)。測試裡用 `auto_free(...)` + `add_child()` 是既有範本的做法,
   照抄即可;**不要自己組替身節點鏈**。
3. **兩份夾具必須彼此相容。** 2026-09-24 踩過一次:roster 的 ENEMY 起點 `(12,5)` 落在
   `5×3` 地形夾具描述的範圍之外,**不會報錯,只會量出一個不存在的棋盤的答案**。
   `assets/data/units/test_fixture_roster.txt` 的檔頭有那次的逐字記錄,**先讀它**。
4. **敵方階段有真實計時器暫停**(`ENEMY_STEP_PAUSE_SECONDS = 0.3` 秒),涉及敵方回合的
   測試會花真實秒數。**這是代價不是缺陷**,不要為了快而繞過真實播放路徑。
5. **一條測試失敗會中止它所在 suite 的剩餘測試。** 所以 AC-5 的三個 mutant
   **各自要能單獨證明**,不能靠「跑一次全紅」充數 —— 證明一條測試敏感,代價是一次執行。

## 交付與驗收

🔴 **本機跑測試一律用**:
```bash
GODOT_BIN="C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  bash tools/build/run_tests_with_import.sh
```
**舊的兩段式指令會騙你**(2026-10-15 登記的第六種假綠燈:CSV 改了沒重新匯入,
測試讀到舊快取,協調者的獨立重跑照樣報 0 failures)。

🔴 **交付回報必須貼出引擎自己的原始三行,不是只說「測試通過」**:
`ENGINE EXIT = ?` / `Overall Summary: ...` / `Executed test suites: (n/n)`。

⚠️ **先看 `ENGINE EXIT`,再 grep log。** exit 105 代表測試收集階段就炸了、一條都沒跑,
而 `grep "Overall Summary"` 與 `grep " FAILED"` **兩個都會回空,看起來跟乾淨通過一模一樣**。

**協調者一律自行重跑複驗,不採信回報。**
