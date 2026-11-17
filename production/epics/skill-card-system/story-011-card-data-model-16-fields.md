# Story 011:卡牌資料模型擴欄(16 欄、新列舉、confirm 的 else 改 match)

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Ready(2026-11-17 三題皆已決,見「派工前須先決定」;下列為原卡點,留作紀錄)—— 原:卡在三題裁決:①F1 付款人語意(`docs/reviews/card-rework-data-format-2026-11-12.md` 第 5 節 F1)②卡 id 命名 `c01` vs `card_01`(同檔 2.7 末段)③F7 直傷是否尊重視線(同檔 F7 末段;影響是否需要某欄,見下)
> **Type**: Logic
> **Estimate**: M(1.5~2 天,粗估未驗證)
> **依據**:
> - `docs/reviews/card-rework-data-format-2026-11-12.md` 第 2.2 節(路線 A)、2.6、F3;規格 v1.0 第 4.1 節(`CostType.PAIR` 追加在列舉尾端)。
> - 現況(2026-11-17 查):`src/gameplay/cards/card.gd` 第 56 行 `const FIELD_COUNT_WITH_NAMED_MODE: int = 10`,第 216 行 `fields.size() < FIELD_COUNT or fields.size() > FIELD_COUNT_WITH_NAMED_MODE`(區間式欄數檢查)。

## 派工前須先決定

1. **F1 付款人**:新卡的 `named_unit_id` 是「付款人」還是沿用現行「承受者(ONLY)/出手者(EXCLUDE)」語意?建議(data-format 文件):新 Category 一律 `named_unit_id` = 付款人、`named_mode` 對新 Category 無作用(填 ONLY)。**設計師 + lead-programmer 裁決**;若改為獨立第 17 欄,本單欄數與 AC 全變。
   - **已決:不加第 17 欄,欄數集合維持 {8,9,10,16}。** `named_unit_id` 一律 = 付款人(凡 `cost_type ≠ NONE` 的卡),`named_mode` 對這類卡無作用(填 `ONLY`,載入器不驗)。付款人集合由 `cost_type` + 卡類別導出(**屬 015 的純函式,不在本單**):`PAIR` 且雙人加成(c09~c11)/合擊(c12)→ `named` 與 `partner` 兩人皆付;`PAIR` 且補血(c13/c14)→ 只有 `named` 付、`partner` 是承受者。(答案檔題 1;v0.3 第 3 節規則 1;設計師直接定,日後出現例外卡再升級為第 17 欄。)
2. **卡 id 命名**:`c01` 或沿用 `card_01`(game-designer)。
   - **已決:`card_11`~`card_24`**(c01 = `card_11`,依此類推 c14 = `card_24`);**不可**用 `card_01`~`card_08`(現行 `vs02_cards.txt` 已佔用,會撞 id)。`cNN` 只是閱讀簡稱。(答案檔題 2;v0.3 第 3 節規則 13。)
3. **F7 視線**:直傷是否受視線阻擋 —— 若「是」,不影響欄位,但影響 018;若直傷需要「射程下限/上限」欄(c02 董振豪射程 2~6)則本單欄位集合要多。**請設計師同時確認 c02 的射程是用現有單位射程還是卡面指定**(規格第 4 節 c02 原文本單撰寫時未重讀,**未驗證**)。
   - **已決:直傷尊重視線;c02 射程 = 施放者的單位射程(董振豪 2~6),不是卡面指定 → 不需要任何射程欄位,欄位集合不變。** 直傷卡 `target_range = -1`(不適用/用付款人攻擊射程)。(答案檔題 3;v0.3 第 3 節規則 2、7。)控制區對直傷無影響(設計師直接定,影響 018 不影響本單)。
4. (lead-programmer 自問,不需管理者)`effect_kind` 併入 `Category` 追加值的名稱:`DIRECT_DAMAGE` / `HEAL` / `COMBO_DAMAGE`(沿用 data-format 2.1)。
   - **補充(答案檔題 5、題 12)**:卡表資料**只使用 `PAIR`**、不使用 `AFFINITY`(列舉保留該值——列舉只能尾端追加,不刪既有值;載入器遇 `AFFINITY` 的處置由實作者依 AC3 決定並於回報說明)。`effect_value` 維持「由建構者/載入器傳入、不寫死」(023 本批不做,營火批再追加覆寫入口,屬追加式小改)。

## 規則

