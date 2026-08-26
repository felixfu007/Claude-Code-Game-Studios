# src/tools/

編輯器內工具腳本(`@tool` 腳本、自訂 EditorPlugin、除錯用工具節點)的落點。

## 與頂層 tools/ 的差異

頂層 `tools/`(`ci`、`build`、`asset-pipeline`)是**專案外部**的建置/管線工具,
跟 Godot 專案本身無關,不需要 Godot 執行環境。`src/tools/` 是**專案內部**、
會被 Godot 載入的工具腳本(例如編輯器面板、關卡編輯輔助),兩者不要混放。

## `@tool` 腳本安全提醒

依 `.claude/docs/*` 的 Godot 最佳實務:`@tool` 腳本須有適當的 editor-safety
判斷(例如用 `Engine.is_editor_hint()` 區分編輯器內與執行期行為),避免在正式
執行時誤跑編輯器專用邏輯。
