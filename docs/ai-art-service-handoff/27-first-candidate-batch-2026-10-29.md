# 27 號:第一批候選圖 -- 5 位角色 x (立繪 + 棋子) x 3 張 = 30 張(2026-10-29)

- **撰寫**:公司端(委託方)。prompt 由 art-director 起草,協調者查證、產生工單並推送。
- **回覆對象**:`26a-owner-decisions-on-comparison-2026-10-29.md`
- **工單**:`queue/jobs/20261029-001-*` ~ `20261029-030-*`(30 張),由本倉庫外的產生器 `build-jobs.js` 產出;
  協調者已對 30 個檔逐一 `jq` 驗證(`generation.prompt` 非空、目錄名 = `job_id`、無 BOM),長度實測見 5.4。
- **生成參數**取自貴方 10/28~29 實際跑過的紀錄(`2026-10-28-base-model-comparison/records/comparison_jobs.json` 的 RongHua 立繪、
  `2026-10-29-piece-model-search/records/arthemy_jobs.json` 的棋子):steps 30、`dpmpp_2m`、`native_only`;立繪 1024×1024、棋子 896×1152。

## 一、四句話摘要

1. 第一批 30 張:甲乙丙丁戊各 3 張立繪 + 3 張棋子,seed 固定、可重現,立繪用 `ronghua-v4.5`(CFG 3.5),棋子用 `arthemy-comics-v2.0`(CFG 4)。
2. 立繪背景改平塗中性灰、之後 AI 去背(取代 `art-tone-direction.md` 第一節的「陰暗朦朧背景」);棋子同為平塗灰底、不得是真人風格。
3. 立繪是胸像(head and shoulders,依 26 號與 `art-direction.md` 第二節「基礎胸像」),不帶手持物;斧頭握法 0/12 全錯,本批把「肩扛」拿掉,握法測試只在棋子上做,甲的 3 張棋子 seed 各試一種新握法。
4. 待機幀做法 A 我方有條件同意(第九節);Arthemy 出處是日後製作人員名單的義務(第八節),不影響本批出圖。

## 二、引用 26a 裁決(協調者已對照 26a 原文)

| 項 | 裁決 | 本批如何落實 |
|---|---|---|
| 立繪底模 | `ronghua-v4.5`,CFG 3.5,seed 7002「像台灣人」OK | 全部立繪 job 用此模型與 CFG |
| 棋子底模 | `arthemy-comics-v2.0`,CFG 4 | 全部棋子 job |
| 棋子風格 | 不得是真人風格 | 正向寫 `hand-drawn comic illustration, not photographic, not a real person`;負向擋 `photograph, photorealistic` |
| 臉對齊 | 「試了再說」 | 本批**不做**臉對齊(無 LoRA/參考圖);3 張候選即是「試」,管理者看完再決定 |
| CR-002 | 暫停已解除 | 本批可正常出圖 |
| 待機幀 | 暫定做法 A | 第九節 |
| 受擊閃爍 | 遊戲程式處理 | 本批不要求家用端做閃爍幀 |
| 10/28 另裁 | 立繪透明去背、平塗中性灰底 | 見第三節 |
| 10/29 裁決 | 第一批 5 人 x 立繪+棋子 x 3;Arthemy 出處標在製作人員名單 | 本文件範圍;第八節 |

## 三、共同規則

