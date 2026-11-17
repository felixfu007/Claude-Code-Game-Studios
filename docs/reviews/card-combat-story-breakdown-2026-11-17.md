# 卡牌改造「戰鬥部分」工單拆分總覽(2026-11-17,lead-programmer)

> 範圍:規格 `design/quick-specs/card-campfire-rework-v1-2026-11-12.md`(v1.0)的**戰鬥部分**。不含營火、牌組編輯頁、48 格/大地圖。工單在 `production/epics/skill-card-system/`,編號 010~025。
> 🔴 估計天數皆為粗估、未驗證(沿用 `docs/reviews/card-rework-data-format-2026-11-12.md` 第 4 節與排程文件第 2 節的類比估計,本專案無估實對帳)。
> 本次未讀:`docs/reviews/card-campfire-v1-creative-confirm-2026-11-12.md`、`card-rework-creative-review-2026-11-12.md`、`affinity-zero-state-proposal-2026-11-12.md`、v0.3 規格(`card-rework-cost-and-pool-2026-11-12.md`)、上午排程 `card-campfire-schedule-2026-11-12.md`(K0~K11 編號未對照)。凡引用它們處皆標二手或未驗證。

## 工單一覽

| 編號 | 標題 | 估 | 狀態 |
|---|---|---|---|
| 010 | 卡牌確認走 ADR-0001 提交入口(路徑⑥) | S~M | **Ready**(已當場 grep 確認 `card_play_session.gd` 無提交呼叫) |
| 011 | 資料模型擴欄(16 欄、`CostType.PAIR`、else→match) | M | Blocked:F1 付款人語意、卡 id 命名、F7 視線/c02 射程 |
| 012 | `state_of(pair)` + 冷淡區旋鈕(k=0 回歸) | M | **Ready**(以 k=0 先行;需先確認是否牽動 ADR-0002) |
| 013 | 位置系統改讀關係狀態 | M | Blocked:`affinity-position-chain.md` 公式五須先改;依賴 012 |
| 014 | 麥子健騎牆改「4 組全 NONE」 | M | Blocked:同 013;依賴 012、013 |
| 015 | 代價結算(付血/PAIR/先驗證後扣款) | L | Blocked:依賴 010、011、012;`AFFINITY` vs `PAIR` 分工待設計師確認 |
| 016 | 折損扣減並肩貢獻(5.1 表) | M | Blocked:依賴 012、013、015 |
| 017 | 補血與雙人甲類 | M~L | Blocked:依賴 010、011、015;距離函式選哪一份、免選目標路徑 |
| 018 | 直傷卡 + 擊殺鏈 | L | Blocked:依賴 010、011、015;F7 視線、反擊規則待裁決 |
| 019 | 合擊 c12 | M | Blocked:依賴 015、018;c12 細節待設計師確認 |
| 020 | 確認面板代價/不可打原因/選敵 UI | L | Blocked:ux-designer 規格不存在 |
| 021 | 關係三態顯示 | M | Blocked:ux 規格不存在;依賴 012 |
| 022 | 資料遷移 14 張卡 + 5 關一致性測試 | M | Blocked:依賴 011/015/017~019;id 命名、10A-1、D4 |
| 023 | 營火接口 seam(`effect_value` 外部覆寫) | S | Blocked:依賴 011;是否本批做待協調者判定 |
| 024 | 既有好感度測試「固定兩對」改寫 | M | Blocked:依賴 013、014 |
| 025 | 量測 M9 + `k` 候選 + M6 | M | Blocked:依賴 012、016、019、022 |

合計約 22~29 估計天(各單估計下限/上限加總,未驗證),另 020/021 的 ux 規格時間未計。

## 依賴圖與建議順序

```
010 ──┐
011 ──┼─> 015 ──> 016(也依賴 012、013)
012 ──┘     ├──> 017
 │          └──> 018 ──> 019
 ├─> 013 ──> 014 ──> 024
 ├─> 021(ux)        020(ux,依賴 015、018)
 └─> 025(最後;依賴 016、019、022)      022(依賴 011、015、017~019)
```

12/11 檢查點(排程文件的「卡牌戰鬥結算 + 關係狀態判定 N1~N3 做完」)對應本批:**010、011、012、015、017、018、019 + 013、014**。其中 013/014 卡在文件,是檢查點最大風險。可先並行起手(不依賴任何裁決):**010、012**。

## 待管理者/專家裁決題目

| # | 題目 | 擋哪些工單 | 誰裁決 |
|---|---|---|---|
| 1 | **F1 付款人語意**(`named_unit_id` 是否一律 = 付款人;或加第 17 欄) | 011、015、017 | game-designer + lead-programmer |
| 2 | 卡 id 命名 `c01` vs `card_01` | 011、022 | game-designer |
| 3 | **F7 直傷是否尊重視線/控制區**;c02 射程是卡面指定還是單位射程 | 011、018、019 | game-designer |
| 4 | 直傷擊殺有無反擊(現行規則未驗證) | 018 | 實作者查證 → game-designer |
| 5 | `AFFINITY` vs `PAIR` 的分工;好感度代價是否「真的寫池」(規格 5.2 說折損不寫池) | 015 | game-designer |
| 6 | c12 合擊細節(各自/合併傷害;第一擊擊殺後第二擊) | 019 | game-designer |
| 7 | **10A-1** 牌面敘事(預設甲案,未裁決) | 022 | 管理者 |
| 8 | D4 舊 6 張甲類去留 | 022 | 管理者/game-designer |
| 9 | `state_of` 是否動 ADR-0002 契約 | 012 | lead-programmer → technical-director |
| 10 | `k` 候選區間與判準 | 025 | systems-designer(10B) |
| 11 | ux 規格:確認面板、不可打原因、三態顯示 | 020、021 | ux-designer(尚未派) |
| 12 | 本批是否做 023 seam | 023 | 協調者 |
| 13 | 戰敗重打同一場是否保留牌組(N8;屬牌組編輯,**本批不拆**,不阻擋任何本批工單) | — | lead-programmer 10B(4) |

## 待管理者核准的既有檔變更(本次未改任何既有檔)

1. `design/gdd/affinity-position-chain.md` 公式五(麥子健恆無線)→ 解鎖 013、014、016。
2. `design/gdd/characters.md` 第三節(改為「開場時的關係」)、`design/gdd/skill-card-system.md`(界線 1/3/4)、`design/gdd/affinity-data-pool.md` 等(`active.md` D1~D8 共 8 份,規格第 7 節列出)。
3. `production/epics/skill-card-system/EPIC.md` 與 story 總表/story-index:登記 010~025(本次依約未動)。
4. `docs/registry/architecture.yaml`:若 012 的 `state_of` 算新 interface,須登記(待 technical-director)。
5. `docs/architecture/adr-0001-*`:無需改(010 是補符合它),但 EPIC 的「已知缺口」若有登記該漏洞,可標已處理。

## 已知風險與未驗證項

- 011 的 `.category` 其餘 7 處讀取點形狀、距離函式既有位置、`BattleScreen` 對 `FINISHED` 的處理、反擊規則:仍**未驗證**(沿用 data-format 文件第 6 節)。
- 012 的 `n_pair`、`combat_strength_read` 介面與 `links()` 行為,規格稱二手,實作者第一步查證。
- 排程把 N5(移除人設關係線/麥子健拒絕)併入 015(AC4),N8 不拆,N10(關係線畫面)未查未拆。
- 結局計分驗收 (8) 不在本批(程式裡無結局判定,排程文件建議移出營火)。
