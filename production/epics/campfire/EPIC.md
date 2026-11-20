# EPIC:營火(campfire)

> **Status**: Draft(2026-11-20 `producer` 建立;**尚未經管理者核准**)
> **交付目標**:2027-01-22(管理者 11-13 裁決:日期範圍不動)
> **系統名**:`campfire-system`(`docs/registry/architecture.yaml` 的 `affinity_relation_state_single_judgment` 消費者清單已用此名,註明「系統尚未建檔,協調者暫填」;本 EPIC 沿用,系統索引登記仍待做)
> **規格權威**:`design/quick-specs/card-campfire-rework-v1-2026-11-12.md`(v1.0,狀態「草稿未核准」)第 4.3~4.6、5.2、6.1、6.3、8、9、10 節;v1.0 未推翻的 v0.3 第 6、6B 節(`design/quick-specs/card-rework-cost-and-pool-2026-11-12.md`)仍有效。**兩份同讀,以 v1.0 為準。**
> **排程依據**:`docs/reviews/card-campfire-schedule-v1-2026-11-12.md`(F1~F10、N6/N8/N11 對應到本 EPIC 工單,見下方對照)

## 現況(2026-11-20 實測)

```
$ grep -rnE "campfire|營火" src | wc -l
0
```

營火程式為零。**但下面這些營火要用的零件已經存在**(卡牌戰鬥部分做出來的):

| 零件 | 位置 | 狀態 |
|---|---|---|
| 關係狀態唯一判定 `AffinityRelation.state_of()` | `src/gameplay/affinity/affinity_relation.gd` | skill-card story-012 Done(k=0 先行) |
| 卡牌 `CostType.PAIR`、`Source.CAMP` | `src/gameplay/cards/card.gd`(grep `enum CostType` / `enum Source`) | story-011 Done |
| `PAIR` 代價依打牌當下關係結算 | story-015/016/026 | Done |
| 戰役累積記錄(營火寫入要落在這裡) | `src/gameplay/campaign/campaign_affinity_ledger.gd` | 存在,執行期記憶、不進存檔 |
| 累積記錄 → 新池子的重播 | `src/ui/battle/battle_screen.gd`(grep `campaign ledger replay record`) | 存在,**但寫在戰鬥畫面裡,營火讀不到** → 本 EPIC story-001 |
| 支援對話寫入累積記錄的寫入埠(營火寫入口的範本) | `src/gameplay/narrative/support_conversation_ledger_write_port.gd` | 存在 |
| 戰鬥之間插畫面的路由 | `src/ui/shell/scene_router.gd`(`go_to_support_conversation`) | 存在 |
| 卡牌數值外部改寫口(營火卡強度要用) | skill-card story-023 | 🔴 **Deferred**(管理者 11-17「本批不做」)→ 本 EPIC story-003 卡在這裡 |

⚠️ `AffinityTypes.Source` 只有 `COMBAT_CARD / SUPPORT_CONVERSATION / STORY_EVENT` 三值(`src/gameplay/affinity_pool/affinity_types.gd` grep `enum Source`),**沒有營火**。營火寫入用哪一個值、或要不要追加,是 story-002 的待決項。

## 範圍

1. 營火寫池:任選兩人 + 關心(`+m`)/質問(`−m`),寫入戰役累積記錄,下一場戰鬥讀到(v1.0 4.3)。
2. 營火產卡:先寫池、再依寫入後的 `v` 產合作/競爭卡,`cost_type=PAIR`、`source=CAMP`,強度快照(v1.0 4.4、4.5、5.2)。
3. 收藏區與牌組:**只在本輪遊玩記得,不進存檔**(v1.0 4.6);預設牌組、8~14 張、新卡自動入組。
4. 戰鬥改從確認後的牌組洗牌(取代各關固定牌表;教學場與第 1 場除外,見 story-005)。
5. 營火畫面、牌組編輯畫面(滑鼠 + 手把同等)。含 v1.0 6.3 第 (1) 項:寫入前顯示當前與寫入後的預期關係、「麥子健將失去騎牆」提示。
6. 營火插入戰役流程(戰鬥之間)。
7. 營火文案與營火卡字串入庫。
8. 端到端整合測試、M8 營火策略量測(並恢復 skill-card story-025 的 M9)。

