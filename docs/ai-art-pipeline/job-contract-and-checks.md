# AI 繪圖遠端工單 — 資料契約與自動檢查

| 欄位 | 內容 |
|---|---|
| 作者 | tools-programmer |
| 依據 | `design/art/ai-art-validation-protocol-2026-09-29.md` 第五節(後製工具規格)、第三節 3.1(機械式檢查) |
| 這份文件管什麼 | 工單長什麼樣、跑完回傳什麼、兩端(公司筆電/家用桌機)怎麼對帳 |
| 這份文件不管什麼 | 後製降採樣+量化怎麼做(第五節)、人工一致性怎麼看(第三節 3.2)、傳輸層要用 REST 還是 git 輪詢(尚未裁決,本契約刻意不綁其中之一) |
| 標註法 | (A) 實機驗證 / (B) 專案文件明文 / (C) 推測未驗證。本文件無法跑 GPU,幾乎全為 (B)/(C),逐條標註 |

## 一、傳輸層中立性(本契約的第一條硬性要求)

(C) 推測未驗證,但為本契約的設計前提:REST 與 git 輪詢兩案目前都在評估,**契約本身
不得預設任一種**。做法:Job / Result 都是**獨立的 JSON 物件 + 隨附二進位檔案(PNG)**,
彼此靠 `job_id` 關聯。傳輸層的唯一義務是**原子送達**——同一個 `job_id` 的 JSON 與其
PNG 必須一起出現,不得讓消費端讀到「json 已到、png 未到」的中間狀態(REST 用單一
multipart 請求或先寫暫存檔再 rename 定案;git 輪詢用單一 commit 裝下兩者)。這是抄
`tools/build/capture_window.ps1` 已定案的紀律(`.claude/docs/coding-standards.md`
「Validate before writing」)套用到跨機傳輸情境。

`job_id` 兼作冪等鍵——同一個工單被同一個傳輸管道重送兩次,消費端必須能判斷「這個我
已經處理過」而不是重複跑一次 GPU。

## 二、工單(Job)格式

(B)+(C) 混合:欄位分類依據第三節 2 的清單與 3.1 的檢查項推導,具體數值為範例。

```json
{
  "schema_version": "1.0",
  "job_id": "char_test01_face_happy_20260930_002",
  "created_by": "felixfu007",
  "created_at": "2026-09-30T09:00:00+08:00",
  "character_id": "char_test01",
  "asset": {
    "category": "face_variant",
    "variant_name": "happy",
    "output_filename": "char_test01_face_happy_128.png"
  },
  "content_spec": {
    "pose": "half-body bust, front-facing",
    "expression": "closed-eye smile, cheerful",
    "orientation": "front",
    "prompt": "...",
    "negative_prompt": "..."
  },
  "generation_params": {
    "base_model": { "name": "SDXL", "checkpoint_file": "sd_xl_base_1.0.safetensors",
                    "version": "1.0", "sha256": "TBD-filled-at-runtime" },
    "lora": { "name": "char_test01_lora", "file": "char_test01_lora_v3.safetensors",
              "version": "v3", "sha256": "TBD-filled-at-runtime",
              "trigger_word": "char_test01style", "weight": 0.8 },
    "sampler_name": "DPM++ 2M Karras", "steps": 30, "cfg_scale": 7.0,
    "clip_skip": 2, "seed": 123456789,
    "native_generation_size": { "width": 1024, "height": 1024 }
  },
  "target_size": { "width": 128, "height": 128 },
  "palette_ref": { "path": null, "version": null,
    "note": "色階庫尚未建立(art-direction.md 第十節),本欄暫為 null——消費端見下方狀態機第 5 節,不得因為 null 就靜默略過離盤色檢查" },
  "retry": {
    "attempt_number": 2,
    "retry_of_job_id": "char_test01_face_happy_20260930_001",
    "previous_failure": { "reason_code": "COLOR_COUNT_OVER_LIMIT",
                           "measured": { "total_color_count": 31, "limit": 24 } },
    "max_attempts": 3
  },
  "status": "queued"
}
```

**欄位說明,只列非自明項**:

| 欄位 | 說明 |
|---|---|
| `base_model.sha256` / `lora.sha256` | (B) 可重現性硬性要求——來源:「本專案已為『不同人跑的是不同版本』付過代價」(`.claude/docs/technical-preferences.md`「Allowed Libraries / Addons」節,原案例是 GdUnit4,同一道理套用到模型檔)。**沒有 hash,壞掉的工單無法重現,好的工單也無法確認下次還能生出同一張圖** |
| `native_generation_size` vs `target_size` | 對應第五節輸入 #1「原生解析度不固定,通常遠大於目標尺寸」與輸入 #2「目標規格」——兩者都要留,後製工具兩者都需要 |
| `palette_ref` 允許 `null` | (B) 色階庫本身尚未建立是專案明文事實(`art-direction.md` 第十節),工單格式必須容許這個依賴還不存在,不能假裝它存在 |
| `retry.previous_failure` | 把上一次 Result 的失敗原因**內嵌**進新工單,讓重跑不必回頭翻上一份 Result 才知道自己在修什麼 |

