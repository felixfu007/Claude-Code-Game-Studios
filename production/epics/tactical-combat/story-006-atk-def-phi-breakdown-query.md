# Story 006: `ATK`/`DEF`/`Φ` 拆解查詢 + 基準值/有效值存取層(#6 反向依賴)

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M3a(切面 5)
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-09-09

## Context

**GDD**: Formulas 公式一(傷害計算 `damage_formula = max(0, ATK − DEF + Φ)`)、UI Requirements
§4(攻擊確認與傷害拆解面板,最小欄位 `ATK`/`DEF`/`Φ`/結果傷害/目標剩餘 HP)、
Visual/Audio §2(傷害回饋須拆解出 `Φ` 的貢獻,不得只給合併整數)、AC-12。

**Requirement**: `TR-tactical-030`(傷害路徑須回傳完整拆解,須容忍不設上限的 `Φ`)、
`TR-tactical-043`(#6 技能卡牌效果掛鉤須滿足同步契約,可行性尚未確認 OQ-4——與本 story 的
存取層有交界但不同範圍)

🔴 **本 story 的第二個目標(基準值/有效值存取層)是 #6 技能卡牌系統的登記在案反向依賴,
管理者已許可**——但其文件面義務(GDD 補「存取層」一節)由 `systems-designer` 擁有,
**截至本 story 切出時尚未完成**:
```
$ grep -c "存取層" design/gdd/tactical-combat-system.md
0
```
GDD 第 171 行目前只是 2026-08-17 的舊佔位句「具體介面待該系統設計時定案」。EPIC.md C5 已
登記此義務期限為「M3 切面 5 的 story 切出來之前」——**該期限未被滿足,已在 `story-index.md`
誠實記錄**。本 story 的處置:程式面驗收條件本身不受影響(#6 已登記、管理者已許可的既有契約,
「補實作不等於補 ADR」,EPIC.md 原文),但**本 story 的驗收不應阻塞於等待該 GDD 章節完成**——
存取層的介面形狀由本 story 的實作者依現有 `Unit` 資料結構自行設計,待 `systems-designer` 補上
GDD 章節後再確認是否一致;若不一致,以 GDD 章節為準做事後調整(記為技術債,非本 story 的
延遲理由)。

**ADR Governing Implementation**: `ADR-0001`(**Accepted**)—— 傷害拆解查詢受 Core Rules #5
「`Φ` 的取值時點為快照」規則約束(公式一的 `Φ` 必須是結算步①查得的快照,不因步驟②的寫入
而重新查詢,見 AC-6)。

**Engine**: Godot 4.7.1 | **Risk**: LOW

## 現況(2026-09-29 實測)

UX 規格 5(a) 節已記載:「`_info_label` 目前只顯示 `format_damage_preview()` 的合併字串
(`"打擊 %d　血量 %d→%d"`),沒有任何地方單獨顯示 `ATK`、`DEF`、`Φ` 三個欄位」。
`_phi.phi()` + `_state.preview_damage()` 現況只回傳合併後的單一整數,無拆解介面。

## Acceptance Criteria

- [ ] 新增查詢(暫名 `preview_damage_breakdown(attacker_id, target_id)` 或等效簽章)回傳
      `ATK`(攻擊方有效攻擊力)、`DEF`(目標有效防禦力)、`Φ`(帶號整數,`=0` 仍須可讀)、
      結果傷害(`max(0, ATK-DEF+Φ)`)、目標結算後預估 HP 五個欄位(GDD UI Requirements §4)
- [ ] `Φ` 上界不設任何隱性截斷(GDD 公式一「上界目前無夾限」;#5 好感度—位置連鎖系統尚未
      定案 `Φ_max`,本 story 不得預先假設任何上限值)
- [ ] 純函數、零寫入(供預判模式與攻擊確認面板共用底層查詢——但**不得**共用同一個 UI 元件
      或呼叫路徑本身,那是 UI Requirements §5 對呈現層的約束,不是本查詢的約束;本 story
      只需保證查詢本身無副作用)
- [ ] **新增基準值/有效值存取層**:提供查詢「單位當前有效 `ATK`/`DEF`/`HP`/`MP`」的公開介面,
      區分「基準數值」(角色設定值,`player_baseline_stat` 或敵方縮放前的數值)與「有效值」
      (經公式二敵方縮放、或未來卡牌加成後的當前值)——**具體資料形狀由本 story 決定**,
      GDD 第 171 行(待補「存取層」章節前)只給出既有的公式一/二變數定義,無更細節的介面規格
