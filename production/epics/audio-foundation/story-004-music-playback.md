# Story 004(可選):音樂播放(標題/戰鬥循環、淡入淡出)

> **Epic**: `production/epics/audio-foundation/EPIC.md`
> **Status**: Blocked(前置 story-001、003;且必須先裁決未決點 1)。**可選**,可延後。
> **Type**: Logic + Integration
> **需求來源**: `docs/reviews/minimal-audio-scope-draft-2026-11-06.md` 第二節 2.3、第四節需求 6
> **指派**: `godot-gdscript-specialist`;架構判斷 `godot-specialist`
> **前置**: story-001、story-003

## 範圍

1. 場景 → 音樂曲目對應(標題 / 戰鬥各一首循環曲,對話場景預設靜音),放資料檔 `assets/data/audio/music_tracks.csv`(`scene_key,path,fade_in_ms,fade_out_ms`)。
2. 決策核心(純):給定「前一場景曲目、新場景曲目、素材是否存在、靜音」→ 動作列舉(保持/淡出後切換/淡入/靜默)。**同一首曲目跨場景不重啟**。
3. 素材缺席同 story-003:安靜無錯。
4. 循環:`.ogg` 的 loop 匯入旗標是否能無縫、`AudioStreamOggVorbis.loop` 屬性名稱與 4.7.1 行為**未驗證,實作者須以引擎參考或探針確認**。
5. 淡入淡出用 `Tween` 或 bus 音量,方式與 headless 行為未驗證。

## Affected Files

- `assets/data/audio/music_tracks.csv` —— 新檔
- `src/core/audio/music_policy.gd` —— 新檔,純決策
- `src/ui/audio/music_player_host.gd` —— 新檔,播放殼
- 場景切換接點(`src/ui/shell/scene_router.gd` 或各畫面 `_ready`)—— **未決點 1 未定,不在清單內,要先問**
- `project.godot`、`.claude/docs/technical-preferences.md` —— 若選 Autoload,**兩者都要動,屬文件/設定,需另行請示**
- 測試新檔:`tests/unit/core/audio/music_policy_test.gd`、`tests/integration/ui/shell/music_scene_wiring_test.gd`

## Acceptance Criteria

headless 只驗決策。

- [ ] **AC-1 同曲不重啟**:標題→標題、戰鬥→戰鬥(含連戰換場)決策為「保持」。**[自動]**
- [ ] **AC-2 切曲決策**:標題→戰鬥為「淡出後切換」,戰鬥→對話為「淡出/靜默」。**[自動]**
- [ ] **AC-3 靜音**:靜音時不送播放請求。**[自動]**
- [ ] **AC-4 素材缺席安靜**:無 `push_error`/`push_warning`、不崩潰。**[自動]**
- [ ] **AC-5 資料表**:`music_tracks.csv` 解析與壞列處理。**[自動]**
- [ ] **AC-6 Autoload 義務**(僅選 Autoload 時):`class_name` 不與 Autoload 名稱同名;Autoload 表已更新(文件經核准);全套 `tests/unit` 實跑確認無新失敗與孤兒節點。
- [ ] 🔴 交付硬性義務:全套跑完,貼 `ENGINE EXIT` 與 `Overall Summary` 三行。
- [ ] 敏感度證明:AC-1、AC-2 各一次。
- 「循環是否無縫」「淡入淡出聽感」**不可自動化**,家中耳聽驗收。

## Test Evidence

`tests/unit/core/audio/`、`tests/integration/ui/shell/`;家中聽感紀錄放 `production/qa/evidence/`。

## 未決點

1. 🔴 **音樂跨場景存活需要常駐宿主。** `SceneRouter` 是自製路由(不用 `change_scene_to_file`),宿主可掛在路由持有的根節點(`GameRoot`)而不經 Autoload,或註冊 Autoload。兩者取捨:後者簡單但觸發 `technical-preferences.md` Autoload 表更新(文件需請示)、全測試場景啟動、跨測試共用狀態風險;前者不增 Autoload,但需確認所有畫面都經 `GameRoot`(**未查證**)。**需先請 `godot-specialist` 與管理者判斷,不得自行選。**
2. 曲目與素材尚不存在、授權紀錄未派工。
3. 對話場景音樂策略(靜音 / 沿用),依草案為「可沒有」,預設靜音。

## Out of Scope

勝敗 stinger(屬 story-003 的 M7/M8)、動態音樂、ducking、素材製作。
