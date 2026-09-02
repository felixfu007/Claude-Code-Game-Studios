# 控制清單(Control Manifest)

> **引擎**:Godot 4.7.1
> **最後更新**:2026-09-02
> **清單版本**:2026-09-02
> **涵蓋 ADR**:ADR-0001、ADR-0002、ADR-0003、ADR-0005(**四份 `Accepted`**)
> **狀態**:Active —— ADR 有異動時以 `/create-control-manifest update` 重新生成

`清單版本` 是本檔生成日期。story 檔建立時嵌入此日期,`/story-readiness` 以它比對 story 是否
寫在過期規則之上。與 `最後更新` 恆為同一日期,供不同消費端使用。

本檔是從全部 `Accepted` ADR、技術偏好與引擎參考文件萃取出的**程式設計師速查表**。
ADR 解釋**為什麼**,本檔只講**做什麼 / 不准做什麼**。每條規則都標來源。

---

## 🔴 使用前必讀:本檔的涵蓋限制(2026-09-02 生成時誠實登記)

**萃取方式是「抓出四份 ADR 全部的強制語句」(不得/禁止/嚴禁/必須/一律/絕不),
不是逐頁通讀 4,445 行。** 316 行命中,逐條轉寫為下列規則。

**這對「必須/不得」型規則涵蓋良好,但用敘述句表達、不帶強制字眼的約束可能漏掉。**
因此:**本檔為速查表,不是 ADR 的替代品。** 實作某機制前仍須讀該 ADR 對應的機制節。

⚠️ **本次生成的技術總監覆核(`TD-MANIFEST`)未執行**,因精簡模式跳過。
依專案前例(`TD-ADR` 閘門九次跳過且不留痕),此處明文登記,不靜默略過。

**ADR-0004(存檔原子寫入與遷移)仍為 `Proposed`,依規則未納入本檔。**
它的 1 條禁令(`early_return_between_lock_acquire_and_release`)已在登記表中,但本檔不收錄
其規則 —— 引用該 ADR 的實作一律 BLOCKED。

---

## 基礎層規則(Foundation)

*適用於:存檔讀寫、序列化、引擎初始化*

### 必須這樣做

- **持久化 payload 一律是純 `Dictionary`**,巢狀值只能是原生 Variant 型別(`Array`/`String`/
  `int`/`float`/`bool`/`PackedByteArray` 等),**不含任何 `Object`/`Resource`** — ADR-0003
- **型別閘門採白名單制**,允許 35 項(0–22 + 27–38),判準恆為 `.has(t)` — ADR-0003
- **寫入側與讀取側必須擋同一組型別**,至少 `{23 RID, 24 Object, 25 Callable, 26 Signal}` 四項 — ADR-0003
- **閘門遞迴一律呼叫 `_walk()`**,絕不可呼叫 `_walk_body()` — ADR-0003
- **容器一律直接拒絕當鍵**,不遞迴進去看內容 — ADR-0003
- **`deserialize_manifest()` 的四步順序不得調換** — ADR-0003
- **解碼後一律用 `decoded is Dictionary` 判定成功** — ADR-0003
- **每個區塊的雜湊必須用獨立的 `HashingContext.new()` 實例**,不得跨區塊重用 — ADR-0003
- **雜湊比對一律走 `hash_matches()`**,先驗長度、長度不合法直接判失敗 — ADR-0003
- **雜湊輸入必須是固定欄位順序的 `Array`**,順序取自 `MANIFEST_ENTRY_FIELDS` 這個**單一共用
  常數**,不得另寫一份 — ADR-0003
- **型別閘門必須由 CI-blocking 單元測試呼叫並斷言** — ADR-0003

### 絕對不可以

- **絕不在存檔路徑使用 `FileAccess.store_var()` / `get_var()`** —— 兩者的第二個參數確實接受
  物件,是繞過閘門的旁路 — 禁令 `fileaccess_store_var_on_save_path` / ADR-0003
