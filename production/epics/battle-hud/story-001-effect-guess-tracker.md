# Story 001:猜測判定與一致率追蹤器(純邏輯,零畫面)

> **Epic**: 戰鬥 HUD(僅預判標記)—— `production/epics/battle-hud/EPIC.md`
> **Status**: Ready
> **Layer**: Core(純 `RefCounted`,無節點)
> **Type**: Logic
> **Estimate**: S~M
> **規格權威**: `design/quick-specs/battle-hud-prediction-marker.md`(199 行)
> **開單依據**: 2026-10-16 管理者裁決「寫戰鬥 HUD 預判標記」+ 同日四項細部裁決
> (統計不持久化 / 只猜好感度 / 可跳過不計分 / 整場固定不可熱切換)。

## Context

本 story 做規格裡**完全不需要人眼驗收**的那一半。畫面與輸入是 story-002(尚未建立)。

🔴 **這個機制的意義全繫於一條規則**:**揭曉真實數值之前,玩家的猜測必須已經鎖死。**
沒有這一條,玩家可以「先隨便猜 → 看答案 → 改成對的 → 確認」,一致率恆為 100%,
而驗收協議 1 的 80% 門檻就量不到任何東西。**規格 AC8 就是這一條,它是本 story 的核心。**

## Acceptance Criteria(逐條對應規格第 6 節,編號沿用規格)

- [ ] **AC5 判定純函式**:`delta = +3 → POSITIVE` / `-2 → NEGATIVE` / `0 → NEUTRAL`。
      **無副作用純函式**,三分支皆有測試。
      📌 規格第 3 節逐字:`delta = preview - current`,來源是既有的
      `AffinityRules.bonus_for()`(current)與 `bonus_for_at()`(preview)。
      🔴 **本 story 不呼叫 `AffinityRules`** —— 它只接受一個已經算好的 `delta: int`。
      理由:純函式才測得乾淨,而把「誰去算 delta」留給 story-002 的呼叫端。
- [ ] **AC6 一格一次(鎖定語意的狀態機部分)**:同一次「移動選取過程」中,
      每一格只接受一次猜測。已鎖定的格子再次收到猜測輸入 → **不改變**已記錄的猜測。
      「取消選取 / 重新選取棋子」→ 整個過程重置,所有格子回到「尚未猜測」。
      ⚠️ **本 story 只做狀態機,不做顯示**(顯示是 story-002 的 AC6 那一半)。
- [ ] **AC7 只有「已鎖定猜測 + 已確認移動」才計分**:
      (a) 在格 A 鎖定後對**格 B** 確認移動 → 格 A **不計入**分母與分子。
      (b) 對格 A 確認移動但格 A **從未被猜過**(跳過)→ **不計入**分母與分子。
      **共同規則寫成一條,不要寫成兩套判斷。**
- [ ] 🔴 **AC8 不可灌水(本 story 最重要的一條)**:
      (a) 在格 A 猜「正」、實際為「負」→ 未取消選取時**無法改猜**;對格 A 確認移動,
          該筆記錄為**不符合**。
      (b) 已揭曉後移出格 A 再移回(未取消選取)→ **不得**重新開放猜測;
          此時確認移動,記錄仍為**不符合**。
      🔴 **這兩款各自要有獨立測試,不得合併成一條。**
- [ ] **AC9 一致率計算**:N 筆已計分記錄中 M 筆 `match == true` → 回傳值為 `M / N`。
      ⚠️ **N == 0 時的回傳值必須明文定義並測試**(規格沒有定義這一點 ——
      **你決定並寫進 doc comment,但不得用 `assert()` 守衛**,見下方陷阱 2)。
- [ ] **AC14 不持久化**:本類別**不得**出現在任何存檔讀寫路徑,**不得**新增存檔欄位。
      **做法**:寫一條**結構守衛測試**(讀 `src/` 原始碼文字,斷言存檔相關檔案沒有
      參照本類別),比照本專案既有的同類守衛先例。
      📌 `.claude/rules/test-standards.md` 乙類明文例外允許「讀 `src/**/*.gd` 原始碼
      文字以斷言靜態程式碼紀律」—— **但該測試檔頭必須依規則宣告這個例外**。

## Affected Files

**依 2026-10-12 管理者裁決,下列既有程式碼檔在本工作單明文範圍內,可直接改,不必先問。**

| 檔案 | 預期動作 |
|---|---|
| `src/ui/battle/effect_guess_tracker.gd` | 🔴 **新建(第一個動作就寫這個檔)** |
| `tests/unit/ui/effect_guess_tracker_test.gd` | 新建 |

⚠️ **落點建議而非規定**:`src/ui/battle/` 已有同類的純邏輯 helper
(`hud_layout.gd` / `world_layout.gd`)。**若你判斷有更符合既有慣例的落點,
先回報再改,不要自己搬。**

🔴 **`src/ui/battle/battle_screen.gd` 不在範圍內。** 本 story **不接線**到畫面 ——
接線是 story-002。需要改它才做得到的話,**停下來回報**。

## 🔴 四個已登記的陷阱

1. **`set_script()` 會把先前賦值的屬性清回宣告預設值** —— 若用到 mutant 子類別,
   `set_script()` 一律寫在任何屬性賦值**之前**。
2. 🔴 **絕對不要用 `assert()` 守衛「不可能到達」的分支,尤其在回傳 enum 的函式裡**
   —— 本專案實測:`assert()` 失敗會中止函式,而函式會產出**其回傳型別的序數 0**。
   若成功值排在第一個,**失敗的斷言會靜默回傳「成功」**。
   用 `push_error()` + 明確 `return` 一個刻意的非成功值。
   (全文見 `.claude/docs/coding-standards.md`。)
3. 🔴 **GdUnit4 在實際值為【空字串】時,失敗報告的 `Expecting` 與 `but was` 去色後逐字相同**
   —— 看到「兩個一樣的字串不相等」,先懷疑實際值是空的,不要追編碼。
4. **lambda 對 `int`/`bool` 是值捕捉** —— 計數要用單元素 `Array`。

## 交付與驗收

**只跑你自己那一支測試檔**(快,不會跟協調者的全套撞車):
```bash
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  -a tests/unit/ui/effect_guess_tracker_test.gd
```
⚠️ **務必檢查 `Executed test cases : (n/n)`** —— filter 打錯字會 exit 0、零條執行、看起來像通過。

**全套由協調者自己跑,不要重複。**
回報時貼 `Statistics:` 與 `Executed test cases : (n/n)` 原文,
並逐條寫明哪幾條 AC 你**實際看到它通過**。
