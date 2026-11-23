# Story 003:營火產卡 —— 合作卡/競爭卡,強度快照

> **Epic**: `production/epics/campfire/EPIC.md`
> **Status**: Done(2026-11-23 `2635b74`;協調者全套 2666 綠)
> (2026-11-23 收工前狀態:Ready(2026-11-23:001 `8dfb48c`、002 `1b81e67` 已提交;第 4 題管理者裁決「加專用入口，並更新工單（推薦）」))
> (原狀態:Blocked —— 依賴 **story-001、002**(皆未 Done)。管理者題已解除(skill-card story-023 的接口**併入本單**);`game-designer` 已答付款人與模板。**派工前另須 `lead-programmer` 答一小題**(見下第 4 題),不影響其他工單。)
> (原狀態:Blocked —— 卡在 ①**管理者**:skill-card story-023(卡牌數值外部改寫口)於 11-17 裁決暫緩,營火卡強度要用它,需解除暫緩(或同意把那部分併入本單);②`game-designer`:營火卡由誰付款、合作/競爭卡的效果模板。)
> **Type**: Logic
> **Estimate**: M(1~1.5 估計天,粗估未驗證;**含**原 023 範圍中營火用得到的那一部分 —— 若第 4 題的答案是「要在 `card.gd` 加正式入口」,估時重算)
> **依據**:v1.0 規格 4.4、4.5、5.2、4.1;v0.3 第 6 節第 2、4、5 點;管理者 2026-11-20 裁決第 0 題「併進營火產卡工單(推薦)」(`docs/reviews/campfire-rulings-2026-11-20.md`;skill-card story-023 **維持 Deferred**);`game-designer` 題 2、題 3(`docs/reviews/campfire-rules-gd-2026-11-20.md`)。

## 背景(producer 2026-11-20 實查;2026-11-23 依專家回答更新)

- `card.gd` 已有 `CostType.PAIR` 與 `Source.CAMP`(grep `enum CostType`、`enum Source`)。
- 🔴 **`game-designer` 指出的縫(比「缺 023」更精確)**:暫時增益卡打出時讀的是 `delta_atk`/`delta_def`/`duration_rounds`,**不讀 `effect_value`**;`effect_value` 只被補血、直傷、連攜傷害讀。所以規格 5.2 算出的強度 `E` **必須寫進 `delta_atk`/`delta_def`**,`effect_value` 只當快照記錄與顯示(`campfire-rules-gd-2026-11-20.md` 題 3,標【已讀】)。
- 競爭卡「ATK 增 DEF 降」:現有 `TEMPORARY_STAT_MODIFIER` 一張卡可同時帶正 `delta_atk` 與負 `delta_def`(vs02 的 card_16 即是)—— **不需要新效果種類**(同上)。

## 已解除的待決(2026-11-23)

| # | 原題目 | 結論 | 出處 |
|---|---|---|---|
| 1 | 023 解除暫緩或併入 | **併入本單**;023 本身維持 Deferred | 管理者 11-20 第 0 題 |
| 2 | 付款人 | **沿用現有 `PAIR` 規則,不新寫付款邏輯**:`named_unit_id` = 玩家選的第一人、`partner_unit_id` = 第二人,`CardCostPlan.payers_of()` 讓兩人都付 | `campfire-rules-gd-2026-11-20.md` 題 2 |
| 3 | 合作/競爭卡模板 | 見下方模板表(數字皆占位) | 同上題 3 |
| — | 競爭卡是否需新效果種類 | **不需要** | 同上題 3 |

## 派工前須先決定(僅剩一題)

| # | 題目 | 誰決定 | 備註 |
|---|---|---|---|
| 4 | 產卡時能否「用 `new_temporary_stat_modifier()` 建卡再逐欄補 `cost_type`、`partner_unit_id`、`source`」(`Card` 欄位是公開 `var`、無 setter),還是要在 `card.gd` 加正式建構入口 | `lead-programmer` | game-designer 標此為「是否違反 023 想守的『Card 不可變』意圖,由 lead-programmer 決定」。若答「要加入口」→ `card.gd` 屬 skill-card 檔,列入本單範圍前須先問 |

## 模板(game-designer 推薦;數字皆占位,放資料檔、標「不得直接上線」,交 `systems-designer` 校準)

