# Cheyenne 探針圖工單 — 2026-10-19

> 承接 `design/art/art-tone-direction.md`(2026-10-19 上午)。目的:依管理者同日三項裁決,
> 產出 4 張可直接貼進家用端工單的完整 prompt。

## 零、今日三項裁決(寫上午那份文件時還不知道)

| 題目 | 裁決 |
|---|---|
| 立繪去背 | **要去背,維持 10/16 裁決**(推翻上游 `character-generation-prompts-2026-10-12.md` 1.4
  節「不要求去背」的假設——該檔既有檔,須先問才能改,本檔只在 P1/P2 的背景套用新裁決) |
| 底模 | **裝 _CHEYENNE_**(https://civitai.com/models/198051),先產探針圖 |
| 立繪 master 尺寸 | **1024×1024 原生輸出** |

**底模事實**(`docs/reviews/base-model-feasibility-v2-2026-10-19.md` 2.1/2.2 節):SDXL 1.0
單檔 `.safetensors`,6616 MB。立繪用 `v2.0`(`CHEYENNE_v20.safetensors`,馬特繪/精緻線稿向),
棋子用 `CH.01 [ALT] Clean Lineart`(作者自述 `flat colors ... more cartoony`)。血統自述
「more representative of the Franco-Belgian comic strip style than of manga」——對應判準 2
(離開動漫血統)。建議取樣 `DPM++ 2M`(已在白名單)、CFG 1–5,🔴 作者原話「extremely sensitive
to the nature of the sampler, steps and CFG」——下方 4 張的參數因此在建議區間內跨值,不固定。

## 一、底模與授權硬性規則

🔴 **派工單寫「依 `design/art/ai-image-licensing-audit-2026-09-29.md` 第 5.3 節」,查證後該檔
沒有 5.3 節**(全檔章節一~八,中間為 3.1~3.6/4.1~4.3 小節,無「五之三」——當場查:
`grep -n "^#" design/art/ai-image-licensing-audit-2026-09-29.md`)。**正確出處是
`docs/ai-art-service-handoff/04-security-and-licensing.md` 第 5.3 節**(`base-model-feasibility-v2`
第二節「立繪-C」候選的第 2 點風險引用的也是這份)。本節依正確出處重寫,不轉述錯誤那份。

> **硬性規則**(`04-security-and-licensing.md` 5.3 節,引 EFF 2023 立場):風格本身不受著作權
> 保護,但若 prompt 刻意意圖重製「某一張具體存在、可辨識的原作品」,責任可能落在下指令的人
> 身上。**實務建議:避免指名在世的特定畫師/工作室/角色/作品名稱,改用中性媒材/年代/光影/
> 構圖描述詞。** Cheyenne 模型頁逐字列出「Hergé, Spirou, Franquin, Uderzo, Gibrat, Moebius」
> 等漫畫家姓名作為血統自述——**這些名字只出現在模型頁,下方 4 張 prompt 全文一個都不包含**,
> 也不含任何作品/角色名稱。違反不會被引擎擋下,**全靠人工覆核**,下方每張都已自查。

## 二、現行 prompt 起點與本次判斷:要不要保留 danbooru 標籤開頭

🔴 **先澄清一個查證落差**:派工單說「現行那組是 danbooru 標籤式開頭」,對不上
`character-generation-prompts-2026-10-12.md`(1.2/1.4/1.5 節)——**那份是自然語言描述句,
沒有 `masterpiece, best quality, 1girl, solo` 這種開頭。** 標籤開頭的實際出處是
`docs/ai-art-service-handoff/13-animagine-tag-prompts-2026-10-13.md`——家用端為配合
**當時已裝的 `animagine-xl-3.1`**(動漫 booru-tag 訓練模型)把 10-12 號自然語言句**改寫**成
標籤式,甲的範例:`masterpiece, best quality, very aesthetic, absurdres, safe, 1girl, solo,
adult woman, east asian, black hair, ponytail, serious expression, ...`。**兩份文件都現行
有效,派工單把兩者混成一份**——查證不符,照更正後的理解往下判。

**判斷:不保留 danbooru 標籤開頭,改回自然語言描述句。理由三點:**

1. danbooru 標籤是配合 animagine 這個 booru-tag 訓練模型的格式選擇,不是通用慣例。Cheyenne
   「300 次合併,偏歐漫/馬特繪」,不是 booru-tag 資料集訓練出來的——沒有證據它認得
   `1girl, solo, absurdres` 這套 token。通才 SDXL 合併模型(Juggernaut、DreamShaper、
   RealVisXL,`base-model-feasibility-v2` 2.1 節列的其他候選)慣例用自然語言,這也是
   10-12 號文件原始格式的理由。
2. 🔴 `absurdres`、`masterpiece`、`1girl/solo` 本身帶 anime/booru 社群印記,即使是品質詞,
   仍可能把生成拉向它最常見的訓練情境(動漫圖站)。**判準 2(離開動漫血統)是本輪核心訴求**,
   保留這套開頭等於一邊要求離開動漫、一邊餵動漫社群最典型的提示語彙,方向互相抵銷。
3. 本檔第三節已是自然語言寫法,10-12 號文件本身也是——改回自然語言是銜接既有兩份文件
   最省工的路徑,不必再維護第三套格式。

⚠️ **這是判斷,不是已驗證結論**——Cheyenne 對自然語言 vs 標籤式的服從度沒人測過,若探針圖
顯示身份特徵掉得比預期多,下一批該測標籤式,不代表本判斷錯了,只代表需要第二個資料點。

## 三、4 張探針圖完整工單

**共通說明(P1/P2,2026-10-19 經協調者核對更正)**:立繪去背走的是 **AI 去背(BiRefNet)**,
不是色鍵——`docs/ai-art-service-handoff/22-postprocess-0.3-0.4-and-ai-matting-2026-10-17.md`
第二節實測 7/7 張非純色背景全部完整切出。**故背景維持 `art-tone-direction.md` 第一節要求的
陰暗朦朧氣氛背景,不改洋紅**(本檔初稿曾改洋紅,已推翻,理由見第五節)。
⚠️ **該份實測同時列了兩項瑕疵**(髮緣背景色溢色、小塊背景殘留),縮到 32×40 都看不出來,
但**「128×128 以上的尺寸還沒有測,尺寸越大瑕疵越明顯」——立繪是 1024×1024,屬於未測範圍**,
第一批出圖後請連同這一項一併檢視。

### P1 — 立繪 · seed 5001(CFG 偏低)

模型:`CHEYENNE_v20.safetensors` | 尺寸:1024×1024 | Steps:30 | CFG:**3** | Sampler:`DPM++ 2M`
| Scheduler:`normal`(服務固定值,無 Karras) | Seed:**5001**

```
prompt: semi-realistic illustration, painterly matte painting style, soft rendered
shading, clear facial structure, bust shot, head and shoulders portrait, slight
three-quarter angle facing camera, East Asian features, contemporary Taiwan
setting, single character, centered composition, dim low-key lighting from a
single hard-edged source, deep dramatic shadow coverage, desaturated cool and
sickly color palette, sharp focus, clean linework, young adult Taiwanese woman,
athletic build, dark hair tied back in a tight ponytail, sharp determined but
weary expression, guarded posture, navy-blue tactical forced-entry firefighter
uniform, gear harness with D-ring buckles, fingerless tactical gloves worn pale
at the knuckles, subtle grime and scuff marks on uniform fabric, sturdy worn
boots, cool desaturated navy-blue uniform tones with dull steel-gray metal
fittings, expressive weary eyes, visible facial and hair detail, dim hazy
oppressive backdrop, soft out-of-focus darkness, background secondary to the
character and not the focal point, portrait framing, square 1:1 composition
```
```
negative_prompt: flat cel-shading, bold black outline, three-tone cel shading,
anime style, anime shading, manga style, cheerful smile, bright even studio
lighting, vivid saturated cheerful colors, pastel colors, chibi proportions,
pristine spotless clothing, glossy anime shine, sparkle, cute, photorealistic
skin pore macro detail, 3d render, photograph, film grain, noise, chromatic
aberration, lens blur, depth of field, motion blur, text, watermark, signature,
logo, extra limbs, extra fingers, fused fingers, deformed hands, malformed
anatomy, extra heads, mutated, multiple characters, crowd, duplicate, full body,
standing pose, hands prominent in frame, cluttered background, busy patterned
backdrop, multiple background objects, nsfw
```
⚠️ **negative 刻意不含 `soft airbrush gradient`/`heavy smudge shading`**(原在 `[COMMON-NEG]`
1.3 節)——半寫實要的正是柔和漸層,照搬會自我矛盾,P3/P4(棋子)仍保留這兩詞。

### P2 — 立繪 · seed 5002(CFG 偏高,貼近作者建議上限)

模型:`CHEYENNE_v20.safetensors` | 尺寸:1024×1024 | Steps:30 | CFG:**5** | Sampler:`DPM++ 2M`
| Scheduler:`normal` | Seed:**5002**

prompt 與 negative_prompt **逐字同 P1**(只有 seed 與 CFG 不同)——刻意固定其餘變因,
讓兩張圖的差異只能來自 CFG,才能回答「服從度隨 CFG 怎麼變」這個問題(見第四節)。

### P3 — 棋子 · seed 6001(CFG 偏低)

模型:`CH.01 [ALT] Clean Lineart`(🔴 檔名與檔案大小未查證,見第五節;請家用端自行在模型頁
版本列表找到實際檔案) | 尺寸:**896×1152**(4:5,與第四輪一致,最終降採樣到 32×40) |
Steps:30 | CFG:**2** | Sampler:`DPM++ 2M` | Scheduler:`normal` | Seed:**6001**

```
prompt: 2D game character concept art, flat cel-shaded illustration, clean precise
lineart, bold clean outline on the character's outer silhouette only, minimal to
no outlining on internal clothing seams or details, rely on flat color-block
contrast for internal shape separation, limited flat color palette, three-tone
cel shading with clear shadow/base/highlight breaks, no soft airbrush gradient,
strong clear silhouette, East Asian features, contemporary Taiwan setting,
single character, centered composition, dim low-key lighting, hard shadow break,
sharp focus, clean linework, full body, standing idle pose, front-facing with a
slight three-quarter turn, arms visible, feet visible, orthographic framing with
minimal perspective distortion, isolated single character, solid flat magenta
background (#FF00FF), no scenery, no shadow cast on background, no gradient
background, generous empty padding around the character within frame, young
adult Taiwanese woman, athletic build, dark hair tied back in a tight ponytail,
sharp determined but weary expression, guarded posture, navy-blue tactical
forced-entry firefighter uniform, gear harness with D-ring buckles, fingerless
tactical gloves worn pale at the knuckles, subtle grime and scuff marks on
uniform fabric, sturdy worn boots, holding a firefighter breaching axe resting
on one shoulder, desaturated cool navy-blue uniform tones, dull steel-gray metal
fittings, worn silver axe head, desaturated muted color selection, visible minor
wear on clothing and equipment without breaking silhouette clarity
```
```
negative_prompt: photorealistic, 3d render, photograph, realistic skin pore
detail, hyperdetailed skin texture, film grain, noise, chromatic aberration,
lens blur, depth of field, motion blur, soft airbrush gradient, heavy smudge
shading, text, watermark, signature, logo, extra limbs, extra fingers, fused
fingers, deformed hands, malformed anatomy, extra heads, mutated, multiple
characters, crowd, duplicate, nsfw, cropped body, cut off limbs, partial figure,
close-up, bust shot, complex background, scenery, multiple objects in
background, vignette, drop shadow on background, gradient background, patterned
background, cheerful smile, bright colors, vivid saturation, chibi, pastel,
glossy anime shine, sparkle, cute, pristine clean, anime style, anime shading,
manga style
```
⚠️ **P3/P4 的 negative 與 P1/P2 不同,保留 `soft airbrush gradient` / `heavy smudge shading`**——
棋子仍要求扁平三階,與 P1/P2 的理由相反方向,不要混用同一份 negative。

### P4 — 棋子 · seed 6002(CFG 偏高)

模型:`CH.01 [ALT] Clean Lineart`(同 P3,檔名未查證) | 尺寸:896×1152 | Steps:30 | CFG:**4**
| Sampler:`DPM++ 2M` | Scheduler:`normal` | Seed:**6002**

prompt 與 negative_prompt **逐字同 P3**(只有 seed 與 CFG 不同),理由同 P1/P2——固定其餘變因,
只讓 CFG 變化,才能回答「扁平判準隨 CFG 怎麼變」。

## 四、這 4 張要回答什麼

對照 `art-tone-direction.md` 第一節那張表(光源/彩度色溫/表情姿態/服裝磨損/背景環境/戰鬥克制):

- **P1(CFG 3)**:作者建議區間下限,`v2.0` 繪製質感是否達半寫實(柔和漸層、臉部結構清楚,
  對照判準 1),光源/彩度是否可見「離開動漫」(判準 2、表中「光源」「彩度與色溫」兩列,
  與既有 animagine 版的甲做視覺對照)。
- **P2(CFG 5)**:拉高 CFG 後身份特徵服從度是否提升(制服、斧頭、D 環扣是否更精確),是否出現
  作者警告的「extremely sensitive」副作用——**直接回答第二節「拿掉標籤開頭」有沒有讓服從度掉太多**。
- **P3(CFG 2)**:`CH.01 [ALT]` 低 CFG 下扁平 cel-shade 判準(三階硬邊、少漸層)是否成立
  (判準 1),降採樣模擬到 32×40 後剪影是否可辨識(「服裝/道具磨損」細節縮小後會不會糊成一團)。
- **P4(CFG 4)**:拉高 CFG 後陰鬱色彩與磨損細節是否保留而不破壞剪影清晰度,negative 裡的
  動漫排除詞在這個血統上是否看得出效果。

**總問題**:Cheyenne 能不能同時服務「立繪半寫實 + 棋子扁平」兩個相反方向的判準 1
(`base-model-feasibility-v2` 稱它技術上「唯一兩者都能服務」的候選,但那不是美術驗證——
這 4 張就是補驗證)。

## 五、本檔不涵蓋 / 未驗證

- 🔴 **Cheyenne 的實際輸出我沒看過**——以上全部依模型頁自述(`base-model-feasibility-v2`)與既有
  規格(`art-tone-direction.md`、`character-generation-prompts-2026-10-12.md`)推導,不是從實測
  結果校正出來的,與 10-12 號文件開頭的自我定位一致。**第二節「拿掉 danbooru 開頭」同理是
  判斷不是驗證**——若 P2/P4 服從度掉太多,下一批該測「補回標籤式」,不是放棄 Cheyenne。
- **`CH.01 [ALT]` 確切檔名與檔案大小未查證**(civitai API 只回傳前 3 個版本,`base-model-
  feasibility-v2` 2.2 節已標記)。**civitai 旗標字面法律定義、上游 RAIL++-M 是否仍拘束這個
  300 次合併的衍生物,同樣未查證**——該檔 2.0 節「共通風險一、二」,本檔沿用非新發現。
- 🔴 **已核對並推翻,改回氣氛背景**(原文保留作決策紀錄,非仍待確認項):初稿曾把 P1/P2
  立繪背景改洋紅純色,理由「模糊漸層背景沒有乾淨色鍵可取」——**只對色鍵去背成立**。管理者今日
  選的是 **AI 去背(BiRefNet)**,`22-postprocess-0.3-0.4-and-ai-matting-2026-10-17.md` 第二節
  實測非純色背景 7/7 完整切出,**非純色正是它被選上的原因**,洋紅反而因溢色瑕疵在大尺寸下
  風險更高。已改回 `art-tone-direction.md` 第一節要求的陰暗朦朧氣氛背景(見第三節 P1)。
- **不涵蓋** 1024×1024 以外的版面測試、對話框合成效果(`ux-designer`/`technical-artist` 範圍);
  **sampler/scheduler 固定 `dpmpp_2m`/`normal`**,未要求放寬白名單,4 張全在白名單內完成。
