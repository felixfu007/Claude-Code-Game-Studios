# ADR-0005: 單一游標/高亮狀態系統 — 裝置權威輸入架構

## Status

**Proposed**

## Date

2026-08-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Input / UI / Core |
| **Knowledge Risk** | **HIGH** —— 4.7 為訓練截止(2026-01)後發布,且本 ADR 的兩個核心領域(Input、UI)在 4.6 與 4.7 各有一項直接相關的變更 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`、`breaking-changes.md`、`current-best-practices.md`、`deprecated-apis.md`、`modules/input.md`、`modules/ui.md` |
| **Post-Cutoff APIs Used** | 無新 API 依賴。本 ADR 依賴的機制(`_input()`、`_process()` + `process_priority`、`InputEvent` 子類別、`InputMap.get_actions()`/`action_get_events()`、`ProjectSettings.get_setting()`、`Input.mouse_mode`、`CanvasLayer`、`NOTIFICATION_APPLICATION_FOCUS_IN`/`_OUT`)皆為 4.4 前既有機制。**但本 ADR 刻意避開兩項 post-cutoff 變更的影響面**:(a) 4.7 鍵盤/滑鼠**裝置 ID 重新編號** —— 機制四結構性地從不讀取 `.device`(見機制四);(b) 4.6 **雙焦點系統** —— 機制十四禁止已註冊表面使用原生 Control focus/hover(這正是 GDD 第四輪裁決的成因) |
| **Verification Required** | 見下方「Verification Required 明細」—— 共 9 項。其中第 1 項(參考文件版本落後與涵蓋率缺口)與第 9 項(`FOCUS_NONE` 涵蓋範圍)為本 ADR 撰寫/驗證過程中新發現,不屬 GDD 既有 Open Questions |

### ⚠️ 參考文件版本落差(本 ADR 撰寫時發現,尚未被任何文件追蹤)

`docs/engine-reference/godot/modules/` 下**全部 8 份**模組參考文件皆標記 `Last verified: 2026-02-12 | Engine: Godot 4.6`,而專案釘選 **4.7.1**(`VERSION.md` 釘選日 2026-07-28)。這對本 ADR 的影響**特別嚴重**,因為 `modules/input.md` 與 `modules/ui.md` 正是本 ADR 的兩個核心領域,而兩份都**不含任何 4.7 變更**:

| 4.7 變更 | 只存在於 | 對本 ADR 的意義 |
|---|---|---|
| Input:鍵盤/滑鼠裝置 ID 重新編號 | `breaking-changes.md` | 機制四的設計依據 |
| UI:Control offset transforms(明文點名 hover 回饋與自訂輸入路由為迴歸測試項) | `breaking-changes.md`、`current-best-practices.md` | 已由 GDD 第九輪 spike 實測關閉(見下方) |

**因此本 ADR 的引擎判斷一律以 `breaking-changes.md` 為準,不以 `modules/input.md`/`modules/ui.md` 為準。** 這個落差本身列為 Verification Required 第 1 項,並建議由 technical-director 排入模組文件的 4.7 更新(與 ADR-0004 審查發現的 `modules/core-scripting.md` 缺口為同一類問題)。

### 參考庫對本 ADR 核心依賴的實際涵蓋率(撰寫時逐項 grep 全 `docs/engine-reference/godot/` 目錄)

| 引擎依賴 | 用於 | 參考庫涵蓋 |
|---|---|---|
| `process_priority` | **機制六(四行為者定序的全部基礎)** | **零命中** |
| Autoload(註冊、生命週期、`_notification` 可達性) | 機制一、機制九 | **零命中** |
| `focus_mode` / `Control.FOCUS_NONE` | **機制十四(4.6 雙焦點的唯一防線)** | **零命中** |
| `accept_event()` | 機制五拒絕 `_unhandled_input()` 的因果鏈 | **零命中** |
| `CanvasLayer` | 機制十二、十三 | **零命中** |
| `Input.mouse_mode` | 機制十三 | **零命中** |
| `_input()` | 機制五 | 僅 `modules/input.md`(**4.6,版本落後**) |
| `mouse_filter` | 機制十四 | 僅 `modules/ui.md`(**4.6,版本落後**) |

**8 項核心依賴中 6 項在專案參考庫完全沒有記錄,另 2 項只存在於落後一個大版本的文件裡。** 這不是本 ADR 的缺失,是專案引擎參考庫的結構性缺口——但它直接決定了本 ADR 的引擎判斷**有多少比例只能來自訓練資料印象而非查證**。ADR-0004 的第二輪審查已就 `modules/core-scripting.md`(序列化/雜湊/檔案 I/O/並發原語)提出同一類建議;本 ADR 再新增一項:**`modules/` 需要一份涵蓋 Node 生命週期與輸入派發語意的文件**(`process_priority`、`_input`/`_unhandled_input`/`_gui_input` 的派發鏈與 `accept_event()`、Autoload 語意、`CanvasLayer`、`focus_mode` 在雙焦點下的行為)。在那之前,機制五/六/十四的正確性依據**弱於**本專案其他 ADR 的平均水準,這一點必須被明文承認而不是藏在「Verification Required」的清單長度裡。

### Verification Required 明細

| # | 項目 | 來源 | 風險 |
|---|---|---|---|
| 1 | **`modules/input.md`/`modules/ui.md` 版本落後一個大版本**(4.6 vs 釘選 4.7.1)—— 須更新後回頭覆核本 ADR 的引擎假設 | **本 ADR 新發現** | 中 —— 已以 `breaking-changes.md` 代償,但代償不等於覆蓋 |
| 2 | **`_input()` 在同一影格內跨節點的派發順序**是否確定、可重現 —— 機制五刻意讓正確性**不依賴**此順序(緩衝而非即時處理),但機制六的「四行為者定序」需要確認 `_input()` 全數完成後才進入 `_process()` 這個前提在 4.7.1 成立 | 本 ADR 機制六 | **高** —— 機制六的定序基礎 |
| 3 | **`ProjectSettings` 中 Agile Event Flushing 的確切設定鍵字串**(推測為 `input_devices/buffering/agile_event_flushing`,**未經查證**) | GDD Open Question(第九輪) | 中 —— 鍵名錯誤會讓機制七的驗證靜默通過(`get_setting()` 對不存在的鍵回傳 `null`),比不驗證更危險。機制七已就此加設防衛 |
| 4 | **`Input.mouse_mode` 是否支援原生指標的連續 alpha 動畫** —— 本 ADR 機制十三**假設不支援**並據此設計,若實際支援,機制十三仍成立(自繪載體是上位方案),不需回頭修訂 | GDD Open Question(第五輪) | 低 —— 本 ADR 選擇了不依賴此答案的方案 |
| 5 | **Steam 疊加層是否觸發 `NOTIFICATION_APPLICATION_FOCUS_IN`** —— GDD AC-30 依賴此通知涵蓋 alt-tab / 最小化 / Steam 疊加層三情境,但 Steam 疊加層常以應用程式內 swapchain 層級掛鉤,不一定產生 OS 層焦點轉移 | GDD Open Question(第四輪) | 中 —— 若不觸發,機制九需備援偵測路徑 |
| 6 | **`InputMap.get_actions()`/`action_get_events()` 於 headless 載入後能正確反映「引擎內建預設綁定 + 專案自訂覆寫」的合併結果** | GDD Open Question —— **已於第十輪由 `godot-specialist` 覆核關閉**(此二 API 於 4.5→4.6→4.7 穩定、未變更、未棄用) | 低 —— 保留登記供追溯 |
| 7 | **暫停/模態的讓路手段** —— GDD Open Question 問「`SceneTree.paused` + `process_mode` 是否足以涵蓋專案內全部彈出情境」。**本 ADR 機制九不採用 `SceneTree.paused` 作為判準**(見機制九的拒絕理由),因此此 Open Question 對本 ADR 的實作可行性不再構成阻擋;仍須於 `/create-architecture` 盤點彈窗情境以確認機制九的顯式旗標有被正確呼叫 | GDD Open Question(第六輪) | 低(已被機制九降級) |
| 9 | **`focus_mode = FOCUS_NONE` 是否也排除 Control 主題內建的滑鼠 hover 繪製** —— `godot-specialist` 判斷**大概率不排除**(兩條獨立管線)。最小 spike:`Button` 設 `FOCUS_NONE` 後滑鼠懸停是否仍畫 hover 主題。決定機制十四第 2 項條件是硬性要求或防禦性建議 | **本 ADR Step 5.5 驗證新發現** | **高** —— 若不排除,單靠 `focus_mode` 的機制十四只封住兩條管線中的一條,原決策已據此修訂 |
| 8 | **`InputEvent.device` 於某些合成事件回傳 `-1` sentinel** —— GDD 第十一輪明文登記為「ADR 撰寫時的警告項」。本 ADR 機制四結構性不讀取 `.device`,不受影響;**但下游若為除錯/記錄用途讀取裝置 ID 須留意此值**,已列為機制四的明文警告 | GDD Open Question(第十一輪) | 低(本系統結構性免疫) |

**實作第一天的驗證排程建議**(`godot-specialist` Step 5.5 建議):第 **2**(`process_priority` 不涵蓋 `_input()` 與批次前提)、**3**(Agile Event Flushing 鍵名)、**9**(`FOCUS_NONE` 是否也關 hover 主題)三項,加上機制八的 `@abstract` 語法(承 ADR-0004 Verification Required 6/6a),應在實作**第一天**先跑掉,不要留到整合測試後期。理由:四者的驗證成本都極低(一次幀精準測試、一次 `has_setting()` 查詢、一個 `Button` 懸停 spike、一個最小 `@abstract` 檔案),但後果都是**全有全無**——`@abstract` 寫錯是整檔案編譯失敗;`process_priority` 前提不成立會讓機制六整個定序失效;`FOCUS_NONE` 只關一半會讓機制十四在某些節點型別上失效;Agile Flushing 鍵名寫錯會讓機制七的驗證靜默通過,製造假的安全感。**先跑這四項,可以在寫任何正式程式碼之前就知道有沒有需要回頭修訂本 ADR。**

**已由 GDD spike 實測關閉、本 ADR 不再重複登記**:Control offset transforms 的命中測試風險(第九輪 `prototypes/cursor-reclaim-godot-spike-2026-08-05/` Test 1 於 4.7.1 Editor 實測 translate/rotate/scale 三模式,`_gui_input` 路由與 `get_global_rect()` 皆正確跟隨視覺變換,無脫節)。

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **None**。本 ADR 不依賴任何既有 ADR 的決策內容。機制二借用 ADR-0002 的 `AffinityTypes` **先例**(裸 enum 跨檔無法編譯),但那是可獨立驗證的引擎事實,不是對該 ADR 決策的依賴 |
| **Enables** | 戰棋移動與交戰系統的演算法層 ADR(`TR-tactical-024`/`-025` 明文把輸入閘控委派給本系統的有效性旗標與裝置權威查詢,在本 ADR 定案前無法設計);好感度視覺呈現 UI(#9)、戰鬥 HUD(#10)、支援對話 UI(#11)三個 Presentation 層系統的讀取架構;教學/上手引導系統(奪權漸進回饋的教學掛鉤) |
| **Blocks** | 單一游標/高亮狀態系統的全部 story;戰棋移動與交戰系統中任何觸及輸入閘控或游標目標讀取的 story |
| **Ordering Note** | 本 ADR 定案的是**機制**;它所服務的**義務**由 `design/gdd/cursor-highlight-state.md` 擁有(該文件 2026-08-13 第十六輪 Approved)。GDD 的 Overview 明文設下「設計 vs. 實作邊界」,刻意停留在行為規格層級,並在 Open Questions 明列「是否需要為本系統建立正式 ADR(記錄具體的 Godot 實作模式,例如全域狀態用 Autoload singleton 還是其他機制)」,目標時間點 `/create-architecture` —— 本 ADR 即為該項的落實。**單向修訂約束**:GDD 義務變更須回頭檢查本 ADR 是否仍能滿足;本 ADR 的機制變更**不得**擴大或縮小 GDD 的義務。<br>**滑鼠奪權子機制的凍結狀態**:GDD 第十二輪(2026-08-11)使用者裁決把該子機制的硬性閘門降級為建議事項、重新設計**暫停**、候選修法停止投入,待取得手把硬體。本 ADR **不試圖解決該子機制的兩項已確認缺陷**,只把它隔離在可替換邊界後(機制八)——比照 ADR-0004 以 `SaveIOBackend` 限縮 Open Question 9 的手法 |

## Context

### Problem Statement

`cursor-highlight-state.md` 經 16 輪 `/design-review` 收斂,行為規格極為完整(66+ 條 Acceptance Criteria、明文的狀態機、明文的邊界情況),但**刻意不定案任何 Godot 實作機制**——這是該文件 Overview 的明文設計邊界。結果是 19 項技術需求全部沒有架構支撐:2026-08-18 兩輪 `/architecture-review` 皆判定本系統 **19/19 零涵蓋**,且它是 Foundation 層(`systems-index.md` Dependency Map 第 3 位),第二輪的 FAIL 判定**唯一成因**就是本系統。

同時,本系統有兩項超出「尚未定案」的問題:

1. **兩項已確認、尚未修復的缺陷**(GDD `Known Confirmed Defects` 節):類比搖桿持續按住造成滑鼠奪權永久鎖死(E1,spike log 實測,100% 可重現);滑鼠奪權成功後被反方向零門檻豁免規則秒搶回(E2,真人口語觀察)。兩者已由使用者裁決降級為建議事項、子機制重新設計暫停。
2. **一項擁有權缺口**:全域每裝置待機指示元件須存在於每個畫面,但 GDD 記載「現有候選擁有者皆為畫面範圍,無一符合」。

架構階段的責任因此有三層:選定實作機制、**不在翻譯過程中弄丟任何一條已收斂的規則**、以及**不假裝已凍結的問題已被解決**。

### Constraints

- **GDScript 無例外處理機制**:錯誤處理須以回傳值(enum 或結構化 Result 物件)表達。GDD 明文要求「標記待重新解析」介面**絕不靜默**,必須回傳結構化的已套用/已過期結果。
- **無 Godot 執行環境可供實機驗證**:本專案 `src/` 為空,尚無任何實作程式碼,亦無法實測任何引擎 API 行為。所有引擎判斷須明確區分「已查證」與「訓練資料印象」。
- **參考文件的兩個核心模組落後一個大版本**(見上方 Engine Compatibility)。
- **裸 enum 跨檔無法編譯**(ADR-0002 撰寫時由 `godot-specialist` 查核發現的 BLOCKING 問題,已包裝為 `AffinityTypes` 解決)——機制二不得重蹈。
- **`process_priority` 不管 `_input()` 的順序**,只管 `_process`/`_physics_process`。這是機制五/六形狀的直接決定因素。
- **既有架構立場**(`docs/registry/architecture.yaml`,41 項):`autoload_singleton_for_testable_data_layers`、`enum_value_positional_string_conversion`、`mutable_container_as_dictionary_key`、`relying_on_container_iteration_order`、`returning_internal_container_references` 五項 forbidden pattern 與本 ADR 直接相關。
- **全手把平權**(`.claude/docs/technical-preferences.md`):所有 UI 須同等支援滑鼠 hover/click 與 d-pad/類比搖桿導覽,主機無游標,不得有 hover-only 互動。
- **子機制凍結**:滑鼠奪權(Core Rules #3 空間門檻)的重新設計已由使用者明文暫停,不得在本 ADR 內重啟設計。

### Requirements

1. **全域狀態**(Core Rules #1):恰 3 個已認定的頂層欄位;擁有者生命週期須涵蓋所有使用本系統的畫面。
2. **共用「表面類型」列舉**(Core Rules #7):單一集中定義,實作位置自第四輪起懸而未決。
3. **雙寫入、單一狀態源**(Core Rules #2):滑鼠與鍵盤/手把寫入同一狀態,任何表面不得繞過本系統操作自己的高亮。
4. **裝置權威判定**(Core Rules #3):`ui_*` action 為權威閘門,`InputEvent` 子類別為裝置分類手段,**絕不讀裝置 ID**。
5. **同幀原子化裁定**(Core Rules #3 實作架構約束):整幀緩衝後統一裁定,**必須**掛 `_input()`,**禁止** `_unhandled_input()`——這是正確性要求,不是風格偏好。
6. **固定優先序仲裁**:同幀雙裝置時鍵盤/手把恆勝,100% 決定性,不依賴引擎內部行為。
7. **焦點/暫停閘控**:失焦全程不運算、復焦重新播種;暫停/模態期間被動裁定路徑不參與,但呼叫方主動 API 路徑**不受**此限。
8. **交接視覺延遲 ≤ 1 影格**(`max_handoff_visual_latency_frames`,GDD 已定案為 1),需要幀精準量測機制。
9. **原生視覺抑制**(Core Rules #5):失去權威的裝置其原生視覺須被抑制;已註冊表面不得使用原生 Control focus/hover。
10. **結構化介面**:2 個寫入方法、2 個讀取查詢,拒絕回饋須在感知上可區分。

## Decision

### 核心洞見:三個問題其實共用同一個答案

GDD 留下三個看似無關的架構缺口——**全域狀態的生命週期宿主**(TR-cursor-001,「Autoload 類機制」)、**全域每裝置待機指示元件的擁有者**(TR-cursor-016,「現有候選皆為畫面範圍,無一符合」)、**原生游標連續 alpha 的替代載體**(TR-cursor-017,「原生指標可能不支援逐幀連續 alpha」)——三者的共同結構是:**需要一個生命週期跨越所有畫面、且能承載視覺節點的宿主**。

一旦承認第一個問題的答案是「一個 Autoload」,另外兩個就不再是缺口,而是同一個 Autoload 順理成章的兩個掛載點。這也解釋了為什麼 GDD 找不到 TR-cursor-016 的擁有者:它一直在畫面範圍的候選者裡找,而正確答案在畫面範圍之外——而那個東西在 GDD 寫作當下還不存在,因為它正是本 ADR 要建立的。

### 機制一:擁有模式 —— Autoload 薄殼 + 依賴注入核心

```gdscript
# ─── cursor_state.gd ─────────────────────────────────────────
# 純邏輯核心。可 new() 建構,不依賴場景樹,單元測試直接構造。
class_name CursorState extends RefCounted

