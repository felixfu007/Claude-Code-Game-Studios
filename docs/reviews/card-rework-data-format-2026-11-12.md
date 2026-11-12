# 卡牌改版:資料格式路線評估(2026-11-12)

> 作者:lead-programmer。對象:`design/quick-specs/card-rework-cost-and-pool-2026-11-12.md`(設計師草稿,未核准)。
> 範圍:只評估資料格式與結算掛點,**不寫程式、不改任何既有檔**。凡未讀到原始碼的判斷標「未驗證」。
> 數字都附指令,在專案根目錄執行即可重現(指令寫在本檔,命中數以當日 2026-11-12 為準,會漂)。

## 0. 對協調者/設計師轉述的核對

| 轉述 | 實測 | 結論 |
|---|---|---|
| 欄數上限 10、常數在第 56 行 | `grep -n "FIELD_COUNT_WITH_NAMED_MODE" src/gameplay/cards/card.gd` 命中 4 行,常數定義在第 56 行 | 相符 |
| 5 份 `vsNN_cards.txt` 逐列相同 | 逐檔 `diff -q` 與 vs01 皆「differ」,但差異只在 vs01 的長檔頭;資料列 vs02~05 各 8 列,逐列相同於 vs01 的 8 列(已逐檔印出核對) | **相符(資料列相同,檔頭不同)**,設計師寫「未驗證」可改為已驗證 |
| 「還要約 5 個新欄」 | 實際需要 **6 個**(見 2.1):設計師列的 `partner_unit_id` 等 5 欄之外,規格每張卡都有「距離 ≤N」限制,沒有欄位承載 | **不足一欄** |
| `effect_kind` 是新欄 | `Card.Category` 本來就是「效果種類」。再加一欄 `effect_kind` 會有兩個真相來源 | 建議**併入 `Category` 擴充**,不另開欄 |
| 「付款人 = `named_unit_id`」(規格 3.1) | 現行 `named_mode=ONLY` 的意思是「點名者 = **承受者**」(`card.gd` 的 `NamedMode` 註解),`EXCLUDE` 是「點名者 = 出手者,承受者是隊友」 | **語意衝突**,見第 5 節 F1 |

## 1. 現況(實際讀到的原始碼)

- `src/gameplay/cards/card.gd`(332 行):`Category` 只有 `TEMPORARY_STAT_MODIFIER`、`PERMANENT_AFFINITY_WRITE` 兩值;`from_csv_line()` 以 `fields.size() < 8 or > 10` 擋欄數(story-038,`push_error` + 回 `null`,不靠 `assert`);`cards_from_text()` 任一列失敗整表回 `null`;`category` 字串未知回 `null`(不用 enum 名稱下標,登記禁令 `raw_enum_name_subscript_from_untrusted_string`)。
- 工廠 `new_temporary_stat_modifier()` / `new_permanent_affinity_write()`:`src` 內**零**呼叫(`grep -rE "Card\.new_(temporary|permanent)" src --include=*.gd | wc -l` → 0),`tests` 內 83 行。**即新增參數必須帶預設值、附加在尾端,83 行測試呼叫就一行都不必動。**
- 載入端只有一處:`src/ui/battle/battle_screen.gd` 約第 1850 行 `Card.cards_from_text()`,路徑由 campaign sequence 該列決定(`campaign_sequence_entry.card_text_path` 同型有牌表路徑,見該檔第 1865~1871 行的解析順序 override → 序列表 → 預設常數)。所以**每關可以指向不同的牌表,資料遷移不必一次全換。**
- 牌面文字表另檔(`vsNN_card_text.txt`,2 欄,`card_text.gd` `FIELD_COUNT = 2`),id 一致性由 `tests/integration/gameplay/cards/card_table_id_consistency_test.gd` 檢查(目前只檢 vs01,`grep -n "func test_" ` 僅 1 條)。
- 打牌流程:`CardPlaySession`(451 行)只有 `confirm()` 一個寫入點。甲類走 `target.add_modifier(...)`,丙類走 `PermanentAffinityWriteRules.play(...)`,**其餘全是 `else` 分支**(見 F3)。
- `BattleController.confirm()`(約第 718~726 行)只做閘門檢查後轉呼 `session.confirm()`。

## 2. 路線比較

