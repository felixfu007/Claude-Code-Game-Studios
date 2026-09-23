# Coding Standards

- All game code must include doc comments on public APIs
- Write an architecture decision record in `docs/architecture/` **only for cross-system contracts**.
  A single system's internal technical detail belongs in that system's design document.
  > 🔴 **Changed 2026-09-01 (manager ruling).** This line previously read *"Every system must have a
  > corresponding architecture decision record"* — which **directly contradicted** the process-dosage
  > rule of 2026-08-25 (`production/milestones/one-year-plan.md` §6②, summarised in
  > `technical-preferences.md`), and **both files are auto-loaded every session**. Whoever read this
  > one first would write six more ADRs; the dosage rule expects **0–1** more for the remaining six
  > systems. The dosage ruling is the newer decision and wins.
  > `docs/WORKFLOW-GUIDE.md`'s "minimum 3 Foundation ADRs" gate wording is the third copy of this
  > rule and is **still unreconciled** — registered in `docs/reviews/doc-audit-2026-09-01.md`.
- Gameplay values must be data-driven (external config), never hardcoded
- All public methods must be unit-testable (dependency injection over singletons)
- Commits must reference the relevant design document or task ID
- **Commit messages**: Use Conventional Commits format — `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`. Reference the story or task ID in the body (e.g., `Story: EPIC-001-S02`).
- **Verification-driven development**: Write tests first when adding gameplay systems.
  For UI changes, verify with screenshots. Compare expected output to actual output
  before marking work complete. Every implementation should have a way to prove it works.
- 🔴 **Never use `assert()` to guard an "unreachable" branch in a function that returns an enum.**
  Measured 2026-09-15 by the coordinator (own probe, engine-executed, Godot 4.7.1 headless):
  when an `assert()` fails it aborts the calling function, and the function yields
  **ordinal 0 of its declared return type**. For the near-universal convention where the
  success value is listed first (`enum R { NONE = 0, ... }`), that means
  **a failed assertion silently returns "success"** — the exact opposite of what the
  assertion was written to prevent. Use `push_error()` followed by an explicit `return`
  of a deliberately non-success value instead.

  Reproduce (self-contained — no need to trust this entry; save and run it):

  ```gdscript
  extends SceneTree
  enum R { NONE = 0, BAD_A = 1, BAD_B = 2 }
  func _fails_assert() -> R:
      assert(false, "deliberate probe failure")
      return R.BAD_B
  func _init() -> void:
      print("returned = ", _fails_assert(), "  is NONE? ", _fails_assert() == R.NONE)
      quit()
  ```
  ```
  godot --headless --path . -s <that file>
  ```
  Measured output: `returned = 0  is NONE? true`, alongside
  `SCRIPT ERROR: Assertion failed: deliberate probe failure`.

  ⚠️ **The error message is printed, so this is loud in a terminal and silent in a return
  value.** A caller that only inspects the returned rejection code sees `NONE` and proceeds
  as if the write succeeded. This was found during Story S-008 (affinity write-port adapter)
  by the implementer, who had been about to use `assert()` for exactly this purpose and
  probed it first; the coordinator then re-verified it independently rather than taking the
  report at face value.

# Design Document Standards

- All design docs use Markdown
- Each mechanic has a dedicated document in `design/gdd/`
- Documents must include these 8 required sections:
  1. **Overview** -- one-paragraph summary
  2. **Player Fantasy** -- intended feeling and experience
  3. **Detailed Rules** -- unambiguous mechanics
  4. **Formulas** -- all math defined with variables
  5. **Edge Cases** -- unusual situations handled
  6. **Dependencies** -- other systems listed
  7. **Tuning Knobs** -- configurable values identified
  8. **Acceptance Criteria** -- testable success conditions
- Balance values must link to their source formula or rationale

# Testing Standards

## Test Evidence by Story Type

All stories must have appropriate test evidence before they can be marked Done:

| Story Type | Required Evidence | Location | Gate Level |
|---|---|---|---|
| **Logic** (formulas, AI, state machines) | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| **Integration** (multi-system) | Integration test OR documented playtest | `tests/integration/[system]/` | BLOCKING |
| **Visual/Feel** (animation, VFX, feel) | Screenshot + lead sign-off | `production/qa/evidence/` | ADVISORY |
| **UI** (menus, HUD, screens) | Manual walkthrough doc OR interaction test | `production/qa/evidence/` | ADVISORY |
| **Config/Data** (balance tuning) | Smoke check pass | `production/qa/smoke-[date].md` | ADVISORY |

## Screenshot Evidence Rules

A screenshot must prove it is **the thing it claims to be** — not merely that it is not
blank. These rules exist because on 2026-08-31 a Godot **boot splash screen** was written
into `production/qa/evidence/` as evidence of the exported build. It was caught, but not
by any rule that existed at the time.

🔴 **"Count the distinct colours to prove it is not blank" does not work.** Measured on the
two images that day:

| | Real gameplay frame | Godot boot splash |
|---|---|---|
| Dimensions | 960×540 ✅ correct | 960×540 ✅ correct |
| Distinct colours | 247 | **493** |

The splash has **more** colours than the real frame, because a logo's antialiased gradients
produce more distinct values than a pixel-art scene's large flat fills. **"More colours reads
as more real" points the wrong way.** The colour count only rules out a uniformly blank
frame, which is the narrow case it was written for.

### Screenshot classification — decide the category before applying any check

**2026-09-17 addition.** The five checks below were written against one shape of screenshot
(a full-window gameplay frame) and were then applied unmodified to two other shapes in the
same batch of work, on the same day, by two different implementers, from two different
directions:

| | Screen | Check it hit | Measured |
|---|---|---|---|
| U-007 | **Forced-response overlay/mask** (translucent scrim covers the entire window, small panel centred inside it) | Check 3, dominant colour share ≤ 80% | **91.6% / 92.7%** at 1920×1080 / 2560×1440 — `prototypes/u007-battle-menu-evidence-capture-2026-09-17/README.md`, `production/qa/evidence/battle-menu-layout-evidence.md` |
| U-011 | **Thin-line UI crop** (hand-bar strip, cropped from a full-window capture) | Check 2, 12-point sampling ≥ 3 colours | first attempt (wide-margin crop) measured **4 / 1** distinct colours, dominant share **53.26%–63.32% / 99.19%–99.60%** — `prototypes/story-u011-hand-bar-evidence-2026-09-17/README.md` and its `run_output.txt` |

