# 底模可行性評估 v2 —— 判準加入「離開動漫血統」之後的重開

**日期**:2026-10-19 · **撰寫**:`technical-director`
**範圍**:單檔 checkpoint 可行性、VRAM、授權分層、服務端改不改得動。
**不在範圍**:哪一個好看(美術判斷,歸 `art-director` 與管理者)

> 🔴 **本檔刻意不排名、不寫「建議採用」。** v1(`12-base-model-candidates-2026-10-13.md`)
> 有「候選一(建議採用)」,這一版沒有 —— 新判準有一半是畫風判斷,不是技術網域。

## 第一節:判準表(四條,逐一打勾)

| # | 判準 | 立繪要的 | 棋子要的 | 誰判 |
|---|---|---|---|---|
| 1 | **繪製質感** | **半寫實精緻繪製**:柔和漸層、臉部有結構、乾淨完成度高。**❌ 不是照片寫實、❌ 不是扁平** | **扁平 cel-shade**:三階硬邊、少漸層。**❌ 不要半寫實** | 美術 |
| 2 | **血統** | **離開動漫血統**(2026-10-16 新增;本作類型是克蘇魯、對標《暗黑地牢》) | 同左 | 美術 |
| 3 | **授權** | 第②層「產出圖片可商用、第三方不能對它主張權利」必須有 URL + 查證日期 | 同左 | **技術(本檔)** |
| 4 | **可用性** | **單檔 `.safetensors` 的 SD1.5 / SDXL checkpoint**,16GB VRAM 跑得動 | 同左 | **技術(本檔)** |

🔴 **判準 1 立繪與棋子要的方向相反**(來源 `20c-cr-002-supplement-style-criteria-2026-10-16.md` 第二節),
所以本檔第二節把兩邊**分開列**。一個模型只滿足其中一邊是正常的,不是缺點。

⚠️ **判準 4 比家用端寫的多一條限制,那一條是我加的,來源是本專案自己的規定**:
`04-security-and-licensing.md:107` 逐字「**模型檔一律只收 `.safetensors` 格式**,不下載、不使用
`.ckpt`/`.pt` 格式的模型」。**這條會直接刷掉生態系裡幾個最知名的非動漫風格模型**
(`ogkalu/Comic-Diffusion`、`Envvi/Inkpunk-Diffusion`、`nitrosocke/Arcane-Diffusion` 三個在 HF 上
**只有 `.ckpt`**,實測:`curl -s https://huggingface.co/api/models/<id>/tree/main | jq`,2026-10-19)。

## 第二節:候選清單

### 2.0 查證方法,以及三件套在每一個候選上的共通風險

**查證方法**(全部 2026-10-19 當場執行,可重跑):
```
curl -s "https://huggingface.co/api/models/<id>" | jq -r .cardData.license          # HF 授權欄位
curl -s "https://huggingface.co/api/models/<id>/tree/main" | jq -r '.[].path'       # 單檔是否存在
curl -s "https://civitai.com/api/v1/models/<id>" | jq -r '.allowCommercialUse, .modelVersions[].files[0].metadata.format'
```

🔴 **共通風險一:civitai 的 `allowCommercialUse` 是【上傳者自己勾的】,不是授權全文。**
它是一組旗標(`Image` / `Rent` / `Sell` / `SellMerge`),**旗標字面的定義我今天沒有查到條款原文**
—— 標為**未查證**。我只能逐字回報旗標值,不能代為解釋「`Image` 等於可以把產圖放進商業遊戲」。

🔴 **共通風險二:合併/微調模型不會自動繼承一份乾淨的授權。**
`04-security-and-licensing.md` 第五節第 2 點逐字要求「不同模型、不同版本的授權條款**不能互相套用**」。
下面每一個 SDXL 衍生模型,**上游 SDXL base 1.0 的 CreativeML Open RAIL++-M 仍然可能同時拘束它**,
而上傳者勾的旗標不會告訴你這件事。**這是法律判斷,本檔不代為下。**

✅ **共通事實(對我方有利,今天查證)**:RAIL++-M 對「產出圖像」有明文,第 34 行逐字:
> The Output You Generate. Except as set forth herein, Licensor claims no rights in the Output You
> generate using the Model. You are accountable for the Output you generate and its subsequent uses.

