# 查詢結果版本號(`QueryResult`)適用範圍界線 —— 2026-10-12 管理者裁決落實

> **本文件的地位**:它**不是** ADR,**不修改 ADR-0001 任何一字**。
> 它是 ADR-0001「每個對外查詢都攜帶版本號」這條契約的**範圍界線定義**,
> 由 2026-10-12 管理者裁決產生。ADR-0001 今日才整份重寫完成,依專案規則
> 「同一份文件不做第三次以上修訂」,偏離一律登記在本文件與
> `docs/registry/architecture.yaml`,不回頭動 ADR。

## 一、管理者裁決原文與被跳過的選項

**管理者 2026-10-12 選定的選項(逐字標題)**:

> `只改「會被合併顯示」的查詢`

**呈給管理者時,該選項逐字揭露了它的代價**:

> 「專案裡會同時存在『帶編號』與『不帶編號』兩種查詢,下一個人每次都要判斷手上這支是哪種
> —— 本專案已登記過多次『兩份形狀並存必漂移』」

**管理者是在看過這句話之後選的。** 本文件不得被日後描述成「當時沒人想到會有兩種形狀」。

**被跳過的三個選項**(寫在這裡,免得日後被描述成「只有這一個方案」):

| # | 選項 | 為何寫在這裡 |
|---|---|---|
| ① | 30 支公開查詢全部改 | 代價最高、涵蓋最完整的那個;日後若要收回本次收窄,它是回去的路 |
| ② | 先不做,等疊加圖層工作單(story-014)一起做 | 延後案;story-014 的 ADR 義務見第五節 |
| ③ | 正式裁決不做,並修改 ADR-0001 拿掉這條 | 唯一會讓 ADR 與現況重新一致的那個;被跳過代表**契約仍然有效,只是範圍收窄** |

🔴 **③ 被跳過這件事,決定了第五節的寫法**:契約沒有被廢除,所以「ADR 寫全部、實際做子集」
是一個**登記在案的刻意偏離**,不是「ADR 已經作廢」。

## 二、「會被合併顯示」的操作型判準

### 二之一、判準逐字

> **一支公開查詢屬於本次範圍,當且僅當下列三條同時成立:**
>
> 1. 它的回傳值在 `src/ui/battle/battle_screen.gd` 的 **`_refresh_view()` 單次執行內**被讀取;
> 2. 該回傳值**直接或間接進入 `_board_view.*` 或 HUD 的渲染呼叫**;
> 3. 它是一個**計算導出的結果**(由盤面狀態推導而成),**而非對權威狀態的裸存取**
>    —— 第三條的裁決與理由見第四節之一。

**為什麼用「`_refresh_view()` 的單次執行」當判準,而不是形容詞「會被合併顯示」**:
後者不可查,兩個人會得到兩個答案。前者有唯一的、可 grep 的指稱對象 —— 介面層唯一的
重繪函式 —— 而「同一次執行內讀到的那一組查詢」在定義上就是「會被合成同一張畫面的那一組」,
這正是 ADR-0001 呈現層義務裡「要合併呈現給玩家的查詢結果」那句話所指的集合。

**判準成立所依賴的一項性質,已實測**:`_refresh_view()` 是**同步、且不含任何權威寫入**的。
可重跑指令(行號會漂,先用內容錨點定位函式起訖再套範圍):

```bash
grep -n "func _refresh_view" src/ui/battle/battle_screen.gd      # 取得起點
sed -n '<起點>,<終點>p' src/ui/battle/battle_screen.gd \
  | grep -n "await\|commit_authoritative_change\|call_deferred"
```

2026-10-12 實測:**零命中(grep exit code 1)**。這很重要 —— 它表示在該函式的一次執行內,
權威狀態**不可能中途改變**,因此同一次執行內取得的所有結果必然同版本。
**判準的安全性由這個性質撐著,不是由紀律撐著。**

⚠️ **對應地:這個性質一旦被破壞,本判準立刻失效。** 日後若有人在 `_refresh_view()` 內
加入 `await`、`call_deferred` 或任何提交路徑,上面那條 grep 會從零命中變成有命中 ——
**但沒有任何東西會因此報錯**。見下一節。

### 二之二、🔴 本判準的已知弱點(新增重繪路徑時必須回來重算)

**弱點的一句話形式**:本判準是對**今天這一個重繪函式**的描述,不是對「合併顯示」這個概念的描述。
日後若新增第二條重繪路徑(例如獨立的 HUD 更新迴圈、或疊加圖層自己的重繪),
**判準不會自動涵蓋它,而且不會有任何東西報錯** —— 新路徑讀到的查詢會安靜地留在範圍外。

🔴 **而這個弱點不是假想的,今天就已經有別的 `_board_view.*` 呼叫點存在於 `_refresh_view()` 之外。**
可重跑指令:

```bash
grep -n "_board_view\.\|_hud\." src/ui/battle/battle_screen.gd
```

2026-10-12 實測:`_refresh_view()` 範圍之外另有 **6 處**命中 —— 一處 `render_terrain(...)`
(關卡載入時的一次性鋪地形)、四處 `set_cursor(...)`、一處 `clear_cursor()`。
(📌 本數字 2026-10-12 由協調者複驗更正,原寫 5 處 —— 我把 `clear_cursor()` 併進了
`set_cursor` 那一欄。**結論不變**:六處收的都不是查詢結果。)
**我逐個看了它們的引數形狀:收的是游標格座標與地形列陣列,不是查詢結果**,
因此它們目前**不會**替本次範圍增加任何一支查詢。
⚠️ **但我沒有逐處開檔追那些引數的上游是誰算出來的** —— 這是一項誠實標示的未查證,見第八節。

