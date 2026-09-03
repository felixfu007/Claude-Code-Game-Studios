# Story 007「寫入與讀取介面」引擎與 ADR 一致性覆核

| 欄位 | 值 |
|---|---|
| 日期 | 2026-09-03 |
| 覆核者 | godot-specialist(引擎/架構覆核) |
| 受審檔案 | `src/ui/cursor/cursor_state.gd`(897 行)、`tests/unit/cursor/state_host_test.gd`(AC-1 排除名單改動) |
| 明文排除 | `tests/unit/cursor/write_read_interface_test.gd`(另一位覆核者負責;此刻仍在撰寫中) |
| 引擎 | Godot 4.7.1 / GdUnit4 v6.2.1 |

> 🔴 **本覆核不以測試結果為依據。** 派工明載 `write_read_interface_test.gd` 36 條中 30 條主體為空,
> GdUnit4 對零斷言測試一律判通過,故「35 條全過」字面為真而意義為空。
> 以下所有結論建立在逐行讀程式碼上,每項引用行號。

**檔案骨架(全部行號以本次讀到的 897 行版本為準)**

| 類別 | 成員 | 行 |
|---|---|---|
| 七個公開寫入入口 | `arbitrate_device_authority` / `apply_buffered_navigation` / `set_target` / `mark_pending_reresolve` / `handoff_before_unload` / `handoff_after_mount` / `reseed_reclaim_on_focus_regained` | 315 / 374 / 414 / 462 / 493 / 541 / 586 |
| 四個讀取查詢 | `is_current_target_valid` / `get_device_authority` / `get_current_target` / `reclaim_progress` | 629 / 635 / 644 / 679 |
| 六條未閘門私有路徑 | `_write_target_internal` / `_mark_pending_reresolve_internal` / `_validate_target_writable` / `_safe_mouse_position` / `_target_changed_from` / `_drain_pending_reseed` | 708 / 746 / 790 / 836 / 860 / 883 |

---

## 逐項判定

### 1. `handoff_before_unload()`(甲)呼叫私有 `_mark_pending_reresolve_internal()`

**PASS**(獨立複驗,結論與主 session 一致)

L.514 `var result: MarkResult = _mark_pending_reresolve_internal(_target)` —— 呼叫的是私有路徑。
全檔對公開 `mark_pending_reresolve()` 的呼叫**零次**(唯一出現處是 L.462 的宣告本身與各處
doc comment 的 `[method ...]` 交叉引用,非呼叫)。

- 傳入的 `expected` 是 `_target` 自身,L.510-512 的註解正確說明了它「依構造不可能 stale」,
  且說明了為何這是**刻意**的(甲的契約是「標記當前」而非「標記你以為的當前」)。
- L.517-518 的 `_reclaim.reset(..., SURFACE_HANDOFF)` 放在 `result` 檢查**之外**,
  符合 GDD Core Rules #7 F2-2「無論有沒有東西可標記都要歸零」。觸發原因用 `SURFACE_HANDOFF`
  而非 `TARGET_CHANGED` 亦正確 —— 此路徑上 surface/id 未變。

### 2. `_write_target_internal()` 兩條 reset 路徑的 `if`/`elif` 結構與 null 守衛位置

**PASS**(獨立複驗;此處為 CP7 改動過的位置,已重點確認)

`_write_target_internal()` L.708-736:

```
L.726  if _reclaim != null:
L.727      if reset_policy == TargetResetPolicy.UNCONDITIONAL:
L.728          _reclaim.reset(_safe_mouse_position(), ...SURFACE_HANDOFF)
L.729      elif changed:
L.730          _reclaim.reset(_safe_mouse_position(), ...TARGET_CHANGED)
L.734  if changed:
L.735      target_changed.emit()
```

三點逐一確認:

1. **`if`/`elif` 保留** —— 兩條 reset 路徑互斥,乙分支「UNCONDITIONAL 且 target 真的變了」
   的正常情況只會 `reset()` 一次、只放一個 trigger 上線。禁止樣式
   `independent_ifs_for_cursor_target_reset_policy` 未觸犯。
2. **null 守衛整組包在外層(L.726)**,不是各分支各加一個。這正是保住互斥性的寫法 ——
   若改成每個分支各自 `if _reclaim != null and ...`,`if`/`elif` 的鏈結關係會被拆散,
   等同退回兩個獨立 `if`。CP7 的改法**沒有引入該退化**。
3. **`target_changed.emit()`(L.734-735)在 `_reclaim` 守衛之外**,只依賴 `changed`,
   與 `reset_policy` 正交 —— 亦即 `_reclaim` 為 null 時訊號照發。這是正確的:
   訊號語意是「目標變了」,與 reclaim 子機制存不存在無關。

另確認 L.711-713 的取舊值/寫新值/再比較順序正確,符合 `_target_changed_from()` 的呼叫端義務。

### 3. 全檔 `call_deferred` 零次

**PASS**(獨立複驗)

`grep -n "call_deferred\|CONNECT_DEFERRED\|await\|set_deferred" src/ui/cursor/cursor_state.gd`
→ **零命中**。

這不只是形式合規。ADR-0005 的閘門模型依賴「入口的整個主體在同一個同步呼叫堆疊內完成」——
任何 `call_deferred` 或 `await` 都會讓 `_mutation_in_progress = false`(L.355/396/445/472/522/560/607)
與入口主體之間插入一個引擎主迴圈的回合,閘門的保護區間就不再等於方法主體。
`await` 在 GDScript 中尤其危險:它會把函式轉成協程,`_mutation_in_progress` 會**跨幀維持 true**,
之後所有公開呼叫永久 `REJECTED_REENTRANT`。零命中即結構性排除此風險。

唯一的非同步邊界是 L.297 的 `_reclaim.reset_triggered.connect(reclaim_reset_triggered.emit)` ——
但那是**預設(直連)連線**,無 `CONNECT_DEFERRED`,故 `reset()` 引發的轉發是同步的,
仍在閘門內。這正是 `_drain_pending_reseed()` 存在的前提(R6-10),前後一致。

### 4. 七個公開入口的閘門單一進入/單一釋放

**PASS(對 `return` 路徑)/ CONCERNS(對 abort 路徑)**

#### (a) `return` 路徑 —— 逐個入口走完,零繞過

| 入口 | 檢查 | 升旗 | 落旗前 drain | 落旗 | 升旗與落旗之間的 `return` |
|---|---|---|---|---|---|
| `arbitrate_device_authority` | 316 | 319 | 354 | 355 | **無** |
| `apply_buffered_navigation` | 375 | 378 | 395 | 396 | **無** |
| `set_target` | 415 | 417 | 444 | 445 | **無**(446 在落旗後) |
| `mark_pending_reresolve` | 463 | 465 | 471 | 472 | **無**(473 在落旗後) |
| `handoff_before_unload` | 494 | 496 | 521 | 522 | **無**(523 在落旗後) |
| `handoff_after_mount` | 542 | 544 | 559 | 560 | **無**(561 在落旗後) |
| `reseed_reclaim_on_focus_regained` | 587 | 594 | 606 | 607 | **無** |

四個有回傳值的入口一律用 `var result` 暫存、落旗後才 `return result`(L.446/473/523/561),
沒有任何一個在中途 `return` 掉。**這正是無 `finally` 語言下唯一能保證形狀的寫法,做對了。**
七個入口互不呼叫,禁止樣式 `public_cursor_write_entry_calling_another` 未觸犯(見第 9 項)。

#### (b) 🔴 但 `return` 不是 GDScript 唯一的離開方式 —— abort 才是

本檔自己在三處明文承認這件事(L.108-114 的 `ERR_RECLAIM_POLICY_ABSENT` 說明、
L.795-800 `_validate_target_writable` 的 assert 說明、L.862-867 `_target_changed_from` 的 null 說明):
**在已升旗的區間內發生執行期錯誤會中止外層函式、跳過落旗那一行,之後所有公開呼叫永久
`REJECTED_REENTRANT`。** 逐入口盤點升旗區間內的解參考:

- `arbitrate_device_authority` / `apply_buffered_navigation` / `mark_pending_reresolve` /
  `handoff_before_unload` / `reseed_reclaim_on_focus_regained` —— **零 abort 風險**,
  所有 `_reclaim` 解參考皆有 null 守衛,`_mouse_position_provider.call()`(L.841)只在
  `is_valid()` 之後,`equals()` 的 null 前置條件在 L.767 與 L.868 各被擋掉。
- `set_target`(417→445)與 `handoff_after_mount`(544→559)—— **各有兩個未關閉的 abort 面**:
  1. **L.801 `assert(target != null, ...)`**。本檔 L.795-800 的理由只論證了「release 版可能被
     剝除、所以後面那個 `if` 必須存在」,**沒有論證 debug 版 assert 觸發時會發生什麼**。
     debug 版下 assert 命中時 L.802 的 `if` 根本不會執行到,閘門停在升起狀態。
     ⚠️ 本專案未實測 Godot 4.7.1 的 assert 失敗是「中止函式」還是「整個停下」;
     若是前者,這就是本檔自己命名為「一次大聲的錯誤,接著是一個永久且無聲死掉的系統」
     的那個形狀。**列為必查,不列為已證實的缺陷。**
  2. **L.814 `_registry.get_surface(target.surface)` —— `_registry` 完全沒有 null 處理。**
     這是本檔三個協作者中唯一沒有的:`_mouse_position_provider` 在 L.250-251 建構期驗證,
     `_reclaim` 在 L.276-279 建構期驗證且六個呼叫點逐一守衛,**`_registry` 兩者皆無**。
     不對稱本身就是訊號 —— 一份對 null 協作者論述得如此徹底的檔案,漏掉第三個。

  ⚠️ **嚴重度限定**:已查證 `cursor_state_host.gd` L.77-81 傳入的是
  `CursorSurfaceRegistry.new()`(非 null),故此路目前**不是 live path**,只有測試注入 null
  時才可達。**不阻擋**,但應補一個與 `_reclaim` 同形的建構期報告(或至少在類別檔頭寫明
  「`_registry` 不接受 null,呼叫端自負」),否則下一個讀者會合理推論「本檔對 null 協作者
  一律有守衛」而據以注入 null。

---

#### (c) 🔴 深掘:三個指定問題的答覆

##### Q1 — 兩條 abort 路徑各在哪一行,在閘門「內」還是「外」?

**兩條都在閘門內。兩條都只出現在 `_validate_target_writable()` 裡,而該方法只有兩個呼叫者,
兩個都已經升好旗了。**

| # | 行 | 所在私有方法 | 由哪個入口到達 | 該入口升旗於 | 位置 |
|---|---|---|---|---|---|
| 1 | **L.801** `assert(target != null, ...)` | `_validate_target_writable` | `set_target` L.419 / `handoff_after_mount` L.548 | L.417 / L.544 | 🔴 **閘門內** |
| 2 | **L.814** `_registry.get_surface(target.surface)` | `_validate_target_writable` | 同上 | 同上 | 🔴 **閘門內** |

**後果的精確形狀**(這不是推測,是把本專案已實測的事實接起來):

1. ADR-0005 L.834-841 記載已實測結果:對已釋放物件呼叫 `.call()`
   **「會讓所在函式整段中止」**,且「中止範圍只到直接呼叫的那個函式,不往上傳播」。
   證據:`prototypes/engine-verification-spike-2026-08-20/` C2 段 / README F-10。
2. 「不往上傳播」這半句在這裡是**壞消息不是好消息**:中止停在 `_validate_target_writable()`,
   於是 `set_target()` L.420 之後的 `_drain_pending_reseed()`(L.444)與
   `_mutation_in_progress = false`(L.445)**照樣不會執行** —— 呼叫堆疊沒有被展開回去繼續跑,
   而是外層拿到一個未完成的回傳。
3. 結果:`_mutation_in_progress` **永久停在 `true`**。此後七個公開入口全部立刻回
   `REJECTED_REENTRANT` 或 no-op。**游標系統整個死掉,而且四個 `void`/計數路徑
   只會讓 `diagnostic_reentrant_rejection_count` 一直加。**

**這正是本檔 L.108-114 自己寫下的那段話所描述的形狀** ——
「a loud one-off error followed by a permanently and silently dead system: strictly worse than
either alternative」。實作者為 `_reclaim` 完整推導了這個論證,**卻沒有把同一個論證套用到
同一個檔案裡的另外兩條路徑上。**

⚠️ **兩條的 release 行為未查證,且本專案查證不了**:ADR-0005 L.123-127 明文登記
「層 B(GDScript VM 在 export release 建置下是否中止所在函式)—— **未查證,本 ADR 依賴它**」,
原因是本機 `export_templates/` 為空。**因此以下判斷對 debug 成立(已實測),
對 release 是外推。** 兩者的方向相同(都更壞),故不影響建議。

##### Q2 — `_safe_mouse_position()` 的 `is_valid()` 守衛是否覆蓋全部取值點?

**✅ PASS —— 覆蓋率 100%,零繞過。這是本檔做得最乾淨的一處。**

