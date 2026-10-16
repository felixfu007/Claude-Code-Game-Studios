# 19a — 飽和度修正 prompt 實驗(2026-10-16)

承接 `docs/ai-art-service-handoff/18a-round3-screening-art-verdict-2026-10-16.md`。管理者已裁決:
18a 第五節 5.1(`native_only`)與 5.2(飽和度修法)兩件一起做,排成一個有共用對照組的三張實驗
(A/B/C)。本檔只負責第四節表格裡 B、C 兩張要用的新 prompt,以及三張的 seed 選擇。

## 1. 新正向 prompt

### 1.1 全文

```
masterpiece, best quality, very aesthetic, absurdres, safe, 1girl, solo, adult woman, east asian, black hair, ponytail, serious expression, athletic build, standing, full body, three-quarter view, facing viewer, firefighter, vivid navy blue uniform, saturated blue, harness, fingerless gloves, boots, holding axe, axe on shoulder, silver axe, steel gray trim, cel shading, flat color, bold outline, simple background, magenta background
```

### 1.2 逐項改動與理由

與工單 `20261014-001` 的 `request.json` 原文逐字比對,改動只有兩處插入,其餘一字未動:

1. **`navy blue uniform` → `vivid navy blue uniform`**(插入 `vivid`,緊貼在制服 token 前面)。
   理由:`vivid` 是 Danbooru 系標籤語彙裡常見的飽和度/色彩強度修飾詞,Animagine XL 3.1
   訓練語料以 Danbooru tag 為主,應認得這個詞。放的位置刻意**緊貼**制服 token、不是丟在
   prompt 開頭或結尾當全域風格詞 —— 目的是在「標籤湯」式的條件化裡盡量把影響侷限在制服
   這個概念附近。⚠️ **這個侷限效果是假設,不是保證**:tag-soup 模型沒有分區域的語意邊界,
   相鄰只是增加關聯機率,不是硬性範圍。
2. **插入 `, saturated blue`**(緊接在上一步之後)。
   理由:疊字/堆疊同義詞是標籤式 prompt 常見的加重手法(同一概念重複出現,等同不用
   emphasis 語法也能提高條件化權重)。這是把你 18a 原本對散文 prompt 提的「寫
   `saturated navy blue uniform`」這個想法,換成標籤式語彙後的對應做法 —— 原本那份散文
   prompt 本來就寫了 `saturated`,但**那份 prompt 從未被實際送出**(見下方事實對照),
   所以這次是「新增」,不是「補回遺漏」,效果未知。
3. **`steel gray trim` 完全不動**。
   理由:管理者已在派工單裡明講,金屬配件刻意要灰 —— 這是正向設計,不是飽和度問題的一部分。
   凡本次插入的詞都**不在這個 token 附近**,且沒有使用任何全域性的「整張圖都更鮮豔」式詞彙
   (例如不加 `vibrant colors` 這種不分對象的全域標籤),就是為了不要把灰色金屬一起拉飽和。
   ⚠️ 即使如此,tag-soup 沒有分區保證,**trim 會不會被連帶影響仍是未驗證的風險**,
   這正是本實驗 3 張裡必須人眼確認的一項(見第 4 節)。
4. **`cel shading, flat color, bold outline` 完全不動**。
   理由:18a 沒有建立「這些風格詞導致飽和度/亮度偏低」的因果證據,只建立了「16 張制服主色
   系統性偏暗偏灰」這個現象。這次只動一個懷疑變因(制服顏色 token),如果連風格詞也一起改,
   3 張出來不管變好變壞都無法歸因到底是哪個改動起作用。
5. **沒有刪除、沒有重排任何既有 token**,全部改動是純插入 —— 同樣是為了讓這次實驗盡量只有
   一個變因。

⚠️ **未驗證**:這套工具的生成管線是否支援 emphasis 語法(例如 `(navy blue uniform:1.3)`
這種 Stable Diffusion WebUI / NovelAI 慣用寫法)完全未知,故本次不使用這類語法,只用純
tag 插入與堆疊。若日後確認支援,這會是比堆疊更可控的下一步,但不是本次範圍。

## 2. 新負向 prompt

**判斷:要動,不是「不動」。** 理由:正向詞的堆疊是「拉」,負向詞是「推」,兩個方向同時做
才比較可能讓制服的飽和度落在規格附近,而不是只拉一半。

