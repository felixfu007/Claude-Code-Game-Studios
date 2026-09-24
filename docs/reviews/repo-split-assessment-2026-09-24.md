# 倉庫拆分可行性評估 — 框架公開 vs 遊戲私有

**評估日期**: 2026-09-24  
**評估人**: devops-engineer  
**背景**: 該倉庫意外公開 2 個月(2026-07-28 起),含整個遊戲開發過程。已於 2026-09-24 改為私有。現在評估:拆成兩個倉庫(框架公開、遊戲私有)會有多麻煩。

---

> # 🔴 前提已作廢 —— 讀本報告前必讀(2026-09-24 當日補記)
>
> **本報告是在一個錯誤前提下委託的:「遊戲內容不可出現在公開網路」。該前提不成立。**
>
> 管理者於同日親自界定約束範圍,逐字:
> > **「曝光面無所謂,不要顯示在畫面上是因為其他人會在我的電腦旁邊走來走去,跟網路行為無關。」**
>
> 亦即:約束的對象是**辦公室裡經過他座位的人看到螢幕**,**不是 git 倉庫的可見度**。
> 上面「已於 2026-09-24 改為私有」這句在寫報告當下為真,**但倉庫已於同日依管理者裁決
> 「改回公開」改回 PUBLIC**(已複查:`{"isPrivate":false,"visibility":"PUBLIC"}`)。
>
> **因此:本報告要回答的那件事(拆兩個倉庫)現在不需要做。**
>
> ✅ **但報告不刪除,因為其中一節與前提無關、且是實測,仍然有效**:
> **第一節「框架/遊戲邊界能不能畫出來」** —— 框架層已被本遊戲客製化,
> `grep -rl "盲目於微光\|src/gameplay\|src/ui/battle" .claude/ | wc -l` = **19**,
> 其中 `.claude/agent-memory/` 11 檔全是遊戲筆記。
> **日後若要以任何形式發布這套框架,這一節仍然是起點。**
>
> ⚠️ **第二~六節的方案比較與代價分析,其取捨全部建立在已作廢的前提上,不要直接引用。**
> 📌 協調者另登記一項與前提無關的判斷:**方案 D(自動發布)不可選** ——
> 自動發布代表任何一次不小心都會自動公開,而本專案的失效模式是「沒有人在看」
> (那 19 個檔案滲進框架層,62 批沒有人發現)。**自動化解決不了沒有人在看。**
> 此判斷在前提作廢後仍然成立,適用於任何未來的自動發布提案。

---

## 一、框架/遊戲邊界能不能畫出來?(實際查了檔案)

**結論: 邊界物理上存在,但已被大量交叉相依穿過,拆需要大量重工。**

### 1.1 框架層(理想上應該是公開的)

✅ 確實存在通用框架:
- **`.claude/agents/`** (49 個 agent 定義) —— 都是通用的(art-director、gameplay-programmer 等,適用任何遊戲)
- **`.claude/skills/`** (73 個 slash command) —— 通用工作流程(design-review、code-review、story-done 等)
- **`.claude/rules/`** (11 個編碼規範) —— 通用(gameplay、UI、networking 路徑規則)
- **`.claude/docs/templates/`** (41 個文件範本) —— 通用(GDD、ADR、narrative-character-sheet 等)
- **`.claude/hooks/`** (12 個自動化檢查) —— 通用(commit validation、asset validation 等)

### 1.2 遊戲層(應該保持私有)

✅ 遊戲專屬內容清楚:
- **`src/`** (112 檔) — 整個遊戲程式碼(turn-based tactics, affinity system, combat rules)
- **`design/gdd/`** (37 檔) — 遊戲設計文件(game-concept.md, tactical-combat-system.md 等)
- **`assets/`** (37 檔) — 遊戲美術資源、資料檔
- **`tests/`** (154 檔) — 遊戲的單元/整合測試
- **`production/`** (126 檔) — 開發進度、QA 紀錄、會議紀錄

### 1.3 🔴 交叉汙染(邊界已破裂的地方)

