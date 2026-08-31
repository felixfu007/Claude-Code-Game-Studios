<#
capture_window.ps1 — 對匯出後的 Godot .exe 拍攝視窗畫面（QA 證據用）

============================================================
根因記錄（2026-08-31 診斷，供下一個維護者查閱，避免重踩）
============================================================

【問題】舊版腳本對匯出的 .exe 連續七次回報 GetClientRect = 0x0，
        拉長等待時間、重新取得 handle、加 --resolution 參數全部無效。

【根因 1：抓錯 PID，抓到一個本來就該是 0x0 的視窗】
  匯出目錄同時有 BlindInTheFaintLight.console.exe（主控台外殼）與
  BlindInTheFaintLight.exe（真正的遊戲本體）。實測用
  Get-CimInstance Win32_Process 印出的行程樹：
    36300  (無 parent)  BlindInTheFaintLight.console.exe
    33344  parent=36300 BlindInTheFaintLight.exe   ← 真正擁有遊戲視窗的 PID
  若對 console.exe 那個 PID 做 EnumWindows，只會找到一個叫
  'PseudoConsoleWindow' 的視窗，GetWindowRect / GetClientRect
  永遠回報 (0,0)-(0,0) —— 這是它本來的正常狀態，不是還沒畫好，
  所以無論等多久都不會變。真正的 'Engine' 類別視窗（Godot 匯出視窗
  的 class 名稱）屬於子行程，不屬於你啟動的那個 PID。
  → 對策：一定要沿著行程樹找到「真正擁有 class='Engine' 可見視窗」
    的那個 PID，不能假設是你 Start-Process 拿到的 PID 本人。這支
    腳本用 Get-DescendantProcessIds 遞迴收集整條子行程鏈再比對。

【根因 2：DPI 虛擬化，GetClientRect 回報的不是實體像素】
  本機 Windows 顯示縮放為 125%。PowerShell 行程預設是 DPI-unaware，
  此時系統會把視窗座標「虛擬化」成放大前的邏輯座標再回傳給呼叫者。
  實測對照（同一個視窗、同一支腳本，只差有沒有先呼叫
  SetProcessDpiAwarenessContext）：
    DPI 感知之前: GetWindowRect 782x470  GetClientRect 768x432  DwmExtFrameBounds 962x579
    DPI 感知之後: GetWindowRect 978x587  GetClientRect 960x540  DwmExtFrameBounds 962x579（不變）
  960x540 才是專案設定的正確視窗尺寸（480x270 基礎解析度的整數 2 倍）。
  768x432 = 960x540 / 1.25，正是被 125% 縮放虛擬化後的結果。
  DwmExtFrameBounds 兩次都一樣，因為那支 API 本來就不受呼叫端 DPI
  感知狀態影響，但它含邊框陰影，數字對不上 WindowRect，不能拿來當
  ClientRect 的替代品。
  → 對策：呼叫任何 Get*Rect 之前，必須先呼叫
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4)。
    忘記這一步不會讓截圖失敗，而是會讓截圖「看起來成功」但尺寸是
    768x432 而不是 960x540 —— 因為本作是像素風、480x270 基礎解析度，
    768÷480=1.6 不是整數倍，每個遊戲像素會被不完整的格線重新取樣，
    圖會多出遊戲裡本來沒有的模糊，而且沒有任何錯誤訊息可以提醒你。
    這比直接失敗更危險：下一個看圖的人無法分辨那是截圖造成的、
    還是遊戲真的糊了。

