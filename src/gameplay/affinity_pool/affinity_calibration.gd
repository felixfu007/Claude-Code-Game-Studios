# AffinityCalibration —— 好感度數值池加權讀取的六個校準旋鈕,獨立、不可變設定型別。
#
# 設計文件:design/gdd/affinity-data-pool.md「## Tuning Knobs」節——
#   λ_combat/λ_narrative(起始建議範圍 [0.90,0.98])、α(起始建議範圍 [0.15,0.4],
#   開區間)、Q(明文起始建議值 4,範圍 [3,6])、n_min_segment(明文公式
#   = 2×Q)、M(起始建議範圍 [3,8])。
# 治理:2026-09-16 technical-director 裁決(升交自 Story S-007——λ/α 該是讀取
#   函式的參數還是池上的可寫欄位,兩案皆與 ADR-0002 機制五已宣告的函式簽章或
#   「三個獨立純函數」定性有摩擦)——旋鈕既不是函式參數,也不是
#   [AffinityDataPool] 上的散裝可寫欄位,而是本檔這個獨立的不可變設定型別,
#   於建構期經 [method AffinityDataPool._init] 注入,帶預設(見
#   [method uncalibrated_placeholder])。已登記於 docs/registry/architecture.yaml
#   ——本參數不在 ADR-0002「## Key Interfaces」節 `affinity_data_pool.gd` 介面
#   清單區塊(`class_name AffinityDataPool extends RefCounted` 起算)原先列出的
#   簽章裡,這是接受「ADR 文字與程式碼多一處不一致」的緩解條件,見
#   [method AffinityDataPool._init] 文件註解逐字複誦。
#
# 🔴 本檔案頭與 [method uncalibrated_placeholder] 文件註解刻意不引用 GDD 的行號
# ——design/CLAUDE.md「No line-number self-references」明文:多輪 /design-review
# 下行號必然漂移,一律以段落名稱指路。
#
# Story:production/epics/affinity-data-pool/story-007-weighted-reads.md(S-007)
#
# 🔴 `n_gate_min` 不屬於本型別——[AffinityDataPool] 永遠不會讀它。執行
# `n(p) ≥ n_gate_min` 比較的是下游敘事解鎖與結局分支系統,池只負責回傳
# `n_pair`,不持有這個旋鈕(technical-director 2026-09-16 裁決逐字,糾正本
# story 派工單原本誤把它算進池的旋鈕清單裡)。
class_name AffinityCalibration
extends RefCounted


## [method create]/[method uncalibrated_placeholder] 的拒絕碼。回報方式與
## ADR-0002 機制五之二同型(結果物件帶 [member rejection] 欄位),不發明第二種
## 拒絕通道。
##
## 🔴 絕不可用 `assert()` 攔非法值——`assert()` 失敗會中止函式並回傳宣告型別的
## 序數 0,而序數 0 正是 [constant NONE],等於失敗時回報「成功」
## (`.claude/docs/coding-standards.md` 逐字禁令,2026-09-15 實測)。本檔一律用
## `push_error()` + 顯式 `return` 非成功值,不使用 `assert()`。
enum Rejection {
	NONE,
	LAMBDA_COMBAT_OUT_OF_RANGE,
	LAMBDA_NARRATIVE_OUT_OF_RANGE,
	ALPHA_OUT_OF_OPEN_INTERVAL,
	Q_NOT_POSITIVE_INTEGER,
	N_MIN_SEGMENT_NOT_POSITIVE_INTEGER,
	M_NOT_POSITIVE_INTEGER,
	NON_FINITE,
}

## 拒絕碼——[constant Rejection.NONE] 表示本物件可用;非 [constant Rejection.NONE]
## 時,下方六個數值欄位為拒絕哨兵值(浮點 [constant @GDScript.NAN]、整數 `-1`),
## 不代表任何真實校準值,呼叫端不得使用(理由與 [AffinityDataPool] 既有的
## `_rejected_read_result()` 哨兵值設計原則相同)。
var rejection: Rejection = Rejection.NONE