🔴 **The most informative thing that happened is not the two failures above — it is what the
U-011 implementer reached for next.** Facing Check 2's failure, the first instinct was to
switch the metric to **whole-image distinct-colour count**. That is the exact metric the table
at the top of this section already names as pointing **backwards** (boot splash 493 colours >
real frame 247 colours) — a reviewer caught it before it shipped (see
`production/qa/evidence/story-u011-hand-bar-evidence.md`, section "第二次嘗試(已捨棄)").
**When a check does not fit the screen in front of you, the replacement invented on the spot
is not automatically safer than the check it's replacing — on this project, it has already
turned out to be the exact thing this section was written to ban.**

**Conclusion for this rule set: no category gets a "use your judgement" escape hatch.** Every
screenshot is classified into exactly one of three categories below, by an objective test that
does not depend on the capturer's self-description, and each category has its own fixed,
fully-specified checks.

#### Classification test (apply in this order — first match wins)

1. **Category C — cropped / partial capture.** Test: **the image's dimensions do not equal
   the full target window size** for the resolution under test. (This reuses Check 1's
   dimension measurement — classification and Check 1 read the same number.)
2. **Category B — full-window overlay/mask screen.** Test: dimensions **do** match the full
   window, **and** the screen's own real layout function — the one production code actually
   calls (e.g. `panel_rect()`), not a re-derivation of it — reports a content rect whose area
   is **less than 50% of the full window's area** at that resolution, with the remaining area
   an intentional single-colour scrim/mask. (Threshold chosen to unambiguously separate cases
   like U-007's ~8.9% panel coverage from an ordinary partial-window widget; changing it is a
   fresh decision, not a silent adjustment.)
   🔴 **A claim of "this is a modal" with no named rect-function call behind it does not
   qualify.** It stays Category A and inherits Category A's checks — which it will then
   correctly fail. The escape hatch is the rect call, not the assertion.
3. **Category A — full gameplay/world frame.** Everything not caught by 1 or 2 — the shape the
   original five checks were written for. They apply to it unchanged.

### Category A checks — full gameplay/world frame (the original five checks; one disclosure clause added to Check 4 on 2026-09-17 for symmetry with B/C, see below)

1. **Dimensions** match the expected window size exactly.
2. **Multi-point sampling** — sample at least 12 spread coordinates; require **≥ 3 distinct
   colours** among them. (Splash: all 12 identical. Real frame: 7 distinct.)
3. **Dominant colour share ≤ 80%** of all pixels. (Splash: 94.62%. Real frame: 43.06%.)
4. **Pixel-art integer-scale grid integrity** — each source pixel must map to a clean
   N×N block of identical colour, proving no resampling occurred.
   ⚠️ **Measure the world layer only.** Whole-image measurement is *inverted* here and will
   judge backwards: the project deliberately renders body text in a normal Chinese font
   rather than a pixel font (`design/art/art-direction.md`), and that antialiased text
   produces more grid violations in a real frame (3.157%) than the splash logo does (1.748%).
   🔴 **How "world layer only" is operationally measured changed on 2026-09-23 (manager
   ruling) — see "Check 4 世界層量法變更(2026-09-23 管理者裁決)" below for the full method,
   three implementation constraints, and a new N/A rule. Not restated here to avoid drift
   between two copies of the same procedure.**
   ⚠️ **The "restricted to the board region" demonstration numbers below were measured with the
   OLD method** (cropping the composited screenshot to the world-layer container's rect) **and
   have not been re-measured with the new method — do not cite them as current evidence**:
   real frame 0 of 66300 blocks, splash 2265.
   **If the screen has no world layer at all, say so explicitly; do not silently
   omit the check without a stated reason** — this is the same disclosure obligation Category
   B and C's Check 4 state below; Category A never needed it in practice (a full gameplay/world
   frame has a world layer by definition), but the obligation itself applies uniformly to every
   category, not just the two where it currently matters. Stating it only under B/C invited the
   wrong inference — that A is exempt from disclosure rather than merely exempt, so far, from
   ever triggering it.
   📌 See "Check 4「僅量世界層」豁免的前提查證" below — read it before relying on this carve-out.
   📌 2026-09-23 續:上面那則查證後來同一天由實機複驗補正,結論方向不同 —— 見緊接其後的
   「(續,2026-09-23)」小節,勿只讀到「前提為假」就下結論。
   📌 2026-09-23 再續:**那兩則登記各自「不修改 Check 4 判準」的結論,已被同日稍晚一次獨立的
   管理者裁決取代** —— 新判準寫在本節下方「Check 4 世界層量法變更(2026-09-23 管理者裁決)」,
   兩則登記原文本身不動。
5. 🔴 **A human opens the image and confirms it shows what it claims.** The checks above are
   a filter, not a substitute. Every visual defect found on this project so far was found by
   a person opening the file; the automated suite has never caught one.

### Category B checks — full-window overlay/mask screens

**Why Check 3 as written points backwards here**: a modal's entire design intent is "one
translucent colour covers most of the frame, plus a small panel." A dominant-share ceiling
built to catch "this frame is suspiciously blank" will **always** fire on a correctly-rendered
modal — U-007 measured 91.6%/92.7%, both confirmed complete and correct by human review
(`production/qa/evidence/battle-menu-layout-evidence.md`). Applying Check 3 unmodified here
does not detect a defect; it detects the design.

1. **Dimensions** — unchanged, still required.
2. **Sampling** — run the original blind grid **and keep its result on the record even if it
   comes back with only 1 distinct colour** (expected, not a failure to hide — see U-007's own
   disclosure of this exact result). **Add** sample points derived from the screen's real
   content-rect function (the same one used for classification above); require **≥ 3 distinct
   colours across the combined blind + targeted set**.
3. **Dominant colour share ≤ 80% does not apply.** Replace it with an **edge/corner mask
   coverage check**: sample the 4 corners and 4 edge midpoints of the full window and confirm
   every one matches the intended overlay colour, with no gap. This targets the actual defect
   this screen shape can have — an incompletely-covered scrim leaving a bright, un-masked strip
   at the window edge (the risk `design/art/screen-architecture.md` names for non-16:9
   windows) — instead of testing for a property (low dominant-colour share) the design
   deliberately does not have.
