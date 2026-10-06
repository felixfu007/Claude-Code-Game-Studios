## Story U-014（`production/epics/card-play-interface/story-u014-confirm-panel.md`）
## — 確認面板(S3):打牌流程唯一的不可逆寫入點的顯示層
## (`design/ux/skill-card-play.md`「確認面板欄位」節,2026-09-10 管理者裁決)。
## 逐欄拆解甲類/丙類的效果,並落實該節的三項合規重點:
##   1. 甲類「合併後有效值不得取代逐條那一列」——兩者永遠並列顯示。
##   2. 丙類「作用對象」必須回顯玩家在 S2p/S2q 的實際選取,不得從卡片欄位讀
##      (呼叫端 battle_screen.gd 的職責,本檔本身不能也不做這個檢查)。
##   3. 丙類好感度數值以「現值 → 打完後」箭頭呈現,恰好一次——AC-U14。
##
## [b]本檔完全不引用 [Card]/[CardModifier]/[Unit]/[AffinityLink][/b] —— 與
## [HandBar] 的既有紀律相同(`.claude/rules/ui-code.md`:「UI must NEVER own or
## directly modify game state — display only」;`hand_bar.gd` 類別文件註解:
## 「defines its own display-only vocabulary...rather than the gameplay enum it
## is ultimately fed from」)。[enum Category] 是本檔自己的顯示用詞彙,不是
## [enum Card.Category]。battle_screen.gd(「同時認得雙方」的那一個類別,對
## [BoardView]/[HandBar] 皆是如此)才是唯一知道 [Card]/[Unit] 真實形狀的地方。
##
## [b]確認/取消輸入由 battle_screen.gd 分派,本檔不覆寫 [method Node._input][/b]
## —— 同 [HandBar] 的既有分工(其選牌游標移動是被外部呼叫的
## [method HandBar.move_cursor] 驅動,不是自己讀鍵盤)。本檔只暴露三個顯示用
## 公開入口:[method show_temporary_modifier_confirmation]、
## [method show_permanent_write_confirmation]、[method hide_panel]。
##
## [b]2026-09-24 管理者裁決:丙類好感度欄位「維持留白＋提示」[/b] ——
## `combat_strength_read`(UX-13)不接上任何真實資料來源。[method
## show_permanent_write_confirmation] 的 [param strength_available] 參數是
## 為日後接上真值預留的注入點(呼叫端 battle_screen.gd 那個具名、可注入的
## Callable 欄位是實際的接縫;本檔只負責「給了值就畫箭頭,沒給就畫提示」這個
## 純顯示分支),本story 不會、也不應該把它接上任何資料來源。
##
## [b]版面尺寸是本檔自己的判斷,不是規格逐字寫死的數字[/b](同
## `hud_layout.gd` / `battle_menu.gd` 對這類常數的既有揭露慣例)——規格只定了
## 要顯示哪些欄位(「確認面板欄位」節),沒有定尺寸。截圖/像素驗證本批不做
## (`coding-standards.md` 截圖規則本批不適用 UI 型 ADVISORY 證據,且管理者
## 明文本機不得開窗)。
class_name CardConfirmPanel
extends Control

## Which of the two MVP card categories the panel is currently showing — this
## file's own display vocabulary (see class doc comment). [constant NONE] is
## the panel's at-rest / hidden state.
enum Category { NONE, TEMPORARY_MODIFIER, PERMANENT_WRITE }

const HUD_FONT: FontFile = preload("res://assets/fonts/Cubic_11.ttf")

## Panel background size, in [method HudLayout.font_size] multiples — mirrors
## `battle_menu.gd`'s `PANEL_WIDTH_FPX_MULTIPLIER` / `PANEL_HEIGHT_FPX_MULTIPLIER`
## convention exactly. This file's own placeholder judgment (class doc
## comment) — tall enough for 丙類's five stacked rows or 甲類's six, at the
## smallest supported window (960x540, N=2).
const PANEL_WIDTH_FPX_MULTIPLIER: float = 24.0
const PANEL_HEIGHT_FPX_MULTIPLIER: float = 18.0

