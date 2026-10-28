# Story 002:猜測選擇器的畫面與輸入

> **Epic**: 戰鬥 HUD(僅預判標記)—— `production/epics/battle-hud/EPIC.md`
> **Status**: ✅ **Done-pending-visual(2026-10-28)** —— AC1~AC4、AC10~AC12 有測試(`tests/integration/ui/battle/battle_screen_egm_guess_selector_test.gd`,40 條,18 條常駐敏感度證明、3 條不可證理由在檔頭);AC13 由既有設定畫面滿足。畫面(AC2/AC4/AC10)待管理者簽核。commit `025c36d`;協調者重跑 1471 全綠。原狀態:Ready(**AC13 明文切出,見下方「開工前查核」**)
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M
> **規格權威**: `design/quick-specs/battle-hud-prediction-marker.md`(208 行)
> **前置**: `story-001`(✅ Done 2026-10-16)—— `EffectGuessTracker` 已存在且 17 條測試綠。

## Context

`story-001` 做完了**判定、鎖定狀態機、一致率累計**,全部是純 `RefCounted`、零節點。
**本 story 把它接到畫面與輸入上。**

🔴 **這個機制的意義全繫於規格 AC8**:揭曉真實數值之前,玩家的猜測必須已經鎖死。
`story-001` 已經把這個性質做進狀態機並用兩條獨立測試釘住。
**本 story 不得在呈現層開出繞過它的路**(例如讓選擇器在揭曉後仍可互動)。

## 🔴 開工前查核(2026-10-16 協調者執行)—— 一條 AC 的驗收對象是空集合

> ✅ **2026-10-27 更新:本節前提已不成立。** 設定畫面已存在(game-shell story-002),
> 戰鬥開局讀一次 `GameSettings.is_egm_enabled()` 後整場鎖定,唯讀查詢
> `BattleScreen.is_egm_enabled_for_this_battle()` 已存在且有測試(`egm_setting_test.gd`)。
> ➜ **AC13 由既有實作滿足;AC-NEW(暫代開關)作廢 —— 本 story 不得再做任何暫代 EGM 開關。**
> 以下原文保留作為決策紀錄。(管理者 2026-10-27 核准此加註)

本專案 `production/epics/cursor-highlight-state/EPIC.md` 登記過這個形狀的通則:
> `/story-readiness` 檢查的是「前置 story 完成了沒」與「ADR 核准了沒」,
> **它結構上不會檢查「這張要驗的東西是否存在」**。

逐條查的結果:

| AC | 驗收對象存在嗎 |
|---|---|
| AC1 迴歸安全(EGM 關閉時行為不變) | ✅ 現行行為就是對照組 |
| AC2 選擇器出現 | ✅ 本 story 自己建 |
| AC3 輸入平權 | ✅ 本 story 自己加 `battle_guess_cycle` |
| AC4 揭曉與鎖定同時 | ✅ `story-001` 的狀態機已就位 |
| AC10 非純色區分 | ✅ 本 story 自己建 |
| AC11 在地化 | ✅ `strings.csv` 已存在 |
| AC12 跳過不隱藏資訊 | ✅ 本 story 自己建 |
| 🔴 **AC13 戰鬥中開關鎖定為唯讀** | ❌ **空集合** |

**AC13 為什麼是空的**(當場可重跑):
```bash
ls src/ui/menu/                                  # → 只有 BattleMenu
grep -rln "settings\|options\|設定" src/ui/ --include=*.gd
```
`BattleMenu` 只有「結束回合列 / 離開確認 / 退出」三件事,**全專案沒有任何設定或選項畫面,
也沒有任何地方可以打開 EGM 模式。**

🔴 **處置:AC13 明文切出本 story,不假裝做得到。**
- 本 story **不實作** EGM 的開啟入口與選項列。
- 本 story **必須**提供一個**唯讀的診斷查詢**(例如 `diagnostic_egm_enabled()`),
  讓「本場 EGM 是開是關」在測試裡可觀測 —— **但開關怎麼被設定,不在本 story 範圍。**
- 🔴 **本 story 期間 EGM 的啟用方式必須明文登記為暫代品**,並寫清楚
  「它日後會被真正的選項畫面取代」。**不得寫成像是最終設計。**
- **AC13 本身移交**:需要一張「設定/選項畫面」的工作單,而那張工作單目前不存在,
  也不屬於本 epic。**本 story 完成時 AC13 仍為未涵蓋,這是明文的,不是疏漏。**

