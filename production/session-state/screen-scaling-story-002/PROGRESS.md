# Story 002（screen-scaling:字級規則 + 套用到現有介面元件）進度追蹤

以檔案為準，不以文字回報為準（見 dispatch brief 第九節：subagent 常在宣告要
大量產出之後、實際動手之前被中斷 —— 本張實際發生了三次)。

## 設計決定（實作前）

- **HUD 字級規則**：直接呼叫 `WorldLayout.compute_scale()`，`src/ui/battle/hud_layout.gd`
  （`class_name HudLayout`）的 `font_size()` 只做
  `11 * WorldLayout.compute_scale(window_size)`，不重刻公式。
- **6 個元件座標退化的修法**：`HudLayout` 的純函式（`status_label_rect` /
  `info_label_rect` / `controls_hint_bg_rect` / `load_error_label_rect` /
  `result_label_offset_rect`），全部以 `safe_rect()`（title-safe 5% 內縮）為錨點，
  再由 `src/ui/battle/hud_layout_scaler.gd`（掛在 `UILayer`）套用到節點的
  `offset_left/top/right/bottom` 四個值，不改動任何節點既有的 `anchors_preset`。
- **關鍵設計判斷（已在最終回報中標記,不是規格逐字寫死）**：`ControlsHintBg` 改為以
  安全區（非螢幕物理邊緣）為錨點 —— 背景不貼齊真正的螢幕邊緣。理由：安全區存在
  的目的就是防止內容碰到物理邊緣，若背景本身貼齊邊緣，安全區對它形同虛設。

## 檔案清單與狀態 —— 全部已完成

- [x] `src/ui/battle/hud_layout.gd` — 新增，純函式，`font_size()` 委派
      `WorldLayout.compute_scale()`（不複製公式）
- [x] `src/ui/battle/hud_layout_scaler.gd` — 新增，場景腳本（掛 `UILayer`），
      `_ready()` + `get_window().size_changed` 監聽，非啟動時算一次
- [x] `src/ui/battle/BattleScreen.tscn` — 新增 ext_resource,`UILayer` 掛上
      `hud_layout_scaler.gd`
- [x] `tests/unit/ui/hud_layout_test.gd` — 新增，311 行、15 條測試，涵蓋
      AC-S002-a/b/c + 6 元件回歸基準 + LoadErrorLabel 換行高度
- [x] headless `--import` 乾淨通過（兩次：新增檔案後一次、新增 evidence spike 後一次）
- [x] 全套測試重跑 **386 test cases / 0 errors / 1 failures / 0 flaky / 0 orphans /
      30 suites / exit 100**（基線 371 → 386，+15，零退步；唯一失敗為既有已核准
      `affinity_phi_provider` 紅燈）
- [x] AC-S002-b 測試「弄紅一次」證明有效 —— 兩輪注入,分別證明「同一 bug 造成
      4 條斷言全紅」與「AC-S002-b 專屬測試本身會紅」,已還原並重跑全套確認乾淨
- [x] 擷圖證據：`prototypes/story-002-evidence-capture-2026-09-04/`
      驅動,產出 1920x1080 + 2560x1440 兩張,機械檢查全過,人眼已開圖確認
- [x] `production/qa/evidence/adaptive-font-scale-evidence.md`
- [x] 最終回報

## 已知會列入回報但不擅自處理的項目

1. **`ControlsHintBg` 改為以安全區（非螢幕物理邊緣）為錨點** —— 這是本張做出的
   一個版面判斷,不是規格逐字寫死的數字。已在最終回報**單獨拉出**標記(協調者
   覆核時特別要求不要埋在細節裡),供協調者/管理者確認。
2. **對話正文字型仍未選定** —— 不阻擋本張（沿用 Story 002 規格文件自己的既有揭露）。
3. **`InfoLabel` 在兩張擷圖裡都是空白** —— 這是預期行為（初始狀態沒有游標作用中、
   沒有選取單位,`_refresh_view()` 的 Mode A/B/C 皆不成立),不是本張引入的缺陷,
   只是擷圖當下沒有觸發任何 InputEvent 去展示它。
4. **場景檔（`.tscn`）裡 5 個節點的 `offset_*` 仍是 Story 001 結案時的舊 480×270
   座標字面值,不反映執行期實際版面**（協調者覆核時實測發現並提出）——已判斷為
   刻意設計,理由與 `StatusLabel` 的英文佔位字串（`text="Round 1 | PLAYER phase"`,
   被 `_update_status_label()` 無條件覆寫)、`WorldViewportContainer` 的
   `anchors_preset=15`（被 `world_viewport_scaler.gd` 無條件覆寫)是同一種、
   本專案已接受的既有權衡,故延續同一套慣例（在執行覆寫的腳本 doc comment 裡
   記錄「這些字面值會被覆寫」),而非引入第三種做法。已在
   `hud_layout_scaler.gd` doc comment 與最終證據文件裡完整記錄理由,若管理者
   認為這個權衡在 UI 座標情境下風險更高,列為待裁決項。

## AC-S002-b 靈敏度證明的兩輪注入（已還原,見最終回報完整輸出）

**Run 1**（`hud_layout.gd` 的 `font_size()` 加 `+1`,15 條測試全部啟用）：
只有宣告順序中的第一條 `test_font_size_matches_expected_value_at_every_defined_resolution`
執行並紅(4 項斷言全部失敗),其餘 14 條**未執行**（`Executed test cases: (1/1)`）——
與 `coding-standards.md` 記載的「一條失敗會中止同 suite 其餘測試」完全一致。

**Run 2**（同一個 `+1` bug 仍在,暫時把第一條測試改名移出收集清單）：
`test_font_size_is_integer_multiple_of_glyph_px_at_every_defined_resolution`
（AC-S002-b 專屬測試）本身執行並紅,4 個解析度各自印出
`font_px 45/56/89/56 is not an integer multiple of GLYPH_PX 11`。

兩輪後皆已還原（`hud_layout.gd` 的 `+1` 移除、測試改名復原),
`grep "TEMP-INJECTED\|_temp_disabled"` 兩檔皆零命中,全套測試重跑確認回到
386/0/1/0/exit 100。

## 測試基線（協調者提供，開工前）

356→371（Story 001）→386（本張,+15）條 / 0 errors / 1 failures（既有已核准紅燈
`affinity_phi_provider`）/ 0 orphans / exit 100