## Inner content margin / row gap, in fpx — mirrors `battle_menu.gd`'s
## `CONTENT_MARGIN_FPX_MULTIPLIER` convention.
const CONTENT_MARGIN_FPX_MULTIPLIER: float = 0.6
const ROW_GAP_FPX_MULTIPLIER: float = 0.3

## Mirrors `battle_menu.gd`'s own `PANEL_BG_COLOR` / `MASK_COLOR` — this panel
## is the same "模態" vocabulary (`skill-card-play.md` Component Inventory:
## 確認面板 | 模態 | ... | P-M1), so it reuses the same visual language rather
## than inventing a second one.
const PANEL_BG_COLOR: Color = Color(0.10, 0.10, 0.12, 0.92)
const MASK_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)

const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const WARNING_COLOR: Color = Color(1.0, 0.75, 0.3, 1.0)

## 🔴 Story-002 migration
## (`production/epics/localization-infrastructure/story-002-migrate-existing-hardcoded-strings.md`)
## — every constant in this block is now a [StringName] KEY into
## `assets/data/locales/strings.csv`, not the literal display text itself.
## Every read site wraps the constant in [method Loc.localize] to get the
## actual text.
##
## Implementation Note 2 — 「永久」不可逆警示文字+圖示(圖示以既有字符表示,
## 同 [HandBar] 的既有作法:組合既有字元/圖元,不新增 PNG 資產 — UX-3 卡面
## 美術未定前的既有慣例)。
const TEXT_PERMANENT_WARNING: StringName = &"battle.card_confirm.permanent_warning"

## Implementation Note 2 — 「敘事影響」固定為一句定性文字,沿用 Z3 既有文案
## (`skill-card-play.md` Component Inventory「定性提示(Z3)」列)。
const TEXT_NARRATIVE: StringName = &"battle.card_confirm.narrative"

## UX-13 / 2026-09-24 管理者裁決「維持留白＋提示」——`skill-card-play.md`
## 「查無資料時的處理」表:「留白 + 同一句提示,不得顯示 0 或省略欄位」。
const TEXT_STRENGTH_UNAVAILABLE: StringName = &"battle.card_confirm.strength_unavailable"

const TEXT_NO_EXISTING_MODIFIERS: StringName = &"battle.card_confirm.no_existing_modifiers"

## AC-U14 的箭頭字面量——「現值 → 打完後」的分隔符。[method format_strength_arrow]
## 是本檔唯一產生它的地方,[method text_uses_required_arrow_format] 是唯一
## 檢查它的地方,兩者共用同一個常數,不各自寫一份字面量。
##
## 🔴 Story-002 決定:**納入遷移範圍**(工作單 AC 第二條明文把決定權交給實作者,
## 並要求記錄理由)。判斷依據:雖然它在排版上接近「箭頭符號」而非一句話,但
## (1) `.claude/rules/ui-code.md` 的規則本身沒有替「符號」開一個不算 UI 文字的
## 例外 ——「no hardcoded user-facing strings」逐字涵蓋任何會出現在玩家畫面上的
## 字元;(2) 這個字串同時是解析用的分隔符(見 [method text_uses_required_arrow_format]
## 的 [method String.split] 呼叫),保持它是「單一常數、單一出處」比起分裂成
## 「顯示用 key + 解析用常數」兩份更安全 —— 納入 key 系統後兩邊仍然共用同一個
## 常數,只是常數現在存的是 key 而非字面值,原本的「不各自寫一份字面量」保證
## 不受影響;(3) 若未來語言的排版慣例需要不同的符號或間距(例如某些語言偏好
## 全形箭頭,或排版方向需要調整間距),key 系統讓翻譯者能直接調整,不必改程式碼。
const ARROW_GLYPH: StringName = &"battle.card_confirm.arrow_glyph"

