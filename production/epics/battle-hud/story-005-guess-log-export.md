# Story 005: 預判紀錄匯出(每場寫成檔案,供遠端試玩回收)

> **Status**: Draft(待管理者裁決試玩範圍)
> **Epic**: battle-hud
> **Type**: Logic(寫入器、格式化)+ Integration(接線)
> **預估工時**: 約 1 個工作天(見「預估」節);若採「未決點 1」的方案 B 再加約 0.5 天文件修訂
> **擁有者**: lead-programmer 起草;實作交 gameplay-programmer / godot-gdscript-specialist
> **編號註記**: 任務指定檔名 `story-XXX-guess-log-export.md`,battle-hud 目前最大為 story-004,故取 005。

## 為什麼有這張單

協議 1 真人半要的數字是「預判一致率」。陌生人若在遠端試玩,在場觀察者不存在,
而現行 `EffectGuessTracker` 只在記憶體累計一個 `M/N`,關閉遊戲即歸零,
**遠端試玩結束後沒有任何東西可以回收**。本單評估把每場預判寫成檔案寄回。

**是否開工尚未裁決**:管理者在今晚試玩後才決定試玩範圍(在場 / 遠端)。
本檔只是把成本與未決點先查清楚,讓裁決有材料。

## 現況(逐項查證,附符號)

### tracker 記了什麼(`src/ui/battle/effect_guess_tracker.gd`)

| 欄位 / 符號 | 內容 | 備註 |
|---|---|---|
| `_locked_guesses: Dictionary` | 本次選格流程已鎖定的猜測,`Vector2i` → `EffectDirection` | 每次 `begin_move_selection()` / `cancel_move_selection()` / `confirm_move()` 都會 `clear()` |
| `_scored_total: int` | 「有鎖定猜測且已確認移動」的次數(分母 N) | 只有計分事件的**累計數** |
| `_scored_correct: int` | 其中猜中的次數(分子 M) | 同上 |
| `get_consistency_rate()` | `M/N`,N==0 回 `-1.0` | 一致率**在這裡算** |
| `EffectDirection` | `POSITIVE=1` / `NEGATIVE=2` / `NEUTRAL=3` | 刻意不用 0 |

**關鍵缺口:tracker 只保留累計數,不保留每一筆事件。** `confirm_move()` 算完就丟掉
`guess` / `actual` / `cell`。要寫「每場的預判紀錄」,必須先讓這些資料有出口(見設計)。
另外「**跳過**」(沒猜就確認移動)目前存在 `battle_screen.gd` 的 `_guess_skipped`,
**不在 tracker 裡**,也不計入 N —— 若要回答「受測者多常跳過」,資料在畫面層不在 tracker。

### 畫面哪裡顯示

`src/ui/battle/battle_screen.gd`:
- `_guess_tracker`(第 977 行附近宣告)由 `_click_tile_with_egm()` 在移動成功後呼叫
  `_guess_tracker.confirm_move(cell, delta)`,接著 `_update_consistency_counter()`。
- `_consistency_counter_text()` 以 `Loc.localize(TEXT_CONSISTENCY_COUNTER_FORMAT) % [correct, total]`
  組出「猜中 M/N」,顯示於 `_consistency_label`(`_build_consistency_counter()` 建立)。
- EGM 開關:`GameSettings.is_egm_enabled()`(`src/core/settings/game_settings.gd`),
  預設關閉,`_ready()` 只讀一次(AC2)。

**接線點只有一個**:`_click_tile_with_egm()` 的 `moved` 分支。匯出的觸發點就掛在這裡。

## AC14 為什麼禁止 I/O,以及新需求是否衝突

查證 `design/quick-specs/battle-hud-prediction-marker.md`:

1. 第 137~140 行:**本規格不得碰存檔系統**。理由是存檔系統當時降級、程式尚未落筆,
   不該為量測工具牽動它;統計變數生命週期與單次執行相同,**不得出現在存檔讀寫路徑或新增存檔欄位**;
   跨前 2~3 場戰鬥的累積只在不關遊戲的單次執行內有效;中途關閉則歸零 ——
   「**裁決接受的代價,非本規格缺陷**」。
2. AC14(第 185 行):關閉重開後一致率重置為 0/0;存檔序列化/反序列化程式碼**不得**參照任何 EGM 統計變數。
3. 2026-10-16 管理者裁決(第 192 行):「**不持久化,只留記憶體,關閉遊戲即歸零**」。

