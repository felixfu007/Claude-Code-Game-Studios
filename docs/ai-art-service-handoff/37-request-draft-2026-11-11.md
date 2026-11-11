# 37 號:音樂第二批——勝利 stinger 重做 + 第 4 首戰鬥循環曲(2026-11-11,草稿)

- **狀態**:🔴 **草稿。推送到家用端之前必須經管理者核准。** 我(audio-director)不自行推送,也沒有碰 `C:/Users/User/Documents/AI_IMG`。
- **撰寫**:audio-director,2026-11-11。
- **號碼**:已查,`docs/ai-art-service-handoff/` 與 `AI_IMG/docs/team/handoff/` 兩邊都沒有 37 號;兩邊都沒有 36 號(36 號依指示留給地形圖塊,本檔不占用)。公司端現有最大號是 35。
- **依據**:管理者 2026-11-10 夜間在家試聽 12 首候選後的裁決(第一節,逐字)、家用端上一批交件 `AI_IMG/docs/team/deliveries/2026-11-07-music-candidates/README.md`(下稱「上批 README」)、`33a-owner-decisions-2026-11-06.md`、`docs/reviews/music-licensing-and-listening-2026-11-10.md`。
- **工單**:無。與 33、34 號相同,不走工單,直接交付資料夾 + README。
- **需要回報告**:是(第七節)。
- **標記**:【原文】= 我今天親自讀檔、逐字引用;【推論】= 我的推理;**未驗證** = 我沒有親自查證。我不能聽音檔,本檔不對任何曲子的好壞下判斷。

## 一、管理者裁決(逐字,經派工訊息轉述——「轉述」這件事本身標:未驗證,我沒有讀到原始裁決紀錄)

| # | 裁決 | 對本單的效果 |
|---|---|---|
| 1 | 「戰鬥BGM可以三四首隨機撥放」→ 選「現有 3 首 + 再產 1 首」 | 現有 `mus_battle_main_loop_c01/c02/c03` **全部採用**;本單再產第 4 首的候選 |
| 2 | 「戰敗音樂用mus_stinger_defeat_01_c03」 | 敗北 stinger 已定案,**本單不再產** |
| 3 | 「戰勝音樂都不滿意,要再華麗一點」 | 現有 `mus_stinger_victory_01_c01~c03` **全部不採用**;本單重做勝利 stinger |
| 4 | 「標題音樂可以用mus_title_main_loop_c02」 | 標題曲已定案,**本單不再產** |

**已定案、不要動**:標題 c02、戰敗 c03、戰鬥 c01~c03。家用端不需要為它們重產或重做後製。

## 二、勝利 stinger 重做

### 2-1 被否決的 3 首,prompt 原文【原文,取自上批 README 3-3 節】

共用參數:8 步、CFG 1.0、lcm/simple、denoise 1.0、負向提示詞空字串、要求 5.5 秒 → 實得 5.573 秒、最後 0.5 秒淡出。

| 檔名 | prompt 原文 | seed | 成品 LUFS / 真峰值 |
|---|---|---|---|
| `mus_stinger_victory_01_c01` | Short victory stinger, solemn hopeful brass and string chord swell resolving to a major chord, dark fantasy, ends with a soft ringing tail, instrumental | 20261107301 | -16.0 / -3.2 |
| `mus_stinger_victory_01_c02` | Brief restrained orchestral fanfare with French horns and strings rising to a warm major resolution then fading out, dark fantasy game, instrumental | 20261107302 | -15.9 / -5.0 |
| `mus_stinger_victory_01_c03` | Short uplifting piano and harp arpeggio over a soft string pad resolving on a bright major chord, quiet relief after a battle, gentle fade, instrumental | 20261107303 | -15.9 / -3.9 |

### 2-2 為什麼聽起來不夠華麗(【推論】,未驗證;我只讀了 prompt 與量測,沒聽過音檔)

