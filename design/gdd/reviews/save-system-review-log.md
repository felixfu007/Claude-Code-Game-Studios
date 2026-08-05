# 存檔系統(含跨規則集遷移)—— Design Review Log

## Persistent Leftover Ledger(遺留項帳本)

追蹤非阻擋但需要持續觀察的項目。若某項連續 3 輪未被實際處置(僅改動狀態文字、無交付物),下一輪自動升級為阻擋候選。欄位拆分「處置動作狀態」與「交付物存在性」,避免只改文字而未真正交付卻讓升級計數器歸零。

| 編號 | 內容 | 首次出現輪次 | 處置動作狀態 | 交付物存在性 | 備註 |
|---|---|---|---|---|---|
| S1 | `affinity-data-pool.md` 的索引鍵持久化描述(enum 序數)與本文件 Core Rules #10(字串名稱)不一致,尚未回頭同步該文件 | R1 | **✅ R2 已解決** | 是——`affinity-data-pool.md` Dependencies 章節新增索引鍵持久化方式段落 + 新增 AC-56(見該文件第 M 節) | 依 creative-director R2 裁決,解綁與 AC-47/同步-非同步議題的錯誤綑綁,獨立處理完成,不再等待格式決策 |
| S2 | AC-24 的浮點容差在序列化格式決定前先行斷言,格式決定後可能需要重新校準 | R1 | R2:**本輪主動延後**(creative-director 明確記錄,非遺漏) | 否 | qa-lead 建議項,非阻擋;確實受格式決策閘制,升級計數器本輪不累計 |
| S3 | 遷移鏈孤兒終止函數的歸屬未定義(誰負責維護「不再需要」的舊版本遷移函數) | R1 | R2:**本輪主動延後**(creative-director 明確記錄,非遺漏) | 否 | systems-designer 建議項,非阻擋;目前僅 1 個規則集版本,無從判斷,升級計數器本輪不累計 |
| S4 | Player Fantasy「拒絕並告知=最值得信任的作法」語氣偏高,與文件自身嚴重度表(此為次糟類別)不完全對齊 | R1 | **✅ R2 已解決** | 是——Player Fantasy 章節依使用者裁決 A2 整段重寫,嚴重度排序與取捨聲明措辭一致化 | 隨 B6 裁決一併處理,原問題描述的矛盾已不存在 |
| S5 | `max_save_slots`、`save_write_max_duration_ms`、`migration_chain_load_time_budget_ms` 三個旋鈕皆待實測校準,目前僅有建議方向、無實際數值 | R1 | 已建立旋鈕欄位;R2 新增遷移函數複雜度上限旋鈕(免旋鈕值,契約型)、寬限上限規則、AC-46 | 部分——欄位存在,數值待補 | 待 UI 系統設計/`/create-architecture` 階段實測後填入起始值 |
| S6 | 主機平台是否為目標平台尚未定案,Core Rules #4/#14 的 provisional 狀態依賴此決定 | R1 | 已標記 provisional + Open Question | 是——已寫入文件 | 平台策略定案前為主動延後,非遺漏;R2 未變動 |
| S7(新) | 型別白名單(Core Rules #9)版本分域範圍未定 | R2 | 已登記為 `/create-architecture` 必辦項(非 GDD 阻擋) | 是——Open Questions 新增列 | security-engineer 提出的攻擊路徑,creative-director 綜合裁決降級(單機無伺服器信任邊界,機制需等格式定案),非本文件阻擋 |

---

## Review — 2026-08-05 — 第一輪(首次 `/design-review`)

**Verdict**: MAJOR REVISION NEEDED
**Scope signal**: XL
**Specialists**: game-designer, systems-designer, godot-specialist, qa-lead, performance-analyst, security-engineer, creative-director(綜合裁決)
**Blocking items**: 24(去重後)| **Recommended**: 6(即上方 S2-S4,含效能/旋鈕類)

**Summary**: 文件對「檔案本身損毀」建立了完整防禦,但對自陳最嚴重的失敗模式——**語意靜默改變**(尤其 `Pair` enum 序數漂移導致存檔靜默還原成錯誤但合法的配對)——幾乎零防禦。5 位專家獨立收斂於此為核心問題。次要主題:同步阻塞式寫入的決定被判定「花用過度」(用來永久關閉已 Approved 的 `affinity-data-pool.md` AC-47),裁定降格為 provisional;遷移鏈生命週期(回寫時機、確定性要求、後置條件檢查)大量規則從未成文卻被其他論證依賴;執行緒模型自相矛盾(AC-8/9/14 隱含並發場景,與 Core Rules #4 的單執行緒假設衝突);序列化格式懸而未決連帶拖累 5 項阻擋。文件標頭的美學支柱自我分類也被判定錯誤(應為支柱二持久化承載層,非純基礎設施)。

**User decisions(修訂前置)**:
1. 序列化格式:維持 Open Question(留給 `/create-architecture`),但立即鎖定 4 項不論選哪種格式都必須滿足的硬性護欄(字串名稱持久化、manifest 完整性標記、反序列化白名單、跨平台原子置換行為契約)
2. F1 失敗粒度:維持整份拒絕(不採部分載入),但在 Player Fantasy 明文寫出取捨理由
3. 同步寫入降格範圍:只降格本文件語氣為 provisional,`affinity-data-pool.md` 的 AC-47 暫不重開,僅留交接註記
4. 遷移回寫規則:成功後立即回寫覆蓋原槽,並正式宣告自動痊癒保證

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

**未隨此輪處理(明確記錄,非遺漏)**:序列化格式本身、`max_supported_migration_depth` 數值上限、`affinity-data-pool.md` AC-47 重開——皆為使用者明確裁定延後的項目,見上方 User decisions 與 Open Questions。

---

## Review — 2026-08-05 — 第二輪(完整模式對抗性重新覆核)

**Verdict**: NEEDS REVISION
**Scope signal**: XL(系統本身)| 本輪修訂工作量:M–L
**Specialists**: game-designer, systems-designer, godot-specialist, qa-lead, performance-analyst, security-engineer(六位並行審查)、creative-director(綜合裁決)
**Blocking items**: 9(去重合併後)| **Recommended**: 14 | **Nice-to-have**: 5

**Summary**: 第一輪的問題是「防線不存在」,第二輪的問題是「防線都在,但預設值都設反了」。第一輪新增的語意防禦層(Core Rules #7 語意驗證、#8 manifest 完整性、#10 字串名稱對照、#12+#13 遷移後置條件與回寫)存在五處獨立的 fail-open 邊界,全部指向文件自己標記為「最毒」的失敗類別(靜默語意改變)——這不是五個獨立疏漏,是「每條規則都從『怎麼讓正常路徑通過』寫,不是從『怎麼讓可疑路徑被擋下』寫」的一致書寫慣性。最高優先發現(B1)由三位專家(systems-designer、security-engineer、game-designer)從意外 bug / 對抗性輸入 / 無出路三個獨立角度收斂於同一個洞:有 bug 的遷移函數只要輸出滿足 Core Rules #12 的結構性後置條件,就會被判定成功並觸發 Core Rules #13 立即不可逆覆寫,該槽從此永遠無法被自動痊癒保證觸及。creative-director 另外獨立發現 Player Fantasy 三級嚴重度排序的清單順序與同節取捨聲明文字互相矛盾,直接決定 F1(整份拒絕 vs 部分載入)政策是否仍然成立——此為唯一無法由 creative-director 單方面裁定、需使用者介入的項目。設計本身(manifest + 版本化區塊 + 逐步遷移 + 原子置換)健全,沒有任何發現指向方向性錯誤。

**User decisions(修訂前置)**:
1. 裁決 A(Player Fantasy 三級嚴重度排序哪個版本為正統):**A2——取捨聲明為準**(要求玩家管理存檔=第二嚴重,比可見中斷更糟)。清單順序改寫,F1「整份拒絕」政策維持且理由成立。
2. 裁決 B(是否採納「遷移成功回寫時保留遷移前原始位元組」修法):**B-甲——採納**。代價約 2 倍已遷移槽檔案大小(數十 KB 級可忽略),同時解掉 B1、B7 最壞後果。

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

**Recommended revisions applied(必辦項,同批完成)**:
- 版本過新的呈現須框為「可回復」,不得與資料損毀同等呈現(最低呈現契約新增)
- AC-36 拆分序列化/雜湊/原子置換三段子成本量測,移至新增 H 節(非功能性阻擋獨立子節)
- 新增 AC-38(遷移後回寫途中當機的中斷安全性)
- Player Fantasy 承諾範圍限定至「已成功寫入的最後一個進度邊界」
- AC-36 新增寬限上限規則(連續兩次超標,Core Rules #4 重新評估由建議升級為必須)
- 新增遷移函數複雜度上限(O(區塊自身筆數)介面契約)
- AC-24 新增 N=0(空 Delta Log)情境測試(AC-24b)
- 最低呈現契約新增「遷移進行中須有進度/忙碌呈現」
- Open Questions 序列化格式列補充 Resource vs `store_var` 的型別白名單相容性成本權衡
- Open Questions 新增活棋盤地形演變系統的 `duplicate_deep()` 參數模式交接註記
- 標題「Detailed Design」更名為「Detailed Rules」,對齊專案標準

**creative-director 對個別專家嚴重度判定的公開改判(不計入上方 9 組阻擋)**:
- security-engineer「型別白名單無版本分域」BLOCKING → 降為 `/create-architecture` 必辦項(單機無伺服器信任邊界,與第一輪 Pair 序數問題的嚴重度來源不同,見 Open Questions 新增列,ledger 新增 S7)
- performance-analyst + systems-designer「遷移+回寫複合阻塞成本無預算」BLOCKING → 降為建議項(框架套錯,複合路徑屬於載入畫面情境而非影格預算;已透過 Tuning Knobs 範圍聲明 + AC-46 解決)
- performance-analyst「未壓測 20-50 步深遷移鏈」BLOCKING → 延後,綁定既有 `max_supported_migration_depth` 觸發條件(目前僅 1 個規則集版本,合成長鏈測的是測試框架本身)
- game-designer「重開 Core Rules #4 時無強制回檢 Player Fantasy」Recommended → 降為 Nice-to-have(Open Questions 負責人已含 creative-director,重開時本就在場)

**Prior verdict resolved**: 是——第一輪 MAJOR REVISION NEEDED 的 24 項阻擋已於同一 session 全數修訂(見上方第一輪記錄),第二輪針對修訂本身的對抗性覆核發現新的 9 組阻擋,已於本輪(同一 session)全數處理完成。

**未隨此輪處理(明確記錄,非遺漏)**:序列化格式本身、`max_supported_migration_depth` 數值上限、`affinity-data-pool.md` AC-47 重開、主機平台策略——皆為使用者/前輪明確裁定延後的項目,本輪未變動。S2/S3(浮點容差、孤兒遷移函數歸屬)本輪明確記錄為主動延後,見上方 Ledger。
