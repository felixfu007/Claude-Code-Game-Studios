# Story 001:標題畫面與場景切換骨架

> **Epic**: 遊戲殼層 —— `production/epics/game-shell/EPIC.md`
> **Status**: ✅ **Done-pending-visual(2026-10-19,協調者獨立重跑驗收,不採信回報)**
> —— AC1~AC6、AC9 全部落地且有自動化測試;**AC10 待管理者在家看畫面簽核**(今天在公司看不了,明文不驗收)。
> 全套由協調者自己重跑:`ENGINE EXIT = 0` / `WRAPPER EXIT = 0` /
> `Overall Summary: 1290 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans` /
> `Executed test suites: (110/110)` / `grep "Parse Error"` 零命中 / `grep " FAILED"` 零命中。
> 基線 1286 → 1290 **正好是新增的 4 條**,且新測試檔名確實出現在輸出裡(不是存在但沒跑)。
>
> 🔴 **本 story 最值得記的是協調者覆核抓到的一個【會變成間歇性失敗】的寫法**:
> `_on_battle_ended()` 原本用 `get_tree().create_timer(3.0)` —— **SceneTree 層級、
> 與 `BattleScreen` 實例生命週期脫鉤**。而 `story-018` 的既有測試會真的走到 `battle_ended`,
> 等於全套執行期間裝上一顆「3 秒後自動切整個場景」的計時器,而全套要跑 75~80 秒。
> **訊號連線只在接收者真正 `free()` 時才失效,`queue_free()` 到真正釋放之間有延遲** ——
> 若延遲夠長,它就會在另一條完全無關的測試執行中切走場景。**它不會每次都炸,只會偶爾炸。**
> 實作者查證後同意,並選了比協調者建議更徹底的改法:**改用 `BattleScreen` 自己的子 `Timer` 節點**
> (生命週期綁在實例上,本節點被釋放時倒數當場停止),守衛另外也加了當最後一道防線。
>
> ⚠️ **三項誠實登記未做**:①AC7(三種輸入導覽)/ AC8(在地化)**程式碼已實作但無專屬測試**;
> ②四條新測試**沒有敏感度證明**;③AC10 視覺完全未驗證。
>
> 📌 **連帶改到一個不在 `Affected Files` 的檔**:`tests/unit/core/i18n/locale_data_integrity_test.gd`
> 的寫死列數 75 → 78(新增 3 個標題畫面字串直接撞到)。**實作者直接改並主動揭露,
> 協調者判定這個判斷是對的**(兩次前例、且是自己改動的直接後果,不是「既有測試依賴一個被打破的架構假設」)。
> 管理者同日裁決**另把該條移到檔案最後一條**,理由見該檔新增的區段註解。
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
  ✅ **2026-10-28 部分取代**:**勝利且非最後一場**時,已改為「支援對話畫面(若有)→ 直接進下一場」(管理者裁決「對話播完直接進下一場」,`production/epics/support-conversation-ui/story-004-transition-wiring.md`)。戰敗與戰役完成仍回標題。原句保留。
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
