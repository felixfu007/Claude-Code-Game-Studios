# Story 026:代價結算的生產接線(建立 session 處注入好感度池與 `CardCostTuning`)

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: ✅ Done(2026-11-17,提交 `e2c5c66`)(原狀態:Blocked —— 等 story-015 併入 main(本單依賴 `CardPlaySession.attach_affinity_pool()` / `attach_cost_tuning()` 與 `CardCostTuning` 存在;該實作目前在 worktree `agent-a61a535a476aef783`、尚未併入 main)。015 併入後轉 `Ready`。)
> **Type**: Integration
> **Estimate**: S~M(約 1 天,粗估未驗證;改動面只有 2 個 `src/` 檔,時間主要花在整合測試與敏感度證明)
> **依據**:story-015 交付註記「生產接線不在其範圍」—— 015 只新增注入點,沒有任何呼叫端。現況(2026-11-17 當場查):`grep -rn "attach_affinity_pool\|attach_cost_tuning" src/` 在 015 worktree 只命中 `card_play_session.gd` 的兩個定義,**零呼叫端**;`BattleController._init()`(`src/gameplay/battle/battle_controller.gd` 約第 196 行)以五參數建立 `CardPlaySession` 後即止。後果:**實際遊戲中付血/付好感度代價不生效,PAIR 卡未接池時一律「不可打」(`RELATION_UNRESOLVED`)**,而 015 的單元測試全綠、完全看不出來。

## 派工前須先決定

1. **注入落點(技術選型,非設計裁決)**:`CardPlaySession` 由 `BattleController` 在建構子內建立、`BattleScreen` 看不到它。兩個候選:
   - **(a) 建構子新增兩個有預設值的參數**(`affinity_pool: AffinityDataPool = null`、`cost_tuning: CardCostTuning = null`)在建立 session 之後立刻 attach。與既有 `card_deck` / `write_port` 的注入風格一致、所有依賴在建構時一次到位。**推薦。**
   - (b) `BattleController` 新增 `attach_card_cost_wiring(pool, tuning)` 轉發方法,由 `BattleScreen` 建完 controller 後呼叫。較不侵入建構子簽章,但**多出一個「忘了呼叫就靜默失效」的時機窗** —— 這正是本單要消除的失效形狀。
   - 實作者若發現 (a) 使既有建構子呼叫端(測試)大量改動,停下來問,不要自行改成 (b)。
2. **`CardCostTuning` 的載入點**:比照 `DeckTuning`(`battle_screen.gd` 約第 2010 行:`from_knobs` 回傳 null → `LoadFailure.PARSE_ERROR` 大聲失敗)。**不得**在 `BattleScreen` 內以 `CardCostTuning.defaults()` 靜默蓋過載入失敗。該旋鈕檔(`assets/data/tuning/tuning_knobs.txt`)的 `card,hp_cost_none` / `card,pair_cost_cap` 兩鍵是否已在正式檔裡:**未驗證**,實作者第一步查(各 test_fixture 檔已有,正式檔未查)。缺鍵時依 015 AC9 的語意(預設值 + `push_warning`)。
3. **池的來源**:必須是 `BattleScreen` 的 `_affinity_pool`(**同一個實例**,與 `AffinityPhiProvider`、`AffinityPoolWritePort` 共用;ADR-0002 機制一)。**不得**在 controller 或 session 內另建池。

## 規則

- 注入時機:**controller 建構完成、任何 `open_hand()` 之前**。不得留下「已建構但未接線」的中間態可被外部觀察(單一建構入口內完成)。
- `card_deck == null`(整場無出牌)時沿用現行行為:不建 session,故也不注入;不得因此拋錯。
- 不改 `CardPlaySession` 的 attach 簽章與語意(015 的範圍);本單只增加呼叫端與其載入路徑。
- 不使用 `assert()` 驗證外部輸入(發行版被移除,見 coding-standards)。

## Acceptance Criteria