## 🔴 Story-002 追加(優先序 2,管理者裁決「現在就補完」)—— 下列 8 個常數是
## [method show_temporary_modifier_confirmation] / [method show_permanent_write_confirmation]
## 函式本體內原本直接內嵌(非 `const` 宣告)的繁體中文格式化字串,不在原始 30 個
## 常數清單裡,也因此沒有被「零殘留」grep(只抓 `^const [A-Z_]+: String = "`)
## 抓到過。性質與上面 5 個常數相同:玩家看得到、該走 key 系統。
const TEXT_TARGET_FORMAT_SINGLE: StringName = &"battle.card_confirm.target_format_single"
const TEXT_DELTA_ATK_FORMAT: StringName = &"battle.card_confirm.delta_atk_format"
const TEXT_DELTA_DEF_FORMAT: StringName = &"battle.card_confirm.delta_def_format"
const TEXT_DURATION_FORMAT: StringName = &"battle.card_confirm.duration_format"
## 丙類「作用對象」雙目標格式(「A ↔ B」)——與 [constant TEXT_TARGET_FORMAT_SINGLE]
## 分開宣告,不共用一個 key:前者只有一個 [code]%s[/code],本常數有兩個
## ([code]%s ↔ %s[/code]),合併會讓其中一種呼叫方式格式化出錯。
const TEXT_TARGET_FORMAT_PAIR: StringName = &"battle.card_confirm.target_format_pair"
## [method show_temporary_modifier_confirmation] 逐條既有修正的單行格式——
## 「來源：ATK ±n／DEF ±n，剩 n 回合」。
const TEXT_EXISTING_MODIFIER_LINE_FORMAT: StringName = &"battle.card_confirm.existing_modifier_line_format"
const TEXT_EFFECTIVE_FORMAT: StringName = &"battle.card_confirm.effective_format"
## 丙類「好感度」欄位的外層標籤格式——包住 [method format_strength_arrow] 的輸出
## 或 [constant TEXT_STRENGTH_UNAVAILABLE] 佔位提示,兩者皆可代入同一個
## [code]%s[/code]。
const TEXT_STRENGTH_LABEL_FORMAT: StringName = &"battle.card_confirm.strength_label_format"

var _category: Category = Category.NONE

var _mask: ColorRect
var _background: ColorRect
var _content: VBoxContainer
var _title_label: Label
var _target_label: Label
var _delta_atk_label: Label
var _delta_def_label: Label
var _duration_label: Label
var _existing_modifiers_label: Label
var _effective_label: Label
var _permanent_warning_label: Label
var _strength_label: Label
var _narrative_label: Label

## Every label built by [method _ensure_nodes], populated once — iterated by
## [method _apply_layout] so font-size overrides live in exactly one place.
var _labels: Array[Label] = []

## Story U-014 — one formatted line per entry in the most recent
## [method show_temporary_modifier_confirmation]'s [param existing_modifiers],
## exposed via [method diagnostic_existing_modifier_line] so a test can assert
## a SPECIFIC entry rather than parsing [member _existing_modifiers_label]'s
## joined text.
var _existing_modifier_lines: Array[String] = []

## Story U-014 (AC-U14 discriminator) — the exact text currently shown for
## 丙類's strength row, whatever it is (arrow-formatted or the UX-13
## unavailable placeholder). See [method diagnostic_strength_text].
var _strength_text: String = ""


func _ready() -> void:
	visible = false
	_ensure_nodes()
	_apply_layout()
	get_window().size_changed.connect(_apply_layout)


