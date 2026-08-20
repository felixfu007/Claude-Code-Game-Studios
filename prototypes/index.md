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
| **第七輪審查探針**——關閉第七輪 `/architecture-review` 對 ADR-0002 的四項未查證項(R7E-1/R7E-2/R7E-4/R7E-13) | 2026-08-20 | Godot 4.7.1 專案(三支獨立探針) | **concluded**(三支皆 exit 0,log 未過濾)。**R7E-1/R7E-13 關閉**(包裝類別宣告兩形皆編譯、兩層型別皆保住;三個 enum 轉換原語可用)。**R7E-2 由「未查證」升為已實測正確性缺口**——型別化 `Dictionary` 缺鍵讀取是 `SCRIPT ERROR` 並中止呼叫函式。**R7E-4 確認成立,並推翻機制四「`INVALID_PAIR`/`INVALID_SOURCE` 理論上不可達」**——越界 int 零檢查通過。衍生 R7-P1/P2/P3;執行者自陳並保留第一版失敗 log | [README.md](xcheck-round7-2026-08-20/README.md) |
