# Story 001:AudioBus 結構、音量與靜音設定、設定檔持久化(含既有 EGM 與隱藏好感度兩開關)

> **Epic**: `production/epics/audio-foundation/EPIC.md`
> **Status**: Ready(2026-11-06 管理者裁決「做一個小設定檔,音量與既有兩個開關都記住」,解除原 Blocked)
> ✅ **2026-11-10 加註(管理者核准整批加註):已完成,提交 `3623d98`(2026-11-06)。** 本狀態欄當時未同步;以此為準。
> **Type**: Logic(headless 只驗「決策」與純函式;見 AC 說明)
> **需求來源**: `docs/reviews/minimal-audio-scope-draft-2026-11-06.md` 第四節需求 1、2、3;管理者 2026-11-06 裁決
> **指派**: `godot-gdscript-specialist`(`.gd`);Bus 配置方式請 `godot-specialist` 確認
> **前置**: 無

## 範圍

1. **音量與靜音資料**:在 `GameSettings` 新增四個欄位(主音量、音樂、音效、靜音),線性 0.0~1.0,讀寫方法比照既有 `is_hide_affinity_display` / `set_hide_affinity_display`。預設值保守(首次啟動不得突然大聲),**預設數值是未驗證初值**,寫成具名常數,家中實聽後可能調。
2. **AudioBus 結構**:至少 `Music`、`SFX`、`UI` 三條子 bus,皆送往 `Master`。建立方式(`default_bus_layout.tres` 或執行期 `AudioServer.add_bus`)**未驗證,實作者須以 `docs/engine-reference/godot/` 或 headless 探針確認**後選一種並在檔頭說明理由。若選執行期建立,須冪等(重複呼叫不重複加 bus)。
3. **音量套用**:純函式(線性 → dB;靜音 → 靜音決策)與一個薄的「套用到 AudioServer」入口。`AudioServer.set_bus_volume_db` / `set_bus_mute` / `get_bus_index` / `linear_to_db` 的簽章與 headless 行為**皆未驗證**,須探針確認。
4. **設定檔持久化(2026-11-06 裁決)**:六項設定一起存——新增的四項音訊 + **既有的** EGM(`_egm_enabled`)與隱藏好感度(`_hide_affinity_display`)。
   - 檔案:`user://settings.cfg`,格式 `ConfigFile`(`encode_to_text`/`parse` 簽章**未驗證**,探針確認)。**路徑可注入**。
   - 純函式編解碼(設定 ⇄ 文字)與檔案薄殼分離,薄殼是唯一碰 `user://` 的程式。
   - **寫入時機**:任一 setter 被呼叫(且持久化已啟用)就立即存檔。不做「離開時才存」,避免異常結束遺失。
   - **載入時機與啟動接點(第 4 題定案,職權內)**:`project.godot` 的 `run/main_scene` 是 `res://src/ui/shell/TitleScreen.tscn`,即**每次啟動的唯一入口就是標題畫面**。定案:`TitleScreen._ready()` 呼叫一次 `GameSettings.boot_load()`(冪等,靠 static 旗標),該函式啟用持久化、讀檔、冪等建立 bus、套用音量。
     - 理由:不需要 Autoload(不動 `technical-preferences.md` Autoload 表、不讓所有測試場景多一個啟動項);啟動入口已被 `project.godot` 事實確定。
     - **被跳過的替代方案**:①Autoload —— 需改文件、每個測試場景都啟動,且本專案已有「Autoload 跨測試共用」風險登記;②`GameRoot` —— 查證 `GameRoot` 並非開機場景(開機場景是 TitleScreen),掛那裡不會被執行;③`SceneRouter` —— 開機時沒經過路由。
     - **已知代價(接受並須寫入程式註解)**:直接從編輯器以 F6 單獨跑戰鬥/設定場景時不經標題畫面,不會載入設定檔(用預設值)。
5. **啟動前的既有行為不變**:`BattleScreen` 仍只在 `_ready()` 讀一次 EGM 與隱藏好感度(`battle_screen.gd` 第 1710~1711 行),本 story 不改該檔。
6. **註解更新**:`GameSettings` 類別註解中「跨啟動不持久化」「已知代價 第 1 點」「存檔系統(第三條路)已被排除」等段落,依 2026-11-06 管理者裁決改寫為現況(設定檔持久化、不經 ADR-0004 存檔系統),並保留歷史脈絡一句。`reset_for_test()` 的說明補上「同時關閉持久化」。

