# Story 010:營火文案與營火卡字串入庫

> **Epic**: `production/epics/campfire/EPIC.md`
> **Status**: Blocked —— 卡在 `narrative-director` / `writer`:營火短句與營火卡名**尚未寫**。
> **Type**: Config/Data
> **Estimate**: S~M(0.5~1 估計天入庫,粗估未驗證;**寫作本身不在內**,排程估實際 1~2 天含管理者看一次)
> **依據**:v1.0 規格 10B(narrative-director:麥子健與任何人的營火合作卡寫成「人情債/臨時的默契」)、v0.3 第 6 節第 2 點(合作/競爭框架);`design/narrative/pair-premises-10-2026-11-12.md`(十組前提草稿,Provisional,每組附「營火切入點」);排程第 3.2 節(營火短句 40~120 句、營火卡 20 張)。

## 派工前須先決定

| # | 題目 | 誰決定 |
|---|---|---|
| 1 | 營火短句範圍:每組每動作 2 句(約 40 句),或再依三態分(約 120 句) | `narrative-director`(若影響審稿量 → 管理者) |
| 2 | 營火卡名:20 張(10 組 × 合作/競爭)各一名,或依模板共用名 + 姓名 | `narrative-director` + `game-designer` |
| 3 | 管理者審稿時點 | 協調者排 |

## 規則摘要

- 所有字串進 `assets/data/locales/strings.csv`(既有檔,只追加列;**合入時手算列數**,見協調者 worktree 清單)。
- 角色一律用姓名(藍亭萱/徐培恩/董振豪/秦亦柔/麥子健)。

## Acceptance Criteria

- [ ] **AC1** 營火畫面與產出卡所用的每個鍵都在 `strings.csv` 有值(資料測試掃鍵存在)。
- [ ] **AC2** 10 組 × 2 動作都有對應短句(資料測試;缺一組即紅)。
- [ ] **AC3** 改了 `strings.csv` 後跑的是包裝腳本(會重新匯入),**不得**用單檔指令驗收(舊翻譯快取假綠燈,coding-standards CI 節)。
- [ ] **AC4** 敏感度證明:刪一組短句 → AC2 紅(一次獨立執行)。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files

- `assets/data/locales/strings.csv`(只追加)、營火文案資料檔(若短句另放 `.txt`)、新資料測試。
- 超出先問。

## 與其他工單的順序

- 007 與 003 可先用占位鍵;本單在兩者之後替換。
