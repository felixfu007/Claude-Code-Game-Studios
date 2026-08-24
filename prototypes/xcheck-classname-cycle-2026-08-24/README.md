# X-CYCLE —— 兩個 `class_name` 腳本互相引用(2026-08-24)

**結論:雙向 `class_name` 引用在 Godot 4.7.1 編譯得過,執行期也完全成立。**

引擎:`4.7.1.stable.official.a13da4feb`,headless,exit 0。
未過濾 log:`logs/xcycle-unfiltered.txt`(本檔每一條宣稱都可在該 log 逐字對照)。

## 為什麼跑這支

ADR-0003 的 2026-08-24 修訂把原本單一 `SaveFormat` 腳本拆成三個 `class_name` 腳本
(`SaveTypeGate` / `SaveEnvelope` / `SaveFormat`)。若 `SaveFormat.deserialize_manifest()`
呼叫 `SaveEnvelope.check_shape()`,而 `SaveEnvelope.ShapeCheckResult` 的欄位型別又標註
`SaveFormat.ReadRejection`,兩個腳本就**互相引用對方**。

Step 5.6 架構總監覆核指出:**存檔格式骨架從未編譯過這個形狀**(骨架把閘門包在單一
`SaveFormat` 內,只有單向引用),而這是核准條件一「依賴的引擎行為都要在真引擎上跑過」
當時唯一的真缺口。

既有探針 x4(`save-format-skeleton-2026-08-21/scripts/x4_cross_class_enum.gd`)只測過
**單向**(腳本 A 引用腳本 B 的 enum / 內部類別)。本探針補測雙向。

## 受測形狀

| 檔案 | 引用對方什麼 |
|---|---|
| `scripts/save_format.gd`(`class_name SaveFormat`) | 呼叫 `SaveEnvelope.check_shape()`(靜態方法) |
| `scripts/save_envelope.gd`(`class_name SaveEnvelope`) | 型別標註 `SaveFormat.ReadRejection`、常數 `SaveFormat.HASH_LEN`、enum 值 |

判編譯用 `ResourceLoader.load(..., CACHE_MODE_IGNORE)` 後取 `reload()` 的 `Error`,
**不用「`load()` 不是 `null`」** —— 沿用既有探針紀律。

## 結果

| # | 測項 | 結果 |
|---|---|---|
| Step 1 | 兩檔各自編譯 | **兩檔皆 `COMPILED OK`**(`reload()` 回 `OK`) |
| Step 2 Case 1 | 合法信封,`SaveFormat` → `SaveEnvelope` 跨檔呼叫 | `ok=true` —— 雙向解析在執行期成立 |
| Step 2 Case 2 | 缺 `ruleset_version` | `ok=false`,`detail='信封缺少鍵 ruleset_version'` —— **錯誤字串來自 `SaveEnvelope`**,證明真的呼叫過去了,不是本地判斷 |
| Step 2 Case 3 | `top_level_hash` 長度錯 | `ok=false`,`detail='top_level_hash 型別或長度不符'` —— `SaveEnvelope` 內部確實讀到了跨檔常數 |
| Step 2 Case 4 | 空 buffer | `ok=false`,`detail='decoded typeof=0, not a Dictionary'`,伴隨逐字 `ERROR: Condition "len < 4" is true. Returning: ERR_INVALID_DATA`(`core/io/marshalls.cpp:191`)。**不觸碰 `SaveEnvelope`**,`SaveFormat` 自己的分支不受引用影響 |
| Step 3 | 不經方法呼叫直接存取跨檔符號 | `SaveFormat.HASH_LEN = 32`;`SaveFormat.ReadRejection.DATA_CORRUPTED = 1`;`SaveEnvelope.ShapeCheckResult.new().rejection = 0`(預設值正確解析到對方 enum 的 `NONE`) |

## ⚠️ 環境陷阱 —— 差一步就會做出完全相反的結論

**第一次執行時全部失敗**,逐字:

```
SCRIPT ERROR: Parse Error: Could not find type "SaveFormat" in the current scope.
SCRIPT ERROR: Parse Error: Identifier "SaveEnvelope" not declared in the current scope.
ERROR: Failed to load script "res://scripts/runner.gd" with error "Parse error".
```

**這不是雙向引用的結論,是環境問題。** `class_name` 的全域註冊靠
`.godot/global_script_class_cache.cfg`,而那份快取由匯入階段產生。全新目錄
直接 `--headless --path .` 執行時該快取不存在,**任何** `class_name` 參照都會
「not declared in the current scope」。

**正確做法:先跑 `--headless --path . --import` 產生快取,再執行。**
匯入完成後 `global_script_class_cache.cfg` 內同時列出 `SaveEnvelope` 與 `SaveFormat`
兩個項目 —— **快取能生成本身就已經是「兩檔在匯入期都通過剖析」的證據。**

> 若沒有做這一步就下結論,會得到「雙向 `class_name` 引用在 Godot 4.7.1 不可行」
> 這個**完全相反且錯誤**的判定,並據此把架構改成不必要的單向形狀。
> **後續任何用到 `class_name` 的 headless 探針都必須先 `--import`。**

## 未涵蓋

- 三檔互相引用成環(`A→B→C→A`)未測 —— 本探針只測兩檔雙向
- release(export)建置行為未測 —— 本機無 export template(全域零個 `.tpz`),與
  `core-serialization.md` 文末未查證表第 1 項同一限制
- `class_name` 快取在**編輯器未開啟過**的 CI 環境是否可靠生成 —— 本次是本機手動
  `--import`,CI 情境未測