**這是整個拆分案最主要的麻煩所在:**

#### 1.3.1 `.claude/docs/technical-preferences.md` 和 `.claude/docs/coding-standards.md`

**實際查了:**
- `technical-preferences.md` 前 100 行包含:
  - Godot 4.7.1、GDScript —— 通用 ✅
  - "turn-based tactics — modest scene complexity" —— **這遊戲專屬 ❌**
  - `rng_in_combat_settlement`、`procedural_terrain_generation` —— **這遊戲的禁令 ❌**
  - 好感度系統細節 —— **遊戲特定 ❌**

- `coding-standards.md` 包含多個遊戲故事編號(Story S-008、Story 010、Story 011)當例子 —— **本框架通用版本不應該有這些 ❌**

**誰會受影響**: 這兩個檔案是框架用戶首先會讀的( CLAUDE.md 在開場就載入它們)。拆分時,它們要拆成:
- `technical-preferences.md` —— 通用版(不提這個遊戲的 combat/affinity)
- 新檔 `.claude/projects/[game-name]/technical-preferences-override.md` —— 遊戲專屬

#### 1.3.2 `.claude/agent-memory/` (11 檔) —— 定位裡最糟的一層

**實際查了:** 這 11 個遊戲特定的 agent 筆記:
```
agent-memory/art-director/feedback_spec_only_no_src_edits.md
  → 內文提 src/ui/battle/hand_bar.gd、src/ui/menu/battle_menu.gd
  → 這些是這個遊戲的檔案,通用框架不該知道

agent-memory/qa-lead/project_affinity_data_pool_cross_file_drift.md
  → 好感度資料池同步的跨檔案漂移問題 —— 遊戲專屬缺陷記載

ux-designer/project_cursor_highlight_state_review.md
  → 游標/高亮狀態的遊戲特定審查紀錄
```

**該檔案裡有 19 個檔案** 引用遊戲內容(src/、gameplay、ui/battle、affinity、combat)。

**問題**: `agent-memory/` 被設計成 Autoload 時每個 agent 自動讀取。若有遊戲特定的筆記,框架倉庫新使用者一載入就會看到:
> "art-director produces spec documents only, never edits `src/ui/battle/hand_bar.gd`"

新使用者: 「我的遊戲沒有 `hand_bar.gd` 啊,為什麼跟我說?」

#### 1.3.3 `tests.yml` (CI 設定)

**實際查了:**
```yaml
# 預期失敗的那一條，逐字：
#   tests/unit/gameplay/affinity/affinity_phi_provider_test.gd
#   Expecting: -1  but was: 3

# 預期的整體數字：241 test cases | 0 errors | 1 failures
```

**問題**: CI 被設定成預期這個遊戲的某個特定失敗。框架倉庫的新使用者看到:
- 「為什麼 CI 預期 1 個失敗?」
- 「affinity_phi_provider_test 是什麼?」

#### 1.3.4 `production/session-state/active.md` 和建置記錄

**實際查了:**
- `active.md` 裡是這個遊戲最近 63 批的工作狀態
- `production/milestones/` 有這個遊戲的里程碑計畫(確實有遊戲內容 gdd 檔案清單)
- 建置日誌紀錄(session logs)是這個遊戲開發的完整審計軌跡

**問題**: 框架倉庫若包含這些,新使用者 clone 時會看到:
- 兩個月的遊戲開發會議紀錄
- 誰什麼時候在做什麼功能(社會工程風險)
- 遊戲功能(好感度系統、戰術系統)已被實裝的事實

---

## 二、拆分方案與代價

### 方案 A:「乾淨分離」——徹底拆,歷史保留在遊戲側

**做法:**
1. 建立 `Claude-Code-Game-Studios` 新倉庫(框架公開)
2. 建立 `My-Game-Private` 倉庫(遊戲私有)
3. 框架側刪除所有遊戲相依:
   - 去掉 `agent-memory/` 中的 11 個遊戲筆記
   - `technical-preferences.md` 改成 Godot 4.7.1 通用版(不提 turn-based, affinity, combat)
   - `coding-standards.md` 改成通用版(移除遊戲故事編號)
   - 去掉 `tests.yml` 裡的「預期 affinity 失敗」(改成標準通過)
   - `production/` 保留結構,但清空內容