- **絕不以 `Resource` 承載存檔 payload** — 禁令 `resource_based_save_payload` / ADR-0003
- **絕不寫黑名單 or 鏈**取代白名單 — ADR-0003
- **絕不用 `!= null` 判定解碼成功** —— 全零位元組會讓它誤判 — ADR-0003
- **絕不在雜湊比對時略過長度檢查** — 禁令 `hash_compare_without_length_check` / ADR-0003
- **閘門遞迴絕不呼叫 `_walk_body()`** — 禁令 `gate_recursion_calling_walk_body` / ADR-0003
- **消費端不得**直接把 `NodePath` 當節點查找使用(該型別不被閘門拒絕,但語意不安全) — ADR-0003

### 效能護欄

- 型別閘門為單次遞迴掃描,成本與 payload 節點數成正比 — ADR-0003
- 三段式 `HashingContext` 是唯一路徑,無簡化空間 — ADR-0003

---

## 核心層規則(Core)

*適用於:戰棋查詢與結算、好感度數值池、核心玩法迴圈*

### 必須這樣做 —— 戰棋查詢原子性(ADR-0001)

- **`board_version` 只在「已提交的結算邊界」完成時 +1**。玩家移動游標、開關疊加圖、觸發預判
  等唯讀操作**一律不得**使其遞增
- **每個查詢結果攜帶它所計算的版本號**;有效性判準為 `result.version == board.board_version`
- **合成查詢的所有子結果必須攜帶同一版本號**(`assert_same_version`);任一不符,整組作廢重算
- **跨幀展開在開始時記下 `start_version`**,每次恢復時比對,不符即**中止並重算**(不是套用部分
  結果,也不是繼續用舊資料算完)
- **持有跨幀協程的物件必須是生命週期涵蓋整場戰鬥的物件**(Board 自身或戰鬥層 manager),不得
  掛在會隨場景切換 / UI 面板關閉而被釋放的暫時性節點上
- **每次 `await` 恢復後須先以 `is_instance_valid()` 確認宿主仍存活**,否則一律視為中止
- **`settlement_in_progress` 於結算步①設 `true`**,④完成(含全部跨系統呼叫回傳)後設 `false`,
  並於此時遞增 `board_version`
- **結算步執行於 `_process` 鏈**。⚠️ 放進 `_physics_process` 會讓 ADR-0005 的全部定序保證
  **靜默失效且不報錯**
- **結算進行中,所有玩家輸入一律拒絕並觸發拒絕回饋**(不採佇列)
- **`settlement_in_progress` 不得跨越兩個連續的 `_process` 幀仍為 `true`**;偵測到須以
  `push_error()` 明確曝光(可直接寫成自動化測試)
- **`occupied` 由稀疏 `Dictionary[Vector2i, int]` 承載**,只記錄有單位的格
- **佔位同步與 `board_version` 遞增在同一個原子區段內完成**
- **查詢結果攜帶的容器必須是新配置的物件**
- **需要穩定序列時須自行以固定排序鍵顯式排序**(例如先 `y` 後 `x`)

### 必須這樣做 —— 好感度數值池(ADR-0002)

- **採依賴注入,不採 Autoload 單例** —— 專案編碼標準明文要求公開方法可單元測試
- **跨檔共用列舉必須包在 `AffinityTypes` 類別裡** —— GDScript 沒有跨檔可見的裸列舉
- **所有呼叫端必須檢查 `get_at()` 回傳值是否為 `null`**,不得假設索引落在合法範圍
- **外部進入容器的鍵一律經型別化參數簽章收斂**;**值一律由本系統自身方法以靜態型別建構後賦值**
- **七個入口一律在觸碰任何容器之前**呼叫對應的私有驗證器
- **`pair_of()` 的呼叫端必須先以 `AffinityTypes.is_valid_character()` 驗證兩個參數**
- **必須先確認 `result.rejection == ReadRejection.NONE`,才可讀取任何其他欄位**
- **型別判定只能用 `typeof()`**,不可用賦值當檢查,且型別檢查必須在值域運算之前
- **`_death_marks` 刻意不預填,一律 `has()` 守衛**
- **enum ↔ 字串轉換一律用 `find_key(value)` / `enum[name_string]`**,且對來自存檔的字串必須先
  `.has()` 守衛
