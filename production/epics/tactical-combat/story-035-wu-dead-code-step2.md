# Story 035:戊舊機制死碼清理第二步(`lone_guard_effective` / `will_attack` / `attacked_this_phase`)

> **Status**: Ready
> **Type**: Logic(重構,零行為變更)
> **Epic**: tactical-combat
> **擁有者**: lead-programmer 派 `gameplay-programmer`(src/ 與 tests/)、`tools-programmer` 或同一人(prototypes v4)
> **依據**:管理者 2026-11-05 裁決(逐字)「結案,但工具留著當安全檢查(推薦)」—— 協議 2(停損考試)正式結案,戊舊機制死碼第二步可清;協議 2 量測工具必須繼續能跑,當回歸檢查用。
> **來源盤點**:`docs/reviews/wu-dead-code-audit-2026-11-03.md`(方案 C 步驟二)。步驟一已於 `95559b2` 完成。

## 一句話目標

把已經不影響任何結果的三個符號從 `src/` 與 `tests/` 清掉,**遊戲行為一個字不變**;同時讓協議 2 量測工具有一份不依賴死碼的新版(v4),證明清理前後輸出逐行相同。

## 與盤點檔不一致之處(協調者與實作者先讀)

盤點寫於步驟一**之前**,以下已過期,**一律以現場 grep 為準,不要照盤點的行號或條數**:

1. **行號全部漂移。** 現值(2026-11-05 當場查):`battle_state.gd` 的 `_attacked_this_phase` 寫入在 556、宣告 773、讀取函式 778、`lone_guard_if_at` 789/794、清除 921;`combat_rules.gd:70`;`battle_screen.gd` 的 `_displayed_guard_at` 簽名在 2948-2951、唯一呼叫點在 4971。
2. **`battle_screen.gd` 呼叫點從 4 處變 1 處**(步驟一已刪雙值三連呼)。`format_guard_move_dual` 與字串鍵 `guard_move_dual_format` 已不存在(grep 零命中)。
3. **盤點提到 5 支協議 2 腳本會壞,實際 prototypes 命中 8 檔 / 6 個資料夾**(見下方「prototypes 處置」)。多出的是 11-03 之後新增的 `difficulty-ai-formation-2026-11-03`、`difficulty-ai-retreat-2026-11-03`、`vs03-defeat-diagnosis-2026-11-03`。
4. **prototypes 命中有兩種形狀**:多數是 `s.lone_guard_if_at(id, t, will_attack)` 三參數呼叫加一個**區域變數** `will_attack`(語法上會因簽名改變而壞);另有 2 支 `protocol2_runner_traced.gd` 呼叫 `s.attacked_this_phase(tg)`(函式刪除後執行期錯誤)。
5. 盤點「測試約 -15 條」過期:步驟一已刪 3 條,現估見下方 Affected Files。**實際條數以引擎全套輸出為準。**
6. 盤點第 6 項「6 keys 陳舊註解」本工單**不處理**(步驟一範圍,若仍在請實作者 grep 後另報,不擴大範圍)。

## prototypes 處置

### 1. 正式量測工具:新增 v4(新檔,直接建)

- 新增 `prototypes/protocol2-computer-measure-v4/`,**複製** `prototypes/protocol2-computer-measure-v3/` 的 `README.md`、`p2_decision.gd`、`protocol2_runner.gd`、`guard_check.gd`(不複製 `.uid`、`*_output.txt`,由引擎重生 / 由本工單新產)。
- **只改兩類東西**,其餘一字不動:
  - `p2_decision.gd`:刪區域變數 `will_attack`(v3 第 97、110 行的宣告與賦值)並把 `s.lone_guard_if_at(id, t, will_attack)`(v3 第 121 行)改成 `s.lone_guard_if_at(id, t)`。這與現行 API 行為等價,因為 `will_attack` 在 `lone_guard_if_at` 內被忽略。
  - `protocol2_runner.gd`:第 14 行 `preload` 路徑改指 v4 的 `p2_decision.gd`;HEADER 的 `tool=` 字串(v3 第 57 行)改 `protocol2-computer-measure-v4`。⚠️ HEADER 這行會讓輸出與 v3 不同 —— 比對時按 `tuning-refactor-equivalence-2026-11-04/README.md` 的前例**去掉 HEADER 與引擎標頭行**再 diff(該前例同樣這樣處理)。
  - `guard_check.gd` 若有 `preload`/路徑指向 v3 也一併改;若它不含死碼符號,只改路徑。
  - README 開頭加一行:「自 v3 複製;唯一差異是移除對已刪除的 `will_attack` 參數的呼叫(行為等價),見 story-035。」