全檔對 `Callable` 的實際取值只有**一處**:

```
L.836  func _safe_mouse_position() -> Vector2:
L.837      if not _mouse_position_provider.is_valid():
L.838          diagnostic_invalid_mouse_provider_count += 1
L.839          return _last_mouse_position
L.840      var position: Vector2 = _mouse_position_provider.call()
```

`grep "\.call(\|\.callv("` 全檔僅命中 **L.840** 一行,且它在 L.837 的守衛之後、
兩行之間無 `await`、無訊號、無任何可被重入的縫隙(GDScript 單執行緒非搶佔,
ADR L.~957「專家發現 D」第 1 點已論證過此前提)。

五個座標消費點(L.519 / 600 / 727 / 729 / 896)**全部經由 `_safe_mouse_position()`**,
無一直接碰 `_mouse_position_provider`。另一處 L.330 是 `is_valid()` 詢問而非取值,
符合 S-3 的「座標只經 `_safe_mouse_position()`」且 ADR L.850-856 明文承認此區分。

**故不存在第三條 abort 路徑。S-1 押注的正中央是守住的。**

##### Q3 — 有沒有不需要 `try`/`finally` 的結構修法?

**有,而且很便宜。兩項,建議都做。**

**修法 A(針對這兩條路徑,治本):把驗證整段前移到升旗之前。**

關鍵事實 —— 我逐行確認過:**`_validate_target_writable()` 對「閘門要保護的東西」完全是純的。**
它只讀 `target`(參數)與 `_registry`;**不讀不寫 `_target`、不讀不寫 `_device_authority`、
不碰 `_reclaim`、不發任何訊號**(L.790-817 全文)。因此把它移到升旗之前,
**語意零變化**,只是 abort 時閘門還沒升起:

```
建議形狀(以 set_target 為例,handoff_after_mount 同):
    if _mutation_in_progress:
        return SetTargetResult.REJECTED_REENTRANT
    var result := _validate_target_writable(target)      # ← 移到閘門外
    if result != SetTargetResult.APPLIED:
        return result                                     # ← 旗標從未升起,提前 return 安全
    _mutation_in_progress = true
    _write_target_internal(target, ...)
    _drain_pending_reseed()
    _mutation_in_progress = false
    return result
```

- **這不違反「單一進入/單一釋放」**:新增的提前 `return` 位在**升旗之前**,
  旗標從未升起,自然不需要釋放。單一進入/單一釋放管轄的是「升旗之後」的區間,
  而那個區間反而**變短了**(從 29 行縮到 4 行)。
- **失敗模式從「系統永久死亡」降為「這一次呼叫失敗」。** 這是質變不是量變。
- **與 ADR 的相容性**:ADR L.933 寫「七者進入時皆先設 `_mutation_in_progress = true`」。
  字面上本修法讓升旗晚了幾行。但該句的**保護目標**是下一句
  「完成全部欄位寫定、且訊號已發出後才設回 `false`」—— 驗證不寫欄位、不發訊號,
  移出去不觸碰該不變式。⚠️ **ADR-0005 已 `Accepted`,故此改動需架構擁有者一句確認**,
  但它是**收緊**而非放寬,且不改任何對外行為或回傳值,覆核成本應該很低。

**修法 B(針對閘門這個機制本身,治標但涵蓋未知):比照 ADR-0001 加卡死偵測。**

🔴 **本專案對「布林旗標卡在 true = 系統無聲死亡」已經有一份成文結論,而 ADR-0005 沒有繼承它。**

`docs/architecture/adr-0001-tactical-query-atomicity-contract.md` **L.141**:

> **卡死偵測(2026-08-18 `godot-specialist` 驗證發現的一個比重入更嚴重的失效模式)**:
> `settlement_in_progress` **不得跨越兩個連續的 `_process` 幀仍為 `true`**;若偵測到,
> 須以 `push_error()` 明確曝光。(…)後果不是「一次可觀測的拒絕」而是**整場戰鬥輸入永久鎖死
> 且無任何錯誤訊息**——比本旗標原本要防的情境更糟。

同 ADR **L.385** 已把它升為 Validation Criteria 第 7 項(可自動化測試)。

**兩個旗標是同一個形狀、同一個後果,卡死成因不同**(ADR-0001 怕的是永不恢復的 `await`;
本檔 `await` 零命中,怕的是閘門內 abort),**但 ADR-0001 的修法可以原樣移植**:
`CursorStateHost` 是 `Node`、有 `_process`、`process_priority = -100`(`cursor_state_host.gd` L.70-71),
要斷言「`_mutation_in_progress` 不得跨越兩個連續 `_process` 幀仍為 `true`」在結構上完全做得到。

**修法 A 與 B 不重複,建議都做**:A 關掉今天已知的兩條路徑;
B 是安全網,涵蓋**未來**在閘門內新長出來的 abort 面 —— 而這是必然會發生的:
Story 014 的具體 `MouseReclaimPolicy` 子類別一落地,`_reclaim.reset()`
(L.519 / 600 / 727 / 729 / 896,**五處全在閘門內**)就變成一個本檔管不到的第三方呼叫,
它 abort 一次的後果與上述完全相同,而**修法 A 幫不上忙**(reset 必須在閘門內執行)。

##### 深掘結論

第 4 項由 CONCERNS 維持 CONCERNS,**但性質要講清楚**:
七個入口的 `return` 形狀**做得完全正確**,無一繞過;問題不在實作者寫錯了什麼,
而在於**這個形狀所保護的範圍比它需要保護的範圍小一圈**,
而本專案在另一份 ADR 裡已經發現過同一件事並寫下了修法,只是沒有跨文件傳過來。

**判定為不阻擋**(今天沒有 live path:`_registry` 由 Autoload 傳入非 null、
`target` 為 null 需呼叫端違約),**但列為必修**,理由是:
`_reclaim` null 那條**本來也不是 live path**,而實作者為它寫了 40 行論證與六個守衛。
**同一個標準應該套用到同一個檔案的其餘兩條。**

### 5. 三個 `void` 入口重入:整段 no-op 且遞增 `diagnostic_reentrant_rejection_count`

**PASS(兩個)/ PASS-with-note(第三個,刻意偏離且偏離有據)**

| 入口 | 重入分支 | 整段 no-op? | 遞增計數? |
|---|---|---|---|
| `arbitrate_device_authority` | L.316-318 | ✅ 是 | ✅ L.317 |
| `apply_buffered_navigation` | L.375-377 | ✅ 是 | ✅ L.376 |
| `reseed_reclaim_on_focus_regained` | L.587-593 | ⚠️ **不是** —— L.591 寫 `_pending_reseed = true` | ✅ L.592 |

第三個的偏離是**正確的,而且是 ADR 自己要求的**:ADR-0005 L.902-905(R6-10,2026-08-21 第四次修訂)
逐字要求「偵測到 `_mutation_in_progress` 為真時設 `_pending_reseed = true`」。實作 L.591 照做。

🔴 **但這暴露 ADR 自身的一處內部不一致(文件層,不阻擋本張)**:
ADR L.934 那段「三個回傳 `void` 的入口如何表達拒絕」寫的是
「三者的閘門語意是『偵測到重入即**整段 no-op、不寫任何欄位**、不發任何訊號』」——
**這句話在 R6-10 之後對第三個入口已不成立,而該段未被同步更新。**
兩段相距約 30 行、同屬機制十。**照 L.934 字面實作的人會丟棄 reseed 請求**,
正好復現 R6-10 要修的那個缺口(ADR L.906-912 自己描述的失敗方向)。

實作選了較新且較具體的 R6-10,是對的。**建議**(不阻擋):在 ADR L.934 那段補一句
「第三個入口的例外見 R6-10」。這是純文字補綴、不改任何決策,成本極低,
而它防的是一個 ADR 自己記載過的實際缺口。

另註:`_pending_reseed` 是機制欄位(L.203),不是 Core Rules #1 的三個狀態欄位之一,
故就 AC-1 的定義域而言「不寫任何欄位」仍可辯護 —— 但 L.934 的行文沒有做這個區分,
讀者無從得知。

### 6. `reseed_reclaim_on_focus_regained()` 重入記 `_pending_reseed`;`_drain_pending_reseed()` 於落旗前呼叫

**PASS —— 兩個半條件全部成立,且實作者對 ADR 的引述經查證屬實**

#### (a) 重入時記錄而非丟棄

L.587-593:`if _mutation_in_progress:` → `_pending_reseed = true`(L.591)→ 計數 +1(L.592)→ `return`。
符合 ADR L.902-905(R6-10)。用 `bool` 而非計數亦符合 ADR L.903 的明文理由(重新播種冪等)。

#### (b) `_drain_pending_reseed()` 在每個入口落旗**之前**

七個入口逐一核對,**drain 與落旗永遠是相鄰兩行、drain 在前**:

| 入口 | drain | 落旗 |
|---|---|---|
| `arbitrate_device_authority` | L.354 | L.355 |
| `apply_buffered_navigation` | L.395 | L.396 |
| `set_target` | L.444 | L.445 |
| `mark_pending_reresolve` | L.471 | L.472 |
| `handoff_before_unload` | L.521 | L.522 |
| `handoff_after_mount` | L.559 | L.560 |
| `reseed_reclaim_on_focus_regained` | L.606 | L.607 |

**七個全有,各恰一次,零遺漏。**

#### (c) 複核實作者在 L.876-882 對 ADR 的引述 —— 屬實

該處註解寫「ADR-0005 is explicit that all seven do it uniformly rather than six」。
**已查證為真**:ADR L.1408-1414(Key Interfaces,契約層)逐字寫
「**六個會發訊號的公開入口**在清除 `_mutation_in_progress` **之前**各呼叫本方法恰一次(…)。
`reseed_reclaim_on_focus_regained()` 自己不需要,但為避免『漏了一個』的疏漏,**七個一起做**。」

⚠️ 但 **Validation Criteria #13(iv)(ADR L.1630)只寫「六個」**,沒有帶上 Key Interfaces 的
「七個一起做」那半句。**契約層說七、驗證條款說六。** 依派工單「衝突時以 Key Interfaces 為準」,
實作的七個是對的;但**照 VC #13(iv) 字面寫測試的人會寫出一條只檢查六個的斷言**,
第七個漏掉不會被抓到。與第 16(a) 項是同一類問題(VC 未隨修訂同步),一併列在文件層建議。

#### (d) drain 內部的順序

L.883-897:先 `reset()`(L.896)、後清旗標(L.897)。ADR L.905 要求的順序即此。
L.886-891 的註解對「為何先 reset 再清旗標」的說明(reset 會發訊號 → 下游可在本次呼叫內
再設 `_pending_reseed` → 清掉是對的,因為剛播種過、冪等)**推理正確**,
且與 `_pending_reseed` 選 `bool` 的理由自洽。

### 7. `get_current_target()` 回傳新配置複本、逐欄完整

**PASS —— 複製完整,零漏欄**

`get_current_target()` L.644-656:

```
L.645  if _target == null:
L.646      return null
L.652  var copy: CursorTarget = CursorTarget.new()
L.653  copy.surface = _target.surface
L.654  copy.id = _target.id
L.655  copy.is_valid = _target.is_valid
L.656  return copy
```

已比對 `src/ui/cursor/cursor_target.gd` L.11-13,`CursorTarget` 的欄位**恰好三個**:
`surface`、`id`、`is_valid`。**三個全部複製,無遺漏。**

- **不用 `CursorTarget.make()` 是正確的**,而且是必要的:`make()`(`cursor_target.gd` L.44-49)
  無條件把 `is_valid` 設 `true`,用它會讓「pending re-resolve 的目標」被回報成有效目標 ——
  這正好會摧毀 `is_current_target_valid()` 想守住的東西。L.648-651 的註解說明了這點,正確。
- **不用 `CursorTarget.invalidated()` 也正確**:那個反過來無條件設 `false`。兩個 static 工廠
  都是有偏的,逐欄複製是此處唯一忠實的做法。
- 禁止樣式 `returning_internal_container_references` 未觸犯:回傳的是 `CursorTarget.new()` 的
  新實例,呼叫端拿不到 `_target` 本身。
- ⚠️ **一項不阻擋的觀察**:`CursorTarget` 的三個欄位是公開可寫的普通 `var`,所以回傳的複本
  是可變的。這不影響本類別的內部狀態(複本與 `_target` 無別名關係),但意味著
  `cursor_target.gd` 檔頭宣稱的 "Immutable: any change produces a new instance" 在型別層面
  仍是紀律而非結構。本檔 L.641-643 的註解對此的措辭是誠實的
  (「'immutable' is discipline; copying makes it structure」),**未誇大**。

### 8. `_target_changed_from()` 的雙條件

**PASS**

`_target_changed_from()` L.860-870:

```
L.868  if old == null or new == null:
L.869      return old != new
L.870  return not old.equals(new) or old.is_valid != new.is_valid
```