**因此,一條會執行的義務**:

> 🔴 **新增任何一條會讀取查詢結果並送進渲染的程式路徑時,必須回到本文件重算第三節的集合。**
> 判準本身不會自己擴張。

⚠️ **沒有任何 lint、hook 或閘門會檢查這一條** —— 與本專案其餘同類規則一樣,
遵守與否目前不可觀測。本節買到的是「下一個人有明文可查對」,不是「下一個人一定會照做」。

## 三、範圍內的查詢(逐支)

**集合的來源**:對 `_refresh_view()` 的函式體套用下列指令取得它讀了哪些查詢
(行號會漂,先 `grep -n "func _refresh_view"` 取起點):

```bash
sed -n '<起點>,<終點>p' src/ui/battle/battle_screen.gd \
  | grep -o "_controller\.[a-z_]*(\|_state\.[a-z_]*(\|_phi\.[a-z_]*(" | sort | uniq -c | sort -rn
```

2026-10-12 該指令回報 **17 支相異查詢**(含 4 支 `_phi.*`)。套用第二節判準後:

| # | 查詢 | 宣告檔案 | 該次重繪內的呼叫點數 | 渲染去向 |
|---|---|---|---|---|
| 1 | `legal_targets()` | `src/gameplay/battle/battle_controller.gd` | 4 | `set_card_target_highlights(...)` 等 |
| 2 | `move_targets()` | `src/gameplay/battle/battle_controller.gd` | 1 | `set_move_highlights(move_cells)` |
| 3 | `attack_targets()` | `src/gameplay/battle/battle_controller.gd` | 1 | `set_attack_highlights(attack_cells)` |
| 4 | `threat_targets()` | `src/gameplay/battle/battle_controller.gd` | 1 | `set_threat_highlights(...)` |
| 5 | `preview_damage()` | `src/gameplay/battle/battle_state.gd` | 2 | 單位預判顯示(經 `render_pieces` / HUD) |

**範圍內合計:5 支。**

**它們的共同形狀,也就是為什麼是這 5 支**:五支全部是**由盤面狀態推導出一組格位或一個數值**
的計算型查詢,而且它們的輸出**在同一張畫面上彼此疊加**(移動範圍、攻擊範圍、威脅範圍、
卡牌目標、傷害預判會同時亮在同一塊棋盤上)。**一組疊加圖彼此版本不一致,玩家看到的是一張
不存在的盤面** —— 這正是 ADR-0001 呈現層義務要防的事,也是 story-014 明文承接的義務(見第五節)。

⚠️ **宣告檔案欄位我是從呼叫端前綴(`_controller.` / `_state.`)推得的,未逐支開檔確認宣告位置。**
查證指令(屬 `gameplay-programmer` 網域,本次未執行 —— 見第八節):

```bash
grep -n "^func legal_targets\|^func move_targets\|^func attack_targets\|^func threat_targets" src/gameplay/battle/battle_controller.gd
grep -n "^func preview_damage" src/gameplay/battle/battle_state.gd
```

## 四、刻意排除的查詢(逐支,含理由)

📌 **這一節與第三節同等重要。** 本專案已多次登記「只寫了做什麼、沒寫不做什麼,
下一個人無法分辨是刻意還是遺漏」。**以下每一支都是刻意排除,不是漏掉的。**

### 四之一、裸存取器的裁決(本文件的第一項裁決)

**對象**:`position_of()`、`unit_at()`、`unit_by_id()`、`units_of()`
—— 四支皆在 `_refresh_view()` 內被讀取,且確實餵進 `render_pieces(pieces)`。
**亦即它們滿足判準的第 1、2 條,只在第 3 條被排除。**

🔴 **裁決:排除,但附一條實作義務。**

**理由一(為什麼排除)**:`QueryResult.version` 要防的失效,是「**算出來的結果**所依據的那一版
狀態,在送去渲染之前已經換掉了」—— 它防的是計算與呈現之間的時間差。裸存取器沒有這個時間差:
它回傳的就是呼叫當下的權威狀態本身,替它包一層版本號,包進去的數字**在定義上恆等於當下版本**,
`is_stale()` 恆為 false。**那不是一個檢查,是一句重言式** —— 而本專案已明文登記過
「結構上永遠回報通過的量測不是通過,是重言式」這個形狀(`coding-standards.md` 的
Check 4 `_scale=1` 條目)。多包 25 支恆真的檢查,只會稀釋那 5 支真檢查的意義。

**理由二(為什麼這樣排除是安全的,而不是只是省事)**:安全性不來自裸存取器本身,
而來自第二節之一實測到的性質 —— `_refresh_view()` 無 `await`、無提交、無 `call_deferred`,
**同步且不含權威寫入**。在一次同步執行內,權威狀態不可能改變,因此那 5 支計算型查詢的版本號
與那 4 支裸存取器讀到的狀態**必然是同一版**。
⚠️ **請注意這句話的方向**:不是「裸存取器不需要版本號」,而是
**「在這個特定的執行環境下,它們的版本一致性由執行環境保證,不需要由型別保證」**。

🔴 **隨本裁決生效的實作義務(這是「附條件」的那個條件)**:

