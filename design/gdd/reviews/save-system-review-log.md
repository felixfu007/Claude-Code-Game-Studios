# 存檔系統(含跨規則集遷移)—— Design Review Log

## Persistent Leftover Ledger(遺留項帳本)

追蹤非阻擋但需要持續觀察的項目。若某項連續 3 輪未被實際處置(僅改動狀態文字、無交付物),下一輪自動升級為阻擋候選。欄位拆分「處置動作狀態」與「交付物存在性」,避免只改文字而未真正交付卻讓升級計數器歸零。

| 編號 | 內容 | 首次出現輪次 | 處置動作狀態 | 交付物存在性 | 備註 |
|---|---|---|---|---|---|
| S1 | `affinity-data-pool.md` 的索引鍵持久化描述(enum 序數)與本文件 Core Rules #10(字串名稱)不一致,尚未回頭同步該文件 | R1 | **✅ R2 已解決** | 是——`affinity-data-pool.md` Dependencies 章節新增索引鍵持久化方式段落 + 新增 AC-56(見該文件第 M 節) | 依 creative-director R2 裁決,解綁與 AC-47/同步-非同步議題的錯誤綑綁,獨立處理完成,不再等待格式決策 |
| S2 | AC-24 的浮點容差在序列化格式決定前先行斷言,格式決定後可能需要重新校準 | R1 | R2:本輪主動延後;R3:再次主動延後(仍受同一個未決的序列化格式決策閘制,無新事實);R4:已重新評估,結論為確實無法獨立於格式決策;**R5:已從遺留帳本畢業**——qa-lead 第五輪查證發現「交付物存在性=否」欄位與備註欄「不觸發自動升級」文字自相矛盾,且客觀已達 3 輪觀察窗。creative-director 裁決:不對本項做實質解決(確實受序列化格式閘制,屬已裁定 GDD 層無法解答的類別),但比照 S6 既有範式將其移出 Ledger、轉為 Open Questions 明確條目並綁定閘門(見 `save-system.md` Open Questions),避免第六次以上的沉默延後 | 否(格式決策本身無法在 GDD 層解決,交付物存在性欄位維持誠實填「否」) | **此項已從遺留帳本畢業**——後續追蹤移至 Open Questions 表對應列,不再需要每輪重新登記於此帳本,見 R5 裁決 |
| S3 | 遷移鏈孤兒終止函數的歸屬未定義(誰負責維護「不再需要」的舊版本遷移函數) | R1 | R2:本輪主動延後;R3:再次主動延後(目前仍僅 1 個規則集版本,無新事實);R4:已重新評估,無新事實,已達 3 輪觀察窗須明確標註;**R5:已從遺留帳本畢業**——同 S2 理由,依 creative-director 裁決比照 S6 範式移出 Ledger、轉為 Open Questions 明確條目並綁定閘門(累積 3+ 規則集版本時重新評估) | 否(仍僅 1 個規則集版本,無法在無第二個版本存在的情況下產出有意義的交付物) | **此項已從遺留帳本畢業**——後續追蹤移至 Open Questions 表對應列,不再需要每輪重新登記於此帳本,見 R5 裁決 |
| S4 | Player Fantasy「拒絕並告知=最值得信任的作法」語氣偏高,與文件自身嚴重度表(此為次糟類別)不完全對齊 | R1 | **✅ R2 已解決** | 是——Player Fantasy 章節依使用者裁決 A2 整段重寫,嚴重度排序與取捨聲明措辭一致化 | 隨 B6 裁決一併處理,原問題描述的矛盾已不存在;R3 對同章節的 D-5 修訂(取捨的殘餘成本)是獨立的新發現,非本項復發,見 R3-B10 |
| S5 | `max_save_slots`、`save_write_max_duration_ms`、`migration_chain_load_time_budget_ms` 三個旋鈕皆待實測校準,目前僅有建議方向、無實際數值 | R1 | 已建立旋鈕欄位;R2 新增遷移函數複雜度上限旋鈕(免旋鈕值,契約型)、寬限上限規則、AC-46;R3 補上寬限上限規則的精確觸發條件定義(量測環境/最小間隔/最大間隔)與追蹤責任指派 | 部分——欄位存在,數值待補;R3 新增的觸發條件定義本身是交付物 | 待 UI 系統設計/`/create-architecture` 階段實測後填入起始值;寬限期規則本身已從「存在但可能無人執行」轉為「可稽核」 |
| S6 | 主機平台是否為目標平台尚未定案,Core Rules #4/#14 的 provisional 狀態依賴此決定 | R1 | 已標記 provisional + Open Question;R3 補充:provisional 範圍限定為一般寫入路徑,遷移執行模型已於 R3 獨立定案(不再與此項綁定,見 D-2);**R4:已解決**——game-designer 發現本項依據的前提(「`game-concept.md` 僅登記 PC」)與 `.claude/docs/technical-preferences.md`(登記 PC+Console)直接矛盾,使用者裁決以後者為權威、已回頭修訂 `game-concept.md`。**主機現為既定目標平台,非待定項**——本項優先度由「平台策略定案時、無限期延後」升級為「`/create-architecture` 開始前必須解決」 | 是——`game-concept.md`/`save-system.md` 平台範圍聲明/Open Questions 皆已同步修訂 | **此項已從遺留帳本畢業,不再是懸而未決的延後項**——後續追蹤移至 Open Questions 表對應列與 `/create-architecture` 必辦項清單,不再需要每輪重新登記於此帳本 |
| S7 | 型別白名單(Core Rules #9)版本分域範圍未定 | R2 | 已登記為 `/create-architecture` 必辦項(非 GDD 阻擋);R3 未變動 | 是——Open Questions 新增列 | security-engineer 提出的攻擊路徑,creative-director 綜合裁決降級(單機無伺服器信任邊界,機制需等格式定案),非本文件阻擋 |
| S8(新) | Core Rules #13 自動痊癒路徑(二)的維運層級重跑觸發機制與狀態轉換模型未定義 | R3 | 已登記為 `/create-architecture` 必辦項,已補上資料前提(創世保留、完成標記+拼接範圍限定) | 是——Open Questions 新增列、Core Rules #13 已補上限定範圍 | R3 由「保證」措辭降級為「資料前提已保證,程序留待架構階段」,見 R3-B9;不計入 GDD 層級阻擋,但架構階段若略過此項,路徑(二)將形同無法使用 |
| S9(新) | 電源中斷(斷電)情境下 `FileAccess.flush()` 是否有等效的硬體層級落盤保證,GDScript 目前未知是否可直接呼叫 | R3 | 已登記為 `/create-architecture` 必辦查證項,已縮小 GDD 承諾範圍(僅保證進程層級當機) | 是——Core Rules #14 耐久性範圍聲明、Open Questions 新增列 | godot-specialist 提出,自陳為回憶而非即時查證;查證結果若為「無法達成」,電源中斷資料遺失維持已接受的殘餘風險,不需回頭修改 GDD 承諾範圍(已經是縮小後的版本) |
| S10(新) | 存檔目錄位置(`user://`)與 `.tmp`/`.dat` 須同檔案系統的前提,先前僅隱含於原子性論證中未明文 | R3 | 已登記為 `/create-architecture` 必辦項 | 是——Open Questions 新增列 | godot-specialist 提出;所有當機安全論證隱含依賴此前提,架構階段須把它落實為硬性配置要求而非繼續隱含 |
| S11(新) | Steam Cloud(或其他雲端存檔同步)與本輪新增的多檔案佈局(`.pre_migration.bak`/`.prev.bak`)如何互動尚未評估 | R3 | 已登記為 Open Question,待平台/發行策略定案 | 是——Open Questions 新增列 | performance-analyst 提出,creative-director 上調優先度(理由:R3 新增的持久備份機制放大了此風險面,不再是可忽略的邊角情境) |
| S12(新) | Core Rules #10 退役名稱治理規則的自動化檢查,要到 `/create-architecture` 階段才會真正建置完成——在此之前,本規則的實際執行力等同升級前,仍完全依賴人工審查紀律,這是本文件自陳最高風險失敗類別在過渡期窗口的殘餘風險 | R4 | 已補上過渡期殘餘風險聲明(比照 Core Rules #14 耐久性範圍聲明的既有寫法)+ 本 Ledger 列 | 是——Core Rules #10 新增聲明段落 | security-engineer 發現(對比 Core Rules #14/#13 皆有明文殘餘風險聲明+Ledger 列,Core Rules #10 原本沒有,可能讓讀者誤以為風險已解決);待 `/create-architecture` 自動化檢查真正交付、AC-51 可被實際執行後,此列可畢業 |

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

---

## Review — 2026-08-06 — 第四輪(完整模式對抗性重新覆核,聚焦三性質)

**Verdict**: NEEDS REVISION
**Scope signal**: XL(系統本身)| 本輪修訂工作量:**S**(三輪以來首次降到 S)
**Specialists**: game-designer、systems-designer、godot-specialist、qa-lead、performance-analyst、security-engineer(六位並行審查,依 creative-director 第三輪建議聚焦時序完整性/承諾可證成性/跨文件一致性三性質)、creative-director(綜合裁決)
**Blocking items**: 8(去重合併後,含 2 項嚴重度改判)| **Recommended**: 12 | **Nice-to-have**: 5

**Summary**: creative-director 逐條追蹤查證後確認一個結構性訊號:本輪 8 項阻擋**全部**源自第三輪 D-1~D-5 使用者裁決新增的規則自身,缺了「矩陣列 / 專屬 AC / 範圍聲明」三件套之一——不是新的設計缺陷,是修訂流程本身的交付完整性缺口。三輪定性依序是 R1「防線不存在」→R2「防線都在但預設值設反」→R3「防線都設對了但接縫未言明」→**R4「R3 修法自己的接縫未言明」**,是同一終末類別的二階實例而非新失敗模式。三組發現達成跨專家獨立收斂:(一)路徑(二)維運拼接的完整性重算義務缺失(security-engineer+systems-designer+game-designer 三方獨立收斂,本輪最高優先,直接命中使用者交辦的特別查證任務);(二)分步執行引入的同槽重入視窗未被宣告(godot-specialist+performance-analyst 獨立收斂,與 systems-designer 的降級判定形成嚴重度分歧,creative-director 裁決維持 BLOCKING);(三)D-4 滾動備份的接縫(security-engineer+godot-specialist 從不同角度收斂於同一功能)。此外意外發現 `technical-preferences.md` 與 `game-concept.md` 對主機平台矛盾的專案級文件問題,經使用者裁決以前者為權威解決。

**User decisions(修訂前置)**:
1. 平台矛盾裁決:**採納 creative-director 建議**——以 `technical-preferences.md`(PC+Console)為權威,回頭修訂 `game-concept.md`(原僅登記 PC)。連帶使 Core Rules #4 的 provisional 解決時點由「無限期延後」提前為「`/create-architecture` 開始前必須」。
2. 創世存底冗餘保護(原 qa-lead 提議可能需要的 D-6):**不需要使用者裁決**,採 creative-director 代為裁決的預設方向(誠實下修措辭+條件式告知),不額外加碼保護等級。

**Revision list(blocker → fix applied)**:

| # | 阻擋項摘要 | 修訂內容 |
|---|---|---|
| R4-B1 | 路徑(二)維運拼接完整性重算義務缺失,遷移完成標記本身不受任何完整性保護(security-engineer+systems-designer+game-designer 三方獨立收斂,本輪最高優先) | Core Rules #8 頂層雜湊輸入 tuple 擴充涵蓋遷移完成標記;Core Rules #13 路徑(二)新增第 4 項硬性前提(拼接後須重算逐區塊+頂層雜湊,且回寫須重用標準管線);Core Rules #16 矩陣新增對應列;新增 AC-61 |
| R4-B2 | 分步執行(D-2)引入的同槽重入不變量從未被宣告(godot-specialist+performance-analyst 收斂;與 systems-designer 的 NICE-TO-HAVE 判定分歧,creative-director 裁決維持 BLOCKING——理由:「輪詢輸入」是文件自己列出的讓出期間行為,重入管道是文件自己寫進去的) | Core Rules #5 新增同槽重入不變量(同槽分步執行期間拒絕第二個讀/寫呼叫);矩陣第五列補上反面宣稱;新增 AC-59 |
| R4-B3 | D-4 滾動備份步驟四自我違反步驟零存在理由,含永久卡死風險;`.prev.bak` 未被 Core Rules #13 逐字枚舉涵蓋;Open Questions 對應列殘留 D-4 修法前的舊敘述(godot-specialist+security-engineer 從不同角度收斂於同一功能) | Core Rules #14 新增步驟 4a(rename 前先刪除既有 `.prev.bak`);Core Rules #13 唯讀介面枚舉擴大涵蓋 `.prev.bak`;Open Questions 對應列改寫反映 D-4 後序列 |
| R4-B4 | manifest-only 輕量讀取介面零 AC、零矩陣覆蓋——本系統流量最高的互動路徑完全沒有完整性檢查規範(game-designer) | Core Rules #5 manifest-only 段落新增完整性檢查要求(須套用 Core Rules #8 頂層標記檢查);矩陣新增對應列;新增 AC-60 |
| R4-B5 | 創世存底無位元腐蝕保護,Player Fantasy「與正常存檔同等完整」為過度宣稱,強制主動告知無例外條款(qa-lead,提出可能需要 D-6,creative-director 代為裁決不需使用者介入) | Player Fantasy 措辭改為「逐位元組相同」(內容等同,非保護等級等同)+ 補上殘餘風險聲明;States 表與 Interactions 的強制主動告知改為條件式(唯讀資料損毀時改為明確告知「備份本身也已損毀」) |
| R4-B6 | 承諾可證成性掃描三處殘留合併處理:(a) 遷移檢查失敗的零副作用從未被斷言(qa-lead);(b) Core Rules #10「升級為硬性規則」未揭露過渡期殘餘風險(security-engineer);(c) Player Fantasy 第 20 行「玩家從不需要想到存檔」未因 D-5 誠實揭露加註範圍(game-designer,與 R3-B5 同型) | AC-32 擴充斷言範圍(驗證回寫確實從未開始,非僅回傳值正確);Core Rules #10 新增過渡期殘餘風險聲明+Ledger S12;Player Fantasy 第 20 行加註範圍聲明 |
| R4-B7 | Cross-System Obligations Registry 對 save-system.md 施加的八項硬性義務零列登記(game-designer 發現為 RECOMMENDED,creative-director 上調為 BLOCKING——理由:D-5 整套「把玩家決定從永遠失去改成帶著完整歷史重新開始」的論證完全依賴下游 UI 執行主動告知義務,若承接系統看不到此義務,D-5 的價值靜默歸零) | `systems-index.md` Cross-System Obligations Registry 新增 8 列,涵蓋存檔管理 UI(六項)、章節/戰役結構、活棋盤地形演變系統 |
| R4-B8 | 平台矛盾——`technical-preferences.md`(PC+Console)與 `game-concept.md`(PC-only)直接矛盾,Ledger S6 的最低優先度延後建立在可能已錯的前提上(game-designer) | 見上方 User decisions;`game-concept.md` 平台列修訂;`save-system.md` 平台範圍聲明、Core Rules #4、Open Questions 對應列同步修訂;Ledger S6 升級為已解決並畢業 |

**Recommended revisions applied(同批完成)**:
- Core Rules #16 矩陣第二列補上「逐步驟」措辭,明示 #12/#7 檢查粒度非「鏈完成後一次性」(systems-designer,深度 50 邊界值測試發現)
- 矩陣新增讀取路徑排序列(#8→#9→#7/#5,game-designer+systems-designer 收斂,嚴重度由 BLOCKING 降為 RECOMMENDED——理由:Core Rules #8 本身已有明文排序指令,缺的是矩陣鏡射,非正確性問題)
- Tuning Knobs 儲存倍數區分穩態常駐(3×)與寫入瞬間峰值(4×),「上限」測辭修正為峰值專用(performance-analyst,逐步核算確認 4× 而非文件原 3× 或使用者假設的 5×)
- 遷移鏈耗時模型補上與資料量無關的加性下限(Σ計算耗時 + 鏈深度×每步讓出固定成本),影響 `max_supported_migration_depth` 重新評估觸發條件(performance-analyst)
- AC-46 第一段拆分為「遷移函數計算耗時」與「步間讓出排程等待耗時」兩個獨立子項,消除混算導致的誤導性根因判讀(performance-analyst)
- Core Rules #8 頂層雜湊「固定順序」明確定義為與寫入迭代順序無關的規範順序(例如依來源系統識別碼字典序,game-designer)
- Formulas 章節補上與 Tuning Knobs 備份倍數的交叉引用(systems-designer)
- `Resource.DEEP_DUPLICATE_ALL`/`DEEP_DUPLICATE_INTERNAL` 具名 API 比照 `OS.get_thread_caller_id()` 標記為待查證,統一文件內部查證標準(godot-specialist)
- `affinity-data-pool.md` Open Questions 新增第 11 項,反向引用 `save-system.md` Core Rules #8 威脅模型聲明(單向落差,非矛盾,security-engineer)
- Ledger S2/S3 明文記錄本輪重新評估已發生,避免自動升級規則靜默觸發(game-designer)

**creative-director 對個別專家嚴重度判定的裁決**:
- godot-specialist+performance-analyst「分步執行同槽重入」BLOCKING vs systems-designer「同一問題」NICE-TO-HAVE → **維持 BLOCKING**(理由見上方 R4-B2)
- game-designer「讀取管線順序未定義」BLOCKING vs systems-designer「同一問題」RECOMMENDED → **降為 RECOMMENDED**(Core Rules #8 已有明文排序指令,矛盾的是矩陣未鏡射既有規則,不是規則本身有洞)
- systems-designer「矩陣檢查粒度未區分逐步驟」BLOCKING → 降為 RECOMMENDED(Core Rules #12/#7 規範文本已用「每個」二字排除歧義,矩陣措辭補強是維護性而非正確性問題)
- performance-analyst「4× 儲存峰值」「AC-46 混雜」「耗時模型加性下限」三項 BLOCKING → 皆降為 RECOMMENDED(與 R2/R3 既有的效能類降級標準一致:缺的是校準精度或診斷儀器,不是正確性,失敗模式為安全失敗)
- game-designer「Cross-System Obligations Registry 零登記」RECOMMENDED → **上調為 BLOCKING**(理由見上方 R4-B7)

**Prior verdict resolved**: 是——第三輪 NEEDS REVISION 的 11 組阻擋已於第三輪同一 session 全數修訂(見上方第三輪記錄),第四輪針對這些修訂本身的對抗性覆核發現新的 8 組阻擋(全部源自 D-1~D-5 新增規則的三件套缺漏,非新設計缺陷),已於本輪(同一 session)全數處理完成。

**未隨此輪處理(明確記錄,非遺漏)**:序列化格式本身、`FileAccess.flush()` 的 fsync 等效行為、`DirAccess.rename()` 平台語意、型別白名單版本分域、`OS.get_thread_caller_id()`/`get_main_thread_id()`/`Resource.DEEP_DUPLICATE_ALL` 的 4.7.1 API 名稱查證、`user://` 同檔案系統前提、路徑(二)的觸發機制與狀態轉換模型、Steam Cloud 多檔案佈局互動、`max_supported_migration_depth` 數值上限、`affinity-data-pool.md` AC-47 重開——皆為 creative-director 明確提醒「在沒有引擎接觸的情況下本質上無法在 GDD 層解決」的項目,本輪未變動,且**明確要求第五輪(或任何後續 GDD 輪次)不得將上述項目再次列為阻擋**。

**creative-director 第五輪退場條件建議**:第五輪**只**驗證兩件事,不開新領域:(一)本輪八項阻擋的修法本身沒有製造第九個接縫——用本輪新增的矩陣完備性檢查表機械掃描,而非自由探索;(二)矩陣完備性檢查表本身完備——每條 Core Rule 都有矩陣列或無約束宣告,每條新規則都有 AC。若通過即應 APPROVED、移交 `/create-architecture`。creative-director 判斷本輪不是天花板(所有修法皆不依賴序列化格式/fsync/rename 平台語意等已知無法在 GDD 層解答的項目),但提醒:若第五輪仍出現 5 項以上**新類別**的阻擋(而非本輪修法的接縫),才是真正的天花板訊號,屆時正確動作是接受現狀移交架構階段,而非繼續紙上迭代。

---

## Review — 2026-08-07 — 第五輪(完整模式對抗性重新覆核,聚焦兩項退場條件)

**Verdict**: NEEDS REVISION
**Scope signal**: XL(系統本身)| 本輪修訂工作量:**S**(與第四輪同級)
**Specialists**: game-designer、systems-designer、godot-specialist、qa-lead、performance-analyst、security-engineer(六位並行審查,依 creative-director 第四輪建議聚焦「R4 修法本身有無製造新接縫」與「Core Rules #16 矩陣完備性檢查表本身是否完備」兩項退場條件)、creative-director(綜合裁決)
**Blocking items**: 11(去重合併後,含 3 項嚴重度分歧裁決)| **Recommended**: 4(Ledger S2/S3 畢業 + performance-analyst 3 項併入相鄰段落——其中 1 項已因矩陣補列間接解決)

**Summary**: creative-director 逐條追蹤查證後確認:本輪十一項阻擋**全部**可溯源至第四輪的具體修法或第四輪新增的矩陣完備性檢查表本身,沒有一項開新領域、沒有一項依賴已裁定「GDD 層無法解答」的項目(序列化格式/fsync/rename 平台語意/主機平台等)——六位專家守住了退場條件劃定的紀律。**性質定性**:R1「防線不存在」→R2「防線設反」→R3「接縫未言明」→R4「R3 修法自己的接縫未言明」→**R5「防呆機制建好了,但從未對自己執行過」**——十一項中五項是第四輪新增的完備性檢查表該抓卻只套用在當輪八項阻擋上、沒套用在為修那八項而寫的新條款上;一項是檢查表漏了自己(矩陣缺 #1/#2/#3/#15/#16,五位專家獨立收斂,本輪跨最多專家收斂的發現)。本輪最高優先發現由 systems-designer 與 security-engineer 從值語意/寫入責任兩個不同切面獨立收斂:Core Rules #8 頂層雜湊新納入的「遷移完成標記」欄位,第四輪只把語意寫在路徑(二)的前提清單裡,從未指派任何規則在一般路徑上實際寫入它——若只在路徑(二)執行時才寫,標記需要記錄的時機早已錯過,路徑(二)機制形同虛設。第二優先由 godot-specialist 單獨發現但查證屬實且精確:Core Rules #14 步驟零的文字只涵蓋「步驟四」,未同步涵蓋第四輪新增的步驟 4a,若中斷發生在特定時間點,會經另一條路徑重現第四輪明文要防止的「該槽後續所有寫入被步驟零永久卡住」。第三優先由 systems-designer/godot-specialist/qa-lead 從三個角度收斂於同一根因:Core Rules #15「僅供 QA/除錯用途」的開場定位與其「遷移進度查詢介面」被 States/Interactions/systems-index 登記為下游硬性義務的實際用途字面矛盾,且與 Core Rules #5 同槽重入不變量的交互從未定義,導致 AC-14b(遷移期間查詢必須成功)與 AC-59(遷移期間第二個讀寫呼叫必須被拒絕)字面上可被誤讀為互斥。security-engineer 額外發現 Core Rules #10 過渡期殘餘風險聲明低估曝險範圍——退役名稱重用若未伴隨版本躍遷,AC-41/AC-42 完全不適用,現有防線對此子情境零覆蓋,比聲明描述的「與升級前執行力相同」更嚴重。game-designer 發現 Player Fantasy 對唯讀匯出資料的技術宣稱(「與創世存底逐位元組相同」)已與 Core Rules #13/States/Interactions 第四輪跟上的泛化優先序(優先回傳 `.dat`)矛盾,以及 `systems-index.md` 第 164 列同時綁定兩項義務但關閉條件只驗證其中一項(與 creative-director 第四輪把 Registry 零登記上調為 BLOCKING 的論證同構)。qa-lead 發現 AC-61 的前提在路徑二觸發機制交付前完全不可執行,未比照 Core Rules #10/AC-51 的既有範式明文標註;以及 Ledger S2/S3 的「交付物存在性=否」欄位與備註欄「不觸發自動升級」文字自相矛盾,且客觀已達 3 輪觀察窗。performance-analyst 本輪**零 BLOCKING**——三項發現(矩陣缺 #15 的效能面向、路徑二雜湊重算耗時量級零聲明、4 倍峰值計算未言明是否涵蓋路徑二額外副本)皆判定為 fail-safe,與前三輪一致選擇不升為 BLOCKING,creative-director 對其中「矩陣缺 #15」一項的分歧予以上調(見下方裁決)。

**嚴重度分歧裁決(creative-director)**:
1. performance-analyst「矩陣缺 #15」判 RECOMMENDED vs 其餘四位判 BLOCKING → **裁決 BLOCKING**:文件自己在第四輪頒布「每條規則必須有矩陣列或無約束宣告」為硬性要求,而這條缺列在本輪確實產生實害(#15 若被逼著宣告關係,第四輪就會發現與 #5 重入不變量的互斥),不是純衛生問題。
2. game-designer 判步驟 4a 缺 AC 為 RECOMMENDED vs systems-designer 判 BLOCKING → **裁決 BLOCKING(合併後)**:與矩陣固定順序條款缺 AC、步驟零補完行為缺 AC 合併後,不再是孤立的一條 AC,而是「檢查表未對自己執行」的證據集合。
3. godot-specialist 判 manifest-only 重入範圍為 RECOMMENDED → **上調並併入介面分類表**:與 AC-14b/AC-59 互斥是同一個「介面分類未定義」根因,一次修完避免 R6 生出第三個同類問題。

**Revision list(blocker → fix applied,同一 session 內完成)**:

| # | 阻擋項摘要 | 修訂內容 |
|---|---|---|
| R5-B1 | 遷移完成標記寫入責任與值語意全面未定義,路徑(二)機制實質形同虛設(本輪最高優先,systems-designer+security-engineer+game-designer 三方獨立收斂) | Core Rules #13 新增「遷移完成標記的寫入責任與值語意」段落:寫入責任指派給階段 B 每一次一般遷移回寫;非追加型區塊恆為顯式 `null`;路徑(二)拼接後不更新此標記(錨定創世遷移點);新增 AC-62(單獨竄改此欄位觸發 `DATA_CORRUPTED`)、AC-63(驗證寫入責任確實履行) |
| R5-B2 | Core Rules #14 步驟零文字未涵蓋步驟 4a,經另一路徑重現永久卡死風險(godot-specialist) | 步驟零文字改為「依序」補完 4a(若 `.prev.bak` 存在則先刪除)與步驟四本身;新增 AC-66 驗證修正後行為 |
| R5-B3 | Core Rules #15 定位自相矛盾+與 #5 同槽重入不變量交互未定義,AC-14b 與 AC-59 字面互斥(systems-designer+godot-specialist+qa-lead 合併) | Core Rules #15 拆分為甲類(診斷,QA-only)/乙類(可觀測狀態,生產介面);新增介面分類表(6 種介面 × 生產/診斷、是否受重入約束、是否須套用 #8/#9);Core Rules #5 重入規則明確排除 manifest-only/進度查詢/唯讀存取三個豁免介面 |
| R5-B4 | AC-59「該槽處理中」缺結構化定義,與 Core Rules #6 四類代碼命名空間關係未定(systems-designer+qa-lead) | Core Rules #5 新增「該槽處理中」結果性質段落,比照 AC-4「無資料」既有範式定義為獨立、非錯誤、可與四類拒絕代碼明確區分的結果;新增 AC-67 |
| R5-B5 | Core Rules #16 矩陣完備性檢查表自我違反,#1/#2/#3/#15/#16 缺列或無約束宣告(五位專家獨立收斂,本輪跨最多專家收斂發現) | 矩陣新增 7 列/宣告(#1↔#8、#2↔#5、#3↔#4、#6 無約束宣告、#15 甲/乙兩類各一列、#16 自我豁免宣告) |
| R5-B6 | Core Rules #13 唯讀介面優先序兩處破口:(a) Player Fantasy 技術宣稱與實際優先序矛盾;(b) `.prev.bak`/`.pre_migration.bak` 優先順序未定義(game-designer) | Player Fantasy 措辭改為泛用「依優先序回傳當下可安全解析的最新完好內容」,殘餘風險論證擴大涵蓋三種可能來源;Core Rules #13 明訂 `.prev.bak` 優先於 `.pre_migration.bak`;AC-39 同步更新 |
| R5-B7 | 第四輪新增條款缺專屬 AC 三處:步驟 4a、Core Rules #8 固定順序規範、步驟零補完行為(systems-designer+game-designer) | 新增 AC-64(步驟 4a 具體行為)、AC-65(固定順序對容器迭代變動的免疫性)、AC-66(步驟零正確涵蓋 4a,與 R5-B2 共用) |
| R5-B8 | AC-61 前提在路徑二觸發機制交付前完全不可執行,未比照 Core Rules #10/AC-51 既有範式標註(qa-lead) | AC-61 新增不可執行狀態聲明,併入 Ledger S8 追蹤 |
| R5-B9 | Core Rules #10 過渡期殘餘風險聲明低估曝險——退役名稱重用若未伴隨版本躍遷,AC-41/42 完全不適用,現有防線零覆蓋(security-engineer) | 過渡期殘餘風險聲明新增「曝險範圍的精確化」段落,明確區分伴隨/未伴隨版本躍遷兩種子情境的實際覆蓋率差異,同步更新 Ledger S12 引用 |
| R5-B10 | `systems-index.md` 第 164 列雙義務單關閉條件,「不得允許無告知重試」義務可被靜默視為已清償(game-designer,理由與 creative-director 第四輪把 Registry 零登記上調 BLOCKING 同構) | 第 164 列拆分為兩列,各自獨立的關閉條件 |
| R5-B11 | Ledger S2/S3 欄位自相矛盾(「交付物存在性=否」vs 備註「不觸發升級」),客觀已達 3 輪觀察窗(qa-lead) | 比照 Ledger S6 既有範式,S2/S3 從 Ledger 畢業,移入 Open Questions 並各自綁定明確閘門(序列化格式定案時/累積 3+ 規則集版本時) |

**Recommended revisions applied(同批完成)**:
- Core Rules #13 路徑(二)雜湊重算義務新增耗時量級聲明(未估算,留待架構階段,不預先假設可在互動時間尺度內完成)(performance-analyst)
- Tuning Knobs 4 倍峰值計算新增路徑(二)範圍聲明(若不另外持有中繼拷貝則峰值相同,但此假設未經驗證)(performance-analyst)
- 新增「Completeness Execution Record」完備性執行紀錄表(16 條 Core Rules × 三件套執行狀態、67 條 AC × 可執行性標註)——creative-director 指定此表為本輪移交條件本身,不是宣告要做而是把執行結果寫進文件,使本文件從「經過五輪專家抽樣審查」升級為「經過一次構造上窮盡的完備性檢查」

**creative-director 對本輪終止條件的重新校準**:嚴格按第四輪判準(5 項以上**新類別**阻擋)——不是天花板,0 項新類別,11/11 全部溯源。但阻擋數 24→9→11→8→11 非單調,creative-director 指出接縫產生率約 1:1,以「找不到問題的一輪」為終止條件在此比率下不可達,改採「找到的問題若不修,不會讓實作者建錯東西的一輪」——本輪 5 項屬此類(已修),6 項屬追蹤性資產(已一併修)。**建議修訂完成後無條件移交 `/create-architecture`,不安排第六輪 `/design-review`**,理由:完備性執行紀錄表使本輪從「專家抽樣」升級為「構造上窮盡」,遞迴在不動點被執行後收斂,而非因為停手。

**Prior verdict resolved**:是——第四輪 NEEDS REVISION 的 8 組阻擋已於第四輪同一 session 全數修訂(見上方第四輪記錄),第五輪針對這些修訂本身與矩陣完備性檢查表本身的對抗性覆核發現新的 11 組阻擋(全部源自第四輪的具體修法或檢查表自身,非新設計缺陷),已於本輪(同一 session)全數處理完成。

**未隨此輪處理(明確記錄,非遺漏)**:序列化格式本身、`FileAccess.flush()` 的 fsync 等效行為、`DirAccess.rename()` 平台語意、型別白名單版本分域、三組 Godot API 名稱查證、`user://` 同檔案系統前提、路徑(二)的觸發機制與狀態轉換模型、Steam Cloud 多檔案佈局互動、`max_supported_migration_depth` 數值上限、`affinity-data-pool.md` AC-47 重開——皆為 creative-director 明確提醒「在沒有引擎接觸的情況下本質上無法在 GDD 層解決」的項目,本輪未變動。AC-24 浮點容差(原 Ledger S2)、遷移鏈孤兒終止函數歸屬(原 Ledger S3)已從 Ledger 畢業並移入 Open Questions,各自綁定明確閘門,非遺漏。

---

## Approval — 2026-08-07 — 使用者裁決:核准,跳過第六輪

第五輪 11 項阻擋已於同一 session 內全數修訂完成(見上方第五輪記錄)。creative-director 建議修訂完成後無條件移交 `/create-architecture`、不再安排第六輪 `/design-review`,理由:本輪新增的「Completeness Execution Record」完備性執行紀錄表(16 條 Core Rules × 三件套執行狀態、67 條 AC × 可執行性標註)使本文件從「經過五輪專家抽樣審查」升級為「經過一次構造上窮盡的完備性檢查」,遞迴在自身的不動點被實際執行後收斂,繼續紙上迭代預期只會找到追蹤性級的新接縫。

**使用者裁決**:採納 creative-director 建議,核准本文件跳過第六輪 `/design-review`,狀態由 Designed 改為 **Approved**。`design/gdd/systems-index.md` 對應列與 Progress Tracker 已同步更新(Design docs reviewed/approved 各由 1 增至 2)。

**移交條件自我檢驗(供 `/create-architecture` 階段參照)**:依 creative-director 第五輪裁決第七節列出的三個可驗證訊號——(1)架構階段回頭對本 GDD 提出的問題應全部落在既有 Open Questions 列之內(序列化格式、fsync、rename 平台語意、主機平台、白名單分域、路徑二觸發機制、Steam Cloud、`user://`、三組 API 名稱查證,以及本輪新畢業的 AC-24 浮點容差、孤兒遷移函數歸屬);(2)Completeness Execution Record 應在架構階段被實際引用查核規則約束;(3)R5-B1 遷移完成標記的寫入時機決定不應在架構階段被重開。若架構階段前期出現三個以上「這條規則讀不出該怎麼實作」的回頭詢問,應視為本次核准過早的訊號,回頭補一輪 `/design-review`。

---

## Review — 2026-08-11 — 第六輪(完整模式對抗性覆核,聚焦四項既有殘留缺口)

**Verdict**: NEEDS REVISION → 已於同一 session 內完成修訂
**Scope signal**: L(六位專家原始評估;security-engineer 意外發現的完整性鏈條缺口經使用者核准擴大範圍後,實際落地範圍與原 L 一致,未升級為 XL——因 D-1 選擇 A+ 而非 B2,不新增持久化結構)
**Specialists**: systems-designer、security-engineer、narrative-director、godot-specialist、game-designer、qa-lead(六位並行審查,分別聚焦四項缺口)、creative-director(綜合裁決)
**Blocking items**: 10(B1-B10,見下方逐項)| **Recommended**: 3(Player Fantasy「殘餘成本」段落可讀性、Open Questions 架構階段清單提取、Completeness Execution Record 逐義務檢查試行——皆未落地,列為未來輪次參考)

**背景**:本輪處理三項自 2026-08-09 `/review-all-gdds` 起長期擱置的跨文件殘留缺口(D-1、F2-1、F2-2)以及「三路終止漏第四支」(遷移語意成功但 Core Rules #13 回寫因 I/O 失敗未完成,`end` 永不呼叫,原權杖永久卡死問題原樣重現)。六位專家並行審查,systems-designer/security-engineer 聚焦第四路徑,narrative-director 聚焦 D-1,godot-specialist 聚焦 F2-1,game-designer 聚焦 F2-2,qa-lead 橫向掃描四者的 AC 覆蓋與 Completeness Execution Record 同步風險。

**Summary**:six 位專家逐一交出具體修法草案,四項缺口的方向皆收斂,無使用者裁決陷入僵局的分歧。**security-engineer 意外發現的伴生缺口是本輪最重要的技術發現**:Core Rules #8 的雜湊涵蓋範圍被四輪修訂寫到極其精確,卻從未定義雜湊輸入的**來源**——若取自「寫入後讀回的磁碟位元組」而非「寫入前已驗證的記憶體資料」,一次磁碟已滿造成的截斷寫入會被如實雜湊、manifest 與 payload 永久自洽,Core Rules #8 兩層雜湊防線對此完全無感,不需要任何攻擊者。同時 Core Rules #14「確保內容完整寫入並 flush」從未指定任何檢查機制,`store_*`/flush 失敗訊號若未被實際檢查,序列可能靜默把截斷內容 rename 扶正。qa-lead 獨立發現 Completeness Execution Record 表二本身已存在一處實證矛盾(標題於第八輪已改為「68 條」,結尾結果句卻仍寫「65 條」「63 條」),是本文件自身的三件套漏一件實例。

**creative-director 綜合裁決核心論點**:(1)第四路徑與完整性鏈條缺口雖共用觸發情境,但缺陷類別不同,立為獨立議題但同輪處理(第四路徑「保證呼叫 end」的成立前提依賴完整性鏈條缺口的修法,分輪會讓新增 AC 從誕生當天就懸空);(2)D-1 修正 narrative-director 對「終局快照」方案的成本估算——該方案會讓揭露義務對 `source_absence` 實質消失(不是被滿足,是無從觸發),提出第三方向 A+(終局判定 + 過程中誠實告知)補回這個損失,成本僅一條登記義務,遠低於承認可逆性+凍結旁表(B2)需要新增一級持久化區塊的代價;(3)F2-1 駁回 godot-specialist 原提的「消費者導向」判準(以「是否有下游讀取」判斷管轄範圍),改為「登記制」(以共用列舉登記為唯一判準),理由是消費者導向判準會讓管轄範圍隨未來下游設計選擇悄悄改變,重演本文件招牌失敗模式;(4)F2-1 與 F2-2 必須共用同一個「暫停選單內讀檔」情境定義,錨點為 `save-system.md` Core Rules #5「觸發情境限制」——在此定義下兩者字面矛盾不成立(讀檔的真實序列必經非互動式載入過場、原表面必然卸載,不是「暫停→返回原畫面」路徑)。

**本輪使用者裁決(三項)**:
1. D-1 修法方向 → **選擇 A+(終局判定 + 過程中誠實告知,creative-director 傾向選項)**:`source_absence` 移出 game-concept.md「單調不可逆」豁免清單,僅得於戰役終局判定當下呼叫一次判定互斥獨佔內容,戰役中途得以可逆的事實呈現現況但不得宣稱永久關閉。
2. 處理範圍 → **選擇擴大為五項(creative-director 建議)**:security-engineer 發現的完整性鏈條缺口(雜湊輸入來源、寫入失敗偵測義務)同輪一併處理,獨立編號但不另開新輪。
3. 下一輪覆核模式 → **選擇目標型覆核,3 位專家(creative-director 建議)**:systems-designer(第四路徑與完整性鏈條修法的形式一致性)、qa-lead(AC 覆蓋、Completeness Execution Record 同步、F2-1×F2-2 情境定義是否真的被兩邊共用)、godot-specialist(`_input` 讓路機制與表面登記判準的引擎可行性)。附退場條件:若目標型覆核發現任一項修法製造了新接縫,即升級為完整模式重跑。

**本輪修訂內容(10 項阻擋全數於同一 session 內修訂完成)**:

| # | 阻擋項摘要 | 修訂內容 |
|---|---|---|
| B1 | Core Rules #8 雜湊輸入來源全文未定義,可能讓截斷寫入被誤判成功;Core Rules #13/#14「確保完整寫入」缺乏具體檢查機制 | Core Rules #8 新增「雜湊輸入來源定案」段落(寫入前記憶體資料,非讀回位元組);Core Rules #14 步驟 1 新增「確保」的具體定義(主動檢查返回值,失敗即中止);Core Rules #13 階段 A 明文繼承此義務;新增 AC-74、AC-75 |
| B2 | Core Rules #5 三路終止漏第四支(遷移成功但回寫 I/O 失敗,`end` 永不呼叫) | 新增路徑(四),保證呼叫 `end`(前提繫於 Core Rules #4 現行同步阻塞模型,已明文標注並綁定 Open Questions/Ledger S6);槽狀態維持「待遷移」,不新增拒絕原因代碼;新增 AC-73;新增重複失敗可觀察性義務(AC-76)+ Interactions 最低呈現契約新增條款 |
| B3 | AC-10 合併「進程終止」與「注入寫入失敗」,掩蓋兩者依賴不同保證機制的事實 | 拆分為 AC-10a(進程終止)/AC-10b(寫入失敗注入);耐久性範圍聲明同步修正引用對象 |
| B4 | Dependencies 章節三處落差(「兩條路徑」與 Core Rules #5 本體「四條路徑」不同步、「無上游依賴」與 begin/end 強制呼叫矛盾、與游標系統零登記依賴) | 生命週期通知段落改寫為四條路徑完整描述;「Foundation 層」措辭修正區分「定案依賴」與「執行期呼叫依賴」;新增對游標系統的資訊性交叉引用(非呼叫依賴) |
| B5 | Completeness Execution Record 表一 #5/#8/#13/#14 列未反映新增 AC;表二標題「68 條」與結尾結果句「65 條/63 條」既存不同步 | 表一四列同步新增 AC 編號與範圍聲明;表二標題改為「73 條」(AC-10 拆分淨增 1 + AC-73~76 四條);新增 K 節;結尾結果句修正為「73 條中 70 條可執行,3 條(AC-51、AC-61、AC-71)不可執行」 |
| B6 | cursor-highlight-state.md AC-23(暫停選單操作不竄改游標狀態)與 Core Rules #7(任何具懸停/游標目標表面皆受管轄)真矛盾 | Core Rules #7 新增「管轄範圍判準」(登記制:以共用列舉登記為唯一判準)+ 暫停選單/彈出對話框明文排除;AC-23 保留不動,補範圍註記(保證的是「無耦合」而非「本系統執行了保存/還原」);新增 AC-60 |
| B7 | 本系統 `_input` 級緩衝與暫停選單原生 focus 系統搶輸入事件,順序未定義 | Edge Cases 暫停選單條款新增「成立機制」段落,複用觸發點 (c) 失焦「不運算+重新播種」模式一般化至暫停/模態期間;具體讓路手段(`SceneTree.paused`+`process_mode`)委派 `/create-architecture`,新增 Open Questions 列;新增 AC-59 |
| B8/B9 | 存檔載入後陳舊游標目標無人標記失效;F2-1/F2-2 缺乏共用情境定義,有交互矛盾風險 | Core Rules #7「表面卸載前的目標交接義務」觸發情境明文擴充涵蓋存檔讀取;分列甲(舊表面存在時讀檔)/乙(無舊表面時讀檔,複用 Core Rules #6 初始狀態)兩種情境;責任歸屬呼叫方系統(戰棋移動與交戰系統),不歸屬存檔系統或游標系統本身;新增「時機點的安全窗口」段落以 `save-system.md` Core Rules #5「觸發情境限制」為共用情境定義錨點,明文說明 AC-23 與本節修法為何不矛盾;`systems-index.md` Cross-System Obligations Registry 第 165 列同步擴充;`save-system.md` Dependencies 新增資訊性交叉引用(見 B4) |
| B10 | D-1:`game-concept.md` 把 `source_absence` 與 `total_churn`/`reversal_count` 一併列為「單調不可逆」豁免特徵,但前者是即時查詢、可被玩家事後翻轉,前提不成立 | `game-concept.md`「範圍排除與揭露義務」新增 D-1 修法段落(移出豁免清單,終局判定 + 過程中誠實告知);`affinity-data-pool.md` 3g 段落新增「可逆性明文承認」+ AC-54 補範圍聲明 + 新增 AC-80;`systems-index.md` Cross-System Obligations Registry 新增列 |

**Prior verdict resolved**:是——第五輪 11 項阻擋已於第五輪同一 session 全數修訂完成並移交(2026-08-07 核准跳過第六輪),本輪處理的是移交後、2026-08-09 `/review-all-gdds` 發現且長期擱置的跨文件殘留缺口,非第五輪範圍內的回歸。

**未隨此輪處理(明確記錄,非遺漏)**:Recommended 三項(Player Fantasy「殘餘成本」段落拆分、Open Questions 架構階段清單提取、Completeness Execution Record 逐義務檢查試行)——creative-director 建議留待本輪修法穩定後單獨進行,避免在同一輪疊加高風險的可讀性重構;F2-3(存檔管理 UI 未被登記為正式系統)、F2-4(第 164 列承接名單不含暫停/存檔流程)、F2-5(硬性閘門範圍未涵蓋存檔管理 UI 槽瀏覽器)、F2-6(第 171 列已過期的三分級告知舊文案)——`/review-all-gdds` 2026-08-09 報告的 Warning 級發現,本輪未觸及,留待下一輪或相關下游系統設計時處理。