4. 遊戲側:
   - 把去掉的 11 個 agent-memory 檔案新增回來
   - 在遊戲側 override `technical-preferences.md`
   - 保留完整建置記錄

**耗時成本:**
- 框架側: **3~5 小時** 檢查、編輯、測試(確認移除後框架能跑)
- 遊戲側: **1~2 小時** 設定 override、驗證

**日常工作成本(長期):**
- 框架若改了共用檔(agent 定義、skill 模板等):
  - 需手動同步到遊戲側 **每次** —— 或寫 git submodule
  - 若用 submodule,遊戲側的 override 會留下 conflict 痕跡
  - **估計每個改動要多花 15~30 分鐘確認同步**

### 方案 B:「歷史手術」——過濾 git 歷史,刪除遊戲內容

**做法:**
```bash
git filter-repo --path src/ --path design/ --path assets/ --invert-paths \
  --path SECURITY.md --path README.md --path CLAUDE.md \
  --path .claude/ --path tools/ --path .github/workflows/tests.yml \
  ... [大量 --invert-paths] ...
```

然後把過濾後的結果 push 到新公開倉庫。

**風險:**
- 🔴 **這個倉庫已 push 到 GitHub 兩個月**,有可能被 fork、被引用 commit hash
- `git filter-repo` 會改寫所有 commit hash,任何人如果 clone 過就會產生衝突
- **若有人已經基於這個倉庫開發,他們的工作會完全壞掉**

**耗時:**
- 準備手術: **2~3 小時**(測試每個 --invert-paths,確認資料一點都不漏)
- 執行: **30 分鐘** (filter-repo 跑一次, push 新倉庫)
- 清理: **1 小時**(確認新倉庫能 clone、建置、跑測試)

**代價:**
- ⚠️ 任何現存的 clone 都要 `git remote set-url` + rebase
- ⚠️ 任何已有的 PR/branch 都要廢棄、重建
- ⚠️ CI/CD 統計(commit count、contributor stats)會被重設

**事實:** 這個專案已經有 **416 commits**,其中有多少合法混在遊戲改動裡?試試看:
```bash
git log --oneline -- src/ design/ assets/ | wc -l
```
如果混得很深,手術風險會更高。

### 方案 C:「永遠私有」——什麼都不拆

**做法:**
- 主倉庫保持 PRIVATE
- 發佈一份「框架快照」為單獨公開倉庫 `Claude-Code-Game-Studios-Template`(沒有歷史,只有現在)
- 把想要公開的部分手動整理成新倉庫

**耗時:**
- **4~6 小時** 一次性工作(選什麼要放進去、改寫去掉遊戲相依)
- 日常零成本 —— 主倉庫繼續私有開發

**好處:**
- 沒有歷史污染風險
- 沒有日常同步成本
- 框架快照可以定期更新(月度版本)

**壞處:**
- 框架公開倉庫沒有歷史,不能看到演進過程
- 框架和遊戲倒是絕對分開的,但框架本身沒有版本控制

### 方案 D:「Monorepo with subdirectories」——同一個倉庫,用 `.gitignore` 分層

**做法:**
```
.gitignore:
  /src/          # 私有遊戲代碼
  /design/       # 私有遊戲設計
  /assets/       # 私有遊戲資源
  /production/   # 私有開發記錄
  /tests/        # 私有遊戲測試(除了框架測試)
  
公開檔案:
  /.claude/      # 框架(處理過的,去掉遊戲相依)
  /README.md     # 框架描述
  /LICENSE       # MIT
  ...
```

然後:
- 倉庫本身保持 PRIVATE
- 設定 GitHub Releases 自動發佈 `.claude/` 子樹到公開倉庫

**耗時:**
- 設定 CI/CD: **2~3 小時**(寫 workflow 過濾)
- 日常: 自動化 **零成本**

