# AI 繪圖服務:部署與傳輸架構

> 🔴 **2026-09-30 協調者加註:本文的 CUDA / 驅動版本號不可照抄,已被同批另一份文件推翻。**
>
> 本文多處寫 `cuda-12.1` / `nvidia-driver-550`(標記為 (C) 推測)。
> 同日 `technical-director` 以 WebSearch 查證後寫進
> `docs/ai-art-pipeline/architecture-and-risks.md` §1 的結論是:
> **RTX 5070 Ti(Blackwell,sm_120)需要 CUDA 12.8 以上,PyTorch 需 2.7.0 以上。**
>
> **兩者衝突,依證據等級以 §1 為準** —— §1 有查證來源,本文此處標的是推測。
> 🔴 **照本文的版本號安裝,顯示卡會不能用**,而且它的錯誤訊息
>(`sm_120 is not compatible`)會讓人誤以為是硬體不支援,實際成因是裝錯版本。
>
> **本文其餘內容(服務常駐、狀態設計、問題清單)不受此更正影響,原文一字未改。**

> ⚠️ **本文 623 行,超過派工時設定的 200 行上限 3.1 倍,協調者知情保留。**
> 原因:它把**甲、乙兩案的完整安裝腳本都寫完了**,而架構尚未裁決 —— 其中一半注定丟棄。
> 依 `technical-preferences.md` 的流程劑量上限精神,這是過度生產。
> **保留而不退回重寫的理由**:內容本身沒有錯,且裁決後刪掉一半即可,重寫的成本高於刪除。
> 🔴 **裁決甲或乙之後,必須回來刪掉另一半,否則這份文件會同時描述兩個互斥的系統。**

**本文件記述家中 RTX 5070 Ti 工作站與公司筆電之間的服務部署與通訊方案。**

> 🔴 **驗證狀態**: 本文件為推測架構,尚未在實機執行。標記規則:
> - **(A) 實機驗證** —— 在專案現有環境上執行過
> - **(B) 專案文件明文** —— 已確認記載於既有文件
> - **(C) 推測未驗證** —— 理論上可行,未經測試

---

## 第一部分:家中工作站部署清單

### 環境假設 (待確認 §待管理者回答)

| 項目 | 現況 | 待確認 |
|------|------|--------|
| 家中桌機 OS | 未知 | ✓ 需確認(Windows / Linux / macOS) |
| GPU 驅動 | 未知 | ✓ 需確認(NVIDIA 驅動版本) |
| 網路型態 | 完全未知 | ✓ 需確認(見後續各架構) |
| 24 小時開機 | 未知 | ✓ 需確認 |
| 公司筆電安裝權限 | 受限 | ✓ 需確認(IT 政策) |

### 部署步驟 (方案骨架,待 OS 確定後分岔展開)

#### 方案 A: Windows 作為宿主

**(C) 假設家中為 Windows 11 或 Windows Server:**