4. **Integer-scale grid** — same carve-out as Category A: world layer only.
   🔴 **量法定義已於 2026-09-23 變更(管理者裁決)——見 Category A Check 4 與本節下方
   「Check 4 世界層量法變更(2026-09-23 管理者裁決)」,此處不複述。** If the screen has
   no world layer at all, say so explicitly; do not silently omit the check without a stated
   reason.
   📌 See "Check 4「僅量世界層」豁免的前提查證" below — read it before relying on this carve-out.
   📌 2026-09-23 續:上面那則查證後來同一天由實機複驗補正,結論方向不同 —— 見緊接其後的
   「(續,2026-09-23)」小節,勿只讀到「前提為假」就下結論。
   📌 2026-09-23 再續:**那兩則登記各自「不修改 Check 4 判準」的結論,已被同日稍晚一次獨立的
   管理者裁決取代** —— 新判準見 Category A Check 4 與「Check 4 世界層量法變更」段落。
5. 🔴 **Human review — mandatory, unchanged.** See "why Check 5 survives every category" below.

### Category C checks — cropped / partial UI captures

**Why Check 2 as written points backwards here**: a blind 12-point grid assumes content is
spread across the frame. A crop of a thin-line UI element (borders, a count label) is mostly
empty space between lines at typical UI scale — U-011's first attempt measured 1 distinct
colour among 12 blind points on a correctly-rendered crop
(`prototypes/story-u011-hand-bar-evidence-2026-09-17/run_output.txt`). The grid tests "is
content spread out," and a thin-line crop's honest answer is "no," independent of whether it
is correct.

1. **Dimensions** — must equal the crop rect as computed by the real layout function used to
   produce it (name the function, e.g. `slot_bar_rect()` / `slot_rect()`), not the full window.
2. **Blind sampling is replaced by directional/oriented sampling.** Coordinates must be
   derived by calling the same real layout function that produced the crop — placed at
   "should have a drawn edge here" positions and at "known interior, no edge" positions —
   never at random or evenly-spaced coordinates chosen independently of that function.
   🔴 **Explicitly banned substitute: whole-image distinct-colour count.** This was tried on
   this project and withdrawn before shipping
   (`production/qa/evidence/story-u011-hand-bar-evidence.md`, section "第二次嘗試(已捨棄)")
   for the same reason the table at the top of this section exists: colour count points
   backwards (more antialiasing → more colours → a boot splash beats a real frame). **A check
   that fails on a real screen does not get replaced by a metric this document has already
   named as unreliable, regardless of who proposes it or how reasonable it looks at the time.**
3. **Dominant colour share ≤ 80% does not universally apply** — an isolated widget crop on an
   otherwise-blank test backdrop is mostly one colour by design (U-011's isolated-widget crop
   measured 99.6% and was correct). Use whichever of the following fits the evidence being
   produced:
   - **(a) Structural-difference check**, when two crops are being compared against each other
     (e.g. two states of the same component): per-pixel luminance difference, requiring the
     **standard deviation** of that difference to clear a threshold — this proves the
     difference is not just a uniform brightness/contrast shift across the whole crop.
   - **(b) Positive-presence check**, when there is no second crop to diff against: a named
     region must be measurably brighter or darker than a named reference background point.
4. **Integer-scale grid** — same carve-out as Category A/B: world layer only.
   🔴 **量法定義已於 2026-09-23 變更(管理者裁決)——見 Category A Check 4 與本節下方
   「Check 4 世界層量法變更(2026-09-23 管理者裁決)」,此處不複述。** Most UI crops
   have no world-layer content at all (this project renders UI text in an antialiased Chinese
   font, not a pixel font); state that explicitly rather than silently skipping the check.
   📌 See "Check 4「僅量世界層」豁免的前提查證" below — read it before relying on this carve-out.
   📌 2026-09-23 續:上面那則查證後來同一天由實機複驗補正,結論方向不同 —— 見緊接其後的
   「(續,2026-09-23)」小節,勿只讀到「前提為假」就下結論。
   📌 2026-09-23 再續:**那兩則登記各自「不修改 Check 4 判準」的結論,已被同日稍晚一次獨立的
   管理者裁決取代** —— 新判準見 Category A Check 4 與「Check 4 世界層量法變更」段落。
5. 🔴 **Human review — mandatory, and carries more weight here than in the other two
   categories**, because checks 2 and 3 are, by construction, the most structurally weakened
   of the three categories here — see below.

### 已知陷阱(Check 4,A/B/C 三類共通):分析/證據腳本繞過真實渲染管線,以及重複計數的方向性偏誤(2026-09-22)

Check 4 的違規數字假設量測自真實像素。2026-09-22(Story U-013)兩個陷阱由協調者獨立複驗,非傳聞。
**兩者事後都已在同一支腳本內修正**(見該腳本檔頭「4TH REVISION」註解自述的修訂記錄)——
記載在此是為了這類錯誤本身會重演,不是要人去該檔案現在的行號找這段程式碼,現行版本已經不是這樣寫。

🔴 **陷阱①——證據腳本繞過真實渲染管線,產生假性失敗,而假性數字足以觸發對正確程式碼的錯誤修改。**
本專案世界層實際走 `SubViewportContainer` + `SubViewport`,內部固定 480×270 原生解析度再 nearest
整數放大:
```
$ grep -n "SubViewport" src/ui/battle/BattleScreen.tscn
12:[node name="WorldViewportContainer" type="SubViewportContainer" parent="."]
17:[node name="WorldViewport" type="SubViewport" parent="WorldViewportContainer"]
```
`prototypes/u013-highlight-evidence-2026-09-22/evidence_driver.gd` 前三版把 `BoardView` 直接掛在
根 `Window` 下、手動套 `WorldLayout` 算出的 scale/position,跳過這層 —— Check 4 報
**194 / 229440**。改走真實管線複驗(`prototypes/godot-specialist-u013-subviewport-pipeline-check-2026-09-22/`):
```
PIPELINE PROBE -- SubViewport.size (should be exactly BASE_WIDTHxBASE_HEIGHT = 480x270 ...) = (480, 270)
PIPELINE PROBE -- Check 4 (corrected single-count algorithm) on REAL SubViewport pipeline, full window = 0 / 229440
```
那個 194 曾引發跨網域調查:`art-director` 依專案明文的像素對齊規範**正確地**判定「該改遊戲」——
它的判斷原則沒錯,錯的是它相信了那個數字。若當時沒有第二位專家改查渲染管線,
就會去改一段本來正確的 `src/ui/battle/board_view.gd`。**與 `technical-preferences.md`
「(A) 的精確定義」節記載的 awk 棋盤量測案例是同一個失效模式的第三次** —— 分析腳本重新實作
一份規則、繞過真正的程式碼,而沒有任何規則管得到分析腳本。

