# Remediation Validation Report — 2026-08-09（第一、二優先修訂後覆核）

**Date**: 2026-08-09（同日,`/review-all-gdds` 原始報告之後）
**Trigger**: 驗證同日對 `gdd-cross-review-2026-08-09.md` 第一優先（基線真實性）與第二優先（2026-08-07 修法傳播,B1/B2/B6/B7/B8/B9）所做的外科手術式修訂,本身是否引入新接縫
**Method**: 三個並行子審查（Phase 2 一致性 / Phase 3 設計理論 / Phase 4 情境走查),各自完整讀畢五份 GDD + entities.yaml,並以 `git diff` 比對本輪實際變動範圍

---

## 結論先行

**是——本輪修訂本身又引入了新的 Blocking 問題,連續第三次命中本專案的招牌失敗模式：「修法落在一處、其他複述同一事實的段落沒跟上」。**

合計新增：**一致性 5 項 Blocking、設計理論 1 項新 Blocking（+1 項既有 Warning 加重）、情境走查 4 項新 Blocker**。原本刻意延後的 5 項設計缺陷（C-1、C-2、D-1、F1、F3-1）與情境類 Blocker（F2-1、F2-2、F3-1）逐一查證，**全部確認仍在、未被誤修或誤標為已解決**——這部分修訂沒有破壞任何東西。

**使用者裁決**：停止繼續用自由發揮的外科手術式編輯追這個循環，先把現狀落盤，下一步另行決定（例如改用 `/design-review` 逐檔收斂，而非繼續自由編輯）。

---

## 一、正面確認：哪些修訂是乾淨的

- **B1（生命週期通知三條終止路徑）真正對稱關閉**：`affinity-data-pool.md` Edge Cases 與 `save-system.md` Core Rules #5 的三路徑定義結構一致，連帶關閉了 F1-2 的「單向孤兒義務」記載缺口（機制本身仍未定案，見下方新發現）。
- **B3、B8、B9（部分）、B10 主體、W9 已解決**：`entities.yaml` 的公式本體重新同步準確（7 個形狀子特徵、`t_query` 參數、`span_c`、公式四、移除被推翻的不等式，且反例逐字吻合源文件）；Section L 判準同步 Section M；game-concept.md 的初始游標狀態段落正確指向 cursor-highlight-state.md 定案內容。
- **AC-60/AC-61 編號無碰撞**，`save-system.md` 65 條 AC 計數與完備性執行紀錄表自洽。
- **「劇情事件為系統觸發寫入」措辭在五處（Overview / Core Rules #2 / Formulas 3g / game-concept.md / systems-index.md 第 175 列）全部一致**——這是本輪傳播做得最乾淨的示範，可作為未來修法的參考模板。
- **F4（三方 Status 不一致稀釋 ⛔ 閘門訊號）本輪唯一實質關閉**的設計理論級 Warning。

---

## 二、新增 Blocking：一致性（Phase 2）

🔴 **A-1｜`save-system.md` States and Transitions「拒絕讀取」列，仍載已被本文件自己判定為「主動誤導式資料遺失」的舊版兩分支告知文案**——本輪把 `systems-index.md` 登記表第 172 列同步成三級，卻漏了源文件自己的 States 表，現在登記表比它引用的權威來源更新。

🔴 **A-2｜`save-system.md` Core Rules #14「精確檔名比對」段落，對兩份備份的可存取情境宣稱與 Core Rules #13/AC-39 互斥，且沿用舊狀態名**——「僅…僅…」二分把 `.prev.bak`／`.pre_migration.bak` 各自綁死在一種拒絕原因上，兩個方向都與定案優先序牴觸。

🔴 **A-3｜`save-system.md` Dependencies 表仍寫「好感度數值池（已 Approved）」**——全庫唯一殘留的「現行狀態」誤稱，且與 `systems-index.md` Progress Tracker 新核算的「approved:0」直接矛盾。

🔴 **A-4｜`game-concept.md` 改寫後的裝置權威段落，誤述 `cursor-highlight-state.md` Core Rules #3 的實際規則**——把 B9 原本「兩份文件字面相反」的矛盾方向對調，而非真正消除；這是本輪**唯一新造**的跨文件矛盾（而非傳播遺漏）。

🔴 **A-5｜`systems-index.md` Cross-System Obligations Registry 第 152 列的義務本文，仍寫「須於非同步存檔架構下提供」，與同一列的關閉條件自相矛盾**——本輪的讀者提醒特地指向這一列，卻沒有改它的本文。

另有 15 項 Warning，含：「遷移失敗」殘留 4 處未傳播（Player Fantasy 段落）、`systems-index.md` 本輪新寫的列號自我引用 off-by-one、`entities.yaml` 的 `referenced_by` 未同步、`pure_combat_floor` 完全未登記入 entities.yaml、AC-68 情境數自我矛盾原樣照抄、兩份文件 Status 標頭把「同批已修好的發現」列成現存理由（造成讀者無法分辨哪些已修）。

---

## 三、新增 Blocking：設計理論（Phase 3）

