# Spike:世界層放大倍率 / 世界容器定位 / 介面設計基準畫布 三個待決項,連同 ADR-0005 VR #11b

> PROTOTYPE - NOT FOR PRODUCTION / 拋棄式技術驗證,不是完整戰棋系統實作
> **日期**:2026-09-01
> **執行者**:godot-specialist,本機直接執行 Godot 4.7.1(有實體 GPU,可跑非 headless 視窗模式)

**要驗證的假設**:`design/art/art-direction.md` 第七節列了三個待決項(世界層放大倍率、世界容器定位方式、介面設計基準畫布尺寸),目前全部沒有實測數字支撐。派工單同時要求:三個待決項的每一個選項,都要回答對 ADR-0005 VR #11b(承載自繪游標的 `CanvasLayer` 是否全程維持恆等變換)的影響,以及推導前提「`CursorStateHost` 是 Autoload、`get_viewport()` 對它應回傳根視窗」是否成立。中途追加:Cubic 11(11×11 點陣、放大 2 倍使用)在各解析度下的二次縮放是否仍落在乾淨整數格。

**中途走了一條沒人預期到的岔路,且它是本次最重要的發現**:量測介面基準畫布選項時,在 2560×1440 撞到一個anomaly(棋盤格圖案完全沒有交替色),追下去發現是**引擎本身的渲染目標尺寸問題,不是本 spike 的程式錯誤**——見下方「重大發現」。這個發現直接推翻了 Q1 待決項文字本身的前提("容器之外的空間...是介面的地盤"),所以本檔把它放在數字表格之前先講。

---

## 專案結構

```
prototypes/ui-canvas-scale-spike-2026-09-01/
├── project.godot                    # 沿用主專案實測值:480x270 / canvas_items / keep / integer / Nearest
├── scenes/
│   ├── GameRoot.tscn                # Scenario 1:專案目前的實際設定(canvas_items),根節點 Node(非 Node2D)
│   ├── GameRootScenario2.tscn       # Scenario 2:content_scale_mode 執行期強制改 DISABLED,全手動排版
│   └── DebugMarginProbe.tscn        # 追查 2560x1440 異常用的最小重現場景(兩輪)
├── scripts/
│   ├── game_root.gd                 # Scenario 1 量測驅動(Phase A~F)
│   ├── game_root_scenario2.gd       # Scenario 2 量測驅動(Q1×Q2、Q3、字型再量)
│   ├── debug_margin_probe.gd        # 追查腳本,兩輪(見下方「重大發現」)
│   ├── ui_canvas_transform.gd       # 純函式:介面基準畫布 <-> 視窗像素換算,不碰場景樹
│   └── pixel_grid_check.gd          # 純函式:棋盤格(Cubic 11 替身)整數格乾淨度量測
└── autoload/
    └── cursor_layer_sim.gd          # ADR-0005 CursorStateHost 的替身:CanvasLayer,全程未被指定 transform
```

---

## 如何執行

先 headless import 一次(讓 `class_name` 快取就緒):
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
```

三個場景各自跑完自己印完數字就 `quit()`,**不要加 `--headless`**(理由與 2026-08-27 spike 相同:`Control`/`SubViewportContainer` 的錨點與 resize 通知需要正常視窗建立流程):
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path .                                  # Scenario 1(main_scene = GameRoot.tscn)
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . scenes/GameRootScenario2.tscn     # Scenario 2
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . scenes/DebugMarginProbe.tscn      # 追查腳本
```

---

## 重大發現(超出原始問題範圍,但直接推翻 Q1 待決項文字本身的前提)

**現象**:量 Phase F(Cubic 11 替身字型的整數格檢查)時,2560×1440 這一個解析度下,無論哪個介面基準畫布選項,棋盤格圖案量出來**完全沒有交替色**(單一 run,長度等於整個取樣寬度)——1080p 與 4K 都正常,唯獨 2K 壞掉。

**追查過程**(`scripts/debug_margin_probe.gd`,場景 `scenes/DebugMarginProbe.tscn`,兩輪):