L.870 與要求的形狀**逐字一致**。已獨立複核 `src/ui/cursor/cursor_target.gd` L.39-41:

```
func equals(other: CursorTarget) -> bool:
	assert(other != null, "CursorTarget.equals: other must not be null")
	return surface == other.surface and id == other.id
```

`equals()` 確實只比 `surface` + `id`,**不看 `is_valid`**,故兩個條件缺一不可:

- 少了第一條 → 換目標但新舊 `is_valid` 同為 `true` 時不發訊號(一般導航全失效)。
- 少了第二條 → `_mark_pending_reresolve_internal()`(L.772-776)的有效性翻轉
  **完全偵測不到**,因為 `invalidated()` 保留同一組 surface/id、`equals()` 判定相等。
  檔內 L.850-855 記載的 R6-7 事故(讀檔回到同一棋盤,`is_valid` false→true,
  只訂閱不輪詢的下游永久卡在 pending 視覺)就是這條缺席造成的。

另確認 **`equals()` 的 null 前置條件在兩個呼叫點都被擋住**:L.868 的守衛,以及
`_mark_pending_reresolve_internal()` L.767 的 `if expected == null or not expected.equals(_target)`
—— GDScript 的 `or` 是短路求值,`expected == null` 為真時右側不會執行,故 assert 不會被觸發。
**這是對的,而且依賴短路語意,不要重排這兩個運算元。**

L.868-869 的 null 退化路徑(退回參考比較)是防禦性的,理由(避免 abort 卡死閘門)與第 4 項
所述的整體風險模型一致,寫法自洽。

### 9. 四條禁止樣式逐條判定

**PASS(全數未觸犯)—— 但先說明「四條」的範圍歧義**

⚠️ 派工單寫「四條禁止樣式」。實測登記表 `docs/registry/architecture.yaml` 的 `forbidden_patterns` 節
與本檔相關的**不只四條**:ADR-0005 自己就有 **12 條**,另有 ADR-0001/0002 各 1 條會約束到本檔,
再加 **3 條專案級**(`technical-preferences.md` 列的專案級禁令中,`abstract_func_with_body` 不約束本檔)。
「四條」可能指專案級那組。**為免漏判,以下把所有會約束到本檔的條目全查**,不只四條。
指令:`grep -n -A8 "pattern: <名稱>" docs/registry/architecture.yaml`。

#### A. ADR-0005 的 12 條

| # | pattern | 判定 | 依據 |
|---|---|---|---|
| 1 | `public_cursor_write_entry_calling_another` | **PASS** | 全檔對七個公開入口的呼叫**零命中**(僅 doc comment 的 `[method ...]` 交叉引用)。共用行為一律下放六條私有路徑:`_validate_target_writable`(L.419/548 兩處呼叫)、`_mark_pending_reresolve_internal`(L.468/514)、`_write_target_internal`(L.420/558)。**甲分支 L.514 走私有版是關鍵證據**(見第 1 項) |
| 2 | `independent_ifs_for_cursor_target_reset_policy` | **PASS** | L.727/729 為 `if`/`elif`,外層 L.726 單一 null 守衛未拆散鏈結(見第 2 項) |
| 3 | `call_deferred_for_cursor_retarget_deferral` | **PASS** | `call_deferred`/`CONNECT_DEFERRED`/`set_deferred`/`await` **全部零命中**(見第 3 項)。⚠️ 註:ADR L.~950 建議**呼叫端**可用 `call_deferred` 延到下一影格 —— 那是給下游的,不是給本檔的,兩者不衝突 |
| 4 | `cursor_state_write_from_own_signal_handler` | **PASS** | 本檔不訂閱自己的任何訊號。唯一的 `connect`(L.277)是把 `_reclaim.reset_triggered` 轉發到自己的 `reclaim_reset_triggered.emit` —— 純轉發,不觸發任何寫入。**且本檔的結構保證(閘門 + `_drain_pending_reseed`)本來就不依賴這條紀律**,符合 ADR「結構優於紀律」立場 |
| 5 | `external_access_to_cursor_reclaim_instance` | **PASS** | `_reclaim`(L.185)無 getter、不出現在任何回傳型別。`reclaim_progress()`(L.679)回傳 `float`、`reclaim_reset_triggered`(L.179)只帶 enum。登記表 L.2010-2013 明文連 `CursorStateHost` 呼叫 `_reclaim.reset(...)` 都禁止 —— 已查 `cursor_state_host.gd`,它只在 L.77-81 把 `null` **傳入**建構子,之後從不持有 |
| 6 | `silent_freeze_fallback_for_invalid_provider` | **PASS** | 登記表 L.2211-2215 要求「per-frame polled 路徑不得回退到上次值,須升級為系統層降級:整段跳過 + `push_error()` 恰一次(bool 守衛)+ 保留診斷計數」。L.330/346-352 三項全做到:L.346 計數、L.347-352 由 `_provider_error_reported` 守衛的單次 `push_error`。`_safe_mouse_position()`(L.836)的回退契約**只服務一次性播種呼叫點**,ADR L.842-846 明文允許 |
| 7 | `unhandled_input_for_device_authority` | **N/A(結構性不適用)** | 本檔是 `RefCounted`(L.60),不在場景樹上,**沒有也不可能有** `_unhandled_input()`。已 grep 確認零命中 |
| 8 | `confirm_action_read_in_unhandled_input` | **N/A** | 同上 |
| 9 | `reading_input_event_device_id` | **PASS(且是結構性免疫)** | 見第 17 項 —— `InputEvent` 全檔只出現在 L.315/374 兩個簽章的型別位置,**從未被解參考**,`.device` 零命中 |
| 10 | `logic_in_cursor_autoload_shell` | **N/A(方向相反,且本檔是它的受益者)** | 該條管的是 `CursorStateHost` 不得含邏輯。本檔正是邏輯該待的地方 |
| 11 | `native_control_hover_or_focus_on_registered_surface` | **N/A** | 場景層,本檔無 `Control` |
| 12 | `single_node_for_nonadjacent_cursor_actor_roles` | **N/A** | 場景層節點切分 |

#### B. 其他 ADR 約束到本檔的 2 條

| pattern | 來源 | 判定 | 依據 |
|---|---|---|---|
| `returning_internal_container_references` | ADR-0001 | **PASS** | `get_current_target()` L.644-656 逐欄複製後回傳新實例(見第 7 項) |
| `enum_value_positional_string_conversion` | ADR-0002 | **PASS** | L.811 用 `CursorTypes.SurfaceType.find_key(target.surface)` —— 正是登記表指定的 value→enum 做法,未用位置字串轉換 |

`mutable_container_as_dictionary_key`(ADR-0002):本檔無任何 `Dictionary`,**N/A**。

#### C. 專案級 3 條

`rng_in_combat_settlement` / `networking_features` / `procedural_terrain_generation` —— 三條**全部 N/A**:
本檔零 `randi`/`randf`/`RandomNumberGenerator`、零網路 API、零地形生成。
`abstract_func_with_body`:本檔無 `@abstract` 宣告,N/A(`MouseReclaimPolicy` 的 `@abstract` 不在本次範圍)。

#### 🔴 附帶發現(登記表本身,文件層,不阻擋)

`public_cursor_write_entry_calling_another` 的 `description`(登記表 **L.1930-1933**)只列了**五個**公開入口:
`arbitrate_device_authority / apply_buffered_navigation / set_target / mark_pending_reresolve / handoff_before_unload`
—— **缺 `handoff_after_mount` 與 `reseed_reclaim_on_focus_regained`**。

那兩個正是 ADR 第三次修訂(R5-1 / R5-3)把入口由五增為七時新增的,**登記表沒跟上**。
本張實作沒有觸犯(七個都沒互相呼叫),所以今天無害;
**但登記表是禁止樣式的權威來源**,照它字面做靜態檢查的人會漏檢兩個入口 ——
而 `handoff_after_mount` 恰恰是 ADR L.~940 表格裡點名「最可能被實作者拿去借用 `set_target()` 驗證」的那一個。
**建議把 description 補成七個**(純文字,不改決策)。

### 10. 三處「ADR 未定義」邊界的註解措辭 + 技術判斷

**措辭層:三處全 PASS —— 逐字查證,無一處把自己的決定寫成 ADR 的規定。**
**技術層:兩處判「讀法正確」、一處判「讀法可接受但最弱」。三處都有一個共通的真缺口 —— 見 (d)。**

先講查證方法:我**不採信實作者自述**,對三處各自去 ADR 求證「ADR 是否真的沒定義」。
🔴 **三處的『ADR 未定義』宣稱全部屬實。** 本專案上個月發生過「註解裡寫著一句不存在的管理者裁決」,
這一輪**沒有復發**。

---

#### (a) `MarkResult.NO_CURRENT_TARGET` 的觸發條件(L.746-759)

**措辭:PASS。** L.751 逐字 `# ⚠️ BOUNDARY NOT DEFINED BY ADR-0005 — reported, not silently chosen.`

**查證:宣稱屬實,而且比它說的更徹底。**
`grep -n "NO_CURRENT_TARGET" docs/architecture/adr-0005-*.md` → **全文僅 1 命中,在 L.770 的 enum 宣告本身。**
**ADR 從頭到尾沒有第二次提到這個值。** 沒有觸發條件、沒有語意說明、沒有測試向量。

**技術判斷:讀法正確,我同意,而且理由比註解寫的更強。**

實作採「沒有*當前(有效)*目標可失效」而非「參照為 null」:

```
L.758  if _target == null or not _target.is_valid:
L.759      return MarkResult.NO_CURRENT_TARGET
```

支持這個讀法的三條依據(我獨立查證):

1. **「參照為 null」讀法會讓這個 enum 成員永久死掉。** 實測 `_target` 的全部賦值點:
   L.281(`_init` 的 `CursorTarget.new()`)、L.712(`_write_target_internal`,寫入前已驗證非 null)、
   L.771(`CursorTarget.invalidated(old)`,靜態工廠必回非 null)。**`_target == null` 在本類別不可達。**
2. **ADR 自己有一條相同方向的前例。** R6-6 刪掉 `surface` 參數時,ADR L.~880 明確
   「**選擇刪除而非新增 `SURFACE_MISMATCH`**」,理由包含不願保留一個沒東西能到達的成員。
   **一個讀法會製造死成員、另一個不會,ADR 的既有立場站在後者。**
3. **檢查順序正確。** L.756-757 的理由(「呼叫方的認知是不是最新的」在沒有東西可比時無意義)
   成立 —— 若先比 staleness,`expected` 與一個已失效的 `_target` 比較會走到
   `equals()`(只比 surface+id)而回傳 `APPLIED`,**等於對一個已經失效的目標再失效一次**,
   語意更糟。

🔴 **但有一個呼叫端會踩到的行為後果,而且沒有寫在公開文件裡** ——
情境:目標 T 已被別人標記為待重新解析,呼叫方手上仍持有 T 並呼叫 `mark_pending_reresolve(T)`。
**實際回傳 `NO_CURRENT_TARGET`,不是 `APPLIED`。**
呼叫方想要的後置條件(「T 處於待重新解析」)**其實已經成立**,但它收到的碼看起來像失敗。
寫重試邏輯的人會據此重試,而重試永遠得到同一個碼。

**這不是實作錯**(這個讀法下就該這樣),**是文件缺口**:
`mark_pending_reresolve()` 的公開 doc comment(L.448-460)**完全沒提 `NO_CURRENT_TARGET`** ——
只講了 `APPLIED` 與 `STALE_NOT_APPLIED`。四個回傳值裡有兩個沒被公開文件說明
(另一個是 `REJECTED_REENTRANT`)。**建議補三行。**

**是否該回頭修 ADR?** —— **該補,但不急。**
建議在 ADR 的 `MarkResult` 定義處補一句觸發條件(**一行**),把這個讀法定死,
否則下一個實作者(或重構者)有 50% 機率選另一個讀法,而**兩個讀法都不會報錯**。
**急迫性:下一張碰到 `MarkResult` 的工作單(Story 009 三分支呼叫慣例)一併處理即可。**

---

#### (b) `_validate_target_writable()` 收到 null 的回傳(L.790-803)

**措辭:PASS,而且是三處裡最克制的一處。** L.791-800 逐字寫
`# ⚠️ BOUNDARY NOT DEFINED BY ADR-0005 — reported, not silently chosen.`,
並明說 `Mapping null onto INVALID_SURFACE_TYPE is the least-wrong of the three available
members …, NOT an ADR decision.` —— **它自己就用了「least-wrong」而不是「correct」。**

**技術判斷:🔴 這是三處裡最弱的一個讀法。可接受,但它把兩種需要不同處置的事情合併了。**

`INVALID_SURFACE_TYPE` 現在同時代表兩件事:

| 情況 | 性質 | 呼叫方該做什麼 |
|---|---|---|
| `target.surface` 是超出 enum 值域的整數(L.811) | **執行期資料問題** | 檢查資料來源、可復原 |
| `target` 是 `null`(L.802) | **呼叫端違約 / 程式 bug** | 改程式,不可能在執行期復原 |

