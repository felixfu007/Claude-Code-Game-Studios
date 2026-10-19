# Story 003:關卡序列與轉場流程(支援對話的掛載點)

> **Epic**: 遊戲殼層 —— `production/epics/game-shell/EPIC.md`
> **Status**: Ready
> **Layer**: Domain(流程邏輯)+ Presentation(場景切換接線)
> **Type**: Logic(**BLOCKING**)+ Integration
> **Estimate**: M
> **裁決依據**:管理者 2026-10-19 下午,逐字選項「**關卡轉場機制(推薦)**」。
> 被跳過的三個:清測試債 / 先裁決三個結構缺口 / 提前收工。
> **上游**:`design/quick-specs/mvp-five-levels-skeleton.md`(5 場關卡、4 個轉場槽位)、
> `production/epics/support-conversation/story-001`(✅ Done —— 觸發判定與規則已存在)

## 這張要做什麼(一句話)

**把「打完一場 → 轉場 → 進下一場」做出來,並在轉場處掛上支援對話的唯一觸發點。**

## 🔴 開工前查核(2026-10-19 協調者執行)—— 三件會決定做法的事實

### 一、只有第 1 關有真實資料

```bash
ls assets/data/levels/   # vs01_terrain.txt + 三個 test_fixture_*
ls assets/data/units/    # vs01_roster.txt + 三個 test_fixture_*
```
**關卡 2~5 的地形、名冊、牌組、好感度前置全部不存在。**
➜ **本 story 不製作那些內容**(那是 `level-designer` 的工作)。
**序列表要能表達 5 場,但現階段只有第 1 場指得到真實資料**;測試用既有夾具驗。

### 二、四個資料路徑注入點已經存在,不必新建

```bash
grep -n "_path_override" src/ui/battle/battle_screen.gd
#   463: terrain_path_override   467: roster_path_override
#   477: affinity_path_override  481: cards_path_override
```

### 三、🔴 **最會咬人的一件:`change_scene_to_file()` 沒有資料注入的時機窗**

`.claude/docs/technical-preferences.md` 明文:
> **資料注入只有一個時機窗:`instantiate()` 之後、`add_child()` 之前**
> (`_ready()` 只讀一次,而 `_ready()` 要進樹才跑)。

而 `change_scene_to_file()` **自己做 instantiate 與 add_child**,中間**不交棒給呼叫端** ——
story-001 的探針已量到它的時序(`Q3-*`:呼叫端下一行照常執行,新場景 `_ready()` 延後到同一幀稍後)。
**亦即:你沒有機會在新的 `BattleScreen._ready()` 跑之前設它的 `*_path_override`。**

🔴 **這一題必須在開工時就決定,本工作單刻意不替你選,但要求你寫下理由**:

| 做法 | 代價 |
|---|---|
| **(甲) 一個小型「戰役進度」持有者,`BattleScreen._ready()` 自己去讀** | 與今天剛落地的 `GameSettings`(`static var` + `reset_for_test()`)**同一個形狀**,有現成先例可抄;但又多一份全域靜態狀態,測試要顯式重置 |
| **(乙) 放棄 `change_scene_to_file()`,改成手動管理場景**(自己 `instantiate()` → 注入 → `add_child()` → 釋放舊場景) | 拿回注入時機窗;但 story-001/002 的既有切換路徑全部要改,而那兩張的迴歸測試正釘著現行行為 |

⚠️ **若你選 (乙),請先停下來回報再動手** —— 它會動到兩張已驗收的工作單的既有行為。

## Acceptance Criteria

### A. 流程邏輯(BLOCKING —— 必須有自動化測試)

- **AC1**:一個**純邏輯**的戰役流程類別(零節點、零場景),持有「目前第幾場」。
  **解析與讀檔分離**,比照 `card_text.gd` / `Unit.roster_from_text`(解析類別不碰 `FileAccess`)。
