# 概念原型索引

專案所有概念原型(`/prototype`)與中期技術驗證(spike)的完整歷史紀錄。

## 概念原型

| 概念 | 日期 | 路徑 | 判決 | 報告 |
| --- | --- | --- | --- | --- |
| 好感度—位置連鎖 | 2026-07-28 | Paper | PIVOT | [REPORT.md](affinity-position-concept/REPORT.md) |
| 好感度—位置連鎖 v2 | 2026-07-28 | HTML | PIVOT(第 2 次) | [REPORT.md](affinity-position-concept-v2/REPORT.md) |
| 好感度—位置連鎖 v3(遠程武器) | 2026-07-28 | HTML | PROCEED | [REPORT.md](affinity-position-concept-v3/REPORT.md) |
| 好感度—位置連鎖 v4(新手驗證批次 · Track A 戰鬥端) | 2026-07-29 | HTML | PIVOT(測試場景缺陷,非機制失敗——v3 PROCEED 後的獨立驗證輪,非連續 PIVOT 鏈) | [REPORT.md](affinity-position-concept-v4/REPORT.md) |
| 好感度—位置連鎖 v4(新手驗證批次 · Track B 敘事端) | 2026-07-29 | Paper | PROCEED(附帶條件——局內/局外好感度分離需回 design-review 裁決) | [REPORT.md](affinity-position-concept-v4/track-b-narrative/REPORT.md) |
| 好感度—位置連鎖 v5(站位隨機化驗證批次) | 2026-07-30 | HTML | PARTIALLY CONFIRMED / PROCEED(附帶調校項——敵方強度、卡牌內容深度、角色識別度留給 /design-system) | [REPORT.md](affinity-position-concept-v5/REPORT.md) |

## 中期技術/設計驗證(Spike)

