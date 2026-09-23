# Check4 走「路①」的引擎面事實(SubViewport 直接讀回)

> PROTOTYPE — NOT FOR PRODUCTION / 拋棄式驗證探針
> **Executed by**: `godot-specialist`。Q1 沿用既有 headless 紀錄並當場重新核對原始行號
> (未重跑 headless);Q2/Q3/Q4 為本輪新跑,windowed only。

## What hypothesis is being tested

管理者在「路①」(把 Check4「世界層」的操作型定義從『裁容器矩形』改成『讀
`SubViewport.get_texture()`』)裁決前,要先知道引擎面事實:**這樣改之後,Check4 還抓不抓得到
任何缺陷,還是變成一條「不可能失敗的檢查」**(`coding-standards.md` 明文:「A test line that
cannot fail is worse than one that fails」)。

本探針只回答四個問題,不推薦三條路裡的哪一條。

## 怎麼跑

**必須開窗執行**(headless 下 `get_image()` 恆為 null,已由
`prototypes/godot-specialist-scene-load-feasibility-2026-09-23/` 確立,本輪 Q1 沿用未重測):

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . prototypes/godot-specialist-check4-subviewport-readback-2026-09-23/ProbeCheck4SubviewportReadback.tscn
```

`_ready()` 開頭掛 45 秒保險計時器(同前兩支探針的教訓:私有欄位回讀不要宣告成具體 Node 子類,
本探針的欄位回讀已整段省略,不重踩那個坑)。原始輸出 tee 進 `run_output_windowed.txt`。

**本輪跑了兩次**:第一次 sprite 位置 `(4,4)`/`(4,60)` 量到反直覺結果(見下方 Q3 的說明與修正),
修正位置後重跑,`run_output_windowed.txt` 目前內容為**第二次(修正後)**的乾淨輸出。第一次的
原始輸出未保留檔案,但其反直覺結果本身是本輪一個真實發現,已寫入下方 Q3 的「附帶發現」。

## Current status

Concluded — 20 回合上限內完成,兩次執行皆乾淨結束(`=== PROBE END ===` 後 `quit(0)`),
未撞保險計時器。

## 逐項回答

### Q1:`SubViewport.get_texture().get_image()` 在 headless 下能不能拿到像素?—— 已答(沿用既有紀錄,當場核對原始行號,未重跑)

**不能,而且它就是既有記載「兩條取像路徑皆 null」裡的其中一條。** 當場重新開啟
`prototypes/godot-specialist-scene-load-feasibility-2026-09-23/run_output_headless.txt`
第 38-43 行,逐字:

```
Q2/SUBVIEWPORT: world_viewport.get_texture() is null? false
ERROR: Parameter "t" is null.
   at: texture_2d_get (./servers/rendering/dummy/storage/texture_storage.h:110)
   GDScript backtrace (most recent call first):
       [0] _ready (res://prototypes/godot-specialist-scene-load-feasibility-2026-09-23/probe_load_real_scene.gd:129)
Q2/SUBVIEWPORT: sub_tex.get_image() is null? true
```

**兩條路徑逐字確認**:
1. 根視窗截圖 `get_viewport().get_texture().get_image()`(同檔第 31-37 行)
2. **`SubViewport.get_texture().get_image()`(上面引用的第 38-43 行,就是本問題問的那條)**

兩者的 `get_texture()` 本身都回傳非 null 物件,但呼叫 `.get_image()` 時 dummy rendering driver
直接回報「紋理是 null」(`ERROR: Parameter "t" is null.`)並回傳 `null`。**這是 headless dummy
rendering driver 的引擎限制,不因為改用 `SubViewport` 直接讀回就能繞過** —— 路①在 headless 下
與現行方法一樣拿不到像素,兩者對 headless 的可行性沒有差別。

⚠️ **本輪沒有重新執行 headless**,只當場重新核對既有 log 的原始行號與逐字內容(不是憑記憶轉述
README 摘要)。若要更嚴格,可重跑該支既有探針,但其 headless 結論與本輪要問的問題無關(路①改的
是「量測範圍」,不是「headless 能不能取像」這件事),故未重跑。

### Q2:開窗下要等幾幀才拿得到穩定的 SubViewport 原生像素?用什麼訊號等?—— 已答,附一個誠實缺口

**在本次靜態畫面下,第 1 幀就已經與第 15 幀逐位元組相同**,原始輸出:

```
Q2: frame 1 get_image() null? false size=(480, 270)
...
Q2: frame 1 byte-identical to frame 15? true
Q2: frame 2 byte-identical to frame 15? true
Q2: frame 5 byte-identical to frame 15? true
Q2: frame 10 byte-identical to frame 15? true
Q2: frame 15 byte-identical to frame 15? true
```

也就是說,**在這一幀的畫面內容下,等 1 個 `process_frame` 就足夠**,先前兩支探針沿用的
「等 15 個 `process_frame`」是保守值,不是必要值(至少對這個靜態場景而言)。

**用什麼訊號等**:本探針與前兩支探針一樣,只用 `await get_tree().process_frame`(輪詢式等待
N 幀),**沒有使用任何「渲染完成」的專屬訊號**(例如 `RenderingServer.frame_post_draw`)。
沒有查過是否存在更精確的訊號可以等,這條路沒有走。

🔴 **誠實缺口,不要外推**:
1. **本輪未測「等 0 幀」**(`add_child` / 場景穩定後,完全不等待任何 `process_frame` 直接讀)——
   最早測的是「已等待 1 幀」那個時間點,不是「完全沒等」。兩者不是同一件事,不得混用。
2. **本次畫面是靜態的**(`_cursor_active=false`,無 Tween/動畫進行中)。若畫面正在跑動畫或
   Tween,幀與幀之間內容本來就會不同,那是「內容還在變化」而不是「讀回本身落後渲染」——
   本探針的方法(比對位元組)無法區分這兩種情況,故本結論只能保證「靜態內容穩定所需的最少
   等待幀數 ≤ 1」,不保證「任何時刻讀回的都是當下最新畫面」這個更強的宣稱。

### Q3:🔴 最重要 —— 在 SubViewport 原生 480×270 緩衝區上跑 Check4,量到多少?路①之後這個檢查還剩什麼偵測力?—— 已答

**Part A:`_scale=1` 是結構性重言式,恆為 0,不管內容是什麼。**

```
CHECK4 [Q3A-native-scale1 (structural tautology check, expect 0 by construction)] = 0 / 129600
```

這不是巧合。Check4 的定義是「每個來源像素必須對應一塊 N×N 同色方塊」;當 `_scale=1` 時,方塊
就是單一像素本身,「方塊內每個像素都等於方塊左上角像素」對 1×1 方塊**必然恆真**——這與
`godot-specialist-u013-worldlayer-attribution-2026-09-23/` 已證明的「nearest 放大輸出恆為 0」
是同一種結構性保證,只是這次發生在輸入端而不是輸出端。**若路①的實作直接沿用容器縮放倍率算出
的整數 `_scale` 去讀原生緩衝區(現行倍率是 2、4、5、8……皆 >1,不是 1),則不會踩到這個
特例 —— 但如果有人誤以為「世界層原生解析度不需要縮放,所以 scale=1」,那條路徑會讓 Check4
變成一條永遠 0 的重言式,這正是派工單擔心的「不可能失敗的檢查」那個形狀,已於本次確認為真。**

**Part B:用資產自己「應有的」整數縮放倍率(而非容器倍率)直接測原生緩衝區,偵測力仍在 —— 但發現一個先前沒人問過的新前提:格線對齊。**

構造兩個額外精靈(掛在真實載入的 `WorldViewport` 底下,4×4 棋盤格紋理,`texture_filter=Nearest`):
- GOOD:`scale=3.0`(乾淨整數)
- BAD:`scale=3.3`(非整數)

**第一次執行**(精靈位置 `(4,4)`/`(4,60)`,x 座標不是 3 的倍數)量到反直覺結果:**GOOD 也是
100% 違規**(`16/16`)——這不是精靈本身有缺陷,而是 Check4 的方塊格線是從影像原點 `(0,0)` 起算
的**絕對固定格線**(`bx*scale, by*scale, ...`),不是「以被測物件自己的左上角為起點」的相對格線。
精靈位在 x=4(非 3 的倍數)時,它自己的來源像素邊界(4,7,10,13…)與 Check4 格線的絕對邊界
(0,3,6,9,12…)對不齊,於是每個 Check4 方塊都橫跨兩個不同來源像素,**乾淨的整數縮放也會被
判定違規**。

修正精靈位置為 3 的倍數(`(3,3)`/`(3,63)`)後重跑,結果符合預期:

```
CHECK4-REGION [Q3B-GOOD-integer-scale-3.0-aligned] = 0 / 16
CHECK4-REGION [Q3B-BAD-nonint-scale-3.3-aligned] = 21 / 25
```

**結論**:當格線對齊被滿足時,Check4 直接讀 `SubViewport` 原生緩衝區、用資產自己「應有的」整數
縮放倍率(不是容器的整數縮放倍率),**確實抓得到世界層內部自己造成的非整數縮放缺陷**
(GOOD 0/16 對比 BAD 21/25,對比鮮明)。**這是路①之後這個檢查還剩下的偵測力**:它抓不到
「容器把 SubViewport 放大到視窗」那一步(那一步已被
`godot-specialist-u013-worldlayer-attribution-2026-09-23/` 證明結構上恆為乾淨),但**抓得到
世界層內部自己對某個元素做了非整數縮放**(例如:單位精靈的懸停/選取動畫用 Tween 把 `scale`
撐大到非整數倍率、卡牌翻面動畫中途某幀縮放到非整數值)。

🔴 **附帶發現,不在原問題範圍內,但會直接影響路①的實作成本(見 Q4)**:Check4 目前的演算法本身
**假設一個從影像原點起算的絕對整數格線**,而不是「以被測物件自身位置為準」的相對格線。這代表
**若某個世界層元素本身縮放乾淨(整數倍),但它在原生 480×270 座標系裡的位置不是所選 `_scale`
的整數倍,Check4 一樣會誤報違規** ——這與「世界層內容本身有沒有缺陷」無關,純粹是格線對齊
問題。**本輪只是在建構測試精靈時意外撞到這一點,沒有查過真實世界層內容(棋盤格、單位精靈)的
實際擺放位置是否都對齊到所選 `_scale` 的倍數** —— 這是一個新發現的缺口,不是本次任務要解決的
問題,留給下一輪或管理者裁決路①時一併考慮。

### Q4:路①的實作成本 —— 已答

**探針拿得到 `SubViewport` 節點**,路徑與型別皆確認:

```
Q4: WorldViewportContainer node = WorldViewportContainer:<SubViewportContainer#51472500218> get_class()=SubViewportContainer
Q4: WorldViewport node = WorldViewport:<SubViewport#51506054653> get_class()=SubViewport
```

路徑 `battle.get_node_or_null("WorldViewportContainer/WorldViewport")` 直接可用,與前兩支探針
一致,無新障礙。

**要改幾個地方,取決於範圍**:
1. **像素取得**:所有目前對「整個視窗截圖」呼叫 `get_viewport().get_texture().get_image()`
   後再裁切世界層矩形的地方,改成直接呼叫
   `world_viewport.get_texture().get_image()`(原生 480×270,不裁切、不需要知道容器矩形)。
2. **`_scale` 參數的意義整個換掉**:現行 Check4 呼叫端傳的 `_scale` 是「容器/視窗的整數放大
   倍率」(2、4、5、8……依解析度而定,見本探針 `SANITY: stretch_shrink=2`)。路①下讀的是
   原生緩衝區,**容器倍率對它沒有意義**——需要換成「該世界層內容自己應有的整數縮放倍率」,
   而**這個值不是單一全域常數**,原生解析度下大多數內容(棋盤格、單位精靈)理論上是 1:1
   繪製(不額外縮放),只有少數動畫/特效元素會在世界層內部自己做縮放。**這代表 Check4 的呼叫端
   需要知道「這一段測的是什麼」才能選對 `_scale` 值** —— 不能再像現行容器版那樣,全螢幕一個
   `_scale` 打天下。
3. **Q3 附帶發現的格線對齊問題**:若要測世界層內部某個元素,還需要確認該元素在原生座標系裡的
   位置是否對齊到所選 `_scale` 的整數倍,否則會誤報。**本探針沒有查過真實世界層內容是否天生
   滿足這個對齊條件**,這是路①的一項未知成本,不是已知成本。
4. **headless 不受影響**(Q1 已答:兩條路徑一樣拿不到像素,路①不會讓 headless 突然可行)。

## 誠實缺口總表(不要外推超出本輪測過的範圍)

- Q1:未重跑 headless,僅重新核對既有 log 原始行號(該部分本身就是既有 (A) 級證據,重新核對
  沒有改變結論,只是加強查證)。
- Q2:只測了「等 1 幀起」,未測「等 0 幀」;只測了靜態畫面,未測動畫/Tween 進行中的畫面。
- Q3:GOOD/BAD 兩個精靈只測了一組座標與一組縮放值(3.0 vs 3.3);未測其他縮放值(例如 1.5、
  2.0)、未測真實世界層內容(棋盤格、單位精靈)本身是否天生對齊到任何特定 `_scale`。
- Q4:「要換掉的呼叫點總數」沒有實際去數 —— 只回答了「換掉之後需要換成什麼概念」,沒有逐一
  清點 Category A/B/C 現行程式碼裡有幾處呼叫點。