【根因 4：開機畫面競態（2026-08-31 協調者複驗抓到，寫進正式腳本前的最後一關）】
  第一版正式腳本只等到「視窗出現、可見、class='Engine'」就立刻擷取，
  沒有再等內容真正畫出來。實測結果：同一支腳本、同一支 exe，
  某次在「輪詢 2 次」（約 1 秒）時擷取到的是 Godot 預設開機畫面
  （藍色機器人標誌 + "GODOT / Game engine" 字樣），不是遊戲畫面 ——
  因為視窗在開機畫面顯示期間就已經符合「可見的 Engine 視窗」這個
  條件，跟等待時間長短無關，是視窗出現的時機和內容畫出來的時機
  本來就是兩件事，不能假設同時發生。

  【為什麼算相異顏色數擋不住它】直覺會覺得「開機畫面比較單調，
  相異顏色數應該比較少」，實測結果剛好相反：
    真正的遊戲畫面：相異顏色數 247（960x540 全圖）
    開機畫面（誤判為證據的那張）：相異顏色數 493 —— 比遊戲畫面還多
  原因是開機標誌的陰影/邊緣有漸層灰階，反而比像素風遊戲畫面的
  大面積純色貼圖產生更多相異顏色值。「顏色數門檻」只能擋真正全黑
  /全灰的空白幀，擋不住開機畫面這種「內容豐富但不是遊戲」的情況。

  【全圖 2x2 網格完整性一樣不可靠，且方向是反的】原本設想比照
  「像素網格完整性」的邏輯：開機標誌的抗鋸齒邊緣應該會破壞 2x2
  網格。實測對整張 960x540（480x270 個 2x2 格）計算不一致比例：
    真正的遊戲畫面：129600 格中 4091 格不一致（3.157%）
    開機畫面：       129600 格中 2265 格不一致（1.748%）
  遊戲畫面的不一致比例反而比開機畫面高，因為本專案的對話正文
  刻意使用「一般繁體中文字型而非像素字型」（見 design/art/art-direction.md），
  這些抗鋸齒文字本身就會在真正的遊戲畫面裡製造大量 2x2 不一致，
  數量超過開機標誌的抗鋸齒邊緣。全圖網格完整性檢查在這裡是
  反向指標，不能當篩選條件用；若要用，必須先精準框出純世界層
  （不含文字 UI）的子區域，本次未做到，故未採用。

  【實際採用的兩道防線，皆已用真實截圖數據校準】
    1) 抽樣多點比對：在畫面上取 12 個分散座標，要求相異顏色數 >= 3。
       開機畫面的 12 個抽樣點全部落在同一片背景色（全部同色，
       distinct=1）；真正遊戲畫面實測 distinct=7。門檻設在 3，
       兩者中間有充分安全邊界。
    2) 主導色佔比：算出全圖中「單一顏色的像素數」占全圖比例。
       真正遊戲畫面 43.06%；開機畫面 94.62%（背景色幾乎鋪滿整張圖，
       只有中間一小塊標誌）。門檻設在 80%，兩者中間同樣有充分邊界。
  兩道防線任一失敗就重試（在 -SettleTimeoutSeconds 時間預算內反覆
  重新擷取），重試仍失敗就明確報錯、不寫檔。

【根因 3（過程中另外抓到，非原始清單裡的假設）：
  PrintWindow 的旗標少加了 PW_CLIENTONLY】
  只傳 PW_RENDERFULLCONTENT（=2）時，PrintWindow 會把「整個視窗」
  （含 OS 標題列）畫進目標畫布，但畫布只開了 ClientRect 大小
  （960x540，不含標題列的 978x587）。結果是：畫面最上方變成
  OS 標題列（遊戲名稱、最小化/最大化/關閉鈕），而遊戲內容本該顯示在
  最下方的操作提示文字列反而被裁掉、看不到。像素網格完整性檢查
  雖然仍會通過（因為裁到的每一塊本身仍是乾淨的 2x2），
  但這是在拍「錯誤的一塊」，不是「拍壞了」，肉眼比對才抓到，
  單靠自動化的相異顏色數/網格檢查抓不出來。
  → 對策：旗標要用 PW_CLIENTONLY | PW_RENDERFULLCONTENT（= 3），
    才會只畫進 client area，且仍強制走 GPU 合成內容路徑
    （Vulkan/Forward+ 視窗如果不加 PW_RENDERFULLCONTENT，訓練資料裡
    常見的說法是 PrintWindow 會回傳 true 但整張圖全黑/全灰
    ——這件事本專案尚未實測重現過，寫在這裡供下次真的踩到時比對，
    不要當成已驗證的事實）。

============================================================
為什麼不用螢幕截圖（BitBlt-from-desktop / 全螢幕）
============================================================
本機桌面上可能同時開著私人信箱與公司內部系統視窗。任何「先截全螢幕、
之後再裁切」的做法，都必然有一個瞬間整張桌面的點陣圖存在於
記憶體或磁碟上；如果程式在裁切前當掉、被中斷、或裁切座標算錯，
外洩的就是使用者的私人畫面。本工具改用 PrintWindow 直接向
目標視窗要內容，資料路徑完全不經過桌面合成畫面，從頭到尾
記憶體裡只存在「這個視窗的內容」，沒有機會意外落地全螢幕影像。
這是本工具存在的核心理由之一，修改此腳本時請不要為了方便
（例如某天 PrintWindow 對某個新視窗類型失效）就退回全螢幕截圖
再裁切的做法 —— 請回報，不要私自繞過這個限制。

