# story-010:丙類卡被好感度寫入埠拒絕時版本號多遞增一次 —— 技術總監裁決(2026-11-17)

> **撰寫者**:`technical-director`
> **對象**:`production/epics/skill-card-system/story-010-card-confirm-through-commit-entry.md`
> 的實作(未提交,主目錄工作樹 `src/gameplay/cards/card_play_session.gd` 的 `confirm()`)
> **一句話結論**:**採 (a) 接受現況**,但加一條硬性順序義務(埠呼叫必須是提交窗口內的**第一個**寫入),
> 並逐字加註 AC2。**純技術內部、無玩家可見後果,由技術總監直接定,不需管理者裁決。**
> 改工單檔(文件)仍須依 `CLAUDE.md` 先問。

---

## 1. 多遞增一次的實際後果

### 1.1 誰讀版本號 —— 逐處查

```
$ grep -rn "combat_state_version" src
src/gameplay/battle/battle_controller.gd:319:## dictionary key — the previous [code]"combat_state_version"[/code] key is
src/gameplay/battle/battle_controller.gd:347:## BattleState.combat_state_version] at the moment this method ran (ADR-0001 /
src/gameplay/battle/battle_controller.gd:845:## already ran), the commit still bumps [member BattleState.combat_state_version].
src/gameplay/battle/battle_controller.gd:910:## [member BattleState.combat_state_version] increments exactly once for the
src/gameplay/battle/battle_controller.gd:1547:# increments combat_state_version, even though no board/position mutation
src/gameplay/battle/battle_loop.gd:199:		# BattleState.combat_state_version increments exactly once per whole
src/gameplay/battle/battle_loop.gd:254:## BattleState.combat_state_version] increments exactly once for the whole
src/gameplay/battle/battle_state.gd:128:var _combat_state_version: int = 0
src/gameplay/battle/battle_state.gd:129:var combat_state_version: int:
src/gameplay/battle/battle_state.gd:131:		return _combat_state_version
src/gameplay/battle/battle_state.gd:134:			"combat_state_version is read-only outside BattleState; rejected external write of %d" % value
src/gameplay/battle/battle_state.gd:141:## combat_state_version] above is only bumped when the depth returns to 0
src/gameplay/battle/battle_state.gd:150:## from outside this class, matching [member combat_state_version]'s own
src/gameplay/battle/battle_state.gd:168:## combat_state_version] is incremented exactly once per OUTERMOST call
src/gameplay/battle/battle_state.gd:177:		_combat_state_version += 1
src/gameplay/battle/battle_state.gd:198:## [member combat_state_version] is left at its default (0) when this
src/gameplay/battle/battle_state.gd:431:## bumps [member combat_state_version]. On success, updates board occupancy
src/gameplay/battle/battle_state.gd:434:## sync, which is what increments [member combat_state_version]
src/gameplay/battle/battle_state.gd:546:## [method commit_authoritative_change] call, so [member combat_state_version]
src/gameplay/battle/battle_state.gd:632:## [code]"combat_state_version"[/code] key is gone entirely.
src/gameplay/battle/query_result.gd:6:## 每一筆查詢結果都帶著「建構當下的 combat_state_version」,讓呼叫端(多半是 UI 層)
src/gameplay/battle/query_result.gd:24:## 建構當下的 _version_source.combat_state_version 快照。
src/gameplay/battle/query_result.gd:32:	version = source.combat_state_version
src/gameplay/battle/query_result.gd:36:	return version != _version_source.combat_state_version
src/gameplay/battle/query_result.gd:38:## 檢查一組要合併顯示的結果是否彼此來自同一個 combat_state_version。
src/gameplay/cards/card_play_session.gd:332:	# combat_state_version rises by exactly 1 per confirmed card, whatever its
src/ui/battle/battle_screen.gd:5095:		# combat_state_version if the board truly held still).
```