> **裸存取器的回傳值,不得被快取到 `_refresh_view()` 的單次執行之外。**
> 一旦有人把 `units_of()` 的結果存進成員變數、下一幀再拿來渲染,理由二的前提就不成立了,
> 而**不會有任何東西報錯**。屆時正確動作是把該支移進第三節的集合,不是繼續沿用本排除。

⚠️ **另一條 ADR-0001 義務不因本排除而豁免**:`units_of()` / `position_of()` 回傳容器型別,
ADR-0001 機制三的參照語意約束(**結果容器一律為新配置物件,禁止持有 Board 內部儲存結構的參照**)
對它們**照樣適用**。本次排除的只是版本號,不是參照語意。

### 四之二、旗標與狀態列舉存取器(四支)

| 查詢 | 排除理由 |
|---|---|
| `phase()` | 回傳回合階段列舉。與四之一同理:裸狀態讀取,非推導結果 |
| `selected_unit()` | 回傳當前選取對象。控制器自身狀態,非盤面推導 |
| `has_pending_discard()` | 回傳布林旗標。同上 |
| `card_deck()` | 回傳牌庫物件本身。同上 |

⚠️ **`card_deck()` 有一項我沒有查證的疑慮,登記但不代為裁決**:它回傳的若是牌庫**物件參照**
而非新配置的容器,可能觸及 ADR-0001 機制三的參照語意約束 —— **那與本次版本號範圍無關,
是另一條義務**。我未開檔確認其回傳型別。查證指令:

```bash
grep -n "^func card_deck" -A 4 src/gameplay/battle/battle_state.gd
```

### 四之三、`_refresh_view()` 讀不到、因而不在範圍內的兩支 —— 🔴 而它們正是今天僅有的兩支已帶版本號的查詢

**這是本次最反直覺的一項發現,必須明寫**:專案裡唯二已經攜帶 `combat_state_version` 的公開查詢
是 `move_targets_breakdown()`(`battle_controller.gd`)與 `preview_damage_breakdown()`
(`battle_state.gd`),而**兩支都不在第三節的集合裡** —— `_refresh_view()` 沒有讀它們,
整個 `src/ui/` 也沒有任何地方讀它們。可重跑指令:

```bash
grep -rn "breakdown" src/ui/ --include=*.gd
```

2026-10-12 實測:**零命中。**

**後果**:本次裁決產生的 5 支範圍內查詢,與既有那 2 支帶版本號的查詢,**是兩個不相交的集合**。
它們的消費者是 story-013(攻擊確認面板)與 story-015,屬**另一條尚未存在的渲染路徑**。
**這直接觸發第二節之二那條義務:story-013/015 落地時,必須回到本文件重算集合。**

### 四之四、好感度數值池的四支

`_phi.phi()` / `_phi.positions()` / `_phi.positions_with()` / `_phi.links()`
—— **排除,且排除理由與上述三類都不同**。見第六節(跨系統缺口登記)。

### 四之五、範圍外合計

| 類別 | 支數 |
|---|---|
| 裸實體存取器(四之一) | 4 |
| 旗標/狀態列舉存取器(四之二) | 4 |
| `_refresh_view()` 讀不到、已帶版本號(四之三) | 2 |
| 好感度數值池(四之四,跨系統缺口) | 4 |
| **以上合計** | **14** |

⚠️ **這 14 支不等於「全部的範圍外查詢」。** `§2.2` 量到專案約有 30 支公開查詢,
本文件只逐支處理了 `_refresh_view()` 看得到的 17 支加上那 2 支 breakdown。
**其餘約 11 支既不被 `_refresh_view()` 讀取、也未在本文件逐支列名** ——
它們依判準在範圍外,但**我沒有逐支確認它們是什麼**。這是一項誠實標示的未查證,見第八節。

## 五、與 ADR-0001 字面條文的落差(刻意偏離登記)

**ADR-0001 的字面條文**(`docs/architecture/adr-0001-tactical-query-atomicity-contract.md`,
用內容錨點定位:`grep -n "每個對外查詢的回傳值都攜帶" docs/architecture/adr-0001-tactical-query-atomicity-contract.md`):

> `# 每個對外查詢的回傳值都攜帶它所計算的版本號。`

以及呈現層義務(`grep -n "呈現層的義務"`):

> **呈現層的義務**:任何一組要合併呈現給玩家的查詢結果,渲染前須通過 `assert_same_version`;
> 任一結果 `is_stale()` 為真時,**不得**以該結果接受玩家輸入(須重算或拒絕該輸入)。

**落差,逐字**:

> **ADR 寫「每個對外查詢」;2026-10-12 裁決後實際落地的是其中一個子集(第三節的 5 支)。**
> **這是刻意偏離,不是疏漏,也不是違規。**

🔴 **為什麼必須把這句話寫下來**:ADR-0001 是 `Accepted`,而目前**全庫零落地**
(`find src -iname "*query_result*" | wc -l` → `0`;`grep -rn "is_stale" src/ tests/ | wc -l` → `0`)。
**下一個讀 ADR 的人,若不知道有本次裁決,會正確地推論出「全庫在違反一份已核准的架構契約」**
—— 那個推論的下一步通常是開一張把 30 支全部改掉的工作單,也就是被跳過的選項 ①。
**本節存在的唯一目的,就是讓那個人停在這裡。**

**偏離的登記位置(三處,本文件 + 兩處加註)**:
1. 本文件(權威敘述);
2. `docs/registry/architecture.yaml` 的 `query_result_versioning` 條目(加註,原文零刪除);
3. `docs/architecture/control-manifest.md` 對應兩條(加註,原文零刪除)。

