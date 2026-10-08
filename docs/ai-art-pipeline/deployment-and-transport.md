# AI 繪圖服務:部署與傳輸架構

> **狀態**:2026-09-30 管理者裁決落檔、版本號已更正、方案單一化為乙案(git 輪詢)。
>
> **建議讀者**:工作在「實作 AI 繪圖自動化」的工程師。參考文件見各節引用。

---

## 〇、架構概覽 —— 乙案(git 輪詢)

**前置**:家中 RTX 5070 Ti(Blackwell) Windows 工作站與公司 GitHub 帳號已能通訊。Tailscale 已安裝於家機與個人手機,不在公司筆電上。

**流程**:

1. 公司筆電上的工具生成工單 JSON + PNG 組(見 `job-contract-and-checks.md`),寫入本地目錄
2. 公司筆電執行 `git commit && git push` 到 GitHub (推送工單分支,如 `jobs/pending/`)
3. 家中工作站上定時執行輪詢腳本(見下方【輪詢規則】),拉取新工單
4. 工作站執行生成 → 後製 → 檢查(見 `ai-art-validation-protocol-2026-09-29.md`),產出 Result JSON + PNG
5. 工作站執行 `git commit && git push` (推送結果分支,如 `jobs/completed/` 或 `jobs/failed/`)
6. 公司筆電定時拉取(`git pull`),讀取結果
7. 前端工具解析 Result,標記工單已完成或失敗;若失敗,可選擇調整參數後重試(入佇列數上限見下方【重試上限】)

**為什麼是這個方案?** — 見 `SPEC.md` 第二節。甲案(家裡開 REST 服務)被公司網路/資安政策一票否決(`technical-director` / `security-engineer` 評估);乙案避免新增網路相依,只用既有 GitHub 帳號。

**關鍵保證**:工單與結果的「JSON + PNG」必須原子送達(見 `job-contract-and-checks.md` 第一節)——單一 `git commit` 包含兩者,確保消費端不會讀到斷裂狀態。

---

## 一、家中工作站部署清單(Windows)

### 環境確認(B:管理者自述)

| 項目 | 確定值 |
|---|---|
| **OS** | **Windows** (確認) |
| **24 小時開機** | **幾乎都開著**(確認) |
| **網路** | **沒有固定 IP**;**已裝 Tailscale**(確認) |

**注**:Tailscale 用途見下方【Tailscale 角色說明】;**不在公司筆電上安裝**。

### 步驟 1:NVIDIA 驅動與 CUDA 工具鏈(C:待實機驗證)

```batch
:: RTX 5070 Ti(sm_120) 需 CUDA 12.8+;以下寫 12.8 為最小值
:: 實機驗證尚未進行,故標 (C)

:: 1. 安裝 NVIDIA 驅動(最新穩定版)
::    來源:official NVIDIA,當前 2026-09 > 12.8 支援的最低驅動號 
::    驅動版本號未查證(待實機確認),故此行 (C)

:: 2. 安裝 CUDA Toolkit 12.8+ (建議 12.8 / 12.9 / 最新穩定)
::    下載: https://developer.nvidia.com/cuda-downloads
::    驗證方式: nvcc --version 應報 release 12.8

:: 3. 驗證:
nvidia-smi
::    輸出應包含 CUDA Capability 12.0
```

### 步驟 2:Python 與 PyTorch(C:待實機驗證)

```batch
:: Python 3.11 or 3.12 (SDXL 標準環境)
python --version

:: PyTorch 2.7.0 以上,需明確安裝 cu128 wheel
:: 2.7.0 為第一個原生支援 sm_120 的穩定版;建議用 2.10(2026-01 的穩定線)
:: 切勿用預設 wheel(可能是 CPU 版或舊 CUDA 版)
:: 來源:PyTorch 官方 issue #164342;實測 2.7.0 cu128 wheel 存在

pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
python -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))"
::    預期輸出:True + RTX 5070 Ti
```

🔴 **常見陷阱**(C:參考 `architecture-and-risks.md` §1.4):
- 若 `is_available()` 為 False 且錯誤訊息說「sm_120 is not compatible」,多數情況是**安裝到了舊 CUDA 版 wheel**,不是卡不支援。改用 cu128 wheel。
- 勿自行修改 CUDA 路徑或環境變數以「繞過」版本檢查,會產生靜默失敗。