## Acceptance Criteria(規格第 6 節,AC13 除外)

- [ ] **AC1 迴歸安全**:EGM 關閉、游標停在候選格 → 好感度預覽文字立即顯示,
      無選擇器,**行為與現狀逐字相同**。
      🔴 **這一條要有測試。** 它是「新功能沒有弄壞舊行為」的唯一防線。
- [ ] **AC2 選擇器出現**:EGM 開啟、游標停在**尚未猜測過**的候選格 →
      好感度預覽文字被隱藏,選擇器(正/負/無)在**同一區域**取而代之。
- [ ] **AC3 輸入平權**:鍵盤(`battle_guess_cycle` + `battle_confirm`)、滑鼠點擊、
      手把(同鍵盤)三種**各自獨立**能完成一次標記。
      🔴 **新增 `battle_guess_cycle` 到 `project.godot` 的 `[input]` 節**。
      **已核對不衝突的綁定**:鍵盤 `X`、手把序號 **3**(= `JOY_BUTTON_Y`,
      (A) 級證據在 `prototypes/joy-button-index-probe-2026-10-16/`)。
      ⚠️ **headless 下引擎不送 `InputEvent`** —— 測試要用 `Input.action_press()`
      或直接呼叫處理函式,**不要期待模擬真實按鍵**。
- [ ] **AC4 揭曉與鎖定同時發生**:第一次標記的同一瞬間,(a) 預覽文字顯示真實值
      (b) 選擇器轉為唯讀。**真實數值不得早於標記完成就出現。**
- [ ] **AC10 非純色區分**:「不符合」的回饋除顏色外**必須**有圖形或文字差異。
      📌 本專案有色盲可辨識性的硬性要求(見 `design/ux/accessibility-requirements.md`)。
- [ ] **AC11 在地化**:選擇器與一致率呈現的**所有**玩家可見文字一律走
      `assets/data/locales/strings.csv` 的鍵,原始碼不得出現寫死的中文字面值。
      **建議寫一條結構守衛測試**(比照 `story-001` 的 AC14 守衛手法)。
- [ ] **AC12 跳過不隱藏資訊**:在「尚未猜測」狀態直接送出移動確認(跳過)→
      好感度預覽**比照 EGM 關閉時立即顯示**,不得因跳過而繼續隱藏。
- [ ] 🔴 **AC-NEW 本 story 自訂**:EGM 啟用方式的暫代品**必須在程式註解裡明文標為暫代**,
      並指出它要被什麼取代。本專案已登記過「暫代品沒有任何自動檢查會確認它日後被移除」,
      所以**至少要留下可被搜尋到的明文**。

## Affected Files

| 檔案 | 預期動作 |
|---|---|
| `src/ui/battle/battle_screen.gd` | **修改**(接線、選擇器顯示、隱藏/揭曉切換) |
| `project.godot` | **修改** —— 新增 `battle_guess_cycle` 到 `[input]` 節 |
| `assets/data/locales/strings.csv` | **修改** —— 新增選擇器與一致率的文字鍵 |
| `tests/integration/ui/battle/...` | 新建 |

🔴 **`src/ui/battle/effect_guess_tracker.gd` 不得修改。** 它已完成並有 17 條測試。
若發現它的介面不夠用,**停下來回報**,不要直接改它 —— 那會動到已驗收的東西。

⚠️ **改 `assets/data/locales/strings.csv` 之後,測試一定要用
`GODOT_BIN=... bash tools/build/run_tests_with_import.sh`** ——
CSV 改了不重新匯入,引擎讀的是舊快取,而**測試會假綠**
(2026-10-15 登記的第六種假綠燈,協調者的獨立重跑當時也被騙過)。

## 🔴 這張工作單必須在有畫面的環境驗收

**AC2 / AC4 / AC10 要人眼看。** 本專案登記過:
> 目前為止所有畫面缺陷都是人開圖看到的,自動檢查一次也沒抓到過。

**截圖證據須依 `.claude/docs/coding-standards.md` 的三類分類法歸類後再套用檢查** ——
選擇器很可能是 **Category C(裁切/局部擷取)**,而那一類的 Check 2/Check 3
**原樣套用會指向錯誤方向**,該節有明文替代做法。**不要自己發明替代指標。**

## 交付與驗收

**只跑你自己那幾支檔**,全套由協調者跑。
回報時貼 `ENGINE EXIT` / `Overall Summary` / `Executed test suites` 三行原文。