來源:https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/raw/main/LICENSE.md,查證 2026-10-19。
**這句話解決的是第②層的一半**(授權方不主張權利),**沒有解決另一半**(訓練資料來源的爭議狀態)。

---

### 2.1 立繪候選(半寫實精緻繪製 + 陰鬱)

#### 立繪-A:Juggernaut XL v9 + RunDiffusion Photo v2

- **連結**:https://huggingface.co/RunDiffusion/Juggernaut-XL-v9
- **架構 / 檔案形式 / 大小**:SDXL 1.0 / **單檔 `.safetensors` ✅**
  (`Juggernaut-XL_v9_RunDiffusionPhoto_v2.safetensors`)/ **6.61 GB**
- **授權**:HF `cardData.license` = `creativeml-openrail-m`。逐字關鍵條款同上方 RAIL 家族的
  Output 條款(RAIL-M 與 RAIL++-M 的 Output 條文措辭一致)。
  🔴 **但我今天沒有逐字打開這個 repo 自己的 LICENSE 檔**,只讀到授權欄位標籤 —— **這一項標「部分未查證」**。
  來源 URL 同上,查證日期 2026-10-19。
- **訓練資料取向(事實)**:SDXL base 1.0 的**攝影寫實向**微調,版本名自帶 `RunDiffusionPhoto`。
  發布者自述,未獨立驗證。
- **已知風險**:🔴 **方向偏照片寫實,而 `20c` 第一節明文寫 ❌ 不是照片寫實。**
  家用端探針已實測過同一類(攝影寫實)模型的後果:去背失效、降採樣後成色塊(見 CR-002 回覆第四節)。
  **列在這裡的理由是它授權與來源最乾淨,不是因為它符合畫風。**

#### 立繪-B:DreamShaper XL(`alpha2 (xl1.0)` 版本)

- **連結**:https://civitai.com/models/112902 (作者 Lykon);同作者在 HF 另有
  https://huggingface.co/Lykon/dreamshaper-xl-v2-turbo (**Turbo 版**)
- **架構 / 檔案形式 / 大小**:SDXL 1.0 / **單檔 `.safetensors` ✅**(`dreamshaperXL_alpha2Xl10.safetensors`)
  / **約 6.46 GB**(civitai 自報 6616 MB;HF 上 Turbo 版實測 6.46 GB)
- **授權**:
  - HF(Turbo 版)`cardData.license` = **`openrail++`** —— 來源
    https://huggingface.co/api/models/Lykon/dreamshaper-xl-v2-turbo,查證 2026-10-19。
  - civitai(alpha2 所在的頁面)旗標逐字 = `["Image","RentCivit","Rent"]`,
    `allowNoCredit=true`、`allowDerivatives=true`。來源 https://civitai.com/api/v1/models/112902,查證 2026-10-19。
  - 🔴 **兩個來源是不同載點、不同版本,授權欄位也不同一份。** 真的要用 alpha2,**必須去 civitai 該版本頁
    逐字確認**,不能拿 HF Turbo 版的 `openrail++` 替它背書 —— 這正是 `04` 第五節第 2 點禁止的那種套用。
- **訓練資料取向(事實)**:模型頁逐字自述「DreamShaper is a general purpose SD model that aims at
  doing everything well, photos, a…」;**civitai 標籤逐字包含 `anime`**
  (`photography,art,xl,realistic,dreamshaper,artstyle,turbo,sdxl,base model,anime`)。
- **已知風險**:
  1. 🔴 **標籤自帶 `anime`,對判準 2(離開動漫血統)是直接的反向證據。** 它是通才模型,不是離開動漫,
     而是**什麼都沾一點**。
  2. 模型頁作者自己寫「Alpha2 is a bit old now. I suggest you switch to the Turbo or Lightning version」
     —— 而 Turbo / Lightning 版的建議取樣是 **DPM++ SDE**,**不在現行 sampler 白名單**(見第四節②)。
     **選 alpha2 可避開白名單問題,但等於刻意用舊版。**

#### 立繪-C:_CHEYENNE_ —— 🔴 **本表唯一【兩者都能服務】的候選,對我方成本最有利**

