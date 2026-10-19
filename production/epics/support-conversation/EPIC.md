# EPIC:支援對話系統(系統 #8)

> **建立**:2026-10-19(管理者裁決:「支援對話系統的邏輯半邊(推薦)」)
> **Status**: Active
> **規格權威**:`design/quick-specs/support-conversation-system.md`(177 行,輕量規格)
> **內容來源**:`design/quick-specs/mvp-five-levels-skeleton.md`(5 場關卡節拍與 4 個轉場槽位)
> **不涵蓋**:系統 #11「支援對話 UI」是**另一個系統**(`design/gdd/systems-index.md` 第 11 列),不在本 epic。

## 規格已結案、不要重新設計的四件事

| | 結論 | 出處 |
|---|---|---|
| **槽位分配** | SC-01 → 1→2、SC-02 → 2→3、SC-03 → 3→4,**4→5 空置** | 五場骨架 Q1 |
| **配對與方向** | SC-01 甲—乙(加深正向)、SC-02 甲—丙(**負向**)、SC-03 乙—丁(正向);**戊不參與任何一段** | 五場骨架 Q2 |
| **完成時機** | **強制自動觸發,玩家不可延後,也沒有「可延後」這個狀態** | 規格第 3 節 |
| **posthumous 變體** | **不做** —— MVP 不存在「角色已陣亡、戰役仍繼續」這個狀態(任一人 HP 歸零即整關回滾) | 規格第 5 節 |

## 🔴 開工前查核(2026-10-19 協調者執行)—— 兩個結構缺口,都不擋邏輯半邊

### 一、池的 `Source` 列舉有 `SUPPORT_CONVERSATION`,但**沒有任何寫入路徑送得出它**

```bash
grep -n "enum Source" -A 4 src/gameplay/affinity_pool/affinity_types.gd
#   46:enum Source {  47: COMBAT_CARD,  48: SUPPORT_CONVERSATION,  49: STORY_EVENT,
grep -n "SOURCE_" src/gameplay/cards/affinity_write_port.gd
#   91:const SOURCE_COMBAT_CARD: StringName = &"combat_card"     ← 只有這一個
```

`AffinityPoolWritePort.append_record()` 的 `_source` 參數**刻意底線前綴、從不讀取**,
無條件映射成 `COMBAT_CARD` —— 它的 doc comment 明寫理由:「本埠的**唯一合法呼叫端**
(`PermanentAffinityWriteRules.play`)恆傳 `SOURCE_COMBAT_CARD`」。

**而支援對話是不同的來源**:規格第 3 節逐字寫它是「**無 α 折扣、權重 1.0**」的寫入,
與戰鬥卡牌不同。**照現況寫進去,它會被記成戰鬥卡牌。**

📌 **這是本專案登記過的「孔已開、上游不存在」家族的又一例**,只是方向相反:
**列舉開好了、池收得下,中間那一段送不出去。**

### 二、🔴 好感度池是在 `BattleScreen._ready()` 裡 `new()` 出來的 —— 它活不過一場戰鬥

```bash
grep -rn "AffinityDataPool.new()" src/ --include=*.gd
#   src/ui/battle/battle_screen.gd:1165:	_affinity_pool = AffinityDataPool.new()
```

**每打一場戰鬥就重建一個池**,開局再依 `AFFINITY_PATH` 的靜態檔逐條灌入(story-005 的暫代作法)。
**支援對話發生在關卡【之間】,而它要寫入的那個池,在關卡之間不存在。**

⚠️ **這與現行設計一致、不是 bug** —— `vertical-slice-level-01.md` 明文「任一人 HP 歸零即關卡失敗,
好感度一併回滾重來」,單關回滾本來就不需要跨關的池。**但 5 場關卡的弧線需要它,而那個東西還不存在。**

🔴 **交回管理者裁決,本 epic 不自行決定**:跨關卡的好感度要怎麼延續(誰持有池、存哪裡、
與存檔系統的關係)。**在那之前,本 epic 的寫入一律走依賴注入,不碰任何真實池實例。**

## Stories

| # | 標題 | Type | Status |
|---|---|---|---|
| 001 | 資料表、觸發判定與規則驗證(純邏輯) | Logic | ✅ **Done(2026-10-19)** —— AC1~AC7 全部有測試,40 條 |
| 002 | 接上關卡轉場與真實好感度池 | Integration | **Blocked** —— 等上面兩個缺口的裁決,以及 `game-shell` story-003 |

## 本 epic 不涵蓋

- **不做對話文字內容**(那是 `writer` 的工作,規格第 1 節明文)。
- **不做 UI**(系統 #11,另一個系統)。
- **不做排程系統** —— MVP 明文「寫死的觸發點」「不需要排程系統」。
- **不做跨啟動持久化**(存檔系統明確不在 12 個月範圍內)。