### 2.1 全文

```
nsfw, lowres, (bad), text, error, fewer, extra, missing, worst quality, jpeg artifacts, low quality, watermark, unfinished, displeasing, oldest, early, chromatic aberration, signature, extra digits, artistic error, username, scan, [abstract], desaturated, muted colors, dull colors, washed out colors, low saturation, pastel colors, grayscale, photorealistic, realistic, multiple girls, multiple boys, duplicate, extra limbs, extra arms, extra legs, fused fingers, missing fingers, deformed hands, mutated hands, bad anatomy, detailed linework, cross-hatching, reference sheet, turnaround, multiple views, grid, kneeling, crouching, sitting, action pose, dynamic angle, scenery, complex background, gradient background, shadow on background, patterned background, close-up, cropped, out of frame, feet out of frame
```

### 2.2 逐項改動與理由

新增的 7 個詞全部插入在 `[abstract],` 之後、`photorealistic, realistic,` 之前 —— 這個位置
本來就是「整體渲染風格不對」的負向詞群聚處(`[abstract]` / `photorealistic` / `realistic`
都是在排除「畫風整體跑掉」,不是在排除單一局部瑕疵),新插入的 7 個詞同屬這個性質
(描述整張圖的色彩呈現風格,不是某個局部缺陷),放在一起比插進開頭的 `jpeg artifacts` /
`low quality` 技術性瑕疵群組更合邏輯。

1. **`desaturated`** —— 最直接對應我們量到的症狀本身(16 張飽和度代理值系統性偏低
   18~22pp),字面對應度最高。
2. **`muted colors`** —— 對應 18a 原本在散文 prompt 脈絡下提的「muted」,換成標籤式慣用的
   `muted colors` 寫法。⚠️ **未驗證**這個確切片語是否為 Animagine 認得的標籤,風險低
   (加了沒用頂多無效,不太可能有副作用),故仍納入。
3. **`dull colors`** —— 同義堆疊,理由與正向詞的堆疊手法一致:標籤式 prompt 沒有強調
   語法時,重複相近概念是常見的加重手段。
4. **`washed out colors`** —— 直接對應我們量到的另一個症狀(平均亮度 L 只有 24.4%,
   比規格 base 的 38.3% 低 14pp)。這個詞同時沾到亮度與飽和度兩個面向,比前三個更廣。
5. **`low saturation`** —— 最字面、最不依賴模型對隱喻詞的理解,直接複述我們量測用的指標
   名稱本身。
6. **`pastel colors`** —— pastel = 高亮度 + 低飽和,是動漫標籤語彙裡常見的「要避開的風格」
   方向,涵蓋到「整張圖偏向粉彩」這個我們沒有直接量到、但視覺上與現象相關的風險。
7. **`grayscale`** —— 涵蓋最極端的情況(近乎單色/去彩),是這類負向詞組的標準配置。

8. 🔴 **刻意不加裸的 `gray`**(18a 原文建議的是「desaturated / muted / gray」三詞,這裡只採
   前兩類、捨棄第三個)。
   **`gray` 原本要防的是什麼**:防止整張圖的色彩傾向變得灰撲撲、對比度不足的那種「畫面感」。
   **捨棄它會失去什麼**:上面 7 個詞裡,只有 `grayscale`(極端情況)勉強沾到「灰」這個字面,
   沒有一個詞能像裸 `gray` 一樣直接壓住「畫面整體偏灰」這個傾向本身 —— 所以這個方向的負向
   力道會比 18a 原始建議弱一些,這是本次刻意接受的代價。
   **為什麼接受這個代價**:`steel gray trim` 是正向 prompt 裡明確指定的顏色,金屬配件要的
   就是灰。負向 prompt 裡的 `gray` 是一個全域詞,無法像插入正向詞那樣「緊貼在某個 token
   旁邊」來侷限範圍 —— 它會對整張圖的灰色傾向整體施加壓力,而這包含了 trim 本身。
   用一個全域負向詞去打壓一個同時存在於正向 prompt 裡的明確指定顏色,兩者會互相拉扯,
   結果不可預期(可能是 trim 顏色跑掉,也可能是 trim 整個被判定為「該避免」而弱化或消失)。
   **這是對派工單第 2 點警語的具體落實,也是我推翻自己 18a 建議的地方。**

