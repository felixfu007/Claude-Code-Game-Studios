# VR#12 探針 —— `var_to_bytes()` / `bytes_to_var()` 對 `int`/`float` 的型別往返保真

**狀態:已執行完畢(兩輪皆 exit 0,log 未過濾)。** 本探針由 `godot-gdscript-specialist`
撰寫並實跑,回填「結果」與「結論」兩節。

## 假設 / 要回答的問題

ADR-0002 待驗證事項第 12 項(`docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md`
第 53 行)逐字寫:

> `var_to_bytes()` / `bytes_to_var()` 對 `int` 與 `float` 的**型別往返保真** ——
> 未查證(2026-08-21 新增),歸屬 ADR-0003。

它為什麼是阻擋級:ADR-0002 機制八(同檔第 640 行,R7E-10)對還原後的 `m` 欄位有
一條**嚴格拒絕規則**:

> **`m` 嚴格為 `TYPE_FLOAT`,不接受 `TYPE_INT`**

其理由逐字引用(第 642 行):

> `export_state()` 的唯一生產者是 `AffinityRecord.m: float`(靜態型別),而
> `var_to_bytes()` 保留 `Variant` 型別 —— 因此**任何合法存檔的 `m` 必為
> `TYPE_FLOAT`**;還原後為 `TYPE_INT` 只可能來自人工編輯或位元損壞,**拒絕是正確
> 行為**。

`t`/`c` 兩欄位方向相反,嚴格要求 `TYPE_INT`。這條規則的**前提**(`var_to_bytes()`
保留 Variant 型別,int 進去還是 int、float 進去還是 float)ADR-0002 自己承認
「只登記依賴、不代為記帳」——**本探針第一次實測這個前提本身**,而不是繼續假設它。

本探針要回答:

1. **`float` 往返(整數值)**:`2.0`、`0.0`、`-1.0`、`1e10` —— 這組最可疑,因為
   `2.0` 在數值上等於 `2`。還原後 `typeof()` 是否仍為 `TYPE_FLOAT`(3)?
2. **`float` 往返(非整數值 / 極端量級)**:`3.14`、`0.1`、`1.7976931348623157e308`
   (最大正規 double)、`4.9406564584124654e-324`(教科書上最小正 double)—— 是否
   位元級相等?
3. **`int` 往返**:`0`、`1`、`-1`、`9007199254740993`(2⁵³+1,超過 32 位元,且超過
   double 能精確表示整數的範圍)—— 還原後是否仍為 `TYPE_INT`(2)、值是否不變?
4. **裝在容器裡的實際用法**:照 ADR-0002 `export_state()` 的真實形狀(`records`
   陣列裡的 `Dictionary`,含 `m`/`t`/`c`/`pair`/`source`;`campaign_tick_marks`
   整數陣列;`death_marks` 字串鍵整數值字典),整包一次 `var_to_bytes()` 後逐欄位
   比對。
5. **特殊值**:`INF`、`-INF`、`NAN` 的往返,以及機制八依賴的 `is_finite()` 對還原
   後的值是否仍正確回傳 `false`。

## 如何重跑

實際使用的 Godot 執行檔路徑(已確認存在,console 版本以取得 stdout):

```bash
GODOT="$HOME/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
cd prototypes/xcheck-adr0002-vr12-2026-08-25
"$GODOT" --headless --path . --import > logs/00-import.txt 2>&1
"$GODOT" --headless --path . > logs/run1-unfiltered.txt 2>&1
```

`main_scene` 固定指向 `scenes/Main.tscn`(`project.godot` 已設定)。

## 探針設計

`scripts/runner.gd`(`extends Node`)每組測項各自關在自己的函式裡,`_ready()` 依序
呼叫並印出分隔標題。每一筆比對都印一行 `RESULT` 前綴、可 grep 的 log,欄位包含
`typeof_before`/`typeof_after`(用 `type_string()` 附上數字與名稱,雙重確認)、
`value_equal`(`==` 比較)、`bit_equal`(位元級比較,見下)。