## 測試污染風險(協調者要求查證,結論)

查證指令:`grep -rn "GameSettings\." src tests`(2026-11-06)。**現況**:`GameSettings` 為純記憶體 static var;`src/` 只有兩個讀端(`settings_screen.gd`、`battle_screen.gd` 第 1710~1711 行)與兩個寫端(`settings_screen.gd` 第 84、89 行)。`tests/` 有 8 個檔案寫入設定,**全部**以 `reset_for_test()` 收尾,慣例已建立。

**加入持久化後新增的兩種污染路徑**:

1. 🔴 **測試經 `TitleScreen`/`SceneRouter` 觸發啟動接點。** 查證:`tests/` 中有 10 個檔案載入 `TitleScreen.tscn` 或呼叫 `SceneRouter`(`title_screen_*`、`scene_router_test`、`tutorial_sequence_test`、`campaign_*` 等)。`TitleScreen._ready()` 是新啟動接點,**這些測試會執行到它**;若它真的讀寫 `user://settings.cfg`,則某測試寫入的值會被下一支測試(或開發者真實設定檔)讀到。
2. **某測試呼叫 setter 時,若持久化已啟用則寫檔。** 且 `reset_for_test()` 若把預設值寫回檔案,會洗掉開發者真實設定。

**防法(皆須成為 AC,見下):**

- 持久化**預設關閉**,只有 `boot_load()` 才啟用;setter 只在「已啟用」時寫檔。
- `boot_load()` 在 headless 下是 **no-op**(判斷方式例如 `DisplayServer.get_name() == "headless"`——**未驗證,須探針確認**;GdUnit4 於本專案以 `--headless` 執行)。因此全套自動測試**零檔案讀寫**。
- `reset_for_test()` 恢復預設值並**關閉持久化與清除「已載入」旗標,且絕不寫檔**。
- 路徑可注入:任何需要檔案行為的程式(探針、未來開窗證據驅動器)必須注入暫存路徑,**禁止使用預設的 `user://settings.cfg`**。
- ⚠️ 開窗執行的證據驅動器(例如 `prototypes/` 的截圖驅動)若載入 `TitleScreen` 會讀寫開發者真實設定檔;驅動器須先 `reset_for_test()` 或注入暫存路徑。此為紀律要求,**無自動檢查**。

## Affected Files

程式(新檔直接建;既有檔限下列範圍):

- `src/core/settings/game_settings.gd` —— 既有檔:四個新欄位、讀寫方法、`boot_load()`、持久化開關與路徑注入、`reset_for_test()`、**類別註解改寫**(註明依 2026-11-06 裁決)。EGM 與隱藏好感度的 setter 加上「已啟用則存檔」。
- `src/ui/shell/title_screen.gd` —— 既有檔:`_ready()` 僅加一行 `GameSettings.boot_load()` 呼叫與說明註解
- `src/core/audio/audio_buses.gd` —— 新檔:bus 名稱常數、`volume_to_db`、`ensure_buses()`、`apply_settings()`
- `src/core/settings/settings_codec.gd` —— 新檔:純編解碼,壞資料回預設
- `src/core/settings/settings_file_store.gd` —— 新檔:唯一碰 `user://` 的薄殼
- `default_bus_layout.tres` —— 僅當探針後選靜態配置(新檔,專案根)

既有的兩個開關讀寫處(**不改,僅確認相容**):`src/ui/shell/settings_screen.gd`(第 58~59、83~89 行)、`src/ui/battle/battle_screen.gd`(第 1710~1711 行)。

測試(新檔):

- `tests/unit/core/settings/game_settings_audio_test.gd`
- `tests/unit/core/settings/settings_codec_test.gd`
- `tests/unit/core/settings/game_settings_persistence_guard_test.gd`
- `tests/unit/core/audio/audio_buses_test.gd`

可能因本 story 而需動的既有測試(以實跑為準,有意識改、不得刪):`tests/unit/core/settings/game_settings_hide_affinity_test.gd`、`tests/integration/ui/shell/egm_setting_test.gd`。

不得動:`project.godot`(除非 bus 設定必須改,**先問**)、`src/gameplay/**`、`battle_screen.gd`、`scene_router.gd`。

## Acceptance Criteria

說明:headless 下音訊輸出是 no-op。**只驗決策值,不得寫「真的響了/真的靜音了」的斷言。**

