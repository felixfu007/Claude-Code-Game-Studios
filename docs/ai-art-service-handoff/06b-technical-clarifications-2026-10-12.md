# 06b 技術側疑義回覆 —— CR-001 第一批(D1~D5)

| 欄位 | 內容 |
|---|---|
| 日期 | 2026-10-12 |
| 作者 | `technical-director`(`06b-change-request-lora-requirements-2026-10-08.md` 的同一作者) |
| 回覆對象 | `docs/ai-art-service-handoff/06-change-request-001-reply-2026-10-10.md`(承接方原文逐字副本) |
| 涵蓋範圍 | **技術側五條**:Q1、Q6、第九節第 1 / 2 / 3 / 4 點 |
| **不涵蓋** | Q2 / Q5 / Q7 / Q8 / Q9 與第九節第 5 點 —— 美術側疑義由 `art-director` 另覆(見 `06a-art-clarifications-2026-10-12.md`);訓練素材來源為管理者裁決,另案處理 |

## 證據等級標示法(本檔用)

本專案三分法:**(A)** 實機驗證 /**(B)** 專案參考庫明文記載 /**(C)** 訓練資料推測、未經驗證。
**(C) 級不得當成既定事實引用。**

本檔多出一個標籤,因為三分法沒有對應的格子:

> **(B′) = 外部上游原始碼 / 發布紀錄,版本釘死、逐字取回、指令可重跑。**
> 它**不是 (A)** —— 我**沒有執行過 sd-scripts**,本機也沒有可供執行的環境。
> 它**強於 (C)** —— 不是憑記憶,是當場用 `gh api` 自 GitHub 取回指定 commit 的檔案內容後 grep 出來的,
> 每一條都附了可重跑的指令。
> **凡本檔標 (B′) 的,請讀成「原始碼/官方發布紀錄白紙黑字這樣寫」,不要讀成「我跑過」。**

本檔所有 (B′) 級查證的釘死版本:

```bash
gh api repos/kohya-ss/sd-scripts/commits/690ea7f9 --jq '.sha, .commit.author.date, .commit.message'
# 690ea7f96c23182352ec63def76d431c6120bd2f
# 2026-09-24T10:34:44Z
# Merge pull request #2441 from kohya-ss/dev  /  Version 0.12.0
```

此即承接方 `cr001-lora-d2-d3.md` 宣告使用的 commit,也是該倉庫 `main` 當前 HEAD(`pushed_at` 2026-09-24T10:35:53Z)。**我方查證的版本與承接方實測的版本是同一個。**

---

## 一、Q1 —— 色票檔欄位標題行不屬於 4.2 判準任何一類

**問題**

`06a` 4.2 的修訂判準只定義三種行(資料列 = `#` + 恰好 6 碼 hex + 逗號 / 註解 = 其餘 `#` 開頭 / 空行),
而 `design/art/color-palette.csv` 裡有一行 `hex,category,label` 不以 `#` 開頭 —— **照字面是未定義的行**。
承接方暫定「恰好等於該字串就當標題略過,其餘未定義行 → 整份解析失敗」。

**裁決**

1. **確認承接方的暫定解讀,照現行實作即可,不必改。** 兩半都確認:
   - 恰好等於欄位標題的那一行 → 略過,不計入資料列、**不計入 4.2 的 64 色上限**。
   - 其餘任何不屬於三類的行 → **整份色票解析失敗**(「無法驗證」、不產 PNG)。
     理由與承接方寫的相同:「看不懂就跳過」正是 `06a` 2.3 要防的靜默略過。**我方同意失敗要向外倒(fail-closed)。**
2. **補兩條實作細節(請併入)**:
   - **標題行是選用的,不是必需的。** 工具**不得**因為缺少標題行而判失敗 —— 未來若有人手寫一份只有資料列的色票,它必須能解析。
   - 🔴 **比對前請先剝掉行尾空白與 `\r`。** 現行檔案是 LF 結尾(我已用 `od -c` 逐位元確認,見下),
     但**本專案在 Windows 上開發**,任何人用某些編輯器另存就可能變成 CRLF。
     在承接方自己訂的「其餘未定義行 → 整份失敗」規則下,**一個看不見的 `\r` 會讓整份色票解析失敗**,
     而且錯誤訊息會指向一行看起來完全正確的字。這是我方要求加這一句的唯一理由。
3. **4.2 判準表要不要正式加一列:要,但不由我加。** `06a` 是美術側文件(`art-director` 網域),
   且該檔今日剛由 `art-director` 另行回覆。**本裁決即為正式答覆,具契約效力;下次修訂 `06a` 4.2 時請一併把下列一列補進判準表**:

   | 這一行是什麼 | 判準 |
   |---|---|
   | **欄位標題(選用)** | 整行(剝除行尾空白與 `\r` 後)恰好等於 `hex,category,label`。略過,不計入 64 色上限。最多一行,且必須出現在第一個資料列之前 |

**依據(我實際查了什麼)**

- 🔴 **承接方引用的行號是錯的,或至少已經漂掉了 —— 請不要再用行號定位這一行。**(A) 級,本機實測:

  ```bash
  grep -n '^hex,category,label$' design/art/color-palette.csv
  # 82:hex,category,label
  ```

  承接方 Q1 寫「`color-palette.csv` 第 76 行」。**實測是第 82 行。**
  而該檔在我方倉庫**只有一個 commit**(`4e8d05b`,2026-10-08 16:27:04 +0800),工作區相對 HEAD 無修改
  (`git status --porcelain design/art/color-palette.csv` 無輸出)。
  成因我**沒有查出來**(見下方「我沒把握的部分」)。**結論不受影響** —— 不論它在第幾行,
  全檔只有這一行不屬於三類,裁決不變。
- **全檔實測計數**(A) 級:

  ```bash
  wc -l design/art/color-palette.csv                                   # 125
  grep -c -E '^#[0-9A-Fa-f]{6},' design/art/color-palette.csv          # 38   (資料列)
  grep -c '^#' design/art/color-palette.csv                            # 124
  grep -c '^[[:space:]]*$' design/art/color-palette.csv                # 0    (空行)
  grep -n -v '^#' design/art/color-palette.csv                         # 只有 82:hex,category,label
  ```

  → 125 = 124(`#` 開頭)+ 1(標題行)。**全檔恰好一行是未定義行**,就是標題行。
  → 38 色 + 標題 1 行 = 39,**即使把標題誤計為資料列也還沒撞到 64 上限** —— 所以這次沒出事,是運氣不是設計。
- **行尾位元組實測**(A) 級:

  ```bash
  sed -n '82p' design/art/color-palette.csv | od -c | tail -3
  #  h e x , c a t e g o r y , l a b e l \n
  ```

  → **LF,沒有 `\r`,也沒有 BOM**(檔首三位元組 `23 20 63` = `# c`)。
  ⚠️ **我中途用 `grep -c $'\r' <file>` 量過一次,回報 125(= 全部行都有 CR)——那是假陽性。**
  以 `od -c` 逐位元複驗後確認無 CR。**登記在此是因為下一個人很可能也會用那條 grep。**

**我沒把握的部分**

- **行號 76 vs 82 的差異我沒查出成因。** 該檔只有一個 commit,所以不是我方 commit 之間的漂移。
  可能是承接方拿到的是 commit 前的草稿副本,也可能是他們數錯。**我沒有去 AI_IMG 找他們手上那份副本比對**
  (`gh api` 的 code search 對 private repo 回 `total_count: 0`,我判斷那是搜尋索引限制而非「檔案不存在」,
  **沒有進一步用 contents API 逐路徑確認**)。
- **「標題行最多一行、且必須在第一個資料列之前」是我加的約束,不是承接方提的,也沒有實測依據。**
  理由是它讓「略過」這個行為不依賴出現位置。若承接方認為這條徒增複雜度,我方可以撤回。

---

## 二、Q6 —— 打錯的資料列會被當成註解,沒有任何提示

**問題**

`#GG0000,skin,x`(非 hex)、`#FF00F,skin,x`(5 碼)都不符合「`#` + 恰好 6 碼 hex + 逗號」,
照 4.2 判準**就是註解**。等於色票裡少了一色而沒有人知道。
承接方現行:當註解,但在報告 `palette.warnings` 列出「長得像資料列的註解」,**不判失敗**。

**裁決**

🔴 **改成判失敗。** 命中「長得像資料列的註解」時:**整份色票解析失敗 → 無法驗證 → 不產出 PNG → 非 0 結束碼**,
與 `06a` 4.3「色票檔不存在/解析失敗」同一條路徑。**不要只留 warning。**

三個理由,第一個是決定性的:

1. **這正是本專案已經踩過一次、而且只被人眼抓到的那個形狀。** `06a` 4.2 原文寫「`#` 開頭整行視為註解」,
   照它實作**一色都讀不到**,而且**不會報錯** —— 它會安靜地回報一份空色票。
   那次不是規則抓到的,是 `art-director` 真的拿它去產第一個檔案時才發現的。
   **Q6 是同一個形狀的第二次**:一個打錯的字元,讓一個顏色安靜地從色票裡消失,而工具照樣回報通過。
   📌 承接方自己在 Q6 裡把這個風險講得比我還清楚,這裡只是把它升級為硬性行為。
2. **色票的色數是有人在看的數字。** 4.2 訂了 64 色上限,色票檔自己的註解也寫著「角色數由 5 擴充時重新核算 64 色總配額分配」。
   靜默掉一色會讓這個數字錯,而且錯的方向是**偏小**(看起來還有餘裕)。
3. **現在改的成本是零。** 承接方已回報:交付的 v0.1 色票 `warnings` 為空
   (`06` 第八節逐字:「交付的 v0.1 色票 warnings 為空」)。**所以這個改動今天不會讓任何現有檔案變紅。**
   越晚改成本越高。

**兩個附帶要求:**

- **錯誤訊息必須同時印出行號與該行原文。** 失敗向外倒只在「人能立刻看出哪一行、錯在哪」時才有用;
  只說「色票解析失敗」會把一個 5 秒的修正變成一次翻檔。
- **「長得像資料列」的判準請在 `docs/postprocess.md` 裡寫死成一句可照做的話,並把它當契約。**
  判準由承接方定(你們有實作),但**必須白紙黑字寫出來**,否則它是一條只有實作者知道的規則。
  ⚠️ **已知代價,我方接受**:若將來某行散文註解不幸命中該啟發式,整條流水線會卡住,直到有人去改那行註解。
  在 `06a` 2.3 已選定的 fail-closed 方向下,這個代價比「安靜少一色」小。

**依據(我實際查了什麼)**

- `06a` 4.2 的 2026-10-08 修訂段落逐字(本機 (A) 級,`sed -n '190,215p' docs/ai-art-service-handoff/06a-change-request-art-requirements-2026-10-08.md`):
  > 🔴 **2026-10-08 修訂:原文寫「`#` 開頭整行視為註解」,那是錯的,照它寫解析器會一色都讀不到。**
  > …… **發現者**:`art-director`(撰寫本節的同一人),在據此產出第一份實際色票檔時發現。
- `06a` 4.3 逐字:「工具**不得**靜默回報「0 個離盤色像素」,必須明確回報「無法驗證……」,並且**不產出目標 PNG**」。
  → **Q6 的現行做法(當註解 + warning + 照樣通過)與 4.3 的方向相反**,只是 4.3 字面上沒涵蓋「色票解析成功但內容被吃掉一行」這一格。本裁決把這一格補上。
- `06` 第八節「新增疑義」Q6 原文(本機 (A) 級,逐字副本)。

**我沒把握的部分**

- **我沒有看過承接方「長得像資料列」啟發式的實際實作。** 我沒有讀 `ai_art_postprocess/` 任何一行程式碼,
  也沒讀 `docs/postprocess.md`。**我裁決的是「命中時要失敗」,不是「什麼叫命中」** —— 後者仍由承接方定義,我方只要求它被寫下來。
- **我沒有量過這個改動會不會影響 55 個既有測試。** 若它會讓既有測試大量變紅,請回報,我方重新評估時機(但不改方向)。

---

## 三、第九節第 2 點 —— fused backward pass:`06b` 第七節引用了錯的數字

### 先回答派工單問的那一句:**我有查到原始碼。**

**查到了。(B′) 級** —— 自 GitHub 取回 `kohya-ss/sd-scripts` 在承接方宣告的同一個 commit
(`690ea7f96c23182352ec63def76d431c6120bd2f`)下的原始檔,再 grep。**我沒有執行 sd-scripts,所以不是 (A) 級。**

**問題**

承接方逐字宣稱:「fused backward pass」在 sd-scripts 的 LoRA 訓練裡**沒有實作**;旗標會被接受但完全沒有作用;
實作只在全模型微調的 `sdxl_train.py`;`06b` 第七節引用的「24 GB → 10 GB」研判是全模型微調的數字(他們標為**推理,未查證原出處**)。

**裁決**

🔴 **承接方是對的。我方 `06b` 第七節那段 VRAM 敘述錯了,錯的是機制,不是結論數字。** 逐條:

| 承接方的宣稱 | 我方查證結果 |
|---|---|
| LoRA 路徑沒有實作 fused backward pass | ✅ **確認**,而且**比他們說的更強** —— 上游作者明文表示**不打算**在 LoRA 腳本實作(見下方引文) |
| 旗標會被接受 | ✅ **確認**,旗標定義在所有訓練腳本共用的 `add_optimizer_arguments()` 裡 |
| 「完全沒有作用」 | ⚠️ **幾乎對,但有一處要修正**:在 LoRA 路徑上它**有作用,而且是純代價** —— 見下方「這個錯誤原本會讓我們付出什麼」 |
| 「24 GB → 10 GB 是全模型微調的數字」 | ⚠️ **方向確認,但那一組數字我在上游找不到任何出處**。上游與 fused 綁在一起的數字是 **17 GB(fp32、batch 1、全模型微調)** |
| 他們的實測數字自洽嗎 | ✅ **自洽**,而且與原始碼互相印證(兩臂都用 Adafactor —— 那正是原始碼強制的,見下) |

**對承接方三個問題的答覆:**

1. **接受「fused backward」的偏離處理。** 以「bf16 + full_bf16 + gradient checkpointing」取代不存在的
   (a)「fused + bf16 開」組態,是**正確的處置**,不是降級。**偏離登記照收,不要求補做。**
2. **不要求重跑 fp32 組態。** 同意承接方「不必」的建議,但我方的理由與他們的不同,請以我方的為準:
   - 他們的理由是「會撞時間盒且結論不變」。**我方的理由是:那一次是以 `CUDA error: illegal memory access` + Windows 驅動
     `nvlddmkm` 事件 153 中止的,根因未確定。** 重跑一個已知無用、且唯一一次執行就觸發驅動層錯誤的組態,
     是拿那台機器去換一個沒有人要用的數字。
   - 🔴 **但請把那個驅動事件登記為未結案風險。** 它目前只在 fp32 組態出現過;**若它哪天出現在 bf16 正式組態裡,
     判讀就完全不同了**(屆時不是「fp32 不能用」,而是「這台機器的訓練路徑不可靠」)。
     請在往後每次訓練後順手確認有無同類事件,有就立刻回報,不必等我方問。
3. **不要求補做 `sdxl_train.py` 全模型微調的 fused 實測。** 承接方在 `cr001-lora-d2-d3.md` §6 第 6 點提議
   「若委託方要 fused backward pass 的實測:只能做全模型微調……需另行同意範圍」——**我方不同意擴大範圍**。
   全模型微調的產物是 6.9 GB 的整個模型,不是我方要的 LoRA;這個數字對我方沒有任何用途。

**🔴 這個錯誤原本會讓我們付出什麼(這一項承接方沒有算,我方補上)**

`--fused_backward_pass` 在 LoRA 路徑上**不是無害地被忽略**。它會被 `library/optimizer.py` 讀到,並強制兩件事:
**optimizer 必須是 Adafactor**、**gradient accumulation 必須是 1**,否則 `AssertionError` 當場中止。

把承接方自己量的兩列擺在一起就能算出代價(數字全部引自 `cr001-lora-d2-d3.md` §3、§4):

| 組態(皆 bf16 + full_bf16 + gradient checkpointing) | s/step | 整卡 VRAM 峰值 |
|---|---|---|
| **AdamW**(正式組態) | **0.956** | 10,117 MiB |
| Adafactor(`--fused_backward_pass` 強制的那個) | 1.532 | 9,295 MiB |

→ **照 `06b` 第七節字面去設定,會被鎖進 Adafactor:每步慢約 60%,換到的 VRAM 節省來自 Adafactor 本身(約 0.8 GB),
fused 的貢獻是 0。** 以正式組態 1,920 steps 估算,單次訓練從約 31 分變成約 49 分。
**這就是「機制寫錯但結論數字碰巧正確」的實際代價** —— 結論沒救到我們,是承接方的實測救的。

**依據(我實際查了什麼)**

全部可重跑。`REF=690ea7f96c23182352ec63def76d431c6120bd2f`,取檔寫法
`gh api "repos/kohya-ss/sd-scripts/contents/<路徑>?ref=$REF" --jq '.content' | base64 -d`。

1. **LoRA 兩個腳本從頭到尾沒有這個字串**(B′):
   `grep -c fused train_network.py` → **0**;`grep -c fused sdxl_train_network.py` → **0**。
   且 `sdxl_train_network.py` 確實就是 LoRA 入口:`class SdxlNetworkTrainer(train_network.NetworkTrainer)`、
   `parser = train_network.setup_parser()`。
2. **旗標為什麼會被接受**(B′):`library/args.py:159` 在 `add_optimizer_arguments(parser)`(同檔 `:49`)裡宣告它,
   而 `train_network.py:1876` 呼叫 `args_util.add_optimizer_arguments(parser)`。
   旗標的 help 逐字:`"Combines backward pass and optimizer step to reduce VRAM usage. Only available in SDXL, SD3 and FLUX"`
   —— ⚠️ **這句話本身就是這場誤會的溫床**:它說「SDXL 可用」,沒說「只有全模型微調腳本可用」。
3. **它在 LoRA 路徑上實際造成的唯一效果是兩個 assert**(B′),`library/optimizer.py:57-63` 逐字:
   ```python
   if args.fused_backward_pass:
       assert (
           optimizer_type == "Adafactor".lower()
       ), "fused_backward_pass currently only works with optimizer_type Adafactor / ..."
       assert (
           args.gradient_accumulation_steps == 1
       ), "fused_backward_pass does not work with gradient_accumulation_steps > 1 / ..."
   ```
   而 `train_network.py:1174` 正是呼叫 `optimizer_util.get_optimizer(args, trainable_params)` ——
   **所以這兩個 assert 在 LoRA 路徑上是生效的。**
4. **真正的實作只在全模型微調**(B′):`sdxl_train.py:530-545`(`import library.adafactor_fused` →
   `patch_adafactor_fused(optimizer)` → 逐參數 `register_post_accumulate_grad_hook`)。
   全庫 code search `patch_adafactor_fused` 共 9 個檔案命中:`library/adafactor_fused.py`、`sd3_train.py`、`flux_train.py`、
   `sdxl_train.py`、`anima_train.py`、`lumina_train.py`、`train_control_net.py`、`sdxl_train_control_net.py`、
   `flux_train_control_net.py` —— **`train_network.py` 與 `sdxl_train_network.py` 都不在其中。**
5. 🔴 **決定性的一條:上游作者明文說它對 LoRA 無效、而且不打算實作。**(B′)
   路徑是 v0.9.0 release body 只寫一句 `See #1879 for details.`,實際內容在 issue #1879。
   `gh api repos/kohya-ss/sd-scripts/issues/1879 --jq '.body'` 第 57 行逐字:
   > "Mechanism: Normally, backward -> step is performed for each parameter, so all gradients need to be temporarily
   > stored in memory. "Fuse backward and step" reduces memory usage by performing backward/step for each parameter
   > and reflecting the gradient immediately. **The more parameters there are, the greater the effect, so it is not
   > effective in other training scripts (LoRA, etc.) where the memory usage peak is elsewhere, and there are no plans
   > to implement it in those training scripts.**"

   同一則第 53 行:`"Specify the --fused_backward_pass option in sdxl_train.py. At this time, only AdaFactor is supported. Gradient accumulation is not available."`
   ⚠️ **這一條差一點被我漏掉:`v0.9.0` 的 release body 只有 23 bytes,直接 grep `fused` 是零命中。**
   零命中不等於沒有 —— 內容在它指向的 issue 裡。
6. **「24 GB → 10 GB」的出處:我找不到。**(B′,**否證性查證**)
   上游唯一與 fused 綁在一起的 VRAM 數字是 issue #1879 第 55 行:
   > "Training is possible with a memory usage of about **17GB** with a batch size of 1 and fp32. If you specify the
   > `--full_bf16` option, you can further reduce the memory usage (but the accuracy will be lower)."

   而「24GB」在上游出現在**兩個不同脈絡**,兩者都與 fused 無關:
   - `docs/train_SDXL-en.md:48`:`"The fine-tuning can be done with 24GB GPU memory with the batch size of 1"` → **全模型微調**。
   - `docs/train_network_advanced.md:213`:`"SDXL LoRA training requires a lot of VRAM. Even with 24GB VRAM, you might run out of memory depending on settings."` → **LoRA**,但那是「24GB 也可能不夠」的警告,不是「fused 把它壓到 10GB」。

   **結論:「24 GB →(fused + bf16)→ 10 GB」這個配對,我在釘死版本的上游倉庫裡找不到任何出處。**
   承接方「那是全模型微調的數字」的推理**方向正確**(與 fused 綁定的數字確實出自全模型微調脈絡),
   但**那一組數字本身不是上游的**。
7. **上游自己的文件也是錯的 —— 這點必須寫進更正,否則下一個人會再掉進去一次。**(B′)
   `docs/sdxl_train_network.md:207-208`(**這是 LoRA 腳本自己的說明頁**)逐字:
   > `* --fused_backward_pass`
   > `  * Fuses gradient computation and optimizer steps to reduce VRAM usage. Available for SDXL. (Currently only supports the Adafactor optimizer)`

   `docs/train_network_advanced.md:84` 更把它列在 **SDXL LoRA 的省 VRAM 手段**清單裡(標 `**Experimental**`)。
   **程式碼說沒有,作者的發布紀錄說不會做,而 LoRA 自己的文件頁說可以用。**
   ⚠️ 承接方在 `cr001-lora-d2-d3.md` 也獨立發現了同一件事(逐字:「文件 `docs/sdxl_train_network.md:207` 卻把它列在 LoRA 的選項裡 —— 文件與程式碼不一致」)。**兩邊各自查到同一處矛盾。**
8. **承接方的實測與原始碼互相印證**(他們的數字為 (A) 級,但那是**他們的** (A),不是我方的):
   他們 A/B 兩臂**都用 Adafactor**(`cr001-lora-d2-d3.md` §3 逐字:「實測(30 steps,Adafactor,bf16 + full_bf16 + gradient checkpointing,其餘同正式組態)」)。
   🔴 **這不是巧合,而是第 3 點那個 assert 強制的** —— 若他們在「開」那一臂用了 AdamW,行程會當場 `AssertionError` 中止,根本量不到 9,278 MiB。
   **換句話說:他們能量出那兩個數字這件事本身,就是原始碼那兩行 assert 生效的旁證。**
   📌 **另外更正我自己一個差點寫錯的推論**:我原以為承接方「漏看」了 `library/optimizer.py` 那兩個 assert(因為 `06` 回覆正文只說「`sdxl_train_network.py` 不讀它」)。
   實際去讀他們的 `cr001-lora-d2-d3.md` §3,**他們逐行引了 `library/optimizer.py:57-63`**。
   **是 `06` 回覆的摘要省略了,不是他們漏看。** 這一條登記在此,是因為「專家的摘要比他的證據薄」會讓覆核者誤判成疏漏。

**🔴 `06b` 第七節的更正加註(草稿,待核准後貼入 —— 見本節末)**

**我沒把握的部分**

- 🔴 **我沒有執行過 sd-scripts,一行都沒有。** 本節全部 (B′) 級靜態閱讀。
  承接方的 VRAM / s/step 數字我**無法獨立複驗**,只能確認它們與原始碼的行為**互相自洽**。
- **我沒有查 `690ea7f9` 以外的任何版本。** 若承接方日後升級 sd-scripts,本節全部結論需重查。
- **「每次訓練 31 分 → 49 分」是我用他們的 s/step 乘 1,920 steps 外推的**,不是量的。
  (0.956 × 1920 ≈ 1,836 s ≈ 30.6 分;1.532 × 1920 ≈ 2,941 s ≈ 49.0 分。)
  他們實測正式組態是 1,874 s,與 1,836 s 差約 2%,所以這個外推**量級可信、個位數不可信**。
- **上游 issue #1879 是 2025-01-17 的,而釘死的 commit 是 2026-09-24。** 作者「不打算實作」的話是 2025 年說的,
  原始碼在 2026-09-24 這個版本仍然與它一致(我查的就是這個版本),但**我沒有逐版追過中間有沒有反覆**。

---

## 四、第九節第 3 點 —— D6 metadata 粒度

**問題**

承接方目前是「每次訓練一份 metadata,涵蓋該次全部檢查點」;`06b` D6 寫的是「每個 `.safetensors` 一份」。他們可改。

**裁決**

**維持承接方現行做法(每次訓練一份),我方撤回 D6「每個檔一份」的寫法。** 但加一條**必要條件**:

> 🔴 **那一份 run metadata 必須能把該次產出的每一個 `.safetensors` 單獨指認出來** ——
> 至少包含:每個檔的**檔名**、**SHA256**、以及它對應的 **epoch / step**。
> 做不到這一條的話,「一次一份」就不成立,要改回一檔一份。

**理由(可追溯性 vs 檔案數量,兩者我都不是主要考量):**

1. **可追溯性是「映射關係」的性質,不是「檔案數量」的性質。** 只要 run metadata 列得出
   「檔名 → SHA256 → epoch」,從任何一個 `.safetensors` 回推到它的完整訓練設定就是一次查表。
   一檔一份並沒有多買到可追溯性 —— 它只是把同一份設定抄了 N 遍。
2. 🔴 **而「同一份事實抄 N 份」是本專案登記在案的重複失效模式。** 本專案的經驗是:
   **手抄複本必然漂移,而且漂移時兩份都看起來像真的。**(同一個項數在四個檔案出現三個並存的值、
   且被指定為權威來源的那一份自己是錯的 —— 這件事在本專案真的發生過,寫在 `.claude/docs/technical-preferences.md`。)
   一次訓練若保留 8 個 epoch 檢查點,一檔一份就是**同一組訓練設定的 8 份複本**。
   只要有人手動改過其中一份(例如事後補註),就會出現 8 份裡有 1 份不一樣,而且沒有任何東西會發現。
3. **檔案數量不是理由。** 8 個 JSON 檔不構成任何負擔。**我方不是為了省檔案數才選一次一份的。**

**依據(我實際查了什麼)**

- `06b` D6 原文(本機 (A) 級):本檔作者即 `06b` 作者,D6 在 `06b` 第 117 行起的
  「### D6 —— 可重跑的訓練設定檔與執行腳本(需素材才能完成)」節。
  ⚠️ **我這次沒有逐字重讀 D6 全文**,我讀的是承接方在 `06` 第九節的轉述(「06b D6 寫的是『每個 `.safetensors` 一份』」)。
  **若 D6 原文與這句轉述有出入,以 D6 原文為準,本裁決需重做。**
- 「手抄複本必漂移」的專案前例:`.claude/docs/technical-preferences.md` 的
  「Architecture Decisions Log」節 ——(B) 級,專案參考庫明文記載。

**我沒把握的部分**

- **我不知道 sd-scripts 寫進 `.safetensors` 檔頭的 `ss_*` metadata 到底含哪些欄位。**
  我**沒有查**這一項(本可查但時間不足)。若那些內嵌欄位本來就足以單獨還原設定,
  上面那條「必要條件」可能是多餘的 —— **但多寫一份外部映射表的成本極低,我方仍維持要求。**
- 承接方提過 sd-scripts 每次寫入隨機 `ss_session_id`(見 `06` 第九節 L11)。**這暗示檔頭確實有 `ss_*` 欄位,
  但那是我的推測 (C) 級,不足以改變上面那條要求。**

---

## 五、第九節第 1 點與第 4 點 —— 兩條低風險項(各一句)

### 第 1 點:D5「訓練期間停止產圖服務」政策

**裁決:接受,照草案定案,不要求實際同時跑一次來驗證那個相加推理。**

一句話理由(與承接方的理由不同,請以我方的為準):**他們自己 §4 已經量到,這台機器在顯示記憶體不足時
不會乾脆地 OOM,而是靜默溢出到系統記憶體、慢 3.8~63 倍** —— 對一個以**位元重現**(L12)為硬性驗收條件的
產圖服務來說,「安靜地變慢」比「明確地失敗」更難處理,而且要花時間才會發現。
既然工單留在 git 不會遺失、代價只是最多約 31 分鐘延後,**沒有任何理由去冒那個險換一個更精確的數字。**
(「9.8 + 9.4 > 16.3」確實是兩個量測值相加的推理、未實際同時跑 —— 但**推理錯的方向是安全的**:
若它其實跑得動,我方損失的只是吞吐量,不是正確性。)

### 第 4 點:每 epoch 中間檢查點是否保留

**裁決:保留,全部保留,現階段不設清理。**

一句話理由:**L11 已經證明訓練不是位元可重現的**(承接方實測兩次同設定訓練:檔案 SHA 不同、張量也不同、
最終權重相對差 0.34%)—— 所以**一個被刪掉的 epoch 檢查點是永久回不來的**,重訓只會得到「近似」而非「同一個」。
在 C: 還剩 **991.7 GiB**、每次訓練中間檔約 1.6 GiB 的情況下(他們 D1 與第九節的數字),
這個代價換來的空間連千分之二都不到。
**請改用門檻而非逐次清理**:沿用他們 R1 已訂的 **100 GiB 低水位**,撞到才回報並由我方裁決清理對象。

**我沒把握的部分(兩條共通)**

- 這兩條我**完全沒有獨立查證**,全部引自承接方自己的回報(`06` 第四節、第六節、第九節)。
  等級是**他們的 (A)、我方的 (C)**:我沒有複驗過 991.7 GiB、1.6 GiB、31 分、0.34% 任何一個數字。
- 第 4 點「每次訓練中間檔約 1.6 GiB」與他們第九節寫的「每 epoch 檢查點等中間檔目前共 3.20 GiB」
  **我沒有對上**(可能是「每次訓練」與「目前累積兩次訓練」的差別,也可能不是)。**不影響裁決方向**
  —— 即使是 3.2 GiB,相對 991.7 GiB 仍然可忽略。

---

## 附錄:`06b` 第七節更正加註(草稿,**尚未貼入,待核准**)

🔴 **本專案規定:對既有檔案的 Write/Edit 必須先取得核准。`06b` 是既有檔,故本節只備稿,我沒有動它。**

**擬插入位置**:`06b-change-request-lora-requirements-2026-10-08.md` 第七節表格內「VRAM 門檻」那一列**之後**,
**原表格與原文字一個字都不刪、不改**。定位用:

```bash
grep -n "fused backward pass" docs/ai-art-service-handoff/06b-change-request-lora-requirements-2026-10-08.md
```

**擬插入的內容:**

> 🔴 **上列「VRAM 門檻」一列的機制敘述於 2026-10-12 經查證為錯誤,原文保留不刪。**
>
> **錯在哪**:原文寫「『16GB 尚可』的前提是開啟 Kohya SS v0.9.0 的 **fused backward pass + bf16**(把約 24GB 壓到約 10GB)」。
> **`fused backward pass` 在 sd-scripts 的 LoRA 訓練路徑上並不存在** —— 它只實作在全模型微調腳本(`sdxl_train.py` 等),
> 上游作者在 v0.9.0 發布紀錄(issue #1879)明文寫:對 LoRA 等腳本「not effective ... and there are no plans to implement it in those training scripts」。
> 此外,「24 GB → 10 GB」這組配對在上游倉庫**找不到任何出處**;上游與 fused 綁定的數字是 **17 GB(fp32、batch 1、全模型微調)**。
>
> **誰發現的**:**承接方(家用 AI 產圖工作站)於 2026-10-10 實測時發現並主動告知**,不是我方自己查出來的。
> 我方隨後於 2026-10-12 獨立查證上游原始碼(commit `690ea7f9`),確認其正確,並補到作者發布紀錄這一層。
>
> **結論數字反而是對的,機制是錯的** —— 承接方實測正式組態整卡峰值 **10,004 / 16,303 MiB**,與原文「約 10GB」相符。
> 🔴 **但不要因此以為這段話只是「講法不精確」**:真正讓它跑得動的是 **gradient checkpointing + bf16 / full_bf16**;
> 而照原文字面去加上 `--fused_backward_pass`,會被 `library/optimizer.py` 的 assert **強制鎖進 Adafactor optimizer**,
> 每步慢約 60%(承接方實測 0.956 → 1.532 s/step),換到的 fused 效益是 **0**。
>
> **為什麼會錯**:原文已誠實標為 **(C) 級:二手來源推論,未實機驗證** —— 標示沒有錯,**是後續引用時把它當成了既定事實**。
> ⚠️ 另有一個加重因素:**上游自己的 LoRA 文件頁(`docs/sdxl_train_network.md`)至今仍把這個旗標列為 SDXL LoRA 的選項**,
> 與它自己的程式碼和發布紀錄矛盾。**下一個去查這件事的人,只讀那一頁會再錯一次。**
>
> **完整查證過程、逐條原始碼引用與可重跑指令**:`docs/ai-art-service-handoff/06b-technical-clarifications-2026-10-12.md` 第三節。