- **第一輪**:在 2560×1440 視窗下,於一層「用 `get_final_transform().affine_inverse()` 抵消世界層縮放」的 `CanvasLayer` 裡,於**絕對視窗像素座標** (50,50)-(150,150) 畫一個不透明紅色方塊,再用 `get_viewport().get_texture().get_image()` 把整個畫面截下來檢查。逐字量測結果:

  ```
  final_transform scale=(5.0, 5.0) offset=(80.0, 45.0)
  DisplayServer.window_get_size(): (2560, 1440)
  get_tree().root.get_visible_rect(): [P: (0.0, 0.0), S: (480.0, 270.0)]
  captured image size: (2400, 1350)
  ```

  **截圖尺寸是 (2400, 1350),不是視窗的 (2560, 1440)。** `2400 = 480×5`、`1350 = 270×5`——這正是 `canvas_items` + `keep` + `integer` 縮放算出來的「內部貼合矩形」,**不含四周共 (2560-2400)=160px 橫向 / (1440-1350)=90px 縱向的黑邊留白**。紅色方塊因此完全沒有畫到我原本以為的絕對視窗座標,而是被硬塞進了那個更小的座標系裡。

- **第二輪**:用 `Window` 物件的 `get()`/`set()` 動態存取(不用型別化屬性存取,理由見下方「查證方式」)確認 `content_scale_mode` 屬性存在、目前值為 `1`(對應專案 `window/stretch/mode="canvas_items"`),嘗試在執行期把它改成 `0`(預期為 `DISABLED`),結果:

  ```
  [canvas_items (project default), 2560x1440] captured image size=(2400, 1350)
  content_scale_mode current value (enum int): 1
  [content_scale_mode set to 0 (expected DISABLED), 2560x1440] final_transform scale=(1.0, 1.0) offset=(0.0, 0.0) | captured image size=(2560, 1440)
  marker at absolute window pixel (2500,1400)-(2550,1430), image size=(2560, 1440)
    sample at (2510,1410):  (1.0, 0.0, 0.0, 1.0)
  ```

  切成 `DISABLED` 後,截圖立刻變成完整的 (2560, 1440),而且原本落在「黑邊」裡的絕對座標 (2500,1400) 現在真的畫得到(取樣到純紅色)。

**結論(實測,非推理)**:在專案目前的設定(`window/stretch/mode="canvas_items"`)下,**只要 `keep`+`integer` 算出來的縮放沒有剛好填滿視窗(2K 的 5.333→5 取整、超寬螢幕的比例落差),那圈留白就是引擎渲染目標本身沒有涵蓋到的區域——不是「畫了但被蓋住」,是物理上不存在,任何 `CanvasItem`/`CanvasLayer`,不管掛什麼 `.transform`,都畫不進去。**

**這直接推翻 Q1 待決項自己的文字**(art-direction.md 第七節:「專家指出容器之外的空間**不是黑邊,是介面的地盤**」)——在目前的專案設定下,那圈空間就是黑邊,不是介面的地盤,不管選 4 倍還是 5 倍都一樣拿不到。**要讓那段話成立,`window/stretch/mode` 必須改成 `"disabled"`**(已實測驗證:切換後渲染目標立即涵蓋整個實體視窗)。這是本檔案權限範圍外的正式設定變更,**只回報,不動 `project.godot`**——即使是主專案自己的那份也不在授權範圍。

---

## 三個待決項的實測數字

### 待決項 1 + 2:世界層放大倍率 × 世界容器定位方式

**Scenario 1(專案目前實際設定,`canvas_items`)—— Phase A,自動整數縮放**(`scripts/game_root.gd`,`scenes/GameRoot.tscn`,執行於 2026-09-01):

| 視窗尺寸 | 自動縮放倍率 | 偏移(黑邊起點) | 說明 |
|---|---|---|---|
| 1920×1080(1080p) | 5.0000→**4.0000** | (0, 0) | 480×4=1920、270×4=1080,剛好整除,零黑邊 |
| 2560×1440(2K) | **5.0000** | (80.0, 45.0) | 480×5.333,取整為 5,留白 160px 橫 / 90px 縱(對半分兩側各 80/45) |
| 3840×2160(4K) | **8.0000** | (0, 0) | 480×8=3840、270×8=2160,剛好整除,零黑邊 |
| 3440×1440(超寬 21:9,邊界情況) | **5.0000** | (520.0, 45.0) | 縱向與 2K 同(1440 高一樣),橫向留白暴增到 1040px(對半兩側各 520) |

