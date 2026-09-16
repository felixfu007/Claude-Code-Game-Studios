# Story U-004: `InputMap` 探針 —— 5 個候選鍵是否已被內建動作佔用

> **Epic**: 卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **狀態**: 📋 Ready
> **層**: Presentation(拋棄式探針,不進 `src/`)
> **型別**: Logic(拋棄式探針 —— 產出是一份量測報告,不是功能)
> **估時**: S
> **依賴**: 無
> **解鎖**: U-005
> **波次**: 波 0(與 U-001 ∥ U-002 ∥ U-006 四路真平行 —— 四個不同檔,零交集)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)

## Context

**權威來源**:`design/ux/skill-card-play.md`「按鍵配置」節、`design/ux/battle-menu.md`
「Interaction Map」節 —— 兩份都要求新動作綁定前先跑探針。

**Governing ADR**:ADR-0005(**Accepted**)—— 呈現層規則「載入期必須驗證 Input Map 約束
…鍵不存在時回報 UNKNOWN,不得視為通過」(`docs/architecture/control-manifest.md` 呈現層
規則節)。本 story 是這條規則在新增卡牌/選單動作前的具體執行。

## 目標

在把 5 個新動作(`battle_cancel`、`open_hand`、`next_target`/`prev_target`、`battle_menu`
——實際命名以實作時定案,見下)寫進 `project.godot` 之前,實測確認建議的按鍵沒有被任何
既有內建 `ui_*` 動作佔用,尤其是手把的動作鍵(A/B/X/Y 或等效的下/右/左/上)。做完之後,
U-005 寫 `project.godot` 時用的是**量出來的答案**,不是**猜的答案**。

## Implementation Notes

1. 🔴 **新增的手把鍵絕不可用上動作鍵(Y / Triangle)(EPIC.md 陷阱九,轉錄,本 story 的
   核心職責就是覆核這件事)**:

   > 2026-08-27 實測結論逐字:**「沒有任何內建 `ui_*` 動作同時綁了鍵盤與手把、又還沒被
   > 佔用」**,其中 `ui_select` 的**手把綁定就是上動作鍵(Y)**、鍵盤綁定是 **Space**,
   > 而 Space 已被 `battle_confirm` 佔用 → **同一次按鍵觸發兩個動作**。**這是已實測過的
   > 失效形狀,而它不會報錯。**
   >
   > UX 規格建議手把用 **X(左動作鍵)**,正是為了避開已知的那一個。**U-004 的探針要
   > 覆核這件事。**

   **本 story 是 EPIC.md 明文指名要「覆核這件事」的那個探針** —— 不是重跑一次已知結論,
   而是針對本 epic 實際提議的 5 個候選鍵(含兩份 UX 規格建議的手把 X / RB / LB / Start
   等)逐一確認,而不是假設 2026-08-27 那次探針涵蓋了今天要新增的全部按鍵。

2. **探針產出是一份量測報告,不是功能** —— 依 EPIC.md 對本單元的定性,本 story 的產物是
   一個拋棄式腳本 + 它的輸出記錄,**不寫入 `src/`**。放在 `prototypes/`(本專案目前沒有
   這個目錄,本 story 是第一個建立它的單元)。目錄名沿用本專案既有的「描述-日期」慣例
   自訂,例如 `prototypes/input-map-key-collision-probe-2026-09-XX/`(日期為實作當天,
   非本 story 裁決,實作時可依實際情況調整目錄名 —— 這不是需要覆核的裁決,只是命名)。

3. **探針必須實際呼叫引擎的 `InputMap` 查詢**(例如 `InputMap.action_get_events()` /
   `InputMap.has_action()` 等,具體 API 由實作時對照 Godot 4.7.1 文件確認),對每個候選鍵
   逐一檢查:①該按鍵是否已綁在任何既有 `ui_*` 或本專案既有動作(`battle_confirm`、
   `battle_end_phase` 等)上;②若已佔用,佔用它的動作在鍵盤/手把兩側是否都有其他綁定
   (若某動作只在一側有這個綁定,衝突的嚴重程度不同,需要在報告裡分別記錄)。
   **不得只讀 `project.godot` 檔案的文字內容當作「查詢」** —— 內建 `ui_*` 動作的預設綁定
   不一定寫在 `project.godot` 裡(它們是引擎的預設值),必須實際呼叫 `InputMap` API 才能
   看到完整的合併結果。

