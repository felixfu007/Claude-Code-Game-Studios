# Story 062:真實關卡整場戰鬥的牆鐘耗時移出全套(全套只驗「打得完」,耗時改為獨立效能檢查)

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Done(2026-11-18,`786e687`;perf 基準待閒置時重量)(原狀態:Ready(2026-11-17)—— 管理者 2026-11-17 約 16:10 裁決(逐字):計時測試 =「A:全套只驗『打得完』,耗時移成單獨效能檢查(效能專家推薦)」;全套等待上限 =「維持 15 分鐘」(不改 wrapper)。)
> **Type**: Logic(測試結構重整)+ Config(新增非全套收集的測試目錄)
> **Estimate**: S(約 0.5~0.75 天:抽出共用驅動 0.2、全套測試改寫 0.1、效能檢查檔 0.15、常駐敏感度證明 0.1、基準量測與 README 0.1、全套跑一次約 95 秒~12 分鐘)
> **依據**:`docs/reviews/timing-test-full-suite-red-2026-11-17.md`(performance-analyst)。要點:同一場戰鬥(6 回合、結果相同)歷來實測耗時 15.9~50.4 秒;30 秒門檻只比安靜時單跑(19~23 秒)高 1.3~1.5 倍;story-019/020 訂門檻時實測約 5 秒、2 回合(6 倍餘裕),後來內容長大、門檻從未重估。**不是遊戲邏輯退化。**
> ⚠️ 上述報告是 performance-analyst 的調查;其中「下午變慢的真正原因」「單跑與全套同時段並排」均**未驗證**(報告第七節)。本單不依賴那些未驗證項,只依賴「耗時不穩定」這個已實測事實。

## 問題

`tests/integration/ui/battle/battle_screen_real_level_battle_test.gd` 的 `test_real_level_battle_reaches_a_terminal_outcome` 末行 `assert_int(elapsed_msec).is_less(30000)`(story-019/020 AC-5)量的是**真實牆鐘時間**。耗時隨機器時段 2~3 倍浮動,於是這條測試同時扮演「戰鬥卡死偵測器」與「今天機器快不快的量測器」,後者讓全套無故變紅,紅燈不可信。

真卡死另有兩道把關,**不依賴那 30 秒**:`_ROUND_CAP = 10`(迴圈上限)與「`outcome()` 必須是 VICTORY 或 DEFEAT」斷言。

## 設計

### 一、全套內(`tests/integration/...`,照常被收集)

- `test_real_level_battle_reaches_a_terminal_outcome` **保留**:開局防誤報(5 對 5、ONGOING)、逐回合驅動、診斷輸出、`outcome()` 為 VICTORY 或 DEFEAT。
- **移除** `assert_int(elapsed_msec).is_less(30000)`。`elapsed_msec` 仍計算並**照舊印進診斷輸出**(只印不斷言;之後有人要看趨勢,log 裡還在)。
- 其餘斷言、診斷輸出、`_ROUND_CAP` 一個字不動。**不得**把 `_ROUND_CAP` 放大(檔內註解明文禁止貼近實測值縮小,放大同樣會讓把關變鬆)。

### 二、獨立效能檢查(**刻意不在全套自動收集範圍內**)

**提案位置**:`tests/perf/battle_real_level_timing_perf_test.gd`(新目錄 `tests/perf/`)。

**為什麼選這裡,而不是 prototypes 腳本**:
- 它仍是 GdUnit4 測試,有標準的 `assert_*` 與 exit code(超標 → exit 100),符合 test-standards「Performance tests must specify acceptable thresholds and fail if exceeded」。prototypes 腳本則無此契約,且 `prototypes/` 規範上是拋棄式。
- 與全套共用**同一份真實驅動**(見下「共用驅動」),不重新實作一份戰鬥迴圈 —— 避免 `technical-preferences.md` 第 5 點記載的「真的類別 + 假的宿主」形狀(本檢查同樣必須 `load()` 真實 `BattleScreen.tscn`)。

**🔴 刻意不加進 `tests/gdunit4_runner.gd` 的 `FORCED_ARGS`**:`coding-standards.md` 與 runner 檔頭都寫「新增測試層級必須加進 FORCED_ARGS,否則不會跑」—— 那條規則防的是「測試存在、看起來全綠、實際一條都沒跑」。**本單的 `tests/perf/` 正是要「不被全套跑」,所以這是對該規則的刻意反用,不是漏加。** 必須在三處寫明(見 AC6):`tests/perf/README.md`、perf 測試檔檔頭、runner 的 `FORCED_ARGS` 旁註解。理由是日後有人看到「這個目錄沒進 runner」會當成疏漏去補,補了就讓這條計時測試回到全套、重演今天的紅燈。

**執行方式**(手動、機器閒置時):

```bash
"<Godot 4.7.1 console 執行檔>" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/perf
```

(`--ignoreHeadlessMode` 必帶,見 coding-standards CI 節。**注意**:不走 `run_tests_with_import.sh`,因為該入口綁定全套;若執行者的工作樹剛改過資料檔,先自行 `--import` 一次。實作者須驗證此指令實際跑到 1 條測試,**以測試數而非 exit code 判斷**,因為 coding-standards 記載過路徑打錯會 exit 0。)