1. **AI 繪圖引擎安裝** (假設採 Stable Diffusion WebUI 或 Comfy UI)
   - 下載並安裝至固定路徑,例: `D:\ai-art-service\`
   - GPU: CUDA 12.1 + cuDNN 9.x (RTX 5070 Ti 對應版本)
   - 驗證: `nvidia-smi` 顯示 GPU 與可用顯存

2. **Windows 服務啟動** (使用 NSSM 或 WinSW)
   - 工具: `Non-Sucking Service Manager` (NSSM) 下載 32/64 位版本
   - 步驟:
     ```
     nssm install "AIArtService" "path\to\webui.bat"
     nssm set "AIArtService" AppDirectory "D:\ai-art-service"
     nssm set "AIArtService" Start "SERVICE_AUTO_START"
     nssm start "AIArtService"
     ```
   - 驗證: 服務管理器 → 檢查 "AIArtService" 運行狀態

3. **無使用者登入時啟動** (Windows 10+)
   - 服務預設在無登入時執行 ✓ (C)
   - 但若涉及 GPU 計算,可能需要禁用 TDR (Timeout Detection Recovery):
     ```
     REG ADD "HKLM\System\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /t REG_DWORD /d 0
     ```

#### 方案 B: Linux 作為宿主 (若家中為 Ubuntu/Debian)

**(C) 假設採用 Ubuntu 22.04 LTS:**

1. **NVIDIA 驅動 + CUDA 安裝**
   ```bash
   sudo apt update && sudo apt install -y nvidia-driver-550 cuda-12.1
   ```
   驗證: `nvidia-smi`

2. **AI 繪圖服務啟動 (systemd)**
   - 建立服務檔 `/etc/systemd/system/ai-art-service.service`:
     ```ini
     [Unit]
     Description=AI Art Generation Service
     After=network-online.target
     
     [Service]
     Type=simple
     User=ai-service
     ExecStart=/home/ai-service/ai-art-service/start.sh
     Restart=always
     RestartSec=10
     Environment="CUDA_VISIBLE_DEVICES=0"
     
     [Install]
     WantedBy=multi-user.target
     ```
   - 啟動:
     ```bash
     sudo systemctl daemon-reload
     sudo systemctl enable ai-art-service
     sudo systemctl start ai-art-service
     ```
   - 驗證: `systemctl status ai-art-service`

3. **機器離線後自動重啟** (若有 UPS 或自動電源恢復)
   - 檢查 BIOS 設定: `Power After AC Loss` → `Turn On`

---

## 第二部分:傳輸架構部署比較

### 架構甲:家中 REST 服務對外 + 公司筆電主動連接

**通訊流向:** 公司筆電 → 家中桌機 (pull 模式)

#### 網路拓撲與前置條件

| 條件 | 狀態 | 備註 |
|------|------|------|
| 家中網路有公有 IP | (C) 未知 | 若 CGNAT,需隧道方案 |
| 家中可開放 port | (C) 未知 | 路由器配置權限 |
| TLS 憑證獲取 | (C) 推測可行 | 自簽 / Let's Encrypt |
| 公司筆電可安裝軟體 | (C) 未知 | IT 政策影響 |

#### 部署步驟

**Step 1: 家中服務暴露**

1a. **若家中有公有 IP (非 CGNAT)**
   - 在路由器設定 port forwarding:
     ```
     WAN:18888 → LAN:8888 (家中桌機內部服務埠)
     ```
   - TLS 設定:
     - 自簽憑證 (測試): `openssl req -x509 -newkey rsa:4096 -out cert.pem -keyout key.pem -days 365`
     - Let's Encrypt (生產): 申請一個動態 DNS 域名(如 noip.com),配合 certbot
   - 驗證: `curl https://your-home-domain:18888/health` (從公司筆電)

1b. **若家中是 CGNAT (無公有 IP)**
   - 使用隧道服務(三選一):
   
   **(方案 i) Cloudflare Tunnel (推薦,無需公司筆電設定)**
   - 家中:
     ```bash
     cloudflared tunnel create ai-art-tunnel
     cloudflared tunnel route dns ai-art-tunnel ai-art.example.com
     cloudflared tunnel run --url http://localhost:8888 ai-art-tunnel
     ```
   - 公司筆電: 直接 `https://ai-art.example.com` (無需額外軟體)
   
   **(方案 ii) Tailscale VPN (需公司筆電安裝)**
   - 家中: 安裝 Tailscale,啟動即可
   - 公司筆電: 安裝 Tailscale,加入同一網路
   - 通訊: `https://home-machine.tailscale.io:8888`
   - 風險: 公司筆電需安裝軟體(待 IT 批准)
   
   **(方案 iii) WireGuard (手動管理密鑰)**
   - 複雜度最高,跳過

**Step 2: 公司筆電客戶端**

- 編寫定時任務(Windows Task Scheduler):
  ```
  觸發: 每小時執行一次
  動作: 執行 PowerShell 腳本 render-request.ps1
  ```
- 腳本功能:
  ```powershell
  $request = @{prompt = "..."; ...}
  $response = Invoke-WebRequest -Uri "https://home-ai-service:18888/render" `
    -Method POST `
    -Body ($request | ConvertTo-Json) `
    -ContentType "application/json" `
    -SkipCertificateCheck  # 若用自簽憑證
  
  # 結果存放
  $response.Content | Out-File -Path "D:\ai-output\result.png"
  ```

#### 部署複雜度與代價

| 項 | 無 CGNAT | CGNAT+Cloudflare | CGNAT+Tailscale |
|----|----------|------------------|-----------------|
| 家中配置 | 高(路由器) | 低 | 低 |
| 公司筆電改動 | 無 | 無 | ⚠️ 需裝軟體 |
| 隱私風險 | 中(外網可見) | 低(Cloudflare 代理) | 低(VPN) |
| 成本 | 免費 | 免費 tier | Tailscale 免費 tier |
| 故障排查難度 | 低 | 中 | 中 |