⚠️ **陷阱②——重複計數寫法只會高估,不會低估。**
同一支腳本第 3 版(修正前)的 `_integer_grid_violations()`:
```gdscript
			var origin: Color = img.get_pixel(bx * _scale, by * _scale)
			for dy in range(_scale):
				for dx in range(_scale):
					var c: Color = img.get_pixel(bx * _scale + dx, by * _scale + dy)
					if not c.is_equal_approx(origin):
						violations += 1
						break
```
`break` 只跳出 `dx` 迴圈,`dy` 繼續執行,同一個方塊若多列不合格會被重複計入。去重後真值是
**178**,不是 194(見 `prototypes/godot-specialist-u013-check4-decomposition-2026-09-22/run_output.txt`)。
**方向與本節其餘規則相反** —— 本節上方多數陷阱(例如顏色數量、Check 3 的支配色佔比)指向的是
**低估**風險,把壞畫面誤判成過關;這一條只會**高估**,把好畫面誤判成壞掉,不會讓壞畫面蒙混過關。
套用本節其餘規則的直覺時,這一條要反過來讀。

以上兩項皆為紀律記載,**沒有任何 lint 或自動檢查會攔** —— 與本節其餘規則一樣,遵守與否目前
不可觀測,唯一的防線是下一個人讀到這裡並照做。

### Check 4「僅量世界層」豁免的前提查證(2026-09-23):世界層本身已驗證含有反鋸齒文字

Category A、B、C 三個章節各自的 Check 4 都寫「Measure the world layer only」/
「same carve-out ... world layer only」(現場定位用 `grep -n "world layer only"
.claude/docs/coding-standards.md`,不查行號 —— 行號會漂,見 `.claude/rules/design-docs.md`
的「No line-number self-references」),理由是**反鋸齒中文字只在介面層,世界層沒有**
—— 這是三處共用的同一條前提。**該前提已用下列可重跑的 grep 逐條驗證為假**
(非手抄數字,指令與輸出皆可重現):

```
$ grep -n "SubViewport\|BoardView" src/ui/battle/BattleScreen.tscn
12:[node name="WorldViewportContainer" type="SubViewportContainer" parent="."]
17:[node name="WorldViewport" type="SubViewport" parent="WorldViewportContainer"]
19:[node name="BoardView" parent="WorldViewportContainer/WorldViewport" instance=ExtResource("2_board_view")]
```
→ `BoardView` 掛在 `WorldViewport` 底下 —— 它就是世界層,不是介面層。

```
$ grep -n "Label.new" src/ui/battle/board_view.gd
```
→ 命中 `_build_hp_text()` 函式內建立的那個 `Label`(單位頭上的血量讀數,見該函式上方文件
註解)。**行號故意不寫在這裡**——該檔另有工作線正在改血量襯底顏色,行號會位移;要行號現場
重跑上面這條指令,勿依賴任何寫死的數字。

```
$ grep -c "add_theme_font_override" src/ui/battle/board_view.gd
0
$ grep -c "add_theme_font_override" src/ui/battle/hand_bar.gd
2
```
→ 世界層那個 `Label` **零字型覆寫**,吃引擎預設(反鋸齒)字型;對照組 `hand_bar.gd`
(介面層,手牌列)有 2 處明確覆寫成 `HUD_FONT` 點陣字(`grep -n` 可查行號)。
**世界層裡確實有反鋸齒文字 —— 三處豁免共用的前提不成立。**

🔴 **前提不成立不等於「世界層量出來的違規數字就是這個原因造成的」。** 有一支 2026-09-23
的探針(`godot-specialist` 執行)在世界層量到整數縮放違規 `1071 / 112490`(已扣除 3 個真實
`HudLayout` 矩形),執行者誠實答「不知道成因」、也沒有讀過 `board_view.gd`。上面的 grep 讓
「1071 是血量 Label 造成的」成為**有根據的假說**——但**沒有人驗證過這個因果關係**,本條目
也未重跑引擎去驗證(不在本次任務範圍內)。**下一個引用這個數字的人,不得把因果關係當既定
事實寫,只能寫「有一個未驗證的假說」。**

⚠️ **本條目不修改 Check 4 的判準,也不改動 A/B/C 三處「world layer only」豁免的原文一字。**
要不要把血量 Label(或其他世界層文字)排除在 Check 4 之外、還是反過來收緊豁免的適用範圍,
是下一次的管理者裁決,不是本條目的職權。**本條目只登記缺口**:三處豁免共用的前提已驗證為假,
下一個要動 Check 4 判準、或要引用「世界層乾淨」這個假設的人,必須先讀到這裡。

### Check 4「僅量世界層」豁免的前提查證(續,2026-09-23):前提為假不影響 Check 4 的結果 —— 另外找到兩個更大的洞

上一條登記留了一句「沒有人驗證過這個因果關係」,管理者裁決先派 `godot-specialist` 依上一條第 5 點
的規則寫探針實跑查證,再談要不要動判準。探針結果見
`prototypes/godot-specialist-u013-worldlayer-attribution-2026-09-23/run_output_windowed.txt`
(windowed 執行,以下逐字引用):

