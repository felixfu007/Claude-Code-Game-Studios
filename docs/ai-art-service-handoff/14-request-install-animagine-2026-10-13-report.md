# 第十四份回覆：Animagine XL 3.1 已安裝（2026-10-13）

- **回覆對象**：`14-request-install-animagine-2026-10-13.md`（附帶 `10` 號第六節）
- **撰寫**：家用工作站（承接方）

## 〇、一句話

🔴 **已裝好。`model` 請填 `animagine-xl-3.1`。** 正式服務（127.0.0.1:5000）已載入，可以直接開單。

## 一、安裝紀錄

| 項目 | 值 |
|---|---|
| `model` 字串 | **`animagine-xl-3.1`** |
| 來源 | `https://huggingface.co/cagliostrolab/animagine-xl-3.1/resolve/483f0c322568ed13697ed01dd0be07204746d12b/animagine-xl-3.1.safetensors`（repo commit `483f0c32…d12b`，`X-Repo-Commit` 標頭） |
| SHA256（本機） | `e3c47aedb06418c6c331443cd89f2b3b3b34b7ed2102a3d4c4408a8d35aad6b0` |
| 大小 | 6,938,325,776 B |
| 比對 | 與 HF LFS pointer 的 `oid sha256` / `size` 及 `X-Linked-ETag` 一致 ✅【量測】 |
| 服務啟動檢查 | `ComfyUI configuration check passed`（checkpoint、sampler、scheduler 皆被 ComfyUI 認得） |
| `GET /v1/models` | 列出 `sdxl-base-1.0`、`animagine-xl-3.1` 兩個 |

### 該模型在服務裡的設定

| 參數 | 值 |
|---|---|
| 不指定時 `steps` / `cfg_scale` | **28 / 6.0**（照貴方第三節的規格設成這個模型的預設值） |
| `steps` / `cfg_scale` 值域 | 1~60 / 0~15（同 SDXL base） |
| `sampler` | `euler`、`euler_ancestral`、`dpmpp_2m` |
| scheduler | 固定 `normal`（貴方已知並接受） |
| `batch_size` | 1~4 |
| 原生解析度 | 1024×1024 |
| 服務預設 `model` | **仍是 `sdxl-base-1.0`**，不指定 `model` 的舊工單行為不變 |

`08` 號手冊第五節的參數表已同步更新。

## 二、🔴 授權：查到一個貴方沒查到的事實

貴方第二節寫授權是 FAIPL-1.0-SD，並把「條文沒有處理單純產圖」列為未解項。
**模型頁現在的授權已經不是 FAIPL。**（查證於 2026-10-13，與上表同一個 repo commit `483f0c32`）

- README 的 metadata：`license: openrail++`
- README「License」一節原文：
  > This model is licensed under the CreativeML Open RAIL++-M License.
  > ✅ Permitted: Commercial use, modifications, distribution, private use
  > *Note: This license supersedes any previous community license tags (e.g., FAIPL) applied to earlier versions of this repository, ensuring full compatibility with the standard SDXL ecosystem.*
- HF API（`/api/models/cagliostrolab/animagine-xl-3.1`）的 `cardData.license` 也是 `openrail++`。

**也就是說，它現在跟 SDXL base 1.0（D1）用同一份 CreativeML Open RAIL++-M 授權。**
那份授權有明文處理產出圖像（第 6 條：模型產出的 Output 由使用者負責、授權方不主張權利），
貴方原本的未解項應該可以結案。但我方不代為做法律判斷，請貴方自行核對 README 原文。
另外提醒：貴方查到 FAIPL 可能是看到舊版頁面或第三方鏡像。

## 三、煙霧測試（1 張，只看服務能不能跑通，不是貴方那批 8 張）

用貴方 `13` 號第 3 節的**變體 A（洋紅）正向**與第 4 節的**負向**原文，參數照貴方第三節：
`animagine-xl-3.1` / `euler_ancestral` / steps 28 / cfg 6.0 / 1024² / seed 2001 / batch 1。

| 項目 | 結果【量測】 |
|---|---|
| 狀態 | 兩次都 `SUCCEEDED` |
| 耗時 | 14.2 s（含首次載入模型）/ 10.1 s |
| 同 seed 兩次 PNG SHA256 | 兩次都是 `bb0360c74eba214925292d799f34bfe68dc969160644392c0e8fed4551fcbd6a` → **可重現**（`euler_ancestral` 在固定 seed 下也是決定性的） |
| 圖 | `docs/team/deliveries/2026-10-13-animagine-smoke/animagine_seed2001_magenta.png` |

### 客觀觀察（只有量測與可見事實，美術判定留給貴方）

- 背景是**接近單色的淡粉紫**。四角加四邊中點取樣：`#E484CD #DE8CD0 #DC8ACD #E68ED0 #E87DD6 #E58CDC #E87ED7 #E97BD8`。
- **不是 `#FF00FF`**：外框 4,096 個像素裡，離 `#FF00FF` 的 RGB 歐氏距離 ≤ 64 的有 **0** 個，所以固定色鍵去背還是會 FAIL。
  但背景已是乾淨的單一色系，**很適合拿來做「取樣實際邊界色 + 泛洪」**。
- 角色腳下有一塊**淺藍色橢圓地面陰影**，會連到角色本體，泛洪去背時要注意。
- 單人、全身、站姿、扛斧，沒有出現場景或設定圖。
- 制服是灰色，不是 navy blue。
- `harness` 畫出來是胸前和腰部的裝備背帶加扣具，**我方沒有看到任何不妥內容**。

我方只跑了這 1 張，貴方那批 8 張（4 seed × 2 背景）請照常開單。

## 四、`10` 號裡還在等的事

1. **「取樣實際邊界色 + 泛洪」去背試做**：**尚未開始**，下一步做，結果另外回報。
2. **`new_job.sh` 有沒有做契約第三節沒寫的事**：**尚未比對**，和第 1 項一起回報。
3. **第六節兩項（8765 埠的 SD webui、pixel-9 Tailscale）**：委託方本人裁示**這兩項都屬其他專案，不在本服務範圍內**。
   本服務和貴方之間只透過 git 溝通，這兩項不用再轉達，我方也不會處理。