| | 合作卡(關心) | 競爭卡(質問) |
|---|---|---|
| category | `TEMPORARY_STAT_MODIFIER` | `TEMPORARY_STAT_MODIFIER` |
| 強度 E | `base + min(max_bonus, floor(max(0, v−k)/pool_step))` | `base + min(max_bonus, floor(max(0, −v−k)/pool_step))` |
| 效果 | 兩人 `delta_def = +E`、`delta_atk = 0` | 兩人 `delta_atk = +E`、`delta_def = −2`(固定) |
| duration | 2 | 2 |
| `cost_amount` / `target_range` | 1 / 2 | 1 / 2 |

`base_value`=2、`max_bonus`=4、`pool_step`=2(v1.0 5.2 初值,池值量級未驗證)。⚠️ 量級提醒(未驗證):競爭卡 E 最大 6,現有牌表增益最大 3 —— 由 012 量測,本單不調。

> ✅ **第 4 題 2026-11-23 結案**:lead-programmer 推薦在 `card.gd` 加正式工廠而非建卡後逐欄補(理由:營火卡必為 PAIR,漏填 `partner_unit_id` 不會報錯;工廠一次帶上 `_parse_cost_suffix()` 的三條檢查),管理者「加專用入口，並更新工單（推薦）」。⚠️ lead 建議的「付款人不得等於夥伴」**來源未查證** —— 實作者先查 `docs/reviews/campfire-rules-gd-2026-11-20.md`,無明文就停下回報,不要自行加規則。

## 規則摘要

- 純函式:輸入(配對、關心/質問、寫入後 `v`、`k`、模板、旋鈕)→ 回傳一張 `Card`。公式與 `k` 只能呼叫 story-001 的結果與 `AffinityTuning`,不複寫。
- `E` 寫進 `delta_def`(合作)或 `delta_atk`(競爭);`effect_value` 記錄 `E` 作為快照與顯示。
- 產卡當下固定,之後池值變動不改卡面數字。
- `cost_type = PAIR`、`source = CAMP`。代價走「折損」還是「各付血」**不在產卡時決定**(v1.0 4.1:打牌當下依關係狀態決定,已由 story-015/016 實作)。
- 確認前**不預告**會產出多強的卡,只在結果層揭曉(管理者 11-20 第 8 題「照專家推薦」;屬 007 畫面行為,本單只需確保「產卡」只在寫入確認後呼叫)。
- 旋鈕放 `assets/data/`(`.txt`)。

## Acceptance Criteria

- [ ] **AC1** 合作卡:`v ≤ k` → `E == base_value`;`v` 遠大於 → 夾在 `base_value + max_bonus`;中間值逐格符合公式(邊界值測試);`delta_def == E`、`delta_atk == 0`。
- [ ] **AC2** 競爭卡:鏡像 AC1(關係越差越強);`delta_atk == E`、`delta_def == −2`。
- [ ] **AC3** 快照:產卡後再寫池,卡的 `E`(`effect_value` 與 `delta_*`)不變。
- [ ] **AC4** 產出的卡 `cost_type == PAIR`、`source == CAMP`、`named_unit_id`/`partner_unit_id` = 所選兩人(順序同選擇順序);含麥子健的配對可產卡,且產出的卡在戰鬥中可打(v1.0 驗收 (10))。
- [ ] **AC5** 營火卡在戰鬥中:兩人關係 `NONE` → 兩人各付血;`POS`/`NEG` → 走折損(重用既有路徑,**不另寫**;以真實戰鬥場景檔載入驗證);**打出後兩人身上都掛上 `delta_*` 修正**(game-designer 標「`recipient_ids` 實際組成是兩人未逐行驗證」,本條即驗證它)。
- [ ] **AC6** 敏感度證明(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①公式漏扣 `k` → AC1 紅 ②競爭卡用 `v` 而非 `−v` → AC2 紅 ③產卡後讀即時池值 → AC3 紅 ④`E` 只寫 `effect_value`、不寫 `delta_*` → AC5 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files

- 新檔:`src/gameplay/campfire/`(產卡)、`assets/data/` 營火卡模板資料檔、`tests/unit/gameplay/campfire/`
- `src/gameplay/cards/card.gd`:**新增**營火專用工廠(草案 `new_camp_pair_card`,純新增、不動既有簽章;參數不合法 `push_error` 回 `null`,不用 `assert`)—— 管理者 2026-11-23 核准列入本單範圍。依據 `docs/reviews/campfire-003-card-construction-2026-11-23.md`。
- 新測試 `tests/unit/gameplay/cards/card_camp_pair_factory_test.gd`。

## 與其他工單的順序

- 依賴 001、002。004(新卡自動入牌組)、007(營火畫面顯示產出的卡)依賴本單。
- 牌面文字(卡名、效果句)用占位鍵即可開工;正式文字在 010。