```
SANITY: WorldViewportContainer.position=(0.0, 0.0) size=(960.0, 540.0) stretch_shrink=2
SANITY: WorldViewport.size = (480, 270) (WorldLayout.BASE_WIDTH/HEIGHT=480x270)
STATE: _cursor_active=false _cursor_cell=(0, 2)
CHECK4 [BONUS-SUBVIEWPORT-NATIVE-nearest-upscaled (pure world-layer content, isolates measurement-method vs content-problem)] = 0 / 129600
CHECK4 [BASELINE-whole-window] = 4601 / 129600
CHECK4-EXCL [EXCL-3-HUD-rects (reproduces prior probe's 1071/112490)] excluded_blocks=17110 violations=1109 / 112490
CHECK4-EXCL [EXCL-4-rects (3 HUD + HandBar)] excluded_blocks=21466 violations=478 / 108134
CHECK4-EXCL [EXCL-5-rects (3 HUD + HandBar + HP-text band) -- if this is ~0, all violations are accounted for] excluded_blocks=21466 violations=478 / 108134
WITHIN [WITHIN HandBar.slot_bar_rect] rect=[P: (348, 392), S: (264, 66)] violations=631 / 4356 blocks
```

🔴 **結論一(改變上一條登記的推論方向,不是撤回它):前提確實為假,但這個假前提從頭到尾不影響
Check 4 對真世界層內容的判定 —— Check 4 結構上量不到 `SubViewport` 內部畫了什麼。**
`BONUS-SUBVIEWPORT-NATIVE` 那行直接讀 `WorldViewport.get_texture().get_image()`
(480×270 原生緩衝區,完全在 UI `CanvasLayer` 疊上去之前),照真實倍率用 nearest 放大回 960×540
再跑同一套 Check 4 → **`0 / 129600`**。這不是「這次剛好乾淨」,而是結構性保證:nearest 放大的定義
就是把每一個來源像素複製成一個 N×N 同色方塊,**不論來源像素本身是否來自反鋸齒渲染,複製出來的
方塊必定同色**。真實管線同樣走 nearest —— `src/ui/battle/BattleScreen.tscn` 的
`WorldViewportContainer` 節點 `texture_filter = 1`,本條目另以
`grep -n "texture_filter\|SubViewport" src/ui/battle/BattleScreen.tscn` 獨立覆核,結果一致:

```
12:[node name="WorldViewportContainer" type="SubViewportContainer" parent="."]
13:texture_filter = 1
17:[node name="WorldViewport" type="SubViewport" parent="WorldViewportContainer"]
```

**所以:世界層裡有沒有反鋸齒文字,不會讓 Check 4 量出違規。** 這與 Category A 原文本來就有的
證據方向一致(「限縮到棋盤區域訊號是乾淨的:真實畫面 0 of 66300」),本條目是第一次把它講清楚是
**結構性保證**,不是「今天剛好如此」。**上一條登記的前提查證本身沒有錯 —— 錯的是把「前提為假」
自然讀成「所以這個豁免不可靠」的方向,實測指向相反。**

**結論二:先前量到的 1071/1109,從頭到尾都不是世界層內容 —— 是介面層疊上去之後被一起算了進去。**
`WorldViewportContainer` 在這個解析度下 `position=(0,0) size=(960,540)`,與整個視窗完全重疊。
「裁到世界層矩形」在這個畫面等於「裁到整個視窗」,於是疊在世界層之上的 `CanvasLayer` 介面內容
(HUD 文字、手牌列數字)被一起算了進去 —— `EXCL-3`(僅排除 3 個 HUD 矩形)量到 `1109 / 112490`
(與上一條登記引用的 1071 同量級,差 38,見下方未解項);再排除 `HandBar.slot_bar_rect` 一項
(`EXCL-4`)就降到 `478 / 108134`,而 `WITHIN HandBar.slot_bar_rect` 單獨量測顯示該矩形內部就有
`631 / 4356` 個方塊違規。**「world layer only」這行指令,在這個專案目前的畫面配置下,「裁到世界層
容器的矩形」與「只量到世界層真正畫出的像素」是兩件不同的事**——因為容器滿版、介面疊在上面。

⚠️ **結論三:上一條登記的「HP Label 造成殘留違規」假說,以這次測到的這一幀而言已被否證,
不應再被當成支持證據引用。** `STATE: _cursor_active=false` —— 血量文字只在游標啟用時畫出
(`board_view.gd` 的 `_build_hp_text()`)。`EXCL-5`(在 `EXCL-4` 之外再排除血量文字帶)與
`EXCL-4` **逐字相同 `478 / 108134`** —— 多排除的是空集合,代表這一幀裡血量文字沒有貢獻任何違規。
上一條登記寫的是「有根據的假說,但沒有人驗證過」;現在驗證了,至少對這一幀是否定的。這不代表
血量 Label 在游標啟用、血量文字確實畫出的其他幀裡一定無罪 —— 那個情境本次探針沒有測,不得
外推成「血量 Label 全面無關」。

📌 **兩項誠實登記的未解項,不代填成因**:
1. **排除 4 個已知真實矩形(3 個 HUD + `HandBar`)後仍剩 `478 / 108134` 無法歸因。**
   `godot-specialist` 原猜測是 `WorldViewportContainer` 走了 Linear 濾波 —— 本條目已用上方
   `texture_filter = 1` 的獨立覆核否定這個猜測。**478 目前無人能解釋成因。**
2. **兩支探針的 baseline 相差 38**:2026-09-22 那支量到 `1071`,本次量到 `1109`;差額不落在
   那 3 個已知 HUD 矩形之內。**成因同樣無人知道。**

⚠️ **本條目不改動上一條登記的任何一字,也不修改 Check 4 的判準,不改動 A/B/C 三處
「world layer only」豁免的原文一字** —— 立場與上一條登記相同,理由也相同:要不要把「世界層」的
操作型定義從「容器矩形」改成「容器實際渲染輸出」(例如改讀 `SubViewport.get_texture()`,而不是
裁切合成後的整個視窗畫面),是下一次的管理者裁決,不是本條目的職權。**本條目只登記事實:
「前提為假」這件事本身對 Check 4 無害,真正的洞在別處 —— 「world layer only」這行指令目前實際
測到的,不是世界層。**

### Check 4 世界層量法變更(2026-09-23 管理者裁決,取代上兩則登記各自的「不修改 Check 4 判準」結論)