| 主題 | 日期 | 路徑 | 結果 | 報告 |
| --- | --- | --- | --- | --- |
| 戰役規模好感度模擬(design-review 第六輪硬性前置) | 2026-07-29 | Paper(手算) | CONFIRMED——不加權會產生不可達結局;指數衰減優於回溯窗口;λ 校準有取捨,需對照均衡經營策略門檻 | [README.md](affinity-campaign-simulation-2026-07-29/README.md) |
| 單一游標/高亮狀態系統——滑鼠奪權子機制 Godot 4.7.1 引擎行為驗證(`cursor-highlight-state.md` 第十輪 spike 前置) | 2026-08-05 | Godot 4.7.1 專案 | Test 1(offset transform 命中測試)CONFIRMED SAFE;Test 2(混合輸入)重新設計驗證通過,但發現觸發點 (d) + 持續按住方向鍵/搖桿會造成完整鎖死,新阻擋項待第十一輪 `/design-review` | [README.md](cursor-reclaim-godot-spike-2026-08-05/README.md) |
| 引擎行為驗證——解鎖 ADR-0002 進入 `Accepted`(ADR-0002 VR #1/#2/#3、ADR-0005 VR #1/#3/#15、`tests/` 六項未驗證) | 2026-08-20 | Godot 4.7.1 專案 | **Phase 1 concluded**(五次執行)—— **抓到 1 項 BLOCKING**(ADR-0002 機制四核心宣告無法編譯:巢狀型別容器不支援)、參考庫 `` 範例有誤、6 項 VR 關閉、3 項 spike 自傷已記錄。Phase 2(GdUnit4)待辦 | [README.md](engine-verification-spike-2026-08-20/README.md) |
| **交叉驗證**——`godot-gdscript-specialist` 對上一列 spike 的獨立覆核(獨立專案,排除環境污染變因) | 2026-08-20 | Godot 4.7.1 專案 | **concluded**(未過濾 log 已歸檔)。**推翻協調者三條結論**:F-9(d) 證據無效、F-9(c) 結論錯誤、F-3 層三推導鏈不成立且措辭過寬。另關閉 ADR-0002 VR #5 與四個內省 API。**F-3 層二在 release 建置未測 —— 決定「執行期會擋」能不能寫進 ADR** | [README.md](xcheck-gdscript-specialist-2026-08-20/README.md) |
| **第七輪審查探針**——關閉第七輪 `/architecture-review` 對 ADR-0002 的四項未查證項(R7E-1/R7E-2/R7E-4/R7E-13),外加探針 D 關閉執行者自陳的殘留 #1/#2 | 2026-08-20 ~ 08-21 | Godot 4.7.1 專案(**五支**獨立探針) | **concluded**(**五支皆 exit 0**,log 未過濾;⚠️ 本欄先前寫「四支探針」卻又寫「三支皆 exit 0」,兩個數字自相矛盾,2026-08-21 一併修正)。**R7E-1/R7E-13 關閉**(包裝類別宣告兩形皆編譯、兩層型別皆保住;三個 enum 轉換原語可用)。**R7E-2 由「未查證」升為已實測正確性缺口**——型別化 `Dictionary` 缺鍵讀取是 `SCRIPT ERROR` 並中止呼叫函式。**R7E-4 確認成立,並推翻機制四「`INVALID_PAIR`/`INVALID_SOURCE` 理論上不可達」**——越界 int 零檢查通過。衍生 R7-P1/P2/P3;執行者自陳並保留第一版失敗 log。**探針 D(2026-08-21)關閉殘留 #1/#2** —— `values().has()` 越界輸入與 `keys().has()` 非法名皆乾淨回傳 `false` 不中止,**R7-P1/R7-P3 建議修法地基成立,ADR-0002 修訂前置條件解除**;殘留 #3/#4 仍開(覆蓋面,不阻擋修訂)。**探針 E(2026-08-21)目標換為 ADR-0004** —— 沿用本專案只因 class cache 與紀律範本已在此,**不屬第七輪對 ADR-0002 的稽核範圍**:`@abstract` 裸簽章已對 **8 種**回傳型別實測(新增 `Variant`/`String`/`PackedByteArray`),**機制一 `SaveIOBackend` 的完整組合已逐字編譯通過**,具體子類別的 `-> Variant` 多型覆寫含經抽象基底型別的呼叫皆正常。**額外測出:字面 `ClassName.new()` 構造抽象類別是編譯期 Parse Error**(間接路徑未查證,登記為 ADR-0004 VR #6b);`is_abstract` 會進 class cache 結構化欄位 | [README.md](xcheck-round7-2026-08-20/README.md) |
| **ADR-0003 序列化格式與型別安全實機驗證**——探針 F(主)+ G / H / J(嵌套子探針,各自獨立專案) | 2026-08-21 | Godot 4.7.1 專案(`xcheck-stepdotfive-` 與 `xcheck-gdscript-shape-` 兩個子目錄在本目錄內) | **concluded**(**四支皆 exit 0**,log 未過濾)。🔴 **推翻 ADR-0003 全文級寫法**:`bytes_to_var(bytes, false)` 在 4.7.1 是 **Parse Error 根本不編譯**,ADR 全文 18 處逐字採用 —— 本專案第二次由實機擊落已寫下的 ADR 內容(第一次是 2026-08-20 ADR-0002 巢狀型別容器)。**但型別安全的核心論證經實測成立,只是 API 形狀寫錯,兩件事不可互相牽連。** 另測出:plain `var_to_bytes()` 對 Object 靜默編出 `EncodedObjectAsID`(`typeof=24`、`is Object` 為真);`HashingContext` 重複 `start()` 回 `ERR_ALREADY_IN_USE` 且**不重置**、`update(空)` 回 `FAILED`、`PackedByteArray` **沒有** `sha256_buffer()`;同一 `.gd` 內所有值為零的 float 常數會被編譯期去重。**關閉懸置三輪的 E1**(結論:`Callable`/`Signal`/`RID` 三者命運完全不同,不可一併敘述 —— `Signal` 還原後**全功能**,`emit()` 真的觸發處理函式) | [README.md](xcheck-adr0003-2026-08-21/README.md) |
| **存檔格式設計骨架**——把整份格式規格寫成可執行骨架跑起來(**設計層驗證,不是單一 API 探針**) | 2026-08-21 | Godot 4.7.1 專案(拋棄式,依 `.claude/rules/prototype-code.md` 不得被 `src/` 引用) | **concluded**(**三階段皆 exit 0**)。**13 項設計成立 / 🔴 推翻 7 項 / 暴露 16 個文件層的洞**(洞已全數登記於 `docs/architecture/adr-0003-deferred-to-implementation.md`)。兩項最重:(1) 兩個 `==` 相等但插入順序不同的 `Dictionary`,`var_to_bytes()` 出來的**位元組不同** → ADR 頂層雜湊輸入的條目型別正是 `Dictionary`,而 ADR 只處理了區塊**之間**的順序、沒處理條目**內部鍵**的順序 → **健康存檔會被誤判為損毀**;(2) `RID` 跨行程 id **完全相同且指向新行程剛好占用同號的活體資源**(`還原的RID == 本行程新配的RID` 為 `true`)—— 探針 F/G 都標為「最壞情況、未測」的那一格,實測**成立且具決定性,不是機率碰撞**。另抓到驗證器 `Callable` 的生命期問題、以及白名單完整性斷言「數量相加相等」是必要非充分條件 | [README.md](save-format-skeleton-2026-08-21/README.md) |
| **ADR-0002 VR#12**——`var_to_bytes()`/`bytes_to_var()` 對 `int`/`float` 的型別往返保真(機制八 R7E-10「`m` 嚴格 `TYPE_FLOAT`」的前提首次實測) | 2026-08-25 | Godot 4.7.1 專案(兩輪執行,皆 exit 0) | **concluded**。測項 1-4(float 整數值/非整數值/極端量級、int 含超 32 位元、ADR-0002 實際容器形狀)**型別與位元皆完整保真**,`m`/`t`/`c` 三個 VERDICT 欄位在容器往返後皆為 `true`——**R7E-10 的前提在本探針測到的範圍內成立,不會把合法存檔誤判為損毀**。測項 5:`INF`/`-INF`/`NAN` 往返後 `typeof()` 仍為 float,`is_finite()` 正確回傳 `false`。**意外測到、與 `var_to_bytes()` 無關**:`2.2250738585072014e-308`(IEEE754 正規化 double 最小值,非次正規化)等小量級 float **字面量**在宣告階段(零序列化呼叫)就已是 `0.0`——現象記錄在案,根因未查,不歸入本 VR 的判定 | [README.md](xcheck-adr0002-vr12-2026-08-25/README.md) |