- **連結**:https://civitai.com/models/198051 (作者 Aurety)
- **架構 / 檔案形式 / 大小**:SDXL 1.0 / **單檔 `.safetensors` ✅** / **6616 MB**。
  多個版本,**三個與我方有關**:
  - `v2.0`(`CHEYENNE_v20.safetensors`)→ **立繪向**
  - `CH.01 [ALT] Clean Lineart` → **棋子向**(見下)
  - `v2.4 (Hyper Illustration)` → 🔴 **不要用,理由見風險 1**
- **授權**:civitai 旗標逐字 = `["RentCivit","Image","Rent"]`(**沒有** `Sell` / `SellMerge`),
  `allowNoCredit=true`、`allowDerivatives=true`、`allowDifferentLicense=true`。
  來源 https://civitai.com/api/v1/models/198051,查證 2026-10-19。
  ⚠️ **旗標字面定義未查證**(見 2.0 共通風險一);**上游 SDXL 的 RAIL++-M 是否同時拘束未查證**(共通風險二)。
- **訓練資料取向(事實,全部引自模型頁作者自述)**:
  - 「**more representative of the Franco-Belgian comic strip style than of manga**」、
    「**There's a bit of Manga, but very little**」、
    「More influence on the style of European comics: **Hergé, Spirou, Franquin, Uderzo, Gibrat,
    Moebius**, etc. are now recognisable」
  - v2.0:「More mature, more '**Painting**' and '**Matte painting**' oriented, I've refined the lineart」
  - 「After more than **300 fusions**」—— **大量合併的產物,上游清單不可考。**
- **✅ 為何標「兩者都能服務」**:`v2.0` 走繪畫/馬特繪(立繪),`CH.01 [ALT]` 走乾淨線稿 + 平塗(棋子)。
  **兩種素材共用一個作者、一條血統,風格一致性天生比「兩個無關模型」高。** 事實陳述,不是建議。
- **已知風險**:
  1. 🔴 **`v2.4` 作者自述「I merge a bit of a **Illustrious** model」—— Illustrious 是動漫血統,
     直接違反判準 2。** 而且該版本要求「Use **Skip:-2** in ComfyUI」(CLIP skip),
     **現行服務有沒有開放這個參數,我未查證** —— 若沒有,畫面會與作者預期不同而無人察覺。
     **→ 要用就用 `v2.0` / `CH.01`,不要用 `v2.4`。**
  2. 🔴 **模型頁明文列出數位仍在著作權保護期內的歐洲漫畫家姓名且「可辨識」。**
     `04-security-and-licensing.md` 第 5.3 節正是針對這個形狀:風格本身不受保護,
     但「刻意重製某一張具體可辨識的原作」責任落在下指令的人。**這不阻擋採用,
     但若採用,prompt 規格必須明文禁止指名這些人名。**
  3. 300 次合併 → **上游每一份模型的授權不可考**,共通風險二在這個候選上最嚴重。
  4. 建議取樣 `DPM++ 2M` / CFG 1–5 —— **`dpmpp_2m` 已在白名單內 ✅**,但作者同時寫
     「extremely sensitive to the nature of the sampler, steps and CFG」。

---

### 2.2 棋子候選(扁平 cel-shade + 陰鬱)

#### 棋子-A:comi-noir v2(`comi-noir hard` 或 `comi noir sephia` 版本)

- **連結**:https://civitai.com/models/16325
- **架構 / 檔案形式 / 大小**:**SD 1.5** / **單檔 `.safetensors` ✅,但只有兩個子版本是**:
  `comiNoirV2_comiNoirHard.safetensors`、`comiNoirV2_comiNoirSephia.safetensors`,各 **2033 MB**。
  🔴 **主版本 `comiNoirV2.ckpt` 是 PickleTensor,依 `04` 第 107 行一律不收** —— 下載時**不要抓到那一個**。
- **授權**:civitai 旗標逐字 = `["Image","RentCivit","Rent","Sell","SellMerge"]`(**四項全開,
  本檔所有候選中最寬**),`allowNoCredit=true`、`allowDerivatives=true`、`allowDifferentLicense=true`。
  來源 https://civitai.com/api/v1/models/16325,查證 2026-10-19。
  ⚠️ 共通風險一、二同樣適用;SD1.5 的上游授權是 **CreativeML OpenRAIL-M**(非 ++),**本次未逐字查證**。
