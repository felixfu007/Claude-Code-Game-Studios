# ADR-0002 Step 5.5 覆核探針 — 2026-08-24

**執行者**:`godot-specialist`(Step 5.5 引擎專家覆核,ADR-0002 第五次修訂前的把關)
**引擎**:`Godot 4.7.1.stable.official.a13da4feb`,headless,exit code 0

## 假設

ADR-0002 的 Key Interfaces 章節有一句閱讀提醒(第 747 行):「Godot 每個 `.gd`
檔只能有一個 `class_name`,實作時各類別應落在各自檔案(如 `affinity_record.gd`、
`affinity_record_list.gd`、`affinity_data_pool.gd`、`affinity_read_result.gd`)」
—— 明白建議 `AffinityReadResult` 落在獨立檔案 `affinity_read_result.gd`。

但機制五的契約碼寫的是:

```gdscript
class AffinityReadResult extends RefCounted:
    var rejection: ReadRejection = ReadRejection.NONE   # 裸引用,未加類別限定字
```

而 `ReadRejection` 本身,依 ADR 機制二明文的規則(該規則正是為了修正 `Pair`/
`Character`/`Source` 曾經犯過的同一種錯誤才寫下的):「列舉若定義在某個
`class_name` 的類別內,只能以 `ClassName.EnumName` 從其他檔案存取」——而
`ReadRejection`/`WriteRejection`/`AdvanceRejection`/`DeathNotifyResult`/
`EndTokenResult` 全部明文「維持巢狀於 `AffinityDataPool` 內」(機制二原文)。

**若 `AffinityReadResult` 真的被放進獨立檔案,它對 `ReadRejection` 的裸引用會不會
重演 `Pair`/`Character`/`Source` 已經被抓過一次的同一個錯誤?**

## 如何重跑

```bash
GODOT="$HOME/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
"$GODOT" --headless --path . --editor --quit   # 建立 class_name 快取(必要)
"$GODOT" --headless --path .                    # 執行探針
```

`main_scene` 固定指向 `scenes/Main.tscn`。

## 探針設計

三個檔案,結構逐一對應 ADR-0002 的真實情境(用中性名稱抽象化以隔離變因):

| 檔案 | 對應 ADR-0002 的誰 | 內容 |
|---|---|---|
| `outer_holder.gd` | `AffinityDataPool` | `class_name OuterHolder`,內嵌 `enum MyEnum { A, B }`(對應 `ReadRejection` 巢狀於 `AffinityDataPool`) |
| `bare_ref_other_file.gd` | `AffinityReadResult`(若真的落在獨立檔案) | 另一個 `class_name`,對 `MyEnum` 做**裸引用**:`var rejection: MyEnum = MyEnum.A` —— 逐字對應 ADR 機制五的寫法 |
| `qualified_ref_other_file.gd` | 對照組 | 同樣跨檔案引用,但**限定**:`var rejection: OuterHolder.MyEnum = OuterHolder.MyEnum.A` —— 對應 ADR 機制二對 `AffinityTypes.Pair` 已經要求的正確寫法 |

`runner.gd` 依本專案既有紀律(`runner_c.gd`/`runner_d.gd` 前例):一律
`ResourceLoader.load(..., CACHE_MODE_IGNORE)` + `.reload()` 的 `Error` 回傳值逐檔
編譯檢查,絕不裸 `load()` 已知有編譯風險的檔案,避免一個檔案的 Parse Error 擋掉同批
其他檔案的結果(`probeC-v1-flawed` 的教訓)。

## 結果

| 檔案 | 結果 |
|---|---|
| `outer_holder.gd` | `COMPILED OK` |
| `bare_ref_other_file.gd`(裸引用) | **`FAILED (reload=Parse error)`** —— `Parse Error: Could not find type "MyEnum" in the current scope.` / `Identifier "MyEnum" not declared in the current scope.` |
| `qualified_ref_other_file.gd`(限定引用,對照組) | `COMPILED OK` |

完整未過濾輸出:`logs/run1-unfiltered.txt`(含 class cache 建置:
`logs/00-editor-cache-build.txt`)。

## 結論

**假設成立,且是決定性的。** 若 `AffinityReadResult`/`ShapeFeatureResult` 依 Key
Interfaces 的閱讀提醒被放進獨立檔案 `affinity_read_result.gd`,而機制五的
`var rejection: ReadRejection = ReadRejection.NONE` 逐字照抄(裸引用,不加
`AffinityDataPool.` 限定字),**該檔會在編譯期整檔失敗**——與 ADR 自己記載的
`Pair`/`Character`/`Source` 原始錯誤是同一個語言規則、同一種失敗訊息形狀。

這代表 ADR-0002 的 Key Interfaces 章節與機制五的契約碼**互相矛盾**:兩者對「檔案
邊界」給出的訊息合起來會導向一份不能編譯的實作,而四輪修訂與兩輪 Step 5.5 覆核都
沒有抓到這一處——因為關注焦點一直放在「這次新改的地方」,沒有人重新掃過「舊的、
一直沒動過的 Key Interfaces 閱讀提醒是否仍與新加的型別集合相容」。

## 狀態

**已結案。** 此為一次性的 Step 5.5 覆核驗證探針,結論已回報進審查意見,不預期後續
擴充。