- **v3 原封不動**(含 README),當歷史紀錄。
- 資料夾內不得放 `will_attack` / `attacked_this_phase` / `lone_guard_effective` 任何形式的字樣(含註解 —— 註解會讓驗收 grep 自我命中,見下方驗收 4)。上面那句 README 說明請寫成「已移除的三參數呼叫」,不要出現符號名。

### 等價證明(本工單的核心物證)

**跑哪一組**:vs01 協議 2 那組、16 局 —— `--level=1 --r2=yes`。**v3 的執行指令從這裡查**:`prototypes/tuning-refactor-equivalence-2026-11-04/README.md` 最末「執行」行:

```
<godot> --headless --path . -s res://prototypes/protocol2-computer-measure-v3/protocol2_runner.gd -- --level=1 --r2=yes
```

(`<godot>` 用本機引擎完整路徑,見 `.claude/docs/coding-standards.md` CI 節;v4 同指令把路徑中的 v3 換成 v4。)基準輸出可對照 `prototypes/tuning-refactor-equivalence-2026-11-04/run93_p2_after.txt` 的形狀:`RESULT` 16 行、`DONE 1`、`FATAL 0`、約 21 行。

**三次跑,同一組參數**(每次先 `--import`;**乾淨 worktree 做 A、B,避免汙染主工作目錄**,前例做法):

| 代號 | commit | 工具 | 輸出檔(放 `prototypes/protocol2-computer-measure-v4/`) |
|---|---|---|---|
| A | **清理前**(本工單實作之前的 HEAD) | v3 | `run_v3_before.txt` |
| B | **清理前**(同一個 HEAD,v4 資料夾需先存在) | v4 | `run_v4_before.txt` |
| C | **清理後**(本工單 src/ 清理完成的 commit) | v4 | `run_v4_after.txt` |

- **要求**:A 與 B 去掉 HEADER/引擎標頭後 `diff` 為空;**B 與 C 也為空**(因此 A=B=C,即 v4 在死碼清除前後行為皆與 v3(清理前)逐行相同)。
- 每次都貼 `ENGINE EXIT`、`RESULT` 行數、`DONE`、`FATAL`、`diff` 的原始輸出;**「diff 為空」要貼出 `diff ... ; echo "diff exit=$?"` 的原文**。
- 🔴 **去標頭的過濾法要事前寫進輸出檔頂端或 README**,而且過濾後兩邊**行數必須相等且大於 0** —— 兩邊都空,diff 也是空(本專案登記過的空結果假綠)。請貼 `wc -l` 原文。
- ⚠️ B 要在「v4 存在、死碼仍在」的 commit 上跑,所以**實作順序**:先 commit v4 資料夾(此時 src/ 還有死碼)→ 跑 A、B → 再做 src/ 清理 → 跑 C。實作者**不得 commit**(專案規則),由協調者依序提交或實作者在乾淨 worktree 以 `git stash`/暫存方式取得 B 的條件;不確定就停下問。

### 2. 其餘 7 支診斷/難度腳本:**不改**,在各自 README 末尾加一行

命中清單(當場查:`grep -rln "lone_guard_effective\|attacked_this_phase\|will_attack" prototypes --include=*.gd`,不含 v3 與 v4):

| 資料夾 | 命中檔 | 形狀 |
|---|---|---|
| `protocol2-diagnosis-attempt3-2026-10-30` | `p2_decision.gd`、`protocol2_runner_traced.gd` | 三參數呼叫 + `attacked_this_phase()` |
| `protocol2-diagnosis-attempt4-2026-10-30` | `p2_decision.gd`、`protocol2_runner_traced.gd` | 同上 |
| `vs03-defeat-diagnosis-2026-11-03` | `p2_decision.gd` | 三參數呼叫 |
| `difficulty-ai-formation-2026-11-03` | `formation_decision.gd` | 三參數呼叫 |
| `difficulty-ai-retreat-2026-11-03` | `retreat_decision.gd` | 三參數呼叫 |