**位元級比較的做法**:不依賴 `==` 或 `str()` 的字面呈現,而是用
`PackedByteArray.encode_double()` / `encode_s64()` 把原始值與還原值各自編碼成 8
bytes 後取 `hex_encode()` 比對逐位元組是否相同 —— 這比單純 `==` 更嚴格,能排除
「數值相等但位元表示不同」的僥倖情況(儘管 IEEE754 double 理論上不會有這種情況,
但既然本專案的紀律要求「不外推」,就用最嚴格的檢查手段量測,不假設)。

`NAN` 一項刻意**不**用 `==` 判定往返保真(`NAN != NAN` 是 IEEE754 定義行為),改用
`is_nan()`,並把「若誤用 `==`」的結果也一併印出(`naive_equal_would_be`)供對照。

### run1 與 run2 的關係(兩份 log 都保留,用途不同)

`logs/run1-unfiltered.txt` 是**第一次完整執行**,涵蓋測項 1、2、3、4、5。檢視這份
log 時,發現測項 2(`float_non_integer`)裡 `4.9406564584124654e-324`(教科書最小正
double)這一筆,**還原前**(`hex_before`)就已經是 `0000000000000000`(全零,即
`0.0`)—— 也就是說,如果這是一個真的下溢(underflow),它發生在 `var_to_bytes()`
被呼叫**之前**,是 GDScript 浮點字面量的**解析階段**,不是本探針要測的**序列化
往返**階段。這兩件事若混為一談,會錯誤地把一個與 `var_to_bytes()` 無關的現象,
算進「往返保真」的判定裡。

為了不讓這個疑點含糊帶過,追加了**測項 2b**(`_case_denormal_literal_isolation()`):
全程**不呼叫任何** `var_to_bytes()`/`bytes_to_var()`,單純宣告三個小量級 float
字面量(`4.9406564584124654e-324`、`2.2250738585072014e-308`——這個是 IEEE754
**正規化** double 的最小值,不是次正規化值——與 `1.0e-310`),直接印出 `typeof()`
與位元表示,隔離出「這個現象在字面量宣告的那一刻就已存在,還是要等到某個運算才
出現」。

因為 2b 要插在測項 2 與測項 3 之間才能維持輸出順序與測項編號的直覺對應,所以修改
`runner.gd` 後**重新完整執行了一次**,存成 `logs/run2-unfiltered.txt`。已用
`diff logs/run1-unfiltered.txt logs/run2-unfiltered.txt` 逐位元組核對:**run2 與
run1 除了多出 2b 那 5 行(1 行標題 + 3 行 `RESULT` + 1 行空行)之外,其餘每一行
逐字相同**——測項 1、2、3、4、5 的所有數值與判定在兩輪之間**沒有任何變化**。

**兩份 log 的用途**:`run1-unfiltered.txt` 是原始的第一次完整執行紀錄,保留作為
測項 1/2/3/4/5 的獨立佐證(不依賴後續任何腳本修改);`run2-unfiltered.txt` 是
run1 的超集,額外多了 2b 的隔離測試結果,是下方「結果」節與「結論」節**實際引用
的版本**。兩者都未經事後編輯或美化。

## 結果

### `logs/run1-unfiltered.txt`(逐字)

