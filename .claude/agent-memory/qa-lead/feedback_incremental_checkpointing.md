---
name: feedback-incremental-checkpointing
description: For long review/audit tasks, write a section skeleton to disk first and save after every single item plus a scratchpad checkpoint log line — validated approach, coordinator confirmed it twice
metadata:
  type: feedback
---

長篇覆核/稽核任務,**開始分析前**先把報告骨架(全部章節標題、內容留空)寫到最終路徑並存檔;
**每查完一項就寫進去並存檔**,不累積到最後一次寫;每次存檔後在 scratchpad 的 log 檔 append
一行 `CP<n> | 剛查完哪項 | 還剩哪些`。

**Why:** 這個工作環境的 subagent 會被中斷,而中斷位置**百分之百落在「宣告要開始大量產出」之後、
實際動作之前**(2026-09-03 一天內七次,位置全部相同)。有落檔的每一次都零重工接回;
上一批有一位覆核者跳過落檔然後中斷,沒人看得出他停在哪。管理者在 Story 007 覆核中途
明確確認過兩次「你的落檔紀律讓我能精確接續,沒有任何需要重做的東西」——
這是**經驗證有效**的做法,不是防禦性的多餘動作。

**How to apply:** 任何預期會產出多節報告的任務(覆核、稽核、涵蓋度分析)一律照做。
接續時**以檔案為準,不要重寫已落檔的內容** —— 管理者會直接告訴你 checkpoint 顯示到哪裡。
每次寫入量壓小(一節一次),不要為了「一次寫完比較整齊」而累積。
相關:[[project-affinity-data-pool-cross-file-drift]]
