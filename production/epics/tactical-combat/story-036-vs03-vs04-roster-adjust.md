# Story 036:第 3、4 場名冊站位調整(依難度裁定書)

> **Status**: Ready(查證無擋路事項;有 3 項與裁定書假設不符或需注意,見「查證結果」)
> ✅ **2026-11-10 加註(管理者核准整批加註):已完成,提交 `289c837`。** 第 4 場 4-A 保留;第 3 場 3-B 未改善,依判準 4 整案退回(名冊零改動)。
> **Type**: Config/Data(資料檔座標,零程式碼變更)
> **Epic**: tactical-combat
> **指派建議**: `gameplay-programmer`(跑量測、改資料);對照組的舊介面工具另需會開乾淨 worktree 的人(同一人亦可)
> **依據**:`docs/reviews/vs03-vs04-difficulty-decision-2026-11-06.md`(level-designer 依電腦數據代裁,管理者 2026-11-06 裁決「能代的全代,我只留聲音與手把」授權)。**本工單判準與退回條件照抄裁定書,不得改寫、不得加碼調參。**

## 一句話目標

改兩份名冊共 3 行座標(第 3 場 2 行、第 4 場 1 行),照裁定書判準重量;**達標才留、不達標就還原那一行**。丙射程維持 6,不動。

## 要改的行(逐字,取自裁定書)

`assets/data/units/vs03_roster.txt`
```
before: 9,E4,ENEMY,22,13,5,5,1,2,8,4
after : 9,E4,ENEMY,22,13,5,5,1,2,10,4
before: 10,E5,ENEMY,24,14,6,6,1,1,7,3
after : 10,E5,ENEMY,24,14,6,6,1,1,8,3
```
`assets/data/units/vs04_roster.txt`
```
before: 8,E3,ENEMY,18,14,3,3,2,4,12,5
after : 8,E3,ENEMY,18,14,3,3,2,4,11,4
```
兩檔檔頭**追加**一段帶日期的修訂註解(不改寫原註解,比照 vs04 檔頭 2026-10-29 那段)。vs03 那段可順手註明:檔頭「丙射程 2~4」已過時(實為 2~6)、「前排 E1/E5 在 x=7」「間距 7」因本次修改過時。

## 判準(照抄裁定書,逐字意義不得改)

### 第 3 場(運用好感度臂 `--arms=use`,8 組旋鈕),四項**全部**同時成立
1. 勝場 **≥ 7/8**(現 6/8)。
2. **不得過衝**:勝局 neardeath 總和 **≥ 3**(現 vs03 勝局 = 0,1,0,1,1,2 → 5;vs02 全 8 局總和 = 4)。第 3 場仍須比第 2 場險。
3. 對照組:同一份改後名冊再跑「提早撤退+隊形 a+b」版,勝場 **≥ 5/8**(不得比改前 5/8 更差)。
4. **整案退回**:勝場 ≤ 6/8 或第 2 項不成立(過衝),**還原兩行、不再試別案**(不開第二輪調參)。第 3 項不成立同樣還原。

### 第 4 場(`--arms=use`)
1. 勝場 **≥ 6/8**(防崩盤;現 8/8)。
2. **第 1~2 回合不得出現敗局**(看 RESULT 行 `rounds=`)。
3. 加分、**非必要**:勝局 neardeath 總和 ≥ 3,或最低剩餘 HP < 6(現總和 2、最低 6)。
4. 退回:第 1 或第 2 項任一不成立 → 還原該行,第 4 場維持原站位並回報;不改試 4-B/4-C。
5. 若量出仍 8/8 且第 3 項無改善:**保留 4-A**,但回報必須如實寫「電腦數據顯示沒有變難」,**不得寫成「已調難」**。

兩場各自獨立判定、各自可獨立退回,回報寫明是哪一條判準不成立。

## 🔴 禁止
- **絕不得跑 vs01**(停損考試專用;`--level=1`、`--r2=yes` 一律不得出現)。
- 不動旋鈕檔 `assets/data/tuning/tuning_knobs.txt`(裁定書自述未讀、牽連未查證 —— 若實作者發現必須動旋鈕才能達標,**停下回報,不自行動**)。
- 不動丙射程、不動地形檔、不動我方各行與 E1/E2(vs03 另含 E3)以外之敵方行。

