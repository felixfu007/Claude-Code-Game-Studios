# Kenney 音效包盤點(2026-11-10)

> 只下載與盤點,**未放進專案、未修改專案任何檔案**。每包各自一個全新資料夾 `C:/tmp/kenney-dl/<包名>/`(zip 本體 + `extracted/`)。只解壓縮,未執行包內任何檔案。
> 解壓前已用 `unzip -Z1` 檢查:五包皆無絕對路徑或 `..` 路徑。
> 時長:**本機沒有 ffprobe**(`command -v ffprobe` 無輸出),依指示未安裝,故不列時長。
> 不判斷好不好聽。

## 下載方式(從頁面 HTML 讀出,非猜測)

商店頁 HTML 裡沒有直接的 `.zip` 連結。下載按鈕是 `<a ... data-download-id='<hex>' onclick='return initiateDownload(this)'>`,而頁面內的 `initiateDownload()` 會 `fetch('https://kenney.nl/download-link/' + _id)`,取回 JSON 的 `url` 欄(帶 `expires` 的簽名網址)再導向。以下照這個流程做:先 GET 商店頁(存 cookie)→ GET `download-link/<id>` → GET 回傳的簽名網址。伺服器回應皆為 `Content-Type: application/zip`。

## 總表

| 包 | 結果 | 商店頁「Files」 | 實際 .ogg 數 | 格式 | 非音檔 | 授權欄 vs 包內授權檔 |
|---|---|---|---|---|---|---|
| ui-audio | 成功 | 50× | 52 | 全為 .ogg | 3 | 一致(皆 CC0) |
| interface-sounds | 成功 | 100× | 100 | 全為 .ogg | 3 | 一致(皆 CC0) |
| rpg-audio | 成功 | 50× | 52 | 全為 .ogg | 3 | 一致(皆 CC0) |
| music-jingles | 成功 | 85× | 86 | 全為 .ogg | 3 | 一致(皆 CC0) |
| digital-audio | 成功 | 60× | 63 | 全為 .ogg | 4 | 一致(皆 CC0) |

⚠️ **商店頁的「Files」數與包內實際 .ogg 數有四包對不上**(ui-audio 50 vs 52、rpg-audio 50 vs 52、music-jingles 85 vs 86、digital-audio 60 vs 63;interface-sounds 100 vs 100 相符)。成因未查,只登記。

---

## 包:ui-audio

- 商店頁:https://kenney.nl/assets/ui-audio
- download-link 端點:`https://kenney.nl/download-link/6173736574732f75692d617564696f`
- 實際下載網址(簽名,帶期限):`https://kenney.nl/download/6173736574732f75692d617564696f/39f788caf7bfb1d6221ef60e6b1156e76cbe529b9bad28d2517041bdb1c141a1?expires=1794282813`
- 伺服器給的檔名:`kenney_ui-audio.zip`;本地存為 `C:/tmp/kenney-dl/ui-audio/ui-audio.zip`(411949 bytes)
- SHA256:`946fc23a63d535d693eb31b2eabb80c8c28d6351e2186b344ceb71b2cb1d5eb6`
- 下載時間:2026-11-10 11:49:13 +0800

### 商店頁授權欄原文(HTML 原始碼,逐字)

```html
<td class='title text-muted'>License</td>
<td class='bold'><a href='https://creativecommons.org/publicdomain/zero/1.0/' target='_blank'>Creative Commons CC0</a></td>
</tr>
```
(頁面另有 og:description 逐字:`Download this package (50 assets) for free, CC0 licensed!`)

### 包內 License.txt 全文(逐字;原檔為 CRLF、行首 Tab,此處保留 Tab)

```text
	

	UI SFX Set

	by  Kenney Vleugels (Kenney.nl)

			------------------------------

	License (Creative Commons Zero, CC0)
	http://creativecommons.org/publicdomain/zero/1.0/

	You may use these assets in personal and commercial projects.
	Credit (Kenney or www.kenney.nl) would be nice but is not mandatory.

			------------------------------

	Donate:   http://support.kenney.nl
	Request:  http://request.kenney.nl

	Follow on Twitter for updates:
	@KenneyNL
```

**比對**:商店頁寫 CC0(連到 creativecommons.org/publicdomain/zero/1.0/),包內 License.txt 寫 "Creative Commons Zero, CC0" 同一網址(http vs https)→ **一致**。包內另寫「署名非必要」,商店頁授權欄無此文字,不構成衝突。

### 非音檔

- `License.txt`(479 bytes)
- `Visit Kenney.url`(45 bytes)
- `Visit Patreon.url`(55 bytes)
  - `.url` 為 Windows 網址捷徑,內容僅 `URL=http://www.kenney.nl/` 或 `URL=https://www.patreon.com/kenney/`(已以文字讀出,未開啟)。

### 音檔清單(52 個)

