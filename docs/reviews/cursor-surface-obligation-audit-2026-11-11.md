# 游標表面註冊義務稽核(D3 / AC-51)— 2026-11-11

唯讀稽核,未改任何程式。依據:`design/gdd/cursor-highlight-state.md` 的 Core Rules #7「表面卸載前的目標交接義務」與 AC-51
(卸載前必須呼叫「標記目前目標為待重新解析」或「設定新目標」)。全部為讀檔 + grep,**非 (A) 級**(未跑引擎)。
列舉位置:`src/ui/cursor/cursor_types.gd` 的 `enum SurfaceType { BOARD_TILE, RELATION_MINIMAP_NODE, CARD_SLOT, DIALOGUE_CHOICE }`,共 4 種。

| 表面型別 | 註冊處 | 卸載/交接處 | 符合 AC-51 | 證據原始行 | 風險 |
|---|---|---|---|---|---|
| BOARD_TILE | `battle_screen.gd` `_ready()` 註冊;手牌開關/確認出牌/取消另有 4 處註銷後重註冊 | `battle_screen.gd` `_on_tree_exited_cursor_handoff()`(`tree_exited.connect` 於 `_ready` 內):目標屬本表面則 `mark_pending_reresolve`,再 `unregister_surface` | 符合 | `CursorStateHost.mark_pending_reresolve(current)` / `CursorStateHost.unregister_surface(CursorTypes.SurfaceType.BOARD_TILE)` | 低。守衛看「目標的表面型別」而非「誰註冊」,手牌開啟中(BOARD_TILE 暫時註銷)離場也涵蓋 |
| DIALOGUE_CHOICE | `support_conversation_screen.gd` `_register_cursor_surface()`,並以 `handoff_after_mount` 播種初始目標 | 同檔 `_on_tree_exited_cursor_handoff()`(`tree_exited.connect` 於 `_ready` 附近):同樣先 mark 再 unregister | 符合 | `CursorStateHost.mark_pending_reresolve(current)` / `CursorStateHost.unregister_surface(CursorTypes.SurfaceType.DIALOGUE_CHOICE)` | 低 |
| RELATION_MINIMAP_NODE | 無(`src/` 零註冊) | 不適用 | 不適用(類別 ①:介面不可聚焦) | `design/ux/relation-minimap.md` 第 6 節:「2026-10-28 管理者裁決:本節不實作(EPIC 裁決 5『維持純顯示,不做地圖游標』)」;`production/epics/relation-minimap/EPIC.md` story 002 列「取消(管理者裁決 5)」 | 無。這是明文裁決,非疏漏 |
| CARD_SLOT | 無(`src/` 零註冊) | 不適用 | 目前不適用,但**需裁決確認**(類別 ①/②交界) | `hand_bar.gd` 用自己的私有 `_cursor_index`(`diagnostic_cursor_index()`)管手牌焦點,不經游標系統;`battle_screen.gd` 開手牌時刻意把 BOARD_TILE 註銷、由卡牌出牌路徑接手 | 低~中,見下 |

## 補充查證

- 測試覆蓋卸載交接:
  - BOARD_TILE:`tests/integration/cursor/battle_screen_surface_handoff_test.gd`(含「只註銷不 mark」變異體的敏感度證明)、`tests/integration/ui/battle/battle_screen_surface_handoff_mid_card_play_test.gd`(手牌中離場)。
  - DIALOGUE_CHOICE:`tests/integration/ui/shell/support_conversation_screen_test.gd` 內 `test_sensitivity_proof_no_handoff_leaves_target_valid`(`_MutantNoHandoff`)。
  - 缺口追蹤:`tests/integration/cursor/frame_buffer_ordering_test.gd` 的 `test_gap_relation_minimap_and_card_slot_not_registered_anywhere_in_src_yet`,一旦有人註冊這兩型別就轉紅,會逼人補義務。
- 其他有引用 `CursorStateHost` 的畫面:`title_screen.gd`、`settings_screen.gd`(檔頭明文不註冊任何表面);`battle_menu.gd` 只用 `suspend_arbitration`/`resume_arbitration`,不註冊表面。
- 注意:本稽核未逐一驗證 `title_screen`/`settings_screen` 的「不註冊」理由是否與 GDD 一致,只確認 `src/` 確實無註冊呼叫。

## 結論

- **缺陷數:0**。上午盤點的兩項「無註冊」皆非 AC-51 違反:RELATION_MINIMAP_NODE 是管理者明文裁決(類別 ①);DIALOGUE_CHOICE 卸載路徑**確有**呼叫交接介面且有測試(上午盤點「未查」的部分,現已查明為符合)。
- **唯一待確認項(非缺陷,是設計空白)**:CARD_SLOT。列舉成員與門檻設定仍在,但手牌焦點目前由 `HandBar` 私有索引管理,不走游標系統。我**未找到**一份明文裁決說「手牌不使用 CARD_SLOT」(只查了 `card-play-interface` EPIC 與 `design/ux`,可能漏查)。若確屬刻意設計,風險僅是「列舉裡有一個永遠不用的成員、`card_slot_threshold_px` 為死設定」;若日後要讓手牌進游標系統,必須同時補註冊與卸載交接(AC-51),缺口測試會提醒。
- **最小修法**:不需改程式。建議只在 D3 登記表該列加註「2026-11-11 稽核:4 型別 2 符合 / 1 裁決不做 / 1 待確認(CARD_SLOT)」,並請 `ux-designer` 或 `game-designer` 回一句 CARD_SLOT 是否保留。
- **是否需要新工單**:不需要。D3 的持續義務維持現狀(缺口測試已是自動提醒);CARD_SLOT 的去留是一次設計詢問,不是實作工單。
