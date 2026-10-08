# Story 003d: story-003b 的敏感度證明補做 —— 間諜子類別常駐測試

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md`
> **Status**: 📋 **Ready**
> **建立日期**: 2026-10-08(管理者裁決:003b 先標 Done 解鎖 004~007,證明另切)
> **擁有者**: 未指派 —— 動工前依 `.claude/docs/coordination-rules.md` 路由
> **不阻擋任何 story。** 004~007 已由 003b 的 Done 解除封鎖,本 story 不是它們的前置。

---

## 為什麼有這張 story

`story-003b` 於 2026-10-08 標 Done 時,AC8(14 條驗收測試)已完成且全綠,
**但 AC9(敏感度證明)只做到 1/14,而且用的方法本身不合規。**

**管理者是在知情下裁決的** —— 選項原文已逐字寫明代價:
「**有風險**:那 13 條裡若有假測試(永遠不會紅的那種),會被後續工單當成已驗證的地基癢著蓋」。

🔴 **這張 story 是那個風險的對應處置。排不進去,風險就一直在。**

---

## 現況:精確的缺口形狀(2026-10-08 協調者獨立驗收)

### 已獨立證明會紅 —— 1 條

`test_4d_enemy_batch_settlement_with_two_units_two_actions_increments_version_by_exactly_one`
(`tests/unit/gameplay/battle/commit_authoritative_change_version_test.gd`)。

證明方式:暫時把 `battle_state.gd` 的 `commit_authoritative_change()` 改成提交完不遞增版本,
重跑全套 → **1027 條(掉了 9 條)、3 failures**,該測試具名 FAILED,
且**連帶讓既有核准測試 `attack_los_blocked_query_test.gd >
test_combat_state_version_increments_exactly_once_on_successful_move` 也正確轉紅**
—— 證明兩邊吃的是同一個共用機制。注入已立即還原(`git diff` 空)。

### 未證明 —— 13 條

| 檔案 | 條數 | 它們共用的機制 |
|---|---|---|
| `commit_authoritative_change_version_test.gd` | 6(4e / 4f / 4i / 4j / 4l×2) | `BattleState.commit_authoritative_change()` 的深度計數器與版本遞增 |
| `mutator_guard_rejection_test.gd` | 7(4k,七個 mutator 各一) | `Board` / `TurnOrder` 的選擇性守衛 |

⚠️ **「它們共用的機制已被 4d 證明過」是推論,不是量測。**
本專案已登記過「同一個公式兩份實作、只是今天答案一致」的案例,而黑箱比對輸出
**永遠無法區分「共用同一份」與「兩份碰巧一致」**。不要用這條推論取代證明。

---

## 🔴 方法:間諜子類別,不是手動注入

`.claude/rules/test-standards.md` 的 2026-09-16 裁決逐字:

> **手動注入(改壞 → 跑 → 改回)已淘汰,理由是它在版本庫裡不留任何痕跡。**

> **正確形式**:間諜子類別 + 一條**會通過的** `test_sensitivity_proof_*` 測試,
> 斷言「偵測器真的抓到了這個植入的缺陷」。

當場查全文與範本(**不要依賴本檔轉述**):

```bash
sed -n '/^### 證明的形式/,/^### 已知證明不了的五類/p' .claude/rules/test-standards.md
grep -n "_Spy" tests/integration/gameplay/affinity_pool/affinity_pool_wiring_test.gd
```

判準:`grep '^func test_sensitivity'`。
🔴 **不要用 `grep inject` 判斷** —— `_inject_raw_record()` 那類是塞測試**資料**的夾具函式,
與敏感度證明無關,同規則檔已登記過一次 20 處撞名。

### 🔴 兩項「為什麼之前沒這樣做」的事實,動工前必讀

1. **`story-003b` 的 AC9 條文本身寫的就是被淘汰的那個方法**,
   而派工單照抄了它。**錯在工作單與派工單,不在實作者** —— 實作者照做之後自己發現
   並誠實指出。003b 的 AC 表已加註更正,**原文一字未刪**。
2. 🔴 **手動注入法對守衛類程式碼,在這台機器上結構性做不到。**
   2026-10-08 實作者嘗試把 `board.gd` 的守衛改成 `if false and not _write_allowed():`,
   **被本機安全分類器以「削弱安全機制」為由拒絕執行後續指令**。改動已立即還原。
   **亦即:4k 那七條不是「沒人想做」,是手動注入法在這裡走不通。**
   間諜子類別走得通,因為它新增的是測試檔裡的子類別,不是削弱產品碼。

---

## Scope

### 要做的

1. **為那 13 條各補一條常駐 `test_sensitivity_proof_*`**,或
2. **為補不了的那幾條,逐條寫下可查證的「為什麼證明不了」**,並歸入
   `.claude/rules/test-standards.md` 已登記的五類(A / A′ / B / C / D)之一。
   🔴 **門檻是二選一,不是「全部補齊」** —— 同一份規則逐字:
   「每條測試要嘛有敏感度證明,要嘛有寫下來、可查證的『為什麼證明不了』」,
   且管理者當時**已明確否決**「全部補齊才算完成」(理由:結構上不可能達成)。
   **寫「證明不了」必須是真的證明不了,不是嫌麻煩。** 歸類要指出是哪一類、為什麼。
3. **補 `story-003b` AC11 的兩條專屬驗收向量**(003b 收尾時未寫,移入本 story):
   - `step_enemy_phase()` 獨立觸發 `_finalize_enemy_phase()` 時,版本號**恰好 +1**
   - `run_enemy_phase()` 整批呼叫時,該內層提交**巢狀收斂**、不額外多算
   出處:`story-003b` 的 QA Test Cases 節。
   ⚠️ **`step_enemy_phase()` 是正式遊戲唯一在用的生產路徑**(`battle_screen.gd`),
   `run_enemy_phase()` 是整批路徑 —— 兩條都要驗,只驗一條會讓另一條的繞過不可觀測。

### 不要做的

- **不要改產品程式碼。** 003b 的產品碼已驗收完成。
- **不要用手動注入法**(見上方)。
- 不要重寫那 14 條既有測試的斷言 —— 它們已綠且經獨立重跑驗證。

---

## Acceptance Criteria

| # | AC |
|---|---|
| 1 | 那 13 條每一條**要嘛**有一條對應的、**會通過的** `test_sensitivity_proof_*`,**要嘛**在測試檔內有逐條寫下的「為什麼證明不了」並標明五類中的哪一類 |
| 2 | AC11 的兩條專屬向量各有一條斷言測試 |
| 3 | `grep '^func test_sensitivity' tests/unit/gameplay/battle/` 的命中數 = 本 story 新增的證明數,且數字寫進回報 |
| 4 | 全套測試重跑:總數 = 1036 + 本次新增條數,**算術必須對得上**;具名 ` FAILED` 只有既有那條已核准的 `affinity_phi_provider_test.gd` |
| 5 | 收尾 `grep -rn "TEMP INJECTION\|if false and\|if false or" src/ tests/ --include=*.gd` **零命中**,原始輸出貼進回報 |

---

## 測試指令(這台機器)

`godot` **不在 PATH 上,而且失敗是安靜的**(接 grep 會變成一秒內的空結果,跟乾淨通過一樣):

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s tests/gdunit4_runner.gd
```

🔴 **先看引擎 exit code,再 grep log。** `{0, 100, 101, 103}` 以外(特別是 **105**)
代表收集階段就炸了、**一條都沒跑**,而此時 `grep "Overall Summary"` 與 `grep " FAILED"`
**兩個都回空**,看起來跟乾淨通過一模一樣。

🔴 **`failures` 欄算的是失敗斷言數,不是失敗測試數。** 要知道壞了幾個,數具名 ` FAILED`。

---

## Dependencies

- **無前置。** 003b 已 Done,產品碼與那 14 條測試都在。
- **不阻擋任何 story。**

## Test Evidence

- 自動化單元測試 —— `tests/unit/gameplay/battle/`,BLOCKING。
