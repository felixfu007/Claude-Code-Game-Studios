# Story 003:音效播放服務(訂閱既有 signal、素材缺席安靜、同類最小間隔)

> **Epic**: `production/epics/audio-foundation/EPIC.md`
> **Status**: Blocked(前置 story-001;另受未決點 1、2 阻擋)
> **Type**: Logic + Integration
> **需求來源**: `docs/reviews/minimal-audio-scope-draft-2026-11-06.md` 第二節 M1~M9、第四節需求 4、5、7
> **指派**: `godot-gdscript-specialist`(`.gd`);掛載位置請 `godot-specialist` 確認
> **前置**: story-001

## 範圍

1. **提示(cue)表**:新資料檔 `assets/data/audio/sfx_cues.csv`,欄位 `cue_id,path,min_interval_ms,bus`,九個 cue 對應 M1~M9(數值皆未驗證初值,家中實聽後可能調)。素材路徑可指向尚不存在的檔案。
2. **事件對應(M1~M9 出處,協調者讀碼核對,2026-11-06)**:

   | M | 事件 | 既有出處(讀到) |
   |---|---|---|
   | M1 | 通用按鈕點擊 | 各畫面按鈕 `pressed`(`battle_menu.gd` 列按鈕、`title_screen.gd`、`settings_screen.gd`、`support_conversation_screen.gd` 等) |
   | M2 | 選取單位 | `BattleController.unit_selected(id)` |
   | M3 | 取消/拒絕 | `BattleController.selection_cleared()`、`BattleMenu.open_rejected(result, message)` |
   | M4 | 單位移動 | `BattleController.unit_moved(id, from, to)` |
   | M5 | 攻擊命中 | `BattleController.attack_resolved(...)`,`target_died == false` |
   | M6 | 單位被擊倒 | 同一 signal,`target_died == true`(**與 M5 二擇一,不得同發兩聲**) |
   | M7/M8 | 勝利/失敗 | `BattleController.battle_ended(outcome)` 依 `Outcome` |
   | M9 | 好感度增進 | `AffinityDataPool.entry_appended(pair, record)` |

   **M1 接線策略(職權內定案,2026-11-06)**:查證 `grep -c "pressed" src/ui` 約 86 處、分散在 5 個畫面檔,按鈕有些是執行期建立。定案:`SfxPlayerHost` 進樹時連 `get_tree().node_added`,對之後加入的每個 `BaseButton` 連 `pressed`,並在進樹當下走訪既有子孫補連;離樹時斷線。**不逐畫面改按鈕。**
   - **宿主放哪(不用 Autoload)**:每個場景一個宿主。`SceneRouter.switch_to()` 在新實例「尚未進樹」時(`configure` 呼叫之後、`_perform_swap` 之前)把宿主加為新場景根的子節點,使宿主先於場景 `_ready()` 就位;開機場景 `TitleScreen` 不經路由,於 `title_screen.gd` `_ready()` 自行加一個。宿主加入 group `sfx_host`,`BattleScreen._ready()` 以 `get_tree().get_first_node_in_group(&"sfx_host")` 取得並 `bind_battle(controller, pool)` 接 M2~M9;取不到(例如測試直接載入 `BattleScreen`)則靜默不接。
   - **被跳過的替代方案**:①Autoload —— 需改 `technical-preferences.md`、所有測試場景啟動;②逐畫面逐按鈕接 —— 86 處、漏接難察覺;③每畫面 `_ready` 各自遍歷一次 —— 漏掉執行期建立的按鈕,且四個畫面各改一次。
   - **已知代價**:每個場景多一個宿主節點(`scene_router_test.gd` 等 10 個測試檔走路由,**若有斷言根節點子節點數會紅,實作者須實跑確認並有意識改斷言,不得刪**);宿主在 `node_added` 回呼內只連信號,不得做重工;ADR-0001 結算窗口內不得 `await`。
3. **決策核心(純、可 `new()`)**:`SfxCuePolicy`(`RefCounted`),輸入 (cue_id, 目前時間 ms, 靜音旗標, 素材是否存在) → 輸出「播/不播」及理由列舉。時鐘與「素材是否存在」皆**注入**(`Callable`),不直接呼叫 `Time`/`ResourceLoader`,以便測試。
4. **素材缺席**:`ResourceLoader.exists(path)` 為 false 時**安靜略過**——不 `push_error`、不 `push_warning`、不崩潰、不每次重試洗版(同一缺席路徑結果可快取)。`ResourceLoader.exists` 行為**未驗證**,以探針確認。
5. **同類最小間隔**:同一 cue 在 `min_interval_ms` 內再次請求則丟棄;敵方回合連續移動/命中不爆音。
6. **播放殼**:薄的 `Node`(持有少量 `AudioStreamPlayer` 池,送往 story-001 的 bus)。池大小為具名常數。
7. 🔴 **依賴方向**:`src/gameplay/**` **零改動、零音訊依賴**(`grep` 驗證,見 AC-7)。服務訂閱事件,不被邏輯層呼叫。
8. 🔴 **ADR-0001 約束**:服務的 signal 回呼只做「入列/決策/播放請求」,不得在結算窗口內引入 deferred 路徑或回寫戰鬥狀態;結算類 signal 的處理器不得 `await`。

## Affected Files

