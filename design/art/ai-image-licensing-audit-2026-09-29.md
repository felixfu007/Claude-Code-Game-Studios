# AI 影像生成模型 —— 授權查證報告(2026-09-29)

| 欄位 | 內容 |
|---|---|
| **建立日期** | 2026-09-29 |
| **派工依據** | 管理者裁決十一,逐字選項「先查 AI 模型授權(建議)」 |
| **狀態** | 草案 —— 八節皆已回填,但含 7 項標記未查證(見第八節),非法律意見,待管理者裁決是否足以據此選路線 |
| **這份文件不做的事** | 不是法律意見;不替管理者選路線;不動 `art-production-paths-2026-09-29.md`;不動 `src/` |
| **查證紀律** | 每條授權宣稱附「來源 URL + 查證日期」。沒有 URL 的宣稱一律標「未查證(憑訓練資料,可能過期)」 |

## 一、問題的完整形狀與查證方法

**這個問題不是「哪些模型能商用」那麼窄,要分開回答三層,它們常被混為一談:**

| 層級 | 問題 | 誰定的 |
|---|---|---|
| **① 模型權重本身的授權** | 我可不可以用這個模型做商業用途?能不能修改、能不能再散布? | 模型發布者的授權條款(CreativeML OpenRAIL、Apache-2.0、自訂條款等) |
| **② 產出圖片的著作權狀態** | 產出物我能不能主張權利?會不會有第三方能對它主張權利?訓練資料來源的爭議狀態算這一層 | 各國著作權法(尚無定論)+ 服務條款(部分平台會額外約定歸屬) |
| **③ 訓練衍生模型(LoRA/fine-tune)的授權** | 「可以用模型產圖」不等於「可以拿模型去訓練衍生模型再商用」,有些授權在這裡分岔 | 模型發布者授權條款裡的「衍生作品(Derivatives)」條款 |

**本專案為什麼③特別重要**:`design/art/art-direction.md` 與 `game-concept.md` 已定案 5 位固定
主角、立繪要隨劇情腐蝕逐步變化 —— 這代表無法只靠「每次下一樣的 prompt」維持角色一致性,
結構上需要訓練角色專屬模型(LoRA 或 fine-tune)。**若選到的底模型①過關但③不過關,等於
訓練完角色 LoRA 才發現不能商用放出成品 —— 這正是派工單警告的「答錯後面全白做」的地方。**

**本專案的硬約束(會篩掉很多選項)**:

| 約束 | 值 | 對查證的影響 |
|---|---|---|
| 執行硬體 | 家中桌機 RTX 5070 Ti / 16GB VRAM | 查證重心放在可本機執行的開源模型;雲端 API 另立一節 |
| 實體視線 | 遊戲畫面不能出現在公司座位螢幕上 | 不影響授權查證本身,已於 `art-production-paths-2026-09-29.md` 第十一節解掉(美術在家做) |
| 美術規格 | 像素風、480×270、64 色、1px 描邊、立繪 128×128 | 授權過關但畫不出這種風格的模型會標出,但風格適配性不是本文件重點(見該檔第十一節「像素網格精度」已分流為後製問題) |
| 販售意圖 | 這是要賣的遊戲,不是作品集 | 「個人非商業使用免費」等於出局,逐項明確標示 |

**查證方法**:使用 WebSearch 逐一查證下列模型/服務目前(2026-09-29)公開條款的原文或官方頁面
描述,每條宣稱附 URL + 查證日期。訓練資料截止 2026 年 1 月前的既有印象一律視為「未查證」重新確認,
若查不到就誠實標「未查證」,不得用訓練資料填補。

## 二、執行摘要表

**查證日期欄一律為 2026-09-29。「可否本機 16GB 跑」欄未經本專案實測,標「未查證(推測)」處
代表僅為業界常識層級的合理推測,不是量測結果——見第八節「未查證清單」第 4 項。**