1. **三個 prompt 的形容詞都往收斂走**:`Short` / `Brief`、`solemn` / `restrained` / `quiet relief`、`soft ringing tail` / `gentle fade` / `soft string pad`。模型照字面理解的話,動態會被壓小。
2. **沒有任何一個要求「高潮」的元素**:沒有定音鼓滾奏、沒有鈸、沒有高音域的小號 / 鐘琴 / 豎琴滑奏、沒有「全體樂團」。c03 甚至只有鋼琴 + 豎琴 + 弦樂墊底。
3. **都帶 `dark fantasy`**(c01、c02)——風格標籤把整體往暗處拉。
4. **三首長度同為 5.573 秒**,還要扣掉尾端 0.5 秒淡出,中間能鋪陳「起、承、高潮、收」的時間很少。【推論】要華麗,時間是其中一個條件。
5. **c03 響度前**:原始 -19.7 LUFS,需要 +3.7 dB 增益才到 -16;c01 原始 -13.3(要 -2.7 dB)。數字只說明動態本來就不高,不能直接證明「不夠華麗」。

### 2-3 「再華麗一點」翻成具體音樂需求

| 項目 | 舊版(被否決) | 新版需求 |
|---|---|---|
| 配器 | 銅管 + 弦樂墊 / 鋼琴 + 豎琴 | **全體管弦樂**:小號 + 法國號主奏旋律、定音鼓滾奏、鈸、弦樂快速跑句、豎琴滑奏、鐘琴 / 鋼片琴點綴 |
| 音域 | 中低音域為主(推論) | **主旋律上行到高音域**(小號 / 弦樂高把位),再配豎琴 / 鐘琴的高頻閃光 |
| 動態 | 柔、克制、gentle | **明確的 crescendo → 全奏高潮**:定音鼓 + 鈸 + 全體在最後和弦同時落下(**這是戰勝收尾的一次性重音,不是戰鬥循環曲裡的突發重音,不衝突**) |
| 調性 | 大調但「solemn」 | **明亮大調**,上行旋律、完全終止(解決到主和弦),不要小調色彩 |
| 長度 | 5.573 秒 | **請求 8.0 秒**(三首)+ **5.5 秒對照組**(一首),見 2-5 |
| 結尾 | soft ringing tail / gentle fade | **保留自然的殘響尾巴**(大廳殘響延續),不要突然切、也不要刻意「輕輕淡掉」;後製 0.5 秒保險淡出照舊 |
| 風格標籤 | dark fantasy | 去掉 `dark`,改 `heroic` / `triumphant` / `cinematic`。【推論】遊戲整體調性偏哀悼,但管理者明說要華麗;勝利可以亮,與敗北 stinger 的對比反而更清楚 |

### 2-4 新版 prompt(候選 4 個)

編號接續舊的,從 c04 起,**避免和被否決的 c01~c03 撞名**。seed 沿用上批「日期 8 碼 + 類別 + 序號」的寫法(上批勝利是 20261107301),新批日期為 20261111。**負向提示詞留空**(CFG = 1 時無作用,上批 README 2-2 節;該結論本身標【推理】)。

| 檔名 | prompt 全文(給家用端原樣使用) | seed | 要求長度 |
|---|---|---|---|
| `mus_stinger_victory_01_c04` | Triumphant heroic orchestral victory fanfare, bright trumpets and French horns playing a rising melodic phrase over rolling timpani, full string section, harp glissando and a cymbal crash on the final chord, full orchestra in a major key, a grand sustained final chord with a long ringing reverb tail, instrumental, no vocals | 20261111304 | 8.0 秒 |
| `mus_stinger_victory_01_c05` | Majestic cinematic victory stinger, soaring brass fanfare with a bold ascending trumpet theme, rapid string runs, glockenspiel and bell sparkle, timpani and bass drum hit into a big major final chord, shimmering cymbal swell decaying naturally, epic and celebratory, instrumental, no vocals | 20261111305 | 8.0 秒 |
| `mus_stinger_victory_01_c06` | Glorious fantasy adventure victory music, full orchestra, brass chorale answered by harp arpeggios and celesta sparkles, rising to a grand major climax with a timpani roll, final chord held and resonating in a large concert hall, triumphant and bright, instrumental, no vocals | 20261111306 | 8.0 秒 |
| `mus_stinger_victory_01_c07`(對照組) | Triumphant orchestral fanfare, bold trumpets and horns, timpani roll, cymbal crash, harp glissando rising into a bright major final chord with a ringing tail, instrumental, no vocals | 20261111307 | 5.5 秒 |