### 2.1 先釐清「到底缺哪些欄位」(三條路都一樣)

以規格第 4 節 14 張卡逐張核對,需要的新資訊:

| 新欄 | 為什麼 |
|---|---|
| `cost_type`(NONE/HP/AFFINITY) | 規格 3 |
| `cost_amount` | 同上 |
| `effect_value` | 直傷/補血量 |
| `partner_unit_id` | 雙人卡 c09~c14 |
| **`target_range`(新,規格未列)** | c04「≤1」、c07「≤2」、c13「≤3」、c14「≤2」,每張不同;規格 3.8「合擊距離 ≤2」只是旋鈕預設,補血距離完全沒有欄位承載 |
| `source`(BASE/CAMP) | 規格 6 預留 |

`effect_kind` 不算新欄,**建議併入 `Category`(追加 `DIRECT_DAMAGE`、`HEAL`、`COMBO_DAMAGE` 三值)**。c05~c11 沿用 `TEMPORARY_STAT_MODIFIER`(c06 的「ATK+3 且 DEF−2」現有 `delta_atk`/`delta_def` 就能表達,**不需新機制**)。**只能追加在列舉尾端**,不可重排:函式回傳 enum 的第 0 值陷阱見 `coding-standards.md`。

合計 10 + 6 = **16 欄**。

### 2.2 路線 A:擴 `card.gd`,單表單真相(推薦)

- `FIELD_COUNT_WITH_NAMED_MODE` 之後新增 `FIELD_COUNT_WITH_COST = 16`;**合法欄數集合改為 {8, 9, 10, 16}**(11~15 一律拒絕)。
  - 不採「8~16 連續區間」:現行區間式檢查讓 10→16 之間的任意欄數都合法,等於 story-038「壞資料整張表拒絕」的防呆被拉鬆;中間欄數幾乎一定是手誤(漏逗號)。**集合式檢查是比現況更嚴,不是更鬆。**
- 新列必須把前 10 欄補齊(用既有 sentinel:`0,-1,-1,0,-1,ONLY` 之類)再接 6 個新欄。舊 8/9/10 欄列繼續合法,語意 = `cost_type=NONE`、`source=BASE`、`target_range=-1`(不限)。
- 新增列舉 `CostType`、`Source`;`Category` 追加三值;`_category_from_string()` 補三條 `match`,未知字串仍回 `null`;`_cost_type_from_string()` / `_source_from_string()` 同寫法(**不得用 `Enum[name]` 下標**)。
- 規則護欄新增**載入期**驗證(整表拒絕):`cost_type=AFFINITY` 必須有合法 `partner_unit_id`(≥1);含麥子健(id 5)的配對 — 這條需要 links,載入器看不到,**不在 `card.gd` 做,留給打牌時的寫入埠拒絕**;`cost_amount` 必須 ≥ 0 且 `cost_type=NONE` 時必為 0。
- `from_csv_line()` 現約 45 行,加新欄後會超過「40 行/複雜度 10」標準 → 拆成 `_parse_legacy_prefix()` / `_parse_cost_suffix()` 兩個私有函式。

**要改的檔**:`src/gameplay/cards/card.gd`;`assets/data/cards/vs01~vs05_cards.txt`(5)+ `vs01~vs05_card_text.txt`(5,新增 14 列)+ `tutorial_cards.txt`/`tutorial_card_text.txt`(可能不動,見 2.5);測試見 2.4。`battle_screen.gd` **載入端不必改**。

### 2.3 路線 B:旁表 `vsNN_card_costs.txt` 以 id 對應

- 好處:`card.gd` 的 10 欄解析與既有 14 條相關測試一行不動。
- 壞處(實質):
  1. `Card` 實例仍必須持有這些欄位(打牌時要讀),所以 `card.gd` 照樣要加欄位 + 新列舉,只是「從旁表合併」多一個載入步驟。**省掉的只有解析測試,不是 `card.gd` 的改動。**
  2. 新卡在主表**必須先有一列合法的 category**,但 `DIRECT_DAMAGE` 等不在現有兩值內 → 主表列只好填「`TEMPORARY_STAT_MODIFIER` + 全 0」的假身分,這就是「**真的類別 + 假的資料**」的失效形狀(本專案已登記同形狀);任何只讀主表的人會把直傷卡當成零加成甲類。
  3. 又多一條 id 對應(牌面文字表已是第一條,一致性測試只檢 vs01 一份):三表 × 五關 = 15 條對應要檢。
  4. 載入端 `battle_screen.gd` 必須改(多一個路徑 + 一個失敗分類),而它已是 4000+ 行的大檔。