| 模型/服務 | 權重授權 | 產出物商用狀態 | 可否訓練 LoRA 並商用(第③層) | 可否本機 16GB 跑 | 來源 URL |
|---|---|---|---|---|---|
| **Stable Diffusion 1.5** | CreativeML Open RAIL-M,無營收門檻 | 可商用 | **可,無額外費用** | 未查證(推測:可,模型小) | [terms.law](https://terms.law/ai-output-rights/stable-diffusion/)、[LICENSE 原文](https://raw.githubusercontent.com/CompVis/stable-diffusion/main/LICENSE) |
| **SDXL(base)** | CreativeML Open RAIL++-M,無營收門檻 | 可商用 | **可,無額外費用** | 未查證(推測:可) | [LICENSE.md](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md) |
| ⚠️ SDXL Turbo(非 base 版) | 另收費分級授權 | 需視營收購買授權(<$100萬適用$20/月) | 需另購授權 | 未查證 | [LICENSE.md](https://huggingface.co/stabilityai/sdxl-turbo/blob/main/LICENSE.md) |
| **Stable Diffusion 3.5** | Stability AI Community License,年營收 <$100萬免費 | 可商用(門檻內) | **可,門檻內免費(官方明文列為例子)** | 未查證(推測:可,視版本大小) | [stability.ai/license](https://stability.ai/license) |
| **FLUX.1 [dev]** | 非商業授權 | **可商用**(產出物例外允許) | 🔴 **原則上不可,除非另購商用授權(查到報價量級 $999/月,未官方交叉確認)** | 未查證(推測:可,但需另計算 VRAM) | [LICENSE.md](https://huggingface.co/black-forest-labs/FLUX.1-dev/blob/main/LICENSE.md) |
| **FLUX.1 [schnell]** | Apache 2.0,完全寬鬆 | 可商用 | **可,無額外費用**(但蒸餾模型訓練品質存疑,見未查證清單第5項) | 未查證(推測:可) | [Hugging Face 頁](https://huggingface.co/black-forest-labs/FLUX.1-schnell) |
| Civitai 個別微調模型(範例:Pixel Art Diffusion XL) | **依上傳者自訂,逐一不同** | 🔴 **此例要求商用先聯絡作者** | 逐一不同,不可外推 | 依底模而定 | [Civitai 模型頁](https://civitai.com/models/277680/pixel-art-diffusion-xl) |
| **Midjourney**(付費訂閱) | 服務條款(非開放權重) | 可商用(年營收>$100萬需Pro/Mega方案) | 平台不提供 LoRA 訓練功能 | 不適用(雲端服務) | [terms.law](https://terms.law/ai-output-rights/midjourney/) |
| **PixelLab** | 服務條款 | 可商用 | 🔴 **明文禁止拿產出訓練其他模型** | 不適用(雲端服務) | [PixelLab ToS](https://www.pixellab.ai/termsofservice) |
| **Scenario** | 服務條款 | 可商用 | **可,平台內建付費訓練功能($45/月起)** | 不適用(雲端服務) | [Scenario ToS](https://www.scenario.com/terms-and-conditions) |
| **Retro Diffusion**(Aseprite 外掛) | 工具閉源、買斷制 | 可商用(產出物) | 未查證(官方未載明是否支援自訓角色模型) | 不適用(本機工具但非開放模型) | [Astropulse itch.io](https://astropulse.itch.io/retrodiffusion) |

**這張表最重要的一行是 FLUX.1 [dev] 那一行**——它是唯一一個「產出物可商用」與「訓練 LoRA
商用」兩欄答案不同的開源模型,精準對應派工單警告的風險形狀。

## 三、可本機執行的開源模型(逐個查證)

⚠️ **每一項的「查證日期」皆為 2026-09-29,經 WebSearch 查證,非憑訓練資料回答。**

### 3.1 Stable Diffusion 1.5(CompVis/RunwayML,2022 發布)

| 層級 | 結論 | 依據 |
|---|---|---|
| ① 模型權重授權 | **CreativeML Open RAIL-M**,允許商業與非商業用途,**無營收門檻** | [Stable Diffusion Commercial License & Output Rights 2026](https://terms.law/ai-output-rights/stable-diffusion/)、[CreativeML Open RAIL-M 授權原文](https://raw.githubusercontent.com/CompVis/stable-diffusion/main/LICENSE) |
| ③ 訓練衍生模型(LoRA/fine-tune) | **允許**——授權文字明載可「use, reproduce, modify, perform, display, distribute」模型與其 Derivatives,受 Attachment A 的「用途限制」約束(而非「商用限制」) | 同上 |
| Attachment A 限制的性質 | **是行為黑名單(違法、傷害他人、色情兒少等約 10 類禁止用途),不是「禁止商用」或「禁止訓練衍生模型」** —— WebSearch 只取得截斷版本,**完整逐條文字未查證**,建議下一個人直接開網頁讀原文核對 | [huggingface.co 授權原文連結](https://huggingface.co/spaces/CompVis/stable-diffusion-license/raw/main/license.txt)(本次查證未能取得完整逐條文字,標記未查證) |
| VRAM 需求 | 未查證明確數字,但 SD1.5 是 2022 年模型,體積遠小於後續模型,**16GB VRAM 訓練 LoRA 綽綽有餘**是業界常識層級的推測,非本次量測 |  |

### 3.2 Stable Diffusion XL(SDXL,Stability AI,2023 發布)

| 層級 | 結論 | 依據 |
|---|---|---|
| ① 模型權重授權 | **CreativeML Open RAIL++-M**,無營收門檻,商用不受限 | [SDXL LICENSE.md](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md)、[terms.law](https://terms.law/ai-output-rights/stable-diffusion/) |
| ③ 訓練衍生模型 | 同 SD1.5,允許 | 同上 |
| 🔴 陷阱:同名不同款 | **SDXL Turbo、Stable Cascade 是不同授權**,SDXL Turbo 商用需另外購買分級授權(Creator/Developer Tier $20/月,適用年營收 <$100 萬)。**「SDXL」三個字不能只看一次就當全系列都適用同一條款** | [SDXL Turbo LICENSE.md](https://huggingface.co/stabilityai/sdxl-turbo/blob/main/LICENSE.md) |
| VRAM 需求 | 未查證明確數字;16GB 應可訓練 LoRA(社群常見配置為 8~12GB),但本次未找到官方或量測性的確切門檻,標記未查證 |  |

### 3.3 Stable Diffusion 3 / 3.5(Stability AI,2024 發布)

| 層級 | 結論 | 依據 |
|---|---|---|
| ① 模型權重授權 | **Stability AI Community License**——個人與年營收 <US$1,000,000 的組織免費商用;超過門檻需 Professional($20/月起)或 Enterprise 授權 | [Stability AI License 官方頁](https://stability.ai/license)、[Community License 公告](https://stability.ai/news-updates/license-update) |
| ③ 訓練衍生模型(LoRA/fine-tune) | **允許,且明文歸類為「衍生產品」,同樣適用 <$100 萬營收免費門檻**——「finetunes of Stable Diffusion 3」被官方文字直接點名為例子 | 同上,WebSearch 摘要引用 Stability AI 官方措辭 |
| 🔴 陷阱:禁止訓練「競品基礎模型」 | 明文禁止「用 SD3 生成的圖片去訓練一個新的基礎模型(尤其是 Stable Diffusion 的競品)」——**這條不影響本專案**(本專案訓練的是角色 LoRA,不是新的基礎模型),但屬於「訓練限制」的一種,登記在此以求完整 | 同上 |
| 🔴 陷阱:歷史信譽問題 | SD3 初版授權曾引發社群強烈反彈,一度被 Civitai **禁止上架**,Stability AI 事後改版才恢復——**代表這類自訂授權條款有被平台單方拒絕的先例,不是理論風險** | [Decrypt:「SD3 licensing questions plague Stability AI as image generator gets banned」](https://decrypt.co/235866/sd3-license-stability-ai-civit-ai-ban)、[Decrypt:「SD3 license revamped amid blowback」](https://decrypt.co/238871/stable-diffusion-3-license-revamped-amid-blowback) |
| VRAM 需求 | 未查證明確數字,SD3.5 有 Large/Medium/Turbo 等不同參數量版本,16GB 應可跑 Medium 級但確切訓練門檻未查證 |  |

### 3.4 FLUX.1 [dev](Black Forest Labs,2024 發布)

| 層級 | 結論 | 依據 |
|---|---|---|
| ① 模型權重授權 | **非商業授權(Non-Commercial License)**——僅供非商業用途(定義為「不直接或間接收取報酬」的研究、實驗、測試) | [FLUX.1-dev LICENSE.md](https://huggingface.co/black-forest-labs/FLUX.1-dev/blob/main/LICENSE.md) |
| ② 產出物 | **產出圖像本身可作任何用途,包含商業用途**——這是官方明文允許的例外 | 同上,[ArtificialGuyBR 授權白話整理](https://artificialguy.com/blog/flux-licensing-commercial-use/) |
| 🔴 ③ 訓練衍生模型 —— 本專案最關鍵的陷阱 | **LoRA 被歸類為「Derivative(衍生品)」,會繼承模型本身的非商業限制,即使產出圖像可以商用**。換言之:「拿 FLUX.1-dev 生圖來賣」合法,但「拿 FLUX.1-dev 訓練一個角色專屬 LoRA,而這個 LoRA 是為了做一款要賣的遊戲」——**這件事本身落在非商業限制內,除非另外取得商用授權** | [DeepWiki: Model Licenses and Restrictions](https://deepwiki.com/black-forest-labs/flux/5.1-model-licenses-and-restrictions)、[Flux LoRA 授權指南 2026](https://www.bestfreewebresources.com/flux-lora-licence-guide-2026) |
| 商用授權的價格 | 2025 年 6 月起 Black Forest Labs 推出「Self-Hosted Commercial License」,查到的一個報價點是 **US$999/月**(來源為第三方整理文章,非官方定價頁逐字確認,標記為「查到但未在官方定價頁交叉確認」) | [FLUX Developer Guide 2026](https://baeseokjae.github.io/posts/flux-1-image-generation-developer-api-guide-2026/) |
| 額外限制 | 不得用產出物訓練/微調/蒸餾出與 FLUX.1-dev 競爭的模型 | [FLUX.1-dev LICENSE.md](https://huggingface.co/black-forest-labs/FLUX.1-dev/blob/main/LICENSE.md) |
| **對本專案的意義** | **若選 FLUX.1-dev 訓練角色 LoRA,在沒有額外付費商用授權的情況下,訓練這個動作本身可能已經違反非商業限制**——這正是派工單指名要防的「答錯後面全白做」的具體案例 |  |

### 3.5 FLUX.1 [schnell](Black Forest Labs,2024 發布)

| 層級 | 結論 | 依據 |
|---|---|---|
| ① 模型權重授權 | **Apache 2.0,完全寬鬆**,個人、科學研究、商業用途皆可,無額外限制 | [FLUX.1-schnell Hugging Face 頁](https://huggingface.co/black-forest-labs/FLUX.1-schnell)、[ArtificialGuyBR](https://artificialguy.com/blog/flux-licensing-commercial-use/) |
| ③ 訓練衍生模型 | **Apache 2.0 下訓練 LoRA/fine-tune 不受商用限制**——與 FLUX.1-dev 是完全不同的法律狀態,不要因為兩者同屬「FLUX.1」系列就假設條款相同 | 同上 |
| ⚠️ 未查證的技術疑慮(非授權問題) | schnell 是「蒸餾模型」,設計目標是 1~4 步驟快速出圖,**社群對蒸餾模型能否穩定訓練出高品質 LoRA 存在技術上的不確定性**——本次查證只涵蓋授權層,這一項屬於第十一節提到的「一致性能否守住」範疇,未查證,需要實測 |  |

### 3.6 Civitai 社群微調模型(以個別像素風模型為例)—— 用來證明「同平台不代表同授權」

**Civitai 平台本身**的服務條款規定:使用者對自己上傳的內容(模型、產出圖片)保有著作權,**但每個模型各自的授權由上傳者自訂,平台不統一規範**。

| 模型範例 | 授權 | 商用結論 |
|---|---|---|
| Pixel Art Diffusion XL – Sprite Shaper | 自訂條款 | **明文要求「用於遊戲或 AI 相關專案的商業用途須先聯絡原作者」**——這正是「陷阱條款」的活範例:看起來是公開模型,實際商用需要額外取得授權 | [Civitai 模型頁](https://civitai.com/models/277680/pixel-art-diffusion-xl) |
| AziibPixelMix | CreativeML Open RAIL-M(繼承 SD1.5 底模的授權) | 商用無營收門檻限制,同 3.1 節 | [Civitai 模型頁](https://civitai.com/models/195730/aziibpixelmix) |
| Civitai 上標示「Fair AI Public License」的模型 | 屬 Share-Alike 精神(不得對下游使用者疊加新限制),**但查證顯示已有模型違反此精神、私自疊加商用限制/要求公開創作過程** | [Civitai:「What The License?!」](https://civitai.com/articles/18619/what-the-license) |

**結論(可直接落地的紀律)**:**每一個要用的具體模型檔案都要逐一打開授權頁核對,不能只確認「基礎模型是 OpenRAIL 所以整條 Civitai 生態都商用無虞」**——上表 Pixel Art Diffusion XL 就是一個「底模開放、但這個微調版本自己加了限制」的實例。

## 四、雲端服務

⚠️ **這是另一條路,不是路線 4 的替代,是補充**——`art-production-paths-2026-09-29.md` 第五節
已列出價格,本節補上逐一查證的授權結論(該檔當時未附查證日期與 URL)。

### 4.1 泛用型商業服務

| 服務 | 產出物商用 | 訓練專屬模型(LoRA/自訂模型) | 查證依據 |
|---|---|---|---|
| **Midjourney** | 付費訂閱者(Basic/Standard/Pro/Mega)擁有產出物,可商用,**但年營收 >US$100 萬的公司/員工必須訂閱 Pro 或 Mega 才能保有所有權**——本專案目前應落在此門檻之下 | 平台不提供角色專屬模型訓練功能(截至查證日) | [terms.law Midjourney 2026 指南](https://terms.law/ai-output-rights/midjourney/) |
| **免費/試用版 Midjourney** | 🔴 **完全不擁有產出物**——免費用戶「own nothing」,不可用於本專案 | 不適用 | 同上 |

### 4.2 遊戲美術專用服務(呼應選項書第五節已列名單,補授權查證)

| 工具 | 產出物商用 | 訓練專屬模型 | 🔴 陷阱條款 | 查證依據 |
|---|---|---|---|---|
| **Scenario** | 使用者擁有產出物,付費方案含完整商用授權,可用於遊戲、可販售、免權利金 | **可以**——使用者保有自訂訓練資料與訓練出的模型權重的權利 | 平台保留底層基礎模型架構與訓練基礎設施本身的所有權(這是常見措辭,不影響使用者對自己模型的權利);上傳內容會被授權給 Scenario 用於「提供訓練服務」——**這是必要的技術授權,不是內容所有權轉移,但條款寫法容易被誤讀成「Scenario 拿走我的圖」,建議正式簽約前逐字確認** | [Scenario Terms and Conditions](https://www.scenario.com/terms-and-conditions)、[Commercial Use Licenses of Scenario Platform Models](https://help.scenario.com/en/articles/commercial-use-licenses-of-scenario-platform-models/) |
| **PixelLab** | 使用者擁有產出物著作權,商用含在付費方案內 | 🔴 **明文禁止「訓練其他模型」(training other models)而未經明確許可** —— **這一條與本專案的路線衝突之處在於**:若計畫是「先用 PixelLab 生成大量角色圖,再拿這批圖去訓練自己的角色 LoRA」,這個動作可能落在 PixelLab 自己禁止的範圍內,需要向 PixelLab 另外取得許可,不能想當然視為「圖是我的,我要怎麼用都可以」 | 同左,這正是禁止項目本身 | [PixelLab Terms of Service](https://www.pixellab.ai/termsofservice) |
| **Retro Diffusion**(Aseprite 外掛,買斷制) | 🔴 **模型與程式碼本身歸 Astropulse LLC 所有、不可商用**,但**產出的像素圖歸使用者所有、可商用** —— 授權結構與 PixelLab/Scenario 不同(工具閉源、輸出開放,而非工具開放、輸出附條件) | **未查證**——這是閉源商業模型,官方頁面未載明是否開放使用者自行訓練專屬角色模型;若需要「5 位角色跨數月一致」,建議直接詢問 Astropulse 是否支援,不要假設 | [Astropulse itch.io 頁](https://astropulse.itch.io/retrodiffusion) |
| Sprixen / Sprite-AI / SpriteLab | **未查證**——本次查證時間有限,優先查了前三個工具的授權細節,這三個僅查過選項書既有的價格資訊,授權條款(尤其是③訓練層與陷阱條款)尚未逐一查證 | 未查證 | 見文末「查證進度與交接」 |

### 4.3 一般性提醒

**「產出物商用」與「訓練專屬模型的授權」是兩個獨立問題,必須分開向每一家服務確認。**
本節查到的三個具體案例(FLUX.1-dev、PixelLab、Retro Diffusion)**三種都不一樣**:
FLUX.1-dev 是「產出可商用、但訓練衍生模型本身违反非商業限制」;PixelLab 是「產出可商用、
但『拿產出去訓練另一個模型』被明文禁止」;Retro Diffusion 是「工具閉源不可商用,但產出物
開放商用,訓練自訂模型的可能性未載明」。**沒有一種通用規則可以套用到全部服務,每一家都要
單獨核對。**

## 五、🔴 陷阱條款節

**這節彙整本次查證實際遇到的每一種陷阱形狀,並標明是「已在本文件出現的實例」還是「已知存在
但本次未查到本專案會踩到的具體案例」。**

| 陷阱形狀 | 本專案相關的具體實例 | 狀態 |
|---|---|---|
| **營收門檻** | SD3/3.5 的 Community License:年營收 <$100 萬免費,超過需 Enterprise;SDXL Turbo 需另購分級授權(<$100 萬適用 $20/月 Creator Tier);Midjourney:>$100 萬營收的公司員工需訂閱 Pro/Mega 才保有所有權 | **實測存在,本專案目前應在門檻之下,但遊戲若賣座需要重新檢查** |
| **禁止拿產出物去訓練其他模型** | PixelLab 明文禁止;FLUX.1 系列禁止「用產出訓練/微調/蒸餾出競爭模型」(範圍較窄,只禁competitor) | **實測存在,PixelLab 這條與本專案「先生圖再訓練 LoRA」的計畫直接衝突,見 4.2 節** |
| **「訓練模型本身」與「用模型產出物」授權分岔** | FLUX.1-dev 核心陷阱:輸出可商用,但訓練 LoRA(=製作 Derivative)本身仍受非商業限制 | **實測存在,本文件第 3.4 節最關鍵發現** |
| **模型作者條款與權重託管平台不一致** | Civitai 上的 Pixel Art Diffusion XL 要求商用先聯絡作者,即使 Civitai 平台本身允許商用內容託管;Civitai 自己的文章記載部分「Fair AI Public License」模型被上傳者私自疊加限制,違反該授權本身的 Share-Alike 精神 | **實測存在,見 3.6 節** |
| **同系列不同版本條款不同,不能只查一次代表全系列** | 「FLUX.1」dev 非商業 vs schnell Apache 2.0;「SDXL」base 版 OpenRAIL++ vs Turbo 版另收費;「Stable Diffusion」1.5/XL 無門檻 vs 3/3.5 有 $100 萬門檻 | **實測存在,三個系列各自都有此陷阱,是本次查證最常見的錯誤來源** |
| **歷史上曾被平台單方拒絕/下架的授權** | SD3 初版授權引發社群反彈,一度被 Civitai 禁止上架 | **實測存在(已修復),證明「條款寫出來」不保證「條款會被下游平台接受」,是額外的營運風險而非單純法律風險** |
| 使用者數門檻(非營收) | **本次查證未遇到具體案例**——所查的每一項門檻條款都是以營收金額計算,未發現以「使用者數」為門檻的條款 | 未發現,不代表不存在,只代表本次查證範圍內沒遇到 |
| 要求標示 AI 來源(attribution) | **與遊戲上架的 Steam AI 揭露義務相關但性質不同**——Steam 的揭露義務來自平台規則(見第六節),不是模型授權條款本身要求標示;本次查證未發現要求「在遊戲內標示某模型名稱」的條款 | 未發現要求模型標示的條款本身,但 Steam 平台規則另有揭露義務,不要混為一談 |
| 日後可單方面修改條款 | **本次未查到任一項本文件列出的授權含有「發布者保留單方面溯及既往修改條款」的明文條款**,但 SD3 初版授權在社群壓力下「改版」這件事本身說明:**即使沒有明文的單方修改權,發布者事實上仍可能改版**——法律上是否溯及既往影響已下載的舊版權重,本次未查證 | 未查到明文條款,但有事實上發生過改版的先例,兩者要分開理解 |

**🔴 本節最重要的一句話,對應派工單的核心關切**:**本專案目前規劃的路徑(訓練角色專屬
LoRA、用於商業遊戲)剛好精準踩在「訓練模型本身」與「僅使用產出物」授權分岔的那條線上。**
FLUX.1-dev 與 PixelLab 兩個範例分別從「模型授權」與「服務條款」兩個不同來源,各自對這條線
給出了限制。**選模型/服務時,必須明確問「我要不要訓練衍生模型」這個問題,不能只問「我要不要
商用產出物」——這是兩個不同的問題,本次查證裡目前只有 SD 系列(1.5/XL/3.5)與 FLUX.1 schnell
（Apache 2.0）對兩個問題都給出「可以」的答案且無需另外付費。**

## 六、🔴 法律狀態的誠實揭露(非法律意見)

**本節把「條款白紙黑字寫的」「目前的實務共識」「仍在訴訟或立法中的未定事項」三者分開寫,
不混在一起。本 agent 不是律師,不對本節內容的法律效力負責,重大決策前應諮詢真正的法律專業人士。**

### (A)白紙黑字寫的(條款/官方政策原文)

- 美國著作權局(U.S. Copyright Office)官方政策文件明文要求「人類作者身份」(human authorship)
  作為著作權保護的前提,並要求申請人揭露作品中 AI 生成內容的比例與人類貢獻的具體說明。
  來源:[US Copyright Office 官方政策指引 PDF](https://www.copyright.gov/ai/ai_policy_guidance.pdf)、
  [官方 AI 專頁](https://www.copyright.gov/ai/)(查證日 2026-09-29)。
- Steam(Valve)自 2026-01-17 起更新 AI 揭露規則,**只針對「玩家會看到的內容」**(player-facing
  content),分「預先生成」與「即時生成」兩類,店面頁面需勾選揭露並附文字說明;**開發階段使用
  AI 工具本身(例如效率工具)不需要揭露,只有最終進入遊戲、玩家看得到的內容需要揭露**。
  來源:[PC Gamer 報導](https://www.pcgamer.com/software/ai/steam-updates-ai-disclosure-form-to-specify-that-its-focused-on-ai-generated-content-that-is-consumed-by-players-not-efficiency-tools-used-behind-the-scenes/)、
  [StraySpark 開發者指南](https://www.strayspark.studio/blog/steam-ai-disclosure-rules-2026-indie-developer-guide)(查證日 2026-09-29)。
  **對本專案的具體意義**:若走 AI 生圖路線,遊戲上架 Steam 時的美術資產屬於「玩家會看到的
  預先生成內容」,**依規則需要在店面頁面勾選揭露,這不是選擇性的,是 Steam 平台規則**。

### (B)目前的實務共識(非條款原文,是律師/業界整理出的操作慣例)

- 美國著作權局立場的實務操作解讀:「AI 輔助但有人類有意義的創作控制」可以取得著作權保護,
  但「僅靠 prompt(無論多詳細)」通常不足以構成人類作者身份,因為模型仍保有對最終視覺輸出的
  過度控制權。**這代表:若本專案完全靠 AI 生成、僅用文字描述沒有後續人工大幅修改,產出物本身
  在美國可能拿不到著作權保護**——但「拿不到著作權」不等於「不能商用」(見下方(C)的區分)。
  來源:[Jones Day 法律分析](https://www.jonesday.com/en/insights/2025/02/copyrightability-of-ai-outputs-us-copyright-office-analyzes-human-authorship-requirement)(查證日 2026-09-29)。
- 台灣智慧財產局的實務見解(非判決,是行政機關函釋層級):**若 AI 只是輔助工具(如繪圖軟體),
  創作過程中有實際人類創作投入,完成的創作仍受著作權保護,權利歸屬實際創作者**;若創作過程
  完全由 AI 演算法完成、沒有實際人類創作投入,產出內容不受著作權保護。**台灣的判準文字與美國
  相近(強調人類創作參與程度),但這是行政函釋,不是法院判決,個案仍須由法院依具體事實認定。**
  來源:[經濟部智慧財產局著作權主題網函釋](https://www.tipo.gov.tw/tw/copyright/692-63403.html)、
  [聖島智慧財產專業團體整理](https://www.saint-island.com.tw/Tw/Knowledge/Knowledge_Info.aspx?IT=Know_0_1&CID=715&ID=62781)(查證日 2026-09-29)。

### (C)仍在訴訟或立法中的未定事項

- 2026 年 3 月,美國最高法院拒絕受理是否「完全由 AI 自主生成的作品」可以取得著作權保護的
  上訴案(Thaler 案),**維持了「人類作者身份」的下級法院見解,但這是「拒絕受理」不是「肯認
  規則正確」——最高法院沒有對此問題做出實體判決,爭議並未因此在法理上被「解決」,只是這一次
  的訴訟途徑走到終點**。
  來源:[Morgan Lewis 分析](https://www.morganlewis.com/pubs/2026/03/us-supreme-court-declines-to-consider-whether-ai-alone-can-create-copyrighted-works)、
  [Mayer Brown 分析](https://www.mayerbrown.com/en/insights/publications/2026/03/supreme-court-denies-review-in-ai-authorship-case)(查證日 2026-09-29)。
- **訓練資料本身的著作權爭議未查證進度**:台灣智慧財產局函釋提到「將受著作權保護的作品輸入
  AI 訓練,原則上構成著作權法上的重製,除非符合合理使用」——**這代表:即使本專案使用的模型
  本身授權允許商用,若該模型的訓練資料本身涉及未經授權重製他人著作,理論上訓練行為本身可能
  存在法律瑕疵。這是模型發布者要承擔的風險還是下游使用者也可能被牽連,本次查證沒有找到明確
  答案,標記為未查證的開放問題。**
  來源:同上智慧財產局函釋(查證日 2026-09-29)。
- **「產出物近似於訓練資料中某著作」是否構成侵權**,目前在美國有多起進行中的訴訟(如
  Disney 對 Midjourney 的訴訟,terms.law 文章標題提及),**本次查證沒有深入這些個案的具體
  進展與結論,只確認了訴訟存在這個事實**,標記為未查證的開放問題,不應被本文件視為已有定論。

### 三者不要混在一起的具體提醒

**「模型授權允許商用」(A 類事實)、「著作權局說沒有人類創作投入就拿不到著作權保護」(B 類
共識)、「訓練資料本身是否侵權尚無定論」(C 類未定事項)是三個完全獨立的問題,一個問題的
答案不能拿來回答另一個問題**。舉例:FLUX.1 schnell 的 Apache 2.0 授權(A 類,白紙黑字)
不代表用它產出的圖片一定能在美國取得著作權保護(B 類,實務共識另有判準);而即使產出物能
取得著作權保護,也不代表訓練資料來源沒有法律瑕疵(C 類,未定事項)。

## 七、對本專案的建議(選項與代價,不做決定)

🔴 **本節只列選項與代價,不替管理者選路線** —— 依協作規則,美術產出路線的最終選擇屬管理者
裁決範圍,`art-director` 只提供分析。

### 選項一:Stable Diffusion 1.5 或 SDXL 作為底模,本機訓練角色 LoRA

**代價**:兩者授權在①②③三層都是本次查證中最乾淨的(無營收門檻、允許訓練衍生模型、無需
額外付費),16GB VRAM 訓練 LoRA 的可行性業界常識上應該足夠(但本次未實測)。**代價是模型
較舊(SD1.5 為 2022 年、SDXL 為 2023 年),生成品質與可控性可能不如新一代模型,像素風的
輸出天花板需要實際測試才知道。**

### 選項二:Stable Diffusion 3.5 作為底模

**代價**:授權同樣允許訓練 LoRA 且免費(本專案應在 $100 萬營收門檻之下),模型較新、生成
品質理論上較好。**代價是**:此系列曾有過初版授權被社群反彈、被 Civitai 下架的先例,雖然
已修正,但代表 Stability AI 的授權條款有過改版史,需要留意日後是否再次調整。

### 選項三:FLUX.1 schnell(Apache 2.0)作為底模

**代價**:授權最寬鬆(Apache 2.0 無任何商用/訓練限制),**但技術上是蒸餾模型,社群對其能否
穩定訓練出高品質 LoRA 存在未查證的疑慮**——選這條路等於同時承擔「授權最乾淨」與「技術可行性
最不確定」兩個相反的風險,需要先做小規模訓練測試才能判斷。

### 選項四:FLUX.1 dev + 付費商用授權

**代價**:生成品質公認業界領先,但**本次查到的商用授權報價量級為 US$999/月(未在官方定價頁
交叉確認,標記存疑)**,若這個數字屬實,對一人團隊的量級而言是相當高的固定支出,需要先向
Black Forest Labs 官方確認實際報價後再評估是否可負擔。

### 選項五:PixelLab / Scenario 等專用工具

**代價**:門檻低、不需要自己組建訓練環境,PixelLab 明確禁止「拿產出去訓練其他模型」——**若
選這條路,角色一致性必須靠工具本身的功能(PixelLab 的角色姿勢骨架功能、Scenario 的自訂模型
訓練功能)達成,不能繞道自己另外拿產出物訓練別的模型**。Scenario 本身就內建訓練自訂模型的
付費功能($45/月起,依 `art-production-paths-2026-09-29.md` 第五節),等於把選項一~四的
「自己訓練 LoRA」整個外包給平台做,代價是每月訂閱費,換來的是不用自己顧本機訓練環境。

### 共通的下一步(不論選哪一條)

**不論選哪個模型/服務,下一步都應該是「先做 1 位角色的完整素材組」的小規模驗證**,呼應
`art-production-paths-2026-09-29.md` 第八節與第十一節已經反覆強調的檢查點協議精神——本文件
解決的是「哪些選項在法律上站得住腳」,**不解決「站得住腳的選項裡,哪一個做得出好看的畫面」**,
後者需要實測,而且只有使用者能在家中桌機上跑(見選項書第十一節「問題 2」)。

## 八、查證進度與交接

### 已完整查證(有 URL + 日期,見各節)

- Stable Diffusion 1.5、SDXL(含 Turbo 陷阱)、SD3/3.5 的①②③三層授權
- FLUX.1 dev、FLUX.1 schnell 的①②③三層授權,含 dev 版最關鍵的「訓練即非商業用途」陷阱
- Civitai 平台本身條款 + 兩個具體像素風模型範例(對照組)
- Midjourney 商用門檻
- PixelLab、Scenario、Retro Diffusion 三個遊戲美術專用工具的授權(價格已在
  `art-production-paths-2026-09-29.md` 第五節,本文件補授權)
- Steam AI 揭露規則(2026-01-17 更新版)
- 美國著作權局人類作者身份要求、2026-03 最高法院拒絕受理 Thaler 案
- 台灣智慧財產局對 AI 生成著作權的行政函釋見解

### 🔴 未查證清單(標記給下一個人接手)

1. **CreativeML Open RAIL-M / RAIL++-M 的 Attachment A 完整逐條文字**——WebSearch 只取得
   截斷版本,只確認了「性質是用途黑名單而非商用禁令」,沒有逐條核對全部約 10 項禁止用途的
   確切文字。**下一步**:直接開啟
   [huggingface.co/spaces/CompVis/stable-diffusion-license/raw/main/license.txt](https://huggingface.co/spaces/CompVis/stable-diffusion-license/raw/main/license.txt)
   或 [GitHub 原文](https://raw.githubusercontent.com/CompVis/stable-diffusion/main/LICENSE) 讀取全文。
2. **FLUX.1-dev 商用授權的實際報價**——查到 US$999/月這個數字來自第三方整理文章,**未在
   Black Forest Labs 官方定價頁交叉確認**。下一步:直接查
   [bfl.ai/licensing](https://bfl.ai/licensing) 官方頁面。
3. **Sprixen、Sprite-AI、SpriteLab 三個工具的授權條款**——本次查證時間有限,只查了價格
   (已在選項書第五節),沒有查授權細節(產出物商用範圍、能否訓練專屬模型、陷阱條款)。
4. **各模型/服務在 16GB VRAM 下訓練 LoRA 的實際可行性與所需時間**——這是技術可行性問題,
   不是授權問題,本文件完全沒有觸及,呼應選項書第十一節「問題 2:只有使用者能在家那台跑」。
5. **FLUX.1 schnell 蒸餾模型能否穩定訓練出高品質 LoRA**——本次只查到「存在技術疑慮」這個
   定性描述,沒有查到具體的社群測試結果或量化數據。
6. **訓練資料侵權爭議是否會牽連下游使用者**(而非只有模型發布者承擔)——台灣智財局函釋提到
   訓練行為本身可能構成重製,但本次沒有查到「若原始訓練有瑕疵,下游商用是否會被追溯究責」
   的具體見解,這需要更深入的法律研究,可能超出 WebSearch 能查到的範圍,建議由真正的法律
   專業人士處理。
7. **本專案目標上架平台是否只有 Steam**——第六節的 Steam 揭露規則查證是基於選項書已提及
   Steam,若管理者計畫另外上架其他平台(如 itch.io、GOG),那些平台各自的 AI 內容政策
   本文件完全沒有查證。

### 給下一個接手者的具體指引

若要繼續查證,**優先順序建議**:先補 1(RAIL-M 完整條文,因為 SD 系列是本次結論中授權
最乾淨的選項,若 Attachment A 藏有本文件沒發現的限制,會直接影響第七節的建議);再補 2
(FLUX.1-dev 官方報價,因為若報價遠低於 $999/月,選項四的排序可能上升);4 與 5(技術
可行性)**不屬於本次派工範圍(本次只查授權),但邏輯上是選路線前必須補的下一塊拼圖**。