**衝突判斷(不自行推翻)**:

- **字面不衝突的部分**:AC14 禁的是「存檔系統」與「一致率統計跨重啟保留」。
  本單的匯出檔**不是存檔、不被讀回、不影響重啟後的 0/0**,
  遊戲內計數器行為完全不變。tracker 本身仍可維持零 I/O(寫入由外部元件做)。
- **精神上有衝突的部分**:10-16 裁決的字面是「只留記憶體」。把預判寫成檔案,
  就是把統計「留在記憶體以外」。裁決當時要防的是**牽動存檔系統**,
  而不是「任何檔案」,但**這個解讀是我的,不是管理者的**。
  → 列為未決點 1,**由管理者裁決,本單不假設答案**。

## 未決點(需管理者 / 相關專家裁決)

1. **10-16 裁決是否容許「診斷匯出檔」?**(管理者,阻擋實作)
   - 方案 A:視為與存檔系統無關的獨立診斷輸出,**更新 quick-spec 一行註記**(文件修訂,需先問);
   - 方案 B:仍視為持久化,**不做**,走「替代方案」(在場手抄)。
2. **試玩範圍**:今晚試玩後才定。若全部在場觀察 → 本單可擱置(關閉),不浪費工時。
3. **受測者如何把檔案寄回**:`user://` 在 Windows 為 `%APPDATA%\Godot\app_userdata\<專案名>\`,
   陌生人未必找得到。選項:請他截圖資料夾路徑 / 遊戲內顯示路徑一行 / 結束畫面提供「複製路徑」。
   本單**不含**任何上傳(`networking_features` 為專案級禁令);寄回是人工動作。
4. **是否同時記「跳過」次數**:對「預判一致率」不必要,但能解釋 N 為何偏小(受測者沒在猜)。
   建議記,成本幾乎為零。
5. **開關放哪**(見下節,有建議,需確認):不放進給陌生人看的選項選單。

## 設計提案(待核准,未核准前不寫程式)

### 資料出口

不讓 tracker 做 I/O。給 tracker 一個**純資料出口**:`confirm_move()` 計分時
發出 signal `guess_scored(cell: Vector2i, guess: int, actual: int, matched: bool)`
(過去式、snake_case,符合命名規範)。tracker 仍是純邏輯、零 I/O、AC14 的檔頭字句不需改。
(若偏好不加 signal,替代是讓 `confirm_move()` 回傳 `Dictionary`;signal 對既有呼叫端與既有測試影響最小。)

### 寫入元件

新增 `src/ui/battle/guess_log_writer.gd`(`class_name GuessLogWriter`,`RefCounted`):

- 持有一個**可注入的檔案寫入器**(比照 `SettingsFileStore`:`write_text(text) -> bool` 薄殼,
  路徑可注入)—— 單元測試注入假寫入器,不碰檔案系統(符合 coding-standards「Independence」)。
- `record_scored(...)` / `record_skipped(...)` 累積事件;`flush()` 組出文字並呼叫寫入器。
- **寫入失敗**:`write_text` 回傳 false 時 `push_warning()`、吞掉、**不重試、不拋、不影響遊戲**
  (與設定檔「讀寫失敗不阻擋遊戲」同立場)。禁用 `assert()` 守衛(見 coding-standards)。
- 寫入發生在回合確認那一刻(事件稀疏,非每幀),不阻塞畫面的風險可接受。

### 路徑與格式

- 路徑:`user://guess_logs/guess_log_<session_id>.txt`,**每次啟動一檔**。
  `session_id` = 啟動時的 UTC 時間 `YYYYMMDD-HHMMSS`(不含主機名 / 使用者名)。
- 格式:**純文字 JSON 檔(副檔名 `.txt`,不得 `.csv`)**。每筆事件一行 JSON(JSON Lines 風格),
  比一整份 JSON 好:中途當機也保有已寫的行。
- 寫法:每次事件**整檔重寫**(事件總數很小,幾十行)而非 append ——
  這樣可複用既有「整段文字寫出」薄殼,不必新增追加模式;若實作者偏好追加亦可,屬實作細節。
