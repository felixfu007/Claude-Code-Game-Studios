# 工作單相依關係稽核(2026-09-03)

**範圍**:`production/epics/cursor-highlight-state/` 14 張工作單(story-001 ~ story-014),
對照 `docs/architecture/adr-0005-cursor-device-authority-input-architecture.md` 的
`### Key Interfaces` 節(第 1329 行起,契約段,優先於說明段)推導**契約層真實相依**——
逐張工作單要實作的簽章/建構子/回傳型別/常數,實際引用了哪些型別,那些型別的產出者是哪一張工作單。

**方法**:
1. 通讀 EPIC.md 與 14 張工作單全文。
2. 通讀 ADR 全 1676 行(分段讀取),重點為 Key Interfaces 節與機制一~十五各自的程式碼區塊。
3. 讀 `src/ui/cursor/` 已完成之 001/002/003 三張的實際原始碼(含檔頭 doc comment),
   確認契約上已存在的型別/方法**實際上**由誰產出——多處工作單的產出者判斷,
   最終依據是原始碼檔頭 doc comment 明文寫下的「這個 story 只做到這裡,下一個方法屬於哪一張」,
   而非僅憑 ADR 文字推測。
4. 唯讀稽核:除本檔外未讀寫 `src/ui/cursor/` 或 `tests/unit/cursor/` 任何檔案。

**14 張皆已查核完畢,無「未查核」項。**

---

## 逐張稽核表

