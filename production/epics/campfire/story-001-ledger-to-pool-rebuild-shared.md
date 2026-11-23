# Story 001:累積記錄重建好感度池,從戰鬥畫面抽成共用

> **Epic**: `production/epics/campfire/EPIC.md`
> **Status**: Done(2026-11-23 `8dfb48c`;協調者全套 2581 綠)
> (2026-11-23 收工前狀態:Ready(2026-11-20 producer 草擬;無管理者題、無設計待決))
> **Type**: Logic(重構,零行為變更)
> **Estimate**: S~M(約 1 估計天,粗估未驗證)
> **依據**:v1.0 規格 4.3「寫入立即生效,下一場戰鬥即反映」、4.4「先寫池、再依寫入後的 `v` 產卡」、6.3 (1)「寫入前顯示該配對當前 S 與寫入後的預期 S」;登記表契約 `affinity_relation_state_single_judgment`(`docs/registry/architecture.yaml`,「ONE JUDGMENT, ONE PLACE」)。

## 背景(producer 2026-11-20 實查)

- 營火要讀「現在每組關係是什麼」與「寫入後的 `v`」。戰鬥場景結束後池子就丟了,**營火時記憶體裡只有 `CampaignAffinityLedger`**(戰役累積記錄)。
- 「累積記錄 → 新池子」的重播目前只寫在 `src/ui/battle/battle_screen.gd` 的 `_ready()` 裡(grep `campaign ledger replay record`),經 `_apply_opening_affinity_record` 寫入。營火不是戰鬥畫面,**拿不到它**。
- 若營火自己再寫一份重播,就是本專案登記過的「兩份實作只是今天答案一致」形狀。**所以先抽出來,兩邊共用。**

## 派工前須先決定

- 無管理者題。共用函式放哪個檔、叫什麼名字,由實作者依 `.claude/rules/gameplay-code.md` 提出、協調者覆核。
- ⚠️ **不得新增靜態狀態持有者**(該規則已有兩個登記例外,再要第三個須重新裁決)—— 共用函式應是純函式(輸入累積記錄,回傳新池)。

## 規則摘要

- 新增一個純函式:輸入 `CampaignAffinityLedger`(與池建構所需的既有參數),回傳一個灌好全部記錄的 `AffinityDataPool`;拒絕碼照現行做法 `push_error`,不得吞掉、不得用 `assert()`。
- `battle_screen.gd` 改呼叫它。**第 1 場的開場灌入(`seed_into_ledger`)邏輯不搬**,留在戰鬥畫面(那是戰鬥開局的事,不是重播)。
- 零行為變更:同一份累積記錄,抽出前後戰鬥開局的池內容逐筆相同。

## Acceptance Criteria

- [ ] **AC1** 單元測試:給一份含 3 組配對、正負混合、多筆的累積記錄,共用函式回傳的池對每組 `combat_strength_read` 的 `value` 與 `n_pair` 符合逐筆累加結果;**至少 1 組含麥子健、1 組非人設配對**。
- [ ] **AC2** 空累積記錄 → 10 組全部 `n_pair == 0`,`AffinityRelation.state_of()` 全部 `NONE`。
- [ ] **AC3** 既有戰鬥/支援對話/戰役回滾相關測試全綠,且**未修改任何既有斷言**(要改就停下回報)。
- [ ] **AC4** 敏感度證明(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①共用函式漏掉最後一筆記錄 → AC1 紅 ②`battle_screen.gd` 改回不呼叫共用函式而改呼叫空實作 → 至少一條既有戰役重播測試紅(證明戰鬥端真的走共用函式)。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files

- `src/ui/battle/battle_screen.gd`(改呼叫共用函式)
- 新檔:`src/gameplay/campaign/` 下一支(名稱由實作者提)
- 新測試:`tests/unit/gameplay/campaign/`
- 超出先問。

## 與其他工單的順序

- 最先做;002(寫入口)、003(產卡)、007(營火畫面預覽)都讀它的結果。
- 與 skill-card story-024(測試改寫,In Progress)可能碰同一批好感度測試檔 —— **開工前先確認 024 是否已提交**,避免兩邊同時改同檔。
