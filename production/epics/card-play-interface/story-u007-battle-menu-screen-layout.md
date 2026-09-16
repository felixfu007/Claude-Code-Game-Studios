# Story U-007: 戰鬥選單畫面 —— M0~M2 版面、原生 focus、上下導覽不繞回

> **Epic**: 卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **狀態**: 📋 Ready
> **層**: Presentation(戰鬥選單,新畫面)
> **型別**: UI
> **估時**: M
> **依賴**: U-005、U-006
> **解鎖**: U-008、U-010(後者不在本次 8 個單元授權範圍內)
> **波次**: 波 2(與 U-011 ∥ 真平行 —— `battle_menu.gd`(新)vs `hand_bar.gd`(新),U-011
>   不在本次 8 個單元授權範圍內)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)

## Context

**權威來源**:`design/ux/battle-menu.md` 全文(Layout Specification / Component Inventory /
ASCII Wireframe / Interaction Map / States & Variants 各節)。

**Governing ADR**:ADR-0005(**Accepted**)—— AC-60 明文未登記表面**可以**使用引擎原生
Control focus/hover(機制十四原本禁止已登記表面這樣做,但本畫面刻意不登記進游標系統,
見 `battle-menu.md`「焦點視覺」節)。

## 目標

建出戰鬥選單畫面(M0 遮罩、M1 選單面板、M2 項目列)的版面與焦點導覽行為:三個項目
(回到遊戲/結束回合/離開遊戲)、引擎原生 focus 視覺、上下導覽不繞回(從第一列按「↑」
不會繞到最後一列)。做完之後,選單「長什麼樣子、怎麼用方向鍵走」第一次存在,但**不含**
開關閘控邏輯(`SceneTree.paused`、`suspend_arbitration()`——那是 U-008)、不含「結束回合」
列的實際功能(U-009,不在本次授權範圍)、不含離開確認 M4(U-010,同樣不在本次授權範圍)。

## 🔴 本 story 決定的原始碼目錄路徑

EPIC.md 第二節單元清單表已列出落點,本節把它明文複述在這裡——**`battle_menu.gd` /
`battle_menu.tscn` 是本 epic 要新建的檔案,不是既有檔案,實作者沒有既有檔可以「照著找」,
story 是他唯一會讀的東西,故落點不能只留在 EPIC.md 那張表裡。**

- **新建**:`src/ui/menu/battle_menu.gd`(腳本本體,`class_name` 由實作時依專案 PascalCase
  慣例定案,建議 `BattleMenu`)
- **新建**:`src/ui/menu/battle_menu.tscn`(場景檔,根節點掛上述腳本)

⚠️ **本 story 只建立這兩個檔案本身與 M0~M2 的版面/導覽**——U-008 會**累加**修改
`battle_menu.gd`(閘控邏輯),U-009/U-010(不在本次授權範圍)之後也會繼續累加同一個檔案。
本 story 是這兩個檔案第一次被建立,不是最後一次被修改。

## Implementation Notes

1. **版面尺寸**:`fpx = HudLayout.font_size(window_size)` 的倍數,錨定
   `HudLayout.safe_rect(window_size)`——**不得自行重刻**這兩個函式的公式
   (`.claude/docs/technical-preferences.md` 已登記的失效模式:「同一條公式兩份實作,
   只是今天答案一致」)。M0 遮罩覆蓋**整個視窗**(非安全區,`battle-menu.md` 明文:
   兩種常見螢幕邊區為零,但 2K/超寬有留白,遮罩若只蓋安全區,那圈留白會亮著);M1
   選單面板寬 `10 fpx`、高 `9 fpx`,安全區正中;M2 項目列每列高 `2 fpx`。

