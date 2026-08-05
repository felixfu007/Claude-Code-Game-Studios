# 存檔系統(含跨規則集遷移)—— Design Review Log

## Persistent Leftover Ledger(遺留項帳本)

追蹤非阻擋但需要持續觀察的項目。若某項連續 3 輪未被實際處置(僅改動狀態文字、無交付物),下一輪自動升級為阻擋候選。欄位拆分「處置動作狀態」與「交付物存在性」,避免只改文字而未真正交付卻讓升級計數器歸零。

| 編號 | 內容 | 首次出現輪次 | 處置動作狀態 | 交付物存在性 | 備註 |
|---|---|---|---|---|---|
| S1 | `affinity-data-pool.md` 的索引鍵持久化描述(enum 序數)與本文件 Core Rules #10(字串名稱)不一致,尚未回頭同步該文件 | R1 | **✅ R2 已解決** | 是——`affinity-data-pool.md` Dependencies 章節新增索引鍵持久化方式段落 + 新增 AC-56(見該文件第 M 節) | 依 creative-director R2 裁決,解綁與 AC-47/同步-非同步議題的錯誤綑綁,獨立處理完成,不再等待格式決策 |
| S2 | AC-24 的浮點容差在序列化格式決定前先行斷言,格式決定後可能需要重新校準 | R1 | R2:**本輪主動延後**;R3:**再次主動延後**(仍受同一個未決的序列化格式決策閘制,無新事實) | 否 | qa-lead 建議項,非阻擋;連續 2 輪主動延後,理由未變,尚未達 3 輪自動升級門檻,R4 若仍無格式決策則需重新評估是否該獨立於格式決策先行處理 |
| S3 | 遷移鏈孤兒終止函數的歸屬未定義(誰負責維護「不再需要」的舊版本遷移函數) | R1 | R2:**本輪主動延後**;R3:**再次主動延後**(目前仍僅 1 個規則集版本,無新事實改變判斷) | 否 | systems-designer 建議項,非阻擋;連續 2 輪主動延後,尚未達 3 輪自動升級門檻 |
| S4 | Player Fantasy「拒絕並告知=最值得信任的作法」語氣偏高,與文件自身嚴重度表(此為次糟類別)不完全對齊 | R1 | **✅ R2 已解決** | 是——Player Fantasy 章節依使用者裁決 A2 整段重寫,嚴重度排序與取捨聲明措辭一致化 | 隨 B6 裁決一併處理,原問題描述的矛盾已不存在;R3 對同章節的 D-5 修訂(取捨的殘餘成本)是獨立的新發現,非本項復發,見 R3-B10 |
| S5 | `max_save_slots`、`save_write_max_duration_ms`、`migration_chain_load_time_budget_ms` 三個旋鈕皆待實測校準,目前僅有建議方向、無實際數值 | R1 | 已建立旋鈕欄位;R2 新增遷移函數複雜度上限旋鈕(免旋鈕值,契約型)、寬限上限規則、AC-46;R3 補上寬限上限規則的精確觸發條件定義(量測環境/最小間隔/最大間隔)與追蹤責任指派 | 部分——欄位存在,數值待補;R3 新增的觸發條件定義本身是交付物 | 待 UI 系統設計/`/create-architecture` 階段實測後填入起始值;寬限期規則本身已從「存在但可能無人執行」轉為「可稽核」 |
| S6 | 主機平台是否為目標平台尚未定案,Core Rules #4/#14 的 provisional 狀態依賴此決定 | R1 | 已標記 provisional + Open Question;R3 補充:provisional 範圍限定為一般寫入路徑,遷移執行模型已於 R3 獨立定案(不再與此項綁定,見 D-2) | 是——已寫入文件 | 平台策略定案前為主動延後,非遺漏;R3 縮小了此項實際懸而未決的範圍 |
| S7 | 型別白名單(Core Rules #9)版本分域範圍未定 | R2 | 已登記為 `/create-architecture` 必辦項(非 GDD 阻擋);R3 未變動 | 是——Open Questions 新增列 | security-engineer 提出的攻擊路徑,creative-director 綜合裁決降級(單機無伺服器信任邊界,機制需等格式定案),非本文件阻擋 |
| S8(新) | Core Rules #13 自動痊癒路徑(二)的維運層級重跑觸發機制與狀態轉換模型未定義 | R3 | 已登記為 `/create-architecture` 必辦項,已補上資料前提(創世保留、完成標記+拼接範圍限定) | 是——Open Questions 新增列、Core Rules #13 已補上限定範圍 | R3 由「保證」措辭降級為「資料前提已保證,程序留待架構階段」,見 R3-B9;不計入 GDD 層級阻擋,但架構階段若略過此項,路徑(二)將形同無法使用 |
| S9(新) | 電源中斷(斷電)情境下 `FileAccess.flush()` 是否有等效的硬體層級落盤保證,GDScript 目前未知是否可直接呼叫 | R3 | 已登記為 `/create-architecture` 必辦查證項,已縮小 GDD 承諾範圍(僅保證進程層級當機) | 是——Core Rules #14 耐久性範圍聲明、Open Questions 新增列 | godot-specialist 提出,自陳為回憶而非即時查證;查證結果若為「無法達成」,電源中斷資料遺失維持已接受的殘餘風險,不需回頭修改 GDD 承諾範圍(已經是縮小後的版本) |
| S10(新) | 存檔目錄位置(`user://`)與 `.tmp`/`.dat` 須同檔案系統的前提,先前僅隱含於原子性論證中未明文 | R3 | 已登記為 `/create-architecture` 必辦項 | 是——Open Questions 新增列 | godot-specialist 提出;所有當機安全論證隱含依賴此前提,架構階段須把它落實為硬性配置要求而非繼續隱含 |
| S11(新) | Steam Cloud(或其他雲端存檔同步)與本輪新增的多檔案佈局(`.pre_migration.bak`/`.prev.bak`)如何互動尚未評估 | R3 | 已登記為 Open Question,待平台/發行策略定案 | 是——Open Questions 新增列 | performance-analyst 提出,creative-director 上調優先度(理由:R3 新增的持久備份機制放大了此風險面,不再是可忽略的邊角情境) |

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

---

## Review — 2026-08-05 — 第三輪(完整模式對抗性重新覆核)

**Verdict**: NEEDS REVISION
**Scope signal**: XL(系統本身)| 本輪修訂工作量:M
**Specialists**: game-designer、systems-designer、godot-specialist、qa-lead、performance-analyst、security-engineer(六位並行審查)、creative-director(綜合裁決)
**Blocking items**: 11(去重合併後)| **Recommended**: 10 | **Nice-to-have**: 3

**Summary**: 三輪失敗性質有清楚演進,creative-director 本輪明確定性:R1 是「防線不存在」,R2 是「防線都在但預設值都設反了(fail-open)」,R3 是「防線都設對了,但彼此之間的接縫沒有被明文記載」。十一項阻擋中沒有任何一項指向架構方向錯誤——manifest + 版本化區塊 + 逐步遷移 + 原子置換 + 原始位元組保留這個組合本身健全。最高優先發現由四方獨立收斂(systems-designer、godot-specialist、qa-lead、performance-analyst):Core Rules #13(存底建立)與 #14(原子置換)之間的寫入時序從未定義,存在存底檔案「從未被建立就被沖銷」的當機視窗,而 AC-38 完全沒測到這件事。第二高優先由四方獨立收斂(security-engineer、systems-designer、game-designer,加上 creative-director 資深審查追加發現):`.pre_migration.bak` 單代保留策略在連續兩次遷移下會被覆蓋,直接反證「最後一道防線」的自我宣稱。第三高優先由三方獨立收斂(security-engineer、qa-lead、game-designer):Core Rules #10 退役名稱治理規則——文件自陳的最高風險失敗類別——是同一輪修訂中唯一沒被翻成 fail-closed 的規則,僅靠人工審查紀律把關。creative-director 資深審查另外查證發現兩項專家未觸及的問題:`source_i` 欄位從未被 Core Rules #10 涵蓋(範圍字面上僅限「索引鍵」),面臨與 `Pair` 完全相同的序數漂移風險;`affinity-data-pool.md` Open Question 5 殘留一句與 Core Rules #10/Section M 直接矛盾的舊敘述,顯示 R2 的 ledger S1「已解決」判定只驗證了新交付物存在,未驗證舊矛盾敘述已移除。performance-analyst 另外發現一項自我矛盾:R2 同一輪新增的「遷移進行中須有忙碌指示」呈現要求,與 Core Rules #4 的同步阻塞式遷移模型結構性不相容——單一阻塞式主執行緒呼叫期間,Godot 無法渲染任何新影格,連轉圈動畫都畫不出來。

**User decisions(修訂前置,D-1 至 D-5 五項)**:
1. **D-1(存底保留策略)**:**甲——創世保留**。只保留該存檔槽第一次遷移前的存底,永不覆寫,取代原「最近一次」措辭。成本與現狀完全相同。
2. **D-2(遷移執行模型)**:**乙——分步執行**。遷移鏈每次只執行一個版本躍遷,步與步之間讓出控制權,允許引擎渲染忙碌指示;仍在主執行緒、無鎖,不重開非同步/執行緒化的整包代價。互動情境(存檔槽瀏覽器)須改走 manifest-only 輕量讀取介面,不得觸發遷移。
3. **D-3(自動痊癒路徑(二)修補深度)**:**乙-lite——遷移完成標記+重放**。manifest 記錄遷移完成當下的記錄索引/戰役刻度位置,維運程序重跑修正後遷移時須拼接標記後的合法追加記錄;此拼接僅對明確宣告為「僅追加」的資料區塊(好感度數值池 Delta Log)成立,非追加型區塊不保證無損拼接。
4. **D-4(一般位元腐蝕是否也備份)**:**乙——滾動保留一代**。Core Rules #14 步驟四由「刪除備份檔」改為「rename 為 `slot_N.prev.bak`」,為一般 `DATA_CORRUPTED`(非遷移情境)提供唯讀回退路徑。
5. **D-5(Player Fantasy 取捨成立前提自我矛盾)**:**甲——誠實重新計價+補上溝通要求**。承認遷移失敗的等待/放棄決定是持續性殘餘成本(結構上更接近第二嚴重級而非文件原先宣稱的第三嚴重級一次性事件),將唯讀匯出明確定位為「零代價保險」,下游 UI 新增強制主動告知義務。F1(整份拒絕政策)本身不受動搖,creative-director 已驗證不需重開使用者 A2 裁決。

**Revision list(blocker → fix applied)**:

| # | 阻擋項摘要 | 修訂內容 |
|---|---|---|
| R3-B1 | Core Rules #13(存底建立)與 #14(原子置換)之間的寫入時序未定義,存底可能「從未被建立就被沖銷」,AC-38 未覆蓋(四方獨立收斂:systems-designer/godot-specialist/qa-lead/performance-analyst) | Core Rules #13 新增兩階段寫入順序(階段 A 存底建立須先確認完成才進入階段 B);Core Rules #14 新增步驟零(寫入前先補完上次未完成的步驟四)、精確檔名比對規則(排除萬用字元/前綴比對誤判三種 `.bak` 檔案);AC-38 由兩結果模型改寫為三結果模型並新增存底檔案斷言;新增 AC-48(精確檔名比對) |
| R3-B2 | 單代 `.pre_migration.bak` 保留在連續兩次遷移下會被覆蓋,反證「最後一道防線」宣稱(四方獨立收斂:security-engineer/systems-designer/game-designer,使用者裁決 D-1) | Core Rules #13 保留策略由「最近一次」改為「創世保留」(第一次遷移前的存底永久保留、不得覆寫);AC-37 新增連續兩次遷移下創世存底不被覆寫的驗證;Edge Cases 對應措辭同步修正 |
| R3-B3 | Core Rules #10 退役名稱治理規則零自動化執行,是文件自陳最高風險項卻是同輪唯一未 fail-closed 的規則(三方獨立收斂:security-engineer/qa-lead/game-designer) | Core Rules #10 由「治理紀律,不依賴任何執行期機制強制」升級為硬性規則,要求 `/create-architecture` 階段提供自動化檢查(建置期/CI 皆可);新增 AC-51 驗證檢查機制本身存在且會攔截違規 |
| R3-B4 | `source_i` 欄位從未被 Core Rules #10 涵蓋(範圍字面僅限「索引鍵」),面臨與 `Pair` 相同的序數漂移風險,能通過現有全部四道防線(creative-director 資深審查新增發現) | Core Rules #10 範圍由「索引鍵」擴大為「索引鍵與任何持久化列舉欄位」,明確納入 `source_i`;新增 AC-49/AC-50(對稱於 AC-25/AC-29);`affinity-data-pool.md` 同步擴大 Dependencies 段落與新增 AC-57(對稱於 AC-56) |
| R3-B5 | `affinity-data-pool.md` Open Question 5 殘留與 Core Rules #10/Section M 直接矛盾的舊敘述,R2 ledger S1「已解決」判定未驗證舊敘述已移除(qa-lead 發現,creative-director 實地查證屬實) | `affinity-data-pool.md` Open Question 5 該句刪除並改寫,明確指向 Section M/AC-56/AC-57 與 `save-system.md` Core Rules #10;ledger 記錄本次修法對「交付物存在性」欄位定義的補充(修正既有錯誤敘述類項目須同時記載舊敘述移除位置) |
| R3-B6 | Core Rules #13 唯讀存底存取介面未要求重跑 Core Rules #7/#8/#9,重開 R2 剛翻成 fail-closed 的三條規則的繞行側門(security-engineer) | Core Rules #13 新增規則:唯讀介面須重新套用型別白名單與完整性雜湊檢查,不得因「本系統自產備份」而自我信任;語意驗證可降為僅標註;新增 AC-53(竄改存底須回傳明確錯誤,不得靜默呈現) |
| R3-B7 | manifest 缺少涵蓋自身區塊清單的完整性標記,與 AC-24b(空 Delta Log 合法)交互後,一次意外消失的區塊條目會被讀成合法空狀態(security-engineer) | Core Rules #8 新增涵蓋整份區塊清單的頂層完整性標記(雜湊輸入為區塊身分/版本/逐區塊雜湊的有序 tuple 清單);新增 AC-52 |
| R3-B8 | 忙碌指示要求(R2 新增)與 Core Rules #4 同步阻塞模型結構性不相容——單一阻塞呼叫期間連轉圈動畫都畫不出來(performance-analyst,使用者裁決 D-2) | Core Rules #4 範圍限定為一般寫入路徑;新增 Core Rules #5「遷移執行模型」小節,改為分步執行(每步之間讓出控制權,仍在主執行緒、無鎖);Core Rules #15 新增遷移進度查詢介面;新增 AC-14b;新增「互動情境須走 manifest-only 讀取」規則與對應 Interactions 條款 |
| R3-B9 | 自動痊癒路徑(二)既未指定觸發機制/狀態模型/專屬 AC,又會靜默毀掉遷移後累積的合法玩家進度(game-designer + qa-lead 合併,使用者裁決 D-3) | Core Rules #13 路徑(二)措辭由「保證」降為「資料前提已保證,程序留待 `/create-architecture`」;新增遷移完成標記機制與合法追加記錄拼接前提(僅限追加型區塊);AC-37 新增明確範圍聲明(不涵蓋路徑二程序本身);Open Questions 新增觸發機制設計項 |
| R3-B10 | Player Fantasy「此取捨的成立前提」自我矛盾——第 28 行定義的失格條件在第 102 行對緩解後狀態的描述中依然成立(game-designer,使用者裁決 D-5) | Player Fantasy 段落改寫為「此取捨的殘餘成本」,誠實承認遷移失敗等待/放棄決定為持續性成本;States 表、Interactions 最低呈現契約同步新增強制主動告知要求(「歷史已完整保存,可隨時取出」) |
| R3-B11 | `flush()` 耐久性與 Edge Cases 對「斷電」的無條件承諾不符(godot-specialist,措辭層級但需修正) | Core Rules #14 新增耐久性範圍聲明(僅保證進程層級當機,電源中斷列為已知並接受的殘餘風險,待 `/create-architecture` 查證 fsync 等效機制);Edge Cases 對應措辭同步修正 |

**Recommended revisions applied(同批完成)**:
- AC-7 措辭由「範圍」改寫為可逐位元組核對的斷言(qa-lead)
- AC-46 補上與 AC-36 對稱的四段子成本拆分(performance-analyst)
- AC-38 三結果模型化的同時,一併新增讀取端精確檔名比對規則對應的 AC-48(systems-designer)
- 遷移鏈耗時「深度 × 資料量」乘積關係於 Tuning Knobs 明文補充(systems-designer)
- 存檔目錄位置(`user://`)、`.tmp`/`.dat` 須同檔案系統前提、`FileAccess.store_*` 布林回傳值檢查——新增 Open Questions 三列(godot-specialist)
- `OS.get_thread_caller_id()`/`get_main_thread_id()` API 名稱查證——新增 Open Questions 一列(godot-specialist,本專案 post-cutoff API 政策既有要求)
- AC-36 寬限上限規則補上精確觸發條件定義(量測環境固定、最小/最大間隔、追蹤責任指派給 qa-lead/producer)(performance-analyst + qa-lead)
- Steam Cloud 多檔案佈局互動——新增 Open Questions 一列,creative-director 上調優先度(performance-analyst)
- 一般 `DATA_CORRUPTED` 滾動備份——已併入 BLOCKING D-4 決策執行,非獨立建議項
- 新增 Core Rules #16「規則交互矩陣」小節(creative-director 結構性建議,非任一專家發現,但為十一項阻擋中六項「規則接縫未言明」問題的最有效單一收斂改動)

**creative-director 對個別專家嚴重度判定的裁決**:
- performance-analyst「AC-36 寬限期觸發條件可被遊戲」BLOCKING → 降為 RECOMMENDED(落在文件自己標為非功能性、不阻擋 Story 完成的 H 節,是流程衛生問題而非會讓實作者做錯東西的問題)
- performance-analyst「AC-46 缺子成本拆分」BLOCKING → 降為 RECOMMENDED(同上,缺的是診斷儀器而非正確性)
- performance-analyst「無互動情境呼叫限制、manifest-only 路徑缺席」建議 → **上調為 D-2 決策的必要條款**(不論選擇哪個遷移執行模型,此限制皆須成立,不能只是建議)
- performance-analyst「合成 N 步 no-op 遷移鏈量測固定框架成本」→ **推翻 R2 自己的降級**,改列 RECOMMENDED(R2 誤將「測未來業務邏輯」與「測固定框架開銷」混為一談,後者今天即可測)
- performance-analyst「Steam Cloud 互動」Nice-to-have → 上調為 RECOMMENDED(R3 新增的持久備份機制放大此風險面)

**Prior verdict resolved**: 是——第二輪 NEEDS REVISION 的 9 組阻擋已於第二輪同一 session 全數修訂(見上方第二輪記錄),第三輪針對這些修訂本身的對抗性覆核發現新的 11 組阻擋(其中 6 項為規則間接縫未言明、3 項為過度承諾措辭、2 項為範圍遺漏),已於本輪(同一 session)全數處理完成。

**未隨此輪處理(明確記錄,非遺漏)**:序列化格式本身、`max_supported_migration_depth` 數值上限、`affinity-data-pool.md` AC-47 重開、主機平台策略——皆為使用者/前輪明確裁定延後的項目,本輪未變動。S2/S3(浮點容差、孤兒遷移函數歸屬)本輪再次記錄為主動延後,連續 2 輪未達 3 輪自動升級門檻,見上方 Ledger。Core Rules #13 路徑(二)的實際觸發機制、fsync 電源中斷查證、`user://` 前提正式化——皆為本輪新增但刻意留給 `/create-architecture` 階段的項目,非遺漏,見 Ledger S8/S9/S10。

**creative-director 收斂觀察與第四輪退場條件建議**:發現數 24→9→11,非單調收斂。creative-director 判讀 R3 的發現已抵達「同輪新增規則間接縫未言明」這個終末類別,建議第四輪只驗證三個性質、不開新領域:(一)時序完整性——每條約束另一條規則時序的規則,其先後關係已明文寫下(Core Rules #16 規則交互矩陣即為此存在,新增規則時應同步更新);(二)承諾可證成性——文件中每一句「絕不/保證/不存在」,要麼可由已載明的機制推導,要麼已附範圍聲明(本輪 B2/B10/B11 皆屬此類,可一次掃描窮舉);(三)跨文件一致性——`affinity-data-pool.md`、`systems-index.md`、`game-concept.md` 中沒有與本文件矛盾的敘述,含**舊段落**不只新段落(R3-B5 的教訓)。若第四輪在這三個性質上通過即應 APPROVED、移交 `/create-architecture`。序列化格式、fsync 真實行為、`DirAccess.rename()` 平台語意、型別白名單版本分域、Godot API 名稱查證、主機平台——這些未決項在沒有引擎接觸的情況下本質上無法在 GDD 層解決,繼續在 GDD 層打轉不會提高品質,只會延後真正能解答它們的階段。
