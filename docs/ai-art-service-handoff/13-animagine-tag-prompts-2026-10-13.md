# 第十三份：Animagine XL 3.1 標籤式 Prompt 改寫（2026-10-13）

## 0. 裁決來源與本文件範圍

管理者已裁決採 `12` 號文件候選一 **Animagine XL 3.1**，並已知情兩項代價（換底模需重寫
prompt 格式、授權條文未觸及輸出圖像商用）後選擇照走。**本文件不重新評估要不要換底模，
也不重新談授權** —— 只做一件事：把現行自然語言 prompt（正向 910 字元、負向 806 字元，
見 `09` 號文件第六、四節）改寫成 Animagine 系列慣用的標籤式（tag-based）寫法。

美術硬參數（扁平三階 cel-shade、外輪廓單線、內部不描邊、64 色色票、1px 非純黑描邊）
**原樣保留，只換表達形式**，依據 `06a` 第 1、2 節。

🔴 **本機尚未裝、也沒跑過 Animagine XL 3.1。** 下方第 2 節「已查到的慣例」是公開官方
README 與社群指南的查證結果（已附來源，查證日期 2026-10-13），**但這些標籤套進本服務
後會不會依文獻描述運作、是否符合我方畫風期待，完全未經本機驗證**，屬 (C) 級（訓練資料/
外部文件推測，未經本機實測）。本文件是「等底模裝好就能拿去試」的材料，不是已驗證的結論。

## 1. 現行自然語言需求 → 標籤對照表