🔴 **新 A-1｜`save-system.md` 的狀態更名確實動搖了 Player Fantasy 三級嚴重度論證**——States and Transitions 把 `DATA_CORRUPTED`（一般位元腐蝕）納入「拒絕讀取」狀態，但該狀態沒有任何自動痊癒路徑（Core Rules #13 的兩條自動路徑只涵蓋 `MIGRATION_FAILED`／`SEMANTIC_VALIDATION_FAILED`）。Player Fantasy「此取捨的殘餘成本」段落仍稱其為有終點的「殘餘成本」，但对经由位元腐蚀进入該狀態的槽而言，等待沒有終點——這實質是文件自訂排序中的第二嚴重級（要求玩家持續管理），而非殘餘成本級。今天的更名傳播批次動了規則側五處，唯獨跳過論證側的兩處舊名。

⚠️ 加重：**F2**（game-concept.md 的裝置權威權威讓渡，兩處皆未註記 cursor-highlight-state.md 目前是 Needs Revision 且帶 ⛔ 閘門與已確認鎖死缺陷）。
⚠️ 新增：**A-2/G-3**（affinity-data-pool.md 標頭承認 G-1，但 Player Fantasy 本文與 Implements Pillar 行未同步——文件內部出現「標頭否認、本體主張」的權威分歧）。

7 項既有設計理論 Blocking（B-1、C-1、C-2、D-1、E-1、F1、G-1）逐條原文查證，**全部仍然存在、描述仍然準確**（僅 G-1 末句「該文件 Status 為 Approved」因本輪狀態對齊而過期，其餘不變）。

---

## 四、新增 Blocking：情境走查（Phase 4）

🔴 **A-1｜三路終止漏掉第四支：遷移成功但 Core Rules #13 回寫 I/O 失敗（磁碟已滿、權限錯誤等），end 永不被呼叫**——原缺陷（旗標永久卡死）在這條未被枚舉的分支上原樣重現。

🔴 **A-2｜AC-61 建立在不可能成立的前提上**——旗標僅存於 affinity 的記憶體實例，行程當機後重啟是全新實例，不可能有「殘留旗標」可供偵測；AC-61 描述的成因與它意圖防守的情境彼此排斥。

🔴 **A-3｜begin/end 無重入計數，而 AC-59 明文允許跨槽並行遷移**——槽 B 遷移失敗觸發 end、旗標無條件清除，但槽 A 的遷移可能仍在進行中，保護因此被意外解除。

🔴 **A-8｜今天的失敗路徑修訂使 F4-2（單筆刻度遺失複合放大為整槽不可讀）由「被更嚴重的全面鎖死遮蔽」變為「可達」**——修訂前，遷移失敗會鎖死該 session 的所有寫入，Delta Log 保持空、不變量不會被違反；修訂後，旗標立即清除、寫入恢復，但被拒絕的那次刻度前進永遠不會重來，若發生在戰役第一次刻度前進，會直接觸發 AC-59b 非法向量、下次讀檔整槽拒絕讀取。

另兩項新走查發現：**B-4**（陣亡角色的 `t_query` 全文無任何持久化路徑，跨 session 讀取時靜默退化為它自己明文禁止的行為）、**B-6**（同版本、未觸發遷移的一般載入路徑——最常見的載入情境——落在 affinity「任何還原」判準與 save-system「只承諾遷移時呼叫 begin」的縫隙裡）。

F2-1、F2-2、F3-1 三項原有 Blocker **全部確認仍然存在，原描述準確**（F2-2 需精確化：「save-system.md 全文零提及游標」現應讀作「本文零提及，僅 Status 標頭以審查發現形式提及」）。F2-6（登記表第 172 列舊版誤導文案）是本輪唯一被完整關閉的情境層級發現。

---

## 五、下一步建議（未經使用者裁決，僅供參考）

1. **不要再用自由發揮的外科編輯繼續追。** 三個驗證 agent 一致指出：問題根源是「改一處、忘記同步複述同一事實的其他處」——這正是自由編輯模式的結構性弱點，不是這次做得不夠仔細。
2. 若要繼續收斂，建議改用 `/design-review [gdd路徑]` 逐檔跑完整模式對抗性覆核（這是本專案過去唯一多輪後真正收斂過的方法，例如 save-system.md 五輪），而非繼續在多份文件間手動同步同一組事實。
3. 累積至今的「必須同步一致」的事實清單已經相當長，建議下一輪修訂前先對這幾組關鍵詞做全庫 grep 掃描，一次性收斂，而不是逐段修訂：`拒絕讀取`/`遷移失敗`、三級告知文案（甲/乙/丙）、唯讀介面來源優先序、`非同步` vs `非原子視窗`、`已 Approved`/文件 Status、begin/end 生命週期的四種終止情境（含新發現的「回寫失敗」）。
4. 5 項原始新設計缺陷（C-1、C-2、D-1、F1、F3-1）+ 本輪新增的情境類發現（A-1/A-2/A-3/A-8、B-4、B-6）中，至少 C-2、F3-1、A-1（save-system 嚴重度論證）、A-3（begin/end 重入)建議一併走 creative-director 裁決，而非留給下游系統或下一輪自由裁量。