- [ ] 遵守 Core Rules #5「`Φ` 的取值時點為快照」——本查詢回傳的 `Φ` 若被結算步①使用,結算步③
      不得重新查詢,必須沿用①的快照值(此為既有規則,本 story 的新查詢介面不得破壞它)

## Implementation Notes

1. **本 story 產出兩個相對獨立但相關的介面**:①攻擊傷害拆解查詢(UI 直接消費,供 story-013
   攻擊確認面板使用);②基準值/有效值存取層(#6 技能卡牌系統的反向依賴消費,不直接服務任何
   本 epic 內的 UI story)。兩者可以是同一個模組內的不同公開方法,不需要拆成兩個檔案。
2. ⚠️ **未查證**:`Unit` 類別目前是否已有區分「基準值」與「有效值」欄位的資料結構——
   下一個人應先 `grep -n "class_name Unit\|var atk\|var def\|var hp" src/gameplay/battle/`
   一類指令確認現況,再決定存取層是新增欄位還是新增計算方法(例如敵方單位的「有效值」可能
   本來就是公式二縮放後直接存入的欄位,不需要每次查詢時重新計算)。
3. **`Φ` 快照義務的具體實作提醒(GDD Core Rules #5 原文)**:若查詢回傳型別不是裸 `int`/`float`
   而是 `Dictionary`/`Resource` 等參照型別,呼叫端須顯式複製(`Dictionary` 用 `.duplicate(true)`;
   巢狀 `Resource` 用 `duplicate_deep()`,**不得用已棄用的 `duplicate()`**——見
   `docs/engine-reference/godot/deprecated-apis.md`)後才能視為快照,不得直接持有參照。
4. **本 story 不裁決 #6 卡牌系統的效果掛鉤介面本身**(TR-tactical-043 的同步契約範圍)——
   只提供基準值/有效值的讀取查詢,不提供寫入或修改介面。

## Out of Scope

- **攻擊確認面板的 UI 呈現**——story-013(M5),消費本 story 的拆解查詢輸出。
- **#6 技能卡牌系統的效果掛鉤契約本身**(是否能滿足 Core Rules #11 同步契約)——OQ-4,屬 #6
  設計時確認,不在本 story 範圍。
- **GDD「存取層」章節文字本身**——擁有者為 `systems-designer`,不由本 story 代寫。
- **`Φ_max` 上界定案**——擁有者為 #5 好感度—位置連鎖系統,本 story 只保證不預先假設上限。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 Task 工具不可用而跳過。

- **拆解欄位完整性(AC-12 對照)**
  - Given: `ATK=12, DEF=8, Φ=+3`
  - When: 呼叫拆解查詢
  - Then: 回傳 `ATK=12, DEF=8, Φ=+3, 結果傷害=7, 目標預估HP=目標當前HP-7`
- **`Φ=0` 仍可讀(Visual/Audio §2 對照)**
  - Given: `Φ=0`
  - When: 呼叫拆解查詢
  - Then: `Φ` 欄位明確回傳 `0`,不得省略該欄位或以空值代替
- **極端正值無截斷**
  - Given: `Φ=+500`
  - When: 呼叫拆解查詢
  - Then: 結果傷害正確反映 `504`(或對應輸入),不產生任何截斷或溢位
- **零寫入驗證**
  - Given: 任一輸入
  - When: 呼叫拆解查詢前後比對棋盤/HP/好感度數值池狀態
  - Then: 完全相同(純函數)
- **基準值/有效值存取層基本查詢**
  - Given: 一個敵方單位(有效值經公式二縮放)
  - When: 分別查詢其基準值與有效值
  - Then: 兩者不同(有效值反映 `enemy_advantage_pct` 縮放後結果),且有效值查詢的結果與
    公式二 `ceil(baseline × (1+pct))` 一致

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gameplay/battle/damage_breakdown_query_test.gd` —— BLOCKING

**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(不依賴 M2;⚠️ EPIC.md C5 擁有者義務——`systems-designer` 補 GDD「存取層」
  章節——截至本 story 切出時尚未完成,見上方 Context 節,已誠實記錄於 `story-index.md`)
- Unlocks: story-013(攻擊確認面板消費拆解查詢)

## 執行層序列化

本 story 屬 M3a,不受 M6→M5→M4 序列化約束。