- **訓練資料取向(事實)**:模型頁說明極短,逐字只有「more **anime-like** than before.
  The nsfw expression doesn't work well. safe tensor update good luck」。
  **作者沒有公開訓練資料來源。**
- **已知風險**:
  1. 🔴 **作者自述「more anime-like than before」—— 對判準 2 是直接的反向證據**,
     與模型名「comi-noir」(黑色電影/漫畫)給人的印象相反。**這一句必須讓美術看到再判。**
  2. **SD1.5 → 512 原生**,連帶後果見第四節①③。
  3. 模型頁資訊量極低(兩行),**來源與合併鏈不可考**。

#### 棋子-B:_CHEYENNE_ 的 `CH.01 [ALT] Clean Lineart` 版本 —— **與立繪-C 同一個模型家族**

- 欄位同立繪-C(同一個 civitai 頁面、同一組授權旗標、同樣單檔 `.safetensors`)。
- **為何列在棋子側**:作者對這個版本的自述逐字是
  「clear and precise lineart, **flat colors** and beautiful gradients … less organic, more cartoony」
  —— **這是本檔唯一一個作者明文自稱 flat colors、且血統自稱偏歐漫而非日漫的版本。**
- **風險**:同立繪-C 第 2、3 點(人名可辨識、300 次合併);
  另 **我沒有查到這個 ALT 版本的檔名與檔案大小**(civitai API 只回傳前 3 個版本)—— **標「未查證」**。

---

### 2.3 其他看過但沒有展開的候選(留痕,不是刪除)

同批查詢出現、未展開,理由寫在各自後面(下一個人續查的起點):
`SG161222/RealVisXL_V5.0`(`openrail++`,單檔 6.46 GB;攝影寫實,同立繪-A 的問題)、
🔴 `dataautogpt3/ProteusV0.5`(**`apache-2.0`,本次最乾淨的授權標籤**,單檔 6.65 GB;
但它是 SDXL 衍生物,上游 RAIL++ 是否仍拘束**未查證** —— **最值得續查的一個**)、
`playgroundai/playground-v2.5`(授權欄位 `other`,**未查證**)、
`dataautogpt3/OpenDalleV1.1`(`cc-by-nc-nd-4.0` → **NC,出局**)、
`Gothic style SDXL`(civitai 522764,旗標四項全開、SDXL 單檔,但自述合併自 Realistic Mix → 偏寫實)、
`ElHoldson/Arthemy-Comics-XL`(HF **沒有授權欄位** → 未查證)、
`Nova Flat XL`(v1 已查證明文禁止未編輯產圖商用,不重查)。

---

### 2.4 🔴 一個結構性事實,它比上面任何一個候選都重要

**「扁平 / cel-shade」這一軸,在開源生態系裡主要不是以 checkpoint 形式存在,而是以 LoRA 形式存在。**

實測(2026-10-19,HF 依下載量搜 `flat color` / `cel shaded` / `vector art` / `woodcut` 各取前 8 名):
**四組的前 8 名幾乎全部是 LoRA**,checkpoint 只有零星幾個且多為動漫血統。指令:
`curl -s "https://huggingface.co/api/models?search=cel%20shaded&pipeline_tag=text-to-image&sort=downloads&direction=-1&limit=8" | jq -r '.[].id'`

**而我方的服務已經有 LoRA 路徑,不需要改程式。** 這與派工單寫的「只有單檔 checkpoint
裝好就能用(`CheckpointLoaderSimple` 一條路線)」**不衝突** —— 那句話講的是**底模**的載入路線;
LoRA 是另一條,而且**已經驗收過了**:`06-change-request-001-reply-2026-10-10.md` 第八節逐字
「`loras` 設定 → `GET /v1/models` → 請求驗證 → **ComfyUI LoraLoader 串接** → 錯誤分類,整條路徑查過」,
同檔 149 行「D4 | ✅ 2026-10-10(用 D2 的真 LoRA 正式驗收)」,附 L6/L12 位元相同的 SHA 證據。

