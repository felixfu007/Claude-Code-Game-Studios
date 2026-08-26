# src/gameplay/

回合制戰棋與好感度數值池的正式實作落點。

## 放什麼

- 棋盤查詢與狀態(對應 ADR-0001,目前仍 `Proposed`——引用它的 story 在
  `src/` 正式開發前會被 `/story-readiness` 擋下,寫程式前先確認該 ADR 狀態)
- 好感度數值池資料結構與並發存取(對應 ADR-0002,已 `Accepted`,可開始寫)
- 回合流程、戰鬥結算(⚠️ 結算路徑禁止 RNG——見
  `.claude/docs/technical-preferences.md` 的 `rng_in_combat_settlement` 專案級禁令,
  唯一豁免是好感度對話卡牌的**牌面**隨機)
- 單位、地形格資料(地形一律手工設計,禁止程序化生成——`procedural_terrain_generation`)

## 不放什麼

- 任何連線/多人相關程式碼——`networking_features` 專案級禁令,單機遊戲,
  `src/networking/` 依此裁決不建立

## 依賴查核

寫任何新系統前先查 `docs/registry/architecture.yaml` 的 `forbidden_patterns` 節,
逐項附 `why:`,比本檔或 `technical-preferences.md` 的摘要更完整。