============================================================
已驗證的限制
============================================================
- 【視窗最小化時無法擷取】實測：呼叫 ShowWindow(SW_MINIMIZE) 後，
  IsIconic 回報 True，此時 GetClientRect 回報 (0,0)-(0,0)，是視窗
  本身真實的合理狀態（不是根因 1 那種「抓錯視窗」的假 0x0）。
  本腳本會在此狀態下正確判定失敗、不落地任何影像，但目前沒有
  自動把視窗還原（ShowWindow SW_RESTORE）再重試 —— 呼叫端須自行
  確保目標視窗未被最小化。
- 【是否需要前景焦點】嘗試測試過視窗被其他視窗遮擋/非前景時能否
  擷取，過程中控制腳本本身有 bug（SetForegroundWindow 呼叫型別轉換
  失敗），未能 100% 確認遮擋確實發生；擷取結果雖然與前景狀態下
  的已知基準（相異顏色數 247）一致，但這只是佐證、不是確證，
  未來若要依賴「非前景也能拍」這個特性，建議重新測試。
- 【多螢幕】未測試（開發機只有單一螢幕）。
- 【視窗 class 名稱固定為 'Engine'】這是 Godot 4.7.1 匯出視窗的
  實測結果。若日後 Godot 版本更新導致 class 名稱改變，本腳本的
  視窗比對條件需要同步更新（見 docs/engine-reference/godot/VERSION.md）。
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExePath,

    [string]$OutPath,

    [int]$WaitSeconds = 15,

    [int]$SettleTimeoutSeconds = 12,

    [switch]$KeepRunning
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ExePath)) {
    Write-Error "找不到執行檔: $ExePath"
    exit 1
}

if (-not $OutPath) {
    $dateStr = Get-Date -Format "yyyy-MM-dd"
    $OutPath = Join-Path (Get-Location) "capture_$dateStr.png"
}

Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;

public class CaptureWindowWin32 {
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetProcessDpiAwarenessContext(IntPtr value);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    public static List<IntPtr> EnumTopLevel() {
        List<IntPtr> result = new List<IntPtr>();
        EnumWindows(delegate (IntPtr hWnd, IntPtr lParam) { result.Add(hWnd); return true; }, IntPtr.Zero);
        return result;
    }
}
"@

# 根因 2 對策：一定要在任何 Get*Rect 呼叫之前設定，否則整支腳本
# 拿到的座標都是被 125%（或其他非 100%）縮放虛擬化過的錯誤值。
$dpiOk = [CaptureWindowWin32]::SetProcessDpiAwarenessContext([IntPtr]::new(-4))
Write-Verbose "SetProcessDpiAwarenessContext(PER_MONITOR_AWARE_V2) = $dpiOk"

function Get-DescendantProcessIds {
    param([int]$RootPid)
    $all = Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId
    $result = New-Object System.Collections.Generic.List[int]
    $queue = New-Object System.Collections.Generic.Queue[int]
    $queue.Enqueue($RootPid)
    $result.Add($RootPid)
    while ($queue.Count -gt 0) {
        $cur = $queue.Dequeue()
        foreach ($p in $all) {
            if ($p.ParentProcessId -eq $cur -and -not $result.Contains([int]$p.ProcessId)) {
                $result.Add([int]$p.ProcessId)
                $queue.Enqueue([int]$p.ProcessId)
            }
        }
    }
    return $result
}

function Find-GameWindow {
    param([int[]]$CandidatePids)
    $allTop = [CaptureWindowWin32]::EnumTopLevel()
    foreach ($h in $allTop) {
        $pidOut = 0
        [CaptureWindowWin32]::GetWindowThreadProcessId($h, [ref]$pidOut) | Out-Null
        if ($CandidatePids -contains [int]$pidOut -and [CaptureWindowWin32]::IsWindowVisible($h)) {
            $sbClass = New-Object System.Text.StringBuilder 256
            [CaptureWindowWin32]::GetClassName($h, $sbClass, 256) | Out-Null
            # 根因 1 對策：不假設是你啟動的那個 PID，改成比對「class 是不是
            # Godot 匯出視窗的 Engine」，並且候選 PID 清單包含整條子行程鏈。
            if ($sbClass.ToString() -eq "Engine") {
                return $h
            }
        }
    }
    return [IntPtr]::Zero
}