## 查證結果(2026-11-10 當場查,以下為原始輸出)

### 1. 測試是否寫死 vs03/vs04 名冊或座標 —— 無
```
$ grep -rn "vs03_roster\|vs04_roster" tests src tools prototypes/protocol2-computer-measure-v4 prototypes/protocol2-computer-measure-v3
(無輸出)
$ grep -rln "vs03\|vs04" tests src
tests/integration/ui/shell/campaign_all_missions_load_test.gd
tests/integration/ui/shell/support_conversation_transition_flow_test.gd
$ grep -n "vs03\|vs04" <上述兩檔>
campaign_all_missions_load_test.gd:92:	# 地形 vs03(13x6)搭配 duel 名冊(單位數不是 5+5)→ 單位數違規
support_conversation_transition_flow_test.gd:13:#   - 戰鬥內容用夾具(duel 地形 + 勝利名冊),不是 vs03~vs05 真實關卡;真實關卡載入由
```
兩檔命中皆為**註解**。`tests/integration/ui/battle_input_gaps_test.gd:290` 提到 (12,5) 但註解指的是 vs01 地形,與本單無關。
⚠️ 但 `campaign_all_missions_load_test.gd` 經 `campaign_sequence.txt` 載入全部關卡(含 vs03/vs04 名冊),故**全套仍必須跑**以確認新座標不違反載入規則(單位數、不重疊、在棋盤內)。**預期零測試需改**;若有紅燈,先判斷是本單造成還是既有,不要改測試去遷就。

### 2. 地形確認(座標 = (x,y),x 為欄、y 為列,皆從 0 起算)
```
vs03_terrain.txt   列4(y=4): ...,,#,......   -> x=10 為 '.'(空地)
                   列3(y=3): ...#,,,......   -> x=8  為 '.'(空地)
vs04_terrain.txt   列4(y=4): .....,,.#....   -> x=11 為 '.'(空地)
```
(上方以 `cat -n` 的行號 y+1 讀取:vs03 第 5 行 `...,,#,......`、第 4 行 `...#,,,......`;vs04 第 5 行 `.....,,.#....`。)三格皆空地。
單位不重疊:vs03 改後敵方座標 (7,2)(8,1)(9,5)(10,4)(8,3) 互異且與我方 x=0 不衝突;vs04 改後 E3 (11,4) 與 E1(8,2) E2(12,0) E4(11,3) E5(12,2) 皆異。

### 3. 量測工具:`prototypes/protocol2-computer-measure-v4/protocol2_runner.gd`
讀的是程式碼,不是 README:
```
6:  ##   --level=<n>            row of campaign_sequence.txt (default 2; vs01 must be chosen explicitly: --level=1)
7:  ##   --terrain= --roster= --affinity=   explicit res:// paths (override --level; for fixture debugging)
8:  ##   --arms=ignore,use      default both
13: const SEQ := "res://assets/data/levels/campaign_sequence.txt"
37-44: 讀 SEQ 取 terrain/roster 路徑
82: var state: BattleState = BattleState.create(_rows(FileAccess.get_file_as_string(terrain_path)), FileAccess.get_file_as_string(roster_path))
208: print("RESULT arm=%s v=%d outcome=%s rounds=%d neardeath=%d ... final_hp=%s ...
```
結論:
- **支援 `--level=3`/`--level=4`、`--arms=use`**(`use` = 運用好感度臂)。
- **載入真實資料檔**:`FileAccess.get_file_as_string(roster_path)`(第 82 行)讀的就是 `res://assets/data/units/vsNN_roster.txt`,**沒有重新實作名冊規則**,符合 `technical-preferences.md` 第 1 點。
- **能讀改後名冊,有兩種做法,選一**:(a) 直接改 `assets/` 後跑 `--level=N`(最簡單,不達標就還原);(b) `--terrain= --roster= --affinity=` 明指 `res://` 路徑(第 7 行),把改後名冊放在 `prototypes/story-036-.../` 副本量,達標才動 `assets/`。**建議 (b)**:退回成本為零、不會把 `assets/` 弄髒。⚠️ 用 (b) 時 `--level` 不得省略改成 `--terrain` 以外的組合 —— 注意第 29 行的 vs01 護欄只在 `--level=1` 且無 `--terrain` 時才擋,**用 (b) 時絕不要給 `--level=1`**。(b) 必須同時給三個路徑(第 7 行);`--affinity=` 請填 `res://assets/data/affinity/vsNN_affinity_links.txt`(同 `campaign_sequence.txt` 該列)。
- 輸出檔頭 `HEADER` 印 `roster=` 路徑(第 57-59 行),**必須留在 log 裡**作為「確實量到改後名冊」的物證:用 (b) 時 `roster=` 應為副本路徑,且副本內容須與 `assets/` 最終落地內容逐字相同(量完 `diff` 並貼原文)。
- ⚠️ `neardeath`、`rounds`、`outcome`、`final_hp` 皆為 RESULT 行欄位(第 208 行),判準 1/2 與第 4 場判準 1/2/3 全可直接由它們算出,不需改工具。

