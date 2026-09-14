# 文件一致性檢查:被丟棄的發現清單(2026-09-14)

> **為什麼這份清單現在才出現。** `validate-doc-consistency.sh` 從建立起就一直在跑、
> 一直在產出發現,但它的輸出走 **stderr + exit 0** —— 而 2026-09-14 實測證實,
> 這個組合的輸出**既不會送到 Claude,也不會顯示給使用者**(管理者親口證實「從來沒看過」)。
> 所以這些發現全部進了虛空。管理者 2026-09-14 裁決:先完整擈出來,不修。
>
> ⚠️ **本清單只擈不修。** 每一項都需要人判斷,而且有相當比例可能是誤判 —— 見下方分類。

## 一、先講結論:目前沒有任何「文件互相矛盾」

`--gate` 模式的 **ERROR 級(兩份文件講相反的話)實測為 0 筆**。

📌 **而且 ERROR 級的阻擋路徑本來就是通的** —— `validate-commit.sh` 有正確接住
`validate-doc-consistency.sh --gate` 的離開碼 2 並自己 exit 2,而 exit 2 的 stderr
經實測**確實會送達 Claude**。**壞掉的是 warn 級,不是 ERROR 級。**
(協調者稍早一度把兩者一起說成「全部無效」,在此更正。)

## 二、warn 級:10 筆(判斷題,非必然錯誤)

[warn]  skill-card-system.md — could not classify status (header=UNKNOWN, index=NOT_APPROVED); check wording
[warn]  no '> **Status**:' header, so no systems-index cross-check is possible for: endings gameplay-flow-decisions gameplay-flow-draft vertical-slice-level-01
[warn]  affinity-data-pool — header cites 第12輪 but review-log has 5 '## Review —' entries. Mid-session skew is expected; a persistent gap means rounds went unlogged (this happened: rounds 1-2 of tactical-combat were never logged).
[warn]  cursor-highlight-state — header cites 第12輪 but review-log has 11 '## Review —' entries. Mid-session skew is expected; a persistent gap means rounds went unlogged (this happened: rounds 1-2 of tactical-combat were never logged).
[warn]  affinity-data-pool.md — AC id defined more than once: AC-4 (verify these are real duplicates, not a prose citation matching the definition anchor)
[warn]  affinity-data-pool.md — AC numbering has gaps: 72 distinct numbers spanning AC-1..AC-81 (expected 81 if contiguous). Retirements are fine (this project keeps retired ids on the books); verify none were dropped accidentally.
[warn]  cursor-highlight-state.md — AC id defined more than once: AC-63a (verify these are real duplicates, not a prose citation matching the definition anchor)
[warn]  cursor-highlight-state.md — AC numbering has gaps: 62 distinct numbers spanning AC-1..AC-63 (expected 63 if contiguous). Retirements are fine (this project keeps retired ids on the books); verify none were dropped accidentally.
[warn]  save-system.md — AC numbering has gaps: 76 distinct numbers spanning AC-1..AC-82 (expected 82 if contiguous). Retirements are fine (this project keeps retired ids on the books); verify none were dropped accidentally.
[warn]  157 suspected line-number self-references in design/, docs/architecture/, docs/registry/ (banned by .claude/rules/design-docs.md — use a stable handle). Standing backlog, deliberately one line. List them: bash .claude/hooks/validate-doc-consistency.sh --line-refs

## 三、行號自我引用:157 筆,但不是 157 個問題

規則出處:`.claude/rules/design-docs.md` ——
「never point to another passage in **a design doc, `systems-index.md`, or a
`*-review-log.md`** by line number」。理由是這類文件會被多輪 `/design-review` 反覆改寫,
行號在同一場對話內就會漂掉。

🔴 **規則的文字範圍不包含 `docs/architecture/`,也不包含有日期的存檔審查報告。**
因此 157 筆必須分三類看,不能當成 157 個待修項:

| 類別 | 筆數 | 是不是真問題 |
|---|---|---|
| **A. 活的設計文件 / 索引 / review-log** | **43** | 🔴 **是。規則明文涵蓋,而且這些文件還在被改,行號會繼續漂** |
| **B. 有日期的存檔跨文件審查報告**(`design/gdd/gdd-cross-review-2026-*`) | 38 | ⚠️ 存疑。它們是特定日期的快照、不再改動,引用當時的行號可視為歷史紀錄 |
| **C. 規則文字未涵蓋**(`docs/architecture/*`、`design/quick-specs/`) | 76 | ⚠️ 規則沒管到。要嘛擴大規則、要嘛明文排除,**目前是灰色地帶** |

**只有 A 類的 43 筆是明確違規。** 逐檔分布:

  12 design/gdd/cursor-highlight-state.md
  8 design/gdd/reviews/cursor-highlight-state-review-log.md
  7 design/gdd/reviews/save-system-review-log.md
  6 design/gdd/systems-index.md
  3 design/gdd/save-system.md
  3 design/gdd/affinity-data-pool.md
  1 design/gdd/tactical-combat-system.md
  1 design/gdd/reviews/affinity-position-chain-review-log.md
  1 design/gdd/reviews/affinity-data-pool-review-log.md
  1 design/gdd/game-concept.md

## 四、🔴 順帶查到的陷阱(擈這份清單時踩到的)

`validate-doc-consistency.sh` 第 82 行是 `cd "$(dirname "$0")/../.."` ——
它依**自己所在的位置**推算專案根目錄。協調者為了避開專家正在編輯的工作區檔案,
把它複製到暫存目錄執行,結果它 `cd` 到了不相干的地方、**什麼都沒掃到,然後安靜地 exit 0**。

**又是同一個形狀:「沒發現問題」與「根本沒檢查」在畫面上完全一樣。**
日後要單獨跑這支腳本,**必須在它原本的位置跑**,不能複製出去。

