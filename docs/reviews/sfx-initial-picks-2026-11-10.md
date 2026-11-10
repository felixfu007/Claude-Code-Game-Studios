# 音效初選(Kenney CC0)— 2026-11-10

> 撰寫者:audio-director。素材來源與授權原文:`C:/tmp/kenney-dl/INVENTORY.md`。需求:`docs/reviews/minimal-audio-scope-draft-2026-11-06.md` 第二節 M1~M9。目標檔名:`assets/data/audio/sfx_cues.txt`。
>
> 🔴 **全部是【依檔名推測】的初值。** 我聽不到音檔,只能依檔名與各包性質挑,**未經任何試聽**。每項都待管理者在家試聽後換掉或確認。INVENTORY 沒有時長資料(本機無 ffprobe),檔案大小只能當「約略長短」的弱線索,不能當證據。

## 一、9 個 cue 的主選與備選

包縮寫:IF = interface-sounds、UI = ui-audio、RPG = rpg-audio、JG = music-jingles、DG = digital-audio。路徑皆相對該包 `extracted/`。

| # | cue_id | 主選(包 / 路徑) | 備選(包 / 路徑) | 理由【依檔名推測】 |
|---|---|---|---|---|
| M1 | ui_click | IF / `Audio/click_003.ogg` | UI / `Audio/click2.ogg` | 通用按鈕聲,選最樸素的 click;檔小(約 4KB)表示應很短。備選來自另一包,以防 IF 風格偏數位 |
| M2 | unit_select | IF / `Audio/select_001.ogg` | IF / `Audio/select_003.ogg` | 檔名即「選取」語意,與 M1 的 click 區隔;戰鬥每步都用,故選檔最小的一類(短) |
| M3 | cancel | IF / `Audio/error_004.ogg` | IF / `Audio/back_001.ogg` | M3 要讓玩家分清「不能做」與「沒反應」,主選用 error 類(拒絕感);備選 back 是較柔和的「退回」,若 error 太刺耳就換它 |
| M4 | unit_move | RPG / `Audio/footstep00.ogg` | RPG / `Audio/footstep05.ogg` | 敵方回合逐格移動的節奏,腳步聲語意直接。注意 120ms 間隔限制,連播時若太吵可改備選或調 cue 表 |
| M5 | attack_hit | RPG / `Audio/chop.ogg` | RPG / `Audio/knifeSlice.ogg` | 近戰命中:砍擊(chop)語意最直接;備選為切割聲,偏銳 |
| M6 | unit_down | RPG / `Audio/dropLeather.ogg` | DG / `Audio/lowDown.ogg` | 需與 M5 明顯不同聲:選較悶的「落下」類。備選 lowDown 為下行低音(數位風,與 RPG 包風格不一致,僅在落地聲不夠重時用) |
| M7 | victory | JG / `Audio/Steel jingles/jingles_STEEL02.ogg` | JG / `Audio/Pizzicato jingles/jingles_PIZZI07.ogg` | 草案要 3~6 秒短旋律;STEEL02、PIZZI07 檔案偏大(約 19~22KB)故推測偏長。「是否聽起來像勝利」完全未知 |
| M8 | defeat | JG / `Audio/Sax jingles/jingles_SAX07.ogg` | JG / `Audio/Sax jingles/jingles_SAX12.ogg` | 與 M7 必須不同聲;選不同樂器組(薩克斯)以拉開。SAX07 為該組最大檔(約 31KB),推測較長較緩;「是否像失敗」完全未知,這是最不確定的一項 |
| M9 | affinity_up | IF / `Audio/confirmation_003.ogg` | IF / `Audio/confirmation_001.ogg` | 「好感度增進」要有正向、與按鈕聲不同的柔和提示;confirmation 類語意吻合,檔比 click 大(較長、較有旋律感) |

**試聽重點提醒**:M7/M8 是最容易挑錯的(jingle 沒有情緒標籤);M4/M5/M6 要在連播下試聽;M1 與 M2 要確認聽起來不會混成同一個聲音。

## 二、複製清單

來源根目錄:`C:/tmp/kenney-dl/<包資料夾>/extracted/`。只列主選;備選待管理者試聽後若採用再另行補。協調者複製時,**目標檔名一律已是 `.ogg`,與 `sfx_cues.txt` 的路徑逐字一致**。

| cue_id | 來源絕對路徑 | 目標專案路徑 |
|---|---|---|
| ui_click | `C:/tmp/kenney-dl/interface-sounds/extracted/Audio/click_003.ogg` | `assets/audio/sfx/sfx_ui_click_01.ogg` |
| unit_select | `C:/tmp/kenney-dl/interface-sounds/extracted/Audio/select_001.ogg` | `assets/audio/sfx/sfx_battle_select_01.ogg` |
| cancel | `C:/tmp/kenney-dl/interface-sounds/extracted/Audio/error_004.ogg` | `assets/audio/sfx/sfx_battle_cancel_01.ogg` |
| unit_move | `C:/tmp/kenney-dl/rpg-audio/extracted/Audio/footstep00.ogg` | `assets/audio/sfx/sfx_battle_move_01.ogg` |
| attack_hit | `C:/tmp/kenney-dl/rpg-audio/extracted/Audio/chop.ogg` | `assets/audio/sfx/sfx_battle_hit_01.ogg` |
| unit_down | `C:/tmp/kenney-dl/rpg-audio/extracted/Audio/dropLeather.ogg` | `assets/audio/sfx/sfx_battle_down_01.ogg` |
| victory | `C:/tmp/kenney-dl/music-jingles/extracted/Audio/Steel jingles/jingles_STEEL02.ogg` | `assets/audio/sfx/sfx_battle_victory_01.ogg` |
| defeat | `C:/tmp/kenney-dl/music-jingles/extracted/Audio/Sax jingles/jingles_SAX07.ogg` | `assets/audio/sfx/sfx_battle_defeat_01.ogg` |
| affinity_up | `C:/tmp/kenney-dl/interface-sounds/extracted/Audio/confirmation_003.ogg` | `assets/audio/sfx/sfx_affinity_up_01.ogg` |