- 每行欄位(最小集):

  ```
  {"v":1,"seq":3,"battle":1,"unit_turn":7,"event":"scored","guess":"positive","actual":"neutral","matched":false}
  {"v":1,"seq":4,"battle":1,"unit_turn":8,"event":"skipped"}
  ```
  - `v`:格式版本;`seq`:本檔流水號;`battle`:第幾場(從 1 起);
  - **格座標不寫**(對一致率無用、也不需要)。需要者列入未決點再議。
  - 檔尾 / 每場結束可附一行 `{"event":"summary","correct":M,"total":N}`,
    與畫面「猜中 M/N」可交叉核對(**驗證用,不是第二份計算 —— 見 AC5**)。
- **一致率的權威算式仍只有 tracker 的 `get_consistency_rate()`**。寫入器不自行除,
  只轉錄 tracker 的 `get_scored_correct()` / `get_scored_total()`(避免「兩份實作碰巧一致」的已知失效形狀)。

### 預設是否開啟

**建議預設關閉**,只在試玩 build 開。開關放哪,建議順序:

1. **匯出特徵標籤**(`OS.has_feature("playtest")`,於 Godot 匯出預設的 Custom Features 設定):
   試玩 build 與開發 build 的差別在匯出時決定,**受測者無從誤關、玩家版本天然關閉**,
   不進 `GameSettings`、不進設定檔、不佔 UI。(特徵標籤行為需 `godot-specialist` 以 4.7.1 實機確認再採用 —— 本人未驗證,標為 (C) 級。)
2. 備案:命令列使用者參數 `OS.get_cmdline_user_args()` 含 `--guess-log`。需要受測者用捷徑啟動,遠端不友善。
3. **不建議**:放進 `GameSettings`(設定檔會跨啟動記住,又會與 10-16 裁決的精神更靠近一步)或選項選單(陌生人會看到並動它)。

另需 EGM 本身為開啟(`GameSettings.is_egm_enabled()`),否則沒有猜測可記;EGM 關閉時寫入器不建立、不產生空檔。

### 隱私

- 檔案內容只有:格式版本、流水號、場次、回合序、預判方向、實際方向、是否相符、摘要計數。
- **不含**:使用者名稱、主機名、路徑、IP、裝置資訊、系統時區、棋盤格座標、對話選擇、存檔內容。
- 檔名只含 UTC 時間戳,**不含**任何識別資訊。
- 受測者自行把檔案寄出(無自動上傳);試玩說明須提一句檔案內容為何,
  讓他知情後才寄(此為試玩流程文字,不在本單範圍)。
- AC 要求單元測試對產出文字掃描,斷言不含 `OS.get_environment("USERNAME")` 之類的值
  (測試以固定假值注入,不讀真實環境)。

## Affected Files(預估;開工前依實作回頭核對)

| 檔案 | 動作 |
|---|---|
| `src/ui/battle/guess_log_writer.gd` | **新增**(純邏輯 + 注入寫入器) |
| `src/ui/battle/guess_log_file_store.gd` | **新增**(唯一碰 `user://` 的薄殼,比照 `src/core/settings/settings_file_store.gd`) |
| `src/ui/battle/effect_guess_tracker.gd` | 修改:加 `guess_scored` signal,於 `confirm_move()` 計分分支發出(**檔頭 "no save/load I/O (AC14)" 不動,仍為真**) |
| `src/ui/battle/battle_screen.gd` | 修改:啟動時依開關建立 writer、連 signal、跳過分支呼叫 `record_skipped`、場結束 flush |
| `tests/unit/ui/battle/guess_log_writer_test.gd` | **新增** |
| `tests/unit/ui/battle/effect_guess_tracker_test.gd` | 修改:新增 signal 發出測試(**既有斷言不得改**) |
| `tests/integration/ui/battle/battle_screen_guess_log_test.gd` | **新增** |
| `design/quick-specs/battle-hud-prediction-marker.md` | **僅在未決點 1 選方案 A 時**加一行註記(文件,需先問) |
| `docs/` / `.claude/docs/technical-preferences.md` | 若新增 `user://` 檔案,須登記(該檔現列「唯一碰設定檔」) |

## Acceptance Criteria