**兩者收到同一個碼,呼叫方結構上分不出來** —— 而這正是本 ADR 在讀取介面那一節
(L.~1010「兩種拒絕回饋必須在感知上可區分」)花了整段篇幅反對的形狀。
**同一份 ADR 在讀取側堅持「兩種拒絕不可合併」,在寫入側卻沒有給第三個成員。**

**有沒有更好的讀法?** 技術上有:新增 `INVALID_TARGET_NULL` 成員。
**但我不建議做**,三個理由:
① `SetTargetResult` 是 ADR 明文「Frozen member list」(本檔 L.133-136 亦轉述);
② ADR 已 `Accepted`,加 enum 成員牽動 ADR + 登記表 + 兩個公開方法的契約 + 測試向量;
③ 專案有**流程劑量上限**(`technical-preferences.md`:同一份文件不做第三次以上修訂),
   為一個「呼叫端違約」情境開一輪 ADR 修訂,代價不成比例。

**我建議的處置(零 ADR 成本)**:
1. **採納第 4 項 Q3 的修法 A**(把驗證前移到閘門外)。這會**順帶解決本項最危險的部分** ——
   L.801 的 `assert` 就不再位於閘門內,「debug 版 assert 命中 → 閘門永久卡死」這條就消失了。
   **兩個問題共用一個修法。**
2. 在 `set_target()` 與 `handoff_after_mount()` 的**公開** doc comment 各補一句:
   「`INVALID_SURFACE_TYPE` 亦涵蓋 `target` 為 `null` 的情形(ADR 未定義,本實作的對應)」。
   目前兩處公開文件**都沒提**,呼叫方只有讀私有方法才會知道。

**是否該回頭修 ADR?—— 不必修,但要記一筆。**
建議在 ADR 的 `SetTargetResult` 處加一句**非規範性註記**
(「null target 未定義;現行實作對應至 `INVALID_SURFACE_TYPE`,見 `cursor_state.gd`」),
讓下一個讀 ADR 的人不會以為這是漏寫。**急迫性:低,可與 (a) 同批。**

---

#### (c) `set_target()` 的 `from_ui_action == true` 行為(L.422-441)

**措辭:PASS —— 三處裡最好的一處。** 它不只標明未定義,還明確拒絕猜測:
L.441 逐字 `Raised as an open question for the architecture owner; do not close it by guessing.`

**🔴 我特別查證了它對 ADR 的引述,因為這種句子最容易被寫成不存在的規定 —— 引述屬實。**
ADR **L.1041** 逐字:

> **裝置權威不隨目標交接重置**:`set_target()` **只在 `from_ui_action == true` 時連動裝置權威轉移**。
> 甲/乙/丙三分支的呼叫皆為系統主動改標,`from_ui_action` 一律傳 `false`——裝置權威維持不變。

**ADR 確實這樣說了,而且確實沒說「轉移到哪個裝置」。** 註解的轉述精確,無誇大也無虛構。

**技術判斷:不實作是對的。但實作者給的理由只覆蓋了一半情境,這點要講清楚。**

實作者的推理(L.434-438):步驟一 `arbitrate_device_authority()`(−100)已在同影格稍早裁定權威,
步驟二呼叫方於 −60 改標,**此時已無權威可轉移**。

✅ **這對「四步影格流程內的呼叫」成立。**
🔴 **但 `set_target()` 不是只有流程內呼叫者。** 它是**通用公開入口** ——
丙分支交接(ADR L.~1000)、任何呼叫方系統在任意時點的主動改標都走它,
**那些呼叫不保證發生在同一影格的 −100 之後。** 對它們而言「已經裁定過了」的前提不存在。

**但這反而讓「不實作」更正確,不是更不正確:** 情境比實作者想的更多、
而簽章依然沒有攜帶任何裝置資訊可據以推導。**在這裡發明規則會有兩個獨立的猜測疊加**
(猜轉移到哪個裝置 + 猜哪些呼叫情境適用)。**維持不實作、明文登記為開放問題,是正解。**

⚠️ **一項次要的一致性瑕疵**:
```
L.440  if from_ui_action:
L.441      pass
```
這個空分支的存在理由是「讓參數看起來不像懸空」(L.422-424)。
但**同一份檔案對 `events` 兩個參數並沒有這樣做**(第 16(b) 項)——
兩個同樣「本張未讀、未來會讀」的參數,一個加了空分支、一個沒加。
**不是錯,但兩種寫法並存會讓下一個讀者以為其中有語意差別。**
建議二選一:要嘛兩處都靠 doc comment 說明(我偏好這個,空分支終究是可執行的無操作),
要嘛統一加註。**零嚴重度,順手即可。**

**是否該回頭修 ADR?—— 🔴 這一處該修,而且是三處裡唯一真正該進 ADR 的。**
理由:(a)(b) 是**實作細節的未定義**,寫在程式碼註解裡就夠;
**(c) 是一條 ADR 明文承諾了、但無法從簽章實現的行為** ——
ADR L.1041 對呼叫方做出了一個承諾(`from_ui_action == true` 會連動權威轉移),
而**這個承諾今天沒有任何程式碼兌現,也沒有任何測試會失敗**。
這不是「未定義邊界」,是**規格與介面不相容**,與 R5-1(乙分支無合法呼叫路徑)、
R6-6(懸空參數)是**同一種病**:ADR 寫了行為,沒寫接線。

**建議的最小修法(不必重開審查)**:在 ADR L.1041 就地補一句,二擇一 ——
① 「`from_ui_action == true` 的權威轉移語意**尚未定義**,待機制六(Story 005)落地後一併定案」;
② 或直接定案為「權威由機制六於 −100 裁定,`set_target()` 不改動權威;
   `from_ui_action` 僅供診斷與稽核」——若採此,`from_ui_action` 的存在意義需一併重新說明。

**急迫性:Story 005 開工前必須決定。** 那張要寫機制六,而機制六正是這個問題的另一端;
**兩邊各自假設對方會處理,就會變成一條沒有人實作的承諾。**

---

#### (d) 🔴 三處共通的真缺口:未定義邊界只寫在「私有側」,呼叫方看不到

這是我看完三處後最想留下的一條。**三處的揭露品質都很好,但揭露的位置都在讀者到不了的地方:**

| 邊界 | 揭露在哪 | 呼叫方讀得到嗎 |
|---|---|---|
| `NO_CURRENT_TARGET` 觸發條件 | `_mark_pending_reresolve_internal()`(**私有**)L.751-757 | ❌ 公開的 `mark_pending_reresolve()` doc(L.448-460)**完全沒提** |
| null → `INVALID_SURFACE_TYPE` | `_validate_target_writable()`(**私有**)L.791-800 | ❌ 公開的 `set_target()` / `handoff_after_mount()` doc **都沒提** |
| `from_ui_action == true` | `set_target()` 主體內(L.422-441) | ⚠️ 在公開方法裡,但在**函式主體**而非 doc comment;doc comment L.410-412 只說「the `true` half is deliberately NOT implemented — see the note in this method's body」——**至少有指路標,三者中最好** |

**後果**:呼叫方系統(戰棋、好感度、存檔)的實作者**只會讀公開 doc comment**,
不會去讀 `_` 開頭的私有方法。他們會拿到 `NO_CURRENT_TARGET` 或 `INVALID_SURFACE_TYPE`
而不知道那可能代表什麼 —— 而 ADR 的核心立場之一正是「絕不靜默、拒絕碼必須可程式化區分」。
**碼是給了,語意沒傳到收件人手上。**

**建議(合計約 8 行,不改任何行為,不動 ADR)**:把三處的結論各摘一句到對應的公開 doc comment,
私有側保留完整推導。**這是本項唯一我認為應該進本張修正清單的東西**,其餘皆可延後。

### 11. `_reclaim` null 策略一致性(6 個呼叫點)與 `ERR_RECLAIM_POLICY_ABSENT` 只 push 一次

**PASS(一致性與單次 push 皆成立)/ 一項不阻擋的營運觀察**

#### (a) 六個呼叫點逐一核對 —— 全數守衛,零遺漏

「六個」的定義域先講清楚:指**對 `_reclaim` 的方法呼叫**。逐一列出:

| # | 行 | 呼叫 | 守衛 | 守衛形式 |
|---|---|---|---|---|
| 1 | L.519 | `_reclaim.reset(..., SURFACE_HANDOFF)` | L.518 | `if _reclaim != null:` |
| 2 | L.600 | `_reclaim.reset(..., FOCUS_LOST_REGAINED)` | L.599 | `if _reclaim != null:` |
| 3 | L.687 | `_reclaim.reclaim_progress()` | L.685 | `if _reclaim == null: return 0.0` |
| 4 | L.727 | `_reclaim.reset(..., SURFACE_HANDOFF)` | L.726 | `if _reclaim != null:`(涵蓋 4+5) |
| 5 | L.729 | `_reclaim.reset(..., TARGET_CHANGED)` | L.726 | 同上 |
| 6 | L.896 | `_reclaim.reset(..., FOCUS_LOST_REGAINED)` | L.895 | `if _reclaim != null:` |

另有 **L.277 `_reclaim.reset_triggered.connect(...)`**,守衛在 L.276。
它是**屬性讀取**(`reset_triggered` 是 signal)而非方法呼叫,故不計入「六個」——
這個讀法是自洽的,見第 12 項。**總計 7 處解參考,7 處全部有守衛。零漏網。**

#### (b) 策略一致性 —— 一致

第 3 項的形式(`== null` 提前回傳中性值)與其餘五處(`!= null` 跳過)寫法不同,
但**這是型別差異強制的,不是不一致**:`reclaim_progress()` 回傳 `float`,必須給出一個值;
其餘五處回傳 `void`,可以什麼都不做。兩者的策略是同一條:**null → 無副作用 + 中性結果**。

五處 `void` 守衛的註解**逐字相同**(L.515-517 / 596-598 / 720-722 / 892-894):
「Skipped when `_reclaim` is null - reported once at construction, see `ERR_RECLAIM_POLICY_ABSENT`.
This guard is this file's decision; ADR-0005 has no position on a null `_reclaim`.」
**一致到可以 grep 稽核,這是優點。**

**已獨立查證「ADR-0005 has no position」屬實**:
`grep -n "reclaim.*null\|null.*reclaim" docs/architecture/adr-0005-*.md` → **零命中**。
ADR Key Interfaces L.1375-1376 只宣告 `_init(reclaim: MouseReclaimPolicy, ...)`,
而 GDScript 的物件型別參數本來就接受 `null`,**ADR 既未允許也未禁止**。
實作者沒有虛構一條不存在的 ADR 規定,措辭正確。

#### (c) `_drain_pending_reseed()` 的 null 行為 —— 正確,且值得指出

L.895-897:`_reclaim` 為 null 時跳過 `reset()`,但 **L.897 `_pending_reseed = false` 在守衛之外、
無條件執行**。這是對的 —— 若把清旗標也包進守衛,`_pending_reseed` 會在無政策時
**永久停在 `true`**,雖然無害卻會讓診斷失真。實作者把它放在外面,判斷正確。

#### (d) `ERR_RECLAIM_POLICY_ABSENT` 只 push 一次 —— **成立**

`grep -n "push_error"` 全檔僅 4 處:L.251 / **L.279** / L.352 / (L.801 是 `assert`)。
`ERR_RECLAIM_POLICY_ABSENT` 只出現在 **L.279**,位於 `_init()` 的 `else` 分支,
**每個實例恰一次**,且不在任何迴圈或每幀路徑上。
L.98-106 的理由(null 是實例的永久屬性、ADR S-4 無熱抽換管道、故答案不會改變)**推理成立**。

#### (e) ⚠️ 不阻擋的營運觀察:這條 `push_error` 今天每次開機都會噴

`cursor_state_host.gd` L.76-81 實際傳 `null`,所以**遊戲每一次啟動都會在 log 印一次紅色錯誤**,
而且會持續到 Story 014 落地為止(依一年計畫,那是很久以後)。

這是刻意的、訊息寫得很好(L.120-129 明確說「Expected while Story 014 is unbuilt」),
**我不建議改掉** —— 改成 `push_warning()` 會弱化它,拿掉則正是 R6-11 要消滅的靜默。

**但請登記一項風險**:一個每次開機都出現、且被文件宣告為「預期中」的紅色錯誤,
會訓練團隊略過開機期的錯誤輸出。本專案已經有過完全同型的教訓 ——
`coding-standards.md` 記載 CI 連續多日全紅、真正的失敗步驟卻無人察覺
(「A red CI is unread until its actual failing step is named」)。
**建議**:在 Story 014 的工作單加一條驗收「本訊息消失」,讓它有明確的到期日,
而不是無限期地成為背景雜訊。

### 12. 類別檔頭 Story 002 舊敘述是否已被推翻並更正

🔴 **CONCERNS —— 受審檔案改對了,但同一句話在隔壁檔案原封不動地活著,而且受審檔案正指著它**