⚠️ 來源路徑 `Steel jingles`、`Sax jingles` 資料夾名含**空格**,複製時要加引號。複製後請確認 9 個目標檔皆存在且大於 0 bytes。

另有兩點需要協調者注意,**不是我能決定的**:
1. `.ogg` 進 `assets/` 後 Godot 會產生 `.import`;依 `coding-standards.md`,資料檔勿用 `.csv`,而 `.ogg` 是正規音訊格式,無此問題,但請照 `run_tests_with_import.sh` 流程重新匯入。
2. 響度未量測。五包響度彼此未必一致(音效與 jingle 來自不同包),入庫後需在家聽過並視需要調 bus 音量,本表不涵蓋。

## 三、授權紀錄草稿(建議放 `assets/audio/sfx/LICENSES.md`)

以下為建議內容(只寫在本檔,未建立 assets 下的檔)。

````markdown
# assets/audio/sfx 授權紀錄

本目錄的音效全部來自 Kenney(Kenney Vleugels,www.kenney.nl)的免費素材包,授權為
**Creative Commons Zero (CC0 1.0)**:http://creativecommons.org/publicdomain/zero/1.0/
下載日:2026-11-10。署名非必要(下列原文),本專案仍在此留紀錄。

## 授權原文(逐字,取自各包內 License.txt 與商店頁,轉錄自 C:/tmp/kenney-dl/INVENTORY.md)

- 商店頁授權欄(五包皆同):`Creative Commons CC0`,連結 https://creativecommons.org/publicdomain/zero/1.0/
- interface-sounds 包內 License.txt:
  `License: (Creative Commons Zero, CC0)` / `This content is free to use in personal, educational and commercial projects.` / `Support us by crediting Kenney or www.kenney.nl (this is not mandatory)`
- rpg-audio、music-jingles 包內 License.txt(兩包相同):
  `License (Creative Commons Zero, CC0)` / `You may use these assets in personal and commercial projects.` / `Credit (Kenney or www.kenney.nl) would be nice but is not mandatory.`

## 入庫檔案

| 專案內檔名 | 來源包 | 原檔名(包內路徑) | 商店頁 | 授權 | 下載日 |
|---|---|---|---|---|---|
| sfx_ui_click_01.ogg | Interface Sounds | Audio/click_003.ogg | https://kenney.nl/assets/interface-sounds | CC0 | 2026-11-10 |
| sfx_battle_select_01.ogg | Interface Sounds | Audio/select_001.ogg | https://kenney.nl/assets/interface-sounds | CC0 | 2026-11-10 |
| sfx_battle_cancel_01.ogg | Interface Sounds | Audio/error_004.ogg | https://kenney.nl/assets/interface-sounds | CC0 | 2026-11-10 |
| sfx_battle_move_01.ogg | RPG Audio | Audio/footstep00.ogg | https://kenney.nl/assets/rpg-audio | CC0 | 2026-11-10 |
| sfx_battle_hit_01.ogg | RPG Audio | Audio/chop.ogg | https://kenney.nl/assets/rpg-audio | CC0 | 2026-11-10 |
| sfx_battle_down_01.ogg | RPG Audio | Audio/dropLeather.ogg | https://kenney.nl/assets/rpg-audio | CC0 | 2026-11-10 |
| sfx_battle_victory_01.ogg | Music Jingles | Audio/Steel jingles/jingles_STEEL02.ogg | https://kenney.nl/assets/music-jingles | CC0 | 2026-11-10 |
| sfx_battle_defeat_01.ogg | Music Jingles | Audio/Sax jingles/jingles_SAX07.ogg | https://kenney.nl/assets/music-jingles | CC0 | 2026-11-10 |
| sfx_affinity_up_01.ogg | Interface Sounds | Audio/confirmation_003.ogg | https://kenney.nl/assets/interface-sounds | CC0 | 2026-11-10 |

## 維護規則

- 試聽後若換用備選檔,**同步改上表**(來源包、原檔名)。表與實際檔不一致就是授權紀錄失效。
- 新增來自其他來源的檔,先確認授權再入庫,並在本表新增一列;不是 CC0 的來源另行討論,不得混入。
- 此處只轉錄 INVENTORY 的逐字原文;包內 License.txt 的 SHA256 與 zip 雜湊見 INVENTORY.md 各包節。
````

## 四、未驗證事項(誠實登記)

- 全部挑選依檔名;**無一項聽過**。
- 備選的授權來源:UI 包(ui-audio)的備選 M1、DG 包(digital-audio)的備選 M6 若被採用,需在 LICENSES.md 補上該包(兩包亦為 CC0,見 INVENTORY,授權原文:`You may use these assets in personal and commercial projects.`)。目前表內只列主選。
- INVENTORY 稱商店頁 Files 數與實際檔數有四包對不上,成因未查;與本次挑選無關,但檔案完整性未驗。