- `assets/data/audio/sfx_cues.csv` —— 新檔
- `src/core/audio/sfx_cue_policy.gd` —— 新檔,純決策
- `src/core/audio/sfx_cue_table.gd` —— 新檔,解析 CSV 文字(不讀檔,讀檔留在組裝點,比照 `tuning_knobs.gd` 慣例)
- `src/ui/audio/sfx_player_host.gd` —— 新檔,播放殼與 signal 接線
- `src/ui/battle/battle_screen.gd` —— 既有檔,**僅**在 `_ready` 取得宿主並 `bind_battle` 的最小接點(此檔 5000 行以上,改動只限接點,先在回報列出改的行)
- `src/ui/shell/scene_router.gd` —— 既有檔,**僅** `switch_to()` 在新實例進樹前加宿主的一處
- `src/ui/shell/title_screen.gd` —— 既有檔,**僅** `_ready()` 加宿主的一處(與 story-001 的 `boot_load()` 呼叫同檔,後做者須在現有內容上改,不得覆蓋)
- 其餘畫面不需改(M1 由宿主走訪按鈕)
- 測試新檔:`tests/unit/core/audio/sfx_cue_policy_test.gd`、`tests/unit/core/audio/sfx_cue_table_test.gd`、`tests/integration/ui/battle/battle_sfx_wiring_test.gd`

不得動:`src/gameplay/**`、`battle_controller.gd`、`project.godot`、`technical-preferences.md`。

## Acceptance Criteria

headless 只驗決策與接線,**不得斷言「真的響了」**。

- [ ] **AC-1 靜音不送請求**:靜音旗標為 true 時,任何 cue 的決策都是「不播」,且播放殼收到的播放請求數為 0。**[自動]**
- [ ] **AC-2 素材缺席安靜**:素材存在判斷回 false 時決策為「不播(素材缺席)」;測試期間無 `push_error`/`push_warning`(以 GdUnit4 的錯誤攔截或日誌檢查確認方法,實作者提案)。**[自動]**
- [ ] **AC-3 最小間隔**:注入假時鐘,同 cue 於間隔內第二次被丟棄、間隔後可播;不同 cue 互不影響。**[自動]**
- [ ] **AC-4 事件對應**:對真實 `BattleController` 觸發 M2~M8 對應事件,服務收到的 cue_id 序列正確;`attack_resolved` 擊倒時只出 M6 不出 M5。**[自動]**(載入真實 `BattleScreen.tscn`,依 `technical-preferences.md`「第 5 點」`instantiate → 設 override → call_deferred add_child → 等幀`,不得自組替身)
- [ ] **AC-5 CSV 解析**:壞列/缺欄/非數值被略過並回報(回傳值,不洗版);九個 cue_id 皆存在且無重複。**[自動]**
- [ ] **AC-6 音量接線**:cue 的 `bus` 欄位必須是 story-001 定義的 bus 名稱常數之一。**[自動]**
- [ ] **AC-7 依賴方向**:`grep -rn "Audio" src/gameplay`(**以 `^` 錨定或排除註解,勿讓驗證指令命中自己的註解**)無命中。**[自動]**(原始碼文字斷言屬 `test-standards.md` 登記的第二類例外,檔頭須聲明)
- [ ] **AC-9 M1 接線**:新建一個 `Button` 加入樹後,模擬其 `pressed`(直接 `emit_signal`)產生 M1 cue 請求;離樹後再 emit 不產生請求;執行期建立的按鈕同樣有效。**[自動]**
- [ ] **AC-10 宿主就位順序**:經 `SceneRouter` 切換後,新場景內存在恰好一個 `sfx_host` 群組節點(不重複)。**[自動]**
- [ ] **AC-8 不崩潰**:素材全缺席時跑完整場戰鬥測試場景,全套仍綠。**[自動]**
- [ ] 🔴 交付硬性義務:全套 `run_tests_with_import.sh`,貼 `ENGINE EXIT` 與 `Overall Summary` 三行。
- [ ] 敏感度證明:AC-1、AC-3、AC-4 各一次;注意 `set_script()` 會清掉先前賦值屬性,順序見 `coding-standards.md` 2026-10-16 條。

## Test Evidence

`tests/unit/core/audio/`、`tests/integration/ui/battle/`。**真實可聽驗收在家**(素材到位後,窗口模式 + 耳機,結果寫簡短紀錄放 `production/qa/evidence/`);公司端只驗靜音下功能不壞。

## 未決點

1. 素材尚未到:cue 表先指向預期檔名,檔名慣例採草案第四節 `sfx_[context]_[name]_[variant].ogg`;素材授權紀錄屬 story 外(草案需求 8),**本 epic 未派工,需請示是否另開**。
2. (已定案,見範圍 2 的 M1 接線策略;若實作發現 `node_added` 或路由加宿主與既有測試衝突,停下回報。)
3. 播放殼不用 Autoload(服務隨場景誕生,音效不跨場景);若實作者判斷必須,**停下回報**(需改 `technical-preferences.md`,須請示)。
4. cue 表是否放資料檔:已預設是(專案規則:設定值不硬編)。

## Out of Scope

音樂(story-004)、手牌/階段切換/游標 tick/打字機等「可以沒有」的音效、素材取得與授權登記、ducking。
