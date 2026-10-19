# Story 001:標題畫面與場景切換骨架

> **Epic**: 遊戲殼層 —— `production/epics/game-shell/EPIC.md`
> **Status**: Ready
> **Layer**: Presentation + Integration
> **Type**: UI(呈現條件為 ADVISORY)+ Integration(切換行為為 BLOCKING)
> **Estimate**: M
> **裁決依據**:2026-10-19 管理者裁決「**丙:做最小的標題/主選單**」,
> 被跳過的三個選項:甲(戰鬥選單加唯讀列)/ 乙(選單內直接改)/ 先不決定。
> **量測依據**:`docs/reviews/shell-layer-feasibility-2026-10-19.md`

## Context

本專案至今**零場景切換**,遊戲開機直接進 `BattleScreen` 並永遠待在那裡。
本 story 建立第一個「戰鬥外」狀態,**並證明來回切換不會弄壞游標系統**。

🔴 **不要重新探索已經量過的東西。** 三件事已有引擎原始 log(見 EPIC「已量測的三件事」):
游標 Autoload 跨場景是同一實例、來回切換零錯誤、`change_scene_to_file()` 是混合時機。
**探針在 `prototypes/shell-layer-scene-switch-probe-2026-10-19/`,可直接讀它的寫法。**

## 🔴 開工前查核(2026-10-19 協調者執行)

| 驗收對象 | 存在嗎 |
|---|---|
| `change_scene_to_file()` 在本專案可用 | ✅ 探針實測 `Error=0`,來回切換零錯誤 |
| 選單的方向鍵/手把導覽先例 | ✅ `src/ui/menu/battle_menu.gd` —— **它用引擎原生 `Button` focus(`focus_mode = Control.FOCUS_ALL`)+ `ui_accept`**,因為疊加型選單依 ADR-0005 Core Rules #7 本來就排除在游標註冊制之外 |
| 在地化字串管道 | ✅ `Loc.localize(key)` + `assets/data/locales/strings.csv`(`keys,zh_TW`) |
| 戰鬥結束訊號 | ✅ `BattleScreen._on_battle_ended(outcome)`(`battle_screen.gd:3907`),由 `_controller.battle_ended` 驅動(`:1240`),**story-018 已有端對端測試釘住它會發出** |
| 標題畫面的美術方向 | ❌ **不存在** —— 本 story 不做視覺風格,只要可用可讀。⚠️ **明文登記,不是疏漏** |

## Acceptance Criteria

### A. 場景與切換(BLOCKING —— 必須有自動化測試)

- **AC1**:新增 `src/ui/shell/TitleScreen.tscn` 與 `src/ui/shell/title_screen.gd`。
  根節點型別為 `Control`(本畫面**不含** `SubViewport`/`SubViewportContainer`,
  故 `GameRoot.tscn` 那個「裸 `Control` 當父節點會壞掉」的已知陷阱不適用 ——
  見 `.claude/docs/technical-preferences.md`「⚠️ 同一支 spike 另外抓到一個正式檔案的缺陷」段)。
- **AC2**:`project.godot` 的 `run/main_scene` 改指向 `TitleScreen.tscn`。
- **AC3**:標題畫面提供三個項目:**開始戰鬥** / **設定** / **離開遊戲**。
  「設定」本 story **不實作**,以**停用狀態(disabled)**呈現 —— 🔴 **不得做成可點但無反應**,
  也不得做成「暫代的假畫面」(本專案登記過「暫代品沒有任何自動檢查會確認它日後被移除」)。
- **AC4**:「開始戰鬥」切換到 `BattleScreen.tscn`,且切換後 `current_scene` 確為 `BattleScreen`。
  **測試直接呼叫公開方法(例如 `start_battle()`),不模擬 `InputEvent`** ——
  headless 不送 `InputEvent`(`coding-standards.md` CI 節已登記)。
