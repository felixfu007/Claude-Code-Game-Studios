# Story 003:營火產卡 —— 合作卡/競爭卡,強度快照

> **Epic**: `production/epics/campfire/EPIC.md`
> **Status**: Blocked —— 卡在 ①**管理者**:skill-card story-023(卡牌數值外部改寫口)於 11-17 裁決暫緩,營火卡強度要用它,需解除暫緩(或同意把那部分併入本單);②`game-designer`:營火卡由誰付款、合作/競爭卡的效果模板。
> **Type**: Logic
> **Estimate**: M(1~1.5 估計天,粗估未驗證;**不含** 023 本身)
> **依據**:v1.0 規格 4.4(先寫池、再依寫入後的 `v` 產卡、產卡當下固定、`source=CAMP`、點名限定沿用)、4.5(兩種卡都有底價)、5.2(強度公式)、4.1(營火卡一律 `cost_type=PAIR`);v0.3 第 6 節第 2、4、5 點(合作 = 兩人各得小幅 DEF/ATK 增益;競爭 = 兩人 ATK 增、DEF 降;`named_unit_id`/`partner_unit_id` 由配對決定)。

## 背景(producer 2026-11-20 實查)

- `card.gd` 已有 `CostType.PAIR` 與 `Source.CAMP`(grep `enum CostType`、`enum Source`)。
- `effect_value` 外部改寫口是 skill-card story-023,狀態 **Deferred**(該檔 Status 行:「管理者 2026-11-17:本批不做」)。營火卡的數字是產卡當下算出來的,不是牌表寫死的 —— **沒有這個口子,營火卡數字無處可放**。
- 競爭卡「ATK 增、DEF 降」能否用現有兩目標增益效果(story-017)表達:**未驗證**。

## 派工前須先決定

| # | 題目 | 誰決定 |
|---|---|---|
| 1 | 解除 skill-card story-023 的暫緩,或併入本單 | **管理者** |
| 2 | 營火卡的付款人(`named_unit_id`)是兩人中的哪一個(或兩人都付);v1.0 4.1 寫「付款人各付」 | `game-designer` |
| 3 | 合作/競爭卡模板:效果種類、`base_value`、`cost_amount`、`target_range`、持續回合 | `game-designer`(數值初值 `systems-designer`;可用占位值放資料檔) |
| 4 | 競爭卡「ATK 增 DEF 降」是否需要新效果種類 | `lead-programmer`(若要新種類 → 另開工單,估時重算) |

## 規則摘要

- 純函式:輸入(配對、關心/質問、寫入後 `v`、`k`、模板、旋鈕)→ 回傳一張 `Card`。
- 合作:`effect_value = base_value + min(max_bonus, floor(max(0, v − k) / pool_step))`;競爭:把 `v − k` 換成 `−v − k`(v1.0 5.2)。`k` 只能從 `AffinityTuning` 取。
- 產卡當下固定,之後池值變動不改卡面數字。
- `cost_type = PAIR`、`source = CAMP`。代價走「折損」還是「各付血」**不在產卡時決定**(v1.0 4.1:打牌當下依關係狀態決定,已由 story-015/016 實作)。
- 旋鈕 `pool_step`、`max_bonus`、`base_value` 放 `assets/data/`(`.txt`)。

## Acceptance Criteria

- [ ] **AC1** 合作卡:`v ≤ k` → `effect_value == base_value`;`v` 遠大於 → 夾在 `base_value + max_bonus`;中間值逐格符合公式(邊界值測試)。
- [ ] **AC2** 競爭卡:鏡像 AC1(關係越差越強)。
- [ ] **AC3** 快照:產卡後再寫池,卡的 `effect_value` 不變。
- [ ] **AC4** 產出的卡 `cost_type == PAIR`、`source == CAMP`、點名欄位對應所選兩人;含麥子健的配對可產卡,且產出的卡在戰鬥中可打(v1.0 驗收 (10))。
- [ ] **AC5** 營火卡在戰鬥中:兩人關係 `NONE` → 走各付血;`POS`/`NEG` → 走折損(重用既有 015/016 路徑,**不另寫**;以真實戰鬥場景檔載入驗證)。
- [ ] **AC6** 敏感度證明(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①公式漏扣 `k` → AC1 紅 ②競爭卡用 `v` 而非 `−v` → AC2 紅 ③產卡後讀即時池值 → AC3 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files

- 新檔:`src/gameplay/campfire/`(產卡)、`assets/data/` 營火卡模板資料檔、`tests/unit/gameplay/campfire/`
- `src/gameplay/cards/card.gd` 若需改:屬 skill-card 範圍,依 023 的 Affected Files;**本單不得自行改,超出先問**。

## 與其他工單的順序

- 依賴 001、002、skill-card story-023。004(新卡自動入牌組)、007(營火畫面顯示產出的卡)依賴本單。
- 牌面文字(卡名、效果句)用占位鍵即可開工;正式文字在 010。