- [ ] **AC1 真實場景整合測試(付血)**:`load("res://src/ui/battle/BattleScreen.tscn")` → `instantiate()` → 設定資料注入(夾具,`terrain_path_override` / `roster_path_override` 等,順序見 AC5 註) → `get_tree().root.call_deferred("add_child", instance)` → 等 2 個 `process_frame`(technical-preferences 第 5 點;**不得自組替身節點鏈**)。夾具須使手牌含一張 `cost_type=HP` 付血卡、付款人 `hp > cost`。經真實公開入口(`open_hand` → `select_card` → `select_target` → `confirm`)打出該卡,斷言**付款人 `hp == 舊hp − cost`**(真實 vs 資料:夾具的 `cost` 取自夾具卡表,斷言值不得手抄在測試內另一處而與夾具脫鉤)。
- [ ] **AC2 PAIR 卡不再恆為不可打**:同一真實場景下,對一張 `PAIR` 卡、夾具池內預灌一筆使關係為 NONE 的狀態:`is_card_playable()` 不回 `RELATION_UNRESOLVED`,且打出後兩付款人各扣 `hp_cost_none`(取自載入的旋鈕,非預設值 —— 夾具旋鈕檔須設成**與預設值不同**的值,否則「沒接上、用了預設」會與「接上了」無法區分)。
- [ ] **AC3 接的是同一個池**:在真實場景中經 `BattleScreen` 的池寫入一筆好感度後,PAIR 卡的 S 判定隨之變化(例:POS→NONE 改走付血)—— 證明注入的池與 `AffinityPhiProvider` 讀的池是同一個實例,不是另建的空池。
- [ ] **AC4 旋鈕載入失敗大聲失敗**:夾具旋鈕檔使 `CardCostTuning.from_knobs()` 回 null(例:`pair_cost_cap` 值域外)→ `BattleScreen` 走 `LoadFailure.PARSE_ERROR`,與 `DeckTuning` 同一路徑;不得靜默退回預設。
- [ ] **AC5 `card_deck == null` 不受影響**:無牌組的場景照常建構、不拋錯、不建 session(既有 AC-P6 / AC-W6 行為不變)。
  - ⚠️ 註:若測試對 `BattleScreen` 同時用 `set_script()` mutant 與路徑 override,**`set_script()` 必須在設定 override 之前**(`.claude/docs/coding-standards.md`「set_script() 會把先前賦值的屬性清回宣告預設值」;順序錯測試會靜默改測正式資料)。
- [ ] **AC6 常駐敏感度證明**(`test_sensitivity_proof_*`,一個 mutant 一次獨立執行,於真實 `BattleScreen` 場景內):①拿掉 `attach_affinity_pool` 呼叫 → AC2、AC3 紅 ②拿掉 `attach_cost_tuning` 呼叫(退回預設值)→ AC2 紅(因夾具旋鈕值 ≠ 預設)③接到另建的池而非 `_affinity_pool` → AC3 紅 ④載入失敗時改為靜默退回預設 → AC4 紅。**失敗即中止同檔後續測試**,每個 mutant 要證明哪條就要單獨跑;交付前**掃殘留注入標記**(敏感度證明中斷會停在改壞狀態)。
- [ ] **AC7 全套回報**:交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 **`ENGINE EXIT` 與 `Overall Summary` 原始三行**(2026-10-12 裁決;協調者自行重跑複驗,不採信回報)。收集階段炸掉(exit 105)時兩個 grep 都回空,**先看引擎 exit code**。

## 未涵蓋(刻意)

- 付款/折損規則本身(015)、折損如何扣減 Φ(016)、卡效果(017~019)、確認面板畫面(020)。
- 任何新的設計裁決。本單純為接線與其證據。

## 相關風險