## 3. Seed 選擇(X / Y)

**可選範圍**(派工單給定):seed 2002~2009,對應工單 009~016,依序一一對應
(2002→009、2003→010、2004→011、2005→012、2006→013、2007→014、2008→015、2009→016)。

**派工單直接提供的邊殘數字只有四個**:工單 009(2009px,病態)、工單 010(75px)、
工單 011(237px)、工單 015(1164px,病態)。⚠️ **工單 012/013/014/016(對應 seed
2005/2006/2007/2009)的邊殘數值與飽和度數值,本次派工單沒有提供,我也沒有重新讀取
18a 原始檔去查** —— 依指示不重讀檔案,故這四個 seed 是否同樣「非病態」對我而言是
**未驗證**,以下選擇只在給定的四個候選裡做。

### 3.1 seed X = 2004(對應工單 011,10/14 原圖邊殘 237px)

A 要當髒邊假說的對照組,需要 10/14 原圖「有明顯但非病態的外框殘留」。四個候選裡:
- 工單 011(237px)與工單 010(75px)都屬非病態的一般情況。
- 237px 比 75px 大超過 3 倍,在側邊比對時應該**更容易被人眼看出「縮小後確實有一圈邊」**,
  而又遠低於病態的兩個案例(2009px / 1164px),不至於夾帶病態案例可能有的其他未知成因。
- 因此選 237px(工單 011)而非 75px(工單 010)當 seed X —— 75px 可能小到連當對照組都
  看不太出差異,驗證力道較弱。

### 3.2 seed Y = 2003(對應工單 010,邊殘 75px)

C 的目的是「驗 B 的效果不是單一 seed 的運氣」,派工單沒有對 Y 給邊殘相關的篩選條件
(那是 A 專屬的考量)。選擇理由:
- 四個已知候選裡,工單 010 是唯一還沒被 A/B 用掉、且同屬「非病態一般情況」的選項 ——
  用一個本身乾淨、不帶邊殘干擾的 seed 來測飽和度修法,比較不會把「這張本來就有點髒邊」
  跟「飽和度有沒有改善」兩件事混在一起看。
- ⚠️ **這個理由只覆蓋邊殘這一個維度。** C 真正要驗的「不是單一 seed 的運氣」,理想上應該
  是挑一個**構圖、姿勢、色彩分布跟 X 明顯不同**的 seed,但這些資訊本次派工單沒給、我也沒有
  重新查 18a —— 所以工單 010 只是「目前已知資訊裡最乾淨的次選」,不是「我確認過構圖夠不同
  的選擇」。這一點在第 4 節會再標注為本次實驗量不到的東西。

## 4. 這次實驗量不到什麼

1. **樣本數本身**:3 張不是統計意義上的樣本,16 張才是目前唯一夠格談「系統性」的樣本。
   不論這 3 張結果多乾淨,都不能拿來取代 16 張的結論,只能當「值不值得再送一整批」的
   初步訊號。

2. **A/C 只各一個 seed,不是機率意義上的「驗證」**。C 用 seed Y 確認 B 的效果不是單一
   seed 的運氣,但 2 個資料點(X、Y)只能講「方向一致 / 不一致」,講不出「這個修法對
   任意 seed 都有效」。