⚠️ **三項未查證,不要讀成「馬上就能用」**:①**正式服務的 config 目前有沒有登記任何 LoRA,我查不到**
(驗收是在臨時實例 5099 埠做的,原文明寫「正式服務未動」);②**LoRA 本身的授權要另外逐一查證**;
③家用端實測:**key 不相容的 LoRA 只記警告照樣出圖** —— **靜默失效,掛錯不會報錯。**

**這代表一個本檔沒有展開、但存在的路線:底模只負責「非動漫 + 陰鬱 + 半寫實」,
「扁平」交給棋子專用的 LoRA。** 要不要走這條,是管理者的裁決,不是我的建議(見第五節)。

## 第三節:覆核協調者的一項事實宣稱 —— 🔴 **協調者錯了,家用端是對的**

**結論一句話**:**矛盾是真的,而且今天仍可重現。** 不要照協調者的結論回覆家用端。

### 3.1 今天(2026-10-19)實測三處,兩邊確實不一致

```
$ curl -s "https://huggingface.co/api/models/cagliostrolab/animagine-xl-3.1" | jq -r .cardData.license
openrail++

$ curl -s "https://huggingface.co/cagliostrolab/animagine-xl-3.1/raw/main/README.md" | grep -n -i license
2:license: openrail++
404:This model is licensed under the [CreativeML Open RAIL++-M License](...)
411:*Note: This license supersedes any previous community license tags (e.g., FAIPL) applied to
     earlier versions of this repository, ensuring full compatibility with the standard SDXL ecosystem.*
```

檔內 metadata 由我直接對 HF 上那個檔案發 HTTP Range 請求、讀 safetensors 標頭取得
(只抓前 2048 bytes,沒有下載 6.9 GB):

```
$ curl -sL -r 0-2047 ".../resolve/main/animagine-xl-3.1.safetensors" -o head.bin   # 再用 node 解標頭 JSON
FILE-METADATA: "modelspec.license":"Fair AI Public License 1.0-SD"
```

**模型頁 = `openrail++`,檔內 metadata = `Fair AI Public License 1.0-SD`。兩者不一致,家用端照實回報,沒有寫錯。**

### 3.2 協調者的推論錯在哪(兩個獨立的錯)

**錯誤①:grep 範圍只有一個檔案,而答案在另外兩個檔案裡。**
協調者引用 `12-base-model-candidates-2026-10-13.md:17` 證明「我方 10-13 記的就是 FAIPL」。
那一行確實存在 —— **但它在 2026-10-14 已被我方自己正式更正為錯誤**:
`14-request-install-animagine-2026-10-13-report.md:36` 家用端標題逐字「**授權:查到一個貴方沒查到的事實**」;
`17-cr001-round3-jobs-and-decisions-2026-10-14.md:49` 我方標題逐字
「🔴 **授權:貴方是對的,我方 `12` 號文件寫錯了**」,下附我方**獨立複驗**的 curl 原始輸出,
並寫明「`12` 號文件的原文不刪除,另行加註更正」。

**所以 `12` 號那一行是【已登記為錯誤、刻意保留原文】的紀錄** —— 拿它反駁家用端,
等於拿一份已撤回的結論去推翻那份撤回本身。查法:`grep -rn "RAIL++" docs/ai-art-service-handoff/*.md`
(更正在 `14` 與 `17` 兩個檔裡,**只查 `12` 號不會看到**)。

**錯誤②:「家用端在講 10-13 的模型頁」這個讀法成立,而且指向 RAIL++-M。**
10-13 那天**有人真的去讀過模型頁**,讀到的就是 RAIL++-M,所以家用端那句話是準確的。

### 3.3 回覆家用端時該寫什麼(不是「沒有矛盾」)

1. **確認矛盾為真**,我方已獨立重現(指令如 3.1)。
2. **矛盾的解釋在模型頁自己的 README 第 411 行**:該授權**取代**早期版本沿用的 FAIPL 標籤。
   檔內 metadata 是發布當時烘進檔案的舊值,**檔案本身不會隨模型頁更新而改寫**。
3. **以模型頁為準(RAIL++-M)**,與我方 2026-10-14 已結案的判定一致 —— **方向建議,不是法律意見**
   (依 `04` 第五節免責)。⚠️ 這不是新發現,**直接指向 `17` 號第二節**,免得對方再查一輪。