```
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

=== VR12 probe: var_to_bytes()/bytes_to_var() int/float round-trip fidelity / Godot 4.7.1-stable (official) ===

--- 1: float round-trip, integer-valued ---
RESULT float_integer_valued value=2.0 typeof_before=3(float) typeof_after=3(float) value_equal=true bit_equal=true hex_before=0000000000000040 hex_after=0000000000000040
RESULT float_integer_valued value=0.0 typeof_before=3(float) typeof_after=3(float) value_equal=true bit_equal=true hex_before=0000000000000000 hex_after=0000000000000000
RESULT float_integer_valued value=-1.0 typeof_before=3(float) typeof_after=3(float) value_equal=true bit_equal=true hex_before=000000000000f0bf hex_after=000000000000f0bf
RESULT float_integer_valued value=10000000000.0 typeof_before=3(float) typeof_after=3(float) value_equal=true bit_equal=true hex_before=000000205fa00242 hex_after=000000205fa00242

--- 2: float round-trip, non-integer / extreme magnitude ---
RESULT float_non_integer value=3.14 typeof_before=3(float) typeof_after=3(float) value_equal=true bit_equal=true hex_before=1f85eb51b81e0940 hex_after=1f85eb51b81e0940
RESULT float_non_integer value=0.1 typeof_before=3(float) typeof_after=3(float) value_equal=true bit_equal=true hex_before=9a9999999999b93f hex_after=9a9999999999b93f
RESULT float_non_integer value=179769313486231570000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000.0 typeof_before=3(float) typeof_after=3(float) value_equal=true bit_equal=true hex_before=ffffffffffffef7f hex_after=ffffffffffffef7f
RESULT float_non_integer value=0.0 typeof_before=3(float) typeof_after=3(float) value_equal=true bit_equal=true hex_before=0000000000000000 hex_after=0000000000000000

--- 3: int round-trip, incl. beyond-32-bit ---
RESULT int_roundtrip value=0 typeof_before=2(int) typeof_after=2(int) value_equal=true bit_equal=true hex_before=0000000000000000 hex_after=0000000000000000
RESULT int_roundtrip value=1 typeof_before=2(int) typeof_after=2(int) value_equal=true bit_equal=true hex_before=0100000000000000 hex_after=0100000000000000
RESULT int_roundtrip value=-1 typeof_before=2(int) typeof_after=2(int) value_equal=true bit_equal=true hex_before=ffffffffffffffff hex_after=ffffffffffffffff
RESULT int_roundtrip value=9007199254740993 typeof_before=2(int) typeof_after=2(int) value_equal=true bit_equal=true hex_before=0100000000002000 hex_after=0100000000002000

--- 4: container shape matching export_state() (Dictionary[Array[Dictionary], Array[int], Dictionary]) ---
RESULT container_top_level typeof_before=27(Dictionary) typeof_after=27(Dictionary)
RESULT container_field_m typeof_before=3(float) typeof_after=3(float) value_before=2.0 value_after=2.0 value_equal=true bit_equal=true
RESULT container_field_t typeof_before=2(int) typeof_after=2(int) value_before=10 value_after=10 value_equal=true
RESULT container_field_c typeof_before=2(int) typeof_after=2(int) value_before=3 value_after=3 value_equal=true
RESULT container_field_pair typeof_before=4(String) typeof_after=4(String) value_equal=true
RESULT container_field_source typeof_before=4(String) typeof_after=4(String) value_equal=true
RESULT container_field_campaign_tick_marks typeof_array_before=28(Array) typeof_array_after=28(Array) elem0_typeof_before=2(int) elem0_typeof_after=2(int) value_equal=true
RESULT container_field_death_marks typeof_before=27(Dictionary) typeof_after=27(Dictionary) key_typeof_before=4(String) key_typeof_after=4(String) value_typeof_before=2(int) value_typeof_after=2(int) value_equal=true
RESULT VERDICT_m_strict_TYPE_FLOAT_after_container_roundtrip = true
RESULT VERDICT_t_strict_TYPE_INT_after_container_roundtrip = true
RESULT VERDICT_c_strict_TYPE_INT_after_container_roundtrip = true

--- 5: special float values (INF/-INF/NAN) ---
RESULT special_INF typeof_before=3(float) typeof_after=3(float) value_equal=true is_inf_after=true is_finite_after=false
RESULT special_NEG_INF typeof_before=3(float) typeof_after=3(float) value_equal=true is_inf_after=true is_finite_after=false
RESULT special_NAN typeof_before=3(float) typeof_after=3(float) is_nan_after=true naive_equal_would_be=false is_finite_after=false

=== PROBE VR12 COMPLETE ===
```

### `logs/run2-unfiltered.txt`(逐字,與 run1 相同部分不重複貼,只列出多出的 2b 區塊——完整檔案見 `logs/run2-unfiltered.txt`)

