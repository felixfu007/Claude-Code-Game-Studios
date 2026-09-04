# Epic:單一游標/高亮狀態系統

> **層**:Core(依 `design/gdd/systems-index.md` 第 3 列)
> **GDD**:`design/gdd/cursor-highlight-state.md`(2026-08-13 第十六輪 **Approved**)
> **架構模組**:ADR-0005 定案的六類別模組(見下方「架構模組」節)
> **控制清單版本**:2026-09-02
> **狀態**:Ready
> **Stories**:14 張(見下方 Stories 節)
> **建立日期**:2026-09-02

## Overview

本 epic 實作全專案唯一的游標/高亮狀態權威。它擁有恰 3 個頂層狀態欄位(當前目標、
裝置權威、滑鼠奪權進度),並對外提供寫入與讀取介面;所有畫面(棋盤格、對話卡牌、
選單、好感度關係圖)的高亮一律只讀本系統的狀態,**不得**各自維護一份。

它同時是裝置權威(鍵盤/滑鼠/手把當前由誰主導)的唯一裁決者,並負責在權威不是滑鼠時
隱藏原生游標、由自繪載體承擔連續透明度回饋。

**這是四個已核准系統中第一個真正解鎖的** —— 其餘三個各自另有阻擋。

## 架構模組

`docs/architecture/architecture.md` **不存在**(`/create-architecture` 從未執行)。
ADR-0005 實質承擔該角色:它有完整的模組圖(Architecture Diagram)與介面契約
(Key Interfaces)。**本 epic 以 ADR-0005 為模組定義的權威來源。**

| 類別 | 角色 | 生命週期 |
|---|---|---|
| `CursorStateHost` | Autoload **薄殼**;持有專屬 `CanvasLayer`;`process_priority = −100` | 全域 |
| `CursorState` | `RefCounted` 核心,依賴注入;持有恰 3 個頂層欄位 | 由宿主持有 |
| `CursorNavigationApplier` | 宿主於 `_ready()` 內 `add_child()` 的專屬子節點;`process_priority = −25` | 全域 |
| `CursorTypes` | 共用列舉的包裝類別(裸列舉跨檔無法編譯) | 靜態 |
| `CursorSurfaceRegistry` | 表面註冊/發現;**兩份獨立登記表**(已註冊表面 + AC-60 例外白名單) | 全域 |
| `MouseReclaimPolicy` | `@abstract` 策略邊界 —— **凍結子機制的隔離牆** | 由 `CursorState` 持有 |

## Governing ADRs

| ADR | 決策摘要 | 引擎風險 |
|---|---|---|
| **ADR-0005** 單一游標/高亮狀態系統:裝置權威輸入架構<br>(2026-09-01 **Accepted**) | Autoload 薄殼 + DI 核心;`_input()` 只緩衝、`_process()` 才裁決;裝置分類依 `InputEvent` **子類別**、結構性不讀 `.device`;六行為者的具體 `process_priority` 定序;已註冊表面禁用原生 Control focus/hover | **HIGH** |

⚠️ **HIGH 的具體成因**:本系統的兩個核心領域(Input、UI)在 4.6 與 4.7 **各有一項直接相關的
破壞性變更** —— 4.7 鍵盤/滑鼠裝置 ID 重新編號、4.6 雙焦點系統。ADR-0005 的機制四與機制十四
正是分別對這兩項的結構性免疫。

🔴 **引擎判斷一律以 `breaking-changes.md` 與 `current-best-practices.md` 為準,不得只查
`modules/input.md` / `modules/ui.md`** —— 那兩份停在 4.6,而且對上述兩項變更**各自零命中**。

## 🔴 兩條隨核准生效的實作硬性義務

