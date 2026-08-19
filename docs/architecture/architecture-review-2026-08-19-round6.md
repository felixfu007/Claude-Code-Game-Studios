# 架構審查報告 — 第六輪(範圍限縮)

| 欄位 | 值 |
|---|---|
| **日期** | 2026-08-19(ADR-0005 **第三次修訂**後) |
| **模式** | `/architecture-review` —— **範圍限縮**,非 full |
| **引擎** | Godot 4.7.1 |
| **判定** | **CONCERNS**(第三~五輪亦為 CONCERNS) |
| **前一輪** | `architecture-review-2026-08-19-round5.md`(第五輪) |
| **引擎專家覆核** | **已執行**(`godot-specialist`,使用者明文核准) |

## 本輪範圍(與前五輪不同,務必先讀)

依 2026-08-19 第三次修訂時與使用者的明文約定,本輪**不重推 130 項需求的涵蓋分佈**,範圍限縮為兩件事:

1. **第三次修訂的 17 項是否確實關閉** —— 第五輪的 R5-1~R5-6 + `godot-specialist` 自行發現 S-1~S-5(11 項),加上該次修訂寫入前 Step 5.5 覆核新抓出的 A / B / 2b / D / F / G(6 項)。
2. **`docs/registry/architecture.yaml` 的 68 項立場是否與 ADR 內文逐節一致。**

**因此本報告不產生新的涵蓋率數字,`traceability-index.md` 與 `tr-registry.yaml` 本輪零改動。** 引用涵蓋分佈時請沿用第五輪的 130 項 68 ✅ / 30 ⚠️ / 32 ❌ 與游標系統 15 完整 / 4 部分 / 0 缺口 —— 那是最後一次獨立重推的結果,第三次修訂後的分佈**至今仍未被獨立推導**。

**工作區狀態**:本輪開始時 `git status --porcelain` 無輸出,與 `origin/main` 同步(`rev-list --count --left-right` 為 `0 0`)。

---

## 一、17 項處置判定 —— **16 項完整關閉,1 項只關一半**

| 項 | 第五輪級別 | 本輪判定 | 覈實依據 |
|---|---|---|---|
| **R5-1** | **BLOCKING** | ✅ **完整關閉** | 新增乙分支專用公開入口 `handoff_after_mount(target) -> SetTargetResult`(機制十/十一/Key Interfaces 三處一致);私有路徑由 1 條擴為 4 條。第五輪列出的三種讀法 + 第四個問題(目標未變則靜默不重置)由 `TargetResetPolicy.UNCONDITIONAL` 的**無條件**語意逐一關閉。**`godot-specialist` 逐一展開七個公開入口 × 四條私有路徑的呼叫圖後確認:沒有任何公開入口需要回頭呼叫另一個公開入口**——這是本輪最重要的正面結論 |
| **同源缺陷**(第五輪未點名,修訂 session 自行發現) | — | ✅ 關閉 | 甲分支改走 `_mark_pending_reresolve_internal()`,不再回頭呼叫掛閘門的公開 `mark_pending_reresolve()`。與 R4-4 同形狀、第四輪只修了三處中一處的缺陷至此補齊 |
| **發現 A**(雙重重置) | Step 5.5 | ✅ 關閉 | 機制十明文「必須寫成 `if`/`elif`,不得寫成兩個獨立 `if`」,並登記為 forbidden pattern `independent_ifs_for_cursor_target_reset_policy` |
| **發現 B**(boolean trap) | Step 5.5 | ✅ 關閉 | 私有層改用 `TargetResetPolicy` enum,且明文寫出「在私有層種回同一個 bool 會是自相矛盾的修法」的理由 |
| **發現 2b**(前置驗證) | Step 5.5 | ✅ 關閉 | `_validate_target_writable()`,由 `set_target()` 與 `handoff_after_mount()` 各自呼叫。Validation Criteria #13(ii) 有「以未註冊表面的目標呼叫、斷言回傳 `SURFACE_NOT_REGISTERED`」的反向向量,實作者若為避開閘門而跳過驗證即失敗 |
| **發現 D**(閘門歸屬) | Step 5.5 | ✅ 關閉(但見 R6-10) | `reseed_reclaim_on_focus_regained()` 納為第七個掛閘門公開入口,`void` + `diagnostic_reentrant_rejection_count`。**修法本身有一個未被討論的反方向失敗,列為本輪 R6-10,不推翻本項的關閉判定** |
| **R5-6 + 發現 F** | 中高 | ✅ 關閉 | 機制十三之二的 hover 判定由黑名單**反轉為白名單**;機制十四改為按根節點型別分流(`Control` 兩項硬性、非 `Control` 結構性不適用),並明文**不**約束 `mouse_filter`;`CursorSurfaceRegistry` 新增結構獨立的第二份登記表。Validation Criteria #17(iv) 是 R5-6 與發現 F 各自的迴歸測試 |
| **R5-3** | 中高 | ✅ 關閉 | `_reclaim` 唯一擁有者為 `CursorState`(私有、無 getter);Host 與呈現層各走轉發(`reseed_reclaim_on_focus_regained()` / `reclaim_progress()` / `reclaim_reset_triggered`);滑鼠座標三條路徑收成一條。登記 forbidden pattern `external_access_to_cursor_reclaim_instance`;VC #16 (ii) 斷言 `get_viewport().get_mouse_position()` 全專案恰好出現一次 |
| **R5-2** | 中 | ⚠️ **只關一半** | 規範表與示意圖已改為 −60 + 開區間 + 六值兩兩相異,但 **ADR 內文 7 處、registry 6 處仍寫 −50**。詳見 R6-1。**數值上無害**(−50 仍落在合法開區間內且與六值兩兩相異,推不出任何非法配置),但屬同一份文件對同一個架構強制值給出兩個數字 |
| **S-1 + 發現 G** | 中 | ✅ 關閉(但見 R6-11) | `_safe_mouse_position()` 每次取值前 `is_valid()`;注入形式改為具名方法綁定;VR #15 + Day-1 spike + VC #18,且 VC #18 明文標註「本測試的前提本身列為 VR #15,須先跑 spike」。**fallback 的選擇方向有問題,列為本輪 R6-11,不推翻本項的關閉判定** |
| **S-2** | 低 | ✅ 關閉 | 機制十三之二加 `if Input.mouse_mode != desired` 賦值前守衛(第四輪已建議、第二次修訂未採納,本次補上) |
| **S-3** | 中 | ✅ 關閉 | 機制九新增段落:`_notification()` 派發為**樹序**,與 `process_priority` 是兩個獨立排序機制,不得互相推論,且本 ADR 對此不作任何保證、不得有任何機制依賴它 |
| **S-4** | 低 | ✅ 關閉 | 明訂 `_reclaim` 只在 `_init()` 注入,無執行期熱替換管道;VC #8 的「替換」一律等於重建 `CursorState`,並斷言舊實例無外部參照 |
| **S-5** | 低 | ✅ 關閉 | Risks 明列本 ADR 引入的 10 個 `class_name`,並把「維護已註冊 `class_name` 清單」明文歸給 technical-director(專案級流程,不屬單一 ADR) |
| **R5-4** | 低 | ✅ 關閉 | **實測**:ADR-0005 Validation Criteria 為 1,2,…,9(9a–9d),10,…,19 連續無跳號;ADR-0004 為 1…7 順序正確(第 6 項已改號並維持位置) |
| **R5-5** | 低 | ✅ 關閉 | Architecture Diagram 已含 `UI_ACTION_UNCLASSIFIED` 完整性驗證、−60、七個公開入口、白名單判定、發現 F 的型別分流註記 |

