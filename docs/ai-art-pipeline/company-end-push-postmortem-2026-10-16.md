# 公司端推送 AI_IMG 的靜默刪檔事故 —— 根因與修法(2026-10-16)

> **狀態**:根因已實機重現並確認,修法已實測。**尚未寫進任何自動檢查** ——
> 與本專案其餘同類規則一樣,遵守與否目前不可觀測。
>
> **對應事件**:家用端 2026-10-15 的 18 號回覆第四節逐字提醒:
> 「`e66c1b3` 刪除了 … 看起來是誤刪 … 如果是你們本地 clone 的工具
> (例如 sparse checkout 或清理腳本)造成的,可能要檢查一下設定。」
> **是我方造成的,而且不是 sparse checkout,也不是清理腳本。**

---

## 一、事故

公司端 2026-10-15 推送 18 號請求的提交 `e66c1b3`,**連帶刪除了家用端 10/13 交付的兩個檔**:

```
docs/team/deliveries/2026-10-13-edge-floodfill-trial/pipeline-demo/animagine_seed2001_32x40_check_report.json
docs/team/deliveries/2026-10-13-edge-floodfill-trial/pipeline-demo/animagine_seed2001_32x40_x10_preview.png
```

家用端自行從 git 歷史還原(同一個 commit `4d08293`)。

## 二、🔴 根因:Windows 路徑長度上限,而 `git clone` 只給**警告**不給錯誤

2026-10-16 在本機重現。公司端的 clone 落在 session scratchpad 底下,該路徑本身就約 160 字元:

```
C:/Users/FELIXF~1/AppData/Local/Temp/1/claude/c--Users-felixfu007-Documents-Claude-Code-Game-Studios/<session-uuid>/scratchpad/<clone>/
```

加上倉庫內約 100 字元的路徑就越過 Windows 的 260 字元上限。實測 `git clone` 的輸出:

```
warning: Clone succeeded, but checkout failed.
You can inspect what was checked out with 'git status'
and retry with 'git restore --source=HEAD :/'
```

逐檔錯誤長這樣:

```
error: unable to create file docs/team/deliveries/2026-10-15-round3-screening/cutouts/20261014-001-jia-anim-sq-seed2002_cutout.png: Filename too long
```

**本次重現有 246 個檔沒有被寫出來。**

### 🔴 真正會咬人的一步不是「檔案沒寫出來」,是「索引把它們記成刪除」

checkout 失敗之後,`git status --short` 的輸出是:

```
D  .claude/agents/api-service-engineer.md
D  .claude/agents/comfyui-integration-engineer.md
...
```

**第一欄的 `D` 代表「已暫存的刪除」。** 亦即此時直接 `git commit`,
**那 246 個刪除會原封不動進提交**,而工作目錄看起來只是「少了一些檔」。

⚠️ **而且它會依路徑長度逐檔決定成敗,不是全有全無。** 2026-10-15 那次只死了 2 個檔,
正是那批裡路徑最長的兩個。**實測四個同批檔案的路徑長度**(`${#p}`,純 ASCII):

```
109  .../pipeline-demo/animagine_seed2001_32x40_check_report.json   ← 被刪
107  .../pipeline-demo/animagine_seed2001_32x40_x10_preview.png     ← 被刪
 98  .../pipeline-demo/regions_animagine_seed2001.json              ← 存活
 97  .../animagine_seed2001_magenta_preview_tol32.png               ← 存活
```

**98 與 107 之間有一道乾淨的分界。**
⚠️ 本次重現時連 97/98 那兩個也失敗了 —— 因為**本次的 scratchpad 路徑比 10/15 那次更長**。
**亦即門檻會隨 clone 落點浮動,同一個倉庫在不同 session 會死不同的檔。**
**所以症狀看起來像「隨機誤刪兩個檔」,不像「checkout 整個失敗」** —— 這是它當時沒被發現的原因。

## 三、修法(已實測)

```bash
git clone --depth 1 https://github.com/felixfu007/AI_IMG.git <目標目錄>
git -C <目標目錄> config core.longpaths true
git -C <目標目錄> restore --source=HEAD :/     # 把沒寫出來的檔補寫到工作目錄
git -C <目標目錄> reset -q HEAD -- .            # 🔴 清掉索引裡那些假刪除
git -C <目標目錄> status --short                # 必須是【完全空的】
```

🔴 **第四步不可省略。** 第三步只還原工作目錄,**索引裡的暫存刪除還在**;
實測第三步跑完之後 `git status --short` 仍然回報 246 行 `D`,直到第四步才歸零。

## 四、🔴 推送前的硬性查核(一行,沒有它上面全部白做)

> **`git status --short` 在你 `git add` 任何東西之前,必須是完全空的。**
> **只要有任何一行 `D`,就停下來 —— 那代表 checkout 靜默失敗了,
> 照樣提交會刪掉對方真實的交付物。**

⚠️ **沒有任何 hook、lint 或閘門會檢查這一條。** 它買到的是「下一個推送的人有明文可查對」,
不是「下一個人一定會照做」。

📌 **另一種同樣有效的做法**:把 clone 放到一個短路徑(例如 `C:/tmp/aiimg`),
從源頭避開 260 字元上限。本文不指定用哪一種,但**無論用哪一種,第四節那條查核都要做**
—— 它才是唯一會攔住事故的那一步。