# Core Rules #1 的三個頂層欄位,無第四個:
var _target: CursorTarget                      # 含有效性旗標(旗標是目標欄位內部結構,不算獨立頂層欄位)
var _device_authority: CursorTypes.Authority   # UNINITIALIZED / MOUSE / KEYBOARD_GAMEPAD
var _reclaim: MouseReclaimPolicy               # 第三個頂層欄位的擁有者,見下方說明與機制八

> **第三個頂層欄位的歸屬(GDD 命名對照)**:GDD Core Rules #1 明文列出三個頂層欄位,第三個是**滑鼠奪權累積位移量**(`accumulated_net_displacement_px`,GDD 第五輪明文承認為非隱藏的頂層欄位)。本 ADR 把該純量**移入 `MouseReclaimPolicy` 內部**(機制八),`CursorState` 上對應的欄位是持有該策略物件的 `_reclaim`。
>
> **這仍然滿足「恰 3 個頂層欄位」**:欄位數未增未減,第三個欄位的**型別**由裸 `float` 變為一個封裝它的物件。GDD 明文的意圖是「此欄位必須被承認、不得是隱藏狀態」——`_reclaim` 是公開宣告的欄位,累積量透過 `reclaim_progress()` 可查詢,不是隱藏狀態。
>
> **但這是一個需要驗證的形狀變更**:GDD **AC-1** 要求對公開方法行為做窮盡檢視、確認不存在未被承認的第四個欄位。該 AC 的測試必須針對本 ADR 的形狀執行(`CursorState` 的 3 個欄位 + `MouseReclaimPolicy` 內部的累積量與起點),**不得**假設原 GDD 措辭下的扁平三純量形狀。若 AC-1 的窮盡檢視認定「策略物件內部另有累積起點」構成第四個未承認欄位,則本 ADR 須回頭把起點也明文列入契約(建議做法:`MouseReclaimPolicy` 增設 `diagnostic_seed_position() -> Vector2` 使其可查詢,而非改回扁平形狀)。

# ─── cursor_state_host.gd ────────────────────────────────────
# Autoload。只負責四件事,不含任何裁定邏輯:
#   (1) 生命週期宿主 —— 持有唯一的 CursorState 實例,生命週期涵蓋所有畫面
#   (2) 輸入緩衝掛載點 —— _input() 收集,_process() 裁決(機制五/六)
#   (3) 引擎通知轉發 —— NOTIFICATION_APPLICATION_FOCUS_IN/_OUT(機制九)
#   (4) 全域視覺宿主 —— 持有一層 CanvasLayer(機制十二/十三)
class_name CursorStateHost extends Node
```

**決策**:註冊一個 Autoload(`CursorStateHost`),但**它本身不持有任何狀態、不含任何裁定邏輯**——狀態與邏輯全在可 `new()` 的 `CursorState`(`RefCounted`)裡。

**為何這不違反 `autoload_singleton_for_testable_data_layers`**(ADR-0002 登記的 forbidden pattern):該禁令的 `description` 明確限定於「**data-layer** systems that need extensive unit-test coverage of edge cases (validation rules, invariant checks)」,理由是 Autoload 會迫使每個測試案例前後清理全域狀態。本 ADR 的結構讓禁令的**理由**得到滿足而非規避:66+ 條 Acceptance Criteria 全部針對 `CursorState`/`MouseReclaimPolicy`,測試時直接 `CursorState.new()`,不觸碰場景樹、無全域狀態需要清理;Autoload 只剩下一層無邏輯的轉發殼,它本身沒有需要邊界測試的行為。

**因此本 ADR 不需要該禁令的例外**——這是一個結構上落在禁令範圍外的設計,不是「明知違反但有正當理由」。若未來有人把裁定邏輯搬進 `CursorStateHost`,那才是違反,且應被程式碼審查攔下(已登記為 forbidden pattern 候選,見 Registry 更新提案)。

**為何不是純 DI(無 Autoload)**:TR-cursor-015 的**跨畫面交接義務**是本系統的硬性需求——存檔讀取的甲/乙/丙分支要求舊表面拆除前標記、新表面掛載後設定,橫跨兩個畫面的生命週期。純 DI 下,注入鏈只要在任何一個畫面轉場處斷掉,交接就失效,而「注入鏈完整」這件事沒有任何結構性保證,只能靠紀律。Autoload 提供的正是「不可能斷」這個保證。

### 機制二:共用列舉的實作位置 —— `CursorTypes` 包裝類別

```gdscript
# ─── cursor_types.gd ─────────────────────────────────────────
class_name CursorTypes extends RefCounted   # 純命名空間,永不實例化