```
--- 2b: follow-up isolation -- is the smallest-magnitude literal already 0.0 at parse time? ---
RESULT literal_parse_subnormal_min literal=4.9406564584124654e-324 typeof=3(float) value=0.0 hex=0000000000000000 is_zero=true
RESULT literal_parse_normal_min literal=2.2250738585072014e-308 typeof=3(float) value=0.0 hex=0000000000000000 is_zero=true
RESULT literal_parse_subnormal_mid literal=1.0e-310 typeof=3(float) value=0.0 hex=0000000000000000 is_zero=true
```

（`diff logs/run1-unfiltered.txt logs/run2-unfiltered.txt` 的完整輸出已於探針設計節
引用;上面五行——含標題行與尾隨空行——就是全部差異,其餘逐字相同。）

兩輪執行皆 `EXIT_RUN=0`,`--import` 步驟(`logs/00-import.txt`)亦 `EXIT_IMPORT=0`,
過程中零 `ERROR`/`SCRIPT ERROR`/`Parse Error` 訊息。

## 結論

**以下判定全部只依據上面逐字 log,未外推。**

1. **`m` 嚴格 `TYPE_FLOAT` 這條拒絕規則(R7E-10)的前提,在本探針測過的所有情況下
   成立**——`RESULT VERDICT_m_strict_TYPE_FLOAT_after_container_roundtrip = true`
   (測項 4,用 ADR-0002 `export_state()` 的實際容器形狀測);測項 1 的四個
   float 字面量(含 `2.0`、`0.0`、`-1.0` 這種數值上與 int 相等的邊界情況)與測項
   2 的非整數值,`typeof_after` 全部是 `3(float)`,無一還原成 `2(int)`。
   **在本探針測到的範圍內,這條規則不會把合法存檔誤判為損毀**——因為前提
   (float 進去、float 出來,不會被序列化過程本身改變型別)在這些具體數值上成立。
   ⚠️ **範圍限定(推論,未量測)**:本探針測的是「值在合法值域內」的 float;
   ADR-0002 R7E-10 條文本身承認的風險來源是「人工編輯或位元損壞」,那類輸入本來
   就不是 `var_to_bytes()` 的合法輸出,不在本探針的測試範圍,也不需要在這裡測——
   本探針只關掉「合法輸出會不會被序列化過程本身改成別的型別」這個問題。

2. **`t`/`c` 嚴格 `TYPE_INT` 的同一結論,方向對稱且同樣成立**——
   `RESULT VERDICT_t_strict_TYPE_INT_after_container_roundtrip = true`、
   `RESULT VERDICT_c_strict_TYPE_INT_after_container_roundtrip = true`(測項 4);
   測項 3 的四個 int 值(含超過 32 位元的 `9007199254740993`)`typeof_after` 全部
   是 `2(int)`。同樣的範圍限定適用。

3. **本探針測到會改變 ADR-0002 機制八設計的東西:沒有。** 型別往返在測過的所有
   案例中(整數值 float、非整數值 float、極端量級、int、容器巢狀形狀、特殊值)
   皆完整保真,沒有出現任何需要修改機制八驗證邏輯的落差。

4. **NAN/INF 往返後,`is_finite()` 的行為**——測項 5(`logs/run1-unfiltered.txt`
   第 37-39 行、`run2-unfiltered.txt` 第 42-44 行)直接測到:`INF`、`-INF`、`NAN`
   三者往返後 `typeof()` 皆仍為 `3(float)`(不是被序列化過程改成別的型別),且
   `is_finite()` 對三者的回傳值皆為 `false`。**這足以支持一個窄敘述**:機制八
   「`m` 非零且有限」的值域檢查,若收到一個經 `var_to_bytes()`/`bytes_to_var()`
   往返過的 `INF`/`-INF`/`NAN`,`is_finite()` 會正確判定其為非有限值——本探針
   **關閉了「往返本身會不會讓 `is_finite()` 誤判」這個窄問題**。
   ⚠️ **未關閉、不外推的部分**:本探針**沒有**測 `is_finite()` 對型別錯配輸入
   (例如 `String`)的行為——那是 XCHECK-4 已測過的既有結論(`docs/architecture/adr-0002-...-contract.md`
   第 661 行,`is_finite(v)` 對 `String` 型 `v` 會中止所在函式),與本探針測的
   「同型別、往返後的特殊值」是兩個不同的問題,本探針不重複也不擴大那個結論。

