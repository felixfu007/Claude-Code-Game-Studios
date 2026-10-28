# Story 015:戰鬥畫面照規格做游標交接(離開時標待重新解析、開局走 handoff)

> **Epic**: 游標/高亮狀態系統 —— `production/epics/cursor-highlight-state/EPIC.md`
> **Status**: ✅ Done(2026-10-27)—— AC1~AC6 落地;協調者重跑 1414 全綠(commit `fa1dff2`)。原狀態:Ready
> **Layer**: Presentation + Integration
> **Type**: Integration(BLOCKING)
> **Estimate**: S~M
> **裁決依據**:管理者 2026-10-27,逐字選項「**今天開工作單,下次做(推薦)**」(被跳過:現在就做 / 不修登記為已知偏差)。
> 修法為 `technical-director` 意見書推薦的**甲案**:`docs/reviews/cursor-target-on-screen-exit-opinion-2026-10-27.md` 第 3 節。

## 為什麼存在

戰鬥畫面離開時只解除 BOARD_TILE 註冊,**游標目標殘留為「BOARD_TILE/26、有效」**
(實測:`prototypes/cursor-host-isolation-probe-2026-10-27/run_output.txt`)。它違反兩條**已核准**規格:

1. **GDD Core Rules #7「表面卸載前的目標交接義務」/ AC-51** —— 卸載前若目前目標屬於自己,必須
   `mark_pending_reresolve` 或設定新目標,不得直接卸載。
   當場查:`grep -n "表面卸載前的目標交接義務" design/gdd/cursor-highlight-state.md`
2. **ADR-0005 機制十一 2026-09-04 管理者裁決** —— 新開局一律走 `handoff_after_mount()`,不得走 `set_target()`。
   當場查:`grep -n "新開局. 走哪一個入口" docs/architecture/adr-0005-cursor-device-authority-input-architecture.md`

自 2026-10-19 有了「離開戰鬥回標題」(`src/ui/shell/scene_router.gd`),兩條規格預想的情境才真的發生。
**玩家目前幾乎不受影響**(意見書第 2 節:標題/設定期間零讀取者),但之後每個新表面會照抄同樣的漏洞。

## Acceptance Criteria

- **AC1**:`CursorStateHost` 補 `mark_pending_reresolve(expected)` 與 `handoff_after_mount(...)` 兩個**一行轉手**入口
  (形狀依 ADR「全部公開 API 為對 `_state` 的一行轉發」;不得加任何判斷邏輯 —— `logic_in_cursor_autoload_shell` 禁令)。
- **AC2**:戰鬥畫面離開時:若目前目標表面為 BOARD_TILE,先 `mark_pending_reresolve(目前目標)` 再解除註冊;
  回傳值必須檢查,非成功時 `push_error`,不得吞掉。
- **AC3**:戰鬥畫面開局播種改走 `handoff_after_mount()`。
- **AC4**:新整合測試:戰鬥畫面移除後 `CursorStateHost.is_current_target_valid() == false`(**當作日後新表面的範本**,檔頭寫明)。
- **AC5**:全套零迴歸;開局重置觸發點由 `TARGET_CHANGED` 變 `SURFACE_HANDOFF` 造成的既有測試變動,逐條列理由
  (起點:`grep -rln "reclaim_reset_triggered\|TARGET_CHANGED" tests`)。
- **AC6**:`tests/helpers/cursor_host_snapshot.gd` 與收尾檢查**保留不拆**(意見書第 4 節:修好後目標仍會殘留為「26/無效」)。

## 需另行請管理者核准(文件)

- ADR-0005 Key Interfaces 現寫「刻意不加 `mark_pending_reresolve`…U-013 目前不需要」—— 需補一行**事實層加註**(零決策變更)。
- `docs/tech-debt-register.md` 那條 AC-51「持續義務」下註明:戰鬥畫面已補,下一個表面要照做。

## Affected Files

`src/ui/cursor/cursor_state_host.gd`、`src/ui/battle/battle_screen.gd`、`tests/` 底下相關與新增測試。

## ✅ 2026-10-27 交付紀錄

`godot-gdscript-specialist`;協調者獨立重跑:`ENGINE EXIT = 0` / `1414 test cases | 0 errors | 0 failures | 0 orphans` / `(130/130)`。
- 既有測試**零修改**(開局重置觸發點改為 SURFACE_HANDOFF 後,相關 4 檔照舊通過;實作者明言未逐檔讀,不主張原因)。
- ⚠️ 未涵蓋:**出牌中途離開戰鬥**沒有專屬測試(守衛只看目標表面類型;全套未出現新增的 push_error)。
  ✅ **2026-10-28 部分補上**:出牌第 1 步(選牌中)與第 2 步(選目標中)離開戰鬥已有專屬測試(`tests/integration/ui/battle/battle_screen_surface_handoff_mid_card_play_test.gd`,含常駐變種,commit `b2bc057`)。**確認面板中與敵方回合中離開仍未涵蓋。**
- ADR-0005 Key Interfaces 與 tech-debt-register 的加註已於同日經管理者核准套用。
