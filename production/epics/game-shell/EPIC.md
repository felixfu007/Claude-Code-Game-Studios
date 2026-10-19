# EPIC:遊戲殼層(戰鬥以外的狀態)

> **建立**:2026-10-19(管理者裁決「丙案:做最小的標題/主選單」)
> **Status**: Active
> **規格權威**:本 epic **沒有** GDD,也刻意不寫 ADR —— 理由見下方「為什麼不寫 ADR」。
> **量測依據**:`docs/reviews/shell-layer-feasibility-2026-10-19.md`(133 行,含引擎原始 log)

## 這個 epic 要補的洞

**遊戲開機直接進戰鬥,然後永遠待在那裡。** 當場可重跑:

```bash
grep -n "run/main_scene" project.godot          # → res://src/ui/battle/BattleScreen.tscn
grep -rn "change_scene" src/ --include=*.gd     # → 零命中
```

七個場景全部是戰鬥相關,整個 `src/` 零場景切換。**沒有標題畫面、沒有戰鬥外狀態。**

### 它擋住的不只一件事(2026-10-19 協調者逐項對帳)

| 剩下的 MVP 項目 | 需不需要「戰鬥外」狀態 | 依據 |
|---|---|---|
| **#8 支援對話系統** | 🔴 **要** | `design/quick-specs/support-conversation-system.md` 第 2 節:觸發點「全部掛在關卡與關卡之間」,5 場關卡之間 4 個轉場槽位 |
| **#11 支援對話 UI** | 🔴 **要** | 同上,它是 #8 的畫面 |
| **設定/選項畫面** | 🔴 **要** | 2026-10-16 管理者裁決「開,但只做最小的」;`battle-hud-prediction-marker.md` AC13 預設了「戰鬥外可以改」 |
| #9 好感度視覺呈現 UI(關係圖迷你地圖) | ❌ 不用 | 它是戰鬥中比較棋子用的疊加介面(`game-concept.md:244`)。⚠️ **這一列是協調者 2026-10-19 查的,未經第二人覆核** |

**三個卡住的 MVP 項目共用同一個根因** —— 這是管理者選丙案(補根因)而非甲/乙案(在不存在的前提上補洞)的理由。

## 為什麼不寫 ADR(2026-10-19,`godot-specialist` 判定,協調者覆核同意)

- `.claude/docs/coding-standards.md` 的規則是「**只在跨系統契約時才寫 ADR**」。
- 實測顯示場景切換與既有 ADR-0005(游標/高亮狀態系統)的**唯一交集**,是下方那條
  「`tree_exited` 解除註冊」義務 —— 那是**新畫面要遵守舊契約的既有規則**,不是新契約。
- 流程劑量上限預期剩餘系統僅再產生 0~1 份新 ADR(`one-year-plan.md` 第六節②)。
- ⚠️ **若日後量到場景切換與 ADR-0005 機制五(`_frame_events` / `_arbitration_suspended`)
  有真正衝突,屆時才有寫 ADR 的理由** —— 該項目前**未量測**,已登記在可行性報告第二節。

## 🔴 本 epic 全域硬性實作義務(每張 story 都適用)

> **任何向 `CursorStateHost` 註冊 `CursorSurfaceRegistry` 表面的畫面,
> 必須自己接一條 `tree_exited → unregister_surface`,比照 `src/ui/battle/battle_screen.gd:1301`。**

**這不是風格建議。** `cursor_surface_registry.gd` 的類別註解明文:一般表面註冊
「lifecycle managed via explicit unregister calls(**no automatic cleanup**)」——
註冊表**刻意不自動清理**。不接的後果記在 `battle_screen.gd` 1282~1301 行的註解裡:
`CursorNavigationApplier._process()`(Autoload,永不卸載)會在**之後某個完全無關的場景**
撞到已釋放節點,逐字 `SCRIPT ERROR: Trying to return a previously freed instance`,
**實機驗證、曾經純因執行順序弄壞 `battle_menu_layout_test.gd`**。

⚠️ **沒有任何自動檢查會攔這條。** 與本專案其餘同類規則一樣,遵守與否目前不可觀測。

## 已量測的三件事(不必重新假設)

| | 結論 | 物證 |
|---|---|---|
| 游標 Autoload 跨場景 | **全程同一實例,未被重建,`_process` 未中斷** | `prototypes/shell-layer-scene-switch-probe-2026-10-19/run_output_headless.txt` 的 `Q1-FINAL: same_as_original=true` |
| 來回切換 | **零錯誤**,第二個 `BattleScreen` 是全新實例、乾淨重新註冊 | 同檔 `Q4-*` 各行 |
| `change_scene_to_file()` 時機 | **混合**:舊場景移除同步發生、呼叫端下一行照常執行;新場景 `_ready()` 延後到同一幀稍後 | 同檔 `Q3-*` 各行 |

**實作後果**:呼叫 `change_scene_to_file()` 之後**不可假設新場景已掛上樹**;要存取新場景請先 `await` 至少一幀。

## Stories

| # | 標題 | Type | Status |
|---|---|---|---|
| 001 | 標題畫面與場景切換骨架 | UI + Integration | Ready |
| 002 | 最小設定畫面(EGM 開關落地) | UI | 未建立 —— 待 001 完成後評估 |
| 003 | 關卡之間的轉場槽位(支援對話系統的掛載點) | Integration | 未建立 —— 待 #8 規格的開放問題 6 有答案 |

## 本 epic 不涵蓋

- **不做存檔**(ADR-0004 仍 `Proposed`,且已明文不在 12 個月範圍內)。
- **不做關卡選擇**(`BattleScreen` 已有 `*_path_override` 注入點可供日後使用,本 epic 不動它)。
- **不改 `BattleMenu` 的「離開確認」語意**(目前是結束遊戲)。🔴 可行性報告指出
  `battle_menu.gd:373` 的 `quit_callable` 是**現成可注入點**,改成「回主選單」技術上不必動
  `BattleMenu` 本體 —— **但那會改動 `design/ux/battle-menu.md` 的既有語意,屬設計變更,
  需另行裁決。本 epic 登記但不執行。**
- **不做視覺風格** —— 標題畫面的美術方向未定,story-001 只要求可用、可讀、符合既有字級規則。
