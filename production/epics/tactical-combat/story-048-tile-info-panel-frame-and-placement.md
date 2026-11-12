# Story 048:資訊卡 —— 不透明底與框、位置避開敵兵(或隨游標側切換)

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-12)—— 🔴 前置:art-director 的「面板語言統一」決定(框/底色規格)
> **Type**: UI
> **Estimate**: M
> **優先序**: 畫面可讀性批次 T9
> **依據**:
> - 管理者 2026-11-12 核准範圍,選項逐字「**修今天的字重疊 + 介面 + 重做高亮層次 + 圖例(UX 專家推薦)**」(含 T9)。紀錄:`active.md` 第九十九批節(grep「重做高亮層次」)。
> - 證據:`docs/reviews/screen-readability-verified-ux-2026-11-12.md` N5、V6(右上資訊卡半透明,底下棋盤格點、敵兵血條透出文字;固定位置壓住敵兵 2);
>   `docs/reviews/screen-readability-verified-art-2026-11-12.md` V6(四種面板語言、無共用框)。

## 為什麼

資訊卡半透明且固定右上,文字與棋盤內容互相干擾,並遮住一個敵人。

## 派工前須先決定

1. **美術規格(art-director)**:不透明底色、框線寬/色,且須與手牌區、提示列、選單的面板語言統一(本單只套用在資訊卡;其餘面板另議)。規格不到位不開工,實作者不得自創色值。
2. 🔴 **既有裁決警告**:管理者 2026-11-03 對「介面蓋棋盤」選的是「指到才變淡 + 一鍵隱藏」,**被跳過「介面依游標自動換邊」**
   (`production/epics/battle-hud/story-004-hud-board-overlap.md`),且該單明言「資訊框本輪不單獨處理」。
   本單的「隨游標側切換」**等同被跳過的選項**,**不得自行採用,須新裁決**;可先做的部分:不透明底 + 框 + 「位置固定但不涵蓋任何敵方起始格」(若算得出)。
   算不出無重疊位置時停下回報,附各解析度算術。

## Acceptance Criteria

- [ ] **AC1 不透明與框**:資訊卡底色 alpha 依規格(不透明或規格指定值);框依規格。測試斷言面板節點的底色/框常數等於規格常數,並以真實 `BattleScreen` 載入驗證實際節點(非只驗常數)。
- [ ] **AC2 位置不變式**:資訊卡矩形(取自真實矩形函式,不得另算)與每個敵方單位格視窗矩形在 960、1366×768、1440、1920、2560×1440、3440×1440、3840×2160 皆不相交;
      防空洞:斷言被測敵兵數 == 關卡敵兵總數。若 AC2 在任一尺寸算不出解 → 停下回報(見前置 2),不得靜默放寬。
- [ ] **AC3 內容不變**:`build_tile_info_text` 簽章與輸出不變(story-039/040/042 的斷言全綠);面板高度規則(最多 9 行)不變。
- [ ] **AC4 story-004 行為不退化**:資訊框原本不在變淡範圍,維持;`hud_layout_test` / story-004 相關測試全綠。
- [ ] **AC5 敏感度證明**(🔴 一個 mutant 一次獨立執行):①底色 alpha 改回舊值 → AC1 紅 ②矩形移回舊位置 → AC2 紅 ③AC2 敵兵清單改空 → 防空洞紅。交付前掃描殘留注入標記。
- [ ] **AC6 像素層待補拍**:960×540、1920×1080 各一張游標停在敵兵;人開圖確認文字不受底下棋盤干擾、無敵兵被遮。依截圖規則判類別。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## 未涵蓋(刻意)

- 其他面板(手牌、提示列、選單)的框統一。
- 資訊卡內容/文案(story-040/042)。
- 空格也顯示地形卡(T10,須先問 story-024 當初決定,未獲核准,不在本批)。

## Affected Files

- `src/ui/battle/battle_screen.gd`(資訊卡面板建構/定位)
- `src/ui/battle/hud_layout.gd`(`info_label_rect` 位置規則)
- 新測試檔:`tests/integration/ui/tile_info_panel_frame_test.gd`
- 既有 `tests/unit/ui/hud_layout_test.gd`(若矩形斷言隨之變動,說明)

超出此清單先問。

## 與其他工單的順序

同動 `battle_screen.gd` / `hud_layout.gd`:043 → 045 → 046 → **048** → 049。與 story-042(只動 CSV)互不衝突。

> 📌 **2026-11-12 加註**(管理者 2026-11-12 核准加註(選項「三張新工單補 UX 實拍發現」;紀錄 `production/session-state/active.md` 第九十九批節)):依 `docs/reviews/screen-readability-verified-ux-addendum-2026-11-12.md`:M7 —— 選牌時資訊卡與敵兵叉框重疊,字被框線切過,須加驗收;M3 —— 驗收解析度須含 960×540、1920×1080、2560×1440。
