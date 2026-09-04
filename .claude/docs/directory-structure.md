# Directory Structure

> 🔴 **本圖於 2026-09-01 全庫稽核重畫,依實測結果。**
> 舊版有 **13 個子目錄實際不存在**、**4 個實際存在的頂層目錄沒有畫**,而且畫著
> `src/networking/` —— 但 `networking_features` 是本專案的**專案級禁令**(單機遊戲,
> 無連線/多人/線上功能)。**一張規範用的結構圖,列著一個被明文禁止的目錄。**
>
> **本圖只畫實際存在的東西。** 需要新目錄時先建立再畫,不要預先畫出「將來可能會有的」——
> 舊版就是那樣寫的,結果沒人能分辨哪些是規範、哪些是想像。

```text
/
├── CLAUDE.md                    # 專案主配置(每次對話開場載入)
├── README.md
├── UPGRADING.md
├── project.godot                # Godot 專案檔
│
├── .claude/                     # agent 定義、skill、hook、rules、docs
├── addons/                      # 第三方套件(目前僅 GdUnit4,明文進版控)
│
├── src/                         # 遊戲原始碼
│   ├── ai/
│   ├── core/
│   ├── gameplay/
│   ├── tools/
│   └── ui/
│
├── assets/                      # 遊戲資源
│   ├── art/
│   ├── fonts/                   # 進版控的字型檔 + 授權全文(見該目錄 README)
│   └── data/                    # 資料驅動的設定檔(關卡地形、名冊等)
│
├── design/                      # 設計文件
│   ├── art/                     # 美術方向
│   ├── gdd/                     # 系統設計文件 + reviews/
│   ├── narrative/               # 角色、劇情
│   ├── quick-specs/             # 暫行規格(未升格為正式 GDD)
│   ├── registry/                # entities.yaml —— 跨文件事實登記表
│   └── ux/
│
├── docs/                        # 技術文件
│   ├── architecture/            # ADR + 追溯索引 + 審查報告
│   ├── engine-reference/        # 版本釘死的引擎 API 快照(godot / unity / unreal)
│   ├── examples/
│   ├── registry/                # architecture.yaml —— 架構立場登記表(權威)
│   └── reviews/                 # 跨文件審查與稽核報告
│
├── tests/                       # 測試套件(GdUnit4)
│   ├── integration/
│   ├── smoke/
│   └── unit/
│
├── tools/                       # 建置與流水線工具
│   ├── asset-pipeline/
│   └── build/
│
├── prototypes/                  # 拋棄式試作與驗證探針(與 src/ 隔離)
│
├── production/                  # 生產管理
│   ├── milestones/
│   ├── qa/                      # 測試證據、問卷
│   ├── session-logs/            # 稽核流水帳(gitignored)
│   └── session-state/           # 跨對話交接狀態(active.md,進版控)
│
├── build/                       # 匯出的建置產物(gitignored)
├── reports/                     # 測試報告(每次執行重新產生,gitignored)
└── CCGS Skill Testing Framework/   # skill 測試框架(獨立於遊戲)
```

## 兩點使用說明

- **`docs/registry/architecture.yaml` 是架構立場的權威來源**,`design/registry/entities.yaml`
  是跨文件遊戲數值的權威來源。兩者都**只有條目本體算數** —— 檔頭的計數摘要會漂移,
  2026-09-01 稽核就是因為檔頭計數落後兩代才發現的。
- **`prototypes/` 的試作不受 `src/` 的規範約束**,但也不得被正式程式碼引用。
  引用 `Proposed` 狀態 ADR 的工作只能在此進行,不得進 `src/`。