- 新欄(第 11~16 欄,順序以 data-format 2.1 為準、裁決後可調):`cost_type`(NONE/HP/AFFINITY/**PAIR**)、`cost_amount`、`effect_value`、`partner_unit_id`、`target_range`、`source`(BASE/CAMP)。
- 合法欄數**集合 {8,9,10,16}**(11~15 拒絕);舊 8~10 欄列語意 = `cost_type=NONE`、`source=BASE`、`target_range=-1`(不限)。**集合式檢查比現況區間式更嚴。**
- `CostType`、`Source` 新列舉**只能追加在尾端**;`Category` 只追加 `DIRECT_DAMAGE`/`HEAL`/`COMBO_DAMAGE`,不重排(回傳 enum 的第 0 值陷阱見 `coding-standards.md`)。
- 字串轉列舉一律 `match` + 未知回 `null`,**不得 `Enum[name]` 下標**(登記禁令 `raw_enum_name_subscript_from_untrusted_string`);**不用 `assert` 驗外部資料**(發行版被移除)。
- 新整數欄用 `String.is_valid_int()` 先驗,失敗整表拒絕(舊欄 `int("abc")==0` 的弱點**不在本單修**,獨立決定)。值域:`cost_amount ≥ 0`,`cost_type=NONE` 時必為 0;`cost_type∈{AFFINITY,PAIR}` 時 `partner_unit_id ≥ 1`。
- 工廠函式新增參數一律**帶預設值、附加尾端**(既有 83 行測試呼叫一行不動;數字出處 data-format 2.5,2026-11-12 量,會漂)。
- `CardPlaySession.confirm()` 的 `else`(把一切非丙類當甲類,F3)改成對 `Category` 的 `match`,預設分支 `push_error` + `return false`。**新值在本單還不會出現,這是防呆。**同理 `category` 其餘讀取點(data-format 稱 8 處,形狀未驗證)逐處檢查「兩類二選一」if/else 並改為帶預設錯誤分支的 `match`,**逐處列在回報**。
- `from_csv_line()` 超過 40 行標準 → 拆 `_parse_legacy_prefix()` / `_parse_cost_suffix()`。

## Acceptance Criteria

- [ ] **AC1 欄數集合**:8/9/10/16 欄合法(各 1 條);11、12、13、14、15、17 欄各被拒(各 1 條,回 `null`、`push_error`)。
- [ ] **AC2 舊列語意不變**:既有 `card_from_csv_test` 全綠且**不改斷言**;舊列解析後 `cost_type==NONE`、`source==BASE`、`target_range==-1`。
- [ ] **AC3 新列舉**:每個新列舉每個合法字串 1 條;未知字串各被拒;`cost_type=NONE` 且 `cost_amount≠0` 被拒;`AFFINITY/PAIR` 且 `partner_unit_id<1` 被拒;非整數字串於新整數欄被拒。
- [ ] **AC4 else 改 match(F3)**:用 `DIRECT_DAMAGE` 之類新 Category 的卡呼叫 `confirm()` → 回 `false`、`push_error`、**牌不被消耗、不掛修正器**(對照:修好前它會掛全 0 修正器並消耗牌)。
- [ ] **AC5 工廠預設**:既有工廠呼叫(不傳新參數)得到的 `Card` 新欄皆為預設值。
- [ ] **AC6 `.category` 讀取點盤點**:回報列出 `grep -rn "\.category\b" src --include=*.gd | grep -v "^src/gameplay/cards/card.gd"` 的原始輸出,每一行標明「已改 match / 非二選一不需改」。
- [ ] **AC7 敏感度證明**(常駐 `test_sensitivity_proof_*`,mutant 內嵌,一個 mutant 一次獨立執行):①欄數檢查回到區間式 → AC1(11~15 欄)紅 ②`Enum[name]` 下標 → AC3 未知字串紅 ③`else` 還原 → AC4 紅 ④列舉新值插在中間(重排)→ AC3 既有字串→值對應紅 ⑤`cost_type=NONE` 不檢 `cost_amount` → AC3 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 14 張卡的實際資料列與牌面文字(022)。新卡的效果結算(015~019)。`effect_value` 外部覆寫(023)。

## Affected Files

- `src/gameplay/cards/card.gd`、`src/gameplay/cards/card_play_session.gd`(僅 `confirm()` 的 else→match 與 `.category` 讀取點)
- 其餘 `.category` 讀取點所在檔(AC6 盤點後逐檔列於回報;超出先問)
- `tests/unit/gameplay/cards/card_from_csv_test.gd`(新增,不改既有斷言);新測試檔 `tests/unit/gameplay/cards/card_data_model_fields_test.gd`

## 與其他工單的順序

- 可與 010 並行;**015、017、018、019、022、023 依賴本單**。