## 不在範圍

- 🔴 **結局計分驗收(v1.0 驗收 (8))**:管理者 11-13 裁決移到結局系統。本 EPIC 只保證「營火寫入落在與支援對話同一份累積記錄」,**不驗證結局怎麼讀它**。
- **存檔**:不新增任何存檔欄位(v1.0 4.6、第 7 節)。
- **10 組支援對話劇本(中版 30 段)與「依關係挑段落」的程式**:屬支援對話 EPIC / 第 4 階段(排程第 3.4 節)。
- **丙類卡 card_07/08 是否放寬到任意兩人**:v1.0 10B 交 creative-director,其推薦(`docs/reviews/card-campfire-v1-creative-confirm-2026-11-12.md` 第 1 節)尚待管理者裁決。**營火寫入不經丙類過濾,所以不擋本 EPIC。**
- 冷淡區 `k` 的正式值:由恢復後的 skill-card story-025(M9)決定;本 EPIC 只產出能量它的資料。
- 營火背景美術、音效:未排(若要,另開美術工單)。

## 依賴

| 依賴 | 誰 | 狀態 | 擋哪張 |
|---|---|---|---|
| 營火畫面規格、牌組編輯畫面規格 | `ux-designer` | **不存在**(`ls design/ux/` 無此二檔,2026-11-20 實查) | 007、008、009 |
| 營火寫入許可路線、寫入用哪個來源值 | `lead-programmer`(好感度擁有者) | v1.0 10B 第 1 項,未答 | 002 |
| 牌組放在哪個執行期物件、戰敗重打保留可行性 | `lead-programmer` | v1.0 10B 第 4、5 項,未答 | 004 |
| 每輪次數、付款人規則、合作/競爭卡模板、營火與支援對話先後 | `game-designer` | 未定(v1.0 第 8 節「營火規格定」) | 002、003、006 |
| `m`、`base_value`、`pool_step`、`max_bonus` 初值;M8 門檻 | `systems-designer` | 占位(v1.0 第 8 節);creative-director 附條件「`m` ≤ 一次支援對話寫入量」 | 不擋寫程式(旋鈕放資料檔),擋 012 |
| 營火短句、20 張營火卡名與牌面 | `narrative-director` / `writer` | 十組關係前提草稿已有(`design/narrative/pair-premises-10-2026-11-12.md`,Provisional,含「營火切入點」);**營火短句本身未寫** | 010 |
| skill-card story-023(數值外部改寫口) | 管理者解除暫緩 | Deferred | 003 |
| 戰敗後回到哪裡 | 管理者 | 規格與 GDD 不一致(見 story-006) | 004、006 |

## 管轄 ADR

- **ADR-0002(好感度數值池,`Accepted`)**:營火是**新增的呼叫者**,v1.0 4.3 明寫「本檔不改 ADR-0002」。營火寫入落在 `CampaignAffinityLedger`,由下一場開局重播進池 —— 與支援對話同一路徑。**是否需要新許可、`can_write()` 保護等級如何對應:未驗證**(story-002 待 lead-programmer 答)。
- **登記表契約 `affinity_relation_state_single_judgment`**(`adr: none`,`docs/registry/architecture.yaml`):營火已列為消費者。義務:關係狀態**只能**呼叫 `AffinityRelation.state_of()`,`k` 只能從 `AffinityTuning` 取,不得另寫判斷。
  ⚠️ 該條目逐字:「Dead pairs … for campfire / post-battle contexts this was NOT verified as of 2026-11-17」。營火發生在勝利之後(任一我方陣亡即戰敗,故營火時五人皆存活),**推論上碰不到,未驗證**。
- **ADR-0003/0004(存檔)**:不適用(不進存檔)。
- **ADR-0005(游標/輸入)**:兩個新畫面要走既有游標/手把架構(游標圖層獨佔、自行過濾鍵盤 echo)。
- `grep -n "campfire" docs/registry/architecture.yaml` 只命中上述契約一處(2026-11-20 實查),**沒有營火專屬條目**。依流程劑量規則 3,預期**不需要新 ADR**;若 story-002 的答案是「要改池的許可契約」,那是跨系統契約,改由 `technical-director` 判斷。

## 兩個時點

