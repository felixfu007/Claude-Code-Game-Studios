# Epics 索引

**最後更新**:2026-09-02
**引擎**:Godot 4.7.1
**控制清單版本**:2026-09-02

| Epic | 層 | 系統 | GDD | Stories | 狀態 |
|---|---|---|---|---|---|
| [cursor-highlight-state](cursor-highlight-state/EPIC.md) | Core | 單一游標/高亮狀態系統 | `design/gdd/cursor-highlight-state.md` | **14 張** | Ready |

---

## 尚未建立 Epic 的已核准系統

以下三個系統的設計文件皆已 `Approved`,但**各自另有阻擋**,故本批未建立 epic:

| 系統 | 層 | 卡在什麼 |
|---|---|---|
| 好感度數值池(#1) | Core | ADR-0002 已 `Accepted`。**未建立 epic 的理由是本批範圍只做游標一個**,不是被擋 |
| 戰棋移動與交戰(#4) | Gameplay | 🔴 **OQ-2:我方基準數值表** —— ✅ 2026-09-02 已指派 `systems-designer`(管理者裁決),**但表尚未產出,仍然阻擋**。該文件公式二沒有它寫不出來。ADR-0001 已 `Accepted`,**但它從來不是唯一的鎖** |
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
