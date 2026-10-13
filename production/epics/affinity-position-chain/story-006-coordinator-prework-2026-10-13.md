# Story 006 協調者前置反查(2026-10-13)

> **為什麼有這份檔**:本專案實測,實作型派工最會被吃光的回合是「開工前的唯讀反查」。
> 本檔由協調者在派工**之前**做完,原始輸出全部附上。
> ⚠️ **本檔只是反查結果,不是裁決。** 任何一條與磁碟不符就以磁碟為準,並回報。
>
> 🔴 **而且前置反查【會錯】** —— 同一天 `story-008` 的前置檔給了一個錯建議,被實作者當場推翻。
> **本檔刻意把「我量到的事實」與「我由此推論的建議」分開寫**,方便你只推翻後者。

## 一、【事實】夾限在今天的真實資料下**結構上不可能觸發**

```
$ cat assets/data/affinity/vs01_affinity_links.txt | grep -v "^#" | grep -v "^$"
1,2,POSITIVE,1
3,4,NEGATIVE,1
```
**整張關係表只有 2 條線,而且每個單位最多只出現在 1 條裡**(1、2、3、4 各一次;5 號戊完全沒有)。

```
$ grep -n "^const PHI_MIN\|^const PHI_MAX\|^const DELTA_" src/gameplay/affinity/affinity_rules.gd
35:const DISTANCE_ADJACENT: int = 1
38:const DISTANCE_FAR: int = 3
41:const DELTA_POSITIVE_ADJACENT: int = 3
44:const DELTA_POSITIVE_FAR: int = -1
47:const DELTA_NEGATIVE_ADJACENT: int = -1
50:const DELTA_NEGATIVE_FAR: int = 2
54:const DELTA_NEUTRAL: int = 0
65:const PHI_MIN: int = -4      # 註解自述 = 4 × DELTA_NEGATIVE_ADJACENT
71:const PHI_MAX: int = 12      # 註解自述 = 4 × DELTA_POSITIVE_ADJACENT
```

🔴 **兩個邊界是依「每人最多 4 條線」推導的,而真實資料是每人最多 1 條。**

| | 真實資料可達範圍 | 夾限邊界 |
|---|---|---|
| 最小 | **−1** | −4 |
| 最大 | **+3** | +12 |

### 🔴 這對本 story 的直接後果(**這是本檔最重要的一段**)

**本 story 的整個功能 —— 揭露「原始和、有沒有被夾限、夾到哪一邊」—— 用真實資料永遠得到
「沒有被夾限」。** 亦即:

- **AC 第 3 條**(「原始和與 `bonus_for_at()` 的夾限後總和在同一組輸入下必須一致」)
  **用真實資料是恆真的**,因為夾限根本沒作用。**那樣的測試不證明任何東西。**
- **「夾到上界」與「夾到下界」兩個分支,用真實資料是不可達程式碼。**

**所以測試必須用合成的 `Array[AffinityLink]`**(讓單一單位身上掛 4 條以上的正向線以越過 +12,
或 5 條以上負向線以越過 −4)。
📌 **好消息:這些函式全是 `static func` 且 `links` 是參數,不是從檔案讀** ——
```
$ sed -n '124,129p' src/gameplay/affinity/affinity_rules.gd
static func bonus_for_at(
	unit_id: int,
	origin: Vector2i,
	positions: Dictionary[int, Vector2i],
	links: Array[AffinityLink]
) -> int:
```
**合成資料直接當參數傳即可,不需要造假資料檔、不觸及本專案的檔案 I/O 禁令。**

⚠️ **依 `.claude/docs/coding-standards.md` 的紀律**:若某個分支真的構造不出來,
**必須寫「沒有可測對象(N/A)」,不得寫「0 個違規 / 通過」** —— 兩者字面數字可能相同,
但前者是「這次沒驗證到任何東西」,後者暗示「驗證了,而且乾淨」。

## 二、【事實】現有實作長什麼樣(本 story 要擴充的就是這段)

```
$ sed -n '124,134p' src/gameplay/affinity/affinity_rules.gd
static func bonus_for_at(
	unit_id: int, origin: Vector2i,
	positions: Dictionary[int, Vector2i], links: Array[AffinityLink]
) -> int:
	var total: int = 0
	for status: AffinityLineStatus in lines_for_at(unit_id, origin, positions, links):
		total += status.delta
	return clampi(total, PHI_MIN, PHI_MAX)
```
**加總與夾限就在這八行裡。** 四個相關函式:`bonus_for`(105)、`bonus_for_at`(124)、
`lines_for`(142)、`lines_for_at`(155)。

## 三、【建議,可推翻】新查詢怎麼擺

🔴 **以下是協調者的推論,不是事實,也不是裁決。實作者有權推翻,推翻請寫理由。**

- **不要在新函式裡再寫一次 `for ... total += status.delta`。** 本專案登記過
  「同一個公式兩份實作,只是今天答案一致」,而黑箱比對**永遠無法區分
  『共用同一份』與『兩份碰巧一致』**。建議讓 `bonus_for_at()` 與新查詢**共用同一個加總**
  (例如抽出一個 private 的 `_raw_total_at()`,兩邊都呼叫它)。
  ⚠️ **這也正好讓 AC 第 3 條從「恆真的空測試」變成「結構保證」** ——
  但**結構保證仍然需要測試釘住**,不要因為「共用了所以一定一致」就不寫測試。
- **「夾到哪一邊」建議用一個三值列舉而非兩個布林**(未夾 / 夾到下界 / 夾到上界)——
  兩個布林可以同時為真,那是一個表達得出來但不可能發生的狀態。
  ⚠️ **若用 enum,絕不可用 `assert()` 守衛它的分支** —— 本專案 2026-09-15 實機實測:
  `assert()` 失敗會中止呼叫端並產出回傳型別的 **ordinal 0**,
  慣例上成功值排第一,等於**斷言失敗反而回傳「成功」**。

## 四、【事實】本 story 明文不碰 `battle_screen.gd`

該檔 Out of Scope 節逐字列出「`src/ui/battle/battle_screen.gd` 的任何修改」。
⚠️ 但同檔另註「**這是判斷,不是保證**」—— 若實作中發現非加一行呼叫不可,**停下回報**。

📌 **同檔另一項排程約束**:「**本 story 與 story-005 不可同時派人**」。
**協調者已確認 `story-005` 仍是 `Ready`、尚未開工。**