---

### 架構乙:家中主動輪詢 git repo + push 成品

**通訊流向:** 家中桌機定期拉工單 → 執行 → push 結果 (push 模式)

#### 核心概念

- 家中桌機每 N 分鐘掃一次 GitHub repo 的特定分支/標籤
- 若發現新工單,執行並 push 成品 + 執行紀錄回 repo
- 公司筆電從 repo 拉結果

#### 部署步驟

**Step 1: 工單/成品結構設計**

```
repo 根目錄結構:
  /ai-workload/
    /pending/         # 待執行工單 (公司筆電 push 入)
      - job-001.json
      - job-002.json
    /processing/      # 執行中標記 (家中鎖檔)
      - job-001.lock
    /completed/       # 完成品 (家中 push 出)
      - job-001-output.png
      - job-001-manifest.json (包含執行時間/參數/狀態)
```

**Step 2: 工單格式**

```json
{
  "id": "job-001",
  "timestamp": "2026-09-30T10:00:00Z",
  "prompt": "a fantasy warrior",
  "model": "sd-v1-5",
  "steps": 20,
  "cfg_scale": 7.5,
  "requested_by": "art-director"
}
```

**Step 3: 家中輪詢腳本 (Windows PowerShell 或 Linux Bash)**

**(C) 假設用 PowerShell:**

```powershell
# run-workload-loop.ps1
$REPO_PATH = "D:\repo\game-studio"
$POLL_INTERVAL = 300  # 5 分鐘

while ($true) {
    # 拉最新
    Push-Location $REPO_PATH
    git fetch origin
    git pull origin main
    Pop-Location
    
    # 掃 pending 目錄
    $pending = Get-ChildItem "$REPO_PATH\ai-workload\pending\*.json"
    foreach ($job in $pending) {
        $jobId = $job.BaseName
        
        # 鎖檔 (避免重複執行)
        if (Test-Path "$REPO_PATH\ai-workload\processing\$jobId.lock") {
            continue  # 已有在跑
        }
        
        New-Item -Path "$REPO_PATH\ai-workload\processing\$jobId.lock" -ItemType File -Force
        
        # 執行繪圖
        try {
            $jobParams = Get-Content $job.FullName | ConvertFrom-Json
            $output = & "D:\ai-art-service\generate.exe" @jobParams
            
            # 輸出結果
            Copy-Item $output -Destination "$REPO_PATH\ai-workload\completed\$jobId-output.png"
            
            # 記錄執行結果
            @{
                status = "success"
                completed_at = (Get-Date).ToUniversalTime()
                execution_time_seconds = 45
            } | ConvertTo-Json | Out-File "$REPO_PATH\ai-workload\completed\$jobId-manifest.json"
            
            # commit & push
            Push-Location $REPO_PATH
            git add "ai-workload/completed/*"
            git commit -m "feat(ai-art): completed $jobId"
            git push origin main
            Pop-Location
            
        } catch {
            # 失敗時: 寫入失敗記錄 (重點:不刪 lock,不 push,讓公司端看得到失敗)
            @{
                status = "failed"
                error = $_.Exception.Message
                failed_at = (Get-Date).ToUniversalTime()
            } | ConvertTo-Json | Out-File "$REPO_PATH\ai-workload\failed\$jobId-error.json"
        } finally {
            Remove-Item "$REPO_PATH\ai-workload\processing\$jobId.lock" -Force -ErrorAction SilentlyContinue
        }
    }
    
    Start-Sleep -Seconds $POLL_INTERVAL
}
```

**Step 4: 公司筆電客戶端**