- **同形缺口:「單元層綠、實機沒接上」是本批卡牌工單的通病,不只 015**。本單範圍外但須追蹤:
  - **012(`AffinityRelation.state_of`)—— 已接上**。唯一生產呼叫端是 013 在 main 的 `affinity_phi_provider.gd` 第 189 行(`AffinityRelation.state_of(_pool, pair, _state.affinity_tuning.neutral_band())`),而 `AffinityPhiProvider` 由 `battle_screen.gd` 第 2191 行 `AffinityPhiProvider.new(_state, _affinity_pool)` 真實建立。
  - **013 —— 同形缺口風險低,但有一條小缺口**。接線完整:池由 `BattleScreen._affinity_pool` 傳入、`k` 取自 `BattleState.affinity_tuning`(`battle_state.gd` 第 233~235 行載入),建構路徑與 015 不同,沒有「另需呼叫的 attach」。**小缺口是證據層而非接線層**:當場查 `git grep -n "neutral_band" main -- tests`,只有 `tests/integration/gameplay/affinity/position_chain_reads_relation_state_test.gd`(組 `BattleState` + 池,**不載入 `BattleScreen.tscn`**)與單元測試;**沒有任何載入真實 `BattleScreen` 並用 k>0 的測試**。亦即「`BattleScreen` 載入的旋鈕 k 真的進到 `phi`」目前只由構造推論、無實機物證。建議併入本單或另開 S 級小單補一條真實場景測試(不屬 013 範圍的改碼,只補測試)。
  - **014(騎牆)—— 尚未實作(main 無對應提交),無從查**。**派工時必須把 AC 寫成「載入真實 `BattleScreen.tscn`、斷言 `lone_guard` 與 `hold_back` 同開同關」**,否則會重演 015。另注意既有 `battle_screen.gd` 第 5518~5523 行有一段 `lone_guard` 顯示碼註記為「未經裁決的暫定」—— 014 要一併收掉或對齊,屬 014 的 Affected Files,不屬本單。
- **`attach_*` 這種「事後呼叫的注入點」本身是失效形狀**(忘了呼叫 = 靜默退回預設/不可打,且單元測試永遠綠)。015 為了不動既有呼叫端選了此設計,代價正是本單。後續若再有類似需求,優先採建構子參數;若必須事後 attach,**同一張工單就要含生產接線與真實場景測試**。
- 無任何 lint / 閘門檢查「attach 有沒有人呼叫」,遵守與否不可觀測;本單的 AC6 ① ② 是唯一的機械防線。

## Affected Files

- `src/gameplay/battle/battle_controller.gd`(建構子新增兩個選填參數,建立 session 後 attach)
- `src/ui/battle/battle_screen.gd`(載入 `CardCostTuning`、傳 `_affinity_pool` 與 tuning 給 controller;失敗走 `LoadFailure.PARSE_ERROR`)
- `assets/data/tuning/tuning_knobs.txt`(僅當正式檔缺 `card,hp_cost_none` / `card,pair_cost_cap` 時補鍵;`.txt`,不得 `.csv`)
- 新夾具:`assets/data/tuning/test_fixture_tuning_card_cost_nondefault.txt`(旋鈕值刻意 ≠ 預設)、必要的合成牌組/名冊夾具(兩份夾具須先驗彼此相容,見 technical-preferences 第 5 點後的警告)
- 新測試:`tests/integration/ui/battle/battle_screen_card_cost_wiring_test.gd`

超出此清單先問。

## 與其他工單的順序

- **依賴 015**(必須先併入 main);**建議排在 015 之後、017/018 之前,獨立成單、不併入任一張**。
  - 理由 1:017(補血 c13/c14)與 018(直傷)都含 PAIR / 付血卡,其真實場景驗收若在代價未接線時跑,會**用預設值與恆為「不可打」的行為通過或失敗得莫名其妙**,等於把本單缺口帶進兩張工單的驗收。先接線,017/018 的整合測試才站在真實基礎上。
  - 理由 2:本單改的是 `battle_controller.gd` / `battle_screen.gd`(兩個大檔、多條工作線共用),017/018 改的是卡效果檔,**檔案面不重疊,可平行開發**;但**合併順序**須本單先。併入其一會讓該單的 Affected Files 膨脹並混入完全不同性質的風險(接線 vs 效果數學),敏感度證明也難以各自獨立。
  - 016(PAIR 折損扣 Φ)依賴 015;是否也依賴本單:016 的單元層可先行,但其真實場景驗收同理應排在本單之後。