3. 🔴 **飽和度的乾淨比較只有一條:B vs A(以及程度較弱的 C vs A)—— 不得拿 B/C 直接跟
   18a 的 16 張表比。**

   派工單表格裡 A、B、C 三張的 `upscale_mode` **全部是 `native_only`**,A 與 B 之間
   **唯一**差異是 prompt(A 舊、B 新)。所以 **A↔B 的飽和度差異,定義上就只能來自
   prompt 改動**,不存在「可能部分來自 upscale_mode 不同」這個疑慮 —— 這正是把 A 排進
   表格當共用對照組的全部理由。(本點前一版把這裡想反了,誤寫成 A 是「舊 prompt +
   lanczos」,已更正:A 跟 B 一樣是 `native_only`。)

   **但有一條比較仍然不乾淨,必須明寫清楚適用範圍**:18a 第三節那 16 張全部走過 lanczos
   升頻,跟這次 A/B/C 的 `native_only` 是不同的 `upscale_mode`。所以**不得拿 B(或 C)
   量出來的飽和度數字,直接去跟 18a 那 16 列的表比**——那樣比出來的差異一樣無法排除
   「只是因為 upscale_mode 換了」這個可能。**唯一乾淨的飽和度比較是本次表格內部的
   B vs A**,其次是 C vs A(換了 seed,乾淨度打折,但仍在 `native_only` 內部比較),
   不是拿這 3 張去跟之前的 16 張比。

   📌 **另一個真的混淆因子,一併寫入**:A 自己跟它的 10/14 同 seed 原圖相比,也不是
   「只差尺寸模式」。`native_only` 讓產圖解析度從 904×1168 變成 896×1152 ——
   同一個 seed 在不同解析度下,擴散模型是重新跑一次 denoising,不是單純裁切/縮放同一張
   既有圖,所以本來就會生成出不完全相同的圖。因此「A 的邊殘比 10/14 原圖少」這個結果,
   **無法區分「拿掉 lanczos 本身解決了髒邊」與「單純換了一張圖,這張剛好邊殘較少」**——
   這是機制歸因上的缺口。
   ⚠️ **但這個缺口不影響本次要做的排程決定。** 我們真正要回答的問題是「下一批 4:5
   若全面改用 `native_only`,邊殘乾不乾淨」,不是「髒邊的物理成因是不是 lanczos」——
   A 直接且完整地回答了前者,不論背後機制為何。機制歸因有缺口,不代表「這條驗證不可信、
   不能拿來做排程決定」。

4. **不含 lanczos 路徑,所以「新 prompt 在 lanczos 下還有沒有效」完全未知。**
   如果這次驗出新 prompt 確實能拉高飽和度,下一個問題是:這個效果會不會被 lanczos 的
   重新取樣再次抵銷、或者反而被放大、或者跟 lanczos 的髒邊問題疊加出新的瑕疵——
   這次 3 張一張都不會回答這個問題,因為全部都是 `native_only`。

5. **亮度落差(−14pp)這次沒有被直接處理。**
   新正向 prompt 只動了飽和度相關的 token(`vivid`、`saturated blue`),負向 prompt
   裡的 `washed out colors` 間接沾到亮度,但沒有任何詞直接要求「更亮」(例如
   `bright lighting`、`high key` 之類)。**如果這 3 張測出來飽和度改善但亮度依然偏暗,
   不代表這次修法失敗 —— 只代表亮度是另一個獨立的落差,這次的改動範圍本來就沒打算處理它。**
   反過來,如果亮度也跟著變好,那是附帶效應,不是這次刻意設計的目標,不能宣稱「亮度問題
   也一併解決了」去外推到其他場景。

6. **兩個正向改動(`vivid` 與 `saturated blue`)的個別貢獻拆不開。**
   這次是把兩個同方向的詞一起加進去當一組「治療方案」,3 張結果只能告訴我們「這組合
   有沒有效」,不能告訴我們是哪一個詞在起作用、還是兩者加總、甚至其中一個在削弱另一個。
   要拆開需要再做至少兩組「只加其中一個」的對照,不在本次範圍內。

7. **`steel gray trim` 有沒有被誤傷,只能在這 3 張裡逐張人眼/量測確認,不能外推。**
   即使這 3 張的 trim 顏色完全沒跑掉,也只能說「這 3 個 seed、這組 prompt 下沒有看到
   誤傷」,不能保證換一批 seed、或者日後負向詞再疊加其他修法時,trim 依然不受影響。

8. **`cel shading` / `flat color` / `bold outline` 這幾個風格詞完全沒被動到,所以如果
   這 3 張的飽和度與亮度依然不理想,不能倒推「飽和度詞沒用」** —— 真正的瓶頸也可能落在
   這幾個完全沒被測試過的風格詞上,這次的設計排除不了這個可能性,只是刻意不在本次處理。

9. **本次負向詞裡新加的幾個片語(`muted colors`、`dull colors`、`washed out colors`、
   `pastel colors`)是否真的是 Animagine / 其底層 CLIP 文字編碼器認得的有效標籤,
   這次無法驗證** —— 3 張結果如果變好,無法確定是這些片語真的被模型理解,還是純粹因為
   `desaturated` / `low saturation` / `grayscale` 這幾個更直白的詞起了作用,堆疊的其餘
   幾個詞可能完全沒有貢獻(但也没有已知的壞處)。
