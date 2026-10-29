# 五名主角 AI 產圖 Prompt 規格 v0.1(2026-10-12)

> 🔴 **本檔是未驗證的第一版。** 撰寫者(art-director)從未看過這個 SDXL 底模的實際輸出,
> 整份規格是從角色文字描述與美術方向文件**推導**出來的,不是從任何一次實測結果**校正**出來的。
> 跑第一批候選圖之後,幾乎必然要回頭調整 prompt 用詞與參數 —— 這是預期中的事,不代表規格寫錯。
> 請承接方(家用工作站操作者)把第一批視為「校正 prompt 用的樣本」,不是「定案候選」。

**撰寫者**: art-director
**狀態**: 草稿,待第一批候選圖回饋後修訂
**上游依據**:
- `design/narrative/characters.md`(第一節總覽表,`Established`)
- `design/art/art-direction.md`(像素風硬參數)

---

## 一、共通規格

### 1.1 整體風格基準

這批圖**不是最終美術資產**,是給管理者(步驟⑤)挑選長相用的候選圖,本身是 1024×1024 的
AI 原生圖,後製會再做降採樣 + 64 色量化 + 補描邊 + 裁切置中。所以 prompt 要為「降採樣後
還能看」服務,不是為了讓這張 1024×1024 圖本身好看。

- **不要求寫實風格**:寫實的皮膚毛孔、複雜漸層、雜訊顆粒在降採樣後會變成糊髒色塊,量化
  不出乾淨色階。改要求「扁平上色、清楚輪廓、三階明暗(暗面/中間調/亮面)」—— 這套三階
  語言直接對應 `color-palette.csv` 本身的結構(每個材質家族都是 `_shadow_`/`_base_`/
  `_highlight_` 三階),上下游用同一套語言,量化時失真最小。
- 🔴 **是否直接在 prompt 裡寫「pixel art」風格關鍵字,本規格刻意不預先判定 —— 列為第四節
  的 A/B 實驗。** 理由:AI 的「假像素風」常在 1024px 畫布上畫出肉眼看起來像像素塊、但
  實際尺寸對不齊 32×40 目標格線的色塊,降採樣時會跟真正的格線產生疊紋,反而可能比乾淨的
  扁平插畫風更糊。**這是未在本模型驗證過的已知風險,不是定論。**
- 📌 **描邊只畫外輪廓,不畫內部接縫**:依 2026-10-12 另一次裁決(美術方向記錄,
  見本檔第六節第 1 項的揭露),描邊規則是「只描外輪廓,服裝接縫等內部分界不描邊」。
  **這條規則截至今天尚未併入 `design/art-direction.md` 第四節,我是從自己的工作記錄帶過來
  的,不是從今天讀的兩份檔案裡看到的** —— 已在第六節列為待確認項。先按這個方向寫進
  prompt(見下方 1.2),降低後製時「AI 畫了一堆內部接縫黑線,跟描邊規則衝突」的返工風險。

### 1.2 共通正向 prompt 片段(標記 `[COMMON-POS]`)

```
2D game character concept art, flat cel-shaded illustration, bold clean outline on
the character's outer silhouette only, minimal to no outlining on internal clothing
seams or details, rely on flat color-block contrast for internal shape separation,
limited flat color palette, three-tone cel shading with clear shadow/base/highlight
breaks, no soft airbrush gradient, strong clear silhouette, East Asian features,
contemporary Taiwan setting, single character, centered composition, soft even
studio lighting from upper-left at roughly 45 degrees, sharp focus, clean linework
```

逐段理由:
- `bold clean outline on the ... outer silhouette only / minimal ... internal`:見上方 1.1
  的描邊揭露 —— 外輪廓清楚(服務剪影辨識),內部接縫不特別加黑線(避免跟描邊規則衝突)。
- `strong clear silhouette`:戰棋遊戲裡玩家靠剪影在縮小的棋盤上瞬間分辨角色,這是視覺階層
  最基本的要求(Gestalt 圖地分離)。
- `three-tone cel shading`:見 1.1,直接對應色票三階結構。
- `soft even studio lighting from upper-left at roughly 45 degrees`:**這是我的建議,不是
  `art-direction.md` 的既有規定** —— 該檔沒有明文定義世界層角色的光源方向。選「左上 45 度」
  是常見插畫慣例,五位角色統一同一光源方向是為了放在一起時光影語言一致。**需要管理者或
  技術美術之後確認是否要配合棋盤本身的光源設定**,見第六節。