function Test-CapturedContent {
    # 根因 4 對策：兩道防線，皆已用真實截圖數據校準（見腳本檔頭）。
    # 回傳 hashtable，內含通過與否、以及供最終輸出自證用的數據。
    param([System.Drawing.Bitmap]$Bmp)
    $w = $Bmp.Width
    $h = $Bmp.Height

    # 防線 1：抽樣 12 個分散座標，要求相異顏色數 >= 3
    # （開機畫面實測 12 點全部同色 distinct=1；真正遊戲畫面實測 distinct=7）
    $sampleFracs = @(
        @(0.05,0.05), @(0.5,0.05), @(0.95,0.05),
        @(0.05,0.5),  @(0.5,0.5),  @(0.95,0.5),
        @(0.05,0.95), @(0.5,0.95), @(0.95,0.95),
        @(0.25,0.25), @(0.75,0.25), @(0.75,0.75)
    )
    $sampleColors = New-Object 'System.Collections.Generic.HashSet[int]'
    $sampleReport = New-Object System.Collections.Generic.List[string]
    foreach ($f in $sampleFracs) {
        $sx = [Math]::Min($w - 1, [int]($w * $f[0]))
        $sy = [Math]::Min($h - 1, [int]($h * $f[1]))
        $c = $Bmp.GetPixel($sx, $sy)
        [void]$sampleColors.Add($c.ToArgb())
        $sampleReport.Add(("($sx,$sy)=#{0:X2}{1:X2}{2:X2}" -f $c.R, $c.G, $c.B))
    }
    $distinctSamples = $sampleColors.Count

    # 防線 2：主導色（單一最常出現的顏色）佔全圖像素比例
    # （開機畫面實測 94.62%，背景幾乎鋪滿全圖；真正遊戲畫面實測 43.06%）
    $colorCounts = @{}
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $argb = $Bmp.GetPixel($x, $y).ToArgb()
            if ($colorCounts.ContainsKey($argb)) { $colorCounts[$argb]++ } else { $colorCounts[$argb] = 1 }
        }
    }
    $totalPixels = $w * $h
    $dominantCount = ($colorCounts.Values | Measure-Object -Maximum).Maximum
    $dominantRatio = [math]::Round(($dominantCount / $totalPixels) * 100, 2)
    $distinctColors = $colorCounts.Count

    $MinDistinctSamples = 3
    $MaxDominantRatio = 80.0
    $MinDistinctColors = 20

    $reasons = New-Object System.Collections.Generic.List[string]
    if ($distinctSamples -lt $MinDistinctSamples) {
        $reasons.Add("抽樣 12 點相異顏色數僅 $distinctSamples（門檻 >= $MinDistinctSamples），疑似落在單一背景色上（開機畫面的已知特徵）")
    }
    if ($dominantRatio -gt $MaxDominantRatio) {
        $reasons.Add("主導色佔比 $dominantRatio%（門檻 <= $MaxDominantRatio%），疑似大面積空白背景 + 小塊置中內容（開機畫面的已知特徵）")
    }
    if ($distinctColors -lt $MinDistinctColors) {
        $reasons.Add("全圖相異顏色數僅 $distinctColors（門檻 >= $MinDistinctColors），疑似全黑/全灰空白幀")
    }

    return @{
        Passed          = ($reasons.Count -eq 0)
        Reasons         = $reasons
        DistinctSamples = $distinctSamples
        SampleReport    = $sampleReport
        DominantRatio   = $dominantRatio
        DistinctColors  = $distinctColors
    }
}

Write-Output "啟動: $ExePath"
$proc = Start-Process -FilePath $ExePath -PassThru

# 
trap {
    Write-Output "發生未預期錯誤，執行緊急清理：$($_.Exception.Message)"
    if (-not $KeepRunning -and $proc) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    break
}


$deadline = (Get-Date).AddSeconds($WaitSeconds)
$targetHwnd = [IntPtr]::Zero
$pollCount = 0

while ((Get-Date) -lt $deadline) {
    $pollCount++
    $check = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if ($null -eq $check) {
        Write-Error "行程在等待期間已結束（可能啟動失敗）。請確認執行檔本身可以正常啟動。"
        exit 1
    }
    $candidates = Get-DescendantProcessIds -RootPid $proc.Id
    $targetHwnd = Find-GameWindow -CandidatePids $candidates
    if ($targetHwnd -ne [IntPtr]::Zero) {
        break
    }
    Start-Sleep -Milliseconds 500
}