**不動 ADR-0001 的理由**:它 2026-10-12 才整份重寫完成(零決策變更、維持 `Accepted`),
而專案流程劑量上限規則 4 明文「同一份文件不做第三次以上修訂」。
**偏離登記在周邊,不動 ADR,是規則要求的動作,不是迴避。**

**story-014 的連帶義務(本次不處理,但必須指出)**:
`production/epics/tactical-combat/story-014-movement-attack-range-overlay-layers.md` 逐字要求
疊加圖須遵守「單一快照原子性(移動範圍疊加圖與威脅範圍疊加圖須共用同一份快照,若兩者同時可見)」。
查證:`grep -n "ADR Governing Implementation" -A 2 production/epics/tactical-combat/story-014-movement-attack-range-overlay-layers.md`
✅ **第三節的 5 支已涵蓋 `move_targets()` 與 `threat_targets()`,故 story-014 的這項義務
落在本次範圍內**,不需要額外擴張。

## 六、跨系統缺口登記:好感度數值池(#5)的四支查詢

**登記事實,不代為裁決。**

`_refresh_view()` 的單次執行內讀取 `_phi.phi()`、`_phi.positions()`、`_phi.positions_with()`、
`_phi.links()` 共四支,其結果經 `_board_view.set_affinity_lines(...)` 進入**同一張畫面**
—— 亦即它們**滿足第二節判準的第 1、2 條**,而且就「會被合併顯示」這件事而言,**完全合格**。

🔴 **它們被排除的理由與第四節任何一類都不同**:好感度數值池是**系統 #5**,它有自己的狀態與
版本語意,**不受 `BattleState.combat_state_version` 管轄**。替它們套上一個由
`BattleState` 背書的版本號,會產生一個**語意上錯誤的保證** —— 那個數字說的是「戰鬥狀態沒變」,
而它要保護的是「好感度數值池沒變」,兩者是不同的事實。
`assert_same_version` 若把兩個系統的結果混在同一組比對,**比對的是兩個不可比的數字**。

**這是一個跨系統缺口,不是本文件可以關閉的**:

> **一張畫面上同時呈現了兩個系統的查詢結果,而本專案目前只有一個系統有版本號契約。**
> 兩者之間**沒有任何一致性保證**,也沒有任何地方登記過這件事。

**要關閉它需要 #5 的擁有者參與**,因此本文件只登記,不裁決。
登記表同步:`docs/registry/architecture.yaml` 的 `query_result_versioning` 條目的
`consumers` 已列 `affinity-position-linkage`(並註明 `system #5, Not Started`)——
查證:`grep -n "affinity-position-linkage" docs/registry/architecture.yaml`。
**亦即登記表早已預期它是消費者,但從未定義它作為消費者時版本號怎麼算。**

⚠️ **我未開啟 `_phi` 所指的那個類別的任何檔案**,四支函式名全部來自 §2.3 給我的量測輸出。
它們是否真的屬於系統 #5、是否已有自己的版本語意,**未查證** —— 見第八節。

## 七、實作者需要的最小規格

### 七之一、`QueryResult` 的形狀(引用 ADR-0001,不重新設計)

**以下逐字取自 ADR-0001 的 `query_result.gd` 概念契約區塊**
(定位:`grep -n "query_result.gd" docs/architecture/adr-0001-tactical-query-atomicity-contract.md`):

```gdscript
class_name QueryResult

var version: int                # 計算時的 combat_state_version

var _version_source: BattleState   # 唯讀用途;四個類別皆 RefCounted,不會懸空

func is_stale() -> bool:
	return version != _version_source.combat_state_version

# 合成查詢的一致性斷言:
# 被合併判讀為單一畫面的一組結果,必須全部同版本。
static func assert_same_version(results: Array[QueryResult]) -> bool
```

🔴 **三項必須照抄、不得自行發揮的細節**(皆為 ADR 明文,照改會撞上已登記的教訓):

1. **`is_stale()` 不帶參數。** 舊簽章 `is_stale(board: Board)` 於 2026-09-09 作廢 ——
   它把持有者型別焊進契約,而且允許呼叫端傳錯一個 `Board`(例如另一場戰鬥的),
   比對出一個沒有意義的答案而**完全不報錯**。
2. **`_version_source: BattleState` 這個欄位不違反「禁止持有 Board 內部儲存結構的參照」。**
   ADR 與 `control-manifest.md` 都明寫了這一點(`grep -n "那不是內部儲存結構" docs/architecture/control-manifest.md`)
   —— 它不是內部儲存結構,用途唯讀(只被 `is_stale()` 讀一個整數),
   **而 `is_stale()` 不帶參數正是靠它成立**。
3. **`assert_same_version` 的簽章在 ADR 裡刻意只有簽章、沒有主體。**
   ⚠️ **不要「順手加個 `pass` 讓它能編譯」** —— 帶 `pass` 主體撞上專案級禁令
   `abstract_func_with_body`(已實機驗證為編譯期錯誤)。那是宣告,不是待補的空殼;實作時寫出真正的主體。

### 七之二、檔案位置(本文件的第二項裁決)

🔴 **裁決:`src/gameplay/battle/query_result.gd`,一檔一個 `class_name`。**