## Implementation Note 1 — 甲類確認面板欄位,逐欄轉錄(`skill-card-play.md`
## 「確認面板欄位」節):卡名與牌面文字、作用對象、`Δatk`/`Δdef`(帶號,`0`
## 仍顯示)、存續回合 `r`、該對象生效中的既有修正逐條、合併後有效值。
## 🔴 合併後有效值不得取代逐條那一列(GDD UI Requirements #7)——
## [param existing_modifiers] 與 [param effective_atk]/[param effective_def]
## 兩者永遠同時顯示,呼叫端沒有任何方式只傳其中一個。
##
## [param existing_modifiers] — 每筆
## [code]{"source_name":String,"atk_delta":int,"def_delta":int,
## "remaining_turns":int}[/code],呼叫端從 [method Unit.active_modifiers] 映射
## 而來(本檔不引用 [CardModifier] 本身,見類別文件註解)。空陣列合法(代表
## 該對象目前無生效中修正),不是資料缺失,顯示 [constant TEXT_NO_EXISTING_MODIFIERS]
## 而非空白。
func show_temporary_modifier_confirmation(
	card_id: String,
	flavor_text: String,
	target_name: String,
	delta_atk: int,
	delta_def: int,
	duration_rounds: int,
	existing_modifiers: Array[Dictionary],
	effective_atk: int,
	effective_def: int
) -> void:
	_category = Category.TEMPORARY_MODIFIER
	_title_label.text = _format_title(card_id, flavor_text)
	_target_label.text = Loc.localize(TEXT_TARGET_FORMAT_SINGLE) % target_name
	_delta_atk_label.text = Loc.localize(TEXT_DELTA_ATK_FORMAT) % format_signed(delta_atk)
	_delta_def_label.text = Loc.localize(TEXT_DELTA_DEF_FORMAT) % format_signed(delta_def)
	_duration_label.text = Loc.localize(TEXT_DURATION_FORMAT) % duration_rounds

	_existing_modifier_lines = []
	var existing_modifier_line_format: String = Loc.localize(TEXT_EXISTING_MODIFIER_LINE_FORMAT)
	for entry: Dictionary in existing_modifiers:
		_existing_modifier_lines.append(
			existing_modifier_line_format % [
				entry.get("source_name", ""),
				format_signed(int(entry.get("atk_delta", 0))),
				format_signed(int(entry.get("def_delta", 0))),
				int(entry.get("remaining_turns", 0)),
			]
		)
	_existing_modifiers_label.text = (
		Loc.localize(TEXT_NO_EXISTING_MODIFIERS) if _existing_modifier_lines.is_empty()
		else "\n".join(PackedStringArray(_existing_modifier_lines))
	)
	_effective_label.text = Loc.localize(TEXT_EFFECTIVE_FORMAT) % [effective_atk, effective_def]

	_set_row_visibility(true)

	visible = true
	_apply_layout()


## Implementation Notes 2/3 — 丙類確認面板欄位(同上節):卡名與牌面文字、
## 作用對象(配對雙方姓名,🔴 [param target_a_name]/[param target_b_name] 必須
## 來自玩家在棋盤上的實際選取,不得從卡片欄位讀——battle_screen.gd 的呼叫端
## 已依此紀律,本檔本身不作也不能作這個檢查)、「永久」不可逆警示、好感度數值
## (現值 → 打完後箭頭,恰好一次)、敘事影響(固定一句,零數字)。
##
## [param strength_available]/[param current_strength]/[param projected_strength]
## — UX-13:`combat_strength_read` 依 2026-09-24 管理者裁決「維持留白＋提示」,
## 不接上任何真實資料來源;呼叫端(battle_screen.gd)今天必然傳
## [code]strength_available = false[/code]。為 false 時不論後兩個參數傳什麼
## 都不顯示——顯示 [constant TEXT_STRENGTH_UNAVAILABLE] 佔位提示,不顯示 `0`,
## 也不省略這個欄位(見「查無資料時的處理」表)。
func show_permanent_write_confirmation(
	card_id: String,
	flavor_text: String,
	target_a_name: String,
	target_b_name: String,
	strength_available: bool,
	current_strength: int,
	projected_strength: int
) -> void:
	_category = Category.PERMANENT_WRITE
	_title_label.text = _format_title(card_id, flavor_text)
	_target_label.text = Loc.localize(TEXT_TARGET_FORMAT_PAIR) % [target_a_name, target_b_name]
	_permanent_warning_label.text = Loc.localize(TEXT_PERMANENT_WARNING)
	_strength_text = (
		format_strength_arrow(current_strength, projected_strength) if strength_available
		else Loc.localize(TEXT_STRENGTH_UNAVAILABLE)
	)
	_strength_label.text = Loc.localize(TEXT_STRENGTH_LABEL_FORMAT) % _strength_text
	_narrative_label.text = Loc.localize(TEXT_NARRATIVE)

	_set_row_visibility(false)

	visible = true
	_apply_layout()


## Closes the panel — reverses whatever the most recent [method
## show_temporary_modifier_confirmation] / [method show_permanent_write_confirmation]
## call set. Idempotent (calling this while already hidden is a harmless
## no-op).
func hide_panel() -> void:
	_category = Category.NONE
	visible = false


## Formats [param value] with an explicit leading sign — Implementation Note 1's
## "帶號,`0` 仍顯示" requirement ([code]0[/code] formats as [code]"+0"[/code],
## never bare [code]"0"[/code]).
static func format_signed(value: int) -> String:
	return "%+d" % value