- **不推薦。**

### 2.4 路線 C(第三條):尾端單一「擴充欄」`key=value;key=value`

- 在第 10 欄之後只加**一欄**(第 11 欄),例 `cost=HP:5;value=12;range=1;partner=2;source=BASE`。
- 好處:欄數上限只動 +1,日後再加欄不必再動欄數。
- 壞處:這是在 CSV 裡另立一種字串迷你語言 —— 要自己寫 key 解析、未知 key、重複 key、值型別四種拒絕路徑,每一種都是新的「靜默收下壞資料」風險面,與 story-038 的「欄數即契約」精神相反(欄數不再能擋手誤)。且 `from_csv_line` 以 `,` 切欄,擴充欄值內不得含逗號,與牌面文字表標頭的警語同類陷阱。
- **不推薦**;僅當「預期還會再加 5 欄以上」才值得,規格沒有此跡象。

### 2.5 既有測試影響(實數)

指令與命中:

```
# 解析入口被哪些測試直接呼叫(檔案 / 命中數)
grep -rcE "Card\.(from_csv_line|cards_from_text)" tests --include=*.gd | grep -v ":0"
  → card_named_target_restriction_test 8 / card_table_id_consistency_test 1 / battle_screen_card_deck_wiring_test 4
    / affinity_link_no_direct_return_test 7 / card_from_csv_test 14   (合計 34 處,5 個檔)
# 工廠
grep -rE "Card\.new_(temporary|permanent)" tests --include=*.gd | wc -l   → 83
# 常數被測試引用
grep -rn "Card.FIELD_COUNT" tests src --include=*.gd | wc -l             → 0
# 讀 *_cards.txt 的測試檔
grep -rln "_cards.txt" tests --include=*.gd | wc -l                       → 9
# 寫死 card_01~card_08 id 的測試檔
grep -rln "card_0[1-8]" tests --include=*.gd | wc -l                      → 4
# src 內 .category 的讀取點(card.gd 以外)
grep -rn "\.category\b" src --include=*.gd | grep -v "^src/gameplay/cards/card.gd" | wc -l   → 8
```

| 路線 | 必須改既有測試 | 新增測試 |
|---|---|---|
| A(推薦) | **預期 0~2 檔**:`card_from_csv_test`(10 條)在欄數 8~10 的行為全不變;`wrong_field_count`(第 213~226 行)用的是 3 欄與 8+3 欄,仍會被拒。**唯一可能受影響:是否有測試把「恰 11 欄」當合法** —— `grep -n "11"`(該檔)無此用法,但其餘 4 檔**未逐條讀,標未驗證** | `card_from_csv_test` 約 +10 條(16 欄正常、11~15 欄拒絕、各新列舉未知字串拒絕、`cost_type=NONE` 必 0 等);`card_table_id_consistency_test` 擴成 5 關 |
| B | 0 | 同 A + 合併載入器測試 + 三表一致性 |
| C | 0 | 迷你語言解析測試 約 +15 條 |

**8 處 `.category` 讀取點(card.gd 以外)是真正的隱藏成本** —— 其中 `CardPlaySession.confirm()` 是 `if 丙類 … else(=甲類)`,見 F3。凡是「兩類二選一」的 if/else 都要逐處改成帶預設錯誤分支的 `match`。這 8 處是否都是 if/else 形狀:**未驗證**(只細讀了 `confirm()`、`select_target()`、`legal_targets()`)。

### 2.6 與 story-038「壞資料整張表拒絕」的共存

- 欄數:集合式(2.2)。
- 新列舉:每個新字串欄位走 `match` + 回 `null`,不 `assert`(`assert` 在發行版被整條移除,`coding-standards.md` 2026-11-11 條)。
- 值域:`cost_amount`、`effect_value`、`target_range` 解析用 `int()` 會把垃圾字串靜默轉成 0 —— **這是現行 `delta_atk` 等欄位已存在的弱點**(`int("abc") == 0`)。新欄位建議改用 `String.is_valid_int()` 先驗,失敗回 `null`;舊欄位是否一併補,屬獨立決定(**不建議混在同一張工單**)。
- 整表拒絕的 `push_error` 要帶 1-based 行號(`cards_from_text` 已有)。