### 1.3 共通負向 prompt 片段(標記 `[COMMON-NEG]`)

```
photorealistic, 3d render, photograph, realistic skin pore detail, hyperdetailed
skin texture, film grain, noise, chromatic aberration, lens blur, depth of field,
motion blur, soft airbrush gradient, heavy smudge shading, text, watermark,
signature, logo, extra limbs, extra fingers, fused fingers, deformed hands,
malformed anatomy, extra heads, mutated, multiple characters, crowd, duplicate,
nsfw
```

前半(`photorealistic` 到 `smudge shading`)服務 1.1 的降採樣需求;後半(`text` 到 `nsfw`)
是 SDXL 社群常見的通用排除清單。**這組通用負向清單屬一般性知識,沒有針對這個底模實際
測試過**,家用端若發現某個詞沒效果或誤傷畫面,可自行增刪。

### 1.4 立繪專屬共通片段(標記 `[PORTRAIT-POS]` / `[PORTRAIT-NEG]`)

正向:
```
bust shot, head and shoulders portrait, slight three-quarter angle facing camera,
clear visible facial expression, expressive eyes, visible facial and hair detail,
simple soft blurred dark neutral backdrop, portrait framing, square 1:1 composition
```

負向:
```
full body, standing pose, hands prominent in frame, cluttered background,
busy patterned backdrop, multiple background objects
```

> 🔴 **2026-10-19 管理者裁決推翻本項:立繪【要】去背,方法為本機 AI 去背模型(BiRefNet)。**
> 下一段原文一字未刪,它是 2026-10-12 當下的正確記載。**被推翻的是「不要求去背」這件事本身**,
> 它連帶使同段「萬一裁切邊緣留一點背景」那個擔憂失去前提。
> **背景的美術處理仍然照舊**(深色中性、非純色)—— AI 去背不要求純色背景,這正是它取代
> 邊界取樣色鍵的理由(家用端實測:`--alpha-mask` 5/5 通過,`--key-from-edges` 只有 1/5)。
> ⚠️ **連帶未解**:家用端明文登記 AI 去背的兩個瑕疵(髮緣溢色、輪廓內小塊背景殘留)
> **在 32×40 看不出來、在 1024 會明顯**,而 128² 以上尚未測。見
> `docs/ai-art-service-handoff/22-postprocess-0.3-0.4-and-ai-matting-2026-10-17.md` 第二節。

- 立繪**不要求去背**(對話框有底板),背景用「柔和模糊的深色中性背景」而非純色 ——
  刻意選深色呼應介面既有面板底色(`color-palette.csv` 的 `ui_panel_bg_01 #1A1A1F`),
  萬一裁切邊緣留一點背景,跟介面面板色調不至於衝突。**這只是我的建議搭配,不是強制要求**
  —— 對話框 UI 實際怎麼擺放底板是 ui-programmer/ux-designer 的工作範圍。
- 方形 1:1 構圖:最終要裁 128×128 正方形,半身胸像天生適合方形構圖,不需要額外裁切浪費畫面。

### 1.5 棋子專屬共通片段(標記 `[SPRITE-POS]` / `[SPRITE-NEG]`)

正向:
```
full body, standing idle pose, front-facing with a slight three-quarter turn,
arms visible, feet visible, orthographic framing with minimal perspective
distortion, isolated single character, solid flat magenta background (#FF00FF),
no scenery, no shadow cast on background, no gradient background, generous empty
padding around the character within frame
```

負向:
```
cropped body, cut off limbs, partial figure, close-up, bust shot, complex
background, scenery, multiple objects in background, vignette, drop shadow on
background, gradient background, patterned background
```

- 要求全身+四肢可見,因為棋子要露出站姿(`art-direction.md` 第二節「含 2~4 幀待機」的
  前提是看得到完整站姿)。
- `solid flat magenta background (#FF00FF)`:直接命中後製去背的色鍵值。
  ⚠️ **但 AI 產出的背景不會剛好是精確的 `#FF00FF`,只會是「視覺上很接近的洋紅/桃紅色」**
  —— 後製去背大概率需要用「顏色距離容忍度」而非「完全比對」。**去背工具規格不在我的職權
  範圍**(屬技術美術/技術總監),這裡只先提醒,避免交棒後對方才發現。