### 步驟 3:ComfyUI 安裝(C:社群參考,待實機驗證)

```batch
:: 建議採 ComfyUI(見 architecture-and-risks.md §3 評估)
:: Windows 安裝:下載官方預編包或 git clone

:: A. 官方預編(最簡單,推薦新手)
::    見 https://github.com/comfyanonymous/ComfyUI

:: B. 自行打包(進階,便於客製化節點)
cd D:\ai-art-service\
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI
python -m pip install -r requirements.txt

:: 驗證:
python main.py
::    預期在 http://127.0.0.1:8188 (或指定埠)啟動 Web UI
```

### 步驟 4:ComfyUI 模型與工作流版本釘死(B:policy from `job-contract-and-checks.md`

以下檔案進版控,確保可重現性:

| 項目 | 位置 | 版本釘死方式 |
|---|---|---|
| **SDXL base model** | `models/checkpoints/` | SHA256 hash 存檔案頂(見 `job-contract-and-checks.md` 二.1) |
| **角色 LoRA** | `models/loras/` | 同上:檔名 + SHA256 |
| **ComfyUI workflow JSON** | `workflows/` | 整個 JSON commit 進 git |
| **ComfyUI 版本** | `.env` 或 `version_lock.txt` | 記錄安裝日期 + git commit hash |

**理由**(B:from `architecture-and-risks.md` §3):ComfyUI 的 API 是「整個 workflow JSON」,workflow 改一個節點就等於改 API 契約。沒有版本控制,換日期可能拿到不同結果。

### 步驟 5:輪詢腳本(C:架構提案,待實作驗證)

Windows Task Scheduler 或等價服務定期執行(建議 10~30 分鐘):
1. `git fetch origin`
2. 掃描新工單,執行 ComfyUI generation + post-process
3. 若通過檢查:commit result JSON + final_image PNG,push
4. 若失敗:commit failure report + heartbeat,push

**前提變更**(B):原文在「可能沒開機」假設下提議 Wake-on-LAN。因為「幾乎都開著」(確認),WoL 可擱置;輪詢簡化為純粹的定時拉取。

---

## 二、Generation 與 Post-Process

> 🔴 **本節與第三節於 2026-10-08 加註更正。原文一字未刪,但下面四件事已經不對了 ——
> 照原文做會繞過一整套已經在運作、且當天剛通過跨機器驗收的服務。**
>
> **成因(值得記下來,因為它會再發生)**:本檔寫於 2026-09-30,
> AI 產圖服務的規格書寫於 10-05,倉庫實作於 10-06,**三者互不知道對方存在**。
> 2026-10-08 寫需求變更申請書時,本節差一點被當成現況引用。
>
> | # | 原文怎麼寫 | 實際上是什麼 |
> |---|---|---|
> | 1 | 步驟 2/3:`POST /prompt` 到本地 ComfyUI、輪詢 `/history/{prompt_id}` | **繞過整個 AI_IMG 服務。** 正確做法是呼叫服務的 `POST /v1/jobs` —— 服務已處理工單排隊、重啟恢復、參數驗證、冪等保護,繞過它等於再寫一份 |
> | 2 | 步驟 4:降採樣 + 量化 + 加 1px 描邊 | **分工本身仍然成立且已於 2026-10-08 正式委託**(見 `docs/ai-art-service-handoff/06-change-request-001-2026-10-08.md`),但當時沒有任何人在做 —— 送交承接方的委託規格書把它明文排除在範圍外 |
> | 3 | 第三節「色盤驗證:顏色數 ≤ 64」 | **已由 `art-director` 2026-10-08 裁定改為「零離盤色像素」** —— 更嚴格也更誠實,不會被「顏色數剛好卡在門檻內、但其中幾個是量化沒乾淨的殘留色」誤導 |
> | 4 | 第三節「描邊驗證:**1px 黑線**完整無缺」 | 🔴 **與 `design/art/art-direction.md` 第四節直接相反** —— 該節是「描邊**非純黑**,依材質微調色相」。已裁定採美術方向那版。**照原文實作檢查工具,會把每一張正確的圖判成不合格** |
>
> **權威來源改為** `docs/ai-art-service-handoff/06-change-request-001-2026-10-08.md`
> 與其兩份附件(`06a` 美術側 / `06b` 技術側)。本節原文保留為決策紀錄。
>
> ⚠️ **未一併處理、誠實登記**:第三節的「Result JSON 含四項檢查結果」與
> 「心跳檔」兩項,**與雙方目前實際在用的工單契約不符**(現行 `result.json` 沒有任何
> 檢查結果欄位,也沒有心跳檔)。CR-001 第五節第 4 項已把 `result.json` 的契約修訂
> 登記為待辦;**心跳檔則是連登記都還沒有的第三種狀態**,下一個動這塊的人要自己決定
> 它還算不算數。