**`content_scale_factor` 是否能覆寫這個自動取整?—— 實測:不能。**(Phase B,2560×1440 下嘗試 0.8 / 0.75 / 1.25 三個值,`get_final_transform()` 的 scale 與 offset **完全不變**,維持 5.0000 / (80,45)。這個屬性確實存在〔動態 `get()` 讀到預設值 1.0〕,但它顯然不是用來覆寫 `integer` 縮放取整結果的旋鈕——本 spike 沒有進一步查它實際的用途,只確認了「不是這個」。)

**Scenario 2(`content_scale_mode` 執行期強制設為 `DISABLED`,`scripts/game_root_scenario2.gd`,`scenes/GameRootScenario2.tscn`)—— 4 倍 vs 5 倍在 2K 與超寬下的真實可用margin**,世界容器改為完全手動定位(不再有任何自動縮放):

| 視窗 | 倍率 | 定位策略 | 世界佔用矩形(視窗絕對像素) | 邊距 L,T,R,B | 一格 32px 邊長 |
|---|---|---|---|---|---|
| 2560×1440 | 4x | 置中 | (320,180)-(2240,1260) | 320,180,320,180 | 128.0px |
| 2560×1440 | 4x | 貼右邊 | (640,180)-(2560,1260) | 640,180,0,180 | 128.0px |
| 2560×1440 | 4x | 依比例動態(此處等同置中,因 2560:1440=16:9 未超過門檻) | (320,180)-(2240,1260) | 320,180,320,180 | 128.0px |
| 2560×1440 | 5x | 置中 | (80,45)-(2480,1395) | 80,45,80,45 | 160.0px |
| 2560×1440 | 5x | 貼右邊 | (160,45)-(2560,1395) | 160,45,0,45 | 160.0px |
| 3440×1440 | 4x | 置中 | (760,180)-(2680,1260) | 760,180,760,180 | 128.0px |
| 3440×1440 | 4x | 貼右邊 | (1520,180)-(3440,1260) | 1520,180,0,180 | 128.0px |
| 3440×1440 | 4x | **依比例動態(這裡真的分岔了)** | (0,180)-(1920,1260) | **0**,180,1520,180 | 128.0px |
| 3440×1440 | 5x | 置中 | (520,45)-(2920,1395) | 520,45,520,45 | 160.0px |
| 3440×1440 | 5x | 貼右邊 | (1040,45)-(3440,1395) | 1040,45,0,45 | 160.0px |
| 3440×1440 | 5x | 依比例動態 | (0,45)-(2400,1395) | **0**,45,1040,45 | 160.0px |

「依比例動態」的規則是本 spike 自訂的示範規則(超過 16:9 一定門檻就整個貼左、留右側單一大塊給介面;否則置中),**不是任何文件已定案的規則**——這裡只示範它在超寬螢幕下確實會與置中/貼邊產生不同結果(超寬時左邊距歸零,右側集中出 1520px 或 1040px 的單一 dock 空間,而不是兩側對半分散的 760/520px)。

**點驗證(spot-check)**:在 `DISABLED` 模式下,於 2560×1440、世界 4 倍置中的情境中,對「原本 `canvas_items` 模式下屬於黑邊(座標 (2300,700))」的位置畫一個標記,截圖取樣結果為純紅色 `(1.0, 0.0, 0.0, 1.0)`——**確認那塊空間現在真的畫得到、也截得到**,不是理論推算。

**渲染目標尺寸 sanity check**(4 個目標解析度全部重驗一次,確認修法不是只對 2560×1440 生效的巧合):

```
window=(1920, 1080)  captured image size=(1920, 1080)  matches_full_window=true
window=(2560, 1440)  captured image size=(2560, 1440)  matches_full_window=true
window=(3840, 2160)  captured image size=(3840, 2160)  matches_full_window=true
window=(3440, 1440)  captured image size=(3440, 1440)  matches_full_window=true
```

### 待決項 3:介面設計基準畫布尺寸

兩個候選選項各自量測:**NATIVE**(基準畫布 = 當下視窗實際解析度,無二次縮放)vs **FIXED_1920x1080**(固定 1920×1080 基準,`keep` 比例、允許非整數縮放,因為介面層規格明文「不對齊像素網格」)。

**Scenario 1(`canvas_items`,Phase D)—— `CanvasLayer.transform` 讀回值**:

| 視窗 | 選項 | 基準畫布 | layer.transform 縮放 | layer.transform 位移 | 是否恆等 |
|---|---|---|---|---|---|
| 1920×1080 | NATIVE | (1920,1080) | 0.2500 | (0,0) | **false** |
| 1920×1080 | FIXED_1920x1080 | (1920,1080) | 0.2500 | (0,0) | **false** |
| 2560×1440 | NATIVE | (2560,1440) | 0.2000 | (-16, -9) | **false** |
| 2560×1440 | FIXED_1920x1080 | (1920,1080) | 0.2667 | (-16, -9) | **false** |
| 3840×2160 | NATIVE | (3840,2160) | 0.1250 | (0,0) | **false** |
| 3840×2160 | FIXED_1920x1080 | (1920,1080) | 0.2500 | (0,0) | **false** |

⚠️ **這批數字有前面「重大發現」的陰影**:在 `canvas_items` 模式下,即使選 NATIVE(理論上想要「1 設計單位 = 1 真實像素」),`CanvasLayer.transform` 仍必須設成 `get_final_transform().affine_inverse()` 才能抵消世界層的縮放——而這個抵消動作,在 2K/超寬這種有黑邊的情境下,**永遠無法真正抵消到黑邊範圍**(那裡渲染目標根本不存在,任何 transform 都救不回來)。也就是說 Scenario 1 下,NATIVE 選項名不符實:它抵消了世界層的縮放,但沒有,也不可能,真正拿到整個實體螢幕。

**Scenario 2(`DISABLED`,Phase Q3)—— 同樣的兩個選項,乾淨重量**:

| 視窗 | 選項 | 基準畫布 | layer.transform 縮放 | 位移 | 是否恆等 |
|---|---|---|---|---|---|
| 1920×1080 | NATIVE | (1920,1080) | **1.0000** | (0,0) | **true** |
| 1920×1080 | FIXED_1920x1080 | (1920,1080) | 1.0000 | (0,0) | true(此解析度剛好等於基準,巧合) |
| 2560×1440 | NATIVE | (2560,1440) | **1.0000** | (0,0) | **true** |
| 2560×1440 | FIXED_1920x1080 | (1920,1080) | 1.3333 | (0,0) | **false** |
| 3840×2160 | NATIVE | (3840,2160) | **1.0000** | (0,0) | **true** |
| 3840×2160 | FIXED_1920x1080 | (1920,1080) | 2.0000 | (0,0) | false(但為整數倍) |

**關鍵差異**:切到 `DISABLED` 之後,**NATIVE 選項在任何解析度下 `CanvasLayer.transform` 都是真正的恆等變換**(不需要抵消任何東西,因為已經沒有東西要抵消)。FIXED_1920x1080 則**必然**在非 1920×1080 倍數的解析度下是非恆等的——這是選了固定基準畫布本身就會付出的代價,與 `content_scale_mode` 選什麼無關。

---

## VR #11b(ADR-0005):承載自繪游標的 CanvasLayer,是否維持恆等變換?

**這是本次派工的主要目的,以下逐項回答。**

### 前提查證:`CursorStateHost` 是 Autoload、`get_viewport()` 對它應回傳根視窗

**派工單原話**:「這是我從文件推導的,請你實測確認,不要當成前提照收。」

**實測結果:前提成立,未被推翻。** `autoload/cursor_layer_sim.gd` 以 `CursorLayerSim="*res://autoload/cursor_layer_sim.gd"` 的形式註冊為專案 Autoload(即掛在 `/root` 底下、與 `GameRoot` 同層,不在任何 `SubViewport` 內)。在 Scenario 1 的 Phase E,對 4 個目標解析度**逐一**呼叫 `_cursor_layer_sim.get_viewport() == get_tree().root`,逐字輸出:

```
window=(1920, 1080)  CursorLayerSim.transform=identity:true  get_viewport()==root:true
window=(2560, 1440)  CursorLayerSim.transform=identity:true  get_viewport()==root:true
window=(3840, 2160)  CursorLayerSim.transform=identity:true  get_viewport()==root:true
window=(3440, 1440)  CursorLayerSim.transform=identity:true  get_viewport()==root:true
```

四個解析度、兩項斷言全部 `true`,無一次例外。

### 每個「介面設計基準畫布尺寸」選項對 VR #11b 的影響

