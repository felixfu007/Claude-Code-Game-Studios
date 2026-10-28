# Story 001:關係圖的開關與繪製

> **Epic**: `production/epics/relation-minimap/EPIC.md`
> **Status**: ✅ **Done-pending-visual(2026-10-28)** —— `0bec6be` + `5ed6c4e`;1554 全綠(協調者重跑)。開啟條件依管理者裁決放寬為我方階段隨時可開。畫面待管理者簽核。原狀態:Ready(2026-10-28)
> **Type**: UI
> **規格權威**: `design/ux/relation-minimap.md` 第 2~5、7 節及對應 AC(游標相關第 6 節屬 story-002)

## 範圍

1. 新增輸入動作 `battle_toggle_relation_map`(鍵盤 R、手把 button 8)到 `project.godot` `[input]` 節(格式照既有動作逐字比照,含 `device` 欄)。
2. 戰鬥畫面上一個可開關的關係圖面板(疊在 UI 層、不暫停棋盤操作;預設關閉)。按鍵切換;**開著時其他輸入照常**。過濾鍵盤 echo。
3. 畫五名我方角色節點(名牌用在地化鍵 `character.name.N`)與**全部**關係線:
   - 生效 → 實線;未生效 → 淡虛線;正/負除顏色外**必須**另有符號差異(例如「+」「−」)。
   - 不顯示強度數字。陣亡角色的節點與線怎麼畫:照規格,規格沒寫就畫灰並在註解標「暫行」。
4. 🔴 **單一來源**:線的正負與生效狀態**必須**取自戰鬥畫面 `_refresh_view()` 裡已經算出來給棋盤連線用的同一份 `line_statuses`(`AffinityRules.board_lines(...)` 的結果),**不得**另外呼叫一次或自己推導。若結構上做不到,停下回報。
5. 版面:面板矩形寫成 `src/ui/battle/hud_layout.gd` 的一支 `relation_minimap_rect()`,不與既有 HUD 矩形重疊、不佔側邊欄位;字級 `HudLayout.font_size()`。
6. 唯讀診斷:`diagnostic_relation_minimap_visible()`、`diagnostic_relation_minimap_lines()`(回傳畫出的線與其狀態)。

## 不在本 story

游標在地圖上移動、`RELATION_MINIMAP_NODE` 登記(story-002)。**本 story 不得登記該表面**(`frame_buffer_ordering_test.gd` 的缺口測試會正確轉紅)。

## Acceptance Criteria

- [ ] 規格 AC 中與開關、繪製、單一來源、非色彩區分、在地化相關的各條(實作者逐條列出對應)。
- [ ] 預設關閉時,戰鬥畫面既有行為與既有測試**逐字不變**。
- [ ] 開著時,移動/確認等棋盤操作照常(測試證明)。
- [ ] 地圖上的線集合與棋盤連線**同一回合、同一游標位置下完全一致**(測試證明)。
- [ ] 敏感度證明門檻。
- 畫面外觀待管理者簽核。

## Affected Files

`project.godot`、`src/ui/battle/battle_screen.gd`、`src/ui/battle/hud_layout.gd`、新檔 `src/ui/battle/relation_minimap.gd`(或同類)、`assets/data/locales/strings.csv`(若需新文字)、`tests/unit/core/i18n/locale_data_integrity_test.gd`(只改列數)、`tests/integration/ui/battle/...`(新)。