| 時點 | 要到哪 | 沒到的後果 |
|---|---|---|
| **12-11 檢查點** | ①管理者兩題已裁決(戰敗回到哪、023 解除暫緩);②`ux-designer` 兩份畫面規格已交;③`lead-programmer`、`game-designer` 的待決項已答,002~006 全部轉 Ready;④**001 Done**,002~004 至少兩張 Done | 依管理者 11-13 裁決:卡牌戰鬥未完 → 大地圖與 48 格後挪,營火日期不動。**本 EPIC 自己的訊號**:若 12-11 兩份畫面規格還沒交,三張畫面工單(約 4.5~6 估計天,未驗證)會擠到 12 月下旬,01-22 把握再降 |
| **2027-01-22 交付** | 001~011 全部 Done(含人眼);012 量測**已執行一次並留原始 log**(門檻校準可在交付後);管理者試玩回答「有沒有因為營火的選擇在戰場上看到差別、看得懂嗎」(v1.0 第 9 節體驗題) | 每晚一週吃掉第 3 階段尾端一週(排程第 4.4 節) |

## 工單一覽(依實作順序)

| # | 標題 | Type | Status | 估(估計天,未驗證) | 排程對照 |
|---|---|---|---|---|---|
| 001 | 累積記錄重建好感度池,抽成共用 | Logic | **Ready** | 1 | 新(排程未列) |
| 002 | 營火寫入口 | Logic | Blocked | 1~1.5 | F3 |
| 003 | 營火產卡 | Logic | Blocked | 1~1.5 | F4 |
| 004 | 收藏區與牌組(本輪記得) | Logic | Blocked | 1~1.5 | F6 + N8 |
| 005 | 戰鬥改從牌組洗牌 | Integration | Blocked | 1~1.5 | F7 |
| 006 | 營火接進戰役流程 | Integration | Blocked | 1~1.5 | F1 |
| 007 | 營火畫面 | UI | Blocked | 1.5~2 | F2 + N6 |
| 008 | 牌組編輯畫面①:移入移出與確認 | UI | Blocked | 1.5~2 | F8 前半 |
| 009 | 牌組編輯畫面②:卡片詳情與提示 | UI | Blocked | 1.5~2 | F8 後半 |
| 010 | 營火文案與營火卡字串入庫 | Config/Data | Blocked | 0.5~1 | F9 |
| 011 | 端到端整合測試 | Integration | Blocked | 1 | F10 |
| 012 | M8 營火策略量測(並恢復 M9) | Logic | Blocked | 1.5~2.5 | N11 |
| | **合計** | | | **約 13.5~20 估計天** | |

換算實際天(沿用排程係數 1.5~2,**未驗證**):約 **7~13 實際天**。**不含**等待專家與管理者的時間 —— 那才是本 EPIC 的主要風險(見下)。

## 風險

| 風險 | 機率 | 影響 | 對策 |
|---|---|---|---|
| 畫面規格(ux)晚交,三張畫面工單擠在年底 | 中高 | 高 | 現在就派 `ux-designer`;12-11 未交即呈報 |
| 待決項卡住:12 張裡 11 張 Blocked,解鎖要 4 位專家 + 管理者 | 高 | 高 | 一次派齊(本 EPIC「需要誰先出東西」);逐張追蹤,不等全部到齊才開工 |
| 抽「累積記錄→池」改到戰鬥畫面,弄壞既有戰鬥 | 低中 | 高 | 001 要求零行為變更 + 全套原始三行 + 敏感度證明 |
| 牌組放哪需要第三個全域靜態保管處(專案規則:再要第三個須重新裁決) | 中 | 中 | 004 待 lead-programmer;若需要,轉管理者裁決 |
| 戰鬥改從牌組洗牌,既有讀各關牌表的測試大量要改 | 中 | 中 | 005 實作者先量受影響測試數再估 |
| 營火讓某種策略壓倒性(全關心/全質問) | 中 | 中 | 012 量測;門檻 +20 個百分點為初值 |
| v1.0 規格本身仍是「草稿未核准」 | — | 中 | 待協調者確認是否需要正式核准;本 EPIC 視為工作依據 |

## 待決事項(彙總)

見各工單「派工前須先決定」。管理者題在報告第一段,不重複。
