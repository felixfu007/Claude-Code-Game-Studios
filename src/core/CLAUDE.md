# src/core/

全域系統與 autoload 落點——不放遊戲玩法邏輯。

## 放什麼

- Autoload/singleton 腳本(事件匯流排、存檔管理、設定管理)
- 依 `.claude/docs/coordination-rules.md`:autoload 只放這裡,且新增 autoload 時
  必須同步在 `CLAUDE.md` 記錄用途,不可當成便利函式的堆放處
- 跨系統共用、與具體玩法無關的基礎設施(例如 `SaveEnvelope` 之類的序列化外殼,
  對應 ADR-0003)

## 不放什麼

- 具體玩法規則(戰鬥結算、好感度計算)→ 放 `src/gameplay/`
- 任何 UI 節點或 Control 腳本 → 放 `src/ui/`

## 命名慣例

依 `.claude/docs/technical-preferences.md`:類別 PascalCase、檔名 snake_case
對應類別名、常數 UPPER_SNAKE_CASE。