| 相對路徑(相對 `extracted/`) | 格式 | 大小(bytes) |
|---|---|---|
| `Audio/click1.ogg` | ogg | 4983 |
| `Audio/click2.ogg` | ogg | 4656 |
| `Audio/click3.ogg` | ogg | 4880 |
| `Audio/click4.ogg` | ogg | 4558 |
| `Audio/click5.ogg` | ogg | 4532 |
| `Audio/mouseclick1.ogg` | ogg | 4686 |
| `Audio/mouserelease1.ogg` | ogg | 4775 |
| `Audio/rollover1.ogg` | ogg | 5932 |
| `Audio/rollover2.ogg` | ogg | 4701 |
| `Audio/rollover3.ogg` | ogg | 4778 |
| `Audio/rollover4.ogg` | ogg | 5188 |
| `Audio/rollover5.ogg` | ogg | 5258 |
| `Audio/rollover6.ogg` | ogg | 5385 |
| `Audio/switch1.ogg` | ogg | 6104 |
| `Audio/switch10.ogg` | ogg | 6456 |
| `Audio/switch11.ogg` | ogg | 6248 |
| `Audio/switch12.ogg` | ogg | 4588 |
| `Audio/switch13.ogg` | ogg | 4467 |
| `Audio/switch14.ogg` | ogg | 4522 |
| `Audio/switch15.ogg` | ogg | 6325 |
| `Audio/switch16.ogg` | ogg | 6991 |
| `Audio/switch17.ogg` | ogg | 6686 |
| `Audio/switch18.ogg` | ogg | 7633 |
| `Audio/switch19.ogg` | ogg | 7177 |
| `Audio/switch2.ogg` | ogg | 6042 |
| `Audio/switch20.ogg` | ogg | 6965 |
| `Audio/switch21.ogg` | ogg | 7453 |
| `Audio/switch22.ogg` | ogg | 7116 |
| `Audio/switch23.ogg` | ogg | 7177 |
| `Audio/switch24.ogg` | ogg | 6340 |
| `Audio/switch25.ogg` | ogg | 7130 |
| `Audio/switch26.ogg` | ogg | 6031 |
| `Audio/switch27.ogg` | ogg | 6445 |
| `Audio/switch28.ogg` | ogg | 5916 |
| `Audio/switch29.ogg` | ogg | 6769 |
| `Audio/switch3.ogg` | ogg | 6270 |
| `Audio/switch30.ogg` | ogg | 7151 |
| `Audio/switch31.ogg` | ogg | 8180 |
| `Audio/switch32.ogg` | ogg | 7868 |
| `Audio/switch33.ogg` | ogg | 8530 |
| `Audio/switch34.ogg` | ogg | 7910 |
| `Audio/switch35.ogg` | ogg | 6935 |
| `Audio/switch36.ogg` | ogg | 6616 |
| `Audio/switch37.ogg` | ogg | 6822 |
| `Audio/switch38.ogg` | ogg | 7303 |
| `Audio/switch4.ogg` | ogg | 6477 |
| `Audio/switch5.ogg` | ogg | 6181 |
| `Audio/switch6.ogg` | ogg | 6610 |
| `Audio/switch7.ogg` | ogg | 5707 |
| `Audio/switch8.ogg` | ogg | 6253 |
| `Audio/switch9.ogg` | ogg | 6009 |
| `Preview.ogg` | ogg | 171143 |

---

## 包:interface-sounds

- 商店頁:https://kenney.nl/assets/interface-sounds
- download-link 端點:`https://kenney.nl/download-link/6173736574732f696e746572666163652d736f756e6473`
- 實際下載網址(簽名,帶期限):`https://kenney.nl/download/6173736574732f696e746572666163652d736f756e6473/38ea8d3715382ac9f9da1d87ce1ebbb9a8294fd5d5ef796a8beac098f8dde330?expires=1794282819`
- 伺服器給的檔名:`kenney_interface-sounds.zip`;本地存為 `C:/tmp/kenney-dl/interface-sounds/interface-sounds.zip`(834536 bytes)
- SHA256:`f2193d072726d6758a5f7871b2dcc54dcce0d5c35c6f0a62f92549b327c81232`
- 下載時間:2026-11-10 11:49:20 +0800

### 商店頁授權欄原文(HTML 原始碼,逐字)

```html
<td class='title text-muted'>License</td>
<td class='bold'><a href='https://creativecommons.org/publicdomain/zero/1.0/' target='_blank'>Creative Commons CC0</a></td>
</tr>
```
(頁面另有 og:description 逐字:`Download this package (100 assets) for free, CC0 licensed!`)

### 包內 License.txt 全文(逐字;原檔為 CRLF、行首 Tab,此處保留 Tab)

```text
	

	Interface Sounds (1.0)

	Created/distributed by Kenney (www.kenney.nl)
	Creation date: 11-02-2020

			------------------------------

	License: (Creative Commons Zero, CC0)
	http://creativecommons.org/publicdomain/zero/1.0/

	This content is free to use in personal, educational and commercial projects.
	Support us by crediting Kenney or www.kenney.nl (this is not mandatory)

			------------------------------

	Donate:   http://support.kenney.nl
	Patreon:  http://patreon.com/kenney/

	Follow on Twitter for updates:
	http://twitter.com/KenneyNL
```

**比對**:商店頁寫 CC0(連到 creativecommons.org/publicdomain/zero/1.0/),包內 License.txt 寫 "Creative Commons Zero, CC0" 同一網址(http vs https)→ **一致**。包內另寫「署名非必要」,商店頁授權欄無此文字,不構成衝突。

