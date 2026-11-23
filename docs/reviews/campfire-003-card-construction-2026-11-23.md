# campfire story-003 派工前第 4 題:營火產卡的建卡方式

> 作者:lead-programmer,2026-11-23。唯讀查證,未改任何既有檔、未跑引擎。
> 證據等級:全部是**讀原始碼/grep(B 級)**;沒有任何一條是引擎執行過的 (A) 級。

## 結論(一句話)

**要加正式建構入口**(`card.gd` 加一支純新增的工廠),不要在營火程式裡建卡後逐欄補。
技術上逐欄補今天不會出錯(沒有快取欄位),但它會讓「Card 不可變」只剩 023 一句散文在撐,
而且繞過 011 解析器已有的值域檢查。

## 查證

### ① `card.gd` 現有建構函式與欄位 (B)
- 兩支工廠:`new_temporary_stat_modifier(id, atk, def, duration, named_unit_id, named_mode)`、
  `new_permanent_affinity_write(...)`。**沒有 `_init`、沒有 setter、沒有任何衍生欄位**。
- 公開 `var` 共 17 個;`cost_type`、`cost_amount`、`effect_value`、`partner_unit_id`、`target_range`、`source`
  六個**沒有任何工廠參數**,現在唯一的寫入者是 `_parse_cost_suffix()`(同檔內,載入卡表時逐欄補)。
- 該函式補欄位前先驗:`cost_amount >= 0`、`cost_type == NONE` 時 `cost_amount == 0`、
  `AFFINITY/PAIR` 時 `partner_unit_id >= 1`。**外部逐欄補不會自動帶這三條檢查。**

### ② 「卡建立後不可變」的明文 (B)
- grep 範圍:`src`、`design`、`docs/architecture`、`docs/registry`、`production/epics`,
  詞 `不可變|immutable`,副檔名 md/gd/yaml。
- **唯一關於 Card 的明文是 skill-card `story-023` 第 17 行**:「`Card` 仍為不可變值型別;seam = 工廠接受 `effect_value` 與 `source` 外部值」,
  第 13 行同單另寫「`Card` 為純值型別,不可事後改」。**GDD、ADR、登記表裡沒有針對 Card 的不可變條文**
  (其餘命中都是調校旋鈕物件、ADR-0001 的戰鬥狀態、ADR-0005 的 CursorTarget,與 Card 無關)。
- 所以它是**意圖**不是被執行的規則:語言層面做不到(欄位公開),`card.gd` 自己的檔頭只說「純資料載體」。
- 另一個事實:023 本身 Deferred,且其「工廠加尾端參數」的形狀正是本題推薦的方向。

### ③ 建卡後讀快取值造成不一致的風險 (B,涵蓋範圍有限)
- `src/gameplay/cards/` 下 grep `cache|_snapshot` **零命中**(唯一的 `duplicate(` 是 `card_play_session.gd` 複製付款人陣列,與卡欄位無關)。
- `src` 下對 Card 欄位的賦值(變數名 `card`/`c`/`_card`)只出現在 `card.gd` 自己(工廠與 `_parse_cost_suffix`)。
- `tests/` 裡有 17 個檔共 68 處在建卡後直接改 `cost_type`/`partner_unit_id`/`source`/`effect_value`:
  逐欄補在本專案測試是既成慣例,且全套綠燈 —— **沒有觀察到「補欄位造成不一致」的徵象**。
- ⚠️ **未涵蓋**:我只掃了 `src/gameplay/cards/` 的快取字樣,沒有逐一檢查 UI(手牌列、牌面模板)是否在
  建卡當下複製欄位值;賦值掃描只認三個變數名,其他命名會漏。這兩處沒有證據顯示有問題,但也**不是已證無**。

## 推薦與理由

**推薦:加入口。** 理由依重要性:
1. **值域檢查**:營火卡一定是 `PAIR` + 兩個單位,漏填 `partner_unit_id`(預設 -1)不會報錯,只會在打牌時以奇怪方式失敗。
   工廠可把 `_parse_cost_suffix` 那三條檢查一次帶上(`push_error` + 回 `null`,不用 `assert`,見 coding-standards)。
2. **不可變意圖**:023 與 game-designer 都在守這個意圖;若營火批第一支產線程式碼就在 `card.gd` 外部改公開欄位,
   之後沒有人能說清楚「哪些地方可以這樣做」。
3. **成本極低**:純新增、不動既有簽章,既有 17 個測試檔不受影響。
- 取捨:要改 skill-card 的檔(`card.gd`),須先問;若不想動,逐欄補**可行**(上面 ③ 無反證),
  代價是理由 1、2 變成靠紀律。這是**較弱的選項,不是錯的選項**。

## 入口簽章草案(只列,不改)

```gdscript
## 營火產卡專用:甲類(暫時增益)、PAIR 代價、source=CAMP。回傳 null 表示參數不合法(已 push_error)。
static func new_camp_pair_card(
	p_id: String,
	p_delta_atk: int,
	p_delta_def: int,
	p_duration_rounds: int,
	p_payer_unit_id: int,      # -> named_unit_id(named_mode 設 ONLY,PAIR 下無意義)
	p_partner_unit_id: int,    # -> partner_unit_id,須 >= 1
	p_cost_amount: int,        # >= 0
	p_target_range: int,
	p_effect_value: int        # E 的快照記錄,>= 0
) -> Card
```
內部:`category = TEMPORARY_STAT_MODIFIER`、`cost_type = PAIR`、`source = CAMP`;
驗證 `cost_amount >= 0`、`partner >= 1`、`effect_value >= 0`、`payer != partner`(最後一條是我加的建議,
來源未查證,**是否要擋同人配對請 game-designer 確認**)。

## 要改的檔(只列)
- `src/gameplay/cards/card.gd`:新增上述工廠(**既有檔、skill-card 範圍,須先問**)
- 新測試 `tests/unit/gameplay/cards/card_camp_pair_factory_test.gd`(值域各一條拒絕 + 欄位全落位)
- `production/epics/campfire/story-003-campfire-card-generation.md`:`Affected Files` 與估時(估時本身我未估)
- skill-card `story-023`:建議加一行「營火工廠由 campfire story-003 提供,本單仍 Deferred」,避免兩處各做一次

## 另兩點提醒
- 本單 AC6 敏感度證明的 mutant ④(`E` 只寫 `effect_value`)與工廠簽章直接相關:工廠要同時收 `delta_*` 與 `effect_value`,
  測試要斷言兩者。
- 若選「不加入口」,需把「營火產卡是唯一允許在 `card.gd` 外補欄位的程式」寫進 story-003 的規則,否則下一個人沒有依據。
