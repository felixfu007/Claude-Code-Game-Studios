# 家用端 2026-10-13 交付物(本機副本)

**這不是試作,是外部交付物的本機副本。** 放在 `prototypes/` 只因為它是拋棄式的
查閱用素材,不屬於 `assets/`(不是遊戲資源)也不屬於 `docs/`(是二進位圖檔)。

## 來源

`https://github.com/felixfu007/AI_IMG`,commit `0ed9b2e`(2026-10-13T13:55:42Z)。
取法:`gh api repos/felixfu007/AI_IMG/contents/<path>?ref=0ed9b2e --jq .download_url | xargs curl -sL -o`

**權威來源是 AI_IMG 倉庫,不是這份副本。** 本副本只為了讓 `art-director`
不必連外就能開全解析度原圖判定。

## 檔案

| 檔案 | 是什麼 |
|---|---|
| `animagine_seed2001_magenta.png` | 🔴 **新底模 Animagine XL 3.1 的第一張實跑圖**(1024²,seed 2001,變體 A 洋紅)。換底模成敗的判準就是這張 |
| `animagine_seed2001_magenta_preview_tol32.png` | 同一張的去背前後對照(左原圖、右去背結果疊綠底) |
| `animagine_seed2001_32x40_x10_preview.png` | 🔴 **本專案第一張跑完整條後製管線的 32×40 成品**(放大 10 倍、灰底) |
| `animagine_seed2001_32x40.png` | 同上,原尺寸 |
| `animagine_seed2001_32x40_check_report.json` | 上圖的機械檢查報告(四項硬性檢查全過) |
| `regions_animagine_seed2001.json` | 上圖用的「描邊區域」檔 —— 四個矩形,臉/腿=`skin`、斧柄/斧頭=`metal` |
| `stats_tol32.json` | 8 張舊 SDXL 圖的邊界取樣去背統計(每張的 8 個樣本色、分群、色鍵、比例) |
| `styleA_seed2003_preview_tol32.png` | 舊 SDXL 圖的去背對照,供與新底模比較 |

## 對應文件

- `docs/ai-art-service-handoff/14-request-install-animagine-2026-10-13-report.md`
- `docs/ai-art-service-handoff/10-cr001-calibration-round1-reply-2026-10-13-report.md`
- `docs/ai-art-service-handoff/15-postprocess-key-from-edges-2026-10-13.md`