### 非音檔

- `Kenney.url`(45 bytes)
- `License.txt`(574 bytes)
- `Patreon.url`(55 bytes)
  - `.url` 為 Windows 網址捷徑,內容僅 `URL=http://www.kenney.nl/` 或 `URL=https://www.patreon.com/kenney/`(已以文字讀出,未開啟)。

### 音檔清單(100 個)

| 相對路徑(相對 `extracted/`) | 格式 | 大小(bytes) |
|---|---|---|
| `Audio/back_001.ogg` | ogg | 6997 |
| `Audio/back_002.ogg` | ogg | 7029 |
| `Audio/back_003.ogg` | ogg | 7208 |
| `Audio/back_004.ogg` | ogg | 6923 |
| `Audio/bong_001.ogg` | ogg | 4848 |
| `Audio/click_001.ogg` | ogg | 4876 |
| `Audio/click_002.ogg` | ogg | 4275 |
| `Audio/click_003.ogg` | ogg | 4371 |
| `Audio/click_004.ogg` | ogg | 4486 |
| `Audio/click_005.ogg` | ogg | 4410 |
| `Audio/close_001.ogg` | ogg | 9915 |
| `Audio/close_002.ogg` | ogg | 14752 |
| `Audio/close_003.ogg` | ogg | 15648 |
| `Audio/close_004.ogg` | ogg | 16263 |
| `Audio/confirmation_001.ogg` | ogg | 8968 |
| `Audio/confirmation_002.ogg` | ogg | 14169 |
| `Audio/confirmation_003.ogg` | ogg | 9535 |
| `Audio/confirmation_004.ogg` | ogg | 12391 |
| `Audio/drop_001.ogg` | ogg | 5859 |
| `Audio/drop_002.ogg` | ogg | 6411 |
| `Audio/drop_003.ogg` | ogg | 6288 |
| `Audio/drop_004.ogg` | ogg | 7230 |
| `Audio/error_001.ogg` | ogg | 7373 |
| `Audio/error_002.ogg` | ogg | 7369 |
| `Audio/error_003.ogg` | ogg | 12256 |
| `Audio/error_004.ogg` | ogg | 6393 |
| `Audio/error_005.ogg` | ogg | 7266 |
| `Audio/error_006.ogg` | ogg | 8288 |
| `Audio/error_007.ogg` | ogg | 10225 |
| `Audio/error_008.ogg` | ogg | 9215 |
| `Audio/glass_001.ogg` | ogg | 6103 |
| `Audio/glass_002.ogg` | ogg | 4917 |
| `Audio/glass_003.ogg` | ogg | 5732 |
| `Audio/glass_004.ogg` | ogg | 8323 |
| `Audio/glass_005.ogg` | ogg | 6206 |
| `Audio/glass_006.ogg` | ogg | 6956 |
| `Audio/glitch_001.ogg` | ogg | 5121 |
| `Audio/glitch_002.ogg` | ogg | 5473 |
| `Audio/glitch_003.ogg` | ogg | 4915 |
| `Audio/glitch_004.ogg` | ogg | 5225 |
| `Audio/maximize_001.ogg` | ogg | 12111 |
| `Audio/maximize_002.ogg` | ogg | 9915 |
| `Audio/maximize_003.ogg` | ogg | 11748 |
| `Audio/maximize_004.ogg` | ogg | 17723 |
| `Audio/maximize_005.ogg` | ogg | 20900 |
| `Audio/maximize_006.ogg` | ogg | 11618 |
| `Audio/maximize_007.ogg` | ogg | 8097 |
| `Audio/maximize_008.ogg` | ogg | 9085 |
| `Audio/maximize_009.ogg` | ogg | 7650 |
| `Audio/minimize_001.ogg` | ogg | 11924 |
| `Audio/minimize_002.ogg` | ogg | 9441 |
| `Audio/minimize_003.ogg` | ogg | 11739 |
| `Audio/minimize_004.ogg` | ogg | 17099 |
| `Audio/minimize_005.ogg` | ogg | 19501 |
| `Audio/minimize_006.ogg` | ogg | 11292 |
| `Audio/minimize_007.ogg` | ogg | 7677 |
| `Audio/minimize_008.ogg` | ogg | 9298 |
| `Audio/minimize_009.ogg` | ogg | 7665 |
| `Audio/open_001.ogg` | ogg | 9834 |
| `Audio/open_002.ogg` | ogg | 14975 |
| `Audio/open_003.ogg` | ogg | 15046 |
| `Audio/open_004.ogg` | ogg | 15879 |
| `Audio/pluck_001.ogg` | ogg | 6317 |
| `Audio/pluck_002.ogg` | ogg | 6941 |
| `Audio/question_001.ogg` | ogg | 11700 |
| `Audio/question_002.ogg` | ogg | 9455 |
| `Audio/question_003.ogg` | ogg | 8233 |
| `Audio/question_004.ogg` | ogg | 9821 |
| `Audio/scratch_001.ogg` | ogg | 8989 |
| `Audio/scratch_002.ogg` | ogg | 9319 |
| `Audio/scratch_003.ogg` | ogg | 8849 |
| `Audio/scratch_004.ogg` | ogg | 16478 |
| `Audio/scratch_005.ogg` | ogg | 15824 |
| `Audio/scroll_001.ogg` | ogg | 21633 |
| `Audio/scroll_002.ogg` | ogg | 24628 |
| `Audio/scroll_003.ogg` | ogg | 29488 |
| `Audio/scroll_004.ogg` | ogg | 20348 |
| `Audio/scroll_005.ogg` | ogg | 20448 |
| `Audio/select_001.ogg` | ogg | 5468 |
| `Audio/select_002.ogg` | ogg | 5463 |
| `Audio/select_003.ogg` | ogg | 6901 |
| `Audio/select_004.ogg` | ogg | 6909 |
| `Audio/select_005.ogg` | ogg | 6767 |
| `Audio/select_006.ogg` | ogg | 8101 |
| `Audio/select_007.ogg` | ogg | 6580 |
| `Audio/select_008.ogg` | ogg | 6339 |
| `Audio/switch_001.ogg` | ogg | 6753 |
| `Audio/switch_002.ogg` | ogg | 7097 |
| `Audio/switch_003.ogg` | ogg | 9653 |
| `Audio/switch_004.ogg` | ogg | 7248 |
| `Audio/switch_005.ogg` | ogg | 7814 |
| `Audio/switch_006.ogg` | ogg | 7873 |
| `Audio/switch_007.ogg` | ogg | 7921 |
| `Audio/tick_001.ogg` | ogg | 4497 |
| `Audio/tick_002.ogg` | ogg | 4514 |
| `Audio/tick_004.ogg` | ogg | 5031 |
| `Audio/toggle_001.ogg` | ogg | 7369 |
| `Audio/toggle_002.ogg` | ogg | 8056 |
| `Audio/toggle_003.ogg` | ogg | 8654 |
| `Audio/toggle_004.ogg` | ogg | 6695 |

