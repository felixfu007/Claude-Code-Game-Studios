# Story 005:場景切換改為手動管理(交得出資料)+ 離開戰鬥回主選單

> **Epic**: 遊戲殼層 —— `production/epics/game-shell/EPIC.md`
> **Status**: Ready
> **Layer**: Presentation + Integration
> **Type**: UI(呈現為 ADVISORY)+ Integration(切換行為為 BLOCKING)
> **Estimate**: L —— **它要動今天已驗收的兩張工作單的既有行為,請特別小心**
> **裁決依據**:管理者 2026-10-19 兩項裁決:
> ①「**甲:由切場景的那一方交給它(推薦)**」(被跳過:戰鬥開局自己去要 / 先不接)
> ②「**兩個都要:回主選單 + 離開遊戲**」(被跳過:只改成回主選單 / 不改)

## 這張為什麼存在

### 一、裁決①的後果:`change_scene_to_file()` 必須被換掉

管理者選了「**由切場景的那一方把累積記錄交給新畫面**」。
**而 Godot 的 `change_scene_to_file()` 沒有這個時機窗** —— 它自己做
`instantiate()` 與 `add_child()`,**中間不交棒給呼叫端**。
(實測在 `prototypes/shell-layer-scene-switch-probe-2026-10-19/` 的 `Q3-*` 各行。)

本專案的注入時機窗明文只有一個(`.claude/docs/technical-preferences.md`):
> **`instantiate()` 之後、`add_child()` 之前**(`_ready()` 只讀一次,而 `_ready()` 要進樹才跑)。

➜ **所以要拿回那個窗口,切場景那一層就得自己管**:
`load()` → `instantiate()` → **注入** → `add_child()` → 釋放舊場景。

🔴 **為什麼不是「讓戰鬥開局自己去要」**(那個選項被跳過,理由要留著):
實作者 2026-10-19 查證後**拒絕執行協調者原本的指示**,理由正確 ——
那會讓**全專案絕大多數從未注入過 ledger 的 `BattleScreen` 測試**
(地形掃描、戰鬥結算……與戰役完全無關的)在 `_ready()` 都去碰那個**共用的靜態單例**。
**今天不會變紅(它剛好是空的),但那是一次未經核准的耦合面擴大**,
正是 `.claude/rules/gameplay-code.md` 裁決④自己點名的風險類型。

### 二、裁決②的後果:戰鬥選單要有兩個不同的離開

**今天之前「離開 = 關掉遊戲」是對的**,因為遊戲沒有別的地方可去。
**今天之後就不一致了** —— 有標題畫面了,但離開鍵不認得它。當場可查:

```bash
grep -n "quit_callable" src/ui/menu/battle_menu.gd        # 395: var quit_callable: Callable = Callable()
grep -rn "quit_callable" src/ --include=*.gd | grep -v battle_menu.gd | wc -l   # → 0,沒有人注入過它
grep -n "leave_confirm" assets/data/locales/strings.csv    # 「離開遊戲?」「目前沒有存檔功能…」
```

## 🔴 開工前必讀:這張會動到今天剛驗收的東西

| 會動到 | 它現在被什麼釘著 |
|---|---|
| `title_screen.gd` 的 `start_battle()` | `tests/integration/ui/shell/title_screen_scene_switch_test.gd`(story-001 AC4/AC6) |
| `battle_screen.gd` 的 `return_to_title_screen()` | 同上(story-001 AC5) |
| `settings_screen.gd` 的 `back_to_title()` | story-002(無專屬測試,**明文登記過**) |
| `BattleMenu` 的三列版面 | `battle_menu_layout_test.gd` —— 🔴 **面板高度是規格寫死的,加第四列會擠壓既有三列** |

**弄壞它們不是可接受的交付。** 但「既有測試原本就依賴一個現在不成立的假設」
是**回報給協調者裁決**的事,**不是自己默默改掉**。

## Acceptance Criteria

### A. 手動場景切換(BLOCKING)

- **AC1**:新增一個**單一的場景切換入口**(建議放在殼層,例如一個 `SceneRouter` 之類的
  純邏輯/薄殼),做 `load()` → `instantiate()` → **注入** → `add_child()` → 釋放舊場景。
  🔴 **不得散落成每個畫面各自一份** —— 本專案登記過「同一份邏輯兩處實作、只是今天答案一致」。
- **AC2**:切進戰鬥時,**由切換方注入**
  `instance.campaign_ledger_override = CampaignProgress.start_mission_affinity_ledger()`。
  ⚠️ **`start_mission_affinity_ledger()` 自己會先呼叫 `begin_mission()`** —— 那是它存在的理由,不要繞過。
- **AC3**:story-001 的既有迴歸鎖**仍然全綠**:來回切換零 `SCRIPT ERROR`,
  第二次進戰鬥時 `register_surface(BOARD_TILE)` 仍回 `DUPLICATE_TAG_REJECTED`。
  🔴 **手動管場景時,舊場景的釋放時機由你決定 —— 而那正是游標表面解除註冊會出事的地方。**
- **AC4**:🔴 **支援對話的寫入真的進入下一場** —— 這是整條線「有沒有效果」的驗收點
  (支援對話 EPIC 的 AC5)。**打完第 1 場 → 觸發 SC-01 → 第 2 場開局查得到那筆。**
  ⚠️ **需要第 2 場存在**(`vs02_*`,2026-10-19 另行派工)。

### B. 離開戰鬥的兩個去處(BLOCKING 的邏輯半部)

- **AC5**:戰鬥選單提供**兩個不同的離開**:**回主選單** 與 **離開遊戲**,語意不同、文案不同。
- **AC6**:「回主選單」走 AC1 那個切換入口;「離開遊戲」維持 `get_tree().quit()`。
- **AC7**:新文案進 `assets/data/locales/strings.csv`,**並同步更新
  `tests/unit/core/i18n/locale_data_integrity_test.gd` 的列數**(那條在該檔**最後一條**,檔尾有格式說明)。
- **AC8(ADVISORY)**:🔴 **四列版面要人眼簽核** —— `battle_menu_layout_test.gd` 釘著的面板高度是
  規格寫死的,**管理者已知情接受「可能擠壓既有三列」這個代價**,但**畫面好不好看今天無法簽核**。
  ➜ **實作時若發現四列在任何目標解析度下溢出或重疊,停下來回報,不要自己改規格寫死的高度。**

## 本 story 不涵蓋

- **存檔**(ADR-0004 仍 `Proposed`,明確不在 12 個月範圍內)。
- **關卡選擇畫面**。
- **關卡 2~5 的內容**(第 2 場另行派工,3~5 場仍不存在)。

## 交付前必做

跑全套,**貼引擎原始三行**。🔴 **先看 exit code 再 grep log。**
```
GODOT_BIN="C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  bash tools/build/run_tests_with_import.sh
```

## 📌 給派工者的提醒(2026-10-19 實測得出)

**這是一張「破壞式」工作單**,而本專案今天兩次零產出都發生在這種工作單上
(47 次與 32 次工具呼叫、磁碟零產出)。**有效的處方是三件一起做**:
1. **把要改的那幾段程式碼直接貼進派工單**(不要讓 agent 去讀四千行的檔案);
2. **替它做掉技術決定**(不要留「你判斷」的分岔給一個正在燒回合的 agent);
3. **切成每個都能單獨編譯的單位,並明文授權「這一輪零改動既有檔也算合格」。**
