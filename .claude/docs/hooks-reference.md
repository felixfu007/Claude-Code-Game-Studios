# Active Hooks

掛載設定在 `.claude/settings.json`。**本表由該檔實際內容逐列比對產生,不是憑記憶寫的。**

> 🔴 **2026-09-15 全表重畫。** 舊版列著 `validate-push.sh`「警告推送到 protected branch」——
> 而它的掛載點已於 **2026-09-14(`1416ed7`)移除**,那批六筆提交碰了 `settings.json`
> 卻一次都沒碰這份說明文件。同時舊表**漏列了兩道實際掛載中的** hook
> (`validate-doc-consistency.sh`、`advise-skill-owner.sh`)。
> **兩個方向都錯:寫了不存在的,漏了存在的。**
>
> **重畫指令(要現值就當場跑,一秒,結果永遠是真的)**:
> ```bash
> grep -o '"command": "bash \.claude/hooks/[a-z-]*\.sh"' .claude/settings.json | sort -u
> ```

## 一、掛載中(13 個掛載點)

| Hook | 事件 | 觸發條件 | 作用 | 送達管道 |
| ---- | ---- | -------- | ---- | -------- |
| `session-start.sh` | SessionStart | 對話開始 | 載入 sprint / milestone / git 近況;偵測並預覽 `active.md`;**讀出並清空 hook 訊息佇列**;偵測提交閘門的孤兒記號 | stdout ✅ |
| `detect-gaps.sh` | SessionStart | 對話開始 | 偵測全新專案(建議 `/start`)與有程式碼卻無文件的缺口 | stdout ✅ |
| `validate-doc-consistency.sh` | SessionStart | 對話開始 | 跨檔案事實一致性(report 模式) | stdout ✅ **(2026-09-15 才修好,此前整段寫 stderr,五秒跑完一個字沒送到)** |
| `validate-commit.sh` | PreToolUse (Bash) | `git commit` 片段 | 設計文件段落、JSON 資料檔、寫死數值、TODO 格式、注入標記、跨檔矛盾(呼叫上一列的 `--gate` 模式) | 阻擋級 stderr+exit 2 ✅ / 其餘走佇列 ⏳ |
| `advise-skill-owner.sh` | PreToolUse (Skill) | 任何 skill 呼叫 | 查 `.claude/agent-routing.tsv`,印出該 skill 的擁有者 | 佇列 ⏳ **(先天做不到事前提醒,見下方注意事項)** |
| `validate-assets.sh` | PostToolUse (Write/Edit) | `assets/` 底下的檔案 | 命名規範、`assets/data/*.json` 格式 | 佇列 ⏳ **(2026-09-15 才修好)** |
| `validate-skill-change.sh` | PostToolUse (Write/Edit) | `.claude/skills/` 底下的檔案 | 提醒跑 `/skill-test` | 佇列 ⏳ **(2026-09-15 才修好)** |
| `notify.sh` | Notification | 通知事件 | PowerShell Windows 快顯通知 | 作業系統 |
| `pre-compact.sh` | PreCompact | 脈絡壓縮前 | 把 `active.md`、已改檔案、進行中設計文件倒進對話,讓它撐過摘要 | stdout |
| `post-compact.sh` | PostCompact | 壓縮後 | 提醒從 `active.md` 還原狀態 | stdout |
| `session-stop.sh` | Stop | 對話結束 | 摘要本次成果、更新 session log、跑 `validate-doc-consistency.sh --handoff` | 檔案 |
| `log-agent.sh` | SubagentStart | 派出 subagent | 稽核流水帳:記錄起點 | 檔案 |
| `log-agent-stop.sh` | SubagentStop | subagent 結束 | 稽核流水帳:補完該筆 | 檔案 |

**送達管道欄的意思**(依據:`.claude/docs/hooks-reference/hook-input-schemas.md` 的實測矩陣):

- **✅** = 會送達 Claude 與使用者。
- **⏳ 佇列** = 寫進 `production/session-logs/hook-queue.log`,由 `session-start.sh`
  在**下次對話開場**一次讀出並清空。**會送達,但會遲到。**
- 🔴 **不存在「不阻擋 + 立即看得到」的組合。** 那是平台性質,不是任何一支 hook 的缺陷。
  `stderr + exit 0` 這個組合**不送達任何人** —— 全庫九道閘門曾經全部是這個形狀。

## 二、在磁碟上、但**沒有掛載**(3 支)