- **AC5**:戰鬥結束(`BattleScreen` 收到 `battle_ended`)之後,**回到標題畫面**。
  🔴 **呈現時序交由實作者決定並寫下理由**(例:先顯示勝敗文字 N 秒再切、或等玩家按鍵)——
  但**必須可被測試驅動**,不得只能靠真人等待。
- **AC6**:來回切換(標題 → 戰鬥 → 標題 → 戰鬥)**零 `SCRIPT ERROR`**,
  且第二次進入戰鬥時 `CursorStateHost.register_surface(BOARD_TILE)` 仍回傳
  `DUPLICATE_TAG_REJECTED`(代表 `BattleScreen#2` 乾淨地重新佔住了 tag)。
  **這一條就是 EPIC 那條 `tree_exited` 義務的迴歸鎖。**

### B. 輸入與在地化(BLOCKING)

- **AC7**:三個項目可用**鍵盤方向鍵、手把 d-pad、滑鼠**三種方式導覽與選取,
  比照 `battle_menu.gd` 的既有做法(原生 `Button` focus + `ui_accept`)。
  ⚠️ **不要自己發明第二套導覽機制** —— 本專案明文禁止下游系統各自重實作裝置權威判定。
- **AC8**:所有玩家可見文字一律走 `Loc.localize()`,新鍵加進 `assets/data/locales/strings.csv`,
  **不得硬編中文字面值**。
- **AC9**:`TitleScreen` **不向 `CursorStateHost` 註冊任何表面**(比照 `BattleMenu` 的疊加排除),
  並以一條測試斷言這件事。🔴 **若實作者判斷非註冊不可,必須同時接 `tree_exited → unregister_surface`
  並在 doc comment 寫明理由** —— 見 EPIC 全域義務。

### C. 呈現(ADVISORY —— 需管理者在家簽核,今天做不了)

- **AC10**:標題畫面在 1920×1080 / 2560×1440 下文字不溢出、不重疊,字級走既有規則
  (`hud_layout.gd` 呼叫 `WorldLayout.compute_scale()`,**不得自行計算倍率** ——
  `.claude/docs/technical-preferences.md` 硬性義務)。
  ⚠️ **本條需要截圖證據 + 人眼簽核,依 `coding-standards.md` 的 UI 類為 ADVISORY。
  管理者今天在公司不能看遊戲畫面,故本條【今天不驗收】,story 可先標 Done-pending-visual。**

## 🔴 交付前必做(2026-10-12 管理者裁決)

凡依裁決直接改既有程式碼檔的 agent,**交付前必須跑一次全套,並在回報裡貼出引擎自己的
`ENGINE EXIT` 與 `Overall Summary` 原始三行** —— 不是只說「測試通過」。

```
GODOT_BIN="C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  bash tools/build/run_tests_with_import.sh
```

⚠️ **先檢查引擎的 exit code 再 grep log。** 任何落在 {0, 100, 101, 103} 之外的碼
(尤其 **105**:測試收集階段就炸了、`Overall Summary` 與 ` FAILED` **兩個 grep 都回空**)
代表測試一條都沒跑 —— 詳見 `coding-standards.md` CI 節。

## Affected Files

- 新增:`src/ui/shell/TitleScreen.tscn`、`src/ui/shell/title_screen.gd`
- 新增:`tests/integration/ui/shell/title_screen_scene_switch_test.gd`
- 修改:`project.godot`(`run/main_scene`)
- 修改:`assets/data/locales/strings.csv`(新增標題畫面字串鍵)
- 修改:`src/ui/battle/battle_screen.gd`(AC5:戰鬥結束後切回標題)
  —— **在本工作單明文範圍內,依 2026-10-12 裁決可直接改,不必先問**

## 本 story 不涵蓋

- 設定畫面本體(story-002)、關卡之間的轉場槽位(story-003)。
- **不改 `BattleMenu` 的「離開確認」語意**(目前是結束遊戲)—— 見 EPIC「本 epic 不涵蓋」。
- 標題畫面的美術/視覺風格。
- 存檔、關卡選擇、繼續遊戲。