- `no shadow cast on background` / `no gradient background`:防止背景邊緣留下深色殘影,
  造成去背後角色邊緣有一圈髒色。

### 1.6 顏色分配基準(呼應 `color-palette.csv`,詳見第二節各角色小節)

本規格為 5 位角色各自提案一組「膚色群 × 服裝色相家族」組合,讓 AI 產出的顏色盡量靠近既有
色票,降低後製量化落差。**色相家族只有 3 組(warm / cool / neutral)卻要分給 5 位角色,
必然有重複 —— 本規格用「同家族但明暗比重不同」緩解,撞色風險見第六節。**

| 代號 | 膚色群(對應色票) | 服裝色相家族(對應色票) |
|---|---|---|
| 甲 | 群組一(`skin_base_01` 系,暖褐) | cool,偏亮(`cloth_cool_base_01`/`_highlight_01`) |
| 乙 | 群組二(`skin_base_02` 系,深褐) | neutral,偏亮/乾淨(`cloth_neutral_highlight_01`) |
| 丙 | 群組二(日曬深褐) | neutral,偏暗/髒(`cloth_neutral_shadow_01`) |
| 丁 | 群組一 | cool,偏暗(`cloth_cool_shadow_01`,接近黑) |
| 戊 | 群組一 | warm(`cloth_warm_base_01`/`_shadow_01`) |

### 1.7 生成參數建議起點(未驗證,僅供起步;工具有預設請優先用預設)

| 參數 | 建議起點 | 備註 |
|---|---|---|
| Steps | 30 | 社群慣用起點,**未針對本機此底模驗證** |
| CFG Scale | 6~7 | 同上 |
| Sampler | DPM++ 2M Karras(或工具預設等效項) | 同上 |
| 解析度 | 1024×1024 | 依任務給定的技術前提,非我的建議 |
| Seed | 每批次固定起始值後遞增(例:1001, 1002, 1003…) | 見第四節 |

---

## 二、角色個別 Prompt

### 甲(藍亭萱,消防員,強制進入第一線隊員)

**視覺提案與理由**:`characters.md` 寫她「名字文雅溫柔,人卻是隊上最先衝進火場的那個」——
這個反差是敘事刻意設計的重點。視覺上**不用溫柔外表去呼應名字**,而是直接呈現職業慣性
(直率衝動、習慣衝第一):緊實馬尾(綁髮是實務需求,不是美感選擇)、堅毅直視的表情、戰術化
破門裝備(用「戰術/破門裝備」而非整套防火裝 —— 整套防火裝會把身形完全包住,棋子剪影會失去
辨識度)。膚色群組一 + cool 冷色調制服,金屬配件(D 環扣、斧頭)。

**角色專屬正向片段**:
```
young adult Taiwanese woman, athletic build, dark hair tied back in a tight
ponytail, sharp determined expression, confident posture, navy-blue tactical
forced-entry firefighter uniform, gear harness with D-ring buckles, fingerless
tactical gloves, sturdy boots, holding a firefighter breaching axe resting on
one shoulder, cool saturated navy-blue uniform tones with steel-gray metal
fittings and a silver axe head
```

**立繪完整正向 prompt(本檔唯一一次示範完整組裝,`[COMMON-POS]` + `[PORTRAIT-POS]` +
角色專屬片段,可直接複製貼上)**:
```
2D game character concept art, flat cel-shaded illustration, bold clean outline on
the character's outer silhouette only, minimal to no outlining on internal clothing
seams or details, rely on flat color-block contrast for internal shape separation,
limited flat color palette, three-tone cel shading with clear shadow/base/highlight
breaks, no soft airbrush gradient, strong clear silhouette, East Asian features,
contemporary Taiwan setting, single character, centered composition, soft even
studio lighting from upper-left at roughly 45 degrees, sharp focus, clean linework,
bust shot, head and shoulders portrait, slight three-quarter angle facing camera,
clear visible facial expression, expressive eyes, visible facial and hair detail,
simple soft blurred dark neutral backdrop, portrait framing, square 1:1 composition,
young adult Taiwanese woman, athletic build, dark hair tied back in a tight
ponytail, sharp determined expression, confident posture, navy-blue tactical
forced-entry firefighter uniform, gear harness with D-ring buckles, fingerless
tactical gloves, sturdy boots, holding a firefighter breaching axe resting on
one shoulder, cool saturated navy-blue uniform tones with steel-gray metal
fittings and a silver axe head
```
負向 prompt = `[COMMON-NEG]`(1.3)+ `[PORTRAIT-NEG]`(1.4)原文直接沿用,**不在此重貼**——
避免兩份字串日後各自修改造成不一致。
**立繪建議起始 seed 範圍**:`1001`–`1008`(8 張)

