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
| 001 | 標題畫面與場景切換骨架 | UI + Integration | ✅ **Done-pending-visual(2026-10-19)** —— AC10 待管理者在家簽核 |
| 002 | 最小設定畫面(EGM 開關落地) | UI + Logic | ✅ **Done-pending-visual(2026-10-19)** —— AC6 明文未做、AC9 待簽核 |
| 003 | 關卡序列與轉場流程(支援對話的掛載點) | Logic + Integration | 🟡 **部分 Done(2026-10-19)** —— AC1~AC6 落地有測試;🔴 **AC7/AC8(真的切到下一場、來回切換迴歸鎖)明文未做**,協調者縮減範圍。✅ 2026-10-27:AC7(真的切到下一場)已由 story-005 補上(序列表第 2 列接上);AC8 由 round-trip 與 scene_router 測試涵蓋 → **整張 Done**(管理者 10/27 核准) |
| 004 | 直接開進戰鬥的啟動旗標(修復自動截圖證據) | Logic + Tools | ✅ **Done(2026-10-19)** —— 旗標 `--capture-battle`,雙向測試;🔴 **不要加 `--` 分隔符,加了會安靜失效**(實測) |
| 005 | 場景切換改手動(交得出資料)+ 離開戰鬥回主選單 | UI + Integration | ✅ **Done-pending-visual(2026-10-27)** —— 支援對話第一次真的帶到下一場;離開確認框三按鈕待目視。原狀態:Ready |

## ✅ story-001 的一項連帶後果:自動截圖證據失效 —— **同日已修(story-004)**

> **2026-10-19 當日處置**:管理者裁決「今天補,跟著 story-002 一起做」,已由 **story-004** 完成
> (旗標 `--capture-battle`,雙向測試,截圖工具檔頭已補說明)。
> 🔴 **但有一個已知限制:不要加 `--` 分隔符** —— 實測帶了 `--` 之後旗標會跑到
> `OS.get_cmdline_user_args()`,而判定只看 `OS.get_cmdline_args()`,**會安靜地什麼都不做**。
> ⚠️ **尚未驗證的一半**:「帶旗標啟動匯出建置、真的拍到戰鬥畫面」這條端對端路徑**沒有跑過** ——
> 旗標的判定有測試,但「截圖證據這條路真的修好了」還沒有被證明。
>
> **以下原文保留作決策紀錄(它記載了發現當下的狀態與理由)。**

`run/main_scene` 改指向 `TitleScreen` 之後,**匯出的建置開機進的是標題畫面**。
而截圖工具 `tools/build/capture_window.ps1` 的做法是「啟動 exe → 沿行程樹找到真正的遊戲視窗 → 拍它」,
**它沒有任何輸入能力,不會按「開始戰鬥」**(當場可查:`grep -n "SendInput\|keybd_event\|mouse_event" tools/build/capture_window.ps1` 零命中)。

**後果分兩半,不要混讀**:
- **人工看畫面不受影響** —— 多按一下「開始戰鬥」而已。
- 🔴 **自動截「戰鬥畫面」當證據這件事等於失效。** 而本專案的
  `.claude/docs/coding-standards.md` 明文記載:**至今每一個畫面缺陷都是人開圖看到的,
  自動檢查一次也沒抓到過** —— 截圖是那道人眼防線的輸入,不是裝飾。

**建議修法(story-004,尚未裁決)**:在 `TitleScreen._ready()` 檢查
`OS.get_cmdline_args()`,帶特定旗標時直接呼叫 `start_battle()`。
⚠️ **這是新增範圍,不是 story-001 的缺陷** —— story-001 的 `Affected Files` 沒有截圖工具,
本節只登記事實與建議,**不自行擴大上一張工作單的範圍**。

## 本 epic 不涵蓋

- **不做存檔**(ADR-0004 仍 `Proposed`,且已明文不在 12 個月範圍內)。
- **不做關卡選擇**(`BattleScreen` 已有 `*_path_override` 注入點可供日後使用,本 epic 不動它)。
- **不改 `BattleMenu` 的「離開確認」語意**(目前是結束遊戲)。🔴 可行性報告指出
  `battle_menu.gd:373` 的 `quit_callable` 是**現成可注入點**,改成「回主選單」技術上不必動
  `BattleMenu` 本體 —— **但那會改動 `design/ux/battle-menu.md` 的既有語意,屬設計變更,
  需另行裁決。本 epic 登記但不執行。**
- **不做視覺風格** —— 標題畫面的美術方向未定,story-001 只要求可用、可讀、符合既有字級規則。