### 2.7 遷移(5 份牌表 + 牌面文字)

- vs02~vs05 資料列與 vs01 相同(已驗證),vs01 另有長檔頭。**建議把欄位定義文件集中在 vs01 檔頭一份,其餘四份檔頭指向它**(現況 vs02~05 檔頭較短)。
- 遷移不必一次完成:舊 8~10 欄列繼續合法,**可先只在 vs02 放新列做試玩**,vs01(教學場)保持現狀 —— 這與規格待決 D4「舊卡去留」互相獨立。
- 退役舊 6 張甲類(若 D4 選 A):`card_text` 與 `card_table_id_consistency_test` 同步刪列;**寫死 `card_0N` 的 4 個測試檔**要改指向保留的 id 或改用內嵌字面值。
- 牌面文字表新增 14 列(c01~c14 id 要先定命名規則,舊的是 `card_01`,規格用 `c01` —— 兩者不同,**請設計師指定一種**,混用會讓一致性測試的 id 集合比對在視覺上難讀)。

## 3. 推薦與工作量

**推薦路線 A**(擴 `card.gd`、16 欄、合法欄數集合 {8,9,10,16}、`Category` 追加三值、不另開 `effect_kind` 欄)。

理由:
1. 單表單真相,沒有 B 的「假 category」問題;
2. 比現況**更嚴**的欄數驗證,story-038 的防呆不退化;
3. 尾端預設值的工廠簽章 → 83 行測試呼叫與 8 份舊卡表都不動;
4. 規格的 `target_range` 缺口在這個格式裡只是多一欄,不是多一種機制。

**但「改資料格式」只是整件事的約 15%**。真正的工作在戰鬥結算(第 5 節 F2、F4~F6),下面工單表已含。

## 4. 建議工單切法(先後順序;每張都可單獨編譯、全套綠)

估天數為**粗估、未驗證**(依本專案同類 story 的規模類比,無實測基礎),以「專家一輪連續工作日」計。

| # | 工單 | 內容 | 估 | 依賴 | 可獨立綠? |
|---|---|---|---|---|---|
| S0 | **補 ADR-0001 路徑⑥**(**前置,不屬改版,應先做**) | 把 `CardPlaySession.confirm()` 的寫入包進 `commit_authoritative_change()`;見 F2 | 0.5~1 | 無 | 是 |
| S1 | 資料模型 + 解析 | 第 2.2 節全部;新列舉、新欄位(預設值)、集合式欄數、`is_valid_int` 驗證、`.category` 8 處改 `match` 帶錯誤分支(此時新值還不會出現,只是防呆) | 1.5~2 | 無 | 是(新欄位無人讀) |
| S2 | 代價結算(付血 + 付好感度) | 驗證在先、扣款在後、效果之前同一提交;`is_card_playable()` 擴成回傳不可打原因;每場每配對付出累計器(狀態放哪見 F6);既有甲類加 `cost_type` 後即可用 | 2~3 | S0 S1 | 是 |
| S3 | 補血 + 雙目標甲類(c04 c07 c09 c10 c11 c13 c14) | `target_range` 距離過濾(**用現有距離函式,不得再寫一份曼哈頓**,F7)、補血夾限、雙人同回合都在場檢查 | 2~2.5 | S2 | 是 |
| S4 | **直傷(單人)** + 敵方目標步驟 | `CardPlaySession` 新 Step、新 `BattleState.resolve_direct_damage()`(死亡清佔位/移出行動序/勝負判定掛點,F4)、`BattleController` 訊號、棋盤選敵 UI | 3~4 | S2 | 是 |
| S5 | 合擊直傷 c12 | 雙人各一擊同一敵人、雙方射程交集 | 1~1.5 | S4 | 是 |
| S6 | 出牌 UI:代價顯示與不可打原因 | 確認面板顯示「好感度 −N(甲 × 乙)」(規格風險 2a)、手牌列灰化 + 原因;**要 `ux-designer` 先定** | 2 | S2 | 是 |
| S7 | 資料遷移 + 14 張卡 + 牌面文字 | 5 份牌表、5 份文字表、id 一致性測試擴成 5 關、舊卡退役(視 D4) | 1~1.5 | S1~S5 | 是 |
| S8 | 營火接口預留 | `source` 欄位已在 S1;此張只補「效果值外部覆寫」的載入端 seam(規格 6-5)並測;**不設計營火** | 0.5~1 | S1 | 是 |