#### (a) `cursor_state.gd` 這一半:**PASS,而且改得很好**

L.41-56 已把 Story 002 的舊句改掉,做法是**保留原句、明確標為已被推翻**:

```
L.42  🔴 [b]Story 007 invalidated what this line used to say.[/b] It read
L.43-45  "nothing built so far ever calls a method on [member _reclaim], so a null
         collaborator is safe here" — that was true when Story 002 wrote it and is
         now false: this class calls [member _reclaim] from six places.
```

**這是正確的做法**(不是抹掉,是留下可追溯的更正),且逐項查核**敘述正確**:

- **「calls `_reclaim` from six places」= 對。** 實測方法呼叫恰 6 處
  (L.519/600/687/727/729/896,見第 11 項)。L.277 的 `_reclaim.reset_triggered` 是
  **屬性讀取**不是方法呼叫,不計入 —— 這個讀法與句子的措辭(“calls … a method on”)一致。
- **「reported once at construction」= 對**(L.279,見第 11 項 (d))。
- **「every call site a no-op」= 對**(7 處全守衛)。
- **「`reclaim_progress()` returns `0.0`」= 對**(L.685-686)。
- **「ADR-0005 takes no position on it」= 對**(ADR 全文零命中,已獨立 grep)。
- **「no test can catch that: unit tests inject a working test double, so only a real run
  exercises the null」= 對,而且是本檔最有價值的一句自白。**

#### (b) 🔴 但 `src/ui/cursor/cursor_state_host.gd` **L.20-22 仍寫著那句已被推翻的話**

```
L.19-22  This host therefore constructs [CursorState]
         with [param reclaim] [code]null[/code]. This is safe for THIS story only
         because nothing built so far ever calls a method on
         [member CursorState._reclaim];
```

**這句話今天是假的。** 本張新增了 6 個對 `_reclaim` 的方法呼叫,
它所主張的「安全理由」已經不存在了。系統目前仍然安全,
但**是靠新寫的 7 個 null 守衛安全的,不是靠「沒有人呼叫」安全的** —— 理由整個換掉了。

**為什麼這比一般的過時註解嚴重:受審檔案主動把讀者導向這裡。**
`cursor_state.gd` **L.38-40** 寫:

```
Story 014 adds the concrete [MouseReclaimPolicy] subclass; until then
[code]CursorStateHost[/code] constructs this class with [param reclaim]
[code]null[/code] (see that file's doc comment).
```

「**see that file's doc comment**」—— 而那份 doc comment 說的正是被本張推翻的舊理由。
一個照著交叉引用走的讀者,會從一份已更正的文件被送進一份未更正的文件,
**並且不會有任何跡象告訴他哪一份是新的。**

這**正是** `docs/consistency-failures.md` 登記的模式:同一項事實的兩份副本,
只更新了其中一份。差別在於這次兩份副本相距**同一個目錄下的兩個檔案**,
而且新的那份還附了指路標。

#### (c) 判定與建議

- `cursor_state.gd` 本身:**PASS**。
- 本項整體:**CONCERNS**,**不阻擋**(是註解錯誤,不是程式錯誤;執行期行為完全正確)。
- **必修,成本極低**:把 `cursor_state_host.gd` L.20-22 的理由換成現況 ——
  「安全的理由不再是『沒有人呼叫』,而是 `CursorState` 對 null `_reclaim` 有一致的守衛策略,
  見 `ERR_RECLAIM_POLICY_ABSENT`」。**約兩行。**

⚠️ **範圍聲明**:`cursor_state_host.gd` **不在派工單列出的受審檔案內**。
我把它寫進報告,是因為它是本項(第 12 項)問題的另一半,而且是受審檔案的交叉引用目標 ——
**不修它,第 12 項就沒有真正完成。** 請由工作單擁有者決定要不要納入本張。

---

#### ✅ (d) 狀態更新:**已於本次覆核期間修正(主 session 執行,非本覆核者)**

**2026-09-03,主 session 在收到本項判定後親自查證屬實並修改了 `src/ui/cursor/cursor_state_host.gd`。**
據其回報:舊句零殘留;新文字**保留原句供追溯**,並寫明現行處置
(建構時 `push_error` 一次 + 每個呼叫點守衛 + `reclaim_progress()` 回 `0.0`),
以及「ADR 對 null `_reclaim` 無立場」。

🔴 **本項因此不列入結案待辦。** 原 CONCERNS 判定成立且已被採納 —— 那是一個真的缺陷,
只是它的生命週期在本次覆核之內就結束了。

⚠️ **範圍聲明(重要)**:上述修正**由主 session 完成,本覆核者未讀過修改後的檔案內容**
(依派工「不要修改任何程式碼」,我也未回頭複驗)。
**故此處記載的是「已回報修正」,不是「已複驗修正正確」。**
若需要後者,應由下一次覆核或測試端獨立確認。

### 13. AC-1 排除名單放寬幅度(`state_host_test.gd`)

**PASS —— 六個理由逐個成立(其中一個較弱但可辯護),且新名單有存在性斷言釘死**

#### (a) 有沒有存在性斷言?**有,而且是本次改動品質最高的一處**

**L.203** `test_ac1_known_mechanism_fields_are_excluded_from_the_state_field_count_by_design()`
逐字斷言六個名字都真的存在於腳本上(L.219-223)。

L.204-211 的註解說明了它防的兩個失效方向,**兩個都是真的會發生的**:

1. **打錯字或改名 → 排除項匹配不到任何東西 → 該欄位重新出現在殘集裡 →
   AC-1 以「看起來像是真的多了第四個狀態欄位」的方式紅燈** —— 除錯方向會被帶偏。
2. **欄位刪掉後排除項留在原地 → 永久預先核准一個沒人在看的名字。**

第 2 點尤其重要:排除名單的危險從來不是它現在錯,而是它**日後悄悄鬆掉**。
這條斷言把「名單條目」與「真實欄位」綁成雙向,是正確的做法。
同型斷言在 L.190 已對兩個協作者欄位做過,**新增的六個沿用同一紀律,不是特例通融。**

#### (b) 六個理由逐個判定

| 欄位 | 理由(L.143-160) | 我的判定 |
|---|---|---|
| `_mutation_in_progress` | 控制流,只在公開入口自身呼叫**內**為真,任何呼叫者能觀察到時恆為 false | ✅ **成立**。已由第 4 項獨立驗證:七個入口的升旗/落旗成對,無 `await`、無 `call_deferred`,故不跨越呼叫邊界。⚠️ 但這句話的成立**依賴閘門內不發生 abort** —— 見第 4 項 Q1。abort 一旦發生,它就永久為 true 且外部可觀察。**理由本身正確,但它的前提正是第 4 項那個未關閉的洞** |
| `_pending_reseed` | R6-10 的 note-to-self,同一次呼叫返回前必被 drain,不跨呼叫存活 | ✅ **成立**。已由第 6 項獨立驗證:七個入口全部在落旗前 drain,drain 內 L.897 無條件清旗標 |
| `_provider_error_reported` | 一次性 latch,log 記帳 | ✅ **成立**。L.204/347-352,只影響是否 `push_error`,不影響任何回傳值或訊號 |
| `_last_mouse_position` | 供應者上次回傳座標的快取(S-1 回退),衍生自注入的協作者,不是游標目標 | ⚠️ **成立但為六者中最弱的一個 —— 見下** |
| `diagnostic_reentrant_rejection_count` | QA-only 計數,機制十五慣例,下游不得依賴 | ✅ **成立**。L.216 的欄位註解逐字寫明此約束,與 ADR-0002 `diagnostic_visited_count` 同慣例 |
| `diagnostic_invalid_mouse_provider_count` | 同上 | ✅ **成立**(L.221) |

**關於 `_last_mouse_position` 為何較弱**:它是六者中唯一同時滿足三個條件的 ——
(i) **跨呼叫存活**(L.841 寫入,下次呼叫仍在);
(ii) **會被讀回**(L.839 在供應者失效時回傳它);
(iii) **影響可觀察行為**(它決定了失效期間 `_reclaim.reset()` 拿到的播種座標)。
另外五個沒有一個同時滿足這三點。理由裡「owned by no one here」這句**不精確** ——
它確實由本類別擁有並賦值(L.841)。

**但排除仍然正確**,理由要換一個:AC-1 的定義域是
**GDD Core Rules #1 的三個頂層狀態欄位**(目標 / 裝置權威 / 累積淨位移),
而 `_last_mouse_position` 不是其中任何一個 —— 它是「`RefCounted` 核心沒有場景樹、
只能經注入 `Callable` 取座標」這個架構選擇的**實作產物**,
在 ADR 沒有引入 `mouse_position_provider` 之前根本不會存在。
**建議把測試註解 L.152-155 的理由改成這個**(不改行為,只改理由),
因為現有措辭若被日後引用,會讓人以為「有快取的欄位都可以排除」。

#### (c) 放寬幅度的誠實評估

排除名單由 **2 個 → 8 個**;腳本上的屬性總數為 **11**(3 狀態 + 2 協作者 + 6 機制)。
亦即 **AC-1 現在要過濾掉 8/11 才看到它要檢查的 3 個。**

**但防護沒有結構性弱化,關鍵在於名單是「逐名列舉」而非「樣式比對」**:

- 若寫成 `if property_name.begins_with("diagnostic_")` 或 `_` 開頭一律跳過,
  **那才是真的放寬** —— 未來任何新欄位只要取對名字就自動隱形。
- 現在的形式下,**任何新增欄位都會讓 AC-1 立刻紅燈**,除非有人明確把名字加進 L.162 的陣列。

🔴 **所以 AC-1 現在的實際保護等級要講清楚,不要高估**:
它已經**不是**「自動偵測到有人偷加狀態欄位」,而是
**「有人偷加狀態欄位時,他必須在同一個 diff 裡明確地把名字加進一份排除名單」**。
擋下它的**是程式碼審查,不是測試**。測試的貢獻是**強迫這件事在 diff 裡顯形**,無法被略過。

這仍然有價值(而且是本專案偏好的形狀:讓省略表現成可見的東西),
**但它的強度取決於有沒有人看 diff。** 建議把這句話寫進測試的類別註解,
免得後續有人以為 AC-1 是全自動防線。

#### (d) 順帶認可一項正確的引擎處理

L.169-175 過濾 `PROPERTY_USAGE_CATEGORY`:`Object.get_script_property_list()` 會回傳一個
以腳本檔名為 `name` 的合成分類標頭(給編輯器 Inspector 當區段標籤用),
不過濾就會被當成「第四個欄位」。

**這是真的 Godot 陷阱,不是防禦性冗餘**,而且註解誠實記載它是
「Verified directly during this story's own test run (first attempt failed with exactly this
extra entry)」—— **實測得來、寫明來歷。符合本專案 (A) 級的舉證要求。**

### 14. 探針 `prototypes/story-007-gdscript-probe-2026-09-03/` 的 log 與 (A) 級標示誠實度

**PASS(有真實 log、揭露到位)/ CONCERNS(「(A) 級」這個標籤本身,但問題出在分類法有缺口,不在本探針)**

#### (a) 有沒有實際 log?**有,而且是真的跑出來的**

`prototypes/story-007-gdscript-probe-2026-09-03/` 共 4 個檔:
`README.md`、`probe.gd`、`project.godot`、`logs/probe_output.txt`。

`logs/probe_output.txt` 逐字:

```
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

PROBE1 signal.emit-as-Callable forward -> seen=42
PROBE2 get_script_property_list -> ["Built-in script|usage=128", "_plain|usage=4096",
                                    "_vec|usage=4096", "diagnostic_n|usage=4096", "_e|usage=4096"]
PROBE3 CAT flag = 128
```

**判定為真實輸出而非手打**,依據三點:
① 帶引擎版本橫幅且含 commit hash `a13da4feb`,與專案釘死的 4.7.1 相符;
② `usage=4096`(`PROPERTY_USAGE_SCRIPT_VARIABLE`)與 `128`(`PROPERTY_USAGE_CATEGORY`)
是引擎內部數值,PROBE3 另外把 `128` 獨立印出來自我佐證;
③ `probe.gd` 的 `print()` 格式與 log 逐字對得上(我逐行核對過)。