建議指令(`<godot>` 為本機引擎完整路徑,見 `coding-standards.md` CI 節):
```
<godot> --headless --path . -s res://prototypes/protocol2-computer-measure-v4/protocol2_runner.gd -- --level=3 --arms=use
<godot> --headless --path . -s res://prototypes/protocol2-computer-measure-v4/protocol2_runner.gd -- --level=4 --arms=use
```
(以上為改 `assets/` 的做法 (a);(b) 把 `--level=N` 換成三個路徑。)首次需 `--import`。🔴 **指令直接貼進回報,不要寫進任何 `.gd`/`.md` 註解**(自我命中陷阱)。

### 4. 對照組(判準 3「提早撤退+隊形 a+b」)—— **可行性:理論可行、未驗證**
```
prototypes/difficulty-ai-formation-2026-11-03/formation_runner.gd 第 127 行:
  var gt: int = CombatRules.guard_total(CombatRules.guard(phi_t), s.lone_guard_if_at(id, t, will_attack))
README 第 13 行(執行指令形狀):
  ... -s res://prototypes/difficulty-ai-formation-2026-11-03/formation_runner.gd -- --level=3 --arms=use [--early=on] [--form=on]
```
- 該工具呼叫已移除的三參數 `lone_guard_if_at`,**在現行 HEAD 會解析失敗**(README 2026-11-05 加註亦如此寫)。
- `cbe811d` 是 `45a20de` 的祖先(`git merge-base --is-ancestor` 實測成立),故理論上可在 `cbe811d` 的**乾淨 worktree** 跑。但 `cbe811d..HEAD` 之間 `src/` 與 `assets/data` 另有 22 檔變更(`git diff --stat cbe811d HEAD -- src assets/data` → `22 files changed`),**該舊 commit 上的遊戲規則不等於現行**。
- **做法(若採用)**:乾淨 worktree 檢出 `cbe811d` → 在該 worktree 放入「改後名冊」副本並用 `--roster=` 指向 → `--early=on --form=on --level=3 --arms=use`(或 `--terrain/--roster/--affinity` 三路徑)。**同一 worktree 要再跑一次「未改名冊」作為同條件基準**,因為判準寫的「改前 5/8」是 11-03 在另一個 commit 量的,不同 commit 的數字不可直接比。判準 3 以**同一 worktree 內改前/改後**的勝場比較為準(改後 ≥ 5/8 且不低於同條件改前基準);同條件基準若不是 5/8,**照實貼出,判準 3 仍以裁定書 ≥ 5/8 判**,另在回報註明基準差異。
- **若 worktree 跑不起來(`.uid`/`project.godot`/資料檔不齊、解析失敗等)**:判準 3 在回報與本工單標「**未驗**」,**不得宣稱通過**;此時整案是否保留,**不自行裁定,停下回報協調者**(裁定書只定義了「第 3 項不成立 → 還原」,沒定義「第 3 項無法驗」)。

### 5. 與裁定書假設不符 / 需注意的事實
1. 裁定書稱「v4 參數沒查證」—— 已查,**v4 支援所需全部參數**(上方第 3 節),不需複製新版。
2. 裁定書稱「如何讓工具讀副本名冊未查證」—— 已查,**`--roster=` 即可**,不必改工具。
3. 裁定書稱檔頭「間距 7」過時屬實:改後 vs03 最近敵人為 E1(7,2)、E5(8,3)、與我方前緣 x=0 的間距仍是 E1 的 7;**E1 不動**,故檔頭「間距 7」其實對 E1 仍成立,只有「前排 E1/E5 在 x=7」「E4 在 x=8」不成立。修訂註解請照實寫,不要照裁定書字面寫「間距過時」。
4. 對照組基準不同 commit 的不可比性(上方第 4 節)—— 裁定書未提。