5. **意外測到的獨立現象(與 `var_to_bytes()` 無關,不構成對序列化 API 的任何指控)**:
   測項 2b(`run2-unfiltered.txt` 第 17-20 行)量到 —— GDScript 4.7.1 中,
   `4.9406564584124654e-324`(次正規化 double)、**`2.2250738585072014e-308`
   (IEEE754 正規化 double 的最小值,不是次正規化值)**、以及 `1.0e-310` 三個
   float 字面量,**在單純的變數宣告階段**(全程零 `var_to_bytes()`/`bytes_to_var()`
   呼叫)就已經是 `0.0`(`hex=0000000000000000`)。這是**字面量解析階段**的現象,
   **不是序列化往返階段**的現象——測項 2 與測項 4 已經證明合法 float 值通過
   `var_to_bytes()`/`bytes_to_var()` 是位元級保真的;這裡量到的是那些值**在被
   序列化之前,字面量本身就已經是 `0.0`**。⚠️ **推論,未進一步量測**:這暗示
   GDScript 4.7.1 的浮點字面量解析器對極小量級(至少到 `1e-308` 這個量級,包含
   正規化範圍內的值)存在不明原因的下溢,但**根本原因未查**(未讀 tokenizer/
   parser 原始碼、未测是否為 locale 相關、未測是否只影響字面量而不影響執行期
   運算結果),**不屬於本次 ADR-0002 VR#12 的驗證範圍**,故不在此下結論,只如實
   記錄現象與建議(見下)。

## 未涵蓋

- **release 建置**:本探針與本專案目前所有序列化探針一樣,只在 debug/headless
  建置下執行(`%APPDATA%/Godot/export_templates/` 為空,無法匯出 release 建置)。
  `docs/engine-reference/godot/modules/core-serialization.md` 未查證表第 1 項已
  登記此缺口,本探針的往返保真結論同樣繼承這個限制,不重複記帳。
- **`float` 之外的其他數值型別往返**(例如 `Vector2`/`Color` 等複合數值型別)——
  ADR-0002 機制八只涉及純量 `int`/`float`,本探針刻意只測這兩者。
- **型別錯配輸入下的 `is_finite()`/`is_nan()`/`is_inf()` 行為**——如結論 4 所述,
  這是既有結論(XCHECK-4),本探針不重測也不藉此擴大既有結論的範圍。
- **極小量級 float 字面量下溢的根本原因**——如結論 5 所述,已記錄現象但未查根因,
  且判定它落在本探針的範圍之外(它發生在字面量解析階段,不影響 `var_to_bytes()`/
  `bytes_to_var()` 往返保真這個 VR#12 要回答的問題本身)。
- **並發情境下的序列化往返**——ADR-0002 機制八對 `import_state()`/
  `validate_semantics()` 的呼叫時機有 Mutex 相關約定,但本探針只測單執行緒下的
  純函式呼叫,不測併發讀寫時序列化是否受影響。
- **ADR-0003 整個二進位 Variant 序列化格式決策的 Knowledge Risk 分級**——本探針
  **沒有、也不試圖**降低 ADR-0003 自陳的 Knowledge Risk HIGH 評級。本探針測的
  範圍窄得多:只驗證 ADR-0002 自己在機制八用到的兩個具體欄位形狀(純量
  `int`/`float`,含 ADR-0002 實際的容器巢狀結構)在型別往返上的行為,不是
  ADR-0003 選擇二進位 Variant 序列化這個格式決策本身涉及的所有其他面向(見
  `docs/engine-reference/godot/modules/core-serialization.md` 第 2-11 節列出的
  其他既有發現,例如 Object 靜默編碼、Dictionary 鍵順序敏感等——那些與本探針測的
  int/float 型別往返是完全不同的問題,本探針不代為記帳,也不藉由關閉窄問題去
  暗示寬問題已一併關閉)。