---

## 包:rpg-audio

- 商店頁:https://kenney.nl/assets/rpg-audio
- download-link 端點:`https://kenney.nl/download-link/6173736574732f7270672d617564696f`
- 實際下載網址(簽名,帶期限):`https://kenney.nl/download/6173736574732f7270672d617564696f/17770afb352a183fcb466550ede90e423617f486e4f1e6c7b90b36d8f610e400?expires=1794282824`
- 伺服器給的檔名:`kenney_rpg-audio.zip`;本地存為 `C:/tmp/kenney-dl/rpg-audio/rpg-audio.zip`(964837 bytes)
- SHA256:`6dbeaf8544da958d8f2adcb4a4a4b76c1ade34a05f8ab9edccd327da7375f38b`
- 下載時間:2026-11-10 11:49:26 +0800

### 商店頁授權欄原文(HTML 原始碼,逐字)

```html
<td class='title text-muted'>License</td>
<td class='bold'><a href='https://creativecommons.org/publicdomain/zero/1.0/' target='_blank'>Creative Commons CC0</a></td>
</tr>
```
(頁面另有 og:description 逐字:`Download this package (50 assets) for free, CC0 licensed!`)

### 包內 License.txt 全文(逐字;原檔為 CRLF、行首 Tab,此處保留 Tab)

```text
	

	RPG Audio

	by  Kenney Vleugels (Kenney.nl)

			------------------------------

	License (Creative Commons Zero, CC0)
	http://creativecommons.org/publicdomain/zero/1.0/

	You may use these assets in personal and commercial projects.
	Credit (Kenney or www.kenney.nl) would be nice but is not mandatory.

			------------------------------

	Donate:   http://support.kenney.nl
	Request:  http://request.kenney.nl

	Follow on Twitter for updates:
	@KenneyNL
```

**比對**:商店頁寫 CC0(連到 creativecommons.org/publicdomain/zero/1.0/),包內 License.txt 寫 "Creative Commons Zero, CC0" 同一網址(http vs https)→ **一致**。包內另寫「署名非必要」,商店頁授權欄無此文字,不構成衝突。

### 非音檔

- `License.txt`(478 bytes)
- `Visit Kenney.url`(45 bytes)
- `Visit Patreon.url`(55 bytes)
  - `.url` 為 Windows 網址捷徑,內容僅 `URL=http://www.kenney.nl/` 或 `URL=https://www.patreon.com/kenney/`(已以文字讀出,未開啟)。

### 音檔清單(52 個)