## 是否為 [method uncalibrated_placeholder] 產生的佔位物件——`true` 代表下方
## 六個數值不是任何已定案的遊戲平衡數字,只是 GDD Tuning Knobs 節的起始建議值
## 或建議區間中點(見 [method uncalibrated_placeholder] 文件註解逐一列出出處)。
## [AffinityDataPool] 透過 `diagnostic_calibration_is_placeholder()` 對外暴露此
## 旗標(QA 診斷用途,業務邏輯不得依賴此欄位判斷任何事——理由與
## [AffinityReadResult.diagnostic_visited_count] 相同)。
var is_placeholder: bool = false

## GDD Formulas 公式一保留常數,合法範圍 `[0,1]`(GDD Tuning Knobs
## 「λ_combat、λ_narrative」段落)。
var lambda_combat: float = NAN

## GDD Formulas 公式二保留常數,合法範圍 `[0,1]`,獨立於 [member lambda_combat]
## (同上段落——「建議各自獨立的旋鈕,不共用同一個值」)。
var lambda_narrative: float = NAN

## GDD Formulas 公式二來源折扣係數,合法範圍為開區間 `(0,1)`(GDD Tuning Knobs
## 「α」段落)。
var alpha: float = NAN

## GDD Formulas 3f 分段剖面段數,正整數(GDD Tuning Knobs「Q」段落)。
## 🔴 不屬本 story(S-007)使用範圍——[method AffinityDataPool.shape_feature_read]
## 本 story 未觸碰,本欄位由 S-010/S-011 落地時消費。
var q: int = -1

## GDD Formulas 3f `low_confidence` 樣本數門檻,正整數(GDD Tuning Knobs
## 「n_min_segment」段落)。範圍註記同 [member q]。
var n_min_segment: int = -1

## GDD Formulas 3g 來源缺席確認門檻(戰役刻度單位),正整數(GDD Tuning Knobs
## 「M」段落)。範圍註記同 [member q]。
var m: int = -1


## 建構一份完整校準——六個旋鈕逐一驗證,任一失敗即回傳帶 [member rejection] 的
## 拒絕物件(其餘欄位為哨兵值),全數通過才回傳可用物件([constant Rejection.NONE])。
##
## 🔴 驗證順序為本檔實作選擇,GDD 未規定順序(比照
## `AffinityDataPool.append_record()` 六步驗證既有慣例的宣告方式)——若同一次
## 呼叫同時違反兩條規則,回傳哪個拒絕碼由下方順序決定,不是規格保證:
## 1. [param lambda_combat]/[param lambda_narrative]/[param alpha] 三者任一非
##    有限(NaN 或 ±Infinity)→ [constant Rejection.NON_FINITE]。[b]必須先於
##    範圍比較檢查[/b]——NaN 與任何數比較皆為 `false`,範圍檢查對 NaN 會靜默
##    放行,理由與 `append_record()` 對 NaN 幅度的既有處置相同。
## 2. [param lambda_combat] 不在 `[0,1]` → [constant Rejection.LAMBDA_COMBAT_OUT_OF_RANGE]
## 3. [param lambda_narrative] 不在 `[0,1]` → [constant Rejection.LAMBDA_NARRATIVE_OUT_OF_RANGE]
## 4. [param alpha] 不在開區間 `(0,1)` → [constant Rejection.ALPHA_OUT_OF_OPEN_INTERVAL]
## 5. [param q] 非正整數(`q < 1`)→ [constant Rejection.Q_NOT_POSITIVE_INTEGER]
## 6. [param n_min_segment] 非正整數 → [constant Rejection.N_MIN_SEGMENT_NOT_POSITIVE_INTEGER]
## 7. [param m] 非正整數 → [constant Rejection.M_NOT_POSITIVE_INTEGER]
##
## 呼叫端型別義務(比照 `append_record()` 既有慣例):本函式參數為型別化
## float/int,不接受 [Variant]——上游若持有來源不明的值,必須先自行以
## `typeof()` 收斂型別,本函式的拒絕碼不涵蓋型別非法。
static func create(
	lambda_combat: float,
	lambda_narrative: float,
	alpha: float,
	q: int,
	n_min_segment: int,
	m: int
) -> AffinityCalibration:
	if is_nan(lambda_combat) or is_inf(lambda_combat):
		return _rejected(Rejection.NON_FINITE)
	if is_nan(lambda_narrative) or is_inf(lambda_narrative):
		return _rejected(Rejection.NON_FINITE)
	if is_nan(alpha) or is_inf(alpha):
		return _rejected(Rejection.NON_FINITE)

	if lambda_combat < 0.0 or lambda_combat > 1.0:
		return _rejected(Rejection.LAMBDA_COMBAT_OUT_OF_RANGE)
	if lambda_narrative < 0.0 or lambda_narrative > 1.0:
		return _rejected(Rejection.LAMBDA_NARRATIVE_OUT_OF_RANGE)
	if alpha <= 0.0 or alpha >= 1.0:
		return _rejected(Rejection.ALPHA_OUT_OF_OPEN_INTERVAL)
	if q < 1:
		return _rejected(Rejection.Q_NOT_POSITIVE_INTEGER)
	if n_min_segment < 1:
		return _rejected(Rejection.N_MIN_SEGMENT_NOT_POSITIVE_INTEGER)
	if m < 1:
		return _rejected(Rejection.M_NOT_POSITIVE_INTEGER)

	var calibration := AffinityCalibration.new()
	calibration.rejection = Rejection.NONE
	calibration.is_placeholder = false
	calibration.lambda_combat = lambda_combat
	calibration.lambda_narrative = lambda_narrative
	calibration.alpha = alpha
	calibration.q = q
	calibration.n_min_segment = n_min_segment
	calibration.m = m
	return calibration