- **模型/CFG**:立繪 `ronghua-v4.5` / 3.5;棋子 `arthemy-comics-v2.0` / 4。steps 30、`dpmpp_2m`、`native_only`;立繪 1024×1024、棋子 896×1152(與貴方 10/28~29 實跑相同)。
- **背景**:兩種素材都寫 `plain flat neutral gray background`,不要洋紅、不要場景;去背走家用端本機 AI 去背(`--alpha-mask`,2026-10-27 裁決)。**這同時推翻 `art-tone-direction.md` 第一節「陰暗朦朧氣氛背景」**(該檔我沒改,見回報)。
- **氣氛**由光線與色彩承擔(低調光、單一硬光源、降飽和冷色),不靠背景。
- **皮膚**:10/28 管理者回饋「P2 膚色太黑」,故每條都寫 `natural East Asian skin tone, light warm complexion, not tanned`,負向擋 `dark tanned skin, orange skin`。丙(山老鼠)我沒有寫曬黑,只寫 `weathered face`。
- **不指名**任何在世畫師/工作室/作品/角色;全 ASCII;正/負各 <= 1600 字元(產生器會 throw)。
- **棋子比例**:`adult body proportions about five heads tall, not chibi`(`art-tone-direction.md` 第一節禁 Q 版);細節寫 `readable at 32x40 pixels`。⚠️ 五頭身在 32x40 下頭只有約 8px 高,臉部細節幾乎全丟 -- 這是設計推理,管理者看圖後可能要改成四頭身(見待裁決 3)。
- ⚠️ **prompt 分段**:兩個底模都是 SDXL 系(26a 放寬的是條件 3「東亞臉」,不是條件 1「SDXL」)。依貴方 25 號報告,CLIP 是**分段**不是截斷,但 pooled 只取第 1 段。本批把「主體 + 角色外觀 + 手持物握法」排在最前、風格在最後;**棋子最重要的平塗、粗外框落在後段**。若第一批棋子不平塗,請在交付時註明,我方會把風格詞前移再試。

## 四、斧頭握法處理

**事實**:26 號把握法移到 prompt 開頭,仍 0/12 全錯(管理者:「P4 斧頭拿反了」)。
**我的推理(非實測)**:`on shoulder` 要求刃口朝後、柄跨過肩,模型最容易把斧頭倒過來;`holding axe` 也沒指定「手在柄的哪一端、斧頭朝哪」。
**立繪不帶斧頭(判斷)**:立繪是胸像,看不到手與斧頭全貌;帶出一截柄或斧頭反而增加「半露斧頭又拿反」的風險,而斧頭不是對話畫面辨識甲的必要物(制服、背帶、馬尾已足夠)。握法測試因此只在棋子上做;負向 `NEG_AXE` 也只加在棋子。胸像看不到的手套、靴子、腰帶也一併從立繪 prompt 拿掉。
**斧頭構造(已更正)**:消防破門斧的鎬尖在斧頭上、與刃口相對,不在柄尾。`AXE_DESC` 已改為斧頭在柄的一端、一側刃口、另一側鎬尖。
**做法**:不再出現 `on shoulder`;每個握法都把「手在哪、斧頭在哪」寫成**解剖上無歧義**的位置,並加負向 `axe held backwards / gripping the axe head / upside down axe`。**甲的 3 張棋子** seed(s8101/8102/8103)各用一種(其餘角色三張同握法):

| seed | 握法 | 為什麼可能比較不錯 |
|---|---|---|
| 棋子 s8101 | 單手握柄尾端、斧頭朝下垂在身側 | 「斧頭在下、手在柄尾」是重力決定的唯一姿勢,不存在可倒過來的方向 |
| 棋子 s8102 | 雙手疊在柄尾上、斧頭立地在身前(拄斧) | 同上,且雙手位置明確 |
| 棋子 s8103 | 雙手空著,斧用背帶斜背在身後、斧頭露出肩上 | **完全沒有「握法」要出錯**;代價是斧頭只剩一小塊露在肩後,棋子 32x40 剪影幾乎認不出它是斧 |

**這需要管理者裁決**:若 3 種全錯,是否接受「斧頭不握在手上」(背/掛腰)為永久設計(待裁決 1)。三種各一張同時是診斷:全錯代表問題在斧頭本身而非握法措辭。

## 五、逐字 prompt

**組裝規則**(產生器與本節同一規則,**以產生器輸出為準**):
`prompt = PREFIX + ", " + 角色外觀 + ", " + 手持物 + ", " + STYLE`;`negative = NEG + (甲才加) NEG_AXE`。

### 5.1 立繪區塊(`ronghua-v4.5`,CFG 3.5)

