# i18n Locale Probe — 2026-09-29

**目的**:回答 `production/epics/localization-infrastructure/EPIC.md` 明文標記的兩項「未查證」——
`project.godot` 的 `[internationalization]` 真實鍵名,以及 `zh_TW` 對 `zh_Hant` 在
`TranslationServer` 實際行為上的差異。

**驗證方式**:本機 `Godot_v4.7.1-stable_win64_console.exe --headless`,於系統暫存目錄
(`C:\Users\felixfu007\AppData\Local\Temp\1\tmp.FsqQJTlCWU\i18n_probe_project`,已隨對話結束
清除,不隨本目錄留存)建立拋棄式空專案,直接向引擎讀取真實預設值(`ProjectSettings`)、
真實 API 表(`ClassDB`)、真實行為(`TranslationServer`),並實際匯入一份含 `zh_TW` /
`zh_Hant` 兩欄的測試 CSV 檢查產生的 `.translation` 資源。**未觸碰專案根目錄**——本目錄
(`prototypes/godot-specialist-i18n-locale-probe-2026-09-29/`)以外沒有寫入任何檔案。

**(A) 級來源**:本目錄 `probe.gd`(headless SceneTree 腳本,原樣留存)。
**原始輸出**:本目錄 `run_output_headless.txt`(引擎真實 stdout,192 行,未經整理或摘要)。
**輔助物證**:`test_translations.csv`(測試夾具)、`test_translations.csv.import`(引擎產生的
匯入設定檔,原樣留存)、`import_run_output.txt`(首次 `--import` 執行的引擎輸出)。

引擎路徑(本機專用):
`C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe`

---

## Q2 結論先講(這是本次探針的主要產出)

**用 `zh_TW`,不要用 `zh_Hant`。**

理由,依實測證據排序:

1. **`zh_TW` 才是引擎公開文件裡「有名字」的地區代碼** ——
   `get_locale_name(zh_TW) = Chinese, Taiwan`(`run_output_headless.txt` 第 148 行),
   而 `zh_Hant` 只回報 `Chinese (Traditional Han)`(第 149 行)——**沒有國家/地區資訊,
   只有文字系統資訊**。本專案面向台灣使用者,`zh_TW` 語意上更精確。
2. **實測 `compare_locales()` 顯示兩者在引擎的比對邏輯裡分數相同**(見下方 Q2 詳細第 4 點),
   **fallback 方向雙向都成功**(Case A、Case B,第 169-175 行)——**所以「選哪個都不會讓
   fallback 失敗」這件事已經實測排除**,選 `zh_TW` 不是因為 `zh_Hant` 有 fallback 風險,
   是因為 `zh_TW` 語意更貼近專案受眾且是更常見寫法。
3. **`standardize_locale()` 不會把兩者互相正規化成同一個字串**(第 132-133 行:
   `zh_TW` 保持 `zh_TW`,`zh_Hant` 保持 `zh_Hant`)——**兩者是引擎眼中不同但「足夠像」的
   合法 locale 字串**,不是一個會被正規化掉的別名關係。
4. **兩者在引擎的地區/文字系統資料庫裡都合法存在**(第 152-154 行:`zh` 語言、`Hant` 文字
   系統、`TW` 國別代碼皆存在),**不是「一個合法一個不合法」的選擇**。

⚠️ **這是本次探針執行者的判斷,不是管理者裁決** —— 派工單明文寫「管理者已授權由技術總監依你的
結果拍板」,故本結論是**呈交技術總監的建議**,不是最終決定。

---

## Q1:`project.godot` 的 `[internationalization]` 區塊,實際鍵名與預設值

**方法**:直接列舉 `ProjectSettings.get_property_list()`,過濾 `internationalization` 開頭
的項目 —— 這是引擎自己回報「這個版本實際有哪些設定」,不是憑文件或訓練資料列的清單。