## Affected Files(`Ready` 工單的明文範圍)

| 檔案 | 動作 |
|---|---|
| `assets/data/units/vs03_roster.txt` | 改 2 行(E4、E5 座標)+ 檔頭追加修訂註解;不達標則還原 |
| `assets/data/units/vs04_roster.txt` | 改 1 行(E3 座標)+ 檔頭追加修訂註解;不達標則還原 |
| `prototypes/story-036-roster-adjust-<日期>/`(新資料夾) | 放副本名冊(做法 (b))、各 run 原始輸出檔、一份簡短 README(只記指令與結果,不複述判準) |
| `tests/**` | **預期零改動**(上方第 1 節)。若全套紅燈且確因本單,先停下回報,不得改測試遷就 |

不在範圍:`vs03_terrain.txt`/`vs04_terrain.txt`、旋鈕檔、其他關卡名冊、`src/`、丙射程、`design/quick-specs/unit-stats-provisional.md`(丙 2~4 與名冊 2~6 的已知不一致不在本單處理)。

## 驗收條件

1. **每份量測 log 貼原始行**:`ENGINE EXIT`、`HEADER`(含 `roster=` 路徑)、全部 `RESULT` 行、`DONE`、`FATAL`。「勝場 N/8」「neardeath 總和」由實作者**從 RESULT 行算出並列出算式**(例:`neardeath` 逐局數字相加),協調者重算複驗。
2. **逐項對判準逐條寫「成立 / 不成立 / 未驗」**,第 3 場四項、第 4 場五項各自表列,不得只寫總結。
3. 空結果守衛:RESULT 行數必須 = 旋鈕組數 × 臂數(`--arms=use` 8 組 → 8 行),`FATAL` 為 0;**不是 0 行也不是「grep 空」**(本專案登記過空結果假綠)。
4. 若退回:還原後 `git diff` 該檔應為空(除檔頭註解是否保留由實作者在回報中說明;**建議退回時連修訂註解一併還原,另寫一行說明留在 prototypes README**)。
5. **全套**(交付硬性義務,CLAUDE.md 2026-10-12 裁決):
   ```
   GODOT_BIN=<引擎路徑> bash tools/build/run_tests_with_import.sh
   ```
   回報貼**引擎自己的原始三行**:`ENGINE EXIT = <n>`、`Overall Summary` 該行、`Executed test suites: (x/x)`;**不是只說「測試通過」**。exit 105(收集階段解析錯誤)時 `Overall Summary`/` FAILED` 的 grep 會是空的,**先看 exit code 與 log 尾端有無 `Parse Error`**。協調者一律自行重跑複驗。
6. 回報附 `git status` 證明沒有碰 vs01 或其他檔(尤其 `assets/` 下除兩份名冊外無變更)。

## 實作順序(每步皆可停,不留壞檔)

1. 在 `prototypes/story-036-.../` 放改後名冊副本 → 用 (b) 跑 vs03、vs04(各一次)→ 判準 1/2(第 3 場)與第 4 場全部判定。
2. 兩場各自:達標 → 把副本內容寫入 `assets/` 對應名冊(+ 修訂註解);不達標 → 不動 `assets/`,回報哪一條不成立。
3. 第 3 場主判準通過才做對照組(第 4 節)。主判準已不成立就**不必**跑對照組(已經要退回)。
4. 全套 → 貼物證。

## 風險

- 🔴 **n=8 且 8 組旋鈕彼此不獨立**:判準是篩子不是勝率目標(裁定書第四節第 4 項)。**不要因為差 1 局就自行再試別的座標**,裁定書明令不開第二輪。
- 🔴 電腦數據回答不了手感、真人公平感、敘事副作用(裁定書第四節);回報**不得**寫成「第 3 場變好玩了」之類超出量測範圍的話。
- ⚠️ 修改 `assets/` 名冊會影響所有讀 vs03/vs04 的測試與場景;`campaign_all_missions_load_test.gd` 是唯一會碰到的測試,見上。
- ⚠️ 本單無自動檢查保證「判準 3 的基準 commit 一致」,靠實作者照第 4 節寫明。
