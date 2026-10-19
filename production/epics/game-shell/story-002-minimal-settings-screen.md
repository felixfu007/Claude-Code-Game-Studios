# Story 002:最小設定畫面(效果猜測標記開關落地)

> **Epic**: 遊戲殼層 —— `production/epics/game-shell/EPIC.md`
> **Status**: Blocked —— 等 `story-001` 完成(標題畫面的「設定」鈕目前是停用狀態)
> **Layer**: Presentation + State
> **Type**: UI(呈現為 ADVISORY)+ Logic(狀態與讀取為 BLOCKING)
> **Estimate**: M
> **裁決依據**:2026-10-16 管理者裁決「設定/選項畫面:**開,但只做最小的**」;
> 2026-10-19 管理者裁決**丙案**(做最小的標題/主選單),本 story 是它的第二半。

## Context

**「最小」的形狀上週五撞到過一次**:當時以為只要在戰鬥選單加一列,查完發現
**遊戲根本沒有「戰鬥以外」這個狀態**(`docs/reviews/settings-screen-has-nowhere-to-live-2026-10-16.md`)。
`story-001` 把那個狀態做出來了,**本 story 才是原本那張工作單要做的事**。

**唯一要做的設定項**:效果猜測標記(Effect-Guess Marker,EGM)的開關。
**規格權威**:`design/quick-specs/battle-hud-prediction-marker.md`
(🔴 **AC13 就是被切出去、等本 story 的那一條**:
「戰鬥中打開選項選單 → EGM 開關應顯示目前值但**不可互動變更**;變更只在下一場戰鬥開始時生效」)。

## 🔴 開工前必答的一題:這個設定值住在哪裡(本 story 的主要技術決定)

**本工作單刻意不替實作者決定**,但**必須在交付時寫下選了哪一個與理由**。三條路各有登記在案的代價:

| 做法 | 代價 |
|---|---|
| **新增 Autoload** | 🔴 **要同時更新 `.claude/docs/technical-preferences.md` 的 Autoload 表,而那是既有文件 —— 依 2026-10-12 裁決必須先問管理者。** 另:註冊 Autoload 會讓它在**每一個測試場景**啟動,本專案明文要求新增時實跑全套確認無新失敗 |
| **`static var` 於一個小型設定類別** | 不必動 Autoload 表;但**靜態狀態跨測試共用**,會產生執行順序相依 —— 必須提供 `reset_for_test()` 之類的顯式重置,並在測試裡用 |
| **存檔系統** | ❌ **排除**:ADR-0004 仍 `Proposed`,且依一年計畫**明確不在 12 個月範圍內** |

⚠️ **本階段不要求跨啟動持久化。** 設定值在同一次遊戲執行內有效即可 ——
「關掉遊戲再開還記得」需要存檔系統,而那不在範圍內。**這一點請明文寫進 doc comment,
不要讓下一個人以為它壞了。**

## Acceptance Criteria

### A. 設定狀態(BLOCKING)

- **AC1**:存在一個可讀寫的「EGM 是否開啟」狀態,預設**關閉**
  (迴歸安全:規格 AC1 要求 EGM 關閉時行為與現狀完全相同)。
- **AC2**:`BattleScreen` 在 `_ready()` 讀取該值**一次**,整場戰鬥不再重讀
  —— 這就是規格「不支援戰鬥中途熱切換」的落地點。
- **AC3**:測試證明「戰鬥開始後改變設定值,不影響進行中的那一場」。

### B. 設定畫面(BLOCKING 的部分)

- **AC4**:`story-001` 標題畫面的「設定」鈕**解除停用**,可進入設定畫面。
- **AC5**:設定畫面可用鍵盤/手把/滑鼠三種方式操作,比照 `BattleMenu` 的既有做法。
- **AC6**:可返回標題畫面,且來回切換零 `SCRIPT ERROR`(比照 story-001 AC6 的迴歸鎖)。
- **AC7**:全部文字走 `Loc.localize()`,新鍵加進 `assets/data/locales/strings.csv`。

### C. 戰鬥中的唯讀顯示(規格 AC13 —— 本 story 的終點)

- **AC8**:戰鬥中打開 `BattleMenu` 時,**顯示 EGM 目前值但不可變更**。
  🔴 **「顯示但不可變更」要做成玩家看得懂的形狀,不是一顆按下去沒反應的鈕**
  —— 本專案登記過「暫代品沒有任何自動檢查會確認它日後被移除」。

### D. 呈現(ADVISORY)

- **AC9**:1920×1080 / 2560×1440 下文字不溢出,字級依既有規則取得倍率
  (**必須呼叫 `WorldLayout.compute_scale()`,不得自行計算** —— `.claude/docs/technical-preferences.md` 硬性義務)。
  ⚠️ **需管理者在家看畫面簽核。**

## 本 story 不涵蓋

- **不做跨啟動持久化**(需要存檔系統,明確不在 12 個月範圍內)。
- **不做音量/解析度/按鍵重綁等任何其他設定項** —— 「只做最小的」是明文裁決。
- **不改 `BattleMenu` 的「離開確認」語意**(見 EPIC)。

## 交付前必做

跑一次全套並貼出引擎原始三行(`ENGINE EXIT` / `Overall Summary` / `Executed test suites`):

```
GODOT_BIN="C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  bash tools/build/run_tests_with_import.sh
```