**總計約 13.5~18.5 個工作日,9 張工單(含前置 S0)。** 若只做「改版第一批、先不接營火」則 S8 可延後,約 13~17.5 日。
風險最大兩張:S4(UI + 勝負判定 + 敵方目標選取,涉及 `battle_screen.gd`)與 S6(UX 未定)。**建議 S1~S3 完成後即可做電腦量測**(規格第 7 節的 A0/A1/A2/A3 對照組不依賴 S4 之後的 UI,但依賴 S4 的結算 —— 直傷卡沒有就量不了,**所以實際可量測點是 S5 完成後**,不是 S3)。

## 5. 規格在現有程式模型下做不到、或需要新掛點的項目

**F1 名詞語意衝突(`named_unit_id` / `named_mode`)**——規格 3.1「付款人 = 點名者」與現行 ONLY = 承受者矛盾。逐卡看:c01/c02/c04/c07/c08 的點名者是**付款人兼出手者**,但 c01/c02 的承受者是**敵人**、c04/c07 是**隊友**。現有兩種 `NamedMode` 都不是這個意思。建議:新卡一律把「付款人」放進**獨立欄**?那會是第 17 欄 —— 或規定「新 Category 的 `named_unit_id` 一律 = 付款人,`named_mode` 對新 Category 無作用(填 ONLY)」。**這是需要設計師與我共同定案的規格缺口,請在核准前裁決**,否則 S1 沒法定稿。

**F2 ADR-0001 提交入口:現行卡牌確認並未包在提交內(既有缺口,與本改版無關但會被它放大)**
- ADR-0001 的路徑表第 6 條明文:「**卡牌打出的第 4 步『確認』完成**」必須遞增 `combat_state_version`,且「遞增必須無條件,不得依卡牌類別判斷」(`docs/architecture/adr-0001-tactical-query-atomicity-contract.md` 第 184、192 行;連同 `grep -n "卡牌打出" docs/architecture/adr-0001-*.md` 可查)。
- 實測:`grep -n "commit_authoritative" src/gameplay/cards/*.gd` 去除 `##` 註解行後 **0 行**;`BattleController.confirm()` 與 `BattleScreen._apply_pending_card_confirm()` 亦無提交包裝(`grep -rn "commit_authoritative" src/ui --include=*.gd | grep -v "##"` → 0 行)。**即現行卡牌確認不走提交入口、版本號不遞增。**「是否另有別處補遞增」:**未驗證**(沒逐檔找 `combat_state_version +=`;grep 提交入口命中只在 `battle_controller`/`battle_loop`/`battle_state`)。
- 為何以前沒出事:甲類只 `add_modifier()`(不經受守衛的屬性),丙類寫好感度池。**HP 變動則不同**:`Unit.hp` 的 setter 是受守衛的,窗口外賦值會被 `push_error` 拒絕(`unit.gd` 約第 92~99 行);只有 `take_damage()` 刻意繞過守衛。付血/補血/直傷全是 HP 寫入 → **S0 必須先做**,否則補血會被守衛拒絕、付血雖不被拒卻不遞增版本,畫面傷害預覽會殘留舊值(正是 ADR-0001 Validation Criteria 6、`TR-card-001` 要防的事)。
- 提交包裝**必須是 `BattleController` 與 `BattleLoop` 共用的那一個**(ADR 明文),`CardPlaySession` 只依賴 `BattleState`,所以包裝放在 `session.confirm()` 內用 `_state.commit_authoritative_change(...)` 即可,不需新依賴。

