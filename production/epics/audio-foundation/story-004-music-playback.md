# Story 004(可選):音樂播放(標題/戰鬥循環、淡入淡出)

> **Epic**: `production/epics/audio-foundation/EPIC.md`
> **Status**: Blocked(前置 story-001、003;且必須先裁決未決點 1)。**可選**,可延後。
> ✅ **2026-11-10 更新(管理者核准加註)**:Status 改為 **Ready**。未決點 1 已裁決「甲:掛最外層,不加常駐物件(推薦)」(見下方未決點 1 加註);前置 story-001、003 已完成。原句保留。
> ✅ **2026-11-10 加註(管理者核准整批加註):已完成,提交 `ccdf11b`(含「選單打開時音樂繼續播」修正)。** 曲目表目前為空(授權未辦),聽感待在家。
> **Type**: Logic + Integration
> **需求來源**: `docs/reviews/minimal-audio-scope-draft-2026-11-06.md` 第二節 2.3、第四節需求 6
> **指派**: `godot-gdscript-specialist`;架構判斷 `godot-specialist`
> **前置**: story-001、story-003

## 範圍

1. 場景 → 音樂曲目對應(標題 / 戰鬥各一首循環曲,對話場景預設靜音),放資料檔 `assets/data/audio/music_tracks.csv`(`scene_key,path,fade_in_ms,fade_out_ms`)。〔✅ 2026-11-06 更正(管理者核准加註):檔名必須改用 `assets/data/audio/music_tracks.txt` —— `.csv` 會被 Godot 當翻譯檔匯入(story-003 已實際踩到),見 `.claude/docs/coding-standards.md`「Data files under `assets/` must not use the `.csv` extension」。本檔其餘 `.csv` 字樣一律照此讀。〕
2. 決策核心(純):給定「前一場景曲目、新場景曲目、素材是否存在、靜音」→ 動作列舉(保持/淡出後切換/淡入/靜默)。**同一首曲目跨場景不重啟**。
3. 素材缺席同 story-003:安靜無錯。
4. 循環:`.ogg` 的 loop 匯入旗標是否能無縫、`AudioStreamOggVorbis.loop` 屬性名稱與 4.7.1 行為**未驗證,實作者須以引擎參考或探針確認**。
5. 淡入淡出用 `Tween` 或 bus 音量,方式與 headless 行為未驗證。

## Affected Files

- `assets/data/audio/music_tracks.csv` —— 新檔
- `src/core/audio/music_policy.gd` —— 新檔,純決策
- `src/ui/audio/music_player_host.gd` —— 新檔,播放殼
- 場景切換接點(`src/ui/shell/scene_router.gd` 或各畫面 `_ready`)—— **未決點 1 未定,不在清單內,要先問**
  - ✅ **2026-11-10 加註(管理者核准「可以,兩處都改後開工(推薦)」)**:納入範圍 —— `src/ui/shell/scene_router.gd`(`switch_to`/`_perform_swap` 呼叫冪等的確保宿主)與 `src/ui/shell/title_screen.gd`(開機場景不經 SceneRouter,自行確保一次)。宿主掛 `tree.root`,不新增 Autoload,故 `project.godot` 與 `technical-preferences.md` **不在範圍**。
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

1. ✅ **2026-11-10 已裁決**:管理者選「**甲:掛最外層,不加常駐物件(推薦)**」(被跳過:乙 全域常駐物件 / 先不做)。依據 `prototypes/music-host-and-ogg-loop-2026-11-10/README.md`(godot-specialist):`SceneRouter` 是純靜態、不持有節點,`GameRoot.tscn` 無任何載入者 —— 原文「掛在路由持有的根節點(GameRoot)」前提不成立,改掛 `tree.root`;在 `_ready()` 內對 root `add_child` 須 `call_deferred`;測試須自行清掉 `/root` 上的宿主。同 README:`AudioStreamOggVorbis.loop`/`loop_offset` 屬性名稱、`.import` loop 旗標生效、headless 下 Tween 推進 `volume_db` 皆 (A) 級實測(範圍第 4、5 點的「未驗證」據此部分解除;無縫與否仍須耳聽)。原文保留如下。
   原文:🔴 **音樂跨場景存活需要常駐宿主。** `SceneRouter` 是自製路由(不用 `change_scene_to_file`),宿主可掛在路由持有的根節點(`GameRoot`)而不經 Autoload,或註冊 Autoload。兩者取捨:後者簡單但觸發 `technical-preferences.md` Autoload 表更新(文件需請示)、全測試場景啟動、跨測試共用狀態風險;前者不增 Autoload,但需確認所有畫面都經 `GameRoot`(**未查證**)。**需先請 `godot-specialist` 與管理者判斷,不得自行選。**
2. 曲目與素材尚不存在、授權紀錄未派工。
3. 對話場景音樂策略(靜音 / 沿用),依草案為「可沒有」,預設靜音。

## Out of Scope

勝敗 stinger(屬 story-003 的 M7/M8)、動態音樂、ducking、素材製作。