- **上游持有來源不明 `Variant` 時,必須在呼叫前自行驗證** —— 型別化參數的阻擋方式是**整段呼叫端
  函式中止**,不是可判斷的回傳值
- **鎖採單一進入點取鎖**,逾時清除以「假設已持鎖」的私有輔助函式實作

### 絕對不可以 —— 核心層

- **絕不以節點樹 / `get_node()` 導出佔位** — 禁令 `node_tree_derived_occupancy` / ADR-0001
  ⚠️ 具體攻擊面:`queue_free()` 延後至幀尾才移除,結算步④陣亡的單位其節點**同一步內仍在樹上**
- **絕不以動畫 / Tween 的完成狀態驅動邏輯狀態更新** — 禁令 `animation_driven_logical_state` / ADR-0001
- **絕不以視覺位置作為佔位判定依據** — ADR-0001
- **結算呼叫鏈中絕不使用 `call_deferred()` 或 `CONNECT_DEFERRED`** —— 這條**看不出 `await` 字樣**,
  程式碼審查抓不到 — 禁令 `deferred_calls_in_settlement_path` / ADR-0001
- **絕不回傳 board 內部儲存結構的參照** —— 版本戳記機制**無法防禦這條旁路** —
  禁令 `returning_internal_container_references` / ADR-0001
- **絕不依賴 `Dictionary`/`Array` 的原生迭代順序作為輸出順序** —
  禁令 `relying_on_container_iteration_order` / ADR-0001
- **絕不把盤面變動排入佇列**(本 ADR 裁定中止重算) — ADR-0001
- **絕不對可測試資料層使用 Autoload 單例** — 禁令 `autoload_singleton_for_testable_data_layers` / ADR-0002
- **絕不以可變容器當 `Dictionary` 鍵** — 禁令 `mutable_container_as_dictionary_key` / ADR-0002
- **絕不用 `keys()[value]` 位置索引做 enum → 字串轉換** —
  禁令 `enum_value_positional_string_conversion` / ADR-0002
- **絕不把裸 `Variant` 以 subscript 寫進型別化容器** —
  禁令 `raw_variant_subscript_into_typed_container` / ADR-0002
- **絕不預填 `_death_marks` 或做無守衛讀取** — 禁令 `death_marks_prefill_or_unguarded_read` / ADR-0002
- **絕不對來自存檔的字串裸用 `AffinityTypes.Pair[name]`** —
  禁令 `raw_enum_name_subscript_from_untrusted_string` / ADR-0002
- **絕不整批重新指派 `AffinityRecordList` 的項目** —
  禁令 `wholesale_reassignment_of_affinity_record_list_items` / ADR-0002
- **絕不把未驗證的角色序數傳進 `pair_of()`** — 禁令 `unvalidated_character_into_pair_of` / ADR-0002
- **絕不寫 `if t_query != null and t_query > _t_now`** —— 對 `String` 會在**比較運算子處中止
  所在函式** — ADR-0002
- **呼叫端的邏輯分支絕不依 `rule_id` 判斷**,一律只依 `rejection` — ADR-0002

### 效能護欄 —— 核心層

- 版本戳記開銷可忽略(一個 int 欄位 + 一次比較) — ADR-0001
- 稀疏佔位表記憶體與**單位數**成正比,與棋盤格數無關 — ADR-0001
- 🔴 **`reachable_set` 雙趟展開與 `threat_range_all(E)` 的 N 敵成本未量化** —— ADR-0001 明確
  **不解決**此問題,只讓跨幀攤分合法。單幀 16.6 ms 內能容納多少格 × 多少敵,**本專案未作任何宣稱**
- 好感度讀取為熱路徑,`AffinityTypes.is_valid_*()` 與內部讀快取檢查的**語意必須完全相同** — ADR-0002

---

## 呈現層規則(Presentation)

*適用於:游標/高亮、輸入處理、UI、渲染*

