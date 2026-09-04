# Story 001（screen-scaling:世界層手動縮放定位）進度追蹤

寫這份檔案的理由:本專案的 subagent 有很高機率在「宣告要開始大量產出」之後、
實際動手之前被中斷（見 dispatch brief 第九節）。以檔案為準，不以文字回報為準。

## 設計已驗證（2026-09-04）

`prototypes/story-001-manual-scaling-verification-2026-09-04/` —— 手動
position/size + stretch_shrink>1 同時作用，四種解析度全部正確（詳見該目錄
README）。**設計不再是假設，可以照此實作。**

## 檔案清單與狀態

- [x] `prototypes/story-001-manual-scaling-verification-2026-09-04/` — 設計驗證 spike，已完成
- [x] `src/ui/battle/world_layout.gd` — 新增,pure 工具類別(WorldLayout),完成
- [x] `src/ui/battle/BattleScreen.tscn` — WorldViewportContainer 移除靜態滿版錨點,改掛 world_viewport_scaler.gd
- [x] `src/ui/battle/world_viewport_scaler.gd` — 新增,完成
- [x] `src/ui/battle/board_coords.gd` — doc comment 更新完成(函式簽章不變),headless --import 乾淨通過
- [x] `src/ui/battle/battle_screen.gd` — 滑鼠座標換算改用 _window_pos_to_cell()+WorldLayout,headless --import 乾淨通過(先前中斷點:_window_pos_to_cell 呼叫點寫了但函式未定義,現已補上)
- [x] `src/ui/CLAUDE.md` — 協調者已授權(不在 `.claude/` 底下)。原「條件一/條件二」以 blockquote 退役,新增「世界層容器改為手動置中」節,明文「紀律沒放寬,唯一出處換成 WorldLayout」
- [x] `project.godot` — window/stretch/mode 改 disabled；aspect/scale_mode 決定拿掉（連帶處理）；**最後才改，且要跟腳本一起提交**
- [x] `tests/unit/core/display_pixel_settings_test.gd` — 拆成兩條測試(mode=disabled;aspect/scale_mode 移除後回退引擎預設 keep/fractional),完成
- [x] `tests/unit/cursor/cursor_layer_transform_test.gd` — 環境健全性測試改寫(斷言恆等),類別 doc comment 加註 AC-S010-a 現在資訊量下降但保留理由,headless --import 乾淨通過
- [x] `tests/unit/ui/world_layout_test.gd` — 新增,完成
- [x] `tests/unit/ui/battle_screen_mouse_coords_test.gd` — 新增,完成(涵蓋 1x/2K/4K/邊區越界四種情境)
- [x] `production/qa/evidence/screen-scaling-evidence.md` — 完成,含機械檢查、人眼確認(本人+協調者)、介面退化交叉引用
- [x] 全套測試重跑,371 test cases/0 errors/1 failures(既有紅燈)/0 orphans/exit 100,cursor_layer_transform_test.gd 11 條全跑到,途中抓到並修正一個真實 min_size 語意的測試前提錯誤
- [ ] 最終回報

## 已知的「超出派工範圍但發現」清單（會在最終回報列出，不擅自處理無關項）

1. **`battle_screen.gd` 的滑鼠點擊座標換算**依賴 canvas_items 模式下引擎自動把
   `InputEvent.position` 轉成 480x270 base-canvas 空間再送達 `_input()`（該檔
   class doc comment 明文記載 2026-08-27 實測）。切成 disabled 後這個自動轉換
   消失，`_handle_mouse_button()`/`_update_cursor_visual()`裡
   `event.position - _world_viewport_container.global_position` 這段算式會整個
   算錯（差一個 scale 倍率）。**判斷：這是本次原子變更必然牽連的正式程式碼，
   不修的話滑鼠點擊在真實遊戲裡會失準——已決定一併修正並在報告中列出**，
   而非視為「不相關發現只列出不動」。
2. **`src/ui/GameRoot.tscn` 不是實際執行的場景**（`run/main_scene` 指向
   `BattleScreen.tscn`，兩者結構重複但各自獨立）。本次只改 `BattleScreen.tscn`，
   `GameRoot.tscn` 維持原樣，於回報中列出建議由檔案擁有者裁決是否收斂。