| 相對路徑(相對 `extracted/`) | 格式 | 大小(bytes) |
|---|---|---|
| `Audio/beltHandle1.ogg` | ogg | 10820 |
| `Audio/beltHandle2.ogg` | ogg | 15410 |
| `Audio/bookClose.ogg` | ogg | 9292 |
| `Audio/bookFlip1.ogg` | ogg | 18248 |
| `Audio/bookFlip2.ogg` | ogg | 12393 |
| `Audio/bookFlip3.ogg` | ogg | 9077 |
| `Audio/bookOpen.ogg` | ogg | 8273 |
| `Audio/bookPlace1.ogg` | ogg | 9901 |
| `Audio/bookPlace2.ogg` | ogg | 11185 |
| `Audio/bookPlace3.ogg` | ogg | 9570 |
| `Audio/chop.ogg` | ogg | 9370 |
| `Audio/cloth1.ogg` | ogg | 16508 |
| `Audio/cloth2.ogg` | ogg | 11787 |
| `Audio/cloth3.ogg` | ogg | 12432 |
| `Audio/cloth4.ogg` | ogg | 11043 |
| `Audio/clothBelt.ogg` | ogg | 21491 |
| `Audio/clothBelt2.ogg` | ogg | 20013 |
| `Audio/creak1.ogg` | ogg | 15761 |
| `Audio/creak2.ogg` | ogg | 19012 |
| `Audio/creak3.ogg` | ogg | 10408 |
| `Audio/doorClose_1.ogg` | ogg | 18564 |
| `Audio/doorClose_2.ogg` | ogg | 17598 |
| `Audio/doorClose_3.ogg` | ogg | 20889 |
| `Audio/doorClose_4.ogg` | ogg | 16902 |
| `Audio/doorOpen_1.ogg` | ogg | 22848 |
| `Audio/doorOpen_2.ogg` | ogg | 30280 |
| `Audio/drawKnife1.ogg` | ogg | 11134 |
| `Audio/drawKnife2.ogg` | ogg | 12395 |
| `Audio/drawKnife3.ogg` | ogg | 12726 |
| `Audio/dropLeather.ogg` | ogg | 11695 |
| `Audio/footstep00.ogg` | ogg | 9475 |
| `Audio/footstep01.ogg` | ogg | 9900 |
| `Audio/footstep02.ogg` | ogg | 9528 |
| `Audio/footstep03.ogg` | ogg | 10559 |
| `Audio/footstep04.ogg` | ogg | 11303 |
| `Audio/footstep05.ogg` | ogg | 10288 |
| `Audio/footstep06.ogg` | ogg | 9885 |
| `Audio/footstep07.ogg` | ogg | 10264 |
| `Audio/footstep08.ogg` | ogg | 9242 |
| `Audio/footstep09.ogg` | ogg | 9356 |
| `Audio/handleCoins.ogg` | ogg | 25394 |
| `Audio/handleCoins2.ogg` | ogg | 13094 |
| `Audio/handleSmallLeather.ogg` | ogg | 10492 |
| `Audio/handleSmallLeather2.ogg` | ogg | 10028 |
| `Audio/knifeSlice.ogg` | ogg | 15532 |
| `Audio/knifeSlice2.ogg` | ogg | 15099 |
| `Audio/metalClick.ogg` | ogg | 13615 |
| `Audio/metalLatch.ogg` | ogg | 10208 |
| `Audio/metalPot1.ogg` | ogg | 31619 |
| `Audio/metalPot2.ogg` | ogg | 22471 |
| `Audio/metalPot3.ogg` | ogg | 23142 |
| `Preview.ogg` | ogg | 321120 |

---

## 包:music-jingles

- 商店頁:https://kenney.nl/assets/music-jingles
- download-link 端點:`https://kenney.nl/download-link/6173736574732f6d757369632d6a696e676c6573`
- 實際下載網址(簽名,帶期限):`https://kenney.nl/download/6173736574732f6d757369632d6a696e676c6573/4f662adb000174f87a82593350a47553cb5117fd7bc84f9c174703a21740b7c5?expires=1794282828`
- 伺服器給的檔名:`kenney_music-jingles.zip`;本地存為 `C:/tmp/kenney-dl/music-jingles/music-jingles.zip`(1239525 bytes)
- SHA256:`b729ba57959bd58793d2c5cafa348aaf2655d354f3da35ec4729e03ec77197b8`
- 下載時間:2026-11-10 11:49:33 +0800

### 商店頁授權欄原文(HTML 原始碼,逐字)

```html
<td class='title text-muted'>License</td>
<td class='bold'><a href='https://creativecommons.org/publicdomain/zero/1.0/' target='_blank'>Creative Commons CC0</a></td>
</tr>
```
(頁面另有 og:description 逐字:`Download this package (85 assets) for free, CC0 licensed!`)

### 包內 License.txt 全文(逐字;原檔為 CRLF、行首 Tab,此處保留 Tab)

```text
	

	Music Jingles

	by  Kenney Vleugels (Kenney.nl)

			------------------------------

	License (Creative Commons Zero, CC0)
	http://creativecommons.org/publicdomain/zero/1.0/

	You may use these assets in personal and commercial projects.
	Credit (Kenney or www.kenney.nl) would be nice but is not mandatory.

			------------------------------

	Donate:   http://support.kenney.nl
	Request:  http://request.kenney.nl

	Follow on Twitter for updates:
	@KenneyNL
```

**比對**:商店頁寫 CC0(連到 creativecommons.org/publicdomain/zero/1.0/),包內 License.txt 寫 "Creative Commons Zero, CC0" 同一網址(http vs https)→ **一致**。包內另寫「署名非必要」,商店頁授權欄無此文字,不構成衝突。

### 非音檔

- `License.txt`(482 bytes)
- `Visit Kenney.url`(45 bytes)
- `Visit Patreon.url`(55 bytes)
  - `.url` 為 Windows 網址捷徑,內容僅 `URL=http://www.kenney.nl/` 或 `URL=https://www.patreon.com/kenney/`(已以文字讀出,未開啟)。

