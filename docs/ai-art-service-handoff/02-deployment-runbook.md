# 第二章:部署與環境建置手冊

> **本文的每一條指令都未在目標機器上實際執行過。** 
> 第一步永遠是先手動跑通一張圖、把環境指紋記下來，再開始自動化。

## 零、前置假設

- **作業系統**: Windows 10 / 11 (22H2 或更新)，英文或日文語系(繁體中文可能產生路徑編碼問題)
- **硬體**: NVIDIA RTX 5070 Ti (Blackwell 架構，`sm_120`)，16GB VRAM，NVIDIA 官方驅動支援此卡
- **網路**: 本機運行，僅供 `localhost:PORT` 存取，不對外開放
- **若作業系統或驅動版本不符**: 本文步驟可能無法照著做，應先在官方文件驗證相容性

## 一、軟體安裝清單與順序

### 1.1 驅動與基礎套件版本

**詳細的驅動、CUDA、PyTorch 版本要求與相容性矩陣，請見本交付包 `01-architecture-and-feasibility.md` 的〈第三節 驅動 / CUDA / PyTorch 的最低版本(最關鍵的一條)〉。**

以下為快速檢查清單(基於 RTX 5070 Ti + Blackwell sm_120，2026-10-05 查證)：

| 軟體 | 最低版本 | 檢查方式 |
|-----|---------|--------|
| NVIDIA 驅動 | 570.65(CUDA 12.8) 或 572.61(CUDA 12.8 Update 1) | `nvidia-smi` 查詢版本 |
| CUDA Toolkit | 12.8 | `nvcc --version` |
| PyTorch | 2.7.0+，**必須帶 `+cu128` 尾碼** | `python -c "import torch; print(torch.__version__)"` |
| cuDNN | 9.0 或更新(對應 CUDA 版本) | 無命令行檢查；安裝後驗證解壓位置 |

### 1.2 安裝步驟

1. **驗證驅動**: 開 PowerShell，執行 `nvidia-smi`，確認版本 ≥ 570.65(若使用 CUDA 12.8 GA) 或 ≥ 572.61(CUDA 12.8 Update 1)
   - 版本號顯示在輸出的右上角，例如 `Driver Version: 570.65`
   - 若版本過舊，從 nvidia.com/Download/driverDetails 下載對應卡型的最新驅動並安裝(需重啟)
   
2. **安裝 CUDA**
   ```powershell
   # 下載 CUDA 12.8 Toolkit Windows 版本
   # 執行 .exe 安裝程式，選擇預設安裝路徑 C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8
   ```
   
3. **驗證 CUDA**
   ```powershell
   # 開新 PowerShell 視窗(環境變數變更需重新載入)
   nvcc --version
   # 應輸出 "release 12.8" 或更新
   ```

4. **安裝 cuDNN**
   - 從上述網址下載對應 CUDA 12.8 的 cuDNN 9.x zip 檔
   - 解壓到 CUDA 安裝路徑(通常 `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8`)
   - 檔案應落在 `bin/`, `include/`, `lib/` 等標準位置

5. **安裝 PyTorch 與相依套件**
   ```powershell
   # 建立 Python 虛擬環境(假設已安裝 Python 3.10 或 3.11)
   python -m venv C:\path\to\venv
   .\venv\Scripts\Activate.ps1
   
   # 安裝 PyTorch 2.7.0+ with CUDA 12.8 支援
   pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
   
   # 【關鍵】驗證 PyTorch 版本與 CUDA 編譯選項
   python -c "import torch; print('PyTorch:', torch.__version__)"
   # 應輸出類似 "PyTorch: 2.7.0+cu128"
   # ⚠️ 若輸出是 "2.7.0+cu126" 或無 +cuXXX 尾碼，代表裝到錯誤的 wheel，會導致 sm_120 不相容錯誤
   
   # 驗證 PyTorch 能看到 GPU
   python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"
   # 應輸出 True 與 RTX 5070 Ti 相關文字
   ```

6. **安裝推論伺服器框架(以 vLLM 為例)**
   ```powershell
   pip install vllm>=0.6.0
   # 或根據實際選用的框架調整
   ```

## 二、模型檔的取得與部署

### 2.1 模型儲存位置