**這三支不會執行。** 寫在這裡是因為它們檔案還在,不列出來的話下一個人會以為它們在跑。

| 檔案 | 為什麼還留著 | 掛回去之前必須先做什麼 |
| ---- | ------------ | ---------------------- |
| `validate-push.sh` | 2026-09-14 `1416ed7` 移除掛載點。平均 25.5 秒、逾時 10 次,**且六天內有效警告 0 次** —— `^git push` 錨在整條指令開頭,而多數指令以 `cd` 開頭 | 先修 `^git push` 錨定(改法見 `validate-commit.sh` 的拆片段比對) |
| `advise-file-owner.sh` | 同上。**逾時 100 次,佔全庫 151 次逾時的 66%**,且設計上 exit 0 always、永不阻擋 | 同上的錨定問題,加上抽值遇跳脫引號會截斷 |
| `enforce-gdd-line-limit.sh` | 2026-09-14 `d426f1a` **做好了但刻意沒上線** | 單次實測 50462 ms(對 11 份 GDD 開 22 個 git 行程)。改成一次 `git ls-tree` / `git diff --numstat`,1~2 個行程 |

⚠️ 三支的檔頭都有警示,寫明掛回去之前要修什麼。**不要在沒修的情況下掛回去。**

## 三、不是 hook、但被 hook 引用的

| 檔案 | 用途 |
| ---- | ---- |
| `lib/hook-queue.sh` | 被 `source` 的共用函式:`queue_message` / `queue_no_match_hit`。**有 256 KiB 硬上限**,理由見其檔頭(`session-log.md` 曾長到 190 MB) |
| `config/gdd-line-limit-exceptions.txt` | GDD 行數上限的豁免名單(三份,管理者裁決) |
| `.claude/agent-routing.tsv` | 路徑 / skill → 擁有者對照表 |

## 四、🔴 已知缺口(不是待辦,是現況)

1. **「跑 skill 前先確認擁有者」這件事,自動化上做不到。**
   `advise-skill-owner.sh` 唯一能即時送達的管道是 `exit 2`,而那會**擋下該次 skill 呼叫**。
   目前選擇排入佇列 —— 訊息會到,但**是在 skill 已經跑完之後**。
   ✅ **管理者 2026-09-15 裁決:維持現狀,不加這道摩擦。**
   🔴 知情代價:「派錯人」仍然會發生,本機制只保證事後查得到。
2. **`advise-file-owner.sh` 拆掉之後,寫檔路徑的擁有者提醒完全沒有自動化在跑。**
   `.claude/agent-routing.tsv` 目前只剩 `advise-skill-owner.sh` 在讀。
   「開工第一則訊息寫擁有者」那條常設義務,現在 100% 靠人工紀律。
3. **`assets/data/*.json` 沒有格式檢查**(本機無可用 Python,該段整段跳過)。
   ⚠️ 但它**以前也沒在保護** —— 舊版是 100% 誤判(把合法 JSON 判成不合法)。
4. 🔴 **佇列的「查無擁有者計數」分支今天是死碼,但它看起來是活的。**
   2026-09-15 實測:`queue_no_match_hit()` 全庫**唯一呼叫者**是缺口 2 那支已取消掛載的
   `advise-file-owner.sh`,因此 `production/session-logs/hook-queue-nomatch-count.txt`
   **恆為 0 且永遠不會增加**。`session-start.sh` 裡那段排空邏輯照樣每次開場執行、照樣判斷、
   照樣什麼都不印。
   ⚠️ **不要把「計數是 0」讀成「沒有查無擁有者的情況」** —— 它的意思是「沒有人在數」。
   ✅ **刻意保留不刪**:該 hook 還在磁碟上,日後重新掛載就需要這段;刪掉會讓重新掛載的人
   拿到一個靜默丟訊息的閘門。
   📌 **順帶記下這一項是怎麼被發現的**:不是靠讀程式碼,是靠**端到端實測** ——
   手動塞一則訊息進佇列、跑一次 `session-start.sh`、確認它印出來且檔案歸零。
   **「佇列是空的」與「佇列壞了」在畫面上長得一模一樣**,只有主動塞東西進去才分得出來。

---

詳細輸入格式:`.claude/docs/hooks-reference/hook-input-schemas.md`
權限清單與提交閘門的實測涵蓋範圍:`.claude/docs/permission-rules-scope.md`