### 音檔清單(86 個)

| 相對路徑(相對 `extracted/`) | 格式 | 大小(bytes) |
|---|---|---|
| `Audio/8-Bit jingles/jingles_NES00.ogg` | ogg | 39948 |
| `Audio/8-Bit jingles/jingles_NES01.ogg` | ogg | 11758 |
| `Audio/8-Bit jingles/jingles_NES02.ogg` | ogg | 11743 |
| `Audio/8-Bit jingles/jingles_NES03.ogg` | ogg | 16573 |
| `Audio/8-Bit jingles/jingles_NES04.ogg` | ogg | 16796 |
| `Audio/8-Bit jingles/jingles_NES05.ogg` | ogg | 21439 |
| `Audio/8-Bit jingles/jingles_NES06.ogg` | ogg | 19138 |
| `Audio/8-Bit jingles/jingles_NES07.ogg` | ogg | 18971 |
| `Audio/8-Bit jingles/jingles_NES08.ogg` | ogg | 16534 |
| `Audio/8-Bit jingles/jingles_NES09.ogg` | ogg | 11934 |
| `Audio/8-Bit jingles/jingles_NES10.ogg` | ogg | 12001 |
| `Audio/8-Bit jingles/jingles_NES11.ogg` | ogg | 21177 |
| `Audio/8-Bit jingles/jingles_NES12.ogg` | ogg | 21202 |
| `Audio/8-Bit jingles/jingles_NES13.ogg` | ogg | 25177 |
| `Audio/8-Bit jingles/jingles_NES14.ogg` | ogg | 11717 |
| `Audio/8-Bit jingles/jingles_NES15.ogg` | ogg | 11849 |
| `Audio/8-Bit jingles/jingles_NES16.ogg` | ogg | 14057 |
| `Audio/Hit jingles/jingles_HIT00.ogg` | ogg | 8650 |
| `Audio/Hit jingles/jingles_HIT01.ogg` | ogg | 11681 |
| `Audio/Hit jingles/jingles_HIT02.ogg` | ogg | 11735 |
| `Audio/Hit jingles/jingles_HIT03.ogg` | ogg | 13944 |
| `Audio/Hit jingles/jingles_HIT04.ogg` | ogg | 11424 |
| `Audio/Hit jingles/jingles_HIT05.ogg` | ogg | 13868 |
| `Audio/Hit jingles/jingles_HIT06.ogg` | ogg | 11854 |
| `Audio/Hit jingles/jingles_HIT07.ogg` | ogg | 8707 |
| `Audio/Hit jingles/jingles_HIT08.ogg` | ogg | 8613 |
| `Audio/Hit jingles/jingles_HIT09.ogg` | ogg | 15477 |
| `Audio/Hit jingles/jingles_HIT10.ogg` | ogg | 15019 |
| `Audio/Hit jingles/jingles_HIT11.ogg` | ogg | 17932 |
| `Audio/Hit jingles/jingles_HIT12.ogg` | ogg | 8666 |
| `Audio/Hit jingles/jingles_HIT13.ogg` | ogg | 8577 |
| `Audio/Hit jingles/jingles_HIT14.ogg` | ogg | 10099 |
| `Audio/Hit jingles/jingles_HIT15.ogg` | ogg | 19626 |
| `Audio/Hit jingles/jingles_HIT16.ogg` | ogg | 8445 |
| `Audio/Pizzicato jingles/jingles_PIZZI00.ogg` | ogg | 10382 |
| `Audio/Pizzicato jingles/jingles_PIZZI01.ogg` | ogg | 16579 |
| `Audio/Pizzicato jingles/jingles_PIZZI02.ogg` | ogg | 16360 |
| `Audio/Pizzicato jingles/jingles_PIZZI03.ogg` | ogg | 16981 |
| `Audio/Pizzicato jingles/jingles_PIZZI04.ogg` | ogg | 11052 |
| `Audio/Pizzicato jingles/jingles_PIZZI05.ogg` | ogg | 10291 |
| `Audio/Pizzicato jingles/jingles_PIZZI06.ogg` | ogg | 11867 |
| `Audio/Pizzicato jingles/jingles_PIZZI07.ogg` | ogg | 19137 |
| `Audio/Pizzicato jingles/jingles_PIZZI08.ogg` | ogg | 10825 |
| `Audio/Pizzicato jingles/jingles_PIZZI09.ogg` | ogg | 10872 |
| `Audio/Pizzicato jingles/jingles_PIZZI10.ogg` | ogg | 14004 |
| `Audio/Pizzicato jingles/jingles_PIZZI11.ogg` | ogg | 13830 |
| `Audio/Pizzicato jingles/jingles_PIZZI12.ogg` | ogg | 15969 |
| `Audio/Pizzicato jingles/jingles_PIZZI13.ogg` | ogg | 14644 |
| `Audio/Pizzicato jingles/jingles_PIZZI14.ogg` | ogg | 15212 |
| `Audio/Pizzicato jingles/jingles_PIZZI15.ogg` | ogg | 13905 |
| `Audio/Pizzicato jingles/jingles_PIZZI16.ogg` | ogg | 10201 |
| `Audio/Sax jingles/jingles_SAX00.ogg` | ogg | 10335 |
| `Audio/Sax jingles/jingles_SAX01.ogg` | ogg | 17409 |
| `Audio/Sax jingles/jingles_SAX02.ogg` | ogg | 17112 |
| `Audio/Sax jingles/jingles_SAX03.ogg` | ogg | 19785 |
| `Audio/Sax jingles/jingles_SAX04.ogg` | ogg | 9786 |
| `Audio/Sax jingles/jingles_SAX05.ogg` | ogg | 10183 |
| `Audio/Sax jingles/jingles_SAX06.ogg` | ogg | 11167 |
| `Audio/Sax jingles/jingles_SAX07.ogg` | ogg | 30900 |
| `Audio/Sax jingles/jingles_SAX08.ogg` | ogg | 9989 |
| `Audio/Sax jingles/jingles_SAX09.ogg` | ogg | 10023 |
| `Audio/Sax jingles/jingles_SAX10.ogg` | ogg | 13565 |
| `Audio/Sax jingles/jingles_SAX11.ogg` | ogg | 13737 |
| `Audio/Sax jingles/jingles_SAX12.ogg` | ogg | 16903 |
| `Audio/Sax jingles/jingles_SAX13.ogg` | ogg | 15654 |
| `Audio/Sax jingles/jingles_SAX14.ogg` | ogg | 15119 |
| `Audio/Sax jingles/jingles_SAX15.ogg` | ogg | 13560 |
| `Audio/Sax jingles/jingles_SAX16.ogg` | ogg | 10588 |
| `Audio/Steel jingles/jingles_STEEL00.ogg` | ogg | 15691 |
| `Audio/Steel jingles/jingles_STEEL01.ogg` | ogg | 21019 |
| `Audio/Steel jingles/jingles_STEEL02.ogg` | ogg | 21919 |
| `Audio/Steel jingles/jingles_STEEL03.ogg` | ogg | 19117 |
| `Audio/Steel jingles/jingles_STEEL04.ogg` | ogg | 14951 |
| `Audio/Steel jingles/jingles_STEEL05.ogg` | ogg | 15082 |
| `Audio/Steel jingles/jingles_STEEL06.ogg` | ogg | 18893 |
| `Audio/Steel jingles/jingles_STEEL07.ogg` | ogg | 22460 |
| `Audio/Steel jingles/jingles_STEEL08.ogg` | ogg | 13885 |
| `Audio/Steel jingles/jingles_STEEL09.ogg` | ogg | 11145 |
| `Audio/Steel jingles/jingles_STEEL10.ogg` | ogg | 16151 |
| `Audio/Steel jingles/jingles_STEEL11.ogg` | ogg | 14615 |
| `Audio/Steel jingles/jingles_STEEL12.ogg` | ogg | 18971 |
| `Audio/Steel jingles/jingles_STEEL13.ogg` | ogg | 17122 |
| `Audio/Steel jingles/jingles_STEEL14.ogg` | ogg | 20532 |
| `Audio/Steel jingles/jingles_STEEL15.ogg` | ogg | 16113 |
| `Audio/Steel jingles/jingles_STEEL16.ogg` | ogg | 15473 |
| `Preview.ogg` | ogg | 155244 |

