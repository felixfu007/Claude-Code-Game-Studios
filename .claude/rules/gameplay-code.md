---
paths:
  - "src/gameplay/**"
---

# Gameplay Code Rules

- ALL gameplay values MUST come from external config/data files, NEVER hardcoded
- Use delta time for ALL time-dependent calculations (frame-rate independence)
- NO direct references to UI code — use events/signals for cross-system communication
- Every gameplay system must implement a clear interface
- State machines must have explicit transition tables with documented states
- Write unit tests for all gameplay logic — separate logic from presentation
- Document which design doc each feature implements in code comments
- No static singletons for game state — use dependency injection
  > ✅ **2026-10-19 管理者裁決:兩項明文例外(逐字選項「明文登記為專案級例外(推薦)」)。**
  > 被跳過的兩個:「不管(字面上不違規)」、「改成注入式」。
  >
  > | 檔案 | 它持有什麼 | 為什麼准 |
  > |---|---|---|
  > | `src/core/settings/game_settings.gd` | EGM 開關(本次執行期間有效) | 下方三點共通 |
  > | `src/core/campaign/campaign_progress.gd` | 目前第幾場關卡 | 下方三點共通 |
  >
  > 1. 🔴 **本規則檔檔頭 `paths:` 只套用 `src/gameplay/**`,而這兩個檔都在 `src/core/`**
  >    —— **字面上本來就不在管轄範圍內。登記例外不是因為它們違規,是因為
  >    「它在別的目錄所以不算」這個理由【沒有寫在任何地方】**,下一個人讀到這條規則
  >    再看到那兩個檔,只會以為規則被無視了。
  > 2. **真正的技術理由**:改成注入式要動到場景切換那一層,而
  >    `change_scene_to_file()` **沒有資料注入的時機窗**(實測,見
  >    `production/epics/game-shell/story-003-...md` 查核三)。注入式在這個位置做不到。
  > 3. **緩解措施已就位**:兩者都提供 `reset_for_test()`,且都有測試釘住「重置真的還原」。
  >    ⚠️ **靜態狀態跨測試共用的風險仍然存在**,實測證據在
  >    `prototypes/godot-specialist-static-var-probe-2026-10-19/README.md`
  >    (**真的用兩個獨立的 GdUnit4 測試檔案量到狀態洩漏**,不是常識帶過)。
  >
  > 🔴 **這是例外,不是放寬。** `src/gameplay/**` 底下仍然一個都不准。
  > **再要第三個,請重新裁決,不要援引本條。**

## Examples

**Correct** (data-driven):

```gdscript
var damage: float = config.get_value("combat", "base_damage", 10.0)
var speed: float = stats_resource.movement_speed * delta
```

**Incorrect** (hardcoded):

```gdscript
var damage: float = 25.0   # VIOLATION: hardcoded gameplay value
var speed: float = 5.0      # VIOLATION: not from config, not using delta
```
