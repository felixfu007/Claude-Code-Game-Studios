# 存檔系統(含跨規則集遷移)—— Design Review Log

> **紀錄壓縮政策**(2026-08-12,回應使用者對文本量的要求):已被後續輪次覆核過的舊輪次(第一輪至第六輪)的長篇散文 Summary 與逐條嚴重度裁決說明,已壓縮為條列/短句形式;**Revision list 表格(阻擋項 → 修訂內容,真正承載決策的部分)全數逐字保留,未刪減任何一列**。完整散文原文可從 git 歷史還原(每輪修訂皆有對應 commit)。第七輪(現行、尚未被下一輪覆核)維持完整記錄,依此政策本身「現行輪次不壓縮」的原則。多輪重複出現的「未隨此輪處理」清單已合併為下方單一的「架構階段待辦清單」,各輪條目只列出該輪**新增**的項目。

## 架構階段待辦清單(GDD 層無法解決,移交 `/create-architecture` 時的既定必辦項)

以下項目自第一輪起即被 creative-director 反覆確認為「沒有引擎接觸的情況下本質上無法在 GDD 層解決」,自第四輪起明文禁止任何後續輪次再將其列為阻擋。除非下方逐輪記錄另有註明新增項,否則每輪皆原封不動:

- 序列化格式本身(Resource/.tres vs 自訂格式)
- `FileAccess.flush()` 的 fsync 等效行為 / OS 當機情境下的硬體層級落盤查證
- `DirAccess.rename()` 平台語意
- 型別白名單(Core Rules #9)版本分域範圍
- `OS.get_thread_caller_id()`/`get_main_thread_id()`/`Resource.DEEP_DUPLICATE_ALL` 等 4.7.1 API 名稱查證
- `user://` 與 `.tmp`/`.dat` 須同檔案系統的前提
- Core Rules #13 自動痊癒路徑(二)的實際觸發機制與狀態轉換模型
- Steam Cloud(或其他雲端同步)與多檔案佈局的互動
- `max_supported_migration_depth` 數值上限
- `affinity-data-pool.md` AC-47 重開(該文件已 Approved,不主動重開)
- 完備性執行紀錄表的**全表**逐義務升級(U-3 甲案,第七輪裁定本輪不投入,由 Ledger S13 累積實證後再評估)

## Persistent Leftover Ledger(遺留項帳本)

追蹤非阻擋但需要持續觀察的項目。若某項連續 3 輪未被實際處置,下一輪自動升級為阻擋候選。

| 編號 | 內容 | 首次出現 | 現況 |
|---|---|---|---|
| S1 | `affinity-data-pool.md` 索引鍵持久化描述(enum 序數)與本文件 Core Rules #10(字串名稱)不一致 | R1 | **已畢業(R2)**——affinity 已同步新增段落 + AC-56 |
| S2 | AC-24 浮點容差待序列化格式定案後重新校準 | R1 | **已畢業(R5)**——移入 Open Questions,綁定格式決策閘門 |
| S3 | 遷移鏈孤兒終止函數歸屬未定義 | R1 | **已畢業(R5)**——移入 Open Questions,綁定「累積 3+ 規則集版本」閘門 |
| S4 | Player Fantasy「拒絕並告知」語氣與嚴重度表不對齊 | R1 | **已畢業(R2)**——依使用者裁決 A2 整段重寫 |
| S5 | 三個 Tuning Knob 旋鈕待實測校準,目前僅方向、無數值 | R1 | 待 UI 系統設計/架構階段實測填值;寬限上限規則本身已可稽核(R2/R3) |
| S6 | 主機平台是否為目標平台未定案 | R1 | **已畢業(R4)**——已確認 PC+Console 為既定目標,移入架構階段待辦清單 |
| S7 | 型別白名單版本分域範圍未定 | R2 | 已登記架構階段必辦項(單機無伺服器信任邊界,非 GDD 阻擋) |
| S8 | 自動痊癒路徑(二)維運重跑觸發機制/狀態轉換模型未定義 | R3 | 已登記架構階段必辦項;資料前提已保證(創世保留+完成標記),程序本身待架構階段 |
| S9 | 電源中斷下 `flush()` 硬體層級落盤保證未知 | R3 | 已登記架構階段必辦查證項;GDD 承諾範圍已縮小為僅保證進程層級當機 |
| S10 | 存檔目錄與 `.tmp`/`.dat` 須同檔案系統的前提未明文 | R3 | 已登記架構階段必辦項 |
| S11 | Steam Cloud 與多檔案佈局互動未評估 | R3 | 已登記 Open Question,待平台/發行策略定案 |
| S12 | Core Rules #10 退役名稱自動化檢查要到架構階段才建置,過渡期仍靠人工紀律 | R4 | 已補過渡期殘餘風險聲明;待架構階段自動化檢查交付、AC-51 可執行後畢業 |
| S13 | 完備性執行紀錄表仍以 Core Rule(非逐義務)為檢查單位——升級觸發條件於 R6 已成立卻未執行,R7 七項阻擋中五項落在此盲區 | R7 | 觸發條件已改寫為可稽核版本(見 `save-system.md`);**畢業條件為實證訊號**——若後續阻擋落在「未被該輪修訂過」的規則上即為全表升級的觸發訊號;若連續 3 輪阻擋皆落在被修訂規則上則畢業 |

---

## Review — 2026-08-05 — 第一輪(首次 `/design-review`)

**Verdict**: MAJOR REVISION NEEDED | **Scope**: XL
**Specialists**: game-designer、systems-designer、godot-specialist、qa-lead、performance-analyst、security-engineer、creative-director(綜合裁決)
**Blocking**: 24(去重)| **Recommended**: 6(即 Ledger S2-S4 等)

**Summary**:對「檔案本身損毀」防禦完整,但對自陳最嚴重的失敗模式——語意靜默改變(尤其 `Pair` enum 序數漂移導致存檔靜默還原成錯誤但合法的配對)——幾乎零防禦,5 位專家獨立收斂於此。次要:同步阻塞式寫入的決定被判定「花用過度」(用來永久關閉已 Approved 的 affinity AC-47);遷移鏈生命週期(回寫時機、確定性要求、後置條件檢查)大量未成文;執行緒模型自相矛盾(AC-8/9/14 隱含並發場景,與單執行緒假設衝突);序列化格式懸而未決連帶拖累 5 項阻擋。

**User decisions**:①序列化格式維持 Open Question,但立即鎖定 4 項格式無關的硬性護欄(字串名稱持久化/manifest 完整性標記/反序列化白名單/跨平台原子置換行為契約) ②F1 失敗粒度維持整份拒絕,Player Fantasy 明文寫出取捨理由 ③同步寫入只降格本文件語氣為 provisional,affinity AC-47 暫不重開,僅留交接註記 ④遷移回寫成功後立即覆蓋原槽,正式宣告自動痊癒保證

**Revision list(blocker → fix applied)**:

| # | 阻擋項摘要 | 修訂內容 |
|---|---|---|
| 1-2 | 語意驗證/manifest 完整性缺失 | 新增 Core Rules #7(語意驗證)、#8(manifest 完整性標記);新增 AC-28、AC-31 |
| 3 | Pair enum 序數漂移零防禦 | 新增 Core Rules #10(字串名稱持久化+對照表);AC-25 改寫,新增 AC-29 |
| 4 | 遷移後置條件缺失 | 新增 Core Rules #12;新增 AC-32 |
| 5 | Resource schema 寬容 vs 拒絕靜默補值衝突 | 由 Core Rules #7/#9 的護欄涵蓋,不待格式決定 |
| 6 | 同步寫入決定越權花用 | Core Rules #4 改標 provisional,列出重新啟用時需回補的介面清單 |
| 7 | OQ9 循環引用 | Formulas 章節改寫,移除「因資料量微小故阻塞非問題」的推論 |
| 8 | 短暫卡頓未量化 | 新增 Tuning Knob `save_write_max_duration_ms`;新增 AC-36 |
| 9 | 主機平台同步假設未證成 | 新增「平台範圍聲明」段落 + Open Question,標記 PC-only 為目前情境 |
| 10 | 遷移失敗 UI 零約束 | Interactions with Other Systems 新增最低呈現契約 |
| 11 | 回寫規則不成文 | 新增 Core Rules #13(含自動痊癒保證);States 表「遷移失敗」離開條件改寫 |
| 12 | 遷移鏈載入時間無預算 | 新增 Tuning Knob `migration_chain_load_time_budget_ms` |
| 13 | 缺複合鏈測試 | 新增 AC-34 |
| 14 | 當機安全論證引用鏈待修 | Edge Cases 改寫引用至 Core Rules #11/#13 |
| 15 | 遷移函數確定性未要求 | 新增 Core Rules #11;新增 AC-33 |
| 16 | 執行緒模型自相矛盾(AC-8/9/14) | Core Rules #4 新增單執行緒假設聲明;AC-8/AC-14 改寫移除並發語意 |
| 17-20 | 平台 rename 語意/AC-12 措辭/Resource 共享參照 | 新增 Core Rules #14(行為契約非機制假設);Open Questions 更新 |
| 21 | Resource 任意類別反序列化風險 | 新增 Core Rules #9(型別白名單);新增 AC-30 |
| 22 | F1 失敗粒度未被檢視 | Player Fantasy 新增「取捨聲明」段落 |
| 23 | 自動痊癒是否為正式保證未言明 | Core Rules #13 明文宣告;新增 AC-35 |
| 24(G1) | 標頭美學支柱誤分類 | 標頭 Implements Pillar 改寫為支柱二持久化承載層 |

**Prior verdict resolved**: 首次審查,無前次判決。
**未隨此輪處理**: 見文首「架構階段待辦清單」;另有 `max_supported_migration_depth` 數值上限、affinity AC-47 重開,皆使用者本輪明確裁定延後。

---

## Review — 2026-08-05 — 第二輪(完整模式對抗性重新覆核)

**Verdict**: NEEDS REVISION | **Scope**: XL | 本輪修訂量:M–L
**Specialists**: game-designer、systems-designer、godot-specialist、qa-lead、performance-analyst、security-engineer(六位並行)、creative-director(綜合裁決)
**Blocking**: 9(去重)| **Recommended**: 14 | **Nice-to-have**: 5

**Summary**:R1 是「防線不存在」,R2 是「防線都在,但預設值都設反了(fail-open)」——R1 新增的語意防禦層(#7/#8/#10/#12+#13)存在五處獨立 fail-open 邊界,全指向文件自陳最毒的失敗類別。最高優先(B1,三方收斂:systems-designer/security-engineer/game-designer):有 bug 的遷移函數只要輸出滿足 #12 結構性後置條件就會判定成功並觸發不可逆覆寫,自動痊癒永遠救不到。creative-director 另發現 Player Fantasy 三級嚴重度排序清單順序與取捨聲明文字矛盾,是本輪唯一需使用者裁決項。設計本身(manifest+版本化區塊+逐步遷移+原子置換)健全,無方向性錯誤。

**User decisions**:①嚴重度排序以取捨聲明為準(A2)——要求玩家管理存檔=第二嚴重,比可見中斷更糟;F1 整份拒絕政策維持且理由成立 ②採納「遷移成功回寫時保留遷移前原始位元組」修法(B-甲),代價約 2 倍已遷移槽檔案大小(可忽略),同時解掉 B1/B7 最壞後果

**Revision list(blocker → fix applied)**:

| # | 阻擋項摘要 | 修訂內容 |
|---|---|---|
| B1 | 遷移「假通過→立即不可逆覆寫」,自動痊癒永遠救不到 | Core Rules #13 重寫,新增「原始位元組保留」機制(存底檔案 + 唯讀存取契約)與自動痊癒保證擴大範圍;Core Rules #7 新增「語意驗證同樣套用於遷移輸出」;新增 AC-37/38/39/45 |
| B2 | Core Rules #7 語意驗證是 opt-in,預設 fail-open | 新增「驗證器宣告為強制項,未宣告視為錯誤」規則,manifest 缺驗證器宣告視為 `DATA_CORRUPTED`;新增 AC-44 |
| B3 | Core Rules #10 不涵蓋退役索引鍵名稱再利用 | 新增「退役名稱治理規則」(退役名稱永久保留、不得重新指派);新增 AC-41/42;`affinity-data-pool.md` 同步新增對應段落與 AC-56 |
| B4 | 完整性標記三重開口(位元組筆數/雜湊擇一、AC-28 未指定等長竄改、雜湊未涵蓋身分中繼資料) | Core Rules #8 改為強制雜湊、雜湊須涵蓋身分+版本中繼資料、新增威脅模型範圍聲明;AC-28 明確指定等長竄改;新增 AC-43 |
| B5 | Core Rules #14 自舉的原子置換範例違反自己的契約 | 撤回「刪除舊檔前置檢查」範例,改為具體安全序列(暫存寫入→現有檔案 rename 為備份→暫存 rename 為目標→刪除備份);新增讀取端 `.bak` 回復規則 |
| B6 | Player Fantasy 三級嚴重度排序自相矛盾 | 依使用者裁決 A2,清單順序改寫(要求玩家管理存檔=第二嚴重),取捨聲明措辭同步修正,新增「此取捨的成立前提」段落 |
| B7 | 遷移失敗/語意驗證失敗沒有有界出路 | Core Rules #6 新增第四類拒絕原因代碼 `SEMANTIC_VALIDATION_FAILED`;States 表遷移失敗列新增唯讀存取說明;Core Rules #13 自動痊癒保證新增第(三)款涵蓋同版本語意驗證失敗;新增 AC-45 |
| B8 | AC-8/AC-14 第一輪靠拿掉測試消除矛盾而非釐清設計 | AC-8 重新指派為測試主執行緒斷言是否被強制;AC-14 移除並發框架,改測狀態查詢介面;新增 Core Rules #15「可觀測性義務」 |
| B9 | 遺留項 S1 錯誤綑綁,應解綁單獨處理 | `affinity-data-pool.md` Dependencies 新增索引鍵持久化方式段落 + 新增 AC-56,刻意不觸及 AC-47/同步-非同步議題 |

**Recommended revisions applied(同批完成)**:版本過新呈現須框為「可回復」;AC-36 拆分三段子成本量測至新 H 節;新增 AC-38(遷移後回寫途中當機的中斷安全性);Player Fantasy 承諾範圍限定至「已成功寫入的最後一個進度邊界」;AC-36 新增寬限上限規則;新增遷移函數複雜度上限(O(區塊自身筆數));AC-24 新增 N=0 情境測試(AC-24b);最低呈現契約新增「遷移進行中須有進度呈現」;Open Questions 補充型別白名單相容性成本權衡、`duplicate_deep()` 交接註記;標題「Detailed Design」更名「Detailed Rules」。

**個別專家嚴重度改判**:型別白名單版本分域 BLOCKING→架構階段必辦項(Ledger S7);遷移+回寫複合阻塞成本 BLOCKING→建議(框架套錯,已透過 Tuning Knobs+AC-46 解決);20-50 步深遷移鏈壓測 BLOCKING→延後(綁定 `max_supported_migration_depth`);重開 #4 需回檢 Player Fantasy RECOMMENDED→Nice-to-have。

**Prior verdict resolved**: 是——R1 24 項全數修訂,R2 對抗性覆核發現新 9 組阻擋,同 session 全數處理完成。
**未隨此輪處理**: 見架構階段待辦清單;S2/S3 本輪主動延後(見 Ledger)。

---

## Review — 2026-08-05 — 第三輪(完整模式對抗性重新覆核)

**Verdict**: NEEDS REVISION | **Scope**: XL | 本輪修訂量:M
**Specialists**: game-designer、systems-designer、godot-specialist、qa-lead、performance-analyst、security-engineer(六位並行)、creative-director(綜合裁決)
**Blocking**: 11(去重)| **Recommended**: 10 | **Nice-to-have**: 3

**Summary**:三輪定性演進:R1「防線不存在」→R2「防線設反(fail-open)」→R3「防線都設對了,但接縫未言明」。十一項阻擋無一指向架構方向錯誤。最高優先(四方收斂:systems-designer/godot-specialist/qa-lead/performance-analyst):#13(存底建立)與 #14(原子置換)寫入時序未定義,存底可能「從未建立就被沖銷」,AC-38 未覆蓋。次高(四方收斂+creative-director 資深審查追加):`.pre_migration.bak` 單代保留在連續兩次遷移下會被覆蓋,反證「最後一道防線」宣稱。第三(三方收斂):#10 退役名稱治理規則是文件自陳最高風險項,卻是本輪唯一未 fail-closed 的規則。creative-director 另查證發現:`source_i` 欄位從未被 #10 涵蓋,面臨與 `Pair` 相同的序數漂移風險;affinity Open Question 5 殘留與 #10 矛盾的舊敘述(顯示 R2 ledger S1「已解決」判定只驗證新交付物存在,未驗證舊矛盾敘述已移除)。performance-analyst 發現:R2 新增的「遷移進行中須有忙碌指示」與 #4 同步阻塞模型結構性不相容——單一阻塞式主執行緒呼叫期間連轉圈動畫都畫不出來。

**User decisions(D-1~D-5)**:①**D-1 存底保留策略:甲——創世保留**,只保留槽第一次遷移前的存底,永不覆寫 ②**D-2 遷移執行模型:乙——分步執行**,每次只執行一個版本躍遷,步間讓出控制權;互動情境改走 manifest-only 輕量讀取 ③**D-3 自動痊癒路徑(二)修補深度:乙-lite——遷移完成標記+重放**,僅對「僅追加」型區塊(好感度池 Delta Log)保證無損拼接 ④**D-4 一般位元腐蝕是否也備份:乙——滾動保留一代**,步驟四由「刪除備份」改為「rename 為 `.prev.bak`」 ⑤**D-5 Player Fantasy 取捨成立前提自我矛盾:甲——誠實重新計價+補溝通要求**,承認等待/放棄決定為持續性殘餘成本,唯讀匯出定位為「零代價保險」

**Revision list(blocker → fix applied)**:

| # | 阻擋項摘要 | 修訂內容 |
|---|---|---|
| R3-B1 | #13(存底建立)與 #14(原子置換)寫入時序未定義,存底可能「從未被建立就被沖銷」,AC-38 未覆蓋(四方獨立收斂) | #13 新增兩階段寫入順序(存底須先確認完成才進入置換);#14 新增步驟零(補完上次未完成的步驟四)、精確檔名比對規則;AC-38 改寫為三結果模型並新增存底斷言;新增 AC-48 |
| R3-B2 | 單代 `.pre_migration.bak` 保留在連續兩次遷移下會被覆蓋(四方收斂,使用者裁決 D-1) | #13 保留策略改為「創世保留」(第一次遷移前的存底永久保留);AC-37 新增連續兩次遷移驗證;Edge Cases 同步修正 |
| R3-B3 | #10 退役名稱治理規則零自動化執行,是文件最高風險項卻唯一未 fail-closed(三方收斂) | #10 由「治理紀律」升級為硬性規則,要求架構階段提供自動化檢查;新增 AC-51 |
| R3-B4 | `source_i` 欄位從未被 #10 涵蓋,面臨與 `Pair` 相同的序數漂移風險(creative-director 追加發現) | #10 範圍擴大為「索引鍵與任何持久化列舉欄位」;新增 AC-49/50;affinity 同步擴大並新增 AC-57 |
| R3-B5 | affinity Open Question 5 殘留與 #10/Section M 矛盾的舊敘述,R2 ledger S1「已解決」判定未驗證舊敘述已移除(qa-lead) | affinity Open Question 5 該句刪除並改寫,明確指向 Section M/AC-56/AC-57 |
| R3-B6 | #13 唯讀存底存取介面未要求重跑 #7/#8/#9(security-engineer) | #13 新增規則:唯讀介面須重新套用型別白名單與完整性雜湊檢查;新增 AC-53 |
| R3-B7 | manifest 缺少涵蓋自身區塊清單的完整性標記,交互 AC-24b 後意外消失的區塊會被讀成合法空狀態(security-engineer) | #8 新增涵蓋整份區塊清單的頂層完整性標記;新增 AC-52 |
| R3-B8 | 忙碌指示要求與 #4 同步阻塞模型結構性不相容(performance-analyst,使用者裁決 D-2) | #4 範圍限定為一般寫入路徑;新增 #5「遷移執行模型」小節(分步執行);#15 新增遷移進度查詢介面;新增 AC-14b;互動情境須走 manifest-only |
| R3-B9 | 自動痊癒路徑(二)觸發機制/狀態模型/專屬 AC 皆缺,且會靜默毀掉遷移後合法進度(合併,使用者裁決 D-3) | #13 路徑(二)措辭由「保證」降為「資料前提已保證,程序留待架構階段」;新增遷移完成標記機制;AC-37 新增範圍聲明 |
| R3-B10 | Player Fantasy「此取捨的成立前提」自我矛盾(game-designer,使用者裁決 D-5) | 段落改寫為「此取捨的殘餘成本」;States 表、Interactions 同步新增強制主動告知要求 |
| R3-B11 | `flush()` 耐久性與 Edge Cases 對斷電的無條件承諾不符(godot-specialist) | #14 新增耐久性範圍聲明(僅保證進程層級當機);Edge Cases 同步修正 |

**Recommended revisions applied(同批)**:AC-7 措辭改可核對斷言;AC-46 補四段子成本拆分;AC-38 三結果模型同時新增 AC-48;遷移鏈耗時「深度×資料量」關係補入 Tuning Knobs;`user://` 同檔案系統前提、`store_*` 布林回傳值檢查、`OS.get_thread_caller_id()` API 查證新增 Open Questions;AC-36 寬限上限規則補精確觸發條件;Steam Cloud 互動新增 Open Questions;新增 Core Rules #16「規則交互矩陣」(creative-director 結構性建議,十一項阻擋中六項「規則接縫未言明」問題的最有效單一收斂改動)。

**個別專家嚴重度裁決**:AC-36 寬限期可被遊戲、AC-46 缺子成本拆分 BLOCKING→RECOMMENDED(流程衛生非正確性);互動情境呼叫限制建議→上調為 D-2 必要條款;合成 N 步 no-op 遷移鏈量測 Nice-to-have→RECOMMENDED(R2 誤判可測性);Steam Cloud 互動 Nice-to-have→RECOMMENDED(R3 新增備份機制放大風險面)。

**Prior verdict resolved**: 是——R2 9 組阻擋全數修訂,R3 對抗性覆核發現新 11 組阻擋(6 項接縫未言明、3 項過度承諾措辭、2 項範圍遺漏),同 session 全數處理完成。
**未隨此輪處理**: 見架構階段待辦清單;S2/S3 再次記錄為主動延後,連續 2 輪未達自動升級門檻。

**收斂觀察**:阻擋數 24→9→11,非單調收斂。R3 已達「同輪新增規則接縫未言明」終末類別。**R4 退場條件**:只驗證三性質(時序完整性/承諾可證成性/跨文件一致性含舊段落),不開新領域,通過即應 APPROVED、移交架構階段。

---

## Review — 2026-08-06 — 第四輪(完整模式對抗性重新覆核,聚焦三性質)

**Verdict**: NEEDS REVISION | **Scope**: XL | 本輪修訂量:**S**(三輪以來首次降到 S)
**Specialists**: game-designer、systems-designer、godot-specialist、qa-lead、performance-analyst、security-engineer(六位並行,聚焦三性質)、creative-director(綜合裁決)
**Blocking**: 8(去重,含 2 項嚴重度改判)| **Recommended**: 12 | **Nice-to-have**: 5

**Summary**:creative-director 逐條查證確認:本輪 8 項阻擋**全部**源自 R3 D-1~D-5 新增規則自身缺了「矩陣列/專屬 AC/範圍聲明」三件套之一——修訂流程本身的交付完整性缺口,非新設計缺陷。定性:R1「防線不存在」→R2「設反」→R3「接縫未言明」→**R4「R3 修法自己的接縫未言明」**。三組跨專家收斂:①路徑(二)維運拼接完整性重算義務缺失(三方收斂,本輪最高優先)②分步執行同槽重入視窗未被宣告(godot-specialist+performance-analyst,與 systems-designer 降級判定分歧,creative-director 裁決維持 BLOCKING)③D-4 滾動備份接縫(security-engineer+godot-specialist)。另意外發現 `technical-preferences.md` 與 `game-concept.md` 對主機平台矛盾,使用者裁決以前者為權威。

**User decisions**:①平台矛盾:採納 creative-director 建議,以 `technical-preferences.md`(PC+Console)為權威回頭修訂 `game-concept.md` ②創世存底冗餘保護(原 D-6):不需使用者裁決,採 creative-director 代裁方向(誠實下修措辭+條件式告知,不加碼保護等級)

**Revision list(blocker → fix applied)**:

| # | 阻擋項摘要 | 修訂內容 |
|---|---|---|
| R4-B1 | 路徑(二)維運拼接完整性重算義務缺失,遷移完成標記本身不受任何完整性保護(三方獨立收斂,本輪最高優先) | Core Rules #8 頂層雜湊輸入 tuple 擴充涵蓋遷移完成標記;Core Rules #13 路徑(二)新增第 4 項硬性前提(拼接後須重算逐區塊+頂層雜湊);Core Rules #16 矩陣新增對應列;新增 AC-61 |
| R4-B2 | 分步執行引入的同槽重入不變量從未被宣告(godot-specialist+performance-analyst 收斂,creative-director 裁決維持 BLOCKING) | Core Rules #5 新增同槽重入不變量(同槽分步執行期間拒絕第二個讀/寫呼叫);矩陣補反面宣稱;新增 AC-59 |
| R4-B3 | D-4 滾動備份步驟四自我違反步驟零存在理由,含永久卡死風險;`.prev.bak` 未被 #13 逐字枚舉涵蓋(兩方收斂) | Core Rules #14 新增步驟 4a(rename 前先刪除既有 `.prev.bak`);#13 唯讀介面枚舉擴大涵蓋 `.prev.bak` |
| R4-B4 | manifest-only 輕量讀取介面零 AC、零矩陣覆蓋(game-designer) | Core Rules #5 manifest-only 段落新增完整性檢查要求(須套用 #8 頂層標記檢查);新增 AC-60 |
| R4-B5 | 創世存底無位元腐蝕保護,Player Fantasy「與正常存檔同等完整」為過度宣稱(qa-lead,creative-director 代裁) | Player Fantasy 措辭改為「逐位元組相同」(內容等同非保護等級等同)+ 補殘餘風險聲明;強制主動告知改為條件式 |
| R4-B6 | 承諾可證成性掃描三處殘留:遷移檢查失敗零副作用未斷言;#10「升級為硬性規則」未揭露過渡期殘餘風險;Player Fantasy「玩家從不需想到存檔」未加註範圍(合併) | AC-32 擴充斷言範圍;#10 新增過渡期殘餘風險聲明+Ledger S12;Player Fantasy 加註範圍聲明 |
| R4-B7 | Cross-System Obligations Registry 對本文件施加的八項硬性義務零列登記(game-designer 發現 RECOMMENDED,creative-director 上調 BLOCKING——D-5 論證完全依賴下游 UI 執行主動告知義務,承接系統看不到義務,D-5 價值靜默歸零) | `systems-index.md` Registry 新增 8 列 |
| R4-B8 | 主機平台矛盾——`technical-preferences.md` vs `game-concept.md`(game-designer) | 見上方 User decisions;`game-concept.md`/`save-system.md` 同步修訂;Ledger S6 畢業 |

**Recommended revisions applied(同批)**:矩陣第二列補「逐步驟」措辭;矩陣新增讀取路徑排序列;Tuning Knobs 儲存倍數區分穩態(3×)與峰值(4×);遷移鏈耗時模型補加性下限;AC-46 拆分兩子項;#8 頂層雜湊「固定順序」明確定義為規範順序;Formulas 補交叉引用;`Resource.DEEP_DUPLICATE_ALL` 等 API 標記待查證;affinity Open Questions 新增反向引用;Ledger S2/S3 記錄重新評估已發生。

**個別專家嚴重度裁決**:分步執行同槽重入 BLOCKING(godot+performance)vs NICE-TO-HAVE(systems-designer)→維持 BLOCKING;讀取管線順序 BLOCKING(game-designer)vs RECOMMENDED(systems-designer)→降 RECOMMENDED(#8 已有明文排序,矛盾是矩陣未鏡射);矩陣檢查粒度 BLOCKING→降 RECOMMENDED;4×峰值/AC-46混雜/耗時模型加性下限三項 BLOCKING→皆降 RECOMMENDED(效能類既有降級標準);Registry 零登記 RECOMMENDED→上調 BLOCKING(理由見 R4-B7)。

**Prior verdict resolved**: 是——R3 11 組阻擋全數修訂,R4 對抗性覆核發現新 8 組阻擋(全部源自 D-1~D-5 三件套缺漏,非新設計缺陷),同 session 全數處理完成。
**未隨此輪處理**: 見架構階段待辦清單。

**收斂觀察**:阻擋數 24→9→11→8,首次降到個位數區間附近。**R5 退場條件**:只驗證兩件事——①本輪修法有無製造第九個接縫(用矩陣完備性檢查表機械掃描)②矩陣完備性檢查表本身是否完備(每條 Core Rule 都有矩陣列或無約束宣告,每條新規則都有 AC)。若通過即 APPROVED、移交架構階段;若仍出現 5 項以上**新類別**阻擋才是真正天花板訊號。

---

## Review — 2026-08-07 — 第五輪(完整模式對抗性重新覆核,聚焦兩項退場條件)

**Verdict**: NEEDS REVISION | **Scope**: XL | 本輪修訂量:**S**(與 R4 同級)
**Specialists**: game-designer、systems-designer、godot-specialist、qa-lead、performance-analyst、security-engineer(六位並行,聚焦「R4 修法有無新接縫」與「矩陣完備性檢查表本身是否完備」)、creative-director(綜合裁決)
**Blocking**: 11(去重,含 3 項嚴重度分歧裁決)| **Recommended**: 4(S2/S3 畢業 + performance-analyst 3 項併入)

**Summary**:creative-director 逐條查證確認:本輪十一項阻擋**全部**溯源至 R4 具體修法或 R4 新增的矩陣完備性檢查表本身,沒有開新領域,沒有依賴已裁定「GDD 層無法解答」的項目——六位專家守住退場條件劃定的紀律。定性:**R5「防呆機制建好了,但從未對自己執行過」**——十一項中五項是 R4 新增的完備性檢查表該抓卻只套用在當輪八項阻擋上、沒套用在為修那八項而寫的新條款上;一項是檢查表漏了自己(矩陣缺 #1/#2/#3/#15/#16,五位專家獨立收斂,本輪跨最多專家收斂發現)。最高優先(systems-designer+security-engineer,值語意/寫入責任兩角度收斂):#8 頂層雜湊新納入的「遷移完成標記」欄位,R4 只把語意寫在路徑(二)前提清單裡,從未指派任何規則實際寫入它——路徑(二)機制形同虛設。第二優先(godot-specialist):#14 步驟零文字只涵蓋步驟四,未同步涵蓋 R4 新增的步驟 4a,會經另一路徑重現永久卡死風險。第三優先(三方收斂):#15「僅供 QA/除錯用途」定位與其被登記為下游硬性義務的實際用途字面矛盾,且與 #5 同槽重入不變量交互未定義,AC-14b 與 AC-59 可被誤讀為互斥。security-engineer 另發現 #10 過渡期殘餘風險聲明低估曝險(未伴隨版本躍遷的重用情境現有防線零覆蓋)。game-designer 發現唯讀匯出資料技術宣稱與 #13/States 泛化優先序矛盾;`systems-index.md` 第 164 列雙義務單關閉條件。qa-lead 發現 AC-61 前提在路徑二觸發機制交付前不可執行;Ledger S2/S3 欄位自相矛盾且已達 3 輪觀察窗。performance-analyst 本輪**零 BLOCKING**。

**嚴重度分歧裁決**:performance-analyst「矩陣缺 #15」RECOMMENDED vs 其餘四位 BLOCKING→裁決 BLOCKING(文件自訂硬性要求,缺列確實產生實害);game-designer「步驟 4a 缺 AC」RECOMMENDED vs systems-designer BLOCKING→裁決 BLOCKING(合併後是「檢查表未對自己執行」的證據集合);godot-specialist「manifest-only 重入範圍」RECOMMENDED→上調並併入介面分類表。

**Revision list(blocker → fix applied)**:

| # | 阻擋項摘要 | 修訂內容 |
|---|---|---|
| R5-B1 | 遷移完成標記寫入責任與值語意全面未定義,路徑(二)機制實質形同虛設(本輪最高優先,三方獨立收斂) | Core Rules #13 新增「遷移完成標記的寫入責任與值語意」段落(寫入責任指派給階段 B 每次一般遷移回寫;非追加型區塊恆為顯式 `null`);新增 AC-62、AC-63 |
| R5-B2 | Core Rules #14 步驟零文字未涵蓋步驟 4a,經另一路徑重現永久卡死風險(godot-specialist) | 步驟零改為「依序」補完 4a 與步驟四;新增 AC-66 |
| R5-B3 | Core Rules #15 定位自相矛盾+與 #5 同槽重入不變量交互未定義,AC-14b 與 AC-59 字面互斥(三方合併) | #15 拆分為甲類(診斷)/乙類(可觀測狀態,生產介面);新增介面分類表;#5 重入規則明確排除三個豁免介面 |
| R5-B4 | AC-59「該槽處理中」缺結構化定義(兩方收斂) | #5 新增「該槽處理中」結果性質段落(比照 AC-4「無資料」既有範式);新增 AC-67 |
| R5-B5 | Core Rules #16 矩陣完備性檢查表自我違反,#1/#2/#3/#15/#16 缺列或無約束宣告(五位專家獨立收斂,本輪跨最多專家收斂發現) | 矩陣新增 7 列/宣告 |
| R5-B6 | Core Rules #13 唯讀介面優先序兩處破口:Player Fantasy 技術宣稱與實際優先序矛盾;`.prev.bak`/`.pre_migration.bak` 優先順序未定義(game-designer) | Player Fantasy 措辭改為泛用「依優先序回傳當下可安全解析的最新完好內容」;#13 明訂 `.prev.bak` 優先於 `.pre_migration.bak`;AC-39 同步 |
| R5-B7 | R4 新增條款缺專屬 AC 三處:步驟 4a、#8 固定順序規範、步驟零補完行為(兩方收斂) | 新增 AC-64、AC-65、AC-66(與 R5-B2 共用) |
| R5-B8 | AC-61 前提在路徑二觸發機制交付前完全不可執行,未標註(qa-lead) | AC-61 新增不可執行狀態聲明,併入 Ledger S8 |
| R5-B9 | Core Rules #10 過渡期殘餘風險聲明低估曝險(security-engineer) | 新增「曝險範圍的精確化」段落,區分伴隨/未伴隨版本躍遷兩種子情境 |
| R5-B10 | `systems-index.md` 第 164 列雙義務單關閉條件(game-designer) | 第 164 列拆分為兩列,各自獨立關閉條件 |
| R5-B11 | Ledger S2/S3 欄位自相矛盾,客觀已達 3 輪觀察窗(qa-lead) | 比照 Ledger S6 範式,S2/S3 從 Ledger 畢業,移入 Open Questions 並各自綁定閘門 |

**Recommended revisions applied(同批)**:#13 路徑(二)雜湊重算義務新增耗時量級聲明;Tuning Knobs 4×峰值新增路徑(二)範圍聲明;新增「Completeness Execution Record」完備性執行紀錄表(16 條 Core Rules × 三件套執行狀態、67 條 AC × 可執行性標註)——creative-director 指定此表為本輪移交條件本身。

**Prior verdict resolved**: 是——R4 8 組阻擋全數修訂,R5 對抗性覆核發現新 11 組阻擋(全部溯源 R4 修法或檢查表自身,非新設計缺陷),同 session 全數處理完成。
**未隨此輪處理**: 見架構階段待辦清單。AC-24 浮點容差(原 S2)、遷移鏈孤兒終止函數歸屬(原 S3)已從 Ledger 畢業移入 Open Questions。

**終止條件重新校準**:嚴格按 R4 判準(5 項以上新類別阻擋)——非天花板,0 項新類別,11/11 全部溯源。但阻擋數 24→9→11→8→11 非單調,creative-director 改採「找到的問題若不修,不會讓實作者建錯東西」為終止條件——本輪符合。**建議修訂完成後無條件移交架構階段,不安排第六輪**,理由:完備性執行紀錄表使本輪從「專家抽樣」升級為「構造上窮盡」。

---

## Approval — 2026-08-07 — 使用者裁決:核准,跳過第六輪

R5 十一項阻擋已同 session 全數修訂完成。creative-director 建議修訂完成後無條件移交架構階段、不安排第六輪,理由:新增的完備性執行紀錄表使本文件從「經過五輪專家抽樣審查」升級為「經過一次構造上窮盡的完備性檢查」。

**使用者裁決**:採納建議,核准本文件跳過第六輪 `/design-review`,狀態由 Designed 改為 **Approved**。`systems-index.md` 對應列與 Progress Tracker 同步更新。

**移交條件自我檢驗(供架構階段參照)**:三個可驗證訊號——①架構階段回頭提出的問題應全部落在既有 Open Questions 列之內 ②Completeness Execution Record 應在架構階段被實際引用查核規則約束 ③R5-B1 遷移完成標記的寫入時機決定不應在架構階段被重開。若前期出現三個以上「這條規則讀不出該怎麼實作」的回頭詢問,應視為本次核准過早的訊號,回頭補一輪 `/design-review`。

---

## Review — 2026-08-11 — 第六輪(完整模式對抗性覆核,聚焦四項既有殘留缺口)

**Verdict**: NEEDS REVISION → 已於同一 session 內完成修訂
**Scope**: L(六位專家原始評估;security-engineer 意外發現的完整性鏈條缺口經使用者核准擴大範圍後,實際落地範圍與原 L 一致,未升級為 XL)
**Specialists**: systems-designer、security-engineer、narrative-director、godot-specialist、game-designer、qa-lead(六位並行,分別聚焦四項缺口)、creative-director(綜合裁決)
**Blocking**: 10(B1-B10)| **Recommended**: 3(未落地,列未來輪次參考)

**背景**:處理三項自 2026-08-09 `/review-all-gdds` 起長期擱置的跨文件殘留缺口(D-1 `source_absence` 可逆性、F2-1 AC-23 vs cursor Core Rules #7 真矛盾、F2-2 存檔載入後游標失效)以及「三路終止漏第四支」(遷移語意成功但 Core Rules #13 回寫因 I/O 失敗未完成,`end` 永不呼叫)。

**Summary**:六位專家逐一交出具體修法草案,四項缺口方向皆收斂,無僵局分歧。**security-engineer 意外發現的伴生缺口是本輪最重要的技術發現**:Core Rules #8 的雜湊涵蓋範圍被四輪修訂寫到極其精確,卻從未定義雜湊輸入的**來源**——若取自「寫入後讀回的磁碟位元組」而非「寫入前已驗證的記憶體資料」,一次磁碟已滿造成的截斷寫入會被如實雜湊、manifest 與 payload 永久自洽,現有兩層雜湊防線對此完全無感,不需要任何攻擊者。同時 Core Rules #14「確保內容完整寫入並 flush」從未指定任何檢查機制。qa-lead 獨立發現 Completeness Execution Record 表二本身已存在一處實證矛盾(標題「68 條」,結尾結果句仍寫「65 條」「63 條」)。

**creative-director 綜合裁決核心論點**:①第四路徑與完整性鏈條缺口共用觸發情境但缺陷類別不同,立為獨立議題但同輪處理 ②D-1 修正 narrative-director 對「終局快照」方案的成本估算,提出第三方向 A+(終局判定+過程中誠實告知) ③F2-1 駁回「消費者導向」判準,改採「登記制」(以共用列舉登記為唯一判準),理由是消費者導向判準會讓管轄範圍隨未來下游設計選擇悄悄改變 ④F2-1 與 F2-2 須共用同一個「暫停選單內讀檔」情境定義,錨點為 `save-system.md` Core Rules #5「觸發情境限制」。

**本輪使用者裁決(三項)**:①D-1 修法方向:**選擇 A+(終局判定+過程中誠實告知)**——`source_absence` 移出 game-concept.md「單調不可逆」豁免清單,僅得於戰役終局判定當下呼叫一次判定互斥獨佔內容,戰役中途得以可逆的事實呈現現況但不得宣稱永久關閉 ②處理範圍:**選擇擴大為五項**,security-engineer 發現的完整性鏈條缺口同輪一併處理 ③下一輪覆核模式:**選擇目標型,3 位專家**(systems-designer/qa-lead/godot-specialist),附退場條件「若目標型覆核發現任一項修法製造了新接縫,即升級為完整模式重跑」

**本輪修訂內容(10 項阻擋全數同 session 內修訂完成)**:

| # | 阻擋項摘要 | 修訂內容 |
|---|---|---|
| B1 | Core Rules #8 雜湊輸入來源全文未定義,可能讓截斷寫入被誤判成功;#13/#14「確保完整寫入」缺乏具體檢查機制 | #8 新增「雜湊輸入來源定案」段落(寫入前記憶體資料,非讀回位元組);#14 步驟 1 新增「確保」的具體定義;#13 階段 A 明文繼承此義務;新增 AC-74、AC-75 |
| B2 | Core Rules #5 三路終止漏第四支(遷移成功但回寫 I/O 失敗,`end` 永不呼叫) | 新增路徑(四),保證呼叫 `end`(前提繫於 #4 現行同步阻塞模型);槽狀態維持「待遷移」,不新增拒絕原因代碼;新增 AC-73;新增重複失敗可觀察性義務(AC-76) |
| B3 | AC-10 合併「進程終止」與「注入寫入失敗」,掩蓋兩者依賴不同保證機制的事實 | 拆分為 AC-10a(進程終止)/AC-10b(寫入失敗注入) |
| B4 | Dependencies 章節三處落差(「兩條路徑」與 #5 本體「四條路徑」不同步、「無上游依賴」與 begin/end 強制呼叫矛盾、與游標系統零登記依賴) | 生命週期通知段落改寫為四條路徑完整描述;「Foundation 層」措辭修正區分定案依賴與執行期呼叫依賴;新增對游標系統的資訊性交叉引用 |
| B5 | Completeness Execution Record 表一 #5/#8/#13/#14 列未反映新增 AC;表二標題「68 條」與結尾結果句「65 條/63 條」既存不同步 | 表一四列同步新增 AC 編號;表二標題改為「73 條」;新增 K 節;結尾結果句修正為「73 條中 70 條可執行,3 條不可執行」 |
| B6 | cursor-highlight-state.md AC-23 與 Core Rules #7 真矛盾 | #7 新增「管轄範圍判準」(登記制)+ 暫停選單/彈出對話框明文排除;AC-23 保留不動,補範圍註記;新增 AC-60 |
| B7 | 本系統 `_input` 級緩衝與暫停選單原生 focus 系統搶輸入事件,順序未定義 | Edge Cases 暫停選單條款新增「成立機制」段落,複用觸發點 (c) 失焦模式一般化至暫停/模態期間;具體讓路手段委派架構階段;新增 AC-59 |
| B8/B9 | 存檔載入後陳舊游標目標無人標記失效;F2-1/F2-2 缺乏共用情境定義 | Core Rules #7「表面卸載前的目標交接義務」觸發情境明文擴充涵蓋存檔讀取;分列甲(舊表面存在時讀檔)/乙(無舊表面時讀檔)兩種情境;責任歸屬呼叫方系統;新增「時機點的安全窗口」段落錨定 save-system.md Core Rules #5;`systems-index.md` Registry 第 165 列同步擴充 |
| B10 | D-1:`game-concept.md` 把 `source_absence` 與 `total_churn`/`reversal_count` 一併列為「單調不可逆」豁免特徵,但前者是即時查詢、前提不成立 | `game-concept.md` 新增 D-1 修法段落(移出豁免清單,終局判定+過程中誠實告知);`affinity-data-pool.md` 3g 新增「可逆性明文承認」+ AC-54 補範圍聲明 + 新增 AC-80;`systems-index.md` Registry 新增列 |

**Prior verdict resolved**:是——R5 十一項阻擋已同 session 全數修訂完成並移交(2026-08-07 核准跳過第六輪),本輪處理的是移交後 2026-08-09 `/review-all-gdds` 發現且長期擱置的跨文件殘留缺口,非 R5 範圍內的回歸。
**未隨此輪處理**:見架構階段待辦清單;Recommended 三項(Player Fantasy「殘餘成本」段落拆分、Open Questions 架構階段清單提取、Completeness Execution Record 逐義務檢查試行)留待本輪修法穩定後單獨進行;F2-3~F2-6(`/review-all-gdds` 2026-08-09 Warning 級發現)本輪未觸及。

---

## Review — 2026-08-12 — 第七輪(目標型覆核觸發升級條件,擴大為完整模式)

**Verdict**: NEEDS REVISION → 已於同一 session 內完成修訂
**Scope signal**: XL(系統本身,不變)| 本輪修訂工作量:**M**
**Specialists**: systems-designer、qa-lead、godot-specialist(第六輪指定的目標型三位)+ game-designer、narrative-director、performance-analyst、security-engineer(觸發第六輪自訂升級條件後新增)、creative-director(綜合裁決)
**Blocking items**: **7**(去重合併後,原始 10 項)| **Recommended**: **14**(去重合併後,原始 17 項)| **結構性建議**: 1

**背景與升級理由**:第六輪訂下的下一輪範圍為「目標型,3 位專家」,附退場條件「若目標型覆核發現任一項修法製造了新接縫,即升級為完整模式重跑」。目標型三位專家各自回報了新接縫(systems-designer 2 項、qa-lead 4 項、godot-specialist 1 項 BLOCKING),觸發條件成立,擴大為七位專家的完整模式。**此決定在事後被證明是本輪價值的關鍵**:升級後新增的四位專家共回報 3 項 BLOCKING,其中 2 項(B6、B7)是本輪僅有的兩項**真設計缺陷**,且分別來自 game-designer 與 narrative-director——若維持目標型三位,本輪只會找到五項傳播失敗,兩項設計缺陷會原封不動流入 `/create-architecture`。

**Summary**:**第六輪的十項修訂,方向全部正確,無一需要撤回**。七項阻擋中**五項是第六輪那批編輯自身的傳播失敗**(不是新設計缺陷),兩項是真正的設計內容缺陷。沒有任何一項指向架構方向錯誤。

本輪最重要的發現不在七項阻擋裡,而是 creative-director 比對第五輪自訂條款與第六輪實際範圍後查證得出、七位專家皆未報告的結構性事實:`save-system.md` 完備性執行紀錄表的「已知檢查粒度限制」段落自訂了升級觸發條件——「留待下一次實質修訂 Core Rules 內容時一併評估是否值得投入」——而第六輪正是一次對 Core Rules #5/#8/#13/#14 的實質修訂,**觸發條件已成立,該評估從未被執行**,表格照舊以規則級綠燈通過。本輪 B1/B3/B4/B5 四項阻擋全部落在該段自己描述的盲區內:第六輪在 #5 內部新增「第四終止路徑」義務、在 #14 內部新增「確保」定義義務,而表一只檢查「#5 有沒有列/有沒有 AC」——#5 早已多列多 AC,綠燈照亮,新義務的傳播缺口完全不在檢查射程內。**這正是該段自己預言過的假綠燈,只是這次是它自己放行的。**

**定性(續寫六輪演進)**:R1「防線不存在」→R2「防線都在但預設值設反」→R3「接縫未言明」→R4「R3 修法自己的接縫未言明」→R5「防呆機制建好了但從未對自己執行過」→R6「四項既有殘留缺口+完整性鏈條的意外缺口」→**R7「防呆機制對自己執行了,但它自己標註的量規不足,而升級量規的觸發條件已成立卻被跳過——本輪五項阻擋全部落在那個已知盲區內」**。R7 是 R5 定性的第二階實例,不是新的失敗模式。

**收斂性判讀:本輪是收斂的,且是六輪以來訊號最清楚的一次**。依據三點:①阻擋數與性質同時下降——7 項中 5 項為純傳播失敗,第六輪十項修訂有八項經七位專家對抗性覆核後零發現,是本文件史上單輪修訂正確率最高的一次;②**本輪首次出現「單一結構性改動可防止多數阻擋再發」的形態**——B1/B3/B4/B5 共享同一個成因,U-3 乙案一次關閉整類;③升級決策被證明正確(見上方背景)。阻擋數:24→9→11→8→11→10→**7**。

**反向訊號(必須點名,已寫入第八輪退場條件)**:第六輪標頭有**兩處**「已完成」的自我宣稱經查證不實——(a)「Dependencies 章節三處落差修正」實際只修了 Interactions 的對應條目,真正的 Dependencies 表格列至今停留在最陳舊的「**兩條路徑**」版本;(b)AC-76 的呈現規範宣稱「已同步登記至 `systems-index.md` Registry」,經逐列查證**該列從未存在**。兩者與 R3-B5 的教訓完全同型,發生在四輪之後。結論:**本文件家族的「修訂完成」自我宣稱不可信,每輪的修訂清單本身都應被下一輪當成待查證的宣稱,而非已知事實。**

**本輪使用者裁決(三項,全數採納 creative-director 推薦選項)**:
1. **U-1(路徑〔四〕的唯讀存取管道)→ 甲案:延伸唯讀存取介面可用條件**。由「拒絕讀取狀態」擴大為「拒絕讀取狀態,**或**待遷移狀態且已滿足重複回寫失敗條件且當下無進行中的分步狀態機」。理由:消除保護等級倒掛、沿用既有介面不新增機制。否決乙案(新增獨立槽狀態——新狀態就是新接縫)與丙案(接受現況——等於明文承認倒掛)。
2. **U-2(陣亡配對 `source_absence_cc` 的揭露處置)→ 丙案:陳述事實但不使用關閉語言**。以角色語言陳述為真的事實(例如「你和她之間,再也不會有並肩作戰時的那種話了」),不談路線、不談關閉、不談機制。此語域與 2026-08-10 第八輪對陣亡議題的既有裁決同源。否決甲案(無條件關閉揭露——把哀悼變成清算)與乙案(沉默——是 D-1 當初要修掉的失格模式的鏡像)。**重要澄清:此裁決不推翻第六輪使用者的 A+ 裁決**,「終局判定+過程中誠實告知」方向維持,修正的是其前提句的全稱性與適用粒度。
3. **U-3(完備性執行紀錄表是否升級為逐義務檢查)→ 乙案:本輪不升級,但把觸發條件改寫為可稽核版本**。理由:本輪五項阻擋全部落在**被修訂過的**那四條規則上,沒有一項落在未被觸碰的規則上。全表升級不取消,改由 Ledger S13 累積實證後重新評估。

**Revision list(blocker → fix applied,同一 session 內完成)**:

| # | 阻擋項摘要 | 修訂內容 |
|---|---|---|
| R7-B1 | **路徑(四)未傳播至六處位置**(systems-designer 1+2、game-designer 2 各自發現其中一部分,creative-director 查證新增第 5、6 處)——第六輪新增路徑(四)時只改了 Core Rules #5 的路徑清單本身 | 六處全數同步:(1)Core Rules #5 導言句「三條」→「四條」;(2)權杖式語意段「以下三條路徑」→「四條」;(3)Core Rules #16 矩陣生命週期通知列「三分支」→「四分支」並列出各路徑保證強度;(4)States and Transitions「待遷移」列離開條件由「成功或失敗」二分法改寫為三結局模型,並明文指出原二分法是構造上的死路;(5)Dependencies 表好感度數值池列由「兩條路徑」改寫為四條(全文件最陳舊的一處,七位專家皆未發現);(6)`systems-index.md` Registry 補上 AC-76 的登記列(第六輪宣稱已登記但該列從未存在)。(5)(6)兩處已寫入第八輪退場條件第 2 項 |
| R7-B2 | **第六輪 cursor 端 F2-1/F2-2 修法缺乏可歸因的驗證**(qa-lead 5+6 合併):F2-2 甲/乙分支零專屬 AC;AC-60 與 AC-59 共用暫停選單情境,登記制判準本身實質從未被驗證 | `cursor-highlight-state.md` 新增 L 節三條 AC:AC-61(甲分支)、AC-62(乙分支,驗證與新開局狀態轉換序列完全相同)、AC-63(丙分支,見 R7-R4);AC-60 測試情境改為「不觸發 `SceneTree.paused` 的未登記表面」,並記載兩 AC 情境必須互斥的理由 |
| R7-B3 | **AC-68/AC-73 引用了不存在的診斷能力**(qa-lead 1):兩條 AC 宣稱可透過「Core Rules #15 甲類診斷介面」觀測 begin/end 呼叫時序,但甲類三項介面皆不監測生命週期通知呼叫 | Core Rules #15 甲類新增第四項:生命週期通知呼叫記錄;新增 AC-78;介面分類表「三項」→「四項」 |
| R7-B4 | **AC-10a 的「今日可執行」理由與其驗證機制矛盾**(godot-specialist 1):完備性表 K 列以單一句涵蓋六條 AC,該句對 AC-10a 為假(它驗證 OS 層級 rename 原子性,須實際終止行程)——AC-10 拆分的全部目的正是分開這兩種驗證,本表在同一輪用一句方法論宣稱把它們重新合併回去 | 表二 K 列拆分為兩列;新增「『今日可執行』的判定粒度限制」段落:同一章節內若存在方法論不同的 AC 須拆列分述 |
| R7-B5 | **Core Rules #14「確保」定義結構性排除步驟四且未聲明理由**(qa-lead 2):規則寫「步驟 2-4a」、AC-75 寫「步驟 1-4a」,一致地把步驟四(`.bak`→`.prev.bak` 的 rename)排除在檢查義務外 | Core Rules #14 步驟 1「確保」範圍改為明文列舉「步驟 1、2、3、4a、4」;AC-75 同步擴大並逐步驟列舉中止後的檔案狀態,取代原「依步驟而定」的概括措辭(一併解決 R7-R3) |
| R7-B6 | **路徑(四)的槽狀態與唯讀存取介面可用條件不相交**(game-designer 1,**本輪兩項真設計缺陷之一**):持續回寫失敗的玩家沒有任何唯讀檢視/匯出管道,保護等級低於資料已損毀的槽 | **使用者裁決 U-1 甲案**:Core Rules #5 路徑(四)新增「重複回寫失敗的判定門檻與唯讀存取管道」段落(連續兩次門檻);Core Rules #13 唯讀存取可用條件擴大;Interactions 新增「須同時提供唯讀存取入口」條款含復原前景語句;新增 AC-77 |
| R7-B7 | **`source_absence_cc` 在陣亡配對上實為單調不可逆,D-1 修法的全稱前提有具體反例**(narrative-director 1,併入其發現 4 的一般化,**本輪最嚴重發現**):陣亡配對的 `cc` 來源寫入被永久拒絕,而該分量翻轉的唯一途徑正是該來源發生新記錄→構造上不可翻轉。AC-80 對此反例結構性空轉 | **使用者裁決 U-2 丙案**,依 narrative-director 發現 4 以通則而非枚舉陣亡個案書寫:`game-concept.md` D-1 修法新增「三項修正」(可逆性須逐(配對,來源)判定/不可逆子情境角色語言陳述事實不用關閉語言/中途揭露義務 modality 明確化);`affinity-data-pool.md` 3g 新增「可逆性的正確範圍」段落 + AC-80 補覆蓋範圍限制 + 新增 AC-81(反面測試);`systems-index.md` 第 178 列改寫為甲/乙兩類分述 |

**Recommended revisions applied(14 項,全數同批完成)**:R1【三合一,godot-specialist+security-engineer×2】Core Rules #8 新增「操作原子性」段落——雜湊須為同一次序列化操作產出的同一份緩衝區;R2(systems-designer)#5 路徑(四)新增與路徑(三)的邊界(失敗訊號形式決定路徑歸屬);R3(systems-designer,併入 B5)AC-75 逐步驟列舉;R4(systems-designer)cursor Core Rules #7 新增(丙)讀檔流程被取消分支+AC-63;R5(game-designer)乙分支新增已知體感落差明文登記,維持建議級不修改行為(依第十二輪既有裁決);R6(game-designer)D-1 修法新增「相關但獨立的建議級落差」段落(規則層可逆、體感上不可逆);R7(narrative-director)`source_absence_se` 能動性措辭排除;R8(narrative-director,併入 B7 修正三)modality 矛盾;R9(performance-analyst)#8 新增可選讀回比對耗時歸屬;R10(performance-analyst)Tuning Knobs 新增路徑(四)持續失敗重跑成本;R11(security-engineer)#14 耐久性範圍聲明新增第三類終止情境(OS 當機/電源未斷);R12(qa-lead,併入 B6)「連續兩次」門檻提升至規則層;R13(qa-lead)AC-74 新增與 AC-75 關係澄清;R14(godot-specialist)#14 步驟 1 具體 API 例示更正。

**結構性建議**:完備性執行紀錄表升級觸發條件改寫為可稽核版本——見上方 U-3 裁決與 Ledger S13。

### 逐義務三件套核對紀錄(U-3 乙案新規則的第一次適用,對象為本輪自身)

*新規則:「任何一次修訂 Core Rules 內部義務句的輪次,須於同輪對受影響的每一條規則執行逐義務三件套核對,並將核對結果寫入該輪的 review-log 條目。」本輪修訂了 #5/#8/#13/#14/#15 的內部義務句,規則對本輪自身生效——若不執行,本輪就會重演它正在修正的那個失敗。以下為核對結果,逐**義務**而非逐規則。*

| 受影響規則 | 本輪新增/實質改寫的義務句 | (a) 矩陣列/無約束宣告 | (b) 專屬 AC | (c) 範圍聲明 |
|---|---|---|---|---|
| #5 | 路徑(四)與路徑(三)的邊界 | ✅ 併入既有生命週期通知列 | ✅ AC-73 | ✅ 本義務自身即為範圍聲明 |
| #5 | 重複回寫失敗門檻(連續兩次) | ✅ 同上列 | ✅ AC-76+AC-77 | ✅ 已明文說明不持久化的理由 |
| #8 | 操作原子性(同一次序列化的同一份緩衝區) | ✅ 併入既有 #8 多列 | ⚠️ **無專屬 AC——已知缺口,見下方說明** | ✅ 對 #4 單執行緒模型前提聲明已補上 |
| #8 | 可選讀回比對的耗時歸屬 | ✅ 同上 | ✅ AC-36 | ✅ 已聲明其對校準基礎的失真風險 |
| #13 | 唯讀存取可用條件擴大 | ✅ 併入既有 #13 多列+#15 分類表 | ✅ AC-77 | ✅ 兩附加條件缺一不可,已說明理由 |
| #14 | 「確保」範圍涵蓋步驟四 | ✅ 併入既有 #14 多列 | ✅ AC-75(已擴大逐步驟列舉) | ✅ 已聲明原排除的具體危險 |
| #14 | 具體檢查 API 三類區分 | ✅ 同上 | ✅ AC-75 | ✅ flush 失敗訊號可得性已列 Open Questions |
| #14 | 第三類終止情境(OS 當機但電源未斷) | ✅ 同上 | ✅ AC-10a+Open Questions | ✅ 已明文更正二分法基準 |
| #15 | 甲類第四項:生命週期通知呼叫記錄 | ✅ 矩陣已補依賴 | ✅ AC-78 | ✅ 已補範圍限定 |

**核對結果:9 條新增/改寫義務中,8 條三件套齊全,1 條有已知缺口。**

**已知缺口(明文登記,非遺漏)**:Core Rules #8「操作原子性」義務**無專屬 AC**。它斷言的是實作的內部結構(雜湊輸入與寫入輸入是否為同一份緩衝區),在單執行緒同步模型下對外部完全不可區分,無法用黑箱 AC 分辨。**處置**:不硬造假 AC 填綠(那正是本輪 B4 批評的行為),明文登記此缺口,於架構階段以「雜湊計算與寫入須共用同一緩衝區變數」作為程式碼審查檢查項落實。**此缺口即為新規則的第一個實證價值**——舊的規則級檢查會因 #8 早已多列多 AC 而綠燈通過,逐義務核對才讓它現形。

**個別專家嚴重度裁決**:qa-lead「AC-59/AC-60 共用暫停選單範例」BLOCKING→維持(登記制判準沒有任何能驗證它的 AC,屬三件套(b)缺漏);godot-specialist「AC-10a 執行方法論矛盾」BLOCKING→維持(拆分意圖於同輪被自己的紀錄表撤銷);systems-designer「F2-2 未涵蓋載入取消」RECOMMENDED→維持但要求與 B2 同批;game-designer「F2-2 乙分支高亮/滑鼠不同步」RECOMMENDED→維持(沿用第十二輪既有裁決);narrative-director 1 BLOCKING→維持並列為本輪最嚴重發現;game-designer 1 BLOCKING→維持,重新框定為「保護等級倒掛」而非「缺一個管道」;performance-analyst、security-engineer 全數 RECOMMENDED→全數維持(效能/安全類既有降級標準一致,security-engineer 對核心攻擊面「無新的可構造靜默損毀路徑」的確認經 creative-director 獨立複核同意)。

**不合併的判定**:narrative-director 1 與 game-designer 3 表面都談可逆性,但不得合併——前者是硬性反例(全稱宣稱在具體構造下為假,BLOCKING),後者是軟性告知落差(規則為真但玩家體感不符,RECOMMENDED);合併會讓後者被前者的修法誤判為已解決。

**AC 總數變化**:73 → **75**(新增 AC-77、AC-78);其中 72 條今日可執行,3 條(AC-51、AC-61、AC-71)維持不可執行狀態並各自綁定交付閘門。`cursor-highlight-state.md` 新增 AC-61/62/63;`affinity-data-pool.md` 新增 AC-81。

**Prior verdict resolved**:部分——第六輪 10 項阻擋的**修法方向全部成立、無一撤回**,但其中兩項(路徑〔四〕的槽狀態選擇、D-1 的全稱前提)在自己新開的語意空間裡留下未走查的玩家路徑,另有五組屬同一批修訂的傳播失敗(含兩處不實的「已完成」宣稱)。全部七項已於本輪同一 session 修訂完成。

**未隨此輪處理(明確記錄,非遺漏)**:見文首「架構階段待辦清單」——本輪確認 U-3 甲案(全表逐義務升級)不投入,由 Ledger S13 累積實證後重新評估,非遺漏。F2-3~F2-6(`/review-all-gdds` 2026-08-09 的 Warning 級發現)——連續第二輪未觸及,建議第八輪一併處理或明確裁定延後至下游系統設計時。

**creative-director 第八輪退場條件建議**:目標型,**3 位專家(qa-lead、systems-designer、narrative-director)**,只驗證三件事,不開新領域:
1. **本輪 7 項修訂本身有無製造新接縫**(既有慣例)。
2. **逐字查證本輪修訂清單的每一句宣稱**——不接受任何「已修訂/已登記」的自我陳述,須指向具體行號並比對實際文字。本輪兩次查獲第六輪宣稱高估覆蓋範圍,且與 R3-B5 的教訓同型、發生在四輪之後——此條款為本輪最重要的流程產出。
3. **B7 的通則化修法是否真的通則**——構造一個**非陣亡**的「來源永久不可寫入」情境(例如角色離隊、章節結構性封閉某來源),驗證新規則自動涵蓋,而非只涵蓋陣亡個案。

附既有退場條件:**發現任何一項屬於「新設計缺陷」而非「傳播失敗」者,即升級為完整模式**(本輪已證明此條款有效)。若第八輪僅在這三點上通過,建議 **APPROVED**、移交 `/create-architecture`。