## 🔴 2026-10-06 補強(協調者 review 抓到,Story-002 遷移的連帶後果)——
## [constant ARROW_GLYPH] 現在是 key,而 [method Loc.localize] 在 key 查無翻譯時
## 依 build 型態回傳不對稱的值(`src/core/i18n/loc.gd`:debug 回傳可辨識佔位符
## [code]⟦MISSING:...⟧[/code],**release 回傳空字串**)。[constant ARROW_GLYPH]
## 同時是顯示分隔符與(見 [method text_uses_required_arrow_format])解析分隔符,
## 而「查無翻譯時安靜回傳空字串」這個設計決定是 story-001 針對純顯示字串訂的,
## 從未考慮過「查找結果被拿去當解析分隔符」這種用法。
##
## **已實機驗證**(拋棄式探針,Godot 4.7.1 headless,
## `scratchpad/probe_empty_separator.gd`,不在版控內):
## [code]"+3+4".count("") == 0[/code](對任何輸入恆為 0,非當掉也非無限迴圈)、
## [code]"+3+4".split("", true, 1) == ["+", "3+4"][/code]。**但後者從未被執行到**——
## [method text_uses_required_arrow_format] 第一行就是 [code]count() != 1[/code]
## 守衛,空字串必定 [code]0 != 1[/code] 為真,函式在觸及 [method String.split] 之前
## 就已經結構性安全地回傳 [code]false[/code]。**真正沒有防護的是 [method
## format_strength_arrow]**:它會靜默把兩個數字直接串接成 [code]"+3+4"[/code]
## (無分隔符、容易誤讀成單一數字),而這條路徑只在 release 建置發生,玩家端
## 看不到任何提示([method Loc.localize] 內部的 [method push_error] 只有
## 開著主控台才看得到)。
##
## 下面這個共用解析函式是本次補強的核心:**顯示端與解析端永遠呼叫同一個函式
## 取得分隔符**,包含退化情境——這與 [constant ARROW_GLYPH] 自己的 doc comment
## 當初決定納入 key 系統的理由一致(「單一常數、單一出處」,顯示與解析不得分裂
## 成兩份各自為政,否則會漂移)。**選的是兩個選項之外的第三案**:不是「只在
## 解析端加守衛」(那樣治不到 [method format_strength_arrow] 真正會顯示給玩家
## 看的缺陷),也不是「解析端改用不可本地化的內部常數」(那樣顯示端與解析端
## 變成兩份獨立來源,違反納入 key 系統時的初衷)。退回的保底分隔符選半形空格
## [code]" "[/code]而非維持空字串:這樣退化後的顯示從「+3+4」(無法判讀斷點)
## 變成「+3 +4」(至少可讀),而且因為兩個函式共用同一個解析結果,[method
## text_uses_required_arrow_format] 對這個退化後的文字一樣能正確判斷為「是」
## (見下方實作;[code]"+3 +4".count(" ") == 1[/code],可以正常 split)。
static func _resolved_arrow_glyph() -> String:
	return _apply_arrow_glyph_fallback(Loc.localize(ARROW_GLYPH))


## 拆成接受明確字串參數的純函式,不在內部直接呼叫 [method Loc.localize]——與
## `loc.gd` 自己的 [method Loc._missing_key_fallback] 同一個理由(該函式自己的
## doc comment已說明):讓這個分岔邏輯可以直接單元測試,不必真的讓
## [method Loc.localize] 在測試環境下回傳空字串(它不會——本機 headless 測試下
## 永遠是 debug build,見 `loc.gd` 的既有測試)。[method _resolved_arrow_glyph]
## 是唯一的正式呼叫端,傳入真正的 [method Loc.localize] 結果。
static func _apply_arrow_glyph_fallback(raw_glyph: String) -> String:
	if raw_glyph.is_empty():
		push_error(
			"CardConfirmPanel: ARROW_GLYPH (battle.card_confirm.arrow_glyph) resolved to an " +
			"empty string -- locale data is missing this key. Falling back to a plain space " +
			"so the two numbers are never displayed concatenated with no separator at all."
		)
		return " "
	return raw_glyph