- c04~c06:同一方向(華麗全奏)的三種寫法,c04 偏小號旋律、c05 偏上行主題 + 打擊重音、c06 偏銅管聖詠 + 鋼片琴。
- **c07 為什麼存在**:若管理者聽完覺得 8 秒太長,c07 是 5.5 秒版本,仍在原規格(3~6 秒)內。它也能回答「變華麗是因為 prompt 還是因為變長」。【推論】
- 請求 5 個也可以(加 1 個 8 秒候選),由家用端依顯存 / 時間決定;上批每個候選執行 2.4~3.6 秒【原文,上批 README 第七節】,成本很低。**我建議 4 個即可**,理由:管理者要的是方向對,不是多;多了反而又要聽 5 首。

### 2-5 規格變動:stinger 長度上限(🔴 需管理者明示同意)

- 原規格(33 號,上批 README 引用):勝 / 敗 stinger **3~6 秒**【原文,33 號第三部分,我 grep 到:「3~6 秒,**非循環**,尾端自然收束」】。
- 本單 c04~c06 請求 8.0 秒,**超出原規格**。這是要請管理者在核准本草稿時一併同意的規格變動,否則請把 c04~c06 改成 5.5 秒(prompt 不變)。
- **對遊戲端的影響:未驗證。** 我沒有讀戰鬥結算畫面的設計文件,不知道 8 秒是否會卡到結算 UI 的節奏或與敗北 stinger(5.573 秒)不對稱。這需要 `game-designer` / UI 端判斷,**不是我能定的**。

### 2-6 後製與響度(沿用上批,不新發明)

- 轉檔:FLAC → OGG,`ffmpeg -c:a libvorbis -q:a 6 -fflags +bitexact -flags:a +bitexact`、44.1 kHz、立體聲【原文,上批 README 5-1】。
- 響度:**只用單一靜態增益**,目標 -16 LUFS / ≤ -1 dBTP;編碼後若真峰值 > -1 dBTP 就把增益降到剛好 ≤ -1;不用壓縮器 / 限幅器【原文,上批 README 5-2】。【推論】全奏 + 鈸的真峰值可能比舊版高,到不了 -16 的機率比舊版大;到不了就如實回報,**不要自行加限幅器**(限幅器是否要加,管理者在 11-10 試聽單的附加題上決定,我未見到他的答案)。
- 收尾:開頭 5 ms 淡入、最後 0.5 秒淡出(`afade=t=in:st=0:d=0.005,afade=t=out:st=<長度-0.5>:d=0.5`);8 秒版的淡出起點請依實際長度算,不要沿用 5.0728 【原文,上批 5-3 節給的是 5.573 秒版的起點】。
- 另請量測並回報:**最後 100 ms 的 RMS**(上批舊版是 -60.4~-62.5 dBFS)與最後一個樣本值,確認尾巴是自然收束。

## 三、第 4 首戰鬥循環曲

### 3-1 現有 3 首的定位(讓第 4 首有區別)【原文,上批 README 3-2】

| 檔名 | BPM 要求 | 音色族 |
|---|---|---|
| c01 | 100 | 合成低音脈衝 + 悶響通鼓 + 滴答打擊 + 暗色弦樂墊 |
| c02 | 96 | 低音弦樂撥奏 + 太鼓 + 低音銅管墊(暗色極簡管弦) |
| c03 | 108 | 類比低音琶音 + 軟底鼓 + 刷鈸 + 詭異持續音(電子) |

三首涵蓋「合成 / 管弦 / 電子」。**第 4 首的空檔**:**原聲室內樂 / 鋼琴驅動**,BPM 取 92(低於現有最低的 96),讓 4 首隨機輪播時速度和音色都有落差,但仍是同一個「冷靜、壓迫、可預測節奏、無突發重音」的家族。【推論】

### 3-2 候選 3 個

規格沿用:BPM 90~110、無人聲、冷靜壓迫、無突發重音、要求長度 **120 秒**(官方上限,上批 README 第〇節第 3 項)、剪成 90~110 秒的循環。