(以上 5 個資料夾 7 檔;加 v3 共 8 檔,與協調者查到的數字一致。)

**我的判斷:在各自 README 末尾加一行是合適的,理由與限制如下。**
- 合適之處:這些是歸檔的拋棄式證據,**改程式 = 改歷史證據**,不改;加一行說明成本最低,且讓下一個想重跑的人不必靠看到解析錯誤才發現。
- ⚠️ **限制,不要寫成「在清理前 commit 上執行即可」就算完:** 那些資料夾的 `.uid`、`project.godot`、資料檔在舊 commit 上是否齊全沒有人驗過。這一行是**說明,不是保證可重跑**。措辭請用「預期需在 `<清理前 commit>` 上執行(未驗證)」。
- 一行範本(`<清理前 commit>` 填步驟 1 的 A/B 所用 HEAD 短雜湊,`<commit>` 填本工單 src/ 清理提交,**由協調者在提交後填入**,實作者留 `<待填>`):
  `> 自 <commit> 起,本資料夾腳本呼叫的舊版三參數介面已不存在,預期需在 <清理前 commit> 上執行(未驗證可重跑)。要重跑量測請改用 protocol2-computer-measure-v4。`
- 🔴 **不得在這行文字裡寫出三個符號名**(驗收 grep 只掃 src/ 與 tests/,但 prototypes 的 grep 若日後用於盤點,README 命中會混淆結果;用「舊版三參數介面」代稱)。
- **這是改既有文件 —— 需協調者確認後才能動**(CLAUDE.md 2026-10-05 / 10-12 裁決:文件側「必須先問」)。實作者拿到協調者明確確認前,**只做 v4 與 src/tests,不碰這 5 個 README**。
- 替代建議(不採用,僅供協調者參考):在 `prototypes/` 根放一份索引。否決理由:新增一個要同步的單向複本,本專案已反覆吃過這種虧。

## Affected Files(逐檔,`Ready` 工單的明文範圍)

### production(src/)
| 檔案 | 動作 |
|---|---|
| `src/gameplay/combat/combat_rules.gd` | 刪 `lone_guard_effective()`(現第 70 行起)及其過期註解 |
| `src/gameplay/battle/battle_state.gd` | 刪 `_attacked_this_phase` 宣告、`attacked_this_phase()`、`resolve_attack` 內的寫入、新階段清除;`lone_guard_if_at` 去掉第 3 參數與 `[param will_attack]` 文件行,直接回傳 `CombatRules.lone_guard(d_min, combat_tuning)`;更新其文件註解。**提交次數不得改變**:寫入在同一個 `commit_authoritative_change` 內,刪掉不影響版本號 +1 一次 |
| `src/ui/battle/battle_screen.gd` | `_displayed_guard_at` 去掉 `will_attack` 參數;4971 附近呼叫點去掉第 4 個引數(`_state.attacked_this_phase(...)`) |

### tests(預計刪除/改寫條數,現場 `grep -c "^func test_"` 為準)
| 檔案 | 動作 | 預計條數 |
|---|---|---|
| `tests/unit/gameplay/combat/combat_rules_guard_test.gd` | 刪 `test_lone_guard_effective_ignores_attacked_flag` | -1 |
| `tests/unit/gameplay/battle/battle_state_lone_guard_conditional_test.gd` | 刪 5 條旗標測試(`test_flag_*` 共 5)與 `test_lone_guard_if_at_will_attack_param_is_ignored`;`test_breakdown_equals_lone_guard_if_at_with_real_position_and_real_flag` 改為 2 參數版保留(名稱去掉 `and_real_flag`);其餘 4 條(d3 / attacked_d1 / attacked_d2 / other_units)讀過內容確認不依賴旗標後保留 | -6、改 1 |
| `tests/unit/gameplay/battle/battle_state_straddle_hold_back_test.gd` | `test_will_attack_param_is_ignored_same_result_true_false`:整條刪(內容是在測被刪的參數與函式);若讀後發現含無關斷言,拆出保留 | -1(或 0,視讀後) |
| `tests/integration/ui/battle/battle_screen_guard_display_test.gd` | `test_lone_guard_part_still_shown_after_unit_attacked` 內有直接寫 `instance._state._attacked_this_phase[u.id] = true` 的一行:**刪那一行,測試保留**(它守護的是「出手後獨行減傷仍顯示」,不依賴旗標);第 188-190 行關於已作廢變種的歷史註解一併刪除或改為不含符號名的敘述 | 0、改 1 |