---

## 包:digital-audio

- 商店頁:https://kenney.nl/assets/digital-audio
- download-link 端點:`https://kenney.nl/download-link/6173736574732f6469676974616c2d617564696f`
- 實際下載網址(簽名,帶期限):`https://kenney.nl/download/6173736574732f6469676974616c2d617564696f/5c5a125587b1fe82a3f74cf08f7c0022c8a3ef62adc06c66be3bedfe5e0bb422?expires=1794282834`
- 伺服器給的檔名:`kenney_digital-audio.zip`;本地存為 `C:/tmp/kenney-dl/digital-audio/digital-audio.zip`(990367 bytes)
- SHA256:`24e6ce28b76a6d8c89cff4d331e0965ff5c3de8a73c612028e9d363cc64e4f06`
- 下載時間:2026-11-10 11:49:40 +0800

### 商店頁授權欄原文(HTML 原始碼,逐字)

```html
<td class='title text-muted'>License</td>
<td class='bold'><a href='https://creativecommons.org/publicdomain/zero/1.0/' target='_blank'>Creative Commons CC0</a></td>
</tr>
```
(頁面另有 og:description 逐字:`Download this package (60 assets) for free, CC0 licensed!`)

### 包內 License.txt 全文(逐字;原檔為 CRLF、行首 Tab,此處保留 Tab)

```text
	

	Digital Audio

	by  Kenney Vleugels (Kenney.nl)

			------------------------------

	License (Creative Commons Zero, CC0)
	http://creativecommons.org/publicdomain/zero/1.0/

	You may use these assets in personal and commercial projects.
	Credit (Kenney or www.kenney.nl) would be nice but is not mandatory.

			------------------------------

	Donate:   http://support.kenney.nl
	Request:  http://request.kenney.nl

	Follow on Twitter for updates:
	@KenneyNL
```