### 對「模式」的判定

第三輪抓到的是**自陳膨脹**,第四、五輪抓到的是**修法本身引入新缺陷**。第三次修訂在寫入前跑了 `godot-specialist` Step 5.5 覆核(第二次修訂缺的正是這道關卡),該覆核當場抓出 6 項、其中 4 項是該次修法自己新產生的。

**這道關卡有效,但不充分。** 本輪 9 項新發現裡 **7 項出自第三次修訂自身**。覆核抓到的是「R5-1 的骨架不完整」,沒抓到:

- 補完骨架後,**甲分支的簽章沒跟著重新設計**(R6-6)
- 同一次修訂新增的**正交性宣告**讓 `is_valid` 翻轉失去訊號涵蓋(R6-7)

`godot-specialist` 對此的建議(本輪採納並記錄):**下一次修法的自問應改為「這個修法會不會讓某個既有簽章、既有正交性宣告變得不成立」**,而不只是「這個修法會不會製造下一個 R-x」。前者管的是修法對周邊的**回頭影響**,後者只管修法本身。

---

## 二、本輪 13 項發現

> R6-1~R6-4 由主審獨立推導,`godot-specialist` 逐項對抗性覆核**全部 CONFIRMED,無一 REFUTED**;其中 R6-1 與 R6-2 主審設定的定義域被判定過窄,各補一層(R6-1 漏第 427 行且完全未查 registry 那一側;R6-2 底下藏著結構性的 R6-5)。R6-5~R6-13 為該專家自行發現,主審已逐項實地覆核 R6-1 補充範圍與 R6-5,其餘採信其靜態推導。

### 已於本 session 修補的 5 項(純文件/登記處,零機制改動)

#### R6-1 · `−50` 殘留 13 處 —— R5-2 的修法只改了規範表 · **低-中** · 純靜態可證

**ADR 內文**:`grep -n -- '-50'` 命中 1 處(ASCII 連字號)、`grep -n '−50'` 命中 8 處(U+2212),合計 9 處。其中第 412 行(引述第四輪判定原文)與第 433 行(「由 −50 改為 −60」這句修法本身)**是合法的歷史敘述**;其餘 **7 處為 live**:132(Constraints 的 R4-7 拆節點規則)、388(機制五註解)、**427**(機制六「為何必須是兩個節點」的核心推導句 —— 主審初判漏列,專家補上)、1250(Key Interfaces,以**約束句**寫的「必須嚴格介於 ② -50 與 ④ 0 之間」)、1359(GDD Requirements Addressed 的 `TR-cursor-008` 列)、1410/1411(Validation Criteria 9a / 9b 兩個**測試規格**)。

**registry**:`grep -n -- '-50'` 命中 10 處。963(`api:` 權威欄)已正確寫 −60 並附 R5-2 修訂註記;977/985 明文標為 `kept only as a record`(OVERTURNED 段落);1025 是 R5-2 的修訂註記本身 —— 四者合法。其餘 **6 處為 live**:999/1002(`cursor_actor_process_priority_ladder` 的 "NEW VALUE (6 tiers)" 現行值陳述)、1682(`call_deferred_for_cursor_retarget_deferral` 的 `why:`)、1694/1697/1709(`single_node_for_nonadjacent_cursor_actor_roles` 的 `description:` 與 `why:`)。

**嚴重度判定(專家加壓後確認)**:第 1250 行**不會導致非法配置** —— 若讀者採信 ②=−50,它仍滿足第 419 行的開區間 −100 < ② < −25,而 ③=−25 也確實嚴格介於 −50 與 0 之間;兩種讀法交出的配置都合法且六值仍兩兩相異。**這是純文件缺陷,不是配置缺陷。**

**但 registry 的殘留比 ADR 的更該修**(專家判定,本輪採納):registry 的 `description:` 欄是程式碼審查者實際拿去比對的規則文字,它原本寫「actor (2) caller-active-retag at **-50**」並建議「a thin child at **-50** for the retag role」。ADR 內文的殘留只是讀起來困惑,registry 的殘留**會被當成規則執行**。

**根因**:R5-2 的修法只改了 `api:` 欄與新增的 `reason:` 段落,**沒有回頭掃同一份檔案裡其他條目對該值的引用**。

**✅ 已修**:ADR 7 處、registry 6 處,合計 13 處。歷史敘述的 4 處刻意保留。第 1250 行順帶補上開區間條件;第 1359 行補上「第三次修訂 R5-2 由 −50 改為 −60」的沿革註記。

#### R6-5 · registry YAML 重複鍵 · **高** · 純靜態可證

`docs/registry/architecture.yaml` 的 `- purpose: cursor_unregistered_surface_hover_visibility` 這個 mapping 內出現**兩個 `revised:` 鍵**(`"2026-08-19c"` 與 `""`,相鄰兩行)。