**量測方式與門檻**(依效能報告建議,由本單定案):
- **連跑 3 場**整場戰鬥(每場各自 `load()` 新實例),取 **中位數** 與全部 3 個值一併印出。中位數可抵銷單次偶發的 2~3 倍尖峰;3 次是在「成本約 20 秒 × 3」與「抗單次離群」之間的折衷。
- **門檻:中位數 < 30000 ms**(沿用原值,不重估成新數字 —— 原值的問題是被放進全套,不是數字本身;在閒置機器上實測 19~23 秒有 1.3~1.5 倍餘裕)。
- 同時斷言 3 場的 `round_count` **全部相同**(實測為 6;不寫死 6,只要求彼此相等,以免遊戲內容再成長又要改測試)。不同代表戰鬥本身不再決定性,那是另一種缺陷,不是效能。
- 實作者第一步:在閒置機器上實跑 3 次,把原始輸出行貼進 README 作為基準值;若中位數已不到 30000 的 1/1.3,**停下回報**,不自行調門檻。

**⚠️ 這個檢查沒有任何機制保證有人會定期去跑**(performance-analyst 報告選項 A 的明文缺點)。管理者在知情下選了 A。本單不加排程、不加 CI;唯一的補償是 `tests/perf/README.md` 寫明何時該跑(例如:改動戰鬥迴圈、卡牌/代價結算、敵方回合播放之後)。

### 三、共用驅動(兩邊不得各養一份)

現況 `_load_battle_screen_real`、`_play_faction_turn_via_ai`、`_resolve_any_pending_discard` 等是全套測試檔內的私有函式。效能檢查需要同一條驅動,又不能複製貼上(複製等於第二份實作,日後兩份漂移)。

- 抽出為 `tests/support/real_battle_driver.gd`(或實作者查證後更合適的既有 support 位置;**動工前先 `ls tests/` 確認慣例,不符就回報**),提供:載入真實場景、驅動至終局或回合上限,回傳 `{round_count, outcome, elapsed_msec}`。
- 全套測試與效能檢查都呼叫它。**抽出必須是純搬移**:搬移前後全套該條測試的診斷輸出(逐回合 died/alive、座標、`round_count`、`outcome`)逐行相同 —— 實作者貼前後 log 對照。
- 🔴 實作者動工前**自己讀**原檔 `_load_battle_screen_real` 等私有函式的實際內容再決定搬法;本單撰寫者只讀了測試主體(約 545~657 行),**未讀那些輔助函式**。若它們依賴 suite 實例狀態(`self`、`auto_free` 等)導致無法乾淨抽出,**停下回報**,不要為了抽出而改變它們的行為。

## Acceptance Criteria

- [ ] **AC1 全套保留把關**:`test_real_level_battle_reaches_a_terminal_outcome` 仍存在,且斷言開局 5 對 5 + ONGOING、結束時 `outcome()` 為 VICTORY 或 DEFEAT、迴圈受 `_ROUND_CAP`(值不變)約束。
- [ ] **AC2 牆鐘斷言移除**:`grep -n "is_less(30000)" tests/integration/ui/battle/battle_screen_real_level_battle_test.gd` 無命中(🔴 把這個指令寫在回報裡時,**不要把字串寫進該檔的註解**,否則自己命中自己,見 coding-standards「驗證指令寫在註解裡會算進自己」)。`elapsed_msec` 仍印在診斷輸出。
- [ ] **AC3 效能檢查存在且不在全套**:`tests/perf/battle_real_level_timing_perf_test.gd` 存在,中位數 < 30000 ms、3 場 `round_count` 相等;`grep -n "tests/perf" tests/gdunit4_runner.gd` 只命中**註解**、不在 `FORCED_ARGS` 陣列內。實作者貼:全套跑一次的 `Overall Summary` 內**沒有**該 perf 測試名;單跑 `-a tests/perf` 的測試數為 1。
- [ ] **AC4 共用驅動純搬移**:前後診斷輸出逐行相同(貼對照);全套與效能檢查呼叫同一份驅動,`grep` 確認原私有函式在測試檔內已無第二份定義。
- [ ] **AC5 常駐敏感度證明(移除牆鐘後,戰鬥卡死仍會被抓)**:在全套測試檔內新增一條會**通過**的 `test_sensitivity_proof_stuck_battle_is_caught`:
      - 常駐 mutant 子類別(`extends BattleScreen`),覆寫 `_end_faction_phase_pressed()` 為不推進任何階段(模擬「敵我雙方都無法再推進」,即檔頭記載過的強制棄牌閘門卡死那類缺陷);
      - 🔴 **先 `set_script()` 再設任何屬性**(test-standards 陷阱一;與 story-060 同);
      - 用共用驅動跑它,斷言:`round_count == _ROUND_CAP`、`outcome() == ONGOING`,**且**把關用的判定函式(「結果是否為 VICTORY/DEFEAT」,須抽成與正式測試共用的同一個函式而非各寫一份)對該結果回傳 false。
      - 證明的是**判定函式本身**抓得到卡死,不是在測 mutant。這條只靠 `_ROUND_CAP` + outcome 斷言,**不依賴任何時間**。
      - 不可證項逐條寫理由:效能檢查的 30000 門檻本身**無法在全套內做敏感度證明**(證明需要刻意放慢戰鬥 → 引入真實等待或假時鐘,前者拖慢全套、後者是改動被測物;屬 test-standards 類 D「唯一有意義的注入點在受限範圍外」)。該門檻的有效性改由 README 的基準值與「超標 → 紅」的一次性手動驗證(暫把門檻改成 1 ms 跑一次、貼 exit 100、還原)佐證,**一次性紀錄,不算常駐證明,README 須如實寫**。