## 三、回傳(Result)格式

(B)+(C):機械檢查量測值比照第三節 3.1 四項逐一回傳,不得只回一張圖讓公司端重量一次
(否則等於逼公司端重新實作一份量測邏輯,重演 `.claude/docs/technical-preferences.md`
「(A) 的精確定義」記載的「同一規則兩份實作」失效模式)。

```json
{
  "schema_version": "1.0",
  "job_id": "char_test01_face_happy_20260930_002",
  "worker_id": "home-rtx5070ti-01",
  "status": "failed",
  "engine_exit_code": 0,
  "claimed_at": "2026-09-30T09:05:00+08:00",
  "started_at": "2026-09-30T09:05:03+08:00",
  "heartbeat_at": "2026-09-30T09:07:40+08:00",
  "finished_at": "2026-09-30T09:07:41+08:00",
  "outputs": {
    "native_image": { "path": "results/char_test01_face_happy_20260930_002_native.png",
                       "sha256": "..." },
    "final_image":  { "path": "results/char_test01_face_happy_20260930_002_final.png",
                       "sha256": "..." }
  },
  "mechanical_checks": {
    "size_match": { "pass": true, "expected": "128x128", "actual": "128x128" },
    "off_palette_pixel_count": null,
    "off_palette_check_applicable": false,
    "off_palette_check_note": "N/A —— palette_ref 為 null,本項未驗證,不是「0 個離盤色」",
    "total_color_count": 31,
    "outline_samples": [ { "region": "skin_edge", "rgb": "#3a2418" },
                          { "region": "cloth_edge", "rgb": "#241a3a" } ]
  },
  "failure_reason_code": "COLOR_COUNT_OVER_LIMIT",
  "failure_detail": "total_color_count=31 > 建議上限 24(第三節 3.1 第 3 項)",
  "human_signoff": { "decision": null, "reviewer": null, "reviewed_at": null },
  "workflow_state": "awaiting_retry"
}
```

🔴 **`off_palette_check_applicable: false` 是刻意設計的欄位,不是可省略的裝飾。**
理由抄自本專案自己的教訓(`.claude/docs/coding-standards.md`「新判準二:『沒有東西可測』
不得寫成『通過』」)——套色階庫還沒建立時,「沒驗證」與「驗證了、乾淨」若都寫成
`off_palette_pixel_count: 0`,下一個讀證據的人會分不清楚。**本契約把這件事變成兩個
獨立欄位(布林 + 數值),而不是讓一個數值身兼兩種意思。**

## 四、狀態機

`status` 只能是下列五個值之一,**且必須恰好對應派工單指定的五種情況**:

| `status` | 對應情況 | 誰寫入 |
|---|---|---|
| `queued` | ①工單還沒被取走 | 建立工單時的初始值 |
| `running` | ②正在跑 | worker 取走工單那一刻寫入,同時寫 `claimed_at` |
| `passed` | ③跑完且機械檢查合格 | worker 跑完 3.1 全部適用項後寫入 |
| `failed` | ④跑完但機械檢查不合格 | worker 跑完但至少一項不通過 |
| `errored` | ⑤跑掛了(工具崩潰、GPU 記憶體不足、檔案讀寫失敗等) | worker 的例外處理路徑寫入,**必須同時寫 `engine_exit_code` 與可讀的 `failure_detail`** |

⚠️ **`errored` 與 `failed` 不可合併。** 這是抄
`.claude/docs/coding-standards.md` CI 段落的核心教訓——exit 105(解析失敗、零測試執行)
與「跑了、有測試失敗」必須是可區分的兩件事,合併會讓「工具根本沒跑」看起來像
「跑了、只是不合格」。本契約套用同一道理:`errored` 代表「這次嘗試沒有產出可信的
機械檢查結果」,`failed` 代表「機械檢查真的跑完、真的不合格」。

**(C) 殭屍/卡死偵測(推測未驗證,建議採用)**:`heartbeat_at` 由 worker 每次量測步驟
更新;消費端若發現 `status="running"` 但 `heartbeat_at` 超過門檻(建議:單張生成+
後製的合理上限乘以安全係數,例如 30 分鐘,實際數字待第一次真實跑完後回填)未更新,
應視為**第六種診斷狀態 `stalled`**——這不是新增第六個儲存值,而是消費端從
`status + heartbeat_at` 算出來的衍生判斷,寫入時仍是 `running`。**理由**:兩台機器
之間沒有進程監督關係,worker 端斷線或掛死時,`status` 欄位本身不會自動變成
`errored`——沒有這個衍生判斷,一個卡死的工單會永遠顯示「正在跑」。

## 五、自動重跑停損

🔴 **不得無限重跑。** 本節定義的是**機械檢查失敗後的全自動重試迴圈**——與第三節
3.3/第四節「不過關的下一步」的**人工判斷升級階梯**是不同粒度的東西,不能互相取代:
本節的迴圈完全不換模型/不換 LoRA,只調整 seed 等輕量參數,無人判斷介入;第四節的
「換模型」「重新訓練 LoRA」是人的決定,不在本契約的自動化範圍內。

