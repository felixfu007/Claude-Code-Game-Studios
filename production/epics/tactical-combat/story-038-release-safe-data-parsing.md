# Story 038:資料檔解析的防呆改為發行版也有效(assert → push_error + 整表拒絕)

> **Epic**: `production/epics/tactical-combat/EPIC.md`(橫跨名冊/關係/卡表解析,掛此 epic 因三者皆餵戰鬥)
> **Status**: Ready(2026-11-11 協調者起草)
> ✅ **2026-11-11 加註(管理者核准狀態欄加註):已完成,提交 `f0884ac`。** 原句保留。
> **Type**: Logic
> **指派**: `godot-gdscript-specialist`

## 裁決來源

管理者 2026-11-11 逐字選項:「**修 5 處,壞資料一律整張表拒絕(推薦)**」(被跳過:只修前 4 處 / 先不修只登記)。
依據:
- `prototypes/assert-release-probe-2026-11-11/README.md` —— (A) 級:release 匯出整條移除 `assert()`,運算式不求值、函式照常往下。
- `docs/reviews/assert-release-risk-inventory-2026-11-11.md` —— lead-programmer 盤點 `src/` 18 處,必修 5 處。

## 範圍(必修 5 處,以盤點檔為準)

1. `src/gameplay/affinity/affinity_link.gd` —— 連結表欄數檢查。
2. `src/gameplay/affinity/affinity_link.gd` —— 自配連結(`unit_a == unit_b`)。
3. `src/gameplay/units/unit.gd` —— 名冊欄數(`from_csv_line`)。
4. `src/gameplay/cards/card.gd` —— 卡表欄數。
5. `src/gameplay/cards/card_text.gd` —— 牌面文字缺逗號。**依裁決比照前 4 處整表拒絕**(檔頭「壞列要不要整表中止」未決 → 本裁決定為整表拒絕;檔頭註解同步改寫為已決並指向本工單)。

做法:違反時 `push_error(<可讀訊息,含檔/列>)` 後回傳失敗值(`null` 或該解析器既有的失敗表示),由既有的「null 就整表拒絕」路徑接手。**不得留 `assert()` 作為唯一防線**(可保留作為開發期加強,但發行版行為必須由 push_error + return 決定)。

## Affected Files

- `src/gameplay/affinity/affinity_link.gd`
- `src/gameplay/units/unit.gd`
- `src/gameplay/cards/card.gd`
- `src/gameplay/cards/card_text.gd`
- 其呼叫端若需配合處理失敗值(先確認盤點檔所述「三個 `*_from_text` 已有 null 整表拒絕路徑」屬實;`card_text` 的接收端 `battle_screen.gd` 若需改,**先停下回報**,不在本範圍)
- 測試:`tests/unit/` 下對應的既有/新增測試檔

## Acceptance Criteria

- [ ] **AC-1**:5 處各有一條測試餵壞資料 → 解析回失敗、整表拒絕、不崩潰。**[自動]**
- [ ] **AC-2**:真實資料檔(`assets/data/` 全部名冊/關係/卡表)仍全數載入成功(既有全套涵蓋即可,寫明是哪幾條)。**[自動]**
- [ ] **AC-3**:測試在 debug 下不得依賴 assert 中止 —— 驗證的是 push_error + return 路徑。**實作者先探針確認 GdUnit4 遇到 `push_error` 的行為**(是否判失敗、如何斷言),結果寫進回報。
- [ ] 敏感度證明:任選 2 處,拿掉 return(只留 push_error)→ 對應測試紅 → 還原。
- [ ] 🔴 交付硬性義務:全套跑完,貼 `ENGINE EXIT`、`Overall Summary`、`Executed test suites` 原始三行。
- 發行版行為的最終確認(匯出 release 跑壞資料)不在本張 —— 可選,若做須用拋棄式副本,不得改 `export_presets.cfg`。

## Out of Scope

其餘 13 處 assert(盤點判「保留 / 無需處理」);`cursor_types.gd` `decode_tile` 除法守衛(呼叫端全為常數 13,登記為日後 board_width 可變時再升級)。