| # | 現行自然語言需求 | 標籤式寫法 | 備註 |
|---|---|---|---|
| 1 | 2D game character concept art | *(無對應標籤，依賴模型本身插畫傾向)* | 刻意丟掉，見下節 |
| 2 | flat cel-shaded illustration | `cel shading, flat color` | — |
| 3 | bold outline on outer silhouette only | `bold outline` | **精度流失**：「只在外輪廓、不含內部」這個限定詞沒有對應標籤，見下節 |
| 4 | no internal seam outlines | *(無正向標籤)* | 改在負向加 `detailed linework, cross-hatching` 間接抑制，無法正向保證 |
| 5 | three-tone cel shading | `cel shading` | **精度流失**：「三階」這個數量限定沒有對應標籤 |
| 6 | no soft gradient | 負向：`soft shading`（見第 2 節建議負向基準已含類似字） | — |
| 7 | strong clear silhouette | *(無直接標籤)* | 依賴 `solo` + `simple background` 間接達成，刻意丟掉顯式標籤 |
| 8 | East Asian features, contemporary Taiwan setting | `east asian` | ⚠️ 未逐一查證此標籤在 Danbooru 詞彙庫裡的收錄/訓練量，風險見第 6 節；「contemporary Taiwan setting」整段丟棄（見下節） |
| 9 | single isolated character, centered | `1girl, solo` | — |
| 10 | soft even studio lighting from upper-left | *(丟棄)* | 見下節 |
| 11 | sharp focus | `sharp focus` | 非純 booru 詞彙，社群常見混用寫法，效果未個別驗證 |
| 12 | standing idle pose | `standing` | — |
| 13 | front-facing three-quarter turn | `three-quarter view` | ⚠️ 未逐一查證此確切字串是否為慣用標籤，較常見的替代是 `from side`/`from behind` 這類固定方位詞，`three-quarter` 的精確命中率未知 |
| 14 | arms and feet visible | `full body` | `full body` 是慣用且可靠度較高的標籤，間接涵蓋此需求 |
| 15 | orthographic framing | *(丟棄)* | 見下節 |
| 16 | solid flat magenta background (#FF00FF) | `simple background, magenta background` | 獨立成節，見第 5 節 |
| 17 | no scenery / no background shadow / no gradient background | 負向：`scenery, gradient background, shadow on background` | — |
| 18 | generous padding around character | *(丟棄)* | 見下節 |
| 19 | young adult Taiwanese woman | `1girl, adult woman` | 🔴 2026-10-13 管理者裁決推翻「不加標籤」，改採 `adult woman`（自由文字片語，非確認過的標準標籤，效果未知）——理由見表下新增註記 |
| 20 | athletic build | `athletic build` | 非標準 booru 詞彙，混用寫法，效果未驗證 |
| 21 | dark hair in tight ponytail | `black hair, ponytail` | — |
| 22 | determined expression | `serious expression` | 換成較常見的標籤用詞 |
| 23 | confident posture | *(丟棄)* | 見下節 |
| 24 | navy-blue tactical firefighter uniform | `firefighter, navy blue uniform` | — |
| 25 | gear harness | `harness` | 🔴 2026-10-13 管理者裁決推翻 `utility belt`，改回 harness 系——理由見表下新增註記 |
| 26 | fingerless gloves | `fingerless gloves` | 標準標籤 |
| 27 | sturdy boots | `boots` | — |
| 28 | holding firefighter breaching axe on shoulder | `holding axe, axe on shoulder` | — |
| 29 | steel-gray metal fittings, silver axe head | `silver axe, steel gray trim` | — |

### 刻意丟掉的需求，以及為什麼

1. **方向性打光（上左 45 度）、正交取景、角色周圍留白量** —— 標籤式詞彙庫沒有可控的
   精確方位/留白控制概念（這類精細構圖控制在 booru 標籤系統裡幾乎不存在，通常要靠
   ControlNet 或後製裁切解決，兩者都超出本次「只換表達形式」的範圍）。**這些需求目前
   完全無法用標籤表達，不是我選擇省略，是工具本身的限制。**
2. **「只在外輪廓、不含內部」「三階」這類精確限定詞** —— 標籤系統的粒度是「有沒有這個
   概念」（有描邊/沒描邊），不是「這個概念的精確範圍是什麼」。這個精度流失是結構性的，
   換回正式美術管線的把關在後製量化那一步（06a 第二節既定設計），不是生圖端的責任。
3. **`gear harness` 不用 `harness`** —— `harness` 在 booru 詞彙庫裡高頻與角色扮演/
   束縛類內容共現，對照約束 #3（不得引入授權或內容風險標籤），改用語意更中性的
   `utility belt`。
4. **不加任何年齡/成熟度標籤**（例如 `mature female`、`teenager` 這類）——同樣是約束 #3
   的理由：這類標籤在 booru 系統裡的訓練關聯常偏向成人向內容，而 `1girl` 本身已足以
   表達「女性角色」，不需要額外標籤承擔不必要的風險。
5. **「contemporary Taiwan setting」整段丟棄** —— 這句原意是角色打扮的時代/地域語境
   （非奇幻、現代），但標籤系統沒有「現代台灣」這個概念，而且若誤用地名類標籤，更可能
   被模型解讀成要畫場景地標（違反「no scenery」）。判斷留白比亂猜一個標籤安全。

### 2026-10-13 管理者裁決：推翻上方第 3、4 點，維持第 5 點

協調者把上方第 3、4 點的原始做法與理由逐字呈給管理者，並各自附上代價分析/反對意見。
**本節只加註，上方第 3、4、5 點原文一字未刪** —— 兩邊的理由都留著，供日後查對。

| 項目 | 本文件原做法 | 原理由（上方第 3/4 點） | 管理者裁決 | 推翻/維持的理由 |
|---|---|---|---|---|
| `gear harness` | 改用 `utility belt` | 避開 `harness` 在 booru 語料的不良共現關聯 | 🔴 **推翻，改回 harness 系標籤** | 協調者指出本文件先前沒講的代價：背帶在肩胸、腰帶在腰部，**改變角色剪影**——而「strong clear silhouette」是我方硬需求，最終成品是 32×40 棋子，剪影就是辨識度的全部。管理者選擇「先照規格走，出問題再修」，並跳過「`shoulder strap`/`chest rig` 這類中性替代」的折衷方案（理由：這類複合詞未查過在 booru 語料的命中率，`harness` 是確認過的高頻標籤） |
| 年齡/成熟度標籤 | 完全不加 | 避開 `mature female` 等標籤的成人向語料關聯 | 🔴 **推翻，加上「成年」類標籤** | 協調者提出方向相反的風險（其明文標注為未在本底模實測的判斷）：動畫底模的 `1girl` 在無年齡修飾時預設偏年輕畫風，「young adult」角色可能被畫成少女——對商業遊戲而言，角色顯得更年幼是更敏感的方向，不是更安全。兩種風險（成人向關聯 vs. 偏年輕畫風）可能同時成立，管理者裁決此事該由管理者定奪，不該由任一方單方面決定 |
| `contemporary Taiwan setting` | 整段丟棄 | 標籤系統無「現代台灣」概念，恐誤觸發場景標籤 | ✅ **維持原做法** | 無異議 |

**2026-10-13 第二輪查證結果（執行上述裁決時新查到的事實）：**

1. **`harness` 標籤的選擇，以及一項新查到、強化原本疑慮的事實**：Danbooru wiki
   （`https://danbooru.donmai.us/wiki_pages/harness`）確認 `harness` 是真實存在、
   被分類在服飾配件群組的標籤，且**官方 wiki 原文明寫**：「in fashion, where it can
   be intricate and fetish-inspired」。這不再是本文件單方面的揣測，是查證到的事實——
   **原本第 3 點要避開的風險是真的，管理者是在知道它是真的之後，仍選擇照規格走**。
   wiki 另有更窄義的 `chest_harness`（定義：「worn specifically on the chest」），
   語意上更貼近「胸前裝備背帶」，但「專指胸部」這個限定讓它在同一方向的風險判斷上更高，
   故本文件維持選用較通用的 `harness`，不選 `chest_harness`，也不採用未經查證是否為
   真實標籤的複合詞 `gear harness`/`tactical harness`。
2. **年齡標籤：查證後找不到一個能乾淨表達「年輕成年、非熟齡」的標籤**，兩個最直觀的
   候選分別查證後判定都不合用：
   - `adult`（Danbooru wiki）：語意前提是「角色外觀偏離其官方/原作年齡設定」，典型
     用法是「把官方設定是未成年的角色畫成成人版本」。**我方是原創角色，沒有「官方年齡
     設定」可供偏離，這個標籤的語意前提在本案不成立，很可能無效或被模型忽略。**
   - `mature female`（Danbooru wiki）：明確定義為「30 代後半以上，MILF/DILF 範疇」——
     **直接對準原本第 4 點要避開的「熟女」方向，比完全不加標籤更糟，不是更安全。**
   - 另查到社群指南建議用自由文字片語 `adult woman` / `beautiful adult woman`
     （非嚴格 booru 標籤，混合式寫法）引導成年外觀，但**這不是一個查證過在 Danbooru
     訓練語料裡有固定關聯強度的標籤字串，效果未知**。
   **誠實結論，回報管理者**：沒有找到查證過、語意乾淨對應「年輕成年」的標籤。本文件
   第 3 節/第 5.3 節採用 `adult woman`（自由文字片語，非嚴格標籤）作為**目前查得到的
   最接近選項**，但這是「查不到乾淨答案、兩個直觀候選都被排除後的次佳嘗試」，不是
   「確認有效的解法」，請管理者在這個理解下看待它。

## 2. Animagine XL 3.1 已知慣例

### 2.1 已查證（官方 README / 社群整理指南，2026-10-13 查證，非本機實測）

- **品質標籤**：`masterpiece`（評分 >150）、`best quality`（100–150）、`high quality`
  （75–100）……等級距，數字是訓練時依美學評分綁定的門檻，非可調參數。
- **美學標籤**：`very aesthetic`（>0.71）、`aesthetic`（0.45–0.71）、`displeasing`
  （0.27–0.45）、`very displeasing`（≤0.27）。
- **評分（rating）標籤**：`safe`＝一般向、`sensitive`＝略敏感、`nsfw`＝questionable、
  `explicit, nsfw`＝explicit。**本案一律採 `safe`**，直接對應約束 #3（商業遊戲、不引入
  內容風險）。
- **官方建議正向前綴**：`masterpiece, best quality, very aesthetic, absurdres`。
- **官方建議負向基準**：`nsfw, lowres, (bad), text, error, fewer, extra, missing,
  worst quality, jpeg artifacts, low quality, watermark, unfinished, displeasing,
  oldest, early, chromatic aberration, signature, extra digits, artistic error,
  username, scan, [abstract]`。
- **標籤順序建議**：`1girl/1boy, 角色名, 出處作品, 其餘標籤任意順序`。本案是原創角色、
  無出處作品，故省略中間兩段。
- **建議取樣參數**：CFG 5–7、步數 <30、採樣器 Euler a —— ⚠️ **這與本機服務目前固定
  `scheduler=normal`、無 Karras 的限制如何搭配，超出本文件範圍**，見 `12` 號文件
  候選一第 4 點，留給下一步驗證。
- **品質/評分標籤順序本身有矛盾未解**：查到的資料裡，一處文字寫「prepend」（放最前），
  但官方範例字串裡品質標籤卻擺在最後。本文件選擇放最前（見第 3、4 節），**這是我方的
  選擇，不是確認過的官方定論**。

### 2.2 未查證、本文件自行推導的標籤（全部屬 (C) 級）

第 1 節對照表裡標「⚠️ 未逐一查證」的項目（`east asian`、`three-quarter view`、
`athletic build`、`sharp focus` 等）**沒有個別去查它們是否為 Danbooru 訓練語料裡的
高頻標籤**——本次只查證了標籤系統的結構性慣例（順序、品質/評分標籤、負向基準），
沒有逐詞查證內容標籤的命中率。**不要把這些當成確認過的慣例引用。**

### 來源

- [cagliostrolab/animagine-xl-3.1 README](https://huggingface.co/cagliostrolab/animagine-xl-3.1)
- [Animagine XL V3.1 Complete Guide](https://zhonguncle.github.io/blogs/61ab08c2ae947939d5414717fdb5a93f.html)
- [Optimizing Animagine XL 4.0 guideline](https://cagliostrolab.net/posts/optimizing-animagine-xl-40-in-depth-guideline-and-update)（含 3.x 系列延續的標籤慣例說明）

## 3. 正向 Prompt（標籤式，洋紅背景版）

```
masterpiece, best quality, very aesthetic, absurdres, safe, 1girl, solo, adult woman, east asian, black hair, ponytail, serious expression, athletic build, standing, full body, three-quarter view, facing viewer, firefighter, navy blue uniform, harness, fingerless gloves, boots, holding axe, axe on shoulder, silver axe, steel gray trim, cel shading, flat color, bold outline, simple background, magenta background
```

**撰寫者人工估算：414 字元**（逐 token 長度 + 逗號分隔符累加，手算，未用程式精算）。
🔴 **此數字為人工估算，待協調者程式精算，不得當成確定值引用。**
🔴 **2026-10-13 更新**：相較原版 406 字元，新增 `adult woman`（+13，含新增的分隔逗號）、
`utility belt`→`harness`（−5），淨變化 +8，與原估算吻合（406+8=414）。

## 4. 負向 Prompt（標籤式）

```
nsfw, lowres, (bad), text, error, fewer, extra, missing, worst quality, jpeg artifacts, low quality, watermark, unfinished, displeasing, oldest, early, chromatic aberration, signature, extra digits, artistic error, username, scan, [abstract], photorealistic, realistic, multiple girls, multiple boys, duplicate, extra limbs, extra arms, extra legs, fused fingers, missing fingers, deformed hands, mutated hands, bad anatomy, detailed linework, cross-hatching, reference sheet, turnaround, multiple views, grid, kneeling, crouching, sitting, action pose, dynamic angle, scenery, complex background, gradient background, shadow on background, patterned background, close-up, cropped
```

**撰寫者人工估算：680 字元**（同上手算方式）。
🔴 **此數字為人工估算，待協調者程式精算，不得當成確定值引用。**

前段（`nsfw` 到 `[abstract]`）照抄第 2.1 節官方建議負向基準；後段是把現行自然語言負向
prompt（606 字元原文 + 09 號文件第四節追加的 198 字元）裡的失敗模式逐條改寫成標籤
（裝備設定圖、跪姿、多人構圖、肢體畸形等），並新增 `detailed linework, cross-hatching`
呼應第 1 節第 4 項（無內部描邊）的間接防線。

## 5. 洋紅背景專節

### 5.1 背景現況

`09` 號文件問題三記載：洋紅背景（`#FF00FF`）在 SDXL base 1.0 上**全部 12 張失效**
（第一輪 8 張 + rev2 四張，邊界洋紅像素皆為 0）。**換底模後這項會不會生效是未知數**，
原因：Animagine 的訓練語料是插畫/二次元圖像，`simple background` 與色名背景標籤
（`white background`、`blue background` 等）在這類語料中是高頻、可靠度較高的標籤，
理論上遵循度應優於自然語言句子裡的十六進位色碼描述——但 `magenta background` 本身
在訓練語料裡的出現頻率未查證，**這是推論不是驗證**。

### 5.2 主案：洋紅背景

第 3 節正向 prompt 結尾的 `simple background, magenta background` 即為主案，不需
額外修改。**建議理由**：`simple background` 是極高可靠度的標籤（幾乎必定產出純色/
極簡背景），疊加色名標籤的失敗風險應低於純文字句子描述，值得先試。

### 5.3 備案：白底 + 後製邊界泛洪去背

若 `magenta background` 重演失效，備案為把第 3 節 prompt 最後兩個標籤換成
`simple background, white background`：

```
masterpiece, best quality, very aesthetic, absurdres, safe, 1girl, solo, adult woman, east asian, black hair, ponytail, serious expression, athletic build, standing, full body, three-quarter view, facing viewer, firefighter, navy blue uniform, harness, fingerless gloves, boots, holding axe, axe on shoulder, silver axe, steel gray trim, cel shading, flat color, bold outline, simple background, white background
```

**撰寫者人工估算：412 字元**（比主案少 2 字元，`white` 比 `magenta` 短；同主案套用
2026-10-13 的 `adult woman` 新增與 `harness` 代換）。
🔴 **同樣待協調者程式精算。**

此版本不依賴精確色鍵匹配——去背改用 `09` 號文件第三節方案 (c)「取樣各圖實際邊界色
再做邊界泛洪」，因為 `white background` 加 `simple background` 的組合預期能穩定產出
乾淨單色背景，即使實際色值不是純白，泛洪法仍可取樣該色再去背，不需要色鍵精確命中
`#FFFFFF`。

**建議**：第一批驗證同時跑兩版，各出 1 組樣本，直接比較洋紅版是否生效；不需要等洋紅版
確認失敗才跑白底版，兩版互不依賴。

## 6. 已知未驗證前提彙整

- 本機未裝、未跑過 Animagine XL 3.1，整份文件屬 (C) 級（第 0 節已聲明）。
- 第 2.2 節列出的內容標籤（`east asian`、`three-quarter view`、`athletic build` 等）
  只查證過整體標籤系統慣例，沒有逐詞查證各別標籤的收錄情形或命中率。
- `magenta background` 在訓練語料中的出現頻率查不到，第 5 節的「理論上應優於純文字
  描述」是推論，不是查證結果。
- 品質/美學標籤該放 prompt 最前還是最後，查到的資料本身不一致（第 2.1 節已註記），
  本文件選擇放最前，未經驗證何者效果較好。
- 本機服務 scheduler 固定 `normal`、無 Karras，與官方建議採樣參數的搭配效果未驗證，
  明確排除在本文件範圍外。
- 🔴 **2026-10-13 新增兩項，兩者皆為管理者知情下的裁決，不是待修的缺陷**：
  - `harness` 標籤經 Danbooru wiki 查證，**官方定義本身即標注其語意偏 fetish 向**——
    這項風險是真實、已查證的，管理者在知道後選擇照規格走（優先保住剪影辨識度），
    「出問題再修」是明文的處置方式，不是沒人注意到。
  - `adult woman` 是查無乾淨標籤後的次佳嘗試（自由文字片語，非確認過的標準標籤），
    `adult`、`mature female` 兩個直觀候選皆經查證判定不合用（理由見第 1 節表下新增
    註記）。**它有沒有效果、會不會把角色畫得更年長或完全沒有作用，未經本機驗證。**
  兩項請在下一步實際出圖驗證時優先核對：背帶/腰帶是否破壞 32×40 剪影可辨識度、
  `adult woman` 是否確實把外觀推向「年輕成年」而非無效或推向「熟齡」。