- [ ] **AC-1 預設保守**:重置後四個音訊欄位等於具名預設常數;靜音預設 false;主音量預設不超過 1.0。**[自動]**
- [ ] **AC-2 範圍夾制**:寫入 <0 或 >1 被夾制到 [0,1],不報錯。**[自動]**
- [ ] **AC-3 純函式**:`volume_to_db(1.0)` = 0 dB;`volume_to_db(0.0)` 為文件化的靜音等價值,不得 NaN/無限大;單調遞增。**[自動]**
- [ ] **AC-4 靜音決策**:靜音開啟時「各 bus 應套用的靜音旗標」為 true,且三個音量值不被改寫。**[自動]**
- [ ] **AC-5 bus 結構**:三條子 bus 名稱等於常數、送往 `Master`、`ensure_buses()` 冪等。**[自動]**,但 headless 下 `AudioServer` 可否讀回 bus 資料未驗證:先探針;不可讀回則降為靜態檢查並在回報揭露。
- [ ] **AC-6 編碼往返**:六項設定(含 EGM、隱藏好感度)編碼再解碼逐項相等。**[自動]**
- [ ] **AC-7 壞資料不崩潰**:空字串、亂碼、缺鍵、非數值、超範圍皆回預設,不 `push_error` 洗版;**缺某一鍵只讓那一鍵回預設,其他鍵保留**。**[自動]**
- [ ] **AC-8 舊檔相容**:只含 EGM 與隱藏好感度、沒有音訊鍵的文字,解碼後音訊欄位為預設。**[自動]**
- [ ] **AC-9 持久化預設關閉**:重置後呼叫 setter,存檔薄殼的寫入呼叫次數為 0(以注入假薄殼/假寫入 `Callable` 驗證)。**[自動]**
- [ ] **AC-10 啟用後寫入**:注入假薄殼並啟用後,任一 setter(含 EGM、隱藏好感度)恰觸發一次寫入,內容為完整六項。**[自動]**
- [ ] **AC-11 reset 不寫檔**:啟用持久化後呼叫 `reset_for_test()`,寫入次數仍為 0,且持久化回到關閉。**[自動]**
- [ ] **AC-12 headless 啟動接點為 no-op**:headless 下 `boot_load()` 不讀不寫(注入假薄殼驗證呼叫次數為 0)。**[自動]**(headless 判斷方式須先探針確認)
- [ ] **AC-13 啟動接點冪等**:`boot_load()` 連續呼叫兩次,載入只發生一次。**[自動]**
- [ ] **AC-14 檔案層(薄殼)**:讀不到檔 = 回預設;寫入失敗不崩潰。單元測試**不得寫檔**,以拋棄式探針 `prototypes/audio-settings-file-probe-<日期>/` 實跑留原始 log(**此為管理者/協調者 2026-11-06 的定案,不再請示**)。須在探針中以暫存路徑跑「寫 → 讀 → 往返相等」並貼出引擎原始輸出行。
- [ ] **AC-15 既有行為不變**:全套既有測試仍綠(特別是 EGM 與隱藏好感度相關的 8 個檔案)。
- [ ] 🔴 交付硬性義務(`CLAUDE.md` 2026-10-12 裁決):全套 `GODOT_BIN=<引擎路徑> ./tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行;先查 exit code 再 grep(exit 105 兩個 grep 皆空)。
- [ ] 敏感度證明:至少對 AC-2、AC-9、AC-11 各一次故意改壞轉紅,注入標記驗收前清乾淨。

## Test Evidence

`tests/unit/core/settings/`、`tests/unit/core/audio/`;AC-14 探針 log 放 `prototypes/` 該目錄(注入暫存路徑,**不碰開發者真實 `user://settings.cfg`**)。預設音量是否合適由管理者在家確認,結果記入 EPIC Open Questions。

## 未決點(停下回報,不得自行裁決)

1. 預設音量具體數值(未驗證初值)。
2. headless 判斷方式與 `ConfigFile` 往返行為探針結果若與本檔假設不符,停下回報。
3. 若實作者判斷啟動接點必須用 Autoload,**停下回報**(需改 `technical-preferences.md`,須請示)。

## Out of Scope

設定畫面 UI(story-002)、播放服務(story-003)、音樂(story-004)、素材、戰役進度或其他資料的存檔、`game-shell/story-002` 原文的更新(由協調者另行請示)。
