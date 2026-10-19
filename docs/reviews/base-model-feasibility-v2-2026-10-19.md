# 底模可行性評估 v2 —— 判準加入「離開動漫血統」之後的重開

**日期**:2026-10-19
**撰寫**:`technical-director`
**範圍**:單檔 checkpoint 可行性、VRAM、授權分層、服務端改不改得動
**不在範圍**:哪一個好看(美術判斷,歸 `art-director` 與管理者)

> 🔴 **本檔刻意不排名、不寫「建議採用」。** v1(`12-base-model-candidates-2026-10-13.md`)
> 有「候選一(建議採用)」,這一版沒有 —— 新判準有一半是畫風判斷,不是技術網域。

---

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

(待填)

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

檔內 metadata 則由我直接對 HF 上那個檔案發 HTTP Range 請求、讀 safetensors 標頭取得
(只抓前 2048 bytes,沒有下載 6.9 GB):

```
$ curl -sL -r 0-2047 "https://huggingface.co/cagliostrolab/animagine-xl-3.1/resolve/main/animagine-xl-3.1.safetensors" -o head.bin
$ node -e "...讀 safetensors 標頭 JSON..."
FILE-METADATA: "modelspec.license":"Fair AI Public License 1.0-SD"
```

**模型頁 = `openrail++`,檔內 metadata = `Fair AI Public License 1.0-SD`。兩者不一致,家用端照實回報,沒有寫錯。**

### 3.2 協調者的推論錯在哪(兩個獨立的錯)

**錯誤①:grep 的範圍只有一個檔案,而答案在另外兩個檔案裡。**
協調者引用 `12-base-model-candidates-2026-10-13.md` 第 17 行證明「我方 10-13 記的就是 FAIPL」。
那一行確實存在 —— **但它在 2026-10-14 已被我方自己正式更正為錯誤**:

- `14-request-install-animagine-2026-10-13-report.md:36` 家用端標題逐字:「**授權:查到一個貴方沒查到的事實**」,
  並引用模型頁原文 `This model is licensed under the CreativeML Open RAIL++-M License.`
- `17-cr001-round3-jobs-and-decisions-2026-10-14.md:49` 我方標題逐字:
  「🔴 **授權:貴方是對的,我方 `12` 號文件寫錯了**」,下方附我方**獨立複驗**的 curl 原始輸出,
  並寫明「我方 `12` 號文件的原文不刪除,另行加註更正」。

**所以 `12` 號那一行是一份【已登記為錯誤、刻意保留原文】的紀錄。** 拿它當「我方的記載」來反駁家用端,
等於拿一份已撤回的結論去推翻那份撤回本身。查法:`grep -rn "RAIL++" docs/ai-art-service-handoff/*.md`
(我方的更正在 `14-…-report.md` 與 `17-…` 兩個檔裡,只查 `12` 號不會看到)。

**錯誤②:「家用端在講 10-13 的模型頁」這個讀法本身成立,而且指向 RAIL++-M。**
10-13 那天**有人真的去讀過模型頁**,讀到的就是 RAIL++-M(上面 `14-…-report.md` 那次)。
家用端寫「跟 10-13 查到的模型頁(RAIL++-M)不一致」是準確的。

### 3.3 回覆家用端時該寫什麼(不是「沒有矛盾」)

1. **確認矛盾為真**,我方已獨立重現(指令如 3.1)。
2. **矛盾的解釋在模型頁自己的 README 第 411 行**:該授權**取代**早期版本沿用的 FAIPL 標籤。
   檔內 metadata 是發布當時烘進檔案的舊值,**檔案本身不會隨模型頁更新而改寫**。
3. **以模型頁為準(RAIL++-M)**,這與我方 2026-10-14 已結案的判定一致 —— 這是**法律判斷的方向建議,
   不是法律意見**,依 `04-security-and-licensing.md` 第五節開頭的免責聲明。
4. ⚠️ **這件事不是新發現,是第二次撞到同一件事。** 回覆時直接指向 `17` 號第二節,
   免得對方再查一輪。

## 第四節:換底模的連帶技術後果

(待填)

## 第五節:本檔不涵蓋什麼 + 交回裁決的項目

(待填)