### ComfyUI 生成與後製(C:規範來源見 `job-contract-and-checks.md` + `ai-art-validation-protocol-2026-09-29.md` §5)

實作流程:
1. 讀工單 JSON,根據 `generation_params` 構建 ComfyUI workflow JSON(見步驟四:版本釘死)
2. POST `/prompt` 到本地 ComfyUI server(http://127.0.0.1:8188),回 `prompt_id`
3. 輪詢 `/history/{prompt_id}` 等候完成,讀出 native PNG(通常 1024×1024)
4. 降採樣 + 量化至 64 色 + 加 1px 描邊(見 `art-direction.md`),產出 final image
5. 回傳 Result JSON(見下方【Result JSON 與回傳】)

細節(演算法、工具選型、resampling 方式)見驗證協議第五節及 `art-direction.md`;實裝者決定。

---

## 三、檢查與結果回報

### 機械檢查(B:規範 from `ai-art-validation-protocol-2026-09-29.md` §3.1)

家中工作站必須對每張圖進行:

1. **尺寸驗證**:最終圖應為 `job.target_size`
2. **色盤驗證**:顏色數 ≤ 64(或適用上限)
3. **描邊驗證**:1px 黑線完整無缺
4. **格線對齊**:像素網格整數倍(細節見 `coding-standards.md` Check 4)

各項失敗時,不推送,改寫失敗報告(見下方),並允許重試(見【重試上限】)。

### Result JSON 與回傳(B:規範 from `job-contract-and-checks.md` §三)

包含:`job_id`、`status`(passed/failed)、四項檢查結果(dimension/palette/border/grid_alignment)、final_image PNG 路徑與 SHA256、失敗原因碼。

每個 Result 與其 final_image PNG 必須同時 commit(原子性,見第〇節)。

### 心跳檔與狀態回報(C:架構提案)

**解決乙案的「安靜壞掉」問題**(見 `SPEC.md` §二)。家中工作站每次輪詢都寫:

```
results/worker_heartbeat_20260930_120000.json
{
  "worker_id": "home-rtx5070ti-01",
  "last_poll_at": "2026-09-30T12:00:00+08:00",
  "status": "idle|processing|error",
  "error": null | "DISK_FULL" | "GPU_OOM" | "CONNECTION_FAILED" | ...
}
```

定時推送此檔案。失敗報告同樣推送(含詳細錯誤訊息)。

**為什麼需要?** —— 公司端看到「沒有新圖」時,心跳檔讓它判斷是「機器沒開」還是「沒有新工單」還是「無聲掛機」。心跳檔不取代人工監控;只是讓自動化能判斷是否該告警。

---

## 四、公司筆電工具流程

### 公司端流程(C:架構,待 tools-programmer 實作)

**工單生成**:美術工具生成提示詞 + 參數(見 `job-contract-and-checks.md` 二),本地 `jobs/pending/[job_id].json` + `_preview.png`,commit & push。

**結果消費**:定時 `git pull origin`。掃描 `jobs/completed/` 和 `jobs/failed/`:
- 若檢查全過(dimension/palette/border/grid),移至 `review/` 待人工簽核(見 `SPEC.md` 〇)
- 若檢查未過:判斷是否自動重試(見下方【重試上限】),否則通知失敗,建議檢查心跳檔和家機狀態

---

## 五、重試上限與自動恢復(B:政策 from `job-contract-and-checks.md`)

| 項目 | 規則 |
|---|---|
| **重試上限** | **3 次**(含初次) |
| **自動重試** | ✅ 支援(家中工作站自動判斷) |
| **人工介入** | 第 3 次失敗後,必須由人工審查失敗原因,調整參數後重新提交 |

工單中自動跟蹤 `retry.attempt_number` 與 `retry.previous_failure`,見 `job-contract-and-checks.md` 二.60-66。

---

## 六、Tailscale 角色說明(B:管理者自述 2026-09-30)

### ✅ Tailscale 用途:家機遠端管理

- **安裝位置**:家中 RTX 5070 Ti Windows 工作站 ✅ 已裝
- **安裝位置**:管理者個人手機 ✅ 已裝
- **目的**:管理者用手機遠端查看家機狀態(服務活著沒、看失敗報告、必要時重啟)
- **完全不碰**:公司筆電 —— 不在公司筆電上裝 Tailscale

### ❌ Tailscale 不是什麼

- **不是**:在公司筆電上裝 Tailscale,遠連家機服務 —— 那正是主管說「盡量不要」的事(見 SPEC.md §二,資安政策問題)
- **不是**:取代心跳檔的自動監控 —— 手機是「人去查」,心跳檔是「自動化能讀」,兩者互補

### 與本架構的整合

Tailscale 不屬於工單/結果的傳輸層(那是 GitHub);它只是**運維窗口**,讓管理者有辦法在自己手機上看到家機是不是卡住。

---

## 七、環境管理與監控(C:架構框架,細節待實作)

| 工具/檔案 | 用途 | 位置 |
|---|---|---|
| **ComfyUI 日誌** | 單次生成的詳細診斷 | 工作站本地,需要時讀取 |
| **heartbeat.json** | 輪詢狀態與無聲故障偵測 | `results/worker_heartbeat_*.json` |
| **failure report** | 上次失敗的原因碼與量測值 | `jobs/failed/*.json` |
| **.env 或 config.toml** | 模型路徑、ComfyUI 埠、輪詢間隔等 | 工作站版控(與 code 同層) |

---

## 八、已知限制與擱置項(C:架構層級)

**不阻擋:**

- [ ] 後製工具的具體演算法(見二.【post-process】):Pillow vs ImageMagick vs 自寫 CUDA —— 由 tools-programmer 決定
- [ ] ComfyUI workflow JSON 的精確格式:由 tools-programmer 測試後版控
- [ ] 輪詢間隔的精確值(10 vs 20 vs 30 分鐘):由實裝者測試調整,上限需與 GitHub API rate limit 相容

**擱置(甲案與 Linux 方案):**

見附錄【已擱置的架構方案】。

---

## 附錄:已擱置的方案

🔴 **甲案(REST 直連)** — 2026-09-30 擱置。🔴 **不是禁令** —— 管理者主管表示「盡量不要」,非「禁止」。核心:家機開 ComfyUI REST 服務(`--listen 0.0.0.0`),公司筆電主動 POST 工單。擱置理由:無固定 IP,且管理者主管對「在公司筆電主動連自家自架服務」表示「盡量不要」(`technical-director`/`security-engineer` 評估,兩位都表示「不判定」因只有管理者問得到)。若政策變,甲乙都用同一份 JSON 格式,切換成本不高。

🔴 **Linux/macOS 方案** — 環境確認為 Windows,暫未考慮。主要差異:驅動(apt/yum 替代 MSI)、排程(cron/systemd 替代 Task Scheduler),core 邏輯不變。

---

**檔案版本**:1.0(2026-09-30,乙案單一化版本)  
**證據等級**:
- (A) 實機驗證:無(待實作)
- (B) 專案文件明文:環境確認(管理者自述,2026-09-30)、工單/結果格式(from `job-contract-and-checks.md`)、驗證規範(from `ai-art-validation-protocol-2026-09-29.md`)
- (C) 推測未驗證:CUDA/PyTorch 版本(from `architecture-and-risks.md`,有查證來源)、輪詢邏輯、ComfyUI 細節
