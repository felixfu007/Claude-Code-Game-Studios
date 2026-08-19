# 測試基礎設施

| 欄位 | 值 |
|---|---|
| **引擎** | Godot 4.7.1(釘選於 `docs/engine-reference/godot/VERSION.md`) |
| **測試框架** | **GdUnit4** |
| **CI** | `.github/workflows/tests.yml` |
| **建立日期** | 2026-08-19(`/test-setup`) |

> **框架選定的沿革**:專案曾同時存在兩個互相矛盾的宣稱 ——
> `.claude/docs/technical-preferences.md` 寫 `GUT`,而 `.claude/docs/coding-standards.md`
> 的 CI 指令寫 `tests/gdunit4_runner.gd`。兩者是不相容的框架。2026-08-19 由使用者裁決採
> **GdUnit4**,`technical-preferences.md` 已同步更正。

---

## 目錄結構

```
tests/
  unit/              單元測試 —— 一個系統一個子目錄(公式、狀態機、純邏輯)
    harness/         測試骨架自我檢查(見下方)
  integration/       整合測試 —— 跨系統、存檔讀取往返
  smoke/             關鍵路徑清單,供 /smoke-check 讀取
  gdunit4_runner.gd  headless 執行入口

production/qa/evidence/   視覺/回饋類與 UI 類故事的證據落點(**不在 tests/ 底下**)
```

> **證據落點為何不在 `tests/evidence/`**:`/test-setup` 與 `/smoke-check` 兩個 skill 的範本
> 寫 `tests/evidence/`,但 `.claude/docs/coding-standards.md` 與 `create-epics`、
> `create-stories`、`dev-story`、`story-done`、`gate-check` 共**六處**寫
> `production/qa/evidence/`。六比二,且 coding-standards 是每個 session 都會載入的檔案,
> 故採後者。此為對 `/test-setup` 範本的一處明文偏離。

---

## 執行測試

```bash
# 本機 / 任何無法使用 GitHub Action 的環境
godot --headless --script tests/gdunit4_runner.gd
```

CI 走另一條路(`MikeSchulze/gdUnit4-action`)。**兩條路都必須維持可用**:
Action 用於自動化,runner 用於本機除錯。

### 前置:安裝 GdUnit4

建立本文件時 `addons/` 尚不存在,GdUnit4 **未安裝**。Godot 專案建立後:

1. Godot 編輯器 → AssetLib → 搜尋 `GdUnit4` → 下載並安裝
2. 專案 → 專案設定 → 外掛 → GdUnit4 打勾啟用
3. 重啟編輯器
4. 確認 `res://addons/gdUnit4/` 存在

---

## 命名慣例

| 對象 | 規則 | 範例 |
|---|---|---|
| 檔名 | `[system]_[feature]_test.gd` | `affinity_decay_test.gd` |
| 函式 | `test_[scenario]_[expected]` | `test_zero_delta_returns_unchanged_pool()` |

---

## 測試骨架自我檢查

`tests/unit/harness/harness_selfcheck_test.gd` 驗證的是**基礎設施本身**,不是遊戲邏輯:

- 斷言 API 可用(框架未正確安裝則整檔不編譯)
- **框架真的會判失敗** —— 一個永遠綠燈的測試框架比沒有框架更危險
- 執行時的引擎版本與釘選版本相符 —— 版本漂移會讓整個引擎參考庫的判斷失去前提

第一個真實系統實作後**仍應保留**:它抓的是基礎設施迴歸(例如升級 GdUnit4 後 runner
路徑改變),與遊戲邏輯正交。

---

## 故事型別 → 測試證據

（權威來源:`.claude/docs/coding-standards.md` 的 Testing Standards 節）

| 故事型別 | 必要證據 | 位置 | 閘門 |
|---|---|---|---|
| **Logic**(公式、AI、狀態機) | 自動化單元測試,必須通過 | `tests/unit/[system]/` | **BLOCKING** |
| **Integration**(跨系統) | 整合測試 或 有記錄的實測 | `tests/integration/[system]/` | **BLOCKING** |
| **Visual/Feel**(動畫、特效、手感) | 截圖 + 主管簽核 | `production/qa/evidence/` | ADVISORY |
| **UI**(選單、HUD、畫面) | 手動走查文件 或 互動測試 | `production/qa/evidence/` | ADVISORY |
| **Config/Data**(數值調校) | Smoke check 通過 | `production/qa/smoke-[date].md` | ADVISORY |

---

## 待驗證項(建立時無 Godot 執行環境,全數未實測)

| # | 項目 | 影響 | 何時驗 |
|---|---|---|---|
| 1 | **GdUnit4 CLI 入口的實際路徑** | `gdunit4_runner.gd` 逐一嘗試四個候選路徑,全落空即 fail-loud。路徑猜錯只會讓 runner 明確報錯,不會靜默通過 | 安裝 GdUnit4 後第一次執行 |
| 2 | **`MikeSchulze/gdUnit4-action@v1` 對 Godot 4.7.1 的支援** | 4.7 為訓練截止(2026-01)後發布,action 是否跟上未確認。CI 首次真實執行失敗時優先懷疑此處 | 首次移除守衛後的 CI 執行 |
| 3 | **`run_tests()` 的回傳型別** | runner 同時處理 `int` 與 `bool`,無法判讀時**一律視為失敗**(不猜成功) | 同 #1 |
| 4 | **GdUnit4 對 Godot 4.7.1 的整體相容性** | 框架層級風險。若不相容,需回頭重評框架選擇 | 安裝時 |
| 5 | **`GdUnitTestSuite` 基底類別名稱** | 自我檢查測試 `extends GdUnitTestSuite`。名稱錯誤屬編譯期錯誤,會擋下整檔 —— 失敗方向明確,不會靜默 | 同 #1 |
| 6 | **`assert_failure(Callable).is_failed()` 的 API 形狀** | 用於驗證「框架真的會判失敗」。此 API 的確切簽章未經查證;若不存在,該項測試需改寫(可退回以框架自身的預期失敗機制表達) | 同 #1 |

> **這六項全部未實測,但沒有一項會造成「靜默通過」** —— 這是刻意的:
> runner 找不到入口即 `quit(1)`、回傳值無法判讀即視為失敗、基底類別名稱錯誤是編譯期錯誤、
> CI 跳過時 Summary 明文印出「並非通過」。**測試基礎設施最危險的失敗模式是假綠燈**,
> 六項的失敗方向都被安排在會被看見的那一側。

---

## CI 的暫時性守衛

`.github/workflows/tests.yml` 目前帶一個守衛:`project.godot` 不存在時跳過測試並直接成功。

**這不是「關掉失敗的測試」**(coding-standards 明文禁止)——現在根本還沒有測試可跑,
而長期紅燈會訓練所有人忽略 CI。守衛只在專案不存在時生效,`project.godot` 一進 repo 就自動放行。

跳過時 CI 的 Summary 會明文印出「**測試已跳過,並非通過**」,避免綠燈被誤讀。

**移除條件**:`project.godot` 建立 + GdUnit4 安裝完成 + 首次真實綠燈確認後,
刪除 workflow 內的守衛步驟與兩處 `if` 條件。