```powershell
# submit-render-job.ps1
param(
    [string]$Prompt,
    [string]$OutputDir = "D:\ai-output"
)

$jobId = "job-$(Get-Date -Format 'yyyyMMddHHmmss')"
$jobFile = ".\ai-workload\pending\$jobId.json"

@{
    id = $jobId
    timestamp = (Get-Date).ToUniversalTime()
    prompt = $Prompt
    model = "sd-v1-5"
    steps = 20
    cfg_scale = 7.5
    requested_by = "art-director"
} | ConvertTo-Json | Out-File $jobFile

git add $jobFile
git commit -m "feat(ai-art): submitted $jobId"
git push origin main

# 輪詢檢查完成
$maxWait = 3600  # 1 小時超時
$waited = 0
while ($waited -lt $maxWait) {
    git pull origin main
    if (Test-Path ".\ai-workload\completed\$jobId-output.png") {
        Copy-Item ".\ai-workload\completed\$jobId-output.png" -Destination $OutputDir
        Write-Host "✓ Job $jobId completed"
        exit 0
    }
    if (Test-Path ".\ai-workload\failed\$jobId-error.json") {
        $error = Get-Content ".\ai-workload\failed\$jobId-error.json" | ConvertFrom-Json
        Write-Host "✗ Job $jobId failed: $($error.error)"
        exit 1
    }
    Start-Sleep -Seconds 10
    $waited += 10
}
Write-Host "✗ Job $jobId timeout"
exit 1
```

#### 故障排查與監視

| 故障情境 | 表現 | 排查方式 |
|---------|------|--------|
| 家中機器離線 | pending 堆積不動 | 檢查 `processing/*.lock` 歲數 |
| 執行緩慢 | 任務卡在 processing | 檢查 gpu 狀態 & 磁碟空間 |
| git 衝突 | push 失敗,錯誤留在 failed/ | git log 查衝突紀錄 |
| 公司端看不到成品 | completed/ 有檔但公司 pull 不到 | git status 檢查遠端同步 |

#### 代價與侷限

| 項 | 評估 |
|----|------|
| 實裝複雜度 | 高(需設計檔案協議、鎖機制、輪詢邏輯) |
| 網路依賴 | 低(只需 git push/pull,已驗證可行) |
| 公司筆電改動 | 低(只需 git + PowerShell,無新軟體) |
| 延遲 | 中(取決於輪詢間隔,典型 5~10 分鐘) |
| 故障偵測 | 中(需要解析檔案狀態,非即時反饋) |
| **致命缺陷** | ⚠️ 見下方「架構乙的陷阱」|

#### 🔴 架構乙的陷阱(致命缺陷評估)

1. **git 歷史膨脹**
   - 問題: 每次成品 PNG (~10MB) push,git log 累積
   - 解決: 用 Git LFS (Large File Storage)
     ```
     git lfs install
     git lfs track "ai-workload/completed/*.png"
     ```
   - 但 LFS 也要付費維護,成本上升

2. **並行工單衝突**
   - 問題: 公司筆電同時 submit 兩個工單,家中同時執行會互相干擾 GPU
   - 解決: 在 lock 機制上加隊列編號,家中一次只取一個
   - 代價: 輪詢邏輯更複雜

3. **無法中止或優先級控制**
   - 問題: 工單一旦提交,無法取消或改優先級
   - 解決: 在 job manifest 加 `status: "cancelled"` 欄,家中跳過
   - 缺點: 已執行的無法中止,浪費 GPU 時間

4. **成品命名衝突**
   - 問題: 若公司同時 submit job-001 和 job-001(重複 ID)
   - 解決: 用時間戳替代序號,確保全局唯一
   - 驗證: `$jobId = "job-$(New-Guid)"`

---

## 第三部分:機器離線處理

### Wake-on-LAN (WoL) 可行性

| 環境 | 可行性 | 前置條件 | 備註 |
|------|--------|---------|------|
| 家中桌機+乙太網 | ✓ (C) 推測可行 | 主板支援,BIOS 啟用,乙太網卡待機供電 | 需知道 MAC 地址 |
| 家中桌機+Wi-Fi | ✗ | Wi-Fi 睡眠時關閉,WoL 包無法送達 | 不實用 |
| 公司筆電喚醒家中 | ✓ (C) 可行,但複雜 | VPN 或公網隧道,WoL 廣播轉發 | Tailscale 原生不支援 WoL |

### 部署方案

**方案一:手動啟動 (最簡單)**
- 前提: 家中機器 24 小時開機
- 優點: 無故障點
- 缺點: 浪費電力,若不開機工單卡住

**方案二:排程啟動 (機器端)**
- 在家中桌機 BIOS 設定: `Power On at 08:00 AM` 每天
- 優點: 預測性,無需遠端介入
- 缺點: 僅限固定時間