| Story | 宣告的 `Depends on` | 契約層真實相依(推導) | 判定 | 依據(ADR 行號 + 簽章原文) |
|---|---|---|---|---|
| **001** 共用列舉、目標值型別與策略契約 | — | 無(本張是基礎契約檔案本身,`CursorTypes`/`CursorTarget`/`MouseReclaimPolicy` 抽象基底皆為本張產出,簽章不引用任何外部型別) | ✅ 相符 | Key Interfaces L.1339-1372(`cursor_types.gd`/`cursor_target.gd`/`mouse_reclaim_policy.gd` 三檔案區塊互不引用外部 story 型別) |
| **002** Autoload 薄殼 + DI 核心 + 三欄位狀態 | 001 | 001(`CursorTypes.Authority`)+ **003**(`CursorSurfaceRegistry`,建構子直接注入) | 🔴 **少列**(缺 003) | L.1376-1377:`func _init(reclaim: MouseReclaimPolicy, registry: CursorSurfaceRegistry, mouse_position_provider: Callable) -> void`。佐證:Story002 自身 Completion Notes 已載明「本 story 宣告 `Depends on: 001`,實際還需要 003 的 `CursorSurfaceRegistry`」(此為已知線索,本次獨立複核簽章後確認成立) |
| **003** 表面註冊表(兩份獨立登記表) | 001 | 001(`CursorTypes.SurfaceType` 供各方法簽章使用) | ✅ 相符 | L.1436:`func register(surface: CursorTypes.SurfaceType, node: Node) -> RegisterResult`;L.1438-1444 各方法皆只用內建型別 + `CursorTypes.SurfaceType`,無其他 story 型別 |
| **004** 裝置分類 + 動作語意分類(含 echo 過濾) | 001 | 001(`CursorTypes` 命名空間內的靜態方法,`classify()`/`classify_action()` 皆掛在同一個 `class_name CursorTypes` 上) | ✅ 相符(獨立複驗,結論與主 session 判斷一致) | Key Interfaces L.1349:`static func classify_action(event: InputEvent) -> ActionClass`;機制四 L.390:`static func classify(event: InputEvent) -> CursorTypes.Authority`。兩者回傳型別 `ActionClass`/`Authority` 皆為 001 已宣告的列舉,簽章不涉及 `CursorState`/`CursorSurfaceRegistry` |
| **005** 整幀緩衝 + `_process` 裁決 + 六行為者定序 | 002, 004 | 002(`_frame_events`)+ 004(`classify_action()` 供仲裁資格判定)+ **007**(`CursorState._write_target_internal()` 私有方法) | 🔴 **少列**(缺 007) | L.577-581:`func apply_buffered_navigation(events: Array[InputEvent]) -> void: ... 目標寫入一律走 _write_target_internal(target, TargetResetPolicy.CONDITIONAL_ON_CHANGE)`;`_write_target_internal()` 由機制十(L.811-819,「(1) 唯一實際改寫 `_target` 的地方」)定義並歸屬 —— EPIC.md 明文機制十對應 Story007 |
| **006** 載入期設定驗證(Input Map + Agile Flushing) | 001 | 001(`CursorTypes` 基礎)+ **004**(`NAVIGATION_ACTIONS`/`CONFIRM_ACTIONS`/`ACKNOWLEDGED_OTHER_ACTIONS` 三份清單,供 (c) 完整性驗證比對) | 🔴 **少列**(缺 004) | L.617:「遍歷 `InputMap.get_actions()` 中全部 `ui_*` action,對照機制四之二的三份清單(`NAVIGATION_ACTIONS` / `CONFIRM_ACTIONS` / `ACKNOWLEDGED_OTHER_ACTIONS`)」;Key Interfaces L.1346:`const NAVIGATION_ACTIONS / CONFIRM_ACTIONS / ACKNOWLEDGED_OTHER_ACTIONS: Array[StringName] # 第四輪新增第三份清單(R4-5,機制四之二)` —— 這三份清單是 EPIC.md 指派給 Story004(機制四之二)的產出,即使檔案位置與 001 的 `CursorTypes` 相同 |
| **007** 寫入與讀取介面(七個公開入口 + 重入閘門) | 002, 003 | 002(`CursorState` 類骨架)+ 003(`CursorSurfaceRegistry`,供 `_validate_target_writable()` 查詢表面是否已註冊) | ✅ 相符 | L.828:`func _validate_target_writable(target: CursorTarget) -> SetTargetResult`,對照 L.1436-1439 `CursorSurfaceRegistry.get_surface()`/`registered_surfaces_sorted()`;`_init()` 兩協作者已由 002 自身建構子注入(L.1376-1377) |
| **008** 焦點/暫停閘控 | 002, 005 | 002 + 005(`_frame_events.clear()`)+ **007**(`CursorState.reseed_reclaim_on_focus_regained()`) | 🔴 **少列**(缺 007) | L.733:`_state.reseed_reclaim_on_focus_regained() # 觸發點 (c):復焦重新播種`;此方法為 Key Interfaces L.919 所列 `CursorState` 七個公開入口之一,`src/ui/cursor/cursor_state.gd` 檔頭 doc comment 明文:「Story 007 adds the seven gated public write entries」。⚠️ **另有一項證據較弱、未列入本列判定的疑慮**:同段 L.734-735 亦呼叫 `_state.force_redraw_current_authority()`(標註 `# AC-30`,語意上可能是 Story008 自行在 `CursorState` 新增)與 `_state.reapply_native_cursor_visibility()`(標註 `# 機制十三`,語意上可能是 Story011 的產出)。ADR 全文未明文指派這兩個方法的撰寫歸屬,若 `reapply_native_cursor_visibility()` 確實歸 Story011,則 008 可能還需要依賴 011——證據強度不如 `reseed_reclaim_on_focus_regained()`,**列為待下一步排錯程查證的開放問題,不併入本列的判定** |
| **009** 跨畫面交接生命週期(甲/乙/丙) | 007 | 007(`handoff_before_unload()`/`handoff_after_mount()`) | ✅ 相符 | 機制十一 L.1007-1008:`func handoff_before_unload() -> MarkResult` / `func handoff_after_mount(target: CursorTarget) -> SetTargetResult`;Story007 Out of Scope 明文保留「入口本體」給自己,Story009 只管「三分支呼叫慣例」 |
| **010** 全域待機指示宿主 + 專屬 CanvasLayer | 002 | 002(`CursorStateHost` 持有 CanvasLayer) | ✅ 相符 | 機制十二 L.1045:「`CursorStateHost` 持有一層 `CanvasLayer`」,不涉及其他 story 型別 |
| **011** 原生游標隱藏 + 自繪載體 + 白名單例外 | 003, 010 | 003(`is_native_pointer_exception()` 白名單)+ 010(CanvasLayer 宿主)+ **007**(`CursorState.get_device_authority()`、`reclaim_progress()`、`reclaim_reset_triggered` 訊號) | 🔴 **少列**(缺 007) | L.1129:`if _state.get_device_authority() == CursorTypes.Authority.MOUSE`;L.1070:`_state.reclaim_reset_triggered.connect(_on_reset_triggered)`;L.1077:`var target := _state.reclaim_progress()`。三者皆為 `cursor_state.gd` 檔頭 doc comment 明文列出、**Story007 才產出**的讀取查詢/訊號(該註解逐字:「`get_current_target` / `get_device_authority` / `is_current_target_valid` / `reclaim_progress` do not exist yet」) |
| **012** 已註冊表面禁用原生 focus/hover(兩項條件) | 003 | 003(已註冊表面清單,供逐一檢視根節點型別) | ✅ 相符(獨立複驗,確認為**設計約束而非編譯期相依**) | 機制十四 L.1179:「高亮視覺只讀 `CursorState`,不讀任何引擎原生焦點/懸停狀態」——此句主詞是**下游系統(各表面)的高亮實作方式**,不是 Story012 自身程式碼的呼叫對象。Story012 的實際交付物(見其 Implementation Notes 全文)只操作 `Control.focus_mode` 與清空 hover/focus StyleBox,全文未出現任何 `CursorState` 方法呼叫或型別引用,結構上不需要 002 已完成 |
| **013** 幀精準量測儀器 | 005, 011 | 005(`diagnostic_last_authority_change_frame`/`diagnostic_last_target_change_frame` 依附 `arbitrate_device_authority()`/`apply_buffered_navigation()`)+ 011(`diagnostic_reclaim_progress_history` 取樣自繪節點的 `_presented_alpha`) | ✅ 相符 | 機制十五 L.1212-1218;L.1218 註解明文「取樣自繪節點每幀實際 `modulate.a`(即 `_presented_alpha`)」——`_presented_alpha` 為機制十三(Story011)自繪節點的欄位(L.1063) |
| **014** 滑鼠奪權策略(凍結區) | 001, 002 | 001(`MouseReclaimPolicy` 抽象基底、`CursorTypes.ResetTrigger`)+ 002(`CursorStateHost`,供日後把 `null` 佔位換成具體策略實例) | ✅ 相符 | `src/ui/cursor/cursor_state_host.gd` 檔頭 doc comment 明文:「Replace the `null` below with a real concrete `MouseReclaimPolicy` instance once Story 014 lands」——確認 Story014 的交付範圍包含編輯 002 的檔案,而非只獨立於 002 之外新增一個檔案 |

