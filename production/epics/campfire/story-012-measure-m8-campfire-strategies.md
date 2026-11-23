# Story 012:M8 營火策略量測(並恢復 M9)

> **Epic**: `production/epics/campfire/EPIC.md`
> **Status**: Blocked —— 依賴 001~006 與 013(對話寫入時機會影響量到的關係);另需 ①`systems-designer` 出量測規格;②**管理者**同意把 skill-card story-025(M9)一起恢復。(2026-11-23 檢查:兩項皆未變。)
> (原狀態:Blocked —— 依賴 001~006;另需 ①`systems-designer` 出量測規格(三種策略的具體操作、局數、門檻);②**管理者**同意把 skill-card story-025(M9,11-20 裁決「暫緩,等營火」)一起恢復。)
> **Type**: Logic(量測工具)
> **Estimate**: M~L(1.5~2.5 估計天,粗估未驗證;headless 能否驅動整場戰役沿 v0.3 標未驗證)
> **依據**:v1.0 規格第 9 節「量測新增」M8、M9;skill-card story-025 Status 行;管理者 2026-11-20 裁決第 3 題(每輪 3 次、同輪同組不重複、輪數 = 場數 − 1)、第 4 題與 2026-11-23 第 1 題(預設 12 張)。

## 背景(2026-11-23 補)

- 戰役 5 場(`assets/data/levels/campaign_sequence.txt` 第 40~44 列),營火 4 輪(第 2~5 場之前各一輪),每輪 3 次 → 一輪遊玩最多 12 筆營火寫入。M8 的「四關勝率」= 第 2~5 場。
- 策略腳本要遵守「同輪同組不重複」:例如「只對一組」策略**每輪只能對那一組做 1 次**,其餘 2 次如何處理須在量測規格寫明(本題由 `systems-designer` 定,producer 不代判)。

## 派工前須先決定

| # | 題目 | 誰決定 |
|---|---|---|
| 1 | M8 量測規格:基準策略是什麼、每策略幾局、出牌策略如何固定、「只對一組」在同組不重複規則下的定義 | `systems-designer` |
| 2 | 恢復 skill-card story-025 | **管理者**(同一次問) |
| 3 | 結果若顯示某策略壓倒性,誰決定調什麼(creative-director 已建議調 `k` 與加成曲線,不調 `m`) | `systems-designer` 提案 → 管理者 |

## 規則摘要

- 量測腳本**必須執行專案自己的類別**、`load()` production 場景檔,不得重新實作規則(technical-preferences「(A) 的精確定義」與第 5 點)。
- 留原始 log;報告逐條附可重跑指令。結果標 (A) 級時附執行檔路徑。

## Acceptance Criteria

- [ ] **AC1** 三種策略各跑完規定局數,輸出勝率與 Φ 平均(原始 log 進版控旁的 `prototypes/` 或 `production/qa/`)。
- [ ] **AC2** M9:各關開場與戰末 10 組三態次數表。
- [ ] **AC3** 量測工具自身的敏感度:把營火寫入量設為 0 → 三種策略結果應與基準無差;若有差,工具有問題(一次獨立執行並留 log)。
- [ ] **AC4** 結果交 `systems-designer` 判讀;**本單不改任何旋鈕**。
- [ ] 若有新增正式測試,交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files

- 新檔:量測腳本(`prototypes/` 或 `tests/perf/` 類的非收集位置,由實作者依 `tests/perf/README.md` 慣例提)。不改產品碼。

## 與其他工單的順序

- 可與 011 平行。01-22 前**至少執行一次**;門檻校準可在交付後。
