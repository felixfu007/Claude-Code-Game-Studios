## 本地化 key 查找 API —— 封裝 Godot 內建 [TranslationServer] 翻譯管線，加一層
## 「絕不讓裸 key 字串出現在玩家畫面上」的防呆層。
##
## [b]工作單[/b]:`production/epics/localization-infrastructure/story-001-core-lookup-api-and-locale-structure.md`
## D 節。本類別只負責 D 節(key 查找 API + fallback 行為)；locale 檔案結構與
## `project.godot` 設定（A~C 節）由 `godot-specialist` 同批完成。
##
## [b]為什麼封裝既有管線而不是自建查找表[/b](D 節第一條要求記錄理由)：Godot 的
## CSV 匯入 -> [Translation] 資源 -> [TranslationServer] 這條原生管線已經是本專案
## 引擎版本原生支援、且已實機驗證可用的材料（見
## `production/epics/localization-infrastructure/EPIC.md` Q1：「Godot 內建 tr() 函式 +
## TranslationServer + CSV 為底的 Translation 資源，是引擎原生管線，不是要自建的東西」）。
## 自建一份平行的 key -> 字串查找表，會製造本專案已登記過的失效模式 —— 「同一個規則
## 兩份實作，只是今天答案一致」（`design/art/screen-architecture.md` 的曼哈頓距離重複
## 案例）；而引擎原生管線唯一缺的安全網，是「key 打錯字時原樣回傳 key 字串」——這個洞
## 用一層薄殼堵住即可，不必重建整條管線。
##
## [b]為什麼對外方法叫 [method localize]、不叫 [code]tr[/code][/b]（引擎硬限制，不是
## 命名偏好）：本類別 [code]extends RefCounted[/code]，而 [RefCounted] 繼承自 [Object]，
## [Object] 本身原生定義了實例方法 [method Object.tr]。GDScript 不允許用
## [code]static func[/code] 覆寫一個繼承而來的非 static 方法 —— 實際嘗試會直接
## parse error（`Parse Error: The function signature doesn't match the parent` +
## `The method "tr()" overrides a method from native class "Object"`），不只是
## 「內部呼叫會遞迴」這種執行期風險。證據見
## `prototypes/godot-gdscript-specialist-i18n-story001-d-probe-2026-10-05/README.md`
## 「🔴 連帶發現」節（`shadow_check/run_output_FAILED_named_tr.txt`）。本實作改用
## [method TranslationServer.translate]（與 [method Object.tr] 底層同一條管線、
## 行為逐字一致，但暴露在不同物件上，呼叫它不經過本類別自己的方法表，沒有撞名風險）。
##
## [b]已實機驗證（2026-10-05，godot-gdscript-specialist，headless，從正式專案根目錄
## 啟動，project.godot 既有 [code][internationalization][/code] 設定自動生效，未使用
## 任何替身場景或替身資料）[/b]：
## `prototypes/godot-gdscript-specialist-i18n-story001-d-probe-2026-10-05/`
## 1. 階層式 dot-notation key（例如 [code]battle.hud.status_format[/code]）可直接作為
##    查找參數，句點字元不會造成截斷或誤判成巢狀路徑 —— 兩個既有 CSV key 皆逐字命中
##    CSV 裡登記的翻譯內容。
## 2. 對一個完全不存在於任何已註冊語系的 key 呼叫查找，回傳值是「原樣回傳 key 字串
##    本身」（不論 key 是否含句點），不是空字串、也不是 null —— [method localize]
##    存在的唯一理由就是攔截這個行為。
class_name Loc
extends RefCounted

## debug build 下，查無翻譯時回傳的可辨識佔位標記前後綴（而不是回傳裸 key 本身）。
## 刻意使用一般文字與正常 key 命名慣例不會出現的符號包住 key，讓缺字在畫面上一眼可辨識，
## 不會被誤認成正常文字或正常 key 名稱。
const _MISSING_KEY_DEBUG_PREFIX: String = "⟦MISSING:"
const _MISSING_KEY_DEBUG_SUFFIX: String = "⟧"