4. **候選鍵清單,取自兩份 UX 規格(逐一列出,供探針覆核)**:

   | 動作(暫定名) | 鍵盤建議 | 手把建議 | 來源 |
   |---|---|---|---|
   | 取消 / 退一步(`battle_cancel`) | Esc | B(右動作鍵) | `skill-card-play.md` |
   | 開 / 收手牌 | `C` | X(左動作鍵) | `skill-card-play.md` |
   | 跳下一個合法目標 | `Tab` | RB | `skill-card-play.md` |
   | 跳上一個合法目標 | `Shift+Tab` | LB | `skill-card-play.md` |
   | 開啟選單(`battle_menu`) | `M` | Start | `battle-menu.md` |

   ⚠️ **`Esc`/`B` 目前已綁在 `battle_end_phase` 上**——這條探針要確認的不是「這兩個鍵有沒
   有被佔用」(它們本來就被本專案自己的既有動作佔用,這是刻意的過渡狀態,見 U-005),
   而是**除了 `battle_end_phase` 之外,鍵盤 `Esc` 與手把 `B` 有沒有同時被任何內建
   `ui_*` 動作佔用**——若有,新增 `battle_cancel` 綁同一個鍵會產生三個動作同時觸發的
   情況,比 U-005/U-016 之間刻意接受的「兩個動作同時觸發」更糟,必須在報告裡特別標註。

5. **報告格式**:每個候選鍵一行,記錄「鍵盤按鍵 → 目前綁定的動作清單」與「手把按鍵 →
   目前綁定的動作清單」,並明確標示每一組是否有衝突、衝突的動作名稱、以及該動作是否
   同時有鍵盤與手把綁定(重現 2026-08-27 `ui_select` 那個案例的判斷邏輯)。

## Acceptance Criteria

*本單元沒有對應的 AC-U / AC-M 條文——它是一個拋棄式探針,產出是量測報告而非功能
(EPIC.md 第三節明文登記)。以下是本 story 自訂的驗收基準:*

- [ ] 探針對 5 個候選鍵(鍵盤 + 手把兩側,共 10 個按鍵)逐一查詢 `InputMap`,不遺漏任何一個
- [ ] 報告明確指出哪些候選鍵目前無衝突、哪些有衝突,衝突時列出佔用的動作名稱
- [ ] 報告明確回答陷阱九的具體問題:手把 X(左動作鍵)是否真的比 Y(上動作鍵)更安全
      (即 X 未被任何同時綁鍵盤+手把的內建動作佔用)
- [ ] 報告明確回答 `Esc`/`B` 除了 `battle_end_phase` 之外是否還有其他動作佔用

## Test Evidence

**型別**:Logic(拋棄式探針,非永久自動化測試)
**產物**:`prototypes/input-map-key-collision-probe-[日期]/`(含探針腳本與其輸出報告)

⚠️ **本 story 不產生 `tests/` 底下的永久測試檔** —— 依 `.claude/docs/directory-structure.md`,
`prototypes/` 的試作不受 `src/` 的規範約束,也不得被正式程式碼引用。探針本身的正確性由
「報告內容與實際 `project.godot`/引擎預設值相符」佐證,不需要另外的自動化測試包裝它。

## Out of Scope

- **實際把 5 個動作寫進 `project.godot`**——屬 U-005,本 story 只提供量測依據
- **`battle_end_phase` 解綁**——屬 U-016(切片內但不在本次 8 個單元授權範圍內)
- **選單畫面、手牌介面等任何功能實作**——本 story 不產生任何 `src/` 變更

## Dependencies

- 依賴:無
- 解鎖:U-005(需要本 story 的量測結果決定最終按鍵是否需要調整)
