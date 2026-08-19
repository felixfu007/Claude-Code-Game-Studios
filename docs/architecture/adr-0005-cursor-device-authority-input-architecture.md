# ADR-0005: 單一游標/高亮狀態系統 — 裝置權威輸入架構

## Status

**Proposed**

> **2026-08-19 修訂**:回應第三輪 `/architecture-review`(`docs/architecture/architecture-review-2026-08-19.md`,全新 session 獨立推導)判定的 9 項待修訂——**F1、F5 為 BLOCKING**(修好前不得進 `Accepted`),F2/F3/F4 為高/中,N1~N4 為 `godot-specialist` 於該輪額外發現。本次修訂已逐項處理全部 9 項,並經 `godot-specialist` 對修法本身的技術假設做第二輪驗證(見各機制內「F1/F2/…/N4 修訂」標記段落)。**本次修訂不改動任何其餘機制的既有決策**,也不重啟滑鼠奪權子機制的凍結重新設計(機制八的門檻數學本身仍是使用者裁決暫停的範圍)。修訂結果須待**全新 session** 的第四輪 `/architecture-review` 獨立驗證,本 ADR 不自陳此次修訂已使涵蓋率達 19/19。

> **2026-08-19 第四輪修訂(第二次修訂)**:回應第四輪 `/architecture-review`(`docs/architecture/architecture-review-2026-08-19-round4.md`,全新 session 獨立重推)。該輪判定上一次修訂 9 項中**完整關閉 6 項**(F5、F2、F4、N1、N2、N4),但 **F1 只關一半、F3 修法引入新違反**,並新增 7 項發現 R4-1~R4-7 與 `TR-cursor-015` 的兩項落差(第三輪未編號、修訂 session 依 9 項清單作業而漏掉)。**R4-2 為 BLOCKING(編譯期錯誤),R4-1/R4-3 視同 BLOCKING。** 本次修訂逐項處理全部 9 項,並額外處理撰寫本次修訂時核對出的**三項新事實**:(A) `ResetTrigger` 四個觸發點中 **(a)(b)(d) 三者在上一版全文零呼叫點**——與 `-015`(a) 漏掉「甲/乙分支重置為 0」是同一根因(補了列舉與訊號、沒補呼叫點地圖);(B) F2 把 `evaluate()` 改收滑鼠座標,但 `CursorState` 是 `RefCounted`、不在場景樹上,**全文沒有任何管道讓它取得座標**;(C) 上一版 Consequences 仍留著「19 項全部有機制支撐(其中 3 項為部分)」的舊自陳,與 Status 宣告的「不自陳涵蓋分佈」互相矛盾,已刪除。**本次修訂同樣不自陳修訂後的涵蓋分佈**——留給第五輪獨立 `/architecture-review` 重新推導。**模式警示**:第三輪抓到的是自陳膨脹,第四輪抓到的是**修法本身引入新缺陷**(R4-2/R4-3/R4-4 三項皆為上一次修訂新產生)。本次修訂因此對每一項修法額外自問「這個修法會不會製造下一個 R4-x」,並把答案寫進各機制的修訂標記段落。

## Date

2026-08-18(初版) / 2026-08-19(第一次修訂,F1~F5+N1~N4) / 2026-08-19(第二次修訂,R4-1~R4-7 + `TR-cursor-015` 兩項落差 + 三項新事實)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Input / UI / Core |
| **Knowledge Risk** | **HIGH** —— 4.7 為訓練截止(2026-01)後發布,且本 ADR 的兩個核心領域(Input、UI)在 4.6 與 4.7 各有一項直接相關的變更 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`、`breaking-changes.md`、`current-best-practices.md`、`deprecated-apis.md`、`modules/input.md`、`modules/ui.md` |
| **Post-Cutoff APIs Used** | 無新 API 依賴。本 ADR 依賴的機制(`_input()`、`_process()` + `process_priority`、`InputEvent` 子類別、`InputMap.get_actions()`/`action_get_events()`、`ProjectSettings.get_setting()`、`Input.mouse_mode`、`CanvasLayer`、`NOTIFICATION_APPLICATION_FOCUS_IN`/`_OUT`)皆為 4.4 前既有機制。**但本 ADR 刻意避開兩項 post-cutoff 變更的影響面**:(a) 4.7 鍵盤/滑鼠**裝置 ID 重新編號** —— 機制四結構性地從不讀取 `.device`(見機制四);(b) 4.6 **雙焦點系統** —— 機制十四禁止已註冊表面使用原生 Control focus/hover(這正是 GDD 第四輪裁決的成因) |
| **Verification Required** | 見下方「Verification Required 明細」—— 共 **14 列**(原 9 項 + 第一次修訂新增 #10 `_notification()` 時序、#11 `CanvasLayer` 恆等變換假設、#12 `@abstract`+`signal` 語法組合 + **第四輪修訂**:#11 依第四輪引擎專家更正**拆為 #11a/#11b**、新增 #13 `InputMap.event_is_action()` 是否過濾 `InputEventKey.echo`)。其中第 1 項(參考文件版本落後、涵蓋率缺口與**參考庫自相矛盾**)、第 9 項(`FOCUS_NONE` 涵蓋範圍)、第 10~13 項為本 ADR 撰寫/驗證過程中新發現,不屬 GDD 既有 Open Questions |

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
| `process_priority` | **機制六(六行為者定序的全部基礎;2026-08-19 第四輪修訂由五增為六)** | **零命中** |
| Autoload(註冊、生命週期、`_notification` 可達性) | 機制一、機制九 | **零命中** |
| `focus_mode` / `Control.FOCUS_NONE` | **機制十四(4.6 雙焦點的唯一防線)** | **零命中** |
| `accept_event()` | 機制五拒絕 `_unhandled_input()` 的因果鏈 | **零命中** |
| `CanvasLayer` | 機制十二、十三 | **零命中** |
| `Input.mouse_mode` | 機制十三 | **零命中** |
| `_input()` | 機制五 | 僅 `modules/input.md`(**4.6,版本落後**) |
| `mouse_filter` | 機制十四 | 僅 `modules/ui.md`(**4.6,版本落後**) |
| `InputMap.event_is_action()`(2026-08-19 修訂新增,N1) | 機制四之二(`ActionClass` 語意分類,機制六仲裁資格判定的輸入依賴——第三輪審查發現此依賴原本完全不在本表) | **零命中**(與 `get_actions()`/`action_get_events()` 同系列 API,已由第十輪 `godot-specialist` 覆核為穩定,但本表此前漏列)。**第四輪追加兩項未查證語意**:(i) 對 `InputEventMouseMotion` 必然回傳 `false`(與本設計一致,但上一版未明講,現明文記錄於機制四之二);(ii) **印象中不過濾 `InputEventKey.echo`** —— 已列為 Verification Required #13 |
| `Viewport.gui_get_hovered_control()`(2026-08-19 修訂新增,N3) | 機制十三之二(未登記表面 hover 時暫時恢復原生指標) | **零命中** |
| `CanvasLayer` 座標變換與 `get_viewport().get_mouse_position()` 的互動(2026-08-19 修訂新增,F2;**第四輪拆項**)——本 ADR 明文假設全域游標/待機指示 `CanvasLayer` 全程維持恆等變換(無位移/縮放/旋轉) | **僅**機制十三/十三之二的**視覺定位**(VR #11b)。機制八的淨位移計算**已由第四輪引擎專家更正為不受影響**(全程停留在 viewport 座標系,兩座標相減,從未轉進該層局部空間,VR #11a 降級為資訊項) | **零命中**——`godot-specialist` 於第一次修訂驗證中標記 **UNVERIFIABLE-FLAG-AS-RISK**,第四輪同一專家縮小其影響面至視覺定位一半 |
| `Node.add_child()` + 子節點獨立 `process_priority`(2026-08-19 第四輪修訂新增,R4-1) | 機制五/六的 `CursorNavigationApplier`(−25)—— `process_priority` 是**逐節點**屬性,同一節點不可能同時位於 −100 與 −25,故 GDD 四步序列的步驟一與步驟三必須落在兩個節點上 | **零命中**(與既有 `process_priority` 零命中同一缺口;Autoload 節點於 `_ready()` 內 `add_child()` 為基本 Node API,風險等級低於 `process_priority` 語意本身) |
| `Callable` 作為建構子注入的取值管道(2026-08-19 第四輪修訂新增,新發現 B) | 機制十 `CursorState._init()` 的 `mouse_position_provider` —— 讓 `RefCounted` 核心在無場景樹的情況下仍能取得滑鼠座標,同時讓單元測試可直接假造(Validation Criteria #2 的前提) | **零命中**(GDScript 語言層基本型別,非引擎子系統 API,風險等級低) |

**13 項核心依賴中 11 項在專案參考庫完全沒有記錄,另 2 項只存在於落後一個大版本的文件裡**(初版 8 項中 6+2;第一次修訂新增 3 項;**第四輪修訂再新增 2 項**〔子節點 `process_priority`、`Callable` 注入〕,全部零命中)。這不是本 ADR 的缺失,是專案引擎參考庫的結構性缺口——但它直接決定了本 ADR 的引擎判斷**有多少比例只能來自訓練資料印象而非查證**。ADR-0004 的第二輪審查已就 `modules/core-scripting.md`(序列化/雜湊/檔案 I/O/並發原語)提出同一類建議;本 ADR 再新增一項:**`modules/` 需要一份涵蓋 Node 生命週期與輸入派發語意的文件**(`process_priority`、`_input`/`_unhandled_input`/`_gui_input` 的派發鏈與 `accept_event()`、Autoload 語意、`CanvasLayer`、`focus_mode` 在雙焦點下的行為)。在那之前,機制五/六/十四的正確性依據**弱於**本專案其他 ADR 的平均水準,這一點必須被明文承認而不是藏在「Verification Required」的清單長度裡。

### Verification Required 明細

| # | 項目 | 來源 | 風險 |
|---|---|---|---|
| 1 | **`modules/input.md`/`modules/ui.md` 版本落後一個大版本**(4.6 vs 釘選 4.7.1)—— 須更新後回頭覆核本 ADR 的引擎假設。**2026-08-19 第四輪追加**:參考庫**自相矛盾**——`breaking-changes.md` 第 43 行標 4.4→4.5 為 `POST-CUTOFF, HIGH RISK`,`VERSION.md` 版本時間軸卻標 4.5 為 `LOW (pre-cutoff)`,兩份文件對同一版本的風險分級**相反**,而本 ADR 與 ADR-0004 的 `@abstract` 語法賭注正好押在 4.5。在矛盾未解前,本 ADR 一律以較保守的一側(HIGH RISK)為準,即 `@abstract` 相關項目維持 Day-1 spike 排程,不因 `VERSION.md` 標 LOW 而降級 | **本 ADR 新發現**(矛盾一項為第四輪 `godot-specialist` 發現、主審實測覆核成立) | 中 —— 已以 `breaking-changes.md` 代償,但代償不等於覆蓋;矛盾本身建議由 technical-director 一併處理 |
| 2 | **`_input()` 在同一影格內跨節點的派發順序**是否確定、可重現 —— 機制五刻意讓正確性**不依賴**此順序(緩衝而非即時處理),但機制六的六行為者定序需要確認 `_input()` 全數完成後才進入 `_process()` 這個前提在 4.7.1 成立 | 本 ADR 機制六 | **高** —— 機制六的定序基礎 |
| 3 | **`ProjectSettings` 中 Agile Event Flushing 的確切設定鍵字串**(推測為 `input_devices/buffering/agile_event_flushing`,**未經查證**) | GDD Open Question(第九輪) | 中 —— 鍵名錯誤會讓機制七的驗證靜默通過(`get_setting()` 對不存在的鍵回傳 `null`),比不驗證更危險。機制七已就此加設防衛 |
| 4 | **`Input.mouse_mode` 是否支援原生指標的連續 alpha 動畫** —— 本 ADR 機制十三**假設不支援**並據此設計,若實際支援,機制十三仍成立(自繪載體是上位方案),不需回頭修訂 | GDD Open Question(第五輪) | 低 —— 本 ADR 選擇了不依賴此答案的方案 |
| 5 | **Steam 疊加層是否觸發 `NOTIFICATION_APPLICATION_FOCUS_IN`** —— GDD AC-30 依賴此通知涵蓋 alt-tab / 最小化 / Steam 疊加層三情境,但 Steam 疊加層常以應用程式內 swapchain 層級掛鉤,不一定產生 OS 層焦點轉移 | GDD Open Question(第四輪) | 中 —— 若不觸發,機制九需備援偵測路徑 |
| 6 | **`InputMap.get_actions()`/`action_get_events()` 於 headless 載入後能正確反映「引擎內建預設綁定 + 專案自訂覆寫」的合併結果** | GDD Open Question —— **已於第十輪由 `godot-specialist` 覆核關閉**(此二 API 於 4.5→4.6→4.7 穩定、未變更、未棄用) | 低 —— 保留登記供追溯 |
| 7 | **暫停/模態的讓路手段** —— GDD Open Question 問「`SceneTree.paused` + `process_mode` 是否足以涵蓋專案內全部彈出情境」。**本 ADR 機制九不採用 `SceneTree.paused` 作為判準**(見機制九的拒絕理由),因此此 Open Question 對本 ADR 的實作可行性不再構成阻擋;仍須於 `/create-architecture` 盤點彈窗情境以確認機制九的顯式旗標有被正確呼叫 | GDD Open Question(第六輪) | 低(已被機制九降級) |
| 10 | **`NOTIFICATION_APPLICATION_FOCUS_IN`/`_OUT` 相對 `process_priority`(`_process()` 執行序)的時序完全未定義**——若 FOCUS_IN 在部分節點 `_process()` 已跑完、部分未跑的中途觸發,`force_redraw_current_authority()`/`reapply_native_cursor_visibility()` 可能讓部分下游在同影格讀到新舊混合的視覺狀態 | 第三輪 `/architecture-review`(**N2**,godot-specialist 於該輪額外發現) | 中——印象等級(信心度偏高),參考庫零涵蓋 |
| 11a | **~~機制八的淨位移計算受 `CanvasLayer` 變換影響~~ —— 第四輪引擎專家更正:此項為虛驚,已降級為資訊項**。機制八全程只是兩個 viewport-space 座標相減求距離(`current_mouse_position.distance_to(_seed)`),兩個座標都來自 `get_viewport().get_mouse_position()`,**從未轉進 `CanvasLayer` 的局部空間** → 結構上不受該層是否恆等變換影響 | 第一次修訂列為風險;**第四輪 `godot-specialist` 更正並降級** | **低**(原判高)——保留登記供追溯,不佔用 Day-1 spike 額度 |
| 11b | **機制十三/十三之二的視覺定位受 `CanvasLayer` 變換影響** —— 若把 viewport 座標直接指派給掛在該 `CanvasLayer` 底下的自繪節點 `position`,而該層帶非恆等變換,自繪游標的畫出位置會與滑鼠實際位置脫節;機制十三之二的 hover 判定亦同 | 第四輪 `godot-specialist` 自 #11 拆出——**綁在一起會讓 Day-1 spike 的範圍設計過寬,或反過來稀釋真正該驗的這一半** | **高**——這才是原 #11 的真風險所在,Day-1 spike 應只針對此半 |
| 13 | **`InputMap.event_is_action()` 是否過濾 `InputEventKey.echo`**(2026-08-19 第四輪修訂新增)——若不過濾,玩家**按住**方向鍵產生的重複 echo 事件會與初次按下同樣被機制四之二判為 `NAVIGATION`,亦即每一影格都在主張裝置權威。這會直接餵進機制八觸發點 (d)(同幀否決)與 E1 缺陷(類比搖桿持續按住造成滑鼠奪權永久鎖死)的因果鏈——**上一版 ADR 對此完全未討論** | 第四輪 `godot-specialist` 判定為「本次最值得回頭確認的一項」 | **高**——若不過濾,機制四之二須自行加 `event is InputEventKey and event.echo` 過濾,且該過濾要不要套用於觸發點 (d) 需回頭對照 GDD;但**該子機制已凍結**,此處只登記、不預先設計修法 |
| 12 | **`@abstract` 類別內同時宣告 `signal` 與多個 `@abstract func`(機制八 F3 修訂新增 `reset_triggered` 訊號)是否有語法限制** | 本次修訂新增(**godot-specialist** 標記 **UNVERIFIABLE-FLAG-AS-RISK**,與既有 `@abstract` 語法賭注同一風險等級) | 高——寫錯屬編譯期錯誤,擋下整個檔案 |
| 9 | **`focus_mode = FOCUS_NONE` 是否也排除 Control 主題內建的滑鼠 hover 繪製** —— `godot-specialist` 判斷**大概率不排除**(兩條獨立管線)。最小 spike:`Button` 設 `FOCUS_NONE` 後滑鼠懸停是否仍畫 hover 主題。決定機制十四第 2 項條件是硬性要求或防禦性建議 | **本 ADR Step 5.5 驗證新發現** | **高** —— 若不排除,單靠 `focus_mode` 的機制十四只封住兩條管線中的一條,原決策已據此修訂 |
| 8 | **`InputEvent.device` 於某些合成事件回傳 `-1` sentinel** —— GDD 第十一輪明文登記為「ADR 撰寫時的警告項」。本 ADR 機制四結構性不讀取 `.device`,不受影響;**但下游若為除錯/記錄用途讀取裝置 ID 須留意此值**,已列為機制四的明文警告 | GDD Open Question(第十一輪) | 低(本系統結構性免疫) |

**實作第一天的驗證排程建議**(`godot-specialist` Step 5.5 建議;第一次修訂新增第 11/12 項;**第四輪修訂:#11 拆項後只保留 #11b、新增 #13**):第 **2**(`process_priority` 不涵蓋 `_input()` 與批次前提)、**3**(Agile Event Flushing 鍵名)、**9**(`FOCUS_NONE` 是否也關 hover 主題)、**11b**(`CanvasLayer` 變換對機制十三/十三之二的**視覺定位**影響——**不含**已降級為虛驚的 #11a 淨位移計算)、**12**(`@abstract` 類別內含 `signal` 的語法組合,擴充自 ADR-0004 Verification Required 6/6a 的既有 `@abstract` 語法賭注)、**13**(`InputMap.event_is_action()` 是否過濾 `InputEventKey.echo`)**六項**,應在實作**第一天**先跑掉,不要留到整合測試後期。理由:六者的驗證成本都極低(一次幀精準測試、一次 `has_setting()` 查詢、一個 `Button` 懸停 spike、一個放在**帶非恆等變換的** `CanvasLayer` 底下的自繪節點定位比對、一個最小 `@abstract`+`signal` 檔案、一次按住方向鍵印出 `event_is_action()` 回傳值),但後果都是**全有全無**——`@abstract`/`signal` 組合寫錯是整檔案編譯失敗;`process_priority` 前提不成立會讓機制六整個定序失效;`FOCUS_NONE` 只關一半會讓機制十四在某些節點型別上失效;`CanvasLayer` 變換假設不成立會讓機制十三/十三之二的自繪定位與 hover 判定脫節;Agile Flushing 鍵名寫錯會讓機制七的驗證靜默通過,製造假的安全感;`echo` 若未被過濾,按住方向鍵會讓每一影格都在主張裝置權威。**先跑這六項,可以在寫任何正式程式碼之前就知道有沒有需要回頭修訂本 ADR。**

**`@abstract` 的三種回傳型別須分別編譯(2026-08-19 第四輪修訂新增,承第三輪部分關閉的殘留)**:第三輪已把 `@abstract` 語法從「印象」升級為「已查證」(與 `current-best-practices.md` 第 41–49 行範例逐字格式一致),但該文件範例只有 `Array[Attack]` 一種回傳型別,而本 ADR 的 `MouseReclaimPolicy` 用到 `bool`(`evaluate`)、`float`(`reclaim_progress`)、`void`(`reset`)、`Vector2`(`diagnostic_seed_position`,**本次修訂改標 `@abstract`,見 R4-2**)**四種**。Day-1 spike 的第 12 項應**四種各建一檔分別編譯**,不是只測一種。

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
- **單一根 Viewport 假設(2026-08-19 修訂新增,F2)**:機制八的滑鼠淨位移計算、機制十三/十三之二的原生指標判定與 hover 查詢,全程假設專案只有一個根 Viewport,滑鼠座標一律取自 `get_viewport().get_mouse_position()`,承載自繪游標/待機指示的 `CanvasLayer` 全程維持恆等變換(無位移/縮放/旋轉)。若未來引入分割畫面或多個獨立 Viewport,此假設須重新驗證(見 Verification Required 第 11 項)。
- **下游確認動作判讀的執行位置(2026-08-19 修訂新增,F1)**:任何下游系統解讀確認類 `ui_*` action 並查詢本系統狀態時,該判讀邏輯必須落在該系統自己的 `_process()`——若觸發來源是 `_physics_process()` 或其他回呼,呼叫方須自行轉呼叫延後至 `_process()`,不得直接在 `_physics_process()`/`_input()`/`_unhandled_input()` 內完成判讀(`process_priority` 只排序 `_process`/`_physics_process` 各自的鏈,兩鏈之間、以及 `_input()`/`_unhandled_input()` 相對兩鏈皆無排序保證,`godot-specialist` 本次修訂驗證明確指出此點)。

- **一系統身兼多個行為者角色時的節點拆分(2026-08-19 第四輪修訂新增,R4-7)**:機制六的行為者表暗示「一角色一節點」,但戰棋系統同時是**呼叫方主動改標**(②,−50)與**確認讀取方**(⑥,100)幾乎是必然。**規則**:同一系統身兼多個角色時,只有當這些角色在優先序梯上**相鄰、中間不存在其他行為者**時,才可合併於單一節點的單一 `_process()` 內以陳述順序保證相對順序;若中間隔著其他行為者,**必須拆成兩個節點**。②與⑥之間隔著③(−25 緩衝內導覽寫入)與④(0 已註冊表面),因此**②+⑥ 的雙角色系統必須拆節點**——把改標邏輯寫在確認讀取之前的單節點做法在此**不成立**(見機制六「R4-7 修法」的推導)。
- **`call_deferred()` 不得作為延後至 `_process()` 的手段(2026-08-19 第四輪修訂新增,R4-6)**:上一版對「觸發來源在 `_physics_process()` 的呼叫方」提出兩條路線,其中「使用 `call_deferred()` 排入下一次 `_process()`」是一個**未經查證的排程時點斷言**——本 ADR 從未驗證延後呼叫的沖洗點相對 `_process` 鏈的位置。若落點在 `_process` 鏈之後或次影格,當幀的確認讀取(⑥)會先於改標(②)發生,重新打開 R4-1/F1 剛關上的洞。**該選項已刪除**,只保留旗標路線(設旗標,於自己 `_process()` 開頭檢查並執行)。

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
11. **確認動作判讀的執行位置(2026-08-19 修訂新增,F1,AC-52)**:任何下游系統解讀確認類 `ui_*` action 並查詢本系統狀態(`is_current_target_valid()`/`get_device_authority()`)時,判讀邏輯必須在該系統自己的 `_process()` 執行,絕不可掛 `_input()`/`_unhandled_input()`——這是 GDD 四步完整定序(裝置權威判定 → 呼叫方主動改標呼叫 → 緩衝內導覽類 `ui_*` 寫入 → 緩衝內確認類 `ui_*` 讀取)成立的必要條件,是正確性要求,不是風格偏好。

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
> **但這是一個需要驗證的形狀變更**:GDD **AC-1** 要求對公開方法行為做窮盡檢視、確認不存在未被承認的第四個欄位。該 AC 的測試必須針對本 ADR 的形狀執行(`CursorState` 的 3 個欄位 + `MouseReclaimPolicy` 內部的累積量與起點),**不得**假設原 GDD 措辭下的扁平三純量形狀。~~若 AC-1 的窮盡檢視認定「策略物件內部另有累積起點」構成第四個未承認欄位,則本 ADR 須回頭把起點也明文列入契約~~ **2026-08-19 修訂已補上**(F2 修法的必然結果——`_seed` 現在確定是 `MouseReclaimPolicy` 的內部欄位,見機制八):`diagnostic_seed_position() -> Vector2` 已加入介面契約。第三輪 `/architecture-review` 因此條件未解而將 TR-cursor-001 由 ✅ 降為 ⚠️,本次修訂視為一併關閉,惟涵蓋判定仍須待獨立 `/architecture-review` 確認。

# ─── cursor_state_host.gd ────────────────────────────────────
# Autoload。只負責四件事,不含任何裁定邏輯:
#   (1) 生命週期宿主 —— 持有唯一的 CursorState 實例,生命週期涵蓋所有畫面
#   (2) 輸入緩衝掛載點 —— _input() 收集,_process() 裁決(機制五/六);2026-08-19 第四輪修訂
#       (R4-1)另於 _ready() 內 add_child() 一個 CursorNavigationApplier(process_priority = -25),
#       承擔 GDD 四步序列的步驟三,見機制五/六
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

# 2026-08-19 修訂新增(F2/F3)——GDD Core Rules #3 四個累積起點重置觸發點 (a)(b)(c)(d) 的具名列舉,
# 取代先前僅以散文字母指稱。機制八 reset() 與 reset_triggered 訊號皆以此列舉溝通。
# 2026-08-19 第四輪修訂新增第五個值 SURFACE_HANDOFF —— ⚠️ 它**不是** GDD Core Rules #3 的第五個
# 觸發點(該規則明文只有四個)。它的來源是 Core Rules #7 F2-2 的另一條獨立義務,見下方註記與機制十一。
enum ResetTrigger {
    AUTHORITY_TRANSFER,      # (a) 裝置權威任一方向轉移        —— 呼叫點:機制六 arbitrate_device_authority()
    TARGET_CHANGED,          # (b) 目前高亮目標改變            —— 呼叫點:機制十 _write_target_internal()
    FOCUS_LOST_REGAINED,     # (c) 失焦全程不運算,復焦重新播種 —— 呼叫點:機制九 resume_arbitration() / FOCUS_IN
    VETOED_SAME_FRAME,       # (d) 同影格達門檻但被鍵盤/手把導覽類動作否決——唯一允許呈現層單影格瞬間歸零的觸發點(AC-41b)
                             #                                 —— 呼叫點:機制六 arbitrate_device_authority()
    SURFACE_HANDOFF,         # 2026-08-19 第四輪修訂新增(TR-cursor-015 落差 (a))。來源為 GDD Core Rules #7
                             # F2-2 而非 Core Rules #3:「滑鼠奪權累積位移量於甲/乙兩分支皆重置為 0」。
                             # 呈現層待遇同 (a)(b)(c)——收斂,不瞬間歸零(只有 (d) 是 AC-41b 的例外)。
                             #                                 —— 呼叫點:機制十一 handoff_before_unload()
}
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

### 機制四之二:動作語意分類 —— `ActionClass`(2026-08-19 修訂新增,N1)

```gdscript
# 機制四的 classify() 只做裝置類別分類,不做動作語意分類。但機制六「僅 NAVIGATION 類
# ui_* 具主張裝置權威資格」需要另一層判定——第三輪 /architecture-review 發現本 ADR
# 完全沒給這個機制,且該依賴不在核心依賴涵蓋率表裡(N1)。
# 2026-08-19 第四輪修訂(R4-5):三份清單構成 ui_* action 的「明文三分割」。
# 第三份 ACKNOWLEDGED_OTHER_ACTIONS 不是為了讓 classify_action() 用(它本來就 fallthrough 到
# OTHER),而是為了讓機制七 (c) 的完整性驗證有一個「已被人工看過並確認不是導覽類」的白名單
# 可以比對。任何 ui_* action 若三份清單皆未命中,即為「未分類」,由機制七於載入期回報,
# 不靜默降級為 OTHER。
const NAVIGATION_ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]
const CONFIRM_ACTIONS: Array[StringName] = [&"ui_accept", &"ui_cancel"]
# 明文承認為非導覽類的引擎內建 ui_* action(值為參考起點,實作時須以實際 InputMap 內容補齊)。
const ACKNOWLEDGED_OTHER_ACTIONS: Array[StringName] = [
    &"ui_focus_next", &"ui_focus_prev", &"ui_page_up", &"ui_page_down",
    &"ui_home", &"ui_end", &"ui_select", &"ui_menu",
]