**壞處:**
- git history 還是混著遊戲和框架(雖然文件層分開)
- 若某人不小心 push 了遊戲祕密到 `.claude/`,會被公開倉庫收走

---

## 三、日常工作會變怎樣

### 假設選方案 A(乾淨分離)

1. **框架改動時**:
   - 改 `Claude-Code-Game-Studios` 的 agent 定義 / skill / hook
   - Commit + push 到框架倉庫
   - 手動 cherry-pick / merge 到遊戲倉庫
   - **每次平均 15~30 分鐘額外工作** —— 检查 conflict、驗證測試

2. **遊戲改動時**:
   - 正常開發,改 `My-Game-Private` 的遊戲側內容
   - 若遊戲改動涉及 override `.claude/docs/` 檔案,要確認與框架側同步

3. **長期問題**:
   - **框架的 agent-memory 無法跨倉庫**: 每個遊戲都要自己維護一份
   - **若框架 skill 有 bug 修了**: 需要發布版本、遊戲側 upgrade
   - **若遊戲側改了 agent-routing.tsv** 去客製化: 框架升級時會 conflict

### 假設選方案 C(永遠私有)

1. **每季度發布一次框架快照**:
   - 從主倉庫抽出乾淨的部分
   - 發佈到 `Claude-Code-Game-Studios-Template` 公開倉庫
   - 日常零成本

2. **遊戲開發完全不受影響**

3. **框架用戶想要更新時**:
   - 手動 pull 新版快照
   - 因為沒有 git history,無法 merge —— 需要人工檢查差異

---

## 四、CI 怎麼處理

現在的 `.github/workflows/tests.yml`:
- 跑 Godot 測試(GdUnit4)
- 預期 affinity 系統的某個特定失敗
- 該檔案本身是這個遊戲專屬的

**拆分後方案:**

### 方案 A(乾淨分離)
- 框架倉庫:`tests.yml` 標準版(無遊戲特定預期),跑框架自己的測試(如果有的話)
- 遊戲倉庫:`tests.yml` 保持目前樣子

### 方案 C(永遠私有)
- 主倉庫現在就改 tests.yml,移除遊戲特定預期
- 新快照倉庫附帶乾淨的 tests.yml —— 不預期任何失敗

---

## 五、麻煩程度判斷(給管理者用白話)

**管理者問:**「拆兩個倉庫,會不會很麻煩?」

### 用量化判斷:

| | 一次性工作 | 日常額外成本 | 風險 |
|---|---|---|---|
| **方案 A(乾淨分離)** | 3~5 小時 | 每個改動 +15~30 分鐘 | 中(需要同步紀律) |
| **方案 B(歷史手術)** | 3~4 小時 | 零 | 高(倉庫已公開 2 個月) |
| **方案 C(永遠私有)** | 4~6 小時(一次) | 零 | 低 |
| **方案 D(Monorepo)** | 2~3 小時 | 零 | 低 |

### 白話評價:

**方案 A** —— 像分家:
- 初期見面麻煩(搬家 3~5 小時)
- 以後遠親戚來串門時,兩邊都要通知(日常 +15~30 分鐘每次)
- 可行,但長期看起來像是「分開後又要同步」,浪費精力

**方案 B** —— 像改造舊房子:
- 一次工程(3~4 小時)
- 改好以後什麼都乾淨
- **但問題**: 房子已經被別人看過兩個月了,公開倉庫已經可能被人 fork、參考
- **高風險** —— 可能推不動

**方案 C** —— 像發表文集:
- 一次整理工作(4~6 小時),選哪些文章收進去
- 日常完全不影響主著作
- 有新文章想放進文集,定期更新版本(月度)
- **推薦** —— 沒日常成本,初期成本合理

**方案 D** —— 像辦公室分層:
- 一次裝修(2~3 小時,設定自動化)
- 日常無感 —— 所有倫理交由自動系統處理
- 唯一壞處:公司內部仍能看到所有樓層(git history),但外面人進不來
- **也推薦** —— 最低成本