建立目錄: `C:\stable-diffusion-models\` 或其他易於追蹤的位置

### 2.2 下載模型(以 Hugging Face 為例)

```powershell
# 安裝 git-lfs
choco install git-lfs  # 或從 git-lfs.com 下載安裝
git lfs install

# 使用 Hugging Face 官方指令或本機 CLI 下載(需預先登入)
huggingface-cli login
# 輸入 token，可從 huggingface.co/settings/tokens 取得

huggingface-cli download MODEL_ID --local-dir C:\stable-diffusion-models\MODEL_NAME
```

### 2.3 驗證模型完整性

```powershell
# 記錄模型檔案的 SHA256，避免後續版本不一致
Get-FileHash C:\stable-diffusion-models\MODEL_NAME\*.safetensors -Algorithm SHA256 | Out-File model_hashes.txt
```

**重要**: 不同時間從 Hugging Face 抓相同模型可能取得不同權重版本(如微調或安全修補)；始終記錄 SHA256 做驗收依據。

## 三、服務啟動與健康檢查

### 3.1 編寫服務啟動腳本(Python Flask 為例)

```python
# C:\deployment\app.py
from flask import Flask, request, jsonify
import torch
from diffusers import StableDiffusionPipeline

app = Flask(__name__)

# 初始化模型(啟動時)
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
MODEL_PATH = r"C:\stable-diffusion-models\MODEL_NAME"
pipeline = StableDiffusionPipeline.from_pretrained(MODEL_PATH, torch_dtype=torch.float16)
pipeline.to(DEVICE)

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "device": DEVICE, "cuda_available": torch.cuda.is_available()})

@app.route("/generate", methods=["POST"])
def generate():
    prompt = request.json.get("prompt", "")
    if not prompt:
        return jsonify({"error": "prompt required"}), 400
    
    # 生成圖像
    with torch.no_grad():
        image = pipeline(prompt).images[0]
    
    # 儲存或傳回(此處簡化)
    image.save(r"C:\temp\output.png")
    return jsonify({"output": r"C:\temp\output.png"})

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=False)
```

### 3.2 啟動服務與驗證

```powershell
# 啟動伺服器
cd C:\deployment
python app.py

# 另開 PowerShell 視窗，測試健康檢查端點
curl http://localhost:5000/health
# 應回傳 {"status": "healthy", "device": "cuda", "cuda_available": true}
```

## 四、開機自動啟動

### 4.1 Windows 工作排程器方案(推薦用於單一應用)

1. 開啟 `taskschd.msc` (工作排程器)
2. 右鍵 → 建立工作
3. 設定:
   - **一般**: 名稱 `AI-Art-Service`，勾選 `不論使用者是否登入都執行`
   - **觸發條件**: 新增 → 選 `開機時`
   - **動作**: 新增 → 程式: `C:\path\to\venv\Scripts\python.exe`，引數: `C:\deployment\app.py`
   - **設定**: 勾選 `如果工作失敗，在此間隔內重試` (設 5 分鐘)

### 4.2 Windows 服務方案(更穩定，但設定複雜)

使用 `nssm` (Non-Sucking Service Manager) 包裝 Python 應用:

```powershell
# 下載 nssm，解壓並加入 PATH
choco install nssm
# 或手動從 nssm.cc 下載

# 安裝服務
nssm install AIArtService C:\venv\Scripts\python.exe C:\deployment\app.py
nssm set AIArtService AppDirectory C:\deployment

# 設定自動啟動
nssm set AIArtService Start SERVICE_AUTO_START

# 啟動服務
nssm start AIArtService