**預估淨減 8 條上下。** ⚠️ 測試數字屬 (C) 級預估;驗收以引擎自己的 `Overall Summary` 為準,與預估不符時照實報,不要為湊數改動範圍。

### prototypes
- 新增 `prototypes/protocol2-computer-measure-v4/`(見上)。
- 5 個 README 末尾各加一行 —— **需協調者確認**。
- 不動任何 `.gd`(v3 與 5 個診斷/難度資料夾皆然)。

### 不在範圍
- `assets/data/locales/strings.csv` 與 `locale_data_integrity_test.gd`(步驟一已處理,本步驟不再動列數)。
- 常數資料驅動化(盤點第 8 項,另走技術債)、「6 keys」註解(盤點第 6 項)。

## 驗收條件

1. **全套綠**,交付時貼**引擎自己的原始三行**(不是「測試通過」):`ENGINE EXIT = <n>`、`Overall Summary` 該行、`Executed test suites: (x/x)`。入口用 `GODOT_BIN=<引擎路徑> ./tools/build/run_tests_with_import.sh`(coding-standards CI 節)。預期 `ENGINE EXIT = 0`、`0 failures`、`0 orphans`。出現 exit 105(收集階段解析錯誤)時 grep 會是空的,**先看 exit code 與 log 尾端有無 `Parse Error`**。協調者一律自行重跑複驗。
2. **等價證明**:A、B、C 三個輸出檔在 `prototypes/protocol2-computer-measure-v4/`,附 diff 原文與過濾後 `wc -l`(見上)。A=B=C。
3. **v4 能跑本身即驗收**:C 在清理後的 src/ 上 `ENGINE EXIT = 0`、`RESULT` 16 行、`FATAL 0`。
4. **src/ 與 tests/ 已無三個符號**。⚠️ 「寫在註解裡的 grep 會算到自己」陷阱(`coding-standards.md`):下面指令**貼在回報裡執行,不要寫進任何 `.gd` 或 `.md` 註解**;且本工單檔本身含這些字樣,所以**掃描範圍不得包含 `production/`**:
   ```
   grep -rn "lone_guard_effective\|attacked_this_phase\|will_attack" src tests; echo "grep exit=$?"
   ```
   預期無輸出、`grep exit=1`。(exit 1 = 無命中;exit 2 = 路徑錯誤,不算過。)另貼 `grep -rn "func lone_guard_if_at" src` 的原文證明簽名為兩參數。
5. 行為不變的旁證:既有「結算與預覽同源」測試(`test_resolve_attack_matches_preview_single_source`)仍在且綠;`resolve_attack` 提交一次版本號 +1 的既有測試仍綠。
6. v3 資料夾 `git diff` 為空;其餘 5 個資料夾的 `.gd` 無 diff。
7. 回報列出實際刪除/改寫的測試名與條數,以及與上方預估的差異。

## 實作順序(每步皆可編譯,停在任一步都不留壞檔)

1. 建 v4(此時 src 未動,v4 與 v3 都能跑)→ 請協調者提交 → 跑 A、B。
2. src/ 與 tests/ 一次改完(三個符號互相串連,拆開會有不可編譯的中間態;若中途用完回合,**零改動也合格** —— 回報停在哪一步)。
3. 跑全套 → 跑 C → 貼物證。
4. 協調者確認後才動 5 個 README。

## 風險

- 🔴 等價證明只證明「v3/v4 在這一組 16 局上輸出一致」,**不證明所有路徑**。要證 `lone_guard_if_at` 的參數真的被忽略,靠的是現有單元測試與讀碼(`lone_guard_effective` 本體為 `return lone`),本工單不新增窮舉證明。
- 刪除 `_attacked_this_phase` 寫入若誤動到 `commit_authoritative_change` 的包夾範圍,會改變提交邊界(ADR-0001)。只刪那一行賦值,不動窗口。
- 步驟一的護欄 `test_lone_guard_part_still_shown_after_unit_attacked` 必須保留(見上),它是「有人把出手條件改回來」的唯一畫面層回歸。