enum SurfaceType {
    BOARD_TILE,            # 棋盤格
    RELATION_MINIMAP_NODE, # 關係圖迷你地圖節點
    CARD_SLOT,             # 卡牌選取區槽位
    DIALOGUE_CHOICE,       # 支援對話選項
    # 新增表面類型 = 在此新增一個成員 + 於機制七的門檻表補一個常數。
    # 未登記於此列舉的 UI 表面不落入游標目標管轄範圍(GDD Core Rules #7 管轄範圍判準、AC-60)。
}

enum Authority { UNINITIALIZED, MOUSE, KEYBOARD_GAMEPAD }

enum ActionClass { NAVIGATION, CONFIRM, OTHER }   # 見機制六:僅 NAVIGATION 具主張權威資格
```

**決策**:表面類型列舉定案在 `cursor_types.gd`,包裝於 `class_name CursorTypes` 之下,**不使用裸的全域 enum**。

**理由**:ADR-0002 撰寫時 `godot-specialist` 查核發現裸列舉跨檔無法編譯,是該 ADR 的 BLOCKING 級修正(已包裝為 `AffinityTypes`)。本專案已有一個查證過的先例與慣例,沒有理由讓第二個系統重蹈同一個錯誤。**這解決了自 GDD 第四輪起懸而未決的「實作位置與擁有者未定案」**(TR-cursor-002):擁有者是本系統,位置是 `cursor_types.gd`,呼叫端一律以 `CursorTypes.SurfaceType.BOARD_TILE` 形式溝通。

**持久化紀律**:若表面類型或裝置權威值需要持久化(目前無此需求,但存檔系統的游標交接甲/乙/丙分支可能演化出需求),一律採 `enum.find_key(value)` / `enum[name_string]`,**不得**用 `keys()[value]` 位置索引——沿用 `enum_value_positional_string_conversion` forbidden pattern(ADR-0002 登記)。

### 機制三:目標識別為值型別 + 表面註冊表

```gdscript
# ─── cursor_target.gd ────────────────────────────────────────
# 值語意目標識別。不可變:任何變更都產生新實例,不就地修改。
class_name CursorTarget extends RefCounted

var surface: CursorTypes.SurfaceType
var id: int                  # 該表面內的目標識別。int 而非 Variant —— 見下方理由
var is_valid: bool           # Core Rules #1 的有效性旗標

func equals(other: CursorTarget) -> bool   # 顯式值比較,不用 ==
static func make(surface, id) -> CursorTarget      # is_valid 恆為 true
static func invalidated(from: CursorTarget) -> CursorTarget  # 保留 surface/id,旗標翻 false
```

**`id` 型別選 `int` 而非 `Variant`**:GDD 舉的三個例子是〔棋盤格,座標〕、〔迷你地圖節點,節點ID〕、〔卡牌選取區,槽位索引〕——後兩者天然是 int,只有棋盤格是 `Vector2i`。**決策:棋盤座標由呼叫方以本系統提供的純函式編碼為 int**(`CursorTypes.encode_tile(Vector2i) -> int` / `decode_tile(int) -> Vector2i`,以盤面寬度為基數的雙射)。

**理由**:(a) 統一 `id` 型別讓 `CursorTarget` 成為真正的值型別,`equals()` 的語意不隨表面類型改變;(b) `Variant` 的 `id` 會讓「兩個目標是否相同」在 `Vector2i` 情境下落入 GDScript 的參照相等陷阱——`mutable_container_as_dictionary_key` forbidden pattern(ADR-0002 登記)警告的正是同一類問題;(c) 機制十三的競態防呆(「傳入的目標識別與系統當下持有的不相符即回傳已過期」)完全依賴一個可靠的相等判定,不能建立在型別相依的比較邏輯上。

**顯式 `equals()` 而非 `==`**:`CursorTarget` 是 `RefCounted`,`==` 比較的是物件身分不是欄位值。這是 GDScript 的既知陷阱,已由 `mutable_container_as_dictionary_key` 的 `why:` 欄記錄。

```gdscript
# ─── cursor_surface_registry.gd ──────────────────────────────
class_name CursorSurfaceRegistry extends RefCounted

enum RegisterResult { REGISTERED, DUPLICATE_TAG_REJECTED, UNREGISTERED_NOT_FOUND }

func register(surface: CursorTypes.SurfaceType, node: Node) -> RegisterResult
func unregister(surface: CursorTypes.SurfaceType) -> RegisterResult
func get_surface(surface: CursorTypes.SurfaceType) -> Node   # 或 null
func registered_surfaces_sorted() -> Array[CursorTypes.SurfaceType]  # 見下方
```

**單標籤單實例**(TR-cursor-003):`register()` 對已被占用的標籤回傳 `DUPLICATE_TAG_REJECTED`,**不覆寫**——fail-loud,比照 ADR-0002 `notify_death()` 的 `DUPLICATE_DEATH_NOTIFICATION` 冪等拒絕慣例。

**迭代順序**:任何需要遍歷已註冊表面的邏輯**必須**透過 `registered_surfaces_sorted()`(依 enum 底層 int 值排序),**不得**直接迭代內部 `Dictionary`——沿用 `relying_on_container_iteration_order` forbidden pattern(ADR-0001 登記)。

### 機制四:裝置分類 —— `InputEvent` 子類別,結構性不讀裝置 ID

```gdscript
# 兩層機制(GDD Core Rules #3):
#   第一層(權威閘門):事件是否對應到某個 ui_* action。不對應者不構成裝置權威轉移依據。
#   第二層(分類手段):檢視原始 InputEvent 的子類別。
static func classify(event: InputEvent) -> CursorTypes.Authority:
    if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
        return CursorTypes.Authority.KEYBOARD_GAMEPAD
    if event is InputEventMouseMotion or event is InputEventMouseButton:
        return CursorTypes.Authority.MOUSE
    return CursorTypes.Authority.UNINITIALIZED   # 不參與裁定
```

**絕不讀取 `event.device`**(TR-cursor-004)。這不只是紀律,是本系統對 **4.7 鍵盤/滑鼠裝置 ID 重新編號**這項 post-cutoff breaking change 的結構性免疫——`godot-specialist` 於首輪 `/architecture-review` 已 **CONFIRMED** 此設計與該變更無交集。

**⚠️ 下游警告項**(GDD 第十一輪登記):`InputEvent.device` 在某些合成事件下可能回傳 `-1` sentinel(代表「無特定裝置」)。本系統結構性不受影響,但**下游若為除錯或記錄用途讀取裝置 ID,必須處理 `-1`**。

**已知未定義路徑**(GDD 第八輪登記,不在本 ADR 解決範圍):若 `ui_*` action 由 `Input.action_press()`/`action_release()` 程式化合成觸發(除錯工具、未來的無障礙輔助),背後沒有真正的 `InputEvent` 實例可供分類。本 ADR 依 GDD 建議方向處理:`classify()` 收不到事件的路徑**不改變目前裝置權威**(比照 AC-6 精神),待有實際下游需求時補正式規則。

### 機制五:整幀緩衝掛 `_input()`,裁決在 `_process()`

```gdscript
# ─── cursor_state_host.gd(承機制一)─────────────────────────
var _frame_events: Array[InputEvent] = []

func _input(event: InputEvent) -> void:
    # 只收集,絕不裁定。掛載點是正確性要求(見下方),不是風格選擇。
    if _arbitration_suspended:        # 機制九
        return
    _frame_events.append(event)

func _process(_delta: float) -> void:
    if _frame_events.is_empty():
        return
    _state.arbitrate_frame(_frame_events)   # 機制六:一次原子化裁定
    _frame_events.clear()
```

**掛 `_input()`、禁 `_unhandled_input()`**(GDD Core Rules #3 實作架構約束,第九輪升級為阻擋項):`_unhandled_input()` 只會收到 Control 自身 GUI 處理(透過 `accept_event()`)未消費的事件。若一個聚焦中的 Control 其內建焦點導覽邏輯消費了 `ui_up`/`ui_down`,該事件會**完全不抵達**緩衝區——這是**遺漏**而非重排序,緩衝架構本身無法補救一個從未進入緩衝區的事件,足以推翻 GDD 最核心的「100% 決定性測試」宣稱。`godot-specialist` 於首輪 `/architecture-review` **CONFIRMED** `_input()` 為正確做法。

**為何裁決在 `_process()` 而非 `_input()` 的最後一次呼叫**:GDD 要求「整幀事件收集完畢後才統一裁定」,但 `_input()` 本身無法知道自己是不是這一影格的最後一次呼叫。**關鍵引擎事實:`process_priority` 只管 `_process`/`_physics_process`,不管 `_input()` 的派發順序**——因此「四行為者的決定性同幀執行順序」(TR-cursor-008)只可能建立在 `_process` 階段。把裁決移到 `_process()` 讓正確性建立在一個可用 `process_priority` 精確控制的階段,而不是建立在 `_input()` 跨節點派發順序這個未經驗證的引擎行為上(列為 Verification Required 第 2 項——需確認的是「該影格全部 `_input()` 完成後才進入 `_process()`」這個更弱的前提,而非派發順序本身)。

### 機制六:四行為者的決定性同幀定序 —— 具體 `process_priority` 數值

| 行為者 | 節點 | `process_priority` | 職責 |
|---|---|---|---|
| ① 裁定者 | `CursorStateHost`(Autoload) | **−100** | 消化該影格緩衝事件,更新 3 個頂層欄位 |
| ② 已註冊表面 | 各 `CursorSurface` | **0**(預設) | 讀取狀態,渲染自己的高亮/待重新解析視覺 |
| ③ 全域視覺層 | `CursorStateHost` 持有的 CanvasLayer 子節點 | **50** | 待機指示、奪權漸進回饋載體(機制十二/十三) |
| ④ 下游讀取方 | 戰鬥 HUD、好感度視覺 UI、支援對話 UI | **100** | 讀取游標目標更新自己的呈現 |

**`process_priority`(更新順序)與 `CanvasLayer.layer`(繪製疊放順序)是兩個獨立概念**,本表指的一律是前者;機制十二/十三那層 CanvasLayer 的 `layer` 值另行設定,不與本表數值混用(`godot-specialist` Step 5.5 建議明確分開標注以降低下游誤讀)。**Godot 的 `process_priority` 是數值小者先執行**,因此裁定者(−100)必然早於任何讀取方。這讓「交接視覺延遲 ≤ 1 影格」(`max_handoff_visual_latency_frames` = 1,GDD 已定案)成為**同一影格內即完成**的更強保證,而非勉強達標。

**同幀雙裝置的固定優先序仲裁**(GDD Edge Cases,第四輪重寫為不依賴引擎佇列順序):

```gdscript
func arbitrate_frame(events: Array[InputEvent]) -> void:
    # 只有「具備主張裝置權威資格」的事件參與仲裁。資格僅兩類:
    #   (a) 鍵盤/手把的 NAVIGATION 類 ui_* action
    #   (b) 滑鼠達到該表面類型 reclaim_threshold_px 的位移(機制八判定)
    # CONFIRM 類與其他非導覽類動作不具資格,不落入仲裁範圍。
    #
    # 固定優先序:KEYBOARD_GAMEPAD 恆勝於 MOUSE。不讀引擎佇列順序,100% 決定性。