**做法上的關鍵前提(不管選哪個介面選項都一樣)**:`cursor_layer_sim.gd` 全程沒有任何一行程式碼指定過它自己的 `transform`/`offset`/`rotation`/`scale`——這是刻意的,測的就是「放著不管,它會不會被誰動到」。只要 `CursorStateHost` 的游標 `CanvasLayer` 是**專屬的獨立節點**、不是介面層那顆需要抵消縮放/套用基準畫布的 `CanvasLayer`,四個解析度的實測全部是 `identity:true`——**這個結論與 Q3 選 NATIVE 還是 FIXED_1920x1080 無關,因為兩者都不會去動這顆專屬 `CanvasLayer`**。

真正決定 VR #11b 安不安全的,不是 Q3 選哪個選項,而是**架構上有沒有把游標的 `CanvasLayer` 跟介面基準畫布的 `CanvasLayer` 混成同一顆**。因此逐項回答如下:

| 選項 | 若游標與介面**共用同一顆** `CanvasLayer` | 若游標**維持專屬獨立**` CanvasLayer`(本 spike 的作法) |
|---|---|---|
| NATIVE(`canvas_items` 模式) | **非恆等**,縮放係數 = `1/get_final_transform().scale`,隨解析度變動(實測 0.25 / 0.2 / 0.125) | 恆等(實測 4 解析度皆 `true`) |
| NATIVE(`DISABLED` 模式) | 恆等(實測縮放 1.0000,因為此模式下 NATIVE 的抵消運算本身就退化成恆等) | 恆等 |
| FIXED_1920x1080(任一模式) | **非恆等**,縮放係數隨解析度變動(1.0 / 1.3333 / 2.0,`DISABLED` 模式下;`canvas_items` 模式下另外疊加世界層縮放的抵消,見上表 0.25/0.2667/0.25) | 恆等 |

**若做錯了(游標共用了那顆非恆等的介面層),代價有多大?——實測量出來,不是估的。**(Scenario 1 Phase E,用 FIXED_1920x1080 那顆非恆等 layer 的 transform 去算「如果游標畫在這顆 layer 底下」,同一個測試點在正確路徑〔誤差 0.0000~0.0003px,浮點雜訊等級〕vs 錯誤路徑的螢幕位置偏差):

| 視窗 | 測試點 | 正確路徑誤差 | 若共用介面層的誤差 |
|---|---|---|---|
| 1920×1080 | 右上角 (1920,0) | 0.0000px | **1440.00px** |
| 1920×1080 | 中心 (960,540) | 0.0000px | **826.09px** |
| 2560×1440 | 右下角 (2560,1440) | 0.0003px | **2178.43px** |
| 3840×2160 | 右下角 (3840,2160) | 0.0000px | **3304.36px** |
| 3440×1440 | 右下角 (3440,1440) | 0.0003px | **2464.74px** |

**這不是「游標歪一點」,是游標完全脫離滑鼠實際位置,偏差量級是螢幕尺寸本身的量級——實質上等於游標系統整個失效。**

### 結論

**ADR-0005 的恆等變換假設,在本 spike 測試的所有情境下都可以成立,但成立與否完全取決於一個架構決定,而不是取決於 Q3 選哪個介面基準畫布**:`CursorStateHost` 持有的 `CanvasLayer` 必須是**專屬、獨立、不被任何介面基準畫布邏輯碰到**的節點。**這件事應該寫進 ADR-0005 或機制十二的實作備註裡,做成一條結構性約束(例如一個測試斷言「`CursorStateHost` 的 `CanvasLayer.transform` 全程等於 `Transform2D.IDENTITY`」),而不是只靠「不要那樣做」的紀律。**

---

## 像素字型二次縮放(Cubic 11 替身,中途追加項目)

**做法**:專案沒有 vendor 進 Cubic 11 字型檔(已確認,見下方「已知簡化」),用一張程式產生的 11×11 高對比棋盤格 `ImageTexture` 當替身,放大 2 倍(art-direction.md 第五節「放大 2 倍使用」),量測「每個來源像素在螢幕上是否映射成同一寬度的乾淨色塊」——方法沿用 `.claude/docs/coding-standards.md` 螢幕截圖證據規則第 4 條(整數縮放格網完整性)。

