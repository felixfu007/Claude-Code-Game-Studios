# Story Index — Epic: 戰棋移動與交戰系統(#4 Tactical Combat)

> 本檔是寫作進度的落地清單,先於逐張 story 內容寫出,供任何一次寫作中斷後的接手依據。
> 完成後仍保留(不刪除)作為 story 檔全集的目錄,但 EPIC.md 的「## Stories」表才是正式狀態欄。

## 🔴 story-003b 插隊說明(2026-09-30 管理者裁決)

`story-003` 完成時誠實登記了一個阻擋項:ADR-0001 要求的「版本號 + 寫入守衛」機制
(機制一/機制二五條硬性義務)在全專案一行都沒有,story-003 只做了自己那一個查詢
用得到的最小一塊(`combat_state_version` 本體 + `move_unit()`/`resolve_attack()`
兩處遞增)。而 004~007 四張 story 全部標「受 ADR-0001 管轄」,卻沒有任何一張負責
把機制本身做出來——每張都只寫「遵守 ADR-0001」。

**管理者裁決**:插入 `story-003b`,由 `gameplay-programmer` 把三個類別(`BattleState`/
`TurnOrder`/`Board`)八個以上方法的遞增、寫入守衛、佔位改動收進單一入口一次做齊,
**排在 004~007 之前**。代價是知情接受的:多一張工作單的時間,且會動到
`board.gd`/`turn_order.gd`/`battle_state.gd`(**`lead-programmer` 切 story 時
grep 查證發現實際還會動到 `battle_controller.gd`/`battle_loop.gd`,見該 story 檔
「與管理者裁決的落差」節,已在該 story 內明確標註,非本索引擅自擴大範圍**),
期間不能並行其他戰棋工作單。

詳見 `story-003b-atomicity-write-guard-consolidation.md`。


## 🔴 story-016 切出說明(2026-10-05 管理者裁決)

**為什麼現在切**:`docs/architecture/tr-registry.yaml` 的 `TR-tactical-002` requirement 逐字含
「**並有載入時驗證**」,而此前 16 張工作單無一涵蓋它 —— `docs/architecture/traceability-index.md`
上該條目前標 `❌ 缺口`。當場查:

```bash
grep -rn "載入時驗證" production/epics/tactical-combat/   # 切出前:唯一命中是 story-001 內引述舊版需求文字
```

**實測到的具體後果**(協調者 2026-10-05 自跑,非轉述):`src/gameplay/board/board.gd` 的
`get_move_cost()` 查到未登記地形字元時回傳哨兵 `MOVE_COST_UNKNOWN_TERRAIN = -1`,而
**全專案零個檢查點** —— 唯一真正的呼叫端把它直接加進 `candidate_cost`。在
`ignore_passability=true` 的路徑下(story-002 新增的開關),`passable()` 閘門被短路跳過,
走過一格未登記地形的移動成本**不減反增**。現在不會真的發生,因為地形檔都在版控、內容可控。

🔴 **範圍只涵蓋地形那一半。** 武器資料表(`TR-tactical-005`)**刻意排除**,理由已實測:
`grep -rln "weapon" src/ --include=*.gd` 只命中 `combat_rules.gd` 的文件註解、
`find assets/data -iname "*weapon*"` 零輸出 —— **武器尚未成為被載入的資料檔**,現在為它寫驗證
是對不存在的東西立法。`traceability-index.md` 的 `TR-tactical-005` ❌ 缺口**不會**因本 story 關閉。

🔴 **排程阻擋(尚未裁決)**:本 story 與 `story-003b` **同時修改 `src/gameplay/board/board.gd`**
(兩者改的函式不同、邏輯無關,純粹是同檔案衝突)。繼承 003b 既有的「動工期間不得並行其他
戰棋工作單」限制。**先後順序由排程擁有者裁決,`lead-programmer` 明文未代為決定。**

📌 **兩項本 story 未代為宣告的下游動作**:①`TR-tactical-002` 能否轉綠由 `technical-director`
判定(EPIC.md C5 既有指派);②`story-007` 是否正式依賴本 story —— 兩者技術上確實關聯
(007 用 `ignore_passability=true` 算 `C` 集合,正是本 story 要修的那條路徑),但排程裁決屬
`producer`/`technical-director`。

## 🔴 story-003c / story-017 拆分說明(2026-10-05 管理者裁決)

### 為什麼拆