---

## 循環相依

**未發現循環相依。** 依上表推導的邊(A → B 表示 A 依賴 B):

```
001 → (無)
003 → 001
004 → 001
002 → 001, 003
006 → 001, 004
007 → 002, 003
010 → 002
014 → 001, 002
005 → 002, 004, 007
011 → 003, 007, 010
009 → 007
008 → 002, 005, 007  (⚠️ 011 為待查疑慮,未列入)
013 → 005, 011
012 → 003
```

反向檢查:007 的下游(005、008、009、011)皆不被 007 引用;005 的下游(008、013)皆不被 005 引用;
011 的下游(008⚠️、013)皆不被 011 引用。**全圖為 DAG,無環。**

---

## 依契約層真實相依重算的正確開工順序

以下依拓撲排序分波,同一波內可平行開工(前提:同波內彼此無依賴,已逐一核對):

| 波次 | 可平行開工的 Story | 理由 |
|---|---|---|
| **第 1 波** | 001 | 唯一無任何相依的基礎契約檔案 |
| **第 2 波** | 003, 004 | 兩者皆只依賴 001,互不相依 |
| **第 3 波** | 002, 006 | 002 需 001+003;006 需 001+004(**原判 006 可與 002/003/004 同波開,現更正為需等 004 完成**);兩者互不相依,可平行 |
| **第 4 波** | 007, 010, 012, 014 | 007 需 002+003;010 需 002;012 需 003;014 需 001+002 —— 四者互不相依,可平行 |
| **第 5 波** | 005, 011, 009 | 005 需 002+004+**007**;011 需 003+010+**007**;009 需 007 —— 三者皆需等 007 完成,彼此互不相依,可平行 |
| **第 6 波** | 008, 013 | 008 需 002+005+007(⚠️ 可能還需 011,待查);013 需 005+011 —— 兩者皆需等第 5 波完成 |