2. 🔴 **本檔的版面驗算表自陳是 (C) 級,落地前須複驗並附檔案路徑(EPIC.md 陷阱十二,
   轉錄)**:

   > `battle-menu.md` 的四螢幕 × 三字級表格下方逐字寫著:上表為算術、非實機量測,依
   > (A) 級定義為 **(C) 級**(它重新實作了 `HudLayout.font_size()` 與 `safe_rect()`
   > 各一條規則),**排版落地前須以呼叫這兩個函式的拋棄式測試複驗並附檔案路徑。**
   >
   > **U-007 有這個義務。** 依 `.claude/docs/technical-preferences.md`,**沒有附檔案
   > 路徑的「(A) 級」一律降為 (C)。**

   **本 story 落地時**,必須實際呼叫 `HudLayout.font_size()` 與 `HudLayout.safe_rect()`
   (不得重新推導這兩條公式)驗證 `battle-menu.md` 表格裡列的四種螢幕 × 三字級尺寸,並在
   commit / doc comment 裡附上執行這次複驗的檔案路徑(拋棄式測試或正式測試皆可),否則
   不得在任何地方宣稱這是 (A) 級驗證過的版面。

3. **上下導覽的兩條裁決(2026-09-10 管理者裁決,`battle-menu.md` 原文轉錄)**:

   > 🔴 **① 不可選項目——游標跳過,原因文字常駐。** 上下導覽**跳過**不可選的「結束回合」列
   > (玩家不會停在一個按不動的東西上);而 M3 的原因文字**不因焦點離開就消失**,全程可讀。
   >
   > 🔴 **② 上下導覽不繞回,到底停住。** 從「回到遊戲」按「↑」**不會**繞到「離開遊戲」。
   > **理由**:預設焦點在第一列、「離開遊戲」刻意排在最後一列並加分隔線(`P-M4` 破壞性
   > 項目不得與高頻項目相鄰),繞回會讓這段刻意拉開的距離變成一個按鍵——直接抵銷本畫面
   > 存在的理由。

   ⚠️ **兩者皆為設計決策,不是引擎預設的直接產物。** `focus_mode` / `disabled` 的實際
   行為本專案從未量測過;本 story 必須**驗證**所選的 Godot 4.7.1 節點設定確實產生「跳過
   不可選項」與「到底停住」兩種效果,而非假設某個屬性組合自動具備。

   📌 **本 story 只交付「上下導覽不繞回」(第②點)**——第①點(跳過不可選的「結束回合」
   列 + M3 原因文字常駐)需要「結束回合是否可選」這個判斷式(AC-M5,由 U-009 提供,
   不在本次授權範圍),**本 story 只需要保證版面與導覽結構支援這個行為之後可以接上**,
   不need 在本 story 就讓「結束回合」列真的會被跳過(因為現在它恆為可選,U-009 落地前
   沒有「不可選」這個狀態可跳)。

4. **焦點視覺:本畫面可以用引擎原生 focus,這是明文豁免**(`battle-menu.md`,轉錄):

   > ADR-0005 機制十四禁止使用引擎原生 Control focus/hover——**但那條只約束已登記
   > 表面。** 游標 GDD 的 AC-60 明文:**未登記表面不受管轄,可照常使用引擎原生
   > focus/hover。** 因此本畫面的焦點視覺由自身的 Godot 原生實作負責,不接游標狀態源。
   > ⚠️ **但仍受兩條全域約束**:①**禁止 hover-only**(主機無游標);②**焦點視覺不得
   > 只靠顏色**(`P-F3` 無例外)——須有位置標記(`▸`)或外框等第二通道。

5. **排除清單:三件有理由不放的東西**(`battle-menu.md`,轉錄,供實作者不要誤加)——
   存檔(2026-09-08 管理者裁決:戰鬥中不可手動存檔,永久排除)、讀檔(存檔系統尚未
   實作)、設定/改鍵(設定畫面不存在,見 Open Questions BM-4)。**本 story 不得加入
   任何這三類入口的視覺佔位**,理由已由上游文件明文交代,不是「還沒做」。

6. ⚠️ **陷阱十四:截圖證據規則第 4 點不適用本畫面(EPIC.md,轉錄)**:

   > `coding-standards.md` 的截圖規則第 4 點(像素完美整數縮放網格)逐字警告**只量
   > 世界層**——整張量會判反,因為本作刻意用一般中文字型而非像素字型,抗鋸齒文字在真實
   > 畫面產生的網格違規比啟動畫面還多(3.157% vs 1.748%)。**本畫面全部在介面層**,
   > 第 4 點對它不成立。

   **本 story 的截圖/灰階驗收(AC-M10、AC-M11)只需套用截圖證據規則的第 1~3、5 點**
   (尺寸、多點取樣、主色佔比、人工開圖確認),**不需要**(也不應該)套用第 4 點的
   整數縮放網格檢查。