3. ✅ 已處理（協調者已授權更新 `src/ui/CLAUDE.md`，該檔不在 `.claude/` 底下，先前誤判為在授權範圍外）。原「條件一：世界層容器以滿版錨點貼齊基準畫布」／「條件二：換算呼叫 `Window.get_final_transform()`」兩條紀律以 blockquote 退役（保留原文，註明前提消失的日期與理由），新增「世界層容器改為手動置中」節，明文寫清楚：紀律沒有放寬，只是唯一出處從引擎的 `get_final_transform()` 換成 `WorldLayout`。

## 測試基線（協調者提供，開工前）

356 條 / 0 errors / 1 failures（既有已核准紅燈 affinity_phi_provider）/ 0 orphans / exit 100

## min_size 收尾（2026-09-04，追加，協調者已獨立驗證同一結論）

`Window.min_size` 在 Godot 4.7.1 沒有對應的 project.godot 設定鍵（協調者與我各自
獨立探針確認：17 個 `display/window/size/*` 鍵逐一列出，六種可能鍵名皆
`has_setting=false`）。已在 `world_viewport_scaler.gd` 的 `_ready()` 用
`get_window().min_size = Vector2i(960, 540)` 補上，headless --import 乾淨通過
（先前中斷點：const 寫在 extends 之前，GDScript 語法要求 extends 必須在前，已修正）。

**範圍落差已在該檔 doc comment 記錄，並會寫進最終回報**：這是場景層級腳本設定
行程層級屬性，目前因 BattleScreen.tscn 是 run/main_scene 而無影響；若未來有
標題畫面先於戰鬥畫面載入，本設定會延後生效。未擅自搬進 CursorStateHost
（明文禁止 logic_in_cursor_autoload_shell）。

## 全套測試重跑結果（2026-09-04，最終）

**第一次跑出 2 failures**：`affinity_phi_provider_test.gd`（既有已核准紅燈，預期）
+ 我新寫的 `battle_screen_mouse_coords_test.gd::test_window_pos_to_cell_at_1x_...`。

**根因（非production bug，是測試前提本身不成立）**：`world_viewport_scaler.gd`
的 `_ready()` 設 `Window.min_size=(960,540)`；實測確認**對「當下尺寸已小於新
min_size」的視窗設定 min_size 會立即把 size 夾到新最小值**（不是只影響之後的
resize）。測試把 root 設成 480x270（1x）後才 spawn BattleScreen 實例，
BattleScreen 的 `_ready()` 一設 min_size，root.size 立刻被夾成 960x540 —— 1x 從
此在真實遊戲裡是結構性不可達的狀態（min_size 裁決本來的目的正是如此），
測試在斷言一個已經不存在的狀態。已修正：改測 960x540（真正可達的最小值,
scale=2），並在測試 doc comment 記錄這個發現與 log 位置
（`prototypes/story-001-manual-scaling-verification-2026-09-04/verify_minsize_clamp.gd`）。

⚠️ **副作用抓到的教訓**：`battle_screen_mouse_coords_test.gd` 第一條測試失敗後,
同套件其餘 3 條**完全沒有執行**（「Statistics: 1 test cases」）——與本專案
`coding-standards.md` 記載的既有教訓（一條失敗會中止同 suite 其餘測試）完全一致,
修完後重跑該檔確認 4/4 全過。

**最終結果**：**371 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans | exit 100**
（29/29 suites、371/371 test cases 全部執行到）。唯一失敗仍是既有已核准的
`affinity_phi_provider` 紅燈,與協調者開工前給的基線一致。淨新增 15 條測試
（world_layout_test.gd 10 條 + battle_screen_mouse_coords_test.gd 4 條 +
display_pixel_settings_test.gd 拆一為二淨增 1 條）,356+15=371,與基線 356 完全對得上。

**`cursor_layer_transform_test.gd` 的 11 條逐一確認全部執行且全部通過**
（含改寫過的環境健全性測試、2 條靈敏度金絲雀、4 條 AC-S010-a、1 條圖層比較、
3 條 AC-S010-b）。log:`production/session-state/screen-scaling-story-001/full_test_run_output_final.txt`。