## AC-U14 — 「現值 → 打完後」箭頭格式,本檔產生這個字串的唯一函式。
static func format_strength_arrow(current: int, projected: int) -> String:
	return "%s%s%s" % [format_signed(current), _resolved_arrow_glyph(), format_signed(projected)]


## AC-U14 鑑別力測試用的判準函式——判斷 [param text] 是否符合「恰好一組
## 『現值 → 打完後』箭頭」的形狀:[constant ARROW_GLYPH] 恰好出現一次,且兩側
## 各自是一個帶號整數字串。「兩欄並排、無箭頭關聯」的版本(例如以 tab 或換行
## 分隔兩個數字,不含 [constant ARROW_GLYPH])必須讓這個函式回傳
## [code]false[/code]——這正是 AC-U14 後半句要求的鑑別力來源。
static func text_uses_required_arrow_format(text: String) -> bool:
	var arrow_glyph: String = _resolved_arrow_glyph()
	if text.count(arrow_glyph) != 1:
		return false
	var parts: PackedStringArray = text.split(arrow_glyph, true, 1)
	if parts.size() != 2:
		return false
	return _looks_like_signed_int(parts[0]) and _looks_like_signed_int(parts[1])


static func _looks_like_signed_int(token: String) -> bool:
	var trimmed: String = token.strip_edges()
	if trimmed.is_empty():
		return false
	if trimmed[0] != "+" and trimmed[0] != "-":
		return false
	return trimmed.substr(1).is_valid_int()


static func _format_title(card_id: String, flavor_text: String) -> String:
	if flavor_text.is_empty():
		return card_id
	return "%s\n%s" % [card_id, flavor_text]


## Which category the panel is currently showing ([constant Category.NONE]
## while hidden) — lets a test assert the panel actually switched to the
## expected variant, not merely that SOME text is showing.
func diagnostic_category() -> Category:
	return _category


## Exact text currently shown in the title row (卡名 + 牌面文字, see [method
## _format_title]) — lets a test assert the specific card's id/flavor text was
## used, not merely that the row is non-empty.
func diagnostic_title_text() -> String:
	return _title_label.text


## Exact text currently shown in the「作用對象」row — one target's name for
## 甲類, or the "A ↔ B" pair for 丙類 (see [method
## show_temporary_modifier_confirmation] / [method
## show_permanent_write_confirmation]).
func diagnostic_target_text() -> String:
	return _target_label.text


## Exact text currently shown in the甲類 ΔATK row — always signed via [method
## format_signed], including [code]"+0"[/code] (Implementation Note 1: 0 is a
## legal value, never omitted).
func diagnostic_delta_atk_text() -> String:
	return _delta_atk_label.text


## Same as [method diagnostic_delta_atk_text] for the ΔDEF row.
func diagnostic_delta_def_text() -> String:
	return _delta_def_label.text


## Exact text currently shown in the 甲類「存續回合」row.
func diagnostic_duration_text() -> String:
	return _duration_label.text


## Number of entries in the most recent [method
## show_temporary_modifier_confirmation]'s [param existing_modifiers] — 0 is a
## legal, distinct state from "no card shown at all" (see [constant
## TEXT_NO_EXISTING_MODIFIERS]).
func diagnostic_existing_modifier_count() -> int:
	return _existing_modifier_lines.size()


## One formatted line from the most recent [method
## show_temporary_modifier_confirmation]'s existing-modifiers list — lets a
## test assert a SPECIFIC entry's content (source/delta/remaining turns)
## rather than parsing [member _existing_modifiers_label]'s joined text.
## Out-of-range [param index] returns [code]""[/code] rather than crashing.
func diagnostic_existing_modifier_line(index: int) -> String:
	if index < 0 or index >= _existing_modifier_lines.size():
		return ""
	return _existing_modifier_lines[index]


## Exact text currently shown in the 甲類「合併後有效值」row (ATK_eff/DEF_eff) —
## GDD UI Requirements #7: this row and [method diagnostic_existing_modifier_line]
## are always both populated, never one in place of the other.
func diagnostic_effective_text() -> String:
	return _effective_label.text