**棋子完整正向 prompt(`[COMMON-POS]` + `[SPRITE-POS]` + 角色專屬片段)**:
```
2D game character concept art, flat cel-shaded illustration, bold clean outline on
the character's outer silhouette only, minimal to no outlining on internal clothing
seams or details, rely on flat color-block contrast for internal shape separation,
limited flat color palette, three-tone cel shading with clear shadow/base/highlight
breaks, no soft airbrush gradient, strong clear silhouette, East Asian features,
contemporary Taiwan setting, single character, centered composition, soft even
studio lighting from upper-left at roughly 45 degrees, sharp focus, clean linework,
full body, standing idle pose, front-facing with a slight three-quarter turn, arms
visible, feet visible, orthographic framing with minimal perspective distortion,
isolated single character, solid flat magenta background (#FF00FF), no scenery, no
shadow cast on background, no gradient background, generous empty padding around
the character within frame,
young adult Taiwanese woman, athletic build, dark hair tied back in a tight
ponytail, sharp determined expression, confident posture, navy-blue tactical
forced-entry firefighter uniform, gear harness with D-ring buckles, fingerless
tactical gloves, sturdy boots, holding a firefighter breaching axe resting on one
shoulder, cool saturated navy-blue uniform tones with steel-gray metal fittings and
a silver axe head
```
負向 prompt = `[COMMON-NEG]`(1.3)+ `[SPRITE-NEG]`(1.5)。
**棋子建議起始 seed 範圍**:`2001`–`2008`

> 下方乙丙丁戊**只給視覺提案與角色專屬正向片段**,組裝公式與上面甲完全相同
> (立繪 = `[COMMON-POS]`+`[PORTRAIT-POS]`+角色專屬,棋子 = `[COMMON-POS]`+`[SPRITE-POS]`+
> 角色專屬,負向分別對應 1.3+1.4 / 1.3+1.5),不再重貼完整長字串,降低多份長字串各自
> 漂移的風險。

### 乙(徐培恩,緊急救護技術員,與甲同屬救災第一線的另一個職種;2026-10-29 原文「甲的搭檔」已依管理者裁決修正為兩人素不相識)

**視覺提案與理由**:`characters.md` 寫他「穩重克制,習慣待在能立刻補救的位置」,與甲的衝動
形成互補。視覺上比甲低一階視覺張力:平穩站姿與表情(不皺眉也不緊繃)、EMT 實務裝備(急救包、
剪刀,不是武器化造型),膚色群組二 + neutral 暖灰/米色調(刻意跟甲的冷色調制服拉開距離,
兩人並肩站在棋盤上要一眼能分辨)。

**角色專屬正向片段**:
```
adult Taiwanese man, medium steady build, short practical dark hair, calm
composed expression, gray-and-tan EMT paramedic uniform, utility vest with
pouches, cargo pants, duty belt, holding a pair of rescue extrication shears,
neutral light gray-tan uniform tones with steel-gray metal shears
```
**立繪建議 seed**:`1101`–`1108` ｜ **棋子建議 seed**:`2101`–`2108`

### 丙(董振豪,山老鼠集團底層苦力)

**視覺提案與理由**:`characters.md` 強調他是「被債務綁進這行」的底層苦力,不是主謀,**道德上
不洗白但理由站得住**——視覺上避免單純的反派造型(凶狠/張牙舞爪),改用「疲憊、警戒、被生活
磨損」的方向:日曬深褐的膚色群組二、破舊補丁的山區工作服,neutral 家族但刻意壓暗/壓髒
(與乙的「乾淨米灰」拉開明暗距離)。🔴 **他的隨身物「非法長槍」在 prompt 裡刻意寫得抽象、
不寫實**(整體本來就是扁平插畫風,這裡額外強調是提醒操作者別在 prompt 裡加碼寫實槍械細節)。

