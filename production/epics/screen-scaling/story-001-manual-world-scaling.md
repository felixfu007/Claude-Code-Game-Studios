# Story 001:切換縮放模式 + 世界層手動縮放定位

> **Epic**:畫面縮放與定位(手動管理)
> **Status**:Ready
> **Layer**:Presentation
> **Type**:Integration
> **Estimate**:M(約 4–6 小時)
> **Last Updated**:[由 /dev-story 於實作開始時設定]

## Context

**權威文件**:`design/art/screen-architecture.md`(2026-09-01 管理者裁決)
**執行摘要**:`.claude/docs/technical-preferences.md`「畫面架構裁決」節(每次對話開場載入)
**實測依據**:`prototypes/ui-canvas-scale-spike-2026-09-01/`(非 headless、真實 GPU)

**Engine**:Godot 4.7.1 | **Risk**:MEDIUM

🔴 **本張是一個原子變更,不可拆開交付。** 見下方「為什麼不能只改設定」。

---

## 現況(2026-09-04 實測,非轉述)

`project.godot` 第 18–20 行:

```
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/stretch/scale_mode="integer"
```

而 `.claude/docs/technical-preferences.md`(**開場自動載入**)寫的是 `"disabled"`。
**兩份抄本三天來講著相反的話,而其中一份每次對話都會被讀進來。**

---

## 🔴 為什麼不能只改設定

`"canvas_items"` 下,引擎自動把 480×270 的內容整數倍放大填滿視窗。
改成 `"disabled"` 之後**引擎完全不再縮放** —— 若手動縮放程式不存在,
**棋盤會以 480×270 的原始大小畫在螢幕左上角**,其餘畫面空白。

**設定與程式必須在同一次變更裡完成。**

⚠️ **連帶**:`aspect="keep"` 與 `scale_mode="integer"` 兩鍵在 `disabled` 下**不再產生作用**。
不要刪除它們就當作沒事,也不要以為它們還在幫忙 —— 決定要留還是要拿掉,並在提交訊息裡說明。

---

## Implementation Notes

### 1. 倍率與定位規則(裁決原文,不得改寫)

> **取該螢幕塞得下的最大整數倍,永遠置中。**

棋盤基準 480×270,放大 N 倍即 480N×270N。塞不下就是塞不下。

| 螢幕 | 倍率 | 棋盤尺寸 | 剩餘邊區 | 來源 |
|---|---|---|---|---|
| 1920×1080 | 4× | 1920×1080 | 零 | 算術 |
| 2560×1440 | 5× | 2400×1350 | 四周 80 / 45 | **spike 實測** |
| 3840×2160 | 8× | 3840×2160 | 零 | 算術 |
| 3440×1440 | 5× | 2400×1350 | 左右各 520 | **spike 實測** |

**視窗尺寸會變(玩家縮放視窗、切換全螢幕),所以這是要持續維持的關係,不是啟動時算一次。**
🔴 **邊界值未定義處請停下來問,不要自己選一個** —— 特別是:視窗小於 480×270 時要怎麼辦
(倍率會變成 0)。**這一項本工作單刻意不預先裁定。**

### 2. 已實測的三個引擎陷阱(出自 `technical-preferences.md`,不要重新踩)

1. 🔴 **`stretch/mode` 絕不可設 `"viewport"`。** `CanvasLayer` 的繼承鏈是
   `CanvasLayer → Node → Object`,**不繼承 `Viewport`**,該模式下介面無法逃出低解析度緩衝區,
   對話文字會模糊。**照第一輪報告寫入的話,要等到排完介面才會發現。**
2. 🔴 **不可手動設定 `SubViewport.size`。** 用 `SubViewportContainer.stretch_shrink`
   讓引擎反推。實測引擎**當場拒絕該賦值**(不是「賦值後被覆寫」——除錯時循後者方向會找錯地方),
   並印出 `Can't change the size of a SubViewport with a SubViewportContainer parent that has stretch enabled`。
3. ⚠️ **`SubViewportContainer.texture_filter` 預設為 `Inherit`,須手動覆寫為 Nearest**,
   否則世界層貼回外層畫面那一步仍會被 Linear 模糊一次。**此項極易漏掉。**

另:`src/ui/GameRoot.tscn` 的根節點必須是 `Node` —— 掛在 `Node2D` 或**裸 `Control`** 底下時
`SubViewportContainer` 的錨點永遠不生效(容器恆 `(0,0)`、內部畫布恆 `2×2px`)。
**現行檔案已是 `Node`,不要改回去。**

### 3. 座標換算紀律(已實測結案的條件,不是建議)

`prototypes/board-render-input-spike-2026-08-27/` 判定 ADR-0005 的「單一根 Viewport 假設」
**條件成立**,兩個條件是:

- **條件一**:世界層容器以滿版錨點貼齊基準畫布,起點恆為 `(0,0)`。
- **條件二**:換算一律呼叫引擎的 `Window.get_final_transform()`,**不自己重刻**
  `stretch`/`keep`/`integer` 公式。

🔴 **條件二是紀律要求,不是自動保證** —— 手刻公式在非 16:9 視窗會**悄悄算錯而不報錯**。
⚠️ **本張把縮放改成手動之後,「不要自己重刻公式」這條變得更難遵守**,因為現在確實有一段
我們自己寫的縮放邏輯。**那段邏輯要有單一出處,不得在呼叫端各自複製一份。**

---

## 🔴 已知會被本張弄紅的既有測試

`tests/unit/cursor/cursor_layer_transform_test.gd::test_environment_sanity_root_transform_is_non_identity_when_resized`

它斷言 2K 下根視窗變換為**非**恆等、倍率 `5×`、偏移 `(80, 45)` —— **三項皆是
`canvas_items` 的性質**,切成 `disabled` 後全部不成立。

⚠️ **不可以只把它改綠。** 該測試的職責是證明「游標圖層的恆等斷言不是廢話」:
先證明環境非恆等,圖層的恆等才有資訊量。切換後那個論證失效,
**必須重新回答「Story 010 的 AC-S010-a 現在證明了什麼」,並如實記錄結論。**

✅ **ADR-0005 Validation Criteria #20 已預先寫過這段推理**,結論是該驗證條件**仍然必需**
(①畫面設定會再改;②HUD 字型放大 2 倍使用,介面層一旦掛上縮放,共用節點立刻壞掉)。
**動手前先讀那一段,不要重新推導。**

📌 該測試檔的失敗訊息本身就點名了這個情境(逐字:「or content scaling is disabled.
If so, EVERY identity assertion in this file is vacuous and must be reported as
UNCOVERED, not passing」)——**它是刻意寫成這樣的,請照它說的辦。**

---

## Out of Scope

- **字級規則** —— Story 002。
- **任何介面版面配置** —— 本張只負責世界層的縮放與定位,不排介面。
- **黑邊裝飾邊框** —— 🔴 已於 2026-09-01 因前提消失而**取消**,不是延後。

---

## Acceptance Criteria

以下 3 條編號 `AC-S001-*`,來源為 `design/art/screen-architecture.md` 的裁決,非任何 GDD。

- **AC-S001-a(倍率正確)**:**GIVEN** 視窗尺寸為 1920×1080 / 2560×1440 / 3840×2160 /
  3440×1440 其中之一,**WHEN** 讀取世界層實際繪製尺寸,**THEN** 它等於 480×270 乘以
  「該尺寸塞得下的最大整數倍」,四種尺寸分別為 4× / 5× / 8× / 5×。

- **AC-S001-b(永遠置中)**:**GIVEN** 上述任一視窗尺寸,**WHEN** 讀取世界層的螢幕位置,
  **THEN** 左右邊區相等、上下邊區相等(邊區為零時亦成立)。

- **AC-S001-c(不再有引擎未涵蓋的黑邊)**:**GIVEN** 視窗尺寸為 2560×1440,
  **WHEN** 擷取整個畫面,**THEN** 擷取到的影像尺寸等於**視窗尺寸 2560×1440**,
  而不是 `canvas_items` 模式下的 2400×1350。
  🔴 **這一條是本次切換的核心理由**:舊模式下那圈留白是**引擎渲染目標沒有涵蓋的範圍**,
  物理上不存在,任何 transform 都畫不進去(2026-09-01 實測)。切換後那圈範圍必須變成可繪製。

⚠️ **邊界值未定義處請停下來問,不要自己選一個。** 已知未定義:視窗小於 480×270 時的行為。

---

## Test Evidence

**Story Type**:Integration
**必要證據**:整合測試 **或** 有紀錄的實機檢視 — `production/qa/evidence/screen-scaling-evidence.md`
**Status**:[ ] 尚未建立

🔴 **AC-S001-c 需要真的開視窗擷取畫面**(headless 沒有渲染目標可擷取)。
**擷取工具的四項機械檢查與「人要打開圖確認」那條規則,見 `.claude/docs/coding-standards.md`
的 Screenshot Evidence Rules** —— 該節是 2026-08-31 一張 Godot 開機畫面被當成遊戲畫面
寫進證據目錄之後訂的。**寫擷取工具前先讀,不要重寫一支。** 現有工具:`tools/build/capture_window.ps1`。

---

## Dependencies

- **Depends on**:無
- **Unlocks**:所有介面版面工作(在此之前「棋盤旁邊有沒有空位」這個問題沒有確定答案)
