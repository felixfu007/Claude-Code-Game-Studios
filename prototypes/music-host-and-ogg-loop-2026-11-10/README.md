# 音樂宿主與 OGG 循環探針 (2026-11-10)

狀態:concluded。對應 `production/epics/audio-foundation/story-004-music-playback.md` 範圍第 4、5 點與未決點 1。
引擎:Godot 4.7.1 console,一律 `--headless`。參考庫 `docs/engine-reference/godot/` 對 `AudioStreamOggVorbis` 零命中(無 (B) 級來源)。
候選檔只讀(`C:/tmp/aiimg27/.../mus_battle_main_loop_c01.ogg`),未複製進本倉庫;Q2 匯入流程探針把它複製到系統暫存目錄的拋棄式專案(scratchpad/oggproj)。

## Q1 常駐宿主(靜態查證,(C)/(B) 級:讀程式碼,未跑引擎)

工單未決點 1 的前提**不成立**:不存在「路由持有、切換期間不釋放的 GameRoot」。
- `src/ui/shell/scene_router.gd` `_perform_swap()`:`old.get_parent().remove_child(old)` + `old.queue_free()`,再 `tree.root.add_child(instance)`、`tree.current_scene = instance`。每個畫面都是 `/root` 的直接子節點,切換時整個被釋放。`SceneRouter` 是 `RefCounted` 純靜態,不持有任何節點。
- `src/ui/GameRoot.tscn` 存在,但 `grep GameRoot` 在 `src/**/*.gd`、`project.godot` 皆無載入者(只有註解)。
- 現有先例:`SfxPlayerHost.attach_to(instance)` 在 `scene_router.gd` `switch_to()`(進樹前)與 `title_screen.gd:99`(開機場景)各掛一份,**隨場景釋放**,所以 SFX 可以,音樂不行(會隨場景被砍斷)。

場景切換點全清單(`grep change_scene_to|reload_current_scene|main_scene` 於 src/、project.godot):
- 啟動:`project.godot:14 run/main_scene="res://src/ui/shell/TitleScreen.tscn"` —— **不經 SceneRouter**。
- 唯一的 `add_child` 到 root + 換 current_scene:`scene_router.gd` `_perform_swap`(經 `switch_to`)。
- 呼叫 SceneRouter 的:`title_screen.gd:171/177/183`(戰役/教學/設定)、`settings_screen.gd:149`(回標題)、`battle_screen.gd:5291/5294/5302/5304/5325/5341`(下一場、支援對話、回標題)、`battle_menu.gd:809`(回標題)、`scene_router.gd` `go_to_support_conversation` 的 `_enter_battle_after_conversations`(對話後進戰鬥)。
- `get_tree().quit()`:`title_screen.gd:191`、`battle_menu.gd:794`(離開遊戲,不是切換)。
- `change_scene_to_*`、`reload_current_scene`:src/ 內**零個實際呼叫**(僅註解提及)。
- 未查:`tests/`、`tools/`、`prototypes/` 內的切換(非 production 路徑)。

結論:除開機那一次外,所有切換都經 `SceneRouter.switch_to`,但沒有現成的常駐節點。

**建議(技術面,最終由管理者裁決)**:
- 偏好 **(甲')**:宿主掛在 `tree.root`(Window,永不釋放)而非「GameRoot」。做法:`SceneRouter._perform_swap`(或 `switch_to`)呼叫 `MusicPlayerHost.ensure_on_root(tree)`,冪等(`root.get_node_or_null` 已有就不重建)。開機場景 `TitleScreen` 與 SFX 先例相同需自行確保一次;注意 `_ready()` 內對 root `add_child` 會被引擎拒絕(scene_router 檔頭已記),須 `call_deferred`。不增 Autoload、不動 `project.godot` 與 technical-preferences,不污染所有測試場景。
- 代價:宿主存活依賴「每次切換/開機都有人呼叫 ensure」,漏掉一條入口就靜默沒音樂(已查證入口只有 SceneRouter + main_scene 兩處);測試要自行清掉掛在 `/root` 的宿主以免跨測試殘留(孤兒/共用狀態)。
- (乙)Autoload 較不易漏入口,但依工單與 technical-preferences:要改 `project.godot` + Autoload 表(文件須請示)、每個測試場景都啟動、`class_name` 不可與 Autoload 同名。若管理者重視「不可能漏」勝過「不增 Autoload」,(乙)可行。
- 宿主不是純靜態類別就必須是 Node,所以「SceneRouter 持有」並不成立,只能掛 root 或 Autoload。

## Q2 OGG 循環

探針:`probe_q2_ogg_props.gd`,原始輸出 `run_output_q2.txt`。(A)
- `Q2 fresh: loop=false loop_offset=0.0 length=0.0`(新建實例;另有 `get_length` 對空 packet_sequence 的引擎 ERROR,屬 `new()` 未載入的預期)
- `Q2 props: ["packet_sequence", "bpm", "beat_count", "bar_beats", "tags", "loop", "loop_offset"]` —— 屬性名稱確為 `loop`、`loop_offset`(預設 false / 0.0)。
- `Q2 file: loop=false loop_offset=0.0 length=96.0001831054688 bpm=0.0` —— `load_from_file()` 在 4.7.1 可用,候選 c01 長 96.0 秒,loop 預設 false。
- `Q2 after set: loop=true loop_offset=1.5` —— 執行期可設。

匯入流程:探針 `probe_q2_import.gd`(於拋棄式專案),輸出 `run_output_q2_import.txt`。(A)
- 預設 `.import`:`importer="oggvorbisstr"`、`loop=false`、`loop_offset=0`、`bpm=0`、`beat_count=0`、`bar_beats=4`。
- 載入:`loop=false ... length=96.0001831054688`;把 `.import` 的 `loop=false` 改 `true` 後重匯入 → `Q2I class=AudioStreamOggVorbis loop=true`。即 **`.import` 的 `loop` 旗標會到達 `AudioStreamOggVorbis.loop`**。
- 我的 sed 沒改到 `loop_offset`(`.import` 寫 `0` 非 `0.0`),所以 import 路徑的 `loop_offset` **未驗**。

**不能宣稱**:循環是否無縫(需耳聽,headless 無音訊輸出);候選曲首尾是否真為循環點。

## Q3 淡入淡出

探針 `probe_q3_tween.gd`,輸出 `run_output_q3.txt`。(A)
- `Q3 start volume_db=-40.0` → `frame 1 -40.0` → `frame 5 -16.9986686706543` → `frame 10 -12.968770980835` → `Q3 end frames=25 ms=956 volume_db=0.0 running=false`。
- `Q3 node-bound tween final volume_db=-40.0`(節點綁定 tween 亦推進完畢)。
- 結論:headless 下 Tween 對 `AudioStreamPlayer.volume_db` 會依 process_frame 推進並到達終值。注意 headless 幀時間:0.3 秒的 tween 實際花約 956 ms 牆鐘(25 幀),測試別用牆鐘斷言,用幀數/終值。

## 未驗項
- Q1:`tests/`、`tools/` 內的切換未查;「ensure_on_root 掛 root 於 `_perform_swap` 的時機與 `queue_free` 舊場景無互撞」未實測。
- Q2:`.import` 的 `loop_offset` 非零值路徑;實際無縫與否;`bpm/beat_count` 相關行為;匯出版本(export)是否保留 loop 旗標。
- Q3:實音訊輸出下的聽感/爆音;bus 音量淡化方案未測(只測了 player.volume_db)。