## 第四節:換底模的連帶技術後果(事實,不做建議)

### ① SD1.5 的 512 原生解析度,對「立繪尺寸不綁 128×128」的硬限制

| | SD1.5 候選 | SDXL 候選 |
|---|---|---|
| 原生解析度 | **512 級** | 1024 級 |
| 本專案已實測成功的產圖尺寸 | **512×640(棋子)/ 640×960(立繪)** —— 家用端探針 3 張,CR-002 回覆第四節 | **896×1152** —— 第四輪 3 張工單全部如此(`19-round4-…` 第 24 行) |
| 線性邊長比 | 1 | **約 1.2~1.8 倍**,像素量約 **1.4~3.2 倍** |

**硬限制一句話**:走 SD1.5,立繪的可用來源像素就停在 640×960 這個量級,
**而服務內沒有任何已驗證的放大路徑可以補**(理由見③)。
⚠️ **這條現在關不掉** —— 立繪的實際尺寸本來就還沒定(`20c` 第四節第 2 點),
**尺寸定了這條才能判**。棋子不受影響(最終 32×40,是縮小不是放大)。

### ② sampler 白名單要不要加值 —— 🔴 **真正的缺口是 scheduler,不是 sampler**

- 現行白名單逐字:`euler` / `euler_ancestral` / `dpmpp_2m`(`14-…-report.md:28`)。
- 🔴 **scheduler 另外固定 `normal`、沒有 Karras**(同檔第 29 行逐字:「固定 `normal`(貴方已知並接受)」)。
  **`sampler` 與 `scheduler` 是兩個不同的軸:把 `dpmpp_sde` 加進白名單,不會讓你拿到 `karras`。**
  Hyper / Lightning / Turbo 類模型建議的 `dpmpp_sde` + `karras` **要同時動兩個軸**。
- 對照本檔候選:Cheyenne v2.0 要 `DPM++ 2M` → **已在白名單 ✅**;
  DreamShaper Turbo / Lightning 要 `DPM++ SDE` → ❌;SD1.5 Hyper 類 → ❌❌(兩軸都缺)。
- ⚠️ **動白名單會推翻我方自己 2026-10-13 的既有立場**:`10-…-reply` 第 163 行逐字
  「sampler/scheduler **維持服務預設,不要為我方改設定** —— 現階段變因已經夠多了」。**所以這是裁決,不是設定。**

### ③ `native_only` 在 512 原生下的放大行為,家用端明文說沒有實測過

家用端逐字(CR-002 回覆第 63 行):「原生解析度是 512 級,比 SDXL 小。工單建議填 `native_only`
(**`auto` 在 512 原生下的放大行為沒有實測**)。」

**連帶後果**:SD1.5 候選實務上只能走 `native_only`,而 `native_only` 的定義就是**不放大**。
**①的限制因此沒有服務內的解法** —— 要嘛立繪尺寸配合 640×960,要嘛改用 SDXL 候選,
要嘛另外開一條放大工序(**現在不存在,且未評估**)。

## 第五節:本檔不涵蓋什麼 + 交回裁決的項目

**不涵蓋**:哪一個好看(美術判斷);LoRA 候選本身與其授權;AI 去背模型(裁決 2 已在家用端進行中);
prompt 改寫;任何法律判斷(依 `04` 第五節免責);civitai 旗標字面定義(未查證)。

**交回管理者裁決(四項,本檔不排序、不建議)**:

| # | 要決定的事 | 不決定會卡住什麼 |
|---|---|---|
| D1 | 兩種素材用**同一個模型家族**(立繪-C / 棋子-B 是同一個)還是**兩個不同模型** | 風格一致性 vs 各自最佳;影響要請家用端裝幾個底模 |
| D2 | 要不要走 **2.4 的路線**:底模只負責「非動漫 + 陰鬱」,「扁平」交給棋子專用 LoRA | 若要,棋子側的底模選擇標準整個改變 |
| D3 | 要不要放寬 **sampler / scheduler 白名單**(等於推翻 2026-10-13 的「不要為我方改設定」) | 卡住所有 Hyper / Lightning / Turbo 版本 |
| D4 | **立繪的實際尺寸**(目前只知道不綁 128×128) | 不定就無法判 SD1.5 候選能不能用(第四節①) |