**兩項結論都直接支撐了實作決定,不是好奇心**:
① `Signal.emit` 可當 `Callable` → `cursor_state.gd` L.277 的純轉發寫法成立,
   免掉第七個底線方法(保住 VC #13 的「恰六條私有路徑」不變式);
② `get_script_property_list()` 只回 `var` 且**額外多一筆分類標頭** → AC-1 反射測試的
   排除名單必須擴充、且必須過濾 `PROPERTY_USAGE_CATEGORY`(見第 13 項 (d))。
   `const` / `enum` / `signal` 不出現 → 本張新增的 3 個 enum、3 個 const、3 個 signal **不影響 AC-1**。
   **這一項是「先量到、才動手」,README 自己也是這樣寫的 —— 順序正確。**

#### (b) README 是否誠實標明「獨立空專案、非執行本專案類別」?**有,逐字驗證如下**

我不接受自述,以下是 README 的原文(第 5-6 行):

> **執行方式**(本探針是**獨立空專案**,不掛本專案任何程式碼;因此它驗證的是**引擎行為**,
> 不是本專案的類別 —— 依 `technical-preferences.md` 的 (A) 級定義,這一點必須明講)

**三個必要元素全部具備,措辭無模糊空間**:
「獨立空專案」✅、「不掛本專案任何程式碼」✅、「不是本專案的類別」✅,
並且**主動點名 (A) 級定義**,而非等人來問。
`project.godot` 只有 4 行(`config/name="probe"`)、`probe.gd` 全部自帶 class,
**實測與敘述相符 —— 它真的沒有引用本專案任何東西。**

`technical-preferences.md` 要求的
「🔴 凡文件裡寫下『(A) 級』,必須同時附上它實際執行的那支檔案的路徑」
**亦已滿足**:README 給出完整可重跑指令(含引擎絕對路徑、`--headless`、`-s probe.gd`)。

#### (c) 🔴 但「(A) 級」這個標籤本身站不站得住?—— 我的判斷:**分類法有缺口,不是探針有錯**

README 開頭寫「對兩項引擎行為做 **(A) 級實機驗證**」。**按 `technical-preferences.md` 的字面,
這個標籤不成立** ——(A) 級的判準逐字是「引擎必須執行過**專案自己的程式碼**」,
而本探針執行的是探針自己寫的 `Emitter`/`Relay`。

**但我認為照字面降級是錯的,理由是那條規則的定義域不涵蓋這種量測:**

(A) 級那條規則的成因寫得很清楚 —— 它防的是
**「腳本自行重新實作了一份專案規則,然後把跑出來的數字當成實測發布」**
(2026-08-31 的 awk 棋盤量測:腳本假定 `#` 不可通行,而 `board.gd` 的 `MOVE_COST` 根本沒有
「不可通行」這個概念,三個數字全錯)。

**本探針裡沒有任何一條專案規則被重新實作。** 它問的兩個問題
(「`Signal.emit` 能不能當 `Callable`」「`get_script_property_list()` 回傳什麼」)
**真值來源就是引擎本身**,不存在「專案的版本」與「探針的版本」兩份可能分歧的實作。
把專案類別塞進去也不會讓答案更真 —— 只會讓探針更慢、更容易受無關因素干擾。

**這是 `technical-preferences.md` 自己登記的「兩項刻意未定義的邊界」之外的第三種未涵蓋情況。**
該檔已誠實記載三分法對「混合情況沒有等級可標」,現在再多一種:
**「引擎行為量測」既不是 (A)(沒跑專案程式碼)、也不該是 (C)(它確實是實機量測、有 log、可重跑)。**

**建議(呈管理者):** 不要求本探針改標,改為在 `technical-preferences.md` 補一句釐清 ——
> 量測對象是**引擎行為本身**(而非專案規則的計算結果)時,獨立最小專案的實機量測**視為 (A) 級**,
> 但必須明文標示「非執行專案類別」。判準是:**這次量測有沒有重新實作任何一條專案規則?**
> 有 → 逐條降級;沒有(真值來源是引擎)→ (A) 級成立。

急迫性:**低,下次有人寫探針時順手補即可。** 本探針的揭露已經足夠,
讀者不會被誤導 —— 它明講了自己是什麼。

#### (d) 一項技術上的細節,值得記下來(不影響判定)

探針的結論 ② 是在**內部類別 + built-in script** 上量的
(log 的分類標頭 `name` 是 `"Built-in script"`),而真實的 `cursor_state.gd` 是
**頂層 `class_name` 腳本**,其分類標頭 `name` 是檔名 `"cursor_state.gd"`
(見 `state_host_test.gd` L.170-172)。**兩者的 `name` 不同,是同一件事的兩個情境。**

**結論仍然可轉移**,因為過濾條件寫的是 `usage & PROPERTY_USAGE_CATEGORY`(L.176)而非比對名稱 ——
**這是實作者選對了過濾維度,不是運氣。** 若當初寫成比對名稱等於檔名,探針的結論就轉移不過去。

另外要指出:**結論 ② 在真實類別上的證據其實比探針更強** ——
`state_host_test.gd` L.173-174 記載該過濾是在「this story's own test run (first attempt failed with
exactly this extra entry)」中撞到並修正的,那**才是**跑了專案自己程式碼的 (A) 級證據。
探針的價值在於**它先發生**,讓這件事不是靠紅燈才發現。

#### (e) 一項零嚴重度的整潔問題

`probe.gd` 倒數第 3 行 `var t: int = 0` **宣告後從未使用**。
無害(拋棄式探針、不進 `src/`),但既然本張正在清算「懸空參數」這種形狀(第 16(b) 項),
順手提一句。**不必為此改動。**

### 15. 兩處「刻意未實作」的切法判定 + 兩個未實作方法的歸屬

**(a) 切法:PASS —— 切在正確的接縫上。但接縫的「位置」放錯了一處,見 (c)。**
**(b) 結案文字:🔴 不能寫「七個公開入口完成」。正確寫法見 (d)。**
**兩個未實作方法(`force_redraw_current_authority` / `reapply_native_cursor_visibility`):PASS,不做是對的。**

#### (a) 這個切法對不對?—— 對,而且是唯一正確的切法

`arbitrate_device_authority`(L.315-355)與 `apply_buffered_navigation`(L.374-396)實測內容:
閘門檢查 + 診斷計數 + 升旗 + (前者多一個 provider 前置檢查)+ 標記接縫的 `pass` + drain + 落旗。
**確為接縫,無任何寫入。** 與測試端實機讀出的結論一致(我獨立讀程式碼所得,非採信該結論)。

**判定「切對了」的四條依據:**

1. **ADR 的機制邊界本來就切在這裡。** 機制十(本張)定義的是
   *閘門、七個入口的存在與簽章、六條私有路徑、讀取介面*;
   機制六(Story 005)定義的是*仲裁決定什麼*。ADR L.936-943 的兩類路徑表列的是**入口本身**,
   不是入口的決策內容。**本張交付的是機制十,不是機制六。**
2. **工作單自己的 Implementation Notes 第 1 條逐字是「七個公開入口掛重入閘門」** ——
   交付物是*掛閘門*,不是*仲裁邏輯*。這一條本張 7/7 做到。
3. **相依方向支持這個切法。** 工作單 L.118 `Unlocks: 005, 008, 009, 011`,
   即 **Story 005 依賴本張**。若本張不先產出帶閘門的空殼入口,Story 005 無處可填 ——
   **接縫是本張的交付物之一,不是本張的欠債。**
4. **現在硬寫主體會是本專案已登記的失效模式。** 機制六需要 Story 005 的
   frame-buffered 時序(`_frame_events` 收集、四步定序、`process_priority` 分層),
   那些東西**現在不存在**。憑推測寫下去會「順利跑完、輸出漂亮數字、看起來完全正常」——
   `technical-preferences.md` 明文記載的那個形狀。

**接縫標記本身的品質也夠格**(這是我願意判 PASS 的關鍵):
L.331-343 與 L.382-394 兩處不是 `# TODO`,而是列出了
*該填什麼*、*不得做什麼*、*為什麼*。尤其 L.388-392 逐字寫明
「**NEVER via `set_target()`**. That is R4-4 verbatim: the latch is already up by this line」——
**把 ADR 花兩輪審查才抓到的自我死鎖,預先釘在了它最可能復發的那一行上。**
這比實作一個猜的主體有價值。

#### (b) 另兩個未實作方法 —— 不做是對的,依據已存在且我已複核

| 方法 | 歸屬 | 判定 | 依據 |
|---|---|---|---|
| `force_redraw_current_authority()` | 機制九 → **Story 008** | ✅ 不做正確 | ADR Key Interfaces **L.1424** 註記 `# AC-30`;AC-30 屬機制九 |
| `reapply_native_cursor_visibility()` | 機制十三之二 → **Story 011** | ✅ 不做正確 | `docs/reviews/story-dependency-audit-2026-09-03.md` **L.123-139**,五條證據,已於本日上午查證關閉並更正 `story-008` / `story-011` 的相依欄 |

⚠️ **但要指出一個會反覆咬人的結構事實**(該稽核 L.144-146 已登記,我在此複述是因為本張正好踩到):
**ADR Key Interfaces 的 `cursor_state.gd` 區塊(L.1373-1433)把六個查詢方法列在一起,
卻橫跨機制十(007)、機制九(008)、機制十三(011)三張工作單,而 ADR 裡沒有任何一張總表說明
哪張寫哪個。** 只讀 Key Interfaces 的人會合理推論本張欠了兩個方法。
**本次是靠一份當日的相依稽核才問清楚的,不是靠文件結構。**

#### (c) 🔴 一個真正的缺陷:接縫的**位置**放錯了,會讓 Story 005 寫出「跑得順但是錯」的東西

`arbitrate_device_authority()` 的接縫(L.331-343 的 `pass`)被放在
**`if _mouse_position_provider.is_valid():` 的 true 分支裡面**(守衛在 L.330)。

而該接縫註解自己列出的待填內容(L.333-338)包含:

> eligibility filtering (**NAVIGATION-class `ui_*` from keyboard/gamepad**; …),
> the fixed **KEYBOARD_GAMEPAD-beats-MOUSE priority**, **writing `_device_authority` and
> emitting `device_authority_changed()`**, plus the AUTHORITY_TRANSFER (a) and VETOED_SAME_FRAME (d) reset calls.

**亦即:鍵盤/手把的仲裁被放進了「滑鼠座標供應者有效」這個條件底下。**

**這與同一個檔案裡的承諾直接矛盾。** `ERR_MOUSE_PROVIDER_INVALID_RECLAIM_DISABLED`(L.83-89)逐字寫:

> "Mouse-reclaim arbitration is DISABLED for the rest of this CursorState's lifetime
> (**keyboard/gamepad arbitration is unaffected**)."

**也與 ADR 的原意矛盾。** ADR **L.852** 逐字:

> `· false → **整段跳過 evaluate() 路徑**(滑鼠奪權停用)`

ADR 要停的是 **`evaluate()` 那條路徑**(滑鼠奪權),**不是整個仲裁**。

**後果(若 Story 005 照現在的縮排把主體填進去)**:滑鼠供應者一失效,
**鍵盤與手把的裝置權威仲裁一併停止** —— 玩家用手把完全無法取得權威,
`_device_authority` 永遠停在當下的值。而 `push_error` 只會說一次「滑鼠奪權停用」,
訊息本身還明說鍵盤/手把不受影響。**除錯的人會照著那句話去找別的地方。**

⚠️ **這是本項最值得帶走的東西:接縫的縮排層級本身就是一項規格。**
放錯一層,不會有任何編譯錯誤或測試紅燈(主體是 `pass`),
但它已經把一個錯誤的結構決定寫進了下一張工作單的起點。

**建議修法**(不阻擋本張,但**必須在 Story 005 開工前**處理):
把接縫拆成兩段 —— 鍵盤/手把的資格判定與優先序**在 `if` 之外**無條件執行;
只有 `_reclaim.evaluate()` 那一小段留在 `is_valid()` 的 true 分支內。
或至少在接縫註解裡明文寫出這條約束,讓 Story 005 的實作者不必自己發現。

#### (d) 結案文字該怎麼寫才不算灌水

🔴 **不可以寫「七個公開入口完成」。** 那句話字面為真(七個都存在、都掛了閘門)、
**實質會誤導**——讀的人會以為游標系統的仲裁能跑了,而它一行都還沒有。

**建議的結案措辭(可直接採用):**

> **Story 007 交付機制十的結構層,7/7 個公開入口具備閘門、診斷與 drain 義務。**
> 其中 **5 個入口的行為主體完成**(`set_target`、`mark_pending_reresolve`、
> `handoff_before_unload`、`handoff_after_mount`、`reseed_reclaim_on_focus_regained`);
> **2 個入口的行為主體屬機制六,由 Story 005 填入**
> (`arbitrate_device_authority`、`apply_buffered_navigation`)——
> 本張已就位其存在、簽章、閘門、診斷計數、provider 前置檢查與接縫約束。
> **六條私有路徑 6/6 完成、讀取介面 4/4 完成。**
> 🔴 **AC-32 無法由本張滿足**(它要求的是機制六的導覽套用行為),
> 已由測試端記為缺口警報器而非以其他路徑湊涵蓋。

**兩個數字都要出現(7/7 結構、5/7 主體),缺任何一個都會失真。**

#### (e) 🔴 同型複本問題(依指示標出)—— 工作單自己內部就有一組

這是今天第**四**次同一種毛病:**同一項事實的兩份副本只更新了一份。**

`production/epics/cursor-highlight-state/story-007-write-read-interface.md`:

| 位置 | 寫了什麼 | 狀態 |
|---|---|---|
| **L.118** `Unlocks` | `**005**, **008**, 009, **011**` | ✅ 2026-09-03 相依稽核**已補上 005** |
| **L.55-56** `Out of Scope` | 只列 `Story 009`、`Story 014` | 🔴 **完全沒提 Story 005 / 機制六** |

**同一份檔案裡**,一處說「005 依賴我」,另一處在列本張不做什麼時**漏掉了本張最大的一塊不做**。
`grep -n "005\|機制六"` 對這份工作單的命中全部落在 L.17/39/102/118/120,
**`Out of Scope` 區塊零命中。**

**後果具體**:結案覆核者翻到 `Out of Scope` 想確認「兩個空殼入口是計畫內的嗎」,
會**找不到任何背書**,只能從程式碼註解推斷 —— 而那正是「刻意不做」與「漏做」
在文件上無法區分的情形。**建議在 `Out of Scope` 補一行:
「Story 005:機制六的仲裁決策與 frame-buffered 時序(本張只出兩個入口的閘門與接縫)」。**
與現有兩行(009 只出入口本體、014 的 `_reclaim` 具體策略)**同一句型**,零爭議。

### 16. 實作者自陳兩項發現的複核

### 16(a) Validation Criteria #16(iv) 是否已過期?—— **確認過期。CONCERNS(文件層)**

#### 逐步追出來的實際行為

VC #16(iv)(ADR **L.1637**)逐字要求:

> **重入向量(專家發現 D)**:於 `target_changed()` 的處理函式內同步呼叫
> `CursorStateHost.resume_arbitration()`,斷言 `_reclaim` 在該次外層寫入內**只被 reset 一次**、
> 且 `diagnostic_reentrant_rejection_count` 遞增。

以 `set_target(t, false)`(目標確實改變)為外層寫入,**逐行走一遍現行程式碼**:

| 步驟 | 行 | 發生什麼 |
|---|---|---|
| 1 | L.415→417 | 閘門通過,`_mutation_in_progress = true` |
| 2 | L.419 | `_validate_target_writable()` → `APPLIED` |
| 3 | L.420 → L.711-713 | 存舊值、寫新值、`changed = true` |
| 4 | L.726→729 | **`_reclaim.reset(…, TARGET_CHANGED)` ← 第 1 次 reset** |
| 5 | L.734-735 | `target_changed.emit()` —— **下游處理函式在此同步執行** |
| 6 | L.587→591-593 | 轉發進 `reseed_reclaim_on_focus_regained()`,閘門仍為真 → **`_pending_reseed = true`**、計數 +1、return |
| 7 | L.444 → L.884→896 | `_drain_pending_reseed()` → **`_reclaim.reset(…, FOCUS_LOST_REGAINED)` ← 第 2 次 reset** |
| 8 | L.897 / L.445 | `_pending_reseed = false`;落旗 |

**`_reclaim.reset()` 在該次外層寫入內被呼叫了兩次,且是兩個不同的 `ResetTrigger`。**
**VC #16(iv) 的「只被 reset 一次」現在必然為假 —— 實作者的宣稱成立。**

**過期原因**:VC #16 寫於 2026-08-19(第三次修訂),當時發現 D 的修法是
「掛閘門,重入即整段 no-op」→ 重新播種**被丟棄** → 全程只有 1 次 reset。
**R6-10(2026-08-21,第四次修訂)把「丟棄」改成「記下來、稍後補做」**,
第 2 次 reset 是那次修法**刻意加進去的**。VC #16 沒有同步更新。

🔴 **後果正是派工單擔心的那個**:照 L.1637 字面寫測試的人會斷言「reset 恰一次」,
拿到一條**紅燈**,然後很可能去「修好」一個其實正確的實作 ——
把 R6-10 的補做拆掉,**靜默地把 R6-10 要修的缺口重新打開**。

#### 🔴 正確的期望值應該是什麼(這是本項要交付的東西)

**⚠️ 先講一個關鍵陷阱:正確的次數不是固定的「兩次」,它取決於外層是哪一個入口。**
把 (iv) 改寫成「斷言 reset 兩次」**同樣會錯**,只是錯在別的向量上。

| 外層入口 | 寫入路徑自己的 reset | drain 補做的 reset | **總次數** |
|---|---|---|---|
| `set_target()`(目標改變) | `TARGET_CHANGED`(L.729) | `FOCUS_LOST_REGAINED`(L.896) | **2** |
| `handoff_after_mount()` | `SURFACE_HANDOFF`(L.727,UNCONDITIONAL) | 同上 | **2** |
| `handoff_before_unload()` | `SURFACE_HANDOFF`(L.519) | 同上 | **2** |
| `mark_pending_reresolve()`(有效性翻轉發訊號) | **無** —— `_mark_pending_reresolve_internal()`(L.746-777)**不呼叫 `_reclaim.reset()`** | 同上 | **1** |
| `set_target()`(目標未改變 → 不發訊號) | 無 | 不會被觸發(下游沒收到訊號) | **0** |

**建議把 (iv) 改寫成三條斷言,前兩條取代原本的次數斷言:**

1. **順序與觸發點,而非次數** ——
   斷言 `reclaim_reset_triggered` 收到的**最後一個** trigger 是
   `CursorTypes.ResetTrigger.FOCUS_LOST_REGAINED`,且它發生在
   `target_changed` **之後**、外層入口回傳**之前**。
   (這條抓的是 R6-10 真正要保證的事:被擋下的重新播種**確實補做了**,而且補在寫入落定之後。)
2. **不變式取代計數** —— 🔴 **發現 D 真正要保護的從來不是「只 reset 一次」,
   而是「絕不在 `_target` 處於半寫入狀態時 reset」。** 建議直接斷言這一條:
   **任何一次 `_reclaim.reset()` 發生時,`_write_target_internal()` 都已經完整返回。**
   R6-10 加的第 2 次 reset **不違反**這條(它在 L.444 的 drain 裡,`_write_target_internal` 早已返回);
   而發現 D 原本要防的那次會違反(它會落在 `_write_target_internal()` 執行到一半的中途)。
   **這條在 R6-10 前後都成立,不會再過期一次 —— 這是我建議它的主要理由。**
3. **原有的計數斷言維持不變** ——
   `diagnostic_reentrant_rejection_count` 遞增 **恰 1**(L.592)。這一半沒有過期。

另建議加一條收尾斷言:外層入口回傳後 **`_pending_reseed == false`**(L.897 保證),
否則一次漏掉的 drain 會讓下一個入口莫名其妙地多做一次重新播種。

#### 急迫性

**現在就該修 ADR 的 (iv)** —— 但這是**四項 ADR 文件層修正裡最急的一項**,理由是
**它是唯一一個會主動製造錯誤行為的**:另外三項(見總結表)只是讓人漏檢或查錯地方,
而這一項會讓一個照規矩辦事的人**去破壞一個正確的實作**。
Story 005 與 Story 014 都會碰到這條向量。

---

### 16(b) `events` 參數是否為 R6-6 剛清算過的「懸空參數」形狀?

**判定:形狀相同,實質不同 —— 不應比照 R6-6 刪除。PASS,但附一項具體建議。**

實測:`events: Array[InputEvent]` 出現在 L.315 與 L.374 兩個簽章,
**全檔從未被走訪、索引或解參考**(見第 17 項)。字面上確實是「宣告了但沒讀」。

**但與 R6-6 的 `surface` 參數有一個決定性差異:有沒有已知的未來讀取者。**

| | R6-6 刪掉的 `handoff_before_unload(surface)` | 本張的 `events` |
|---|---|---|
| 未來會不會被讀? | **不會** —— ADR L.~880 逐字判定它「當守衛則 `MarkResult` 沒有任何值能表達『表面不符』」,**在原理上不可實作** | **會** —— 接縫註解 L.333-334 明確指定 Story 005 用它做 eligibility filtering |
| 語意明確嗎? | **不明確**,ADR 說它是「誘導實作者猜語意的介面面」 | **明確**,且 L.339-342 連「不准用它挖座標、座標一律走 `_safe_mouse_position()`」都先寫死了 |
| 是否在凍結契約內? | 是,但 ADR **主動修訂**刪除 | **是** —— Key Interfaces L.1385-1386 凍結了這兩個簽章。刪掉等於改契約,而且 Story 005 得再加回來 |

**結論:留著是對的。** 刪除會製造一次無意義的簽章翻動,並違反凍結的 Key Interfaces。

⚠️ **但 R6-6 的教訓仍有一半適用**:讀者無法從簽章分辨「還沒讀」與「不該讀」。
本檔的緩解是接縫註解,但**兩個方法的 doc comment 都沒有一句直白的
「`events` 在本張未被讀取,由 Story 005 讀」**——那句話目前只能從接縫註解裡推。
**建議各加一行**,成本一行,讓靜態閱讀者不必進到函式主體才搞清楚。

#### 🔴 而查這一項時,順手抓到同型問題的第五次發作

依指示標出。**本檔 L.188-189 兩個欄位的 doc comment 各有一句話今天已經是假的:**

```
L.188  var _registry: CursorSurfaceRegistry   ## …; unread in this story
L.189  var _mouse_position_provider: Callable ## …(S-1) — unread in this story
```

**實測兩者在本張都被讀了:**

- `_registry` → **L.814** `_registry.get_surface(target.surface)`
- `_mouse_position_provider` → **L.330** `.is_valid()`、**L.837** `.is_valid()`、**L.840** `.call()`

這兩句是 Story 002 寫的(當時「this story」=Story 002,敘述為真),
**Story 007 讀了它們卻沒更新這兩行。**

**這與第 12 項是完全同一個病、同一個檔案、相隔 150 行。**
第 12 項的舊句被**正確地**標記為已推翻(L.42-45),而**同一次改動漏掉了 L.188-189**。
⚠️ **`_registry` 那一行還特別諷刺**:它自己寫著
「needed by Story 007's `_validate_target_writable()`」——
**同一行裡先說「Story 007 會用到」,再說「本張未讀取」。**

**建議**:兩行的 `unread in this story` 改為指出實際讀取點
(`_registry` → `_validate_target_writable()` L.814;`_mouse_position_provider` → `_safe_mouse_position()`
與 `arbitrate_device_authority()` 的前置檢查)。**不阻擋,但與第 12 項應同批修掉。**

### 17. Godot 4.7.1 專屬風險(Input 裝置 ID 重編號 / Control offset transforms)

**PASS —— 兩項 4.7 破壞性變更對本檔皆不成立,其中一項是結構性免疫**

依派工指示,引擎判斷一律取 `docs/engine-reference/godot/breaking-changes.md` 與
`current-best-practices.md`,**不採用停在 4.6 的 `modules/input.md` / `modules/ui.md`**
(該兩份對這兩項變更各自零命中,是 `VERSION.md` 自己標示的查閱死角)。

#### (a) 鍵盤/滑鼠裝置 ID 重編號(4.7)

`breaking-changes.md` **L.11**:
「Input | Keyboard/mouse device ID numbering changed | Code that hardcodes device IDs will break.
Re-verify any custom multi-device input handling.」

**本檔完全不受影響,而且不是碰巧,是結構設計的結果。**

實測:全檔 `InputEvent` 僅出現 **2 次**,都在型別位置 ——
`arbitrate_device_authority(events: Array[InputEvent])`(L.315)與
`apply_buffered_navigation(events: Array[InputEvent])`(L.374)。
**`events` 從未被走訪、從未被索引、其元素從未被解參考。`.device` 全檔零命中。**

這正是禁止樣式 `reading_input_event_device_id` 要達成的效果:ADR-0005 機制四以
**動作語意**(`ui_*` action 的 NAVIGATION 分類)而非裝置 ID 判定權威來源,
故引擎怎麼重編號 ID 都碰不到本系統。**這條免疫是 ADR 層拿到的,本檔只是沒有破壞它。**

⚠️ **但這條免疫是 Story 005 可以打破的。** L.331-343 的接縫註解要求 Story 005 在此
「eligibility filtering (NAVIGATION-class `ui_*` from keyboard/gamepad; …)」——
實作者若圖方便改用 `event.device` 區分鍵盤與手把,免疫立刻失效,而且
**在 4.7 上不會報錯,只會判錯**。建議把這句警告寫進 Story 005 的工作單,不要只留在登記表裡。

#### (b) Control offset transforms(4.7)

`breaking-changes.md` **L.15**:該變更影響「existing menus using containers, tweens, hover
feedback, popups, scroll views, or custom input routing」。

**N/A** —— 本檔是 `RefCounted`(L.60),**不是 `Control`、不在場景樹上、無任何節點或版面 API**。
全檔零 `Control` / `CanvasLayer` / `Viewport` / `get_viewport` / `anchor` / `offset` 命中。

⚠️ **本系統整體仍有此暴露面,只是不在本檔**:機制十三的自繪游標呈現層與
`CursorStateHost` 的 `CanvasLayer` 才是受這條變更約束的地方
(`technical-preferences.md` 已登記的硬性義務「游標圖層必須獨佔一顆 `CanvasLayer`」,
以及 `prototypes/ui-canvas-scale-spike-2026-09-01/` 實測的 1080p 1440px / 2K 2178px / 4K 3304px 誤差)。
**那屬 Story 008/011 的範圍,本張不涉及。**