依 YAML 1.2 規格重複鍵為錯誤。寬鬆解析器(PyYAML 等)採**後者勝出** → `revised` 實際值為空字串,**第三次修訂的 `c` 戳記被靜默抹掉**;嚴格解析器(ruamel round-trip、多數 linter)則直接拋錯 → 整份權威 registry 無法載入。**兩種後果沒有一種可接受。**

「會不會 parse 失敗」屬未實測(本機無 Python 執行環境);「檔案含重複鍵」是純文字可證的事實 —— 以 `awk` 對每個 entry 區塊計數 `revised:` 鍵,全檔僅此一處為 2,其餘皆為 0 或 1。

**這是第三次修訂自己新產生的**,錯誤形狀是「新增一行忘了刪舊行」。

**✅ 已修**:刪除重複的空值行。修後全檔零重複鍵,`revised: "2026-08-19c"` 標記數為 8,與檔頭宣稱的「就地修訂 8 項」一致。

**建議**(未執行,留待下次修訂):加一道機械檢查(每個 entry 的 `revised:` 鍵數必須 ≤ 1),因為這個形狀會重複發生。

#### R6-2 · registry 兩項 `revised:` 欄未同步 · **低** · 純靜態可證

檔頭宣稱就地修訂 8 項且「皆 `revised: 2026-08-19c`」,實測只有 6 項帶該標記。缺的兩項:`mouse_reclaim_accumulator`(state)與 `cursor_visual_carrier_split`(api),兩者的 `revised:` 欄皆停在 `"2026-08-19b"`。

**兩者的內文都確實更新了** —— `mouse_reclaim_accumulator` 的 `write_access:` 與 `notes:` 內有 `REVISED 2026-08-19c, R5-3`,`cursor_visual_carrier_split` 的 `api:` 內有 `REVISED 2026-08-19c, round-5 R5-6`。**散文改了、結構化欄位沒改** —— 與 R6-1 同一個形狀。任何以 `revised` 日期做篩選的工具都會漏掉這兩項。

**✅ 已修**:兩處改為 `"2026-08-19c"`。

#### R6-3 · ADR-0005 的涵蓋歷史表落後一次修訂 · **低** · 純靜態可證

表題寫「2026-08-19 **第四輪修訂後**」,最後一列停在「第二次修訂後 / 本 ADR 不自陳 / 待第五輪」。但**同一份文件的 Status 段落與 Validation Criteria #19 都已改口說「待第六輪」** —— 同一份文件對「現在是第幾輪」給出兩個答案。第五輪已獨立推出的 15 完整 / 4 部分 / 0 缺口未入表。

**✅ 已修**:表題改為「第三次修訂後」;補入「第五輪獨立重推(第二次修訂後)| **15 完整 / 4 部分 / 0 缺口**」一列;末列改為「第三次修訂後 | **本 ADR 不自陳** | 待第六輪(範圍限縮:17 項是否確實關閉)」。下方段落的「上表保留三輪的實際數字」同步改為四輪。

#### R6-4 · `technical-preferences.md` 的 ADR-0002 摘要句與 C3 修訂自相矛盾 · **中**(專家判定,主審原判低) · 純靜態可證

`.claude/docs/technical-preferences.md` 的 ADR-0002 條目,同一行前段寫 `Mutex` 是 "**the project's only declared thread-safety obligation**",行尾的 C3 修訂註記卻寫「`Mutex` 決策不變但理由改為**縱深防禦**,不再宣稱是『全專案唯一已成立的執行緒安全義務』」。ADR-0002 本文已正確修好(機制七的 C3 段落)。

**專家判定本項影響面被主審低估,本輪採納此加壓**:`.claude/docs/technical-preferences.md` 由 `CLAUDE.md` 以 `@` 引入,**這句已被撤回的宣稱會注入每一個 session 的系統脈絡**。它不是一份參考文件裡的陳舊句子,是每次對話的前提 —— 下一個 session 的任何 agent 讀到「全專案唯一已成立的執行緒安全義務」,會據此做出錯誤的並發設計判斷。

**✅ 已修**:改為 "defence-in-depth — ADR-0004 has since ruled the background-thread condition of `TR-affinity-016` to be NO, so this is a lock with no current contender; see the C3 note below"。