**與原交付單排序(EPIC.md 表)的關鍵差異**:

1. **007 從「第 4 波」的角色,實質上頂到了 005/009/011 三張的必要前置** —— 原表把 005 排在「002, 004 完成即可動工」,但 005 的 `apply_buffered_navigation()` 內部呼叫 007 才產出的私有方法 `_write_target_internal()`,**007 必須先於 005**。
2. **006 從「可與 002 同波」下修一波** —— 006 的 (c) 分類完整性驗證需要 004 產出的三份清單常數,**004 必須先於 006**。
3. **011 的前置多了 007** —— 白名單邏輯需要讀 `CursorState.get_device_authority()`/`reclaim_progress()`,這兩個查詢與 `reclaim_reset_triggered` 訊號皆為 007 的產出。
4. **008 的前置多了 007** —— `reseed_reclaim_on_focus_regained()` 是 007 產出的七個公開入口之一。

---

## 摘要

**判定為 🔴 少列的張數:4 張** —— Story 002(缺 003,已知線索確認成立)、Story 005(缺 007)、
Story 006(缺 004)、Story 008(缺 007)、Story 011(缺 007)。

> 更正計數:上方列出 5 張(002、005、006、008、011),非 4 張 —— 逐項覆核後的正確清單如下,
> 以清單為準,不以本行數字為準:

**🔴 少列清單(5 張)**:
- **Story 002**:少列 003(`CursorSurfaceRegistry` 建構子注入,已知線索,獨立複核成立)
- **Story 005**:少列 007(`apply_buffered_navigation()` 呼叫 `_write_target_internal()`,後者為 007 的私有路徑)
- **Story 006**:少列 004((c) 分類完整性驗證需要 004 產出的三份 action 清單常數)
- **Story 008**:少列 007(`reseed_reclaim_on_focus_regained()` 為 007 的七個公開入口之一)
- **Story 011**:少列 007(`get_device_authority()`/`reclaim_progress()`/`reclaim_reset_triggered` 皆為 007 的讀取查詢與訊號)

**✅ 相符清單(9 張)**:001、003、004(獨立複驗,確認主 session 判斷)、007、009、010、
012(獨立複驗,確認為設計約束而非編譯期相依)、013、014

**⚠️ 多列清單:0 張** —— 未發現任何工作單宣告了契約上不需要的相依。

**循環相依:無。**

**建議開工順序**(6 波,見上節):
`001` → `003,004` → `002,006` → `007,010,012,014` → `005,011,009` → `008,013`

**一項未列入判定、留給下一步排錯程查證的開放問題**:Story008 的焦點復焦處理呼叫
`_state.reapply_native_cursor_visibility()`(ADR L.735,標註「機制十三」),此方法的撰寫歸屬
ADR 未明文指派 —— 若歸屬 Story011,則 Story008 的前置還需加上 011。證據強度不如其餘 5 項
「少列」判定(那 5 項皆有原始碼檔頭 doc comment 或明確機制歸屬佐證),故本次不併入正式判定,
僅登記供下一次派工前查證。
