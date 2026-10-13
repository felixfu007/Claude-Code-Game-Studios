# Story 004 協調者前置反查(2026-10-13)

> ⚠️ **本檔把「我量到的事實」與「我推論的建議」分開寫。**
> 同一天 `story-008` 的前置檔給了一個**錯的建議**並被實作者當場推翻 ——
> 它之所以只推翻建議、保留了事實,正是因為兩者分開寫。**請照樣對待本檔。**
>
> 🔴 **行號會漂**:另一位實作者正在改 `battle_screen.gd`(story-009)。
> **本檔一律用符號名定位,你也請用符號名,不要抄行號。**

## 一、🔴【事實】工作單的第一步「讀 S-009 判定它有沒有解決 P-1」—— 我已經做完了

**S-009 不會被單獨執行。** 它的檔頭逐字:
```
> **狀態**:🔴 **不單獨執行 —— 已併入卡牌介面 epic 的 U-003**(2026-09-15 管理者裁決二)
> **接手的人請改去做** production/epics/card-play-interface/story-u003-battle-screen-deck-wiring.md
```
**而 `U-003` 已於 2026-09-16 `Complete`。** 所以 P-1 的現況要看 `battle_screen.gd`,不是看 S-009。

### 實測:P-1 **部分解決**

```
$ grep -n "_affinity_pool\|AffinityPoolWritePort.new\|AffinityPhiProvider.new" src/ui/battle/battle_screen.gd | grep -v ":##"
436:var _affinity_pool: AffinityDataPool
965:	_phi = AffinityPhiProvider.new(_state, links)
977:	_affinity_pool = AffinityDataPool.new()
978:	var write_port: AffinityPoolWritePort = AffinityPoolWritePort.new(_affinity_pool)
```

| 工作單的 P-1 判準 | 實測 |
|---|---|
| 實例掛在生命週期涵蓋整場戰鬥的物件上 | ✅ **成立** —— 掛在 `BattleScreen` 節點上(`var _affinity_pool`),不是 Autoload,符合 ADR-0002 機制一 |
| 有明確方式讓 #5 側取得對它的參照 | ❌ **不成立** |

**第二項為什麼不成立**:
```
$ grep -n "^func _init" -A 3 src/gameplay/affinity/affinity_phi_provider.gd
48:func _init(state: BattleState, links: Array[AffinityLink]) -> void:
49-	_state = state
50-	_links = links
```
**`AffinityPhiProvider` 的建構子只收 `state` 與 `links`,收不到池。**
而它是 #5 的讀取側。**寫入側(`AffinityPoolWritePort`)已經接上了,讀取側沒有。**

🔴 **所以工作單四個分支裡,你要選的是第 4 個**(「部分解決,本 story 補完剩下的 ___」),
**而且工作單要求你把判定結果寫回該檔的「實作決定」小節。**

## 二、【事實】P-2 的對映規則已經有一份在生產中跑,不要重新發明

```
$ grep -n "_ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET" src/gameplay/cards/affinity_pool_write_port.gd
59:const _ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET: int = 1
```
同檔檔頭(`:24-30`)另有兩段非常重要的說明,**逐字摘錄**:
> 1. `_ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET` 與 `append_record()` 開頭。
>    **ADR-0002 全文沒有任何一句話建立這個對映,本檔是它的歸屬處。**
> 2. 序數驗證必須**先於** `AffinityTypes.pair_of()` —— 見 `append_record()` 對
>    `is_valid_character()` 的**雙重驗證**,以及對 `character_a == character_b` 的額外檢查。
>    `pair_of()` 自己的文件註解明文:「含 `a == b`,同一人不成配對」也是該函式的**未定義輸入**,
>    呼叫端必須連同序數驗證一起擋下 —— **只驗證單邊合法就放行的話,兩個相同的合法角色
>    會落入未定義行為。**

🔴 **最後那句是本 story 最容易漏的一條**:讀取側只做單向轉換(roster id → Character),
看起來不需要 `a == b` 檢查 —— **但若讀取側日後也要組配對,同一個陷阱會再發作一次。**

```
$ grep -rn "^static func is_valid_character" -A 2 src/ --include=*.gd
src/gameplay/affinity_pool/affinity_types.gd:136:static func is_valid_character(c: Character) -> bool:
137-	return Character.values().has(c)
```
⚠️ **注意路徑**:`AffinityTypes` 在 **`src/gameplay/affinity_pool/`**,
不在 `src/gameplay/affinity/`。**兩個目錄都存在、名字很像,很容易找錯。**

## 三、【建議,可推翻】本 story 的範圍建議收斂為「P-2 + 把 P-1 的判定寫回去」

🔴 **以下是協調者的推論,不是裁決。**

**理由**:把池接進 `AffinityPhiProvider` 要改它的建構子簽章**加上 `battle_screen.gd` 的呼叫點** ——
而**那正是 `story-005`(配對資料改為逐次查詢)要做的事**:它是「唯一真正改變行為的故事」,
讀取側改成查池就是它的主線。本 story 若先改簽章,等於替 005 做了一半,
而且**會在 `battle_screen.gd` 上與正在進行的 `story-009` 撞車**。

**所以建議**:
1. **做 P-2**:roster id → Character 的對映層(含驗證),**新檔**,放在 #5 這一側。
2. **把 P-1 的判定寫回工作單的「實作決定」小節**(工作單 AC 第 1 條明文要求),
   並明寫「剩下的『讓 provider 拿到池』交給 story-005」。
3. **不要動 `battle_screen.gd`,不要改 `AffinityPhiProvider` 的建構子。**

⚠️ **若你讀完工作單後認為這個收斂不對(例如 AC 第 2 條「可以被 #5 側透過建構子注入取得參照」
必須現在就成立),停下來回報,不要自己擴大範圍。**
📌 **協調者的讀法**:AC 第 2 條要的是「**可以**被注入」這個**能力**存在 ——
而 `battle_screen.gd` 已經持有 `_affinity_pool` 作為成員、也在同一個函式裡建構 provider,
**能力是成立的,只差一個參數**。但這是解讀,不是事實。

## 四、【事實】不要重新發明對映,但「抽成共用常數 vs 讀端自己複製一份」是你要決定的

工作單原文:
> **強烈建議直接複用** `affinity_pool_write_port.gd` 裡 `_ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET = 1`
> 這個既有、已在生產中驗證過的對映方式……**不要重新發明一套不同的對映規則**,
> 但**是否要把這個常數抽成兩邊共用、還是讀端獨立複製一份同樣的偏移量常數**,
> 是本 story 需要決定的實作細節。

🔴 **協調者的提醒(非裁決)**:本專案登記最多次的失效形狀就是
**「同一個規則兩份實作,只是今天答案一致」**,而黑箱比對**永遠分不出
『共用同一份』與『兩份碰巧一致』**。
**複製一份偏移量常數 = 主動製造第二份。** 但抽成共用會讓讀端依賴寫入端的檔案 ——
**兩邊各有代價,請明寫你選了哪個、為什麼。**
📌 今天 `story-007` 剛落地一條守衛測試,就是在守「曼哈頓距離恰好兩份」這種結構性質 ——
**若你選擇複製,考慮順手為這個偏移量加一條同形的守衛。**