## 建立帶 [param rejection] 的拒絕物件——六個數值欄位為哨兵值(浮點
## [constant @GDScript.NAN]、整數 `-1`),與 [AffinityDataPool] 既有的
## `_rejected_read_result()` 同一套「不代表任何真實值」設計原則。
static func _rejected(rejection: Rejection) -> AffinityCalibration:
	var calibration := AffinityCalibration.new()
	calibration.rejection = rejection
	calibration.is_placeholder = false
	calibration.lambda_combat = NAN
	calibration.lambda_narrative = NAN
	calibration.alpha = NAN
	calibration.q = -1
	calibration.n_min_segment = -1
	calibration.m = -1
	return calibration


## 🔴 本函式產生的物件不代表任何已定案的遊戲平衡數字——見下方逐一出處。
## [AffinityDataPool] 在建構期未收到明確 [AffinityCalibration] 時,以本函式的
## 回傳值頂替,並將 [member is_placeholder] 對外暴露為
## `diagnostic_calibration_is_placeholder()`,供 QA 判斷目前是否仍在跑佔位數字
## (2026-09-16 technical-director 裁決「丙案」——假值集中在一個名字就是警告的
## 函式裡,`grep -rn uncalibrated_placeholder src/` 隨時列得出來)。
##
## 每個數字的出處(GDD `design/gdd/affinity-data-pool.md`「## Tuning Knobs」節,
## 依段落名稱指路,不引用行號——見本檔案頭說明):
## - [member lambda_combat]/[member lambda_narrative]:「λ_combat、λ_narrative」
##   段落起始建議範圍 `[0.90, 0.98]` 的區間中點,取 `0.94`。
## - [member alpha]:「α」段落起始建議範圍 `[0.15, 0.4]` 的區間中點,取 `0.275`。
## - [member q]:「Q」段落[b]明文起始建議值[/b] `Q=4`(非區間中點——GDD 對這個
##   旋鈕直接給了單一建議值,不是只給區間)。
## - [member n_min_segment]:「n_min_segment」段落[b]明文公式[/b]
##   `n_min_segment = 2×Q`,代入上面的 `Q=4` 得 `8`。
## - [member m]:「M」段落起始建議範圍 `[3, 8]` 的區間中點為 `5.5`,但 `M` 依同
##   段落的硬性定義域約束必須是正整數——區間中點非整數時如何取整,GDD 未指定,
##   本檔選擇四捨五入取 `6`(而非無條件捨去的 `5`),這是本檔的實作選擇,不是
##   GDD 明文數字。
##
## 🔴 這一格是平衡值,不是架構——technical-director 已另行呈報管理者。他日
## 調整只需要修改本函式,不影響 [AffinityDataPool] 或任何呼叫端程式碼。
static func uncalibrated_placeholder() -> AffinityCalibration:
	var calibration: AffinityCalibration = create(0.94, 0.94, 0.275, 4, 8, 6)
	calibration.is_placeholder = true
	return calibration