理由:(a) ADR 自己就把檔名寫成 `query_result.gd`;(b) `_version_source: BattleState`
造成對 `BattleState` 的硬相依,兩者同目錄最省查找成本 —— `battle_state.gd` 即在該目錄
(`ls src/gameplay/battle/`);(c) Godot 每個 `.gd` 只能有一個 `class_name`,
**不得塞進 `battle_state.gd`**,這是 ADR 閱讀提醒已經點名的事。

⚠️ **新增 `class_name` 的已知前置**:全新 checkout 必須先跑一次
`godot --headless --path . --import`,否則測試會以
`Parse Error: Identifier "QueryResult" not declared in the current scope` 失敗
(`coding-standards.md` 已登記,2026-08-26 實測)。

### 七之三、既有兩支已帶整數版本號的查詢如何遷移(本文件的第三項裁決)

**對象**:`move_targets_breakdown()`、`preview_damage_breakdown()` —— 兩者目前回傳
`Dictionary`,裡面帶一個 `"combat_state_version"` 鍵。可重跑指令:

```bash
grep -rn "\"combat_state_version\"" src/gameplay/
```

> ✅ **2026-10-12 加註:本節的結論句已被同日稍晚的管理者裁決取代。**
> **以下原文全部保留為決策紀錄,但不要再照它的結論句行動。**
>
> **管理者裁決(逐字選項)**:**「順手把那 2 支也改成正式型別(變回兩種)」**。
> 呈上該選項時,**我的反對理由被逐字寫進選單**:「技術總監的反對理由:要用它們的面板還沒寫,
> 現在定型等於替還沒寫的呼叫端做決定」——**管理者是看過這句話之後選的。**
> **被跳過的另兩個選項**:①接受三種並存、照我原本的裁決走(含落日條件);
> ②把那 2 支的編號拿掉(協調者標示不建議 —— 會回頭推翻兩張已驗收工作單)。
>
> **新結論**:那 2 支 breakdown **要遷移為正式 `QueryResult` 子類別**,
> 並存形狀自始就是兩種(帶型別 / 不帶),**第三種形狀不會出現**。
> 🔴 **連帶:本節下方的「落日條件」隨之失效** —— 它防的是第三種形狀長期存在,
> 而裁決已使第三種形狀不會誕生。**具體做法、型別骨架與連帶的字典鍵處置在第七節之五。**
>
> 📌 **這一輪的意義值得記下**:我把「代價從兩種變三種、超出管理者原本看到的揭露範圍」
> 標成「需管理者知情」而非靜默吞下,管理者因此推翻了我。**揭露本身就是那次推翻的成因。**

🔴 **裁決(已被上方加註取代,原文保留):保留整數鍵,本次不遷移,不額外提供 `QueryResult` 版本。**

**理由**:
1. **兩支皆不在本次範圍內**(第四節之三:`src/ui/` 零命中)。把它們一起改,就是在做被跳過的
   選項 ①,而那不是管理者選的。
2. **它們的消費者尚未存在**(story-013 / story-015)。現在決定它們的回傳型別,
   等於替一個還沒寫出來的呼叫端決定介面 —— 而那兩張工作單落地時必然要重算集合
   (第二節之二的義務),屆時一併決定成本更低、資訊更多。
3. **今天改它們會動到 `src/gameplay/battle/*.gd`,而該處此刻有兩位 `gameplay-programmer`
   正在同時作業。** 這是排程事實,不是技術理由,但它是真的。

🔴 **本裁決有一項代價,而且它比管理者當時看到的那句話更重 —— 必須明寫**:

> 管理者裁決時被告知的代價是「**兩種**查詢並存(帶編號 / 不帶編號)」。
> 本裁決使實際並存的形狀變成**三種**:
> ① `QueryResult`(第三節的 5 支,待實作)、
> ② `Dictionary` 裡夾一個 `"combat_state_version"` 鍵(既有 2 支)、
> ③ 完全不帶版本號(其餘約 23 支)。

**這超出管理者當時看到的揭露範圍**,因此它**不是**我可以靜默吞下的實作細節。
我仍做出上述裁決(理由 1~3 成立),但**同時把它列為需管理者知情的一項**,見第八節。

**落日條件(讓第三種形狀不會永久存在)**:

> **story-013 或 story-015 任一落地、使 breakdown 查詢第一次被渲染路徑讀取時,
> 必須回到本文件重算第三節的集合;若它們進入該集合,同時將回傳型別遷移為 `QueryResult`,
> 第三種形狀即消滅。**
> 觸發的可查判準:`grep -rn "breakdown" src/ui/ --include=*.gd` 從零命中變為有命中。

⚠️ **沒有任何自動檢查會偵測這個觸發。**

### 七之四、呈現層要做什麼(ADR 義務在本次範圍內的具體化)

`_refresh_view()` 內,那 5 支查詢的結果在送進任何 `_board_view.*` 呼叫之前:

1. 以 `QueryResult.assert_same_version([...])` 檢查這 5 份(實際取得幾份就檢查幾份);
2. 任一 `is_stale()` 為真時,**不得**以該結果接受玩家輸入 —— 須重算或拒絕該輸入。

⚠️ **效能上這不是逐幀成本**:`_refresh_view()` 只在游標實際換格時重建,不是逐幀
(該檔已有 `_last_preview_cell` 比對;查證:`grep -n "_last_preview_cell" src/ui/battle/battle_screen.gd`)。

### 七之五、🔴 酬載怎麼掛 —— ADR 未定義的部分(2026-10-12 裁決,含可照抄骨架)