> **同行殘留、本輪未改、留待裁決**:同一條目寫 "Covers all 24 `TR-affinity-*` requirements",而第五輪的獨立推導為 22 ✅ / 2 ⚠️ / 0 缺口。**零缺口**成立,故「涵蓋全部 24 項」勉強可辯護,與 ADR-0004 被連續清除四次的「全數覆蓋」過度宣稱(該處實為 22/7/**1**,有真缺口)嚴重度不同。但它屬同一個措辭家族,**建議下次修訂時一併改為「24 項零缺口(其中 2 項部分涵蓋,成因在他系統)」**。

---

### 需改動 ADR 決策內容、**本輪未修**的 8 項

> 以下 8 項全部會改動介面簽章、訊號集合、節點拆分或型別語意,屬 `/architecture-decision` 的管轄範圍,審查 session 不逕行修改。使用者已裁決:**另開 session 跑第四次修訂**。
>
> **關於「第三次修訂為最後一次全面修訂」的約定**:本輪判定該約定不被違反 —— 約定的是最後一次**全面**修訂;這 8 項是點狀的、有明確清單的修訂,不是全面重審。五份 ADR 皆仍為 `Proposed`,現在改動成本最低。

#### R6-6 · `handoff_before_unload(surface)` 的 `surface` 參數懸空 · **中高** · 純靜態可證

機制十一虛擬碼寫甲分支為 `handoff_before_unload(surface)` → `_mark_pending_reresolve_internal(當下目標)` → `_reclaim.reset(_safe_mouse_position(), SURFACE_HANDOFF)`。**`surface` 在兩條後續呼叫裡都沒有被讀** —— `_mark_pending_reresolve_internal(expected: CursorTarget)` 收的是 `CursorTarget`,而虛擬碼傳入的是「當下目標」,不是任何從 `surface` 導出的東西。全文 8 處 `handoff_before_unload` 命中,無一說明 `surface` 的用途。

兩種讀法,**兩種都有問題**:

1. **它是一道守衛**(只有當下目標的表面等於傳入值才標記)。合理,但 `MarkResult` 目前只有 `APPLIED / STALE_NOT_APPLIED / NO_CURRENT_TARGET / REJECTED_REENTRANT`,**沒有任何一個能表達「表面不符」**;複用 `STALE_NOT_APPLIED` 會對呼叫方說謊(它的語意是「你手上的目標過期了」,不是「你交接錯表面」)。守衛讀法在現行回傳型別下**無法實作而不違反本 ADR 自己的「絕不靜默」紀律**。
2. **它是殘留的無用參數**。那麼它就是一個誘導實作者去猜語意的介面面 —— 而本 ADR 才剛以「呼叫處看不出參數是什麼」為由否決了 `set_target()` 的第三參數方案。

**額外的不對稱**:ADR 宣稱甲/乙「成對讀起來就是交接生命週期的兩半」,但參數型別是 `SurfaceType` vs `CursorTarget` —— 不是一對,是兩個不同抽象層級的東西。**R5-1 新增乙分支入口時只設計了乙的簽章,沒有回頭把甲的簽章納入同一次設計。**

**修法(必須明文擇一)**:(a) 刪除 `surface` 參數,簽章改為 `handoff_before_unload() -> MarkResult`;或 (b) 保留為守衛,`MarkResult` 新增 `SURFACE_MISMATCH` 並在虛擬碼寫出比對步驟。**專家傾向 (a)** —— 甲分支的呼叫時機是「舊表面拆除前」,呼叫方本來就知道自己在拆哪一個,守衛能攔下的錯誤情境幾乎不存在,而代價是一個新 enum 值加一條新測試向量。

**這是第三次修訂自己新產生的**(R5-1 修法的直接副作用)。

#### R6-7 · 乙分支同值寫入時 `target_changed()` 不發,且 `is_valid` 翻轉全文無訊號涵蓋 · **中高** · 純靜態可證

推導鏈:

1. 機制十明訂「`target_changed()` 的發出條件不變:只在目標確實改變時發,與 `reset_policy` **正交**」。
2. 甲分支先把當下目標標記為待重新解析(`is_valid` 翻 `false`)。
3. 乙分支 `handoff_after_mount(target)` 走 `UNCONDITIONAL`。若新目標的表面與 `id` 恰等於舊目標 —— **存檔讀取後回到同一張棋盤時這是常態,不是邊緣情境**。
4. 「目標是否確實改變」取決於 `CursorTarget.equals()` **有沒有比較 `is_valid`**,而機制三只給了簽章,**全文未定案**:
   - 若只比表面 + `id`(最自然的身分比較讀法,也是機制三把 `id` 統一為 `int` 的整個理由)→ 判定「未改變」→ **`target_changed()` 不發出**,但 `is_valid` 已從 `false` 翻回 `true`。
   - 若也比 `is_valid` → 訊號正常,但「同一格的有效與失效版本是兩個不同目標」會污染 `mark_pending_reresolve(expected)` 的競態語意(呼叫方手上的 `expected` 幾乎必然是有效版本,而當下持有的可能已失效 → 恆回 `STALE_NOT_APPLIED`)。

**兩條路都有代價,而 ADR 沒選。** 第一條路的實際後果:機制十的 N4 修法明文祝福「不想每幀輪詢的下游系統」只訂閱訊號,**這類下游會永遠停在待重新解析的視覺上**,因為喚醒它的那個狀態變化沒有對應訊號。輪詢派下游不受影響 —— 只有訂閱派中招,這正是最難在整合測試裡發現的那一種。

**更廣的根因**:`is_valid` 旗標的翻轉在**全文沒有任何訊號涵蓋**(全文 `signal` 宣告僅 `target_changed` / `device_authority_changed` / `reclaim_reset_triggered` / `reset_triggered` 四個)。而 `mark_pending_reresolve()` 這條路徑(不只乙分支,一般路徑也是)唯一改變的就是 `is_valid`。Validation Criteria #13(i) 只斷言「當下目標確實被標記」,不斷言有沒有推播。

**修法**:(i) 機制三明訂 `equals()` **只比較表面與 `id`**,`is_valid` 不參與(保住 `mark_pending_reresolve` 的競態語意);(ii) 在 `_write_target_internal()` 與 `_mark_pending_reresolve_internal()` 內明訂「`is_valid` 的翻轉亦視為狀態變更,須發出 `target_changed()`」,或新增 `target_validity_changed()`;(iii) Validation Criteria 15b 補第三個向量:同值寫入情境下斷言 `target_changed()` **有**發出。

**這是第三次修訂自己新產生的**(`UNCONDITIONAL` 路徑與那句正交性宣告都是本次新增)。

#### R6-8 · 機制六⑤的「同一節點」與機制十二/十三的「兩個視覺元素」互相矛盾 · **中** · 純靜態可證

- 機制六 ⑤ 寫:CanvasLayer 子節點,priority = 50,待機指示、奪權漸進回饋載體、機制十三之二的 hover 判定「**同一節點單一 `_process()` 內完成**,避免與其他 priority=50 節點的同層排序未定義問題」。
- 機制十三的程式碼區塊標題寫「自繪替代游標節點」,其 `_process()` 末尾寫 `modulate.a = _presented_alpha`。
- Architecture Diagram 把「全域每裝置待機指示」與「自繪奪權漸進回饋游標」畫成 CanvasLayer 底下的**兩個並列子項**。

三處不能同時成立,而 `modulate.a` 是**逐節點**屬性:

- **若真是同一節點**:`modulate.a = _presented_alpha` 會把**待機指示一起淡出**。待機指示的可見性依 `TR-cursor-016` 由裝置權威決定,與奪權進度無關 —— 這是行為錯誤。
- **若是兩個節點**:機制六 ⑤ 的「同一節點」不成立,而該句的理由正是「避免同層排序未定義」;兩個節點都在 50,**直接落入 R5-2 本次新訂的「同值之間本 ADR 不假設任何 tie-break」**。

**這項的尖銳化是第三次修訂造成的** —— R5-2 之前「同值無 tie-break」只是機制六 ⑤ 的一句風險註記,第三次修訂把它升格為「架構強制值必須兩兩相異」的正式立場,於是這個矛盾從「措辭不一致」變成「違反本 ADR 自己剛訂的規則」。

**修法**:拆為三個節點並明訂各自職責與優先序(待機指示純讀取可留 50、自繪游標承載 `_presented_alpha`、hover 判定為 Core Rules #5 的執行者);若堅持合併,必須把 `modulate.a` 下放到只有自繪游標那個子節點,並刪掉機制六 ⑤ 的「同一節點」措辭。**連帶**:機制十五取樣的是「自繪節點每幀實際 `modulate.a`」,這句在合併讀法下取樣對象不唯一。

#### R6-9 · 「兩兩相異」只覆蓋角色,未覆蓋同一角色的多個實例 · **中** · 純靜態可證

R5-2 新立的立場是「機制六**六個行為者**的架構強制優先序值必須兩兩相異,這是定序保證成立的前提,不是建議」。但同一張表裡:

- ② 的定義是「**任何**因遊戲語意事件需呼叫 `mark_pending_reresolve()`/`set_target()` 的下游系統」—— 開放式、多實例。
- ⑥ **明文列了三個具體系統**(戰鬥 HUD、好感度視覺 UI、支援對話 UI)**全部在 100**。

新立的規則自己就有三個反例。後果分兩檔:**⑥ 的三個同值實例**純讀取、彼此無定序需求,**無害**(但規則文字自我矛盾);**② 的多個同值實例有害** —— 兩個系統同幀各自 `set_target()`,順序未定義 → 最後寫入者勝 → **最終目標不決定**。ADR 全文從未討論同幀多重主動改標。

**嚴重度壓在「中」的誠實理由**(專家原文記錄):GDD 的「100% 決定性」宣稱其字面管轄範圍是同幀雙裝置仲裁,不是多呼叫方改標;後者更像下游設計問題。但 ADR 既然把「兩兩相異」升格為硬性前提,就有義務說清楚它管到哪一層。

**修法**:明文補「本規則管轄的是**角色之間**;同一角色的多個實例(②、⑥)之間本 ADR 不提供定序保證,②的多實例呼叫方須自行確保同幀不會有兩個系統對同一目標欄位競寫,此為下游義務」。或更強:規定 ② 的多實例必須在開區間內取相異值並登記。

#### R6-10 · `reseed_reclaim_on_focus_regained()` 掛閘門的反方向失敗未被討論 · **中** · 純靜態可證(論證級)

**先排除一半**:FOCUS_IN 路徑的疑慮**不成立**。ADR 自己的論證擋住了 —— `_notification()` 由主迴圈派發,不會插進某個 GDScript 函式主體的執行中途(單執行緒、非搶佔、七個公開入口內無 `await`)。S-3 說的樹序只影響「哪個節點先收到通知」,不改變這個結論。

**另一半成立,且 ADR 沒討論**:發現 D 的論證**只涵蓋「防止雙重重置」這一個方向**。反方向是 —— 下游在 `device_authority_changed()` 的處理函式裡呼叫 `CursorStateHost.resume_arbitration()`(這是**合理**的下游設計:「權威轉回滑鼠 → 關掉手把提示模態」,不是 ADR 舉的那個誤用例子)。此時 `_mutation_in_progress` 仍為真(訊號在旗標清空**之前**發出)→ 轉發進掛閘門的入口 → 整段 no-op → **重新播種被靜默丟棄**,累積起點停在模態開啟前的過期座標。

**那正好是第一次修訂新增 `resume_arbitration()` 重新播種時要修的缺口。閘門在一條窄路徑上把它重新打開了**,而回傳型別是 `void`,呼叫方連知道都不知道,只有一個 QA-only 計數器。

**另有一項對稱性斷裂**:`suspend_arbitration()` **不**掛閘門(它只碰 Host 自己的 `_arbitration_suspended` 與 `_frame_events`),`resume_arbitration()` 卻會被閘門擋。同一對 API 在重入情境下行為不對稱,且無任何文字說明。

**修法**:不要丟棄,改記 pending —— 偵測到重入時設 `_pending_reseed = true`,由當前公開入口在清 `_mutation_in_progress` **之前**補做一次。這與 ADR 自己在 R4-6 定下的「唯一許可手段是設旗標」是同一個形狀,不引入任何未查證的排程假設。**至少也要明文寫出這個失敗方向並宣告刻意接受** —— 目前是完全沒提。

**這是第三次修訂自己新產生的**(發現 D 的修法本身)。

#### R6-11 · `_safe_mouse_position()` 的 fallback 製造「靜默凍結」,失敗方向偏錯的一側 · **中** · 純靜態可證(論證級)

provider 失效後 `_safe_mouse_position()` 恆回傳同一個陳舊座標 `P`,而 `evaluate()` 內部算 `P.distance_to(_seed)`:

- **情況一**:失效發生在某次 `reset()` 之後 → `_seed == P` → 淨位移恆為 0 → **滑鼠永遠無法達門檻奪權**。
- **情況二**:失效時 `P` 距 `_seed` 已超過門檻 → 每幀主張權威;但固定優先序下 NAVIGATION 恆勝,玩家一按方向鍵即觸發 (d) `VETOED_SAME_FRAME` → `reset(P, ...)` 把 `_seed` 拉回 `P` → **收斂進情況一**。

**穩態必然是情況一:滑鼠側奪權永久失效,且對玩家與正式版完全無聲**(`diagnostic_invalid_mouse_provider_count` 是 QA-only)。這與 ADR 通篇「絕不靜默」與「fail-safe 必須偏向硬性規則那一側」不一致 —— **本次修訂才剛用同一個論證把機制十三之二反轉為白名單,這裡卻選了最安靜的那個 fallback。**

**嚴重度壓在「中」的誠實理由**:正式 Autoload 生命週期下 provider 綁定的是 Autoload 自己,不會被釋放,ADR 對此的評估(「風險趨近於零」)成立。這是設計方向問題,不是會在出貨版本觸發的缺陷。**另一個小點**:初值 `Vector2.ZERO` —— 若 provider 從第一次呼叫就無效,系統會表現得像滑鼠停在 (0,0),`reset()` 也以 (0,0) 播種,一致但錯誤,同樣無聲。

**修法**:把失效的處置從「座標層 fallback」升到「系統層行為」—— provider 無效時進入明確的降級狀態:`evaluate()` 路徑整段跳過(滑鼠奪權停用)、`push_error()` **一次**(不是每幀)、診斷計數保留。失敗方向從「靜默凍結」翻成「大聲停用」,與 R5-6 白名單反轉的邏輯一致。

#### R6-12 · 第五輪明文建議的「`add_child()` 前設定 `process_priority`」既未採納也未駁回 · **低中** · 純靜態可證

全文 `add_child` 命中 5 處,**全部只寫「於 `_ready()` 內 `add_child()` 一個 `CursorNavigationApplier`(process_priority = -25)」這類措辭,沒有任何一處規定設值必須發生在 `add_child()` 之前**。Validation Criteria 9c 只做靜態值斷言與父子關係斷言,不涵蓋設定順序。第五輪的建議**就是掉了**。

這與 S-2 是同一個模式(第五輪自己記錄過「先前輪次的非阻擋建議未被回頭處理」),只是這次輪到第五輪自己的建議被下一次修訂漏接。

**修法**:機制一與 Key Interfaces 各補一句「`process_priority` 必須在 `add_child()` **之前**設定」,VC 9c 補一條靜態程式碼審查項。**成本為零,直接消掉一個印象等級的引擎依賴。**

#### R6-13 · 第二張登記表的結果語意未定案,且與第一張表共用回傳 enum · **低** · 純靜態可證

`RegisterResult` 新增了 `ALREADY_EXCEPTED`,但全文沒有任何段落說明它何時回傳;`unregister_native_pointer_exception()` 的失敗案例(未曾登記)沒有對應值。更根本的是:ADR 才剛以「兩者的生命週期擁有者不同」為由堅持兩張表必須**結構獨立**,卻讓兩張表共用同一個回傳 enum —— 於是 `DUPLICATE_TAG_REJECTED`(標籤概念)出現在一張明文「沒有標籤」的表的回傳型別裡。

**額外的生命週期缺口**:第一張表由「單標籤單實例 + 顯式 `unregister()`」保護;第二張表明文「可以有任意多個、沒有標籤、來去自由」,而 ADR 沒有任何自動反登記機制。若例外表面被 `queue_free()` 而忘記反登記,登記表持有已釋放的 `Control` 參照,祖先鏈比對會踩到 GDScript 的 previously freed instance 陷阱。

**修法**:(i) 第二張表拆出自己的 `ExceptionRegisterResult`;(ii) `register_native_pointer_exception()` 內連接該節點的 `tree_exited` 自動反登記 —— 比對該表「來去自由」的定位,自動化比紀律更合適。

---

## 三、專家逐項加壓後**未抓到破綻**的項目

> 逐項明列,避免被誤讀為「沒壓到」。

| 加壓點 | 結論 |
|---|---|
| **七個公開入口 × 四條私有路徑的呼叫圖** | **未抓到破綻。** 七個入口逐一展開後,**沒有任何一個需要回頭呼叫另一個公開入口**,R5-1 的修法在這一點上成立。唯一的不對稱是 `apply_buffered_navigation()` 是三條寫入路徑中**唯一不呼叫 `_validate_target_writable()`** 的一條,ADR 未說明理由(導覽算出的目標理論上落在已註冊表面上,但表面可能剛被 `unregister()`)—— 判為**敘述缺口而非缺陷**,建議第四次修訂順帶補一句 |
| `register_native_pointer_exception(node: Control)` vs `is_native_pointer_exception(node: Node)` **型別不一致** | **未抓到破綻,這個不一致是對的。** 登記端收 `Control` 有明文理由(非 `Control` 不會出現在 `gui_get_hovered_control()` 回傳裡);查詢端收 `Node` 是因為祖先鏈走訪用 `get_parent()`,回傳型別就是 `Node`。收窄成 `Control` 反而會在遇到非 `Control` 祖先時提前斷鏈 |
| ⑤(50)是否讀得到 ①(−100)同幀裁定的新值 | **正確,未抓到破綻。** 50 > −100,同幀後執行,讀到的是本幀已裁定的權威值,正是機制十三之二想要的「同幀反映」 |
| 白名單反轉後,滑鼠持權威時原生指標一律 VISIBLE(不看 hover)是否與 Core Rules #5 有落差 | **未抓到破綻。** Core Rules #5 的義務是「**失去權威**的裝置其原生視覺須被抑制」;滑鼠持權威時原生指標本就該可見。連帶檢查:此時自繪奪權游標的 `_presented_alpha` 因 `AUTHORITY_TRANSFER` 已 reset 為 0,不會與原生指標並存 |
| 六值兩兩相異的前提 | **在角色層成立**(−100 / −60 / −25 / 0 / 50 / 100);−50 殘留不破壞這一點。**但實例層未被覆蓋 —— 見 R6-9** |

---

## 四、Registry 逐節對帳 —— **修後零落差**

| 節 | 實測 | 檔頭自陳 |
|---|---|---|
| `state_ownership` | 10 | 10 ✅ |
| `interfaces` | 11 | 11 ✅ |
| `api_decisions` | 23 | 23 ✅ |
| `forbidden_patterns` | 24 | 24 ✅ |
| **合計** | **68** | **68** ✅ |

依 `adr:` 欄逐項實測分佈:ADR-0001 **13**、ADR-0002 **12**、ADR-0003 **6**、ADR-0004 **8**、**ADR-0005 26**、`adr: none` **3**(專案級裁決)= 68 ✅。

ADR-0005 逐節為 **3 state / 5 interface / 7 api / 11 forbidden = 26**,與檔頭自陳完全一致 ✅。

第三次修訂宣稱的三項新增條目全部存在:`cursor_native_pointer_exception_registration`(interface)、`external_access_to_cursor_reclaim_instance`、`independent_ifs_for_cursor_target_reset_policy`(forbidden)✅。

`.claude/docs/technical-preferences.md` 的三處計數(forbidden 24 項 / 其餘 21 項 / ADR-0005 共 11 項)與 registry 實測一致 ✅(10 + 11 + 3 專案級 = 24)。

**修前的兩項落差**(`revised:` 欄未同步、YAML 重複鍵)已於本輪關閉 —— 見 R6-2 與 R6-5。

### 一項未修的 schema 不一致(不影響正確性)

`state_ownership` / `interfaces` / `api_decisions` 三節的條目在未修訂時寫 `revised: ""`,而 `forbidden_patterns` 節的條目則**完全省略該鍵**。兩種慣例並存,不是錯誤,但會讓「以 `revised` 鍵是否存在」做判斷的工具在不同節之間得到不同語意。建議未來統一。

---

## 五、引擎相容性

**本輪未重跑全域引擎稽核** —— 範圍限縮。以下為針對第三次修訂增量的判定。

### 棄用 API:**零命中**

第三次修訂涉及的引擎 API 面:`Callable(obj, "method")` 建構、`Callable.is_valid()` / `call()`、`Viewport.gui_get_hovered_control()`、`Input.mouse_mode` 讀後比較再寫、`Node.get_parent()` 祖先鏈走訪、`Control` 型別參數、`signal.connect(callable)`。全數為 4.x 現行 API。

**誤報防範已執行**:`deprecated-apis.md` 第 25/29 行是「**左欄棄用、右欄建議取代**」的格式;ADR 用的 `signal.connect(callable)` 正是右欄形式,不構成命中;亦未使用 `OS.get_ticks_msec()`。

**專家的加強論證(其自行推導,非轉引)**:第三次修訂相對第二次修訂**沒有引入任何新的引擎 API 面** —— 新增的全是 GDScript 語言層構造(`TargetResetPolicy` enum、四條私有方法、一個轉發訊號、一張登記表)。因此第五輪對第二次修訂做的零命中結論可**結構性繼承**,不需要重跑。

### 四項引擎事實的證據等級

> **前置聲明(誠實記錄)**:本表的「參考庫佐證」一欄為**轉引**(來源:ADR 自己的逐項 grep 表、第五輪報告的獨立比對),`godot-specialist` 本輪未重新打開 `deprecated-apis.md` / `breaking-changes.md` / `modules/*.md` 的內文,僅確認目錄結構(8 份 modules + 3 份頂層檔)。

| # | 事實 | 證據等級 | 參考庫 | 判定 |
|---|---|---|---|---|
| 1 | `Callable(self, "_get_mouse_position")` 具名綁定,在綁定物件 `queue_free()` 後 `is_valid()` 是否可靠回傳 `false` | **印象-中高** | 零命中(轉引) | **同意 ADR 的選擇。** 具名綁定內部以物件 ID + 方法名保存,`is_valid()` 有明確可查詢對象;lambda 是 `GDScriptLambdaCallable`,有效性繫於腳本實例而非被捕獲物件,且 `Node` 非 `RefCounted`,隱式捕獲 `self` 不延長生命週期 —— 常見症狀是 previously freed instance 錯誤或崩潰,而非乾淨的 `false`。**明確不同意降級**:VR #15 標「中高」並排進 Day-1 spike 是對的。追加確認:`queue_free()` 是延後釋放,spike 必須等一影格才有意義 —— VR #15 已寫「等一影格」,這點正確 |
| 2 | `Viewport.gui_get_hovered_control()` 的回傳語意,及 `CanvasLayer` 上的節點 hover 是否正常回傳 | 基本語意 **印象-中高**;CanvasLayer 情境 **印象-中** | 零命中(轉引) | 回傳目前位於滑鼠下、參與 GUI hover 管線的最內層 `Control`,無則 `null`;`MOUSE_FILTER_IGNORE` 節點不參與判定(與 R5-6 的前提一致)。**CanvasLayer 情境應正常回傳** —— 該方法是 **Viewport** 的方法,`CanvasLayer` 改變的是繪製與輸入映射的**變換**,不改變 GUI 系統歸屬於哪個 Viewport。這反過來佐證第四輪把 VR #11 拆為 #11a/#11b 是對的(真正脫節的只有 ADR 手動指派 `position` 的那一半),也佐證第三次修訂把 VR #14 降為低是對的 |
| 3 | `_ready()` 內 `add_child()` **之後**設 `process_priority` 是否正確重排 | **印象-中**(與第五輪同級) | 零命中(轉引) | **實查結果:第五輪的建議未採納也未駁回 —— 見 R6-12。** 引擎事實本身的判斷比第五輪略樂觀:setter 在節點已在樹上時會觸發處理鏈重排,風險不在「會不會重排」而在「是否影響當前這一幀已開始的遍歷」,而本案的 `add_child()` 發生在 Autoload 的 `_ready()`(主場景載入前),落在某幀 `_process` 遍歷中途的可能性極低。**但「先設值再 `add_child()`」的成本是零**,仍應採納為強制寫法 |
| 4 | 第三次修訂新增/改動 API 對 `deprecated-apis.md` 的比對 | **印象-高** + 轉引 | 見上 | **零命中** |

### 引擎參考庫既有缺口(自第三輪起未動,本輪不重驗)

`modules/` 全部 8 份仍標 `Engine: Godot 4.6`,專案釘選 4.7.1;`breaking-changes.md` 與 `VERSION.md` 對 4.5 的風險分級相反的自相矛盾仍開。

---

## 六、跨 ADR 銜接缺口

**本輪不重驗** —— C1~C6 已於第五輪逐項覈實全部關閉,且 ADR-0001/0002/0003 自第五輪起零改動,ADR-0004 僅第五輪 R5-4 的 Validation Criteria 編號調正(本輪已覈實)。

**⚠️ 五份 ADR 全部仍為 `Proposed`,無一 `Accepted`** —— 依 `docs/CLAUDE.md`,引用 `Proposed` ADR 的 story 會被自動阻擋。ADR-0003 依賴 ADR-0002、ADR-0004 依賴 ADR-0003,兩條依賴都指向仍為 `Proposed` 的上游。**這已連續四輪未動,仍是比任何單一涵蓋缺口都更接近實作路徑的結構性阻擋。**

---

## 七、判定

### **CONCERNS**

**本輪零 BLOCKING。** 第五輪唯一的 BLOCKING(R5-1)經 `godot-specialist` 逐一展開呼叫圖後判定**核心修法成立**。

**為何不是 PASS**:R5-2 只關一半(已於本輪修補);新增 8 項需改動 ADR 決策內容的發現,其中 R6-6 / R6-7 為中高、且兩者都會造成實作層行為錯誤(懸空參數誘導猜測、訂閱派下游永遠停在待重新解析視覺)。

**為何不是 FAIL**:本輪未重推涵蓋分佈,故不引用涵蓋率作為判定依據;13 項發現中無一為 BLOCKING,亦無跨 ADR 衝突。**⚠️ 第五輪登記的 FAIL 退回條件維持有效**:若戰棋 GDD 在其演算法層 ADR 之前先達 `Approved`,25 項 Core 層缺口即符合 FAIL 條件。

### ADR-0005 進入 `Accepted` 前必須關閉

1. **R6-6 / R6-7**(中高 —— 皆為 R5-1 修法的直接副作用,皆會造成實作層行為錯誤)
2. R6-8 / R6-9 / R6-10 / R6-11(中)
3. R6-12 / R6-13(低中/低)
4. 七項 Day-1 spike(其中 VR #2 `_input()` 全數派發完才進 `_process()` 為全案最該優先驗證的單點失效點;VR #15 `Callable.is_valid()` 為 S-1 整套防禦的前提)

### 本輪已修補(純文件/登記處,零機制改動)

| 項 | 檔案 | 改動 |
|---|---|---|
| R6-1 | ADR-0005 ×7 處、`architecture.yaml` ×6 處 | `−50` → `−60`;第 1250 行順帶補開區間條件;`TR-cursor-008` 列補沿革註記。4 處歷史敘述刻意保留 |
| R6-5 | `architecture.yaml` | 刪除重複的 `revised:` 鍵 |
| R6-2 | `architecture.yaml` ×2 | `revised:` `2026-08-19b` → `2026-08-19c` |
| R6-3 | ADR-0005 | 涵蓋歷史表補第五輪一列 + 第三次修訂一列;表題與下方段落計數同步 |
| R6-4 | `.claude/docs/technical-preferences.md` | `Mutex` 摘要句改為縱深防禦措辭 |

---

## 八、下一步優先序

1. **`/architecture-decision` 第四次修訂 ADR-0005** —— R6-6~R6-13 共 8 項。**使用者已裁決另開 session 執行。** 關於「第三次修訂為最後一次全面修訂」的約定:本輪判定不被違反,因為約定的是最後一次**全面**修訂,這 8 項是點狀、有明確清單的修訂。**寫入前必須跑 Step 5.5 覆核**(該關卡在第三次修訂已證明有效),且**自問應改為「這個修法會不會讓某個既有簽章、既有正交性宣告變得不成立」**。
2. **`/ux-review design/ux/interaction-patterns.md`** —— 與架構軌零依賴。Pre-Production 閘門要求關鍵規格有審查判定,該檔尚未驗證。
3. **戰棋盤面演算法層 ADR** —— 投入產出比最高的單一動作,一次移動 25 項 ❌ 中的大部分。
4. **回合結構擁有權 + 缺席的 AI/遭遇系統 ADR** —— 全專案無人認領回合結構。
5. **(建議,自第三輪起第四次提出)建立 `docs/consistency-failures.md`** —— 六輪下來已有足夠的同型別重複值得沉澱為可查的模式清單:自陳膨脹 ×1、**修法本身引入新缺陷 ×3**(第四、五、六輪)、**散文改了但結構化欄位/示意圖/歷史表沒跟著改 ×4**(registry `interface:` 欄、Consequences 自陳、Architecture Diagram、本輪的 `revised:` 欄與涵蓋歷史表)。這份檔案的缺席正在讓模式辨識完全依賴人工回讀歷史報告。
6. **(低成本)`.claude/docs/technical-preferences.md` 的 "Covers all 24 `TR-affinity-*` requirements"** 改為「24 項零缺口(其中 2 項部分涵蓋,成因在他系統)」—— 見 R6-4 的附註。

---

## 九、Pre-gate 檢查(2026-08-19 實測,**glob by FILENAME**)

> 依 P0-3 的結構性修法,存在性檢查一律以**檔名** glob 全庫,不以散文引述的路徑查。第一~五輪對 `accessibility-requirements.md` 連續五次誤報 ❌,根因即是查了 `design/accessibility-requirements.md`(少了 `ux/`)。**本輪未再發生。**

| 項目 | 狀態 | 實際路徑 |
|---|---|---|
| `tests/unit/` | ✅ | `tests/unit/` |
| `tests/integration/` | ✅ | `tests/integration/` |
| `tests.yml` | ✅ | `.github/workflows/tests.yml` |
| `accessibility-requirements.md` | ✅ | `design/ux/accessibility-requirements.md`(另有範本 `.claude/docs/templates/accessibility-requirements.md`,非同一份) |
| `interaction-patterns.md` | ✅ | `design/ux/interaction-patterns.md` |

**五項全備。** 但 `/gate-check pre-production` **仍不保證通過** —— 閘門另有 ADR `Accepted`(目前 0/5)、UX 規格覆蓋(目前 0 份畫面規格)等條件,且 `interaction-patterns.md` 尚未經 `/ux-review` 驗證。

**⚠️ CI 的暫時性守衛仍在**:`project.godot` 不存在時跳過測試並直接成功。**綠燈不代表測試通過**;移除條件寫在 `tests/README.md` 與 workflow 註解裡。

---

## 十、給第七輪的交代

**本輪的範圍限縮是一次性的,不建立慣例。** 第三次修訂後的 19 項 `TR-cursor-*` 涵蓋分佈**至今仍未被獨立推導**;若第四次修訂後仍不重推,ADR-0005 會在「連續兩次修訂未經涵蓋驗證」的狀態下逼近 `Accepted`。

**建議第七輪的範圍**:R6-6~R6-13 這 8 項是否確實關閉,**加上**游標系統 19 項的涵蓋分佈重推(這一項不可再延後)。130 項全域重推可維持沿用,前提是 GDD 仍零改動。