**角色專屬正向片段**:
```
middle-aged Taiwanese man, weathered sun-worn skin, rugged tired build, short
messy dark hair, wary guarded expression, worn patched dark olive-brown mountain
work clothes, utility pants, wide-brim hat, holding a long rifle slung low and
stylized non-realistic, muted dark neutral-brown uniform tones with dull metal
rifle fittings
```
**立繪建議 seed**:`1201`–`1208` ｜ **棋子建議 seed**:`2201`–`2208`

### 丁(秦亦柔,警察,依法配槍執勤)

**視覺提案與理由**:`characters.md` 寫她「先看人、再看罪」,是帶著疑惑執勤的警察,不是單純的
執法者刻板形象——表情選擇「觀察、若有所思」而非「嚴厲」。服裝沿用警察制服既定印象(深色系、
徽章、槍套),膚色群組一、cool 家族但刻意**壓暗到接近黑**(與甲的「飽和亮藍」拉開明暗距離,
緩解兩人同屬 cool 家族的撞色風險,但夠不夠區分要等圖出來看,見第六節)。

**角色專屬正向片段**:
```
young adult Taiwanese woman, upright professional posture, hair tied back in a
tight bun, observant thoughtful expression, dark navy-black police duty uniform,
badge on chest, duty belt with holster, sidearm pistol holstered, polished black
boots, cool near-black navy uniform tones with silver metal badge and holster
hardware
```
**立繪建議 seed**:`1301`–`1308` ｜ **棋子建議 seed**:`2301`–`2308`

### 戊(麥子健,流氓,絕不把籌碼押在同一邊)

**視覺提案與理由**:`characters.md` 的核心是他的生存算計(誰都不深交、誰都不得罪),不是單純
的兇狠流氓——表情選擇「帶著算計的自信微笑」而非齜牙咧嘴。服裝用 warm 家族(紅棕色系皮衣),
是五人中唯一的暖色調主角,視覺上自然與警察(丁,冷黑)、消防員(甲,冷藍)形成對立陣營的直覺
分色,膚色群組一。

**角色專屬正向片段**:
```
adult Taiwanese man, lean wiry build, messy slicked-back dark hair, confident
calculating smirk, worn reddish-brown leather jacket over a dark shirt, loose
casual pants, holding a machete down at his side, warm rust-brown jacket tones
with a dull steel blade
```
**立繪建議 seed**:`1401`–`1408` ｜ **棋子建議 seed**:`2401`–`2408`

---

## 三、立繪 / 棋子是否分開產 —— 裁決與理由

**裁決:分開產,各自獨立完整的 prompt(不是同一份 prompt 改一兩個字)。**

理由:
1. **構圖需求根本不同** —— 立繪要半身胸像、臉部細節最大化;棋子要全身、剪影最大化。
   同一份 prompt 硬要兩者兼顧,兩邊都會打折(臉部細節不夠放大,或身體比例資訊被半身構圖
   吃掉)。
2. **背景處理需求不同** —— 棋子要可去背的純色背景,立繪不需要(有底板)。若用同一份背景
   指令,立繪會被迫套用不必要的純色背景限制,犧牲美術自由度卻換不到任何好處。
   > 🔴 **2026-10-19 更正:立繪現在也要去背(管理者裁決),但本項的【結論仍然成立】,
   > 理由換了一個。** 立繪走 **AI 去背模型**、棋子走**純色色鍵**,兩者對背景的要求依然不同
   > —— 立繪**不需要**純色背景,所以「不要用同一份背景指令」這個結論不變。
   > **變的是「立繪不需要去背」這個前提,不是「兩者背景需求不同」這個結論。**
3. **表情強度需求不同** —— 立繪要清楚表情(對話用),棋子只要姿勢端正,不需要表情特寫。

⚠️ **代價(誠實揭露)**:分開產代表**立繪與棋子不保證長成同一個人**(兩次各自隨機的 AI
生成,沒有 LoRA 之前無法跨圖維持同一張臉/同一套細節)。這是本階段(步驟③④)的已知限制,
不是我能解決的——真正的跨圖一致性要等步驟⑥ LoRA 訓練完,用管理者選定的那組候選圖當訓練
素材之後才會出現。**管理者挑選時心理預期要調整**:這階段挑的是「這個角色的整體感覺對不對」,
不是「這張臉跟那張棋子是不是同一個人」。見第四節挑選判準最後一條。