| 鍵名 | 型別(engine `type` 枚舉值) | 預設值 | 原始輸出行(`run_output_headless.txt`) |
|---|---|---|---|
| `internationalization/locale/translations` | 34(`Array`) | `[]`(空陣列) | 第 14-15 行 |
| `internationalization/locale/translation_remaps` | 34(`Array`) | `[]` | 第 12-13 行 |
| `internationalization/locale/translations_pot_files` | 34(`Array`) | `[]` | 第 16-17 行 |
| `internationalization/locale/translation_add_builtin_strings_to_pot` | 1(`bool`) | `false` | 第 18-19 行 |
| `internationalization/locale/fallback` | 4(`String`) | `en` | 第 26-27 行 |
| `internationalization/locale/test` | 4(`String`) | `""`(空字串) | 第 24-25 行 |
| `internationalization/locale/include_text_server_data` | 1(`bool`) | `false` | 第 20-21 行 |
| `internationalization/locale/line_breaking_strictness` | 2(enum) | `0`(`Auto`,hint_string 列舉:`Auto,Loose,Normal,Strict`) | 第 22-23 行 |
| `internationalization/rendering/force_right_to_left_layout_direction` | 1(`bool`) | `false` | 第 6-7 行 |
| `internationalization/rendering/root_node_layout_direction` | 2(enum) | `0`(`Based on Application Locale`) | 第 8-9 行 |
| `internationalization/rendering/root_node_auto_translate` | 1(`bool`) | `true` | 第 10-11 行 |
| `internationalization/rendering/text_driver` | 4(`String`,enum hint) | `""`(空字串=自動) | 第 46-47 行 |
| `internationalization/pseudolocalization/*`(7 項:`use_pseudolocalization`、`replace_with_accents`、`double_vowels`、`fake_bidi`、`override`、`expansion_ratio`、`prefix`、`suffix`、`skip_placeholders`) | 各異 | 各異(全部 `false`,除 `replace_with_accents`/`skip_placeholders` 為 `true`) | 第 28-45 行 |

**回答派工單三個具體問題**:

- **語系清單怎麼設定** → `internationalization/locale/translations`,型別 `Array`(存放
  `.translation` 資源的 `res://` 路徑字串)。**實測預設為空陣列,而且匯入 CSV 不會自動填入
  這個陣列**(見下方「CSV 匯入行為」一節)——必須手動把產生的 `.translation` 路徑加進這個
  陣列,或透過編輯器的 Import 面板逐一勾選「加入專案」。
- **fallback locale 的鍵名** → `internationalization/locale/fallback`,型別 `String`,
  **實測預設值是 `en`**(第 27 行),不是空字串。
- **`.csv` 翻譯資源怎麼掛進去** → 見下方「CSV 匯入行為」一節,`internationalization/locale/translations`
  型別確認為 `Array`(第 14-15 行 `type=34`),可以掛。

### CSV 匯入行為(實測,`import_run_output.txt` + `test_translations.csv.import`)

拿一份標頭為 `keys,zh_TW,zh_Hant,en` 的測試 CSV 實際匯入(`godot --headless --import`):

- **匯入器名稱是 `csv_translation`**(`test_translations.csv.import` 第 3 行:
  `importer="csv_translation"`)。
- **每個語系欄位各自產生一個獨立 `.translation` 檔,檔名逐字沿用 CSV 標頭字串** ——
  產生了 `test_translations.zh_TW.translation`、`test_translations.zh_Hant.translation`、
  `test_translations.en.translation`(`test_translations.csv.import` 第 8-9 行 `dest_files`)。
  **標頭字串在檔名這一層沒有被正規化。**
- **匯入 CSV 這個動作本身不會自動把產生的 `.translation` 路徑寫進
  `internationalization/locale/translations`** —— `import_run_output.txt` 記載匯入前後
  `project.godot` 內容逐字相同(這份探針的 `project.godot` 本身沒有 `[internationalization]`
  區塊,匯入前後皆然)。**這一步是額外的手動動作**,不是 CSV 匯入的副作用。
