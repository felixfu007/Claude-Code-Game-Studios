# Epic:好感度數值池(Delta Log)—— 資料層

> **層**:Foundation(系統 #1)
> **權威文件**:`design/gdd/affinity-data-pool.md`(**Approved**,2026-08-10 第十二輪)
> **治理 ADR**:ADR-0002(好感度數值池資料結構與並發契約,**Accepted**,2026-08-25)
> **既有承重介面**:`src/gameplay/cards/affinity_write_port.gd`(Story 004 已提交,**不得修改其語意**)
> **狀態**:📋 未開工 —— 切片內 9 張、切片外 7 張,全部尚未建立 story 檔
> **建立日期**:2026-09-15

## 一句話目標

讓「玩家打一張丙類卡 → 好感度數值真的改變 → 讀得回來」這條路**第一次會通**,
把 `NullAffinityWritePort` 這個空殼換成接在真實 Delta Log 上的轉接器。

## 為什麼現在做(它擋著什麼)

**它是技能卡牌系統結案時唯一沒還的帳。** `production/epics/skill-card-system/EPIC.md`
的「三項必須傳下去的限制」第 1 條逐字寫著:

> 丙類端到端無法驗證 —— 好感度數值池零實作,只驗到埠 | 誰能解:#1 好感度數值池

實測(2026-09-15)仍然成立:

```
grep -rn "append_record\|AffinityDataPool\|data_pool\|AffinityTypes" src/ --include=*.gd
→ 只命中 src/gameplay/cards/(埠與空殼)與 src/ui/cursor/cursor_types.gd 的一行註解
```

⚠️ **`src/gameplay/affinity/` 的四個檔案不是本系統。** 它們(`affinity_link` /
`affinity_rules` / `affinity_phi_provider` / `affinity_line_status`)是**系統 #5
好感度—位置連鎖**的關係線極性讀取路徑,餵給 `Φ`,**沒有任何 append-only 記錄結構**。
不要把本 epic 的檔案混進那個目錄。

## 這個 epic 涵蓋什麼、不涵蓋什麼

**涵蓋:資料層。** 記錄結構、寫入路徑與七類拒絕、陣亡標記表、戰役刻度、
兩個時近性加權讀取函數、以及把丙類卡接上去的轉接器與接線。
**全部 headless 可測,不碰任何節點、不碰畫面。**

**不涵蓋:介面層。** 卡牌 UI、戰鬥選單、取消鍵重綁,**已另派 `ui-programmer` 獨立調查**,
本 epic 一律不規劃、不預留、不評論。

## 🔴 開工前必讀的五個陷阱

以下每一條都是**實測或文件明文**,不是防禦性直覺。踩到的後果全部是「不當機、不報錯、
資料悄悄錯掉」那一類。

### 陷阱一:roster id(1~5)與 enum 序數(0 起算)差 1 —— 本 epic 是它第一次被寫下來

`assets/data/units/vs01_roster.txt` 把 **id 1~5 釘死為甲乙丙丁戊**;
ADR-0002 的 `enum Character { CHARACTER_1, … }` 的 **`CHARACTER_1` 序數是 0**。

🔴 **ADR-0002 全文沒有任何一句話建立這個對映**(它寫的是「佔位識別碼,角色系統定案時
只需重新命名 enum 值」,而當時 roster 編號還不存在)。轉接器必須是明文查表或 `id - 1`,
**直接把 roster id 當序數丟進去的後果**:`5`(戊)落在合法範圍外、`1`(甲)變成乙。

**做 S-008 的人必須把這個對映寫進程式碼註解**,不要指望下一個人也推理出同一個答案。

### 陷阱二:型別化 enum 參數擋不住越界整數,也擋不住浮點截斷

ADR-0002 機制四 R7-P1 / R7-P2(2026-08-20 探針 B 實測):

- 越界 int(`-1` / `999`)**原封不動抵達函式本體,零錯誤零檢查**。
  → `INVALID_PAIR` / `INVALID_SOURCE` 是**唯一防線**,不是防禦層。
- 夾帶 `float 3.7` **不中止、靜默截斷為合法序數 3** → 記錄寫進**錯誤的配對**、回傳成功。
  ADR 自陳這是它唯一一類「寫入成功、回傳成功、資料落在錯誤位置、下游看不出異常」的失敗。

**硬性義務**:進 `AffinityTypes.pair_of()` **之前**必須先呼叫
`AffinityTypes.is_valid_character()` 驗證兩個參數 —— `pair_of()` 回傳裸 `Pair`,
**結構上沒有拒絕通道**。已登記禁令:`unvalidated_character_into_pair_of`。

### 陷阱三:來源字串大小寫不一致,而錯誤的查法會當場中止函式

埠用的是 `SOURCE_COMBAT_CARD: StringName = &"combat_card"`(**小寫**);
ADR-0002 的列舉成員名是 `COMBAT_CARD`(**大寫**)。

🔴 **絕不可寫 `AffinityTypes.Source[source]`** —— 已登記禁令
`raw_enum_name_subscript_from_untrusted_string`,動態非法字串索引**當場中止呼叫函式**
(2026-08-20 探針 C 實測)。許可形狀只有三種:`keys().has()`、`find_key()`、`values().has()`。

**本路徑最乾淨的做法是根本不做字串轉換** —— 這個埠只有一個合法來源值,直接映射成常數。

### 陷阱四:新增 `class_name` 後,本機第一次跑測試前必須先 import

S-001 一次引入 4~5 個新的 `class_name`。依 `.claude/docs/coding-standards.md`
(2026-08-26 實測,`Board` / `LineOfSight` 進庫當天兩位專家各自踩到):

```
godot --headless --path . --import      # 一次性,每個工作副本各一次
```

不做的話 runner 會以 `Parse Error: Identifier "AffinityTypes" not declared in the current scope` 失敗。
**CI 不受此限**(每次從頭 checkout,action 自己會 import)。

📌 另:`class_name` 不可與 Autoload 名稱同名(parse-time 衝突)。目前唯一的 Autoload 是
`CursorStateHost`,本 epic 的命名無碰撞。

### 陷阱五:一張 story = 至少一個獨立測試檔,不得合併

`.claude/docs/coding-standards.md` 實測:**一條真實失敗會讓同檔案後面的測試全部不執行**,
而 `Overall Summary` 的 `failures` 數的是**斷言數不是測試數**(2026-09-07 實測:
11 failures 實際只有 2 個測試 FAILED)。**不要用 summary 的數字估損害,去 grep ` FAILED`。**

🔴 **附帶一項尚未驗證、且本專案有過相反前例的事**:本 epic 的測試預計放在
`tests/unit/` 與 `tests/integration/` 既有兩層之下的新子目錄。
**`tests/gdunit4_runner.gd` 的 `FORCED_ARGS` 是否需要因此改動,本 epic 未驗證。**

> ⚠️ **不要套用「`-a` 給的是上層目錄所以子目錄自動涵蓋」這個推理 —— 本專案踩過一次。**
> 2026-09-04(Story 009,本專案第一張把測試放進 `tests/integration/` 的工作單)實測:
> runner 當時寫死只掃 `tests/unit`,新增 5 條整合測試後回報
> **386 條、1 個既有失敗、exit 100 —— 與新增之前逐字相同**,那 5 條的名字一次都沒出現。
> **測試存在、看起來全綠、實際一條都沒跑。**
>
> 此項已交由協調者驗證。**在拿到答案之前,第一張 story 跑完測試後必須核對執行條數
> 確實增加,不得只看 exit code。**

## Stories

**狀態一律為 📋 Ready 或 🔒 Blocked。本 epic 建立時零完成。**

### 切片內 —— 做完這 9 張,端到端那條路第一次會通

| # | Story | 型別 | 狀態 | 估時 | 依賴 |
|---|---|---|---|---|---|
| 001 | 型別基座:`AffinityTypes` 三列舉 + `pair_of()` + 三個序數驗證器 + 穩定名稱存取器 | Logic | 📋 Ready | S | — |
| 002 | `AffinityRecord` 五欄記錄 + `AffinityRecordList` 包裝層 | Logic | 📋 Ready | M | 001 |
| 003 | 陣亡標記表:`notify_death()` / `t_death()`(**不預填**,一律 `has()` 守衛) | Logic | 📋 Ready | S | 001 |
| 004 | 池骨架與寫入路徑:建構子預填 10 對、`append_record()` 六步驗證、七類拒絕 | Logic | 📋 Ready | M | 001, 002, 003 |
| 005 | 戰役刻度:`advance_campaign_tick()` + 標記列表 + `c_now(t_query)` | Logic | 📋 Ready | S | 004 |
| 006 | 讀取結果型別與 `t_query` 型別閘門 + 拒絕哨兵兩張表 | Logic | ✅ Complete | M | 004 |
| 007 | 公式一/二:兩個加權讀取 + 陣亡凍結預設 + `0^0:=1` + `O(n_p)` 診斷 | Logic | 📋 Ready | M | 003, 006 |
| 008 | **丙類寫入轉接器**:`AffinityWritePort` 的第一個真實實作 | Integration | 📋 Ready | M | 001, 003, 004 |
| 009 | **接線**:池的生命週期宿主 + 用真實埠取代 `NullAffinityWritePort` | Integration | 📋 Ready | M | 007, 008 |

### 切片外 —— 📋 Ready 不代表該現在做,順序由 `producer` 排

| # | Story | 型別 | 狀態 | 估時 | 依賴 |
|---|---|---|---|---|---|
| 010 | 形狀特徵外殼 + 3a/3b/3c/3d/3e + `n(p)=0` 哨兵(**無旋鈕相依**) | Logic | 📋 Ready | L | 005, 006 |
| 011 | 形狀特徵 3f/3g:`segment_profile` + `low_confidence` + `source_absence`(需 `Q` / `n_min_segment` / `M`) | Logic | 📋 Ready | M | 010 |
| 012 | 公式四:`speculative_read()` 預判/假設性讀取 | Logic | 📋 Ready | M | 007 |
| 013 | 持久化:`ImportResult` + `export_state` / `validate_semantics` / `import_state` + 5 條跨結構不變量 | Logic | 📋 Ready | L | 002, 003, 004, 005 |
| 014 | 序列化生命週期權杖的**重入語意**(begin/end、多重疊視窗) | Logic | 📋 Ready | M | 004 |
| 015 | 權杖**逾時回收**與 `TIMED_OUT_RECLAIMED` 分類 | Logic | 🔒 **Blocked** | S | 014 |
| 016 | `can_write()` 窄範圍封鎖查詢 | Logic | 📋 Ready | S | 003, 004 |

🔒 **S-015 被什麼擋住(管理者已裁決的既定前提)**:
`TOKEN_TIMEOUT_MS` 的定值責任由 ADR-0002 交給 **ADR-0004**,而 ADR-0004 仍是 `Proposed`
且 `production/milestones/one-year-plan.md:359-360` 逐字寫著「**不在最短路徑上,
維持 `Proposed` 即可,不要再投入**」。實測 `grep -rn "TOKEN_TIMEOUT_MS"` 全庫:
**只命中 `.md` 檔(ADR-0002 九處、ADR-0004 一處),`.gd` 零命中。**

📌 **但這個鎖只綁住 S-015,不綁住 S-014** —— 這是逐條讀完 AC 之後才看清楚的:
AC-60 / AC-64(權杖重入語意)**完全不需要那個常數**,今天就能建構、就能測。
管理者的裁決是「整組延後」,本 epic 遵守它;此處只是讓延後的邊界準確,
**避免下一個人以為整組都被同一個東西擋住。**

## 切片內的開工順序與可平行性

**實作由 `gameplay-programmer` 接手。判準是「會不會寫到同一個檔案」,不是依賴圖本身** ——
依賴圖允許的平行,若兩張 story 改同一個檔,實務上仍得排隊。

🔴 **`src/gameplay/affinity_pool/affinity_data_pool.gd`(暫定路徑)是本 epic 的序列化點。**
S-003 / 004 / 005 / 006 / 007 **全部往同一個檔案裡加東西**,因此它們之間**沒有真正的平行機會**,
不論依賴圖長什麼樣。

| 波次 | 可同時開工 | 為什麼 |
|---|---|---|
| **波 0** | **001 單獨** | 三個列舉是所有東西的前提。**沒有任何東西能與它平行。** |
| **波 1** | **002 ∥ 003** | ✅ **真平行** —— 002 寫 `affinity_record.gd` / `affinity_record_list.gd`,003 寫 `affinity_data_pool.gd`,**不同檔案** |
| **波 2** | **004 單獨** | 需要 002 與 003 都在;且與 003 同檔 |
| **波 3** | **008 ∥(005 → 006 排隊)** | ✅ **008 是真平行** —— 它寫 `src/gameplay/cards/` 底下的新檔,**碰不到池的檔案**,且只依賴 001/003/004。⚠️ **005 與 006 彼此不能平行**(同檔),但兩者順序可互換 |
| **波 4** | **007 單獨** | 需要 006;同檔 |
| **波 5** | **009 單獨** | 需要 007 與 008 |

**最短路徑長度 = 6 波。** 若只有一位實作者,總順序建議:
`001 → 003 → 002 → 004 → 008 → 005 → 006 → 007 → 009`
(把 008 提前到 004 之後,好處是接縫上的四道轉換——見陷阱一/二/三——會在讀取函數還沒寫完
之前就被逼著想清楚,而那是本 epic 風險最集中的地方)。

⚠️ **009 之前不會有任何「端到端」的東西可看。** 這是本 epic 的形狀決定的,不是進度落後。

## 🔴 本次推翻的一項舊結論(寫下它取代了什麼,比寫下結論本身重要)

> **2026-09-15 的實作拆解調查報告說錯了一件事,以下這段取代它。**

**那份報告寫**:讀取單元「blocked on knob ownership」—— λ_combat / λ_narrative / α
在全專案沒有任何數值(只有 GDD 的建議範圍),所以讀取函數做不了。

**逐條讀完 AC 之後,這個判斷不成立。** AC-14 逐字要求用**三組不同的
(λ_combat, λ_narrative, α) 合法參數組合**——例如 `(0.9, 0.9, 0.3)`、`(0.5, 0.99, 0.15)`、
`(1.0, 1.0, 0.39)`——呼叫**同一個** `shape_feature_read`;AC-15/16/17/18/31/32/33
也各自指定自己要用的 λ 與 α。

**亦即:這些值在設計上本來就是呼叫端/設定檔提供的參數,不是實作要去查出來的常數。**
校準值未定**不阻擋任何一張讀取 story**,它只阻擋「遊戲實際手感的調校」,而那是 playtest 階段的事。

🔴 **實作義務(由此推導)**:λ_combat / λ_narrative / α / `Q` / `n_min_segment` / `M` /
`n_gate_min` **一律為注入參數或外部設定,不得寫死成常數** ——
`.claude/docs/coding-standards.md`「Gameplay values must be data-driven」本來就要求如此,
而 AC-14 是它在本系統的可執行證據。

**為什麼要留著這一段**:本專案的頭號失效模式是舊結論留在原地沒人撤回。
上一份報告會被讀到,**若不寫明它哪一句被推翻,下一個人會照著「旋鈕沒定案所以先別做讀取」去排程。**

## 🔴 AC 對照表(逐條,不抽樣)

### ⚠️ 先把三個並存的數字講清楚:75 / 72 / 76 都是對的,它們在回答不同問題

**本專案的 `session-start` 一致性檢查每次對話開場都會報這一行**:

> `affinity-data-pool.md — AC numbering has gaps: 72 distinct numbers spanning AC-1..AC-81 (expected 81 if contiguous)`

**下一個人會看到這份 epic 寫 75、開場檢查寫 72,然後以為其中一個錯了。兩個都沒錯。**

| 數字 | 它在回答什麼 | 指令 |
|---|---|---|
| **75** | **相異 AC 條數(含 a/b 變體)** —— 本表的列數,也是本 epic 用的數 | `grep -o '^- \*\*AC-[0-9]*[ab]*' design/gdd/affinity-data-pool.md \| sort -u \| wc -l` |
| **72** | **相異數字編號**(把 `27a`/`27b` 併成 27、`59a`/`59b` 併成 59、`77`/`77b` 併成 77) | `grep -o '^- \*\*AC-[0-9]*' design/gdd/affinity-data-pool.md \| sort -u \| wc -l` |
| **76** | **定義行總數** —— 比 75 多的那 1 是 **`AC-4` 被定義了兩次**(第 385 行是 AC 本體,第 477 行是 L 節的「AC-4、AC-47、AC-61、AC-78 的 DoD 範圍釐清」條目,行首同形) | `grep -c '^- \*\*AC-' design/gdd/affinity-data-pool.md` |

**`AC-81` 是最大編號,不是條數。** `AC-65`~`AC-72` 八個編號**全檔零命中、從未存在**
(`for n in 65 66 67 68 69 70 71 72; do grep -c "AC-$n\b" design/gdd/affinity-data-pool.md; done` → 全部 0);
`AC-40` 於第四輪被移出 AC 章節、改列 Open Question(現僅存在於修訂歷史敘述中)。

📌 **這段存在的唯一目的,是讓下一個人不必重跑這次比對。要條數請當場數,不要抄本節任何數字。**

| AC | Story | 備註 |
|---|---|---|
| AC-1 | 009 | 公開介面行為窮盡檢視。**範圍限於本切片交付的介面**,新增介面時須重跑。⚠️ 它嚴格說不屬於任何單一 story,放這裡是判斷 |
| AC-2 | 004 | `c_i` 斷言需 005 已落地 |
| AC-3 | 007 | 純讀取不遞增計數器 |
| AC-4 | **本切片不涵蓋** | GDD L 節**明文排除於本系統 DoD** —— 需技能卡牌/支援對話/章節結構三者皆有程式碼 |
| AC-5 | 007 | 冷落機制:age 因他人活動增長 |
| AC-6 | 007 | `n(p)` 與 `t_now` 獨立 |
| AC-7 | 004 | 同回合兩筆取得遞增且不重複的 `t_i` |
| AC-8 | 010 | 其「戰鬥/敘事讀值為 0」半句由 007 一併驗;**見限制表第 5 條的 fail-open 警告** |
| AC-9 | 007 | λ=1 精確抵銷,`n(p)=2` |
| AC-10 | 010 | 合法零值 vs 哨兵的型別區分 —— 它是擋住「永遠回 null」作弊的控制組 |
| AC-11 | 007 | 戰鬥讀取對來源不敏感 |
| AC-12 | 007 | ≈0.664 |
| AC-13 | 007 | ≈0.712,與 AC-12 對照 |
| AC-14 | 010 | **三組不同 (λ,λ,α) 呼叫同一函數** → λ/α 必須可注入,不得寫死(見上方「本次推翻的舊結論」) |
| AC-15 | 007 | `0^0:=1` 顯式特判,**不得依賴引擎預設行為** |
| AC-16 | 007 | λ=1 線性無界成長是合法結果 |
| AC-17 | 007 | λ<1 收斂至穩態 |
| AC-18 | 007 | `k=1` 單元測試層級,GDD 自陳非真實遊戲情境 |
| AC-19 | 010 | `sign(0)` 沿用前一個非零號 |
| AC-20 | 010 | `reversal_count` 達理論上限 `n(p)−1` |
| AC-21 | 010 | 筆數與比例並列 |
| AC-22 | 010 | 「資料不足」vs「刻意不聊天」 |
| AC-23 | 010 | `span_c` / `spread_ratio` |
| AC-24 | 004 | `m=0` 被拒且不靜默糾正 |
| AC-25 | 007 | 🔴 三個排除前提缺一不可:`λ<1`、凍結基準非零、差距 > ±0.01 |
| AC-26 | 013 | 還原後 `t_now` = 記錄總筆數 |
| AC-27a | 001 | 靜態檢視 enum 恰 10 值 |
| AC-27b | 004 | 非法配對值被拒 |
| AC-28 | 004 | 非法來源標籤被拒 |
| AC-29 | 004 | `m=NaN` 被拒。**只在池的直接單元測試可構造** —— 埠的 `m: int` 造不出 NaN |
| AC-30 | 004 | 非法配對被拒(AC-27b 引用的具體驗證) |
| AC-31 | 007 | λ=0 多配對交錯 |
| AC-32 | 007 | λ_narrative=1,與 AC-16 對稱 |
| AC-33 | 007 | 敘事端 `0^0`,與 AC-15 對稱 |
| AC-34 | 007 | 歷史 `t_query` 不洩漏未來資訊 |
| AC-35 | 007 | `t_query` 早於最早記錄 |
| AC-36 | 006 | 未來 `t_query` 拒絕。閘門在 006;**010 落地後須擴及 `shape_feature_read`** |
| AC-37 | 013 | 還原後 `c_now` = 標記列表筆數 |
| AC-38 | 010 | `source_polarity` |
| AC-39 | 005 | ⚠️ 觀測 `c_now` 需 010 —— 見下方「AC 措辭與 Core Rules #3 不一致」 |
| AC-41 | 005 | ⚠️ 同上 |
| AC-42 | 010 | 淨值 0 但 `total_churn`=8 |
| AC-43 | 012 | `n(p)=0` 不產生 NaN(`t_last:=t_query`) |
| AC-44 | 012 | 預判與真實寫入等價 |
| AC-45 | 012 | 公式四無副作用 |
| AC-46 | 012 | 多筆假設性記錄須嚴格遞增 `t_new` |
| AC-47 | **本切片不涵蓋** | GDD L 節**明文排除於本系統 DoD**;且 S-014/015 在切片外 |
| AC-48 | 013 | 標記列表持久化 × 歷史重建的交集 |
| AC-49 | 011 | 救贖 vs 背叛;期望 `low_confidence=true`,**不影響本 AC 通過** |
| AC-50 | 012 | 公式四豁免的正面驗證 |
| AC-51 | 011 | `span_c=0` 且 `n(p)≥2` |
| AC-52 | 011 | 三個獨立觸發條件各驗一次 |
| AC-53 | 011 | `absent_pending` vs `absent_confirmed` |
| AC-54 | 011 | 有記錄時回傳 `active` |
| AC-55 | 007 | `diagnostic_visited_count` 精確等於 `n_p`,**業務邏輯不得讀此欄位** |
| AC-56 | 001 | `Pair` 穩定名稱存取器,與序數無關 |
| AC-57 | 001 | 來源列舉穩定名稱存取器,與 AC-56 對稱 |
| AC-58 | 🔴 **無法歸屬** | 見下方說明 |
| AC-59a | 013 | GDD 明文「今日即可執行,不依賴存檔系統程式碼」 |
| AC-59b | 013 | 五條跨結構不變量各一組合法/非法向量 |
| AC-60 | 014 | 失敗路徑立即釋放權杖 |
| AC-61 | 015 | GDD L 節**明文排除於本系統 DoD**(機制待定案) |
| AC-62 | 007 | 陣亡凍結 vs 形狀不凍結。其 `segment_profile` 子句需 011 |
| AC-63 | 004 | 陣亡配對拒絕 `combat_card`。**這是 skill-card AC-7b 一直欠的第二道防線** |
| AC-64 | 014 | 含第三種非法情形(全新實例、集合從未被填入過) |
| AC-73 | 003 | 含 `t_now=0` 邊界 |
| AC-74 | 003 | 冪等性拒絕,不覆寫既有標記 |
| AC-75 | 007 | GDD 明文「不依賴戰棋系統程式碼,今日即可執行」 |
| AC-76 | 013 | 陣亡標記表持久化 |
| AC-77 | **本切片不涵蓋** | 結局資格閘是**敘事解鎖與結局分支系統(#13)的判定邏輯**,不是本系統。🔴 **此歸屬有一個未查證的前提,見下方** |
| AC-77b | **本切片不涵蓋** | 同上。本系統只負責讓三個函數的 `n(p)` 副值在陣亡配對上**確實不同**。🔴 **同一個未查證前提** |
| AC-78 | 015 | GDD L 節**明文排除於本系統 DoD** |
| AC-79 | 012 | 公式四對陣亡配對一律拒絕 |
| AC-80 | 011 | `source_absence` 事後翻轉合法 |
| AC-81 | 011 | 與 AC-80 互為正反面,**不得只做其一** |

### 🔴 AC-77 / AC-77b 的歸屬帶著一個未查證的前提

> **原樣保留寫這份 epic 的人自陳的限制**:判 AC-77 / AC-77b 屬下游系統,依據是這兩條 AC
> 本文與 Tuning Knobs 的 `n_gate_min` 段落(兩者已逐字讀完)。
> **但 Formulas 的「形狀特徵集合與 Track B 形狀空間的對應」一節(第 234–252 行)只讀了
> 標題與片段,未讀完。** 該節是結局資格閘的設計推導處,**若它對本系統另有義務,
> 這兩條的歸屬就要改。**
>
> **做 S-010 / S-011 之前請先把那一節讀完並回頭覆核這兩列。**

### 分佈

| 去處 | 條數 |
|---|---|
| 切片內(001–009) | **37** |
| 切片外(010–016) | **33** |
| 本切片不涵蓋(AC-4 / 47 / 77 / 77b) | **4** |
| 無法歸屬(AC-58) | **1** |
| **合計** | **75** |

逐 story:001→3、002→**0**、003→2、004→8、005→2、006→1、007→20、008→**0**、009→1、
010→10、011→7、012→6、013→6、014→2、015→2、016→**0**

### 🔴 三張零 AC 的 story,以及為什麼那不是缺陷

- **002(`AffinityRecord` / `AffinityRecordList`)** —— 它們是 **ADR 層構造**,不是 GDD 規則。
  驗收依據是 **ADR-0002 Validation Criteria 第 11 項**(兩層型別皆保住、`get_at()` 越界回
  `null` 不中止),不是任何 AC。**不可用 `get_class()` 做型別斷言** —— 它回傳原生類別,
  任何 `RefCounted` 子類都印 `RefCounted`;應用 `script.get_global_name()` 或 `is`。
- **008(轉接器)** —— 它的驗收在**對面那份 GDD**:`design/gdd/skill-card-system.md`
  的 AC-6(`source=combat_card` 端到端)、AC-7b(繞過介面寫陣亡配對被拒)、
  AC-8c(繞過介面傳非 canon 配對被拒)。本 GDD 不管轄轉接器。
  ⚠️ **這三條的落點是引自 `production/epics/skill-card-system/EPIC.md` 的「驗收條件對照」表,
  不是讀那八張 story 檔本體。** 需要逐條細節時請打開該 GDD 與 `story-004`。
- **016(`can_write()`)** —— ADR-0002 機制九的決策,GDD 零 AC。它在 YAGNI 邊界上,
  **沒有任何已知呼叫方**。放最後。

### 🔴 AC-58 為什麼無法歸屬

AC-58 要對「目前合法名稱集合」與「**已退役名稱對照表**」求交集並斷言為空。
**那張對照表在本專案不存在**,而 GDD 的 Dependencies 存檔系統列明文把
「對照表 + 自動化檢查」的治理責任指給**存檔系統**(`save-system.md` Core Rules #10),
本系統只提供轉換原語。**存檔系統目前已自 MVP 降級至垂直切片層、零實作。**

→ **不硬塞進 S-001。** 在對照表有擁有者之前,這條 AC 沒有第二個集合可以求交集,
硬做只會做出一個「空集合 ∩ 任何東西 = 空」的恆真測試。

### ⚠️ 一項 AC 措辭與 Core Rules #3 不一致(登記,本 epic 不修 GDD)

AC-37 / AC-41 / AC-48 三條都寫「呼叫**任一讀取函數**取得 `c_now`」,
但 Core Rules #3 的計數器可觀測性規則寫的是:三個函數都回傳 `t_query` 與 `n(p)`,
**只有 `shape_feature_read` 額外回傳 `c_now`**。

**實務後果**:S-005 的 AC-39 / AC-41 與 S-013 的 AC-37 / AC-48
**無法在 S-010 落地前以黑箱方式驗證** —— 唯一的觀測通道在形狀特徵讀取上。
**處置**:S-005 先以池的內部狀態(白箱)驗,並在 S-010 完成後**補一次黑箱複驗**。
本 epic 不修 GDD;此項登記給 `producer`。

## 誠實登記的限制(切片做完之後**仍然不成立**的事)

**以下每一條都不得計入本 epic 的完成度。**

| # | 限制 | 誰能解 |
|---|---|---|
| 1 | 🔴 **玩家在畫面上看不到任何變化。** `battle_screen.gd` 對卡牌零命中(實測 `grep -n "CardDeck\|card_deck\|deck\|Card\b" src/ui/battle/battle_screen.gd` → 0 命中),且 `src/` 裡唯一構造 `BattleController` 的地方是 `battle_screen.gd:360`,**沒傳牌組**。本切片的「端到端」是**整合測試層級**,不是遊戲畫面 | 介面層(`ui-programmer` 另案) |
| 2 | **每筆記錄的 `c` 欄位在 S-005 落地前恆為 0。** 依管理者裁決 S-005 已收進切片,故此腳手架**只在 004→005 之間存在**,不會留到切片結束 | S-005(切片內) |
| 3 | 🔴 **`SERIALIZATION_WINDOW_ACTIVE` 是一條測不出真陽性的分支。** `append_record()` 第 1 步要檢查權杖集合非空,但 S-014 在切片外 → 集合永遠是空的,該分支恆為 false。**不要把這一步刪掉**(刪了將來要重新推導整個驗證順序),但**也不要在 story 裡宣稱它被測過** | S-014 |
| 4 | **陣亡凍結只在單元測試裡構造得出來。** `notify_death()` 今天沒有生產端呼叫方 —— 戰棋系統的死亡結算流程尚未定案「陣亡通知 vs 卡牌寫入」的同結算步順序(GDD Dependencies 明文要求該系統自行定案並說明理由) | #4 戰棋移動與交戰系統 |
| 5 | ⚠️ **AC-8 的一半在 S-011 落地前是 fail-open 的。** S-010 讓 `segment_profile` / `low_confidence` 在 `n=0` 時為 `null`;若實作偷懶讓它們**恆為 `null`**,AC-8 照樣通過。擋住這個的是 AC-10(合法零值須與哨兵型別可區分)與 S-011 本身 | S-011 |
| 6 | **好感度不跨存檔保存。** 持久化在切片外;存檔系統本身也已自 MVP 降級至垂直切片層 | S-013 |
| 7 | **預判模式(`game-concept.md` 第四輪已訂為正式功能)在資料層無支援。** 系統 #5 目前讀的是 `assets/data/affinity/vs01_affinity_links.txt` 而非本池(已登記於 `architecture.yaml` 的 `affinity_pairing_data_per_query_refetch`),故今天沒有人在等 | S-012 |
| 8 | 🔴 **埠的 `Rejection` 列舉裝不下 `SERIALIZATION_WINDOW_ACTIVE`。** 埠 5 值、池 7 值。`NON_FINITE_AMPLITUDE` / `INVALID_SOURCE` 在這條路徑上結構不可達(埠檔頭已論證),但 `SERIALIZATION_WINDOW_ACTIVE` **只是今天不可達,不是結構不可達** —— 等 S-014 與存檔系統都在,池就會丟一個埠承載不了的值回來 | 一次裁決(見下) |
| 9 | ⚠️ **`INVALID_PAIR` 在接縫兩側同名不同義。** 埠側 = 「這兩人在劇情上沒有關係線」(由 `PermanentAffinityWriteRules.play()` 在碰埠**之前**決定);池側 = 「配對序數不在 10 個合法值內」。**S-008 不可把池的 `INVALID_PAIR` 直接轉送成埠的 `INVALID_PAIR`** —— 那會把一個程式錯誤讀成一個劇情事實。正解是靠陷阱二的驗證讓池側那個值**永遠不會發生** | S-008 |
| 10 | ✅ **已關閉(2026-09-15 管理者裁決補上)。** 🔴 **原始登記內容保留於下,供查考**——這是「工作單漏了 ADR 明文要求的東西」真的發生過的紀錄,且是被實作者在自陳欄舉手才浮出來的:「`entry_appended` 訊號未實作,而工作單對它零命中。ADR-0002 在 5 處要求它(含兩處 `AffinityDataPool` 的介面宣告 `signal entry_appended(pair, record)`,以及追溯編號 `TR-affinity-024`),明文『`append_record()` 成功時 emit』;而 `story-004` 全文提到它 0 次。S-004 實作者依權威順序(工作單 > ADR)沒有加,並主動在報告裡舉手——判斷可辯護,但那代表 `TR-affinity-024` 今天沒有實作、也沒有任何地方記著這件事。今天不會壞任何東西(實測零命中,沒有人在等它),且 ADR 自己明文這是『實作慣例決策,非已承諾的契約』、下游不得假設其存在。故此處只登記,不自行補——補不補是一次裁決,不是實作細節。」**處置(2026-09-15)**:管理者裁決「現在補」,明確否決「先登記等有人要用再補」與「從 ADR 刪除」兩個選項,依據是 **card-play-interface epic**(`production/epics/card-play-interface/EPIC.md`,卡牌介面要即時反映關係變化)是這個訊號第一個看得見的使用者。已補上訊號本體與 `append_record()` 成功路徑的 emit(`src/gameplay/affinity_pool/affinity_data_pool.gd`),並補三條單元測試——成功發出一條(斷言配對與記錄本體皆正確)、兩條拒絕路徑(`ZERO_AMPLITUDE`/`INVALID_PAIR`)各一條「確認不發出」,兩條「不發出」斷言皆以刻意注入假發出驗證過**真的會紅**才採用(`tests/unit/gameplay/affinity_pool/affinity_data_pool_write_path_test.gd`)。🔴 **但書不變,寫進了程式碼註解**:ADR-0002 原文(`TR-affinity-024`)仍是「實作慣例決策,非承諾契約」,補上不等於升格——下游(含 card-play-interface)**不得假設**此訊號會被其他 ADR 或未來重構保留 | 已解:`gameplay-programmer`,2026-09-15 |

### 限制 8 的處置:登記,不由本 epic 發起裁決

三條路:①在 `AffinityWritePort.Rejection` 新增一個值;②S-008 把它折成既有值(**會說謊**);
③明文登記為「做 S-014 那天一併處理」。

**不需要新 ADR** —— 這是既有檔案的列舉加一個成員。但它**是跨系統介面變更**,
應登記進 `docs/registry/architecture.yaml`。本專案已有「用登記表兩列取代兩份 ADR」的前例
(`affinity_pairing_data_per_query_refetch`,`adr: none`)。

📌 **它今天不擋路**,故本 epic 只登記、不提報;由協調者在它真的擋路時提出。

## ADR-0002 的 7 項事實層過期(登記,**本次不動 ADR 本體**)

逐條比對 ADR-0002 機制一~九與今天的程式碼。**6 項是事實層過期(改字不改決策),
1 項是計畫層凍結造成的真實阻擋。**

| # | 位置 | 現況 | 處置 |
|---|---|---|---|
| 1 | Migration Plan:「`src/` 目前為空,尚無任何實作程式碼」 | `find src -name "*.gd" \| wc -l` → **41** | **要改**(不改決策) |
| 2 | Constraints:「5 名主角尚未定名…角色系統尚未設計」 | `design/narrative/characters.md` 已有正典姓名(Canon: Established);`vs01_roster.txt` 已釘死 id 1~5。**佔位 enum 設計仍正確**,但多出一套 ADR 不知道的權威編號 → 即陷阱一 | **要改**(並補上對映) |
| 3 | 機制四之三之二:「三個呼叫點**全部無 GDD 亦無 ADR**…呼叫端義務**沒有任何文件承接**」 | 技能卡牌已有 GDD + 8 張完成 story + 程式碼;且那條義務**已被 `affinity_write_port.gd` 檔頭領養** | **要改**(孤兒義務已有主) |
| 4 | Engine Compatibility:「`modules/` 只有 animation/…/ui,**無 core/scripting**」 | 現有 `core-serialization.md` 與 `scripting-typing.md`,且據 `VERSION.md` 是該目錄**僅有的兩份已更新到 4.7.1** 的檔案 | **要改**(它改變「該查哪裡」) |
| 5 | `Blocks` 欄:「24 項 `TR-affinity-*` 缺口**全數**卡在此」 | `traceability-index.md` 現載 **21 ✅ / 3 ⚠️ / 0 ❌** | 記錄即可(手抄計數漂移) |
| 6 | 🔴 機制七 `TOKEN_TIMEOUT_MS` | 定值責任在 ADR-0004,而 ADR-0004 被計畫層明文凍結 → **照 ADR 寫,機制七寫不完** | **已由管理者裁決處置**:S-015 標 🔒 Blocked。ADR 沒寫錯,是它依賴的上游被凍結 |
| 7 | `Related Decisions` / Consequences 的 `authoritative_write_in_progress` 改名(2026-09-09) | **已同步**,且 `card_play_session.gd` 用的也是新名字 | ✅ **查過沒事**(列出來是免得下一個人以為沒查) |

**逐條查過、今天仍然成立的**:機制一(DI 非 Autoload)、機制二(per-pair 索引 + 包裝層)、
機制四之二(鍵/值兩條邊界規則)、機制五(`t_query` 的 `typeof()` 三分支閘門與 `match`
順序陷阱)、機制八之二(`to_dict()` 的大寫 `"COMBAT_CARD"`,2026-09-01 已更正)、
機制九(`can_write()` 可達性表)。

## 既定前提(2026-09-15 管理者裁決,本 epic 不重新討論)

1. **目標是「玩家在畫面上真的打得到卡牌」** —— 但介面層另派,本 epic 只負責資料層那一段。
2. **S-005(戰役刻度)不延後,收進切片。** 理由:跨結構不變量第 1 條是「Delta Log 非空
   則標記列表必非空」,若在 `c=0` 狀態下累積過記錄再做 S-013,**那顆池的存檔會被它自己的
   驗證器判為非法**,而失敗點離寫入點很遠(要等玩家存過檔才會出現)。
3. **S-014 / S-015 整組延後。**
4. **不寫新 ADR。** 本系統預期再產生 **0** 份新 ADR,與劑量規則的預估一致。

## 本 epic 的已知缺口(交給 `producer`,不由實作者處理)

- **`production/epics/index.md` 尚未登記本 epic。** 本次奉指示只寫 `EPIC.md` 一個檔案。
  ⚠️ **這不是小事**:本專案 2026-09-04 有前例 —— 一個管理者裁決被記在 8 個檔案裡卻
  **沒有任何工作單擁有它**,三天內沒進入任何排程。**索引沒登記 = 同一個形狀。**
- **`tests/gdunit4_runner.gd` 的 `FORCED_ARGS` 是否需要改**(見陷阱五),協調者驗證中。
- **AC-37 / 41 / 48 的「任一讀取函數」措辭**與 Core Rules #3 不一致,待回頭修 GDD。