---

## 四、批次建議與管理者挑選判準

### 第一輪:校正批次(只做甲一人,驗證風格關鍵字)

在往下產其餘四人之前,先用甲一人做一次小規模校正——這與 `art-direction.md` 第八節「檢查點
協議」同一個精神(先驗證一人,再決定要不要批量)。**本規格沒有讀過該檔指向的
`ai-art-validation-protocol-2026-09-29.md` 完整內容,若兩者的檢查點安排有衝突,以那份文件
的具體協議為準,此處只是呼應其精神,不是取代它。**

1. 用甲的棋子 prompt,**風格 A**(目前 `[COMMON-POS]`,不含 "pixel art" 字樣)產 4 張、
   **風格 B**(在 `[COMMON-POS]` 額外加入 `"pixel art style, pixelated"`)也產 4 張,
   共 8 張,固定其餘所有文字與參數,只換 seed。
2. 任選 1~2 張手動降採樣到 32×40 看結果(不需要完整後製管線,只是粗略比對哪種風格降採樣後
   雜訊少、色塊乾淨),決定正式候選批次要用哪種風格關鍵字。
3. 若兩種看起來差不多,建議選**風格 A(不含 pixel art 字樣)**當預設——理由是它同時也能
   更好地服務立繪 128×128(立繪不會被降採樣到那麼小,"pixel art" 字樣對立繪沒有好處,
   只對棋子有潛在風險)。

### 第二輪:五人候選批次

選定風格後,五位角色各自產生候選圖:
- **立繪**:每人建議 **8 張**(seed 範圍見第二節各角色小節)
- **棋子**:每人建議 **8 張**
- 五人合計約 **80 張**。若管理者看過之後某人 8 張都不滿意,**再追加 8 張**(換一批新 seed
  延續),而不是一開始就產更大量——這對應第一節「這不是最終資產」的立場:候選圖的成本是
  算力跟時間,不是美術工時,追加便宜。

### 給管理者的挑選判準(白話清單,挑圖時逐條看)

- **整體第一眼印象對不對**:看到這張圖,是不是你想像中那個角色該有的樣子?
- **縮小測試**:把圖縮到跟硬幣差不多大小看一眼(或退後幾步看螢幕),五官還認得出來嗎?
  ——這是在模擬遊戲裡實際顯示的大小,縮小後糊成一團的圖再漂亮也不能選。
- **道具對不對**:破門斧/破壞剪/長槍/配槍/開山刀,畫得出來、看得出是那個東西嗎?AI 常會
  把道具畫錯或畫成四不像。
- **顏色乾不乾淨**:整張圖顏色會不會太花太雜?愈簡單乾淨的顏色,後面壓縮成像素圖愈不會
  糊掉。
- **背景乾不乾淨(棋子類特別要看)**:背景是不是一塊乾淨的桃紅色,沒有花紋、沒有其他東西
  混在裡面?背景有雜質會讓去背的人多花很多時間。
- **身體有沒有畫壞**:AI 最常見的錯誤是手指數量不對、肢體角度詭異——掃一眼手跟四肢,
  有沒有明顯不對勁。
- **不用要求立繪跟棋子是同一張臉**(見第三節的代價說明),各自挑你覺得「最像這個角色」的
  那一張就好。

---

## 五、給承接方(家用工作站)的執行說明

1. 讀本檔第一節取得共通片段,讀對應角色小節取得角色專屬片段,依「組裝公式」(第二節甲的
   完整範例)組出完整正向/負向 prompt。
2. 技術前提:SDXL base 1.0,1024×1024 輸出。生成參數若工具本身有預設,優先用預設;
   沒有的話參考第一節 1.7 的建議起點(未驗證)。
3. **一次只跑一種資產類型**(立繪或棋子),同一批次內**只換 seed**,其餘文字與參數完全
   固定——這是為了讓候選圖之間唯一的差異來源是隨機性,管理者挑選時比較的才是「真正不同的
   人臉/姿勢」,而不是被其他變因干擾。