### 🔴 兩條隨 ADR-0005 核准生效的硬性義務

1. **游標圖層必須獨佔一顆 `CanvasLayer`**,不得與介面圖層共用。
   **誤混的實測誤差:1080p 1440 px / 2K 2178 px / 4K 3304 px —— 游標系統實質失效。**
   **須寫成一條會執行的自動化測試**(ADR-0005 Validation Criteria #20),不得只靠紀律。
2. **`classify_action()` 必須自行過濾 `InputEventKey.echo`** —— 已實測
   `InputMap.event_is_action()` **不過濾**;不濾的話,玩家**按住**方向鍵會**每一影格都被判為
   導覽、亦即每一影格都在主張裝置權威**。

### 必須這樣做

- **Autoload 只做薄殼,邏輯放在依賴注入的核心** — 禁令 `logic_in_cursor_autoload_shell` / ADR-0005
- **共用列舉包在 `CursorTypes` 類別裡**(沿用 ADR-0002 已驗證的先例) — ADR-0005
- **`_input()` 只緩衝整幀,裁決一律在 `_process()`** — ADR-0005
- **六個行為者的 `process_priority` 值必須兩兩相異** —— 這是定序保證成立的前提,不是建議。
  同值之間本 ADR **不假設任何 tie-break** — ADR-0005
- **`process_priority` 的賦值語句必須在原始碼順序上早於 `add_child()`**(全部 5 處呼叫點) — ADR-0005
- **`CursorNavigationApplier` 必須是獨立子節點,固定 −25**,嚴格介於 ②(−60)與 ④(0)之間;
  ② 本身須落在開區間 `−100 < ② < −25`,兩端點皆不可取 — ADR-0005
- **同時身兼呼叫方與讀取方的系統必須拆成兩個節點** —— `process_priority` 是**逐節點**屬性 —
  禁令 `single_node_for_nonadjacent_cursor_actor_roles` / ADR-0005
- **載入期必須驗證 Input Map 約束**,且 **Agile Event Flushing 必須關閉**;**鍵不存在時回報
  UNKNOWN,不得視為通過** — ADR-0005
- **暫停/模態閘控採顯式旗標**,不採 `SceneTree.paused` — ADR-0005
- **已註冊表面的根 Control 必須同時滿足兩項**:①`focus_mode = FOCUS_NONE`;②不得帶有內建滑鼠
  hover 主題狀態(不得是 `Button` 等,否則必須顯式清空 hover/focus StyleBox)。
  🔴 **已實測:`FOCUS_NONE` 不排除 hover 繪製 —— 焦點與懸停是兩條獨立管線**,只設 `focus_mode`
  只封住其中一條 — ADR-0005
- **原生指標的恢復判定採白名單**:只有 hover 到明文登記為例外的表面時才恢復,其餘一律隱藏
  (失敗方向因此翻轉為「錯誤隱藏」,而非「錯誤顯示」) — ADR-0005
- **遍歷已註冊表面必須透過 `registered_surfaces_sorted()`**,不得直接迭代內部 `Dictionary` — ADR-0005
- **兩條 reset 路徑必須寫成 `if` / `elif`**,不得寫成兩個獨立 `if` —
  禁令 `independent_ifs_for_cursor_target_reset_policy` / ADR-0005
- **`is_instance_valid(node)` 檢查必須在任何後續操作(含 `connect()`)之前執行** — ADR-0005
- **`_notification()` 的派發順序是樹序,不是 `process_priority` 序** —— 設計時不得假設後者 — ADR-0005
- **滑鼠座標一律走單一注入管道**(`_mouse_position_provider`),不得三條路徑並存 — ADR-0005
- **拒絕一律回傳明確結果碼**(例如 `STALE_NOT_APPLIED`),絕不靜默忽略、絕不回傳 `void` — ADR-0005
- **兩種拒絕回饋必須在感知上可區分** —— 兩者的正確補救動作相反 — ADR-0005
- **`_reclaim` 私有、無 getter、不得外流** — 禁令 `external_access_to_cursor_reclaim_instance` / ADR-0005
- **持久化表面類型 / 裝置權威值時一律 `find_key` / `[name]`**,不得位置索引 — ADR-0005

### 絕對不可以

- **絕不讀取 `event.device`** —— 這是對 **4.7 鍵盤/滑鼠裝置 ID 重新編號**這項 post-cutoff 破壞性
  變更的**結構性免疫**,不只是紀律 — 禁令 `reading_input_event_device_id` / ADR-0005
  ⚠️ 下游若為除錯/記錄讀取裝置 ID,必須處理 `-1` sentinel
- **絕不用 `_unhandled_input()` 做裝置權威判定** — 禁令 `unhandled_input_for_device_authority` / ADR-0005
- **絕不在 `_unhandled_input()` 讀確認動作** — 禁令 `confirm_action_read_in_unhandled_input` / ADR-0005
- **已註冊表面絕不使用原生 Control focus/hover** —
  禁令 `native_control_hover_or_focus_on_registered_surface` / ADR-0005
- **絕不從自己的訊號處理器寫入游標狀態** — 禁令 `cursor_state_write_from_own_signal_handler` / ADR-0005
- **公開寫入入口絕不互相呼叫** —— GDScript 無 `try`/`finally`,這是唯一能保證閘門正確釋放的形狀 —
  禁令 `public_cursor_write_entry_calling_another` / ADR-0005
- **絕不用 `call_deferred()` 延後游標改標** — 禁令 `call_deferred_for_cursor_retarget_deferral` / ADR-0005
  ⚠️ **這與機制十容許的 `call_deferred()` 是兩件不同的事**,審查時容易誤判為矛盾:前者要求
  「必須落在當幀 −60 這個位置」(時點未經查證),後者只要求「不是現在」
- **絕不對無效的 provider 做靜默凍結退回** — 禁令 `silent_freeze_fallback_for_invalid_provider` / ADR-0005

### 效能護欄

- 診斷欄位(`diagnostic_*`)為 QA/測試專用,**下游業務邏輯不得依賴** — ADR-0001 / 0002 / 0005
- `process_priority`(更新順序)與 `CanvasLayer.layer`(繪製疊放順序)是兩個獨立概念,不得混用 — ADR-0005

---

## 全域規則(適用所有層)

### 命名慣例

| 元素 | 慣例 | 範例 |
|---|---|---|
| 類別 | PascalCase | `PlayerController` |
| 變數 | snake_case | `move_speed` |
| 訊號/事件 | snake_case,過去式 | `health_changed` |
| 檔案 | snake_case,與類別對應 | `player_controller.gd` |
| 場景 | PascalCase,與根節點對應 | `PlayerController.tscn` |
| 常數 | UPPER_SNAKE_CASE | `MAX_HEALTH` |

### 效能預算

| 目標 | 值 |
|---|---|
| 目標幀率 | 60 fps |
| 單幀預算 | 16.6 ms |
| Draw call | < 1000 |
| 記憶體上限 | **[尚未設定]** —— 待內容量與目標硬體確定 |

### 核准套件

- **GdUnit4 v6.2.1** —— 單元測試框架。`addons/gdUnit4/` **進版控**(512 檔 / 約 1.9 MB)。
  CI 指令必須帶 `--ignoreHeadlessMode`。
  🔴 **exit code 101 = 通過但有警告(節點洩漏),不是失敗 —— 但也絕不可當成成功。**

### 禁用 API(Godot 4.7.1)

**節點/類別**:`TileMap`→`TileMapLayer`、`VisibilityNotifier2D/3D`→`VisibleOnScreenNotifier2D/3D`、
`YSort`→`Node2D.y_sort_enabled`、`Navigation2D/3D`→`NavigationServer2D/3D`、
`EditorSceneFormatImporterFBX`→`…FBX2GLTF`、`AudioEffectSpectrumAnalyzer::get_tap_back_pos`(已移除)

**方法/屬性**:`yield()`→`await signal`、字串式 `connect()`→`signal.connect(callable)`、
`instance()`→`instantiate()`、`get_world()`→`get_world_3d()`、
`OS.get_ticks_msec()`→`Time.get_ticks_msec()`、
🔴 **巢狀資源的 `duplicate()`→`duplicate_deep()`(4.5 起)**、`type_exists()`(4.7 棄用)

**模式**:`$NodePath` 在 `_process()` 內 → `@onready` 快取;無型別 `Array`/`Dictionary` → 型別化
容器;新專案用 GodotPhysics3D → Jolt;**硬編碼鍵盤/滑鼠裝置 ID → 執行期查詢(4.7 編號已改)**

來源:`docs/engine-reference/godot/deprecated-apis.md`

> 🔴 **查 input / UI 相關 API 時,一律以 `current-best-practices.md` 與 `breaking-changes.md`
> 為準,不得只查 `modules/`。** `modules/` 底下 8 份全部停在 Godot 4.6,而專案釘 4.7.1;其中
> `input.md` 對「裝置 ID 重編號」、`ui.md` 對「Control offset transforms」**各自零命中**。
> **照那條捷徑查完就停下的人,不會知道自己漏了什麼。**

### 跨層約束

- **禁令權威清單在 `docs/registry/architecture.yaml` 的 `forbidden_patterns` 節**,
  **2026-09-02 當場數為 35 項**(0001:5 / 0002:8 / 0003:5 / 0004:1 / 0005:12 / 專案級:4)。
  🔴 **要現值就當場數,不要引用上面這行**:

  ```bash
  awk '/^forbidden_patterns:/{f=1} f&&/^    adr:/{print $2}' docs/registry/architecture.yaml \
    | sort | uniq -c | sort -rn
  ```

- **四項專案級禁令**(來源為 `game-concept.md`,不源自任何 ADR,在任何 ADR 核准前就已生效):
  - `rng_in_combat_settlement` —— 戰鬥結算路徑**絕不可使用 RNG**。唯一豁免:好感度對話卡牌的
    **牌面**隨機,但**發牌節奏固定**
  - `networking_features` —— 無連線/多人/線上功能,單機遊戲
  - `procedural_terrain_generation` —— 棋盤地形一律手工設計、劇情觸發
  - `abstract_func_with_body` —— 抽象方法宣告必須是**裸簽章**,帶 `pass` 主體是**編譯期錯誤**
    (已實機驗證)
- **ADR 的 `Key Interfaces` 示意程式碼刻意只有簽章、主體從略,直接貼上是 Parse Error。**
  🔴 **不要「順手加個 `pass` 讓它能編譯」** —— 那會撞上上一條禁令。
  **本專案已為「照 ADR 示意碼直接寫」付過 18 處編譯錯誤的代價。**
- **`class_name` 全域唯一。** ⚠️ 已知衝突:ADR-0001 契約的 `class_name Board` 與既有
  `src/gameplay/board/board.gd` 撞名(**已登記,未處置**),落地時須二選一。
- **量測結果要進入設計文件或架構決策時,必須讓引擎跑專案自己的類別**,不得用 awk/bash 重寫
  一份規則。🔴 **凡寫下「(A) 級」必須附上實際執行的檔案路徑,否則一律降為 (C)。**
- **新的一份工作副本必須先跑一次 `godot --headless --path . --import`**,否則 runner 會因
  `global_script_class_cache.cfg` 不存在而失敗。CI 不受此限(action 自行匯入)。

---

## 來源

- `docs/architecture/adr-0001-tactical-query-atomicity-contract.md`
- `docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md`
- `docs/architecture/adr-0003-save-system-serialization-format-and-type-safety.md`
- `docs/architecture/adr-0005-cursor-device-authority-input-architecture.md`
- `docs/registry/architecture.yaml`(禁令與立場登記表,**權威來源**)
- `.claude/docs/technical-preferences.md`、`.claude/docs/coding-standards.md`
- `docs/engine-reference/godot/`(`VERSION.md`、`deprecated-apis.md`、`breaking-changes.md`、
  `current-best-practices.md`)