1. 開關關閉(預設)時:不建立任何寫入器、不產生任何檔案、遊戲行為與現狀逐位元相同。
2. 開關開啟 + EGM 開啟時:每次**計分**移動產生一行 `scored` 事件,欄位如上;每次**跳過**產生一行 `skipped`。
3. 檔案副檔名為 `.txt`,路徑在 `user://guess_logs/` 下;**專案內不新增任何 `.csv`**。
4. 寫入失敗(假寫入器回 false)時:遊戲流程不中斷、無例外、`push_warning` 一次;之後的事件仍嘗試寫入或安靜放棄(擇一,測試鎖定)。
5. 摘要的 M/N 與畫面計數器逐項相等,且**來源是 tracker 的 getter**,寫入器內無任何除法或比較邏輯可複製出第二份一致率。
6. 隱私:產出文字不含主機/使用者識別字串(測試以注入的假環境值驗證不出現)。
7. `effect_guess_tracker.gd` 仍零 I/O;AC14 原文(重啟歸零)行為不變 —— 重啟後遊戲內計數器仍為 0/0。
8. 每場一檔(以啟動為界)。**同一次啟動內多場戰鬥**寫入同一檔並以 `battle` 欄區分。
9. 單元測試**不寫任何檔案**:全部經注入的假寫入器;唯一碰真實 `user://` 的是薄殼,
   比照 `settings_file_store.gd` 的測試做法,且全套跑完後無真實 `user://guess_logs/` 產生(與設定檔同一驗法)。

## 測試路徑

- 單元:`tests/unit/ui/battle/guess_log_writer_test.gd` —— 格式、欄位、失敗不拋、隱私、關閉時不寫。
- 單元:tracker signal 發出時機(計分才發、未猜移動不發、取消不發)。
- 整合:`tests/integration/ui/battle/battle_screen_guess_log_test.gd` —— 走真實 `BattleScreen.tscn`,
  依 `technical-preferences.md` 第 5 點:`instantiate()` → 設注入 → `call_deferred("add_child")` → 等幀;
  注入假寫入器與開關,不自組替身節點鏈。
- 敏感度證明:改壞「只在計分才寫」與「失敗不拋」各驗一次紅(注意:單一失敗會中止同檔後續測試,
  需逐條證明並還原,驗收前掃注入標記)。
- 交付須貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行;本機以 `tools/build/run_tests_with_import.sh` 跑。

## 預估

| 項目 | 工時 |
|---|---|
| tracker signal + 測試 | 1~1.5 小時 |
| writer + 薄殼 + 單元測試 | 3~3.5 小時 |
| BattleScreen 接線 + 整合測試 | 2~2.5 小時 |
| 特徵標籤開關實機驗證(godot-specialist) | 0.5~1 小時 |
| 全套重跑 + 敏感度證明 + 覆核修正 | 1 小時 |
| **合計** | **約 1 個工作天(7~8 小時)** |

主要不確定性:特徵標籤在匯出版的行為、BattleScreen 於 `_ready()` 注入時序(已有前例可循)。

## 「若不做」的替代:在場觀察者手抄畫面數字

**可行性:高,成本最低,但只適用在場試玩。**

- 畫面已常駐顯示「猜中 M/N」(`_consistency_label`),觀察者在**每場戰鬥結束**時抄下 M 與 N 兩個數字即可;
  最終一致率 = M/N,無需任何程式。
- **限制**:
  - 只得到累計值,看不到逐筆(例如前期猜得準、後期亂猜);
  - 跳過次數看不到(畫面不顯示 `_guess_skipped`);
  - 受測者收起或遮住計數器(HUD 可收合)時抄不到,需先確認可見;
  - **遠端試玩完全不適用**,除非請受測者自己截圖/報讀數字 ——
    而那會是**受測者自述**,且他們在不同場次之間可能忘記,可信度低於檔案。
  - 資料在記憶體,遊戲被關掉即歸零 —— 須約定「戰鬥結束畫面不關遊戲前先抄完」。
- **最輕量的遠端折衷(不寫檔)**:請受測者每場戰鬥結束後截一張含計數器的圖寄回。
  零工時,但可信度與完整度介於手抄與檔案之間,且需受測者配合。

## 建議

1. **今晚試玩若全部在場** → 本單不做,以手抄蓋章結案(關閉並註明理由)。
2. **若有遠端** → 先請管理者裁決未決點 1(10-16 裁決是否容許診斷匯出);通過則約 1 天可交付。
3. 在裁決前**不要**寫任何 `src/` 程式。

## 依賴與備註

- 依賴:battle-hud story-001(tracker)、story-003(計數器顯示)—— 皆已存在。
- 未動 `GameSettings` / 存檔系統。
- 本單**未經引擎驗證任何宣稱**;特徵標籤與 `user://` 實際路徑為 (C) 級待查證。