- (C) 建議:`retry.max_attempts` 預設 **3**——不論失敗原因是 `failed` 還是 `errored`,
  都計入同一個 `attempt_number` 計數器。**選單一計數器而非「內容失敗」「基礎設施錯誤」
  分兩個計數器,是本文件為求簡單做的簡化**,不是查證過的最佳值;若後續真實跑出「GPU
  記憶體不足」這類與內容無關的失敗頻繁發生,拆成兩個計數器是合理的下一步修訂。
- 達到 `max_attempts` 後:自動迴圈**停止**,`workflow_state` 寫入
  `stopped_needs_human`,**不得**再自動嘗試(不換 seed、不換模型)。
- 停損時 Result 必須附上**完整嘗試歷史**(`attempt_history: [job_id, status,
  failure_reason_code][]`),讓接手判斷第四節「該走便宜/中等/貴」的人不必自己去翻
  三份散落的 Result 檔案拼歷史。

## 六、機械檢查跑在哪一端

**建議:兩端都跑,家用端跑第一輪、公司端跑覆核輪,公司端的結果才是 `status` 的權威值。**

- **家用端先跑**:省下把明顯不合格的圖傳過公司網路的成本與時間——`native_generation_size`
  通常遠大於 `target_size`,傳輸不是免費的。這一輪的結果只決定要不要在家自動重跑
  (第五節),**不寫入最終 `status`**。
- **公司端覆核**:第五節的檢查邏輯本身很輕(純影像像素運算,不需要 GPU),(C) 兩端都
  能跑;但**只信任單一自我回報,違反本專案自己記載的教訓**——`.claude/docs/
  technical-preferences.md`「(A) 的精確定義」與 `docs/consistency-failures.md` 反覆
  出現的模式是「黑箱比對輸出永遠無法區分『共用同一份』與『兩份碰巧一致』」,套用到這裡
  就是:家用端自己說「合格」不能直接採信為最終判定,必須有公司端獨立重跑同一套檢查邏輯
  （呼叫的是**同一支**第五節工具,不是重新實作一份簡化版)才能定案。
- 兩端結果不一致時(家用端說 pass、公司端說 fail 或反之),**視為 `errored`**,標記
  `failure_reason_code: "CROSS_CHECK_MISMATCH"`——這代表傳輸過程可能損壞了檔案,或兩端
  執行的工具版本不一致,本身就是一個需要人工排查的問題,不能靜默取多數決或取其中一邊。

## 七、明確不做的事 / 人工審圖不可取代

🔴 **本專案至今所有畫面缺陷都是人開圖看到的,自動檢查一次也沒抓到過**
(`.claude/docs/coding-standards.md`,`grep -n "the automated suite has never caught
one"` 可查)。本契約把這一條寫成**明文欄位**,不是道德勸說:

- `human_signoff: { decision: "approved"|"rejected"|null, reviewer, reviewed_at }`
  是 Result 的必要欄位。
- **`status: "passed"` 只代表機械檢查過關,不代表工單完成。** `workflow_state`
  的計算規則:

  | `status` | `human_signoff.decision` | `workflow_state` |
  |---|---|---|
  | `passed` | `null` | `awaiting_human_review` |
  | `passed` | `"approved"` | `done` |
  | `passed` | `"rejected"` | `rejected_needs_rework`（機械過關、人眼判定不行,例如第三節 3.2 的風格漂移) |
  | `failed` | 任意 | `awaiting_retry`(未達上限)或 `stopped_needs_human`(達上限) |
  | `errored` | 任意 | `stopped_needs_human` |

  **沒有任何路徑能讓 `workflow_state` 不經過 `human_signoff.decision == "approved"`
  就變成 `done`。**
- 本契約**不做**:材質區域自動辨識、3.2 節的人工一致性比對、色階庫內容的生成或裁決——
  這三項第五節已明文排除,本文件不重複實作,只在此重申邊界避免有人誤以為工單契約
  應該涵蓋它們。

## 八、未查證/待裁決清單

1. (C) 傳輸層選 REST 還是 git 輪詢——**尚未裁決**,不在本文件職權內,契約已依第一節
   做到兩案都能承載。
2. (C) `heartbeat_at` 卡死門檻的具體分鐘數——目前是猜測值,待第一次真實生成+後製
   跑完後用實測耗時回填。
3. (C) `max_attempts=3` 與「單一計數器」的簡化——未經任何真實失敗案例驗證,見第五節。
4. (B) 色階庫檔案格式與路徑——`palette_ref` 目前只是佔位,待色階庫實際建立後回填
   具體 schema(本文件不越權定義色階庫本身的格式)。
5. (C) 模型/LoRA 檔案的 `sha256` 由誰計算、寫入時機(生成當下由 worker 自己算,還是
   由一支獨立小工具算)——本文件只定義欄位存在,不定義計算流程。