- [ ] **AC6 「刻意不進 FORCED_ARGS」寫明三處**:`tests/perf/README.md`(含手動執行指令、何時該跑、基準值、與全套的關係)、perf 測試檔檔頭、`tests/gdunit4_runner.gd` 的 `FORCED_ARGS` 旁註解(⚠️ runner 為既有程式碼檔,見下「Affected Files」)。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。🔴 全套現約 7~13 分鐘,**wrapper 逾時維持 900 秒不改**(管理者同日裁決);若跑到逾時回報 exit 124,**那是逾時假訊號,不是測試失敗**,照實回報並停下,不自行改 `TEST_TIMEOUT_SEC`。
- [ ] 注入標記掃描:交付前確認 `tests/` 內無殘留的暫時改壞(AC5 的 mutant 是常駐的,不算殘留;AC5 一次性把門檻改 1 ms 必須已還原)。

## 未涵蓋(刻意)

- 全套逾時(`tools/build/run_tests_with_import.sh` 的 `TEST_TIMEOUT_SEC`):**管理者裁決維持 900,不動**。
- 全套整體變慢的根本原因與「同一 suite 共用畫面」之類的加速(報告第五節末),是另一張工單。
- 其他有計時性質的整合測試(報告前 10 名清單)是否也該移出:本單不評估。
- 排程/CI 自動跑效能檢查:不做(見上「沒有機制保證有人會跑」)。
- 重估 30000 門檻:不做,沿用。

## Affected Files

**程式碼檔(本單 Ready 工作單明文範圍,2026-10-12 裁決可直接改;交付須貼引擎原始三行):**
- `tests/integration/ui/battle/battle_screen_real_level_battle_test.gd`(移除牆鐘斷言與其註解、改呼叫共用驅動、新增 AC5 常駐證明與共用判定)
- 新:`tests/support/real_battle_driver.gd`(位置待實作者核對慣例)
- 新:`tests/perf/battle_real_level_timing_perf_test.gd`
- `tests/gdunit4_runner.gd`(**只加註解**,不改 `FORCED_ARGS` 內容)

**新檔(直接寫):**
- `tests/perf/README.md`

超出此清單先問。

## 待核准既有檔變更(文件類,本單撰寫者**不自行修改**,需管理者核准後另行處理)

1. `production/epics/tactical-combat/story-019-real-level-battle-terminates.md` 的 **AC-5**(「執行時間必須量測並揭露……若單一測試超過 30 秒,先停下來回報」):原文意圖是「異常變慢要抓到」。建議在原文下加註「2026-11-17 起牆鐘斷言移至 `tests/perf/`,見 story-062」,**不改原文**。
2. `production/epics/tactical-combat/story-020-test-policy-survives-multiple-rounds.md` 的 **AC-5**(「單一測試不得超過 30 秒」「超過就停下回報」):同上加註。
3. `.claude/docs/coding-standards.md`:查證結果 —— 本單撰寫者以 `grep -n "30000\|30 秒\|AC-5"` 掃過 `.claude/docs/*.md`、`tests/README.md`、story-019/020,**未在 coding-standards 找到對本計時測試的明文提及**。但該檔 CI 節有一句「新增測試層級必須同時加進 `tests/gdunit4_runner.gd` 的 `FORCED_ARGS`」,**與本單「刻意不加」形成例外**;建議在該句後加一行「例外:`tests/perf/` 刻意不收集,見 story-062」。(⚠️ 該檔每次對話開場載入,改動影響全域,是否值得加由管理者定;不加的風險是日後有人當疏漏去補。)
4. `tests/README.md`:若記載測試層級清單,建議補 `tests/perf/`(**本單撰寫者未讀全檔**,僅 grep 過 30000/AC-5 無命中;是否需補由實作者查後回報)。
5. `production/session-state/active.md` 與 `docs/reviews/timing-test-full-suite-red-2026-11-17.md`:收尾登記由協調者處理。

## 與其他工單的順序

- 與 story-059/060 **不同檔、順序不限**;本單只動測試與 `tests/` 底下的新檔,不動 `src/`。
- ⚠️ `git status` 顯示 `M production/session-state/active.md` 等他人未提交修改;本單不碰那些檔。
- 未驗證項(實作者動工前自行確認,不符就停下回報):①輔助函式能否乾淨抽出(見設計三);②`-a tests/perf` 指令實際執行 1 條測試;③`tests/support/` 是否為既有慣例。
