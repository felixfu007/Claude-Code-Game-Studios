# 意見書:戰鬥畫面離開時游標目標殘留的根源判斷(2026-10-27,technical-director)

> 狀態:完成。唯讀分析,本輪未修改任何既有檔,未執行引擎。
> 來源等級:**[讀]** = 讀了程式/規格原文,附 grep 指令可自行重跑;**[推論]** = 未經執行驗證。

## 給管理者的白話摘要

**玩家現在會不會遇到問題?幾乎不會。** 離開戰鬥後留下的「游標還指著第 26 格、而且標記為有效」
這筆舊資料,在標題畫面和設定畫面期間**沒有任何程式拿它來畫東西或做判斷**;
下一場戰鬥開局時,正常情況下會被新的開局位置蓋掉。只有兩種很少見的情況會讓舊值漏進新戰鬥
(該場沒有我方單位、或開局註冊失敗),而這兩種本身就已經是會報錯的故障。

**但它確實違反了已核准的規格,而且違反了兩條,不是一條:**
1. 規格明文規定:畫面關閉前,若游標正指著自己,**必須先把游標標成「暫時無效」**(或交給下一個畫面)。
   戰鬥畫面沒做。
2. 規格明文規定(2026-09-04 管理者裁決):**每次進入戰鬥設定開局游標,必須走「無條件重置」的那個入口**,
   理由正是「玩家回標題再開新局時,開局格很可能跟上次一樣,走另一個入口會漏掉重置」。
   戰鬥畫面走的是另一個入口。**當時這個情境還不存在;自 10-19 有了「回標題」之後它就存在了。**

**要不要修?建議修,範圍小。** 改戰鬥畫面兩行呼叫、在游標總管補兩個「一行轉手」的入口,
**不改任何已核准的規則**,所以**不需要您做規則層的裁決**,只需要您同意開一張工作單。
今天測試端加的「存檔/還原」防線**要保留**,理由見第 4 節。

## 1. 規格要求的行為 —— 有寫,現行程式違反

**[讀]** GDD Core Rules #7「表面卸載前的目標交接義務」逐字:任一表面卸載前若「目前游標目標的表面類型標籤等於自己的類型」,
**必須**執行 (a)「標記目前目標為待重新解析」或 (b)「設定新目標」之一,「**不得直接卸載而不呼叫任一介面**」。
驗收條款 AC-51 同義。
`grep -n "表面卸載前的目標交接義務" design/gdd/cursor-highlight-state.md`(第 95 行規則、第 322 行 AC-51)

**[讀]** 戰鬥畫面離開時只做一件事:
`grep -n "tree_exited.connect" src/ui/battle/battle_screen.gd` → 只呼叫 `unregister_surface(BOARD_TILE)`。
→ **違反 Core Rules #7 / AC-51。不是規格缺口。**

**[讀]** 這條義務早已登記為「持續義務」、當時下游表面是空集合:
`grep -n "AC-51 的「每個下游表面」目前是空集合" docs/tech-debt-register.md`
戰鬥畫面是**第一個**真正會卸載的下游表面,而它上線時沒有回頭對這條。

**[讀]** 第二項違反(題目沒問到,但同一處):ADR-0005 機制十一「`新開局` 走哪一個入口」2026-09-04 裁決 ——
新開局一律 `handoff_after_mount()`,不得走 `set_target()`。
`grep -n "新開局. 走哪一個入口" docs/architecture/adr-0005-cursor-device-authority-input-architecture.md`
戰鬥畫面開局播種用的是 `set_target()`:`grep -n "CursorStateHost.set_target(" src/ui/battle/battle_screen.gd`
該裁決當時寫「今天沒有任何生產程式碼在遵守它,因為還不存在新開局流程」——**流程後來出現了,沒有人回來接。**

## 2. 正式遊戲現在有沒有受影響 —— 標題/設定期間沒有讀取者

**[讀]** 殘留值與開機基線的差別只在 `id`(26 vs 0)與 `is_valid`(true vs false);**表面類型兩者都是 BOARD_TILE**
(`grep ISOPROBE prototypes/cursor-host-isolation-probe-2026-10-27/run_output.txt`)。所以只有讀 `id`/`is_valid` 的地方才會被影響。

逐一列出全部讀取點:

| 讀取點 | 讀什麼 | 標題/設定期間會不會跑 | 受殘留影響? |
|---|---|---|---|
| `CursorState.arbitrate_device_authority`(每幀) | 只讀 `_target.surface` 查奪權門檻 | 會 | **否** —— 表面同為 BOARD_TILE,與基線行為相同 |
| `CursorState.apply_buffered_navigation` | `_target.surface` 查註冊表 | 會(鍵盤權威+方向鍵時) | **否** —— BOARD_TILE 未註冊,與基線走同一個報錯分支 |
| `SelfDrawnReclaimCursor._process` | 只讀 `reclaim_progress()` | 會 | **否** —— 不讀目標 |
| `NativePointerVisibilityArbiter._process` | 只讀裝置權威 + 懸停例外 | 會 | **否** —— 不讀目標 |
| `battle_screen.gd`(4 處讀目標) | `get_current_target` / `is_current_target_valid` | **不會**,畫面已不在樹上 | — |
| `title_screen.gd` / `settings_screen.gd` | 全文只在註解提到 `CursorStateHost` | — | **否** |
| `target_changed` 訊號訂閱者 | — | src 內**零**訂閱者 | — |

重跑指令:
```
grep -rn "get_current_target()\|is_current_target_valid()" src --include=*.gd | grep -v "src/ui/cursor/"
grep -n "_target" src/ui/cursor/cursor_state.gd          # 看 arbitrate/apply 兩處只讀 .surface/.id
grep -n "_state\." src/ui/cursor/self_drawn_reclaim_cursor.gd src/ui/cursor/native_pointer_visibility_arbiter.gd
grep -rn "target_changed\.connect" src --include=*.gd     # 0 筆
```

**下一場開局會不會一定覆蓋?** **[讀]** 開局順序是先註冊、再 `set_target`。`set_target` 只有四種拒絕:
重入、null、表面值越界、表面未註冊。前三種在開局路徑上不會發生;第四種只在註冊失敗時發生,
而切場景器刻意「先同步移除舊畫面、再加新畫面」以避免重複註冊被拒
(`grep -n "交換順序刻意為" src/ui/shell/scene_router.gd`;⚠️ 該檔自己標註反向順序**未實測**)。
**兩個不會覆蓋的情況** **[讀]**:①`if not player_ids.is_empty()` —— 我方零單位時根本不播種;
②註冊失敗時 `set_target` 回 `SURFACE_NOT_REGISTERED`,只 `push_error`,殘留值留在總管裡,
之後戰鬥畫面的 4 處讀取會讀到**上一場的格號且標為有效**。兩者都已是有報錯的故障情境。

**一個安靜的次要效應** **[推論]**:殘留值是 `BOARD_TILE/26/有效`;若新一場開局格恰好也是 26,
`set_target` 的「有變才重置」判斷會判為**沒變**,跳過滑鼠奪權累積量的重置 —— 這正是第 1 節第二項裁決預言的那個 bug。
玩家感受上是「鍵盤操作後,要把滑鼠拉回控制權的距離,在新戰鬥第一下可能略長或略短」。影響輕微、未實測。
依據:`grep -n "func _target_changed_from" -A4 src/ui/cursor/cursor_state.gd`(比對表面+id+有效性)。

## 3. 修法選項