static func classify_action(event: InputEvent) -> CursorTypes.ActionClass:
    # 對 InputEventMouseMotion 必然全數回傳 false → 落到 OTHER。這與本設計一致
    # (滑鼠主張權威走機制八的門檻路徑,不走 action 路徑),但上一版未明講,現明文記錄。
    # ⚠️ InputEventKey.echo 是否被過濾未經查證(Verification Required #13)——若不過濾,
    #    按住方向鍵的每一個重複事件都會被判為 NAVIGATION。此處不預先加過濾:該行為的正確
    #    處置與凍結中的奪權子機制(觸發點 (d)、E1 缺陷)耦合,須待 spike 結果與 GDD 對照。
    for action in NAVIGATION_ACTIONS:
        if InputMap.event_is_action(event, action):
            return CursorTypes.ActionClass.NAVIGATION
    for action in CONFIRM_ACTIONS:
        if InputMap.event_is_action(event, action):
            return CursorTypes.ActionClass.CONFIRM
    return CursorTypes.ActionClass.OTHER
```

**決策**:以 `InputMap.event_is_action(event, action_name)` 對照固定的導覽類/確認類 action 名單判定 `ActionClass`,獨立於機制四的裝置類別 `classify()`——一個事件同時經過兩層分類(裝置類別 + 動作語意),互不取代。`InputMap.event_is_action()` 與本 ADR 已使用、經第十輪 `godot-specialist` 覆核穩定的 `InputMap.get_actions()`/`action_get_events()` 同系列,`godot-specialist` 本次修訂驗證確認**穩定、無棄用風險**,已補登記於上方核心依賴涵蓋率表(此前遺漏正是 N1 指出的問題本身)。

**理由**:機制六仲裁只允許「鍵盤/手把的 NAVIGATION 類 `ui_*` action」與「滑鼠達門檻位移」兩類事件主張裝置權威,確認類與其他非導覽類 action 結構性被排除在仲裁範圍外(GDD Core Rules #3「確認類動作與裝置權威的關係」)。這道判定若不獨立於 `classify()` 明文定案,`arbitrate_device_authority()` 的「僅 NAVIGATION 具資格」規則會變成沒有具體實作依據的空話。

**R4-5 修法(2026-08-19 第四輪修訂)—— 白名單完整性驗證,不靜默降級**:第四輪 `/architecture-review` 判定上一版的硬編碼六項清單與本 ADR 在別處反覆兌現的「絕不靜默」紀律不一致。GDD 對「導覽類 `ui_*` action」的定義是**語意性、開放式**的(「語意上代表『移動游標』的動作」),而機制四之二是**封閉**的清單;機制七 (a) 的載入期驗證器雖遍歷全部 `ui_*` action,驗證的卻是完全不同的屬性(是否誤綁滑鼠),**不做分類完整性的交叉檢查**。後果:未來新增任何語意上屬於導覽的 `ui_*` action(專案自訂,或啟用引擎內建的 `ui_focus_next`/`ui_page_up` 等),會被**靜默**歸為 `OTHER`、失去主張裝置權威的資格,沒有任何啟動期或執行期檢查會攔下。

修法採**明文三分割**而非「未命中即回報」:後者會在啟動時把數十個引擎內建 `ui_*` action 全部報成待分類,噪音大到會被實作者直接關掉,反而製造比靜默更糟的結果。三分割要求每一個 `ui_*` action 都被**人工歸入三份清單之一**,新增 action 時若忘了歸類,機制七 (c) 於載入期回報 `UI_ACTION_UNCLASSIFIED`——這與機制七 (b) 的 `has_setting()` 防衛是同一個設計原則:**讓未經人工確認的狀態在執行期自我暴露,而不是靜默採用一個預設值。**

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
    # 2026-08-19 修訂(F5,BLOCKING):原版本沒有比照 _input() 檢查 _arbitration_suspended——
    # 若同影格內 _input() 已 append 事件之後 _arbitration_suspended 才變 true,原版本仍會裁定
    # 那批事件。這個競窗 100% 確定存在,不依賴任何未驗證引擎行為(第三輪 godot-specialist
    # 對抗性覆核 CONFIRMED)。
    #
    # 2026-08-19 第四輪修訂(R4-1):原版本在此一次呼叫 arbitrate_frame() 內完成 GDD 四步序列的
    # 步驟一(裝置權威判定)與步驟三(緩衝內導覽類寫入),實際定序為 1&3 → 2 → 4,與 GDD 明文
    # 的 1 → 2 → 3 → 4 相反。現拆為兩次呼叫、掛在兩個不同 process_priority 的節點上。
    # 本節點(−100)只做步驟一,不碰目標欄位。
    if _arbitration_suspended or _frame_events.is_empty():
        return
    _state.arbitrate_device_authority(_frame_events)   # 機制六 ①:GDD 步驟一
    # ⚠️ 緩衝區不在此清空 —— 步驟三(−25 的 CursorNavigationApplier)還要再讀一次。
    #    清空責任已移交給該影格緩衝的最後一個消費者,見下方 flush_buffered_navigation()。

func flush_buffered_navigation() -> void:
    # 由 CursorNavigationApplier(−25)於其 _process() 呼叫。緩衝區維持私有,不外露內部參照
    # (沿用 returning_internal_container_references 禁令)。
    if _arbitration_suspended or _frame_events.is_empty():
        return
    _state.apply_buffered_navigation(_frame_events)    # 機制六 ③:GDD 步驟三
    _frame_events.clear()

# ─── cursor_navigation_applier.gd(2026-08-19 第四輪修訂新增,R4-1)──
# CursorStateHost 於 _ready() 內 add_child() 建立的專屬子節點,process_priority = -25。
# 存在的唯一理由:process_priority 是逐節點屬性,同一個節點不可能同時位於 −100 與 −25,
# 而 GDD 四步序列要求步驟三發生在步驟二(呼叫方主動改標,−50)之後。
# 本節點沿用機制一薄殼的同一紀律 —— 只有一行轉發,不含任何裁定邏輯。
class_name CursorNavigationApplier extends Node

var _host: CursorStateHost

func _process(_delta: float) -> void:
    _host.flush_buffered_navigation()
```

**F5 修法範圍(2026-08-19 修訂,BLOCKING)**:上方 `_process()` 已補上 `_arbitration_suspended` 檢查。**另一半修法在機制九**——`suspend_arbitration()`、`resume_arbitration()`、`NOTIFICATION_APPLICATION_FOCUS_OUT`、`NOTIFICATION_APPLICATION_FOCUS_IN` **四個進出點,原版本沒有任何一個呼叫 `_frame_events.clear()`**,暫停期間緩衝區內的殘留事件會一直躺著,直到下次 `_process()`(可能已是復焦後的影格)被誤裁定,與復焦當下的新事件混在一起處理——違反 GDD 觸發點 (c)「失焦期間完全不運算」與機制九自己宣稱的「暫停期間被動裁定路徑不參與」。四個進出點的具體修法見機制九。

**R4-1 修法對 F5 的連帶影響(2026-08-19 第四輪修訂,必須明文記錄)**:緩衝區的清空點從 −100 移到 −25 之後,同一影格內出現一個新的中間狀態——「步驟一已裁定、步驟三尚未套用」。若 `_arbitration_suspended` 在這兩者之間翻為 `true`(例如呼叫方於 −50 的 `_process()` 內開啟模態選單),則:(i) 該影格的**裝置權威已被裁定**,無法回溯;(ii) `suspend_arbitration()` 自己會 `_frame_events.clear()`,因此步驟三不會套用,`flush_buffered_navigation()` 進入時緩衝區已空,直接 return。**這是刻意接受的行為**,理由是它與 GDD 的既有精神一致——裝置權威是全域欄位、其轉移本就不受表面或畫面邊界約束(見機制十四對 AC-60 的說明),而游標目標的寫入才是暫停期間應該讓路的部分。**替代方案(把裝置權威判定也延後到 −25 與導覽寫入合併)已被否決**:那會讓步驟一晚於步驟二,直接重新違反 GDD 四步序列,是用一個確定的定序違反去換一個邊緣情境的一致性。此中間狀態已列為 Validation Criteria #10 的新增測試向量。