**背景**:上兩則登記(本節上方的「前提查證」與其「續」)各自明文寫著「本條目不修改 Check 4
的判準」「不改動 A/B/C 三處『world layer only』豁免的原文一字」,把要不要動判準留給下一次
管理者裁決。協調者隨後就此提出兩份意見書 ——`lead-programmer` 建議「不改判準,只加警語誠實
揭露 478 目前無法歸因」(`docs/reviews/check4-recommendation-lead-programmer-2026-09-23.md`),
`qa-lead` 建議「先把世界層 Check 4 標成『現在用不到』,等程式寫出來再談」
(`docs/reviews/check4-recommendation-qa-lead-2026-09-23.md`),另有代價評估
(`docs/reviews/check4-world-layer-paths-cost-2026-09-23.md`)。**管理者選的是第三案 ——
兩個都做,同一天一次寫清楚 —— 不是這兩份意見書裡的任何一個。** 以下是裁決後的新判準,
取代上兩則登記各自的「不修改 Check 4 判準」結論;**兩則登記本身的文字不動,決策紀錄保留。**

#### 新判準一:世界層的操作型定義,從「裁切合成後畫面裡容器矩形所在的區域」改為
「直接讀 `SubViewport` 內部的原生緩衝區」

理由(見上方兩則登記的結論二):本專案 `WorldViewportContainer` 在多數解析度下滿版覆蓋整個
視窗,「裁容器矩形」在這種佈局下等於「裁整張合成畫面」——疊在世界層上方的介面層內容(HUD
文字、手牌列數字)會被一起算進「世界層」的違規數,產生無人能解釋的殘值(排除已知 HUD 矩形後
仍剩 `478 / 108134` 無法歸因)。改讀 `WorldViewport.get_texture().get_image()`——即引擎把
UI `CanvasLayer` 疊上去之前的 480×270 原生緩衝區——結構上排除這個污染源,因為介面層的畫面
根本不存在於這個緩衝區裡。

實作時必須遵守以下三項約束,皆為 2026-09-23 引擎實測所得:

1. 🔴 **`_scale` 絕不可不假思索地預設為 1,也絕不可想當然直接取世界層容器的縮放倍率
   (本專案常見值依解析度為 4/5/8)。** 原生緩衝區上容器倍率沒有意義——要取的是**被測內容
   自己應有的整數倍率**。`_scale=1` 在結構上永遠回報 0 違規,這不是「通過」,是重言式,
   不論被測內容實際狀況如何都會得到同一個答案:
   ```
   CHECK4 [Q3A-native-scale1 (structural tautology check, expect 0 by construction)] = 0 / 129600
   ```
   來源:`prototypes/godot-specialist-check4-subviewport-readback-2026-09-23/run_output_windowed.txt`
2. 🔴 **方塊格線是從影像原點 `(0,0)` 起算的絕對格線,不是相對於被測物件本身。**
   同一份 log 顯示:一個縮放完全乾淨的精靈,只因位置沒對齊到所選倍率的倍數,被判
   `16/16` 全部違規;對齊後才正確判 `0/16`;真正做壞的(3.3 倍縮放)在同樣對齊紀律下正確
   被抓到 `21/25`。**所以:量測世界層內部任一元素前,必須先確認它的位置對齊到所選倍率的
   倍數**,否則無法分辨「量法本身沒對齊」與「內容真的縮放錯誤」。
   來源:同上,`prototypes/godot-specialist-check4-subviewport-readback-2026-09-23/run_output_windowed.txt`
3. **headless 仍然拿不到像素,這條路不改變這一點。** 像素量測只能開窗執行。
   來源:`prototypes/godot-specialist-scene-load-feasibility-2026-09-23/run_output_headless.txt`
   (逐字:`Q2/SUBVIEWPORT: sub_tex.get_image() is null? true`)

#### 新判準二:「沒有東西可測」不得寫成「通過」

執行 Check 4(任一類別、任何被判定要量測世界層的畫面)之前,必須先確認被測範圍內**是否存在
任何被縮放/被重新取樣過的內容**。若不存在,證據上必須寫**「沒有可測對象(N/A)」**,
**不得**寫「0 個違規 / 通過」——兩者字面上數字可能相同,但前者是「這次沒驗證到任何東西」,
後者暗示「驗證了,而且乾淨」,對讀證據的人而言無法區分。這與本節開頭「boot splash 顏色數
比真實畫面多」那類指標會被誤讀的方向是同一個形狀:**看起來合理的數字,不等於它在回答
你以為它在回答的問題。**

📌 **以今天(2026-09-23)這份畫面內容為例,這條規則不是空規則,現在就會生效**:世界層真實
內容共 142 個節點,`.scale != (1,1)` 的有 **0** 個:
```
Q2: total descendant nodes under WorldViewport = 142
Q2: nodes with .scale != Vector2(1,1) = 0
```
來源:`prototypes/godot-specialist-worldlayer-grid-alignment-2026-09-23/run_output_headless.txt`

**亦即:以今天的畫面內容,改完之後每一次 Check 4 世界層量測,正確答案都是「沒有可測對象
(N/A)」,而不是「通過」。下一個人看到 N/A 不要當成規則沒生效或量測沒做——那就是規則生效
後,對照今天畫面內容應該得到的正確輸出。**

#### 兩條新判準都沒有自動檢查

⚠️ **與本節其餘規則一樣:沒有任何 lint、hook 或閘門會檢查上述兩條有沒有被遵守。**
規則寫了不代表有人照做——本專案沒有任何自動機制會確認 Check 4 的執行者真的讀取了
`SubViewport` 的原生緩衝區(而不是繼續裁切合成畫面)、真的核對了被測物件的位置對齊、或真的
在無可測對象時寫下 N/A 而不是「通過」。**這是管理者在知情下的選擇**——兩份意見書都明講了
這一點,協調者轉呈選項時也逐字寫明:「規則寫了不代表有人照做,本專案沒有任何自動機制會檢查
這件事」。管理者是在看過這句話之後選的「兩個一起做」。寫下這兩條規則買到的是「下一個人有
明文可查對」,不是「下一個人一定會照做」。

**本段不修改、也不刪除上方兩則「前提查證」登記的任何一字** —— 兩則登記是決策紀錄,記載了
裁決前的狀態與理由,原文保留。**本段取代的只是它們各自結尾那句「不修改 Check 4 判準」的
結論性宣告**——那句話在本次裁決發生之前是真的,現在被取代。上方 Category A、B、C 三處
Check 4 條文已同步加註指向本段。

### Why Check 5 is not replaced by anything above, in any category