## Acceptance Criteria

*以下為 `design/ux/battle-menu.md` 的條文原文轉錄,未改寫:*

- **AC-M10**:四種螢幕 × 字級 75% / 100% / 150% 共 **12 組** → M1 與 M4 完整落在安全區內;
  **M0 覆蓋整個視窗,四周無亮邊** | UI | **BLOCKING**
  ⚠️ **部分涵蓋**——只能驗 100% 檔的 4 組,75%/150% 字級功能未實作(UX-5/BM-6,無障礙檔
  登記 `Not Started`)。**M4(離開確認)本身不在本 story 範圍**(屬 U-010),本 story 對
  M4 的驗證僅限「版面尺寸表格裡 M4 那一欄的算術有沒有複驗過」,不含 M4 的實際功能。
- **AC-M11**:焦點與不可選狀態的截圖**轉為灰階** → 仍可區分 | UI | **BLOCKING**(`P-F3`)
  📌 「不可選」狀態要到 U-009 才有真實觸發條件,本 story 驗證的是「焦點視覺」半部
  (`▸` 標記 + 外框在灰階下仍可辨識);「不可選」半部由 U-009 落地後補驗。
- **AC-M13**:焦點在「回到遊戲」(第一列)→ 按「↑」→ 焦點**維持在「回到遊戲」**,**不繞到
  「離開遊戲」** | UI | **BLOCKING**
- **AC-M15**:按 `battle_menu` → **M1 完全可讀 ≤ 200ms** | UI | ADVISORY——與
  `skill-card-play.md` 的 AC-U2 同一效能基準,兩份同批交付(U-012 那一半不在本次授權
  範圍,本 story 只驗證選單自己這一半)

## Test Evidence

**型別**:UI
**測試檔/證據**:
- `tests/unit/ui/menu/battle_menu_layout_test.gd`(headless 可驗的半部:節點結構、
  `focus_mode` 設定、上下導覽不繞回的邏輯層驗證——依陷阱十三通則,「決定」與「套用」
  拆兩個斷言)
- `production/qa/evidence/battle-menu-layout-evidence.md`(截圖 + 人工開圖確認,依
  `coding-standards.md` 截圖規則第 1/2/3/5 點,不套用第 4 點)
- 版面驗算複驗:一支呼叫 `HudLayout.font_size()`/`HudLayout.safe_rect()` 的拋棄式測試
  (`prototypes/` 或 `tests/` 皆可,實作時決定,但**必須**在 story 完成時附上執行它的
  檔案路徑,見第 2 點)

預期涵蓋:
- `test_menu_panel_uses_hud_layout_font_size_and_safe_rect_not_recomputed`
- `test_focus_starts_on_return_to_battle_row`
- `test_pressing_up_on_first_row_does_not_wrap_to_last_row`(AC-M13)
- `test_focus_visual_has_position_marker_not_color_only`(P-F3)
- `test_m1_grayscale_screenshot_focus_still_distinguishable`(AC-M11,焦點半部)

## Out of Scope

- **`SceneTree.paused`、`suspend_arbitration()`/`resume_arbitration()` 的呼叫**——屬 U-008
- **「結束回合」列的實際判斷式與共用邏輯**(AC-M5)——屬 U-009,不在本次授權範圍
- **離開確認 M4 的完整功能**(預設焦點在取消、連按兩次不關遊戲)——屬 U-010,不在本次
  授權範圍;本 story 只涵蓋 M4 的版面尺寸驗算義務
- **不可選狀態的灰階驗收後半段**(AC-M11 的「不可選」部分)——需 U-009 落地後補驗
- **75%/150% 字級檔位**——功能不存在(UX-5/BM-6),本 story 只驗 100% 檔

## Dependencies

- 依賴:U-005(`battle_menu` 動作已註冊)、U-006(游標宿主暫停排除已就緒,雖然本 story
  本身不觸發暫停,但依波次規劃需等 U-006 完成)
- 解鎖:U-008(選單開關閘控需要本 story 交付的畫面本體)、U-010(不在本次授權範圍)