`story-003b` 當天從 **348 行 / 9 條 AC / 5 條寫入路徑**長到 **564 行 / 12 條 AC / 8 條路徑**
(`technical-director` 裁決巢狀語意時撞到第七條;`lead-programmer` 併入時再找到第八條)。
交接檔早已登記它「實質工作量明顯大於前三張、**沒有人估過工時**、要不要再拆是一次尚未進行的判斷」。

**管理者看到的選項描述逐字如下,他是照這個選的**:

> 這是唯一真的切得開的地方 —— 核心半(計數器 + 守衛 + 15 個呼叫點改道)必須同一次落地,
> 否則守衛一掛上去沒改道的呼叫點全部被擋;而⑥⑦ 是純追加的包裝、不動守衛。
> **缺點(他知情)**:多一張工作單要管;而且⑥(回合轉換)今天就會真的改到攻防值,
> 拆出去就是多一段「機制做好了但這條路徑還漏著」的時間窗。

`story-017`(`Unit` setter)則是 ADR-0001 **硬性義務第 2 條**,`story-003b` 刻意排除並寫
「建議下一次 `technical-director` 裁決」,而 `technical-director` 2026-10-05 自己回報
**「兩輪下來都沒排進我的交付物,這是目前唯一還掛在我名下、沒有人接手的項目」**。管理者裁決另切一張。

### ⚠️ 拆分的代價:`story-003b` 這個**檔案**沒有變小,變小的是它的**範圍**

依本專案「原文一個字都不要刪」的紀律,搬走的段落**原處全部保留並逐段加註**,所以該檔
從 564 行變成 **633 行**。**實作者讀到的是一份 633 行、其中數段標著「已搬至」的文件。**
當場查加註位置(**用實體名搜,不要用想像的措辭** —— 協調者本批就因此誤判過一次):

```bash
grep -n "003c" production/epics/tactical-combat/story-003b-atomicity-write-guard-consolidation.md
```

### AC11 的歸屬:留在 `story-003b`,**這是 `lead-programmer` 的裁決,未經管理者覆核**

管理者對此明文「兩邊都說得通,我不代為決定」。`lead-programmer` 裁定留在 003b,理由是
AC11 解答的是 **003b 原始範圍(路徑⑤)就已存在**的開放問題(「未決的實作細節」第 3 項),
路徑⑥⑦ 只是讓它順便有了更清楚的解法。分工是「**003b 負責讓它存在且正確(包住整個函式本體),
003c 負責多驗一條本來不在 003b 驗收範圍內的斷言**」,不是各包一半。

### 🔴 施工序:`016 → 003b → {003c, 017}`

- `016` 與 `003b` **皆動 `board.gd`,不得並行**;管理者裁決 016 先。
- `003c` 與 `017` **皆硬性依賴 003b 先 Done**(需要 `commit_authoritative_change()` /
  守衛介面 / `_finalize_enemy_phase()` 既有包裝實際存在)。
- `003c` 與 `017` **互不依賴,003b 完工後可並行派給兩個人**。
- `004`~`007` 的依賴欄**不需要改** —— 它們依賴的是 003b 交付的核心機制,不依賴 003c/017。

### 📌 `lead-programmer` 誠實登記的三個未決項

1. **`story-003c` 的 `battle_loop.gd` 實際改動形狀未知** —— 取決於 003b 完工時 119 行附近的
   實際寫法。`battle_controller.gd` 側預期只需補測試,**`battle_loop.gd` 側預期需要改程式碼**
   (沒有輔助函式可以自然共用一次包裝)。**這個不對稱是 003c 動工第一步要查證的事。**
2. **`story-017` 的 `take_damage()` 相容性處理是二選一未決項**(受守衛約束 / 比照
   `Board.set_occupant()` 繞過守衛)。`lead-programmer` 傾向後者並寫明理由,**未代為裁決**。
3. **`unit.gd` 之外的讀取面未逐一覆核**(`CombatRules` / `CardModifierRules` 對 `atk`/`def`
   的讀取)。理論上 getter 回傳值不變、不受影響,**但未實測**。
## M3 拆分說明(附帶建議 1 的結論)

M3 原五組切面拆為 **M3a**(切面 2/3/4/5,不依賴 M2,可與 M2 同日開工)與 **M3b**(切面 1,
移動範圍四態查詢,依賴 M2 的 `passable`/`ignore_passability` 產出)。理由直接取自 EPIC.md
自己的依賴圖:「只有 M3 的切面 1……真的等 M2」,其餘四組切面與 M2 跨目錄無檔案衝突、
第一天即可各自開工。這不是新裁決,是把 EPIC.md 已經畫出來的兩條工作線,對應到 story 邊界。