Check 5 was never "the automated checks, plus a human as a backstop for cases automation can't
reach" — the original rule states it as **the only check that has ever actually caught a
defect on this project**: "Every visual defect found on this project so far was found by a
person opening the file; the automated suite has never caught one." Categories B and C exist
*because* the mechanical checks calibrated for Category A misfire by construction on those
shapes — which means, for exactly those two categories, automation's share of the detection
burden is smaller than it is for Category A, not larger. **The category with the weakest
mechanical coverage is never allowed to also have the weakest human coverage.**

⚠️ **This classification framework has no automated check of its own**, consistent with the
rest of this section — it buys "a screenshot's category and the reasoning behind it are
written down and checkable by a second reader," not "no one will misclassify a screenshot."

### Rules for capture tooling

- **Validate before writing.** Capture, check, retry while the check fails, and on exhaustion
  **error out and write nothing**. A tool that can emit false evidence is worse than no tool,
  because false evidence is trusted.
- **Never capture the full screen**, even intending to crop afterwards — the developer's
  desktop contains private content. Crop in memory or capture the window directly.
- **Window existence ≠ content drawn.** Waiting for a visible window is not waiting for the
  game; the boot splash satisfies that condition. This is a race, not a rare event: the same
  script captured gameplay and the splash nine minutes apart.
- Current tool: `tools/build/capture_window.ps1` (Godot exported builds on Windows). Its
  header records four traps in detail; read it before writing another capture tool.

## Automated Test Rules

- **Naming**: `[system]_[feature]_test.[ext]` for files; `test_[scenario]_[expected]` for functions
- **Determinism**: Tests must produce the same result every run — no random seeds, no time-dependent assertions
- **Isolation**: Each test sets up and tears down its own state; tests must not depend on execution order
- **No hardcoded data**: Test fixtures use in-test constants, factory functions, or — **only via
  the two registered exceptions named in the next bullet** — read-only version-controlled data
  files. Never inline magic numbers. **Do not invent a third kind of file access to satisfy this
  bullet.** (exception: boundary value tests where the exact number IS the point)
- **Independence**: Unit tests do not call external APIs, databases, or **write to any filesystem
  location** — use dependency injection. **Two narrow, registered read-only exceptions exist**;
  their exact scope and two attached obligations (declare the exception in the test file's header;
  disclose that it does not prove exhaustiveness) are in `.claude/rules/test-standards.md` —
  **this line deliberately does not restate them**:
  1. reading real, version-controlled fixture data under `assets/data/` — **this is what the
     "constant files" wording in the bullet above actually means in practice**
  2. reading `src/**/*.gd` / `tests/**/*.gd` source text to assert a static code-discipline rule

  **All other file I/O remains prohibited.**
  > ✅ **2026-09-17 管理者裁決:上面兩行已改寫,矛盾解除。**
  > **原文的形狀**:上一條要求「Test fixtures use constant files」,下一條禁止「file I/O」——
  > **照上一條做就必然違反下一條**,而兩條相隔兩行、同在這份每次開場載入的文件裡。
  > 2026-09-16 管理者已裁決那 10 支違反者為明文例外,**但裁決的是「准不准」,不是「這兩行怎麼重寫」**,
  > 於是矛盾又原封不動留了一天,直到 2026-09-17 才補上這次改寫。
  > 🔴 **改寫刻意不重新推翻 9/16 那次裁決** —— 它只是把第一條的「constant files」明確指向
  > 該次核准的例外範圍,讓兩條停止互相否定。**例外的範圍一個字都沒有變動。**
  > ⚠️ **仍然沒有任何自動檢查會攔第三種檔案存取。** 上面那句「Do not invent a third kind」
  > 是紀律要求,不是閘門 —— 與本專案其餘同類規則一樣,**遵守與否目前不可觀測**。

## What NOT to Automate

- Visual fidelity (shader output, VFX appearance, animation curves)
- "Feel" qualities (input responsiveness, perceived weight, timing)
- Platform-specific rendering (test on target hardware, not headlessly)
- 🔴 **Anything whose engine-side write is a no-op headless.** Verified 2026-09-07 (Story 011):
  `Input.mouse_mode = MOUSE_MODE_HIDDEN` **does nothing** under `--headless` — the value reads
  back `0` (VISIBLE) forever, whatever the code did. **The failure directions are asymmetric and
  the dangerous one is silent**: a test asserting HIDDEN (`1`) always fails (loud), while a test
  asserting VISIBLE (`0`) **always passes regardless of the production code**. ADR-0005's own
  Validation Criteria #17 asks for `Input.mouse_mode` assertions, and AC-60's exception case
  asserts VISIBLE — taken literally headless, that pair yields one permanently-red and one
  permanently-green test, **neither touching the code**.
  **Split the target**: assert the component's *decision* headless (a `diagnostic_*` read-only
  getter), and assert the engine *applied* it in a windowed run. Both, not either.
- Full gameplay sessions (covered by playtesting, not automation)

## CI/CD Rules