PREFIX:
```
bust shot, head and shoulders portrait, slight three-quarter view, single adult character, solo
```
立繪組裝為 `PREFIX, 胸像外觀(c.bust), STYLE`,**無手持物**。
STYLE:
```
semi-realistic character illustration, clear facial structure, natural East Asian skin tone, light warm complexion, not tanned, soft rendered shading with gentle gradients, dim low-key lighting from a single hard-edged source, large shadow areas, muted desaturated cool palette, weary guarded expression, worn clothing with subtle stains and scuff marks, plain flat neutral gray background, no scenery, no background shadow, strong clear silhouette, head and shoulders fully visible with a little padding around the character
```
NEG(立繪)= `NEG_COMMON` + `, full body, wide shot, photograph, 3d render, doll, plastic skin`。`NEG_COMMON`(逐字,已移除 `cropped, out of frame, close-up, bust only`,否則與胸像互相打架):
```
chibi, cute, cheerful smile, bright vivid colors, pastel colors, pristine spotless clothes, multiple people, extra limbs, extra fingers, deformed hands, bad anatomy, text, watermark, logo, signature, scenery, complex background, gradient background, patterned background, shadow on background, reference sheet, multiple views, revealing clothing, dark tanned skin, orange skin, gripping the blade, tool held by its head, reversed tool, upside down tool, floating tool
```
NEG_AXE(**只加在甲的棋子**,接在 NEG 後):
```
, axe held backwards, axe blade facing the wrong way, gripping the axe head, upside down axe, axe floating
```

### 5.2 棋子區塊(`arthemy-comics-v2.0`,CFG 4)

PREFIX:
```
single adult character, solo, full body standing idle pose, front-facing three-quarter view
```
STYLE:
```
hand-drawn comic illustration, not photographic, not a real person, adult body proportions about five heads tall, not chibi, flat cel shading with three tone steps, hard-edged flat color shapes, no soft gradient, bold dark outline around the outer silhouette only, no internal outlines, simplified bold shapes that stay readable at 32x40 pixels, few small details, natural East Asian skin tone, light warm complexion, muted desaturated colors, weary guarded posture, plain flat neutral gray background, no scenery, no background shadow
```
NEG(棋子)= `NEG_COMMON` + 以下(`cropped, out of frame, close-up, bust only` 移到這裡):
```
, cropped, out of frame, close-up, bust only, photograph, photorealistic, soft shading, gradient shading, detailed linework, cross-hatching, internal outlines, soft shadows
```
(以 `build-jobs.js` 的 `NEG_PIECE` 為準。)

### 5.3 五位角色外觀與手持物

**下表「外觀」為棋子用(全身)。立繪用胸像版 `bust`(拿掉手套、靴子、腰帶、手持物),逐字在 `build-jobs.js` 各角色的 `bust` 欄**;胸像保留看得見的識別物(甲背帶與制服反光條、乙反光領章與急救包肩帶、丙肩上繩圈、丁肩上無線電、戊棕紅外套)。**手持物只用於棋子。**

| 角色 | 外觀(棋子,逐字) | 手持物(棋子,逐字) |
|---|---|---|
| 甲 藍亭萱 | `young adult Taiwanese woman, athletic build, black hair in a tight ponytail, determined weary expression, navy blue firefighter jacket and trousers with faded reflective stripes, fingerless tactical gloves with worn-white knuckles, sturdy scuffed boots, chest gear harness straps` | 三張三種,見 `build-jobs.js` 的 `weapons[0..2]`(第四節表) |
| 乙 徐培恩 | `young adult Taiwanese man, lean steady build, short neat black hair, calm composed expression, beige-gray paramedic uniform, dirty-edged first aid pack on the hip, reflective collar patch, dark work gloves, dark work boots` | `holding a long-handled steel bolt cutter low at his side in one hand, hand gripping the end of the handles, the cutting jaws pointing down toward the floor` |
| 丙 董振豪 | `adult Taiwanese man in his thirties, thin wiry build, weathered face with stubble, wary guarded gaze, worn dark brown work jacket with mud stains, patched olive-brown trousers, coil of rope over one shoulder, scuffed hiking boots, cloth-wrapped hands` | `holding an old long-barreled hunting rifle diagonally across his chest with both hands, one hand on the stock near the hip and one on the forestock, the muzzle pointing up and to the side` |
| 丁 秦亦柔 | `young adult Taiwanese woman, slim build, black hair in a low neat bun, serious watchful expression, dark navy-black police uniform, duty belt, shoulder radio, scuffed black boots` | `holding a service pistol low in both hands pointed at the ground, finger resting straight along the frame, the pistol not pointed at the viewer` |
| 戊 麥子健 | `adult Taiwanese man in his thirties, wiry build, slicked-back black hair, calm calculating half-lidded gaze, warm brown-red open-collar jacket over a dark shirt, loose dark trousers, worn leather shoes` | `holding a machete low in one hand at his side, hand gripping the handle at the top, the blade pointing down along his leg` |