| | 甲(推薦):在戰鬥畫面照規格做交接 | 乙:游標總管在解除註冊時自動失效 | 丙:不修,登記為已知偏差 |
|---|---|---|---|
| 改哪裡 | `battle_screen.gd`:離開時若目前目標是 BOARD_TILE,先 `mark_pending_reresolve(目前目標)` 再解除註冊;開局播種改走 `handoff_after_mount()`。`cursor_state_host.gd`:補這兩個方法的一行轉手 | `CursorState` 新增「解除註冊連帶失效」邏輯,或把解除註冊收進 `CursorState` | 無程式改動;更新技術債登記 |
| 碰不碰已核准語意 | **不碰**。兩個呼叫都是規格要求的;轉手入口的形狀已由 ADR 明訂(「全部公開 API 為對 _state 的一行轉發」),2026-09-22 有同形狀前例。需在 ADR Key Interfaces 補一行事實層加註(該處現寫「刻意不加 mark_pending_reresolve…U-013 目前不需要」) | **碰**。改變機制三註冊表契約;且總管被禁止含判斷邏輯(`logic_in_cursor_autoload_shell`) | 不碰 |
| 需要管理者裁決? | **不需規則裁決**;需同意開工作單 + 同意 ADR 加註(文件,依規須先問) | **需要**。且觸及「同一文件不做第三次以上修訂」—— 見下 | 需要(接受違反已核准驗收條款) |
| 影響的既有測試 **[推論]** | 開局重置觸發點由 `TARGET_CHANGED` 變 `SURFACE_HANDOFF`:須跑全套確認;`grep -rln "reclaim_reset_triggered\|TARGET_CHANGED" tests` 是起點。新增一條整合測試:戰鬥畫面移除後 `is_current_target_valid()==false` | **大量**。見風險欄 | 無 |
| 風險 | 小。`mark_pending_reresolve` 須在離開回呼裡處理回傳值(重入時回 `REJECTED_REENTRANT`,要 `push_error` 不可吞) | 🔴 **[讀] 戰鬥畫面在戰鬥中會反覆解除/重新註冊 BOARD_TILE**(開手牌、選目標、確認出牌:戰鬥中解除 3 處、重新註冊 4 處,不含開局與離開;`grep -n "CursorStateHost.unregister_surface(\|CursorStateHost.register_surface(" src/ui/battle/battle_screen.gd`,命中含報錯字串行,須人工剔除)。自動失效會讓每次開手牌都把游標打成無效 —— 改變現有玩法行為 | 未來每個新表面(關係圖、支援對話)會照抄同樣的漏洞;AC-51 持續為假 |

**為什麼乙會觸發修訂次數規則** **[讀+推論]**:ADR-0005 已有四次正式修訂(皆在劑量規則前),
規則生效後又有多次帶管理者裁決的改動(2026-09-04 新開局入口、09-07 刪參數、09-15 刪兩方法),
`git log --oneline -- docs/architecture/adr-0005-cursor-device-authority-input-architecture.md | wc -l` → 23 次提交。
劑量規則寫「只往後生效、不追改既有 5 份」,但 ADR-0001 的先例是把生效後的決策層改動算進次數。
**我的判斷:對 ADR-0005 任何決策層改動,都已落在「第三次以上」的灰區**,依規則 4 正確動作是重寫或擱置,
不是再補一次 —— 這是不選乙的第二個理由。甲不改決策,不落入此規則。

**推薦甲。** 它只是讓戰鬥畫面照已核准的兩條規格做事;乙的「結構保證」聽起來更好,
但這個註冊表在本專案被當作戰鬥中的開關使用,自動失效會打到正確行為。
甲的已知弱點:**AC-51 仍靠每個新表面自己記得做** —— 建議在工作單裡加一條整合測試當範本,
並在技術債登記那條「持續義務」下註明戰鬥畫面已補、下一個表面要照做。

## 4. 測試端「存檔/還原」防線:保留,不要拆

**[讀]** 它還原的不只目標:還有裝置權威、暫停旗標、輸入緩衝、註冊表、例外白名單、樹暫停
(`grep -n "snap\._" tests/helpers/cursor_host_snapshot.gd`)。根源修好後,其中**裝置權威跨畫面延續是設計本意**,
仍會在測試之間流動,所以這道防線的大部分理由不受影響。

**[讀]** 修好後目標也不會回到基線:規格明文「標記待重新解析**不清空座標值**」,
殘留會從 `BOARD_TILE/26/有效` 變成 `BOARD_TILE/26/無效`。收尾檢查
`tests/integration/zz_cursor_host_final_state_test.gd` 的判準是 `id != 0` 即算殘留
(`grep -n "tgt.id != 0" tests/integration/zz_cursor_host_final_state_test.gd`),**仍會判為殘留**。
→ 存檔/還原與收尾檢查都要留。收尾檢查的判準**不需要改**:有存檔/還原時它本來就應該是乾淨的。

## 未涵蓋 / 未驗證

- 未執行任何引擎探針;第 2 節「次要效應」與第 3 節「影響的既有測試」皆為推論。
- 未檢查 `handoff_after_mount()` 改用後,戰鬥畫面讀回 `_cursor_cell` 的那段是否有依賴 `TARGET_CHANGED` 的測試間接斷言。
- 旁註 **[推論]**:標題畫面用方向鍵移動按鈕焦點時,`apply_buffered_navigation` 可能走「表面不支援導覽」報錯分支一次(每次程式執行一次)。
  與本殘留無關(開機基線也一樣),未實測,值得另外確認是不是噪音錯誤。