- **`.translation` 資源實際載入後,`.locale` 屬性值 = CSV 標頭字串本身,一字不改**
  (`run_output_headless.txt` 第 164、166 行:
  `res_zh_tw.locale (verbatim from CSV header zh_TW) = zh_TW`、
  `res_zh_hant.locale (verbatim from CSV header zh_Hant) = zh_Hant`)。

### 未查證(Q1)

- `internationalization/locale/locale_filter_mode`、`internationalization/locale/locale_filter`
  ——**這兩個是我依訓練資料猜測可能存在的鍵名,實測 `has_setting()` 回報 `false`**
  (第 53-54 行)。**這兩個鍵在 Godot 4.7.1 預設專案設定裡不存在**(至少在未被任何
  UI 操作觸發前不存在;不排除只有在編輯器內手動設定過至少一次語系篩選後才會出現在
  `property_list()` 裡——**這一點沒有另外測試,標未查證**)。
- **`.csv` 匯入的 `[params]` 逐項語意**(`compress`、`delimiter`、`unescape_keys`、
  `unescape_translations`,見 `test_translations.csv.import` 第 12-15 行)——本次只確認了
  它們存在與預設值,**沒有逐項測試改變它們會如何影響匯入結果,標未查證**。
- **透過編輯器 Import 面板手動勾選「加入專案」的實際行為**(是否真的會寫入
  `internationalization/locale/translations`、寫入格式)——本次只用 CLI `--import`,
  **沒有測試編輯器互動路徑,標未查證**。

---

## Q2:`zh_TW` 還是 `zh_Hant` —— 詳細實測

### 1. `set_locale()` 之後 `get_locale()` 讀回來是什麼(第 123-129 行)

```
after set_locale(zh_TW)        -> get_locale() = zh_TW
after set_locale(zh_Hant)      -> get_locale() = zh_Hant
after set_locale(zh_Hant_TW)   -> get_locale() = zh_Hant_TW
after set_locale(zh_HANT_tw) mixed case -> get_locale() = zh
```

**兩者都不會被正規化成對方,原樣保留。** 但**大小寫不規範的字串會被引擎砍成只剩語言碼**
(`zh_HANT_tw` 混合大小寫 → 讀回 `zh`,遺失了文字系統與地區資訊)——**這是一個附帶發現的
實務陷阱:CSV 標頭或程式碼裡的 locale 字串大小寫必須寫對**(`zh_Hant_TW`,不是
`zh_HANT_tw`),否則 `set_locale()` 會靜默降級成只剩 `zh`。

### 2. `standardize_locale()`(第 131-138 行)

```
standardize_locale(zh_TW)      = zh_TW
standardize_locale(zh_Hant)    = zh_Hant
standardize_locale(zh_Hant_TW) = zh_Hant_TW
standardize_locale(zh_HANT_tw) = zh          <- 同樣的大小寫陷阱
standardize_locale(zh)         = zh
standardize_locale(zh_CN)      = zh_CN
standardize_locale(zh_Hans)    = zh_Hans
```

**`zh_TW` 與 `zh_Hant` 不會互相正規化成同一個字串** —— 兩者是引擎眼中兩個不同但都合法的
locale 字串,不是別名關係。

### 3. `get_loaded_locales()` / `compare_locales()`(第 140-145、185-186 行)

```
compare_locales(zh_TW,zh_Hant)   = 10
compare_locales(zh_TW,zh_TW)     = 10
compare_locales(zh_TW,zh_CN)     = 3
compare_locales(zh_Hant,zh_Hans) = 3
compare_locales(zh_Hant,zh_TW)   = 10
```

`compare_locales(zh_TW, zh_Hant) = 10`,**與完全相同字串的比對分數(`zh_TW` 對 `zh_TW`)
相同,都是 10**——引擎把這兩者視為**同等吻合**,不是「有點像但比不上完全相同」。反觀
`zh_TW` 對 `zh_CN`(同語言、不同地區,均為簡體語境)只有 3 分,`zh_Hant` 對 `zh_Hans`
(繁簡對立)同樣只有 3 分。**這說明引擎的比對邏輯把「地區代碼」與「文字系統代碼」視為
同一權重層級的限定詞,兩者對「基準語言 zh」的加成相等。**