甲的斧頭描述 `AXE_DESC`(逐字,已更正鎬尖位置):`a long straight wooden-handled fire axe, the small steel axe head at one end of the handle with a cutting blade on one side and a pointed pick spike on the opposite side of the head`。

### 5.4 長度(協調者實測,`build-jobs.js` 輸出,全 ASCII)

| 工單 | 正向 | 負向 |
|---|---|---|
| 甲立繪 001~003 | 834 | 532 |
| 甲棋子 004 / 005 / 006 | 1237 / 1234 / 1209 | 745 |
| 乙立繪 007~009 / 棋子 010~012 | 834 / 1009 | 532 / 639 |
| 丙立繪 013~015 / 棋子 016~018 | 801 / 1069 | 532 / 639 |
| 丁立繪 019~021 / 棋子 022~024 | 784 / 953 | 532 / 639 |
| 戊立繪 025~027 / 棋子 028~030 | 784 / 954 | 532 / 639 |

最長 1237,低於 1600 上限。**以工單檔內的逐字 prompt 為準**(本節第 5.1~5.3 是組裝規則的說明)。

## 六、Seed / 工單清單

seed 規則:立繪 `7000 + 角色序*100 + 1..3`(甲=1…戊=5),棋子 `8000 + ...`。例:甲立繪 7101/7102/7103、戊棋子 8501/8502/8503。**全部固定。** 注意 26a 的 7002 對應的是舊 prompt,本批 prompt 已不同,**不要期待 7002 重現**。

job_id = `20261029-NNN-<key>-<portrait|piece>-s<seed>`,NNN 由 `start_serial` 起連號(預設 001~030);若 AI_IMG 當天已有同號,協調者改 `start_serial`。key = jia / yi / bing / ding / wu。順序:甲立繪x3、甲棋子x3、乙…(輪詢器依目錄名排序執行)。

## 七、交付要求(比照 26 號交付的總覽圖格式)

1. 去背後的 PNG 30 張,檔名含 job_id。
2. **兩張總覽圖**:立繪 5 列 x 3 欄、棋子 5 列 x 3 欄(列=角色,欄=seed 序),每格標 job_id 與 seed;棋子總覽另附**各自縮到 32x40 的並排**(最近鄰縮放)。
3. 甲的 3 張棋子請在總覽圖加註各自握法(第四節表);立繪為胸像,無握法。
4. 每張回報:去背邊緣是否殘留灰底、實際使用的 seed 與 steps/sampler。
5. 不要自行挑選「最好的」,30 張全交,由管理者挑。

## 八、Arthemy 出處標示

管理者 10/29 裁決:標在**製作人員名單**。遊戲目前**沒有製作人員畫面**,故由我方登記為**日後義務**,不阻擋本批。
標示的確切措辭以貴方交付的 civitai 授權快照(`2026-10-29-piece-model-search/records/civitai/`)為準;
**請貴方在本批交付 README 寫明:模型頁要求的標示對象(作者名/模型名/連結)逐字為何。**

## 九、待機幀做法 A 我方意見:**有條件同意**

做法 A = 第 1 幀 AI 圖、第 2~4 幀後製位移 1px;`art-direction.md` 規格為 2~4 幀待機,相符。
理由:32x40 上 1px 約 2.5% 高,等同呼吸起伏,對「不做完整動畫、戰鬥畫面不得有驚嚇感」(`art-tone-direction.md` 第一節末列)是對的幅度。
條件:
1. **整張同步位移優先**。若只動上半身,腰部會露出 1px 空列(內部不描邊,補洞需一次人工/規則判定),先不做。
2. 所有幀過**同一份色票量化**,避免位移後重取樣造成色漂。
3. 循環用 0,-1,0,(+0) 之類對稱序列,不累加。
4. 若管理者看第 1 幀就不滿意,待機幀無意義 -- 順序是先過靜態圖。
受擊閃爍交遊戲程式處理,我方同意(我方美術規格的對應段落會另行更新)。

## 十、待貴方回報
- 30 張全交 + 兩張總覽圖(第七節)。
- 甲的 3 種握法各自是否正確。
- Arthemy 標示要求逐字(第八節)。
