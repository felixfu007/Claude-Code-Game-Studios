# Story 002:`CardDeck` 三項旋鈕資料驅動化

**Status**: ✅ Done(2026-11-04;原為 Ready)
> 提交:3441c61(協調者重跑全套驗收)
**Epic**: `production/epics/tuning-data/EPIC.md` · **Type**: Logic + Integration · **規劃檔步 1**
**Depends On**: story-001

## 依據(管理者 2026-11-04 裁決,逐字)

- 「現在搬(推薦)」
- 「大聲報錯(推薦)」= 方案 B(設定物件 + 注入,資料檔錯誤明確失敗)
- 搬的常數(規劃檔 §1.1):`OPENING_HAND_SIZE`(5)、`HAND_SIZE_LIMIT`(5)、`CARDS_DRAWN_PER_TURN`(1)

## 設計約束

- 新增 `DeckTuning`(不可變 `RefCounted`,`defaults()` = 今日值,`from_text` 驗證:三項皆 ≥ 1 的整數、`OPENING_HAND_SIZE <= HAND_SIZE_LIMIT + CARDS_DRAWN_PER_TURN` 之類不變式由實作者依 `card_deck.gd` 現有規則推導並寫進驗證,**推導不出者停下來問**)。
- `CardDeck.new(cards, rng)` 增末位可選參數 `tuning: DeckTuning = null`(`null` → `defaults()`);`draw_for_turn` 等方法照用持有的設定。
- 資料檔鍵加進 `assets/data/tuning/tuning_knobs.txt`(`deck,opening_hand_size,5` 等),並登錄進 story-001 的已知鍵清單。
- 常數 `OPENING_HAND_SIZE`/`HAND_SIZE_LIMIT`/`CARDS_DRAWN_PER_TURN` 處置:**實作者擇一並在交付報告說明**——(a) 刪除並改所有引用;(b) 暫留為 `defaults()` 的來源。不得讓兩處各寫一份數字。
- ⚠️ UI 耦合:`battle_screen.gd`、`hand_bar.gd` 以 `CardDeck.HAND_SIZE_LIMIT` 排版與顯示「n/5」。資料驅動後須改讀注入的設定,**驗收須證明手牌列在 `HAND_SIZE_LIMIT` 變動時仍正確**(版面壞了視為本張缺陷,不得推給後續)。

## Affected Files(範圍;範圍外一律先問)

**新增**:`src/gameplay/tuning/deck_tuning.gd`、`tests/unit/gameplay/tuning/deck_tuning_test.gd`、`assets/data/tuning/test_fixture_tuning_deck_hand3.txt`(夾具:`HAND_SIZE_LIMIT=3` 等)、`tests/integration/ui/battle/battle_screen_deck_tuning_wiring_test.gd`

**修改既有程式碼檔(src)**:
`src/gameplay/cards/card_deck.gd`、`src/gameplay/tuning/tuning_knobs.gd`、`src/gameplay/battle/battle_state.gd`、`src/gameplay/battle/battle_controller.gd`、`src/gameplay/battle/battle_loop.gd`、`src/ui/battle/battle_screen.gd`、`src/ui/battle/hand_bar.gd`、`assets/data/tuning/tuning_knobs.txt`(資料檔)

**修改既有測試檔(僅限直接引用 `CardDeck.HAND_SIZE_LIMIT`/`OPENING_HAND_SIZE` 的斷言或呼叫端)**:
`tests/unit/gameplay/cards/card_deck_test.gd`、`tests/integration/gameplay/cards/card_battle_wiring_test.gd`、`tests/integration/gameplay/cards/card_forced_discard_gate_test.gd`、`tests/integration/ui/forced_discard_test.gd`、`tests/integration/ui/battle/battle_screen_card_play_wiring_test.gd`、`tests/integration/ui/battle/battle_screen_real_level_battle_test.gd`、`tests/integration/ui/battle/battle_screen_playtest_feedback_2026_10_28_test.gd`、`tests/unit/ui/hand_bar_test.gd`

其餘 `tests/**` 中呼叫 `CardDeck.new(...)` 的檔案(清單見 `grep -rlw CardDeck tests`)**因簽名只加可選參數而不應需要改**;若某檔必須改,先問。

## 驗收條件

1. **零行為變更**:`defaults()` 三值逐個等於今日常數;初始資料檔內容等於 `defaults()`;全套 `Overall Summary` 除新增測試數外與動工前逐字相同。
2. **敏感度證明(走真實流程)**:以夾具(`HAND_SIZE_LIMIT=3`)注入真實 `BattleScreen`,斷言**可觀測行為**改變(例:手牌上限觸發強制棄牌的時機、手牌列槽數);常駐 `test_sensitivity_proof_*`。
3. **資料檔錯誤大聲報錯**:缺鍵、非整數、`HAND_SIZE_LIMIT=0`、違反不變式各一條,`from_text` 回 `null` 且 `push_error`;`BattleScreen` 對壞檔明確失敗。
4. **「忘了把設定傳下去」的防線**:證明 `CardDeck` 在 `BattleScreen` 真實路徑下用的是**注入的**設定而非 `defaults()`(驗收 2 即是此證明;不可只靠 `CardDeck` 單元測試)。
5. 簽名只加末位可選參數;`prototypes/story-u011-hand-bar-evidence-2026-09-17/evidence_driver.gd` 與 `prototypes/godot-specialist-u013-worldlayer-attribution-2026-09-23/probe_worldlayer_attribution.gd` 引用 `CardDeck.HAND_SIZE_LIMIT`:若刪除該常數則它們會壞——這兩支為已簽的歷史證據,**不得動**,故若選 (a) 須先問;**預設建議選 (b) 暫留常數作 `defaults()` 來源**。
6. 交付含 `ENGINE EXIT`、`Overall Summary` 原始三行。

## `combat_rules_guard_test.gd` 釘死值

不適用(屬 story-004)。