**比對**:商店頁寫 CC0(連到 creativecommons.org/publicdomain/zero/1.0/),包內 License.txt 寫 "Creative Commons Zero, CC0" 同一網址(http vs https)→ **一致**。包內另寫「署名非必要」,商店頁授權欄無此文字,不構成衝突。

### 非音檔

- `Audio/desktop.ini`(46 bytes)
- `License.txt`(482 bytes)
- `Visit Kenney.url`(45 bytes)
- `Visit Patreon.url`(55 bytes)
  - `Audio/desktop.ini` 內容:Windows 資料夾檢視設定(`[ViewState] Mode= Vid= FolderType=Generic`),非音檔。
  - `.url` 為 Windows 網址捷徑,內容僅 `URL=http://www.kenney.nl/` 或 `URL=https://www.patreon.com/kenney/`(已以文字讀出,未開啟)。

### 音檔清單(63 個)

| 相對路徑(相對 `extracted/`) | 格式 | 大小(bytes) |
|---|---|---|
| `Audio/highDown.ogg` | ogg | 5803 |
| `Audio/highUp.ogg` | ogg | 6135 |
| `Audio/laser1.ogg` | ogg | 9315 |
| `Audio/laser2.ogg` | ogg | 8524 |
| `Audio/laser3.ogg` | ogg | 8302 |
| `Audio/laser4.ogg` | ogg | 9208 |
| `Audio/laser5.ogg` | ogg | 8484 |
| `Audio/laser6.ogg` | ogg | 8928 |
| `Audio/laser7.ogg` | ogg | 8848 |
| `Audio/laser8.ogg` | ogg | 9383 |
| `Audio/laser9.ogg` | ogg | 9331 |
| `Audio/lowDown.ogg` | ogg | 5956 |
| `Audio/lowRandom.ogg` | ogg | 5416 |
| `Audio/lowThreeTone.ogg` | ogg | 7035 |
| `Audio/pepSound1.ogg` | ogg | 6019 |
| `Audio/pepSound2.ogg` | ogg | 5910 |
| `Audio/pepSound3.ogg` | ogg | 5590 |
| `Audio/pepSound4.ogg` | ogg | 5948 |
| `Audio/pepSound5.ogg` | ogg | 6422 |
| `Audio/phaseJump1.ogg` | ogg | 6733 |
| `Audio/phaseJump2.ogg` | ogg | 6342 |
| `Audio/phaseJump3.ogg` | ogg | 6854 |
| `Audio/phaseJump4.ogg` | ogg | 7117 |
| `Audio/phaseJump5.ogg` | ogg | 6770 |
| `Audio/phaserDown1.ogg` | ogg | 7113 |
| `Audio/phaserDown2.ogg` | ogg | 6093 |
| `Audio/phaserDown3.ogg` | ogg | 7329 |
| `Audio/phaserUp1.ogg` | ogg | 7390 |
| `Audio/phaserUp2.ogg` | ogg | 6895 |
| `Audio/phaserUp3.ogg` | ogg | 7222 |
| `Audio/phaserUp4.ogg` | ogg | 6332 |
| `Audio/phaserUp5.ogg` | ogg | 6289 |
| `Audio/phaserUp6.ogg` | ogg | 6349 |
| `Audio/phaserUp7.ogg` | ogg | 6410 |
| `Audio/powerUp1.ogg` | ogg | 9011 |
| `Audio/powerUp10.ogg` | ogg | 6568 |
| `Audio/powerUp11.ogg` | ogg | 6495 |
| `Audio/powerUp12.ogg` | ogg | 7278 |
| `Audio/powerUp2.ogg` | ogg | 5577 |
| `Audio/powerUp3.ogg` | ogg | 9043 |
| `Audio/powerUp4.ogg` | ogg | 6288 |
| `Audio/powerUp5.ogg` | ogg | 5652 |
| `Audio/powerUp6.ogg` | ogg | 5607 |
| `Audio/powerUp7.ogg` | ogg | 5868 |
| `Audio/powerUp8.ogg` | ogg | 6363 |
| `Audio/powerUp9.ogg` | ogg | 6101 |
| `Audio/spaceTrash1.ogg` | ogg | 12132 |
| `Audio/spaceTrash2.ogg` | ogg | 12640 |
| `Audio/spaceTrash3.ogg` | ogg | 12413 |
| `Audio/spaceTrash4.ogg` | ogg | 12685 |
| `Audio/spaceTrash5.ogg` | ogg | 11729 |
| `Audio/threeTone1.ogg` | ogg | 7361 |
| `Audio/threeTone2.ogg` | ogg | 8082 |
| `Audio/tone1.ogg` | ogg | 6634 |
| `Audio/twoTone1.ogg` | ogg | 7362 |
| `Audio/twoTone2.ogg` | ogg | 7349 |
| `Audio/zap1.ogg` | ogg | 8126 |
| `Audio/zap2.ogg` | ogg | 9819 |
| `Audio/zapThreeToneDown.ogg` | ogg | 9936 |
| `Audio/zapThreeToneUp.ogg` | ogg | 9590 |
| `Audio/zapTwoTone.ogg` | ogg | 9847 |
| `Audio/zapTwoTone2.ogg` | ogg | 9016 |
| `Preview.ogg` | ogg | 587635 |