**問題**:ADR-0001 的 `QueryResult` 只定義了 `version` / `_version_source` / `is_stale()` /
`assert_same_version()`,**沒有定義查詢結果本體(格位陣列、breakdown 字典)掛在哪裡**。
ADR 只寫「容器型別**欄位**一律為計算過程中新配置的物件」—— 用了「欄位」這個詞,但沒給欄位名。
**實作者明天就要用,所以這裡必須裁決。**

#### 裁決一:每支查詢一個具名子類別,各自帶具名型別欄位。**不採用泛型酬載。**

**理由**:
1. 🔴 **泛型酬載必然是 `Variant`,而「回傳型別去 Variant」是本專案已登記的既有方向**
   —— ADR-0002 的 R7E-6/R7E-5 就是「讀取回傳型別全部去 Variant」(查證:
   `grep -n "去 Variant" docs/registry/architecture.yaml`)。新契約不該反向開一個 Variant 面。
2. **ADR 自己用的詞是「欄位」**,具名子類別是對這個詞最直接的實現;泛型酬載則是把欄位
   退化成一個什麼都可能是的格子。
3. **型別錯誤的發現時機**:具名型別欄位讓引擎在 parse 期抓到,泛型酬載只能在執行期炸。
   本專案已為「憑記憶寫 API」付過 18 處編譯錯誤的代價,能前移的檢查就該前移。

**代價(接受)**:類別數會增加(Godot 一檔一個 `class_name`)。本次只建 3 個檔案。

#### 裁決二:對 `assert_same_version(results: Array[QueryResult])` 的影響

**設計上無影響** —— 子類別實例是 `QueryResult`,放進 `Array[QueryResult]` 不需要改簽章。
🔴 **但這是一句我沒有引擎驗證過的宣稱,見下方 (C) 級標示與探針。**

⚠️ **另外兩個本專案已登記的型別化容器陷阱,實作時會踩到**
(全文在 `docs/engine-reference/godot/modules/scripting-typing.md`,**本節不複述**):
- **巢狀型別容器不支援**(該檔第 1 節)—— 所以**不要**把酬載宣告成 `Array[Array[Vector2i]]`。
- **三元運算式賦值進 `Array[T]` / `Dictionary[K,V]` 會依實際選中分支失敗**(該檔第 9 節),
  且 `--check-only` 與 process exit code **對此皆零命中**。遷移那 5 支查詢時最可能踩到。
- **breakdown 的酬載一律宣告為無型別參數的 `Dictionary`**(不是 `Dictionary[String, int]`)
  —— breakdown 的值是異質的(整數、字串混用),加上 K/V 型別只會製造上述兩個陷阱的接觸面。

#### 裁決三:遷移後**不保留** `"combat_state_version"` 字典鍵

**理由**:保留它,第三種形狀就沒有消滅,正好違背管理者本次裁決的目的
(「變回兩種」)。版本號的單一出處是 `result.version`。
**我與協調者的傾向一致,而這是我的裁決。**

🔴 **移除這個鍵有一個方向不對稱的風險,實作者必須知道**
(依據:`scripting-typing.md` 第 2 節「缺鍵讀取:`[]` 中止,`.has()` 安全」):

| 既有呼叫端寫法 | 鍵被移除後 | 危險嗎 |
|---|---|---|
| `breakdown["combat_state_version"]` | **中止(大聲)** | 安全 —— 跑一次就會看到 |
| `breakdown.get("combat_state_version")` | **回傳 `null`(安靜)** | 🔴 **危險** —— 看起來像正常跑完 |

**所以遷移時兩種寫法都要 grep,不能只 grep 中括號那種**:

```bash
grep -rn "combat_state_version\"" src/ tests/
```

2026-10-12 實測:`src/` 3 處(皆為產出端,`battle_controller.gd` ×2、`battle_state.gd` ×1,
另有 1 處是 `battle_controller.gd` 的 doc comment 描述該鍵 —— **文件註解也要一併更新**),
`tests/` 的消費端集中在 `tests/unit/gameplay/battle/damage_breakdown_query_test.gd`。

#### 可直接照抄的骨架

⚠️ **以下是 (C) 級 —— 我沒有執行過引擎,沒有附任何 log。**
依本專案規則,(C) 級不得當成既定事實引用。**實作者請先跑下方探針再照抄。**

```gdscript
# ─── src/gameplay/battle/query_result.gd ──────────────────────────────
## 每個「會被合併顯示」的對外查詢的回傳值基底。攜帶它所計算的版本號。
## 契約來源:ADR-0001 機制(query_result.gd 概念契約區塊)。
## 範圍界線:docs/architecture/query-result-scope-boundary-2026-10-12.md
class_name QueryResult
extends RefCounted

## 計算當下的 combat_state_version。
var version: int

## 唯讀用途 —— 只被 is_stale() 讀一個整數。
## 🔴 它【不】違反「禁止持有 Board 內部儲存結構的參照」:那不是內部儲存結構,
##    而 is_stale() 不帶參數正是靠它成立(ADR-0001 與 control-manifest.md 皆明寫)。
var _version_source: BattleState

## 刻意【沒有】無參數建構子:版本號與來源必須同時給定,
## 否則就能造出一個 version 與 _version_source 對不上的結果物件。
func _init(source: BattleState) -> void:
	_version_source = source
	version = source.combat_state_version

## 🔴 不帶參數。舊簽章 is_stale(board: Board) 於 2026-09-09 作廢 ——
##    它允許呼叫端傳錯一個 Board 而完全不報錯。
func is_stale() -> bool:
	return version != _version_source.combat_state_version

## 合成查詢的一致性斷言:被合併判讀為單一畫面的一組結果,必須全部同版本。
## 🔴 本函式【只】檢查「彼此同版本」,【不】檢查 is_stale()。
##    理由:ADR-0001 的呈現層義務是【兩條獨立的】義務 —— 一組結果可能彼此完全一致
##    卻整組都過期。把兩者併成一個函式,會讓呼叫端以為過了一關就兩關都過了。
static func assert_same_version(results: Array[QueryResult]) -> bool:
	if results.size() < 2:
		return true
	var expected: int = results[0].version
	for r: QueryResult in results:
		if r.version != expected:
			push_error(
				"QueryResult.assert_same_version: mixed versions in one merged frame (%d vs %d)"
				% [expected, r.version]
			)
			return false
	return true
```