## 五、完整清單(157 筆)

  design/gdd/affinity-data-pool.md:7 cites number 86 as a location
  design/gdd/affinity-data-pool.md:21 cites number 294 as a location
  design/gdd/affinity-data-pool.md:333 cites number 175 as a location
  design/gdd/cursor-highlight-state.md:6 cites number 76 as a location
  design/gdd/cursor-highlight-state.md:7 cites number 76 as a location
  design/gdd/cursor-highlight-state.md:7 cites number 166 as a location
  design/gdd/cursor-highlight-state.md:8 cites number 166 as a location
  design/gdd/cursor-highlight-state.md:10 cites number 165 as a location
  design/gdd/cursor-highlight-state.md:102 cites number 165 as a location
  design/gdd/cursor-highlight-state.md:102 cites number 203 as a location
  design/gdd/cursor-highlight-state.md:104 cites number 165 as a location
  design/gdd/cursor-highlight-state.md:104 cites number 203 as a location
  design/gdd/cursor-highlight-state.md:360 cites number 165 as a location
  design/gdd/cursor-highlight-state.md:360 cites number 203 as a location
  design/gdd/cursor-highlight-state.md:391 cites number 205 as a location
  design/gdd/game-concept.md:134 cites number 180 as a location
  design/gdd/gdd-cross-review-2026-08-06.md:139 cites number 153 as a location
  design/gdd/gdd-cross-review-2026-08-06.md:148 cites number 170 as a location
  design/gdd/gdd-cross-review-2026-08-06.md:157 cites number 147 as a location
  design/gdd/gdd-cross-review-2026-08-06.md:163 cites number 161 as a location
  design/gdd/gdd-cross-review-2026-08-06.md:179 cites number 147 as a location
  design/gdd/gdd-cross-review-2026-08-06.md:225 cites number 147 as a location
  design/gdd/gdd-cross-review-2026-08-09-remediation-validation.md:24 cites number 175 as a location
  design/gdd/gdd-cross-review-2026-08-09-remediation-validation.md:31 cites number 172 as a location
  design/gdd/gdd-cross-review-2026-08-09-remediation-validation.md:39 cites number 152 as a location
  design/gdd/gdd-cross-review-2026-08-09-remediation-validation.md:68 cites number 172 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:18 cites number 151 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:29 cites number 171 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:30 cites number 171 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:33 cites number 171 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:39 cites number 308 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:39 cites number 182 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:46 cites number 151 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:47 cites number 158 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:47 cites number 160 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:118 cites number 155 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:120 cites number 149 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:120 cites number 174 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:121 cites number 174 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:121 cites number 149 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:126 cites number 15 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:127 cites number 164 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:129 cites number 171 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:130 cites number 174 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:131 cites number 175 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:132 cites number 177 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:134 cites number 163 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:169 cites number 149 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:169 cites number 174 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:184 cites number 171 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:184 cites number 151 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:185 cites number 308 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:194 cites number 149 as a location
  design/gdd/gdd-cross-review-2026-08-09.md:194 cites number 174 as a location
  design/gdd/reviews/affinity-data-pool-review-log.md:37 cites number 86 as a location
  design/gdd/reviews/affinity-position-chain-review-log.md:119 cites number 116 as a location
  design/gdd/reviews/cursor-highlight-state-review-log.md:340 cites number 166 as a location
  design/gdd/reviews/cursor-highlight-state-review-log.md:364 cites number 76 as a location
  design/gdd/reviews/cursor-highlight-state-review-log.md:369 cites number 166 as a location
  design/gdd/reviews/cursor-highlight-state-review-log.md:398 cites number 76 as a location
  design/gdd/reviews/cursor-highlight-state-review-log.md:402 cites number 76 as a location
  design/gdd/reviews/cursor-highlight-state-review-log.md:402 cites number 166 as a location
  design/gdd/reviews/cursor-highlight-state-review-log.md:430 cites number 166 as a location
  design/gdd/reviews/cursor-highlight-state-review-log.md:432 cites number 166 as a location
  design/gdd/reviews/save-system-review-log.md:195 cites number 164 as a location
  design/gdd/reviews/save-system-review-log.md:212 cites number 164 as a location
  design/gdd/reviews/save-system-review-log.md:260 cites number 165 as a location
  design/gdd/reviews/save-system-review-log.md:302 cites number 178 as a location
  design/gdd/reviews/save-system-review-log.md:374 cites number 178 as a location
  design/gdd/reviews/save-system-review-log.md:385 cites number 178 as a location
  design/gdd/reviews/save-system-review-log.md:664 cites number 631 as a location
  design/gdd/save-system.md:345 cites number 165 as a location
  design/gdd/save-system.md:345 cites number 203 as a location
  design/gdd/save-system.md:463 cites number 88 as a location
  design/gdd/systems-index.md:12 cites number 165 as a location
  design/gdd/systems-index.md:14 cites number 149 as a location
  design/gdd/systems-index.md:15 cites number 164 as a location
  design/gdd/systems-index.md:206 cites number 175 as a location
  design/gdd/systems-index.md:231 cites number 150 as a location
  design/gdd/systems-index.md:236 cites number 170 as a location
  design/gdd/tactical-combat-system.md:336 cites number 26 as a location
  design/quick-specs/unit-stats-provisional.md:259 cites number 93 as a location
  docs/architecture/adr-0001-tactical-query-atomicity-contract.md:696 cites number 20 as a location
  docs/architecture/adr-0004-save-system-atomic-write-and-migration-execution-model.md:7 cites number 27 as a location
  docs/architecture/adr-0004-save-system-atomic-write-and-migration-execution-model.md:531 cites number 27 as a location
  docs/architecture/adr-0004-save-system-atomic-write-and-migration-execution-model.md:531 cites number 421 as a location
  docs/architecture/adr-0005-cursor-device-authority-input-architecture.md:49 cites number 705 as a location
  docs/architecture/adr-0005-cursor-device-authority-input-architecture.md:49 cites number 774 as a location
  docs/architecture/adr-0005-cursor-device-authority-input-architecture.md:103 cites number 43 as a location
  docs/architecture/adr-0005-cursor-device-authority-input-architecture.md:105 cites number 384 as a location
  docs/architecture/adr-0005-cursor-device-authority-input-architecture.md:105 cites number 59 as a location
  docs/architecture/adr-0005-cursor-device-authority-input-architecture.md:1095 cites number 98 as a location
  docs/architecture/adr-0005-cursor-device-authority-input-architecture.md:1236 cites number 406 as a location
  docs/architecture/adr-0005-cursor-device-authority-input-architecture.md:1238 cites number 216 as a location
  docs/architecture/adr-0005-cursor-device-authority-input-architecture.md:1240 cites number 81 as a location
  docs/architecture/adr-0005-cursor-device-authority-input-architecture.md:1241 cites number 43 as a location
  docs/architecture/adr-revision-history.md:52 cites number 238 as a location
  docs/architecture/adr-revision-history.md:56 cites number 27 as a location
  docs/architecture/adr-revision-history.md:56 cites number 71 as a location
  docs/architecture/adr-revision-history.md:56 cites number 91 as a location
  docs/architecture/adr-revision-history.md:65 cites number 87 as a location
  docs/architecture/adr-revision-history.md:65 cites number 27 as a location
  docs/architecture/adr-revision-history.md:65 cites number 17 as a location
  docs/architecture/adr-revision-history.md:65 cites number 121 as a location
  docs/architecture/architecture-review-2026-08-18.md:142 cites number 15 as a location
  docs/architecture/architecture-review-2026-08-19-round4.md:227 cites number 51 as a location
  docs/architecture/architecture-review-2026-08-19-round4.md:228 cites number 66 as a location
  docs/architecture/architecture-review-2026-08-19-round4.md:229 cites number 69 as a location
  docs/architecture/architecture-review-2026-08-19-round4.md:233 cites number 88 as a location
  docs/architecture/architecture-review-2026-08-19-round4.md:235 cites number 51 as a location
  docs/architecture/architecture-review-2026-08-19-round4.md:296 cites number 43 as a location
  docs/architecture/architecture-review-2026-08-19-round4.md:320 cites number 28 as a location
  docs/architecture/architecture-review-2026-08-19-round5.md:140 cites number 709 as a location
  docs/architecture/architecture-review-2026-08-19-round5.md:140 cites number 986 as a location
  docs/architecture/architecture-review-2026-08-19-round5.md:149 cites number 98 as a location
  docs/architecture/architecture-review-2026-08-19-round5.md:174 cites number 581 as a location
  docs/architecture/architecture-review-2026-08-19-round5.md:175 cites number 746 as a location
  docs/architecture/architecture-review-2026-08-19-round5.md:217 cites number 27 as a location
  docs/architecture/architecture-review-2026-08-19-round5.md:241 cites number 25 as a location
  docs/architecture/architecture-review-2026-08-19-round5.md:241 cites number 29 as a location
  docs/architecture/architecture-review-2026-08-19-round5.md:263 cites number 43 as a location
  docs/architecture/architecture-review-2026-08-19-round5.md:292 cites number 28 as a location
  docs/architecture/architecture-review-2026-08-19-round5.md:314 cites number 51 as a location
  docs/architecture/architecture-review-2026-08-19-round6.md:61 cites number 427 as a location
  docs/architecture/architecture-review-2026-08-19-round6.md:67 cites number 412 as a location
  docs/architecture/architecture-review-2026-08-19-round6.md:67 cites number 433 as a location
  docs/architecture/architecture-review-2026-08-19-round6.md:71 cites number 1250 as a location
  docs/architecture/architecture-review-2026-08-19-round6.md:71 cites number 419 as a location
  docs/architecture/architecture-review-2026-08-19-round6.md:77 cites number 1250 as a location
  docs/architecture/architecture-review-2026-08-19-round6.md:77 cites number 1359 as a location
  docs/architecture/architecture-review-2026-08-19-round6.md:280 cites number 25 as a location
  docs/architecture/architecture-review-2026-08-19-round6.md:330 cites number 1250 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:75 cites number 434 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:80 cites number 714 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:122 cites number 294 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:125 cites number 215 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:130 cites number 156 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:137 cites number 30 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:137 cites number 25 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:297 cites number 71 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:297 cites number 1151 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:308 cites number 39 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:321 cites number 47 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:321 cites number 48 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:331 cites number 43 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:332 cites number 25 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:336 cites number 25 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:355 cites number 1759 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:355 cites number 87 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:355 cites number 93 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:389 cites number 71 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:390 cites number 1151 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:390 cites number 121 as a location
  docs/architecture/architecture-review-2026-08-20-round7.md:391 cites number 17 as a location
  docs/architecture/traceability-index.md:212 cites number 434 as a location
  docs/architecture/traceability-index.md:217 cites number 714 as a location
  docs/architecture/traceability-index.md:237 cites number 216 as a location
