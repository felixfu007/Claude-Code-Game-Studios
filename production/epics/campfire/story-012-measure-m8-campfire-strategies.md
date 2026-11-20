# Story 012:M8 營火策略量測(並恢復 M9)

> **Epic**: `production/epics/campfire/EPIC.md`
> **Status**: Blocked —— 依賴 001~006;另需 ①`systems-designer` 出量測規格(三種策略的具體操作、局數、門檻);②**管理者**同意把 skill-card story-025(M9,11-20 裁決「暫緩,等營火」)一起恢復。
> **Type**: Logic(量測工具)
> **Estimate**: M~L(1.5~2.5 估計天,粗估未驗證;headless 能否驅動整場戰役沿 v0.3 標未驗證)
> **依據**:v1.0 規格第 9 節「量測新增」M8(全關心/全質問/只對一組三策略,四關勝率與 Φ 平均;任一策略勝率較基準 +20 個百分點以上為警訊,**初值待校準**)、M9(各關開場/戰末各組關係三態次數,用於定 `k`);skill-card story-025 Status 行(「現行資料只有兩組關係線、麥子健零條,量不到」)。

## 派工前須先決定

| # | 題目 | 誰決定 |
|---|---|---|
| 1 | M8 量測規格:基準策略是什麼、每策略幾局、出牌策略如何固定 | `systems-designer` |
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
