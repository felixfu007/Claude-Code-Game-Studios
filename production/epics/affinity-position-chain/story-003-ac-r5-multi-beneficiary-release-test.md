# Story 003: AC-R5 新增測試 —— 多名負向夥伴同時解除負擔

> **Epic**: 好感度—位置連鎖系統(#5)
> **Status**: ✅ **Done(2026-10-12,協調者獨立驗收)** —— AC-R5 落地,**測試直接通過**。
>
> 🔴 **本 story 的驗證意義就在「它會不會通過」** —— 工作單明文:若 Y、Z 沒有各自 +1,代表 R4/R5
> 的落地並不完整,那已超出補測試的範圍。**實測通過,亦即 R4(2026-08-31 提交 `f8d1241` 的
> 「逐條加總、無抑制」)在「多受益人」這個 EPIC.md 從未驗過的角度下依然成立。**
>
> **新增 1 條測試**:`test_bonus_for_two_beneficiaries_each_gain_one_when_shared_negative_partner_removed`
>
> | 工作單要求的三項關鍵差異 | 實測落地情況 |
> |---|---|
> | ①至少兩個受益人(不是一個) | Y=2、Z=3 兩人,另加對照用第四人 W=4(站位遠離,避免 3 人盤的邊界干擾) |
> | ②負向線(不是正向線) | `"1,2,NEGATIVE,1"` + `"1,3,NEGATIVE,1"` |
> | ③不經任何額外腳本事件 | 同一測試函式內 `positions.erase(1)` 後**直接查詢**,中間零方法呼叫 |
>
> 🔴 **核心斷言寫成「各自 +1」而非「總和變了」**,逐字:
> ```gdscript
> assert_int(y_after - y_before).is_equal(1)
> assert_int(z_after - z_before).is_equal(1)
> ```
> 測試內的註解自己寫明理由:**只比總和無法區分「兩人各 +1」與「一人 +2 另一人不變」。**
> 📌 另避開 `PHI_MIN = -4` 夾限(單線負向距 1 貢獻 −1,離夾限夠遠),否則 +1 的差值會被夾掉而測不出來。
>
> **敏感度證明:歸為 A 類(static 純函式,無繼承鏈可覆寫)**,理由逐條寫在測試檔內,
> 與同檔今日稍早 AC-R1 的處理一致。這是 `.claude/rules/test-standards.md` 明文允許的二選一另一半。
>
> **協調者獨立複驗**:`grep -c "AC-R5"` → 1;`git status --short src/` 零產品碼改動;
> 全套 `1127 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans`、`EXIT 100`、
> Parse Error / Cyclic / Abnormal = 0。算術 `1116 + 10(QueryResult) + 1(本 story) = 1127`,逐項對得上。
> **Layer**: Gameplay(控制清單「核心層規則(Core)」涵蓋範圍)
> **Type**: Logic
> **Estimate**: S(0.5～1 session)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)
> **Last Updated**: —(由 `/dev-story` 開工時填)

## Context

**GDD**: `design/gdd/affinity-position-chain.md`
**需求**: R5(Core Rules,「犧牲一人」是 R4 的直接後果)+ AC-R5(Acceptance Criteria)
**TR-ID**: ⚠️ 同 story-001——本系統尚未登記進 `tr-registry.yaml`,以 GDD 自身代號 `AC-R5` 追蹤。

**Governing ADR**: `ADR: N/A` —— 理由同 story-001。

**Engine**: Godot 4.7.1 | **Risk**: LOW

**Engine Notes**: 無。

**Control Manifest Rules(此層)**: 本 story 只動 `tests/`,不動 `src/`。

---

## 🔴 這是三張 M1 故事裡唯一 EPIC.md 確認「真的缺」的一條,不是反查問題

與 story-001 / story-002 不同,EPIC.md 第 4 節對 AC-R5 的判斷是**確定性的**,不是「待反查」:

> ⚠️ **AC-R5 是三條裡唯一我有把握是真缺的**:它要驗「X 被移除後 **Y 和 Z 各自** +1」,
> 而現有最接近的 AC-R9 測試只有**一個**夥伴、且是**正向**線。AC-R5 的重點是 R5
> 「犧牲一人」那條敘事機制——**多個關係人同時解除負擔**,單夥伴測不到。