**Scenario 1(`canvas_items`)結果**:1080p、4K 乾淨(`combined_2x_scale` 剛好 2.0 或 4.0,整數,格網乾淨)。**2560×1440 兩個選項都量到單一 run(無交替色)——已定位為「重大發現」那個渲染目標黑邊問題造成的無效量測,不是字型本身的答案,已被 Scenario 2 的乾淨重量取代。**

**Scenario 2(`DISABLED`,乾淨、無黑邊污染)結果——這是可信的答案**:

| 視窗 | 選項 | 合併縮放(2倍 × 基準畫布縮放) | 是否整數 | 格網是否乾淨(實測) | 實測 run 長度 |
|---|---|---|---|---|---|
| 1920×1080 | NATIVE | 2.0000 | 是 | **乾淨** | [2,2,2,2,2,2,2,2,2,2,2,4] |
| 1920×1080 | FIXED_1920x1080 | 2.0000 | 是 | **乾淨** | [2,2,2,2,2,2,2,2,2,2,2,4] |
| 2560×1440 | NATIVE | **2.0000** | 是 | **乾淨** | [2,2,2,2,2,2,2,2,2,2,2,4] |
| 2560×1440 | FIXED_1920x1080 | **2.6667** | **否** | **不乾淨** | **[1,2,3,3,2,3,3,2,3,3,2,3,4]** |
| 3840×2160 | NATIVE | 2.0000 | 是 | **乾淨** | [2,2,2,2,2,2,2,2,2,2,2,4] |
| 3840×2160 | FIXED_1920x1080 | 4.0000 | 是 | **乾淨** | [4,4,4,4,4,4,4,4,4,4,4,4] |

**結論**:**NATIVE 選項下,Cubic 11 替身的 2 倍縮放在三個解析度下全部乾淨**——因為 NATIVE 的定義就是「基準畫布 = 當下實際解析度」,2 倍縮放直接套用在真實像素上,不會再疊加第二層縮放係數。**FIXED_1920x1080 只在解析度剛好是 1920×1080 整數倍時乾淨(1080p 本身、4K = 2 倍),在 2K 這種非整數倍解析度下,合併縮放變成 2.6667,量到的色塊寬度在 2px 與 3px 之間跳動(`[1,2,3,3,2,3,3,2,3,3,2,3,4]`)——這不是猜測,是實際擷取畫面逐像素量出來的。** 若「介面短標籤 / HUD 數字」用 Cubic 11 走 FIXED_1920x1080 這條路線,在 2K 螢幕上會有實際可見的鋸齒/不均勻縮放瑕疵;NATIVE 路線沒有這個問題。

---

## 逐項涵蓋範圍(做了什麼、沒做什麼)

| 項目 | 涵蓋 | 未涵蓋 |
|---|---|---|
| 待決項 1(世界層放大倍率) | 1080p/2K/4K/超寬四個解析度的自動整數縮放實測;`content_scale_factor` 覆寫嘗試(否證);`DISABLED` 模式下 4x/5x 手動選擇的真實可用邊距 | 除了 4/5 倍以外的其他倍率;`DISABLED` 模式對世界層像素級銳利度(nearest 貼齊)是否受影響——理論上不受影響(世界層縮放邏輯本身沒變,只是外層 content_scale 不同),但**沒有另外重跑一次世界層本身的整數格網檢查來確認**,是延伸推論,不是量出來的 |
| 待決項 2(世界容器定位) | 置中 / 貼右邊 / 依比例動態三種策略,在 `DISABLED` 模式下於 2K 與超寬的邊距實測 | 「依比例動態」的門檻規則是本 spike 自訂示範,不是任何文件定案的規則;沒有測試貼上/貼下(只測了貼右) |
| 待決項 3(介面基準畫布) | NATIVE / FIXED_1920x1080 兩個選項,在 `canvas_items` 與 `DISABLED` 兩種模式、四個解析度下的 `CanvasLayer.transform` 讀回值 | 其他候選基準值(例如 1280×720)完全沒測;只測了 `keep` 比例邏輯,沒測「expand/裁切」邏輯 |
| VR #11b | 游標 `CanvasLayer` 恆等性(4 解析度 × 2 種 content_scale_mode 部分覆蓋);共用介面層的量化代價;`get_viewport()==root` 前提查證 | 沒有用真實滑鼠移動驗證(全程用程式指定的測試座標模擬「假設的滑鼠位置」,原因與 2026-08-27 spike 相同:headless/自動關閉流程收不到真人操作;`Input.warp_mouse()` 這條路本 spike 沒有嘗試) |
| Cubic 11 二次縮放 | NATIVE / FIXED_1920x1080 在 1080p/2K/4K 下的合併縮放整數性與格網乾淨度(`DISABLED` 模式,乾淨量測);`canvas_items` 模式下的同一組數字(已知受黑邊問題污染,標記無效) | 真實 Cubic 11 字型檔完全沒測(專案未 vendor 進來,見下方已知簡化);沒有測超寬螢幕下的字型縮放(推論與 2K/4K 結論一致,因為超寬的高度與 1440p 相同,但**沒有實際跑這個解析度的字型格網量測**) |