- Automated test suite runs on every push to main and every PR
- No merge if tests fail — tests are a blocking gate in CI
- Never disable or skip failing tests to make CI pass — fix the underlying issue
- Engine-specific CI commands:
  - **Godot**: `godot --headless --path . -s tests/gdunit4_runner.gd`
    - The runner wraps GdUnit4's own CLI entry point and supplies the mandatory flags, so CI
      does not have to remember them. Verified 2026-08-26: 9 tests, 0 failures, 0 orphans,
      exit 0, against GdUnit4 v6.2.1 / Godot 4.7.1.
    - 🔴 **The failure mode to watch for is a false green light.** GdUnit4 discards every
      argument before the token containing `GdUnitCmdTool.gd`; omit that token and it silently
      degrades to printing help text and exiting **0** — tests never ran, and CI reports pass.
      This was hit live while rewriting the runner. A test line that cannot fail is worse than
      one that fails.
    - 🔴 **`godot` is not on PATH in the local Git Bash shell, and the failure is silent.**
      The command above works in CI because the action supplies the engine. Locally it does
      not resolve, and if the invocation is piped into `grep`/`sed` the `command not found`
      message is consumed — leaving an **empty result in about one second**, which is
      indistinguishable from a clean pass. Verified 2026-08-31; only the implausibly short
      runtime gave it away. **An empty result is not a passing result — check the exit code
      of the engine itself, not of the pipeline.**
      Local invocation needs the full path to the engine binary (machine-specific — the
      value below is this development machine's, not a project constant):
      `"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . ...`
    - ⚠️ **A failing test aborts the remaining tests in its own suite.** Verified 2026-08-31:
      a suite of 5 reported `4 test cases` when the 4th failed — the 5th never ran.
      **"1 failure" never means "one thing is broken".** Re-run after fixing.
      🔴 **Second consequence, found 2026-09-04 (Story 010): this caps what an injected
      fault can prove.** Break the production code on purpose to check a test really goes
      red, and the suite stops at the *first* test that catches it — every assertion after
      that point is never executed and is therefore **unproven, not proven**. On Story 010
      the implementer's injection run reported `2 test cases` in an 11-test file; the four
      tests actually carrying the acceptance criterion were tests 3–6 and none of them ran.
      "The injection made it go red" was literally true and materially misleading.
      **Proving a test file is sensitive costs one run per assertion you want to prove** —
      reach the later ones by temporarily renaming the earlier `test_` functions out of
      collection, then revert. Budget for that before promising a sensitivity proof.
    - 🔴 **`-a <file>:<test_name>` is NOT valid filter syntax, and getting it wrong exits 0.**
      Verified 2026-09-04 while trying to run a single test case: GdUnit4 prints
      `Given directory or file does not exists: ...` followed by
      `No test cases found, abort test run!` and then reports **`Exit code: 0`**.
      **A typo'd filter therefore means zero tests executed and CI reporting success** —
      the same shape as the argument-ordering trap above, from a different direction.
      CI does not currently use filtering, so this is latent rather than live; it becomes
      live the moment anyone adds a filter to the test line. If filtering is ever needed,
      **assert on the executed-test count, not on the exit code alone.**
    - Direct invocation, if the runner is ever bypassed:
      `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/unit -a tests/integration`
      🔴 **`-a tests/unit` 單獨一項是不夠的,而且不夠的方式不會報錯。** 2026-09-04
      (Story 009,本專案第一張把測試放進 `tests/integration/` 的工作單)實測:
      runner 當時寫死只掃 `tests/unit`,新增 5 條整合測試後回報
      **386 條、1 個既有失敗、exit 100 —— 與新增之前逐字相同**,那 5 條的名字
      一次都沒出現在輸出裡。**測試存在、看起來全綠、實際一條都沒跑。**
      ⚠️ **CI 從來沒有這個問題**(`tests.yml` 的 `paths:` 本就同時列了兩者),
      所以壞掉的是**本機比 CI 寬鬆**這個方向 —— 而本機是大多數人唯一會跑的地方。
      `-a` 可重複給:GdUnit4 的 `add_test_suites()` 是 `append_array()` 不是覆寫。
      📌 **日後新增任何測試層級(例:`tests/smoke/`)必須同時加進 `tests/gdunit4_runner.gd`
      的 `FORCED_ARGS`**,否則會重演同一件事。
      `--ignoreHeadlessMode` is mandatory (without it: `Headless mode is not supported!`,
      exit 103) because the engine delivers no `InputEvent`s headless, so UI-interaction tests
      would silently do nothing.
    - 🔴 **`Overall Summary`'s `failures` counts FAILED ASSERTIONS, not failed test cases.**
      Verified 2026-09-07 (Story 011): a single test looping 10 frames with one assertion per
      iteration reported **`11 failures`** in the summary while naming only **2** tests as
      `FAILED` (the looping one plus the pre-existing red). Fixing that one test dropped the
      count from 11 to 1. **"11 failures" did not mean eleven things were broken, and the
      arithmetic gap is the only hint** — so never size the damage from the summary number.
      **Grep the log for ` FAILED` and count the named tests instead.** This is the fifth
      distinct way this test line misleads (argument ordering, silent PATH miss, filter-typo
      exit 0, exit 101, and this).
    - ⚠️ **Exit code 101 means PASSED WITH WARNINGS, not failure.** Read from GdUnit4 source:
      `errors + failures > 0` → 100; `orphan_count > 0` → **101**; otherwise → 0. A run that
      reports `0 failures` can still exit 101 purely because a test leaked nodes.
      **The fix is to stop leaking nodes — never to treat 101 as success, and never to stop
      checking the exit code.** That check is the only place the whole test line is enforced.
    - History, because "never executed" is how it survived: this row's original command used
      `--script` against a runner that called a `run_tests()` method GdUnit4 does not have.
      It was written before GdUnit4 had ever been installed, so it could never have worked,
      and nothing revealed that until the suite was first actually run on 2026-08-26. The
      runner has since been rewritten against the real entry point.
    - 🔴 **A fresh checkout must run `godot --headless --path . --import` once before the runner.**
      Verified 2026-08-26, the day the first `class_name`-declaring scripts entered the repo
      (`Board`, `LineOfSight`): without it the runner fails with
      `Parse Error: Identifier "Board" not declared in the current scope`, because
      `.godot/global_script_class_cache.cfg` does not exist yet. Two specialists hit this
      independently, and it was reproduced on a throwaway clone in the scratchpad: no import →
      fails/hangs; import first → 25 tests, 0 failures, exit 0. The import is idempotent and
      one-time per working copy; it is a prerequisite, not a change to the test command.
      ✅ **Verified 2026-08-26: the action performs the import itself.** CI checks the repo out
      from scratch every run, so had it not, the `class_name`-declaring scripts could not have
      parsed — instead the first real green run (`380472b`) reported `51 passed, 0 failed and
      0 skipped`. The import prerequisite above therefore binds local working copies only, not
      CI. The action reference moved to `godot-gdunit-labs/gdUnit4-action@v1` in the same
      commit, matching the addon's own move; the old `MikeSchulze` path 301s to it.
      🔴 **Getting to that first green meant reading the log, not the tests.** Every run from
      the day GdUnit4 was installed was red — never on a test, always inside the action's own
      `dorny/test-reporter` step, which needs `checks: write` to create a check run and was
      handed a read-only token. The suite was running and reporting into the void, and the
      workflow's own comment pointed the next reader at the wrong suspect (4.7.1 support).
      **A red CI is unread until its actual failing step is named. The failing step is not
      always the tests.**
  - **Unity**: `game-ci/unity-test-runner@v4` (GitHub Actions)
  - **Unreal**: headless runner with `-nullrhi` flag