# 查看狀態
Get-Service AIArtService
```

**建議**: 初期用工作排程器(簡單)，待穩定後再改服務(更可靠)。

## 五、故障排除清單(常見問題)

### 問題 1: "sm_120 is not compatible" / "CUDA compute capability"

**症狀**: PyTorch 或模型推論時報錯，出現 `sm_120` 或 `compute capability` 字樣

**根本原因**: 有三個常見的入口導致此錯誤(詳細的版本相容性矩陣見 `01-architecture-and-feasibility.md` 的〈第三節 驅動 / CUDA / PyTorch 的最低版本〉)：
- NVIDIA 驅動版本過舊(< 570.65)
- CUDA Toolkit 版本過舊(≤ 12.1)
- PyTorch wheel 是用錯的 CUDA 版本編譯的(例裝到 `torch 2.7.0+cu126` 而非 `+cu128`)

**排查順序**:
1. 檢查驅動: `nvidia-smi` → 版本號 ≥ 570.65？
2. 檢查 PyTorch: `python -c "import torch; print(torch.__version__)"` → 包含 `+cu128` 尾碼？
3. 若驅動或版本號不符，見本文第一節的版本要求，重新安裝對應版本

### 問題 2: `Out Of Memory (OOM)`

**症狀**: 單張生成時顯示 `CUDA out of memory`，即使機器有 16GB 空閒 VRAM

**根本原因**: 模型權重 + 推論中間結果超過 VRAM；也可能驅動未完全卸載舊核心

**解決方案**:
1. 降低推論時的精度: `torch.float32` 改 `torch.float16` 或 `torch.bfloat16`
2. 啟用內存優化: `enable_attention_slicing()`, `enable_xformers_memory_efficient_attention()`
3. 重啟 Python 程序(有時驅動未釋放內存)
4. 確認沒有其他 GPU 應用佔用 VRAM: `nvidia-smi`

### 問題 3: 驅動版本不符導致初始化失敗

**症狀**: `nvidia-smi` 能跑，但 `import torch` 時失敗，或顯示 CUDA 版本衝突警告

**根本原因**: NVIDIA 驅動版本不符預期版本(詳見 `01-architecture-and-feasibility.md` 的〈第三節〉)

**排查方案**:
1. 檢查目前驅動版本: `nvidia-smi` 第一行顯示 `Driver Version: XXX.XX`
2. 比對目標版本: CUDA 12.8 GA 需 ≥ 570.65；CUDA 12.8 Update 1 需 ≥ 572.61
3. 若不符，從 nvidia.com/Download/driverDetails 下載對應版本，完整卸載舊驅動後重新安裝(不要直接覆蓋)
4. 重啟電腦並再次驗證 `nvidia-smi` 版本

### 問題 4: 服務停止但不自動重啟

**症狀**: 應用程序崩潰後沒有自動恢復，`Get-Service` 顯示 Stopped

**根本原因** (如使用工作排程器): 排程可能未觸發重試，或觸發時已超過預定時間

**解決方案**:
1. 檢查事件檢視器 (`eventvwr.msc`) → Windows 日誌 → 系統，尋找工作排程的失敗紀錄
2. 確保排程重試間隔足夠(建議 5 分鐘)
3. 考慮改用 NSSM 服務，提供更好的失敗恢復

### 問題 5: GPU 記憶體洩漏，長時間執行變慢

**症狀**: 首張圖生成 5 秒，但跑一小時後變成 15 秒，`nvidia-smi` 顯示 VRAM 佔用持續增長

**根本原因**: Python / PyTorch 物件未正確釋放，驅動層累積記憶體碎片

**解決方案**:
1. 在推論迴圈後加 `torch.cuda.empty_cache()` 手動清理
2. 定期重啟服務(例每小時)，在 cron 或工作排程加 `nssm restart AIArtService`
3. 使用 `nvidia-smi -l 1` 持續監控 VRAM，確認每次推論後都有下降

### 問題 6: PyTorch "sm_120 is not compatible"，但驅動與 CUDA 版本都對

**症狀**: `nvidia-smi` 顯示驅動 ≥ 570.65，`nvcc --version` 顯示 CUDA 12.8，但 `import torch` 或推論時仍出現 `sm_120` 錯誤

**根本原因**: PyTorch wheel 是用錯誤的 CUDA 版本編譯的。`pip install torch` 若未指定正確的 index URL，可能靜默安裝用 CUDA 12.6 等舊版編譯的 wheel。版本字串檢查會通過(例 `2.7.0`)，但實際編譯目標不含 `sm_120`。

**排查與解決方案**:
1. 檢查已安裝的 PyTorch 編譯選項: `python -c "import torch; print(torch.__version__)"`
   - 應看到 `2.7.0+cu128` 或更新版本(含 `+cu128` 尾碼)
   - 若看到 `2.7.0+cu126` 或無尾碼，代表裝錯版本
2. 卸載既有 PyTorch: `pip uninstall torch torchvision torchaudio -y`
3. 重新安裝，**務必指定正確的 index URL**:
   ```powershell
   pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
   ```
4. 驗證新版本: `python -c "import torch; print(torch.__version__)"` → 應包含 `+cu128`

## 六、資源與監控

### 6.1 VRAM 監控

```powershell
# 檢視當前使用
nvidia-smi

