# 世界層 Check4 違規歸因(1071/112490 是什麼造成的?)

> PROTOTYPE — NOT FOR PRODUCTION / 拋棄式驗證探針
> **Executed by**: `godot-specialist`, windowed (headless 拿不到像素,見前一支探針的既有結論,本輪未重測)。

## What hypothesis is being tested

管理者派工單的假說:`prototypes/godot-specialist-scene-load-feasibility-2026-09-23/` 量到的
「世界層」Check4 整數縮放違規 `1071 / 112490` 格,是 `board_view.gd` 的血量文字 Label(唯一
一個在世界層裡使用非像素字型、無字型覆寫的節點)造成的。派工單推的算術上界:一個血量文字帶
最多佔 `CELL_SIZE × HP_TEXT_HEIGHT = 32 × 10 = 320` 個來源像素方塊,而 `320 < 1071`,所以
「假設那一幀只有一個單位顯示血量數字」這個前提下,血量數字在算術上不可能單獨解釋 1071。

## 結果:假說被否證,而且否證的方式比原本推的更徹底

**1. 那一幀的血量數字貢獻是 0,不是「至多 1 個單位、至多 320 格」。**
`run_output_windowed.txt` 第 17 行量到 `_cursor_active=false`(兩輪重測結果一致)。依
`battle_screen.gd`'s `_refresh_view()` 的 `show_hp_text` 規則(`focus_cell = _cursor_cell if
_cursor_active else Vector2i(-1,-1)`),`_cursor_active=false` 時沒有任何單位符合顯示條件。
本探針直接向已載入的真實 `BattleState` 查詢 `cursor_cell` 位置有沒有單位(`unit_at()`,不是
邏輯推論),結果 `hp_text_window_rects` 陣列為空——**空陣列本身就是量到的事實,不是假設**。
證據:`EXCL-5-rects`(3 個 HUD 矩形 + HandBar + 血量文字帶)與 `EXCL-4-rects`(少了血量文字帶
那一項)兩行輸出逐字相同:
```
CHECK4-EXCL [EXCL-4-rects (3 HUD + HandBar)] excluded_blocks=21466 violations=478 / 108134
CHECK4-EXCL [EXCL-5-rects (3 HUD + HandBar + HP-text band) -- if this is ~0, all violations are accounted for] excluded_blocks=21466 violations=478 / 108134
```
多排除的那個矩形集合是空集合,才會讓兩行數字完全一樣——代表這一幀根本沒有血量文字可排除。

**2. 🔴 更根本的發現(本輪最重要的一項):Check4 這個檢查方法,結構上量不到 `SubViewport` 內部畫了什麼——不管答案是什麼。**

本輪額外做的量測(`BONUS`):直接讀 `WorldViewport.get_texture().get_image()`,拿到完全在
UI `CanvasLayer`疊加**之前**的原生 480×270 世界層緩衝區,用 `Image.resize(...,
Image.INTERPOLATE_NEAREST)` 照真實管線的縮放倍率(這次量到 2×)自己放大回 960×540,再對這張
「純世界層」影像跑同一套 Check4 演算法:
```
CHECK4 [BONUS-SUBVIEWPORT-NATIVE-nearest-upscaled (pure world-layer content, isolates measurement-method vs content-problem)] = 0 / 129600
```
**結果是 0,而且這不是巧合,是這個放大方式的數學性質保證的**:nearest 放大的定義就是「把每
個來源像素複製成一個 N×N 同色方塊」——不管來源像素本身乾不乾淨、有沒有反鋸齒,複製出來的方
塊**定義上一定同色**,Check4(「每個來源像素必須對應一塊 N×N 同色方塊」)因此**永遠**回報 0
違規,無論 `SubViewport` 內部實際畫了什麼。

**結論**:「世界層本身有沒有反鋸齒文字,會不會讓 Check4 的『只量世界層』前提不成立」這整個問
題,Check4 這個檢查方法從設計上就答不出來——它只可能偵測到「繞過那道 nearest 放大、直接畫在
視窗原生座標上的東西」,也就是 UI `CanvasLayer`,**永遠不是** `SubViewport` 裡的世界層內容。
`1071`(以及本輪重測的 `1109`)**從頭到尾都是 UI CanvasLayer 的內容**,不是「量測範圍選錯」
這麼簡單,而是這個檢查方法的偵測範圍本來就只涵蓋 UI 層。

**3. 目前找到的最大單一來源是 `HandBar`,但沒有解釋全部。**
排除 3 個既有 `HudLayout` 矩形(`status_label_rect`/`info_label_rect`/`controls_hint_bg_rect`)
後剩 `1109` 格違規(本輪重測值;上一支探針量到 `1071`,見下方「兩項未解」)。`$UILayer/HandBar`
是前一支探針的排除清單完全沒算進去的第 4 個真實 UI 元素——`battle_screen.gd` 的 `_ready()`
初次呼叫 `_refresh_view()` 就會 `_hand_bar.render(...)`,其 `CountLabel`/`UnavailableLabel` 與
那 3 個已排除的 HUD Label 用同一顆 `Cubic_11.ttf`。實測它自己矩形內就有 `631 / 4356` 格違規:
```
WITHIN [WITHIN HandBar.slot_bar_rect] rect=[P: (348, 392), S: (264, 66)] violations=631 / 4356 blocks
CHECK4-EXCL [EXCL-4-rects (3 HUD + HandBar)] excluded_blocks=21466 violations=478 / 108134
```
`631` 佔排除 3 HUD 矩形後剩餘量(`1109`)的 57%——是目前找到的單一最大來源,但拿掉它之後還
剩 `478` 格(43%)沒有解釋。**是主要貢獻之一,不是唯一/壓倒性的主因。**

## 兩項未解

- **`478` 沒有成因。** 本輪曾猜測 `SubViewportContainer`/世界層貼回外層畫面那一步若濾波設定
  不是 Nearest(`technical-preferences.md` 明文警告這項「極易漏掉」),GPU 合成時會被 Linear
  模糊掉邊緣,而這種模糊不會被 `BONUS` 那種軟體端強制 Nearest 的重建方式測到。
  🔴 **這個猜測已被協調者用 `src/ui/battle/BattleScreen.tscn` 的 `texture_filter = 1` 否定**
  ——本探針沒有重新查證這個否定本身,原樣記錄,不當結論。`478` 目前仍無成因,留給下一輪。
- **兩支探針的 baseline 對不上。** 前一支探針(`godot-specialist-scene-load-feasibility-
  2026-09-23/`)量到 `4563 / 129600`(排除 3 HUD 後 `1071`);本探針同一套方法重測量到
  `4601 / 129600`(排除 3 HUD 後 `1109`)。差值恆為 `38`(兩處差值相同),代表這 38 格的來源
  不在那 3 個已排除的 HUD 矩形內,但沒有查出是什麼——可能是動畫/Tween 進度落在不同幀、也可能
  是某處浮點捨入,兩者都沒有驗證,純粹列出差異本身。

## 型別陷阱(供下一個依 `technical-preferences.md`「(A) 的精確定義」第 5 點寫探針的人參考)

第一輪執行時,腳本裡有一行 `var controller: Node = battle.get("_controller")`——抄的是前一支
探針對 `SubViewport`/`SubViewportContainer` 這樣讀回來、宣告成 `Node` 型別是安全的寫法(它們
真的是 `Node` 子類)。但 `BattleController extends RefCounted`(`src/gameplay/battle/
battle_controller.gd:42-43`),不是 `Node`。這個型別不符**在 GDScript 解析期沒有任何警告**,
只在**執行期**丟出 `SCRIPT ERROR: Trying to assign value of type 'RefCounted' to a variable of
type 'Node'.`,中止整個 `_ready()` 協程——而中止點在 `get_tree().quit()` 之前,導致視窗**一直
開著**,直到我手動 `taskkill` 兩個殘留的 `Godot_v4.7.1-stable_win64*.exe` 行程。背景工作管理
器事後回報「completed, exit code 0」——**那個 0 是 `taskkill` 造成的,不是腳本自己 `quit()`
出來的**,和 `coding-standards.md` 已經記載的好幾種「假綠燈」是同一個形狀。

**教訓**:凡是照規則第 5 點的寫法用 `battle.get("_something")` 回讀私有欄位做交叉檢查,收的變
數應該宣告成 `Variant`/`Object`,不要照抄「看起來能動」的具體型別——那個具體型別能不能動,取
決於被讀的欄位底層實際是不是那個型別的子類,寫的人通常不會事先知道。

本輪修法是**整段刪掉**那個交叉檢查(它是附帶項,不影響主線量測),不是改型別再試。

## 如何重跑

**必須開窗執行**(headless 下 `get_image()` 恆為 null,已由前一支探針確立,本輪未重測):

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . prototypes/godot-specialist-u013-worldlayer-attribution-2026-09-23/ProbeWorldlayerAttribution.tscn
```