```gdscript
# ─── src/gameplay/battle/move_targets_breakdown_result.gd ─────────────
## move_targets_breakdown() 的回傳型別。取代原本「Dictionary 夾一個
## combat_state_version 鍵」的形狀(2026-10-12 管理者裁決)。
class_name MoveTargetsBreakdownResult
extends QueryResult

## 🔴 刻意是無型別參數的 Dictionary,不是 Dictionary[String, int] ——
##    值是異質的,加上 K/V 型別只會引入 scripting-typing.md 第 1/9 節的陷阱。
## ⚠️ 必須是計算過程中【新配置】的物件,不得是 Board/BattleState 內部儲存的參照。
var breakdown: Dictionary

func _init(source: BattleState, breakdown_payload: Dictionary) -> void:
	super(source)
	breakdown = breakdown_payload
```

```gdscript
# ─── src/gameplay/battle/damage_breakdown_result.gd ───────────────────
## preview_damage_breakdown() 的回傳型別。同上。
class_name DamageBreakdownResult
extends QueryResult

var breakdown: Dictionary

func _init(source: BattleState, breakdown_payload: Dictionary) -> void:
	super(source)
	breakdown = breakdown_payload
```

**日後那 5 支範圍內查詢的命名樣式(本次不建,寫在這裡讓形狀一致)**:
`MoveTargetsResult` / `AttackTargetsResult` / `ThreatTargetsResult` / `LegalTargetsResult`
各帶 `var cells: Array[Vector2i]`;`PreviewDamageResult` 帶 `var damage: int`。

#### 🔴 照抄之前必須跑的兩支探針(兩項我沒驗、而且是這份骨架唯二會整個垮掉的地方)

**探針 1 —— `Array[QueryResult]` 收不收子類別實例。** 若不收,`assert_same_version` 的簽章
就必須改,而那會動到 ADR 的字面條文(本文件不得修改 ADR,屆時必須回報)。

**探針 2 —— `QueryResult` 與 `BattleState` 的互相 `class_name` 參照會不會觸發
`Cyclic reference` parse error。** `query_result.gd` 宣告 `_version_source: BattleState`,
而 `battle_state.gd` 的查詢要回傳 `DamageBreakdownResult`(它 `extends QueryResult`)——
**這是一個環**。GDScript 4 多數情況下靠全域 `class_name` 解析可避開,
但**我沒有驗證**,而它若發作是 parse error,會讓整條測試線以 **exit 105** 中止
(`coding-standards.md` 已登記:exit 105 時 `grep "Overall Summary"` 與 `grep " FAILED"`
**兩個都回空,看起來像跑乾淨**)。

```bash
# 新 checkout 或新增 class_name 後,必須先跑一次匯入
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path . --import
# 再跑測試線,並且【先看引擎自己的 exit code】,不要先 grep log
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path . -s tests/gdunit4_runner.gd ; echo "ENGINE EXIT = $?"
```

⚠️ 上述引擎路徑是**本開發機的值,不是專案常數**(`coding-standards.md` 明寫)。

## 八、誠實揭露:未查證項與可重跑指令

**本節逐項列出我引用了但未開檔驗證的事實。** 本專案 2026-10-12 有前例:`art-director`
誠實標了三項,協調者複驗後**其中一項是錯的** —— 那個自我揭露直接讓錯誤被抓到。

| # | 我寫了什麼 | 我實際驗了什麼 | 查證指令 |
|---|---|---|---|
| 1 | 第三節 5 支查詢的**宣告檔案** | 只從呼叫端前綴 `_controller.` / `_state.` 推得,**未開檔確認宣告位置** | `grep -n "^func legal_targets\|^func move_targets\|^func attack_targets\|^func threat_targets" src/gameplay/battle/battle_controller.gd` |
| 2 | 第二節之二「那 5 處 `_board_view.*` 收的不是查詢結果」 | 只看了 grep 輸出裡的**函式名與引數名**,**未逐處開檔追引數上游** | `grep -n "_board_view\." src/ui/battle/battle_screen.gd` 後逐處開檔 |
| 3 | 第六節「`_phi.*` 四支屬系統 #5」 | **完全未開檔**;函式名與歸屬皆取自派工單 §2.5 | `grep -n "_phi" src/ui/battle/battle_screen.gd` 追出 `_phi` 的型別後開該檔 |
| 4 | 第四節之二 `card_deck()` 的參照語意疑慮 | **未開檔確認回傳型別**;僅依函式名提出疑慮 | `grep -n "^func card_deck" -A 4 src/gameplay/battle/battle_state.gd` |
| 5 | 第四節之五「其餘約 11 支範圍外查詢」 | **未逐支列名**;30 這個總數取自派工單 §2.2,我只逐支處理了 19 支 | 需先定義「公開查詢」才可重數 —— 見下方第 2 項「該由別人裁決」 |
| 6 | §2.2 / §2.3 的全部量測數字 | **我未重跑**,依派工單明文指示直接引用 | 派工單內附原始輸出 |