if ($targetHwnd -eq [IntPtr]::Zero) {
    Write-Error "等待 $WaitSeconds 秒後仍找不到 class='Engine' 的可見視窗（PID $($proc.Id) 及其子行程）。不落地任何影像。若這是匯出設定變更後第一次執行，請確認匯出視窗的 class 名稱是否仍是 'Engine'。"
    if (-not $KeepRunning) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    exit 1
}

Write-Output "找到遊戲視窗 HWND=$targetHwnd（輪詢 $pollCount 次）"

$cr = New-Object CaptureWindowWin32+RECT
[CaptureWindowWin32]::GetClientRect($targetHwnd, [ref]$cr) | Out-Null
$w = $cr.Right - $cr.Left
$h = $cr.Bottom - $cr.Top
Write-Output "ClientRect（DPI 感知後）: ${w}x${h}"

if ($w -le 0 -or $h -le 0) {
    Write-Error "ClientRect 無效（${w}x${h}）。常見原因：視窗處於最小化狀態（已實測 IsIconic=True 時 ClientRect 會是 0x0，這是視窗真實狀態，不是本工具的 bug）。不落地任何影像。"
    if (-not $KeepRunning) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    exit 1
}

# 根因 4 對策：不是「找到視窗就立刻擷取存檔」，而是擷取後先驗內容，
# 驗不過就重試（視窗已經找到了，不必重新啟動或重新找視窗），
# 在 -SettleTimeoutSeconds 預算內反覆擷取直到通過或預算耗盡。
# 這是為了擋開機畫面競態：視窗「出現」跟「內容真正畫出來」是兩件事。
$settleDeadline = (Get-Date).AddSeconds($SettleTimeoutSeconds)
$captureAttempt = 0
$validation = $null
$finalBmp = $null

while ((Get-Date) -lt $settleDeadline) {
    $captureAttempt++
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $gfx.GetHdc()
    # 根因 3 對策：PW_CLIENTONLY(1) | PW_RENDERFULLCONTENT(2) = 3
    # 只有 CLIENTONLY 才不會把 OS 標題列一起畫進來、把畫面下緣裁掉；
    # 只有 RENDERFULLCONTENT 才能正確畫出 Vulkan/Forward+ 的 GPU 合成內容。
    $ok = [CaptureWindowWin32]::PrintWindow($targetHwnd, $hdc, 3)
    $gfx.ReleaseHdc($hdc)
    $gfx.Dispose()

    if (-not $ok) {
        Write-Output "第 $captureAttempt 次擷取: PrintWindow 回傳 false，重試中..."
        $bmp.Dispose()
        Start-Sleep -Milliseconds 800
        continue
    }

    $validation = Test-CapturedContent -Bmp $bmp
    if ($validation.Passed) {
        $finalBmp = $bmp
        Write-Output "第 $captureAttempt 次擷取通過內容驗證"
        break
    } else {
        Write-Output "第 $captureAttempt 次擷取未通過內容驗證，重試中:"
        foreach ($r in $validation.Reasons) { Write-Output "  - $r" }
        $bmp.Dispose()
        Start-Sleep -Milliseconds 800
    }
}

if ($null -eq $finalBmp) {
    Write-Error "在 $SettleTimeoutSeconds 秒內重試 $captureAttempt 次，內容驗證始終未通過（很可能一直停在開機畫面或載入畫面）。不落地任何影像。"
    if (-not $KeepRunning) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    exit 1
}

$outDir = Split-Path -Parent $OutPath
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$finalBmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$finalBmp.Dispose()

Write-Output "已存檔: $OutPath"
Write-Output "--- 自我驗證數據（存檔前已通過，這裡是給使用者複核用）---"
Write-Output "影像尺寸: ${w}x${h}"
Write-Output "全圖相異顏色數: $($validation.DistinctColors)"
Write-Output "主導色佔比: $($validation.DominantRatio)%（門檻 <= 80%）"
Write-Output "抽樣 12 點相異顏色數: $($validation.DistinctSamples)（門檻 >= 3）"
Write-Output "抽樣座標與顏色: $($validation.SampleReport -join ', ')"

if (-not $KeepRunning) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    Write-Output "已關閉遊戲行程 PID=$($proc.Id)"
} else {
    Write-Output "-KeepRunning 已指定，遊戲行程 PID=$($proc.Id) 保持執行中"
}