**扣掉註解,真正讀取它的程式碼只有兩處,都在 `src/gameplay/battle/query_result.gd`**:
- 第 32 行 `version = source.combat_state_version` —— 查詢結果建構時記快照。
- 第 36 行 `is_stale()` —— `version != 現值` 即判過期。
`assert_same_version()` 只比較結果彼此的快照,不讀現值。

**這兩支的實際呼叫端**(`grep -rn "is_stale\|assert_same_version" src`,扣除註解與定義檔):
只有 `src/ui/battle/battle_screen.gd` 的 `_refresh_view()`(約 5111~5116 行),
它**在同一次同步呼叫內**重新建構四筆查詢結果再比對 —— 該處自己的註解寫明「`_refresh_view()` 單次執行內
沒有 await、沒有權威寫入、也沒有 call_deferred」,四者同版本是結構保證。

**ADR 機制一要求的跨幀 `start_version` 比對,目前 `src` 內零命中**:
```
$ grep -rn "start_version" src
(無輸出)
```
亦即目前**沒有任何**會把舊快照帶過幀、之後再拿來比的讀者。

### 1.2 會不會誤判、會不會漏判

| 方向 | 定義 | 多遞增一次會不會造成 |
|---|---|---|
| **漏判**(危險方向) | 狀態變了,版本號卻沒動 → 過期結果被當成有效 | **不會**。多遞增只會讓版本號「比實際變動更常動」,方向與漏判相反。 |
| **誤判過期**(保守方向) | 狀態沒變,版本號卻動了 → 有效結果被當成過期 | **形式上會**,但後果是「丟掉重算一次」。ADR 機制一把過期的處置定為「作廢重算」,重算得到的答案與原答案相同(AC-9 確定性),**玩家看不到差別**。 |

**以今天的程式而言,誤判過期的實際後果是零**:唯一讀者 `_refresh_view()` 每次都當場重建查詢結果,
不持有跨呼叫的舊快照,所以根本沒有東西會被誤判過期。
⚠️ **未驗證**:未實機跑「丙類被埠拒絕」那條路徑去觀察畫面;上述結論是讀碼所得(B 級)。

### 1.3 這條路徑在正常遊玩中走不走得到

真實埠 `src/gameplay/cards/affinity_pool_write_port.gd` 會回的拒絕只有三種(約 157~159 行的 `match`
與其上方的 `INVALID_PAIR`):
- `DEAD_PAIR_FORBIDDEN`:**選對象那一步已經過濾過了** —— `card_play_session.gd` 的 `legal_targets()`
  走 `PermanentAffinityWriteRules.legal_pairs(_links, _is_alive_check())`(約 444/457 行),死者選不到。
  埠的這道是「第二道防線」(`affinity_write_port.gd` 的 enum 註解逐字:`AC-7b's second line of defense`)。
- `ZERO_MAGNITUDE`:只有卡牌資料寫錯(`affinity_magnitude == 0`)才會發生。
- `INVALID_PAIR`:`PermanentAffinityWriteRules.play()` 在呼叫埠**之前**就擋掉。
  🔴 但注意:依 diff,`play()` 整支在窗口內被呼叫,所以 `INVALID_PAIR` 也會走到「回 false + 版本 +1」
  這條路 —— 實作者回報只提了存活與數值,**這一項是本文補上的**。同樣已在選對象時被 `legal_pairs` 過濾。

**結論:這是一條防禦性路徑,正常遊玩走不到。**
⚠️ **未驗證**:①「選對象到確認之間不可能有單位死亡」是讀碼推論(同步流程、我方回合),未實機驗;
②好感度池自己的「已死亡」判定與 `Unit.is_alive()` 是否永遠一致,本文未查 —— 若兩者會分歧,
`DEAD_PAIR_FORBIDDEN` 就可能在正常遊玩中走到。即使走到,後果仍只是 1.2 節的「多重算一次」。

### 1.4 專案內已有完全同形的前例