# 持續監控(每 1 秒更新)
nvidia-smi -l 1

# 記錄到檔案(供長期分析)
nvidia-smi --query-gpu=timestamp,name,utilization.gpu,utilization.memory,memory.used,memory.free --format=csv,nounits >> C:\logs\gpu_usage.csv
```

**預期 VRAM 峰值** (根據模型、精度，此為估計):
- Stable Diffusion 1.5 (float16): ~7-9 GB
- Stable Diffusion XL (float16): ~11-14 GB  
- LoRA 微調推論: 需額外 500MB-2GB

### 6.2 單張生成耗時測量

```powershell
# Python 內測時
import time
start = time.time()
image = pipeline(prompt)
elapsed = time.time() - start
print(f"耗時: {elapsed:.2f} 秒")
```

**預期耗時** (RTX 5070 Ti，1024×1024，float16):
- 首次啟動: 15-30 秒 (模型加載)
- 後續生成: 3-8 秒 (取決於 steps 與採樣器)

### 6.3 長時間執行健康度檢查

定期檢查無漏記憶體:
```powershell
# 簡易腳本: 每 10 秒記錄一次 VRAM
$count = 0
while ($count -lt 360) {  # 1 小時
    $mem = & nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - GPU Memory: ${mem}MB"
    Start-Sleep -Seconds 10
    $count++
}
```

## 七、驗收清單

外包方交付時，**必須附上以下環境指紋**。驗收方用此驗證環境一致性:

```
驗收日期: 2026-10-XX
機器標識: [您的電腦名稱]

NVIDIA 驅動版本: [nvidia-smi 輸出]
CUDA 版本: [nvcc --version 輸出]
PyTorch 版本與編譯選項: [python -c "import torch; print(torch.__version__, torch.version.cuda)"]
GPU 能力: [python -c "import torch; print(torch.cuda.get_device_capability(0))"]

模型檔位置: [絕對路徑]
模型檔 SHA256: [每個 .safetensors 或 .bin 檔案的雜湊]

服務埠: [localhost:PORT]
服務啟動方式: [工作排程/NSSM 服務/其他]

單張測試結果:
  提示詞: "a cat"
  解析度: 1024x1024
  生成耗時: X.XX 秒
  VRAM 峰值: XXXX MB
  首次生成: [經過時間，含模型加載]
  後續生成: [經過時間]

健康檢查端點: GET http://localhost:PORT/health → [回傳內容]
```

## 八、安全最低要求(部署面)

- **API 端口綁定**: 始終使用 `127.0.0.1` 或 `localhost`，**絕不使用 `0.0.0.0` 對外開放**
- **認證**: 若要跨區域網路呼叫，應在反向代理(nginx / Apache)層加 API 金鑰驗證，**本應用層不實現認證**
- **日誌記錄**: 推論請求與結果應記錄(含時間戳、提示詞、耗時)，便於事後稽核
- **防火牆**: Windows Defender 防火牆應設定只允許本機存取該埠，或由 IT 部門配置網路層隔離

**完整安全評估(如密鑰輪轉、內容審核、訪問日誌分析)由其他文件涵蓋，本章只涵蓋部署必須項。**

---

## 已知未驗證項(2026-10-05 委託方覆核更新)

- **驅動版本**: ✅ 已驗證。NVIDIA 驅動 570.65 (CUDA 12.8 GA) 或 572.61 (CUDA 12.8 Update 1) 為 RTX 5070 Ti (Blackwell sm_120) 的最低要求。來源: NVIDIA CUDA Toolkit 12.8.0 Release Notes、LeaderGPU RTX 50 series 安裝指南 (2026-10-05 查證)。
- **CUDA 12.8 與 PyTorch 2.7.0+ 相容性**: ✅ 已驗證成立。
- **本文所有指令**: ❌ 仍未在 RTX 5070 Ti + Windows 11 上實際執行（唯讀查證，未實跑）。
- **VRAM 峰值與耗時估計值**: ❌ 基於同代 GPU 的一般經驗，未對本型號實測。

---

**下一步**: 部署方應先手動跑通一張圖、記錄環境指紋，再與本文步驟對照並上報任何不符之處。