**F3 `confirm()` 的 `else` 會把任何新類別當甲類**:`if category == PERMANENT_AFFINITY_WRITE … else: add_modifier(...)`(`card_play_session.gd` 約第 332~348 行)。新 `Category` 值 100% 會落入 else、**對目標掛一個全 0 的修正器並正常消耗那張牌** —— 不報錯、卡看起來打出去了、什麼都沒發生。S1 必須同批把它改成 `match` 帶 `push_error` + `return false` 的預設分支。**這是本改版最容易靜默壞掉的一處。**

**F4 直傷擊殺:結算鏈在 Controller,不在 Session**
- 一般攻擊的死亡處理分三段:`BattleState.resolve_attack()`(`take_damage` + 清佔位 + `_positions.erase`,自帶一次提交)→ `BattleController._apply_attack()`(`_order.remove_unit()`、發 `attack_resolved`)→ `_check_outcome_and_finish()`(勝負判定)。**這三段 Session 一個都碰不到**(它只持有 `BattleState` / `CardDeck` / 寫入埠)。
- 所以直傷需要:(a)`BattleState` 新增一個與 `resolve_attack()` 對稱、共用清佔位邏輯的方法(**不得複製貼上**,否則又是「同一規則兩份實作、今天剛好一致」);(b)`BattleController.confirm()` 在 `session.confirm()` 成功後補 `_order.remove_unit()` 與 `_check_outcome_and_finish()`;(c)新訊號(例 `card_damage_resolved`)讓棋盤視圖播擊殺。**「牌打出後戰鬥立刻結束」是新情境**,`BattleScreen._apply_pending_card_confirm()` 現在完全沒預期 `FINISHED`(未驗證它之後是否仍存取已結束的控制器狀態)。
- 直傷擊殺有無「反擊」:現行規則**未驗證**(沒讀 `combat_rules.gd` 全檔,只知傷害公式一行),設計師也標未驗證。

**F5 付血會不會讓自己陣亡**:可以做到「不會」,而且機制很簡單 —— `is_card_playable()` 擴成檢查「付款人 `hp > cost_amount`」。但須注意:
- **付血必須走受守衛的 `hp` setter、在提交窗口內**,不用 `take_damage()`:`take_damage()` 在 HP 歸 0 時會 `clear_modifiers()`,而「付血不會致死」的保證是**靠前置檢查**而不是靠結算端,所以窗口內再加一個 `assert` 型保護不可取(發行版被移除,`coding-standards.md`)—— 改用「寫入前 `push_error` + `return false`」。
- 規格 D8 若管理者選 B(可致死),需要整條死亡清理鏈(F4 的 a~c)加上「付款人死亡後效果是否仍結算」的規格,**目前規格沒寫,建議 D8 鎖定為 A 再開工**。
- 效果端也有死亡情境:**付款人與承受者不同人時**(c04 c07 c13 c14),承受者可在選目標到確認之間不在場?現行流程是同步單幀(ADR-0001 機制:結算不可重入),所以不會。`confirm()` 已有「確認時再驗」的前例(`_selected_card` 不在手牌時 `assert`,**此處本身違反「assert 不得守衛外部輸入」規則**,但守的是內部不變量,可接受;**建議新增檢查不要照抄這個 assert**)。

**F6 好感度代價的三個狀態/不可逆問題**
1. **無法回滾**:好感度池是 append-only 的 Delta Log(`AffinityPoolWritePort.append_record()`,ADR-0002)。**所以流程必須是「先全部驗證 → 付好感度 → 效果」,且付款後效果不得有任何失敗路徑**;若反過來(先效果、後付款),付款被埠拒絕(`DEAD_PAIR_FORBIDDEN` 等)就變成「白拿效果」。規格 3 的第 4 點「先驗證、後扣款」方向正確,實作時要在「驗證階段」就呼叫與寫入埠同一套的合法性判斷(**不得另寫一份配對合法性**,應重用 `PermanentAffinityWriteRules.legal_pairs()` / `is_legal_target()`)。
2. **「每場每配對付出上限 3」要一個新的每場計數器**:`Card` 是純值型別,不能放;`CardDeck` 是牌的位置簿;最自然的歸屬是 `BattleState`(每場一個、與 `CardPlaySession` 同生命週期)。**每場重置**要與「每場重置滿血」一致 —— 新戰場 = 新 `BattleState`,天然重置(未驗證 `BattleScreen` 切關時是否真的重建 `BattleState`)。
3. `PermanentAffinityWriteRules.play()` 現在吃的是 `card.affinity_magnitude`,丙類專用;**代價寫入需要「負向 m、非丙類卡」的呼叫**。直接以 `AffinityWritePort.append_record(a, b, -cost, SOURCE_COMBAT_CARD)` 呼叫,則**繞過 `play()` 內的 canon 關係線檢查**。需要把 `play()` 內的驗證抽成可重用的 `validate_pair()`(不改簽章,內部抽函式),代價寫入走同一份驗證。這是 S2 的一部分,但是**對 `permanent_affinity_write_rules.gd` 的既有檔修改**,動前需核對它的既有測試。