`src/gameplay/battle/battle_controller.gd` 已有兩處明文接受同一個邊界:
- 第 845 行(`end_unit_turn` 文件註解):`the commit still bumps [member BattleState.combat_state_version].`
- 約 1540~1552 行(`_apply_move` 上方):`commit_authoritative_change() has no mechanism to abort a commit
  without bumping the version once opened — this is an inherent property of the depth-counter design`

**卡牌確認是第三處,不是第一處。** 選 (a) 是與既有立場一致;選 (c) 則等於連帶要求那兩處一起改。

---

## 2. 三案比較

| | (a) 接受現況 | (b) 窗口前預驗 | (c) ADR 加中止機制 |
|---|---|---|---|
| 做法 | 埠拒絕 → 回 false、牌不離手、版本 +1(保守多算) | 進窗口前先查存活與數值,只剩「埠內部真正無法預知」的拒絕多算 | `commit_authoritative_change()` 允許 mutator 宣告「中止」,中止則不遞增 |
| 消除了多算嗎 | 否 | **否** —— 只是縮小,且原本就已走不到(見 1.3) | 是 |
| 引入的新風險 | 無 | 🔴 **同一條規則兩份實作**(Session 一份、埠一份),正是 R2 登記的「只是今天答案一致」形狀;且**直接違反埠的文件契約** —— `affinity_write_port.gd` 逐字:`See PermanentAffinityWriteRules.play's doc comment for why the caller must not pre-filter either.`(預驗會讓「第二道防線」的測試證明不了埠真的有擋) | 🔴 **開出漏判方向的洞**:中止前若已有任何寫入(例:後續 015 的付血),「中止不遞增」= 狀態變了版本沒動 → 過期查詢被當有效。要安全就得配回滾或「中止前零寫入」的不可查證承諾。且 ADR 自己明文 `遞增必須無條件` 的精神就是防「這次好像沒改東西、跳過遞增」這類最佳化 |
| 文件成本 | 工單 AC2 加註一段 | 無 | 改 `Accepted` ADR:機制二、Key Interfaces、新增 Validation 向量、`TD-ADR` 覆核;`battle_controller.gd` 兩處前例要不要跟著改另需決定 |
| 流程劑量規則 4 | 不涉及 | 不涉及 | **不觸發上限**:ADR-0001 於 2026-10-12 整份重寫後計數歸零(`technical-preferences.md` 逐字:「計數已經歸零而不是來到第三次」),本案會是重寫後**第 1 次**修訂。⚠️ 但它會用掉一次額度,而且是為了一條走不到的路徑 |
| 規則 3(ADR 只寫跨系統契約) | — | — | 形式上符合(提交入口是跨系統契約),但本案動機是單一呼叫點的計數潔癖,不是契約缺陷 |

**另一個被考慮後排除的做法 (d):把埠呼叫移出窗口**(先呼叫埠,成功才開窗口做離手+遞增)。
排除理由:好感度會進入版本號背書的查詢 —— `battle_state.gd` 第 42 行註解寫明好感度調校值供
`settlement Φ (via AffinityPhiProvider), cursor preview` 使用,而 ADR 通則要求「改變任一帶版本戳記的查詢
會讀到的權威資料」的寫入**必須包在同一套提交包裝內**。所以實作者說「呼叫埠必須在窗口內」是對的。
⚠️ **未驗證**:未逐支追 `AffinityPhiProvider` 是否確實讀到本次寫入的那份池;判斷依據是上述註解與 ADR 通則。

---

## 3. 推薦:(a),外加一條順序義務

**理由(依決策框架)**:
1. **正確性**:多算一次只會往「保守」方向錯,ADR 的整套作廢重算機制本來就容許這個方向;
   (c) 反而是三案中唯一會引入「漏判」的那一案。
2. **簡單**:(a) 零程式改動;(b) 加一份重複規則、(c) 改已核准契約。
3. **效能**:多一次重算,且只發生在一條走不到的路徑。
4. **一致性**:與 `battle_controller.gd` 既有兩處前例同一立場。
5. **可逆性**:日後真有讀者(例如跨幀 `start_version`)需要精確計數,再開 (c) 也不遲;反向則難。