#### (c) 其他 4.7 面向的順帶查核

- **零 `await` / 零 `call_deferred`**(第 3 項)→ 不受 4.7 任何排程/訊號時序變更影響。
- **`Callable.is_valid()` 對已釋放綁定物件**:本檔的 S-1 防禦押在此(L.837)。
  ADR Verification Required **#15** 曾把它列為必跑 spike,**已於 2026-08-20 實測關閉**
  (ADR L.834-841:具名綁定與 lambda 皆回 `false`、行為一致)。**非 post-cutoff 風險。**
- **`Callable` / `Signal.emit` 當 Callable 傳給 `connect()`**(L.277):
  實作者在 L.261-263 註明已於 Godot 4.7.1 headless 拋棄式探針驗證可行。
  ⚠️ 該探針的性質見第 14 項 —— 就本項而言,這是一個**低風險且結論方向正確**的用法。
- **`assert()` 在 export release 是否被剝離**:**未查證,且本專案查證不了**
  (ADR L.123-127 明文登記為「層 B」,`export_templates/` 為空)。
  這不是 4.7 專屬問題(是 GDScript 一貫行為),但它是第 4 項 Q1 那條 abort 路徑的前提之一,
  **在此重申它仍是未關閉的假設,不要當成已知事實引用。**

---

## 逐項涵蓋範圍回報

**17 項全部查證完畢,無「未查證」項。**

| 項 | 判定 | 項 | 判定 |
|---|---|---|---|
| 1 甲走私有路徑 | ✅ PASS | 10 三處未定義邊界 | ✅ PASS(措辭)/ 見技術判斷 |
| 2 `if`/`elif` + null 守衛位置 | ✅ PASS | 11 `_reclaim` null 一致性 | ✅ PASS |
| 3 零 `call_deferred` | ✅ PASS | 12 類別檔頭 | ⚠️ CONCERNS → **已修正** |
| 4 閘門單一進入/單一釋放 | ⚠️ **CONCERNS** | 13 AC-1 排除名單 | ✅ PASS |
| 5 三個 `void` 入口重入 | ✅ PASS | 14 探針 | ✅ PASS / ⚠️ 標籤 |
| 6 `_pending_reseed` + drain | ✅ PASS | 15 Story 005 接縫 | ✅ PASS(切法)/ ⚠️ **接縫位置** |
| 7 `get_current_target()` 複本 | ✅ PASS | 16(a) VC #16(iv) 過期 | ⚠️ **CONCERNS(確認過期)** |
| 8 `_target_changed_from()` | ✅ PASS | 16(b) `events` 懸空 | ✅ PASS |
| 9 禁止樣式(共查 17 條) | ✅ PASS | 17 Godot 4.7.1 風險 | ✅ PASS |

---

## 🔴 呈管理者裁決:四處文件層不一致(集中列表)

**四處全部是「同一項事實有兩份副本,只更新了一份」。** 沒有一處是程式錯誤 ——
**本張的程式碼在這四處全部選對了邊。** 但每一處都會讓**下一個人**選錯,而且不會報錯。

| # | 哪兩份說法打架 | 位置 | 現行程式碼站哪邊 | 照另一邊做會怎樣 | 建議 |
|---|---|---|---|---|---|
| **1** | 三個 `void` 入口重入時是否「不寫任何欄位」 | ADR **L.934**(說整段 no-op、不寫欄位) vs **L.902-905** R6-10(說要寫 `_pending_reseed`) | ✅ 站 R6-10(較新且較具體) | **重新播種請求被丟棄** —— 正好復現 R6-10 當初要修的缺口,且回傳 `void`,呼叫方無從得知 | L.934 補一句「第三個入口的例外見 R6-10」 |
| **2** | 有幾個入口要呼叫 `_drain_pending_reseed()` | Key Interfaces **L.1408-1414**(七個)vs Validation Criteria **#13(iv) L.1630**(六個) | ✅ 站七個(契約層優先) | 測試只斷言六個,**第七個漏掉不會被抓到** | VC #13(iv) 改為七個 |
| **3** | 禁止樣式管轄幾個公開入口 | 登記表 **L.1930-1933**(列五個) vs ADR R5-1/R5-3(定案七個) | ✅ 七個都沒互相呼叫 | 靜態檢查漏檢 `handoff_after_mount` 與 `reseed_reclaim_on_focus_regained`,**而前者正是 ADR 點名「最可能被拿去借用 `set_target()` 驗證」的那一個** | 登記表 description 補成七個 |
| **4** 🔴**最急** | 重入向量中 `_reclaim` 被 reset 幾次 | Validation Criteria **#16(iv) L.1637**(斷言「只被 reset 一次」)vs R6-10 的實際行為(**兩次,兩個不同 trigger**) | ✅ 站 R6-10 | **拿到一條錯的紅燈,然後很可能去「修好」一個正確的實作** —— 把 R6-10 的補做拆掉,靜默重開缺口 | 見第 16(a) 項:改斷言**順序與不變式**,不要斷言次數(次數隨外層入口而異:2 / 2 / 2 / 1 / 0) |

> **第 4 項與其餘三項的差別要講清楚**:1~3 讓人**漏檢**或**查錯地方**;
> **第 4 項會讓一個照規矩辦事的人主動去破壞一個正確的實作。** 這是唯一一項會製造錯誤行為的。

📌 **另有一處同型問題不在上表,因為它不是 ADR 的**:
`production/epics/cursor-highlight-state/story-007-write-read-interface.md` 的
`Unlocks`(L.118,已補 005)與 `Out of Scope`(L.55-56,**未提 005**)互相矛盾 —— 見第 15(e) 項。

---

## 🔴 「同一句話的其餘複本沒修」—— 本次覆核抓到的發作次數

依指示標出。**本次覆核在四個不同位置抓到同一種病:**

| # | 哪一句 | 已修的那份 | 沒修的那份 | 狀態 |
|---|---|---|---|---|
| 1 | 「沒有人呼叫 `_reclaim`,所以 null 安全」 | `cursor_state.gd` L.42-45(正確標為已推翻) | `cursor_state_host.gd` L.20-22 | ✅ **覆核期間已由主 session 修正** |
| 2 | 「`unread in this story`」 | —— | `cursor_state.gd` **L.188**(`_registry`,實際讀於 L.814)與 **L.189**(`_mouse_position_provider`,實際讀於 L.330/837/840) | 🔴 **未修**。第 16(b) 項。⚠️ L.188 同一行內先說「Story 007 會用到」再說「本張未讀取」 |
| 3 | 「公開入口有五個」 | ADR 已改七個 | 登記表 L.1930-1933 | 🔴 未修(上表第 3 項) |
| 4 | 「`_reclaim` 只 reset 一次」 | R6-10 已改行為 | VC #16(iv) L.1637 | 🔴 未修(上表第 4 項) |

**其中第 1、2 兩項是同一次改動、同一個檔案系列裡漏掉的** ——
Story 007 正確地更新了類別檔頭那一句,卻漏掉了 150 行外的兩個欄位註解,
以及隔壁檔案的同一句話。**這說明「改的時候順手 grep 一次原句」是有回報的:
本次四項裡有三項是靠 `grep` 原句字面抓到的,不是靠讀懂上下文。**

---

## 整體判定:**CONCERNS**

**這是一份品質明顯高於平均的實作。** 我判 CONCERNS 而非 PASS,不是因為它寫錯了什麼 ——
**逐項查下來,程式碼在每一個有爭議的岔路上都選對了邊**,包括四處 ADR 自我矛盾之處。
判 CONCERNS 是因為有**兩件事會讓下一張工作單出錯**(第 4 項的閘門 abort 面、第 15(c) 的接縫位置),
而兩者都不會以紅燈的形式出現。

**做得特別好、值得保留為範例的三處:**

1. **第 4 項 (a)** —— 七個入口的 `return` 形狀零瑕疵,四個有回傳值的一律 `var result` 暫存、
   落旗後才 return。在無 `finally` 的語言裡這是唯一正確的形狀,而且它被貫徹了七次。
2. **第 10 項** —— 三處 ADR 未定義邊界**全部**明文標示、**全部**經我獨立 grep 查證屬實。
   本專案上個月才發生過「註解裡寫著一句不存在的裁決」,**這一輪沒有復發**。
3. **第 13 項 (a) / 第 14 項** —— AC-1 排除名單附存在性斷言、探針附真實 log 與誠實揭露。
   兩者都是「讓省略表現成可見的東西」,符合專案偏好的形狀。

**必須誠實指出的一項限制**:依派工要求,本覆核**完全不以測試結果為依據**,
全部建立在讀程式碼上。因此**執行期行為未經我驗證** —— 我論證的是結構與契約一致性。

---

## 必須修正的項目

### 🔴 阻擋(建議在本張結案前處理)

**只有一項,而且是文字。**

| # | 項目 | 出處 | 為什麼阻擋 |
|---|---|---|---|
| **B-1** | **工作單結案文字不得寫「七個公開入口完成」**,須改為「7/7 結構層 + 5/7 行為主體 + 2 個 Story 005 接縫」,並明列 **AC-32 無法由本張滿足** | 第 15(d) 項(含建議措辭全文) | 字面為真、實質誤導。讀的人會以為仲裁能跑了,而它一行都沒有。**這是結案文件的正確性問題,不是程式問題** |

### ⚠️ 不阻擋,但必修(建議與本張同批,合計約 15 行文字改動)

| # | 項目 | 出處 | 成本 |
|---|---|---|---|
| N-1 | **接縫位置**:`arbitrate_device_authority` 的 Story 005 接縫被放在 `if _mouse_position_provider.is_valid():` **內**,會讓鍵盤/手把仲裁一併停用 —— 與 L.83-89 的承諾及 ADR L.852 皆矛盾。**Story 005 開工前必須處理** | 第 15(c) | 拆兩段,或至少在接縫註解寫明約束 |
| N-2 | **`from_ui_action == true` 的 ADR 承諾無人兌現**(ADR L.1041 明文承諾、無程式碼實作、無測試會失敗)。**Story 005 開工前必須決定**(定案或明文延後) | 第 10(c) | ADR L.1041 就地補一句 |
| N-3 | **VC #16(iv) 已過期**,改為斷言順序與不變式而非次數 | 第 16(a) | ADR 一段 |
| N-4 | **L.188-189 兩句 `unread in this story` 已為假** | 第 16(b) | 兩行 |
| N-5 | **三處未定義邊界的結論摘一句到公開 doc comment**(呼叫方讀不到私有側) | 第 10(d) | 約 8 行 |
| N-6 | 其餘三處文件不一致(ADR L.934、VC #13(iv)、登記表 L.1930-1933) | 上方裁決表 1~3 | 各一句 |
| N-7 | 工作單 `Out of Scope` 補 Story 005 一行 | 第 15(e) | 一行 |

### 📋 建議(可延後,不必進本張)

| # | 項目 | 出處 |
|---|---|---|
| S-1 | **閘門 abort 面**:①把 `_validate_target_writable()` 前移到升旗之前(修法 A,順帶解決 `assert` 在閘門內的問題);②比照 ADR-0001 L.141 加「`_mutation_in_progress` 不得跨兩幀」卡死偵測(修法 B)。**兩者不重複** —— Story 014 的 `_reclaim.reset()` 會在閘門內長出第三個 abort 面,修法 A 幫不上忙 | 第 4 項 Q3 |
| S-2 | `_registry` 補建構期 null 處置,與 `_reclaim` / `_mouse_position_provider` 對齊(目前三個協作者中唯一沒有的) | 第 4 項 (b) |
| S-3 | `technical-preferences.md` 補一句:量測對象是**引擎行為本身**時,獨立最小專案視為 (A) 級,但須標明非執行專案類別 | 第 14(c) |
| S-4 | Story 014 加一條驗收「開機 `ERR_RECLAIM_POLICY_ABSENT` 訊息消失」,給這個每次開機的紅字一個到期日 | 第 11(e) |
| S-5 | `MarkResult` / `SetTargetResult` 的未定義邊界在 ADR 補非規範性註記 | 第 10(a)(b) |

---

## 附:本覆核未涵蓋的範圍(明文聲明)

- **`tests/unit/cursor/write_read_interface_test.gd`** —— 派工明文排除,由另一位覆核者負責。
  本報告**未讀過該檔任何一行**,也未以任何測試執行結果作為判定依據。
- **`cursor_state_host.gd` 的修正後內容** —— 見第 12(d) 項的範圍聲明。
- **執行期行為** —— 本覆核為靜態的結構/契約一致性覆核。
- **release 建置下的 `assert()` 剝離與 VM 中止行為** —— 本專案無匯出範本,**結構上查證不了**
  (ADR L.123-127 已登記為「層 B」)。第 4 項的 abort 論證對 debug 成立(已實測),
  對 release 為外推。