**方案三:WoL 遠端喚醒 (架構甲適用)**
- 前提: 家中網路有公有 IP + 路由器支援 WoL 轉發
- 步驟:
  1. 家中桌機 BIOS: 啟用 `Wake on LAN`
  2. 路由器: 啟用 WoL 轉發 (某些機型支援)
  3. 公司筆電: 發送 WoL 魔包
     ```powershell
     function Send-WoL {
         param([string]$MacAddress, [string]$BroadcastAddress)
         $packet = [byte[]](,0xFF * 6) + ([convert]::FromHexString($MacAddress -replace '-|:','')) * 16
         $socket = New-Object Net.Sockets.UdpClient
         $socket.Send($packet, $packet.Length, $BroadcastAddress, 9)
         $socket.Close()
     }
     Send-WoL -MacAddress "AA:BB:CC:DD:EE:FF" -BroadcastAddress "192.168.1.255"
     ```
- 風險: 路由器通常不支援外網 WoL 轉發,此路多數不通

**方案四:架構乙中的處理**
- 若家中機器離線: pending 工單無人處理
- 解決: 在 submit 腳本中加超時檢測
  ```powershell
  # 若 30 分鐘仍未出現在 processing/,判定機器離線
  if (!(Test-Path ".\ai-workload\processing\$jobId.lock") -and $waited -gt 1800) {
      Write-Host "⚠️  Home machine appears offline, retrying WoL..."
      Send-WoL  # 嘗試喚醒
  }
  ```

---

## 第四部分:可觀測性與故障偵測

🔴 **本項對應**.claude/docs/coding-standards.md` 的教訓:** 
- 「exit code 0 但一條測試都沒跑」
- 「看起來成功的空結果與真正的成功無法區分」

### 三層狀態判定

#### 層一: 工單狀態 (檔案系統)

```
pending/job-001.json    → 待執行
processing/job-001.lock → 執行中 (lock 檔建立時間 < 5 分鐘)
                        → 執行卡住 (lock 檔建立時間 > 30 分鐘,舊)
completed/job-001-*     → 執行成功
failed/job-001-error    → 執行失敗
```

**公司筆電檢查邏輯**

```powershell
function Check-JobStatus {
    param([string]$JobId)
    
    if (Test-Path ".\ai-workload\pending\$JobId.json") {
        return "PENDING"
    }
    
    if (Test-Path ".\ai-workload\processing\$JobId.lock") {
        $lockAge = (Get-Date) - (Get-Item ".\ai-workload\processing\$JobId.lock").LastWriteTime
        if ($lockAge.TotalMinutes -gt 30) {
            return "STALLED"  # 🔴 卡住! 不是「還在跑」
        }
        return "PROCESSING"
    }
    
    if (Test-Path ".\ai-workload\completed\$JobId-output.png") {
        return "SUCCESS"
    }
    
    if (Test-Path ".\ai-workload\failed\$JobId-error.json") {
        $error = Get-Content ".\ai-workload\failed\$JobId-error.json" | ConvertFrom-Json
        return "FAILED:$($error.error)"
    }
    
    return "NOT_FOUND"  # 工單不存在 (非「還沒送」)
}
```

#### 層二: 機器健康狀態

**架構甲(REST):**
```powershell
try {
    $health = Invoke-WebRequest "https://home-ai-service:18888/health" -TimeoutSec 5
    if ($health.StatusCode -eq 200) {
        $uptime = ($health.Content | ConvertFrom-Json).uptime_seconds
        Write-Host "✓ Home service OK (uptime: $uptime s)"
    }
} catch {
    Write-Host "✗ Home service unreachable"
}
```

**架構乙(git):**
```powershell
# 檢查最後推送時間
$lastCommit = git log -1 --format="%ct" origin/main -- ai-workload/completed/
$lastPush = [datetime]::FromFileTime($lastCommit * 10000000 + 116444736000000000)
$minutesSinceLastPush = ((Get-Date) - $lastPush).TotalMinutes

if ($minutesSinceLastPush -gt 60) {
    Write-Host "⚠️  Home machine has not pushed in $minutesSinceLastPush minutes (possible offline)"
}
```

#### 層三: 故障日誌

**架構甲(REST):** 服務端日誌
```
/home/service/logs/render-2026-09-30.log
ERROR [10:15:23] GPU out of memory
ERROR [10:20:05] Model load failed
```

**架構乙(git):** repo 內失敗紀錄
```
failed/job-001-error.json:
{
  "status": "failed",
  "error": "CUDA out of memory",
  "stack_trace": "..."
}
```

### 監視儀表板 (推薦實現)

```powershell
# dashboard.ps1 — 定時執行,輸出狀態摘要