```

**為何鍵盤/手把恆勝**(GDD 明文理由,本 ADR 忠實承載):滑鼠是絕對定位裝置,同幀落敗只需下一次達門檻的移動即可重新取得權威,誤判代價趨近於零;鍵盤/手把是相對定位裝置,同幀意外落敗會讓玩家感受到剛按下的方向鍵「沒有反應」,心智模型斷裂的代價高得多。

### 機制七:載入期設定驗證 —— Input Map 約束 + Agile Event Flushing 鎖定

```gdscript
# ─── cursor_startup_validator.gd ─────────────────────────────
class_name CursorStartupValidator extends RefCounted

enum ValidationFailure {
    NONE,
    UI_ACTION_BOUND_TO_MOUSE,          # TR-cursor-005
    AGILE_EVENT_FLUSHING_ENABLED,      # TR-cursor-007
    AGILE_FLUSHING_SETTING_KEY_UNKNOWN # 見下方防衛
}

func validate() -> Array[ValidationFailure]   # 空陣列 = 全數通過
```

**(a) Input Map 約束驗證**(TR-cursor-005):遍歷 `InputMap.get_actions()`,對每個 `ui_*` action 呼叫 `InputMap.action_get_events()`,若任一 event 為 `InputEventMouseButton`/`InputEventMouseMotion` 而該 action **語意上非懸停/游標移動**,回報 `UI_ACTION_BOUND_TO_MOUSE`。這道約束是 Core Rules #3「滑鼠奪權前提約束」成立的前提——Steam Input／觸控板可能注入與真實滑鼠事件無法區分的合成事件,若 `ui_*` action 同時綁定滑鼠,合成事件會在「最後操作裝置決定權威」規則下竊取手把的權威。此二 API 已由 GDD 第十輪 `godot-specialist` 覆核為 4.5→4.6→4.7 穩定、未變更、未棄用。

**範圍明文排除**(GDD 第五輪裁決):驗證僅於載入期執行一次。玩家執行期重新綁定按鍵不在本設計範圍內——`systems-index.md` 尚無「輸入設定/重新綁定系統」。該系統一旦設計,須回頭替本 ADR 補執行期重新驗證機制。

**(b) Agile Event Flushing 鎖定**(TR-cursor-007):機制五「一影格 = 一批原子化事件」的前提依賴專案設定 `Input Devices → Buffering → Agile Event Flushing` 維持關閉(引擎預設)。若任何系統日後為求低延遲開啟它,事件會即時派發而非批次收集,**全域**破壞本系統的定義前提。

**設定鍵未知的防衛**(本 ADR 新增):推測鍵名為 `input_devices/buffering/agile_event_flushing`,**未經查證**(Verification Required 第 3 項)。`ProjectSettings.get_setting()` 對不存在的鍵回傳 `null`——若鍵名寫錯,驗證會**靜默通過**,比不驗證更危險(製造了虛假的安全感)。因此驗證器**先**以 `ProjectSettings.has_setting()` 確認鍵存在:不存在則回報 `AGILE_FLUSHING_SETTING_KEY_UNKNOWN`(而非視為通過),迫使實作階段查出正確鍵名。**這是本 ADR 唯一一處刻意讓「未經查證」在執行期自我暴露的設計**,理由是此設定的破壞範圍是全域且靜默的。

`godot-specialist` 於首輪 `/architecture-review` 對此設定的原子性保證標記 **LIKELY-BUT-UNVERIFIED**——設定本身確實存在,但「一幀 = 一個原子批次」的具體保證需實機計時測試確認。

### 機制八:滑鼠奪權子機制 —— 可替換策略邊界(凍結項的隔離)

```gdscript
# ─── mouse_reclaim_policy.gd ─────────────────────────────────
@abstract
class_name MouseReclaimPolicy extends RefCounted

# 回傳本影格滑鼠是否取得有效的奪權主張資格
@abstract
func evaluate(mouse_motion_net_delta: Vector2, surface: CursorTypes.SurfaceType) -> bool:
    pass
# GDD 稱此值為 `reclaim_progress`(0.0~1.0),供機制十三的漸進回饋載體讀取
@abstract
func reclaim_progress() -> float:
    pass
# 四個重置觸發點 (a)(b)(c)(d) 的統一入口
@abstract
func reset(seed_position: Vector2) -> void:
    pass

# ─── threshold_mouse_reclaim_policy.gd ───────────────────────
# 現行實作:GDD Core Rules #3 的表面類型固定像素門檻。
# ⚠️ 本檔案內含兩項 GDD 已確認、尚未修復的缺陷(見 Consequences → Risks)。
# ⚠️ 本子機制的重新設計已由使用者於 GDD 第十二輪明文暫停,待手把硬體。
class_name ThresholdMouseReclaimPolicy extends MouseReclaimPolicy
```

**決策**:滑鼠奪權的門檻數學、累積器、四個重置觸發點、漸進回饋進度值,全部封裝在 `MouseReclaimPolicy` 的單一實作檔內,`CursorState` 只透過三個方法與它互動。

**理由**:GDD 第十二輪(2026-08-11)使用者裁決把此子機制的硬性閘門降級為建議事項、**重新設計暫停**、候選修法(`InputEventKey.echo` 過濾)正式標記為不再追加投入,待取得手把硬體。同時**兩項已確認缺陷維持未修復**:

| 缺陷 | 證據強度 | 狀態 |
|---|---|---|
| 類比搖桿持續按住造成滑鼠奪權**永久鎖死** | **E1**(spike log 實測,100% 可重現) | 無任何暫行防線 |
| 滑鼠奪權成功後被反方向零門檻豁免規則**秒搶回** | **E2**(真人口語觀察,僅測鍵盤路徑) | 無任何圍堵措施 |

本 ADR **不試圖修復這兩項**——使用者已明文裁決停止投入,重啟需要手把硬體到位且有明確理由。本 ADR 能做的、也是唯一該做的,是讓「未來重啟此子機制的重新設計」不需要動到本系統其他任何部分:**上層的裁定順序(機制六)、焦點閘控(機制九)、介面契約(機制十)、視覺載體(機制十三)全部只依賴 `MouseReclaimPolicy` 的三方法契約,與門檻數學如何實作無關。**

這是 ADR-0004 以 `SaveIOBackend` 限縮 GDD Open Question 9 的同一手法,理由也相同:**在缺乏驗證依據時,不假裝問題已解決,而是把它的影響面縮到一個檔案。**

**明文不成立的宣稱**:本機制**不**讓兩項缺陷消失,**不**降低它們的嚴重度,**不**構成「圍堵措施」。它只保證缺陷的修復範圍是一個檔案。若未來重啟設計時發現需要改動 `MouseReclaimPolicy` 的三方法契約本身(例如需要跨影格歷史而非單影格淨位移),則本 ADR 須一併修訂。

**退化實作供除錯用**:另提供 `ImmediateMouseReclaimPolicy`(門檻恆為 0,滑鼠任何移動即奪權)。它**不是**缺陷的修法——零門檻正是 GDD 第三~八輪明確駁回的方案(會讓滑鼠在鍵盤/手把操作期間持續竊取權威)。它的用途是隔離測試:當某個測試失敗時,替換為此實作可判定失敗是否來自門檻邏輯。

### 機制九:焦點/暫停閘控 —— 顯式旗標,不採 `SceneTree.paused`

```gdscript
# ─── cursor_state_host.gd(承機制一/五)──────────────────────
var _arbitration_suspended: bool = false

func suspend_arbitration() -> void      # 暫停選單/模態 UI 開啟時呼叫
func resume_arbitration() -> void       # 關閉時呼叫,內部觸發 _reclaim.reset(當下滑鼠座標)

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_FOCUS_OUT:
            _arbitration_suspended = true
        NOTIFICATION_APPLICATION_FOCUS_IN:
            _arbitration_suspended = false
            _reclaim.reset(get_viewport().get_mouse_position())  # 觸發點 (c):復焦重新播種
            _state.force_redraw_current_authority()               # AC-30
            _state.reapply_native_cursor_visibility()             # 機制十三
```

**決策**:暫停/模態期間的讓路採**顯式旗標** `_arbitration_suspended`,由呼叫方以 `suspend_arbitration()`/`resume_arbitration()` 驅動,**不以 `SceneTree.paused` 或 `process_mode` 作為判準**。

**拒絕 `SceneTree.paused` 的理由**:GDD 第六輪 Open Question 明確問「依賴 `SceneTree.paused` 搭配 `process_mode` 是否足以涵蓋專案內全部彈出情境,或是否存在不透過 `SceneTree.paused` 實作的非阻斷式彈窗」。答案在 GDD 自己的 AC-60 裡就已經是「存在」——該 AC 明文以「**不會使 `SceneTree.paused` 為真**的非登記表面(非模態設定側欄、成就吐司通知)」為測試情境。既然文件內部已經確立這類表面存在,把讓路機制建立在 `SceneTree.paused` 上就是建立在一個已知不完整的判準上。顯式旗標**不需要**回答那個 Open Question(該 OQ 因此從阻擋項降級,見 Verification Required 第 7 項),代價是呼叫方必須記得呼叫——這個代價由機制十的結構化回傳值與 AC-59 的測試涵蓋。

**兩條路徑的正交性**(GDD 第十三輪範圍澄清,本 ADR 必須忠實承載):`_arbitration_suspended` **只**閘控**被動裁定路徑**(機制五的 `_input()` 收集與 `_process()` 裁決),**不閘控**呼叫方透過機制十寫入介面發出的**主動 API 呼叫**。存檔讀取的甲分支(舊表面拆除前標記待重新解析)與丙分支(讀檔取消、返回原畫面前設定新目標)都可能發生在暫停選單仍顯示的轉場期間——這是文件明文要求的正確行為,不是例外。**因此 `set_target()`/`mark_pending_reresolve()` 絕不檢查 `_arbitration_suspended`。**

**失焦整段期間不運算**(GDD 第十輪重寫的觸發點 (c)):`_input()` 在 suspended 時直接 return,累積量因此在失焦全程完全不運算,不存在「失焦期間在背景悄悄逼近或跨過門檻」的可能;復焦當下才 `reset()` 並以復焦當下的滑鼠座標重新播種。

**Steam 疊加層的殘留風險**(Verification Required 第 5 項):若實測證實 Steam 疊加層不觸發 `NOTIFICATION_APPLICATION_FOCUS_IN`,機制九需新增備援偵測路徑(GDD 建議方向:額外監聽 `NOTIFICATION_WM_WINDOW_FOCUS_IN` 或輪詢式偵測)。本 ADR 不預先實作未經驗證的備援路徑——`suspend_arbitration()` 的存在讓 Steam 疊加層在最壞情況下仍可由呼叫方顯式處理。

### 機制十:寫入與讀取介面

```gdscript
# ─── 寫入(2 個方法,對應 GDD Core Rules #2)──────────────────
enum SetTargetResult { APPLIED, SURFACE_NOT_REGISTERED, INVALID_SURFACE_TYPE }
enum MarkResult { APPLIED, STALE_NOT_APPLIED, NO_CURRENT_TARGET }

