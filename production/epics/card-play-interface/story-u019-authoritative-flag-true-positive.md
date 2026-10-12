# Story U-019:`AC-U8` / `AC-M8` 真陽性測試 —— 用真的旗標,不用替身

> **Epic**:卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **型別**:Integration
> **狀態**:📋 **Ready**(2026-10-12 管理者裁決切出)
> **估時**:S
> **依賴**:無前置。**不阻擋任何 story。**
> **擁有者**:未指派 —— 動工前依 `.claude/docs/coordination-rules.md` 路由

---

## 🔴 為什麼現在才有這張 story(前提在 2026-10-12 當天才成立)

`EPIC.md` 限制表第 1 列逐字寫著:

> 「**`authoritative_write_in_progress` 旗標不存在** —— 在 `src/` 裡它只是一句註解。
>   **AC-U8 / AC-M8 只能驗「閘門有接」,不能驗「旗標會變真」**,亦即今天構造不出真陽性」
> 「誰能解」欄:**#4 戰棋(ADR-0001 機制一)**

**2026-10-12 那一欄寫的事情發生了。** `story-003b` / `003c` / `017` 把寫入守衛與提交入口做出來,
加上 ADR-0001 的深度計數器語意,那個旗標現在是真的。當場查(⚠️ **用符號名,不要用行號**):

```bash
grep -n "^var authoritative_write_in_progress" src/gameplay/battle/battle_state.gd
```

🔴 **本 story 是那個限制的對應處置。排不進去,那兩條 BLOCKING 級 AC 就永遠停在「部分涵蓋」。**

---

## 現況:缺口的精確形狀(協調者 2026-10-12 實測)

**不是「沒有測試」,是「測試餵的是替身」。** 現有四處注入點:

```
$ grep -rn "authoritative_write_in_progress_check" tests/ --include=*.gd
tests/integration/ui/forced_discard_test.gd:291
tests/integration/ui/menu/battle_menu_gating_test.gd:328(註解)、:355、:397
tests/integration/ui/menu/battle_menu_leave_confirmation_test.gd:559(註解)
```

而它們餵進去的東西逐字是:

```gdscript
instance.authoritative_write_in_progress_check = func() -> bool: return true
```

**一個恆回 `true` 的 lambda。** 它證明的是「閘門接上了、而且會拒絕」,
**沒有證明「真的旗標在真的權威寫入期間會變真」** —— 那兩件事中間隔著整個 `BattleState`。

📌 **框架已經搭好了,本 story 不是從零開始** —— 注入點、拒絕外觀、OpenResult 列舉全都在,
要換的只是「餵什麼進去」。

---

## Acceptance Criteria

- [ ] **AC-1**:新增至少一條整合測試,**用真實的 `BattleState` 驅動真實的旗標**,
      而非恆回 `true` 的 lambda。做法建議(非強制):
      ```gdscript
      menu.authoritative_write_in_progress_check = func() -> bool:
          return state.authoritative_write_in_progress
      state.commit_authoritative_change(func() -> void:
          # 窗口開著的此刻,選單必須拒絕開啟
          var result: BattleMenu.OpenResult = menu.open()
          # 斷言 result 為拒絕
      )
      ```
      🔴 **關鍵在於斷言寫在 `commit_authoritative_change()` 的 mutator 內部** ——
      那是旗標唯一會是 `true` 的時刻。寫在外面會量到 `false`,**而且測試會通過**
      (因為選單確實開得起來),變成一條永遠綠、什麼都沒驗的測試。
- [ ] **AC-2**:同一條或另一條測試斷言**窗口關閉之後選單開得起來** ——
      證明拒絕是因為窗口,不是因為選單壞了。
- [ ] **AC-3**:**既有那四處用替身的測試一律不改、不刪。**
      它們驗的是「閘門有接」,與本 story 驗的「旗標會變真」是兩件事,兩者並存。
- [ ] **AC-4**:至少一條 `test_sensitivity_proof_*`,或逐條寫下可查證的「為什麼證明不了」
      並歸入 `.claude/rules/test-standards.md` 的五類之一。
- [ ] **AC-5**:更新三處既有登記,讓它們指向本 story 的結果(**原文零刪除,只加註**):
      `EPIC.md` 限制表第 1 列之後的註記、`story-u008` 的 `AC-M8` 註記、
      以及 `AC-U8` 所在的工作單(動工前先 `grep -rn "AC-U8" production/epics/` 確認是哪一張)。

---

## 🔴 四個必踩的坑(本專案實測,不照做一定出事)

1. **絕不用 `assert()` 守衛分支**(2026-09-15 實測:失敗會中止呼叫端並產出回傳型別的
   **ordinal 0** —— 慣例上成功值排第一,等於**斷言失敗反而回傳「成功」**)。
   ⚠️ **本 story 特別危險**,因為 `BattleMenu.OpenResult` 就是一個 enum。
2. 🔴 **先看引擎自己的 exit code,再 grep log。** `{0, 100, 101, 103}` 以外(特別是 **105**)
   代表測試收集階段就炸了、**一條都沒跑**,而此時 `grep "Overall Summary"` 與 `grep " FAILED"`
   **兩個都回空,看起來跟乾淨通過一模一樣**。
3. **`Overall Summary` 的 `failures` 算的是失敗【斷言】數,不是失敗測試數。** 數具名 ` FAILED`。
4. ⚠️ **一條測試失敗會中止它所在 suite 的剩餘測試。**「1 failure」從不代表「只壞一件事」。

---

## 測試指令

```
"<Godot 4.7.1 執行檔完整路徑>" --headless --path . -s tests/gdunit4_runner.gd ; echo "ENGINE EXIT = $?"
```
`godot` **不在本機 PATH 上,而且失敗是安靜的**(接 grep 會變成約一秒的空結果,跟全綠一樣)。
機器專屬路徑見 `.claude/docs/coding-standards.md` 的 CI 指令列。

**基線(2026-10-12 收工時)**:`1127 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans`、`EXIT 100`。
⚠️ 唯一具名 FAILED 是既有**刻意紅且已核准**的
`tests/unit/gameplay/affinity/affinity_phi_provider_test.gd > test_phi_reflects_a_pairing_polarity_flip_made_after_construction`。**不要修它。**

---

## Test Evidence

**Story Type**:Integration → **BLOCKING** 級(`coding-standards.md` 測試證據表)
**Required evidence**:整合測試存在且通過,且**測試內確實呼叫了真實的
`BattleState.commit_authoritative_change()`**,不是餵替身 lambda。
⚠️ **驗收者請直接讀測試本體確認這一點** —— 「測試是綠的」無法區分真陽性與替身。

---

## Out of Scope

- **不改既有那四處替身測試**(見 AC-3)。
- **不碰 `AC-M16` / 強制棄牌的拒絕情境** —— 那屬 U-015。
- **不改 `BattleMenu` 的拒絕外觀設計** —— 已於 U-008 定案。