腳本 `_ready()` 開頭掛了一個 **45 秒保險計時器**(`get_tree().create_timer(45.0)`):不論下面
的量測邏輯有沒有跑完或崩潰,45 秒後一定會 `push_error` + `get_tree().quit(2)`,避免重演上面那
個「視窗掛住要人工 `taskkill`」的狀況。正常執行(本輪兩次重跑皆如此)在 45 秒保險觸發前就會自
己跑完並印出 `=== PROBE END ===` 後 `quit(0)`——若 log 裡出現 `FAILSAFE: 45s elapsed...` 字
樣,代表主邏輯本身又崩潰了,保險只保證行程會結束,不代表量測有跑完。

原始輸出重導到 `run_output_windowed.txt`(建議加 `2>&1`,錯誤與一般輸出都在同一份 log 裡,
本輪就是這樣做的)。

## Current status

Concluded. 三輪執行(第一輪型別崩潰、第二輪修正後乾淨跑完並含 BONUS 量測)的完整原始輸出保留
在本目錄的 `run_output_windowed.txt`(當前檔案內容為第二輪、乾淨結束的那次)。

## Findings 摘要(給只想看結論的人)

1. 假說(血量數字造成 1071)**被否證**:本輪重測那一幀血量文字貢獻實測為 0,不是「至多 320」。
2. **Check4 這個檢查方法結構上量不到 `SubViewport` 內部的內容**(nearest 放大的數學性質保證
   任何世界層內容 Check4 恆為 0)——這比否證血量數字假說本身更重要,它改變了整條規則的前提。
3. `HandBar`(`$UILayer/HandBar` 的 `CountLabel`)是目前找到的單一最大來源(57% of 1109),
   但不是全部——還有 43%(478 格)未解。
4. 兩項懸而未決,已列在上方「兩項未解」,留給下一輪。
