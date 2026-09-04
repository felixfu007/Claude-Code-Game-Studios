# 字型資產

## Cubic 11(俐方體 11 號)

| 欄位 | 值 |
|---|---|
| **檔案** | `Cubic_11.ttf`(2,773,732 bytes) |
| **來源** | https://github.com/ACh-K/Cubic-11 |
| **版本** | **v1.500**(2026-06-27 發布) |
| **取得路徑** | `https://raw.githubusercontent.com/ACh-K/Cubic-11/v1.500/fonts/ttf/Cubic_11.ttf` |
| **SHA256** | `0193f5f033612496df6b45ee92ac3b335bc6a5a24ff95da55ca87b33e57dcf62` |
| **授權** | SIL Open Font License 1.1(全文見同目錄 `OFL.txt`) |
| **納入日期** | 2026-09-04(screen-scaling Story 002 開工前) |
| **用途** | 介面短標籤 / HUD 數字(`design/art/art-direction.md` 第五節指定) |

🔴 **釘在發布標籤 `v1.500`,不是 `main`。** 任何人重跑上面那個網址都會拿到位元組相同的檔案;
抓 `main` 會隨上游變動,而本專案已為「不同人拿到不同版本」付過代價(見 GdUnit4 的 vendoring 理由)。

## 🔴 OFL 的散布義務

**SIL OFL 1.1 要求散布時一併包含授權全文。** `OFL.txt` 與字型檔放在同一目錄,**不得刪除**。
遊戲匯出時若該檔案未被打包,需要在遊戲內或隨附文件中提供授權文字。
⚠️ **本項目前尚未在匯出設定裡驗證過** —— 匯出流程建立時必須確認。

## 進版控的理由

**與 GdUnit4 同一套理由**:版本釘死在提交裡,CI 不需要抓取步驟,任何人 clone 下來就能建置。
抓取式安裝會讓建置多一個對外相依,而且不同時間 clone 可能拿到不同版本。

## 2026-09-04 開工前實測(引擎確實載得動,不是假設)

探針:`prototypes/story-010-headless-resolution-probe-2026-09-04/font_probe.gd`

```
載入耗時 13 ms;結果=true
font_name = Cubic 11
fixed_size = 0
現行畫面用到的 18 個字,缺字數 = 0
```

匯入時引擎自行輸出(逐字):

```
res://assets/fonts/Cubic_11.ttf: Pixel font detected, disabling subpixel positioning.
res://assets/fonts/Cubic_11.ttf: Pixel font detected, disabling hinting.
```

### 🔴 `fixed_size = 0` 的意義 —— 一個會誤導人的假設,已當場推翻

探針原本寫著「點陣字的 `fixed_size` 應非 0」。**實測為 0,那個假設是錯的。**

Cubic 11 是**外框對齊 11px 網格的 TTF**,不是內嵌點陣圖(bitmap strike)的字型。
引擎那兩行 `Pixel font detected` 來自它自己的啟發式判斷(於是關掉次像素定位與 hinting),
**不是來自 `fixed_size` 欄位。**

⚠️ **後果**:**「只能整數倍放大」不是引擎會替我們擋下來的限制,是一條紀律。**
設一個非整數倍的字級不會報錯、不會有警告,**只會在畫面上糊掉**。
🔴 **因此 Story 002 的 AC-S002-b(整數倍)必須靠測試或審查執行,不能指望引擎把關。**

## 尚未取得的字型

**對話正文字型尚未選定。** `design/art/art-direction.md` 只寫「一般繁體中文字型(非像素字型)」,
那是一個**類別,不是一個決定** —— 沒有指名是哪一套,也沒有檔案。

📌 對話正文字型的選用不阻擋 Story 002 的 HUD 部分:向量字型可任意縮放,
字級規則可以先寫成與特定字型無關的形式。**但真的要排對話畫面之前必須先選定。**