| 檔名 | prompt 全文 | seed | 要求長度 |
|---|---|---|---|
| `mus_battle_main_loop_c04` | Calm tense tactical strategy game music with a low felt piano ostinato, bowed double bass, soft frame drum pulse and a sustained cello drone, cold and patient, steady groove, consistent rhythm, no sudden hits, instrumental, no vocals, 92 BPM | 20261111204 | 120 秒 |
| `mus_battle_main_loop_c05` | Brooding dark chamber ensemble underscore with muted plucked harp, low clarinet and bass flute drones, soft hand percussion and shaker pulse, steady restrained rhythm, patient pressure like a slow chess endgame, no sudden hits, instrumental, no vocals, 104 BPM | 20261111205 | 120 秒 |
| `mus_battle_main_loop_c06` | (與 c04 完全相同的 prompt) | 20261111206 | 120 秒 |

- c06 是 c04 換 seed,用途是看「同 prompt 不同 seed」的差異;**只要 c04 或 c06 其中一個可用就夠**。若家用端覺得多餘,可以只交 c04、c05,請在 README 說明。
- prompt 句型沿用上批的結構(場景 + 樂器 + 氣質 + `no sudden hits` + `instrumental, no vocals` + BPM)。這個寫法有沒有讓模型守住 BPM,上批只對戰鬥曲三首做了粗估(落在 ±0.5 BPM 或其一半)【原文,上批 README 第〇節第 4 項;該估計方法本身標【推理】】。

### 3-3 循環後製(沿用上批 4-1 節的做法,參數表照填)

- 找循環起點 S:2~12 秒、每 0.25 秒試一次;循環長度 L:90~110 秒、每 10 ms 試一次;L 再以 50 ms 波形相關細調到取樣點;開頭 X = 2 秒做等功率交叉淡化;**不拼接不同次產出、不重複貼短段**【原文,上批 4-1 節與戰鬥曲 X 值】。
- 請交與上批同格式的接縫證據(樣本跳動、250 ms 音量跳動、內部百分位、波形圖)。
- 🔴 **上批已知兩個問題,請這批主動檢查並回報,不要等我問**:
  1. 戰鬥曲原始輸出有滿格樣本(c01 360、c02 224、c03 9)【原文,上批第〇節第 7 項】。這批請回報 c04~c06 的滿格樣本數。**是否改用 `AudioAdjustVolume` 在 VAE 解碼後先降音量**,上批只說「本批沒有用」;這個做法是否有效、會不會影響同 seed 重現,**我未驗證**。是否採用請家用端提出方案由管理者決定,**不要自行改動 workflow 後悄悄交件**。
  2. 循環點若剛好落在音頭上(上批標題 c01 的情形),請在 README 標出。
- 節拍有沒有對齊:上批沒有對齊拍點(4-4 節)。同樣,**這批也不要求**;但 4 首隨機輪播時,「換曲接縫」是另一件事(見第六節)。

## 四、格式、命名、響度(一律沿用上批)

| 項目 | 規格 | 出處 |
|---|---|---|
| 格式 | Vorbis `.ogg`、44.1 kHz、立體聲 | 上批 5-1 |
| 響度 | 目標 -16 LUFS、真峰值 ≤ -1 dBTP,單一靜態增益 | 上批 5-2 |
| 命名 | `[類別]_[情境]_[名稱]_[變體].ogg`;候選帶 `_cNN` 後綴(本批 c04 起,與已有 c01~c03 不撞名),正式檔名由遊戲端另定 | 專案命名規範、上批第六節 |
| 保留 | `candidates/prenorm/*.ogg`、`evidence/` 全套(ffprobe、loudness、waveforms、gen_log、summary.csv)、`scripts/jobs_*.json` | 上批第一節 |
| 原始 FLAC | 只留家用端本機,不進 git | 上批附註 |
| 重現性 | 全部候選同 seed 重跑一次,回報 SHA256 是否相同 | 上批 Q8 |
| 交付資料夾 | 建議 `docs/team/deliveries/2026-11-11-music-round2/`(名稱由家用端定,**未驗證**該路徑未被占用) | |

