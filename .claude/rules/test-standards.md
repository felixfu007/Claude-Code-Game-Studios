---
paths:
  - "tests/**"
---

# Test Standards

- Test naming: `test_[system]_[scenario]_[expected_result]` pattern
- Every test must have a clear arrange/act/assert structure
- Unit tests must not depend on external state (filesystem, network, database)
- Integration tests must clean up after themselves
- Performance tests must specify acceptable thresholds and fail if exceeded
- Test data must be defined in the test or in dedicated fixtures, never shared mutable state
- Mock external dependencies — tests should be fast and deterministic
- Every bug fix must have a regression test that would have caught the original bug

## 🔴 「單元測試不得碰檔案系統」這一條:現況是 43 中有 10 條在違反,而沒有任何東西會攔

**2026-09-16 登記。這一節不是裁決,是把一件本來不可觀測的事變成可觀測的。**

**起因**:2026-09-15 管理者裁決把兩道游標保護寫成會執行的測試,產出的兩支檔案掃描
`res://src/**/*.gd` 的原始碼文字 —— 也就是做了檔案 I/O。實作者當場判定為必要例外
(對原始碼的靜態斷言不掃檔案無法實作),**但沒有登記在任何治理文件**,當日以缺口
❷ 記錄在交接檔。

🔴 **而查證時發現交接檔的範圍寫小了。不是兩支,是十支。** 當場實測(指令與原始輸出):

```bash
for f in $(find tests/unit -name '*.gd' | sort); do
  n=$(grep -c '^[^#]*\(FileAccess\.\|DirAccess\.\)' "$f")
  if [ "$n" -gt 0 ]; then printf '%-72s %s\n' "$f" "$n"; fi
done
```

```text
tests/unit/cursor/cursor_modulate_alpha_single_writer_test.gd            2
tests/unit/cursor/cursor_mouse_mode_single_writer_test.gd                2
tests/unit/gameplay/affinity/affinity_link_test.gd                       3
tests/unit/gameplay/affinity/affinity_phi_provider_test.gd               2
tests/unit/gameplay/battle/battle_controller_test.gd                     3
tests/unit/gameplay/battle/battle_controller_threat_test.gd              3
tests/unit/gameplay/battle/battle_state_test.gd                          3
tests/unit/gameplay/board/board_test.gd                                  2
tests/unit/gameplay/cards/card_permanent_write_test.gd                   1
tests/unit/gameplay/units/unit_test.gd                                   4
```

`find tests/unit -name '*.gd' | wc -l` → `43`。

**兩類,動機完全不同,不要混為一談**:

| 類 | 檔案 | 它讀什麼 | 為什麼會長成這樣 |
|---|---|---|---|
| **甲** | 上表後 8 支(2026-09-15 之前就存在) | `assets/data/` 底下的真實關卡/名冊/關係資料檔 | 本專案 `coding-standards.md` 明文要求「Gameplay values must be data-driven (external config), never hardcoded」。**測真實資料檔是在測規格本身** |
| **乙** | 上表前 2 支(2026-09-15 新增) | `src/**/*.gd` 的**原始碼文字** | 斷言的對象就是原始碼。不掃檔案則此類斷言不存在 |

### 🔴 規則自己有兩份複本,而其中一份兩行之內自我矛盾

- 本檔第 10 行:`Unit tests must not depend on external state (filesystem, network, database)`
- `.claude/docs/coding-standards.md:142`:`Unit tests do not call external APIs, databases, or file I/O`
- `.claude/docs/coding-standards.md:140`(**上一條的兩行之前**):
  `Test fixtures use constant files or factory functions`

**「constant file」只能透過檔案 I/O 讀取。** 同一份文件相隔兩行,一行要求用常數檔、
一行禁止檔案 I/O。**甲類那 8 支照第 140 行做是對的,照第 142 行做是錯的** ——
而兩行都在同一份每次對話開場載入的文件裡。

### 🔴 2026-09-16 管理者裁決:**甲乙兩類皆為明文例外**,其餘仍為禁令

**裁決當日即下,同日落檔。** 管理者選「**承認現況,寫成明文例外**」,
**明確否決**「維持禁令、十支全部改寫」與「先不決定」。

**依據(裁決時協調者提供、管理者採納)**:甲類那 8 支測真實資料檔,**抓得到「資料檔打錯字」
這種錯**;改成寫死在測試裡的假資料就抓不到了。本專案踩過的前例逐字是
「資料檔沒打包、遊戲靜默畫空棋盤、151 條測試全綠」。

#### 例外的邊界(這是例外,不是把規則刪掉)

| | 准 | 不准 |
|---|---|---|
| **甲 真實資料檔** | 唯讀 `assets/data/` 底下**已進版控**的資料檔 | ❌ 寫入任何檔案;❌ 讀 `user://`、暫存目錄或測試自己產生的檔案 |
| **乙 原始碼紀律掃描** | 唯讀 `src/**/*.gd` 的**文字**,用於斷言原始碼紀律 | ❌ 掃 `addons/`;❌ 據此推論執行期行為(它證明不了) |

**兩類以外的檔案系統存取仍然違規。** 新增這類測試前先問,不要沉默地照做。

🔴 **例外附帶兩項義務**:
1. **測試檔檔頭必須寫明它屬甲類還是乙類,以及為什麼不能用注入取代。**
   乙類那兩支(`cursor_*_single_writer_test.gd`)已有範例,且寫得比這裡要求的更徹底
   —— 它們逐條列出掃描看不見的情況與會誤判的情況。**照那個水準寫。**
2. 🔴 **乙類必須自陳它的斷言範圍不等於窮盡性。**
   「`single_writer`」說的是**斷言數了什麼**,不是「不可能有第二個寫入者」。
   反射存取、`.tscn` 動畫軌道、shader 驅動、GDExtension 都在掃描視野之外。

⚠️ **這個例外沒有自動檢查,和它豁免的那條規則一樣。** 它買到的是
「違反時看得見、且作者必須把理由寫在檔頭」,**不是「不會被濫用」**。

#### 仍未處理:`coding-standards.md` 兩行自我矛盾的那一處

上一小節指出的第 140 / 142 行矛盾,**本次裁決沒有改到它** ——
裁決的對象是「檔案 I/O 准不准」,不是「那兩行怎麼重寫」。
第 142 行現已加一行指路指到本節,**但兩行並排讀起來仍然互相打架**。
📌 **要修它是一次獨立的文件動作,不要在別的工作裡順手改** ——
那份文件每次對話開場載入,改壞的代價是全域的。

## Examples

**Correct** (proper naming + Arrange/Act/Assert):

```gdscript
func test_health_system_take_damage_reduces_health() -> void:
    # Arrange
    var health := HealthComponent.new()
    health.max_health = 100
    health.current_health = 100

    # Act
    health.take_damage(25)

    # Assert
    assert_eq(health.current_health, 75)
```

**Incorrect**:

```gdscript
func test1() -> void:  # VIOLATION: no descriptive name
    var h := HealthComponent.new()
    h.take_damage(25)  # VIOLATION: no arrange step, no clear assert
    assert_true(h.current_health < 100)  # VIOLATION: imprecise assertion
```