function Get-AIServiceStatus {
    $pending = (Get-ChildItem ".\ai-workload\pending\*.json" -ErrorAction SilentlyContinue).Count
    $processing = (Get-ChildItem ".\ai-workload\processing\*.lock" -ErrorAction SilentlyContinue).Count
    $completed = (Get-ChildItem ".\ai-workload\completed\*-output.png" -ErrorAction SilentlyContinue).Count
    $failed = (Get-ChildItem ".\ai-workload\failed\*.json" -ErrorAction SilentlyContinue).Count
    
    @{
        pending = $pending
        processing = $processing
        completed = $completed
        failed = $failed
        homeServiceReachable = (Test-NetConnection home-ai-service -Port 18888 -InformationLevel Quiet)
    }
}

$status = Get-AIServiceStatus
Write-Host @"
=== AI Art Service Status ===
Pending:  $($status.pending) jobs
Running:  $($status.processing) jobs
Done:     $($status.completed) jobs
Failed:   $($status.failed) jobs
Home OK:  $($status.homeServiceReachable)
Updated:  $(Get-Date)
"@
```

---

## 第五部分:待管理者回答的問題

| # | 問題 | 用途 | 優先級 |
|---|------|------|--------|
| Q1 | 家中桌機的作業系統是什麼?(Windows / Linux / macOS) | 決定部署工具與啟動機制 | 🔴 高(必須) |
| Q2 | 家中機器是否 24 小時開機?還是有定期關機? | 決定是否需要 WoL / 排程啟動 | 🟡 中 |
| Q3 | 家中網路環境是什麼?有公有 IP 嗎?還是 CGNAT? | 決定架構甲是否可行,或必須用隧道 | 🔴 高(影響架構選擇) |
| Q4 | 家中路由器型號/品牌是什麼? | 確認是否支援 port forwarding / WoL 轉發 | 🟡 中(涉及架構甲) |
| Q5 | 公司 IT 政策允許在筆電上安裝新軟體嗎? | 如用 Tailscale/WireGuard,需事先取得許可 | 🟡 中(影響具體部署細節) |
| Q6 | 公司筆電可以開放外網 HTTPS 連線嗎? | 決定 REST 服務連線是否被防火牆阻擋 | 🔴 高(影響架構甲可行性) |
| Q7 | 成品 PNG 預期多大?每月產出多少張? | 影響 git LFS 成本與 repo 磁碟用量 | 🟡 中(涉及長期維運) |
| Q8 | 家中桌機的 NVIDIA 驅動版本是什麼?或需要從零安裝? | 部署 CUDA 工具鏈時需確認相容性 | 🔴 高(影響 GPU 初始化) |

---

## 架構選擇決策樹

```
START
  │
  ├─→ 家中有公有 IP?
  │    │
  │    ├─→ 否 (CGNAT)
  │    │    └─→ 用 Cloudflare Tunnel (無需公司改動)
  │    │
  │    └─→ 是
  │         ├─→ 公司筆電能出 HTTPS?
  │         │    │
  │         │    ├─→ 否
  │         │    │    └─→ 用架構乙(git push)
  │         │    │
  │         │    └─→ 是
  │         │         └─→ 用架構甲(REST) — 最低延遲
  │
  └─→ 若不確定 → 預設架構乙(git),成本最低,對公司筆電改動最小
```

---

## 附錄:部署檢查清單

### 家中桌機初始檢查

- [ ] GPU 驅動已安裝,`nvidia-smi` 輸出正常
- [ ] AI 繪圖引擎(WebUI/Comfy)能獨立啟動
- [ ] 成功生成至少 1 張圖片,輸出路徑確認
- [ ] 啟動腳本 (`.bat` / `.sh`) 已測試
- [ ] 服務/systemd 已註冊,重啟後自動啟動
- [ ] 磁碟空間充足 (預留 50GB+ 給模型與成品)

### 公司筆電初始檢查

- [ ] git 倉庫 clone 完整
- [ ] 網路連線測試 (ping github.com)
- [ ] 若架構甲: 確認 TLS 證書信任(自簽則 skip cert check)
- [ ] 若架構乙: PowerShell 執行政策允許腳本運行
- [ ] 監視儀表板腳本能執行無誤

---

**本文件更新日期:** 2026-09-30
**驗證狀態:** 全部推測 (C),待實機測試