- **AC2**:關卡序列是**版控資料檔**,不是寫死在程式裡
  (`coding-standards.md`:「Gameplay values must be data-driven」)。
  每列至少要有:場次編號 + 四個資料路徑(terrain / roster / affinity / cards)。
- **AC3(勝利推進)**:戰鬥結果為 `VICTORY` → 前進到下一場;已是最後一場 → 進入「戰役完成」終態
  (**終態長什麼樣由你定,但必須是明確的狀態,不是靜默停住**)。
- **AC4(失敗回滾)**:結果為 `DEFEAT` → **整關回滾重來**,場次編號不前進。
  依據逐字:`vertical-slice-level-01.md`「任一人 HP 歸零即關卡失敗……好感度、腐蝕、牌組與
  營火配對選擇**一併回滾重來**」。
  ⚠️ **「好感度一併回滾」這一半本 story 做不到** —— 見下方「不涵蓋」第 1 項。**明文登記,不要假裝做到了。**

### B. 支援對話掛載(BLOCKING)

- **AC5**:轉場時呼叫 `SupportConversationRules`(story-001 已完成)判定並觸發該槽位的對話,
  **而且這是整個系統唯一的觸發呼叫點**。
  🔴 **支援對話系統 story-001 的 AC6 掃描範圍只涵蓋 `src/gameplay/narrative/`** ——
  **若你把呼叫點寫在那個目錄之外,那條既有的「恰好一處」測試【攔不到】**(它自己誠實登記了這個窄範圍)。
  **二選一並寫下理由**:①呼叫點放進 `src/gameplay/narrative/`;②放別處,但**同批擴大那條掃描測試的範圍**。
  **不可以兩個都不做。**
- **AC6**:測試證明「第 4 場之後(4→5 槽位)**沒有**對話被觸發」——
  五場骨架明文該槽位空置,而**空集合最容易被誤判成「功能還沒做」**。

### C. 接線(Integration)

- **AC7**:戰鬥結束後,流程**真的切到下一場**,且新場次讀到的是序列表指定的資料。
  測試用既有夾具(`test_fixture_*`)驗,**不要求關卡 2~5 的真實資料存在**。
- **AC8**:來回切換零 `SCRIPT ERROR`,且游標表面註冊沒有殘留
  (比照 story-001 AC6 的迴歸鎖 —— 這是 EPIC 那條 `tree_exited` 義務的持續驗證)。

## 本 story 明文不涵蓋(不是疏漏)

1. 🔴 **好感度跨關卡延續** —— `AffinityDataPool` 目前是在 `BattleScreen._ready()` 裡 `new()` 出來的,
   **每打一場重建一次**(`grep -rn "AffinityDataPool.new()" src/`)。這是已交回管理者的結構缺口
   (`production/epics/support-conversation/EPIC.md` 開工前查核二),**本 story 不自行裁決**。
   ➜ **支援對話的寫入仍走依賴注入,呼叫端可以傳一個丟棄式的寫入埠。**
   **AC4 的「好感度一併回滾」因此在本 story 內恆成立(因為它本來就不跨關)** —— 這是現況,不是本 story 做到的。
2. **關卡 2~5 的內容**(地形、敵人、數值)——`level-designer` 的工作。
3. **營火/整備畫面**、**對話的畫面呈現**(系統 #11)。
4. **跨啟動持久化**(存檔系統明確不在 12 個月範圍內)。

## 交付前必做

跑一次全套,**貼出引擎原始三行**。今天基線:`1335 test cases | 0 failures | (114/114)`。

```
GODOT_BIN="C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  bash tools/build/run_tests_with_import.sh
```
⚠️ **先看 exit code 再 grep log**(105 代表測試一條都沒跑,而兩個 grep 都會回空)。
⚠️ **若新增字串鍵到 `strings.csv`,必須同步把 `locale_data_integrity_test.gd` 的 83 改成 83+N**
(那條在該檔最後一條,檔尾有區段註解說明格式)。