# TR-cursor-012:雙輸入簽章(目標識別 + 是否由裝置 ui_* action 觸發),不含碰撞箱幾何。
# 有效性旗標自動翻回有效。
func set_target(target: CursorTarget, from_ui_action: bool) -> SetTargetResult

# TR-cursor-013:競態防呆 —— 傳入的 expected 與當下實際持有的目標不符即回傳
# STALE_NOT_APPLIED,絕不靜默忽略、絕不回傳 void。
func mark_pending_reresolve(expected: CursorTarget) -> MarkResult

# ─── 讀取(2 個查詢,對應 TR-cursor-014)─────────────────────
func is_current_target_valid() -> bool                  # 閘控確認動作
func get_device_authority() -> CursorTypes.Authority     # 閘控滑鼠點擊確認
func get_current_target() -> CursorTarget                # 回傳新配置的複本,見下方
```

**`get_current_target()` 回傳複本而非內部參照**:沿用 `returning_internal_container_references` forbidden pattern(ADR-0001 登記)。`CursorTarget` 是 `RefCounted`,回傳內部實例會讓呼叫方持有一個會被本系統就地變更的物件——即使 `CursorTarget` 設計為不可變,「不可變」是紀律而非結構保證,回傳複本讓它成為結構保證。

**「不含碰撞箱幾何」的沿革**(GDD 第九輪註記):寫入介面曾一度需要呼叫方提供命中框幾何。第九輪奪權門檻改為錨定表面類型固定像素常數後,任何形式的幾何查詢都不再存在——**目標識別中的表面類型標籤即為機制八門檻查表的鍵值**,足以取得該表面的固定常數,不需要額外幾何資料,也不需要每幀查詢。本 ADR 的簽章忠實反映此收斂結果。

**兩種拒絕回饋必須在感知上可區分**(GDD Core Rules #3 (iv)):
- **確認鍵被拒**(目標處於待重新解析)→ 呼叫方應查 `is_current_target_valid()`。正確補救:等待呼叫方重新解析,或自己導覽到別的目標。
- **滑鼠點擊被拒**(裝置權威非滑鼠)→ 呼叫方應查 `get_device_authority()`。正確補救:**移動**滑鼠達門檻取回權威,而非再點一次。

**兩者的正確補救動作相反**,回饋若無法區分,玩家會嘗試錯誤的補救動作。本 ADR 因此把它們分成**兩個獨立的讀取查詢**而非一個合併的「可否確認」布林——合併會讓呼叫方結構上無法產生可區分的回饋。**兩者皆須主動、可感知,絕不靜默拒絕**;具體回饋內容由呼叫方系統決定,本 ADR 只保證判別資訊可取得。

### 機制十一:跨畫面交接生命週期(甲/乙/丙三分支)

```gdscript
# 卸載前交接義務(TR-cursor-015)。三分支對應 GDD Core Rules #7 F2-2:
#   甲:讀檔流程開始、舊表面拆除前 → mark_pending_reresolve(當下目標)
#   乙:讀檔成功、新表面掛載後     → set_target(依 Core Rules #6 重新計算的初始目標)
#   丙:讀檔取消、返回原畫面前     → set_target(依 Core Rules #6 重新計算的新目標,AC-63b)
func handoff_before_unload(surface: CursorTypes.SurfaceType) -> MarkResult
```

**丙分支不是「還原暫停前的目標」而是「重新計算」**(GDD AC-63b):讀檔取消返回原畫面後,呼叫方須依 Core Rules #6 重新計算目標,不假設舊目標仍然有效。這與 AC-59 的「恢復當下裝置權威與游標目標與暫停前完全相同」看似矛盾,實則不然——AC-59 明文排除暫停期間發生的主動 API 呼叫,兩者管轄不同路徑(見機制九的正交性說明)。**本 ADR 的介面必須同時支援兩種行為,不得把任一種寫成唯一路徑。**

**裝置權威不隨目標交接重置**:`set_target()` 只在 `from_ui_action == true` 時連動裝置權威轉移。甲/乙/丙三分支的呼叫皆為系統主動改標,`from_ui_action` 一律傳 `false`——裝置權威維持不變(GDD Core Rules #4:裝置權威與游標目標是正交欄位)。

### 機制十二:全域每裝置待機指示宿主 —— Autoload 持有的 CanvasLayer

**決策**:`CursorStateHost` 持有一層 `CanvasLayer`(高 layer 值,恆在所有畫面內容之上),作為全域每裝置待機指示元件的宿主。

**這解決了 TR-cursor-016**——GDD 記載「戰鬥 HUD 是候選,但支援對話 UI 等非戰鬥畫面情境下這個指示元件如何呈現、由誰擁有,同樣需要答案」,結論是「現有候選擁有者皆為畫面範圍,無一符合」。**問題不在於候選者不夠好,而在於需求本身(存在於每個畫面)排除了任何畫面範圍的擁有者。** 一旦機制一建立了生命週期跨所有畫面的 Autoload,正確的宿主就存在了。

**本 ADR 定案宿主與行為契約,不定案視覺樣式**:具體美術樣式留待 `/art-bible`,比照 GDD 對「待重新解析」視覺的同一分工。ADR 保證的是:該元件存在於每個畫面、由單一擁有者渲染、不需要任何下游系統各自實作。

**未解決的部分**:GDD 的 Open Question 還問「非戰鬥畫面情境下這個指示元件**如何呈現**」——那是 UX/美術問題,本 ADR 不回答,已登記為 `producer`/`ux-designer` 於下游 UI 系統設計時的義務(GDD 已同步至 `systems-index.md` 跨系統義務登記表)。

### 機制十三:原生游標二元隱藏 + 自繪載體承擔連續 alpha

**決策**:
- **原生 OS/引擎滑鼠指標**:僅二元顯示/隱藏,透過 `Input.mouse_mode`(權威為滑鼠時 `MOUSE_MODE_VISIBLE`,否則 `MOUSE_MODE_HIDDEN`)。
- **奪權漸進回饋的連續透明度**:由機制十二那層 CanvasLayer 上的**自繪替代游標節點**承擔,其 `modulate.a` 讀取 `MouseReclaimPolicy.reclaim_progress()`。

**理由**:GDD 第五輪 Open Question 指出「原生指標若實際上不支援逐幀連續 alpha 動畫(4.7.1 下未經驗證),需改用下游自繪的替代游標圖形」,並指出此載體選擇會連動影響 AC-31 的驗證方式(`Input.mouse_mode` 斷言可能對自繪方案退化為恆真)與 Core Rules #5 抑制義務的掛載對象。

**本 ADR 直接選擇自繪載體,不等驗證結果**——理由不是悲觀,而是**自繪方案在兩種驗證結果下都成立**,而原生方案只在其中一種下成立。既然機制十二已經因為 TR-cursor-016 建立了那層 CanvasLayer,自繪載體的邊際成本接近零。這讓 Verification Required 第 4 項從阻擋項降為資訊項:若實測證實原生指標支援連續 alpha,本 ADR **不需要**修訂(自繪仍是上位方案)。

**AC-31 的驗證掛載點因此定案**:斷言對象是自繪節點的 `visible`/`modulate.a`,**不是** `Input.mouse_mode`——後者在自繪方案下對漸進回饋確實退化為恆真,GDD 的預判正確。`Input.mouse_mode` 的斷言仍用於驗證原生指標的二元抑制(Core Rules #5),兩者是兩個不同的驗證目標。

### 機制十四:已註冊表面禁用原生 Control focus/hover

**決策(2026-08-18 `godot-specialist` Step 5.5 驗證後修訂 —— 原決策不完整)**:每個已註冊表面的根 Control **必須同時**滿足以下**兩項**條件:

1. **`focus_mode = Control.FOCUS_NONE`** —— 排除鍵盤/手把焦點通道。
2. **不得帶有內建滑鼠 hover 主題狀態** —— 根 Control 不得是 `Button` 或任何在主題中內建 hover StyleBox 的節點型別;若因其他理由必須使用此類型別,**必須顯式清空其 hover/focus StyleBox**(使其 hover 狀態與 normal 狀態在視覺上不可區分)。

高亮視覺只讀 `CursorState`,不讀任何引擎原生焦點/懸停狀態。

**為何第 2 項是必要的、而非防禦性冗餘**(`godot-specialist` 2026-08-18 Step 5.5 驗證發現,本 ADR 原決策只有第 1 項):`focus_mode` 這個屬性的語意範圍,在 4.6 雙焦點系統引入**之前**就只管一件事——「鍵盤/手把能否經 Tab/方向鍵取得焦點」。滑鼠 hover 的原生視覺(例如 `Button` 內建的 hover 主題狀態)一直是由 `mouse_entered`/`mouse_exited` 加節點內部狀態機驅動,與 `focus_mode` 是**兩條獨立管線**,不是同一個屬性的兩個子情境。4.6 的雙焦點拆分改的是「滑鼠/觸控焦點」與「鍵盤/手把焦點」兩個**焦點判定通道**是否共用同一份狀態,**沒有**新增任何能被 `focus_mode` 統一關閉的滑鼠 hover 開關。

因此 `focus_mode = FOCUS_NONE` **大概率只關掉一半**:若已註冊表面的根 Control 帶內建 hover 主題,該節點會**獨立於本系統的全部邏輯**、單純因為滑鼠移到它上面就自行繪製原生 hover 視覺——即使本系統的高亮邏輯完全正確、完全只讀 `CursorState`,畫面上仍會出現兩個高亮。**這正是機制十四存在的理由本身,原決策卻只封住了兩條管線中的一條。**

**列入 Verification Required 第 9 項**(最小 spike,成本極低):`Button` 設 `focus_mode = FOCUS_NONE` 後,滑鼠懸停是否仍觸發 hover 主題繪製。若答案為「仍會」(專家判斷的高機率情況),第 2 項條件即為硬性要求;若答案為「不會」,第 2 項降為防禦性建議,但**不移除**——因為它的成本近乎零,而誤判的代價是重現 GDD 明訂的最高風險失敗情境。

**理由**(GDD Core Rules #7 + 第四輪 `godot-specialist` + `creative-director` 裁決):Godot **4.6 引入雙焦點系統**(滑鼠/觸控焦點與鍵盤/手把焦點分離),兩者可同時作用於不同 Control。若棋盤格高亮依賴原生 focus/hover 主題渲染,會直接重現 GDD Player Fantasy 明訂的最高風險失敗情境——「兩種高亮同時存在」。

**範圍一般化**(第五輪 `ux-designer` 發現、`creative-director` 裁決):此規則不限棋盤格,適用於**所有**具懸停/游標目標的 UI 表面,含關係圖迷你地圖等跨棋子比較介面。

**⚠️ 專案級風險,不限本系統**(`godot-specialist` 首輪 `/architecture-review` RISK-FLAG):4.6 雙焦點系統影響**所有**標準 Control 選單畫面,不只本作自訂的戰棋游標。好感度視覺呈現 UI(#9)、戰鬥 HUD(#10)、支援對話 UI(#11)、教學系統(皆尚未設計)開始設計時應留意。本 ADR 只約束**已註冊表面**;未註冊表面(非模態設定側欄等)仍可使用原生 focus 系統——GDD AC-60 明文承認這一點,並明文排除裝置權威欄位於該 AC 的斷言範圍外(未註冊表面上的方向鍵導覽仍會觸發 `ui_*` action、仍會被機制五的緩衝捕捉、仍可能依機制六轉移裝置權威——**這是預期中的正確行為**,因為裝置權威是全域的,只有游標目標欄位受表面登記邊界約束)。

### 機制十五:幀精準量測儀器

```gdscript
# 供 TR-cursor-019 的兩個硬性上限量測。診斷用,下游業務邏輯不得依賴。
var diagnostic_last_authority_change_frame: int   # Engine.get_process_frames()
var diagnostic_last_target_change_frame: int
var diagnostic_reclaim_progress_history: Array[float]   # 供收斂上限驗證
```

`max_handoff_visual_latency_frames`(GDD 已定案為 **1**)與 `reclaim_visual_convergence_max_frames`(嚴格大於 0,見 AC-46b)兩個上限都需要幀精準量測。機制六的 `process_priority` 定序讓交接在**同一影格**內完成,量測應驗證這個更強的保證,而非僅驗證 ≤1。

**與 ADR-0002 的診斷慣例一致**:診斷欄位明文標記為 QA-only,比照 `diagnostic_visited_count`。

### Architecture Diagram

```
                    ┌─────────────────────────────────────────────────┐
                    │  CursorStateHost  (Autoload, Node)              │
                    │  process_priority = -100                        │
                    │  ─────────────────────────────────────────────  │
   OS 輸入事件 ────▶│  _input()   → _frame_events: Array[InputEvent]  │
                    │               (只收集,suspended 時直接 return)  │
                    │  _process()  → _state.arbitrate_frame(events)   │
                    │  _notification() → FOCUS_IN/OUT (機制九)         │
                    │                                                 │
                    │  ┌───────────────────────────────────────────┐  │
                    │  │ CursorState (RefCounted) ← DI, 可 new()     │  │
                    │  │  _target: CursorTarget  (含 is_valid)      │  │
                    │  │  _device_authority: Authority              │  │
                    │  │  _reclaim: MouseReclaimPolicy ──┐          │  │
                    │  └────────────────────────────────│──────────┘  │
                    │                                   │             │
                    │   ┌───────────────────────────────▼──────────┐  │
                    │   │ MouseReclaimPolicy  @abstract            │  │
                    │   │  ⚠️ 凍結子機制的唯一居所                  │  │
                    │   │  ├ ThresholdMouseReclaimPolicy (現行)     │  │
                    │   │  │   內含 2 項已確認未修復缺陷 (E1/E2)     │  │
                    │   │  └ ImmediateMouseReclaimPolicy (除錯隔離) │  │
                    │   └──────────────────────────────────────────┘  │
                    │                                                 │
                    │  ┌───────────────────────────────────────────┐  │
                    │  │ CanvasLayer (機制十二/十三) priority = 50  │  │
                    │  │  ├ 全域每裝置待機指示   ← TR-cursor-016    │  │
                    │  │  └ 自繪奪權漸進回饋游標 ← TR-cursor-017    │  │
                    │  │      modulate.a = _reclaim.reclaim_progress()     │  │
                    │  └───────────────────────────────────────────┘  │
                    └───────┬─────────────────────────────┬───────────┘
              寫入 API      │                             │  讀取 API
        set_target()        │                             │  is_current_target_valid()
        mark_pending_...()  │                             │  get_device_authority()
        (不受 suspended 限) │                             │  get_current_target() → 複本
                            ▼                             ▼
        ┌───────────────────────────────┐   ┌────────────────────────────────┐
        │ 已註冊表面 (priority = 0)      │   │ 下游讀取方 (priority = 100)     │
        │  focus_mode = FOCUS_NONE ⚠️    │   │  戰鬥 HUD (#10)                │
        │  棋盤格 / 迷你地圖節點 /       │   │  好感度視覺呈現 UI (#9)         │
        │  卡牌槽位 / 對話選項           │   │  支援對話 UI (#11)              │
        │  單標籤單實例 (機制三)         │   │  讀游標目標更新自己的呈現        │
        └───────────────────────────────┘   └────────────────────────────────┘

  載入期一次性:CursorStartupValidator
    ├ Input Map:ui_* action 不得綁定滑鼠(除非語意為懸停/游標移動)
    └ Agile Event Flushing 必須關閉(鍵不存在 → 回報 UNKNOWN,不視為通過)
```

### Key Interfaces

以下為本 ADR 定案的契約形狀。**具體命名與型別簽章可在實作時微調,但語意不得改變**;任何改變語意的調整須回頭修訂本 ADR。

> **閱讀提醒**:以下為概念契約,不是可直接貼上的單一檔案。Godot 每個 `.gd` 檔只能有一個 `class_name`,實作時各類別應落在各自檔案。
>
> **`@abstract` 語法警告**(承 ADR-0004 的同一風險):本專案唯一已查證的 `@abstract` 範例(`current-best-practices.md`)採「冒號 + `pass` 主體」形式,下方沿用該形式。`godot-specialist` 在 ADR-0004 審查時無法在本環境確認何者正確,且**寫錯屬編譯期錯誤,會擋下整個檔案**——ADR-0004 的 Verification Required 第 6/6a 項同樣適用於本 ADR 的 `MouseReclaimPolicy`,且該專家明確指出這是四份 ADR 裡信心度最低、後果最嚴重的語法賭注。

```gdscript
# ─── cursor_types.gd ─────────────────────────────────────────
class_name CursorTypes extends RefCounted
enum SurfaceType { BOARD_TILE, RELATION_MINIMAP_NODE, CARD_SLOT, DIALOGUE_CHOICE }
enum Authority { UNINITIALIZED, MOUSE, KEYBOARD_GAMEPAD }
enum ActionClass { NAVIGATION, CONFIRM, OTHER }
static func encode_tile(coord: Vector2i, board_width: int) -> int
static func decode_tile(id: int, board_width: int) -> Vector2i

# ─── cursor_target.gd ────────────────────────────────────────
class_name CursorTarget extends RefCounted
var surface: CursorTypes.SurfaceType
var id: int
var is_valid: bool
func equals(other: CursorTarget) -> bool
static func make(surface: CursorTypes.SurfaceType, id: int) -> CursorTarget
static func invalidated(from: CursorTarget) -> CursorTarget

# ─── cursor_state.gd(DI 核心,單元測試直接 new()）────────────
class_name CursorState extends RefCounted
func _init(reclaim: MouseReclaimPolicy, registry: CursorSurfaceRegistry) -> void

func arbitrate_frame(events: Array[InputEvent]) -> void
func set_target(target: CursorTarget, from_ui_action: bool) -> SetTargetResult
func mark_pending_reresolve(expected: CursorTarget) -> MarkResult
func handoff_before_unload(surface: CursorTypes.SurfaceType) -> MarkResult
func is_current_target_valid() -> bool
func get_device_authority() -> CursorTypes.Authority
func get_current_target() -> CursorTarget          # 新配置的複本
func force_redraw_current_authority() -> void      # AC-30
func reapply_native_cursor_visibility() -> void    # Core Rules #5

# ─── cursor_state_host.gd(Autoload 薄殼,無裁定邏輯）─────────
class_name CursorStateHost extends Node
func suspend_arbitration() -> void
func resume_arbitration() -> void
# 全部公開 API 為對 _state 的一行轉發,不新增任何判斷邏輯。
```

## Alternatives Considered

### Alternative 1:純 Autoload(狀態與邏輯都在 Autoload 節點上)

- **Description**:`CursorStateHost` 直接持有三個頂層欄位與全部裁定邏輯,不分離 `CursorState`。
- **Pros**:最貼近 GDD「Autoload 類機制」的字面描述;少一層轉發,程式碼行數較少;不需要思考 DI 的注入時機。
- **Cons**:GDD 有 66+ 條 Acceptance Criteria,絕大多數是純邏輯的邊界情況(狀態機轉移、同幀仲裁、競態防呆、四個重置觸發點)。每一條都要在測試前後清理全域狀態、且需要一個活著的場景樹才能建構被測物。`.claude/docs/coding-standards.md` 明文要求「dependency injection over singletons」。
- **Rejection Reason**:會需要為 ADR-0002 登記的 `autoload_singleton_for_testable_data_layers` forbidden pattern 開一個例外——而該禁令的**理由**(Autoload 迫使每個測試攜帶全域狀態清理樣板)在本系統成立得比在好感度數值池更強烈,因為本系統的 AC 數量更多、狀態機分支更密。**開例外的正確門檻是「禁令的理由在此不成立」,不是「此處不方便遵守」**;本案是後者。

### Alternative 2:純依賴注入,不註冊任何 Autoload

- **Description**:`CursorState` 由最上層的遊戲根節點建構一次,經建構子/setter 逐層注入所有需要它的畫面與表面。
- **Pros**:最符合 forbidden pattern 的字面與精神;零全域狀態;測試最乾淨。
- **Cons**:TR-cursor-015 的跨畫面交接是本系統的硬性需求——甲/乙/丙三分支橫跨「舊表面拆除前」與「新表面掛載後」兩個畫面的生命週期。純 DI 下,注入鏈在任何一個畫面轉場處斷掉,交接就靜默失效,而「注入鏈完整」沒有任何結構性保證。此外 TR-cursor-016 要求的全域待機指示元件在純 DI 下重新變成無主(這正是 GDD 找不到擁有者的原因)。
- **Rejection Reason**:它把一個**結構性保證**(生命週期涵蓋所有畫面)降級為**紀律要求**(記得逐層注入)。GDD 明文把生命週期需求寫進 TR-cursor-001 而非留給實作,正是因為這件事不能靠紀律。**機制一的薄殼方案取得了兩者:Autoload 提供不可能斷的生命週期,DI 核心提供乾淨的可測性——兩個目標並不衝突,先前只是被當成二選一。**

### Alternative 3:裁決在 `_input()` 的最後一次呼叫,不進 `_process()`

- **Description**:在 `_input()` 內判斷是否為本影格最後一個事件,若是則立即裁定,省去一次 `_process` 週期。
- **Pros**:理論上少一個階段的延遲。
- **Cons**:`_input()` 無法知道自己是不是這一影格的最後一次呼叫——除非依賴 `_input()` 的跨節點派發順序,而那正是 GDD 第三輪已把「引擎輸入佇列處理順序」升級為阻擋項的同一類依賴。更關鍵:**`process_priority` 不管 `_input()` 的順序**,只管 `_process`/`_physics_process`,因此 TR-cursor-008 要求的「四行為者決定性同幀執行順序 + 具體 `process_priority` 數值」在 `_input()` 階段結構上無法實現。
- **Rejection Reason**:它為了一個未經量測的延遲收益,把正確性重新建立在 GDD 已明文拒絕依賴的引擎行為上。機制六的 `process_priority = -100` 讓裁定仍在**同一影格**內早於所有讀取方,`max_handoff_visual_latency_frames = 1` 的上限有充分餘裕。

### Alternative 4:滑鼠奪權門檻直接內嵌 `CursorState`,不做策略抽象

- **Description**:把門檻數學、累積器、四個重置觸發點直接寫在 `CursorState` 裡,不引入 `MouseReclaimPolicy`。
- **Pros**:少一層抽象;累積器與裝置權威欄位在同一個類別內,狀態轉移讀起來更直接。
- **Cons**:此子機制的重新設計已由使用者明文**暫停**,且帶著兩項已確認未修復的缺陷(E1 類比搖桿永久鎖死、E2 反方向零門檻秒搶回)。未來重啟設計時,若門檻邏輯與裝置權威裁定混在同一類別,修改範圍會擴散到機制六的仲裁、機制九的焦點閘控、機制十三的視覺載體。
- **Rejection Reason**:這會讓一個**已知會被重新設計**的子機制與四個**已經收斂**的機制耦合。ADR-0004 面對 Open Question 9 時採同一手法(`SaveIOBackend`),理由相同:在缺乏驗證依據時,把未解決問題的影響面縮到一個檔案,而不是讓它滲透整個系統。

### Alternative 5:待機指示元件交由戰鬥 HUD 擁有

- **Description**:依 GDD 記載的候選方向,由戰鬥 HUD(#10)渲染全域每裝置待機指示。
- **Pros**:戰鬥 HUD 持久呈現於戰鬥畫面,是最自然的候選;不需要本 ADR 建立新的視覺宿主。
- **Cons**:需求是「存在於**每個**畫面」。支援對話畫面、暫停選單、讀檔畫面都沒有戰鬥 HUD。GDD 自己的結論就是「現有候選擁有者皆為畫面範圍,無一符合」。
- **Rejection Reason**:需求本身(跨所有畫面)排除了任何畫面範圍的擁有者。機制一建立的 Autoload 是本專案第一個生命週期跨所有畫面的實體,它的出現讓這個缺口從「找不到擁有者」變成「擁有者順理成章」。

## Consequences

### Positive

- **19 項 `TR-cursor-*` 全部有機制支撐**(其中 3 項為部分——見 Negative),第二輪 `/architecture-review` 的唯一 FAIL 成因得以關閉。
- **自第四輪起懸而未決的「表面類型 enum 實作位置」定案**(機制二),且沿用已查證的 `AffinityTypes` 先例,不重蹈 ADR-0002 撞過的裸列舉編譯問題。
- **三個 GDD 標記為 `/create-architecture`「建議優先安排」的 Open Question 被降級**:暫停讓路手段(機制九不採 `SceneTree.paused`,不需要回答該 OQ)、原生游標連續 alpha 載體(機制十三選了在兩種驗證結果下都成立的方案)、型別白名單式的設定驗證(機制七的 `has_setting()` 防衛讓未知鍵名在執行期自我暴露)。
- **TR-cursor-016 的擁有權缺口被結構性解決**(機制十二),而非再次轉交給下游。
- **凍結的子機制被隔離在單一檔案**(機制八),未來重啟重新設計不需要動到其他四個機制。
- **對兩項 post-cutoff breaking change 結構性免疫**:4.7 裝置 ID 重新編號(機制四從不讀 `.device`)、4.6 雙焦點(機制十四禁用原生 focus/hover)。
- **`process_priority` 定序讓交接在同一影格內完成**,比 GDD 定案的 ≤1 影格上限更強。

### Negative

- **多一層轉發**:`CursorStateHost` 的每個公開 API 都是對 `CursorState` 的一行轉發。這是為可測性付的代價,且必須以紀律維持(禁止把邏輯搬進薄殼)——已列為 forbidden pattern 候選。
- **顯式暫停旗標依賴呼叫方紀律**:機制九不採 `SceneTree.paused`,代價是呼叫方必須記得呼叫 `suspend_arbitration()`。若某個模態 UI 忘了呼叫,暫停期間的背景輸入會被裁定。GDD AC-59 涵蓋此測試,但測試只能驗證已知的呼叫點。
- **棋盤座標須經 int 編碼**(機制三):呼叫方多一次 `encode_tile()`/`decode_tile()`。換得的是 `CursorTarget` 真正的值語意與型別無關的相等判定。
- **`TR-cursor-009/-010/-011` 僅為部分涵蓋**:機制八提供了隔離邊界與三方法契約,但**門檻數學本身的正確性未被本 ADR 保證**——它承載的是一個帶著兩項已確認缺陷、且重新設計已暫停的子機制。這是刻意的、經使用者裁決的狀態,不是本 ADR 的遺漏。
- **`@abstract` 語法賭注**:機制八的 `MouseReclaimPolicy` 是本專案第二處使用 `@abstract`(ADR-0004 為第一處),沿用同一個未經確認的語法形式。若寫錯是編譯期錯誤,會擋下整個檔案。

### Risks

| 風險 | 緩解 |
|---|---|
| **類比搖桿持續按住造成滑鼠奪權永久鎖死(E1,spike log 實測,100% 可重現,無任何暫行防線)** | **本 ADR 不緩解此缺陷** —— 使用者於 GDD 第十二輪明文裁決降級為建議事項、重新設計暫停、候選修法停止投入,待取得手把硬體。機制八只保證修復範圍是一個檔案。**明文不宣稱此風險已被圍堵。** 回合制戰棋對即時奪權手感的要求較低是該裁決的理由,不是缺陷不存在的理由 |
| **滑鼠奪權成功後被反方向零門檻豁免規則秒搶回(E2,真人口語觀察,僅測鍵盤路徑)** | 同上。GDD 明文記載:任何未來的重新設計若只處理同影格否決(觸發點 (d))而不處理反方向零門檻豁免規則,**不得**宣稱已解決此現象 |
| **D-pad 與類比搖桿在候選修法下的行為完全未測**(測試者無任何手把硬體) | GDD 明文:**不得假設「未測 = 沒問題」**。已正式登記為待辦(等使用者取得手把)。本 ADR 不因此阻擋——子機制已暫停 |
| **`_input()` 全數完成後才進入 `_process()` 這個前提未經實機驗證** | 機制六的定序基礎。列為 Verification Required 第 2 項,**風險等級高**。若不成立,機制五/六需重新設計裁決時點(但緩衝架構本身仍成立) |
| **Agile Event Flushing 設定鍵名未經查證** | 機制七以 `has_setting()` 先行防衛,鍵不存在時回報 `AGILE_FLUSHING_SETTING_KEY_UNKNOWN` 而非視為通過。這是唯一一處刻意讓未查證項在執行期自我暴露的設計 |
| **Steam 疊加層可能不觸發 `NOTIFICATION_APPLICATION_FOCUS_IN`** | `suspend_arbitration()` 的存在讓最壞情況下仍可由呼叫方顯式處理。若實測證實不觸發,機制九需新增備援偵測路徑 |
| **模組參考文件落後一個大版本** | 本 ADR 的引擎判斷一律以 `breaking-changes.md` 為準。列為 Verification Required 第 1 項,建議 technical-director 排入模組文件 4.7 更新 |
| **`focus_mode = FOCUS_NONE` 只關掉鍵盤/手把焦點,不關掉 Control 主題內建的滑鼠 hover 繪製**(`godot-specialist` Step 5.5 驗證發現,判斷為大概率成立) | 機制十四已據此修訂為**兩項**條件(第 2 項:已註冊表面根 Control 不得帶內建 hover 主題,或須清空其 hover/focus StyleBox)。Verification Required 第 9 項的最小 spike 成本極低,應優先執行。**若只實作第 1 項條件,本系統會在某些節點型別上重現 GDD 明訂的最高風險失敗情境「兩種高亮同時存在」,且該失敗與本系統邏輯是否正確完全無關** |
| **薄殼被後續開發者加入邏輯** | 登記為 forbidden pattern 候選 `logic_in_cursor_autoload_shell`,由程式碼審查攔截 |

## GDD Requirements Addressed

| TR-ID | 需求 | How This ADR Addresses It |
|---|---|---|
| TR-cursor-001 | 全域狀態恰 3 個頂層欄位;擁有節點生命週期須涵蓋所有畫面(Autoload 類機制) | 機制一:`CursorStateHost`(Autoload)為生命週期宿主,`CursorState`(`RefCounted`,DI)持有恰 3 個頂層欄位,有效性旗標為目標欄位內部結構不算第四欄 |
| TR-cursor-002 | 「表面類型」須為單一集中定義的共用 enum;實作位置與擁有者未定案 | 機制二:定案於 `cursor_types.gd`,包裝於 `class_name CursorTypes`(沿用 ADR-0002 `AffinityTypes` 已查證先例——裸列舉跨檔無法編譯) |
| TR-cursor-003 | 同一標籤任一時刻至多一個掛載實例;需要註冊/發現機制 | 機制三:`CursorSurfaceRegistry.register()` 對已占用標籤回傳 `DUPLICATE_TAG_REJECTED`,不覆寫;迭代一律經 `registered_surfaces_sorted()` |
| TR-cursor-004 | 裝置分類須依 `InputEvent` 子類別,絕不可讀 `.device`/裝置 ID | 機制四:`classify()` 只做子類別 match,結構性不觸及 `.device`;`-1` sentinel 列為下游警告項 |
| TR-cursor-005 | Input Map 約束:`ui_*` action 不得綁定滑鼠(除非語意為懸停/游標移動);須載入時驗證 | 機制七 (a):`CursorStartupValidator` 遍歷 `InputMap.get_actions()`/`action_get_events()`(已由 GDD 第十輪覆核為穩定 API);執行期重新綁定明文排除 |
| TR-cursor-006 | 須緩衝整幀 `InputEvent` 並收集完成後才裁決;須掛 `_input()`,絕不可 `_unhandled_input()` | 機制五:`_input()` 只 append 不裁定,`_process()` 統一 `arbitrate_frame()`;`_unhandled_input()` 的遺漏風險(被 `accept_event()` 消費的事件永不抵達緩衝區)明文記錄為拒絕理由 |
| TR-cursor-007 | 專案層級 Agile Event Flushing 必須保持關閉 | 機制七 (b):載入期驗證 + `has_setting()` 防衛(鍵不存在回報 UNKNOWN,不視為通過) |
| TR-cursor-008 | 四行為者的決定性同幀執行順序;需要具體 `process_priority` 數值 | 機制六:裁定者 −100、已註冊表面 0、全域視覺層 50、下游讀取方 100。**關鍵前提**:`process_priority` 不管 `_input()`,只管 `_process` —— 這正是裁決移到 `_process()` 的理由 |
| TR-cursor-009 | 滑鼠奪權門檻數學:逐表面類型像素常數、淨位移非路徑總和、根視窗座標空間 | **⚠️ 部分** —— 機制八提供隔離邊界與三方法契約(`evaluate`/`reclaim_progress`/`reset`),門檻數學封裝於 `ThresholdMouseReclaimPolicy`。**子機制重新設計已由使用者裁決暫停**,本 ADR 不保證門檻數學本身的正確性 |
| TR-cursor-010 | 累積器須依裝置權威 + OS 焦點閘控;須掛 `NOTIFICATION_APPLICATION_FOCUS_*`;暫停/彈窗讓出機制留待架構階段 | 機制九:焦點通知已掛載,失焦全程不運算、復焦 `reset()` 重新播種;**暫停讓出改採顯式旗標,不採 `SceneTree.paused`**(拒絕理由見機制九)。累積器本身的閘控 ⚠️ 隨機制八部分 |
| TR-cursor-011 | **已知確認、尚未修復的永久鎖死缺陷(持續按住方向輸入)**;已降級為建議項但架構層面仍未解決 | **⚠️ 部分,且刻意如此** —— 機制八把缺陷隔離在單一檔案,**明文不宣稱已緩解**。使用者第十二輪裁決:重新設計暫停、候選修法停止投入、待手把硬體 |
| TR-cursor-012 | 寫入介面「設定新目標」:雙輸入簽章,不含碰撞箱幾何,自動清除有效性旗標 | 機制十:`set_target(target, from_ui_action) -> SetTargetResult`;幾何查詢自 GDD 第九輪門檻改錨定表面類型常數後已完全不存在 |
| TR-cursor-013 | 寫入介面「標記待重新解析」:須回傳結構化的已套用/已過期結果,絕不靜默 | 機制十:`mark_pending_reresolve(expected) -> MarkResult`,`STALE_NOT_APPLIED` 為明確回傳值;競態判定依賴機制三的 `CursorTarget.equals()` 值語意 |
| TR-cursor-014 | 讀取介面:有效性旗標查詢 + 裝置權威查詢,兩者拒絕回饋須可區分 | 機制十:刻意分為**兩個獨立查詢**而非一個合併布林 —— 兩種拒絕的正確補救動作相反(等待重新解析 vs 移動滑鼠取回權威),合併會讓呼叫方結構上無法產生可區分回饋 |
| TR-cursor-015 | 卸載前目標交接義務,涵蓋存檔讀取整批替換的甲/乙/丙分支 | 機制十一:`handoff_before_unload()` + 三分支呼叫慣例;丙分支明文為「依 Core Rules #6 重新計算」而非「還原舊目標」(AC-63b);三分支 `from_ui_action` 一律 `false`,裝置權威不隨交接重置 |
| TR-cursor-016 | **全域每裝置待機指示元件須存在於每個畫面**;現有候選擁有者皆為畫面範圍,無一符合 | 機制十二:`CursorStateHost` 持有的全域 `CanvasLayer` 為宿主。**缺口成因是需求本身排除了畫面範圍擁有者**,機制一建立的 Autoload 是本專案第一個跨所有畫面的實體。視覺樣式仍留 `/art-bible` |
| TR-cursor-017 | 原生游標須在權威≠滑鼠時隱藏,唯一例外是連續漸變的奪權回饋 —— **連續透明度動畫在 4.7.1 可能不受原生游標支援** | 機制十三:原生指標僅二元 `Input.mouse_mode`;連續 alpha 由機制十二 CanvasLayer 上的自繪載體承擔。**選了在兩種驗證結果下都成立的方案**,故 Verification Required 第 4 項降為資訊項。AC-31 驗證掛載點定案為自繪節點的 `modulate.a` |
| TR-cursor-018 | 全鍵盤/手把平權;已註冊表面不得使用原生 Control 焦點/懸停主題(4.6 雙焦點分離) | 機制十四(2026-08-18 Step 5.5 後修訂為**兩項**條件):`focus_mode = FOCUS_NONE`(關鍵盤/手把焦點通道)**加上**根 Control 不得帶內建 hover 主題 / 須清空 hover-focus StyleBox(關滑鼠 hover 管線)——`focus_mode` 單獨**不足以**涵蓋此需求,兩者是獨立管線。高亮只讀 `CursorState`。**未註冊表面仍可用原生 focus**(GDD AC-60 明文承認),且其上的方向鍵導覽仍會轉移裝置權威 —— 這是正確行為,裝置權威是全域的 |
| TR-cursor-019 | 交接視覺延遲硬性上限(最多 1 幀)與奪權收斂上限,皆需幀精準量測機制 | 機制十五:`diagnostic_last_authority_change_frame` 等三個 QA-only 診斷欄位;機制六的定序讓交接在**同一影格**完成,量測應驗證這個更強保證 |

**涵蓋結論(本 ADR 自陳,待獨立 `/architecture-review` 驗證)**:19 項中 **16 項完整涵蓋**、**3 項部分涵蓋**(`TR-cursor-009`/`-010`/`-011`,全部落在使用者已裁決暫停的滑鼠奪權子機制)。**本 ADR 明文不宣稱 19/19 無缺口** —— 這正是第二輪 `/architecture-review` 在 ADR-0004 身上抓到的宣稱膨脹模式,不重蹈。

## Performance Implications

- **CPU**:`_input()` 每事件僅一次 `Array.append`,O(1)。`arbitrate_frame()` 對該影格事件數線性,而一影格內的輸入事件數是個位數量級(滑鼠移動事件最密,約每影格 1–2 個)。`classify()` 為常數次 `is` 判定。`MouseReclaimPolicy.evaluate()` 為一次 `Vector2` 距離計算 + 一次表面類型查表,O(1)。**全部落在每影格路徑,但總量遠低於 16.6ms 預算的任何可觀比例。**
- **Memory**:`_frame_events` 每影格清空,峰值與單影格事件數成正比。`CursorSurfaceRegistry` 上界為 `SurfaceType` 成員數(目前 4)。`diagnostic_reclaim_progress_history` 為診斷用,須有上界(建議環形緩衝,具體大小留實作)。
- **Load Time**:`CursorStartupValidator.validate()` 遍歷全部 `ui_*` action 一次,發生於啟動,非每幀路徑。
- **Draw Calls**:機制十二/十三的全域 CanvasLayer 新增至多 2 個繪製元素(待機指示、自繪游標),對 `<1000` 的專案預算(`technical-preferences.md`)無實質影響。
- **Network**:不適用(單人遊戲;`networking_features` 為專案級 forbidden pattern)。

**明確未定案**:各表面類型的 `reclaim_threshold_px` 具體值(GDD 初步校準數據:單一合成測試表面約 50–100px 手感自然,**非最終值,亦未依表面類型分別測試**,待垂直切片階段各表面分別校準);`reclaim_visual_convergence_max_frames` 具體值(僅約束嚴格大於 0)。

## Migration Plan

不適用 —— 本專案 `src/` 目前為空,尚無任何實作程式碼,處於設計階段。本 ADR 為前瞻性決策,不涉及既有程式碼遷移。

## Validation Criteria

1. **GDD Acceptance Criteria 章節 A~L 全部分類的向量通過** —— 這是本 ADR 機制是否真的支撐 GDD 義務的直接證據。特別關鍵:AC-2(恆一高亮不變式,含未初始化狀態)、AC-12(交接延遲 ≤1 影格)、AC-15/16(未初始化狀態與設定初始目標的正交性)、AC-20(同幀雙裝置固定優先序)、AC-59(暫停期間不裁定,且**排除**主動 API 路徑)、AC-60(登記制排除,且**不**斷言裝置權威)、AC-61/63a/63b(甲/乙/丙三分支)。
2. **`CursorState` 可在無場景樹的情況下 `new()` 並完整測試** —— 這是機制一分離設計的存在理由。若任何 AC 的測試需要一個活著的場景樹或需要清理全域狀態,機制一的分離就失敗了,應回頭檢查是否有邏輯洩漏進 `CursorStateHost`。
3. **`_unhandled_input()` 的反向驗證**:刻意構造一個聚焦中的 Control 消費 `ui_up`,驗證掛 `_input()` 的緩衝區**仍然收到**該事件。這直接驗證機制五拒絕 `_unhandled_input()` 的理由成立,而非只是相信文件。
4. **同幀仲裁的決定性測試**:同一組事件以不同順序餵入 `arbitrate_frame()`,驗證結果完全相同(固定優先序不依賴輸入順序)。這是 GDD「100% 決定性測試」宣稱的直接兌現。
5. **`process_priority` 定序的幀精準驗證**:斷言裁定者的欄位更新與讀取方的讀取發生在同一影格,且前者先於後者(以 `Engine.get_process_frames()` 為時基)。
6. **`CursorStartupValidator` 的三種失敗案例各自測試**,包含 `AGILE_FLUSHING_SETTING_KEY_UNKNOWN` —— 刻意以錯誤鍵名建構,驗證回報 UNKNOWN 而非靜默通過。
7. **`mark_pending_reresolve()` 的競態測試**:傳入與當下不符的 `expected`,驗證回傳 `STALE_NOT_APPLIED` 且當下合法目標未被誤標記。
8. **`MouseReclaimPolicy` 替換測試**:以 `ImmediateMouseReclaimPolicy` 替換後,機制六/九/十/十三的全部測試仍通過 —— 驗證機制八的隔離邊界真的只有三個方法寬。
9. **後續 `/architecture-review`**(須於**全新 session** 執行)判定本 ADR 與 ADR-0001~0004 無衝突,且對 19 項 `TR-cursor-*` 的涵蓋為 16 完整 / 3 部分(不宣稱無缺口)。

**反向驗證(本 ADR 若錯了會如何顯現)**:若機制一的分離不徹底(邏輯洩漏進 Autoload 薄殼),會表現為某些 AC 的單元測試開始需要 `add_child()` 或全域狀態清理 —— 驗證條件 2 會直接攔截。若機制六的 `_process` 定序前提不成立(`_input()` 未在 `_process()` 前全數完成),會表現為同幀仲裁結果隨事件抵達時序漂移 —— 驗證條件 4 會攔截,但**只在多次執行下才會顯現**,因此該測試須重複執行而非單次通過即算過。若機制十三的自繪載體未正確讀取 `reclaim_progress()`,會表現為漸進回饋視覺與判定值脫節(玩家看到指標淡入但奪權未發生,或反之)—— 這是 GDD Player Fantasy 明訂要消除的「探測性輸入後仍不確定」失敗情境本身。

## Related Decisions

- `design/gdd/cursor-highlight-state.md` —— 本 ADR 服務的全部義務之權威定義處(2026-08-13 第十六輪 Approved),本 ADR 只定案機制。該文件的 `Known Confirmed Defects` 節與 Open Questions 表是本 ADR 機制八/九/十三的直接輸入。
- `docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md` —— 機制二的 `CursorTypes` 包裝沿用其 `AffinityTypes` 先例(裸列舉跨檔無法編譯,該 ADR 的 BLOCKING 級修正);機制三的值型別鍵與顯式 `equals()` 沿用其 `mutable_container_as_dictionary_key` 登記立場;機制十五的診斷欄位沿用其 QA-only 標記慣例。**本 ADR 需要說明為何機制一不違反該 ADR 登記的 `autoload_singleton_for_testable_data_layers`**(見機制一)。
- `docs/architecture/adr-0004-save-system-atomic-write-and-migration-execution-model.md` —— 機制八的可替換策略邊界採其 `SaveIOBackend` 的同一手法(在缺乏驗證依據時把未解決問題的影響面縮到一個檔案);共用其 `@abstract` 語法的未驗證風險(Verification Required 6/6a)。機制十一的甲/乙/丙分支與該 ADR 的存檔讀取路徑直接交接。
- `docs/architecture/adr-0001-tactical-query-atomicity-contract.md` —— 機制三的迭代順序紀律沿用其 `relying_on_container_iteration_order`;機制十的回傳複本沿用其 `returning_internal_container_references`。
- `docs/architecture/architecture-review-2026-08-18-round2.md` —— 記錄本系統為第二輪審查 **FAIL 判定的唯一成因**(19/19 零涵蓋,Foundation 層),並把本 ADR 列為第一優先建議。
- `prototypes/cursor-reclaim-godot-spike-2026-08-05/` —— 機制八所承載缺陷的 E1 級證據來源;亦是 Control offset transforms 命中測試風險關閉的依據。
- `docs/registry/architecture.yaml` —— 本 ADR 完成後將登記的新增立場(見 Registry 更新提案)。
