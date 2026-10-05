# Story 001 D 節實機驗證探針(2026-10-05,godot-gdscript-specialist)

對應 `production/epics/localization-infrastructure/story-001-core-lookup-api-and-locale-structure.md`
的 D 節兩項「🔴 實機驗證」要求。**不重跑** `godot-specialist` 2026-09-29 已完成的 Q1 探針
(`prototypes/godot-specialist-i18n-locale-probe-2026-09-29/`)——CSV 匯入器行為、
`project.godot` 鍵名直接引用那份材料。

## 執行方式

```bash
# 前置:確保 .translation 已由 CSV 匯入產生(本機 .translation 不進版控)
"<Godot 4.7.1 執行檔>" --headless --path . --import

# 探針本體
"<Godot 4.7.1 執行檔>" --headless --path . -s prototypes/godot-gdscript-specialist-i18n-story001-d-probe-2026-10-05/probe.gd
```

原始輸出:`run_output_headless.txt`(同目錄,逐字保留,未編輯)。

## 結論(對照工作單 D 節逐條)

### 題目一:`tr()` 能否直接用階層式 dot-notation key

**可以,句點不會造成截斷或誤判成巢狀路徑。** 從正式專案根目錄啟動(`--path .`),
`project.godot` 既有 `[internationalization]` 設定自動生效,未使用任何替身場景或替身資料
——量到的是 production 實際會發生的狀況:

```
Q1a: tr(&"battle.hud.status_format") = [第 %d 回合．%s]
Q1a: matches CSV value verbatim? = true
Q1b: tr(&"battle.menu.leave_confirm_title") = [離開遊戲?]
Q1b: matches CSV value verbatim? = true
```

兩個既有 CSV key 本身就是 dot-notation,逐字命中 CSV 登記的翻譯內容,不需要另外在 CSV
裡新增一個人工的 dot-notation 測試 key。

### 題目二:完全不存在的 key,`tr()` 的預設回傳值是什麼

**原樣回傳 key 字串本身**(不是空字串、不是 null),不論 key 是否含句點:

```
Q2: tr(&"this.key.does.not.exist.anywhere") = [this.key.does.not.exist.anywhere]
Q2: result == key string itself (bare-key echo)? = true
Q2: result.is_empty() = false
Q3: tr(&"nonexistentkeynodot") = [nonexistentkeynodot]
Q3: result == key string itself (bare-key echo)? = true
```

**這就是 `Loc` 類別存在的理由**——不包薄殼的話,打錯字的 key 會原樣顯示在玩家畫面上。

### 題目四/五(實作過程中發現,非原始交辦項,但不處理會寫出壞程式碼):

### 🔴 `Loc` 不能讓自己的靜態方法直接取名 `tr` 然後內部呼叫裸 `tr(key)`

`Loc` 計畫 `extends RefCounted`,而 `RefCounted` 繼承自 `Object`,`Object` 本身就定義了
`tr()` 方法(非 `@GlobalScope` 自由函式,是 `Object` 的實例方法,一般腳本能裸寫
`tr("key")` 是因為隱含呼叫了 `self.tr(...)`)。若 `Loc.tr()` 內部呼叫裸 `tr(key)`,
GDScript 方法解析會先找到 `Loc` 自己宣告的同名方法,等於**無限遞迴呼叫自己**,
不會真的呼叫到引擎翻譯邏輯。這不是臆測——是先寫出這個形狀的程式碼後才會在遞迴或
堆疊溢位時發現的陷阱,探針在動手寫實作前就排除了它。

**解法**:`TranslationServer` 有獨立的 `translate()` 方法,行為與 `Object.tr()` 完全一致
(兩者底層走同一條管線,只是暴露在不同物件上),呼叫它不經過 `Loc` 自己的方法表,
沒有遮蔽/遞迴風險:

```
Q4: TranslationServer.has_method("translate") = true
Q4: TranslationServer.translate(&"battle.hud.status_format") = [第 %d 回合．%s]
Q4: typeof result = 21   (TYPE_STRING_NAME)
Q5: TranslationServer.translate(&"this.key.does.not.exist.anywhere") = [this.key.does.not.exist.anywhere]
Q5: result == key string itself (bare-key echo)? = true
```

題目五確認:`TranslationServer.translate()` 對缺字 key 的行為與 `Object.tr()` 逐字一致
(同樣原樣回傳 key),故題目二/三的結論可以安全套用到 `Loc.tr()` 實際呼叫的那個方法上,
不是驗證了 A 方法的行為、卻用在 B 方法上。

`TranslationServer.translate()` 回傳型別是 `StringName`(`typeof` = 21),`Loc.localize()`
對外簽章保持 `-> String`,內部做顯式轉型。

### 🔴 連帶發現:封裝方法不能命名為 `tr`,會直接 parse error(不只是遞迴風險)

**比上面「會無限遞迴」更嚴重**——實際編譯都過不了。`Loc extends RefCounted`,
`RefCounted` 繼承自 `Object`,`Object` 原生定義了實例方法 `tr(message, context='')`。
GDScript 不允許用 `static func` 覆寫一個繼承而來的非 static 方法,即使簽章看起來相容:

```
$ cat prototypes/godot-gdscript-specialist-i18n-story001-d-probe-2026-10-05/shadow_check/shadow_probe_FAILED_named_tr.gd
class_name ShadowProbeLocFailed
extends RefCounted

static func tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))

$ "<godot>" --headless --path . --check-only --script .../shadow_probe_FAILED_named_tr.gd
SCRIPT ERROR: Parse Error: The function signature doesn't match the parent. Parent signature is "tr(StringName, StringName = <default>) -> String".
SCRIPT ERROR: Parse Error: The method "tr()" overrides a method from native class "Object". This won't be called by the engine and may not work as expected. (Warning treated as error.)
ERROR: Failed to load script ... with error "Parse error".
exit 1
```
（原始輸出:`shadow_check/run_output_FAILED_named_tr.txt`)

改名為 `localize()` / `is_missing()`(不與 `Object`/`RefCounted` 任何繼承方法撞名)後,
同一套 `--check-only` 乾淨通過,零輸出、exit 0:

```
$ "<godot>" --headless --path . --check-only --script .../shadow_probe_PASSED_named_localize.gd
exit 0
```
（原始輸出:`shadow_check/run_output_PASSED_named_localize.txt`)

**結論:正式 API 命名為 `Loc.localize(key)`,不是 `Loc.tr(key)`。** 這不是風格偏好,
是引擎層面的硬限制——`tr` 這個名字在任何繼承 `Object` 的類別上都被原生方法佔用。

## 本探針未涵蓋

- `OS.get_locale()` / `OS.get_locale_language()` 匯出建置平台驗證——明文屬工作單 E 節,
  `godot-specialist` 的職責,本探針不重複。
- CSV 的 context 欄、複數形式——本專案 CSV 目前未使用這兩欄,未測試。
- 本探針在 headless **編輯器** 環境執行,`OS.is_debug_build() = true`;匯出建置
  (debug/release 兩種 export template)下此值是否不同,本探針未驗證,`Loc` 的
  debug/release 分支行為因此只在此環境下被證實過。