**F7 距離/射程規則不可再寫一份**:c04/c07/c09~c11/c13/c14 都有「距離 ≤N」、直傷有「射程」。本專案已有登記的失效模式:「同一個公式兩份實作、今天剛好一致」。曼哈頓距離現有實作在戰鬥模組與好感度模組**各一份**(`technical-preferences.md` 提及)。**新卡的距離判斷必須呼叫其中既有的一份,不得第三份。**用哪一份、是否經 `CombatRules`:**未驗證**(沒讀 `combat_rules.gd` 全檔),S3 開工前先查。
- **規格沒說的**:直傷是否受**視線**阻擋?(`BattleState.is_attack_range_blocked_by_los()` 已存在)、是否受**控制區**影響?c03/c01 說「射程內」,但一般攻擊有視線規則。**請設計師裁決:直傷是否尊重視線。**這會改變 c02(董振豪 射程 2~6)的實際價值。

**F8 雙人卡「雙方是否都要在場」**:規格 3.8 說兩名都須存活、距離 ≤2。程式面:`is_card_playable()` 目前只有「點名者存活」一條;雙人卡要加「`partner_unit_id` 存活」+ 距離。**c13/c14 的「付款人 → 承受者」是有向的**(徐培恩→藍亭萱),但好感度池配對是無向(`AffinityTypes.pair_of(a,b)`);有向只用在「誰付/誰收」,不影響寫入。

**F9 兩目標甲類(c09~c11 對「兩人」同時加 ATK)**:現行甲類的 `confirm()` 一次只對 `_selected_target_a` 掛一個 `CardModifier`。「兩人」若是自動 = 點名者 + 夥伴,**不需要再選目標**(目標由卡面決定),所以 UI 只需點確認;但目前 `legal_targets()` 對甲類的語意是「選一個承受者」,要新增「無需選目標」的路徑 —— 現行 Session 步驟機沒有「跳過 SELECTING_TARGET」。**未驗證**:`BattleScreen` 是否把「`legal_targets()` 為空」解讀為已到 CONFIRMING(`select_card()` 內的註解明說有這個慣例),這會與新路徑碰撞。

**F10 規格第 2 節宣稱「Card 解析器不碰 Φ」與「直傷無視 DEF 與 Φ」**:`CombatRules.damage()` 一個字不改是可行的(新函式),且**沒有隨機**(符合 `rng_in_combat_settlement` 禁令)。這部分沒問題;但**傷害預覽**(`preview_damage*`)對直傷卡要不要顯示、顯示在哪:規格沒寫,屬 S6/UX。

## 6. 結論(給協調者)

- **推薦路線**:A(擴 `card.gd` 至 16 欄、集合式欄數、`Category` 追加三值、併掉 `effect_kind`)。
- **工單**:9 張(S0~S8,S0 為前置補洞),總估約 **13.5~18.5 個工作日**(粗估,未驗證)。
- **開工前必須先裁決的規格缺口**:F1(付款人語意)、F7(直傷是否尊重視線)、D8(付血能否致死,建議鎖 A)、`target_range` 要新增一欄、卡 id 命名(`c01` vs `card_01`)。
- **與本改版獨立、但會被它放大的既有缺口**:F2(卡牌確認未走 ADR-0001 提交入口)— 建議立刻另立工單,不等改版。
- **最容易靜默壞掉**:F3(`confirm()` 的 `else` 把新類別當甲類)。
- **未驗證**:`.category` 其餘 7 處讀取點形狀、距離函式的既有位置、`BattleScreen` 對 `FINISHED` 的處理、反擊規則、`vs03~05` 以外的名冊(與卡無關)。