---

## 已知簡化

- **Cubic 11 字型檔本身不在專案裡**(已確認:`find` 全庫搜尋 `*cubic*` 與常見字型副檔名均無結果)。用程式產生的 11×11 高對比棋盤格代替——這足以測「整數縮放格網是否乾淨」這個特定問題(任何相鄰像素顏色不同的紋理都能測這件事),但**不能**證明真正的 Cubic 11 字形在任何縮放倍率下的可讀性/美觀度,那要等字型檔案本身進專案後另外驗證。
- 「依比例動態」定位策略的門檻規則(`aspect > 16:9 + 0.01`)是本 spike 為了示範「動態規則確實會與置中/貼邊產生不同結果」而自訂的,不代表任何已核准的設計決策。
- 游標位置全程用程式指定的座標模擬,沒有真人移動滑鼠驗證(與 2026-08-27 spike 的互動模式揭露相同)。
- `content_scale_factor` 被否證為「不會覆寫 integer 取整結果」之後,**沒有再花時間查它實際的用途**——那超出本次派工範圍。
- 世界層在 `DISABLED` 模式下的像素級銳利度(nearest 貼齊、整數縮放無縫)沒有重新用棋盤格法驗證,只驗證了介面層/字型的部分;世界層的邏輯路徑本身沒有變動(仍是 `SubViewportContainer.size` 直接指定整數倍),理論上結論沿用 2026-08-27 spike 的既有結論,但這是推論,不是本次新量出來的。

---

## 建構過程中撞到的規格問題(如實記錄,不代表結論)

1. **`content_scale_mode` / `content_scale_factor` 這兩個 API,`docs/engine-reference/godot/` 底下沒有任何一份文件記載**——與 2026-08-27 spike 撞到的 `get_final_transform()` 系列 API 是同一類缺口。本次全部改用動態 `get()`/`set()` 存取(而非型別化屬性存取),原因是若屬性名稱猜錯,型別化存取會在**剖析期**直接報錯讓整個場景載入失敗;動態存取則是安全的探測方式,查不到會回傳 `null` 而不是讓程式崩潰。
2. **「重大發現」那個黑邊渲染目標問題,推翻了 art-direction.md 第七節 Q1 待決項自己的文字前提**——這是本次撞到的最大規格問題,已在上方獨立成節說明,這裡不重複。
3. 追查黑邊問題花了兩輪 debug 探針(`debug_margin_probe.gd`)才定位到根因,過程中第一輪的假設(以為是自己的座標數學算錯)被第二輪的對照實驗(切換 `content_scale_mode` 前後截圖尺寸的直接對比)推翻——如果只看第一輪的紅色方塊位置偏移,很容易誤判成「我的 `canvas_layer_transform_for()` 公式寫錯」,而不是「這塊區域物理上畫不到」。

---

## 狀態

**已完成(2026-09-01)**。三個待決項在 1080p/2K/4K/超寬(邊界情況)下的實測數字已取得(待決項 1、2 額外覆蓋了「專案目前設定 `canvas_items`」與「改為 `disabled`」兩種情境,因為兩者的答案不同,且中途發現前者會讓 Q1 待決項文字本身的前提不成立)。VR #11b 判定為**條件成立**:恆等變換在所有測試情境下都能維持,但條件是「游標 `CanvasLayer` 必須是專屬節點,不與介面基準畫布共用」,這與 Q3 選哪個選項無關。`CursorStateHost` 前提(Autoload、`get_viewport()` 回傳根視窗)實測確認成立,未被推翻。Cubic 11 二次縮放:NATIVE 選項在三個解析度下全部整數乾淨,FIXED_1920x1080 選項在 2K 下量到實際的格網不均勻瑕疵。
