# Story 005:好感度「扣分」另配一個音(affinity_down)

> **Epic**: `production/epics/audio-foundation/EPIC.md`
> **Status**: Ready(2026-11-10 協調者起草;管理者裁決見下)
> ✅ **2026-11-11 加註(管理者核准狀態欄加註):已完成,提交 `09336bd`(2026-11-10)。** 聽感待家中試聽。原句保留。
> **Type**: Logic + Integration
> **指派**: `godot-gdscript-specialist`
> **前置**: story-003(音效提示服務,已完成 `e9583b6`;9 個 CC0 素材 `781a990`)

## 裁決來源

管理者 2026-11-10 逐字選項:「**丙:扣分另配一個音(推薦)**」(被跳過:甲 只有加分才響 / 乙 維持現狀)。
問題查證(game-designer,2026-11-10,只讀):
- `src/ui/audio/sfx_player_host.gd` 的 `_on_entry_appended(_pair, _record)` 不看紀錄,一律播 `affinity_up`。
- 紀錄帶正負號:`src/gameplay/affinity_pool/affinity_record.gd` 的 `m`(非零有限浮點)。
- 實戰負向來源:每場卡表都有 `card_08,PERMANENT_AFFINITY_WRITE,...,-2,...`(例 `assets/data/cards/vs01_cards.txt` 第 87 行,協調者已核)。

## 範圍

1. 新 cue `affinity_down`:`SfxCueTable` 新常數並列入必要清單;`assets/data/audio/sfx_cues.txt` 新增一列
   `affinity_down,res://assets/audio/sfx/sfx_affinity_down_01.ogg,300,SFX`(間隔同 affinity_up)。
2. `_on_entry_appended`:`record.m > 0` → `affinity_up`;`record.m < 0` → `affinity_down`(池已拒絕 0/NaN/inf,無第三種)。
3. 素材:協調者複製 Kenney Interface Sounds `Audio/minimize_003.ogg` → `assets/audio/sfx/sfx_affinity_down_01.ogg`(依檔名初選,待試聽),並在 `assets/audio/sfx/LICENSES.md` 入庫表加一列。**這兩件由協調者做,實作者不碰音檔與 LICENSES。**

## Affected Files

- `src/core/audio/sfx_cue_table.gd`
- `src/ui/audio/sfx_player_host.gd`
- `assets/data/audio/sfx_cues.txt`
- `tests/unit/core/audio/sfx_cue_policy_test.gd`、`tests/unit/core/audio/sfx_cue_table_test.gd`(若存在)、`tests/integration/ui/battle/battle_sfx_wiring_test.gd`(只為新 cue 補/改斷言;9 → 10 的計數斷言)

## Acceptance Criteria

- [ ] **AC-1**:正向紀錄 append → 只請求 `affinity_up`。**[自動]**
- [ ] **AC-2**:負向紀錄 append → 只請求 `affinity_down`,不請求 `affinity_up`。**[自動]**
- [ ] **AC-3**:`affinity_down` 列入必要 cue;真實表 10 個路徑 `ResourceLoader.exists()` 皆 true。**[自動]**
- [ ] **AC-4**:靜音時兩者皆不播(沿用既有靜音路徑)。**[自動]**
- [ ] 敏感度證明:AC-2 一次(把分支改回一律 up → 紅 → 還原)。
- [ ] 🔴 交付硬性義務:全套跑完,貼 `ENGINE EXIT`、`Overall Summary`、`Executed test suites` 原始三行。
- 聽感(這個音像不像「下降」)不可自動化,家中試聽。

## Out of Scope

依幅度大小分音、支援對話(戰鬥外)的音效、開局灌入的關係線(灌入時音效尚未接線 —— 【推測】,未驗)。