## 五、授權註記(只記錄,不阻擋本單)

- **管理者已知情選擇**:「音樂直接放進公開 GitHub 倉庫,並附授權標示」。此句為派工訊息轉述,**未驗證**(我沒有讀到原始裁決紀錄)。
- **Stability 商用註冊:尚未完成**(派工訊息所述,**未驗證**;我 11-10 的文件寫的是「未做」,之後我沒有看到更新)。
- 其餘三件事的查證現況,以 `docs/reviews/music-licensing-and-listening-2026-11-10.md` 第一節為準,本單**不複述**:註冊入口 / Affiliate 定義 / 署名義務是否適用於「只放輸出音檔」的遊戲,在那份文件裡都標為【未查到】,我今天沒有重查。
- 【推論,未驗證】音檔放進**公開**倉庫,等於對第三方散布,11-10 文件 F3(授權副本、Notice 版權句、顯眼處「Powered by Stability AI」)的字面讀法下更可能適用。這會影響倉庫的 README / 授權檔該寫什麼,**但不影響本單怎麼產音檔**。
- **本單處置**:家用端照常產出;交件 README 請照上批第八節的寫法,逐項寫「未處理」,不要寫成「已解決」。把音檔放進倉庫、以及 Credits / 授權標示的措辭,是管理者與遊戲端後續的決定,不在本單。

## 六、不在本單範圍、但請管理者知道的事

1. **4 首戰鬥曲隨機輪播是遊戲端功能**:story-004 目前的描述是「戰鬥 1 首」(11-10 文件 3-1 節,我沒有重讀 story 檔本身)。換成多首隨機輪播,會影響 `music_tracks.txt` 格式、「不連續重複同一首」的規則、換曲時是否淡入淡出。這些**需要 game-designer / 程式端決定,我未決定也未驗證現況**。
2. **隨機輪播的換曲接縫**:每首都是單獨循環後製的,曲與曲之間的銜接(淡出 / 淡入多久)是播放端行為,與本單的產出無關。
3. **勝利 stinger 若為 8 秒**:見 2-5。
4. **Godot 讀 OGG 循環行為**仍未測(上批十之 7),維持 `godot-specialist` 待辦,不在本單。

## 七、請家用端回報的內容

1. 每個候選:prompt 全文(原樣)、seed、實得長度、原始 → 成品 LUFS / 真峰值、成品 SHA256、同 seed 重跑是否逐位元相同。
2. 勝利 stinger:最後 100 ms RMS、最後一個樣本值;實際 8 秒版的淡出起點。
3. 戰鬥曲:S / L / X / 包絡相關 / 兩窗音量差、接縫證據、滿格樣本數、BPM 粗估(照上批方法,標【推理】)。
4. 與上批不同之處(若有)——例如 ComfyUI commit、模型檔 SHA256 是否與上批一致。
5. **不判斷好不好聽,不寫「通過」**,與上批相同。試聽由管理者在家做。

## 八、本檔未驗證事項清單(逐字)

1. 管理者四項裁決的原話——**未驗證**(派工訊息轉述)。
2. 「Stability 商業登記尚未完成」「管理者選擇放進公開 GitHub」——**未驗證**(派工訊息轉述)。
3. 新版 prompt 是否真的比舊版更華麗——**未驗證**,我不能聽音檔,也沒有跑過模型。第 2-2 節的所有原因都是【推論】。
4. Stable Audio 3 Small Music 對 `triumphant`、`timpani roll`、`cymbal crash` 之類詞的反應——**未驗證**。
5. 8 秒 stinger 對遊戲節奏的影響——**未驗證**。
6. 92 / 104 BPM 在 prompt 裡能否被模型遵守——**未驗證**(上批只對 96/100/108 做過粗估)。
7. 33 號規格全文——我只用 grep 讀到 stinger 一段(「3~6 秒」),其餘規格是引用上批 README 與 33a,**未重讀 33 號全文**。
8. `docs/team/deliveries/2026-11-11-music-round2/` 是否已存在——**未驗證**。
9. story-004 現況——**未重讀**,沿用 11-10 文件。