## Story 清單(依建議施工序,非 M2→M6 條列序)

| # | 檔名 | 模組 | 型別 | 一句話範圍 | 依賴 |
|---|---|---|---|---|---|
| 001 | story-001-terrain-passable-flag.md | M2 | Logic | 地形 `passable` 布林旗標 + 未知地形字元明確失敗(R1 緩解) | 無(⚠️ C5 擁有者義務未完成,見下) |
| 002 | story-002-reachable-tiles-bounded-frontier.md | M2 | Logic | `reachable_tiles()` 改 `ignore_occupancy`/`ignore_passability` 雙開關 + 有界前緣展開 | 001 |
| 003 | story-003-los-blocked-in-range-query.md | M3a | Logic | 「射程內但視線被擋」查詢(攻擊疊加圖第三層資料源) | 無 |
| 003b | story-003b-atomicity-write-guard-consolidation.md | M3a | Logic | ADR-0001 原子性機制收斂(版本號遞增、寫入守衛、`Board` mutator 封裝,三個類別一次做齊) | 003(承接其部分實作) |
| 004 | story-004-unit-action-four-state-getter.md | M3a | Logic | 單位行動四態 getter(不選取也能查任一單位) | **003b**(2026-09-30 管理者裁決,見下) |
| 005 | story-005-threat-targets-semantic-clarification.md | M3a | Logic | `threat_targets()` 語意查證與必要時改名/擴充(U-T15) | **003b**(同上) |
| 006 | story-006-atk-def-phi-breakdown-query.md | M3a | Logic | `ATK`/`DEF`/`Φ` 拆解查詢 + 基準值/有效值存取層(#6 反向依賴) | **003b**(同上);⚠️ C5 擁有者義務未完成,見下 |
| 007 | story-007-movement-range-four-state-query.md | M3b | Integration | 移動範圍四態查詢介面(`A`/`B\A`/`C\B`/`Grid\C`) | 001, 002, **003b**(2026-09-30 管理者裁決,見下) |
| 008 | story-008-cursor-navigation-convergence.md | M6 | Integration | 一般移動/攻擊路徑接入 `CursorStateHost`(BOARD_TILE surface) | 無(需先於 009) |
| 009 | story-009-device-authority-convergence.md | M6 | Integration | 退役 `device_authority.gd`,改走 `CursorState.arbitrate_device_authority()` | 008 |
| 010 | story-010-direction-key-debounce-convergence.md | M6 | Logic | 方向鍵去抖收斂至 `InputEventKey.echo` 過濾(先驗證手把類比涵蓋) | 008 |
| 011 | story-011-input-gaps.md | M6 | Integration | U-T6 敵方回合拒絕逐幀生效、U-T7 拒絕回饋、U-T8 結束單位行動輸入路徑 | 008 |
| 012 | story-012-tile-info-panel.md | M5 | UI | 格位資訊面板(地形/成本/遮蔽/佔位單位/武器分層/MP) | 004, 006(部分見內文), 008-011, localization Story 001 |
| 013 | story-013-attack-confirm-panel.md | M5 | UI | 攻擊確認面板(二段確認,`_confirm_at_cursor()` 拆段) | 006, 008-011, localization Story 001 |
| 014 | story-014-movement-attack-range-overlay-layers.md | M4 | Visual/Feel | 移動範圍三態+第四態、攻擊範圍三層疊加圖 | 003, 007, 012, 013(執行序) |
| 015 | story-015-action-flag-marker-impassable-terrain-render.md | M4 | Visual/Feel | 單位行動旗標持久非色彩標記 + 不可通行地形呈現 | 001, 004, 014(執行序) |
| 016 | story-016-terrain-load-time-validation.md | M2 | Logic | 地形載入時驗證(`Board.from_ascii()` 結構性+組成性檢查)+ `reachable_tiles()` 哨兵 `-1` 防護 | 001, 002 |
| 003c | story-003c-player-turn-start-commit-wrapping.md | M3a | Logic | 玩家回合開始鉤子的提交覆蓋(`begin_player_turn()` / `tick_all_modifiers()`,路徑⑥⑦) | 003b |
| 017 | story-017-unit-combat-field-setters.md | M3a | Logic | `Unit` 戰鬥數值欄位加 setter + 寫入守衛(ADR-0001 硬性義務第 2 條) | 003b |

## 執行層序列化(寫進每張 M4/M5/M6 story 的 Dependencies 節,不只寫在這裡)

**M6(008-011)→ M5(012-013)→ M4(014-015)**,理由:三者共用 `src/ui/battle/battle_screen.gd`
(2702 行),規劃層產出互不依賴但執行不可並行(EPIC.md「依賴與實作順序」節)。

## 附帶建議 2:story 狀態欄同步的可執行檢查

寫入各 story 檔的 Test Evidence 節,亦記於此供一次性查閱。**檢查腳本**(非紀律呼籲,是可當場跑的指令):

```bash
for f in production/epics/tactical-combat/story-*.md; do
  status_line=$(grep -m1 '^> \*\*Status\*\*' "$f")
  test_path=$(grep -o 'tests/[a-zA-Z0-9_/]*_test\.gd' "$f" | head -1)
  if [ -n "$test_path" ] && [ -f "$test_path" ] && ! echo "$status_line" | grep -q "Complete"; then
    echo "MISMATCH: $f — 測試檔已存在($test_path)但狀態欄未標 Complete:$status_line"
  fi
done
```

用途:偵測「程式與測試已完成,狀態欄卻停在舊值」(本專案已有實例:
`affinity-data-pool/story-008-write-port-adapter.md` 停留 `Ready` 12 天後才補正)。
建議排入 sprint 收尾例行檢查,而非只在 `/story-done` 當下跑一次。

## ⚠️ C5 擁有者義務查證結果(2026-09-29,本次派工時實測)

EPIC.md 登記 C5 兩項擁有者義務「必須在對應 story 切出來之前有人動過」。本次派工**當場查證**,
兩項均**尚未完成**:

```
$ grep -c "passable" docs/architecture/tr-registry.yaml
0
$ grep -c "存取層" design/gdd/tactical-combat-system.md
0
```

- **TR-tactical-002/-006 由 `technical-director` 更正**(仍寫「兩個」地形屬性、單一 `ignore_occupancy` 參數)——**未完成**,影響 story 001/002/007。
- **GDD 補「存取層」一節由 `systems-designer` 撰寫**——**未完成**,影響 story 006。

**本次派工的處置**:EPIC.md 本身已提供保險條款(「以 GDD 公式三為準,不以 TR 文字為準」),
本次已把該保險條款寫入 story 001/002/007/006 的驗收條件,**不因此暫停切 story**——
但這是本次派工的判斷,不是把 C5 義務視為已完成。**兩項義務仍待 `technical-director`/
`systems-designer` 執行,不因本檔存在而消失。**

## 附帶建議 3:M4 截圖驗收批次化(已裁決,寫入 014/015 的 Test Evidence 節)

管理者裁決:M4 全部截圖證據集中一批,由管理者在家中桌機一次看完(理由:辦公室座位有人
經過,遊戲畫面不可出現在該螢幕上;headless 取不到像素,截圖只能開窗跑)。014/015 兩張
story 的 Test Evidence 節已寫入「不要求逐 story 截圖複核,累積至 M4 全部完成後一次執行」。

## 🔴 story-003d 新增說明(2026-10-08 管理者裁決)

`story-003b` 於 2026-10-08 標 **Done** 並解除 004~007 的封鎖時,**AC8(14 條驗收測試)
已完成且全綠,但 AC9(敏感度證明)只做到 1/14,而且用的方法本身已被本專案淘汰。**

**管理者裁決:先標 Done 解鎖四張,證明另切一張** —— 即 `story-003d`。
選項原文已逐字寫明代價:「那 13 條裡若有假測試(永遠不會紅的那種),
會被後續工單當成已驗證的地基蓋著蓋」。**這張 story 就是那個風險的對應處置。**

- **檔案**:`story-003d-sensitivity-proofs-spy-subclass.md`
- **狀態**:📋 Ready,**未指派**
- **不阻擋任何 story。** 004~007 已由 003b 的 Done 解除封鎖,本 story 不是它們的前置。
- **它也吸收了 AC11 的兩條專屬驗收向量**(`step_enemy_phase()` 獨立 +1 /
  `run_enemy_phase()` 巢狀收斂),003b 收尾時未寫。

🔴 **兩項動工前必讀的事實,寫在 story 本體,此處只指路:**
①`story-003b` 的 AC9 條文本身寫的就是被淘汰的方法(手動注入),而派工單照抄了它 ——
**錯在工作單與派工單,不在實作者**;②手動注入法對守衛類程式碼**在這台機器上結構性做不到**
(安全分類器攔下)。正確形式是間諜子類別 + 常駐 `test_sensitivity_proof_*`,
規則全文在 `.claude/rules/test-standards.md`。

⚠️ **在它被做掉之前,那 13 條是「存在且全綠」,不是「已驗證有效」。**