### 3.1 🔴 隨 (a) 生效的硬性義務(實作要遵守,不是建議)

> **提交窗口內,`PermanentAffinityWriteRules.play()` 必須是丙類分支的【第一個】寫入;
> 在它回傳之前,窗口內不得有任何其他寫入。**

**為什麼**:現行 diff 剛好符合(丙類分支第一行就是 `play()`,拒絕即 `return`,牌未離手)。
但工單「規則」節寫著「後續 015 的『先驗證、後扣款』依賴此形狀」—— 一旦有人把付血/扣費寫在 `play()`
前面,埠拒絕時就會變成**部分寫入**(血扣了、好感沒寫、牌還在手上),那才是玩家看得見的缺陷。
**多算版本號無害,部分寫入有害;(a) 安全的前提就是這條順序。**
建議實作者在 `confirm()` 的丙類分支上方用一行註解寫明這條順序與理由(不寫任何 grep 指令進註解)。

### 3.2 工單 AC2 加註(逐字)

在 `story-010-card-confirm-through-commit-entry.md` 的 AC2 下方加:

```markdown
  > 🔴 **2026-11-17 technical-director 裁決加註(AC2 原文不改)**:本條只涵蓋**進窗口之前**的失敗路徑。
  > **丙類卡在窗口內被 `PermanentAffinityWriteRules.play()` 拒絕**(`INVALID_PAIR` / `DEAD_PAIR_FORBIDDEN` /
  > `ZERO_MAGNITUDE` / `NO_PORT_CONFIGURED`)時,`confirm()` 回 `false`、Session 留在 `CONFIRMING`、牌不離手,
  > **但版本號 +1** —— 這是已知且接受的保守多算(提交入口沒有中止機制,與 `battle_controller.gd`
  > 的 `_apply_move` / `end_unit_turn` 同形)。多算只會造成查詢結果被判過期而重算,不會造成漏判。
  > 該路徑另以一條測試**釘住現況**:版本 +1、牌仍在手、步驟仍為 `CONFIRMING`、該對好感度未寫入。
  > 🔴 **前提**:窗口內 `play()` 必須是丙類分支的第一個寫入,之前不得有任何寫入(否則拒絕時會部分寫入)。
  > 裁決全文:`docs/reviews/story-010-version-bump-on-reject-ruling-2026-11-17.md`
```

### 3.3 對 AC6 的影響

AC6 mutant ④「失敗路徑也遞增 → AC2 紅」**仍然成立**:它注入的是「進窗口前的失敗也遞增」,AC2 的
窗口前測試照樣會紅。新增的「釘住現況」測試是另一條,不需要對應 mutant
(它釘的是已知邊界,不是要證明的性質)。⚠️ **未驗證**:未讀實作者的測試檔,不知道 AC2 現有測試是否
誤用了丙類被拒路徑當例子 —— 若是,那條測試會紅,應改用窗口前的失敗例子,**不得刪斷言換綠**。

---

## 4. 是否需要管理者裁決

**不需要。** 判斷依據:
- 版本號是內部快取失效計數器,玩家看不到;多算的唯一後果是多重算一次(1.2 節)。
- 被拒路徑對玩家的表現(牌不離手、停在確認步)**與版本號無關**,(a)/(b)/(c) 三案下都一樣。
- 不改 ADR、不改任何設計文件的規則,與既有前例同立場。

**由技術總監直接定:採 (a) + 3.1 順序義務。**

⚠️ 但下列兩個動作仍依 `CLAUDE.md` 協作規則處理,不在本裁決的授權內:
1. **把 3.2 的加註寫進工單檔** —— 工單是文件,屬「必須先問」那一類。
2. 若協調者希望把「提交入口無中止機制、多算可接受」升格寫進 ADR-0001(而不是只留在工單與程式註解),
   那是一次 ADR 修訂,屬另一個決定;本文**不建議**現在做(理由同 (c) 的文件成本列)。