`get_loaded_locales()` 在兩者同時註冊時原樣列出兩者,不做去重合併
(第 186 行:`get_loaded_locales() = ["zh_TW", "zh_Hant", "en"]`)。

### 4. **CSV 欄位標頭寫 zh_TW、系統 locale 是 zh_Hant(或反之),fallback 會不會失敗** —— 這是派工單點名「真正會痛的那一條」,已用真實 CSV 匯入的 `.translation` 資源實測

**不會失敗,雙向都成功。**

```
--- Case A: ONLY zh_TW translation registered, active locale forced to zh_Hant ---
get_locale() = zh_Hant
tr(test_key) = [測試甲_zhTW]  -- 成功:看到 zh_TW 的字串,fallback 生效

--- Case B: ONLY zh_Hant translation registered, active locale forced to zh_TW ---
get_locale() = zh_TW
tr(test_key) = [測試乙_zhHant]  -- 成功:看到 zh_Hant 的字串,fallback 生效
```

（第 169-175 行,對照組 Case C/D 確認 `tr()` 本身管線正常運作,第 177-183 行。）

**但有一個邊界情況值得記錄**:當**兩者同時註冊**、系統 locale 是合併形式 `zh_Hant_TW` 時,
**`zh_TW` 那份翻譯贏了**,不是 `zh_Hant`(第 188-190 行,Case E:
`get_locale() = zh_Hant_TW` 之後 `tr(test_key) = [測試甲_zhTW]`)。**這只測了一種註冊順序
(先註冊 zh_TW 再註冊 zh_Hant),沒有測試反過來的註冊順序是否會改變勝出者 —— 這一點標
未查證**,若專案將來真的同時提供兩種標頭的 CSV(不建議,見下方建議),這個順序依賴性需要
另外驗證。

### 5. 引擎內建 locale 清單裡兩者分別存不存在(第 151-154 行)

```
get_all_languages contains zh? true total=616
get_all_scripts contains Hant? true contains Hans? true total=191
get_all_countries contains TW? true total=261
```

`TranslationServer` 沒有直接列舉「完整 locale 字串」的 API(`ClassDB` 列出的方法只到
`get_all_languages`/`get_all_scripts`/`get_all_countries` 這三個各自獨立的清單,見
`run_output_headless.txt` 第 63-97 行的完整方法表)。**`zh`、`Hant`、`TW` 三個組成部分各自
都存在於引擎資料庫**,`zh_TW` 與 `zh_Hant` 都是這些部分的合法組合,沒有一個是「引擎不認得」
的字串。

### 未查證(Q2)

- **Case E(兩者同時註冊時的勝出順序)是否受註冊順序影響** —— 只測了一種順序,見上方第 4 點。
- **`get_tool_locale()`**(`ClassDB` 方法表裡有列出,第 66 行)——**沒有呼叫測試**,不確定
  這是編輯器專用還是 runtime 也有意義,標未查證。
- **實際 Windows/Steam 平台回報的系統 locale 字串格式**(`OS.get_locale()` /
  `OS.get_locale_language()`)——**本次探針完全沒有測試這兩個方法**,只測了
  `TranslationServer` 這一側。**若系統回報的字串本身就帶著奇怪的大小寫或格式,第 1 點
  發現的「大小寫陷阱」可能在真實裝置上發生,而本次探針無法確認 Windows/Steam 實際會回報
  什麼字串** —— 這是下一步若要收斂到「production 環境會不會踩到這個陷阱」需要另外驗證的項目。

---

## 做不到的部分

**沒有一題完全做不到。** 兩題都在 headless 下拿到了引擎的真實回應。上面列的「未查證」都是
**探針範圍內刻意沒有測試的追加問題**,不是「試了但引擎給不出答案」的情況。
