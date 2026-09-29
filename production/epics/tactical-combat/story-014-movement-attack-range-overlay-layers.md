# Story 014: 移動範圍三態+第四態、攻擊範圍三層疊加圖(世界層繪製)

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M4
> **Status**: Ready(規劃層無阻擋;執行層見下方序列化)
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: 2026-09-09

## Context

**GDD**: Visual/Audio §1.1(移動範圍可達/兩種不可達成因)、§1.2(武器射程三分層,遠程盲區
併入範圍外)、§1.3(視線遮蔽第三態)、§1.4(遮蔽與移動成本正交呈現)、AC-13/AC-14/AC-20。

**ADR Governing Implementation**: `ADR-0001`(**Accepted**)—— 疊加圖須遵守 AC-20/AC-22 的
即時性 + 單一快照原子性(移動範圍疊加圖與威脅範圍疊加圖須共用同一份快照,若兩者同時可見)。

**Engine**: Godot 4.7.1 | **Risk**: LOW(純繪製邏輯,無 post-cutoff API 依賴——但須遵守
`.claude/docs/coding-standards.md` 的 Check 4 世界層量法規則,見下方 Test Evidence)

## Acceptance Criteria

- [ ] **移動範圍三態 + 第四態**:可達(`A`)、不可達-被佔位擋死(`B\A`)、不可達-地形不可通行
      (`C\B`)、不可達-移動力不足(`Grid\C`)——四者皆須有獨立的**非色彩通道**視覺標記
      (`P-F3` 無例外),沿用既有 `THREAT_HIGHLIGHT_PATH` 的「環狀 vs 實心」手法而非另創一套
- [ ] **攻擊範圍三層**:無疊加 / 合法可攻擊 / 範圍內但視線被擋(story-003 的查詢輸出)——
      第三層不得被畫成與「無疊加」相同(GDD Core Rules #4 明文要求)
- [ ] 遠程盲區併入「範圍外」共用視覺處理,**不另設獨立視覺狀態**(GDD 2026-08-13 使用者裁決
      R-VA1 乙案,已定案,不在本 story 重新裁決)
- [ ] 所有範圍圖形一律呈現為**曼哈頓菱形**,不得為視覺順眼畫成圓形或方形
- [ ] 全部新增層須通過灰階複驗(比照 `skill-card-play.md` HP 對比度修復批次的既有紀律)
- [ ] 遵守 AC-20/AC-22(a):疊加圖顯示期間棋盤變化,重繪須反映最新狀態,不得沿用快取畫面

## Implementation Notes

1. **本 story 是純消費端**——移動範圍四態的資料來自 story-007,攻擊範圍第三層的資料來自
   story-003。本 story 不重新計算任何查詢邏輯,只負責把既有查詢輸出畫成畫面。
2. **`board_view.gd` 現有繪製路徑不動**(EPIC.md 明文「比重:新增圖層為主,`board_view.gd`
   現有繪製路徑不動」)——新增獨立圖層,比照既有 `StatsLayer` 的作法。
3. ⚠️ **未查證**:`THREAT_HIGHLIGHT_PATH` 的「環狀 vs 實心」具體實作細節(繪製函式、資源
   路徑)——下一個人應先讀 `board_view.gd` 內該常數的使用方式,依樣延伸到新增的四態/三層。

## Out of Scope

- **查詢邏輯本身**(移動範圍四態、視線第三層)——story-007、story-003。
- **敵方威脅範圍疊加圖的繪製**——依 EPIC.md,威脅範圍疊加圖歸屬 #10 戰鬥 HUD 決定呈現方式,
  本 story 只確保移動/攻擊範圍與威脅範圍**可同時可見**(不互斥),不負責威脅範圍本身的繪製。
- **正式美術資產**——本 story 以 placeholder 推進(2026-09-29 管理者裁決,`design/art/`
  無正式圖,`assets/art/` 只有 `placeholder/`)。驗收的是形狀與非色彩通道是否成立,不是美術
  品質。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 Task 工具不可用而跳過。**Visual/Feel 型 story,以下為手動驗證
步驟而非自動化測試規格**(依 `.claude/docs/coding-standards.md` Test Evidence by Story Type)。

- **移動範圍四態可辨識**
  - Setup: 建構一個含佔位、地形不可通行、移動力邊界的混合盤面,選取單位
  - Verify: 四種狀態各自有獨立的非色彩通道標記(形狀/圖示/邊框差異)
  - Pass condition: 灰階模式下四態仍可互相區分
- **攻擊範圍三層可辨識**
  - Setup: 一名遠程單位,盤面含遮蔽地形
  - Verify: 無疊加/合法可攻擊/視線被擋 三層各自可辨識
  - Pass condition: 灰階模式下三層仍可互相區分,第三層不與「無疊加」混淆
- **遠程盲區併入範圍外**
  - Setup: 遠程單位,檢視其相鄰格(盲區)
  - Verify: 盲區格與距離 5 以上的「範圍外」格視覺相同,無獨立標記
- **曼哈頓菱形**
  - Setup: 任意射程/移動範圍
  - Verify: 圖形邊界為曼哈頓菱形,非圓形/方形
- **即時性(AC-20)**
  - Setup: 疊加圖顯示期間,另一單位移動改變佔位
  - Verify: 觸發重繪後,疊加圖反映新狀態

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/movement-attack-range-overlay-evidence.md`

🔴 **截圖批次化(管理者裁決,附帶建議 3)**:**本 story 不要求逐 story 截圖複核**。
全部 M4 截圖證據(本 story + story-015)累積至 M4 兩張 story 皆完成後,**一次性**交由管理者
在家中桌機複核(理由:管理者上班座位有人經過,遊戲畫面不可出現在該螢幕上;headless 取不到
像素,截圖只能開窗跑——見 `.claude/docs/coding-standards.md`)。本 story 完成時,截圖依 Category
A/B/C 分類(此為世界層全螢幕呈現,預期屬 Category A)存入 `production/qa/evidence/`,**標記
為「待批次複核」**,不視為本 story 未完成的理由。

⚠️ **Check 4 世界層量法**(灰階/整數縮放驗證):依 2026-09-23 管理者裁決,世界層的操作型定義
改為直接讀 `SubViewport` 的原生緩衝區,不得裁切合成畫面——本 story 的截圖證據若涉及 Check 4
驗證,須遵循該量法,不得沿用舊的「裁切容器矩形」方法。

**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-003(視線第三層查詢)、story-007(移動範圍四態查詢)、
  story-012/013(M5 完成,執行序列化)
- Unlocks: None

## 執行層序列化(M6 → M5 → M4)

本 story 屬 M4,**M6(008-011)與 M5(012-013)須先執行完成**,本 story 才可開工——理由:
三者共用 `src/ui/battle/battle_screen.gd`,本 story 對其改動最輕(`_refresh_view()` 多傳幾個
參數),放最後受前兩者影響最小(EPIC.md 明文)。