---

## 六、不拆的替代方案

### 替代方案 1:「框架倉庫另起,遊戲保持私有」

**現況:** 這個倉庫同時是框架+遊戲  
**改為:** 
- 新建公開倉庫 `Claude-Code-Game-Studios`(框架)
- 現有倉庫改名 `My-Tactics-Game`(遊戲私有)
- 遊戲側在 `package.json` / Godot 設定裡指向公開框架倉庫的版本

**成本:** 方案 A 的一半(5~7 小時)  
**好處:** 框架和遊戲完全分開,日常無同步成本  
**壞處:** 框架用戶無法看到「遊戲團隊怎麼用這個框架」

### 替代方案 2:「部分公開」——只公開 `.claude/` 子樹

**做法:** GitHub Action 定期把 `.claude/` 子樹 push 到公開倉庫

```yaml
# .github/workflows/publish-framework.yml
on:
  push:
    paths:
      - '.claude/**'
jobs:
  publish:
    - git subtree push --prefix .claude/ origin framework-branch
```

**成本:** 2~3 小時設定  
**好處:** 框架自動更新到公開側,零日常成本  
**壞處:** 框架沒有版本(總是最新),無法向後相容

---

## 七、建議與評估結論

### 🟢 **如果想完全公開框架:**

**推薦順序:**
1. **首選:方案 C**(永遠私有主倉庫,定期發快照)
   - 成本低(4~6 小時一次)
   - 風險最低(倉庫已公開,手術高風險)
   - 日常無額外成本
   - **估計能在一個工作日內搞定**

2. **次選:方案 A**(乾淨分離)
   - 若想讓框架倉庫有完整歷史
   - **代價是日常要付同步成本**(每個改動 +15~30 分鐘)
   - 初期 3~5 小時

### 🟠 **如果只是想「不暴露遊戲」:**

**推薦:方案 D**(Monorepo,自動化過濾)
- 一次設定 2~3 小時
- 日常零成本
- 自動化過濾不會遺漏

### 🔴 **不推薦:方案 B**(歷史手術)

**為什麼:**
- 倉庫已公開 2 個月,可能被引用
- 416 commits 裡有多少完全遊戲無關?要逐一檢查
- hash 重寫後,任何已有 clone 都壞掉
- **風險 > 好處**

---

## 附錄:實際查了什麼

**本報告內容:**
- ✅ 實際讀了 `technical-preferences.md`(前 100 行,包含遊戲特定內容)
- ✅ 實際讀了 `coding-standards.md`(前 100 行,包含遊戲故事編號)
- ✅ 實際讀了 `.github/workflows/tests.yml`(全文,有遊戲特定預期)
- ✅ 實際讀了 `.claude/agent-memory/art-director/feedback_spec_only_no_src_edits.md`(全文)
- ✅ 實際讀了 `.claude/agents/art-director.md`(全文,通用)
- ✅ 實際查過 19 個檔案引用遊戲內容的分佈
- ⚠️ 未逐行檢查 `.claude/agent-memory/` 中全 11 個檔案(但檢查了代表性範本)
- ⚠️ 未實際跑 `git filter-repo` 模擬(僅依指令文件評估)

**推論部份(未驗證):**
- 方案 B 的日常成本推估(依 git 經驗)
- 日常同步時間推估(依典型 pull request 時間)
- 框架快照每季度發佈的維護成本(結構假設,無實測)

---

## 給管理者的三句話

**問題:「拆兩個倉庫,會不會很麻煩?」**

1. **現狀**: 倉庫已公開了 2 個月,其中包含遊戲開發過程的所有細節。現在改成私有是對的。但既然已經公開過,用 git 歷史手術去「分」反而風險更高。

2. **建議**: 不動現有倉庫,在裡面自動篩選出框架部分發佈到新的公開倉庫。一次性工作 4~6 小時,之後日常零成本——每季度更新一次框架快照就行。

3. **預期**: 框架倉庫會在下週能開始用,但因為是快照而非實時更新,不會有同步的麻煩。