因此本 story **不需要先做反查**——直接補寫一條新測試即可,不必先讀完既有測試檔案
確認有沒有等價測試(那個確認 EPIC.md 已經做過)。

## Acceptance Criteria

*來源:`design/gdd/affinity-position-chain.md` Acceptance Criteria 節,AC-R5 原文:*

- [x] **AC-R5**:GIVEN X 與 Y、Z 各有負向距1線,WHEN X 從名冊移除,THEN Y、Z 的 `Φ`
  各自 +1,且不經任何額外腳本事件。

**與現有 AC-R9 測試的關鍵差異(必須做到,否則等於重寫 AC-R9)**:
1. **至少兩個受益人**(Y 與 Z),不是一個——這是本條要驗的核心("Y、Z **各自**")。
2. **負向線**,不是正向線——AC-R9 現有測試驗的是移除單一正向夥伴後 `Φ` 減少;
   本條驗的是移除一個帶有多條負向線的角色後,原本被負向線拖累的每個人**各自**回升。
3. **不經任何額外腳本事件**——移除後直接查詢即可看到變化,呼應 R10(無狀態)與 R9
   (位置快照每次重新讀取)的既有契約,不應該需要呼叫任何重置/清快取方法。

## Implementation Notes

- 本 story 沒有治理 ADR,不涉及 production 程式碼變動——若照 R4/R5 現有實作(逐條加總、
  無抑制)去構造測試資料,**預期這條測試會直接通過**,不需要修任何 `src/` 程式碼。
  這也是本 story 的驗證意義:確認 R4 的落地(2026-08-31 提交 `f8d1241`)在「多受益人」
  這個 EPIC.md 沒驗過的角度下依然成立,而不只是在單受益人角度下成立。
- 🔴 **若補寫時發現這條測試會失敗(即 Y、Z 沒有各自 +1)**,代表 R4/R5 的落地並不完整,
  這已超出「補測試」的範圍,請停下並回報——不要為了讓測試變綠而弱化斷言。
- 測試建構建議(非強制):三個單位 X、Y、Z 加一個對照用的第四人(避免只有 3 人時
  距離/佔位邊界情況干擾判讀),X 與 Y、X 與 Z 各有一條負向、距離 1 的線;移除 X 後,
  分別查詢 Y 與 Z 的 `Φ`,斷言兩者皆比移除前 `+1`(即恢復到 X 存在時 Y/Z 各自被 X
  拖累的那 `−1` 消失)。

## Out of Scope

- AC-R1、AC-R3——見 story-001、story-002,獨立驗收條件。
- R5「不需另外設計」這句話本身的驗證——GDD Acceptance Criteria 節已明文標註這是
  code review 範圍(「①R5『不需另外設計』這句話本身(屬 code review 範圍)」),
  不是自動測試能涵蓋的宣稱,本 story 不處理。

## QA Test Cases

*同 story-001,`lean` 模式跳過 qa-lead 正式規格產生,以下為作者依 GDD AC 原文直接轉寫:*

- **AC-R5**:
  - Given: X 與 Y 有一條負向距1線,X 與 Z 也有一條負向距1線(Y、Z 之間無線)
  - When: 從位置表移除 X,不呼叫任何重置或清快取方法,重新查詢 Y 與 Z 的 `Φ`
  - Then: Y 的 `Φ` 較移除前 `+1`,Z 的 `Φ` 較移除前 `+1`(兩者各自成立,非合計)
  - Edge cases: 若 Y 或 Z 除了與 X 的線之外還有其他線,測試需確保那些線在移除 X 前後
    保持不變,以排除「總和剛好對但個別線算錯」的偽陽性(呼應 EPIC.md AC-R8 的教訓:
    「不得改用 `bonus_for(A)` 對比 `bonus_for(B)`」這類總和層級比對可能測不到細節錯誤)。

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gameplay/affinity/affinity_rules_test.gd`
內一條新的 `test_` 函式,標註 `AC-R5`,今天會跑且通過。

**Status**: [ ] Not yet created

## Dependencies

- Depends on: None
- Unlocks: None
