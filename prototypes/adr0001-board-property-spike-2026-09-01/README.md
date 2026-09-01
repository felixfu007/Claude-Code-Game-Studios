# Spike:`Board` 的兩個承重欄位要怎麼表達「對外唯讀」?

> PROTOTYPE - NOT FOR PRODUCTION / 拋棄式技術驗證
> **日期**:2026-09-01
> **執行者**:`godot-gdscript-specialist`,本機 Godot 4.7.1 headless
> **成因**:2026-09-01 `TD-ADR` 關卡覆核發現 —— `docs/registry/architecture.yaml`(權威登記表)
> 對 `Board.board_version` 與 `Board.settlement_in_progress` 寫 `read-only` / `write_access: board-only`,
> 而 ADR-0001 的 Key Interfaces 宣告的是裸 `var`。**GDScript 的裸 `var` 代表任何外部程式碼都能直接寫入**
> —— 登記表宣稱的唯讀在程式層面不存在。管理者裁決另請專家處理,本檔為該次處理的證據。

**反諷之處**:同一份 ADR 對次要的佔位表 `_occupied` 做了底線私有化 + 存取方法保護,
**這兩個更要命的欄位反而沒有**。而 ADR 自己的 Risks 表點名的頭號風險逐字就是
「實作者誤把 `board_version` 的遞增掛在錯誤的事件上」。

---

## 結論(全部為實測)

| 做法 | 外部寫入時 | 呼叫端改寫量 | 500 萬次讀取 |
|---|---|---|---|
| A. 底線私有 + getter 方法 | 語法上不存在 setter | **ADR 全文 29 處要改** | 753,349 μs(**5.1×**) |
| B. 裸 `var`(ADR 原況) | **寫得進去,零阻攔** | — | 147,054 μs(基準) |
| C. 只有 `get:`、無 `set:` | 🔴 **靜默吞掉,`--verbose` 也無訊息** | 0 處 | 未單獨測 |
| **D. `get:` + `set:` 攔截(採用)** | **`push_error()` + 完整呼叫堆疊,值不變** | **0 處** | 607,175 μs(**4.1×**) |

**採用 D**(2026-09-01 管理者裁決)。三個理由:

1. **零呼叫端改寫** —— ADR 全文 29 處 `board.board_version` / `board.settlement_in_progress`
   引用逐字有效。本專案的已知失效模式之一就是跨檔傳播漏改。
2. **不靜默** —— 做法 C **比現況還糟**:裸 `var` 至少寫入會生效、日後能從行為異常反推;
   C 是寫了什麼都不會發生,連 debug log 都沒有,直接違反本專案「錯誤不得靜默」的慣例。
3. **反過來保護 Board 自己的實作者** —— 內部若手滑寫成 `board_version += 1` 而非
   `_board_version += 1`,一樣立刻報錯,而不是悄悄繞過原子性慣例。

**效能不構成理由**:4~5 倍聽起來大,絕對值是每次存取多約 90~120 奈秒。該欄位是
「每次查詢有效性判定讀一次」,一幀讀千次也只多 0.1ms,而預算是 16.6ms。

---

## 怎麼重跑

引擎路徑為本開發機的值,**非專案常數**:

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
```

- **單檔探針**(A / B / C 的機制與效能):`--headless --script <probe_x.gd>`
- **`realproj/`(最貼近真實情境,結論的主要依據)**:獨立 `project.godot`,
  `board_probe.gd` 以 `class_name` 宣告、由 `main.gd` 扮演**外部呼叫端**持有參照後嘗試賦值。
  須先 `--headless --path realproj --import` 建立 `class_name` 快取,再 `--headless --path realproj`。
  ⚠️ 這個前置匯入是本專案已記載的必要步驟(見 `.claude/docs/coding-standards.md`)。

## 逐字實測輸出(`realproj/logRun.txt`)

```
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

M1: initial board.board_version = 0
M2: after two committed settlement boundaries = 2
ERROR: board_version is read-only outside BoardProbe; rejected external write of 999
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] @board_version_setter (res://board_probe.gd:13)
       [1] _ready (res://main.gd:18)
M3: after external write attempt = 2 (expect 2, not 999)
```

**這段輸出是本 spike 的核心證據**:外部賦值 999 被拒絕、值維持 2、且錯誤訊息**指名了違規發生在哪一個檔案第幾行**
—— 後者正是它相對做法 B/C 的價值所在,寫錯的人在第一次執行就會看到,不必等到「查詢結果恆為過期」的症狀出現才回頭猜。

---

## 已知簡化與未查證

- 🔴 **release 建置下的行為未查證。** 本機沒有 export template,無法匯出 release。
  **本 spike 的全部結論限定在 debug / headless。** 這與 `docs/engine-reference/godot/modules/scripting-typing.md`
  「未查證」表第 1 項是同一個限制,不是本次新增的疏漏。
- 效能數字是單機、單次、粗略基準(500 萬次迴圈讀取),**不是統計上嚴謹的量測**。
  它足以支撐「差異在奈秒等級、相對 16.6ms 預算可忽略」這個結論,不足以支撐更精細的宣稱。
- 做法 C 只驗了「外部寫入是否靜默」,未單獨量測其讀取效能(結構上等同 B)。
- **未查** GdUnit4 對 `push_error()` 的斷言介面 —— 亦即「怎麼寫一條會 fail 的測試來釘住這個行為」
  尚未確認。ADR 新增的 Validation Criteria 第 9 項要落地時需要它。

## 建構過程中撞到、與本題無關但必須回報的兩件事

1. 🔴 **`class_name Board` 已經被佔用了。** `src/gameplay/board/board.gd`(166 行,2026-08-26 進 repo)
   已宣告 `class_name Board`,而它與 ADR-0001 要定義的 `Board` **是兩個職責不重疊的類別**
   (前者是地形/移動成本/視線/佔位的幾何雛形,`board_version` 零命中;後者是查詢原子性契約)。
   **Godot 一個專案內 `class_name` 全域唯一** —— ADR-0001 落地時不能再宣告第二個,
   必須二選一:把契約併進現有 `board.gd`(順帶把它的 `_occupants` 改名對齊 ADR 的 `_occupied`),
   或改掉其中一個名字。**已回報,未處置。**
2. ADR-0001 的 Migration Plan 寫「`src/` 為空,專案處於設計階段」—— 該句撰寫當下(2026-08-18)為真,
   但 `board.gd` / `line_of_sight.gd` 已於 2026-08-26 進 repo。**已就地更正。**

## 狀態

**已完成(2026-09-01)。** 做法 D 經管理者裁決採用,ADR-0001 Key Interfaces 已據此改寫,
`architecture.yaml` 第 71-72 / 95-96 行的 `interface:` 欄已補上執行機制說明。