4. 產出後**不需要自己做降採樣/量化/去背**,那是後製工具的工作,不在這批產出範圍內。
   本批次只需要交回 1024×1024 原始候選圖。
5. **命名建議(候選圖命名,非最終資產命名)**:
   `candidate_[代號]_[portrait|sprite]_seed[數字].png`,例如
   `candidate_jia_portrait_seed1001.png`。正式資產命名會在管理者選定之後,依專案既有的
   `[category]_[name]_[variant]_[size]` 慣例重新命名,**這批候選圖不需要套用那套命名**。
6. 推回公司端給管理者前,**連同每張圖實際使用的 seed 一併記錄**(可以是檔名裡的 seed,
   也可以是另外一份對照清單)——管理者選定某張之後,這個 seed 可能在後續需要被引用
   (例如重新產生微調版本時當作起點)。
7. 第一輪請先只做「第四節第一輪校正批次」(甲一人,8 張),等風格關鍵字定案後再做五人
   候選批次——不要一次把全部 80 張都產出來,避免校正結論出來後要整批重做。

---

## 六、我沒把握的部分 / 需要管理者裁決的項目

🔴 **本規格整體狀態:第一版,未經任何實測。** 撰寫者(art-director)從未看過這個底模的
實際輸出,下列都是推導而非驗證結果。跑完第一批候選圖之後幾乎必然要回頭調整用詞與參數——
這是預期中的事,不代表規格寫錯。

**需要管理者或下一位專家確認的項目**:

1. **描邊「只畫外輪廓、內部不描邊」這條規則,我是從自己過去的工作記錄帶過來的,不是從
   今天讀的 `art-direction.md`/`characters.md` 兩份檔案裡看到的**——該規則截至今天尚未
   併入 `art-direction.md` 第四節。我已把它寫進第一節的共通 prompt 片段,但**這條規則本身
   是否仍然有效、是否已經有人正式裁決,需要管理者或下一位讀過美術方向文件最新狀態的人確認**,
   不要只憑本檔就當成定案。
2. **光源方向(左上 45 度)是我的提案,不是 `art-direction.md` 既有規定**——該檔沒有明文
   定義世界層角色的光源方向。若棋盤地形本身有既定光源方向,需要跟這份提案核對是否一致。
3. **色相家族撞色風險**:只有 3 組 cloth 色相家族(warm/cool/neutral)卻要分給 5 位角色,
   本規格用「同家族不同明暗比重」緩解(甲亮藍 vs 丁近黑,乙米灰 vs 丙壓暗),但**沒有實測
   能否真的在棋盤縮圖大小下視覺區分**——若第一批圖出來後管理者覺得甲丁或乙丙看起來太像,
   需要額外加強差異化細節(反光條紋、徽章形狀等),這是下一輪的工作,不是本版能提前解決的。
4. **「pixel art」風格關鍵字要不要用**,本規格刻意不判定,留給第四節的 A/B 校正批次決定。
5. **去背門檻(精確比對 vs 顏色容忍度)**——AI 產出的背景不會剛好是 `#FF00FF`,後製去背
   工具大概率需要容忍度門檻,但去背工具規格不在我的職權範圍(屬技術美術/技術總監),這裡
   只提醒。

**純粹揭露,不要求裁決,但下一個人需要知道**:

6. **立繪與棋子不保證同一張臉**——沒有 LoRA 之前跨圖無法維持一致,見第三節。
7. **五位角色的膚色/服裝色系分配是我這次的創作提案**,`characters.md` 沒有規定外觀細節,
   這正是本次「先產候選圖」流程的本意——若管理者覺得某個分配不好,可以直接要求換色重跑,
   不需要先改動 `color-palette.csv` 或 `characters.md`。
8. **本規格沒有讀過 `docs/ai-art-service-handoff/` 下任何檔案**(依派工指示)——若那批
   文件對 prompt 格式、檔名、交付方式另有既定規範,本規格可能與其衝突,需要靠管理者或
   下一個讀過那批文件的人核對。
9. **生成參數(steps/CFG/sampler)只是社群常見起點,沒有針對這個底模驗證過**,家用端工具
   若有自己的預設,應優先採用。
10. **丙的「非法長槍」道具,prompt 裡刻意要求「stylized non-realistic」**,避免寫實槍械
    細節——這是我主動加的,不是被要求的,提醒下一個人這條線存在。