## release build 下，查無翻譯時回傳的值 —— 空字串。依
## `production/epics/localization-infrastructure/EPIC.md` Q3「絕不對玩家顯示裸 key」
## 與本 story D 節「release build 顯示空字串或其他明確定義行為」，由本類別拍板選空字串
## （而非另一種佔位文字）：空字串不會在任何版面上產生一段看起來像是刻意設計、實際是
## 缺字症狀的雜訊文字。
const _MISSING_KEY_RELEASE_VALUE: String = ""


## 查找 [param key] 對應的本地化字串，絕不回傳裸 key 字串本身。
##
## 底層呼叫 [method TranslationServer.translate]（本專案原生本地化管線，見類別文件
## 註解）。若回傳值與 [param key] 字面相同 —— 這是已實機驗證的「查無翻譯」訊號（見
## 類別文件註解第 2 點）—— 則視為缺字，改回傳依 build 型態決定的明確定義替代值，並以
## [method @GlobalScope.push_error] 記錄，讓缺字在開發期間大聲可見、不會被靜默吞掉。
##
## 回傳值一律是已查找或已替換過的純顯示字串；若該 key 對應的翻譯內容含 `%` 格式化
## 佔位符（例如 CSV 裡 [code]battle.hud.status_format[/code] 的值是
## [code]第 %d 回合．%s[/code]），格式化由呼叫端自行用 [code]% [args][/code] 處理，
## 本方法不代為格式化 —— 這與 [method Object.tr] 原本的分工一致，呼叫端不需要改寫
## 既有的格式化慣用語法。
##
## [b]已知限制（刻意不處理，誠實揭露）[/b]：若某個 key 的「正確翻譯」字面上恰好與
## key 字串本身相同，本方法會誤判為缺字並換成佔位值。本專案目前的 key 命名慣例
## （階層式 dot-notation，如 [code]battle.hud.status_format[/code]）與人類可讀的中文
## 翻譯內容在字面上不可能相同，故此情境在本專案現有資料下不會發生；但若未來新增的 key
## 命名方式改變（例如直接把中文句子本身當 key），需要重新檢視這個假設是否仍然成立。
static func localize(key: StringName) -> String:
	var result: String = String(TranslationServer.translate(key))
	if is_missing(key, result):
		push_error("Loc.localize(): 缺少本地化翻譯，key = \"%s\"" % String(key))
		return _missing_key_fallback(key, OS.is_debug_build())
	return result


## 純邏輯判定：給定 [param key] 與它實際查找出的 [param result]，判斷這是不是「查無
## 翻譯、原樣回傳 key」的情況。抽出成獨立函式是為了讓測試可以直接斷言這個判斷邏輯
## 本身，不必每次都繞經 [method localize] 的 build 型態分支（debug 佔位符 vs. release
## 空字串）。
static func is_missing(key: StringName, result: String) -> bool:
	return result == String(key)


## 依 [param is_debug_build] 決定缺字時的替代字串。刻意拆成接受明確布林參數的純函式，
## 不在內部直接呼叫 [method OS.is_debug_build]，是為了讓 debug/release 兩條分支都能在
## 單元測試裡直接斷言 —— 依 `.claude/docs/coding-standards.md`「All public methods must
## be unit-testable (dependency injection over singletons)」。沒有這層拆分的話，
## release 分支在 headless 編輯器測試環境裡永遠無法被走到（`OS.is_debug_build()`
## 在本專案已實機驗證的測試環境下恆為 true，見
## `prototypes/godot-gdscript-specialist-i18n-story001-d-probe-2026-10-05/run_output_headless.txt`
## 的 `Q_setup: OS.is_debug_build() = true`），會重演本專案已登記的「headless 下某些
## 引擎狀態恆為固定值，一條分支永遠測不到」那類陷阱（`.claude/docs/coding-standards.md`
## 「What NOT to Automate」節的 `Input.mouse_mode` 案例）。[method localize] 是唯一的
## 正式呼叫端，傳入真正的 [method OS.is_debug_build] 結果；本函式本身不直接依賴引擎
## build 狀態，因此不需要實際進入一個 release 匯出建置就能測到兩條分支。
static func _missing_key_fallback(key: StringName, is_debug_build: bool) -> String:
	if is_debug_build:
		return _MISSING_KEY_DEBUG_PREFIX + String(key) + _MISSING_KEY_DEBUG_SUFFIX
	return _MISSING_KEY_RELEASE_VALUE