1. **游標圖層必須獨佔一顆 `CanvasLayer`**,不得與介面圖層共用。
   實測誤混的偏差:1080p **1440 px** / 2K **2178 px** / 4K **3304 px** —— **游標系統實質失效**。
   **必須寫成一條會執行的自動化測試**(ADR-0005 Validation Criteria #20),不得只靠紀律。
2. **`classify_action()` 必須自行過濾 `InputEventKey.echo`** —— 已實測
   `InputMap.event_is_action()` **不過濾**。不濾的話,玩家**按住**方向鍵會每一影格都被判為
   導覽、亦即每一影格都在主張裝置權威。

## GDD Requirements

**19 項 `TR-cursor-*`,零缺口。** 最近一次獨立重推(第五輪 `/architecture-review`,
2026-08-19,第二次修訂後)為 **15 完整 / 4 部分 / 0 缺口**。

> ⚠️ **ADR-0005 自第三次修訂起刻意不自陳涵蓋分佈**,理由是涵蓋判定必須由獨立的全新 session
> 重新推導 —— 本專案已抓到過兩次「自評與獨立推導落差很大」(其中一次是 16/3 → 11/8)。
> **因此下表的「涵蓋」欄是第五輪的獨立數字,不是最新狀態。** 第六輪之後未再獨立重推。

| TR-ID | 需求 | 涵蓋 |
|---|---|---|
| TR-cursor-001 | 全域狀態恰 3 個已認定的頂層欄位;擁有節點生命週期須涵蓋所有使用本系統的畫面 | ✅ 機制一 |
| TR-cursor-002 | 表面類型標籤須為單一集中定義的共用 enum | ✅ 機制二 |
| TR-cursor-003 | 同一標籤在任一時刻至多一個掛載實例;需要註冊/發現機制 | ✅ 機制三 |
| TR-cursor-004 | 裝置權威分類須依原始 `InputEvent` 子類別,**絕不可讀 `.device`** | ✅ 機制四 |
| TR-cursor-005 | Input Map 約束:除非語意為懸停/游標移動,`ui_*` action 不得綁定滑鼠 | ✅ 機制七 (a) |
| TR-cursor-006 | 須緩衝整幀 `InputEvent` 後才裁決;掛 `_input()`,**絕不可 `_unhandled_input()`** | ✅ 機制五 |
| TR-cursor-007 | 專案層級 Agile Event Flushing 必須保持關閉 | ✅ 機制七 (b) |
| TR-cursor-008 | 行為者的決定性同幀執行順序;需要具體 `process_priority` 數值 | ✅ 機制六(**六**行為者) |
| TR-cursor-009 | 滑鼠奪權門檻數學:逐表面類型像素常數、淨位移非路徑總和 | ⚠️ **部分 —— 凍結** |
| TR-cursor-010 | 累積器須依裝置權威加 OS 焦點閘控;須掛 `NOTIFICATION_APPLICATION_FOCUS_*` | ⚠️ **部分 —— 累積器那半凍結** |
| TR-cursor-011 | 已確認、尚未修復的永久鎖死缺陷(持續按住方向輸入) | ⚠️ **部分 —— 刻意如此** |
| TR-cursor-012 | 寫入介面設定新目標:雙輸入簽章,不含碰撞箱幾何,自動清除有效性旗標 | ✅ 機制十 |
| TR-cursor-013 | 寫入介面標記待重新解析:須回傳結構化結果,**絕不靜默** | ✅ 機制十 |
| TR-cursor-014 | 讀取介面:有效性旗標查詢 + 裝置權威查詢,兩者拒絕回饋須可區分 | ✅ 機制十(**刻意兩個獨立查詢**) |
| TR-cursor-015 | 卸載前目標交接義務,涵蓋存檔讀取整批替換的甲/乙/丙三分支 | ✅ 機制十一 |
| TR-cursor-016 | 🔴 **2026-09-03 管理者裁決取消,需求本身不再存在** —— 原文:全域每裝置待機指示元件須存在於每個畫面 | ❌ 不適用(原:機制十二)。裁決依據見 `production/session-state/active.md` 第三十二批 |
| TR-cursor-017 | 原生游標須在權威非滑鼠時隱藏,例外是連續漸變的奪權回饋 | ⚠️ **部分 —— 回饋那半凍結** |
| TR-cursor-018 | 全鍵盤/手把平權;已註冊表面不得使用原生 Control 焦點/懸停主題 | ✅ 機制十四(**兩項條件**) |
| TR-cursor-019 | 交接視覺延遲硬性上限(最多 1 幀)與奪權收斂上限,皆需幀精準量測 | ✅ 機制十五 |

## 🔴 範圍聲明:那 4 項「部分」是凍結,不是待辦

`TR-cursor-009` / `-010` / `-011` / `-017` 的未盡部分**全部掛在同一個東西上:滑鼠奪權子機制**。

**使用者已於 GDD 第十二輪(2026-08-11)明文裁決**:該子機制的硬性閘門降級為建議事項、
重新設計**暫停**、候選修法**停止投入**,待取得手把硬體。
ADR-0005 因此把它隔離在 `MouseReclaimPolicy` 這道可替換邊界後方,並**明文不宣稱已緩解**。

> **對寫 story 的人**:碰到滑鼠奪權的 story 一律標記為**照現況實作、不修缺陷**。
> **不是**「等別人做完」,**也不是**「順手修一下」。
> **不標的話,下一個人會把它當待辦去修它 —— 那正好違反使用者的裁決。**

已知未修缺陷 **E1**:類比搖桿或方向鍵**持續按住**會造成滑鼠奪權永久鎖死。
🔴 **2026-09-01 新確認**:原本只有手把路徑的實測證據,**現確認鍵盤持續按鍵餵進同一條因果鏈**。

## 引擎驗證狀態

**ADR-0005 自列 16 項待驗證。** 其中「實作第一天就該跑掉」的 **7 項全部已關閉**
(#2/#3/#9/#11b/#13 於 2026-09-01,#12/#15 於 2026-08-20),證據在
`prototypes/adr0005-engine-probes-2026-09-01/` 與 `prototypes/engine-verification-spike-2026-08-20/`。

**仍開著的 3 項,兩項本機無法驗證**:

| # | 項目 | 處置 |
|---|---|---|
| 1 | `modules/input.md` / `modules/ui.md` 落後一個大版本(4.6 vs 釘選 4.7.1) | **不阻擋本 epic** —— 已以 `breaking-changes.md` 代償,並寫進控制清單。屬文件維護工作,建議另開 |
| 5 | Steam 疊加層是否觸發 `NOTIFICATION_APPLICATION_FOCUS_IN` | 🔴 **本機無 Steam 環境,測不了。** 依 `adr-acceptance-criteria.md` 第四節第 1 項**不阻擋核准**。若實際不觸發,機制九需備援偵測路徑 —— **列為整合測試期的觀察項** |
| — | 層 B:GDScript VM 在 export release 建置下是否中止所在函式 | 🔴 **本機無匯出範本,測不了。** 機制十的 S-1 防禦論證押在它上面(debug 下已實測會中止)。**列為取得匯出範本後的第一件事** |

其餘 5 項(#4/#7/#8/#11a/#14)已由設計降級為資訊項或低風險 —— **設計刻意不依賴它們的答案**。

## 適用的控制清單規則

實作前必讀 `docs/architecture/control-manifest.md` 的**呈現層**節(游標/輸入的 20 條必須、
14 條禁止),以及**核心層**中與結算定序相關的部分。

**本系統相關的 12 條 forbidden pattern**(權威清單在 `docs/registry/architecture.yaml`):
`logic_in_cursor_autoload_shell`、`unhandled_input_for_device_authority`、
`reading_input_event_device_id`、`native_control_hover_or_focus_on_registered_surface`、
`confirm_action_read_in_unhandled_input`、`cursor_state_write_from_own_signal_handler`、
`public_cursor_write_entry_calling_another`、`call_deferred_for_cursor_retarget_deferral`、
`single_node_for_nonadjacent_cursor_actor_roles`、`external_access_to_cursor_reclaim_instance`、
`independent_ifs_for_cursor_target_reset_policy`、`silent_freeze_fallback_for_invalid_provider`

## 已知的落地衝突

- **`class_name` 全域唯一** —— ADR-0001 契約的 `class_name Board` 與既有
  `src/gameplay/board/board.gd` 撞名(**已登記,未處置**)。本 epic 若需引用 `Board`,
  須先確認以哪一個為準。

## Definition of Done

本 epic 完成的條件:

- 全部 story 已實作、已審查,並經 `/story-done` 結案
- `design/gdd/cursor-highlight-state.md` 的全部驗收標準已驗證
- 全部 Logic 與 Integration story 在 `tests/` 有通過的測試檔
- 全部 Visual/Feel 與 UI story 在 `production/qa/evidence/` 有含簽核的證據文件
- 🔴 **「游標圖層 transform 恆等」已寫成一條會執行的自動化測試並通過**
  (ADR-0005 Validation Criteria #20 —— 這條是隨核准生效的硬性義務,不是選配)
- 🔴 **`InputEventKey.echo` 過濾已有測試覆蓋** —— 按住方向鍵不得每影格主張裝置權威

## Stories

**14 張,零 Blocked**(ADR-0005 已 `Accepted`,無 story 引用草案文件)。
**依 `Depends on` 順序推進** —— 每張 story 的該欄寫明它要等哪幾張完成。

| # | Story | 型別 | 狀態 | 估時 | 對應機制 | 依賴 |
|---|---|---|---|---|---|---|
| 001 | [共用列舉、目標值型別與策略契約](story-001-shared-types.md) | Logic | ✅ Complete | S(約 3–4 小時) | 二、三、八(契約) | — |
| 002 | [Autoload 薄殼 + DI 核心 + 三欄位狀態](story-002-state-host.md) | Logic | ✅ Complete | M(約 5–6 小時) | 一 | 001 |
| 003 | [表面註冊表(兩份獨立登記表)](story-003-surface-registry.md) | Logic | ✅ Complete | M(約 4–6 小時) | 三 | 001 |
| 004 | [裝置分類 + 動作語意分類(含 echo 過濾)](story-004-device-classification.md) | Logic | ✅ Complete | M(約 4–6 小時) | 四、四之二 | 001 |
| 005 | [整幀緩衝 + `_process` 裁決 + 六行為者定序](story-005-frame-buffer-ordering.md) | Integration | Ready | L(約 8–10 小時) | 五、六 | 002, 004 |
| 006 | [載入期設定驗證](story-006-startup-validation.md) | Logic | Ready | S(約 2–3 小時) | 七 | 001 |
| 007 | [寫入與讀取介面(七個公開入口 + 重入閘門)](story-007-write-read-interface.md) | Logic | ✅ Complete | L(約 8–10 小時) | 十 | 002, 003 |
| 008 | [焦點/暫停閘控](story-008-focus-pause-gating.md) | Integration | Ready | M(約 5–6 小時) | 九 | 002, 005 |
| 009 | [跨畫面交接生命週期(甲/乙/丙)](story-009-screen-handoff.md) | Integration | Ready | M(約 4–6 小時) | 十一 | 007 |
| 010 | [專屬游標 `CanvasLayer` + 圖層變換恆等防護測試](story-010-idle-indicator-host.md) | UI | ✅ Complete | S(約 2–3 小時) | 十二 | 002 |
| 011 | [原生游標隱藏 + 自繪載體 + 白名單例外](story-011-native-cursor-suppression.md) | Visual/Feel | Ready | L(約 8–10 小時) | 十三、十三之二 | 003, 010 |
| 012 | [已註冊表面禁用原生 focus/hover](story-012-disable-native-focus.md) | UI | 🔴 Blocked | S(約 2–3 小時) | 十四 | 003 |
| 013 | [幀精準量測儀器](story-013-frame-instrumentation.md) | Logic | Ready | S(約 3–4 小時) | 十五 | 005, 011 |
| 014 | 🔴 [滑鼠奪權策略(**凍結區:照現況實作,不修缺陷**)](story-014-mouse-reclaim-frozen.md) | Logic | ⏸ 凍結 | M(約 6–8 小時) | 八 | 001, 002 |

**估時合計:約 65–86 小時**(2026-09-02 補;原為 `[待 sprint 規劃時填]` 佔位符,
`/story-readiness` 判定「無估時的 story 無法排程」)。**這是粗估,不是承諾。**
專案尚無 `production/sprints/`,估時直接寫在各 story,不為了填一個欄位去建整套排程流程。

**驗收標準涵蓋**:GDD 的 **70 條有效 AC 全部分派完畢,零遺漏**(另 3 個編號是「本條已移除」的公告行,
正確排除)。逐條為**原文轉錄**,未改寫。

🔴 **另有 7 條 story 自訂驗收條文(`AC-S001-*` / `AC-S012-*` / `AC-S013-*`),來源是 ADR-0005 不是 GDD。**
它們於 2026-09-02 補上,因 001 / 012 / 013 三張未達 `/story-readiness` 的最低條文數門檻
(Logic 需 3、UI 需 2)。**每一條都標了它源自 ADR 的哪一節,查證時以 ADR 原文為準。**
⚠️ **這是本專案最貴失效模式的一個新曝險面** —— 同一事實的第二份抄本。
**ADR-0005 若改動這幾處,這 7 條必須同步。** 編號刻意加 `S` 前綴,不佔用 GDD 號碼,便於整批搜出。

🔴 **兩張 story 綁著隨核准生效的硬性義務,不得跳過**:
- **Story 010** —— 「游標圖層 transform 恆等」必須寫成會執行的自動化測試。<br>✅ **2026-09-04 已履行** —— `tests/unit/cursor/cursor_layer_transform_test.gd`,四種解析度對正式圖層斷言,且四條**逐條實測**在注入破壞時會紅。🔴 **連帶產生一條新義務落在 Story 011**(真的開視窗看畫面一次),見該張。
- **Story 004** —— `InputEventKey.echo` 過濾

⚠️ **本批未經 qa-lead 產生測試規格**(精簡模式 + 本環境未授權動用 Agent)。
替代做法是直接使用 GDD 的 AC —— 它們本就寫成 GIVEN/WHEN/THEN。
**但 AC 沒有列邊界值與失敗態**,各 story 已註記「邊界不明確時停下來問」。

---

## Next Step

🔴 **本節於 2026-09-04 更正 —— 原寫「執行 `/create-stories` 把本 epic 拆成工作單」,而 14 張工作單早在 2026-09-02 就已存在。**
這是一份完工後沒人回頭改的指路,照它做的人會重跑一次已經做完的事。

**現況**:14 張完成 6 張(001/002/003/004/007/010)。
**下一波可開**:006、009(前置皆已滿足);**011** 因 010 完成而解鎖。
**012 Blocked**(驗收標準的定義域是空集合,需先裁決強制執行落點);**014 凍結**。

⚠️ **上表「狀態」欄於 2026-09-04 由工作單檔案自動重建** —— 此前 14 列全部寫著 `Ready`,
而當時實際已有 5 張 Complete、1 張 Blocked。**手抄的狀態欄必然漂移,要現值就讀工作單第 4 行。**
