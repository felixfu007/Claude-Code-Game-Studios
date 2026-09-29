# Story Index — Epic: 戰棋移動與交戰系統(#4 Tactical Combat)

> 本檔是寫作進度的落地清單,先於逐張 story 內容寫出,供任何一次寫作中斷後的接手依據。
> 完成後仍保留(不刪除)作為 story 檔全集的目錄,但 EPIC.md 的「## Stories」表才是正式狀態欄。

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
| 004 | story-004-unit-action-four-state-getter.md | M3a | Logic | 單位行動四態 getter(不選取也能查任一單位) | 無 |
| 005 | story-005-threat-targets-semantic-clarification.md | M3a | Logic | `threat_targets()` 語意查證與必要時改名/擴充(U-T15) | 無 |
| 006 | story-006-atk-def-phi-breakdown-query.md | M3a | Logic | `ATK`/`DEF`/`Φ` 拆解查詢 + 基準值/有效值存取層(#6 反向依賴) | 無(⚠️ C5 擁有者義務未完成,見下) |
| 007 | story-007-movement-range-four-state-query.md | M3b | Integration | 移動範圍四態查詢介面(`A`/`B\A`/`C\B`/`Grid\C`) | 001, 002 |
| 008 | story-008-cursor-navigation-convergence.md | M6 | Integration | 一般移動/攻擊路徑接入 `CursorStateHost`(BOARD_TILE surface) | 無(需先於 009) |
| 009 | story-009-device-authority-convergence.md | M6 | Integration | 退役 `device_authority.gd`,改走 `CursorState.arbitrate_device_authority()` | 008 |
| 010 | story-010-direction-key-debounce-convergence.md | M6 | Logic | 方向鍵去抖收斂至 `InputEventKey.echo` 過濾(先驗證手把類比涵蓋) | 008 |
| 011 | story-011-input-gaps.md | M6 | Integration | U-T6 敵方回合拒絕逐幀生效、U-T7 拒絕回饋、U-T8 結束單位行動輸入路徑 | 008 |
| 012 | story-012-tile-info-panel.md | M5 | UI | 格位資訊面板(地形/成本/遮蔽/佔位單位/武器分層/MP) | 004, 006(部分見內文), 008-011, localization Story 001 |
| 013 | story-013-attack-confirm-panel.md | M5 | UI | 攻擊確認面板(二段確認,`_confirm_at_cursor()` 拆段) | 006, 008-011, localization Story 001 |
| 014 | story-014-movement-attack-range-overlay-layers.md | M4 | Visual/Feel | 移動範圍三態+第四態、攻擊範圍三層疊加圖 | 003, 007, 012, 013(執行序) |
| 015 | story-015-action-flag-marker-impassable-terrain-render.md | M4 | Visual/Feel | 單位行動旗標持久非色彩標記 + 不可通行地形呈現 | 001, 004, 014(執行序) |

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