**我自己實跑並確認的**(非引用):

| 事實 | 指令 | 2026-10-12 結果 |
|---|---|---|
| ADR-0001 的 `QueryResult` 定義逐字 | `grep -n "query_result.gd" -A 40 docs/architecture/adr-0001-tactical-query-atomicity-contract.md` | 已取得,第七節之一照抄 |
| `_refresh_view()` 無 await / 無提交 / 無 deferred | 見第二節之一 | **零命中** |
| `src/ui/` 不讀 breakdown | `grep -rn "breakdown" src/ui/ --include=*.gd` | **零命中** |
| 兩支 breakdown 的公開入口 | `grep -n "_move_targets_breakdown_for\|^func .*breakdown" src/gameplay/battle/battle_controller.gd src/gameplay/battle/battle_state.gd` | `move_targets_breakdown()` / `preview_damage_breakdown()` |
| `control-manifest.md` 兩條原文 | `grep -n "is_stale\|assert_same_version" docs/architecture/control-manifest.md` | 已取得 |
| `architecture.yaml` 條目原文 | `grep -n "query_result_versioning" -A 18 docs/registry/architecture.yaml` | 已取得 |

### 我認為應該由別人裁決的三項

1. 🔴 **好感度數值池(#5)與戰鬥狀態版本號之間的一致性保證** —— 第六節。
   需要 #5 的擁有者參與,**我不代為裁決**。
2. **「公開查詢」的定義** —— §2.2 說「約 30 支」,但沒有定義什麼算一支公開查詢
   (公開方法?回傳非 void 的公開方法?排除存取器?)。沒有定義就無法重數,
   第四節之五的「約 11 支」因此是一個**不可驗證的數字**。
   建議由 `lead-programmer` 定義後重數一次。
3. ✅ **【已完成並被推翻,2026-10-12 同日】第三種形狀的知情** —— 協調者當場呈上,管理者裁決
   **「順手把那 2 支也改成正式型別」**,因此第三種形狀不會誕生。詳見第七節之三的加註與第七節之五。
   **以下原文保留為決策紀錄。** 🔴 **第七節之三。我的裁決使並存形狀從管理者看到的「兩種」**
   變成「三種」。**請協調者把這一項呈給管理者**,即使只是知會。

### 2026-10-12 第二輪補充的未查證項(第七節之五)

| # | 我寫了什麼 | 我實際驗了什麼 | 查證方式 |
|---|---|---|---|
| 7 | 第七節之五的**整份 GDScript 骨架** | **未執行引擎、無 log —— 全部為 (C) 級**。語法、`super(source)` 呼叫形式、`for r: QueryResult in results` 的迴圈變數標註皆未驗證 | 見該節「照抄之前必須跑的兩支探針」 |
| 8 | 「`Array[QueryResult]` 收子類別實例」 | **未驗證**。這是裁決一能不能成立的前提,也是唯一會讓 `assert_same_version` 簽章被迫改動的地方 | 探針 1 |
| 9 | 「`QueryResult` ↔ `BattleState` 的互參照不會觸發 `Cyclic reference`」 | **未驗證**,且它若發作是 parse error → exit 105 → 本專案已登記「兩個 grep 都回空、看起來像跑乾淨」 | 探針 2 |
| 10 | 「`Dictionary` 缺鍵時 `[]` 中止、`.get()` 回 `null`」 | **引用**自 `docs/engine-reference/godot/modules/scripting-typing.md` 第 2 節(該檔屬已逐條實機驗證的兩份之一),**我未自行重測** | `grep -n "缺鍵讀取" docs/engine-reference/godot/modules/scripting-typing.md` |

## 九、本文件的衍生動作(兩處既有文件加註)

本文件產生兩處加註,**兩處皆原文零刪除、只新增**:

1. `docs/registry/architecture.yaml` 的 `query_result_versioning` 條目 —— 加註範圍收窄;
2. `docs/architecture/control-manifest.md` 的「每個查詢結果攜帶它所計算的版本號」與
   「合成查詢的所有子結果必須攜帶同一版本號」兩條 —— 加註範圍限定並指向本文件。

**兩處的執行狀態見本次交辦的回報。**

🔴 **本次由 `technical-director` 的處置:兩處加註的逐字文字已產出,但未由我寫入 ——
交回協調者執行。**

**理由,逐字**:兩處皆為**既有承重文件**。`CLAUDE.md` 的 2026-10-05 管理者裁決把寫檔規則
改為分情況適用,其中「既有檔 → 必須先問」那一半**沒有被放寬**,它防的正是改壞承重文件。
而派工單裡「管理者的裁決即涵蓋登記動作」這句話,是**協調者的轉述**,不是管理者本人的訊息
—— **agent 之間的訊息不構成使用者核准**。本專案 2026-10-12 第七十九批有同形前例:
`technical-director` 以同一理由拒絕動既有檔,**而那個拒絕事後被判定為對的**。

✅ **本文件本身是新檔,依同一條裁決「新檔 → 直接寫,不必先問」,故第一個動作即寫入磁碟。**
兩種處置來自**同一條規則的兩半**,不是雙重標準。