**掛 `_input()`、禁 `_unhandled_input()`**(GDD Core Rules #3 實作架構約束,第九輪升級為阻擋項):`_unhandled_input()` 只會收到 Control 自身 GUI 處理(透過 `accept_event()`)未消費的事件。若一個聚焦中的 Control 其內建焦點導覽邏輯消費了 `ui_up`/`ui_down`,該事件會**完全不抵達**緩衝區——這是**遺漏**而非重排序,緩衝架構本身無法補救一個從未進入緩衝區的事件,足以推翻 GDD 最核心的「100% 決定性測試」宣稱。`godot-specialist` 於首輪 `/architecture-review` **CONFIRMED** `_input()` 為正確做法。

**為何裁決在 `_process()` 而非 `_input()` 的最後一次呼叫**:GDD 要求「整幀事件收集完畢後才統一裁定」,但 `_input()` 本身無法知道自己是不是這一影格的最後一次呼叫。**關鍵引擎事實:`process_priority` 只管 `_process`/`_physics_process`,不管 `_input()` 的派發順序**——因此「四行為者的決定性同幀執行順序」(TR-cursor-008)只可能建立在 `_process` 階段。把裁決移到 `_process()` 讓正確性建立在一個可用 `process_priority` 精確控制的階段,而不是建立在 `_input()` 跨節點派發順序這個未經驗證的引擎行為上(列為 Verification Required 第 2 項——需確認的是「該影格全部 `_input()` 完成後才進入 `_process()`」這個更弱的前提,而非派發順序本身)。

### 機制六:六行為者的決定性同幀定序 —— 具體 `process_priority` 數值(2026-08-19 兩次修訂,F1 → R4-1,BLOCKING)

**第三輪 `/architecture-review` 判定(F1,BLOCKING)**:本表原版本列的是**節點渲染更新序**(①②③④),**不是** GDD Core Rules #2 明文定案的「四方完整定序」——**裝置權威判定 → 呼叫方主動改標呼叫 → 緩衝內導覽類 `ui_*` 寫入 → 緩衝內確認類 `ui_*` 讀取**(AC-52)。原表裡根本沒有「呼叫方主動改標」這個行為者的位置,而「確認動作判讀由誰執行、掛在哪裡」原版本從未定義——若下游系統在自己的 `_input()`/`_unhandled_input()` 裡直接處理確認動作,該讀取會發生在同影格 `_process()` **開始之前**,連「裁定者先跑」這個最基本保證都不成立,違反 AC-52(該 AC 此前也不在 Validation Criteria 清單裡,已於下方補齊)。

**第一次修法(2026-08-19,F1)**:新增第二個行為者「呼叫方主動改標」,並把「確認動作判讀」的執行位置提升為對下游系統的明文約束,而非只是本系統內部的一條紀律。**該修法只關了一半**,見下方第四輪判定與 R4-1 修法。

**2026-08-19 第四輪 `/architecture-review` 判定(R4-1,高,視同 BLOCKING)——上一次修法只關一半**:上一版新增了②(呼叫方主動改標,−50)並把確認讀取提升為明文約束,`-008` 的 AC-52 面因此成立;但**步驟三仍與步驟一融在 −100 的同一次 `arbitrate_frame()` 呼叫內**,實際定序為 **1&3 → 2 → 4**,與 GDD 明文的 1 → 2 → 3 → 4 相反。上一版的辯護是「步驟一、三皆為本系統內部運算,呼叫方看不到中間狀態」——**該論證只處理可觀察性,未處理先後權**。具體行為差異(第四輪主審與 `godot-specialist` 各自獨立推導出同一結論):同一影格,呼叫方 `set_target(A)`(步驟二)與緩衝內導覽寫入 `ui_right`(步驟三)並存時,最後寫入者勝——上一版排序下 ② 覆寫 ①,**玩家當幀的方向鍵輸入被系統主動改標整個蓋掉**;GDD 排序下則是導覽寫入在呼叫方改標的基礎上計算並勝出。且 AC-52 明訂的驗證方式是「程式碼審查為主——確認實作的節點執行順序符合四步序列」,照上一版的機制六審查會不通過。

**R4-1 修法(拆節點,六行為者)**:

| 行為者 | 節點 | `process_priority` | 職責 |
|---|---|---|---|
| ① 裁定者 | `CursorStateHost`(Autoload) | **−100** | 消化該影格緩衝事件,`arbitrate_device_authority(events)` 完成**裝置權威判定**(GDD 四步序列**步驟一**)。**不碰目標欄位**;**不清空緩衝區** |
| ② 呼叫方主動改標 | 任何因遊戲語意事件(非 `ui_*` 觸發,例如單位死亡)需呼叫 `mark_pending_reresolve()`/`set_target()` 的下游系統,於**該系統自己的節點** `_process()` | **−50**(架構強制;−100 與 −25 之間任一值皆滿足排序,此為參考值) | GDD 四步序列**步驟二** |
| ③(第四輪新增)緩衝內導覽寫入 | `CursorNavigationApplier`——`CursorStateHost` 於 `_ready()` 內 `add_child()` 的專屬子節點 | **−25**(架構強制;必須嚴格介於 ② 與 ④ 之間) | `apply_buffered_navigation(events)` 依①已裁定的權威套用緩衝內導覽類 `ui_*` 目標寫入(GDD 四步序列**步驟三**),**並清空緩衝區**(該影格緩衝的最後一個消費者) |
| ④ 已註冊表面 | 各 `CursorSurface` | **0**(預設) | 讀取狀態,渲染自己的高亮/待重新解析視覺 |
| ⑤ 全域視覺層 | `CursorStateHost` 持有的 CanvasLayer 子節點 | **50** | 待機指示、奪權漸進回饋載體、機制十三之二的 hover 判定(機制十二/十三,同一節點單一 `_process()` 內完成,避免與其他 priority=50 節點的同層排序未定義問題) |
| ⑥ 下游讀取方(含確認動作判讀) | 戰鬥 HUD、好感度視覺 UI、支援對話 UI,於**該系統自己的節點** `_process()` | **100** | 讀取游標目標更新自己的呈現;**GDD 四步序列步驟四**——任何解讀確認類 `ui_*` action 並查詢 `is_current_target_valid()`/`get_device_authority()` 的邏輯必須落在此處,絕不可掛 `_input()`/`_unhandled_input()`(見 Requirements 第 11 項、Constraints「下游確認動作判讀的執行位置」) |

**定序對照(這是本修法唯一要證明的事)**:①(−100)→ ②(−50)→ ③(−25)→ ⑥(100),即 GDD 明文的 **1 → 2 → 3 → 4**,逐步對齊、無融合。④⑤ 是純讀取的渲染方,不屬 GDD 四步序列的任何一步,插在 ③ 與 ⑥ 之間不影響該序列。

**為何必須是兩個節點而不是一個節點內的兩段程式碼**:`process_priority` 是**逐節點**屬性,同一個節點的 `_process()` 只會在優先序梯上出現一次。步驟一必須在 −100(早於任何呼叫方),步驟三必須在 −25(晚於呼叫方 −50)——兩個位置之間隔著一個**外部系統**的執行,沒有任何辦法用單一節點的陳述順序達成。這也是為什麼上一版把兩步融在一起:它不是疏忽,是在單節點前提下的唯一可能,而該前提本身才是要被推翻的東西。

**R4-7 修法(2026-08-19 第四輪修訂新增)—— 一系統身兼多角色**:上表與下方 Architecture Diagram 都暗示「一角色一節點」,但戰棋系統同時是②(呼叫方主動改標)與⑥(確認讀取方)幾乎是必然,上一版對此一字未提。**規則**:多角色合併於單一節點的單一 `_process()`、以陳述順序保證相對順序,**只在這些角色於優先序梯上相鄰、中間不存在其他行為者時成立**。

> **本 ADR 在此部分修正第四輪報告採納的修法方向。** 第四輪 `godot-specialist` 推翻主審初判(「優先序梯無解」)並提出「把改標邏輯寫在確認讀取之前即可,不需拆節點」——該推翻的**前提**(`process_priority` 管不到函式內部,同節點內陳述順序自由)完全正確,但它的**結論**在②+⑥ 這組具體角色上不成立:②與⑥之間隔著③(−25,本系統自己的子節點)與④(0,已註冊表面),單節點方案會把②的改標推遲到 ③ 之後(若節點設 100)或把⑥的確認讀取提前到 ③ 之前(若節點設 −50),兩者各自重新違反 GDD 四步序列的一段。**因此②+⑥ 雙角色系統必須拆成兩個節點**(建議:主節點設 100 承擔⑥,另建一個極薄的子節點設 −50 承擔②,比照本 ADR 自己對 `CursorNavigationApplier` 的處理)。陳述順序方案仍適用於**相鄰**角色的合併,例如同時是④與⑤的系統。

**`process_priority` 只排序同一種回呼各自的鏈,不跨鏈**(`godot-specialist` 本次修訂驗證新增澄清,**BLOCKING 修法的必要前提**):`process_priority` 分別排序 `_process()` 鏈與 `_physics_process()` 鏈,**兩鏈之間彼此無排序保證**;`_input()`/`_unhandled_input()` 更完全不受 `process_priority` 管轄。因此:(a) 若②的觸發來源是某系統的 `_physics_process()`(例如物理碰撞判定角色死亡),該系統**不得**在 `_physics_process()` 內直接呼叫 `mark_pending_reresolve()`,必須將呼叫轉移到自己的 `_process()`——**唯一許可的手段是設一個旗標、於自己 `_process()` 開頭檢查並執行**。直接在 `_physics_process()` 呼叫不受本表任何優先序保證約束。**`call_deferred()` 路線已於 2026-08-19 第四輪修訂刪除(R4-6)**:上一版把它與旗標路線並列為等價選項,但延後呼叫的沖洗時點相對 `_process` 鏈的位置**本 ADR 從未查證**;若落點在 `_process` 鏈之後或次影格,當幀的確認讀取(⑥)會先於改標(②)發生,重新打開 R4-1 剛關上的洞。兩條路線不等價,不得並列;(b) ⑥的「絕不可掛 `_input()`/`_unhandled_input()`」不是本系統一廂情願的紀律要求,而是**唯一能讓 process_priority 的排序保證真正生效**的必要條件——`godot-specialist` 明確指出:即使替 `_unhandled_input()` 也編一個優先序數字,`process_priority` 依然管不到它,只有明文禁止才能堵住這個路徑。

**`process_priority`(更新順序)與 `CanvasLayer.layer`(繪製疊放順序)是兩個獨立概念**,本表指的一律是前者;機制十二/十三那層 CanvasLayer 的 `layer` 值另行設定,不與本表數值混用(`godot-specialist` Step 5.5 建議明確分開標注以降低下游誤讀)。**Godot 的 `process_priority` 是數值小者先執行**,因此裁定者(−100)必然早於任何讀取方。這讓「交接視覺延遲 ≤ 1 影格」(`max_handoff_visual_latency_frames` = 1,GDD 已定案)成為**同一影格內即完成**的更強保證,而非勉強達標。

**同幀雙裝置的固定優先序仲裁**(GDD Edge Cases,第四輪重寫為不依賴引擎佇列順序):

```gdscript
# ① priority = −100(GDD 步驟一)。2026-08-19 第四輪修訂:原 arbitrate_frame() 的前半。
func arbitrate_device_authority(events: Array[InputEvent]) -> void:
    # 只有「具備主張裝置權威資格」的事件參與仲裁。資格僅兩類:
    #   (a) 鍵盤/手把的 NAVIGATION 類 ui_* action(機制四之二 classify_action())
    #   (b) 滑鼠達到該表面類型 reclaim_threshold_px 的位移(機制八 evaluate() 判定)
    # CONFIRM 類與其他非導覽類動作不具資格,不落入仲裁範圍。
    #
    # 固定優先序:KEYBOARD_GAMEPAD 恆勝於 MOUSE。不讀引擎佇列順序,100% 決定性。
    #
    # 滑鼠奪權判定所需的目前座標取自 _mouse_position_provider.call()(機制十,新發現 B),
    # 不從事件裡撈 —— handoff 等無事件路徑也要用同一個管道,兩處不得分歧。
    #
    # ⚠️ 本函式**不寫入目標欄位**。它只可能寫入 _device_authority,並依下列規則呼叫
    #    _reclaim.reset()(2026-08-19 第四輪修訂新增,新發現 A —— 上一版只有觸發點 (c)
    #    有呼叫點,(a)(b)(d) 三者全文零呼叫點):
    #      · 若本影格 _device_authority 發生任一方向的轉移
    #          → _reclaim.reset(pos, ResetTrigger.AUTHORITY_TRANSFER)      # 觸發點 (a)
    #      · 若滑鼠當幀已達門檻、但鍵盤/手把的 NAVIGATION 類動作依固定優先序勝出
    #          → _reclaim.reset(pos, ResetTrigger.VETOED_SAME_FRAME)       # 觸發點 (d)
    #        (僅 NAVIGATION 類觸發本路徑;僅有 CONFIRM 類時不成立,滑鼠奪權正常完成
    #         —— GDD Core Rules #3 第十一輪窄化,見 AC-58)
    #    觸發點 (a) 與 (d) 在同一影格互斥:(d) 的定義前提就是權威**未**轉移。

# ③ priority = −25(GDD 步驟三)。2026-08-19 第四輪修訂新增:原 arbitrate_frame() 的後半。
func apply_buffered_navigation(events: Array[InputEvent]) -> void:
    # 依①已裁定的 _device_authority 決定是否套用緩衝內的導覽類 ui_* 目標變更。
    # 權威非 KEYBOARD_GAMEPAD 時本函式為 no-op(滑鼠不透過 action 路徑改標)。
    #
    # 目標寫入一律走 _write_target_internal()(私有,不受 _mutation_in_progress 檢查,
    # 見機制十 R4-4 修法);若目標確實改變,由該私有方法統一呼叫
    #   _reclaim.reset(pos, ResetTrigger.TARGET_CHANGED)                   # 觸發點 (b)
    # 並發出 target_changed()。
```

**為何鍵盤/手把恆勝**(GDD 明文理由,本 ADR 忠實承載):滑鼠是絕對定位裝置,同幀落敗只需下一次達門檻的移動即可重新取得權威,誤判代價趨近於零;鍵盤/手把是相對定位裝置,同幀意外落敗會讓玩家感受到剛按下的方向鍵「沒有反應」,心智模型斷裂的代價高得多。

### 機制七:載入期設定驗證 —— Input Map 約束 + Agile Event Flushing 鎖定

```gdscript
# ─── cursor_startup_validator.gd ─────────────────────────────
class_name CursorStartupValidator extends RefCounted

enum ValidationFailure {
    NONE,
    UI_ACTION_BOUND_TO_MOUSE,           # TR-cursor-005
    AGILE_EVENT_FLUSHING_ENABLED,       # TR-cursor-007
    AGILE_FLUSHING_SETTING_KEY_UNKNOWN, # 見下方防衛
    UI_ACTION_UNCLASSIFIED,             # 2026-08-19 第四輪修訂新增(R4-5),見下方 (c)
}

func validate() -> Array[ValidationFailure]   # 空陣列 = 全數通過
```

**(a) Input Map 約束驗證**(TR-cursor-005):遍歷 `InputMap.get_actions()`,對每個 `ui_*` action 呼叫 `InputMap.action_get_events()`,若任一 event 為 `InputEventMouseButton`/`InputEventMouseMotion` 而該 action **語意上非懸停/游標移動**,回報 `UI_ACTION_BOUND_TO_MOUSE`。這道約束是 Core Rules #3「滑鼠奪權前提約束」成立的前提——Steam Input／觸控板可能注入與真實滑鼠事件無法區分的合成事件,若 `ui_*` action 同時綁定滑鼠,合成事件會在「最後操作裝置決定權威」規則下竊取手把的權威。此二 API 已由 GDD 第十輪 `godot-specialist` 覆核為 4.5→4.6→4.7 穩定、未變更、未棄用。

**範圍明文排除**(GDD 第五輪裁決):驗證僅於載入期執行一次。玩家執行期重新綁定按鍵不在本設計範圍內——`systems-index.md` 尚無「輸入設定/重新綁定系統」。該系統一旦設計,須回頭替本 ADR 補執行期重新驗證機制。

**(b) Agile Event Flushing 鎖定**(TR-cursor-007):機制五「一影格 = 一批原子化事件」的前提依賴專案設定 `Input Devices → Buffering → Agile Event Flushing` 維持關閉(引擎預設)。若任何系統日後為求低延遲開啟它,事件會即時派發而非批次收集,**全域**破壞本系統的定義前提。

**設定鍵未知的防衛**(本 ADR 新增):推測鍵名為 `input_devices/buffering/agile_event_flushing`,**未經查證**(Verification Required 第 3 項)。`ProjectSettings.get_setting()` 對不存在的鍵回傳 `null`——若鍵名寫錯,驗證會**靜默通過**,比不驗證更危險(製造了虛假的安全感)。因此驗證器**先**以 `ProjectSettings.has_setting()` 確認鍵存在:不存在則回報 `AGILE_FLUSHING_SETTING_KEY_UNKNOWN`(而非視為通過),迫使實作階段查出正確鍵名。**這是本 ADR 唯一一處刻意讓「未經查證」在執行期自我暴露的設計**,理由是此設定的破壞範圍是全域且靜默的。

`godot-specialist` 於首輪 `/architecture-review` 對此設定的原子性保證標記 **LIKELY-BUT-UNVERIFIED**——設定本身確實存在,但「一幀 = 一個原子批次」的具體保證需實機計時測試確認。

**(c) `ActionClass` 分類完整性驗證(2026-08-19 第四輪修訂新增,R4-5)**:遍歷 `InputMap.get_actions()` 中全部 `ui_*` action,對照機制四之二的三份清單(`NAVIGATION_ACTIONS` / `CONFIRM_ACTIONS` / `ACKNOWLEDGED_OTHER_ACTIONS`)。**任一 `ui_*` action 三份皆未命中即回報 `UI_ACTION_UNCLASSIFIED`,連同該 action 名稱一併回報**(供實作者人工歸類),不靜默視為 `OTHER` 通過。

**為何這道驗證與 (a) 是兩件事**:(a) 檢查的是「`ui_*` action 有沒有誤綁滑鼠」,(c) 檢查的是「`ui_*` action 有沒有被人工分類過」——兩者遍歷同一個集合、驗證完全不同的屬性。上一版只有 (a),導致新增一個語意上屬於導覽的 `ui_*` action 時,**沒有任何啟動期或執行期檢查會攔下它被靜默降級為 `OTHER`**(R4-5)。

**與 (a) 相同的範圍排除**:本驗證同樣僅於載入期執行一次,同樣不涵蓋玩家執行期重新綁定——若未來新增「輸入設定/重新綁定系統」,(a) 與 (c) 須一併補執行期重新驗證。

### 機制八:滑鼠奪權子機制 —— 可替換策略邊界(凍結項的隔離)

```gdscript
# ─── mouse_reclaim_policy.gd ─────────────────────────────────
# 2026-08-19 修訂(F2、F3):三方法簽章改版,新增一個訊號。詳見下方「F2 修法」「F3 修法」。
@abstract
class_name MouseReclaimPolicy extends RefCounted

# F3 新增:呈現層(機制十三)訂閱此訊號以判斷本次歸零是否為觸發點 (d)(唯一允許瞬間歸零者)。
signal reset_triggered(trigger: CursorTypes.ResetTrigger)

# F2 修訂:改收「目前滑鼠螢幕座標」(根視窗座標,見 Constraints「單一根 Viewport 假設」),
# 淨位移由實作內部以 current_mouse_position.distance_to(_seed) 計算,不再由呼叫方算好傳入。
# 回傳本影格滑鼠是否取得有效的奪權主張資格。
@abstract
func evaluate(current_mouse_position: Vector2, surface: CursorTypes.SurfaceType) -> bool:
    pass
# GDD 稱此值為 `reclaim_progress`(0.0~1.0),供機制十三的呈現層平滑器讀取(不再直綁 modulate.a,見機制十三)
@abstract
func reclaim_progress() -> float:
    pass
# F2/F3 修訂:新增 trigger 參數,標明四個重置觸發點 (a)(b)(c)(d) 中的哪一個(CursorTypes.ResetTrigger),
# 供內部記錄 seed 之餘,亦透過 reset_triggered 訊號通知呈現層。
@abstract
func reset(seed_position: Vector2, trigger: CursorTypes.ResetTrigger) -> void:
    pass
# 2026-08-19 修訂新增(回應 TR-cursor-001 的條件式涵蓋——見機制一「第三個頂層欄位的歸屬」註記:
# AC-1 窮盡檢視若認定累積起點是未被承認的第四欄位,本 ADR 須補一個可查詢的 getter)。
# QA/測試專用,下游業務邏輯不得依賴,比照機制十五 diagnostic_* 慣例。
#
# 2026-08-19 第四輪修訂(R4-2,BLOCKING):上一版寫成「無 @abstract 標記、主體 return _seed」,
# 但 _seed 只宣告於子類別 ThresholdMouseReclaimPolicy,而 GDScript 的靜態解析作用域是
# 「本類別 + 祖先鏈」,不會往子類別查找 → 編譯期在 _seed 上失敗。且 Key Interfaces 段落寫的
# 是無主體簽章、本節寫的是有主體範例,兩處自相矛盾,本身就是訊號。
# 改標 @abstract,與同檔案其餘三方法一致 ——「起點」本就是門檻子機制特有的概念,不該假設
# 每個未來策略實作都有。(另一選項「把 _seed 上移到基底」已否決:代價是
# ImmediateMouseReclaimPolicy 等實作被迫攜帶一個對它無意義的欄位。)
@abstract
func diagnostic_seed_position() -> Vector2:
    pass

# ─── threshold_mouse_reclaim_policy.gd ───────────────────────
# 現行實作:GDD Core Rules #3 的表面類型固定像素門檻。
# ⚠️ 本檔案內含兩項 GDD 已確認、尚未修復的缺陷(見 Consequences → Risks)。
# ⚠️ 本子機制的重新設計已由使用者於 GDD 第十二輪明文暫停,待手把硬體。
class_name ThresholdMouseReclaimPolicy extends MouseReclaimPolicy

var _seed: Vector2   # F2 修訂新增:起點內部化,evaluate() 不再依賴呼叫方算好的淨位移

func diagnostic_seed_position() -> Vector2:
    return _seed     # R4-2:實作下放到子類別,基底只留 @abstract 簽章

# ─── immediate_mouse_reclaim_policy.gd(除錯隔離用)──────────
# R4-2 連帶:本實作雖無「門檻累積」概念,仍須實作 diagnostic_seed_position()。
# 它照樣會收到 reset(seed_position, trigger) 的座標,直接原樣回存回傳即可 ——
# 診斷契約因此對所有策略實作一致,不需要呼叫方判斷「這個策略有沒有起點」。
```

**F2 修法(2026-08-19 修訂)**:原簽章 `evaluate(mouse_motion_net_delta: Vector2, surface) -> bool` 對「誰持有累積起點」自相矛盾——`reset(seed_position)` 暗示策略物件持有起點,`evaluate(net_delta)` 卻暗示呼叫方已算好淨位移,兩種語意各沾一半。第三輪 `/architecture-review` 指出**最危險的是參數命名本身**:`arbitrate_frame()` 手上只有 `InputEventMouseMotion`,看到 `_net_delta` 這個參數名、且每幀被呼叫一次,最自然的實作就是累加 `event.relative`——那正好是 GDD Core Rules #3 明文禁止的**路徑總和**(禁止理由:路徑總和會讓原地抖動在零淨位移下也能跨過門檻)。修法:`evaluate()` 改收**目前滑鼠螢幕座標**(而非位移量),策略內部以自己持有的 `_seed`(由 `reset()` 播種)相減計算淨位移,`reset(seed_position)` 的語意因此自洽,且結構性杜絕路徑總和的實作路徑。座標空間的明文假設見 Constraints「單一根 Viewport 假設」——`godot-specialist` 本次驗證標記此假設本身 **UNVERIFIABLE-FLAG-AS-RISK**(承載自繪游標的 `CanvasLayer` 若非恆等變換會使座標脫節),已列入 Verification Required 第 11 項。**2026-08-19 第四輪更正**:該專家於第四輪回頭指出,機制八的淨位移**全程停留在 viewport 座標系**(兩個 `get_viewport().get_mouse_position()` 回傳值相減求距離),從未轉進 `CanvasLayer` 的局部空間,**結構上不受該層變換影響——此處為虛驚**。真風險只在機制十三/十三之二把 viewport 座標畫到該層子節點上的那一半。原第 11 項已拆為 **#11a(本項,降級為資訊項)** 與 **#11b(視覺定位,維持高風險、留在 Day-1 spike)**。**上一版把兩者綁在一起,會讓 spike 範圍設計過寬,或反過來稀釋真正該驗的那一半。**

**F2 修法留下的懸空(2026-08-19 第四輪修訂補上,新發現 B)**:`evaluate()` 改收「目前滑鼠座標」之後,**上一版全文沒有任何管道讓 `CursorState` 取得該座標**——它是 `RefCounted`、不在場景樹上,`get_viewport()` 對它不存在;全文唯一取得座標的地方是機制九裡 `CursorStateHost` 自己的兩次呼叫。修法:`CursorState._init()` 注入 `mouse_position_provider: Callable`(見機制十),`arbitrate_device_authority()` 與 `handoff_before_unload()` 走同一個管道,兩處不得分歧。附帶好處:單元測試可直接注入常數 lambda,Validation Criteria #2「可在無場景樹下 `new()` 並完整測試」因此仍然成立——若改採「每個方法各加一個 `Vector2` 參數」,測試雖然也能過,但介面面積會隨每一個未來需要座標的方法持續擴張。

**F3 修法(2026-08-19 修訂,見機制十三的呈現層平滑器實作)**:GDD 是兩個值的模型——`reclaim_progress` 本身必須立即反映全部四個重置觸發點,但**呈現層透明度**對觸發點 (a)(b)(c) 不得單影格瞬間歸零,必須在 `reclaim_visual_convergence_max_frames` 內收斂,觸發點 (d) 才是**唯一**允許同影格瞬間歸零的例外(AC-41b)。原版本的 `modulate.a` 直綁 `reclaim_progress()`,對 (a)(b)(c) 必然違反 AC-41,且三方法契約沒有任何管道讓呈現層知道這次歸零是哪個觸發點造成的。修法:新增 `reset_triggered` 訊號,呈現層(機制十三)訂閱後才知道該 snap 還是漸退。

**⚠️ 契約寬度的誠實記錄(回應 F3 對 Validation Criteria #8 的動搖;2026-08-19 第四輪再次更新)**:本 ADR 初版自陳「機制八的隔離邊界只有三個方法寬」。**現況是四個 `@abstract` 方法 + 一個訊號**——`evaluate`/`reclaim_progress`/`reset` 三者的方法數量不變,但 `reset()` 的參數面拓寬(新增 `trigger`),另新增 `reset_triggered` 訊號與 `diagnostic_seed_position()`(第一次修訂新增為具體方法,**第四輪修訂 R4-2 改標 `@abstract`,因此它現在計入抽象契約寬度,不再是基底提供的免費實作**)。**契約每寬一格,凍結子機制未來重啟重新設計時要重新談的東西就多一項** —— 這是為修正 F3/R4-2 付出的實際代價,不應被「只是加個診斷方法」的說法掩蓋。這是**連動修訂**,不是措辭澄清——已同步修正 Validation Criteria #8 的措辭(見下方)。若未來替換 `_reclaim` 實例(例如切換至 `ImmediateMouseReclaimPolicy` 做隔離測試),呼叫方須自行重新訂閱新實例的 `reset_triggered`——訊號連接不隨物件替換自動轉移(`godot-specialist` 本次驗證提醒)。

**決策**:滑鼠奪權的門檻數學、累積器、四個重置觸發點、漸進回饋進度值,全部封裝在 `MouseReclaimPolicy` 的單一實作檔內,`CursorState` 只透過上述介面與它互動。

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

# 2026-08-19 修訂(F5,BLOCKING):四個進出點原版本沒有任何一個呼叫 _frame_events.clear()——
# 暫停期間緩衝區的殘留事件會一直躺著,直到下次 _process()(可能已是復焦後的影格)被誤裁定。
# 四者現在全部清空緩衝區,搭配機制五 _process() 新增的 _arbitration_suspended 檢查,
# 兩處合起來才是完整修法。
func suspend_arbitration() -> void:      # 暫停選單/模態 UI 開啟時呼叫
    _arbitration_suspended = true
    _frame_events.clear()

func resume_arbitration() -> void:       # 關閉時呼叫
    _arbitration_suspended = false
    _frame_events.clear()
    _reclaim.reset(get_viewport().get_mouse_position(), CursorTypes.ResetTrigger.FOCUS_LOST_REGAINED)

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_FOCUS_OUT:
            _arbitration_suspended = true
            _frame_events.clear()
        NOTIFICATION_APPLICATION_FOCUS_IN:
            _arbitration_suspended = false
            _frame_events.clear()
            _reclaim.reset(get_viewport().get_mouse_position(), CursorTypes.ResetTrigger.FOCUS_LOST_REGAINED)  # 觸發點 (c):復焦重新播種
            _state.force_redraw_current_authority()               # AC-30
            _state.reapply_native_cursor_visibility()             # 機制十三
```

**`resume_arbitration()` 一併補上 `_reclaim.reset()`(2026-08-19 修訂新增)**:原版本只有 `_notification()` 的 FOCUS_IN 分支重新播種累積起點,`resume_arbitration()`(呼叫方主動關閉暫停選單時呼叫)沒有對應動作——但暫停/模態的關閉不透過 OS 焦點通知,若不比照處理,關閉選單瞬間的累積起點會停留在選單開啟前的過期座標,與觸發點 (a)(裝置權威轉移)的既有精神矛盾。此為本次修訂中發現的相鄰缺口,一併修正。

**決策**:暫停/模態期間的讓路採**顯式旗標** `_arbitration_suspended`,由呼叫方以 `suspend_arbitration()`/`resume_arbitration()` 驅動,**不以 `SceneTree.paused` 或 `process_mode` 作為判準**。

**拒絕 `SceneTree.paused` 的理由**:GDD 第六輪 Open Question 明確問「依賴 `SceneTree.paused` 搭配 `process_mode` 是否足以涵蓋專案內全部彈出情境,或是否存在不透過 `SceneTree.paused` 實作的非阻斷式彈窗」。答案在 GDD 自己的 AC-60 裡就已經是「存在」——該 AC 明文以「**不會使 `SceneTree.paused` 為真**的非登記表面(非模態設定側欄、成就吐司通知)」為測試情境。既然文件內部已經確立這類表面存在,把讓路機制建立在 `SceneTree.paused` 上就是建立在一個已知不完整的判準上。顯式旗標**不需要**回答那個 Open Question(該 OQ 因此從阻擋項降級,見 Verification Required 第 7 項),代價是呼叫方必須記得呼叫——這個代價由機制十的結構化回傳值與 AC-59 的測試涵蓋。

**兩條路徑的正交性**(GDD 第十三輪範圍澄清,本 ADR 必須忠實承載):`_arbitration_suspended` **只**閘控**被動裁定路徑**(機制五的 `_input()` 收集與 `_process()` 裁決),**不閘控**呼叫方透過機制十寫入介面發出的**主動 API 呼叫**。存檔讀取的甲分支(舊表面拆除前標記待重新解析)與丙分支(讀檔取消、返回原畫面前設定新目標)都可能發生在暫停選單仍顯示的轉場期間——這是文件明文要求的正確行為,不是例外。**因此 `set_target()`/`mark_pending_reresolve()` 絕不檢查 `_arbitration_suspended`。**

**失焦整段期間不運算**(GDD 第十輪重寫的觸發點 (c)):`_input()` 在 suspended 時直接 return,累積量因此在失焦全程完全不運算,不存在「失焦期間在背景悄悄逼近或跨過門檻」的可能;復焦當下才 `reset()` 並以復焦當下的滑鼠座標重新播種。

**Steam 疊加層的殘留風險**(Verification Required 第 5 項):若實測證實 Steam 疊加層不觸發 `NOTIFICATION_APPLICATION_FOCUS_IN`,機制九需新增備援偵測路徑(GDD 建議方向:額外監聽 `NOTIFICATION_WM_WINDOW_FOCUS_IN` 或輪詢式偵測)。本 ADR 不預先實作未經驗證的備援路徑——`suspend_arbitration()` 的存在讓 Steam 疊加層在最壞情況下仍可由呼叫方顯式處理。

### 機制十:寫入與讀取介面

```gdscript
# ─── 寫入(2 個方法,對應 GDD Core Rules #2)──────────────────
# 2026-08-19 修訂(N4):新增 REJECTED_REENTRANT,見下方「N4 修法」。
enum SetTargetResult { APPLIED, SURFACE_NOT_REGISTERED, INVALID_SURFACE_TYPE, REJECTED_REENTRANT }
enum MarkResult { APPLIED, STALE_NOT_APPLIED, NO_CURRENT_TARGET, REJECTED_REENTRANT }

# 2026-08-19 修訂新增(N4):狀態變更推播訊號,不帶payload——訂閱方以下方既有查詢方法重新讀取,
# 避免持有可能漂移的複本(比照 get_current_target() 回傳複本、不回傳內部參照的既有紀律)。
signal target_changed()
signal device_authority_changed()

var _mutation_in_progress: bool = false   # N4 重入閘門,見下方「N4 修法」與「R4-4 修法」

# 2026-08-19 第四輪修訂新增(新發現 B):滑鼠座標取值管道。
# F2 把 evaluate() 改收「目前滑鼠座標」,但 CursorState 是 RefCounted、不在場景樹上,
# 上一版全文沒有任何管道讓它取得座標 —— arbitrate 路徑與 handoff 路徑同時懸空。
# 由 CursorStateHost 注入 func(): return get_viewport().get_mouse_position();
# 單元測試直接注入常數 lambda,Validation Criteria #2「可在無場景樹下 new()」因此仍成立。
func _init(
    reclaim: MouseReclaimPolicy,
    registry: CursorSurfaceRegistry,
    mouse_position_provider: Callable
) -> void

# ─── 私有寫入路徑(2026-08-19 第四輪修訂新增,R4-4)────────────
# 唯一實際改寫 _target 的地方。**不檢查 _mutation_in_progress**。
# 統一負責:寫入欄位 → 若目標確實改變則 _reclaim.reset(pos, TARGET_CHANGED)(觸發點 (b))
#           → 發出 target_changed()。
func _write_target_internal(target: CursorTarget) -> void

# TR-cursor-012:雙輸入簽章(目標識別 + 是否由裝置 ui_* action 觸發),不含碰撞箱幾何。
# 有效性旗標自動翻回有效。訊號於狀態完全寫定後才發出(見下方)。
func set_target(target: CursorTarget, from_ui_action: bool) -> SetTargetResult

# TR-cursor-013:競態防呆 —— 傳入的 expected 與當下實際持有的目標不符即回傳
# STALE_NOT_APPLIED,絕不靜默忽略、絕不回傳 void。
func mark_pending_reresolve(expected: CursorTarget) -> MarkResult

# ─── 讀取(2 個查詢,對應 TR-cursor-014)─────────────────────
func is_current_target_valid() -> bool                  # 閘控確認動作
func get_device_authority() -> CursorTypes.Authority     # 閘控滑鼠點擊確認
func get_current_target() -> CursorTarget                # 回傳新配置的複本,見下方
```

**N4 修法(2026-08-19 修訂新增,下游更新機制的正式定案)**:機制六的四/五層 `process_priority` 假設下游系統每影格輪詢 `_process()` 讀取游標狀態,但 GDD 66+ 條驗收標準裡不少要求「狀態一變就要反映」,更自然對應訊號推送而非輪詢。本 ADR 正式決定:**輪詢與訊號並存**——`process_priority` 的優先序仍是下游讀取的**時序保證**(交接在同一影格內完成,見機制六),`target_changed()`/`device_authority_changed()` 是**額外的立即通知**,供不想每幀輪詢的下游系統訂閱,訊號不攜帶資料,一律回頭呼叫既有查詢方法取得目前值。

**重入閘門**:`arbitrate_device_authority()`、`apply_buffered_navigation()`、`set_target()`、`mark_pending_reresolve()`、`handoff_before_unload()` **五個公開入口**皆受 `_mutation_in_progress` 保護——進入時檢查該旗標,若已為真(代表本次呼叫是從本系統剛發出的訊號處理函式內回頭呼叫寫入介面,即重入),**一律回傳 `REJECTED_REENTRANT`,不執行任何狀態變更、不再次發出訊號**,比照 ADR-0001 `settlement_in_progress` 的 reject-on-input 模式。五者進入時皆先設 `_mutation_in_progress = true`,完成全部欄位寫定、且訊號已發出後才設回 `false`。

**兩個回傳 `void` 的入口如何表達拒絕(2026-08-19 第四輪修訂補上,上一版把 `arbitrate_frame() -> void` 與三個有回傳值的方法混列而未區分)**:`arbitrate_device_authority()` 與 `apply_buffered_navigation()` 回傳 `void`,**不可能**回傳 `REJECTED_REENTRANT`。兩者的閘門語意是「偵測到重入即整段 no-op、不寫任何欄位、不發任何訊號」。這**不違反**本 ADR 的「絕不靜默」紀律,理由是它們的呼叫方只有本系統自己的兩個節點(`CursorStateHost` 與 `CursorNavigationApplier`),不是外部呼叫方——沒有一個下游系統會因為讀不到拒絕碼而做出錯誤補救。**但重入若真的發生,代表本系統內部有一條非預期的呼叫路徑**,因此兩者在 no-op 時應遞增一個 `diagnostic_reentrant_rejection_count`(QA-only,比照機制十五慣例),讓它在測試中可見而非完全無痕。三個有回傳值的公開入口(`set_target`/`mark_pending_reresolve`/`handoff_before_unload`)則一律回傳 `REJECTED_REENTRANT`,不變。

**R4-4 修法(2026-08-19 第四輪修訂,高)—— 閘門差點鎖死本系統自己**:第四輪 `godot-specialist` 額外發現,上一版把 `arbitrate_frame()` 列為受閘門保護的四者之一,而機制六說明它內部要「依權威決定是否套用緩衝內的導覽類目標變更」——即內部需要執行一次等同「寫入新目標」的動作。**若該內部動作重用公開的 `set_target()`(最自然的實作),進入時旗標已被自己設為 `true`,內部呼叫會被自己的閘門判為重入而拒絕 → 緩衝內導覽寫入永遠不生效。** 上一版完全沒說明內部寫入走公開方法還是私有路徑。

**修法**:明文區分兩類路徑,不留給實作者猜——

| 路徑 | 成員 | 是否掛閘門 |
|---|---|---|
| **公開入口** | `arbitrate_device_authority()`、`apply_buffered_navigation()`、`set_target()`、`mark_pending_reresolve()`、`handoff_before_unload()` | **是**。進入設旗標、離開清旗標,重入回傳 `REJECTED_REENTRANT` |
| **私有寫入** | `_write_target_internal()`(唯一實際改寫 `_target` 的地方) | **否**。它永遠只被上列公開入口在旗標已為真的狀態下呼叫,再檢查一次必然自我拒絕 |

**紀律**:公開入口**不得**互相呼叫。任何「一個公開入口需要另一個公開入口的行為」的情境,一律把共用邏輯下放到私有方法,由兩個入口各自呼叫——這是 GDScript 無 `try`/`finally` 下唯一能保證「旗標的設與清恰好配對一次」的形狀(同一理由見 ADR-0004 的單一進入/單一釋放每槽重入鎖)。呼叫方若需要在訊號處理函式內串聯狀態變更,應以 `call_deferred()` 延後到下一影格,不得期待同步生效。

> **⚠️ 這裡的 `call_deferred()` 與 R4-6 禁止的 `call_deferred()` 是兩件不同的事,不得混淆(2026-08-19 第四輪修訂明文區辨——兩條規則字面上看起來相反,審查時容易被誤判為矛盾)**:
>
> | | R4-6 **禁止**的用法 | 本段 **建議**的用法 |
> |---|---|---|
> | 情境 | 行為者②的觸發來源在 `_physics_process()`,想用 `call_deferred()` 把改標推進**當幀**的 `_process()` | 下游在本系統訊號的處理函式內被 `REJECTED_REENTRANT` 拒絕,想把寫入重排到**下一影格** |
> | 對沖洗時點的要求 | **必須落在當幀 −50 這個位置** —— 而該時點未經查證,落錯就重開四步定序的洞 | **只要求「不是現在」** —— 落在當幀稍後或次影格都可接受,不承載任何定序保證 |
> | 若時點推測錯誤 | 定序違反,AC-52 失守 | 無後果 |
>
> 一句話:**`call_deferred()` 不可用來滿足定序要求,可用來滿足「別在這個呼叫堆疊裡做」的要求。** 前者押在未查證的排程時點上,後者不押任何東西。**`godot-specialist` 本次驗證確認**:GDScript 訊號預設同步派發於同一呼叫堆疊(`CONNECT_DEFERRED` 會延後至該影格 idle 處理,反而破壞本系統仰賴的同影格保證,不是本案的替代方案);本問題屬單執行緒重入,**正確工具是純布林旗標**,不應比照 ADR-0002 引入 `Mutex`(`Mutex` 針對跨執行緒競爭,是不同的問題模型)。

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
#                                    + 累積位移量重置為 0(第四輪修訂新增,見下方)
#   乙:讀檔成功、新表面掛載後     → set_target(依 Core Rules #6 重新計算的初始目標)
#                                    + 累積位移量重置為 0(第四輪修訂新增,見下方)
#   丙:讀檔取消、返回原畫面前     → set_target(原目標仍有效則直接沿用;僅失效時才依
#                                    Core Rules #6 重新計算,AC-63b。第四輪修訂更正,見下方)
func handoff_before_unload(surface: CursorTypes.SurfaceType) -> MarkResult
```

**`TR-cursor-015` 落差 (a) 修法(2026-08-19 第四輪修訂)—— 甲/乙分支的累積位移量重置**:GDD Core Rules #7 F2-2 明訂「滑鼠奪權累積位移量於甲/乙兩分支皆**重置為 0**,累積起點更新為當下滑鼠座標」,理由是該欄位是「鍵盤/手把持有權威期間,滑鼠正朝奪回權威累積淨位移」這個進行中事件的暫態量——舊表面整批替換(甲)或根本尚無舊表面(乙)之後,原本的累積起點與其所依附的表面一併不再有意義。**上一版機制十一全文對此零字**(第三輪已發現、未編號為 F/N 項,第一次修訂依 9 項清單作業因而漏掉)。

修法:`handoff_before_unload()`(甲)於完成標記後、乙分支的 `set_target()` 於寫入後,各自呼叫

```gdscript
_reclaim.reset(_mouse_position_provider.call(), CursorTypes.ResetTrigger.SURFACE_HANDOFF)
```

**為何新增第五個 `ResetTrigger` 值而不是複用 `TARGET_CHANGED`**:兩者的**來源規則不同**——`TARGET_CHANGED` 是 Core Rules #3 明列的四個觸發點之一,`SURFACE_HANDOFF` 來自 Core Rules #7 F2-2 的另一條獨立義務。複用會讓「Core Rules #3 恰有四個觸發點」這句話在程式碼層變成五個,製造與 GDD 的字面落差;更實際的問題是甲分支**目標並未改變**(只是被標記為待重新解析),用 `TARGET_CHANGED` 溝通會對訂閱 `reset_triggered` 的呈現層說謊。呈現層待遇則與 (a)(b)(c) 完全相同:**收斂,不瞬間歸零**——AC-41b 的瞬間歸零例外只屬於 (d)。

**丙分支不是無條件「重新計算」——`TR-cursor-015` 落差 (b) 修法(2026-08-19 第四輪修訂)**:上一版寫成無條件「依 Core Rules #6 重新計算的新目標」,這是對 GDD 義務的**收窄**,牴觸本 ADR 自己 Ordering Note 的單向修訂約束(本 ADR 的機制變更不得擴大或縮小 GDD 的義務)。GDD AC-63b 的原文是有條件的:「**若原目標在取消後仍然有效(原表面未拆除、該目標所指實體仍存在),得直接以原目標值重新設定,不需要重新計算;僅當原目標已失效時才依 Core Rules #6 計算初始目標。**」

修法:丙分支的介面契約明文承載**兩條路徑**——呼叫方先判定原目標是否仍然有效(此判定屬呼叫方職責:本系統不理解遊戲實體語意,無法知道「該目標所指實體是否仍存在」),有效則以原目標值呼叫 `set_target(原目標, false)`,失效才依 Core Rules #6 重算後呼叫。**本系統的介面對兩條路徑一視同仁**(都是一次 `set_target()`),真正被修正的是本 ADR 先前把呼叫方的選擇權寫死成單一路徑這件事。

**丙分支不是「還原暫停前的目標」**(GDD AC-63b):不論走上述哪一條路徑,呼叫方都必須**主動**重新設定,不得讓游標停留在「待重新解析」狀態返回一個可互動的畫面。這與 AC-59 的「恢復當下裝置權威與游標目標與暫停前完全相同」看似矛盾,實則不然——AC-59 明文排除暫停期間發生的主動 API 呼叫,兩者管轄不同路徑(見機制九的正交性說明)。**本 ADR 的介面必須同時支援兩種行為,不得把任一種寫成唯一路徑。**

**裝置權威不隨目標交接重置**:`set_target()` 只在 `from_ui_action == true` 時連動裝置權威轉移。甲/乙/丙三分支的呼叫皆為系統主動改標,`from_ui_action` 一律傳 `false`——裝置權威維持不變(GDD Core Rules #4:裝置權威與游標目標是正交欄位)。

### 機制十二:全域每裝置待機指示宿主 —— Autoload 持有的 CanvasLayer

**決策**:`CursorStateHost` 持有一層 `CanvasLayer`(高 layer 值,恆在所有畫面內容之上),作為全域每裝置待機指示元件的宿主。

**這解決了 TR-cursor-016**——GDD 記載「戰鬥 HUD 是候選,但支援對話 UI 等非戰鬥畫面情境下這個指示元件如何呈現、由誰擁有,同樣需要答案」,結論是「現有候選擁有者皆為畫面範圍,無一符合」。**問題不在於候選者不夠好,而在於需求本身(存在於每個畫面)排除了任何畫面範圍的擁有者。** 一旦機制一建立了生命週期跨所有畫面的 Autoload,正確的宿主就存在了。

**本 ADR 定案宿主與行為契約,不定案視覺樣式**:具體美術樣式留待 `/art-bible`,比照 GDD 對「待重新解析」視覺的同一分工。ADR 保證的是:該元件存在於每個畫面、由單一擁有者渲染、不需要任何下游系統各自實作。

**未解決的部分**:GDD 的 Open Question 還問「非戰鬥畫面情境下這個指示元件**如何呈現**」——那是 UX/美術問題,本 ADR 不回答,已登記為 `producer`/`ux-designer` 於下游 UI 系統設計時的義務(GDD 已同步至 `systems-index.md` 跨系統義務登記表)。

### 機制十三:原生游標二元隱藏 + 自繪載體承擔連續 alpha

**決策**:
- **原生 OS/引擎滑鼠指標**:僅二元顯示/隱藏,透過 `Input.mouse_mode`(權威為滑鼠時 `MOUSE_MODE_VISIBLE`,否則 `MOUSE_MODE_HIDDEN`,**N3 修訂新增一項例外,見下方機制十三之二**)。
- **奪權漸進回饋的連續透明度**:由機制十二那層 CanvasLayer 上的**自繪替代游標節點**承擔,**2026-08-19 修訂(F3)**:不再直綁 `modulate.a = reclaim_progress()`,改由呈現層平滑器逐幀收斂。

**F3 修法 —— 呈現層平滑器(2026-08-19 修訂,取代原直接綁定)**:

```gdscript
# ─── 自繪替代游標節點(位於機制十二的 CanvasLayer,priority = 50)──
var _presented_alpha: float = 0.0
var _pending_snap: bool = false

func _ready() -> void:
    reclaim.reset_triggered.connect(_on_reset_triggered)   # 見機制八 F3

func _on_reset_triggered(trigger: CursorTypes.ResetTrigger) -> void:
    if trigger == CursorTypes.ResetTrigger.VETOED_SAME_FRAME:   # 觸發點 (d),AC-41b 的唯一例外
        _pending_snap = true

func _process(_delta: float) -> void:
    var target := reclaim.reclaim_progress()
    if _pending_snap:
        _presented_alpha = target        # 觸發點 (d):同影格瞬間歸零,不經收斂(AC-41b)
        _pending_snap = false
    elif target >= _presented_alpha:
        # 2026-08-19 第四輪修訂(R4-3):上升方向**立即同步**,不限速。
        _presented_alpha = target
    else:
        # 只有下降方向(且非觸發點 (d))才收斂限速。
        var max_step := 1.0 / float(max(reclaim_visual_convergence_max_frames, 1))
        _presented_alpha = move_toward(_presented_alpha, target, max_step)
    modulate.a = _presented_alpha
```

**R4-3 修法(2026-08-19 第四輪修訂,高,視同 BLOCKING)—— 上一版的平滑器對上升方向也限速**:GDD Core Rules #3「漸進回饋」的硬性要求原文是「以與移動進度……**成正比**的透明度漸進顯示——0% 進度時完全不可見,**達到門檻的當下透明度達 100%、同時完成權威轉移**」。而「收斂上限」規則的管轄範圍,原文限定在「**這類非玩家滑鼠動作直接造成的重置**」——全段語境都是下降方向(歸零、收斂、不得瞬間跳變)。**GDD 從未對「朝門檻累積」的上升方向設下限速。**

上一版對任何方向套用同一個 `max_step`,而 `reclaim_visual_convergence_max_frames` 依 GDD 必須嚴格大於 0、且配置為 1 即等於單影格瞬間歸零(自我矛盾)→ 實際下限為 2 → `max_step ≤ 0.5`。GDD 初步校準門檻 50–100px,常見滑鼠速度下 2–3 影格即可跨過 → `_presented_alpha` **結構上不可能**在跨過門檻的當下達到 1.0。**這是純數學上必然發生的違規**,不依賴任何未驗證引擎行為。

第四輪 `godot-specialist` 的總結值得原樣保留:F3 修法「解決下降方向說謊的同時,在上升方向重新引入了同一類『呈現值與判定值不同步』的說謊——只是方向相反」。

**這個修法會不會製造下一個 R4-x?** 逐項自問的結果:(i) 上升立即同步會不會讓 (d) 的瞬間歸零失效?不會——`_pending_snap` 分支在最前面,優先於方向判斷;(ii) `target >= _presented_alpha` 用 `>=` 而非 `>`,兩者相等時走哪條分支?走上升分支,賦值為同一個值,無行為差異,但避免相等時進入 `move_toward()` 做無謂運算;(iii) 上升立即同步後,機制十五量測的 `_presented_alpha` 還能驗證「收斂上限」嗎?能——該上限本就只約束下降方向的收斂,量測時應只採計下降區段(**已同步補入機制十五的欄位說明**)。

**理由**:GDD 是兩個值的模型——`reclaim_progress()` 本身必須立即反映全部四個重置觸發點(不因呈現層考量延遲判定),但**呈現層透明度**對觸發點 (a)(b)(c) 不得單影格瞬間歸零,須於 `reclaim_visual_convergence_max_frames` 內收斂,觸發點 (d) 才是唯一允許瞬間歸零的例外(AC-41b)。原版本 `modulate.a` 直綁判定值,對 (a)(b)(c) 必然違反 AC-41 且無法區分是哪個觸發點造成的歸零。`move_toward()` 是 Godot 對「目標值持續變動、非到達即停」情境的正確慣用工具(`godot-specialist` 本次修訂驗證確認,優於每幀重啟的 `Tween`)。**若 `_reclaim` 實例被替換**(例如 Validation Criteria #8 的 `ImmediateMouseReclaimPolicy` 隔離測試),呼叫方須重新對新實例呼叫 `reset_triggered.connect()`——訊號連接不隨物件替換自動轉移。

**理由**:GDD 第五輪 Open Question 指出「原生指標若實際上不支援逐幀連續 alpha 動畫(4.7.1 下未經驗證),需改用下游自繪的替代游標圖形」,並指出此載體選擇會連動影響 AC-31 的驗證方式(`Input.mouse_mode` 斷言可能對自繪方案退化為恆真)與 Core Rules #5 抑制義務的掛載對象。

**本 ADR 直接選擇自繪載體,不等驗證結果**——理由不是悲觀,而是**自繪方案在兩種驗證結果下都成立**,而原生方案只在其中一種下成立。既然機制十二已經因為 TR-cursor-016 建立了那層 CanvasLayer,自繪載體的邊際成本接近零。這讓 Verification Required 第 4 項從阻擋項降為資訊項:若實測證實原生指標支援連續 alpha,本 ADR **不需要**修訂(自繪仍是上位方案)。

**AC-31 的驗證掛載點因此定案**:斷言對象是自繪節點的 `visible`/`modulate.a`,**不是** `Input.mouse_mode`——後者在自繪方案下對漸進回饋確實退化為恆真,GDD 的預判正確。`Input.mouse_mode` 的斷言仍用於驗證原生指標的二元抑制(Core Rules #5),兩者是兩個不同的驗證目標。

### 機制十三之二:未登記表面 hover 時暫時恢復原生指標(2026-08-19 修訂新增,N3)

**問題**(第三輪 `/architecture-review` 引擎專家額外發現):`Input.mouse_mode` 是**全域**設定(整個應用程式視窗),依裝置權威切換;但裝置權威是全域欄位,與玩家當下實際把滑鼠移到哪個表面無關。GDD AC-60 明文允許「未登記表面」(例如非模態設定側欄)使用原生 hover、不受本系統管轄——但手把持權威時原生指標全域隱藏,玩家想用滑鼠點這類側欄時,側欄自己的 hover 樣式仍會畫出來(`mouse_entered`/`mouse_exited` 不依賴游標可見性),玩家卻完全看不到滑鼠指標在哪。這是真實體感落差,原版本未處理也未承認。

**決策**:與機制十三的自繪載體同一節點(CanvasLayer,priority = 50,單一 `_process()` 內完成,避免與其他同層節點的排序未定義問題——`godot-specialist` 本次驗證提醒同層級同優先序節點無 tie-break 保證),新增每影格 hover 檢查:

```gdscript
func _process(_delta: float) -> void:
    # ...(機制十三的呈現層平滑器邏輯,見上方)...
    _reapply_native_cursor_visibility_with_unregistered_surface_exception()

func _reapply_native_cursor_visibility_with_unregistered_surface_exception() -> void:
    if _state.get_device_authority() == CursorTypes.Authority.MOUSE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        return
    var hovered := get_viewport().gui_get_hovered_control()
    if hovered != null and not _registry.is_part_of_registered_surface(hovered):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # AC-60 例外:未登記表面,暫時恢復
    else:
        Input.mouse_mode = Input.MOUSE_MODE_HIDDEN    # Core Rules #5 一般規則
```

`CursorSurfaceRegistry` 新增查詢方法 `is_part_of_registered_surface(node: Node) -> bool`(沿祖先鏈比對已註冊表面節點)。`Viewport.gui_get_hovered_control()` 為既有穩定 API,`godot-specialist` 本次驗證確認回傳 `null` 代表無懸停對象、成本為 O(1) 快取查詢,逐幀呼叫無虞。

**理由**:AC-60 已明文把未登記表面排除在本系統管轄之外——恢復該類表面上的原生指標可見性,是**落實**該排除條款的自然結果,而非違反 Core Rules #5(Core Rules #5 的隱藏義務隱含的管轄範圍是本系統登記制內的表面)。**未查證項**:此互動屬 GDD 兩處設計文件內部張力之一(第三輪 `/architecture-review` 判定,Core Rules #5 全域隱藏 vs. Core Rules #7/AC-60 未登記表面例外此前從未被調和),本 ADR 提出的是一個技術層面自洽的解法,但**不越權替 GDD 做設計裁決**——若 creative-director 或使用者認為此行為不符合 Core Rules #5 的精神(例如認為短暫顯示指標仍會造成「兩種視覺線索同時存在」的觀感混淆),應回頭修訂 GDD 明文裁決,屆時本機制須配合調整或移除。

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
# 2026-08-19 修訂(F4):原版本取樣 MouseReclaimPolicy.reclaim_progress()(判定值,依 GDD
# 必須瞬間歸零),但 reclaim_visual_convergence_max_frames 約束的是「呈現層透明度」——量錯
# 對象,無法驗證這個上限。F3 修法後機制十三的自繪節點有了獨立於判定值的呈現值(_presented_alpha),
# 本欄位改為取樣它。
var diagnostic_reclaim_progress_history: Array[float]   # 取樣自繪節點每幀實際 modulate.a(即 _presented_alpha),非 reclaim_progress()
# 2026-08-19 第四輪修訂(R4-3 連帶):`reclaim_visual_convergence_max_frames` 只約束**下降方向**的
# 收斂(GDD 原文語境全在「非玩家滑鼠動作直接造成的重置」),上升方向已改為立即同步。
# 因此以本序列驗證該上限時,**只採計下降區段**(相鄰兩筆遞減的連續段),不可把上升段一併計入
# —— 否則會把「立即同步」誤判為違反收斂上限。
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
                    │  _process()  → _state.arbitrate_device_authority │
                    │                (步驟一,不碰目標、不清緩衝)      │
                    │  ┌─ 子節點 CursorNavigationApplier  prio = -25 ─┐│
                    │  │ _process() → _host.flush_buffered_navigation()││
                    │  │   → _state.apply_buffered_navigation(步驟三)  ││
                    │  │   → _frame_events.clear()  (最後一個消費者)   ││
                    │  └──────────────────────────────────────────────┘│
                    │  _notification() → FOCUS_IN/OUT (機制九)         │
                    │                                                 │
                    │  ┌───────────────────────────────────────────┐  │
                    │  │ CursorState (RefCounted) ← DI, 可 new()     │  │
                    │  │  _target: CursorTarget  (含 is_valid)      │  │
                    │  │  _device_authority: Authority              │  │
                    │  │  _reclaim: MouseReclaimPolicy ──┐          │  │
                    │  │  _mouse_position_provider: Callable ← 注入 │  │
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
                    │  │      modulate.a = _presented_alpha (呈現層平滑器)  │  │
        │  │        上升立即同步 / 下降收斂 / (d) 瞬間歸零      │  │
                    │  └───────────────────────────────────────────┘  │
                    └───────┬─────────────────────────────┬───────────┘
              寫入 API      │                             │  讀取 API
        set_target()        │                             │  is_current_target_valid()
        mark_pending_...()  │                             │  get_device_authority()
        (不受 suspended 限) │                             │  get_current_target() → 複本
                            ▼                             ▼
        ┌───────────────────────────────┐   ┌────────────────────────────────┐
        │ 已註冊表面 (priority = 0) ④    │   │ 下游讀取方 (priority = 100) ⑥   │
        │  focus_mode = FOCUS_NONE ⚠️    │   │  戰鬥 HUD (#10)                │
        │  棋盤格 / 迷你地圖節點 /       │   │  好感度視覺呈現 UI (#9)         │
        │  卡牌槽位 / 對話選項           │   │  支援對話 UI (#11)              │
        │  單標籤單實例 (機制三)         │   │  讀游標目標更新自己的呈現;      │
        │                                │   │  ⚠️確認動作判讀須在此(F1)      │
        └───────────────────────────────┘   └────────────────────────────────┘

        ┌───────────────────────────────────────────────────────────────────┐
        │ ② 呼叫方主動改標 (priority = -50) —— 例如戰棋系統偵測單位死亡          │
        │  於自己的 _process() 呼叫 mark_pending_reresolve()/set_target()      │
        │  ⚠️ 觸發來源若為 _physics_process():只准設旗標於自己 _process() 開頭執行 │
        │     (R4-6:call_deferred() 路線已刪除,沖洗時點未查證)                 │
        │  ⚠️ 同時身兼 ⑥ 的系統必須拆兩個節點 —— ② 與 ⑥ 之間隔著 ③④,          │
        │     單節點陳述順序無法同時滿足兩段定序(R4-7)                          │
        └───────────────────────────────────────────────────────────────────┘

  同幀定序(GDD 四步序列 1→2→3→4,2026-08-19 第四輪修訂 R4-1 逐步對齊):
    ① -100 裝置權威判定 → ② -50 呼叫方主動改標 → ③ -25 緩衝內導覽寫入
      → ④ 0 表面渲染 → ⑤ 50 全域視覺 → ⑥ 100 下游讀取 + 確認判讀
      (④⑤ 為純讀取渲染方,不屬四步序列任何一步)

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
enum ResetTrigger { AUTHORITY_TRANSFER, TARGET_CHANGED, FOCUS_LOST_REGAINED, VETOED_SAME_FRAME, SURFACE_HANDOFF }   # F2/F3;SURFACE_HANDOFF 為第四輪新增(TR-cursor-015 落差 a),來源為 Core Rules #7 而非 #3
const NAVIGATION_ACTIONS / CONFIRM_ACTIONS / ACKNOWLEDGED_OTHER_ACTIONS: Array[StringName]   # 第四輪新增第三份清單(R4-5,機制四之二)
static func encode_tile(coord: Vector2i, board_width: int) -> int
static func decode_tile(id: int, board_width: int) -> Vector2i
static func classify_action(event: InputEvent) -> ActionClass   # 2026-08-19 修訂新增(N1,機制四之二)

# ─── cursor_target.gd ────────────────────────────────────────
class_name CursorTarget extends RefCounted
var surface: CursorTypes.SurfaceType
var id: int
var is_valid: bool
func equals(other: CursorTarget) -> bool
static func make(surface: CursorTypes.SurfaceType, id: int) -> CursorTarget
static func invalidated(from: CursorTarget) -> CursorTarget

# ─── mouse_reclaim_policy.gd(2026-08-19 修訂——F2/F3 簽章改版,見機制八)──
@abstract
class_name MouseReclaimPolicy extends RefCounted
signal reset_triggered(trigger: CursorTypes.ResetTrigger)
@abstract
func evaluate(current_mouse_position: Vector2, surface: CursorTypes.SurfaceType) -> bool:
    pass
@abstract
func reclaim_progress() -> float:
    pass
@abstract
func reset(seed_position: Vector2, trigger: CursorTypes.ResetTrigger) -> void:
    pass
@abstract
func diagnostic_seed_position() -> Vector2:   # 第四輪修訂(R4-2):改標 @abstract,實作下放子類別
    pass

# ─── cursor_state.gd(DI 核心,單元測試直接 new()）────────────
class_name CursorState extends RefCounted
# 第四輪修訂(新發現 B):第三個建構子參數 —— RefCounted 核心取得滑鼠座標的唯一管道
func _init(reclaim: MouseReclaimPolicy, registry: CursorSurfaceRegistry,
           mouse_position_provider: Callable) -> void

signal target_changed()                            # 2026-08-19 修訂新增(N4)
signal device_authority_changed()                  # 2026-08-19 修訂新增(N4)

# ─── 五個公開入口,全數掛 _mutation_in_progress 閘門(N4 + R4-4)──
func arbitrate_device_authority(events: Array[InputEvent]) -> void   # ① -100,GDD 步驟一(第四輪:原 arbitrate_frame 前半)
func apply_buffered_navigation(events: Array[InputEvent]) -> void    # ③ -25,GDD 步驟三(第四輪新增:原 arbitrate_frame 後半)
func set_target(target: CursorTarget, from_ui_action: bool) -> SetTargetResult   # 新增 REJECTED_REENTRANT(N4)
func mark_pending_reresolve(expected: CursorTarget) -> MarkResult               # 新增 REJECTED_REENTRANT(N4)
func handoff_before_unload(surface: CursorTypes.SurfaceType) -> MarkResult      # 第四輪:內部另呼叫 _reclaim.reset(SURFACE_HANDOFF)
# ─── 私有寫入路徑,**不**掛閘門(R4-4)。公開入口不得互相呼叫 ──
# func _write_target_internal(target: CursorTarget) -> void
func is_current_target_valid() -> bool
func get_device_authority() -> CursorTypes.Authority
func get_current_target() -> CursorTarget          # 新配置的複本
func force_redraw_current_authority() -> void      # AC-30
func reapply_native_cursor_visibility() -> void    # Core Rules #5

# ─── cursor_surface_registry.gd ──────────────────────────────
class_name CursorSurfaceRegistry extends RefCounted
func register(surface: CursorTypes.SurfaceType, node: Node) -> RegisterResult
func unregister(surface: CursorTypes.SurfaceType) -> RegisterResult
func get_surface(surface: CursorTypes.SurfaceType) -> Node
func registered_surfaces_sorted() -> Array[CursorTypes.SurfaceType]
func is_part_of_registered_surface(node: Node) -> bool   # 2026-08-19 修訂新增(N3,機制十三之二)

# ─── cursor_state_host.gd(Autoload 薄殼,無裁定邏輯）─────────
class_name CursorStateHost extends Node
# process_priority = -100;於 _ready() 內 add_child(CursorNavigationApplier)(第四輪,R4-1)
func suspend_arbitration() -> void      # 2026-08-19 修訂:內部亦呼叫 _frame_events.clear()(F5)
func resume_arbitration() -> void       # 2026-08-19 修訂:內部亦呼叫 _frame_events.clear() + _reclaim.reset()(F5)
func flush_buffered_navigation() -> void  # 第四輪新增(R4-1):供 -25 子節點呼叫,緩衝區維持私有
# 全部公開 API 為對 _state 的一行轉發,不新增任何判斷邏輯。

# ─── cursor_navigation_applier.gd(第四輪修訂新增,R4-1)───────
class_name CursorNavigationApplier extends Node
# process_priority = -25(必須嚴格介於 ② -50 與 ④ 0 之間)
# _process() 內只有一行:_host.flush_buffered_navigation()
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

- **第二輪 `/architecture-review` 的唯一 FAIL 成因(游標系統 19/19 零涵蓋、Foundation 層)得以關閉。** ⚠️ **2026-08-19 第四輪修訂刪除此處原有的「19 項全部有機制支撐(其中 3 項為部分)」自陳**——它是初版寫下的 16/3 分佈,第三輪已獨立推翻為 11/8、第四輪再重推為 13/6,而 Status 自第一次修訂起即宣告「本 ADR 不自陳涵蓋分佈」。舊句與該宣告直接矛盾,且是同一個「自評膨脹」模式被連續兩輪抓到後仍留在文件裡的第三次。**涵蓋分佈一律以最新一輪獨立 `/architecture-review` 的推導為準,本節不再複述任何數字。**
- **自第四輪起懸而未決的「表面類型 enum 實作位置」定案**(機制二),且沿用已查證的 `AffinityTypes` 先例,不重蹈 ADR-0002 撞過的裸列舉編譯問題。
- **三個 GDD 標記為 `/create-architecture`「建議優先安排」的 Open Question 被降級**:暫停讓路手段(機制九不採 `SceneTree.paused`,不需要回答該 OQ)、原生游標連續 alpha 載體(機制十三選了在兩種驗證結果下都成立的方案)、型別白名單式的設定驗證(機制七的 `has_setting()` 防衛讓未知鍵名在執行期自我暴露)。
- **TR-cursor-016 的擁有權缺口被結構性解決**(機制十二),而非再次轉交給下游。
- **凍結的子機制被隔離在單一檔案**(機制八),未來重啟重新設計不需要動到其他四個機制。
- **對兩項 post-cutoff breaking change 結構性免疫**:4.7 裝置 ID 重新編號(機制四從不讀 `.device`)、4.6 雙焦點(機制十四禁用原生 focus/hover)。
- **`process_priority` 定序讓交接在同一影格內完成**,比 GDD 定案的 ≤1 影格上限更強。
- **2026-08-19 修訂關閉第三輪 `/architecture-review` 判定的兩項 BLOCKING 缺陷**(F1 定序違反 AC-52、F5 兩個確定性程式漏洞)與三項高/中缺陷(F2 介面自相矛盾且邀請被禁止的實作、F3 呈現層平滑器缺失、F4 量測儀器量錯對象),外加引擎專家額外發現的四項(N1 動作語意分類機制缺失、N2 通知時序未定義、N3 未登記表面指標可見性落差、N4 下游更新機制未定案)。修訂連帶關閉了機制一自陳待決的 TR-cursor-001 條件式涵蓋。
- **2026-08-19 第四輪修訂處理第四輪 `/architecture-review` 的 7 項發現 + `TR-cursor-015` 兩項落差 + 3 項本次核對出的新事實**:R4-2 的編譯期錯誤(`@abstract` 基底讀子類別欄位)、R4-1 的定序只關一半(拆出 −25 子節點,四步序列逐步對齊)、R4-3 的平滑器上升方向限速(改為上升立即同步)、R4-4 的重入閘門會鎖死本系統自己的內部導覽寫入(明文區分公開入口與私有寫入路徑)、R4-5 的 `ActionClass` 靜默降級(明文三分割 + 載入期完整性驗證)、R4-6 的 `call_deferred()` 未查證路線(刪除)、R4-7 的多角色節點拆分(部分修正第四輪採納的修法方向)、`TR-cursor-015` 甲/乙分支重置與丙分支條件式沿用、以及 `ResetTrigger` 三個觸發點零呼叫點與 `CursorState` 取不到滑鼠座標兩處懸空。
- **每一項修法都經過「這會不會製造下一個 R4-x」的逐項自問**,答案寫進各機制的修訂標記段落(機制五的 R4-1/F5 連帶中間狀態、機制十三的三點自問、機制十的公開入口互呼禁令)。這是回應第四輪抓到的模式——**修法本身引入新缺陷**(R4-2/R4-3/R4-4 三項皆為第一次修訂新產生)。

### Negative

- **多一層轉發**:`CursorStateHost` 的每個公開 API 都是對 `CursorState` 的一行轉發。這是為可測性付的代價,且必須以紀律維持(禁止把邏輯搬進薄殼)——已列為 forbidden pattern 候選。
- **顯式暫停旗標依賴呼叫方紀律**:機制九不採 `SceneTree.paused`,代價是呼叫方必須記得呼叫 `suspend_arbitration()`。若某個模態 UI 忘了呼叫,暫停期間的背景輸入會被裁定。GDD AC-59 涵蓋此測試,但測試只能驗證已知的呼叫點。
- **棋盤座標須經 int 編碼**(機制三):呼叫方多一次 `encode_tile()`/`decode_tile()`。換得的是 `CursorTarget` 真正的值語意與型別無關的相等判定。
- **凍結子機制相關的需求無法由本 ADR 保證為完整涵蓋**(`TR-cursor-009`/`-011` 為其核心,`-001`/`-015`/`-017` 亦有部分面向依附其上;**確切分佈由獨立審查判定,此處不列數字**):機制八提供了隔離邊界與四方法+一訊號契約,但**門檻數學本身的正確性未被本 ADR 保證**——它承載的是一個帶著兩項已確認缺陷、且重新設計已暫停的子機制。這是刻意的、經使用者裁決的狀態,不是本 ADR 的遺漏。
- **`@abstract` 語法賭注**:機制八的 `MouseReclaimPolicy` 是本專案第二處使用 `@abstract`(ADR-0004 為第一處),沿用同一個未經確認的語法形式。若寫錯是編譯期錯誤,會擋下整個檔案。
- **F1 修法對下游系統新增了架構義務**(2026-08-19 修訂新增):任何解讀確認類 `ui_*` action 的下游系統,現在**必須**在自己的 `_process()` 執行判讀、絕不可掛 `_input()`/`_unhandled_input()`,且若觸發來源是 `_physics_process()` 須自行轉呼叫延後。`process_priority` 無法強制這條規則被遵守(它管不到 `_input()`/`_unhandled_input()`/跨鏈排序)——這條約束的落實完全依賴程式碼審查,已登記為 forbidden pattern 候選(見 Registry 更新提案),但這代表**本 ADR 自身無法提供結構性保證**,是本系統目前唯一一處正確性完全依賴紀律而非引擎機制的地方。
- **N4 的訊號推送新增了重入語意的學習成本**:下游若在 `target_changed()`/`device_authority_changed()` 處理函式內同步呼叫寫入介面,會被 `REJECTED_REENTRANT` 拒絕而非排入佇列——呼叫方須改用 `call_deferred()`,這是一個容易被忽略、直到實測才會發現的行為差異。

- **定序正確性的代價是節點數與呼叫方節點形狀(2026-08-19 第四輪修訂新增,R4-1/R4-7)**:本系統自己多一個 `CursorNavigationApplier` 子節點(可接受,它只有一行轉發);但**②+⑥ 雙角色的下游系統被迫拆成兩個節點**——戰棋系統幾乎必然落在這一類。這是把 GDD「此定序方向本身是硬性行為要求」翻譯到 Godot 節點模型的必然代價,不是本 ADR 的設計偏好。**代價的落點在下游系統的節點結構上,而本 ADR 無法強制它**(同 F1 那條約束,只能靠程式碼審查)。
- **機制七 (c) 的三份清單需要人工維護(2026-08-19 第四輪修訂新增,R4-5)**:每新增一個 `ui_*` action,實作者必須把它歸入三份清單之一,否則載入期驗證失敗。這是**刻意的摩擦**——替代方案(靜默歸為 `OTHER`)正是 R4-5 判定為缺陷的行為。但摩擦是真的,且 `ACKNOWLEDGED_OTHER_ACTIONS` 的初始內容須在實作時依實際 `InputMap` 補齊,本 ADR 給的是參考起點而非完整清單。
- **`CursorState` 建構子多一個參數(2026-08-19 第四輪修訂新增,新發現 B)**:`mouse_position_provider: Callable` 讓核心與場景樹解耦,但也讓「忘了注入」變成一個新的失敗模式(GDScript 無編譯期 null 檢查)。緩解:`_init()` 內對 `mouse_position_provider.is_valid()` 斷言,失敗即立刻爆而非在第一次滑鼠移動時才顯現。

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
| **下游系統在 `_input()`/`_unhandled_input()` 判讀確認動作(2026-08-19 修訂新增,F1)**——`process_priority` 無法強制這條規則,完全依賴紀律 | 登記為 forbidden pattern 候選 `confirm_action_read_in_unhandled_input`,由程式碼審查攔截;違反時的具體症狀(確認讀取先於裁定者完成)已明文記錄於機制六,便於審查者辨識 |
| **`CanvasLayer` 承載自繪游標/待機指示/hover 判定,若帶非恆等變換會使座標計算脫節(2026-08-19 修訂新增,F2/N3)** | `godot-specialist` 標記 **UNVERIFIABLE-FLAG-AS-RISK**,已列 Verification Required 第 11 項為 Day-1 spike。緩解措施是明文約束該 `CanvasLayer` 全程維持恆等變換,不做為長期解法 |
| **`@abstract` 類別內含 `signal` 的語法組合未經確認(2026-08-19 修訂新增,F3)** | 與既有 `@abstract` 語法賭注同一風險等級,已併入 Verification Required 第 12 項與 Day-1 spike 排程 |
| **下游在訊號處理函式內同步呼叫寫入介面被 `REJECTED_REENTRANT` 拒絕而非預期生效(2026-08-19 修訂新增,N4)** | 已於 Consequences → Negative 明文記錄行為差異;`set_target()`/`mark_pending_reresolve()` 的回傳值本就要求呼叫方檢查,`REJECTED_REENTRANT` 沿用既有「絕不靜默」紀律,可在整合測試階段及早發現 |

| **`CursorState` 的公開寫入入口互相呼叫(2026-08-19 第四輪修訂新增,R4-4)**——最誘人的寫法是 `apply_buffered_navigation()` 直接重用公開 `set_target()`,結果會被自己剛設下的 `_mutation_in_progress` 判為重入而拒絕,**緩衝內導覽寫入在正常路徑上靜默失效** | 登記為 forbidden pattern `public_cursor_write_entry_calling_another`,由程式碼審查攔截;Validation Criteria #14 為其自動化下限(斷言 `apply_buffered_navigation()` 後目標確實改變,而非靜默 no-op) |
| **下游以 `call_deferred()` 把改標延後進 `_process()`(2026-08-19 第四輪修訂新增,R4-6)**——沖洗時點相對 `_process` 鏈的位置本 ADR 從未查證,落錯即重開四步定序的洞 | 登記為 forbidden pattern `call_deferred_for_cursor_retarget_deferral`,唯一許可手段是旗標路線。**注意與機制十 N4 建議的 `call_deferred()` 是兩件事**,兩者的區辨見機制十該段的對照表 |
| **雙角色系統(②+⑥)實作在單一節點上(2026-08-19 第四輪修訂新增,R4-7)**——戰棋系統同時是改標呼叫方與確認讀取方幾乎必然,而②與⑥之間隔著③④,單節點不論設哪個優先序都會違反四步序列的一段 | 登記為 forbidden pattern `single_node_for_nonadjacent_cursor_actor_roles`;`process_priority` 無法強制此規則(它管不到「一個系統該用幾個節點」),同 F1 那條約束,落實依賴程式碼審查 |
| **`InputMap.event_is_action()` 印象中不過濾 `InputEventKey.echo`(2026-08-19 第四輪修訂新增)**——按住方向鍵的每一個重複事件都會被判為 `NAVIGATION`,亦即每一影格都在主張裝置權威。直接餵進觸發點 (d) 與 E1 缺陷(類比搖桿持續按住造成永久鎖死)的因果鏈 | Verification Required #13,Day-1 spike。**本 ADR 刻意不預先加 `event.echo` 過濾**:該行為的正確處置與凍結中的奪權子機制耦合(要不要過濾、過濾後觸發點 (d) 還成不成立,須對照 GDD 才知道),現在猜一個實作等於在凍結範圍內偷偷做設計裁決。spike 結果出來後若證實不過濾,須回頭修訂機制四之二**並重新評估是否落入使用者的凍結範圍** |
| **同影格內「步驟一已裁定、步驟三尚未套用」的中間狀態(2026-08-19 第四輪修訂新增,R4-1 連帶)**——`_arbitration_suspended` 若在 −100 與 −25 之間翻為 `true`,該影格的裝置權威已裁定且無法回溯,但導覽寫入不會套用 | 刻意接受並明文記錄(見機制五「R4-1 修法對 F5 的連帶影響」)。理由:裝置權威是全域欄位,其轉移本就不受畫面邊界約束;把權威判定也延後到 −25 會直接重新違反四步序列。已列為 Validation Criteria #10 的新增測試向量 |

## GDD Requirements Addressed

| TR-ID | 需求 | How This ADR Addresses It |
|---|---|---|
| TR-cursor-001 | 全域狀態恰 3 個頂層欄位;擁有節點生命週期須涵蓋所有畫面(Autoload 類機制) | 機制一:`CursorStateHost`(Autoload)為生命週期宿主,`CursorState`(`RefCounted`,DI)持有恰 3 個頂層欄位,有效性旗標為目標欄位內部結構不算第四欄。**2026-08-19 第四輪修訂(R4-2,BLOCKING)**:第一次修訂為關閉本項的條件式涵蓋而新增的 `diagnostic_seed_position()`,**寫在抽象基底卻 `return _seed`,而 `_seed` 只宣告於子類別** —— GDScript 的靜態解析作用域是「本類別 + 祖先鏈」,不往子類別查找,且該方法沒有 `@abstract` 標記(與同檔案其餘三方法不同),會被當作基底自身的完整方法編譯 → **編譯期錯誤**。已改標 `@abstract`、實作下放子類別。**這是純靜態閱讀即可 100% 確認的邏輯錯誤,不依賴任何引擎行為驗證** |
| TR-cursor-002 | 「表面類型」須為單一集中定義的共用 enum;實作位置與擁有者未定案 | 機制二:定案於 `cursor_types.gd`,包裝於 `class_name CursorTypes`(沿用 ADR-0002 `AffinityTypes` 已查證先例——裸列舉跨檔無法編譯) |
| TR-cursor-003 | 同一標籤任一時刻至多一個掛載實例;需要註冊/發現機制 | 機制三:`CursorSurfaceRegistry.register()` 對已占用標籤回傳 `DUPLICATE_TAG_REJECTED`,不覆寫;迭代一律經 `registered_surfaces_sorted()` |
| TR-cursor-004 | 裝置分類須依 `InputEvent` 子類別,絕不可讀 `.device`/裝置 ID | 機制四:`classify()` 只做子類別 match,結構性不觸及 `.device`;`-1` sentinel 列為下游警告項 |
| TR-cursor-005 | Input Map 約束:`ui_*` action 不得綁定滑鼠(除非語意為懸停/游標移動);須載入時驗證 | 機制七 (a):`CursorStartupValidator` 遍歷 `InputMap.get_actions()`/`action_get_events()`(已由 GDD 第十輪覆核為穩定 API);執行期重新綁定明文排除 |
| TR-cursor-006 | 須緩衝整幀 `InputEvent` 並收集完成後才裁決;須掛 `_input()`,絕不可 `_unhandled_input()` | 機制五:`_input()` 只 append 不裁定;`_process()` 階段統一消化——**2026-08-19 第四輪修訂(R4-1)**拆為兩次呼叫(`arbitrate_device_authority()` 於 −100、`apply_buffered_navigation()` 於 −25 的子節點),緩衝區的清空責任隨之移交給後者。「收集完成後才裁決」的前提不受影響:兩次呼叫都在同一影格的 `_process` 階段,都在全部 `_input()` 之後。`_unhandled_input()` 的遺漏風險(被 `accept_event()` 消費的事件永不抵達緩衝區)明文記錄為拒絕理由 |
| TR-cursor-007 | 專案層級 Agile Event Flushing 必須保持關閉 | 機制七 (b):載入期驗證 + `has_setting()` 防衛(鍵不存在回報 UNKNOWN,不視為通過) |
| TR-cursor-008 | 四行為者的決定性同幀執行順序;需要具體 `process_priority` 數值 | **2026-08-19 第四輪修訂(R4-1,承第一次修訂的 F1)**:機制六為**六**行為者——① 裝置權威判定 −100、② 呼叫方主動改標 −50、**③ 緩衝內導覽寫入 −25(第四輪新增的專屬子節點 `CursorNavigationApplier`)**、④ 已註冊表面 0、⑤ 全域視覺層 50、⑥ 下游讀取方 100(含確認動作判讀)。**定序因此為 ①→②→③→⑥,即 GDD 明文的 1→2→3→4 逐步對齊。** 第一次修訂只補了②與⑥的約束,步驟三仍與步驟一融在 −100(實際 1&3→2→4,與 GDD 相反),第四輪判定為只關一半;本次拆節點關閉。另補:R4-7 多角色拆節點規則(②+⑥ 雙角色必須兩個節點)、R4-6 刪除未查證的 `call_deferred()` 路線、R4-4 明文區分公開入口與私有寫入路徑(否則閘門會鎖死③自己)。`process_priority` 不跨 `_process`/`_physics_process` 兩鏈的前提維持記錄 |
| TR-cursor-009 | 滑鼠奪權門檻數學:逐表面類型像素常數、淨位移非路徑總和、根視窗座標空間 | **⚠️ 部分,子機制重新設計仍由使用者裁決暫停**——**2026-08-19 修訂(F2)**:`evaluate()` 簽章改收目前滑鼠座標而非位移量,策略內部持有 `_seed` 自行計算淨位移,結構性杜絕 GDD 明文禁止的路徑總和實作(原簽章的參數命名邀請此錯誤);根視窗座標空間假設已明文寫入 Constraints,並列為 Verification Required 第 11 項(`CanvasLayer` 恆等變換) |
| TR-cursor-010 | 累積器須依裝置權威 + OS 焦點閘控;須掛 `NOTIFICATION_APPLICATION_FOCUS_*`;暫停/彈窗讓出機制留待架構階段 | **2026-08-19 修訂(F5,BLOCKING)**:機制九補上 `_process()` 對 `_arbitration_suspended` 的檢查,且 suspend/resume/FOCUS_OUT/FOCUS_IN 四個進出點全數呼叫 `_frame_events.clear()`——原版本兩個確定性漏洞(競窗 100% 存在、緩衝殘留)已修正。累積器本身的閘控 ⚠️ 仍隨機制八部分(子機制凍結) |
| TR-cursor-011 | **已知確認、尚未修復的永久鎖死缺陷(持續按住方向輸入)**;已降級為建議項但架構層面仍未解決 | **⚠️ 部分,且刻意如此** —— 機制八把缺陷隔離在單一檔案,**明文不宣稱已緩解**。使用者第十二輪裁決:重新設計暫停、候選修法停止投入、待手把硬體 |
| TR-cursor-012 | 寫入介面「設定新目標」:雙輸入簽章,不含碰撞箱幾何,自動清除有效性旗標 | 機制十:`set_target(target, from_ui_action) -> SetTargetResult`;幾何查詢自 GDD 第九輪門檻改錨定表面類型常數後已完全不存在 |
| TR-cursor-013 | 寫入介面「標記待重新解析」:須回傳結構化的已套用/已過期結果,絕不靜默 | 機制十:`mark_pending_reresolve(expected) -> MarkResult`,`STALE_NOT_APPLIED` 為明確回傳值;競態判定依賴機制三的 `CursorTarget.equals()` 值語意 |
| TR-cursor-014 | 讀取介面:有效性旗標查詢 + 裝置權威查詢,兩者拒絕回饋須可區分 | 機制十:刻意分為**兩個獨立查詢**而非一個合併布林 —— 兩種拒絕的正確補救動作相反(等待重新解析 vs 移動滑鼠取回權威),合併會讓呼叫方結構上無法產生可區分回饋 |
| TR-cursor-015 | 卸載前目標交接義務,涵蓋存檔讀取整批替換的甲/乙/丙分支 | 機制十一:`handoff_before_unload()` + 三分支呼叫慣例;三分支 `from_ui_action` 一律 `false`,裝置權威不隨交接重置。**2026-08-19 第四輪修訂關閉第三輪的兩項未編號落差**(第一次修訂依 9 項清單作業因而漏掉):**(a)** 甲/乙兩分支皆須把滑鼠奪權累積位移量**重置為 0**、起點更新為當下滑鼠座標(GDD Core Rules #7 F2-2 明訂,上一版全文零字)——新增第五個 `ResetTrigger` 值 `SURFACE_HANDOFF`(來源為 Core Rules #7 而非 #3 的四點,呈現層待遇同 (a)(b)(c) 收斂、非瞬間歸零);**(b)** 丙分支上一版寫成無條件「依 Core Rules #6 重新計算」,**收窄了 GDD 義務**(AC-63b 原文為「若原目標在取消後仍然有效,得直接以原目標值重新設定,不需要重新計算;僅當原目標已失效時才依 Core Rules #6 計算」),牴觸本 ADR 自己 Ordering Note 的單向修訂約束——已改為兩條路徑並存,有效性判定歸呼叫方(本系統不理解遊戲實體語意) |
| TR-cursor-016 | **全域每裝置待機指示元件須存在於每個畫面**;現有候選擁有者皆為畫面範圍,無一符合 | 機制十二:`CursorStateHost` 持有的全域 `CanvasLayer` 為宿主。**缺口成因是需求本身排除了畫面範圍擁有者**,機制一建立的 Autoload 是本專案第一個跨所有畫面的實體。視覺樣式仍留 `/art-bible` |
| TR-cursor-017 | 原生游標須在權威≠滑鼠時隱藏,唯一例外是連續漸變的奪權回饋 —— **連續透明度動畫在 4.7.1 可能不受原生游標支援** | **2026-08-19 修訂(F3/F4/N3)**:機制十三原版本 `modulate.a` 直綁判定值,對觸發點 (a)(b)(c) 必然違反 AC-41——已改為呈現層平滑器(`_presented_alpha` 逐幀 `move_toward()` 收斂,僅觸發點 (d) 瞬間歸零),由新增的 `reset_triggered` 訊號驅動;機制十五的收斂上限診斷欄位同步改為取樣呈現值而非判定值(F4)。另新增機制十三之二:未登記表面 hover 時暫時恢復原生指標(N3),處理 `Input.mouse_mode` 全域性與 AC-60 未登記表面例外的落差。AC-31 驗證掛載點仍為自繪節點的 `modulate.a`。**2026-08-19 第四輪修訂(R4-3)**:上一版的平滑器對**上升方向也限速**,而 `reclaim_visual_convergence_max_frames` 的實際下限為 2(配置為 1 即等於單影格瞬間歸零,自我矛盾)→ `max_step ≤ 0.5`,常見滑鼠速度下 2–3 影格即跨過門檻 → `_presented_alpha` **結構上不可能**在跨門檻當下達到 1.0,純數學上必然違反 GDD「達到門檻的當下透明度達 100%」。已改為**上升立即同步、只對下降方向(且非觸發點 (d))限速**;機制十五的量測隨之明文只採計下降區段 |
| TR-cursor-018 | 全鍵盤/手把平權;已註冊表面不得使用原生 Control 焦點/懸停主題(4.6 雙焦點分離) | 機制十四(2026-08-18 Step 5.5 後修訂為**兩項**條件):`focus_mode = FOCUS_NONE`(關鍵盤/手把焦點通道)**加上**根 Control 不得帶內建 hover 主題 / 須清空 hover-focus StyleBox(關滑鼠 hover 管線)——`focus_mode` 單獨**不足以**涵蓋此需求,兩者是獨立管線。高亮只讀 `CursorState`。**未註冊表面仍可用原生 focus**(GDD AC-60 明文承認),且其上的方向鍵導覽仍會轉移裝置權威 —— 這是正確行為,裝置權威是全域的 |
| TR-cursor-019 | 交接視覺延遲硬性上限(最多 1 幀)與奪權收斂上限,皆需幀精準量測機制 | 機制十五:`diagnostic_last_authority_change_frame` 等三個 QA-only 診斷欄位;機制六的定序讓交接在**同一影格**完成,量測應驗證這個更強保證。**2026-08-19 修訂(F4)**:`diagnostic_reclaim_progress_history` 原量測判定值(量錯對象),已改為量測機制十三呈現層的實際 `modulate.a` |

**涵蓋結論(2026-08-19 第四輪修訂後,待獨立 `/architecture-review` 驗證)**:

| 輪次 | 涵蓋分佈(19 項 `TR-cursor-*`) | 來源 |
|---|---|---|
| 初版自陳 | 16 完整 / 3 部分 | 本 ADR 自評 —— **第三輪推翻** |
| 第三輪獨立重推 | **11 完整 / 8 部分 / 0 缺口** | `architecture-review-2026-08-19.md` |
| 第四輪獨立重推(第一次修訂後) | **13 完整 / 6 部分 / 0 缺口** | `architecture-review-2026-08-19-round4.md` |
| 第二次修訂後 | **本 ADR 不自陳** | 待第五輪 |

**本 ADR 同樣不自陳本次修訂後的涵蓋分佈**——涵蓋判定必須由獨立、全新 session 的 `/architecture-review` 重新推導,而非由撰寫/修訂本 ADR 的同一 session 自評。上表保留三輪的實際數字,是為了讓「自評與獨立推導之間有多大落差」這件事本身留在文件裡:第二輪在 ADR-0004 身上抓到一次、第三輪在本 ADR 身上抓到第二次(16/3 → 11/8)。**第四輪抓到的是不同的模式——修法本身引入新缺陷**(R4-2/R4-3/R4-4 三項皆為第一次修訂新產生,不存在於初版)。本次修訂對此的回應寫在 Consequences → Positive 最後一項。

**第四輪 7 項發現 + `TR-cursor-015` 兩項落差的處置**:R4-1(機制六拆節點)、R4-2(機制八 `@abstract`)、R4-3(機制十三上升立即同步)、R4-4(機制十公開/私有寫入路徑)、R4-5(機制四之二三分割 + 機制七 (c))、R4-6(機制六刪 `call_deferred()`)、R4-7(機制六多角色拆節點,**部分修正第四輪採納的修法方向**)、`-015`(a)(機制十一 `SURFACE_HANDOFF`)、`-015`(b)(機制十一丙分支條件式沿用)——**九項全部處理**,各自見上方對應 TR-ID 列與機制內的「第四輪修訂」標記段落。另處理本次核對出的三項新事實(見 Status)。

## Performance Implications

- **CPU**:`_input()` 每事件僅一次 `Array.append`,O(1)。`arbitrate_device_authority()` 與 `apply_buffered_navigation()`(2026-08-19 第四輪修訂拆分,兩者各自)對該影格事件數線性,而一影格內的輸入事件數是個位數量級(滑鼠移動事件最密,約每影格 1–2 個)。`classify()` 為常數次 `is` 判定,**2026-08-19 修訂新增**`classify_action()` 為常數次 `InputMap.event_is_action()` 查詢(N1)。`MouseReclaimPolicy.evaluate()` 為一次 `Vector2` 距離計算 + 一次表面類型查表,O(1)。**2026-08-19 修訂新增**:機制十三的呈現層平滑器每影格一次 `move_toward()`(F3);機制十三之二每影格一次 `gui_get_hovered_control()` O(1) 快取查詢(N3)。**全部落在每影格路徑,但總量遠低於 16.6ms 預算的任何可觀比例。**
- **Memory**:`_frame_events` 每影格清空,峰值與單影格事件數成正比。`CursorSurfaceRegistry` 上界為 `SurfaceType` 成員數(目前 4)。`diagnostic_reclaim_progress_history` 為診斷用,須有上界(建議環形緩衝,具體大小留實作)。
- **Load Time**:`CursorStartupValidator.validate()` 遍歷全部 `ui_*` action 一次,發生於啟動,非每幀路徑。
- **Draw Calls**:機制十二/十三的全域 CanvasLayer 新增至多 2 個繪製元素(待機指示、自繪游標),對 `<1000` 的專案預算(`technical-preferences.md`)無實質影響。
- **Network**:不適用(單人遊戲;`networking_features` 為專案級 forbidden pattern)。

**明確未定案**:各表面類型的 `reclaim_threshold_px` 具體值(GDD 初步校準數據:單一合成測試表面約 50–100px 手感自然,**非最終值,亦未依表面類型分別測試**,待垂直切片階段各表面分別校準);`reclaim_visual_convergence_max_frames` 具體值(僅約束嚴格大於 0)。

## Migration Plan

不適用 —— 本專案 `src/` 目前為空,尚無任何實作程式碼,處於設計階段。本 ADR 為前瞻性決策,不涉及既有程式碼遷移。

## Validation Criteria

1. **GDD Acceptance Criteria 章節 A~L 全部分類的向量通過** —— 這是本 ADR 機制是否真的支撐 GDD 義務的直接證據。特別關鍵:AC-2(恆一高亮不變式,含未初始化狀態)、AC-12(交接延遲 ≤1 影格)、AC-15/16(未初始化狀態與設定初始目標的正交性)、AC-20(同幀雙裝置固定優先序)、**AC-52(2026-08-19 修訂新增——GDD 四步完整定序,原版本此清單漏列,正是第三輪 F1 判定 BLOCKING 的理由之一)**、AC-59(暫停期間不裁定,且**排除**主動 API 路徑)、AC-60(登記制排除,且**不**斷言裝置權威)、AC-61/63a/63b(甲/乙/丙三分支)、AC-41/41b(2026-08-19 修訂新增——F3 呈現層收斂與觸發點 (d) 瞬間歸零例外)。
2. **`CursorState` 可在無場景樹的情況下 `new()` 並完整測試** —— 這是機制一分離設計的存在理由。若任何 AC 的測試需要一個活著的場景樹或需要清理全域狀態,機制一的分離就失敗了,應回頭檢查是否有邏輯洩漏進 `CursorStateHost`。
3. **`_unhandled_input()` 的反向驗證**:刻意構造一個聚焦中的 Control 消費 `ui_up`,驗證掛 `_input()` 的緩衝區**仍然收到**該事件。這直接驗證機制五拒絕 `_unhandled_input()` 的理由成立,而非只是相信文件。
4. **同幀仲裁的決定性測試**:同一組事件以不同順序餵入 `arbitrate_device_authority()` + `apply_buffered_navigation()`(兩者依序,模擬 −100 與 −25 兩個節點),驗證結果完全相同(固定優先序不依賴輸入順序)。這是 GDD「100% 決定性測試」宣稱的直接兌現。
5. **`process_priority` 定序的幀精準驗證**:斷言裁定者的欄位更新與讀取方的讀取發生在同一影格,且前者先於後者(以 `Engine.get_process_frames()` 為時基)。
6. **`CursorStartupValidator` 的三種失敗案例各自測試**,包含 `AGILE_FLUSHING_SETTING_KEY_UNKNOWN` —— 刻意以錯誤鍵名建構,驗證回報 UNKNOWN 而非靜默通過。
7. **`mark_pending_reresolve()` 的競態測試**:傳入與當下不符的 `expected`,驗證回傳 `STALE_NOT_APPLIED` 且當下合法目標未被誤標記。
8. **`MouseReclaimPolicy` 替換測試**:以 `ImmediateMouseReclaimPolicy` 替換後,機制六/九/十/十三的全部測試仍通過 —— 驗證機制八的隔離邊界(**措辭經兩次修訂**:初版「只有三個方法寬」→ 第一次修訂「三個方法 + 一個訊號」→ **第四輪修訂:四個 `@abstract` 方法 + 一個訊號**,因 R4-2 把 `diagnostic_seed_position()` 改標 `@abstract`,它現在計入抽象契約寬度。見機制八「契約寬度的誠實記錄」)。**替換測試須連 `diagnostic_seed_position()` 一併實作**——`ImmediateMouseReclaimPolicy` 無「門檻累積」概念,但仍須回傳它收到的 `reset()` 座標,否則整個檔案不編譯。**新增檢查項**:替換後,呈現層是否已重新對新實例呼叫 `reset_triggered.connect()`——若忘記重連,漸退收斂測試會靜默失敗(讀到舊實例的訊號,或完全收不到)。
9. **四步序列定序測試(2026-08-19 兩次修訂,BLOCKING 修法的直接驗證)**:
   - **9a(第一次修訂,F1)**:構造「呼叫方主動改標(−50)」與「下游確認讀取(100)」同影格皆觸發的情境,斷言確認讀取讀到的是改標**之後**的狀態,而非改標前的舊值——驗證 ②→⑥(GDD 步驟 2→4)。
   - **9b(2026-08-19 第四輪修訂新增,R4-1 —— 第四輪明文指出「②→③ 這組沒有任何測試涵蓋」)**:構造「呼叫方主動改標 `set_target(A)`(−50)」與「緩衝內導覽寫入 `ui_right`(−25)」同影格並存的情境,斷言該影格結束時的目標是**導覽寫入在 A 的基礎上計算出的結果**,而非 A 本身——即③勝出、且是在②的基礎上勝出。這是 R4-1 修法的**唯一**直接證據:上一版的融合排序下,此測試會讀到 A(②覆寫①),必然失敗。
   - **9c(第四輪修訂新增,R4-1)**:節點優先序的靜態斷言——`CursorStateHost.process_priority == -100`、`CursorNavigationApplier.process_priority == -25`,且後者是前者的子節點。AC-52 明訂驗證方式「以程式碼審查為主——確認實作的節點執行順序符合四步序列」,本項是該審查的自動化下限。
   - **9d(第一次修訂)**:構造一個下游系統故意在自己的 `_unhandled_input()` 判讀確認動作的反例,驗證此為 forbidden pattern 審查應攔截的情況(此測試驗證的是規則本身合理,不是驗證引擎會自動阻止——引擎不會)。
10. **F5 暫停/復焦緩衝清空測試(2026-08-19 修訂新增)**:構造「`_input()` 已 append 事件之後、同影格內 `_arbitration_suspended` 才變 true」的時序,斷言 `_process()` 不裁定該批事件;另構造暫停期間累積殘留事件、復焦後驗證 `_frame_events` 為空、不與復焦當下新事件混合處理。**2026-08-19 第四輪修訂新增第三個向量(R4-1 連帶)**:構造「−100 已完成裝置權威裁定、−25 尚未執行、期間 `_arbitration_suspended` 翻為 `true`」的中間狀態,斷言(i) 裝置權威**已**被裁定(該影格不回溯)、(ii) 導覽寫入**未**套用、(iii) `_frame_events` 已被 `suspend_arbitration()` 清空,`flush_buffered_navigation()` 進入時直接 return。這是拆節點修法製造的新中間狀態,見機制五「R4-1 修法對 F5 的連帶影響」。
11. **N4 重入測試(2026-08-19 修訂新增)**:在 `target_changed()`/`device_authority_changed()` 的處理函式內同步呼叫 `set_target()`,斷言回傳 `REJECTED_REENTRANT`、狀態未被變更、訊號未被重複發出。
13. **R4-3 上升方向測試(2026-08-19 第四輪修訂新增)**:餵入單調遞增的 `reclaim_progress()` 序列直到跨過門檻,斷言**跨過門檻的當影格** `_presented_alpha == 1.0`(不是「N 影格後才到 1.0」)。這是 GDD「達到門檻的當下透明度達 100%」的直接兌現,也是上一版平滑器**結構上不可能通過**的那一項。另餵入下降序列,斷言收斂步數不超過 `reclaim_visual_convergence_max_frames`,且觸發點 (d) 的歸零為單影格完成。
14. **R4-4 內部寫入不被自己的閘門拒絕(2026-08-19 第四輪修訂新增)**:呼叫 `apply_buffered_navigation()` 使其內部執行目標寫入,斷言目標**確實改變**(不是靜默 no-op)。上一版若把內部寫入實作為呼叫公開 `set_target()`,此測試會失敗——這是 R4-4 的直接證據。另斷言五個公開入口彼此不互相呼叫(以呼叫圖靜態檢查或程式碼審查為之)。
15. **R4-5 分類完整性測試(2026-08-19 第四輪修訂新增)**:於 `InputMap` 注入一個不在三份清單任一份中的 `ui_*` action,斷言 `CursorStartupValidator.validate()` 回報 `UI_ACTION_UNCLASSIFIED` **並附帶該 action 名稱**,而非靜默通過。
16. **`TR-cursor-015` 三分支測試(2026-08-19 第四輪修訂新增)**:甲/乙分支各自斷言累積位移量已重置為 0、起點已更新為當下滑鼠座標、且 `reset_triggered` 帶的是 `SURFACE_HANDOFF`(不是 `TARGET_CHANGED`);丙分支**兩條路徑各測一次**——原目標仍有效時斷言可直接以原目標值重新設定(不強制重算),原目標已失效時斷言走 Core Rules #6 重算路徑。
17. **後續 `/architecture-review`**(須於**全新 session** 執行)判定本 ADR 與 ADR-0001~0004 無衝突,且對 19 項 `TR-cursor-*` 的涵蓋由獨立審查重新推導——本 ADR 不預先自陳修訂後的涵蓋分佈(見 GDD Requirements Addressed 涵蓋結論)。

**反向驗證(本 ADR 若錯了會如何顯現)**:若機制一的分離不徹底(邏輯洩漏進 Autoload 薄殼),會表現為某些 AC 的單元測試開始需要 `add_child()` 或全域狀態清理 —— 驗證條件 2 會直接攔截。若機制六的 `_process` 定序前提不成立(`_input()` 未在 `_process()` 前全數完成),會表現為同幀仲裁結果隨事件抵達時序漂移 —— 驗證條件 4 會攔截,但**只在多次執行下才會顯現**,因此該測試須重複執行而非單次通過即算過。若機制十三的自繪載體未正確讀取 `reclaim_progress()`,會表現為漸進回饋視覺與判定值脫節(玩家看到指標淡入但奪權未發生,或反之)—— 這是 GDD Player Fantasy 明訂要消除的「探測性輸入後仍不確定」失敗情境本身。

## Related Decisions

- `design/gdd/cursor-highlight-state.md` —— 本 ADR 服務的全部義務之權威定義處(2026-08-13 第十六輪 Approved),本 ADR 只定案機制。該文件的 `Known Confirmed Defects` 節與 Open Questions 表是本 ADR 機制八/九/十三的直接輸入。
- `docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md` —— 機制二的 `CursorTypes` 包裝沿用其 `AffinityTypes` 先例(裸列舉跨檔無法編譯,該 ADR 的 BLOCKING 級修正);機制三的值型別鍵與顯式 `equals()` 沿用其 `mutable_container_as_dictionary_key` 登記立場;機制十五的診斷欄位沿用其 QA-only 標記慣例。**本 ADR 需要說明為何機制一不違反該 ADR 登記的 `autoload_singleton_for_testable_data_layers`**(見機制一)。
- `docs/architecture/adr-0004-save-system-atomic-write-and-migration-execution-model.md` —— 機制八的可替換策略邊界採其 `SaveIOBackend` 的同一手法(在缺乏驗證依據時把未解決問題的影響面縮到一個檔案);共用其 `@abstract` 語法的未驗證風險(Verification Required 6/6a)。機制十一的甲/乙/丙分支與該 ADR 的存檔讀取路徑交接。**2026-08-19 第四輪修訂澄清(C6,第三輪提出、第四輪重申)**:上一版寫「直接交接」,但 ADR-0002/0003/0004 全文對「游標」/「cursor」/「ADR-0005」**實測零命中**——這不是矛盾,而是**義務歸屬**的正確結果:GDD Core Rules #7 把交接義務歸給**呼叫方**(戰棋系統),不歸給存檔系統,兩份 ADR 皆宣稱不理解遊戲實體語意。因此正確的描述是:**機制十一的三分支由呼叫方在 ADR-0004 定義的讀檔生命週期節點上呼叫本系統介面,ADR-0004 本身不呼叫、也不需要知道本系統存在。** ADR-0004 已於同日修訂補上回指本 ADR 的 `Related Decisions` 條目並說明此歸屬,避免它在「被單方面宣稱交接」的狀態下逕行 `Accepted`。
- `docs/architecture/adr-0001-tactical-query-atomicity-contract.md` —— 機制三的迭代順序紀律沿用其 `relying_on_container_iteration_order`;機制十的回傳複本沿用其 `returning_internal_container_references`。
- `docs/architecture/architecture-review-2026-08-18-round2.md` —— 記錄本系統為第二輪審查 **FAIL 判定的唯一成因**(19/19 零涵蓋,Foundation 層),並把本 ADR 列為第一優先建議。
- `prototypes/cursor-reclaim-godot-spike-2026-08-05/` —— 機制八所承載缺陷的 E1 級證據來源;亦是 Control offset transforms 命中測試風險關閉的依據。
- `docs/registry/architecture.yaml` —— 本 ADR 完成後將登記的新增立場(見 Registry 更新提案)。
