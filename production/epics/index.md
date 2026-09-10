# Epics 索引

**最後更新**:2026-09-10(建立技能卡牌系統 epic —— 邏輯層 5 張)
**引擎**:Godot 4.7.1
**控制清單版本**:2026-09-02

| Epic | 層 | 系統 | 權威文件 | Stories | 狀態 |
|---|---|---|---|---|---|
| [cursor-highlight-state](cursor-highlight-state/EPIC.md) | Core | 單一游標/高亮狀態系統 | `design/gdd/cursor-highlight-state.md` | **14 張**(完成 9) | 進行中 |
| [screen-scaling](screen-scaling/EPIC.md) | Presentation | 畫面縮放與定位(手動管理) | `design/art/screen-architecture.md`(**非 GDD**) | **2 張**(全部完成) | ✅ **Complete** |
| [skill-card-system](skill-card-system/EPIC.md) | Gameplay | 技能卡牌系統(僅好感度對話卡牌) | `design/gdd/skill-card-system.md` + `design/ux/skill-card-play.md` | **5 張**(邏輯層;介面層未建立) | 🟡 進行中 |

⚠️ **第三欄原名「GDD」,2026-09-04 改為「權威文件」** —— `screen-scaling` 是呈現層基礎設施,
不是遊戲系統,沒有 GDD 也不會有。硬塞一個 GDD 欄位會讓下一個人去找一份不存在的文件。

🔴 **`screen-scaling` 建立於 2026-09-04,起因值得記住**:它的內容是 **2026-09-01 的管理者裁決**,
被記載在 8 個檔案裡,**但沒有任何工作單擁有它,因此三天內沒有進入任何排程**。
發現方式是盤點下一步時察覺 `project.godot` 的實際值與 `.claude/docs/technical-preferences.md`
(**每次對話開場載入**)寫的值不一致。
📌 **通則:裁決被記錄 ≠ 裁決被排程。** 凡裁決帶有執行動作,當天就要有一張工作單擁有它,
否則它只會活在紀錄裡。

---

## 尚未建立 Epic 的已核准系統

以下三個系統的設計文件皆已 `Approved`,尚未建立 epic。

🔴 **本段原寫「各自另有阻擋」,2026-09-10 更正:三項裡只有一項是真的被擋。**
#4 那把鎖九天前就開了(見下表),#1 只是沒排到。**寫成「被擋」與寫成「沒排到」
會導向完全不同的下一步 —— 前者永遠不會自己結束。**

| 系統 | 層 | 卡在什麼 |
|---|---|---|
| 好感度數值池(#1) | Core | ADR-0002 已 `Accepted`,**但程式碼零實作**(2026-09-10 實測:`append_record`/`combat_card`/`data_pool` 全庫零命中)。🔴 **它現在擋著 `skill-card-system` 的丙類端到端驗證**,見該 epic 的 Story 004 |
| 戰棋移動與交戰(#4) | Gameplay | 🔴 **本列 2026-09-10 更正 —— 原寫「OQ-2 我方基準數值表尚未產出,仍然阻擋」,而那是錯的。** 該表自 **2026-08-31** 起即有擁有者並已產出:`design/quick-specs/unit-stats-provisional.md`(第 1 節資料、第 7-4 節給 #6 的尺度錨點)。上游 OQ 沒跟上那次指派,本索引照抄,於是 2026-09-02 又重複指派了一次。**未建立 epic 的實際理由是尚未排程,不是被擋。** 教訓見 `docs/consistency-failures.md`:**看到「已指派、等交件」,先 grep 產出物是否已存在** |
| 好感度—位置連鎖(#5) | Gameplay | 依賴 #4 的輸出 |

**存檔系統**:ADR-0004(原子寫入與遷移)仍為 `Proposed`,且依一年計畫第七節**明確不在
12 個月範圍內**(「不在最短路徑上,維持 `Proposed` 即可,不要再投入」)。

---

## 本批的流程紀錄(不靜默略過)

- **`/create-control-manifest` 與 `/create-epics` 的覆核關卡皆未執行**
  (`TD-MANIFEST`、`PR-EPIC`,因精簡模式跳過)。管理者 2026-09-02 裁決:
  **先不跑覆核,但要留紀錄。** 理由是本批只做一個系統試水溫,錯了很便宜。
- **`docs/architecture/architecture.md` 不存在** —— `/create-architecture` 從未執行。
  ADR-0005 實質承擔模組定義的角色。**不阻擋,但登記在案。**