## True while the 丙類「永久」不可逆警示 row is visible — should be
## [code]true[/code] whenever [method diagnostic_category] is [constant
## Category.PERMANENT_WRITE], per Implementation Note 2.
func diagnostic_permanent_warning_visible() -> bool:
	return _permanent_warning_label.visible


## Exact text currently shown in the 丙類「永久」警示 row.
func diagnostic_permanent_warning_text() -> String:
	return _permanent_warning_label.text


## Exact text currently shown for 丙類's「好感度」row — either [method
## format_strength_arrow]'s output or [constant TEXT_STRENGTH_UNAVAILABLE],
## whichever [method show_permanent_write_confirmation]'s [param
## strength_available] selected. AC-U14's discriminator ([method
## text_uses_required_arrow_format]) is meant to be run against exactly this
## value.
func diagnostic_strength_text() -> String:
	return _strength_text


## Exact text currently shown in the 丙類「敘事影響」row — always [constant
## TEXT_NARRATIVE] today (Implementation Note 2: fixed one-line text, zero
## numbers).
func diagnostic_narrative_text() -> String:
	return _narrative_label.text


func _set_row_visibility(is_temporary_modifier: bool) -> void:
	_delta_atk_label.visible = is_temporary_modifier
	_delta_def_label.visible = is_temporary_modifier
	_duration_label.visible = is_temporary_modifier
	_existing_modifiers_label.visible = is_temporary_modifier
	_effective_label.visible = is_temporary_modifier
	_permanent_warning_label.visible = not is_temporary_modifier
	_strength_label.visible = not is_temporary_modifier
	_narrative_label.visible = not is_temporary_modifier


func _ensure_nodes() -> void:
	if _mask != null:
		return

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_mask = ColorRect.new()
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.color = MASK_COLOR
	add_child(_mask)

	_background = ColorRect.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.color = PANEL_BG_COLOR
	add_child(_background)

	_content = VBoxContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_child(_content)

	_title_label = _build_label()
	_target_label = _build_label()
	_delta_atk_label = _build_label()
	_delta_def_label = _build_label()
	_duration_label = _build_label()
	_existing_modifiers_label = _build_label()
	_effective_label = _build_label()
	_permanent_warning_label = _build_label()
	_permanent_warning_label.add_theme_color_override(&"font_color", WARNING_COLOR)
	_strength_label = _build_label()
	_narrative_label = _build_label()

	_labels = [
		_title_label, _target_label, _delta_atk_label, _delta_def_label,
		_duration_label, _existing_modifiers_label, _effective_label,
		_permanent_warning_label, _strength_label, _narrative_label,
	]
	for label: Label in _labels:
		_content.add_child(label)


func _build_label() -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(&"font", HUD_FONT)
	label.add_theme_color_override(&"font_color", TEXT_COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _apply_layout() -> void:
	if _background == null:
		return
	var window_size: Vector2i = get_window().size
	_mask.position = Vector2.ZERO
	_mask.size = Vector2(window_size)

	var rect: Rect2 = panel_rect(window_size)
	_background.position = rect.position
	_background.size = rect.size

	var fpx_int: int = HudLayout.font_size(window_size)
	var fpx: float = float(fpx_int)
	var margin: float = fpx * CONTENT_MARGIN_FPX_MULTIPLIER
	_content.position = Vector2(margin, margin)
	_content.size = rect.size - Vector2(margin, margin) * 2.0
	_content.add_theme_constant_override(&"separation", int(round(fpx * ROW_GAP_FPX_MULTIPLIER)))

	for label: Label in _labels:
		label.add_theme_font_size_override(&"font_size", fpx_int)


## Panel background rect in window-pixel space, centered within [method
## HudLayout.safe_rect] — mirrors `battle_menu.gd`'s `panel_rect()` convention
## exactly (this file does not invent a second centering formula).
static func panel_rect(window_size: Vector2i) -> Rect2:
	var fpx: float = float(HudLayout.font_size(window_size))
	var safe: Rect2 = HudLayout.safe_rect(window_size)
	var size: Vector2 = Vector2(fpx * PANEL_WIDTH_FPX_MULTIPLIER, fpx * PANEL_HEIGHT_FPX_MULTIPLIER)
	var pos: Vector2 = safe.position + (safe.size - size) / 2.0
	return Rect2(pos, size)
